# Prices

Where market prices live, how their database is built and what may never cross from it to the rest of the instance. This is the current truth; when it and an older spec disagree, this doc is right.

## Scope

The prices database: its configuration, its tables, the connection class later models inherit, and the rules that keep prices global and apart from collectors' data (spec 081). The price source contract (#364), the daily refresh (#365), the run record (#366), the admin log (#367), the history levels (#368), the display (#369) and the operator's cost documentation (#370) will extend this doc.

Neighbouring areas: the backup that holds the prices database, its format and its restore are in [release and deploy](release-and-deploy.md). The printings that prices name are the catalog's ([catalog core](catalog-core.md)). The export format holds no price ([data portability](data-portability.md)).

## Glossary

- **Prices database:** the instance's fifth SQLite file, `storage/<environment>_prices.sqlite3`, with its migrations in `db/prices_migrate/` and its schema in `db/prices_structure.sql` (spec 081 decision 1; [ADR 0029](../adr/0029-prices-database-held-by-the-backup.md)).
- **Printing:** one catalog entry, named in the prices tables by `catalog_entry_id`, the id of its `catalog_entries` row (spec 081 decision 4).
- **Price source:** where prices come from, with the attribution a page shows and whether a hosted, paid instance may show it (`price_sources`; spec 081 decision 2).
- **Price series:** what a price means: a finish, an ISO 4217 currency and a kind such as `market`. Series are global, not per source (`price_series`; spec 081 decision 2).
- **Current price:** the latest known price of one printing in one series from one source (`current_prices`).
- **Price change:** one row of history, recorded on the day a price differs from the last one recorded; a row with no cents records that the price went away that day (`price_changes`; design decision 7).
- **Price refresh run:** one run of the daily refresh (`price_refresh_runs`). Its identity and times only, so far; #366 adds the measurements (spec 081 decision 2).

## Invariants

- **Prices live in their own file.** No price table is in the primary database, and the daily writes never touch it (spec 081 decision 1, FR-1; the design's anti-goal).
- **Prices are global.** No price table has `account_id` or `user_id`, and nothing of the prices database is in an export, a preview or an apply (spec 081 decision 4, AC-3.1, AC-3.2).
- **Nothing crosses the two files.** There is no foreign key from a price table to the primary (SQLite can't make one across files), and no query joins or attaches the two. Code looks up prices by printing. The test environment has both databases, so a join fails in the suite as it would in production (spec 081 decisions 1 and 4, AC-3.3, AC-3.4).
- **A price row may name a printing the primary doesn't have** (a backup's two snapshots are taken seconds apart; a retired entry). That is never an error: a reader finds no entry and shows nothing (spec 081 decision 4).
- **Foreign keys stay inside the prices file**, and each one is `on_delete: :restrict`: a source or a series that prices name can't be deleted (spec 081 decision 2, AC-3.3).
- **`current_prices` and `price_changes` are `WITHOUT ROWID`**: their primary key is the table, so the key is stored once. That holds on a database loaded from `db/prices_structure.sql` (a new instance, the test database) and on one built by the migrations (an upgraded instance), and `spec/prices_schema_spec.rb` fails when either table lacks the option (spec 081 decision 3, ruled 2026-11-13; AC-2.1 to AC-2.3).
- **The two large tables have no index beyond their primary key.** Lookups go by printing, the key's first column. An index on `price_source_id` or `price_series_id` would store most of the key again and undo the saving, so this is an accepted exception to "index every foreign key" (`.claude/rules/sqlite-and-migrations.md`). Deleting a source or a series would scan the table, and nothing does (spec 081 decision 2; the maintainer's ruling of 2026-11-13).
- **The prices schema names no collectible**: its migrations, its structure file and `PricesRecord` never name a game or a source (spec 081 decision 9, AC-3.5; `spec/prices_core_spec.rb`).
- **The backup holds the prices database** beside the primary; how is in [release and deploy](release-and-deploy.md) (spec 081 decision 6).

## States and transitions

- **The prices database comes into being with the instance's start.** `bin/rails db:prepare` creates it on a new volume, loading `db/prices_structure.sql`, and on an upgraded one that lacks it. A missing `sqlite3` command at that point leaves the load undone and two `command not found` lines in the log, and `db:prepare` then runs every prices migration from scratch, which builds the same tables (spec 081 decision 3).
- **A run's status** is one of `running`, `finished`, `skipped` and `failed`, fixed by a check so that #365 needs no rebuild of a released table to use them; what moves a run between them is #365's (spec 081 decision 2).

## Named constants

| Name | Value | Where | Why | Source |
|---|---|---|---|---|
| Prices database file | `storage/<environment>_prices.sqlite3` | `config/database.yml` | Beside the other four, on the same volume | spec 081 decision 1 |
| Prices schema format | `sql` (`db/prices_structure.sql`) | `config/database.yml` | A Ruby schema dump drops `WITHOUT ROWID` (the SQLite adapter defines no `table_options`); the SQL dump keeps it | spec 081 decision 3; ADR 0029 |
| `price_refresh_runs.status` values | `running`, `finished`, `skipped`, `failed` | `db/prices_migrate/20261113100001_create_price_tables.rb` | The design's three outcomes and a run in progress | spec 081 decision 2 |

## Decisions not in an ADR

- **A change to `current_prices` or `price_changes` is a new migration that recreates the table.** On SQLite, Rails changes a column (`change_column`, `remove_column`, `rename_column`, `change_column_null`, `add_check_constraint` and the like) by copying the table into a new one built without its options, so `WITHOUT ROWID` would be silently lost. Write a migration that creates the new table with `options: "WITHOUT ROWID"`, copies the rows and swaps the names; `spec/prices_schema_spec.rb` fails otherwise. `add_column` of a nullable column is safe: SQLite's `ALTER TABLE ADD COLUMN` keeps the table. The first prices migration says the same in its header (spec 081 decision 3, AC-7.3).
- **`PricesRecord` has the writing role only**: nothing reads a replica, and a reading pool that the suite's restored-instance helper doesn't re-point would be a trap (spec 081 decision 5; plan review).
- **The structure file carries query-log comments.** Statements run in development end with `/*application='Collector'*/` (`config.active_record.query_log_tags_enabled`), SQLite stores them with the definition, and the dump keeps them. Production stores none. `spec/prices_schema_spec.rb` strips comments before it compares definitions (spec 081 execution, batch A).
- **The structure file needs the `sqlite3` command** where it is dumped (development, after a migration) and loaded (the test database, a new instance). It is in the image's runtime stage and on CI's runners; CI installs none itself (spec 081 decision 3).
- **No model per table yet.** This spec built the schema and the connection only; each later prices issue writes the models, readers and writers it owns (spec 081 decision 5, Non-Goals).

## Sources

- [Spec 081](../specs/081-prices-database-in-backup/spec.md): decisions 1 to 5, 9 and 12, Stories 1 to 3 (the backup's part is in [release and deploy](release-and-deploy.md)).
- [ADR 0029](../adr/0029-prices-database-held-by-the-backup.md).
- [Price data design](../superpowers/specs/2026-11-13-price-data-design.md) (2026-11-13); roadmap rulings 35 to 40.
- Issues [#363](https://github.com/plainprogrammer/Collector/issues/363) (this database), [#375](https://github.com/plainprogrammer/Collector/issues/375) (a start that refuses a prices file with no primary: built by [spec 086](../specs/086-start-refuses-orphan-prices/spec.md), whose rules, the check and its message, are in [release and deploy](release-and-deploy.md)).

## Distillation log

| Date | What | Pull request |
|---|---|---|
| 2026-11-13 | Spec 081 (decisions 1 to 5, 9 and 12: the prices database, its five tables, `WITHOUT ROWID` with the SQL schema file, the index exception, `PricesRecord`, the rules that keep prices global and apart; this doc's first distillation) | [#405](https://github.com/plainprogrammer/Collector/pull/405) |
