# Plan review: spec 030 (back up and restore an instance)

**Plan reviewed:** commit `40cec8a` (`plan.md`, `contracts/`, `data-model.md`, `research.md`, ADR 0024), against spec 1.2.1.
**Review:** one independent, read-only review (Opus, 2026-10-21), **NEEDS REVISION**: 1 critical (C1), 3 major (M1 to M3), 13 minor (m1 to m13). Nothing was run: the review traced the plan against the files it edits and the gems (`bundle show`: railties, activerecord, activestorage and activesupport 8.1.4; sqlite3 2.10.0; kamal 2.12.0). This revision was traced the same way; I re-read the cited lines for C1, M1 and M2 and the gems for the new code (`Rake::Task#all_prerequisite_tasks`, `SQLite3::IOException`, `database.yml`'s flat test configuration) before writing the fixes.
**Revision:** `59c334d` (plan, contracts, research) and `6ae2941` (ADR 0024). ADR 0024 stays **Proposed**. The revised plan has not been reviewed again.

All 17 findings are resolved: 13 as the review proposed, 4 as the maintainer ruled (m3, m5, m6, m7). None is rejected. One defect the review didn't list turned up while tracing the fixes (row 18).

## Maintainer rulings of 2026-10-21 applied

1. **m3:** follow FR-2's order. The room is checked as soon as the manifest is parsed, inside `Archive.read`'s first pass (a callback), before the checksum.
2. **m5:** the Kamal backups volume stays commented out in `config/deploy.yml`, with the `backup` alias live; the documents tell the operator to create the host directory owned by uid 1000 (`install -d -o 1000 -g 1000 …`) and then uncomment the volume. This is the reading of decision 4's "stated addition".
3. **m6:** the plan's construction for AC-3.6 (seed, back up, roll back the newest migration) is accepted; `verification.md` carries a note with the reason. No spec change.
4. **m7:** the decision 13 measurement runs against a seeded database outside `storage/` (under `tmp/`), so no step needs the maintainer and no agent reads `storage/`. It gates on at least 50,000 unretired catalog entries and records the real counts, times a write without bcrypt's cost, and says in the plan and in `verification.md` that the numbers come from a seeded database, not the maintainer's instance.

## What changes for the maintainer to know

- **M1 changes how the D4 confirmation is evidenced.** The ruling stands (the tasks read no `secret_key_base`; the dummy is enough for a boot), but a production boot with a wrong `RAILS_MASTER_KEY` can't show it: `config/storage.yml`'s commented ERB reads credentials on boot, so every such boot raises `InvalidMessage` first. The boot examples now run with no key and are skipped where `config/master.key` exists, so the evidence is the structural example (neither task depends on `:environment`), the two task examples, and the boot examples run in CI or the image, where there is no key. `verification.md` cites the run.
- **m3 has a residue.** A file cut short after its manifest is told apart only by reading it to its end, which comes after the room check. So a cut-short file on a volume without room is refused for the room. Every other pair of FR-2's checks is in FR-2's order. The contracts and `verification.md` say so.

## Resolutions

| # | Finding | Resolution |
|---|---|---|
| 1 | **C1** `Create#read_back` calls `Archive.read` on the `.partial` archive, which refuses any `.partial` name, so no backup succeeds | **Resolved** (`59c334d`). `Archive.read(path, allow_partial: false, on_manifest: nil)`; the `.partial` check stays where FR-2 puts it (after the first entry) and is skipped only for `allow_partial: true`, which `Create#read_back` passes. New `archive_spec` examples: an intact `.partial` reads with the option; a cut-short one is still incomplete with it; the default still refuses. Contracts/archive.md states it. |
| 2 | **M1** the D4 boot spec's wrong `RAILS_MASTER_KEY` makes every production boot raise `InvalidMessage` | **Resolved** (`59c334d`). The two task examples keep the wrong key. The control and the dummy example run with no key (`"RAILS_MASTER_KEY" => nil`) and skip with the reason when `config/master.key` exists (an existence test reads nothing). The control's regex is `/secret_key_base/`. A new in-process example asserts `all_prerequisite_tasks` of both tasks exclude `environment`. Traced: `storage.yml:12-13`, `configuration_file.rb:21`, `active_storage/engine.rb:180-188`, `encrypted_configuration.rb:62-66`, `active_record/railtie.rb:361-366`. research.md §1 gains the finding; the D4 section of the plan and Phase 5's verification say the evidence rests on the structure plus the CI run; research.md §8 gains a row for the control boot's first run. |
| 3 | **M2** Phase 0's guard `config.active_record.encryption` is not blank under `load_defaults 8.1` | **Resolved** (`59c334d`). The example checks what AC-4.3 names: no model has `encrypted_attributes`, no `encrypts` line in `app/**/*.rb`, and `config.active_record.encryption.to_h.slice(:primary_key, :deterministic_key, :key_derivation_salt)` is empty. Confirmed at `railties-8.1.4/…/configuration.rb:288-289`. Credentials are never read. |
| 4 | **M3** an unreadable input file or unwritable volume ends in `Errno::EACCES` and a backtrace | **Resolved** (`59c334d`). `Restore#call` refuses a file the user can't read ("<path> can't be read by the user Collector runs as (uid n).") and a volume it can't write, before reading or writing anything; `Backup.run` gains a last rescue for `SystemCallError` and `SQLite3::Exception` that prints "The command stopped: <the error's words>." and a second line, exit 1, no class, no frames. New examples: `run_spec` (Phase 0; system and SQLite errors), two `restore_spec` examples skipped as root. Both refusals and the catch-all are rows in contracts/tasks.md; AC-3.8, FR-4 and the global constraint name them. |
| 5 | m1 `Snapshot#verify!` doesn't set `PRAGMA foreign_keys = ON` | **Resolved** (`59c334d`). `verify!` sets it (allowed on a read-only connection) with a comment; research.md §3 says why. |
| 6 | m2 `Create` verifies before converting to rollback-journal mode; the sweep can't remove `.partial` sidecars | **Resolved** (`59c334d`). `rollback_journal!` now runs before `verify!`; `PARTIAL` also matches `.partial-journal`, `-wal` and `-shm`; the sweep example gains old and young sidecars; contracts/archive.md and research.md §3 and §8 follow. |
| 7 | m3 (ruling) `Restore` checks the checksum before the room | **Resolved by ruling 1** (`59c334d`). `Archive.read(on_manifest:)` hands the parsed manifest of a known version to `Restore`, which refuses for room there; a new example has a corrupt snapshot and a full volume and expects the room refusal (and the checksum refusal when there is room); another shows the callback isn't called for a non-backup or an unknown version. Plan Requirement Map, choice 3, contracts and the README's check list follow. The residue is under "What changes". |
| 8 | m4 the Kamal restore's `scp` targets a directory a fresh host doesn't have | **Resolved** (`59c334d`). README step 7.2 runs `ssh … 'install -d -o 1000 -g 1000 /srv/collector-backups'` before the `scp`. |
| 9 | m5 (ruling) the Kamal volume is commented, not the "stated addition" | **Resolved by ruling 2** (`59c334d`). Choice 4 states the reading of decision 4; the README's Kamal backup section puts `install -d` first and then says to uncomment the line, with the reason; the `config/deploy.yml` comment says why it stays commented. The `image_publishing_spec` example is unchanged. |
| 10 | m6 (ruling) AC-3.6's older snapshot is built by rollback | **Resolved by ruling 3** (`59c334d`). Choice 5 records the acceptance; step 8.3 lists the AC-3.6 note (the criterion's wording, the plan's construction, the reason, the reversibility dependency) for `verification.md`. No spec change. |
| 11 | m7 (ruling) the measurement reads `storage/`; the catalog gate may refuse a valid catalog | **Resolved by ruling 4** (`59c334d`). `script/backup/measure.rb` seeds its own database under `tmp/measure` (`RAILS_ENV=test`, `DATABASE_URL`, `db:schema:load`; the test environment's only database is the primary), inserts `MEASURE_ENTRIES` printings (default 100,000), gates on at least 50,000 unretired entries, prints the real counts, and times `Lot.add!` writes with the account made before the clock starts (no bcrypt in the timing). Step 8.2 needs no one's help and requires the seeded-database sentence in `verification.md`. |
| 12 | m8 AC-1.3's second writer isn't the app's lot-add path | **Resolved** (`59c334d`). The writer calls `Lot.add!(account:, entry:)` (`app/models/lot.rb:24-34`). |
| 13 | m9 AC-1.2 is proven by `accounts == users` totals | **Resolved** (`59c334d`). A helper counts accounts without a user and users without an account in each snapshot; both must be 0. The totals check is replaced. |
| 14 | m10 step 6.1 says "the four new examples" but lists three | **Resolved** (`59c334d`): "three" in steps 6.1 and 6.6. |
| 15 | m11 research.md §8 says the library autoloads | **Resolved** (`59c334d`). The row says it is required by path everywhere and that `zeitwerk:check` passes because of the ignore; step 0.7 says the same. |
| 16 | m12 commits hard-code `Claude Sonnet 5.5` | **Resolved** (`59c334d`): "the executing model's attribution line (the one the session's system reminder gives)". |
| 17 | m13 wording drift ("renamed into place"; "with a negative control" for both guards) | **Resolved** (`59c334d`, `6ae2941`). ADR 0024 decision 3 and 4 say "linked", with the rename fallback noted; the plan's global constraints, Restore interface, the `docs/backup-restore.md` text and the contracts follow. The requirement map says the database guard is an exact match with no control. |
| 18 | *Found while tracing, not in the review:* `expect_refused`'s plain-sentence check is `/\A[A-Z].*\.\z/`, but most file-named refusals start with a file name (`collector-backup-….tar.gz is incomplete…`, `note.txt isn't a Collector backup.`), so every such example would fail | **Resolved** (`59c334d`). The check is `/\A\S.*\.\z/`, with a comment; the sentences still end in a full stop and carry no exception class or Ruby file name. |

## Not taken

None. Every finding was fixed as the review proposed or as the maintainer ruled.

## Notes for the executor

- Everything above was traced, not run. The first failing runs most likely to move something are in research.md §8: the control boot's message (`secret_key_base`), the sweep's sidecar pattern, and `Zeitwerk` with the ignore list.
- `spec/lib/collector/backup/run_spec.rb` is a new Phase 0 file; it uses `captured_streams` from the support layer.
- The two boot examples (control, dummy) are skipped on a machine with `config/master.key`; run them in CI or a clean checkout, and cite that run in `verification.md`.

## Second review (Sonnet, read-only, 2026-10-21)

**Verdict: APPROVE WITH NITS**: 0 critical, 0 major, 4 minor, all new. Every finding of the first review was confirmed fixed and the four rulings carried as written. The four nits are folded into the plan below.

| # | Nit | Resolution |
|---|---|---|
| N1 | The two boot examples (control, dummy) are skipped on a machine with `config/master.key`, so Phase 5's "green" for them is deferred to CI | **Folded in.** Phase 5's verification now says they first run in the first CI run, after Phase 6, and that an unexpected result there reopens research.md 8's row for the control boot rather than loosening the example. |
| N2 | The catch-all's second line says "Nothing was changed", which is false for an error after the database was placed (the directory fsync) | **Folded in.** The line is now "It left nothing half-made; check that …"; the `run_spec` example, `Backup.run`'s comment and contracts/tasks.md ("An error nothing names") follow. The refusals keep "Nothing was changed", which is true for them. |
| N3 | `expect_refused`'s `/\A\S.*\.\z/` accepts any non-space start | **Folded in.** The check keeps the capital rule and allows a path or a file name: `/\A(?:[A-Z]|\/|collector-backup-|[\w.-]+\.(?:gz|txt|json) ).*\.\z/`, full stop unchanged; its comment says so. |
| N4 | The m3 residue is wider than its wording and missing from the Requirement Map's FR-2 row and from choice 3 | **Folded in.** The FR-2 row, choice 3 and step 8.3's note name the wider set (cut short, wrong gzip CRC, trailing damage, a snapshot that doesn't match its checksum) refused for the room on a volume without one; `verification.md` carries the list. |

## Approval

The maintainer approved the plan on 2026-10-21 after its two reviews, with the four nits folded in, accepted ADR 0024, and chose Sonnet for execution. ADR 0024's Status changes to Accepted in Phase 8, step 8.5, where the plan puts it.
