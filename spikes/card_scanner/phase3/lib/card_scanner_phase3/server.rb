require "fileutils"
require "rack"
require "securerandom"
require "time"

module CardScannerPhase3
  # The art spike's server (spec 010 FR-2). Over the LAN (the phone) it serves only the timing page and what it needs: the
  # fingerprint settings, spec 008's search and fingerprint modules, the gzipped index, the query fingerprints and the
  # straightened cards, and it takes the page's results on one path. Everything else (the replay page, the app's scanner
  # modules, the working folder, the corpus) is for this machine only. LAN responses carry a strict policy, with no inline
  # script.
  class Server
    LOOPBACK = %w[127.0.0.1 ::1].freeze
    IMMUTABLE = "public, max-age=31536000, immutable"
    MAX_RESULTS = 1_000_000
    POLICY = [ "default-src 'self'", "script-src 'self'", "connect-src 'self'", "img-src 'self'", "style-src 'self'", "object-src 'none'",
               "base-uri 'self'", "frame-ancestors 'none'", "report-uri /csp-report" ].join("; ")
    PHONE_MODULES = %w[search.js fingerprint.js].freeze

    def initialize(phase2_public:, phase3_public:, app_scanner:, work_dir:, corpus_dir:, runs_dir:, settings_path:, queries_path:, cards_dir:)
      @phase2 = Rack::Files.new(phase2_public.to_s)
      @phase3 = Rack::Files.new(phase3_public.to_s)
      @app_scanner = Rack::Files.new(app_scanner.to_s)
      @work = Rack::Files.new(work_dir.to_s)
      @corpus = Rack::Files.new(corpus_dir.to_s)
      @work_dir, @runs_dir, @settings_path, @queries_path, @cards_dir = Pathname(work_dir), Pathname(runs_dir), Pathname(settings_path), Pathname(queries_path), Pathname(cards_dir)
    end

    def call(env)
      request = Rack::Request.new(env)
      status, headers, body = route(request)
      headers = headers.to_h
      headers = headers.merge("content-security-policy" => POLICY) unless request.path_info.match?(%r{\A/(replay|app/scanner/|work/|corpus/)})
      [ status, headers, body ]
    end

    private
      def route(request)
        path = request.path_info
        if request.post?
          case path
          when "/phone/results" then save_results(request)
          when "/csp-report" then save_report(request)
          else text(404, "Not found")
          end
        elsif request.get?
          get(request, path)
        else
          text(405, "Method not allowed")
        end
      end

      def get(request, path)
        case path
        when "/phone/timing.html", "/phone/timing.js" then delegate(@phase3, request, path.delete_prefix("/phone"))
        when "/settings.json" then json(200, { "fingerprint" => JSON.parse(@settings_path.read).fetch("fingerprint") })
        when "/phone/index.bin" then index
        when "/phone/queries.json" then json(200, JSON.parse(@queries_path.read))
        when %r{\A/phone/cards/(IMG_\d+)\.png\z} then card(Regexp.last_match(1))
        when %r{\A/phase2/([\w.]+)\z} then PHONE_MODULES.include?(Regexp.last_match(1)) ? delegate(@phase2, request, path.delete_prefix("/phase2")) : text(404, "Not found")
        when "/replay.html", "/replay.js" then local(request) { delegate(@phase3, request, path) }
        when %r{\A/app/scanner/} then local(request) { delegate(@app_scanner, request, path.delete_prefix("/app/scanner")) }
        when %r{\A/work/} then local(request) { delegate(@work, request, path.delete_prefix("/work")) }
        when %r{\A/corpus/} then local(request) { delegate(@corpus, request, path.delete_prefix("/corpus")) }
        else text(404, "Not found")
        end
      end

      # The socket's own address: Rack's request.ip trusts X-Forwarded-For from private addresses, which a LAN client could forge.
      def local(request) = LOOPBACK.include?(request.get_header("REMOTE_ADDR")) ? yield : text(403, "Forbidden")

      def delegate(files, request, path) = files.call(request.env.merge("PATH_INFO" => path))

      def index
        file = @work_dir.join("index/art_index.bin.gz")
        return text(404, "No gzipped index; run gzip_index.rb") unless file.file?

        [ 200, { "content-type" => "application/octet-stream", "content-encoding" => "gzip", "cache-control" => IMMUTABLE,
                 "content-length" => file.size.to_s }, [ file.binread ] ]
      end

      def card(stem)
        file = @cards_dir.join(stem, "card.png")
        file.file? ? [ 200, { "content-type" => "image/png", "content-length" => file.size.to_s }, [ file.binread ] ] : text(404, "Not found")
      end

      def save_results(request)
        body = request.body.read(MAX_RESULTS + 1).to_s
        return text(413, "Too large") if body.bytesize > MAX_RESULTS

        dir = @runs_dir.join("phone")
        dir.mkpath
        target = dir.join("#{Time.now.utc.strftime("%Y%m%dT%H%M%S")}-#{SecureRandom.hex(3)}.json")
        target.write(body)
        json(201, { "saved" => target.basename.to_s })
      end

      def save_report(request)
        dir = @runs_dir.join("phone")
        dir.mkpath
        dir.join("csp-reports.jsonl").open("a") { it.puts(request.body.read(10_000).to_s.tr("\n", " ")) }
        [ 204, {}, [] ]
      end

      def json(status, object) = respond(status, "application/json", object.to_json)
      def text(status, message) = respond(status, "text/plain", message)
      def respond(status, type, content) = [ status, { "content-type" => type, "content-length" => content.bytesize.to_s }, [ content ] ]
  end
end
