# Spec review (Mode A): 030 Back Up and Restore an Instance

**Reviewed:** spec version 1.0.0 (commit `5358a2e`), 2026-10-21, by a read-only Opus subagent, as the project default. It checked the spec's factual claims against the code.
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
