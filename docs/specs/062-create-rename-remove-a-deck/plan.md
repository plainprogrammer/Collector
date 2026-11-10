# Plan 062: Create, rename and remove a deck

**Spec:** [spec.md](spec.md) v0.5.0 (Approved) · **ADR:** [0028](../../adr/0028-decks-are-locations-with-zones.md) · **Issue:** [#49](https://github.com/plainprogrammer/Collector/issues/49)
**Plan version:** 0.1.0 (2026-11-10) · **Status:** Draft, for Gate B

## Goal

A collector creates, renames and removes decks from a Decks page in the main navigation; a deck is a `locations` row of kind `deck` with `decks` data and child `locations` rows for its zones; every existing surface keeps listing places only, and a lot in a zone is shown as "Deck › Zone" and never silently unplaced; export format version 4 carries decks and zones, and the import previews and applies them, including the two refusals of an older file (maintainer D7).

## How to read this plan

- **Order.** Phases 1–2 build the records, the seam and the domain objects with no page. Phase 3 builds the pages. Phase 4 is the places-only audit and the label (D6). Phase 5 is the format (version 4, document, schema, examples, export). Phase 6 is the import (reader, plan, apply). Phase 7 is the guards, documents and the round trip. Each task is one TDD commit: a failing example first (run it, see it fail for the right reason), then the code, then green, then `bin/rubocop` on the touched files.
- **Batches.** Tasks are handed to a Sonnet implementer in the batches of the table below (2–4 consecutive tasks, one commit per task, plan.md read by line range). The supervisor checks each batch's diff before the next. Only targeted `bin/rspec <file>` runs happen in batches; the full `bin/ci` runs once, after the last batch, with a CI slot asked first.
- **Spec criteria.** A task names the criteria it satisfies. A criterion's examples are named in the task as `it` descriptions beginning with the criterion's number; the code shown is the shape, and an implementer may add examples but never drops one.
- **Examples that already pass.** Where D6 asks for "a failing example first for each unsafe path", T11–T14 list every path. An example for a path that is already safe is written first too and is marked *characterisation*: it passes at once and stays as the guard. An example for an unsafe path must be seen failing before its fix; the commit body says which.
- **Core guard.** Files named in T22's `spec/deck_core_spec.rb` list never name `mtg`, `scryfall`, `magic`, MTG's eight format keys or the zone keys `sideboard` and `commander` (in comments either). The only zone key core code names is `considering`. The format seam's comment says "a collectible" and "a game", never a game's name.
- **Comments.** Every new public class, module or method has a YARD summary (`.claude/rules/code-documentation.md`; the ratchet fails `bin/ci checks` otherwise), the why, and `@see file:…` for area docs.
- **Avoid.** `bin/rails console/dbconsole/db:rollback/db:migrate:down/db:seed`, `sqlite3`, `bundle update/add`, editing `Dockerfile`, `config/deploy*.yml`, `.github/workflows/**`, reading `.kamal/secrets`, `config/master.key`, `.env*`, `storage/`. Migration reversibility is proved with `bin/rails db:migrate:redo:primary`, and the Solid Queue schema noise is restored after migrating (`.claude/memory/migrate-schema-noise.md`). Never run two test runs at once (shared test database).

### Batches

| Batch | Tasks | Delivers |
|---|---|---|
| B1 | T1, T2, T3 | migration and schema, `Location` and `Account`, the format seam |
| B2 | T4, T5 | `Deck`, creation, rename, removal, holdings; `Lot` validation, `Location::Placement`, the label |
| B3 | T6, T7, T8 | routes, Decks page, navigation; New deck; Rename |
| B4 | T9, T10 | removal and refusal pages; locations routes answer places only |
| B5 | T11, T12 | the lot, move and bulk-move surfaces list places only; number entry, scanner, filter, bulk removal |
| B6 | T13, T14, T15 | the label everywhere; Edit copy read-only and the gates; the unsafe-path examples |
| B7 | T16, T17 | export rules v4, schema and the document's examples; the format document |
| B8 | T18, T19 | export v4; the reader (decks, refusals, rows) |
| B9 | T20, T21 | plan, fingerprint, preview page, notice; the apply |
| B10 | T22, T23 | round trip, bounds, upgrade proof; guards, documents, indexes |

## File structure

New:

| File | Responsibility |
|---|---|
| `db/migrate/20261110200001_add_decks.rb` | kind, parent_id, zone, the `decks` table, the indexes; reversible while no deck exists |
| `app/models/deck.rb` | one deck's data (`account`, `location`, `collectible_type`, `format`), rename, remove |
| `app/models/deck/creation.rb` | the New deck form's object: checks the name and format, writes the deck and its zones in one transaction |
| `app/models/deck/listing.rb` | the Decks page's rows and counts in a bounded number of queries |
| `app/models/catalog/formats.rb` | the format seam: the contract, lookups, the boot check |
| `app/models/location/placement.rb` | how a lot's place is written in a file, keyed and resolved (one definition) |
| `app/models/collection_import/decks.rb` | what applying a file would do with decks (the `Locations` sibling) |
| `app/models/collection_import/deck_changes.rb` | writes the decks' and places' removals, additions and zones for the apply |
| `app/controllers/decks_controller.rb`, `app/controllers/decks/removals_controller.rb` | the pages |
| `app/views/decks/{index,new,edit}.html.erb`, `app/views/decks/removals/{new,refused}.html.erb`, `app/views/icons/_decks.html.erb`, `app/views/collections/import_previews/_decks.html.erb` | views |
| `app/helpers/decks_helper.rb` | the Decks page's words |
| `docs/export-format/v4.schema.json`, `app/models/export_format/v4.schema.json` | version 4's schema (byte-identical copies) |
| `spec/deck_core_spec.rb`, `spec/support/deck_helpers.rb`, `spec/factories/decks.rb` | guard, helpers, factory |

Changed: `Location`, `Account`, `Lot`, `Location::Holdings`, `MTG::Collecting`, `config/initializers/catalog.rb`, `config/routes.rb`, the nav partials, every reader of `account.locations` (T10–T12), the label readers (T13), `ExportFormat::Rules`, `CollectionExport`, `CollectionImport` and its parts, `Collections::ImportsController`, the preview views and helpers, the export format document and its examples, the design-system and area docs.

---

## Phase 1: Schema, records and the seam

### T1: Migration, schema and coverage rows

**Satisfies:** AC-9.1 to AC-9.4, AC-9.10 (rows). **Files:** `db/migrate/20261110200001_add_decks.rb`, `db/schema.rb`, `spec/migrations/add_decks_spec.rb` (read `spec/migrations/add_location_to_lots_spec.rb` first and follow it), `docs/export-format/README.md` (Coverage tables only), `spec/factories/decks.rb` is T4.

**Failing examples first** (`spec/migrations/add_decks_spec.rb`, built as the precedent spec builds its pre-migration database):

- *9.1* every location that existed is `kind: "place"` with null `parent_id` and `zone`, with `name`, `name_key`, timestamps and every lot's `lot_key` unchanged; `decks` is empty.
- *9.1* the old unique index on `(account_id, name_key)` is gone and a unique partial index on the same columns `WHERE parent_id IS NULL` exists; two places of one name still fail with `RecordNotUnique`; a place and a deck of one name fail the same way.
- *9.4* the named checks hold: `locations_kind_known`, `locations_parent_matches_kind`, `locations_zone_matches_kind` (insert a `deck_zone` with no parent → `ActiveRecord::StatementInvalid`; a place with a parent → same; a place with a zone → same); `decks.location_id` is unique; deleting a location deletes its `decks` row and its zones.
- *9.2* the migration is `disable_ddl_transaction!`, each step guarded (running `up` twice in a row changes nothing and does not raise), and a `lots` row and a `scanner_sittings` row pointing at a location survive `up` (the `DROP TABLE` trap).
- *9.3* `down` raises `ActiveRecord::IrreversibleMigration` while a `decks` row exists, naming the count; with none it removes the columns, the table and the new indexes and restores the old unique index.

```ruby
# Adds decks to locations (spec 062 decisions 1 and 3, ADR 0028). A deck is a location of kind "deck" plus a row of
# `decks`; a zone is a location of kind "deck_zone" whose parent is the deck. Every existing location becomes a place.
class AddDecks < ActiveRecord::Migration[8.1]
  # Same reason as AddLocationToLots: SQLite copies a table to add a constraint to it or drop a column, and with foreign
  # keys enforced inside a transaction the copy's DROP TABLE would run lots.location_id's RESTRICT and
  # scanner_sittings.location_id's SET NULL. Rails turns enforcement off for a copy only outside a transaction, so this
  # migration runs without one and every step is guarded: a run that stopped part way is finished by the next boot.
  disable_ddl_transaction!

  TOP_LEVEL = "index_locations_on_account_id_and_name_key_top_level".freeze
  ZONES = "index_locations_on_parent_id_and_name_key".freeze
  OLD = "index_locations_on_account_id_and_name_key".freeze

  def up
    # ADD COLUMN copies no table. A CHECK stated on the column is tested against every existing row (all places) and
    # kept by the schema dump when it is named; REFERENCES is accepted because the default is NULL.
    unless column_exists?(:locations, :kind)
      execute "ALTER TABLE locations ADD COLUMN kind varchar NOT NULL DEFAULT 'place' " \
              "CONSTRAINT locations_kind_known CHECK (kind IN ('place', 'deck', 'deck_zone'))"
    end
    unless column_exists?(:locations, :parent_id)
      execute "ALTER TABLE locations ADD COLUMN parent_id integer REFERENCES locations (id) ON DELETE CASCADE " \
              "CONSTRAINT locations_parent_matches_kind CHECK ((kind = 'deck_zone') = (parent_id IS NOT NULL))"
    end
    unless column_exists?(:locations, :zone)
      execute "ALTER TABLE locations ADD COLUMN zone varchar " \
              "CONSTRAINT locations_zone_matches_kind CHECK ((kind = 'deck_zone') = (zone IS NOT NULL))"
    end
    add_index :locations, :parent_id unless index_exists?(:locations, :parent_id)
    # The new guards exist before the old one goes, so no name is ever unguarded.
    unless index_name_exists?(:locations, TOP_LEVEL)
      add_index :locations, %i[account_id name_key], unique: true, where: "parent_id IS NULL", name: TOP_LEVEL
    end
    unless index_name_exists?(:locations, ZONES)
      add_index :locations, %i[parent_id name_key], unique: true, where: "parent_id IS NOT NULL", name: ZONES
    end
    remove_index :locations, name: OLD if index_name_exists?(:locations, OLD)
    create_table :decks, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :location, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :collectible_type, null: false
      t.string :format, null: false
      t.timestamps
    end
  end

  def down
    decks = table_exists?(:decks) ? select_value("SELECT COUNT(*) FROM decks").to_i : 0
    raise ActiveRecord::IrreversibleMigration, "#{decks} #{decks == 1 ? "deck exists" : "decks exist"}; remove #{decks == 1 ? "it" : "them"} before rolling back" if decks.positive?

    drop_table :decks, if_exists: true
    unless index_name_exists?(:locations, OLD)
      add_index :locations, %i[account_id name_key], unique: true, name: OLD
    end
    remove_index :locations, name: TOP_LEVEL if index_name_exists?(:locations, TOP_LEVEL)
    remove_index :locations, name: ZONES if index_name_exists?(:locations, ZONES)
    remove_index :locations, :parent_id if index_exists?(:locations, :parent_id)
    # The checks name the columns they test, so they go before the columns do.
    %w[locations_kind_known locations_parent_matches_kind locations_zone_matches_kind].each do |name|
      remove_check_constraint :locations, name: name if check_constraint_exists?(:locations, name: name)
    end
    remove_column :locations, :zone if column_exists?(:locations, :zone)
    remove_column :locations, :parent_id if column_exists?(:locations, :parent_id)
    remove_column :locations, :kind if column_exists?(:locations, :kind)
  end
end
```

`index_name_exists?` and `check_constraint_exists?` are Rails 8 schema statements. The risk in `down` (a removed column that a foreign key or a check still names, on a table copy) is the reason `bin/rails db:migrate:redo:primary` is part of the task: run it with no deck (ends with the schema it started with, `git diff db/schema.rb` empty apart from the migration version) and the implementer adapts `down` (for example `remove_foreign_key :locations, column: :parent_id` first) until it does. Run `bin/rails db:migrate` (development database), restore the cable, cache and queue schema noise, and commit `db/schema.rb` with only the `locations` and `decks` changes. Run `ruby script/upgrade/guard.rb` (no released migration is edited).

The Coverage tables of `docs/export-format/README.md` gain the rows the coverage guard demands (AC-9.10), in the table shapes already there: `decks` ("Exported: the collector's decks, as `decks`; see Decks"), and for `locations` the three new columns (`kind`: "Not exported by itself: places are `locations`, decks are `decks`"; `parent_id`: "Not exported: a zone is derived from its deck's format"; `zone`: "Exported as the `zone` of a lot's `location` object"). Run `bin/rspec spec/export_format_document_spec.rb` for the guard's own wording and match it.

**Commit:** `feat(db): add decks, kind and zones to locations (#49)`.

### T2: `Location` and `Account`

**Satisfies:** AC-1.4 (rows), AC-1.5, AC-1.6, AC-5.9, AC-9.5, AC-9.6, AC-1.7a. **Files:** `app/models/location.rb`, `app/models/account.rb`, `spec/models/location_spec.rb`, `spec/models/account_spec.rb`.

**Failing examples first:**

- *1.7a* `Location::FULL` is `"You can have at most 500 places and decks together."`; an account with 400 places and 100 decks refuses a 501st place and a 501st deck with it; zones do not count (an account with 499 top-level rows and 3 zones accepts a 500th).
- *1.5, 1.6* a place and a deck cannot share a comparison key (taken sentence); two decks may each have a zone with `name_key` "main"; one deck cannot have two.
- *9.5* a place with a `parent` or a `zone` is invalid; a deck with a `parent` or a `zone` is invalid; a `deck_zone` needs a parent that is a deck of the same account and a `zone`; a zone of a zone is invalid; a zone's `zone` key must be one of its deck's format's (skipped when the deck's registration is gone: the validation fails open there, as rename and removal do, spec Error Scenarios).
- *9.6* an account with decks and lots in zones is destroyed with no foreign key error; `spec/models/account_spec.rb`'s order check still holds (`lots` declared before `locations`; `decks` declared after `locations`).

```ruby
# in Location
KINDS = %w[place deck deck_zone].freeze
FULL = "You can have at most #{MAX_PER_ACCOUNT} places and decks together.".freeze
ZONE_SEPARATOR = " › ".freeze

belongs_to :parent, class_name: "Location", optional: true
has_many :zones, -> { where(kind: "deck_zone") }, class_name: "Location", foreign_key: :parent_id, inverse_of: :parent, dependent: nil # the foreign key cascades
has_one :deck, dependent: nil # decks.location_id cascades; the Deck model removes through the location

scope :places, -> { where(kind: "place") }
scope :decks, -> { where(kind: "deck") }
scope :zones_of_decks, -> { where(kind: "deck_zone") }
scope :top_level, -> { where(parent_id: nil) }

def place? = kind == "place"
def deck? = kind == "deck"
def zone? = kind == "deck_zone"

# "Izzet Tempo › Main" for a zone, the name for anything else: the one label wherever a lot's place is shown (spec 062 D6).
# Needs the parent loaded for a zone; lists preload it (`includes(location: :parent)`).
def label = zone? ? Placement.label(name, parent.name) : name
```

`name_is_free` becomes `where(account_id:, parent_id:, name_key:)`; `account_has_room` runs `on: :create` and only `if parent_id.nil?`, counting `where(account_id:, parent_id: nil)`. New validations `kind_is_consistent` (the rules above) and `zone_key_is_the_formats` (calls `Catalog::Formats.zones_for(deck.collectible_type, deck.format)` from T3; `nil` when unregistered). `has_many :decks` goes in `Account` after `locations`. Because `has_one :deck` and the `decks` scope share a name with different receivers (instance versus class), name the scope `decks` and keep `has_one :deck`; a spec proves `Location.decks` and `location.deck` both work.

`Location::Placement` is T5; `label` for a zone refers to it, so T2 adds `Location::Placement.label(name, deck_name) = "#{deck_name}#{Location::ZONE_SEPARATOR}#{name}"` first (the rest of that module is T5). Run `bin/rspec spec/models/location_spec.rb spec/models/location spec/models/account_spec.rb`.

**Commit:** `feat(locations): kinds, zones under decks, names scoped by parent (#49)`.

### T3: The format seam

**Satisfies:** AC-1.2 (source), FR-2, AC-9.11 (for its files). **Files:** `app/models/catalog/formats.rb`, `app/models/mtg/collecting.rb`, `config/initializers/catalog.rb`, `spec/models/catalog/formats_spec.rb`, `spec/models/mtg/collecting_formats_spec.rb`, `spec/support/other_collecting.rb` (read it; it already registers a second collectible for specs, extend it with formats).

**Failing examples first:**

- the registered formats of `"mtg"` are Casual (default), Standard, Pioneer, Modern, Legacy, Vintage, Pauper (zones Main, Sideboard, Considering, keys `main sideboard considering`) and Commander (zones Commander, Main, Considering, keys `commander main considering`), in that order, with the default Casual.
- `Catalog::Formats.find("mtg", "modern")` returns the format; `find("mtg", "x")`, `find("nope", "modern")` return nil; `find_pair("mtg/modern")` splits on the first `/` and returns an `Option` (type, format) or nil for blank, no slash, an unknown type, or a key of another type (AC-1.8).
- with a second collectible that also registers `standard`, both are found by type, and `options` groups by `Catalog.collecting_for(type).category_name` (AC-1.2); with one type, `grouped?` is false.
- `verify!` raises `ArgumentError` for: a default that isn't among the formats; two formats with one key; a repeated zone key; two zone names with one comparison key; a zone name that fails `Location::Name.fault`; a format with no `considering` zone. (Each with a fake vocabulary registered in the example and removed after.)
- a vocabulary that defines no `formats` offers none and doesn't raise.
- `Catalog::Formats::CONSIDERING` is `"considering"`.
- `zones_for("mtg", "commander")` returns the three `Zone`s in order; for an unregistered format it returns nil.

```ruby
# The deck formats collectible extensions register (spec 062 FR-2, ADR 0028). A collectible type's collecting vocabulary
# (`Catalog.collecting_for`) may answer `formats`: an array of {Format}, each with a stable `key`, a shown `name`, its
# {Zone}s in order and whether it is the type's `default`. A key is unique within its type, so two games can both have
# one named the same; the core asks here and never names a format. Zones are keys and names and an order: the core knows
# one zone key, {CONSIDERING}, because every format must have a zone for cards under consideration (the decks issue
# design), so a later change of format can move cards there.
#
# An extension contract: a vocabulary that registers formats must provide
# * `formats` returning `Array<Catalog::Formats::Format>`, with exactly one `default`,
# * for each format, `zones` with distinct keys and names that are distinct names (by comparison key) and well-formed
#   (`Location::Name`), and a zone whose key is {CONSIDERING}.
# {verify!} checks this at boot, so a bad registration fails the process, not a request.
module Catalog::Formats
  CONSIDERING = "considering".freeze
  Zone = Data.define(:key, :name)
  Format = Data.define(:key, :name, :zones, :default)
  # One choice of the New deck form: a format with the collectible type it belongs to.
  Option = Data.define(:type, :format) do
    def value = "#{type}/#{format.key}"
  end

  def self.options = Catalog.collecting.keys.flat_map { |type| formats_of(type).map { |format| Option.new(type:, format:) } }
  def self.find(type, key) = formats_of(type).find { it.key == key.to_s }
  def self.find_pair(value) = (type, key = value.to_s.split("/", 2); format = find(type, key) if key; Option.new(type:, format:) if format)
  def self.default_option = options.find { it.format.default }
  def self.zones_for(type, key) = find(type, key)&.zones
  def self.name_for(type, key) = find(type, key)&.name || key
  def self.category_name(type) = Catalog.collecting_for(type).category_name
  def self.grouped? = options.map(&:type).uniq.size > 1
  def self.verify! = (Catalog.collecting.each_key { |type| verify_type!(type) }; true)
  # (verify_type!, formats_of: private; formats_of returns [] for an unregistered type or a vocabulary without `formats`.)
end
```

`MTG::Collecting` gains `FORMATS`, a frozen table of `Format.new(...)` values and `def self.formats = FORMATS`. `MTG::Collecting` may name MTG's formats (it is the extension). In `config/initializers/catalog.rb`, after the registrations in `to_prepare`: `Catalog::Formats.verify!`. A boot-time failure example boots nothing; the spec calls `verify!` against the fake registrations.

**Commit:** `feat(catalog): the format seam, with Magic's formats and zones (#49)`.

---

## Phase 2: The domain objects

### T4: `Deck`, its creation, rename, removal and holdings

**Satisfies:** AC-1.3, AC-1.7 (model side), AC-1.8, AC-1.9, AC-1.11, AC-2.2, AC-2.3, AC-2.5, AC-3.2, AC-3.5, AC-5.9, AC-9.5. **Files:** `app/models/deck.rb`, `app/models/deck/creation.rb`, `app/models/deck/listing.rb`, `app/models/location/holdings.rb`, `spec/models/deck_spec.rb`, `spec/models/deck/creation_spec.rb`, `spec/models/deck/listing_spec.rb`, `spec/models/location/holdings_spec.rb`, `spec/factories/decks.rb`, `spec/support/deck_helpers.rb`.

**Failing examples first:**

*Creation* (`Deck::Creation.new(account:, name:, format: "mtg/modern")`): *1.3* `save` makes one `Location` (kind deck), one `Deck` (`collectible_type "mtg"`, `format "modern"`) and one zone per zone of the format, in the format's order with its key and name (`zone.created_at` order equals the format's order); *1.7/1.8* a blank, control-character, 61-character or taken name, a blank, unregistered or foreign-key format, or an account at 500 each return false with the error on `:name` (the `Location` sentences) or `:format` (`"Choose a format."`), the typed name kept (`typed`), and nothing written; *1.9* two `Creation`s with one name in the same example, the second saved after the first returns false with the taken sentence and never raises (also: simulate the racing second by creating the location between `valid?` and `save` with a stub on nothing but the database: save the second one's duplicate through `Location.insert` first); an account at 499 top-level locations that creates one place and one deck ends at 500 not 501; *1.11* a failing zone write (stub `Location.create!` to raise on the second zone, the one place where a stub is allowed because the transaction is the subject) leaves no deck, no location, no zone.

*Deck* `rename(name)`: *2.2/2.3* a case-only change saves, a name another place or deck has fails with the taken sentence, zones, format and lots unchanged; *2.5* no lot, lot key or quantity changes. `remove!`: *3.2* destroys the location, the `decks` row and the zones, no lot, place or other deck changes; *3.5* with a lot in a zone it raises `ActiveRecord::InvalidForeignKey` and leaves everything (zones and deck row) in place, which is the database's refusal when a lot lands between the check and the delete. `Deck#holdings` returns the same `Location::Holdings` shape for every zone together. `Deck#zone(key)` returns the zone's location. `Deck#format_name` falls back to the key when unregistered.

*Listing* `Deck::Listing.new(account)`: `rows` in comparison-key order; `cards` is the sum over every zone (Considering included); a deck with no copies has 0; the count of queries is the same with 1 and with 12 decks (use `spec/support/query_counting.rb`).

*Holdings* (`location.holdings` for a deck): counts lots across its zones; `listed` preloads `location: :parent`; for a place or a zone nothing changes.

```ruby
class Deck < ApplicationRecord
  belongs_to :account
  belongs_to :location
  validates :collectible_type, :format, presence: true
  validate :location_is_a_deck_of_the_account

  delegate :name, to: :location
  # Routes name a deck by its location's id (spec 062 decision 4), so a zone's or a place's id is never a deck's.
  def to_param = location_id.to_s

  def self.listing_order = joins(:location).order("locations.name_key", "locations.name")

  def zones = location.zones.order(:id)          # created together in the format's order, so id order is that order
  def zone(key) = location.zones.find_by!(zone: key)
  def holdings = location.holdings
  def format_name = Catalog::Formats.name_for(collectible_type, format)
  def rename(name) = (location.name = name; location.save)
  # One DELETE of the location: the zones and this row cascade, and a zone that holds a lot refuses it (RESTRICT), so a
  # lot placed after the caller's check is caught here, never left half removed (spec 062 AC-3.5).
  def remove! = location.destroy!
end
```

`Location::Holdings#initialize` takes the location and builds `@lots` as `Lot.where(account_id: location.account_id, location_id: location.deck? ? Location.where(parent_id: location.id).select(:id) : location.id)` (a subquery, no extra query); `listed` adds `.preload(location: :parent)`. `counts(account)` is unchanged (grouped by `location_id`; the Decks page uses `Deck::Listing`).

`spec/factories/decks.rb`: `factory :deck` with `transient { name { "Izzet Tempo" }; format { "modern" } }` and `initialize_with { Deck::Creation.new(account:, name:, format: "mtg/#{format}").tap(&:save!).deck }`, with `save!` on `Creation` raising `ActiveRecord::RecordInvalid` for a failing build. `spec/support/deck_helpers.rb`: `create_lot_in_zone(deck, zone_key, **attrs)` using `Lot.add!(account:, entry:, location: deck.zone(zone_key), **attrs)`.

**Commit:** `feat(decks): the Deck record, its creation, rename, removal and holdings (#49)`.

### T5: `Lot` and `Location::Placement`

**Satisfies:** AC-5.3, AC-6.12 (key shape), AC-5.4 (the one label). **Files:** `app/models/lot.rb`, `app/models/location/placement.rb`, `spec/models/lot_spec.rb`, `spec/models/location/placement_spec.rb`.

**Failing examples first:**

- *5.3* a `Lot` whose `location` is a deck's row is invalid with "isn't one of your locations"; a zone of the account, a place of the account and nil are valid; another account's place, deck or zone is invalid.
- `Lot#place_label` is nil unplaced, the place's name in a place, `"Izzet Tempo › Main"` in a zone.
- `Lot.key_for(…, zone.id)` ends in `|<zone.id>`, equal to a place's form (the five builders are unchanged; one example per builder in T15 proves each carries a zone).
- `Placement.written(kind:, name:, zone:, deck_name:)` is nil for a nil kind, the name for a place, `{ "deck" => deck_name, "zone" => zone }` for a zone; `Placement.key(kind:, name_key:, zone:, deck_key:)` is nil, the name key, or `[deck_key, zone]`; `Placement.file_key(value)` reads a file's `location` (String, Hash or nil) into the same value with `Location::Name.key(Location::Name.normalise(…))`; the string "Box" and the pair `["box","main"]` are different keys (AC-6.12); `Placement.label(name, deck_name)` is the joined form.

```ruby
# How a lot's place is written in an export file and how it is keyed, as one definition (spec 062 decisions 1 and 4).
# A file writes `null`, a place's name, or `{ "deck" => name, "zone" => key }`; the identity's sixth value is `nil`, a place's
# comparison key, or the pair `[deck key, zone key]`. A key and a pair never compare equal, so a place called "Box" and
# the zone "main" of a deck called "Box" are different places.
module Location::Placement
  def self.label(name, deck_name) = "#{deck_name}#{Location::ZONE_SEPARATOR}#{name}"
  def self.written(kind:, name:, zone:, deck_name:) = ...
  def self.key(kind:, name_key:, zone:, deck_key:) = ...
  def self.file_key(value) = ...
  # The location id for a key among +places+ ({ name_key => id }) and +zones+ ({ [deck_key, zone] => id }); nil for nil.
  def self.resolve(key, places:, zones:) = key.is_a?(Array) ? zones.fetch(key) : (places.fetch(key) if key)
end
```

In `Lot`: `validate :location_is_the_accounts` adds `location.deck?` to the refusal; `def place_label = location&.label`; the comment on the model says a lot sits in a place or a zone, never a deck's own row, and why the database can't state it (SQLite needs a trigger).

**Commit:** `feat(lots): a lot sits in a place or a zone, never a deck; the one place label (#49)`.

---

## Phase 3: The Decks pages

### T6: Routes, the Decks page, the navigation and the icon

**Satisfies:** AC-4.1 to AC-4.10, AC-9.7 (index). **Files:** `config/routes.rb`, `app/controllers/decks_controller.rb`, `app/views/decks/index.html.erb`, `app/helpers/decks_helper.rb`, `app/views/layouts/_appbar.html.erb`, `app/views/layouts/_tabbar.html.erb`, `app/views/icons/_decks.html.erb`, `app/assets/stylesheets/collector/additions.css` (only if a rule is needed), `spec/requests/decks_spec.rb`, `spec/system/design_system_deck_rules_spec.rb`, `spec/system/decks_spec.rb`.

First read `.claude/skills/collector-design-system/SKILL.md`, `docs/design-system/README.md` (Navigation, Decks) and `docs/design-system/components/{DecksIndex,AppHeader,TabBar,Table}.md`; the markup below follows `DecksIndex.md`.

**Failing examples first:** request (`spec/requests/decks_spec.rb`): *4.3* a collector with three decks sees `3 decks · N cards` (and "1 deck"), the rows in comparison-key order, columns Deck, Format, Cards, Owned (no Proxy), the name as plain text (no link), and Rename and Remove links named by the deck for a screen reader (`<span class="c-sr"> Izzet Tempo</span>`); *4.4* Format is the format's name (the key for an unregistered one); Cards counts Considering; a deck with no copies shows 0; *4.6* no decks: the empty sentence replaces the table and "New deck" stays; *4.7* the query count is the same with 2 and with 10 decks and lots in them; *4.8* `GET /locations` lists places only and "N locations" counts only places while a deck exists; *4.9* signed out, `GET /decks` redirects to sign in, and the open-catalog visitor's header has no Decks link; *4.10* More still has its rows and no Decks row. System (`spec/system/decks_spec.rb`, headless Firefox): *4.5* at 360px Format and Owned are hidden, the line under the name reads "Modern · 58 owned", a 60-character unbroken name wraps and the page does not scroll sideways. Header guard: *4.1, 4.2* `design_system_deck_rules_spec.rb` stops adding its own clone ("add_nav_links('Decks')" and "add_tabs('Decks')" are replaced by the app's real link, which the spec only counts); the five-link examples at 640, 719 and 720px and the tab bar's five tabs at 360px now assert the real header; the "four links" example becomes "five" and the two "can fail" examples keep their clones, which is the point of them. The layouts render with `section: :decks`.

```ruby
# config/routes.rb, after the locations block
# Decks (spec 062): a deck is a location with zones; the id in every deck URL is the deck's location id (decision 4).
resources :decks, only: %i[index new create edit update destroy] do
  resource :removal, only: :new, module: :decks
end
```

```ruby
# Spec 062: the signed-in collector's decks. Every lookup is through Current.account and by the deck's location id, so another
# account's deck, a place or a zone is a 404 (AC-9.7, AC-3.8).
class DecksController < ApplicationController
  before_action :set_deck, only: %i[edit update destroy]

  def index
    @listing = Deck::Listing.new(Current.account)
  end
  # new, create: T7. edit, update: T8. destroy: T9.

  private
    def set_deck = @deck = Current.account.decks.includes(:location).find_by!(location_id: params[:id])
end
```

`find_by!` raises `ActiveRecord::RecordNotFound` (404, as in `LocationsController`). The nav: `_appbar` inserts `Decks` after Collection (`decks_path`, `"aria-current": ("page" if section == :decks)`); `_tabbar` inserts the Decks tab after Collection with `render "icons/decks"` (the markup is in `TabBar.md`: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><rect x="8" y="3" width="12" height="16" rx="2"/><path d="M5 7v12a2 2 0 0 0 2 2h9"/></svg>`, following the other icon partials' shape). The page's table markup follows `DecksIndex.md` minus the Proxy column, plus an actions cell with `c-btn c-btn--ghost c-btn--sm` Rename and Remove as the Locations list has. `DecksHelper#deck_count_line(listing)` builds "6 decks · 379 cards". If the actions cell needs a rule, it goes in `additions.css` with a note in `DecksIndex.md` (T23); keep new rules in one block at the end of the file (a sibling worker, #294, edits icons and `additions.css`).

**Commit:** `feat(decks): the Decks page, and Decks in the header and tab bar (#49)`.

### T7: New deck

**Satisfies:** AC-1.1 to AC-1.3, AC-1.7, AC-1.7a, AC-1.8, AC-1.10. **Files:** `app/controllers/decks_controller.rb`, `app/views/decks/new.html.erb`, `spec/requests/decks_spec.rb`, `spec/system/decks_spec.rb`.

**Failing examples first:** request: *1.1* `GET /decks/new` shows Name, a Format select of the registered formats with Casual selected, the hint "The format sets the deck's zones.", "Create deck" and a "Cancel" link to `/decks`, under `c-appbar--detail`; *1.2* with the second fake collectible registered (the `:other_collecting` helper) the select has an `optgroup` per type labelled with its category name, with one type it is flat; *1.3* `POST /decks` with `deck[name]` "Izzet Tempo" and `deck[format]` "mtg/modern" is a 303 to `/decks` with `Added “Izzet Tempo”.` and the deck and its zones exist for `Current.account` only; *1.7* blank, control character, 61 characters, taken by a place, taken by a deck: 422, the form again with the typed name and the chosen format kept, the sentence in `c-field__error` on the Name field (`aria-describedby` wired as the Locations form does); *1.7a* with 500 top-level rows the sentence is "You can have at most 500 places and decks together."; *1.8* a blank, no-slash, unknown-type or other-type's key value is 422 "Choose a format." on the Format field and writes nothing; a request without `deck` is 400; *1.10* a request that adds `deck[account_id]`, `deck[kind]`, `deck[parent_id]`, `deck[zone]`, `deck[collectible_type]` ignores them (the deck belongs to the signed-in account, kind deck, the type from the pair). System: *1.1* the page at 360px has no horizontal overflow and the field and select stay inside the form.

```ruby
def new
  @creation = Deck::Creation.new(account: Current.account, name: "", format: Catalog::Formats.default_option&.value)
end

def create
  @creation = Deck::Creation.new(account: Current.account, name: deck_params[:name], format: deck_params[:format])
  if @creation.save
    redirect_to decks_path, notice: "Added “#{@creation.deck.name}”.", status: :see_other
  else
    render :new, status: :unprocessable_content
  end
end

# The two permitted parameters; a request without the deck parameter is a 400 (AC-1.8, AC-1.10).
def deck_params = params.expect(deck: %i[name format])
```

The view builds the select with `grouped_options_for_select` when `Catalog::Formats.grouped?` and `options_for_select` otherwise, from `Catalog::Formats.options` (value `option.value`, label `option.format.name`, group `Catalog::Formats.category_name(type)`); the form is `form_with model: @creation, scope: :deck, url: decks_path`, the Name and Format error markup is the Locations page's (`shared/field_errors`).

**Commit:** `feat(decks): the New deck page and creating a deck (#49)`.

### T8: Rename

**Satisfies:** AC-2.1 to AC-2.6. **Files:** `app/controllers/decks_controller.rb`, `app/views/decks/edit.html.erb`, `spec/requests/decks_spec.rb`.

**Failing examples first:** *2.1* `GET /decks/:id/edit` shows the Name field with the current name, Save and Cancel under Decks (`aria-current` on the Decks link); *2.2* `PATCH /decks/:id` with a valid name is 303 to `/decks` with `Renamed “<old>” to “<new>”.`, the zones, format, lots untouched; *2.3* a case-only change is allowed, another place's or deck's name (any case) is refused with the taken sentence; *2.4* a blank, control, over-60 or taken name is 422, the Rename page again with the typed text kept and the sentence on the Name field, the deck unchanged; *2.5* a lot in the deck's zone keeps its id, key and quantity and its place line reads the new name; *2.5a* `POST /locations` and `PATCH /locations/:id` with a deck's name (by key) is refused with the taken sentence; *2.6* `PATCH /decks/:id` and `GET /decks/:id/edit` with a zone's id or a place's id are 404; `PATCH /locations/:id` and `GET /locations/:id/edit` with a deck's or a zone's id are 404 (T10 makes the `/locations` half pass; write both here and mark the `/locations` half pending until T10, in the same commit `pending` with the reason, which T10 turns on).

```ruby
def edit; end

def update
  before = @deck.name
  if @deck.rename(deck_name)
    redirect_to decks_path, notice: "Renamed “#{before}” to “#{@deck.name}”.", status: :see_other
  else
    render :edit, status: :unprocessable_content
  end
end

def deck_name = params.expect(location: [ :name ])[:name]
```

The form is `form_with model: @deck.location, scope: :location, url: deck_path(@deck), method: :patch`, so the Name field's markup and ids equal the Locations Rename page's; the page title is "Rename deck". The page head shows the current name (`name_was`).

**Commit:** `feat(decks): rename a deck (#49)`.

### T9: Remove, and the refusal page

**Satisfies:** AC-3.1 to AC-3.7, AC-9.7 (removal). **Files:** `app/controllers/decks_controller.rb`, `app/controllers/decks/removals_controller.rb`, `app/views/decks/removals/{new,refused}.html.erb`, `spec/requests/decks_spec.rb`, `spec/system/decks_spec.rb`.

**Failing examples first:** *3.1* an empty deck's `GET /decks/:id/removal/new` names the deck, says its zones are removed with it, offers Remove and Cancel (works without scripting: a `button_to … method: :delete`); *3.2* `DELETE /decks/:id` removes deck, `decks` row and zones, changes no lot, place or other deck, 303 to `/decks` with `Removed “<name>”.`; *3.3* a deck with lots in two zones: the page is "“<name>” holds 12 copies in 3 lots. Move them before removing it.", lists the first 100 lots each linking to its card page with its zone label ("Izzet Tempo › Sideboard"), "and N more" beyond 100, "Back to decks", and has no Remove button and no "Move them in bulk mode" button; *3.4* `DELETE` on it is 409 with the same page, nothing removed (also when a lot was placed after the confirmation page opened: open the page, add the lot, send the DELETE); *3.5* a lot placed between the check and the delete: stub `Deck#holdings` to answer empty for one example (the one allowed stub: the subject is the database's refusal) and assert the 409 and that no zone and no deck is missing afterwards; *3.6* a second `DELETE` is 404; *3.7* a scanner sitting, a number-entry line, a bulk selection and an undo record are unchanged by a removal; *3.8* (deck routes half) a place's or a zone's id on `/decks/:id/removal/new` and `DELETE /decks/:id` is 404; *9.7* another account's deck on `edit`, `update`, `removal/new` and `destroy` is 404 and unchanged (the request spec per route).

```ruby
def destroy
  return refuse(@deck.holdings) if @deck.holdings.any?

  @deck.remove!
  redirect_to decks_path, notice: "Removed “#{@deck.name}”.", status: :see_other
rescue ActiveRecord::InvalidForeignKey
  refuse(@deck.holdings)
end

private
  def refuse(holdings)
    @holdings = holdings
    render "decks/removals/refused", status: :conflict
  end
```

```ruby
class Decks::RemovalsController < ApplicationController
  def new
    @deck = Current.account.decks.includes(:location).find_by!(location_id: params[:deck_id])
    @holdings = @deck.holdings
    render :refused if @holdings.any?
  end
end
```

`@deck.holdings` is called once per request in `destroy` through a local; the refused view lists `@holdings.listed` with `lot.place_label` (zone label) in each line and reuses `location_holds(@holdings.total)`. The refusal's words follow the Locations refusal page's exactly, "Back to decks" replacing the secondary link, and no shortcut button.

**Commit:** `feat(decks): remove a deck, refused while it holds copies (#49)`.

### T10: The locations routes know places only

**Satisfies:** AC-3.8, AC-2.6 (locations half), AC-4.8, AC-5.2 (locations selection). **Files:** `app/controllers/locations_controller.rb`, `app/controllers/locations/removals_controller.rb`, `app/controllers/locations/selections_controller.rb`, `spec/requests/locations_spec.rb`, `spec/requests/location_bulk_shortcut_spec.rb`.

**Failing examples first** (all five routes, with a deck's id and a zone's id each): `GET /locations/:id/edit`, `PATCH /locations/:id`, `GET /locations/:location_id/removal/new`, `DELETE /locations/:id`, `POST /locations/:location_id/selection` answer 404 and change nothing (a deck is never removed through `/locations`, which would bypass `Deck`'s own page); `GET /locations` lists places only and counts only places; the index page's form (`@location = Location.new`) still creates a place (`kind` is never a parameter; `Current.account.locations.new(name:)` defaults to `place`, so `create` is `Current.account.locations.places.new(name:)` for clarity). Turn on the `/locations` half of T8's pending example.

The change is one word in each lookup: `Current.account.locations.places` in `index` (both reads), `set_location`, `Locations::RemovalsController#new` and `Locations::SelectionsController#create`. A comment on `LocationsController` says why (a deck is removed and renamed as a deck; a zone never on its own).

**Commit:** `fix(locations): the locations pages answer places only (#49)`.

---

## Phase 4: Places only elsewhere, the label and the safe paths (D6)

### T11: The lot form, Move copies and bulk Move to… list and take places only

**Satisfies:** AC-5.1, AC-5.2, AC-5.6, AC-5.7a, AC-5.8a (the selects). **Files:** `app/controllers/lots_controller.rb`, `app/controllers/lots/moves_controller.rb`, `app/controllers/collections/moves_controller.rb`, `app/controllers/collections/selections_controller.rb`, `app/models/lot/bulk_move.rb` (comment), `spec/requests/lots_spec.rb`, `spec/requests/lot_moves_spec.rb`, `spec/requests/bulk_move_spec.rb`.

**Failing examples first** (one account with places "Box" and "Binder", deck "Izzet Tempo" with zones; a lot in the zone "main"; `deck_id` and `zone.id` posted as the location):

- *5.1* the new-lot form's Location select, the Move copies To select and bulk Move to…'s To select list "Binder" and "Box" (comparison-key order), never "Izzet Tempo" or "Main".
- *5.2, unsafe, fails first* `POST /catalog/entries/…/lots` with `lot[location_id]` set to a zone id and to a deck id is refused (404, as another account's place is today: `find` raising `RecordNotFound`); `PATCH /lots/:id` with a zone's id is 404; `POST /lots/:lot_id/move` with `move[location_id]` a zone's id is 404; `POST /collection/move` with `move[location_id]` a zone's id is 404. Each fails today (a zone id is accepted, which would place a lot in a zone through a form that does not offer one).
- *5.6* Move copies on a lot in a zone offers "No location" and the account's places; moving to "Binder" moves as for any lot and merges into an equal lot there; the lot's own zone is not a destination; moving all copies of a zone lot to "No location" works.
- *5.7a, characterisation* bulk Move to a place of a selection holding a zone lot, a place lot and an unplaced lot moves all three (a zone lot is never "already there"), merges where an identity meets, honours the cap, and leaves no selected lot in a zone; the To select omits the filter's own place exactly as spec 041 AC-2.1 does.
- *5.8a, partly here* `Collections::MovesController#require_locations` and `SelectionsController#offered?` ask `places.exists?`, so an account with decks and no place is told "You have no locations yet." and is not offered Move to….

Changes: in each file `Current.account.locations` becomes `Current.account.locations.places` (`set_locations`, `chosen_location`, the move controllers' `find`, `require_locations`, `offered?`). The comment on `Lot::BulkMove` says its destination is a place or none, and the partition `lot.location_id != @to&.id` is therefore right for a lot in a zone.

**Commit:** `fix(lots): the form, Move copies and bulk Move to… take places only (#49)`.

### T12: Number entry, the scanner, the filter and bulk removal

**Satisfies:** AC-5.1, AC-5.2, AC-5.7, AC-5.8, AC-5.8a. **Files:** `app/models/number_entry/line_form.rb`, `app/controllers/concerns/scanner_sitting.rb`, `app/controllers/scanner/sittings_controller.rb`, `app/models/collection_filter.rb`, `app/models/collection_filter/place.rb`, `app/models/bulk_removal.rb`, `spec/models/number_entry/line_form_spec.rb`, `spec/requests/number_entries_spec.rb`, `spec/requests/scanners_spec.rb`, `spec/requests/collection_location_filter_spec.rb`, `spec/models/bulk_removal_spec.rb`.

**Failing examples first:**

- *5.1* number entry's Location select, the scanner picker and the collection's Location select list places only.
- *5.2, unsafe, fails first* a number-entry line posted with a zone's id as `line[location]` shows the field error the surface shows for an id it doesn't offer (and adds nothing); `PATCH /scanner/sitting` with `sitting[location_id]` a zone's id leaves the sitting's place alone and answers as for an id that is not the account's (read `Scanner::SittingsController#update` for the current answer and keep it); `GET /collection?location=<zone id>` and `location=<deck id>` read as "all locations" (the filter's value is `""`), and a bulk-mode filter does the same. Each fails today.
- *5.8* (characterisation) a collection with a zone lot, a place lot and an unplaced lot: filter "No location" shows only the unplaced lot, filter "Binder" only the place lot, "All locations" all three (a zone lot is in neither of the first two).
- *5.7* (characterisation) number entry's Undo and the scanner's Undo of an add into a lot that sits in a zone keep the lot in its zone (the lot's key ends in the zone's id); a bulk removal's Undo of a zone lot restores it in its zone; when its deck was removed after the removal (a deck with no lots can be removed), Undo restores it unplaced and reports it as for a place (`BulkRemoval::Undone.new(unplaced:)`); `BulkRemoval#undo!` finds the lots' places among `account.locations` (every kind, keyed by id, because it follows lots to where they are), which must never find a deck: a lot's `location_id` can't be a deck's row after T5, so no change except the comment saying why every kind is right there.
- *5.8a* `CollectionFilter#places?` (the gate for the select and the filter) is "has a place"; a new `CollectionFilter#place_column?` is "has a place, or any lot in a zone" and gates the grid's place line, the table's Location column (`table.places?` in `collections/_table`, `_lot_cells`) and `lot_row_summary`'s `places:`; an account with a deck, a zone lot and no place shows the place line and column ("Izzet Tempo › Main"), hides the select, the filter, Move to… and the form's field, and the lot form shows "Add a location to keep copies in one."; with places all show as before.

Changes: `NumberEntry::LineForm#locations`, `ScannerSitting#account_locations`, `Scanner::SittingsController#update`'s `find_by`, `CollectionFilter#locations` take `.places`; `CollectionFilter` gains `place_column?` (one extra `exists?`, memoized, only when the account has no place: no new query for an account that has one) and `CollectionTable`/`CollectionGrid` read it where they read `places?` for the line and column. Update the comments that say "the account's locations" to "places".

**Commit:** `fix(collection): number entry, the scanner and the filter list places only (#49)`.

### T13: "Deck › Zone" wherever a place is shown

**Satisfies:** AC-5.4, AC-5.7b, AC-7.5 (lot rows). **Files:** `app/helpers/lots_helper.rb`, `app/helpers/number_entries_helper.rb`, `app/views/collections/_lot_cells.html.erb`, `app/views/catalog/entries/_copies.html.erb`, `app/models/collection_grid.rb`, `app/models/catalog/card_overview.rb`, `app/models/collection_table.rb` (the lot reads), `app/models/location/holdings.rb`, `app/views/locations/removals/refused.html.erb` (no change expected), the specs named below.

**Failing examples first** (a lot in the zone "main" of the deck "Izzet Tempo", and a place lot "Box"):

- the card page's "Your copies" row (the place cell, the phone line and the menu's `aria-label` "Actions for … in Izzet Tempo › Main"), the table's Location cell and phone line (`lot_row_summary`), the grid tile's place line, the bulk table's cell and line, the refusal pages' lots, the number-entry list's " in Izzet Tempo › Main", all read the label; none reads "Main" alone.
- one example greps the rendered pages' source for the zone's name without its deck ("Main" appears only inside "Izzet Tempo › Main") on those surfaces.
- *5.7b* in bulk mode a zone lot's place cell reads the label, and bulk Set condition keeps each lot's zone (characterisation).
- the collection table, the grid and the card page cost the same number of queries with a zone lot as with a place lot (add the zone lot to the existing `spec/requests/query_counts_spec.rb` scenarios: `includes(location: :parent)`/`preload` on every lot list; the label needs the parent loaded).

Changes (one label, `Location#label` / `Lot#place_label`, `Location::Placement.label` for plucked rows): `lot_place(lot) = lot.place_label || "No location"`; `lot_actions_label` and `lot_row_summary` and `_lot_cells` use `place_label`; `number_entry_place(line)` uses `line.lot&.place_label`; every query that lists lots preloads `location: :parent` (find them with `git grep -n "preload(:location)\|left_joins(:location)\|includes(:location)" -- app ':!.kamal/secrets'`; `CardOverview#lots` joins the parent for its order: `COALESCE(parents.name_key, locations.name_key)` then `locations.name_key`, so a deck's zones sort together under the deck's name); `CollectionGrid#places_of` joins the parent (`LEFT JOIN locations parents ON parents.id = locations.parent_id`) and plucks `parents.name` beside `locations.name`, building `Place.new(name: label, …)` through `Location::Placement.label`. `Location::Holdings#listed` already preloads the parent (T4).

**Commit:** `feat(lots): a zone is shown as "Deck › Zone" wherever a place is shown (#49)`.

### T14: "Edit copy" shows a zone read-only

**Satisfies:** AC-5.5. **Files:** `app/controllers/lots_controller.rb`, `app/views/lots/_form.html.erb`, `app/views/lots/edit.html.erb`, `app/models/lot/form.rb`, `spec/requests/lots_spec.rb`, `spec/system/lot_edit_spec.rb` (extend the existing lot system spec for the page).

**Failing examples first:** *5.5, unsafe, fails first* `GET /lots/:id/edit` for a zone lot shows "Izzet Tempo › Main" as plain text in the Location field's place and no `select#lot_location_id`; submitting the form exactly as the page sends it (quantity, finish, condition, price paid, no `location_id`) keeps the lot in its zone (today the select posts a blank value and unplaces it); a change of condition that meets another lot in the same zone merges there; a request that adds `lot[location_id]` for a zone lot is ignored by `update` (the zone is not changed through Edit: Move copies offers places, and zone choice is #252). For a place lot or an unplaced lot, the page and `update` are unchanged (the select, `lot_params.key?(:location_id)` semantics of spec 032 O3).

```ruby
# in LotsController#update
place = if @lot.location&.zone?
  @lot.location # a lot in a zone keeps it: the form shows it read-only (spec 062 AC-5.5, D6)
else
  lot_params.key?(:location_id) ? chosen_location : @lot.location
end
```

`lots/_form` takes a new local `zone_label:` (nil except for Edit of a zone lot): when set, the Location field is `<p class="c-field__static">` (a `c-field` with the label "Location" and the text; use the design system's static-field pattern if one exists in `Form.md`, otherwise a `c-field__hint`-styled paragraph and say so in the commit) and the select is not rendered; `lot_params` for that case permits no `location_id`. `Lot::Form` keeps `location_id` for the other cases.

**Commit:** `fix(lots): Edit copy keeps a lot in its zone and shows the place read-only (#49)`.

### T15: The other paths that could unplace a lot in a zone

**Satisfies:** AC-5.7, AC-5.7a, AC-5.7b, decision 6. **Files:** `spec/models/lot/move_spec.rb`, `spec/models/lot/condition_change_spec.rb`, `spec/models/lot/bulk_move_spec.rb`, `spec/models/bulk_removal_spec.rb`, `spec/models/lot_spec.rb`, `spec/models/number_entry_spec.rb`, `spec/models/scanner/sitting_spec.rb`, and the production files they point at, only if an example fails.

D6 asks for a check of every bulk path with a failing example first for each unsafe one. T11–T14 hold the examples for the surfaces they change; this task holds the remaining model-level paths. One example each, written first and run before any code:

| Path | Example | Expected today |
|---|---|---|
| `Lot::Move` of some copies of a zone lot to a place | the split part is in the place, the rest stays in the zone, keys end in the right ids | passes (characterisation) |
| `Lot::Move` of all copies to "No location" | the lot is unplaced, key without a location | passes |
| `Lot::ConditionChange` (bulk Set condition) on two lots equal but for the zone | each keeps its own zone, no merge across zones, a merge inside one zone | passes |
| `Lot::BulkMove` to a place | as T11 | passes |
| `BulkRemoval#undo!` | as T12 | passes |
| `Lot.add!` into a zone lot's identity (number entry, scanner) | merges into the zone lot, never creates a place lot | passes |
| the five `lot_key` builders (`Lot.key_for`, `Lot::BulkMove`'s SQL, `Lot::ConditionChange`'s SQL, `BulkRemoval#identity`, `CollectionImport::Apply#placed`) | one example each: given a zone's id, the key ends in `|<zone id>` | passes (the apply's is T21) |
| a lot's `location_id` set to a deck's id by any write path that skips validation | none exists after T5, T11, T12: assert it by running every controller path with a deck id (already in T11, T12) | — |

If any characterisation example fails, that is the unsafe path: fix it in this task with the smallest change and say so in the commit body (the list above is a prediction, the examples are the check). Also record in the task's commit body the results of the run.

**Commit:** `test(lots): every path that could unplace a lot in a zone is checked (#49)`.

---

## Phase 5: Export format version 4

### T16: The rules and schema of version 4, and their examples

**Satisfies:** AC-6.6 (schema), AC-6.7, AC-6.7b, AC-6.8, AC-6.9, AC-6.10 (rule half), AC-6.12, AC-6.13. **Files:** `app/models/export_format/rules.rb`, `app/models/export_format/v4.schema.json`, `docs/export-format/v4.schema.json`, `docs/export-format/examples/**`, `docs/export-format/examples/problems.json`, `spec/models/export_format/rules_spec.rb`, `spec/export_format_examples_spec.rb`, `spec/support/export_format_rules.rb`.

Read first: `docs/export-format/v3.schema.json`, `spec/models/export_format/rules_spec.rb`, `spec/export_format_examples_spec.rb` and `spec/support/export_format_rules.rb`.

**Failing examples first** (in `rules_spec.rb` unless noted; each fails because `VERSIONS` is `[1,2,3]`):

- `Rules::VERSIONS` is `[1, 2, 3, 4]`, `VERSION` 4; `v4.schema.json` in the app is byte-identical to the document's copy (the existing equality example generalises).
- *6.7* a version 4 file with: no `decks`; `decks` not a list; a deck missing `name`, `collectible_type` or `format`; a blank `collectible_type` or `format`; a deck whose name fails the name rules (control character, padded, 61 characters); a lot with a `location` that is a number, an object without `deck` or without `zone`, with an extra key, with a `deck` that is not a well-formed name, or with a blank `zone`; a lot without `location` — each is a problem at the pointer the schema gives (`/decks`, `/decks/0/format`, `/lots/0/location/zone`, …), `required`, `pattern`, `additionalProperties` or `type`. A string, null and `{deck, zone}` each pass.
- *6.7b* a deck name within 60 characters as written but over 60 after NFC (U+0344 doubles) passes the schema, as a place's does; the reader refuses it as a whole (`maxLength` at `/decks/<i>/name`, spec 029 decision 9's accepted limit), so its example is in T19's reader spec. Here only `invalid/deck-name-60-nfc.json` is added, with its row in `problems.json` as the existing `locations` neighbour of that kind is, if the examples spec's convention lists reader-only refusals there (read how `location-name-60`-style examples are handled and follow it).
- *6.8* a place and a deck, or two decks, with one comparison key: the later one is `duplicate_location` at its pointer, places judged before decks; a deck after the place `Box` named `box` is `/decks/0`.
- *6.9* `locations` plus `decks` over 500 together: `too_many_locations` at `/decks`; each list over 500 alone is the schema's `maxItems`; only the first 500 names of each are checked when the total is over 500 (a 100,000-name list does not take time: assert the count of `Location::Name.normalise` calls or the elapsed bound the existing `locations-501` example uses).
- *6.10* a lot whose `location` is `{deck: "Nope", zone: "main"}` with no such deck is `unknown_location` at `/lots/0/location` (the key compared by comparison key); a zone key the format lacks is NOT a rules problem (the reader's, T19).
- *6.12* two lots equal but for one in `{deck: "Box", zone: "main"}` and the other in the place "Box": not duplicates; `{deck: "Izzet"}` and `{deck: "izzet"}` same zone: `duplicate_lot` at the later (`Rules.identity` uses `Placement.file_key`).
- the version 1 to 3 examples and files are unchanged byte for byte (assert the git-tracked hashes? no: the existing examples spec runs them and must stay green untouched).

Changes:

- `v4.schema.json` is `v3.schema.json` with: `$id` `…:v4`, `format_version` const 4, title and description updated, `decks` in `required` and `properties` (`{ "type": "array", "maxItems": 500, "items": { "$ref": "#/$defs/deck" } }`), `$defs/deck` `{ type object, required [name collectible_type format], properties { name: location_name, collectible_type: text, format: text } }` (`text` is the existing non-blank string def; read its definition first and reuse it), and `lot_location` replaced by a type union so that every keyword applies to its own type only and the pointers stay precise:

```json
"lot_location": {
  "description": "null when the lot is in no location; a place's name; or an object naming a deck and one of its zones.",
  "type": ["string", "null", "object"],
  "minLength": 1, "maxLength": 60, "pattern": "<the same pattern as location_name>",
  "required": ["deck", "zone"],
  "additionalProperties": false,
  "properties": { "deck": { "$ref": "#/$defs/location_name" }, "zone": { "$ref": "#/$defs/text" } }
}
```

  `minLength`, `maxLength` and `pattern` apply to strings only; `required`, `additionalProperties` and `properties` to objects only. A spec proves each failure's pointer.
- `Rules`: `VERSIONS = [1, 2, 3, 4]`; `RULES` adds `too_many_locations`; `IDENTITY_FIELDS` adds `location/deck` and `location/zone`; `identity` uses `Location::Placement.file_key(lot["location"])` when `version >= 3` (a String or, from version 4, a Hash); `unlisted_places` also handles Hash locations against the decks' keys (version 4); `repeated_locations` iterates places then decks over one `seen` set (version 4: `decks` are read the same way, names only, skipping failed pointers); `locations_over_limit?` generalises to `names_over_limit?(data, version)` (version 4: `locations.size + decks.size > MAX_LOCATIONS`; versions 2 and 3: `locations.size > MAX_LOCATIONS` as before) and, when over, `data` keeps the first `MAX_LOCATIONS` of each list and the problem is `maxItems` at `/locations` (v2 and v3, as before) or `too_many_locations` at `/decks` (v4 total). `Problem` rule names for a deck-name pointer are the schema's.
- Examples: `valid/collection-v4.json`, `valid/empty-v4.json`, `valid/decks-all-formats.json` (one deck per MTG format with a lot in each zone key), `valid/deck-name-60.json`, `valid/decks-500.json` (500 decks, no places, no lots), `valid/lot-in-zone.json`; `invalid/` files for each bullet above (`decks-missing`, `decks-not-a-list`, `deck-name-missing`, `deck-format-empty`, `deck-collectible-type-empty`, `deck-name-61`, `deck-name-control`, `deck-name-60-nfc`, `deck-duplicate-place`, `deck-duplicate-deck-fold`, `decks-501`, `locations-and-decks-501`, `lot-location-object-no-zone`, `lot-location-object-no-deck`, `lot-location-object-extra-key`, `lot-location-zone-blank`, `lot-location-deck-unlisted`, `lot-location-zone-duplicate-case`) with their rows in `problems.json` (rule and pointer; the file's header comment says how an entry is read); `comparison/v4-base.json`, `v4-same.json`, `v4-different-deck-name.json`, `v4-different-deck-format.json`, `v4-different-lot-zone.json` (AC-6.13). `spec/support/export_format_rules.rb`'s comparison treats `decks` as a set of `name`, `collectible_type` and `format` exactly as written and a lot's `location` exactly (a zone object by its deck's written name and key); extend `same_collection?` and its examples.

**Commit:** `feat(export-format): version 4 rules, schema and examples (#49)`.

### T17: The format document

**Satisfies:** AC-6.6, AC-9.10. **Files:** `docs/export-format/README.md`.

Not tested by RSpec beyond the existing document spec (`spec/export_format_document_spec.rb`, the one exception, spec 020 decision 7), which now demands the version 4 row and the coverage rows. Run it first and let its failures list what is missing. The document gains: `**Format version:** 4`; `decks` in the top-level table (required from version 4); a "Decks" section (fields, the name space shared with places, the 500 limit shared, "zones are not listed: they come from the format"); the lot's `location` row (null, a name or `{ deck, zone }`) and its identity (the sixth value: a place's key, a (deck key, zone key) pair or none); the Well-formed rules (`too_many_locations`; `duplicate_location` and `unknown_location` across decks), and under "Well-formed and resolvable" the two resolvable checks (`unknown_format`, `unknown_zone`) and the older-file note; the version 4 row of the history ("2026-11-10"); the MTG section's formats table (key, name, zones in order, default) and its zone keys; "the same collection" for decks. It says in the Versions section what a reader of version 1 to 3 does with decks (leaves them in place; the copies in their zones are removed by applying the file).

**Commit:** `docs(export-format): version 4, decks and zones (#49)`.

### T18: The export writes version 4

**Satisfies:** AC-6.1 to AC-6.5. **Files:** `app/models/collection_export.rb`, `app/models/lot.rb` (the `with_place` scope), `spec/models/collection_export_spec.rb`, `spec/requests/collection_exports_spec.rb`, `spec/collection_export_core_spec.rb`.

**Failing examples first:**

- *6.1* the file is `format_version` 4 and has `decks`, present and empty for an account with none, each `{name, collectible_type, format}` with the name as stored, ordered by comparison key then name (code point order).
- *6.2* `locations` lists places only; no zone and no deck is in it.
- *6.3* a zone lot's `location` is `{"deck" => "Izzet Tempo", "zone" => "main"}`; a place lot's is its name; an unplaced lot's is `nil` (never `""`).
- *6.4* the number of queries is the same with 1 and 30 decks and lots; a deck renamed, removed or format-changed between the reads (stub the first read's lot rows through a hook the existing spec uses for the version 3 case: read `spec/models/collection_export_spec.rb`'s `Unsettled` example and copy its technique) makes it repeat up to `TRIES` and then raise `Unsettled`; a lot never names a deck or place the lists lack.
- *6.5* two exports of an unchanged collection are identical apart from `exported_at`; no id, no zone name and no account or user id is in the JSON (grep the JSON for the zone name's text where it differs from its key, and for the ids).
- the export validates against `v4.schema.json` and `Rules.problems` finds none (round-trip through the rules in the spec).

```ruby
# in Lot
PLACE_JOIN = "LEFT JOIN locations ON locations.id = lots.location_id " \
             "LEFT JOIN locations parents ON parents.id = locations.parent_id".freeze
PLACE_COLUMNS = %w[locations.kind locations.name locations.name_key locations.zone parents.name parents.name_key].freeze
# The lots with their place's own columns and, for a zone, its deck's, from one statement: what the export and the import
# read so a lot never names a place the account's lists lack (spec 062 AC-6.4).
scope :with_place, -> { joins(PLACE_JOIN) }
```

`CollectionExport` reads `lot_rows` as `@account.lots.joins(entry: :set).with_place.order(:id).pluck(*LOT_COLUMNS, *Lot::PLACE_COLUMNS)` (the old `locations.name` column goes), builds `location` with `Location::Placement.written(...)`, and `locations_and_lots` reads places (`@account.locations.places.ordered.pluck(:name)`) and decks (`@account.decks.listing_order.pluck("locations.name", :collectible_type, :format)`), checks that every row's place is listed (a place by name, a zone by its deck's name among the decks) and repeats up to `TRIES` as before; `FORMAT_VERSION = 4`; the class comment says version 4 and the new field. The core guard `spec/collection_export_core_spec.rb` still passes (no collectible or format named).

**Commit:** `feat(export): decks and zones in the collector export, version 4 (#49)`.

---

## Phase 6: Import

### T19: The reader: decks, refusals and rows

**Satisfies:** AC-6.7a, AC-6.7b, AC-6.10, AC-6.11, AC-7.4a, AC-7.4b, AC-7.4c, AC-7.4e, AC-7.8. **Files:** `app/models/collection_import.rb`, `app/models/collection_import/decks.rb`, `spec/models/collection_import_spec.rb`, `spec/models/collection_import/decks_spec.rb`, `spec/import_apply_core_spec.rb`, `spec/collection_import_core_spec.rb`.

**Failing examples first** (against `CollectionImport.new(account:, file: StringIO.new(json))`; build files with the existing helper in `spec/support/import_helpers.rb`, extended with `decks:` and zone lots):

- *6.11* a version 4 file with a deck whose `format` or `collectible_type` this instance doesn't register: `refusal.rule == "unknown_format"`, reason "This instance doesn't know the format “<format>” of <type>." before any row is judged and after `unsupported_currency` (a file with both says `unsupported_currency`).
- *6.7b* the NFC-long deck name is refused as a whole with rule `maxLength` at `/decks/<i>/name` (like `long_location`).
- *6.10* a lot in a deck's zone that the format lacks is a problem row `unknown_zone` at `/lots/<i>/location/zone`, reason "The deck “<name>” has no zone “<key>” in its format.", the names as the file spells them; a lot naming an unlisted deck is a problem row `unknown_location` with the reason "Its deck “<name>” isn't one of the file's decks."; neither makes a refusal.
- *6.7a* the reasons never print a raw object.
- *7.4c* a held lot's identity is `[type, source_id, finish, condition, price, key]` with `key` the place's comparison key, or the pair `[deck_key, zone]`; a file with the same printing in the zone "main" of two decks and a held collection with the same two lots matches each held lot with its own row (two outcomes, `unchanged`), and removing one deck's lot removes only that one.
- *7.4a* a version 1, 2 or 3 file whose place has a held deck's comparison key is refused (`deck_name_taken`, reason "A deck you have is called “<name>”, like a place in this file. Rename one of them and preview again.", `at` `/locations/<i>`; a version 1 file has no places so never refuses this way); nothing is written (the import writes nothing at all).
- *7.4b* a version 2 or 3 file whose places plus the held decks exceed 500 is refused (`too_many_with_decks`, "This file and your decks together would have more than 500 locations."); the same file for an account without decks isn't; a version 1 file is judged on held places plus held decks (cannot exceed).
- *7.4e* order: a version 4 file with `unknown_format` and a version 3 file with both `deck_name_taken` and `too_many_with_decks` give the first named in the order `unsupported_currency`, `unknown_format`, `deck_name_taken`, `too_many_with_decks`.
- *7.4* a version 1 to 3 file's plan has `decks` not counted (`counted?` false), its lots in places or none, and a held zone lot is a removed lot, listed with its label.
- *7.8* a version 4 file with a schema problem in `decks` or `too_many_locations` is refused as a whole at its pointer with no row.
- the preview writes nothing and enqueues nothing (AC-7.9: the existing "writes nothing" example grows a deck).
- the three core guards still pass: the new files name no collectible, format or zone key (the spec names none; the reader asks `Catalog::Formats`).

```ruby
# CollectionImport::Decks: what applying a file would do with the collector's decks (the Locations sibling, spec 062 AC-7.1
# to AC-7.3). +held+: the account's decks as Held; +file+: the file's decks as Entry, or nil for a version 1 to 3 file,
# which says nothing about decks, so the held ones stay and nothing here counts.
class CollectionImport::Decks
  Held = Data.define(:id, :name, :key, :collectible_type, :format)   # id is the deck's location id
  Entry = Data.define(:name, :collectible_type, :format)
  Renamed = Data.define(:held, :name)
  FormatChanged = Data.define(:held, :collectible_type, :format)
  attr_reader :added, :renamed, :format_changed, :removed, :unchanged   # added: [Entry]
  # counts, counted?, nothing_to_change?, removes?, listed_* and more_* as Locations has them, then:
  def fingerprint_part = [ added.map(&:name), renamed.map { [ it.held.name, it.name ] },
                           format_changed.map { [ it.held.name, it.held.collectible_type, it.held.format, it.collectible_type, it.format ] },
                           removed.map { [ it.name ] } ]
end
```

`renamed` and `format_changed` are independent lists over the held decks whose key the file also has (AC-7.2: a deck with both is in both). Lists are ordered by comparison key then name. `CollectionImport` changes:

- `read(file)` is `header_refusal || currency_refusal || format_refusal || held_decks_refusal`.
- `format_refusal`: for `@version >= 4`, the first deck whose pair `Catalog::Formats.find(type, format)` is nil → `refuse("unknown_format", "/decks/#{i}/format", …)`; also `long_deck_name` (the NFC length; extend `long_location`).
- `held_decks_refusal` (version ≤ 3, only when `held_decks.any?`): the first file place (by index) whose key matches a held deck's key → `deck_name_taken`; else `too_many_with_decks` when `file_place_keys.size + held_decks.size > Location::MAX_PER_ACCOUNT`; version 1: `held_locations.size + held_decks.size` can't exceed 500, no check needed but the rule is stated in a comment. Both are recomputed by `replan` (T21).
- `held_locations` reads `@account.locations.places.pluck(...)`; `held_decks` reads `@account.decks.joins(:location).pluck("decks.location_id", "locations.name", "locations.name_key", :collectible_type, :format)` once (memoized, reset in `replan`).
- `decks` (public, like `locations`): `@decks ||= Decks.new(held_decks, @version >= 4 ? file_decks : nil)`.
- `file_decks` normalises each name (`Location::Name.normalise`).
- Row `place` and `described[:location]` for a Hash location: the file's spelling `"#{deck} › #{zone name if the deck's format registers it, else the key}"` through `Location::Placement.label`.
- `HeldLot` gains the key and `location` label from `Lot.with_place`: `identity.last` is `Location::Placement.key(kind:, name_key:, zone:, deck_key: parents.name_key)` and `location` is `Placement.label` / the name; `LOT_COLUMNS` loses its two location columns for `Lot::PLACE_COLUMNS`.
- `resolution_problems` adds the `unknown_zone` check for a Hash `location` using the file's decks by key (only for rows with no other problem) and `describe` the `unknown_location` reason for a Hash location.
- `places?` stays "version ≥ 3" (the page says "written before locations existed" for version 1 and 2); add `decks_counted? = @version >= 4`.

**Commit:** `feat(import): read decks and zones from a version 4 file, refuse what would collide (#49)`.

### T20: The plan, its fingerprint, the preview page and the notice

**Satisfies:** AC-7.1, AC-7.2, AC-7.3, AC-7.4 (page), AC-7.5, AC-7.6, AC-7.7, AC-7.10, AC-8.8. **Files:** `app/models/collection_import/plan.rb`, `app/models/collection_import.rb` (the `plan` constructor), `app/views/collections/import_previews/_decks.html.erb`, `app/views/collections/import_previews/show.html.erb`, `app/views/collections/import_previews/_locations.html.erb` (the older-file note), `app/helpers/import_previews_helper.rb`, `app/controllers/collections/imports_controller.rb`, `spec/models/collection_import/plan_spec.rb`, `spec/requests/collection_import_previews_spec.rb`, `spec/requests/collection_imports_spec.rb`, `spec/system/collection_import_preview_spec.rb`.

**Failing examples first:**

- *7.1* the preview of a version 4 file has a Decks section after Locations with the counts "Decks added", "Decks renamed", "Format changed", "Decks unchanged", "Decks removed", lists of renamed (old → new), format-changed (name, old format → new format, by format names) and removed decks, each showing the first `LIST_LIMIT` and "and N more".
- *7.2* the plan counts: a key the held decks lack is added; a spelling change is renamed with the id kept; a format or type change is format-changed; both together are counted in both lists; the same name and format is unchanged; a held deck the file lacks is removed.
- *7.3* a held place "Box" and a file deck "Box": the place is removed and the deck added, both sections say so, and the apply needs the confirmation.
- *7.4* a version 1–3 file: the note "This file was written before decks existed, so your decks would stay, but the copies in them (<N> lots) would be removed." (the second half only when a deck holds a lot), no Decks counts; the note's N is `plan.removed_lots` in zones.
- *7.5* removed lots and problem rows in a zone end "in Izzet Tempo › Main".
- *7.6* the checkbox label is "I understand this removes N lots, M locations and K decks", naming only the parts that apply (`removal_phrase` and `removal_counts` in `ImportPreviewsHelper` gain decks; the lots in a deck's zones count among N).
- *7.7* a file whose only difference is a deck is applicable; a plan with nothing of any kind is "nothing to change".
- *7.10* the fingerprint changes when a deck is added, removed, renamed or format-changed between preview and apply, and does not when a deck is deleted and added again with the same spelling and format; a version 1–3 plan has the fingerprint it had (a regression example with a stored fingerprint of a version 3 plan computed before this change, pinned as a literal).
- *8.8* the notice: "Imported: N lots added, M changed, K removed; 2 locations added, 1 renamed, 1 removed; 2 decks added, 1 renamed, 1 format changed, 1 removed; prices now shown in EUR", each part at zero left out, no final period (`Collections::ImportsController#deck_sentence`, like `location_sentence`).

`Plan.new(outcomes, view_change, locations, decks, currency_change)`; `nothing_to_change?` adds `decks.nothing_to_change?`; `removes?` adds `decks.removes?`; `fingerprint` appends `decks.fingerprint_part` after the locations' part when `decks.counted?`, before the currency change (so a plan without decks keeps its fingerprint). `CollectionImport#plan` and `#replan` pass `decks`. The `_decks` partial uses the `c-stat`, `c-list` and `c-import__*` classes the Locations partial uses; the colour and spacing rules are the design system's (T23 documents the partial in `ImportPreview.md` if that doc exists, otherwise in the area doc).

**Commit:** `feat(import): preview what a file would do with decks (#49)`.

### T21: The apply

**Satisfies:** AC-7.4d, AC-8.1 to AC-8.7, AC-8.9, AC-8.3, AC-6 (identity of rows to the zone). **Files:** `app/models/collection_import/apply.rb`, `app/models/collection_import/location_changes.rb` (or `deck_changes.rb`), `app/models/collection_import/deck_changes.rb`, `spec/models/collection_import/apply_spec.rb`, `spec/models/collection_import/deck_changes_spec.rb`, `spec/requests/collection_imports_spec.rb`.

**Failing examples first:**

- *8.1, 8.2* a previewed version 4 file with an added deck: the deck row, its location, the zones of its format in order with the registration's keys and names; a renamed deck keeps its location id, zones and lots; a format-changed deck keeps id and name, takes the new type and format, gets the zones it lacks and loses the zones it has that the new format lacks (a lot of a lost zone is among the removed lots, deleted first); no lot is moved into Considering.
- *8.2a* a held deck whose format has since gained a zone (arrange it: create the deck with a registration then register one more zone through the fake vocabulary, or delete one of the deck's zone rows): applying a file that lists the deck, unchanged, ends with every zone row of the format present with the registration's key and name and a lot naming the new zone placed; a held zone whose stored name differs from the registration is rewritten first; the repair alone never makes a plan "something to change" (a file equal to the collection is "nothing to change" and writes nothing).
- *8.3* a place and a deck swap names across kinds; all removals run before any addition and the result matches the file with no unique-index failure (a deck → place and a place → deck in one file).
- *8.4* a lot in a zone: `location_id` is the zone's id and `lot_key == Lot.key_for(finish, condition, cents, zone.id)`; the apply's `placed` resolves a place key among places and a zone by its (deck key, zone key) pair, so a place "Main" and a deck's zone "main" are never confused and the same printing in two decks' "main" is two lots in the right zones.
- *8.6* a removed deck's zones' lots are deleted before the zones (the foreign key never fires); the apply never moves a lot; a scanner sitting whose place is removed is cleared through the foreign key.
- *8.7* an apply that changes only decks or places clears no working state (selection, undo records, number-entry list, sitting); one that writes a lot clears them.
- *8.9* every written row is checked against the models: a helper reloads each written `Location` and `Deck` and calls `valid?` (name, key, kind, parent, zone, format), as `AC-2.4` does for lots; the number of statements (counted with `query_counting`) for 2 decks equals that for 40 decks.
- *7.4d* a version 3 file previewed against a collection with no decks; a deck named like one of the file's places is then created (or enough decks to pass 500 with the file's places); the apply refuses with the preview's reason (`deck_name_taken` or `too_many_with_decks`), before the nothing-to-change and stale checks (a refusal is never shown as stale), writes nothing, and the upload is removed as a refusal removes it; no path reaches `ActiveRecord::RecordNotUnique` (run the example twice with the deck created before preview and between).
- the apply re-checks in the transaction: `replan` also re-judges `format_refusal`'s registration check? No: `unknown_format` depends only on the file and the instance's registrations, not on the account; it is stable between preview and apply and is not re-judged.

Changes. `CollectionImport#replan` resets `@held_decks`, `@decks` and recomputes `@refusal = held_decks_refusal` (version ≤ 3), and `Apply#decide` checks `import.refused?` right after `replan` and before `nothing_to_change?`: `next refuse(current, import)` (the existing `refuse` removes the upload and returns `:refused`). The order in `write!`:

```ruby
def write!(plan, rows)
  @account.update!(currency: plan.currency_change.to) if plan.currency_change
  plan.removed_lots.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.lots.where(id: ids).delete_all }
  CollectionImport::DeckChanges.write!(@account, plan.locations, plan.decks)
  place_ids = @account.locations.places.pluck(:name_key, :id).to_h
  zone_ids = @account.locations.zones_of_decks.joins("JOIN locations parents ON parents.id = locations.parent_id")
    .pluck("parents.name_key", "locations.zone", "locations.id").to_h { |deck_key, zone, id| [ [ deck_key, zone ], id ] }
  # ... upsert_lots! as before, placed(attributes, place_ids, zone_ids)
end

def placed(attributes, place_ids, zone_ids)
  location_id = Location::Placement.resolve(attributes[:location_key], places: place_ids, zones: zone_ids)
  attributes.except(:location_key).merge(location_id:, lot_key: Lot.key_for(attributes[:finish], attributes[:condition], attributes[:price_paid_cents], location_id))
end
```

`DeckChanges.write!(account, locations, decks)` (the old `LocationChanges.write!` becomes its first half and is kept as `LocationChanges` for places, called from here so the places' code stays where it is):

1. delete the removed places' rows and the removed decks' location rows (a deck's zones and `decks` row cascade) in two `delete_all` statements, batched; delete the zones that format-changed decks lose (`Catalog::Formats.zones_for` by the file's pair; ids read from the account's zones of those decks in one statement); *every removal before any addition* (AC-8.3);
2. upsert places (kind `place`) and deck locations (kind `deck`) on the top-level index: `Location.upsert_all(rows, unique_by: :index_locations_on_account_id_and_name_key_top_level, update_only: %i[name updated_at], record_timestamps: false, returning: false)`. A conflict target on a partial index needs its condition (spec note): prove it with a spec that fails first, and if `unique_by` with an index name does not emit `WHERE parent_id IS NULL` on this Rails version, use `Location.connection.execute` with `Location.sanitize_sql_array` and `ON CONFLICT (account_id, name_key) WHERE parent_id IS NULL DO UPDATE SET name = excluded.name, updated_at = excluded.updated_at` as the lots' upsert does;
3. read the decks' location ids (`account.locations.decks.pluck(:name_key, :id)`), upsert `decks` rows (`unique_by: :location_id`, setting `collectible_type`, `format`, `updated_at`) for added and format-changed ones;
4. the zone repair (AC-8.2a): for every deck the file lists, read the account's existing zones once, `UPDATE` each existing zone's `name`, `name_key` from the registration (one statement per zone key of the registrations, not per deck), then insert the zones that are missing (`insert_all` with `unique_by: :index_locations_on_parent_id_and_name_key`, `on_duplicate: :skip`).

The statement count must not depend on the number of decks (AC-8.9); a spec proves it. A deck with no zone in its registration (a lost registration) is never listed by a file the reader accepts (`unknown_format`), so the repair never meets one.

**Commit:** `feat(import): apply decks and zones, with the older-file refusals re-judged in the transaction (#49)`.

---

## Phase 7: Round trip, bounds, guards and documents

### T22: The round trip, the bounds and the guards

**Satisfies:** AC-8.5, AC-8.10, AC-9.8, AC-9.9, AC-9.11, AC-6.13 (round trip), NFR Performance. **Files:** `spec/deck_core_spec.rb`, `spec/models/collection_round_trip_spec.rb` (read the existing round-trip spec first and extend it), `spec/requests/collection_import_timing_spec.rb` (extend the existing timing specs), `spec/requests/admin/users_spec.rb`, `spec/backup_restored_instance_spec.rb`.

**Failing examples first:**

- *8.5* the round trip: an account with places, one deck in every MTG format, zones holding lots (some empty), a lot in a place and an unplaced lot is exported, applied to a fresh account, and exported again; the two files hold the same collection (`ExportFormatRules.same_collection?`), each deck has its format's zones, each lot its place; applying the same file twice is refused the second time as nothing to change, clearing nothing.
- *8.10* a file at the worst case of the earlier bars (50,000 lots over 300 places) with 100 decks and 300 zones is previewed and applied within the bars (preview under 30 s and 500 MB, apply under 30 s and 500 MB with the write transaction under 4 s, export of 50,000 lots under 10 s and 300 MB). The existing timing specs are measurements as timing specs (`.claude/memory`): extend them, do not add a separate script.
- *9.8* the admin users page, `/admin/catalog` and `/admin/jobs`, for an account with decks, show no deck name, format, zone or count; the admin users page's copy count is unchanged by zone lots? It counts copies: assert it still counts every lot (a zone lot is a lot).
- *9.9* a backup of an instance with decks, restored (the existing `:committed` backup helpers), holds the decks, zones and lots; `spec/backup_guards_spec.rb` stays green.
- *9.11* `spec/deck_core_spec.rb` lists the deck files (the decks controllers and views, `app/models/deck.rb`, `deck/*.rb`, `location/placement.rb`, `catalog/formats.rb`, `app/helpers/decks_helper.rb`, `collection_import/decks.rb`, `collection_import/deck_changes.rb`, the preview's `_decks` partial) and fails if one names `mtg`, `scryfall` or `magic` in any spelling (case-insensitive, comments included) or any of the eight format keys as words (`casual standard pioneer modern legacy vintage pauper commander`), or the zone keys `sideboard` and `commander`; `main` is reviewed by eye. It proves it can fail: write a temporary identifier-shaped name into a Tempfile and run the same matcher on it, the way `spec/number_entry_core_spec.rb` does (read it and copy its structure). `spec/collection_export_core_spec.rb`, `spec/collection_import_core_spec.rb` and `spec/import_apply_core_spec.rb` gain the same words for their files.

Also run `ruby script/upgrade/guard.rb` and `bin/rails zeitwerk:check`. `bin/upgrade-smoke` and the full `bin/ci` are the supervisor's, after B10, with a CI slot asked first.

**Commit:** `test(decks): round trip, bounds, guards and the operator's view (#49)`.

### T23: Documents and indexes

**Satisfies:** the spec's "Supersedes and updates", AC-6.6, the notes for #251 and #252. **Files:** `docs/architecture/collection-and-lots.md`, `docs/architecture/data-portability.md`, `docs/architecture/tenancy-and-accounts.md`, `docs/architecture/README.md` if it lists sections, `docs/design-system/README.md`, `docs/design-system/components/{DecksIndex,AppHeader,TabBar}.md`, `docs/specs/README.md`, `docs/adr/0028-decks-are-locations-with-zones.md`, `CLAUDE.md`, `docs/specs/062-create-rename-remove-a-deck/verification.md`.

Prose documents are verified by reading and recorded in `verification.md` (`.claude/rules/testing.md`: no RSpec on prose). Each new statement in an area doc carries its source inline (spec 062 criterion, ADR 0028), and #49 joins each doc's Sources.

- `collection-and-lots.md`: locations are kinds (place, deck, zone), names unique per parent, the 500 limit's new sentence (Named constants table: `Location::FULL` and its text), a lot's place may be a zone, the label ("Deck › Zone"), the places-only list of surfaces and the every-kind list (decision 1), Edit copy's read-only place, the refusal page for a deck.
- `data-portability.md`: format version 4 (current; `VERSIONS` is `[1,2,3,4]`), `decks`, the lot's `location` forms, the new rules and resolvable checks, the older-file refusals (`deck_name_taken`, `too_many_with_decks`) and their order, the plan and fingerprint for decks, the apply's order and the zone repair, the constants.
- `tenancy-and-accounts.md`: the deck routes' 404 rule (a deck is found by its location id through the account; a place's or zone's id is 404; the locations routes' reverse).
- `docs/design-system/README.md`: Navigation (Decks is live), `AppHeader.md` and `TabBar.md` (the real link and tab, the icon partial), `DecksIndex.md` (columns without Proxy, the row actions, the name as text until #253, the 500 sentence "You can have at most 500 places and decks together.", the refusal and rename pages): "Supersedes spec 060 decision 11 and AC-4.1 to AC-4.3 for the page until #253 and #254".
- `docs/specs/README.md`: spec 062's row (Status and plan link), the superseded-by additions kept, a note under #252's entry that the label and the safe Edit copy are done in spec 062 (D6), and under #251 that an import changes a deck's format as the file says with no move to Considering; expect a merge conflict in this file when `origin/main` is merged (keep every row).
- ADR 0028: Status `Accepted` after the maintainer's approval of this plan (done at Gate B, not here), and the README's line as it is.
- `CLAUDE.md`: the Project Status paragraph names decks (`Deck`, `Deck::Creation`, `Catalog::Formats`, spec 062, ADR 0028), and the export bullet says version 4 is current (`VERSIONS` `[1,2,3,4]`).
- `verification.md`: one line per criterion of the spec saying what proved it (an example's file and description, or "read"), the results of the full CI and the migration redo, and, last, the `## Implementation review` heading the review fills.

Two issue notes are owed to the maintainer, not written by the worker: the sentences for #251's issue ("an import changes a deck's format as the file says, with no move to Considering") and #252's ("the label and the safe Edit copy are done in #49"). They go in `worker_done`'s body.

**Commit:** `docs: decks in the area docs, the design system and the specs index (#49)`.

---

## After the last batch (supervisor, not an implementer)

1. `bin/rubocop`, `bin/yard doc` (the YARD build and the comment ratchet are part of `bin/ci checks`), `bin/brakeman`, `ruby script/upgrade/guard.rb`, `bin/rails db:migrate:redo:primary` (no deck), `bin/rails zeitwerk:check`: each once, targeted.
2. Ask the coordinator for a CI slot; run `bin/ci`; send "slot released" with the SHA and the result. On a failure, reproduce with the CI seed (`.claude/memory/reproduce-ci-with-seed.md`).
3. Implementation review (`sdd-superpowers:sdd-review` Mode B, read-only, Opus), recorded in `verification.md` under `## Implementation review` with the verdict first.
4. The final visual review: screenshots (real CSS, classic scrollbars, headless Firefox, as spec 060's were) of the Decks page, the New deck page, the rename and remove flows and the refusal page, in both themes, wide and phone, in the PR body; asked of the coordinator before the PR is marked ready.
5. `sdd-superpowers:session-wrap`, then `distill-feature`; merge `origin/main` (a merge, never a rebase; keep every row of `docs/specs/README.md`); push (slot first) to open the draft PR; green CI; `gh pr ready`, `gh pr edit --add-assignee @me`; `worker_done` once.

## Risks and how the plan meets them

| Risk | Where | Handling |
|---|---|---|
| The migration's `down` and `ADD COLUMN` checks on SQLite | T1 | guarded steps, `db:migrate:redo:primary`, a spec on a pre-migration database with lots and sittings; the plan names the `remove_check_constraint` and foreign-key order the redo may need |
| A partial unique index as an `ON CONFLICT` target | T21 | the spec's own note; a failing example, then `unique_by:` with the index name or the raw statement the lots' apply already uses |
| A zone id reaching a surface that offers places only | T10–T12 | every lookup takes `.places`; an example per surface posts a zone id and a deck id |
| The label's N+1 | T13 | `includes(location: :parent)` on every lot list; the query-count scenarios gain a zone lot |
| A format registration that a later release changes | T3, T21 | `verify!` at boot; the zone repair on apply; the format document says what a release must do |
| Merge conflicts with the sibling worker (#294) in `additions.css` and the icons | T6 | new CSS in one block at the end of the file; `app/views/icons/_decks.html.erb` is a new file |
| The unique name index meeting an apply | T19, T21 | the reader's two refusals, re-judged in the transaction; removals before additions; each created row's name checked by a spec against `Location` |

## Spec coverage

Every acceptance criterion has a task: Story 1 T4, T7; Story 2 T4, T8, T10; Story 3 T4, T9, T10; Story 4 T6, T10, T23; Story 5 T5, T11–T15; Story 6 T16–T18; Story 7 T19, T20; Story 8 T21, T22; Story 9 T1, T2, T9, T22. FR-1 T2, T4; FR-2 T3; FR-3 T16–T21; FR-4 T6–T9. No criterion is left without an example; T22 closes the cross-cutting ones (round trip, bounds, guard, operator view, backup).
