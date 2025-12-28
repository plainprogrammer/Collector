# frozen_string_literal: true

module MTGJSON
  # Service to download MTGJSON AllPrintings.sqlite file from mtgjson.com or local path.
  #
  # Usage:
  #   service = MTGJSON::DownloadService.new
  #   result = service.call(destination: "path/to/save.sqlite")
  #   result = service.call(source: "https://custom.url/file.sqlite", destination: "path/to/save.sqlite")
  #   result = service.call(source: "/local/path/file.sqlite", destination: "path/to/save.sqlite")
  class DownloadService
    DEFAULT_MTGJSON_URL = "https://mtgjson.com/api/v5/AllPrintings.sqlite"

    # Downloads or copies MTGJSON data file.
    #
    # @param source [String] URL or local file path (defaults to MTGJSON official URL)
    # @param destination [String] Path where the file should be saved
    # @return [Hash] Result with :success boolean and :error message if failed
    def call(source: DEFAULT_MTGJSON_URL, destination:)
      if source.start_with?("http://", "https://")
        download_from_url(source, destination)
      else
        copy_from_local(source, destination)
      end
    rescue StandardError => e
      { success: false, error: "Download failed: #{e.message}" }
    end

    private

    def download_from_url(url, destination)
      require "net/http"
      require "uri"

      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        return { success: false, error: "HTTP error: #{response.code} #{response.message}" }
      end

      File.write(destination, response.body, mode: "wb")
      { success: true, destination: destination }
    end

    def copy_from_local(source, destination)
      unless File.exist?(source)
        return { success: false, error: "Source file not found: #{source}" }
      end

      FileUtils.cp(source, destination)
      { success: true, destination: destination }
    end
  end
end
