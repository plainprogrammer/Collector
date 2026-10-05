# Implementation Plan: Card Scanner Art Spike — The Index on a Phone, and Art on Live Captures

**Spec:** docs/specs/010-card-scanner-art-spike/spec.md (v1.1.2, Approved, reviewed three times)
**Decisions:** [ADR 0004](../../adr/0004-card-recognition-in-the-browser.md) (Accepted). This spike informs [ADR 0006](../../adr/0006-art-fingerprint-and-index.md) and [ADR 0007](../../adr/0007-art-search-in-the-browser.md) (both Proposed) and makes no new decision.
**Created:** 2026-10-05

## Context

Spec 009's misses all lacked a usable collector line, and art matching is the remedy spec 008 measured, but only on straightened photos and only on the desktop. This spike measures two things before spec 011 builds art matching:
- the art index on the maintainer's iPhone
- art accuracy on live captures, both from the guide box and from a detected, straightened frame

It runs on spec 009's 35 cards, against their text-only results.

**Facts established during planning (2026-10-05):**

- **Spec 008's art tools** (`spikes/card_scanner/phase2/`) hard-code their working folder (`WORK_DIR = REPO/tmp/card_scanner_phase2`). In it they keep:
  - `artworks.json`, `entries.json` and `names.json`, written by `script/artworks.rb` from the newest `storage/catalog/mtg/default-cards-*.jsonl.gz`
  - `artwork/<size>/<id>.jpg`
  - `index/art_index.bin` and its `art_index_meta.json`
  - `truth/<corpus>/ground_truth.json`

  `fetch_art.rb` (`--mode corpus|estimate|full`, resumable, `--limit`), `build_index.rb` and `agreement.rb` read the truth corpora from `CORPORA.keys` (phase0 and new).
  - `estimate` mode fetches a 500-artwork random sample, seed 20261003. Spec 010 AC-1.2 instead computes the full-fetch estimate from spec 008's measured figures and fetches nothing. Spec 008 §7 measured 50,923 images, 707,955,694 bytes and 9,448.8 s.
  - `ArtIndex.write!` already records `bulk_version`, `settings_commit` and `built_at`.
- **The browser code:**
  - `public/search.js`: `loadIndex(url)` fetches and parses in one step and caches the result in a module variable. `search(index, hashes, limit)` returns the nearest `{id, distance}`.
  - `public/fingerprint.js`: `fingerprints(canvas, settings)` gives the six offsets, and `hex(bytes)` formats them. Both read pixels with `getImageData`.
  - The spike server (`lib/card_scanner_phase2/server.rb`) binds `127.0.0.1:4200`. It gates `/corpus`, `/work` and `POST /outputs` to loopback and sends the scanner page's policy with a nonce.
- **The data on disk:**
  - The bulk file `default-cards-20261003210542.jsonl.gz` is the only one in this worktree's `storage/catalog/mtg/`.
  - `spec/fixtures/card_scanner/phase2_results.json` holds 43 held-out records with `art_full.hashes`, six 256-hex-digit fingerprints each.
  - `~/card-scanner-corpus/runs/phase2/held-hand/<stem>/card.png` holds 43 straightened cards at 1008×1408, pixel-identical to the cards those hashes came from.
  - Spec 009's sitting fixtures are `phase2_sitting_ocr_results.json` (`lookup`) and `phase2_sitting_name_matches.json` (`final_candidates`).
  - `~/card-scanner-corpus/phase2-sitting/` holds the manifest (35 rows, era column), `ground_truth.json` (`file`, `name`, `external_key`, `foil`, `era`) and the 35 unguided photos.
- **The app's measurement mode:**
  - `card_reader_controller.js#read` gets `{ image, card }` from `camera.grab()`. `card` is the guide rect in frame pixels, as floats. The method dispatches `card-reader:read` with `{ ...reading, strips }` only.
  - `measurement_controller.js#store` posts strips and text to `scanner_measurement_captures_path`.
  - `Scanner::MeasurementRun#record!` validates both strips with `png!` (PNG, at most 5 MB) before writing anything, then writes the JSON last.
  - The measurement system spec (`spec/system/scanner_measurement_spec.rb`) sets the config in an `around` block and has a `capture_lightning_bolt` helper. The synthetic camera is a 900×1200 canvas stream.
- **The app's detector:** `app/javascript/scanner/detector.js` exports `detectCard(source, settings)`, `warp(source, corners, w, h)` and `WARP`. It imports only `scanner/geometry`, which imports nothing.
- **Spike specs** run with `bundle exec rspec spikes/card_scanner/<phase>/spec`, outside `bin/ci`. RuboCop lints `spikes/`.

**Plan decisions:**

- **Where the spike lives.** A new folder, `spikes/card_scanner/phase3/`, holds spec 010's apparatus (`CardScannerPhase3`). It reuses `CardScannerPhase2`'s art units by `require_relative`.
- **Spec 008's tools gain two settings, and nothing else in them changes:**
  - **`CARD_SCANNER_WORK_DIR`** overrides `WORK_DIR`. Every spec 010 command runs with it set to `~/card-scanner-corpus/art-cache`, so the cache, index and truth live outside the repo and survive worktree removal (spec AC-1.3).
  - **`CARD_SCANNER_TRUTH_CORPORA`** lists the truth corpora (`sitting` here), so the corpus fetch, the index build's report and the agreement check use spec 009's 35 cards.

  - **`CARD_SCANNER_BULK_FILE`** names the bulk file (`default-cards-20261003210542.jsonl.gz`) instead of "the newest", so a later catalog refresh can't change the spike's input.

  The cache and the index share the one working folder (the index is `<work>/index/`), which meets FR-1's "cache folder, index folder" with one setting. The corpus already comes from `CARD_SCANNER_CORPUS`.
- **One addition to `search.js`:** an exported `parseIndex(bytes)`, which `loadIndex` then calls. The parsing doesn't change. It lets the timing page time the download and the parse separately (AC-2.2).
- **The phone server** is a new `CardScannerPhase3::Server` with its own `puma.rb`. It binds `ssl://0.0.0.0:4300` with spec 007's certificate for the phone, and `tcp://127.0.0.1:4301` for the desktop replay.
  - **LAN routes** carry a strict policy (no inline script, `connect-src 'self'`): the timing page and its modules, the fingerprint settings, the gzipped index (`Content-Encoding: gzip`), the 43 query fingerprints, the 43 straightened cards, and one results path (`POST /phone/results`).
  - **Loopback-only routes:** the replay page, the app's scanner modules (behind an import map), the working folder and the corpus.
  - No corpus photo or frame is reachable from the LAN (FR-2).
  - **Ruling:** the spec says "the spike server gains that bind". A separate phase 3 server leaves spec 008's server and its specs untouched, and meets the same requirement.
- **The live replay** runs the app's own `detector.js` (through the import map) with spec 008's `fingerprint.js` and `search.js`, in headless Firefox. Each job also returns the right artwork's distance, measured directly against its record (AC-4.8).
- **Scoring** happens in a pure-Ruby `CardScannerPhase3::ArtFindings` (with specs). The same-capture text rescore (AC-4.5's secondary table) uses `Collector::ScannerFindings.rescore` under `bin/rails runner`.
- **App change:** measurement mode gains frame keeping, switched on by `COLLECTOR_SCANNER_KEEP_FRAMES=1` in development, with a 32 MB frame limit. The frame travels in the same captures request, and a refused frame refuses the whole capture.
  - The only change outside measurement mode is in `card_reader_controller.js`: for live captures, the read event's detail also carries `frame: { image, guide }`, in memory. `send` is unchanged.
- **Fixtures,** all `phase3_`, text only:
  - `phase3_fetch_estimate.json` (AC-1.2)
  - `phase3_index_build.json` (AC-1.5, AC-1.6)
  - `phase3_phone_timings.json` (Story 2)
  - `phase3_art_results.json` (Story 4, AC-5.4)

## Global Constraints

- **Writes outside the repo:** only `~/card-scanner-corpus/art-cache/` (the cache, the index and the truth copies), `~/card-scanner-corpus/runs/phase3/` (replays and phone results) and `~/card-scanner-corpus/runs/spec010/` (the sitting's captures and frames). Nothing else in `~/card-scanner-corpus` changes.
- **Never committed:** no image, frame, cached artwork or index. Fixtures are JSON text (FR-1, AC-5.4).
- **The fetch:** nothing beyond the 35 cards' artworks is fetched until the maintainer approves the committed estimate, or, on decline, a stated distractor sample (500, seed 20261003) (AC-1.2, FR-1). The fetch follows the Scryfall etiquette already in `ArtFetcher` (AC-1.3).
- **The fingerprint** settings (`settings.json`, frozen at `39cdc6e`), resampling and index writer are unchanged (FR-1). Nothing is tuned on the 35 cards (FR-4).
- **The app:** normal scanning is unchanged. The readings request still carries only `reading[name_text]`, `reading[collector_text]` and `reading[key]`. Frames are stored only in development measurement mode with frame keeping on, and every measurement route 404s when the mode is off (FR-3, AC-3.3, AC-5.5).
- **The phone server:** no third-party host, no inline script on the LAN routes, and no corpus photo or frame on the LAN (FR-2).
- **No pass threshold.** Every number carries its sample size. Desktop and phone figures are labelled as such, and rates against a subset index are labelled with its size.
- **Commits and CI:** `bin/ci` passes at every commit. Spike specs pass with `bundle exec rspec spikes/card_scanner/phase3/spec spikes/card_scanner/phase2/spec`. One Conventional Commit per step, scope `spike`, `scanner`, `findings` or `010`, on branch `010-card-scanner-art-spike`.
- **Every spike command** runs with `export CARD_SCANNER_WORK_DIR=$HOME/card-scanner-corpus/art-cache CARD_SCANNER_TRUTH_CORPORA=sitting CARD_SCANNER_BULK_FILE=$PWD/storage/catalog/mtg/default-cards-20261003210542.jsonl.gz SE_AVOID_STATS=true` (from the worktree root).

---

## Goal

Measured findings (`research.md`, `phase3_*` fixtures, updated ADRs 0006 and 0007) on the art index on the iPhone and on art accuracy for spec 009's 35 cards along three paths, for the maintainer's ruling on spec 011.

**Components (Simplicity Gate: 3):**
1. Spec 008's art tools with two settings and `parseIndex`.
2. Spike phase 3: the server, the timing and replay pages, the scripts, and `CardScannerPhase3::{Estimate, ArtworkOwners, ArtFindings, PhoneFindings}`.
3. The app's measurement mode, with frame keeping.

**Human checkpoints (the maintainer), asked for in Phase 0, all at once:**
- **Phase 1:** approve the full fetch from the committed estimate, or decline it and approve the distractor sample.
- **Phase 5:** the phone timing session, one cold and one warm load on the iPhone (a few minutes).
- **Phase 6:** the live captures of the 35 cards, one capture each with frame keeping on (captures only, no adds).

Phases 2 and 3 need nothing from the maintainer and run while the approval is pending (the work-ahead practice).

---

## Phase 0: Environment and the maintainer's inputs

**Implements:** Users and Context | **Satisfies:** none directly
**Files:** none
**Interfaces:** Produces: the maintainer's three checkpoints scheduled; the checked bulk file and catalog.

- [ ] Ask the maintainer, in one message: approve or decline the fetch once Phase 1 commits the estimate; a time for the iPhone timing session (Phase 5); a time for the 35-card live captures (Phase 6). Check that the 35 cards are still at hand.
- [ ] Check the environment:
  - `ls storage/catalog/mtg/`: expect only `default-cards-20261003210542.jsonl.gz`.
  - `bin/rails "catalog:status[mtg]"`: expect that version applied.
  - `ls ~/card-scanner-corpus/runs/phase2/held-hand/*/card.png | wc -l`: expect 43.
  - `test -f ~/.local/share/collector-dev-https/dev.crt && echo ok`.
  - `ip -4 -o addr show scope global`: expect 192.168.1.76; otherwise rerun `bin/dev-certificate`.

---

## Phase 1: Spec 008's tools take their folders, the estimate, and the corpus artworks

**Implements:** FR-1, Story 1 (up to approval) | **Satisfies:** AC-1.1, AC-1.2, AC-1.3 (corpus fetch)
**Files:** `spikes/card_scanner/phase2/lib/card_scanner_phase2.rb`, `spikes/card_scanner/phase2/lib/card_scanner_phase2/bulk_artworks.rb`, `spikes/card_scanner/phase2/script/{fetch_art,build_index,agreement}.rb`, `spikes/card_scanner/phase2/spec/card_scanner_phase2_spec.rb`, `spikes/card_scanner/phase3/lib/card_scanner_phase3.rb`, `spikes/card_scanner/phase3/lib/card_scanner_phase3/estimate.rb`, `spikes/card_scanner/phase3/spec/{phase3_helper.rb,card_scanner_phase3/estimate_spec.rb}`, `spikes/card_scanner/phase3/script/{truth.rb,estimate.rb}`, `spec/fixtures/card_scanner/phase3_fetch_estimate.json`
**Interfaces:** Consumes: `CardScannerPhase2::{BulkArtworks, ArtFetcher}`. Produces: `CardScannerPhase2.truth_corpora`, `CardScannerPhase2::WORK_DIR` (overridable), `CardScannerPhase3::{ROOT, REPO, SPEC008_FETCH}`, `CardScannerPhase3.{corpus_dir, sitting_dir, runs_dir}`, `CardScannerPhase3::Estimate.call(artworks, cached:, size:, measured:)`.

- [ ] Add failing examples to `spikes/card_scanner/phase2/spec/card_scanner_phase2_spec.rb` (inside its top-level `describe`):

```ruby
  describe ".truth_corpora (spec 010)" do
    around do |example|
      saved = ENV.delete("CARD_SCANNER_TRUTH_CORPORA")
      example.run
    ensure
      saved ? ENV["CARD_SCANNER_TRUTH_CORPORA"] = saved : ENV.delete("CARD_SCANNER_TRUTH_CORPORA")
    end

    it "defaults to spec 008's two corpora, and takes a list from the environment", :aggregate_failures do
      expect(CardScannerPhase2.truth_corpora).to eq(%w[phase0 new])
      ENV["CARD_SCANNER_TRUTH_CORPORA"] = "sitting"
      expect(CardScannerPhase2.truth_corpora).to eq(%w[sitting])
    end
  end

  it "takes the bulk file from CARD_SCANNER_BULK_FILE (spec 010)" do
    script = "require 'card_scanner_phase2'; require 'card_scanner_phase2/bulk_artworks'; puts CardScannerPhase2::BulkArtworks.latest_bulk_file"
    output = IO.popen({ "CARD_SCANNER_BULK_FILE" => "/tmp/bulk.jsonl.gz" }, [ "ruby", "-I", File.expand_path("../lib", __dir__), "-e", script ], &:read)
    expect(output.strip).to eq("/tmp/bulk.jsonl.gz")
  end

  it "takes its working folder from CARD_SCANNER_WORK_DIR (spec 010)" do
    script = "require 'card_scanner_phase2'; puts CardScannerPhase2::WORK_DIR"
    output = IO.popen({ "CARD_SCANNER_WORK_DIR" => "/tmp/art-cache" }, [ "ruby", "-I", File.expand_path("../lib", __dir__), "-e", script ], &:read)
    expect(output.strip).to eq("/tmp/art-cache")
  end
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase2/spec/card_scanner_phase2_spec.rb`. Expect 3 failures (`truth_corpora` undefined; neither the folder nor the bulk file is overridden).
- [ ] In `spikes/card_scanner/phase2/lib/card_scanner_phase2.rb`, replace the `WORK_DIR` line with the lines below, and add `truth_corpora` after `runs_dir`:

```ruby
  # Spec 010 points this at ~/card-scanner-corpus/art-cache, outside the repository, so the cache and index survive a worktree.
  WORK_DIR = Pathname(File.expand_path(ENV.fetch("CARD_SCANNER_WORK_DIR", REPO.join("tmp/card_scanner_phase2").to_s)))
```

```ruby
  # The corpora whose ground truth the art scripts read from WORK_DIR/truth/<corpus>/ (spec 010 uses "sitting").
  def self.truth_corpora = ENV.fetch("CARD_SCANNER_TRUTH_CORPORA", "").split(",").map(&:strip).reject(&:empty?).then { it.empty? ? CORPORA.keys : it }
```

- [ ] In `spikes/card_scanner/phase2/lib/card_scanner_phase2/bulk_artworks.rb`, replace the `latest_bulk_file` line with:

```ruby
    # Spec 010 names its bulk file with CARD_SCANNER_BULK_FILE, so a later catalog refresh can't change the input.
    def latest_bulk_file(dir = REPO.join("storage/catalog/mtg"))
      return Pathname(File.expand_path(ENV["CARD_SCANNER_BULK_FILE"])) if ENV["CARD_SCANNER_BULK_FILE"]

      dir.glob("default-cards-*.jsonl.gz").max_by(&:mtime) or raise "no bulk file under #{dir}"
    end
```

- [ ] In `script/fetch_art.rb`, `script/build_index.rb` and `script/agreement.rb`, replace each `CardScannerPhase2::CORPORA.keys.flat_map` with `CardScannerPhase2.truth_corpora.flat_map` (one occurrence per file). Run `grep -n "CORPORA.keys" spikes/card_scanner/phase2/script/{fetch_art,build_index,agreement}.rb`; expect no output. Then run `bundle exec rspec spikes/card_scanner/phase2/spec`; expect 0 failures. Commit: `refactor(spike): let spec 008's art tools take their folder, bulk file and truth corpora as settings (010)`.
- [ ] Write `spikes/card_scanner/phase3/lib/card_scanner_phase3.rb`:

```ruby
require "json"
require "pathname"
require_relative "../../phase2/lib/card_scanner_phase2"

# The art spike (spec 010): the art index on a phone, and art on live captures. It reuses spec 008's art tools
# (CardScannerPhase2), run with CARD_SCANNER_WORK_DIR=~/card-scanner-corpus/art-cache and CARD_SCANNER_TRUTH_CORPORA=sitting.
module CardScannerPhase3
  ROOT = Pathname(File.expand_path("..", __dir__))
  REPO = CardScannerPhase2::REPO
  FIXTURE_DIR = CardScannerPhase2::FIXTURE_DIR
  # Spec 008's measured full fetch (research.md §7), the basis of the estimate (spec 010 AC-1.2).
  SPEC008_FETCH = { "images" => 50_923, "bytes" => 707_955_694, "seconds" => 9_448.8 }.freeze
  # Spec 009's misses and corrections, reported card by card (AC-4.6).
  NAMED = %w[IMG_6808.jpeg IMG_6829.jpeg IMG_6821.jpeg IMG_6814.jpeg IMG_6823.jpeg].freeze

  def self.corpus_dir = CardScannerPhase2.corpus_dir
  def self.sitting_dir = corpus_dir.join("phase2-sitting")
  def self.runs_dir = corpus_dir.join("runs/phase3")
end
```

- [ ] Write `spikes/card_scanner/phase3/spec/phase3_helper.rb`:

```ruby
# Loads the art spike's code (spec 010) for its specs; these are not part of bin/ci.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "card_scanner_phase3"
```

- [ ] Write the failing spec `spikes/card_scanner/phase3/spec/card_scanner_phase3/estimate_spec.rb`:

```ruby
require_relative "../phase3_helper"
require "card_scanner_phase3/estimate"

RSpec.describe CardScannerPhase3::Estimate do
  let(:artworks) do
    { "a" => { "small" => "u1" }, "b" => { "small" => "u2" }, "c" => { "small" => nil }, "d" => { "small" => "u4" } }
  end

  it "estimates the uncached fetchable artworks from spec 008's measured cost per image (AC-1.2)", :aggregate_failures do
    estimate = described_class.call(artworks, cached: ->(id) { id == "a" }, measured: { "images" => 10, "bytes" => 1_000, "seconds" => 36.0 })
    expect(estimate).to include("artworks" => 4, "with_image_url" => 3, "cached" => 1, "to_fetch" => 2, "bytes" => 200, "hours" => 0.002)
    expect(estimate["per_image"]).to eq("bytes" => 100.0, "seconds" => 3.6)
    expect(estimate["basis"]).to include("10 images")
  end
end
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase3/spec`. Expect a failure (`cannot load such file -- card_scanner_phase3/estimate`).
- [ ] Write `spikes/card_scanner/phase3/lib/card_scanner_phase3/estimate.rb`:

```ruby
module CardScannerPhase3
  # The full fetch's cost before anything is fetched (spec 010 AC-1.2): the uncached artworks that have an image URL, at
  # spec 008's measured bytes and seconds per image. Nothing is fetched to make it.
  module Estimate
    module_function

    def call(artworks, cached:, size: "small", measured: SPEC008_FETCH)
      fetchable = artworks.select { |_, artwork| artwork[size] }
      remaining = fetchable.keys.reject { cached.call(it) }
      per_bytes = measured["bytes"].fdiv(measured["images"])
      per_seconds = measured["seconds"].fdiv(measured["images"])
      { "artworks" => artworks.size, "with_image_url" => fetchable.size, "cached" => fetchable.size - remaining.size, "to_fetch" => remaining.size,
        "per_image" => { "bytes" => per_bytes.round(1), "seconds" => per_seconds.round(4) }, "bytes" => (per_bytes * remaining.size).round,
        "hours" => (per_seconds * remaining.size / 3600).round(3),
        "basis" => "spec 008 research.md §7: #{measured["images"]} images, #{measured["bytes"]} bytes, #{measured["seconds"]} s" }
    end
  end
end
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase3/spec`. Expect 0 failures.
- [ ] Write `spikes/card_scanner/phase3/script/truth.rb`:

```ruby
# Copies spec 009's 35-card ground truth into the art spike's working folder as the "sitting" corpus (spec 010).
# Usage: CARD_SCANNER_WORK_DIR=… bundle exec ruby spikes/card_scanner/phase3/script/truth.rb
require "bundler/setup"
require "fileutils"
require_relative "../lib/card_scanner_phase3"

dir = CardScannerPhase2::WORK_DIR.join("truth", "sitting")
dir.mkpath
FileUtils.cp(CardScannerPhase3.sitting_dir.join("ground_truth.json"), dir.join("ground_truth.json"))
puts "#{JSON.parse(dir.join("ground_truth.json").read).fetch("photos").size} truth records -> #{dir}"
```

- [ ] Write `spikes/card_scanner/phase3/script/estimate.rb`:

```ruby
# Commits the full fetch's estimate (spec 010 AC-1.2) from the listed artworks and the cache, fetching nothing.
# Usage: CARD_SCANNER_WORK_DIR=… bundle exec ruby spikes/card_scanner/phase3/script/estimate.rb
require "bundler/setup"
require "time"
require_relative "../lib/card_scanner_phase3"
require_relative "../lib/card_scanner_phase3/estimate"
require_relative "../../phase2/lib/card_scanner_phase2/bulk_artworks"

data = CardScannerPhase2::BulkArtworks.load
cache = CardScannerPhase2::WORK_DIR.join("artwork", "small")
estimate = CardScannerPhase3::Estimate.call(data["artworks"], cached: ->(id) { cache.join("#{id}.jpg").file? })
  .merge("bulk_version" => data["bulk_version"], "counts" => data["counts"], "at" => Time.now.utc.iso8601)
CardScannerPhase3::FIXTURE_DIR.join("phase3_fetch_estimate.json").write(JSON.pretty_generate(estimate))
puts JSON.pretty_generate(estimate)
```

- [ ] Run the setup:
  1. Run `bundle exec ruby spikes/card_scanner/phase2/script/artworks.rb`. Expect `default-cards-20261003210542: {…}`, with the counts recorded (AC-1.1).
  2. Run `bundle exec ruby spikes/card_scanner/phase3/script/truth.rb`. Expect `35 truth records`.
  3. Run `bundle exec ruby spikes/card_scanner/phase2/script/fetch_art.rb --size small --mode corpus`. This fetches only the 35 cards' artworks, at most about 35 requests. Expect `failed: 0`; any failure is listed for the findings (AC-1.4).
  4. Run `bundle exec ruby spikes/card_scanner/phase3/script/estimate.rb`.
- [ ] Commit `spec/fixtures/card_scanner/phase3_fetch_estimate.json` and the phase 3 files: `feat(spike): estimate the full art fetch from spec 008's measured cost (010)`.
- [ ] **Checkpoint (the maintainer).** Give the estimate: artworks to fetch, bytes and hours. Ask for approval of the full fetch, or for a decline with approval of the distractor sample (500 artworks, seed 20261003). Record the ruling in Phase 4's commit body. Run Phases 2 and 3 meanwhile.

---

## Phase 2: Frame keeping in measurement mode (app)

**Implements:** FR-3, Story 3 | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-5.5 (the app part)
**Files:** `app/javascript/controllers/card_reader_controller.js`, `app/javascript/controllers/measurement_controller.js`, `app/models/scanner/measurement_run.rb`, `app/controllers/scanner/measurements/captures_controller.rb`, `app/controllers/concerns/measurement_mode.rb`, `app/views/scanner/measurements/_panel.html.erb`, `config/environments/development.rb`, `spec/models/scanner/measurement_run_spec.rb`, `spec/requests/scanner/measurements_spec.rb`, `spec/system/scanner_measurement_spec.rb`
**Interfaces:** Consumes: `camera.grab()` → `{ image, card }`. Produces:
- `Scanner::MeasurementRun.keep_frames?` and `MAX_FRAME_BYTES`
- `#record!(…, frame:, guide:)`, writing `<dir>/<file>/capture-NNN-frame.png` and, in `capture-NNN.json`, the keys `guide` (`x`, `y`, `width`, `height`, as floats), `frame_width` and `frame_height`
- the read event's `frame: { image, guide }` (live captures only)

- [ ] Add failing examples to `spec/models/scanner/measurement_run_spec.rb`:

```ruby
  describe "frames (spec 010 Story 3)" do
    let(:png) { ->(width = 4, height = 3) { StringIO.new("\x89PNG\r\n\x1A\n".b + [ 13 ].pack("N") + "IHDR" + [ width, height ].pack("NN") + "\x08\x06\x00\x00\x00".b) } }
    let(:guide) { { "x" => 1.5, "y" => 2.25, "width" => 10.0, "height" => 14.0 } }

    before { dir.join("manifest.csv").write("file,set,number,foil\nS001,mom,123,no\n") }

    def capture(frame:, guide: self.guide)
      run.record!(run.row("S001"), name_text: "Bolt", collector_text: "", ms: 200, user_agent: "iPhone", name_strip: png.call, collector_strip: png.call,
        frame:, guide:)
    end

    it "stores the frame beside the strips, with the guide rect and the frame's size (AC-3.1)", :aggregate_failures do
      capture(frame: png.call(1080, 1920))
      expect(dir.join("runs/live/S001/capture-001-frame.png")).to exist
      expect(run.captures(run.row("S001")).sole).to include("guide" => guide, "frame_width" => 1080, "frame_height" => 1920)
    end

    it "refuses the whole capture for a frame that isn't a PNG or is over the limit (AC-3.2)", :aggregate_failures do
      expect { capture(frame: StringIO.new("not a png")) }.to raise_error(described_class::InvalidCapture, /frame wasn't a PNG of at most 32 MB/)
      stub_const("Scanner::MeasurementRun::MAX_FRAME_BYTES", 20)
      expect { capture(frame: png.call) }.to raise_error(described_class::InvalidCapture)
      expect(dir.join("runs/live/S001")).not_to exist
    end

    it "refuses a frame without a whole guide rect" do
      expect { capture(frame: png.call, guide: { "x" => 1 }) }.to raise_error(described_class::InvalidCapture, /guide rect/)
    end

    it "stores no frame keys when no frame comes" do
      capture(frame: nil, guide: nil)
      expect(run.captures(run.row("S001")).sole.keys).not_to include("guide", "frame_width")
    end
  end

  it "keeps frames only when the measurement config says so (AC-3.1)", :aggregate_failures do
    expect(described_class).not_to be_keep_frames
    Rails.configuration.x.scanner_measurement = { manifest: "m", dir: "d", keep_frames: true }
    expect(described_class).to be_keep_frames
  ensure
    Rails.configuration.x.scanner_measurement = nil
  end
```

- [ ] Add failing examples to `spec/requests/scanner/measurements_spec.rb` (top level):

```ruby
  describe "frames (spec 010)" do
    def capture_with_frame
      post scanner_measurement_captures_path, headers: turbo, params: { capture: { file: "IMG_1.jpeg", name_text: "Bolt", collector_text: "", ms: "1",
        user_agent: "iPhone", name_strip: upload(png), collector_strip: upload(png), outline: "live", frame: upload(frame_png),
        guide: { x: 1.5, y: 2, width: 10, height: 14 }.to_json } }
    end

    it "stores the frame and guide rect when frame keeping is on (AC-3.1)", :aggregate_failures do
      Rails.configuration.x.scanner_measurement = Rails.configuration.x.scanner_measurement.merge(keep_frames: true)
      capture_with_frame
      expect(response).to have_http_status(:ok)
      expect(current.captures(current.row("IMG_1.jpeg")).sole).to include("frame_width" => 900, "guide" => include("x" => 1.5))
    end

    it "ignores a frame when frame keeping is off" do
      capture_with_frame
      expect(current.captures(current.row("IMG_1.jpeg")).sole).not_to have_key("guide")
    end
  end
```

  Define `capture_with_frame` at the top level of the file, beside `capture`, rather than inside the `describe` block, so the off-mode list can use it: add `-> { capture_with_frame }` to that list of 404 requests (AC-3.3). Its frame comes from a method, not a `let`, which keeps the file within RuboCop's five memoised helpers:

```ruby
  def frame_png = "\x89PNG\r\n\x1A\n".b + [ 13 ].pack("N") + "IHDR" + [ 900, 1200 ].pack("NN") + "\x08\x06\x00\x00\x00".b
```
- [ ] Add a failing system example to `spec/system/scanner_measurement_spec.rb`:

```ruby
  it "keeps the live frame and its guide rect, and still sends only the text and key for the reading (spec 010 AC-3.1, AC-5.5)", :aggregate_failures do
    Rails.configuration.x.scanner_measurement = Rails.configuration.x.scanner_measurement.merge(keep_frames: true)
    capture_lightning_bolt
    capture = Scanner::MeasurementRun.current.captures(Scanner::MeasurementRun.current.row("IMG_1.jpeg")).sole
    expect(capture).to include("frame_width" => 900, "frame_height" => 1200, "guide" => include("width" => be > 0))
    expect(corpus.join("runs/live/IMG_1.jpeg/capture-001-frame.png")).to exist
    expect(scanner_sent).to include([ "reading[name_text]", "reading[collector_text]", "reading[key]" ])
  end
```

- [ ] Run `bin/rspec spec/models/scanner/measurement_run_spec.rb spec/requests/scanner/measurements_spec.rb spec/system/scanner_measurement_spec.rb`. Expect the new examples to FAIL.
- [ ] In `app/models/scanner/measurement_run.rb`:
  - After `MAX_STRIP_BYTES = 5.megabytes`, add `MAX_FRAME_BYTES = 32.megabytes` and `GUIDE_KEYS = %w[x y width height].freeze`.
  - After `def self.enabled?`, add:

```ruby
  # Spec 010: live captures also keep their full frame when the measurement config's keep_frames is set (development only).
  def self.keep_frames? = Rails.configuration.x.scanner_measurement.to_h[:keep_frames].present?
```

  - Change `record!` to:

```ruby
  def record!(row, name_text:, collector_text:, ms:, user_agent:, name_strip:, collector_strip:, extra: {}, frame: nil, guide: nil)
    if [ name_text, collector_text ].any? { it.length > MTG::Reading::MAX_TEXT_LENGTH }
      raise InvalidCapture, "That capture's text was too long to store."
    end

    images = { "name" => png!(name_strip), "collector" => png!(collector_strip) }
    frame_data = frame && png!(frame, limit: MAX_FRAME_BYTES, what: "frame")
    raise InvalidCapture, "The frame's guide rect was missing, so nothing was stored." if frame_data && !whole_guide?(guide)

    number = captures(row).size + 1
    kind = number == 1 ? :measured : :retake
    stem = format("capture-%03d", number)
    row_dir(row).mkpath
    images.each { |strip, data| row_dir(row).join("#{stem}-#{strip}.png").binwrite(data) }
    row_dir(row).join("#{stem}-frame.png").binwrite(frame_data) if frame_data
    row_dir(row).join("#{stem}.json").write(JSON.pretty_generate({ "file" => row.file, "kind" => kind.to_s, "name_text" => name_text,
      "collector_text" => collector_text, "ms" => ms, "user_agent" => user_agent, "captured_at" => Time.current.utc.iso8601 }
      .merge(extra.to_h.stringify_keys.slice(*EXTRA_FIELDS).compact_blank).merge(frame_fields(frame_data, guide))))
    kind
  end
```

  - Replace `png!` and add the two helpers (private):

```ruby
    def png!(upload, limit: MAX_STRIP_BYTES, what: "strip")
      data = upload.respond_to?(:read) ? upload.read(limit + 1) : nil
      return data if data && data.bytesize <= limit && data.b.start_with?(PNG_SIGNATURE)

      raise InvalidCapture, "A #{what} wasn't a PNG of at most #{limit / 1.megabyte} MB, so nothing was stored."
    end

    def whole_guide?(guide) = guide.is_a?(Hash) && GUIDE_KEYS.all? { guide[it].is_a?(Numeric) }

    # The guide rect as the page used it, and the frame's size from its PNG header (width and height at bytes 16–23).
    def frame_fields(data, guide)
      return {} unless data

      width, height = data.byteslice(16, 8).unpack("NN")
      { "guide" => guide.slice(*GUIDE_KEYS).transform_values(&:to_f), "frame_width" => width, "frame_height" => height }
    end
```

  (The test PNG is 29 bytes: signature, IHDR length and type, width, height and 5 more bytes. A 20-byte limit refuses it with "A frame wasn't a PNG of at most 0 MB…", which still raises `InvalidCapture`.)
- [ ] In `app/controllers/scanner/measurements/captures_controller.rb`:
  - Add `frame guide` to the `params.expect(capture: %i[…])` list.
  - Pass `**frame_params(capture)` to `record!`.
  - Add the private helper:

```ruby
  private
    # Spec 010: the live frame and its guide rect, kept only when the measurement config says so.
    def frame_params(capture)
      return {} unless Scanner::MeasurementRun.keep_frames? && capture[:frame]

      { frame: capture[:frame], guide: parsed_guide(capture[:guide]) }
    end

    def parsed_guide(text)
      JSON.parse(text.to_s)
    rescue JSON::ParserError
      nil # record! refuses a frame without a whole guide rect
    end
```

- [ ] In `app/controllers/concerns/measurement_mode.rb`, add `keep_frames: Scanner::MeasurementRun.keep_frames?` to the hash `panel_locals` returns. In `app/views/scanner/measurements/_panel.html.erb`:
  - change the locals line to `<%# locals: (run:, next_row:, expected:, keep_frames: false, notice: nil, alert: false) %>`
  - add `data-measurement-keep-frames-value="<%= keep_frames %>"` to the section tag
  - add `<% if keep_frames %><p class="c-field__hint">Keeping each live capture's full frame (spec 010), up to 32 MB.</p><% end %>` after the storage hint
- [ ] In `config/environments/development.rb`, add `keep_frames: ENV["COLLECTOR_SCANNER_KEEP_FRAMES"] == "1"` to the `config.x.scanner_measurement` hash, with the comment `# Spec 010: COLLECTOR_SCANNER_KEEP_FRAMES=1 also keeps each live capture's full frame.`
- [ ] In `app/javascript/controllers/card_reader_controller.js#read`, replace the line `this.dispatch("read", { detail: { ...reading, strips } })` with:

```js
      // Spec 010: a live capture's frame and guide rect travel with the event, in memory, for measurement mode only.
      const frame = source.outline === "live" ? { image, guide: card } : null
      this.dispatch("read", { detail: { ...reading, strips, frame } })
```

- [ ] In `app/javascript/controllers/measurement_controller.js`:
  - Add `keepFrames: Boolean` to `static values`.
  - Add `frame` to the destructured detail in `store`.
  - Before `this.pending = body`, add:

```js
    if (this.keepFramesValue && frame) {
      body.append("capture[frame]", await png(frame.image), "frame.png")
      body.append("capture[guide]", JSON.stringify(frame.guide))
    }
```

- [ ] Run `bin/rspec spec/models/scanner/measurement_run_spec.rb spec/requests/scanner/measurements_spec.rb spec/system/scanner_measurement_spec.rb spec/system/scanner_spec.rb spec/system/scanner_detection_spec.rb`. Expect 0 failures. Then run `bin/ci` and expect it to pass. Commit: `feat(scanner): keep live frames in measurement mode for the art spike (010)`.

---

## Phase 3: The phone server, the timing page and the replay page

**Implements:** FR-2, FR-4 (apparatus), Story 2 and Story 4 apparatus | **Satisfies:** AC-2.1, AC-2.2, AC-2.5 (the page), AC-4.1, AC-4.2, AC-4.3, AC-4.8 (the page)
**Files:** `spikes/card_scanner/phase2/public/search.js`, `spikes/card_scanner/phase3/lib/card_scanner_phase3/server.rb`, `spikes/card_scanner/phase3/{config.ru,puma.rb}`, `spikes/card_scanner/phase3/public/{timing.html,timing.js,replay.html,replay.js}`, `spikes/card_scanner/phase3/spec/card_scanner_phase3/server_spec.rb`, `spikes/card_scanner/phase3/script/gzip_index.rb`
**Interfaces:** Consumes: `search.js`, `fingerprint.js`, `app/javascript/scanner/{geometry,detector}.js`. Produces:
- `CardScannerPhase3::Server.new(phase2_public:, phase3_public:, app_scanner:, work_dir:, corpus_dir:, runs_dir:, settings_path:, queries_path:, cards_dir:)`
- `window.__phase3Timing.run(mode)`, with mode `"cold"` or `"warm"`, which posts its results to `/phone/results`
- `window.__phase3.run({ path, kind, guide, right })`, with kind `"guide"`, `"detected"` or `"photo"`, returning `{ kind, crop?, found?, corners?, hashes, top, rightDistance, searchMs }`

- [ ] In `spikes/card_scanner/phase2/public/search.js`, replace `loadIndex` with the two functions below. The parsing is unchanged, only split out:

```js
export async function loadIndex(url) {
  if (index) return index
  index = parseIndex(new Uint8Array(await (await fetch(url)).arrayBuffer()))
  return index
}

// The flat index's records as the search reads them; exported so spec 010's timing page can time the parse on its own.
export function parseIndex(bytes) {
  const count = bytes.length / RECORD
  const ids = new Array(count), words = new Uint32Array(count * 32)
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  for (let i = 0; i < count; i++) {
    const base = i * RECORD
    const h = Array.from(bytes.subarray(base, base + 16), (b) => b.toString(16).padStart(2, "0")).join("")
    ids[i] = `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`
    for (let w = 0; w < 32; w++) words[i * 32 + w] = view.getUint32(base + 16 + w * 4)
  }
  return { count, ids, words, bytes: bytes.length }
}
```

- [ ] Write the failing spec `spikes/card_scanner/phase3/spec/card_scanner_phase3/server_spec.rb`:

```ruby
require_relative "../phase3_helper"
require "card_scanner_phase3/server"
require "fileutils"
require "rack/mock"
require "tmpdir"
require "zlib"

RSpec.describe CardScannerPhase3::Server do
  let(:root) do
    Pathname(Dir.mktmpdir).tap do |root|
      %w[p2 p3 app work/index corpus/phase2-sitting runs cards/IMG_1].each { root.join(it).mkpath }
      root.join("p2/search.js").write("export {}")
      root.join("p3/timing.html").write("<!doctype html>")
      root.join("p3/replay.html").write("<!doctype html>")
      root.join("app/detector.js").write("export {}")
      root.join("work/index/art_index.bin.gz").binwrite(Zlib.gzip("x" * 144))
      root.join("corpus/phase2-sitting/IMG_9.jpeg").binwrite("\xFF\xD8\xFF".b)
      root.join("cards/IMG_1/card.png").binwrite("\x89PNG".b)
      root.join("settings.json").write({ "fingerprint" => { "grid" => [ 17, 16 ] }, "hand" => {} }.to_json)
      root.join("queries.json").write([ { "file" => "IMG_1.jpeg", "hashes" => [ "00" * 128 ] } ].to_json)
    end
  end
  let(:app) do
    described_class.new(phase2_public: root.join("p2"), phase3_public: root.join("p3"), app_scanner: root.join("app"), work_dir: root.join("work"),
      corpus_dir: root.join("corpus"), runs_dir: root.join("runs"), settings_path: root.join("settings.json"), queries_path: root.join("queries.json"),
      cards_dir: root.join("cards"))
  end
  let(:lan) { { "REMOTE_ADDR" => "192.168.1.22" } }
  let(:local) { { "REMOTE_ADDR" => "127.0.0.1" } }

  after { FileUtils.remove_entry(root) }

  def get(path, env) = Rack::MockRequest.new(app).get(path, env)

  it "serves the timing page to the phone under a strict policy without inline script (AC-2.1, FR-2)", :aggregate_failures do
    response = get("/phone/timing.html", lan)
    expect(response.status).to eq(200)
    expect(response.headers["content-security-policy"]).to include("script-src 'self';", "connect-src 'self'", "report-uri /csp-report")
    expect(response.headers["content-security-policy"]).not_to include("unsafe-inline", "nonce-")
  end

  it "serves the index gzipped and cacheable, with the encoded size (AC-2.1)", :aggregate_failures do
    response = get("/phone/index.bin", lan)
    expect(response.headers).to include("content-encoding" => "gzip", "cache-control" => "public, max-age=31536000, immutable")
    expect(response.headers["content-length"].to_i).to eq(root.join("work/index/art_index.bin.gz").size)
  end

  it "serves the queries, the straightened cards and only the fingerprint settings to the phone", :aggregate_failures do
    expect(JSON.parse(get("/phone/queries.json", lan).body).sole["file"]).to eq("IMG_1.jpeg")
    expect(get("/phone/cards/IMG_1.png", lan).status).to eq(200)
    expect(JSON.parse(get("/settings.json", lan).body).keys).to eq([ "fingerprint" ])
  end

  it "keeps the corpus, the working folder, the app's modules and the replay off the LAN (FR-2)", :aggregate_failures do
    %w[/corpus/phase2-sitting/IMG_9.jpeg /work/index/art_index.bin.gz /app/scanner/detector.js /replay.html].each do |path|
      expect(get(path, lan).status).to eq(403), path
      expect(get(path, local).status).to eq(200), path
    end
  end

  it "accepts the timing page's results on one path from the LAN, and nothing else", :aggregate_failures do
    response = Rack::MockRequest.new(app).post("/phone/results", lan.merge(input: { "mode" => "cold" }.to_json))
    expect(response.status).to eq(201)
    expect(root.join("runs/phone").glob("*.json").size).to eq(1)
    expect(Rack::MockRequest.new(app).post("/outputs/x/y/z.json", lan.merge(input: "{}")).status).to eq(404)
  end

  it "refuses an oversized results body" do
    response = Rack::MockRequest.new(app).post("/phone/results", lan.merge(input: "x" * 1_000_001))
    expect(response.status).to eq(413)
  end
end
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase3/spec`. Expect it to FAIL (`cannot load such file -- card_scanner_phase3/server`).
- [ ] Write `spikes/card_scanner/phase3/lib/card_scanner_phase3/server.rb`:

```ruby
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
    POLICY = [ "default-src 'self'", "script-src 'self'", "connect-src 'self'", "img-src 'self' blob:", "style-src 'self'", "object-src 'none'",
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
      [ status, headers.to_h.merge("content-security-policy" => POLICY), body ]
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

      def local(request) = LOOPBACK.include?(request.ip) ? yield : text(403, "Forbidden")

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
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase3/spec`. Expect 0 failures.
- [ ] Write `spikes/card_scanner/phase3/config.ru`:

```ruby
$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "card_scanner_phase3"
require "card_scanner_phase3/server"

run CardScannerPhase3::Server.new(
  phase2_public: CardScannerPhase2::ROOT.join("public"),
  phase3_public: CardScannerPhase3::ROOT.join("public"),
  app_scanner: CardScannerPhase3::REPO.join("app/javascript/scanner"),
  work_dir: CardScannerPhase2::WORK_DIR,
  corpus_dir: CardScannerPhase3.corpus_dir,
  runs_dir: CardScannerPhase3.runs_dir,
  settings_path: CardScannerPhase2::SETTINGS_PATH,
  queries_path: CardScannerPhase2::WORK_DIR.join("phone_queries.json"),
  cards_dir: CardScannerPhase3.corpus_dir.join("runs/phase2/held-hand"))
```

- [ ] Write `spikes/card_scanner/phase3/puma.rb`:

```ruby
# The art spike's server (spec 010): HTTPS on the LAN for the phone (spec 007's certificate), plain HTTP on loopback for the
# desktop replay. Start: CARD_SCANNER_WORK_DIR=… bundle exec puma -C spikes/card_scanner/phase3/puma.rb
cert = File.expand_path(ENV.fetch("CERT_DIR", "~/.local/share/collector-dev-https"))
bind "ssl://0.0.0.0:#{ENV.fetch("SPIKE_PORT", 4300)}?key=#{cert}/dev.key&cert=#{cert}/dev.crt"
bind "tcp://127.0.0.1:#{ENV.fetch("SPIKE_LOCAL_PORT", 4301)}"
rackup File.expand_path("config.ru", __dir__)
threads 1, 4
```

- [ ] Write `spikes/card_scanner/phase3/script/gzip_index.rb`, which writes the phone's inputs:

```ruby
# Writes what the timing page serves (spec 010 Story 2): the index gzipped (as the app would serve a static file) and spec
# 008's 43 held-out query fingerprints. Usage: CARD_SCANNER_WORK_DIR=… bundle exec ruby spikes/card_scanner/phase3/script/gzip_index.rb
require "bundler/setup"
require "zlib"
require_relative "../lib/card_scanner_phase3"

index = CardScannerPhase2::WORK_DIR.join("index/art_index.bin")
Zlib::GzipWriter.open(index.sub_ext(".bin.gz").to_s, Zlib::BEST_COMPRESSION) { it.write(index.binread) }
records = JSON.parse(CardScannerPhase3::FIXTURE_DIR.join("phase2_results.json").read).fetch("records")
queries = records.select { it["half"] == "held_out" && it.dig("art_full", "hashes") }.map { { "file" => it["file"], "hashes" => it.dig("art_full", "hashes") } }
CardScannerPhase2::WORK_DIR.join("phone_queries.json").write(JSON.generate(queries))
puts "index #{index.size} bytes, gzip #{index.sub_ext(".bin.gz").size} bytes; #{queries.size} queries"
```

- [ ] Write `spikes/card_scanner/phase3/public/timing.html`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Art index on this phone (spec 010)</title>
  <script type="module" src="/phone/timing.js"></script>
</head>
<body>
  <h1>Art index timing</h1>
  <p><button id="cold" type="button">Run cold</button> <button id="warm" type="button">Run warm</button></p>
  <p id="status">Ready.</p>
  <pre id="result"></pre>
</body>
</html>
```

- [ ] Write `spikes/card_scanner/phase3/public/timing.js`:

```js
import { parseIndex, search } from "/phase2/search.js"
import { fingerprints } from "/phase2/fingerprint.js"

// Spec 010 Story 2: loads the full art index on this device and times the download, the parse, 43 searches, 100 searches for
// responsiveness, and the fingerprint of straightened cards; posts everything to /phone/results.
const status = document.getElementById("status"), out = document.getElementById("result")
const bytesOf = (hex) => Uint8Array.from(hex.match(/../g), (h) => parseInt(h, 16))
const popcount = (v) => { v -= (v >>> 1) & 0x55555555; v = (v & 0x33333333) + ((v >>> 2) & 0x33333333); return (((v + (v >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24 }
const bits = (a, b) => { let d = 0; for (let i = 0; i < a.length; i++) d += popcount(a[i] ^ b[i]); return d }
const median = (xs) => { const s = [ ...xs ].sort((a, b) => a - b), m = s.length >> 1; return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2 }
const tick = () => new Promise((resolve) => setTimeout(resolve, 0))

async function run(mode) {
  status.textContent = `Running ${mode}…`
  const settings = (await (await fetch("/settings.json")).json()).fingerprint
  const url = new URL("/phone/index.bin", location).href
  performance.clearResourceTimings()
  const started = performance.now()
  const response = await fetch(url, { cache: mode === "cold" ? "reload" : "force-cache" })
  const bytes = new Uint8Array(await response.arrayBuffer())
  const downloaded = performance.now()
  const index = parseIndex(bytes)
  const ready = performance.now()
  const entry = performance.getEntriesByName(url).pop() || {}
  const queries = await (await fetch("/phone/queries.json")).json()
  const searches = queries.map(({ file, hashes }) => {
    const t = performance.now(), top = search(index, hashes.map(bytesOf), 10)
    return { file, ms: performance.now() - t, top: top[0] }
  })
  let gap = 0, last = performance.now()
  for (let i = 0; i < 100; i++) {
    search(index, queries[i % queries.length].hashes.map(bytesOf), 10)
    status.textContent = `Responsiveness: ${i + 1}/100`
    await tick()
    const now = performance.now(); gap = Math.max(gap, now - last); last = now
  }
  const cards = []
  for (const { file, hashes } of queries.slice(0, 12)) {
    const blob = await (await fetch(`/phone/cards/${file.replace(/\.\w+$/, "")}.png`)).blob()
    const bitmap = await createImageBitmap(blob)
    const canvas = Object.assign(document.createElement("canvas"), { width: bitmap.width, height: bitmap.height })
    canvas.getContext("2d", { willReadFrequently: true }).drawImage(bitmap, 0, 0)
    const t = performance.now(), mine = fingerprints(canvas, settings), ms = performance.now() - t
    cards.push({ file, ms, maxBits: Math.max(...mine.map((h, k) => bits(h, bytesOf(hashes[k])))) })
  }
  const result = {
    mode, userAgent: navigator.userAgent, at: new Date().toISOString(),
    index: { count: index.count, decodedBytes: index.bytes, encodedBodySize: entry.encodedBodySize ?? null, transferSize: entry.transferSize ?? null,
      decodedBodySize: entry.decodedBodySize ?? null, contentLength: Number(response.headers.get("content-length")) || null },
    downloadMs: downloaded - started, readyMs: ready - downloaded,
    search: { n: searches.length, medianMs: median(searches.map((s) => s.ms)), slowestMs: Math.max(...searches.map((s) => s.ms)), tops: searches.map(({ file, top }) => ({ file, top })) },
    responsive: { searches: 100, maxGapMs: gap, completed: true },
    fingerprint: { n: cards.length, medianMs: median(cards.map((c) => c.ms)), slowestMs: Math.max(...cards.map((c) => c.ms)), maxBits: Math.max(...cards.map((c) => c.maxBits)), cards },
    memory: { decodedBytes: index.bytes, wordsBytes: index.words.byteLength, ids: index.count }
  }
  const saved = await fetch("/phone/results", { method: "POST", body: JSON.stringify(result), headers: { "Content-Type": "application/json" } })
  out.textContent = JSON.stringify({ ...result, search: { ...result.search, tops: `${result.search.tops.length} tops` } }, null, 2)
  status.textContent = saved.ok ? `Done (${mode}); results saved.` : `Done (${mode}); saving failed: HTTP ${saved.status}`
  return result
}

document.getElementById("cold").addEventListener("click", () => run("cold"))
document.getElementById("warm").addEventListener("click", () => run("warm"))
window.__phase3Timing = { run }
```

- [ ] Write `spikes/card_scanner/phase3/public/replay.html` (loopback only; the import map lets the app's `detector.js` resolve `scanner/geometry`):

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Art replay (spec 010)</title>
  <script type="importmap">{ "imports": { "scanner/geometry": "/app/scanner/geometry.js", "scanner/detector": "/app/scanner/detector.js" } }</script>
  <script type="module" src="/replay.js"></script>
</head>
<body><p id="status">Loading the index…</p></body>
</html>
```

  The server's policy forbids inline script, which would block this import map. So `replay.html` and `replay.js` are served without the policy. In `server.rb#call`, set the policy header only when the path doesn't start with `/replay`, `/app/scanner`, `/work` or `/corpus`, which are all loopback only:

```ruby
    def call(env)
      request = Rack::Request.new(env)
      status, headers, body = route(request)
      headers = headers.to_h
      headers = headers.merge("content-security-policy" => POLICY) unless request.path_info.match?(%r{\A/(replay|app/scanner/|work/|corpus/)})
      [ status, headers, body ]
    end
```

  Add this example to `server_spec.rb`, and run it (expect a pass after the change above):

```ruby
  it "sends the policy on the phone's routes and not on the loopback replay" do
    expect([ get("/phone/timing.html", lan), get("/replay.html", local) ].map { it.headers.key?("content-security-policy") }).to eq([ true, false ])
  end
```

- [ ] Write `spikes/card_scanner/phase3/public/replay.js`:

```js
import { detectCard, warp, WARP } from "scanner/detector"
import { fingerprints, hex } from "/phase2/fingerprint.js"
import { loadIndex, search } from "/phase2/search.js"

// Spec 010 Story 4: one stored frame or photo through one path. "guide" crops the guide rect from the frame at native
// pixels (rounded outward, no resize) and takes it as the card; "detected" and "photo" find the card with the app's
// shipped detector and straighten it (spec 008's warp size). Every job also measures the right artwork's distance directly.
const settings = (await (await fetch("/settings.json")).json()).fingerprint
const index = await loadIndex("/work/index/art_index.bin")
const status = document.getElementById("status")

const popcount = (v) => { v -= (v >>> 1) & 0x55555555; v = (v & 0x33333333) + ((v >>> 2) & 0x33333333); return (((v + (v >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24 }

function canvasOf(width, height) {
  const canvas = Object.assign(document.createElement("canvas"), { width, height })
  return { canvas, context: canvas.getContext("2d", { willReadFrequently: true }) }
}

async function source(path) {
  const bitmap = await createImageBitmap(await (await fetch(`/corpus/${path}`)).blob()) // applies a photo's EXIF orientation
  const { canvas, context } = canvasOf(bitmap.width, bitmap.height)
  context.drawImage(bitmap, 0, 0)
  return canvas
}

function crop(frame, guide) {
  const x0 = Math.max(0, Math.floor(guide.x)), y0 = Math.max(0, Math.floor(guide.y))
  const x1 = Math.min(frame.width, Math.ceil(guide.x + guide.width)), y1 = Math.min(frame.height, Math.ceil(guide.y + guide.height))
  const { canvas, context } = canvasOf(x1 - x0, y1 - y0)
  context.drawImage(frame, x0, y0, x1 - x0, y1 - y0, 0, 0, x1 - x0, y1 - y0)
  return { canvas, rect: { x: x0, y: y0, width: x1 - x0, height: y1 - y0 } }
}

function distanceTo(id, hashes) {
  const i = index.ids.indexOf(id)
  if (i < 0) return null
  let best = 1025
  for (const h of hashes) {
    const v = new DataView(h.buffer, h.byteOffset, 128)
    let d = 0
    for (let w = 0; w < 32; w++) d += popcount(index.words[i * 32 + w] ^ v.getUint32(w * 4))
    best = Math.min(best, d)
  }
  return best
}

async function run({ path, kind, guide, right }) {
  const frame = await source(path)
  let card, extra
  if (kind === "guide") {
    const cropped = crop(frame, guide)
    card = cropped.canvas
    extra = { crop: cropped.rect }
  } else {
    const corners = detectCard(frame)
    if (!corners) return { kind, found: false, top: [], rightDistance: null }
    card = warp(frame, corners, WARP.width, WARP.height)
    extra = { found: true, corners }
  }
  const hashes = fingerprints(card, settings)
  const started = performance.now()
  const top = search(index, hashes, 10)
  return { kind, ...extra, hashes: hashes.map(hex), top, rightDistance: right ? distanceTo(right, hashes) : null, searchMs: performance.now() - started }
}

status.textContent = `Ready: ${index.count} artworks`
window.__phase3 = { ready: true, run, count: index.count }
```

- [ ] Run `bundle exec rspec spikes/card_scanner/phase3/spec spikes/card_scanner/phase2/spec` and `bin/rubocop spikes/card_scanner`. Expect 0 failures and no offenses. Commit: `feat(spike): add the art spike's phone and replay pages and server (010)`.

---

## Phase 4: The index (after the maintainer's ruling)

**Implements:** FR-1, Story 1 | **Satisfies:** AC-1.3, AC-1.4, AC-1.5, AC-1.6, the decline row
**Files:** `spikes/card_scanner/phase3/script/index_build.rb`, `spec/fixtures/card_scanner/phase3_index_build.json`
**Interfaces:** Consumes: Phase 1's tools and the maintainer's ruling. Produces: `art-cache/index/art_index.bin` (`.gz`), `art_index_meta.json`, `phone_queries.json`, `agreement_small.json`, and the `phase3_index_build.json` fixture.

- [ ] **If the fetch is approved**, run `fetch_art.rb --size small --mode full --limit 30000` as a background task (at most 2 hours). Repeat until a run reports `fetched: 0`; the fetch is resumable. Keep each run's `fetch_small_full_*.json`. **If it is declined**, run `fetch_art.rb --size small --mode estimate`, which fetches the approved 500-artwork sample (seed 20261003).
- [ ] Run `bundle exec ruby spikes/card_scanner/phase2/script/build_index.rb --label "35 cards + 500 sampled"`. On the approved path the index labels itself "full", and the label is ignored. Expect `corpus artworks left out (AC-4.8): none`, or the left-out ones listed for the findings (AC-1.4).
- [ ] Run the agreement check (AC-1.6). Start spec 008's server for its `detect.html` as a background task: `CARD_SCANNER_WORK_DIR=… bundle exec puma -C spikes/card_scanner/phase2/puma.rb`. Then run `bundle exec ruby spikes/card_scanner/phase2/script/agreement.rb --size small --extra 100` and stop the server. Expect `"max":0`, with `n` at least 100 and `corpus_cards` at about 35. If the maximum is above 0, stop: the index isn't used until the cause is found (Error Scenarios).
- [ ] Run `bundle exec ruby spikes/card_scanner/phase3/script/gzip_index.rb`. Expect `43 queries`.
- [ ] Write `spikes/card_scanner/phase3/script/index_build.rb`:

```ruby
# The index build's figures as a fixture (spec 010 AC-1.5, AC-1.6): the fetch runs, the index metadata, sizes and agreement.
# Usage: CARD_SCANNER_WORK_DIR=… bundle exec ruby spikes/card_scanner/phase3/script/index_build.rb
require "bundler/setup"
require_relative "../lib/card_scanner_phase3"

work = CardScannerPhase2::WORK_DIR
fetches = work.glob("fetch_small_*.json").sort.map { JSON.parse(it.read).except("failed").merge("failed" => JSON.parse(it.read)["failed"].size) }
meta = JSON.parse(work.join("index/art_index_meta.json").read)
agreement = JSON.parse(work.join("agreement_small.json").read).except("results")
figures = { "index" => meta, "stored_bytes" => work.join("index/art_index.bin").size, "gzip_bytes" => work.join("index/art_index.bin.gz").size,
  "fetches" => fetches, "fetched_images" => fetches.sum { it["fetched"] }, "fetched_bytes" => fetches.sum { it["bytes"] },
  "fetch_seconds" => fetches.sum { it["seconds"] }.round(1), "agreement" => agreement }
CardScannerPhase3::FIXTURE_DIR.join("phase3_index_build.json").write(JSON.pretty_generate(figures))
puts JSON.pretty_generate(figures.except("fetches"))
```

- [ ] Run it. Commit `spec/fixtures/card_scanner/phase3_index_build.json` and the script: `test(findings): record the art index rebuild (010)`. Put the maintainer's ruling in the body: `Ruling: full fetch approved (or declined; subset of N) on <date> — maintainer`.

---

## Phase 5: The index on the iPhone (the maintainer)

**Implements:** FR-2, Story 2 | **Satisfies:** AC-2.1–AC-2.7
**Files:** `spikes/card_scanner/phase3/lib/card_scanner_phase3/phone_findings.rb`, `spikes/card_scanner/phase3/spec/card_scanner_phase3/phone_findings_spec.rb`, `spikes/card_scanner/phase3/script/{desktop_timing.rb,phone_findings.rb}`, `spec/fixtures/card_scanner/phase3_phone_timings.json`
**Interfaces:** Consumes: Phase 3's server and timing page, and Phase 4's gzipped index and queries. Produces: `CardScannerPhase3::PhoneFindings.new(results:, desktop:)` with `#to_markdown` and `#to_h`.

- [ ] Write the failing spec `spikes/card_scanner/phase3/spec/card_scanner_phase3/phone_findings_spec.rb`:

```ruby
require_relative "../phase3_helper"
require "card_scanner_phase3/phone_findings"

RSpec.describe CardScannerPhase3::PhoneFindings do
  let(:phone) do
    { "mode" => "cold", "userAgent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) … Brave", "downloadMs" => 900.0, "readyMs" => 120.0,
      "index" => { "count" => 50_000, "decodedBytes" => 7_200_000, "encodedBodySize" => 5_900_000, "contentLength" => 5_900_000 },
      "search" => { "n" => 2, "medianMs" => 150.0, "slowestMs" => 210.0, "tops" => [ { "file" => "A", "top" => { "id" => "x" } }, { "file" => "B", "top" => { "id" => "y" } } ] },
      "responsive" => { "searches" => 100, "maxGapMs" => 400.0, "completed" => true },
      "fingerprint" => { "n" => 12, "medianMs" => 90.0, "slowestMs" => 130.0, "maxBits" => 0 },
      "memory" => { "decodedBytes" => 7_200_000, "wordsBytes" => 6_400_000, "ids" => 50_000 } }
  end
  let(:desktop) { phone.merge("userAgent" => "Firefox", "search" => phone["search"].merge("tops" => [ { "file" => "A", "top" => { "id" => "x" } }, { "file" => "B", "top" => { "id" => "z" } } ])) }

  it "reports the phone's figures with slower-link arithmetic, and lists tops that differ from the desktop's (AC-2.3, AC-2.6)", :aggregate_failures do
    markdown = described_class.new(results: [ phone ], desktop:).to_markdown
    expect(markdown).to include("| cold | 5,900,000 | 7,200,000 | 900 | 120 | 150 | 210 | 90 | 130 | 0 | 400 | yes |")
    expect(markdown).to include("50 Mbit/s: 0.9 s", "10 Mbit/s: 4.7 s", "2 Mbit/s: 23.6 s", "arithmetic, not measured")
    expect(markdown).to include("Tops that differ from the desktop's: B (phone y, desktop z)")
    expect(markdown).to include("iPhone OS 18_7", "measured over the LAN")
  end
end
```

  (The slower-link figures: 5,900,000 bytes × 8 at 50, 10 and 2 Mbit/s gives 0.944, 4.72 and 23.6 s, rounded to one decimal.)
- [ ] Run `bundle exec rspec spikes/card_scanner/phase3/spec/card_scanner_phase3/phone_findings_spec.rb`. Expect it to FAIL.
- [ ] Write `spikes/card_scanner/phase3/lib/card_scanner_phase3/phone_findings.rb`:

```ruby
module CardScannerPhase3
  # The phone timings for research.md and the fixture (spec 010 Story 2): one row per load (cold, warm), slower-link
  # arithmetic for the cold download, and the queries whose top artwork differs from the desktop reference.
  class PhoneFindings
    LINKS = [ 50, 10, 2 ].freeze

    def initialize(results:, desktop:)
      @results, @desktop = results, desktop
    end

    def to_h = { "loads" => @results, "desktop" => @desktop, "differing_tops" => differing_tops }

    def to_markdown
      rows = @results.map do |r|
        "| #{r["mode"]} | #{num(r.dig("index", "encodedBodySize") || r.dig("index", "contentLength"))} | #{num(r.dig("index", "decodedBytes"))} | #{r["downloadMs"].round} | " \
          "#{r["readyMs"].round} | #{r.dig("search", "medianMs").round} | #{r.dig("search", "slowestMs").round} | #{r.dig("fingerprint", "medianMs").round} | " \
          "#{r.dig("fingerprint", "slowestMs").round} | #{r.dig("fingerprint", "maxBits")} | #{r.dig("responsive", "maxGapMs").round} | #{r.dig("responsive", "completed") ? "yes" : "no"} |"
      end
      cold = @results.find { it["mode"] == "cold" }
      bytes = cold && (cold.dig("index", "encodedBodySize") || cold.dig("index", "contentLength"))
      links = bytes ? LINKS.map { "#{it} Mbit/s: #{(bytes * 8.0 / (it * 1_000_000)).round(1)} s" }.join(", ") : "n/a"
      diffs = differing_tops.map { "#{it["file"]} (phone #{it["phone"]}, desktop #{it["desktop"]})" }
      [ "| Load | Encoded bytes | Decoded bytes | Download ms | Ready ms | Search median ms | Search slowest ms | Fingerprint median ms | " \
        "Fingerprint slowest ms | Fingerprint max bits | Longest gap ms (100 searches) | Completed |", "|---|---|---|---|---|---|---|---|---|---|---|---|", *rows, "",
        "Cold download at slower links (arithmetic, not measured): #{links}.", "",
        "Tops that differ from the desktop's: #{diffs.empty? ? "none" : diffs.join(", ")}.", "",
        "Device and browser: #{@results.map { it["userAgent"] }.uniq.join("; ")}; measured over the LAN." ].join("\n")
    end

    private
      def differing_tops
        reference = @desktop.dig("search", "tops").to_h { [ it["file"], it.dig("top", "id") ] }
        @results.flat_map { |r| r.dig("search", "tops") }.uniq { it["file"] }.filter_map do |t|
          { "file" => t["file"], "phone" => t.dig("top", "id"), "desktop" => reference[t["file"]] } if reference[t["file"]] != t.dig("top", "id")
        end
      end

      def num(value) = value.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
  end
end
```

- [ ] Run the spec. Expect 0 failures.
- [ ] Write `spikes/card_scanner/phase3/script/desktop_timing.rb`, the desktop reference (AC-2.3):

```ruby
# Runs the timing page in headless Firefox on this machine, as the desktop reference for the phone (spec 010 AC-2.3).
# Usage: (phase 3 server running) bundle exec ruby spikes/card_scanner/phase3/script/desktop_timing.rb
require "bundler/setup"
require "selenium-webdriver"

options = Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ], accept_insecure_certs: true)
driver = Selenium::WebDriver.for(:firefox, options:)
driver.manage.timeouts.script_timeout = 600
begin
  driver.navigate.to("https://127.0.0.1:#{ENV.fetch("SPIKE_PORT", 4300)}/phone/timing.html")
  Selenium::WebDriver::Wait.new(timeout: 60).until { driver.execute_script("return Boolean(window.__phase3Timing)") }
  result = driver.execute_async_script("const done = arguments[0]; window.__phase3Timing.run('cold').then((r) => done({ ok: r.search.n }), (e) => done({ failure: String(e) }))")
  abort result["failure"] if result["failure"]
  puts "desktop reference saved (#{result["ok"]} searches)"
ensure
  driver.quit
end
```

- [ ] Write `spikes/card_scanner/phase3/script/phone_findings.rb`:

```ruby
# Summarises the phone loads and the desktop reference (spec 010 Story 2). Usage: bundle exec ruby … phone_findings.rb [FIXTURES=1]
require "bundler/setup"
require_relative "../lib/card_scanner_phase3"
require_relative "../lib/card_scanner_phase3/phone_findings"

loads = CardScannerPhase3.runs_dir.join("phone").glob("*.json").sort.map { JSON.parse(it.read) }
desktop = loads.reverse.find { it["userAgent"].include?("Firefox") } or abort "run desktop_timing.rb first"
phone = loads.reject { it["userAgent"].include?("Firefox") }
findings = CardScannerPhase3::PhoneFindings.new(results: phone, desktop:)
puts findings.to_markdown
CardScannerPhase3::FIXTURE_DIR.join("phase3_phone_timings.json").write(JSON.pretty_generate(findings.to_h)) if ENV["FIXTURES"] == "1"
```

- [ ] Start the phase 3 server as a background task: `CARD_SCANNER_WORK_DIR=… bundle exec puma -C spikes/card_scanner/phase3/puma.rb`. Check that `curl -sk https://192.168.1.76:4300/phone/timing.html` returns the page, and that `curl -sk -o /dev/null -w "%{http_code}" https://192.168.1.76:4300/corpus/phase2-sitting/IMG_6806.jpeg` gives `403`. Then run `desktop_timing.rb`.
- [ ] **Checkpoint (the maintainer, about 5 minutes).** On the iPhone, open `https://192.168.1.76:4300/phone/timing.html`. Tap **Run cold**, wait for "results saved", then tap **Run warm**. If the page reloads or crashes, record how far it got (Error Scenarios).
- [ ] Stop the server. Run `FIXTURES=1 bundle exec ruby spikes/card_scanner/phase3/script/phone_findings.rb | tee tmp/spec010/phone.md`. If there are any CSP reports, record them from `runs/phase3/phone/csp-reports.jsonl`. Commit the fixture and the code: `test(findings): record the art index on the iPhone (010)`.

---

## Phase 6: The live captures (the maintainer)

**Implements:** FR-3, Story 3 | **Satisfies:** AC-3.4, AC-3.5
**Files:** none (data in `~/card-scanner-corpus/runs/spec010/sitting/`)
**Interfaces:** Consumes: Phase 2's frame keeping. Produces: 35 rows with `capture-001-frame.png` and the guide rect.

- [ ] Start the app's HTTPS dev server as a background task, per `bin/dev-certificate`, with:
  - `COLLECTOR_SCANNER_MANIFEST=$HOME/card-scanner-corpus/phase2-sitting/manifest.csv`
  - `COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/spec010/sitting`
  - `COLLECTOR_SCANNER_KEEP_FRAMES=1`

  Check `/up`. Find which account the phone is signed in as (device-sitting account check); no adds are needed, so any account works.
- [ ] **Checkpoint (the maintainer).** Open `/scanner/measurement`; the panel says "Keeping each live capture's full frame". Capture each of the 35 cards once, in manifest order, with no adds. Take a retake only when a capture is unusable.
- [ ] Afterwards, check that each row has a frame and a guide rect:

```bash
ruby -rjson -e 'rows = Dir[File.expand_path("~/card-scanner-corpus/runs/spec010/sitting/*/capture-001.json")].map { JSON.parse(File.read(it)) }
  puts "#{rows.size} captures; frames #{rows.count { it["frame_width"] }}; sizes #{rows.map { [it["frame_width"], it["frame_height"]] }.tally}; retakes #{Dir[File.expand_path("~/card-scanner-corpus/runs/spec010/sitting/*/capture-002.json")].size}"'
```

  Expect 35 captures, 35 frames and one frame size. Stop the server.

---

## Phase 7: The replays and the art findings

**Implements:** FR-4, Story 4, AC-5.4 | **Satisfies:** AC-4.1–AC-4.8
**Files:** `spikes/card_scanner/phase3/lib/card_scanner_phase3/{artwork_owners,art_findings}.rb`, `spikes/card_scanner/phase3/spec/card_scanner_phase3/{artwork_owners,art_findings}_spec.rb`, `spikes/card_scanner/phase3/script/{replay.rb,art_findings.rb}`, `spec/fixtures/card_scanner/phase3_art_results.json`
**Interfaces:** Consumes: Phase 3's replay page, Phase 4's index, Phase 6's frames, and spec 009's fixtures. Produces:
- `CardScannerPhase3::ArtworkOwners.read(path)`, which returns `{ id => { "names", "printings" } }`
- `CardScannerPhase3::ArtFindings.new(results:, truth:, entries:, owners:, text:, same_capture_text:)` with `#scored(path)`, `#rates(path)`, `#to_markdown` and `#to_h`

- [ ] Write the failing spec `spikes/card_scanner/phase3/spec/card_scanner_phase3/artwork_owners_spec.rb`:

```ruby
require_relative "../phase3_helper"
require "card_scanner_phase3/artwork_owners"
require "tmpdir"
require "zlib"

RSpec.describe CardScannerPhase3::ArtworkOwners do
  it "lists each front-face artwork's card names and printings among imported entries (AC-4.4, AC-4.5)", :aggregate_failures do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "bulk.jsonl.gz")
      cards = [
        { "id" => "p1", "name" => "Plains", "lang" => "en", "games" => [ "paper" ], "illustration_id" => "art-1" },
        { "id" => "p2", "name" => "Plains", "lang" => "en", "games" => [ "paper" ], "illustration_id" => "art-1" },
        { "id" => "p3", "name" => "Plains", "lang" => "ja", "games" => [ "paper" ], "illustration_id" => "art-1" },
        { "id" => "d1", "name" => "Front // Back", "lang" => "en", "games" => [ "paper" ], "card_faces" => [ { "illustration_id" => "art-2" }, { "illustration_id" => "art-3" } ] }
      ]
      Zlib::GzipWriter.open(path) { |gz| cards.each { gz.puts(it.to_json) } }
      owners = described_class.read(path)
      expect(owners["art-1"]).to eq("names" => [ "Plains" ], "printings" => %w[p1 p2])
      expect(owners["art-2"]).to eq("names" => [ "Front // Back" ], "printings" => %w[d1])
      expect(owners).not_to have_key("art-3")
    end
  end
end
```

- [ ] Write the failing spec `spikes/card_scanner/phase3/spec/card_scanner_phase3/art_findings_spec.rb`:

```ruby
require_relative "../phase3_helper"
require "card_scanner_phase3/art_findings"

RSpec.describe CardScannerPhase3::ArtFindings do
  let(:truth) do
    { "IMG_6808.jpeg" => { "file" => "IMG_6808.jpeg", "name" => "Plains", "external_key" => "m10-233", "foil" => false, "set_code" => "m10", "collector_number" => "233" },
      "IMG_6821.jpeg" => { "file" => "IMG_6821.jpeg", "name" => "Pegasus Guardian", "external_key" => "clb-36", "foil" => true, "set_code" => "clb", "collector_number" => "36" } }
  end
  let(:entries) { { "m10-233" => "art-plains", "clb-36" => "art-pegasus" } }
  let(:owners) do
    { "art-plains" => { "names" => [ "Plains" ], "printings" => [ "m10-233" ] }, "art-other-plains" => { "names" => [ "Plains" ], "printings" => [ "woe-262" ] },
      "art-pegasus" => { "names" => [ "Pegasus Guardian" ], "printings" => [ "clb-36", "plst-clb-36" ] } }
  end
  let(:text) do
    { "IMG_6808.jpeg" => { "top3" => [ "Plains" ], "lookup" => { "status" => "none", "external_keys" => [] } },
      "IMG_6821.jpeg" => { "top3" => [ "Pegasus Guardian" ], "lookup" => { "status" => "one", "external_keys" => [ "clb-36" ] } } }
  end
  let(:results) do
    { "guide" => { "IMG_6808.jpeg" => { "top" => [ { "id" => "art-other-plains", "distance" => 210 }, { "id" => "art-plains", "distance" => 230 } ], "rightDistance" => 230 },
                   "IMG_6821.jpeg" => { "top" => [ { "id" => "art-pegasus", "distance" => 150 } ], "rightDistance" => 150 } },
      "detected" => { "IMG_6808.jpeg" => { "found" => false, "top" => [], "rightDistance" => nil },
                      "IMG_6821.jpeg" => { "found" => true, "top" => [ { "id" => "art-pegasus", "distance" => 120 } ], "rightDistance" => 120 } } }
  end
  let(:findings) { described_class.new(results:, truth:, entries:, owners:, text:) }

  it "scores right artwork first, right card first by art and the top 3 per path (AC-4.4)", :aggregate_failures do
    plains, pegasus = findings.scored("guide").values_at(0, 1)
    expect(plains).to include("art_first" => false, "card_first" => true, "art_top3" => true, "right_distance" => 230, "nearest_wrong" => 210)
    expect(pegasus).to include("art_first" => true, "card_first" => true, "unique_printing" => false)
    expect(findings.rates("guide")["all"]).to include("art_first" => "1/2 (50.0%)", "card_first" => "2/2 (100.0%)")
  end

  it "counts a missing outline as a miss on the detected path (AC-4.2)" do
    expect(findings.rates("detected")["all"]["art_first"]).to eq("1/2 (50.0%)")
  end

  it "compares with the text: text or art, and the printings the text missed (AC-4.5)", :aggregate_failures do
    expect(findings.comparison("guide")).to include("text_top3" => "2/2 (100.0%)", "text_or_art" => "2/2 (100.0%)", "printing_missed" => 1)
    expect(findings.comparison("guide")["art_names_printing"]).to eq(0)
  end

  it "names spec 009's misses with their distances and whether the artwork is unique to the printing (AC-4.6)" do
    expect(findings.to_markdown).to include("| IMG_6808.jpeg | Plains (M10 · 233) | guide: card first, right 230, nearest wrong 210, unique to its printing | detected: no outline |")
  end
end
```

  (On the guide path, Plains' top artwork is another Plains printing's, so the card is right but the artwork isn't. Pegasus's artwork is shared with its PLST reprint, so art can't name the printing. Only Plains is a printing the text missed.)
- [ ] Run `bundle exec rspec spikes/card_scanner/phase3/spec`. Expect the two new specs to FAIL.
- [ ] Write `spikes/card_scanner/phase3/lib/card_scanner_phase3/artwork_owners.rb`:

```ruby
require "zlib"
require_relative "../../../phase2/lib/card_scanner_phase2/bulk_artworks"

module CardScannerPhase3
  # For each front-face artwork among the entries the catalog imports (spec 008 AC-4.1's filter): the card names and the
  # printings that carry it (spec 010 AC-4.4, AC-4.5).
  module ArtworkOwners
    module_function

    def read(path)
      owners = {}
      Zlib::GzipReader.open(path.to_s) do |gz|
        gz.each_line do |line|
          next if line.strip.empty?

          card = JSON.parse(line)
          next unless CardScannerPhase2::BulkArtworks.imported?(card)

          front = Array(card["card_faces"]).first || card
          next unless (id = front["illustration_id"] || card["illustration_id"])

          owner = owners[id] ||= { "names" => [], "printings" => [] }
          owner["names"] |= [ card["name"] ]
          owner["printings"] << card["id"]
        end
      end
      owners
    end
  end
end
```

- [ ] Write `spikes/card_scanner/phase3/lib/card_scanner_phase3/art_findings.rb`:

```ruby
module CardScannerPhase3
  # Scores the art replay (spec 010 AC-4.4 to AC-4.7) against ground truth and spec 009's text results. results: { path =>
  # { file => replay record } }; truth: { file => ground-truth record }; entries: { printing id => front artwork id }; owners:
  # ArtworkOwners; text and same_capture_text: { file => { "top3" => names, "lookup" => {…} } }.
  class ArtFindings
    PATHS = { "guide" => "Live, guide box", "detected" => "Live, detected (shipped detector incl. 8a6c712)", "photo" => "Unguided photo, detected" }.freeze

    def initialize(results:, truth:, entries:, owners:, text:, same_capture_text: {})
      @results, @truth, @entries, @owners, @text, @same = results, truth, entries, owners, text, same_capture_text
    end

    def paths = PATHS.keys & @results.keys

    def scored(path)
      @truth.values.sort_by { it["file"] }.map do |truth|
        record = @results.dig(path, truth["file"]) || { "top" => [] }
        right = @entries[truth["external_key"]]
        top = Array(record["top"])
        first = top.first&.fetch("id")
        { "file" => truth["file"], "name" => truth["name"], "foil" => truth["foil"], "right" => right, "found" => record.fetch("found", true),
          "art_first" => !right.nil? && first == right, "card_first" => !first.nil? && Array(@owners.dig(first, "names")).include?(truth["name"]),
          "art_top3" => !right.nil? && top.first(3).any? { it["id"] == right }, "right_distance" => record["rightDistance"],
          "nearest_wrong" => top.find { it["id"] != right }&.fetch("distance"), "unique_printing" => Array(@owners.dig(right, "printings")).size == 1,
          "first" => first, "missing_artwork" => right.nil? }
      end
    end

    def rates(path)
      groups = { "all" => scored(path), "foil" => scored(path).select { it["foil"] }, "non-foil" => scored(path).reject { it["foil"] } }
      groups.transform_values { |rows| %w[art_first card_first art_top3].to_h { |key| [ key, rate(rows) { it[key] } ] } }
    end

    def comparison(path, text = @text)
      rows = scored(path)
      text_top3 = ->(r) { Array(text.dig(r["file"], "top3")).first(3).include?(r["name"]) }
      missed = rows.select { |r| printing_missed?(r["file"], text) }
      { "text_top3" => rate(rows, &text_top3), "text_or_art" => rate(rows) { text_top3.call(it) || it["card_first"] }, "printing_missed" => missed.size,
        "art_names_printing" => missed.count { it["art_first"] && it["unique_printing"] } }
    end

    def to_h = { "paths" => paths.to_h { [ it, { "rates" => rates(it), "comparison" => comparison(it), "records" => scored(it) } ] } }

    def to_markdown
      sections = paths.map do |path|
        r, c = rates(path), comparison(path)
        same = @same.empty? ? "" : "\n\nSame-capture text: #{comparison(path, @same).to_json}"
        scored_rows = scored(path)
        right = scored_rows.filter_map { it["right_distance"] }
        wrong = scored_rows.filter_map { it["nearest_wrong"] }
        misses = scored_rows.reject { it["art_first"] }.map { "| #{it["file"]} | #{it["name"]} | #{it["first"] || "—"} | #{it["right_distance"] || "—"} | #{it["nearest_wrong"] || "—"} | #{it["found"] ? "" : "no outline"} |" }
        [ "### #{PATHS[path]}", "| Group | Right artwork first | Right card first by art | Right artwork in top 3 |", "|---|---|---|---|",
          *r.map { |group, v| "| #{group} | #{v["art_first"]} | #{v["card_first"]} | #{v["art_top3"]} |" }, "",
          "Text top 3 #{c["text_top3"]}; text or art #{c["text_or_art"]}; printings the text missed #{c["printing_missed"]}, of which art names the printing #{c["art_names_printing"]}.#{same}", "",
          "Median distance: right #{median(right)}, nearest wrong #{median(wrong)} (n=#{right.size}, #{wrong.size}).", "",
          "| File | Card | First artwork | Right distance | Nearest wrong | Note |", "|---|---|---|---|---|---|", *misses ].join("\n")
      end
      named = NAMED.filter_map do |file|
        truth = @truth[file] or next
        cells = paths.map { |path| "#{path}: #{outcome(scored(path).find { it["file"] == file })}" }
        "| #{file} | #{truth["name"]} (#{truth["set_code"].to_s.upcase} · #{truth["collector_number"]}) | #{cells.join(" | ")} |"
      end
      [ *sections, "### Spec 009's misses and corrections", "| File | Card | #{paths.join(" | ")} |", "|---|---|#{"---|" * paths.size}", *named ].join("\n\n")
    end

    private
      def printing_missed?(file, text)
        lookup = text.dig(file, "lookup") || {}
        !(lookup["status"] == "one" && lookup["external_keys"] == [ @truth.dig(file, "external_key") ])
      end

      def outcome(row)
        return "no outline" unless row["found"]

        verdict = if row["art_first"] then "artwork first" elsif row["card_first"] then "card first" else "miss" end
        "#{verdict}, right #{row["right_distance"] || "—"}, nearest wrong #{row["nearest_wrong"] || "—"}#{row["unique_printing"] ? ", unique to its printing" : ""}"
      end

      def rate(rows, &) = "#{rows.count(&)}/#{rows.size} (#{rows.empty? ? "n/a" : format("%.1f%%", 100.0 * rows.count(&) / rows.size)})"
      def median(values) = CardScannerPhase2.median(values) || "n/a"
  end
end
```

  (In the AC-4.6 example, the detected path for IMG_6808 has no outline, so its cell reads `detected: no outline`. The guide path's cell reads `guide: card first, right 230, nearest wrong 210, unique to its printing`: Plains' right artwork belongs to one printing (M10 233) in the test's owners. The paths come in the order guide, detected.)
- [ ] Run `bundle exec rspec spikes/card_scanner/phase3/spec`. Expect 0 failures; adjust only the expected strings if a rounding detail differs, and record it.
- [ ] Write `spikes/card_scanner/phase3/script/replay.rb`:

```ruby
# Replays the 35 cards through the three paths (spec 010 Story 4) in headless Firefox against the phase 3 server's replay page,
# writing runs/phase3/<label>/results.json. Usage: (server running) bundle exec ruby … replay.rb <label>
require "bundler/setup"
require "selenium-webdriver"
require "time"
require_relative "../lib/card_scanner_phase3"
require_relative "../../phase2/lib/card_scanner_phase2/bulk_artworks"

label = ARGV.fetch(0) { abort "usage: replay.rb <label>" }
out = CardScannerPhase3.runs_dir.join(label)
abort "#{out} exists; pick a new label" if out.exist?
data = CardScannerPhase2::BulkArtworks.load
truth = JSON.parse(CardScannerPhase3.sitting_dir.join("ground_truth.json").read).fetch("photos")
live = CardScannerPhase3.corpus_dir.join("runs/spec010/sitting")
jobs = truth.flat_map do |t|
  right = data["entries"][t["external_key"]]
  capture = JSON.parse(live.join(t["file"], "capture-001.json").read) if live.join(t["file"], "capture-001.json").file?
  frame = "runs/spec010/sitting/#{t["file"]}/capture-001-frame.png"
  [ (capture && { "file" => t["file"], "path" => frame, "kind" => "guide", "guide" => capture["guide"], "right" => right }),
    (capture && { "file" => t["file"], "path" => frame, "kind" => "detected", "right" => right }),
    { "file" => t["file"], "path" => "phase2-sitting/#{t["file"]}", "kind" => "photo", "right" => right } ].compact
end
RUN_JS = "const [ job, done ] = arguments; window.__phase3.run(job).then((r) => done({ r }), (e) => done({ failure: `${e}` }))"
driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
driver.manage.timeouts.script_timeout = 300
results = Hash.new { |h, k| h[k] = {} }
begin
  driver.navigate.to("http://127.0.0.1:#{ENV.fetch("SPIKE_LOCAL_PORT", 4301)}/replay.html")
  Selenium::WebDriver::Wait.new(timeout: 300).until { driver.execute_script("return Boolean(window.__phase3 && window.__phase3.ready)") }
  jobs.each do |job|
    answer = driver.execute_async_script(RUN_JS, job.except("file"))
    abort "#{job["file"]} #{job["kind"]}: #{answer["failure"]}" if answer["failure"]
    results[job["kind"]][job["file"]] = answer["r"]
    puts format("%-14s %-8s %s", job["file"], job["kind"], answer.dig("r", "top", 0, "id").to_s[0, 8])
  end
ensure
  driver.quit
end
out.mkpath
meta = JSON.parse(CardScannerPhase2::WORK_DIR.join("index/art_index_meta.json").read)
head = IO.popen([ "git", "-C", CardScannerPhase3::REPO.to_s, "rev-parse", "HEAD" ], &:read).strip
out.join("results.json").write(JSON.pretty_generate("label" => label, "at" => Time.now.utc.iso8601, "code_commit" => head, "index" => meta, "results" => results))
puts "#{jobs.size} jobs -> #{out.join("results.json")}"
```

- [ ] Write `spikes/card_scanner/phase3/script/art_findings.rb`, which runs under Rails for the same-capture text rescore:

```ruby
# Scores a replay (spec 010 Story 4) and, with FIXTURES=1, writes phase3_art_results.json. Also compares two replays for
# determinism (AC-4.8). Usage: bin/rails runner spikes/card_scanner/phase3/script/art_findings.rb <label> [<second label>]
require_relative "../lib/card_scanner_phase3"
require_relative "../lib/card_scanner_phase3/artwork_owners"
require_relative "../lib/card_scanner_phase3/art_findings"
require_relative "../../phase2/lib/card_scanner_phase2/bulk_artworks"

label, second = ARGV
replay = JSON.parse(CardScannerPhase3.runs_dir.join(label, "results.json").read)
data = CardScannerPhase2::BulkArtworks.load
owners = CardScannerPhase3::ArtworkOwners.read(CardScannerPhase2::BulkArtworks.latest_bulk_file)
truth = JSON.parse(CardScannerPhase3.sitting_dir.join("ground_truth.json").read).fetch("photos").to_h { [ it["file"], it ] }
fixtures = Rails.root.join("spec/fixtures/card_scanner")
lookups = JSON.parse(fixtures.join("phase2_sitting_ocr_results.json").read).fetch("results").to_h { [ it["file"], it["lookup"] ] }
tops = JSON.parse(fixtures.join("phase2_sitting_name_matches.json").read).fetch("matches").to_h { [ it["file"], it["final_candidates"] ] }
text = truth.keys.to_h { [ it, { "top3" => tops[it], "lookup" => lookups[it] } ] }
run = Scanner::MeasurementRun.new(manifest: CardScannerPhase3.sitting_dir.join("manifest.csv"), dir: CardScannerPhase3.corpus_dir.join("runs/spec010/sitting"))
same = Collector::ScannerFindings.rescore(truth, run.measured_captures).to_h { [ it["file"], { "top3" => it["final_candidates"], "lookup" => it["lookup"] } ] }
findings = CardScannerPhase3::ArtFindings.new(results: replay["results"], truth:, entries: data["entries"], owners:, text:, same_capture_text: same)
puts "Index: #{replay["index"].slice("count", "label", "bulk_version", "settings_commit")}", "", findings.to_markdown
if second
  other = JSON.parse(CardScannerPhase3.runs_dir.join(second, "results.json").read)["results"]
  diffs = replay["results"].flat_map { |path, files| files.filter_map { |file, r| "#{path} #{file}" if other.dig(path, file, "hashes") != r["hashes"] } }
  puts "", "Determinism (#{label} vs #{second}): #{diffs.empty? ? "identical fingerprints for every job" : diffs.join(", ")}"
end
if ENV["FIXTURES"] == "1"
  records = replay["results"].transform_values { |files| files.transform_values { it.slice("hashes", "top", "rightDistance", "crop", "found", "corners") } }
  fixtures.join("phase3_art_results.json").write(JSON.pretty_generate("format_version" => 1, "spec" => "010", "index" => replay["index"], "code_commit" => replay["code_commit"],
    "replay" => records, "scored" => findings.to_h))
end
```

- [ ] Run the replays:
  1. Start the phase 3 server as a background task, then run `replay.rb replay-1` and `replay.rb replay-2`.
  2. Run `bin/rails runner spikes/card_scanner/phase3/script/art_findings.rb replay-1 replay-2 | tee tmp/spec010/art.md`. Expect "identical fingerprints for every job" (AC-4.8).
  3. Run it again with `FIXTURES=1` and `replay-1` alone, then stop the server.
  4. Check that `git status --porcelain spec/fixtures/card_scanner` shows only `phase3_art_results.json`.
- [ ] Commit the scripts, the lib, the specs and the fixture: `feat(spike): replay and score art on the 35 cards' live frames and photos (010)`.

---

## Phase 8: Findings, ADR updates, docs and memory

**Implements:** FR-5, Story 5 | **Satisfies:** AC-5.1, AC-5.2, AC-5.3, AC-5.4 (all fixtures committed), AC-2.7, AC-3.5, AC-4.7 (likely causes)
**Files:** `docs/specs/010-card-scanner-art-spike/research.md`, `docs/adr/0006-art-fingerprint-and-index.md`, `docs/adr/0007-art-search-in-the-browser.md`, `CLAUDE.md`, `.claude/memory/card-scanner-direction.md`

- [ ] **Write `research.md`.** Every number carries its sample size, desktop and phone figures are labelled, and any subset index is labelled with its size. There is no pass threshold. The sections:
  1. **Environment:** the bulk file, the settings commit, the index label, the devices and browsers.
  2. **The index rebuild:** the estimate, the ruling, the fetch, the build, and agreement from `phase3_index_build.json` (AC-1.1–AC-1.6).
  3. **The index on the iPhone,** from `tmp/spec010/phone.md` (AC-2.1–AC-2.7).
  4. **The live session:** frames, size, retakes and device (AC-3.5).
  5. **Art on the three paths,** from `tmp/spec010/art.md` (AC-4.1–AC-4.5). The likely cause of each miss is filled in by viewing the frame or photo: framing, glare or foil, a shared artwork, or a missing image (AC-4.7).
  6. **Spec 009's misses and corrections** (AC-4.6).
  7. **Determinism** (AC-4.8).
  8. **Recommendations for spec 011:** which paths get art, where the search runs, art evidence in the ranking grouped by card, and the opt-in fetch's cost to an instance (AC-5.2).
- [ ] **ADRs 0006 and 0007:** add the phone and live-frame figures to Consequences, and correct their references to spec 009 (spec 010 measures; spec 011 builds and decides). Both stay Proposed (AC-5.3).
- [ ] **`CLAUDE.md`:** add one line to the Card scanner fact: the art spike (`spikes/card_scanner/phase3/`) and frame keeping (`COLLECTOR_SCANNER_KEEP_FRAMES=1`). Update **`card-scanner-direction.md`** with the spike's results and the next step (the maintainer's ruling, then spec 011).
- [ ] Commit: `docs(010): record the art spike's findings and update ADRs 0006 and 0007`.

---

## Phase 9: Integration Verification

**Implements:** All FRs, NFRs | **Satisfies:** AC-5.5, NFR Security and Reliability

- [ ] Run `bin/ci`. Expect every step to pass.
- [ ] Run `bundle exec rspec spikes/card_scanner/phase3/spec spikes/card_scanner/phase2/spec`. Expect 0 failures.
- [ ] Run `git diff --stat main -- app config` and check that it shows only the Phase 2 files (AC-5.5). Run `git diff main -- spikes/card_scanner/phase2` and check that it shows only the `WORK_DIR`, bulk-file and `truth_corpora` settings, the three scripts' `truth_corpora` calls and `search.js`'s `parseIndex` (FR-1).
- [ ] Run `git ls-files spec/fixtures/card_scanner | grep phase3_`. Expect exactly the four `phase3_` JSON fixtures, and no image anywhere in the diff: `git diff --stat main | grep -E '\.(png|jpe?g|bin|gz)'` prints nothing.
- [ ] Use `sdd-superpowers:sdd-review` (Mode B), as a read-only Fable subagent, before merging.

---

## Quickstart Validation

1. `export CARD_SCANNER_WORK_DIR=$HOME/card-scanner-corpus/art-cache CARD_SCANNER_TRUTH_CORPORA=sitting`
2. `bundle exec puma -C spikes/card_scanner/phase3/puma.rb`, then open `https://<dev-ip>:4300/phone/timing.html` on a phone and tap **Run cold**. The page reports the download, ready, search and fingerprint times and saves them.
3. `bundle exec ruby spikes/card_scanner/phase3/script/replay.rb check` (with the server running), then `bin/rails runner spikes/card_scanner/phase3/script/art_findings.rb check`. These print the three paths' rates on the 35 cards.

---

## Coverage map (self-review)

| AC / FR | Phase | Test or record |
|---|---|---|
| AC-1.1, AC-1.2 | 1 | estimate_spec, `phase3_fetch_estimate.json` |
| AC-1.3, AC-1.4 | 1, 4 | `ArtFetcher` (spec 008's specs), fetch logs |
| AC-1.5, AC-1.6 | 4 | `phase3_index_build.json`, `agreement.rb` |
| AC-2.1–AC-2.7 | 3, 5 | server_spec, phone_findings_spec, `phase3_phone_timings.json` |
| AC-3.1–AC-3.3 | 2 | measurement_run_spec, measurements_spec, scanner_measurement_spec |
| AC-3.4, AC-3.5 | 6, 8 | the capture check, research §4 |
| AC-4.1–AC-4.3, AC-4.8 | 3, 7 | replay page, replay.rb, determinism line |
| AC-4.4–AC-4.7 | 7, 8 | art_findings_spec, artwork_owners_spec, research §5–§6 |
| AC-5.1–AC-5.4 | 8 | research.md, ADR edits, fixtures |
| AC-5.5, FR-1–FR-5 | 2, 9 | diff checks, scanner specs |
| Decline row | 1, 4 | the checkpoint and the subset label |
