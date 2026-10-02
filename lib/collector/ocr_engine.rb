require "digest"
require "fileutils"
require "net/http"
require "rubygems/package"
require "stringio"
require "zlib"

module Collector
  # The self-hosted OCR engine (ADR 0001; spec 007 AC-2.2, AC-7.3): Tesseract.js 7.0.0, its three LSTM-only
  # core builds and the eng 4.0.0_best_int data. They're fetched from the npm registry as pinned tarballs,
  # checked file by file against pinned SHA-256 digests, and served by the app from /ocr/<VERSION>/.
  # Stdlib only: bin/fetch-ocr-engine runs it before the app boots (bin/setup, the Dockerfile build).
  module OcrEngine
    class Error < StandardError; end
    class IntegrityError < Error; end

    Package = Struct.new(:url, :sha256, :files, keyword_init: true) # files: { "path in tarball" => "served path" }

    VERSION = "v7.0.0"
    ROOT = File.expand_path("../../vendor/ocr/#{VERSION}", __dir__)
    REGISTRY = "https://registry.npmjs.org"
    # Any fixed time: the pinned files never change, so Last-Modified never needs to.
    PUBLISHED_AT = Time.utc(2026, 9, 30)
    CORES = %w[lstm simd-lstm relaxedsimd-lstm].freeze
    PACKAGES = [
      Package.new(url: "#{REGISTRY}/tesseract.js/-/tesseract.js-7.0.0.tgz",
        sha256: "9a93bf51c3387f945d10a24bf8b3a4bf2e45c7c7161b8242aafbaf9d3c4b606a",
        files: { "package/dist/tesseract.min.js" => "tesseract.min.js", "package/dist/worker.min.js" => "worker.min.js" }),
      Package.new(url: "#{REGISTRY}/tesseract.js-core/-/tesseract.js-core-7.0.0.tgz",
        sha256: "ba584355515eaff877552022853c0e71f2cb70466e759d1d6940484929718ee0",
        files: CORES.to_h { [ "package/tesseract-core-#{it}.wasm.js", "core/tesseract-core-#{it}.wasm.js" ] }),
      Package.new(url: "#{REGISTRY}/@tesseract.js-data/eng/-/eng-1.0.0.tgz",
        sha256: "c9bddf2e2f0a214ac7918f3f4a3caf45e09ce8674fe26662ae7787ac8927f7bb",
        files: { "package/4.0.0_best_int/eng.traineddata.gz" => "lang/eng.traineddata.gz" })
    ].freeze
    FILES = {
      "tesseract.min.js" => "000c27d9cd0def655f77b36c72a389c0ab13793aa31cb4d7aab56d09c0afbc7e",
      "worker.min.js" => "576b7df7e3393e137e51849357c9adb53fe7ac1bb69bfa06cf3d61520f182c6d",
      "core/tesseract-core-lstm.wasm.js" => "eef5f8b2f8e20e150680b20adaec4a60babafee3adbe8a94583c81fee46e8680",
      "core/tesseract-core-simd-lstm.wasm.js" => "c58b46a4c796c0b8afccf77591d5b875b6896b45d402bbce8caa6f5362447b38",
      "core/tesseract-core-relaxedsimd-lstm.wasm.js" => "861a536cf9ef8e63cb644d57bab39c388f37f7d6b6f60024b741c5f6b39a59b3",
      "lang/eng.traineddata.gz" => "45b4cb346724ac1774f1c36f42f182b887bcdb28ebe63e6fff90ac41f3fcff91"
    }.freeze
    CONTENT_TYPES = { ".js" => "text/javascript", ".gz" => "application/gzip" }.freeze

    module_function

    def path_for(relative) = FILES.key?(relative) ? File.join(ROOT, relative) : nil

    def content_type(path) = CONTENT_TYPES.fetch(File.extname(path))

    def intact?(path, digest) = File.file?(path) && Digest::SHA256.file(path).hexdigest == digest

    # Fetches whatever is missing or damaged, verifies it, and returns the served paths written.
    def install!(root: ROOT, packages: PACKAGES, files: FILES, download: method(:download))
      packages.flat_map do |package|
        wanted = package.files.reject { |_, served| intact?(File.join(root, served), files.fetch(served)) }
        next [] if wanted.empty?

        tarball = download.call(package.url)
        check!(package.url, Digest::SHA256.hexdigest(tarball), package.sha256)
        unpack(tarball, wanted).each { |served, data| check!(served, Digest::SHA256.hexdigest(data), files.fetch(served)) }
          .map { |served, data| write(File.join(root, served), data) && served }
      end
    end

    def check!(what, actual, expected)
      raise IntegrityError, "#{what}: sha256 #{actual}, expected #{expected}" unless actual == expected
    end

    def unpack(tarball, wanted)
      found = {}
      Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(tarball))) do |tar|
        tar.each { |entry| found[wanted.fetch(entry.full_name)] = entry.read if wanted.key?(entry.full_name) }
      end
      missing = wanted.values - found.keys
      raise IntegrityError, "missing from the tarball: #{missing.join(", ")}" if missing.any?

      found
    end

    def write(path, data)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite("#{path}.part", data)
      File.rename("#{path}.part", path)
    end

    def download(url, redirects: 3)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 60) do |http|
        http.get(uri.request_uri, "User-Agent" => "Collector OCR engine fetch")
      end
      case response
      when Net::HTTPSuccess then response.body
      when Net::HTTPRedirection
        raise Error, "#{url}: too many redirects" if redirects.zero?

        download(response.fetch("location"), redirects: redirects - 1)
      else raise Error, "#{url}: HTTP #{response.code}"
      end
    end
  end
end
