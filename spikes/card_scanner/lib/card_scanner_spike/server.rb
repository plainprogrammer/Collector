require "fileutils"
require "json"
require "rack"
require "securerandom"
require "time"

module CardScannerSpike
  # Serves the spike pages, the pinned OCR engine and (to this machine only) the
  # photo corpus from one origin, under a self-only CSP, logging each response's
  # size (FR-2, AC-1.6, NFR Security).
  class Server
    CSP = [ "default-src 'self'", "script-src 'self' 'wasm-unsafe-eval'", "worker-src 'self' blob:",
            "connect-src 'self'", "report-uri /csp-report" ].join("; ").freeze
    IMMUTABLE = { "cache-control" => "public, max-age=31536000, immutable" }.freeze
    LOOPBACK = %w[127.0.0.1 ::1].freeze
    PHOTO = /\.jpe?g\z/i

    def initialize(public_dir:, ocr_dir:, corpus_dir:, log_dir:)
      @public = Rack::Files.new(public_dir)
      @ocr = Rack::Files.new(ocr_dir, IMMUTABLE)
      @corpus_dir = corpus_dir
      @corpus = Rack::Files.new(corpus_dir)
      @log_dir = log_dir
      FileUtils.mkdir_p(log_dir)
    end

    def call(env)
      request = Rack::Request.new(env)
      status, headers, body = route(request)
      headers = headers.to_h.merge("content-security-policy" => CSP)
      log(request, status, headers)
      [ status, headers, body ]
    end

    private
      def route(request)
        path = request.path_info
        case [ request.request_method, path ]
        in [ "POST", "/timings" ] then save_timings(request)
        in [ "POST", "/csp-report" ] then save_csp_report(request)
        in [ "GET", "/corpus/index.json" ] then local?(request) ? corpus_index : text(403, "Forbidden")
        in [ "GET", %r{\A/corpus/} ] then local?(request) ? delegate(@corpus, request, path.delete_prefix("/corpus")) : text(403, "Forbidden")
        in [ "GET", %r{\A/ocr/} ] then revalidating?(request) ? [ 304, {}, [] ] : delegate(@ocr, request, path.delete_prefix("/ocr"))
        in [ "GET", _ ] then delegate(@public, request, path)
        else text(405, "Method not allowed")
        end
      end

      def delegate(files, request, path) = files.call(request.env.merge("PATH_INFO" => path))

      def local?(request) = LOOPBACK.include?(request.ip)

      # The engine files are pinned by version in their path, so a revalidation never needs a body.
      # Safari ignores `immutable` and revalidates on reload; answering 304 keeps warm runs honest (AC-1.6).
      def revalidating?(request) = request.has_header?("HTTP_IF_MODIFIED_SINCE") || request.has_header?("HTTP_IF_NONE_MATCH")

      def corpus_index
        json(200, Dir.exist?(@corpus_dir) ? Dir.children(@corpus_dir).grep(PHOTO).sort : [])
      end

      def save_timings(request)
        timings = JSON.parse(request.body.read)
        name = "timings-#{Time.now.utc.strftime("%Y%m%dT%H%M%S")}-#{SecureRandom.hex(3)}.json"
        File.write(File.join(@log_dir, name), JSON.pretty_generate(timings))
        json(201, { saved: name })
      rescue JSON::ParserError
        text(400, "Timings must be JSON")
      end

      def save_csp_report(request)
        File.open(File.join(@log_dir, "csp-reports.jsonl"), "a") { it.puts(request.body.read.tr("\n", " ")) }
        [ 204, {}, [] ]
      end

      def log(request, status, headers)
        entry = { at: Time.now.utc.iso8601(3), ip: request.ip, method: request.request_method, path: request.path_info,
                  status:, bytes: headers["content-length"].to_i, user_agent: request.user_agent }
        File.open(File.join(@log_dir, "requests.jsonl"), "a") { it.puts(entry.to_json) }
      end

      def json(status, value) = respond(status, "application/json", value.to_json)

      def text(status, message) = respond(status, "text/plain", message)

      def respond(status, type, content)
        [ status, { "content-type" => type, "content-length" => content.bytesize.to_s }, [ content ] ]
      end
  end
end
