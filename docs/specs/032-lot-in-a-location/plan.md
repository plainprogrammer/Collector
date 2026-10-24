# Implementation Plan: Put a Lot in a Location

**Spec:** docs/specs/032-lot-in-a-location/spec.md (v1.0.2: approved by the maintainer on 2026-10-23 as 1.0.1; PATCH 1.0.2 of 2026-10-24 records ruling O1)
**Status:** Revised on 2026-10-24 for the independent read-only review (`plan-review.md`: 6 major and 11 minor findings, each mapped there to its fix) and the maintainer's rulings O1 to O3; awaiting the maintainer's approval. Plans here are not executed or test-run before approval: this plan was traced against the files it edits (research R1 to R10) and nothing was run.
**Decisions:** docs/adr/0025-a-lots-location-is-part-of-its-identity.md (Proposed, written with this plan; accepted in Phase 8 when the maintainer approves the plan). ADRs 0016, 0017, 0019, 0020, 0021, 0022 and 0023 apply
**Created:** 2026-10-23 (on `origin/main` at `b873304`, after PR #129 added the data portability area doc)
**Supporting:** [data-model.md](data-model.md), [contracts/api.md](contracts/api.md), [contracts/export-v3.md](contracts/export-v3.md), [research.md](research.md)

## Global Constraints

Copied from the spec; each applies to every phase.

- One pull request: the migration, the lot's place, the forms, the card page, Move copies, the refusal to remove a location that holds lots, the locations page's counts, the bulk Undo, export format version 3 (document, schema, examples, Coverage), the export, and the preview's and apply's reading of version 3 and of older files as unplaced (spec Problem Statement; the format is extended "in the same pull request").
- **A lot's identity is its printing, finish, condition, price paid and location** (decision 1, ADR 0025). An account never holds two lots of one identity: the unique index on `[account_id, catalog_entry_id, lot_key]` stays, and the place is in `lot_key` as the location's **id** for a placed lot; an unplaced lot's key is the key it has today. The 9,999 cap is per lot, so per place.
- **Unplaced is a real state**: no default location, no backfill, no existing value changes (decision 2).
- **A location that holds copies can't be removed** (decision 3): 409 from `DELETE`, a refusal page that counts and lists (P1), the database refuses too. Nothing is unplaced or merged by a removal.
- A place is set by the add form, the edit form and Move copies (decision 4); the grid, table, quick add, typed entry, scanner and bulk bar do not gain a place and keep adding unplaced copies (decision 5).
- Every location and lot is found through `Current.account`; another account's id is 404 (decision 6). `account_id` is never mass-assigned.
- Older files (version 1 or 2) are read as unplaced; their preview says why and the apply needs the removal confirmation (decision 7).
- Format version 3: a required `location` (name or `null`) on every lot; six-value lot identity; `unknown_location`; `v1` and `v2`, their examples and the app's copies never change; a missing `location` in a version 3 file is malformed; no internal id in a file.
- The apply keeps spec 028's one write transaction, stored upload, expiry, sweep, working-state rule and bars (request under 30 s, write transaction under 4 s, under 500 MB growth); its order becomes delete removed lots, write locations, read the account's locations once, then upsert lots (research R3).
- The migration changes no value and is safe to run unattended from any prior version; it adds one empty column, an index and a foreign key without rebuilding `lots` (research R1). No released migration is edited; no application model is referenced in a migration (`.claude/rules/sqlite-and-migrations.md`).
- Core code names no collectible type: the new and changed files contain neither `MTG` nor `Scryfall` (FR-1). `git grep -n -i 'mtg\|scryfall' -- <the files this plan creates> ':!.kamal/secrets'` is empty when the plan finishes (the existing `ExportFormat`/`CollectionImport` files already satisfy this). Each new file is also added to the file list of `spec/import_apply_core_spec.rb` (where spec 029's are) in the phase that creates it, so the check guards it from then on (plan review m7).
- UI uses only design-system tokens and `c-*` classes; read `docs/design-system/README.md` and the `components/` docs named per phase, via the `collector-design-system` skill, before writing a view, partial or stylesheet. A new pattern goes in `collector/additions.css` with its doc under `docs/design-system/components/` and a line in the README's app additions.
- Pages work with scripting off, from 360px wide up, with the keyboard alone; a write answers 303 on success, 422 on a failed form, 409 on a refused removal, 404 on another account's id.
- Every phase ends green: its last step is the whole `bin/rspec` passing, plus `bin/rubocop`; an expectation of an existing spec that a phase makes false is changed in that phase, never a later one (spec 029 plan review M3). A phase's own run list is for speed while working, not for the end.
- TDD is the hard gate: a failing test precedes every implementation step. Prose documents are verified by reading and recorded in `verification.md`, never by RSpec (`.claude/rules/testing.md`); the export format's document is the one exception.
- Small commits: one conventional commit per step that is a unit (`feat(lots): …`, `test(…)`, `docs(…)`), each ending with the attribution line; stage files by name; `Gemfile.lock` stays uncommitted.
- Every `bin/rails db:migrate` rewrites `db/schema.rb` and may rewrite the cache, queue and cable schemas: restore those three (`git checkout -- db/cache_schema.rb db/queue_schema.rb db/cable_schema.rb`) before committing (memory: migrate schema noise).

---

## Goal

A signed-in collector puts copies in a location when adding them, changes a lot's location, and moves some or all of a lot's copies to another place or to none; a printing can sit in several places as several lots; the card page and the locations page show where copies are; a location that holds copies refuses removal and says what it holds; and the export (format version 3), the preview and the apply carry and restore each lot's place, reading older files as unplaced.

---

## Scope Check and Gates

One outcome, one pull request, eleven stories. No split: the format change must ship with the field (north star, "Export covers it").

- **Simplicity (≤3 components):** (1) *A lot's place*: `lots.location_id`, `Lot` and its merging (`add!`, `revise!`, `Lot::ConditionChange`, `BulkRemoval`), `Lot::Move`, `Location::Holdings`, the forms and pages; (2) *Format version 3*: `ExportFormat::Rules`, `v3.schema.json`, the document and examples, `CollectionExport`; (3) *The import's places*: `CollectionImport` (identity, problem rows, the page) and `CollectionImport::Apply`/`Plan`. No new dependency, table, job, route family or gem.
- **Anti-abstraction:** `Lot::Move` is the one class for the move form and the move (like `Lot::Form` and `Lot::ConditionChange` are for theirs); `Location::Holdings` is the one place that counts what a location holds (the locations page's grouped totals and the refusal page's list); everything else is a change to the class that already owns the behaviour. No wrapper, no service layer.
- **Integration-first:** `data-model.md`, `contracts/api.md` and `contracts/export-v3.md` precede code. Phase 0 starts with the failing migration spec; Phase 6 starts with the failing rules and example specs.

## Areas and Supersessions

- **Area docs to change** (`.claude/rules/documentation.md`): `docs/architecture/data-portability.md` is on `origin/main` (PR #129), so Phase 8 updates it in this pull request, a source inline for each new statement (spec criterion or ADR 0025). The collection-and-lots area doc does not exist (`docs/architecture/README.md` lists it as not written); `CLAUDE.md` carries the line until it does. `distill-feature` runs at session end.
- **Supersedes** (recorded in the spec's Supersedes table and in `docs/specs/README.md`, both directions, already merged with the spec; not by editing earlier specs): ADR 0019's open question and ADR 0023's sentence on deleting a location (by ADR 0025; their Status lines get pointers in Phase 8); specs 004, 006, 009, 017, 022, 025, 026, 028 and 029 as the spec lists.
- **Design system:** read `Form.md`, `ConfirmPage.md`, `Locations.md`, `ItemPage.md`, `CollectionTable.md`, `ImportPreview.md`, `Menu.md` before the phases that use them.

## Open Items

O1 to O3 were ruled by the maintainer on 2026-10-24 (accepted as the defaults below); O4 is settled by the index. Nothing blocks the plan.

| # | Item | Ruling | Source |
|---|---|---|---|
| O1 | AC-10.9 said "the lists of added, changed and removed lots add 'in <location>'", but the preview lists only removed lots and problem rows | **Ruled 2026-10-24:** "in <location>" goes on those two lists; no list of added or changed lots is built (that would be a new preview feature). Recorded in the spec as PATCH 1.0.2 (`9d3f072`): AC-10.7 is checked by the counts and the removed lot's line, AC-10.9 names the two lists. Also recorded in `verification.md` (Phase 8 step 8) so the Mode B review doesn't flag drift | research R6, plan review M6 |
| O2 | AC-7.8: which lot is named when the restored rows alone pass 9,999 and no lot of the account is involved | **Ruled 2026-10-24:** an existing lot that would overflow is named first, by the table's sort (spec 006 AC-7.5); else the first overflowing restored row in saved order, as an unsaved lot. Implemented in Phase 2's `check_cap!` and tested there | research R4 |
| O3 | The spec doesn't say what an edit does when `lot[location_id]` is absent (add: unplaced, AC-1.8) | **Ruled 2026-10-24:** an edit without the parameter keeps the lot's place (PATCH semantics); blank is "No location". A plan-level rule (contracts/api.md, Phase 4's `update` and two examples); it adds no criterion to the spec | research R5 |
| O4 | ADR number | 0025 (0024 is the last on `origin/main`; spec 031 plans no ADR); the YARD ADR that the roadmap expected to take 0025 takes the next free number; `docs/adr/README.md`'s Expected paragraph already says so | ADR 0025 Status |

---

## File Structure

| File | Responsibility |
|---|---|
| `db/migrate/20261023100001_add_location_to_lots.rb`, `db/schema.rb` | `lots.location_id`, its index and foreign key (FR-1) |
| `spec/migrations/add_location_to_lots_spec.rb` | The migration keeps every lot and every pointer to one, both ways (AC-7.1) |
| `app/models/lot.rb` (edit) | `belongs_to :location`, `key_for` with the place, `add!(location:)`, the place validation |
| `app/models/location.rb` (edit) | `has_many :lots`, `#holdings` |
| `app/models/location/holdings.rb` (new) | What a location, and every location, holds (P1, P2) |
| `app/models/account.rb` (edit) | The comment that makes the `has_many` order load-bearing |
| `app/models/lot/form.rb` (edit) | `location_id` for the add and edit forms |
| `app/models/lot/move.rb` (new) | The Move copies form and the move (Story 3) |
| `app/models/lot/condition_change.rb`, `app/models/bulk_removal.rb` (edit) | Keys and groups with the place; the Undo that merges per place (Story 7) |
| `app/models/catalog/card_overview.rb` (edit) | The card page's lots with their place, in a fixed order |
| `app/controllers/lots_controller.rb`, `app/controllers/lots/moves_controller.rb` (new), `app/controllers/locations_controller.rb`, `app/controllers/locations/removals_controller.rb`, `app/controllers/collections/bulk_removals/undos_controller.rb` (edit) | The actions |
| `config/routes.rb` (edit) | `resource :move` under `lots` |
| `app/views/lots/{_form,new,edit}.html.erb`, `app/views/lots/moves/new.html.erb` (new), `app/views/catalog/entries/_copies.html.erb`, `app/views/locations/index.html.erb`, `app/views/locations/removals/refused.html.erb` (new) | The pages |
| `app/helpers/lots_helper.rb`, `app/helpers/locations_helper.rb` (new), `app/helpers/collections_helper.rb`, `app/helpers/import_previews_helper.rb` (edit) | Words |
| `app/assets/stylesheets/collector/additions.css` (edit) | `c-locations__more`; a 44px floor for the refusal page's lot links (`c-locations__lots`) |
| `spec/import_apply_core_spec.rb` (edit) | Lists each new file as its phase creates it (Phases 3 and 5) |
| `app/models/export_format/rules.rb` (edit), `app/models/export_format/v3.schema.json` (new) | Three versions, six-value identity, `unknown_location` |
| `docs/export-format/README.md` (edit), `v3.schema.json`, `examples/**` | The format document, schema, examples |
| `app/models/collection_export.rb` (edit) | Writes version 3 |
| `app/models/collection_import.rb`, `app/models/collection_import/{apply,plan}.rb` (edit), `app/views/collections/import_previews/show.html.erb` (edit) | Reads versions 1 to 3, six-value matching, the page, the apply's order and keys |
| `spec/support/{export_format_rules,import_helpers}.rb` (edit) | Version-aware identity; builders for version 3 files |
| `spec/**` | Listed per phase |
| `docs/architecture/data-portability.md`, `docs/adr/{0019,0023,0025}-*.md`, `docs/adr/README.md`, `docs/roadmap.md`, `docs/specs/README.md`, `docs/design-system/**`, `CLAUDE.md`, `README.md`, `docs/specs/032-lot-in-a-location/verification.md` | Phase 8 |

---

## Requirement Map

Every decision, detail and criterion → phase → the first failing test (named by file and example; the executor writes the example first).

| Requirement | Phase | First failing test |
|---|---|---|
| FR-1: one identity, unique, backed by the database; D1, D2 | 0, 1 | `add_location_to_lots_spec` "keeps every lot…"; `lot_spec` ".key_for carries the place" |
| AC-7.1 (migration), NFR reliability (migration), cost | 0 | `add_location_to_lots_spec` (up, down, twice, refuses with placed lots) |
| AC-9.3 (Coverage lists `lots.location_id`; interim "Left out" row, final mapping in 6) | 0, 6 | `export_format_document_spec` "accounts for every column…" |
| AC-1.3, AC-1.4, AC-1.5 (model), AC-2.2 to AC-2.6 (model), AC-7.2 | 1 | `lot_spec` ".add! in a place", "#revise! to a place", `number_entry_spec`/`sitting_spec`/`quick_adds_spec` "adds an unplaced copy" |
| AC-6.6 (delete an account with placed lots), AC-5.5 second half (the database refuses) | 1 | `account_spec` "deletes its lots before its locations"; `location_spec` "can't be deleted while a lot is in it" |
| AC-7.3 to AC-7.8, P5, AC-7.6 | 2 | `condition_change_spec` "merges only within a place"; `bulk_removal_spec` "restores each lot to its place", "restores a lot whose location was removed unplaced" |
| Story 5 (AC-5.1 to AC-5.7), P1, P2, AC-4.3, D3 | 3 | `holdings_spec`; `locations_spec` "refuses to remove a location that holds lots (409)" |
| AC-6.3, AC-6.4, AC-6.5 (locations pages), AC-6.7 (removal side) | 3 | `locations_spec` "shows no count of another account"; admin spec "shows no location" |
| Story 1 (AC-1.1, 1.2, 1.5 to 1.9), Story 2 (AC-2.1, 2.2, 2.4, 2.6, 2.7, 2.8), P3, D4 (forms), D6 (forms) | 4 | `lots_spec` "adds into a location", "answers 404 for another account's location" |
| Story 4 (AC-4.1, 4.2, 4.4, 4.5) | 4 | `entries_show_spec` "lists a row per lot with its location" |
| AC-6.1, AC-6.2 (forms), AC-6.7 (add, edit) | 4 | `lots_spec` "never 500 when the location is removed meanwhile" |
| Story 3 (AC-3.1 to AC-3.12), P4, P6, D4 (move), AC-5.6, AC-6.1, AC-6.2 (move) | 5 | `move_spec` ".call! splits"; `lot_moves_spec` "moves copies"; system "moves a lot out of a location and removes it" |
| Story 9 (AC-9.1, 9.2, 9.4 to 9.8) | 6 | `rules_spec` "reads version 3 against its own schema"; `export_format_examples_spec` "version 3"; `name_parity_spec` lot location |
| Story 10 (AC-10.1 to AC-10.11), D5 / D7 (reading) | 6 | `collection_import_spec` "matches on six values", "reads a version 2 file's lots as unplaced" |
| Story 8 (AC-8.1 to AC-8.6) | 7 | `collection_export_spec` "writes version 3 with each lot's location" |
| Story 11 (AC-11.1 to AC-11.11, 11.13, 11.14) | 7 | `apply_spec` "puts every lot in the file's location"; `round_trip_spec` "restores each valid example as version 3" |
| AC-11.12 (50,000 lots, 500 locations) and the NFR queries and cost | 8 (measured), 3 to 5 (query specs) | `query_counts_spec`; `verification.md` |
| Supersessions both directions; ADR; area doc; design system; roadmap; spec 031 note | 8 | By reading, recorded in `verification.md` |

The decision labels: the maintainer's D1 to D6 are decisions 1 to 7 of the spec (D1 to D3 are decisions 1 to 3; D4 and D6 are spread over decisions 4, 5 and 6; D5 is decision 7); P1 to P6 are the confirmed details. Every one appears above.

---

## Phase 0: The column

**Implements:** FR-1 (the database half), NFR reliability and cost. **Satisfies:** AC-7.1 (migration), AC-9.3 (interim). **Files:** `db/migrate/20261023100001_add_location_to_lots.rb`, `db/schema.rb`, `spec/migrations/add_location_to_lots_spec.rb`, `docs/export-format/README.md`, `spec/export_format_document_spec.rb`.

**Read first:** `data-model.md` (the migration, the tables that point at lots), research R1, `app/models/bulk_selection.rb`, `app/models/number_entry.rb`, `app/models/scanner/sitting.rb`, `spec/support/backup_helpers.rb` (the `:committed` context).

**0.1 Failing test.** `spec/migrations/add_location_to_lots_spec.rb` (new directory; RSpec infers nothing here, so tag the type). The example needs rows committed and no surrounding transaction, because the migration runs without one:

```ruby
require "rails_helper"
require Rails.root.join("db/migrate/20261023100001_add_location_to_lots")

# Spec 032 AC-7.1: the migration changes no lot and breaks no pointer to a lot, going down and up. It runs outside a
# transaction (disable_ddl_transaction!), so the examples commit their rows (:committed empties the database around them).
# Down and up go through the Migrator (MigrationContext#run), which wraps a migration in a transaction unless it turns that
# off (migration.rb ddl_transaction), exactly as db:rollback does. Calling Migration#migrate would open none and so pass
# without disable_ddl_transaction!, the very line this spec guards (plan review M4).
RSpec.describe AddLocationToLots, :backup, :committed, type: :model do
  let(:migration) { described_class.new }
  let(:version) { 2026_10_23_100001 }
  let(:context) { ActiveRecord::Base.connection_pool.migration_context }
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:session) { user.sessions.create! }

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up unless Lot.connection.column_exists?(:lots, :location_id)
    Lot.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def down = context.run(:down, version)

  def up = context.run(:up, version)

  def count(table) = Lot.connection.select_value("SELECT COUNT(*) FROM #{table}") # Safe: a literal table name from this spec

  def lot_rows = Lot.connection.select_rows("SELECT id, catalog_entry_id, quantity, finish, condition, price_paid_cents, lot_key, created_at, updated_at FROM lots ORDER BY id")

  def pick(selection, *lots) = selection.record!(shown_ids: [], ticked_ids: lots.map(&:id), header_rendered: false, header_ticked: false)

  # Every kind of row that points at a lot: a mark, a number-entry line, a scanner entry, and an undoable removal.
  def fill
    kept = owned_printing("Opt", account:, quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 150)
    gone = owned_printing("Shock", account:)
    selection = BulkSelection.for(session)
    pick(selection, gone)
    BulkRemoval.remove!(selection)
    pick(selection, kept)
    NumberEntry.add!(account:, entry: kept.entry, quantity: 1, finish: "foil", line_key: NumberEntry.new_line_key)
    Scanner::Sitting.add!(account:, printing: kept.entry, finish: "foil", reading_key: SecureRandom.hex(16)) # the printing must be searchable; the factory's is
  end

  it "turns the migration's transaction off, so a rollback rebuilds lots with foreign keys off (research R1)" do
    expect(described_class.disable_ddl_transaction).to be(true)
  end

  it "keeps every lot, mark, line, entry and undoable removal going down and up", :aggregate_failures do
    fill
    before = [ lot_rows, count("bulk_selection_marks"), count("number_entry_lines"), count("scanner_sitting_entries"), count("bulk_removals") ]

    down
    expect(Lot.connection.column_exists?(:lots, :location_id)).to be(false)
    expect([ lot_rows, count("bulk_selection_marks"), count("number_entry_lines"), count("scanner_sitting_entries"), count("bulk_removals") ]).to eq(before)

    up
    expect(Lot.connection.column_exists?(:lots, :location_id)).to be(true)
    expect([ lot_rows, count("bulk_selection_marks"), count("number_entry_lines"), count("scanner_sitting_entries"), count("bulk_removals") ]).to eq(before)
    expect(Lot.connection.select_values("SELECT location_id FROM lots")).to all(be_nil)
    expect(BulkRemoval.last).to be_undoable
  end

  it "points every mark, number-entry line and scanner entry at the lot it had", :aggregate_failures do
    fill
    pointers = %w[bulk_selection_marks number_entry_lines scanner_sitting_entries].to_h { |table| [ table, Lot.connection.select_rows("SELECT id, lot_id FROM #{table} ORDER BY id") ] } # Safe: literal table names
    down
    up
    pointers.each do |table, rows|
      expect(rows.map(&:last)).to all(be_present)
      expect(Lot.connection.select_rows("SELECT id, lot_id FROM #{table} ORDER BY id")).to eq(rows) # Safe: literal table names
    end
  end

  it "refuses to go down while a lot is in a location, saying how many", :aggregate_failures do
    Lot.where(id: owned_printing("Opt", account:).id).update_all(location_id: create(:location, account:).id) # the model has no place yet (Phase 1)
    expect { migration.migrate(:down) }.to raise_error(ActiveRecord::IrreversibleMigration, /1 lot/) # Migration#migrate itself: the Migrator would re-wrap the error
    expect(Lot.connection.column_exists?(:lots, :location_id)).to be(true)
  end

  it "finishes a run that stopped between its two steps" do
    Lot.connection.remove_index :lots, :location_id # the state a crash between ADD COLUMN and CREATE INDEX leaves
    migration.migrate(:up)
    expect([ Lot.connection.column_exists?(:lots, :location_id), Lot.connection.index_exists?(:lots, :location_id) ]).to eq([ true, true ])
  end
end
```

(`down` and `up` run the migration through `MigrationContext#run`, which also moves its `schema_migrations` row, so the `around` hook restores both. `connection_pool.migration_context` is `:nodoc:` in Rails 8.1.4; if it moves, `ActiveRecord::MigrationContext.new(ActiveRecord::Base.connection_pool.migrations_paths, schema_migration, internal_metadata)` is the same object. `owned_printing` is `spec/support/collection_helpers.rb`; the executor adjusts the `BulkSelection#record!` calls to the signatures in `app/models/bulk_selection.rb`. The "refuses" example needs Phase 1's `Lot#location` and is written in Phase 1 step 1.0; in Phase 0 it uses `Lot.connection.execute("UPDATE lots SET location_id = …")` against a `locations` row inserted with SQL. Both read the same.) Run it: it fails at `require` (no migration file).

**0.2 Implement.** `db/migrate/20261023100001_add_location_to_lots.rb`:

```ruby
# Puts a lot in one of its account's locations, or in none (spec 032 decision 1, ADR 0025). The lot's existing values and
# its key are untouched: every lot is unplaced, and an unplaced lot's key is what it was.
class AddLocationToLots < ActiveRecord::Migration[8.1]
  # SQLite copies a table to remove a column from it or to add a constraint to it, and with foreign keys enforced the copy's
  # DROP TABLE would run the ON DELETE actions of the tables that point at lots (marks, number-entry lines, scanner
  # entries). Rails turns enforcement off for the copy only outside a transaction (sqlite3_adapter.rb,
  # disable_referential_integrity), so this migration runs without one. Each step is guarded, so a run that stopped between
  # them is finished by the next.
  disable_ddl_transaction!

  def up
    # ADD COLUMN copies no table; SQLite accepts REFERENCES on it when the default is NULL, which is every lot's value.
    execute "ALTER TABLE lots ADD COLUMN location_id integer REFERENCES locations (id) ON DELETE RESTRICT" unless column_exists?(:lots, :location_id)
    add_index :lots, :location_id unless index_exists?(:lots, :location_id)
  end

  def down
    placed = select_value("SELECT COUNT(*) FROM lots WHERE location_id IS NOT NULL").to_i
    raise ActiveRecord::IrreversibleMigration, "#{placed} #{placed == 1 ? "lot is" : "lots are"} in a location; move them out before rolling back" if placed.positive?

    remove_index :lots, :location_id if index_exists?(:lots, :location_id)
    remove_column :lots, :location_id if column_exists?(:lots, :location_id)
  end
end
```

(`placed` message: the example expects `/1 lot/`.) Run `bin/rails db:migrate`; `db/schema.rb` gains `t.integer "location_id"`, `t.index ["location_id"], name: "index_lots_on_location_id"` and `add_foreign_key "lots", "locations", on_delete: :restrict`, and the version `2026_10_23_100001`; restore the other three schema files. Run the new spec: green. If the second example shows the marks gone after `down`, research R1's reading is wrong and the plan stops here for the maintainer (nothing else in the plan depends on a rebuild). Once, to see the guard work, comment out `disable_ddl_transaction!`: that example must turn red (the Migrator's transaction makes the rebuild's `PRAGMA foreign_keys = OFF` a no-op, so the marks cascade away); put the line back.

**0.3 Failing test, Coverage** (made before the commit below, so no commit leaves the suite red; plan review m10). With the column in the schema, `bin/rspec spec/export_format_document_spec.rb` now fails "accounts for every column of a table that isn't left out whole" (`lots.location_id` is not listed). Fix both sides: in `docs/export-format/README.md`'s Coverage table add `| `lots.location_id` | Left out | Not in the file until version 3 (spec 032, Phase 6 of its plan). |` and change `lots.lot_key`'s Why to "Derived from the finish, the condition, the price paid and the location."; in `spec/export_format_document_spec.rb` add `lots.location_id` to the `left_out` `match_array` list. (Phase 6 maps it to `location` and removes it from that list.)

**Green gate:** `bin/rspec` (whole), `bin/rubocop`. **Commit:** one, `feat(db): add lots.location_id (#45)`: the migration, `db/schema.rb`, the migration spec, the Coverage row and the document spec's `left_out` line.

---

## Phase 1: A lot knows its place

**Implements:** FR-1, decisions 1, 2. **Satisfies:** AC-1.3, AC-1.4, AC-1.5 (model), AC-2.2 to AC-2.6 (model), AC-6.6, AC-5.5 (database), AC-7.2. **Files:** `app/models/lot.rb`, `app/models/location.rb`, `app/models/account.rb`, `spec/models/lot_spec.rb`, `spec/models/location_spec.rb`, `spec/models/account_spec.rb` (new), `spec/models/number_entry_spec.rb`, `spec/models/scanner/sitting_spec.rb`, `spec/requests/catalog/quick_adds_spec.rb`, `spec/migrations/add_location_to_lots_spec.rb` (the "refuses" example written with models).

**1.1 Failing tests** (all red until 1.2):

- `lot_spec` ".key_for": `Lot.key_for("foil", "near_mint", 150)` is `"foil|near_mint|150"`, `Lot.key_for(nil, nil, nil)` is `"||"` (today's values, AC-7.1), and with a location id `Lot.key_for("foil", "near_mint", 150, 7)` is `"foil|near_mint|150|7"` and `Lot.key_for(nil, nil, nil, 7)` is `"|||7"`.
- ".add!" (AC-1.3, AC-1.4, AC-1.5), with `blue = create(:location, account:)` and `box = create(:location, account:)`: adding 4 then 2 of one identity to `blue` is one lot of 6 in `blue`; adding 2 to no location makes a second lot (4 and 2); 9,998 in `blue` then 2 more to `blue` raises `ActiveRecord::RecordInvalid` with `Lot::FULL_MESSAGE` on `quantity` and changes nothing, while the same 2 to `box` succeeds.
- "refuses another account's location": `Lot.add!(account:, entry:, location: create(:location))` (the factory's own account) raises `RecordInvalid` on `:location`.
- "#revise!" (AC-2.2 to AC-2.6): a lot of 4 in `box` revised to `location: blue` keeps its id and `created_at`, has `updated_at` after the save, key ends in `|<blue.id>`; with a lot of 3 in `blue` of the same identity, the revised lot is destroyed and the other holds 7; with 9,997 there it raises with both lots unchanged; revised to `location: nil` with an unplaced twin merges into the unplaced one; quantity and location changed in one `revise!` end with the new quantity in the new place.
- "the unique index" (`lot_spec`): two `insert` calls with one `lot_key` raise `ActiveRecord::RecordNotUnique`; one placed and one unplaced of the same printing, finish, condition and price succeed.
- `location_spec` "can't be deleted while a lot is in it (AC-5.5)": `expect { Location.where(id: location.id).delete_all }.to raise_error(ActiveRecord::InvalidForeignKey)`, and the row is still there.
- `account_spec` (new, `type: :model`) "deletes its lots before its locations (AC-6.6)": an account with two locations and lots in both, `user.destroy!` (a `belongs_to :account, dependent: :destroy`) succeeds and `Lot`, `Location` and `Account` counts for it are 0.
- AC-7.2: with an unplaced lot and a lot in `blue` of one printing, finish, condition and price, `NumberEntry.add!`, `Scanner::Sitting.add!` and the tile quick add (`POST /catalog/entries/:key/quick_add`) each leave the lot in `blue` unchanged and add the copy to the unplaced lot. (Spec 026 and 009 files, and `quick_adds_spec`.)
- The lost race of AC-6.7 at the model (m5): a location found and then deleted by SQL (`Location.where(id: location.id).delete_all`) makes `Lot.add!(account:, entry:, location:)` and `lot.revise!(location:)` raise `ActiveRecord::InvalidForeignKey`, and no lot is written. (The requests that map it to 404 are proved in Phases 4 and 5 without a stub.)
- `add_location_to_lots_spec` "refuses to go down while a lot is in a location" is written with `create(:lot, location:)` now.

**1.2 Implement.** `app/models/lot.rb` (the class comment gains "and location, ADR 0025"):

```ruby
belongs_to :account
belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id
belongs_to :location, optional: true # nil is unplaced (spec 032 decision 2)

validate :quantity_within_cap, :finish_offered, :condition_known
validate :location_is_the_accounts, if: :location_id_changed? # only a new place is checked: a bulk condition change saves many lots

before_validation { self.lot_key = self.class.key_for(finish, condition, price_paid_cents, location_id) }

# The lot's identity as text (ADR 0025): an unplaced lot's key is what it was before locations; a placed lot's ends in the
# location's id, not its name, so renaming a location keeps every key.
def self.key_for(finish, condition, price_paid_cents, location_id = nil)
  key = [ finish, condition, price_paid_cents ].join("|")
  location_id ? "#{key}|#{location_id}" : key
end

def self.add!(account:, entry:, quantity: 1, finish: nil, condition: nil, price_paid_cents: nil, location: nil)
  retried = false
  begin
    transaction do
      lot = find_or_initialize_by(account:, entry:, lot_key: key_for(finish.presence, condition.presence, price_paid_cents, location&.id))
      lot.assign_attributes(finish:, condition:, price_paid_cents:, location:, quantity: lot.quantity.to_i + quantity.to_i)
      lot.save!
      lot
    end
  rescue ActiveRecord::RecordNotUnique
    raise if retried

    retried = true
    retry
  end
end
```

and, private, `def location_is_the_accounts = errors.add(:location, "isn't one of your locations") if location && location.account_id != account_id`. `revise!` is unchanged: `validate!` runs `before_validation`, which rebuilds `lot_key` with `location_id`, so `other = where(account_id:, catalog_entry_id:, lot_key:)` finds the twin in the new place.

`app/models/location.rb`: add `has_many :lots, dependent: nil # a location that holds lots can't be deleted: the foreign key refuses it (spec 032 decision 3)`. `app/models/account.rb`: keep the two declarations in this order and add above them `# Order matters: the foreign key from a lot to its location refuses deleting a location a lot is in, so the lots go first. spec/models/account_spec.rb guards it (spec 032 AC-6.6).`

**Green gate:** whole `bin/rspec`, `bin/rubocop`. **Commits:** `feat(lots): a lot is in a location or in none (#45)`; `test(lots): unplaced adds keep joining the unplaced lot (#45)`.

---

## Phase 2: Merging keeps places

**Implements:** Story 7, P5. **Satisfies:** AC-7.3 to AC-7.8. **Files:** `app/models/lot/condition_change.rb`, `app/models/bulk_removal.rb`, `app/controllers/collections/bulk_removals/undos_controller.rb`, `app/helpers/collections_helper.rb`; `spec/models/lot/condition_change_spec.rb`, `spec/models/bulk_removal_spec.rb`, `spec/requests/bulk_removal_spec.rb`, `spec/requests/bulk_condition_spec.rb`, `spec/models/number_entry/line_spec.rb`, `spec/models/scanner/sitting_entry_spec.rb`, `spec/requests/lots_spec.rb`.

**2.1 Failing tests.**

- `condition_change_spec` (AC-7.3): lots of one printing, finish and price in `blue` and in `box`, both near mint, set to lightly played: each keeps its place (`location_id` unchanged, `lot_key` ends in its place); a lot in `blue` with a lightly-played twin in `blue` merges into it, while a lot in `box` with a lightly-played twin in `blue` does not; the 9,999 check applies per place (a merge in `blue` over the cap raises `Lot::CapExceeded` and a second place with room is unchanged). A lot alone (no merge) in `blue` gets `lot_key` equal to `Lot.key_for(finish, "lightly_played", price, blue.id)` (the raw SQL builds it).
- `bulk_removal_spec`: "removes the selected lots, keeping them for one undo" now expects `"location_id" => nil` in `lots_data` (change the existing expectation in this phase); a lot in `blue` is saved with `"location_id" => blue.id`; "restores each lot to its place" (AC-7.4): lots in `blue` and unplaced come back in `blue` and unplaced and merge per place with lots added since; "restores a lot whose location was removed unplaced" (AC-7.5, P5): remove the lots (so `blue` is empty), `blue.destroy!`, Undo: the lot is unplaced and `undo!` returns a result whose `unplaced` is 1; "merges restored rows that share an identity" (AC-7.8): a lot in `blue` and an unplaced lot of one identity, quantities 3 and 4, `blue` removed, Undo gives one unplaced lot of 7; with 9,999 and 1 it raises `Lot::CapExceeded` naming the entry (O2, ruled 2026-10-24), nothing is restored and the removal is still undoable; when an existing lot would overflow too, the exception names that lot (the first by the table's sort), not a restored row (O2); a removal whose saved lots have no `location_id` key (build `lots_data` by hand) restores them unplaced (AC-7.8); a lot in `blue` and a lightly different existing lot in `blue` merge only within `blue`.
- `bulk_removal` request spec: the notice after an Undo with one lot back without a location reads "Restored 7 copies to your collection. 1 lot came back without a location."; with none it is unchanged.
- AC-7.6 (`line_spec`, `sitting_entry_spec`): a line or entry whose lot was moved whole to an empty place (`lot.update!(location: blue)`) undoes against the same lot; a lot merged away by a whole move (`Lot::Move` is Phase 5; here use `lot.revise!(location: blue)` into a twin) leaves the line not undoable and the entry `:changed`; a number-entry line added 3 whose lot now holds 2 (moved 1 away by `revise!`/split in Phase 5) is not undoable. The examples that need `Lot::Move` are written in Phase 5 step 5.1; the ones with `revise!` run now.
- AC-7.7 (`lots_spec`): removing a single lot that is in a location removes it, leaves the location, and `BulkRemoval.supersede!` makes the earlier bulk removal no longer undoable.

**2.2 Implement.**

`Lot::ConditionChange`: the group key and the raw SQL carry the place.

```ruby
groups = lots.group_by { |lot| [ lot.catalog_entry_id, Lot.key_for(lot.finish, @condition, lot.price_paid_cents, lot.location_id) ] }
```

```ruby
@account.lots.where(id: ids).update_all([ "condition = ?, lot_key = COALESCE(finish, '') || '|' || ? || '|' || COALESCE(price_paid_cents, '') || COALESCE('|' || location_id, ''), updated_at = ?", @condition.presence, @condition.to_s, Time.current ]) # Safe: … (keep the existing justification) ; '|' || NULL is NULL, so an unplaced lot keeps the key it had
```

`merge` is unchanged (`survivor.update!` rebuilds the key; the place is unchanged so the validation of 1.2 doesn't run).

`BulkRemoval`:

```ruby
lots_data: lots.map { |lot| lot.slice(:catalog_entry_id, :finish, :condition, :price_paid_cents, :quantity, :location_id) })
```

```ruby
# What came back: how many saved lots had a location the account no longer has and so came back unplaced (P5).
Undone = Data.define(:unplaced)

# Puts back the removed lots, each in the location it was in if the account still has it, else in none; saved lots that then
# share an identity are one lot with the summed quantity, merging into the lot of that identity if there is one. All or
# nothing (spec 006 AC-7.4, AC-7.5; spec 032 P5, AC-7.8).
def undo!(sort:)
  raise NotUndoable unless undoable?

  transaction do
    entries = Catalog::Entry.where(id: lots_data.pluck("catalog_entry_id")).index_by(&:id)
    Catalog::Entry.preload_extensions(entries.values)
    locations = account.locations.where(id: lots_data.filter_map { |data| data["location_id"] }).index_by(&:id)
    unplaced = lots_data.count { |data| data["location_id"] && !locations.key?(data["location_id"]) }
    rows = restored_rows(locations)
    existing = existing_lots(rows)
    check_cap!(rows, existing, entries, sort)
    merging, alone = rows.partition { |row| existing.key?(identity(row)) }
    insert_alone!(alone)
    merging.each do |row|
      Lot.add!(account:, entry: entries.fetch(row["catalog_entry_id"]), quantity: row["quantity"], finish: row["finish"],
        condition: row["condition"], price_paid_cents: row["price_paid_cents"], location: locations[row["location_id"]])
    end
    update!(lots_data: nil)
    Undone.new(unplaced:)
  end
end
```

(`unplaced` is counted before `lots_data` is cleared, and the account's locations are read once, so the number of queries doesn't grow with the lots.) Private:

```ruby
# The saved lots with a location the account no longer has set to none, and those that then share an identity made one.
def restored_rows(locations)
  lots_data.map { |data| data.merge("location_id" => (data["location_id"] if locations.key?(data["location_id"]))) }
    .group_by { |row| identity(row) }.values.map { |group| group.first.merge("quantity" => group.sum { |row| row["quantity"] }) }
end

def existing_lots(rows)
  account.lots.where(catalog_entry_id: rows.pluck("catalog_entry_id").uniq).index_by { |lot| [ lot.catalog_entry_id, lot.lot_key ] }
end

def identity(data) = [ data["catalog_entry_id"], Lot.key_for(data["finish"], data["condition"], data["price_paid_cents"], data["location_id"]) ]

# An existing lot that would pass 9,999 is named first, by the table's sort (spec 006 AC-7.5); if only the restored rows
# together pass it there is no lot of the account to name, so the first such row is (research R4, O2 as the maintainer ruled it on 2026-10-24).
def check_cap!(rows, existing, entries, sort)
  over = rows.select { |row| row["quantity"] + (existing[identity(row)]&.quantity || 0) > Lot::MAX_QUANTITY }
  return if over.empty?

  held = over.filter_map { |row| existing[identity(row)] }
  raise Lot::CapExceeded, sort.apply(account.lots.joins(entry: :set).where(id: held.map(&:id))).preload(entry: :set).first if held.any?

  raise Lot::CapExceeded, Lot.new(entry: entries.fetch(over.first["catalog_entry_id"]))
end
```

`insert_alone!` keeps its shape and slices `"location_id"` too: `data.slice("catalog_entry_id", "quantity", "finish", "condition", "price_paid_cents", "location_id").merge("lot_key" => identity(data).last, …)`. `identity(data)` for a pre-migration row reads `data["location_id"]` as nil. `existing_lots` is evaluated before inserts, in the transaction (IMMEDIATE), so the "each identity is free" claim in `insert_alone!`'s comment still holds.

`Collections::BulkRemovals::UndosController#create`:

```ruby
undone = removal.undo!(sort: return_sort)
redirect_to return_path, status: :see_other,
  notice: "Restored #{helpers.items_count(removal.copies)} to your collection.#{helpers.restored_without_location(undone.unplaced)}"
```

`CollectionsHelper`: `def restored_without_location(count) = count.positive? ? " #{pluralize(count, "lot")} came back without a location." : ""`.

**Green gate:** whole `bin/rspec`, `bin/rubocop`. **Commits:** `feat(bulk): bulk condition change and removal keep each lot's place (#45)`; `feat(bulk): Undo restores a removed location's lots unplaced and merges them (#45)`.

---

## Phase 3: A location that holds copies can't be removed

**Implements:** decision 3, P1, P2, Story 5. **Satisfies:** AC-4.3, AC-5.1 to AC-5.7, AC-6.3, AC-6.4, AC-6.5 (locations pages), AC-6.7 (removal side). **Files:** `app/models/location.rb`, `app/models/location/holdings.rb` (new), `app/controllers/locations_controller.rb`, `app/controllers/locations/removals_controller.rb`, `app/views/locations/index.html.erb`, `app/views/locations/removals/refused.html.erb` (new), `app/helpers/locations_helper.rb` (new), `app/helpers/lots_helper.rb`, `app/assets/stylesheets/collector/additions.css`; `spec/models/location/holdings_spec.rb` (new), `spec/requests/locations_spec.rb`, `spec/requests/admin/users_spec.rb` (or the admin pages' spec), `spec/requests/query_counts_spec.rb`, `spec/system/locations_spec.rb`, `spec/import_apply_core_spec.rb`.

**Read first:** `docs/design-system/components/{ConfirmPage,Locations}.md`, `app/views/locations/removals/new.html.erb`, `app/views/collections/import_previews/show.html.erb` (the `c-import__more` rule it uses).

**3.1 Failing tests.**

- `holdings_spec`: `Location::Holdings.counts(account)` returns lots and copies per placed location in two statements (count the queries) and `Count.new(lots: 0, copies: 0)` for any other id; `location.holdings` has `lots_count`, `copies`, `any?`, and `listed`: at most 100 lots ordered by entry name, set code, collector number, language, finish, condition, price paid (P1), each with its entry and set loaded, `more` is the rest.
- `locations_spec` (request): the index reads "12 copies in 3 lots", "1 copy in 1 lot" and "Empty" for three locations (AC-4.3); an empty location's `GET …/removal/new` is the existing confirmation (AC-5.1) and confirming removes it, leaves lots alone and redirects 303 with "Removed “Box”."; a location with 3 lots (12 copies): the page says "“Blue binder” holds 12 copies in 3 lots. Move them before removing it.", lists the lots with ×quantity and a link to the card page's copies, links "Back to locations" and has no Remove button (AC-5.2); 250 lots: 100 listed, ordered, and "and 150 more" (AC-5.3, create 250 lots of one printing with distinct prices so the order is the price's); `DELETE` of a location that holds lots is 409 with the same page, the location exists and no lot changed (AC-5.4); open the confirmation of an empty location, put a lot in it, send `DELETE`: 409 and nothing removed (AC-5.5); two accounts each with a "Box" and placed lots: neither the index nor the refusal page shows a count, lot or name of the other (AC-5.7, AC-6.3); a signed-out `GET` and `DELETE` are sent to sign in (AC-6.5); `DELETE` of another account's location is 404 (spec 029 AC-4.1 stays).
- Admin: the admin users page shows account-level copy counts only, no location name (AC-6.4).
- A location name with markup is output escaped on the locations page and the refusal page (AC-4.5).
- `query_counts_spec`: the locations page runs the same number of queries with 1 and with 30 locations that hold lots; the refusal page with 5 and with 40 lots in the location.
- `spec/system/locations_spec.rb`: the refusal page at 360px has no horizontal scroll (reuse `open_in_narrow_frame`) and "Remove" is absent; keyboard can reach "Back to locations" (AC-5.2); every lot link and "Back to locations" is at least 44px high and wide (the floor of spec 029 AC-5.5, which `Locations.md` says holds for every control on these pages), measured as that spec's examples measure theirs.
- `import_apply_core_spec` lists `app/models/location/holdings.rb`, `app/views/locations/removals/refused.html.erb` and `app/helpers/locations_helper.rb`, added with the files in 3.2 (m7).

**3.2 Implement.**

`app/models/location/holdings.rb`:

```ruby
# What an account's lots hold in a location (spec 032 P1, P2): the totals, and the first lots for the page that refuses a
# removal. Collectible-agnostic: a lot is a quantity of an entry, the entry names it.
class Location::Holdings
  LISTED = 100 # as many lots as the import preview lists (spec 025 decision 11)
  Count = Data.define(:lots, :copies)
  EMPTY = Count.new(lots: 0, copies: 0)

  # Every location's totals for the locations page, in two grouped statements whatever the number of locations or lots.
  def self.counts(account)
    placed = account.lots.where.not(location_id: nil).group(:location_id)
    copies = placed.sum(:quantity)
    placed.count.to_h { |id, lots| [ id, Count.new(lots:, copies: copies.fetch(id)) ] }.tap { |counts| counts.default = EMPTY }
  end

  def initialize(location)
    @lots = Lot.where(account_id: location.account_id, location_id: location.id) # the location came from the signed-in account; the scope is by value, so it costs no query
  end

  def lots_count = @lots_count ||= @lots.count
  def copies = @copies ||= @lots.sum(:quantity)
  def any? = lots_count.positive?
  def total = Count.new(lots: lots_count, copies:)
  def more = lots_count - listed.size

  # The first LISTED lots, as the import preview orders lots: name, set code, number, language, finish, condition, price paid.
  def listed
    @listed ||= @lots.joins(entry: :set).preload(entry: :set).limit(LISTED).order(
      Catalog::Entry.arel_table[:name].asc, Catalog::Set.arel_table[:code].asc, Catalog::Entry.arel_table[:number].asc,
      Catalog::Entry.arel_table[:language].asc, Lot.arel_table[:finish].asc, Lot.arel_table[:condition].asc,
      Lot.arel_table[:price_paid_cents].asc).to_a
  end
end
```

(The price orders by cents, not by the preview's text: only lots equal in every earlier column differ, and the number is the sensible order; noted in `verification.md`.) `Location`: `def holdings = Holdings.new(self)`.

`LocationsController`:

```ruby
def index
  @location = Location.new
  @locations = Current.account.locations.ordered.to_a
  @holdings = Location::Holdings.counts(Current.account)
end
```
(and `create`'s 422 branch sets `@holdings` too.)

```ruby
# A location that holds lots is refused (spec 032 decision 3), here and in the database: a lot put in it after the
# confirmation page opened is caught by the check, one put in it between the check and the delete by the foreign key.
def destroy
  holdings = @location.holdings
  return refuse(holdings) if holdings.any?

  @location.destroy!
  redirect_to locations_path, notice: "Removed “#{@location.name}”.", status: :see_other
rescue ActiveRecord::InvalidForeignKey
  refuse(@location.holdings)
end

private
  def refuse(holdings)
    @holdings = holdings
    render "locations/removals/refused", status: :conflict
  end
```

`Locations::RemovalsController#new`: after finding `@location`, `@holdings = @location.holdings` and `render :refused if @holdings.any?`.

`app/views/locations/removals/refused.html.erb`:

```erb
<% content_for :title, "Remove location · Collector" %>
<%= render "layouts/appbar", section: :locations, detail: true, back_path: locations_path %>
<main class="c-main c-page c-locations">
  <section class="c-confirm">
    <h1 class="c-pagehead__title">“<%= @location.name %>” isn't empty</h1>
    <p>“<%= @location.name %>” holds <%= location_holds(@holdings.total) %>. Move them before removing it.</p>
    <ul class="c-list c-locations__lots" id="held_lots">
      <% @holdings.listed.each do |lot| %>
        <li>
          <span><%= link_to lot.entry.name, catalog_entry_path(lot.entry, from: "collection", anchor: "copies") %> <span class="c-list__meta"><%= lot_line(lot) %></span></span>
          <span class="c-list__end">×<%= number_with_delimiter(lot.quantity) %></span>
        </li>
      <% end %>
    </ul>
    <% if @holdings.more.positive? %><p class="c-locations__more">and <%= number_with_delimiter(@holdings.more) %> more</p><% end %>
    <div class="c-form__actions">
      <%= link_to "Back to locations", locations_path, class: "c-btn c-btn--secondary" %>
    </div>
  </section>
</main>
<%= render "layouts/tabbar", section: nil %>
```

`LocationsHelper`:

```ruby
module LocationsHelper
  # "12 copies in 3 lots", "1 copy in 1 lot", "Empty" (spec 032 P2).
  def location_holds(count)
    return "Empty" if count.lots.zero?

    "#{pluralize(number_with_delimiter(count.copies), "copy")} in #{pluralize(number_with_delimiter(count.lots), "lot")}"
  end
end
```

`LotsHelper#lot_line(lot)` builds on the existing `lot_summary` (set and number, finish, condition, language, joined by " · ") and adds the price paid, the one value that tells two lots of a printing, finish and condition apart in a list: `def lot_line(lot) = [ lot_summary(lot), (lot_price(lot) if lot.price_paid_cents) ].compact.join(" · ")` (plan review m3; no second copy of the join). `locations/index.html.erb`: inside each `<li>`, after the name, `<span class="c-list__meta c-locations__holds"><%= location_holds(@holdings[location.id]) %></span>`. `additions.css`: `.c-locations__more` with the declarations of `.c-import__more` (copy them; tokens only); `.c-locations__lots a { display:inline-flex; align-items:center; min-height:var(--touch-floor); }`, because the lot links are not `c-btn` and `additions.css`'s floor rule (`.c-locations .c-btn`) doesn't reach them (plan review m2; the class now has a rule, and `Locations.md` documents it in Phase 8 step 4); and, if the counts need breathing room at 360px, `.c-locations__holds { flex-basis:100%; }` using no new value. Add the three files of 3.1's last bullet to `spec/import_apply_core_spec.rb`.

**Green gate:** whole `bin/rspec`, `bin/rubocop`. **Commits:** `feat(locations): count what each location holds (#45)`; `feat(locations): a location that holds lots can't be removed (#45)`.

---

## Phase 4: The add and edit forms, and the card page

**Implements:** decisions 4, 5, 6; P3; Story 1, Story 2, Story 4. **Satisfies:** AC-1.1, AC-1.2, AC-1.5 to AC-1.9, AC-2.1, AC-2.2, AC-2.7, AC-2.8, AC-4.1, AC-4.2, AC-4.4, AC-4.5, AC-6.1, AC-6.2 (forms), AC-6.7 (add, edit). **Files:** `app/models/lot/form.rb`, `app/controllers/lots_controller.rb`, `app/views/lots/{_form,new,edit}.html.erb`, `app/models/catalog/card_overview.rb`, `app/views/catalog/entries/_copies.html.erb`, `app/helpers/lots_helper.rb`; `spec/requests/lots_spec.rb`, `spec/requests/catalog/entries_show_spec.rb`, `spec/models/catalog/card_overview_spec.rb`, `spec/requests/collections_spec.rb` (totals), `spec/requests/query_counts_spec.rb`, `spec/system/card_page_spec.rb`.

**Read first:** `docs/design-system/components/{Form,ItemPage,CollectionTable}.md`, `app/views/lots/_form.html.erb`.

**4.1 Failing tests** (`lots_spec` unless noted; helpers: `blue = create(:location, account:, name: "Blue binder")`):

- Add form opens with a "Location" select offering "No location" (selected) then "Blue binder" and "Long box" in `Location.ordered` order (AC-1.1); submitting quantity 4 with `blue` creates one lot of 4 in `blue`, 303 to the card page, notice "Added 4 × <name> (<set> <number>) to Blue binder."; "No location" reads "…to your collection." (AC-1.2); 9,998 + 2 into the same place is 422 with the cap message beside Quantity and no change, while the other place accepts (AC-1.5); a 422 for quantity 0 keeps the chosen location selected (AC-1.6); another account's location id and a missing id answer 404, creating nothing (AC-1.7, AC-6.1); a request without the key, or blank, is unplaced (AC-1.8); an account without locations sees no select and "Add a location to keep copies in one." linking to `locations_path` (AC-1.9, P3); the lost race answers 404, not 500 (AC-6.7), with no stub (plan review m5): an `ActiveSupport::Notifications` subscriber on `sql.active_record` deletes the chosen location with SQL right after the request's lookup statement (`SELECT … FROM "locations"`), once, so the real foreign key refuses the insert and `rescue_from` answers 404; the same subscriber for the edit (AC-6.7) in the next bullet.
- Edit form has the lot's place selected, "No location" for an unplaced lot (AC-2.1); saving `location_id: blue` moves the same lot (same id, same `created_at`, new `updated_at`), 303 to `lot_return_path`, "Saved." (AC-2.2); the same from the collection table's `return_to` and from a scanner Details link returns there (AC-2.8, within the existing "from the collection table" describe); another account's location is 404 and the lot is unchanged (AC-2.7); a request that leaves `location_id` out keeps the lot's place, a blank one unplaces it (O3, ruled 2026-10-24); the lost race on the edit is 404 in the same way (AC-6.7); editing into a place that holds a twin makes one lot (AC-2.3), a merge that would pass 9,999 is 422 with "One lot can hold at most 9,999 copies." beside Quantity and both lots as they were (AC-2.4), and a quantity and a place changed in one save end with the new quantity in the new place (AC-2.6): the three by request, as the model examples of Phase 1 already prove them (plan review m8).
- `entries_show_spec`: a card with lots in `blue` and unplaced, of one printing and of several, shows a row per lot, each with a Location cell reading the place or "No location", ordered as today and then unplaced first, then `Location.ordered` (AC-4.1); the line under the printing carries the place; a printing with 2 in `blue` and 2 in `box` lists two lots and "4 in 2 lots" (AC-4.2); a location name with markup renders escaped (AC-4.5); two lots of one printing and condition in different places have different action-menu names, "Actions for DMR · 27 NM in Blue binder" and "…, no location" (plan review m1, TableActions: the label names the row).
- `collections_spec`: the grid and table, the totals and the filter bar's counts include placed lots exactly as unplaced ones and show no location (AC-4.4).
- `query_counts_spec`: the card page with 1 and with 20 placed lots, the add form with 1 and 30 locations.

**4.2 Implement.**

`Lot::Form`: add `attribute :location_id, :string`; `from(lot)` passes `location_id: lot.location_id&.to_s`; `lot_attributes` is unchanged (the controller resolves the location).

`LotsController`:

```ruby
before_action :set_locations, only: %i[new create edit update]

# The location chosen in the form was removed after it was found: the foreign key refused the write (AC-6.7).
rescue_from(ActiveRecord::InvalidForeignKey) { raise ActiveRecord::RecordNotFound }

def new
  @form = Lot::Form.new(entry: @entry)
end

def create
  location = chosen_location
  @form = Lot::Form.new(**lot_params.to_h.symbolize_keys, entry: @entry)
  return render(:new, status: :unprocessable_content) unless @form.valid?

  attributes = @form.lot_attributes
  Lot.add!(account: Current.account, entry: @entry, location:, **attributes)
  redirect_to catalog_entry_path(@entry, **card_params), status: :see_other,
    notice: "Added #{attributes[:quantity]} × #{@entry.name} (#{helpers.set_number(@entry)}) to #{location ? location.name : "your collection"}."
rescue ActiveRecord::RecordInvalid => error
  @form.absorb(error.record)
  render :new, status: :unprocessable_content
end

def update
  place = lot_params.key?(:location_id) ? chosen_location : @lot.location # absent keeps the place; blank is "No location" (O3)
  @form = Lot::Form.new(**{ location_id: @lot.location_id&.to_s }.merge(lot_params.to_h.symbolize_keys), entry: @lot.entry)
  return render(:edit, status: :unprocessable_content) unless @form.valid?

  @lot.revise!(@form.lot_attributes.merge(location: place))
  redirect_to lot_return_path(@lot.entry), status: :see_other, notice: "Saved."
rescue ActiveRecord::RecordInvalid
  @form.absorb(@lot)
  render :edit, status: :unprocessable_content
end

private
  def set_locations = @locations = Current.account.locations.ordered.to_a

  # The account's location the form names, nil for none; another account's, a missing one and text that isn't an id are 404.
  def chosen_location
    id = lot_params[:location_id].presence
    Current.account.locations.find(id) if id
  end

  def lot_params = params.expect(lot: %i[quantity finish condition price_paid location_id])
```

(`edit` sets `@form = Lot::Form.from(@lot)`; `new` and `edit` render with `@locations`.) `revise!` raises `RecordInvalid` for the cap with `@lot`'s errors merged, as today (a failed merge rolls back; `absorb(@lot)` shows the message beside Quantity).

`lots/_form.html.erb` gains `locations:` in its `# locals:` line, `:location` is not in `errors` (no field error is expected), and after the price block:

```erb
<% if locations.any? %>
  <div class="c-field">
    <%= form.label :location_id, "Location", class: "c-field__label" %>
    <%= form.select :location_id, locations.map { |location| [ location.name, location.id ] }, { include_blank: "No location" } %>
  </div>
<% else %>
  <p class="c-field__hint"><%= link_to "Add a location", locations_path %> to keep copies in one.</p>
<% end %>
```

`new.html.erb` and `edit.html.erb` pass `locations: @locations`. (Option text is the escaped `name`; `include_blank` with a string is the "No location" option with an empty value, selected when `location_id` is blank.)

`Catalog::CardOverview#lots`:

```ruby
@lots ||= @account.lots.joins(:entry).left_joins(:location).where(catalog_entries: { catalog_identity_id: identity.id })
  .includes(entry: :set).preload(:location).merge(Catalog::Entry.newest_first).order(:finish, :condition, :price_paid_cents)
  .order(Location.arel_table[:name_key].asc, Location.arel_table[:name].asc).to_a # unplaced first: NULL sorts first (AC-4.1)
```

`_copies.html.erb`: header `<th class="is-opt">Location</th>` after Condition's... (after "Language", before "Qty"), the cell `<td class="is-opt"><%= lot_place(lot) %></td>`, and the sub line `safe_join([ finish, condition, lot_place(lot), language ].compact, " · ")` (the place shows where the optional columns are hidden). `LotsHelper#lot_place(lot) = lot.location&.name || "No location"`. The actions trigger's `aria-label` becomes `lot_actions_label(lot)`, since a split leaves two rows of one printing and condition (plan review m1): `def lot_actions_label(lot) = "Actions for #{set_number(lot.entry)} #{lot_condition(lot)}#{lot.location ? " in #{lot.location.name}" : ", no location"}"` (the attribute is escaped by the template). ("Move copies" in the menu is Phase 5.)

**Green gate:** whole `bin/rspec`, `bin/rubocop`. **Commits:** `feat(lots): choose a location when adding or editing a lot (#45)`; `feat(catalog): the card page shows where each lot is (#45)`.

---

## Phase 5: Move copies

**Implements:** decision 4, P4, P6, Story 3. **Satisfies:** AC-3.1 to AC-3.12 (3.4a included), AC-5.6, AC-6.1, AC-6.2 (move), AC-7.6 (the examples that need a move). **Files:** `config/routes.rb`, `app/models/lot/move.rb` (new), `app/controllers/lots/moves_controller.rb` (new), `app/views/lots/moves/new.html.erb` (new), `app/views/catalog/entries/_copies.html.erb`; `spec/models/lot/move_spec.rb` (new), `spec/requests/lot_moves_spec.rb` (new), `spec/requests/lots_spec.rb` (the signed-out table), `spec/models/number_entry/line_spec.rb`, `spec/models/scanner/sitting_entry_spec.rb`, `spec/requests/query_counts_spec.rb`, `spec/system/lot_moves_spec.rb` (new), `spec/routing/` (a routing example), `spec/import_apply_core_spec.rb`.

**Read first:** `docs/design-system/components/{Form,Menu}.md`, `app/views/lots/edit.html.erb`.

**5.1 Failing tests.**

- `move_spec` (`Lot::Move.new(lot:, to:, copies:)`, `#call!`): all 4 to an empty place keeps the id, `created_at`, sets the place and a later `updated_at` (AC-3.2, P6); 2 of 4 leaves 2 and creates a lot of 2 in the place with the same printing, finish, condition and price paid, `created_at` and `updated_at` of the move (AC-3.3, P6), the account's copies unchanged; into a place with a twin of 3: 2 moved gives 2 and 5 (AC-3.4), all 4 gives one lot of 7 whose id, `created_at` are the twin's and the source gone (AC-3.4a, P6); to `nil` joins or starts the unplaced lot (AC-3.5); a result over 9,999 raises `RecordInvalid` with the cap message on `copies` and both lots as they were (AC-3.6); copies 0, -1, 5 of 4, "x", "" and "4.5" are invalid with "Choose from 1 to 4 copies." (AC-3.7); `to` equal to the lot's own place (both `nil` included) is invalid with "Those copies are already there." (P4); a failure forced after the source was changed leaves both lots unchanged (AC-3.8): create in the example `Lot.connection.execute("CREATE TRIGGER fail_lot_insert BEFORE INSERT ON lots BEGIN SELECT RAISE(ABORT, 'forced'); END")` (rolled back with the example's transaction) and assert the source's quantity and the table are unchanged after the `ActiveRecord::StatementInvalid`; there is no retry on the destination's key (plan review m6): the twin is read inside `Lot.transaction`, which SQLite opens IMMEDIATE (`default_transaction_mode: :immediate`, `sqlite3_adapter.rb:162`), so writers are serialised and no other writer can add the twin between the read and the write; the unique index (Phase 1's example) is the backstop, and `verification.md` says so.
- `lot_moves_spec` (request): the lost race on the destination (AC-6.7) answers 404 with no stub, by the `sql.active_record` subscriber of Phase 4 that deletes the destination right after the request's lookup; `GET /lots/:id/move/new` titled "Move copies of <name> (<set> <number>)", a Copies field (min 1, max the quantity, value the quantity), a "To" select with "No location" first when the lot is placed and the account's other locations, "Move" and "Cancel" (AC-3.1); an unplaced lot's select starts on the first location; `POST` moves and answers 303 to the card page with "Moved 4 × … to Blue binder." / "Moved 2 × … to no location." (AC-3.2, AC-3.3, AC-3.5); 422s with the reasons beside Copies and To, the chosen destination kept (AC-3.6, AC-3.7); another account's lot, destination, or a missing one answers 404 and changes nothing (AC-3.9, AC-6.1, AC-6.2: two accounts with "Box"; the other's rows and `updated_at` times unchanged); an unplaced lot in an account with no locations: "You have no locations yet." with a link and no Move button (AC-3.10, P3); signed-out visitors are sent to sign in and a write without a session fails forgery protection (AC-6.5; add the two paths to the table at the top of `lots_spec.rb`); the card page's lot menu offers "Edit copy", "Move copies" and "Remove" and the collection table's menu has no "Move copies" (AC-3.1).
- `line_spec`, `sitting_entry_spec` (AC-7.6): a line whose lot was moved whole to an empty place undoes against the lot where it is now; a lot merged by a whole move is no longer undoable (line) / `:changed` (entry); a line added 3 whose lot was split to 2 is not undoable and a scanner entry follows its own rule.
- `query_counts_spec`: the Move copies page with 1 and with 30 locations.
- `spec/system/lot_moves_spec.rb`: with the keyboard only, at 360px (`open_in_narrow_frame`) and with the form posting as plain HTML, a collector opens a lot's menu, moves 2 of 4 copies to another place and cancels another move (AC-3.12); the end-to-end of AC-5.6: a location with two lots is refused, each lot is moved out with Move copies, then the removal succeeds and both lots are where they were moved.
- A routing example: `new_lot_move_path(1)` is `/lots/1/move/new`, `lot_move_path(1)` is `/lots/1/move`.

**5.2 Implement.** `config/routes.rb`, inside `resources :lots, only: %i[edit update destroy] do`: add `resource :move, only: %i[new create], module: :lots` after the `removal` line.

`app/models/lot/move.rb`:

```ruby
# Moves some or all of a lot's copies to another location, or to none (spec 032 Story 3, decision 4). It is the Move copies
# form and the move: copies of one identity are one lot, so moving some is a split and moving all to a place that has the
# identity is a merge. All or nothing. Collectible-agnostic.
class Lot::Move
  include ActiveModel::Model
  include ActiveModel::Attributes

  CHOOSE = "Choose from 1 to %d copies.".freeze
  ALREADY_THERE = "Those copies are already there.".freeze

  attribute :copies, :string
  attr_reader :lot, :to

  validate :copies_in_range, :somewhere_else

  # +to+ is a Location of the lot's account, or nil for none.
  def initialize(lot:, to:, copies: lot.quantity.to_s)
    super(copies:)
    @lot, @to = lot, to
  end

  def count = Integer(copies.to_s.strip, 10, exception: false)

  def location_id = to&.id.to_s # the To select's value

  # Returns the lot that now holds the copies. Raises ActiveRecord::RecordInvalid, with the reason on this form, and changes
  # nothing, when the copies or the destination are wrong or the result would pass the cap.
  def call!
    raise ActiveRecord::RecordInvalid, self unless valid?

    # SQLite opens the transaction IMMEDIATE, so the twin read below is read under the write lock: no other writer can add one
    # before this one writes, and the unique index on lot_key stays the backstop.
    Lot.transaction { count == lot.quantity ? move_whole : split }
  rescue ActiveRecord::RecordInvalid => error
    raise if error.record.equal?(self)

    lot.reload # the transaction rolled back; the lot in memory still holds the unsaved change
    errors.add(:copies, Lot::FULL_MESSAGE) if error.record.errors.of_kind?(:quantity, :too_many)
    raise ActiveRecord::RecordInvalid, self
  end

  private
    def move_whole
      other = twin
      return lot.tap { |moved| moved.update!(location: to) } unless other

      other.update!(quantity: other.quantity + lot.quantity) # the destination's lot survives, as Lot#revise! does (P6)
      lot.destroy!
      other
    end

    def split
      other = twin
      lot.update!(quantity: lot.quantity - count)
      return other.tap { |held| held.update!(quantity: held.quantity + count) } if other

      lot.account.lots.create!(entry: lot.entry, finish: lot.finish, condition: lot.condition, price_paid_cents: lot.price_paid_cents,
        location: to, quantity: count)
    end

    # The account's lot with this lot's identity in the destination, if there is one.
    def twin
      lot.account.lots.find_by(catalog_entry_id: lot.catalog_entry_id,
        lot_key: Lot.key_for(lot.finish, lot.condition, lot.price_paid_cents, to&.id))
    end

    def copies_in_range = errors.add(:copies, format(CHOOSE, lot.quantity)) unless count&.between?(1, lot.quantity)

    def somewhere_else = errors.add(:location_id, ALREADY_THERE) if to&.id == lot.location_id
end
```

(`errors.add` in `somewhere_else` is under a different attribute so both reasons can show; `location_id` is the To field's name.)

`Lots::MovesController`:

```ruby
# Spec 032 Story 3: moves some or all of one lot's copies. Every lookup goes through Current.account (decision 6).
class Lots::MovesController < ApplicationController
  before_action :set_lot
  before_action :set_destinations

  rescue_from(ActiveRecord::InvalidForeignKey) { raise ActiveRecord::RecordNotFound } # the destination was removed meanwhile

  def new
    @move = Lot::Move.new(lot: @lot, to: nil)
  end

  def create
    to = destination
    @move = Lot::Move.new(lot: @lot, to:, copies: move_params[:copies])
    @move.call!
    redirect_to catalog_entry_path(@lot.entry, **card_params), status: :see_other,
      notice: "Moved #{@move.count} × #{@lot.entry.name} (#{helpers.set_number(@lot.entry)}) to #{to ? to.name : "no location"}."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  private
    def set_lot = @lot = Current.account.lots.includes(:location, entry: :set).find(params[:lot_id])

    # "No location" first unless the lot is already there, then the account's other locations: the options of the To field.
    def set_destinations
      locations = Current.account.locations.ordered.reject { |location| location.id == @lot.location_id }
      @destinations = (@lot.location_id ? [ [ "No location", "" ] ] : []) + locations.map { |location| [ location.name, location.id ] }
    end

    def destination
      id = move_params[:location_id].presence
      Current.account.locations.find(id) if id
    end

    def move_params = params.expect(move: %i[copies location_id])
end
```

`lots/moves/new.html.erb` (read `Form.md` first): appbar with `detail: true` and `back_path: catalog_entry_path(@lot.entry, **card_params)`, `c-main c-page`, a `c-pagehead` with the h1 "Move copies of <name> (<set> <number>)" and a stats line `lot_line(@lot)`, `lot_place(@lot)`, "×N". When `@destinations.empty?`: `<p class="c-empty">You have no locations yet. <%= link_to "Add a location", locations_path %></p>` and only a Cancel link. Otherwise `form_with model: @move, scope: :move, url: lot_move_path(@lot, **card_params), method: :post, class: "c-form"` with two `c-field`s: Copies (`number_field :copies, min: 1, max: @lot.quantity, step: 1, inputmode: "numeric", required: true`, error from `@move.errors[:copies]` through `shared/field_errors`, the id/`aria-describedby` pattern of `_form.html.erb`) and To (`select :location_id, options_for_select(@destinations, @move.location_id)`, error from `errors[:location_id]`), then `c-form__actions` with `submit "Move", class: "c-btn c-btn--primary"` and `link_to "Cancel", catalog_entry_path(@lot.entry, **card_params), class: "c-btn c-btn--secondary"`. The `copies` value on `new` is the lot's quantity (the model's default).

`_copies.html.erb` menu: `<%= link_to "Move copies", new_lot_move_path(lot, **card_params), class: "c-menu__item" %>` between "Edit copy" and the separator.

Add `app/models/lot/move.rb`, `app/controllers/lots/moves_controller.rb` and `app/views/lots/moves/new.html.erb` to `spec/import_apply_core_spec.rb` with the files (m7).

**Green gate:** whole `bin/rspec`, `bin/rubocop`. **Commits:** `feat(lots): move some or all of a lot's copies to another location (#45)`; `test(lots): a location is emptied one lot at a time, then removed (#45)`.

---

## Phase 6: Export format version 3 and reading it

**Implements:** FR-3 (the format), FR-4 (reading), decision 7, Stories 9 and 10. **Satisfies:** AC-9.1, AC-9.2, AC-9.3 (final), AC-9.4 to AC-9.8, AC-10.1 to AC-10.11. **Files:** `docs/export-format/README.md`, `docs/export-format/v3.schema.json` (new), `docs/export-format/examples/**` (new files, `problems.json`), `app/models/export_format/v3.schema.json` (new, byte-identical), `app/models/export_format/rules.rb`, `app/models/collection_import.rb`, `app/views/collections/import_previews/show.html.erb`, `app/helpers/import_previews_helper.rb`, `spec/support/export_format_rules.rb`, `spec/support/import_helpers.rb`, `spec/export_format_document_spec.rb`, `spec/export_format_examples_spec.rb`, `spec/models/export_format/rules_spec.rb`, `spec/models/location/name_parity_spec.rb`, `spec/models/collection_import_spec.rb`, `spec/models/collection_import/{plan_spec,locations_spec,round_trip_spec}.rb`, `spec/requests/collection_import_previews_spec.rb`, `spec/system/collection_import_preview_spec.rb`.

**Read first:** `contracts/export-v3.md` (the schema, examples, document changes), `docs/export-format/README.md` (whole), `docs/architecture/data-portability.md` (Reading a file), `docs/design-system/components/ImportPreview.md`.

Why the preview is in this phase and the export is not: the six-value identity is shared by the rules and the preview's matching (`CollectionImport` builds identities with `ExportFormat::Rules.identity`), so the two change together or an identity array of five meets one of six. `CollectionExport` and the apply move to version 3 in Phase 7; between the phases the export still writes version 2, which every reader accepts, and `Apply` still builds unplaced keys, so a placed version 3 file must not be applied yet. Exactly one spec applies the valid examples: `spec/models/collection_import/round_trip_spec.rb` loops over `ExportFormatRules.examples("valid")` (`git grep -n 'examples("valid")' -- spec` finds the others, which only judge, preview or compare them). The new version 3 examples would fail it (`collection-v3.json` holds one printing in two places, two added rows with one unplaced key, and the NFD and 60-character examples would lose their places), so Phase 6 limits that loop to examples of version 2 or lower, with a comment (`next if JSON.parse(bytes)["format_version"] > 2 # until Phase 7: Apply doesn't place lots yet`), and Phase 7 removes the limit when it rewrites the spec to AC-11.14 (plan review M1). Phase 6 therefore ends green.

**6.1 Failing tests**, in this order (each red before its implementation):

1. Suite support: `ExportFormatRules.identity(lot, version = 3)` passes through to `ExportFormat::Rules.identity` (its sixth value is the comparison key, which is what `duplicate_lot` and the preview's matching need). **"The same collection" compares a lot's location exactly** (contracts/export-v3.md; AC-9.6 makes "box" against "Box" on a lot different), so `compared(file)` does not key the lots by that identity: it keys them by `compared_identity(lot, version) = identity(lot, version).first(5) + [ (lot["location"] if version >= 3) ]`, the location string as written, and passes `file["format_version"]` (a `location` on a version 1 or 2 lot is an ignored unknown field and stays out). `same_collection?` raises for different versions as before (plan review M2: with the key, `v3-base.json` and `v3-different-lot-location-case.json` would compare as one collection and AC-9.6's example would fail). `spec/support/import_helpers.rb`: `import_row(entry, …, location: :none)` adds `"location" => …` only when given; `import_file_v3(user, lots, locations: [], **fields)` builds `format_version: 3`.
2. `rules_spec`: `VERSIONS` is `[1, 2, 3]` and `VERSION` 3; each pair of schema and app copy is byte-identical for v1, v2 and v3; `identity(lot, 3)` has six values, the sixth the comparison key of the location (`"blue binder"` for "Blue Binder"), `nil` for `null`; `identity(lot, 2)` ignores a `location` key and ends in `nil`; a version 3 lot with no `location` fails `required` at `/lots/0/location`, a number fails `type`, `""` fails `minLength`, 61 code points `maxLength`, a padded one `pattern` (AC-9.5); a version 2 file with a `location` on a lot is well-formed (AC-9.8); `unknown_location` at `/lots/<i>/location` for a location the file's `locations` doesn't list, none for a listed one in another case or in NFD (AC-9.4); `duplicate_lot` on six values: two lots equal but for the case of their locations repeat, two equal but for location do not (AC-9.5); a version 3 file with 501 locations and one placed lot reports `maxItems` at `/locations` and no `unknown_location` (the list is not walked again: plan review M3, spec 029 review M1; assert it with a lot whose location is listed only past the 500th, which must not be looked for); a version 4 file is judged by version 1's schema (changing the existing example that used 3).
3. `export_format_examples_spec`: the new valid, invalid and comparison examples exist and are judged as `problems.json` says (the suite already iterates the directories); `RULES` includes `unknown_location` and an invalid example exists for it (the existing "an invalid example for every rule" example); the version 3 section (like "version 2 (spec 029)"): lot-location variants, edges (60 code points), the same collection for lots in another order and different for a changed or re-cased location (AC-9.6; the re-cased pair is the example that proves `compared_identity` is exact, and a unit example builds two one-lot files differing only by "Box" and "box" on the lot and expects `same_collection?` false while `ExportFormatRules.identity` gives them one value); "newer" now means `format_version: 4`.
4. `export_format_document_spec`: states version 3; every version 1 to 3 has its schema and its row in Versions; Coverage maps `lots.location_id` to `location` and `lots.location_id` leaves the `left_out` list (AC-9.3, the Phase 0 interim row is replaced); `fields` from the valid examples include `location`, which the document names.
5. `name_parity_spec`: a lot's `location` string, judged by the model's `Location::Name` and by `v3.schema.json`'s `$defs/lot_location`, agrees for every Unicode scalar value (AC-9.7), the same loop as for a name.
6. `collection_import_spec`: version 4 is refused "…This instance reads version 3." (AC-10.1); each of 1, 2, 3 is read against its own schema; a version 3 row matches a held lot only when printing, finish, condition, price paid and location agree, "box" in the file and "Box" held being one place (AC-10.2); a row with an unlisted location is a problem row with "Its location “Box” isn't one of the file's locations.", the file isn't applicable, no held lot is reported removed because of it and `held` counts it (AC-10.3); a version 1 or 2 file: rows match unplaced held lots only, a placed held lot is removed and the row added, or changed against an unplaced twin (AC-10.4, AC-10.5); the account's own version 3 export has nothing to change (AC-10.6, needs `CollectionExport` v3: the example builds the file with `import_file_v3` from the account's lots instead; the real round trip is Phase 7); a file moving one lot between places is applicable with one added and one removed, and the removed lot's line says it was in "Long box" (AC-10.7 as 1.0.2 words it: the counts and the removed lot's line, since the preview has no list of added lots); renaming "box" to "Box" lists the rename and changes no lot (AC-10.8); removed lots carry the held place and problem rows the file's (AC-10.9 as 1.0.2 words it: those are the two lists the preview has; O1 ruled 2026-10-24); a duplicate row of a version 3 file reads "Same card, finish, condition, price and location as row M" and one of an older file keeps its wording (AC-9.5, plan review m4); a version 3 file that drops a location lists every held lot in it as removed and the location as removed (AC-10.10); two accounts read only their own (AC-10.11). `plan_spec`: the fingerprint changes when a held lot's place changes (`lot_part` carries the place).
7. Request and system specs: the preview page shows "This file was written before lots could be in a location, so its lots would be in none." for a version 1 or 2 file and not for a version 3 file (AC-10.4); the problem-row reason and the removed lot's "in Blue binder" appear (AC-10.3, AC-10.9); one system example at 360px of a version 3 preview with problem rows (reuse the file's existing narrow check).

**6.2 Implement, in order.**

*Schema and examples.* Create `docs/export-format/v3.schema.json` from `v2.schema.json` per `contracts/export-v3.md` (change `$id`, `title`, `description`, `format_version` const; `lot.required` gains `"location"`; `lot.properties.location` is `{ "$ref": "#/$defs/lot_location" }`; new `$defs/lot_location` is the `location_name` definition with `"type": ["string", "null"]` and a `description` that says "or null when the lot is in no location"); copy it byte for byte to `app/models/export_format/v3.schema.json`. Write the examples in `contracts/export-v3.md`'s table and their `problems.json` entries (`why`, `rule`, `at`). Edit `docs/export-format/README.md` at every place the contract lists (header, intro, the file's table, Lots, Lot identity, Locations, Well-formed and resolvable, The same collection, Versions with the version 3 row and the rewritten expected-changes sentence, Coverage, Examples).

*Rules.* `app/models/export_format/rules.rb`:

```ruby
VERSIONS = [ 1, 2, 3 ].freeze
# Keep in step with v2.schema.json's and v3.schema.json's maxItems for locations (a spec checks it).
RULES = %w[not_utf8 not_json not_a_time changed_before_added duplicate_lot duplicate_location unknown_location].freeze
IDENTITY_FIELDS = %w[entry entry/collectible_type entry/source_id finish condition price_paid location].freeze

# What identifies a lot (ADR 0019, ADR 0025): its entry's type and source id, finish, condition, price paid and, from
# version 3, the comparison key of its location. Six values for every version; the sixth is nil for versions 1 and 2, which
# say nothing about a place (spec 032 decision 7), and for a lot in no location.
def self.identity(lot, version = VERSION)
  lot.fetch("entry").values_at("collectible_type", "source_id") + lot.values_at("finish", "condition", "price_paid") +
    [ place_key(lot["location"], version) ]
end

def self.place_key(location, version)
  Location::Name.key(Location::Name.normalise(location)) if version >= 3 && location.is_a?(String)
end
```

`rule_problems` computes `version = schema_version(data)` once, groups `repeats` by `identity(lot, version)`, and returns `not_times + backwards + repeats + unlisted_places(data, lots, failed, version) + (version >= 2 ? repeated_locations(data, failed) : [])`:

```ruby
# The lots whose location is a name the file's locations don't list, compared by comparison key (version 3). A lot whose
# location failed the schema has nothing to compare, as a lot whose identity can't be read isn't compared.
def self.unlisted_places(data, lots, failed, version)
  return [] unless version >= 3 && data["locations"].is_a?(Array) && !failed.include?("/locations") # an over-long list is refused at the header; none of it is folded here (spec 029 review M1)

  listed = data["locations"].filter_map { |location| place_key(location["name"], version) if location.is_a?(Hash) }.to_set
  lots.filter_map do |lot, index|
    next unless lot["location"].is_a?(String) && !failed.include?("/lots/#{index}/location")

    Problem.new("unknown_location", "/lots/#{index}/location") unless listed.include?(place_key(lot["location"], version))
  end
end
```
(`private_class_method` gains `:unlisted_places, :place_key`.)

*Reading.* `app/models/collection_import.rb`:

- `LOT_COLUMNS` gains `"locations.name", "locations.name_key"` at the end; `HeldLot` gains `:location`, and `described` adds `location: location`.
- `Row` gains `:place` (the file's spelling of the lot's location for a version 3 lot that has one, else nil); `described` adds `location: place`.
- `def places? = @version >= 3` (public, for the page).
- `read_rows`: `failed = @problems.reject { |problem| %w[duplicate_lot unknown_location].include?(problem.rule) }.to_set(&:at)`; identities `ExportFormat::Rules.identity(lot, @version)`; `Row.new(number: index + 1, lot:, identity: identities[index], problems:, place: (lot["location"] if @version >= 3 && lot.is_a?(Hash) && lot["location"].is_a?(String)))`; `describe(problem, first_row[…], lot)` gains the lot and a branch:

```ruby
if problem.rule == "unknown_location"
  return Problem.new(rule: problem.rule, at: problem.at, reason: "Its location “#{lot["location"]}” isn't one of the file's locations.",
    summary: "Its location isn't one of the file's locations.")
end
```
- `held_lots`: `@account.lots.joins(entry: :set).left_joins(:location).pluck(*LOT_COLUMNS)`, destructuring `…, language, place, place_key`, `identity: [ type, source_id, finish, condition, price, place_key ]`, `location: place`.
- The preview `show.html.erb`: under the applicable/not applicable status, `<% unless @import.places? %><p class="c-import__note" id="places_note">This file was written before lots could be in a location, so its lots would be in none.</p><% end %>`.
- The duplicate reasons (`collection_import.rb:18-19`) gain version 3 wordings so the reason names the one value that can explain two rows of "Box" and "box": `DUPLICATE_OF_PLACED = "Same card, finish, condition, price and location as row %d"` and `DUPLICATE_PLACED = "Same card, finish, condition, price and location as an earlier row"`; `describe` picks them when `@version >= 3` and keeps `DUPLICATE_OF` and `DUPLICATE` for versions 1 and 2 (spec 025 decision 9 stands for them).
- `ImportPreviewsHelper#import_lot_line` gains `location: nil` and appends `("in #{location}" if location)` to the joined parts; the removed-lots and problem-row lines pass `**lot.described` / `**row.described`, which now carry it.
- `Plan#lot_part(lot) = [ lot.id, lot.quantity, lot.created_exact, lot.updated_exact, lot.identity.last ]`.

**Green gate:** whole `bin/rspec`, `bin/rubocop`. `diff docs/export-format/v3.schema.json app/models/export_format/v3.schema.json` is empty. **Commits:** `docs(export-format): define format version 3, a lot's location (#45)` (document, schema, examples, Coverage, support, the format specs); `feat(import): read format version 3 and older files as unplaced (#45)`.

---

## Phase 7: The export writes version 3; the apply puts lots in their places

**Implements:** FR-3 (writing), FR-4 (applying), Stories 8 and 11. **Satisfies:** AC-8.1 to AC-8.6, AC-11.1 to AC-11.11, AC-11.13, AC-11.14 (AC-11.12 is measured in Phase 8). **Files:** `app/models/collection_export.rb`, `app/models/collection_import/apply.rb`, `app/models/collection_import/location_changes.rb` (comment), `spec/models/collection_export_spec.rb`, `spec/requests/collection_exports_spec.rb`, `spec/models/collection_export_core_spec.rb`, `spec/models/collection_import/{apply_spec,round_trip_spec}.rb`, `spec/import_apply_core_spec.rb`, `spec/requests/collection_imports_spec.rb`, `spec/system/collection_import_apply_spec.rb`, `spec/system/collection_export_spec.rb`, `spec/support/import_helpers.rb`.

**7.1 Failing tests.**

- Export: `format_version` is 3 and every lot has `location`: the stored name (NFC) or `null`, never `""` (AC-8.1); a printing in two places is two lots, one with each (AC-8.2); an empty location is listed and every lot's location is among the names (AC-8.3); two accounts' files share nothing (AC-8.4); two exports differ only in `exported_at` (AC-8.5); an account with no locations has `"location": null` everywhere and `locations: []` (AC-8.6); the export of a placed collection is well-formed under `ExportFormatRules` and equals `docs/export-format/examples/valid/collection-v3.json` but for `exported_at` and the profile (the example `collection_export_spec` used `collection-v2.json` for); the number of statements doesn't grow with the lots (the query-count helper). **A change between the export's two reads** (plan review M5; no stub): an `ActiveSupport::Notifications` subscriber on `sql.active_record` renames the lot's location with SQL (`UPDATE locations SET name = 'Crate', name_key = 'crate'`) once, right after the statement that reads the lots; the export is well-formed under `ExportFormatRules`, lists "Crate" and the lot says "Crate". A second subscriber moves the lot out and deletes its location after the lots statement, once: the export reads again and is well-formed, with the lot where it now is, no more than two extra statements; if it never settles in `TRIES` reads it raises `CollectionExport::Unsettled`.
- Apply (`apply_spec`, with `import_file_v3`): every lot ends in the file's location or none (AC-11.1); a file moving a lot from "Long box" to "Blue binder" leaves it in Blue binder, none in Long box, the notice counting one lot added and one removed (AC-11.3); a version 1 or 2 file applied to an account with placed lots makes the lots the file's, unplaced, needs the removal confirmation ("I understand this removes N lots…") and for version 2 replaces the locations, for version 1 leaves them (AC-11.4); renaming "box" to "Box" keeps the location's id, its lots in it unwritten (their `updated_at` unchanged) and exports "Box" (AC-11.5); a plan that removes a location and its lots deletes the lots first in one transaction, and a lot placed in that location after the preview makes the apply answer `:stale` with nothing written (AC-11.6); a lot moved to another place between preview and apply is `:stale` (AC-11.7, the existing fingerprint examples gain the place); the same file twice: the second is `:nothing_to_change` and writes nothing (AC-11.8); a file whose only change is one lot's place is applicable, stored, and moves that lot (AC-11.9); a failure after the locations were written (create `CREATE TRIGGER fail_lot_upsert BEFORE INSERT ON lots BEGIN SELECT RAISE(ABORT, 'forced'); END` in the example) rolls back locations, lots and working state (AC-11.10); two accounts with a "Box": the first's apply resolves to its own and leaves the other's lots, locations and `updated_at` unchanged (AC-11.11); the working state is cleared when a lot is written and not when only a location or the view changes (AC-11.13); the statements of an apply of 5,000 lots in 500 locations are the same as for 50 lots in 5 (the count helper; AC-11.12's bounded statements).
- `round_trip_spec` (AC-11.2, AC-11.14), first removing Phase 6's `format_version > 2` limit on the loop (M1): an account with lots in two locations, a printing in both, an unplaced lot and an empty location, exported and applied to an empty account on the same catalog, exports again to a file equal but for `exported_at` and the profile's name and email; and each valid example of versions 1, 2 and 3 that resolves against the catalog the suite builds, except `locations-nfd.json` and the version 3 NFD/case example, applied to an empty account and exported equals the example but for `exported_at`, the profile's name and email, `format_version` (3), for a version 1 example `locations: []`, and for a version 1 or 2 example every lot's `"location": null` (replace spec 029 AC-9.15's and spec 028 AC-6.4's expectations in the existing examples, which compared an example with its own version).
- Core specs (`collection_export_core_spec`, `import_apply_core_spec`, `number_entry_core_spec` pattern): the changed files name no collectible type.

**7.2 Implement.**

`CollectionExport`: `FORMAT_VERSION = 3`; the header comment says "format version 3 (spec 022, spec 029, spec 032)"; `LOT_COLUMNS` gains `"lots.location_id"` after `"lots.updated_at"`. The two reads (`collection_export.rb:33-36`, no transaction around `to_h`) now have a rule that ties them together (`unknown_location`), so a rename between them could write a file Collector refuses (plan review M5). Every lot's place is therefore **named from the one locations read, by id**, and a transaction is not used: Rails opens SQLite's transactions IMMEDIATE (`sqlite3_adapter.rb:162`), so a read transaction would hold the write lock for a 50,000-lot export.

```ruby
TRIES = 3
Unsettled = Class.new(StandardError)

# The lots, then the locations, each read once; a lot's place is its location's name from the second read, looked up by id, so a
# rename between the reads leaves every lot naming a listed location (spec 032 AC-8.3). The one gap left is a location removed
# between the reads (its lot moved out and it was removed, within milliseconds): the reads are repeated.
def locations_and_lots
  TRIES.times do
    rows = lot_rows
    places = @account.locations.ordered.pluck(:id, :name)
    names = places.to_h
    next unless rows.all? { |row| row.last.nil? || names.key?(row.last) }

    return [ places.map { |_id, name| { "name" => name } }, rows.map { |row| lot_hash(row, names) } ]
  end
  raise Unsettled, "the account's locations kept changing while its collection was read"
end

def lot_rows = @account.lots.joins(entry: :set).order(:id).pluck(*LOT_COLUMNS)

def lot_hash(row, names)
  type, source_id, name, set_code, number, language, quantity, finish, condition, cents, added, changed, location_id = row
  { "entry" => { … as before },
    "quantity" => quantity, "finish" => finish, "condition" => condition, "price_paid" => price(cents),
    "location" => (names.fetch(location_id) if location_id), "added_at" => time(added), "changed_at" => time(changed) }
end
```

`to_h` calls `locations_and_lots` once for `"locations"` and `"lots"`, replacing the private `locations` and `lots` methods. The statements are the same two as before (no join: the lots' read has no `locations` table), so the count doesn't grow with the lots; `Unsettled` is not rescued (it needs three removals racing three reads) and would be a 500. The order of the lots (`order(:id)`) and of the locations (`ordered`) is unchanged, so two exports stay the same apart from `exported_at` (AC-8.5).

`CollectionImport::Apply`: `lot_attributes` no longer builds `lot_key`; it keeps the row's place beside the values, and `write!` places the lots after the locations are written (research R3):

```ruby
def lot_attributes(row, import)
  lot = row.lot
  finish = lot["finish"].presence
  condition = lot["condition"].presence
  cents = lot["price_paid"]&.delete(".")&.to_i
  { account_id: @account.id, catalog_entry_id: import.entry_id(row), quantity: lot["quantity"], finish:, condition:,
    price_paid_cents: cents, location_key: row.identity.last, # the comparison key; resolved to an id once the locations are written
    created_at: Time.iso8601(lot["added_at"]), updated_at: Time.iso8601(lot["changed_at"]) }
end

# Delete the removed lots (the lots of a removed location are among them, so the foreign key never fires), write the
# locations, read them once (at most 500 rows), then upsert the lots with their place and key. One statement per BATCH_SIZE
# lots, never one per lot (FR-4). The upsert is on the lot's identity, so a changed lot keeps its id and a renamed
# location's lots stay where they are; the rows were validated by the reader, so the bulk statements skip Lot's callbacks and
# validations on purpose (spec 028 FR-3).
def write!(plan, rows)
  plan.removed_lots.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.lots.where(id: ids).delete_all }
  CollectionImport::LocationChanges.write!(@account, plan.locations)
  place_ids = @account.locations.pluck(:name_key, :id).to_h
  (plan.added_rows + plan.changed_rows).each_slice(CollectionImport::BATCH_SIZE) do |slice|
    Lot.upsert_all(slice.map { |row| placed(rows.fetch(row.number), place_ids) }, unique_by: %i[account_id catalog_entry_id lot_key],
      update_only: %i[quantity created_at updated_at], record_timestamps: false, returning: false)
  end
  # Only a written lot makes the lists that point at lots wrong (spec 029 decision 11, AC-9.17).
  CollectionImport::WorkingState.clear!(@account) if plan.writes_lots?
  @account.user.update!(collection_view: plan.view_change) if plan.view_change
end

# One pass over the built attributes: the location's id and the key that carries it, by string concatenation.
def placed(attributes, place_ids)
  location_id = place_ids.fetch(attributes[:location_key]) if attributes[:location_key]
  attributes.except(:location_key).merge(location_id:,
    lot_key: Lot.key_for(attributes[:finish], attributes[:condition], attributes[:price_paid_cents], location_id))
end
```

`LocationChanges.write!` is unchanged except its header comment ("after the removed lots are deleted and before the lots are written"). The two `unique_by` columns and `update_only` are unchanged. The order `WorkingState.clear!` after the lots and before the user update matches today's (it moved after locations before; nothing between them reads lots).

**Green gate:** whole `bin/rspec`, `bin/rubocop`. **Commits:** `feat(export): write format version 3 with each lot's location (#45)`; `feat(import): apply places lots in the file's locations (#45)`.

---

## Phase 8: Documents, design system, measurements

**Implements:** the spec's "Documents that change", NFR performance and cost. **Satisfies:** AC-11.12, the Supersedes entries both ways, AC-9.1 (by reading). **Files:** `docs/architecture/data-portability.md`, `docs/adr/0025-…md`, `docs/adr/0019-…md`, `docs/adr/0023-…md`, `docs/adr/README.md`, `docs/roadmap.md`, `docs/specs/README.md`, `docs/specs/032-lot-in-a-location/{spec.md,verification.md,screenshots/}`, `docs/design-system/components/Locations.md`, `docs/design-system/README.md`, `app/assets/stylesheets/collector/additions.css`, `CLAUDE.md`, `README.md`.

Steps (documents are verified by reading and recorded in `verification.md`; no RSpec checks prose):

1. **Area doc** `docs/architecture/data-portability.md` (read it first; each new statement keeps its source inline: the spec criterion or ADR 0025, and spec 032 in Sources): Glossary and Invariants (lot identity is six values; an older file's lots are unplaced); *The export*: version 3, the `location` per lot; *Reading a file*: the version-above row reads "higher than 3", `unknown_location` in the rule list and the problem table, `duplicate_lot` on six; *Outcomes of a plan*: the identity is six values, a held lot in a location has no match in an older file; *The preview page*: the older-file sentence, "in <location>" on removed lots; *The fingerprint*: the place is part of a lot's part; *The apply*: the new write order and why; *Named constants*: `CollectionExport::FORMAT_VERSION` 3, `ExportFormat::Rules::VERSIONS` `[1, 2, 3]`, `RULES`, `MAX_LOCATIONS` comment; *Sources*: spec 032 and ADR 0025; add a row to its *Distillation log* for this change (date, what changed, this pull request), and record the supersessions in the area doc's Sources both ways (spec 025, 028, 029 and 017 decisions this spec replaces); `distill-feature` still runs at session end. `docs/architecture/release-and-deploy.md` (#130) states nothing this spec changes (read for `version`, `location`: only the backup format's versions, which are not the export's), so it is not touched. Also (plan review notes and m4): the apply paragraph's "spec 029 AC-9.15" citation (the round trip, now AC-11.14), the problem table's duplicate row (`Same identity as an earlier row`: "Same card, finish, condition and price as row M" for versions 1 and 2, "…, price and location as row M" for version 3), and the "Decisions not in an ADR" bullet on which versions are read. Verify with `git grep -n "version 2" docs/architecture/data-portability.md ':!.kamal/secrets'` and read every hit.
2. **ADR 0025** Status becomes Accepted (date of the maintainer's approval of this plan); `docs/adr/README.md` drops "(Proposed)"; `docs/adr/0019-lot-as-the-unit-of-ownership.md` and `docs/adr/0023-locations-make-export-format-version-2.md` get a pointer on their Status lines ("The open question for locations is answered by ADR 0025" / "The consequence about deleting a location is superseded by ADR 0025").
3. **Roadmap:** `docs/roadmap.md` item 10 is marked done with this spec and its pull request, item 9's pointer updated, and the YARD line's "Expected ADR: YARD (0023)" corrected to "the next free number after 0025".
4. **Design system:** `docs/design-system/components/Locations.md` gains the holdings text, the refusal page and the `c-locations__more` rule (the Location column and the Move copies page are existing components used as documented: `Form`, `ConfirmPage`, `CollectionTable`; say so in the doc); the README's app additions get "App additions (spec 032, in `collector/additions.css`): `c-locations__more` and the 44px floor of `c-locations__lots` links, documented in `Locations`" (the doc says the refusal page's lot links share the page's touch floor, plan review m2). Render the card page, Move copies page, refusal page, locations page and import preview at 1280px and 390px in light and dark (`data-theme`) and compare with `previews/`; keep the pictures in `docs/specs/032-lot-in-a-location/screenshots/` (memory: PR screenshots workflow).
5. **`CLAUDE.md`:** the Project Status sentence about locations and export (a collector records which location a lot is in; export format version 3) and the *Export format*, *Import preview* and *Locations* bullets' version numbers and the new removal rule, each pointing to the area doc instead of restating it; `README.md` if it names the export's version or what a collector can record (read it; `git grep -n -i "version 2\|location" README.md ':!.kamal/secrets'`).
6. **Specs index and spec header:** `docs/specs/README.md`'s 032 row Status "Approved (implemented; …)" with its Plan cell "present" (done in the plan commit) and, after the implementation review, as 030's row does; `spec.md`'s `Plan:` line points at `plan.md` (done in the plan commit). The Supersedes entries are in both places (the index row's Supersedes cell gained spec 025 decision 9 and ADR 0023's "reads versions 1 and 2" bullet in the plan revision, plan review m11); re-read them against what shipped.
7. **Measurements** (AC-11.12 and the NFRs), into `verification.md`, with a throwaway runner in the session scratchpad, never committed, as specs 028 and 029 did: seed 50,000 lots each in one of 500 locations whose names are 60 CJK characters and export; preview and apply it to an empty account, and apply a version 2 copy to the placed account; record the file size (under `CollectionImport::MAX_BYTES`), the longest `transaction.active_record` duration (hard bar 4 s), the whole requests (under 30 s), RSS growth (under 500 MB) and the number of statements (none per lot or per location). Also: queries per page at 500 locations and 5,000 lots (card page, Move copies, locations page, refusal page) against the same pages with little data; the migration's time on 50,000 lots (`ADD COLUMN` plus `CREATE INDEX`); the size of the database before and after (cost per account). If the file passes the limit or a bar fails, stop for the maintainer's ruling before release (AC-11.12).
8. **`verification.md`:** the coverage matrix (every AC, decision and P with its example, measurement or reading), the rulings O1 to O3 of 2026-10-24 (O1 as spec PATCH 1.0.2, so the Mode B review reads AC-10.7 and AC-10.9 as reworded and flags no drift), that the price orders the refusal page's lots by cents (3.2), that `Lot::Move` has no retry because IMMEDIATE transactions serialise the writers (m6), the measurements, the readings of the documents, and the `## Implementation review` heading with the verdict on its first line after an independent `sdd-review` Mode B pass (`.claude/rules/documentation.md`).
9. **Spec 031 (follow-up).** Its plan's research section 8 (branch `031-upgrade-from-previous-release`, read-only) gives the rules for a later migration: a nullable column on an existing table needs nothing (this migration), a new table must be filled in `script/upgrade/seeds/next.rb` or listed under `next` in `seed_exceptions.yml` (none here), a migration that rewrites lot rows needs an `expected_changes.yml` entry (none here: no lot is rewritten). `next.rb` builds its lots with `Lot.insert_all`, `Lot.key_for` and `Lot.add!`; `key_for`'s new fourth argument defaults to `nil` and `add!`'s `location:` to `nil`, so it keeps working, and it should place a lot through `Lot.add!(location:)` so the new column holds data. If the upgrade check is on `main` when this is executed, make that change in this pull request; otherwise open an issue saying so and link it in the pull request (research R8).
10. **Session end:** `sdd-superpowers:session-wrap`, then `distill-feature` (writes the area docs for the finished feature before the merge, retires this plan after it).

**Green gate:** whole `bin/ci` (RuboCop, Brakeman, bundler-audit, importmap audit, RSpec). **Commits:** `docs(adr): accept ADR 0025 (#45)`; `docs: lots in locations in the area doc, design system, roadmap and CLAUDE.md (#45)`; `docs(specs): verification for spec 032 (#45)`.

---

## Self-Review

- **Spec coverage.** Every story, FR and decision has a phase in the Requirement Map; the ACs are listed there by number: Story 1 (AC-1.1 to 1.9: Phases 1 and 4), Story 2 (2.1 to 2.8: 1, 4), Story 3 (3.1 to 3.12: 5), Story 4 (4.1 to 4.5: 3, 4), Story 5 (5.1 to 5.7: 3, 5), Story 6 (6.1 to 6.7: 1, 3, 4, 5), Story 7 (7.1 to 7.8: 0, 1, 2, 5), Story 8 (8.1 to 8.6: 7), Story 9 (9.1 to 9.8: 0, 6), Story 10 (10.1 to 10.11: 6), Story 11 (11.1 to 11.14: 7, 8 for 11.12). FR-1 to FR-4 and the NFRs: Phases 0 to 8. P1 to P6: Phases 3, 3, 4, 5, 2, 5. D1 to D6 / decisions 1 to 7: Phases 1, 1, 3, 4 to 5, 4 to 5, 4 to 5, 6 to 7. Gaps: none. AC-9.1 is verified by reading (Phase 8 step 1 and the contract's table) and by the one spec that reads the document.
- **Placeholder scan.** No "TBD", "TODO" or "similar to". Phase 5 has no retry to test (m6); the lost races of AC-6.7 are proved with an `ActiveSupport::Notifications` subscriber, not a stub (m5, M5).
- **Type consistency.** `Lot.key_for(finish, condition, price_paid_cents, location_id = nil)` is used by `Lot.add!`, `before_validation`, `Lot::ConditionChange`, `BulkRemoval#identity`, `Lot::Move#twin` and `Apply#placed` with the same four arguments; `Location::Holdings.counts(account)`/`#total`/`#listed`/`#more` in Phase 3 are what the views call; `Lot::Move.new(lot:, to:, copies:)` in the controller matches the model; `ExportFormat::Rules.identity(lot, version)` is called with a version everywhere (the suite support, `rule_problems`, `read_rows`); `Row#place` and `HeldLot#location` are the two values `import_lot_line(location:)` receives; `BulkRemoval::Undone#unplaced` is what the controller and helper read.
- **Traced against the files they edit, not run.** Every snippet above edits a file read for this plan (research R10). Where a snippet depends on a signature not read in full (`BulkSelection#record!`, `owned_printing`), the phase says so and names the file to read.
- **Open for the maintainer.** Nothing: O1 to O3 are ruled (2026-10-24); the independent review is done (`plan-review.md`); the upgrade check's seed (Phase 8 step 9) waits for spec 031 to be on `main`.

## Execution Handoff

Plan revised after the review. Next: the maintainer's approval, then `sdd-superpowers:sdd-execute` to begin implementation in this worktree (`032-lot-in-a-location`).
