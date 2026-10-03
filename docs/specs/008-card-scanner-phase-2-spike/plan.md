# Implementation Plan: Card Scanner Phase 2 Spike — Card Detection and Art Matching

**Spec:** docs/specs/008-card-scanner-phase-2-spike/spec.md (v1.1.1, Approved, reviewed twice)
**Decisions:** [ADR 0004](../../adr/0004-card-recognition-in-the-browser.md) (Accepted). This feature *produces* Proposed ADRs for the techniques it recommends (Phase 8).
**Created:** 2026-10-02
**Revised:** 2026-10-02 — plan review (Fable, which ran the plan's code blocks): the split spec's expected lists corrected to the AC-1.1 rule and the braceless hash fixed; the entry file requires no unit, so Phase 1 runs in order; every spec uses `let` directories and `:aggregate_failures` for rubocop-rspec; `art_index.rb` requires `fingerprint`, `scoring.rb` requires `derived_corpus`; AC-3.3's found-only column uses the by-eye class; the replay runs get classes too (copied where the straightened image is byte-identical); the fetch chunk size comes from the estimate; the pilot files are all in the development half and `detect_run.rb` aborts otherwise, with an EXIF guard; the detection line tallies classes and skips sources without them; the per-photo distance table and the left-out corpus artworks are printed by the scripts; `derive.rb` resolves the port; the libvips package name; contour Mats deleted and the odd-blur rule; no commits between the freeze and the held-out runs

## Context

Phase 1 (spec 007) made the scanner usable on live capture (right card first for 42 of 49, in the top 3 for 45 of 49). Three weaknesses remain that reading text can't fix: the photo path fails without the guide (2 of 49), careless live framing cuts names off, and old frames and faint foil collector lines leave the printing unidentified. The roadmap's "Phase 2 – Precision" answers are card detection (find and straighten the card) and art matching (fingerprint the artwork against an index of every artwork). Neither has been measured here. This spike measures both on the 99 stored photos, on the desktop only, changing nothing in the app, so spec 009 (the confirm flow) is scoped from evidence.

This plan builds a throwaway Phase 2 harness under `spikes/card_scanner/phase2/`, beside Phase 0's, and turns its measurements into `research.md`, Proposed ADRs and text-only fixtures. The shipped reading chain and scoring are used as they stand; nothing under `app/`, `config/`, `db/`, `lib/`, `public/`, `script/` or `vendor/` changes (AC-5.6).

**Facts established during planning (2026-10-02):**

- **The shipped photo path can read a derived picture unchanged.** `card_reader_controller.js#pick` calls `createImageBitmap(file)` (which applies EXIF orientation) and places the guide with `guideInFrame(image.width, image.height, STAGE_ASPECT, 1)`; `geometry.js` has `STAGE_ASPECT = 3/4`, `GUIDE = { height: 0.8, maxWidth: 0.9 }`, `CARD_ASPECT = 63/88`. For a 3:4 picture the guide is a 63:88 box, 80% of the picture's height, centred (width ≈ 76% of the picture's width, under the 90% cap). So a straightened card padded into a 3:4 canvas, exactly filling that box, puts the shipped strips on its name bar and collector line.
- **Measurement mode takes a derived corpus from the environment.** `config/environments/development.rb:86-89`: `COLLECTOR_SCANNER_MANIFEST` and `COLLECTOR_SCANNER_RUN_DIR`. `Scanner::MeasurementRun` reads photos from the manifest's own directory (`photo_path` = `manifest.dirname.join(row.file)`), accepts any file name matching `/\A[\w-][\w.-]*\z/`, serves it with a Marcel-sniffed type (so a `.png` works), keys run directories by file name, counts the first capture of a row as the measured one, and writes `capture-001.json` with `file, kind, name_text, collector_text, ms, user_agent, captured_at` (no `parsed`/`lookup`; those come from `rescore`). `ms` covers only the two OCR calls.
- **Scoring is callable from spike code.** `Collector::ScannerFindings` (module functions): `rescore(truth, captures)` runs `MTG::Reading` and returns truth merged with `parsed`, `lookup`, `lookup_ms`, `name_candidates`, `final_candidates`; `breakdown`, `comparison(title, { "col" => records }) { hit }`, `in_top?(record, "final_candidates"|"name_candidates", n)`, `printing_identified?`, `name_read?`, `percentile`, `ground_truth(manifest_text)`, `era_for`, `SET_LINE_ERAS`, `LOOKUP_STATUSES`. `Report`'s only public methods are `to_markdown` and `write_fixtures!` (which writes into `spec/fixtures/card_scanner` with a fixed two-file shape), so the spike builds its own tables and fixture records from the module functions and never calls `write_fixtures!`. `bin/rails "scanner:ground_truth[manifest.csv]"` writes `ground_truth.json` beside the manifest (`{"photos","errors"}`), honouring an `era` column, with records `file, name, name_bar, set_code, collector_number, external_key, era, foil, borderless_or_showcase`.
- **`script/scanner/photo_run.rb`** signs in (`SCANNER_EMAIL`, `SCANNER_PASSWORD`), opens `/scanner/measurement`, hands each pending row's photo to the real picker in headless Firefox and waits for "Stored …" (120 s per photo). `SCANNER_URL` defaults to `http://127.0.0.1:<worktree port>`; this worktree's port is **3204**. A user is made with `COLLECTOR_PASSWORD=… bin/rails "collector:user[email]"`. The run is done when no row is pending; a fresh run directory is needed per run.
- **The reading chain is unchanged since `c68ffbd`** (`git diff c68ffbd HEAD -- app/javascript/scanner app/models/catalog app/models/mtg` is empty); the measurement tooling (`photo_run.rb`, `PhotosController`, `Report` labels) postdates it, so runs happen on the branch head "at the settings frozen at `c68ffbd`" (spec wording).
- **Baselines**: `spec/fixtures/card_scanner/phase1_photos_ocr_results.json` (50) and `phase1_live_photos_ocr_results.json` (49) hold the same photos' text through the shipped photo path; `phase1_live_ocr_results.json` (49) holds the new corpus's live captures. Rescoring their text with `rescore` reproduces the committed rankings, since the matcher is unchanged.
- **This worktree has an empty catalog** (per-worktree databases). `bin/rails runner 'Catalog::Refresh.new("mtg", trigger: "manual").call'` runs a refresh in the foreground (about 79 MB download, 69 s, 106,636 printings in the last baseline) and leaves the bulk file at `storage/catalog/mtg/default-cards-<YYYYMMDDHHMMSS>.jsonl.gz` (gzipped JSON Lines, one card per line). The entries the catalog imports are those with `lang == "en"`, not `digital`, and `"paper"` in `games` (`MTG::Scryfall::Mapper.paper?`); tokens and art cards are imported with a non-`card` kind, and `Catalog::Entry.searchable` is `kind = "card"` and not retired.
- **`illustration_id`** is on the card for single-faced cards and on each `card_faces[]` entry for double-faced ones (`Invasion of Muraganda`: no top-level id, one per face). The catalog reads neither it nor `image_uris.small`; the spike reads both from the bulk file. Scryfall's `small` image is 146×204 JPEG, about 12 KB (`mat 71`: 11,680 bytes); `normal` is 488×680, about 86 KB. Image URLs are `https://cards.scryfall.io/<size>/front/<a>/<b>/<id>.jpg?<stamp>`.
- **Image tooling on this machine:** ImageMagick 7.1.2 (`magick`) and Pillow 12.3 are installed; **libvips is not, and `ruby-vips` isn't in the bundle** (`image_processing` 2.1.0 is, with no backend). The app's Dockerfile installs `libvips`. The spike decodes images with `magick <file> -depth 8 ppm:-` (a 15-byte `P6` header then raw RGB) and does crop, area resampling and hashing in pure Ruby, the same arithmetic as the browser side. The findings report what the production index build would add (ruby-vips on the existing libvips, or ImageMagick), per AC-4.5.
- **OpenCV.js:** the official prebuilt build is `https://docs.opencv.org/4.13.0/opencv.js` (`4.x` redirects there): one file, 10,964,323 bytes, 3,543,365 bytes gzip -9, SHA-256 `63366510248adf3a7eddf3e793dd825404efb7df3749f4d6f8557c7fa4ca8aa0`, Apache-2.0. It embeds its WebAssembly as base64 (`wasmBinaryFile`, `WebAssembly.instantiate`) and contains two `new Function(` calls, so whether it runs under `script-src 'self' 'wasm-unsafe-eval'` is exactly what AC-2.8 measures. `root.cv = factory()` may be a Promise in 4.x builds; the loader awaits it either way.
- **Ruby has no `Integer#bit_count`** (4.0.7). A 16-bit lookup table gives about 336 ms for 45,000 × 16-word Hamming distances on this machine (`to_s(2).count("1")`: 526 ms), so a server-side search of six offsets is roughly 2 s in pure Ruby; the spike reports it as measured.
- **Scryfall etiquette** (`.claude/rules/external-data-and-portability.md`): descriptive `User-Agent`, `Accept`, 50–100 ms spacing, back off on 429, explicit timeouts. `MTG::Scryfall::Client` has `USER_AGENT = "Collector/1.0 (+https://github.com/plainprogrammer/Collector)"`, `MIN_INTERVAL = 0.1`, `OPEN_TIMEOUT = 10`, `READ_TIMEOUT = 60`; its `download` isn't throttled and sends `Accept: application/json`, so the spike's fetcher is its own small class with image `Accept` and spacing.

- **Phase 0's harness** (`spikes/card_scanner/`): `CardScannerSpike::Server` (Rack, static files, `/ocr/` immutable, loopback-only `/corpus/`, `POST /timings`, `POST /csp-report`, CSP `default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; worker-src 'self' blob:; connect-src 'self'; report-uri /csp-report`), `puma.rb` on port 4100, `script/replay.rb` (headless Firefox, polls `window.__spike.done`), `spec/spike_helper.rb`. RuboCop lints `spikes/`; RSpec's default pattern, Brakeman and `bin/ci` don't touch it. `tmp/*` is ignored. Selenium 4.49 with Firefox 156 (`SE_AVOID_STATS=true`). `Collector::OcrEngine` is the pinned-and-checksummed download pattern to copy (tarball and per-file SHA-256, injectable `download:`).
- **Disk:** 60 GB free. The spike's outputs (about 3.5 GB of PNG pictures across runs, 0.6 GB of artwork, the index) go under `tmp/card_scanner_phase2/` (ignored) and `~/card-scanner-corpus/runs/phase2/`.

**Plan decisions (not spelled out in the spec):**

- **A separate harness** at `spikes/card_scanner/phase2/` with its own Ruby namespace `CardScannerPhase2`, server (port 4200), pages, scripts and specs. Phase 0's code is not modified; its server is the model for the new one.
- **One settings file**, `spikes/card_scanner/phase2/settings.json`, holds every tuned knob (detector thresholds, warp size, fill colour, fingerprint box, offsets, image size). The page fetches it and the Ruby side reads it, so both use the same values, and the freeze commit (AC-1.3) is the last commit that changes it.
- **Both detectors share one warp.** Detection differs; straightening (homography and bilinear sampling, pure JS) is the same for both, so the comparison is between detectors, not warps.
- **Outputs go from the page to the spike server** (`POST /outputs/...`) rather than back through WebDriver, since a 3:4 picture is a multi-megabyte PNG. The driver script hands the page one photo at a time with `execute_async_script` and reads a small JSON result.
- **Derived corpora use honest names:** `IMG_6688.png` holds the 3:4 picture. Each run gets a derived `manifest.csv` (with an `era` column: `pre-M15` for `IMG_6718`, and the new corpus's existing overrides) and a `ground_truth.json` made by the shipped `scanner:ground_truth`. Photos a detector didn't find are left out of the derived manifest and scored as empty readings (AC-2.5). Fixture records are keyed by the original manifest file name.
- **Scoring** runs under `bin/rails runner` and calls `Collector::ScannerFindings.rescore` / `comparison` / `in_top?` / `printing_identified?` directly. The baseline and live columns are the committed fixtures' text rescored with the same functions (the matcher is unchanged since `c68ffbd`, so this reproduces the committed rankings), against the spike's own ground-truth copies.
- **Index build tool:** ImageMagick's `magick` CLI decodes each image to raw `P6` pixels; crop, area resampling, hashing, packing and search are pure Ruby in `CardScannerPhase2::Fingerprint` and `ArtIndex`. The browser side implements the same arithmetic in `fingerprint.js`. The findings report the production alternative (ruby-vips on the Dockerfile's libvips, or an `imagemagick` package) with sizes, per AC-4.5.
- **Index image size** starts at `small` (146×204). The pilot fetches both `small` and `normal` for the 99 corpus artworks only and compares agreement and gap; the choice is a tuned setting frozen with the rest.
- **The six query offsets** start as: none; ±2% of the card's width horizontally; ±2% of the card's height vertically; and a 3% inset on every side. They are tuned on the development half.
- **The contact-sheet classes** (AC-2.4) are written by the implementing session after viewing the sheets (the Read tool renders PNGs), into `classes.json` beside each sheet, which the maintainer can check.
- **The full artwork fetch** is resumable (cached files are skipped) and runs in chunks, since a background task stops after 2 hours.
- **Spike specs** live in `spikes/card_scanner/phase2/spec/` and run with `bundle exec rspec spikes/card_scanner/phase2/spec`; pure-Ruby specs load `phase2_helper`, the Rails-backed ones load `rails_helper` first. The pages and the driver scripts are apparatus checked by inspection and by the pilot, as in Phase 0.

## Global Constraints

- No changes under `app/`, `config/`, `db/`, `lib/`, `public/`, `script/` or `vendor/`; `Gemfile` and `Gemfile.lock` unchanged. The branch may touch only `docs/`, `spikes/card_scanner/`, `spec/fixtures/card_scanner/`, `.claude/memory/`, and exclusion lines in `.rubocop.yml` or `.gitignore` (AC-5.6).
- No photo, straightened card, strip, fetched artwork or index is committed. Working files go under `tmp/card_scanner_phase2/` (ignored) and `~/card-scanner-corpus/runs/phase2/` (FR-1, AC-5.5, AC-5.7).
- No picture leaves the machine. Detection, straightening and the query fingerprint run in headless Firefox on the desktop; the spike page loads only its own origin (ADR 0004, NFR Security).
- No held-out photo touches a detector or the fingerprint before the settings commit, and the scripts enforce it (AC-1.2). Development-half runs are labelled biased in every table (AC-1.4).
- Scryfall: `User-Agent`, `Accept: image/jpeg`, ≥100 ms between requests, open/read timeouts, back off on 429, cache on disk (AC-4.7). The full fetch waits for the maintainer's approval of the committed estimate (AC-4.2).
- No pass threshold. Every number carries its sample size; desktop timings are labelled as such; phone figures are listed as unmeasured (FR-5, AC-5.3).
- Spike Ruby is RuboCop-clean; `bin/ci` passes at every commit. One Conventional Commit per step, scope `spike` or `docs`. Branch `008-card-scanner-phase-2-spike`, created from the worktree branch at the start of execution per `docs/git-convention.md`.

---

## Goal

A throwaway Phase 2 harness plus measured findings (`research.md`, Proposed ADRs, `phase2_*` JSON fixtures) that let the maintainer rule, for each of card detection and art matching, on build-with-the-confirm-flow, defer, or drop.

**Components (Simplicity Gate: 3):**
1. The spike page and server: `detect.html` with `hand_detector.js`, `opencv_detector.js`, `warp.js`, `fingerprint.js`, `search.js`, served by `CardScannerPhase2::Server`.
2. The Ruby library `CardScannerPhase2::{Settings, Split, Runs, OpencvAsset, Ppm, Fingerprint, BulkArtworks, ArtFetcher, ArtIndex, DerivedCorpus, Scoring, Records}`.
3. The scripts under `spikes/card_scanner/phase2/script/` that drive runs and write tables.

**Human checkpoints (the maintainer):**
- Phase 5: approve the full artwork fetch from the committed estimate (AC-4.2).
- Phase 8: the contact sheets and findings are theirs to check; the ruling on spec 009 follows.

---

## Phase 0: Environment

**Implements:** Users and Context (the catalog, the bulk file, the dev user) | **Satisfies:** none directly; every later phase needs it
**Files:** none in the repository
**Interfaces:** Consumes: Scryfall bulk data; Produces: a populated development catalog in this worktree, `storage/catalog/mtg/default-cards-<stamp>.jsonl.gz`, a sign-in for `photo_run.rb`

- [ ] Check space: `df -h ~ | tail -1`. Expect at least 10 GB free (there were 60 GB at planning).
- [ ] Refresh the catalog in the foreground (about 79 MB and 70 s): `bin/rails runner 'Catalog::Refresh.new("mtg", trigger: "manual").call'`. Then `bin/rails "catalog:status[mtg]"`. Expect: the newest run `applied`, and `bin/rails runner 'puts Catalog::Name.count'` about 36,000. Record the `source_version` (the bulk file's stamp) for `research.md`.
- [ ] Confirm the bulk file is where the spike will read it: `bin/rails runner 'puts Dir[Rails.configuration.x.catalog_download_dir.join("mtg", "*.jsonl.gz")]'`. Expect one `default-cards-<stamp>.jsonl.gz` path.
- [ ] Make the reading-run user once: `COLLECTOR_PASSWORD=<random> bin/rails "collector:user[phase2@localhost]"`. Keep the password in the session (it is never committed).
- [ ] Confirm the committed Phase 0 ground truth still resolves against this catalog: `bin/rails "scanner:ground_truth[$HOME/card-scanner-corpus/manifest.csv]"` writes `~/card-scanner-corpus/ground_truth.json` (outside the repo). Expect `50 resolved, 0 errors`. Do the same for `$HOME/card-scanner-corpus/phase1-live/manifest.csv` (it overwrites the file spec 007 wrote with the same content). Expect `49 resolved, 0 errors`. If either reports errors, list them in `research.md` as ground-truth errors (Error Scenarios) and exclude those files.

---

## Phase 1: Split, settings and run records

**Implements:** FR-1, Story 1 | **Satisfies:** AC-1.1, AC-1.2 (the guard and the record fields), AC-1.5 (the record fields)
**Files:** `spikes/card_scanner/phase2/lib/card_scanner_phase2.rb`, `lib/card_scanner_phase2/{settings,split,runs}.rb`, `settings.json`, `spec/phase2_helper.rb`, `spec/card_scanner_phase2/{split,settings,runs}_spec.rb`, `spec/fixtures/card_scanner/phase2_split.json`
**Interfaces:** Consumes: the two manifests; Produces: `phase2_split.json` (committed), `Settings.load`, `Split.halves`, `Runs.start!` returning a run directory with `run.json`

- [ ] Write `spikes/card_scanner/phase2/lib/card_scanner_phase2.rb`:

```ruby
require "json"
require "pathname"

# The Phase 2 spike (spec 008): card detection and art matching on the stored photos.
module CardScannerPhase2
  ROOT = Pathname(File.expand_path("..", __dir__))
  REPO = ROOT.join("../../..").expand_path
  WORK_DIR = REPO.join("tmp/card_scanner_phase2")
  FIXTURE_DIR = REPO.join("spec/fixtures/card_scanner")
  SETTINGS_PATH = ROOT.join("settings.json")

  def self.corpus_dir = Pathname(File.expand_path(ENV.fetch("CARD_SCANNER_CORPUS", "~/card-scanner-corpus")))
  def self.runs_dir = corpus_dir.join("runs/phase2")

  CORPORA = {
    "phase0" => { manifest: "manifest.csv", label: "Phase 0" },
    "new" => { manifest: "phase1-live/manifest.csv", label: "New corpus" }
  }.freeze
end
```

  The entry file requires no unit: every spec and script requires the units it uses (`require "card_scanner_phase2/split"`), so a spec can fail with `cannot load such file` before its unit exists and the Phase 1 steps run in order.

- [ ] Write `spikes/card_scanner/phase2/spec/phase2_helper.rb`:

```ruby
# Loads the Phase 2 spike code (spec 008) for its specs; these are not part of bin/ci.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "card_scanner_phase2"
```

- [ ] Write `spikes/card_scanner/phase2/settings.json` (every knob the spike tunes; the last commit that changes it is the settings commit):

```json
{
  "hand": { "workWidth": 480, "blur": 1, "edgePercentile": 0.92, "thetaRangeDeg": 25, "minSeparation": 0.3, "minArea": 0.15, "aspectRange": [0.5, 0.9] },
  "opencv": { "workWidth": 480, "blur": 5, "canny": [50, 150], "approxEpsilon": 0.02, "minArea": 0.15, "aspectRange": [0.5, 0.9] },
  "warp": { "width": 1008, "height": 1408, "fill": "#808080" },
  "fingerprint": {
    "box": { "x0": 0.14, "x1": 0.86, "y0": 0.16, "y1": 0.5 },
    "grid": [17, 16],
    "offsets": [
      { "dx": 0, "dy": 0 }, { "dx": 0.02, "dy": 0 }, { "dx": -0.02, "dy": 0 },
      { "dx": 0, "dy": 0.02 }, { "dx": 0, "dy": -0.02 }, { "dx": 0, "dy": 0, "inset": 0.03 }
    ],
    "imageSize": "small"
  }
}
```

- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/settings_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/settings"

RSpec.describe CardScannerPhase2::Settings do
  it "loads the committed settings with every section", :aggregate_failures do
    settings = described_class.load
    expect(settings.keys).to include("hand", "opencv", "warp", "fingerprint") # the freeze adds "frozen" and "chosen_detector"
    expect(settings.dig("fingerprint", "offsets").size).to eq(6)
    expect(settings.dig("warp", "width").to_f / settings.dig("warp", "height")).to be_within(0.002).of(63.0 / 88)
  end

  it "reports the commit that last changed the file" do
    expect(described_class.commit).to match(/\A\h{40}\z/)
  end
end
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase2/spec/card_scanner_phase2/settings_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_phase2/settings`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/settings.rb`:

```ruby
module CardScannerPhase2
  # The tuned knobs, shared by the page (served as /settings.json) and the Ruby side.
  module Settings
    module_function

    def load(path = SETTINGS_PATH) = JSON.parse(path.read)

    # The commit that last changed the settings file: the settings commit once tuning stops (AC-1.3).
    def commit(path = SETTINGS_PATH)
      IO.popen([ "git", "-C", REPO.to_s, "log", "-1", "--format=%H", "--", path.relative_path_from(REPO).to_s ], &:read).strip
    end
  end
end
```

- [ ] Run the spec again. Expect: 2 examples, 1 failure: the commit example fails until the file is committed (`git log` prints nothing), and passes after the commit below.
- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/split_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/split"

RSpec.describe CardScannerPhase2::Split do
  # Non-foils A, C, D alternate to development, held out, development; foils B, E to development, held out.
  let(:phase0) { "file,set,number,foil\nA.jpeg,aaa,1,no\nB.jpeg,aaa,2,yes\nC.jpeg,aaa,3,no\nD.jpeg,aaa,4,no\nE.jpeg,aaa,5,yes\n" }
  let(:new) { "file,set,number,foil,era\nF.jpeg,bbb,1,no,\nG.jpeg,bbb,2,no,pre-M15\nH.jpeg,bbb,3,yes,\n" }
  let(:texts) { { "phase0" => phase0, "new" => new } }

  it "alternates foils and non-foils separately, each group starting with development", :aggregate_failures do
    halves = described_class.halves(texts, force_development: {})
    expect(halves.dig("phase0", "development")).to eq(%w[A.jpeg D.jpeg B.jpeg])
    expect(halves.dig("phase0", "held_out")).to eq(%w[C.jpeg E.jpeg])
    expect(halves.dig("new", "development")).to eq(%w[F.jpeg H.jpeg])
    expect(halves.dig("new", "held_out")).to eq(%w[G.jpeg])
  end

  it "forces the shared card's new-corpus photo into development", :aggregate_failures do
    halves = described_class.halves(texts, force_development: { "new" => %w[G.jpeg] })
    expect(halves.dig("new", "development")).to eq(%w[F.jpeg H.jpeg G.jpeg])
    expect(halves.dig("new", "held_out")).to be_empty
  end

  it "reads the real manifests into the committed counts", :aggregate_failures do
    halves = described_class.halves
    counts = halves.transform_values { |h| h.transform_values(&:size) }
    expect(counts).to eq("phase0" => { "development" => 26, "held_out" => 24 }, "new" => { "development" => 26, "held_out" => 23 })
    expect(halves.dig("new", "development")).to include("IMG_6763.jpeg")
  end
end
```

  (The plan review ran this against the implementation: the expected lists follow from the AC-1.1 rule, and the real manifests give exactly the committed counts.)

- [ ] Run `bundle exec rspec spikes/card_scanner/phase2/spec/card_scanner_phase2/split_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_phase2/split`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/split.rb`:

```ruby
module CardScannerPhase2
  # Halves each corpus before any tuning (AC-1.1): foil and non-foil rows alternate separately in manifest
  # order, each group starting with development. One card, Leyline Immersion mat 71, is in both corpora,
  # so its new-corpus photo is forced into development to keep every printing on one side.
  module Split
    FORCE_DEVELOPMENT = { "new" => %w[IMG_6763.jpeg] }.freeze
    SPLIT_PATH = FIXTURE_DIR.join("phase2_split.json")

    module_function

    def manifests
      CORPORA.to_h { |key, corpus| [ key, CardScannerPhase2.corpus_dir.join(corpus[:manifest]).read ] }
    end

    def rows(manifest_text)
      header, *lines = manifest_text.lines.map(&:strip).reject(&:empty?)
      keys = header.split(",", -1).map(&:strip)
      lines.map { |line| keys.zip(line.split(",", -1).map(&:strip)).to_h }
    end

    def halves(texts = manifests, force_development: FORCE_DEVELOPMENT)
      texts.to_h do |key, text|
        development, held_out = [], []
        rows(text).group_by { it["foil"].casecmp?("yes") }.sort_by { |foil, _| foil ? 1 : 0 }.each do |_, group|
          group.each_with_index { |row, index| (index.even? ? development : held_out) << row["file"] }
        end
        forced = Array(force_development[key])
        [ key, { "development" => development + (held_out & forced), "held_out" => held_out - forced } ]
      end
    end

    def write!(path = SPLIT_PATH)
      path.write(JSON.pretty_generate("format_version" => 1, "rule" => "foil and non-foil rows alternate separately in manifest order, " \
        "each group starting with development; IMG_6763.jpeg (mat 71, also in Phase 0) forced to development", "halves" => halves))
    end

    def read(path = SPLIT_PATH) = JSON.parse(path.read).fetch("halves")

    def half_of(corpus, file, split = read)
      split.fetch(corpus).find { |_, files| files.include?(file) }&.first or raise ArgumentError, "#{file} isn't in the #{corpus} split"
    end
  end
end
```

  Note the ordering: `group_by` keeps the first-seen order of groups, so `sort_by` puts non-foils before foils; within each group, manifest order is kept. The spec's first example pins the exact lists.

- [ ] Run the spec again. Expect: 3 examples, 0 failures. Then `bin/rubocop spikes/`. Expect: no offenses.
- [ ] Write the split fixture: `bundle exec ruby -I spikes/card_scanner/phase2/lib -e 'require "card_scanner_phase2"; require "card_scanner_phase2/split"; CardScannerPhase2::Split.write!'`. Inspect `spec/fixtures/card_scanner/phase2_split.json`: 26/24 and 26/23 files, `IMG_6763.jpeg` under `new` → `development`.
- [ ] Commit: `feat(spike): add the Phase 2 split, settings and spec helper` (stage `spikes/card_scanner/phase2/` and `spec/fixtures/card_scanner/phase2_split.json`). This commit precedes every tuning commit (AC-1.1).
- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/runs_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/runs"
require "fileutils"
require "tmpdir"

RSpec.describe CardScannerPhase2::Runs do
  let(:git) { instance_double(CardScannerPhase2::Runs::Git, head: "a" * 40, clean?: true) }
  let(:dir) { Pathname(Dir.mktmpdir) }

  after { FileUtils.remove_entry(dir) }

  it "starts a development run and records its provenance" do
    run = described_class.start!("dev-hand", half: "development", root: dir, git:, settings_commit: "b" * 40, now: Time.utc(2026, 10, 3, 12))
    expect(JSON.parse(run.join("run.json").read)).to include("run" => "dev-hand", "half" => "development", "code_commit" => "a" * 40, "tree_clean" => true,
      "settings_commit" => "b" * 40, "started_at" => "2026-10-03T12:00:00Z")
  end

  it "refuses a held-out run without the settings commit" do
    expect { described_class.start!("held", half: "held_out", root: dir, git:, settings_commit: nil) }.to raise_error(described_class::Refused, /settings commit/)
  end

  it "refuses a held-out run when the code isn't at the settings commit" do
    expect { described_class.start!("held", half: "held_out", root: dir, git:, settings_commit: "b" * 40) }
      .to raise_error(described_class::Refused, /code is at/)
  end

  it "refuses a held-out run on a dirty tree" do
    dirty = instance_double(CardScannerPhase2::Runs::Git, head: "a" * 40, clean?: false)
    expect { described_class.start!("held", half: "held_out", root: dir, git: dirty, settings_commit: "a" * 40) }
      .to raise_error(described_class::Refused, /uncommitted/)
  end

  it "starts a held-out run at the settings commit on a clean tree" do
    run = described_class.start!("held", half: "held_out", root: dir, git:, settings_commit: "a" * 40)
    expect(JSON.parse(run.join("run.json").read)).to include("half" => "held_out", "settings_commit" => "a" * 40)
  end

  it "refuses to reuse a run directory" do
    described_class.start!("dev", half: "development", root: dir, git:, settings_commit: nil)
    expect { described_class.start!("dev", half: "development", root: dir, git:, settings_commit: nil) }.to raise_error(described_class::Refused, /exists/)
  end

  it "stamps a record with the run's provenance" do
    run = described_class.start!("dev", half: "development", root: dir, git:, settings_commit: nil, now: Time.utc(2026, 10, 3, 12))
    stamped = described_class.stamp(run, { "file" => "A.jpeg" }, now: Time.utc(2026, 10, 3, 12, 5))
    expect(stamped).to include("file" => "A.jpeg", "run" => "dev", "code_commit" => "a" * 40, "tree_clean" => true, "recorded_at" => "2026-10-03T12:05:00Z")
  end
end
```

  Spec style throughout the spike: multi-expectation examples carry `:aggregate_failures`, temporary directories are `let`s cleaned in `after` (no instance variables), as `spikes/card_scanner/spec/card_scanner_spike/server_spec.rb` does, so `bin/rubocop spikes/` stays clean under rubocop-rspec.

- [ ] Run `bundle exec rspec spikes/card_scanner/phase2/spec/card_scanner_phase2/runs_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_phase2/runs`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/runs.rb`:

```ruby
require "time"

module CardScannerPhase2
  # Starts a run directory with its provenance, and refuses held-out runs before the freeze (AC-1.2, AC-1.5).
  module Runs
    class Refused < StandardError; end

    # Thin git reader, replaceable in specs.
    class Git
      def initialize(repo = REPO) = @repo = repo.to_s
      def head = IO.popen([ "git", "-C", @repo, "rev-parse", "HEAD" ], &:read).strip
      def clean? = IO.popen([ "git", "-C", @repo, "status", "--porcelain" ], &:read).strip.empty?
    end

    module_function

    def start!(name, half:, root: CardScannerPhase2.runs_dir, git: Git.new, settings_commit: ENV["SETTINGS_COMMIT"], now: Time.now.utc)
      raise ArgumentError, "half must be development or held_out" unless %w[development held_out].include?(half)

      guard!(half, git, settings_commit)
      dir = root.join(name)
      raise Refused, "#{dir} exists; held-out runs happen once, so pick a new name" if dir.exist?

      dir.mkpath
      dir.join("run.json").write(JSON.pretty_generate(provenance(name, half, git, settings_commit, now)))
      dir
    end

    def guard!(half, git, settings_commit)
      return if half == "development"
      raise Refused, "a held-out run needs the settings commit (SETTINGS_COMMIT)" if settings_commit.to_s.empty?
      raise Refused, "the code is at #{git.head}, not the settings commit #{settings_commit}" unless git.head == settings_commit
      raise Refused, "the working tree has uncommitted changes; held-out runs need a clean tree" unless git.clean?
    end

    def provenance(name, half, git, settings_commit, now)
      { "run" => name, "half" => half, "code_commit" => git.head, "tree_clean" => git.clean?, "settings_commit" => settings_commit,
        "started_at" => now.iso8601 }
    end

    def read(dir) = JSON.parse(dir.join("run.json").read)

    def stamp(dir, record, now: Time.now.utc)
      run = read(dir)
      record.merge("run" => run["run"], "half" => run["half"], "code_commit" => run["code_commit"], "tree_clean" => run["tree_clean"],
        "settings_commit" => run["settings_commit"], "recorded_at" => now.iso8601)
    end
  end
end
```

- [ ] Run the spec again. Expect: 7 examples, 0 failures. Then `bin/rubocop spikes/`. Expect: no offenses.
- [ ] Commit: `feat(spike): record run provenance and refuse held-out runs before the freeze`

---
## Phase 2: Spike server, OpenCV.js fetcher, detect page with the hand-written detector, driver and pilot

**Implements:** FR-2 (both detectors run in a browser from the page's origin; cards treated as upright), Story 2 | **Satisfies:** AC-2.1 (hand detector), AC-1.6 (pilot), AC-2.9 (timing capture), AC-2.7 (the fetch into an ignored path)
**Files:** `spikes/card_scanner/phase2/lib/card_scanner_phase2/{server,opencv_asset}.rb`, `config.ru`, `puma.rb`, `public/{detect.html,detect.js,canvas.js,hand_detector.js,warp.js,output.js}`, `script/{fetch_opencv.rb,detect_run.rb,contact_sheet.rb}`, `spec/card_scanner_phase2/{server,opencv_asset}_spec.rb`, `README.md`
**Interfaces:** Consumes: `/corpus/<path>` photos, `settings.json`; Produces: `<runs>/<run>/<stem>/{detect.json,card.png,picture.png}`, contact sheets

**Complexity note:** the pages and the driver have no specs. They are experiment apparatus checked by inspection and by the pilot, as in Phase 0 (the maintainer confirmed that exemption for spec 005). The Ruby server and the fetcher are specced.

- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/server_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/server"
require "fileutils"
require "rack/mock"
require "tmpdir"

RSpec.describe CardScannerPhase2::Server do
  let(:root) do
    Pathname(Dir.mktmpdir).tap do |root|
      %w[public opencv/4.13.0 corpus/phase1-live work runs logs].each { root.join(it).mkpath }
      root.join("public/detect.html").write("<!doctype html>")
      root.join("opencv/4.13.0/opencv.js").write("// cv")
      root.join("corpus/IMG_1.jpeg").binwrite("\xFF\xD8\xFF".b)
      root.join("corpus/phase1-live/IMG_2.jpeg").binwrite("\xFF\xD8\xFF".b)
      root.join("settings.json").write("{}")
    end
  end
  let(:dirs) do
    { public_dir: root.join("public"), opencv_dir: root.join("opencv"), corpus_dir: root.join("corpus"), work_dir: root.join("work"),
      runs_dir: root.join("runs"), log_dir: root.join("logs"), settings_path: root.join("settings.json") }
  end
  let(:app) { described_class.new(**dirs) }
  let(:local) { { "REMOTE_ADDR" => "127.0.0.1" } }

  after { FileUtils.remove_entry(root) }

  def get(path, env = local) = Rack::MockRequest.new(app).get(path, env)
  def post(path, env) = Rack::MockRequest.new(app).post(path, env)

  it "serves the page with the scanner page's policy plus a nonce and a report endpoint", :aggregate_failures do
    response = get("/detect.html")
    policy = response.headers["content-security-policy"]
    expect(response.status).to eq(200)
    expect(policy).to start_with("default-src 'self'; script-src 'self' 'wasm-unsafe-eval' 'nonce-")
    expect(policy).to include("worker-src 'self' blob:", "connect-src 'self'", "object-src 'none'", "report-uri /csp-report")
    expect(policy).not_to match(%r{https?:|\*})
  end

  it "widens script-src only when asked, for the AC-2.8 diagnosis" do
    loose = described_class.new(**dirs, unsafe_eval: true)
    expect(Rack::MockRequest.new(loose).get("/detect.html", local).headers["content-security-policy"]).to include("'unsafe-eval'")
  end

  it "serves the settings file" do
    expect(get("/settings.json").body).to eq("{}")
  end

  it "serves OpenCV.js immutably", :aggregate_failures do
    response = get("/opencv/4.13.0/opencv.js")
    expect(response.status).to eq(200)
    expect(response.headers["cache-control"]).to eq("public, max-age=31536000, immutable")
  end

  it "serves corpus photos, including subdirectories, to this machine only", :aggregate_failures do
    expect(get("/corpus/IMG_1.jpeg").status).to eq(200)
    expect(get("/corpus/phase1-live/IMG_2.jpeg").status).to eq(200)
    expect(get("/corpus/IMG_1.jpeg", "REMOTE_ADDR" => "192.168.1.9").status).to eq(403)
  end

  it "serves working files (artwork, index) to this machine only", :aggregate_failures do
    root.join("work/index.bin").binwrite("abc")
    expect(get("/work/index.bin").body).to eq("abc")
    expect(get("/work/index.bin", "REMOTE_ADDR" => "192.168.1.9").status).to eq(403)
  end

  it "stores a page's output under the run directory", :aggregate_failures do
    response = post("/outputs/dev-hand/IMG_1/card.png", local.merge(input: "\x89PNG".b, "CONTENT_TYPE" => "image/png"))
    expect(response.status).to eq(201)
    expect(root.join("runs/dev-hand/IMG_1/card.png").binread).to eq("\x89PNG".b)
  end

  it "refuses output paths that leave the run directory or carry odd names", :aggregate_failures do
    expect(post("/outputs/dev-hand/../x/card.png", local.merge(input: "x")).status).to eq(400)
    expect(post("/outputs/dev-hand/IMG_1/card.exe", local.merge(input: "x")).status).to eq(400)
    expect(post("/outputs/dev-hand/IMG_1/card.png", { "REMOTE_ADDR" => "192.168.1.9", input: "x" }).status).to eq(403)
  end

  it "records policy violation reports", :aggregate_failures do
    expect(post("/csp-report", local.merge(input: '{"csp-report":{}}')).status).to eq(204)
    expect(root.join("logs/csp-reports.jsonl").read).to include("csp-report")
  end
end
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase2/spec/card_scanner_phase2/server_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_phase2/server`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/server.rb`:

```ruby
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
```

  Note on `img-src`: `ScannerPage` also lists the catalog's image hosts; the spike page loads no catalog images, so they are left out and the findings say so when quoting the header. The nonce is unused by the page (it has no inline script) but keeps the header's shape.

- [ ] Run the spec again. Expect: 9 examples, 0 failures. Then `bin/rubocop spikes/`. Expect: no offenses.
- [ ] Write `spikes/card_scanner/phase2/config.ru`:

```ruby
$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "card_scanner_phase2"
require "card_scanner_phase2/server"

run CardScannerPhase2::Server.new(
  public_dir: CardScannerPhase2::ROOT.join("public"),
  opencv_dir: CardScannerPhase2::WORK_DIR.join("opencv"),
  corpus_dir: CardScannerPhase2.corpus_dir,
  work_dir: CardScannerPhase2::WORK_DIR,
  runs_dir: CardScannerPhase2.runs_dir,
  log_dir: CardScannerPhase2::WORK_DIR.join("logs"),
  settings_path: CardScannerPhase2::SETTINGS_PATH,
  unsafe_eval: ENV["SPIKE_UNSAFE_EVAL"] == "1")
```

- [ ] Write `spikes/card_scanner/phase2/puma.rb`:

```ruby
port Integer(ENV.fetch("SPIKE_PORT", 4200)), "127.0.0.1"
rackup File.expand_path("config.ru", __dir__)
threads 1, 4
```

- [ ] Commit: `feat(spike): add the Phase 2 spike server with the scanner's policy and an output sink`
- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/opencv_asset_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/opencv_asset"
require "digest"
require "fileutils"
require "tmpdir"

RSpec.describe CardScannerPhase2::OpencvAsset do
  let(:root) { Pathname(Dir.mktmpdir) }
  let(:content) { "// opencv".b }
  let(:pin) { described_class::Pin.new(url: "https://example.test/opencv.js", sha256: Digest::SHA256.hexdigest(content), served: "4.13.0/opencv.js") }

  after { FileUtils.remove_entry(root) }

  it "downloads, verifies and writes the pinned file", :aggregate_failures do
    written = described_class.install!(root:, pin:, download: ->(_url) { content })
    expect(written).to eq(root.join("4.13.0/opencv.js"))
    expect(written.binread).to eq(content)
  end

  it "skips a file that is already intact" do
    root.join("4.13.0").mkpath
    root.join("4.13.0/opencv.js").binwrite(content)
    expect(described_class.install!(root:, pin:, download: ->(_url) { raise "not called" })).to be_nil
  end

  it "refuses a download whose checksum differs and leaves nothing behind", :aggregate_failures do
    expect { described_class.install!(root:, pin:, download: ->(_url) { "// other".b }) }.to raise_error(described_class::IntegrityError, /sha256/)
    expect(root.join("4.13.0/opencv.js")).not_to exist
  end

  it "pins the official 4.13.0 build", :aggregate_failures do
    expect(described_class::PIN.url).to eq("https://docs.opencv.org/4.13.0/opencv.js")
    expect(described_class::PIN.sha256).to eq("63366510248adf3a7eddf3e793dd825404efb7df3749f4d6f8557c7fa4ca8aa0")
  end
end
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase2/spec/card_scanner_phase2/opencv_asset_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_phase2/opencv_asset`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/opencv_asset.rb` (the `Collector::OcrEngine` pattern: pinned URL, SHA-256, injectable download, write-then-rename, into an ignored path):

```ruby
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
```

- [ ] Run the spec again. Expect: 4 examples, 0 failures. Then `bin/rubocop spikes/`. Expect: no offenses.
- [ ] Write `spikes/card_scanner/phase2/script/fetch_opencv.rb`:

```ruby
# Fetches the pinned OpenCV.js build into the ignored work directory and prints its size.
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/fetch_opencv.rb
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/opencv_asset"
require "zlib"

written = CardScannerPhase2::OpencvAsset.install!
path = CardScannerPhase2::OpencvAsset::ROOT.join(CardScannerPhase2::OpencvAsset::PIN.served)
puts "#{written ? "fetched" : "already intact"}: #{path}"
raw = path.binread
puts "raw #{raw.bytesize} bytes, gzip #{Zlib::Deflate.deflate(raw, Zlib::BEST_COMPRESSION).bytesize} bytes"
```

- [ ] Run `bundle exec ruby spikes/card_scanner/phase2/script/fetch_opencv.rb`. Expect: `fetched: …/tmp/card_scanner_phase2/opencv/4.13.0/opencv.js`, `raw 10964323 bytes, gzip 3543365 bytes` (the gzip figure may differ by a few bytes between zlib and `gzip -9`; the findings quote this script's). Run it again. Expect `already intact`.
- [ ] Commit: `feat(spike): fetch the pinned OpenCV.js build into the ignored work directory`
- [ ] Write `spikes/card_scanner/phase2/public/detect.html`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Card scanner Phase 2 spike: detect</title>
  <script type="module" src="/detect.js"></script>
</head>
<body>
  <h1>Detect</h1>
  <p id="status">Loading settings…</p>
  <canvas id="preview" width="330" height="440"></canvas>
</body>
</html>
```

- [ ] Write `spikes/card_scanner/phase2/public/canvas.js` (shared helpers; `OffscreenCanvas` is in Firefox 105+):

```js
export function canvasOf(width, height) {
  const canvas = new OffscreenCanvas(width, height)
  return { canvas, ctx: canvas.getContext("2d", { willReadFrequently: true }) }
}

// Draws a bitmap at a scale: scale 1 keeps the photo's pixels; otherwise the whole photo is fitted into
// the given height (1440 for the live-frame stand-in, AC-2.6).
export function sourceCanvas(bitmap, targetHeight) {
  const scale = targetHeight ? targetHeight / bitmap.height : 1
  const { canvas, ctx } = canvasOf(Math.round(bitmap.width * scale), Math.round(bitmap.height * scale))
  ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
  return canvas
}

export function imageDataOf(canvas) {
  return canvas.getContext("2d", { willReadFrequently: true }).getImageData(0, 0, canvas.width, canvas.height)
}

export function toGray(imageData) {
  const { data, width, height } = imageData
  const gray = new Float32Array(width * height)
  for (let i = 0, p = 0; i < gray.length; i++, p += 4) gray[i] = 0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2]
  return gray
}

export async function pngBlob(canvas) {
  return canvas.convertToBlob({ type: "image/png" })
}
```

- [ ] Write `spikes/card_scanner/phase2/public/hand_detector.js` (no dependency: box blur, Sobel, a Hough transform for near-horizontal and near-vertical lines, two peaks per direction, the four intersections):

```js
import { canvasOf, toGray } from "/canvas.js"

// Finds the card as the two strongest near-horizontal and two strongest near-vertical edge lines in a
// downscaled copy of the photo, and returns its four corners in the source's pixel coordinates
// (top-left, top-right, bottom-right, bottom-left), or null. Cards are treated as upright (FR-2).
export function detectHand(source, settings) {
  const scale = settings.workWidth / source.width
  const w = settings.workWidth, h = Math.round(source.height * scale)
  const { canvas, ctx } = canvasOf(w, h)
  ctx.drawImage(source, 0, 0, w, h)
  const gray = toGray(ctx.getImageData(0, 0, w, h))
  const smooth = settings.blur > 0 ? boxBlur(gray, w, h, settings.blur) : gray
  const { mag, gx, gy } = sobel(smooth, w, h)
  const threshold = percentile(mag, settings.edgePercentile)
  const horizontal = twoPeaks(hough(mag, gx, gy, w, h, threshold, "horizontal", settings.thetaRangeDeg), h * settings.minSeparation)
  const vertical = twoPeaks(hough(mag, gx, gy, w, h, threshold, "vertical", settings.thetaRangeDeg), w * settings.minSeparation)
  if (!horizontal || !vertical) return null
  const corners = orderCorners([
    intersect(horizontal[0], vertical[0]), intersect(horizontal[0], vertical[1]),
    intersect(horizontal[1], vertical[0]), intersect(horizontal[1], vertical[1])
  ])
  if (!corners || !validQuad(corners, w, h, settings)) return null
  return corners.map(([x, y]) => [x / scale, y / scale])
}

export function boxBlur(gray, w, h, radius) {
  const out = new Float32Array(gray.length)
  const size = 2 * radius + 1
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let sum = 0
      for (let dy = -radius; dy <= radius; dy++) {
        const yy = Math.min(h - 1, Math.max(0, y + dy))
        for (let dx = -radius; dx <= radius; dx++) sum += gray[yy * w + Math.min(w - 1, Math.max(0, x + dx))]
      }
      out[y * w + x] = sum / (size * size)
    }
  }
  return out
}

export function sobel(gray, w, h) {
  const gx = new Float32Array(gray.length), gy = new Float32Array(gray.length), mag = new Float32Array(gray.length)
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const i = y * w + x
      const sx = -gray[i - w - 1] + gray[i - w + 1] - 2 * gray[i - 1] + 2 * gray[i + 1] - gray[i + w - 1] + gray[i + w + 1]
      const sy = -gray[i - w - 1] - 2 * gray[i - w] - gray[i - w + 1] + gray[i + w - 1] + 2 * gray[i + w] + gray[i + w + 1]
      gx[i] = sx; gy[i] = sy; mag[i] = Math.hypot(sx, sy)
    }
  }
  return { mag, gx, gy }
}

export function percentile(values, share) {
  const sorted = Float32Array.from(values).sort()
  return sorted[Math.min(sorted.length - 1, Math.floor(share * sorted.length))]
}

// Accumulates rho = x cos(theta) + y sin(theta) over edge pixels whose gradient points the right way:
// near-vertical gradients vote for horizontal lines (theta about 90 degrees), near-horizontal for vertical (theta about 0).
export function hough(mag, gx, gy, w, h, threshold, direction, rangeDeg) {
  const centre = direction === "horizontal" ? 90 : 0
  const thetas = []
  for (let d = -rangeDeg; d <= rangeDeg; d++) thetas.push(((centre + d) * Math.PI) / 180)
  const diag = Math.ceil(Math.hypot(w, h))
  const rhoBins = 2 * diag + 1
  const acc = new Uint32Array(thetas.length * rhoBins)
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = y * w + x
      if (mag[i] < threshold) continue
      const horizontalEdge = Math.abs(gy[i]) >= Math.abs(gx[i])
      if ((direction === "horizontal") !== horizontalEdge) continue
      for (let t = 0; t < thetas.length; t++) {
        const rho = Math.round(x * Math.cos(thetas[t]) + y * Math.sin(thetas[t])) + diag
        acc[t * rhoBins + rho]++
      }
    }
  }
  return { acc, thetas, rhoBins, diag }
}

// The strongest line, then the strongest line at least minSeparation away in rho; null if the second
// is weaker than a third of the first (no second edge of the card was found).
export function twoPeaks({ acc, thetas, rhoBins, diag }, minSeparation) {
  const peak = (exclude) => {
    let best = -1, bestValue = 0
    for (let i = 0; i < acc.length; i++) {
      if (acc[i] <= bestValue) continue
      const rho = (i % rhoBins) - diag
      if (exclude !== null && Math.abs(rho - exclude) < minSeparation) continue
      best = i; bestValue = acc[i]
    }
    return best < 0 ? null : { rho: (best % rhoBins) - diag, theta: thetas[Math.floor(best / rhoBins)], votes: bestValue }
  }
  const first = peak(null)
  if (!first) return null
  const second = peak(first.rho)
  if (!second || second.votes < first.votes / 3) return null
  return [ first, second ]
}

export function intersect(a, b) {
  const det = Math.cos(a.theta) * Math.sin(b.theta) - Math.sin(a.theta) * Math.cos(b.theta)
  if (Math.abs(det) < 1e-9) return null
  return [
    (a.rho * Math.sin(b.theta) - b.rho * Math.sin(a.theta)) / det,
    (b.rho * Math.cos(a.theta) - a.rho * Math.cos(b.theta)) / det
  ]
}

export function orderCorners(points) {
  if (points.some((p) => p === null)) return null
  const byY = [ ...points ].sort((p, q) => p[1] - q[1])
  const top = byY.slice(0, 2).sort((p, q) => p[0] - q[0]), bottom = byY.slice(2).sort((p, q) => p[0] - q[0])
  return [ top[0], top[1], bottom[1], bottom[0] ]
}

export function validQuad(corners, w, h, settings) {
  const margin = 0.05
  if (corners.some(([x, y]) => x < -margin * w || x > (1 + margin) * w || y < -margin * h || y > (1 + margin) * h)) return false
  let area = 0
  for (let i = 0; i < 4; i++) {
    const [x1, y1] = corners[i], [x2, y2] = corners[(i + 1) % 4]
    area += x1 * y2 - x2 * y1
  }
  area = Math.abs(area) / 2
  if (area < settings.minArea * w * h) return false
  const side = (p, q) => Math.hypot(q[0] - p[0], q[1] - p[1])
  const width = (side(corners[0], corners[1]) + side(corners[3], corners[2])) / 2
  const height = (side(corners[0], corners[3]) + side(corners[1], corners[2])) / 2
  const aspect = width / height
  return aspect >= settings.aspectRange[0] && aspect <= settings.aspectRange[1]
}
```

- [ ] Write `spikes/card_scanner/phase2/public/warp.js` (shared by both detectors: a homography from the output rectangle to the four corners, bilinear sampling, and the 3:4 picture with the card exactly in the guide's box):

```js
import { canvasOf } from "/canvas.js"

const CARD_ASPECT = 63 / 88
const STAGE_ASPECT = 3 / 4
const GUIDE_HEIGHT = 0.8 // geometry.js GUIDE.height: the card's share of a 3:4 picture's height

// Solves for the 8 parameters of the map (u, v) -> (x, y) taking the output rectangle's corners to the
// card's corners: x = (a u + b v + c) / (g u + h v + 1), y = (d u + e v + f) / (g u + h v + 1).
export function homography(width, height, corners) {
  const from = [ [0, 0], [width, 0], [width, height], [0, height] ]
  const rows = [], rhs = []
  for (let i = 0; i < 4; i++) {
    const [u, v] = from[i], [x, y] = corners[i]
    rows.push([u, v, 1, 0, 0, 0, -u * x, -v * x]); rhs.push(x)
    rows.push([0, 0, 0, u, v, 1, -u * y, -v * y]); rhs.push(y)
  }
  return solve(rows, rhs)
}

export function solve(a, b) {
  const n = b.length
  const m = a.map((row, i) => [ ...row, b[i] ])
  for (let col = 0; col < n; col++) {
    let pivot = col
    for (let r = col + 1; r < n; r++) if (Math.abs(m[r][col]) > Math.abs(m[pivot][col])) pivot = r
    ;[m[col], m[pivot]] = [m[pivot], m[col]]
    for (let r = col + 1; r < n; r++) {
      const f = m[r][col] / m[col][col]
      for (let c = col; c <= n; c++) m[r][c] -= f * m[col][c]
    }
  }
  const x = new Array(n).fill(0)
  for (let r = n - 1; r >= 0; r--) {
    let s = m[r][n]
    for (let c = r + 1; c < n; c++) s -= m[r][c] * x[c]
    x[r] = s / m[r][r]
  }
  return x
}

// Straightens the card into a width x height canvas with bilinear sampling and nothing else (AC-2.1).
export function warp(source, corners, width, height) {
  const src = source.getContext("2d", { willReadFrequently: true }).getImageData(0, 0, source.width, source.height)
  const [a, b, c, d, e, f, g, hh] = homography(width, height, corners)
  const out = new ImageData(width, height)
  const sw = source.width, sh = source.height, data = src.data, o = out.data
  for (let v = 0; v < height; v++) {
    for (let u = 0; u < width; u++) {
      const den = g * u + hh * v + 1
      const x = (a * u + b * v + c) / den, y = (d * u + e * v + f) / den
      const x0 = Math.max(0, Math.min(sw - 2, Math.floor(x))), y0 = Math.max(0, Math.min(sh - 2, Math.floor(y)))
      const fx = Math.max(0, Math.min(1, x - x0)), fy = Math.max(0, Math.min(1, y - y0))
      const i00 = (y0 * sw + x0) * 4, i01 = i00 + 4, i10 = i00 + sw * 4, i11 = i10 + 4
      const p = (v * width + u) * 4
      for (let ch = 0; ch < 3; ch++) {
        o[p + ch] = (data[i00 + ch] * (1 - fx) + data[i01 + ch] * fx) * (1 - fy) + (data[i10 + ch] * (1 - fx) + data[i11 + ch] * fx) * fy
      }
      o[p + 3] = 255
    }
  }
  const { canvas, ctx } = canvasOf(width, height)
  ctx.putImageData(out, 0, 0)
  return canvas
}

// The 3:4 picture the shipped photo path reads: the card fills the guide's box (80% of the height, 63:88,
// centred), the rest is one flat colour (a tuned setting).
export function picture(card, fill) {
  const height = Math.round(card.height / GUIDE_HEIGHT)
  const width = Math.round(height * STAGE_ASPECT)
  const { canvas, ctx } = canvasOf(width, height)
  ctx.fillStyle = fill
  ctx.fillRect(0, 0, width, height)
  const cardHeight = height * GUIDE_HEIGHT, cardWidth = cardHeight * CARD_ASPECT
  ctx.drawImage(card, (width - cardWidth) / 2, (height - cardHeight) / 2, cardWidth, cardHeight)
  return canvas
}
```

  The card's warp size (1008×1408) is 63:88 exactly, so `drawImage` in `picture` is a 1:1 placement for the default settings; if a tuning round changes the warp size to another 63:88 pair, it stays 1:1.

- [ ] Write `spikes/card_scanner/phase2/public/output.js`:

```js
import { pngBlob } from "/canvas.js"

export async function store(run, stem, name, canvas) {
  const response = await fetch(`/outputs/${run}/${stem}/${name}`, { method: "POST", body: await pngBlob(canvas), headers: { "Content-Type": "image/png" } })
  if (!response.ok) throw new Error(`Storing ${name} failed: HTTP ${response.status}`)
}
```

- [ ] Write `spikes/card_scanner/phase2/public/detect.js` (the page's contract with the driver; the OpenCV branch is filled in Phase 3, the fingerprint branch in Phase 6):

```js
import { sourceCanvas } from "/canvas.js"
import { detectHand } from "/hand_detector.js"
import { warp, picture } from "/warp.js"
import { store } from "/output.js"

const status = document.getElementById("status")
const settings = await (await fetch("/settings.json")).json()
const detectors = { hand: async (source) => detectHand(source, settings.hand) }

// Runs one photo: fetch it, detect, straighten, build the 3:4 picture, store both PNGs, and answer with
// the small JSON the driver records. `scale` is null (full size) or a picture height (the live stand-in).
async function run({ path, detector, scale, run: runName, stem, art }) {
  status.textContent = `${runName}: ${stem} (${detector})`
  const blob = await (await fetch(`/corpus/${path}`)).blob()
  const bitmap = await createImageBitmap(blob) // applies EXIF orientation
  const source = sourceCanvas(bitmap, scale)
  const t0 = performance.now()
  const corners = await detectors[detector](source)
  const msDetect = performance.now() - t0
  const result = { path, detector, scale: scale || null, sourceWidth: source.width, sourceHeight: source.height, found: Boolean(corners), corners, msDetect }
  if (corners) {
    const t1 = performance.now()
    const card = warp(source, corners, settings.warp.width, settings.warp.height)
    result.msWarp = performance.now() - t1
    const framed = picture(card, settings.warp.fill)
    await store(runName, stem, "card.png", card)
    await store(runName, stem, "picture.png", framed)
    result.picture = { width: framed.width, height: framed.height }
    document.getElementById("preview").getContext("2d").drawImage(framed, 0, 0, 330, 440)
  }
  return result
}

window.__phase2 = { ready: true, settings, run }
status.textContent = "Ready"
```

- [ ] Write `spikes/card_scanner/phase2/script/detect_run.rb`:

```ruby
# Drives the detect page over one half of the split, one photo at a time, and records each result with the
# run's provenance. The page stores card.png and picture.png through the spike server.
# Usage: SE_AVOID_STATS=true bundle exec ruby spikes/card_scanner/phase2/script/detect_run.rb \
#          --run dev-hand --half development --detector hand [--scale 1440] [--corpus phase0,new] [--files IMG_6688.jpeg,...]
#        SETTINGS_COMMIT=<sha> is required for --half held_out (AC-1.2). SPIKE_URL overrides http://127.0.0.1:4200.
require "bundler/setup"
require "optparse"
require "selenium-webdriver"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/split"
require "card_scanner_phase2/runs"

options = { corpus: CardScannerPhase2::CORPORA.keys, scale: nil, files: nil }
OptionParser.new do |parser|
  parser.on("--run NAME") { options[:run] = it }
  parser.on("--half HALF") { options[:half] = it }
  parser.on("--detector NAME") { options[:detector] = it }
  parser.on("--scale HEIGHT", Integer) { options[:scale] = it }
  parser.on("--corpus LIST") { options[:corpus] = it.split(",") }
  parser.on("--files LIST") { options[:files] = it.split(",") }
end.parse!
%i[run half detector].each { |key| abort "--#{key} is required" unless options[key] }

url = ENV.fetch("SPIKE_URL", "http://127.0.0.1:4200")
run_dir = CardScannerPhase2::Runs.start!(options[:run], half: options[:half])
split = CardScannerPhase2::Split.read
jobs = options[:corpus].flat_map do |corpus|
  files = split.fetch(corpus).fetch(options[:half])
  files = files & options[:files] if options[:files]
  files.map { |file| { corpus:, file:, path: File.join(File.dirname(CardScannerPhase2::CORPORA.fetch(corpus)[:manifest]), file).delete_prefix("./") } }
end
if options[:files] && (outside = options[:files] - jobs.map { it[:file] }).any?
  abort "Not in the #{options[:half]} half of the selected corpora: #{outside.join(", ")}" # AC-1.2: never run the other half by accident
end
abort "No photos selected" if jobs.empty?

RUN_JS = <<~JS.freeze
  const [ params, done ] = arguments
  window.__phase2.run(params).then((result) => done({ result }), (error) => done({ error: String(error && error.stack || error) }))
JS

driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
driver.manage.timeouts.script_timeout = 600
begin
  driver.navigate.to("#{url}/detect.html")
  Selenium::WebDriver::Wait.new(timeout: 120, interval: 0.5).until { driver.execute_script("return Boolean(window.__phase2 && window.__phase2.ready)") }
  jobs.each do |job|
    stem = File.basename(job[:file], ".*")
    answer = driver.execute_async_script(RUN_JS, { "path" => job[:path], "detector" => options[:detector], "scale" => options[:scale],
      "run" => options[:run], "stem" => stem })
    abort "#{job[:file]}: #{answer["error"]}" if answer["error"]
    result = answer["result"]
    abort "#{job[:file]}: the source is landscape (#{result["sourceWidth"]}x#{result["sourceHeight"]}); EXIF orientation wasn't applied" if result["sourceWidth"] > result["sourceHeight"]
    record = CardScannerPhase2::Runs.stamp(run_dir, result.merge("file" => job[:file], "corpus" => job[:corpus]))
    dir = run_dir.join(stem)
    dir.mkpath
    dir.join("detect.json").write(JSON.pretty_generate(record))
    puts format("%-14s %-7s %s %6.0f ms", job[:file], record["found"] ? "found" : "none", job[:corpus], record["msDetect"])
  end
ensure
  driver.quit
end
puts "#{jobs.size} photos -> #{run_dir}"
```

- [ ] Write `spikes/card_scanner/phase2/script/contact_sheet.rb` (sheets of 20 straightened cards with labels; photos a detector didn't find show as a labelled blank):

```ruby
# Builds contact sheets of a run's straightened cards for the by-eye classes (AC-2.4).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/contact_sheet.rb <run>
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"

run = ARGV.fetch(0) { abort "usage: contact_sheet.rb <run>" }
run_dir = CardScannerPhase2.runs_dir.join(run)
records = run_dir.glob("*/detect.json").map { JSON.parse(it.read) }.sort_by { it["file"] }
abort "No detect.json under #{run_dir}" if records.empty?
blank = run_dir.join("blank.png")
system("magick", "-size", "252x352", "xc:#dddddd", blank.to_s, exception: true)
records.each_slice(20).with_index(1) do |slice, page|
  args = slice.flat_map do |record|
    card = run_dir.join(File.basename(record["file"], ".*"), "card.png")
    [ "-label", "#{record["file"]}\n#{record["found"] ? "found" : "not found"}", (card.exist? ? card : blank).to_s ]
  end
  out = run_dir.join("contact-#{page}.png")
  system("magick", "montage", *args, "-tile", "5x4", "-geometry", "252x352+6+18", "-pointsize", "14", out.to_s, exception: true)
  puts out
end
```

- [ ] Write `spikes/card_scanner/phase2/README.md` with: the layout; how to start the server (`bundle exec puma -C spikes/card_scanner/phase2/puma.rb`); the fetch, detect, contact-sheet, reading, index and findings commands with their environment variables (filled in as later phases add them); where outputs land (`tmp/card_scanner_phase2/`, `~/card-scanner-corpus/runs/phase2/`); and the rule that held-out runs need `SETTINGS_COMMIT` and a clean tree.
- [ ] Commit: `feat(spike): add the detect page, the hand-written detector, the shared warp and the run driver`
- [ ] **Pilot (AC-1.6).** Start the server as a background task: `bundle exec puma -C spikes/card_scanner/phase2/puma.rb`; check `curl -s http://127.0.0.1:4200/settings.json | head -c 40`. Run five development photos, at least two from each corpus and including foils: `SE_AVOID_STATS=true bundle exec ruby spikes/card_scanner/phase2/script/detect_run.rb --run pilot-hand --half development --detector hand --files IMG_6688.jpeg,IMG_6689.jpeg,IMG_6704.jpeg,IMG_6755.jpeg,IMG_6758.jpeg` (all five are in the development half per `phase2_split.json`, as the plan review computed; the script aborts if any isn't). Expect five lines ending in `… ms` and `5 photos -> …/runs/phase2/pilot-hand`.
- [ ] Build the sheet: `bundle exec ruby spikes/card_scanner/phase2/script/contact_sheet.rb pilot-hand`. View `contact-1.png` and each `card.png` with the Read tool. For each found card, check the straightened image shows the whole card upright; for each not-found, view the photo and note why (edge contrast, hand, background). Also confirm `picture.png` is 1320×1760 with the card centred: `magick identify …/pilot-hand/IMG_6688/picture.png`.
- [ ] If the detector misses or mis-outlines a pilot photo, tune only the named knobs in `settings.json` (`hand.workWidth`, `blur`, `edgePercentile`, `thetaRangeDeg`, `minSeparation`, `minArea`, `aspectRange`), re-run the pilot under a new run name (`pilot-hand-2`, …), and record each round's change and effect for `research.md`. Stop when the five are as good as the knobs allow, or after four rounds.
- [ ] Commit: `chore(spike): tune the hand-written detector on the pilot photos` (only if `settings.json` changed; otherwise note "no change after the pilot" in the next commit body).

---
## Phase 3: The OpenCV.js detector, and its policy, size and licence checks

**Implements:** FR-2, Story 2 | **Satisfies:** AC-2.1 (OpenCV detector), AC-2.7, AC-2.8
**Files:** `spikes/card_scanner/phase2/public/{opencv_detector.js,detect.js}`, `script/sizes.rb`
**Interfaces:** Consumes: `/opencv/4.13.0/opencv.js`, `settings.opencv`; Produces: corners for `warp.js`; `sizes.json` under the work dir; the CSP finding

- [ ] Write `spikes/card_scanner/phase2/public/opencv_detector.js`:

```js
import { canvasOf } from "/canvas.js"
import { orderCorners, validQuad } from "/hand_detector.js"

let loading = null

// Loads the prebuilt build from this origin once. 4.x builds either expose `cv` as a Promise or fire
// `onRuntimeInitialized`; both are handled.
export function loadOpenCV(url) {
  loading ||= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = url
    script.onerror = () => reject(new Error(`Loading ${url} failed (see the server's csp-reports.jsonl)`))
    script.onload = async () => {
      try {
        let cv = window.cv
        if (cv instanceof Promise) cv = await cv
        else if (!cv.Mat) await new Promise((ready) => { cv.onRuntimeInitialized = ready })
        window.cv = cv
        resolve(cv)
      } catch (error) { reject(error) }
    }
    document.head.appendChild(script)
  })
  return loading
}

// Canny edges, the largest convex four-point contour, and the same ordering and checks as the hand detector.
export function detectOpenCV(cv, source, settings) {
  const scale = settings.workWidth / source.width
  const w = settings.workWidth, h = Math.round(source.height * scale)
  const { canvas, ctx } = canvasOf(w, h)
  ctx.drawImage(source, 0, 0, w, h)
  const src = cv.matFromImageData(ctx.getImageData(0, 0, w, h))
  const gray = new cv.Mat(), blurred = new cv.Mat(), edges = new cv.Mat(), dilated = new cv.Mat(), hierarchy = new cv.Mat()
  const kernel = cv.Mat.ones(3, 3, cv.CV_8U), contours = new cv.MatVector()
  let corners = null
  try {
    cv.cvtColor(src, gray, cv.COLOR_RGBA2GRAY)
    cv.GaussianBlur(gray, blurred, new cv.Size(settings.blur, settings.blur), 0)
    cv.Canny(blurred, edges, settings.canny[0], settings.canny[1])
    cv.dilate(edges, dilated, kernel)
    cv.findContours(dilated, contours, hierarchy, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE)
    const candidates = []
    for (let i = 0; i < contours.size(); i++) {
      const contour = contours.get(i)
      candidates.push({ index: i, area: cv.contourArea(contour) })
      contour.delete()
    }
    candidates.sort((p, q) => q.area - p.area)
    for (const { index, area } of candidates.slice(0, 10)) {
      if (area < settings.minArea * w * h) break
      const contour = contours.get(index), approx = new cv.Mat()
      cv.approxPolyDP(contour, approx, settings.approxEpsilon * cv.arcLength(contour, true), true)
      const points = approx.rows === 4 && cv.isContourConvex(approx) ? [0, 1, 2, 3].map((k) => [approx.data32S[2 * k], approx.data32S[2 * k + 1]]) : null
      approx.delete()
      contour.delete()
      if (!points) continue
      const ordered = orderCorners(points)
      if (validQuad(ordered, w, h, settings)) { corners = ordered; break }
    }
  } finally {
    ;[src, gray, blurred, edges, dilated, hierarchy, kernel].forEach((m) => m.delete())
    contours.delete()
  }
  return corners && corners.map(([x, y]) => [x / scale, y / scale])
}
```

- [ ] Edit `spikes/card_scanner/phase2/public/detect.js`: add `import { loadOpenCV, detectOpenCV } from "/opencv_detector.js"` and the detector entry `opencv: async (source) => detectOpenCV(await loadOpenCV("/opencv/4.13.0/opencv.js"), source, settings.opencv)`.
- [ ] **Policy check (AC-2.8).** With the server running under the default policy, run the same five pilot photos: `… detect_run.rb --run pilot-opencv --half development --detector opencv --files <same five>`. Expect either five result lines, or an abort naming the load error. In both cases read `tmp/card_scanner_phase2/logs/csp-reports.jsonl` (if it exists) and record every `violated-directive`. If it fails under the default policy, restart the server with `SPIKE_UNSAFE_EVAL=1`, run again as `pilot-opencv-eval`, and record that `script-src` would need `'unsafe-eval'` (or whatever the report names). This is the AC-2.8 finding; all later OpenCV runs use whichever policy works, and the findings say which.
- [ ] Build and view the contact sheet for `pilot-opencv` as in Phase 2; tune only `opencv.workWidth`, `blur` (must stay odd: `GaussianBlur` rejects an even kernel), `canny`, `approxEpsilon`, `minArea`, `aspectRange` on the five pilot photos, at most four rounds, recording each.
- [ ] Write `spikes/card_scanner/phase2/script/sizes.rb` (AC-2.7: files, stored and gzip sizes, per detector):

```ruby
# Reports each detector's files and their stored and gzip-compressed sizes (AC-2.7).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/sizes.rb
require "bundler/setup"
require "zlib"
require_relative "../lib/card_scanner_phase2"

shared = %w[canvas.js warp.js output.js detect.js].map { CardScannerPhase2::ROOT.join("public", it) }
detectors = {
  "hand" => shared + [ CardScannerPhase2::ROOT.join("public/hand_detector.js") ],
  "opencv" => shared + [ CardScannerPhase2::ROOT.join("public/hand_detector.js"), CardScannerPhase2::ROOT.join("public/opencv_detector.js"),
                         CardScannerPhase2::WORK_DIR.join("opencv/4.13.0/opencv.js") ]
}
report = detectors.to_h do |name, files|
  entries = files.map { |path| raw = path.binread; { "file" => path.basename.to_s, "raw" => raw.bytesize, "gzip" => Zlib::Deflate.deflate(raw, Zlib::BEST_COMPRESSION).bytesize } }
  [ name, { "files" => entries, "raw" => entries.sum { it["raw"] }, "gzip" => entries.sum { it["gzip"] } } ]
end
CardScannerPhase2::WORK_DIR.join("sizes.json").write(JSON.pretty_generate(report))
report.each { |name, r| puts format("%-7s %2d files  raw %10d  gzip %9d", name, r["files"].size, r["raw"], r["gzip"]) }
```

  (`opencv_detector.js` imports two helpers from `hand_detector.js`, so that file counts for both; the findings say so.)

- [ ] Run it. Expect two lines; `opencv` about 10.97 MB raw and 3.5 MB gzip, `hand` a few KB. Record for `research.md`, with the licences: OpenCV 4.13.0 is Apache-2.0 (compatible with AGPL-3.0: Apache-2.0 code may be combined into AGPL-3.0 works); the hand detector has no third-party component.
- [ ] Commit: `feat(spike): add the OpenCV.js detector and the policy and size checks`

---

## Phase 4: Derived corpora, reading runs, scoring and the development-half tuning

**Implements:** FR-2, Story 2 | **Satisfies:** AC-2.2, AC-2.3, AC-2.5, AC-2.6, AC-2.9, AC-2.4 (sheets and classes), AC-1.4 (development rates labelled biased)
**Files:** `spikes/card_scanner/phase2/lib/card_scanner_phase2/{derived_corpus,scoring}.rb`, `script/{truth_copies.rb,derive.rb,score.rb}`, `spec/card_scanner_phase2/{derived_corpus,scoring}_spec.rb`
**Interfaces:** Consumes: a detect run's `picture.png`s and `detect.json`s, the committed baseline fixtures, the ground-truth copies; Produces: `<run>/corpus/{manifest.csv,ground_truth.json,IMG_*.png}`, `<run>/measurement/…` (the shipped photo path's captures), `<run>/classes.json`, `<run>/score.{md,json}`

- [ ] Write `spikes/card_scanner/phase2/script/truth_copies.rb` (the spike's own ground-truth copies, AC-1.1: Phase 0's manifest with an `era` column that overrides only `IMG_6718`; the new corpus's manifest as it is):

```ruby
# Writes the spike's ground-truth copies under tmp/card_scanner_phase2/truth/<corpus>/ via the shipped task.
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/truth_copies.rb
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/derived_corpus"

CardScannerPhase2::CORPORA.each_key do |corpus|
  dir = CardScannerPhase2::WORK_DIR.join("truth", corpus)
  dir.mkpath
  manifest = dir.join("manifest.csv")
  manifest.write(CardScannerPhase2::DerivedCorpus.manifest_with_era(corpus))
  system("bin/rails", "scanner:ground_truth[#{manifest}]", chdir: CardScannerPhase2::REPO.to_s, exception: true)
  puts "#{corpus}: #{dir.join("ground_truth.json")}"
end
```

- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/derived_corpus_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/derived_corpus"
require "fileutils"
require "tmpdir"

RSpec.describe CardScannerPhase2::DerivedCorpus do
  let(:phase0) { "file,set,number,foil\nIMG_6718.jpeg,mat,71,no\nIMG_6690.jpeg,aaa,2,yes\n" }
  let(:new) { "file,set,number,foil,era\nIMG_6763.jpeg,mat,71,no,pre-M15\nIMG_6756.jpeg,iko,235,no,\n" }
  let(:texts) { { "phase0" => phase0, "new" => new } }
  let(:run) { Pathname(Dir.mktmpdir) }

  after { FileUtils.remove_entry(run) }

  def detection(file, corpus, found)
    stem = File.basename(file, ".*")
    run.join(stem).mkpath
    run.join(stem, "picture.png").binwrite("\x89PNG".b) if found
    run.join(stem, "detect.json").write({ "file" => file, "corpus" => corpus, "found" => found }.to_json)
  end

  it "adds an era column that overrides only the shared card's Phase 0 photo", :aggregate_failures do
    expect(described_class.manifest_with_era("phase0", texts:)).to eq("file,set,number,foil,era\nIMG_6718.jpeg,mat,71,no,pre-M15\nIMG_6690.jpeg,aaa,2,yes,\n")
    expect(described_class.manifest_with_era("new", texts:)).to eq(new)
  end

  it "writes a derived manifest of the found photos with png names, and copies their pictures", :aggregate_failures do
    detection("IMG_6718.jpeg", "phase0", true)
    detection("IMG_6690.jpeg", "phase0", false)
    detection("IMG_6756.jpeg", "new", true)
    written = described_class.write!(run, texts:)
    expect(written.join("manifest.csv").read).to eq("file,set,number,foil,era\nIMG_6718.png,mat,71,no,pre-M15\nIMG_6756.png,iko,235,no,\n")
    expect(written.join("IMG_6718.png").binread).to eq("\x89PNG".b)
    expect(written.join("IMG_6690.png")).not_to exist
    expect(described_class.not_found(run)).to eq([ { "file" => "IMG_6690.jpeg", "corpus" => "phase0" } ])
  end
end
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase2/spec/card_scanner_phase2/derived_corpus_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_phase2/derived_corpus`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/derived_corpus.rb`:

```ruby
require "fileutils"
require "card_scanner_phase2/split"

module CardScannerPhase2
  # Turns a detect run into a corpus the shipped photo path can read unchanged: one 3:4 picture per found
  # photo, named IMG_nnnn.png, beside a manifest with an era column (AC-1.1, AC-2.1). Photos the detector
  # didn't find are left out and scored as empty readings (AC-2.5).
  module DerivedCorpus
    ERA_OVERRIDES = { "phase0" => { "IMG_6718.jpeg" => "pre-M15" } }.freeze

    module_function

    def manifest_with_era(corpus, texts: Split.manifests)
      rows = Split.rows(texts.fetch(corpus))
      lines = rows.map do |row|
        era = ERA_OVERRIDES.dig(corpus, row["file"]) || row["era"].to_s
        [ row["file"], row["set"], row["number"], row["foil"], era ].join(",")
      end
      ([ "file,set,number,foil,era" ] + lines).join("\n") + "\n"
    end

    def detections(run_dir) = run_dir.glob("*/detect.json").map { JSON.parse(it.read) }.sort_by { it["file"] }

    def not_found(run_dir) = detections(run_dir).reject { it["found"] }.map { it.slice("file", "corpus") }

    def write!(run_dir, texts: Split.manifests)
      dir = run_dir.join("corpus")
      dir.mkpath
      rows = CORPORA.keys.flat_map { |corpus| Split.rows(manifest_with_era(corpus, texts:)).each { it["corpus"] = corpus } }.to_h { [ it["file"], it ] }
      lines = detections(run_dir).select { it["found"] }.map do |detection|
        row = rows.fetch(detection["file"])
        png = "#{File.basename(row["file"], ".*")}.png"
        FileUtils.cp(run_dir.join(File.basename(row["file"], ".*"), "picture.png"), dir.join(png))
        [ png, row["set"], row["number"], row["foil"], row["era"] ].join(",")
      end
      dir.join("manifest.csv").write(([ "file,set,number,foil,era" ] + lines).join("\n") + "\n")
      dir
    end
  end
end
```

- [ ] Run the spec again. Expect: 2 examples, 0 failures. `bin/rubocop spikes/`: no offenses.
- [ ] Write `spikes/card_scanner/phase2/script/derive.rb`:

```ruby
# Builds a detect run's derived corpus and its ground truth, and prints the environment for the reading run.
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/derive.rb <run>
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/derived_corpus"

run = ARGV.fetch(0) { abort "usage: derive.rb <run>" }
run_dir = CardScannerPhase2.runs_dir.join(run)
abort "#{run_dir} has no run.json" unless run_dir.join("run.json").exist?
corpus = CardScannerPhase2::DerivedCorpus.write!(run_dir)
system("bin/rails", "scanner:ground_truth[#{corpus.join("manifest.csv")}]", chdir: CardScannerPhase2::REPO.to_s, exception: true)
found = corpus.glob("*.png").size
puts "#{found} pictures, #{CardScannerPhase2::DerivedCorpus.not_found(run_dir).size} not found -> #{corpus}"
require_relative "#{CardScannerPhase2::REPO}/lib/collector/dev_port"
port = Collector::DevPort.resolve(root: CardScannerPhase2::REPO.to_s) # the port photo_run.rb defaults to (3204 in this worktree)
puts "Reading run:"
puts "  COLLECTOR_SCANNER_MANIFEST=#{corpus.join("manifest.csv")} COLLECTOR_SCANNER_RUN_DIR=#{run_dir.join("measurement")} bin/rails server -b 127.0.0.1 -p #{port}"
puts "  SE_AVOID_STATS=true SCANNER_EMAIL=phase2@localhost SCANNER_PASSWORD=… bundle exec ruby script/scanner/photo_run.rb"
```

- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/scoring_spec.rb` (Rails-backed, for the pure table logic over stub records; `rescore` itself is the shipped code and isn't re-tested):

```ruby
require "rails_helper"
require_relative "../phase2_helper"
require "card_scanner_phase2/scoring"

RSpec.describe CardScannerPhase2::Scoring, type: :model do
  def record(file, corpus, era: "MOM+", foil: false, final: [], names: [], status: "none", keys: [], key: "k", found: true, klass: nil)
    { "file" => file, "corpus" => corpus, "name" => "Right", "era" => era, "foil" => foil, "borderless_or_showcase" => false,
      "external_key" => key, "final_candidates" => final, "name_candidates" => names, "lookup" => { "status" => status, "external_keys" => keys },
      "found" => found, "class" => klass || (found ? "found" : "not_found") }
  end

  let(:run) do
    [ record("A.jpeg", "phase0", final: %w[Right], names: %w[Right], status: "one", keys: %w[k]),
      record("B.jpeg", "phase0", final: %w[Other Right], names: %w[Other]),
      record("C.jpeg", "new", found: false),
      record("D.jpeg", "new", era: "pre-M15", final: %w[Right], names: %w[Right]) ]
  end
  let(:baseline) { run.map { it.except("found", "class").merge("final_candidates" => [], "name_candidates" => [], "lookup" => { "status" => "none", "external_keys" => [] }) } }

  it "lays out the spec's rates per source, for both corpora together and each on its own", :aggregate_failures do
    tables = described_class.tables("Hand (dev, biased)" => run, "Baseline" => baseline)
    expect(tables.keys).to eq([ "both", "phase0", "new" ])
    both = tables["both"]
    expect(both).to include("| Top 1, final ranking | Group | Hand (dev, biased) | Baseline |", "| overall | all | 2/4 (50.0%) | 0/4 (0.0%) |")
    expect(both).to include("| Top 3, final ranking | Group | Hand (dev, biased) | Baseline |", "| overall | all | 3/4 (75.0%) | 0/4 (0.0%) |")
    expect(both).to include("| Exact printing (M15–ONE, MOM+) | Group | Hand (dev, biased) | Baseline |", "| overall | all | 1/3 (33.3%) | 0/3 (0.0%) |")
    expect(both).to include("| Top 3, name only | Group | Hand (dev, biased) | Baseline |", "| overall | all | 2/4 (50.0%) | 0/4 (0.0%) |")
    expect(both).to include("Lookup outcomes", "Detection: Hand (dev, biased) found 3, not_found 1")
    expect(both).not_to include("Detection: Baseline")
    expect(tables["new"]).to include("| overall | all | 1/2 (50.0%) | 0/2 (0.0%) |")
  end

  it "lists the misses with their class", :aggregate_failures do
    misses = described_class.misses(run)
    expect(misses.map { it["file"] }).to eq(%w[C.jpeg])
    expect(misses.first["class"]).to eq("not_found")
  end
end
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase2/spec/card_scanner_phase2/scoring_spec.rb`. Expect: FAIL (`cannot load such file -- card_scanner_phase2/scoring`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/scoring.rb` (needs Rails; `Collector::ScannerFindings` is autoloaded from `lib/`):

```ruby
require "card_scanner_phase2/derived_corpus"

module CardScannerPhase2
  # Scores a reading run with spec 007's rate definitions (Collector::ScannerFindings), with a baseline column
  # from the committed fixtures and, for the new corpus, the live column (AC-2.2, AC-2.3, AC-2.5).
  module Scoring
    FINDINGS = Collector::ScannerFindings
    RATES = {
      "Top 1, final ranking" => ->(r) { FINDINGS.in_top?(r, "final_candidates", 1) },
      "Top 3, final ranking" => ->(r) { FINDINGS.in_top?(r, "final_candidates", 3) },
      "Top 1, name only" => ->(r) { FINDINGS.in_top?(r, "name_candidates", 1) },
      "Top 3, name only" => ->(r) { FINDINGS.in_top?(r, "name_candidates", 3) }
    }.freeze
    EMPTY_CAPTURE = { "name_text" => "", "collector_text" => "", "ms" => 0, "user_agent" => "none (not found)", "captured_at" => nil }.freeze

    module_function

    # One record per photo of the half: the shipped rescore over the measurement captures (keyed back to the
    # original file name), plus an empty reading for every photo the detector didn't find.
    def records(run_dir, truths:, measured_captures:)
      detections = DerivedCorpus.detections(run_dir).to_h { [ it["file"], it ] }
      classes = run_dir.join("classes.json").then { it.exist? ? JSON.parse(it.read) : {} }
      derived_truth = JSON.parse(run_dir.join("corpus/ground_truth.json").read).fetch("photos").to_h { [ it["file"], it ] }
      read = FINDINGS.rescore(derived_truth, measured_captures).map { it.merge("file" => "#{File.basename(it["file"], ".*")}.jpeg") }
      missing = detections.values.reject { it["found"] }.map do |detection|
        truth = truths.fetch(detection["corpus"]).fetch(detection["file"])
        FINDINGS.rescore({ detection["file"] => truth }, [ EMPTY_CAPTURE.merge("file" => detection["file"]) ]).first
      end
      (read + missing).map do |record|
        detection = detections.fetch(record["file"])
        record.merge(detection.slice("corpus", "found", "msDetect", "msWarp", "run", "half", "recorded_at", "code_commit", "settings_commit", "tree_clean"))
          .merge("class" => classes.fetch(record["file"], detection["found"] ? "found" : "not_found"))
      end.sort_by { it["file"] }
    end

    # The same photos' text from a committed fixture, rescored against the spike's ground-truth copy.
    def fixture_records(fixture, truth, files)
      results = JSON.parse(FIXTURE_DIR.join(fixture).read).fetch("results").select { files.include?(it["file"]) }
      FINDINGS.rescore(truth, results)
    end

    def tables(sources)
      { "both" => markdown(sources), "phase0" => markdown(sources.transform_values { |rs| rs.select { it["corpus"] == "phase0" } }),
        "new" => markdown(sources.transform_values { |rs| rs.select { it["corpus"] == "new" } }) }
    end

    def markdown(sources)
      parts = RATES.map { |title, hit| FINDINGS.comparison(title, sources, &hit) }
      set_line = sources.transform_values { |rs| rs.select { FINDINGS::SET_LINE_ERAS.include?(it["era"]) } }
      parts << FINDINGS.comparison("Exact printing (M15–ONE, MOM+)", set_line) { FINDINGS.printing_identified?(it) }
      parts << "Lookup outcomes (M15–ONE, MOM+): " + set_line.map { |label, rs| "#{label} #{rs.map { it.dig("lookup", "status") }.tally.sort.to_h}" }.join("; ")
      detected = sources.select { |_, rs| rs.any? { it.key?("class") } }
      parts << "Detection: " + detected.map { |label, rs| "#{label} #{rs.map { it["class"] }.tally.sort.map { |k, n| "#{k} #{n}" }.join(", ")}" }.join("; ") if detected.any?
      parts.join("\n\n")
    end

    def misses(records) = records.reject { FINDINGS.in_top?(it, "final_candidates", 3) }

    def timings(records)
      found = records.select { it["found"] }
      { "detect" => summary(records.map { it["msDetect"] }.compact), "warp" => summary(found.map { it["msWarp"] }.compact), "ocr" => summary(found.map { it["ms"] }.compact) }
    end

    def summary(values) = values.empty? ? nil : { "n" => values.size, "median" => FINDINGS.percentile(values, 50).round(1), "max" => values.max.round(1) }
  end
end
```

- [ ] Run the spec again. Expect: 2 examples, 0 failures. `bin/rubocop spikes/`: no offenses.
- [ ] Write `spikes/card_scanner/phase2/script/score.rb` (runs under `bin/rails runner`, so the catalog and the shipped matcher are loaded):

```ruby
# Scores a reading run: the run's records, the baseline from the committed fixtures, and for the new corpus the
# live captures on the same cards; writes score.md (tables, misses, timings) and score.json (records).
# Usage: bin/rails runner spikes/card_scanner/phase2/script/score.rb <run> [<label>]
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "card_scanner_phase2"
require "card_scanner_phase2/runs"
require "card_scanner_phase2/derived_corpus"
require "card_scanner_phase2/scoring"

run = ARGV.fetch(0) { abort "usage: score.rb <run> [<label>]" }
run_dir = CardScannerPhase2.runs_dir.join(run)
provenance = CardScannerPhase2::Runs.read(run_dir)
label = ARGV.fetch(1) { "#{run} (#{provenance["half"] == "development" ? "development, biased" : "held out"})" }

Rails.configuration.x.scanner_measurement = { manifest: run_dir.join("corpus/manifest.csv").to_s, dir: run_dir.join("measurement").to_s }
captures = Scanner::MeasurementRun.current.measured_captures
truths = CardScannerPhase2::CORPORA.keys.to_h do |corpus|
  [ corpus, JSON.parse(CardScannerPhase2::WORK_DIR.join("truth", corpus, "ground_truth.json").read).fetch("photos").to_h { [ it["file"], it ] } ]
end
records = CardScannerPhase2::Scoring.records(run_dir, truths:, measured_captures: captures)
files = records.group_by { it["corpus"] }.transform_values { |rs| rs.map { it["file"] } }
tag = ->(rs, corpus) { rs.map { it.merge("corpus" => corpus) } }
baseline = tag.(CardScannerPhase2::Scoring.fixture_records("phase1_photos_ocr_results.json", truths["phase0"], files.fetch("phase0", [])), "phase0") +
  tag.(CardScannerPhase2::Scoring.fixture_records("phase1_live_photos_ocr_results.json", truths["new"], files.fetch("new", [])), "new")
sources = { label => records, "Baseline: shipped photo path, same photos" => baseline }
if files["new"]
  sources["Live capture, same cards (spec 007)"] = tag.(CardScannerPhase2::Scoring.fixture_records("phase1_live_ocr_results.json", truths["new"], files["new"]), "new")
end

tables = CardScannerPhase2::Scoring.tables(sources)
misses = CardScannerPhase2::Scoring.misses(records)
timings = CardScannerPhase2::Scoring.timings(records)
md = [ "# #{label}", "Run: #{run} · half: #{provenance["half"]} · code: #{provenance["code_commit"]} · settings: #{provenance["settings_commit"]} · tree clean: #{provenance["tree_clean"]}",
  "Catalog: #{Catalog::RefreshRun.where(collectible_type: "mtg", status: "applied").order(:started_at).last&.source_version}",
  "## Both corpora", tables["both"], "## Phase 0", tables["phase0"], "## New corpus", tables["new"],
  "## Misses (not in the final top 3)", "| File | Expected | Class | Name read | Collector read | Top 3 |", "|---|---|---|---|---|---|",
  *misses.map { "| #{it["file"]} | #{it["name"]} | #{it["class"]} | #{it["name_text"].to_s.tr("\n|", " /")[0, 60]} | #{it["collector_text"].to_s.tr("\n|", " /")[0, 60]} | #{Array(it["final_candidates"]).join("; ")} |" },
  "## Timings (desktop)", timings.to_json ].join("\n\n")
run_dir.join("score.md").write(md)
run_dir.join("score.json").write(JSON.pretty_generate("label" => label, "provenance" => provenance, "records" => records, "timings" => timings))
puts md
```

- [ ] **Pilot the reading chain (AC-1.6)** on the five pilot photos before any full run: `derive.rb pilot-hand` (expect up to `5 pictures`), `truth_copies.rb` (expect two paths), then the dev server with the printed environment, `photo_run.rb` (expect `Stored N captures`), stop the server, `bin/rails runner … score.rb pilot-hand`. Expect tables over 5 records. If a picture isn't read at all (both strips empty for a found card), check `picture.png` against the guide geometry (card 1008×1408 at (156, 176) in 1320×1760) before going on; record what the pilot changed.
- [ ] **First full development run, hand detector.** Server running. `detect_run.rb --run dev-hand-1 --half development --detector hand`. Expect 52 lines. Then `derive.rb dev-hand-1` (expect `N pictures, M not found`). Then `truth_copies.rb` once (expect two paths). Start the dev server as a background task with the printed environment (`COLLECTOR_SCANNER_MANIFEST=… COLLECTOR_SCANNER_RUN_DIR=… bin/rails server -b 127.0.0.1 -p 3204`), check `curl -s http://127.0.0.1:3204/up`, then run `photo_run.rb` with the Phase 0 user. Expect `Stored N captures`. Stop the dev server (TaskStop). Score: `bin/rails runner spikes/card_scanner/phase2/script/score.rb dev-hand-1`. Expect the three table sets and a miss list.
- [ ] Build the contact sheets (`contact_sheet.rb dev-hand-1`), view each with the Read tool, and write `…/dev-hand-1/classes.json` as `{"IMG_6688.jpeg": "found" | "not_found" | "wrong_outline", …}` for every photo, where *found* means the straightened image shows the whole card and nothing else fills it, *not found* is the detector's own answer, and *wrong outline* is anything else (part of the card, the hand, the table). Re-run `score.rb` so the classes join the records.
- [ ] **Same for OpenCV:** `dev-opencv-1` → derive → reading run → score → sheets → classes.
- [ ] **Tuning rounds (development half only).** Read both `score.md`s and the misses. Change only the named knobs in `settings.json` (`hand.*`, `opencv.*`, `warp.width/height` as a 63:88 pair, `warp.fill`), one round at a time, re-running detect → derive → reading → score as `dev-<detector>-<n>`. Keep a table of rounds (settings changed, found count, top 3 final) for `research.md`. Stop when a round changes the top-3 count by at most 1 for both detectors, or after five rounds. Commit each round: `chore(spike): tuning round <n>: <what changed>`.
- [ ] **Stand-in runs (AC-2.6):** at the current settings, `detect_run.rb --run dev-hand-scaled --half development --detector hand --corpus phase0 --scale 1440` and the OpenCV twin; derive, reading run, score each. These are the Phase 0 development photos at 1080×1440.
- [ ] Commit: `chore(spike): record the development-half reading runs` (the `score.md` files stay outside the repo; the commit carries the round table in `research.md`'s draft section or in the commit body).

---
## Phase 5: The art index: bulk artworks, the throttled fetch with its estimate checkpoint, the fingerprint and the index

**Implements:** FR-3, Story 4 | **Satisfies:** AC-4.1, AC-4.2, AC-4.3, AC-4.4, AC-4.5 (the tool and its cost), AC-4.7, AC-4.8
**Files:** `spikes/card_scanner/phase2/lib/card_scanner_phase2/{ppm,fingerprint,bulk_artworks,art_fetcher,art_index}.rb`, `script/{artworks.rb,fetch_art.rb,build_index.rb}`, `spec/card_scanner_phase2/{ppm,fingerprint,bulk_artworks,art_fetcher,art_index}_spec.rb`
**Interfaces:** Consumes: `storage/catalog/mtg/default-cards-<stamp>.jsonl.gz` (read at run time by a script), `https://cards.scryfall.io/<size>/front/…`; Produces: `tmp/card_scanner_phase2/{artworks.json,entries.json,names.json}`, `artwork/<size>/<illustration_id>.jpg`, `fetch_estimate.json`, `fetch_<size>.json`, `index/art_index.bin`, `index/art_index_meta.json`

- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/ppm_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/ppm"

RSpec.describe CardScannerPhase2::Ppm do
  it "parses a binary P6 image into width, height and RGB bytes", :aggregate_failures do
    image = described_class.parse("P6\n2 1\n255\n".b + [ 255, 0, 0, 0, 0, 255 ].pack("C*"))
    expect([ image.width, image.height ]).to eq([ 2, 1 ])
    expect(image.rgb(0, 0)).to eq([ 255, 0, 0 ])
    expect(image.rgb(1, 0)).to eq([ 0, 0, 255 ])
  end

  it "refuses anything but 8-bit P6" do
    expect { described_class.parse("P3\n1 1\n255\n0 0 0") }.to raise_error(ArgumentError, /P6/)
  end
end
```

- [ ] Run it. Expect: FAIL (`cannot load such file -- card_scanner_phase2/ppm`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/ppm.rb`:

```ruby
module CardScannerPhase2
  # Raw 8-bit RGB pixels from `magick <file> -depth 8 ppm:-`, the only decoding step outside pure Ruby.
  module Ppm
    Image = Struct.new(:width, :height, :data) do
      def rgb(x, y)
        offset = (y * width + x) * 3
        [ data.getbyte(offset), data.getbyte(offset + 1), data.getbyte(offset + 2) ]
      end
    end

    module_function

    def parse(bytes)
      header = bytes.b.match(/\AP6\s+(\d+)\s+(\d+)\s+(\d+)\s/) or raise ArgumentError, "expected a binary 8-bit P6 image"
      raise ArgumentError, "expected 8-bit P6 (maxval 255)" unless header[3] == "255"

      width, height = header[1].to_i, header[2].to_i
      data = bytes.b.byteslice(header[0].bytesize, width * height * 3)
      raise ArgumentError, "short P6 data" unless data.bytesize == width * height * 3

      Image.new(width, height, data)
    end

    def decode(path, magick: "magick")
      out = IO.popen([ magick, path.to_s, "-depth", "8", "ppm:-" ], "rb", &:read)
      raise ArgumentError, "#{magick} failed on #{path}" unless $?.success?

      parse(out)
    end
  end
end
```

- [ ] Run the spec again. Expect: 2 examples, 0 failures.
- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/fingerprint_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/settings"
require "card_scanner_phase2/ppm"
require "card_scanner_phase2/fingerprint"

RSpec.describe CardScannerPhase2::Fingerprint do
  let(:settings) { CardScannerPhase2::Settings.load.fetch("fingerprint") }

  # A 100x140 image whose red channel rises left to right, green top to bottom, blue constant.
  let(:image) do
    data = +"".b
    140.times { |y| 100.times { |x| data << [ (x * 255) / 99, (y * 255) / 139, 128 ].pack("C*") } }
    CardScannerPhase2::Ppm::Image.new(100, 140, data)
  end

  it "resamples a box by area into the grid, keeping the gradient", :aggregate_failures do
    r, g, b = described_class.area_resample(image, 14.0, 22.4, 86.0, 70.0, 17, 16)
    expect(r.size).to eq(17 * 16)
    expect(r[0]).to be < r[16]
    expect(g[0]).to be < g[15 * 17]
    expect(b.uniq.map(&:round)).to eq([ 128 ])
  end

  it "hashes four planes into 128 bytes with neighbour comparisons", :aggregate_failures do
    hash = described_class.hash(image, settings, settings["offsets"].first)
    expect(hash.bytesize).to eq(128)
    red_plane = hash.byteslice(96, 32)
    expect(red_plane.unpack1("B*")).to eq("1" * 256) # red rises to the right, so every neighbour comparison is true
    blue_plane = hash.byteslice(32, 32)
    expect(blue_plane.unpack1("B*")).to eq("0" * 256) # blue is flat, so none is
  end

  it "computes six offset hashes, all distinct boxes", :aggregate_failures do
    boxes = settings["offsets"].map { described_class.box(100, 140, settings["box"], it) }
    expect(boxes.uniq.size).to eq(6)
    expect(described_class.hashes(image, settings).size).to eq(6)
  end

  it "measures Hamming distance", :aggregate_failures do
    a = ([ 0xFF ] * 128).pack("C*")
    b = ([ 0xFF ] * 127 + [ 0x0F ]).pack("C*")
    expect(described_class.hamming(a, a)).to eq(0)
    expect(described_class.hamming(a, b)).to eq(4)
  end
end
```

- [ ] Run it. Expect: FAIL (`cannot load such file -- card_scanner_phase2/fingerprint`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/fingerprint.rb` (the roadmap's published fingerprint; the same arithmetic, in the same order, as `fingerprint.js`):

```ruby
module CardScannerPhase2
  # The art fingerprint: the art region (y 16–50%, x 14–86% of the card), resampled by area to 17x16, four
  # planes (grey, blue, green, red), each a 256-bit difference hash of horizontal neighbours; 1,024 bits.
  # A query tries six offset boxes and keeps the smallest distance (spec Constraints).
  module Fingerprint
    POPCOUNT = Array.new(65_536) { |i| i.to_s(2).count("1") }.freeze

    module_function

    # The crop box in pixels for an offset: dx/dy shift by a share of the card, inset shrinks every side.
    def box(width, height, box, offset)
      inset = offset["inset"].to_f
      bw, bh = box["x1"] - box["x0"], box["y1"] - box["y0"]
      x0 = (box["x0"] + offset["dx"].to_f + inset * bw) * width
      x1 = (box["x1"] + offset["dx"].to_f - inset * bw) * width
      y0 = (box["y0"] + offset["dy"].to_f + inset * bh) * height
      y1 = (box["y1"] + offset["dy"].to_f - inset * bh) * height
      [ x0, y0, x1, y1 ]
    end

    # Area resampling: each output cell averages the source pixels it overlaps, weighted by the overlap.
    def area_resample(image, x0, y0, x1, y1, cols, rows)
      cell_w, cell_h = (x1 - x0) / cols, (y1 - y0) / rows
      r, g, b = Array.new(cols * rows, 0.0), Array.new(cols * rows, 0.0), Array.new(cols * rows, 0.0)
      rows.times do |j|
        cy0, cy1 = y0 + j * cell_h, y0 + (j + 1) * cell_h
        cols.times do |i|
          cx0, cx1 = x0 + i * cell_w, x0 + (i + 1) * cell_w
          sr = sg = sb = 0.0
          weight = 0.0
          (cy0.floor.clamp(0, image.height - 1)..(cy1.ceil - 1).clamp(0, image.height - 1)).each do |py|
            wy = [ cy1, py + 1 ].min - [ cy0, py ].max
            next if wy <= 0
            (cx0.floor.clamp(0, image.width - 1)..(cx1.ceil - 1).clamp(0, image.width - 1)).each do |px|
              wx = [ cx1, px + 1 ].min - [ cx0, px ].max
              next if wx <= 0
              w = wx * wy
              pr, pg, pb = image.rgb(px, py)
              sr += pr * w
              sg += pg * w
              sb += pb * w
              weight += w
            end
          end
          k = j * cols + i
          r[k], g[k], b[k] = sr / weight, sg / weight, sb / weight
        end
      end
      [ r, g, b ]
    end

    def dhash(plane, cols, rows)
      bits = +""
      rows.times { |j| (cols - 1).times { |i| bits << (plane[j * cols + i + 1] > plane[j * cols + i] ? "1" : "0") } }
      [ bits ].pack("B*")
    end

    def hash(image, settings, offset)
      cols, rows = settings["grid"]
      x0, y0, x1, y1 = box(image.width, image.height, settings["box"], offset)
      r, g, b = area_resample(image, x0, y0, x1, y1, cols, rows)
      grey = r.each_index.map { 0.299 * r[it] + 0.587 * g[it] + 0.114 * b[it] }
      [ grey, b, g, r ].map { dhash(it, cols, rows) }.join
    end

    def hashes(image, settings) = settings["offsets"].map { hash(image, settings, it) }

    def hamming(a, b)
      words_a, words_b = a.unpack("n*"), b.unpack("n*")
      words_a.each_index.sum { POPCOUNT[words_a[it] ^ words_b[it]] }
    end
  end
end
```

- [ ] Run the spec again. Expect: 4 examples, 0 failures. `bin/rubocop spikes/`: no offenses.
- [ ] Commit: `feat(spike): add the P6 decoder and the art fingerprint`
- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/bulk_artworks_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/bulk_artworks"
require "tmpdir"
require "zlib"

RSpec.describe CardScannerPhase2::BulkArtworks do
  def card(id:, name:, lang: "en", digital: false, games: %w[paper], layout: "normal", illustration: nil, faces: nil, set: "aaa", number: "1")
    record = { "id" => id, "name" => name, "lang" => lang, "digital" => digital, "games" => games, "layout" => layout, "set" => set, "collector_number" => number }
    record["illustration_id"] = illustration if illustration
    record["image_uris"] = { "small" => "https://cards.scryfall.io/small/front/#{id}.jpg", "normal" => "https://cards.scryfall.io/normal/front/#{id}.jpg" } unless faces
    record["card_faces"] = faces if faces
    record
  end

  let(:lines) do
    [ card(id: "p1", name: "Bolt", illustration: "art-1"),
      card(id: "p2", name: "Bolt", illustration: "art-1", set: "bbb"),
      card(id: "p3", name: "Bolt", illustration: "art-2"),
      card(id: "p4", name: "Bolt", illustration: "art-1", lang: "ja"),
      card(id: "p5", name: "Arena Bolt", illustration: "art-3", digital: true),
      card(id: "p6", name: "Online Bolt", illustration: "art-4", games: %w[mtgo]),
      card(id: "p7", name: "Front // Back", layout: "transform",
        faces: [ { "name" => "Front", "illustration_id" => "art-5", "image_uris" => { "small" => "https://cards.scryfall.io/small/front/p7.jpg", "normal" => "n" } },
                 { "name" => "Back", "illustration_id" => "art-6", "image_uris" => { "small" => "https://cards.scryfall.io/small/back/p7.jpg", "normal" => "n" } } ]),
      card(id: "p8", name: "No Art") ]
  end

  it "keeps the entries the catalog imports and one front-face artwork per illustration id", :aggregate_failures do
    Dir.mktmpdir do |dir|
      path = Pathname(dir).join("default-cards-20261003000000.jsonl.gz")
      Zlib::GzipWriter.open(path.to_s) { |gz| lines.each { gz.puts(it.to_json) } }
      result = described_class.read(path)
      expect(result["bulk_version"]).to eq("default-cards-20261003000000")
      expect(result["counts"]).to eq("entries" => 5, "with_artwork" => 4, "without_artwork" => 1, "artworks" => 3)
      expect(result["artworks"].keys).to contain_exactly("art-1", "art-2", "art-5")
      expect(result["artworks"]["art-1"]).to eq("printing" => "p1", "name" => "Bolt", "small" => "https://cards.scryfall.io/small/front/p1.jpg",
        "normal" => "https://cards.scryfall.io/normal/front/p1.jpg", "entries" => 2)
      expect(result["entries"]).to eq("p1" => "art-1", "p2" => "art-1", "p3" => "art-2", "p7" => "art-5", "p8" => nil)
      expect(result["names"]).to eq("Bolt" => 3, "Front // Back" => 1, "No Art" => 1)
    end
  end
end
```

- [ ] Run it. Expect: FAIL (`cannot load such file -- card_scanner_phase2/bulk_artworks`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/bulk_artworks.rb`:

```ruby
require "zlib"

module CardScannerPhase2
  # Reads the Scryfall bulk file the catalog was built from and lists one front-face artwork per distinct
  # illustration id among the entries the catalog imports (AC-4.1): lang en, not digital, paper, the same
  # filter as MTG::Scryfall::Mapper.paper?. The first printing in file order stands for each artwork.
  module BulkArtworks
    module_function

    def latest_bulk_file(dir = REPO.join("storage/catalog/mtg")) = dir.glob("default-cards-*.jsonl.gz").max_by(&:mtime) or raise "no bulk file under #{dir}"

    def imported?(card) = card["lang"] == "en" && !card["digital"] && Array(card["games"]).include?("paper")

    def read(path)
      artworks, entries, names = {}, {}, Hash.new(0)
      counts = Hash.new(0)
      Zlib::GzipReader.open(path.to_s) do |gz|
        gz.each_line do |line|
          next if line.strip.empty?
          card = JSON.parse(line)
          next unless imported?(card)

          counts["entries"] += 1
          names[card["name"]] += 1
          front = Array(card["card_faces"]).first || card
          illustration = front["illustration_id"] || card["illustration_id"]
          entries[card["id"]] = illustration
          counts[illustration ? "with_artwork" : "without_artwork"] += 1
          next unless illustration

          uris = front["image_uris"] || card["image_uris"] || {}
          artworks[illustration] ||= { "printing" => card["id"], "name" => card["name"], "small" => uris["small"], "normal" => uris["normal"], "entries" => 0 }
          artworks[illustration]["entries"] += 1
        end
      end
      counts["artworks"] = artworks.size
      { "bulk_version" => File.basename(path.to_s, ".jsonl.gz"), "counts" => counts.sort.to_h, "artworks" => artworks, "entries" => entries, "names" => names }
    end

    def write!(result, dir = WORK_DIR)
      dir.mkpath
      dir.join("artworks.json").write(JSON.generate(result.slice("bulk_version", "counts", "artworks")))
      dir.join("entries.json").write(JSON.generate(result["entries"]))
      dir.join("names.json").write(JSON.generate(result["names"]))
    end

    def load(dir = WORK_DIR) = JSON.parse(dir.join("artworks.json").read).merge("entries" => JSON.parse(dir.join("entries.json").read), "names" => JSON.parse(dir.join("names.json").read))
  end
end
```

- [ ] Run the spec again. Expect: 1 example, 0 failures. `bin/rubocop spikes/`: no offenses.
- [ ] Write `spikes/card_scanner/phase2/script/artworks.rb`:

```ruby
# Lists the artworks of the entries the catalog imports from the bulk file the app downloaded (AC-4.1).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/artworks.rb
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/bulk_artworks"

path = CardScannerPhase2::BulkArtworks.latest_bulk_file
result = CardScannerPhase2::BulkArtworks.read(path)
CardScannerPhase2::BulkArtworks.write!(result)
puts "#{result["bulk_version"]}: #{result["counts"]}"
```

- [ ] Run it. Expect one line, e.g. `default-cards-2026…: {"artworks"=>N, "entries"=>~106,600, "with_artwork"=>…, "without_artwork"=>…}`. Record every number for `research.md` (AC-4.1).
- [ ] Commit: `feat(spike): list the catalog's artworks from the bulk file`
- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/art_fetcher_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/art_fetcher"
require "fileutils"
require "tmpdir"

RSpec.describe CardScannerPhase2::ArtFetcher do
  before { stub_const("Response", Struct.new(:code, :body, :headers) { def [](name) = headers[name] }) }

  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:clock) { [ 0.0 ] }
  let(:sleeps) { [] }
  let(:requests) { [] }
  let(:fetcher) do
    described_class.new(dir:, size: "small", http: ->(url, headers) { requests << [ url, headers ]; responses.shift },
      sleeper: ->(seconds) { sleeps << seconds; clock[0] += seconds }, clock: -> { clock[0] })
  end

  after { FileUtils.remove_entry(dir) }

  context "with ordinary responses" do
    let(:responses) { [ Response.new("200", "jpg-a".b, {}), Response.new("200", "jpg-b".b, {}) ] }

    it "fetches each artwork with the headers the rules name, at least 100 ms apart, into the cache", :aggregate_failures do
      stats = fetcher.fetch({ "a" => { "small" => "https://cards.scryfall.io/small/front/a.jpg" }, "b" => { "small" => "https://cards.scryfall.io/small/front/b.jpg" } })
      expect(requests.map(&:first)).to eq(%w[https://cards.scryfall.io/small/front/a.jpg https://cards.scryfall.io/small/front/b.jpg])
      expect(requests.first.last).to include("User-Agent" => a_string_including("Collector"), "Accept" => "image/jpeg")
      expect(sleeps).to all(be >= 0.1)
      expect(dir.join("small/a.jpg").binread).to eq("jpg-a".b)
      expect(stats).to include("fetched" => 2, "bytes" => 10, "skipped" => 0, "failed" => [])
    end

    it "skips artworks already in the cache" do
      dir.join("small").mkpath
      dir.join("small/a.jpg").binwrite("cached")
      stats = fetcher.fetch({ "a" => { "small" => "u" }, "b" => { "small" => "https://cards.scryfall.io/small/front/b.jpg" } })
      expect(stats).to include("fetched" => 1, "skipped" => 1)
    end
  end

  context "with a rate-limited host" do
    let(:responses) { [ Response.new("429", "", { "retry-after" => "2" }), Response.new("429", "", {}), Response.new("429", "", {}) ] }

    it "backs off on 429 using Retry-After, then gives up after three attempts", :aggregate_failures do
      stats = fetcher.fetch({ "a" => { "small" => "u" } })
      expect(sleeps).to include(2.0, 4.0)
      expect(stats["failed"]).to eq([ { "id" => "a", "error" => "HTTP 429 after 3 attempts" } ])
      expect(dir.join("small/a.jpg")).not_to exist
    end
  end
end
```

- [ ] Run it. Expect: FAIL (`cannot load such file -- card_scanner_phase2/art_fetcher`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/art_fetcher.rb`:

```ruby
require "net/http"
require "uri"

module CardScannerPhase2
  # Fetches one image per artwork from Scryfall's image host with the project's manners (AC-4.7): a
  # descriptive User-Agent and Accept, at least 100 ms between requests, explicit timeouts, back-off on 429,
  # and a disk cache so a re-run fetches nothing twice. Failures after the retries are listed, not raised (AC-4.8).
  class ArtFetcher
    USER_AGENT = "Collector card scanner spike (+https://github.com/plainprogrammer/Collector)"
    MIN_INTERVAL = 0.1
    MAX_ATTEMPTS = 3

    def initialize(dir:, size:, http: method(:request), sleeper: method(:sleep), clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @dir, @size, @http, @sleeper, @clock = Pathname(dir).join(size), size, http, sleeper, clock
      @last = nil
    end

    def path_for(id) = @dir.join("#{id}.jpg")

    # artworks: { illustration_id => { "small" => url, "normal" => url } }. Returns the run's statistics.
    def fetch(artworks, limit: nil)
      @dir.mkpath
      stats = { "size" => @size, "fetched" => 0, "bytes" => 0, "skipped" => 0, "seconds" => 0.0, "failed" => [] }
      started = @clock.call
      artworks.each do |id, urls|
        break if limit && stats["fetched"] >= limit
        if path_for(id).file? && path_for(id).size.positive?
          stats["skipped"] += 1
          next
        end
        body = fetch_one(urls.fetch(@size))
        stats["fetched"] += 1
        stats["bytes"] += body.bytesize
        write(path_for(id), body)
      rescue FetchError => error
        stats["failed"] << { "id" => id, "error" => error.message }
      end
      stats["seconds"] = @clock.call - started
      stats
    end

    class FetchError < StandardError; end

    private
      def fetch_one(url)
        MAX_ATTEMPTS.times do |attempt|
          pace
          response = @http.call(url, { "User-Agent" => USER_AGENT, "Accept" => "image/jpeg" })
          case response.code.to_i
          when 200 then return response.body
          when 429, 500..599
            @sleeper.call((response["retry-after"] || 2**(attempt + 1)).to_f)
          else raise FetchError, "HTTP #{response.code}"
          end
        end
        raise FetchError, "HTTP 429 after #{MAX_ATTEMPTS} attempts"
      rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError => error
        raise FetchError, "#{error.class}: #{error.message}"
      end

      def pace
        now = @clock.call
        wait = @last ? MIN_INTERVAL - (now - @last) : MIN_INTERVAL
        @sleeper.call(wait) if wait.positive?
        @last = @clock.call
      end

      def write(path, body)
        partial = Pathname("#{path}.part")
        partial.binwrite(body)
        partial.rename(path)
      end

      def request(url, headers)
        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) { |http| http.request(Net::HTTP::Get.new(uri, headers)) }
      end
  end
end
```

  The spec's `pace` expectation: the first request sleeps `MIN_INTERVAL` too (a conservative start); every later one sleeps whatever keeps 100 ms between requests.

- [ ] Run the spec again. Expect: 3 examples, 0 failures. `bin/rubocop spikes/`: no offenses.
- [ ] Write `spikes/card_scanner/phase2/script/fetch_art.rb`:

```ruby
# Fetches artwork images into tmp/card_scanner_phase2/artwork/<size>/ (AC-4.2, AC-4.7).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/fetch_art.rb --size small --mode corpus|estimate|full [--limit N] [--seed N]
#   corpus:   the artworks of the 99 corpus cards (both sizes are cheap: ~200 requests)
#   estimate: a random sample of 500 uncached artworks; writes fetch_estimate.json and stops (maintainer checkpoint)
#   full:     everything not cached, in order; resumable; --limit bounds one invocation
require "bundler/setup"
require "optparse"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/bulk_artworks"
require "card_scanner_phase2/art_fetcher"

options = { size: "small", seed: 20261003, limit: nil }
OptionParser.new do |p|
  p.on("--size SIZE") { options[:size] = it }
  p.on("--mode MODE") { options[:mode] = it }
  p.on("--limit N", Integer) { options[:limit] = it }
  p.on("--seed N", Integer) { options[:seed] = it }
end.parse!
abort "--mode corpus|estimate|full is required" unless %w[corpus estimate full].include?(options[:mode])

data = CardScannerPhase2::BulkArtworks.load
fetcher = CardScannerPhase2::ArtFetcher.new(dir: CardScannerPhase2::WORK_DIR.join("artwork"), size: options[:size])
selection =
  case options[:mode]
  when "corpus"
    keys = CardScannerPhase2::CORPORA.keys.flat_map do |corpus|
      JSON.parse(CardScannerPhase2::WORK_DIR.join("truth", corpus, "ground_truth.json").read).fetch("photos").map { data["entries"][it["external_key"]] }
    end.compact.uniq
    data["artworks"].slice(*keys)
  when "estimate"
    uncached = data["artworks"].reject { |id, _| fetcher.path_for(id).file? }
    uncached.keys.sample(500, random: Random.new(options[:seed])).to_h { [ it, data["artworks"][it] ] }
  when "full" then data["artworks"]
  end
stats = fetcher.fetch(selection, limit: options[:limit]).merge("mode" => options[:mode], "selected" => selection.size, "at" => Time.now.utc.iso8601)
if options[:mode] == "estimate"
  remaining = data["artworks"].count { |id, _| !fetcher.path_for(id).file? }
  per_image = { "bytes" => stats["bytes"].to_f / stats["fetched"], "seconds" => stats["seconds"] / stats["fetched"] }
  stats["estimate"] = { "seed" => options[:seed], "sample" => stats["fetched"], "remaining_images" => remaining, "per_image" => per_image,
    "remaining_bytes" => (per_image["bytes"] * remaining).round, "remaining_hours" => (per_image["seconds"] * remaining / 3600).round(2) }
  CardScannerPhase2::WORK_DIR.join("fetch_estimate.json").write(JSON.pretty_generate(stats))
end
CardScannerPhase2::WORK_DIR.join("fetch_#{options[:size]}_#{options[:mode]}_#{Time.now.utc.strftime("%Y%m%dT%H%M%S")}.json").write(JSON.pretty_generate(stats))
puts JSON.pretty_generate(stats.except("failed")) + "\nfailed: #{stats["failed"].size}"
```

- [ ] Run `truth_copies.rb` if not yet done, then `fetch_art.rb --size small --mode corpus` and `--size normal --mode corpus`. Expect about 99 fetched each (fewer if cards share artwork), 0 failed. These precede the estimate on purpose: the corpus artworks are needed whether or not the full fetch is approved (AC-4.3), and the 500-artwork sample is drawn from the artworks not yet cached, so the estimate stays a random sample of the remainder; the findings say so.
- [ ] **Estimate (AC-4.2):** `fetch_art.rb --size small --mode estimate`. Expect `fetched: 500` and an `estimate` block with `remaining_images`, `remaining_bytes` and `remaining_hours`. Write the estimate into `docs/specs/008-card-scanner-phase-2-spike/research.md` as a first section ("Fetch estimate, awaiting approval"), with the seed, sample size, per-image bytes and seconds, and the totals. Commit: `docs(spec): record the artwork fetch estimate for the maintainer's approval (008)`.
- [ ] **Checkpoint (maintainer):** approve or decline the full fetch from the committed estimate. Record the answer and its date in `research.md`. If declined, the index covers the corpus artworks plus the 500-sample and the rates are labelled accordingly (AC-4.3); skip the next step.
- [ ] **Full fetch,** in chunks that fit a background task's 2-hour limit, with the chunk size taken from the estimate: `--limit` = `floor(5400 / per_image.seconds)` from `fetch_estimate.json` (90 minutes' worth, leaving headroom for slow responses). Run `fetch_art.rb --size small --mode full --limit <that>` as a background task, repeated until `fetched: 0`. Each invocation writes its own `fetch_small_full_<stamp>.json` only when it finishes, so a chunk killed by the limit loses its statistics but not its cached images; the findings sum the finished chunks (fetched, bytes, seconds), count cached files for the total, and list `failed` (AC-4.8).
- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/art_index_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/art_index"
require "fileutils"
require "tmpdir"

RSpec.describe CardScannerPhase2::ArtIndex do
  let(:ids) { %w[00000000-0000-4000-8000-000000000001 00000000-0000-4000-8000-000000000002] }
  let(:hashes) { [ ("\x00" * 128).b, ("\xFF" * 128).b ] }
  let(:dir) { Pathname(Dir.mktmpdir) }

  after { FileUtils.remove_entry(dir) }

  it "writes and reads back fixed-size records of uuid plus hash", :aggregate_failures do
    described_class.write!(dir, ids, hashes, meta: { "image_size" => "small" })
    index = described_class.read(dir)
    expect(dir.join("art_index.bin").size).to eq(2 * 144)
    expect(index.size).to eq(2)
    expect(index.ids).to eq(ids)
    expect(index.meta).to include("image_size" => "small", "count" => 2)
  end

  it "ranks by the smallest distance over the query's offsets" do
    described_class.write!(dir, ids, hashes, meta: {})
    index = described_class.read(dir)
    query = [ ("\xFF" * 127 + "\x0F").b, ("\x00" * 127 + "\x0F").b ]
    ranked = index.search(query, limit: 2)
    expect(ranked).to eq([ { "id" => ids[0], "distance" => 4 }, { "id" => ids[1], "distance" => 4 } ])
  end
end
```

- [ ] Run it. Expect: FAIL (`cannot load such file -- card_scanner_phase2/art_index`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/art_index.rb`:

```ruby
require "time"
require "card_scanner_phase2/fingerprint"

module CardScannerPhase2
  # The index as a flat binary file (16-byte uuid + 128-byte hash per artwork), which the browser downloads
  # and searches, plus the pure-Ruby server-side search for AC-3.7.
  class ArtIndex
    RECORD = 144
    attr_reader :ids, :hashes, :meta

    def self.write!(dir, ids, hashes, meta:)
      dir.mkpath
      dir.join("art_index.bin").binwrite(ids.zip(hashes).map { |id, hash| [ id.delete("-") ].pack("H32") + hash }.join)
      dir.join("art_index_meta.json").write(JSON.pretty_generate(meta.merge("count" => ids.size, "built_at" => Time.now.utc.iso8601, "record_bytes" => RECORD)))
    end

    def self.read(dir)
      data = dir.join("art_index.bin").binread
      ids, hashes = [], []
      (data.bytesize / RECORD).times do |i|
        record = data.byteslice(i * RECORD, RECORD)
        ids << record.byteslice(0, 16).unpack1("H32").then { "#{it[0, 8]}-#{it[8, 4]}-#{it[12, 4]}-#{it[16, 4]}-#{it[20, 12]}" }
        hashes << record.byteslice(16, 128)
      end
      new(ids, hashes, JSON.parse(dir.join("art_index_meta.json").read))
    end

    def initialize(ids, hashes, meta)
      @ids, @hashes, @meta = ids, hashes, meta
      @words = hashes.map { it.unpack("n*") }
    end

    def size = ids.size

    # queries: the six offset hashes of one photo. Each artwork's distance is the smallest over them.
    def search(queries, limit: 10)
      query_words = queries.map { it.unpack("n*") }
      distances = @words.map do |words|
        query_words.map { |q| words.each_index.sum { Fingerprint::POPCOUNT[words[it] ^ q[it]] } }.min
      end
      distances.each_index.sort_by { [ distances[it], it ] }.first(limit).map { { "id" => ids[it], "distance" => distances[it] } }
    end
  end
end
```

- [ ] Run the spec again. Expect: 2 examples, 0 failures. `bin/rubocop spikes/`: no offenses.
- [ ] Write `spikes/card_scanner/phase2/script/build_index.rb`:

```ruby
# Fingerprints every cached artwork image and writes the index (AC-4.1, AC-4.4). Reports the build cost.
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/build_index.rb [--size small]
require "bundler/setup"
require "optparse"
require "zlib"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/settings"
require "card_scanner_phase2/bulk_artworks"
require "card_scanner_phase2/ppm"
require "card_scanner_phase2/fingerprint"
require "card_scanner_phase2/art_index"

size = "small"
OptionParser.new { |p| p.on("--size SIZE") { size = it } }.parse!
settings = CardScannerPhase2::Settings.load.fetch("fingerprint")
data = CardScannerPhase2::BulkArtworks.load
image_dir = CardScannerPhase2::WORK_DIR.join("artwork", size)
ids, hashes, missing = [], [], []
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
data["artworks"].each_key do |id|
  path = image_dir.join("#{id}.jpg")
  next missing << id unless path.file?
  hashes << CardScannerPhase2::Fingerprint.hash(CardScannerPhase2::Ppm.decode(path), settings, settings["offsets"].first)
  ids << id
end
seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
dir = CardScannerPhase2::WORK_DIR.join("index")
CardScannerPhase2::ArtIndex.write!(dir, ids, hashes, meta: { "image_size" => size, "bulk_version" => data["bulk_version"], "settings_commit" => CardScannerPhase2::Settings.commit,
  "tool" => "ImageMagick #{`magick -version`[/\d+\.\d+\.\d+-\d+/]} (P6 decode) + pure Ruby", "fingerprint_seconds" => seconds.round(1), "missing_artworks" => missing.size })
raw = dir.join("art_index.bin").size
corpus_ids = CardScannerPhase2::CORPORA.keys.flat_map do |corpus|
  JSON.parse(CardScannerPhase2::WORK_DIR.join("truth", corpus, "ground_truth.json").read).fetch("photos").map { data["entries"][it["external_key"]] }
end.compact.uniq
puts "#{ids.size} artworks in #{seconds.round(1)} s; #{missing.size} without a cached image; index #{raw} bytes raw, #{Zlib::Deflate.deflate(dir.join("art_index.bin").binread, Zlib::BEST_COMPRESSION).bytesize} gzip"
left_out = corpus_ids & missing
puts "corpus artworks left out (AC-4.8): #{left_out.empty? ? "none" : left_out.join(", ")}"
```

- [ ] Run it after whichever fetch the maintainer approved. Expect one line with the counts, the fingerprinting time and both index sizes (AC-4.4). Record them.
- [ ] **AC-4.5, what the production build would add.** Measure the two candidates' package sizes with Podman against the Dockerfile's base image, dry-run only (no image changes): `podman run --rm docker.io/library/ruby:4.0.7-slim sh -c 'apt-get update -qq && apt-get install --no-install-recommends -y --dry-run imagemagick | grep -i "additional disk"'` and the same for `libvips` (the package name the Dockerfile installs at line 19; in the app's image it is already present, so the dry run reports what the base image would add) plus the `ruby-vips` gem's size (`gem fetch ruby-vips` into the scratchpad, then `ls -l`). (Check the Dockerfile's exact base image tag first and use it.) Record both figures for `research.md`.
- [ ] Commit: `feat(spike): fetch artwork with Scryfall's manners and build the art index`

---

## Phase 6: Art matching in the browser, the agreement check and the search timings

**Implements:** FR-4, Story 3 | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.5, AC-3.6, AC-3.7, AC-3.8 (on the development half; held-out in Phase 7), AC-4.6
**Files:** `spikes/card_scanner/phase2/public/{fingerprint.js,search.js,detect.js}`, `lib/card_scanner_phase2/art_scoring.rb`, `script/{agreement.rb,art_run.rb,search_server.rb,art_score.rb}`, `spec/card_scanner_phase2/art_scoring_spec.rb`
**Interfaces:** Consumes: `card.png` per found photo, `/work/index/art_index.bin`, `/work/artwork/<size>/<id>.jpg`; Produces: `<run>/<stem>/art.json` (hashes, top 10, timings), `<run>/art_score.{md,json}`, `tmp/card_scanner_phase2/agreement.json`, `search_server.json`

- [ ] Write `spikes/card_scanner/phase2/public/fingerprint.js` (the same arithmetic and loop order as `Fingerprint` in Ruby):

```js
export function box(width, height, box, offset) {
  const inset = offset.inset || 0, dx = offset.dx || 0, dy = offset.dy || 0
  const bw = box.x1 - box.x0, bh = box.y1 - box.y0
  return [ (box.x0 + dx + inset * bw) * width, (box.y0 + dy + inset * bh) * height, (box.x1 + dx - inset * bw) * width, (box.y1 + dy - inset * bh) * height ]
}

export function areaResample(image, x0, y0, x1, y1, cols, rows) {
  const { data, width, height } = image
  const cellW = (x1 - x0) / cols, cellH = (y1 - y0) / rows
  const r = new Float64Array(cols * rows), g = new Float64Array(cols * rows), b = new Float64Array(cols * rows)
  const clamp = (v, max) => Math.min(max, Math.max(0, v))
  for (let j = 0; j < rows; j++) {
    const cy0 = y0 + j * cellH, cy1 = y0 + (j + 1) * cellH
    for (let i = 0; i < cols; i++) {
      const cx0 = x0 + i * cellW, cx1 = x0 + (i + 1) * cellW
      let sr = 0, sg = 0, sb = 0, weight = 0
      for (let py = clamp(Math.floor(cy0), height - 1); py <= clamp(Math.ceil(cy1) - 1, height - 1); py++) {
        const wy = Math.min(cy1, py + 1) - Math.max(cy0, py)
        if (wy <= 0) continue
        for (let px = clamp(Math.floor(cx0), width - 1); px <= clamp(Math.ceil(cx1) - 1, width - 1); px++) {
          const wx = Math.min(cx1, px + 1) - Math.max(cx0, px)
          if (wx <= 0) continue
          const w = wx * wy, p = (py * width + px) * 4
          sr += data[p] * w; sg += data[p + 1] * w; sb += data[p + 2] * w; weight += w
        }
      }
      const k = j * cols + i
      r[k] = sr / weight; g[k] = sg / weight; b[k] = sb / weight
    }
  }
  return [ r, g, b ]
}

export function dhash(plane, cols, rows, out, offset) {
  let bit = 0
  for (let j = 0; j < rows; j++) {
    for (let i = 0; i < cols - 1; i++, bit++) {
      if (plane[j * cols + i + 1] > plane[j * cols + i]) out[offset + (bit >> 3)] |= 0x80 >> (bit & 7)
    }
  }
}

// One 128-byte hash of a canvas holding the card (or, for the agreement check, a whole artwork image).
export function fingerprint(canvas, settings, offset) {
  const image = canvas.getContext("2d", { willReadFrequently: true }).getImageData(0, 0, canvas.width, canvas.height)
  const [cols, rows] = settings.grid
  const [x0, y0, x1, y1] = box(canvas.width, canvas.height, settings.box, offset)
  const [r, g, b] = areaResample(image, x0, y0, x1, y1, cols, rows)
  const grey = new Float64Array(r.length)
  for (let k = 0; k < r.length; k++) grey[k] = 0.299 * r[k] + 0.587 * g[k] + 0.114 * b[k]
  const out = new Uint8Array(128)
  ;[grey, b, g, r].forEach((plane, n) => dhash(plane, cols, rows, out, n * 32))
  return out
}

export function fingerprints(canvas, settings) {
  return settings.offsets.map((offset) => fingerprint(canvas, settings, offset))
}

export const hex = (bytes) => Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("")
```

- [ ] Write `spikes/card_scanner/phase2/public/search.js`:

```js
const RECORD = 144
let index = null

export async function loadIndex(url) {
  if (index) return index
  const bytes = new Uint8Array(await (await fetch(url)).arrayBuffer())
  const count = bytes.length / RECORD
  const ids = new Array(count), words = new Uint32Array(count * 32)
  const view = new DataView(bytes.buffer)
  for (let i = 0; i < count; i++) {
    const base = i * RECORD
    const h = Array.from(bytes.subarray(base, base + 16), (b) => b.toString(16).padStart(2, "0")).join("")
    ids[i] = `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`
    for (let w = 0; w < 32; w++) words[i * 32 + w] = view.getUint32(base + 16 + w * 4)
  }
  index = { count, ids, words, bytes: bytes.length }
  return index
}

function popcount(v) {
  v = v - ((v >>> 1) & 0x55555555)
  v = (v & 0x33333333) + ((v >>> 2) & 0x33333333)
  return (((v + (v >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24
}

// Each artwork's distance is the smallest over the query's offset hashes; returns the nearest `limit`.
export function search(index, hashes, limit = 10) {
  const queries = hashes.map((h) => { const v = new DataView(h.buffer, h.byteOffset, 128); return Array.from({ length: 32 }, (_, w) => v.getUint32(w * 4)) })
  const distances = new Uint16Array(index.count)
  for (let i = 0; i < index.count; i++) {
    let best = 1025
    for (const q of queries) {
      let d = 0
      for (let w = 0; w < 32 && d < best; w++) d += popcount(index.words[i * 32 + w] ^ q[w])
      if (d < best) best = d
    }
    distances[i] = best
  }
  const order = Array.from(distances.keys()).sort((p, q) => distances[p] - distances[q] || p - q).slice(0, limit)
  return order.map((i) => ({ id: index.ids[i], distance: distances[i] }))
}
```

- [ ] Edit `spikes/card_scanner/phase2/public/detect.js`: import `fingerprints, fingerprint, hex` and `loadIndex, search`; in `run`, after the card is straightened and when the destructured `art` is true, add:

```js
    const t2 = performance.now()
    const hashes = fingerprints(card, settings.fingerprint)
    result.msFingerprint = performance.now() - t2
    result.hashes = hashes.map(hex)
    const index = await loadIndex("/work/index/art_index.bin")
    const t3 = performance.now()
    result.art = search(index, hashes, 10)
    result.msSearch = performance.now() - t3
    result.indexCount = index.count
```

  and add a second page function for the agreement check (AC-4.6), fingerprinting a whole artwork image as if it were the card:

```js
async function fingerprintImage({ path }) {
  const bitmap = await createImageBitmap(await (await fetch(`/work/${path}`)).blob())
  const source = sourceCanvas(bitmap, null)
  return { hash: hex(fingerprint(source, settings.fingerprint, settings.fingerprint.offsets[0])) }
}
window.__phase2 = { ready: true, settings, run, fingerprintImage }
```

- [ ] Write `spikes/card_scanner/phase2/script/agreement.rb` (AC-4.6; runs before the freeze):

```ruby
# Fingerprints the same artwork images in Ruby (the index build) and in the browser, and reports the distances.
# Usage: SE_AVOID_STATS=true bundle exec ruby spikes/card_scanner/phase2/script/agreement.rb [--size small] [--extra 100]
require "bundler/setup"
require "optparse"
require "selenium-webdriver"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/settings"
require "card_scanner_phase2/bulk_artworks"
require "card_scanner_phase2/ppm"
require "card_scanner_phase2/fingerprint"

size, extra = "small", 100
OptionParser.new { |p| p.on("--size S") { size = it }; p.on("--extra N", Integer) { extra = it } }.parse!
settings = CardScannerPhase2::Settings.load.fetch("fingerprint")
data = CardScannerPhase2::BulkArtworks.load
corpus_ids = CardScannerPhase2::CORPORA.keys.flat_map do |corpus|
  JSON.parse(CardScannerPhase2::WORK_DIR.join("truth", corpus, "ground_truth.json").read).fetch("photos").map { data["entries"][it["external_key"]] }
end.compact.uniq
image_dir = CardScannerPhase2::WORK_DIR.join("artwork", size)
others = (data["artworks"].keys - corpus_ids).select { image_dir.join("#{it}.jpg").file? }.sample(extra, random: Random.new(20261003))
ids = (corpus_ids + others).select { image_dir.join("#{it}.jpg").file? }

JS = "const [p, done] = arguments; window.__phase2.fingerprintImage(p).then(done, (e) => done({ error: String(e) }))"
driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
driver.manage.timeouts.script_timeout = 120
results = begin
  driver.navigate.to("#{ENV.fetch("SPIKE_URL", "http://127.0.0.1:4200")}/detect.html")
  Selenium::WebDriver::Wait.new(timeout: 120).until { driver.execute_script("return Boolean(window.__phase2 && window.__phase2.ready)") }
  ids.map do |id|
    ruby = CardScannerPhase2::Fingerprint.hash(CardScannerPhase2::Ppm.decode(image_dir.join("#{id}.jpg")), settings, settings["offsets"].first)
    answer = driver.execute_async_script(JS, { "path" => "artwork/#{size}/#{id}.jpg" })
    abort "#{id}: #{answer["error"]}" if answer["error"]
    browser = [ answer["hash"] ].pack("H*")
    { "id" => id, "corpus_card" => corpus_ids.include?(id), "distance" => CardScannerPhase2::Fingerprint.hamming(ruby, browser) }
  end
ensure
  driver.quit
end
distances = results.map { it["distance"] }.sort
summary = { "size" => size, "n" => results.size, "corpus_cards" => corpus_ids.size, "median" => distances[distances.size / 2], "max" => distances.last,
  "settings_commit" => CardScannerPhase2::Settings.commit, "results" => results }
CardScannerPhase2::WORK_DIR.join("agreement_#{size}.json").write(JSON.pretty_generate(summary))
puts summary.except("results").to_json
```

- [ ] Run it for `small` (and `normal`, since both corpus sets are cached). Expect `n` ≥ 100 + the corpus artworks and a median and max in bits. If the max is not small against the true-vs-impostor gaps seen later (the 180–340 true / +46–150 impostor calibration the roadmap quotes), the resampling approximation is the first knob to revisit (`fingerprint.grid` stays; the JPEG decoders are the likely cause and are reported as such).
- [ ] Write `spikes/card_scanner/phase2/script/art_run.rb`. It re-runs detection for a detect run's photos with `art: true`, as a new run named `<run>-art`, so the art results carry their own provenance; detection is deterministic (AC-2.10 checks that), so the straightened card is the same one the reading run saw:

```ruby
# Art matching over a detect run: re-runs detection with the fingerprint and search enabled, as a new run
# named <run>-art, for the photos the chosen detector found. Usage: … art_run.rb --from dev-hand-3 --detector hand
require "bundler/setup"
require "optparse"
require "selenium-webdriver"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/runs"
require "card_scanner_phase2/derived_corpus"

options = {}
OptionParser.new { |p| p.on("--from RUN") { options[:from] = it }; p.on("--detector D") { options[:detector] = it } }.parse!
from = CardScannerPhase2.runs_dir.join(options.fetch(:from))
provenance = CardScannerPhase2::Runs.read(from)
run_dir = CardScannerPhase2::Runs.start!("#{options[:from]}-art", half: provenance["half"])
jobs = CardScannerPhase2::DerivedCorpus.detections(from).map do |d|
  { "path" => d["path"], "detector" => options[:detector], "scale" => nil, "run" => run_dir.basename.to_s, "stem" => File.basename(d["file"], ".*"), "art" => true, "file" => d["file"], "corpus" => d["corpus"] }
end
RUN_JS = "const [p, done] = arguments; window.__phase2.run(p).then((r) => done({ result: r }), (e) => done({ error: String(e && e.stack || e) }))"
driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
driver.manage.timeouts.script_timeout = 600
begin
  driver.navigate.to("#{ENV.fetch("SPIKE_URL", "http://127.0.0.1:4200")}/detect.html")
  Selenium::WebDriver::Wait.new(timeout: 120).until { driver.execute_script("return Boolean(window.__phase2 && window.__phase2.ready)") }
  jobs.each do |job|
    answer = driver.execute_async_script(RUN_JS, job.except("file", "corpus"))
    abort "#{job["file"]}: #{answer["error"]}" if answer["error"]
    record = CardScannerPhase2::Runs.stamp(run_dir, answer["result"].merge("file" => job["file"], "corpus" => job["corpus"]))
    dir = run_dir.join(job["stem"])
    dir.mkpath
    dir.join("art.json").write(JSON.pretty_generate(record))
    puts format("%-14s %-5s %s", job["file"], record["found"] ? "found" : "none", record["art"] ? "#{record["art"].first["id"][0, 8]} d=#{record["art"].first["distance"]}" : "-")
  end
ensure
  driver.quit
end
puts "#{jobs.size} photos -> #{run_dir}"
```

- [ ] Write `spikes/card_scanner/phase2/script/search_server.rb` (AC-3.7, the server-side search: pure Ruby, nothing outside the bundle, timed per photo over the hashes the browser sent):

```ruby
# Times the pure-Ruby search for each photo's browser-made hashes, and checks it ranks the same first artwork.
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/search_server.rb <art run>
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/fingerprint"
require "card_scanner_phase2/art_index"

run_dir = CardScannerPhase2.runs_dir.join(ARGV.fetch(0) { abort "usage: search_server.rb <art run>" })
index = CardScannerPhase2::ArtIndex.read(CardScannerPhase2::WORK_DIR.join("index"))
rows = run_dir.glob("*/art.json").map { JSON.parse(it.read) }.select { it["hashes"] }.map do |record|
  hashes = record["hashes"].map { [ it ].pack("H*") }
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ranked = index.search(hashes, limit: 10)
  ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  { "file" => record["file"], "ms" => ms.round(1), "same_first" => ranked.first["id"] == record["art"].first["id"], "browser_ms" => record["msSearch"] }
end
ms = rows.map { it["ms"] }.sort
summary = { "n" => rows.size, "index_count" => index.size, "median_ms" => ms[ms.size / 2], "max_ms" => ms.last, "same_first" => rows.count { it["same_first"] },
  "timed_span" => "ArtIndex#search over the loaded index: six Hamming distances per artwork and the top-10 sort; excludes loading the index", "rows" => rows }
run_dir.join("search_server.json").write(JSON.pretty_generate(summary))
puts summary.except("rows").to_json
```

- [ ] Write the failing spec `spikes/card_scanner/phase2/spec/card_scanner_phase2/art_scoring_spec.rb`:

```ruby
require_relative "../phase2_helper"
require "card_scanner_phase2/art_scoring"

RSpec.describe CardScannerPhase2::ArtScoring do
  let(:data) do
    { "artworks" => { "art-1" => { "name" => "Right", "entries" => 2 }, "art-2" => { "name" => "Other", "entries" => 1 }, "art-3" => { "name" => "Right", "entries" => 1 } },
      "entries" => { "k1" => "art-1", "k2" => "art-1", "k3" => "art-3" }, "names" => { "Right" => 3, "Other" => 1 } }
  end
  let(:records) do
    [ { "file" => "A.jpeg", "corpus" => "phase0", "name" => "Right", "external_key" => "k1", "era" => "MOM+", "foil" => false, "borderless_or_showcase" => false,
        "found" => true, "class" => "found", "art" => [ { "id" => "art-1", "distance" => 200 }, { "id" => "art-2", "distance" => 300 } ], "text_top3" => false, "lookup" => { "status" => "none" } },
      { "file" => "B.jpeg", "corpus" => "phase0", "name" => "Right", "external_key" => "k3", "era" => "pre-M15", "foil" => true, "borderless_or_showcase" => false,
        "found" => true, "class" => "wrong_outline", "art" => [ { "id" => "art-2", "distance" => 250 }, { "id" => "art-3", "distance" => 260 } ], "text_top3" => true, "lookup" => { "status" => "none" } },
      { "file" => "C.jpeg", "corpus" => "new", "name" => "Right", "external_key" => "k2", "era" => "MOM+", "foil" => false, "borderless_or_showcase" => true,
        "found" => false, "class" => "not_found", "art" => nil, "text_top3" => false, "lookup" => { "status" => "none" } } ]
  end

  it "scores the right artwork first and in the top 3, over all photos and over the ones classed as found", :aggregate_failures do
    scored = described_class.score(records, data)
    expect(scored.map { it["right_artwork"] }).to eq(%w[art-1 art-3 art-1])
    expect(scored.map { it["art_rank"] }).to eq([ 1, 2, nil ])
    expect(scored.map { it["right_distance"] }).to eq([ 200, 260, nil ])
    expect(scored.map { it["nearest_wrong_distance"] }).to eq([ 300, 250, nil ])
    md = described_class.markdown(scored)
    expect(md).to include("| Right artwork first | Group | All photos | Classed found |", "| overall | all | 1/3 (33.3%) | 1/1 (100.0%) |")
    expect(md).to include("| Right artwork in top 3 | Group | All photos | Classed found |", "| overall | all | 2/3 (66.7%) | 1/1 (100.0%) |")
    expect(md).to include("Text missed 2; of those art first 1; text top 3 or art first 2 of 3")
    expect(md).to include("| B.jpeg | Right | 3 | 1 |") # printings sharing the name vs sharing the artwork, for a card with no exact printing
  end
end
```

- [ ] Run it. Expect: FAIL (`cannot load such file -- card_scanner_phase2/art_scoring`).
- [ ] Implement `spikes/card_scanner/phase2/lib/card_scanner_phase2/art_scoring.rb` (pure Ruby; the `comparison` helper is reimplemented here so this spec doesn't need Rails):

```ruby
module CardScannerPhase2
  # Art-matching rates (AC-3.2 to AC-3.6) over scored records: each carries its text result (text_top3,
  # lookup) from score.json and the browser's ranked artworks from art.json.
  module ArtScoring
    GROUPINGS = { "overall" => ->(_) { "all" }, "era" => ->(r) { r["era"] }, "foil" => ->(r) { r["foil"] ? "foil" : "non-foil" },
                  "frame treatment" => ->(r) { r["borderless_or_showcase"] ? "borderless/showcase" : "regular" } }.freeze

    module_function

    def score(records, data)
      records.map do |record|
        right = data["entries"][record["external_key"]]
        ranked = Array(record["art"])
        rank = ranked.index { it["id"] == right }&.+(1)
        nearest_wrong = ranked.find { it["id"] != right }&.dig("distance")
        exact = record.dig("lookup", "status") == "one" && record["printing_identified"]
        record.merge("right_artwork" => right, "art_rank" => rank, "right_distance" => rank && ranked[rank - 1]["distance"], "nearest_wrong_distance" => nearest_wrong,
          "art_first" => rank == 1, "art_top3" => !rank.nil? && rank <= 3, "right_nearer" => !rank.nil? && (nearest_wrong.nil? || ranked[rank - 1]["distance"] < nearest_wrong),
          "share_name" => data["names"][record["name"]], "share_artwork" => right && data["artworks"].dig(right, "entries"), "no_exact_printing" => !exact)
      end
    end

    def rate(rows, &hit) = "#{rows.count(&hit)}/#{rows.size} (#{rows.empty? ? "n/a" : format("%.1f%%", 100.0 * rows.count(&hit) / rows.size)})"

    def comparison(title, sources, &hit)
      groups = sources.values.flat_map { |rs| GROUPINGS.flat_map { |label, key| rs.map { [ label, key.call(it) ] } } }.uniq.sort
      rows = groups.map { |label, value| "| #{label} | #{value} | #{sources.values.map { |rs| rate(rs.select { GROUPINGS[label].call(it) == value }, &hit) }.join(" | ")} |" }
      [ "| #{title} | Group | #{sources.keys.join(" | ")} |", "|---|---|#{"---|" * sources.size}", *rows ].join("\n")
    end

    def markdown(scored)
      sources = { "All photos" => scored, "Classed found" => scored.select { it["class"] == "found" } } # the by-eye class (AC-2.4), per AC-3.3
      distances = scored.select { it["art_rank"] }
      parts = [ comparison("Right artwork first", sources) { it["art_first"] }, comparison("Right artwork in top 3", sources) { it["art_top3"] } ]
      parts << "Distances (right artwork ranked): median right #{median(distances.map { it["right_distance"] })}, median nearest wrong " \
               "#{median(distances.map { it["nearest_wrong_distance"] }.compact)}, right nearer than every wrong #{distances.count { it["right_nearer"] }} of #{distances.size}"
      missed = scored.reject { it["text_top3"] }
      parts << "Text missed #{missed.size}; of those art first #{missed.count { it["art_first"] }}; text top 3 or art first #{scored.count { it["text_top3"] || it["art_first"] }} of #{scored.size}"
      narrowing = scored.select { it["no_exact_printing"] }
      parts << "| File | Card | Printings sharing the name | Printings sharing the artwork |\n|---|---|---|---|\n" +
        narrowing.map { "| #{it["file"]} | #{it["name"]} | #{it["share_name"]} | #{it["share_artwork"]} |" }.join("\n")
      parts << "Narrowing: median sharing name #{median(narrowing.map { it["share_name"] }.compact)}, median sharing artwork #{median(narrowing.map { it["share_artwork"] }.compact)}, " \
               "artwork belongs to exactly one printing #{narrowing.count { it["share_artwork"] == 1 }} of #{narrowing.size}"
      parts << "| File | Right artwork's distance | Nearest wrong artwork's distance | Rank |\n|---|---|---|---|\n" +
        scored.map { "| #{it["file"]} | #{it["right_distance"] || "not ranked"} | #{it["nearest_wrong_distance"] || "-"} | #{it["art_rank"] || "-"} |" }.join("\n")
      parts.join("\n\n")
    end

    def median(values) = values.empty? ? "n/a" : values.sort[values.size / 2]

    def misses(scored) = scored.reject { it["art_first"] }
  end
end
```

- [ ] Run the spec again. Expect: 1 example, 0 failures. `bin/rubocop spikes/`: no offenses.
- [ ] Write `spikes/card_scanner/phase2/script/art_score.rb` (joins `score.json` of the detect run with the art run's `art.json`s):

```ruby
# Scores an art run against the text results of its detect run. Usage: bundle exec ruby … art_score.rb <art run> <detect run>
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/runs"
require "card_scanner_phase2/bulk_artworks"
require "card_scanner_phase2/art_scoring"

art_run, detect_run = ARGV.fetch(0), ARGV.fetch(1) { abort "usage: art_score.rb <art run> <detect run>" }
art_dir, detect_dir = CardScannerPhase2.runs_dir.join(art_run), CardScannerPhase2.runs_dir.join(detect_run)
data = CardScannerPhase2::BulkArtworks.load
text = JSON.parse(detect_dir.join("score.json").read).fetch("records").to_h { [ it["file"], it ] }
art = art_dir.glob("*/art.json").map { JSON.parse(it.read) }.to_h { [ it["file"], it ] }
records = text.map do |file, record|
  a = art[file] || {}
  record.merge("art" => a["art"], "hashes" => a["hashes"], "msFingerprint" => a["msFingerprint"], "msSearch" => a["msSearch"],
    "art_provenance" => a.slice("run", "half", "recorded_at", "code_commit", "settings_commit", "tree_clean"),
    "text_top3" => Array(record["final_candidates"]).first(3).include?(record["name"]),
    "printing_identified" => record.dig("lookup", "status") == "one" && record.dig("lookup", "external_keys") == [ record["external_key"] ])
end
scored = CardScannerPhase2::ArtScoring.score(records, data)
provenance = CardScannerPhase2::Runs.read(art_dir)
by_corpus = scored.group_by { it["corpus"] }
md = [ "# Art matching: #{art_run} (#{provenance["half"]}#{provenance["half"] == "development" ? ", biased" : ""})",
  "Index: #{JSON.parse(CardScannerPhase2::WORK_DIR.join("index/art_index_meta.json").read).slice("count", "image_size", "bulk_version", "settings_commit")}",
  "## Both corpora", CardScannerPhase2::ArtScoring.markdown(scored),
  *by_corpus.flat_map { |corpus, rs| [ "## #{corpus}", CardScannerPhase2::ArtScoring.markdown(rs) ] },
  "## Misses (right artwork not first)", "| File | Expected | First | Right distance | Nearest wrong | Class |", "|---|---|---|---|---|---|",
  *CardScannerPhase2::ArtScoring.misses(scored).map { "| #{it["file"]} | #{it["name"]} | #{it.dig("art", 0, "id")} | #{it["right_distance"]} | #{it["nearest_wrong_distance"]} | #{it["class"]} |" },
  "## Timings (desktop)", { "fingerprint" => scored.map { it["msFingerprint"] }.compact.then { { "n" => it.size, "median" => it.sort[it.size / 2], "max" => it.max } },
                            "search_browser" => scored.map { it["msSearch"] }.compact.then { { "n" => it.size, "median" => it.sort[it.size / 2], "max" => it.max } } }.to_json ].join("\n\n")
art_dir.join("art_score.md").write(md)
art_dir.join("art_score.json").write(JSON.pretty_generate("provenance" => provenance, "records" => scored))
puts md
```

- [ ] **Pilot the fingerprint and the search (AC-1.6)** on the five pilot photos first: `art_run.rb --from pilot-hand --detector hand`, `art_score.rb pilot-hand-art pilot-hand`, `search_server.rb pilot-hand-art`. Expect every found photo to have six hashes, a top 10 and both timings, and the server search to rank the same first artwork. Record what the pilot changed.
- [ ] **Development-half art run.** With the index built and the server running: `art_run.rb --from dev-hand-<n> --detector hand` (or `opencv`, whichever had the better development top-3 count, the AC-1.3 rule; use both for tuning if close), then `art_score.rb dev-hand-<n>-art dev-hand-<n>` and `search_server.rb dev-hand-<n>-art`. Expect the two rate tables, the distances line, the "text missed" line, the narrowing table, and a timing summary.
- [ ] **Tune the fingerprint on the development half:** only `fingerprint.offsets`, `fingerprint.imageSize` (rebuild the index with `build_index.rb --size normal` to compare, if the corpus-only `normal` cache suffices for a first look; a full `normal` fetch would need its own estimate and approval) and, if the agreement check calls for it, nothing else (the box and grid are the roadmap's). Record each round. Commit each: `chore(spike): tuning round <n>: fingerprint <what changed>`.
- [ ] Commit: `feat(spike): add art matching in the browser, the agreement check and both searches`

---
## Phase 7: The freeze, the held-out runs, the replays and the fixtures

**Implements:** FR-1, FR-2, FR-4, Story 1, Story 5 | **Satisfies:** AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-2.2–AC-2.6, AC-2.9–AC-2.11, AC-3.1–AC-3.8, AC-5.5
**Files:** `spikes/card_scanner/phase2/settings.json` (the freeze), `script/{replay_diff.rb,fixtures.rb}`, `spec/fixtures/card_scanner/phase2_results.json`, `phase2_agreement.json`
**Interfaces:** Consumes: every run's `score.json`, `art_score.json`, `classes.json`, `agreement_<size>.json`; Produces: the committed fixtures

- [ ] **Before the freeze:** confirm the agreement check ran at the current fingerprint settings (`agreement_<size>.json`'s `settings_commit` equals `Settings.commit`); if not, re-run `agreement.rb` (AC-4.6 precedes the freeze).
- [ ] **Freeze (AC-1.3).** Add `"frozen": "<today>"` as the first key of `settings.json`, with a `"chosen_detector"` key naming the detector with the better development-half top-3 count over all 52 photos (smaller download on a tie), and the development counts both reached. Commit: `chore(spike): freeze the Phase 2 settings` with the tuning-round table in the body. `bundle exec ruby -e '…; puts CardScannerPhase2::Settings.commit'` must now print this commit's SHA. Export it: `export SETTINGS_COMMIT=$(git rev-parse HEAD)`. `git status --porcelain` must be empty before every held-out run, and **no commit of any kind may land between the freeze and the last held-out run** (the guard compares `HEAD` with the settings commit): hold the `classes.json`, fixture and findings commits until Phase 7's runs are all done, or re-freeze (a new commit touching `settings.json`) and re-run every held-out run.
- [ ] **Held-out detect runs.** `detect_run.rb --run held-hand --half held_out --detector hand`, `--run held-opencv … --detector opencv`, `--run held-hand-scaled --half held_out --detector hand --corpus phase0 --scale 1440`, `--run held-opencv-scaled …`. Each must print `47` (or `24` for the scaled runs) lines; a `Refused` error means the guard tripped, so fix the cause (commit or stash nothing: the tree must be clean because nothing is pending) and re-run under the same name only after deleting the empty directory the refusal didn't create (it creates none).
- [ ] For each: `derive.rb`, the reading run (dev server on 3204 with the printed environment, `photo_run.rb`, stop), `score.rb`, `contact_sheet.rb`, the by-eye `classes.json`, `score.rb` again. If a reading run dies for an apparatus reason, re-run `photo_run.rb` on the same measurement directory (it resumes from pending rows) and note it in `research.md` (AC-1.5).
- [ ] **Held-out art run:** `art_run.rb --from held-<chosen> --detector <chosen>`, `art_score.rb held-<chosen>-art held-<chosen>`, `search_server.rb held-<chosen>-art`.
- [ ] **Replays (AC-2.10):** at the frozen settings, `detect_run.rb --run dev-hand-r1 --half development --detector hand`, then `dev-hand-r2`, and the OpenCV twins; derive, reading run and score each. Write `spikes/card_scanner/phase2/script/replay_diff.rb`:

```ruby
# Counts the photos whose outcome (detection class, right card in the final top 3) differs between two runs (AC-2.10).
# Usage: bundle exec ruby … replay_diff.rb <run a> <run b>
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"

a, b = ARGV.first(2).map { JSON.parse(CardScannerPhase2.runs_dir.join(it, "score.json").read).fetch("records").to_h { [ it["file"], it ] } }
outcome = ->(r) { [ r["class"], Array(r["final_candidates"]).first(3).include?(r["name"]) ] }
differing = a.keys.select { outcome.(a[it]) != outcome.(b.fetch(it)) }
puts "#{differing.size} of #{a.size} differ: #{differing.join(", ")}"
```

  The outcome's detection class is the by-eye one (AC-2.4), so the replay runs need `classes.json` too: judge `dev-<detector>-r1` from its contact sheets as usual; for `r2`, copy each photo's class from `r1` when its `card.png` is byte-identical (`cmp`), since the same straightened image has the same class by definition, and judge only the photos whose images differ. Re-run `score.rb` on both, then run `replay_diff.rb` for both pairs; record the counts, the files, and how many images were byte-identical.

- [ ] Write `spikes/card_scanner/phase2/script/fixtures.rb` (AC-5.5: one record per photo keyed by the original manifest file name; text and numbers only):

```ruby
# Assembles the committed fixtures from the held-out, development, scaled, replay and art runs.
# Usage: bundle exec ruby … fixtures.rb --held hand=held-hand,opencv=held-opencv --scaled hand=held-hand-scaled,opencv=held-opencv-scaled \
#          --dev hand=dev-hand-5,opencv=dev-opencv-4 --replays hand=dev-hand-r1+dev-hand-r2,opencv=dev-opencv-r1+dev-opencv-r2 --art held-hand-art --agreement small
require "bundler/setup"
require "optparse"
require_relative "../lib/card_scanner_phase2"
require "card_scanner_phase2/settings"

options = {}
OptionParser.new { |p| %w[held scaled dev replays art agreement].each { |k| p.on("--#{k} V") { options[k] = it } } }.parse!
pairs = ->(v) { v.to_s.split(",").map { it.split("=") }.to_h }
records = ->(run) { JSON.parse(CardScannerPhase2.runs_dir.join(run, "score.json").read).fetch("records") }
READING = %w[run half class found name_text collector_text parsed lookup lookup_ms name_candidates final_candidates ms msDetect msWarp recorded_at code_commit settings_commit tree_clean].freeze

out = {}
add = ->(run, detector, slot) do
  records.(run).each do |r|
    rec = out[r["file"]] ||= { "file" => r["file"], "corpus" => r["corpus"], "half" => r["half"], "name" => r["name"], "external_key" => r["external_key"], "era" => r["era"],
                               "foil" => r["foil"], "borderless_or_showcase" => r["borderless_or_showcase"], "detectors" => {} }
    (rec["detectors"][detector] ||= {})[slot] = r.slice(*READING)
  end
end
pairs.(options["held"]).each { |d, run| add.(run, d, "full") }
pairs.(options["dev"]).each { |d, run| add.(run, d, "full") }
pairs.(options["scaled"]).each { |d, run| add.(run, d, "scaled") }
pairs.(options["replays"]).each do |d, runs|
  runs.split("+").each do |run|
    records.(run).each { |r| ((out[r["file"]]["detectors"][d] ||= {})["replays"] ||= []) << { "run" => run, "class" => r["class"], "top3" => Array(r["final_candidates"]).first(3).include?(r["name"]) } }
  end
end
if options["art"]
  art = JSON.parse(CardScannerPhase2.runs_dir.join(options["art"], "art_score.json").read)
  art["records"].each do |r|
    out[r["file"]]["art"] = r.slice("hashes", "art", "right_artwork", "art_rank", "right_distance", "nearest_wrong_distance", "share_name", "share_artwork",
      "msFingerprint", "msSearch").merge(r.fetch("art_provenance", {})).merge("detector" => art.dig("provenance", "run").sub(/-art\z/, ""))
  end
end
CardScannerPhase2::FIXTURE_DIR.join("phase2_results.json").write(JSON.pretty_generate("format_version" => 1, "spec" => "008", "settings_commit" => CardScannerPhase2::Settings.commit,
  "records" => out.values.sort_by { it["file"] }))
if options["agreement"]
  agreement = JSON.parse(CardScannerPhase2::WORK_DIR.join("agreement_#{options["agreement"]}.json").read)
  CardScannerPhase2::FIXTURE_DIR.join("phase2_agreement.json").write(JSON.pretty_generate(agreement.merge("format_version" => 1)))
end
puts "#{out.size} records -> #{CardScannerPhase2::FIXTURE_DIR.join("phase2_results.json")}"
```

- [ ] Run it with the real run names. Expect `99 records -> …/phase2_results.json`. Check: `grep -c '"file": "IMG_' spec/fixtures/card_scanner/phase2_results.json` is 99; every held-out record's `recorded_at` is later than the settings commit's date (`git show -s --format=%cI $SETTINGS_COMMIT`); no field holds an image (`grep -c "data:image" …` is 0).
- [ ] Commit: `test(scanner): add the Phase 2 spike's text fixtures`

---

## Phase 8: Findings, ADRs, README and memory

**Implements:** FR-5, Story 5 | **Satisfies:** AC-2.4 (counts), AC-2.11, AC-3.8, AC-4.1–AC-4.5 (reported), AC-5.1, AC-5.2, AC-5.3, AC-5.4, AC-5.7
**Files:** `docs/specs/008-card-scanner-phase-2-spike/research.md`, `docs/adr/0005-*.md` … (only for techniques recommended to build), `spikes/card_scanner/phase2/README.md`, `.claude/memory/card-scanner-direction.md`, `docs/lessons/…`
**Interfaces:** Consumes: every `score.md`, `art_score.md`, `search_server.json`, `sizes.json`, `agreement_*.json`, `fetch_*.json`, `art_index_meta.json`, the tuning-round tables; Produces: the findings and ADRs

- [ ] Write `research.md` with these sections, every rate with its sample size, held-out rates as the headline and development rates beside them labelled biased:
  1. **Summary**: what was and wasn't measured; the held-out headline for each detector (right card first, top 3, exact printing) beside the baseline and the live same-card figures; the art-matching headline (right artwork first / top 3, what art adds to text); the costs; the recommendation.
  2. **Method and apparatus**: the frozen settings (every key of `settings.json`), the split (AC-1.1, with counts), the pilot and its changes (AC-1.6), the tuning rounds table, the settings commit, the catalog version, the bulk file version, the detectors' versions (OpenCV 4.13.0 and its SHA-256), the policy header as sent and the AC-2.8 outcome, the isolation argument (the shipped chain unchanged since `c68ffbd`).
  3. **Detection rates** (AC-2.2, AC-2.3): the tables from the held-out `score.md`s (both corpora, each corpus), with the baseline and live columns; the development tables beside them, labelled biased.
  4. **Detection classes and misses** (AC-2.4, AC-2.11): found / not found / wrong outline per detector, corpus and half; the held-out miss table for the chosen detector; where the contact sheets are.
  5. **The live-frame stand-in** (AC-2.6): the scaled tables, labelled.
  6. **Costs**: sizes and licences (AC-2.7), detection and warp timings (AC-2.9), OCR timings for comparison.
  7. **The art index** (AC-4.1–AC-4.5, AC-4.7, AC-4.8): bulk version, entry and artwork counts, the image size and which printing stood for each artwork, the fetch estimate and the maintainer's approval with its date (or the declined fetch and the subset), the measured fetch cost, failures, the fingerprinting time, index sizes, the tool and what the production build would add.
  8. **Agreement** (AC-4.6): median and max distances, beside the true and nearest-wrong distances.
  9. **Art matching** (AC-3.2–AC-3.6, AC-3.8): the held-out tables, the per-photo distance table (file, right artwork's distance, nearest wrong artwork's distance, from `art_score.json`) and its summary, what art adds to text, the narrowing table, the misses; the development tables labelled biased.
  10. **Search costs** (AC-3.7): browser and server-side timings with the timed span, the index as a download.
  11. **Replays** (AC-2.10).
  12. **Not measured** (AC-5.3): every phone figure, real live capture, and anything else skipped.
  13. **Fixtures** (AC-5.5): every field of `phase2_results.json` and `phase2_agreement.json`; where the straightened cards and strips are kept (AC-5.7).
  14. **Recommendation and options** (AC-5.2): for detection and for art matching, build with the confirm flow / defer / drop, with the evidence for and against, and the options for the maintainer's ruling; roadmap assumptions the evidence contradicted.
- [ ] For each technique the findings recommend building, write a Proposed ADR per `docs/adr/README.md` (Title, Status, Context, Options considered, Decision, Consequences), numbered from `0005`: the detector, the fingerprint and index design (image size, build tool, refresh), where the search runs. Link each from `research.md`. A technique recommended for dropping gets none (AC-5.4).
- [ ] Finish `spikes/card_scanner/phase2/README.md`: the full command table in order, with the environment variables, and the guard rule.
- [ ] Update `.claude/memory/card-scanner-direction.md` with the spike's result and the pending ruling (the ruling itself is the maintainer's; record it when given).
- [ ] Commit in steps: `docs(spec): record the Phase 2 spike findings`, `docs(adr): propose ADR 000N …` (one per ADR), `docs(spike): document the Phase 2 harness`, `chore(memory): record the Phase 2 spike's result`.

---

## Phase 10 (added v1.2.0): Full-index art matching

Runs after Phase 8 and before Phase 9.

**Implements:** FR-3, FR-4 (no-tuning rule), Stories 3 and 4 | **Satisfies:** AC-4.9, AC-4.10, AC-3.9, AC-3.10, AC-1.3 (index-metadata settings commit), AC-4.2 (approval recorded)
**Files:** `spikes/card_scanner/phase2/script/{build_index,art_run,art_score,fixtures}.rb`, `spikes/card_scanner/phase2/settings.json` (index metadata only), `spec/fixtures/card_scanner/phase2_results.json`, `docs/specs/008-card-scanner-phase-2-spike/research.md`, `docs/adr/` (if art matching is recommended to build), `spikes/card_scanner/phase2/README.md`, `.claude/memory/card-scanner-direction.md`
**Interfaces:** Consumes: the cached subset, `artworks.json`, the frozen fingerprint settings, `dev-hand-3` and `held-hand`; Produces: `tmp/card_scanner_phase2/index/` (full), `index-subset/` (kept), runs `dev-hand-3-art-full` and `held-hand-art-full`, `art_full` fixture slot

**Ordering rule.** Every code change in this phase is committed before the index-metadata settings commit. From that commit until `held-hand-art-full` and its scoring are done, there is no commit and no new file in the repository (the held-out guard). The fixtures, findings, ADR and memory commits come after.

- [ ] Record the approval: in research.md's "Fetch estimate and the maintainer's decision" section, add "Decision revised (maintainer, 2026-10-03): the full fetch is approved, to measure art matching against the full index (spec v1.2.0)." Commit `docs(spec): record the maintainer's approval of the full artwork fetch (008)`.
- [ ] **Full fetch (AC-4.9):** as background tasks, `bundle exec ruby spikes/card_scanner/phase2/script/fetch_art.rb --size small --mode full --limit 30006` (30,006 = floor(5400 / 0.17996 s), from the estimate), repeated until a chunk reports `fetched: 0`. Each chunk writes `fetch_small_full_<stamp>.json` when it finishes. If a chunk is killed by the 2-hour limit, start another (the cache resumes it) and say so in the findings. Expect about 50,361 fetched in all, minus the 36 artworks without a URL (listed as failed, AC-4.8).
- [ ] Keep the subset index: `cp -a tmp/card_scanner_phase2/index tmp/card_scanner_phase2/index-subset`.
- [ ] `build_index.rb`: replace the fixed `SUBSET` meta with a `--label` option, so the metadata names the index (AC-4.10):

```ruby
size, label = "small", nil
OptionParser.new do |p|
  p.on("--size SIZE") { size = it }
  p.on("--label TEXT") { label = it }
end.parse!
# … unchanged fingerprinting …
meta = { "image_size" => size, "bulk_version" => data["bulk_version"], "settings_commit" => CardScannerPhase2::Settings.commit,
  "tool" => …, "fingerprint_seconds" => seconds.round(1), "missing_artworks" => missing.size }
meta["subset"] = label if label && missing.any? # a partial index names itself; the full index carries no subset field
meta["label"] = label || (missing.empty? ? "full" : "subset")
CardScannerPhase2::ArtIndex.write!(dir, ids, hashes, meta:)
```

  `art_score.rb` already labels rates "against a N-artwork subset" only when `subset` is present, and "against N artworks" otherwise.
- [ ] `art_run.rb`: add `--name RUN` (default `"#{from}-art"`), so a second art run from the same detect run gets its own directory: `run_dir = CardScannerPhase2::Runs.start!(options[:name] || "#{options[:from]}-art", half: provenance["half"])`.
- [ ] `fixtures.rb`: add `--full-art` and `--dev-full-art` options that write the same fields as `--art` into a separate `art_full` slot per record (so `art` keeps the subset results). In the record's `art_full` also store `"index_count"` from the run's art_score.json provenance or the index meta.
- [ ] Check `bin/rubocop spikes/` and `bundle exec rspec spikes/card_scanner/phase2/spec`. Commit `feat(spike): label art indexes and name art runs for the full-index measurement`.
- [ ] Build the full index: `bundle exec ruby spikes/card_scanner/phase2/script/build_index.rb`. Expect about 50,923 artworks (50,959 minus those without an image) in roughly 15 minutes; `missing_artworks` equals the fetch failures; `corpus artworks left out: none`. Record count, time, raw and compressed size (AC-4.10, AC-3.10's download).
- [ ] **Development full-index art run** (biased, AC-3.9): spike server without `SPIKE_UNSAFE_EVAL`; `art_run.rb --from dev-hand-3 --detector hand --name dev-hand-3-art-full`; `art_score.rb dev-hand-3-art-full dev-hand-3`; `search_server.rb dev-hand-3-art-full`.
- [ ] **Index-metadata settings commit (AC-1.3):** add `"art_index": "full: <count> artworks, small images, bulk default-cards-20261002210553, built 2026-10-03"` as a top-level key in `settings.json`, changing nothing else. Check with `git diff -U0 spikes/card_scanner/phase2/settings.json` that the only change is that line (record the diff for the findings), and that `settings.json`'s fingerprint, hand, opencv and warp values equal those at `39cdc6e` (`git diff 39cdc6e -- spikes/card_scanner/phase2/settings.json`). Commit `chore(spike): record the full art index in the frozen settings`. Set `SETTINGS_COMMIT=$(git rev-parse HEAD)`; `git status --porcelain` must be empty.
- [ ] **Held-out full-index art run, once (AC-3.9):** `SETTINGS_COMMIT=<sha> … art_run.rb --from held-hand --detector hand --name held-hand-art-full`; `art_score.rb held-hand-art-full held-hand`; `search_server.rb held-hand-art-full`. Check provenance: every `art.json` has `half` held_out, `settings_commit` = `code_commit` = the new commit, `tree_clean` true, `recorded_at` after it. If a run dies for an apparatus reason, re-run under the same settings commit as `held-hand-art-full-2` and note it (AC-1.5).
- [ ] Compare subset and full results per photo (both halves): which right-artwork-first results the full index loses, with the artwork that now ranks first and both distances; this is AC-3.9's "how many and why".
- [ ] Fixtures: re-run `fixtures.rb` with the Phase 7 options plus `--full-art held-hand-art-full --dev-full-art dev-hand-3-art-full`. Expect `99 records`; check every held-out `art_full` record's provenance. Commit `test(scanner): add the full-index art results to the Phase 2 fixtures`.
- [ ] Findings: update research.md (§1 summary, §7 index with the fetch totals beside the estimate and the full index's cost, §9 art matching with full-index tables as the headline beside the subset's, §10 search costs against the full index, §12 not measured, §13 the `art_full` fields, §14 recommendation re-drafted from the full-index evidence). If §14 now recommends building art matching, write Proposed ADRs for the fingerprint and index design and for where the search runs (from 0006), linked from research.md; otherwise say why not. Update the spike README (the `--label`, `--name`, `--full-art` options) and `card-scanner-direction` memory. Commit in steps: `docs(spec): record the full-index art results`, `docs(adr): …`, `docs(spike): …`, `chore(memory): …`.

## Phase 9: Integration Verification

**Implements:** NFR Security, NFR Reliability | **Satisfies:** AC-5.6, AC-5.5 (no images), AC-1.2 (verified from the records)
**Files:** none
**Interfaces:** Consumes: the branch; Produces: evidence for the implementation review

- [ ] `bundle exec rspec spikes/card_scanner/phase2/spec`. Expect: all examples pass (about 25).
- [ ] `bin/ci`. Expect: pass (RuboCop covers `spikes/`; RSpec runs only `spec/**`, which now includes nothing new except fixtures no spec reads).
- [ ] Allowed paths: `git diff origin/main --name-only | grep -Ev '^(docs/|spikes/card_scanner/|spec/fixtures/card_scanner/|\.claude/memory/|\.rubocop\.yml$|\.gitignore$)'`. Expect: no output.
- [ ] `git diff origin/main --stat -- Gemfile Gemfile.lock app public vendor config db lib script`. Expect: empty.
- [ ] No images: `git diff origin/main --name-only | grep -Ei '\.(jpe?g|png|webp|heic|bin)$'`. Expect: no output. And `grep -l "data:image" spec/fixtures/card_scanner/phase2_*.json`. Expect: none.
- [ ] Held-out provenance (AC-1.2): `bundle exec ruby -e 'require "json"; f = JSON.parse(File.read("spec/fixtures/card_scanner/phase2_results.json")); c = f["settings_commit"]; bad = f["records"].select { |r| r["half"] == "held_out" }.flat_map { |r| r["detectors"].values.flat_map(&:values).flatten.select { |s| s.is_a?(Hash) && s["settings_commit"] } + [ r["art"] ].compact }.reject { |s| s["settings_commit"] == c && s["code_commit"] == c && s["tree_clean"] }; puts bad.size'`. Expect: `0`. And every held-out `recorded_at` is after `git show -s --format=%cI <settings commit>`.
- [ ] The spike page made no third-party request: `grep -c '"ip"' tmp/card_scanner_phase2/logs/requests.jsonl` is not needed (the server logs nothing but policy reports); instead confirm `csp-reports.jsonl` holds only the entries the AC-2.8 step explained, and that no `connect-src` or `img-src` report names an external host.
- [ ] Every AC-N.M in the spec maps to a phase above (Phases 1–8 headers); list any gap for the implementation review.

## Quickstart Validation

From a clean checkout of the branch, with `~/card-scanner-corpus/` present:

1. `bin/setup --skip-server`, then Phase 0's catalog refresh and user.
2. `bundle exec ruby spikes/card_scanner/phase2/script/fetch_opencv.rb` → `already intact` or `fetched`, 10,964,323 bytes.
3. `bundle exec puma -C spikes/card_scanner/phase2/puma.rb` (background), `truth_copies.rb`, then `detect_run.rb --run qs-hand --half development --detector hand --files <two development files>` → 2 lines.
4. `derive.rb qs-hand`, the dev server with the printed environment, `photo_run.rb` → `Stored 2 captures`, `bin/rails runner … score.rb qs-hand` → tables.
5. `bundle exec rspec spikes/card_scanner/phase2/spec` → green; `bin/ci` → green.

**Next steps after approval:** run `sdd-superpowers:sdd-review` (plan mode) on Fable, then `sdd-superpowers:sdd-execute` on Opus, creating the branch `008-card-scanner-phase-2-spike` first.

## Plan Changelog

| Version | Phase | Change |
|---------|-------|--------|
| 1.2.0 | Phase 10 | Added: full-index art matching (AC-4.9, AC-4.10, AC-3.9, AC-3.10), run after Phase 8 and before Phase 9 |
| 1.2.0 | Phase 9 | Diff checks run against `origin/main` (AC-5.6 clarified; local `main` can be stale) |
