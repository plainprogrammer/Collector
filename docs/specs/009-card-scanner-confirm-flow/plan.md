# Implementation Plan: Card Scanner — Confirm and Add, and Detection on the Photo Path

**Spec:** docs/specs/009-card-scanner-confirm-flow/spec.md (v1.1.2, Approved, reviewed twice)
**Decisions:** [ADR 0001](../../adr/0001-browser-ocr-engine-and-asset-hosting.md), [0002](../../adr/0002-camera-path-testing.md), [0003](../../adr/0003-card-name-index.md), [0004](../../adr/0004-card-recognition-in-the-browser.md), [0005](../../adr/0005-hand-written-card-detector-for-the-photo-path.md) (all Accepted). ADRs 0006 and 0007 stay Proposed (art matching is the next spec).
**Created:** 2026-10-03
**Revised:** 2026-10-03, after a read-only plan review (Fable, NEEDS REVISION).
- **Blocking fixes:**
  - `pick_photo` installs the request recorder.
  - The release date follows the app's locale ("17 July 2009").
  - The examples meet the project's RuboCop limits: `let` names without trailing digits, `:aggregate_failures`, helper methods for long JavaScript, fewer memoised helpers, and timings reported through RSpec's reporter.
- **Spec gaps closed:** the failed-add and Other-printings-failure Error Scenarios are handled in `scanner_reading_controller.js` and tested.
- **Other fixes:**
  - Add buttons stay locked while a newer add is in flight (`success === false`).
  - The foil hint is in the visible label only, not the accessible name.
  - `LONG_TOKEN_SHARE` gets a sweep and a stop rule.
  - The Phase 10 fixture check uses `git status`.
  - Opening Other printings is announced.
  - The identity lookup is scoped to the collectible type.
  - The Details link isn't prefetched.
  - The README note keeps `readme_spec`'s phrases.
- **Still needs a run:** a review that runs the code hasn't been done.

**Approved:** 2026-10-03 (maintainer). Data model: [data-model.md](data-model.md). Contracts: [contracts/api.md](contracts/api.md).

## Context

Spec 007 shipped a scanner that reads a card and ranks printings but can't add anything. Spec 008's spike showed that a 5 KB hand-written detector triples the photo path's held-out top 3. The maintainer ruled on 2026-10-03 that spec 009 ships three things:
- the confirm flow
- the detector on the photo-picker path
- the ranking and reading fixes for spec 007's weak cases

Art matching gets its own spec afterwards. This plan builds those three things into the app, then measures the flow in a live sitting of 35 unseen cards on the maintainer's iPhone.

**Facts established during planning (2026-10-03):**

- **Scanner code today.**
  - `MTG::Reading` (`app/models/mtg/reading.rb`) is an ActiveModel value object. It has `Candidate = Data.define(:entry, :source)`, `candidates` (a collector-line match first, then one printing per name candidate, at most 3), `name_candidates` (`Catalog::NameIndex#search` → `Candidate(:identity_id, :name, :score)`, where the score is Jaro-Winkler from 0 to 1) and `collector_line` (`MTG::CollectorLine.parse`, `Result(:set_code, :number, :language, :foil, :format)`, where `foil` is true when the set line's separator is in `FOIL_MARKERS = %w[★ *]`).
  - `Scanner::ReadingsController#create` stores nothing and answers `turbo_stream.update("scanner_result", partial: "scanners/result")`.
  - `card_reader_controller.js` cuts strips with `cropStrips(image, card)`, reads them with `readStrips`, POSTs `reading[name_text]` and `reading[collector_text]` with `fetch`, then renders the stream. It dispatches `card-reader:read` (`{ nameText, collectorText, ms, strips }`), which measurement mode stores.
  - `pick()` uses `createImageBitmap(file)` and `guideInFrame(image.width, image.height, STAGE_ASPECT, 1)`.
- **Adding today.**
  - `Lot.add!(account:, entry:, quantity: 1, finish: nil, condition: nil, price_paid_cents: nil)` merges by `lot_key = "finish|condition|price"` and raises `ActiveRecord::RecordInvalid` past 9,999. It validates the finish against `Catalog.collecting_for(type).finishes_for(entry)`, which `MTG::Collecting` orders nonfoil, foil, etched; `finish_label` is `humanize`.
  - `Lot#revise!` merges into another lot of the same identity, and then destroys the edited lot.
  - `LotsController#destroy` calls `BulkRemoval.supersede!(Current.session)`.
  - `Catalog::QuickAddsController::FULL_LOT` is "You already have the most copies one lot can hold (9,999).".
  - `CardContext#lot_return_path` follows a local `return_to`. Edit copy's Save, Cancel and Back all use it.
- **Page conventions.**
  - The layout renders the one `#status` live region, and quick add updates it with `turbo_stream.update("status", partial: "shared/status_message", locals: { message:, alert: })`.
  - The scanner page sends `turbo-visit-control: reload`. A Turbo visit to it therefore fetches it, then loads it again, so a flash set by the redirect is used up before the page the collector sees. A redirect whose flash must be shown on the scanner therefore uses a non-Turbo form.
  - A Turbo Frame response is rendered without that meta (turbo-rails' frame layout).
  - `.c-pagehead__actions` is hidden below 640 px; the tab bar covers phones and allows up to 5 tabs (3 today).
  - Collection partials with strict locals take collection counters without declaring them (`scanners/_candidate` does it today).
- **Testing JS.** There is no Node. JS modules are tested in system specs: a `type="module"` script carrying the page's CSP nonce imports `scanner/*` (`ScannerHelpers::CARD_JS`), and `getUserMedia` is replaced by a synthetic 63:88 card's `captureStream` (ADR 0002). `scanner_sent` records the field names of every `fetch` with a `FormData` body.
- **Findings tooling.**
  - `Collector::ScannerFindings.rescore(truth, results)` runs `MTG::Reading` against the development catalog and returns `final_candidates` and `name_candidates` (card names).
  - `Report#write_fixtures!` writes `format_version` 2.
  - `Scanner::MeasurementRun` stores `<dir>/<file>/capture-NNN.json` (`file, kind, name_text, collector_text, ms, user_agent, captured_at`) and strip PNGs. It reads photos from the manifest's directory, with file names matching `/\A[\w-][\w.-]*\z/`.
  - `script/scanner/photo_run.rb` feeds a manifest's photos through the real picker. `script/scanner/replay.rb <label>` re-reads stored strips.
  - The measurement manifest and run directory come from `COLLECTOR_SCANNER_MANIFEST` and `COLLECTOR_SCANNER_RUN_DIR`, read when the server boots.
- **Stored runs** (`~/card-scanner-corpus/`):
  - `runs/phase1-live/` holds the new corpus's live captures with their strips (the strips are stored after spec 007's processing, so only steps added after that processing can be replayed on them exactly).
  - `phase1-live/ground_truth.json` (49 cards) and `tuning/ground_truth.json` (12) exist but aren't committed. `spec/fixtures/card_scanner/ground_truth.json` (Phase 0's 50) is committed.
  - Tuning round 4's files are `T001`–`T012`.
  - `spec/fixtures/card_scanner/phase2_split.json` holds the halves: phase0 26 development and 24 held out; new 26 and 23.
- **The spike detector** (`spikes/card_scanner/phase2/public/hand_detector.js`, `warp.js`, `canvas.js`) is unchanged between `59a4474` and the freeze `39cdc6e`, with identical `hand` and `warp` settings.
  - Its recorded runs at those settings, `runs/phase2/dev-hand-3/<stem>/detect.json` (52) and `runs/phase2/held-hand/<stem>/detect.json` (47, `code_commit` `39cdc6e`), hold `corners` in source pixels (or `null`), plus `sourceWidth`, `path` (relative to the corpus directory) and `found`.
  - So these records are the spike detector re-run at `39cdc6e` that AC-7.3 names, and the parity check compares against them without running the spike again.
- **IMG_6720** (Phase 1 photo replay): `name_text` is `"Lp cog Sw pan soon pa B= SR be prea ZN oo Ld\r\nFanged Flames 1\r\n~  _______ \\3"`. Spec 007's cleaning picks the first line (17 characters once short tokens drop out), so the name candidates are Monsoon, Harpoon Sniper and Horned Loch-Whale.
- **The worktree.**
  - This worktree's development catalog is empty and it has no users.
  - `bin/rails db:migrate` also rewrites `db/{cable,cache,queue}_schema.rb`; restore those files with `git checkout` afterwards.
  - Ruby 4.0.7 and Rails 8.1. SQLite foreign keys are enforced, so `on_delete: :nullify` and `:cascade` work.

**Plan decisions (not spelled out in the spec):**

- **Reading key.** The page mints the key with `crypto.getRandomValues` (16 bytes as 32 hex characters), because `crypto.randomUUID` is missing from the insecure contexts the photo path serves. The key goes with the readings request, so the server writes it into the reading's add forms (FR-5 lists the key among what may be sent), and it is checked against `/\A[0-9a-f]{32}\z/` everywhere.
- **Hotwire shape.**
  - **Add and Undo** are `button_to` forms answered with Turbo Streams (`#scanner_result`, `#scanner_sitting`, `#status`), so the camera keeps running.
  - **Other printings** is a Turbo Frame (`scanner_printings`) under the candidates.
  - **Done** goes to a confirm page (the design system's `ConfirmPage`) whose form is non-Turbo, so the one-time summary flash survives the scanner's reload meta.
- **Data.** `scanner_sittings` (unique `account_id`) and `scanner_sitting_entries`. An entry's `lot_id` is a foreign key with `on_delete: :nullify`, so an entry knows its lot was removed or merged away (AC-3.6) without a callback. Ending a sitting deletes it, and its entries cascade.
- **Ranking rule (AC-5.5).** One sort key per candidate: `[strong top name ? 0 : 1, collector-line evidence ? 0 : 1, name rank]`. "Strong" means the top name candidate's score is at or above `MTG::Reading::STRONG_NAME_SCORE`. The threshold comes from `bin/rails scanner:strong_sweep` over the AC-5.4 fixtures: the threshold with the most right-first readings, no lost first place, and the three misreads fixed; ties go to the higher threshold. If none qualifies, execution stops for the maintainer.
- **Query cleaning (AC-6.1).** A line is a query only if at least half of its characters sit in tokens of 3 or more characters (`LONG_TOKEN_SHARE = 0.5`). Spec 007's rule is the fallback.
- **Reading refinements** are steps after spec 007's strip processing (`refineStrip`), so they replay exactly on stored strips (`replay.rb` with `REFINE=1`). The steps are: invert the name strip when it is mostly dark, Otsu-binarize the collector strip, and enlarge it further. The detected photo path gets its own strip layout (`DETECTED_STRIPS`). The detector gains outline completion (`completeTolerance`). Every refinement starts off and is switched on only if the tuning run shows it helps.
- **Detected-photo tuning** runs on derived folders: `~/card-scanner-corpus/derived/{development,held_out}/` holds symlinks to both corpora's photos, a combined manifest and combined ground truth. Each half then needs one server configuration. Held-out photos run only after the freeze commit.
- **The live sitting** runs in measurement mode. It records `reading_key`, outline and timings in each capture, and add, Undo and details events with the candidate's rank (sent only by the measurement controller, AC-9.2). A sitting report joins the captures, events and sitting entries.
- **Times in the sitting list** read "Added 3 minutes ago" (`time_tag`): the app has no time zone per user. **Accessible names** use `SET · number`, as `lot_label` and quick add do: "Add Tome Shredder STX · 117 Foil".
- **Median.** The new findings code uses a conventional median (the mean of the middle two for even n) and says so. The shipped `ScannerFindings.percentile` takes the upper middle, so only the medians from earlier reports use it.

## Global Constraints

- **Privacy:** in normal use the scanner sends the app only recognised text, the reading key, and the add, Undo and Other printings requests (printing ids and finishes). It never sends a frame, strip, photo, straightened image or outline (FR-5, FR-4). Measurement mode stays development-only, and its files stay outside the repository and `storage/`.
- **Scanner page:** the scanner's Content Security Policy is unchanged (`ScannerPage`), and the detector is first-party with no third-party library (AC-7.5, FR-4).
- **Tenancy:** every sitting read and write goes through `Current.account`. Another account's entry answers 404, with a request spec (FR-2, multi-tenancy rules).
- **Migrations:** reversible, safe under unattended `db:prepare` from any prior version, with every foreign key and `account_id` indexed. Commit only `db/schema.rb` (restore the other schema files).
- **Collectible-agnostic core:** finish names and order come from `Catalog.collecting_for(type)`; the foil marker, number correction, parser and ranking stay in `MTG::` (FR-1, FR-3).
- **Design system:** only tokens and `c-*` classes. New patterns go in `app/assets/stylesheets/collector/additions.css` and `docs/design-system/components/Scanner.md` (FR-6). Use the `collector-design-system` skill before each view change.
- **Exact copy from the spec:**
  - "Added 1 × ‹name› (‹SET› · ‹number›, ‹finish›) to your collection." (no finish part when unspecified)
  - "Removed 1 × … from your collection."
  - "You already have the most copies one lot can hold (9,999)."
  - "This sitting: N cards"
  - "Added N cards in this sitting"
  - "Printing not confirmed"
  - "Matched by its collector line"
  - "Matched by its collector line, one digit corrected"
  - "Foil · read from the card"
  - "Changed in your collection"
  - "Other printings"
  - "Show all"
  - "Done"
- **Evidence rules:**
  - Tuning uses only the stored runs and the spike's development photos. Held-out photos are read only after the freeze commit, and the live sitting's cards never feed tuning (AC-6.7).
  - Development rates are labelled biased.
  - No pass threshold is set.
  - Every number carries its sample size.
  - No image is committed.
- **Timing targets:** the speed and size targets (500 ms add, 300 ms p95 for Other printings, 1 s detection on the iPhone, +20 KB) are measured outside the gating suite (NFR Performance).
- **Commits:** `bin/ci` passes at every commit. One Conventional Commit per step (`feat`, `test`, `fix`, `docs`, `chore`; scope `scanner`, `findings` or `009`). The branch is `009-card-scanner-confirm-flow` (it already exists).

---

## Goal

Signed-in collectors can scan, confirm and add cards from the scanner in stack sittings with Undo, pick the printing in place, and get readable results from unguided photos. The plan ends with findings from a 35-card live sitting on the iPhone.

**Components (Simplicity Gate: 3):**
1. The sitting: `Scanner::Sitting`, `Scanner::SittingEntry` and their three controllers (entries, undos, endings), plus `Scanner::OtherPrintings` and its controller.
2. Recognition: `MTG::Reading` (evidence ranking), `MTG::CollectorNumber`, `Catalog::NameIndex.clean`, `scanner/detector.js` and `scanner/geometry.js` (refinements).
3. The findings tools: `Collector::ScannerFindings::{Ranking, SittingReport}`, measurement-mode events and capture fields, rake tasks and scripts.

No new gem, no new JS pin outside `app/javascript/` (Anti-Abstraction Gate: Rails, Turbo and Stimulus directly; one model per concept). The HTML contracts are in `contracts/api.md` and their request specs are written before each controller (Integration-First Gate).

**Human checkpoints (the maintainer):**
- **Phase 0:** asked once, early (they gather while the agent builds):
  - the 35-card manifest (or a list to build it from), with each card's finish
  - a time for the iPhone sitting after the freeze
  - at least 10 unguided photos of cards from the pile, taken in the phone's camera app
- **Phase 10:** the live sitting and the photo-path run on the iPhone; the findings are theirs to read.

Phases 1–9 need nothing from the maintainer. Per the "work ahead of human checkpoints" practice, run them while the maintainer prepares the pile.

---

## Phase 0: Environment and the maintainer's inputs

**Implements:** Users and Context | **Satisfies:** none directly; every later phase needs it
**Files:** none in the repository
**Interfaces:** Consumes: Scryfall bulk data. Produces: a populated development catalog, the users `findings@localhost` and `sitting@localhost`, the maintainer's inputs requested.

- [ ] Ask the maintainer, in one message:
  - for the 35-card manifest at `~/card-scanner-corpus/phase2-sitting/manifest.csv`: columns `file,set,number,foil,era,finish`; `file` is a label such as `S001`; `era` is optional (as in spec 007); `finish` is `nonfoil`, `foil` or `etched` and is optional when `foil` says it
  - for a time for the iPhone sitting after the freeze
  - for at least 10 unguided photos of cards from that pile, kept on the phone for Phase 10
- [ ] Refresh the catalog in the foreground: `bin/rails runner 'Catalog::Refresh.new("mtg", trigger: "manual").call'`, then `bin/rails "catalog:status[mtg]"`. Expect the newest run `applied` and `bin/rails runner 'puts Catalog::Name.count'` at about 36,000. Note the `source_version`.
- [ ] Make the two local users (passwords stay in the session, never committed): `COLLECTOR_PASSWORD=<random> bin/rails "collector:user[findings@localhost]"`, and the same for `sitting@localhost`.
- [ ] Rebuild ground truth against this catalog. `bin/rails "scanner:ground_truth[$HOME/card-scanner-corpus/phase1-live/manifest.csv]"` should report `49 rows resolved, 0 errors`, and `bin/rails "scanner:ground_truth[$HOME/card-scanner-corpus/tuning/manifest.csv]"` should report `12 rows resolved, 0 errors`. Any error is listed in `research.md` and that file is excluded.

---

## Phase 1: The ranking baseline under spec 007 (before any ranking change)

**Implements:** Story 5 (the evidence base), FR-3 | **Satisfies:** AC-5.4 (committed ground truth, the baseline)
**Files:** `lib/collector/scanner_findings/ranking.rb`, `spec/lib/collector/scanner_findings/ranking_spec.rb`, `lib/tasks/scanner.rake`, `spec/fixtures/card_scanner/{phase1_live_ground_truth,phase1_tuning_ground_truth,spec009_ranking_baseline}.json`
**Interfaces:** Consumes: `MTG::Reading#candidates`, `#name_candidates`, `Collector::ScannerFindings.identity_names`. Produces: `Collector::ScannerFindings::Ranking.new(fixtures:, runs:, misreads:)` with `#rankings(strong_name_score: nil)`, `#write_baseline!`, `#baseline`, `#losses(now, against:)`, `#name_losses(now, against:)`, `#misreads_fixed?(now)`, `#comparison(now, against:)` and `#sweep(thresholds, against:)` (the last calls `MTG::Reading#ranked`, added in Phase 2); the tasks `scanner:ranking_baseline` and `scanner:ranking`.

- [ ] Commit the ground truth as text (AC-5.4): `cp ~/card-scanner-corpus/phase1-live/ground_truth.json spec/fixtures/card_scanner/phase1_live_ground_truth.json` and `cp ~/card-scanner-corpus/tuning/ground_truth.json spec/fixtures/card_scanner/phase1_tuning_ground_truth.json`. Check both have `"photos"` with 49 and 12 records: `ruby -rjson -e 'p %w[live tuning].map { JSON.parse(File.read("spec/fixtures/card_scanner/phase1_#{it}_ground_truth.json"))["photos"].size }'`, which should print `[49, 12]`. Commit: `test(findings): commit the new corpus's and tuning cards' ground truth (009)`.
- [ ] Write the failing spec `spec/lib/collector/scanner_findings/ranking_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::ScannerFindings::Ranking do
  let(:fixtures) { Pathname(Dir.mktmpdir) }
  let(:ranking) { described_class.new(fixtures:, runs: { "Live" => %w[results.json truth.json] }, misreads: { "Live" => %w[a.jpeg] }) }

  before do
    mom = create(:catalog_set, code: "mom")
    [ "Lightning Bolt", "Lightning Helix" ].each_with_index do |name, index|
      identity = create(:catalog_identity, name:)
      create(:mtg_printing, entry: create(:catalog_entry, identity:, name:, set: mom, number: (123 + index).to_s))
    end
    Catalog::NameIndex.new("mtg").rebuild
    fixtures.join("truth.json").write(JSON.generate("photos" => [ { "file" => "a.jpeg", "name" => "Lightning Bolt" },
      { "file" => "b.jpeg", "name" => "Lightning Helix" } ]))
    fixtures.join("results.json").write(JSON.generate("results" => [
      { "file" => "a.jpeg", "name_text" => "Lightning Bolt", "collector_text" => "" },
      { "file" => "b.jpeg", "name_text" => "Lightning Helix", "collector_text" => "" },
      { "file" => "c.jpeg", "name_text" => "Untracked", "collector_text" => "" } ]))
  end

  after { FileUtils.rm_rf(fixtures) }

  it "ranks every reading that has ground truth, with its final and name-only top 3", :aggregate_failures do
    rows = ranking.rankings.fetch("Live")
    expect(rows.map { it["file"] }).to eq(%w[a.jpeg b.jpeg])
    expect(rows.first).to include("expected" => "Lightning Bolt", "name" => include("Lightning Bolt"))
    expect(rows.first["final"].first).to eq("Lightning Bolt")
  end

  it "writes a baseline that loses nothing against itself", :aggregate_failures do
    ranking.write_baseline!
    expect(JSON.parse(fixtures.join(described_class::BASELINE).read)).to include("format_version" => 1, "ranking" => "spec 007")
    now = ranking.rankings
    expect(ranking.losses(now)).to be_empty
    expect(ranking.name_losses(now)).to be_empty
    expect(ranking.misreads_fixed?(now)).to be(true)
  end

  it "reports a lost first place and the changed first candidate", :aggregate_failures do
    ranking.write_baseline!
    worse = ranking.rankings.transform_values do |rows|
      rows.map { it["file"] == "a.jpeg" ? it.merge("final" => [ "Lightning Helix", "Lightning Bolt" ]) : it }
    end
    expect(ranking.losses(worse)).to eq([ [ "Live", "a.jpeg" ] ])
    expect(ranking.misreads_fixed?(worse)).to be(false)
    expect(ranking.comparison(worse)).to include("| Live | a.jpeg | Lightning Bolt |", "Right first places lost: Live a.jpeg")
  end
end
```

- [ ] Run `bin/rspec spec/lib/collector/scanner_findings/ranking_spec.rb`. Expect it to FAIL with `uninitialized constant Collector::ScannerFindings::Ranking`.
- [ ] Write `lib/collector/scanner_findings/ranking.rb`:

```ruby
# Spec 009 AC-5.4: the stored text of every earlier run, ranked by the shipped matcher against committed ground truth.
# The baseline is taken once under spec 007's ranking, before spec 009 changes it, and committed. Later rankings are
# compared with it: every reading whose first candidate changed, every right first place lost (there must be none)
# and every right card that left the name-only top 3 (AC-6.1). Runs against the development catalog.
class Collector::ScannerFindings::Ranking
  FIXTURES = Rails.root.join("spec/fixtures/card_scanner")
  BASELINE = "spec009_ranking_baseline.json"
  RUNS = {
    "Phase 0" => %w[ocr_results.json ground_truth.json],
    "Phase 1 photo replay" => %w[phase1_photos_ocr_results.json ground_truth.json],
    "Tuning round 4" => %w[phase1_tuning4_ocr_results.json phase1_tuning_ground_truth.json],
    "New corpus live" => %w[phase1_live_ocr_results.json phase1_live_ground_truth.json],
    "New corpus photos" => %w[phase1_live_photos_ocr_results.json phase1_live_ground_truth.json]
  }.freeze
  # Spec 007 research.md §5's misread collector numbers, checked on the live run only (spec 009 AC-5.4).
  MISREADS = { "New corpus live" => %w[IMG_6765.jpeg IMG_6769.jpeg IMG_6792.jpeg] }.freeze

  def initialize(fixtures: FIXTURES, runs: RUNS, misreads: MISREADS)
    @fixtures = Pathname(fixtures)
    @runs = runs
    @misreads = misreads
    @readings = {}
  end

  # { run => [ { "file", "expected", "final", "name" } ] }: each reading's expected card, its final top 3 and its
  # name-only top 3. strong_name_score ranks with another strong-name threshold, for the sweep (AC-5.1).
  def rankings(strong_name_score: nil)
    @runs.to_h do |run, (results, truth)|
      expected = json(truth).fetch("photos").to_h { [ it["file"], it["name"] ] }
      rows = json(results).fetch("results").filter_map do |result|
        next unless expected.key?(result["file"])

        reading = reading(run, result)
        final = strong_name_score ? reading.ranked(strong_name_score) : reading.candidates
        { "file" => result["file"], "expected" => expected[result["file"]], "final" => final.first(3).map { it.entry.name },
          "name" => Collector::ScannerFindings.identity_names(reading.name_candidates.map(&:identity_id)) }
      end
      [ run, rows ]
    end
  end

  def write_baseline!
    @fixtures.join(BASELINE).write(JSON.pretty_generate("format_version" => 1, "spec" => "009", "ranking" => "spec 007",
      "catalog" => catalog_version, "runs" => rankings))
  end

  def baseline = json(BASELINE).fetch("runs")

  # [run, file] for each reading the baseline had right first and now doesn't (AC-5.4: none allowed).
  def losses(now, against: baseline) = lost(now, against) { right_first?(it) }

  # [run, file] for each reading whose right card left the name-only top 3 (AC-6.1: none allowed).
  def name_losses(now, against: baseline) = lost(now, against) { it.present? && it["name"].first(3).include?(it["expected"]) }

  def misreads_fixed?(now)
    @misreads.all? { |run, files| files.all? { |file| right_first?(now.fetch(run).find { it["file"] == file }) } }
  end

  # Markdown for research.md: per run, right first and in the top 3 under each ranking; every changed first candidate.
  def comparison(now = rankings, against: baseline)
    totals = @runs.keys.map do |run|
      before, after = against.fetch(run), now.fetch(run)
      "| #{run} | #{rate(before) { right_first?(it) }} | #{rate(after) { right_first?(it) }} | " \
        "#{rate(before) { in_top3?(it) }} | #{rate(after) { in_top3?(it) }} |"
    end
    changed = @runs.keys.flat_map do |run|
      later = now.fetch(run).to_h { [ it["file"], it ] }
      against.fetch(run).filter_map do |row|
        after = later[row["file"]]
        next if after.nil? || after["final"].first == row["final"].first

        "| #{run} | #{row["file"]} | #{row["expected"]} | #{row["final"].join("; ")} | #{after["final"].join("; ")} |"
      end
    end
    [ "| Run | Right first, spec 007 | Right first, spec 009 | Top 3, spec 007 | Top 3, spec 009 |", "|---|---|---|---|---|", *totals, "",
      "First candidate changed: #{changed.size}", "", "| Run | File | Expected | Spec 007 top 3 | Spec 009 top 3 |", "|---|---|---|---|---|",
      *changed, "", "Right first places lost: #{listed(losses(now, against:))}. Right cards that left the name-only top 3: " \
      "#{listed(name_losses(now, against:))}. Misread cases right first: #{misreads_fixed?(now) ? "yes" : "no"}." ].join("\n")
  end

  # One row per threshold (AC-5.1): right first over every run, first places lost, and whether the misreads are fixed.
  def sweep(thresholds, against: baseline)
    thresholds.map do |threshold|
      now = rankings(strong_name_score: threshold)
      { threshold:, right_first: now.values.flatten.count { right_first?(it) }, losses: losses(now, against:).size,
        misreads_fixed: misreads_fixed?(now) }
    end
  end

  private
    def reading(run, result)
      @readings[[ run, result["file"] ]] ||=
        MTG::Reading.new(name_text: result["name_text"].to_s, collector_text: result["collector_text"].to_s).resolve
    end

    def lost(now, against)
      against.flat_map do |run, rows|
        later = now.fetch(run, []).to_h { [ it["file"], it ] }
        rows.select { yield(it) && !yield(later[it["file"]]) }.map { [ run, it["file"] ] }
      end
    end

    def right_first?(row) = row.present? && row["final"].first == row["expected"]
    def in_top3?(row) = row["final"].first(3).include?(row["expected"])
    def rate(rows, &) = "#{rows.count(&)}/#{rows.size}"
    def listed(pairs) = pairs.empty? ? "none" : pairs.map { it.join(" ") }.join(", ")
    def json(name) = JSON.parse(@fixtures.join(name).read)
    def catalog_version = Catalog::RefreshRun.where(collectible_type: "mtg", status: "applied").order(:finished_at).last&.source_version
end
```

- [ ] Run `bin/rspec spec/lib/collector/scanner_findings/ranking_spec.rb`. Expect 3 examples, 0 failures.
- [ ] Append to `lib/tasks/scanner.rake`, inside `namespace :scanner do … end`:

```ruby
  desc "Spec 009 AC-5.4: commit the ranking baseline (once, under spec 007's ranking, before spec 009 changes it)"
  task ranking_baseline: :environment do
    Collector::ScannerFindings::Ranking.new.write_baseline!
    puts "Wrote #{Collector::ScannerFindings::Ranking::FIXTURES.join(Collector::ScannerFindings::Ranking::BASELINE)}"
  end

  desc "Spec 009 AC-5.4, AC-6.1: every earlier run's stored text under the shipped ranking, against the baseline"
  task ranking: :environment do
    ranking = Collector::ScannerFindings::Ranking.new
    now = ranking.rankings
    puts ranking.comparison(now)
    abort "A right first place or a name-only top 3 place was lost." if ranking.losses(now).any? || ranking.name_losses(now).any?
  end
```

- [ ] Commit the tool: `feat(findings): add the spec 009 ranking comparison (009)`.
- [ ] Take the baseline under spec 007's ranking, before Phase 2 touches `MTG::Reading`: `git diff --exit-code main -- app/models/mtg app/models/catalog` must be empty. Then `bin/rails scanner:ranking_baseline`. Check it: `bin/rails scanner:ranking` should print identical before and after columns, `First candidate changed: 0`, `none` twice, and the misreads `no`. Commit `spec/fixtures/card_scanner/spec009_ranking_baseline.json`: `test(findings): record the spec 007 ranking baseline (009)`.

---

## Phase 2: Evidence ranking, the one-digit cross-check, query cleaning and the strong-name threshold

**Implements:** Story 5, FR-3, Story 6 (AC-6.1, AC-6.5 display) | **Satisfies:** AC-5.1, AC-5.2, AC-5.3, AC-5.4, AC-5.5, AC-6.1, AC-2.1 (marks), AC-6.5 (the hint, marked in Phase 4)
**Files:** `app/models/mtg/collector_number.rb`, `app/models/mtg/reading.rb`, `app/models/mtg/collector_line.rb` (comment), `app/models/catalog/name_index.rb`, `app/views/scanners/_candidate.html.erb`, `app/views/scanners/_result.html.erb`, `app/views/icons/_alert.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/models/mtg/{collector_number,reading}_spec.rb`, `spec/models/catalog/name_index_spec.rb`, `spec/requests/scanner/readings_spec.rb`, `lib/tasks/scanner.rake`
**Interfaces:** Consumes: Phase 1's `Ranking`. Produces:
- `MTG::Reading::Candidate(:entry, :evidence, :name_rank, :strong_name)` with `#collector_line?`, `#corrected?`, `#name?` and `#rank_key`
- `MTG::Reading#ranked(strong_name_score)`, `#finish_hint` (`"foil"` or `nil`), and `MTG::Reading::STRONG_NAME_SCORE`
- `MTG::CollectorNumber.one_digit_apart?(printed, read)`
- `Catalog::NameIndex::LONG_TOKEN_SHARE` and `.long_token_share(line)`
- the task `scanner:strong_sweep`
- `scanners/_candidate` locals `(candidate:, reading:)`; Phase 4 adds `key:` and `rank:`

- [ ] Write the failing spec `spec/models/mtg/collector_number_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::CollectorNumber, type: :model do
  describe ".one_digit_apart?" do
    {
      [ "117", "17" ] => true, [ "282", "202" ] => true, [ "51", "5" ] => true, [ "0117", "17" ] => true,
      [ "117a", "17a" ] => true, [ "52★", "5★" ] => true,
      [ "117", "117" ] => false, [ "117", "1" ] => false, [ "117a", "17" ] => false, [ "117", "17a" ] => false,
      [ "117", nil ] => false, [ "", "1" ] => false
    }.each do |(printed, read), expected|
      it "is #{expected} for #{printed.inspect} printed and #{read.inspect} read (AC-5.3)" do
        expect(described_class.one_digit_apart?(printed, read)).to be(expected)
      end
    end
  end
end
```

- [ ] Run `bin/rspec spec/models/mtg/collector_number_spec.rb`. Expect it to FAIL (`uninitialized constant MTG::CollectorNumber`).
- [ ] Write `app/models/mtg/collector_number.rb`:

```ruby
require "did_you_mean"

# Collector numbers as printed: digits, then any letters or symbols ("117", "117a", "52★") (spec 009 AC-5.3).
module MTG::CollectorNumber
  SHAPE = /\A0*(\d+)(\D*)\z/

  module_function

  # True when the digits differ by one digit added, dropped or changed, ignoring leading zeros, and whatever follows
  # the digits matches exactly.
  def one_digit_apart?(printed, read)
    a, b = SHAPE.match(printed.to_s), SHAPE.match(read.to_s)
    return false unless a && b && a[2].casecmp?(b[2])

    DidYouMean::Levenshtein.distance(a[1], b[1]) == 1
  end
end
```

- [ ] Run `bin/rspec spec/models/mtg/collector_number_spec.rb`. Expect 12 examples, 0 failures. Commit: `feat(scanner): compare collector numbers one digit apart (009)`.
- [ ] Add the failing cleaning examples to `spec/models/catalog/name_index_spec.rb`. Put these two inside its existing `describe ".clean"` block:

```ruby
    it "skips a line of short noise tokens for the name below it (spec 009 AC-6.1, IMG_6720)" do
      text = "Lp cog Sw pan soon pa B= SR be prea ZN oo Ld\r\nFanged Flames 1\r\n~  _______ \\3"
      expect(described_class.clean(text)).to eq("Fanged Flames")
    end

    it "keeps spec 007's cases under spec 009's rule", :aggregate_failures do
      expect(described_class.clean("A) ae ea i Rd TE NC DORA AA Sa pr\nCosmic Hunger")).to eq("Cosmic Hunger")
      expect(described_class.clean("Ox")).to eq("Ox")
      expect(described_class.clean("Ox of Agonas")).to eq("Agonas")
    end
```

  and this one at the top level of the spec:

```ruby
  it "finds the right card in the top 3 for IMG_6720's text (AC-6.1)" do
    create(:mtg_printing, entry: create(:catalog_entry, identity: create(:catalog_identity, name: "Fanged Flames"), name: "Fanged Flames"))
    create(:mtg_printing, entry: create(:catalog_entry, identity: create(:catalog_identity, name: "Monsoon"), name: "Monsoon"))
    described_class.new("mtg").rebuild
    text = "Lp cog Sw pan soon pa B= SR be prea ZN oo Ld\r\nFanged Flames 1\r\n~  _______ \\3"
    expect(described_class.new("mtg").search(text).map(&:name)).to include("Fanged Flames")
  end
```

  ("Ox of Agonas" keeps spec 007's rule of dropping tokens shorter than 3 characters: the line qualifies, since 6 of its 10 characters are in long tokens, and its trimmed form is "Agonas".)
- [ ] Run `bin/rspec spec/models/catalog/name_index_spec.rb`. Expect the IMG_6720 examples to FAIL (`"cog pan soon prea"`).
- [ ] In `app/models/catalog/name_index.rb`, replace everything from the line `MIN_TOKEN = 3` through the `end` of `def self.clean` (that span holds `MIN_TOKEN`, `BATCH_SIZE`, the comment and `clean`; `SHORTLIST` and `SHORT_QUERY` above it stay) with:

```ruby
  MIN_TOKEN = 3
  # A line is a query only if at least this share of its characters sit in tokens of MIN_TOKEN or more (spec 009
  # AC-6.1): a line of short noise tokens no longer beats the name. A tuning setting, frozen before the live sitting.
  LONG_TOKEN_SHARE = 0.5
  BATCH_SIZE = 1_000

  # The longest mostly-alphabetic line, once tokens shorter than MIN_TOKEN are dropped, among lines mostly made of
  # such tokens; failing that, among every line as before; failing that, the longest such line as read, so a short name
  # like "Ox" is still a query (spec 007 AC-3.4).
  def self.clean(text)
    lines = text.to_s.lines.map(&:strip)
    trimmed = lines.map { |line| line.split.select { |token| token.length >= MIN_TOKEN }.join(" ") }
    worded = trimmed.select.with_index { |_, index| long_token_share(lines[index]) >= LONG_TOKEN_SHARE }
    longest_alphabetic(worded) || longest_alphabetic(trimmed) || longest_alphabetic(lines) || ""
  end

  def self.long_token_share(line)
    tokens = line.split
    total = tokens.sum(&:length)
    total.zero? ? 0 : tokens.select { it.length >= MIN_TOKEN }.sum(&:length).fdiv(total)
  end
```

- [ ] Run `bin/rspec spec/models/catalog/name_index_spec.rb`. Expect 0 failures. Commit: `feat(scanner): skip short-token noise lines when cleaning the name query (009)`.
- [ ] Rewrite `spec/models/mtg/reading_spec.rb`. The spec 007 examples are kept, with the evidence shape; the examples for the new rule are added:

```ruby
require "rails_helper"

RSpec.describe MTG::Reading, type: :model do
  let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine", released_on: Date.new(2023, 4, 21)) }
  let(:stx) { create(:catalog_set, code: "stx", name: "Strixhaven", released_on: Date.new(2021, 4, 23)) }
  let!(:bolt) { printing("Lightning Bolt", set: mom, number: "123") }

  before do
    printing("Lightning Helix", set: mom, number: "200")
    Catalog::NameIndex.new("mtg").rebuild
  end

  def printing(name, set:, number:, language: "en", finishes: %w[nonfoil foil])
    identity = Catalog::Identity.find_by(name:) || create(:catalog_identity, name:)
    create(:mtg_printing, finishes:, entry: create(:catalog_entry, identity:, name:, set:, number:, language:)).entry
  end

  def read(name_text: "", collector_text: "") = described_class.new(name_text:, collector_text:).resolve

  it "puts the printing the collector line identifies first, once, matched by both (AC-3.2, AC-5.1)", :aggregate_failures do
    reading = read(name_text: "Lightning Bolt", collector_text: "R 0123\nMOM • EN")
    expect(reading.collector_status).to eq(:one)
    expect(reading.candidates.first).to have_attributes(entry: bolt, evidence: %i[collector_line name], strong_name: true)
    expect(reading.candidates.count { it.entry.catalog_identity_id == bolt.catalog_identity_id }).to eq(1)
  end

  it "uses English when the collector line names no language" do
    expect(read(collector_text: "M0123\nMOM").collector_status).to eq(:one)
  end

  it "reports several printings and falls back to the name (AC-3.3)", :aggregate_failures do
    printing("Lightning Bolt", set: mom, number: "123")
    reading = read(name_text: "Lightning Bolt", collector_text: "R 0123\nMOM • EN")
    expect(reading.collector_status).to eq(:several)
    expect(reading.candidates.map(&:evidence)).to all(eq(%i[name]))
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

  context "when the name and the collector line point to different cards (spec 009 Story 5)" do
    let!(:tome) { printing("Tome Shredder", set: stx, number: "117") }
    let!(:spellbinder) { printing("Elite Spellbinder", set: stx, number: "17") }

    before { Catalog::NameIndex.new("mtg").rebuild }

    it "ranks a strong name match first, corrected by one digit, and the collector-line printing second (AC-5.1, AC-5.3)", :aggregate_failures do
      candidates = read(name_text: "Tome Shredder", collector_text: "R 0017\nSTX • EN").candidates
      expect(candidates.first).to have_attributes(entry: tome, evidence: %i[name collector_line_corrected], strong_name: true)
      expect(candidates.second).to have_attributes(entry: spellbinder, evidence: include(:collector_line))
    end

    it "keeps the collector-line printing first when the name match isn't strong, without a correction (AC-5.2)", :aggregate_failures do
      candidates = read(name_text: "Tome Shredder", collector_text: "R 0017\nSTX • EN").ranked(1.01)
      expect(candidates.first).to have_attributes(entry: spellbinder, evidence: include(:collector_line))
      expect(candidates.second).to have_attributes(entry: tome, evidence: %i[name])
    end

    it "corrects a number that matched no printing to the named card's one printing a digit away (AC-5.3)" do
      expect(read(name_text: "Tome Shredder", collector_text: "R 0118\nSTX • EN").candidates.first)
        .to have_attributes(entry: tome, evidence: %i[name collector_line_corrected])
    end

    it "doesn't correct when two printings are a digit away, or the letters differ (AC-5.3)", :aggregate_failures do
      printing("Tome Shredder", set: stx, number: "119")
      expect(read(name_text: "Tome Shredder", collector_text: "R 0118\nSTX • EN").candidates.first).not_to be_corrected
      tome.update!(number: "117a")
      expect(read(name_text: "Tome Shredder", collector_text: "R 0017\nSTX • EN").candidates.first).not_to be_corrected
    end
  end

  describe "#finish_hint (spec 009 AC-6.5)" do
    it "suggests foil only when the separator reads as the foil marker", :aggregate_failures do
      expect(read(collector_text: "R 0123\nMOM ★ EN").finish_hint).to eq("foil")
      expect(read(collector_text: "R 0123\nMOM • EN").finish_hint).to be_nil
      expect(read(collector_text: "").finish_hint).to be_nil
    end
  end

  describe "the ranking rule (AC-5.5)" do
    it "orders by a strong name, then collector-line evidence, then name rank" do
      kinds = [ [ %i[name], 1, false ], [ %i[collector_line], nil, false ], [ %i[name], 0, true ], [ %i[name collector_line_corrected], 2, false ] ]
      candidates = kinds.map { |evidence, name_rank, strong_name| described_class::Candidate.new(entry: bolt, evidence:, name_rank:, strong_name:) }
      expect(candidates.sort_by(&:rank_key).map { [ it.evidence, it.name_rank ] })
        .to eq([ [ %i[name], 0 ], [ %i[name collector_line_corrected], 2 ], [ %i[collector_line], nil ], [ %i[name], 1 ] ])
    end
  end
end
```

  ("R 0017" parses as number 17 through the rarity-first pattern, and "R 0118" as 118. STX 118 isn't in the catalog, so the line matches no printing.)
- [ ] Run `bin/rspec spec/models/mtg/reading_spec.rb`. Expect failures (`evidence` is unknown, `ranked` and `finish_hint` are undefined).
- [ ] Rewrite `app/models/mtg/reading.rb`:

```ruby
# What the scanner read from one card, and the printings it points to (spec 007 Story 3, spec 009 Story 5): the parsed
# collector line and its printing lookup (one, none or several), the name index's candidates from the name strip alone,
# and the final ranking the page shows. Each candidate carries the kinds of evidence behind it, and one rule orders them
# (AC-5.5): a strong name match first, then collector-line evidence, then the name order. Only text arrives here; the
# photo stays on the device (FR-3).
class MTG::Reading
  include ActiveModel::Model
  include ActiveModel::Attributes

  COLLECTIBLE_TYPE = "mtg"
  CANDIDATES = 3
  MAX_TEXT_LENGTH = 2_000
  # The top name candidate is a strong match at this Jaro-Winkler similarity to the cleaned query or above (spec 009
  # AC-5.1). Chosen with `bin/rails scanner:strong_sweep` on the stored text of earlier runs; frozen with the settings.
  STRONG_NAME_SCORE = 0.9

  # evidence: the kinds behind the candidate, from :collector_line, :collector_line_corrected and :name (AC-5.5);
  # name_rank: its place among the name candidates, if any; strong_name: it's the top name candidate, strongly matched.
  Candidate = Data.define(:entry, :evidence, :name_rank, :strong_name) do
    def collector_line? = evidence.intersect?(%i[collector_line collector_line_corrected])
    def corrected? = evidence.include?(:collector_line_corrected)
    def name? = evidence.include?(:name)

    # The one ranking rule (AC-5.5). A later kind of evidence, such as an art match, joins here.
    def rank_key = [ strong_name ? 0 : 1, collector_line? ? 0 : 1, name_rank || CANDIDATES ]
  end

  attribute :name_text, :string, default: ""
  attribute :collector_text, :string, default: ""

  validates :name_text, :collector_text, length: { maximum: MAX_TEXT_LENGTH }

  # Runs every query once, so the view only reads memoised results; the candidates' finishes come with them (AC-1.1).
  def resolve
    catalog_ready? && Catalog::Entry.preload_extensions(candidates.map(&:entry))
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

  # The finish the collector line suggests: the foil marker printed on foil cards from M15 on (spec 009 AC-6.5). A
  # hint for the page to mark; it never adds or chooses anything.
  def finish_hint = collector_line.foil ? "foil" : nil

  def candidates = @candidates ||= ranked(STRONG_NAME_SCORE)

  # The final ranking with a given strong-name threshold; the findings sweep tries several (AC-5.1).
  def ranked(strong_name_score)
    matched = collector_status == :one ? collector_entries.first : nil
    strong = strong_name?(strong_name_score)
    by_card = {}
    name_printings(correct: correction_due?(matched, strong)).each_with_index do |(entry, corrected), rank|
      by_card[entry.catalog_identity_id] = Candidate.new(entry:, evidence: corrected ? %i[name collector_line_corrected] : %i[name],
        name_rank: rank, strong_name: rank.zero? && strong)
    end
    if matched
      named = by_card[matched.catalog_identity_id]
      by_card[matched.catalog_identity_id] = Candidate.new(entry: matched, evidence: named ? %i[collector_line name] : %i[collector_line],
        name_rank: named&.name_rank, strong_name: named&.strong_name || false)
    end
    by_card.values.each_with_index.sort_by { |candidate, index| [ *candidate.rank_key, index ] }.map(&:first).first(CANDIDATES)
  end

  private
    def name_index = @name_index ||= Catalog::NameIndex.new(COLLECTIBLE_TYPE)

    # [:one | :none | :several | :unread, entries] (spec 007 AC-3.2, AC-3.3); English when no language was read.
    def collector_match
      @collector_match ||= if collector_line.set_code.blank? || collector_line.number.blank? then [ :unread, [] ]
      else
        entries = Catalog::Entry.where(collectible_type: COLLECTIBLE_TYPE).includes(:set, :identity)
          .printed_as(set_code: collector_line.set_code, number: collector_line.number, language: collector_line.language || "en").to_a
        [ { 0 => :none, 1 => :one }.fetch(entries.size, :several), entries ]
      end
    end

    def strong_name?(threshold) = name_candidates.first.present? && name_candidates.first.score >= threshold

    # The one-digit cross-check (AC-5.3) runs for the top name candidate when a strong name match names another card
    # than the collector line's printing, or when the line parsed but matched no printing. It never runs when the
    # collector-line printing ranks first (AC-5.2).
    def correction_due?(matched, strong)
      top = name_candidates.first
      return false unless top

      collector_status == :none || (matched.present? && strong && matched.catalog_identity_id != top.identity_id)
    end

    # One printing per name candidate, in candidate order: for the top one, when due, the one-digit correction; otherwise
    # its printing in the parsed set when it has one there, else its newest English printing. [entry, corrected?] pairs.
    def name_printings(correct:)
      name_candidates.map(&:identity_id).each_with_index.filter_map do |id, rank|
        options = printings_by_identity.fetch(id, [])
        corrected = corrected_printing(options) if correct && rank.zero?
        entry = corrected || options.find { it.set.code.casecmp?(collector_line.set_code.to_s) } || options.first
        [ entry, corrected.present? ] if entry
      end
    end

    def printings_by_identity
      @printings_by_identity ||= Catalog::Entry.searchable
        .where(collectible_type: COLLECTIBLE_TYPE, catalog_identity_id: name_candidates.map(&:identity_id), language: "en")
        .newest_first.includes(:set, :identity).to_a.group_by(&:catalog_identity_id)
    end

    # The named card's one printing in the read set whose number is a digit away from the read number (AC-5.3).
    def corrected_printing(options)
      near = options.select do |entry|
        entry.set.code.casecmp?(collector_line.set_code.to_s) && MTG::CollectorNumber.one_digit_apart?(entry.number, collector_line.number)
      end
      near.first if near.one?
    end
end
```

- [ ] In `app/models/mtg/collector_line.rb`, replace the comment line `# The foil mark is reported as read, but the scanner never uses it for the finish (FR-4).` with `# The foil mark is reported as read; the scanner shows it as a hint for the finish, never a choice (spec 009 AC-6.5).`
- [ ] Run `bin/rspec spec/models/mtg/reading_spec.rb`. Expect 0 failures.
- [ ] Write `app/views/icons/_alert.html.erb`:

```erb
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4 2.5 20h19z"/><path d="M12 10v4M12 17h.01"/></svg>
```

- [ ] Use the `collector-design-system` skill, then rewrite `app/views/scanners/_candidate.html.erb` (the evidence marks, AC-2.1 and AC-5.1):

```erb
<%# locals: (candidate:, reading:) %>
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
  <% if candidate.collector_line? %>
    <span class="c-badge c-badge--success"><%= render "icons/check" %><%= candidate.corrected? ? "Matched by its collector line, one digit corrected" : "Matched by its collector line" %></span>
  <% else %>
    <span class="c-badge c-badge--warning"><%= render "icons/alert" %>Printing not confirmed</span>
  <% end %>
  <% if candidate.name? %><span class="c-scanner__evidence">Matched by its name</span><% end %>
</div>
```

- [ ] In `app/views/scanners/_result.html.erb`, replace the line `<div class="c-grid"><%= render partial: "scanners/candidate", collection: reading.candidates, as: :candidate %></div>` with:

```erb
      <div class="c-grid"><%= render partial: "scanners/candidate", collection: reading.candidates, as: :candidate, locals: { reading: } %></div>
```

- [ ] Append to `app/assets/stylesheets/collector/additions.css`:

```css
/* Scanner confirm flow (spec 009): evidence on a candidate, add buttons per finish, Other printings and the sitting. */
.c-scanner__candidate { display:flex; flex-direction:column; align-items:flex-start; gap:var(--space-2); }
.c-scanner__evidence { font:400 13px/18px var(--font-sans); color:var(--ink-muted); }
```

- [ ] Add to `spec/requests/scanner/readings_spec.rb`, inside `context "when the name index is built"`:

```ruby
    it "marks a candidate found by its name alone as a guess at the printing (AC-2.1, AC-5.1)", :aggregate_failures do
      read("Lightning Bolt", "")
      expect(response.body).to include("Printing not confirmed", "Matched by its name")
      expect(response.body).not_to include("Matched by its collector line")
    end
```

- [ ] Run `bin/rspec spec/models spec/requests/scanner spec/system/scanner_spec.rb`. Expect 0 failures. Commit: `feat(scanner): rank by kinds of evidence and correct a one-digit misread (009)`.
- [ ] Append to `lib/tasks/scanner.rake`, inside the namespace:

```ruby
  desc "Spec 009 AC-5.1: right-first readings, lost first places and the misread cases per strong-name threshold"
  task strong_sweep: :environment do
    rows = Collector::ScannerFindings::Ranking.new.sweep((80..100).map { it / 100.0 })
    puts "| Threshold | Right first | First places lost | Misreads right first |", "|---|---|---|---|"
    rows.each { puts "| #{it[:threshold]} | #{it[:right_first]} | #{it[:losses]} | #{it[:misreads_fixed] ? "yes" : "no"} |" }
    eligible = rows.select { it[:losses].zero? && it[:misreads_fixed] }
    abort "No threshold fixes the three misreads without losing a right first place: ask the maintainer (AC-5.4)." if eligible.empty?

    best = eligible.max_by { [ it[:right_first], it[:threshold] ] }
    puts "Choose #{best[:threshold]}: the most right-first readings with no loss, ties to the higher threshold."
  end
```

- [ ] Run `bin/rails scanner:strong_sweep | tee tmp/spec009/strong_sweep.md` (run `mkdir -p tmp/spec009` first). If it aborts, stop and give the maintainer the table, with a recommendation. Otherwise set `STRONG_NAME_SCORE` in `app/models/mtg/reading.rb` to the chosen value.
- [ ] Run `bin/rails scanner:ranking | tee tmp/spec009/ranking.md`. Expect it to exit 0 with `Right first places lost: none`, no name-only top 3 losses, and `Misread cases right first: yes` (AC-5.4, AC-6.1). If it reports right cards that left the name-only top 3, the new cleaning caused them. Try `LONG_TOKEN_SHARE` at 0.4, 0.45, 0.55, 0.6, 0.65 and 0.7, rerunning `scanner:strong_sweep` and `scanner:ranking` for each. Keep the value nearest 0.5 that loses no name-only top 3 place and still fixes IMG_6720 (`bin/rspec spec/models/catalog/name_index_spec.rb`). If no value qualifies, stop and give the maintainer the table with a recommendation. Then `bin/rspec spec/models/mtg`; expect 0 failures. Commit: `feat(scanner): set the strong-name threshold from the stored runs (009)`, with the body `Ruling: STRONG_NAME_SCORE = <value> — most right-first readings with no loss across 5 runs (sweep in research.md) — biased upwards on these readings; the live sitting is the unbiased check.`

---

## Phase 3: The sitting and its entries

**Implements:** FR-1 (the add rules), FR-2, Stories 3–4 (model) | **Satisfies:** AC-1.2, AC-1.5, AC-1.6, AC-1.7, AC-3.1, AC-3.5 (end), AC-3.6 (state), AC-4.1, AC-4.2, AC-4.3, AC-4.4, NFR Reliability (migrations)
**Files:** `db/migrate/20261003100001_create_scanner_sittings.rb`, `db/migrate/20261003100002_create_scanner_sitting_entries.rb`, `db/schema.rb`, `app/models/scanner.rb`, `app/models/scanner/sitting.rb`, `app/models/scanner/sitting_entry.rb`, `app/models/account.rb`, `spec/models/scanner/{sitting,sitting_entry}_spec.rb`
**Interfaces:** Consumes: `Lot.add!`, `Catalog.collecting_for(type).finishes_for(entry)`, `Catalog::Entry.searchable`. Produces:
- `Scanner::Sitting::KEY_FORMAT` and `SHOWN = 10`
- `Scanner::Sitting.add!(account:, printing:, finish:, reading_key:)`, which returns `Scanner::Sitting::Added(:entry, :replayed)` and raises `Scanner::Sitting::Refused` (`#reason` is `:key`, `:unavailable` or `:finish`) or `ActiveRecord::RecordInvalid` at the cap
- `Scanner::Sitting#kept_entries` and `#end!` (returns the count kept)
- `Scanner::SittingEntry` with `#printing`, `#lot`, `#finish`, `#reading_key`, `#state` (`:added`, `:undone` or `:changed`) and `#undo!` (returns true when the lot went; raises `NotUndoable` with message `"undone"` or `"changed"`)
- `Account#scanner_sitting`

- [ ] Write the failing spec `spec/models/scanner/sitting_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Scanner::Sitting, type: :model do
  let(:account) { create(:user).account }
  let(:printing) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }

  def add(finish: "foil", key: "a" * 32, to: printing) = described_class.add!(account:, printing: to, finish:, reading_key: key)

  def refusal
    yield
    nil
  rescue described_class::Refused => error
    error.reason
  end

  describe ".add!" do
    it "adds one copy with the finish as tapped, condition and price unspecified, and opens the sitting (AC-1.2, AC-3.1)", :aggregate_failures do
      added = add
      lot = account.lots.sole
      expect(lot).to have_attributes(entry: printing, quantity: 1, finish: "foil", condition: nil, price_paid_cents: nil)
      expect(added).to have_attributes(replayed: false)
      expect(added.entry).to have_attributes(sitting: described_class.find_by!(account:), printing:, lot:, finish: "foil", reading_key: "a" * 32)
    end

    it "merges into the lot of the same finish, not a finish-unspecified one (AC-1.2)" do
      plain = create(:lot, account:, entry: printing)
      foil = create(:lot, account:, entry: printing, finish: "foil", quantity: 2)
      add
      expect([ foil.reload.quantity, plain.reload.quantity ]).to eq([ 3, 1 ])
    end

    it "adds nothing for a key the sitting already has, whatever the printing or finish (AC-1.5)", :aggregate_failures do
      first = add
      again = add(finish: "nonfoil", to: create(:mtg_printing).entry)
      expect(again).to have_attributes(replayed: true, entry: first.entry)
      expect(account.lots.sum(:quantity)).to eq(1)
    end

    it "adds a second copy for a second reading, in the same sitting (AC-1.7, AC-3.1)", :aggregate_failures do
      add
      add(key: "b" * 32)
      expect(account.lots.sole.quantity).to eq(2)
      expect(described_class.where(account:).count).to eq(1)
    end

    it "records nothing at the lot cap (AC-1.6)", :aggregate_failures do
      create(:lot, account:, entry: printing, finish: "foil", quantity: Lot::MAX_QUANTITY)
      expect { add }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Scanner::SittingEntry.count).to eq(0)
    end

    it "records a one-finish printing's finish, and none for a printing with none listed (AC-1.1)", :aggregate_failures do
      expect(add(finish: "nonfoil", to: create(:mtg_printing, finishes: %w[nonfoil]).entry).entry.finish).to eq("nonfoil")
      expect(add(finish: "", key: "b" * 32, to: create(:mtg_printing, finishes: []).entry).entry.finish).to be_nil
    end

    it "refuses a bad key, a retired or missing printing, and a finish the printing doesn't come in, changing nothing", :aggregate_failures do
      retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
      expect(refusal { add(key: "not-a-key") }).to eq(:key)
      expect(refusal { add(key: nil) }).to eq(:key)
      expect(refusal { add(to: retired) }).to eq(:unavailable)
      expect(refusal { add(to: nil) }).to eq(:unavailable)
      expect(refusal { add(finish: "etched") }).to eq(:finish)
      expect(refusal { add(finish: "") }).to eq(:finish)
      expect([ account.lots.count, described_class.count ]).to eq([ 0, 0 ])
    end
  end

  describe "#kept_entries" do
    it "lists the entries not undone, newest first, including those whose lot changed (AC-3.2, AC-3.6)", :aggregate_failures do
      first, second, third = %w[a b c].map { add(key: it * 32).entry }
      second.undo!
      account.lots.sole.destroy!
      expect(described_class.find_by!(account:).kept_entries).to eq([ third, first ])
      expect(third.reload.state).to eq(:changed)
    end
  end

  describe "#end!" do
    it "deletes itself and its entries, keeps the copies and counts the entries not undone (AC-3.5)", :aggregate_failures do
      add
      add(key: "b" * 32).entry.undo!
      expect(described_class.find_by!(account:).end!).to eq(1)
      expect([ described_class.count, Scanner::SittingEntry.count, account.lots.sum(:quantity) ]).to eq([ 0, 0, 1 ])
    end

    it "counts nothing when every add was undone (AC-3.5)" do
      add.entry.undo!
      expect(described_class.find_by!(account:).end!).to eq(0)
    end
  end

  it "goes with its account" do
    add
    account.user.destroy!
    expect([ described_class.count, Scanner::SittingEntry.count ]).to eq([ 0, 0 ])
  end
end
```

- [ ] Write the failing spec `spec/models/scanner/sitting_entry_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Scanner::SittingEntry, type: :model do
  let(:account) { create(:user).account }
  let(:printing) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }

  def add(key) = Scanner::Sitting.add!(account:, printing:, finish: "foil", reading_key: key * 32).entry

  describe "#undo!" do
    it "takes one copy out of the lot and marks the entry undone (AC-4.1)", :aggregate_failures do
      add("a")
      entry = add("b")
      expect(entry.undo!).to be(false)
      expect(account.lots.sole.quantity).to eq(1)
      expect(entry.reload.state).to eq(:undone)
    end

    it "removes the lot with its last copy (AC-4.1)", :aggregate_failures do
      expect(add("a").undo!).to be(true)
      expect(account.lots).to be_empty
    end

    it "takes one copy for each of two adds into the same lot (AC-4.3)" do
      [ add("a"), add("b") ].each(&:undo!)
      expect(account.lots).to be_empty
    end

    it "still takes the copy back after the lot was edited, if it wasn't merged away (AC-4.4)" do
      entry = add("a")
      add("b")
      account.lots.sole.revise!(condition: "near_mint", price_paid_cents: 250)
      entry.undo!
      expect(account.lots.sole).to have_attributes(quantity: 1, condition: "near_mint", price_paid_cents: 250)
    end

    it "refuses once undone, and when the lot was merged away or removed (AC-3.6, AC-4.2, AC-4.4)", :aggregate_failures do
      undone = add("a").tap(&:undo!)
      expect { undone.undo! }.to raise_error(described_class::NotUndoable, "undone")
      merged = add("b")
      create(:lot, account:, entry: printing, finish: "foil", condition: "near_mint")
      account.lots.find_by!(condition: nil).revise!(condition: "near_mint")
      expect(merged.reload.state).to eq(:changed)
      expect { merged.undo! }.to raise_error(described_class::NotUndoable, "changed")
      removed = add("c")
      account.lots.find(removed.lot_id).destroy!
      expect { removed.undo! }.to raise_error(described_class::NotUndoable, "changed")
    end
  end
end
```

- [ ] Run `bin/rspec spec/models/scanner/sitting_spec.rb spec/models/scanner/sitting_entry_spec.rb`. Expect it to FAIL (`uninitialized constant Scanner::Sitting`).
- [ ] Write `db/migrate/20261003100001_create_scanner_sittings.rb`:

```ruby
# The account's open run of scanner adds (spec 009 FR-2): at most one per account.
class CreateScannerSittings < ActiveRecord::Migration[8.1]
  def change
    create_table :scanner_sittings do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.timestamps
    end
  end
end
```

- [ ] Write `db/migrate/20261003100002_create_scanner_sitting_entries.rb`:

```ruby
# One add recorded in a scanner sitting (spec 009 FR-2): the printing, the finish as tapped, the lot the copy went into
# (cleared when that lot is removed or merged away, AC-3.6) and the page's reading key (one entry per key, AC-1.5).
class CreateScannerSittingEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :scanner_sitting_entries do |t|
      t.references :scanner_sitting, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :catalog_entry, null: false, foreign_key: true
      t.references :lot, foreign_key: { on_delete: :nullify }
      t.string :finish
      t.string :reading_key, null: false
      t.datetime :undone_at
      t.timestamps
      t.index %i[scanner_sitting_id reading_key], unique: true
    end
  end
end
```

  (The unique index leads with `scanner_sitting_id`, so it also indexes that foreign key.)
- [ ] Run `bin/rails db:migrate`, then `git checkout -- db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb`. Check reversibility: `bin/rails db:rollback:primary STEP=2 && bin/rails db:migrate:primary && git diff --stat db/schema.rb` should show only the two new tables against `main` (`git diff main -- db/schema.rb`).
- [ ] Write `app/models/scanner.rb`:

```ruby
# The card scanner's records (spec 009): the account's sitting and its entries. Measurement mode's files are plain
# Ruby (Scanner::MeasurementRun) and keep no table.
module Scanner
  def self.table_name_prefix = "scanner_"
end
```

- [ ] Write `app/models/scanner/sitting.rb`:

```ruby
# The account's run of scanner adds, open until "Done" (spec 009 Story 3, FR-2). An account has at most one: adding opens
# it, and ending it deletes it with its entries, which are workflow state rather than collection data (not exported).
# SQLite's IMMEDIATE transactions serialise writers, so two adds can't both open a sitting or reuse a key.
class Scanner::Sitting < ApplicationRecord
  KEY_FORMAT = /\A[0-9a-f]{32}\z/
  SHOWN = 10

  # Why an add was turned away before anything changed (FR-1): :key, :unavailable or :finish.
  class Refused < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason.to_s)
    end
  end

  # One add's outcome: its entry, and whether an earlier request with the same reading key made it (AC-1.5).
  Added = Data.define(:entry, :replayed)

  belongs_to :account
  has_many :entries, class_name: "Scanner::SittingEntry", foreign_key: :scanner_sitting_id, inverse_of: :sitting,
    dependent: :delete_all

  # Adds one copy of a printing for a reading, at most once per reading key in the account's open sitting (AC-1.2,
  # AC-1.5, AC-3.1). The copy merges into its lot as the catalog's Add does; Lot.add! raises RecordInvalid at the
  # 9,999 cap (AC-1.6), and nothing is recorded then.
  def self.add!(account:, printing:, finish:, reading_key:)
    finish = finish.presence
    raise Refused, :key unless KEY_FORMAT.match?(reading_key.to_s)
    raise Refused, :unavailable unless printing && Catalog::Entry.searchable.exists?(printing.id)
    raise Refused, :finish unless finish_offered?(printing, finish)

    transaction do
      sitting = find_or_create_by!(account:)
      existing = sitting.entries.find_by(reading_key:)
      next Added.new(entry: existing, replayed: true) if existing

      lot = Lot.add!(account:, entry: printing, finish:)
      Added.new(entry: sitting.entries.create!(account:, printing:, lot:, finish:, reading_key:), replayed: false)
    end
  end

  # A printing with finishes takes one of them; one with none listed takes none (AC-1.1).
  def self.finish_offered?(printing, finish)
    finishes = Catalog.collecting_for(printing.collectible_type).finishes_for(printing)
    finishes.empty? ? finish.nil? : finishes.include?(finish)
  end

  # Every entry not undone, newest first, including those whose lot changed (AC-3.2, AC-3.6).
  def kept_entries = entries.kept.newest_first.includes(printing: :set)

  # Ends the sitting (AC-3.5): the copies stay in the collection; the entries go. Returns how many were kept.
  def end!
    count = entries.kept.count
    destroy!
    count
  end
end
```

- [ ] Write `app/models/scanner/sitting_entry.rb`:

```ruby
# One add recorded in a scanner sitting (spec 009 FR-2): the printing, the finish as tapped, the lot the copy went into
# and the page's reading key. The lot reference clears itself (on delete set null) when that lot is removed or merged
# away by an edit, which is how an entry knows it changed in the collection (AC-3.6).
class Scanner::SittingEntry < ApplicationRecord
  NotUndoable = Class.new(StandardError)

  belongs_to :sitting, class_name: "Scanner::Sitting", foreign_key: :scanner_sitting_id, inverse_of: :entries
  belongs_to :account
  belongs_to :printing, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id
  belongs_to :lot, optional: true

  scope :kept, -> { where(undone_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # :added, :undone, or :changed once its lot was removed or merged away (AC-1.5, AC-3.6).
  def state
    if undone_at then :undone
    elsif lot_id.nil? then :changed
    else :added
    end
  end

  # Takes this add's copy back out of the lot it went into, even if that lot was edited since (AC-4.1, AC-4.4), and
  # returns whether the lot went with it. Raises NotUndoable when it was undone already or its lot is gone (AC-4.2).
  def undo!
    transaction do
      reload
      raise NotUndoable, state.to_s unless state == :added

      lot = account.lots.find(lot_id)
      removed = lot.quantity <= 1
      removed ? lot.destroy! : lot.update!(quantity: lot.quantity - 1)
      update!(undone_at: Time.current)
      removed
    end
  end
end
```

- [ ] In `app/models/account.rb`, add after `has_many :lots, dependent: :delete_all`:

```ruby
  has_one :scanner_sitting, class_name: "Scanner::Sitting", dependent: :destroy
```

- [ ] Run `bin/rspec spec/models/scanner` and `bin/rails zeitwerk:check`. Expect 0 failures and "All is good!". Commit (migrations, `db/schema.rb`, models, specs): `feat(scanner): add the scanner sitting and its entries (009)`.

---

## Phase 4: Adding from the scanner, and reaching it

**Implements:** FR-1, FR-5, FR-6, Story 1, Story 3 (the list as it appears), Story 8, Story 6 (AC-6.5 marking) | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-1.7, AC-3.1, AC-3.2, AC-6.5 (marked button), AC-8.1, AC-8.2, AC-8.3, AC-8.4, NFR Security (validation, CSRF), NFR Accessibility (44 px)
**Files:** `config/routes.rb`, `app/controllers/concerns/scanner_sitting.rb`, `app/controllers/scanner/readings_controller.rb`, `app/controllers/scanner/sittings/entries_controller.rb`, `app/controllers/scanners_controller.rb`, `app/controllers/scanner/measurements_controller.rb`, `app/helpers/scanners_helper.rb`, `app/views/scanners/{_scanner,_result,_candidate,_add_buttons,_sitting,_sitting_entry,show}.html.erb`, `app/views/scanner/measurements/show.html.erb`, `app/views/layouts/{_appbar,_tabbar}.html.erb`, `app/views/collections/show.html.erb`, `app/views/icons/_scan.html.erb`, `app/javascript/controllers/{card_reader,scanner_reading}_controller.js`, `app/assets/stylesheets/collector/additions.css`, `docs/design-system/components/Scanner.md`, `spec/requests/scanner/{sitting_entries,readings}_spec.rb`, `spec/requests/scanners_spec.rb`, `spec/system/{scanner,scanner_adding}_spec.rb`
**Interfaces:** Consumes: Phase 3's `Scanner::Sitting.add!`, `Scanner::Sitting::KEY_FORMAT`/`SHOWN` and `SittingEntry#state`; Phase 2's `MTG::Reading#finish_hint` and `Candidate#collector_line?`. Produces:
- the routes `scanner_sitting_entries_path`, `scanner_sitting_entry_undo_path(entry)`, `new_scanner_sitting_ending_path` and `scanner_sitting_ending_path`
- `ScannerSitting#sitting_locals` and `#sitting_stream(message, alert:)`
- the helpers `scanner_finish(printing, finish)` and `scanner_copy(printing, finish)`
- the partials `scanners/_add_buttons` `(printing:, key:, finish_hint:, rank:)`, `scanners/_sitting` `(sitting:, entries:)`, `scanners/_sitting_entry` `(entry:)` and `scanners/_scanner` `(sitting:, entries:)`
- the readings request field `reading[key]`
- the add forms (`form.c-scanner__add` with `data-scanner-event="add"` and `data-rank`), the undo forms (`form.c-scanner__undo` with `data-scanner-event="undo"` and `data-reading-key`) and the details links (`a[data-scanner-event=details]` with `data-reading-key`)

- [ ] Write the contract spec `spec/requests/scanner/sitting_entries_spec.rb` (the add endpoint in `contracts/api.md`):

```ruby
require "rails_helper"

RSpec.describe "Scanner adds", type: :request do
  let(:user) { create(:user) }
  let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine") }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:printing) do
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
  end
  let(:key) { "a" * 32 }

  before { sign_in_as(user) }

  def add(finish: "foil", reading_key: key, to: printing.external_key)
    post scanner_sitting_entries_path, params: { entry: { printing: to, finish:, reading_key: } },
      headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
  end

  it "adds one copy, clears the reading, lists it and announces it (AC-1.2, AC-1.3, AC-3.1, AC-3.2)", :aggregate_failures do
    add
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to match(%r{<turbo-stream action="update" target="scanner_result"><template>\s*</template></turbo-stream>})
    expect(response.body).to include('<turbo-stream action="replace" target="scanner_sitting">', "This sitting: 1 card")
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123, Foil) to your collection.")
    expect(user.account.lots.sole).to have_attributes(entry: printing, finish: "foil", quantity: 1, condition: nil)
  end

  it "leaves the finish out of the message for a printing with none listed (AC-1.3)" do
    MTG::Printing.find_by!(catalog_entry_id: printing.id).update!(finishes: [])
    add(finish: "")
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123) to your collection.")
  end

  it "adds nothing for a reading already added, and answers as if it had just succeeded (AC-1.5)", :aggregate_failures do
    add
    add(finish: "nonfoil")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Added 1 × Lightning Bolt (MOM · 123, Foil) to your collection.")
    expect(user.account.lots.sum(:quantity)).to eq(1)
  end

  it "says so when the reading's add was undone, or its copy changed, adding nothing (AC-1.5)", :aggregate_failures do
    add
    Scanner::SittingEntry.sole.undo!
    add
    expect(response.body).to include("You added this card, then undid it. Scan it again to add it.")
    add(reading_key: "b" * 32)
    user.account.lots.sole.destroy!
    add(reading_key: "b" * 32)
    expect(response.body).to include("You added this card, and it has since changed in your collection.")
    expect(user.account.lots).to be_empty
  end

  it "refuses at the lot cap, adding nothing (AC-1.6)", :aggregate_failures do
    create(:lot, account: user.account, entry: printing, finish: "foil", quantity: Lot::MAX_QUANTITY)
    add
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("You already have the most copies one lot can hold (9,999).")
    expect(Scanner::SittingEntry.count).to eq(0)
  end

  it "refuses a missing or malformed key, an unknown or retired printing and a finish it doesn't come in (Error Scenarios)", :aggregate_failures do
    retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
    [ { reading_key: "" }, { reading_key: "XYZ" }, { to: "nope" }, { to: retired.external_key }, { finish: "etched" } ].each do |change|
      add(**change)
      expect(response).to have_http_status(:unprocessable_content), change.inspect
      expect(response.body).to include("That card couldn't be added. Scan it again.")
    end
    expect(user.account.lots).to be_empty
  end

  it "adds to the signed-in account's own sitting only (AC-3.8)", :aggregate_failures do
    other = create(:user).account
    Scanner::Sitting.add!(account: other, printing:, finish: "nonfoil", reading_key: key)
    add
    expect(other.lots.sole.finish).to eq("nonfoil")
    expect(user.account.scanner_sitting.entries.sole.finish).to eq("foil")
  end

  it "sends a signed-out visitor to sign in" do
    delete session_path
    add
    expect(response).to redirect_to(new_session_path)
  end
end
```

- [ ] In `spec/requests/scanner/readings_spec.rb`:
  - Add `let(:key) { "f" * 32 }`.
  - Change the helper to send the key:

```ruby
  def read(name_text, collector_text, key: self.key)
    post scanner_readings_path, params: { reading: { name_text:, collector_text:, key: } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end
```

  - Replace the example "offers no way to add a card, and links to the catalog search (AC-3.10)" with:

```ruby
    it "offers an add button per finish carrying the reading key, and no 'coming' note (AC-1.1, AC-8.4)", :aggregate_failures do
      read("Lightning Bolt", "R 0123\nMOM • EN")
      html = Nokogiri::HTML5(response.body)
      forms = html.css("form.c-scanner__add")
      expect(forms.map { it.at_css("input[name='entry[finish]']")["value"] }).to eq(%w[nonfoil foil])
      expect(forms.map { it.at_css("input[name='entry[reading_key]']")["value"] }.uniq).to eq([ key ])
      expect(forms.map { it["data-rank"] }).to eq(%w[1 1])
      expect(html.css("form.c-scanner__add button").map { it["aria-label"] })
        .to eq([ "Add Lightning Bolt MOM · 123 Nonfoil", "Add Lightning Bolt MOM · 123 Foil" ])
      expect(response.body).not_to include("Adding cards from the scanner is coming")
    end

    it "offers a single Add for a one-finish printing (AC-1.1)" do
      MTG::Printing.find_by!(catalog_entry_id: bolt.id).update!(finishes: %w[nonfoil])
      read("Lightning Bolt", "R 0123\nMOM • EN")
      expect(Nokogiri::HTML5(response.body).css("form.c-scanner__add button").map { it.text.strip }).to eq([ "Add" ])
    end

    it "marks the Foil button when the separator reads as the foil marker, adding nothing by itself (AC-6.5)", :aggregate_failures do
      read("Lightning Bolt", "R 0123\nMOM ★ EN")
      labels = Nokogiri::HTML5(response.body).css("form.c-scanner__add button").map { it.text.strip }
      expect(labels).to eq([ "Nonfoil", "Foil · read from the card" ])
      expect(Lot.count).to eq(0)
    end

    it "turns away a reading without a well-formed key" do
      read("Lightning Bolt", "", key: "nope")
      expect(response).to have_http_status(:unprocessable_content)
    end
```

- [ ] In `spec/requests/scanners_spec.rb`, replace the example "isn't linked from any page (AC-1.7)" with:

```ruby
    it "is linked from the main navigation and the collection page, marked current on the scanner (AC-8.1, AC-8.2)", :aggregate_failures do
      get collection_path
      html = Nokogiri::HTML5(response.body)
      expect(html.css(".c-appbar__nav a[href='#{scanner_path}']").map(&:text)).to eq([ "Scan" ])
      expect(html.css(".c-tabbar a[href='#{scanner_path}']").map { it.text.strip }).to eq([ "Scan" ])
      expect(html.css(".c-pagehead__actions a[href='#{scanner_path}']").map { it.text.strip }).to eq([ "Scan cards" ])
      get scanner_path
      html = Nokogiri::HTML5(response.body)
      expect(html.css(".c-appbar__nav a[aria-current=page]").map(&:text)).to eq([ "Scan" ])
      expect(html.css(".c-tabbar a[aria-current=page]").map { it.text.strip }).to eq([ "Scan" ])
    end
```

- [ ] In `spec/system/scanner_spec.rb`, change both `expect(scanner_sent).to eq([ [ "reading[name_text]", "reading[collector_text]" ] ])` lines to `expect(scanner_sent).to eq([ [ "reading[name_text]", "reading[collector_text]", "reading[key]" ] ])`.
- [ ] Write the failing system spec `spec/system/scanner_adding_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Adding from the scanner", type: :system do
  let(:user) { create(:user) }
  let(:foil_button) { "button[aria-label='Add Lightning Bolt MOM · 123 Foil']" }

  before do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(user)
    visit scanner_path
  end

  def read_card
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
  end

  it "adds with one tap and is ready for the next card, the camera still running (AC-1.1, AC-1.3)", :aggregate_failures do
    read_card
    page.execute_script("window.__marker = 'still here'")
    expect(page).to have_css(".c-scanner__add button", text: "Nonfoil").and have_css(".c-scanner__add button", text: "Foil")
    find(foil_button).click
    expect(page).to have_css("#status", text: "Added 1 × Lightning Bolt (MOM · 123, Foil) to your collection.")
    expect(page).to have_no_css(".c-scanner__candidate")
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 1 card")
    expect(page).to have_button("Capture", disabled: false)
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(page.evaluate_script("window.__tracks.length === 1 && window.__tracks[0].readyState === 'live'")).to be(true)
    expect(user.account.lots.sole.finish).to eq("foil")
  end

  it "adds one copy even when both buttons are tapped at once (AC-1.4, AC-1.5)", :aggregate_failures do
    read_card
    page.execute_script("document.querySelectorAll('.c-scanner__add button').forEach((button) => button.click())")
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 1 card")
    expect(user.account.lots.sum(:quantity)).to eq(1)
  end

  it "adds from a picked photo and offers the picker again (AC-1.3)", :aggregate_failures do
    wait_for_scanner
    pick_synthetic_photo
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
    find(foil_button).click
    expect(page).to have_css("#status", text: "Added 1 × Lightning Bolt")
    expect(page).to have_field("Use a photo", type: "file", visible: :all, disabled: false)
  end

  it "sends you to sign in when your session ended before the add (Error Scenarios)" do
    read_card
    page.driver.browser.manage.delete_cookie("session_id")
    find(foil_button).click
    expect(page).to have_button("Sign in")
  end

  it "keeps the reading and offers the retry when the add fails on the server (Error Scenarios)", :aggregate_failures do
    read_card
    page.execute_script("window.__marker = 'still here'")
    allow(Scanner::Sitting).to receive(:add!).and_raise(StandardError, "boom")
    find(foil_button).click
    expect(page).to have_css("#status", text: "That card wasn't added. Check your connection, then tap its add button again.")
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt")
    expect(page).to have_css("#{foil_button}:not([disabled])")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
  end
end
```

  (The test server runs in the spec's process, so the stub reaches the request; `show_exceptions` answers the error with a 500 page, which the controller keeps from replacing the scanner.)

- [ ] Run `bin/rspec spec/requests/scanner spec/requests/scanners_spec.rb spec/system/scanner_adding_spec.rb`. Expect failures (no route `scanner_sitting_entries_path`, no add buttons, no nav link).
- [ ] In `config/routes.rb`, replace the scanner block's head (the comment, `resource :scanner, only: :show`, and the opening of `namespace :scanner do` with its `resources :readings` line) with:

```ruby
  # The card scanner (spec 007; spec 009 adds the sitting and Other printings, and links it from the navigation).
  resource :scanner, only: :show
  namespace :scanner do
    resources :readings, only: :create
    resource :sitting, only: [] do
      resources :entries, only: :create, module: :sittings do
        resource :undo, only: :create, module: :entries
      end
      resource :ending, only: %i[new create], module: :sittings
    end
```

  Leave the measurement block as it is; Phases 6 and 8 add to the scanner namespace. Run `bin/rails routes -g scanner_sitting`. Expect `scanner_sitting_entries POST /scanner/sitting/entries`, `scanner_sitting_entry_undo POST /scanner/sitting/entries/:entry_id/undo`, `new_scanner_sitting_ending GET /scanner/sitting/ending/new` and `scanner_sitting_ending POST /scanner/sitting/ending`.
- [ ] Write `app/controllers/concerns/scanner_sitting.rb`:

```ruby
# The account's open scanner sitting as the scanner shows it (spec 009 Story 3): the sitting and its kept entries,
# newest first, loaded in the controller and handed to the partials; and the streams that redraw it after a change.
module ScannerSitting
  extend ActiveSupport::Concern

  private
    def sitting_locals(sitting = Current.account.scanner_sitting)
      { sitting:, entries: sitting ? sitting.kept_entries.to_a : [] }
    end

    def sitting_stream(message, alert: false)
      [ turbo_stream.replace("scanner_sitting", partial: "scanners/sitting", locals: sitting_locals),
        turbo_stream.update("status", partial: "shared/status_message", locals: { message:, alert: }) ]
    end
end
```

- [ ] Write `app/controllers/scanner/sittings/entries_controller.rb`:

```ruby
# Adds the scanned card: one copy of the chosen printing and finish, at most once per reading (spec 009 Story 1). Every
# answer is a Turbo Stream, so the scanner and its camera stay on the page (AC-1.3).
class Scanner::Sittings::EntriesController < ApplicationController
  include ScannerSitting

  NOT_ADDED = "That card couldn't be added. Scan it again.".freeze
  REPLAYED = {
    undone: "You added this card, then undid it. Scan it again to add it.",
    changed: "You added this card, and it has since changed in your collection."
  }.freeze

  def create
    attributes = params.expect(entry: %i[printing finish reading_key])
    printing = Catalog::Entry.includes(:set).find_by(external_key: attributes[:printing].to_s)
    added = Scanner::Sitting.add!(account: Current.account, printing:, finish: attributes[:finish], reading_key: attributes[:reading_key])
    render turbo_stream: [ result_stream(added.entry), *sitting_stream(message_for(added.entry), alert: added.entry.state != :added) ]
  rescue Scanner::Sitting::Refused
    refuse NOT_ADDED
  rescue ActiveRecord::RecordInvalid
    refuse Catalog::QuickAddsController::FULL_LOT
  end

  private
    def message_for(entry)
      return REPLAYED.fetch(entry.state) unless entry.state == :added

      "Added 1 × #{helpers.scanner_copy(entry.printing, entry.finish)} to your collection."
    end

    # The reading clears once its card is in (AC-1.3); a replay of an undone or changed add shows that instead, with no
    # add button (AC-1.5).
    def result_stream(entry)
      return turbo_stream.update("scanner_result", "") if entry.state == :added

      turbo_stream.update("scanner_result", partial: "shared/status_message", locals: { message: REPLAYED.fetch(entry.state), alert: true })
    end

    def refuse(message)
      render turbo_stream: turbo_stream.update("status", partial: "shared/status_message", locals: { message:, alert: true }),
        status: :unprocessable_content
    end
end
```

- [ ] Rewrite `app/controllers/scanner/readings_controller.rb`:

```ruby
# Turns the text read off a card into what the page shows (spec 007 Story 3): the candidates, each with an add button per
# finish for this reading (spec 009 Story 1). Only the text and the page's reading key arrive here; the photo never leaves
# the device (spec 007 FR-3, spec 009 FR-5).
class Scanner::ReadingsController < ApplicationController
  TOO_LONG = "That reading was too long to use. Line the card up with the guide and capture it again.".freeze
  NO_KEY = "That reading couldn't be used. Capture the card again.".freeze

  def create
    attributes = params.expect(reading: %i[name_text collector_text key])
    reading = MTG::Reading.new(attributes.slice(:name_text, :collector_text))
    key = attributes[:key].to_s
    if !Scanner::Sitting::KEY_FORMAT.match?(key) then refuse(NO_KEY)
    elsif reading.valid?
      render turbo_stream: turbo_stream.update("scanner_result", partial: "scanners/result", locals: { reading: reading.resolve, key: })
    else refuse(TOO_LONG)
    end
  end

  private
    def refuse(message)
      render turbo_stream: turbo_stream.update("scanner_result", partial: "shared/status_message", locals: { message:, alert: true }),
        status: :unprocessable_content
    end
end
```

- [ ] Rewrite `app/controllers/scanners_controller.rb`:

```ruby
# The card scanner page (spec 007 Stories 1–4, spec 009): a live camera with the card guide, on-device OCR, the candidate
# printings with their add buttons, and the account's open sitting.
class ScannersController < ApplicationController
  include ScannerPage
  include ScannerSitting

  def show
    @sitting = sitting_locals
  end
end
```

- [ ] In `app/controllers/scanner/measurements_controller.rb`, add `include ScannerSitting` after `include ScannerPage`, and make `show`'s first line `@sitting = sitting_locals`.
- [ ] Add to `app/helpers/scanners_helper.rb`, inside the module:

```ruby
  def scanner_finish(printing, finish) = finish && Catalog.collecting_for(printing.collectible_type).finish_label(finish)

  # "Tome Shredder (STX · 117, Foil)": a scanner add's card, printing and finish (spec 009 AC-1.3, AC-4.1).
  def scanner_copy(printing, finish) = "#{printing.name} (#{[ set_number(printing), scanner_finish(printing, finish) ].compact.join(", ")})"
```

- [ ] Use the `collector-design-system` skill, then write `app/views/scanners/_add_buttons.html.erb`:

```erb
<%# locals: (printing:, key:, finish_hint:, rank:) %>
<%# One add button per finish the printing comes in; a single "Add" for one finish or none listed (spec 009 AC-1.1).
    The foil marker read off the card marks its button's visible label and nothing more (AC-6.5); the accessible name
    stays "Add ‹card› ‹SET · number› ‹finish›", so it never depends on how the separator was read. %>
<% vocabulary = Catalog.collecting_for(printing.collectible_type) %>
<% finishes = vocabulary.finishes_for(printing).presence || [ nil ] %>
<div class="c-scanner__adds">
  <% finishes.each do |finish| %>
    <% name = finish && vocabulary.finish_label(finish) %>
    <% hinted = finish.present? && finish == finish_hint %>
    <% label = hinted ? "#{name} · read from the card" : (finishes.one? ? "Add" : name) %>
    <%= button_to scanner_sitting_entries_path, params: { entry: { printing: printing.external_key, finish: finish.to_s, reading_key: key } },
          class: "c-btn c-btn--secondary c-btn--sm", form: { class: "c-scanner__add", data: { scanner_event: "add", rank: } },
          "aria-label": [ "Add", printing.name, set_number(printing), name ].compact.join(" ") do %>
      <%= render "icons/plus" %><%= label %>
    <% end %>
  <% end %>
</div>
```

- [ ] Rewrite `app/views/scanners/_candidate.html.erb` (Phase 2's version plus the add buttons):

```erb
<%# locals: (candidate:, reading:, key:, rank:) %>
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
  <% if candidate.collector_line? %>
    <span class="c-badge c-badge--success"><%= render "icons/check" %><%= candidate.corrected? ? "Matched by its collector line, one digit corrected" : "Matched by its collector line" %></span>
  <% else %>
    <span class="c-badge c-badge--warning"><%= render "icons/alert" %>Printing not confirmed</span>
  <% end %>
  <% if candidate.name? %><span class="c-scanner__evidence">Matched by its name</span><% end %>
  <%= render "scanners/add_buttons", printing: entry, key:, finish_hint: reading.finish_hint, rank: %>
</div>
```

- [ ] Rewrite `app/views/scanners/_result.html.erb`:

```erb
<%# locals: (reading:, key:) %>
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
      <div class="c-grid">
        <% reading.candidates.each.with_index(1) do |candidate, rank| %>
          <%= render "scanners/candidate", candidate:, reading:, key:, rank: %>
        <% end %>
      </div>
    <% end %>
  </section>
<% end %>
```

- [ ] Write `app/views/scanners/_sitting.html.erb`:

```erb
<%# locals: (sitting:, entries:) %>
<%# The open sitting's adds, newest first: the 10 newest, the rest behind "Show all" (spec 009 AC-3.2). Always present,
    so an add's Turbo Stream can replace it; hidden while there's no sitting (AC-3.7). %>
<% if sitting %>
  <section id="scanner_sitting" class="c-scanner__sitting" aria-labelledby="scanner-sitting-heading">
    <div class="c-section__head">
      <h2 class="c-section__title" id="scanner-sitting-heading">This sitting: <%= pluralize(entries.size, "card") %></h2>
      <span class="c-section__actions"><%= link_to "Done", new_scanner_sitting_ending_path, class: "c-btn c-btn--secondary c-btn--sm" %></span>
    </div>
    <% if entries.empty? %>
      <p class="c-empty">Everything added in this sitting was undone.</p>
    <% else %>
      <ul class="c-list"><%= render partial: "scanners/sitting_entry", collection: entries.first(Scanner::Sitting::SHOWN), as: :entry %></ul>
      <% if entries.size > Scanner::Sitting::SHOWN %>
        <details class="c-scanner__more">
          <summary class="c-btn c-btn--ghost c-btn--sm">Show all <%= entries.size %></summary>
          <ul class="c-list"><%= render partial: "scanners/sitting_entry", collection: entries.drop(Scanner::Sitting::SHOWN), as: :entry %></ul>
        </details>
      <% end %>
    <% end %>
  </section>
<% else %>
  <section id="scanner_sitting" hidden></section>
<% end %>
```

- [ ] Write `app/views/scanners/_sitting_entry.html.erb`:

```erb
<%# locals: (entry:) %>
<% copy = scanner_copy(entry.printing, entry.finish) %>
<li>
  <span><%= entry.printing.name %></span>
  <span class="c-list__meta"><%= set_number(entry.printing) %> · <%= scanner_finish(entry.printing, entry.finish) || "—" %> · Added <%= time_tag entry.created_at, "#{time_ago_in_words(entry.created_at)} ago" %></span>
  <span class="c-list__end c-scanner__entry-actions">
    <% if entry.state == :changed %>
      <span class="c-tag">Changed in your collection</span>
    <% else %>
      <%= link_to "Details", edit_lot_path(entry.lot_id, return_to: scanner_path), class: "c-btn c-btn--ghost c-btn--sm",
            "aria-label": "Details of #{copy}", data: { scanner_event: "details", reading_key: entry.reading_key, turbo_prefetch: false } %>
      <%= button_to "Undo", scanner_sitting_entry_undo_path(entry), class: "c-btn c-btn--secondary c-btn--sm", "aria-label": "Undo #{copy}",
            form: { class: "c-scanner__undo", data: { scanner_event: "undo", reading_key: entry.reading_key } } %>
    <% end %>
  </span>
</li>
```

- [ ] Rewrite `app/views/scanners/_scanner.html.erb`:

```erb
<%# locals: (sitting:, entries:) %>
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
  <div id="scanner_result" class="c-scanner__result" data-card-reader-target="result" data-controller="scanner-reading"
       data-action="turbo:submit-start->scanner-reading#lock turbo:submit-end->scanner-reading#unlock turbo:before-fetch-response->scanner-reading#inspect turbo:frame-missing->scanner-reading#printingsMissing turbo:fetch-request-error->scanner-reading#printingsErrored turbo:frame-load->scanner-reading#printingsLoaded"></div>
  <%= render "scanners/sitting", sitting:, entries: %>
  <noscript><p class="c-status__message c-status__message--alert">The scanner needs JavaScript. <%= link_to "Search the catalog", catalog_entries_path %> instead.</p></noscript>
</div>
```

- [ ] In `app/views/scanners/show.html.erb` and `app/views/scanner/measurements/show.html.erb`, change `<%= render "scanners/scanner" %>` to `<%= render "scanners/scanner", **@sitting %>`.
- [ ] Write `app/javascript/controllers/scanner_reading_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

// Holds a reading's add buttons while one of its adds is in flight, so one reading adds one copy (spec 009 AC-1.4). The
// answer clears the reading when the add goes through; a refusal hands the buttons back. An add that fails on the network
// or the server keeps the reading and says so, and its button is the retry: the same reading key makes a retry safe
// (AC-1.5, Error Scenarios). Other printings that fail to load say so in place, and opening them is announced (NFR
// Accessibility).
const ADD_FAILED = "That card wasn't added. Check your connection, then tap its add button again."
const PRINTINGS_FAILED = "Other printings couldn't be loaded. Tap “Other printings” again."

export default class extends Controller {
  lock({ target }) {
    if (target.matches(".c-scanner__add")) this.buttons.forEach((button) => { button.disabled = true })
  }

  // success is undefined when Turbo cancelled this submission for a newer one, which is still in flight: keep the lock.
  unlock({ target, detail: { success, error } }) {
    if (!target.matches(".c-scanner__add")) return
    if (error) this.announce(ADD_FAILED, { alert: true })
    if (success === false) this.buttons.forEach((button) => { button.disabled = false })
  }

  // A server error's HTML page would otherwise replace the scanner, camera and all.
  inspect(event) {
    if (!event.target.matches?.(".c-scanner__add") || !event.detail.fetchResponse.serverError) return
    event.preventDefault()
    this.announce(ADD_FAILED, { alert: true })
  }

  printingsMissing(event) {
    if (event.target.id !== "scanner_printings") return
    event.preventDefault()
    this.printingsFailed(event.target)
  }

  printingsErrored({ target }) {
    if (target.id === "scanner_printings") this.printingsFailed(target)
  }

  printingsLoaded({ target }) {
    const heading = target.id === "scanner_printings" && target.querySelector("h2")
    if (heading) this.announce(`${heading.textContent} are below.`)
  }

  printingsFailed(frame) {
    frame.replaceChildren(this.message(PRINTINGS_FAILED, { alert: true }))
    this.announce(PRINTINGS_FAILED, { alert: true })
  }

  announce(text, { alert = false } = {}) {
    document.getElementById("status")?.replaceChildren(this.message(text, { alert }))
  }

  message(text, { alert }) {
    return Object.assign(document.createElement("p"), { className: `c-status__message${alert ? " c-status__message--alert" : ""}`, textContent: text })
  }

  get buttons() {
    return this.element.querySelectorAll(".c-scanner__add button")
  }
}
```

  (Turbo answers `turbo:submit-end` with `success: false, error` after a network failure, with `success: false` after a 4xx answer or a prevented server error, and with `success` undefined when a newer submission cancelled this one. `turbo:frame-missing`, `turbo:fetch-request-error` and `turbo:frame-load` bubble from the frame.)

- [ ] In `app/javascript/controllers/card_reader_controller.js`:
  1. Replace the line `      const reading = await readStrips(this.enginePathValue, strips)` with `      const reading = { ...(await readStrips(this.enginePathValue, strips)), key: readingKey() }`.
  2. Replace `  async send({ nameText, collectorText }) {` with `  async send({ nameText, collectorText, key }) {`.
  3. After `body.append("reading[collector_text]", collectorText)`, add `    body.append("reading[key]", key)`.
  4. Change the header comment's last sentence to `Dispatches card-reader:read ({ nameText, collectorText, ms, key, strips }) for measurement mode.`
  5. Append at the end of the file:

```js
// An opaque key for one reading (spec 009 AC-1.5): random, never derived from the text. getRandomValues also works where
// the page isn't a secure context (the photo path over plain HTTP), unlike randomUUID.
function readingKey() {
  return Array.from(crypto.getRandomValues(new Uint8Array(16)), (byte) => byte.toString(16).padStart(2, "0")).join("")
}
```

- [ ] Write `app/views/icons/_scan.html.erb`:

```erb
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3"/><rect x="9" y="7.5" width="6" height="9" rx="1"/></svg>
```

- [ ] In `app/views/layouts/_appbar.html.erb`, after the Search link inside `.c-appbar__nav`, add `      <%= link_to "Scan", scanner_path, "aria-current": ("page" if section == :scanner) %>`. In `app/views/layouts/_tabbar.html.erb`, after the Search tab, add:

```erb
    <%= link_to scanner_path, "aria-current": ("page" if section == :scanner) do %><span class="c-tabbar__icon"><%= render "icons/scan" %></span>Scan<% end %>
```

- [ ] In `app/views/collections/show.html.erb`, replace the `c-pagehead__actions` div with:

```erb
    <div class="c-pagehead__actions"><%= link_to scanner_path, class: "c-btn c-btn--secondary" do %><%= render "icons/scan" %>Scan cards<% end %><%= link_to catalog_entries_path, class: "c-btn c-btn--primary" do %><%= render "icons/plus" %>Add items<% end %></div>
```

- [ ] Append to `app/assets/stylesheets/collector/additions.css`:

```css
.c-scanner__adds { display:flex; flex-wrap:wrap; gap:var(--space-2); }
.c-scanner__add, .c-scanner__undo { margin:0; }
.c-scanner__add .c-btn, .c-scanner__undo .c-btn, .c-scanner__sitting .c-btn { min-height:44px; min-width:44px; }
.c-scanner__sitting .c-list li { flex-wrap:wrap; }
.c-scanner__entry-actions { display:flex; gap:var(--space-2); font-family:var(--font-sans); }
.c-scanner__more > summary { list-style:none; width:max-content; margin-top:var(--space-2); }
.c-scanner__more > summary::-webkit-details-marker { display:none; }
```

- [ ] Run `bin/rspec spec/requests/scanner spec/requests/scanners_spec.rb spec/system/scanner_spec.rb spec/system/scanner_adding_spec.rb`. Expect 0 failures. Then run `bin/rspec`; expect 0 failures (pages that assert nav link counts are updated here if any fail).
- [ ] Add to `docs/design-system/components/Scanner.md`, after the "Candidates are `ItemTile`s…" bullet, replacing that bullet:

```markdown
- Candidates are `ItemTile`s. Each says what it was matched by: a `c-badge--success` with a check, "Matched by its collector line" (or "…, one digit corrected"), or a `c-badge--warning` with the alert icon, "Printing not confirmed"; "Matched by its name" follows in muted text (spec 009 AC-2.1, AC-5.1).
- Under each candidate, `.c-scanner__adds` holds one `button_to` per finish (`form.c-scanner__add`, `c-btn--secondary c-btn--sm`, at least 44px): the finish's name, or "Add" for a printing with one finish or none. The accessible name says exactly what is added: "Add Lightning Bolt MOM · 123 Foil". A foil marker read off the card relabels the Foil button "Foil · read from the card" and chooses nothing (AC-6.5).
- After an add, the reading clears and `#status` announces "Added 1 × Lightning Bolt (MOM · 123, Foil) to your collection."; the camera keeps running.
- The open sitting (`#scanner_sitting`, `.c-scanner__sitting`) follows the result: a `c-section__head` "This sitting: N cards" with a "Done" button, then a `c-list` of adds, newest first (name; set · number, finish or "—", "Added … ago"; "Details" and "Undo"). Ten show; the rest sit in a `details.c-scanner__more` whose summary is "Show all N". An add whose lot was removed or merged away shows a `c-tag` "Changed in your collection" instead of its actions.
```

- [ ] Commit: `feat(scanner): add the scanned card from its candidate, and link the scanner (009)`.

---

## Phase 5: Undo, details, Done and the summary

**Implements:** FR-2 (tenancy, discard), Stories 3–4 | **Satisfies:** AC-3.3, AC-3.4, AC-3.5, AC-3.6, AC-3.7, AC-3.8, AC-4.1, AC-4.2, AC-4.3, AC-4.4, Error Scenarios (Undo on an ended sitting, another account's entry, Done with nothing kept, Done by mistake), NFR Accessibility (360 px)
**Files:** `app/controllers/scanner/sittings/entries/undos_controller.rb`, `app/controllers/scanner/sittings/endings_controller.rb`, `app/views/scanner/sittings/endings/new.html.erb`, `app/views/scanners/_summary.html.erb`, `app/views/scanners/_scanner.html.erb`, `app/views/scanners/show.html.erb`, `app/controllers/scanners_controller.rb`, `spec/requests/scanner/sittings_spec.rb`, `spec/system/scanner_sitting_spec.rb`, `docs/design-system/components/Scanner.md`
**Interfaces:** Consumes: Phase 3's `SittingEntry#undo!` and `Sitting#end!`; Phase 4's routes, `ScannerSitting` and partials; `BulkRemoval.supersede!(session)`. Produces: the flash key `:sitting_summary` (an Integer) and `scanners/_scanner` locals `(sitting:, entries:, summary: nil)`.

- [ ] Write the contract spec `spec/requests/scanner/sittings_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Scanner sittings", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine") }
  let(:printing) do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
  end
  let(:stream) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

  before { sign_in_as(user) }

  def add(key, finish: "foil", to: account, card: printing) = Scanner::Sitting.add!(account: to, printing: card, finish:, reading_key: key * 32).entry
  def html = Nokogiri::HTML5(response.body)
  def undo(entry) = post(scanner_sitting_entry_undo_path(entry), headers: stream)

  describe "the list on the scanner" do
    it "lists the adds newest first, with the count, finish, time, Undo and the copy's details (AC-3.2, AC-3.4)", :aggregate_failures do
      plain = create(:mtg_printing, finishes: [], entry: create(:catalog_entry, name: "Opt", set: mom, number: "7")).entry
      first = add("a", finish: "nonfoil")
      add("b")
      add("c", finish: "", card: plain)
      get scanner_path
      expect(html.at_css("#scanner_sitting h2").text).to eq("This sitting: 3 cards")
      rows = html.css("#scanner_sitting > ul > li")
      expect(rows.map { it.at_css(".c-list__meta").text.squish })
        .to match([ /\AMOM · 7 · — · Added .+ ago\z/, /\AMOM · 123 · Foil · Added .+ ago\z/, /\AMOM · 123 · Nonfoil · Added .+ ago\z/ ])
      expect(rows.last.at_css("a[data-scanner-event=details]")["href"]).to eq(edit_lot_path(first.lot_id, return_to: scanner_path))
      expect(rows.last.at_css("form.c-scanner__undo")["action"]).to eq(scanner_sitting_entry_undo_path(first))
      expect(html.at_css("#scanner_sitting a[href='#{new_scanner_sitting_ending_path}']").text).to eq("Done")
    end

    it "shows the 10 newest and the rest behind Show all (AC-3.2)", :aggregate_failures do
      ("a".."l").each { add(it) }
      get scanner_path
      expect(html.css("#scanner_sitting > ul > li").size).to eq(10)
      expect(html.at_css("#scanner_sitting details summary").text.strip).to eq("Show all 12")
      expect(html.css("#scanner_sitting details li").size).to eq(2)
    end

    it "shows no list or Done without a sitting (AC-3.7)", :aggregate_failures do
      get scanner_path
      expect(html.at_css("#scanner_sitting")["hidden"]).not_to be_nil
      expect(response.body).not_to include(new_scanner_sitting_ending_path)
    end

    it "marks an add whose lot went, with no Undo or details (AC-3.6)", :aggregate_failures do
      add("a")
      account.lots.sole.destroy!
      get scanner_path
      row = html.at_css("#scanner_sitting li")
      expect(row.text).to include("Changed in your collection")
      expect(row.css("form, a")).to be_empty
    end

    it "keeps each account's sitting to itself (AC-3.8)", :aggregate_failures do
      theirs = add("z", to: create(:user).account)
      get scanner_path
      expect(html.at_css("#scanner_sitting")["hidden"]).not_to be_nil
      undo(theirs)
      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.state).to eq(:added)
    end
  end

  describe "Undo" do
    it "takes one copy back in place and says so (AC-4.1)", :aggregate_failures do
      add("a")
      undo(add("b"))
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.", "This sitting: 1 card")
      expect(account.lots.sole.quantity).to eq(1)
    end

    it "ends the session's pending bulk Undo when the lot goes (AC-4.1, spec 006 AC-7.6)" do
      removal = BulkRemoval.create!(session: Session.sole, account:, copies: 1, lots_data: [ { "catalog_entry_id" => printing.id, "quantity" => 1 } ])
      undo(add("a"))
      expect(removal.reload).not_to be_undoable
    end

    it "refuses an add already undone, or whose copy changed (AC-4.2, AC-4.4)", :aggregate_failures do
      entry = add("a")
      undo(entry)
      undo(entry)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("That card was already undone.")
      changed = add("b")
      account.lots.sole.destroy!
      undo(changed)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("That copy has changed in your collection, so it can't be undone here.")
    end

    it "answers 404 once the sitting has ended (Error Scenarios)" do
      entry = add("a")
      account.scanner_sitting.end!
      undo(entry)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Done" do
    it "asks first, then ends the sitting with a one-time summary (AC-3.5, AC-3.7)", :aggregate_failures do
      add("a")
      add("b").undo!
      get new_scanner_sitting_ending_path
      expect(html.at_css("h1").text).to eq("End this sitting?")
      expect(response.body).to include("You added 1 card in this sitting.")
      post scanner_sitting_ending_path
      expect(response).to redirect_to(scanner_path)
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(html.at_css("#scanner_sitting").text.squish).to include("Added 1 card in this sitting")
      expect(html.at_css("#scanner_sitting a[href='#{collection_path}']")).not_to be_nil
      get scanner_path
      expect(response.body).not_to include("Added 1 card in this sitting")
      expect([ Scanner::Sitting.count, account.lots.sum(:quantity) ]).to eq([ 0, 1 ])
    end

    it "says 0 when every add was undone (Error Scenarios)" do
      add("a").undo!
      post scanner_sitting_ending_path
      follow_redirect!
      expect(response.body).to include("Added 0 cards in this sitting")
    end

    it "goes back to the scanner without a sitting to end", :aggregate_failures do
      get new_scanner_sitting_ending_path
      expect(response).to redirect_to(scanner_path)
      post scanner_sitting_ending_path
      follow_redirect!
      expect(response.body).not_to include("in this sitting")
    end
  end

  it "returns to the scanner from the copy's Edit copy page (AC-3.4)" do
    entry = add("a")
    patch lot_path(entry.lot_id, return_to: scanner_path), params: { lot: { quantity: "1", finish: "foil", condition: "near_mint", price_paid: "" } }
    expect(response).to redirect_to(scanner_path)
  end
end
```

- [ ] Write the failing system spec `spec/system/scanner_sitting_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "The scanner's sitting", type: :system do
  let(:user) { create(:user) }
  let(:printing) do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
  end

  before do
    printing
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(user)
  end

  def add_by_scanning
    show_synthetic_card
    click_on "Capture"
    find("button[aria-label='Add Lightning Bolt MOM · 123 Foil']", wait: 30).click
  end

  it "survives signing out and resumes on the scanner, taking further adds (AC-3.3)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 1 card")
    visit more_path
    click_on "Sign out"
    system_sign_in_as(user)
    visit scanner_path
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 1 card")
    add_by_scanning
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 2 cards")
  end

  it "undoes an add in place, the camera still running (AC-4.1)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    page.execute_script("window.__marker = 'still here'")
    click_on "Undo"
    expect(page).to have_css("#status", text: "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(user.account.lots).to be_empty
  end

  it "fits a 360px screen with a long sitting, never scrolling sideways (NFR Accessibility)", :aggregate_failures do
    ("a".."l").each { Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: it * 32) }
    visit collection_path
    expect(open_in_narrow_frame(scanner_path, width: 360, ready: ".c-scanner__stage:not([hidden])")).to eq([ 360, true ])
    within_narrow_frame do
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 360
      expect(page.evaluate_script(%(document.querySelector(".c-scanner__shutter").getBoundingClientRect().top))).to be >= 800 * 2 / 3
    end
  end
end
```

- [ ] Run `bin/rspec spec/requests/scanner/sittings_spec.rb spec/system/scanner_sitting_spec.rb`. Expect failures (`uninitialized constant Scanner::Sittings::Entries::UndosController` and the endings controller).
- [ ] Write `app/controllers/scanner/sittings/entries/undos_controller.rb`:

```ruby
# Undoes one add of the open sitting: its copy leaves the lot it went into (spec 009 Story 4). A Turbo Stream answer keeps
# the scanner on the page; another account's entry, or one of a sitting that has ended, is not found (AC-3.8).
class Scanner::Sittings::Entries::UndosController < ApplicationController
  include ScannerSitting

  REFUSED = {
    "undone" => "That card was already undone.",
    "changed" => "That copy has changed in your collection, so it can't be undone here."
  }.freeze

  def create
    entry = Current.account.scanner_sitting&.entries&.includes(printing: :set)&.find_by(id: params[:entry_id])
    return head(:not_found) unless entry

    copy = helpers.scanner_copy(entry.printing, entry.finish)
    BulkRemoval.supersede!(Current.session) if entry.undo!
    render turbo_stream: sitting_stream("Removed 1 × #{copy} from your collection.")
  rescue Scanner::SittingEntry::NotUndoable => error
    render turbo_stream: sitting_stream(REFUSED.fetch(error.message), alert: true), status: :unprocessable_content
  end
end
```

- [ ] Write `app/controllers/scanner/sittings/endings_controller.rb`:

```ruby
# Ends the account's scanner sitting after a confirmation page (spec 009 AC-3.5): the copies stay, the list goes, and the
# scanner shows a one-time summary of how many cards the sitting added. The summary rides in the flash and isn't stored.
class Scanner::Sittings::EndingsController < ApplicationController
  def new
    sitting = Current.account.scanner_sitting
    return redirect_to(scanner_path) unless sitting

    @count = sitting.entries.kept.count
  end

  def create
    sitting = Current.account.scanner_sitting
    flash[:sitting_summary] = sitting.end! if sitting
    redirect_to scanner_path, status: :see_other
  end
end
```

- [ ] Use the `collector-design-system` skill (ConfirmPage), then write `app/views/scanner/sittings/endings/new.html.erb`. The form is non-Turbo: the scanner's reload meta would otherwise load the page twice and lose the one-time summary.

```erb
<% content_for :title, "End this sitting? · Collector" %>
<%= render "layouts/appbar", section: :scanner, detail: true, back_path: scanner_path %>
<main class="c-main c-page">
  <section class="c-confirm">
    <h1 class="c-pagehead__title">End this sitting?</h1>
    <p>You added <%= pluralize(@count, "card") %> in this sitting. They stay in your collection; the list of adds and its Undo buttons go.</p>
    <div class="c-form__actions">
      <%= button_to "End sitting", scanner_sitting_ending_path, class: "c-btn c-btn--danger", form: { data: { turbo: false } } %>
      <%= link_to "Cancel", scanner_path, class: "c-btn c-btn--secondary" %>
    </div>
  </section>
</main>
<%= render "layouts/tabbar", section: :scanner %>
```

- [ ] Write `app/views/scanners/_summary.html.erb`:

```erb
<%# locals: (count:) %>
<%# Shown once, in the response to Done, in place of the list (spec 009 AC-3.5). The next add replaces it with a new sitting. %>
<section id="scanner_sitting" class="c-scanner__sitting">
  <p class="c-status__message">Added <%= pluralize(count, "card") %> in this sitting. <%= link_to "Open your collection", collection_path %></p>
</section>
```

- [ ] In `app/views/scanners/_scanner.html.erb`, change the locals line to `<%# locals: (sitting:, entries:, summary: nil) %>` and replace `<%= render "scanners/sitting", sitting:, entries: %>` with:

```erb
  <% if summary %>
    <%= render "scanners/summary", count: summary %>
  <% else %>
    <%= render "scanners/sitting", sitting:, entries: %>
  <% end %>
```

- [ ] In `app/controllers/scanners_controller.rb`, make `show`:

```ruby
  def show
    @sitting = sitting_locals
    @summary = flash[:sitting_summary]
  end
```

  In `app/views/scanners/show.html.erb`, change the render to `<%= render "scanners/scanner", **@sitting, summary: @summary %>`.
- [ ] Run `bin/rspec spec/requests/scanner spec/system/scanner_sitting_spec.rb spec/system/scanner_adding_spec.rb`. Expect 0 failures.
- [ ] Add to `docs/design-system/components/Scanner.md`, after the sitting bullet:

```markdown
- "Undo" (`form.c-scanner__undo`) takes the add's copy back in place and `#status` announces "Removed 1 × … from your collection.". "Details" opens the copy's Edit copy page and returns to the scanner.
- "Done" opens a `ConfirmPage` ("End this sitting?", the count kept, `c-btn--danger` "End sitting", whose form is non-Turbo). The scanner then shows the one-time summary ("Added N cards in this sitting", a `c-status__message` with a link to the collection) in place of the list.
```

- [ ] Commit: `feat(scanner): undo an add, edit its copy and end the sitting (009)`.

---

## Phase 6: Other printings

**Implements:** Story 2, FR-1 | **Satisfies:** AC-2.1 ("Other printings" on every candidate), AC-2.2, AC-2.3, AC-2.4, AC-2.5, AC-2.6, NFR Performance (structure for the 300 ms target)
**Files:** `app/models/scanner/other_printings.rb`, `app/controllers/scanner/printings_controller.rb`, `app/views/scanner/printings/{index,_printing}.html.erb`, `app/views/scanners/{_candidate,_result}.html.erb`, `config/routes.rb`, `app/assets/stylesheets/collector/additions.css`, `spec/models/scanner/other_printings_spec.rb`, `spec/requests/scanner/printings_spec.rb`, `spec/requests/scanner/readings_spec.rb`, `spec/system/scanner_adding_spec.rb`, `docs/design-system/components/Scanner.md`
**Interfaces:** Consumes: Phase 4's `scanners/_add_buttons` and `Scanner::Sitting::KEY_FORMAT`. Produces: `Scanner::OtherPrintings.new(identity:, set_code:, number:)` with `#entries`, `#shown` and `#rest` (`SHOWN = 20`); the route `scanner_printings_path(card:, key:, set:, number:, finish_hint:)`; the frame `turbo-frame#scanner_printings`.

- [ ] Write the failing spec `spec/models/scanner/other_printings_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Scanner::OtherPrintings, type: :model do
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let!(:magic_2010) { printing("m10", "146", Date.new(2009, 7, 17)) }
  let!(:magic_2011) { printing("m11", "149", Date.new(2010, 7, 16)) }
  let!(:magic_2011_same_number) { printing("m11", "146", Date.new(2010, 7, 16)) }
  let!(:masters_25) { printing("a25", "141", Date.new(2018, 3, 16)) }

  before do
    printing("m25", "1", Date.new(2025, 1, 1), retired: true)
    printing("m10", "146", Date.new(2009, 7, 17), language: "ja")
  end

  def printing(set_code, number, released_on, language: "en", retired: false)
    set = Catalog::Set.find_by(collectible_type: "mtg", code: set_code) || create(:catalog_set, code: set_code, released_on:)
    create(:catalog_entry, identity:, set:, number:, language:, released_on:, retired_at: (1.day.ago if retired))
  end

  def entries(set: nil, number: nil) = described_class.new(identity:, set_code: set, number:).entries

  it "puts the read set and number first, then the set, then the number, then the rest (AC-2.3)" do
    expect(entries(set: "M11", number: "0146")).to eq([ magic_2011_same_number, magic_2011, magic_2010, masters_25 ])
  end

  it "lists newest first when nothing was read, leaving out retired and other-language printings (AC-2.2, AC-2.4)" do
    expect(entries).to eq([ masters_25, magic_2011_same_number, magic_2011, magic_2010 ])
  end

  it "shows 20 and keeps the rest (AC-2.5)", :aggregate_failures do
    22.times { printing("x#{it}", "1", Date.new(2000, 1, 1)) }
    other = described_class.new(identity:)
    expect([ other.shown.size, other.rest.size ]).to eq([ 20, 6 ])
  end
end
```

- [ ] Run `bin/rspec spec/models/scanner/other_printings_spec.rb`. Expect it to FAIL (`uninitialized constant Scanner::OtherPrintings`).
- [ ] Write `app/models/scanner/other_printings.rb`:

```ruby
# A card's English printings for "Other printings" on the scanner (spec 009 Story 2), retired ones left out. Those matching
# what was read come first (set and number, then set, then number), each group in the catalog's newest-first order.
class Scanner::OtherPrintings
  SHOWN = 20

  def self.plain_number(number) = number.to_s.sub(/\A0+(?=\d)/, "").downcase.presence

  def initialize(identity:, set_code: nil, number: nil)
    @identity = identity
    @set_code = set_code.to_s.downcase.presence
    @number = self.class.plain_number(number)
  end

  def entries
    @entries ||= begin
      all = Catalog::Entry.searchable.where(catalog_identity_id: @identity.id, language: "en").newest_first.includes(:set).to_a
      Catalog::Entry.preload_extensions(all)
      all.each_with_index.sort_by { |entry, index| [ group(entry), index ] }.map(&:first)
    end
  end

  def shown = entries.first(SHOWN)

  def rest = entries.drop(SHOWN)

  private
    def group(entry)
      set = @set_code && entry.set.code.casecmp?(@set_code)
      number = @number && self.class.plain_number(entry.number) == @number
      if set && number then 0
      elsif set then 1
      elsif number then 2
      else 3
      end
    end
end
```

- [ ] Run `bin/rspec spec/models/scanner/other_printings_spec.rb`. Expect 3 examples, 0 failures.
- [ ] Write the contract spec `spec/requests/scanner/printings_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Scanner other printings", type: :request do
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:key) { "c" * 32 }

  before do
    sign_in_as(create(:user))
    { "m10" => Date.new(2009, 7, 17), "m11" => Date.new(2010, 7, 16) }.each do |code, released_on|
      set = create(:catalog_set, code:, name: "Set #{code}", released_on:)
      create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set:, number: "146", released_on:))
    end
  end

  def other_printings(**params)
    get scanner_printings_path(card: identity.external_key, key:, **params), headers: { "Turbo-Frame" => "scanner_printings" }
  end

  it "answers the frame with the card's printings, each with add buttons for the same reading (AC-2.2, AC-2.6)", :aggregate_failures do
    other_printings(set: "m10", number: "146")
    frame = Nokogiri::HTML5(response.body).at_css("turbo-frame#scanner_printings")
    expect(frame.at_css("h2").text).to eq("Other printings of Lightning Bolt")
    expect(frame.css("li .is-data").map(&:text)).to eq([ "M10 · 146", "M11 · 146" ])
    expect(frame.css("li .c-list__meta").first.text).to include("Set m10", "17 July 2009")
    expect(frame.css("input[name='entry[reading_key]']").map { it["value"] }.uniq).to eq([ key ])
    expect(frame.css("form.c-scanner__add").map { it["data-rank"] }.uniq).to eq([ "other" ])
    expect(response.body).not_to include("turbo-visit-control")
  end

  it "marks the Foil buttons when the reading suggested foil (AC-6.5)" do
    other_printings(finish_hint: "foil")
    expect(Nokogiri::HTML5(response.body).css("form.c-scanner__add button").map { it.text.strip }.uniq).to eq([ "Nonfoil", "Foil · read from the card" ])
  end

  it "shows 20, and the rest behind a control (AC-2.5)", :aggregate_failures do
    25.times { create(:catalog_entry, identity:, name: "Lightning Bolt", released_on: Date.new(2000, 1, 1)) }
    other_printings
    html = Nokogiri::HTML5(response.body)
    expect(html.css("turbo-frame > section > ul > li").size).to eq(20)
    expect(html.at_css("details summary").text.strip).to eq("Show 7 more")
  end

  it "answers 404 for a malformed key or an unknown card", :aggregate_failures do
    other_printings(key: "nope")
    expect(response).to have_http_status(:not_found)
    get scanner_printings_path(card: "unknown", key:)
    expect(response).to have_http_status(:not_found)
  end
end
```

- [ ] Run `bin/rspec spec/requests/scanner/printings_spec.rb`. Expect it to FAIL (`undefined method 'scanner_printings_path'`).
- [ ] In `config/routes.rb`, inside `namespace :scanner do`, after `resources :readings, only: :create`, add `    resources :printings, only: :index`.
- [ ] Write `app/controllers/scanner/printings_controller.rb`:

```ruby
# "Other printings" for a scanned card (spec 009 Story 2): its printings in a Turbo Frame inside the reading, each with add
# buttons for the same reading, so the scanner and its camera stay on the page.
class Scanner::PrintingsController < ApplicationController
  def index
    @key = params.expect(:key)
    return head(:not_found) unless Scanner::Sitting::KEY_FORMAT.match?(@key)

    @identity = Catalog::Identity.where(collectible_type: MTG::Reading::COLLECTIBLE_TYPE).find_by!(external_key: params.expect(:card))
    @printings = Scanner::OtherPrintings.new(identity: @identity, set_code: params[:set], number: params[:number])
    @finish_hint = params[:finish_hint].presence
  end
end
```

  (`params.expect(:key)` answers 400 when the key is missing, like every `expect` in the app; a malformed key answers 404.)
- [ ] Write `app/views/scanner/printings/index.html.erb`:

```erb
<%= turbo_frame_tag "scanner_printings" do %>
  <section class="c-scanner__printings" aria-labelledby="scanner-printings-heading">
    <div class="c-section__head">
      <h2 class="c-section__title" id="scanner-printings-heading">Other printings of <%= @identity.name %></h2>
      <span class="c-section__count"><%= pluralize(@printings.entries.size, "printing") %></span>
    </div>
    <ul class="c-list"><%= render partial: "scanner/printings/printing", collection: @printings.shown, as: :printing, locals: { key: @key, finish_hint: @finish_hint } %></ul>
    <% if @printings.rest.any? %>
      <details class="c-scanner__more">
        <summary class="c-btn c-btn--ghost c-btn--sm">Show <%= @printings.rest.size %> more</summary>
        <ul class="c-list"><%= render partial: "scanner/printings/printing", collection: @printings.rest, as: :printing, locals: { key: @key, finish_hint: @finish_hint } %></ul>
      </details>
    <% end %>
  </section>
<% end %>
```

- [ ] Write `app/views/scanner/printings/_printing.html.erb`:

```erb
<%# locals: (printing:, key:, finish_hint:) %>
<li>
  <span class="is-data"><%= set_number(printing) %></span>
  <span class="c-list__meta"><%= printing.set.name %> · <%= printing.released_on ? l(printing.released_on, format: :long) : "Release date unknown" %></span>
  <span class="c-list__end"><%= render "scanners/add_buttons", printing:, key:, finish_hint:, rank: "other" %></span>
</li>
```

  (`config/locales/en.yml` sets `date.formats.long: "%-d %B %Y"`, so the date reads "17 July 2009".)
- [ ] In `app/views/scanners/_candidate.html.erb`, after the `scanners/add_buttons` render line, add:

```erb
  <%= link_to "Other printings", scanner_printings_path(card: entry.identity.external_key, key:, set: reading.collector_line.set_code,
        number: reading.collector_line.number, finish_hint: reading.finish_hint), class: "c-btn c-btn--ghost c-btn--sm", data: { turbo_frame: "scanner_printings" } %>
```

- [ ] In `app/views/scanners/_result.html.erb`, after the closing `</div>` of the `c-grid` (inside the `else` branch), add `      <%= turbo_frame_tag "scanner_printings" %>`.
- [ ] Append to `app/assets/stylesheets/collector/additions.css`:

```css
.c-scanner__printings .c-list li { flex-wrap:wrap; }
.c-scanner__printings .c-list__end { font-family:var(--font-sans); }
```

- [ ] Add to `spec/requests/scanner/readings_spec.rb` (in the built-index context):

```ruby
    it "offers Other printings on every candidate, with what was read (AC-2.1)", :aggregate_failures do
      read("Lightning Bolt", "R 0123\nMOM • EN")
      link = Nokogiri::HTML5(response.body).at_css("a[data-turbo-frame=scanner_printings]")
      expect(link.text).to eq("Other printings")
      expect(Rack::Utils.parse_query(URI(link["href"]).query)).to include("card" => bolt.identity.external_key, "key" => key, "set" => "MOM", "number" => "123")
    end
```

- [ ] Add to `spec/system/scanner_adding_spec.rb`:

```ruby
  it "opens Other printings in place and adds the one chosen (AC-2.2, AC-2.6)", :aggregate_failures do
    m10 = create(:catalog_set, code: "m10", name: "Magic 2010", released_on: Date.new(2009, 7, 17))
    older = create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity: Catalog::Identity.sole, name: "Lightning Bolt", set: m10, number: "146")).entry
    read_card
    page.execute_script("window.__marker = 'still here'")
    click_on "Other printings"
    expect(page).to have_css("#status", text: "Other printings of Lightning Bolt are below.")
    within("turbo-frame#scanner_printings") { find("button[aria-label='Add Lightning Bolt M10 · 146 Nonfoil']").click }
    expect(page).to have_css("#status", text: "Added 1 × Lightning Bolt (M10 · 146, Nonfoil) to your collection.")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(user.account.scanner_sitting.entries.sole.printing).to eq(older)
  end

  it "says so in place when Other printings can't load (Error Scenarios)", :aggregate_failures do
    read_card
    allow(Scanner::OtherPrintings).to receive(:new).and_raise(StandardError, "boom")
    click_on "Other printings"
    expect(page).to have_css("turbo-frame#scanner_printings", text: "Other printings couldn't be loaded.")
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt")
  end
```

- [ ] Run `bin/rspec spec/models/scanner spec/requests/scanner spec/system/scanner_adding_spec.rb`. Expect 0 failures.
- [ ] Add to `docs/design-system/components/Scanner.md`, after the add-button bullet:

```markdown
- Each candidate has a ghost "Other printings" link into the `turbo-frame#scanner_printings` under the candidates. The frame lists the card's English printings (`.c-scanner__printings`, a `c-list`: set · number, set name and release date, then the add buttons), with what was read first. Twenty show; the rest sit in a `details.c-scanner__more` ("Show N more").
```

- [ ] Commit: `feat(scanner): choose another printing in place (009)`.

---

## Phase 7: Detection on the photo path

**Implements:** FR-4, Story 7, FR-5 | **Satisfies:** AC-7.1, AC-7.2, AC-7.3 (the check, recorded in Phase 10), AC-7.4, AC-7.5, AC-7.6
**Files:** `app/javascript/scanner/detector.js`, `app/javascript/scanner/geometry.js`, `app/javascript/controllers/card_reader_controller.js`, `app/views/scanners/_scanner.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/support/scanner_helpers.rb`, `spec/system/scanner_detection_spec.rb`, `spec/requests/scanners_spec.rb`, `script/scanner/detector_parity.rb`, `docs/design-system/components/Scanner.md`
**Interfaces:** Consumes: `scanner/geometry`'s `CARD_ASPECT`, `GUIDE`, `STAGE_ASPECT`, `STRIPS` and `guideInFrame`. Produces:
- `scanner/detector`: `SETTINGS`, `WARP`, `findCard(photo, settings)` → `{ found, corners, picture, detectMs, warpMs }`, `detectCard(source, settings)`, `completeOutline(corners, settings)`, `warp` and `framed`
- `scanner/geometry`'s `DETECTED_STRIPS` and `cropStrips(image, card, layout = STRIPS)`
- the `card-reader:read` detail fields `outline` (`"live"`, `"found"` or `"not_found"`), `detectMs` and `warpMs`
- the ScannerHelpers `MODULES_JS`, `detect_synthetic` and `pick_photo`

- [ ] Add to `spec/support/scanner_helpers.rb`, inside the module after `CARD_JS`:

```ruby
  # Loads the page's own scanner modules into the WebDriver sandbox, as CARD_JS loads geometry (spec 009 Story 7).
  MODULES_JS = <<~JS.freeze
    window.__modules ||= new Promise((resolve) => {
      addEventListener("modules-ready", () => resolve(window.__scannerModules), { once: true })
      const script = Object.assign(document.createElement("script"), { type: "module", nonce: document.querySelector("script[type=importmap]")?.nonce || "" })
      script.textContent = `import * as geometry from "scanner/geometry"; import * as detector from "scanner/detector"; window.__scannerModules = { geometry, detector }; dispatchEvent(new Event("modules-ready"))`
      document.head.append(script)
    })
  JS

  # What the shipped detector finds in a grey photo with a white card-shaped rectangle, optionally tilted.
  def detect_synthetic(card:, width: 1200, height: 1600, tilt_degrees: 0)
    page.evaluate_async_script(<<~JS, width, height, card, tilt_degrees)
      const [ width, height, card, tilt, done ] = arguments
      #{MODULES_JS}
      window.__modules.then(({ detector }) => {
        const canvas = Object.assign(document.createElement("canvas"), { width, height })
        const context = canvas.getContext("2d")
        context.fillStyle = "#555"; context.fillRect(0, 0, width, height)
        if (card) {
          context.translate(card.x + card.width / 2, card.y + card.height / 2); context.rotate(tilt * Math.PI / 180)
          context.fillStyle = "white"; context.fillRect(-card.width / 2, -card.height / 2, card.width, card.height)
        }
        const found = detector.findCard(canvas)
        done({ found: found.found, corners: found.corners || null, picture: found.picture ? [ found.picture.width, found.picture.height ] : null })
      })
    JS
  end

  # Picks a photo of a synthetic card drawn anywhere in it (or none), so the detector rather than the guide has to find it.
  def pick_photo(card: { x: 40, y: 360, width: 859, height: 1200 }, width: 1200, height: 1600, name: "Lightning Bolt", lines: [ "R 0123", "MOM • EN" ])
    page.evaluate_async_script(<<~JS, width, height, card, name, lines)
      const [ width, height, card, name, lines, done ] = arguments
      #{CARD_JS}
      const canvas = Object.assign(document.createElement("canvas"), { width, height })
      const context = canvas.getContext("2d")
      context.fillStyle = "#555"; context.fillRect(0, 0, width, height)
      if (card) {
        context.fillStyle = "white"; context.fillRect(card.x, card.y, card.width, card.height)
        context.fillStyle = "black"; context.textBaseline = "middle"
        context.font = `${Math.round(card.height * 0.045)}px sans-serif`
        context.fillText(name, card.x + card.width * 0.08, card.y + card.height * 0.10)
        context.font = `${Math.round(card.height * 0.022)}px sans-serif`
        lines.forEach((line, index) => context.fillText(line, card.x + card.width * 0.06, card.y + card.height * (0.935 + 0.03 * index)))
      }
      canvas.toBlob((blob) => {
        const transfer = new DataTransfer()
        transfer.items.add(new File([ blob ], "card.png", { type: "image/png" }))
        const input = document.querySelector("[data-card-reader-target=picker]")
        input.files = transfer.files
        input.dispatchEvent(new Event("change", { bubbles: true }))
        done(true)
      }, "image/png")
    JS
  end
```

  The detector needs the card to span at least 65% of the photo's height and width (`minSeparation`). The cards here are 75% and 72% of a 1200×1600 photo, placed away from the guide (whose box is x 142–1058, y 160–1440), so the guide's fixed strips would miss the name.
- [ ] Write the failing system spec `spec/system/scanner_detection_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Detection on the scanner's photo path", type: :system do
  before do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
    visit scanner_path
    wait_for_scanner
  end

  def corners_of(card, tilt_degrees)
    cx, cy = card[:x] + card[:width] / 2.0, card[:y] + card[:height] / 2.0
    angle = tilt_degrees * Math::PI / 180
    [ [ -1, -1 ], [ 1, -1 ], [ 1, 1 ], [ -1, 1 ] ].map do |sx, sy|
      dx, dy = sx * card[:width] / 2.0, sy * card[:height] / 2.0
      [ cx + dx * Math.cos(angle) - dy * Math.sin(angle), cy + dx * Math.sin(angle) + dy * Math.cos(angle) ]
    end
  end

  it "finds a tilted card's corners and straightens it into a 3:4 picture (AC-7.1)", :aggregate_failures do
    card = { x: 170, y: 200, width: 859, height: 1200 }
    result = detect_synthetic(card:, tilt_degrees: 3)
    expect(result["found"]).to be(true)
    expect(result["picture"]).to eq([ 1320, 1760 ])
    result["corners"].zip(corners_of(card, 3)).each { |found, real| expect(found.zip(real).map { |a, b| (a - b).abs }.max).to be <= 15 }
  end

  it "finds no card in a photo without one (AC-7.2)" do
    expect(detect_synthetic(card: nil)["found"]).to be(false)
  end

  it "reads a card the guide would miss, sending only the text and the key (AC-7.1, FR-4)", :aggregate_failures do
    pick_photo
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
    expect(first(".c-scanner__candidate")).to have_text("Matched by its collector line")
    expect(scanner_sent).to eq([ [ "reading[name_text]", "reading[collector_text]", "reading[key]" ] ])
  end

  it "falls back to the guide and says no card edge was found (AC-7.2)" do
    pick_photo(card: nil)
    expect(page).to have_css(".c-scanner__status", text: "No card edge was found", wait: 30)
  end

  it "runs no detection on a live capture (AC-7.6)", :aggregate_failures do
    show_synthetic_card
    page.execute_script("window.__outlines = []; document.querySelector('.c-scanner').addEventListener('card-reader:read', (event) => window.__outlines.push(event.detail.outline))")
    click_on "Capture"
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
    expect(page.evaluate_script("window.__outlines")).to eq([ "live" ])
  end

  it "tells the collector how to take a photo (AC-7.4)" do
    expect(page).to have_text("Using a photo? Take the whole card, upright, filling most of the photo as the live guide does, on a plain background.")
  end
end
```

- [ ] Add to `spec/requests/scanners_spec.rb`, inside `describe "when signed in"`:

```ruby
    it "serves the detector from this app under the unchanged policy (AC-7.5)", :aggregate_failures do
      get scanner_path
      expect(response.body).to match(%r{"scanner/detector": "/assets/scanner/detector-[0-9a-f]+\.js"})
      expect(csp["script-src"].first(2)).to eq([ "'self'", "'wasm-unsafe-eval'" ])
    end
```

- [ ] Run `bin/rspec spec/system/scanner_detection_spec.rb spec/requests/scanners_spec.rb`. Expect failures (no `scanner/detector` module, no hint, no outline).
- [ ] Write `app/javascript/scanner/detector.js`:

```js
import { CARD_ASPECT, GUIDE, STAGE_ASPECT } from "scanner/geometry"

// Finds the card in a picked photo and straightens it (spec 009 Story 7, ADR 0005). This is the Phase 2 spike's
// hand-written detector (spikes/card_scanner/phase2/public/hand_detector.js and warp.js at 39cdc6e), moved onto page
// canvases, plus outline completion (AC-6.6). It takes the two strongest near-horizontal and near-vertical edge lines in a
// downscaled copy of the photo, intersects them for the corners, and maps the card onto a 3:4 picture with the card exactly
// in the guide's box. Cards are treated as upright. It runs on the device; nothing it makes leaves it (FR-4).

// Frozen in the spike at 39cdc6e (spec 008 settings.json "hand" and "warp"). completeTolerance is spec 009's outline
// completion (AC-6.6): null is off, as in the spike. Tuned on the development photos and frozen before the live sitting.
export const SETTINGS = { workWidth: 480, blur: 2, edgePercentile: 0.55, thetaRangeDeg: 6, minSeparation: 0.65, minArea: 0.15,
  aspectRange: [ 0.5, 0.9 ], completeTolerance: null }
export const WARP = { width: 1008, height: 1408, fill: "#808080" }

// { found: true, corners, picture, detectMs, warpMs }, or { found: false, detectMs }. corners are in the photo's pixels
// (top-left, top-right, bottom-right, bottom-left); picture is the canvas the shipped strips are cut from.
export function findCard(photo, settings = SETTINGS) {
  const source = canvasOf(photo.width, photo.height)
  source.context.drawImage(photo, 0, 0)
  const started = performance.now()
  const corners = detectCard(source.canvas, settings)
  const detectMs = Math.round(performance.now() - started)
  if (!corners) return { found: false, detectMs }
  const warpStarted = performance.now()
  const picture = framed(warp(source.canvas, corners, WARP.width, WARP.height), WARP.fill)
  return { found: true, corners, picture, detectMs, warpMs: Math.round(performance.now() - warpStarted) }
}

export function detectCard(source, settings = SETTINGS) {
  const scale = settings.workWidth / source.width
  const w = settings.workWidth, h = Math.round(source.height * scale)
  const work = canvasOf(w, h)
  work.context.drawImage(source, 0, 0, w, h)
  const gray = toGray(work.context.getImageData(0, 0, w, h))
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
  return completeOutline(corners, settings).map(([ x, y ]) => [ x / scale, y / scale ])
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

// Accumulates rho = x cos(theta) + y sin(theta) over edge pixels whose gradient points the right way: near-vertical
// gradients vote for horizontal lines (theta about 90 degrees), near-horizontal ones for vertical lines (theta about 0).
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

// The strongest line, then the strongest line at least minSeparation away in rho; null if the second is weaker than a
// third of the first (no second edge of the card was found).
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
  if (corners.some(([ x, y ]) => x < -margin * w || x > (1 + margin) * w || y < -margin * h || y > (1 + margin) * h)) return false
  let area = 0
  for (let i = 0; i < 4; i++) {
    const [ x1, y1 ] = corners[i], [ x2, y2 ] = corners[(i + 1) % 4]
    area += x1 * y2 - x2 * y1
  }
  area = Math.abs(area) / 2
  if (area < settings.minArea * w * h) return false
  const width = (side(corners[0], corners[1]) + side(corners[3], corners[2])) / 2
  const height = (side(corners[0], corners[3]) + side(corners[1], corners[2])) / 2
  const aspect = width / height
  return aspect >= settings.aspectRange[0] && aspect <= settings.aspectRange[1]
}

// When the outline is much wider than a card for its height, the bottom edge was missed (a card filling the frame, ADR
// 0005): move the bottom corners down their side lines until the outline has a card's proportions (spec 009 AC-6.6).
export function completeOutline(corners, settings) {
  if (!settings.completeTolerance) return corners
  const [ tl, tr, br, bl ] = corners
  const width = (side(tl, tr) + side(bl, br)) / 2
  const height = (side(tl, bl) + side(tr, br)) / 2
  if (width / height <= CARD_ASPECT * (1 + settings.completeTolerance)) return corners
  const target = width / CARD_ASPECT
  const extend = (top, bottom) => {
    const stretch = target / side(top, bottom)
    return [ top[0] + (bottom[0] - top[0]) * stretch, top[1] + (bottom[1] - top[1]) * stretch ]
  }
  return [ tl, tr, extend(tr, br), extend(tl, bl) ]
}

// Solves for the 8 parameters of the map (u, v) -> (x, y) taking the output rectangle's corners to the card's corners:
// x = (a u + b v + c) / (g u + h v + 1), y = (d u + e v + f) / (g u + h v + 1).
export function homography(width, height, corners) {
  const from = [ [ 0, 0 ], [ width, 0 ], [ width, height ], [ 0, height ] ]
  const rows = [], rhs = []
  for (let i = 0; i < 4; i++) {
    const [ u, v ] = from[i], [ x, y ] = corners[i]
    rows.push([ u, v, 1, 0, 0, 0, -u * x, -v * x ]); rhs.push(x)
    rows.push([ 0, 0, 0, u, v, 1, -u * y, -v * y ]); rhs.push(y)
  }
  return solve(rows, rhs)
}

export function solve(a, b) {
  const n = b.length
  const m = a.map((row, i) => [ ...row, b[i] ])
  for (let col = 0; col < n; col++) {
    let pivot = col
    for (let r = col + 1; r < n; r++) if (Math.abs(m[r][col]) > Math.abs(m[pivot][col])) pivot = r
    ;[ m[col], m[pivot] ] = [ m[pivot], m[col] ]
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

// Straightens the card into a width × height canvas with bilinear sampling and nothing else.
export function warp(source, corners, width, height) {
  const src = source.getContext("2d", { willReadFrequently: true }).getImageData(0, 0, source.width, source.height)
  const [ a, b, c, d, e, f, g, hh ] = homography(width, height, corners)
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
  const { canvas, context } = canvasOf(width, height)
  context.putImageData(out, 0, 0)
  return canvas
}

// The 3:4 picture the shipped strips are cut from: the card fills the guide's box (GUIDE.height of the height, 63:88,
// centred), and the rest is one flat colour.
export function framed(card, fill) {
  const height = Math.round(card.height / GUIDE.height)
  const width = Math.round(height * STAGE_ASPECT)
  const { canvas, context } = canvasOf(width, height)
  context.fillStyle = fill
  context.fillRect(0, 0, width, height)
  const cardHeight = height * GUIDE.height, cardWidth = cardHeight * CARD_ASPECT
  context.drawImage(card, (width - cardWidth) / 2, (height - cardHeight) / 2, cardWidth, cardHeight)
  return canvas
}

function side(p, q) {
  return Math.hypot(q[0] - p[0], q[1] - p[1])
}

function canvasOf(width, height) {
  const canvas = Object.assign(document.createElement("canvas"), { width, height })
  return { canvas, context: canvas.getContext("2d", { willReadFrequently: true }) }
}

function toGray({ data, width, height }) {
  const gray = new Float32Array(width * height)
  for (let i = 0, p = 0; i < gray.length; i++, p += 4) gray[i] = 0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2]
  return gray
}
```

- [ ] In `app/javascript/scanner/geometry.js`:
  - After the `STRIPS` constant, add:

```js
// Strips for a picture the detector straightened (spec 009 AC-6.6): there the card exactly fills the guide, unlike a live
// frame, where it sits a little inside. Starts equal to STRIPS; tuned on the spike's development photos.
export const DETECTED_STRIPS = { name: { ...STRIPS.name }, collector: { ...STRIPS.collector } }
```

  - Change `export function cropStrips(image, card) {` to `export function cropStrips(image, card, layout = STRIPS) {`, and inside it `Object.entries(STRIPS)` to `Object.entries(layout)`.
- [ ] Rewrite `app/javascript/controllers/card_reader_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { cropStrips, guideInFrame, DETECTED_STRIPS, STAGE_ASPECT, STRIPS } from "scanner/geometry"
import { findCard } from "scanner/detector"
import { loadEngine, readStrips } from "scanner/recognition"

// Turns a captured frame or a picked photo into what the card says (spec 007 Stories 2–4). A picked photo is first searched
// for the card, which is straightened into the guide's box (spec 009 Story 7); live frames aren't (AC-7.6). It cuts the
// strips, reads them on the device, sends only the text and a reading key, and shows the Turbo Stream answer. One reading at
// a time. Dispatches card-reader:read ({ nameText, collectorText, ms, key, outline, detectMs, warpMs, strips }) for
// measurement mode, where outline is "live", "found" or "not_found".
const REASONS = {
  insecure: "The live camera needs this page to be served over HTTPS. You can use a photo instead.",
  denied: "The camera is blocked for this site. Allow it in your browser's settings, or use a photo instead.",
  "no-camera": "No camera was found. You can use a photo instead.",
  failed: "The camera didn't start. Try again, or use a photo instead.",
  lost: "The camera stopped. Try again, or use a photo instead."
}
const NO_EDGE = "No card edge was found, so the photo was read as if framed like the guide. For a better reading, photograph the whole card, upright, filling most of the photo, on a plain background."

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
    this.read(() => ({ image, card, layout: STRIPS, outline: "live" }))
  }

  pick() {
    const file = this.pickerTarget.files[0]
    this.pickerTarget.value = ""
    if (!file || !this.engineReady || this.busy) return
    this.read(async () => {
      const photo = await createImageBitmap(file) // applies the photo's orientation
      const found = findCard(photo)
      if (!found.found) {
        return { image: photo, card: guideInFrame(photo.width, photo.height, STAGE_ASPECT, 1), layout: STRIPS, outline: "not_found", detectMs: found.detectMs }
      }
      const { picture, detectMs, warpMs } = found
      return { image: picture, card: guideInFrame(picture.width, picture.height, STAGE_ASPECT, 1), layout: DETECTED_STRIPS, outline: "found", detectMs, warpMs }
    })
  }

  async read(prepare) {
    if (this.busy) return
    this.busy = true
    this.render()
    this.say("Reading the card…")
    try {
      const { image, card, layout, ...source } = await prepare()
      const strips = cropStrips(image, card, layout)
      const reading = { ...(await readStrips(this.enginePathValue, strips)), key: readingKey(), ...source }
      if (!this.element.isConnected) return
      this.dispatch("read", { detail: { ...reading, strips } })
      this.lastReading = reading
      if (await this.send(reading) && reading.outline === "not_found") this.say(NO_EDGE)
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

  // Sends the text and the reading key (spec 009 FR-5), never the outline or timings; true when the answer was shown.
  async send({ nameText, collectorText, key }) {
    this.failureTarget.hidden = true
    const body = new FormData()
    body.append("reading[name_text]", nameText)
    body.append("reading[collector_text]", collectorText)
    body.append("reading[key]", key)
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
    return true
  }

  failed(message, { signedOut }) {
    this.failureMessageTarget.textContent = message
    this.failureNameTarget.textContent = this.lastReading?.nameText || "Nothing read"
    this.failureCollectorTarget.textContent = this.lastReading?.collectorText || "Nothing read"
    this.resendTarget.hidden = signedOut
    this.signInTarget.hidden = !signedOut
    this.failureTarget.hidden = false
    this.say(message)
    return false
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

// An opaque key for one reading (spec 009 AC-1.5): random, never derived from the text. getRandomValues also works where
// the page isn't a secure context (the photo path over plain HTTP), unlike randomUUID.
function readingKey() {
  return Array.from(crypto.getRandomValues(new Uint8Array(16)), (byte) => byte.toString(16).padStart(2, "0")).join("")
}
```

- [ ] In `app/views/scanners/_scanner.html.erb`, after the closing `</div>` of `c-scanner__controls`, add:

```erb
  <p class="c-scanner__hint">Using a photo? Take the whole card, upright, filling most of the photo as the live guide does, on a plain background.</p>
```

  Append to `app/assets/stylesheets/collector/additions.css`: `.c-scanner__hint { margin:0; font:400 14px/20px var(--font-sans); color:var(--ink-muted); }`
- [ ] Run `bin/rspec spec/system/scanner_detection_spec.rb spec/system/scanner_spec.rb spec/system/scanner_adding_spec.rb spec/requests/scanners_spec.rb`. Expect 0 failures. (Spec 007's picked-photo example now goes through detection: its synthetic card fills 80% of the photo, so it is found and read.)
- [ ] Write `script/scanner/detector_parity.rb` (AC-7.3; a recorded check, not a suite test):

```ruby
# Spec 009 AC-7.3: the shipped detector against the Phase 2 spike's at its frozen settings, on the spike's 99 photos. The
# spike's runs at those settings (dev-hand-3 for the development half; held-hand, at 39cdc6e, for the held-out half; the
# detector code and settings are identical between them) recorded each photo's outcome and corners, so they are the
# reference and the spike isn't run again. Runs the page's own detector, with outline completion off, in headless
# Firefox against this checkout's dev server.
# Usage: SCANNER_EMAIL=findings@localhost SCANNER_PASSWORD=... bundle exec ruby script/scanner/detector_parity.rb
require "bundler/setup"
require "base64"
require "json"
require "pathname"
require "selenium-webdriver"
require_relative "../../lib/collector/dev_port"

CORPUS = Pathname(File.expand_path(ENV.fetch("CARD_SCANNER_CORPUS", "~/card-scanner-corpus")))
RUNS = %w[dev-hand-3 held-hand].freeze
WORK_WIDTH = 480

DETECT_JS = <<~JS.freeze
  const [ data, done ] = arguments
  window.__detector ||= new Promise((resolve) => {
    addEventListener("detector-ready", () => resolve(window.__scannerDetector), { once: true })
    const script = Object.assign(document.createElement("script"), { type: "module", nonce: document.querySelector("script[type=importmap]")?.nonce || "" })
    script.textContent = `import * as detector from "scanner/detector"; window.__scannerDetector = detector; dispatchEvent(new Event("detector-ready"))`
    document.head.append(script)
  })
  window.__detector.then(async (detector) => {
    const bytes = Uint8Array.from(atob(data), (character) => character.charCodeAt(0))
    const photo = await createImageBitmap(new Blob([ bytes ]))
    const found = detector.findCard(photo, { ...detector.SETTINGS, completeTolerance: null })
    done({ found: found.found, corners: found.corners || null, width: photo.width })
  }).catch((error) => done({ error: String(error) }))
JS

records = RUNS.flat_map { |run| CORPUS.join("runs/phase2", run).glob("*/detect.json").map { JSON.parse(it.read) } }
abort "Expected 99 spike records, found #{records.size}." unless records.size == 99

base = ENV.fetch("SCANNER_URL") { "http://127.0.0.1:#{Collector::DevPort.resolve(root: File.expand_path("../..", __dir__))}" }
email = ENV.fetch("SCANNER_EMAIL") { abort "Set SCANNER_EMAIL and SCANNER_PASSWORD to a local user." }
password = ENV.fetch("SCANNER_PASSWORD") { abort "Set SCANNER_EMAIL and SCANNER_PASSWORD to a local user." }
options = Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ], accept_insecure_certs: true)
driver = Selenium::WebDriver.for(:firefox, options:)
driver.manage.timeouts.script_timeout = 120
begin
  driver.navigate.to("#{base}/session/new")
  driver.find_element(name: "email_address").send_keys(email)
  driver.find_element(name: "password").send_keys(password)
  driver.find_element(css: "input[type=submit][value='Sign in']").click
  Selenium::WebDriver::Wait.new(timeout: 30).until { driver.find_elements(css: ".c-avatar").any? }
  driver.navigate.to("#{base}/scanner")
  mismatches = records.sort_by { it["file"] }.filter_map do |record|
    result = driver.execute_async_script(DETECT_JS, Base64.strict_encode64(CORPUS.join(record["path"]).binread))
    abort "#{record["file"]}: #{result["error"]}" if result["error"]
    scale = WORK_WIDTH.fdiv(record["sourceWidth"])
    drift = record["found"] && result["found"] ? record["corners"].flatten.zip(result["corners"].flatten).map { |a, b| (a - b).abs * scale }.max : 0
    same = record["found"] == result["found"] && result["width"] == record["sourceWidth"] && drift <= 1
    puts format("%-16s %-9s spike %-5s app %-5s drift %.3f px%s", record["file"], record["half"], record["found"], result["found"], drift, same ? "" : "  MISMATCH")
    record["file"] unless same
  end
  puts "#{records.size - mismatches.size} of #{records.size} match: the same outcome, and corners within 1 px at work width #{WORK_WIDTH}."
  puts "Mismatches: #{mismatches.join(", ")}" if mismatches.any?
ensure
  driver.quit
end
```

- [ ] Run it against the dev server (start it with `bin/dev` as a background task, per the background-servers practice): `SCANNER_EMAIL=findings@localhost SCANNER_PASSWORD=<pw> bundle exec ruby script/scanner/detector_parity.rb | tee tmp/spec009/parity.txt`. Expect `99 of 99 match`. If any photo mismatches, use `sdd-superpowers:systematic-debugging` before changing anything. The likeliest cause is the canvas downscale; the spike drew into an `OffscreenCanvas` and the app into a `<canvas>`.
- [ ] Add to `docs/design-system/components/Scanner.md`, after the photo-control bullet:

```markdown
- A picked photo is searched for the card (`scanner/detector.js`), which is straightened into the guide's box before the strips are cut. When no card edge is found, the status line says so and gives the framing advice; `.c-scanner__hint` under the controls gives it before any photo is picked.
```

- [ ] Commit: `feat(scanner): find and straighten the card in a picked photo (009)`, then `test(scanner): check the shipped detector against the spike's (009)` for the script.

---

## Phase 8: Measurement for the sitting, and the findings tools

**Implements:** Story 9 (the tools), FR-5 (measurement stays development-only) | **Satisfies:** AC-9.2, AC-9.1 (the overlap check and the report), AC-9.3 (the timing fields), AC-9.4 (format version), AC-6.2–AC-6.6 (scoring tools)
**Files:** `app/models/scanner/measurement_run.rb`, `app/controllers/scanner/measurements/{captures,events}_controller.rb`, `config/routes.rb`, `app/views/scanner/measurements/_panel.html.erb`, `app/javascript/controllers/measurement_controller.js`, `lib/collector/scanner_findings.rb`, `lib/collector/scanner_findings/{report,sitting_report}.rb`, `lib/tasks/scanner.rake`, `spec/models/scanner/measurement_run_spec.rb`, `spec/requests/scanner/measurements_spec.rb`, `spec/lib/collector/scanner_findings_spec.rb`, `spec/lib/collector/scanner_findings/{report,sitting_report}_spec.rb`
**Interfaces:** Consumes: Phase 4's form data attributes (`data-scanner-event`, `data-rank`, `data-reading-key`) and the `entry[reading_key]` field; Phase 7's read detail fields. Produces:
- `Scanner::MeasurementRun#record!(…, extra:)`, `#row_for_key(key)`, `#record_event!(row, kind:, rank:, reading_key:)` and `#events(row)`
- the route `scanner_measurement_events_path`
- `Collector::ScannerFindings.headline(records)`, `.foil_markers(results, truth)`, `.overlaps(fresh, earlier)`, `.name_read_changes(before, after)` and the truth record's `"finish"`
- `Report.new(…, format_version:)` and `Collector::ScannerFindings::SittingReport.new(run:, account:, ground_truth:)` with `#outcomes`, `#times` and `#to_markdown`
- the tasks `scanner:derive_halves`, `scanner:detected_score`, `scanner:replay_score[label]`, `scanner:foil_markers`, `scanner:overlap[manifest]` and `scanner:sitting_findings`

- [ ] Add failing examples to `spec/models/scanner/measurement_run_spec.rb`:

```ruby
  describe "spec 009's capture fields and events (AC-9.2)" do
    let(:png) { -> { StringIO.new("\x89PNG\r\n\x1A\n".b) } }

    before { dir.join("manifest.csv").write("file,set,number,foil\nS001,mom,123,no\nS002,neo,51,yes\n") }

    def capture(file, key)
      run.record!(run.row(file), name_text: "Bolt", collector_text: "", ms: 200, user_agent: "iPhone", name_strip: png.call, collector_strip: png.call,
        extra: { "reading_key" => key, "outline" => "found", "detect_ms" => 180, "warp_ms" => 120, "other" => "dropped" })
    end

    it "stores the reading key, the outline and the detector's timings with a capture", :aggregate_failures do
      capture("S001", "a" * 32)
      expect(run.captures(run.row("S001")).sole).to include("reading_key" => "a" * 32, "outline" => "found", "detect_ms" => 180, "warp_ms" => 120)
      expect(run.captures(run.row("S001")).sole).not_to have_key("other")
    end

    it "finds a row by a capture's reading key and keeps its events in order", :aggregate_failures do
      capture("S002", "b" * 32)
      row = run.row_for_key("b" * 32)
      expect(row.file).to eq("S002")
      expect(run.row_for_key("c" * 32)).to be_nil
      run.record_event!(row, kind: "add", rank: "2", reading_key: "b" * 32)
      run.record_event!(row, kind: "undo", rank: nil, reading_key: "b" * 32)
      expect(run.events(row).map { it.slice("kind", "rank") }).to eq([ { "kind" => "add", "rank" => "2" }, { "kind" => "undo", "rank" => nil } ])
      expect(run.events(row).first["at"]).to match(/\A\d{4}-\d\d-\d\dT[\d:.]+Z\z/)
    end
  end
```

- [ ] Add failing examples to `spec/requests/scanner/measurements_spec.rb`:
  - Add `-> { post scanner_measurement_events_path, params: { event: { kind: "add", rank: "1", reading_key: "a" * 32 } } }` to the off-mode `requests` list.
  - Add at the top level:

```ruby
  describe "events (spec 009 AC-9.2)" do
    def event(kind: "add", rank: "1", reading_key: "a" * 32) = post(scanner_measurement_events_path, params: { event: { kind:, rank:, reading_key: } })

    it "records an event against the row whose capture carried the key", :aggregate_failures do
      post scanner_measurement_captures_path, headers: turbo, params: { capture: { file: "IMG_2.jpeg", name_text: "Bolt", collector_text: "", ms: "1",
        user_agent: "iPhone", name_strip: upload(png), collector_strip: upload(png), reading_key: "a" * 32, outline: "live" } }
      event
      expect(response).to have_http_status(:no_content)
      expect(current.events(current.row("IMG_2.jpeg")).sole).to include("kind" => "add", "rank" => "1")
    end

    it "answers 404 for an unknown key or kind", :aggregate_failures do
      event
      expect(response).to have_http_status(:not_found)
      event(kind: "nope")
      expect(response).to have_http_status(:not_found)
    end
  end
```

- [ ] Run `bin/rspec spec/models/scanner/measurement_run_spec.rb spec/requests/scanner/measurements_spec.rb`. Expect failures.
- [ ] In `app/models/scanner/measurement_run.rb`:
  - Add after `PNG_SIGNATURE`:

```ruby
  # Spec 009 adds the reading key, the outline ("live", "found" or "not_found") and the detector's timings (AC-9.2, AC-9.3).
  EXTRA_FIELDS = %w[reading_key outline detect_ms warp_ms].freeze
  EVENT_KINDS = %w[add undo details].freeze
```

  - Change `record!`'s signature to `def record!(row, name_text:, collector_text:, ms:, user_agent:, name_strip:, collector_strip:, extra: {})`. Change its JSON write to:

```ruby
    row_dir(row).join("#{stem}.json").write(JSON.pretty_generate({ "file" => row.file, "kind" => kind.to_s, "name_text" => name_text,
      "collector_text" => collector_text, "ms" => ms, "user_agent" => user_agent, "captured_at" => Time.current.utc.iso8601 }
      .merge(extra.to_h.stringify_keys.slice(*EXTRA_FIELDS).compact_blank)))
```

  - Add after `skip!`:

```ruby
  # The row whose capture carried this reading key (spec 009 AC-9.2), or nil.
  def row_for_key(key) = key.present? ? rows.find { |row| captures(row).any? { it["reading_key"] == key } } : nil

  # One line per event, with the server's time, so the findings can time each card (AC-9.1, AC-9.2).
  def record_event!(row, kind:, rank:, reading_key:)
    row_dir(row).mkpath
    row_dir(row).join("events.jsonl").open("a") do |file|
      file.puts(JSON.generate("kind" => kind, "rank" => rank, "reading_key" => reading_key, "at" => Time.current.utc.iso8601(3)))
    end
  end

  def events(row)
    path = row_dir(row).join("events.jsonl")
    path.file? ? path.readlines.map { JSON.parse(it) } : []
  end
```

- [ ] In `app/controllers/scanner/measurements/captures_controller.rb`, replace `create`'s first line and its `record!` call with:

```ruby
    capture = params.expect(capture: %i[file name_text collector_text ms user_agent name_strip collector_strip reading_key outline detect_ms warp_ms])
    row = measurement_run.row(capture[:file])
    return head(:not_found) unless row

    extra = { "reading_key" => capture[:reading_key].to_s[Scanner::Sitting::KEY_FORMAT], "outline" => capture[:outline].to_s[/\A(live|found|not_found)\z/],
              "detect_ms" => capture[:detect_ms].presence&.to_i, "warp_ms" => capture[:warp_ms].presence&.to_i }
    kind = measurement_run.record!(row, name_text: capture[:name_text].to_s, collector_text: capture[:collector_text].to_s,
      ms: capture[:ms].to_i, user_agent: capture[:user_agent].to_s, name_strip: capture[:name_strip], collector_strip: capture[:collector_strip], extra:)
```

- [ ] Write `app/controllers/scanner/measurements/events_controller.rb`:

```ruby
# Records what the collector did with a measured reading (spec 009 AC-9.2): an add with the candidate's rank (or "other"),
# an Undo, or opening a copy's details, against the manifest row whose capture carried the reading key. Development only.
class Scanner::Measurements::EventsController < ApplicationController
  include MeasurementMode

  def create
    event = params.expect(event: %i[kind rank reading_key])
    row = measurement_run.row_for_key(event[:reading_key].to_s)
    return head(:not_found) unless row && Scanner::MeasurementRun::EVENT_KINDS.include?(event[:kind])

    measurement_run.record_event!(row, kind: event[:kind], rank: event[:rank].presence, reading_key: event[:reading_key])
    head :no_content
  end
end
```

- [ ] In `config/routes.rb`, inside `scope module: :measurements do`, add `        resources :events, only: :create`.
- [ ] In `app/views/scanner/measurements/_panel.html.erb`, change the section's opening tag to:

```erb
<section id="measurement_panel" aria-labelledby="measurement-heading" data-controller="measurement"
         data-measurement-captures-url-value="<%= scanner_measurement_captures_path %>" data-measurement-events-url-value="<%= scanner_measurement_events_path %>"
         data-action="card-reader:read@window->measurement#store turbo:submit-end@document->measurement#submitted click@document->measurement#clicked">
```

- [ ] Rewrite `app/javascript/controllers/measurement_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Measurement mode (spec 007 Story 5, development only): stores each capture's text, strip images, reading key, outline and
// detector timings against the manifest row chosen before the shutter, then shows the next row. A capture counts only once
// stored. For spec 009's live sitting it also records what the collector did with each reading (AC-9.2): adds with the
// candidate's rank, Undo, and opening a copy's details. The add and Undo requests themselves never carry a rank.
export default class extends Controller {
  static targets = [ "row", "status", "retry" ]
  static values = { capturesUrl: String, eventsUrl: String }

  async store({ detail: { nameText, collectorText, ms, key, outline, detectMs, warpMs, strips } }) {
    const body = new FormData()
    body.append("capture[file]", this.rowTarget.value)
    body.append("capture[name_text]", nameText)
    body.append("capture[collector_text]", collectorText)
    body.append("capture[ms]", String(ms))
    body.append("capture[user_agent]", navigator.userAgent)
    body.append("capture[reading_key]", key || "")
    body.append("capture[outline]", outline || "")
    body.append("capture[detect_ms]", detectMs ?? "")
    body.append("capture[warp_ms]", warpMs ?? "")
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
        headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": csrfToken() } })
      if (!response.ok && response.status !== 422) throw new Error(`HTTP ${response.status}`)
      Turbo.renderStreamMessage(await response.text())
    } catch {
      this.statusTarget.textContent = "The capture wasn't stored, so it doesn't count yet. Store it again."
      this.statusTarget.hidden = false
      this.retryTarget.hidden = false
    }
  }

  submitted({ target, detail: { success } }) {
    const kind = target.dataset?.scannerEvent
    if (!success || !kind) return
    const key = target.querySelector("input[name='entry[reading_key]']")?.value || target.dataset.readingKey
    this.event({ kind, rank: target.dataset.rank || "", reading_key: key || "" })
  }

  clicked({ target }) {
    const link = target.closest?.("a[data-scanner-event]")
    if (link) this.event({ kind: link.dataset.scannerEvent, rank: "", reading_key: link.dataset.readingKey || "" })
  }

  event(fields) {
    const body = new FormData()
    Object.entries(fields).forEach(([ name, value ]) => body.append(`event[${name}]`, value))
    fetch(this.eventsUrlValue, { method: "POST", body, keepalive: true, headers: { "X-CSRF-Token": csrfToken() } }).catch(() => {})
  }
}

function png(canvas) {
  return new Promise((resolve) => canvas.toBlob(resolve, "image/png"))
}

function csrfToken() {
  return document.querySelector("meta[name=csrf-token]")?.content
}
```

- [ ] Run `bin/rspec spec/models/scanner/measurement_run_spec.rb spec/requests/scanner/measurements_spec.rb spec/system/scanner_measurement_spec.rb`. Expect 0 failures. Commit: `feat(scanner): record reading keys, outlines and sitting events in measurement mode (009)`.
- [ ] Add failing examples to `spec/lib/collector/scanner_findings_spec.rb`, inside the describe that builds ground truth (it has the `entry` fixture):

```ruby
    it "records each card's finish in ground truth, from a finish column or the foil column (spec 009 AC-9.1)" do
      truth = described_class.ground_truth("file,set,number,foil,era,finish\nIMG_1.jpeg,mom,123,yes,,\nIMG_3.jpeg,mom,123,no,,etched\n")
      expect(truth["photos"].map { it["finish"] }).to eq(%w[foil etched])
    end

    it "lists cards already used by earlier corpora (spec 009 AC-9.1)" do
      fresh = [ { "file" => "S001", "name" => "Lightning Bolt", "external_key" => "x" }, { "file" => "S002", "name" => "Opt", "external_key" => "y" } ]
      earlier = { "Phase 0" => [ { "file" => "IMG_1.jpeg", "name" => "Lightning Bolt", "external_key" => "z" } ] }
      expect(described_class.overlaps(fresh, earlier)).to eq([ "S001 Lightning Bolt is Phase 0 IMG_1.jpeg (another printing)" ])
    end
```

  And at the top level of the spec:

```ruby
  describe ".headline (spec 009 tuning)" do
    it "gives right first, top 3, exact printing by foil, name read and outlines found, each with its sample size" do
      records = [
        { "name" => "A", "name_bar" => "A", "name_text" => "A", "final_candidates" => %w[A], "era" => "MOM+", "foil" => true, "external_key" => "k1",
          "lookup" => { "status" => "one", "external_keys" => [ "k1" ] }, "outline" => "found" },
        { "name" => "B", "name_bar" => "B", "name_text" => "x", "final_candidates" => %w[C B], "era" => "pre-M15", "foil" => false, "external_key" => "k2",
          "lookup" => { "status" => "none", "external_keys" => [] }, "outline" => "not_found" }
      ]
      expect(described_class.headline(records)).to eq("right card first 1/2 (50.0%); top 3 2/2 (100.0%); exact printing 1/1 (100.0%) " \
        "(foils 1/1 (100.0%), non-foils 0/0 (n/a)); name read 1/2 (50.0%); outline found 1/2 (50.0%)")
    end
  end
```

- [ ] Write the failing spec `spec/lib/collector/scanner_findings/sitting_report_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::ScannerFindings::SittingReport do
  let(:dir) { Pathname(Dir.mktmpdir("sitting")) }
  let(:run) { Scanner::MeasurementRun.new(manifest: dir.join("manifest.csv"), dir: dir.join("run")) }
  let(:account) { create(:user).account }
  let(:bolt) { create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, name: "Lightning Bolt", set: mom, number: "123")).entry }
  let(:opt) { create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, name: "Opt", set: mom, number: "7")).entry }

  def mom = Catalog::Set.find_by(collectible_type: "mtg", code: "mom") || create(:catalog_set, code: "mom")
  def report = described_class.new(run:, account:, ground_truth: dir.join("truth.json"))

  before do
    dir.join("manifest.csv").write("file,set,number,foil\nS001,mom,123,no\nS002,mom,7,yes\nS003,mom,123,no\n")
    dir.join("truth.json").write(JSON.generate("photos" => [
      { "file" => "S001", "name" => "Lightning Bolt", "set_code" => "mom", "collector_number" => "123", "external_key" => bolt.external_key, "finish" => "nonfoil", "foil" => false },
      { "file" => "S002", "name" => "Opt", "set_code" => "mom", "collector_number" => "7", "external_key" => opt.external_key, "finish" => "foil", "foil" => true },
      { "file" => "S003", "name" => "Lightning Bolt", "set_code" => "mom", "collector_number" => "123", "external_key" => bolt.external_key, "finish" => "nonfoil", "foil" => false } ]))
    scan("S001", "a", bolt, "nonfoil", rank: "1")
    scan("S002", "b", opt, "nonfoil", rank: "2")
    Scanner::SittingEntry.find_by!(reading_key: "b" * 32).undo!
    run.record_event!(run.row("S002"), kind: "undo", rank: nil, reading_key: "b" * 32)
    scan("S002", "c", opt, "foil", rank: "other")
  end

  after { FileUtils.remove_entry(dir) }

  def scan(file, key, printing, finish, rank:)
    strip = -> { StringIO.new("\x89PNG\r\n\x1A\n".b) }
    run.record!(run.row(file), name_text: printing.name, collector_text: "", ms: 200, user_agent: "iPhone", name_strip: strip.call,
      collector_strip: strip.call, extra: { "reading_key" => key * 32, "outline" => "live" })
    Scanner::Sitting.add!(account:, printing:, finish:, reading_key: key * 32)
    run.record_event!(run.row(file), kind: "add", rank:, reading_key: key * 32)
  end

  it "scores each card by what it ended as, with the corrections on the way (AC-9.1)", :aggregate_failures do
    outcomes = report.outcomes.index_by(&:file)
    expect(outcomes["S001"].kind).to eq("right first time")
    expect(outcomes["S002"]).to have_attributes(kind: "right after a correction", corrections: [ "a candidate other than the first", "Other printings", "Undo and re-add" ], scans: 2)
    expect(outcomes["S003"].kind).to eq("not added")
  end

  it "reads the finish from the lot after an edit" do
    Scanner::SittingEntry.find_by!(reading_key: "a" * 32).lot.revise!(finish: "foil")
    expect(report.outcomes.find { it.file == "S001" }.kind).to eq("wrong")
  end

  it "summarises the outcomes by finish, the corrections and the time per card", :aggregate_failures do
    markdown = report.to_markdown
    expect(markdown).to include("| all | 1/3 | 1/3 | 0/3 | 1/3 |", "| foil | 0/1 | 1/1 | 0/1 | 0/1 |", "Other printings: 1")
    expect(markdown).to match(/Time per card .*\(n=2\)/)
    expect(markdown).to include("| S003 | Lightning Bolt (MOM · 123, nonfoil) | — | not added |")
  end
end
```

  ("Reads the finish from the lot after an edit": changing that lot's finish to foil makes S001's foil-versus-nonfoil comparison wrong, which shows the lot is read rather than the entry.)
- [ ] Run `bin/rspec spec/lib/collector/scanner_findings_spec.rb spec/lib/collector/scanner_findings/sitting_report_spec.rb`. Expect failures.
- [ ] In `lib/collector/scanner_findings.rb`:
  - In `truth_record`, add the key `"finish" => row["finish"].presence || (row["foil"].to_s.casecmp?("yes") ? "foil" : "nonfoil"),` after `"foil" => …,`.
  - Add these module functions before `identity_names`:

```ruby
    # One line of the rates spec 009's tuning compares (AC-6.2–AC-6.4, AC-6.6), each with its sample size.
    def headline(records)
      set_line = records.select { SET_LINE_ERAS.include?(it["era"]) }
      foils, plain = set_line.partition { it["foil"] }
      found = records.select { it.key?("outline") }
      [ "right card first #{rate(records) { in_top?(it, "final_candidates", 1) }}", "top 3 #{rate(records) { in_top?(it, "final_candidates", 3) }}",
        "exact printing #{rate(set_line) { printing_identified?(it) }} (foils #{rate(foils) { printing_identified?(it) }}, " \
        "non-foils #{rate(plain) { printing_identified?(it) }})", "name read #{rate(records) { name_read?(it) }}",
        ("outline found #{rate(found) { it["outline"] == "found" }}" if found.any?) ].compact.join("; ")
    end

    def rate(rows, &) = Rate.new(hits: rows.count(&), total: rows.size)

    # [gained, lost]: files whose raw name strip read the name in one run and not in the other (AC-6.4).
    def name_read_changes(before, after)
      was = before.to_h { [ it["file"], name_read?(it) ] }
      now = after.to_h { [ it["file"], name_read?(it) ] }
      [ now.select { |file, read| read && !was[file] }.keys, now.select { |file, read| !read && was[file] }.keys ]
    end

    # Spec 009 AC-6.5: the separator read between set code and language, tallied by the card's real finish.
    def foil_markers(results, truth)
      known = Catalog::Set.where(collectible_type: "mtg").pluck(:code).to_set(&:upcase)
      results.filter_map do |result|
        next unless (record = truth[result["file"]])

        line = MTG::CollectorLine.set_line(result["collector_text"].to_s.unicode_normalize(:nfkc).upcase, known)
        [ record["foil"] ? "foil" : "non-foil", line ? line[:marker].to_s.presence || "(none)" : "(no set line)" ]
      end.tally
    end

    # Spec 009 AC-9.1: the live sitting's cards that an earlier corpus already used, by card name.
    def overlaps(fresh, earlier)
      fresh.flat_map do |card|
        earlier.flat_map do |label, photos|
          photos.select { it["name"] == card["name"] }.map do |old|
            "#{card["file"]} #{card["name"]} is #{label} #{old["file"]} (#{old["external_key"] == card["external_key"] ? "the same printing" : "another printing"})"
          end
        end
      end
    end
```

- [ ] Write `lib/collector/scanner_findings/sitting_report.rb`:

```ruby
# Spec 009 AC-9.1: the live sitting, scored. Each manifest row's captures carry the reading keys the page minted. The events
# measurement mode recorded (AC-9.2) and the sitting entries those keys made give the outcome: the printing and finish the
# card ended as (read from its lot, so an edit counts), against the row's ground truth, and the corrections on the way. Run it
# before "Done", which discards the entries. Medians here are conventional: the mean of the middle two for an even count.
class Collector::ScannerFindings::SittingReport
  KINDS = [ "right first time", "right after a correction", "wrong", "not added" ].freeze
  CORRECTIONS = [ "a candidate other than the first", "Other printings", "Undo and re-add", "details edited" ].freeze

  Outcome = Data.define(:file, :truth, :entry, :finish, :corrections, :scans, :name_text, :collector_text) do
    def added? = !entry.nil?
    def right? = added? && entry.printing.external_key == truth["external_key"] && finish == truth["finish"]

    def kind
      if !added? then "not added"
      elsif !right? then "wrong"
      elsif corrections.any? then "right after a correction"
      else "right first time"
      end
    end
  end

  def initialize(run:, account:, ground_truth:)
    @run = run
    @account = account
    @truth = JSON.parse(Pathname(ground_truth).expand_path.read).fetch("photos").to_h { [ it["file"], it ] }
  end

  def outcomes
    @outcomes ||= @run.rows.filter_map do |row|
      next unless (truth = @truth[row.file])

      captures = @run.captures(row)
      keys = captures.filter_map { it["reading_key"] }
      final = Scanner::SittingEntry.kept.where(account: @account, reading_key: keys).includes(:lot, printing: :set).order(:created_at).last
      Outcome.new(file: row.file, truth:, entry: final, finish: final && (final.lot ? final.lot.finish : final.finish),
        corrections: corrections(@run.events(row)), scans: captures.size,
        name_text: captures.first&.fetch("name_text", nil), collector_text: captures.first&.fetch("collector_text", nil))
    end
  end

  # Seconds from the previous add to each add, in the order the adds happened; the first add has none.
  def times
    adds = @run.rows.flat_map { @run.events(it) }.select { it["kind"] == "add" }.map { Time.iso8601(it["at"]) }.sort
    adds.each_cons(2).map { |earlier, later| (later - earlier).round(1) }
  end

  def to_markdown
    groups = { "all" => outcomes, "foil" => outcomes.select { it.truth["foil"] }, "non-foil" => outcomes.reject { it.truth["foil"] } }
    rows = groups.map { |label, list| "| #{label} | #{KINDS.map { |kind| "#{list.count { it.kind == kind }}/#{list.size}" }.join(" | ")} |" }
    corrections = CORRECTIONS.map { |kind| "#{kind}: #{outcomes.count { it.corrections.include?(kind) }}" }.join("; ")
    seconds = times
    others = outcomes.reject { it.kind == "right first time" }.map do |outcome|
      "| #{outcome.file} | #{label(outcome.truth["name"], outcome.truth["set_code"], outcome.truth["collector_number"], outcome.truth["finish"])} | " \
        "#{outcome.added? ? label(outcome.entry.printing.name, outcome.entry.printing.set.code, outcome.entry.printing.number, outcome.finish || "—") : "—"} | " \
        "#{outcome.kind} | #{outcome.corrections.join("; ").presence || "—"} | #{cell(outcome.name_text)} | #{cell(outcome.collector_text)} | |"
    end
    [ "| Cards | #{KINDS.join(" | ")} |", "|---|---|---|---|---|", *rows, "", "Corrections (a card can have several): #{corrections}.", "",
      "Time per card, from the previous add (conventional median): median #{median(seconds) || "n/a"} s, slowest #{seconds.max || "n/a"} s (n=#{seconds.size}).",
      "", "| File | Expected | Ended as | Outcome | Corrections | Name strip | Collector strip | Likely cause |", "|---|---|---|---|---|---|---|---|",
      *others ].join("\n")
  end

  private
    def corrections(events)
      ranks = events.select { it["kind"] == "add" }.map { it["rank"] }
      [ ("a candidate other than the first" if ranks.any? { %w[2 3].include?(it) }), ("Other printings" if ranks.include?("other")),
        ("Undo and re-add" if events.any? { it["kind"] == "undo" }), ("details edited" if events.any? { it["kind"] == "details" }) ].compact
    end

    def median(values)
      return nil if values.empty?

      sorted = values.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : ((sorted[middle - 1] + sorted[middle]) / 2.0).round(1)
    end

    def label(name, set_code, number, finish) = "#{name} (#{set_code.upcase} · #{number}, #{finish})"

    def cell(text) = text.to_s.gsub("|", "\\|").gsub(/\s+/, " ")
end
```

- [ ] In `lib/collector/scanner_findings/report.rb`:
  - Add `format_version: 2` to `initialize`'s keywords and `@format_version = format_version` to its body.
  - In `write_fixtures!`, replace both `"format_version" => 2` with `"format_version" => @format_version`. Replace the results slice with `live.map { it.slice("file", "name_text", "collector_text", "ms", "user_agent", "captured_at", "parsed", "lookup", *(@format_version >= 3 ? %w[outline detect_ms warp_ms] : [])) }`.
  - In `rescore`'s merge (`lib/collector/scanner_findings.rb`), change `result.slice("file", "name_text", "collector_text", "ms", "user_agent", "captured_at")` to `result.slice("file", "name_text", "collector_text", "ms", "user_agent", "captured_at", "outline", "detect_ms", "warp_ms")`.
  - In `timings`, before the `"Devices:` part, add `#{detection_timing}`. Then add the private method:

```ruby
    def detection_timing
      detect = live.filter_map { it["detect_ms"] }
      warp = live.filter_map { it["warp_ms"] }
      return "" if detect.empty?

      "Detection on the device: median #{findings.percentile(detect, 50)} ms, slowest #{detect.max} ms (n=#{detect.size}); straightening: " \
        "median #{findings.percentile(warp, 50)} ms, slowest #{warp.max || "n/a"} ms (n=#{warp.size}). "
    end
```

- [ ] Add to `spec/lib/collector/scanner_findings/report_spec.rb`:

```ruby
  it "writes format version 3 with the outline and the detector's timings (spec 009 AC-9.4)" do
    described_class.new(run:, output: dir, format_version: 3).write_fixtures!
    expect(JSON.parse(dir.join("phase1_ocr_results.json").read)).to include("format_version" => 3)
  end
```

- [ ] Append to `lib/tasks/scanner.rake`, inside the namespace:

```ruby
  desc "Spec 009: derived folders for the spike's halves (symlinked photos, one manifest and ground truth each) under ~/card-scanner-corpus/derived"
  task derive_halves: :environment do
    corpus = Pathname(File.expand_path(ENV.fetch("CARD_SCANNER_CORPUS", "~/card-scanner-corpus")))
    fixtures = Rails.root.join("spec/fixtures/card_scanner")
    halves = JSON.parse(fixtures.join("phase2_split.json").read).fetch("halves")
    sources = { "phase0" => [ corpus, fixtures.join("ground_truth.json") ], "new" => [ corpus.join("phase1-live"), fixtures.join("phase1_live_ground_truth.json") ] }
    %w[development held_out].each do |half|
      out = corpus.join("derived", half).tap(&:mkpath)
      rows, truth = [], []
      sources.each do |key, (folder, truth_file)|
        files = halves.fetch(key).fetch(half)
        manifest = folder.join("manifest.csv").readlines(chomp: true)
        header = manifest.first.split(",")
        manifest.drop(1).map { header.zip(it.split(",", -1)).to_h }.select { files.include?(it["file"]) }.each do |row|
          link = out.join(row["file"])
          link.make_symlink(folder.join(row["file"])) unless link.symlink? || link.exist?
          rows << [ row["file"], row["set"], row["number"], row["foil"], row["era"].to_s ].join(",")
        end
        truth.concat(JSON.parse(truth_file.read).fetch("photos").select { files.include?(it["file"]) })
      end
      out.join("manifest.csv").write(([ "file,set,number,foil,era" ] + rows).join("\n") + "\n")
      out.join("ground_truth.json").write(JSON.pretty_generate("photos" => truth, "errors" => []))
      puts "#{half}: #{rows.size} photos, #{truth.size} truth records -> #{out}"
    end
  end

  desc "Spec 009 AC-6.4, AC-6.6: rates of the configured measurement run against GROUND_TRUTH; COMPARE_DIR names a run to diff names with"
  task detected_score: :environment do
    run = Scanner::MeasurementRun.current
    abort "Measurement mode is off; run this in development." unless run
    truth = JSON.parse(Pathname(ENV.fetch("GROUND_TRUTH")).expand_path.read).fetch("photos").to_h { [ it["file"], it ] }
    records = Collector::ScannerFindings.rescore(truth, run.measured_captures)
    puts Collector::ScannerFindings.headline(records)
    if (other = ENV["COMPARE_DIR"].presence)
      manifest = Rails.configuration.x.scanner_measurement.fetch(:manifest)
      before = Collector::ScannerFindings.rescore(truth, Scanner::MeasurementRun.new(manifest:, dir: other).measured_captures)
      gained, lost = Collector::ScannerFindings.name_read_changes(before, records)
      puts "Names now read in full: #{gained.join(", ").presence || "none"}. No longer read: #{lost.join(", ").presence || "none"}."
    end
  end

  desc "Spec 009 AC-6.2, AC-6.3: rates of a desktop replay of the configured run against GROUND_TRUTH"
  task :replay_score, [ :label ] => :environment do |_task, args|
    run = Scanner::MeasurementRun.current
    abort "Measurement mode is off; run this in development." unless run
    truth = JSON.parse(Pathname(ENV.fetch("GROUND_TRUTH")).expand_path.read).fetch("photos").to_h { [ it["file"], it ] }
    records = Collector::ScannerFindings.rescore(truth, run.replays.fetch(args.fetch(:label)))
    puts Collector::ScannerFindings.headline(records)
    puts "IMG_6785 name read: #{records.find { it["file"] == "IMG_6785.jpeg" }&.then { Collector::ScannerFindings.name_read?(it) }.inspect}"
  end

  desc "Spec 009 AC-6.5: the set-line separator read on the new corpus's live captures, by real finish, and what the shipped markers mark"
  task foil_markers: :environment do
    fixtures = Rails.root.join("spec/fixtures/card_scanner")
    truth = JSON.parse(fixtures.join("phase1_live_ground_truth.json").read).fetch("photos").to_h { [ it["file"], it ] }
    results = JSON.parse(fixtures.join("phase1_live_ocr_results.json").read).fetch("results")
    Collector::ScannerFindings.foil_markers(results, truth).sort.each { |(finish, marker), count| puts "#{finish}\t#{marker.inspect}\t#{count}" }
    known = Catalog::Set.where(collectible_type: "mtg").pluck(:code)
    marked = results.filter_map { (record = truth[it["file"]]) && [ record["foil"], MTG::CollectorLine.parse(it["collector_text"], known_set_codes: known).foil ] }
    puts "Marked as foil: foils #{marked.count { |foil, hint| foil && hint }}/#{marked.count(&:first)}, " \
      "non-foils #{marked.count { |foil, hint| !foil && hint }}/#{marked.count { !it.first }} (markers #{MTG::CollectorLine::FOIL_MARKERS.inspect})"
  end

  desc 'Spec 009 AC-9.1: abort if the live sitting reuses a card from an earlier corpus: bin/rails "scanner:overlap[path/to/manifest.csv]"'
  task :overlap, [ :manifest ] => :environment do |_task, args|
    fresh = Collector::ScannerFindings.ground_truth(Pathname(args.fetch(:manifest)).expand_path.read)
    abort "Ground truth errors: #{fresh["errors"].inspect}" if fresh["errors"].any?
    fixtures = Rails.root.join("spec/fixtures/card_scanner")
    earlier = { "Phase 0" => "ground_truth.json", "the tuning cards" => "phase1_tuning_ground_truth.json", "the new corpus" => "phase1_live_ground_truth.json" }
      .transform_values { JSON.parse(fixtures.join(it).read).fetch("photos") }
    clashes = Collector::ScannerFindings.overlaps(fresh["photos"], earlier)
    abort(([ "These cards were used before:" ] + clashes).join("\n")) if clashes.any?
    puts "#{fresh["photos"].size} cards, none used by an earlier corpus."
  end

  desc "Spec 009 AC-9.1: score the live sitting (before Done): SCANNER_EMAIL=… GROUND_TRUTH=… bin/rails scanner:sitting_findings"
  task sitting_findings: :environment do
    run = Scanner::MeasurementRun.current
    abort "Measurement mode is off; run this in development." unless run
    account = User.find_by!(email_address: ENV.fetch("SCANNER_EMAIL")).account
    puts Collector::ScannerFindings::SittingReport.new(run:, account:, ground_truth: ENV.fetch("GROUND_TRUTH")).to_markdown
  end
```

  In the existing `findings` task, add `format_version: ENV.fetch("FORMAT_VERSION", "2").to_i` to the `Report.new` keyword hash.
- [ ] Run `bin/rspec spec/lib/collector spec/models/scanner spec/requests/scanner`. Expect 0 failures. Commit: `feat(findings): add spec 009's sitting report and tuning tasks (009)`.

---

## Phase 9: Reading refinements, the tuning runs and the freeze

**Implements:** Story 6, FR-3 (refinements), FR-4 (outline completion) | **Satisfies:** AC-6.2, AC-6.3, AC-6.4, AC-6.5 (markers fixed from the stored text), AC-6.6, AC-6.7
**Files:** `app/javascript/scanner/geometry.js`, `app/javascript/scanner/detector.js` (settings), `app/javascript/controllers/replay_controller.js`, `app/controllers/scanner/measurements/replays_controller.rb`, `app/views/scanner/measurements/replays/show.html.erb`, `script/scanner/replay.rb`, `app/models/mtg/collector_line.rb` (markers), `spec/system/scanner_detection_spec.rb`, `tmp/spec009/*` (ignored outputs for `research.md`)
**Interfaces:** Consumes: Phase 7's `cropStrips` and `SETTINGS`; Phase 8's tasks. Produces: `scanner/geometry`'s `REFINE` and `refineStrip(key, canvas, settings)`; the replay page's `refine=1`; and the freeze commit (its hash goes into `research.md`).

- [ ] Add to `spec/support/scanner_helpers.rb`, inside the module:

```ruby
  # Runs the page's refineStrip on fresh 40×10 strips (20 grey with a 200 block): the name strip with invertBelow 128, the
  # collector strip binarized at twice the size (spec 009 AC-6.2, AC-6.3).
  def refine_synthetic_strips
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      #{MODULES_JS}
      window.__modules.then(({ geometry }) => {
        const strip = () => {
          const canvas = Object.assign(document.createElement("canvas"), { width: 40, height: 10 })
          const context = canvas.getContext("2d")
          context.fillStyle = "rgb(20,20,20)"; context.fillRect(0, 0, 40, 10)
          context.fillStyle = "rgb(200,200,200)"; context.fillRect(5, 3, 10, 4)
          return canvas
        }
        const inverted = geometry.refineStrip("name", strip(), { invertBelow: 128 })
        const flat = geometry.refineStrip("collector", strip(), { binarize: true, scale: 2 })
        const pixel = (canvas, x, y) => canvas.getContext("2d").getImageData(x, y, 1, 1).data[0]
        done({ background: pixel(inverted, 0, 0), text: pixel(inverted, 6, 4), size: [ flat.width, flat.height ], levels: [ pixel(flat, 0, 0), pixel(flat, 12, 8) ] })
      })
    JS
  end
```

  Then add a failing example to `spec/system/scanner_detection_spec.rb`:

```ruby
  it "inverts a mostly dark name strip and binarizes a collector strip when told to (AC-6.2, AC-6.3)" do
    expect(refine_synthetic_strips).to include("background" => 235, "text" => 55, "size" => [ 80, 20 ], "levels" => [ 0, 255 ])
  end
```

- [ ] Run it. Expect it to FAIL (`geometry.refineStrip is not a function`).
- [ ] In `app/javascript/scanner/geometry.js`:
  - After `INVERT_DARK_ROWS`, add:

```js
// Spec 009's reading refinements (AC-6.2, AC-6.3), applied to a strip after the steps above, so a strip stored by an earlier
// run can be replayed with them exactly. name.invertBelow inverts the whole name strip when its mean luminance is below it
// (light names on dark bars); collector.binarize applies an Otsu threshold and collector.scale enlarges further (faint
// foil lines). Off until the tuning runs choose them; frozen before the live sitting (AC-6.7).
export const REFINE = { name: { invertBelow: null }, collector: { binarize: false, scale: 1 } }
```

  - In `cropStrips`, replace `return [ key, canvas ]` with `return [ key, refineStrip(key, canvas) ]`.
  - Append:

```js
export function refineStrip(key, canvas, settings = REFINE[key]) {
  let strip = canvas
  if (settings.scale && settings.scale !== 1) {
    strip = Object.assign(document.createElement("canvas"), { width: Math.round(canvas.width * settings.scale), height: Math.round(canvas.height * settings.scale) })
    strip.getContext("2d", { willReadFrequently: true }).drawImage(canvas, 0, 0, strip.width, strip.height)
  }
  const context = strip.getContext("2d", { willReadFrequently: true })
  if (settings.invertBelow != null && meanLuminance(context, strip.width, strip.height) < settings.invertBelow) invertAll(context, strip.width, strip.height)
  if (settings.binarize) binarize(context, strip.width, strip.height)
  return strip
}

function meanLuminance(context, width, height) {
  const pixels = context.getImageData(0, 0, width, height).data
  let sum = 0
  for (let i = 0; i < pixels.length; i += 4) sum += 0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2]
  return sum / (width * height)
}

function invertAll(context, width, height) {
  const image = context.getImageData(0, 0, width, height)
  const pixels = image.data
  for (let i = 0; i < pixels.length; i += 4) { pixels[i] = 255 - pixels[i]; pixels[i + 1] = 255 - pixels[i + 1]; pixels[i + 2] = 255 - pixels[i + 2] }
  context.putImageData(image, 0, 0)
}

// Otsu's threshold on the (already grey) strip: every pixel becomes black or white.
function binarize(context, width, height) {
  const image = context.getImageData(0, 0, width, height)
  const pixels = image.data
  const histogram = new Array(256).fill(0)
  for (let i = 0; i < pixels.length; i += 4) histogram[pixels[i]]++
  const total = width * height
  let sum = 0
  for (let t = 0; t < 256; t++) sum += t * histogram[t]
  let background = 0, backgroundSum = 0, best = -1, threshold = 127
  for (let t = 0; t < 256; t++) {
    background += histogram[t]
    if (background === 0) continue
    const foreground = total - background
    if (foreground === 0) break
    backgroundSum += t * histogram[t]
    const between = background * foreground * (backgroundSum / background - (sum - backgroundSum) / foreground) ** 2
    if (between > best) { best = between; threshold = t }
  }
  for (let i = 0; i < pixels.length; i += 4) { const value = pixels[i] > threshold ? 255 : 0; pixels[i] = pixels[i + 1] = pixels[i + 2] = value }
  context.putImageData(image, 0, 0)
}
```

  (In the example, the strip is 20 grey with a 200 block: the mean of 38 ((360 × 20 + 40 × 200) / 400) is below 128, so 20 becomes 235 and 200 becomes 55. Otsu's threshold falls between 20 and 200, so the levels are 0 and 255.)
- [ ] Run `bin/rspec spec/system/scanner_detection_spec.rb spec/system/scanner_spec.rb`. Expect 0 failures.
- [ ] Make the replay apply the refinements to strips stored before them:
  - In `app/controllers/scanner/measurements/replays_controller.rb#show`, add `@refine = params[:refine] == "1"`.
  - In `app/views/scanner/measurements/replays/show.html.erb`, add `data-replay-refine-value="<%= @refine %>"` to the `main` tag.
  - In `app/javascript/controllers/replay_controller.js`:
    - add `refine: Boolean` to `static values`
    - import `refineStrip` from `"scanner/geometry"`
    - replace the `strips` line with:

```js
        const strips = { name: await this.strip(file, "name"), collector: await this.strip(file, "collector") }
        if (this.refineValue) Object.keys(strips).forEach((key) => { strips[key] = refineStrip(key, strips[key]) })
```

  - In `script/scanner/replay.rb`, change the navigation URL's query to `?label=#{label}#{ENV["REFINE"] == "1" ? "&refine=1" : ""}` and add `REFINE=1` to the usage comment ("re-applies spec 009's refinements to strips stored before them").
  - Commit: `feat(scanner): add the spec 009 strip refinements, off until tuned (009)`.
- [ ] **Foil marker (AC-6.5).**
  1. Run `bin/rails scanner:foil_markers | tee tmp/spec009/foil_markers.txt`.
  2. Set `MTG::CollectorLine::FOIL_MARKERS` to every separator the tally shows on foils and never on non-foils, keeping `★` unless it appears on a non-foil.
  3. If the list changes, add the new marker as a case to `spec/models/mtg/collector_line_spec.rb` (`expect(described_class.parse("R 0123\nMOM <marker> EN", known_set_codes: %w[mom]).foil).to be(true)`), and run `bin/rspec spec/models/mtg`.
  4. Rerun the task to record the marked counts for foils and non-foils.
  5. Commit: `feat(scanner): read the foil marker the stored captures show (009)`, with a `Ruling:` line naming the markers.
- [ ] **Strip refinements on the stored live strips (AC-6.2, AC-6.3).**
  1. Start the dev server as a background task with `COLLECTOR_SCANNER_MANIFEST=$HOME/card-scanner-corpus/phase1-live/manifest.csv COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/phase1-live`.
  2. For each variant below, edit `REFINE` in the working tree (uncommitted) and run `REFINE=1 bundle exec ruby script/scanner/replay.rb <label>`. Then run `GROUND_TRUTH=$HOME/card-scanner-corpus/phase1-live/ground_truth.json bin/rails "scanner:replay_score[<label>]" | tee -a tmp/spec009/refine.txt` with the same environment.
  3. The variants, labelled `p9-off` (all off; the reference), `p9-bin` (`collector.binarize`), `p9-x15` (`collector.scale: 1.5`), `p9-bin-x15` (both), `p9-inv100` and `p9-inv128` (`name.invertBelow`).
  4. Ship a collector variant only if foil exact printing rises against `p9-off` and non-foil exact printing doesn't fall (AC-6.2). If the best foil gain costs non-foils, keep it off and put the trade to the maintainer.
  5. Ship a name threshold only if IMG_6785's name is read and the overall name-read rate doesn't fall (AC-6.3).
  6. Set `REFINE` to the chosen values. Commit: `feat(scanner): choose the strip refinements from the stored live strips (009)`, with a `Ruling:` line and the rates.
- [ ] **Detected photos on the development half (AC-6.4, AC-6.6).**
  1. Run `bin/rails scanner:derive_halves`. Expect `development: 52 photos, 52 truth records` and `held_out: 47 photos, 47 truth records`.
  2. For each variant below, restart the dev server with `COLLECTOR_SCANNER_MANIFEST=$HOME/card-scanner-corpus/derived/development/manifest.csv COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/spec009/dev-<variant>`. Then run `SCANNER_EMAIL=findings@localhost SCANNER_PASSWORD=<pw> bundle exec ruby script/scanner/photo_run.rb` and `GROUND_TRUTH=$HOME/card-scanner-corpus/derived/development/ground_truth.json bin/rails scanner:detected_score | tee -a tmp/spec009/detected_dev.txt`. Add `COMPARE_DIR=$HOME/card-scanner-corpus/runs/spec009/dev-v0` for every variant after `v0`.
  3. The variants (edits to `DETECTED_STRIPS` and `SETTINGS`):
     - `v0`: nothing changed (expect close to the spike's development top 3 of 43/52; note any gap)
     - `v1`: `completeTolerance: 0.08`
     - `v2`: `DETECTED_STRIPS.name.w: 0.82`
     - `v3`: `DETECTED_STRIPS.name.y: 0.04`
     - `v4`: the winners of `v1`–`v3` combined
  4. Choose by development top 3 (final ranking), then right card first, then exact printing. A change that doesn't improve on `v0` stays off.
  5. If `v2`'s wider name strip is kept, apply the same `name.w` to the live `STRIPS` as well. Strips are fractions of the card, and IMG_6761's long name was a live capture. The live sitting measures the effect. Record that as a `Ruling:`.
  6. The development rates are biased (AC-6.6).
- [ ] **The freeze (AC-6.7).**
  1. Commit the chosen `DETECTED_STRIPS`, `STRIPS`, `SETTINGS.completeTolerance` and `REFINE` (with `STRONG_NAME_SCORE`, `LONG_TOKEN_SHARE` and `FOIL_MARKERS` already committed) as `chore(scanner): freeze the spec 009 settings (009)`. List every setting's value in the body.
  2. Record `git rev-parse HEAD` as the settings commit.
  3. Run `bin/rspec`; expect 0 failures.
  4. From here until the held-out run and the live sitting finish, no commit may touch `app/javascript/scanner`, `app/models/mtg` or `app/models/catalog/name_index.rb`. Guard: `git diff --exit-code <settings commit> -- app/javascript/scanner app/models/mtg app/models/catalog/name_index.rb` must be empty before each run.
- [ ] **Held out, once (AC-6.6).**
  1. Restart the dev server with `COLLECTOR_SCANNER_MANIFEST=$HOME/card-scanner-corpus/derived/held_out/manifest.csv COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/spec009/held-frozen`.
  2. Run `photo_run.rb`, then `GROUND_TRUTH=$HOME/card-scanner-corpus/derived/held_out/ground_truth.json bin/rails scanner:detected_score | tee tmp/spec009/detected_held.txt`.
  3. Compare with the spike's frozen held-out result: top 3 32/47, right card first 27/47, exact printing 13/43. There is no threshold; report it either way.

---

## Phase 10: The live sitting, the phone photo run, and the findings

**Implements:** Story 9, FR-5, NFR Performance (phone figures) | **Satisfies:** AC-9.1, AC-9.2, AC-9.3, AC-9.4, AC-9.5, AC-7.3 (recorded), AC-5.4 (recorded), AC-6.1–AC-6.6 (recorded), AC-6.7 (the commit named)
**Files:** `docs/specs/009-card-scanner-confirm-flow/research.md`, `spec/fixtures/card_scanner/phase2_sitting_{ocr_results,name_matches}.json`, `spec/fixtures/card_scanner/phase2_sitting_photos_{ocr_results,name_matches}.json`, `docs/adr/0005-hand-written-card-detector-for-the-photo-path.md`, `README.md`, `CLAUDE.md`, `.claude/memory/card-scanner-direction.md`
**Interfaces:** Consumes: everything above. Produces: the findings.

- [ ] **The pile (the maintainer's manifest).**
  1. Run `bin/rails "scanner:ground_truth[$HOME/card-scanner-corpus/phase2-sitting/manifest.csv]"`. Expect `35 rows resolved, 0 errors`; resolve any error with the maintainer, following the corpus-manifest practice.
  2. Run `bin/rails "scanner:overlap[$HOME/card-scanner-corpus/phase2-sitting/manifest.csv]"`. Expect `35 cards, none used by an earlier corpus.`; if any are, ask the maintainer to swap those cards.
  3. Check the settings guard (Phase 9).
- [ ] **The sitting (the maintainer, on the iPhone).**
  1. Make the HTTPS dev server per `bin/dev-certificate`, as a background task, bound for the phone, with `COLLECTOR_SCANNER_MANIFEST=$HOME/card-scanner-corpus/phase2-sitting/manifest.csv COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/spec009/sitting`.
  2. The maintainer signs in on the phone as `sitting@localhost` and opens `/scanner/measurement`. For each card, in manifest order, they:
     - capture it once (a retake only if the first capture is unusable, as in spec 007's protocol)
     - add it, correcting as needed: another candidate, Other printings, or Undo and re-add
     - open "Details" only to edit a copy
  3. The maintainer doesn't press Done.
  4. Then run `SCANNER_EMAIL=sitting@localhost GROUND_TRUTH=$HOME/card-scanner-corpus/phase2-sitting/ground_truth.json bin/rails scanner:sitting_findings | tee tmp/spec009/sitting.md` with the same environment (AC-9.1, AC-9.2).
  5. Write the fixtures with `FIXTURES=1 FORMAT_VERSION=3 FIXTURES_PREFIX=phase2_sitting RUN_LABEL="Spec 009 sitting" GROUND_TRUTH=$HOME/card-scanner-corpus/phase2-sitting/ground_truth.json bin/rails scanner:findings | tee tmp/spec009/sitting_findings.md` (AC-9.4).
  6. Check that the fixtures hold no image or strip: `git status --porcelain spec/fixtures/card_scanner` should list only `?? …json` lines.
- [ ] **The phone photo run (AC-9.3).**
  1. Write `$HOME/card-scanner-corpus/phase2-sitting-photos/manifest.csv` with the rows of the cards the maintainer photographed (at least 10, same columns), and its ground truth with `scanner:ground_truth`.
  2. Restart the server with that manifest and `COLLECTOR_SCANNER_RUN_DIR=$HOME/card-scanner-corpus/runs/spec009/sitting-photos`.
  3. On `/scanner/measurement`, the maintainer picks each photo through "Use a photo" for its row.
  4. Run `FIXTURES=1 FORMAT_VERSION=3 FIXTURES_PREFIX=phase2_sitting_photos RUN_LABEL="Spec 009 phone photos" GROUND_TRUTH=… bin/rails scanner:findings | tee tmp/spec009/phone_photos.md` and `GROUND_TRUTH=… bin/rails scanner:detected_score | tee -a tmp/spec009/phone_photos.md`. These give the outline found, right first, top 3 and detection timings.
  5. Then the maintainer may press Done on the sitting.
  6. Commit the four fixture files: `test(findings): record the spec 009 sitting and phone photos as text fixtures (009)`.
- [ ] **Timings and size (NFR Performance).** Run Phase 11's timing spec and asset-growth script now and keep their output (`tmp/spec009/timings.txt`).
- [ ] **Write `docs/specs/009-card-scanner-confirm-flow/research.md`.** Every number carries its sample size, development rates are labelled biased, and desktop and phone figures are labelled as such. No pass threshold. Sections:
  1. Environment: the catalog `source_version`, the settings commit, the devices and browsers.
  2. Ranking (AC-5.1, AC-5.4): the sweep table, the chosen threshold, the comparison against the spec 007 baseline (`tmp/spec009/ranking.md`), and the bias statement.
  3. Query cleaning (AC-6.1).
  4. The foil marker (AC-6.5).
  5. Strip refinements on the stored live strips (AC-6.2, AC-6.3).
  6. The detector against the spike (AC-7.3, `parity.txt`).
  7. Detected photos (AC-6.4, AC-6.6): the development variants (biased) and the held-out run against 32/47, 27/47, 13/43.
  8. The live sitting (AC-9.1, AC-9.2): outcomes by finish, corrections by kind, time per card.
  9. The phone photo path (AC-9.3).
  10. Timings and sizes against the targets (NFR Performance).
  11. Every card that didn't end right, with its read text and likely cause (AC-9.5).
  12. Recommendations for the art-matching spec, naming the cards where art evidence would have changed the outcome (AC-9.5).
- [ ] **Update ADR 0005's Consequences** (AC-9.5) with the phone timing and accuracy from §9, and note the outline completion's result from §7.
- [ ] **Docs.**
  - `README.md`: the scanner adds cards and is linked from the navigation; HTTPS is still needed only for the live camera. Keep the phrases `spec/readme_spec.rb` asserts ("HTTPS", "only the photo picker works", "Docker Compose", "Kamal", "ssl: true", "registry.npmjs.org"), and run `bin/rspec spec/readme_spec.rb`.
  - `CLAUDE.md`, in Project Status: accounts, collections (lots) and the scanner's confirm flow exist.
  - `CLAUDE.md`, the "Card scanner" fact: linked from the navigation; sittings in `scanner_sittings`/`scanner_sitting_entries`; `script/scanner/detector_parity.rb`; the spec 009 tasks.
  - `.claude/memory/card-scanner-direction.md`: spec 009's state and the next step (the art-matching spec).
- [ ] Commit: `docs(009): record the spec 009 findings, ADR 0005's phone figures and the docs`.

---

## Phase 11: Integration Verification

**Implements:** All FRs, NFRs | **Satisfies:** All ACs; NFR Reliability (10 runs), NFR Performance (measured), NFR Security
**Files:** `spec/system/scanner_timing_spec.rb`, `spec/rails_helper.rb`, `script/scanner/asset_growth.rb`

- [ ] In `spec/rails_helper.rb`, inside `RSpec.configure do |config|`, add `  config.filter_run_excluding :timing unless ENV["SCANNER_TIMING"] # spec 009 NFR timings: measured, never gating`.
- [ ] Write `spec/system/scanner_timing_spec.rb`. The JavaScript lives in helper methods, to keep each example within RuboCop's length limit, and the figures go to RSpec's reporter, since `RSpec/Output` forbids `puts`:

```ruby
require "rails_helper"

# Spec 009 NFR Performance, measured outside the gating suite: SCANNER_TIMING=1 bin/rspec spec/system/scanner_timing_spec.rb
RSpec.describe "Scanner timings", :timing, type: :system do
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

  before do
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  def report(message) = RSpec.configuration.reporter.message(message)

  def median(values)
    sorted = values.sort
    sorted.size.odd? ? sorted[sorted.size / 2] : (sorted[sorted.size / 2 - 1] + sorted[sorted.size / 2]) / 2.0
  end

  # Milliseconds from tapping Foil to #status changing, for one fresh reading.
  def time_scanner_add
    click_on "Capture"
    button = find("button[aria-label='Add Lightning Bolt MOM · 123 Foil']", wait: 30)
    page.execute_script(<<~JS)
      const status = document.getElementById("status")
      window.__added = null
      new MutationObserver((_, observer) => { window.__added = performance.now(); observer.disconnect() }).observe(status, { childList: true, subtree: true, characterData: true })
      window.__tapped = performance.now()
    JS
    button.click
    eventually("window.__added !== null")
    page.evaluate_script("window.__added - window.__tapped")
  end

  # Milliseconds for each of 20 Other printings frame requests, fetched from the page.
  def time_other_printings(url)
    page.evaluate_async_script(<<~JS, url)
      const [ url, done ] = arguments
      ;(async () => {
        const times = []
        for (let i = 0; i < 20; i++) {
          const started = performance.now()
          await (await fetch(url, { headers: { "Turbo-Frame": "scanner_printings" } })).text()
          times.push(performance.now() - started)
        }
        done(times)
      })()
    JS
  end

  it "adds, from tap to announcement, in a median of 500 ms or less (desktop)" do
    show_synthetic_card
    times = Array.new(10) { time_scanner_add }
    report "Add, tap to announcement: median #{median(times).round} ms, slowest #{times.max.round} ms (n=10, conventional median)"
    expect(median(times)).to be <= 500
  end

  it "answers Other printings for a card with 100 printings within 300 ms at the 95th percentile (desktop)" do
    100.times { |index| create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", number: (200 + index).to_s)) }
    times = time_other_printings(scanner_printings_path(card: identity.external_key, key: "d" * 32, set: "mom", number: "123"))
    p95 = times.sort[(0.95 * (times.size - 1)).ceil]
    report "Other printings, 100 printings: p95 #{p95.round} ms (n=20)"
    expect(p95).to be <= 300
  end
end
```

- [ ] Write `script/scanner/asset_growth.rb`:

```ruby
# Spec 009 NFR Performance: how much the scanner page's own assets grew, gzip -9, against main. The page loads every
# Stimulus controller and scanner module through the import map, and the app's stylesheets.
# Usage: bundle exec ruby script/scanner/asset_growth.rb
require "open3"
require "stringio"
require "zlib"

PATTERNS = %w[app/javascript/controllers app/javascript/scanner app/assets/stylesheets/collector].freeze

def gzip_size(text)
  return 0 if text.nil?

  io = StringIO.new
  Zlib::GzipWriter.wrap(io, Zlib::BEST_COMPRESSION) { it.write(text) }
  io.string.bytesize
end

def at_main(path)
  text, status = Open3.capture2("git", "show", "main:#{path}")
  status.success? ? text : nil
end

now = PATTERNS.flat_map { Dir["#{it}/**/*.{js,css}"] }
before = Open3.capture2("git", "ls-tree", "-r", "--name-only", "main", *PATTERNS).first.lines(chomp: true).grep(/\.(js|css)\z/)
rows = (now | before).sort.map { |path| [ path, gzip_size(at_main(path)), gzip_size(File.exist?(path) ? File.read(path) : nil) ] }
rows.reject { _2 == _3 }.each { |path, was, is| puts format("%-60s %7d -> %7d (%+d)", path, was, is, is - was) }
growth = rows.sum { _3 - _2 }
puts "Total growth, gzip -9: #{growth} bytes (target: at most 20 KB = 20,480 bytes)"
```

- [ ] Run `bin/ci`. Expect all steps green (RuboCop, Brakeman, bundler-audit, importmap audit, RSpec).
- [ ] Run the camera and scanner system specs 10 times in a row (NFR Reliability): `for i in $(seq 10); do bin/rspec spec/system/scanner_spec.rb spec/system/scanner_adding_spec.rb spec/system/scanner_sitting_spec.rb spec/system/scanner_detection_spec.rb || break; done`. Expect 10 passes.
- [ ] Run `SCANNER_TIMING=1 bin/rspec spec/system/scanner_timing_spec.rb | tee tmp/spec009/timings.txt` and `bundle exec ruby script/scanner/asset_growth.rb | tee -a tmp/spec009/timings.txt`. Report the figures in `research.md` §10, whatever they are.
- [ ] Walk the spec's ACs against the coverage map below and confirm each test exists and passes. Then use `sdd-superpowers:sdd-review` (Mode B), as a read-only Fable subagent, before merging.
- [ ] Commit: `test(scanner): measure the spec 009 timings and asset growth (009)`.

---

## Quickstart Validation

1. **Catalog:** `bin/setup --skip-server`, then `bin/rails runner 'Catalog::Refresh.new("mtg", trigger: "manual").call'`.
2. **Server:** `bin/dev`, then sign in at the worktree's port.
3. **Navigation:** the app bar and tab bar show "Scan", and the collection page shows "Scan cards".
4. **Adding:** on `/scanner`, capture a card (or "Use a photo" with any card photo). The candidates show their evidence and one button per finish. Tap "Foil": the status says "Added 1 × … to your collection.", the reading clears, the camera keeps running, and "This sitting: 1 card" appears.
5. **Other printings:** on another card, open "Other printings", add one from the list, and see it in the sitting.
6. **Undo:** tap "Undo" on an entry; the copy leaves the collection and the status says "Removed 1 × …".
7. **Details:** "Details" opens Edit copy; Save returns to the scanner with the sitting still open.
8. **Resume:** sign out and in again, open the scanner, and the sitting is still there.
9. **Done:** "Done" → "End sitting" shows "Added N cards in this sitting" once; a reload shows neither.
10. **Unguided photo:** pick a photo of a card taken off-centre; it is still read. Pick a photo with no card in it: the status says no card edge was found.

---

## Coverage map (self-review)

| AC | Phase | Test or record |
|---|---|---|
| AC-1.1 | 4 | readings_spec (buttons, single Add), sitting_spec (finish recorded) |
| AC-1.2, AC-1.6, AC-1.7 | 3, 4 | sitting_spec, sitting_entries_spec |
| AC-1.3 | 4 | sitting_entries_spec, scanner_adding_spec |
| AC-1.4, AC-1.5 | 3, 4 | sitting_spec, sitting_entries_spec, scanner_adding_spec (both buttons) |
| AC-2.1 | 2, 6 | readings_spec (marks, link) |
| AC-2.2–AC-2.6 | 6 | other_printings_spec, printings_spec, scanner_adding_spec |
| AC-3.1, AC-3.2 | 3, 4, 5 | sitting_spec, sittings_spec |
| AC-3.3 | 5 | scanner_sitting_spec |
| AC-3.4–AC-3.8 | 5 | sittings_spec |
| AC-4.1–AC-4.4 | 3, 5 | sitting_entry_spec, sittings_spec, scanner_sitting_spec |
| AC-5.1–AC-5.3, AC-5.5 | 2 | reading_spec, collector_number_spec |
| AC-5.4 | 1, 2 | `scanner:ranking` (findings §2) |
| AC-6.1 | 2 | name_index_spec, `scanner:ranking` name losses |
| AC-6.2, AC-6.3 | 9 | scanner_detection_spec (refineStrip), `replay_score` (findings §5) |
| AC-6.4, AC-6.6 | 9 | `detected_score` dev and held out (findings §7) |
| AC-6.5 | 2, 4, 6, 9 | reading_spec, readings_spec, printings_spec, `foil_markers` |
| AC-6.7 | 9 | the freeze commit and guard |
| AC-7.1, AC-7.2, AC-7.4, AC-7.6 | 7 | scanner_detection_spec |
| AC-7.3 | 7, 10 | detector_parity.rb (findings §6) |
| AC-7.5 | 7 | scanners_spec |
| AC-8.1–AC-8.3 | 4 | scanners_spec (links), spec 007's sign-in example |
| AC-8.4 | 4 | readings_spec |
| AC-9.1–AC-9.5 | 8, 10 | sitting_report_spec, measurement specs, findings §8–§12 |
| Error Scenarios: failed add, Other printings not loading | 4, 6 | scanner_adding_spec (server error kept in place; frame failure) |
| NFR Accessibility: Other printings announced | 6 | scanner_adding_spec ("Other printings of … are below.") |
| FR-1…FR-6, NFRs | 3–11 | as above; Global Constraints; Phase 11 |
