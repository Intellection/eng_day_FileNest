# frozen_string_literal: true

require 'socket'
require 'timeout'

module FileProcessing
  class VirusScanner
    include Singleton

    class ScanError < StandardError; end
    class VirusDetectedError < StandardError; end
    class ServiceUnavailableError < StandardError; end

    # Scan results
    SCAN_RESULT_CLEAN = 'clean'
    SCAN_RESULT_INFECTED = 'infected'
    SCAN_RESULT_ERROR = 'error'

    # ClamAV protocol constants
    CLAMD_COMMANDS = {
      ping: "zPING\0",
      version: "zVERSION\0",
      stats: "zSTATS\0",
      instream: "zINSTREAM\0"
    }.freeze

    def initialize
      @host = ENV.fetch('CLAMAV_HOST', 'localhost')
      @port = ENV.fetch('CLAMAV_PORT', 3310).to_i
      @timeout = ENV.fetch('CLAMAV_TIMEOUT', 30).to_i
      @chunk_size = 8192
    end

    # Main scanning method - returns scan result hash
    def scan_file(file_path_or_io)
      ensure_service_available!

      result = perform_scan(file_path_or_io)
      log_scan_result(file_path_or_io, result)
      result
    rescue VirusDetectedError => e
      Rails.logger.warn("Virus detected: #{e.message}")
      {
        status: SCAN_RESULT_INFECTED,
        threat: e.message,
        safe: false,
        scanned_at: Time.current
      }
    rescue => e
      Rails.logger.error("Virus scan failed: #{e.message}")
      handle_scan_failure(e)
    end

    # Convenience method that raises on virus detection
    def scan_file!(file_path_or_io)
      result = scan_file(file_path_or_io)

      if result[:status] == SCAN_RESULT_INFECTED
        raise VirusDetectedError, "Virus detected: #{result[:threat]}"
      elsif result[:status] == SCAN_RESULT_ERROR
        raise ScanError, "Scan failed: #{result[:error]}"
      end

      result
    end

    # Check if ClamAV service is available
    def service_available?
      begin
        ping_result = send_command(:ping)
        ping_result.strip == "PONG"
      rescue
        false
      end
    end

    # Get virus database version info
    def version_info
      send_command(:version).strip
    rescue => e
      Rails.logger.error("Failed to get ClamAV version: #{e.message}")
      nil
    end

    # Get virus database stats
    def stats
      send_command(:stats).strip
    rescue => e
      Rails.logger.error("Failed to get ClamAV stats: #{e.message}")
      nil
    end

    private

    def perform_scan(file_path_or_io)
      content = extract_file_content(file_path_or_io)
      scan_result = scan_content_via_instream(content)
      process_scan_result(scan_result, file_path_or_io)
    end

    def extract_file_content(file_path_or_io)
      case file_path_or_io
      when String
        unless File.exist?(file_path_or_io)
          raise ScanError, "File not found: #{file_path_or_io}"
        end
        File.binread(file_path_or_io)
      when ActionDispatch::Http::UploadedFile
        file_path_or_io.tempfile.rewind
        file_path_or_io.tempfile.read
      when File, Tempfile
        file_path_or_io.rewind if file_path_or_io.respond_to?(:rewind)
        file_path_or_io.read
      when StringIO
        file_path_or_io.rewind
        file_path_or_io.read
      else
        raise ArgumentError, "Unsupported file input type: #{file_path_or_io.class}"
      end
    end

    def scan_content_via_instream(content)
      Timeout.timeout(@timeout) do
        socket = TCPSocket.new(@host, @port)

        begin
          # Send INSTREAM command
          socket.write(CLAMD_COMMANDS[:instream])

          # Send file content in chunks
          content_io = StringIO.new(content)
          while chunk = content_io.read(@chunk_size)
            # Each chunk is prefixed with its size (4 bytes, network byte order)
            size_header = [chunk.bytesize].pack('N')
            socket.write(size_header + chunk)
          end

          # Send termination (zero-length chunk)
          socket.write([0].pack('N'))

          # Read response
          response = socket.read
          response.strip if response
        ensure
          socket.close if socket
        end
      end
    rescue Timeout::Error
      raise ScanError, "Scan timeout after #{@timeout} seconds"
    rescue Errno::ECONNREFUSED
      raise ServiceUnavailableError, "Cannot connect to ClamAV at #{@host}:#{@port}"
    rescue => e
      raise ScanError, "Network error during scan: #{e.message}"
    end

    def send_command(command)
      unless CLAMD_COMMANDS.key?(command)
        raise ArgumentError, "Unknown command: #{command}"
      end

      Timeout.timeout(@timeout) do
        socket = TCPSocket.new(@host, @port)

        begin
          socket.write(CLAMD_COMMANDS[command])
          response = socket.read
          response || ""
        ensure
          socket.close if socket
        end
      end
    rescue Timeout::Error
      raise ScanError, "Command timeout after #{@timeout} seconds"
    rescue Errno::ECONNREFUSED
      raise ServiceUnavailableError, "Cannot connect to ClamAV at #{@host}:#{@port}"
    rescue => e
      raise ScanError, "Network error: #{e.message}"
    end

    def process_scan_result(scan_result, file_identifier)
      return handle_empty_result(file_identifier) if scan_result.nil? || scan_result.empty?

      case scan_result
      when /stream: OK$/
        {
          status: SCAN_RESULT_CLEAN,
          safe: true,
          scanned_at: Time.current,
          file: file_identifier.to_s
        }
      when /stream: (.+) FOUND$/
        threat_name = $1
        raise VirusDetectedError, threat_name
      when /stream: (.+) ERROR$/
        error_detail = $1
        raise ScanError, "ClamAV scan error: #{error_detail}"
      when /ERROR/
        raise ScanError, "ClamAV error: #{scan_result}"
      else
        Rails.logger.warn("Unknown ClamAV response: #{scan_result}")
        raise ScanError, "Unknown scan result format"
      end
    end

    def handle_empty_result(file_identifier)
      Rails.logger.error("Empty response from ClamAV for #{file_identifier}")
      raise ScanError, "Empty response from ClamAV"
    end

    def ensure_service_available!
      unless service_available?
        raise ServiceUnavailableError, "ClamAV service is not available at #{@host}:#{@port}"
      end
    end

    def handle_scan_failure(error)
      # In production, decide whether to allow or block files when scanning fails
      fail_open = Rails.env.development? || ENV['VIRUS_SCAN_FAIL_OPEN'] == 'true'

      if fail_open
        Rails.logger.warn("Virus scan failed but allowing file due to fail-open policy: #{error.message}")
        {
          status: SCAN_RESULT_CLEAN,
          safe: true,
          warning: "Scan failed but allowed",
          error: error.message,
          scanned_at: Time.current
        }
      else
        {
          status: SCAN_RESULT_ERROR,
          safe: false,
          error: error.message,
          scanned_at: Time.current
        }
      end
    end

    def log_scan_result(file_identifier, result)
      case result[:status]
      when SCAN_RESULT_CLEAN
        Rails.logger.info("File scan clean: #{file_identifier}")
      when SCAN_RESULT_INFECTED
        Rails.logger.warn("File scan infected: #{file_identifier} - #{result[:threat]}")
        notify_virus_detection(file_identifier, result[:threat])
      when SCAN_RESULT_ERROR
        Rails.logger.error("File scan error: #{file_identifier} - #{result[:error]}")
      end
    end

    def notify_virus_detection(file_identifier, threat)
      # Hook for sending alerts to monitoring systems
      # You could integrate with services like:
      # - Slack notifications
      # - Email alerts
      # - Monitoring systems (DataDog, New Relic, etc.)

      Rails.logger.warn("SECURITY ALERT: Virus detected in uploaded file")
      Rails.logger.warn("File: #{file_identifier}")
      Rails.logger.warn("Threat: #{threat}")
      Rails.logger.warn("Timestamp: #{Time.current}")
      Rails.logger.warn("Host: #{@host}:#{@port}")
    end
  end
end
