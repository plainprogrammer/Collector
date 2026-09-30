# Implementation Plan: Card Scanner Phase 0 — Feasibility Spikes

**Spec:** docs/specs/005-card-scanner-phase-0/spec.md (v1.1.0, Approved; v1.1.1 PATCH in Phase 0)
**Decisions:** none yet. This feature *produces* ADRs 0001–0003 (Phase 8)
**Created:** 2026-09-30

## Context

Phase 1 of the card scanner rests on three unproven assumptions:
- browser OCR can read card strips from real iPhone photos;
- a trigram index can find garbled names quickly;
- a camera page can be tested headlessly.

This plan builds a small throwaway spike harness under `spikes/card_scanner/`, runs it on the maintainer's photos and iPhone, and turns the measurements into `research.md`, three Proposed ADRs and text-only fixtures. Nothing enters `app/`, `public/`, `vendor/`, `config/`, `db/` or the `Gemfile` (AC-4.5).

**Facts established during planning (2026-09-30):**
- The npm registry has `tesseract.js@7.0.0`, which depends on `tesseract.js-core ^7.0.0`; core 7.0.0 is published, although the `latest` tag still points to 6.1.2. `@tesseract.js-data/eng@1.0.0` is about 13.9 MB unpacked. We download the tarballs straight from `registry.npmjs.org` with `curl`, so no Node toolchain is involved.
- SQLite is 3.53.2. `fts5` with `tokenize='trigram remove_diacritics 1'` creates fine. Rails 8.1.4 has `create_virtual_table(name, module, values)`, and its dumper writes `create_virtual_table "t", "fts5", [args split on ", "]`. AC-3.1 tests whether that round trip holds.
- The stdlib `DidYouMean::JaroWinkler.distance` is available (for example, "lightning bolt" vs "lightnlng bolt" scores 0.925), so no gem is needed. `Rack::Mime` maps `.wasm` to `application/wasm`. Rack 3.2.7, Puma 8.0.2 and `selenium-webdriver` are already in the bundle.
- On this machine: Firefox and ffmpeg are installed, Chrome is not (Selenium Manager downloads Chrome for Testing on demand), and Node is v24.
- Catalog: `Catalog::Entry` has `number`, `language`, `name`, `set` (`Catalog::Set#code`, lowercase) and `released_on`, with scopes `active` and `searchable`. `MTG::Printing` has `faces` (JSON with `name`), `border_color` and `variant_tags` (which includes `frame_effects` such as `showcase`). There's no unique index on set + number + language, so "ambiguous" is possible. This worktree's dev database has to be refreshed first (a 69 s baseline).
- A top-level `spikes/` directory isn't autoloaded by Zeitwerk, isn't in `bin/rspec`'s `spec/**` pattern, and Brakeman ignores it. RuboCop **does** lint it, so the spike Ruby is kept lint-clean (no `.rubocop.yml` change needed).

**Plan decisions (not spelled out in the spec):**
- **Spike page origin:** a static Rack app (`CardScannerSpike::Server`) under the spike's own Puma config (`spikes/card_scanner/puma.rb`, port 4100, bound to `0.0.0.0` for the iPhone). This is the spec's "static file server over the spike directory" option. The Rails server is left untouched.
- **Security policy:** the spec's quoted header would block the engine. WebAssembly compilation needs `'wasm-unsafe-eval'`, and photos drawn from the file picker need `img-src blob:`. Phase 0 applies a **PATCH (1.1.1)** that keeps "every source is `'self'` or a scheme, no other host", and quotes the header actually sent: `default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; img-src 'self' blob: data:; worker-src 'self' blob:; connect-src 'self'; report-uri /csp-report`. Any violation is POSTed back and logged, and zero reports is part of the evidence.
- **Guide:** a photo has no live overlay, so the "card-shaped guide" is a fixed rectangle: centred, 90% of the image height, 63:88 aspect. The photo protocol tells the maintainer to fill it. The strip positions are tuned once on a 5-photo pilot, then frozen before the measured runs (the findings say so).
- **Ground truth:** the maintainer writes `manifest.csv` (`file,set,number,foil[,era]`). A builder derives the catalog name, the name-bar (front face) name, whether the card is borderless or showcase, and the era from the release date (before 2014-07-18 is pre-M15; before 2023-04-21 is M15–ONE; otherwise MOM+). The `era` column overrides it.
- **Name index:** built in its own SQLite file (`tmp/card_scanner_spike/names.sqlite3`), not in the app schema. The query ORs the query's trigrams, takes the top 50 by `bm25`, re-ranks by Jaro-Winkler and de-duplicates per card. Queries shorter than 3 characters use an exact or prefix match on the normalised column.
- **Camera spike:** it compares (a) Firefox's fake camera, which is synthetic, (b) Chrome with `--use-file-for-fake-video-capture` fed a `.y4m` made by ffmpeg, and (c) an in-page `getUserMedia` substitution in Firefox that streams a canvas drawn from the photo. The card-specific assertion is a 256-bit average hash of the captured frame against the source photo, both computed in the page.
- **Spike specs** run manually: `bundle exec rspec spikes/card_scanner/spec`. The pure-Ruby specs load `spike_helper`; the catalog-backed ones load `rails_helper`, so they use the test database and factories. None of them are part of `bin/ci`.

## Global Constraints

- No changes under `app/`, `public/`, `vendor/`, `config/` or `db/`, and no `Gemfile` change. The branch may touch only `docs/`, `spikes/card_scanner/` and `spec/fixtures/card_scanner/` (AC-4.5).
- No photo, crop or derived image is committed. The photos live in `$CARD_SCANNER_CORPUS` (default `~/card-scanner-corpus`); crops and working files go under `tmp/card_scanner_spike/`, which is already ignored (FR-1).
- No photo is sent to a third party. The OCR engine, worker and language data load from the spike page's own origin (FR-2).
- Phase 0 sets no pass or fail thresholds. Every number carries its sample size, and estimates are labelled as estimates (FR-4).
- English only. Japanese, art hashing and rectification are out of scope.
- Spike Ruby is RuboCop-clean. `bin/ci` passes at every commit.
- One Conventional Commit per step, with scope `spike` or `docs`. Branch `005-card-scanner-phase-0` (it already exists).

---

## Goal

A throwaway spike harness plus measured findings (`research.md`, ADRs 0001–0003 Proposed, JSON fixtures) that let the maintainer decide on Phase 1's OCR-based scanner.

**Components (Simplicity Gate: 3):**
1. The spike server and pages (`CardScannerSpike::Server`, `ocr.html`/`ocr.js`, `camera.html`/`camera.js`).
2. The Ruby analysis library (`Normaliser`, `CollectorLine`, `PrintingLookup`, `GroundTruth`, `NameIndex`, `Scoring`, `Rates`, `Timings`).
3. Measurement scripts (`spikes/card_scanner/script/`).

**Human checkpoints (the maintainer):**
- Phase 2: 5 pilot photos.
- Phase 3: the full corpus and `manifest.csv`.
- Phase 6: iPhone cold and warm runs, plus opening the firewall port.

---

## Phase 0: Spec patch and doc-first commit

**Implements:** — | **Satisfies:** — (enables all)
**Files:** `docs/specs/005-card-scanner-phase-0/{spec.md,plan.md}`
**Interfaces:** Consumes: nothing. Produces: spec v1.1.1 and this plan on the branch.

- [ ] Using `sdd-superpowers:sdd-spec-update`, apply PATCH 1.1.1 to spec NFR "Security and privacy" bullet 2. Replace the quoted header with: "served with a Content Security Policy in which every directive allows only `'self'`, the `blob:`/`data:` schemes, or `'wasm-unsafe-eval'` (no other host), with violations reported to the page's own origin". Add a changelog row: "1.1.1: the quoted header blocked WebAssembly and picked photos; same intent (no other host)".
- [ ] Write this plan to `docs/specs/005-card-scanner-phase-0/plan.md`.
- [ ] Commit: `docs(spec): add plan for 005 and patch the spike CSP (v1.1.1)`

---

## Phase 1: Spike skeleton, name normaliser and collector-line parser

**Implements:** FR-2 (normalisation), FR-3 (parsing) | **Satisfies:** AC-1.4
**Files:** `spikes/card_scanner/lib/card_scanner_spike.rb`, `spikes/card_scanner/lib/card_scanner_spike/{normaliser,collector_line}.rb`, `spikes/card_scanner/spec/spike_helper.rb`, `spikes/card_scanner/spec/card_scanner_spike/{normaliser,collector_line}_spec.rb`
**Interfaces:** Consumes: nothing. Produces:
- `CardScannerSpike::ROOT`, `WORK_DIR`, `FIXTURE_DIR` and `.corpus_dir`;
- `Normaliser.call(text) -> String`;
- `CollectorLine.parse(text, known_set_codes:) -> Result(set_code, number, language, foil, format)`, where `set_code` is upper case or nil, `number` is a String without leading zeros or nil, `language` is a Scryfall code or nil, `foil` is true, false or nil, and `format` is `:slash`, `:rarity_first` or nil.

- [ ] Create the entry file `spikes/card_scanner/lib/card_scanner_spike.rb`. It requires only the pure-Ruby parts, and each later step appends its own `require_relative`. Rails-backed and SQLite-backed files are required where they're used.
  ```ruby
  # Throwaway Phase 0 spike code (spec 005). Not autoloaded, not served by the app.
  module CardScannerSpike
    ROOT = File.expand_path("..", __dir__)
    WORK_DIR = File.expand_path("../../../tmp/card_scanner_spike", __dir__)
    FIXTURE_DIR = File.expand_path("../../../spec/fixtures/card_scanner", __dir__)

    def self.corpus_dir = File.expand_path(ENV.fetch("CARD_SCANNER_CORPUS", "~/card-scanner-corpus"))
  end
  ```
  and `spikes/card_scanner/spec/spike_helper.rb`:
  ```ruby
  # Loads the Phase 0 spike code (spec 005) for its specs; these are not part of bin/ci.
  $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
  require "card_scanner_spike"
  ```
- [ ] Write the failing spec `spikes/card_scanner/spec/card_scanner_spike/normaliser_spec.rb`:
  ```ruby
  require_relative "../spike_helper"

  RSpec.describe CardScannerSpike::Normaliser do
    it "folds ligatures, diacritics, case and punctuation", :aggregate_failures do
      expect(described_class.call("Æther Vial")).to eq("aether vial")
      expect(described_class.call("Lim-Dûl's Vault")).to eq("lim duls vault")
      expect(described_class.call("  Jötun   Grunt\n")).to eq("jotun grunt")
      expect(described_class.call("Fire // Ice")).to eq("fire ice")
    end

    it "folds full-width characters" do
      expect(described_class.call("Ｌｉｇｈｔｎｉｎｇ Bolt")).to eq("lightning bolt")
    end

    it "returns an empty string for nil" do
      expect(described_class.call(nil)).to eq("")
    end
  end
  ```
- [ ] Run `bundle exec rspec spikes/card_scanner/spec/card_scanner_spike/normaliser_spec.rb`. Expect: FAIL (`uninitialized constant CardScannerSpike::Normaliser`).
- [ ] Implement `spikes/card_scanner/lib/card_scanner_spike/normaliser.rb`:
  ```ruby
  module CardScannerSpike
    # Folds a card name or OCR text to a comparison key: NFKC, ligatures,
    # diacritics, case, apostrophes, punctuation and whitespace.
    module Normaliser
      LIGATURES = { "Æ" => "AE", "æ" => "ae", "Œ" => "OE", "œ" => "oe", "ß" => "ss" }.freeze

      module_function

      def call(text)
        folded = text.to_s.unicode_normalize(:nfkc).gsub(Regexp.union(LIGATURES.keys), LIGATURES)
        folded.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
          .gsub(/['’‘`]/, "").gsub(/[^\p{L}\p{N}]+/, " ").strip
      end
    end
  end
  ```
  Append `require_relative "card_scanner_spike/normaliser"` to the entry file.
- [ ] Run the same command. Expect: 3 examples, 0 failures.
- [ ] Commit: `feat(spike): add card name normaliser for the scanner spike`
- [ ] Write the failing spec `spikes/card_scanner/spec/card_scanner_spike/collector_line_spec.rb`:
  ```ruby
  require_relative "../spike_helper"

  RSpec.describe CardScannerSpike::CollectorLine do
    def parse(text) = described_class.parse(text, known_set_codes: %w[neo dmu mom pmom])

    it "takes the number before the slash, not the set size (AC-1.4)", :aggregate_failures do
      result = parse("051/302 NEO")
      expect(result.set_code).to eq("NEO")
      expect(result.number).to eq("51")
      expect(result.format).to eq(:slash)
    end

    it "reads the M15–ONE two-line format", :aggregate_failures do
      result = parse("051/302 R\nNEO • EN")
      expect(result.to_h).to eq(set_code: "NEO", number: "51", language: "en", foil: false, format: :slash)
    end

    it "reads the foil star between set and language" do
      expect(parse("0123/0281 M\nDMU ★ EN").foil).to be(true)
    end

    it "reads the MOM and later rarity-first format", :aggregate_failures do
      result = parse("R 0123\nMOM • EN")
      expect(result.to_h).to eq(set_code: "MOM", number: "123", language: "en", foil: false, format: :rarity_first)
    end

    it "keeps a promo suffix letter" do
      expect(parse("R 0045P\nPMOM • EN").number).to eq("45p")
    end

    it "repairs digit lookalikes in the number" do
      expect(parse("O5I/3O2 R\nNEO • EN").number).to eq("51")
    end

    it "repairs a zero read for the letter O in the set code" do
      expect(parse("051/302 R\nNE0 • EN").set_code).to eq("NEO")
    end

    it "rejects an unknown set code but keeps the number", :aggregate_failures do
      result = parse("051/302 R\nXYZ • EN")
      expect(result.set_code).to be_nil
      expect(result.number).to eq("51")
    end

    it "reads a pre-M15 number with no set code", :aggregate_failures do
      result = parse("123/350")
      expect(result.set_code).to be_nil
      expect(result.number).to eq("123")
    end

    it "returns empty fields for empty text" do
      expect(parse("").to_h.values).to all(be_nil)
    end
  end
  ```
- [ ] Run `bundle exec rspec spikes/card_scanner/spec/card_scanner_spike/collector_line_spec.rb`. Expect: FAIL (`uninitialized constant CardScannerSpike::CollectorLine`).
- [ ] Implement `spikes/card_scanner/lib/card_scanner_spike/collector_line.rb`:
  ```ruby
  module CardScannerSpike
    # Parses OCR text from a card's collector line (FR-3). Printed formats:
    # M15–ONE `NNN/TTT R` then `SET • EN`; MOM and later `R NNNN` then `SET • EN`.
    module CollectorLine
      Result = Data.define(:set_code, :number, :language, :foil, :format)

      LANGUAGES = { "EN" => "en", "JP" => "ja", "DE" => "de", "FR" => "fr", "IT" => "it", "ES" => "es",
                    "PT" => "pt", "RU" => "ru", "KO" => "ko", "CS" => "zhs", "CT" => "zht" }.freeze
      LOOKALIKES = { "O" => "0", "D" => "0", "I" => "1", "L" => "1", "S" => "5", "B" => "8" }.freeze
      NUMBERISH = "[0-9ODILSB]"
      SLASH = %r{(?<![A-Z0-9])(#{NUMBERISH}{1,4})\s*/\s*#{NUMBERISH}{1,4}(?![A-Z0-9])}
      RARITY_FIRST = /(?<![A-Z0-9])[CURMSLTP]\s+(#{NUMBERISH}{1,4})([A-Z★]?)(?![A-Z0-9])/
      SET_LINE = /(?<![A-Z0-9])([A-Z0-9]{3,5})\s*([•·*★.])\s*([A-Z]{2})(?![A-Z])/
      FOIL_MARKERS = %w[★ *].freeze

      module_function

      def parse(text, known_set_codes:)
        upper = text.to_s.unicode_normalize(:nfkc).upcase
        known = known_set_codes.to_set(&:upcase)
        set_code, marker, language = set_line(upper, known) || [ loose_set_code(upper, known), nil, nil ]
        number, format = number(upper)
        Result.new(set_code:, number:, language: LANGUAGES[language], foil: marker && FOIL_MARKERS.include?(marker), format:)
      end

      def set_line(upper, known)
        upper.scan(SET_LINE).each do |code, marker, language|
          resolved = resolve(code, known)
          return [ resolved, marker, language ] if resolved
        end
        nil
      end

      def loose_set_code(upper, known)
        upper.split(/[^A-Z0-9]+/).each do |token|
          next if token.length < 3 || token.length > 5 || token.match?(/\A\d+\z/)

          resolved = resolve(token, known)
          return resolved if resolved
        end
        nil
      end

      def resolve(code, known) = [ code, code.tr("0", "O"), code.tr("O", "0") ].find { known.include?(it) }

      def number(upper)
        if (match = SLASH.match(upper)) then [ digits(match[1]), :slash ]
        elsif (match = RARITY_FIRST.match(upper)) then [ digits(match[1]) + match[2].downcase, :rarity_first ]
        else [ nil, nil ]
        end
      end

      def digits(token) = token.gsub(/[ODILSB]/, LOOKALIKES).sub(/\A0+(?=\d)/, "")
    end
  end
  ```
  Append `require_relative "card_scanner_spike/collector_line"` to the entry file.
- [ ] Run the same command. Expect: 10 examples, 0 failures. Then run `bin/rubocop spikes/`. Expect: no offenses.
- [ ] Commit: `feat(spike): add tolerant collector-line parser`

---

## Phase 2: Spike server, OCR page, desktop replay and pilot

**Implements:** FR-2, NFR Security (server side) | **Satisfies:** AC-1.2 (apparatus); AC-1.6 and AC-2.x build on it
**Files:** `spikes/card_scanner/lib/card_scanner_spike/server.rb`, `spikes/card_scanner/spec/card_scanner_spike/server_spec.rb`, `spikes/card_scanner/{config.ru,puma.rb,README.md}`, `spikes/card_scanner/public/{ocr.html,ocr.js}`, `spikes/card_scanner/script/{fetch_ocr_assets,replay.rb}`
**Interfaces:** Consumes: `CardScannerSpike::WORK_DIR`, `.corpus_dir`. Produces:
- `CardScannerSpike::Server.new(public_dir:, ocr_dir:, corpus_dir:, log_dir:)` (a Rack app), with `Server::CSP`;
- the page contract `ocr.html?mode=replay|device`, which exposes `window.__spike = { results, done, error, ready }`. Each result is `{ file, name_text, collector_text, name_confidence, collector_confidence, ms, crops }`;
- `tmp/card_scanner_spike/replays/<label>/ocr.json` and `crops/*.png`;
- logs `tmp/card_scanner_spike/logs/{requests.jsonl,csp-reports.jsonl,timings-*.json}`.

> **Complexity note.** Gate: test-first (`CLAUDE.md` hard gate). Violation: the spike pages (`ocr.js`, and `camera.js` in Phase 7) and the measurement scripts (`script/*`) have no specs. Justification: they are experiment apparatus, not product code. Their outputs are the findings, and they are checked by inspection (crops, tables, the dumped schema). All decision logic they call is in the spec-covered Ruby modules. The maintainer confirms this exemption when approving the plan.

- [ ] Write the failing spec `spikes/card_scanner/spec/card_scanner_spike/server_spec.rb`:
  ```ruby
  require_relative "../spike_helper"
  require "card_scanner_spike/server"
  require "tmpdir"

  RSpec.describe CardScannerSpike::Server do
    subject(:app) do
      Rack::MockRequest.new(described_class.new(public_dir: root.join("public").to_s, ocr_dir: root.join("ocr").to_s,
        corpus_dir: root.join("corpus").to_s, log_dir: root.join("logs").to_s))
    end

    let(:root) { Pathname(Dir.mktmpdir("card-scanner-server")) }
    let(:loopback) { { "REMOTE_ADDR" => "127.0.0.1" } }

    before do
      { "public/ocr.html" => "<p>ocr</p>", "ocr/v7.0.0/worker.min.js" => "//", "corpus/a.jpg" => "jpg",
        "corpus/b.JPEG" => "jpg", "corpus/manifest.csv" => "file" }.each do |path, content|
        root.join(path).dirname.mkpath
        root.join(path).write(content)
      end
    end

    after { FileUtils.remove_entry(root) }

    it "serves spike pages under a self-only content security policy", :aggregate_failures do
      response = app.get("/ocr.html", loopback)
      expect(response.status).to eq(200)
      expect(response.body).to eq("<p>ocr</p>")
      expect(response.headers["content-security-policy"]).to eq(described_class::CSP)
      expect(described_class::CSP).not_to match(%r{https?:|\*})
    end

    it "serves the OCR engine as immutable" do
      expect(app.get("/ocr/v7.0.0/worker.min.js", loopback).headers["cache-control"]).to include("immutable")
    end

    it "serves corpus photos to this machine only", :aggregate_failures do
      expect(app.get("/corpus/a.jpg", loopback).status).to eq(200)
      expect(app.get("/corpus/a.jpg", "REMOTE_ADDR" => "192.168.1.20").status).to eq(403)
      expect(app.get("/corpus/index.json", "REMOTE_ADDR" => "192.168.1.20").status).to eq(403)
    end

    it "lists only the corpus photos" do
      expect(JSON.parse(app.get("/corpus/index.json", loopback).body)).to eq(%w[a.jpg b.JPEG])
    end

    it "saves posted timings", :aggregate_failures do
      response = app.post("/timings", loopback.merge(input: { ready_ms: 900 }.to_json))
      files = root.glob("logs/timings-*.json")
      expect(response.status).to eq(201)
      expect(files.map { JSON.parse(it.read) }).to eq([ { "ready_ms" => 900 } ])
    end

    it "rejects timings that are not JSON" do
      expect(app.post("/timings", loopback.merge(input: "nope")).status).to eq(400)
    end

    it "records content security policy violation reports" do
      app.post("/csp-report", loopback.merge(input: { "csp-report" => { "blocked-uri" => "https://example.com" } }.to_json))
      expect(root.join("logs/csp-reports.jsonl").read).to include("example.com")
    end

    it "logs each request with the bytes sent" do
      app.get("/ocr.html", loopback)
      entry = JSON.parse(root.join("logs/requests.jsonl").readlines.last)
      expect(entry).to include("path" => "/ocr.html", "bytes" => 10, "ip" => "127.0.0.1", "status" => 200)
    end
  end
  ```
- [ ] Run `bundle exec rspec spikes/card_scanner/spec/card_scanner_spike/server_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_spike/server`).
- [ ] Implement `spikes/card_scanner/lib/card_scanner_spike/server.rb`:
  ```ruby
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
      CSP = [ "default-src 'self'", "script-src 'self' 'wasm-unsafe-eval'", "img-src 'self' blob: data:",
              "worker-src 'self' blob:", "connect-src 'self'", "report-uri /csp-report" ].join("; ").freeze
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
          in [ "GET", %r{\A/ocr/} ] then delegate(@ocr, request, path.delete_prefix("/ocr"))
          in [ "GET", _ ] then delegate(@public, request, path)
          else text(405, "Method not allowed")
          end
        end

        def delegate(files, request, path) = files.call(request.env.merge("PATH_INFO" => path))

        def local?(request) = LOOPBACK.include?(request.ip)

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
  ```
- [ ] Run the same command. Expect: 8 examples, 0 failures. Then run `bin/rubocop spikes/`. Expect: no offenses.
- [ ] Commit: `feat(spike): add same-origin spike server with self-only CSP and byte log`
- [ ] Add `spikes/card_scanner/config.ru`:
  ```ruby
  # Phase 0 spike server (spec 005). Start with: bundle exec puma -C spikes/card_scanner/puma.rb
  require_relative "lib/card_scanner_spike"
  require_relative "lib/card_scanner_spike/server"

  run CardScannerSpike::Server.new(
    public_dir: File.join(CardScannerSpike::ROOT, "public"),
    ocr_dir: File.join(CardScannerSpike::WORK_DIR, "ocr"),
    corpus_dir: CardScannerSpike.corpus_dir,
    log_dir: File.join(CardScannerSpike::WORK_DIR, "logs")
  )
  ```
  and `spikes/card_scanner/puma.rb`, which is passed with `-C` so the app's `config/puma.rb` (with its Solid Queue plugin) is never loaded:
  ```ruby
  # Puma config for the spike server only; bound to all interfaces so the iPhone can reach it on the LAN.
  port Integer(ENV.fetch("SPIKE_PORT", 4100)), "0.0.0.0"
  rackup File.expand_path("config.ru", __dir__)
  threads 1, 4
  ```
- [ ] Add `spikes/card_scanner/script/fetch_ocr_assets` (`chmod +x`), which pins v7.0.0 into the ignored work directory:
  ```bash
  #!/usr/bin/env bash
  # Downloads the pinned OCR engine into tmp/card_scanner_spike/ocr/v7.0.0 (never committed).
  set -euo pipefail
  root="$(cd "$(dirname "$0")/../../.." && pwd)"
  dest="$root/tmp/card_scanner_spike/ocr/v7.0.0"
  work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
  mkdir -p "$dest/core" "$dest/lang"
  fetch() { # <registry path> <tarball base name> <version>
    curl -fsSL --max-time 180 "https://registry.npmjs.org/$1/-/$2-$3.tgz" -o "$work/$2.tgz"
    mkdir -p "$work/$2" && tar -xzf "$work/$2.tgz" -C "$work/$2"
    sha256sum "$work/$2.tgz" | sed "s|$work/||"
  }
  fetch tesseract.js tesseract.js 7.0.0
  fetch tesseract.js-core tesseract.js-core 7.0.0
  fetch @tesseract.js-data/eng eng 1.0.0
  cp "$work/tesseract.js/package/dist/tesseract.min.js" "$work/tesseract.js/package/dist/worker.min.js" "$dest/"
  cp "$work/tesseract.js-core/package/"tesseract-core*.wasm.js "$dest/core/"
  cp "$work/eng/package/4.0.0_best_int/eng.traineddata.gz" "$dest/lang/"
  du -b "$dest"/*.js "$dest"/core/* "$dest"/lang/*
  ```
- [ ] Run `spikes/card_scanner/script/fetch_ocr_assets`. Expect: three sha256 lines, then the four core builds (`tesseract-core{,-simd}{,-lstm}.wasm.js`), `worker.min.js`, `tesseract.min.js` and `eng.traineddata.gz`, with their sizes. If a `cp` source path differs inside a tarball, list it with `tar -tzf` and correct that one line before continuing. Record the sha256 values and sizes for `research.md`.
- [ ] Commit: `chore(spike): add pinned OCR asset fetcher`
- [ ] Add `spikes/card_scanner/public/ocr.html`:
  ```html
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Card scanner spike: OCR</title>
    <script src="/ocr/v7.0.0/tesseract.min.js"></script>
    <script type="module" src="/ocr.js"></script>
  </head>
  <body>
    <h1>OCR spike</h1>
    <p id="status" aria-live="polite">Loading OCR engine…</p>
    <label>Photos <input id="photos" type="file" accept="image/*" multiple disabled></label>
    <table>
      <thead><tr><th>File</th><th>Name strip</th><th>Collector strip</th><th>ms</th></tr></thead>
      <tbody id="rows"></tbody>
    </table>
  </body>
  </html>
  ```
  and `spikes/card_scanner/public/ocr.js`:
  ```js
  // Phase 0 OCR spike (spec 005): fixed card guide, two strips, Tesseract.js served from this origin.
  // Strip boxes are fractions of the card; tuned on the pilot photos, then frozen before measured runs.
  const GUIDE_HEIGHT = 0.9 // card height as a share of the image height, centred
  const CARD_ASPECT = 63 / 88
  const STRIPS = {
    name: { x: 0.06, y: 0.035, w: 0.7, h: 0.06, psm: "7" },
    collector: { x: 0.03, y: 0.905, w: 0.55, h: 0.075, psm: "6" }
  }
  const ASSETS = "/ocr/v7.0.0"
  const mode = new URLSearchParams(location.search).get("mode") || "device"
  const status = document.getElementById("status")
  const results = []
  window.__spike = { results, done: false, error: null, ready: null }

  function guideRect(image) {
    const height = image.height * GUIDE_HEIGHT
    const width = height * CARD_ASPECT
    return { x: (image.width - width) / 2, y: (image.height - height) / 2, width, height }
  }

  function crop(image, card, strip) {
    const canvas = document.createElement("canvas")
    canvas.width = Math.round(card.width * strip.w)
    canvas.height = Math.round(card.height * strip.h)
    canvas.getContext("2d").drawImage(image, card.x + card.width * strip.x, card.y + card.height * strip.y,
      canvas.width, canvas.height, 0, 0, canvas.width, canvas.height)
    return canvas
  }

  function addRow(result) {
    const row = document.createElement("tr")
    for (const value of [result.file, result.name_text, result.collector_text, result.ms]) {
      const cell = document.createElement("td")
      cell.textContent = value
      row.append(cell)
    }
    document.getElementById("rows").append(row)
  }

  async function loadWorker() {
    const worker = await Tesseract.createWorker("eng", 1, {
      workerPath: `${ASSETS}/worker.min.js`, corePath: `${ASSETS}/core`, langPath: `${ASSETS}/lang`
    })
    window.__spike.ready = performance.now()
    status.textContent = `Ready ${Math.round(window.__spike.ready)} ms after page load`
    return worker
  }

  async function recognise(worker, file, blob) {
    const image = await createImageBitmap(blob) // applies EXIF orientation
    const card = guideRect(image)
    const started = performance.now()
    const strips = {}
    for (const [key, strip] of Object.entries(STRIPS)) {
      const canvas = crop(image, card, strip)
      await worker.setParameters({ tessedit_pageseg_mode: strip.psm })
      const { data } = await worker.recognize(canvas)
      strips[key] = { text: data.text.trim(), confidence: data.confidence,
        png: mode === "replay" ? canvas.toDataURL("image/png") : null }
    }
    const result = { file, name_text: strips.name.text, collector_text: strips.collector.text,
      name_confidence: strips.name.confidence, collector_confidence: strips.collector.confidence,
      ms: Math.round(performance.now() - started), crops: { name: strips.name.png, collector: strips.collector.png } }
    results.push(result)
    addRow(result)
  }

  async function replay(worker) {
    const files = await (await fetch("/corpus/index.json")).json()
    for (const [index, file] of files.entries()) {
      status.textContent = `Replaying ${index + 1}/${files.length}: ${file}`
      await recognise(worker, file, await (await fetch(`/corpus/${encodeURIComponent(file)}`)).blob())
    }
  }

  function device(worker) {
    const input = document.getElementById("photos")
    input.disabled = false
    input.addEventListener("change", async () => {
      for (const file of input.files) await recognise(worker, file.name, file)
      const body = JSON.stringify({ user_agent: navigator.userAgent, ready_ms: Math.round(window.__spike.ready),
        results: results.map(({ crops, ...rest }) => rest) })
      const response = await fetch("/timings", { method: "POST", headers: { "content-type": "application/json" }, body })
      status.textContent = `Sent ${results.length} timings (${response.status})`
    })
  }

  try {
    const worker = await loadWorker()
    if (mode === "replay") await replay(worker)
    else device(worker)
  } catch (error) {
    window.__spike.error = String(error)
    status.textContent = `Error: ${error}`
  } finally {
    if (mode === "replay") window.__spike.done = true
  }
  ```
- [ ] Add `spikes/card_scanner/script/replay.rb`:
  ```ruby
  # Replays the photo corpus through the OCR page in headless Firefox (AC-1.2, AC-1.5).
  # Usage (spike server running): bundle exec ruby spikes/card_scanner/script/replay.rb <label>
  require "bundler/setup"
  require "base64"
  require "fileutils"
  require "json"
  require "selenium-webdriver"
  require_relative "../lib/card_scanner_spike"

  label = ARGV.fetch(0) { abort "usage: replay.rb <label>" }
  url = ENV.fetch("SPIKE_URL", "http://127.0.0.1:4100")
  out_dir = File.join(CardScannerSpike::WORK_DIR, "replays", label)
  FileUtils.mkdir_p(File.join(out_dir, "crops"))

  driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
  begin
    driver.navigate.to("#{url}/ocr.html?mode=replay")
    Selenium::WebDriver::Wait.new(timeout: 3600, interval: 5).until { driver.execute_script("return Boolean(window.__spike && window.__spike.done)") }
    spike = driver.execute_script("return window.__spike")
    abort "OCR page error: #{spike["error"]}" if spike["error"]
    results = spike.fetch("results").map do |result|
      result.delete("crops").each do |strip, data_url|
        path = File.join(out_dir, "crops", "#{File.basename(result["file"], ".*")}-#{strip}.png")
        File.binwrite(path, Base64.decode64(data_url.split(",", 2).last))
      end
      result
    end
    File.write(File.join(out_dir, "ocr.json"), JSON.pretty_generate({ "run" => label, "ready_ms" => spike["ready"].round, "results" => results }))
    puts "#{results.size} photos -> #{out_dir}/ocr.json"
  ensure
    driver.quit
  end
  ```
- [ ] Write `spikes/card_scanner/README.md`. It covers how to run the spike: fetch the assets, start the server, replay, the scripts, and the spike specs. It also has the **photo protocol**:
  - Set the iPhone camera to JPEG (Settings → Camera → Formats → Most Compatible).
  - Shoot in portrait with the card upright and centred, filling about 90% of the frame height, on a plain background, in normal room light.
  - Shoot foils as they naturally catch the light.
  - Use unique file names.
  - Copy the photos to `$CARD_SCANNER_CORPUS` (default `~/card-scanner-corpus/`) and keep them in the iPhone's Photos library for Phase 6.
  - Write `manifest.csv` there, with the columns `file,set,number,foil[,era]`: `set` is the Scryfall set code, `number` the collector number, `foil` is `yes` or `no`, and `era` (optional) is `pre-M15`, `M15–ONE` or `MOM+`.
  - Quotas: at least 50 usable photos, at least 5 per era, at least 5 foil, and some borderless or showcase cards.
- [ ] Commit: `feat(spike): add OCR spike page, desktop replay driver and photo protocol`
- [ ] **Checkpoint (maintainer):** put 5 pilot photos (mixed eras) in the corpus directory.
- [ ] Start the server as a background task: `bundle exec puma -C spikes/card_scanner/puma.rb`. Run `bundle exec ruby spikes/card_scanner/script/replay.rb pilot`. Expect: `5 photos -> …/replays/pilot/ocr.json`.
- [ ] Inspect `tmp/card_scanner_spike/replays/pilot/crops/*.png` (Read tool). If a strip misses its text band, adjust `STRIPS` or `GUIDE_HEIGHT` in `ocr.js` and re-run the pilot until all 5 crops frame their bands. Record the final values and the number of tuning rounds for `research.md`.
- [ ] Commit: `chore(spike): tune strip positions on the pilot photos`

---

## Phase 3: Catalog lookup and ground truth

**Implements:** FR-1, FR-3 (lookup) | **Satisfies:** AC-1.1
**Files:** `spikes/card_scanner/lib/card_scanner_spike/{printing_lookup,ground_truth}.rb`, `spikes/card_scanner/spec/card_scanner_spike/{printing_lookup,ground_truth}_spec.rb`, `spikes/card_scanner/script/build_ground_truth.rb`, `spec/fixtures/card_scanner/ground_truth.json`
**Interfaces:** Consumes: `CollectorLine` (set codes are upper case). Produces:
- `PrintingLookup#call(set_code:, number:, language: "en") -> Outcome(status: :one|:none|:ambiguous, entries: [Catalog::Entry])`;
- `PrintingLookup.known_set_codes -> [String]`;
- `GroundTruth#build(manifest_csv, corpus_files:) -> { "photos", "errors", "counts" }`;
- `GroundTruth.era_for(date)`;
- `ground_truth.json`, where each photo has `file, name, name_bar, set_code, collector_number, external_key, era, foil, borderless_or_showcase`.

- [ ] Make sure this worktree has the English catalog: `bin/rails "catalog:status[mtg]"`. If there's no `applied` run, start `bin/dev` as a background task and run `bin/rails "catalog:refresh[mtg]"`, then check `catalog:status` until it shows applied (about 70 s). Stop the server afterwards.
- [ ] Write the failing spec `spikes/card_scanner/spec/card_scanner_spike/printing_lookup_spec.rb`:
  ```ruby
  require "rails_helper"
  require_relative "../spike_helper"
  require "card_scanner_spike/printing_lookup"

  RSpec.describe CardScannerSpike::PrintingLookup, type: :model do
    subject(:lookup) { described_class.new }

    let(:neo) { create(:catalog_set, code: "neo") }

    it "resolves a set, number and language to one printing", :aggregate_failures do
      entry = create(:catalog_entry, set: neo, number: "51")
      outcome = lookup.call(set_code: "NEO", number: "51", language: "en")
      expect(outcome.status).to eq(:one)
      expect(outcome.entries).to eq([ entry ])
    end

    it "defaults a missing language to English" do
      create(:catalog_entry, set: neo, number: "51")
      expect(lookup.call(set_code: "NEO", number: "51", language: nil).status).to eq(:one)
    end

    it "reports none for an unknown number" do
      create(:catalog_entry, set: neo, number: "51")
      expect(lookup.call(set_code: "NEO", number: "52").status).to eq(:none)
    end

    it "reports none when the set or number was not parsed" do
      expect(lookup.call(set_code: nil, number: "51").status).to eq(:none)
    end

    it "ignores retired printings" do
      create(:catalog_entry, :retired, set: neo, number: "51")
      expect(lookup.call(set_code: "NEO", number: "51").status).to eq(:none)
    end

    it "reports ambiguous when more than one printing matches" do
      create_list(:catalog_entry, 2, set: neo, number: "51")
      expect(lookup.call(set_code: "NEO", number: "51").status).to eq(:ambiguous)
    end

    describe ".known_set_codes" do
      it "lists the catalog's set codes" do
        neo
        expect(described_class.known_set_codes).to include("neo")
      end
    end
  end
  ```
- [ ] Run `bundle exec rspec spikes/card_scanner/spec/card_scanner_spike/printing_lookup_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_spike/printing_lookup`).
- [ ] Implement `spikes/card_scanner/lib/card_scanner_spike/printing_lookup.rb`:
  ```ruby
  module CardScannerSpike
    # Resolves a parsed collector line to catalog printings (FR-3). Needs Rails.
    class PrintingLookup
      Outcome = Data.define(:status, :entries)

      def self.known_set_codes = Catalog::Set.where(collectible_type: "mtg").pluck(:code)

      def call(set_code:, number:, language: "en")
        return Outcome.new(status: :none, entries: []) if set_code.blank? || number.blank?

        entries = Catalog::Entry.active.joins(:set)
          .where(collectible_type: "mtg", number:, language: language || "en")
          .where(catalog_sets: { code: set_code.downcase }).to_a
        Outcome.new(status: { 0 => :none, 1 => :one }.fetch(entries.size, :ambiguous), entries:)
      end
    end
  end
  ```
- [ ] Run the same command. Expect: 7 examples, 0 failures.
- [ ] Commit: `feat(spike): add collector-line printing lookup`
- [ ] Write the failing spec `spikes/card_scanner/spec/card_scanner_spike/ground_truth_spec.rb`:
  ```ruby
  require "rails_helper"
  require_relative "../spike_helper"
  require "card_scanner_spike/printing_lookup"
  require "card_scanner_spike/ground_truth"

  RSpec.describe CardScannerSpike::GroundTruth, type: :model do
    subject(:ground_truth) { described_class.new }

    let(:manifest) { "file,set,number,foil\nbolt.jpg,NEO,51,yes\nghost.jpg,NEO,999,no\n" }

    before do
      neo = create(:catalog_set, code: "neo", released_on: Date.new(2022, 2, 18))
      create(:mtg_printing, entry: create(:catalog_entry, set: neo, number: "51", released_on: neo.released_on), border_color: "borderless")
    end

    it "records each resolvable photo with its derived fields" do
      photos = ground_truth.build(manifest, corpus_files: %w[bolt.jpg ghost.jpg]).fetch("photos")
      expect(photos).to contain_exactly(include("file" => "bolt.jpg", "name" => "Lightning Bolt", "name_bar" => "Lightning Bolt",
        "set_code" => "neo", "collector_number" => "51", "era" => "M15–ONE", "foil" => true, "borderless_or_showcase" => true))
    end

    it "lists rows that match no printing as ground-truth errors" do
      errors = ground_truth.build(manifest, corpus_files: %w[bolt.jpg ghost.jpg]).fetch("errors")
      expect(errors).to contain_exactly(include("file" => "ghost.jpg", "problem" => "none"))
    end

    it "lists rows whose photo is missing as ground-truth errors" do
      errors = ground_truth.build(manifest, corpus_files: %w[bolt.jpg]).fetch("errors")
      expect(errors).to contain_exactly(include("file" => "ghost.jpg", "problem" => "missing photo"))
    end

    it "lets the manifest override the era" do
      photos = ground_truth.build("file,set,number,foil,era\nbolt.jpg,NEO,51,no,MOM+\n", corpus_files: %w[bolt.jpg]).fetch("photos")
      expect(photos.first["era"]).to eq("MOM+")
    end

    it "counts photos per era and foil" do
      counts = ground_truth.build(manifest, corpus_files: %w[bolt.jpg ghost.jpg]).fetch("counts")
      expect(counts).to eq("total" => 1, "foil" => 1, "by_era" => { "pre-M15" => 0, "M15–ONE" => 1, "MOM+" => 0 })
    end

    describe ".era_for" do
      it "splits eras at the M15 and MOM releases", :aggregate_failures do
        expect(described_class.era_for(Date.new(2014, 7, 17))).to eq("pre-M15")
        expect(described_class.era_for(Date.new(2014, 7, 18))).to eq("M15–ONE")
        expect(described_class.era_for(Date.new(2023, 4, 21))).to eq("MOM+")
      end
    end
  end
  ```
- [ ] Run `bundle exec rspec spikes/card_scanner/spec/card_scanner_spike/ground_truth_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_spike/ground_truth`).
- [ ] Implement `spikes/card_scanner/lib/card_scanner_spike/ground_truth.rb`:
  ```ruby
  require "csv"

  module CardScannerSpike
    # Builds ground-truth records from the maintainer's manifest (AC-1.1).
    # Manifest columns: file,set,number,foil[,era]. Needs Rails.
    class GroundTruth
      ERAS = [ "pre-M15", "M15–ONE", "MOM+" ].freeze
      M15_RELEASE = Date.new(2014, 7, 18)
      MOM_RELEASE = Date.new(2023, 4, 21)

      def self.era_for(released_on)
        if released_on < M15_RELEASE then "pre-M15"
        elsif released_on < MOM_RELEASE then "M15–ONE"
        else "MOM+"
        end
      end

      def initialize(lookup: PrintingLookup.new)
        @lookup = lookup
      end

      def build(manifest_csv, corpus_files:)
        photos = []
        errors = []
        CSV.parse(manifest_csv, headers: true).each do |row|
          problem, entry = check(row, corpus_files)
          problem ? errors << row.to_h.merge("problem" => problem) : photos << record(row, entry)
        end
        { "photos" => photos, "errors" => errors, "counts" => counts(photos) }
      end

      private
        def check(row, corpus_files)
          return [ "missing photo" ] unless corpus_files.include?(row["file"])
          return [ "unknown era" ] if row["era"].present? && ERAS.exclude?(row["era"])

          outcome = @lookup.call(set_code: row["set"], number: row["number"].to_s.strip)
          outcome.status == :one ? [ nil, outcome.entries.first ] : [ outcome.status.to_s ]
        end

        def record(row, entry)
          printing = MTG::Printing.find_by!(catalog_entry_id: entry.id)
          { "file" => row["file"], "name" => entry.name, "name_bar" => printing.faces.first.fetch("name"),
            "set_code" => entry.set.code, "collector_number" => entry.number, "external_key" => entry.external_key,
            "era" => row["era"].presence || self.class.era_for(entry.released_on || entry.set.released_on),
            "foil" => row["foil"].to_s.strip.casecmp?("yes"),
            "borderless_or_showcase" => printing.border_color == "borderless" || printing.variant_tags.include?("showcase") }
        end

        def counts(photos)
          { "total" => photos.size, "foil" => photos.count { it["foil"] },
            "by_era" => ERAS.index_with { |era| photos.count { it["era"] == era } } }
        end
    end
  end
  ```
- [ ] Run the same command. Expect: 6 examples, 0 failures. Then run `bin/rubocop spikes/`. Expect: no offenses.
- [ ] Commit: `feat(spike): build ground truth from the photo manifest`
- [ ] Add `spikes/card_scanner/script/build_ground_truth.rb`:
  ```ruby
  # Writes spec/fixtures/card_scanner/ground_truth.json from the corpus manifest (AC-1.1, AC-4.4).
  # Usage: bin/rails runner spikes/card_scanner/script/build_ground_truth.rb
  require_relative "../lib/card_scanner_spike"
  require_relative "../lib/card_scanner_spike/printing_lookup"
  require_relative "../lib/card_scanner_spike/ground_truth"

  corpus = CardScannerSpike.corpus_dir
  manifest = File.read(File.join(corpus, "manifest.csv"))
  truth = CardScannerSpike::GroundTruth.new.build(manifest, corpus_files: Dir.children(corpus))
  FileUtils.mkdir_p(CardScannerSpike::FIXTURE_DIR)
  File.write(File.join(CardScannerSpike::FIXTURE_DIR, "ground_truth.json"), JSON.pretty_generate({ "format_version" => 1, **truth }))
  puts JSON.pretty_generate(truth.slice("counts", "errors"))
  ```
- [ ] **Checkpoint (maintainer):** the full corpus and `manifest.csv` are in place, following the protocol in `spikes/card_scanner/README.md`.
- [ ] Run `bin/rails runner spikes/card_scanner/script/build_ground_truth.rb`. Expect: `counts.total ≥ 50`, every `by_era` value ≥ 5, and `foil ≥ 5` (AC-1.1). If not, ask the maintainer for more photos, or to fix manifest rows listed in `errors`, and re-run.
- [ ] Commit: `test(spike): add the corpus ground truth fixture`

---

## Phase 4: Fuzzy name index

**Implements:** Story 3 | **Satisfies:** AC-3.1, AC-3.2, AC-3.4, AC-3.5
**Files:** `spikes/card_scanner/lib/card_scanner_spike/name_index.rb`, `spikes/card_scanner/spec/card_scanner_spike/name_index_spec.rb`, `spikes/card_scanner/script/{schema_round_trip,build_name_index,name_edge_cases}.rb`
**Interfaces:** Consumes: `Normaliser.call`. Produces:
- `NameIndex.new(path)`;
- `#rebuild([[card_name, indexed_name], …]) -> Integer`;
- `#count`;
- `#search(text, limit: 3) -> [Candidate(card_name, matched, score)]`;
- `#short_names -> [[card_name, indexed]]`;
- `#card_names_for(text) -> [String]`;
- `tmp/card_scanner_spike/names.sqlite3`.

- [ ] Add `spikes/card_scanner/script/schema_round_trip.rb`:
  ```ruby
  # AC-3.1: does an FTS5 trigram table survive Rails' schema.rb dump and load?
  # Usage: bundle exec ruby spikes/card_scanner/script/schema_round_trip.rb
  require "bundler/setup"
  require "active_record"
  require "stringio"
  require "tmpdir"

  FTS_SQL = "SELECT sql FROM sqlite_master WHERE name = 'names_fts'".freeze

  Dir.mktmpdir("fts-round-trip") do |dir|
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(dir, "source.sqlite3"))
    source = ActiveRecord::Base.connection
    source.create_table(:names) { |t| t.string :norm, null: false }
    source.create_virtual_table(:names_fts, :fts5, [ "norm", "content='names'", "content_rowid='id'", "tokenize='trigram remove_diacritics 1'" ])
    before = source.select_value(FTS_SQL)
    schema = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, schema)
    File.write(File.join(dir, "schema.rb"), schema.string)

    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(dir, "loaded.sqlite3"))
    load File.join(dir, "schema.rb")
    loaded = ActiveRecord::Base.connection
    after = loaded.select_value(FTS_SQL)
    loaded.execute("INSERT INTO names (norm) VALUES ('lightning bolt')")
    loaded.execute("INSERT INTO names_fts (names_fts) VALUES ('rebuild')")
    hits = loaded.select_value("SELECT count(*) FROM names_fts WHERE names_fts MATCH '\"ghtn\"'")
    puts "Dumped schema:", schema.string, "Before: #{before}", "After:  #{after}",
      "Identical: #{before == after}", "Trigram query after load finds the row: #{hits == 1}"
  end
  ```
- [ ] Run `bundle exec ruby spikes/card_scanner/script/schema_round_trip.rb`. Record the dumped `create_virtual_table` line, both SQL strings, and both booleans for AC-3.1. If they aren't identical, try once with the tokenizer written as `"tokenize = 'trigram remove_diacritics 1'"` and record that too. The fallback recommendation then goes in the findings (SQL-format schema, or building the index outside the schema).
- [ ] Commit: `chore(spike): add FTS5 schema round-trip experiment`
- [ ] Write the failing spec `spikes/card_scanner/spec/card_scanner_spike/name_index_spec.rb`:
  ```ruby
  require_relative "../spike_helper"
  require "card_scanner_spike/name_index"
  require "tmpdir"

  RSpec.describe CardScannerSpike::NameIndex do
    subject(:index) { described_class.new(File.join(dir, "names.sqlite3")) }

    let(:dir) { Dir.mktmpdir("name-index") }
    let(:rows) do
      [ [ "Lightning Bolt", "Lightning Bolt" ], [ "Lightning Helix", "Lightning Helix" ], [ "Aether Vial", "Aether Vial" ],
        [ "Fire // Ice", "Fire // Ice" ], [ "Fire // Ice", "Fire" ], [ "Fire // Ice", "Ice" ], [ "Ox", "Ox" ] ]
    end

    before { index.rebuild(rows) }
    after { FileUtils.remove_entry(dir) }

    def top(text) = index.search(text).first&.card_name

    it "indexes each distinct card and name pair, idempotently" do
      expect(index.rebuild(rows)).to eq(7)
    end

    it "finds a card by its exact name" do
      expect(top("Lightning Bolt")).to eq("Lightning Bolt")
    end

    it "finds a card from a misread name" do
      expect(top("Lightnlng Bo1t")).to eq("Lightning Bolt")
    end

    it "finds a card whose name has a ligature" do
      expect(top("Æther Vial")).to eq("Aether Vial")
    end

    it "maps a face name to its card, once per card", :aggregate_failures do
      expect(top("Fire")).to eq("Fire // Ice")
      expect(index.search("Fire").map(&:card_name)).to eq(index.search("Fire").map(&:card_name).uniq)
    end

    it "falls back to exact and prefix matching below three characters" do
      expect(top("Ox")).to eq("Ox")
    end

    it "returns at most the limit, best first" do
      expect(index.search("Lightning", limit: 1).map(&:card_name)).to eq([ "Lightning Bolt" ])
    end

    it "returns nothing for text that normalises to nothing" do
      expect(index.search(" -- ")).to eq([])
    end

    it "lists names shorter than three characters" do
      expect(index.short_names).to eq([ [ "Ox", "Ox" ] ])
    end

    it "looks up the cards an exact name belongs to" do
      expect(index.card_names_for("fire")).to eq([ "Fire // Ice" ])
    end
  end
  ```
- [ ] Run `bundle exec rspec spikes/card_scanner/spec/card_scanner_spike/name_index_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_spike/name_index`).
- [ ] Implement `spikes/card_scanner/lib/card_scanner_spike/name_index.rb`:
  ```ruby
  require "did_you_mean"
  require "sqlite3"

  module CardScannerSpike
    # Trigram full-text index of card names in its own SQLite file (Story 3): OR the
    # query's trigrams, shortlist by bm25, re-rank by Jaro-Winkler, one row per card.
    class NameIndex
      Candidate = Data.define(:card_name, :matched, :score)
      SHORTLIST = 50
      SCHEMA = [
        "CREATE TABLE IF NOT EXISTS names (id INTEGER PRIMARY KEY, card_name TEXT NOT NULL, indexed TEXT NOT NULL, " \
        "norm TEXT NOT NULL, UNIQUE (card_name, norm))",
        "CREATE VIRTUAL TABLE IF NOT EXISTS names_fts USING fts5 (norm, content='names', content_rowid='id', " \
        "tokenize='trigram remove_diacritics 1')"
      ].freeze

      def initialize(path)
        @db = SQLite3::Database.new(path)
        SCHEMA.each { @db.execute(it) }
      end

      def rebuild(rows)
        @db.transaction do
          @db.execute("DELETE FROM names")
          rows.each do |card_name, indexed|
            @db.execute("INSERT OR IGNORE INTO names (card_name, indexed, norm) VALUES (?, ?, ?)",
              [ card_name, indexed, Normaliser.call(indexed) ])
          end
          @db.execute("INSERT INTO names_fts (names_fts) VALUES ('rebuild')")
        end
        count
      end

      def count = @db.get_first_value("SELECT count(*) FROM names")

      def search(text, limit: 3)
        query = Normaliser.call(text)
        return [] if query.empty?

        rank(query, query.length < 3 ? short(query) : trigram(query)).first(limit)
      end

      def short_names = @db.execute("SELECT card_name, indexed FROM names WHERE length(norm) < 3 ORDER BY card_name")

      def card_names_for(text)
        @db.execute("SELECT DISTINCT card_name FROM names WHERE norm = ? ORDER BY card_name", [ Normaliser.call(text) ]).flatten
      end

      private
        def trigram(query)
          terms = (0..query.length - 3).map { %("#{query[it, 3]}") }.uniq.join(" OR ")
          @db.execute(<<~SQL, [ terms, SHORTLIST ])
            SELECT names.card_name, names.norm FROM names_fts JOIN names ON names.id = names_fts.rowid
            WHERE names_fts MATCH ? ORDER BY bm25(names_fts) LIMIT ?
          SQL
        end

        def short(query)
          @db.execute("SELECT card_name, norm FROM names WHERE norm = ? OR norm LIKE ? LIMIT ?", [ query, "#{query}%", SHORTLIST ])
        end

        def rank(query, rows)
          rows.group_by(&:first).map do |card_name, matches|
            norm, score = matches.map { |(_, matched)| [ matched, DidYouMean::JaroWinkler.distance(query, matched) ] }.max_by(&:last)
            Candidate.new(card_name:, matched: norm, score: score.round(4))
          end.sort_by { [ -it.score, it.card_name ] }
        end
    end
  end
  ```
  It isn't required from the entry file; scripts require it explicitly.
- [ ] Run the same command. Expect: 10 examples, 0 failures. Then run `bin/rubocop spikes/`. Expect: no offenses.
- [ ] Commit: `feat(spike): add trigram name index with Jaro-Winkler re-ranking`
- [ ] Add `spikes/card_scanner/script/build_name_index.rb`:
  ```ruby
  # AC-3.2, AC-3.5: builds the name index from the English catalog; reports time, size and count.
  # Usage: bin/rails runner spikes/card_scanner/script/build_name_index.rb
  require_relative "../lib/card_scanner_spike"
  require_relative "../lib/card_scanner_spike/name_index"

  clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
  path = File.join(CardScannerSpike::WORK_DIR, "names.sqlite3")
  FileUtils.mkdir_p(File.dirname(path))
  FileUtils.rm_f(path)
  started = clock.call
  english = Catalog::Entry.searchable.where(collectible_type: "mtg", language: "en")
  rows = english.distinct.pluck(:name).map { [ it, it ] }
  english.joins("JOIN mtg_printings ON mtg_printings.catalog_entry_id = catalog_entries.id")
    .pluck("catalog_entries.name", "mtg_printings.faces").each do |name, faces|
      faces = JSON.parse(faces) if faces.is_a?(String)
      rows.concat(faces.map { [ name, it.fetch("name") ] }) if faces.size > 1
    end
  read = clock.call
  count = CardScannerSpike::NameIndex.new(path).rebuild(rows.uniq)
  finished = clock.call
  fts_bytes = begin
    SQLite3::Database.new(path).get_first_value("SELECT sum(pgsize) FROM dbstat WHERE name LIKE 'names_fts%'")
  rescue SQLite3::SQLException
    nil
  end
  puts({ names: count, read_s: (read - started).round(2), build_s: (finished - read).round(2),
         total_s: (finished - started).round(2), file_bytes: File.size(path), fts_bytes: }.to_json)
  ```
- [ ] Run `bin/rails runner spikes/card_scanner/script/build_name_index.rb` three times. Record the median `total_s` and `build_s`, plus `names`, `file_bytes` and `fts_bytes` (`null` means `dbstat` isn't compiled in, so say so). `total_s` is the cost a full rebuild would add to each refresh (AC-3.5).
- [ ] Commit: `chore(spike): add name index build benchmark`
- [ ] Add `spikes/card_scanner/script/name_edge_cases.rb`:
  ```ruby
  # AC-3.4: short, accented and multi-face names, queried exactly and with one misread character.
  # Usage: bundle exec ruby spikes/card_scanner/script/name_edge_cases.rb
  require "bundler/setup"
  require_relative "../lib/card_scanner_spike"
  require_relative "../lib/card_scanner_spike/name_index"

  index = CardScannerSpike::NameIndex.new(File.join(CardScannerSpike::WORK_DIR, "names.sqlite3"))
  abort "Build the name index first (build_name_index.rb)" if index.count.zero?
  cases = index.short_names.map { |_, name| [ "shorter than 3", name ] } +
    [ "Æther Vial", "Lim-Dûl's Vault", "Jötun Grunt", "Dandân" ].map { [ "diacritic or ligature", it ] } +
    [ "Fire // Ice", "Fire", "Ice" ].map { [ "split", it ] } +
    [ "Bonecrusher Giant", "Stomp" ].map { [ "adventure", it ] } +
    [ "Delver of Secrets", "Insectile Aberration" ].map { [ "double-faced", it ] }
  found = ->(expected, text) { (index.search(text).map(&:card_name) & expected).any? ? "yes" : "no" }

  puts "| Category | Printed name | Expected card | Exact: top 3 | Misread | Misread: top 3 |", "|---|---|---|---|---|---|"
  cases.each do |category, name|
    expected = index.card_names_for(name)
    misread = CardScannerSpike::Scoring.misread(name)
    shown = expected.empty? ? "(not indexed)" : expected.join("; ")
    puts "| #{category} | #{name} | #{shown} | #{found.call(expected, name)} | #{misread} | #{found.call(expected, misread)} |"
  end
  ```
  This script uses `Scoring.misread` from Phase 5, so it runs in Phase 5.
- [ ] Commit: `chore(spike): add name edge-case experiment`

---

## Phase 5: Scoring, matching and the accuracy runs

**Implements:** FR-2 (recording), Story 1 rates, Story 3 rates | **Satisfies:** AC-1.2, AC-1.3, AC-1.5, AC-1.7, AC-3.3 (and AC-3.4 by running Phase 4's script)
**Files:** `spikes/card_scanner/lib/card_scanner_spike/{scoring,rates}.rb`, `spikes/card_scanner/spec/card_scanner_spike/{scoring,rates}_spec.rb`, `spikes/card_scanner/lib/card_scanner_spike.rb`, `spikes/card_scanner/script/{match,report}.rb`
**Interfaces:** Consumes:
- `CollectorLine.parse`, `PrintingLookup#call` and `.known_set_codes`, `NameIndex#search`;
- `replays/<label>/ocr.json` and `ground_truth.json`.

Produces:
- `Scoring.name_read?(result, truth)`, `.printing_identified?(result, truth)`, `.in_top?(match, truth, count)`, `.percentile(values, percent)`, `.differences(run_a, run_b)` and `.misread(name)`;
- `Rates.breakdown(records) { |record| hit } -> { grouping => { value => Rate(hits, total) } }` and `Rates.markdown(title, breakdown)`;
- `replays/<label>/{ocr_results,name_matches}.json`.

- [ ] Write the failing spec `spikes/card_scanner/spec/card_scanner_spike/scoring_spec.rb`:
  ```ruby
  require_relative "../spike_helper"

  RSpec.describe CardScannerSpike::Scoring do
    let(:truth) { { "name" => "Fire // Ice", "name_bar" => "Fire", "external_key" => "abc" } }

    describe ".name_read?" do
      it "compares normalised text", :aggregate_failures do
        expect(described_class.name_read?({ "name_text" => "FIRE\n" }, truth)).to be(true)
        expect(described_class.name_read?({ "name_text" => "Firc" }, truth)).to be(false)
      end
    end

    describe ".printing_identified?" do
      it "needs exactly the expected printing", :aggregate_failures do
        expect(described_class.printing_identified?({ "lookup" => { "status" => "one", "external_keys" => [ "abc" ] } }, truth)).to be(true)
        expect(described_class.printing_identified?({ "lookup" => { "status" => "ambiguous", "external_keys" => %w[abc def] } }, truth)).to be(false)
      end
    end

    describe ".in_top?" do
      it "looks only at the first candidates", :aggregate_failures do
        match = { "candidates" => [ { "card_name" => "Fireball" }, { "card_name" => "Fire // Ice" } ] }
        expect(described_class.in_top?(match, truth, 1)).to be(false)
        expect(described_class.in_top?(match, truth, 3)).to be(true)
      end
    end

    describe ".percentile" do
      it "picks the nearest rank", :aggregate_failures do
        expect(described_class.percentile([ 5, 1, 3, 2, 4 ], 50)).to eq(3)
        expect(described_class.percentile([ 5, 1, 3, 2, 4 ], 95)).to eq(5)
        expect(described_class.percentile([], 50)).to be_nil
      end
    end

    describe ".differences" do
      it "lists strips whose text changed between runs" do
        a = [ { "file" => "x.jpg", "name_text" => "Fire", "collector_text" => "1/2" } ]
        b = [ { "file" => "x.jpg", "name_text" => "Firc", "collector_text" => "1/2" } ]
        expect(described_class.differences(a, b)).to eq([ { "file" => "x.jpg", "field" => "name_text", "a" => "Fire", "b" => "Firc" } ])
      end
    end

    describe ".misread" do
      it "swaps the middle character for a lookalike, or x", :aggregate_failures do
        expect(described_class.misread("Bolt")).to eq("Bo1t")
        expect(described_class.misread("Ice")).to eq("Ixe")
      end
    end
  end
  ```
  and `spikes/card_scanner/spec/card_scanner_spike/rates_spec.rb`:
  ```ruby
  require_relative "../spike_helper"

  RSpec.describe CardScannerSpike::Rates do
    let(:records) do
      [ { "era" => "MOM+", "foil" => true, "borderless_or_showcase" => false, "hit" => true },
        { "era" => "MOM+", "foil" => false, "borderless_or_showcase" => true, "hit" => false },
        { "era" => "pre-M15", "foil" => false, "borderless_or_showcase" => false, "hit" => true } ]
    end
    let(:breakdown) { described_class.breakdown(records) { it["hit"] } }

    describe ".breakdown" do
      it "rates every grouping with its sample size", :aggregate_failures do
        expect(breakdown["overall"]["all"].to_s).to eq("2/3 (66.7%)")
        expect(breakdown["era"].transform_values(&:to_s)).to eq("MOM+" => "1/2 (50.0%)", "pre-M15" => "1/1 (100.0%)")
        expect(breakdown["foil"]["foil"].to_s).to eq("1/1 (100.0%)")
        expect(breakdown["frame treatment"]["borderless/showcase"].to_s).to eq("0/1 (0.0%)")
      end
    end

    describe ".markdown" do
      it "renders a header and one row per group" do
        expect(described_class.markdown("Hit", breakdown).lines.size).to eq(2 + 7)
      end
    end
  end
  ```
- [ ] Run `bundle exec rspec spikes/card_scanner/spec/card_scanner_spike/scoring_spec.rb spikes/card_scanner/spec/card_scanner_spike/rates_spec.rb`. Expect: FAIL (`uninitialized constant CardScannerSpike::Scoring`).
- [ ] Implement `spikes/card_scanner/lib/card_scanner_spike/scoring.rb`:
  ```ruby
  module CardScannerSpike
    # Hit predicates and statistics for the Story 1 and Story 3 reports.
    module Scoring
      LOOKALIKES = { "l" => "1", "i" => "l", "o" => "0", "e" => "c", "n" => "m", "a" => "o" }.freeze
      STRIPS = %w[name_text collector_text].freeze

      module_function

      def name_read?(result, truth) = Normaliser.call(result["name_text"]) == Normaliser.call(truth["name_bar"])

      def printing_identified?(result, truth)
        result.dig("lookup", "status") == "one" && result.dig("lookup", "external_keys") == [ truth["external_key"] ]
      end

      def in_top?(match, truth, count) = match["candidates"].first(count).any? { it["card_name"] == truth["name"] }

      def percentile(values, percent)
        return nil if values.empty?

        sorted = values.sort
        sorted[((percent / 100.0) * (sorted.size - 1)).round]
      end

      def differences(run_a, run_b)
        others = run_b.to_h { [ it["file"], it ] }
        run_a.flat_map do |result|
          other = others.fetch(result["file"], {})
          STRIPS.filter_map do |field|
            { "file" => result["file"], "field" => field, "a" => result[field], "b" => other[field] } unless result[field] == other[field]
          end
        end
      end

      def misread(name)
        middle = name.length / 2
        name.dup.tap { it[middle] = LOOKALIKES.fetch(name[middle], "x") }
      end
    end
  end
  ```
  and `spikes/card_scanner/lib/card_scanner_spike/rates.rb`:
  ```ruby
  module CardScannerSpike
    # Hit rates over records, overall and per era, foil and frame treatment, with sample sizes (FR-4).
    module Rates
      Rate = Data.define(:hits, :total) do
        def percent = total.zero? ? nil : (100.0 * hits / total).round(1)
        def to_s = "#{hits}/#{total} (#{percent.nil? ? "n/a" : "#{percent}%"})"
      end
      GROUPINGS = {
        "overall" => ->(_) { "all" },
        "era" => ->(record) { record["era"] },
        "foil" => ->(record) { record["foil"] ? "foil" : "non-foil" },
        "frame treatment" => ->(record) { record["borderless_or_showcase"] ? "borderless/showcase" : "regular" }
      }.freeze

      module_function

      def breakdown(records, &hit)
        GROUPINGS.to_h do |label, key|
          [ label, records.group_by(&key).sort_by(&:first).to_h { |value, rows| [ value, Rate.new(hits: rows.count(&hit), total: rows.size) ] } ]
        end
      end

      def markdown(title, breakdown)
        rows = breakdown.flat_map { |label, groups| groups.map { |value, rate| "| #{label} | #{value} | #{rate} |" } }
        [ "| #{title} | Group | Hits / n (rate) |", "|---|---|---|", *rows ].join("\n")
      end
    end
  end
  ```
  In `spikes/card_scanner/lib/card_scanner_spike.rb`, add `require_relative "card_scanner_spike/scoring"` and `require_relative "card_scanner_spike/rates"` after the collector-line require.
- [ ] Run the same command. Expect: 8 examples, 0 failures. Then run `bin/rubocop spikes/`. Expect: no offenses.
- [ ] Commit: `feat(spike): add scoring and rate breakdowns`
- [ ] Run Phase 4's `bundle exec ruby spikes/card_scanner/script/name_edge_cases.rb`. Save the table for AC-3.4.
- [ ] Add `spikes/card_scanner/script/match.rb`:
  ```ruby
  # Parses each replayed collector strip, looks up the printing, and queries the name index (AC-1.2, AC-3.3).
  # Usage: bin/rails runner spikes/card_scanner/script/match.rb <label>
  require_relative "../lib/card_scanner_spike"
  require_relative "../lib/card_scanner_spike/printing_lookup"
  require_relative "../lib/card_scanner_spike/name_index"

  label = ARGV.fetch(0) { abort "usage: match.rb <label>" }
  dir = File.join(CardScannerSpike::WORK_DIR, "replays", label)
  replay = JSON.parse(File.read(File.join(dir, "ocr.json")))
  known = CardScannerSpike::PrintingLookup.known_set_codes
  lookup = CardScannerSpike::PrintingLookup.new
  index = CardScannerSpike::NameIndex.new(File.join(CardScannerSpike::WORK_DIR, "names.sqlite3"))
  abort "Build the name index first (build_name_index.rb)" if index.count.zero?

  results = replay.fetch("results").map do |result|
    parsed = CardScannerSpike::CollectorLine.parse(result["collector_text"], known_set_codes: known)
    outcome = lookup.call(set_code: parsed.set_code, number: parsed.number, language: parsed.language)
    result.merge("run" => label,
      "parsed" => parsed.to_h.to_h { |key, value| [ key.to_s, value.is_a?(Symbol) ? value.to_s : value ] },
      "lookup" => { "status" => outcome.status.to_s, "external_keys" => outcome.entries.map(&:external_key) })
  end
  matches = replay.fetch("results").map do |result|
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    candidates = index.search(result["name_text"])
    query_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
    { "file" => result["file"], "query" => result["name_text"], "query_ms" => query_ms,
      "candidates" => candidates.map { it.to_h.transform_keys(&:to_s) } }
  end
  File.write(File.join(dir, "ocr_results.json"), JSON.pretty_generate({ "format_version" => 1, "run" => label, "results" => results }))
  File.write(File.join(dir, "name_matches.json"), JSON.pretty_generate({ "format_version" => 1, "run" => label, "matches" => matches }))
  puts "#{results.size} results -> #{dir}"
  ```
- [ ] Add `spikes/card_scanner/script/report.rb`:
  ```ruby
  # Prints the Story 1 and Story 3 tables as Markdown (AC-1.3, AC-1.5, AC-1.7, AC-3.3).
  # Usage: bundle exec ruby spikes/card_scanner/script/report.rb <label> [<second label>]
  require "bundler/setup"
  require "json"
  require_relative "../lib/card_scanner_spike"

  def read_json(*path) = JSON.parse(File.read(File.join(*path)))
  def run_dir(label) = File.join(CardScannerSpike::WORK_DIR, "replays", label)
  def cell(text) = text.to_s.gsub("|", "\\|").tr("\n", " ")

  label, other = ARGV
  abort "usage: report.rb <label> [<second label>]" unless label
  spike = CardScannerSpike
  truth = read_json(spike::FIXTURE_DIR, "ground_truth.json").fetch("photos").to_h { [ it["file"], it ] }
  results = read_json(run_dir(label), "ocr_results.json").fetch("results").select { truth.key?(it["file"]) }
  matches = read_json(run_dir(label), "name_matches.json").fetch("matches").to_h { [ it["file"], it ] }
  rows = results.map { truth.fetch(it["file"]).merge("result" => it, "match" => matches.fetch(it["file"])) }
  with_set_line = rows.select { %w[M15–ONE MOM+].include?(it["era"]) }

  puts "## Name strip read exactly (AC-1.3)", "",
    spike::Rates.markdown("Name read", spike::Rates.breakdown(rows) { spike::Scoring.name_read?(it["result"], it) })
  puts "", "## Exact printing from the collector line, M15–ONE and MOM+ only (AC-1.3)", "",
    spike::Rates.markdown("Printing", spike::Rates.breakdown(with_set_line) { spike::Scoring.printing_identified?(it["result"], it) }),
    "", "Lookup outcomes: #{with_set_line.map { it.dig("result", "lookup", "status") }.tally}"
  [ 1, 3 ].each do |count|
    puts "", "## Correct card in the top #{count} (AC-3.3)", "",
      spike::Rates.markdown("Top #{count}", spike::Rates.breakdown(rows) { spike::Scoring.in_top?(it["match"], it, count) })
  end
  times = rows.map { it.dig("match", "query_ms") }
  puts "", "Query time: median #{spike::Scoring.percentile(times, 50)} ms, p95 #{spike::Scoring.percentile(times, 95)} ms (n=#{times.size})"
  puts "", "## Not in the top 3 (AC-1.7)", "", "| File | Expected | Name strip | Collector strip | Top 3 | Likely cause |", "|---|---|---|---|---|---|"
  rows.reject { spike::Scoring.in_top?(it["match"], it, 3) }.each do |row|
    top = row.dig("match", "candidates").first(3).map { it["card_name"] }.join("; ")
    puts "| #{row["file"]} | #{cell(row["name"])} | #{cell(row.dig("result", "name_text"))} | #{cell(row.dig("result", "collector_text"))} | #{cell(top)} | |"
  end
  if other
    diffs = spike::Scoring.differences(results, read_json(run_dir(other), "ocr_results.json").fetch("results"))
    puts "", "## Replay #{label} vs #{other} (AC-1.5)", "", "#{diffs.map { it["file"] }.uniq.size} of #{results.size} photos differ"
    diffs.each { puts "- #{it["file"]} #{it["field"]}: #{it["a"].inspect} vs #{it["b"].inspect}" }
  end
  ```
- [ ] Run `bin/rubocop spikes/`. Expect: no offenses. Commit: `feat(spike): add matching and report scripts`
- [ ] With the spike server running as a background task, run `bundle exec ruby spikes/card_scanner/script/replay.rb run-a`, then `bundle exec ruby spikes/card_scanner/script/replay.rb run-b` (AC-1.5: same machine, twice). Expect: `N photos -> …/ocr.json` for each, where N equals the corpus size.
- [ ] Run `bin/rails runner spikes/card_scanner/script/match.rb run-a` and `… match.rb run-b`. Expect: `N results -> …` for each.
- [ ] Run `bundle exec ruby spikes/card_scanner/script/report.rb run-a run-b > tmp/card_scanner_spike/report.md`. Expect: tables for AC-1.3 (name read, exact printing plus the outcome tally), AC-3.3 (top 1, top 3, query time), the AC-1.7 miss list and the AC-1.5 difference count.
- [ ] For each AC-1.7 miss, view its crops (`replays/run-a/crops/<file>-{name,collector}.png`) and fill in the likely cause: glare, blur, strip misalignment, unusual frame, parser miss or matcher miss. Keep the completed table for `research.md`. (No commit; the outputs are ignored until Phase 8 copies the fixtures.)

---

## Phase 6: On-device timing and the no-third-party-host check

**Implements:** NFR Security (evidence) | **Satisfies:** AC-1.6
**Files:** `spikes/card_scanner/lib/card_scanner_spike/timings.rb`, `spikes/card_scanner/spec/card_scanner_spike/timings_spec.rb`, `spikes/card_scanner/lib/card_scanner_spike.rb`, `spikes/card_scanner/script/timing_summary.rb`
**Interfaces:** Consumes: the server's `requests.jsonl`, `timings-*.json` and `csp-reports.jsonl`; `Scoring.percentile`. Produces: `Timings.sessions(lines, ip:) -> [Session(started_at, requests, bytes)]`.

- [ ] Write the failing spec `spikes/card_scanner/spec/card_scanner_spike/timings_spec.rb`:
  ```ruby
  require_relative "../spike_helper"

  RSpec.describe CardScannerSpike::Timings do
    def line(path, bytes, ip: "192.168.1.20", method: "GET") = { at: "t", ip:, method:, path:, bytes: }.to_json

    it "splits one device's requests into page loads with their bytes", :aggregate_failures do
      lines = [ line("/ocr.html", 1000), line("/ocr/v7.0.0/core/x.wasm.js", 5000), line("/ocr.html", 1000, ip: "127.0.0.1"),
                line("/ocr.html", 1000), line("/timings", 20, method: "POST") ]
      sessions = described_class.sessions(lines, ip: "192.168.1.20")
      expect(sessions.map(&:bytes)).to eq([ 6000, 1020 ])
      expect(sessions.map(&:requests)).to eq([ 2, 2 ])
    end

    it "ignores requests before the first page load" do
      expect(described_class.sessions([ line("/favicon.ico", 10) ], ip: "192.168.1.20")).to eq([])
    end
  end
  ```
- [ ] Run `bundle exec rspec spikes/card_scanner/spec/card_scanner_spike/timings_spec.rb`. Expect: FAIL (`uninitialized constant CardScannerSpike::Timings`).
- [ ] Implement `spikes/card_scanner/lib/card_scanner_spike/timings.rb`:
  ```ruby
  require "json"

  module CardScannerSpike
    # Splits the spike server's request log into one device's page loads (AC-1.6).
    module Timings
      Session = Data.define(:started_at, :requests, :bytes)
      PAGE = "/ocr.html"

      module_function

      def sessions(lines, ip:)
        lines.map { JSON.parse(it) }.select { it["ip"] == ip }
          .slice_before { it["method"] == "GET" && it["path"] == PAGE }
          .select { it.first["path"] == PAGE }
          .map { Session.new(started_at: it.first["at"], requests: it.size, bytes: it.sum { |entry| entry["bytes"] }) }
      end
    end
  end
  ```
  In `spikes/card_scanner/lib/card_scanner_spike.rb`, add `require_relative "card_scanner_spike/timings"`.
- [ ] Run the same command. Expect: 2 examples, 0 failures.
- [ ] Add `spikes/card_scanner/script/timing_summary.rb`:
  ```ruby
  # Summarises one device's page loads, posted timings and CSP reports (AC-1.6, NFR Security).
  # Usage: bundle exec ruby spikes/card_scanner/script/timing_summary.rb <device ip>
  require "bundler/setup"
  require "json"
  require_relative "../lib/card_scanner_spike"

  ip = ARGV.fetch(0) { abort "usage: timing_summary.rb <device ip>" }
  logs = File.join(CardScannerSpike::WORK_DIR, "logs")
  CardScannerSpike::Timings.sessions(File.readlines(File.join(logs, "requests.jsonl")), ip:).each_with_index do |session, index|
    puts "Page load #{index + 1} at #{session.started_at}: #{session.requests} requests, #{session.bytes} bytes"
  end
  Dir[File.join(logs, "timings-*.json")].sort.each do |path|
    timings = JSON.parse(File.read(path))
    next unless timings["user_agent"].to_s.include?("iPhone")

    times = timings.fetch("results").map { it["ms"] }
    puts "#{File.basename(path)}: ready #{timings["ready_ms"]} ms, #{times.size} photos, " \
      "median #{CardScannerSpike::Scoring.percentile(times, 50)} ms, slowest #{times.max} ms"
  end
  reports = File.join(logs, "csp-reports.jsonl")
  puts "CSP violation reports: #{File.exist?(reports) ? File.readlines(reports).size : 0}"
  ```
- [ ] Run `bin/rubocop spikes/`. Expect: no offenses. Commit: `feat(spike): add device timing summary`
- [ ] Start the spike server as a background task and move the old logs aside: `mv tmp/card_scanner_spike/logs tmp/card_scanner_spike/logs-desktop`. Run `curl -sI http://127.0.0.1:4100/ocr.html | grep -i content-security-policy`. Expect: the `Server::CSP` value. Record it for NFR Security.
- [ ] **Checkpoint (maintainer):**
  1. Open port 4100 for this session only: `sudo firewall-cmd --add-port=4100/tcp` (runtime only; it's gone after a reboot or `--reload`).
  2. On the iPhone, clear this site's data (Settings → Safari → Advanced → Website Data → remove the dev machine's IP).
  3. In a Safari tab, open `http://<dev-ip>:4100/ocr.html`, wait for "Ready", and pick at least 10 corpus photos (**cold**).
  4. Reload the same tab and pick the same photos again (**warm**).
  5. Afterwards, run `sudo firewall-cmd --remove-port=4100/tcp`.
- [ ] Run `bundle exec ruby spikes/card_scanner/script/timing_summary.rb <iphone-ip>`. Expect: two page loads (cold then warm) with their bytes, two timing lines (ready ms, median and slowest ms over ≥ 10 photos), and `CSP violation reports: 0`. Record everything for AC-1.6. A cold load with OCR succeeding and zero reports is the NFR Security evidence.
- [ ] Optionally run the same page in desktop Firefox with devtools open, and keep a network-log screenshot out of the repo (the spec lists it as optional).

---

## Phase 7: Headless camera testing

**Implements:** Story 2 | **Satisfies:** AC-2.1, AC-2.2, AC-2.3, AC-2.4
**Files:** `spikes/card_scanner/public/{camera.html,camera.js}`, `spikes/card_scanner/spec/camera_spec.rb`
**Interfaces:** Consumes: `CardScannerSpike::Server` and one corpus photo (`CAMERA_SOURCE`). Produces: `tmp/card_scanner_spike/camera-results.jsonl` (`{approach, distance, seconds}` per example).

- [ ] Add `spikes/card_scanner/public/camera.html`:
  ```html
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Card scanner spike: camera</title>
    <script type="module" src="/camera.js"></script>
  </head>
  <body>
    <button id="start" type="button">Start camera</button>
    <button id="capture" type="button" disabled>Capture</button>
    <video id="video" autoplay muted playsinline width="360"></video>
    <p>Frame hash: <output id="frame-hash"></output></p>
    <p>Source hash: <output id="source-hash"></output></p>
    <p id="status" aria-live="polite"></p>
  </body>
  </html>
  ```
  and `spikes/card_scanner/public/camera.js`:
  ```js
  // Phase 0 camera spike (spec 005, Story 2): start a camera, capture one frame, and hash it
  // and the source photo with the same 16×16 average hash so a test can compare them.
  function averageHash(source, width, height) {
    const canvas = Object.assign(document.createElement("canvas"), { width: 16, height: 16 })
    const context = canvas.getContext("2d", { willReadFrequently: true })
    context.drawImage(source, 0, 0, width, height, 0, 0, 16, 16)
    const { data } = context.getImageData(0, 0, 16, 16)
    const grey = []
    for (let i = 0; i < data.length; i += 4) grey.push(0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2])
    const mean = grey.reduce((sum, value) => sum + value, 0) / grey.length
    return grey.map((value) => (value > mean ? "1" : "0")).join("")
  }

  const video = document.getElementById("video")
  const capture = document.getElementById("capture")
  const status = document.getElementById("status")
  let stream = null

  document.getElementById("start").addEventListener("click", async () => {
    try {
      stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false })
      video.srcObject = stream
      await video.play()
      capture.disabled = false
      status.textContent = `Camera: ${stream.getVideoTracks()[0].label}`
    } catch (error) {
      status.textContent = `Camera error: ${error.name}`
    }
  })

  capture.addEventListener("click", () => {
    document.getElementById("frame-hash").value = averageHash(video, video.videoWidth, video.videoHeight)
    stream.getTracks().forEach((track) => track.stop())
    video.srcObject = null
  })

  const source = new URLSearchParams(location.search).get("source")
  if (source) {
    const image = await createImageBitmap(await (await fetch(`/corpus/${encodeURIComponent(source)}`)).blob())
    document.getElementById("source-hash").value = averageHash(image, image.width, image.height)
  }
  ```
- [ ] Commit: `feat(spike): add camera capture spike page`
- [ ] Make the Chrome fake-camera file from the chosen photo: `ffmpeg -y -loop 1 -i "$CARD_SCANNER_CORPUS/<file>" -t 2 -r 10 -vf "scale=720:-2,format=yuv420p" tmp/card_scanner_spike/camera.y4m`. Expect: a `.y4m` file (it can be large; it stays in `tmp/`).
- [ ] Add `spikes/card_scanner/spec/camera_spec.rb`:
  ```ruby
  require_relative "spike_helper"
  require "capybara/rspec"
  require "cgi"
  require "selenium-webdriver"
  require "card_scanner_spike/server"
  require "tmpdir"

  CAMERA_SOURCE = ENV.fetch("CAMERA_SOURCE") { abort "Set CAMERA_SOURCE to a corpus photo file name" }
  CAMERA_Y4M = File.join(CardScannerSpike::WORK_DIR, "camera.y4m")
  MATCH_THRESHOLD = 32 # of 256 average-hash bits

  Capybara.app = CardScannerSpike::Server.new(public_dir: File.join(CardScannerSpike::ROOT, "public"),
    ocr_dir: File.join(CardScannerSpike::WORK_DIR, "ocr"), corpus_dir: CardScannerSpike.corpus_dir, log_dir: Dir.mktmpdir)
  Capybara.server = :puma, { Silent: true }
  Capybara.default_max_wait_time = 10

  Capybara.register_driver(:firefox_fake_camera) do |app|
    options = Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ],
      prefs: { "media.navigator.streams.fake" => true, "media.navigator.permission.disabled" => true })
    Capybara::Selenium::Driver.new(app, browser: :firefox, options:)
  end

  Capybara.register_driver(:chrome_file_camera) do |app|
    options = Selenium::WebDriver::Chrome::Options.new(args: [ "--headless=new", "--use-fake-ui-for-media-stream",
      "--use-fake-device-for-media-stream", "--use-file-for-fake-video-capture=#{CAMERA_Y4M}" ])
    Capybara::Selenium::Driver.new(app, browser: :chrome, options:)
  end

  RSpec.describe "Headless camera spike", type: :feature do # rubocop:disable RSpec/DescribeClass -- experiments, not a class
    around do |example|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      example.run
      seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(2)
      File.open(File.join(CardScannerSpike::WORK_DIR, "camera-results.jsonl"), "a") do |file|
        file.puts({ approach: example.metadata[:approach], distance: @distance, seconds:, passed: example.exception.nil? }.to_json)
      end
    end

    def capture_distance
      expect(page).to have_css("#source-hash", text: /\A[01]{256}\z/)
      click_on "Start camera"
      expect(page).to have_button("Capture", disabled: false)
      click_on "Capture"
      expect(page).to have_css("#frame-hash", text: /\A[01]{256}\z/)
      @distance = find("#frame-hash").text.chars.zip(find("#source-hash").text.chars).count { |a, b| a != b }
    end

    it "Firefox's fake camera shows a synthetic pattern, not the card (AC-2.1)", approach: "firefox-fake", driver: :firefox_fake_camera do
      visit "/camera.html?source=#{CGI.escape(CAMERA_SOURCE)}"
      expect(capture_distance).to be > MATCH_THRESHOLD
    end

    it "Chrome plays the card from a file as the camera (AC-2.3a)", approach: "chrome-file", driver: :chrome_file_camera do
      visit "/camera.html?source=#{CGI.escape(CAMERA_SOURCE)}"
      expect(capture_distance).to be <= MATCH_THRESHOLD
    end

    it "an in-page stream drawn from the card works in Firefox (AC-2.3b)", approach: "firefox-in-page", driver: :firefox_fake_camera do
      visit "/camera.html?source=#{CGI.escape(CAMERA_SOURCE)}"
      page.execute_script(<<~JS, CAMERA_SOURCE)
        const file = arguments[0]
        navigator.mediaDevices.getUserMedia = async () => {
          const image = await createImageBitmap(await (await fetch(`/corpus/${encodeURIComponent(file)}`)).blob())
          const canvas = Object.assign(document.createElement("canvas"), { width: image.width, height: image.height })
          const context = canvas.getContext("2d")
          setInterval(() => context.drawImage(image, 0, 0), 100)
          context.drawImage(image, 0, 0)
          return canvas.captureStream(10)
        }
      JS
      expect(capture_distance).to be <= MATCH_THRESHOLD
    end
  end
  ```
  (If RuboCop flags `RSpec/InstanceVariable` for `@distance`, disable it inline with the justification "carries the measured distance to the recording hook".)
- [ ] Run `CAMERA_SOURCE=<file> bundle exec rspec spikes/card_scanner/spec/camera_spec.rb --format documentation`. Expect: each example's pass or fail status, which **is** the finding. The first Chrome run may download Chrome for Testing through Selenium Manager; record that in the setup cost. Record the Firefox driver prefs, each distance, and each example's seconds from `camera-results.jsonl` (AC-2.1, AC-2.2, AC-2.3).
- [ ] Run `for i in $(seq 10); do CAMERA_SOURCE=<file> bundle exec rspec spikes/card_scanner/spec/camera_spec.rb; done`. Tally the passes and failures per approach from `camera-results.jsonl`, with any failure messages (AC-2.3 flakiness, and AC-2.4 for the approach the findings recommend).
- [ ] Record the CI setup needed per approach. Check whether GitHub's `ubuntu-latest` image lists Chrome and ffmpeg (from the runner-images README). Record the extra per-run cost (the Chrome download, generating the `.y4m`) and how the suite's run time would change, using each example's seconds. Note that v4l2loopback was considered but not tried, because it needs a root kernel module.
- [ ] Run `bin/rubocop spikes/`. Expect: no offenses. Commit: `test(spike): add headless camera experiments`

---

## Phase 8: Findings, ADRs and fixtures

**Implements:** Story 4, FR-4 | **Satisfies:** AC-4.1, AC-4.2, AC-4.3, AC-4.4
**Files:** `docs/specs/005-card-scanner-phase-0/research.md`, `docs/adr/{README.md,0001-browser-ocr-engine-and-asset-hosting.md,0002-camera-path-testing.md,0003-card-name-index.md}`, `spec/fixtures/card_scanner/{ground_truth.json,ocr_results.json,name_matches.json}`, `spikes/card_scanner/README.md`
**Interfaces:** Consumes: every recorded output from Phases 2–7. Produces: the Phase 0 deliverables.

- [ ] Copy the fixtures: `cp tmp/card_scanner_spike/replays/run-a/{ocr_results,name_matches}.json spec/fixtures/card_scanner/`. Check that no image is included: `git status --porcelain spec/fixtures/card_scanner` should list JSON files only (AC-4.4). Commit: `test(spike): add OCR result and name match fixtures from run-a`
- [ ] Write `docs/adr/README.md`:
  ```markdown
  # Architecture Decision Records

  One file per decision: `docs/adr/NNNN-<slug>.md`, four digits, numbered from 0001 in the order written and never renumbered.

  Each ADR has these sections, in this order:

  - **Title**: `# NNNN: <decision>` as the first line
  - **Status**: `Proposed`, `Accepted`, `Rejected` or `Superseded by NNNN`
  - **Context**: the problem and the evidence, linking the spec or research
  - **Decision**: what we will do
  - **Consequences**: what follows, good and bad

  Specs and plans link the ADRs they rely on. To change a decision, write a new ADR that supersedes the old one.
  ```
  Commit: `docs(adr): add the ADR convention`
- [ ] Write `docs/specs/005-card-scanner-phase-0/research.md` with these sections, in this order:
  1. **Summary.** One paragraph per spike, then the headline numbers.
  2. **Method and apparatus.** The spike server and its policy header, the asset versions and sha256 values, the guide and strip values with the number of pilot tuning rounds, and where the corpus lives by convention (`$CARD_SCANNER_CORPUS`).
  3. **Spike 1: OCR strip accuracy.** Question, method, the report tables (AC-1.3), the replay differences (AC-1.5), iPhone cold and warm timings (AC-1.6), the miss list with causes (AC-1.7), and a recommendation.
  4. **Spike 2: headless camera testing.** Question, method, a per-approach table (works, setup on the dev machine and in CI, run time, 10-run pass count, failures), and a recommendation.
  5. **Spike 3: fuzzy name index.** Question, method, round-trip result (AC-3.1), build time, size and count (AC-3.2), top-1 and top-3 rates with query times (AC-3.3), the edge-case table (AC-3.4), the refresh cost (AC-3.5), and a recommendation.
  6. **Privacy evidence.** The header sent, a successful cold iPhone OCR run, and the CSP report count.
  7. **Fixtures.** Every field of `ground_truth.json`, `ocr_results.json` and `name_matches.json`, and which run they came from (AC-4.4).
  8. **Recommended Phase 1 scope.** What's in, what's out, and what changed from the roadmap (AC-4.2).
  9. **Roadmap assumptions contradicted.** Each with its evidence (AC-4.2).
  10. **Decisions.** Links to ADRs 0001–0003 (AC-4.3).

  Every number carries its n, and every estimate is labelled "estimate" (FR-4). Commit: `docs(spec): add 005 Phase 0 findings`
- [ ] Write ADRs 0001 (the OCR engine and how its assets are hosted), 0002 (the camera-path testing approach) and 0003 (the card-name index approach) in the README's format, each with `Status: Proposed`, the evidence and a link back to `research.md`. Commit: `docs(adr): propose OCR, camera-testing and name-index decisions`
- [ ] Update `spikes/card_scanner/README.md` with the exact commands used and where each result landed. Commit: `docs(spike): document how the spikes were run`

---

## Phase 9: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs; AC-4.5

- [ ] Run all the spike specs except the camera ones: `bundle exec rspec spikes/card_scanner/spec --exclude-pattern "**/camera_spec.rb"`. Expect: 0 failures.
- [ ] Run `bin/ci`. Expect: every step passes (RuboCop covers `spikes/`; RSpec runs only `spec/**`).
- [ ] Check the allowed paths (AC-4.5): `git diff main --name-only | grep -Ev '^(docs/|spikes/card_scanner/|spec/fixtures/card_scanner/)'`. Expect: no output. Then `git diff main --stat -- Gemfile Gemfile.lock app public vendor config db`. Expect: empty.
- [ ] Check that no images are committed: `git diff main --name-only | grep -Ei '\.(jpe?g|png|heic|y4m)$'`. Expect: no output.
- [ ] Walk through every acceptance criterion (AC-1.1 to AC-4.5) against `research.md` and the fixtures, then run `sdd-superpowers:sdd-review` Mode B (on Fable).

---

## Quickstart Validation

```bash
spikes/card_scanner/script/fetch_ocr_assets                          # pinned engine → tmp/card_scanner_spike/ocr
bundle exec puma -C spikes/card_scanner/puma.rb                      # spike server on :4100 (background)
bin/rails runner spikes/card_scanner/script/build_ground_truth.rb    # manifest → ground_truth.json
bin/rails runner spikes/card_scanner/script/build_name_index.rb      # names.sqlite3
bundle exec ruby spikes/card_scanner/script/replay.rb run-a          # OCR every photo in headless Firefox
bin/rails runner spikes/card_scanner/script/match.rb run-a           # parse, look up, name candidates
bundle exec ruby spikes/card_scanner/script/report.rb run-a          # Markdown tables
bundle exec rspec spikes/card_scanner/spec --exclude-pattern "**/camera_spec.rb"
```
