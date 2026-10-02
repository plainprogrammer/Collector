require "fileutils"
require "rack"
require "securerandom"
require "time"

module CardScannerPhase2
  # One origin for the detect page, the pinned OpenCV.js build, the settings, the photos and the working files
  # (to this machine only), plus a sink for the page's outputs. Sends the scanner page's Content Security Policy
  # as the app sends it today (ScannerPage's directives plus a per-request nonce), with a report endpoint added
  # so violations are recorded (AC-2.8).
  class Server
    IMMUTABLE = { "cache-control" => "public, max-age=31536000, immutable" }.freeze
    LOOPBACK = %w[127.0.0.1 ::1].freeze
    OUTPUT_PATH = %r{\A/outputs/([\w-]+)/([\w-]+)/([\w-]+\.(?:png|json))\z}

    def initialize(public_dir:, opencv_dir:, corpus_dir:, work_dir:, runs_dir:, log_dir:, settings_path:, unsafe_eval: false)
      @public = Rack::Files.new(public_dir.to_s)
      @opencv = Rack::Files.new(opencv_dir.to_s, IMMUTABLE)
      @corpus = Rack::Files.new(corpus_dir.to_s)
      @work = Rack::Files.new(work_dir.to_s)
      @runs_dir = Pathname(runs_dir)
      @log_dir = Pathname(log_dir)
      @settings_path = Pathname(settings_path)
      @unsafe_eval = unsafe_eval
      FileUtils.mkdir_p(log_dir)
    end

    def call(env)
      request = Rack::Request.new(env)
      status, headers, body = route(request)
      [ status, headers.to_h.merge("content-security-policy" => policy(SecureRandom.base64(16))), body ]
    end

    # ScannerPage's directives, in its order, plus the nonce the app adds and this server's report-uri.
    def policy(nonce)
      script = [ "'self'", "'wasm-unsafe-eval'", ("'unsafe-eval'" if @unsafe_eval), "'nonce-#{nonce}'" ].compact.join(" ")
      [ "default-src 'self'", "script-src #{script}", "worker-src 'self' blob:", "connect-src 'self'", "img-src 'self' data: blob:",
        "style-src 'self' 'unsafe-inline'", "font-src 'self'", "object-src 'none'", "frame-src 'none'", "base-uri 'self'",
        "form-action 'self'", "frame-ancestors 'self'", "report-uri /csp-report" ].join("; ")
    end

    private
      def route(request)
        path = request.path_info
        case [ request.request_method, path ]
        in [ "GET", "/settings.json" ] then respond(200, "application/json", @settings_path.read)
        in [ "GET", %r{\A/opencv/} ] then delegate(@opencv, request, path.delete_prefix("/opencv"))
        in [ "GET", %r{\A/corpus/} ] then local?(request) ? delegate(@corpus, request, path.delete_prefix("/corpus")) : text(403, "Forbidden")
        in [ "GET", %r{\A/work/} ] then local?(request) ? delegate(@work, request, path.delete_prefix("/work")) : text(403, "Forbidden")
        in [ "POST", %r{\A/outputs/} ] then local?(request) ? save_output(request, path) : text(403, "Forbidden")
        in [ "POST", "/csp-report" ] then save_csp_report(request)
        in [ "GET", _ ] then delegate(@public, request, path)
        else text(405, "Method not allowed")
        end
      end

      def delegate(files, request, path) = files.call(request.env.merge("PATH_INFO" => path))

      def local?(request) = LOOPBACK.include?(request.ip)

      def save_output(request, path)
        match = OUTPUT_PATH.match(path) or return text(400, "Output path must be /outputs/<run>/<stem>/<name>.png|json")
        run, stem, name = match.captures
        target = @runs_dir.join(run, stem, name)
        target.dirname.mkpath
        target.binwrite(request.body.read)
        respond(201, "application/json", { saved: target.relative_path_from(@runs_dir).to_s }.to_json)
      end

      def save_csp_report(request)
        @log_dir.join("csp-reports.jsonl").open("a") { it.puts(request.body.read.tr("\n", " ")) }
        [ 204, {}, [] ]
      end

      def text(status, message) = respond(status, "text/plain", message)

      def respond(status, type, content)
        [ status, { "content-type" => type, "content-length" => content.bytesize.to_s }, [ content ] ]
      end
  end
end
