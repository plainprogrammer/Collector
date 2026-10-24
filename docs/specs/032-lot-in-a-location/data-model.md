# Data Model: Put a Lot in a Location

**Spec:** [spec.md](spec.md) (v1.0.2, Approved) · **Plan:** [plan.md](plan.md) · **Decision:** [ADR 0025](../../adr/0025-a-lots-location-is-part-of-its-identity.md)

One column, one index and one foreign key on `lots`. No new table. Nothing is backfilled.

## `lots` (changed)

| Column | Type | Null | Notes |
|---|---|---|---|
| `location_id` | integer | yes | **New.** The lot's place; `NULL` is *unplaced*. References `locations(id)` with `ON DELETE RESTRICT`: the database refuses deleting a location a lot is in (AC-5.5). |
| `lot_key` | string | no | **Meaning extended, column unchanged.** `finish|condition|price_paid_cents`, then, for a placed lot only, `|` and the location's id. |

Every other column is as it is (`account_id`, `catalog_entry_id`, `quantity` 1 to 9,999, `finish`, `condition`, `price_paid_cents`, `created_at`, `updated_at`).

### Indexes

| Index | Columns | Unique | Status |
|---|---|---|---|
| `index_lots_on_account_id_and_catalog_entry_id_and_lot_key` | `account_id`, `catalog_entry_id`, `lot_key` | yes | **Unchanged.** It backs "an account never holds two lots of one identity" because the place is in `lot_key`. |
| `index_lots_on_catalog_entry_id` | `catalog_entry_id` | no | Unchanged. |
| `index_lots_on_location_id` | `location_id` | no | **New.** Backs the foreign key's check, the locations page's grouped counts and the refusal page's list. |

### Why the place is in the key, as the location's id

SQLite treats `NULL`s in a unique index as distinct, so `[account_id, catalog_entry_id, lot_key, location_id]` would let two unplaced lots of one identity exist. The key text already carries the identity, so it carries the place too (spec 032 Notes for the plan).

| Lot | `lot_key` |
|---|---|
| Unplaced, foil, near mint, 150 cents | `foil|near_mint|150` (what it is today; the migration rewrites nothing) |
| The same in the location with id 7 | `foil|near_mint|150|7` |
| Unplaced, no finish, no condition, no price | `||` (today's value) |
| The same in location 7 | `|||7` |

- The id, not the name: renaming a location (spec 029) or applying a file that respells it keeps every key (AC-11.5).
- A finish, a condition and a price never contain `|` (vocabulary values and an integer), so a placed key has three separators and an unplaced one two; no placed key equals an unplaced key.
- Four places build a key; all four take the place: `Lot.key_for(finish, condition, price_paid_cents, location_id = nil)`, `BulkRemoval#identity` and its raw `insert_all`, the SQL `update_all` in `Lot::ConditionChange#update_alone!`, and `CollectionImport::Apply#lot_attributes` with its `unique_by: [account_id, catalog_entry_id, lot_key]`.

## `locations` (unchanged)

Spec 029's table is as it is: `account_id`, `name`, `name_key`, timestamps, unique `[account_id, name_key]`. A location is now referenced by lots, so deleting one is refused while a lot is in it, in `LocationsController#destroy` (409) and in the database.

## Tables that point at lots (the migration names them)

| Table | Column | `ON DELETE` | Must survive the migration |
|---|---|---|---|
| `bulk_selection_marks` | `lot_id` | `CASCADE` | Every mark still points at its lot |
| `number_entry_lines` | `lot_id` | `SET NULL` | Every line keeps its `lot_id` |
| `scanner_sitting_entries` | `lot_id` | `SET NULL` | Every entry keeps its `lot_id` |
| `bulk_removals` | `lots_data` (JSON, no foreign key) | | An undoable removal stays undoable; its saved lots have no `location_id`, read as unplaced (AC-7.8) |

Rebuilding `lots` the way Rails does for most `ALTER`s on SQLite (create a copy, `DROP TABLE lots`, rename) runs `ON DELETE` actions on these tables when foreign keys are enforced, which they are inside a transaction. The migration therefore never rebuilds `lots` going up (`ADD COLUMN … REFERENCES`), and rebuilds it going down only outside a transaction (Phase 0, research R1).

## Deleting an account

`Account` declares `has_many :lots, dependent: :delete_all` before `has_many :locations, dependent: :delete_all`; the `before_destroy` callbacks they add run in that order, so lots go first and the restrict foreign key never fires (AC-6.6). The order is load-bearing: a comment on the declarations says so and a spec guards it.

## `bulk_removals.lots_data` (JSON, extended)

Each saved lot gains `"location_id"` (an integer or `null`); the existing keys are as they were. A removal made before the migration has no such key and is read as `null` (AC-7.8). On Undo a `location_id` the account no longer has is read as `null` (P5).

## Derived values (no storage)

| Value | From | Used by |
|---|---|---|
| A location's lots and copies | `lots` grouped by `location_id` (one query for every location, `Location::Holdings.counts`; two for one location, `Location#holdings`) | locations page (P2), refusal page (P1) |
| A printing's "Your copies" rows | the account's lots of every printing of the card, `LEFT JOIN locations`, ordered as today then by `locations.name_key`, `locations.name` (`NULL` first) | card page (AC-4.1) |
| A held lot's place in a plan | `LEFT JOIN locations`; the identity's sixth value is `locations.name_key` | `CollectionImport` (AC-10.2) |
| A lot's `location` in the export | `LEFT JOIN locations` in the statement that reads the lots, `locations.name` (Phase 7; spec NFR Performance) | `CollectionExport` (AC-8.1, AC-8.3) |

## Cost per account

One integer per lot and its index entry, and the place in a placed lot's key: about 30 bytes a placed lot and fewer for an unplaced one (about 150 KB for 5,000 lots, 1.5 MB for 50,000, at most). No new table, job, cache entry or background work. Measured in `verification.md` (Phase 8).

## Migration

`db/migrate/20261023100001_add_location_to_lots.rb`, `disable_ddl_transaction!`:

| Direction | Does | Safe because |
|---|---|---|
| `up` | `ALTER TABLE lots ADD COLUMN location_id integer REFERENCES locations (id) ON DELETE RESTRICT` unless the column exists; `add_index :lots, :location_id` unless it exists | `ADD COLUMN` copies nothing and takes a `NULL` default (every lot's value); both steps are guarded so a re-run after a crash between them completes; no application model is referenced |
| `down` | Refuses (`ActiveRecord::IrreversibleMigration`, naming how many lots are placed) while any lot has a `location_id`; otherwise removes the index, then the column | The rebuild Rails does for `remove_column` runs outside a transaction (that is why `disable_ddl_transaction!`), where `PRAGMA foreign_keys = OFF` takes effect, so the marks, lines and entries keep their rows |

Proved by `spec/migrations/add_location_to_lots_spec.rb` (Phase 0) against a database with a mark, a line, an entry, an undoable removal and lots, going down and up through the Migrator (`MigrationContext#run`, which wraps the migration in a transaction unless it disables one, as `db:rollback` does; `Migration#migrate` alone opens none), plus an assertion that `disable_ddl_transaction` is on.

Self-hosters need nothing else: `bin/rails db:prepare` on boot runs it; an instance that never uses locations ends with one empty column.
