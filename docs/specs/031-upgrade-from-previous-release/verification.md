# Verification: Feature 031, Prove an Upgrade from the Previous Release in CI

- **Spec:** [spec.md](spec.md) (1.1.2), [plan.md](plan.md)
- **Branch:** `031-upgrade-from-previous-release`
- **Date:** 2026-10-24
- **Executor:** Sonnet 5.5
- **Code verified:** HEAD `7707a54` (the image under test was built from `git archive HEAD` of that commit)

**Not run, or owed:** see `## Owed` below. In short: nothing is pushed and no pull request exists, so there is no CI evidence yet (both architectures, the Ruby setup, the 5-minute bar); AC-7.2's deliberately failing tag is the maintainer's; the NAS restores are not this spec's.

Evidence cells name a spec file and the example's wording (all under `spec/script/upgrade/` unless a path says otherwise), a document location, or a run. "release_spec", "compare_spec", "expected_changes_spec", "guard_spec", "seeds_spec", "seed_exceptions_spec", "snapshot_spec", "web_spec", "engine_spec", "harness_spec" and "files_spec" are the files of that name there. Every example named was confirmed by grep. "Hand" means the runs under `## Hand runs`.

## Acceptance criteria

| Item | Evidence |
|---|---|
| AC-1.1 | release_spec `#previous` "is the newest stable tag on a branch or pull request, in numeric order, skipping pre-releases (AC-1.1)"; `Version` "orders by number, not text, and puts a pre-release before its release (semver precedence)" and "parses only release tags" |
| AC-1.2 | release_spec "is the newest stable tag strictly older than the tag being built on a tag push (AC-1.2)", "is nil for the first tag's run (AC-1.2)"; harness_spec "prints 'no previous release' and touches no container when there is none (AC-1.2)" |
| AC-1.3 | harness_spec "pulls the exact version tag for the platform and prints the digest and revision (AC-1.3)"; engine_spec "builds only commands that a category accepts, for the tasks and the files (AC-8.3)" (the pull argv); hand run 1 printed the `previous: v0.2.1  image …:0.2.1  digest …@sha256:044bc944…  version 0.2.1  revision 12665807…` line |
| AC-1.4 | harness_spec "fails naming the tag and the platform, without a retry or a fallback, when the image has no manifest (AC-1.4)" and "does not retry the 403 ghcr.io answers for a repository that does not exist or a credential without read access (AC-1.4, hand run)"; hand run 3 (a nonexistent repository fails after one attempt, 0.7 s, naming the tag and platform) |
| AC-1.5 | harness_spec "tries a transient pull failure three times, waiting between, then fails naming the registry's last answer (AC-1.5)" and the two AC-1.4 examples (no retry for a missing manifest or a 403) |
| AC-1.6 | files_spec "adds no secret, login or permission of its own, and can't be skipped past (AC-1.6, AC-7.2, FR-6)"; reading of the workflow (`.github/workflows/ci.yml`, steps `Set up Ruby for the upgrade proof` and `Upgrade smoke test`: no `secrets.`, no login, no `permissions:` change) |
| AC-1.7 | release_spec `#building (AC-1.7)`: "is no tag for a push to main whose commit is already tagged, and the previous release is the newest stable", "is the pushed tag", "is the tag at HEAD for a local checkout", "is the tag of highest precedence when several point at HEAD", "refuses a pushed tag that is no release tag" |
| AC-2.1 | harness_spec "fails when the old database was not made by the previous release (AC-2.1)"; first CI run for the real check |
| AC-2.2 | seeds_spec `next.rb, run on the code under test` "prints the completion line with what the harness reads (AC-2.2)"; hand runs 1 and 2 (the seed ran in the previous release's container) |
| AC-2.3 | compare_spec "reads the facts of AC-2.3 back from a seeded database"; seeds_spec "leaves what AC-2.3 asks for" and "schedules a job with the marker argument a year ahead"; harness_spec "fails when the seeded scheduled job isn't in the queue before the stop (AC-2.3)" |
| AC-2.4 | snapshot_spec "folds in a write-ahead log that the copied files came with (AC-2.4)"; engine_spec "copies out the main database file and any -wal and -shm, not the other databases (AC-2.4)"; harness_spec "fails naming the container when it was killed at the end of the grace period (AC-2.4)"; hand runs (the "stop and snapshot" step passed, so the stop exited 0 or 143) |
| AC-2.5 | seed_exceptions_spec `.coverage` "fails a table without a row, naming the table and the seed file (AC-2.5, AC-2.6)", "passes a listed exception and prints it (AC-2.5)", "fails an exception for a table the database does not have (AC-2.5)"; harness_spec "fails when a table of the previous release got no rows from the seed (AC-2.5)" |
| AC-2.6 | seeds_spec "fills every table db/schema.rb creates, except those listed under next (AC-2.6, FR-7)" (runs in `bin/ci`); seed_exceptions_spec ".coverage" (above) and "ships with no exception for the previous release or for next"; hand run 2 (the `== seed of the next release` step) |
| AC-2.7 | harness_spec "fails before booting anything when the previous release has no seed, naming the file and the release step (AC-2.7)" |
| AC-2.8 | harness_spec "fails with the seed's error rather than comparing a half-filled database (AC-2.8)" |
| AC-2.9 | harness_spec "proves a clean upgrade, in AC-2.9's order, and prints the comparison (AC-4.1, AC-7.3)"; hand run 1 printed the steps in that order |
| AC-3.1 | engine_spec "starts a container the way an operator does: the volume, the secret, the port, the flags and the entrypoint's boot"; hand runs 1 and 2 (the upgrade boot answered `/up`); first CI run on both architectures |
| AC-3.2 | harness_spec "fails when the upgraded database lacks a migration of the code under test (AC-3.2)" |
| AC-3.3 | harness_spec "names the migration and the release when the upgraded container exits before /up (AC-3.3)"; `.failed_migration` "names the last migration a log began" |
| AC-3.4 | engine_spec "refuses a database task in any category (AC-3.4)", "keeps every forbidden task name in one constant and out of every other line of the harness (AC-3.4, AC-8.3)" |
| AC-3.5 | compare_spec "reports a foreign key violation and a clean database (AC-3.5)"; the harness's `compare` step |
| AC-4.1 | compare_spec "passes identical databases and prints a line per table with its counts (AC-4.1)"; harness_spec happy path (above); hand run 1 printed 19 table lines, each `same` with its digest |
| AC-4.2 | compare_spec "reports a missing row with the table and the first key (AC-4.2)", "reports an extra row, a changed value (with its column), a dropped column and a dropped table (AC-4.2)"; harness_spec "fails naming the table and the first key when the upgrade loses a row (AC-4.2, AC-7.5)" |
| AC-4.3 | compare_spec "ignores a column only the new table has, and a new table (AC-4.3)"; hand run 2 compared 26 tables including ones the previous image lacked, no failure |
| AC-4.4 | compare_spec "passes a difference an expected change lists and prints it with its reason (AC-4.4)"; expected_changes_spec "keeps an entry whose migration the previous release lacks as live (AC-4.4)"; hand run 2 printed the four `expected:` lines of the backup leg |
| AC-4.5 | compare_spec "fails a live expected change that matches nothing and names it (AC-4.5)"; expected_changes_spec "retires an entry whose migration the previous release already has, without failing (AC-4.5)", "names the entry that is incomplete, has an unknown kind, or rewrites without a column (AC-4.5)", "names an entry whose migration is no file of the code under test (AC-4.5)"; harness_spec "treats an image of a commit as no release: reads the tree from the ref, runs next.rb, retires listed changes, says so" |
| AC-4.6 | compare_spec "says to fix the migration or list an expected change when a migration empties a column (AC-4.6)" |
| AC-4.7 | compare_spec "orders a table without an integer primary key by all its columns, so rowid order doesn't matter (AC-4.7)", "tells 1 from '1' and NULL from '' (decision 5's encoding; AC-4.7)" |
| AC-5.1 | web_spec "signs in with the form's CSRF token and keeps the session cookie (AC-5.1)"; harness_spec "fails when a collector can't sign in with their old password (AC-5.1)" |
| AC-5.2 | harness_spec "fails when the collector's own page lacks a card name, or shows it to another collector (AC-5.2)" |
| AC-5.3 | web_spec "tells the sign-up form from the closed notice by its email field (AC-5.3)"; harness_spec "fails when the sign-up page differs after the upgrade (AC-5.3)" |
| AC-5.4 | harness_spec "fails when a seeded location is not listed, and passes when it is (AC-5.4)" |
| AC-5.5 | harness_spec "fails when the export holds fewer lots than were seeded, or names a version it has no schema for (AC-5.5)" |
| AC-5.6 | harness_spec "fails when the recurring tasks are not all registered, after waiting for them (AC-5.6)"; hand runs 1 and 2 (the check passed within the wait) |
| AC-5.7 | harness_spec "fails when the scheduled job is gone from the queue after the upgrade (AC-5.7)" and "fails when a job enqueued on the upgraded instance has no row in the queue database (AC-5.7)"; the backup leg does not apply it: "runs Story 5's checks on the restored instance but not AC-5.7, which a primary-only backup can't satisfy (AC-6.2)" |
| AC-6.1 | harness_spec `the backup leg` "backs up with the previous release, restores with the code under test under another secret, and compares (AC-6.1, AC-6.2)", "fails when the backup directory doesn't hold exactly one file (AC-6.1)"; engine_spec "restores with the dummy secret from a read-only directory, as the README documents (AC-6.1)"; hand run 2 |
| AC-6.2 | harness_spec "backs up with the previous release, restores … and compares (AC-6.1, AC-6.2)", "runs Story 5's checks on the restored instance but not AC-5.7 …", "fails when the sessions a restore ends are still there (P4)", "fails when the restore loses a row (AC-6.2)"; compare_spec "requires the tables of a restore to be emptied and passes their removal (P4)"; expected_changes_spec "lists the tables a restore empties as rows_removed entries (P4)", "names every table the schema cascades from sessions, so the allowance can't go stale (P4, review m8)"; hand run 2 (26 tables; the four allowed tables differ, each with its `expected:` line, every other table `same`) |
| AC-6.3 | harness_spec "fails naming the refusal when the code under test refuses a backup the previous release took (AC-6.3)" |
| AC-6.4 | harness_spec "skips the leg with a printed line, and the exit status doesn't change, when the previous release has no backup task (AC-6.4)"; hand run 1 printed `previous release v0.2.1 has no backup task; backup leg skipped`. The other half (a release with the task and no working leg fails) is by the code: `script/upgrade/harness.rb` `backup_task?` sets `@backup_expected` from the container's rake task list, and `take_backup` raises unless the file is reported and the directory holds exactly one; no example drives a task-present failure of the listing itself |
| AC-6.5 | Hand run 2 (the commit image `sha-4cd1ef5` with `--previous-ref 4cd1ef5`); harness_spec `the hand modes` "treats an image of a commit as no release: reads the tree from the ref, runs next.rb, retires listed changes, says so" |
| AC-7.1 | files_spec `the image job` "runs bin/upgrade-smoke for each architecture after the backup smoke test and before the push, on every event (AC-7.1)" |
| AC-7.2 | files_spec "adds no secret, login or permission of its own, and can't be skipped past (AC-1.6, AC-7.2, FR-6)" (the job graph: the publish job needs the image jobs); the throwaway tag is **OWED** to the maintainer, see `## Owed` |
| AC-7.3 | harness_spec "removes every container, volume and the scratch directory on success and on failure (AC-7.3, FR-6)", "removes its temporary directory"; "proves a clean upgrade, in AC-2.9's order …" (exit status and steps); after each hand run `podman ps -a` and `podman volume ls` were empty |
| AC-7.4 | harness_spec "fails the run when the check exceeds its time limit, printing the time (AC-7.4)"; files_spec "sets up the host Ruby for the comparer before it, outside the proof's own limit (decision 5, AC-7.4)" (the step's `timeout-minutes: 12` above the harness's 600 s); local times under `## Measurements`; the CI times are owed |
| AC-7.5 | harness_spec "fails naming the table and the first key when the upgrade loses a row (AC-4.2, AC-7.5)", "reports an error of no expected kind with the same evidence lines (AC-7.5, Error Scenarios)"; hand run 3 printed the previous release, commit and reproduction lines |
| AC-7.6 | files_spec "fetches the full history and the tags in the ci job, which runs the guard (AC-8.5, AC-7.6)"; the `ci` job pulls no image (reading of `ci.yml`) |
| AC-8.1 | guard_spec "passes when every released migration is unchanged and a new one was added (AC-8.1)", "runs as a script: prints the lines and exits non-zero on a failure (AC-8.1)"; files_spec "runs the migration guard in bin/ci (AC-8.1, AC-8.6)"; `bin/ci` step `Upgrade: released migrations unchanged` passed in 0.36 s |
| AC-8.2 | guard_spec "fails naming an edited migration and saying a new migration is the fix (AC-8.2)", "fails naming a deleted migration (AC-8.2)", "fails naming a renamed migration (AC-8.2)" |
| AC-8.3 | engine_spec "builds only commands that a category accepts, for the container's life (AC-8.3)" and "… for the tasks and the files (AC-8.3)", "starts a process only in engine.rb (the container CLI) and release.rb (read-only git) (AC-8.3)" |
| AC-8.4 | guard_spec "says the code under test is behind the release when a branch lacks a released migration (AC-8.4)" |
| AC-8.5 | release_spec "fails, saying to fetch tags, when there is a remote and no tags at all (AC-8.5)", "is nil when there are no tags and no remote"; guard_spec "passes with a line saying there is no previous release when no tag is stable (AC-8.5)", "fails saying to fetch tags when the checkout has a remote and no tags (AC-8.5)"; files_spec "fetches the full history and the tags in the ci job …" and "fetches the full history and the tags, because the proof resolves the previous release from them (AC-8.5)" |
| AC-8.6 | `spec/script/upgrade` uses fakes and loopback only (engine_spec "has a fake that answers every builder, so the harness specs cover what the harness calls"); all 11 files ran in `bin/ci` (2131 examples, 0 failures, with the container engine unused by the suite) |
| AC-9.1 | Reading, `## Documents read` below |
| AC-9.2 | Reading, `## Documents read` below |
| AC-9.3 | Reading, `## Documents read` below |
| FR-1 to FR-8 | As the rows above; FR-6 (cleanup) harness_spec "removes every container, volume and the scratch directory …"; FR-7 seeds_spec "fills every table db/schema.rb creates …"; FR-8 files_spec "keeps bin/upgrade-smoke out of the image, and the image smoke test checks it (FR-8)" |
| NFR self-hosting (no migration, no setting) | `git diff --stat main -- db config` shows only `config/ci.rb | 1 +`; `git diff --stat main -- docs/specs/030-backup-restore` is empty (spec 030's files are not edited) |

**Items with no evidence yet:** AC-7.2's real tag (owed), and the CI run of every row marked "first CI run". Every other row has an example or document location that I confirmed by grep. Three names in the plan's Traceability table differ from the example names in the files (for example the plan's "tag push" is the example "is the newest stable tag strictly older than the tag being built on a tag push (AC-1.2)"); this table uses the names as they are in the files.

## bin/ci

Run in this worktree on HEAD `7707a54`, after the image was built (the first attempt was invalidated: an earlier background `bin/ci` was still running on the same test database and the two collided with `SQLite3::BusyException`; I let the first finish and re-ran alone). Final lines of the clean run:

```
✅ Setup passed in 3.64s
✅ Upgrade: released migrations unchanged passed in 0.36s
✅ Style: Ruby passed in 0.94s
✅ Security: Brakeman code analysis passed in 3.22s
✅ Security: Gem audit passed in 0.45s
✅ Security: Importmap vulnerability audit passed in 1.11s
2131 examples, 0 failures, 1 pending
✅ Tests: RSpec passed in 2m57.20s
✅ Continuous Integration passed in 3m6.92s
```

(The one pending example is `spec/system/art_agreement_spec.rb:16`, which is not this feature's.)

## Hand runs

Machine: Apple silicon Mac, podman 6.1.4 machine (linux/arm64, 4 CPUs, 2 GiB), host Ruby 4.0.7 from mise. The image under test was built from a fresh `git archive HEAD` of `7707a54` in an empty directory: `podman build -t collector:upgrade-dev .` took 18.8 s (most layers cached; a cold build was not measured). Every run used `REGISTRY_AUTH_FILE` pointing at a file holding `{}` (see the ghcr login note under `## Deviations and rulings`). Raw logs are in the session scratchpad only (they are not kept in the repository).

**Run 1: `time bin/upgrade-smoke auto collector:upgrade-dev`** (AC-1.x, AC-2.x, AC-3.1, AC-4.1, AC-5.x, AC-6.4, AC-7.3): exit 0, 26.7 s wall (25 s printed). Steps printed in order: resolve (`previous release: v0.2.1`), seed and rules, pull, boot the previous release, seed, before the stop, stop and snapshot the old database, upgrade, snapshot and compare, behaviour, backup leg, seed of the next release. The pull line gave `ghcr.io/plainprogrammer/collector:0.2.1`, digest `sha256:044bc944cd6fe0de3530ee7c9f63c98315a0e69a85c42ea6fce28c99e0e64c48`, version 0.2.1, revision `126658074684b2ea20e63a103b6051de3aec9906`. The comparison printed 19 tables, each `same` (lots 2001 to 2001). The backup leg was skipped with `previous release v0.2.1 has no backup task; backup leg skipped`. Last line:

```
OK: v0.2.1 (ghcr.io/plainprogrammer/collector@sha256:044bc944cd6fe0de3530ee7c9f63c98315a0e69a85c42ea6fce28c99e0e64c48) upgraded to 7707a54def06; 19 tables compared, behaviour verified, 25 s
```

**Run 2: the backup leg by hand (AC-6.5)**: `time bin/upgrade-smoke ghcr.io/plainprogrammer/collector:sha-4cd1ef5 collector:upgrade-dev --previous-ref 4cd1ef5`: exit 0, 37.7 s wall (36 s printed). It printed `this run is not a release proof: … is the build of 4cd1ef5; the seed is next.rb and its exceptions are the `next` ones`. The upgrade comparison covered 26 tables, all `same`. The `== backup leg` comparison showed `bulk_removals` 1 to 0, `bulk_selection_marks` 3 to 0, `bulk_selections` 1 to 0 and `sessions` 2 to 0 as `differs`, each followed by an `expected: <table> rows_removed (backup:restore ends every session, which cascades to the bulk removals and selections (spec 030, docs/backup-restore.md))` line; every other table was `same`. Last line:

```
OK: 4cd1ef5 (ghcr.io/plainprogrammer/collector@sha256:a637e7ee93f7a3234ed1989f5dd3c264b2bd3f6a066c638bda057da1f6da43cd) upgraded to 7707a54def06; 26 tables compared, behaviour verified, 36 s
```

**Run 3: a nonexistent repository (AC-1.4)**: `UPGRADE_IMAGE_REPOSITORY=ghcr.io/plainprogrammer/does-not-exist SMOKE_BOOT_ATTEMPTS=1 bin/upgrade-smoke auto collector:upgrade-dev`: exit 1 after one attempt, 0.7 s wall:

```
== resolve
previous release: v0.2.1
== seed and rules
== pull
FAIL: pull: can't pull ghcr.io/plainprogrammer/does-not-exist:0.2.1 (v0.2.1, this platform) from ghcr.io: Error: unable to copy from source docker://ghcr.io/plainprogrammer/does-not-exist:0.2.1: initializing source docker://ghcr.io/plainprogrammer/does-not-exist:0.2.1: fetching manifest 0.2.1 in ghcr.io/plainprogrammer/does-not-exist: Requesting bearer token: received unexpected HTTP status: 403 Forbidden
  previous: v0.2.1 
  commit: 7707a54def0626a35454a341f7813109bf8d166e
  read: the lines above; the container's log is printed where a boot failed
  reproduce: bin/upgrade-smoke ghcr.io/plainprogrammer/does-not-exist:0.2.1 collector:upgrade-dev
```

(The trailing space after `previous: v0.2.1` is cosmetic: the digest is empty when a pull fails.) A missing tag in an existing repository, checked in the earlier hand run (`collector:9.9.9`), ends `manifest unknown` after one attempt, as the pattern expects.

Cleanup: after the runs `podman ps -a` and `podman volume ls` were empty. Images left in the local store are `collector:upgrade-dev` and the pulled `0.2.1` and `sha-4cd1ef5` images. The build context for this phase is a fresh directory in the session scratchpad; the earlier one could not be deleted by the sandbox and remains there.

## Measurements

| Measure | Value | Bar |
|---|---|---|
| `podman build` (arm64, cached layers) | 18.8 s | not a bar; a cold build was not measured |
| Upgrade, v0.2.1 to the branch, whole `bin/upgrade-smoke` (local arm64, podman, images already pulled) | 26.7 s wall, 25 s printed | proof limit 600 s (AC-7.4): met |
| Backup-leg run, `sha-4cd1ef5` to the branch (26 tables, restore leg included) | 37.7 s wall, 36 s printed | proof limit 600 s: met |
| Failed pull, nonexistent repository | 0.7 s | one attempt, no retry |
| `Set up Ruby for the upgrade proof`, arm64 and amd64 | owed to the PR's first run | none |
| `Upgrade smoke test`, arm64 and amd64 | owed to the PR's first run | none |
| Added to the `image` job per architecture (their sum) | owed to the PR's first run | under 5 minutes (decision 8, AC-7.4): measured there, not here |

The per-step times are not printed by the harness (the `==` lines carry none), so only the totals are recorded. Local runs had the previous images in the local store, so the pull step was close to 0 s; a CI run pulls the previous image and installs the bundle. They say nothing about the 5-minute bar.

## Documents read

Read on 2026-10-24 at `7707a54`:

| Criterion | What was read / checked |
|---|---|
| AC-9.1 | `docs/releasing.md`. Step 1 carries the release step of decision 9: on `main`, `git mv script/upgrade/seeds/next.rb script/upgrade/seeds/<version>.rb`, rename the `next` key of `script/upgrade/seed_exceptions.yml` to the version, add a new `next.rb` and a `next` key where needed, commit and push before tagging, with the reason (the tagged commit's own run still uses the previous release's seed). Step 3 says to read the `Upgrade smoke test` step of both `Image` jobs in the tag's run, that a failure means nothing was published, to cut the next patch or pre-release, and never to move, reuse or delete the failed tag. Step 4 (the export restore) is unchanged in meaning. Step 5 keeps the real backup restore for a release that changes the schema, the backup or the restore, and now says CI already proves the seeded upgrade and, once a release has the backup commands, the backup restore, so it asks only for what no seed imitates (decision 9's "releases that touch import, export, the schema, the backup or the restore" is covered by steps 4 and 5 together). Step 7 deletes the expected-change entries whose migration the tag contains. "Upgrade notes" has the first entry "Upgrade proof (spec 031)": no migration, nothing required of the operator. |
| AC-9.2 | `CLAUDE.md`: the Commands list has `Upgrade smoke: bin/upgrade-smoke <previous\|auto> <current>` with the `ruby script/upgrade/guard.rb` `bin/ci` step; the "Release and deploy" fact lists spec 031 and points to the area doc without restating it. `docs/architecture/release-and-deploy.md`: the sources and scope list the proof and its files (line 17); the rules say a released migration is never edited, deleted or renamed and where the seeds and `expected_changes.yml` are (line 56), the proof's place in the `image` job (57), the full-history checkout (58); the constants table has the 12-minute step timeout, the 600 s proof limit, the stop grace, the pull attempts and the boot wait with file and line; the backup leg's allowance (213); spec 031 is in the area's source list. `.claude/rules/sqlite-and-migrations.md` points to the guard and the proof. |
| AC-9.3 | `docs/specs/README.md`: spec 031's row exists, its Supersedes column reads "030 decision 14 and AC-5.7, the newer-image leg: automated where the previous release has the backup task. Delivers the proof 030 left owed to #42"; spec 030's Superseded by cell reads "decision 14 and AC-5.7, the newer-image leg: 031 (decision 7)". `git diff --stat main -- docs/specs/030-backup-restore` is empty, so spec 030's own files are not edited. |

Not checked by reading: that the area doc's line numbers (for example `ci.yml:136-138`, `harness.rb:41`) still match after any later edit; they match `7707a54` for `ci.yml:137` (`timeout-minutes: 12`) and `harness.rb:41` (`timeout: 600`), which I looked at.

## Deviations and rulings

1. **Test-side plan bugs fixed in Phases 3, 5, 6 and 7.** The plan's example code for those phases had errors that the specs exposed; each was fixed on the test side in its phase and none changed the spec's behaviour. The phase commits (`d252aac`, `4505957`, `1b97fc9`, `1e9e7e6`) do not itemise them, so this document does not either.
2. **A real bug, not a test fault: `Harness#clean_up` and the name `it` (Phase 7).** The coordinator's notes record a shadowing of `it` in the harness's `clean_up`, found and fixed in Phase 7. The final `clean_up` (`script/upgrade/harness.rb:446`) is plain `each` blocks with named variables, and harness_spec "removes every container, volume and the scratch directory on success and on failure (AC-7.3, FR-6)" passes; the exact original defect is not restated here because the commits do not describe it.
3. **The 403 pull failure was not permanent (found by the hand run; `be91d28`, `7707a54`).** ghcr.io answers `403 Forbidden` at the token step both for a repository that does not exist and for a stored credential without `read:packages`. `PERMANENT_PULL_FAILURE` did not include it, so the harness retried three times (about 17 s) before failing. Fixed test-first: `be91d28` adds the failing example (harness_spec "does not retry the 403 …"), `7707a54` adds `403 Forbidden` to the pattern. Run 3 above is the check on the final code. Ruling: a 403 is a permanent pull failure — neither a missing repository nor a credential without access heals on retry, and rate limiting is 429 or 5xx — cost if wrong: a registry that answers 403 transiently would fail the step one attempt early, which is low.
4. **The local ghcr login note.** This machine's stored `ghcr.io` podman login uses a token without `read:packages`, which makes even public pulls fail with 403. Every hand run above used an empty `REGISTRY_AUTH_FILE` (`{}`), which pulls anonymously. In CI the pull is anonymous (AC-1.6), so this does not apply there. The failure message quotes the 403 but does not name this cause. Ruling: not changed here (the criterion asks for the tag, platform and registry's answer, which it gives); a hint line for `403 Forbidden` is open to the maintainer — cost if not added: a self-hoster with a stale login on a developer machine reads the 403 and has to find `podman logout ghcr.io` themselves.
5. **Engine assumptions of research.md section 6.** Confirmed on podman: `inspect --format '{{.State.Running}} {{.State.ExitCode}}'` works; a clean stop within 30 s exits 0 or 143 (the stop step passed in runs 1 and 2; the exact code is not printed); rootless id mapping lets `chmod -R a+rwX` make the copied-out files readable (the snapshot and compare read them); recurring-task registration appeared within the wait; the permanent-failure wording of a missing tag matches (`manifest unknown`), and of a missing repository did not (item 3). Left for Docker and CI: the same `inspect` format, the exit code of a stop, the file permissions after `cp` on Docker (the CI runners' engine), the `docker pull --platform` wording for a missing manifest, and `ruby/setup-ruby` with job-level `BUNDLE_WITHOUT`.
6. **Security scanner note.** The review tooling flagged `uses: ruby/setup-ruby@v1` as unpinned. Every other action in `ci.yml` is referenced by a major-version tag in the same way, so the new step is left consistent with them; pinning all of them by commit is a separate decision. Ruling: leave `@v1` — one convention across the file, and the step has no secret and no new permission (AC-1.6) — cost if wrong: a compromised tag of that action would run in the `image` job, as it would for the existing ones.
7. **The image under test and the printed commit.** The image was built from a fresh archive of `7707a54`, the same commit the harness prints, so for this phase the two agree. (In the earlier hand run the image came from `d7d673d` and the commit printed was a later one; that is why this phase rebuilt.)
8. **Process.** A first `bin/ci` was started from a background subshell that outlived its tool call, and a second run started while it was still going; the collision made 359 examples fail with `database is locked` on the shared test database. Those failures are not defects; the clean re-run above is the evidence.

## Owed

1. **CI evidence from the pull request's first run, on both architectures** (nothing is pushed, so none exists): that `ruby/setup-ruby@v1` with `bundler-cache: true` works with the job-level `BUNDLE_WITHOUT: development:test` and the job's full-history checkout; that the arm64 bundle install succeeds; the duration of `Set up Ruby for the upgrade proof` (cache hit or not) and of `Upgrade smoke test` per architecture, their sum as "added to the job", and whether the 5-minute target is met (the maintainer rules if it is missed, decision 8; the first levers are the stop grace, the Ruby setup's cache and the three seed boots); the printed table of 19 tables and `OK: v0.2.1` in both jobs; the Docker-specific assumptions of deviation 5; the `ci` job's guard step with the fetched history. Record them here in the pull request.
2. **AC-7.2's deliberately failing tag is the maintainer's** (a tag on the public repository is outward-facing, and a wrongly passing run would publish an image). Recipe, from plan Phase 11: on a throwaway branch from this one add `db/migrate/20261201000001_delete_a_seeded_lot.rb` (`def up = execute("DELETE FROM lots WHERE id = (SELECT min(id) FROM lots)")`, an empty `down`), push the branch and open a draft pull request from it (a pushed branch alone runs nothing), check that the `ci` job passes and the `image` jobs fail only at `Upgrade smoke test`, then tag that commit `v0.2.2-throwaway.1` (its previous release is `v0.2.1`; a tag below 0.2.1 would find none and pass). Confirm that `Publish manifest list` did not run and `ghcr.io/plainprogrammer/collector:0.2.2-throwaway.1` does not exist; delete the tag locally and on the remote, and the branch. Spec 013's cleanup removes the orphaned untagged digest. Record the run URL and the outcome here.
3. **The backup leg in CI.** It is exercised by hand only (run 2); it runs in CI from the first release that has `backup:create` (decision 7), so no CI run shows it until then.
4. **The NAS restores** of the maintainer's own export and backup (decision 9) are not owed by this spec; they stay release steps 4 and 5.
5. **The implementation review** (`sdd-review` Mode B) is run by the coordinator and recorded after this file's content, under its own heading, not by this phase.

## Implementation review

SPEC-ALIGNED (independent Sonnet review 2026-10-24, after fixes)

Reviewer: Sonnet 5.5, read-only, at `7a01af3`: NEEDS FIXES, 0 critical, 1 major, 9 minor, behaviour spec-aligned (AC-by-AC traceability table in the review). All findings were fixed or ruled as below, one commit each, test first where a test could fail first.

### Findings

| Finding | Outcome | Commit |
|---|---|---|
| M1 `vendor/bundle` in the pushed image's build context | Fixed: `/vendor/bundle` in `.dockerignore`; files_spec example "keeps the runner's bundle out of the image build context"; area doc's "image carries only what it runs" line names it | `11c65f3` |
| m1 area doc named `Upgrade::Rules::RESTORE_ENDS_SESSIONS` | Fixed: `Upgrade::ExpectedChanges::RESTORE_ENDS_SESSIONS` (no other mention in the docs or the plan) | `19854ff` |
| m2 "tags not fetched" decided by release-shaped tags | Fixed: `Release#previous` tests `git tag --list` for emptiness; the message says to fetch from the repository that publishes releases (`git fetch <upstream> --tags`); release_spec examples for the message and for a remote with only a non-release tag (passes as "no previous release") | `406b3ea` |
| m3 AC-5.2 empty-collection half too weak | Fixed: the page must carry `c-empty` (`EMPTY_COLLECTION_MARKER`); harness_spec example with a 200 error page | `99b5e5e` |
| m4 AC-6.4 failure half had no example | Added: the task is listed and `backup:create` fails, so exit 1 and no "skipped" line. The behaviour was already structural, so this example passed when written | `bfe0978` |
| m5 cleanup not run on SIGTERM | Fixed: `Harness#call` traps TERM to raise `Interrupt` so `ensure` cleans up, then restores the previous handler; harness_spec example (red first) | `53c0e14` |
| m6 spec forbade any seed exception | Replaced by a shape check (every key `next` or `X.Y.Z`; `SeedExceptions.load` has no errors; each entry has a table and a reason) | `2c63286` |
| m7 `ruby/setup-ruby@v1` | Fixed as ruled: the step moved above "Log in to GHCR" (files_spec example for the order); area doc line citations to `ci.yml` shifted with it. Not pinned: repo-wide SHA pinning is issue #132 | `911285c` |
| m8 index and Distillation log row still pre-distill | Not taken, as ruled: the coordinator runs `distill-feature` before the PR, which marks the index and fills the log row | none |
| m9 modified `Gemfile.lock` | Not taken: local arm64 platform noise, left uncommitted | none |

### Rulings (maintainer, 2026-10-24)

- M1: exclude `/vendor/bundle` in `.dockerignore` (not a separate job), with a guard in files_spec.
- m7: move the Ruby setup above the GHCR login; don't pin here (#132).
- m2: "tags not fetched" means no tag at all with a remote; the message names upstream.
- m6: shape check, not "no exceptions".
- Review question 5: `distill-feature` marks the index and the log row.

### bin/ci

Run in this worktree on `2c63286` (alone, `Gemfile.lock` uncommitted):

```
✅ Tests: RSpec passed in 3m0.41s
2138 examples, 0 failures, 1 pending   (art_agreement_spec.rb:16, not this feature's)
✅ Continuous Integration passed in 3m10.73s
```

`bin/upgrade-smoke` was not re-run: none of the fixes changed the harness's container steps (the SIGTERM trap and the page check are not exercised by a container).

### Only the pull request's first CI run can show

- Both-architecture timings of `Set up Ruby for the upgrade proof` and `Upgrade smoke test`, and the 5-minute bar.
- `ruby/setup-ruby@v1` with `bundler-cache: true` and job-level `BUNDLE_WITHOUT`; the arm64 bundle install; the step's new position (before the login and the build).
- Docker-only assumptions: exit code of `docker stop`, `inspect` format, file modes after `cp`, the missing-platform pull wording.
- That `/vendor/bundle` is absent from the pushed image (visible on a `main` or tag run: the `COPY . .` cache line of "Push by digest" should hit, and the image should hold no `/rails/vendor/bundle`).
- The anonymous pull from a fork PR; AC-7.2's failing tag (maintainer); the backup leg in CI.

## Distillation

`distill-feature` ran on 2026-10-24 before the pull request. The release and deploy area doc already held what spec 031 established (the upgrade proof, the migration guard in `bin/ci`, the image job step and the release steps; Phase 10); the distillation filled its log row and marked the spec Frozen, by release and deploy, in the index, with its plan's retirement owed (the plan is retired after the merge), and added the spec's frozen line (spec 027 D4). The supersessions of spec 030 (decision 14 and AC-5.7, in part) were already recorded in both directions.
