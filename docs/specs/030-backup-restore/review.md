# Spec review (Mode A): 030 Back Up and Restore an Instance

**Reviewed:** spec version 1.0.0 (commit `62dc982`), 2026-10-21, by a read-only Opus subagent, as the project default. It checked the spec's factual claims against the code.
**Verdict on 1.0.0:** NEEDS REVISION (4 critical, 9 important, minors).
**State of 1.1.0:** every critical and important finding and every minor is addressed in the spec below. The revised spec has **not** been reviewed a second time; the plan's first review should read it with this list.

## Critical

| # | Finding | Fix in 1.1.0 |
|---|---|---|
| 1 | Clearing `sessions` cascades (`on_delete: :cascade`) to `bulk_removals`, `bulk_selections` and, through them, `bulk_selection_marks`; FR-3 and AC-2.1 said otherwise | Decision 3 names the cascade and the loss of pending Undos and selections; clearing runs with foreign keys on; AC-2.1 compares every table but those four and asserts they are empty and that the foreign-key check is clean; FR-3 rewritten; foreign-key check added to the backup's verification (decision 7, AC-1.2, AC-1.5, AC-3.7) |
| 2 | "Fresh" meant only "no primary database"; a stale `-wal` or an old queue database would corrupt or poison a restore | Terms, decision 6, AC-2.5 (three cases) and FR-2 define a fresh volume as none of the four databases and no `-wal`, `-shm` or `-journal`; the snapshot is closed in rollback-journal mode before the rename |
| 3 | A restore that opens a connection to the primary's path creates the empty database it is meant to prevent (and opens registration to the first visitor) | New FR-8 (never connect to that path; take migrations from files); AC-2.6 asserts no `production.sqlite3*` after every refusal, including a bad path |
| 4 | The NAS check needed an image with the feature and a "newer image"; neither exists before the spec ships | Decision 9 layer 3, decision 14, AC-5.6 (the branch's image, same image) and new AC-5.7 (the newer-image leg as a `docs/releasing.md` step for later releases) |

## Important

| # | Finding | Fix in 1.1.0 |
|---|---|---|
| 5 | "Writes nothing before its checks pass" was impossible (checks need the snapshot on disk) | FR-2 rewritten: fresh-volume, archive and space checks first, then one fixed-name temporary file on the volume |
| 6 | uid 1000 vs a 0600 file on bind mounts and `cp` | Decision 4 and Self-hosting NFR state the ownership rule; AC-5.1 and the smoke script cover it |
| 7 | The Kamal flow was underspecified (named volume, `kamal setup` boots the app) | Decision 4 gives the sequence (`volumes:` addition, `backup` alias, `scp`, `kamal app exec` without `--reuse` before first boot), to be verified by the plan; recorded as documented and not exercised through Kamal |
| 8 | The suite can't run everything as written (transactional fixtures, the always-present test database, container-only checks) | AC-5.4 and decision 9 layer 1: no transactional fixtures, the restore's target an argument of the class beneath the task, `db:prepare` against a scratch directory; AC-2.3 and AC-4.2 moved to the smoke script |
| 9 | The smoke script couldn't create lots without a catalog, and the CSRF sign-in and Compose-vs-engine were unstated | AC-5.2 and decision 9 layer 2: seeded with `bin/rails runner`, runs the tasks through the engine as `bin/image-smoke` does, signs in with the CSRF token |
| 10 | Missing AC for destination and free-space errors; wrong citation; free space contradicted decision 13 | New AC-1.11 (twice the database's size), AC-1.10 in Given/When/Then with the restore bar, error table cites AC-1.11 |
| 11 | A "successful" restore of nothing, or into the wrong Compose volume, goes unnoticed | The manifest and both commands print counts of accounts, users and lots (counts only, rule 2 holds), the restore prints the volume path, AC-2.1, AC-2.11, error rows, README checklist |
| 12 | AC-2.8's "no HTTP request" held only if every artwork was fingerprinted; ImageMagick and a last applied refresh are needed | AC-2.8 states the preconditions; decision 2 drops "in seconds" |
| 13 | AC-4.1 searched for setting values that appear in catalog rows | AC-4.1 searches secrets and a unique free-form value (a `COLLECTOR_TRUSTED_PROXIES` address) |
| 14 | AC-2.7's "with none" was ambiguous | Dropped; "same rows in every table" |
| 15 | "Back Up and Restore" and the north star's "title that needs and is split" | Decision 15 (recommended, one outcome); awaiting the maintainer |

## Minor

All addressed: "one Collector command"; AC-2.4's wording; AC-2.10's expiry; mtime and unique `.partial` names (AC-1.6, AC-1.9, decision 7); AC-6.2 scoped to `backup` names; When clauses added throughout; "plain message" defined once (AC-3.8) and referenced; the manifest's fields listed (AC-1.4); the schedule is a suggestion (AC-5.1); FR-6 split; new FR-9 (smoke script and CI step) and FR-10 (no secret written); `integrity_check` time noted in decision 13; rake argument quoting and `podman cp` in AC-5.1 and decision 4. The unrelated `Gemfile.lock` change in the working tree is not part of any commit of this spec.

## Confirmed complete (by the reviewer, against the code)

`lots` → `catalog_entries` foreign key; `sqlite3` in the image; no `encrypts` or message verifiers beyond `ActiveStorageGate`; `collector:user` deletes sessions; `ImportUpload` is the only attachment and a missing file gives 422 "Preview the file again."; `docker-entrypoint` runs `db:prepare` only for the server; `db:prepare` creates missing queue, cache and cable databases; boot initializers don't touch the database; the test database is a file; hosted-door rules 1, 3 and 4 are stated and met and rule 2's argument holds; non-goals match the north star's "Not before 1.0"; one outcome and no plan or code.

---

# Round 2 (Mode A, second review, Opus, 2026-10-21)

**Reviewed:** spec version 1.1.0 (commit `55b239e`), read-only. **Verdict on 1.1.0:** NEEDS REVISION (0 critical, 4 major, 11 minor); every first-round critical finding was confirmed fixed (I7 partly, I6 partly, resolved by M1 and M2 below).
**State of 1.2.0:** every finding is addressed, and none is declined. The revised spec has not been reviewed a third time; the plan's first review reads it with this list. The maintainer's rulings of 2026-10-21 are recorded in the spec (decision headings "(ruled)", changelog 1.2.0, Open Questions).

## Major

| # | Finding | Fix in 1.2.0 |
|---|---|---|
| M1 | The Kamal restore (`kamal app exec` before first boot) fails on a fresh host: no env file, no `kamal` network, no `latest` tag | Ruling, option (a): decision 4's Kamal sequence is `kamal server bootstrap`, an `ssh` one-off `docker run --rm -u 1000 -v collector_storage:/rails/storage -v <dir>:/backups:ro -e SECRET_KEY_BASE_DUMMY=1 ghcr.io/plainprogrammer/collector:X.Y.Z bin/rails "backup:restore[…]"`, then `kamal setup`/`deploy`; the exact version is required (releases deploy with `--skip-push --version`); the plan confirms the rake task doesn't read `secret_key_base` eagerly; documented, not exercised through Kamal (no host); AC-5.1 and the Open Questions say the same |
| M2 | The copy-in before the first start has no mechanism or ownership step | Decision 4's table names, for each engine, the preferred read-only bind mount of a host directory `chown`ed to 1000 (rootless Podman `:U` or `--userns=keep-id`) and the `create` + `cp` + `-u 0` `chown` alternative; says where the input file may live (the mounted directory, or inside the volume); AC-5.1 lists them; AC-5.2 runs both and asserts the restore succeeds from a file copied in the documented way |
| M3 | AC-1.5 is mostly unconstructible: `VACUUM INTO` repairs index damage and fails on b-tree damage | Decision 7 explains it and states the verification proves the snapshot, not the source; AC-1.5 is now `VACUUM INTO` failing (simulated `SQLITE_CORRUPT` or a damaged page), new AC-1.12 is the foreign-key case; AC-3.7 builds its damaged snapshots directly, not through `backup:create`; error table split |
| M4 | FR-2's order calls a text file or an export "incomplete" instead of "not a backup" | FR-2 defines the classification order: (1) not a backup (not gzip, or first tar entry not `manifest.json`, including a JSON export), (2) incomplete (starts as a backup and ends early, CRC or length, `*.partial`), (3) unknown format version; AC-3.1 and AC-3.3 say so (and a tar.gz without `manifest.json` is added to AC-3.3) |

## Minor

| # | Finding | Fix in 1.2.0 |
|---|---|---|
| m1 | `.backup` comparison overstates the restart problem | Decision 1 says the incremental API as the `sqlite3` command runs it restarts; a single step doesn't; the conclusion stands |
| m2 | Long read transaction holds the WAL; the cron can collide with the Monday refresh | Decision 8 and AC-5.1: the cron line avoids Monday 03:00 to 05:00; decision 13 and the Cost NFR state the WAL growth |
| m3 | Temporary files are readable while the run lasts | Decision 7 and FR-1: the `.partial` snapshot is pre-created empty 0600 and the archive 0600 from creation; AC-1.6 asserts the mode, AC-1.8 refers to it |
| m4 | Verification must not reopen the snapshot through Active Record | Decision 6 and FR-1: `SQLite3::Database` directly, `foreign_keys = ON` set; AC-1.4 and AC-2.1 assert header bytes 18 and 19 equal 1 and no sidecar |
| m5 | The restore's temporary file can leave a `-journal` | FR-2 and FR-6: its own temporary file and that file's `-journal`, ignored by name by the freshness test; AC-2.6 |
| m6 | FR-1 doesn't say a failed run removes its `.partial` files | FR-1 and AC-1.5 |
| m7 | Durability of the rename is not stated | Decision 7: `fsync` of the archive before the rename and of the directory after it, and of the placed primary in the restore (FR-2) |
| m8 | The file name's time format is not fixed | Decision 5 and AC-1.1: `collector-backup-YYYYMMDDTHHMMSSZ.tar.gz`, pattern checked |
| m9 | The foreign-key refusal needs its rationale and a way out | Decision 7 gives the rationale; the failure message points to each collector's export (AC-1.12) |
| m10 | "The instance keeps answering requests throughout" has no check | Removed from AC-1.1; `bin/backup-smoke` polls `/up` during the backup (AC-5.2, decision 9); AC-1.3's concurrent writer covers the rest |
| m11 | Nits: one README "Back up this volume" bullet; migrations read without a connection | "Documents that change" says one Compose bullet and a pointer in the Kamal part; FR-8 names `ActiveRecord::MigrationContext#migrations` and bars the connection's `migration_context` |
