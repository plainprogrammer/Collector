# Research: Prove an Upgrade from the Previous Release in CI

Read-only traces made while planning (spec 031 1.1.1, branch `031-upgrade-from-previous-release`). The release side is `git show v0.2.1:…`; the code-under-test side is `87d89e3` (the spec's approval commit, on `543d554`, on `main`'s 030 merge `4942287`). The only network use was read-only `curl` against the public registry for the manifest and image config of `ghcr.io/plainprogrammer/collector:0.2.1`. Nothing was run and no image was pulled: plans here aren't executed before approval. Section 6 lists what the first failing test or hand run of each phase confirms.

## 1. The previous release, as it is today

- Tags: `v0.1.0`, `v0.2.0`, `v0.2.1`, all stable. `ghcr.io/plainprogrammer/collector:0.2.1` is an OCI image index with exactly two manifests, `linux/arm64` and `linux/amd64`, no attestations (`provenance: false`, `sbom: false`, spec 012). Its config labels: `org.opencontainers.image.version` = `0.2.1`, `org.opencontainers.image.revision` = `126658074684b2ea20e63a103b6051de3aec9906`, plus created, description, licences, source, title, url. Entrypoint `/rails/bin/docker-entrypoint`, cmd `./bin/thrust ./bin/rails server`, user `1000:1000`, no `StopSignal` (so `SIGTERM`).
- So AC-1.3's digest and revision are readable from `image inspect` (`RepoDigests`, `Config.Labels`, which Docker and Podman both return as a JSON array when no `--format` is given), and the label gives the version for a hand run (decision 2).
- `bin/docker-entrypoint` is unchanged between `v0.2.1` and `main` (it is absent from the diffstat of `git diff v0.2.1 HEAD`), runs `db:prepare` only for `./bin/rails server`, and `exec`s the rest. `bin/rails runner` and `bin/rails -T` therefore skip it.
- `v0.2.1` has 14 migration files, `main` 20; the six added are all additive (section 4). `v0.2.1` has no backup tasks (`lib/collector/backup/` is new in 030) and no `locations` table.
- `config/recurring.yml` (production) at `v0.2.1`: `clear_solid_queue_finished_jobs`, `refresh_mtg_catalog` (Mondays 3:15); `main` adds `sweep_import_uploads` (every 15 minutes). The recurring check (AC-5.6) reads the file from the **code under test**, as `bin/backup-smoke` does, so it expects three tasks on `main`.

## 2. Mechanics the harness relies on

1. **Quote-based digests.** `quote(x)` renders `1` as `1`, `'1'` as `'1'`, `NULL` as `NULL`, `''` as `''`, a blob as `X'…'`; a text value always begins and ends with `'`, a number with a digit or `-`, so the unit separator `\x1f` between quoted values cannot be produced at a value boundary (decision 5). A column declared without a type (`CREATE TABLE t (v)`) keeps `1` and `'1'` apart, which the digest spec uses.
2. **Tables to skip.** `sqlite_master` lists SQLite's own `sqlite_sequence` (Rails' SQLite adapter creates `AUTOINCREMENT` keys) and the FTS5 virtual table `catalog_names_fts` (`content='catalog_names'`) with its shadow tables `catalog_names_fts_data`, `_idx`, `_docsize`, `_config` (no `_content`: the table is external-content). Those are SQLite's machinery for `catalog_names` and hold rows only after `INSERT INTO catalog_names_fts (catalog_names_fts) VALUES ('rebuild')`. The comparer skips a virtual table and every table named `<virtual>_*`; `catalog_names` (the real table) is compared and covered. Spec 030's research (section 3) records the same table and its `VACUUM INTO` behaviour.
3. **Consolidated snapshots.** A WAL database's `-wal` is folded in on open. `Snapshot.consolidate` copies the main file with any `-wal`/`-shm` into a scratch directory the harness owns, opens the copy with `SQLite3::Database` (never Active Record, which would force WAL, spec 030 research section 4) and runs `VACUUM INTO ?` onto a path that does not exist. The sqlite3 gem is 2.10.0 (precompiled, with FTS5).
4. **Stopping.** `stop -t 30` sends `SIGTERM`, waits 30 s, then `SIGKILL`; Thruster forwards the signal to Puma, which stops Solid Queue's supervisor. A clean stop is exit 0 or 143; 137 means the grace period ran out (AC-2.4).
5. **A migration that raises** stops the entrypoint (`#!/bin/bash -e`), so the container exits non-zero before Puma starts. Rails prints `== 20261021100001 CreateLocations: migrating ====…` before running a migration, so the last such line in the log names it (AC-3.3).
6. **`bin/rails runner -`** evaluates standard input: `railties-8.1.4/lib/rails/commands/runner/runner_command.rb` (`perform`: `if code_or_file == "-"` → `eval($stdin.read, TOPLEVEL_BINDING, "stdin")`, inside the Rails executor). `v0.2.1` locks the same railties (read from its `Gemfile.lock`), so a seed can be sent on standard input to either image: no bind mount (no SELinux label problem on a Fedora dev machine) and no `container cp`. A seed is therefore plain top-level code with no constants (an `eval` at the top level is run once per container, and the spec that `load`s `next.rb` runs it many times in one process).
7. **Port and readiness** follow `bin/backup-smoke`: `-p 127.0.0.1::8080`, `port NAME 8080`, poll `/up` every 2 s, `SMOKE_BOOT_ATTEMPTS` (default 60).
8. **Sign-in** needs the CSRF token from `/session/new` (`<meta name="csrf-token" content="…" />`), a cookie jar, `email_address` and `password` fields; success is 302/303. `SessionsController` rate-limits to 10 creates per 3 minutes per client, and the harness signs in four times in a run (two collectors, twice at most in the backup leg only after a fresh boot).
9. **The sign-up page** shows the field `user[email_address]` only when sign-up is open (`Registration.open?`: no user, or `InstanceSetting.sign_up_open?`); else the closed notice, both with status 200 (AC-5.3).
10. **The collection page** (`CollectionsController#show`, grid view by default, 120 tiles per page, one per owned printing) lists a collector's printings; the seed keeps the collector with lots to 50 printings so one page shows every name. A `view=` parameter would write `users.collection_view`, so the harness never sends one (it is after the snapshot anyway). `GET /collection/export` is `send_data export.to_json` (an attachment); `GET /locations` lists names.
11. **User model at `v0.2.1`:** `User::Command.call(email:, password:)` makes an admin and closes sign-up on the first run; further users are made with `User.create!(name:, email_address:, password:)` (an account is built for them). `users.account_id` is unique, so one user per account. `Session` rows are made with `user.sessions.create!`.

## 3. How each table is filled

`v0.2.1` (19 tables; schema read with `git show v0.2.1:db/schema.rb`), every one through the release's models, in the seed's order:

| Table | Filled by |
|---|---|
| `instance_settings` | `InstanceSetting.current.update!(sign_up_open: true)` after the first user closed it |
| `accounts`, `users` | `User::Command.call` (first, admin), then `User.create!` for the second collector |
| `sessions` | `user.sessions.create!(ip_address:, user_agent:)` for each |
| `catalog_sets`, `catalog_identities`, `catalog_entries` | `create!` with `content_digest: "upgrade-seed"`, 2 sets, 50 identities, 50 entries (`kind: "card"`) |
| `mtg_cards`, `mtg_printings` | `MTG::Card.create!`, `MTG::Printing.create!(finishes: %w[nonfoil foil], faces: …)` |
| `catalog_names` (and `catalog_names_fts`) | `Catalog::NameIndex.new("mtg").rebuild` |
| `lots` | 2,000 rows by `Lot.insert_all` with `Lot.key_for` (50 printings × 2 finishes × 5 conditions × 4 prices), plus the scanner's lot |
| `scanner_sittings`, `scanner_sitting_entries` | `Scanner::Sitting.add!(account:, printing:, finish:, reading_key:)` |
| `bulk_selections`, `bulk_selection_marks`, `bulk_removals` | `BulkSelection.for(session)`, `marks.create!(lot:, account:)`, `BulkRemoval.create!(session:, account:, copies:, lots_data:)` (not `remove!`, which would delete lots) |
| `catalog_refresh_runs` | `Catalog::RefreshRun.create!(…, status: "applied", …)` (never `running`: the stall rules would act on it) |
| `mtg_art_builds`, `mtg_artworks` | `MTG::ArtBuild.create!(status: "finished", …)`, `MTG::Artwork.create!(fingerprint: 128 bytes, …)` |

No table of `v0.2.1` needs an exception, so `seed_exceptions.yml` ships empty (the art tables can be written directly, `MTG::Artwork` only validates a 128-byte fingerprint).

`main` adds seven tables, which `next.rb` fills: `locations` (`Location.create!`), `number_entries` and `number_entry_lines` (`NumberEntry.add!`), `import_uploads` with `active_storage_blobs` and `active_storage_attachments` (`ImportUpload.store!` with a stand-in plan object that answers `fingerprint`), and `active_storage_variant_records` (`ActiveStorage::VariantRecord.create!`). The FTS shadow tables are skipped (section 2). The spec's test database also holds Solid Queue's tables (`CLAUDE.md`), so the in-suite coverage check restricts itself to the tables `db/schema.rb` creates.

## 4. What the six new migrations do to existing rows

`20261009100001_add_progress_to_catalog_refresh_runs` adds five nullable columns to `catalog_refresh_runs`; the other five create tables. Nothing deletes, rewrites or backfills a row, so the comparer (which looks only at columns both databases have) finds no difference and `expected_changes.yml` ships as `changes: []`. The same holds for `AddProgressToCatalogRefreshRuns`'s SQLite form: Rails may rebuild the table to add a column, which keeps rows, ids and values (the digest is over column values in name order, not storage order).

## 5. Rulings the plan makes where the spec leaves room

| # | Ruling | Why |
|---|---|---|
| P1 | The harness is Ruby (`bin/upgrade-smoke` is a small Ruby launcher, the code is `script/upgrade/*.rb`), not bash like `bin/backup-smoke`. | The comparer must be Ruby (host Ruby, decision 5), AC-8.3's command list is enforced in one place, and the orchestration can be run against a fake engine in `bin/rspec` (AC-8.6, FR-7): the pull retries, the fail-closed cases, the skip and the cleanup are tested without an engine. Bash would test none of them. |
| P2 | `<previous>` may be `auto`. The image job passes `auto collector:smoke`; the hand run passes an image. | The spec's `bin/upgrade-smoke <previous-image> <current-image>` stays true for the hand run. The workflow cannot choose between "pass" and "run" without a step that resolves the release first, and "no previous release" must pass without a container (AC-1.2); one resolver called from the script keeps `bin/ci` and the job in agreement (AC-1.7). |
| P3 | The backup leg does **not** reuse `bin/backup-smoke`; it shares nothing with it but its approach (a one-off restore, a different `SECRET_KEY_BASE`). `bin/backup-smoke`'s header line "issue #42 reuses this" is reworded. | `bin/backup-smoke` seeds its own fixture, restores two ways, and asserts counts of 1; the leg must restore the harness's seed and run the shared comparison and behaviour checks. Calling it would double the boots and could not run the comparison. Decision 7 left the choice to the plan. |
| P4 | In the backup leg, `sessions`, `bulk_removals`, `bulk_selections` and `bulk_selection_marks` are compared as "emptied by the restore" (`Upgrade::ExpectedChanges.restore_effects`: the old rows are expected gone and the new tables must hold 0 rows); every other table must pass unchanged. **Needs the maintainer's nod.** | AC-6.2 says the restored database "passes the comparison of Story 4", but spec 030 requires `backup:restore` to end every session, which cascades to those four tables (`lib/collector/backup/restore.rb`, `docs/backup-restore.md`). Taken literally the leg could never pass. The allowance is a constant, not an `expected_changes.yml` entry, because no migration makes it. It does not touch the plain upgrade comparison. |
| P5 | Virtual tables and their shadow tables are outside the comparison and the coverage rule (section 2). | Decision 5 excludes "SQLite's own tables"; the shadow tables are that, and `catalog_names` stands for them. |
| P6 | `next.rb` is also run in `bin/rspec` against the test database, with the coverage rule applied (Phase 5). | AC-2.6 is checked in the image job; running it in the suite finds a missing table earlier, in `bin/ci`, on every push, without an engine (FR-7). The image job still runs it on a fresh instance of the real image. |
| P7 | The seed prints `UPGRADE-SEED-COMPLETE <json>` and the harness reads the credentials, names, lot count, locations and marker from it. | One source of truth: the seeds are per release and the harness must work with all of them. |
| P8 | The seed's facts (AC-2.3) are also read back from the old snapshot (`Compare.seed_problems`). | A seed that "completes" with the wrong data is caught as AC-2.8 intends. |
| P9 | **No ADR.** | The choice of the real image over a fixture is recorded in the spec's decision 4 and this plan, as the spec says. The plan changes no way a release is cut or published beyond decision 9 (two renames before the tag, one deletion after), so the spec's own test for an ADR is not met. Spec 032's expected ADR 0025 and #103's are unaffected. |
| P10 | `BUNDLE_WITHOUT=development:test` on the image job's Ruby setup. | The harness needs `sqlite3` and `json_schemer` (default group). Skipping the groups shortens an uncached install on the arm64 runner, which has never run a bundle install in this repository's workflow. Verified by the first run's timing; the fallback is the full bundle. |

## 6. Assumptions the first execution confirms (each with its fallback)

| Assumption | Confirmed by | If false |
|---|---|---|
| `docker/podman inspect --format '{{.State.Running}} {{.State.ExitCode}}'` works on both | Phase 7's hand run (podman, this machine) and the first CI run (docker) | Parse `inspect` JSON in Ruby, as `image inspect` does |
| `ruby/setup-ruby` with `bundler-cache: true` accepts `BUNDLE_WITHOUT` in the step's `env` and the lockfile's platforms include `aarch64-linux` (they do: `Gemfile.lock` PLATFORMS) | Phase 9's first CI run | Drop `BUNDLE_WITHOUT` and cache the full bundle |
| `docker pull` says `manifest unknown` / `not found` / `no matching manifest` for the permanent failures | The `pull` classification spec runs on canned messages; the real wording is read from the first deliberate failure (hand run with a missing tag) | Extend the permanent-failure patterns |
| A clean stop within 30 s exits 0 or 143 | Phase 7's hand run | Raise the grace period; AC-2.4 keeps failing on 137 |
| The recurring-task registration (AC-5.6) appears within 60 s of `/up` | `bin/backup-smoke` does the same wait (30 × 2 s) | Lengthen the wait |
| Podman's rootless id mapping lets `chmod -R a+rwX` make the copied-out files readable to the invoking user | Phase 7's hand run | Copy the files with `container cp` from a stopped holder container, as `bin/backup-smoke` does |

## 7. Risks

- **A recurring job fires inside the run.** `refresh_mtg_catalog` (Mondays 3:15) would call out and add a `catalog_refresh_runs` row during the upgrade boot, failing the comparison with `rows_added`. The window is a few minutes a week; the failure message names the table, and a re-run clears it. Not mitigated by a setting, because the upgrade must run with "the same settings" (AC-3.1).
- **First arm64 bundle install.** The `ci` job runs only on amd64. P10's timing is measured at the first run.
- **`docker pull` rate limits** do not apply to `ghcr.io`; an outage is the retry path (AC-1.5).
- **The comparer's cost** is linear in rows: 26 tables, about 2,200 lots and a few hundred other rows, under a second. The 50,000-lot instance is the maintainer's manual check (decision 9).

## 8. Guidance for spec 032 (#45, a lot in a location) and later specs

Spec 032 changes the lot model and the export format. Nothing in this plan's seeds or comparisons assumes either: the export check reads `format_version` from the response and validates against `app/models/export_format/v<N>.schema.json` of the same checkout, and counts the `lots` list; `0.2.1.rb` is frozen and never changes.

When a later migration lands, in the same pull request:

| The migration… | Do |
|---|---|
| adds a nullable column to an existing table | Nothing. A column only the new table has is not compared. |
| adds a table | Fill it in `seeds/next.rb` (the in-suite coverage example and the image job's AC-2.6 fail until you do), or list it under `next:` in `seed_exceptions.yml` with a reason. |
| drops a column or table, or removes rows | An `expected_changes.yml` entry (`dropped`, `rows_removed`) with the migration's version and a reason that names the spec. |
| rewrites or backfills values or rows of an existing table (for example a new `lots.lot_key` that includes a location) | `rewritten` (with `column`) or `rows_added`/`rows_removed` entries. |
| changes `Lot.key_for` or what `Lot.add!` needs | Update `next.rb`, which builds its lots with `Lot.insert_all` and `Lot.key_for` (the model's own key rule) and `Lot.add!`; place a lot in a location through the new API so the new column holds data. |
| changes `Location` | `next.rb` creates locations with `Location.create!(account:, name:)`; keep that working or update it. |
| changes the export format | Nothing in the harness; the document and schema checks stay where they are (spec 017). |

An entry's migration is retired automatically the moment a release containing it is the previous release; delete retired entries after tagging (decision 9). Spec 032's seed for the release that ships it is `next.rb` renamed at tagging, so it must already run on 032's code: the coverage example in `bin/rspec` shows that on every push.

## 9. What this research did not settle

- Real wall-clock times: the bars are measured in Phase 7's hand run and the first CI run (AC-7.4); the plan estimates 2.5 to 3.5 minutes added per architecture from `bin/backup-smoke`'s timings in spec 030's `verification.md` (backup 1.7 s and restore 1.8 s on a 121 MB seed; boot time was not recorded there, so Phase 7 measures it) plus one image pull, five boots and the Ruby setup.
- The deliberately failing pre-release tag (AC-7.2) and the NAS checks stay with the maintainer.
