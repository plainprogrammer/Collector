# Research: Put a Lot in a Location

**Spec:** [spec.md](spec.md) · **Plan:** [plan.md](plan.md)

Read-only. Nothing here was executed: plans in this project are not run before approval (`.claude/memory`, ruled 2026-10-15), so each point below was traced by reading the file named, at `origin/main` `b873304` plus this branch. An executor confirms each with its first failing test.

## R1. Adding the foreign key must not rebuild `lots`

**Question.** How does the migration add `lots.location_id` with a foreign key without losing the rows that point at lots (AC-7.1)?

**Found.**
- Rails' SQLite adapter implements `add_foreign_key`, `remove_column` and most other constraint changes as `alter_table`: create a temporary copy, `drop_table(from)`, create the table again from the copy, drop the temporary (`activerecord-8.1.4/lib/active_record/connection_adapters/sqlite3_adapter.rb`, `alter_table` and `move_table`, about lines 593 to 650; `sqlite3/schema_statements.rb` `add_foreign_key`, line 56).
- It wraps the copy in `disable_referential_integrity` (lines 283 to 295), which runs `PRAGMA foreign_keys = OFF` and `PRAGMA defer_foreign_keys = ON`. SQLite ignores `PRAGMA foreign_keys` inside a transaction, and a migration runs in one (`supports_ddl_transactions?`). With enforcement on, `DROP TABLE lots` is an implicit `DELETE FROM lots`, which runs the `ON DELETE` actions of the tables that point at it: `bulk_selection_marks` (`CASCADE`), `number_entry_lines` and `scanner_sitting_entries` (`SET NULL`), `db/schema.rb` lines 346, 362 and 366. `defer_foreign_keys` only defers the violation count, not the actions.
- `ALTER TABLE … ADD COLUMN x integer REFERENCES t(id)` is allowed by SQLite when the column's default is `NULL`; it rewrites no row and copies no table. `add_index` is a plain `CREATE INDEX`.
- `ALTER TABLE … DROP COLUMN` fails for a column used in a foreign key, so going down needs the rebuild; outside a transaction Rails' `PRAGMA foreign_keys = OFF` works and the copy is harmless.

**Decision.** `up` uses raw `ADD COLUMN … REFERENCES … ON DELETE RESTRICT` and `add_index`; `down` uses `remove_column` under `disable_ddl_transaction!`; both are guarded with `column_exists?`/`index_exists?` so a crash between the two steps is finished by a re-run. `spec/migrations/add_location_to_lots_spec.rb` proves up and down keep the marks, lines, entries and the undoable removal, and the schema dump shows `add_foreign_key "lots", "locations", on_delete: :restrict`.

**Not chosen.** `add_reference :lots, :location, foreign_key: true` (rebuilds `lots` in the migration's transaction, the hazard above); a trigger instead of a foreign key (`db/schema.rb` doesn't dump triggers, so the test database and a fresh install would lack it, and AC-5.5 needs the database to refuse); a plain column with no foreign key (nothing stops a lot pointing at a missing location, which FR-1 forbids).

## R2. Where "the same lot" is defined

`git grep -n "lot_key\|key_for"` at the base finds exactly the four builders the spec's Notes name, and no other: `app/models/lot.rb` (`key_for`, `add!`, the `before_validation`), `app/models/bulk_removal.rb` (`identity`, `insert_alone!`), `app/models/lot/condition_change.rb` (`groups`, `existing_targets`, `update_alone!`'s SQL) and `app/models/collection_import/apply.rb` (`lot_attributes`, the `unique_by`). The collection grid and table don't build keys (they group by entry). `NumberEntry.add!`, `Scanner::Sitting.add!` and the quick add call `Lot.add!` without a location and need no change (AC-7.2).

**Key text.** Placed: `"#{finish}|#{condition}|#{price}|#{location_id}"`; unplaced unchanged. `Array#join` renders `nil` as `""`, so `[nil, nil, nil].join("|")` is `"||"`; appending `"|7"` gives `"|||7"`. In SQL (`update_alone!`): `COALESCE(finish, '') || '|' || ? || '|' || COALESCE(price_paid_cents, '') || COALESCE('|' || location_id, '')`, because `'|' || NULL` is `NULL`.

**Not chosen.** An expression index `(account_id, catalog_entry_id, lot_key, COALESCE(location_id, 0))`: leaves `lot_key` as is, but then the unplaced and placed keys no longer say the identity, `Lot.key_for` is no longer the one definition, and the apply's `upsert_all(unique_by: %i[account_id catalog_entry_id lot_key])` couldn't name the index. The spec (Notes for the plan, FR-1) rules the key.

## R3. The apply's order and where the attributes are built

Today (`app/models/collection_import/apply.rb`, `rows_to_write` and `write!`): every row's attribute hash, `lot_key` included, is built before the transaction; inside it, `write!` deletes the removed lots, upserts the lots, clears the working state, then writes the locations.

A placed lot's key needs its location's id, which exists only after the locations are written (a new location has none before). So `write!` becomes: delete the removed lots; `LocationChanges.write!` (delete removed, upsert added and renamed); one `account.locations.pluck(:name_key, :id)` (at most 500 rows); then the lots' `location_id` and `lot_key`, upserted. The expensive work (time parsing, price, entry ids) stays before the lock: `rows_to_write` builds each hash without `location_id` and `lot_key`, with the row's location key kept beside it; inside the transaction a single pass fills the two values by string concatenation (O(rows), no parsing, no query per row). `LocationChanges` is unchanged except for being called earlier. Lots in a removed location are among the removed lots (a file row can't name a location the file doesn't list, or it would be an `unknown_location` problem row), so the lot deletes come first and the foreign key never fires. AC-11.12 measures it.

`WorkingState.clear!` stays where it is (after the lots, only `if plan.writes_lots?`).

## R4. Bulk Undo: which lot is named when the restored rows alone pass the cap

AC-7.8: a removal of a lot in Blue binder and an unplaced lot of one identity, then Blue binder removed, restores both unplaced; if their sum passes 9,999 the Undo is refused. `Lot::CapExceeded` takes a lot and its message names `lot.entry`; `over_cap_message` uses `lot.entry.name` and `set_number(lot.entry)`. When an *existing* lot would overflow, the lot named is the first in the sort order, as today (`sort.apply(...)` is SQL and needs rows). When no existing lot is involved, there is no row to sort, so the plan names the first overflowing restored row in the order it was saved, as an unsaved `Lot.new(entry:)`. If both kinds overflow, the existing lot is named (spec 006 AC-7.5 unchanged). This refines AC-7.8's "refused as the cap rule says"; the executor writes the example first. Flagged as O2 in the plan; ruled by the maintainer on 2026-10-24.

## R5. Edit with the location parameter absent

AC-1.8 says a missing or blank location on **add** is unplaced. The spec doesn't say what an edit does with a missing `lot[location_id]`. The edit form always submits the select (blank is "No location"), and an account with no locations has no field, so every real request carries the key or has no placed lot. A hand-made `PATCH` that edits the quantity and leaves the key out would silently unplace a placed lot under the "absent is blank" reading. The plan reads **absent as unchanged** and **blank as unplaced** (one `key?` test, covered by two examples). Flagged as O3; ruled by the maintainer on 2026-10-24: absent keeps the place.

## R6. The preview's lists

Spec 025 decision 11 and `app/views/collections/import_previews/show.html.erb` list only **removed lots** and **problem rows**; the added, changed and unchanged lots are counts. AC-10.9 says "the lists of added, changed and removed lots … add 'in <location>'". The plan applies it to the two lists that exist (removed lots; a problem row's line) and adds no list of added or changed lots, which would be a new preview feature outside this spec. AC-10.7 and AC-11.3 are then checked by counts ("1 lot added, 1 lot removed") and by the removed lot's line. Flagged as O1; ruled by the maintainer on 2026-10-24 and recorded as spec PATCH 1.0.2 (AC-10.7, AC-10.9 name the lists the preview has).

## R7. Queries per page

The pages that gain a place must keep a fixed number of queries (NFR). Traced:

- Card page: `Catalog::CardOverview#lots` is one statement plus the `includes(entry: :set)` preloads; the place is a `LEFT JOIN` for ordering and one `preload(:location)` (a fixed extra query), not per row.
- Move copies page: the lot, its entry and set, the account's locations (one), nothing per row.
- Locations page: the list (one) and `Location::Holdings.counts` (two grouped queries: counts and sums), whatever the number of locations or lots.
- Refusal page: the location, two totals, one list of at most 100 lots with `preload(entry: :set)`.
- Export: the same two statements as before (the lots with their location's name, the locations); a lot's place is its location's name from the lots' own statement (a `LEFT JOIN`), checked against the locations read, and the reads repeat on a mismatch (R11).

`spec/requests/query_counts_spec.rb` already compares a page with little and with much data; Phases 3 to 5 add the new pages to it. Phase 8 records the numbers at 500 locations and 5,000 lots in `verification.md`.

## R8. Spec 031 (the upgrade check)

Spec 031 is approved and being planned in parallel (branch `031-upgrade-from-previous-release`, spec v1.1.1, no ADR owed, plan not on `origin/main`). Read-only against its worktree:
- Its comparison skips "a column only in the new table" (spec 031, *How a database is read*), so the added column needs **no `expected_changes.yml` entry** (that file lists dropped, rewritten and removed or added rows only).
- Its seed for the release not yet cut, `script/upgrade/seeds/next.rb`, runs on the code under test and must cover the schema by table; `lots` is already covered. Putting a lot in a location in `next.rb` is worth doing once the harness is on `main`, so the first release that has this column is proved to keep a placed lot through its own upgrade; if 031 has not merged when this spec's pull request is ready, that is a **follow-up issue** (Phase 8 step), not a blocker.

## R9. The data portability area doc is on `main`

`docs/architecture/data-portability.md` merged in PR #129 (`b873304`), so `.claude/rules/documentation.md` requires this pull request to update it with a source for each new statement (Phase 8). The release and deploy area doc (#109) is not on `main` yet and this change doesn't touch its content (version 3 is not a release concern beyond the document); if it lands first, nothing there changes. The collection-and-lots area doc doesn't exist (`docs/architecture/README.md` lists it as not written), so `CLAUDE.md` carries the line until it does.

## R10. Files traced for this plan

`app/models/{lot,location,account,bulk_removal,collection_export,collection_import,number_entry,number_entry/line}.rb`, `app/models/{lot,collection_import,export_format,scanner}/*.rb`, `app/models/catalog/card_overview.rb`, `app/controllers/{lots,locations,catalog/entries,collections/imports,collections/bulk_removals/undos}_controller.rb` and `app/controllers/{lots,locations}/removals_controller.rb`, `app/controllers/concerns/card_context.rb`, `app/views/{lots,locations,catalog/entries,collections/import_previews}/**`, `app/helpers/{lots,import_previews}_helper.rb`, `config/routes.rb`, `db/schema.rb`, the migrations of lots, locations and number entries, `docs/export-format/README.md` and `v2.schema.json`, `docs/architecture/data-portability.md`, `spec/support/{import_helpers,export_format_rules,backup_helpers,query_counting}.rb`, `spec/{export_format_document,export_format_examples}_spec.rb`, `spec/requests/query_counts_spec.rb`, `spec/models/{bulk_removal,lot}_spec.rb`.

## R11. The export's two reads (plan review M5)

**Question.** Version 3 adds a rule that ties the export's two reads together (`unknown_location`: every lot's `location` is a listed name). `CollectionExport#to_h` reads the locations (`collection_export.rb:33`) and the lots (`:35-36`) in separate statements with no transaction. Can a change between them write a file Collector refuses?

**Found.** Yes. A location renamed between the reads, or created and filled after the locations were read, leaves a lot whose name isn't in the list. A read transaction would fix it, but Rails opens SQLite transactions IMMEDIATE (`sqlite3_adapter.rb:162`, `default_transaction_mode: :immediate`), so it would hold the write lock for the whole export (a 50,000-lot file takes seconds).

**Decision.** Read each lot's location name in the statement that reads the lots (`left_joins(:location)`; spec NFR Performance bullet 2, which a second lookup by id would have contradicted: plan review round 2, M2), then the account's locations, and check that every placed lot's name is among them; if not (a rename or a removal between the reads), repeat both reads, at most 3 times, then `CollectionExport::Unsettled`. A lot and its place cannot disagree; a creation after the lots were read is referenced by no lot read. Same two statements as today, so the count doesn't grow with the lots.

**Not chosen.** A read transaction (the write lock above). Appending unlisted names to the list (writes a location that no longer exists under its old name).

## R12. A migration spec that can see the hazard (plan review M4)

`ActiveRecord::Migration#migrate` (`activerecord-8.1.4/lib/active_record/migration.rb:969`) opens no transaction; the Migrator's `ddl_transaction` does (`:1594-1604`), unless `disable_ddl_transaction` is true. The spec therefore runs the migration through `MigrationContext#run` (`:1283`, via `ActiveRecord::Base.connection_pool.migration_context`, `:nodoc:` but stable in 8.1.4), which is what `db:rollback` does, and asserts `described_class.disable_ddl_transaction` (the class accessor, `:685`). The refusal example calls `Migration#migrate` directly because the Migrator re-wraps an error as `StandardError` (`:1537-1556`).
