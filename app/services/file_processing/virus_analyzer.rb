# frozen_string_literal: true

module FileProcessing
  class VirusAnalyzer < ActiveStorage::Analyzer
    include ActiveStorage::Downloading

    def self.accept?(blob)
      # Analyze all blobs for viruses
      true
    end

    def metadata
      download_blob_to_tempfile do |file|
        scanner = VirusScanner.instance

        begin
          result = scanner.scan_file(file.path)

          {
            virus_scan: {
              status: result[:status],
              safe: result[:safe],
              scanned_at: result[:scanned_at]&.iso8601,
              threat: result[:threat],
              error: result[:error],
              warning: result[:warning]
            }
          }
        rescue => e
          Rails.logger.error("Virus analysis failed: #{e.message}")

          # Return metadata indicating scan failure
          {
            virus_scan: {
              status: VirusScanner::SCAN_RESULT_ERROR,
              safe: false,
              scanned_at: Time.current.iso8601,
              error: e.message
            }
          }
        end
      end
    end

    private

    def blob
      @blob
    end
  end
end
