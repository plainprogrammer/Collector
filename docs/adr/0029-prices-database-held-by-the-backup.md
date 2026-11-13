# 0029: Prices live in a fifth database with `WITHOUT ROWID` history, and the backup holds it (backup format version 2)

## Status

Accepted (2026-11-13). Written with spec 081 as Proposed; the maintainer accepted it with the pull request ([#405](https://github.com/plainprogrammer/Collector/pull/405)) the same day. The maintainer ruled decision 3 (option A) on 2026-11-13. It supersedes [ADR 0024](0024-backup-with-vacuum-into.md) decisions 2, 3 and 4 in part: what a backup holds, the backup file's layout, and the restore's fresh volume (five databases) and placing (two files). It extends [ADR 0016](0016-sqlite-in-every-environment.md) with a fifth file.

**Date:** 2026-11-13
**Feature:** 081-prices-database-in-backup

## Context

Collector is about to record market prices daily ([price data design](../superpowers/specs/2026-11-13-price-data-design.md); roadmap rulings 35 to 40). The source publishes only today's price, so the history an instance records can't be fetched again: a lost database is lost history. The design's anti-goal is daily price writes in the primary database, which holds every collector's data and the catalog, and its decision 12 proposed a database of its own that the backup holds. [ADR 0016](0016-sqlite-in-every-environment.md) gives each role its own SQLite file; [ADR 0024](0024-backup-with-vacuum-into.md) backs up the primary only, and `spec/backup_guards_spec.rb` fails on a fifth database until the backup's contents are decided.

The history table grows with the catalog every day (the design estimates 0.3 to 0.6 GB a year for the whole catalog at changes-only, unmeasured). Its rows are four small keys and a price. In a rowid table with a unique index on that key, the key is stored twice, once in the table and once in the index; a `WITHOUT ROWID` table stores it once, in the table's own B-tree.

Evidence about Rails 8.1.4.1, read in its source and run in a scratch directory on 2026-11-13 (spec 081 decision 3):

- `create_table` with a composite `primary_key` and `options: "WITHOUT ROWID"` writes the right SQL.
- The SQLite adapter defines no `table_options`, so a Ruby schema dump drops the option. `db:prepare` loads the schema file for a new database, so a new instance and the test database would get rowid tables while an upgraded one got `WITHOUT ROWID`.
- Rails 8.1 reads `schema_format` per database. With `schema_format: sql` the dump keeps `WITHOUT ROWID`, and a new database loaded from it has the option. Dumping and loading run the `sqlite3` command. The image's runtime stage installs it, as do CI's runners (`ubuntu-latest`, Ubuntu 24.04, and `ubuntu-24.04-arm` list sqlite3 3.45.1; Ubuntu 26.04 lists 3.46.1) and macOS.
- Without the command, the load fails quietly. Rails runs it through the shell and ignores its status, so the boot log gets `sh: sqlite3: command not found`. `db:prepare` then finds no `schema_migrations` and runs every migration, which builds the same tables, `WITHOUT ROWID` included. In development the dump fails loudly. In test the tables would be missing.
- SQLite's `alter_table`, which Rails uses for `change_column`, `remove_column`, `rename_column` and the like, copies a table into one built without its options, so such a migration silently drops `WITHOUT ROWID`.

## Options considered

**For the tables (spec 081 decision 3):**

- **A. `WITHOUT ROWID` for `current_prices` and `price_changes`, with the prices database's schema kept as SQL (chosen; ruled 2026-11-13).** The key is stored once, and every instance gets the same tables. Costs: the `sqlite3` command is in the loop for the dump and the load, and later migrations of those two tables must recreate them rather than change a column. A guard checks both.
- **B. Plain rowid tables with unique composite indexes, in a Ruby schema file like the other databases.** Simpler, and no command in the loop. Costs: about 1.5 to 2 times the disk for history, and converting later is a rebuild migration over a large table on every self-hosted instance. Not chosen.

**For the backup:**

- **A. One archive holding both databases, format version 2 (chosen).** One file to keep and restore. A restore places both or neither.
- **B. A second archive, or a second command, for prices.** It could run on its own schedule, but two files can drift apart and be lost apart, and a restore of one without the other is an instance the documents would have to explain. Not chosen.
- **C. Leave prices out of the backup.** Not possible: the history can't be fetched again (design, "Constraints").

## Decision

1. **A fifth database, `prices`**, in every environment, on the same volume as the others: `storage/<environment>_prices.sqlite3`, with migrations in `db/prices_migrate/`. The test environment has it too, so a query that joins the two files fails in the suite as in production. `db:prepare` creates and migrates it on a new or an upgraded volume. No deployment file changes.
2. **Five tables**: `price_sources`, `price_series`, `current_prices`, `price_changes` and `price_refresh_runs` (spec 081 decision 2). Prices are global: no `account_id`, and nothing in the export format. A printing is named by `catalog_entry_id`, with no foreign key and no join across the two files. Foreign keys stay inside the prices file, each `on_delete: :restrict`. The two large tables have no index beyond their primary key, an exception to "index every foreign key" that the maintainer accepted on 2026-11-13: an index on a source or series column would store most of the key again, and nothing deletes a source or a series.
3. **`current_prices` and `price_changes` are `WITHOUT ROWID`**, and the prices database alone has `schema_format: sql` (`db/prices_structure.sql`). A guard fails the suite when either table lacks the option, whether the database was loaded from the structure file or built by the migrations. A change to either table is a new migration that recreates it with the option. Because SQLite's foreign-key check names no rowid for these tables, the backup counts each of their violations on its own.
4. **Backup format version 2**: a gzip'd ustar of `manifest.json`, `primary.sqlite3` and then `prices.sqlite3`. The manifest keeps every version 1 member for the primary and adds `prices` (the schema version, size, SHA-256 and counts of `prices.sqlite3`). `backup:create` takes the two snapshots one after the other, each `VACUUM INTO` in its own read transaction and each verified. It refuses when the prices database is missing, and its free-space check is twice the two databases' sizes together. The two snapshots are seconds apart and nothing ties them together, which is harmless because no key crosses the files.
5. **`backup:restore` restores versions 1 and 2.** A fresh volume holds none of the five databases. For version 2 it checks the prices snapshot as it checks the primary, against `db/prices_migrate/`. It places the prices file first and the primary last, and removes the prices file it placed if the primary can't be placed, so a restore stopped by a refusal or an error leaves neither. A killed restore can leave the prices file alone, never a primary without its prices. The next run refuses that volume and says to remove the file. Collector must never be started on that volume: its start would create a blank primary and keep the stale prices, which the new catalog's ids would attach to the wrong printings. A version 1 backup places the primary only, and the first start creates an empty prices database. Everything else in ADR 0024 decisions 4 and 5 stands: no connection to either configured path, no Active Record, no migration, and no `:environment`.

## Consequences

- **Good:** the price history survives a lost disk with the procedure operators already use. A backup from an earlier release still restores. The upgrade proof, the container smoke and the suite cover the new file (spec 081 decision 10).
- **Good:** the history stores its key once, on every instance, before the table holds any row.
- **Cost:** a backup is now two full rewrites, and its temporary disk covers both databases. Once #365 schedules the daily refresh, its window joins the catalog refresh's in the backup schedule advice, because a read transaction holds the WAL back.
- **Cost:** two placings are not one atomic step. A restore killed between them leaves a prices file alone, which the operator removes before restoring or starting (`docs/backup-restore.md`). A start that refuses that state is [#375](https://github.com/plainprogrammer/Collector/issues/375).
- **Cost:** a migration author of the two large tables can't use `change_column` and its kin. The guard and the area doc say so.
- **Cost:** the prices schema file depends on the `sqlite3` command where it is dumped (development) and loaded (test, a new instance). A missing command at boot still yields the right database, through the migrations.
- **Limit:** the two snapshots of one backup aren't one moment. A price row may name a printing that the restored primary lacks, and readers treat that as no entry.
- **Follow-up:** the size of a backup with a year of history is #366's to measure and #370's to document. An operator choice to leave history out of a backup waits for those numbers.
