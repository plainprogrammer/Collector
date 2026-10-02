# Implementation Plan: Card Scanner Phase 1 — Live Capture and Re-measure

**Spec:** docs/specs/007-card-scanner-live-capture/spec.md (v2.0.0, Approved)
**Decisions:** docs/adr/0001-browser-ocr-engine-and-asset-hosting.md, 0002-camera-path-testing.md, 0003-card-name-index.md (Proposed → Accepted in Phase 0, AC-7.4)
**Created:** 2026-09-30
**Revised:** 2026-09-30, after the plan review (Fable): import map–safe and README-anchored assertions, a `camera:stopped` event and a feed-ready wait against a shutter race, geometry loaded through a nonce'd module script in the synthetic-card helper, rubocop-rspec fixes, Brakeman notes for both `send_file`s, no bare `c-section`, and an orientation check on the iPhone
**Revised:** 2026-10-01, during execution (spec v2.0.0): Phase 11 replays the 50 Phase 0 photos through the photo path and reports the tuning rounds' live captures as biased live evidence, because the corpus cards were returned.
**Revised:** 2026-10-01, during execution: dev HTTPS by a self-signed certificate (bin/dev-certificate) and Puma's ssl:// bind, after the maintainer's Cloudflare tunnel returned 502; the spec is unchanged (AC-7.1 names no mechanism)

## Context

Phase 0 (spec 005) showed that self-hosted Tesseract.js, an FTS5 trigram name index and headless camera tests all work. Accuracy didn't: on hand-held photos with a fixed guide, the right card was in the top 3 for 26 of 50 photos, and the exact printing was found for 7 of 45. This plan builds the scanner page into the app with a live camera and the guide drawn over it, fixes the parser and matcher gaps Phase 0 found, adds a development-only measurement mode, and re-measures the same 50 physical cards. Nothing can be added to the collection yet. That is the next spec, written only if the maintainer rules the numbers good enough.

**Facts established during planning (2026-09-30):**
- **Engine files.** `tesseract.js` 7.0.0 builds its core path in `src/worker-script/browser/getCore.js`. With `oem` 1 (LSTM only, the default), it loads only `tesseract-core-lstm.wasm.js`, `tesseract-core-simd-lstm.wasm.js` or `tesseract-core-relaxedsimd-lstm.wasm.js`.
  - The engine therefore needs 6 files, 14,828,864 bytes in total, not ADR 0001's 28.9 MB.
  - The tarball SHA-256 digests match research.md §2. The per-file digests were computed from those verified tarballs and are pinned in Phase 4.
- **CSP baseline.** The app sends no CSP today: `config/initializers/content_security_policy.rb` is entirely commented out.
  - Rails 8.1.4's policy DSL has `:wasm_unsafe_eval` and `:blob`.
  - importmap-rails 2.2.3 puts `request.content_security_policy_nonce` on its inline tags. Its import map tag is `data-turbo-track="reload"`.
- **Refresh hook.** `Catalog::Refresh#call` finishes `applied` after `retire_unseen`. A scheduled run for an already-applied version finishes `skipped` with "<version> already applied" (`refresh.rb:21`, `:35–43`). "Already running" skips happen earlier, in `RefreshRun.start!`, and never reach `#call`'s body.
- **SQLite.** `create_virtual_table` and `drop_virtual_table` exist in Rails 8.1.4's SQLite3 adapter. SQLite has `json_each` and `json_array_length`. The stdlib has `DidYouMean::JaroWinkler` and `DidYouMean::Levenshtein`.
- **Tests.** System specs run Selenium headless Firefox (`spec/support/system.rb`). `window.Stimulus` is exposed (`app/javascript/controllers/application.js`). `spec/support/narrow_frame.rb` tests phone widths in a same-origin iframe.
- **Measurement data.** The corpus manifest is `~/card-scanner-corpus/manifest.csv` (`file,set,number,foil`). Ground truth for the 50 cards is committed in `spec/fixtures/card_scanner/ground_truth.json`, and Phase 0's OCR text in `ocr_results.json` and `name_matches.json` (format_version 1).
- **Dev HTTPS.** The maintainer will reach the dev server over HTTPS through their own tunnel (decided 2026-09-30). The app only has to accept the tunnel's host name and trust that the request was HTTPS. The tunnel didn't work in this environment (the maintainer's Cloudflare tunnel returned 502 and no request reached Rails), so for Phases 10–11 a self-signed certificate for the LAN address (`bin/dev-certificate`), served by Puma's `ssl://` bind and trusted once on the iPhone, replaced it.

**Plan decisions (beyond the spec):**
- **Engine files** (maintainer, 2026-09-30): `bin/fetch-ocr-engine` (stdlib-only Ruby, `Collector::OcrEngine`) downloads the three pinned tarballs, checks each tarball's and each file's SHA-256, and unpacks the six files into the ignored `vendor/ocr/v7.0.0/`. `bin/setup`, so also `bin/ci`, and the Dockerfile's build stage run it.
- **Engine serving:** `OcrAssetsController` at `/ocr/v7.0.0/*path`, not `public/`. It serves only the pinned files, with `Cache-Control: max-age=31536000, public, immutable`, a fixed ETag and Last-Modified, and `304` for `If-None-Match` or `If-Modified-Since`. Rack's static file server can't set `immutable` per path or answer `If-None-Match`.
- **Policy only on scanner pages:** a `ScannerPage` controller concern holds the policy. Nonces are generated only for requests that have a policy, so other pages' import map tags carry no nonce and Turbo Drive keeps working between them.
  - The scanner page sets `turbo-visit-control: reload`, so its policy always arrives with a full load.
  - Because the tracked import map tag differs, leaving the scanner page also reloads, so its policy never leaks into the next page.
- **Name index in the core** (maintainer ruling):
  - `catalog_names` holds `collectible_type`, `catalog_identity_id`, `name` and `normalized`. `catalog_names_fts` is an external-content FTS5 trigram table over `normalized`.
  - `Catalog::NameIndex` rebuilds and searches it. Identity names come from the core. A source class may add other names through `.alternate_names(entries)`; MTG adds face names.
- **Matching:**
  - `MTG::CollectorLine` (parser, MTG extension).
  - `Catalog::Entry.printed_as` (core lookup scope).
  - `MTG::Reading` (one scan's text → parsed line, lookup outcome, name candidates and final ranking).
- **Front end:** three small Stimulus controllers plus two plain modules:
  - `camera` (stream lifecycle, guide, torch, frame grab).
  - `card-reader` (engine, strips, OCR, sending the text, showing the Turbo Stream answer).
  - `measurement` (development uploads).
  - `scanner/geometry.js` (guide and strip maths shared by live frames and photos).
  - `scanner/recognition.js` (one Tesseract worker per page session).
- **Synthetic test card:** system specs replace `getUserMedia` with a canvas stream (ADR 0002). The canvas draws a white 63:88 card, with its name and collector line written exactly where the strips are cut, using the page's own `scanner/geometry` module. No image fixture is committed, and real OCR runs on it.
- **Measurement mode:**
  - `config.x.scanner_measurement = { manifest:, dir: }` is set in `development.rb` and `nil` elsewhere; specs set it in an `around` hook.
  - Captures go to `<dir>/<file>/capture-NNN{.json,-name.png,-collector.png}`.
  - The desktop replay page and the strip endpoint are local-only and need no sign-in, so a headless script can drive them.
- **Findings tooling:** `Collector::ScannerFindings` (rates, scoring, re-scoring through `MTG::Reading`, ground truth for tuning manifests) and `lib/tasks/scanner.rake`. A development-only `Collector::RequestLog` middleware records response bytes for the cold and warm iPhone loads, as the Phase 0 spike server did.
- **Migration version:** `20260930170000`, not the next sequential `…000006`. Feature 006 (collection list view) is being built in parallel and may take `…000006`, and two migrations with the same version would collide on merge.
- **Tunnel support:** Rails' built-in `RAILS_DEVELOPMENT_HOSTS` allows the tunnel's host name, and `COLLECTOR_HTTPS=true` sets `assume_ssl` in development too, so CSRF origin checks pass behind a tunnel that ends TLS. The tunnel didn't work in this environment, so the self-signed route (`bin/dev-certificate` plus Puma's `ssl://` bind, where Rails sees real HTTPS) replaced it for Phases 10–11; the tunnel support stays as the documented alternative.

**Maintainer inputs (ask for all of them at the start of execution, per the work-ahead memory):**
1. That the `bin/dev-certificate` certificate is trusted on the iPhone (originally: the tunnel host name, for `RAILS_DEVELOPMENT_HOSTS`).
2. 10 or more English cards **not** in the 50-card corpus, mixed eras, with a `tuning/manifest.csv` (Phase 10).
3. The 50 corpus cards to hand for the measured run (Phase 11).
4. The iPhone for the manual device checks (AC-6.5).

## Global Constraints

- English only; MTG only. No card detection, rectification, art hashing, flavour names, bulk scanning or native apps (spec Non-Goals).
- Nothing on the scanner page adds to a lot or collection, and no link anywhere in the app points to the scanner (FR-1, AC-1.7, AC-3.10).
- No frame, strip or photo leaves the device outside development measurement mode. In normal use only recognised text is sent, to the app's own origin (FR-3).
- The engine is Tesseract.js 7.0.0, core 7.0.0 and `eng` `4.0.0_best_int`, served from `/ocr/v7.0.0/` (ADR 0001).
- The scanner page's policy allows scripts, workers and connections only from `'self'`, plus `blob:` for the worker, `'wasm-unsafe-eval'` and a per-request nonce. No other host is allowed for scripts, workers, connections or frames. Other pages send no Content-Security-Policy header (AC-2.3, AC-2.4).
- The name index is global catalog data (no `account_id`), keyed by collectible type, kept in `schema.rb`, and rebuilt in full by a refresh run that is applied, or skipped while the index is empty (FR-5).
- Measurement mode exists only when `config.x.scanner_measurement` is set: by default in development, never in production or test unless a spec sets it. Its files go outside the repository and outside `storage/`. Committed fixtures are text only (FR-6, AC-6.6).
- The strip geometry, OCR settings and matcher settings are tuned only on cards outside the 50-card corpus, then frozen and committed before the measured run (AC-6.1).
- No pass threshold is set. The findings report rates with sample sizes, and the maintainer decides (AC-6.7).
- UI follows `docs/design-system/`: tokens and `c-*` classes only, with new patterns in `collector/additions.css` and a doc (FR-1). Copy is sentence case, says "you", and uses no "we" and no exclamation marks.
- Every commit is one discrete step in Conventional Commit form (`docs/git-convention.md`; memory: small incremental commits). Judgement calls go in commit bodies as `Ruling: <what> — <why> — <cost if wrong>`.

---

## Goal

A signed-in collector can open `/scanner` on a phone over HTTPS, line a card up with a live 63:88 guide, capture it, and see the recognised text plus up to 3 candidate printings, read on-device. Then the measurement is scored against Phase 0: the 50 Phase 0 photos are replayed through the shipped photo path, and the tuning rounds' live captures are reported as biased live evidence. (The original goal was to re-capture the same 50 cards live; spec v2.0.0 replaced that, because the cards were returned.)

---

## Phase 0: Branch, documents and ADRs

**Implements:** — | **Satisfies:** AC-7.4
**Files:** `docs/specs/007-card-scanner-live-capture/{spec.md,plan.md,data-model.md,contracts/api.md}`, `docs/adr/000{1,2,3}-*.md`
**Interfaces:** Consumes: nothing. Produces: the branch `007-card-scanner-live-capture` and Accepted ADRs.

Create the branch named by the convention and commit the approved documents before any code. ADRs 0001–0003 become Accepted, and each records how it changed from its Proposed text.

- [ ] Create the branch from the worktree's branch: `git switch -c 007-card-scanner-live-capture`. The spec's **Branch:** field already names it.
- [ ] Check that `plan.md`, `data-model.md` and `contracts/api.md` (written when the plan was approved) are in `docs/specs/007-card-scanner-live-capture/`.
- [ ] Commit: `docs(spec): add spec, plan, data model and contracts for 007`
- [ ] In `docs/adr/0001-browser-ocr-engine-and-asset-hosting.md`, replace `Proposed` under `## Status` with `Accepted (2026-09-30, spec 007 plan)`, and add before `## Consequences`:

  ```markdown
  ## Changes from the Proposed text (spec 007)

  - Only the three LSTM-only core builds are hosted (`tesseract-core-lstm`, `-simd-lstm`, `-relaxedsimd-lstm`): with `oem` 1 the engine never requests the others (`getCore.js`). Six files, 14,828,864 bytes.
  - The files aren't committed. `bin/fetch-ocr-engine` downloads the pinned tarballs, checks each tarball's and each file's SHA-256, and unpacks them into the ignored `vendor/ocr/v7.0.0/`. `bin/setup` (so `bin/ci`) and the Dockerfile build run it; a spec checks every installed file against its pin.
  - The app serves them from `/ocr/v7.0.0/` through `OcrAssetsController`, not `public/`: only the pinned files, `Cache-Control: public, max-age=31536000, immutable`, and `304` for `If-None-Match` or `If-Modified-Since`.
  - The scanner's policy also carries a per-request nonce for its own inline tags (the import map), `style-src 'self' 'unsafe-inline'`, `img-src` for the hosts catalog pages already use for card images, and `frame-src 'none'`. Only scanner pages send a policy; the page always loads in full so its policy applies.
  ```
- [ ] In `docs/adr/0002-camera-path-testing.md`, make the same Status change and add:

  ```markdown
  ## Changes from the Proposed text (spec 007)

  - The fixture card is drawn in the page: the substituted stream paints a white 63:88 card whose name and collector line sit exactly where the scanner cuts its strips (the page's own `scanner/geometry` module), so real OCR runs on it and no image is committed.
  - The system driver grants camera access without a prompt and starts with Firefox's synthetic stream (`media.navigator.permission.disabled`, `media.navigator.streams.fake`); a spec then substitutes its card and restarts the page's camera controller.
  - The optional Chrome file-capture test isn't added in spec 007.
  ```
- [ ] In `docs/adr/0003-card-name-index.md`, make the same Status change and add:

  ```markdown
  ## Changes from the Proposed text (spec 007)

  - Tables are `catalog_names` (`collectible_type`, `catalog_identity_id`, `name`, `normalized`) and `catalog_names_fts`, in the collectible-agnostic catalog core and keyed by collectible type. Identity names come from the core; a source class may add others through `.alternate_names(entries)` (MTG adds face names of multi-face printings).
  - `Catalog::Refresh` rebuilds the index after an applied run, and when a scheduled run is skipped for an already-applied version while the index is empty, so an upgraded instance fills it on its next run.
  - Query cleaning drops tokens shorter than 3 characters from every line, then takes the longest line in which at least half the non-space characters are letters. Queries of 5 characters or fewer also match names within one edit whose length differs by at most 1; text that normalises to nothing is matched exactly against the raw name.
  ```
- [ ] Commit: `docs(adr): accept ADRs 0001–0003 with spec 007's changes`

---
## Phase 1: Name key and collector-line parser

**Implements:** FR-4 (parsing) | **Satisfies:** AC-3.6, AC-3.7 (and the normalisation in AC-3.4)
**Files:** `app/models/catalog/name_key.rb`, `app/models/mtg/collector_line.rb`, `spec/models/catalog/name_key_spec.rb`, `spec/models/mtg/collector_line_spec.rb`
**Interfaces:** Consumes: `spec/fixtures/card_scanner/ocr_results.json` (Phase 0). Produces:
- `Catalog::NameKey.call(text) → String`.
- `MTG::CollectorLine.parse(text, known_set_codes:) → MTG::CollectorLine::Result(set_code, number, language, foil, format)`. `set_code` is upper case, `number` has no leading zeros, `language` is a Scryfall code, `foil` is true, false or nil (never used for the finish, per FR-4), and `format` is one of `:slash`, `:rarity_first`, `:glued_rarity` or `:before_set_line`.
- `MTG::CollectorLine::WORD_SET_CODES`.

Both are ported from the spike (`spikes/card_scanner/lib/card_scanner_spike/{normaliser,collector_line}.rb`) and pure Ruby. The parser gains the fixes research.md §3 called for:
- a rarity letter glued to the number;
- the number nearest before the set line, for when the slash or rarity letter is lost;
- a set line that accepts any one- or two-character mark before a known language code;
- a loose set-code fallback that skips set codes which are also English words.

- [ ] Write `spec/models/catalog/name_key_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe Catalog::NameKey do
    it "folds ligatures, diacritics, case and punctuation", :aggregate_failures do
      expect(described_class.call("Æther Vial")).to eq("aether vial")
      expect(described_class.call("Lim-Dûl's Vault")).to eq("lim duls vault")
      expect(described_class.call("  Jötun   Grunt\n")).to eq("jotun grunt")
      expect(described_class.call("Fire // Ice")).to eq("fire ice")
    end

    it "folds full-width characters" do
      expect(described_class.call("Ｌｉｇｈｔｎｉｎｇ Bolt")).to eq("lightning bolt")
    end

    it "returns an empty string for nil and for text with no letters or digits", :aggregate_failures do
      expect(described_class.call(nil)).to eq("")
      expect(described_class.call("_____")).to eq("")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/name_key_spec.rb`. Expect: FAIL (`uninitialized constant Catalog::NameKey`).
- [ ] Implement `app/models/catalog/name_key.rb`:

  ```ruby
  # Folds a card name, or text read off a card, to the key names are compared by (spec 007 AC-3.4):
  # NFKC, ligatures, diacritics, case and apostrophes, then every other run of punctuation or space to one space.
  module Catalog::NameKey
    LIGATURES = { "Æ" => "AE", "æ" => "ae", "Œ" => "OE", "œ" => "oe", "ß" => "ss" }.freeze

    module_function

    def call(text)
      folded = text.to_s.unicode_normalize(:nfkc).gsub(Regexp.union(LIGATURES.keys), LIGATURES)
      folded.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
        .gsub(/['’‘`]/, "").gsub(/[^\p{L}\p{N}]+/, " ").strip
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/name_key_spec.rb`. Expect: 3 examples, 0 failures.
- [ ] Commit: `feat(catalog): add the name key that folds card names for matching`
- [ ] Write `spec/models/mtg/collector_line_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe MTG::CollectorLine do
    # AC-3.6: the known set codes are exactly these, so xyz and ffv are unknown.
    let(:known) { %w[neo dmu mom pmom cmm nec fin one sta] }
    let(:phase0) do
      JSON.parse(Rails.root.join("spec/fixtures/card_scanner/ocr_results.json").read)
        .fetch("results").to_h { [ it["file"], it["collector_text"] ] }
    end

    def parse(text) = described_class.parse(text, known_set_codes: known)

    describe "Phase 0's misses (AC-3.6)" do
      { "IMG_6723.jpeg" => %w[MOM 149], "IMG_6732.jpeg" => %w[CMM 697],
        "IMG_6711.jpeg" => %w[NEC 120], "IMG_6714.jpeg" => %w[FIN 258] }.each do |file, (set_code, number)|
        it "reads #{file}'s recorded text as #{set_code} #{number}" do
          expect(parse(phase0.fetch(file))).to have_attributes(set_code:, number:)
        end
      end

      it "uses the strings the spec quotes" do
        expect(phase0.fetch("IMG_6711.jpeg")).to eq("Vig 204\n—Shigeki, Jukar v1\n120 Ke\nNEC » EN do SAM BURLEY\n— eww")
      end

      it "doesn't read 'one' in flavour or rules text as the ONE set", :aggregate_failures do
        expect(parse(phase0.fetch("IMG_6728.jpeg")).set_code).to be_nil
        expect(parse(phase0.fetch("IMG_6736.jpeg")).set_code).to be_nil
      end

      it "reads the real ONE set in the SET • LANG shape" do
        expect(parse("R 0123\nONE • EN")).to have_attributes(set_code: "ONE", number: "123", language: "en")
      end
    end

    describe "WORD_SET_CODES (AC-3.7)" do
      it "lists one" do
        expect(described_class::WORD_SET_CODES).to include("one")
      end

      it "applies to the loose fallback only", :aggregate_failures do
        expect(parse("Add one mana of any color.").set_code).to be_nil
        expect(parse("0042 ONE • EN").set_code).to eq("ONE")
      end
    end

    describe "Phase 0's parser inputs (research.md §3)" do
      it "takes the number before the slash, not the set size", :aggregate_failures do
        expect(parse("051/302 NEO")).to have_attributes(set_code: "NEO", number: "51", format: :slash)
      end

      it "reads the M15–ONE two-line format" do
        expect(parse("051/302 R\nNEO • EN").to_h).to eq(set_code: "NEO", number: "51", language: "en", foil: false, format: :slash)
      end

      it "reads the foil star between set and language" do
        expect(parse("0123/0281 M\nDMU ★ EN").foil).to be(true)
      end

      it "accepts a bullet misread as a guillemet" do
        expect(parse("051/302 R\nNEO « EN")).to have_attributes(language: "en", foil: false)
      end

      it "reads the MOM and later rarity-first format" do
        expect(parse("R 0123\nMOM • EN").to_h).to eq(set_code: "MOM", number: "123", language: "en", foil: false, format: :rarity_first)
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

      it "rejects an unknown set code but keeps the number" do
        expect(parse("051/302 R\nXYZ • EN")).to have_attributes(set_code: nil, number: "51")
      end

      it "reads a pre-M15 number with no set code" do
        expect(parse("123/350")).to have_attributes(set_code: nil, number: "123")
      end

      it "returns empty fields for empty text" do
        expect(parse("").to_h.values).to all(be_nil)
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/collector_line_spec.rb`. Expect: FAIL (`uninitialized constant MTG::CollectorLine`).
- [ ] Implement `app/models/mtg/collector_line.rb`:

  ```ruby
  # Reads a card's collector line from OCR text (spec 007 FR-4, AC-3.6, AC-3.7). Printed shapes: pre-M15
  # `NNN/TTT`; M15–ONE `NNN/TTT R` then `SET • EN`; MOM and later `R NNNN` then `SET • EN`. OCR glues the
  # rarity to the number, drops the slash and misreads the bullet, so the number is tried against several
  # patterns in turn and the set line accepts any one- or two-character mark before a known language.
  # The foil mark is reported as read, but the scanner never uses it for the finish (FR-4).
  module MTG::CollectorLine
    Result = Data.define(:set_code, :number, :language, :foil, :format)

    LANGUAGES = { "EN" => "en", "JP" => "ja", "DE" => "de", "FR" => "fr", "IT" => "it", "ES" => "es",
                  "PT" => "pt", "RU" => "ru", "KO" => "ko", "CS" => "zhs", "CT" => "zht" }.freeze
    # Set codes that are also English words. The loose fallback skips them, because rules and flavour
    # text ("Add one") would otherwise read as a set; the SET • LANG shape still accepts them (AC-3.7).
    WORD_SET_CODES = %w[one war all ice big who mid].freeze
    LOOKALIKES = { "O" => "0", "D" => "0", "I" => "1", "L" => "1", "S" => "5", "B" => "8" }.freeze
    NUMBERISH = "[0-9ODILSB]"
    SLASH = %r{(?<![A-Z0-9])(#{NUMBERISH}{1,4})\s*/\s*#{NUMBERISH}{1,4}(?![A-Z0-9])}
    RARITY_FIRST = /(?<![A-Z0-9])[CURMSLTP]\s+(#{NUMBERISH}{1,4})([A-Z★]?)(?![A-Z0-9])/
    GLUED_RARITY = /(?<![A-Z0-9])[CURMSLTP]([0-9]#{NUMBERISH}{2,3})(?![A-Z0-9])/
    BARE_NUMBER = /(?<![A-Z0-9])(\d{1,4})(?![A-Z0-9])/
    SET_LINE = /(?<![A-Z0-9])([A-Z0-9]{3,5})[ \t]*(\S{1,2})?[ \t]*(#{LANGUAGES.keys.join("|")})(?![A-Z])/
    FOIL_MARKERS = %w[★ *].freeze

    module_function

    def parse(text, known_set_codes:)
      upper = text.to_s.unicode_normalize(:nfkc).upcase
      known = known_set_codes.to_set(&:upcase)
      line = set_line(upper, known)
      number, format = number(upper, before: line&.fetch(:at))
      Result.new(set_code: line ? line[:code] : loose_set_code(upper, known), number:,
        language: LANGUAGES[line&.fetch(:language)], foil: line && line[:marker] && FOIL_MARKERS.include?(line[:marker]), format:)
    end

    def set_line(upper, known)
      upper.to_enum(:scan, SET_LINE).each do
        match = Regexp.last_match
        code = resolve(match[1], known)
        return { code:, marker: match[2], language: match[3], at: match.begin(0) } if code
      end
      nil
    end

    def loose_set_code(upper, known)
      upper.split(/[^A-Z0-9]+/).each do |token|
        next if token.length < 3 || token.length > 5 || token.match?(/\A\d+\z/)

        code = resolve(token, known)
        return code if code && WORD_SET_CODES.exclude?(code.downcase)
      end
      nil
    end

    def resolve(code, known) = [ code, code.tr("0", "O"), code.tr("O", "0") ].find { known.include?(it) }

    def number(upper, before:)
      if (match = SLASH.match(upper)) then [ digits(match[1]), :slash ]
      elsif (match = RARITY_FIRST.match(upper)) then [ digits(match[1]) + match[2].downcase, :rarity_first ]
      elsif (match = GLUED_RARITY.match(upper)) then [ digits(match[1]), :glued_rarity ]
      elsif before && (last = upper[0, before].scan(BARE_NUMBER).last) then [ digits(last.first), :before_set_line ]
      else [ nil, nil ]
      end
    end

    def digits(token) = token.gsub(/[ODILSB]/, LOOKALIKES).sub(/\A0+(?=\d)/, "")
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/collector_line_spec.rb`. Expect: 20 examples, 0 failures.
- [ ] Commit: `feat(mtg): parse collector lines with glued rarity, lost slash and word set codes`

---

## Phase 2: Name index

**Implements:** FR-4 (name matching), FR-5 | **Satisfies:** AC-3.4, AC-3.5, AC-3.9
**Files:** `db/migrate/20260930170000_create_catalog_names.rb`, `db/schema.rb`, `app/models/catalog/name.rb`, `app/models/catalog/name_index.rb`, `app/models/catalog/sources.rb` (contract comment), `app/models/mtg/printing.rb`, `app/models/mtg/scryfall/source.rb`, `app/models/catalog/refresh.rb`, `spec/models/catalog/name_index_spec.rb`, `spec/models/catalog/refresh_spec.rb`
**Interfaces:** Consumes: `Catalog::NameKey.call`. Produces:
- `Catalog::NameIndex.new(collectible_type, source_class: Catalog.source_class(collectible_type))` with:
  - `#rebuild → Integer` (names written);
  - `#populated? → Boolean`;
  - `#search(text, limit: 3) → [Catalog::NameIndex::Candidate(identity_id, name, score)]`.
- `Catalog::NameIndex.clean(text) → String`.
- The optional source contract method `.alternate_names(entries) → [[identity_id, name], …]`.

Global catalog data in the primary database. A migration creates the table and its FTS5 index. `Catalog::Refresh` fills the index, and `db:prepare` never backfills it.

- [ ] Write `spec/models/catalog/name_index_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe Catalog::NameIndex, type: :model do
    subject(:index) { described_class.new("mtg") }

    def card(name, faces: [ name ], retired: false)
      identity = create(:catalog_identity, name:)
      entry = create(:catalog_entry, identity:, name:, retired_at: (1.day.ago if retired))
      create(:mtg_printing, entry:, faces: faces.map { { "name" => it } })
      identity
    end

    def top(text, limit: 3) = index.search(text, limit:).map { Catalog::Identity.find(it.identity_id).name }

    before do
      [ "Lightning Bolt", "Lightning Helix", "Aether Vial", "Ox", "Cosmic Hunger", "_____" ].each { card(it) }
      card("Fire // Ice", faces: %w[Fire Ice])
      card("Retired Card", retired: true)
      index.rebuild
    end

    it "indexes each searchable card's name and the face names of multi-face cards, idempotently", :aggregate_failures do
      expect(index.rebuild).to eq(9)
      expect(Catalog::Name.where(collectible_type: "mtg").count).to eq(9)
      expect(index).to be_populated
      expect(described_class.new("other", source_class: FakeCatalogSource)).not_to be_populated
    end

    it "finds a card by its exact name, a misread name or a ligature", :aggregate_failures do
      expect(top("Lightning Bolt").first).to eq("Lightning Bolt")
      expect(top("Lightnlng Bo1t").first).to eq("Lightning Bolt")
      expect(top("Æther Vial").first).to eq("Aether Vial")
    end

    it "maps a face name to its card, once per card", :aggregate_failures do
      expect(top("Fire").first).to eq("Fire // Ice")
      expect(index.search("Fire").map(&:identity_id).tally.values).to all(eq(1))
    end

    it "takes the longest mostly-alphabetic line once short tokens are dropped (AC-3.4)" do
      expect(top("A) ae ea i Rd TE NC DORA AA Sa pr\nCosmic Hunger")).to include("Cosmic Hunger")
    end

    it "matches short queries within one edit (AC-3.5)", :aggregate_failures do
      expect(top("0x")).to include("Ox")
      expect(top("Ixe")).to include("Fire // Ice")
    end

    it "matches text that normalises to nothing exactly (AC-3.5)" do
      expect(top("_____")).to eq([ "_____" ])
    end

    it "leaves out retired printings, returns at most the limit, and nothing for noise", :aggregate_failures do
      expect(top("Retired Card")).to be_empty
      expect(top("Lightning", limit: 1)).to eq([ "Lightning Bolt" ])
      expect(index.search(" -- ")).to eq([])
    end

    describe ".clean" do
      it "keeps a short name when nothing longer survives", :aggregate_failures do
        expect(described_class.clean("Ox")).to eq("Ox")
        expect(described_class.clean("A) ae ea i Rd TE NC DORA AA Sa pr\nCosmic Hunger")).to eq("Cosmic Hunger")
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/name_index_spec.rb`. Expect: FAIL (`uninitialized constant Catalog::NameIndex`).
- [ ] Write the migration `db/migrate/20260930170000_create_catalog_names.rb`:

  ```ruby
  # The scanner's card-name index (spec 007 FR-5, ADR 0003): every name a catalog identity is known by,
  # normalised, with an FTS5 trigram index over the normalised name. Global, derived catalog data, filled
  # by Catalog::Refresh; this migration only creates the tables, so it's safe on any prior version.
  class CreateCatalogNames < ActiveRecord::Migration[8.1]
    FTS_OPTIONS = [ "normalized", "content='catalog_names'", "content_rowid='id'", "tokenize='trigram remove_diacritics 1'" ].freeze

    def up
      create_table :catalog_names do |t|
        t.string :collectible_type, null: false
        t.references :catalog_identity, null: false, foreign_key: true
        t.string :name, null: false
        t.string :normalized, null: false
        t.index %i[collectible_type catalog_identity_id normalized], unique: true, name: "index_catalog_names_uniqueness"
        t.index %i[collectible_type normalized]
      end
      create_virtual_table :catalog_names_fts, :fts5, FTS_OPTIONS
    end

    def down
      drop_virtual_table :catalog_names_fts, :fts5, FTS_OPTIONS
      drop_table :catalog_names
    end
  end
  ```
- [ ] Run: `bin/rails db:migrate && bin/rails db:rollback && bin/rails db:migrate`. Expect: all three succeed. `db/schema.rb` gains `create_table "catalog_names"` and `create_virtual_table "catalog_names_fts", "fts5", ["normalized", "content='catalog_names'", "content_rowid='id'", "tokenize='trigram remove_diacritics 1'"]`. Check the line with `grep -n catalog_names_fts db/schema.rb`.
- [ ] Implement `app/models/catalog/name.rb`:

  ```ruby
  # One name a catalog identity is known by (its full name, or a face name), normalised for the scanner's
  # name index (spec 007 FR-5). Derived data: Catalog::NameIndex#rebuild replaces a type's rows in full.
  class Catalog::Name < ApplicationRecord
    belongs_to :identity, class_name: "Catalog::Identity", foreign_key: :catalog_identity_id
  end
  ```
- [ ] Implement `app/models/catalog/name_index.rb`:

  ```ruby
  require "did_you_mean"

  # Finds catalog identities from text read off a card's name bar (spec 007 AC-3.4, AC-3.5, ADR 0003). The
  # text is cleaned and normalised like the names, matched by OR-ing its trigrams in an FTS5 index,
  # shortlisted by bm25 and re-ranked by Jaro-Winkler, one candidate per identity. Short queries also
  # match names within one edit; text that normalises to nothing is matched exactly against the raw name.
  class Catalog::NameIndex
    Candidate = Data.define(:identity_id, :name, :score)
    SHORTLIST = 50
    SHORT_QUERY = 5
    MIN_TOKEN = 3
    BATCH_SIZE = 1_000

    # The longest line in which at least half the non-space characters are letters, once tokens shorter
    # than MIN_TOKEN are dropped from every line; if no such line is left, the longest such line as read,
    # so a short name like "Ox" is still a query (AC-3.4).
    def self.clean(text)
      lines = text.to_s.lines.map(&:strip)
      trimmed = lines.map { |line| line.split.select { |token| token.length >= MIN_TOKEN }.join(" ") }
      longest_alphabetic(trimmed) || longest_alphabetic(lines) || ""
    end

    def self.longest_alphabetic(lines) = lines.select { |line| alphabetic?(line) }.max_by(&:length)

    def self.alphabetic?(line)
      characters = line.gsub(/\s/, "")
      characters.present? && characters.scan(/\p{L}/).size * 2 >= characters.size
    end

    def initialize(collectible_type, source_class: Catalog.source_class(collectible_type))
      @collectible_type = collectible_type
      @source_class = source_class
    end

    def populated? = names.exists?

    # Replaces this type's names in one transaction and returns how many were written. Bulk maintenance
    # of derived, global catalog rows: no callbacks or validations apply.
    def rebuild
      rows = (identity_names + alternate_names).uniq { |identity_id, name| [ identity_id, Catalog::NameKey.call(name) ] }
      Catalog::Name.transaction do
        names.delete_all
        rows.each_slice(BATCH_SIZE) do |slice|
          Catalog::Name.insert_all(slice.map { |identity_id, name| { collectible_type: @collectible_type,
            catalog_identity_id: identity_id, name:, normalized: Catalog::NameKey.call(name) } })
        end
        Catalog::Name.connection.execute("INSERT INTO catalog_names_fts (catalog_names_fts) VALUES ('rebuild')")
      end
      rows.size
    end

    def search(text, limit: 3)
      key = Catalog::NameKey.call(self.class.clean(text))
      rows = if key.empty? then exact(text.to_s.strip)
      else (key.length >= 3 ? trigram(key) : []) + (key.length <= SHORT_QUERY ? near(key) : [])
      end
      rank(key, rows).first(limit)
    end

    private
      def names = Catalog::Name.where(collectible_type: @collectible_type)

      def searchable = Catalog::Entry.searchable.where(collectible_type: @collectible_type)

      def identity_names
        Catalog::Identity.where(collectible_type: @collectible_type, id: searchable.select(:catalog_identity_id)).pluck(:id, :name)
      end

      def alternate_names = @source_class.respond_to?(:alternate_names) ? @source_class.alternate_names(searchable).to_a : []

      def trigram(key)
        terms = (0..key.length - 3).map { |start| %("#{key[start, 3]}") }.uniq.join(" OR ")
        names.joins("JOIN catalog_names_fts ON catalog_names_fts.rowid = catalog_names.id")
          .where("catalog_names_fts MATCH ?", terms).order(Arel.sql("bm25(catalog_names_fts)")).limit(SHORTLIST)
          .pluck(:catalog_identity_id, :name, :normalized)
      end

      def near(key)
        names.where("length(normalized) BETWEEN ? AND ?", key.length - 1, key.length + 1)
          .pluck(:catalog_identity_id, :name, :normalized)
          .select { |_, _, normalized| DidYouMean::Levenshtein.distance(key, normalized) <= 1 }
      end

      def exact(raw) = raw.empty? ? [] : names.where(name: raw).pluck(:catalog_identity_id, :name, :normalized)

      def rank(key, rows)
        rows.group_by(&:first).map do |identity_id, matches|
          name, score = matches.map { |_, matched, normalized| [ matched, similarity(key, normalized) ] }.max_by(&:last)
          Candidate.new(identity_id:, name:, score: score.round(4))
        end.sort_by { |candidate| [ -candidate.score, candidate.name ] }
      end

      def similarity(key, normalized) = key.empty? ? 1.0 : DidYouMean::JaroWinkler.distance(key, normalized)
  end
  ```
- [ ] Add MTG's face names. In `app/models/mtg/printing.rb`, add inside the class:

  ```ruby
    # [identity id, face name] for each face of a multi-face printing among entries (split, adventure and
    # double-faced cards), whose name bar prints a face name rather than "Front // Back" (spec 007 FR-5).
    def self.face_names(entries)
      joins(:entry).merge(entries).where("json_array_length(mtg_printings.faces) > 1")
        .joins("JOIN json_each(mtg_printings.faces) AS face")
        .distinct.pluck("catalog_entries.catalog_identity_id", Arel.sql("json_extract(face.value, '$.name')"))
    end
  ```

  In `app/models/mtg/scryfall/source.rb`, after `def self.identity_extension_model = MTG::Card`, add:

  ```ruby
  def self.alternate_names(entries) = MTG::Printing.face_names(entries)
  ```

  In the contract comment in `app/models/catalog/sources.rb`, add this line after the `.identity_extension_model` line:

  ```ruby
  #   .alternate_names(entries)           optional: [[identity id, name], …] the name index adds to identity names
  ```
- [ ] Run: `bin/rspec spec/models/catalog/name_index_spec.rb`. Expect: 8 examples, 0 failures.
- [ ] Commit: `feat(catalog): add the card-name index with trigram search and short-name fallbacks`
- [ ] Add to `spec/models/catalog/refresh_spec.rb`, inside the top-level `describe`:

  ```ruby
    describe "the name index (spec 007 AC-3.9)" do
      def names(text) = Catalog::NameIndex.new("fake", source_class: FakeCatalogSource).search(text).map(&:name)

      it "indexes the cards of an applied refresh, including one added later", :aggregate_failures do
        refresh
        expect(names("Lightning Bolt")).to eq([ "Lightning Bolt" ])
        source.entries += [ entry_record("c", identity: identity_record("helix", name: "Lightning Helix")) ]
        refresh
        expect(names("Lightning Helix")).to include("Lightning Helix")
      end

      it "rebuilds an empty index when a scheduled run is skipped", :aggregate_failures do
        refresh(trigger: "scheduled")
        Catalog::Name.delete_all
        expect(refresh(trigger: "scheduled")).to have_attributes(status: "skipped", message: "v1 already applied; name index rebuilt with 1 name")
        expect(names("Lightning Bolt")).to eq([ "Lightning Bolt" ])
      end

      it "leaves a populated index alone when a scheduled run is skipped" do
        refresh(trigger: "scheduled")
        expect { refresh(trigger: "scheduled") }.not_to(change { Catalog::Name.pluck(:id) })
      end
    end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/refresh_spec.rb`. Expect: the 3 new examples FAIL and the existing ones pass.
- [ ] In `app/models/catalog/refresh.rb`, rebuild before finishing an applied run, and rebuild in `skip` when the index is empty:

  ```ruby
      retire_unseen
      name_index.rebuild
      @run.finish!(:applied, counts: @counts)
  ```

  ```ruby
      def skip(version)
        rebuilt = name_index.rebuild unless name_index.populated?
        note = "; name index rebuilt with #{rebuilt} #{"name".pluralize(rebuilt)}" if rebuilt
        @run.finish!(:skipped, message: "#{version} already applied#{note}")
        @run
      end

      def name_index = @name_index ||= Catalog::NameIndex.new(@collectible_type, source_class: @source.class)
  ```
- [ ] Run: `bin/rspec spec/models/catalog`. Expect: 0 failures.
- [ ] Commit: `feat(catalog): rebuild the name index after each applied refresh and when it's empty`

---

## Phase 3: Printing lookup and the reading

**Implements:** FR-4 (lookup, ranking) | **Satisfies:** AC-3.1 (data), AC-3.2, AC-3.3, AC-3.8 (data)
**Files:** `app/models/catalog/entry.rb`, `app/models/mtg/reading.rb`, `spec/models/catalog/entry_spec.rb`, `spec/models/mtg/reading_spec.rb`
**Interfaces:** Consumes: `MTG::CollectorLine.parse`, `Catalog::NameIndex#search/#populated?`. Produces:
- `Catalog::Entry.printed_as(set_code:, number:, language:)` (scope).
- `MTG::Reading.new(name_text:, collector_text:)`, with:
  - `#valid?`, `#resolve → self`, `#catalog_ready?`, `#nothing_read?`, `#collector_line`;
  - `#collector_status` → `:one`, `:none`, `:several` or `:unread`, and `#collector_entries`;
  - `#name_candidates → [Catalog::NameIndex::Candidate]`;
  - `#candidates → [MTG::Reading::Candidate(entry, source)]`, where `source` is `:collector_line` or `:name`;
  - `MTG::Reading::MAX_TEXT_LENGTH` (2,000).

One scan's text becomes the parsed line, the lookup outcome, the name candidates (Phase 0's ranking, kept for the findings) and the final ranking the page shows. When no language is read, English is used.

- [ ] Add to `spec/models/catalog/entry_spec.rb`:

  ```ruby
    describe ".printed_as" do
      it "finds active printings by set code, number and language", :aggregate_failures do
        set = create(:catalog_set, code: "mom")
        match = create(:catalog_entry, set:, number: "123")
        create(:catalog_entry, set:, number: "123", language: "ja")
        create(:catalog_entry, :retired, set:, number: "123")
        expect(described_class.printed_as(set_code: "MOM", number: "123", language: "en")).to eq([ match ])
        expect(described_class.printed_as(set_code: "mom", number: "124", language: "en")).to be_empty
      end
    end
  ```
- [ ] Write `spec/models/mtg/reading_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe MTG::Reading, type: :model do
    let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine", released_on: Date.new(2023, 4, 21)) }
    let!(:bolt) { printing("Lightning Bolt", set: mom, number: "123") }

    before do
      printing("Lightning Helix", set: mom, number: "200")
      Catalog::NameIndex.new("mtg").rebuild
    end

    def printing(name, set:, number:, language: "en")
      identity = Catalog::Identity.find_by(name:) || create(:catalog_identity, name:)
      create(:mtg_printing, entry: create(:catalog_entry, identity:, name:, set:, number:, language:)).entry
    end

    def read(name_text: "", collector_text: "") = described_class.new(name_text:, collector_text:).resolve

    it "puts the printing the collector line identifies first, once (AC-3.2)", :aggregate_failures do
      reading = read(name_text: "Lightning Bolt", collector_text: "R 0123\nMOM • EN")
      expect(reading.collector_status).to eq(:one)
      expect(reading.candidates.first).to have_attributes(entry: bolt, source: :collector_line)
      expect(reading.candidates.count { it.entry.catalog_identity_id == bolt.catalog_identity_id }).to eq(1)
    end

    it "uses English when the collector line names no language" do
      expect(read(collector_text: "M0123\nMOM").collector_status).to eq(:one)
    end

    it "reports several printings and falls back to the name (AC-3.3)", :aggregate_failures do
      printing("Lightning Bolt", set: mom, number: "123")
      reading = read(name_text: "Lightning Bolt", collector_text: "R 0123\nMOM • EN")
      expect(reading.collector_status).to eq(:several)
      expect(reading.candidates.map(&:source)).to all(eq(:name))
    end

    it "reports no printing, or a line it couldn't read", :aggregate_failures do
      expect(read(collector_text: "R 0999\nMOM • EN").collector_status).to eq(:none)
      expect(read(collector_text: "").collector_status).to eq(:unread)
    end

    it "shows a name candidate's printing in the parsed set, else its newest English printing", :aggregate_failures do
      newer = printing("Lightning Bolt", set: create(:catalog_set, code: "m25", released_on: Date.new(2025, 1, 1)), number: "1")
      expect(read(name_text: "Lightning Bolt", collector_text: "R 0999\nMOM • EN").candidates.first.entry).to eq(bolt)
      expect(read(name_text: "Lightning Bolt").candidates.first.entry).to eq(newer)
    end

    it "keeps the name candidates independent of the collector line (AC-6.2)", :aggregate_failures do
      reading = read(name_text: "Lightning Helix", collector_text: "R 0123\nMOM • EN")
      expect(Catalog::Identity.find(reading.name_candidates.first.identity_id).name).to eq("Lightning Helix")
      expect(reading.candidates.first.entry).to eq(bolt)
    end

    it "lists at most three candidates" do
      %w[Lightning\ Axe Lightning\ Storm Lightning\ Strike].each_with_index { |name, i| printing(name, set: mom, number: (300 + i).to_s) }
      Catalog::NameIndex.new("mtg").rebuild
      expect(read(name_text: "Lightning").candidates.size).to eq(3)
    end

    it "knows when nothing was read, when the catalog isn't ready, and when text is too long", :aggregate_failures do
      expect(read).to be_nothing_read
      Catalog::Name.delete_all
      expect(read(name_text: "Lightning Bolt")).not_to be_catalog_ready
      expect(described_class.new(name_text: "a" * 2_001)).not_to be_valid
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/entry_spec.rb spec/models/mtg/reading_spec.rb`. Expect: FAIL (`printed_as` undefined; `uninitialized constant MTG::Reading`).
- [ ] In `app/models/catalog/entry.rb`, add after `scope :in_set`:

  ```ruby
    # Active printings with this set code, collector number and language (spec 007 FR-4).
    scope :printed_as, ->(set_code:, number:, language:) {
      active.joins(:set).where(number:, language:, catalog_sets: { code: set_code.to_s.downcase })
    }
  ```
- [ ] Implement `app/models/mtg/reading.rb`:

  ```ruby
  # What the scanner read from one card, and the printings it points to (spec 007 Story 3): the parsed
  # collector line and its printing lookup (one, none or several), the name index's candidates from the
  # name strip alone (Phase 0's ranking, kept for the findings), and the final ranking the page shows,
  # with a collector-line match first. Only text arrives here; the photo stays on the device (FR-3).
  class MTG::Reading
    include ActiveModel::Model
    include ActiveModel::Attributes

    COLLECTIBLE_TYPE = "mtg"
    CANDIDATES = 3
    MAX_TEXT_LENGTH = 2_000

    Candidate = Data.define(:entry, :source)

    attribute :name_text, :string, default: ""
    attribute :collector_text, :string, default: ""

    validates :name_text, :collector_text, length: { maximum: MAX_TEXT_LENGTH }

    # Runs every query once, so the view only reads memoised results.
    def resolve
      catalog_ready? && candidates
      self
    end

    def catalog_ready? = @catalog_ready.nil? ? (@catalog_ready = name_index.populated?) : @catalog_ready

    def nothing_read? = name_text.blank? && collector_text.blank?

    def collector_line
      @collector_line ||= MTG::CollectorLine.parse(collector_text,
        known_set_codes: Catalog::Set.where(collectible_type: COLLECTIBLE_TYPE).pluck(:code))
    end

    def collector_status = collector_match.first

    def collector_entries = collector_match.last

    def name_candidates = @name_candidates ||= name_index.search(name_text, limit: CANDIDATES)

    def candidates
      @candidates ||= begin
        matched = collector_status == :one ? [ Candidate.new(entry: collector_entries.first, source: :collector_line) ] : []
        named = name_printings.reject { |entry| matched.any? { it.entry.catalog_identity_id == entry.catalog_identity_id } }
        (matched + named.map { Candidate.new(entry: it, source: :name) }).first(CANDIDATES)
      end
    end

    private
      def name_index = @name_index ||= Catalog::NameIndex.new(COLLECTIBLE_TYPE)

      # [:one | :none | :several | :unread, entries] (AC-3.2, AC-3.3); English when no language was read.
      def collector_match
        @collector_match ||= if collector_line.set_code.blank? || collector_line.number.blank? then [ :unread, [] ]
        else
          entries = Catalog::Entry.where(collectible_type: COLLECTIBLE_TYPE).includes(:set)
            .printed_as(set_code: collector_line.set_code, number: collector_line.number, language: collector_line.language || "en").to_a
          [ { 0 => :none, 1 => :one }.fetch(entries.size, :several), entries ]
        end
      end

      # One printing per name candidate, in candidate order: in the parsed set when the card has one
      # there, otherwise its newest English printing.
      def name_printings
        ids = name_candidates.map(&:identity_id)
        printings = Catalog::Entry.searchable.where(collectible_type: COLLECTIBLE_TYPE, catalog_identity_id: ids, language: "en")
          .newest_first.includes(:set).to_a.group_by(&:catalog_identity_id)
        ids.filter_map do |id|
          options = printings.fetch(id, [])
          options.find { it.set.code.casecmp?(collector_line.set_code.to_s) } || options.first
        end
      end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/entry_spec.rb spec/models/mtg/reading_spec.rb`. Expect: 0 failures.
- [ ] Commit: `feat(mtg): turn a scan's text into the collector-line match and ranked candidates`

---
## Phase 4: The self-hosted OCR engine

**Implements:** FR-3 (engine from own origin) | **Satisfies:** AC-2.2, AC-7.3
**Files:** `lib/collector/ocr_engine.rb`, `bin/fetch-ocr-engine`, `bin/setup`, `Dockerfile`, `.gitignore`, `app/controllers/ocr_assets_controller.rb`, `config/routes.rb`, `spec/lib/collector/ocr_engine_spec.rb`, `spec/requests/ocr_assets_spec.rb`, `spec/routing/routes_spec.rb`
**Interfaces:** Consumes: nothing. Produces:
- `Collector::OcrEngine::VERSION` (`"v7.0.0"`), `::ROOT`, `::FILES` (served path → SHA-256) and `::PUBLISHED_AT`.
- `.path_for(relative) → String | nil` and `.content_type(path) → String`.
- `.install!(root:, packages:, files:, download:) → [served paths written]`.
- `ocr_asset_path(version:, path:)`, serving `/ocr/v7.0.0/<path>`.

The engine arrives the way gems do: pinned, checked and fetched at setup or build, never committed. The app serves it with an immutable cache policy and answers conditional requests itself.

- [ ] Write `spec/lib/collector/ocr_engine_spec.rb`:

  ```ruby
  require "rails_helper"
  require "rubygems/package"

  RSpec.describe Collector::OcrEngine do
    describe "the installed engine (AC-7.3)" do
      it "matches every pinned checksum (run bin/fetch-ocr-engine if not)", :aggregate_failures do
        described_class::FILES.each do |relative, digest|
          path = File.join(described_class::ROOT, relative)
          expect(File.file?(path) && Digest::SHA256.file(path).hexdigest).to eq(digest), relative
        end
      end
    end

    describe ".install!" do
      let(:root) { Dir.mktmpdir }
      let(:contents) { "console.log('engine')" }
      let(:tarball) { tar("package/dist/engine.js" => contents) }
      let(:package) do
        described_class::Package.new(url: "https://registry.test/engine.tgz", sha256: Digest::SHA256.hexdigest(tarball),
          files: { "package/dist/engine.js" => "engine.js" })
      end
      let(:files) { { "engine.js" => Digest::SHA256.hexdigest(contents) } }
      let(:downloads) { [] }

      after { FileUtils.remove_entry(root) }

      def install = described_class.install!(root:, packages: [ package ], files:, download: ->(url) { downloads << url && tarball })

      def tar(entries)
        io = StringIO.new
        Zlib::GzipWriter.wrap(io) do |gzip|
          Gem::Package::TarWriter.new(gzip) do |writer|
            entries.each { |name, data| writer.add_file_simple(name, 0o644, data.bytesize) { it.write(data) } }
          end
        end
        io.string
      end

      it "unpacks the pinned files", :aggregate_failures do
        expect(install).to eq([ "engine.js" ])
        expect(File.read(File.join(root, "engine.js"))).to eq(contents)
      end

      it "downloads nothing when every file is intact" do
        install
        expect { install }.not_to(change { downloads.size })
      end

      it "rejects a tarball whose checksum differs" do
        package.sha256 = "0" * 64
        expect { install }.to raise_error(described_class::IntegrityError, /engine\.tgz/)
      end

      it "rejects a file whose checksum differs, writing nothing", :aggregate_failures do
        files["engine.js"] = "0" * 64
        expect { install }.to raise_error(described_class::IntegrityError, /engine\.js/)
        expect(File.exist?(File.join(root, "engine.js"))).to be(false)
      end
    end

    describe ".path_for" do
      it "knows only the pinned files", :aggregate_failures do
        expect(described_class.path_for("core/tesseract-core-simd-lstm.wasm.js")).to end_with("vendor/ocr/v7.0.0/core/tesseract-core-simd-lstm.wasm.js")
        expect(described_class.path_for("core/tesseract-core.wasm.js")).to be_nil
        expect(described_class.path_for("../../config/master.key")).to be_nil
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/lib/collector/ocr_engine_spec.rb`. Expect: FAIL (`uninitialized constant Collector::OcrEngine`).
- [ ] Implement `lib/collector/ocr_engine.rb`:

  ```ruby
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
  ```

  `install!` checks every file in a package before writing any of them: the `each` does all the checks first, then `map` writes. So a damaged file leaves nothing behind.
- [ ] Run: `bin/rspec spec/lib/collector/ocr_engine_spec.rb -e ".install!" -e ".path_for"`. Expect: 5 examples, 0 failures. The checksum example still fails, because nothing is installed yet.
- [ ] Add `bin/fetch-ocr-engine` and make it executable (`chmod +x bin/fetch-ocr-engine`):

  ```ruby
  #!/usr/bin/env ruby
  # Installs the pinned OCR engine into vendor/ocr/ (spec 007 AC-7.3, ADR 0001). Idempotent: files already
  # present with the right checksum aren't downloaded again. Needs network access to registry.npmjs.org.
  require_relative "../lib/collector/ocr_engine"

  engine = Collector::OcrEngine
  written = engine.install!
  puts(written.empty? ? "OCR engine #{engine::VERSION} already installed" : "Installed OCR engine #{engine::VERSION}: #{written.join(", ")}")
  ```

  In `bin/setup`, after the `bundle install` line:

  ```ruby
      puts "\n== Installing the OCR engine =="
      system! "bin/fetch-ocr-engine"
  ```

  In `Dockerfile`, after `COPY . .` in the build stage:

  ```dockerfile
  # Fetch and verify the pinned OCR engine for the card scanner (spec 007, ADR 0001).
  RUN bin/fetch-ocr-engine
  ```

  In `.gitignore`, add:

  ```
  # The OCR engine, fetched and verified by bin/fetch-ocr-engine (spec 007).
  /vendor/ocr/
  ```
- [ ] Run: `bin/fetch-ocr-engine && bin/fetch-ocr-engine && bin/rspec spec/lib/collector/ocr_engine_spec.rb`. Expect: the first run prints `Installed OCR engine v7.0.0: …` with 6 paths, the second prints `already installed`, then 6 examples, 0 failures. `git status --short` shows nothing under `vendor/`.
- [ ] Commit: `build: fetch and verify the pinned OCR engine in setup and the image build`
- [ ] Write `spec/requests/ocr_assets_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe "OCR engine files", type: :request do
    let(:path) { "/ocr/v7.0.0/core/tesseract-core-simd-lstm.wasm.js" }

    it "serves a pinned file from the app, cacheable as immutable for a year (AC-2.2)", :aggregate_failures do
      get path
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/javascript")
      expect(response.headers["Cache-Control"]).to include("max-age=31536000", "public", "immutable")
      expect(response.body.bytesize).to eq(3_899_472)
    end

    it "answers either conditional request with 304 and no body (AC-2.2)", :aggregate_failures do
      get path
      { "If-None-Match" => response.headers["ETag"], "If-Modified-Since" => response.headers["Last-Modified"] }.each do |header, value|
        get path, headers: { header => value }
        expect(response).to have_http_status(:not_modified)
        expect(response.body).to be_empty
      end
    end

    it "serves the language data as gzip" do
      get "/ocr/v7.0.0/lang/eng.traineddata.gz"
      expect(response.media_type).to eq("application/gzip")
    end

    it "serves nothing outside the pinned files and version", :aggregate_failures do
      [ "/ocr/v7.0.0/core/tesseract-core.wasm.js", "/ocr/v6.0.0/tesseract.min.js", "/ocr/v7.0.0/%2E%2E/%2E%2E/config/master.key" ].each do |other|
        get other
        expect(response).to have_http_status(:not_found)
      end
    end
  end
  ```

  Add to `spec/routing/routes_spec.rb`:

  ```ruby
    it "routes the OCR engine's files by version and path" do
      expect(get: "/ocr/v7.0.0/core/tesseract-core-lstm.wasm.js")
        .to route_to("ocr_assets#show", version: "v7.0.0", path: "core/tesseract-core-lstm.wasm.js")
    end
  ```
- [ ] Run: `bin/rspec spec/requests/ocr_assets_spec.rb spec/routing/routes_spec.rb`. Expect: FAIL (no route).
- [ ] Add the route to `config/routes.rb`, before `namespace :admin`:

  ```ruby
    # The self-hosted OCR engine for the card scanner (spec 007, ADR 0001).
    get "ocr/:version/*path", to: "ocr_assets#show", as: :ocr_asset, format: false, constraints: { version: /v\d+\.\d+\.\d+/ }
  ```

  Implement `app/controllers/ocr_assets_controller.rb`:

  ```ruby
  # Serves the self-hosted OCR engine (spec 007 AC-2.2, ADR 0001): only the pinned files, from a path that
  # carries the version, cacheable as immutable for a year; If-None-Match or If-Modified-Since gets 304.
  # The engine is a public library, so no sign-in is needed.
  class OcrAssetsController < ApplicationController
    allow_unauthenticated_access
    allow_before_first_user

    def show
      engine = Collector::OcrEngine
      path = engine.path_for(params[:path]) if params[:version] == engine::VERSION
      return head(:not_found) unless path && File.file?(path)

      expires_in 1.year, public: true, immutable: true
      return unless stale?(etag: engine::FILES.fetch(params[:path]), last_modified: engine::PUBLISHED_AT, public: true)

      send_file path, type: engine.content_type(path), disposition: :inline
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/ocr_assets_spec.rb spec/routing/routes_spec.rb`. Expect: 0 failures.
- [ ] Run: `bin/brakeman --quiet --no-pager --exit-on-warn`. Expect: no warnings, or one File Access warning on `send_file`. If it's flagged, the path comes from the `FILES` allowlist (`path_for` returns nil for anything else), never from the request: run `bin/brakeman -I` to add it to `config/brakeman.ignore` (new file) with that justification as its note, and record a `Ruling:` in the commit.
- [ ] Commit: `feat(scanner): serve the pinned OCR engine with immutable caching`

---

## Phase 5: Scanner page and readings, server side

**Implements:** FR-1, FR-3, FR-4 (presentation) | **Satisfies:** AC-1.2, AC-1.7, AC-2.3, AC-2.4, AC-2.5 (markup), AC-3.1, AC-3.2, AC-3.3, AC-3.8, AC-3.10
**Files:** `config/routes.rb`, `config/initializers/content_security_policy.rb`, `app/controllers/concerns/scanner_page.rb`, `app/controllers/scanners_controller.rb`, `app/controllers/scanner/readings_controller.rb`, `app/helpers/scanners_helper.rb`, `app/views/scanners/{show,_head,_scanner,_result,_candidate}.html.erb`, `spec/requests/scanners_spec.rb`, `spec/requests/scanner/readings_spec.rb`, `spec/routing/routes_spec.rb`
**Interfaces:** Consumes: `MTG::Reading`, `Collector::OcrEngine::VERSION`, `ocr_asset_path`. Produces:
- `scanner_path` (`GET /scanner`) and `scanner_readings_path` (`POST /scanner/readings`, params `reading[name_text]` and `reading[collector_text]`; answers `turbo-stream update scanner_result`).
- The `ScannerPage` concern, carrying the policy.
- The partial `scanners/_scanner`, with these DOM hooks for Phase 6:
  - `.c-scanner[data-controller="card-reader camera"]`, carrying `data-card-reader-readings-url-value` and `data-card-reader-engine-path-value`;
  - targets `status`, `shutter`, `picker`, `result`, `unavailable`, `reason`, `retry`, `failure`, `failureMessage`, `failureName`, `failureCollector`, `signIn`, `resend` and `engineRetry` (card-reader), and `stage`, `video`, `guide` and `torch` (camera);
  - `#scanner_result`.

The page and its policy, and the endpoint that turns text into the result HTML. The page renders a disabled, busy shutter; Phase 6 brings it to life.

- [ ] Write `spec/requests/scanners_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe "Scanner page", type: :request do
    let(:user) { create(:user, admin: true) }

    def csp = response.headers["Content-Security-Policy"].to_s.split(";").map(&:split).to_h { |name, *values| [ name, values ] }

    it "sends a signed-out visitor to sign in (AC-1.2)" do
      create(:user)
      get scanner_path
      expect(response).to redirect_to(new_session_path)
    end

    describe "when signed in" do
      before { sign_in_as(user) }

      it "loads the engine from this app's versioned path, with the shutter busy until it's ready (AC-2.2, AC-2.5)", :aggregate_failures do
        get scanner_path
        expect(response.body).to include('src="/ocr/v7.0.0/tesseract.min.js"', 'data-card-reader-engine-path-value="/ocr/v7.0.0"')
        expect(response.body).to match(/<button[^>]*c-scanner__shutter[^>]*disabled[^>]*aria-busy="true"/)
        expect(response.body).to include('<meta name="turbo-visit-control" content="reload">', '<meta name="turbo-cache-control" content="no-cache">')
      end

      it "sends a strict policy with a fresh nonce for its own inline tags (AC-2.4)", :aggregate_failures do
        get scanner_path
        expect(csp["script-src"]).to match([ "'self'", "'wasm-unsafe-eval'", a_string_matching(/\A'nonce-[^']+'\z/) ])
        expect(csp.values_at("worker-src", "connect-src", "frame-src")).to eq([ [ "'self'", "blob:" ], [ "'self'" ], [ "'none'" ] ])
        nonce = csp["script-src"].last[/'nonce-(.+)'/, 1]
        expect(response.body).to include(%(nonce="#{nonce}"))
        get scanner_path
        expect(csp["script-src"].last).not_to eq("'nonce-#{nonce}'")
      end

      it "keeps the policy off every other page and the engine with it (AC-2.3)", :aggregate_failures do
        [ collection_path, catalog_entries_path(q: "bolt"), more_path ].each do |path|
          get path
          expect(response.headers["Content-Security-Policy"]).to be_nil
          expect(response.body).not_to include("/ocr/", "nonce=")
        end
      end

      it "isn't linked from any page (AC-1.7)" do
        entry = create(:mtg_printing).entry
        pages = [ collection_path, catalog_entries_path(q: entry.name), catalog_entry_path(entry), more_path, admin_users_path ]
        expect(pages.map { get(it) && response.body }).to all(satisfy { !it.include?(%(href="#{scanner_path}")) })
      end
    end
  end
  ```
- [ ] Write `spec/requests/scanner/readings_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe "Scanner readings", type: :request do
    let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine") }
    let!(:bolt) do
      identity = create(:catalog_identity, name: "Lightning Bolt")
      create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
    end

    before { sign_in_as(create(:user)) }

    def read(name_text, collector_text)
      post scanner_readings_path, params: { reading: { name_text:, collector_text: } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    context "when the name index is built" do
      before { Catalog::NameIndex.new("mtg").rebuild }

      it "shows what was read and the candidates, the collector-line match first (AC-3.1, AC-3.2)", :aggregate_failures do
        read("Lightnlng Bo1t", "R 0123\nMOM • EN")
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('<turbo-stream action="update" target="scanner_result">', "Lightnlng Bo1t", "R 0123")
        expect(response.body).to include("Matched one printing", "Matched by its collector line", "MOM · 123", "March of the Machine")
      end

      it "says when the collector line matches several printings or none (AC-3.3)", :aggregate_failures do
        create(:mtg_printing, entry: create(:catalog_entry, identity: bolt.identity, name: "Lightning Bolt", set: mom, number: "123"))
        read("Lightning Bolt", "R 0123\nMOM • EN")
        expect(response.body).to include("Several printings").and include("Lightning Bolt")
        read("Lightning Bolt", "R 0999\nMOM • EN")
        expect(response.body).to include("No printing")
      end

      it "offers no way to add a card, and links to the catalog search (AC-3.10)", :aggregate_failures do
        read("Lightning Bolt", "")
        expect(response.body).not_to include("quick_add", "Add 1 ×")
        expect(response.body).to include("Adding cards from the scanner is coming", %(href="#{catalog_entries_path(q: "Lightning Bolt")}"))
      end

      it "says when nothing could be read" do
        read("", "")
        expect(response.body).to include("Nothing could be read")
      end

      it "turns away text over 2,000 characters", :aggregate_failures do
        read("a" * 2_001, "")
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("That reading was too long to use")
      end
    end

    it "says the catalog isn't ready while the name index is empty (AC-3.8)" do
      read("Lightning Bolt", "")
      expect(response.body).to include("The card catalog isn't ready yet")
    end

    it "sends an expired session to sign in" do
      delete session_path
      read("Lightning Bolt", "")
      expect(response).to redirect_to(new_session_path)
    end
  end
  ```

  Add to `spec/routing/routes_spec.rb`:

  ```ruby
    it "routes the scanner and its readings", :aggregate_failures do
      expect(get: "/scanner").to route_to("scanners#show")
      expect(post: "/scanner/readings").to route_to("scanner/readings#create")
    end
  ```
- [ ] Run: `bin/rspec spec/requests/scanners_spec.rb spec/requests/scanner/readings_spec.rb spec/routing/routes_spec.rb`. Expect: FAIL (no routes).
- [ ] Add the routes to `config/routes.rb`, after `resource :more, only: :show`:

  ```ruby
    # The card scanner (spec 007): reachable by URL only until adding from the scanner ships.
    resource :scanner, only: :show
    namespace :scanner do
      resources :readings, only: :create
    end
  ```

  Replace the commented body of `config/initializers/content_security_policy.rb` with:

  ```ruby
  # Be sure to restart your server when you modify this file.

  # No app-wide policy: only the card scanner's pages send one (spec 007 AC-2.3, AC-2.4), from
  # app/controllers/concerns/scanner_page.rb. A nonce is made only for a request that has a policy, so the
  # import map tags of other pages carry none and Turbo Drive keeps working between them.
  Rails.application.configure do
    config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) if request.content_security_policy }
    config.content_security_policy_nonce_directives = %w[script-src]
  end
  ```

  Implement `app/controllers/concerns/scanner_page.rb`:

  ```ruby
  # The card scanner's Content Security Policy (spec 007 AC-2.4, ADR 0001), for every page that loads the OCR
  # engine: scripts, workers and connections only from this origin, plus blob: for the engine's worker,
  # 'wasm-unsafe-eval' to compile it and a per-request nonce for the page's inline tags. Images may also come
  # from the hosts catalog pages already use for card images. Other pages send no policy (AC-2.3).
  module ScannerPage
    extend ActiveSupport::Concern

    included do
      content_security_policy do |policy|
        policy.default_src :self
        policy.script_src :self, :wasm_unsafe_eval
        policy.worker_src :self, :blob
        policy.connect_src :self
        policy.img_src :self, :data, :blob, *Catalog.allowed_hosts.map { "https://#{it}" }
        policy.style_src :self, :unsafe_inline
        policy.font_src :self
        policy.object_src :none
        policy.frame_src :none
        policy.base_uri :self
        policy.form_action :self
        policy.frame_ancestors :self
      end
    end
  end
  ```

  Implement `app/controllers/scanners_controller.rb`:

  ```ruby
  # The card scanner page (spec 007 Stories 1–4): a live camera with the card guide, on-device OCR, and the
  # candidate printings. Reachable by URL only until adding from the scanner ships (AC-1.7).
  class ScannersController < ApplicationController
    include ScannerPage

    def show; end
  end
  ```

  Implement `app/controllers/scanner/readings_controller.rb`:

  ```ruby
  # Turns the text read off a card into what the page shows (spec 007 Story 3). Only text arrives here; the
  # photo never leaves the device (FR-3).
  class Scanner::ReadingsController < ApplicationController
    TOO_LONG = "That reading was too long to use. Line the card up with the guide and capture it again.".freeze

    def create
      reading = MTG::Reading.new(params.expect(reading: %i[name_text collector_text]))
      if reading.valid?
        render turbo_stream: turbo_stream.update("scanner_result", partial: "scanners/result", locals: { reading: reading.resolve })
      else
        render turbo_stream: turbo_stream.update("scanner_result", partial: "shared/status_message", locals: { message: TOO_LONG, alert: true }),
          status: :unprocessable_content
      end
    end
  end
  ```

  Implement `app/helpers/scanners_helper.rb`:

  ```ruby
  module ScannersHelper
    COLLECTOR_OUTCOMES = { one: "Matched one printing", none: "No printing", several: "Several printings", unread: "Not read" }.freeze

    def collector_outcome(reading) = COLLECTOR_OUTCOMES.fetch(reading.collector_status)

    def ocr_engine_path = "/ocr/#{Collector::OcrEngine::VERSION}"
  end
  ```
- [ ] Write the views. Run the `collector-design-system` skill first and read `docs/design-system/README.md` and the `ItemTile`, `StatusMessage` and `EmptyState` docs. Phase 6 adds the `c-scanner*` styles and their doc.

  `app/views/scanners/_head.html.erb` (shared by every page that loads the engine):

  ```erb
  <% content_for :head do %>
    <%# The page's policy only applies to a full load, and a stale snapshot of a camera page is never wanted. %>
    <meta name="turbo-visit-control" content="reload">
    <meta name="turbo-cache-control" content="no-cache">
    <%= javascript_include_tag "#{ocr_engine_path}/tesseract.min.js", defer: true %>
  <% end %>
  ```

  `app/views/scanners/show.html.erb`:

  ```erb
  <% content_for :title, "Scan a card · Collector" %>
  <%= render "scanners/head" %>
  <%= render "layouts/appbar", section: :scanner %>
  <main class="c-main c-page">
    <div class="c-pagehead"><div><h1 class="c-pagehead__title">Scan a card</h1></div></div>
    <%= render "scanners/scanner" %>
  </main>
  <%= render "layouts/tabbar", section: :scanner %>
  ```

  `app/views/scanners/_scanner.html.erb`:

  ```erb
  <div class="c-scanner" data-controller="card-reader camera"
       data-card-reader-readings-url-value="<%= scanner_readings_path %>" data-card-reader-engine-path-value="<%= ocr_engine_path %>"
       data-action="camera:ready->card-reader#cameraReady camera:stopped->card-reader#cameraStopped camera:unavailable->card-reader#cameraUnavailable">
    <p class="c-scanner__status" role="status" aria-live="polite" data-card-reader-target="status">Loading the scanner…</p>
    <div class="c-scanner__stage" data-camera-target="stage" hidden>
      <video class="c-scanner__video" data-camera-target="video" playsinline muted autoplay></video>
      <div class="c-scanner__guide" data-camera-target="guide" aria-hidden="true"></div>
    </div>
    <div class="c-scanner__unavailable" data-card-reader-target="unavailable" hidden>
      <p class="c-status__message c-status__message--alert" data-card-reader-target="reason"></p>
      <button type="button" class="c-btn c-btn--secondary" data-card-reader-target="retry" data-action="card-reader#retryCamera">Try the camera again</button>
    </div>
    <div class="c-scanner__controls">
      <button type="button" class="c-btn c-btn--primary c-scanner__shutter" data-card-reader-target="shutter" data-action="card-reader#capture" disabled aria-busy="true">Capture</button>
      <button type="button" class="c-btn c-btn--secondary c-scanner__torch" data-camera-target="torch" data-action="camera#toggleTorch" aria-pressed="false" hidden>Torch</button>
      <label class="c-btn c-btn--ghost c-scanner__photo">Use a photo<input type="file" accept="image/*" class="c-sr" data-card-reader-target="picker" data-action="change->card-reader#pick" disabled></label>
      <button type="button" class="c-btn c-btn--secondary" data-card-reader-target="engineRetry" data-action="card-reader#retryEngine" hidden>Load the scanner again</button>
    </div>
    <div class="c-scanner__failure" data-card-reader-target="failure" hidden>
      <p class="c-status__message c-status__message--alert" data-card-reader-target="failureMessage"></p>
      <dl class="c-scanner__read">
        <dt>Name</dt><dd data-card-reader-target="failureName"></dd>
        <dt>Collector line</dt><dd class="c-scanner__mono" data-card-reader-target="failureCollector"></dd>
      </dl>
      <button type="button" class="c-btn c-btn--secondary" data-card-reader-target="resend" data-action="card-reader#resend">Send again</button>
      <%= link_to "Sign in", new_session_path, class: "c-btn c-btn--primary", data: { card_reader_target: "signIn", turbo: false }, hidden: true %>
    </div>
    <div id="scanner_result" class="c-scanner__result" data-card-reader-target="result"></div>
    <noscript><p class="c-status__message c-status__message--alert">The scanner needs JavaScript. <%= link_to "Search the catalog", catalog_entries_path %> instead.</p></noscript>
  </div>
  ```

  `app/views/scanners/_result.html.erb`:

  ```erb
  <%# locals: (reading:) %>
  <% if !reading.catalog_ready? %>
    <p class="c-status__message c-status__message--alert">The card catalog isn't ready yet. Once it has loaded, scan the card again.</p>
  <% elsif reading.nothing_read? %>
    <p class="c-empty">Nothing could be read. Line the card up with the guide and capture it again.</p>
  <% else %>
    <section aria-labelledby="scanner-read">
      <div class="c-section__head"><h2 class="c-section__title" id="scanner-read">What the scanner read</h2></div>
      <dl class="c-scanner__read">
        <dt>Name</dt><dd><%= reading.name_text.presence || "Nothing read" %></dd>
        <dt>Collector line</dt><dd class="c-scanner__mono"><%= reading.collector_text.presence || "Nothing read" %></dd>
        <dt>Set</dt><dd class="c-scanner__mono"><%= reading.collector_line.set_code || "Not found" %></dd>
        <dt>Number</dt><dd class="c-scanner__mono"><%= reading.collector_line.number || "Not found" %></dd>
        <dt>Language</dt><dd class="c-scanner__mono"><%= reading.collector_line.language&.upcase || "Not found" %></dd>
        <dt>Printing</dt><dd><%= collector_outcome(reading) %></dd>
      </dl>
    </section>
    <section aria-labelledby="scanner-candidates">
      <div class="c-section__head"><h2 class="c-section__title" id="scanner-candidates">Candidates</h2></div>
      <% if reading.candidates.empty? %>
        <p class="c-empty">No card matches what was read. Line the card up with the guide and capture it again.</p>
      <% else %>
        <div class="c-grid"><%= render partial: "scanners/candidate", collection: reading.candidates, as: :candidate %></div>
      <% end %>
      <p class="c-scanner__note">Adding cards from the scanner is coming. For now, open a candidate and add it from its page, or <%= link_to "search the catalog", catalog_entries_path(q: reading.candidates.first&.entry&.name.presence || reading.name_text.presence) %>.</p>
    </section>
  <% end %>
  ```

  `app/views/scanners/_candidate.html.erb` (an `ItemTile` without the add button, AC-3.10):

  ```erb
  <%# locals: (candidate:) %>
  <% entry = candidate.entry %>
  <div class="c-tilecell c-scanner__candidate">
    <%= link_to catalog_entry_path(entry), class: "c-tile" do %>
      <div class="c-tile__media">
        <% if (image = catalog_url(entry.image_url)) %>
          <%= image_tag image, alt: entry.name, loading: "lazy", width: 146, height: 204 %>
        <% else %>
          <div class="c-tile__missing"><strong><%= entry.name %></strong><span><%= set_number(entry) %></span></div>
        <% end %>
      </div>
      <div class="c-tile__name"><%= entry.display_name %></div>
      <div class="c-tile__meta"><span class="c-tag"><%= set_number(entry) %></span><span class="c-tag"><%= entry.set.name %></span></div>
    <% end %>
    <% if candidate.source == :collector_line %>
      <span class="c-badge c-badge--success"><%= render "icons/check" %>Matched by its collector line</span>
    <% end %>
  </div>
  ```
- [ ] Run: `bin/rspec spec/requests/scanners_spec.rb spec/requests/scanner/readings_spec.rb spec/routing/routes_spec.rb`. Expect: 0 failures.
- [ ] Commit: `feat(scanner): add the scanner page, its policy and the readings endpoint`

---
## Phase 6: Scanner front end

**Implements:** FR-1 (design system), FR-2, FR-3 | **Satisfies:** AC-1.1, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-2.1, AC-2.5, AC-2.6, AC-4.1, AC-4.2, AC-4.3, NFR Accessibility, NFR Reliability (camera tests)
**Files:** `config/importmap.rb`, `app/javascript/scanner/{geometry,recognition}.js`, `app/javascript/controllers/{camera,card_reader}_controller.js`, `app/assets/stylesheets/collector/additions.css`, `docs/design-system/components/Scanner.md`, `docs/design-system/README.md`, `spec/design_system_files_spec.rb`, `spec/support/system.rb`, `spec/support/scanner_helpers.rb`, `spec/system/scanner_spec.rb`
**Interfaces:** Consumes: the Phase 5 markup and endpoints, and the `/ocr/v7.0.0/` files. Produces:
- `scanner/geometry`: `CARD_ASPECT`, `STAGE_ASPECT`, `GUIDE`, `STRIPS`, `guideRect(viewW, viewH)`, `guideInFrame(frameW, frameH, viewW, viewH)` and `cropStrips(image, card) → { name, collector }` canvases.
- `scanner/recognition`: `SETTINGS`, `loadEngine(path) → Promise<worker>` and `readStrips(path, strips) → { nameText, collectorText, ms }`.
- The `camera` controller: `restart()`, `grab() → { image, card }`, `toggleTorch()`, and the events `camera:ready`, `camera:stopped` and `camera:unavailable` (detail `{ reason }`, one of `insecure`, `denied`, `no-camera`, `failed` or `lost`).
- The `card-reader` controller: dispatches `card-reader:read`, with detail `{ nameText, collectorText, ms, strips }`.
- The spec helpers `show_synthetic_card`, `pick_synthetic_photo`, `restart_camera`, `wait_for_scanner`, `eventually` (returns the expression's value, so examples assert on it) and `scanner_sent`.

The camera's whole life, from start to stop, plus the guide, strips, OCR and sending, in small controllers over two plain modules. The system specs use the in-page `getUserMedia` substitution from ADR 0002 to draw a synthetic card that real OCR reads.

- [ ] Grant camera access in the system driver. In `spec/support/system.rb`, replace the `driven_by` line with:

  ```ruby
      # Camera pages get Firefox's synthetic stream without a prompt; scanner specs then substitute their own
      # card in the page (ADR 0002).
      driven_by :selenium, using: :headless_firefox, screen_size: [ 1400, 1400 ] do |options|
        options.add_preference("media.navigator.permission.disabled", true)
        options.add_preference("media.navigator.streams.fake", true)
      end
  ```
- [ ] Write `spec/support/scanner_helpers.rb`:

  ```ruby
  # Drives the scanner page in system specs (spec 007; ADR 0002): a synthetic 63:88 card, drawn so its name and
  # collector line sit exactly where the page cuts its strips, stands in for the camera or a picked photo.
  module ScannerHelpers
    CARD_JS = <<~JS.freeze
      // WebDriver runs this in a sandbox without the page's import map, so load the page's own geometry module
      // through a module script carrying the page's nonce.
      window.__geometry ||= new Promise((resolve) => {
        addEventListener("geometry-ready", () => resolve(window.__scannerGeometry), { once: true })
        const script = Object.assign(document.createElement("script"), { type: "module", nonce: document.querySelector("script[type=importmap]")?.nonce || "" })
        script.textContent = `import * as geometry from "scanner/geometry"; window.__scannerGeometry = geometry; dispatchEvent(new Event("geometry-ready"))`
        document.head.append(script)
      })
      window.__syntheticCard = async (name, lines) => {
        const { STRIPS, guideRect } = await window.__geometry
        const canvas = Object.assign(document.createElement("canvas"), { width: 900, height: 1200 })
        const context = canvas.getContext("2d")
        const card = guideRect(canvas.width, canvas.height)
        const box = (strip) => ({ x: card.x + card.width * strip.x, y: card.y + card.height * strip.y, w: card.width * strip.w, h: card.height * strip.h })
        const draw = () => {
          context.fillStyle = "gray"; context.fillRect(0, 0, canvas.width, canvas.height)
          context.fillStyle = "white"; context.fillRect(card.x, card.y, card.width, card.height)
          context.fillStyle = "black"; context.textBaseline = "middle"
          const title = box(STRIPS.name)
          context.font = `${Math.round(title.h * 0.55)}px sans-serif`
          context.fillText(name, title.x + title.h * 0.2, title.y + title.h / 2)
          const footer = box(STRIPS.collector)
          context.font = `${Math.round(footer.h * 0.3)}px sans-serif`
          lines.forEach((line, index) => context.fillText(line, footer.x + footer.h * 0.2, footer.y + footer.h * (index + 1) / (lines.length + 1)))
        }
        draw()
        return { canvas, draw }
      }
      if (!window.__sent) { // records the field names of every form the page posts; files show as "<name>:file"
        window.__sent = []
        const send = window.fetch
        window.fetch = (url, options = {}) => {
          if (options.body instanceof FormData) window.__sent.push([ ...options.body.entries() ].map(([ key, value ]) => typeof value === "string" ? key : `${key}:file`))
          return send(url, options)
        }
      }
    JS

    def show_synthetic_card(name: "Lightning Bolt", lines: [ "R 0123", "MOM • EN" ], torch: false)
      page.evaluate_async_script(<<~JS, name, lines, torch)
        const [ name, lines, torch, done ] = arguments
        #{CARD_JS}
        window.__syntheticCard(name, lines).then(({ canvas, draw }) => {
          window.__tracks = []; window.__cameraRequests = []; window.__torch = []
          navigator.mediaDevices.getUserMedia = async (constraints) => {
            window.__cameraRequests.push(constraints)
            const stream = canvas.captureStream(10)
            const track = stream.getVideoTracks()[0]
            setInterval(draw, 100)
            if (torch) {
              track.getCapabilities = () => ({ torch: true })
              track.applyConstraints = async (constraints) => { window.__torch.push(constraints.advanced[0].torch) }
            }
            window.__tracks.push(track)
            return stream
          }
          done(true)
        })
      JS
      restart_camera
      wait_for_scanner
      eventually("window.__tracks.length > 0 && document.querySelector('.c-scanner__video').readyState >= 2")
    end

    # The engine has loaded and a live camera feed is showing (the shutter enables only then).
    def wait_for_scanner
      expect(page).to have_button("Capture", disabled: false, wait: 30)
    end

    def pick_synthetic_photo(name: "Lightning Bolt", lines: [ "R 0123", "MOM • EN" ])
      page.evaluate_async_script(<<~JS, name, lines)
        const [ name, lines, done ] = arguments
        #{CARD_JS}
        window.__syntheticCard(name, lines).then(({ canvas }) => canvas.toBlob((blob) => {
          const transfer = new DataTransfer()
          transfer.items.add(new File([ blob ], "card.png", { type: "image/png" }))
          const input = document.querySelector("[data-card-reader-target=picker]")
          input.files = transfer.files
          input.dispatchEvent(new Event("change", { bubbles: true }))
          done(true)
        }, "image/png"))
      JS
    end

    def restart_camera
      page.execute_script(%(window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(".c-scanner"), "camera").restart()))
    end

    # Waits for a JavaScript expression to become truthy, the way Capybara's matchers wait for the DOM.
    def eventually(script, wait: 10)
      page.document.synchronize(wait) { page.evaluate_script(script) || raise(Capybara::ExpectationNotMet, script) }
    end

    def scanner_sent = page.evaluate_script("window.__sent")
  end

  RSpec.configure { |config| config.include ScannerHelpers, type: :system }
  ```
- [ ] Write `spec/system/scanner_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe "Card scanner", type: :system do
    before do
      identity = create(:catalog_identity, name: "Lightning Bolt")
      mom = create(:catalog_set, code: "mom", name: "March of the Machine")
      create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
      Catalog::NameIndex.new("mtg").rebuild
      system_sign_in_as(create(:user))
      visit scanner_path
    end

    it "asks for the rear camera, draws the guide and reads a lined-up card (AC-1.1, AC-1.3, AC-2.1, AC-3.2)", :aggregate_failures do
      wait_for_scanner
      show_synthetic_card
      expect(page).to have_css(".c-scanner__stage:not([hidden]) .c-scanner__guide")
      click_on "Capture"
      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      expect(first(".c-scanner__candidate")).to have_text("Matched by its collector line")
      expect(page.evaluate_script("window.__cameraRequests[0]")).to include("audio" => false, "video" => include("facingMode" => { "ideal" => "environment" }))
      expect(scanner_sent).to eq([ [ "reading[name_text]", "reading[collector_text]" ] ])
    end

    it "reads one card at a time (AC-2.6)", :aggregate_failures do
      show_synthetic_card
      page.execute_script(%(const shutter = document.querySelector(".c-scanner__shutter"); shutter.click(); shutter.click()))
      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      expect(scanner_sent.size).to eq(1)
    end

    it "stops every camera track when the scanner leaves the page (AC-1.4)" do
      show_synthetic_card
      page.execute_script(%(document.querySelector(".c-scanner").remove()))
      expect(eventually("window.__tracks.length > 0 && window.__tracks.every((track) => track.readyState === 'ended')")).to be(true)
    end

    it "shows a live feed again, not a cached picture, when you come back (AC-1.4)" do
      show_synthetic_card
      visit collection_path
      page.go_back
      expect(eventually("document.querySelector('.c-scanner__video')?.srcObject?.active === true", wait: 30)).to be(true)
    end

    it "offers the torch only when the camera has one (AC-1.5)", :aggregate_failures do
      wait_for_scanner
      expect(page).to have_no_button("Torch")
      show_synthetic_card(torch: true)
      click_on "Torch"
      expect(page).to have_css("button[aria-pressed=true]", text: "Torch")
      click_on "Torch"
      eventually("window.__torch.length === 2")
      expect(page.evaluate_script("window.__torch")).to eq([ true, false ])
    end

    it "explains that the live camera needs HTTPS, without asking for it (AC-1.6, AC-4.1)", :aggregate_failures do
      wait_for_scanner
      page.execute_script(<<~JS)
        Object.defineProperty(window, "isSecureContext", { get: () => false })
        window.__cameraRequests = []
        navigator.mediaDevices.getUserMedia = async (constraints) => { window.__cameraRequests.push(constraints); throw new Error("asked") }
      JS
      restart_camera
      expect(page).to have_text("The live camera needs this page to be served over HTTPS")
      expect(page).to have_field("Use a photo", type: "file", visible: :all, disabled: false)
      expect(page).to have_no_button("Try the camera again")
      expect(page.evaluate_script("window.__cameraRequests.length")).to eq(0)
    end

    it "explains a blocked camera and offers to try again (AC-4.1)", :aggregate_failures do
      wait_for_scanner
      page.execute_script(%(navigator.mediaDevices.getUserMedia = async () => { throw new DOMException("blocked", "NotAllowedError") }))
      restart_camera
      expect(page).to have_text("The camera is blocked for this site")
      expect(page).to have_button("Try the camera again")
      expect(page).to have_button("Capture", disabled: true)
    end

    it "reads a picked photo with the same guide and strips, while the camera is live (AC-4.2, AC-4.3)", :aggregate_failures do
      wait_for_scanner
      expect(page).to have_field("Use a photo", type: "file", visible: :all, disabled: false)
      pick_synthetic_photo
      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      expect(scanner_sent).to eq([ [ "reading[name_text]", "reading[collector_text]" ] ])
    end

    it "asks you to sign in again when your session has ended" do
      show_synthetic_card
      page.driver.browser.manage.delete_cookie("session_id")
      click_on "Capture"
      expect(page).to have_text("Your session has ended", wait: 30)
    end

    it "fits a 360px screen with the shutter in the bottom third (NFR Accessibility)", :aggregate_failures do
      expect(open_in_narrow_frame(scanner_path, width: 360, ready: ".c-scanner__stage:not([hidden])")).to eq([ 360, true ])
      within_narrow_frame do
        expect(page.evaluate_script(%(document.querySelector(".c-scanner__shutter").getBoundingClientRect().top))).to be >= 800 * 2 / 3
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/system/scanner_spec.rb`. Expect: FAIL (the shutter never enables, since there are no controllers yet).
- [ ] Pin the modules. In `config/importmap.rb`, add:

  ```ruby
  pin_all_from "app/javascript/scanner", under: "scanner"
  ```
- [ ] Implement `app/javascript/scanner/geometry.js`:

  ```js
  // Card guide and strip geometry for the scanner (spec 007 AC-1.3, AC-4.2). The stage is 3:4; the guide is a
  // 63:88 card centred in it; strips are fractions of the guide. Live frames and picked photos use the same
  // rules, and the CSS gives .c-scanner__stage the same aspect ratio.
  export const CARD_ASPECT = 63 / 88
  export const STAGE_ASPECT = 3 / 4
  export const GUIDE = { height: 0.8, maxWidth: 0.9 } // shares of the stage
  // Frozen before the measured run, tuned only on cards outside the corpus (spec 007 AC-6.1).
  export const STRIPS = {
    name: { x: 0.05, y: 0.03, w: 0.72, h: 0.085 },
    collector: { x: 0.03, y: 0.905, w: 0.55, h: 0.085 }
  }

  export function guideRect(viewWidth, viewHeight) {
    let height = viewHeight * GUIDE.height
    let width = height * CARD_ASPECT
    if (width > viewWidth * GUIDE.maxWidth) {
      width = viewWidth * GUIDE.maxWidth
      height = width / CARD_ASPECT
    }
    return { x: (viewWidth - width) / 2, y: (viewHeight - height) / 2, width, height }
  }

  // The guide in image pixels when a frameWidth × frameHeight image fills a view with object-fit: cover.
  export function guideInFrame(frameWidth, frameHeight, viewWidth, viewHeight) {
    const scale = Math.max(viewWidth / frameWidth, viewHeight / frameHeight)
    const offsetX = (frameWidth - viewWidth / scale) / 2
    const offsetY = (frameHeight - viewHeight / scale) / 2
    const guide = guideRect(viewWidth, viewHeight)
    return { x: offsetX + guide.x / scale, y: offsetY + guide.y / scale, width: guide.width / scale, height: guide.height / scale }
  }

  export function cropStrips(image, card) {
    return Object.fromEntries(Object.entries(STRIPS).map(([ key, strip ]) => {
      const canvas = document.createElement("canvas")
      canvas.width = Math.round(card.width * strip.w)
      canvas.height = Math.round(card.height * strip.h)
      canvas.getContext("2d").drawImage(image, card.x + card.width * strip.x, card.y + card.height * strip.y,
        canvas.width, canvas.height, 0, 0, canvas.width, canvas.height)
      return [ key, canvas ]
    }))
  }
  ```
- [ ] Implement `app/javascript/scanner/recognition.js`:

  ```js
  // The on-device OCR engine (spec 007 Story 2, ADR 0001): one Tesseract worker per page session, kept across
  // Turbo visits, reading each strip with its own settings. Only the text leaves this module.
  // Page segmentation per strip, frozen before the measured run (spec 007 AC-6.1).
  export const SETTINGS = { name: { tessedit_pageseg_mode: "7" }, collector: { tessedit_pageseg_mode: "6" } }
  let engine = null

  export function loadEngine(path) {
    engine ||= window.Tesseract.createWorker("eng", 1, {
      workerPath: `${path}/worker.min.js`, corePath: `${path}/core`, langPath: `${path}/lang`
    }).catch((error) => { engine = null; throw error })
    return engine
  }

  export async function readStrips(path, strips) {
    const worker = await loadEngine(path)
    const started = performance.now()
    const text = {}
    for (const [ key, canvas ] of Object.entries(strips)) {
      await worker.setParameters(SETTINGS[key])
      const { data } = await worker.recognize(canvas)
      text[key] = data.text.trim()
    }
    return { nameText: text.name, collectorText: text.collector, ms: Math.round(performance.now() - started) }
  }
  ```
- [ ] Implement `app/javascript/controllers/camera_controller.js`:

  ```js
  import { Controller } from "@hotwired/stimulus"
  import { guideInFrame, guideRect } from "scanner/geometry"

  // Owns the scanner's camera (spec 007 Story 1). It asks for the rear camera, shows it with the card guide
  // over it, offers the torch when the track has one, and stops every track when the page is left, cached or
  // hidden, or the controller disconnects. Dispatches camera:ready and camera:unavailable ({ reason }).
  export default class extends Controller {
    static targets = [ "stage", "video", "guide", "torch" ]

    connect() {
      this.stop = this.stop.bind(this)
      this.resume = (event) => { if (event.persisted) this.restart() }
      document.addEventListener("turbo:before-cache", this.stop)
      window.addEventListener("pagehide", this.stop)
      window.addEventListener("pageshow", this.resume)
      this.observer = new ResizeObserver(() => this.layoutGuide())
      this.observer.observe(this.stageTarget)
      this.start()
    }

    disconnect() {
      document.removeEventListener("turbo:before-cache", this.stop)
      window.removeEventListener("pagehide", this.stop)
      window.removeEventListener("pageshow", this.resume)
      this.observer.disconnect()
      this.stop()
    }

    restart() {
      this.stop()
      this.start()
    }

    async start() {
      const attempt = this.attempt = Symbol("camera")
      await Promise.resolve() // let every controller on the element connect before the first event
      if (!window.isSecureContext) return this.unavailable("insecure")
      if (!navigator.mediaDevices?.getUserMedia) return this.unavailable("no-camera")
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          audio: false, video: { facingMode: { ideal: "environment" }, width: { ideal: 1920 }, height: { ideal: 1080 } }
        })
        if (attempt !== this.attempt) return stream.getTracks().forEach((track) => track.stop()) // left meanwhile
        this.stream = stream
        this.track.addEventListener("ended", () => this.unavailable("lost"))
        this.videoTarget.srcObject = stream
        await this.videoTarget.play()
        this.stageTarget.hidden = false
        this.layoutGuide()
        this.torchTarget.hidden = !this.track.getCapabilities?.()?.torch
        this.dispatch("ready")
      } catch (error) {
        if (attempt === this.attempt) this.unavailable(this.reasonFor(error))
      }
    }

    stop() {
      this.dispatch("stopped")
      this.attempt = null
      this.stream?.getTracks().forEach((track) => track.stop())
      this.stream = null
      this.torchOn = false
      if (this.hasVideoTarget) this.videoTarget.srcObject = null
      if (this.hasTorchTarget) this.torchTarget.setAttribute("aria-pressed", "false")
    }

    get track() {
      return this.stream?.getVideoTracks()[0]
    }

    // The current frame at the camera's full delivered resolution, and the guide mapped into it (AC-1.3).
    grab() {
      const video = this.videoTarget
      const image = Object.assign(document.createElement("canvas"), { width: video.videoWidth, height: video.videoHeight })
      image.getContext("2d").drawImage(video, 0, 0)
      const view = this.stageTarget.getBoundingClientRect()
      return { image, card: guideInFrame(image.width, image.height, view.width, view.height) }
    }

    async toggleTorch() {
      const on = !this.torchOn
      try {
        await this.track.applyConstraints({ advanced: [ { torch: on } ] })
        this.torchOn = on
        this.torchTarget.setAttribute("aria-pressed", String(on))
      } catch {
        this.torchTarget.hidden = true
      }
    }

    layoutGuide() {
      const view = this.stageTarget.getBoundingClientRect()
      const guide = guideRect(view.width, view.height)
      Object.assign(this.guideTarget.style, { left: `${guide.x}px`, top: `${guide.y}px`, width: `${guide.width}px`, height: `${guide.height}px` })
    }

    unavailable(reason) {
      this.stop()
      this.stageTarget.hidden = true
      this.torchTarget.hidden = true
      this.dispatch("unavailable", { detail: { reason } })
    }

    reasonFor(error) {
      if ([ "NotAllowedError", "SecurityError" ].includes(error.name)) return "denied"
      if ([ "NotFoundError", "OverconstrainedError" ].includes(error.name)) return "no-camera"
      return "failed"
    }
  }
  ```
- [ ] Implement `app/javascript/controllers/card_reader_controller.js`:

  ```js
  import { Controller } from "@hotwired/stimulus"
  import { Turbo } from "@hotwired/turbo-rails"
  import { cropStrips, guideInFrame, STAGE_ASPECT } from "scanner/geometry"
  import { loadEngine, readStrips } from "scanner/recognition"

  // Turns a captured frame or a picked photo into what the card says (spec 007 Stories 2–4). It cuts the
  // strips, reads them on the device, sends only the text, and shows the Turbo Stream answer. One reading at
  // a time. Dispatches card-reader:read ({ nameText, collectorText, ms, strips }) for measurement mode.
  const REASONS = {
    insecure: "The live camera needs this page to be served over HTTPS. You can use a photo instead.",
    denied: "The camera is blocked for this site. Allow it in your browser's settings, or use a photo instead.",
    "no-camera": "No camera was found. You can use a photo instead.",
    failed: "The camera didn't start. Try again, or use a photo instead.",
    lost: "The camera stopped. Try again, or use a photo instead."
  }

  export default class extends Controller {
    static targets = [ "status", "shutter", "picker", "result", "unavailable", "reason", "retry", "engineRetry",
      "failure", "failureMessage", "failureName", "failureCollector", "signIn", "resend" ]
    static values = { readingsUrl: String, enginePath: String }

    connect() {
      this.cameraLive = false
      this.startEngine()
    }

    async startEngine() {
      this.engineReady = false
      this.busy = true
      this.engineRetryTarget.hidden = true
      this.render()
      this.say("Loading the scanner…")
      try {
        await loadEngine(this.enginePathValue)
        this.engineReady = true
        this.say(this.cameraLive ? "Ready. Line the card up with the guide, then capture." : "Ready.")
      } catch {
        this.engineRetryTarget.hidden = false
        this.say("The scanner couldn't load, so neither the camera nor a photo can be read. Check your connection and load it again.")
      } finally {
        this.busy = false
        this.render()
      }
    }

    retryEngine() {
      this.startEngine()
    }

    cameraReady() {
      this.cameraLive = true
      this.unavailableTarget.hidden = true
      if (this.engineReady) this.say("Ready. Line the card up with the guide, then capture.")
      this.render()
    }

    cameraStopped() {
      this.cameraLive = false
      this.render()
    }

    cameraUnavailable({ detail: { reason } }) {
      this.cameraLive = false
      this.reasonTarget.textContent = REASONS[reason]
      this.retryTarget.hidden = reason === "insecure"
      this.unavailableTarget.hidden = false
      this.render()
    }

    retryCamera() {
      this.camera.restart()
    }

    capture() {
      if (!this.engineReady || !this.cameraLive || this.busy) return
      const { image, card } = this.camera.grab()
      this.read(image, card)
    }

    async pick() {
      const file = this.pickerTarget.files[0]
      this.pickerTarget.value = ""
      if (!file || !this.engineReady || this.busy) return
      const image = await createImageBitmap(file) // applies the photo's orientation
      this.read(image, guideInFrame(image.width, image.height, STAGE_ASPECT, 1))
    }

    async read(image, card) {
      if (this.busy) return
      this.busy = true
      this.render()
      this.say("Reading the card…")
      try {
        const strips = cropStrips(image, card)
        const reading = await readStrips(this.enginePathValue, strips)
        if (!this.element.isConnected) return
        this.dispatch("read", { detail: { ...reading, strips } })
        this.lastReading = reading
        await this.send(reading)
      } catch {
        this.say("The card couldn't be read. Line it up with the guide and try again.")
      } finally {
        this.busy = false
        this.render()
      }
    }

    resend() {
      if (this.lastReading) this.send(this.lastReading)
    }

    async send({ nameText, collectorText }) {
      this.failureTarget.hidden = true
      const body = new FormData()
      body.append("reading[name_text]", nameText)
      body.append("reading[collector_text]", collectorText)
      let response
      try {
        response = await fetch(this.readingsUrlValue, { method: "POST", body, redirect: "manual",
          headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content } })
      } catch {
        return this.failed("The text couldn't be sent. Check your connection, then send it again.", { signedOut: false })
      }
      if (response.type === "opaqueredirect") return this.failed("Your session has ended. Sign in again, then capture the card again.", { signedOut: true })
      if (!response.ok && response.status !== 422) return this.failed("The scanner had a problem with that card. Send it again.", { signedOut: false })
      Turbo.renderStreamMessage(await response.text())
      this.say("Done. What the scanner read and its candidates are below.")
    }

    failed(message, { signedOut }) {
      this.failureMessageTarget.textContent = message
      this.failureNameTarget.textContent = this.lastReading?.nameText || "Nothing read"
      this.failureCollectorTarget.textContent = this.lastReading?.collectorText || "Nothing read"
      this.resendTarget.hidden = signedOut
      this.signInTarget.hidden = !signedOut
      this.failureTarget.hidden = false
      this.say(message)
    }

    render() {
      this.shutterTarget.disabled = !(this.engineReady && this.cameraLive) || this.busy
      this.shutterTarget.setAttribute("aria-busy", String(this.busy || !this.engineReady))
      this.pickerTarget.disabled = !this.engineReady || this.busy
    }

    say(message) {
      this.statusTarget.textContent = message
    }

    get camera() {
      return this.application.getControllerForElementAndIdentifier(this.element, "camera")
    }
  }
  ```

  `guideInFrame(w, h, STAGE_ASPECT, 1)` treats a photo as if it filled a 3:4 stage, which is how a live frame fills the stage (AC-4.2).
- [ ] Add the `Scanner` styles to `app/assets/stylesheets/collector/additions.css`:

  ```css
  /* ---------- Scanner (spec 007): live camera with the card guide, controls, what was read ---------- */
  .c-scanner { display:flex; flex-direction:column; gap:var(--space-4); max-width:480px; }
  .c-scanner__status { margin:0; font:400 15px/22px var(--font-sans); color:var(--ink); }
  .c-scanner__stage { position:relative; width:100%; aspect-ratio:3 / 4; overflow:hidden; background:var(--surface-sunken);
    border:1px solid var(--line); border-radius:var(--radius-md); }
  .c-scanner__stage[hidden] { display:none; }
  .c-scanner__video { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; }
  .c-scanner__guide { position:absolute; border:2px solid var(--brand); outline:2px dashed var(--on-brand); outline-offset:-6px;
    border-radius:var(--radius-card) / calc(var(--radius-card) * 63 / 88); pointer-events:none; }
  .c-scanner__controls { display:flex; flex-wrap:wrap; align-items:center; gap:var(--space-2); }
  .c-scanner__shutter, .c-scanner__torch, .c-scanner__photo { min-height:44px; min-width:44px; }
  .c-scanner__shutter { flex:1 1 auto; }
  .c-scanner__photo:focus-within { outline:2px solid var(--focus); outline-offset:2px; }
  .c-scanner__unavailable, .c-scanner__failure { display:flex; flex-direction:column; align-items:flex-start; gap:var(--space-2); }
  .c-scanner__unavailable[hidden], .c-scanner__failure[hidden] { display:none; }
  .c-scanner__read { display:grid; grid-template-columns:max-content 1fr; gap:var(--space-1) var(--space-3); margin:0;
    font:400 14px/20px var(--font-sans); }
  .c-scanner__read dt { color:var(--ink-muted); }
  .c-scanner__read dd { margin:0; white-space:pre-wrap; overflow-wrap:anywhere; }
  .c-scanner__mono { font-family:var(--font-mono); }
  .c-scanner__result { display:flex; flex-direction:column; gap:var(--space-6); }
  .c-scanner__note { margin:var(--space-3) 0 0; font:400 14px/20px var(--font-sans); color:var(--ink-muted); }
  @media (prefers-reduced-motion: reduce) { .c-scanner * { transition:none; animation:none; } }
  ```

  Write `docs/design-system/components/Scanner.md`:

  ````markdown
  # Scanner

  The card scanner (spec 007): a live camera feed with a card-shaped guide, the controls under it, and what the scanner read with its candidate printings.

  **Markup** — `scanners/_scanner.html.erb` renders it; the controllers `card-reader` and `camera` bring it to life.

  ```html
  <div class="c-scanner">
    <p class="c-scanner__status" role="status" aria-live="polite">Ready. Line the card up with the guide, then capture.</p>
    <div class="c-scanner__stage"><video class="c-scanner__video" playsinline muted></video><div class="c-scanner__guide" aria-hidden="true"></div></div>
    <div class="c-scanner__controls">
      <button class="c-btn c-btn--primary c-scanner__shutter">Capture</button>
      <button class="c-btn c-btn--secondary c-scanner__torch" aria-pressed="false">Torch</button>
      <label class="c-btn c-btn--ghost c-scanner__photo">Use a photo<input type="file" accept="image/*" class="c-sr"></label>
    </div>
    <div id="scanner_result" class="c-scanner__result">…<dl class="c-scanner__read">…</dl><div class="c-grid">…</div></div>
  </div>
  ```

  - The stage is 3:4 and the guide a 63:88 card centred in it, at 80% of the stage's height. `scanner/geometry.js` holds the same numbers; change both together.
  - The guide is drawn in `brand` with an `on-brand` dashed inner line, so it reads on light and dark scenes. Alignment is never shown by colour alone: the status line says what to do.
  - The shutter, torch and photo controls are at least 44px and sit under the stage, in the bottom third of a phone screen.
  - Candidates are `ItemTile`s without the add button. A collector-line match carries a `c-badge--success` with a check and the words "Matched by its collector line".
  - Problems (no camera, no HTTPS, the text not sent) use the `StatusMessage` inline alert, with one next step as a button.
  - The page needs JavaScript; `<noscript>` points to the catalog search.
  ````

  In `docs/design-system/README.md`, add `` `Scanner` `` to the end of the "App additions" list. In `spec/design_system_files_spec.rb`, add `Scanner` to `new_patterns`.
- [ ] Run: `bin/rspec spec/system/scanner_spec.rb spec/design_system_files_spec.rb`. Expect: 0 failures. Then run `bin/rspec spec/system/scanner_spec.rb` 10 times in a row (`for i in $(seq 10); do bin/rspec spec/system/scanner_spec.rb || break; done`). Expect: 10 green runs (NFR Reliability). Record any failure and its message in the commit body.
- [ ] Run: `bin/rspec spec/system`. Expect: 0 failures (the existing system specs are unaffected by the camera preferences).
- [ ] Commit: `feat(scanner): live camera, card guide, strips and on-device OCR`

---
## Phase 7: Measurement mode

**Implements:** FR-6, Story 5 | **Satisfies:** AC-5.1, AC-5.2, AC-5.3, AC-5.4 (mechanics), AC-5.5, AC-5.6 (mechanics)
**Files:** `config/application.rb`, `config/environments/development.rb`, `config/routes.rb`, `app/models/scanner/measurement_run.rb`, `app/controllers/concerns/measurement_mode.rb`, `app/controllers/scanner/measurements_controller.rb`, `app/controllers/scanner/measurements/{captures,skips,replays,strips}_controller.rb`, `app/views/scanner/measurements/{show,_panel}.html.erb`, `app/views/scanner/measurements/replays/show.html.erb`, `app/javascript/controllers/{measurement,replay}_controller.js`, `script/scanner/replay.rb`, `spec/models/scanner/measurement_run_spec.rb`, `spec/requests/scanner/measurements_spec.rb`, `spec/system/scanner_measurement_spec.rb`, `spec/routing/routes_spec.rb`
**Interfaces:** Consumes: `card-reader:read` events, `scanners/_scanner`, `scanners/_head`, `ScannerPage`, `scanner/recognition`. Produces:
- `Scanner::MeasurementRun.enabled?` and `.current`, plus instance methods `#rows`, `#row(file)`, `#status(row)`, `#next_row`, `#counts`, `#retakes`, `#record!`, `#skip!`, `#measured_rows`, `#measured_captures`, `#strip_path(row, strip)`, `#record_replay!(label, results)`, `#replays → { label => results }`, `#expected_name(row)` and `#dir`.
- Routes under `/scanner/measurement`.
- `script/scanner/replay.rb <label>`.

Development-only tooling for the re-measure: the manifest row is chosen before the shutter, and each capture's text and strips are stored outside the repository. Stored strips can be replayed headlessly on the desktop.

- [ ] Write `spec/models/scanner/measurement_run_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe Scanner::MeasurementRun, type: :model do
    let(:dir) { Pathname(Dir.mktmpdir("corpus")) }
    let(:run) { described_class.new(manifest: dir.join("manifest.csv"), dir: dir.join("runs/live")) }

    after { FileUtils.remove_entry(dir) }

    it "reads the Phase 0 manifest format" do
      dir.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,mom,123,no\n")
      expect(run.rows).to eq([ described_class::Row.new(file: "IMG_1.jpeg", set: "mom", number: "123") ])
    end

    it "says what is wrong with a missing or malformed manifest", :aggregate_failures do
      expect { run.rows }.to raise_error(described_class::ManifestError, /No manifest at/)
      dir.join("manifest.csv").write("file,set\nIMG_1.jpeg,mom\n")
      expect { described_class.new(manifest: dir.join("manifest.csv"), dir:).rows }.to raise_error(described_class::ManifestError, /needs file, set and number/)
      dir.join("manifest.csv").write("file,set,number\n../x,mom,1\n")
      expect { described_class.new(manifest: dir.join("manifest.csv"), dir:).rows }.to raise_error(described_class::ManifestError, /Bad file name/)
    end

    it "is enabled only when configured", :aggregate_failures do
      expect(described_class).not_to be_enabled
      expect(described_class.current).to be_nil
    end
  end
  ```
- [ ] Write `spec/requests/scanner/measurements_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe "Scanner measurement mode", type: :request do
    let(:corpus) { Pathname(Dir.mktmpdir("corpus")) }
    let(:run_dir) { corpus.join("runs/live") }
    let(:png) { "\x89PNG\r\n\x1A\nstrip".b }
    let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }

    around do |example|
      corpus.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,mom,123,no\nIMG_2.jpeg,neo,51,yes\n")
      Rails.configuration.x.scanner_measurement = { manifest: corpus.join("manifest.csv").to_s, dir: run_dir.to_s }
      example.run
    ensure
      Rails.configuration.x.scanner_measurement = nil
      FileUtils.remove_entry(corpus)
    end

    before { sign_in_as(create(:user)) }

    def upload(data) = Rack::Test::UploadedFile.new(StringIO.new(data), "image/png", original_filename: "strip.png")

    def capture(file: "IMG_1.jpeg", strip: png)
      post scanner_measurement_captures_path, headers: turbo, params: { capture: { file:, name_text: "Lightning Bolt",
        collector_text: "R 0123\nMOM • EN", ms: "640", user_agent: "iPhone", name_strip: upload(strip), collector_strip: upload(strip) } }
    end

    def current = Scanner::MeasurementRun.current

    context "when measurement mode is off (AC-5.1)" do
      before { Rails.configuration.x.scanner_measurement = nil }

      it "answers 404 for every measurement route" do
        requests = [ -> { get scanner_measurement_path }, -> { capture }, -> { post scanner_measurement_skips_path, params: { file: "IMG_1.jpeg" } },
          -> { get scanner_measurement_replay_path(label: "a") }, -> { post scanner_measurement_replay_path, params: { label: "a", results: [] }, as: :json },
          -> { get scanner_measurement_strip_path("IMG_1.jpeg", strip: "name") } ]
        expect(requests.map { it.call && response.status }).to all(eq(404))
      end

      it "shows no measurement controls on the scanner" do
        get scanner_path
        expect(response.body).not_to include("measurement_panel", "Measured run") # the import map lists every controller, so not "measurement"
      end
    end

    it "shows the next manifest row and the card it should be (AC-5.2)" do
      create(:catalog_entry, set: create(:catalog_set, code: "mom"), number: "123", name: "Lightning Bolt")
      get scanner_measurement_path
      expect(response.body).to include('selected="selected" value="IMG_1.jpeg"', "expected Lightning Bolt (MOM · 123)")
    end

    it "stores the text and both strips outside the repository, then moves on (AC-5.3)", :aggregate_failures do
      capture
      expect(response.body).to include('<turbo-stream action="replace" target="measurement_panel">', "Stored IMG_1.jpeg as the measured capture")
      expect(response.body).to include('selected="selected" value="IMG_2.jpeg"')
      expect(JSON.parse(run_dir.join("IMG_1.jpeg/capture-001.json").read)).to include("kind" => "measured", "ms" => 640, "user_agent" => "iPhone")
      expect(run_dir.join("IMG_1.jpeg/capture-001-name.png").binread).to eq(png)
      expect(run_dir.to_s).not_to start_with(Rails.root.to_s)
    end

    it "keeps the first capture as the measured one; later ones are retakes (AC-5.4)", :aggregate_failures do
      2.times { capture }
      expect(response.body).to include("Stored IMG_1.jpeg as a retake", "1 retake")
      expect(current.measured_captures.map { it["kind"] }).to eq([ "measured" ])
    end

    it "records a skipped row (AC-5.5)", :aggregate_failures do
      post scanner_measurement_skips_path, params: { file: "IMG_2.jpeg" }, headers: turbo
      expect(response.body).to include("Skipped IMG_2.jpeg", "1 skipped")
      expect(current.status(current.row("IMG_2.jpeg"))).to eq(:skipped)
    end

    it "stores nothing for a strip that isn't a PNG, or a row the manifest doesn't list", :aggregate_failures do
      capture(strip: "GIF89a")
      expect(response).to have_http_status(:unprocessable_content)
      capture(file: "IMG_9.jpeg")
      expect(response).to have_http_status(:not_found)
      expect(run_dir).not_to exist
    end

    it "serves stored strips and takes replays from this machine only (AC-5.6)", :aggregate_failures do
      capture
      get scanner_measurement_strip_path("IMG_1.jpeg", strip: "name")
      expect(response.body.b).to eq(png)
      post scanner_measurement_replay_path, as: :json, params: { label: "desktop-a", results: [ { file: "IMG_1.jpeg", name_text: "Bolt", collector_text: "" } ] }
      expect(current.replays.fetch("desktop-a").first).to include("file" => "IMG_1.jpeg", "name_text" => "Bolt")
      get scanner_measurement_strip_path("IMG_1.jpeg", strip: "name"), env: { "REMOTE_ADDR" => "192.168.1.22" }
      expect(response).to have_http_status(:not_found)
    end

    it "says when the manifest is missing, and leaves the scanner alone", :aggregate_failures do
      corpus.join("manifest.csv").delete
      get scanner_measurement_path
      expect(response.body).to include("No manifest at")
      get scanner_path
      expect(response).to have_http_status(:ok)
    end
  end
  ```

  Add to `spec/routing/routes_spec.rb`:

  ```ruby
    it "routes measurement mode under the scanner", :aggregate_failures do
      expect(get: "/scanner/measurement").to route_to("scanner/measurements#show")
      expect(post: "/scanner/measurement/captures").to route_to("scanner/measurements/captures#create")
      expect(post: "/scanner/measurement/skips").to route_to("scanner/measurements/skips#create")
      expect(get: "/scanner/measurement/replay").to route_to("scanner/measurements/replays#show")
      expect(get: "/scanner/measurement/strips/IMG_1.jpeg").to route_to("scanner/measurements/strips#show", id: "IMG_1.jpeg")
    end
  ```
- [ ] Run: `bin/rspec spec/models/scanner spec/requests/scanner/measurements_spec.rb spec/routing/routes_spec.rb`. Expect: FAIL (`uninitialized constant Scanner::MeasurementRun`; no routes).
- [ ] Configure the setting. In `config/application.rb`, after `config.x.sign_in_rate_limit_store = nil`:

  ```ruby
      # Card scanner measurement mode (spec 007 Story 5): off unless an environment sets it.
      config.x.scanner_measurement = nil
  ```

  In `config/environments/development.rb`, before the final `end`:

  ```ruby
    # Card scanner measurement mode (spec 007 Story 5): captures of the cards in the manifest are stored in the
    # run directory, outside the repository. Point both somewhere else for a tuning run.
    config.x.scanner_measurement = {
      manifest: ENV.fetch("COLLECTOR_SCANNER_MANIFEST", "~/card-scanner-corpus/manifest.csv"),
      dir: ENV.fetch("COLLECTOR_SCANNER_RUN_DIR", "~/card-scanner-corpus/runs/live")
    }
  ```
- [ ] Add the routes inside `namespace :scanner` in `config/routes.rb`:

  ```ruby
      # Development-only measurement mode (spec 007 Story 5); every action answers 404 when it's off.
      resource :measurement, only: :show do
        scope module: :measurements do
          resources :captures, only: :create
          resources :skips, only: :create
          resource :replay, only: %i[show create]
          resources :strips, only: :show, constraints: { id: /[\w.-]+/ }
        end
      end
  ```
- [ ] Implement `app/models/scanner/measurement_run.rb`:

  ```ruby
  # A measured run of the card scanner (spec 007 Story 5): the manifest of known cards (spec 005's format,
  # file,set,number,foil[,era]) and what each live capture read, stored in a directory outside the
  # repository. The first capture of a row is the measured one; later ones are retakes (AC-5.4).
  # Layout: <dir>/<file>/capture-NNN.json, capture-NNN-{name,collector}.png, skipped.json;
  # <dir>/replays/<label>.json.
  class Scanner::MeasurementRun
    Row = Data.define(:file, :set, :number)
    class ManifestError < StandardError; end
    class InvalidCapture < StandardError; end

    FILE_NAME = /\A[\w-][\w.-]*\z/
    STRIPS = %w[name collector].freeze
    MAX_STRIP_BYTES = 5.megabytes
    PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b

    def self.enabled? = Rails.configuration.x.scanner_measurement.present?

    def self.current
      config = Rails.configuration.x.scanner_measurement
      new(manifest: config.fetch(:manifest), dir: config.fetch(:dir)) if config.present?
    end

    attr_reader :dir

    def initialize(manifest:, dir:)
      @manifest = Pathname(manifest).expand_path
      @dir = Pathname(dir).expand_path
    end

    # The manifest has no quoted or comma-bearing values, so a split is enough.
    def rows
      @rows ||= begin
        raise ManifestError, "No manifest at #{@manifest}." unless @manifest.file?

        header, *lines = @manifest.readlines(chomp: true).map(&:strip).reject(&:empty?)
        keys = header.to_s.split(",").map(&:strip)
        raise ManifestError, "#{@manifest.basename} needs file, set and number columns." unless (%w[file set number] - keys).empty?

        lines.map do |line|
          values = keys.zip(line.split(",", -1).map(&:strip)).to_h
          raise ManifestError, "Bad file name in #{@manifest.basename}: #{values["file"].inspect}." unless values["file"].to_s.match?(FILE_NAME)

          Row.new(file: values["file"], set: values["set"], number: values["number"])
        end
      end
    end

    def row(file) = rows.find { it.file == file }

    def status(row)
      if captures(row).any? then :captured
      elsif row_dir(row).join("skipped.json").file? then :skipped
      else :pending
      end
    end

    def next_row = rows.find { status(it) == :pending }

    def counts = rows.group_by { status(it) }.transform_values(&:size)

    def retakes = rows.sum { [ captures(it).size - 1, 0 ].max }

    def captures(row) = row_dir(row).glob("capture-*.json").sort.map { JSON.parse(it.read) }

    def measured_rows = rows.select { captures(it).any? }

    def measured_captures = measured_rows.map { captures(it).first }

    # Stores one capture and returns :measured for a row's first, :retake after. The JSON is written last, so a
    # capture interrupted halfway doesn't count.
    def record!(row, name_text:, collector_text:, ms:, user_agent:, name_strip:, collector_strip:)
      if [ name_text, collector_text ].any? { it.length > MTG::Reading::MAX_TEXT_LENGTH }
        raise InvalidCapture, "That capture's text was too long to store."
      end

      images = { "name" => png!(name_strip), "collector" => png!(collector_strip) }
      number = captures(row).size + 1
      kind = number == 1 ? :measured : :retake
      stem = format("capture-%03d", number)
      row_dir(row).mkpath
      images.each { |strip, data| row_dir(row).join("#{stem}-#{strip}.png").binwrite(data) }
      row_dir(row).join("#{stem}.json").write(JSON.pretty_generate("file" => row.file, "kind" => kind.to_s, "name_text" => name_text,
        "collector_text" => collector_text, "ms" => ms, "user_agent" => user_agent, "captured_at" => Time.current.utc.iso8601))
      kind
    end

    def skip!(row)
      row_dir(row).mkpath
      row_dir(row).join("skipped.json").write(JSON.generate("file" => row.file, "skipped_at" => Time.current.utc.iso8601))
    end

    # The measured capture's strip image, for the desktop replay (AC-5.6).
    def strip_path(row, strip) = STRIPS.include?(strip) ? row_dir(row).join("capture-001-#{strip}.png") : nil

    def record_replay!(label, results)
      @dir.join("replays").mkpath
      @dir.join("replays/#{label}.json").write(JSON.pretty_generate("label" => label, "replayed_at" => Time.current.utc.iso8601,
        "results" => results.map { it.slice("file", "name_text", "collector_text") }))
    end

    def replays = @dir.join("replays").glob("*.json").sort.to_h { |path| [ path.basename(".json").to_s, JSON.parse(path.read).fetch("results") ] }

    def expected_name(row)
      entry = Catalog::Entry.where(collectible_type: "mtg").printed_as(set_code: row.set, number: row.number, language: "en").first
      label = "#{row.set.upcase} · #{row.number}"
      entry ? "#{entry.name} (#{label})" : "#{label} (not in the catalog)"
    end

    private
      def row_dir(row) = @dir.join(row.file)

      def png!(upload)
        data = upload.respond_to?(:read) ? upload.read(MAX_STRIP_BYTES + 1) : nil
        return data if data && data.bytesize <= MAX_STRIP_BYTES && data.b.start_with?(PNG_SIGNATURE)

        raise InvalidCapture, "A strip wasn't a PNG of at most 5 MB, so nothing was stored."
      end
  end
  ```

  `record_replay!` takes hashes with string keys. The controller passes `params.expect(...).map(&:to_h)`, and `ActionController::Parameters#to_h` gives a `HashWithIndifferentAccess`, which `slice` with strings works on.
- [ ] Implement `app/controllers/concerns/measurement_mode.rb`:

  ```ruby
  # Development-only measurement mode for the card scanner (spec 007 AC-5.1, FR-6): every action answers 404
  # unless config.x.scanner_measurement is set (development's default; specs switch it on).
  module MeasurementMode
    extend ActiveSupport::Concern

    included do
      before_action :require_measurement_mode
      rescue_from Scanner::MeasurementRun::ManifestError, with: -> { head :unprocessable_content }
    end

    private
      def require_measurement_mode
        head :not_found unless Scanner::MeasurementRun.enabled?
      end

      # The desktop replay is driven by a local headless browser that isn't signed in.
      def require_local_request
        head :not_found unless request.local?
      end

      def measurement_run = @measurement_run ||= Scanner::MeasurementRun.current

      def panel_locals(notice: nil, alert: false)
        next_row = measurement_run.next_row
        { run: measurement_run, next_row:, expected: next_row && measurement_run.expected_name(next_row), notice:, alert: }
      end

      def render_panel(notice, alert: false, status: :ok)
        render turbo_stream: turbo_stream.replace("measurement_panel", partial: "scanner/measurements/panel",
          locals: panel_locals(notice:, alert:)), status:
      end
  end
  ```
- [ ] Implement the controllers.

  `app/controllers/scanner/measurements_controller.rb`:

  ```ruby
  # The card scanner in measurement mode (spec 007 Story 5): the manifest row to capture next, above the
  # normal scanner.
  class Scanner::MeasurementsController < ApplicationController
    include MeasurementMode
    include ScannerPage

    def show
      @panel = panel_locals
    rescue Scanner::MeasurementRun::ManifestError => error
      @manifest_problem = error.message
    end
  end
  ```

  `app/controllers/scanner/measurements/captures_controller.rb`:

  ```ruby
  # Stores one measured capture: the strip text and images for the manifest row chosen before the shutter
  # (spec 007 AC-5.3, AC-5.4).
  class Scanner::Measurements::CapturesController < ApplicationController
    include MeasurementMode

    def create
      capture = params.expect(capture: %i[file name_text collector_text ms user_agent name_strip collector_strip])
      row = measurement_run.row(capture[:file])
      return head(:not_found) unless row

      kind = measurement_run.record!(row, name_text: capture[:name_text].to_s, collector_text: capture[:collector_text].to_s,
        ms: capture[:ms].to_i, user_agent: capture[:user_agent].to_s, name_strip: capture[:name_strip], collector_strip: capture[:collector_strip])
      render_panel "Stored #{row.file} as #{kind == :measured ? "the measured capture" : "a retake"}."
    rescue Scanner::MeasurementRun::InvalidCapture => error
      render_panel error.message, alert: true, status: :unprocessable_content
    end
  end
  ```

  `app/controllers/scanner/measurements/skips_controller.rb`:

  ```ruby
  # Records that a manifest row's card wasn't to hand (spec 007 AC-5.5).
  class Scanner::Measurements::SkipsController < ApplicationController
    include MeasurementMode

    def create
      row = measurement_run.row(params.expect(:file))
      return head(:not_found) unless row

      measurement_run.skip!(row)
      render_panel "Skipped #{row.file}."
    end
  end
  ```

  `app/controllers/scanner/measurements/replays_controller.rb`:

  ```ruby
  # The desktop replay of a measured run (spec 007 AC-5.6): reads the stored strips again with the page's own
  # recognition code in a local headless browser, and stores what it read under a label.
  class Scanner::Measurements::ReplaysController < ApplicationController
    include MeasurementMode
    include ScannerPage
    allow_unauthenticated_access
    before_action :require_local_request

    LABEL = /\A[\w-]{1,40}\z/

    def show
      @label = params.expect(:label)
      return head(:not_found) unless @label.match?(LABEL)

      @files = measurement_run.measured_rows.map(&:file)
    end

    def create
      label = params.expect(:label)
      return head(:not_found) unless label.match?(LABEL)

      measurement_run.record_replay!(label, params.expect(results: [ %i[file name_text collector_text] ]).map(&:to_h))
      head :no_content
    end
  end
  ```

  `app/controllers/scanner/measurements/strips_controller.rb`:

  ```ruby
  # Serves a measured capture's stored strip to the local desktop replay (spec 007 AC-5.6).
  class Scanner::Measurements::StripsController < ApplicationController
    include MeasurementMode
    allow_unauthenticated_access
    before_action :require_local_request

    def show
      row = measurement_run.row(params[:id])
      path = row && measurement_run.strip_path(row, params[:strip])
      return head(:not_found) unless path&.file?

      send_file path, type: "image/png", disposition: :inline
    end
  end
  ```
- [ ] Write the views.

  `app/views/scanner/measurements/show.html.erb`:

  ```erb
  <% content_for :title, "Measure the scanner · Collector" %>
  <%= render "scanners/head" %>
  <%= render "layouts/appbar", section: :scanner %>
  <main class="c-main c-page">
    <div class="c-pagehead"><div><h1 class="c-pagehead__title">Measure the scanner</h1></div></div>
    <% if @manifest_problem %>
      <p class="c-status__message c-status__message--alert"><%= @manifest_problem %> Measurement mode can't start. The scanner itself is unaffected.</p>
    <% else %>
      <%= render "scanner/measurements/panel", @panel %>
      <%= render "scanners/scanner" %>
    <% end %>
  </main>
  <%= render "layouts/tabbar", section: :scanner %>
  ```

  `app/views/scanner/measurements/_panel.html.erb`:

  ```erb
  <%# locals: (run:, next_row:, expected:, notice: nil, alert: false) %>
  <section id="measurement_panel" aria-labelledby="measurement-heading" data-controller="measurement"
           data-measurement-captures-url-value="<%= scanner_measurement_captures_path %>" data-action="card-reader:read@window->measurement#store">
    <div class="c-section__head">
      <h2 class="c-section__title" id="measurement-heading">Measured run</h2>
      <span class="c-section__count"><%= run.counts.fetch(:captured, 0) %> of <%= run.rows.size %> captured · <%= run.counts.fetch(:skipped, 0) %> skipped · <%= pluralize(run.retakes, "retake") %></span>
    </div>
    <p class="c-field__hint">Stored in <%= run.dir %>. Take one deliberate shot per card: a card's first capture is the one that counts.</p>
    <p class="c-status__message<%= " c-status__message--alert" if alert %>" data-measurement-target="status" <%= "hidden" unless notice %>><%= notice %></p>
    <label class="c-field"><span class="c-field__label">Card to capture</span>
      <%= select_tag :file, options_for_select(run.rows.map { |row| [ "#{row.file} · #{row.set.upcase} #{row.number} (#{run.status(row)})", row.file ] }, next_row&.file),
            data: { measurement_target: "row" } %>
    </label>
    <% if next_row %>
      <p class="c-field__hint">Next: <%= next_row.file %>, expected <%= expected %>.</p>
      <%= button_to "Skip #{next_row.file}", scanner_measurement_skips_path, params: { file: next_row.file }, class: "c-btn c-btn--secondary c-btn--sm" %>
    <% else %>
      <p class="c-empty">Every card in the manifest is captured or skipped. Choose a card to retake it.</p>
    <% end %>
    <button type="button" class="c-btn c-btn--secondary c-btn--sm" data-measurement-target="retry" data-action="measurement#retry" hidden>Store again</button>
  </section>
  ```

  `app/views/scanner/measurements/replays/show.html.erb`:

  ```erb
  <% content_for :title, "Replay #{@label} · Collector" %>
  <%= render "scanners/head" %>
  <main class="c-main" data-controller="replay" data-replay-engine-path-value="<%= ocr_engine_path %>" data-replay-label-value="<%= @label %>"
        data-replay-files-value="<%= @files.to_json %>" data-replay-strip-url-value="<%= scanner_measurement_strip_path("FILE") %>"
        data-replay-results-url-value="<%= scanner_measurement_replay_path %>">
    <div class="c-pagehead"><div><h1 class="c-pagehead__title">Replaying <%= pluralize(@files.size, "capture") %> as <%= @label %></h1></div></div>
    <p class="c-scanner__status" role="status" aria-live="polite" data-replay-target="status">Starting…</p>
  </main>
  ```
- [ ] Implement `app/javascript/controllers/measurement_controller.js`:

  ```js
  import { Controller } from "@hotwired/stimulus"
  import { Turbo } from "@hotwired/turbo-rails"

  // Measurement mode (spec 007 Story 5, development only): stores each capture's text and strip images against
  // the manifest row chosen before the shutter, then shows the next row. A capture counts only once stored.
  export default class extends Controller {
    static targets = [ "row", "status", "retry" ]
    static values = { capturesUrl: String }

    async store({ detail: { nameText, collectorText, ms, strips } }) {
      const body = new FormData()
      body.append("capture[file]", this.rowTarget.value)
      body.append("capture[name_text]", nameText)
      body.append("capture[collector_text]", collectorText)
      body.append("capture[ms]", String(ms))
      body.append("capture[user_agent]", navigator.userAgent)
      body.append("capture[name_strip]", await png(strips.name), "name.png")
      body.append("capture[collector_strip]", await png(strips.collector), "collector.png")
      this.pending = body
      await this.post()
    }

    retry() {
      if (this.pending) this.post()
    }

    async post() {
      this.retryTarget.hidden = true
      try {
        const response = await fetch(this.capturesUrlValue, { method: "POST", body: this.pending,
          headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content } })
        if (!response.ok && response.status !== 422) throw new Error(`HTTP ${response.status}`)
        Turbo.renderStreamMessage(await response.text())
      } catch {
        this.statusTarget.textContent = "The capture wasn't stored, so it doesn't count yet. Store it again."
        this.statusTarget.hidden = false
        this.retryTarget.hidden = false
      }
    }
  }

  function png(canvas) {
    return new Promise((resolve) => canvas.toBlob(resolve, "image/png"))
  }
  ```

  Implement `app/javascript/controllers/replay_controller.js`:

  ```js
  import { Controller } from "@hotwired/stimulus"
  import { readStrips } from "scanner/recognition"

  // Replays a measured run's stored strips through the page's own recognition code (spec 007 AC-5.6), then
  // stores what it read. script/scanner/replay.rb drives it in headless Firefox and waits on window.__replay.
  export default class extends Controller {
    static targets = [ "status" ]
    static values = { enginePath: String, files: Array, stripUrl: String, resultsUrl: String, label: String }

    async connect() {
      window.__replay = { done: false, error: null, count: 0 }
      try {
        const results = []
        for (const file of this.filesValue) {
          const strips = { name: await this.strip(file, "name"), collector: await this.strip(file, "collector") }
          const { nameText, collectorText } = await readStrips(this.enginePathValue, strips)
          results.push({ file, name_text: nameText, collector_text: collectorText })
          window.__replay.count = results.length
          this.statusTarget.textContent = `Read ${results.length} of ${this.filesValue.length}`
        }
        const response = await fetch(this.resultsUrlValue, { method: "POST", body: JSON.stringify({ label: this.labelValue, results }),
          headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content } })
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        this.statusTarget.textContent = `Stored ${results.length} replayed captures as ${this.labelValue}`
      } catch (error) {
        window.__replay.error = String(error)
        this.statusTarget.textContent = `The replay failed: ${error}`
      } finally {
        window.__replay.done = true
      }
    }

    async strip(file, name) {
      const response = await fetch(`${this.stripUrlValue.replace("FILE", encodeURIComponent(file))}?strip=${name}`)
      if (!response.ok) throw new Error(`${file} ${name}: HTTP ${response.status}`)
      const image = await createImageBitmap(await response.blob())
      const canvas = Object.assign(document.createElement("canvas"), { width: image.width, height: image.height })
      canvas.getContext("2d").drawImage(image, 0, 0)
      return canvas
    }
  }
  ```

  Write `script/scanner/replay.rb`:

  ```ruby
  # Replays a measured run's stored strips through the scanner's recognition code in headless Firefox
  # (spec 007 AC-5.6). Needs this checkout's dev server running (measurement mode is on in development).
  # Usage: bundle exec ruby script/scanner/replay.rb <label>
  require "bundler/setup"
  require "selenium-webdriver"
  require_relative "../../lib/collector/dev_port"

  label = ARGV.fetch(0) { abort "usage: bundle exec ruby script/scanner/replay.rb <label>" }
  port = Collector::DevPort.resolve(root: File.expand_path("../..", __dir__))
  driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
  begin
    driver.navigate.to("http://127.0.0.1:#{port}/scanner/measurement/replay?label=#{label}")
    Selenium::WebDriver::Wait.new(timeout: 1800, interval: 2).until { driver.execute_script("return Boolean(window.__replay && window.__replay.done)") }
    replay = driver.execute_script("return window.__replay")
    abort "The replay failed: #{replay["error"]}" if replay["error"]
    puts "Replayed #{replay["count"]} captures as #{label}"
  ensure
    driver.quit
  end
  ```
- [ ] Run: `bin/rspec spec/models/scanner spec/requests/scanner/measurements_spec.rb spec/routing/routes_spec.rb`. Expect: 0 failures.
- [ ] Run: `bin/brakeman --quiet --no-pager --exit-on-warn`. `Scanner::Measurements::StripsController#show` has the same `send_file` shape as the engine controller. Its path is allowlist-derived: a manifest row matching `FILE_NAME`, plus `STRIPS.include?`. If Brakeman flags it, add it to `config/brakeman.ignore` with that note.
- [ ] Write `spec/system/scanner_measurement_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe "Scanner measurement mode", type: :system do
    let(:corpus) { Pathname(Dir.mktmpdir("corpus")) }

    around do |example|
      corpus.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,mom,123,no\n")
      Rails.configuration.x.scanner_measurement = { manifest: corpus.join("manifest.csv").to_s, dir: corpus.join("runs/live").to_s }
      example.run
    ensure
      Rails.configuration.x.scanner_measurement = nil
      FileUtils.remove_entry(corpus)
    end

    it "stores a capture against the card chosen before the shutter (AC-5.2, AC-5.3)", :aggregate_failures do
      identity = create(:catalog_identity, name: "Lightning Bolt")
      create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123"))
      Catalog::NameIndex.new("mtg").rebuild
      system_sign_in_as(create(:user))
      visit scanner_measurement_path
      expect(page).to have_select("Card to capture", selected: "IMG_1.jpeg · MOM 123 (pending)")
      show_synthetic_card
      click_on "Capture"
      expect(page).to have_text("Stored IMG_1.jpeg as the measured capture", wait: 30)
      expect(corpus.join("runs/live/IMG_1.jpeg/capture-001-collector.png")).to exist
    end
  end
  ```
- [ ] Run: `bin/rspec spec/system/scanner_measurement_spec.rb`. Expect: 1 example, 0 failures.
- [ ] Commit: `feat(scanner): add development-only measurement mode with captures, skips and desktop replay`

---
## Phase 8: Findings tooling and Phase 0 re-scored

**Implements:** Story 6 (tooling), NFR Performance (measurement) | **Satisfies:** AC-6.2, AC-6.3, AC-6.4, AC-6.5, AC-6.6 (tooling; the numbers come in Phases 10–11)
**Files:** `lib/collector/scanner_findings.rb`, `lib/collector/scanner_findings/report.rb`, `lib/collector/request_log.rb`, `lib/tasks/scanner.rake`, `config/environments/development.rb`, `spec/lib/collector/scanner_findings_spec.rb`, `spec/lib/collector/scanner_findings/report_spec.rb`, `spec/lib/collector/request_log_spec.rb`
**Interfaces:** Consumes: `MTG::Reading`, `Scanner::MeasurementRun`, and `spec/fixtures/card_scanner/{ground_truth,ocr_results,name_matches}.json`. Produces:
- `Collector::ScannerFindings` (`Rate`, `breakdown`, `comparison`, `percentile`, `name_read?`, `printing_identified?`, `in_top?`, `phase0`, `rescore`, `ground_truth`).
- `Collector::ScannerFindings::Report.new(run:, ground_truth:, output:)`, with `#to_markdown` and `#write_fixtures!`.
- `Collector::RequestLog`.
- The tasks `bin/rails scanner:findings` (`FIXTURES=1`, `GROUND_TRUTH=`) and `bin/rails "scanner:ground_truth[manifest]"`.

Spec 005's scoring is ported into the app so every rate is computed the same way for three sources: Phase 0, Phase 0's text with Phase 1's matcher, and the live run. The Phase 0 re-score needs no maintainer input, so it runs now.

- [ ] Write `spec/lib/collector/scanner_findings_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe Collector::ScannerFindings do
    let(:records) do
      [ { "era" => "MOM+", "foil" => true, "borderless_or_showcase" => false, "hit" => true },
        { "era" => "MOM+", "foil" => false, "borderless_or_showcase" => true, "hit" => false },
        { "era" => "pre-M15", "foil" => false, "borderless_or_showcase" => false, "hit" => true } ]
    end

    it "rates every grouping with its sample size", :aggregate_failures do
      rates = described_class.breakdown(records) { it["hit"] }
      expect(rates["overall"]["all"].to_s).to eq("2/3 (66.7%)")
      expect(rates["era"].transform_values(&:to_s)).to eq("MOM+" => "1/2 (50.0%)", "pre-M15" => "1/1 (100.0%)")
      expect(rates["frame treatment"]["borderless/showcase"].to_s).to eq("0/1 (0.0%)")
    end

    it "compares sources column by column, with a dash where a source has no such group", :aggregate_failures do
      table = described_class.comparison("Hit", "A" => records, "B" => records.first(1)) { it["hit"] }
      expect(table.lines.first.strip).to eq("| Hit | Group | A | B |")
      expect(table).to include("| era | pre-M15 | 1/1 (100.0%) | — |")
    end

    it "scores reads, printings and rankings the way spec 005 did", :aggregate_failures do
      record = { "name_text" => "FIRE\n", "name_bar" => "Fire", "name" => "Fire // Ice", "external_key" => "abc",
                 "lookup" => { "status" => "one", "external_keys" => [ "abc" ] }, "name_candidates" => [ "Fireball", "Fire // Ice" ] }
      expect(described_class.name_read?(record)).to be(true)
      expect(described_class.name_read?(record, against: "name")).to be(false)
      expect(described_class.printing_identified?(record)).to be(true)
      expect([ described_class.in_top?(record, "name_candidates", 1), described_class.in_top?(record, "name_candidates", 3) ]).to eq([ false, true ])
      expect(described_class.percentile([ 5, 1, 3, 2, 4 ], 95)).to eq(5)
    end

    describe "with a catalog" do
      let(:entry) do
        identity = create(:catalog_identity, name: "Lightning Bolt")
        create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123")).entry
      end

      before { entry && Catalog::NameIndex.new("mtg").rebuild }

      it "re-reads any run's text through Phase 1's matcher, keeping both rankings (AC-6.3)" do
        record = described_class.rescore({ "IMG_1.jpeg" => { "name" => "Lightning Bolt" } },
          [ { "file" => "IMG_1.jpeg", "name_text" => "Lightnlng Bolt", "collector_text" => "R 0123\nMOM • EN", "ms" => 640 } ]).sole
        expect(record).to include("ms" => 640, "lookup" => { "status" => "one", "external_keys" => [ entry.external_key ] },
          "name_candidates" => [ "Lightning Bolt" ], "final_candidates" => [ "Lightning Bolt" ])
      end

      it "builds ground truth for a tuning manifest (AC-6.1)", :aggregate_failures do
        truth = described_class.ground_truth("file,set,number,foil\nIMG_1.jpeg,mom,123,yes\nIMG_2.jpeg,mom,999,no\n")
        expect(truth["photos"].sole).to include("file" => "IMG_1.jpeg", "name" => "Lightning Bolt", "name_bar" => "Lightning Bolt", "foil" => true, "era" => "M15–ONE")
        expect(truth["errors"].sole).to include("file" => "IMG_2.jpeg", "problem" => "none")
      end
    end
  end
  ```

  The factory set is released on 2020-01-01, which falls in the M15–ONE era.
- [ ] Write `spec/lib/collector/scanner_findings/report_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe Collector::ScannerFindings::Report do
    let(:dir) { Pathname(Dir.mktmpdir("findings")) }
    let(:run) { Scanner::MeasurementRun.new(manifest: dir.join("manifest.csv"), dir: dir.join("run")) }
    let(:report) { described_class.new(run:, output: dir) }

    before do
      dir.join("manifest.csv").write("file,set,number,foil\nIMG_6688.jpeg,fra,391,no\nIMG_6689.jpeg,afc,1,yes\n")
      strip = -> { StringIO.new("\x89PNG\r\n\x1A\n".b) }
      run.record!(run.row("IMG_6688.jpeg"), name_text: "Nothing useful", collector_text: "", ms: 640, user_agent: "iPhone", name_strip: strip.call, collector_strip: strip.call)
      run.skip!(run.row("IMG_6689.jpeg"))
    end

    after { FileUtils.remove_entry(dir) }

    it "reports every rate for Phase 0, Phase 0's text with Phase 1's matcher, and the live run (AC-6.2, AC-6.3)", :aggregate_failures do
      markdown = report.to_markdown
      expect(markdown).to include("| Top 3, name only | Group | Phase 0 | Phase 0 text, Phase 1 matcher | Phase 1 live |")
      expect(markdown).to include("| Top 3, final ranking | Group | Phase 0 text, Phase 1 matcher | Phase 1 live |")
      expect(markdown).to include("| overall | all | 26/50 (52.0%) |", "Exact printing (M15–ONE, MOM+)")
    end

    it "lists misses, timings, skipped rows and retakes (AC-6.4, AC-6.5)", :aggregate_failures do
      expect(report.to_markdown).to include("| IMG_6688.jpeg |", "median 640 ms", "skipped: IMG_6689.jpeg", "retakes: 0")
    end

    it "writes the live run as text-only fixtures (AC-6.6)", :aggregate_failures do
      report.write_fixtures!
      results = JSON.parse(dir.join("phase1_ocr_results.json").read)
      expect(results).to include("format_version" => 2, "run" => "live")
      expect(results["results"].sole.keys).to contain_exactly("file", "name_text", "collector_text", "ms", "user_agent", "captured_at", "parsed", "lookup")
      expect(JSON.parse(dir.join("phase1_name_matches.json").read)["matches"].sole.keys).to include("name_candidates", "final_candidates")
    end
  end
  ```

  The "26/50" row is Phase 0's committed top 3 (research.md §3), recomputed from its fixtures. It checks that the port matches spec 005's numbers.
- [ ] Write `spec/lib/collector/request_log_spec.rb`:

  ```ruby
  require "rails_helper"

  RSpec.describe Collector::RequestLog do
    let(:path) { Pathname(Dir.mktmpdir("log")).join("requests.jsonl") }
    let(:middleware) { described_class.new(->(_env) { [ 200, {}, [ "ab", "cde" ] ] }, path:) }

    after { FileUtils.remove_entry(path.dirname) }

    it "logs each response's size once the body is sent", :aggregate_failures do
      _status, _headers, body = middleware.call(Rack::MockRequest.env_for("/ocr/v7.0.0/tesseract.min.js", "HTTP_USER_AGENT" => "iPhone"))
      body.each { nil }
      body.close
      expect(JSON.parse(path.read)).to include("path" => "/ocr/v7.0.0/tesseract.min.js", "status" => 200, "bytes" => 5, "user_agent" => "iPhone")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/lib/collector/scanner_findings_spec.rb spec/lib/collector/scanner_findings spec/lib/collector/request_log_spec.rb`. Expect: FAIL (uninitialized constants).
- [ ] Implement `lib/collector/scanner_findings.rb`:

  ```ruby
  module Collector
    # Scores card scanner runs for spec 007's findings (AC-6.2–AC-6.6) with spec 005's definitions (research.md
    # §3 and §5): every rate overall, per era, foil and frame treatment, with its sample size. A record is one
    # card's ground truth (ground_truth.json's fields) merged with what a run read and ranked.
    module ScannerFindings
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
      SET_LINE_ERAS = [ "M15–ONE", "MOM+" ].freeze
      LOOKUP_STATUSES = { one: "one", several: "ambiguous", none: "none", unread: "none" }.freeze
      M15_RELEASE = Date.new(2014, 7, 18)
      MOM_RELEASE = Date.new(2023, 4, 21)

      module_function

      def breakdown(records, &hit)
        GROUPINGS.to_h do |label, key|
          [ label, records.group_by(&key).sort_by(&:first).to_h { |value, rows| [ value, Rate.new(hits: rows.count(&hit), total: rows.size) ] } ]
        end
      end

      # One Markdown table with a column per source ({ "Phase 0" => records, … }) and a row per group.
      def comparison(title, sources, &hit)
        columns = sources.transform_values { breakdown(it, &hit) }
        groups = columns.values.flat_map { |rates| rates.flat_map { |label, values| values.keys.map { [ label, it ] } } }.uniq
        rows = groups.map { |label, value| "| #{label} | #{value} | #{columns.values.map { it.dig(label, value) || "—" }.join(" | ")} |" }
        [ "| #{title} | Group | #{columns.keys.join(" | ")} |", "|---|---|#{"---|" * columns.size}", *rows ].join("\n")
      end

      def percentile(values, percent)
        return nil if values.empty?

        sorted = values.sort
        sorted[((percent / 100.0) * (sorted.size - 1)).round]
      end

      def name_read?(record, against: "name_bar") = Catalog::NameKey.call(record["name_text"]) == Catalog::NameKey.call(record[against])

      def printing_identified?(record)
        record.dig("lookup", "status") == "one" && record.dig("lookup", "external_keys") == [ record["external_key"] ]
      end

      def in_top?(record, ranking, count) = Array(record[ranking]).first(count).include?(record["name"])

      # Phase 0's committed fixtures as records: its OCR text, its lookup and its name-only ranking.
      def phase0(truth, ocr_results, name_matches)
        matches = name_matches.fetch("matches").to_h { [ it["file"], it ] }
        ocr_results.fetch("results").filter_map do |result|
          truth[result["file"]]&.merge(result.slice("file", "name_text", "collector_text", "lookup"),
            "name_candidates" => matches.dig(result["file"], "candidates").to_a.map { it["card_name"] })
        end
      end

      # Any run's text read again through MTG::Reading: the parsed line, the lookup, both rankings and the time
      # the lookup took on this machine.
      def rescore(truth, results)
        results.filter_map do |result|
          next unless truth.key?(result["file"])

          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          reading = MTG::Reading.new(name_text: result["name_text"].to_s, collector_text: result["collector_text"].to_s).resolve
          lookup_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
          truth[result["file"]].merge(result.slice("file", "name_text", "collector_text", "ms", "user_agent", "captured_at"),
            "parsed" => reading.collector_line.to_h.to_h { |key, value| [ key.to_s, value.is_a?(Symbol) ? value.to_s : value ] },
            "lookup" => { "status" => LOOKUP_STATUSES.fetch(reading.collector_status), "external_keys" => reading.collector_entries.map(&:external_key) },
            "lookup_ms" => lookup_ms, "name_candidates" => identity_names(reading.name_candidates.map(&:identity_id)),
            "final_candidates" => reading.candidates.map { it.entry.name })
        end
      end

      def identity_names(ids)
        names = Catalog::Identity.where(id: ids).pluck(:id, :name).to_h
        ids.map { names.fetch(it) }
      end

      # Ground truth for a manifest the committed ground_truth.json doesn't cover (a tuning run, AC-6.1), built
      # as spec 005 built it. The manifest has no quoted or comma-bearing values, so a split is enough.
      def ground_truth(manifest_text)
        header, *lines = manifest_text.lines.map(&:strip).reject(&:empty?)
        keys = header.split(",").map(&:strip)
        lines.map { keys.zip(it.split(",", -1).map(&:strip)).to_h }.each_with_object({ "photos" => [], "errors" => [] }) do |row, truth|
          entries = Catalog::Entry.where(collectible_type: "mtg").includes(:set)
            .printed_as(set_code: row["set"], number: row["number"], language: "en").to_a
          next truth["errors"] << row.merge("problem" => entries.empty? ? "none" : "ambiguous") unless entries.one?

          truth["photos"] << truth_record(row, entries.first)
        end
      end

      def truth_record(row, entry)
        printing = MTG::Printing.find_by!(catalog_entry_id: entry.id)
        { "file" => row["file"], "name" => entry.name, "name_bar" => printing.faces.first.fetch("name"), "set_code" => entry.set.code,
          "collector_number" => entry.number, "external_key" => entry.external_key,
          "era" => row["era"].presence || era_for(entry.released_on || entry.set.released_on), "foil" => row["foil"].to_s.casecmp?("yes"),
          "borderless_or_showcase" => printing.border_color == "borderless" || printing.variant_tags.include?("showcase") }
      end

      def era_for(released_on)
        if released_on < M15_RELEASE then "pre-M15"
        elsif released_on < MOM_RELEASE then "M15–ONE"
        else "MOM+"
        end
      end
    end
  end
  ```
- [ ] Implement `lib/collector/scanner_findings/report.rb`:

  ```ruby
  # The Markdown for spec 007's findings (AC-6.2–AC-6.5): each rate for Phase 0, Phase 0's text through Phase 1's
  # matcher, and the live run; then the live run's misses, timings, coverage and replay differences.
  class Collector::ScannerFindings::Report
    FIXTURES = Rails.root.join("spec/fixtures/card_scanner")

    def initialize(run:, ground_truth: FIXTURES.join("ground_truth.json"), output: FIXTURES)
      @run = run
      @truth = JSON.parse(Pathname(ground_truth).expand_path.read).fetch("photos").to_h { [ it["file"], it ] }
      @output = Pathname(output)
    end

    def to_markdown = [ rates, misses, timings, coverage, replays ].join("\n\n")

    # The live run as text-only fixtures beside Phase 0's, keyed by manifest file (AC-6.6).
    def write_fixtures!
      @output.join("phase1_ocr_results.json").write(JSON.pretty_generate("format_version" => 2, "run" => "live",
        "results" => live.map { it.slice("file", "name_text", "collector_text", "ms", "user_agent", "captured_at", "parsed", "lookup") }))
      @output.join("phase1_name_matches.json").write(JSON.pretty_generate("format_version" => 2, "run" => "live",
        "matches" => live.map { it.slice("file", "lookup_ms", "name_candidates", "final_candidates").merge("query" => it["name_text"]) }))
    end

    private
      def findings = Collector::ScannerFindings

      def fixture(name) = JSON.parse(FIXTURES.join(name).read)

      def live = @live ||= findings.rescore(@truth, @run.measured_captures)

      def sources
        @sources ||= { "Phase 0" => findings.phase0(@truth, fixture("ocr_results.json"), fixture("name_matches.json")),
                       "Phase 0 text, Phase 1 matcher" => findings.rescore(@truth, fixture("ocr_results.json").fetch("results")),
                       "Phase 1 live" => live }
      end

      def rates
        set_line = sources.transform_values { |records| records.select { findings::SET_LINE_ERAS.include?(it["era"]) } }
        ranked = sources.except("Phase 0") # Phase 0 had no final ranking
        [ findings.comparison("Name read (front face)", sources) { findings.name_read?(it) },
          findings.comparison("Name read (catalog name)", sources) { findings.name_read?(it, against: "name") },
          findings.comparison("Top 1, name only", sources) { findings.in_top?(it, "name_candidates", 1) },
          findings.comparison("Top 3, name only", sources) { findings.in_top?(it, "name_candidates", 3) },
          findings.comparison("Top 1, final ranking", ranked) { findings.in_top?(it, "final_candidates", 1) },
          findings.comparison("Top 3, final ranking", ranked) { findings.in_top?(it, "final_candidates", 3) },
          findings.comparison("Exact printing (M15–ONE, MOM+)", set_line) { findings.printing_identified?(it) },
          "Lookup outcomes (M15–ONE, MOM+): " + set_line.map { |label, records| "#{label} #{records.map { it.dig("lookup", "status") }.tally}" }.join("; ")
        ].join("\n\n")
      end

      def misses
        rows = live.reject { findings.in_top?(it, "final_candidates", 3) }.map do |record|
          "| #{record["file"]} | #{cell(record["name"])} | #{cell(record["name_text"])} | #{cell(record["collector_text"])} | #{cell(record["final_candidates"].join("; "))} | |"
        end
        [ "Not in the top 3 (live run, final ranking): #{rows.size} of #{live.size}", "",
          "| File | Expected | Name strip | Collector strip | Top 3 | Likely cause |", "|---|---|---|---|---|---|", *rows ].join("\n")
      end

      def timings
        ms = live.filter_map { it["ms"] }
        lookups = live.map { it["lookup_ms"] }
        "Recognition on the device: median #{findings.percentile(ms, 50)} ms, slowest #{ms.max} ms (n=#{ms.size}). " \
          "Candidate lookup on this machine: median #{findings.percentile(lookups, 50)} ms, p95 #{findings.percentile(lookups, 95)} ms (n=#{lookups.size}). " \
          "Devices: #{live.map { it["user_agent"] }.tally.map { |agent, count| "#{agent} (#{count})" }.join("; ")}."
      end

      def coverage
        files = ->(status) { @run.rows.select { @run.status(it) == status }.map(&:file).join(", ").presence || "none" }
        "Captured #{live.size} of #{@run.rows.size}; skipped: #{files.call(:skipped)}; not captured: #{files.call(:pending)}; retakes: #{@run.retakes}."
      end

      def replays
        device = @run.measured_captures.to_h { [ it["file"], it ] }
        sections = @run.replays.map do |label, results|
          diffs = results.flat_map do |result|
            %w[name_text collector_text].filter_map do |field|
              on_device = device.dig(result["file"], field)
              "- #{result["file"]} #{field}: #{on_device.inspect} on the device, #{result[field].inspect} replayed" if on_device != result[field]
            end
          end
          [ "Replay #{label}: #{diffs.map { it.split[1] }.uniq.size} of #{results.size} captures differ from the device's text", *diffs ].join("\n")
        end
        sections.join("\n\n").presence || "No replays yet."
      end

      def cell(text) = text.to_s.gsub("|", "\\|").tr("\n", " ")
  end
  ```
- [ ] Implement `lib/collector/request_log.rb`:

  ```ruby
  require "json"

  module Collector
    # Development-only log of each response's size, for the scanner's cold and warm iPhone loads (spec 007 AC-6.5),
    # as spec 005's spike server logged them: one JSON line per response once its body has been sent.
    class RequestLog
      def initialize(app, path:)
        @app = app
        @path = path
      end

      def call(env)
        status, headers, body = @app.call(env)
        request = Rack::Request.new(env)
        [ status, headers, CountingBody.new(body) { |bytes| log(request, status, bytes) } ]
      end

      private
        def log(request, status, bytes)
          File.open(@path, "a") do |file|
            file.puts(JSON.generate(at: Time.now.utc.iso8601(3), method: request.request_method, path: request.path,
              status:, bytes:, user_agent: request.user_agent))
          end
        end

      class CountingBody
        def initialize(body, &on_close)
          @body = body
          @on_close = on_close
          @bytes = 0
        end

        def each
          @body.each do |chunk|
            @bytes += chunk.bytesize
            yield chunk
          end
        end

        def close
          @body.close if @body.respond_to?(:close)
          @on_close.call(@bytes)
        end
      end
    end
  end
  ```

  In `config/environments/development.rb`, add `require_relative "../../lib/collector/request_log"` after the first `require` line, and add inside the block:

  ```ruby
    # Response sizes for the scanner's on-device load measurements (spec 007 AC-6.5): COLLECTOR_REQUEST_LOG=1
    # writes one JSON line per response to log/requests.jsonl.
    config.middleware.insert_before 0, Collector::RequestLog, path: Rails.root.join("log/requests.jsonl") if ENV["COLLECTOR_REQUEST_LOG"] == "1"
  ```
- [ ] Add `lib/tasks/scanner.rake`:

  ```ruby
  namespace :scanner do
    desc 'Build ground truth for a tuning manifest the committed fixture doesn\'t cover: bin/rails "scanner:ground_truth[path/to/manifest.csv]"'
    task :ground_truth, [ :manifest ] => :environment do |_task, args|
      manifest = Pathname(args.fetch(:manifest)).expand_path
      truth = Collector::ScannerFindings.ground_truth(manifest.read)
      manifest.dirname.join("ground_truth.json").write(JSON.pretty_generate(truth))
      puts "#{truth["photos"].size} rows resolved, #{truth["errors"].size} errors -> #{manifest.dirname.join("ground_truth.json")}"
      truth["errors"].each { puts "  #{it}" }
    end

    desc "Score the measurement run against Phase 0 (spec 007 Story 6). FIXTURES=1 writes the text fixtures; GROUND_TRUTH=path for a tuning run"
    task findings: :environment do
      run = Scanner::MeasurementRun.current
      abort "Measurement mode is off; run this in development." unless run
      report = Collector::ScannerFindings::Report.new(run:, **{ ground_truth: ENV["GROUND_TRUTH"] }.compact)
      puts report.to_markdown
      report.write_fixtures! if ENV["FIXTURES"] == "1"
    end
  end
  ```
- [ ] Run: `bin/rspec spec/lib/collector/scanner_findings_spec.rb spec/lib/collector/scanner_findings spec/lib/collector/request_log_spec.rb`. Expect: 0 failures. The "26/50 (52.0%)" check confirms the port reproduces spec 005's top-3 rate from its fixtures.
- [ ] Commit: `feat(scanner): score measurement runs against Phase 0 and log response sizes in development`
- [ ] Fill this worktree's catalog: start `bin/dev` (Solid Queue runs inside Puma) and run `bin/rails "catalog:refresh[mtg]"`. Then check `bin/rails "catalog:status[mtg]"` until it shows `applied`, which takes about 60 s. Check `bin/rails runner 'p Catalog::Name.where(collectible_type: "mtg").count'` is about 36,000.
- [ ] Re-score Phase 0 now (AC-6.3, no maintainer input needed): `COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/empty bin/rails scanner:findings > tmp/phase0-rescored.md`. Expect: the "Phase 0" column matches research.md §3 (for example, top 3 name only `26/50 (52.0%)` and exact printing `7/45 (15.6%)`), and the "Phase 0 text, Phase 1 matcher" column is filled. Copy the tables into the draft `docs/specs/007-card-scanner-live-capture/research.md` under "Phase 0's text with Phase 1's matcher" (Phase 11 completes the document).
- [ ] Commit: `docs(spec): record Phase 0's text re-scored with Phase 1's matcher`

---
## Phase 9: HTTPS from a phone, and documentation

**Implements:** Story 7 | **Satisfies:** AC-7.1, AC-7.2 (AC-7.3 documented)
**Files:** `config/environments/development.rb`, `README.md`, `spec/readme_spec.rb`, `CLAUDE.md`
**Interfaces:** Consumes: everything above. Produces: `COLLECTOR_HTTPS` honoured in development, alongside Rails' `RAILS_DEVELOPMENT_HOSTS`, and the documentation that Phases 10 and 11 follow.

The maintainer uses their own HTTPS tunnel, so the app only has to accept the tunnel's host name and trust that the request arrived over HTTPS. The README covers that, plus HTTPS for self-hosters on both deployment paths and the engine fetch.

- [ ] Add to `spec/readme_spec.rb`:

  ```ruby
    it "documents the card scanner's HTTPS needs for phones, Compose and Kamal (spec 007 AC-7.1, AC-7.2, AC-7.3)", :aggregate_failures do
      expect(readme).to include("RAILS_DEVELOPMENT_HOSTS", "bin/fetch-ocr-engine", "COLLECTOR_SCANNER_MANIFEST", "COLLECTOR_REQUEST_LOG")
      scanner = readme[/^### Card scanner\n.*?(?=^##)/m].to_s
      expect(scanner).to include("HTTPS", "only the photo picker works", "Docker Compose", "Kamal", "ssl: true", "registry.npmjs.org")
    end
  ```
- [ ] Run: `bin/rspec spec/readme_spec.rb`. Expect: FAIL.
- [ ] In `config/environments/development.rb`, add before the final `end`:

  ```ruby
    # Reaching the dev server from a phone through your own HTTPS tunnel (spec 007 AC-7.1): Rails' own
    # RAILS_DEVELOPMENT_HOSTS names the tunnel's hosts, and COLLECTOR_HTTPS=true (as in production) says the tunnel
    # ends TLS, so Rails treats requests as HTTPS and their Origin matches.
    config.assume_ssl = ENV["COLLECTOR_HTTPS"] == "true"
  ```
- [ ] In `README.md`, add after the `### Worktrees` section's last bullet:

  ````markdown
  ### Card scanner on a phone

  `bin/setup` also runs `bin/fetch-ocr-engine`, which downloads the card scanner's OCR engine (about 15 MB) from
  `registry.npmjs.org`, checks every file against a pinned SHA-256 and keeps it in `vendor/ocr/` (ignored by git).

  The scanner is at `/scanner`; nothing links to it yet. Browsers only allow a live camera on HTTPS (or on
  `localhost`), so to use it from a phone, put an HTTPS tunnel of your choice in front of the dev server and tell
  the app about it. For example, with Tailscale:

  ```sh
  tailscale serve --bg 3000                                       # your worktree's port; prints https://<machine>.<tailnet>.ts.net
  RAILS_DEVELOPMENT_HOSTS=<machine>.<tailnet>.ts.net COLLECTOR_HTTPS=true bin/dev
  ```

  - `RAILS_DEVELOPMENT_HOSTS`: the tunnel's host names, comma-separated, so Rails accepts requests for them.
  - `COLLECTOR_HTTPS=true`: the tunnel ended TLS, so Rails treats the request as HTTPS (cookies, form checks).
  - No certificate or key goes in the repository. Over plain HTTP from another device, the page offers a photo instead.

  **Measurement mode** (development only) records live captures of known cards for the scanner's findings, at
  `/scanner/measurement`. It reads the manifest at `COLLECTOR_SCANNER_MANIFEST` (default
  `~/card-scanner-corpus/manifest.csv`, columns `file,set,number,foil[,era]`) and stores each capture's text and
  strip images under `COLLECTOR_SCANNER_RUN_DIR` (default `~/card-scanner-corpus/runs/live`), outside the
  repository. `bin/rails scanner:findings` scores a run; `bundle exec ruby script/scanner/replay.rb <label>`
  re-reads its strips on the desktop. `COLLECTOR_REQUEST_LOG=1` logs each response's size to `log/requests.jsonl`.
  ````

  Add after the `### Kamal` section:

  ```markdown
  ### Card scanner

  The card scanner (`/scanner`, not linked yet while it's being measured) reads a card with the camera of the phone
  it runs on. Photos never leave the phone: only the text read from the card is sent to your instance. The image
  build downloads the scanner's OCR engine from `registry.npmjs.org` and checks each file against a pinned
  SHA-256; your instance serves it from `/ocr/v7.0.0/`, so phones fetch it from you, not from a third party.

  Browsers only allow a live camera on HTTPS. Without HTTPS, only the photo picker works.

  - **Docker Compose:** put an HTTPS reverse proxy in front of the app (see HTTPS above) and set `COLLECTOR_HTTPS=true`.
  - **Kamal:** enable the proxy's certificate in `config/deploy.yml` (`proxy:` with `ssl: true` and your `host:`),
    and set `COLLECTOR_HTTPS: true` under `env: clear:`.
  ```

  In `CLAUDE.md`, add to "Non-obvious Facts":

  ```markdown
  - **Card scanner (spec 007):** `/scanner`, unlinked. Its OCR engine is fetched and checksum-verified into the ignored `vendor/ocr/v7.0.0/` by `bin/fetch-ocr-engine` (run by `bin/setup` and the Dockerfile) and served by `OcrAssetsController`; scanner specs fail until it's installed. Only scanner pages send a Content-Security-Policy (`ScannerPage` concern); nonces exist only on those requests. Measurement mode (`/scanner/measurement`) is development-only (`config.x.scanner_measurement`; `COLLECTOR_SCANNER_MANIFEST`, `COLLECTOR_SCANNER_RUN_DIR`) and writes outside the repo. Phones need HTTPS: `RAILS_DEVELOPMENT_HOSTS` + `COLLECTOR_HTTPS=true` behind a tunnel.
  ```
- [ ] Run: `bin/rspec spec/readme_spec.rb`. Expect: 0 failures.
- [ ] Commit: `docs: explain the card scanner's HTTPS needs, engine fetch and measurement mode`

---

## Phase 10: Tuning on cards outside the corpus

**Implements:** AC-6.1 | **Satisfies:** AC-6.1, AC-7.1 (verified on the device)
**Files:** `app/javascript/scanner/geometry.js` (`STRIPS`, `GUIDE`), `app/javascript/scanner/recognition.js` (`SETTINGS`), and, only if a round shows a matcher problem, `app/models/catalog/name_index.rb` constants
**Interfaces:** Consumes: measurement mode and `scanner:findings`. Produces: the settings commit that the findings name.

Before the measured run, the strip boxes, page segmentation and matcher constants are tuned only on cards the corpus doesn't contain. Then they're committed and frozen.

- [ ] **Checkpoint (maintainer):** this needs, all asked for at the start of execution:
  - the certificate is trusted on the iPhone (`bin/dev-certificate`, then the README's phone steps);
  - 10 or more English cards that are **not** among the 50 corpus cards, covering pre-M15, M15–ONE and MOM+, with at least 2 foils, listed in `~/card-scanner-corpus/tuning/manifest.csv` (`file,set,number,foil`, where `file` is any unique name such as `T01`).
- [ ] Build their ground truth: `bin/rails "scanner:ground_truth[$HOME/card-scanner-corpus/tuning/manifest.csv]"`. Expect: every row resolves. Confirm any error with the maintainer, fix the manifest, and record a `Ruling:` in the round's commit.
- [ ] Start the dev server over HTTPS with the tuning run, as a background task (memory: background servers via task): run `bin/dev-certificate`, then `COLLECTOR_REQUEST_LOG=1 COLLECTOR_SCANNER_MANIFEST=$HOME/card-scanner-corpus/tuning/manifest.csv COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/tuning-1 bin/dev -b "ssl://0.0.0.0:3578?key=$HOME/.local/share/collector-dev-https/dev.key&cert=$HOME/.local/share/collector-dev-https/dev.crt"`.
- [ ] **Checkpoint (maintainer):**
  - On the iPhone, open `https://192.168.1.76:3578/scanner/measurement` and capture each tuning card once.
  - Report the manual device checks: the rear camera opened (AC-1.1); the camera indicator went off after leaving the page (AC-1.4); the torch lit, or wasn't offered (AC-1.5); `http://<LAN IP>:<port>/scanner` (server bound with `-b 0.0.0.0`) explained the HTTPS need and offered a photo (AC-1.6); and a portrait iPhone photo of a tuning card, picked with **Use a photo**, was read upright, so its orientation metadata was applied (AC-4.2; the synthetic test image has none).
  - That the self-signed HTTPS procedure worked as the README describes (AC-7.1).
- [ ] Score the round: `COLLECTOR_SCANNER_MANIFEST=$HOME/card-scanner-corpus/tuning/manifest.csv COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/tuning-1 GROUND_TRUTH=$HOME/card-scanner-corpus/tuning/ground_truth.json bin/rails scanner:findings`. Read the "Phase 1 live" column. Look at every capture's strips with the Read tool (`runs/tuning-1/<file>/capture-001-{name,collector}.png`) to judge the framing: does each strip hold the whole name bar or collector line, and nothing else?
- [ ] Adjust and repeat, each round in a fresh run directory (`tuning-2`, …):
  - adjust `STRIPS` (and `GUIDE` if the cards don't fill the guide) in `geometry.js`, and `SETTINGS` (page segmentation per strip) in `recognition.js`;
  - adjust the matcher constants only if a round shows a matcher problem.

  Commit each round as `tune(scanner): <what changed> (tuning round N)`, with the round's rates and a `Ruling:` line in the body. Stop after 3 rounds unless the maintainer asks for more, so the tuning effort is bounded and stated.
- [ ] Run: `bin/rspec spec/system/scanner_spec.rb spec/system/scanner_measurement_spec.rb`. Expect: 0 failures. The synthetic card follows `STRIPS`, so it still lines up after tuning.
- [ ] Freeze. Commit: `feat(scanner): freeze strip geometry and OCR settings for the measured run`. The body lists the final `GUIDE`, `STRIPS` and `SETTINGS` and the number of tuning rounds. Note the commit's SHA for the findings (AC-6.1). No setting changes after this commit until the findings are written.

---

## Phase 11: The photo replay, the live tuning evidence and the findings

**Implements:** Story 6 (spec v2.0.0), AC-5.4–AC-5.6 (evidence) | **Satisfies:** AC-5.4, AC-5.5, AC-5.6, AC-6.2, AC-6.3, AC-6.4, AC-6.5, AC-6.6, AC-6.7, AC-6.8, NFR Performance
**Files:** `config/routes.rb`, `app/models/scanner/measurement_run.rb` (`#photo_path`), `app/controllers/scanner/measurements/photos_controller.rb`, `script/scanner/photo_run.rb`, `lib/collector/scanner_findings/report.rb` (`label:`, `prefix:`), `lib/tasks/scanner.rake` (`RUN_LABEL`, `FIXTURES_PREFIX`), `README.md`, specs for each, `docs/specs/007-card-scanner-live-capture/research.md`, `spec/fixtures/card_scanner/phase1_photos_*.json`, `spec/fixtures/card_scanner/phase1_tuning4_*.json`
**Interfaces:** Consumes: the frozen settings (`c68ffbd`), measurement mode, the photo picker path (`card-reader#pick`), `script/scanner/replay.rb` and `scanner:findings`. Produces: the findings and the text fixtures that the maintainer's go/no-go on the confirm flow rests on.

> **Revised 2026-10-01 (spec v2.0.0).** The 50 corpus cards were borrowed and returned, so they can't be re-captured live. The measured run replays the 50 Phase 0 photos on the desktop through the shipped photo-picker path, storing each capture through measurement mode. The four tuning rounds' live iPhone captures are the only live-alignment evidence and are reported as biased (AC-6.8). The code in this phase is specified by interface; implementer subagents write it test-first.

### 11a: The photo replay harness (code, TDD)

- [ ] `Scanner::MeasurementRun#photo_path(row)` → `<manifest's folder>/<row.file>` when that file exists, else nil.
- [ ] `GET /scanner/measurement/photos/:id` (`Scanner::Measurements::PhotosController#show`, `constraints: { id: /[\w.-]+/ }`), in the shape of `StripsController`: `MeasurementMode`, `allow_unauthenticated_access`, `require_local_request`, a manifest row by `file`, `send_file` with the photo's image type, `disposition: :inline`; 404 for an unknown row, a missing file, a non-local request, or measurement mode off. Request specs cover each case. Brakeman: same allowlist justification as the strips (manifest row matching `FILE_NAME`).
- [ ] `script/scanner/photo_run.rb`: headless Firefox (accept insecure certificates; `SCANNER_URL`, default `http://127.0.0.1:<this checkout's port>`), signs in with `SCANNER_EMAIL` / `SCANNER_PASSWORD`, opens `/scanner/measurement`, waits for the photo picker to be enabled (the engine is ready), and then, for each manifest row the panel selects next: fetches `/scanner/measurement/photos/<file>` in the page, hands it to the real picker (`DataTransfer` → `change`), and waits until the panel reports `Stored <file>` (or an alert), up to 120 s per photo. Stops when no row is pending; prints the count stored. No `sleep`; poll the DOM.
- [ ] `Collector::ScannerFindings::Report.new(run:, ground_truth:, output:, label: "Phase 1 live", prefix: "phase1")`: `label` names the third column; `write_fixtures!` writes `<prefix>_ocr_results.json` and `<prefix>_name_matches.json`, with `run` set from the label. `scanner:findings` passes `RUN_LABEL` and `FIXTURES_PREFIX` from the environment. Specs: label in the table headers, prefix in the fixture names.
- [ ] README (measurement mode paragraph): one sentence on `script/scanner/photo_run.rb` for replaying a folder of photos through the photo path.
- [ ] Commits: `feat(scanner): replay corpus photos through the photo picker in measurement mode` and `feat(scanner): name the scored run and its fixtures`.

### 11b: The runs and the findings

- [ ] Create a local replay user once: `COLLECTOR_PASSWORD=<random> bin/rails "collector:user[photo-replay@localhost]"`.
- [ ] Start a local server (plain HTTP on 127.0.0.1, a secure context) as a background task: `COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/photos bin/rails server -b 127.0.0.1 -p 3590` (default corpus manifest). Run `SCANNER_URL=http://127.0.0.1:3590 SCANNER_EMAIL=photo-replay@localhost SCANNER_PASSWORD=<same> bundle exec ruby script/scanner/photo_run.rb`. Expect: `Stored 50 captures`. Stop the server.
- [ ] Score and write the fixtures (AC-6.2–AC-6.4, AC-6.6): `COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/photos RUN_LABEL="Phase 1 photo replay" FIXTURES=1 FIXTURES_PREFIX=phase1_photos bin/rails scanner:findings > tmp/findings-photos.md`, and for the final tuning round: `COLLECTOR_SCANNER_MANIFEST=$HOME/card-scanner-corpus/tuning/manifest.csv COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/tuning-4 GROUND_TRUTH=$HOME/card-scanner-corpus/tuning/ground_truth.json RUN_LABEL="Tuning round 4 (live)" FIXTURES=1 FIXTURES_PREFIX=phase1_tuning4 bin/rails scanner:findings > tmp/findings-tuning4.md`. Score tuning rounds 1–3 the same way without `FIXTURES` (AC-6.8).
- [ ] View each photo-replay miss's strips (`runs/photos/<file>/capture-001-*.png`) and each tuning-4 miss's strips with the Read tool, and fill in the likely cause (AC-6.4).
- [ ] **Checkpoint (maintainer), load test (AC-6.5):** start the HTTPS server with `COLLECTOR_REQUEST_LOG=1` and a fresh `log/requests.jsonl`. On the iPhone in Brave: clear the website data for `192.168.1.76`, open `https://192.168.1.76:3578/scanner`, sign in, wait for "Ready" (cold); reload and wait for "Ready" (warm). Measure with the request-log snippet below (path `/scanner`). Expect one `core/` build on the cold load and no engine file re-downloaded on the warm load. The first `/scanner` row in the log can be a signed-out `302`. Start the cold load at the signed-in `/scanner` `200` (2026-10-02's run: the six requests after `POST /session`).

  ```sh
  ruby -rjson -e 'rows = File.readlines("log/requests.jsonl").map { JSON.parse(_1) }.select { _1["user_agent"].to_s.include?("iPhone") }
    loads = rows.each_index.select { |i| rows[i]["path"] == "/scanner" }
    loads.first(2).each_with_index { |start, n| stop = loads[n + 1] || rows.size; part = rows[start...stop].reject { _1["path"].start_with?("/scanner/readings") }
      puts "#{%w[cold warm][n]}: #{part.sum { _1["bytes"] }} bytes in #{part.size} requests; engine: #{part.select { _1["path"].start_with?("/ocr/") }.map { "#{_1["path"]} #{_1["status"]}" }.join(", ")}" }'
  ```
- [ ] Write `docs/specs/007-card-scanner-live-capture/research.md` (every rate with its sample size; anything not measured labelled so):
  1. **Summary.** Lead with what was and wasn't measured: live alignment only on the 12 tuning cards (biased), the 50 corpus cards only through their Phase 0 photos.
  2. **Method and apparatus:** settings commit `c68ffbd` (AC-6.1); tuning cards and rounds; device and browser; capture protocol (AC-5.4); the photo replay (desktop headless Firefox, photo path, the photos' framing: no guide, cards 69–77% of the frame height against the guide's 80%).
  3. **Rates (AC-6.2, AC-6.3):** the three-column tables (Phase 0, Phase 0 text with Phase 1's matcher, Phase 1 photo replay); which column shows the matcher's gain and what the photo replay does and doesn't show.
  4. **Live tuning captures (AC-6.8):** each round's rates, what changed between rounds (commits `ca27148`, `7d4f09d`, `ec71cd9`, `c68ffbd`), the desktop replay experiments, and the bias statement.
  5. **Misses (AC-6.4):** photo replay and tuning round 4, separately, with causes.
  6. **Timings and downloads (AC-6.5, NFR Performance):** on-device recognition (median, slowest) over the tuning rounds; lookup median and p95 from the photo replay, against Phase 0's 626 ms and 114 ms; cold and warm bytes and requests.
  7. **Device checks (AC-6.5):** rear camera ✓, indicator off ✓, torch ✓, photo orientation ✓, plain-HTTP fallback ✓ (Phase 10).
  8. **Replays (AC-5.6):** desktop replays of the tuning strips matched the device's text exactly (rounds 2 and 3).
  9. **Coverage (AC-5.4, AC-5.5):** per run: captured, skipped (none), retakes (tuning round 4: 1).
  10. **Findings for the next spec:** a misread collector line can match a real, different printing and outrank the right name match (AC-3.2, round 3's T003 → AER 184); faint foil collector lines; one-substitution set-code correction rejected.
  11. **Fixtures (AC-6.6):** paths, format_version 2 fields, keyed by manifest `file`; no images.
  12. **Options for the maintainer (AC-6.7):** build the confirm flow, bring card detection forward, or stop; no threshold.
- [ ] `git status --short`: only the fixtures, `research.md` and Phase 11a's code are new; no `.png`, `.jpeg` or `vendor/ocr` path.
- [ ] Commits: `test(scanner): add the photo replay and tuning round 4 text fixtures`, then `docs(spec): record the Phase 1 findings`.

---

## Phase 12: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run the full suite and every gate: `bin/ci`. Expect: every step passes (Setup, including the engine fetch; RuboCop; Brakeman; bundler-audit; importmap audit; RSpec).
- [ ] Run: `bin/rails zeitwerk:check`. Expect: `All is good!`.
- [ ] Run the migration both ways once more on a fresh database: `RAILS_ENV=test bin/rails db:drop db:create db:migrate && RAILS_ENV=test bin/rails db:rollback && RAILS_ENV=test bin/rails db:migrate`. Expect: no errors, and `git diff db/schema.rb` is empty afterwards. This is the upgrade-safety check (FR-5); it runs only against the test database.
- [ ] Run `sdd-superpowers:sdd-review` in Mode B on Fable (memory: SDD review model choice). It produces the AC-by-AC coverage matrix. Fix any drift before finishing.
- [ ] Commit any review fixes as their own commits. Then use `sdd-superpowers:finishing-a-development-branch`.

---

## Quickstart Validation

1. `bin/setup --skip-server`: installs the OCR engine (`Installed OCR engine v7.0.0: …`, or `already installed`).
2. `bin/dev`, then `bin/rails "catalog:refresh[mtg]"`. Wait until `bin/rails "catalog:status[mtg]"` shows `applied`.
3. In desktop Firefox, sign in and open `http://localhost:<port>/scanner`. Allow the camera: the feed shows with the teal guide, and the status says "Ready. Line the card up with the guide, then capture."
4. Choose **Use a photo** and pick a phone photo of a card held to fill the frame. "What the scanner read" and up to 3 candidates appear. A card whose collector line matched carries "Matched by its collector line". There is no add button.
5. `curl -sI http://localhost:<port>/scanner` (signed out) gives `302`. `curl -sI http://localhost:<port>/ocr/v7.0.0/tesseract.min.js` gives `cache-control: max-age=31536000, public, immutable`.
6. Over HTTPS on the local network: `bin/dev-certificate`, then `bin/dev -b "ssl://0.0.0.0:3578?key=$HOME/.local/share/collector-dev-https/dev.key&cert=$HOME/.local/share/collector-dev-https/dev.crt"`; trust the certificate on the phone (README) and open `https://192.168.1.76:3578/scanner` on it. The rear camera opens, and capturing a card shows its candidates.

---

## Supporting documents

- [data-model.md](data-model.md): the `catalog_names` table and its FTS5 index, measurement files, fixture format.
- [contracts/api.md](contracts/api.md): the scanner page, readings, OCR engine and measurement endpoints.

---

## Self-review (planning)

- **FR coverage:**
  - FR-1: Phases 5 and 6.
  - FR-2: Phase 6.
  - FR-3: Phases 4–6.
  - FR-4: Phases 1–3 and 5.
  - FR-5: Phase 2.
  - FR-6: Phase 7.
  - NFR Performance: Phases 8 and 11. NFR Security: Phases 4, 5 and 7. NFR Reliability and NFR Accessibility: Phase 6.
- **AC coverage:**
  - Story 1: AC-1.1 to AC-1.6 in Phase 6, AC-1.7 in Phase 5.
  - Story 2: AC-2.1 and AC-2.6 in Phase 6; AC-2.2 in Phases 4 and 5; AC-2.3 and AC-2.4 in Phase 5; AC-2.5 in Phases 5 and 6.
  - Story 3: AC-3.1 to AC-3.3 in Phases 3 and 5; AC-3.4 and AC-3.5 in Phase 2; AC-3.6 and AC-3.7 in Phase 1; AC-3.8 in Phases 3 and 5; AC-3.9 in Phase 2; AC-3.10 in Phase 5.
  - Story 4: AC-4.1 to AC-4.3 in Phase 6.
  - Story 5: AC-5.1 to AC-5.6 in Phases 7 and 11.
  - Story 6: AC-6.1 in Phase 10, AC-6.2 to AC-6.7 in Phases 8 and 11.
  - Story 7: AC-7.1 in Phases 9 and 10, AC-7.2 in Phase 9, AC-7.3 in Phase 4, AC-7.4 in Phase 0.
- **Manual-only evidence, recorded in the findings:**
  - the rear camera on the iPhone (AC-1.1);
  - the camera indicator going off (AC-1.4);
  - the torch actually lighting (AC-1.5);
  - real plain HTTP on the phone (AC-1.6);
  - a picked iPhone photo's orientation (AC-4.2);
  - the tunnel procedure (AC-7.1).
- **Gates:**
  - **Simplicity Gate: violated, and justified.** There are more than 3 components (engine hosting, name index, parser and reading, page and front end, measurement mode, findings tooling). Each traces to its own AC group in the spec. Measurement mode and the findings tooling exist only because Story 5 and Story 6 require a reproducible re-measure.
  - **Anti-Abstraction Gate: passes.** Framework features are used directly: the policy DSL, `stale?`/`expires_in`, Turbo Streams, Stimulus values and targets.
  - **Integration-First Gate: passes.** The contracts are in `contracts/api.md`, and the request specs precede the controllers.
