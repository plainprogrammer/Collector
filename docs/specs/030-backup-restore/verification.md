# Verification: Feature 030, Back Up and Restore an Instance

- **Spec:** [spec.md](spec.md) (1.2.1), plan [plan.md](plan.md)
- **Branch:** `030-backup-restore`
- **Date:** 2026-10-22
- **Executor:** Sonnet 5.5

**Not run, or owed:**

- **AC-5.6, the maintainer's NAS restore, is OWED.** It is the maintainer's step (plan step 8.4), not an agent's. Nothing below claims it.
- **No CI run exists yet** (nothing is pushed). The second architecture (amd64; the local smoke test ran on linux/arm64) and the boot examples in a keyless environment have their further evidence in the first CI run; see the AC-5.2, AC-5.3, AC-2.3 and AC-4.2 rows and the D4 note.
- `bin/ci` is run by the coordinator; its result goes under `## bin/ci`.
- The implementation review (`sdd-review` Mode B) is recorded at the end of this file.

Evidence cells name a spec file and the example's wording (all under `spec/` unless a path says otherwise), a document location, or a run. "restore_spec" is `spec/lib/collector/backup/restore_spec.rb`, "create_spec" is `spec/lib/collector/backup/create_spec.rb`, "archive_spec", "snapshot_spec", "manifest_spec", "run_spec", "refusal_spec" and "databases_spec" are beside them; "create rake spec" and "restore rake spec" are `spec/tasks/backup_create_rake_spec.rb` and `spec/tasks/backup_restore_rake_spec.rb`.

## Acceptance criteria and requirements

| Item | Evidence |
|---|---|
| AC-1.1 | create_spec "writes one file named by the UTC second and returns its facts (AC-1.1)"; create rake spec "prints the file's path, size, schema version, counts and time, and exits 0 (AC-1.1)" |
| AC-1.2 | create_spec, `describe "while the app writes (AC-1.2, AC-1.3)"`, "holds both rows of every pair or neither, passes its checks, and lets writes commit while VACUUM INTO runs" (writers in two child processes; commits counted between the `:snapshot_starting` and `:snapshot_written` checkpoints, review minor 1) |
| AC-1.3 | The same example (a pair writer and a lot writer in child processes; no write fails, none waits as long as the busy timeout, and commits land inside the `VACUUM INTO`'s own window). Also measured on a large database: Measurements, "Writes during the backup" |
| AC-1.4 | archive_spec `.write` "makes a private gzip'd tar of manifest.json then primary.sqlite3 and nothing else that the system tar reads (AC-1.4)"; snapshot_spec `#rollback_journal!` "turns a WAL file into a rollback-journal file with no sidecar, whatever its header said first (AC-1.4)"; create_spec "holds the manifest and a rollback-journal snapshot that agrees with it, and no sidecar (AC-1.4)"; manifest_spec "writes exactly the six members of AC-1.4 and reads them back" |
| AC-1.5 | snapshot_spec `.take` "calls a source with a page it can't read damaged (AC-1.5)"; create_spec "refuses a damaged database with a plain message and leaves nothing behind (AC-1.5)" |
| AC-1.6 | create_spec "leaves at worst a private .partial file when it is killed with the snapshot written (AC-1.6)" and "removes a .partial file more than a day old on the next run and leaves a younger one (AC-1.6)" |
| AC-1.7 | create rake spec "prints no recognisable name, address or card, and logs none (AC-1.7)"; restore rake spec "prints no recognisable name, address or card, and logs none (AC-1.7)" |
| AC-1.8 | create_spec "is private and holds no secret or setting, and nothing but the two files (AC-1.8, AC-4.1)" |
| AC-1.9 | create_spec "never replaces a file with the name it would use, and leaves no .partial (AC-1.9)" and "gives two runs started together one file between them and the clash message for the other (AC-1.9)"; archive_spec `.write` "never replaces a file that is there" |
| AC-1.10 | `script/backup/measure.rb`, outside the suite: Measurements (AC-1.10) below |
| AC-1.11 | create_spec "refuses a directory that doesn't exist, can't be written or has too little room, writing nothing (AC-1.11)"; free_space_spec "reads the bytes available on the filesystem that holds a path" and "answers nil when it can't read the figure, so the check is skipped rather than guessed" |
| AC-1.12 | snapshot_spec `#verify!` "counts the rows that fail the foreign-key check (AC-1.12, AC-3.7)"; create_spec "refuses a database that fails its foreign-key check and points to the exports (AC-1.12)" |
| AC-2.1 | restore_spec `describe "a fresh volume (AC-2.1, AC-2.11)"`, "places the snapshot with the sessions ended and every other row as it was"; snapshot_spec `#end_sessions!` "deletes every session with foreign keys on, which takes the bulk removals, selections and marks with them (decision 3, AC-2.1)"; restore rake spec "restores onto the configured volume, prints the facts and exits 0 (AC-2.1)" |
| AC-2.2 | `spec/backup_restored_instance_spec.rb` "signs the collector in with their password, shows their lots and exports the same collection (AC-2.2)" |
| AC-2.3 | `bin/backup-smoke`, `verify_restored` ("the restored instance's databases weren't a fresh instance's with the collection (AC-2.3)"), run locally with podman on linux/arm64 (Smoke test section); a CI run on both architectures is the further evidence and has not happened |
| AC-2.4 | `spec/backup_restored_instance_spec.rb` "ends every session: the old cookie is sent to sign in, and the password works (AC-2.4)" |
| AC-2.5 | restore_spec `describe "a volume that isn't fresh (AC-2.5)"`, one generated example per case ("refuses a volume that holds <case> and changes nothing": a primary, only a -wal of a gone database, only a queue database), and "refuses a primary that appears while the restore runs, and removes its temporary file (never overwrites)"; databases_spec `#occupied` "names each of the four databases and each -wal, -shm and -journal file that is there (decision 6)" |
| AC-2.6 | restore_spec `describe "a restore that is refused or stopped (AC-2.6)"`: "never creates the primary's path for a file that doesn't exist", "leaves no primary database when it is killed with the snapshot written, and the next restore succeeds and cleans up" |
| AC-2.7 | restore_spec "reads no secret: one backup restored under two secrets holds the same rows (AC-2.7)"; `spec/backup_boot_spec.rb` (the tasks run in production with no secret) |
| AC-2.8 | `spec/backup_restored_art_spec.rb` "offers text recognition only until Build art index is pressed, which then needs no request (AC-2.8)" |
| AC-2.9 | `spec/backup_restored_catalog_spec.rb` "reads a refresh recorded as running as interrupted, and lets a refresh start (AC-2.9)" |
| AC-2.10 | `spec/backup_restored_catalog_spec.rb` "answers 'Preview the file again.' for an upload whose file isn't there, and the sweep removes its row (AC-2.10)" |
| AC-2.11 | restore_spec "restores an instance with no users and says who becomes its admin (AC-2.11)" |
| AC-3.1 | archive_spec `.read` "calls a file cut short incomplete (AC-3.1)", "calls a file whose gzip checksum fails incomplete (AC-3.1)", "calls an intact file named *.partial incomplete, because the run that made it didn't finish (AC-3.1)"; restore_spec "refuses a file cut short, and a .partial file, as incomplete (AC-3.1)" |
| AC-3.2 | archive_spec "calls a changed snapshot a checksum failure, not an incomplete file (AC-3.2)"; restore_spec "refuses a changed snapshot on its checksum (AC-3.2)" |
| AC-3.3 | archive_spec "refuses what isn't a backup, saying so and never 'incomplete' (AC-3.3)", "tells a Collector export file where it belongs (AC-3.3)"; restore_spec "refuses what isn't a backup, and a Collector export, saying so (AC-3.3)" |
| AC-3.4 | manifest_spec "refuses a version this release doesn't restore, before it looks at any other member (AC-3.4)"; archive_spec "refuses a backup format version this release doesn't restore, naming the ones it does (AC-3.4)"; restore_spec "refuses an unknown backup format version, naming the ones it restores (AC-3.4)" |
| AC-3.5 | restore_spec "refuses a newer release's backup, naming both schema versions (AC-3.5)" |
| AC-3.6 | `spec/backup_upgrade_spec.rb` "restores it as it is, and the first start migrates it with every row kept"; construction differs from the criterion's wording, see note 1 |
| AC-3.7 | snapshot_spec `#verify!` "calls a database with an unreadable page damaged (AC-3.7)", "counts the rows that fail the foreign-key check (AC-1.12, AC-3.7)"; restore_spec "refuses a snapshot with an unreadable page, and one with an orphan row, as damaged (AC-3.7)" |
| AC-3.8 | restore_spec (`expect_refused` on every refusal example above, defined in `spec/support/backup_helpers.rb`); restore rake spec "prints each refusal as two lines, exits 1 and prints nothing else (AC-3.8)"; run_spec "prints a refusal as its two sentences and exits 1", "prints a system error nothing else names as two plain lines without its class or its frames, and exits 1", "does the same for a SQLite error"; restore_spec "refuses a file the user can't read and a volume it can't write, naming the fix and changing nothing (plan-review M3)"; refusal_spec "keeps what is wrong and what to do as two sentences, and reads as both (FR-4, AC-3.8)" |
| AC-4.1 | create_spec "is private and holds no secret or setting, and nothing but the two files (AC-1.8, AC-4.1)" |
| AC-4.2 | `bin/backup-smoke`, `verify_restored` (sign in under a different `SECRET_KEY_BASE`; the first instance's cookie is refused), run locally; CI is the further evidence |
| AC-4.3 | `spec/backup_guards_spec.rb` "uses no Active Record encryption, so no secret protects any data in the database (AC-4.3)" |
| AC-4.4 | Reading: README "Backup and restore" > "What to keep outside the backup" (README.md line 373); see the Phase 7 reading |
| AC-5.1 | Reading: README "Backup and restore" (README.md line 358); see the Phase 7 reading |
| AC-5.2 | `bin/backup-smoke`, run locally (Smoke test section): the first step prints "back up while /up is polled (AC-5.2)"; CI on both architectures is the further evidence and has not happened |
| AC-5.3 | `spec/image_publishing_spec.rb` "runs bin/backup-smoke after bin/image-smoke and before the push, on each architecture (spec 030 AC-5.3)"; `.github/workflows/ci.yml` step "Backup smoke test" (`run: bin/backup-smoke collector:smoke`, line 120) after "Smoke test", in the matrix job "Image (${{ matrix.platform }})"; the first CI run is not yet available |
| AC-5.4 | The support layer `spec/support/backup_helpers.rb` and every non-container example above, run under `bin/ci` (result under `## bin/ci`) |
| AC-5.5 | `spec/backup_guards_spec.rb` "knows every collector-owned attachment: only ImportUpload's, listed as transient (AC-5.5)" with its negative control "would notice a new attachment (a negative control for the guard above)", and "knows exactly the four production databases (AC-5.5)" |
| AC-5.6 | **OWED** to the maintainer; see `## NAS restore (AC-5.6)`. Not done |
| AC-5.7 | Reading: `docs/releasing.md` step 5 and the Upgrade notes entry "Backup and restore (spec 030)"; see the Phase 7 reading |
| AC-6.1 | Reading: README "Your data" (line 342) and "Backup and restore" (line 358) with its "Export or backup?" table (line 362), linking to each other; see the Phase 7 reading |
| AC-6.2 | `spec/backup_guards_spec.rb` "has no route, controller or view named for a backup, and no route runs the tasks (AC-6.2)" |
| FR-1 | create_spec (all examples above); `Collector::Backup::Create` in `lib/collector/backup/create.rb` |
| FR-2 | archive_spec `.read` "hands the manifest to on_manifest before it reads the snapshot or checks the checksum (FR-2: the room before the checksum)", "does not call on_manifest for a file that isn't a backup or names an unknown version", "calls a cut-short file of an unknown version incomplete first (FR-2's order)"; restore_spec "checks the room before the checksum, as FR-2 lists them (maintainer's ruling m3)", "refuses when the volume has too little room, before it writes anything", and the refusal examples of AC-3.1 to AC-3.7 in FR-2's order; see note 3 |
| FR-3 | restore_spec "places the snapshot with the sessions ended and every other row as it was" (compares every other table); snapshot_spec `#end_sessions!`; the FR-8 trace shows the live primary is never opened |
| FR-4 | refusal_spec; run_spec (three examples above); create rake spec "prints a refusal as two sentences without an exception class or a backtrace, and exits 1"; every refusal example |
| FR-5 | `spec/backup_guards_spec.rb` "keeps core code free of any collectible: the backup's files name neither MTG nor Scryfall (FR-5)" |
| FR-6 | create_spec "removes a .partial file more than a day old on the next run and leaves a younger one (AC-1.6)"; restore_spec "…the next restore succeeds and cleans up" (the AC-2.6 kill example); the FR-8 trace (grep of `lib/collector/backup` and `lib/tasks/backup.rake`) |
| FR-7 | archive_spec (the system `tar` reads the archive); reading of `docs/backup-restore.md` (sections "The file", "The manifest", "What a restore checks", "Manual recovery with `tar` and `sqlite3`"); see the Phase 7 reading |
| FR-8 | restore_spec (no primary path after any refusal, `expect_refused`); databases_spec ".configured" "reads the production databases from config/database.yml without connecting (FR-8)"; `spec/backup_boot_spec.rb`; the Phase 4 FR-8 trace below |
| FR-9 | `spec/image_publishing_spec.rb` (AC-5.3 example above, and "keeps the backup smoke script out of the image, and the image smoke test checks it (spec 030 FR-9)"); `CLAUDE.md` Commands lists `bin/backup-smoke <image> [restore-image]` (CLAUDE.md line 24) |
| FR-10 | The AC-1.7 and AC-1.8 examples (create and restore rake specs, create_spec "is private and holds no secret or setting…"), and restore_spec "reads no secret…" |

Decisions 1 to 15 map to the same examples and documents as the plan's Requirement Map names (plan.md lines 90 to 163); no separate table is repeated here. Decision 13's bar is the Measurements section; decision 14 is the NAS restore and `docs/releasing.md` step 5.

**Items with no evidence:** AC-5.6 (owed, see below). Every other item above has an example or document location that I confirmed by grep. Items whose full evidence needs CI (AC-2.3, AC-4.2, AC-5.2, AC-5.3, and the boot examples in a keyless environment) have a local run and wait for the first CI run.

## Measurements (AC-1.10)

- **Machine:** Apple silicon Mac (Darwin 25.5.0, arm64)
- **Date:** 2026-10-22
- **Ruby:** 4.0.7
- **Commands:** the three of the header of `script/backup/measure.rb`: `mkdir -p tmp/measure && rm -f tmp/measure/primary.sqlite3*`; `export RAILS_ENV=test DATABASE_URL=sqlite3:$PWD/tmp/measure/primary.sqlite3`, then `bin/rails db:schema:load`, then `bin/rails runner script/backup/measure.rb`.

These numbers come from a seeded database (synthetic rows, `MEASURE_ENTRIES` printings), not from the maintainer's instance.

| Measure | Value | Bar |
|---|---|---|
| Seeded database | 121.1 MB (100000 entries, 100000 unretired, 50012 lots) | gate: 50,000 unretired |
| Backup file / snapshot | 8.6 MB / 119.5 MB | |
| Backup, verification included | 1.7 s | under 300 s: met |
| Writes during the backup (Lot.add!, no password hash) | 12, longest wait 0.013 s | under 5 s: met |
| Restore | 1.8 s | under 300 s: met |
| Write-ahead log after the run | 7.1 MB | recorded |

All bars were met, so no fallback (`quick_check` instead of `integrity_check`, or a different compression level) was needed. AC-5.6, the maintainer's own restore, is the real-data check.

## Phase 7 reading (documents)

Read: plan.md 1-163 and Phase 7 (2971-3209); spec 030 AC-4.4, AC-5.1, AC-5.6, AC-5.7, AC-6.1, FR-7, FR-9, "Documents that change"; ADR 0024; plan-review N2 and m4; .claude/rules/documentation.md, testing.md, sqlite-and-migrations.md; README.md, CLAUDE.md, docs/releasing.md, docs/roadmap.md, docs/specs/README.md (030 row present), docs/adr/README.md (0024 line present; its "Expected" line names no backup mechanism, so nothing to remove).
Checked against the code: lib/collector/backup.rb, backup/{archive,manifest,create,restore,snapshot,databases}.rb, lib/tasks/backup.rake, bin/backup-smoke, config/deploy.yml (alias `backup`, commented `/srv/collector-backups:/backups` volume), .github/workflows/ci.yml (Backup smoke test step after Smoke test), config/database.yml (production.sqlite3 and the three others), compose.yaml (service `web`, volume `collector_storage`).

| Criterion | What was read / checked |
|---|---|
| AC-5.1 | README "Backup and restore": Compose, Podman (`podman cp collector_web_1`, name lookup via `podman ps`), Kamal (alias, directory created and owned by uid 1000 before the commented volume line is enabled, scp); copy-in both ways (host directory chowned, mounted :ro; create + cp + `-u 0` chown one-off) with `:U` / `--userns=keep-id` for rootless Podman; Kamal restore sequence (`server bootstrap`, install -d, scp, plain `docker run` of the exact release over ssh, `kamal setup --skip-push --version`) with the "exact tag" and "hasn't been run through Kamal itself" sentences; comma and quoting; what to keep outside; schedule and cron line at 02:17 avoiding Monday 03:00-05:00; after-restore checklist; which release to restore onto; what a backup doesn't hold; sensitivity; alternatives B, C, D untested; link to the layout and manual recovery. Every container command matches bin/backup-smoke apart from volume names, image tag and mounts (smoke: `-u 1000`, `-v dir:/backups:ro`, `-e SECRET_KEY_BASE_DUMMY=1`, `bin/rails "backup:restore[/backups/<file>]"`; copy-in: create, cp, rm, `-u 0` chown, `-u 1000` restore with `-e SECRET_KEY_BASE_DUMMY=1`). |
| AC-4.4 | README "What to keep outside the backup": SECRET_KEY_BASE, RAILS_MASTER_KEY, COLLECTOR_* settings, compose.yaml / deploy.yml; "a lost or changed secret costs only the signed-in sessions". Matches the code (no secret in the archive; `end_sessions!`). |
| AC-6.1 | README "Your data" ends with a pointer to #backup-and-restore; "Backup and restore" has the comparison table (decision 11) and links back to #your-data. Anchors exist (`## Backup and restore`, `## Your data`). docs/backup-restore.md links to ../README.md#backup-and-restore; the README's last paragraph links to docs/backup-restore.md#manual-recovery-with-tar-and-sqlite3 (heading exists). Link targets (ADR 0024, spec, export-format/README.md) exist. |
| AC-5.7 | docs/releasing.md step 5 (old 5 renumbered 6) and an Upgrade-notes entry at the top. NAS restore result (AC-5.6) is left owed for Phase 8 / verification.md. |
| FR-7 | docs/backup-restore.md: file name and .partial rule, the two members in order and mode, manifest members matching Manifest (backup_format_version, taken_at, schema_version, snapshot_bytes, snapshot_sha256, counts of accounts/users/lots), the format-version rule, restore check order matching Restore/Archive (volume, kind/partial, version, room via on_manifest, checksum, then integrity/FK, newer schema, sessions, counts, link), manual recovery with tar and sqlite3 (production.sqlite3 per config/database.yml). |
| FR-9 | CLAUDE.md Commands lists `bin/backup-smoke <image> [restore-image]` beside `bin/ci`; CI runs it in the image job after `bin/image-smoke`. |
| Docs rules | CLAUDE.md gets the Project Status sentence, the Commands bullet and the Non-obvious Fact; roadmap item 6 marked Done (no PR link yet); sqlite-and-migrations rule points to ADR 0024. No area doc written (none exists for this area), ADR 0024 status untouched (Phase 8), shipped specs untouched. |

## Phase 4 FR-8 trace (step 4.5), by reading

Command: `git grep -n "Database.new\|establish_connection\|ActiveRecord::Base\|ActiveRecord::" lib/collector/backup lib/tasks/backup.rake ':!.kamal/secrets'`

- `SQLite3::Database.new` appears only in `lib/collector/backup/snapshot.rb`, twice: line 22 (`Snapshot.take`, opens the *source* database of a backup, read through `VACUUM INTO`) and line 82 (`Snapshot#with`, opens the snapshot's own path: the restore's temporary file `collector-restore.partial`, or a scratch/test snapshot). Neither is ever given `@databases.primary`.
- No `establish_connection` and no `ActiveRecord::Base` anywhere in `lib/collector/backup` or `lib/tasks/backup.rake`.
- The only `ActiveRecord::` reference is `ActiveRecord::DatabaseConfigurations` in `databases.rb:9`, which only builds configuration objects from `config/database.yml` (no connection pool, no connection).
- In `restore.rb` the primary's path appears only as the target of `Backup.publish(temporary, @databases.primary)`, a hard link (`File.link`) that fails on a clash; it is never opened, read or created by SQLite. A refusal before that call leaves no primary path (restore_spec: every `expect_refused` compares the volume's file names and checksums; the kill example leaves only `collector-restore.partial`).
- The tasks do not depend on `:environment`, so no initializer or Active Record connection exists in the process.

## Smoke test (AC-2.3, AC-4.2, AC-5.2; FR-9)

`bin/backup-smoke` was run locally with podman (podman 6.1.4, machine podman-machine-default, linux/arm64) against an image built from a `git archive HEAD` of this branch. The build used the archive because the local uncommitted `Gemfile.lock` platform change breaks the frozen bundle in a build from the working tree.

Command: `CONTAINER_CLI=podman bin/backup-smoke localhost/collector:local`. Exit 0. Last line printed: `OK: localhost/collector:local was backed up and restored into localhost/collector:local the documented ways`.

Steps printed:

1. Boot and seed.
2. Back up while `/up` is polled (AC-5.2).
3. Restore from a read-only host directory owned by uid 1000, with `SECRET_KEY_BASE_DUMMY`.
4. Start a second instance under a different `SECRET_KEY_BASE` (AC-2.3, AC-4.2).
5. Copied-in restore, with a root `chown` one-off and `SECRET_KEY_BASE_DUMMY` (before the review's fix 4 this pass ran with no variable at all).

CI on amd64 and arm64 is the further evidence. No CI run exists yet (nothing is pushed).

## Notes, with reasons

1. **AC-3.6's construction (maintainer's ruling m6, 2026-10-21, no spec change).** The criterion says the older snapshot is "built in the spec by migrating a scratch database to that version". `spec/backup_upgrade_spec.rb` instead seeds an instance, backs it up and rolls the newest migration back on the copy, because that keeps the seeded rows, which the criterion's "no row is lost" needs, and an empty scratch database proves nothing about rows. It relies on the newest migration being reversible (a rule: `.claude/rules/sqlite-and-migrations.md`); the example fails with that message otherwise.
2. **The D4 confirmation (plan-review M1).** `config/master.key` is ABSENT in this worktree, so the boot examples were not skipped here. `spec/backup_boot_spec.rb` ran locally and passed: the control ("would fail if they booted the application, which reads secret_key_base eagerly (the control)"), the dummy boot ("boots with the dummy, which is enough, as the documented one-off passes it"), the structural example ("gives neither task a dependency on :environment, so neither initializes the application (the structural guarantee)") and the two task examples ("runs backup:restore in production and answers its own refusal, without a secret", "runs backup:create in production the same way"). On a machine with a key the two boot examples skip themselves, so a CI run in a keyless environment remains the further evidence.
3. **FR-2's order (ruling m3).** The room is checked as soon as the manifest is read, inside `Archive.read`'s first pass, so a file damaged after its manifest on a volume without room is refused for the room, not for the damage. The damage that is told apart only by reading the file to its end: a file cut short, a wrong gzip CRC, trailing damage, and a snapshot whose checksum does not match. Every other pair of FR-2's checks is in FR-2's order.
4. **Kamal's volume (ruling m5).** Decision 4's "stated addition" is read as the `backup` alias live (`config/deploy.yml` line 94) plus the documents' `install -d -o 1000 -g 1000` step and the volume line to uncomment, which stays commented in the stock file (`config/deploy.yml` line 103).

## Deviations from the plan and fixes found in execution

- Phase 0's extraction truncated `spec/backup_guards_spec.rb`; fixed in commit 1f71564 ("fix(backup): write the guards spec of Step 0.6").
- `Backup.create_private` needed `.tap(&:binmode)` (`lib/collector/backup.rb` line 87): with `Encoding.default_internal` set to UTF-8 by Rails, writing gzip bytes raised.
- `Archive.read` needed an extra `gzip.read(1)` (`lib/collector/backup/archive.rb` line 75), because zlib checks the stream's CRC and length only on the first read past the end; the plan's comment claiming otherwise was reworded.
- `Snapshot#verify!` counts unique `[table, rowid]` pairs for `foreign_key_check` (`snapshot.rb` line 45, `.uniq`) rather than every result row.
- Plan spec-code bugs fixed without loosening an assertion: `File.utime` needs a `Time`, not an `ActiveSupport::TimeWithZone`; a concurrent-writer wait loop needed a committed pair; the restore rake spec stubbed `Databases.configured` before the live source was resolved; RSpec cops needed `:aggregate_failures` or a justified inline disable (create_spec and restore_spec carry two `rubocop:disable RSpec/ExampleLength` comments with their reason); the upgrade spec's `describe` needed its type.
- `bin/backup-smoke` is placed in `bin/image-smoke`'s copy list after `lib/collector/ghcr_cleanup.rb` (line 69), not between `bin/ghcr-cleanup` and it, so the existing ghcr-cleanup example's exact string (`bin/ghcr-cleanup lib/collector/ghcr_cleanup.rb`) still matches.
- `docs/adr/README.md` needed no edit in Phase 7 (its "Expected" line names no backup mechanism).

## Security review note

An automated review of `lib/collector/backup/create.rb` flagged (MEDIUM, TOCTOU / insecure temporary file) that `Create#make` makes the snapshot file with `Backup.create_private(snapshot_file)` (`File::CREAT | File::EXCL`, mode 0600, closed at once) and then hands the path to SQLite (`VACUUM INTO`, in `Snapshot.take`).

Executor's assessment, after reading `create.rb` and `Backup.create_private`: not exploitable beyond the operator's own trust boundary. The name is `collector-backup-<time>.sqlite3.<16 hex from SecureRandom>.partial`, created with `O_EXCL` (so a pre-planted file or symlink at that name makes the create fail rather than being followed) in the directory the operator chose. The remaining window is between the close and SQLite's own open of the same path; using it needs another local user with write access to that backup directory, who could then read or replace the backup files there anyway. The pre-created 0600 file is the design of decisions 5 and 7. I made no change and leave it for the independent implementation review to weigh.

## bin/ci

`bin/ci` was run twice in this worktree on the final tree (after the measurement script was committed), both on 2026-10-22:

| Run | Seed | Result |
|---|---|---|
| 1 | 51882 | `1860 examples, 0 failures, 1 pending`; `✅ Tests: RSpec passed in 3m25.08s`; `✅ Continuous Integration passed in 3m45.24s` |
| 2 | 28606 | `1860 examples, 0 failures, 1 pending`; `✅ Continuous Integration passed in 3m11.39s` |

The one pending example is `spec/system/art_agreement_spec.rb` (needs `COLLECTOR_ART_AGREEMENT`), pending before this branch too: the baseline on `origin/main` plus the plan commits was `1757 examples, 0 failures, 1 pending`. RuboCop, Brakeman, bundler-audit and importmap audit passed as steps of the same runs. The local `Gemfile.lock` platform change was uncommitted in both runs.

## NAS restore (AC-5.6)

**OWED to the maintainer.** Not done by an agent; it is plan step 8.4, once, before the spec ships (decision 14). Steps:

1. Build the image from this branch: `docker build -t collector:local .` (a released image has no `backup:create`).
2. Run the NAS instance (Compose) on it with `COLLECTOR_IMAGE=collector:local`.
3. Back it up with the README's Compose commands.
4. Restore that file onto a fresh Compose project of the same image the README's way.
5. Start it and sign in.
6. Compare the printed counts and an export of each (the same collection; `docs/export-format/README.md`).

Where the steps are carried: `docs/releasing.md` step 5 carries the recurring release check (AC-5.7: backup on the previous release, restore onto a fresh Compose project of the new image, start, sign in, compare counts and exports, record in `verification.md`). It does not carry the one-time branch-image build and `COLLECTOR_IMAGE=collector:local` of steps 1 and 2; those are in plan.md step 8.4 and, for the build itself, in `README.md` line 191 ("Building from source"). This is a small gap in where the one-time steps are written, not a missing release check.

| Field | Result |
|---|---|
| Date | |
| Image / commit | |
| Source counts (accounts, users, lots) | |
| Restored counts | |
| Backup time / restore time | |
| Export comparison | |
| Result | |

## Implementation review

SPEC-ALIGNED (independent Sonnet review 2026-10-22, after fixes)

Independent `sdd-review` Mode B by Sonnet 5.5 at `def47ed` against spec 1.2.1: SPEC-ALIGNED, 0 critical, 0 major, 7 minor. Everything below was fixed or ruled, test first, one commit each.

| Finding | Resolution | Commit |
|---|---|---|
| Minor 1, AC-1.2/1.3 example too weak | Writers are two child processes (pairs, lots) with their own connections; `Create` gets a `:snapshot_starting` checkpoint and the example counts commits finishing between it and `:snapshot_written` (about 1,900 in four 40 ms windows on the first run; a blocking backup would give 0). `script/backup/measure.rb` keeps its thread writer: the recorded measurement stands and was not re-run (ruling Q1 names the example). | b5a740b |
| Minor 2, AC-2.9 passed by the stall rule | Heartbeat 5 minutes old: past `JOB_ENDED_GRACE`, inside `STALL_AFTER`, so only the missing job reads "Interrupted". | 0c33c31 |
| Minor 3, FR-2 room-before-incomplete residue | Informational (ruling m3). Residue: a file cut short, with a bad gzip CRC or with trailing damage, on a volume without room is refused for the room, not as incomplete (note 3 above). The spec is not edited. | none |
| Minor 4, copied-in pass without `SECRET_KEY_BASE_DUMMY` | Added to `bin/backup-smoke`'s copied-in pass and the README's copied-in command (ruling Q2). | 2c32a90 |
| Minor 5, no guard for foreign keys to `sessions` | `spec/backup_guards_spec.rb`: every such key must cascade on delete, naming decision 3, with a negative control (ruling Q5). | 0288c3b |
| Minor 6, 2–9-byte prefix called "not a backup" | A gzip-magic file shorter than the 10-byte header is incomplete (`archive_spec`: 2, 5, 9 bytes). | 6a21b5a |
| Minor 7, `Backup.remove` wider than FR-6 | Suffixes are an argument; the restore passes `""` and `-journal` only (`spec/lib/collector/backup/remove_spec.rb`). | d69036b |

Rulings (maintainer, 2026-10-22):

- Q1 and Q2: as above.
- Q3: the art-index issue is filed as #122; `issue-art-index-ready.md` is now a one-line pointer to it (897560f). The approved spec and plan are untouched.
- Q4: ADR 0024 keeps its number (029, PR #123, holds 0023).
- Q5: as above.
- Q6: the PR's CI is the amd64 evidence; nothing was done here.

The review's TOCTOU judgement (Security review note above) agrees with the executor: not exploitable beyond the operator's trust boundary. A later automated scan questioned the narrower `RESTORE_SUFFIXES`; it does not apply. FR-6 and ruling m7 name only the `-journal`, the temporary file is put in rollback-journal mode, and SQLite ignores (and on open removes) a stray `-wal` or `-shm` beside such a file, as the first draft of the Minor 7 example showed.

Results after the fixes (2026-10-22, the Gemfile.lock platform change uncommitted):

- `bin/ci`: `1865 examples, 0 failures, 1 pending` (seed 121); `✅ Tests: RSpec passed in 3m3.14s`; `✅ Continuous Integration passed in 3m23.10s`. The pending example is the same `art_agreement_spec` as before.
- `bin/backup-smoke`, run again locally with podman (linux/arm64) on an image built from a `git archive` of `897560f`: exit 0, last line `OK: localhost/collector:local was backed up and restored into localhost/collector:local the documented ways`, with the copied-in pass now carrying `SECRET_KEY_BASE_DUMMY`.
- Still owed or unconfirmed: AC-5.6 (the maintainer's NAS restore) and the first CI run on amd64.

## Distillation

`distill-feature` ran on 2026-10-22 before the pull request (`f9caae1`). Spec 030's areas are release and deploy and data portability, which have no area doc yet (#109, #108), so nothing was written to `docs/architecture/`. The spec supersedes nothing in a shipped spec. The index row's Plan is "retirement owed"; the plan is retired after the merge. The maintainer's NAS restore (AC-5.6) is still owed and is the spec's release check.
