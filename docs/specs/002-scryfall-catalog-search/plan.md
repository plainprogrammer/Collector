# Implementation Plan: Scryfall Catalog Ingestion and Card Search

**Spec:** docs/specs/002-scryfall-catalog-search/spec.md (v1.1.0, Approved)
**Decisions:** none (no ADRs; decisions recorded inline, traced to the spec)
**Supporting docs:** [data-model.md](data-model.md), [contracts/api.md](contracts/api.md)
**Created:** 2026-09-29

## Context

Collector has no catalog. Spec 002 builds a collectible-agnostic catalog core (`Catalog::`), an MTG extension (`MTG::`), a Scryfall source adapter (`MTG::Scryfall`) that ingests Scryfall bulk data weekly or on demand, and a public card search (search page, per-card printings page, printing detail page) served only from local data. The design concept (`tmp/docs/catalog-design-concept.md`) is the starting point; project rules override it (e.g. no `lib/` adapters, no `services/`, no new gems, Solid Queue stays in Puma).

**FR-3 spike: done during planning (live calls to Scryfall, 2026-09-29):**
- `GET https://api.scryfall.com/bulk-data` → `data[]` with `type` (`default_cards`, `all_cards`, …), `updated_at`, `jsonl_download_uri` (e.g. `https://data.scryfall.io/all-cards/all-cards-20260929091807.jsonl.gz`) and `compressed_size` (bytes).
- The file is **gzip-compressed JSON Lines** (one card object per line), served as `content-type: application/gzip` with **no** `Content-Encoding`. `content-length` equals `compressed_size`, and `accept-ranges: bytes` is supported. `all_cards` is 393 MB compressed; `default_cards` (English, plus cards printed in only one language) is 79 MB.
- ⇒ Streaming uses stdlib `Zlib::GzipReader#each_line` + `JSON.parse`, so no parser gem is needed. Integrity check = bytes on disk == `compressed_size`. For an English-only configuration we download `default_cards` (5× smaller), otherwise `all_cards`.
- `GET /sets` returns all 1053 sets in one page (`has_more: false`). Fields: `code`, `name`, `released_at` (present on every set today, still treated as optional), `parent_set_code`, `digital`.
- Localized names: single-face cards have top-level `printed_name`. Multi-face cards (e.g. Japanese `transform`) have `printed_name` only on `card_faces[]`, and top-level `image_uris` is absent (the images are per face).

**Plan decisions (not spelled out in the spec):**
- For English-only installs the adapter downloads `default_cards` rather than `all_cards`. It holds every English printing, so FR-3's "bulk file of all printings" is met for the configured languages, at a fifth of the download size.
- Search queries are stripped and truncated to 100 characters (`Catalog::Search::MAX_QUERY_LENGTH`), which bounds the LIKE pattern. No card name comes close.
- A run whose source yields zero valid records fails without retiring anything. This implements the spec's "cannot be decoded or parsed → failed; no retirements".
- An entry whose record is malformed in a run counts as seen, so it is not retired (the spec's "skipped and logged … run continues").
- Spec harness (from the plan review): `RSpec/ExampleLength` max 15, random spec order, and `ActiveSupport::Testing::TimeHelpers` in specs.

## Global Constraints

- Ruby 4.0.7, Rails 8.1.4, SQLite. Catalog tables go in the **primary** database. No new gems (stdlib `net/http`, `zlib`, `json`, `digest`; Solid Queue's `fugit` is already a dependency).
- MTG extension namespace is `MTG` (inflector acronym). The Scryfall adapter is `MTG::Scryfall`, implementing the core `Catalog::Sources` contract. Core `Catalog::` code never names Scryfall or MTG.
- Catalog data is global: no `account_id`. Search is public.
- The server makes no outbound HTTP during a web request. Views render only `https` URLs on `scryfall.com`, `cards.scryfall.io`, `svgs.scryfall.io`.
- Specs make no real HTTP calls (WebMock stubs; the fixture bulk files are built in specs). Tag spec types explicitly; multi-expectation examples use `:aggregate_failures`.
- Migrations are reversible and never edited after release. Do not reference app models in migrations.
- Weekly schedule; 12 cards per search page; 10 printings per result group; 12 printings per printings page; `STALE_AFTER` = 6 hours.
- One Conventional Commit per step (`docs/git-convention.md`), and RSpec green at every commit. Branch: `feat/002-scryfall-catalog-search`.

---

## Goal

A catalog core and MTG extension populated from Scryfall by a scheduled/manual, idempotent, incremental background refresh, with public search, printings, and detail pages served entirely from the local SQLite cache.

**Components (Simplicity Gate: 3):**
1. Catalog core + MTG extension models.
2. Refresh pipeline (the `Catalog::Sources` contract, the `MTG::Scryfall` adapter, `Catalog::Refresh` + job).
3. Search UI.

---

## Phase 0: Branch and doc-first commit

**Implements:** — | **Satisfies:** — (enables all)
**Files:** `docs/specs/002-scryfall-catalog-search/{spec.md,plan.md,data-model.md,contracts/api.md}`
**Interfaces:** Consumes: nothing. Produces: branch `feat/002-scryfall-catalog-search`.

- [ ] Create the branch `feat/002-scryfall-catalog-search` from `main` (`sdd-superpowers:using-git`).
- [ ] Commit: `docs(specs): add spec, plan, data model and contracts for 002 Scryfall catalog search`

---

## Phase 1: `MTG` namespace and convention docs

**Implements:** FR-2 (namespace), FR-9 | **Satisfies:** AC-9.2 (partial: namespace + zeitwerk), AC-9.4
**Files:** `.rubocop.yml`, `spec/spec_helper.rb`, `config/initializers/inflections.rb`, `app/models/mtg.rb`, `spec/models/mtg_spec.rb`, `CLAUDE.md`, `.claude/rules/conventions.md`, `.claude/rules/external-data-and-portability.md`, `.claude/memory/steering/conventions.md`
**Interfaces:** Consumes: nothing. Produces: `"mtg".camelize == "MTG"`; module `MTG` with `table_name_prefix "mtg_"`.

- [ ] Write the failing spec `spec/models/mtg_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe MTG, type: :model do
    it "is the constant for the mtg namespace" do
      expect("mtg/printing".camelize).to eq("MTG::Printing")
    end

    it "prefixes extension tables with mtg_" do
      expect(described_class.table_name_prefix).to eq("mtg_")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg_spec.rb` → expect FAIL (`uninitialized constant MTG`).
- [ ] Replace the body of `config/initializers/inflections.rb`:
  ```ruby
  # Be sure to restart your server when you modify this file.

  # The Magic: The Gathering extension lives in app/models/mtg/ as MTG::…
  ActiveSupport::Inflector.inflections(:en) do |inflect|
    inflect.acronym "MTG"
  end
  ```
- [ ] Create `app/models/mtg.rb`:
  ```ruby
  # Magic: The Gathering extension of the collectible-agnostic catalog.
  module MTG
    def self.table_name_prefix = "mtg_"
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg_spec.rb` → PASS; `bin/rails zeitwerk:check` → `All is good!`
- [ ] Commit: `feat(mtg): register MTG inflector acronym and namespace`
- [ ] Update the docs (FR-9):
  - `CLAUDE.md` "Architecture Intent": in the collectible-agnostic bullet, change "under an `Mtg::` namespace" to "under the `MTG::` namespace (inflector acronym in `config/initializers/inflections.rb`)". Change the adapters bullet to: "Sources such as Scryfall implement the `Catalog::Sources` contract and live in their collectible's namespace (`MTG::Scryfall`); they are synced in background jobs (bulk data, cached locally) and never called during page render."
  - `.claude/rules/conventions.md`: `Mtg::` → `MTG::` on lines 5 and 10.
  - `.claude/rules/external-data-and-portability.md` line 3: "(e.g. `MTG::Scryfall::Source` implementing `Catalog::Sources`)".
  - `.claude/memory/steering/conventions.md` line 12: "collectible-specific code in namespaces such as `MTG::` (`app/models/mtg/`). External source adapters implement `Catalog::Sources` and live in their collectible's namespace (`MTG::Scryfall`)."
- [ ] Verify: `grep -rnE 'Mtg::|Catalog::Sources::Scryfall' CLAUDE.md .claude/rules .claude/memory/steering` → no output.
- [ ] Commit: `docs: use MTG namespace and Catalog::Sources adapters in conventions`
- [ ] Spec-harness housekeeping (the plan-review decisions; they keep `bin/ci` green for the specs in later phases):
  - Append to `.rubocop.yml`:
    ```yaml
    # Integration-style examples need setup → act → assert; the default 5 lines is too tight.
    RSpec/ExampleLength:
      Max: 15
    ```
  - In `spec/spec_helper.rb`, move `config.order = :random` and `Kernel.srand config.seed` (with their comments) out of the `=begin`/`=end` block, so specs run in random order as `.claude/rules/testing.md` requires.
- [ ] Run: `bin/rubocop` → no offenses; `bin/rspec` → green, and the output prints `Randomized with seed`.
- [ ] Commit: `test: run specs in random order and allow 15-line examples`

---

## Phase 2: Catalog core and MTG extension schema and models

**Implements:** FR-1, FR-2 (storage) | **Satisfies:** AC-9.1; scope behaviour underpinning AC-1.1–1.3, AC-1.9, AC-1.10, AC-1.13; AC-4.5, AC-4.6, AC-8.3
**Files:** `db/migrate/20260930000001_create_catalog_core.rb`, `db/migrate/20260930000002_create_mtg_extension.rb`, `db/schema.rb`, `app/models/catalog.rb`, `app/models/catalog/{set,identity,entry,refresh_run}.rb`, `app/models/mtg/{printing,card}.rb`, `spec/factories/catalog.rb`, `spec/models/catalog_spec.rb`, `spec/models/catalog/{entry,refresh_run}_spec.rb`
**Interfaces:** Consumes: `MTG` module. Produces:
- `Catalog::Set`, `Catalog::Identity`, `Catalog::Entry`, `Catalog::RefreshRun`, `MTG::Printing`, `MTG::Card` (tables per Appendix A).
- `Catalog::Entry::PRIMARY_KIND = "card"`; scopes `active`, `searchable`, `named_like(query)`, `in_set(code)`, `newest_first`; `#retired?`; `#to_param` → `external_key`; `attr_accessor :extension`.
- `Catalog::Identity#to_param` → `external_key`.
- `Catalog::RefreshRun`: `STALE_AFTER`, `COUNTS`, `.start!(type, trigger:)`, `#finish!(status, message: nil, counts: {})`, `.applied?(type, source_version:, languages:)`, `.last_applied`, scopes `for_type`, `recent`, `#counts`, `#status_line`.
- Factories `:catalog_set`, `:catalog_identity`, `:catalog_entry` (trait `:retired`), `:mtg_printing`, `:catalog_refresh_run`.

### 2a: Schema

- [ ] Write the failing spec `spec/models/catalog_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Catalog, type: :model do
    it "keeps MTG vocabulary out of the core catalog tables" do
      mtg_terms = /mana|colou?r|power|toughness|loyalty|type_line|oracle|rules|legal|face|rarity|finishes|frame|border|security_stamp/
      columns = [ Catalog::Set, Catalog::Identity, Catalog::Entry, Catalog::RefreshRun ].flat_map(&:column_names)

      expect(columns.grep(mtg_terms)).to be_empty
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog_spec.rb` → FAIL (`uninitialized constant Catalog`).
- [ ] Create `db/migrate/20260930000001_create_catalog_core.rb`:
  ```ruby
  class CreateCatalogCore < ActiveRecord::Migration[8.1]
    def change
      create_table :catalog_sets do |t|
        t.string :collectible_type, null: false
        t.string :code, null: false
        t.string :name, null: false
        t.date :released_on
        t.string :parent_code
        t.string :content_digest, null: false
        t.timestamps
        t.index %i[collectible_type code], unique: true
      end

      create_table :catalog_identities do |t|
        t.string :collectible_type, null: false
        t.string :external_key, null: false
        t.string :name, null: false
        t.string :content_digest, null: false
        t.timestamps
        t.index %i[collectible_type external_key], unique: true
        t.index :name
      end

      create_table :catalog_entries do |t|
        t.string :collectible_type, null: false
        t.string :external_key, null: false
        t.references :catalog_set, null: false, foreign_key: true
        t.references :catalog_identity, null: false, foreign_key: true
        t.string :number, null: false
        t.string :language, null: false
        t.string :name, null: false
        t.string :localized_name
        t.string :kind, null: false
        t.date :released_on
        t.string :image_url
        t.string :content_digest, null: false
        t.datetime :retired_at
        t.timestamps
        t.index %i[collectible_type external_key], unique: true
        t.index %i[kind retired_at]
      end

      create_table :catalog_refresh_runs do |t|
        t.string :collectible_type, null: false
        t.string :trigger, null: false
        t.string :status, null: false
        t.string :source_version
        t.string :languages
        t.integer :seen_count, null: false, default: 0
        t.integer :inserted_count, null: false, default: 0
        t.integer :updated_count, null: false, default: 0
        t.integer :retired_count, null: false, default: 0
        t.integer :restored_count, null: false, default: 0
        t.integer :malformed_count, null: false, default: 0
        t.text :message
        t.datetime :started_at, null: false
        t.datetime :finished_at
        t.timestamps
        t.index %i[collectible_type status started_at]
      end
    end
  end
  ```
- [ ] Create `db/migrate/20260930000002_create_mtg_extension.rb`:
  ```ruby
  class CreateMTGExtension < ActiveRecord::Migration[8.1]
    def change
      create_table :mtg_printings do |t|
        t.references :catalog_entry, null: false, foreign_key: true, index: { unique: true }
        t.string :rarity, null: false
        t.json :finishes, null: false, default: []
        t.string :layout, null: false
        t.string :frame
        t.string :border_color
        t.string :security_stamp
        t.json :variant_tags, null: false, default: []
        t.json :legalities, null: false, default: {}
        t.json :external_ids, null: false, default: {}
        t.json :faces, null: false, default: []
        t.string :scryfall_uri, null: false
        t.timestamps
      end

      create_table :mtg_cards do |t|
        t.references :catalog_identity, null: false, foreign_key: true, index: { unique: true }
        t.string :mana_cost
        t.string :type_line
        t.text :oracle_text
        t.json :colors, null: false, default: []
        t.json :color_identity, null: false, default: []
        t.json :keywords, null: false, default: []
        t.timestamps
      end
    end
  end
  ```
- [ ] Create `app/models/catalog.rb` (the registry is filled in during Phase 3):
  ```ruby
  # Collectible-agnostic catalog: what collectibles exist, fed by source
  # adapters registered per collectible type in config/initializers/catalog.rb.
  module Catalog
    def self.table_name_prefix = "catalog_"
  end
  ```
- [ ] Create `app/models/catalog/set.rb`:
  ```ruby
  class Catalog::Set < ApplicationRecord
    has_many :entries, class_name: "Catalog::Entry", foreign_key: :catalog_set_id,
      inverse_of: :set, dependent: :restrict_with_exception

    validates :collectible_type, :code, :name, :content_digest, presence: true
    validates :code, uniqueness: { scope: :collectible_type }
  end
  ```
- [ ] Create `app/models/catalog/identity.rb`:
  ```ruby
  # What several entries have in common: for MTG, one card across all its printings.
  class Catalog::Identity < ApplicationRecord
    has_many :entries, class_name: "Catalog::Entry", foreign_key: :catalog_identity_id,
      inverse_of: :identity, dependent: :restrict_with_exception

    validates :collectible_type, :external_key, :name, :content_digest, presence: true
    validates :external_key, uniqueness: { scope: :collectible_type }

    def to_param = external_key
  end
  ```
- [ ] Create `app/models/catalog/entry.rb`:
  ```ruby
  # One catalogued collectible as the source identifies it: for MTG, a printing.
  class Catalog::Entry < ApplicationRecord
    PRIMARY_KIND = "card"

    belongs_to :set, class_name: "Catalog::Set", foreign_key: :catalog_set_id, inverse_of: :entries
    belongs_to :identity, class_name: "Catalog::Identity", foreign_key: :catalog_identity_id, inverse_of: :entries

    # The collectible-specific record (e.g. MTG::Printing); see .preload_extensions.
    attr_accessor :extension

    validates :collectible_type, :external_key, :number, :language, :name, :kind, :content_digest, presence: true
    validates :external_key, uniqueness: { scope: :collectible_type }

    def retired? = retired_at.present?

    def to_param = external_key
  end
  ```
- [ ] Create `app/models/catalog/refresh_run.rb`:
  ```ruby
  # One attempt to apply a catalog source's data, with its outcome and counts.
  class Catalog::RefreshRun < ApplicationRecord
    STALE_AFTER = 6.hours
    TRIGGERS = %w[scheduled manual].freeze
    COUNTS = %i[seen inserted updated retired restored malformed].freeze

    enum :status, { running: "running", applied: "applied", skipped: "skipped", failed: "failed" }, validate: true

    validates :collectible_type, :started_at, presence: true
    validates :trigger, inclusion: { in: TRIGGERS }

    scope :for_type, ->(collectible_type) { where(collectible_type:) }
    scope :recent, -> { order(started_at: :desc, id: :desc) }
  end
  ```
- [ ] Create `app/models/mtg/printing.rb` and `app/models/mtg/card.rb`:
  ```ruby
  # MTG-specific attributes of a printing (a Catalog::Entry).
  class MTG::Printing < ApplicationRecord
    belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id

    validates :rarity, :layout, :scryfall_uri, presence: true
    validates :catalog_entry_id, uniqueness: true
  end
  ```
  ```ruby
  # MTG gameplay attributes of a card (a Catalog::Identity).
  class MTG::Card < ApplicationRecord
    belongs_to :identity, class_name: "Catalog::Identity", foreign_key: :catalog_identity_id

    validates :catalog_identity_id, uniqueness: true
  end
  ```
- [ ] Run: `bin/rails db:migrate` → creates `db/schema.rb` with 6 tables; `bin/rails db:migrate:redo STEP=2` succeeds (reversible).
- [ ] Run: `bin/rspec spec/models/catalog_spec.rb` → PASS; `bin/rails zeitwerk:check` → `All is good!`
- [ ] Commit: `feat(catalog): add catalog core and MTG extension schema`

### 2b: Entry scopes

- [ ] Create `spec/factories/catalog.rb` (factories are test support, written ahead of the specs that use them):
  ```ruby
  FactoryBot.define do
    factory :catalog_set, class: "Catalog::Set" do
      collectible_type { "mtg" }
      sequence(:code) { |n| "s#{n}" }
      name { "Set #{code.upcase}" }
      released_on { Date.new(2020, 1, 1) }
      content_digest { "digest" }
    end

    factory :catalog_identity, class: "Catalog::Identity" do
      collectible_type { "mtg" }
      sequence(:external_key) { |n| "identity-#{n}" }
      name { "Lightning Bolt" }
      content_digest { "digest" }
    end

    factory :catalog_entry, class: "Catalog::Entry" do
      collectible_type { "mtg" }
      sequence(:external_key) { |n| "entry-#{n}" }
      set factory: :catalog_set
      identity factory: :catalog_identity
      sequence(:number, &:to_s)
      language { "en" }
      name { identity.name }
      kind { "card" }
      released_on { set.released_on }
      content_digest { "digest" }

      trait :retired do
        retired_at { 1.day.ago }
      end
    end

    factory :mtg_printing, class: "MTG::Printing" do
      entry factory: :catalog_entry
      rarity { "common" }
      finishes { %w[foil nonfoil] }
      layout { "normal" }
      faces do
        [ { "name" => entry.name, "mana_cost" => "{R}", "type_line" => "Instant",
            "oracle_text" => "Lightning Bolt deals 3 damage to any target.", "artist" => "Christopher Moeller",
            "image_uris" => {} } ]
      end
      scryfall_uri { "https://scryfall.com/card/#{entry.set.code}/#{entry.number}" }
    end

    factory :catalog_refresh_run, class: "Catalog::RefreshRun" do
      collectible_type { "mtg" }
      trigger { "scheduled" }
      status { "applied" }
      started_at { 1.hour.ago }
      finished_at { 30.minutes.ago }
    end
  end
  ```
- [ ] Write the failing spec `spec/models/catalog/entry_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Catalog::Entry, type: :model do
    describe ".named_like" do
      it "matches part of the name, ignoring ASCII case", :aggregate_failures do
        bolt = create(:catalog_entry, name: "Lightning Bolt")
        create(:catalog_entry, name: "Lightning Helix")

        expect(described_class.named_like("LIGHTNING bo")).to contain_exactly(bolt)
      end

      it "matches the localized name" do
        ja = create(:catalog_entry, name: "Lightning Bolt", localized_name: "稲妻", language: "ja")

        expect(described_class.named_like("稲妻")).to contain_exactly(ja)
      end

      it "treats % and _ literally" do
        create(:catalog_entry, name: "Fires of Yavimaya")

        expect(described_class.named_like("Fire_")).to be_empty
      end
    end

    describe ".searchable" do
      it "excludes retired entries and non-card kinds" do
        card = create(:catalog_entry)
        create(:catalog_entry, :retired)
        create(:catalog_entry, kind: "token")

        expect(described_class.searchable).to contain_exactly(card)
      end
    end

    describe ".in_set" do
      it "restricts to one set code and ignores a blank code", :aggregate_failures do
        a = create(:catalog_entry, set: create(:catalog_set, code: "aaa"))
        b = create(:catalog_entry, set: create(:catalog_set, code: "bbb"))

        expect(described_class.in_set("aaa")).to contain_exactly(a)
        expect(described_class.in_set("")).to contain_exactly(a, b)
      end
    end

    describe ".newest_first" do
      it "orders by release date, then set code, number and language" do
        old = create(:catalog_entry, released_on: Date.new(2001, 1, 1))
        new_b = create(:catalog_entry, released_on: Date.new(2020, 1, 1), set: create(:catalog_set, code: "bbb"))
        new_a = create(:catalog_entry, released_on: Date.new(2020, 1, 1), set: create(:catalog_set, code: "aaa"))

        expect(described_class.newest_first.to_a).to eq([ new_a, new_b, old ])
      end
    end

    it "is addressed by its external key" do
      expect(build(:catalog_entry, external_key: "abc-123").to_param).to eq("abc-123")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/entry_spec.rb` → FAIL (`undefined method 'named_like'`).
- [ ] Replace `app/models/catalog/entry.rb` with:
  ```ruby
  # One catalogued collectible as the source identifies it: for MTG, a printing.
  class Catalog::Entry < ApplicationRecord
    PRIMARY_KIND = "card"

    belongs_to :set, class_name: "Catalog::Set", foreign_key: :catalog_set_id, inverse_of: :entries
    belongs_to :identity, class_name: "Catalog::Identity", foreign_key: :catalog_identity_id, inverse_of: :entries

    # The collectible-specific record (e.g. MTG::Printing); see .preload_extensions.
    attr_accessor :extension

    validates :collectible_type, :external_key, :number, :language, :name, :kind, :content_digest, presence: true
    validates :external_key, uniqueness: { scope: :collectible_type }

    scope :active, -> { where(retired_at: nil) }
    scope :searchable, -> { active.where(kind: PRIMARY_KIND) }
    scope :named_like, ->(query) {
      pattern = "%#{sanitize_sql_like(query)}%"
      where(arel_table[:name].matches(pattern, "\\"))
        .or(where(arel_table[:localized_name].matches(pattern, "\\")))
    }
    scope :in_set, ->(code) { code.present? ? joins(:set).where(catalog_sets: { code: }) : all }
    scope :newest_first, -> {
      joins(:set).order(released_on: :desc).order(Catalog::Set.arel_table[:code].asc).order(number: :asc, language: :asc)
    }

    def retired? = retired_at.present?

    def to_param = external_key
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/entry_spec.rb` → PASS.
- [ ] Commit: `feat(catalog): add entry search scopes`

### 2c: Refresh run bookkeeping

- [ ] Write the failing spec `spec/models/catalog/refresh_run_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Catalog::RefreshRun, type: :model do
    describe ".start!" do
      it "starts a running attempt when nothing is running" do
        expect(described_class.start!("mtg", trigger: "manual")).to be_running
      end

      it "records a skip when a run younger than 6 hours is running", :aggregate_failures do
        create(:catalog_refresh_run, status: "running", started_at: 5.hours.ago, finished_at: nil)
        allow(Rails.logger).to receive(:info)

        run = described_class.start!("mtg", trigger: "manual")

        expect(run).to be_skipped
        expect(run.message).to eq("already running")
        expect(Rails.logger).to have_received(:info).with(a_string_including('"status":"skipped"'))
      end

      it "marks a run running for 6 hours or more as interrupted and proceeds", :aggregate_failures do
        stale = create(:catalog_refresh_run, status: "running", started_at: 7.hours.ago, finished_at: nil)

        run = described_class.start!("mtg", trigger: "scheduled")

        expect(stale.reload).to be_failed
        expect(stale.message).to eq("interrupted")
        expect(run).to be_running
      end

      it "ignores runs of other collectible types" do
        create(:catalog_refresh_run, collectible_type: "other", status: "running", started_at: 1.hour.ago, finished_at: nil)

        expect(described_class.start!("mtg", trigger: "manual")).to be_running
      end
    end

    describe ".applied?" do
      it "matches source version and language set", :aggregate_failures do
        create(:catalog_refresh_run, source_version: "v1", languages: "en")

        expect(described_class.applied?("mtg", source_version: "v1", languages: "en")).to be(true)
        expect(described_class.applied?("mtg", source_version: "v1", languages: "en,ja")).to be(false)
      end
    end

    describe "#finish!" do
      it "stores the outcome and logs one structured entry", :aggregate_failures do
        run = described_class.start!("mtg", trigger: "manual")
        allow(Rails.logger).to receive(:info)

        run.finish!(:applied, counts: { seen: 3, inserted: 2 })

        expect(run.reload).to have_attributes(status: "applied", seen_count: 3, inserted_count: 2)
        expect(run.finished_at).to be_present
        expect(Rails.logger).to have_received(:info)
          .with(a_string_including('"event":"catalog.refresh.finished"', '"status":"applied"', '"inserted":2'))
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/refresh_run_spec.rb` → FAIL (`undefined method 'start!'`).
- [ ] Replace `app/models/catalog/refresh_run.rb` with:
  ```ruby
  # One attempt to apply a catalog source's data, with its outcome and counts.
  class Catalog::RefreshRun < ApplicationRecord
    STALE_AFTER = 6.hours
    TRIGGERS = %w[scheduled manual].freeze
    COUNTS = %i[seen inserted updated retired restored malformed].freeze

    enum :status, { running: "running", applied: "applied", skipped: "skipped", failed: "failed" }, validate: true

    validates :collectible_type, :started_at, presence: true
    validates :trigger, inclusion: { in: TRIGGERS }

    scope :for_type, ->(collectible_type) { where(collectible_type:) }
    scope :recent, -> { order(started_at: :desc, id: :desc) }

    # Records a new attempt. A run left "running" for STALE_AFTER is marked
    # failed ("interrupted"); a younger one makes this attempt a skip.
    def self.start!(collectible_type, trigger:)
      transaction do
        runs = for_type(collectible_type)
        runs.running.where(started_at: ..STALE_AFTER.ago).find_each { |run| run.finish!(:failed, message: "interrupted") }

        already_running = runs.running.exists?
        run = create!(collectible_type:, trigger:, status: :running, started_at: Time.current)
        run.finish!(:skipped, message: "already running") if already_running
        run
      end
    end

    def self.applied?(collectible_type, source_version:, languages:)
      for_type(collectible_type).applied.exists?(source_version:, languages:)
    end

    def self.last_applied = applied.order(finished_at: :desc).first

    def finish!(status, message: nil, counts: {})
      update!(status:, message:, finished_at: Time.current, **counts.transform_keys { |name| :"#{name}_count" })
      Rails.logger.info(ActiveSupport::JSON.encode(event: "catalog.refresh.finished", collectible_type:,
        trigger:, status:, source_version:, languages:, message:, **self.counts))
    end

    def counts = COUNTS.index_with { |name| public_send(:"#{name}_count") }

    def status_line
      [ started_at.utc.iso8601, finished_at&.utc&.iso8601 || "-", status, trigger, source_version || "-",
        counts.map { |name, value| "#{name}=#{value}" }.join(" "), message ].compact.join("  ")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/refresh_run_spec.rb` → PASS.
- [ ] Commit: `feat(catalog): record refresh runs with stale-run and concurrency guards`

---

## Phase 3: Source contract and the `MTG::Scryfall` adapter

**Implements:** FR-3, FR-6 (setting parsing), FR-2 (kind classification, localized names) | **Satisfies:** AC-9.2, AC-9.3; the adapter halves of AC-6.1, AC-6.2, AC-6.4, AC-7.9, AC-7.10, AC-1.3
**Files:** `app/models/catalog.rb` (registry), `config/initializers/catalog.rb`, `config/application.rb`, `config/environments/test.rb`, `app/models/catalog/sources.rb`, `app/models/mtg/scryfall/{client,mapper,source}.rb`, `spec/support/scryfall_helpers.rb`, `spec/fixtures/files/scryfall/azusa_ja_transform.json`, `spec/models/mtg/scryfall/{mapper,client,source}_spec.rb`
**Interfaces:** Consumes: `MTG::Printing`, `MTG::Card`. Produces:
- `Catalog.sources` (Hash type → class name), `Catalog.source_class(type)`, `Catalog.source_for(type)`, `Catalog.allowed_hosts`.
- `Catalog::Sources::{SetRecord,IdentityRecord,EntryRecord,Malformed}` (each record has `#digest`); errors `Catalog::Sources::{Error,TransientError,IntegrityError,ConfigurationError}`.
- Source contract (duck type, documented in `catalog/sources.rb`): `ALLOWED_HOSTS`, `.entry_extension_model`, `.identity_extension_model`, `#languages`, `#current_version(languages:)`, `#download(version, dir:)`, `#each_set`, `#each_entry(path, languages:)`.
- `MTG::Scryfall::Source.new(client:, env:)`, `MTG::Scryfall::Client#get_json(path_or_url)`, `#download(url, to:)`, and `MTG::Scryfall::Mapper.{paper?,set_record,entry_record}`.
- `Rails.configuration.x.catalog_download_dir` (`storage/catalog`; test: `tmp/catalog`).
- Spec helpers `scryfall_card(overrides)`, `scryfall_set(overrides)`, `gzip_jsonl(lines)`, `stub_scryfall(cards:, sets:, type:)`.

### 3a: Contract and registry

- [ ] Create `app/models/catalog/sources.rb`:
  ```ruby
  # The contract between the catalog and an external data source. A source
  # class (e.g. MTG::Scryfall::Source) is registered per collectible type in
  # config/initializers/catalog.rb and provides:
  #
  #   ALLOWED_HOSTS                       hosts whose https URLs views may render
  #   .entry_extension_model              model keyed by catalog_entry_id, or nil
  #   .identity_extension_model           model keyed by catalog_identity_id, or nil
  #   #languages                          sorted language codes to ingest (raises ConfigurationError)
  #   #current_version(languages:)        opaque String naming the current source data
  #   #download(version, dir:)            Pathname of the verified local copy (IntegrityError, TransientError)
  #   #each_set { |SetRecord| }
  #   #each_entry(path, languages:) { |EntryRecord or Malformed| }   streamed, filtered to languages
  module Catalog::Sources
    SetRecord = Data.define(:code, :name, :released_on, :parent_code) do
      def digest = Catalog::Sources.digest(to_h)
    end

    IdentityRecord = Data.define(:external_key, :name, :extension) do
      def digest = Catalog::Sources.digest(to_h)
    end

    EntryRecord = Data.define(:external_key, :identity, :set_code, :set_name, :number, :language, :name,
      :localized_name, :kind, :released_on, :image_url, :extension) do
      def digest = Catalog::Sources.digest(to_h.except(:identity).merge(identity_key: identity.external_key))
    end

    Malformed = Data.define(:external_key, :error)

    class Error < StandardError; end
    class TransientError < Error; end
    class IntegrityError < Error; end
    class ConfigurationError < Error; end

    def self.digest(attributes) = Digest::SHA256.hexdigest(ActiveSupport::JSON.encode(attributes))
  end
  ```
- [ ] Replace `app/models/catalog.rb`:
  ```ruby
  # Collectible-agnostic catalog: what collectibles exist, fed by source
  # adapters registered per collectible type in config/initializers/catalog.rb.
  module Catalog
    mattr_accessor :sources, default: {}

    def self.table_name_prefix = "catalog_"

    def self.source_class(collectible_type)
      sources.fetch(collectible_type) { raise ArgumentError, "unknown collectible type: #{collectible_type}" }.constantize
    end

    def self.source_for(collectible_type) = source_class(collectible_type).new

    def self.allowed_hosts = sources.values.flat_map { |name| name.constantize::ALLOWED_HOSTS }.uniq
  end
  ```
- [ ] Create `config/initializers/catalog.rb`:
  ```ruby
  # Catalog sources, one per collectible type (see app/models/catalog/sources.rb).
  Rails.application.config.to_prepare do
    Catalog.sources["mtg"] = "MTG::Scryfall::Source"
  end
  ```
- [ ] In `config/application.rb` inside the class, add:
  ```ruby
      # Downloaded catalog source files live on the persistent storage volume.
      config.x.catalog_download_dir = Rails.root.join("storage/catalog")
  ```
  In `config/environments/test.rb`, add: `config.x.catalog_download_dir = Rails.root.join("tmp/catalog")`
- [ ] Append to `spec/models/catalog_spec.rb`:
  ```ruby
  describe ".source_class" do
    it "returns the registered source class for a collectible type" do
      expect(described_class.source_class("mtg")).to eq(MTG::Scryfall::Source)
    end

    it "rejects unknown collectible types" do
      expect { described_class.source_class("pokemon") }.to raise_error(ArgumentError, /pokemon/)
    end
  end

  it "allows images and links only from registered sources' hosts" do
    expect(described_class.allowed_hosts).to contain_exactly("scryfall.com", "cards.scryfall.io", "svgs.scryfall.io")
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog_spec.rb` → FAIL (`uninitialized constant MTG::Scryfall`). This stays red until 3d; do not commit yet.

### 3b: Mapper (pure, no database or network)

- [ ] Create `spec/support/scryfall_helpers.rb`:
  ```ruby
  module ScryfallHelpers
    def scryfall_card(overrides = {})
      id = overrides.fetch("id") { SecureRandom.uuid }
      {
        "object" => "card", "id" => id, "oracle_id" => "oracle-bolt", "name" => "Lightning Bolt", "lang" => "en",
        "released_at" => "2009-07-17", "scryfall_uri" => "https://scryfall.com/card/m10/146/lightning-bolt",
        "layout" => "normal", "image_uris" => { "normal" => "https://cards.scryfall.io/normal/front/a/b/#{id}.jpg",
                                                "large" => "https://cards.scryfall.io/large/front/a/b/#{id}.jpg" },
        "mana_cost" => "{R}", "type_line" => "Instant", "oracle_text" => "Lightning Bolt deals 3 damage to any target.",
        "colors" => [ "R" ], "color_identity" => [ "R" ], "keywords" => [], "legalities" => { "modern" => "legal" },
        "games" => [ "paper", "mtgo" ], "digital" => false, "finishes" => [ "nonfoil", "foil" ], "rarity" => "common",
        "set" => "m10", "set_name" => "Magic 2010", "collector_number" => "146", "artist" => "Christopher Moeller",
        "frame" => "2003", "border_color" => "black", "tcgplayer_id" => 33_517, "prices" => { "usd" => "1.00" }
      }.merge(overrides)
    end

    def scryfall_set(overrides = {})
      { "object" => "set", "code" => "m10", "name" => "Magic 2010", "released_at" => "2009-07-17",
        "set_type" => "core", "digital" => false }.merge(overrides)
    end

    def gzip_jsonl(lines)
      io = StringIO.new
      gz = Zlib::GzipWriter.new(io)
      lines.each { |line| gz.puts(line.is_a?(String) ? line : JSON.generate(line)) }
      gz.close
      io.string
    end

    def stub_scryfall(cards:, sets: [ scryfall_set ], type: "default_cards", stamp: "20260929090555", size: nil)
      body = gzip_jsonl(cards)
      url = "https://data.scryfall.io/#{type.dasherize}/#{type.dasherize}-#{stamp}.jsonl.gz"
      bulk = { "object" => "list", "has_more" => false,
               "data" => [ { "type" => type, "jsonl_download_uri" => url, "compressed_size" => size || body.bytesize } ] }

      stub_request(:get, "https://api.scryfall.com/bulk-data").to_return(json_response(bulk))
      stub_request(:get, "https://api.scryfall.com/sets")
        .to_return(json_response("object" => "list", "has_more" => false, "data" => sets))
      stub_request(:get, url).to_return(body:, headers: { "Content-Type" => "application/gzip" })
    end

    def json_response(payload) = { body: JSON.generate(payload), headers: { "Content-Type" => "application/json" } }
  end

  RSpec.configure { |config| config.include ScryfallHelpers }
  ```
- [ ] Create `spec/fixtures/files/scryfall/azusa_ja_transform.json` (a trimmed real record from the planning spike):
  ```json
  {"object":"card","id":"ec725e92-98b9-4b1e-95df-b5a551aabd7d","name":"Azusa's Many Journeys // Likeness of the Seeker","lang":"ja","released_at":"2022-02-18","scryfall_uri":"https://scryfall.com/card/neo/172/ja/azusa","layout":"transform","color_identity":["G"],"keywords":[],"legalities":{"modern":"legal"},"games":["paper","arena","mtgo"],"digital":false,"finishes":["nonfoil","foil"],"rarity":"uncommon","set":"neo","set_name":"Kamigawa: Neon Dynasty","collector_number":"172","frame":"2015","border_color":"black","promo_types":[],"card_faces":[{"object":"card_face","name":"Azusa's Many Journeys","printed_name":"梓の幾多の旅","mana_cost":"{1}{G}","type_line":"Enchantment — Saga","oracle_text":"(As this Saga enters…)","colors":["G"],"artist":"Lindsey Look","oracle_id":"oracle-azusa","image_uris":{"normal":"https://cards.scryfall.io/normal/front/e/c/ec725e92-98b9-4b1e-95df-b5a551aabd7d.jpg","large":"https://cards.scryfall.io/large/front/e/c/ec725e92-98b9-4b1e-95df-b5a551aabd7d.jpg"}},{"object":"card_face","name":"Likeness of the Seeker","printed_name":"探求者の肖像","mana_cost":"","type_line":"Enchantment Creature — Human Monk","oracle_text":"Whenever Likeness of the Seeker becomes blocked…","colors":["G"],"power":"3","toughness":"3","artist":"Lindsey Look","oracle_id":"oracle-azusa","image_uris":{"normal":"https://cards.scryfall.io/normal/back/e/c/ec725e92-98b9-4b1e-95df-b5a551aabd7d.jpg","large":"https://cards.scryfall.io/large/back/e/c/ec725e92-98b9-4b1e-95df-b5a551aabd7d.jpg"}}]}
  ```
- [ ] Write the failing spec `spec/models/mtg/scryfall/mapper_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe MTG::Scryfall::Mapper, type: :model do
    describe ".entry_record" do
      it "maps core entry attributes", :aggregate_failures do
        card = scryfall_card("id" => "bolt-m10")
        record = described_class.entry_record(card)

        expect(record).to have_attributes(external_key: "bolt-m10", set_code: "m10", set_name: "Magic 2010",
          number: "146", language: "en", name: "Lightning Bolt", localized_name: nil, kind: "card",
          released_on: Date.new(2009, 7, 17), image_url: card.dig("image_uris", "normal"))
        expect(record.identity).to have_attributes(external_key: "oracle-bolt", name: "Lightning Bolt")
      end

      it "keeps MTG attributes in the extensions and drops prices", :aggregate_failures do
        record = described_class.entry_record(scryfall_card)

        expect(record.extension).to include(rarity: "common", finishes: %w[foil nonfoil], layout: "normal",
          legalities: { "modern" => "legal" }, external_ids: { "tcgplayer_id" => 33_517 })
        expect(record.extension[:faces].first).to include("name" => "Lightning Bolt", "artist" => "Christopher Moeller")
        expect(record.identity.extension).to include(mana_cost: "{R}", colors: [ "R" ], type_line: "Instant")
        expect(record.to_h.to_s).not_to include("1.00")
      end

      it "joins face localized names and takes images from faces for multi-face printings", :aggregate_failures do
        card = JSON.parse(file_fixture("scryfall/azusa_ja_transform.json").read)
        record = described_class.entry_record(card)

        expect(record.localized_name).to eq("梓の幾多の旅 // 探求者の肖像")
        expect(record.image_url).to include("/front/")
        expect(record.identity.external_key).to eq("oracle-azusa")
        expect(record.extension[:faces].map { |face| face["artist"] }).to eq([ "Lindsey Look", "Lindsey Look" ])
      end

      it "classifies tokens, emblems, art cards and other non-card kinds", :aggregate_failures do
        kinds = %w[token double_faced_token emblem art_series planar normal].map do |layout|
          described_class.entry_record(scryfall_card("layout" => layout)).kind
        end

        expect(kinds).to eq(%w[token token emblem art_card other card])
      end

      it "produces the same digest for the same data and a different one when stored data changes", :aggregate_failures do
        card = scryfall_card("id" => "x")

        expect(described_class.entry_record(card).digest).to eq(described_class.entry_record(card.merge("prices" => {})).digest)
        expect(described_class.entry_record(card.merge("rarity" => "rare")).digest).not_to eq(described_class.entry_record(card).digest)
      end

      it "raises KeyError when a required field is missing" do
        expect { described_class.entry_record(scryfall_card.except("set")) }.to raise_error(KeyError)
      end
    end

    describe ".paper?" do
      it "is false for digital-only printings", :aggregate_failures do
        expect(described_class.paper?(scryfall_card)).to be(true)
        expect(described_class.paper?(scryfall_card("digital" => true, "games" => [ "arena" ]))).to be(false)
      end
    end

    describe ".set_record" do
      it "allows a missing release date" do
        expect(described_class.set_record(scryfall_set("released_at" => nil)).released_on).to be_nil
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/scryfall/mapper_spec.rb` → FAIL (`uninitialized constant MTG::Scryfall`).
- [ ] Create `app/models/mtg/scryfall/mapper.rb`:
  ```ruby
  # Pure mapping from Scryfall card and set objects to catalog source records.
  module MTG::Scryfall::Mapper
    KINDS = { "token" => "token", "double_faced_token" => "token", "emblem" => "emblem", "art_series" => "art_card",
              "planar" => "other", "scheme" => "other", "vanguard" => "other" }.freeze
    FLAG_TAGS = %w[full_art textless oversized promo variation].freeze
    EXTERNAL_IDS = %w[tcgplayer_id tcgplayer_etched_id cardmarket_id mtgo_id mtgo_foil_id arena_id multiverse_ids].freeze
    FACE_FIELDS = %w[name printed_name mana_cost type_line oracle_text power toughness loyalty defense artist].freeze

    module_function

    def paper?(card) = !card["digital"] && Array(card["games"]).include?("paper")

    def set_record(set)
      Catalog::Sources::SetRecord.new(code: set.fetch("code"), name: set.fetch("name"),
        released_on: date(set["released_at"]), parent_code: set["parent_set_code"])
    end

    def entry_record(card)
      faces = faces(card)
      Catalog::Sources::EntryRecord.new(
        external_key: card.fetch("id"),
        identity: identity_record(card, faces),
        set_code: card.fetch("set"),
        set_name: card.fetch("set_name"),
        number: card.fetch("collector_number"),
        language: card.fetch("lang"),
        name: card.fetch("name"),
        localized_name: card["printed_name"] || faces.filter_map { |face| face["printed_name"] }.join(" // ").presence,
        kind: KINDS.fetch(card.fetch("layout"), "card"),
        released_on: date(card["released_at"]),
        image_url: faces.first.dig("image_uris", "normal"),
        extension: {
          rarity: card.fetch("rarity"), finishes: card.fetch("finishes").sort, layout: card.fetch("layout"),
          frame: card["frame"], border_color: card["border_color"], security_stamp: card["security_stamp"],
          variant_tags: variant_tags(card), legalities: card.fetch("legalities", {}),
          external_ids: card.slice(*EXTERNAL_IDS), faces:, scryfall_uri: card.fetch("scryfall_uri")
        }
      )
    end

    def identity_record(card, faces)
      Catalog::Sources::IdentityRecord.new(
        external_key: card["oracle_id"] || card.fetch("card_faces").first.fetch("oracle_id"),
        name: card.fetch("name"),
        extension: {
          mana_cost: joined(card, faces, "mana_cost"), type_line: joined(card, faces, "type_line"),
          oracle_text: joined(card, faces, "oracle_text"),
          colors: Array(card["colors"] || card["card_faces"]&.flat_map { |face| Array(face["colors"]) }).uniq.sort,
          color_identity: card.fetch("color_identity").sort, keywords: card.fetch("keywords").sort
        }
      )
    end

    def faces(card)
      (card["card_faces"].presence || [ card ]).map do |face|
        face.slice(*FACE_FIELDS).merge("image_uris" => (face["image_uris"] || card["image_uris"] || {}).slice("normal", "large"))
      end
    end

    def joined(card, faces, field) = card[field] || faces.filter_map { |face| face[field].presence }.join(" // ").presence

    def variant_tags(card)
      (Array(card["promo_types"]) + Array(card["frame_effects"]) + FLAG_TAGS.select { |flag| card[flag] }).uniq.sort
    end

    def date(value) = value && Date.iso8601(value)
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/scryfall/mapper_spec.rb` → PASS.
- [ ] Commit: `feat(mtg): map Scryfall cards and sets to catalog source records`

### 3c: HTTP client

- [ ] Write the failing spec `spec/models/mtg/scryfall/client_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe MTG::Scryfall::Client, type: :model do
    subject(:client) { described_class.new(sleeper: ->(seconds) { naps << seconds }, clock: -> { now }) }

    let(:naps) { [] }
    let(:now) { 100.0 }

    describe "#get_json" do
      it "sends a descriptive User-Agent and Accept header", :aggregate_failures do
        stub = stub_request(:get, "https://api.scryfall.com/sets")
          .with(headers: { "User-Agent" => %r{\ACollector/}, "Accept" => "application/json" })
          .to_return(json_response("data" => []))

        expect(client.get_json("/sets")).to eq("data" => [])
        expect(stub).to have_been_requested
      end

      it "waits at least 100 ms between API calls" do
        stub_request(:get, "https://api.scryfall.com/sets").to_return(json_response({}))

        2.times { client.get_json("/sets") }

        expect(naps).to eq([ 0.1 ])
      end

      it "backs off on 429 and retries", :aggregate_failures do
        stub_request(:get, "https://api.scryfall.com/sets")
          .to_return({ status: 429, headers: { "Retry-After" => "2" } }, json_response("ok" => true))

        expect(client.get_json("/sets")).to eq("ok" => true)
        expect(naps).to include(2)
      end

      it "raises a transient error when rate limiting persists" do
        stub_request(:get, "https://api.scryfall.com/sets").to_return(status: 429)

        expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::TransientError, /rate limited/)
      end

      it "raises a transient error on timeouts" do
        stub_request(:get, "https://api.scryfall.com/sets").to_timeout

        expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::TransientError)
      end
    end

    describe "#download" do
      it "streams the body into the given IO" do
        stub_request(:get, "https://data.scryfall.io/f.jsonl.gz").to_return(body: "abc")
        io = StringIO.new

        client.download("https://data.scryfall.io/f.jsonl.gz", to: io)

        expect(io.string).to eq("abc")
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/scryfall/client_spec.rb` → FAIL (`uninitialized constant MTG::Scryfall::Client`).
- [ ] Create `app/models/mtg/scryfall/client.rb`:
  ```ruby
  require "net/http"

  # Minimal Scryfall HTTP client following https://scryfall.com/docs/api:
  # descriptive headers, >= 100 ms between API calls, back-off on 429, timeouts.
  class MTG::Scryfall::Client
    API_ROOT = "https://api.scryfall.com"
    USER_AGENT = "Collector/1.0 (+https://github.com/plainprogrammer/Collector)"
    MIN_INTERVAL = 0.1
    MAX_ATTEMPTS = 3
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 60
    NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, EOFError ].freeze

    def initialize(sleeper: ->(seconds) { sleep(seconds) }, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @sleeper = sleeper
      @clock = clock
      @last_request_at = nil
    end

    # Accepts an API path ("/sets") or a full API URL (a "next_page" link).
    def get_json(path_or_url)
      uri = URI.join(API_ROOT, path_or_url)
      MAX_ATTEMPTS.times do |attempt|
        throttle
        response = request(uri) { |http, request| http.request(request) }
        return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
        raise Catalog::Sources::TransientError, "GET #{uri} returned #{response.code}" unless response.is_a?(Net::HTTPTooManyRequests)

        @sleeper.call(Integer(response["Retry-After"].to_s, exception: false) || 2**attempt)
      end
      raise Catalog::Sources::TransientError, "GET #{uri} still rate limited after #{MAX_ATTEMPTS} attempts"
    end

    def download(url, to:)
      uri = URI(url)
      request(uri) do |http, request|
        http.request(request) do |response|
          raise Catalog::Sources::TransientError, "GET #{uri} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          response.read_body { |chunk| to.write(chunk) }
        end
      end
    end

    private
      def request(uri)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          yield http, Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => "application/json")
        end
      rescue *NETWORK_ERRORS => error
        raise Catalog::Sources::TransientError, "GET #{uri}: #{error.class}: #{error.message}"
      end

      def throttle
        if @last_request_at
          wait = MIN_INTERVAL - (@clock.call - @last_request_at)
          @sleeper.call(wait.round(3)) if wait.positive?
        end
        @last_request_at = @clock.call
      end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/scryfall/client_spec.rb` → PASS.
- [ ] Commit: `feat(mtg): add rate-limited Scryfall HTTP client`

### 3d: Source (languages, version, download, streaming)

- [ ] Write the failing spec `spec/models/mtg/scryfall/source_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe MTG::Scryfall::Source, type: :model do
    subject(:source) { described_class.new(env:, client: MTG::Scryfall::Client.new(sleeper: ->(_) { })) }

    let(:env) { {} }
    let(:dir) { Pathname(Dir.mktmpdir) }

    after { FileUtils.rm_rf(dir) }

    it "declares its extension models and hosts", :aggregate_failures do
      expect(described_class.entry_extension_model).to eq(MTG::Printing)
      expect(described_class.identity_extension_model).to eq(MTG::Card)
      expect(described_class::ALLOWED_HOSTS).to include("cards.scryfall.io")
    end

    describe "#languages" do
      it "defaults to English" do
        expect(source.languages).to eq([ "en" ])
      end

      context "when COLLECTOR_MTG_LANGUAGES is set" do
        let(:env) { { "COLLECTOR_MTG_LANGUAGES" => " JA, de " } }

        it "adds the configured languages, lower-cased and sorted" do
          expect(source.languages).to eq(%w[de en ja])
        end
      end

      context "when a code is not a Scryfall language" do
        let(:env) { { "COLLECTOR_MTG_LANGUAGES" => "ja,xx" } }

        it "raises a configuration error naming the code" do
          expect { source.languages }.to raise_error(Catalog::Sources::ConfigurationError, /xx/)
        end
      end
    end

    describe "#current_version and #download" do
      it "uses default_cards for English only and names the version after the file", :aggregate_failures do
        stub_scryfall(cards: [ scryfall_card ], type: "default_cards", stamp: "20260929090555")

        version = source.current_version(languages: [ "en" ])
        path = source.download(version, dir:)

        expect(version).to eq("default-cards-20260929090555")
        expect(path).to eq(dir.join("default-cards-20260929090555.jsonl.gz"))
        expect(path).to exist
      end

      it "uses all_cards when other languages are configured" do
        stub_scryfall(cards: [], type: "all_cards", stamp: "20260929091807")

        expect(source.current_version(languages: %w[en ja])).to eq("all-cards-20260929091807")
      end

      it "discards a download whose size differs from the published size", :aggregate_failures do
        stub_scryfall(cards: [ scryfall_card ], size: 1)
        version = source.current_version(languages: [ "en" ])

        expect { source.download(version, dir:) }.to raise_error(Catalog::Sources::IntegrityError, /published 1/)
        expect(dir.children).to be_empty
      end

      it "reuses a verified file and keeps only the two newest downloads", :aggregate_failures do
        %w[a b c].each_with_index do |name, index|
          dir.join("#{name}.jsonl.gz").write("x")
          FileUtils.touch(dir.join("#{name}.jsonl.gz"), mtime: Time.now - (10 - index))
        end
        stub_scryfall(cards: [ scryfall_card ])
        version = source.current_version(languages: [ "en" ])

        2.times { source.download(version, dir:) }

        expect(WebMock).to have_requested(:get, /data\.scryfall\.io/).once
        expect(dir.children.map { |path| path.basename.to_s }).to contain_exactly("c.jsonl.gz", "#{version}.jsonl.gz")
      end
    end

    describe "#each_entry" do
      it "yields records for configured paper languages and Malformed for bad lines", :aggregate_failures do
        path = dir.join("f.jsonl.gz")
        path.binwrite(gzip_jsonl([
          scryfall_card("id" => "en-1"),
          scryfall_card("id" => "ja-1", "lang" => "ja", "printed_name" => "稲妻"),
          scryfall_card("id" => "de-1", "lang" => "de"),
          scryfall_card("id" => "arena-1", "digital" => true, "games" => [ "arena" ]),
          scryfall_card("id" => "bad-1").except("collector_number"),
          "{not json"
        ]))

        yielded = []
        source.each_entry(path, languages: %w[en ja]) { |record| yielded << record }

        expect(yielded.grep(Catalog::Sources::EntryRecord).map(&:external_key)).to eq(%w[en-1 ja-1])
        expect(yielded.grep(Catalog::Sources::Malformed).map(&:external_key)).to eq([ "bad-1", nil ])
      end
    end

    describe "#each_set" do
      it "yields a record per set" do
        stub_scryfall(cards: [], sets: [ scryfall_set, scryfall_set("code" => "neo", "name" => "Kamigawa") ])

        expect(source.enum_for(:each_set).map(&:code)).to eq(%w[m10 neo])
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/scryfall/source_spec.rb` → FAIL (`uninitialized constant MTG::Scryfall::Source`).
- [ ] Create `app/models/mtg/scryfall/source.rb`:
  ```ruby
  # Catalog source for Magic: The Gathering backed by Scryfall bulk data
  # (implements the contract documented in app/models/catalog/sources.rb).
  class MTG::Scryfall::Source
    ALLOWED_HOSTS = %w[scryfall.com cards.scryfall.io svgs.scryfall.io].freeze
    LANGUAGES = %w[en es fr de it pt ja ko ru zhs zht he la grc ar sa ph qya].freeze
    LANGUAGES_ENV = "COLLECTOR_MTG_LANGUAGES"
    KEEP_DOWNLOADS = 2

    def self.entry_extension_model = MTG::Printing
    def self.identity_extension_model = MTG::Card

    def initialize(client: MTG::Scryfall::Client.new, env: ENV)
      @client = client
      @env = env
      @bulk_files = {}
    end

    def languages
      requested = @env.fetch(LANGUAGES_ENV, "").split(",").map { |code| code.strip.downcase }.compact_blank
      invalid = requested - LANGUAGES
      if invalid.any?
        raise Catalog::Sources::ConfigurationError,
          "#{LANGUAGES_ENV} has unsupported language code(s): #{invalid.join(", ")} (supported: #{LANGUAGES.join(", ")})"
      end
      (requested | [ "en" ]).sort
    end

    # English only needs Scryfall's much smaller default_cards file.
    def current_version(languages:)
      type = languages == [ "en" ] ? "default_cards" : "all_cards"
      file = @client.get_json("/bulk-data").fetch("data").find { |entry| entry["type"] == type }
      raise Catalog::Sources::TransientError, "Scryfall bulk-data lists no #{type} file" unless file

      File.basename(file.fetch("jsonl_download_uri"), ".jsonl.gz").tap { |version| @bulk_files[version] = file }
    end

    def download(version, dir:)
      file = @bulk_files.fetch(version)
      expected = Integer(file.fetch("compressed_size"))
      path = dir.join("#{version}.jsonl.gz")
      dir.mkpath
      fetch(file.fetch("jsonl_download_uri"), path, expected) unless path.exist? && path.size == expected
      prune(dir)
      path
    end

    def each_set
      url = "/sets"
      while url
        page = @client.get_json(url)
        page.fetch("data").each { |set| yield MTG::Scryfall::Mapper.set_record(set) }
        url = page["has_more"] ? page.fetch("next_page") : nil
      end
    end

    def each_entry(path, languages:)
      allowed = languages.to_set
      Zlib::GzipReader.open(path) do |gzip|
        gzip.each_line do |line|
          record = entry_or_malformed(line, allowed)
          yield record if record
        end
      end
    end

    private
      def fetch(url, path, expected)
        partial = Pathname("#{path}.part")
        File.open(partial, "wb") { |io| @client.download(url, to: io) }
        return partial.rename(path) if partial.size == expected

        actual = partial.size
        partial.delete
        raise Catalog::Sources::IntegrityError, "#{path.basename}: downloaded #{actual} bytes, Scryfall published #{expected}"
      end

      def prune(dir)
        dir.glob("*.jsonl.gz").sort_by(&:mtime).reverse.drop(KEEP_DOWNLOADS).each(&:delete)
      end

      def entry_or_malformed(line, allowed)
        return if line.strip.empty?

        card = JSON.parse(line)
        return unless allowed.include?(card["lang"]) && MTG::Scryfall::Mapper.paper?(card)

        MTG::Scryfall::Mapper.entry_record(card)
      rescue JSON::ParserError, KeyError, ArgumentError, TypeError, NoMethodError => error
        Catalog::Sources::Malformed.new(external_key: card.is_a?(Hash) ? card["id"] : nil, error: "#{error.class}: #{error.message}")
      end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg spec/models/catalog_spec.rb` → PASS; `bin/rails zeitwerk:check` → `All is good!`
- [ ] Commit: `feat(mtg): add Scryfall bulk-data source behind Catalog::Sources`

---

## Phase 4: Refresh pipeline

**Implements:** FR-4, FR-6 (effect of the setting), FR-3 (malformed handling end-to-end) | **Satisfies:** AC-4.2, AC-4.3, AC-4.5, AC-4.6, AC-5.2, AC-6.1, AC-6.2, AC-6.3, AC-6.4, AC-7.1–AC-7.10, AC-9.3
**Files:** `app/models/catalog/refresh.rb`, `spec/support/time_helpers.rb`, `spec/support/fake_catalog_source.rb`, `spec/models/catalog/refresh_spec.rb`, `spec/models/catalog/refresh_scryfall_spec.rb`
**Interfaces:** Consumes: Phase 2 models, the Phase 3 contract. Produces: `Catalog::Refresh.new(collectible_type, trigger:, source: Catalog.source_for(collectible_type))#call` → `Catalog::RefreshRun` (re-raises on failure after recording it).

- [ ] Create `spec/support/time_helpers.rb` (rspec-rails does not include Rails' time helpers):
  ```ruby
  RSpec.configure { |config| config.include ActiveSupport::Testing::TimeHelpers }
  ```
- [ ] Create `spec/support/fake_catalog_source.rb` (implements the contract with no MTG or Scryfall knowledge):
  ```ruby
  class FakeCatalogSource
    ALLOWED_HOSTS = %w[example.test].freeze

    def self.entry_extension_model = nil
    def self.identity_extension_model = nil

    attr_accessor :version, :sets, :entries, :languages_result, :fail_at
    attr_reader :downloads

    def initialize(version: "v1", sets: [], entries: [], languages: [ "en" ], fail_at: nil)
      @version, @sets, @entries, @languages_result, @fail_at = version, sets, entries, languages, fail_at
      @downloads = []
    end

    def languages
      raise languages_result if languages_result.is_a?(Exception)

      languages_result
    end

    def current_version(languages:) = version

    def download(version, dir:)
      downloads << version
      dir.join("#{version}.fake")
    end

    def each_set(&) = sets.each(&)

    def each_entry(_path, languages:)
      entries.each_with_index do |record, index|
        raise "source exploded" if index == fail_at

        yield record if record.is_a?(Catalog::Sources::Malformed) || languages.include?(record.language)
      end
    end
  end

  module CatalogRecordHelpers
    def identity_record(key = "bolt", name: "Lightning Bolt", extension: {})
      Catalog::Sources::IdentityRecord.new(external_key: key, name:, extension:)
    end

    def entry_record(key, identity: identity_record, set_code: "lea", language: "en", name: identity.name, kind: "card", number: "1")
      Catalog::Sources::EntryRecord.new(external_key: key, identity:, set_code:, set_name: set_code.upcase, number:,
        language:, name:, localized_name: nil, kind:, released_on: Date.new(1993, 8, 5),
        image_url: "https://example.test/#{key}.jpg", extension: {})
    end

    def set_record(code) = Catalog::Sources::SetRecord.new(code:, name: code.upcase, released_on: Date.new(1993, 8, 5), parent_code: nil)
  end

  RSpec.configure { |config| config.include CatalogRecordHelpers }
  ```
- [ ] Write the failing spec `spec/models/catalog/refresh_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Catalog::Refresh, type: :model do
    let(:source) { FakeCatalogSource.new(sets: [ set_record("lea") ], entries: [ entry_record("a"), entry_record("b") ]) }

    def refresh(trigger: "manual") = described_class.new("fake", trigger:, source:).call

    it "inserts entries with their sets and identities and records the run", :aggregate_failures do
      run = refresh

      expect(run).to have_attributes(status: "applied", source_version: "v1", languages: "en", seen_count: 2, inserted_count: 2)
      expect(Catalog::Entry.pluck(:external_key)).to contain_exactly("a", "b")
      expect(Catalog::Identity.pluck(:external_key)).to eq([ "bolt" ])
      expect(Catalog::Set.pluck(:code)).to eq([ "lea" ])
    end

    it "writes nothing when the same data is applied again", :aggregate_failures do
      refresh
      stamps = Catalog::Entry.pluck(:updated_at)

      travel 1.hour do
        run = refresh
        expect(run).to have_attributes(inserted_count: 0, updated_count: 0, retired_count: 0)
      end
      expect(Catalog::Entry.count).to eq(2)
      expect(Catalog::Entry.pluck(:updated_at)).to eq(stamps)
    end

    it "updates only the entry whose stored data changed", :aggregate_failures do
      refresh
      source.entries = [ entry_record("a"), entry_record("b", number: "2") ]

      run = refresh

      expect(run.updated_count).to eq(1)
      expect(Catalog::Entry.find_by(external_key: "b").number).to eq("2")
    end

    it "updates an identity whose data changed even when no entry changed" do
      refresh
      source.entries = [ entry_record("a", identity: identity_record(extension: { errata: true })), entry_record("b") ]

      expect { refresh }.to change { Catalog::Identity.find_by(external_key: "bolt").content_digest }
    end

    it "retires entries missing from the source without deleting them", :aggregate_failures do
      refresh
      source.entries = [ entry_record("a") ]

      freeze_time do
        run = refresh
        expect(run.retired_count).to eq(1)
        expect(Catalog::Entry.find_by(external_key: "b").retired_at).to eq(Time.current)
      end
    end

    it "restores a retired entry that reappears, keeping its id", :aggregate_failures do
      refresh
      id = Catalog::Entry.find_by(external_key: "b").id
      source.entries = [ entry_record("a") ]
      refresh
      source.entries = [ entry_record("a"), entry_record("b") ]

      run = refresh

      expect(run.restored_count).to eq(1)
      expect(Catalog::Entry.find_by(external_key: "b")).to have_attributes(id:, retired_at: nil)
    end

    it "creates a set the listing lacks from the entry's own set code and name" do
      source.entries = [ entry_record("a", set_code: "xyz") ]

      refresh

      expect(Catalog::Set.find_by(code: "xyz").name).to eq("XYZ")
    end

    it "skips and counts malformed records", :aggregate_failures do
      source.entries = [ entry_record("a"), Catalog::Sources::Malformed.new(external_key: "bad", error: "KeyError") ]

      run = refresh

      expect(run).to have_attributes(status: "applied", seen_count: 1, malformed_count: 1)
    end

    it "does not retire an existing entry whose record is malformed this run", :aggregate_failures do
      refresh
      source.entries = [ entry_record("a"), Catalog::Sources::Malformed.new(external_key: "b", error: "KeyError") ]

      run = refresh

      expect(run.retired_count).to eq(0)
      expect(Catalog::Entry.find_by(external_key: "b")).not_to be_retired
    end

    it "fails without retiring anything when the source yields no valid records", :aggregate_failures do
      refresh
      source.entries = [ Catalog::Sources::Malformed.new(external_key: nil, error: "JSON::ParserError") ]

      expect { refresh }.to raise_error(Catalog::Sources::Error, /no valid records/)
      expect(Catalog::RefreshRun.recent.first).to be_failed
      expect(Catalog::Entry.active.count).to eq(2)
    end

    it "retires entries of a language that is no longer configured" do
      source.entries = [ entry_record("en-1"), entry_record("ja-1", language: "ja") ]
      source.languages_result = %w[en ja]
      refresh
      source.languages_result = [ "en" ]

      refresh(trigger: "scheduled")

      expect(Catalog::Entry.find_by(external_key: "ja-1")).to be_retired
    end

    context "when the run fails partway" do
      before do
        refresh
        source.entries = [ entry_record("a", number: "9"), entry_record("c"), entry_record("d") ]
        source.fail_at = 2
      end

      it "records the failure and retires nothing", :aggregate_failures do
        expect { refresh }.to raise_error(RuntimeError, "source exploded")

        run = Catalog::RefreshRun.recent.first
        expect(run).to have_attributes(status: "failed", message: "RuntimeError: source exploded", retired_count: 0)
        expect(Catalog::Entry.where.not(retired_at: nil)).to be_empty
        expect(Catalog::Entry.find_by(external_key: "b")).to be_present
      end

      it "is completed by the next run as if it never happened", :aggregate_failures do
        expect { refresh }.to raise_error(RuntimeError)
        source.fail_at = nil
        refresh

        expect(Catalog::Entry.active.pluck(:external_key)).to contain_exactly("a", "c", "d")
      end
    end

    describe "skipping" do
      before { refresh }

      it "skips a scheduled run when the version and languages were already applied", :aggregate_failures do
        run = refresh(trigger: "scheduled")

        expect(run).to have_attributes(status: "skipped", message: "v1 already applied")
        expect(source.downloads).to eq([ "v1" ])
      end

      it "applies a scheduled run when the source publishes a new version", :aggregate_failures do
        source.version = "v2"

        run = refresh(trigger: "scheduled")

        expect(run).to have_attributes(status: "applied", trigger: "scheduled", source_version: "v2")
        expect(source.downloads).to eq(%w[v1 v2])
      end

      it "applies a scheduled run when the language set changed" do
        source.languages_result = %w[en ja]

        expect(refresh(trigger: "scheduled")).to be_applied
      end

      it "never skips a manual run" do
        expect(refresh(trigger: "manual")).to be_applied
      end
    end

    it "fails before downloading when the language setting is invalid", :aggregate_failures do
      source.languages_result = Catalog::Sources::ConfigurationError.new("unsupported language code(s): xx")

      expect { refresh }.to raise_error(Catalog::Sources::ConfigurationError)
      expect(Catalog::RefreshRun.recent.first).to have_attributes(status: "failed", message: a_string_including("xx"))
      expect(source.downloads).to be_empty
    end

    it "records a skip without touching the catalog while another run is in progress", :aggregate_failures do
      create(:catalog_refresh_run, collectible_type: "fake", status: "running", started_at: 1.hour.ago, finished_at: nil)

      expect(refresh).to be_skipped
      expect(Catalog::Entry.count).to eq(0)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/refresh_spec.rb` → FAIL (`uninitialized constant Catalog::Refresh`).
- [ ] Create `app/models/catalog/refresh.rb`:
  ```ruby
  # Applies a catalog source's current data: writes only changed rows in short
  # batches, retires entries the source no longer lists (only after a complete
  # pass), restores ones that come back, and records a Catalog::RefreshRun.
  class Catalog::Refresh
    BATCH_SIZE = 1_000

    def initialize(collectible_type, trigger:, source: Catalog.source_for(collectible_type))
      @collectible_type = collectible_type
      @trigger = trigger
      @source = source
      @counts = Hash.new(0)
    end

    def call
      @run = Catalog::RefreshRun.start!(@collectible_type, trigger: @trigger)
      return @run unless @run.running?

      languages = @source.languages
      version = @source.current_version(languages:)
      @run.update!(source_version: version, languages: languages.join(","))
      return skip(version) if already_applied?(version)

      path = @source.download(version, dir: Rails.configuration.x.catalog_download_dir.join(@collectible_type))
      sync_sets
      sync_entries(path, languages)
      retire_unseen
      @run.finish!(:applied, counts: @counts)
      @run
    rescue StandardError => error
      @run.finish!(:failed, message: "#{error.class}: #{error.message}", counts: @counts) if @run&.running?
      raise
    end

    private
      def already_applied?(version)
        @trigger == "scheduled" &&
          Catalog::RefreshRun.applied?(@collectible_type, source_version: version, languages: @run.languages)
      end

      def skip(version)
        @run.finish!(:skipped, message: "#{version} already applied")
        @run
      end

      def sync_sets
        @sets = Catalog::Set.where(collectible_type: @collectible_type).pluck(:code, :id, :content_digest)
          .to_h { |code, id, digest| [ code, [ id, digest ] ] }
        changed = []
        @source.each_set { |record| changed << record unless @sets.dig(record.code, 1) == record.digest }
        write_sets(changed)
      end

      def sync_entries(path, languages)
        @identities = Catalog::Identity.where(collectible_type: @collectible_type).pluck(:external_key, :id, :content_digest)
          .to_h { |key, id, digest| [ key, [ id, digest ] ] }
        @entries = Catalog::Entry.where(collectible_type: @collectible_type).pluck(:external_key, :id, :content_digest, :retired_at)
          .to_h { |key, id, digest, retired_at| [ key, [ id, digest, retired_at ] ] }
        @seen = ::Set.new
        @identities_checked = ::Set.new
        @pending_entries = []
        @pending_identities = []

        @source.each_entry(path, languages:) do |record|
          next record_malformed(record) if record.is_a?(Catalog::Sources::Malformed)
          next if @seen.include?(record.external_key) # duplicate line in the source

          @counts[:seen] += 1
          @seen << record.external_key
          queue_identity(record.identity)
          queue_entry(record)
          flush if @pending_entries.size >= BATCH_SIZE || @pending_identities.size >= BATCH_SIZE
        end
        flush
        # An unreadable file must not look like "everything was removed upstream".
        raise Catalog::Sources::Error, "no valid records (#{@counts[:malformed]} malformed)" if @counts[:seen].zero?
      end

      def queue_identity(identity)
        return unless @identities_checked.add?(identity.external_key)

        @pending_identities << identity unless @identities.dig(identity.external_key, 1) == identity.digest
      end

      def queue_entry(record)
        _id, digest, retired_at = @entries[record.external_key]
        @pending_entries << record unless digest == record.digest && retired_at.nil?
      end

      def flush
        return if @pending_entries.empty? && @pending_identities.empty?

        Catalog::Entry.transaction do
          write_sets(@pending_entries.reject { |record| @sets.key?(record.set_code) }.uniq(&:set_code).map do |record|
            Catalog::Sources::SetRecord.new(code: record.set_code, name: record.set_name, released_on: nil, parent_code: nil)
          end)
          write_identities(@pending_identities)
          write_entries(@pending_entries)
        end
        @pending_entries.each { |record| tally(record) }
        @pending_entries = []
        @pending_identities = []
      end

      def write_sets(records)
        return if records.empty?

        rows = records.map { |record| record.to_h.merge(collectible_type: @collectible_type, content_digest: record.digest) }
        Catalog::Set.upsert_all(rows, unique_by: %i[collectible_type code], returning: %i[code id])
          .each { |row| @sets[row["code"]] = [ row["id"], nil ] }
      end

      def write_identities(records)
        return if records.empty?

        rows = records.map do |record|
          { collectible_type: @collectible_type, external_key: record.external_key, name: record.name, content_digest: record.digest }
        end
        ids = upsert_returning_ids(Catalog::Identity, rows)
        records.each { |record| @identities[record.external_key] = [ ids.fetch(record.external_key), record.digest ] }
        write_extensions(@source.class.identity_extension_model, :catalog_identity_id, records, ids)
      end

      def write_entries(records)
        return if records.empty?

        ids = upsert_returning_ids(Catalog::Entry, records.map { |record| entry_row(record) })
        write_extensions(@source.class.entry_extension_model, :catalog_entry_id, records, ids)
      end

      def entry_row(record)
        { collectible_type: @collectible_type, external_key: record.external_key,
          catalog_set_id: @sets.fetch(record.set_code).first,
          catalog_identity_id: @identities.fetch(record.identity.external_key).first,
          number: record.number, language: record.language, name: record.name, localized_name: record.localized_name,
          kind: record.kind, released_on: record.released_on, image_url: record.image_url,
          content_digest: record.digest, retired_at: nil }
      end

      def upsert_returning_ids(model, rows)
        model.upsert_all(rows, unique_by: %i[collectible_type external_key], returning: %i[external_key id])
          .to_h { |row| [ row["external_key"], row["id"] ] }
      end

      def write_extensions(model, foreign_key, records, ids)
        return if model.nil?

        rows = records.map { |record| record.extension.merge(foreign_key => ids.fetch(record.external_key)) }
        model.upsert_all(rows, unique_by: foreign_key)
      end

      def tally(record)
        _id, digest, retired_at = @entries[record.external_key]
        if digest.nil? then @counts[:inserted] += 1
        elsif retired_at then @counts[:restored] += 1
        else @counts[:updated] += 1
        end
      end

      # A known entry whose record is malformed this run is kept as it was, not retired.
      def record_malformed(record)
        @counts[:malformed] += 1
        @seen << record.external_key if record.external_key
        Rails.logger.warn("catalog.refresh skipped malformed #{@collectible_type} record #{record.external_key.inspect}: #{record.error}")
      end

      def retire_unseen
        ids = @entries.filter_map { |key, (id, _digest, retired_at)| id if retired_at.nil? && !@seen.include?(key) }
        now = Time.current
        ids.each_slice(BATCH_SIZE) do |slice|
          # Bulk maintenance of global catalog rows: no callbacks or validations apply.
          Catalog::Entry.where(id: slice).update_all(retired_at: now, updated_at: now)
        end
        @counts[:retired] = ids.size
      end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/refresh_spec.rb` → PASS.
- [ ] Commit: `feat(catalog): add incremental catalog refresh with retire and restore`
- [ ] Write the Scryfall end-to-end spec `spec/models/catalog/refresh_scryfall_spec.rb` (real source, WebMock-stubbed Scryfall):
  ```ruby
  require "rails_helper"

  RSpec.describe Catalog::Refresh, type: :model do
    let(:env) { {} }
    let(:source) { MTG::Scryfall::Source.new(env:, client: MTG::Scryfall::Client.new(sleeper: ->(_) { })) }
    let(:cards) do
      [ scryfall_card("id" => "bolt-en"),
        scryfall_card("id" => "bolt-ja", "lang" => "ja", "printed_name" => "稲妻"),
        scryfall_card("id" => "bolt-arena", "digital" => true, "games" => [ "arena" ]),
        scryfall_card("id" => "goblin-token", "layout" => "token", "name" => "Goblin", "oracle_id" => "oracle-goblin") ]
    end

    def refresh = described_class.new("mtg", trigger: "manual", source:).call

    after { FileUtils.rm_rf(Rails.configuration.x.catalog_download_dir) }

    it "ingests English paper printings by default with MTG extensions", :aggregate_failures do
      stub_scryfall(cards:, type: "default_cards")

      refresh

      expect(Catalog::Entry.pluck(:external_key)).to contain_exactly("bolt-en", "goblin-token")
      expect(Catalog::Entry.find_by(external_key: "goblin-token").kind).to eq("token")
      expect(MTG::Printing.find_by(entry: Catalog::Entry.find_by(external_key: "bolt-en"))).to have_attributes(rarity: "common")
      expect(MTG::Card.count).to eq(2)
    end

    context "when Japanese is configured" do
      let(:env) { { "COLLECTOR_MTG_LANGUAGES" => "ja" } }

      it "also ingests Japanese printings and never digital-only ones", :aggregate_failures do
        stub_scryfall(cards:, type: "all_cards")

        refresh

        expect(Catalog::Entry.pluck(:external_key)).to contain_exactly("bolt-en", "bolt-ja", "goblin-token")
        expect(Catalog::Entry.find_by(external_key: "bolt-ja").localized_name).to eq("稲妻")
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/refresh_scryfall_spec.rb` → PASS (fix the adapter or refresh if not).
- [ ] Commit: `test(catalog): cover Scryfall refresh end to end`

---

## Phase 5: Job, weekly schedule, operator commands, docs

**Implements:** FR-5, FR-6 (documentation), FR-4 (concurrency) | **Satisfies:** AC-4.1, AC-4.2, AC-4.4, AC-5.1, AC-5.3, AC-6.5, AC-8.1, AC-8.2
**Files:** `app/jobs/catalog/refresh_job.rb`, `config/recurring.yml`, `lib/tasks/catalog.rake`, `spec/jobs/catalog/refresh_job_spec.rb`, `spec/config/recurring_spec.rb`, `spec/tasks/catalog_rake_spec.rb`, `README.md`, `compose.yaml`, `config/deploy.yml`
**Interfaces:** Consumes: `Catalog::Refresh`, `Catalog::RefreshRun#status_line`. Produces: `Catalog::RefreshJob.perform_later(type, trigger = "manual")`; rake `catalog:refresh[type]`, `catalog:status[type]`; Kamal aliases `catalog-refresh`, `catalog-status`.

- [ ] Write the failing spec `spec/jobs/catalog/refresh_job_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Catalog::RefreshJob, type: :job do
    it "allows one refresh per collectible type at a time, queuing the rest", :aggregate_failures do
      expect(described_class.concurrency_limit).to eq(1)
      expect(described_class.concurrency_on_conflict).to eq(:block)
      expect(described_class.concurrency_duration).to eq(Catalog::RefreshRun::STALE_AFTER)
      expect(described_class.new("mtg").concurrency_key).to eq("Catalog::RefreshJob/mtg")
    end

    it "runs a refresh for the collectible type and trigger" do
      refresh = instance_double(Catalog::Refresh, call: nil)
      allow(Catalog::Refresh).to receive(:new).and_return(refresh)

      described_class.perform_now("mtg", "scheduled")

      expect(Catalog::Refresh).to have_received(:new).with("mtg", trigger: "scheduled")
    end

    it "retries transient source errors" do
      allow(Catalog::Refresh).to receive(:new).and_raise(Catalog::Sources::TransientError, "timeout")

      expect { described_class.perform_now("mtg") }.to have_enqueued_job(described_class).with("mtg")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/jobs/catalog/refresh_job_spec.rb` → FAIL (`uninitialized constant Catalog::RefreshJob`).
- [ ] Create `app/jobs/catalog/refresh_job.rb`:
  ```ruby
  class Catalog::RefreshJob < ApplicationJob
    queue_as :sync

    # A second refresh for the same type waits for the first (Catalog::RefreshRun.start! guards the edge cases).
    limits_concurrency to: 1, key: ->(collectible_type, *) { collectible_type }, duration: Catalog::RefreshRun::STALE_AFTER

    retry_on Catalog::Sources::TransientError, ActiveRecord::StatementTimeout, wait: :polynomially_longer, attempts: 3

    def perform(collectible_type, trigger = "manual")
      Catalog::Refresh.new(collectible_type, trigger:).call
    end
  end
  ```
- [ ] Run: `bin/rspec spec/jobs/catalog/refresh_job_spec.rb` → PASS.
- [ ] Commit: `feat(catalog): add refresh job limited to one run per collectible type`
- [ ] Write the failing spec `spec/config/recurring_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "config/recurring.yml", type: :config do # rubocop:disable RSpec/DescribeClass -- verifies a config file
    it "refreshes the MTG catalog weekly in production", :aggregate_failures do
      task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig("production", "refresh_mtg_catalog")

      expect(task).to include("class" => "Catalog::RefreshJob", "args" => [ "mtg", "scheduled" ], "queue" => "sync")
      expect(Fugit.parse_cronish(task["schedule"]).to_cron_s).to eq("15 3 * * 1")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/config/recurring_spec.rb` → FAIL (`task` is nil).
- [ ] Append under `production:` in `config/recurring.yml`:
  ```yaml
    refresh_mtg_catalog:
      class: Catalog::RefreshJob
      args: [ "mtg", "scheduled" ]
      queue: sync
      schedule: every monday at 3:15am
  ```
- [ ] Run: `bin/rspec spec/config/recurring_spec.rb` → PASS.
- [ ] Commit: `feat(catalog): schedule a weekly MTG catalog refresh`
- [ ] Write the failing spec `spec/tasks/catalog_rake_spec.rb`:
  ```ruby
  require "rails_helper"
  require "rake"

  RSpec.describe "catalog rake tasks", type: :task do # rubocop:disable RSpec/DescribeClass -- rake tasks have no class
    before { Rails.application.load_tasks unless Rake::Task.task_defined?("catalog:refresh") }

    after { %w[catalog:refresh catalog:status].each { |name| Rake::Task[name].reenable } }

    describe "catalog:refresh" do
      it "queues a manual refresh without waiting for it" do
        expect { Rake::Task["catalog:refresh"].invoke("mtg") }
          .to have_enqueued_job(Catalog::RefreshJob).with("mtg", "manual")
          .and output(/Queued mtg catalog refresh/).to_stdout
      end

      it "rejects an unknown collectible type" do
        expect { Rake::Task["catalog:refresh"].invoke("pokemon") }.to raise_error(ArgumentError, /pokemon/)
      end
    end

    describe "catalog:status" do
      it "lists the 10 most recent runs, newest first, with counts and messages", :aggregate_failures do
        11.times { |i| create(:catalog_refresh_run, started_at: (20 - i).hours.ago, source_version: "v#{i}") }
        create(:catalog_refresh_run, status: "failed", started_at: 1.minute.ago, message: "IntegrityError: short file")

        lines = capture_stdout { Rake::Task["catalog:status"].invoke("mtg") }.lines

        expect(lines.size).to eq(10)
        expect(lines.first).to include("failed", "IntegrityError: short file", "seen=0", "malformed=0")
        expect(lines.second).to include("v10", "applied", "scheduled")
      end

      it "says when there are no runs" do
        expect { Rake::Task["catalog:status"].invoke("mtg") }.to output(/No mtg refresh runs yet/).to_stdout
      end
    end

    def capture_stdout
      original = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original
    end
  end
  ```
- [ ] Run: `bin/rspec spec/tasks/catalog_rake_spec.rb` → FAIL (`Don't know how to build task 'catalog:refresh'`).
- [ ] Create `lib/tasks/catalog.rake`:
  ```ruby
  namespace :catalog do
    desc 'Queue a background catalog refresh (default mtg): bin/rails "catalog:refresh[mtg]"'
    task :refresh, [ :collectible_type ] => :environment do |_task, args|
      collectible_type = args[:collectible_type] || "mtg"
      Catalog.source_class(collectible_type)
      Catalog::RefreshJob.perform_later(collectible_type, "manual")
      puts %(Queued #{collectible_type} catalog refresh. Check progress with: bin/rails "catalog:status[#{collectible_type}]")
    end

    desc 'Show the 10 most recent catalog refresh runs (default mtg): bin/rails "catalog:status[mtg]"'
    task :status, [ :collectible_type ] => :environment do |_task, args|
      collectible_type = args[:collectible_type] || "mtg"
      runs = Catalog::RefreshRun.for_type(collectible_type).recent.limit(10)
      puts "No #{collectible_type} refresh runs yet." if runs.none?
      runs.each { |run| puts run.status_line }
    end
  end
  ```
- [ ] Run: `bin/rspec spec/tasks/catalog_rake_spec.rb` → PASS.
- [ ] Commit: `feat(catalog): add catalog refresh and status commands`
- [ ] Docs and deployment config (AC-4.1, AC-5.3, AC-6.5):
  - `compose.yaml` → under `environment:` add `COLLECTOR_MTG_LANGUAGES: "${COLLECTOR_MTG_LANGUAGES:-}"`, and add `# Optional: COLLECTOR_MTG_LANGUAGES (extra card languages, e.g. "ja,de")` to the header comment.
  - `config/deploy.yml` → under `env.clear` add the comment `# COLLECTOR_MTG_LANGUAGES: ja   # extra Scryfall languages; English is always included`. Under `aliases` add:
    ```yaml
      catalog-refresh: app exec --reuse "bin/rails 'catalog:refresh[mtg]'"
      catalog-status: app exec --reuse "bin/rails 'catalog:status[mtg]'"
    ```
  - `README.md` → new section `## Card catalog` before `## License`, covering:
    - Data comes from Scryfall bulk data and is cached locally; the app never calls Scryfall while rendering pages.
    - The catalog is **empty until the first refresh**. After first deploy, run the manual refresh: locally `bin/rails "catalog:refresh[mtg]"`; Compose `docker compose exec web bin/rails "catalog:refresh[mtg]"`; Kamal `bin/kamal catalog-refresh`.
    - Weekly schedule (Mondays 03:15 server time, production). A scheduled run is skipped when that Scryfall file and language set were already applied; a manual run always applies.
    - `bin/rails "catalog:status[mtg]"` (Kamal: `bin/kamal catalog-status`) lists the last 10 runs.
    - `COLLECTOR_MTG_LANGUAGES`: comma-separated, case-insensitive, default English only. English is always included. Accepted codes: `en es fr de it pt ja ko ru zhs zht he la grc ar sa ph qya`. Changes take effect at the next refresh. Removed languages' printings are retired, not deleted. An invalid code fails the refresh before downloading.
    - Disk: downloads live in `storage/catalog/mtg/` on the persistent volume. The two newest are kept (~80 MB each English-only via `default_cards`, ~400 MB each with other languages via `all_cards`). They can be re-downloaded, so they don't need backing up.
    - Card data and images © Wizards of the Coast, provided by Scryfall; the app follows Scryfall's API guidelines.
    - Add `COLLECTOR_MTG_LANGUAGES` to the Compose variables table.
- [ ] Commit: `docs: document the card catalog refresh, languages and schedule`

---

## Phase 6: Card search page

**Implements:** FR-7 | **Satisfies:** AC-1.1–AC-1.14, AC-2.1–AC-2.4, AC-3.6 (search)
**Files:** `config/routes.rb`, `app/models/catalog/set.rb` (scopes), `app/models/catalog/pagination.rb`, `app/models/catalog/search.rb`, `app/models/catalog/entry.rb` (`.preload_extensions`), `app/controllers/catalog/entries_controller.rb`, `app/helpers/catalog_helper.rb`, `app/views/catalog/entries/{index,_group,_summary}.html.erb`, `app/views/catalog/_pagination.html.erb`, `app/views/mtg/printings/_summary.html.erb`, `app/views/home/index.html.erb`, `app/assets/stylesheets/application.css`, `spec/models/catalog/search_spec.rb`, `spec/requests/catalog/entries_search_spec.rb`, `spec/system/catalog_search_spec.rb`
**Interfaces:** Consumes: Phase 2 models, `Catalog.source_class`, `Catalog.allowed_hosts`. Produces:
- `Catalog::Pagination.for(total_count:, requested_page:, per_page:)` with `#page`, `#total_pages`, `#offset`, `#previous_page`, `#next_page`, `#total_count`.
- `Catalog::Search.new(query:, set_code:, page:)` with `#query`, `#set_code`, `#active?`, `#pagination`, `#groups` → `Array<Catalog::Search::Group(identity, entries, total_entries)>`.
- `Catalog::Entry.preload_extensions(entries)`.
- `Catalog::Set` scopes `with_searchable_entries`, `newest_first`.
- Helpers `catalog_url(url)` and `render_catalog_extension(entry, part)`.
- Routes `catalog_entries_path`, `catalog_entry_path(entry)`, `catalog_identity_path(identity, set:)`.

- [ ] Write the failing spec `spec/models/catalog/search_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Catalog::Search, type: :model do
    def printing(name, identity: create(:catalog_identity, name:), **attributes)
      create(:catalog_entry, identity:, name:, **attributes)
    end

    it "is inactive for a blank or whitespace query without a set", :aggregate_failures do
      expect(described_class.new(query: "   ")).not_to be_active
      expect(described_class.new(query: "   ").groups).to eq([])
    end

    it "groups every searchable printing of each matching card, newest first", :aggregate_failures do
      bolt = create(:catalog_identity, name: "Lightning Bolt")
      en = printing("Lightning Bolt", identity: bolt, released_on: Date.new(2009, 7, 17))
      ja = printing("Lightning Bolt", identity: bolt, language: "ja", localized_name: "稲妻", released_on: Date.new(2022, 1, 1))

      groups = described_class.new(query: "稲妻").groups

      expect(groups.map(&:identity)).to eq([ bolt ])
      expect(groups.first.entries).to eq([ ja, en ])
    end

    it "caps a group at 10 printings and reports the total", :aggregate_failures do
      forest = create(:catalog_identity, name: "Forest")
      11.times { printing("Forest", identity: forest) }

      group = described_class.new(query: "forest").groups.first

      expect(group.entries.size).to eq(10)
      expect(group.total_entries).to eq(11)
    end

    it "sorts cards by name and pages 12 at a time", :aggregate_failures do
      13.times { |i| printing(format("Card %02d", i)) }

      expect(described_class.new(query: "card").groups.map { |group| group.identity.name }.first).to eq("Card 00")
      expect(described_class.new(query: "card", page: "2").groups.map { |group| group.identity.name }).to eq([ "Card 12" ])
    end

    it "clamps invalid pages to the first or last page", :aggregate_failures do
      13.times { |i| printing("Card #{i}") }

      expect(described_class.new(query: "card", page: "0").pagination.page).to eq(1)
      expect(described_class.new(query: "card", page: "abc").pagination.page).to eq(1)
      expect(described_class.new(query: "card", page: "99").pagination.page).to eq(2)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/search_spec.rb` → FAIL (`uninitialized constant Catalog::Search`).
- [ ] Create `app/models/catalog/pagination.rb`:
  ```ruby
  Catalog::Pagination = Data.define(:total_count, :page, :per_page) do
    # Non-numeric or non-positive pages become 1; pages past the end become the last page.
    def self.for(total_count:, requested_page:, per_page:)
      total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
      new(total_count:, per_page:, page: (Integer(requested_page.to_s, exception: false) || 1).clamp(1, total_pages))
    end

    def total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
    def offset = (page - 1) * per_page
    def previous_page = page > 1 ? page - 1 : nil
    def next_page = page < total_pages ? page + 1 : nil
  end
  ```
- [ ] Create `app/models/catalog/search.rb`:
  ```ruby
  # One page of card search results: identities with a searchable entry whose
  # name or localized name contains the query (and in the chosen set), each
  # listing its newest searchable entries in that set.
  class Catalog::Search
    PER_PAGE = 12
    ENTRIES_PER_GROUP = 10
    MAX_QUERY_LENGTH = 100

    Group = Data.define(:identity, :entries, :total_entries)

    attr_reader :query, :set_code

    def initialize(query: nil, set_code: nil, page: nil)
      @query = query.to_s.strip.first(MAX_QUERY_LENGTH)
      @set_code = set_code.presence
      @requested_page = page
    end

    def active? = query.present? || set_code.present?

    def pagination
      @pagination ||= Catalog::Pagination.for(total_count: active? ? matching_entries.distinct.count(:catalog_identity_id) : 0,
        requested_page: @requested_page, per_page: PER_PAGE)
    end

    def groups
      return [] unless active?

      @groups ||= begin
        identities = Catalog::Identity.where(id: matching_entries.select(:catalog_identity_id))
          .order(:name, :id).offset(pagination.offset).limit(PER_PAGE).to_a
        entries = Catalog::Entry.searchable.in_set(set_code).where(catalog_identity_id: identities.map(&:id))
          .newest_first.includes(:set).to_a.group_by(&:catalog_identity_id)
        identities.map do |identity|
          listed = entries.fetch(identity.id, [])
          Group.new(identity:, entries: listed.first(ENTRIES_PER_GROUP), total_entries: listed.size)
        end.tap { |groups| Catalog::Entry.preload_extensions(groups.flat_map(&:entries)) }
      end
    end

    private
      def matching_entries
        scope = Catalog::Entry.searchable.in_set(set_code)
        query.present? ? scope.named_like(query) : scope
      end
  end
  ```
- [ ] Add to `app/models/catalog/entry.rb` (after `to_param`):
  ```ruby
  # Loads each entry's collectible-specific record in one query per type.
  def self.preload_extensions(entries)
    entries.group_by(&:collectible_type).each do |collectible_type, group|
      model = Catalog.source_class(collectible_type).entry_extension_model
      next if model.nil?

      extensions = model.where(catalog_entry_id: group.map(&:id)).index_by(&:catalog_entry_id)
      group.each { |entry| entry.extension = extensions[entry.id] }
    end
    entries
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/search_spec.rb` → PASS.
- [ ] Commit: `feat(catalog): add paginated, grouped card search`
- [ ] Write the failing request spec `spec/requests/catalog/entries_search_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Card search", type: :request do
    def printing(name, identity: create(:catalog_identity, name:), **attributes)
      create(:catalog_entry, identity:, name:, **attributes)
    end

    def search(**params) = get(catalog_entries_path(params))

    it "finds cards by part of the name, ignoring case", :aggregate_failures do
      printing("Lightning Bolt")
      printing("Lightning Helix")

      search(q: "LIGHTNING bo")

      expect(response.body).to include("Lightning Bolt")
      expect(response.body).not_to include("Lightning Helix")
    end

    it "finds a card by a localized name and lists its other printings", :aggregate_failures do
      bolt = create(:catalog_identity, name: "Lightning Bolt")
      en = printing("Lightning Bolt", identity: bolt)
      ja = printing("Lightning Bolt", identity: bolt, language: "ja", localized_name: "稲妻")

      search(q: "稲妻")

      expect(response.body).to include("Lightning Bolt", "稲妻", catalog_entry_path(en), catalog_entry_path(ja))
    end

    it "shows image, set, number, language, rarity and finishes for each printing", :aggregate_failures do
      set = create(:catalog_set, code: "m10", name: "Magic 2010")
      entry = printing("Lightning Bolt", set:, number: "146",
        image_url: "https://cards.scryfall.io/normal/front/a/b/bolt.jpg")
      create(:mtg_printing, entry:, rarity: "common", finishes: %w[foil nonfoil])

      search(q: "bolt")

      expect(response.body).to include('src="https://cards.scryfall.io/normal/front/a/b/bolt.jpg"',
        "Magic 2010", "M10", "#146", "en", "Common", "foil, nonfoil")
    end

    it "does not render images from hosts outside the allowlist" do
      printing("Lightning Bolt", image_url: "https://evil.example/bolt.jpg")

      search(q: "bolt")

      expect(response.body).not_to include("evil.example")
    end

    it "links to all printings when a card has more than 10", :aggregate_failures do
      forest = create(:catalog_identity, name: "Forest")
      11.times { printing("Forest", identity: forest) }

      search(q: "forest")

      expect(response.body.scan(%r{href="/catalog/entries/}).size).to eq(10)
      expect(response.body).to include("Show all 11 printings", catalog_identity_path(forest))
    end

    it "pages 12 cards at a time", :aggregate_failures do
      13.times { |i| printing(format("Card %02d", i)) }

      search(q: "card")
      expect(response.body).to include("Card 11", 'rel="next"')
      expect(response.body).not_to include("Card 12")

      search(q: "card", page: 2)
      expect(response.body).to include("Card 12", 'rel="prev"')
    end

    it "falls back to the first or last page for invalid page numbers", :aggregate_failures do
      13.times { |i| printing(format("Card %02d", i)) }

      search(q: "card", page: "abc")
      expect(response.body).to include("Page 1 of 2")

      search(q: "card", page: 99)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Page 2 of 2")
    end

    it "says no cards were found", :aggregate_failures do
      search(q: "nothing matches")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No cards found")
    end

    it "prompts for a name when the query is blank or whitespace" do
      search(q: "   ")

      expect(response.body).to include("Enter a card name")
    end

    it "treats wildcard characters literally" do
      printing("Fires of Yavimaya")

      search(q: "Fire_")

      expect(response.body).to include("No cards found")
    end

    it "hides tokens, emblems, art cards and retired printings", :aggregate_failures do
      printing("Goblin Token", kind: "token")
      printing("Ajani Emblem", kind: "emblem")
      printing("Goblin Art", kind: "art_card")
      printing("Goblin Retired", retired_at: 1.day.ago)

      search(q: "goblin")

      expect(response.body).to include("No cards found")
    end

    it "narrows a card's printings to the selected set", :aggregate_failures do
      bolt = create(:catalog_identity, name: "Lightning Bolt")
      a = printing("Lightning Bolt", identity: bolt, set: create(:catalog_set, code: "aaa"))
      b = printing("Lightning Bolt", identity: bolt, set: create(:catalog_set, code: "bbb"))

      search(q: "bolt", set: "aaa")

      expect(response.body).to include(catalog_entry_path(a))
      expect(response.body).not_to include(catalog_entry_path(b))
    end

    it "lists every searchable card in a set when only a set is chosen" do
      set = create(:catalog_set, code: "aaa")
      printing("Alpha", set:)
      printing("Beta", set:)

      search(set: "aaa")

      expect(response.body).to include("Alpha", "Beta")
    end

    it "offers sets with searchable printings, newest first", :aggregate_failures do
      printing("Old", set: create(:catalog_set, code: "old", released_on: Date.new(1993, 1, 1)))
      printing("New", set: create(:catalog_set, code: "new", released_on: Date.new(2024, 1, 1)))
      printing("Token", kind: "token", set: create(:catalog_set, code: "tkn"))

      search

      expect(response.body.index('value="new"')).to be < response.body.index('value="old"')
      expect(response.body).not_to include('value="tkn"')
    end

    it "returns no results for an unknown set code", :aggregate_failures do
      printing("Lightning Bolt")

      search(q: "bolt", set: "nope")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No cards found")
    end

    it "says the catalog has not been loaded until a refresh has applied" do
      create(:catalog_refresh_run, status: "failed")

      search

      expect(response.body).to include("has not been loaded yet")
    end

    it "shows the date of the last applied refresh" do
      create(:catalog_refresh_run, finished_at: Time.zone.local(2026, 9, 28, 3, 20))

      search

      expect(response.body).to include("September 28, 2026")
    end

    it "makes no outbound requests while rendering" do
      printing("Lightning Bolt", image_url: "https://cards.scryfall.io/normal/front/a/b/bolt.jpg")

      search(q: "bolt")

      expect(a_request(:any, /.*/)).not_to have_been_made
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/catalog/entries_search_spec.rb` → FAIL (`undefined local variable or method 'catalog_entries_path'`).
- [ ] Add to `app/models/catalog/set.rb` (after the validations), for the set filter:
  ```ruby
  scope :with_searchable_entries, -> { where(id: Catalog::Entry.searchable.select(:catalog_set_id)) }
  scope :newest_first, -> { order(released_on: :desc, code: :asc) }
  ```
- [ ] In `config/routes.rb`, above `root`, add:
  ```ruby
  namespace :catalog do
    resources :entries, only: %i[index show], param: :external_key
    resources :identities, only: :show, param: :external_key
  end
  ```
- [ ] Create `app/controllers/catalog/entries_controller.rb`:
  ```ruby
  class Catalog::EntriesController < ApplicationController
    def index
      @search = Catalog::Search.new(query: search_params[:q], set_code: search_params[:set], page: search_params[:page])
      @groups = @search.groups
      @sets = Catalog::Set.with_searchable_entries.newest_first.to_a
      @last_refresh = Catalog::RefreshRun.last_applied
    end

    private
      def search_params = params.permit(:q, :set, :page)
  end
  ```
- [ ] Create `app/helpers/catalog_helper.rb`:
  ```ruby
  module CatalogHelper
    # Returns the URL only when it is https on a host a registered catalog source vouches for.
    def catalog_url(url)
      uri = URI.parse(url.to_s)
      url if uri.is_a?(URI::HTTPS) && Catalog.allowed_hosts.include?(uri.host)
    rescue URI::InvalidURIError
      nil
    end

    # Renders the collectible-specific partial for an entry, e.g. mtg/printings/_summary.
    def render_catalog_extension(entry, part)
      return if entry.extension.nil?

      render partial: "#{entry.extension.model_name.collection}/#{part}", locals: { extension: entry.extension }
    end
  end
  ```
- [ ] Create `app/views/catalog/entries/index.html.erb`:
  ```erb
  <% content_for :title, "Card search · Collector" %>
  <main class="catalog">
    <h1>Card search</h1>

    <% if @last_refresh %>
      <p class="catalog__freshness">Catalog last updated <%= l(@last_refresh.finished_at.to_date, format: :long) %>.</p>
    <% else %>
      <p class="catalog__notice">The card catalog has not been loaded yet.</p>
    <% end %>

    <%= form_with url: catalog_entries_path, method: :get, class: "catalog-search" do |form| %>
      <%= form.label :q, "Card name" %>
      <%= form.search_field :q, value: @search.query %>
      <%= form.label :set, "Set" %>
      <%= form.select :set, options_for_select(@sets.map { |set| [ "#{set.name} (#{set.code.upcase})", set.code ] }, @search.set_code),
            include_blank: "All sets" %>
      <%= form.submit "Search", name: nil %>
    <% end %>

    <% if !@search.active? %>
      <p>Enter a card name to search the catalog.</p>
    <% elsif @groups.empty? %>
      <p>No cards found.</p>
    <% else %>
      <p><%= pluralize(@search.pagination.total_count, "card") %> found.</p>
      <%= render partial: "catalog/entries/group", collection: @groups, locals: { set_code: @search.set_code } %>
      <%= render "catalog/pagination", pagination: @search.pagination, link_params: { q: @search.query.presence, set: @search.set_code } %>
    <% end %>
  </main>
  ```
- [ ] Create `app/views/catalog/entries/_group.html.erb`:
  ```erb
  <section class="catalog-group">
    <h2><%= group.identity.name %></h2>
    <ul class="catalog-printings">
      <% group.entries.each do |entry| %>
        <li><%= render "catalog/entries/summary", entry: %></li>
      <% end %>
    </ul>
    <% if group.total_entries > group.entries.size %>
      <%= link_to "Show all #{group.total_entries} printings", catalog_identity_path(group.identity, set: set_code) %>
    <% end %>
  </section>
  ```
- [ ] Create `app/views/catalog/entries/_summary.html.erb`:
  ```erb
  <%= link_to catalog_entry_path(entry), class: "catalog-printing" do %>
    <% if catalog_url(entry.image_url) %>
      <%= image_tag catalog_url(entry.image_url), alt: entry.name, loading: "lazy", width: 146, height: 204 %>
    <% end %>
    <span class="catalog-printing__name"><%= entry.localized_name || entry.name %></span>
    <span><%= entry.set.name %> (<%= entry.set.code.upcase %>) #<%= entry.number %> · <%= entry.language %></span>
    <%= render_catalog_extension entry, :summary %>
  <% end %>
  ```
- [ ] Create `app/views/mtg/printings/_summary.html.erb`:
  ```erb
  <span class="mtg-printing__meta"><%= extension.rarity.humanize %> · <%= extension.finishes.join(", ") %></span>
  ```
- [ ] Create `app/views/catalog/_pagination.html.erb`:
  ```erb
  <nav class="catalog-pagination" aria-label="Pagination">
    <% if pagination.previous_page %>
      <%= link_to "Previous", url_for(link_params.merge(page: pagination.previous_page)), rel: "prev" %>
    <% end %>
    <span>Page <%= pagination.page %> of <%= pagination.total_pages %></span>
    <% if pagination.next_page %>
      <%= link_to "Next", url_for(link_params.merge(page: pagination.next_page)), rel: "next" %>
    <% end %>
  </nav>
  ```
- [ ] Append to `app/assets/stylesheets/application.css`:
  ```css
  .catalog { max-width: 72rem; margin: 0 auto; padding: 1rem; font-family: system-ui, sans-serif; }
  .catalog-search { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin: 1rem 0; }
  .catalog-printings { list-style: none; padding: 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(10rem, 1fr)); gap: 1rem; }
  .catalog-printing { display: flex; flex-direction: column; gap: 0.25rem; color: inherit; text-decoration: none; }
  .catalog-printing img { width: 100%; height: auto; border-radius: 4.75% / 3.5%; }
  .catalog-pagination { display: flex; gap: 1rem; margin: 1rem 0; }
  .catalog__notice { padding: 0.5rem 1rem; background: #fff4d6; border-left: 4px solid #e0a800; }
  ```
- [ ] In `app/views/home/index.html.erb` add `<p><%= link_to "Search cards", catalog_entries_path %></p>` after the tagline.
- [ ] Run: `bin/rspec spec/requests/catalog/entries_search_spec.rb spec/requests/home_spec.rb` → PASS.
- [ ] Commit: `feat(catalog): add public card search page`
- [ ] Write the system spec `spec/system/catalog_search_spec.rb` (no image URLs, so the browser makes no external requests):
  ```ruby
  require "rails_helper"

  RSpec.describe "Card search", type: :system do
    it "finds a card and opens a printing", :aggregate_failures do
      set = create(:catalog_set, code: "m10", name: "Magic 2010")
      entry = create(:catalog_entry, set:, name: "Lightning Bolt", identity: create(:catalog_identity, name: "Lightning Bolt"))
      create(:mtg_printing, entry:)

      visit catalog_entries_path
      fill_in "Card name", with: "bolt"
      click_on "Search"

      expect(page).to have_css("h2", text: "Lightning Bolt")
      click_on "Lightning Bolt"
      expect(page).to have_css("h1", text: "Lightning Bolt")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/system/catalog_search_spec.rb` → FAIL until Phase 7 adds the detail page (`The action 'show' could not be found`). Commit it with Phase 7.

---

## Phase 7: Printing detail and card printings pages

**Implements:** FR-8, FR-10 | **Satisfies:** AC-3.1–AC-3.6, AC-10.1–AC-10.3
**Files:** `app/controllers/catalog/entries_controller.rb` (`show`), `app/controllers/catalog/identities_controller.rb`, `app/views/catalog/entries/show.html.erb`, `app/views/catalog/identities/show.html.erb`, `app/views/mtg/printings/_details.html.erb`, `spec/requests/catalog/entries_show_spec.rb`, `spec/requests/catalog/identities_spec.rb`, `spec/system/catalog_search_spec.rb`
**Interfaces:** Consumes: Phase 6 routes, helpers, pagination, `preload_extensions`. Produces: `GET /catalog/entries/:external_key`, `GET /catalog/identities/:external_key?set=&page=`.

- [ ] Write the failing spec `spec/requests/catalog/entries_show_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Printing detail", type: :request do
    let(:set) { create(:catalog_set, code: "neo", name: "Kamigawa: Neon Dynasty", released_on: Date.new(2022, 2, 18)) }
    let(:identity) { create(:catalog_identity, name: "Azusa's Many Journeys // Likeness of the Seeker") }
    let(:entry) do
      create(:catalog_entry, external_key: "ec725e92", set:, identity:, number: "172", language: "ja",
        localized_name: "梓の幾多の旅 // 探求者の肖像", released_on: Date.new(2022, 2, 18))
    end

    before do
      create(:mtg_printing, entry:, rarity: "uncommon", finishes: %w[foil nonfoil],
        scryfall_uri: "https://scryfall.com/card/neo/172/ja/azusa",
        faces: [
          { "name" => "Azusa's Many Journeys", "printed_name" => "梓の幾多の旅", "mana_cost" => "{1}{G}",
            "type_line" => "Enchantment — Saga", "oracle_text" => "Chapter one", "artist" => "Lindsey Look",
            "image_uris" => { "large" => "https://cards.scryfall.io/large/front/e/c/ec725e92.jpg" } },
          { "name" => "Likeness of the Seeker", "printed_name" => "探求者の肖像", "mana_cost" => "",
            "type_line" => "Enchantment Creature — Human Monk", "oracle_text" => "<script>x</script>Blocked",
            "artist" => "Lindsey Look", "image_uris" => { "large" => "https://cards.scryfall.io/large/back/e/c/ec725e92.jpg" } }
        ])
    end

    it "is addressed by the Scryfall ID and shows everything about the printing", :aggregate_failures do
      get "/catalog/entries/ec725e92"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "Azusa&#39;s Many Journeys // Likeness of the Seeker", "梓の幾多の旅 // 探求者の肖像",
        "Kamigawa: Neon Dynasty", "NEO", "172", "ja", "Uncommon", "foil, nonfoil", "February 18, 2022",
        "{1}{G}", "Enchantment — Saga", "Chapter one", "Enchantment Creature — Human Monk", "Lindsey Look",
        "https://cards.scryfall.io/large/front/e/c/ec725e92.jpg", "https://cards.scryfall.io/large/back/e/c/ec725e92.jpg")
    end

    it "escapes source text" do
      get catalog_entry_path(entry)

      expect(response.body).not_to include("<script>x</script>")
    end

    it "links to Scryfall with attribution and to the card's printings", :aggregate_failures do
      get catalog_entry_path(entry)

      expect(response.body).to include('href="https://scryfall.com/card/neo/172/ja/azusa"', "provided by Scryfall",
        catalog_identity_path(identity), catalog_entries_path(q: identity.name))
    end

    it "renders a retired printing with a notice", :aggregate_failures do
      entry.update!(retired_at: 1.day.ago)

      get catalog_entry_path(entry)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("no longer present in the upstream source")
    end

    it "returns 404 for an unknown Scryfall ID" do
      get "/catalog/entries/does-not-exist"

      expect(response).to have_http_status(:not_found)
    end

    it "makes no outbound requests while rendering" do
      get catalog_entry_path(entry)

      expect(a_request(:any, /.*/)).not_to have_been_made
    end
  end
  ```
- [ ] Write the failing spec `spec/requests/catalog/identities_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Card printings", type: :request do
    let(:forest) { create(:catalog_identity, name: "Forest", external_key: "oracle-forest") }

    it "lists printings newest first, 12 per page", :aggregate_failures do
      entries = Array.new(25) { |i| create(:catalog_entry, identity: forest, released_on: Date.new(2000, 1, 1) + i) }

      get catalog_identity_path(forest)

      expect(response.body).to include("Forest", "Page 1 of 3")
      expect(response.body.index(catalog_entry_path(entries.last))).to be < response.body.index(catalog_entry_path(entries[-2]))
      expect(response.body.scan(%r{href="/catalog/entries/}).size).to eq(12)
    end

    it "keeps a set filter and offers to show all sets", :aggregate_failures do
      a = create(:catalog_entry, identity: forest, set: create(:catalog_set, code: "aaa"))
      b = create(:catalog_entry, identity: forest, set: create(:catalog_set, code: "bbb"))

      get catalog_identity_path(forest, set: "aaa")

      expect(response.body).to include(catalog_entry_path(a), "Show all sets")
      expect(response.body).not_to include(catalog_entry_path(b))
    end

    it "returns 404 for an unknown card" do
      get "/catalog/identities/nope"

      expect(response).to have_http_status(:not_found)
    end

    it "makes no outbound requests while rendering" do
      create(:catalog_entry, identity: forest, image_url: "https://cards.scryfall.io/normal/front/a/b/forest.jpg")

      get catalog_identity_path(forest)

      expect(a_request(:any, /.*/)).not_to have_been_made
    end

    it "returns 404 for a card without searchable printings" do
      create(:catalog_entry, :retired, identity: forest)

      get catalog_identity_path(forest)

      expect(response).to have_http_status(:not_found)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/catalog/entries_show_spec.rb spec/requests/catalog/identities_spec.rb` → FAIL (missing actions).
- [ ] Add `show` to `app/controllers/catalog/entries_controller.rb`:
  ```ruby
  def show
    @entry = Catalog::Entry.includes(:set, :identity).find_by!(external_key: params[:external_key])
    Catalog::Entry.preload_extensions([ @entry ])
    @printings_listed = @entry.identity.entries.searchable.exists?
  end
  ```
- [ ] Create `app/controllers/catalog/identities_controller.rb`:
  ```ruby
  class Catalog::IdentitiesController < ApplicationController
    PER_PAGE = 12

    def show
      @identity = Catalog::Identity.find_by!(external_key: params[:external_key])
      raise ActiveRecord::RecordNotFound unless @identity.entries.searchable.exists?

      @set_code = printing_params[:set].presence
      scope = @identity.entries.searchable.in_set(@set_code)
      @pagination = Catalog::Pagination.for(total_count: scope.count, requested_page: printing_params[:page], per_page: PER_PAGE)
      @entries = Catalog::Entry.preload_extensions(
        scope.newest_first.includes(:set).offset(@pagination.offset).limit(PER_PAGE).to_a)
    end

    private
      def printing_params = params.permit(:set, :page)
  end
  ```
- [ ] Create `app/views/catalog/entries/show.html.erb`:
  ```erb
  <% content_for :title, "#{@entry.name} · Collector" %>
  <main class="catalog">
    <p><%= link_to "Search for #{@entry.identity.name}", catalog_entries_path(q: @entry.identity.name) %></p>
    <h1><%= @entry.name %></h1>
    <% if @entry.localized_name %>
      <p lang="<%= @entry.language %>"><%= @entry.localized_name %></p>
    <% end %>

    <% if @entry.retired? %>
      <p class="catalog__notice">This printing is no longer present in the upstream source.</p>
    <% end %>

    <dl>
      <dt>Set</dt><dd><%= @entry.set.name %> (<%= @entry.set.code.upcase %>)</dd>
      <dt>Collector number</dt><dd><%= @entry.number %></dd>
      <dt>Language</dt><dd><%= @entry.language %></dd>
      <dt>Released</dt><dd><%= @entry.released_on ? l(@entry.released_on, format: :long) : "Unknown" %></dd>
    </dl>

    <% if @entry.extension %>
      <%= render_catalog_extension @entry, :details %>
    <% elsif catalog_url(@entry.image_url) %>
      <%= image_tag catalog_url(@entry.image_url), alt: @entry.name %>
    <% end %>

    <% if @printings_listed %>
      <p><%= link_to "All printings of #{@entry.identity.name}", catalog_identity_path(@entry.identity) %></p>
    <% end %>
  </main>
  ```
- [ ] Create `app/views/mtg/printings/_details.html.erb`:
  ```erb
  <dl>
    <dt>Rarity</dt><dd><%= extension.rarity.humanize %></dd>
    <dt>Finishes</dt><dd><%= extension.finishes.join(", ") %></dd>
  </dl>

  <% extension.faces.each do |face| %>
    <section class="mtg-face">
      <% image = catalog_url(face.dig("image_uris", "large") || face.dig("image_uris", "normal")) %>
      <% if image %>
        <%= image_tag image, alt: face["name"], loading: "lazy", width: 336, height: 468 %>
      <% end %>
      <h2><%= face["name"] %></h2>
      <% if face["printed_name"] %>
        <p><%= face["printed_name"] %></p>
      <% end %>
      <p><%= face["mana_cost"] %></p>
      <p><%= face["type_line"] %></p>
      <%= simple_format(h(face["oracle_text"])) %>
      <p>Illustrated by <%= face["artist"] %></p>
    </section>
  <% end %>

  <p>
    Card data and images provided by Scryfall.
    <% if catalog_url(extension.scryfall_uri) %>
      <%= link_to "View on Scryfall", catalog_url(extension.scryfall_uri) %>
    <% end %>
  </p>
  ```
- [ ] Create `app/views/catalog/identities/show.html.erb`:
  ```erb
  <% content_for :title, "#{@identity.name} printings · Collector" %>
  <main class="catalog">
    <p><%= link_to "Back to search", catalog_entries_path(q: @identity.name) %></p>
    <h1><%= @identity.name %></h1>
    <% if @set_code %>
      <p><%= link_to "Show all sets", catalog_identity_path(@identity) %></p>
    <% end %>

    <ul class="catalog-printings">
      <% @entries.each do |entry| %>
        <li><%= render "catalog/entries/summary", entry: %></li>
      <% end %>
    </ul>

    <%= render "catalog/pagination", pagination: @pagination, link_params: { set: @set_code } %>
  </main>
  ```
- [ ] Run: `bin/rspec spec/requests/catalog spec/system/catalog_search_spec.rb` → PASS.
- [ ] Commit: `feat(catalog): add printing detail and card printings pages`

---

## Phase 8: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] `bin/rails zeitwerk:check` → `All is good!`; `bin/ci` → green (RuboCop, Brakeman with 0 warnings, bundler-audit, importmap audit, RSpec).
- [ ] AC-9.4: `grep -rnE 'Mtg::|Catalog::Sources::Scryfall' CLAUDE.md .claude/rules .claude/memory/steering` → no output. AC-9.3: `grep -rniE 'scryfall|mtg' app/models/catalog app/models/catalog.rb app/controllers/catalog app/views/catalog` → matches only in comments naming `MTG::Scryfall::Source` as an example.
- [ ] Manual NFR checks against real Scryfall data, in development (the dev server runs jobs in Puma):
  - `bin/rails "catalog:refresh[mtg]"` then `bin/rails "catalog:status[mtg]"` until `applied`. Record the duration.
  - For peak memory, run the job in the foreground: `/usr/bin/time -v bin/rails runner 'Catalog::Refresh.new("mtg", trigger: "manual").call'` → "Maximum resident set size" < 1 GB. Repeat with `COLLECTOR_MTG_LANGUAGES=ja`.
  - Run the same command again → status line shows `inserted=0 updated=0` (AC-7.1 on real data).
  - Search latency: `bin/rails runner 'puts Benchmark.realtime { 20.times { Catalog::Search.new(query: "forest").groups } } / 20'` < 0.5 s. Spot-check `/catalog/entries?q=bolt` timing in the server log (< 500 ms).
  - Search "稲妻" (with `ja`), open a DFC printing, then a retired one (retire one by hand in the console).
- [ ] Walk every AC in `spec.md` and note evidence; then run `sdd-superpowers:sdd-review` (implementation mode).
- [ ] Commit any fixes found, one Conventional Commit per fix.
- [ ] Update `CLAUDE.md` "Project Status" (it says no domain features yet) to mention the catalog, the Scryfall refresh, and card search. Commit: `docs: update CLAUDE.md for the card catalog`

---

## Quickstart Validation

```bash
bin/rails db:migrate
bin/rspec                                          # all green, no network
bin/dev                                            # server + Solid Queue in Puma
bin/rails "catalog:refresh[mtg]"                   # queues a manual refresh (~80 MB download)
bin/rails "catalog:status[mtg]"                    # … running → applied, with counts
open http://localhost:3000/catalog/entries?q=lightning+bolt
COLLECTOR_MTG_LANGUAGES=ja bin/rails "catalog:refresh[mtg]"   # adds Japanese printings (all_cards, ~400 MB)
```

## Gates

- **Simplicity:** 3 components (catalog models, refresh pipeline, search UI). No new gems: the stdlib covers HTTP, gzip, JSON and digests; pagination is hand-rolled (≈10 lines) rather than adding a pagination gem. ✓
- **Anti-abstraction:** Active Record models are used directly. Source records are plain `Data` value objects crossing one boundary (adapter → refresh), and there are no DTO chains. The `Catalog::Sources` contract exists because FR-1/AC-9.3 require the core to be source-agnostic. ✓
- **Integration-first:** the contract is fixed in 3a and exercised by `FakeCatalogSource` (core) and the real adapter (end-to-end). Every implementation step is preceded by a failing spec. ✓

> **Complexity note (Phase 4):** `upsert_all`/`update_all` skip model validations (omakase leaves `Rails/SkipsModelValidations` disabled, so no inline disables are needed). This is justified by FR-4 (only changed rows are written, in short batched transactions, for ~100k–200k rows) and the SQLite write-transaction rule. The rows are global catalog data (no tenant scope). Integrity is enforced by NOT NULL columns, unique indexes and foreign keys.

## Risks

- **Scryfall format drift:** the mapper uses `fetch` for required fields, so a changed field makes records Malformed (counted and logged) rather than corrupting data. If a run reports a high `malformed=` count, investigate before the next run.
- **`upsert_all … returning:` on SQLite** needs SQLite ≥ 3.35 (the bundled version is 3.53.2). ✓
- **Truncated-but-valid upstream file:** would retire many printings. Retirement is reversible (restore on reappearance), and the spec doesn't require a threshold guard, so no guard is added.
- **Solid Queue concurrency semaphore expiry (6 h):** covered by the `start!` DB guard.

## Plan Changelog

| Date | Change |
|------|--------|
| 2026-09-29 | Plan review (Fable) fixes: AC-9.1 regex (`finishes`, not `finish`); time helpers support file; `RSpec/ExampleLength` max 15 and random spec order (Phase 1); malformed records count as seen; zero-valid-records run fails without retirements; "already running" skip logged via `finish!`; Phase 2 reordered so every scope/method follows its failing spec; Set scopes moved to Phase 6; detail page links to a search for the card; identities page no-outbound test; Kamal alias quoting; 7-hour stale boundary in spec; CLAUDE.md status update in Phase 8. |
