# Verification: A Prices Database That the Backup Holds (spec 081, #363)

**Branch:** `081-prices-database-in-backup` · **Spec:** 1.2.2 (Approved) · **Plan:** approved 2026-11-13 (Gate B) · **ADR:** 0029 (Proposed; the maintainer accepts it with the PR)

## How it was built

- Spec, ADR and plan in the main session (Opus 5.5). Two read-only spec reviews (Fable 5.2: READY WITH FIXES twice, all applied) and two read-only plan reviews (Opus 5.5: REVISE, then APPROVE WITH CHANGES, all applied).
- The maintainer ruled decision 3 (`WITHOUT ROWID`, option A), the index exception of decision 2 (accepted) and decision 8's follow-up (#375), all on 2026-11-13.
- Implementation by Sonnet 5.5 implementers in four batches (A: T1.1–T1.4, B: T2.1, T3.1, T3.2, C: T3.3–T3.5, D: T4.1–T4.4) and one batch of review fixes, one commit per task, test first. Every implementer commit's trailer names Sonnet 5.5; the supervisor's documents and fixes name Opus 5.5. One implementer change left unstaged was committed by the supervisor as written, with the Sonnet trailer (`5b9786e7`, a comment's tags).

## The first failing test

T1.1 (`84c32f12`): with `prices` added to `config/database.yml` and the guard unchanged, `spec/backup_guards_spec.rb` failed: "knows exactly the four production databases (AC-5.5)", `expect(names).to match_array(%w[primary queue cache cable])`, with the guard's advice; 8 examples, 1 failure. The backup's contents were then decided (`Collector::Backup::HELD`, the guard's lists).

## Decision 3's evidence (`WITHOUT ROWID`)

- **Rails 8.1.4.1, read and run on 2026-11-13** (a scratch probe of `ActiveRecord::Tasks::DatabaseTasks.prepare_all` with `schema_format: sql`):
  - `create_table` with a composite `primary_key` and `options: "WITHOUT ROWID"` writes the right SQL.
  - The SQLite adapter has no `table_options`, so a Ruby dump drops the option.
  - With `sqlite3` on the PATH, a new database loaded from the SQL dump has `WITHOUT ROWID`.
  - Without it, the load fails quietly (`sh: sqlite3: command not found` twice), `prepare_all` returns normally and runs every migration, and the table is still `WITHOUT ROWID` with every version recorded.
- **Where the `sqlite3` command is:**
  - `Dockerfile`'s `base` stage installs it.
  - actions/runner-images' Readme lists sqlite3 3.45.1 for `ubuntu-latest` (Ubuntu 24.04) and `ubuntu-24.04-arm`, and 3.46.1 for Ubuntu 26.04.
  - macOS has `/usr/bin/sqlite3`.
- **The guard, red first (T1.3, `5e04cde4`).** With the option removed from `current_prices` in the migration and the structure file and the test database rebuilt, `spec/prices_schema_spec.rb` failed on both build paths, naming `current_prices` and the fix: 3 examples, 2 failures. With the option put back: 3 examples, 0 failures.
- **Execution finding: the structure file carries query-log comments.** It has `/*application='Collector'*/` after some statements, because development has `query_log_tags_enabled` and SQLite stores the comment with the definition. Production stores none. The guard strips comments before it compares (`docs/architecture/prices.md`, Decisions).

## Acceptance criteria

| AC | Proof |
|---|---|
| 1.1 | `spec/config/prices_database_spec.rb`; `spec/backup_guards_spec.rb` (five production databases); `spec/lib/collector/backup/databases_spec.rb` |
| 1.2 | `spec/backup_prices_spec.rb` (a child `db:prepare` on an empty scratch volume: versions, five tables, schema files untouched); in production, the container runs below |
| 1.3 | `spec/backup_prices_spec.rb` (a primary with no prices file: the prices file is created with its migrations and tables, the primary's rows kept); in production, `bin/upgrade-smoke` from 0.3.0 |
| 1.4 | `spec/models/prices_record_spec.rb` (each table's columns and primary key against decision 2; bad rows: negative cents, blank and all-space key, name and attribution, duplicate series, lower-case currency, missing series, negative change, unknown status, duplicate current-price key; two runs on one date allowed) |
| 1.5 | `spec/models/prices_record_spec.rb` (the prices connection is `storage/test_prices.sqlite3`; the primary has no `current_prices`; an example's row is in an open transaction and not in the file read from outside); `spec/backup_prices_spec.rb` (`clear_instance!`, which the `:committed` hook calls, empties the prices database: the example calls the helper itself, the hook is that helper) |
| 2.1, 2.2, 2.3 | `spec/prices_schema_spec.rb` (structure-loaded; migrated in a bare child process and equal to the loaded one; negative control) and T1.3's red run |
| 2.4 | `spec/config/prices_database_spec.rb` |
| 3.1, 3.3, 3.4 | `spec/models/prices_record_spec.rb` |
| 3.2 | `spec/requests/collection_exports_spec.rb` (a price row present; format_version 4; no price key at any depth) |
| 3.5 | `spec/prices_core_spec.rb` (and `spec/backup_guards_spec.rb` for the backup's files) |
| 4.1, 4.2, 4.3, 4.7 | `spec/lib/collector/backup/create_spec.rb` (three entries, mode 0600, version 2 manifest agreeing with `prices.sqlite3`, rollback-journal and verified, the report), `manifest_spec.rb`, `archive_spec.rb` |
| 4.4, 4.5, 4.6 | `create_spec.rb` (missing prices database; damaged prices source; three orphan changes counted 3; free space for both); `snapshot_spec.rb` (the `WITHOUT ROWID` orphan count) |
| 4.8 | `create_spec.rb` (a prices writer between `:prices_starting` and `:prices_written`: its commits continue, each under 5 s) |
| 5.1 | `spec/lib/collector/backup/restore_spec.rb` (both files, no sidecars, rows equal, rollback-journal, both counts in the report) |
| 5.2 | `restore_spec.rb` (version 1 places the primary only, with the report's sentence); `spec/backup_upgrade_spec.rb` (the first start creates the prices file with its migrations and tables); `bin/upgrade-smoke`'s backup leg from 0.3.0 |
| 5.3 | `restore_spec.rb` (a prices file alone, or only its `-wal`) |
| 5.4 | `restore_spec.rb` (damaged prices snapshot, orphan, newer prices schema, counts that differ) |
| 5.5 | `archive_spec.rb` (prices entry missing, cut short, changed) |
| 5.6 | `restore_spec.rb` (the primary's name taken after the prices file was placed: the placed prices file is removed, the refusal lists only what was there) |
| 5.7 | `restore_spec.rb` (`FORMAT_VERSIONS` stubbed to `[1]`) |
| 5.8 | No restore spec opens the configured paths: AC-5.1's listing shows no sidecar beside the placed files, and `lib/collector/backup/` has no Active Record. The review deleted an example that couldn't fail |
| 5.9 | `restore_spec.rb` (a real SIGKILL at `:prices_placed`; the next restore refuses with the advice below; after removal it succeeds) |
| 6.1 | `spec/backup_guards_spec.rb` (five databases; `HELD` against the guard's lists) |
| 6.2 | `spec/backup_prices_spec.rb` (round trip with sources, series, current prices and changes, one with null cents) |
| 6.3 | `bin/backup-smoke` run below |
| 6.4 | `spec/script/upgrade/harness_spec.rb` (missing prices file, missing version, missing `WITHOUT ROWID`, an orphan row); `bin/upgrade-smoke` from 0.3.0 below |
| 6.5 | `harness_spec.rb` (old and new prices differ, upgrade and backup leg; split expected changes and seed exceptions); `bin/upgrade-smoke --previous-ref HEAD` below |
| 6.6 | `spec/script/upgrade/seeds_spec.rb`; `harness_spec.rb` |
| 6.7 | `spec/script/upgrade/guard_spec.rb` |
| 6.8 | `spec/script/upgrade/expected_changes_spec.rb` |
| 6.9 | `spec/backup_prices_spec.rb` (schema files unchanged; each child's `SCHEMA` absent when it starts); `spec/backup_upgrade_spec.rb` (both schema digests) |
| 7.1 to 7.3 | By reading, below |

**Readings recorded:**
- **Restore report form.** Decision 8 gives the restore report's counts as "…it holds … and 0 current prices and 0 price changes." The code joins them as "it holds 1 account, 1 user and 3 lots; 0 current prices and 0 price changes.", which is decision 7's form for the create report. This is the reading taken, and `bin/backup-smoke` greps for it.
- **Not-fresh advice.** The advice for a volume holding prices files and no primary reads: "It may be the prices database of a restore that stopped: remove production_prices.sqlite3 and its -wal, -shm and -journal files, then restore again. Never start Collector on this volume as it is." The documents cite #375; the operator's text doesn't.

## The container runs (T5.3)

Run on 2026-11-13 under the coordinator's slot, with docker 29.5.2 through colima on the macOS arm64 machine, at `465d8cb1`. These runs used the branch before the implementation review's fixes. Those fixes changed tests and comments, the not-fresh advice text, the restore's room wording, and the migration's three "present" checks to `length(trim(…))`. CI's image job runs both scripts again on the pushed head.

- **Images.** This build: `docker build -t collector:smoke081 .`, image `sha256:e04c6534f58117977aa62bb3d1ac032407bf3b21888e944c6c53f7390352b185`. `docker pull ghcr.io/plainprogrammer/collector:0.3.0` failed with "error from registry: denied", the saved ghcr.io login that `.claude/memory/container-engine-colima-macos.md` records; the maintainer's login was left alone. So v0.3.0 was built from its tag: `git archive v0.3.0 | tar -x -C tmp/smoke081/v030`, then `docker build -t collector:v030local .`, image `sha256:6be5bcd247b381bba8f47c1beb523e9fd8a0bea32b9a9b4b07df2c93b892f720`.
- **`bin/backup-smoke collector:smoke081`** (a `mktemp` shim under the worktree's `tmp/`): exit 0, "OK: collector:smoke081 was backed up and restored into collector:smoke081 the documented ways". The restore printed `it holds 1 account, 1 user and 1 lot; 1 current price and 0 price changes.`, and both restored containers held the five databases and the price row (AC-6.3, AC-1.2).
- **`TMPDIR=… bin/upgrade-smoke collector:v030local collector:smoke081 --previous-version 0.3.0`:** exit 0, "OK: v0.3.0 … upgraded to 465d8cb167c6; 28 tables compared, behaviour verified, 51 s" (AC-1.3, AC-6.4, AC-5.2, AC-6.6).
  - After the upgrade and in the backup leg (0.3.0's version 1 backup restored, the prices file made by the first start) it printed `prices: 5 tables, schema 20261113100001, WITHOUT ROWID on current_prices and price_changes`.
  - The next seed filled the prices tables.
  - This stands in for `auto` only for the pull.
- **`TMPDIR=… bin/upgrade-smoke collector:smoke081 collector:smoke081 --previous-ref HEAD`:** exit 0, 46 s (AC-6.5 in containers, which CI can't run until a release has prices).
  - The build is its own previous release, so the old volume has a prices database, and the backup leg restores a version 2 backup.
  - Both the upgrade's and the backup leg's prices comparisons read: `current_prices` old 3 new 3 same, `price_changes` 4/4 same, `price_refresh_runs`, `price_series` and `price_sources` 1/1 same.
- **Timing (NFR Performance).** The two upgrade-proof runs took 46 and 51 s in all, each booting six instances and taking and restoring one backup. No run before this feature was timed on this machine for comparison, so the NFR's "under a second more" is not measured directly. With the prices database holding only the seed's few rows, the second snapshot copies a file of a few pages. The size of a backup with a year of history is #366's to measure and #370's to document.

## Story 7, by reading

- **AC-7.1** `docs/backup-restore.md`:
  - version 2's three files and the manifest's `prices` member;
  - version 1 and how it restores;
  - what a restore checks for both databases, and the killed case;
  - manual recovery of both files with `tar` and `sqlite3`.
- **AC-7.2:**
  - ADR 0029 (Proposed), and the status lines of ADR 0024 ("superseded in part by 0029") and ADR 0016 ("extended by 0029");
  - `docs/adr/README.md`;
  - `release-and-deploy.md` (terms, invariants, the backup and restore runs, the upgrade proof, named constants, sources);
  - the new `docs/architecture/prices.md`, indexed in `docs/architecture/README.md`;
  - `data-portability.md` (a backup holds both databases; an export holds no price);
  - README ("Data", "Backup and restore");
  - `docs/releasing.md` (the upgrade note, and the real-backup step restoring a version 2 file);
  - CLAUDE.md;
  - `.claude/rules/sqlite-and-migrations.md`;
  - `.claude/memory/steering/tech-stack.md`, `worktree-shared-test-db.md` and `push-in-background.md`;
  - the specs index (rows of 030, 031 and 081);
  - the roadmap (#375 added to the prices lane).

  `git grep -n -i -E "four (production )?databases|primary database only|holds the primary only|primary DB only|all four production"` finds only frozen specs, the design document of 2026-11-13, this spec and plan, and lines describing version 1.
- **AC-7.3:** the first prices migration's header and `prices.md`'s "Decisions not in an ADR" both say that a column change on SQLite rebuilds the table without `WITHOUT ROWID`, that a change to either large table is a new migration recreating it, and that `spec/prices_schema_spec.rb` checks it.

## Deviations from the plan

- **T1.3:** the guard strips query-log comments (see decision 3's evidence above). The constants are methods.
- **T3.4/T3.5:** AC-5.9's killed-restore examples are in T3.4's commit, which shares the kill helper. AC-4.8 has its own prices-writer example.
- **T3.3:** `Create` names "The prices database" in its refusals through a `@stage`. Restore's damaged-prices and mismatched-count refusals reuse spec 030's messages; only the newer-release refusal names the prices schema versions.
- **T4.2:** the comparison failure reads "the prices database of the <label> volume differs …". The harness spec's checkout gets `db/prices_structure.sql`, which `prices_tables` reads.
- **T4.4:** no red is possible for `bin/backup-smoke`'s text in the suite. It was checked with `bash -n` and `ruby -c`, then by the container run.
- **After the review:** the migration's three "present" checks trim, so a name of spaces is refused. The migration isn't released, so editing it is allowed by `.claude/rules/sqlite-and-migrations.md`.
- **T5.3:** a local build of v0.3.0 stood in for the denied pull, and a `--previous-ref HEAD` run was added for AC-6.5.

## Implementation review

SPEC-ALIGNED (Mode B, read-only, Opus 5.5, 2026-11-13; one round). Every AC from 1.1 to 6.9, every FR and decisions 1 to 12 are implemented and proven; Story 7 holds by reading. It found no blocking or major issue and 14 minor ones.

- **Fixed by the implementer (`851d9820`, `ee0f39aa`, `721ca3e7`, `8b63fe67`, `fe9b54e6`, `d03e4add`, `5b9786e7`):**
  - AC-1.4's columns, keys and blank-name rows, with `length(trim(…))` checks;
  - the restore's room counting both snapshots;
  - the vacuous AC-5.8 example deleted;
  - the not-fresh advice naming the prices file and dropping the issue number;
  - plural comments and wording;
  - `@param`/`@return`/`@raise` on `Archive.read`, `Manifest.parse` and `release_schema_versions`;
  - a harness scenario with an orphan prices row;
  - created prices files checked for migrations and tables;
  - AC-4.8's 5-second bound.
- **Fixed by the supervisor (`7f68dbb9`):** stale line references in `release-and-deploy.md`, and what `bin/backup-smoke` checks.
- **Recorded rather than changed:**
  - the restore report's form (above);
  - the `:committed` cleanup proven through its helper (AC-1.5 above);
  - ADR 0029 stays Proposed until the maintainer accepts it with the pull request.
- **After the fixes:**
  - the targeted run `bin/rspec spec/models/prices_record_spec.rb spec/prices_schema_spec.rb spec/prices_core_spec.rb spec/backup_*_spec.rb spec/lib/collector/backup spec/script/upgrade spec/tasks` gave 327 examples, 0 failures;
  - `bin/ci checks` passed every step at `7f68dbb9`.
  - The full suite runs at the push.
