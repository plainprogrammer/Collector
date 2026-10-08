# Implementation Plan: Card Scanner — Art Matching on Live Capture

**Spec:** docs/specs/011-card-scanner-art-matching/spec.md (v1.1.3, Approved, reviewed three times)
**Decisions:** [ADR 0004](../../adr/0004-card-recognition-in-the-browser.md), [ADR 0006](../../adr/0006-art-fingerprint-and-index.md), [ADR 0007](../../adr/0007-art-search-in-the-browser.md) (Accepted); [ADR 0011](../../adr/0011-decode-art-images-with-imagemagick.md) (Accepted with this plan, 2026-10-08: the build's image decoder)
**Created:** 2026-10-07
**Revised:** 2026-10-08, after a read-only plan review (Fable, NEEDS REVISION; design, fingerprint ports and ranking confirmed).
- **Blocking fixes:** the existing `catalog:status` spec counts the new art line (Phase 9); the index controller's Brakeman SendFile warning is ignored with a justification, like `OcrAssetsController`'s (Phase 10); a missing `:aggregate_failures` (Phase 11).
- **Other fixes:** the artwork ids in the ranking spec come from a helper, not a constant in the group; tests never read `COLLECTOR_MTG_ART_MATCHING` from the environment; the build spec's helper is `run_build`, and `not_change` is defined in the file; `source_spec`'s existing subject is reused; AC-4.3 is asserted (the page moves to the newest index).
- **Added checks (Phase 15):** the production image's ImageMagick fingerprints spec 010's 134 agreement images the same as the desktop's (AC-3.10; ADR 0011 now says the image's agreement is unmeasured until then), and the index passes through Thruster gzip-encoded exactly once.
- **Still needs a run:** ImageMagick reading a PNG saved as `.jpg` in the build specs; headless Firefox's canvas giving a generated PNG's exact pixels; `Open3.capture2` accepting `err:` (a `capture3` fallback is given); the image's ImageMagick version.
**Approved:** 2026-10-08 (maintainer). **Data model:** [data-model.md](data-model.md). **Contracts:** [contracts/api.md](contracts/api.md).

## Global Constraints

- Art matching is off unless `COLLECTOR_MTG_ART_MATCHING` is `1`, `true`, `yes` or `on` (any case, surrounding spaces ignored). Every art behaviour depends on that one setting (FR-1).
- The fingerprint settings are those frozen at `39cdc6e` (`spikes/card_scanner/phase2/settings.json`, its `fingerprint` block). Nothing is tuned.
- The margin is 300 bits (`MTG::Reading::ART_MARGIN`), provisional, beside `STRONG_NAME_SCORE`.
- Rank order: confident art, then strong name, then collector line, then weak art, then name rank. Still at most 3 candidates.
- No frame, strip, photo or fingerprint leaves the device in normal use. The page sends recognised text, the reading key, and up to 10 artwork ids with distances (FR-5).
- Catalog data, the artwork table, build runs, the art cache and the index are global (no `account_id`). The collectible-agnostic core never names art (AC-2.4).
- External HTTP: Scryfall's `User-Agent`, `Accept: image/jpeg` for images, at least 100 ms between requests, timeouts, back-off on 429 and 5xx, 3 attempts, only `cards.scryfall.io` over HTTPS. WebMock in every spec.
- Migrations are reversible and safe for unattended `db:prepare`. After `bin/rails db:migrate`, restore `db/{cable,cache,queue}_schema.rb` with `git checkout` (they are rewritten as noise).
- UI uses the Collector design system's tokens and `c-*` classes; copy is sentence case, "you", no exclamation marks.
- `bin/ci` passes at every commit: each phase commits its tests with its code, never a failing test.
- Commits are Conventional Commits, one per step that changes behaviour, with the attribution trailer.

---

## Goal

Ship opt-in art matching on the live scanner: the catalog stores artwork ids, a background job builds a versioned art index from Scryfall's `small` images, the scanner page searches it on the device, confident art ranks first with its printing chosen among the artwork's printings, the confirm step says so, and a closing measurement re-scans spec 009's 35 cards.

**Facts established during planning (2026-10-07):**

- **Refresh.** `Catalog::Refresh#call` (`app/models/catalog/refresh.rb`) starts a `Catalog::RefreshRun`, returns early when another refresh is running (`return @run unless @run.running?`), and skips only a `scheduled` run whose version and languages were applied (`already_applied?`). `skip` rebuilds the name index if empty. Rows are rewritten when `EntryRecord#digest` changes, and the digest covers `extension` (`app/models/catalog/sources.rb`), so adding fields to the MTG extension rewrites every printing once.
- **Mapper.** `MTG::Scryfall::Mapper.faces` keeps `image_uris` `normal` and `large` only; `illustration_id` isn't stored anywhere. Adventure and split cards have `card_faces` without `image_uris`; the mapper merges the card's.
- **Client.** `MTG::Scryfall::Client` throttles at 100 ms with an injectable clock and sleeper, sends `Accept: application/json` from its private `request`, retries only on 429 in `get_json`, and `download` doesn't retry.
- **Ranking.** `MTG::Reading` (`app/models/mtg/reading.rb`) builds `by_card` (identity id → `Candidate`) from name candidates in name-rank order, replaces the collector-line card's slot when exactly one printing matched, then sorts by `Candidate#rank_key` (`[strong_name, collector_line?, name_rank || CANDIDATES]`) and takes 3. `ranked(score)` is used by `lib/collector/scanner_findings/ranking.rb`; `candidates` by the views and findings. `Candidate` is `Data.define(:entry, :evidence, :name_rank, :strong_name)`.
- **Name search on blank text** returns no candidates (`Catalog::NameIndex#search` → `exact("")`).
- **Scanner page.** `scanners/_scanner.html.erb` is rendered by `ScannersController` and `Scanner::MeasurementsController`; both include `ScannerPage` (the CSP: `connect-src 'self'`, `img-src` includes `data:`). `card_reader_controller.js#read` has the frame and the guide rect (`image`, `card`) for live captures (`source.outline === "live"`), sends `reading[name_text|collector_text|key]` with `fetch`, and dispatches `card-reader:read` for measurement mode before sending.
- **Measurement mode.** `Scanner::MeasurementRun` writes `<dir>/<file>/capture-NNN.json` (extras whitelisted by `EXTRA_FIELDS`), `events.jsonl` per row, and finds a row by reading key only after the capture JSON exists. `Scanner::Measurements::CapturesController` permits the capture fields explicitly.
- **Serving precedent.** `OcrAssetsController` uses `allow_unauthenticated_access`, `allow_before_first_user`, `expires_in 365.days, public: true, immutable: true`, `stale?(etag:, …)`, `send_file`.
- **Status task.** `catalog:status` (`lib/tasks/catalog.rake`) prints `RefreshRun#status_line` for the 10 newest runs.
- **Tests.** No Node: JS modules are tested in headless Firefox system specs by loading the page's modules through a nonce'd module script (`ScannerHelpers::MODULES_JS`). `scanner_sent` records the field names of every `FormData` the page posts. The test catalog download dir is `tmp/catalog`. `FakeCatalogSource` (`spec/support/fake_catalog_source.rb`) has no hooks today.
- **Image tools.** The dev machine has ImageMagick 7 (`magick`) and no libvips. The production image has libvips and no ImageMagick. GitHub's `ubuntu-latest` runner gets ImageMagick from `apt`. The spike decoded with `magick <file> -depth 8 ppm:-` and agreed with the browser to 0 bits (n=198 in spec 008, n=134 in spec 010).
- **Spike references.** `spikes/card_scanner/phase2/lib/card_scanner_phase2/fingerprint.rb`, `ppm.rb`, `art_index.rb`, `public/fingerprint.js`, `public/search.js`; spec 010's live crop is `spikes/card_scanner/phase3/public/replay.js#crop` (guide rect at native pixels, rounded outward, no resize). The spike's image cache is `~/card-scanner-corpus/art-cache/artwork/small/<illustration_id>.jpg` (50,924 files); its agreement list is `~/card-scanner-corpus/art-cache/agreement_small.json` (`results[].id`, n=134).

**Plan decisions (not spelled out in the spec):**

- **Decoder: ImageMagick's CLI** ([ADR 0011](../../adr/0011-decode-art-images-with-imagemagick.md)), the spike's measured path. `magick` is preferred, `convert` (ImageMagick 6, as on Ubuntu) accepted. The Dockerfile's base stage installs `imagemagick`; CI installs it with `apt`; `bin/setup` warns when it's missing.
- **One settings source:** `config/art_fingerprint.json`, a copy of the frozen `fingerprint` block. Its digest (the first 16 hex characters of the SHA-256 of its JSON) goes into every stored fingerprint, the index header and the page.
- **Index file:** `art-index-<catalog version>-<settings digest>-<record count>.bin.gz` in `<catalog dir>/mtg/art/index/`. The count in the name keeps every URL immutable when a later build of the same catalog version adds artworks that failed before. The header is 28 bytes: `CART`, format version 1, three zero bytes, the 16-character digest, the record count (uint32, big-endian); then ADR 0006's 144-byte records, sorted by artwork id.
- **Build runs** (`mtg_art_builds`) carry the job id and a heartbeat; the stale cutoff is 10 minutes with a heartbeat after every batch of 50 images. Solid Queue's `limits_concurrency` isn't used (a first build outlasts its lock).
- **The art part of a reading** is read leniently from `params[:reading][:artworks]` by `MTG::Art::Sent`, outside `params.expect`, so it can never fail the request.
- **Ranking result:** `MTG::Reading#ranking` returns a `Ranking` value (candidates, tier, overruled, overruled scope, art status, usable artworks); `candidates` and `ranked(score)` keep their meaning.
- **JS:** one new module, `app/javascript/scanner/art.js` (crop, fingerprint, index parse, search), pinned by the existing `pin_all_from "app/javascript/scanner"`.
- **Measurement:** the reading request appends one line per reading to `<run dir>/readings.jsonl` (AC-9.3). Captures gain `art_ms`, `art_download_ms`, `art_ready_ms` and `ready_ms` extras.

**Pre-implementation gates:**

- **Simplicity:** three components: the build (models, job, index file), the page (art module and card-reader changes), the ranking (evidence and reading). One new system dependency (ImageMagick), justified by ADR 0006's server-side build (ADR 0011).
- **Anti-abstraction:** Rails features are used directly (`upsert_all`, `send_file`, `after_initialize`, `Data.define`). `MTG::Art::Sent::Artwork` and `MTG::Art::Evidence::Usable` are value objects for one request, not parallel models.
- **Integration-first:** the request and file contracts are written in Phase 0 (`contracts/api.md`, `data-model.md`) and each phase's request or model spec asserts them before its implementation.

---

## Phase 0: Decisions and contracts

**Implements:** FR-2 (decoder) | **Satisfies:** AC-3.10 (decision only)
**Files:** `docs/adr/0011-decode-art-images-with-imagemagick.md`, `docs/specs/011-card-scanner-art-matching/data-model.md`, `docs/specs/011-card-scanner-art-matching/contracts/api.md`, `docs/adr/README.md` (no change needed; ADRs list themselves)
**Interfaces:** Consumes: nothing. Produces: the table, file and endpoint shapes every later phase implements.

The supporting documents are written with this plan. This phase commits them so later commits can link them.

- [x] Check the three files exist: `ls docs/adr/0011-decode-art-images-with-imagemagick.md docs/specs/011-card-scanner-art-matching/data-model.md docs/specs/011-card-scanner-art-matching/contracts/api.md` — expect three paths.
- [x] ADR 0011 was approved with this plan: change its Status line from `Proposed (2026-10-07, …)` to `Accepted (<the plan's approval date>, approved with spec 011's plan)`, and the plan header's "(Proposed with this plan…)" to "(Accepted with this plan…)". The agreement figures join its Consequences in Phase 16.
- [x] Commit: `docs(011): add the art matching plan, data model, contracts and ADR 0008` (done when the plan was approved, 2026-10-08; renumbered ADR 0011 after rebasing onto spec 012's ADRs 0008–0010)

---

## Phase 1: The opt-in setting

**Implements:** FR-1 | **Satisfies:** AC-1.2, AC-1.3
**Files:** `app/models/mtg/art.rb`, `config/initializers/art_matching.rb`, `config/application.rb`, `spec/models/mtg/art_spec.rb`, `spec/support/art_helpers.rb`, `README.md`, `compose.yaml`, `config/deploy.yml`, `spec/readme_spec.rb`
**Interfaces:** Consumes: nothing. Produces: `MTG::Art::ENV_NAME`, `MTG::Art.enabled_in?(env) → Boolean`, `MTG::Art.enabled? → Boolean` (reads `Rails.configuration.x.mtg_art_matching`), `MTG::Art.root → Pathname` (`<catalog_download_dir>/mtg/art`); the RSpec metadata `:art_matching` (turns art on and empties `MTG::Art.root` around an example).

- [x] Write the failing spec `spec/models/mtg/art_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Art, type: :model do
  describe ".enabled_in?" do
    it "is on for 1, true, yes and on, in any case and with surrounding spaces (AC-1.2)" do
      values = [ "1", "true", "yes", "on", "TRUE", " On " ]
      expect(values.map { described_class.enabled_in?(described_class::ENV_NAME => it) }).to all(be(true))
    end

    it "is off when unset, empty or anything else (AC-1.1, AC-1.2)" do
      envs = [ {}, { described_class::ENV_NAME => "" }, { described_class::ENV_NAME => "0" }, { described_class::ENV_NAME => "enabled" } ]
      expect(envs.map { described_class.enabled_in?(it) }).to all(be(false))
    end
  end

  describe ".enabled?" do
    it "is off in tests unless an example turns it on" do
      expect(described_class).not_to be_enabled
    end

    it "reads the app's configuration", :art_matching do
      expect(described_class).to be_enabled
    end
  end

  it "keeps its files under the catalog download directory" do
    expect(described_class.root).to eq(Rails.root.join("tmp/catalog/mtg/art"))
  end
end
```

- [x] Write `spec/support/art_helpers.rb`:

```ruby
# Art matching in specs (spec 011): `:art_matching` turns the instance setting on for one example and empties the art
# directory (tmp/catalog/mtg/art) before and after it, so no index or cached image leaks between examples.
RSpec.configure do |config|
  config.around(:each, :art_matching) do |example|
    previous = Rails.configuration.x.mtg_art_matching
    Rails.configuration.x.mtg_art_matching = true
    FileUtils.rm_rf(MTG::Art.root)
    example.run
  ensure
    Rails.configuration.x.mtg_art_matching = previous
    FileUtils.rm_rf(MTG::Art.root)
  end
end
```

- [x] Run: `bin/rspec spec/models/mtg/art_spec.rb` — expect: FAIL (`uninitialized constant MTG::Art`).
- [x] Implement `app/models/mtg/art.rb`:

```ruby
# Art matching (spec 011): the instance's opt-in setting and where its global files live. Off unless
# COLLECTOR_MTG_ART_MATCHING is 1, true, yes or on (AC-1.2); every art behaviour asks .enabled? (FR-1).
module MTG::Art
  ENV_NAME = "COLLECTOR_MTG_ART_MATCHING"
  TRUE_VALUES = %w[1 true yes on].freeze

  def self.enabled_in?(env) = TRUE_VALUES.include?(env.fetch(ENV_NAME, "").to_s.strip.downcase)

  # Parsed once at boot into the app's configuration (config/initializers/art_matching.rb); tests set the configuration.
  def self.enabled? = Rails.configuration.x.mtg_art_matching == true

  # Global catalog files on the persistent volume: storage/catalog/mtg/art (tmp/catalog/mtg/art in tests).
  def self.root = Rails.configuration.x.catalog_download_dir.join("mtg", "art")
end
```

- [x] Add to `config/application.rb`, after the `config.x.scanner_measurement = nil` line:

```ruby
    # Art matching for the card scanner (spec 011): off until config/initializers/art_matching.rb reads the environment.
    config.x.mtg_art_matching = false
```

- [x] Write `config/initializers/art_matching.rb`:

```ruby
# Spec 011 AC-1.2: COLLECTOR_MTG_ART_MATCHING is parsed once, into the app's configuration, which every caller reads.
# after_initialize, because the parser lives in app/ (MTG::Art) and can't be referenced while config loads. Tests never
# read the environment (a developer's exported variable mustn't turn art on in the suite); examples set the configuration.
Rails.application.config.after_initialize do
  Rails.configuration.x.mtg_art_matching = !Rails.env.test? && MTG::Art.enabled_in?(ENV)
end
```

- [x] Run: `bin/rspec spec/models/mtg/art_spec.rb` — expect: PASS (5 examples).
- [x] Commit: `feat(art): add the opt-in art matching setting (011)`
- [x] Add the failing README expectations to `spec/readme_spec.rb`, before the final `end`:

```ruby
  it "documents opt-in art matching in the README, Compose and Kamal (spec 011 AC-1.3)", :aggregate_failures do
    art = readme[/^- \*\*Art matching \(optional\):\*\*.*?(?=^- \*\*|^## )/m].to_s
    expect(readme).to include("| `COLLECTOR_MTG_ART_MATCHING`")
    expect(art).to include("COLLECTOR_MTG_ART_MATCHING", "about 708 MB", "about 2.6 hours", "about 7.3 MB",
      'bin/rails "catalog:refresh[mtg]"', "storage/catalog/mtg/art", "text alone")
    expect(Rails.root.join("compose.yaml").read).to include('COLLECTOR_MTG_ART_MATCHING: "${COLLECTOR_MTG_ART_MATCHING:-}"')
    expect(Rails.root.join("config/deploy.yml").read).to include("# COLLECTOR_MTG_ART_MATCHING: true")
  end
```

- [x] Run: `bin/rspec spec/readme_spec.rb` — expect: FAIL (1 failure).
- [x] Add a row to the README's settings table, after the `COLLECTOR_MTG_LANGUAGES` row:

```markdown
| `COLLECTOR_MTG_ART_MATCHING` | no       | off                   | `true` turns on art matching for the card scanner (see [Card catalog](#card-catalog))                                                 |
```

- [x] Add a bullet to the README's "Card catalog" list, after the **Languages** bullet:

```markdown
- **Art matching (optional):** set `COLLECTOR_MTG_ART_MATCHING=true` and the card scanner also
  recognises a card by its artwork on live captures. It's off by default because the first
  build costs about 708 MB of downloads (one small image per artwork from Scryfall), about
  2.6 hours of throttled fetching and then fingerprinting, and leaves an index of about 7.3 MB.
  The build runs in the background after a catalog refresh; to start it now, run
  `bin/rails "catalog:refresh[mtg]"` (Kamal: `bin/kamal catalog-refresh`), and follow it with
  `bin/rails "catalog:status[mtg]"`. Later refreshes fetch only new artworks. Until the first
  build finishes, and whenever art matching is off, the scanner works on text alone. Images
  are cached in `storage/catalog/mtg/art`; after turning art matching off you can delete that
  folder to reclaim the space.
```

- [x] In `compose.yaml`, add a header comment line after the `COLLECTOR_MTG_LANGUAGES` one:

```yaml
# Optional: COLLECTOR_MTG_ART_MATCHING ("true" turns on art matching for the scanner; first build ~708 MB, ~2.6 h)
```

  and an environment line after `COLLECTOR_MTG_LANGUAGES: "${COLLECTOR_MTG_LANGUAGES:-}"`:

```yaml
      COLLECTOR_MTG_ART_MATCHING: "${COLLECTOR_MTG_ART_MATCHING:-}"
```

- [x] In `config/deploy.yml`, after the `COLLECTOR_MTG_LANGUAGES` comment block, add:

```yaml

    # Art matching for the card scanner: downloads one small image per artwork (~708 MB, ~2.6 h) after a refresh.
    # COLLECTOR_MTG_ART_MATCHING: true
```

- [x] Run: `bin/rspec spec/readme_spec.rb` — expect: PASS. (`bin/kamal catalog-refresh` is an existing alias, `config/deploy.yml:80`.)
- [x] Commit: `docs(art): document the art matching setting and its cost (011)`

---

## Phase 2: Artwork ids in the catalog

**Implements:** FR-2 | **Satisfies:** AC-2.1, AC-2.2, AC-2.3, AC-2.4
**Files:** `db/migrate/20261007100001_add_illustration_id_to_mtg_printings.rb`, `db/schema.rb`, `app/models/mtg/scryfall/mapper.rb`, `app/models/catalog/sources.rb`, `app/models/catalog/refresh.rb`, `app/models/mtg/scryfall/source.rb`, `spec/support/fake_catalog_source.rb`, `spec/models/mtg/scryfall/mapper_spec.rb`, `spec/models/catalog/refresh_spec.rb`, `spec/models/mtg/scryfall/source_spec.rb`
**Interfaces:** Consumes: nothing. Produces: `mtg_printings.illustration_id` (string, indexed, nullable); each face's `image_uris["small"]` in `mtg_printings.faces`; the optional source hooks `#reapply? → Boolean` (asked before the skip decision) and `#after_refresh(run)` (called after an applied or already-applied skipped run); `MTG::Scryfall::Source#reapply?`.

- [x] Write the failing mapper examples, inside `describe ".entry_record"` in `spec/models/mtg/scryfall/mapper_spec.rb`:

```ruby
    it "keeps the front face's artwork id and each face's small image (spec 011 AC-2.1)", :aggregate_failures do
      card = scryfall_card("illustration_id" => "art-1",
        "image_uris" => { "small" => "https://cards.scryfall.io/small/front/a/b/x.jpg", "normal" => "n", "large" => "l" })
      record = described_class.entry_record(card)

      expect(record.extension[:illustration_id]).to eq("art-1")
      expect(record.extension[:faces].first["image_uris"]).to eq("small" => "https://cards.scryfall.io/small/front/a/b/x.jpg", "normal" => "n", "large" => "l")
    end

    it "takes a multi-face printing's artwork id from its front face, and stores none when there is none", :aggregate_failures do
      faces = [ { "name" => "Front", "illustration_id" => "front-art" }, { "name" => "Back", "illustration_id" => "back-art" } ]
      expect(described_class.entry_record(scryfall_card("card_faces" => faces, "illustration_id" => nil)).extension[:illustration_id]).to eq("front-art")
      expect(described_class.entry_record(scryfall_card).extension[:illustration_id]).to be_nil
    end
```

- [x] Run: `bin/rspec spec/models/mtg/scryfall/mapper_spec.rb` — expect: FAIL (2 failures).
- [x] Write the migration `db/migrate/20261007100001_add_illustration_id_to_mtg_printings.rb`:

```ruby
# Spec 011 AC-2.1, AC-2.2: each printing's artwork (Scryfall's front-face illustration_id), filled by the next applied
# refresh (the extension's digest changes, so every printing is rewritten once). Nullable: some printings have none.
class AddIllustrationIdToMTGPrintings < ActiveRecord::Migration[8.1]
  def change
    add_column :mtg_printings, :illustration_id, :string
    add_index :mtg_printings, :illustration_id
  end
end
```

- [x] Run: `bin/rails db:migrate && git checkout db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb && bin/rails db:rollback && bin/rails db:migrate && git checkout db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb` — expect: the migration runs down and up; `git diff db/schema.rb` shows only the new column, its index and the version.
- [x] Change `MTG::Scryfall::Mapper.entry_record`'s extension hash to add the artwork id (keep every other key):

```ruby
      extension: {
        rarity: card.fetch("rarity"), finishes: card.fetch("finishes").sort, layout: card.fetch("layout"),
        frame: card["frame"], border_color: card["border_color"], security_stamp: card["security_stamp"],
        variant_tags: variant_tags(card), legalities: card.fetch("legalities", {}),
        external_ids: card.slice(*EXTERNAL_IDS), faces:, scryfall_uri: card.fetch("scryfall_uri"),
        illustration_id: illustration_id(card)
      }
```

  and `faces` to keep `small`, plus the new helper below it:

```ruby
  def faces(card)
    (card["card_faces"].presence || [ card ]).map do |face|
      face.slice(*FACE_FIELDS).merge("image_uris" => (face["image_uris"] || card["image_uris"] || {}).slice("small", "normal", "large"))
    end
  end

  # The front face's artwork (spec 011 AC-2.1): a multi-face printing's first face, else the card's own.
  def illustration_id(card) = Array(card["card_faces"]).first&.dig("illustration_id") || card["illustration_id"]
```

- [x] Run: `bin/rspec spec/models/mtg/scryfall/mapper_spec.rb` — expect: PASS.
- [x] Commit: `feat(catalog): store each printing's artwork id and small image (011)`
- [x] Extend `spec/support/fake_catalog_source.rb`'s `FakeCatalogSource` with the optional hooks (replace the `attr_accessor` line and add two methods):

```ruby
  attr_accessor :version, :sets, :entries, :languages_result, :fail_at, :reapply
  attr_reader :downloads, :refreshed

  def initialize(version: "v1", sets: [], entries: [], languages: [ "en" ], fail_at: nil, reapply: false)
    @version, @sets, @entries, @languages_result, @fail_at, @reapply = version, sets, entries, languages, fail_at, reapply
    @downloads = []
    @refreshed = []
  end

  # Spec 011 AC-2.4: the optional hooks a source may implement.
  def reapply? = reapply

  def after_refresh(run) = refreshed << [ run.status, run.source_version ]
```

- [x] Write the failing refresh examples at the end of `spec/models/catalog/refresh_spec.rb` (before the last `end`):

```ruby
  context "with a source's refresh hooks (spec 011 AC-2.3, AC-2.4)" do
    it "applies an already-applied version again when the source asks before the skip decision", :aggregate_failures do
      refresh(trigger: "scheduled")
      source.reapply = true

      run = refresh(trigger: "scheduled")

      expect(run).to have_attributes(status: "applied", source_version: "v1")
      expect(source.downloads).to eq(%w[v1 v1])
    end

    it "skips an already-applied scheduled version when the source doesn't ask" do
      refresh(trigger: "scheduled")

      expect(refresh(trigger: "scheduled")).to have_attributes(status: "skipped")
    end

    it "tells the source after an applied run and after an already-applied skip" do
      refresh(trigger: "scheduled")
      refresh(trigger: "scheduled")

      expect(source.refreshed).to eq([ %w[applied v1], %w[skipped v1] ])
    end

    it "doesn't tell the source when the refresh was skipped because another one is running", :aggregate_failures do
      create(:catalog_refresh_run, collectible_type: "fake", status: "running", finished_at: nil, started_at: 1.minute.ago)

      expect(refresh).to have_attributes(status: "skipped", message: "already running")
      expect(source.refreshed).to be_empty
    end

    it "works with a source that implements neither hook" do
      plain = Class.new(FakeCatalogSource) { undef_method :reapply?, :after_refresh }.new(sets: [ set_record("lea") ], entries: [ entry_record("a") ])

      expect(described_class.new("fake", trigger: "manual", source: plain).call).to have_attributes(status: "applied")
    end
  end
```

- [x] Run: `bin/rspec spec/models/catalog/refresh_spec.rb` — expect: FAIL (the re-apply and hook examples).
- [x] Change `Catalog::Refresh#call` and add the hook helpers (full methods shown):

```ruby
  def call
    @run = Catalog::RefreshRun.start!(@collectible_type, trigger: @trigger)
    return @run unless @run.running?

    languages = @source.languages
    version = @source.current_version(languages:)
    @run.update!(source_version: version, languages: languages.join(","))
    return skip(version) if already_applied?(version) && !reapply?

    path = @source.download(version, dir: Rails.configuration.x.catalog_download_dir.join(@collectible_type))
    sync_sets
    sync_entries(path, languages)
    retire_unseen
    name_index.rebuild
    @run.finish!(:applied, counts: @counts)
    after_refresh
    @run
  rescue StandardError => error
    @run.finish!(:failed, message: "#{error.class}: #{error.message}", counts: @counts) if @run&.running?
    raise
  end
```

```ruby
    def skip(version)
      rebuilt = name_index.rebuild unless name_index.populated?
      note = "; name index rebuilt with #{rebuilt} #{"name".pluralize(rebuilt)}" if rebuilt
      @run.finish!(:skipped, message: "#{version} already applied#{note}")
      after_refresh
      @run
    end

    # Optional source hooks (app/models/catalog/sources.rb): a reason to apply an already-applied version again, and a
    # step after an applied or already-applied run. The core never knows what a source does with them (spec 011 AC-2.4).
    def reapply? = @source.respond_to?(:reapply?) && @source.reapply?

    def after_refresh = @source.respond_to?(:after_refresh) && @source.after_refresh(@run)
```

- [x] Document the hooks in `app/models/catalog/sources.rb`'s header comment, after the `#each_entry` line:

```ruby
#   #reapply?                           optional: true to apply a version again although it was applied (asked before a skip)
#   #after_refresh(run)                 optional: called after an applied run, or one skipped as already applied
```

- [x] Run: `bin/rspec spec/models/catalog/refresh_spec.rb` — expect: PASS.
- [x] Write the failing source example in `spec/models/mtg/scryfall/source_spec.rb` (inside the top-level describe):

```ruby
  describe "#reapply?" do
    it "asks once for a catalog whose printings have no artwork ids yet (spec 011 AC-2.3)", :aggregate_failures do
      expect(source.reapply?).to be(false) # an empty catalog applies anyway
      printing = create(:mtg_printing)
      expect(source.reapply?).to be(true)
      printing.update!(illustration_id: "art-1")
      expect(source.reapply?).to be(false)
    end
  end
```

- [x] Run: `bin/rspec spec/models/mtg/scryfall/source_spec.rb` — expect: FAIL (`undefined method 'reapply?'`).
- [x] Add to `MTG::Scryfall::Source`, after `initialize`:

```ruby
  # Spec 011 AC-2.3: an instance upgrading to artwork ids applies its current bulk file once more, art matching on or off,
  # so every printing gets its artwork id. About 760 printings legitimately have none, so "any without" isn't the test.
  def reapply? = MTG::Printing.exists? && !MTG::Printing.where.not(illustration_id: nil).exists?
```

- [x] Run: `bin/rspec spec/models/mtg/scryfall/source_spec.rb spec/models/catalog spec/models/mtg` — expect: PASS.
- [x] Commit: `feat(catalog): re-apply once for artwork ids, and let sources hook into a refresh (011)`

---

## Phase 3: Fingerprint settings, the Ruby fingerprint and the decoder

**Implements:** FR-2 | **Satisfies:** AC-8.1 (the build's side), AC-3.10 (decoder), NFR Reliability (decoder in development, CI and the image)
**Files:** `config/art_fingerprint.json`, `app/models/mtg/art/settings.rb`, `app/models/mtg/art/fingerprint.rb`, `app/models/mtg/art/decoder.rb`, `spec/models/mtg/art/settings_spec.rb`, `spec/models/mtg/art/fingerprint_spec.rb`, `spec/models/mtg/art/decoder_spec.rb`, `spec/support/png_helpers.rb`, `Dockerfile`, `.github/workflows/ci.yml`, `bin/setup`
**Interfaces:** Consumes: nothing. Produces: `MTG::Art::Settings.fingerprint → Hash` (`"box"`, `"grid"`, `"offsets"`, `"imageSize"`), `MTG::Art::Settings.digest → String` (16 lowercase hex), `MTG::Art::Settings.for_page → { "digest", "fingerprint" }`; `MTG::Art::Fingerprint.of(image, offset = MTG::Art::Fingerprint::ZERO) → String` (128 binary bytes); `MTG::Art::Decoder.decode(path) → MTG::Art::Decoder::Image` (`width`, `height`, `rgb(x, y)`), `MTG::Art::Decoder.command → String`, `MTG::Art::Decoder::Error`; spec helper `png_bytes(width, height) { |x, y| [r, g, b] }`.

- [x] Write `config/art_fingerprint.json` (the `fingerprint` block of `spikes/card_scanner/phase2/settings.json` at `39cdc6e`, unchanged):

```json
{
  "box": { "x0": 0.14, "x1": 0.86, "y0": 0.16, "y1": 0.5 },
  "grid": [17, 16],
  "offsets": [
    { "dx": 0, "dy": 0 }, { "dx": 0.02, "dy": 0 }, { "dx": -0.02, "dy": 0 },
    { "dx": 0, "dy": 0.02 }, { "dx": 0, "dy": -0.02 }, { "dx": 0, "dy": 0, "inset": 0.03 }
  ],
  "imageSize": "small"
}
```

- [x] Write the failing `spec/models/mtg/art/settings_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Art::Settings, type: :model do
  it "is the fingerprint frozen at 39cdc6e (spec 011 AC-8.1)" do
    frozen = JSON.parse(Rails.root.join("spikes/card_scanner/phase2/settings.json").read).fetch("fingerprint")
    expect(described_class.fingerprint).to eq(frozen)
  end

  it "has a stable 16-character digest, which the page gets with the settings", :aggregate_failures do
    expect(described_class.digest).to match(/\A[0-9a-f]{16}\z/)
    expect(described_class.digest).to eq(Digest::SHA256.hexdigest(JSON.generate(described_class.fingerprint))[0, 16])
    expect(described_class.for_page).to eq("digest" => described_class.digest, "fingerprint" => described_class.fingerprint)
  end
end
```

- [x] Run: `bin/rspec spec/models/mtg/art/settings_spec.rb` — expect: FAIL (`uninitialized constant MTG::Art::Settings`).
- [x] Implement `app/models/mtg/art/settings.rb`:

```ruby
# The art fingerprint's settings (ADR 0006), the one source the build and the scanner page share (spec 011 AC-8.1):
# config/art_fingerprint.json, frozen at 39cdc6e. Its digest is recorded with every stored fingerprint, in the index
# header and on the page, so a change of settings can never mix fingerprints.
module MTG::Art::Settings
  PATH = Rails.root.join("config/art_fingerprint.json")

  def self.fingerprint = @fingerprint ||= JSON.parse(PATH.read).freeze

  def self.digest = @digest ||= Digest::SHA256.hexdigest(JSON.generate(fingerprint))[0, 16]

  def self.for_page = { "digest" => digest, "fingerprint" => fingerprint }
end
```

- [x] Run: `bin/rspec spec/models/mtg/art/settings_spec.rb` — expect: PASS.
- [x] Write `spec/support/png_helpers.rb`:

```ruby
# A lossless, opaque PNG with no colour profile or gamma chunk, so ImageMagick and the browser see the same pixels
# (spec 011 AC-8.3). The block gives each pixel's [r, g, b].
module PngHelpers
  def png_bytes(width, height)
    rows = (0...height).map { |y| "\x00".b + (0...width).map { |x| yield(x, y).pack("C3") }.join }.join
    chunk = ->(type, data) { [ data.bytesize ].pack("N") + type.b + data + [ Zlib.crc32(type.b + data) ].pack("N") }
    "\x89PNG\r\n\x1A\n".b + chunk.("IHDR", [ width, height, 8, 2, 0, 0, 0 ].pack("NNC5")) +
      chunk.("IDAT", Zlib::Deflate.deflate(rows)) + chunk.("IEND", "".b)
  end

  # A deterministic noisy picture the size of a Scryfall small image, so every fingerprint bit is exercised.
  def noisy_png(width: 146, height: 204, seed: 7)
    state = seed
    png_bytes(width, height) { Array.new(3) { state = (state * 16_807) % 2_147_483_647; state % 256 } }
  end
end

RSpec.configure { |config| config.include PngHelpers }
```

- [x] Write the failing `spec/models/mtg/art/fingerprint_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Art::Fingerprint, type: :model do
  # A picture whose every channel rises (or falls) from left to right: each horizontal neighbour pair differs one way.
  def gradient(width, height, rising:)
    data = (0...height).flat_map { (0...width).flat_map { |x| [ rising ? x : 255 - x ] * 3 } }.pack("C*")
    MTG::Art::Decoder::Image.new(width, height, data)
  end

  it "sets every bit when brightness rises left to right, and none when it falls (ADR 0006)", :aggregate_failures do
    expect(described_class.of(gradient(200, 280, rising: true))).to eq("\xFF".b * 128)
    expect(described_class.of(gradient(200, 280, rising: false))).to eq("\x00".b * 128)
  end

  it "makes 128 bytes for every one of the six offsets" do
    image = gradient(146, 204, rising: true)
    expect(MTG::Art::Settings.fingerprint.fetch("offsets").map { described_class.of(image, it).bytesize }).to all(eq(128))
  end

  it "crops the art box of the card: x 14–86%, y 16–50%" do
    expect(described_class.box(1000, 1000, MTG::Art::Settings.fingerprint.fetch("box"), described_class::ZERO))
      .to eq([ 140.0, 160.0, 860.0, 500.0 ])
  end
end
```

- [x] Write the failing `spec/models/mtg/art/decoder_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Art::Decoder, type: :model do
  it "decodes a PNG to its exact pixels with ImageMagick (ADR 0011)", :aggregate_failures do
    path = Rails.root.join("tmp/decoder-spec.png")
    path.binwrite(png_bytes(3, 2) { |x, y| [ x * 10, y * 20, 255 - x ] })

    image = described_class.decode(path)

    expect([ image.width, image.height ]).to eq([ 3, 2 ])
    expect(image.rgb(2, 1)).to eq([ 20, 20, 253 ])
  ensure
    path&.delete if path&.exist?
  end

  it "parses binary 8-bit P6 and refuses anything else", :aggregate_failures do
    expect(described_class.parse("P6\n1 1\n255\n\x01\x02\x03".b).rgb(0, 0)).to eq([ 1, 2, 3 ])
    expect { described_class.parse("P3\n1 1\n255\n1 2 3") }.to raise_error(described_class::Error)
  end

  it "raises its own error for a file ImageMagick can't read" do
    path = Rails.root.join("tmp/decoder-spec.jpg")
    path.binwrite("not an image")
    expect { described_class.decode(path) }.to raise_error(described_class::Error)
  ensure
    path&.delete if path&.exist?
  end
end
```

- [x] Run: `bin/rspec spec/models/mtg/art/fingerprint_spec.rb spec/models/mtg/art/decoder_spec.rb` — expect: FAIL (uninitialized constants).
- [x] Implement `app/models/mtg/art/decoder.rb`:

```ruby
require "open3"

# Decodes a cached artwork image to 8-bit RGB with ImageMagick's CLI (ADR 0011), the spikes' path, which agreed with
# the browser's canvas to 0 bits. `magick` (ImageMagick 7) is preferred; `convert` (ImageMagick 6) is accepted.
module MTG::Art::Decoder
  COMMANDS = %w[magick convert].freeze

  class Error < StandardError; end

  Image = Struct.new(:width, :height, :data) do
    def rgb(x, y)
      offset = (y * width + x) * 3
      [ data.getbyte(offset), data.getbyte(offset + 1), data.getbyte(offset + 2) ]
    end
  end

  def self.command
    @command ||= COMMANDS.find { |name| system(name, "-version", out: File::NULL, err: File::NULL) } ||
      raise(Error, "ImageMagick isn't installed: art matching needs the magick (or convert) command")
  end

  def self.decode(path)
    out, status = Open3.capture2(command, path.to_s, "-depth", "8", "ppm:-", binmode: true, err: File::NULL)
    raise Error, "ImageMagick couldn't decode #{File.basename(path.to_s)}" unless status.success?

    parse(out)
  end

  def self.parse(bytes)
    header = bytes.b.match(/\AP6\s+(\d+)\s+(\d+)\s+(\d+)\s/) or raise Error, "expected a binary 8-bit P6 image"
    raise Error, "expected 8-bit P6 (maxval 255)" unless header[3] == "255"

    width, height = header[1].to_i, header[2].to_i
    data = bytes.b.byteslice(header[0].bytesize, width * height * 3)
    raise Error, "short P6 data" unless data && data.bytesize == width * height * 3

    Image.new(width, height, data)
  end
end
```

  Note: `Open3.capture2` takes `err:` as a spawn option; if RuboCop or Ruby rejects it, use `Open3.capture3` and ignore stderr: `out, _err, status = Open3.capture3(command, path.to_s, "-depth", "8", "ppm:-", binmode: true)`.

- [x] Implement `app/models/mtg/art/fingerprint.rb` (the spike's arithmetic, loop order unchanged):

```ruby
# The art fingerprint (ADR 0006), the same arithmetic and loop order as the scanner page's scanner/art.js: the art box
# (x 14–86%, y 16–50% of the card) area-resampled to 17×16, four planes (grey, blue, green, red), each a difference hash
# of horizontal neighbours, most significant bit first: 1,024 bits as 128 bytes. The index stores the zero offset.
module MTG::Art::Fingerprint
  ZERO = { "dx" => 0, "dy" => 0 }.freeze

  module_function

  def of(image, offset = ZERO, settings: MTG::Art::Settings.fingerprint)
    cols, rows = settings.fetch("grid")
    x0, y0, x1, y1 = box(image.width, image.height, settings.fetch("box"), offset)
    r, g, b = area_resample(image, x0, y0, x1, y1, cols, rows)
    grey = r.each_index.map { 0.299 * r[it] + 0.587 * g[it] + 0.114 * b[it] }
    [ grey, b, g, r ].map { dhash(it, cols, rows) }.join
  end

  # The crop box in pixels for an offset: dx/dy shift by a share of the card, inset shrinks every side.
  def box(width, height, box, offset)
    inset = offset["inset"].to_f
    bw, bh = box["x1"] - box["x0"], box["y1"] - box["y0"]
    [ (box["x0"] + offset["dx"].to_f + inset * bw) * width, (box["y0"] + offset["dy"].to_f + inset * bh) * height,
      (box["x1"] + offset["dx"].to_f - inset * bw) * width, (box["y1"] + offset["dy"].to_f - inset * bh) * height ]
  end

  # Each output cell averages the source pixels it overlaps, weighted by the overlap.
  def area_resample(image, x0, y0, x1, y1, cols, rows)
    cell_w, cell_h = (x1 - x0) / cols, (y1 - y0) / rows
    r, g, b = Array.new(cols * rows, 0.0), Array.new(cols * rows, 0.0), Array.new(cols * rows, 0.0)
    rows.times do |j|
      cy0, cy1 = y0 + j * cell_h, y0 + (j + 1) * cell_h
      cols.times do |i|
        cx0, cx1 = x0 + i * cell_w, x0 + (i + 1) * cell_w
        k = j * cols + i
        r[k], g[k], b[k] = cell(image, cx0, cy0, cx1, cy1)
      end
    end
    [ r, g, b ]
  end

  def cell(image, cx0, cy0, cx1, cy1)
    sr = sg = sb = weight = 0.0
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
    [ sr / weight, sg / weight, sb / weight ]
  end

  def dhash(plane, cols, rows)
    bits = +""
    rows.times { |j| (cols - 1).times { |i| bits << (plane[j * cols + i + 1] > plane[j * cols + i] ? "1" : "0") } }
    [ bits ].pack("B*")
  end
end
```

  The spike accumulated `sr`, `sg`, `sb` and `weight` in the same order inside one method; `cell` keeps that order, so the floating-point sums are identical.

- [x] Run: `bin/rspec spec/models/mtg/art` — expect: PASS (needs `magick` or `convert` on the machine; this dev machine has `magick`).
- [x] Add ImageMagick to the image, CI and setup. In the `Dockerfile` base stage, change the `apt-get install` line to:

```dockerfile
    apt-get install --no-install-recommends -y curl imagemagick libjemalloc2 libvips sqlite3 && \
```

  and after `RUN bin/fetch-ocr-engine` add:

```dockerfile
# Art matching decodes Scryfall's small images with ImageMagick (spec 011, ADR 0011).
RUN command -v magick || command -v convert
```

  In `.github/workflows/ci.yml`, before "Run bin/ci":

```yaml
      - name: Install ImageMagick (art matching's decoder, ADR 0011)
        run: sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends imagemagick
```

  In `bin/setup`, after the OCR engine step:

```ruby
    puts "\n== Checking ImageMagick (art matching, ADR 0011) =="
    unless %w[magick convert].any? { |name| system(name, "-version", out: File::NULL, err: File::NULL) }
      puts "ImageMagick isn't installed. Install it (e.g. `sudo dnf install ImageMagick` or `sudo apt install imagemagick`): " \
           "the art matching specs and the art build need it."
    end
```

- [x] Run: `bin/rubocop config bin/setup app/models/mtg/art spec/models/mtg/art spec/support/png_helpers.rb && bin/rspec spec/models/mtg/art` — expect: no offenses, PASS.
- [x] Commit: `feat(art): add the fingerprint settings, the Ruby fingerprint and the ImageMagick decoder (011)`
- [x] Build the production image and check the command: `podman build -t collector:art-check . && podman run --rm --entrypoint sh collector:art-check -c 'command -v magick || command -v convert'` — expect: a path such as `/usr/bin/magick` or `/usr/bin/convert`. If neither prints, record it in the commit body as a `Ruling:` and stop to ask: the base image's ImageMagick package name differs.

---
## Phase 4: The page's art module

**Implements:** FR-4 | **Satisfies:** AC-8.1 (the page's side), AC-8.3, AC-5.3 (the crop)
**Files:** `app/javascript/scanner/art.js`, `spec/support/art_page_helpers.rb`, `spec/system/art_fingerprint_spec.rb`
**Interfaces:** Consumes: `MTG::Art::Settings.fingerprint`, `MTG::Art::Decoder.decode`, `MTG::Art::Fingerprint.of`, `png_bytes`/`noisy_png` (Phase 3). Produces: the module `scanner/art` exporting `FORMAT_VERSION`, `box`, `areaResample`, `fingerprint(canvas, settings, offset)`, `fingerprints(canvas, settings) → Uint8Array[]`, `cropGuide(frame, guide) → canvas`, `parseIndex(bytes, digest) → { count, ids, words }`, `loadArtIndex(url, settings) → { index, downloadMs, readyMs }`, `search(index, hashes, limit = 10) → [{ id, distance }]`, `matchArtwork(index, frame, guide, fingerprintSettings, limit = 10)`, `hex(bytes)`; spec helpers `ArtPageHelpers::ART_JS`, `browser_fingerprints(png) → [hex, …]`, `run_art_js(body, *args)`.

- [x] Write `spec/support/art_page_helpers.rb`:

```ruby
# Loads the page's own scanner/art module into the WebDriver sandbox, as ScannerHelpers::MODULES_JS loads geometry
# (spec 011 Story 5, Story 8).
module ArtPageHelpers
  ART_JS = <<~JS.freeze
    window.__art ||= new Promise((resolve) => {
      addEventListener("art-ready", () => resolve(window.__scannerArt), { once: true })
      const script = Object.assign(document.createElement("script"), { type: "module", nonce: document.querySelector("script[type=importmap]")?.nonce || "" })
      script.textContent = `import * as art from "scanner/art"; window.__scannerArt = art; dispatchEvent(new Event("art-ready"))`
      document.head.append(script)
    })
  JS

  # Runs `body` with `art` (the module) and `args` in scope; `body` calls done(result).
  def run_art_js(body, *args)
    page.evaluate_async_script(<<~JS, *args)
      const args = Array.from(arguments).slice(0, -1), done = arguments[arguments.length - 1]
      #{ART_JS}
      window.__art.then((art) => { #{body} })
    JS
  end

  # The page's six fingerprints (hex) of a PNG drawn at its own size, as the build fingerprints a whole small image.
  def browser_fingerprints(png, settings: MTG::Art::Settings.fingerprint)
    run_art_js(<<~JS, Base64.strict_encode64(png), settings)
      const [ data, settings ] = args
      const image = new Image()
      image.onload = () => {
        const canvas = Object.assign(document.createElement("canvas"), { width: image.naturalWidth, height: image.naturalHeight })
        canvas.getContext("2d").drawImage(image, 0, 0)
        done(art.fingerprints(canvas, settings).map(art.hex))
      }
      image.src = `data:image/png;base64,${data}`
    JS
  end
end

RSpec.configure { |config| config.include ArtPageHelpers, type: :system }
```

- [x] Write the failing `spec/system/art_fingerprint_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Art fingerprint on the scanner page", type: :system do
  before do
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  it "makes the same six fingerprints as the build on a lossless picture (spec 011 AC-8.3)" do
    png = noisy_png
    path = Rails.root.join("tmp/art-agreement-spec.png")
    path.binwrite(png)
    image = MTG::Art::Decoder.decode(path)
    expected = MTG::Art::Settings.fingerprint.fetch("offsets").map { MTG::Art::Fingerprint.of(image, it).unpack1("H*") }

    expect(browser_fingerprints(png)).to eq(expected)
  ensure
    path&.delete if path&.exist?
  end

  it "crops the guide rect at the frame's own pixels, rounded outward and kept inside the frame (spec 011 AC-5.3)" do
    sizes = run_art_js(<<~JS)
      const frame = Object.assign(document.createElement("canvas"), { width: 100, height: 80 })
      done([ { x: 10.4, y: 5.6, width: 30.2, height: 60.9 }, { x: -3, y: 70.5, width: 50, height: 30 } ]
        .map((guide) => { const crop = art.cropGuide(frame, guide); return [ crop.width, crop.height ] }))
    JS

    expect(sizes).to eq([ [ 31, 62 ], [ 47, 10 ] ])
  end
end
```

- [x] Run: `bin/rspec spec/system/art_fingerprint_spec.rb` — expect: FAIL (the module `scanner/art` doesn't exist, so the script times out).
- [x] Implement `app/javascript/scanner/art.js`:

```js
// Art matching on the scanner page (spec 011 Story 5; ADR 0006, ADR 0007). A live capture's guide crop is fingerprinted
// with the same arithmetic and loop order as MTG::Art::Fingerprint, and the index the app built is searched on the
// device. Only the nearest artwork ids and their distances leave this module; a fingerprint never does (FR-5).
export const FORMAT_VERSION = 1
const MAGIC = "CART"
const HEADER = 28
const RECORD = 144

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

function dhash(plane, cols, rows, out, offset) {
  let bit = 0
  for (let j = 0; j < rows; j++) {
    for (let i = 0; i < cols - 1; i++, bit++) {
      if (plane[j * cols + i + 1] > plane[j * cols + i]) out[offset + (bit >> 3)] |= 0x80 >> (bit & 7)
    }
  }
}

// One 128-byte fingerprint of a canvas holding the card (or a whole artwork image).
export function fingerprint(canvas, settings, offset) {
  const image = canvas.getContext("2d", { willReadFrequently: true }).getImageData(0, 0, canvas.width, canvas.height)
  const [ cols, rows ] = settings.grid
  const [ x0, y0, x1, y1 ] = box(canvas.width, canvas.height, settings.box, offset)
  const [ r, g, b ] = areaResample(image, x0, y0, x1, y1, cols, rows)
  const grey = new Float64Array(r.length)
  for (let k = 0; k < r.length; k++) grey[k] = 0.299 * r[k] + 0.587 * g[k] + 0.114 * b[k]
  const out = new Uint8Array(128)
  ;[ grey, b, g, r ].forEach((plane, n) => dhash(plane, cols, rows, out, n * 32))
  return out
}

export function fingerprints(canvas, settings) {
  return settings.offsets.map((offset) => fingerprint(canvas, settings, offset))
}

// The guide rect cut from the frame at its own pixels, rounded outward and not resized (spec 010's replay crop, AC-5.3).
export function cropGuide(frame, guide) {
  const x0 = Math.max(0, Math.floor(guide.x)), y0 = Math.max(0, Math.floor(guide.y))
  const x1 = Math.min(frame.width, Math.ceil(guide.x + guide.width)), y1 = Math.min(frame.height, Math.ceil(guide.y + guide.height))
  const canvas = Object.assign(document.createElement("canvas"), { width: x1 - x0, height: y1 - y0 })
  canvas.getContext("2d", { willReadFrequently: true }).drawImage(frame, x0, y0, x1 - x0, y1 - y0, 0, 0, x1 - x0, y1 - y0)
  return canvas
}

// The index file (MTG::Art::Index): a 28-byte header (CART, format version, 3 zero bytes, the 16-character settings
// digest, the record count as uint32 big-endian), then 144-byte records (16-byte artwork id, 128-byte fingerprint).
export function parseIndex(bytes, digest) {
  if (bytes.length < HEADER) throw new Error("The art index is too short.")
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const text = (start, end) => String.fromCharCode(...bytes.subarray(start, end))
  const count = view.getUint32(24)
  if (text(0, 4) !== MAGIC || bytes[4] !== FORMAT_VERSION || text(8, 24) !== digest || bytes.length !== HEADER + count * RECORD) {
    throw new Error("The art index doesn't match this page.")
  }
  const ids = new Array(count), words = new Uint32Array(count * 32)
  for (let i = 0; i < count; i++) {
    const base = HEADER + i * RECORD
    const h = Array.from(bytes.subarray(base, base + 16), (byte) => byte.toString(16).padStart(2, "0")).join("")
    ids[i] = `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`
    for (let w = 0; w < 32; w++) words[i * 32 + w] = view.getUint32(base + 16 + w * 4)
  }
  return { count, ids, words }
}

// Downloads (the browser's cache serves a repeat) and parses the index; the times are for measurement mode (AC-9.5).
export async function loadArtIndex(url, settings) {
  const started = performance.now()
  const response = await fetch(url, { credentials: "same-origin" })
  if (!response.ok) throw new Error(`The art index answered ${response.status}.`)
  const bytes = new Uint8Array(await response.arrayBuffer())
  const downloaded = performance.now()
  const index = parseIndex(bytes, settings.digest)
  return { index, downloadMs: Math.round(downloaded - started), readyMs: Math.round(performance.now() - downloaded) }
}

function popcount(v) {
  v = v - ((v >>> 1) & 0x55555555)
  v = (v & 0x33333333) + ((v >>> 2) & 0x33333333)
  return (((v + (v >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24
}

// Each artwork's distance is the smallest over the query's offset fingerprints; the nearest `limit`, nearest first,
// ties in index order (the spike's ranking).
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

// A live capture's nearest artworks: the guide crop, its six fingerprints, the search.
export function matchArtwork(index, frame, guide, fingerprintSettings, limit = 10) {
  return search(index, fingerprints(cropGuide(frame, guide), fingerprintSettings), limit)
}

export const hex = (bytes) => Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")
```

- [x] Run: `bin/rspec spec/system/art_fingerprint_spec.rb` — expect: PASS (2 examples). If the agreement example differs, compare `browser_fingerprints` with the spike's `fingerprint.js` on the same PNG before touching either implementation: the arithmetic must stay the spike's.
- [x] Run: `bin/importmap audit && bin/rubocop spec/support/art_page_helpers.rb spec/system/art_fingerprint_spec.rb` — expect: no vulnerable packages, no offenses.
- [x] Commit: `feat(scanner): add the page's art fingerprint, crop and index search (011)`

---

## Phase 5: The artwork and build-run tables

**Implements:** FR-2 | **Satisfies:** AC-3.2, AC-3.7 (storage), NFR Reliability (migrations)
**Files:** `db/migrate/20261007100002_create_mtg_artworks.rb`, `db/migrate/20261007100003_create_mtg_art_builds.rb`, `db/schema.rb`, `app/models/mtg/artwork.rb`, `app/models/mtg/art_build.rb`, `spec/factories/art.rb`, `spec/models/mtg/artwork_spec.rb`, `spec/models/mtg/art_build_spec.rb`
**Interfaces:** Consumes: `MTG::Art::Settings.digest` (Phase 3). Produces: `MTG::Artwork` (`illustration_id`, `catalog_entry_id`, `fingerprint` 128 bytes, `settings_digest`; scope `.current`), `MTG::ArtBuild` (`.start!(job_id:, catalog_version:, settings_digest:) → MTG::ArtBuild`, `.latest`, `#beat!(**counts)`, `#finish!(status, message: nil, **counts)`, `#stale?`, `#counts`, `STALE_AFTER = 10.minutes`, `COUNTS`); factories `:mtg_artwork`, `:mtg_art_build`.

- [x] Write the migrations:

```ruby
# db/migrate/20261007100002_create_mtg_artworks.rb
# Spec 011 AC-3.7: one fingerprint per artwork, global catalog data (no account_id), with the printing whose image was
# fingerprinted and the digest of the settings it was made with. Built only by MTG::Art::BuildJob.
class CreateMTGArtworks < ActiveRecord::Migration[8.1]
  def change
    create_table :mtg_artworks do |t|
      t.string :illustration_id, null: false
      t.references :catalog_entry, null: false, foreign_key: true
      t.binary :fingerprint, null: false
      t.string :settings_digest, null: false
      t.timestamps
      t.index :illustration_id, unique: true
      t.index :settings_digest
    end
  end
end
```

```ruby
# db/migrate/20261007100003_create_mtg_art_builds.rb
# Spec 011 AC-3.2, AC-3.11: each art build's run, global like the catalog's refresh runs, with its job id and a
# heartbeat so a re-run or a crashed build never blocks the next one.
class CreateMTGArtBuilds < ActiveRecord::Migration[8.1]
  def change
    create_table :mtg_art_builds do |t|
      t.string :status, null: false
      t.string :job_id
      t.string :catalog_version
      t.string :settings_digest
      t.string :index_file
      t.integer :total_count, :without_image_count, :fetched_count, :fingerprinted_count, :failed_count, :indexed_count,
        null: false, default: 0
      t.text :message
      t.datetime :started_at, null: false
      t.datetime :heartbeat_at, null: false
      t.datetime :finished_at
      t.timestamps
      t.index %i[status started_at]
      t.index :job_id
    end
  end
end
```

- [x] Run: `bin/rails db:migrate && bin/rails db:rollback STEP=2 && bin/rails db:migrate && git checkout db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb` — expect: both migrate down and up; `git diff --stat db/` shows only `db/schema.rb` and the two migrations.
- [x] Write `spec/factories/art.rb`:

```ruby
FactoryBot.define do
  factory :mtg_artwork, class: "MTG::Artwork" do
    sequence(:illustration_id) { |n| format("00000000-0000-4000-8000-%012d", n) }
    entry factory: :catalog_entry
    fingerprint { "\x00".b * 128 }
    settings_digest { MTG::Art::Settings.digest }
  end

  factory :mtg_art_build, class: "MTG::ArtBuild" do
    status { "finished" }
    sequence(:job_id) { |n| "job-#{n}" }
    catalog_version { "default-cards-1" }
    settings_digest { MTG::Art::Settings.digest }
    started_at { 1.hour.ago }
    heartbeat_at { 30.minutes.ago }
    finished_at { 30.minutes.ago }
  end
end
```

- [x] Write the failing `spec/models/mtg/artwork_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Artwork, type: :model do
  it "is one 128-byte fingerprint per artwork, with its printing and settings digest (spec 011 AC-3.7)", :aggregate_failures do
    artwork = create(:mtg_artwork)
    expect(artwork.entry).to be_a(Catalog::Entry)
    expect(build(:mtg_artwork, illustration_id: artwork.illustration_id)).not_to be_valid
    expect(build(:mtg_artwork, fingerprint: "\x00".b * 127)).not_to be_valid
  end

  it "knows which fingerprints were made with the current settings" do
    current = create(:mtg_artwork)
    create(:mtg_artwork, settings_digest: "0123456789abcdef")
    expect(described_class.current).to eq([ current ])
  end
end
```

- [x] Write the failing `spec/models/mtg/art_build_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::ArtBuild, type: :model do
  def start(job_id = "job-a") = described_class.start!(job_id:, catalog_version: "default-cards-1", settings_digest: MTG::Art::Settings.digest)

  it "records a running build with its job and a heartbeat" do
    expect(start).to have_attributes(status: "running", job_id: "job-a", heartbeat_at: be_present)
  end

  it "ends a second build at once as skipped while one is running (spec 011 AC-3.2)", :aggregate_failures do
    first = start
    second = start("job-b")
    expect(second).to have_attributes(status: "skipped", message: "already running")
    expect(first.reload).to be_running
  end

  it "marks a run with a stale heartbeat interrupted, then runs (AC-3.2)", :aggregate_failures do
    first = start
    travel(described_class::STALE_AFTER + 1.minute) do
      expect(start("job-b")).to be_running
    end
    expect(first.reload).to have_attributes(status: "failed", message: "interrupted")
  end

  it "lets the queue's re-run of the same job carry on at once (AC-3.2, AC-3.8)", :aggregate_failures do
    first = start
    expect(start("job-a")).to be_running
    expect(first.reload).to have_attributes(status: "failed", message: "interrupted")
  end

  it "keeps its counts and heartbeat as it goes, and its outcome at the end", :aggregate_failures do
    run = start
    travel 1.minute do
      run.beat!(total: 3, fetched: 1)
      expect(run).to have_attributes(total_count: 3, fetched_count: 1, heartbeat_at: Time.current)
    end
    run.finish!(:finished, indexed: 3)
    expect(run).to have_attributes(status: "finished", indexed_count: 3, finished_at: be_present)
    expect(run.counts).to include(total: 3, fetched: 1, indexed: 3)
  end

  it "is stale only while running with an old heartbeat", :aggregate_failures do
    run = start
    expect(run).not_to be_stale
    travel(described_class::STALE_AFTER + 1.minute) { expect(run).to be_stale }
  end

  it "reports the latest run that wasn't skipped" do
    finished = create(:mtg_art_build, started_at: 2.hours.ago)
    create(:mtg_art_build, status: "skipped", started_at: 1.hour.ago)
    expect(described_class.latest).to eq(finished)
  end
end
```

- [x] Run: `bin/rspec spec/models/mtg/artwork_spec.rb spec/models/mtg/art_build_spec.rb` — expect: FAIL (uninitialized constants).
- [x] Implement `app/models/mtg/artwork.rb`:

```ruby
# One artwork's fingerprint (spec 011 AC-3.7): global catalog data keyed by Scryfall's illustration_id, with the printing
# whose image was fingerprinted and the digest of the settings it was made with. Written only by MTG::Art::Build.
class MTG::Artwork < ApplicationRecord
  belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id

  validates :illustration_id, presence: true, uniqueness: true
  validates :settings_digest, presence: true
  validates :fingerprint, length: { is: 128 }

  scope :current, -> { where(settings_digest: MTG::Art::Settings.digest) }
end
```

- [x] Implement `app/models/mtg/art_build.rb`:

```ruby
# One attempt to build the art index (spec 011 AC-3.2, AC-3.11): its job, its counts, a heartbeat while it runs, and how
# it ended. A build that finds another running ends at once as skipped. A run left running by the same job (the queue
# re-ran it after a restart), or whose heartbeat is older than STALE_AFTER (a crash), is marked failed as interrupted
# first, so the guard never relies on the job queue's concurrency lock, which a first build can outlast.
class MTG::ArtBuild < ApplicationRecord
  STALE_AFTER = 10.minutes
  COUNTS = %i[total without_image fetched fingerprinted failed indexed].freeze

  enum :status, { running: "running", finished: "finished", failed: "failed", skipped: "skipped" }, validate: true

  validates :started_at, :heartbeat_at, presence: true

  scope :recent, -> { order(started_at: :desc, id: :desc) }

  def self.start!(job_id:, catalog_version:, settings_digest:)
    transaction do
      running.where(job_id:).or(running.where(heartbeat_at: ..STALE_AFTER.ago))
        .find_each { |run| run.finish!(:failed, message: "interrupted") }
      live = running.exists?
      now = Time.current
      run = create!(status: :running, job_id:, catalog_version:, settings_digest:, started_at: now, heartbeat_at: now)
      run.finish!(:skipped, message: "already running") if live
      run
    end
  end

  def self.latest = where.not(status: :skipped).recent.first

  def beat!(**counts) = update!(heartbeat_at: Time.current, **count_columns(counts))

  def finish!(status, message: nil, **counts)
    update!(status:, message:, finished_at: Time.current, **count_columns(counts))
    Rails.logger.info(ActiveSupport::JSON.encode(event: "mtg.art_build.finished", status:, catalog_version:, message:, **self.counts))
  end

  def stale? = running? && heartbeat_at < STALE_AFTER.ago

  def counts = COUNTS.index_with { |name| public_send(:"#{name}_count") }

  private
    def count_columns(counts) = counts.transform_keys { |name| :"#{name}_count" }
end
```

- [x] Run: `bin/rspec spec/models/mtg/artwork_spec.rb spec/models/mtg/art_build_spec.rb` — expect: PASS.
- [x] Commit: `feat(art): add the artwork and art build tables (011)`

---

## Phase 6: Fetching card images

**Implements:** FR-2 | **Satisfies:** AC-3.4
**Files:** `app/models/mtg/scryfall/client.rb`, `spec/models/mtg/scryfall/client_spec.rb`
**Interfaces:** Consumes: nothing new. Produces: `MTG::Scryfall::Client#fetch_image(url) → String` (binary body), raising `Catalog::Sources::TransientError` after 3 attempts or on another error status.

- [ ] Write the failing examples in `spec/models/mtg/scryfall/client_spec.rb` (inside the top-level describe):

```ruby
  describe "#fetch_image (spec 011 AC-3.4)" do
    let(:url) { "https://cards.scryfall.io/small/front/a/b/art.jpg" }

    it "asks for a JPEG with the app's User-Agent and returns its bytes", :aggregate_failures do
      stub = stub_request(:get, url).with(headers: { "User-Agent" => %r{\ACollector/}, "Accept" => "image/jpeg" })
        .to_return(body: "\xFF\xD8jpeg".b)

      expect(client.fetch_image(url)).to eq("\xFF\xD8jpeg".b)
      expect(stub).to have_been_requested
    end

    it "waits at least 100 ms between images, as between API calls" do
      stub_request(:get, url).to_return(body: "x")

      2.times { client.fetch_image(url) }

      expect(naps).to eq([ 0.1 ])
    end

    it "backs off on 429 (honouring Retry-After) and on 5xx, then succeeds", :aggregate_failures do
      stub_request(:get, url).to_return({ status: 429, headers: { "Retry-After" => "3" } }, { status: 503 }, { body: "x" })

      expect(client.fetch_image(url)).to eq("x")
      expect(naps).to include(3, 2)
    end

    it "gives up after 3 attempts" do
      stub_request(:get, url).to_return(status: 502)

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::TransientError, /after 3 attempts/)
    end

    it "doesn't retry another error status", :aggregate_failures do
      stub = stub_request(:get, url).to_return(status: 404)

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::TransientError, /404/)
      expect(stub).to have_been_requested.once
    end
  end
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall/client_spec.rb` — expect: FAIL (`undefined method 'fetch_image'`).
- [ ] Implement in `MTG::Scryfall::Client` — add after `download`:

```ruby
  # A card image (spec 011 AC-3.4): throttled like API calls, Accept image/jpeg, retried with back-off on 429 and 5xx
  # (Retry-After when given, else 1, 2 s), at most MAX_ATTEMPTS requests. Returns the body's bytes.
  def fetch_image(url)
    uri = URI(url)
    MAX_ATTEMPTS.times do |attempt|
      throttle
      response = request(uri, accept: "image/jpeg") { |http, request| http.request(request) }
      return response.body.to_s.b if response.is_a?(Net::HTTPSuccess)
      raise Catalog::Sources::TransientError, "GET #{uri} returned #{response.code}" unless retryable?(response)

      @sleeper.call(Integer(response["Retry-After"].to_s, exception: false) || 2**attempt) if attempt < MAX_ATTEMPTS - 1
    end
    raise Catalog::Sources::TransientError, "GET #{uri} still failing after #{MAX_ATTEMPTS} attempts"
  end
```

  and change the private `request` to take the `Accept` header, plus a predicate:

```ruby
    def request(uri, accept: "application/json")
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        yield http, Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => accept)
      end
    rescue *NETWORK_ERRORS => error
      raise Catalog::Sources::TransientError, "GET #{uri}: #{error.class}: #{error.message}"
    end

    def retryable?(response) = response.is_a?(Net::HTTPTooManyRequests) || response.is_a?(Net::HTTPServerError)
```

  The 429 example sleeps `3` (Retry-After) after attempt 0 and `2` (`2**1`) after attempt 1, so `naps` includes both.
- [ ] Run: `bin/rspec spec/models/mtg/scryfall/client_spec.rb` — expect: PASS.
- [ ] Commit: `feat(catalog): fetch card images with Scryfall's manners (011)`

---

## Phase 7: The index file

**Implements:** FR-2, FR-4 | **Satisfies:** AC-3.9, AC-5.2 (the page's header check), AC-8.1 (digest in the header)
**Files:** `app/models/mtg/art.rb`, `app/models/mtg/art/index.rb`, `spec/models/mtg/art/index_spec.rb`, `spec/system/art_index_spec.rb`
**Interfaces:** Consumes: `MTG::Art.root`, `MTG::Art::Settings.digest`, the page's `parseIndex`/`search` (Phase 4). Produces: `MTG::Art.cache_dir → Pathname`; `MTG::Art::Index` with `MAGIC`, `FORMAT_VERSION`, `HEADER`, `RECORD`, `KEEP`, `NAME`, `.dir`, `.name_for(catalog_version, count)`, `.files → [Pathname]` (newest first), `.current → Pathname | nil`, `.built_for?(catalog_version) → Boolean`, `.path_for(name) → Pathname | nil` (current or previous only), `.write!(catalog_version, records) → Pathname` (`records`: `[[illustration_id, fingerprint]]`), `.read(path) → { magic:, version:, digest:, count:, records: }`.

- [ ] Write the failing `spec/models/mtg/art/index_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Art::Index, :art_matching, type: :model do
  let(:a) { "aaaaaaaa-0000-4000-8000-000000000001" }
  let(:b) { "bbbbbbbb-0000-4000-8000-000000000002" }
  let(:records) { [ [ b, "\xFF".b * 128 ], [ a, "\x01".b * 128 ] ] }

  it "writes a compressed header and sorted 144-byte records, named by catalog version, digest and count (AC-3.9)", :aggregate_failures do
    path = described_class.write!("default-cards-1", records)

    expect(path.basename.to_s).to eq("art-index-default-cards-1-#{MTG::Art::Settings.digest}-2.bin.gz")
    expect(described_class.read(path)).to eq(magic: "CART", version: 1, digest: MTG::Art::Settings.digest, count: 2,
      records: [ [ a, "\x01".b * 128 ], [ b, "\xFF".b * 128 ] ])
    expect(Zlib.gunzip(path.binread).bytesize).to eq(28 + 2 * 144)
  end

  it "leaves no partial file and doesn't rewrite an index it already has", :aggregate_failures do
    path = described_class.write!("default-cards-1", records)
    written = path.mtime
    travel(1.minute) { described_class.write!("default-cards-1", records.reverse) }
    expect(path.mtime).to eq(written)
    expect(described_class.dir.glob("*.part")).to be_empty
  end

  it "keeps only the two newest, serves only those by name, and calls the newest current (AC-3.9, AC-4.2)", :aggregate_failures do
    old = described_class.write!("v1", records)
    FileUtils.touch(old, mtime: 3.minutes.ago.to_time)
    previous = described_class.write!("v2", records)
    FileUtils.touch(previous, mtime: 2.minutes.ago.to_time)
    newest = described_class.write!("v3", records)

    expect(described_class.files).to eq([ newest, previous ])
    expect(old).not_to exist
    expect(described_class.current).to eq(newest)
    expect(described_class.path_for(previous.basename.to_s)).to eq(previous)
    expect(described_class.path_for(old.basename.to_s)).to be_nil
    expect(described_class.path_for("../../config/master.key")).to be_nil
  end

  it "knows whether a catalog version has an index at the current settings" do
    described_class.write!("v1", records)
    expect([ described_class.built_for?("v1"), described_class.built_for?("v2") ]).to eq([ true, false ])
  end
end
```

- [ ] Run: `bin/rspec spec/models/mtg/art/index_spec.rb` — expect: FAIL (`uninitialized constant MTG::Art::Index`).
- [ ] Add to `MTG::Art` (`app/models/mtg/art.rb`), after `root`:

```ruby
  # Scryfall small images, one per artwork, named <illustration_id>.jpg and never fetched twice (AC-3.4, AC-3.5).
  def self.cache_dir = root.join("small")
```

- [ ] Implement `app/models/mtg/art/index.rb`:

```ruby
require "zlib"

# The art index file (spec 011 AC-3.9; ADR 0006, ADR 0007), which the scanner page downloads and searches. Compressed;
# a 28-byte header (CART, format version, three zero bytes, the 16-character settings digest, the record count as uint32
# big-endian) and then one 144-byte record per artwork (16-byte artwork id, 128-byte fingerprint), sorted by artwork id.
# Named by catalog version, settings digest and record count, so a name never changes content (it's served immutable);
# written under a temporary name and renamed; the two newest are kept, and the newest is the one pages use.
class MTG::Art::Index
  MAGIC = "CART".b
  FORMAT_VERSION = 1
  HEADER = 28
  RECORD = 144
  KEEP = 2
  NAME = /\Aart-index-[a-z0-9-]+-[0-9a-f]{16}-\d+\.bin\.gz\z/

  def self.dir = MTG::Art.root.join("index")

  def self.name_for(catalog_version, count) = "art-index-#{catalog_version}-#{MTG::Art::Settings.digest}-#{count}.bin.gz"

  def self.files
    dir.glob("art-index-*.bin.gz").select { NAME.match?(it.basename.to_s) }.sort_by { [ it.mtime, it.basename.to_s ] }.reverse
  end

  def self.current = files.first

  def self.built_for?(catalog_version) = files.any? { it.basename.to_s.start_with?("art-index-#{catalog_version}-#{MTG::Art::Settings.digest}-") }

  # Only the current or previous index, by its exact name; anything else is nil (AC-4.2).
  def self.path_for(name) = NAME.match?(name.to_s) ? files.first(KEEP).find { it.basename.to_s == name } : nil

  def self.write!(catalog_version, records)
    sorted = records.sort_by(&:first)
    path = dir.join(name_for(catalog_version, sorted.size))
    return path if path.file?

    dir.mkpath
    partial = Pathname("#{path}.part")
    Zlib::GzipWriter.open(partial.to_s, Zlib::BEST_COMPRESSION) do |gzip|
      gzip.write(header(sorted.size))
      sorted.each { |id, fingerprint| gzip.write([ id.delete("-") ].pack("H32") + fingerprint.b) }
    end
    partial.rename(path)
    files.drop(KEEP).each(&:delete)
    path
  end

  def self.header(count) = MAGIC + [ FORMAT_VERSION, 0, 0, 0 ].pack("C4") + MTG::Art::Settings.digest.b + [ count ].pack("N")

  # The header and records of an index file, for specs and the findings.
  def self.read(path)
    data = Zlib.gunzip(Pathname(path).binread)
    count = data.byteslice(24, 4).unpack1("N")
    records = Array.new(count) do |i|
      record = data.byteslice(HEADER + i * RECORD, RECORD)
      hex = record.byteslice(0, 16).unpack1("H32")
      [ "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}", record.byteslice(16, 128) ]
    end
    { magic: data.byteslice(0, 4), version: data.getbyte(4), digest: data.byteslice(8, 16), count:, records: }
  end
end
```

- [ ] Run: `bin/rspec spec/models/mtg/art/index_spec.rb` — expect: PASS.
- [ ] Write the failing `spec/system/art_index_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Art index on the scanner page", :art_matching, type: :system do
  let(:near) { "aaaaaaaa-0000-4000-8000-000000000001" }
  let(:far) { "bbbbbbbb-0000-4000-8000-000000000002" }

  before do
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  def index_bytes = Base64.strict_encode64(Zlib.gunzip(MTG::Art::Index.write!("v1", [ [ near, "\x00".b * 128 ], [ far, "\xFF".b * 128 ] ]).binread))

  it "reads the file the build writes and finds the nearest artworks (ADR 0007)" do
    found = run_art_js(<<~JS, index_bytes, MTG::Art::Settings.digest)
      const [ data, digest ] = args
      const index = art.parseIndex(Uint8Array.from(atob(data), (c) => c.charCodeAt(0)), digest)
      const query = new Uint8Array(128); query[0] = 0x80
      done(art.search(index, [ query ], 2))
    JS

    expect(found).to eq([ { "id" => near, "distance" => 1 }, { "id" => far, "distance" => 1023 } ])
  end

  it "refuses an index built with other settings (AC-5.2)" do
    error = run_art_js(<<~JS, index_bytes)
      try { art.parseIndex(Uint8Array.from(atob(args[0]), (c) => c.charCodeAt(0)), "0123456789abcdef"); done(null) } catch (e) { done(e.message) }
    JS

    expect(error).to eq("The art index doesn't match this page.")
  end
end
```

- [ ] Run: `bin/rspec spec/system/art_index_spec.rb` — expect: PASS (the page's module exists since Phase 4; this proves the two file formats agree).
- [ ] Commit: `feat(art): write the versioned art index file the page reads (011)`

---

## Phase 8: The build

**Implements:** FR-2 | **Satisfies:** AC-3.3, AC-3.4 (host), AC-3.5, AC-3.6, AC-3.7, AC-3.8, AC-3.9, AC-3.10 (decoder check)
**Files:** `app/models/mtg/art/build.rb`, `spec/models/mtg/art/build_spec.rb`
**Interfaces:** Consumes: `MTG::Art.enabled?`, `MTG::Art.cache_dir`, `MTG::Art::Settings.digest`, `MTG::Art::Fingerprint.of`, `MTG::Art::Decoder` (`.command`, `.decode`, `::Error`), `MTG::Scryfall::Client#fetch_image`, `MTG::Artwork`, `MTG::ArtBuild`, `MTG::Art::Index.write!`, `Catalog::RefreshRun.for_type("mtg").last_applied`. Produces: `MTG::Art::Build.new(job_id:, client: MTG::Scryfall::Client.new, decoder: MTG::Art::Decoder)#call → MTG::ArtBuild | nil`, `MTG::Art::Build::BATCH`, `MTG::Art::Build::IMAGE_HOSTS`.

- [ ] Write the failing `spec/models/mtg/art/build_spec.rb`:

```ruby
require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe MTG::Art::Build, :art_matching, type: :model do
  let(:naps) { [] }
  let(:client) { MTG::Scryfall::Client.new(sleeper: ->(seconds) { naps << seconds }, clock: -> { 0.0 }) }
  let(:art_a) { "aaaaaaaa-0000-4000-8000-000000000001" }
  let(:art_b) { "bbbbbbbb-0000-4000-8000-000000000002" }

  before { create(:catalog_refresh_run, collectible_type: "mtg", source_version: "default-cards-1") }

  def small(name) = "https://cards.scryfall.io/small/front/a/b/#{name}.jpg"

  # A printing of an artwork; small: false leaves its face without a small image.
  def printing(art, released_on:, name: "Lightning Bolt", small: true, set_code: nil, number: "1", **entry)
    set = create(:catalog_set, released_on:, **(set_code ? { code: set_code } : {}))
    image_uris = small ? { "small" => small("#{art}-#{released_on.year}-#{number}") } : {}
    printing = create(:mtg_printing, illustration_id: art, faces: [ { "name" => name, "image_uris" => image_uris } ],
      entry: create(:catalog_entry, set:, number:, released_on:, **entry))
    printing.entry
  end

  def serve(*names, png: noisy_png) = names.map { stub_request(:get, small(it)).to_return(body: png) }

  def run_build(job_id: "job-1") = described_class.new(job_id:, client:).call

  it "fingerprints each artwork from its oldest printing with a small image, passing over those without (AC-3.3)", :aggregate_failures do
    printing(art_a, released_on: Date.new(1999, 1, 1), small: false)
    chosen = printing(art_a, released_on: Date.new(2005, 1, 1))
    printing(art_a, released_on: Date.new(2020, 1, 1))
    serve("#{art_a}-2005-1")

    run = run_build

    expect(run).to have_attributes(status: "finished", total_count: 1, without_image_count: 0, fetched_count: 1, indexed_count: 1)
    expect(MTG::Artwork.sole).to have_attributes(illustration_id: art_a, catalog_entry_id: chosen.id, settings_digest: MTG::Art::Settings.digest)
    expect(MTG::Artwork.sole.fingerprint.bytesize).to eq(128)
  end

  it "counts artworks with no small image on any printing, and ignores tokens, art cards, other languages and retired printings", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1), small: false)
    printing(art_b, released_on: Date.new(2005, 1, 1), kind: "art_card")
    printing(art_b, released_on: Date.new(2006, 1, 1), language: "ja")
    printing(art_b, released_on: Date.new(2007, 1, 1), retired_at: 1.day.ago)

    expect(run_build).to have_attributes(status: "finished", total_count: 0, without_image_count: 1, indexed_count: 0)
  end

  it "fetches only from Scryfall's image host and caches each image under its artwork id (AC-3.4)", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    serve("#{art_a}-2005-1")
    run_build

    expect(MTG::Art.cache_dir.join("#{art_a}.jpg")).to exist
    expect(MTG::Art.cache_dir.glob("*.part")).to be_empty
  end

  it "records an image on another host as failed without requesting it" do
    entry = printing(art_a, released_on: Date.new(2005, 1, 1))
    MTG::Printing.find_by!(catalog_entry_id: entry.id).update!(faces: [ { "image_uris" => { "small" => "https://evil.test/x.jpg" } } ])

    expect(run_build).to have_attributes(status: "finished", failed_count: 1, indexed_count: 0)
  end

  it "never fetches a cached image again (AC-3.5)" do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    stub = serve("#{art_a}-2005-1").first
    run_build
    MTG::Artwork.delete_all # force a second fingerprint from the cache

    run_build(job_id: "job-2")

    expect(stub).to have_been_requested.once
  end

  it "records a failed image, goes on, and tries it again on the next build (AC-3.6)", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    printing(art_b, released_on: Date.new(2005, 1, 1), name: "Shock", number: "2")
    serve("#{art_a}-2005-1")
    missing = stub_request(:get, small("#{art_b}-2005-2")).to_return(status: 404)

    expect(run_build).to have_attributes(status: "finished", failed_count: 1, indexed_count: 1, message: include(art_b))
    expect(run_build(job_id: "job-2")).to have_attributes(failed_count: 1)
    expect(missing).to have_been_requested.twice
  end

  it "records an image it can't decode as failed and drops it from the cache, so it's fetched again", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    serve("#{art_a}-2005-1", png: "not an image")

    expect(run_build).to have_attributes(failed_count: 1, indexed_count: 0)
    expect(MTG::Art.cache_dir.join("#{art_a}.jpg")).not_to exist
  end

  it "fingerprints only artworks without a current fingerprint (AC-3.7)", :aggregate_failures do
    entry = printing(art_a, released_on: Date.new(2005, 1, 1))
    create(:mtg_artwork, illustration_id: art_a, entry:)
    stub = serve("#{art_a}-2005-1").first

    expect(run_build).to have_attributes(status: "finished", fetched_count: 0, fingerprinted_count: 1, indexed_count: 1)
    expect(stub).not_to have_been_requested
  end

  it "carries on after an interruption with the same result as an uninterrupted build (AC-3.8)", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    printing(art_b, released_on: Date.new(2005, 1, 1), name: "Shock", number: "2")
    stubs = serve("#{art_a}-2005-1", "#{art_b}-2005-2")
    full_disk = Module.new do # an error outside a single image, after the images were fetched and cached
      def self.command = MTG::Art::Decoder.command
      def self.decode(_path) = raise(Errno::ENOSPC)
    end

    expect { described_class.new(job_id: "job-1", client:, decoder: full_disk).call }.to raise_error(Errno::ENOSPC)
    expect(MTG::ArtBuild.sole).to have_attributes(status: "failed", message: include("ENOSPC"))

    # The first image was fetched and cached before the failure; only the second is fetched now.
    expect(run_build(job_id: "job-1")).to have_attributes(status: "finished", fetched_count: 1, indexed_count: 2)
    expect(stubs).to all(have_been_requested.once)
  end

  it "writes the index last, and a second complete build records only its run (AC-3.8, AC-3.9)", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    serve("#{art_a}-2005-1")
    path = MTG::Art::Index.dir.join(MTG::Art::Index.name_for("default-cards-1", 1))

    expect(run_build).to have_attributes(index_file: path.basename.to_s)
    written = path.mtime
    expect { run_build(job_id: "job-2") }.to change(MTG::ArtBuild, :count).by(1).and(not_change(MTG::Artwork, :count))
    expect(path.mtime).to eq(written)
    expect(MTG::Art::Index.read(path)[:records].map(&:first)).to eq([ art_a ])
  end

  it "fails at once, recorded, when ImageMagick is missing (ADR 0011)", :aggregate_failures do
    decoder = class_double(MTG::Art::Decoder, command: nil)
    allow(decoder).to receive(:command).and_raise(MTG::Art::Decoder::Error, "ImageMagick isn't installed")

    expect { described_class.new(job_id: "job-1", client:, decoder:).call }.to raise_error(MTG::Art::Decoder::Error)
    expect(MTG::ArtBuild.sole).to have_attributes(status: "failed", message: include("ImageMagick isn't installed"))
  end

  it "does nothing with art matching off, or before any refresh has applied", :aggregate_failures do
    Rails.configuration.x.mtg_art_matching = false
    expect(run_build).to be_nil
    Rails.configuration.x.mtg_art_matching = true
    Catalog::RefreshRun.delete_all
    expect(run_build).to be_nil
    expect(MTG::ArtBuild.count).to eq(0)
  end
end
```

  The `:art_matching` hook restores the setting after the last example, so changing it inside one is safe. `not_change` is defined at the top of the file (nothing in `spec/support` defines it). The helper is `run_build`, not `build`, so FactoryBot's `build` stays usable here.

- [ ] Run: `bin/rspec spec/models/mtg/art/build_spec.rb` — expect: FAIL (`uninitialized constant MTG::Art::Build`).
- [ ] Implement `app/models/mtg/art/build.rb`:

```ruby
# Builds the art index (spec 011 Story 3; ADR 0006). One fingerprint per artwork among the catalog's English card
# printings that aren't retired, from Scryfall's small image of the artwork's oldest printing that has one (AC-3.3),
# fetched once into the art cache (AC-3.4, AC-3.5). Incremental: only artworks without a fingerprint at the current
# settings are fingerprinted (AC-3.7). Resumable: the cache and the table survive an interruption (AC-3.8). A failed
# image is recorded and tried again next time (AC-3.6). Recorded as an MTG::ArtBuild with a heartbeat per batch, and the
# index file is written last (AC-3.9).
class MTG::Art::Build
  BATCH = 50
  FAILURES_SHOWN = 20
  IMAGE_HOSTS = %w[cards.scryfall.io].freeze
  COLLECTIBLE_TYPE = "mtg"
  # Oldest first: release date (undated last), then set code, then collector number as the catalog orders them.
  OLDEST_FIRST = Arel.sql("catalog_entries.released_on IS NULL, catalog_entries.released_on, catalog_sets.code, " \
                          "catalog_entries.number, catalog_entries.id")
  SMALL_IMAGE = Arel.sql("json_extract(mtg_printings.faces, '$[0].image_uris.small')")

  Representative = Data.define(:id, :catalog_entry_id, :url)

  def initialize(job_id:, client: MTG::Scryfall::Client.new, decoder: MTG::Art::Decoder)
    @job_id = job_id
    @client = client
    @decoder = decoder
    @counts = Hash.new(0)
    @failures = []
  end

  def call
    return unless MTG::Art.enabled?

    version = Catalog::RefreshRun.for_type(COLLECTIBLE_TYPE).last_applied&.source_version
    return unless version

    @run = MTG::ArtBuild.start!(job_id: @job_id, catalog_version: version, settings_digest: MTG::Art::Settings.digest)
    return @run unless @run.running?

    @decoder.command # fails the build at once when ImageMagick is missing (ADR 0011)
    artworks = representatives
    done = MTG::Artwork.current.pluck(:illustration_id).to_set
    todo = artworks.reject { done.include?(it.id) }
    @counts.merge!(total: artworks.size, fingerprinted: artworks.size - todo.size)
    @run.beat!(**@counts)
    todo.each_slice(BATCH) do |batch|
      store(batch.filter_map { fingerprint(it) })
      @run.beat!(**@counts)
    end
    @run.update!(index_file: write_index(version, artworks).basename.to_s)
    @run.finish!(:finished, message: failure_note, **@counts)
    @run
  rescue StandardError => error
    @run.finish!(:failed, message: "#{error.class}: #{error.message}", **@counts) if @run&.running?
    raise
  end

  private
    def representatives
      chosen = {}
      seen = ::Set.new
      printings.pluck(Arel.sql("mtg_printings.illustration_id"), "catalog_entries.id", SMALL_IMAGE).each do |id, entry_id, url|
        seen << id
        chosen[id] ||= Representative.new(id:, catalog_entry_id: entry_id, url:) if url.present?
      end
      @counts[:without_image] = seen.size - chosen.size
      chosen.values
    end

    def printings
      Catalog::Entry.searchable.where(collectible_type: COLLECTIBLE_TYPE, language: "en").joins(:set)
        .joins("INNER JOIN mtg_printings ON mtg_printings.catalog_entry_id = catalog_entries.id")
        .where.not(mtg_printings: { illustration_id: nil }).order(OLDEST_FIRST)
    end

    def fingerprint(artwork)
      path = cached(artwork)
      return unless path

      { illustration_id: artwork.id, catalog_entry_id: artwork.catalog_entry_id,
        fingerprint: MTG::Art::Fingerprint.of(@decoder.decode(path)), settings_digest: MTG::Art::Settings.digest }
    rescue MTG::Art::Decoder::Error => error
      path&.delete # an undecodable download is fetched again next time
      failed(artwork, error)
    end

    def cached(artwork)
      path = MTG::Art.cache_dir.join("#{artwork.id}.jpg")
      path.file? && path.size.positive? ? path : fetch(artwork, path)
    end

    def fetch(artwork, path)
      uri = URI(artwork.url)
      raise Catalog::Sources::Error, "#{artwork.url} isn't a Scryfall image" unless uri.scheme == "https" && IMAGE_HOSTS.include?(uri.host)

      bytes = @client.fetch_image(artwork.url)
      path.dirname.mkpath
      partial = Pathname("#{path}.part")
      partial.binwrite(bytes)
      partial.rename(path)
      @counts[:fetched] += 1
      path
    rescue Catalog::Sources::Error, URI::InvalidURIError => error
      failed(artwork, error)
    end

    def failed(artwork, error)
      @counts[:failed] += 1
      @failures << artwork.id if @failures.size < FAILURES_SHOWN
      Rails.logger.warn("mtg.art_build image #{artwork.id} failed: #{error.class}: #{error.message}")
      nil
    end

    def store(rows)
      return if rows.empty?

      MTG::Artwork.upsert_all(rows, unique_by: :illustration_id)
      @counts[:fingerprinted] += rows.size
    end

    def write_index(version, artworks)
      ids = artworks.to_set(&:id)
      records = MTG::Artwork.current.pluck(:illustration_id, :fingerprint).select { |id, _| ids.include?(id) }
      @counts[:indexed] = records.size
      MTG::Art::Index.write!(version, records)
    end

    def failure_note
      return if @failures.empty?

      "failed images: #{@failures.join(", ")}#{" and #{@counts[:failed] - @failures.size} more" if @counts[:failed] > @failures.size}"
    end
end
```

- [ ] Run: `bin/rspec spec/models/mtg/art/build_spec.rb` — expect: PASS. If "counts artworks with no small image" reports `total_count` 1, check that `printings` excludes `kind: "art_card"`, `language: "ja"` and retired entries: `Catalog::Entry.searchable` covers kind and retirement, `language: "en"` the rest.
- [ ] Run: `bin/rubocop app/models/mtg/art spec/models/mtg/art && bin/brakeman --quiet --no-pager --exit-on-warn` — expect: no offenses; no warnings (the SQL fragments are constants passed through `Arel.sql`).
- [ ] Commit: `feat(art): build the art index from the catalog's small images (011)`

---
## Phase 9: Queueing the build, and its status

**Implements:** FR-1, FR-2 | **Satisfies:** AC-3.1, AC-3.2 (job), AC-3.11, AC-1.1 (nothing built when off)
**Files:** `app/jobs/mtg/art/build_job.rb`, `app/models/mtg/art.rb`, `app/models/mtg/scryfall/source.rb`, `lib/tasks/catalog.rake`, `spec/jobs/mtg/art/build_job_spec.rb`, `spec/models/mtg/art_spec.rb`, `spec/models/mtg/scryfall/source_spec.rb`, `spec/tasks/catalog_rake_spec.rb`
**Interfaces:** Consumes: `MTG::Art::Build` (Phase 8), `MTG::ArtBuild` (Phase 5), `MTG::Art::Index` (Phase 7), the `after_refresh` hook (Phase 2). Produces: `MTG::Art::BuildJob` (queue `sync`), `MTG::Art.after_refresh(run)`, `MTG::Art.status_line → String`, `MTG::Scryfall::Source#after_refresh(run)`, `MTG::Scryfall::Source.status_lines → [String]` (the optional source hook `catalog:status` prints).

- [ ] Write the failing job spec `spec/jobs/mtg/art/build_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Art::BuildJob, type: :job do
  it "runs on the catalog's queue" do
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue("sync")
  end

  it "runs a build under its own job id, so a re-run after a restart carries on (AC-3.2)" do
    job = described_class.new
    allow(MTG::Art::Build).to receive(:new).and_call_original

    job.perform_now

    expect(MTG::Art::Build).to have_received(:new).with(job_id: job.job_id)
  end
end
```

- [ ] Add the failing examples to `spec/models/mtg/art_spec.rb` (before the final `end`):

```ruby
  describe ".after_refresh (spec 011 AC-3.1)" do
    def refresh_run(status) = build(:catalog_refresh_run, collectible_type: "mtg", status:, source_version: "default-cards-1")

    it "queues one build after an applied refresh", :art_matching do
      expect { described_class.after_refresh(refresh_run("applied")) }.to have_enqueued_job(MTG::Art::BuildJob).exactly(:once)
    end

    it "queues one after an already-applied skip only when that version has no index at the current settings", :art_matching, :aggregate_failures do
      expect { described_class.after_refresh(refresh_run("skipped")) }.to have_enqueued_job(MTG::Art::BuildJob)
      MTG::Art::Index.write!("default-cards-1", [])
      expect { described_class.after_refresh(refresh_run("skipped")) }.not_to have_enqueued_job(MTG::Art::BuildJob)
    end

    it "queues nothing with art matching off (AC-1.1)" do
      expect { described_class.after_refresh(refresh_run("applied")) }.not_to have_enqueued_job(MTG::Art::BuildJob)
    end
  end

  describe ".status_line (spec 011 AC-3.11)" do
    it "says when art matching is off" do
      expect(described_class.status_line).to start_with("Art matching: off")
    end

    it "says when no build has run yet", :art_matching do
      expect(described_class.status_line).to eq("Art matching: on; no build has run yet (it starts after the next catalog refresh)")
    end

    it "reports a running build's progress", :art_matching do
      create(:mtg_art_build, status: "running", finished_at: nil, heartbeat_at: 1.minute.ago, total_count: 10, fetched_count: 4, fingerprinted_count: 3)
      expect(described_class.status_line).to include("building", "4 images fetched", "3 of 10 artworks fingerprinted")
    end

    it "reports a running build whose heartbeat stopped as interrupted, with how to resume", :art_matching do
      create(:mtg_art_build, status: "running", finished_at: nil, heartbeat_at: 1.hour.ago, total_count: 10, fingerprinted_count: 3)
      expect(described_class.status_line).to include("interrupted", "3 of 10", 'bin/rails "catalog:refresh[mtg]"')
    end

    it "reports a finished build's counts and index", :art_matching do
      create(:mtg_art_build, indexed_count: 9, without_image_count: 1, failed_count: 2, index_file: "art-index-v1-0123456789abcdef-9.bin.gz")
      expect(described_class.status_line).to include("ready", "9 artworks indexed", "1 without an image", "2 failed images", "art-index-v1-0123456789abcdef-9.bin.gz")
    end

    it "reports a failed build with its message and the index still in use", :art_matching do
      kept = MTG::Art::Index.write!("v1", [])
      create(:mtg_art_build, status: "failed", message: "Errno::ENOSPC: No space left on device")
      expect(described_class.status_line).to include("failed", "No space left on device", kept.basename.to_s)
    end
  end
```

- [ ] Add the failing source example to `spec/models/mtg/scryfall/source_spec.rb`:

```ruby
  describe "#after_refresh and .status_lines (spec 011 AC-3.1, AC-3.11)" do
    it "hands an applied run to art matching, and reports its status", :art_matching, :aggregate_failures do
      run = build(:catalog_refresh_run, collectible_type: "mtg", status: "applied", source_version: "default-cards-1")
      expect { described_class.new(client: MTG::Scryfall::Client.new, env: {}).after_refresh(run) }.to have_enqueued_job(MTG::Art::BuildJob)
      expect(described_class.status_lines).to eq([ MTG::Art.status_line ])
    end
  end
```

- [ ] In `spec/tasks/catalog_rake_spec.rb`, the existing example "lists the 10 most recent runs, newest first, with counts and messages" counts every printed line; with the art line appended there are 11. Change its `expect(lines.size).to eq(10)` to:

```ruby
      expect(lines.size).to eq(11) # the 10 runs, then the source's own line (spec 011)
      expect(lines.last).to start_with("Art matching:")
```

- [ ] Add the failing rake example to `spec/tasks/catalog_rake_spec.rb`, inside `describe "catalog:status"`:

```ruby
    it "ends with the source's own status lines, such as art matching (spec 011 AC-3.11)" do
      expect { Rake::Task["catalog:status"].invoke("mtg") }.to output(/Art matching: off/).to_stdout
    end
```

- [ ] Run: `bin/rspec spec/jobs/mtg spec/models/mtg/art_spec.rb spec/models/mtg/scryfall/source_spec.rb spec/tasks/catalog_rake_spec.rb` — expect: FAIL (the job, the hooks and the status line don't exist).
- [ ] Implement `app/jobs/mtg/art/build_job.rb`:

```ruby
# Builds the art index in the background (spec 011 Story 3), queued by the catalog refresh (MTG::Art.after_refresh). Two
# builds never work at once: MTG::ArtBuild.start! guards it, keyed on the run record and this job's id, rather than a
# queue concurrency lock that a first build (hours) would outlast (AC-3.2). A missing ImageMagick fails the build run,
# which says so; retrying wouldn't help.
class MTG::Art::BuildJob < ApplicationJob
  queue_as :sync

  retry_on ActiveRecord::StatementTimeout, wait: :polynomially_longer, attempts: 3
  discard_on MTG::Art::Decoder::Error

  def perform = MTG::Art::Build.new(job_id:).call
end
```

- [ ] Add to `MTG::Art` (`app/models/mtg/art.rb`), after `cache_dir`:

```ruby
  # Spec 011 AC-3.1: one build after an applied refresh, or after one skipped as already applied while that catalog
  # version has no index at the current settings. Nothing with art matching off. Called by the MTG source's hook.
  def self.after_refresh(run)
    return unless enabled?
    return unless run.applied? || (run.skipped? && !MTG::Art::Index.built_for?(run.source_version))

    MTG::Art::BuildJob.perform_later
  end

  # The art line `catalog:status[mtg]` prints (AC-3.11), from the latest build run that wasn't skipped.
  def self.status_line
    return "Art matching: off (set #{ENV_NAME}=true to turn it on)" unless enabled?

    run = MTG::ArtBuild.latest
    return "Art matching: on; no build has run yet (it starts after the next catalog refresh)" unless run

    progress = "#{run.fetched_count} images fetched, #{run.fingerprinted_count} of #{run.total_count} artworks fingerprinted"
    if run.running? && run.stale?
      "Art matching: interrupted (last heartbeat #{run.heartbeat_at.utc.iso8601}) after #{progress}. " \
        'Run bin/rails "catalog:refresh[mtg]" to resume.'
    elsif run.running?
      "Art matching: building since #{run.started_at.utc.iso8601}; #{progress}, #{run.failed_count} failed " \
        "(last heartbeat #{run.heartbeat_at.utc.iso8601})"
    elsif run.finished?
      "Art matching: ready; #{run.indexed_count} artworks indexed, #{run.without_image_count} without an image, " \
        "#{run.failed_count} failed images; index #{run.index_file}"
    else
      "Art matching: failed at #{run.finished_at&.utc&.iso8601}: #{run.message}; index in use: #{MTG::Art::Index.current&.basename || "none"}"
    end
  end
```

- [ ] Add to `MTG::Scryfall::Source`, after `self.alternate_names`:

```ruby
  # Spec 011 AC-3.11: extra lines for `catalog:status[mtg]`.
  def self.status_lines = [ MTG::Art.status_line ]
```

  and after `reapply?`:

```ruby
  # Spec 011 AC-3.1: art matching queues its build after a refresh (Catalog::Refresh calls this hook).
  def after_refresh(run) = MTG::Art.after_refresh(run)
```

- [ ] Change the `catalog:status` task in `lib/tasks/catalog.rake` to print a source's own lines last:

```ruby
  desc 'Show the 10 most recent catalog refresh runs (default mtg): bin/rails "catalog:status[mtg]"'
  task :status, [ :collectible_type ] => :environment do |_task, args|
    collectible_type = args[:collectible_type] || "mtg"
    runs = Catalog::RefreshRun.for_type(collectible_type).recent.limit(10)
    puts "No #{collectible_type} refresh runs yet." if runs.none?
    runs.each { |run| puts run.status_line }
    source = Catalog.source_class(collectible_type)
    source.status_lines.each { |line| puts line } if source.respond_to?(:status_lines)
  end
```

- [ ] Run: `bin/rspec spec/jobs spec/models/mtg spec/models/catalog spec/tasks` — expect: PASS.
- [ ] Commit: `feat(art): queue the art build after a refresh and report it in catalog:status (011)`. Note in the body that `catalog:status` for an unknown type now raises `ArgumentError` (as `catalog:refresh` does) instead of printing "No … refresh runs yet.".

---

## Phase 10: Serving the index

**Implements:** FR-4, FR-1 | **Satisfies:** AC-4.1, AC-4.2, AC-4.3, AC-4.4, AC-1.4 (not served when off), NFR Security (path)
**Files:** `app/controllers/scanner/art_indexes_controller.rb`, `config/routes.rb`, `config/brakeman.ignore`, `spec/requests/scanner/art_indexes_spec.rb`
**Interfaces:** Consumes: `MTG::Art.enabled?`, `MTG::Art::Index.path_for`, `.write!` (Phase 7). Produces: `GET /scanner/art/:name` (`scanner_art_index_path(name)`), public, gzip-encoded, immutable.

- [ ] Write the failing `spec/requests/scanner/art_indexes_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Art index file", :art_matching, type: :request do
  let(:records) { [ [ "aaaaaaaa-0000-4000-8000-000000000001", "\x00".b * 128 ] ] }

  def write(version) = MTG::Art::Index.write!(version, records)

  it "serves the current index pre-compressed, public and immutable for a year, without signing in (AC-4.1, AC-4.4)", :aggregate_failures do
    path = write("v1")

    get scanner_art_index_path(path.basename.to_s)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/octet-stream")
    expect(response.headers["Content-Encoding"]).to eq("gzip")
    expect(response.headers["Cache-Control"]).to include("max-age=31536000", "public", "immutable")
    expect(response.body.b).to eq(path.binread)
  end

  it "answers a repeat request carrying its ETag with 304" do
    path = write("v1")
    get scanner_art_index_path(path.basename.to_s)

    get scanner_art_index_path(path.basename.to_s), headers: { "If-None-Match" => response.headers["ETag"] }

    expect(response).to have_http_status(:not_modified)
  end

  it "keeps serving the previous index after a new one, but nothing older or unknown (AC-4.2, AC-4.3)", :aggregate_failures do
    old = write("v1")
    FileUtils.touch(old, mtime: 3.minutes.ago.to_time)
    previous = write("v2")
    FileUtils.touch(previous, mtime: 2.minutes.ago.to_time)
    write("v3")

    get scanner_art_index_path(previous.basename.to_s)
    expect(response).to have_http_status(:ok)
    [ old.basename.to_s, "art-index-v9-0123456789abcdef-1.bin.gz", "/scanner/art/..%2F..%2Fconfig%2Fmaster.key" ].each do |name|
      get name.start_with?("/") ? name : scanner_art_index_path(name)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "answers 404 with art matching off, keeping the file on disk (AC-1.1, AC-1.4)", :aggregate_failures do
    path = write("v1")
    Rails.configuration.x.mtg_art_matching = false

    get scanner_art_index_path(path.basename.to_s)

    expect(response).to have_http_status(:not_found)
    expect(path).to exist
  end
end
```

- [ ] Run: `bin/rspec spec/requests/scanner/art_indexes_spec.rb` — expect: FAIL (`undefined method 'scanner_art_index_path'`).
- [ ] Add the route to `config/routes.rb`, after the OCR engine route:

```ruby
  # The art index for the card scanner's art matching (spec 011 Story 4): global catalog data, public and immutable.
  get "scanner/art/:name", to: "scanner/art_indexes#show", as: :scanner_art_index, format: false,
    constraints: { name: /art-index-[a-z0-9-]+\.bin\.gz/ }
```

- [ ] Implement `app/controllers/scanner/art_indexes_controller.rb`:

```ruby
# Serves the art index the build wrote (spec 011 Story 4; ADR 0007): only the current or previous file, by its exact
# name, pre-compressed whatever the request's Accept-Encoding (every supported browser takes gzip), cacheable as immutable
# for a year (a new index always has a new name). Global catalog data: no sign-in, nothing tenant-scoped (AC-4.4).
class Scanner::ArtIndexesController < ApplicationController
  allow_unauthenticated_access
  allow_before_first_user

  def show
    path = MTG::Art.enabled? ? MTG::Art::Index.path_for(params[:name]) : nil
    return head(:not_found) unless path

    expires_in 365.days, public: true, immutable: true # 31536000 s
    return unless stale?(etag: path.basename.to_s, last_modified: path.mtime, public: true)

    response.headers["Content-Encoding"] = "gzip"
    send_file path, type: "application/octet-stream", disposition: :inline
  end
end
```

- [ ] Run: `bin/rspec spec/requests/scanner/art_indexes_spec.rb spec/routing` — expect: PASS.
- [ ] Run: `bin/brakeman --quiet --no-pager --exit-on-warn` — expect: one new Weak "Parameter value used in file name" (SendFile) warning for `scanner/art_indexes_controller.rb`, the same shape Brakeman flags for `OcrAssetsController` (already ignored in `config/brakeman.ignore`). Ignore it with a written justification (`.claude/rules/security.md`): run `bin/brakeman -I`, choose the new warning, and give the note "MTG::Art::Index.path_for returns only the current or previous index, matched by exact name (NAME) among the files in MTG::Art.root/index; any other value is nil and answers 404. The parameter never builds a path." Then `bin/brakeman --quiet --no-pager --exit-on-warn` — expect: no warnings. Commit `config/brakeman.ignore` with the controller.
- [ ] Commit: `feat(scanner): serve the art index, public and immutable (011)`

---

## Phase 11: Art on the scanner page

**Implements:** FR-4, FR-5, FR-6 | **Satisfies:** AC-5.1, AC-5.2, AC-5.3, AC-5.4, AC-5.5, AC-5.6, AC-1.1 (page), AC-1.4 (not referenced when off)
**Files:** `app/models/mtg/art.rb`, `app/controllers/concerns/scanner_page.rb`, `app/views/scanners/_scanner.html.erb`, `app/javascript/controllers/card_reader_controller.js`, `app/assets/stylesheets/collector/additions.css`, `spec/models/mtg/art_spec.rb`, `spec/system/scanner_art_spec.rb`
**Interfaces:** Consumes: `scanner/art` (`loadArtIndex`, `matchArtwork`), `MTG::Art::Index.current`, `MTG::Art::Settings.for_page`, `scanner_art_index_path`. Produces: `MTG::Art.page_config → { name:, settings: } | nil`; the helper `scanner_art` (from `ScannerPage`); the card-reader values `artIndexUrl` and `artSettings`, target `artStatus`; the reading fields `reading[artworks][][id]` and `reading[artworks][][distance]`; on the `card-reader:read` event detail, `artworks`, `artMs` and `art` (`{ downloadMs, readyMs }`) and `readyMs`.

- [ ] Add the failing example to `spec/models/mtg/art_spec.rb`:

```ruby
  describe ".page_config (spec 011 AC-5.1)" do
    it "gives the page the current index's name and the settings, only with art on and an index built", :art_matching, :aggregate_failures do
      expect(described_class.page_config).to be_nil
      older = MTG::Art::Index.write!("v1", [])
      FileUtils.touch(older, mtime: 1.minute.ago.to_time)
      path = MTG::Art::Index.write!("v2", [])
      expect(described_class.page_config).to eq(name: path.basename.to_s, settings: MTG::Art::Settings.for_page) # the newest (AC-4.3)
      Rails.configuration.x.mtg_art_matching = false
      expect(described_class.page_config).to be_nil
    end
  end
```

- [ ] Write the failing `spec/system/scanner_art_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Art matching on the scanner page", type: :system do
  let(:text_fields) { [ "reading[name_text]", "reading[collector_text]", "reading[key]" ] }
  let(:art_fields) { [ "reading[artworks][][id]", "reading[artworks][][distance]" ] }

  before do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
  end

  # 12 artworks with seeded random fingerprints, so a search finds 10 (AC-5.3).
  def write_index(count: 12)
    random = Random.new(11)
    records = Array.new(count) { |i| [ format("aaaaaaaa-0000-4000-8000-%012d", i), random.bytes(128) ] }
    MTG::Art::Index.write!("v1", records)
  end

  it "shows no art status and sends only the text with art matching off (AC-1.1, AC-5.1)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
    expect(page).to have_no_css(".c-scanner__art")
    expect(scanner_sent).to eq([ text_fields ])
  end

  context "with art matching on", :art_matching do
    it "has no status line until an index is built (Error Scenarios)" do
      visit scanner_path
      wait_for_scanner
      expect(page).to have_no_css(".c-scanner__art")
    end

    it "loads the index after the scanner starts and sends the 10 nearest artworks with a live capture (AC-5.1–AC-5.3, AC-5.5)", :aggregate_failures do
      write_index
      visit scanner_path
      expect(page).to have_css(".c-scanner__art[role=status][aria-live=polite]", text: "Artwork matching is on", wait: 30)
      show_synthetic_card
      click_on "Capture"

      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      expect(scanner_sent).to eq([ text_fields + art_fields * 10 ])
    end

    it "says art matching isn't available, and sends text only, when the index doesn't match the page (AC-5.2, AC-5.4)", :aggregate_failures do
      path = write_index
      bytes = Zlib.gunzip(path.binread)
      bytes[8, 16] = "0123456789abcdef"
      path.binwrite(ActiveSupport::Gzip.compress(bytes))
      visit scanner_path
      expect(page).to have_css(".c-scanner__art", text: "Artwork matching isn't available. The scanner is reading text only.", wait: 30)
      show_synthetic_card
      click_on "Capture"

      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      expect(scanner_sent).to eq([ text_fields ])
    end

    it "sends no artworks with a picked photo (AC-5.4)", :aggregate_failures do
      write_index
      visit scanner_path
      expect(page).to have_css(".c-scanner__art", text: "Artwork matching is on", wait: 30)
      pick_photo
      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 60)
      expect(scanner_sent).to eq([ text_fields ])
    end
  end
end
```

  `pick_photo` (ScannerHelpers) installs the request recorder through `CARD_JS`.

- [ ] Run: `bin/rspec spec/models/mtg/art_spec.rb spec/system/scanner_art_spec.rb` — expect: FAIL (`page_config` is undefined; the status line never appears).
- [ ] Add to `MTG::Art` (`app/models/mtg/art.rb`):

```ruby
  # What the scanner page needs for art matching (AC-5.1): the current index's name and the fingerprint settings with
  # their digest, or nil with art matching off or no index built yet.
  def self.page_config
    index = enabled? && MTG::Art::Index.current
    { name: index.basename.to_s, settings: MTG::Art::Settings.for_page } if index
  end
```

- [ ] Add the helper to `ScannerPage` (`app/controllers/concerns/scanner_page.rb`), inside `included do`, after the policy block, and a private method below:

```ruby
    helper_method :scanner_art
```

```ruby
  private
    # The art index and settings for this scanner page (spec 011 AC-5.1), or nil.
    def scanner_art = defined?(@scanner_art) ? @scanner_art : (@scanner_art = MTG::Art.page_config)
```

- [ ] Change the opening tag of `app/views/scanners/_scanner.html.erb` and add the status line after `.c-scanner__controls`:

```erb
<%# locals: (sitting:, entries:, summary: nil) %>
<% art = scanner_art %>
<div class="c-scanner" data-controller="card-reader camera"
     data-card-reader-readings-url-value="<%= scanner_readings_path %>" data-card-reader-engine-path-value="<%= ocr_engine_path %>"
     <% if art %>data-card-reader-art-index-url-value="<%= scanner_art_index_path(art[:name]) %>" data-card-reader-art-settings-value="<%= art[:settings].to_json %>"<% end %>
     data-action="camera:ready->card-reader#cameraReady camera:stopped->card-reader#cameraStopped camera:unavailable->card-reader#cameraUnavailable">
```

```erb
  <% if art %>
    <p class="c-scanner__art" role="status" aria-live="polite" data-card-reader-target="artStatus">Loading artwork matching…</p>
  <% end %>
```

- [ ] Add to `app/assets/stylesheets/collector/additions.css`, after `.c-scanner__hint`:

```css
/* Art matching's status under the scanner's controls (spec 011 AC-5.1): quiet, like the hint. */
.c-scanner__art { margin:0; font:400 14px/20px var(--font-sans); color:var(--ink-muted); }
```

- [ ] Change `app/javascript/controllers/card_reader_controller.js`. Imports and the header comment:

```js
import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { cropStrips, guideInFrame, DETECTED_STRIPS, STAGE_ASPECT, STRIPS } from "scanner/geometry"
import { findCard } from "scanner/detector"
import { loadEngine, readStrips } from "scanner/recognition"
import { loadArtIndex, matchArtwork } from "scanner/art"

// Turns a captured frame or a picked photo into what the card says (spec 007 Stories 2–4). A picked photo is first searched
// for the card, which is straightened into the guide's box (spec 009 Story 7); live frames aren't (AC-7.6). It cuts the
// strips, reads them on the device, sends only the text and a reading key, and shows the Turbo Stream answer. One reading at
// a time. With art matching on (spec 011 Story 5) it loads the art index once the scanner has started, and a live capture
// also sends its 10 nearest artworks (ids and distances, never a fingerprint). Dispatches card-reader:read ({ nameText,
// collectorText, ms, key, outline, detectMs, warpMs, artworks, artMs, art, readyMs, strips, frame }) for measurement mode,
// where outline is "live", "found" or "not_found". frame is { image, guide } for live captures, else null.
```

  Targets and values:

```js
  static targets = [ "status", "shutter", "picker", "result", "unavailable", "reason", "retry", "engineRetry",
    "failure", "failureMessage", "failureName", "failureCollector", "signIn", "resend", "artStatus" ]
  static values = { readingsUrl: String, enginePath: String, artIndexUrl: String, artSettings: Object }
```

  In `startEngine`, after `this.engineReady = true`:

```js
      this.readyMs = Math.round(performance.now())
      this.loadArt()
```

  New methods, after `retryEngine()`:

```js
  // Spec 011 AC-5.2: the art index loads once the scanner has started, never delaying the camera or text recognition.
  async loadArt() {
    if (!this.artIndexUrlValue || this.artLoading) return
    this.artLoading = true
    try {
      const { index, downloadMs, readyMs } = await loadArtIndex(this.artIndexUrlValue, this.artSettingsValue)
      this.artIndex = index
      this.artTimings = { downloadMs, readyMs }
      this.sayArt("Artwork matching is on")
    } catch {
      this.sayArt("Artwork matching isn't available. The scanner is reading text only.")
    }
  }

  // A live capture's nearest artworks (AC-5.3), or null before the index is ready, after it failed, or on error.
  matchArt(image, card) {
    if (!this.artIndex) return null
    const started = performance.now()
    try {
      const artworks = matchArtwork(this.artIndex, image, card, this.artSettingsValue.fingerprint)
      return { artworks, artMs: Math.round(performance.now() - started) }
    } catch {
      return null
    }
  }

  sayArt(message) {
    if (this.hasArtStatusTarget) this.artStatusTarget.textContent = message
  }
```

  The `read` method (full):

```js
  async read(prepare) {
    if (this.busy) return
    this.busy = true
    this.render()
    this.say("Reading the card…")
    try {
      const { image, card, layout, ...source } = await prepare()
      // Spec 011: art runs on live captures only (AC-5.4), before OCR, about 35 ms on the phone.
      const art = source.outline === "live" ? this.matchArt(image, card) : null
      const strips = cropStrips(image, card, layout)
      const reading = { ...(await readStrips(this.enginePathValue, strips)), key: readingKey(), ...source, ...(art || {}) }
      if (!this.element.isConnected) return
      // Spec 010: a live capture's frame and guide rect travel with the event, in memory, for measurement mode only.
      const frame = source.outline === "live" ? { image, guide: card } : null
      this.dispatch("read", { detail: { ...reading, strips, frame, art: this.artTimings || null, readyMs: this.readyMs } })
      this.lastReading = reading
      if (await this.send(reading) && reading.outline === "not_found") this.say(NO_EDGE)
    } catch {
      this.say("The card couldn't be read. Line it up with the guide and try again.")
    } finally {
      this.busy = false
      this.render()
    }
  }
```

  The `send` method's head (the rest is unchanged):

```js
  // Sends the text, the reading key (spec 009 FR-5) and a live capture's nearest artworks (spec 011 FR-5), never the
  // outline, timings or a fingerprint; true when the answer was shown.
  async send({ nameText, collectorText, key, artworks }) {
    this.failureTarget.hidden = true
    const body = new FormData()
    body.append("reading[name_text]", nameText)
    body.append("reading[collector_text]", collectorText)
    body.append("reading[key]", key)
    ;(artworks || []).forEach(({ id, distance }) => {
      body.append("reading[artworks][][id]", id)
      body.append("reading[artworks][][distance]", String(distance))
    })
```

- [ ] Run: `bin/rspec spec/models/mtg/art_spec.rb spec/system/scanner_art_spec.rb spec/system/scanner_spec.rb spec/system/scanner_adding_spec.rb` — expect: PASS. The existing `scanner_spec` still sees only the three text fields (art matching is off there).
- [ ] Run the camera page specs 10 times in a row (NFR Reliability): `for i in $(seq 10); do bin/rspec spec/system/scanner_art_spec.rb spec/system/scanner_spec.rb || break; done` — expect: 10 passing runs.
- [ ] Commit: `feat(scanner): match the live capture's artwork on the device and send the nearest (011)`

---

## Phase 12: Art in the ranking

**Implements:** FR-3, FR-5 | **Satisfies:** AC-6.1, AC-6.2, AC-6.3, AC-6.4, AC-6.5, AC-6.6, AC-6.7, AC-6.8
**Files:** `app/models/mtg/art/sent.rb`, `app/models/mtg/art/evidence.rb`, `app/models/mtg/reading.rb`, `app/controllers/scanner/readings_controller.rb`, `spec/models/mtg/art/sent_spec.rb`, `spec/models/mtg/art/evidence_spec.rb`, `spec/models/mtg/reading_art_spec.rb`, `spec/requests/scanner/readings_spec.rb`
**Interfaces:** Consumes: `MTG::Art.enabled?`, `MTG::Artwork`, `mtg_printings.illustration_id`. Produces: `MTG::Art::Sent::ID`, `MTG::Art::Sent::Artwork(:id, :distance)`, `MTG::Art::Sent.from_params(params) → [Artwork] | nil`, `MTG::Art::Sent.parse(raw) → [Artwork] | nil`; `MTG::Art::Evidence.new(sent, text_identity_ids:, margin:)` with `#usable → [Usable(:id, :distance, :identity_id, :printings)]`, `#nearest`, `#confident`, `#card_distances → { identity_id => distance }`; `MTG::Reading::ART_MARGIN = 300`, `MTG::Reading#artworks` (accessor), `#ranking → MTG::Reading::Ranking(:candidates, :tier, :overruled, :overruled_scope, :art_status, :art_usable)`, `#ranking_for(score)`, `#tier`, `#overruled` (`:name | :collector_line | nil`), `#overruled_scope` (`:card | :printing | nil`), `#art_status` (`:matched | :similar | :no_match | nil`), `#art_usable`; `Candidate` gains `artwork_id`, `art_unique`, `art_distance`, `#art?`, `#art_weak?`, `#printing_confirmed?`.

- [ ] Write the failing `spec/models/mtg/art/sent_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Art::Sent, type: :model do
  let(:id) { "aaaaaaaa-0000-4000-8000-000000000001" }

  def params(artworks) = ActionController::Parameters.new(reading: { name_text: "x", artworks: })

  it "reads up to 10 artwork ids with whole-number distances from 0 to 1,024 (AC-6.1)", :art_matching do
    sent = described_class.from_params(params([ { id:, distance: "189" }, { id: id.tr("a", "b"), distance: "0" } ]))
    expect(sent).to eq([ described_class::Artwork.new(id:, distance: 189), described_class::Artwork.new(id: id.tr("a", "b"), distance: 0) ])
  end

  it "drops the whole art part when any entry is malformed, or there are more than 10 (AC-6.1)", :art_matching, :aggregate_failures do
    [ [ { id: id.upcase, distance: "1" } ], [ { id:, distance: "1025" } ], [ { id:, distance: "-1" } ], [ { id:, distance: "1.5" } ],
      [ { id: } ], [ "#{id}" ], Array.new(11) { { id:, distance: "1" } }, [] ].each do |artworks|
      expect(described_class.from_params(params(artworks))).to be_nil
    end
    expect(described_class.from_params(ActionController::Parameters.new(reading: { artworks: "x" }))).to be_nil
    expect(described_class.from_params(ActionController::Parameters.new(reading: "x"))).to be_nil
  end

  it "reads nothing with art matching off (AC-1.1)" do
    expect(described_class.from_params(params([ { id:, distance: "1" } ]))).to be_nil
  end
end
```

- [ ] Write the failing `spec/models/mtg/art/evidence_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Art::Evidence, type: :model do
  let(:bolt) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:plains) { create(:catalog_identity, name: "Plains") }

  def artwork(id, identity:, printings: 1, **entry)
    entries = Array.new(printings) do |i|
      create(:mtg_printing, illustration_id: id, entry: create(:catalog_entry, identity:, released_on: Date.new(2000 + i, 1, 1), **entry)).entry
    end
    create(:mtg_artwork, illustration_id: id, entry: entries.first)
    entries
  end

  def sent(*pairs) = pairs.map { |id, distance| MTG::Art::Sent::Artwork.new(id:, distance:) }

  def evidence(*pairs, text: []) = described_class.new(sent(*pairs), text_identity_ids: text, margin: 300)

  it "keeps only artworks in the table that have English card printings, nearest first (glossary)", :aggregate_failures do
    near = artwork("a" * 8 + "-0000-4000-8000-000000000001", identity: bolt, printings: 2)
    artwork("b" * 8 + "-0000-4000-8000-000000000002", identity: bolt, kind: "art_card")
    create(:mtg_printing, illustration_id: "c" * 8 + "-0000-4000-8000-000000000003") # not in the artwork table

    usable = evidence([ "c" * 8 + "-0000-4000-8000-000000000003", 10 ], [ "b" * 8 + "-0000-4000-8000-000000000002", 20 ],
      [ "a" * 8 + "-0000-4000-8000-000000000001", 150 ]).usable

    expect(usable.map(&:id)).to eq([ "a" * 8 + "-0000-4000-8000-000000000001" ])
    expect(usable.first).to have_attributes(distance: 150, identity_id: bolt.id, printings: near.reverse)
  end

  it "is confident at or below the margin, and says so for the nearest usable artwork only", :aggregate_failures do
    artwork("a" * 8 + "-0000-4000-8000-000000000001", identity: bolt)
    expect(evidence([ "a" * 8 + "-0000-4000-8000-000000000001", 300 ]).confident).to be_present
    expect(evidence([ "a" * 8 + "-0000-4000-8000-000000000001", 301 ]).confident).to be_nil
  end

  it "gives a two-card artwork to the text candidate with the best name rank, or drops it (glossary)", :aggregate_failures do
    shared = "d" * 8 + "-0000-4000-8000-000000000004"
    artwork(shared, identity: bolt)
    create(:mtg_printing, illustration_id: shared, entry: create(:catalog_entry, identity: plains))
    other = "e" * 8 + "-0000-4000-8000-000000000005"
    artwork(other, identity: plains)

    expect(evidence([ shared, 150 ], [ other, 200 ], text: [ plains.id, bolt.id ]).usable.map(&:identity_id)).to eq([ plains.id, plains.id ])
    without = evidence([ shared, 150 ], [ other, 200 ], text: [])
    expect(without.usable.map(&:id)).to eq([ other ])
    expect(without.confident).to have_attributes(id: other, identity_id: plains.id)
  end

  it "keeps each card's smallest distance" do
    artwork("a" * 8 + "-0000-4000-8000-000000000001", identity: bolt)
    artwork("f" * 8 + "-0000-4000-8000-000000000006", identity: bolt)
    distances = evidence([ "a" * 8 + "-0000-4000-8000-000000000001", 340 ], [ "f" * 8 + "-0000-4000-8000-000000000006", 320 ]).card_distances
    expect(distances).to eq(bolt.id => 320)
  end
end
```

- [ ] Write the failing `spec/models/mtg/reading_art_spec.rb`:

```ruby
require "rails_helper"

# Spec 011 Story 6: art evidence in MTG::Reading's ranking. Text-only rankings are spec 009's (reading_spec.rb, AC-6.8).
RSpec.describe MTG::Reading, type: :model do
  def art_id(key)
    { plains: "aaaaaaaa-0000-4000-8000-000000000001", shared: "bbbbbbbb-0000-4000-8000-000000000002",
      bolt: "cccccccc-0000-4000-8000-000000000003", helix: "dddddddd-0000-4000-8000-000000000004",
      unknown: "eeeeeeee-0000-4000-8000-000000000005" }.fetch(key)
  end

  # Plains M10 233 has an artwork of its own; Plains FDN 272 shares one (with MOM 277 in one context); Bolt MOM 123.
  let!(:cards) do
    sets = { m10: [ 2009, 7, 17 ], fdn: [ 2024, 11, 15 ], mom: [ 2023, 4, 21 ] }
      .to_h { |code, date| [ code, create(:catalog_set, code: code.to_s, released_on: Date.new(*date)) ] }
    { sets:, plains_m10: printing("Plains", sets[:m10], "233", :plains), plains_fdn: printing("Plains", sets[:fdn], "272", :shared),
      bolt: printing("Lightning Bolt", sets[:mom], "123", :bolt) }
  end

  before { Catalog::NameIndex.new("mtg").rebuild }

  def printing(name, set, number, art)
    identity = Catalog::Identity.find_by(name:) || create(:catalog_identity, name:)
    entry = create(:catalog_entry, identity:, name:, set:, number:, released_on: set.released_on)
    create(:mtg_printing, entry:, illustration_id: art_id(art))
    MTG::Artwork.find_by(illustration_id: art_id(art)) || create(:mtg_artwork, illustration_id: art_id(art), entry:)
    entry
  end

  def read(name_text: "", collector_text: "", art: nil)
    artworks = art&.map { |key, distance| MTG::Art::Sent::Artwork.new(id: art_id(key), distance:) }
    described_class.new(name_text:, collector_text:, artworks:).resolve
  end

  it "ranks the confident artwork's card first, its only printing, overruling the name's printing (AC-6.3, AC-6.4, AC-6.7)", :aggregate_failures do
    reading = read(name_text: "Plains", art: { plains: 175 })

    expect(reading.candidates.first).to have_attributes(entry: cards[:plains_m10], evidence: %i[art name], art_unique: true, artwork_id: art_id(:plains))
    expect(reading).to have_attributes(tier: :art, overruled: :name, overruled_scope: :printing, art_status: :matched)
  end

  it "ranks confident art above a strong name for another card, which comes second (AC-6.3)", :aggregate_failures do
    reading = read(name_text: "Lightning Bolt", art: { plains: 120 })

    expect(reading.candidates.map(&:entry)).to eq([ cards[:plains_m10], cards[:bolt] ])
    expect(reading.candidates.second).to have_attributes(strong_name: true, evidence: %i[name])
    expect(reading).to have_attributes(overruled: :name, overruled_scope: :card)
  end

  it "ranks confident art above a collector-line match, and says the collector line was overruled (AC-6.3, AC-6.7)", :aggregate_failures do
    reading = read(collector_text: "R 0123\nMOM • EN", art: { plains: 120 })

    expect(reading.candidates.map(&:entry)).to eq([ cards[:plains_m10], cards[:bolt] ])
    expect(reading).to have_attributes(overruled: :collector_line, overruled_scope: :card)
  end

  it "adds the confident card even when no text was read (AC-6.3)", :aggregate_failures do
    reading = read(art: { plains: 120 })

    expect(reading).to be_nothing_read
    expect(reading.candidates.map(&:entry)).to eq([ cards[:plains_m10] ])
    expect(reading).to have_attributes(overruled: nil, art_status: :matched)
  end

  context "when several printings share the confident artwork (AC-6.4)" do
    let!(:plains_mom) { printing("Plains", cards[:sets][:mom], "277", :shared) }

    it "keeps the collector line's printing when it's one of them, with both kinds of evidence", :aggregate_failures do
      reading = read(name_text: "Plains", collector_text: "C 0272\nFDN • EN", art: { shared: 150 })

      expect(reading.candidates.first).to have_attributes(entry: cards[:plains_fdn], evidence: %i[collector_line name art], art_unique: false)
      expect(reading.candidates.first).to be_printing_confirmed
      expect(reading.overruled).to be_nil
    end

    it "takes the newest in the read set, else the newest, unconfirmed", :aggregate_failures do
      expect(read(name_text: "Plains", collector_text: "C 0999\nMOM • EN", art: { shared: 150 }).candidates.first.entry).to eq(plains_mom)
      newest = read(name_text: "Plains", art: { shared: 150 }).candidates.first
      expect(newest).to have_attributes(entry: cards[:plains_fdn], evidence: %i[art name])
      expect(newest).not_to be_printing_confirmed
    end

    it "doesn't keep a collector-line printing of the same card with another artwork (AC-6.4)", :aggregate_failures do
      reading = read(name_text: "Plains", collector_text: "C 0233\nM10 • EN", art: { shared: 150 })

      expect(reading.candidates.first).to have_attributes(entry: cards[:plains_fdn], evidence: %i[art name])
      expect(reading).to have_attributes(overruled: :collector_line, overruled_scope: :printing)
    end
  end

  it "uses weak art only to break a tie between name-only candidates, never changing a printing (AC-6.5)", :aggregate_failures do
    helix = printing("Lightning Helix", cards[:sets][:mom], "200", :helix)
    Catalog::NameIndex.new("mtg").rebuild
    text = read(name_text: "Lightning").candidates.map(&:entry)
    reading = read(name_text: "Lightning", art: { helix: 410 })

    expect(reading.candidates.map(&:entry)).to eq([ helix, *(text - [ helix ]) ])
    expect(reading.candidates.first).to have_attributes(evidence: %i[name art_weak], art_distance: 410)
    expect(reading).to have_attributes(tier: :art_weak, art_status: :similar, overruled: nil)
  end

  it "never lets weak art outrank a strong name or add a card (AC-6.5)", :aggregate_failures do
    reading = read(name_text: "Lightning Bolt", art: { plains: 400 })

    expect(reading.candidates.map(&:entry)).to eq([ cards[:bolt] ])
    expect(reading).to have_attributes(tier: :strong_name, art_status: :no_match)
  end

  it "gives weak art to another candidate's card even when one card is confident (glossary)" do
    reading = read(name_text: "Lightning Bolt", art: { plains: 120, bolt: 290 })

    expect(reading.candidates.map { [ it.entry, it.evidence ] }).to eq([ [ cards[:plains_m10], %i[art] ], [ cards[:bolt], %i[name art_weak] ] ])
  end

  it "ignores an artwork id it doesn't know, and ranks as spec 009 without artworks (AC-6.1, AC-6.8)", :aggregate_failures do
    unknown = read(name_text: "Lightning Bolt", art: { unknown: 10 })
    expect(unknown.candidates.map(&:entry)).to eq([ cards[:bolt] ])
    expect(unknown.art_status).to eq(:no_match)
    expect(read(name_text: "Lightning Bolt")).to have_attributes(art_status: nil, tier: :strong_name, overruled: nil)
  end

  it "keeps the margin beside the strong-name threshold" do
    expect(described_class::ART_MARGIN).to eq(300)
  end
end
```

  The artwork ids come from a helper method, not a constant in the group (`RSpec/LeakyConstantDeclaration`). The collector-line texts follow `spec/models/mtg/reading_spec.rb`'s format (`"R 0123\nMOM • EN"`): rarity letter, number, then set and language.

- [ ] Run: `bin/rspec spec/models/mtg/art/sent_spec.rb spec/models/mtg/art/evidence_spec.rb spec/models/mtg/reading_art_spec.rb` — expect: FAIL (uninitialized constants; `artworks` unknown).
- [ ] Implement `app/models/mtg/art/sent.rb`:

```ruby
# The art part of a reading request (spec 011 AC-6.1): up to 10 artwork ids (lowercase UUIDs, as Scryfall writes
# illustration_id) with whole-number distances from 0 to 1,024. Read leniently, apart from the text's strict parameters:
# anything malformed drops the whole art part and the text ranks alone; the request never fails for it. nil means no art.
module MTG::Art::Sent
  ID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  DISTANCE = /\A\d{1,4}\z/
  MAX = 10

  Artwork = Data.define(:id, :distance)

  def self.from_params(params)
    return unless MTG::Art.enabled?

    reading = params[:reading]
    parse(reading[:artworks]) if reading.respond_to?(:key?)
  end

  def self.parse(raw)
    return unless raw.is_a?(Array) && raw.size.between?(1, MAX)

    artworks = raw.map do |item|
      return unless item.respond_to?(:key?)

      id, distance = item[:id].to_s, item[:distance].to_s
      return unless ID.match?(id) && DISTANCE.match?(distance) && distance.to_i <= 1_024

      Artwork.new(id:, distance: distance.to_i)
    end
    artworks
  end
end
```

  `ActionController::Parameters` and `Hash` both answer `key?`; `return` inside the `map` block returns `nil` from `parse`.

- [ ] Implement `app/models/mtg/art/evidence.rb`:

```ruby
# A reading's art evidence (spec 011 Story 6): the usable artworks among those the page sent, nearest first. An artwork
# is usable when it's in the artwork table, has printings (not retired, ordinary cards, English: the printings the scanner
# ranks over) and has a card: the card of its printings, or, when they belong to several cards, the one among the text's
# candidates with the best name rank (glossary). The rest give no evidence at all.
class MTG::Art::Evidence
  Usable = Data.define(:id, :distance, :identity_id, :printings)

  def initialize(sent, text_identity_ids:, margin:)
    @sent = sent
    @text_identity_ids = text_identity_ids
    @margin = margin
  end

  def usable
    @usable ||= begin
      printings = printings_by_artwork
      @sent.each_with_index.sort_by { |artwork, index| [ artwork.distance, index ] }.filter_map do |artwork, _index|
        entries = printings[artwork.id]
        identity_id = entries && card_for(entries)
        Usable.new(id: artwork.id, distance: artwork.distance, identity_id:, printings: entries) if identity_id
      end
    end
  end

  def nearest = usable.first

  def confident = nearest if nearest && nearest.distance <= @margin

  # Each card's smallest distance among the usable artworks.
  def card_distances = usable.each_with_object({}) { |artwork, distances| distances[artwork.identity_id] ||= artwork.distance }

  private
    # { illustration_id => [entries, newest first] } for the sent artworks that are in the artwork table.
    def printings_by_artwork
      known = MTG::Artwork.where(illustration_id: @sent.map(&:id)).pluck(:illustration_id)
      return {} if known.empty?

      artwork_of = MTG::Printing.where(illustration_id: known).pluck(:catalog_entry_id, :illustration_id).to_h
      Catalog::Entry.searchable.where(id: artwork_of.keys, collectible_type: "mtg", language: "en")
        .newest_first.includes(:set, :identity).to_a.group_by { artwork_of.fetch(it.id) }
    end

    def card_for(entries)
      ids = entries.map(&:catalog_identity_id).uniq
      ids.one? ? ids.first : @text_identity_ids.find { ids.include?(it) }
    end
end
```

- [ ] Change `app/models/mtg/reading.rb`. The header comment, constants, `Candidate`, `Ranking` and the public ranking methods:

```ruby
# What the scanner read from one card, and the printings it points to (spec 007 Story 3, spec 009 Story 5, spec 011
# Story 6): the parsed collector line and its printing lookup (one, none or several), the name index's candidates from the
# name strip alone, the art evidence of a live capture's nearest artworks, and the final ranking the page shows. Each
# candidate carries the kinds of evidence behind it, and one rule orders them (spec 009 AC-5.5, spec 011 AC-6.6):
# confident art first, then a strong name match, then collector-line evidence, then weak art, then the name order. Only
# text and artwork ids with distances arrive here; the photo and its fingerprint stay on the device.
class MTG::Reading
  include ActiveModel::Model
  include ActiveModel::Attributes

  COLLECTIBLE_TYPE = "mtg"
  CANDIDATES = 3
  MAX_TEXT_LENGTH = 2_000
  # The top name candidate is a strong match at this Jaro-Winkler similarity to the cleaned query or above (spec 009
  # AC-5.1). Chosen with `bin/rails scanner:strong_sweep` on the stored text of earlier runs; frozen with the settings.
  STRONG_NAME_SCORE = 0.96
  # The nearest artwork is a confident match at this Hamming distance (of 1,024 bits) or below (spec 011 AC-6.2).
  # Provisional, from spec 010's guide-path distances on spec 009's 35 cards; the closing measurement checks it.
  ART_MARGIN = 300

  # evidence: the kinds behind the candidate, from :collector_line, :collector_line_corrected, :name, :art and :art_weak
  # (spec 011 AC-6.6); name_rank: its place among the name candidates, if any; strong_name: it's the top name candidate,
  # strongly matched; artwork_id and art_unique: a confident artwork and whether it belongs to this one printing;
  # art_distance: the card's nearest artwork distance (confident or weak).
  Candidate = Data.define(:entry, :evidence, :name_rank, :strong_name, :artwork_id, :art_unique, :art_distance) do
    def initialize(entry:, evidence:, name_rank:, strong_name:, artwork_id: nil, art_unique: false, art_distance: nil)
      super(entry:, evidence:, name_rank:, strong_name:, artwork_id:, art_unique:, art_distance:)
    end

    def collector_line? = evidence.intersect?(%i[collector_line collector_line_corrected])
    def corrected? = evidence.include?(:collector_line_corrected)
    def name? = evidence.include?(:name)
    def art? = evidence.include?(:art)
    def art_weak? = evidence.include?(:art_weak)
    def printing_confirmed? = collector_line? || (art? && art_unique)

    # The one ranking rule (spec 009 AC-5.5, spec 011 AC-6.6). Without art it orders exactly as spec 009's did.
    def rank_key = [ art? ? 0 : 1, strong_name ? 0 : 1, collector_line? ? 0 : 1, art_weak? ? 0 : 1, name_rank || CANDIDATES ]
  end

  # The ranked candidates and what decided them (spec 011 AC-6.7), in memory only. tier: the first candidate's first
  # qualifying part of the rank rule; overruled: :name or :collector_line when confident art changed the card or
  # printing spec 009's ranking put first (overruled_scope :card or :printing); art_status: :matched, :similar or
  # :no_match when art was sent, else nil; art_usable: the usable artworks, nearest first.
  Ranking = Data.define(:candidates, :tier, :overruled, :overruled_scope, :art_status, :art_usable)

  attribute :name_text, :string, default: ""
  attribute :collector_text, :string, default: ""
  # The page's nearest artworks (MTG::Art::Sent), or nil when none were sent or they were dropped (spec 011 AC-6.1).
  attr_accessor :artworks

  validates :name_text, :collector_text, length: { maximum: MAX_TEXT_LENGTH }
```

  Keep `resolve`, `catalog_ready?`, `nothing_read?`, `collector_line`, `collector_status`, `collector_entries`, `name_candidates` and `finish_hint` as they are. Replace `candidates` and `ranked` with:

```ruby
  def ranking = @ranking ||= ranking_for(STRONG_NAME_SCORE)

  def candidates = ranking.candidates

  delegate :tier, :overruled, :overruled_scope, :art_status, :art_usable, to: :ranking

  # The final ranking with a given strong-name threshold; the findings sweep tries several (spec 009 AC-5.1).
  def ranked(strong_name_score) = ranking_for(strong_name_score).candidates

  def ranking_for(strong_name_score)
    by_card = text_candidates(strong_name_score)
    text_alone = top(by_card.values)
    return Ranking.new(candidates: text_alone, tier: tier_of(text_alone.first), overruled: nil, overruled_scope: nil, art_status: nil, art_usable: []) if artworks.nil?

    evidence = MTG::Art::Evidence.new(artworks, text_identity_ids: by_card.keys, margin: ART_MARGIN)
    confident = evidence.confident
    by_card[confident.identity_id] = art_candidate(confident, by_card[confident.identity_id]) if confident
    add_weak_art(by_card, evidence.card_distances, except: confident&.identity_id)
    final = top(by_card.values)
    overruled, scope = overrule(text_alone.first, confident && final.first)
    Ranking.new(candidates: final, tier: tier_of(final.first), overruled:, overruled_scope: scope,
      art_status: art_status(confident, final), art_usable: evidence.usable)
  end
```

  In `private`, add the text ranking (spec 009's `ranked` body, minus the sort) and the art helpers:

```ruby
    # Spec 009's ranking by card, before the order is applied: identity id => Candidate, name candidates in name order,
    # then the collector-line card when it isn't one of them.
    def text_candidates(strong_name_score)
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
      by_card
    end

    def top(candidates) = candidates.each_with_index.sort_by { |candidate, index| [ *candidate.rank_key, index ] }.map(&:first).first(CANDIDATES)

    # Spec 011 AC-6.4: the confident artwork's card, with its printing chosen among the artwork's printings (newest
    # first): its only printing; else the collector line's printing (or spec 009's corrected one) when it's among them;
    # else the newest in the read set; else the newest. A collector-line printing with another artwork isn't kept.
    def art_candidate(artwork, text)
      kept = text if text&.collector_line? && artwork.printings.any? { it.id == text.entry.id }
      entry = kept&.entry || artwork.printings.find { it.set.code.casecmp?(collector_line.set_code.to_s) } || artwork.printings.first
      evidence = kept ? kept.evidence + %i[art] : [ :art, *(%i[name] if text&.name?) ]
      Candidate.new(entry:, evidence:, name_rank: text&.name_rank, strong_name: text&.strong_name || false,
        artwork_id: artwork.id, art_unique: artwork.printings.one?, art_distance: artwork.distance)
    end

    # Spec 011 AC-6.5 and the glossary: every other text candidate's card owning one of the usable artworks holds weak
    # art, whatever its distance. It only adds evidence; it never adds a card or changes a printing.
    def add_weak_art(by_card, distances, except:)
      by_card.each do |identity_id, candidate|
        distance = distances[identity_id]
        next if identity_id == except || distance.nil?

        by_card[identity_id] = candidate.with(evidence: candidate.evidence + %i[art_weak], art_distance: distance)
      end
    end

    # Spec 011 AC-6.7: what confident art overruled in spec 009's ranking of the same reading.
    def overrule(text_first, art_first)
      return [ nil, nil ] if text_first.nil? || art_first.nil? || text_first.entry.id == art_first.entry.id

      [ text_first.collector_line? ? :collector_line : :name,
        text_first.entry.catalog_identity_id == art_first.entry.catalog_identity_id ? :printing : :card ]
    end

    def art_status(confident, final)
      if confident then :matched
      elsif final.any?(&:art_weak?) then :similar
      else :no_match
      end
    end

    def tier_of(candidate)
      return if candidate.nil?

      if candidate.art? then :art
      elsif candidate.strong_name then :strong_name
      elsif candidate.collector_line? then :collector_line
      elsif candidate.art_weak? then :art_weak
      else :name_rank
      end
    end
```

  `by_card` is modified while iterating in `add_weak_art`; reassigning an existing key's value during `each` is allowed in Ruby (no new keys are added).
  For the case where art keeps a unique printing that the collector line also matched (`kept` and `artwork.printings.one?`), the candidate carries `%i[collector_line name art]` with `art_unique: true`.

- [ ] Run: `bin/rspec spec/models/mtg` — expect: PASS, including every example in `spec/models/mtg/reading_spec.rb` unchanged (AC-6.8).
- [ ] Run: `bin/rails runner 'puts Collector::ScannerFindings::Ranking.instance_method(:initialize).arity' && bin/rspec spec/lib` — expect: PASS (the findings tooling still calls `ranked(score)` and `candidates`).
- [ ] Add the failing request examples to `spec/requests/scanner/readings_spec.rb`, inside `context "when the name index is built"`:

```ruby
    context "with art matching on (spec 011)", :art_matching do
      let(:art) { "aaaaaaaa-0000-4000-8000-000000000001" }

      before do
        MTG::Printing.find_by!(catalog_entry_id: bolt.id).update!(illustration_id: art)
        create(:mtg_artwork, illustration_id: art, entry: bolt)
      end

      def read_with_art(artworks, name_text: "Lightnlng Bo1t")
        post scanner_readings_path, params: { reading: { name_text:, collector_text: "", key:, artworks: } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      it "ranks with the artworks sent (AC-6.3)", :aggregate_failures do
        read_with_art([ { id: art, distance: 120 } ], name_text: "")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Lightning Bolt", "MOM · 123")
      end

      it "never refuses a reading for its art part (AC-6.1)", :aggregate_failures do
        read_with_art([ { id: "not-a-uuid", distance: 120 } ])
        expect(response).to have_http_status(:ok)
        read_with_art("x")
        expect(response).to have_http_status(:ok)
      end
    end

    it "ignores artworks with art matching off (AC-1.1)", :aggregate_failures do
      post scanner_readings_path, params: { reading: { name_text: "", collector_text: "", key:, artworks: [ { id: "aaaaaaaa-0000-4000-8000-000000000001", distance: 1 } ] } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include("Nothing could be read")
    end
```

- [ ] Run: `bin/rspec spec/requests/scanner/readings_spec.rb` — expect: FAIL ("ranks with the artworks sent": nothing could be read).
- [ ] Change `Scanner::ReadingsController#create` (full action and header comment):

```ruby
# Turns what was read off a card into what the page shows (spec 007 Story 3): the candidates, each with an add button per
# finish for this reading (spec 009 Story 1). Only the text, the page's reading key and a live capture's nearest artworks
# (ids and distances, spec 011 FR-5) arrive here; the photo and its fingerprint never leave the device.
class Scanner::ReadingsController < ApplicationController
  TOO_LONG = "That reading was too long to use. Line the card up with the guide and capture it again.".freeze
  NO_KEY = "That reading couldn't be used. Capture the card again.".freeze

  def create
    attributes = params.expect(reading: %i[name_text collector_text key])
    reading = MTG::Reading.new(attributes.slice(:name_text, :collector_text))
    reading.artworks = MTG::Art::Sent.from_params(params) # read leniently: never fails the request (spec 011 AC-6.1)
    key = attributes[:key].to_s
    if !Scanner::Sitting::KEY_FORMAT.match?(key) then refuse(NO_KEY)
    elsif reading.valid?
      render turbo_stream: turbo_stream.update("scanner_result", partial: "scanners/result", locals: { reading: reading.resolve, key: })
    else refuse(TOO_LONG)
    end
  end
```

- [ ] Change the "nothing read" branch of `app/views/scanners/_result.html.erb` so confident art shows (AC-6.3):

```erb
<% elsif reading.nothing_read? && reading.candidates.empty? %>
```

- [ ] Run: `bin/rspec spec/requests/scanner spec/models` — expect: PASS. If `params.expect` rejects the nested `artworks` in development or test (it logs unpermitted keys; check `log/test.log`), leave it: logging is the default and nothing raises.
- [ ] Commit: `feat(scanner): rank by art evidence, confident art first (011)`

---
## Phase 13: The confirm step shows art

**Implements:** FR-6, FR-3 | **Satisfies:** AC-7.1, AC-7.2, AC-7.3, AC-7.4, AC-7.5, NFR Accessibility
**Files:** `app/helpers/scanners_helper.rb`, `app/views/scanners/_result.html.erb`, `app/views/scanners/_candidate.html.erb`, `app/models/scanner/other_printings.rb`, `app/controllers/scanner/printings_controller.rb`, `docs/design-system/components/Scanner.md`, `spec/helpers/scanners_helper_spec.rb`, `spec/requests/scanner/readings_spec.rb`, `spec/requests/scanner/printings_spec.rb`, `spec/models/scanner/other_printings_spec.rb`
**Interfaces:** Consumes: `MTG::Reading#art_status`, `#overruled`, `#overruled_scope`, `Candidate#art?`, `#art_weak?`, `#art_unique`, `#artwork_id` (Phase 12); `MTG::Art::Sent::ID`. Produces: `ScannersHelper#scanner_art_outcome(reading) → String | nil`, `#scanner_overrule_note(reading) → String | nil`; `Scanner::OtherPrintings.new(identity:, set_code: nil, number: nil, artwork: nil)`; the `artwork` parameter of `scanner_printings_path`.

Before writing the markup, follow the `collector-design-system` skill: read `docs/design-system/README.md` and `docs/design-system/components/Badge.md`, `StatusMessage.md` and `Scanner.md`. Only existing classes are used: `c-badge c-badge--success`, `c-scanner__evidence`, `c-scanner__read`, `c-status__message`.

- [ ] Write the failing `spec/helpers/scanners_helper_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ScannersHelper, type: :helper do
  let(:reading_class) { Data.define(:art_status, :overruled, :overruled_scope) }

  def reading(art_status, overruled = nil, overruled_scope = nil) = reading_class.new(art_status, overruled, overruled_scope)

  it "names the artwork's outcome for a reading sent with artworks, and nothing otherwise (AC-7.1)", :aggregate_failures do
    expect(%i[matched similar no_match].map { helper.scanner_art_outcome(reading(it)) }).to eq([ "Matched", "Looks similar", "No match" ])
    expect(helper.scanner_art_outcome(reading(nil))).to be_nil
  end

  it "says what confident art overruled, the name or the collector line, and whether the card or the printing (AC-7.4)" do
    notes = [ %i[name card], %i[name printing], %i[collector_line card], %i[collector_line printing] ]
      .map { |overruled, scope| helper.scanner_overrule_note(reading(:matched, overruled, scope)) }

    expect(notes).to eq([
      "The artwork matches a different card from the one the name suggests. The artwork's match is first.",
      "The artwork matches a different printing from the one the name suggests. The artwork's match is first.",
      "The artwork matches a different card from the one the collector line suggests. The artwork's match is first.",
      "The artwork matches a different printing from the one the collector line suggests. The artwork's match is first."
    ])
  end

  it "has no note when art overruled nothing" do
    expect(helper.scanner_overrule_note(reading(:matched))).to be_nil
  end
end
```

- [ ] Add the failing request examples to the `"with art matching on (spec 011)"` context of `spec/requests/scanner/readings_spec.rb` (Phase 12), after its existing examples:

```ruby
      def html = Nokogiri::HTML5(response.body)

      it "shows Matched, the art badge on the artwork's only printing, and the note when art overrules (AC-7.1, AC-7.2, AC-7.4)", :aggregate_failures do
        create(:mtg_printing, entry: create(:catalog_entry, identity: create(:catalog_identity, name: "Shock"), name: "Shock", set: mom, number: "9"))
        Catalog::NameIndex.new("mtg").rebuild
        read_with_art([ { id: art, distance: 150 } ], name_text: "Shock")

        expect(html.css(".c-scanner__read dt").map(&:text)).to include("Artwork")
        expect(html.at_css(".c-scanner__read dt:contains('Artwork') + dd").text).to eq("Matched")
        expect(html.at_css(".c-scanner__candidate .c-badge--success").text.strip).to eq("Matched by its artwork")
        expect(response.body).to include("The artwork matches a different card from the one the name suggests.")
        expect(html.at_css(".c-scanner__candidate a[href*='artwork=#{art}']")).to be_present
      end

      it "marks a shared artwork's printing as not confirmed, with the art as evidence (AC-7.2)", :aggregate_failures do
        create(:mtg_printing, illustration_id: art, entry: create(:catalog_entry, identity: bolt.identity, name: "Lightning Bolt", set: create(:catalog_set, code: "m25"), number: "5"))
        read_with_art([ { id: art, distance: 150 } ], name_text: "")

        candidate = html.at_css(".c-scanner__candidate")
        expect(candidate.at_css(".c-badge--warning").text).to include("Printing not confirmed")
        expect(candidate.css(".c-scanner__evidence").map(&:text)).to include("Matched by its artwork")
      end

      it "shows Looks similar and the weak evidence line, with no art badge (AC-7.1, AC-7.3)", :aggregate_failures do
        read_with_art([ { id: art, distance: 420 } ], name_text: "Lightning Bolt")

        expect(html.at_css(".c-scanner__read dt:contains('Artwork') + dd").text).to eq("Looks similar")
        expect(html.css(".c-scanner__evidence").map(&:text)).to include("Artwork looks similar")
        expect(response.body).not_to include("Matched by its artwork")
      end

      it "shows No match when no sent artwork is usable, and no Artwork row when none were sent (AC-7.1)", :aggregate_failures do
        read_with_art([ { id: "bbbbbbbb-0000-4000-8000-000000000002", distance: 10 } ], name_text: "Lightning Bolt")
        expect(html.at_css(".c-scanner__read dt:contains('Artwork') + dd").text).to eq("No match")
        read("Lightning Bolt", "")
        expect(html.css(".c-scanner__read dt").map(&:text)).not_to include("Artwork")
      end
```

  Nokogiri's CSS `:contains()` is supported. These examples sit inside a context that already has 2 memoised helpers from the file (`mom`, `bolt`, `key`) plus `art`: 4, under the limit of 5.

- [ ] Add the failing examples to `spec/requests/scanner/printings_spec.rb`:

```ruby
  it "lists the confident artwork's printings first, newest first, then spec 009's order (spec 011 AC-7.5)", :aggregate_failures do
    art = "aaaaaaaa-0000-4000-8000-000000000001"
    m11 = Catalog::Entry.joins(:set).find_by!(catalog_sets: { code: "m11" })
    MTG::Printing.find_by!(catalog_entry_id: m11.id).update!(illustration_id: art)

    other_printings(set: "m10", number: "146", artwork: art)
    expect(Nokogiri::HTML5(response.body).css("li .is-data").map(&:text)).to eq([ "M11 · 146", "M10 · 146" ])

    other_printings(set: "m10", number: "146", artwork: "not-an-artwork")
    expect(Nokogiri::HTML5(response.body).css("li .is-data").map(&:text)).to eq([ "M10 · 146", "M11 · 146" ])
  end
```

- [ ] Run: `bin/rspec spec/helpers/scanners_helper_spec.rb spec/requests/scanner` — expect: FAIL (the helpers, the markup and the `artwork` parameter don't exist).
- [ ] Add to `ScannersHelper` (`app/helpers/scanners_helper.rb`):

```ruby
  ART_OUTCOMES = { matched: "Matched", similar: "Looks similar", no_match: "No match" }.freeze

  # The Artwork row of "What the scanner read" (spec 011 AC-7.1): nil when no artworks were sent.
  def scanner_art_outcome(reading) = reading.art_status && ART_OUTCOMES.fetch(reading.art_status)

  # One sentence when confident art overruled what the text suggested (spec 011 AC-7.4).
  def scanner_overrule_note(reading)
    return unless reading.overruled

    what = reading.overruled_scope == :card ? "card" : "printing"
    by = reading.overruled == :collector_line ? "collector line" : "name"
    "The artwork matches a different #{what} from the one the #{by} suggests. The artwork's match is first."
  end
```

- [ ] In `app/views/scanners/_result.html.erb`, add the Artwork row after the Printing row and the note before the grid:

```erb
      <dt>Printing</dt><dd><%= collector_outcome(reading) %></dd>
      <% if (art = scanner_art_outcome(reading)) %><dt>Artwork</dt><dd><%= art %></dd><% end %>
```

```erb
    <% else %>
      <% if (note = scanner_overrule_note(reading)) %><p class="c-status__message"><%= note %></p><% end %>
      <div class="c-grid">
```

- [ ] Replace the badge and evidence lines of `app/views/scanners/_candidate.html.erb` (from `<% if candidate.collector_line? %>` to the "Matched by its name" line) and add the artwork to the Other printings link:

```erb
  <% if candidate.collector_line? %>
    <span class="c-badge c-badge--success"><%= render "icons/check" %><%= candidate.corrected? ? "Matched by its collector line, one digit corrected" : "Matched by its collector line" %></span>
  <% elsif candidate.art? && candidate.art_unique %>
    <span class="c-badge c-badge--success"><%= render "icons/check" %>Matched by its artwork</span>
  <% else %>
    <span class="c-badge c-badge--warning"><%= render "icons/alert" %>Printing not confirmed</span>
  <% end %>
  <% if candidate.art? && (candidate.collector_line? || !candidate.art_unique) %><span class="c-scanner__evidence">Matched by its artwork</span><% end %>
  <% if candidate.art_weak? %><span class="c-scanner__evidence">Artwork looks similar</span><% end %>
  <% if candidate.name? %><span class="c-scanner__evidence">Matched by its name</span><% end %>
  <%= render "scanners/add_buttons", printing: entry, key:, finish_hint: reading.finish_hint, rank: %>
  <%= link_to "Other printings", scanner_printings_path(card: entry.identity.external_key, key:, set: reading.collector_line.set_code,
        number: reading.collector_line.number, finish_hint: reading.finish_hint, artwork: candidate.artwork_id),
        class: "c-btn c-btn--ghost c-btn--sm", data: { turbo_frame: "scanner_printings" } %>
```

- [ ] Change `Scanner::OtherPrintings` (`app/models/scanner/other_printings.rb`):

```ruby
# A card's English printings for "Other printings" on the scanner (spec 009 Story 2), retired ones left out. With a
# confident artwork (spec 011 AC-7.5), the printings sharing it come first; then those matching what was read (set and
# number, then set, then number); each group in the catalog's newest-first order.
class Scanner::OtherPrintings
  SHOWN = 20

  def self.plain_number(number) = number.to_s.sub(/\A0+(?=\d)/, "").downcase.presence

  def initialize(identity:, set_code: nil, number: nil, artwork: nil)
    @identity = identity
    @set_code = set_code.to_s.downcase.presence
    @number = self.class.plain_number(number)
    @artwork = artwork
  end
```

  and its `group`:

```ruby
    def group(entry)
      return 0 if @artwork && entry.extension&.illustration_id == @artwork

      set = @set_code && entry.set.code.casecmp?(@set_code)
      number = @number && self.class.plain_number(entry.number) == @number
      if set && number then 1
      elsif set then 2
      elsif number then 3
      else 4
      end
    end
```

- [ ] Change `Scanner::PrintingsController#index`'s `@printings` line:

```ruby
    @printings = Scanner::OtherPrintings.new(identity: @identity, set_code: params[:set], number: params[:number],
      artwork: params[:artwork].to_s[MTG::Art::Sent::ID]) # an invalid or unknown id is ignored (spec 011 AC-7.5)
```

- [ ] Run: `bin/rspec spec/helpers spec/requests/scanner spec/models/scanner spec/system/scanner_adding_spec.rb` — expect: PASS.
- [ ] Add to `docs/design-system/components/Scanner.md`, after the "Candidates are `ItemTile`s" bullet:

```markdown
- With art matching on (spec 011), a candidate the artwork decided carries a `c-badge--success` with a check, "Matched by its artwork", when the artwork belongs to that printing alone; when several printings share it, "Matched by its artwork" is a muted evidence line beside "Printing not confirmed". A weak art match adds the muted line "Artwork looks similar" and no badge. "What the scanner read" gains an Artwork row ("Matched", "Looks similar" or "No match") when the capture sent artworks. When the artwork overruled the name or the collector line, one `c-status__message` sentence above the candidates says so ("The artwork matches a different card from the one the name suggests. The artwork's match is first.").
- With art matching on and an index built, `.c-scanner__art` under the controls is a polite status line in muted text: "Loading artwork matching…", then "Artwork matching is on" or "Artwork matching isn't available. The scanner is reading text only."
```

- [ ] Check the page by eye per the design-system skill: start `bin/dev` with `COLLECTOR_MTG_ART_MATCHING=true` once an index exists (or render the request spec's HTML), and compare a result with the art badge and the note at 390 px and 1280 px, light and dark. Expect no sideways scroll at 360 px and the shutter still in the bottom third (NFR Accessibility). Note the outcome in the commit body.
- [ ] Commit: `feat(scanner): show art evidence and the overrule note in the confirm step (011)`

---

## Phase 14: Measurement records and findings tooling

**Implements:** FR-5 (measurement stays development-only) | **Satisfies:** AC-9.3, AC-9.5 (timings recorded), AC-8.2 (tool), AC-9.2 and AC-9.4 (report tool), NFR Performance (server-time script)
**Files:** `app/models/scanner/measurement_run.rb`, `app/controllers/scanner/readings_controller.rb`, `app/controllers/scanner/measurements/captures_controller.rb`, `app/javascript/controllers/measurement_controller.js`, `lib/collector/scanner_findings/art_sitting_report.rb`, `lib/tasks/scanner.rake`, `script/scanner/art_reading_time.rb`, `spec/system/art_agreement_spec.rb`, `spec/models/scanner/measurement_run_spec.rb`, `spec/requests/scanner/readings_spec.rb`, `spec/lib/collector/scanner_findings/art_sitting_report_spec.rb`
**Interfaces:** Consumes: `MTG::Reading#ranking` fields, `MTG::Art::Sent::Artwork`, `Collector::ScannerFindings::SittingReport#outcomes` (spec 009). Produces: `Scanner::MeasurementRun#record_reading!(key, reading)`, `#readings → [Hash]`; capture extras `art_ms`, `art_download_ms`, `art_ready_ms`, `ready_ms`; `Collector::ScannerFindings::ArtSittingReport.new(run:, account:, ground_truth:)` with `#rows`, `#to_markdown`, `#fixture`; the rake task `scanner:art_sitting_findings`; `script/scanner/art_reading_time.rb`; the opt-in agreement spec (`COLLECTOR_ART_AGREEMENT=<spike art-cache dir>`).

- [ ] Write the failing examples in `spec/models/scanner/measurement_run_spec.rb` (inside the top-level describe; it already builds a run in a temporary directory — use its `run` helper or `let`):

```ruby
  describe "#record_reading! (spec 011 AC-9.3)" do
    it "appends what the ranking decided to a file for the whole run, keyed by the reading key", :aggregate_failures do
      reading = instance_double(MTG::Reading, artworks: [ MTG::Art::Sent::Artwork.new(id: "a" * 8 + "-0000-4000-8000-000000000001", distance: 189) ],
        tier: :art, overruled: :name, overruled_scope: :printing, art_status: :matched,
        candidates: [ MTG::Reading::Candidate.new(entry: build_stubbed(:catalog_entry, external_key: "p1"), evidence: %i[art], name_rank: nil, strong_name: false) ],
        art_usable: [ MTG::Art::Evidence::Usable.new(id: "x", distance: 189, identity_id: 1, printings: []),
                      MTG::Art::Evidence::Usable.new(id: "y", distance: 341, identity_id: 2, printings: []) ])

      run.record_reading!("f" * 32, reading)

      expect(run.readings).to eq([ hash_including("reading_key" => "f" * 32, "tier" => "art", "overruled" => "name",
        "overruled_scope" => "printing", "art_status" => "matched", "candidates" => [ "p1" ], "nearest" => 189, "second" => 341,
        "second_other_card" => true, "artworks" => [ { "id" => "a" * 8 + "-0000-4000-8000-000000000001", "distance" => 189 } ]) ])
      expect(run.dir.join("readings.jsonl")).to exist
    end
  end
```

  The spec file's `let(:run)` builds the run on a temporary directory (`dir.join("runs/live")`).

- [ ] Add the failing request example to `spec/requests/scanner/readings_spec.rb` (top level of the describe):

```ruby
  it "records each reading's art outcome in measurement mode only (spec 011 AC-9.3, FR-5)", :aggregate_failures do
    Catalog::NameIndex.new("mtg").rebuild
    Dir.mktmpdir do |dir|
      manifest = Pathname(dir).join("manifest.csv")
      manifest.write("file,set,number\nIMG_1.jpeg,mom,123\n")
      Rails.configuration.x.scanner_measurement = { manifest: manifest.to_s, dir: Pathname(dir).join("run").to_s }
      read("Lightning Bolt", "")
      expect(Scanner::MeasurementRun.current.readings.sole).to include("reading_key" => key, "tier" => "strong_name", "art_status" => nil)
    ensure
      Rails.configuration.x.scanner_measurement = nil
    end
    read("Lightning Bolt", "")
    expect(response).to have_http_status(:ok)
  end
```

- [ ] Run: `bin/rspec spec/models/scanner/measurement_run_spec.rb spec/requests/scanner/readings_spec.rb` — expect: FAIL (`record_reading!` and `readings` are undefined).
- [ ] Add to `Scanner::MeasurementRun` (after `events`), and extend `EXTRA_FIELDS`:

```ruby
  # Spec 009 adds the reading key, the outline and the detector's timings (AC-9.2, AC-9.3); spec 011 the art search's time,
  # the index's download and parse times, and when the scanner was ready, in ms since the page loaded (AC-9.5).
  EXTRA_FIELDS = %w[reading_key outline detect_ms warp_ms art_ms art_download_ms art_ready_ms ready_ms].freeze
```

```ruby
  # Spec 011 AC-9.3: what the ranking decided for each reading, one line per reading for the whole run (the capture's row
  # may not exist yet: the page sends the capture and the reading at the same time). Joined to captures by reading key.
  def record_reading!(key, reading)
    first, second = reading.art_usable.first(2)
    line = { "reading_key" => key, "at" => Time.current.utc.iso8601(3), "artworks" => reading.artworks&.map { it.to_h.stringify_keys },
             "tier" => reading.tier, "overruled" => reading.overruled, "overruled_scope" => reading.overruled_scope,
             "art_status" => reading.art_status, "candidates" => reading.candidates.map { it.entry.external_key },
             "nearest" => first&.distance, "second" => second&.distance,
             "second_other_card" => second && second.identity_id != first.identity_id }
    @dir.mkpath
    @dir.join("readings.jsonl").open("a") { |file| file.puts(JSON.generate(line)) }
  end

  def readings
    path = @dir.join("readings.jsonl")
    path.file? ? path.readlines.map { JSON.parse(it) } : []
  end
```

- [ ] In `Scanner::ReadingsController#create`, after the `render` in the `elsif reading.valid?` branch, record in measurement mode. Replace that branch with:

```ruby
    elsif reading.valid?
      render turbo_stream: turbo_stream.update("scanner_result", partial: "scanners/result", locals: { reading: reading.resolve, key: })
      record_measurement(key, reading)
```

  and add the private method:

```ruby
    # Development measurement mode only (spec 011 AC-9.3): never fails or changes the answer.
    def record_measurement(key, reading)
      Scanner::MeasurementRun.current&.record_reading!(key, reading)
    rescue StandardError => error
      Rails.logger.warn("scanner.measurement reading not recorded: #{error.class}: #{error.message}")
    end
```

- [ ] In `Scanner::Measurements::CapturesController#create`, permit and keep the new timings:

```ruby
    capture = params.expect(capture: %i[file name_text collector_text ms user_agent name_strip collector_strip reading_key outline detect_ms warp_ms
      art_ms art_download_ms art_ready_ms ready_ms frame guide])
```

```ruby
    extra = { "reading_key" => capture[:reading_key].to_s[Scanner::Sitting::KEY_FORMAT], "outline" => capture[:outline].to_s[/\A(live|found|not_found)\z/],
              **%i[detect_ms warp_ms art_ms art_download_ms art_ready_ms ready_ms].to_h { [ it.to_s, capture[it].presence&.to_i ] } }
```

- [ ] In `app/javascript/controllers/measurement_controller.js`'s `store`, take the new detail fields and send them after `capture[warp_ms]`:

```js
  async store({ detail: { nameText, collectorText, ms, key, outline, detectMs, warpMs, artMs, art, readyMs, strips, frame } }) {
```

```js
    body.append("capture[art_ms]", artMs ?? "")
    body.append("capture[art_download_ms]", art?.downloadMs ?? "")
    body.append("capture[art_ready_ms]", art?.readyMs ?? "")
    body.append("capture[ready_ms]", readyMs ?? "")
```

- [ ] Run: `bin/rspec spec/models/scanner spec/requests/scanner spec/system/scanner_measurement_spec.rb` — expect: PASS.
- [ ] Commit: `feat(scanner): record art outcomes and timings in measurement mode (011)`
- [ ] Write the failing `spec/lib/collector/scanner_findings/art_sitting_report_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::ScannerFindings::ArtSittingReport, type: :model do
  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:entry) { create(:mtg_printing, entry: create(:catalog_entry, external_key: "right")).entry }

  after { FileUtils.rm_rf(dir) }

  def write_run(tier:, first:, ms: 30)
    dir.join("manifest.csv").write("file,set,number\nIMG_1.jpeg,#{entry.set.code},#{entry.number}\n")
    dir.join("truth.json").write(JSON.generate("photos" => [ { "file" => "IMG_1.jpeg", "external_key" => "right", "finish" => "nonfoil", "foil" => false,
      "name" => entry.name, "set_code" => entry.set.code, "collector_number" => entry.number } ]))
    run = Scanner::MeasurementRun.new(manifest: dir.join("manifest.csv"), dir: dir.join("run"))
    dir.join("run/IMG_1.jpeg").mkpath
    dir.join("run/IMG_1.jpeg/capture-001.json").write(JSON.generate("file" => "IMG_1.jpeg", "reading_key" => "k" * 32, "name_text" => entry.name,
      "collector_text" => "", "art_ms" => ms, "art_download_ms" => 244, "art_ready_ms" => 79, "ready_ms" => 900))
    dir.join("run/readings.jsonl").write(JSON.generate("reading_key" => "k" * 32, "tier" => tier, "candidates" => [ first ], "nearest" => 189,
      "second" => 341, "second_other_card" => true, "overruled" => nil, "overruled_scope" => nil, "art_status" => "matched") + "\n")
    described_class.new(run:, account: create(:account), ground_truth: dir.join("truth.json"))
  end

  it "joins each card's reading to its capture and says whether the right card came first (AC-9.2, AC-9.3)", :aggregate_failures do
    report = write_run(tier: "art", first: "right")

    expect(report.rows.sole).to have_attributes(file: "IMG_1.jpeg", tier: "art", right_card_first: true, confident_wrong: false, nearest: 189)
    expect(report.to_markdown).to include("| IMG_1.jpeg |", "189", "341", "Art search per capture")
    expect(report.fixture).to include("format_version" => 1, "spec" => "011", "rows" => [ hash_including("file" => "IMG_1.jpeg", "tier" => "art") ])
  end

  it "names a confident art match on the wrong card (AC-9.4)" do
    other = create(:catalog_entry, external_key: "wrong")

    expect(write_run(tier: "art", first: other.external_key).rows.sole.confident_wrong).to be(true)
  end
end
```

- [ ] Run: `bin/rspec spec/lib/collector/scanner_findings/art_sitting_report_spec.rb` — expect: FAIL (uninitialized constant).
- [ ] Implement `lib/collector/scanner_findings/art_sitting_report.rb`:

```ruby
# Spec 011 Story 9: the art sitting on spec 009's 35 cards, scored. Spec 009's SittingReport gives each card's outcome (the
# printing and finish it ended as, and its corrections); the readings measurement mode recorded (AC-9.3) give the art
# side, joined by the first capture's reading key: the tier that put the first candidate there, the nearest and second-
# nearest distances, the overrule note, and whether the right card was first. Run it before "Done". Medians are
# conventional (the mean of the middle two for an even count).
class Collector::ScannerFindings::ArtSittingReport
  Row = Data.define(:file, :outcome, :tier, :right_card_first, :confident_wrong, :nearest, :second, :second_other_card,
    :overruled, :overruled_scope, :art_ms) do
    def to_h = super.merge(outcome: outcome.kind).transform_keys(&:to_s)
  end

  def initialize(run:, account:, ground_truth:)
    @run = run
    @sitting = Collector::ScannerFindings::SittingReport.new(run:, account:, ground_truth:)
    @readings = run.readings.index_by { it["reading_key"] }
  end

  def rows
    @rows ||= @sitting.outcomes.map do |outcome|
      capture = @run.captures(@run.row(outcome.file)).first || {}
      reading = @readings.fetch(capture["reading_key"], {})
      right = right_card_first?(reading, outcome.truth)
      Row.new(file: outcome.file, outcome:, tier: reading["tier"], right_card_first: right,
        confident_wrong: reading["tier"] == "art" && !right, nearest: reading["nearest"], second: reading["second"],
        second_other_card: reading["second_other_card"], overruled: reading["overruled"], overruled_scope: reading["overruled_scope"],
        art_ms: capture["art_ms"])
    end
  end

  def to_markdown
    first = rows.count(&:right_card_first)
    art_ms = rows.filter_map(&:art_ms)
    [ @sitting.to_markdown, "",
      "Right card first: #{first}/#{rows.size}. Confident art on the wrong card: #{rows.count(&:confident_wrong)}/#{rows.size}" \
        "#{" (#{rows.select(&:confident_wrong).map(&:file).join(", ")})" if rows.any?(&:confident_wrong)}.",
      "Overrule note shown: #{rows.count(&:overruled)}/#{rows.size}; art overruled a collector-line printing of the same card: " \
        "#{rows.count { it.overruled == "collector_line" && it.overruled_scope == "printing" }}/#{rows.size}.",
      "Art search per capture (phone): median #{median(art_ms) || "n/a"} ms, slowest #{art_ms.max || "n/a"} ms (n=#{art_ms.size}).",
      "Compared with spec 009's text-only sitting on these cards (30/35 right first time, 32/35 in the end) and spec 010's " \
        "guide path (33/35 right artwork first). The 300-bit margin was derived from these same cards, so these rates are biased upwards.",
      "", "| File | Outcome | Tier | Right card first | Nearest | Second | Second another card | Overruled | Art ms |",
      "|---|---|---|---|---|---|---|---|---|",
      *rows.map do |row|
        "| #{row.file} | #{row.outcome.kind} | #{row.tier || "—"} | #{row.right_card_first ? "yes" : "no"} | #{row.nearest || "—"} | " \
          "#{row.second || "—"} | #{row.second_other_card.nil? ? "—" : (row.second_other_card ? "yes" : "no")} | " \
          "#{[ row.overruled, row.overruled_scope ].compact.join(" / ").presence || "—"} | #{row.art_ms || "—"} |"
      end ].join("\n")
  end

  # The text-only fixture (AC-9.6), keyed by manifest file.
  def fixture = { "format_version" => 1, "spec" => "011", "rows" => rows.map(&:to_h) }

  private
    def right_card_first?(reading, truth)
      first = Catalog::Entry.find_by(collectible_type: "mtg", external_key: reading.dig("candidates", 0))
      right = Catalog::Entry.find_by(collectible_type: "mtg", external_key: truth["external_key"])
      first.present? && right.present? && first.catalog_identity_id == right.catalog_identity_id
    end

    def median(values)
      return nil if values.empty?

      sorted = values.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : ((sorted[middle - 1] + sorted[middle]) / 2.0).round(1)
    end
end
```

  `Row#to_h` replaces the outcome object with its kind; `Data#to_h` returns symbol keys, turned into strings for JSON.
- [ ] Add the rake task to `lib/tasks/scanner.rake`, after `sitting_findings`:

```ruby
  desc "Spec 011 AC-9.2–AC-9.6: score the art sitting (before Done), write its fixture: SCANNER_EMAIL=… GROUND_TRUTH=… bin/rails scanner:art_sitting_findings"
  task art_sitting_findings: :environment do
    run = Scanner::MeasurementRun.current
    abort "Measurement mode is off; run this in development." unless run
    account = User.find_by!(email_address: ENV.fetch("SCANNER_EMAIL")).account
    report = Collector::ScannerFindings::ArtSittingReport.new(run:, account:, ground_truth: ENV.fetch("GROUND_TRUTH"))
    Rails.root.join("spec/fixtures/card_scanner/phase3_shipped_sitting.json").write(JSON.pretty_generate(report.fixture) + "\n")
    puts report.to_markdown
  end
```

- [ ] Write `script/scanner/art_reading_time.rb` (NFR Performance, non-gating):

```ruby
# Spec 011 NFR Performance: the reading request's ranking time on the server with and without the art evidence, over the
# measured sitting's readings (development measurement mode). bin/rails runner script/scanner/art_reading_time.rb
require "benchmark"

run = Scanner::MeasurementRun.current or abort("Measurement mode is off; run this in development.")
readings = run.readings.index_by { it["reading_key"] }
pairs = run.measured_captures.filter_map do |capture|
  sent = readings.dig(capture["reading_key"], "artworks") or next
  artworks = sent.map { MTG::Art::Sent::Artwork.new(id: it["id"], distance: it["distance"]) }
  text = { name_text: capture["name_text"].to_s, collector_text: capture["collector_text"].to_s }
  [ Benchmark.realtime { MTG::Reading.new(**text).resolve.candidates.to_a }, Benchmark.realtime { MTG::Reading.new(**text, artworks:).resolve.candidates.to_a } ]
end
abort "No measured readings with artworks." if pairs.empty?
median = ->(values) { sorted = values.sort; middle = sorted.size / 2; sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0 }
without, with = pairs.transpose.map { |times| (median.(times) * 1000).round(1) }
puts "Ranking, median over #{pairs.size} readings: #{without} ms text only, #{with} ms with art (+#{(with - without).round(1)} ms; target ≤ 50 ms)."
```

- [ ] Write the opt-in agreement spec `spec/system/art_agreement_spec.rb` (AC-8.2; skipped unless pointed at the spike's cache, so the gating suite never needs Scryfall images):

```ruby
require "rails_helper"

# Spec 011 AC-8.2: the shipped build and the shipped page fingerprint the same Scryfall small images to 0 bits, on the 134
# artworks spec 010 checked. Run on the desktop before the sitting:
#   COLLECTOR_ART_AGREEMENT=~/card-scanner-corpus/art-cache bin/rspec spec/system/art_agreement_spec.rb
RSpec.describe "Art fingerprint agreement on Scryfall images", type: :system do
  let(:cache) { Pathname(File.expand_path(ENV.fetch("COLLECTOR_ART_AGREEMENT", ""))) }

  before do
    skip "Set COLLECTOR_ART_AGREEMENT to the spike's art-cache directory" if ENV["COLLECTOR_ART_AGREEMENT"].blank?
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  it "agrees to 0 bits on every image and records the result (AC-8.2)", :aggregate_failures do
    ids = JSON.parse(cache.join("agreement_small.json").read).fetch("results").map { it.fetch("id") }
    distances = ids.map do |id|
      path = cache.join("artwork/small/#{id}.jpg")
      server = MTG::Art::Fingerprint.of(MTG::Art::Decoder.decode(path))
      page_hex = browser_fingerprints_of_jpeg(path.binread).first
      MTG::Art::Fingerprint.hamming(server, [ page_hex ].pack("H*"))
    end
    result = { "format_version" => 1, "spec" => "011", "n" => ids.size, "median" => distances.sort[ids.size / 2], "max" => distances.max,
               "decoder" => MTG::Art::Decoder.command, "settings_digest" => MTG::Art::Settings.digest }
    Rails.root.join("spec/fixtures/card_scanner/phase3_shipped_agreement.json").write(JSON.pretty_generate(result) + "\n")
    expect(ids.size).to eq(134)
    expect(distances.max).to eq(0)
  end

  def browser_fingerprints_of_jpeg(jpeg)
    run_art_js(<<~JS, Base64.strict_encode64(jpeg), MTG::Art::Settings.fingerprint)
      const [ data, settings ] = args
      const image = new Image()
      image.onload = () => {
        const canvas = Object.assign(document.createElement("canvas"), { width: image.naturalWidth, height: image.naturalHeight })
        canvas.getContext("2d").drawImage(image, 0, 0)
        done([ art.hex(art.fingerprint(canvas, settings, { dx: 0, dy: 0 })) ])
      }
      image.src = `data:image/jpeg;base64,${data}`
    JS
  end
end
```

  This needs `MTG::Art::Fingerprint.hamming`. Add it to `app/models/mtg/art/fingerprint.rb` (inside the module, after `dhash`):

```ruby
  POPCOUNT = Array.new(65_536) { it.to_s(2).count("1") }.freeze

  # Bits that differ between two fingerprints (agreement checks; the search itself runs on the page).
  def hamming(a, b)
    words_a, words_b = a.unpack("n*"), b.unpack("n*")
    words_a.each_index.sum { POPCOUNT[words_a[it] ^ words_b[it]] }
  end
```

  Place `POPCOUNT` above `module_function` so it stays a constant. And add a unit example to `spec/models/mtg/art/fingerprint_spec.rb`:

```ruby
  it "counts the bits two fingerprints differ by" do
    expect(described_class.hamming("\xFF".b * 128, "\x0F".b + "\xFF".b * 127)).to eq(4)
  end
```

- [ ] Run: `bin/rspec spec/lib/collector/scanner_findings spec/models/mtg/art spec/system/art_agreement_spec.rb` — expect: PASS, with the agreement spec pending ("Set COLLECTOR_ART_AGREEMENT…").
- [ ] Run: `bin/rubocop lib script/scanner/art_reading_time.rb spec/lib spec/system/art_agreement_spec.rb` — expect: no offenses.
- [ ] Commit: `feat(findings): add the art sitting report, agreement check and reading-time script (011)`

---

## Phase 15: Documentation and integration verification

**Implements:** FR-2 (CLAUDE.md), FR-5 (spec 007 update), all FRs (verification) | **Satisfies:** AC-9.7 (ADR 0006's representative rule now; figures in Phase 16), all suite-gated ACs
**Files:** `CLAUDE.md`, `docs/specs/007-card-scanner-live-capture/spec.md`, `docs/adr/0006-art-fingerprint-and-index.md`, `script/scanner/art_decoder_fingerprints.rb`
**Interfaces:** Consumes: everything above. Produces: `script/scanner/art_decoder_fingerprints.rb <art-cache dir>` (one `<id> <hex>` line per agreement artwork).

- [ ] In `CLAUDE.md`'s "Non-obvious Facts", change the catalog bullet's first sentence to:

```markdown
- **Catalog data is global** (no `account_id`) and changes only through `Catalog::Refresh` (weekly `config/recurring.yml` schedule + the manual rake task, via `Catalog::RefreshJob`) and, for the MTG art index (spec 011, opt-in `COLLECTOR_MTG_ART_MATCHING`), `MTG::Art::BuildJob`, which the refresh queues and which writes `mtg_artworks`, `mtg_art_builds`, the image cache and the index under `storage/catalog/mtg/art/`.
```

  and add one sentence to the card-scanner bullet, after "…scanner specs fail until it's installed.":

```markdown
Art matching (spec 011, ADRs 0006, 0007 and 0011) needs ImageMagick (`magick` or `convert`) for the build and its specs; the page searches `/scanner/art/<index>` on the device.
```

- [ ] Add a changelog row and an FR-3 note to `docs/specs/007-card-scanner-live-capture/spec.md` (keep its text as history). Change `**Version:** 2.1.1` to `**Version:** 2.2.0` and `**Last Updated:** 2026-10-02` to `**Last Updated:** 2026-10-07`, and add the row at the end of its changelog table:

```markdown
| 2.2.0 | 2026-10-07 | FR-3 amended by spec 011 (art matching): in normal use the page also sends match results (artwork ids and their distances); never a frame, strip, photo or fingerprint |
```

  and directly under FR-3's **Must not** list (after "- Load the engine on any page except the scanner."):

```markdown
> **Amended by [spec 011](../011-card-scanner-art-matching/spec.md) FR-5 (2026-10-07):** "Send only recognised text and match results (artwork ids and their distances) to the app in normal use." Must not send any frame, strip, photo or fingerprint outside development measurement mode.
```

- [ ] Amend ADR 0006's Decision **Index** bullet to the shipped rule (AC-9.7, 1.1.0 ruling):

```markdown
- **Index:** one record per artwork, a 16-byte artwork id and the 128-byte fingerprint (144 bytes), after a 28-byte header (`CART`, format version, the settings digest, the record count), compressed, and named by catalog version, settings digest and record count. The image for each artwork is the front face's `small` image of its oldest English card printing that has one (release date, then set code, then number; maintainer ruling 2026-10-07, replacing "first printing in the bulk file's order", which the app doesn't keep after a refresh). Artworks with no image on any printing are left out.
```

- [ ] Run the whole gate: `bin/rails zeitwerk:check && bin/ci` — expect: "All is good!" and every CI step passing (RuboCop, Brakeman, bundler-audit, importmap audit, RSpec). Read the RSpec summary: 0 failures; the only pending example is the opt-in agreement spec.
- [ ] Run the camera page specs 10 times in a row with art on and off (NFR Reliability): `for i in $(seq 10); do bin/rspec spec/system/scanner_art_spec.rb spec/system/scanner_spec.rb spec/system/scanner_adding_spec.rb || break; done` — expect: 10 passing runs.
- [ ] Commit: `docs(011): record art matching in CLAUDE.md, spec 007 and ADR 0006`
- [ ] Write `script/scanner/art_decoder_fingerprints.rb` (AC-3.10 for the shipped image: the agreement figures were measured with the desktop's ImageMagick 7, and the image may install version 6):

```ruby
# Spec 011 AC-3.10, ADR 0011: the build's zero-offset fingerprints of spec 010's 134 agreement images, one "<id> <hex>"
# line each, so the production image's ImageMagick can be compared with the desktop's.
#   bin/rails runner script/scanner/art_decoder_fingerprints.rb ~/card-scanner-corpus/art-cache
dir = Pathname(File.expand_path(ARGV.fetch(0)))
warn "decoder: #{MTG::Art::Decoder.command}"
JSON.parse(dir.join("agreement_small.json").read).fetch("results").each do |result|
  path = dir.join("artwork/small/#{result.fetch("id")}.jpg")
  puts "#{result["id"]} #{MTG::Art::Fingerprint.of(MTG::Art::Decoder.decode(path)).unpack1("H*")}"
end
```

- [ ] **The image's decoder agrees with the desktop's (AC-3.10):**
  `podman build -t collector:art-check . && bin/rails runner script/scanner/art_decoder_fingerprints.rb ~/card-scanner-corpus/art-cache > tmp/art-fp-desktop.txt && podman run --rm --security-opt label=disable -e SECRET_KEY_BASE_DUMMY=1 -v ~/card-scanner-corpus/art-cache:/art:ro -v "$PWD/script/scanner:/rails/script/scanner:ro" --entrypoint ./bin/rails collector:art-check runner script/scanner/art_decoder_fingerprints.rb /art > tmp/art-fp-image.txt && diff tmp/art-fp-desktop.txt tmp/art-fp-image.txt && wc -l tmp/art-fp-image.txt`
  — expect: no diff output and `134`. The script is mounted because `.dockerignore` keeps `/script` out of the image (spec 012). The stderr lines name each decoder (`magick` or `convert`). If any line differs, stop: the image's decoder doesn't agree, an index built in the image can't be used, and the maintainer rules (ADR 0011 is revisited). Record the decoder and the result in the commit body.
- [ ] **The index passes through Thruster pre-compressed, once (AC-4.1):** write a one-record index in the test directory, serve it from the image, and read the headers:
  1. `RAILS_ENV=test bin/rails runner 'puts MTG::Art::Index.write!("check", [ [ "aaaaaaaa-0000-4000-8000-000000000001", "\x00".b * 128 ] ]).basename'` — note the printed name.
  2. Start the container as a background task: `podman run --rm --name art-check -p 3999:8080 -e HTTP_PORT=8080 -e SECRET_KEY_BASE=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(64)') -e COLLECTOR_MTG_ART_MATCHING=true --security-opt label=disable -v "$PWD/tmp/catalog:/rails/storage/catalog:ro" collector:art-check`, and wait until `curl -fsS http://localhost:3999/up` answers.
  3. `curl -s -D tmp/art-check.headers -o tmp/art-check.bin -H "Accept-Encoding: gzip" http://localhost:3999/scanner/art/<name> && grep -ic '^content-encoding: gzip' tmp/art-check.headers && gunzip -c tmp/art-check.bin | wc -c` — expect: `1` (exactly one gzip encoding) and `172` (the 28-byte header and one 144-byte record).
  4. Stop it with `podman stop art-check` (or TaskStop for the background task) and `rm -rf tmp/catalog/mtg/art tmp/art-check.* tmp/art-fp-*.txt`. If the encoding is doubled or missing, stop and record it: Thruster's handling needs a fix before release.
- [ ] Commit: `chore(scanner): add the decoder fingerprint check script (011)`, with both results in the body.

---

## Phase 16: Closing measurement (needs the maintainer)

**Implements:** — | **Satisfies:** AC-8.2, AC-9.1, AC-9.2, AC-9.3, AC-9.4, AC-9.5, AC-9.6, AC-9.7, AC-5.6, NFR Performance
**Files:** `spec/fixtures/card_scanner/phase3_shipped_agreement.json`, `spec/fixtures/card_scanner/phase3_shipped_sitting.json`, `spec/fixtures/card_scanner/phase3_shipped_build.json`, `docs/specs/011-card-scanner-art-matching/research.md`, `docs/adr/0006-art-fingerprint-and-index.md`, `docs/adr/0007-art-search-in-the-browser.md`, `docs/adr/0011-decode-art-images-with-imagemagick.md`
**Interfaces:** Consumes: everything above, the development catalog, `~/card-scanner-corpus/phase2-sitting/` (manifest, `ground_truth.json`), `~/card-scanner-corpus/art-cache/`. Produces: the findings and the fixtures.

Ask the maintainer for their inputs at the start of execution, in one message (see the work-ahead memory): the device sitting time, permission to refresh this worktree's development catalog, the seed copy below, and a fresh account for the sitting.

- [ ] **Agreement, desktop (AC-8.2):** `COLLECTOR_ART_AGREEMENT=~/card-scanner-corpus/art-cache bin/rspec spec/system/art_agreement_spec.rb` — expect: 1 example, 0 failures, `phase3_shipped_agreement.json` with `"n": 134`, `"max": 0`. If any distance is above 0, stop: the index isn't used, and the maintainer rules (the decoder's ADR is open until then).
- [ ] **Catalog and index, development (AC-9.1):**
  1. The maintainer copies the spike's cache into this worktree's art cache (agents can't read or write `storage/`): `mkdir -p storage/catalog/mtg/art/small && cp -n ~/card-scanner-corpus/art-cache/artwork/small/*.jpg storage/catalog/mtg/art/small/`.
  2. Start the server with art on and measurement mode pointed at the sitting: `COLLECTOR_MTG_ART_MATCHING=true COLLECTOR_SCANNER_MANIFEST=~/card-scanner-corpus/phase2-sitting/manifest.csv COLLECTOR_SCANNER_RUN_DIR=~/card-scanner-corpus/runs/spec011/sitting bin/dev -b "ssl://…"` (the bind `bin/dev-certificate` prints), as a background task.
  3. `bin/rails "catalog:refresh[mtg]"`; then follow `bin/rails "catalog:status[mtg]"` until the art line reads "ready" (about 48 minutes of fingerprinting; the job fetches only artworks the seed lacks).
  4. Write the build's figures to `spec/fixtures/card_scanner/phase3_shipped_build.json`: `bin/rails runner 'run = MTG::ArtBuild.latest; path = MTG::Art::Index.current; puts JSON.pretty_generate("format_version" => 1, "spec" => "011", "catalog_version" => run.catalog_version, "index_file" => run.index_file, "counts" => run.counts, "seconds" => (run.finished_at - run.started_at).round(1), "stored_bytes" => Zlib.gunzip(path.binread).bytesize, "gzip_bytes" => path.size, "decoder" => MTG::Art::Decoder.command)' > spec/fixtures/card_scanner/phase3_shipped_build.json`.
- [ ] **Account:** create a fresh account for the sitting, so spec 009's open sitting in `findings@localhost` isn't mixed in: `COLLECTOR_PASSWORD=… bin/rails "collector:user[art011@localhost]"` (the maintainer chooses the password).
- [ ] **The sitting (maintainer, iPhone, AC-9.2):** in Brave on the LAN, sign in as `art011@localhost`, open `/scanner/measurement`, check the status line reads "Artwork matching is on", then scan each of the 35 cards once through the live flow and add it, as in spec 009 AC-9.1 (a retake only when the first capture is unusable). Don't press Done.
- [ ] **Score (AC-9.2–AC-9.4, AC-9.6):** `SCANNER_EMAIL=art011@localhost GROUND_TRUTH=~/card-scanner-corpus/phase2-sitting/ground_truth.json bin/rails scanner:art_sitting_findings` — expect: the markdown report and `phase3_shipped_sitting.json`. Then `bin/rails runner script/scanner/art_reading_time.rb` for the server time (NFR, target ≤ 50 ms more).
- [ ] **Readiness with art off (NFR Performance):** restart the server without `COLLECTOR_MTG_ART_MATCHING`, with `COLLECTOR_SCANNER_RUN_DIR=~/card-scanner-corpus/runs/spec011/art-off`, and have the maintainer load the measurement page three times, capturing the first card each time. Compare the captures' `ready_ms` with the sitting's first three.
- [ ] **Findings:** write `docs/specs/011-card-scanner-art-matching/research.md`: environment; agreement (AC-8.2); the build (AC-9.1); the sitting table and rates against spec 009 and spec 010, foils and non-foils separately (AC-9.2); every card not right first time with its read text, art distances and likely cause, and every confident wrong match (AC-9.4); the phone times cold and warm against spec 010's 244 / 79 / 19 ms and the art time per capture against the 100 ms target (AC-9.5, AC-5.6); readiness with art on and off; the server time; the bias statement; no pass threshold; recommendations, including the margin.
- [ ] **ADRs (AC-9.7):** add the shipped figures (build cost, decoder, phone times) to ADR 0006's and ADR 0007's Consequences; add the agreement result to ADR 0011's Consequences.
- [ ] Commit the fixtures and the findings separately: `test(findings): record the shipped art build, agreement and sitting (011)` and `docs(011): record the art matching findings and update ADRs 0006, 0007 and 0011`.
- [ ] **Stop for the maintainer's ruling on the margin (AC-9.4)** before `sdd-review` and merge. Record it in research.md and project memory.

---

## Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] `bin/rails zeitwerk:check && bin/ci` — expect: every step green, 0 failures, 1 pending (the opt-in agreement spec).
- [ ] The camera page specs pass 10 times in a row (Phase 15).
- [ ] Every AC maps to a passing spec or a findings section (Phase 16); `sdd-review` (Mode B, read-only Fable) checks the coverage matrix.

---

## Quickstart Validation

On the development machine, with ImageMagick installed:

1. `bin/rails "catalog:refresh[mtg]"` with `COLLECTOR_MTG_ART_MATCHING` unset: the refresh applies (or re-applies once for artwork ids), and `bin/rails "catalog:status[mtg]"` ends with "Art matching: off".
2. Restart with `COLLECTOR_MTG_ART_MATCHING=true` and refresh again (on a deployed instance, also check `curl -sI -H "Accept-Encoding: gzip" https://<host>/scanner/art/<index>` shows one `content-encoding: gzip`): the status shows "building", then "ready" with the counts; `ls storage/catalog/mtg/art/index/` (the maintainer's shell) shows one `art-index-…-<count>.bin.gz`.
3. Open `/scanner` on a phone over HTTPS: under Capture, "Loading artwork matching…" turns into "Artwork matching is on".
4. Capture a card whose name the scanner reads but whose printing it can't tell (an old Plains): the first candidate carries "Matched by its artwork", "What the scanner read" shows "Artwork: Matched", and the note says the artwork matched a different printing from the one the name suggests.
5. Unset the variable and restart: the status line is gone and `/scanner/art/<that file>` answers 404.
