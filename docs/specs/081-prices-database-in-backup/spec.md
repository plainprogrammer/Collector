# Feature 081: A Prices Database That the Backup Holds

**Status:** Draft
**Version:** 1.2.0
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Branch:** `081-prices-database-in-backup`
**Issue:** [#363](https://github.com/plainprogrammer/Collector/issues/363)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.2.0 | 2026-11-13 | Revised after the Mode A review, round 2 (no blocking findings; two major, nine minor). Starting on a volume that holds a prices file and no primary keeps the stale prices and gives the new catalog's printings the wrong history, so the documents and the refusal say never to start on it; a boot-time refusal is a follow-up (decision 8). The child processes' schema files: a fresh, absent `SCHEMA` path per command, and the repository's schema files stay untouched (decision 12, AC-6.9). The proof tells a previous release with prices from one without by its tag's `db/prices_migrate/`, and copies the prices file with its sidecars (decision 10). The runs index isn't unique. The orphan count's wording. Testable AC-1.2, AC-1.3 and AC-1.5. More superseded parts of specs 030 and 031 and of ADR 0024 decision 4 |
| 1.1.0 | 2026-11-13 | Revised after the Mode A review, round 1 (no blocking findings; four major, eight minor). A killed restore can leave a prices file alone, and the documents and the refusal say what to do (decision 8, AC-5.9). The suite's own machinery for two test databases (decision 12). No secondary index on the two large tables and `on_delete: :restrict` on every key, a ruled exception to "index every foreign key" (decision 2). The run's status values (decision 2). The connection class is named (decision 5). The orphan-row count for `WITHOUT ROWID` tables (decision 3). The reports' schema versions (decisions 7 and 8). The guard's lists come from the backup's own constant (AC-6.1). How AC-5.7 is verified. The harness's version checks (decision 10). More superseded parts of specs 030 and 031, and more documents (decision 11) |
| 1.0.0 | 2026-11-13 | Written from issue #363, the [price data design](../../superpowers/specs/2026-11-13-price-data-design.md) (decisions 7, 10, 12 and 13, "Data", "The run record"), the roadmap's prices lane (rulings 35 to 40), [ADR 0024](../../adr/0024-backup-with-vacuum-into.md), spec 030 and spec 031 as built, and the maintainer's ruling of 2026-11-13 on `WITHOUT ROWID` (decision 3, option A) |

---

## Problem Statement

Collector is about to record market prices every day, and the history it records can't be fetched again: the source publishes only today's price, so a lost day is a gap for good and a lost database is lost history (design, "Constraints"). The daily writes would be large and frequent, and the primary database holds every collector's data and the catalog; the design's anti-goal is "daily price writes in the primary database". Today the instance has four SQLite files, a backup holds the primary one only (ADR 0024), and `spec/backup_guards_spec.rb` fails the suite when a fifth database appears until the backup's contents are decided.

This spec adds the place prices live and makes the backup hold it, before any price is recorded: a fifth SQLite database, beside the primary, with the five tables the later prices issues need (sources, series, current prices, price changes and refresh runs), held by `backup:create` and brought back by `backup:restore`, and proven by the suite, the container smoke and the upgrade proof. It writes no price, reads no price and shows no price; #364 to #370 do.

> **Terms.** *Prices database*: the fifth SQLite file, `storage/<environment>_prices.sqlite3`. *Printing*: one catalog entry, the row of `catalog_entries` a lot points at. *Price source*: where prices come from (Scryfall is the first, #364). *Price series*: what a price means, a finish, a currency and a kind such as market (design, "Data"). *Current price*: the latest known price of one printing in one series from one source. *Price change*: one row of history, recorded when a price differs from the last one recorded (design decision 7). *Price refresh run*: one run of the daily price refresh (#365, #366). *Backup format version*: the backup file's own version number (ADR 0024 decision 3; `docs/backup-restore.md`).

## Goals

- The instance has a prices database separate from the primary, in development, test and production, created by the start of a new instance and of an upgraded one alike, with the five tables the issue lists (decisions 1 and 2).
- The two tables that grow with the catalog store their key once (`WITHOUT ROWID`), on a new instance, an upgraded one and the test database alike, and a later migration that would lose that fails the suite (decision 3, ruled).
- Prices are global data like the catalog: no `account_id`, nothing in the export format, and no foreign key or query that crosses from one database file to the other (decision 4).
- `backup:create` holds the prices database beside the primary, verified as the primary is, and `backup:restore` brings both back onto a fresh volume, or neither (decisions 6 to 8).
- A backup made by an earlier release (format version 1, the primary only) still restores, and the restored instance's first start creates an empty prices database (decision 6).
- The upgrade proof covers the new file: an upgrade from a release without it, a backup of such a release restored, and, from the next release on, an upgrade and a restore that carry price rows (decision 10).

## Non-Goals

- The price source contract and Scryfall's prices through it (#364); the daily refresh, its job, its schedule and what it writes (#365); the run record's measurements (#366); any page, admin or otherwise (#367, #369); the history levels (#368); the operator's cost documentation (#370).
- Models for the five tables, and any reader or writer of a price. This spec builds the schema and the connection to it; each later issue writes the code it owns (decision 5).
- Prices in the export format or the import. Prices are not collector-owned data (design, "Data"; decision 4).
- Restoring prices into an instance that already has data, restoring one database of a backup without the other, or a backup of the prices database alone.
- Backing up the queue, cache or cable databases (unchanged from ADR 0024).
- Making the two snapshots of one backup a single point in time across both files (decision 7).

## Users and Context

**Primary users:** the operator of a self-hosted instance, who backs it up and restores it with the two commands of spec 030 and upgrades it by starting a new release on the same volume.
**Secondary users:** the agents and contributors who build #364 to #370 on this schema; the maintainer, whose release procedure restores a real backup.
**Usage context:** a shell inside the running container (`backup:create`), a one-off container on an empty volume (`backup:restore`), and the container's start (`db:prepare`), which creates and migrates every configured database.
**User mental model:** "the backup is the instance". An operator who restores a backup expects the prices and their history back, as they expect the collections back, and doesn't think in database files.

## Decisions

### 1. Prices live in a fifth database, `prices`, beside the primary (design decision 12)

The configuration gains a database named `prices` in development, test and production, with its own migrations directory, `db/prices_migrate/`, as the queue, cache and cable databases have theirs. The files are `storage/development_prices.sqlite3`, `storage/test_prices.sqlite3` and `storage/production_prices.sqlite3`, beside the others on the same volume. The start of a container (`bin/docker-entrypoint` runs `bin/rails db:prepare`) creates it on a new volume and on an upgraded one alike; no deployment file changes (`Dockerfile`, `config/deploy.yml`, `compose.yaml` and the workflows stay as they are).

**The test environment gains a second database.** Today it has one (the primary, which also holds Solid Queue's tables for the admin pages' specs). It gets `prices` beside it, so the suite runs against two files as production does and a query that joins across them fails in the suite as it would in production (decision 4).

### 2. The tables

Five tables, all in the prices database. Columns are named here because the schema is this spec's deliverable; the later issues may add columns through new migrations, never by editing these.

| Table | Columns | Keys and checks |
|---|---|---|
| `price_sources` | `id`; `key` (the source's stable name, such as `scryfall`); `name`; `attribution` (the text a page shows); `attribution_url` (optional); `hosted_paid_allowed` (whether the source may be shown on a hosted, paid instance, design "The source contract"); timestamps | `key` unique and not blank; `name` and `attribution` not blank; `hosted_paid_allowed` not null, default false |
| `price_series` | `id`; `finish` (a value of the collectible's finish vocabulary); `currency` (an ISO 4217 code); `kind` (such as `market`); timestamps | unique on (`finish`, `currency`, `kind`); `currency` three upper-case letters; every column not null |
| `current_prices` | `catalog_entry_id`; `price_source_id`; `price_series_id`; `cents`; `reported_on` (the date the source reported the price); `changed_on` (the date it last changed) | primary key (`catalog_entry_id`, `price_source_id`, `price_series_id`); `cents` not null and ≥ 0; both dates not null; foreign keys to `price_sources` and `price_series`; no other index; `WITHOUT ROWID` (decision 3) |
| `price_changes` | `catalog_entry_id`; `price_source_id`; `price_series_id`; `recorded_on` (the run's date); `cents` (null when the price went away that day, design "Data") | primary key (`catalog_entry_id`, `price_source_id`, `price_series_id`, `recorded_on`); `cents` null or ≥ 0; foreign keys to `price_sources` and `price_series`; no other index; `WITHOUT ROWID` (decision 3) |
| `price_refresh_runs` | `id`; `price_source_id`; `run_on` (the run's date, the bulk file's UTC date); `source_version` (the source file's version, so a file already applied is skipped, design "The daily refresh" step 1); `status`; `error` (optional); `started_at`; `finished_at` (optional); timestamps | `price_source_id`, `run_on`, `status` and `started_at` not null; `status` one of `running`, `finished`, `skipped` and `failed` (the design's three outcomes and a run in progress); foreign key to `price_sources`; index on (`price_source_id`, `run_on`) |

- **Series are global, not per source.** A series says what a price means; the same series can come from two sources, and a current price names both (design, "Data": "one row per printing, source and series"). Scryfall's six (three finishes by two currencies, market) are #364's to insert.
- **The runs index is not unique**: a failed run and its retry share a source and a date. What #365 looks up to skip a file already applied is its own.
- **The run table holds the run's identity and times only** (the design's "Identity" and "Time" groups), the columns #365 needs to run once per file. The input, prices, writes, storage and process groups are #366's, through its own migration (issue #363: "the run log's contents beyond its table" are out of scope).
- **The two large tables carry no timestamps.** Their dates carry the meaning, and two timestamps would add a third or more to each row of the table that grows (design, "Approaches").
- **Foreign keys stay inside the prices file**, and every one is `on_delete: :restrict`: a source or a series that prices name can't be deleted. `catalog_entry_id` has none (decision 4).
- **No secondary index on the two large tables: a ruled exception to "index every foreign key"** (`.claude/rules/sqlite-and-migrations.md`). An index on `price_source_id` or `price_series_id` would store most of the key again and undo much of decision 3's saving. The cost is that deleting a source or a series, which nothing here or in the design does, checks the whole table. Lookups go by printing, the primary key's first column. ADR 0029 and `prices.md` record the exception.
- **The run's status values are fixed now**, by a check, so that #365 doesn't need a rebuild of a released table to add one. What each value means is #365's.

### 3. `WITHOUT ROWID` for `current_prices` and `price_changes`; the prices database's schema is kept as SQL (ruled 2026-11-13, option A)

Issue #363 left open whether these tables could be `WITHOUT ROWID` through a Rails migration. The maintainer ruled option A on 2026-11-13, on this evidence (Rails 8.1.4.1, read and run in a scratch directory on 2026-11-13):

- **The migration can make them.** `create_table` with a composite `primary_key` and `options: "WITHOUT ROWID"` writes `CREATE TABLE … PRIMARY KEY (…)) WITHOUT ROWID`.
- **The Ruby schema file can't keep them.** The SQLite adapter defines no `table_options`, so `db/schema.rb`-style dumps drop the option, and `db:prepare` loads the schema file for a *new* database: a new instance and the test database would get rowid tables while an upgraded instance got `WITHOUT ROWID`.
- **An SQL schema file keeps them.** Rails 8.1 takes `schema_format` per database, so the prices database alone uses `schema_format: sql`, and its schema file is `db/prices_structure.sql`; the other four databases keep their Ruby schema files. A new database loaded from it has `WITHOUT ROWID` tables.
- **Dumping and loading that file run the `sqlite3` command.** It is in the image's runtime stage (the `Dockerfile`'s `base` stage installs `sqlite3`), on the runners CI uses (`ubuntu-latest`, which is Ubuntu 24.04, and `ubuntu-24.04-arm` both list sqlite3 3.45.1 in actions/runner-images' Readme; Ubuntu 26.04 lists 3.46.1) and on macOS (`/usr/bin/sqlite3`). No deployment or workflow file changes.
- **A missing command at boot changes nothing that matters.** Rails runs the load through the shell and ignores its status: the boot log gets `sh: sqlite3: command not found` lines, the load leaves no `schema_migrations`, and `db:prepare` then runs every prices migration from scratch, which makes the same tables, `WITHOUT ROWID` included. In development the dump after a migration fails loudly ("failed to execute: sqlite3"), and in test the load leaves the prices tables missing, so the suite doesn't pass (it stops on pending migrations or fails on missing tables).
- **The other costs, stated.** Rails passes the database's path to the shell unquoted and relative, so the load runs from the app's root, as `bin/rails` and the container do. Development rewrites `db/prices_structure.sql` after each migration with the local `sqlite3` (`.schema --nosys`), which prints the SQL that SQLite stored, so the file changes only when the schema does. CI installs no `sqlite3` itself and relies on the runner image.
- **SQLite's foreign-key check names no row of a `WITHOUT ROWID` table** (its rowid is null), so spec 030's count of rows that fail the check (`Snapshot#verify!` counts distinct table and rowid) would count all of a table's violations as one. The count counts rows for rowid tables, as today, and violations for `WITHOUT ROWID` tables, so a row of those with two broken keys counts twice; the refusal's wording ("rows") stays (AC-4.5).
- **The trap that stays: SQLite's `alter_table`.** Rails changes a column on SQLite by copying the table into a new one built without the original's options, so a later `change_column`, `remove_column`, `rename_column` or the like on either table silently drops `WITHOUT ROWID`. A guard fails the suite when either table, on the structure-loaded test database or on a database built by running the migrations, lacks it (AC-2.3); the area doc and a comment in the first prices migration tell the next migration author (AC-7.3).

Why the tables are worth it: a rowid table with a unique index on its key stores the key twice, once in the table and once in the index, which for `price_changes` (four small keys and a price) roughly doubles the table that grows with the catalog every day (design, "Approaches": 0.3 to 0.6 GB a year for the whole catalog, unmeasured). Converting later would be a rebuild migration over that table on every self-hosted instance; today the tables are empty. Option B, plain rowid tables in a Ruby schema file, was simpler and not chosen.

### 4. Prices are global, keyed by the catalog entry's id, and never joined across files

- No prices table has `account_id` or `user_id`, so the export format's coverage guard is unaffected, and nothing of the prices database is in an export, a preview or an apply.
- A printing is named by `catalog_entry_id`, the integer id of its row in `catalog_entries`, the same value `lots.catalog_entry_id` holds. An integer keeps the keys of the two large tables small; the id is stable while the catalog refresh upserts by the source's key, and both files are backed up and restored together. A printing that a source later merges into another is #371's (2.0).
- There is no foreign key to the primary database (SQLite can't make one across files), and no query joins the two files: code looks up prices by printing (issue #363). The suite's two test databases make a join fail (decision 1).
- **A price row may name a printing the primary doesn't have** (a restore's two snapshots are seconds apart, decision 7; a retired entry). It is never an error: a reader finds no entry and shows nothing, and nothing here deletes such rows.

### 5. What this spec builds, and what it leaves

Builds: the configuration (decision 1), the migrations and the structure file (decisions 2 and 3), one abstract connection class for the prices database that later models inherit, `PricesRecord` in `app/models/prices_record.rb` (named for the database, as `ApplicationRecord` is the primary's), the backup and restore changes (decisions 6 to 8), the upgrade proof's coverage (decision 10), the guards, and the documents (decision 11).

Leaves: a model per table, scopes, validations, any reader or writer, the source rows and the series rows. The issue says to build only the schema those later issues need. The connection class is in because without it nothing in the app could reach the database, and the seed of the upgrade proof and the suite's round trip need to write rows to it. They write them with SQL through that connection, not through models.

### 6. A backup holds the prices database: backup format version 2

- `backup:create` writes **format version 2**: a gzip'd ustar of `manifest.json`, `primary.sqlite3`, then `prices.sqlite3`, in that order, each 0600, under the same name, `.partial` and linking rules as version 1 (ADR 0024 decision 3).
- **The version 2 manifest** has every member of version 1, with the same meaning for the primary (`taken_at`, `schema_version`, `snapshot_bytes`, `snapshot_sha256`, `counts` of accounts, users and lots), plus one member, `prices`: `{ "schema_version", "snapshot_bytes", "snapshot_sha256", "counts": { "current_prices", "price_changes" } }`, each as its primary counterpart but for `prices.sqlite3`. Counts only, never a name (spec 030 AC-1.7).
- **A release restores every version it has shipped**: this one restores 1 and 2 (`FORMAT_VERSIONS` is `[1, 2]`). Version 1 keeps its meaning: one snapshot, the primary. A release that knows only version 1 refuses a version 2 file as an unknown version, naming both (spec 030 AC-3.4), which is right: it is from a newer release.
- **A version 1 backup restores the primary only.** The volume gets no prices file, and the first start's `db:prepare` creates an empty, migrated prices database. The restore's report says that the backup holds no prices.

### 7. `backup:create` takes both snapshots, one after the other

- It snapshots the primary, then the prices database, each with `VACUUM INTO` in its own read transaction (ADR 0024 decision 1), each put in rollback-journal mode and verified with SQLite's integrity check and foreign-key check before the archive is written. Any failure of either leaves no file under a final name and removes the run's `.partial` files (spec 030 decision 7).
- **The two snapshots are not one moment.** They are taken seconds apart, and nothing ties them: no foreign key crosses the files (decision 4), so a price row for a printing created between the two snapshots is harmless (decision 4's last bullet). `taken_at` is when the run started, as in version 1.
- **The free-space check** asks for twice the sum of the two databases' sizes (spec 030 decision 13, AC-1.11, which asked for twice the primary's).
- **A missing prices database is refused**, with what to do: start Collector once on this release, whose start creates it, then run the command again. A running instance of this release always has one; a refusal is clearer than a backup that silently lacks prices.
- The report gains the prices database's schema version and counts: `Schema version: 20261101000000; prices 20261113000001` and `Holds: 2 accounts, 3 users and 120 lots; 0 current prices and 0 price changes`.

### 8. `backup:restore` brings both back, or neither

- **A fresh volume** holds none of the five databases and none of their `-wal`, `-shm` or `-journal` files (spec 030 decision 6, now five). A prices file alone makes a volume not fresh.
- **Version 2 checks, in spec 030 FR-2's order:** the file's kind, completeness and version; the room (the two snapshots' sizes plus the margin); both checksums in one read; then, on two temporary files on the volume, each snapshot's integrity and foreign-key checks, that no migration in either is newer than the release's (the primary's against `db/migrate/`, the prices database's against `db/prices_migrate/`), the sessions ended in the primary (spec 030 decision 3; nothing is cleared in the prices database), both in rollback-journal mode, and every count agreeing with the manifest.
- **Placing:** the prices snapshot is linked into place first and the primary last, each never replacing a file. If the primary can't be placed, the prices file this run placed is removed, so a restore that stops leaves neither database (spec 030: "A restore that stops anywhere leaves no primary database"). The temporary files are the restore's own fixed names, removed with their `-journal` on any refusal (spec 030 FR-6).
- **A killed restore** (SIGKILL, a power loss) between the two placings can't run its cleanup, and leaves the prices file alone on the volume. The order is chosen for that case: a primary never stands without its prices (the other order would leave a primary whose first start creates an empty prices database, losing the history without a word), and a prices file alone makes a re-run refuse the volume as not fresh. That refusal, when the volume holds a prices file and no primary, says the file may be a stopped restore's and to remove it (with its sidecars) before running the restore again, and `docs/backup-restore.md` says the same (AC-5.9). **Collector must never be started on such a volume.** Its start creates a new, blank primary (whose first visitor becomes its admin) and keeps the restored prices, because `db:prepare` leaves a database that already has its `schema_migrations` alone; the new primary's catalog then gives printings new ids, so the old history would attach to the wrong printings (decision 4 relies on the two files travelling together). The refusal's advice, `docs/backup-restore.md` and the README's restore steps say to remove the prices file and its sidecars before restoring *or starting*. A start that refuses this state on its own is a follow-up issue, not built here: it needs a check at boot, outside the backup's code, and the state needs a killed restore.
- **A prices snapshot newer than the release** is refused like a primary one, naming the prices schema versions.
- The report gains the prices database's schema version and counts (`Taken … at schema version 20261101000000 (prices 20261113000001); it holds … and 0 current prices and 0 price changes.`), or, for a version 1 backup, "The backup holds no prices; Collector's first start creates an empty prices database."
- The restore still never opens a connection to either configured path, uses `SQLite3::Database` and never Active Record, and runs no migration (ADR 0024 decision 4).

### 9. The backup's code stays core

`lib/collector/backup/` and `lib/tasks/backup.rake` keep naming no collectible (spec 030 FR-5), and the prices schema (the migrations, the structure file and the connection class) names none either: prices are a core concept that a collectible's extension supplies through #364's contract. A guard reads those files.

### 10. The upgrade proof covers the new file (spec 031)

- **Which case applies** is decided by the previous release's tag: whether it has `db/prices_migrate/`, not whether its volume has the file. When the tag has it, the old volume must hold the prices file and its `schema_migrations` must equal that directory's versions at the tag, as the proof checks the primary today; a release that should have made the file and didn't fails the proof.
- **Copying out:** the proof copies the prices file with its `-wal` and `-shm` out of a stopped volume and consolidates it as it does the primary (a stopped container can leave a write-ahead log beside either).
- **Upgrading from a release without a prices database** (today's previous release, 0.3.0): the upgraded volume holds `production_prices.sqlite3`, its `schema_migrations` lists exactly the versions of `db/prices_migrate/` (an upgraded prices database missing one fails as the primary does for `db/migrate/`), it passes SQLite's integrity and foreign-key checks, and both large tables are `WITHOUT ROWID`. The proof fails otherwise, naming the file.
- **Upgrading from a release that has one** (from the next release on): the prices database is snapshotted and compared old against upgraded by the same rule as the primary, every old row kept, with only `expected_changes.yml`'s listed differences allowed; an entry there may name a migration of `db/prices_migrate/`.
- **The backup leg:** a version 1 backup restored onto the build gives an instance whose first start creates the prices database (checked as above); a version 2 backup's prices database is compared with the old one as the primary is.
- **The next release's seed** (`script/upgrade/seeds/next.rb`) puts at least one row in each of the five prices tables, through the prices connection, and the coverage rule (every table holds a row, or `seed_exceptions.yml` says why not) covers the prices database's tables too. `seed_exceptions.yml` and `expected_changes.yml` stay keyed by table name, which is unique across the two files.
- **The migration guard** (`ruby script/upgrade/guard.rb`, a `bin/ci` step) covers `db/prices_migrate/` as it covers `db/migrate/`: a released prices migration is never edited, deleted or renamed.
- **`bin/backup-smoke`** checks that the first container's volume holds the five databases (it checks four today), seeds a price row there, and fails unless the restored container holds it and the restore printed its counts.

### 11. The documents

- **ADR 0029** (number given by the coordinator) records decisions 1 to 4 and 6 to 8: a prices database, its tables' rules and the index exception, `WITHOUT ROWID` with an SQL schema file and its evidence, and backup format version 2. It supersedes ADR 0024 decisions 2, 3 and 4 in part (what the backup holds, the file's layout, and a fresh volume of five databases with two placings), and ADR 0024 gets a "superseded in part by 0029" line in its status; `docs/adr/README.md` lists 0029.
- **[`release-and-deploy.md`](../../architecture/release-and-deploy.md)**: the five databases, the fresh volume, a backup of two snapshots in format version 2, the restore's two placements, the upgrade proof's coverage, its Named constants and Sources.
- **A new area doc, `docs/architecture/prices.md`**, for the prices lane: the database, its tables, the rules of decision 4 and the `alter_table` trap; #364 to #370 extend it. `docs/architecture/README.md` lists it.
- **`docs/backup-restore.md`**: version 2's layout and manifest, and manual recovery of both files (`prices.sqlite3` goes to `<volume>/production_prices.sqlite3`).
- **`README.md`**'s backup and restore section and **`CLAUDE.md`**: five databases, what the backup holds, and the test environment's two databases. **`.claude/rules/sqlite-and-migrations.md`**: the primary and prices databases need backing up, and the large tables' index exception. **`.claude/memory/steering/tech-stack.md`**, **`.claude/memory/worktree-shared-test-db.md`** and **`.claude/memory/push-in-background.md`**: the test environment's two files.
- **`docs/releasing.md`**: the next release's upgrade note (the start creates a fifth file, `production_prices.sqlite3`, on the same volume; backups are format version 2 and the release before can't restore them), and its real-backup step restores a version 2 file.
- **ADR 0016** (one file per role, four files) gets a status line, "extended by 0029 (a fifth file, prices)"; ADR 0024 gets "superseded in part by 0029".
- **The specs index** gains spec 081's row with the parts of specs 030 and 031 it supersedes ("Interactions and Supersession"); their rows record it in their "Superseded by" column.
- **Spec 031's frozen contract** (`contracts/yaml-files.md`) says an expected change's migration is a file of `db/migrate/`; the area doc carries the new rule (decision 10) and the contract stays as it shipped.

### 12. The suite's own machinery runs with two test databases

The backup examples run the app's commands in child processes on scratch volumes and commit rows (`spec/support/backup_helpers.rb`, `:committed`). With a second database they must:

- point both databases of a child process at the scratch volume. `DATABASE_URL` reaches the primary only; Rails reads `PRICES_DATABASE_URL` for the prices database. A child process that set only the first would open and migrate the suite's own `storage/test_prices.sqlite3`;
- never write the repository's `db/schema.rb` or `db/prices_structure.sql`, and never load one database's dump into the other. Rails returns `SCHEMA` as every database's schema file, and the test environment dumps after a migration, so each child command gets its own `SCHEMA` path, in its scratch directory, that doesn't exist when the command starts: both databases are then built by their migrations and any dump lands in the scratch directory (AC-6.9);
- empty both databases before and after a `:committed` example, so price rows never leak into later examples;
- point both databases at a restored volume when an example boots the restored instance.

Transactional examples roll back both databases' rows, as Rails' transactional tests open a transaction on every connection pool.

## User Stories

### Story 1: The instance has a prices database

**As an** operator
**I want** the prices to live in a database of their own, created by the app's start
**So that** the daily price writes never touch the database that holds my collectors' data

**Acceptance criteria:**

- [ ] **AC-1.1** Given the production, development and test configurations When they are read Then each names a `prices` database whose file is `storage/<environment>_prices.sqlite3` and whose migrations are in `db/prices_migrate/`, and production names exactly five databases: primary, queue, cache, cable and prices.
- [ ] **AC-1.2** Given a volume with no databases When the databases are prepared (in the suite, a child process's `db:prepare` on a scratch volume; in production, the container's start, shown by `bin/backup-smoke` and `bin/upgrade-smoke`) Then `production_prices.sqlite3` exists, its `schema_migrations` lists exactly the versions of `db/prices_migrate/`, and it holds the five tables of decision 2.
- [ ] **AC-1.3** Given a volume with the four databases of the previous release and no prices file When the databases are prepared (in the suite, a child process on a scratch volume holding only a primary; in production, `bin/upgrade-smoke`'s upgrade of 0.3.0) Then the prices file is created as in AC-1.2 and the primary database's rows are unchanged.
- [ ] **AC-1.4** Given the prices database When its tables are read Then each has the columns, keys, foreign keys and checks of decision 2, and a row that breaks one (a negative `cents`, a blank source `key`, a second series with the same finish, currency and kind, a currency that isn't three upper-case letters, a current price naming a missing series) is refused by the database.
- [ ] **AC-1.5** Given the test environment When it is read Then the prices connection's database is `storage/test_prices.sqlite3` and the primary test database has no `current_prices` table; and Given a transactional example that writes a price row When it ends Then the row is gone; and Given a `:committed` example that commits price rows When it ends Then the prices database is empty again (decision 12).

### Story 2: The two large tables store their key once

**As a** maintainer
**I want** `current_prices` and `price_changes` to be `WITHOUT ROWID` on every instance
**So that** the history costs half the disk, and no instance differs from another by how it was created

**Acceptance criteria:**

- [ ] **AC-2.1** Given the test prices database, loaded from `db/prices_structure.sql` When `sqlite_master` is read Then the definitions of `current_prices` and `price_changes` end in `WITHOUT ROWID`, and those of the other three tables don't.
- [ ] **AC-2.2** Given an empty database built only by running the migrations of `db/prices_migrate/` When `sqlite_master` is read Then the same holds as in AC-2.1, and its tables, columns and indexes are those of the structure-loaded database.
- [ ] **AC-2.3** Given a table definition without `WITHOUT ROWID` for either large table (a negative control) When the guard of AC-2.1 and AC-2.2 reads it Then the guard fails, naming the table and saying that a column change on SQLite rebuilds the table without the option and that a new migration must recreate it.
- [ ] **AC-2.4** Given the configuration When it is read Then the prices database alone has `schema_format: sql`, and the other four keep their Ruby schema files.

### Story 3: Prices are global and stay in their own file

**As a** maintainer
**I want** prices kept apart from collectors' data
**So that** no collector's export, no tenant rule and no query crosses into them by accident

**Acceptance criteria:**

- [ ] **AC-3.1** Given the prices database When its tables' columns are read Then none is `account_id` or `user_id`.
- [ ] **AC-3.2** Given a collector with lots When they download their export Then it holds no price, and the export format's version is unchanged (4).
- [ ] **AC-3.3** Given the prices database When its foreign keys are read Then every one points at a table of the prices database, and `catalog_entry_id` has none.
- [ ] **AC-3.4** Given the prices connection When a query on it names a primary table (`catalog_entries`) Then it fails with no such table (the two files are not attached to each other).
- [ ] **AC-3.5** Given the migrations, the structure file and the connection class of the prices database When they are read, comments included Then none names a collectible or a source (`MTG`, `Scryfall`, `Magic`).

### Story 4: A backup holds the prices

**As an** operator
**I want** `backup:create` to hold the prices database beside the primary
**So that** the price history, which can't be downloaded again, survives a lost disk

**Acceptance criteria:**

- [ ] **AC-4.1** Given a running instance with price rows When the operator runs `backup:create` Then the file is a gzip'd ustar of exactly `manifest.json`, `primary.sqlite3` and `prices.sqlite3`, in that order, each mode 0600, and `prices.sqlite3` holds the price rows.
- [ ] **AC-4.2** Given that backup When its manifest is read Then `backup_format_version` is 2, the version 1 members describe `primary.sqlite3`, and `prices` holds the prices snapshot's newest schema version, size, SHA-256 and the counts of current prices and price changes, which match the file.
- [ ] **AC-4.3** Given that backup When `prices.sqlite3` is opened Then it is in rollback-journal mode and passes SQLite's integrity check and foreign-key check.
- [ ] **AC-4.4** Given an instance with no prices database When the operator runs `backup:create` Then it exits 1 with a two-sentence refusal that names the missing file and says to start Collector once on this release, and no file is left in the directory.
- [ ] **AC-4.5** Given a prices database that fails its integrity check, or whose `price_changes` holds three rows naming a missing series When the operator runs `backup:create` Then it exits 1 with spec 030's refusal for that failure, naming the prices database, the foreign-key refusal counting 3 rows, and no file is left in the directory.
- [ ] **AC-4.6** Given a directory with less free space than twice the two databases' sizes together When the operator runs `backup:create` Then it refuses, naming both figures, before writing anything.
- [ ] **AC-4.7** Given a running instance When `backup:create` succeeds Then its report names the file, its size, the primary's and the prices database's schema versions, the primary's counts and the prices counts, in the form of decision 7.
- [ ] **AC-4.8** Given a writer committing to the prices database during `backup:create` When the backup runs Then the writer's commits keep going, each waiting under the database's 5-second busy timeout, as spec 030 AC-1.3 holds for the primary.

### Story 5: A restore brings the prices back, or nothing

**As an** operator
**I want** `backup:restore` to put both databases back on a fresh volume, or neither
**So that** a restored instance has its prices, and a failed restore never leaves half an instance

**Acceptance criteria:**

- [ ] **AC-5.1** Given a version 2 backup with price rows and a fresh volume When the operator runs `backup:restore` Then the volume holds `production.sqlite3` and `production_prices.sqlite3`, the prices database holds exactly the backed-up price rows, both are in rollback-journal mode with no `-wal` or `-shm`, and the report gives both sets of counts.
- [ ] **AC-5.2** Given a version 1 backup (from a release before this one) and a fresh volume When the operator runs `backup:restore` Then only the primary is placed, the report says the backup holds no prices and that the first start creates an empty prices database, and the instance's first start creates it as in AC-1.2.
- [ ] **AC-5.3** Given a volume that holds only a prices file, or one of its `-wal`, `-shm` or `-journal` files When the operator runs `backup:restore` Then it refuses the volume as not empty, naming the file, and changes nothing.
- [ ] **AC-5.4** Given a version 2 backup whose prices snapshot fails its integrity or foreign-key check, lists a prices migration the release lacks, or whose counts disagree with the manifest When the operator runs `backup:restore` Then it refuses with spec 030's message for that case (damaged, or taken by a newer release naming the prices schema versions), and the volume holds no database file and no temporary file.
- [ ] **AC-5.5** Given a version 2 backup whose `prices.sqlite3` entry is missing, cut short or changed after it was made When the operator runs `backup:restore` Then it is refused as not a backup, incomplete or changed (spec 030 AC-3.1 to AC-3.3), before anything is written.
- [ ] **AC-5.6** Given a restore that fails after the prices snapshot was placed and before the primary is (the primary's name taken, or the disk full) When it stops Then the prices file it placed is removed, and the volume holds neither database.
- [ ] **AC-5.7** Given a version 2 backup When a restore that knows only format version 1 reads it (shown in the suite with the restore's known versions set to `[1]`) Then it refuses it as an unknown version, naming 2 and 1 (spec 030 AC-3.4).
- [ ] **AC-5.8** Given any restore When it runs Then it opens neither configured database path, and never through Active Record (spec 030 FR-8; ADR 0024 decision 4).
- [ ] **AC-5.9** Given a restore killed after the prices file was placed and before the primary was When the operator runs the restore again Then it refuses the volume as not fresh, naming `production_prices.sqlite3`, and its advice says the file may be a stopped restore's, to remove it and its sidecars before restoring again, and never to start Collector on the volume as it is; and Given the operator removes them When the restore runs again Then it succeeds as in AC-5.1.

### Story 6: The proofs cover the new file

**As a** maintainer
**I want** the suite, the container smoke and the upgrade proof to cover the prices database
**So that** a release that loses prices, or fails to create them, can't ship

**Acceptance criteria:**

- [ ] **AC-6.1** Given `spec/backup_guards_spec.rb` When it reads the production configuration and the backup's own list of the databases it holds (the constant the backup's code archives from) Then it passes with exactly five databases, the backup holding the primary and prices and leaving out queue, cache and cable, each with its reason in the guard; and a sixth database, or a backup constant that differs from the guard's list of held databases, fails it, saying to decide what the backup does with it and update this spec's decision 6, `docs/backup-restore.md` and the README.
- [ ] **AC-6.2** Given an instance with lots and price rows When the suite runs `backup:create` and then `backup:restore` onto a fresh directory Then the restored primary and prices databases hold the same rows as the originals (sessions and their cascades aside), with every price row's columns equal.
- [ ] **AC-6.3** Given `bin/backup-smoke` When it runs against an image of this release Then it seeds a price row before the backup, and fails unless the restored container holds that row and the restore printed the prices counts.
- [ ] **AC-6.4** Given the upgrade proof and a previous release with no prices database When it upgrades and when it restores that release's backup Then it fails unless each resulting volume's prices database is as in AC-1.2 and passes SQLite's integrity and foreign-key checks, and its report names the prices database's checks.
- [ ] **AC-6.5** Given the upgrade proof and a previous release with a prices database holding rows (shown with a fake engine in the suite) When it upgrades, and when it restores that release's backup Then it compares the old and the new prices databases by the primary's rule and fails on a lost row or an unlisted difference, naming the table.
- [ ] **AC-6.6** Given `script/upgrade/seeds/next.rb` When the proof runs it on the build Then every table of the prices database holds a row, or `seed_exceptions.yml` lists it with a reason, or the proof fails naming the table.
- [ ] **AC-6.7** Given a released migration under `db/prices_migrate/` that the branch edits, deletes or renames When `ruby script/upgrade/guard.rb` runs Then it fails naming the file, as for `db/migrate/`.
- [ ] **AC-6.8** Given an `expected_changes.yml` entry naming a migration in `db/prices_migrate/` When the rules load Then it is accepted, and one naming no migration file in either directory is still an error.
- [ ] **AC-6.9** Given the suite's backup examples, which run the app's commands in child processes When they have run Then the repository's `db/schema.rb` and `db/prices_structure.sql` are byte for byte what they were before, and each child command's databases were built without loading a dump written by another command (decision 12).

### Story 7: The documents say what the backup holds

**As an** operator
**I want** the documents to say the backup holds the prices and how to get them out by hand
**So that** I can trust the backup and recover without Collector

**Acceptance criteria:**

- [ ] **AC-7.1** Given `docs/backup-restore.md` When it is read Then it gives version 2's three files and manifest, version 1 as what earlier releases wrote, what a restore checks for both databases, and manual recovery of both files with `tar` and `sqlite3`.
- [ ] **AC-7.2** Given every document decision 11 names When it is read Then it states what decision 11 gives it, and none but a frozen spec, a frozen contract or an ADR's body still says that a backup holds the primary database only, that the instance has four databases or that the test environment has one.
- [ ] **AC-7.3** Given the first migration under `db/prices_migrate/` and `docs/architecture/prices.md` When they are read Then each says that a column change on SQLite rebuilds a table without `WITHOUT ROWID`, so a change to either large table is a new migration that recreates it with the option, and that the guard of AC-2.3 checks it.

(Story 7's criteria are verified by reading, recorded in `verification.md`; the suite doesn't check prose documents, `.claude/rules/testing.md`.)

## Functional Requirements

### FR-1: The prices database

**Must:** be configured in every environment as decision 1 says; be created and migrated by `db:prepare` on a new and on an upgraded volume; hold exactly the five tables of decision 2 after this spec's migrations; keep its schema in `db/prices_structure.sql`; make `current_prices` and `price_changes` `WITHOUT ROWID` on every path that creates them (decision 3); give later code one abstract connection class to inherit (decision 5).
**Must not:** add a table to the primary database; add a model per table, a reader, a writer, a job, a route or a page; add rows to any table (the seed and the suite's examples aside); change `Dockerfile`, `config/deploy*.yml`, `compose.yaml` or `.github/workflows/**`.

### FR-2: Prices are global

**Must:** have no `account_id` or `user_id` in any prices table; name a printing by `catalog_entry_id`; keep foreign keys inside the prices file.
**Must not:** put prices in the export format, the preview or the apply; join or attach the two files; name a collectible in the prices schema's files (decision 9).

### FR-3: The backup holds both databases

**Must:** write format version 2 as decision 6 says; take, verify and archive both snapshots as decision 7 says; refuse a missing prices database; keep every spec 030 rule for the primary (online, verified before it counts, 0600, `.partial` until linked, never replacing a file, no `:environment`, no collectible named).
**Must not:** hold the queue, cache or cable databases; change what version 1 means.

### FR-4: The restore brings both back, or neither

**Must:** restore versions 1 and 2 as decisions 6 and 8 say; treat a volume with any of the five databases' files as not fresh; check the prices snapshot as the primary is, against `db/prices_migrate/`; place the prices file before the primary and remove it if the primary can't be placed; say, when a volume holds a prices file and no primary, that it may be a stopped restore's.
**Must not:** open a connection to either configured path; run a migration; clear anything in the prices database.

### FR-5: The proofs

**Must:** extend `spec/backup_guards_spec.rb`, the suite's backup examples, `bin/backup-smoke`, the upgrade proof (`script/upgrade/`, `bin/upgrade-smoke`) and the migration guard as decision 10 says.
**Must not:** run a database task from the upgrade proof (spec 031's refusal list stays); weaken any check of the primary.

## Non-Functional Requirements

### Performance

- An empty prices database adds less than a second to `backup:create`, `backup:restore` and a container's start, measured in `verification.md` against spec 030's bars (decision 13: each under 5 minutes for the English catalog and 50,000 lots).
- The size and time of a backup with a year of history is #366's to measure and #370's to document; this spec makes no claim about it.

### Security

- The backup file's rules are unchanged: 0600 from creation, no secret, counts only in the manifest (spec 030 decision 3, AC-1.7, AC-1.8). The prices database holds no collector data, so it adds no new kind of private data to the file.
- No route, controller or view is named for a backup (spec 030 AC-6.2, unchanged).

### Reliability

- A restore that stops, by a refusal or an error, leaves neither database on the volume; a killed one may leave the prices file alone, never a primary without its prices, and the next run says what to do (decision 8).
- Every migration of `db/prices_migrate/` is safe to run unattended from any prior release (`.claude/rules/sqlite-and-migrations.md`); the first creates tables only.
- A missing `sqlite3` command at boot still yields the right database, through the migrations (decision 3).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| `backup:create` on an instance with no prices file | Refusal: the file is missing; start Collector once on this release, then run it again. Exit 1, nothing left (AC-4.4) |
| The prices database fails its integrity or foreign-key check during `backup:create` | Spec 030's damage refusal, naming the prices database; nothing left (AC-4.5) |
| The prices database stays busy past the timeout during `backup:create` | Spec 030's busy refusal (AC-4.8's writers are not blocked beyond 5 s) |
| The disk fills while either snapshot or the archive is written | Spec 030's disk-full refusal; the run's `.partial` files are removed |
| A version 2 backup's prices entry is missing, cut short or changed | Not a backup, incomplete, or changed (AC-5.5) |
| A version 2 backup's prices snapshot is damaged, newer than the release, or its counts differ | Damaged or newer-release refusal naming the prices schema; volume untouched (AC-5.4) |
| The volume holds only a prices file or one of its sidecars | Not fresh, naming it (AC-5.3) |
| The primary can't be placed after the prices file was | The placed prices file is removed; the refusal says nothing was changed (AC-5.6) |
| The restore is killed between the two placings | The prices file stays alone; the next run refuses the volume and says to remove the file (AC-5.9) |
| A version 2 backup restored by a release that knows only version 1 | Unknown version 2; this release restores version 1 (AC-5.7) |
| The image's start can't find the `sqlite3` command | Two `command not found` lines in the boot log; the migrations build the same database (decision 3) |
| A later migration changes a column of `current_prices` or `price_changes` | The suite fails on AC-2.3's guard, naming the table and the fix |

## Interactions and Supersession

- **Supersedes spec 030 in part:** FR-1 and decision 2 (a backup holds the prices database too), decision 5 (format version 2 beside version 1), decision 6 ("a fresh volume holds none of the four databases": five), decision 13 and AC-1.11 with its error row (the free space is twice both databases' sizes), AC-1.4 (the archive's two files and the manifest's members: AC-4.1 and AC-4.2 here), and AC-5.5's "exactly the four production databases" (five, with the lists of decision 6 here). Recorded in the specs index, both rows.
- **Supersedes spec 031 in part:** the old database's versions and seed coverage, the copy, the comparison, the upgraded database's versions and the backup leg judged the primary only (AC-2.1, AC-2.4, AC-2.5, AC-3.2, AC-6.2); they cover the prices database too. An expected change may name a migration of `db/prices_migrate/` (AC-4.5), and the migration guard reads it (AC-8.1) (decision 10). Recorded in the specs index, both rows.
- **Supersedes ADR 0024 decisions 2, 3 and 4 in part,** through ADR 0029.
- **Builds the place for #364 to #370**, which add models, rows, columns and pages through their own specs.

## Open Questions

None. The `WITHOUT ROWID` question the issue left open was ruled on 2026-11-13 (decision 3).

## Out of Scope (Future Considerations)

- A price per condition or language, thinning old history (design decisions 8, "Non-goals in 1.0").
- Moving the prices tables into a hosted service's main database if it leaves SQLite (design, open question 5).
- A backup of the prices database on its own schedule, or an operator choice to leave prices out of a backup to save space; if #370's measurements show the history makes backups too large, a later spec decides.
- Prices following a printing that the source merges into another (#371, 2.0).
