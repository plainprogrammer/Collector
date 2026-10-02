require "digest"
require "net/http"
require "uri"

module CardScannerPhase2
  # Fetches the official prebuilt OpenCV.js build into tmp/card_scanner_phase2/opencv/<version>/, verified
  # against a pinned SHA-256, never committed (AC-2.7). One file: it embeds its WebAssembly as base64.
  module OpencvAsset
    class IntegrityError < StandardError; end

    Pin = Struct.new(:url, :sha256, :served, keyword_init: true)
    VERSION = "4.13.0"
    PIN = Pin.new(url: "https://docs.opencv.org/#{VERSION}/opencv.js",
      sha256: "63366510248adf3a7eddf3e793dd825404efb7df3749f4d6f8557c7fa4ca8aa0", served: "#{VERSION}/opencv.js").freeze
    ROOT = WORK_DIR.join("opencv")
    USER_AGENT = "Collector card scanner spike (+https://github.com/plainprogrammer/Collector)"

    module_function

    def intact?(path, digest) = path.file? && Digest::SHA256.file(path.to_s).hexdigest == digest

    def install!(root: ROOT, pin: PIN, download: method(:download))
      target = Pathname(root).join(pin.served)
      return nil if intact?(target, pin.sha256)

      data = download.call(pin.url)
      actual = Digest::SHA256.hexdigest(data)
      raise IntegrityError, "#{pin.url}: sha256 #{actual}, expected #{pin.sha256}" unless actual == pin.sha256

      target.dirname.mkpath
      partial = Pathname("#{target}.part")
      partial.binwrite(data)
      partial.rename(target)
      target
    end

    def download(url, redirects: 3)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 120) do |http|
        http.request(Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT))
      end
      case response
      when Net::HTTPSuccess then response.body
      when Net::HTTPRedirection then redirects.positive? ? download(response["location"], redirects: redirects - 1) : raise(IntegrityError, "too many redirects")
      else raise IntegrityError, "#{url}: HTTP #{response.code}"
      end
    end
  end
end
