# frozen_string_literal: true

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

    def initialize
      @client = nil
      @connection_retries = 3
      @connection_timeout = 10
      @scan_timeout = 30
    end

    # Main scanning method - returns scan result hash
    def scan_file(file_path_or_io)
      ensure_connection!

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
      return false unless clamav_available?

      begin
        ensure_connection!
        ping_result = @client.ping
        ping_result == "PONG"
      rescue
        false
      end
    end

    # Get virus database version info
    def version_info
      ensure_connection!
      @client.version
    rescue => e
      Rails.logger.error("Failed to get ClamAV version: #{e.message}")
      nil
    end

    # Get virus database stats
    def stats
      ensure_connection!
      @client.stats
    rescue => e
      Rails.logger.error("Failed to get ClamAV stats: #{e.message}")
      nil
    end

    private

    def perform_scan(file_path_or_io)
      case file_path_or_io
      when String
        scan_file_path(file_path_or_io)
      when File, Tempfile, StringIO, ActionDispatch::Http::UploadedFile
        scan_file_stream(file_path_or_io)
      else
        raise ArgumentError, "Unsupported file input type: #{file_path_or_io.class}"
      end
    end

    def scan_file_path(file_path)
      unless File.exist?(file_path)
        raise ScanError, "File not found: #{file_path}"
      end

      unless File.readable?(file_path)
        raise ScanError, "File not readable: #{file_path}"
      end

      scan_result = @client.scan(file_path)
      process_scan_result(scan_result, file_path)
    end

    def scan_file_stream(file_stream)
      # Extract content for scanning
      content = extract_content(file_stream)

      # Create a temporary file for scanning
      temp_file = Tempfile.new(['virus_scan', '.tmp'])
      begin
        temp_file.binmode
        temp_file.write(content)
        temp_file.close

        scan_result = @client.scan(temp_file.path)
        process_scan_result(scan_result, file_stream.inspect)
      ensure
        temp_file.unlink if temp_file
      end
    end

    def extract_content(file_stream)
      case file_stream
      when ActionDispatch::Http::UploadedFile
        file_stream.tempfile.rewind
        file_stream.tempfile.read
      when File, Tempfile
        file_stream.rewind if file_stream.respond_to?(:rewind)
        file_stream.read
      when StringIO
        file_stream.rewind
        file_stream.read
      else
        raise ArgumentError, "Cannot extract content from #{file_stream.class}"
      end
    end

    def process_scan_result(scan_result, file_identifier)
      case scan_result
      when /^.*: OK$/
        {
          status: SCAN_RESULT_CLEAN,
          safe: true,
          scanned_at: Time.current,
          file: file_identifier
        }
      when /^.*: (.+) FOUND$/
        threat_name = $1
        raise VirusDetectedError, threat_name
      when /^.*: ERROR$/
        raise ScanError, "ClamAV scan error for #{file_identifier}"
      else
        raise ScanError, "Unknown scan result: #{scan_result}"
      end
    end

    def ensure_connection!
      return if @client && connection_healthy?

      @client = connect_to_clamav
    end

    def connect_to_clamav
      require 'clamav'

      retries = 0
      begin
        # Try to connect using the configured method
        client = create_clamav_client

        # Test the connection
        client.ping
        Rails.logger.info("Successfully connected to ClamAV")
        client
      rescue => e
        retries += 1
        if retries <= @connection_retries
          Rails.logger.warn("ClamAV connection attempt #{retries} failed: #{e.message}")
          sleep(1)
          retry
        else
          raise ServiceUnavailableError, "Could not connect to ClamAV after #{@connection_retries} attempts: #{e.message}"
        end
      end
    end

    def create_clamav_client
      # Try different connection methods in order of preference
      connection_configs = [
        socket_connection_config,
        tcp_connection_config
      ].compact

      connection_configs.each do |config|
        begin
          return ClamAV::Client.new(config)
        rescue => e
          Rails.logger.debug("Failed to connect with #{config}: #{e.message}")
          next
        end
      end

      raise ServiceUnavailableError, "All ClamAV connection methods failed"
    end

    def socket_connection_config
      socket_path = find_clamav_socket
      return nil unless socket_path

      {
        socket: socket_path,
        timeout: @connection_timeout
      }
    end

    def tcp_connection_config
      host = ENV.fetch('CLAMAV_HOST', 'localhost')
      port = ENV.fetch('CLAMAV_PORT', 3310).to_i

      {
        host: host,
        port: port,
        timeout: @connection_timeout
      }
    end

    def find_clamav_socket
      # Try common socket paths
      possible_paths = [
        ENV['CLAMAV_SOCKET_PATH'],        # Environment override
        '/var/run/clamav/clamd.ctl',      # Linux default
        '/usr/local/var/run/clamav/clamd.sock', # macOS Homebrew
        '/tmp/clamd.socket',              # Alternative
        '/var/run/clamd.socket',          # Another common path
        '/run/clamav/clamd.ctl'           # systemd path
      ].compact

      possible_paths.find { |path| File.exist?(path) && File.socket?(path) }
    end

    def connection_healthy?
      return false unless @client

      begin
        @client.ping == "PONG"
      rescue
        false
      end
    end

    def clamav_available?
      # Check if ClamAV binaries are available
      system('which clamd > /dev/null 2>&1') ||
      system('which clamdscan > /dev/null 2>&1') ||
      ENV['CLAMAV_HOST'].present?
    end

    def handle_scan_failure(error)
      # In production, you might want to decide whether to allow or block files
      # when scanning fails. For security, we default to blocking.
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
        # Optional: Send alert to monitoring system
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
    end
  end
end
