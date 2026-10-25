# Feature 031: Prove an Upgrade from the Previous Release in CI

**Status:** Approved by the maintainer (2026-10-23), with rulings on decisions 1 to 10 (decisions 1 to 3 as ruled in 1.0.0; 4 to 10 confirmed as recommended); both Mode A reviews' findings fixed (version 1.1.1)
**Version:** 1.1.2
**Created:** 2026-10-23
**Last Updated:** 2026-10-24
**Branch:** `031-upgrade-from-previous-release`
**Issue:** [#42](https://github.com/plainprogrammer/Collector/issues/42)
**Plan:** [plan.md](plan.md)
**Frozen:** the current rules are in [`release-and-deploy.md`](../../architecture/release-and-deploy.md) (whole spec); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.1.2 | 2026-10-24 | The backup leg's restore allowance, ruled by the maintainer on 2026-10-24 (plan review, P4): spec 030's restore ends every session (its decision 3, AC-2.1, AC-2.4), and the database's foreign keys cascade that to `bulk_removals`, `bulk_selections` and `bulk_selection_marks`, so the restored database always differs from the old one in `sessions` and those three tables. Decision 6 (a last sentence), decision 7 and AC-6.2 name them as an allowance the comparison expects, and FR-4 points to it; nothing else is allowed. A reconciliation with spec 030, no change of intent (PATCH) |
| 1.1.1 | 2026-10-23 | Approved by the maintainer. Status and the Open Questions line only; no requirement, criterion or decision changes (PATCH) |
| 1.1.0 | 2026-10-23 | Revised after the second Mode A review (`review.md`, round 2), and the maintainer's rulings recorded: decisions 4 to 10 confirmed as recommended (ruled 2026-10-23). `next.rb` gets the coverage rule, with its exceptions under a `next` key that the release step renames (AC-2.6, decisions 5 and 9); both databases are read as a consolidated snapshot of a cleanly stopped copy, taken before any behaviour check (AC-2.4, AC-2.9, decision 5); the harness runs on a host Ruby set up in the image job (decision 5, AC-8.3, time bar); the hand run uses `--previous-ref` (decision 2, AC-6.5); AC-5.3 checks the sign-up form, not the status; spec 030's *Superseded by* cell recorded (AC-9.3); one resolver for the tag being built (AC-1.7); digest encoding, expected-change versions checked, step 5 only replaced, testable AC-5.7, the failing-tag test described, and the limit of a schema-loaded old database named |
| 1.0.1 | 2026-10-23 | Revised after the Mode A review (`review.md`): expected-change entries retire instead of failing after a tag; both checkouts fetch tags; helpers under `script/upgrade/`; seed fills sign-up open and the catalog directly; seed exceptions listed; `rows_added`; command allowlist (AC-8.3 replaces the ordering rule, which was wrong: Rails runs any pending version); backup leg proved by hand now (AC-6.5); supersession of 030 decision 14 recorded; pull credentials, publish gating and time-bar wording corrected |
| 1.0.0 | 2026-10-23 | First draft. Decisions 1 to 3 ruled by the maintainer on 2026-10-23 (the layers, which release, failure rules); decisions 4 to 10 are recommendations |

---

## Problem Statement

Foundation principle 1 promises that every release upgrades in place and never loses data, and the third check of the 1.0 test is that an instance "has been upgraded in place across at least one release". Today nothing proves either. A migration is written to be safe "from any prior version" (`.claude/rules/sqlite-and-migrations.md`), but the only evidence is the suite, which builds its database from `db/schema.rb` and so never sees a database a real release made. Spec 030 proves one older snapshot migrates, built inside the spec by migrating a scratch database to the migration before the newest (AC-3.6), and says that the CI proof of the previous release is this spec (#42). `docs/releasing.md` leaves the rest to the maintainer: restore their own export (step 4) and their own backup (step 5) onto the new image before announcing a release. That check is real, but it runs after the tag is pushed and the image is published, on one person's data, when they remember.

A self-hoster upgrades by pulling a newer image and starting it on their existing volume. `bin/docker-entrypoint` runs `bin/rails db:prepare` and then the server. If a migration fails on data a real release made, drops a column's values, or the new code cannot read what the old release wrote, the self-hoster finds out on their own collection. This spec makes CI find out first: on every pull request, on `main` and on every release tag, CI boots the **previous release's published image**, creates data through it, starts the **image built from the code under test** on the same volume, and fails unless the database upgraded unattended, lost nothing, and the app serves the collection as it was.

> **Terms.** *Release*: a git tag `vX.Y.Z` with no suffix, and the image published for it as `ghcr.io/plainprogrammer/collector:X.Y.Z` (spec 012, `docs/releasing.md`). *Pre-release*: a tag with a suffix (`vX.Y.Z-rc.1`); it is never a "previous release". *The code under test*: the commit CI is running on and the image built from it. *Previous release*: the release that decision 2 names for the code under test. *Old database*: the primary database a container of the previous release's image made and filled. *Upgrade*: starting the code under test's image on the old database's volume, with the same `SECRET_KEY_BASE` and settings, the way an operator pulls a newer image (Compose, `bin/kamal deploy`). *Primary database*: `storage/<environment>.sqlite3`, the one that holds collector data (ADR 0016); the queue, cache and cable databases hold nothing a collector owns. *Seed*: the script that fills the old database through the previous release's own code (decision 4). *Expected change*: a change between the old and the upgraded database that a migration is meant to make (decision 6).

## Goals

- CI fails when the code under test cannot upgrade a database that the previous release made, on every pull request, on `main` and on release tags, for both architectures the image is published for.
- The old database is made by the previous release's **published image**, from a real boot and the release's own code, not rebuilt from the code under test (decision 4).
- "Can upgrade" is concrete (decision 5): the entrypoint's `db:prepare` migrates the old database unattended; every row of every table the previous release has survives, with the same values in the columns both releases have, unless an expected change says otherwise (decision 6); the database passes SQLite's integrity and foreign-key checks; the app boots, answers `/up`, signs each collector in, and shows each collection, its settings and its locations as they were.
- A migration that fails on real data, a migration that drops rows or values without saying so, a released migration that was edited or deleted, and code that is behind the previous release each fail CI with a message that names the release, the table, the column or the file (Error Scenarios).
- When the previous release has the backup commands (spec 030), a backup it took is restored by the code under test and checked the same way (decision 7).
- A release that fails the proof is not published: on a tag the check runs before the image is pushed (decision 8).
- The part that needs no container engine runs in `bin/ci` (`config/ci.rb`), so a developer finds a broken or edited released migration before pushing (decision 1).
- The maintainer's manual release checks (`docs/releasing.md`: the upgrade part of step 5 goes; steps 4 and 5's real-data restores stay) shrink to what only real data can show (decision 9).

## Non-Goals

- Upgrading across more than one release in one step, or from every earlier release (decision 2). Each release was the previous release of the next one, so the chain of single steps is what CI proves; an operator who skips a release runs several migrations in order, which Rails does, and which no check here covers.
- A downgrade, or running an older image on an upgraded database. A restore onto an older release is already refused (spec 030 decision 10).
- The maintainer's restore onto their NAS (spec 028 AC-6.5, spec 030 AC-5.6 and AC-5.7). It checks the shape and size of real data the seed cannot imitate and stays a release step (decision 9).
- Proving data-level properties of the collection beyond "as it was": that export, import or the scanner still produce the same results is the job of their own specs. The check here reads the collection back and checks one export's validity (AC-5.5).
- The queue, cache and cable databases' contents, except that a job queued before the upgrade is still queued after it (AC-5.7). They are rebuilt state (ADR 0016).
- Sessions surviving an upgrade. A collector may have to sign in again after a release; nothing here requires or forbids it.
- A schema or data change of any kind. This spec adds no table, no column and no collector-owned data, so the export format is unchanged (north star, *Export covers it*).
- A version shown in the app, a rollback tool, a migration dry-run for operators, and any change to how the image is published (spec 012, ADR 0009).
- Proving a long-lived instance's file. The old database is built by loading the previous release's `schema.rb` (decision 4), not by running every migration since `v0.1.0`, so a file that differs from a schema-loaded one (column order, defaults, tables a migration rebuilt) is not covered; the maintainer's NAS restore is that check (decision 9).
- Measuring migration time on the 50,000-lot instance. The check bounds time on the seed's size (AC-7.4); real size stays a manual check (decision 9).

## Decisions

### 1. Two layers: a real-image proof in the image job, and an engine-free guard in `bin/ci` (ruled 2026-10-23)

The issue says "change CI steps in `config/ci.rb`", and `bin/ci` is the local CI that needs no container engine. Booting two images needs one, as `bin/image-smoke` and `bin/backup-smoke` do, and building the current image takes minutes. So the proof is two layers:

1. **`bin/upgrade-smoke <previous-image> <current-image>`**, a script in the image job of `.github/workflows/ci.yml`, after `bin/image-smoke` and `bin/backup-smoke`, on both architectures, on every pull request, push to `main` and release tag. It is the proof (Stories 2 to 6). It is not a `bin/ci` step, for the reason spec 030 gave for `bin/backup-smoke` (decision 9). It can also be run by hand against any two images.
2. **A guard in `bin/ci`** (a step in `config/ci.rb`, and specs run by `bin/rspec`) that needs no engine: the comparer's logic is specified with synthetic databases (Story 4), and the previous release's migration files are checked to be present and unchanged in the code under test (Story 8). It runs locally and in the `ci` job.

A committed fixture database per release, run inside `bin/ci`, was weighed and not chosen: it would be a binary file a person never reads, it ages the moment a release changes, and it cannot be a real release's boot (decision 4).

### 2. The previous release is the newest stable tag before the code under test; only it is checked (ruled 2026-10-23)

- *Which tag.* The stable tags (`vX.Y.Z`, no suffix) are ordered by numeric version (`v0.10.0` is after `v0.9.0`). On a branch or pull request the previous release is the newest one. On a push of a release tag it is the newest one **strictly older than the tag being built**, so building `v0.3.0` compares against `v0.2.1`, and re-running an older release's workflow compares against its own predecessor. Pre-release tags are never chosen.
- *Where it is found.* In the job's checkout, not from the registry's tag list or `latest`, so that `edge` or a moved `latest` can never stand in for a release. **Both** the `ci` job's and the `image` job's checkout fetch the full history and all tags (`fetch-depth: 0`), because each reads the previous tag's `db/migrate/` tree; a checkout that has a remote but no tags makes the step fail saying to fetch them (AC-8.5), never resolve to "no previous release".
- *The tag being built.* One resolver, called by `bin/ci`'s guard and by `bin/upgrade-smoke`, decides it in this order: (1) `GITHUB_REF_TYPE` is `tag`: `GITHUB_REF_NAME`; (2) otherwise, in GitHub Actions (`GITHUB_ACTIONS` set): no tag is being built, so the previous release is the newest stable tag, also when HEAD happens to be tagged (a push to `main` of a tagged commit), so both layers agree for one run; (3) otherwise `git describe --tags --exact-match` when HEAD is tagged, the tag of highest version precedence if several point at HEAD, else no tag being built. The previous release is the newest stable tag whose version precedence is lower than it (a pre-release `vX.Y.Z-rc.N` precedes `vX.Y.Z`, so its previous release is the newest stable tag below `X.Y.Z`). When HEAD is not tagged the previous release is the newest stable tag.
- *By hand.* `bin/upgrade-smoke` takes the previous release's version from the `org.opencontainers.image.version` label of the previous image when it is a stable `X.Y.Z`. A label that is absent or is not a stable version (`edge`, `pr-12`, `main`) needs `--previous-version X.Y.Z`; the flag wins when both are given, and a label and a flag that disagree are printed. The version finds the seed, the migration tree and the expected changes. For an image that is no release (a commit's image, as the first backup-leg run needs, AC-6.5), `--previous-ref <git ref>` replaces the version: the migration tree is read from that ref, the seed is `seeds/next.rb` with the exceptions under `next`, every expected change whose migration is in the ref's tree is retired, and the run says it is not a release proof.
- *Its image.* `ghcr.io/plainprogrammer/collector:X.Y.Z`, the image CI published for that tag, pulled for the runner's own platform. Its labels' version and revision are printed.
- *Only the previous.* Every earlier release was the previous release of the next one when it shipped; checking all of them would grow with each release (about 3 minutes per architecture each) for the one case, skipping releases, that Rails' migration order already covers.
- *None.* A repository whose tags are present but none is stable, one with no remote and no stable tag, or a tag run of the first release, has no previous release. A repository with a remote and no tags at all is the fetch failure (AC-8.5), never "none". The check prints "no previous release" and passes (decision 3).

### 3. Failures fail closed; "no previous release" is the only pass-through (ruled 2026-10-23)

An image that cannot be pulled (missing tag, missing platform, registry unreachable after retries) fails the job on pull requests, `main` and tags alike, naming the tag, the platform and the registry's answer. A registry outage is cleared by re-running the job. The pull needs no credential, because the image is public (`docs/releasing.md`, *Going public*): on a pull request (including one from a fork) the job has not logged in to the registry and the pull is anonymous; on `main` and tags the job has already logged in for its push, and the check adds no secret, permission or login of its own.

### 4. The old database is made by booting the previous release's image and filling it through its own code (ruled 2026-10-23)

Weighed against the other two ways:

| | Fidelity | CI time | Both architectures | Forks and registry | `bin/ci` |
|---|---|---|---|---|---|
| **Boot the previous published image and seed it** | The release's real image, entrypoint, migrations and models | About 2 to 3 minutes per architecture | Yes, each runner pulls its own platform | Anonymous pull; needs ghcr.io | Needs a container engine |
| Check out the previous tag and run its migrations and seeds in the suite | Its migrations and models, but on the runner's Ruby and gems, not the release's image | One more bundle and database build in the `ci` job | Not applicable (no image) | Needs the tag's history in the checkout | Runs locally, no engine |
| A committed fixture per release | A snapshot once, stale after it | Fastest | Not applicable | Nothing to fetch | Runs locally, no engine |

The first is the one that is the thing a self-hoster runs; the second and third prove the migrations, not the release. The seed is a Ruby script supplied from the checkout under test and run by the previous container's own `bin/rails runner`, so it can only use what that release has. It creates catalog rows directly through the release's models, as `bin/backup-smoke` does for its fixture entry (no Scryfall and no refresh; a departure from "catalog data changes only through `Catalog::Refresh`" that is confined to the check's throwaway volume). The first boot on an empty volume builds the old database as any new self-hoster's is built, by `db:prepare` loading the release's own `schema.rb`, which records every migration file of the release as run; the migrations that matter to the proof are the ones the code under test adds afterwards, to a database that holds the seed's rows. Because release models change, **each release has its own seed**: `script/upgrade/seeds/<X.Y.Z>.rb` is the seed used when `vX.Y.Z` is the previous release, and `script/upgrade/seeds/next.rb` is the seed for the release not yet cut, which every run checks against the code under test's own image (AC-2.6). Releasing renames `next.rb` to the tag's version before tagging, and the `next` key of `seed_exceptions.yml` with it (decision 9). A missing seed for the previous release fails the run and names the file and the step (AC-2.7).

### 5. What "can upgrade" means, and how loss is detected (ruled 2026-10-23)

The comparison opens the old and the upgraded primary database directly with SQLite, not through the application's code, so it does not depend on the code it judges. It runs in the image job on a Ruby set up by the job (`ruby/setup-ruby` with the bundle cached; the `sqlite3` and `json_schemer` gems of the app's bundle), not in either image: `script/upgrade/` is read from the checkout, so the judge is neither the previous release's code nor the image under test.

**How a database is read.** A container's primary database can have a write-ahead log that a stop does not fold in: SQLite removes `-wal` only when its last connection closes, and the container runs Puma with Solid Queue's supervisor, worker and dispatcher in it. So the harness never compares a bare main file. After the engine's normal stop (a termination signal and the grace period) it checks the exit: status 0 or 143 is clean; 137 (killed at the end of the grace period) or any other status fails the run naming the container (AC-2.4). It then copies `<environment>.sqlite3` **together with any `-wal` and `-shm`** out of the stopped volume into a temporary directory, and makes a consolidated snapshot of that copy with `VACUUM INTO` (SQLite replays the log on opening); every read below is of the snapshot.

**When it is read.** The upgraded database is snapshotted the same way before any behaviour check: upgrade, `/up`, clean stop, snapshot, comparison and integrity checks on the snapshot, and only then a restart for Story 5's checks, which sign in, enqueue and download an export and so write rows. The behaviour checks run after the snapshot and their writes are never compared (AC-2.9).

For every table in the old snapshot other than SQLite's own, `schema_migrations` and `ar_internal_metadata`:

- the table must still exist and hold the **same rows**: count and digest of the table's rows, taken over every column both databases have, in column-name order, ordered by primary key (all columns for a table without an integer or a single-column primary key, AC-4.7). The digest's encoding is fixed: each value is rendered by SQLite's `quote()` (so `1` and `'1'`, `NULL` and `''`, an integer and a real differ, and a change of a column's type affinity is a difference), a row is the values joined by a separator that `quote()` cannot produce at a value boundary, a row's hash is SHA-256, and the table's digest is the SHA-256 of the row hashes in order;
- a column present in the old table and absent in the new is a loss unless an expected change lists it; a column only in the new table is not compared;
- a row, value or column that differs is reported with the table, the column and the first primary key that differs; for a table without a primary key, with its position in the ordering and the ordering columns' values (the seed's own test values).

A table with no rows in the old database would prove nothing, so the harness first checks that the seed covered the schema (AC-2.5), and does the same for the database `next.rb` makes on the code under test (AC-2.6). The only tables allowed to stay empty are listed in `script/upgrade/seed_exceptions.yml` (table, reason: a table that cannot be filled without an external service or a long job, such as the art index tables), keyed by the release whose seed they excuse, or by `next` for `seeds/next.rb`; `v0.2.1` has 19 tables and the plan lists which of them are exceptions after reading its schema (and which of the tables `main` adds since, `number_entries`, `number_entry_lines`, the Active Storage tables, `import_uploads` and `locations`, `next.rb` must fill). An exception is printed on every run, and an exception for a table the release (or the code under test, for `next`) does not have fails the run. The queue, cache and cable databases are not compared (Non-Goals). Beyond the data, "can upgrade" is the behaviour of Story 5.

### 6. A change a migration is meant to make is listed in `script/upgrade/expected_changes.yml`, and a stale entry fails (ruled 2026-10-23)

A migration that drops a column, merges rows, rewrites a value or removes a table is sometimes right. It is allowed to change what the comparison sees only if `script/upgrade/expected_changes.yml` lists it: the table, the column (or none, for a whole table or row count), the kind (`dropped`, `rewritten`, `rows_removed`), the migration version that makes it, and a reason that names the spec. An entry applies only while the previous release does not have its migration. An entry whose migration the previous release **already has** is retired: it is ignored and printed as "retired", never a failure, because the moment a release is tagged every run on `main` and on every open pull request resolves that tag as the previous release (the tagged commit's own run still needs the entry, since it compares against the release before). Removing retired entries is housekeeping, a release step after the tag (decision 9). An entry whose migration the previous release lacks and that matches **no** difference fails the run, so the file cannot promise a change that did not happen. An entry's migration version must also be a file in the code under test's `db/migrate/`; an entry that names none (a typo that would excuse another migration's difference) fails the run naming the entry. The kinds are `dropped` (a column or table), `rewritten` (values of a column), `rows_removed` and `rows_added` (rows a migration deletes from, or backfills into, an existing table). A change not listed is a failure of the proof, never a warning. The one allowance that is not listed in the file is the backup leg's (decision 7): the four tables spec 030's restore empties.

### 7. The previous release's own backup is restored too, once it exists (ruled 2026-10-23)

Spec 030's decision 14 names this "newer image" leg as owed to #42, and the leg belongs to this outcome because it reuses the same seed, comparison and checks and adds no work when the previous release has no backup task. It is **not exercised by CI in this pull request**, since no release has the task yet (v0.2.1 and earlier); it is proved once by hand (AC-6.5) and runs in CI from the first release that has the task. When the previous release has `backup:create` (the check lists its rake tasks), the proof also takes a backup with the previous release, restores it into a fresh volume with the code under test's image under a different `SECRET_KEY_BASE`, starts it, snapshots its primary database as decision 5 says, and runs the same comparison and the same behaviour checks, with one allowance (ruled 2026-10-24): spec 030's restore ends every session (its decision 3, AC-2.1 and AC-2.4) by clearing `sessions`, which the foreign keys cascade to `bulk_removals`, `bulk_selections` and `bulk_selection_marks` (`db/schema.rb`). The comparison therefore expects exactly those four tables to hold no row after the restore, and their old rows are not a loss; they are not listed in `expected_changes.yml`, because the restore, not a migration, empties them. A row in any of them, or a difference in any other table, fails the leg. The plain upgrade comparison (Story 4) has no such allowance. `bin/backup-smoke <image> <restore-image>` already takes the second image for this; the plan decides whether the leg reuses it or shares its helpers with `bin/upgrade-smoke`. When the previous release has no such task (today: every release), the leg is skipped with a printed line saying why, and only for that reason (AC-6.4).

### 8. It runs in the image job before the image is pushed, and a tag that fails does not publish (ruled 2026-10-23)

In `.github/workflows/ci.yml`'s `image` job the step comes after `bin/backup-smoke` and before "Push by digest". The `publish` job needs the `image` job and the push is skipped on failure, so a tag whose code cannot upgrade the previous release publishes no `X.Y.Z`, `latest` or `edge`. The image job already `needs: ci`, so the engine-free guard (Story 8) has run. The time bar is an addition of **under 5 minutes** to the job on each architecture on a hosted runner, counting everything the check adds: the Ruby setup step, the pull of the previous image, its boot and the seed, the boot of `next.rb`'s fresh instance on the code under test (AC-2.6), the upgrade boot, the restart for the behaviour checks, the comparison, and the backup leg once it runs. **10 minutes** is the failure point of the `bin/upgrade-smoke` step itself (AC-7.4); the Ruby setup is its own step, outside that timeout and inside the 5-minute target. The plan measures and the maintainer rules if the bar is missed. With the build matrix's `fail-fast: false`, the architecture that passes still pushes its untagged digest; a failing architecture means `publish` does not run, so no `X.Y.Z`, `latest` or `edge` tag is created for the commit (spec 013's cleanup removes the orphaned digest).

### 9. The manual checks shrink; they do not go (ruled 2026-10-23)

This proof replaces the upgrade part of `docs/releasing.md` step 5 (that a previous release's database starts and migrates on the new image). Step 4, the export restore, never asked that and is unchanged. What remains for the maintainer, because only real data shows it: the NAS restore of the maintainer's own export (step 4) and of their own backup (step 5), whose shape and size no seed imitates, once per release that touches import, export, the schema, the backup or the restore. The releasing steps change as follows (the plan edits the document; verified by reading, AC-9.1): before tagging, rename `script/upgrade/seeds/next.rb` to the version about to be cut, rename the `next` key of `seed_exceptions.yml` to that version, and add a new `next.rb` (and a `next` key where it needs exceptions), because the tagged commit's own run still uses the older seed while every later run applies the coverage rule to the new one; read the upgrade proof's result in the tag's run before announcing; after tagging, delete the expected-changes entries that the tag's migrations retired (decision 6; they are ignored meanwhile); and keep the NAS checks for real data. The 1.0 test's third check, "upgraded in place across at least one release", is still the maintainer's own instance; this proof is evidence for it, not the check itself.

### 10. One outcome, so one spec (ruled 2026-10-23)

The outcome is "CI fails when the code under test cannot upgrade a database the previous release made". The guard, the harness, the expected-changes file, the seeds and the workflow step are the one capability and merge as one pull request. The backup leg (decision 7) is part of it because it reuses the same comparison and completes what spec 030 left owed to this issue; where the previous release has no backup task it adds no work. The deliverables of the pull request include `script/upgrade/seeds/0.2.1.rb` and `seeds/next.rb`, the first `expected_changes.yml` and `seed_exceptions.yml`, and the first measured times. Nothing here adds collector-owned data (north star, *Export covers it*), and nothing is a hosted-service feature. Hosted-door rule 4 (cost per account): the proof costs no storage or background work per account in the product; it runs in CI only.

## Users and Context

- **The maintainer**, who cuts releases and runs the NAS instance, and wants a red build, not a surprise on the NAS, when a release cannot upgrade the last one.
- **A contributor**, who adds a migration and learns before review that it breaks on data a real release made, or that they edited a released one.
- **A self-hoster**, who pulls a newer image and starts it on their volume and is owed, by principle 1, that it migrates unattended and loses nothing.

Context. The tags `v0.1.0`, `v0.2.0` and `v0.2.1` exist and each has a public two-architecture image on `ghcr.io`; `v0.2.1` has 14 migrations and `main` has 20. Between `v0.1.0`, `v0.2.1` and `main` every released migration file is unchanged (only added), so the immutability guard passes today. No release has the backup commands yet, so the backup leg is skipped until a release that has them is the previous one. `bin/docker-entrypoint` runs `bin/rails db:prepare` only when the container runs the server, and the container runs as uid 1000 with its volume at `/rails/storage`. `.dockerignore` keeps `script/` out of the image (CLAUDE.md), so the seeds are supplied from the checkout and are not in either image.

## User Stories

### Story 1: Find the previous release and its image

**As a** maintainer
**I want** CI to know which release the code under test must upgrade, and to get its published image
**So that** the proof is always against what self-hosters actually run

- [ ] **AC-1.1** Given the stable tags `v0.1.0`, `v0.2.0`, `v0.2.1`, `v0.10.0` and the pre-release `v0.11.0-rc.1` When the previous release is resolved on a pull request or on `main` Then it is `v0.10.0` (numeric order, pre-releases skipped)
- [ ] **AC-1.2** Given the same tags and a push of the tag `v0.10.0` When the previous release is resolved Then it is `v0.2.1` (strictly older than the tag being built); given a push of the first tag with none older, or a repository with no stable tag, Then the run prints "no previous release", runs no container, and exits 0
- [ ] **AC-1.3** Given a previous release `vX.Y.Z` When its image is pulled Then the reference is `ghcr.io/plainprogrammer/collector:X.Y.Z` (never `latest`, `edge` or a `sha-` tag), for the platform of the runner, and the run prints the tag, the image digest and the image's `org.opencontainers.image.revision` label
- [ ] **AC-1.4** Given a previous release whose tag exists but whose image has no manifest, or has no manifest for the runner's platform When the check runs Then it fails, naming the tag, the platform and the registry's answer, and does not fall back to another release or skip
- [ ] **AC-1.5** Given a registry that is unreachable or answers a transient error When the pull is attempted Then it is attempted up to three times in all with a wait between them, and if all fail the run fails naming the registry and the last answer; an authentication or `404` answer is not retried
- [ ] **AC-1.6** Given a pull request from a fork When the check runs Then the pull is anonymous (the job has not logged in to the registry on a pull request), the check reads no secret, and the workflow grants the job no permission it did not have; on `main` and tags it adds no login, secret or permission of its own
- [ ] **AC-1.7** Given a push to `main` whose HEAD is already tagged `v0.2.1`, a push of the tag `v0.2.1`, a local checkout at `v0.2.1`, and a checkout with both `v0.3.0-rc.1` and `v0.3.0` on HEAD When the tag being built is resolved by the one resolver that `bin/ci`'s guard and `bin/upgrade-smoke` both call (decision 2) Then they are respectively: no tag being built (previous release = newest stable), `v0.2.1`, `v0.2.1`, and `v0.3.0`; a spec covers each branch of the resolver

### Story 2: Make the old database with the previous release

**As a** maintainer
**I want** the old database made by the previous release's own image and code
**So that** it holds what a real release writes

- [ ] **AC-2.1** Given the previous release's image and an empty volume When it is started with a `SECRET_KEY_BASE` and `SOLID_QUEUE_IN_PUMA=true` Then `/up` answers 200 within the boot allowance, and the primary database's `schema_migrations` holds exactly the versions of the files in `db/migrate/` at the previous release's tag (proof that the previous release, not the code under test, made it)
- [ ] **AC-2.2** Given that instance When the previous release's seed is run in the container with its own `bin/rails runner`, the seed read from the checkout under test (it is in neither image) Then the seed prints a completion line and exits 0
- [ ] **AC-2.3** Given the seed When it has run Then the old database holds at least two accounts, each with a user who has a password, one account with no lots and one with at least 2,000 lots across several finishes, conditions, quantities and prices paid, a non-default instance setting (sign-up open, which a first user closes by default), catalog sets, identities, entries and printings created directly through the release's models, and one scheduled background job (a `Catalog::RefreshJob` set a year ahead with a recognisable argument, as `bin/backup-smoke` does); and when the previous release has locations, at least two locations
- [ ] **AC-2.4** Given the seeded instance When it is stopped Then it is stopped with the engine's normal stop (a termination signal and the grace period), the exit status is 0 or 143 (a status of 137, or any other, fails the run naming the container), and the primary database file together with any `-wal` and `-shm` is copied out of the stopped volume and consolidated into a snapshot with `VACUUM INTO` before the upgrade; the comparison reads only the snapshot
- [ ] **AC-2.5** Given the previous release's schema When the harness reads the copied database Then every table of the primary database other than `schema_migrations`, `ar_internal_metadata`, SQLite's own tables and the tables listed for that release in `script/upgrade/seed_exceptions.yml` (each with a reason; decision 5; every use is printed) holds at least one row in the snapshot, and a table without a row fails the run naming the table and saying the seed must cover it (so a table a release adds cannot go unseeded)
- [ ] **AC-2.6** Given `script/upgrade/seeds/next.rb` When the check runs Then it is run once on a fresh instance of the code under test's image and must print its completion line, a failure fails the run naming the file, and the instance is then stopped and snapshotted as AC-2.4 says and AC-2.5's coverage rule is applied to the snapshot with the exceptions under the `next` key of `seed_exceptions.yml`, so a table the code under test adds and `next.rb` does not fill fails the run naming the table and the file before a release is cut, not after (the seed the next release will use works on the code under test and covers it)
- [ ] **AC-2.7** Given no `script/upgrade/seeds/<previous version>.rb` When the check runs Then it fails before booting anything, naming the file it expected and the release step that creates it (`docs/releasing.md`)
- [ ] **AC-2.8** Given a seed that raises, or does not print its completion line, on the previous release's image When the check runs Then it fails naming the release and printing the seed's error, rather than comparing a half-filled database
- [ ] **AC-2.9** Given the upgrade run When its steps are read in order Then they are: upgrade boot, `/up`, clean stop (AC-2.4's rule), snapshot of the upgraded database, comparison and integrity checks on that snapshot, restart of the code under test's image on the same volume, then Story 5's behaviour checks; nothing that signs in, enqueues a job or downloads an export runs before the snapshot, and the snapshot is never compared with a database read after a behaviour check

### Story 3: The code under test upgrades it unattended

**As a** self-hoster
**I want** a newer image started on my volume to migrate and boot without help
**So that** upgrading is a pull and a restart

- [ ] **AC-3.1** Given the old database's volume and the code under test's image When the image is started on that volume with the same `SECRET_KEY_BASE` and settings and no other change, as the Compose file starts it Then `bin/rails db:prepare` exits 0 through the entrypoint and `/up` answers 200 within the boot allowance
- [ ] **AC-3.2** Given the upgraded database's snapshot When its `schema_migrations` is read Then it holds every version of the files in `db/migrate/` of the code under test (and every version the old database had), and the app's other databases have been prepared (the app serves requests and processes jobs, AC-5.7)
- [ ] **AC-3.3** Given an upgrade whose migration raises on the old data When the container starts Then the check fails, printing the container's log with the migration's error and naming the version of the previous release and the migration; a container that exits or never answers `/up` within the boot allowance fails the run with its log (it does not hang the job)
- [ ] **AC-3.4** Given the upgrade run Then the only `db:*` task it causes is the entrypoint's `db:prepare`, and no command it runs against the old volume is `db:schema:load`, `db:reset`, `db:drop` or `db:setup` (the commands the script may run are an allowlist, checked by AC-8.3)
- [ ] **AC-3.5** Given the upgraded database's snapshot (AC-2.9) When SQLite's `integrity_check` and `foreign_key_check` are run on it Then both report no problem

### Story 4: Nothing is lost, and a loss is named

**As a** maintainer
**I want** the check to fail when a migration drops rows or values
**So that** "never lose data" is tested, not hoped for

- [ ] **AC-4.1** Given the old and the upgraded snapshots When they are compared Then, for every table of the old database (decision 5), the upgraded database has the table, with the same row count and the same digest over the columns both have, and the run prints one line per table with its counts
- [ ] **AC-4.2** Given synthetic databases (in the suite) that differ by a row missing from the upgraded database, an extra row in the upgraded database, a changed value, a dropped column and a dropped table When each pair is compared Then each is reported as a failure, naming the table, the column where there is one, and the first primary key that differs
- [ ] **AC-4.3** Given synthetic databases that differ by a column only the new table has, or by a new table When they are compared Then there is no failure
- [ ] **AC-4.4** Given an expected change in `script/upgrade/expected_changes.yml` whose table, column and kind match a difference, and whose migration the previous release lacks When the pair is compared Then that difference is not a failure and is printed as expected with its reason, and a difference the file does not list still fails
- [ ] **AC-4.5** Given an expected change whose migration the previous release lacks and that matches no difference, or an entry missing its table, kind, migration version or reason, or an entry whose migration version is not a file in the code under test's `db/migrate/` When the check runs Then it fails naming the entry; and given an entry whose migration the previous release already has Then it is ignored, printed as retired, and the run does not fail (decision 6)
- [ ] **AC-4.6** Given a migration that silently empties a column, deletes rows, or rewrites values (injected in a spec that builds the old and upgraded databases) When the pair is compared Then the failure names the table and column, and the failure text says to fix the migration or list an expected change with a reason
- [ ] **AC-4.7** Given a table whose rows have no integer primary key or have a composite one When it is compared Then it is ordered by all its columns, so the digest does not depend on rowid order, and a difference is reported by its position in that ordering and the ordering columns' values; and Given the digest encoding of decision 5 Then a spec shows that `1` and `'1'`, `NULL` and `''` produce different digests

### Story 5: The app serves the collection as it was

**As a** collector
**I want** to sign in after an upgrade and find my collection as I left it
**So that** I never notice the release except for what it adds

- [ ] **AC-5.1** Given the upgraded instance When each seeded user signs in at the sign-in form with their old password (with its CSRF token, as `bin/backup-smoke` does) Then the sign-in succeeds
- [ ] **AC-5.2** Given the user with lots When they request the collection page Then it lists the seeded card names, and the user whose collection is empty sees the empty collection (account isolation survives the upgrade: neither sees the other's card names)
- [ ] **AC-5.3** Given the seeded instance setting (sign-up open) When the registration page is requested while signed out, on the previous instance before its stop and on the upgraded instance after its restart Then both answer with the same status and both show the sign-up form (the `user[email_address]` field) and not the closed notice (both answer 200, so the status alone cannot show it); the harness also records and compares the statuses of `/up` and `/session/new`
- [ ] **AC-5.4** Given the previous release has locations When the user signs in and requests the locations page Then both seeded locations are listed
- [ ] **AC-5.5** Given the upgraded instance When the user with lots downloads their collection export Then the response is 200, it validates against the current release's export schema for the `format_version` it names, and it holds as many lots as were seeded
- [ ] **AC-5.6** Given the upgraded instance When the recurring tasks of `config/recurring.yml` for production are read from the queue database Then each is registered, as `bin/backup-smoke` checks
- [ ] **AC-5.7** Given the `Catalog::RefreshJob` scheduled a year ahead before the stop When the upgraded instance has started Then a scheduled job with its recognisable argument is still in the queue database, and a `perform_later` run through `bin/rails runner` on the upgraded instance returns a job whose row is in `solid_queue_jobs` (not applicable to the backup leg, which carries the primary database only)

### Story 6: A backup the previous release took restores on the code under test

**As a** self-hoster
**I want** a backup made on one release to restore onto the next
**So that** the backup I took before upgrading is usable after it

- [ ] **AC-6.1** Given a previous release that has the `backup:create` task When the check runs Then the previous instance takes a backup with `backup:create`, a fresh volume is restored from it by the code under test's image with `backup:restore` under a different `SECRET_KEY_BASE`, and that instance starts and answers `/up`
- [ ] **AC-6.2** Given the restored-and-upgraded instance When its primary database, snapshotted as AC-2.9 says before any behaviour check, is compared to the snapshot taken before the backup (decision 5) Then it passes the comparison of Story 4, except that `sessions`, `bulk_removals`, `bulk_selections` and `bulk_selection_marks` must hold no row (spec 030's restore ends every session and the foreign keys cascade it; decision 7), and Story 5's checks AC-5.1 to AC-5.6 (the passwords work under the different secret), and AC-5.7 is not applied
- [ ] **AC-6.3** Given a backup the previous release took When the code under test's `backup:restore` refuses it (for example a backup format version it does not know) Then the check fails naming the refusal, because a backup the previous release made must restore on the next
- [ ] **AC-6.4** Given a previous release that has no `backup:create` task (the image lists no such task) When the check runs Then the leg is skipped, a line says "previous release vX.Y.Z has no backup task; backup leg skipped", the exit status does not change, and a previous release that has the task and a leg that does not run fails the run
- [ ] **AC-6.5** Given that no release yet has `backup:create` When the leg is first built Then it is run once by hand with the image of a commit that has the task (an `edge` or `sha-` image of `main` after spec 030, which carries no release label) as the previous image and the image built from this branch as the current one, in the hand mode of decision 2 (`bin/upgrade-smoke <previous> <current> --previous-ref <ref of that commit>`, which uses `seeds/next.rb` and the `next` exceptions and states it is no release proof), and the steps, the output and the result are recorded in `verification.md`; from the first release that has the task the image job runs it

### Story 7: It runs where releases are made and stops a bad one

**As a** maintainer
**I want** the proof on every change and in front of every publish
**So that** I find out in CI, not after announcing

- [ ] **AC-7.1** Given `.github/workflows/ci.yml` When it is read Then the `image` job runs `bin/upgrade-smoke` for each architecture of its matrix, after `bin/backup-smoke` and before the "Push by digest" step, on pull requests, pushes to `main` and release tags, with the previous release's image and the image just built (`collector:smoke`)
- [ ] **AC-7.2** Given a run on a release tag whose check fails When the workflow finishes Then the `image` job has failed and the `publish` job did not run, so none of `X.Y.Z`, `X.Y`, `X`, `latest` or `edge` points at this commit (an untagged digest pushed by the other architecture may remain, and spec 013's cleanup removes it); verified by reading the job graph and by a throwaway pre-release tag that is made to fail on purpose and then deleted, recorded in `verification.md`: the maintainer pushes it (a tag on the public repository is outward-facing, and a wrongly passing run would publish an `-rc` image) at a commit on a throwaway branch that passes the `ci` job and fails only the upgrade (for example a migration that deletes a seeded row with no expected change), so that the `image` job runs at all and the proof is what fails
- [ ] **AC-7.3** Given `bin/upgrade-smoke` run by hand with two images When it passes Then it exits 0 and prints the steps it took (resolved release, seed, stop, upgrade, comparison table, behaviour checks, backup leg or its skip), and When it fails Then it exits non-zero and the last lines name the failing step and what to read; its temporary containers and volumes are removed on every exit path
- [ ] **AC-7.4** Given a run on a hosted runner When the `bin/upgrade-smoke` step runs longer than 10 minutes Then it is killed and fails with the time printed; and the first measured runs on each architecture are recorded in `verification.md`, split into the Ruby setup step and the upgrade step, with 5 minutes added to the job (both together, decision 8) as the target the maintainer rules on if it is missed
- [ ] **AC-7.5** Given a failure in the proof When the job's log is read Then it names the previous release's tag and digest, the code under test's commit, the step, and for a data difference the table, column and first key, so the failure can be reproduced by hand with the printed `bin/upgrade-smoke` command
- [ ] **AC-7.6** Given the `ci` job (not the image job) Then it does not pull the previous release's image and does not need a container engine; it runs the Story 8 guard

### Story 8: The engine-free guard in `bin/ci`

**As a** contributor
**I want** `bin/ci` to fail when I edit or delete a released migration
**So that** I find out before I push

- [ ] **AC-8.1** Given the previous release's tag in the repository When `bin/ci` runs Then a step in `config/ci.rb` compares every file in `db/migrate/` at that tag with the working tree and passes only if each is present with identical contents
- [ ] **AC-8.2** Given a released migration that was edited, deleted or renamed (a spec builds a temporary repository with a tag, then changes a file) When the guard runs Then it fails naming each file and saying that a released migration is never edited or deleted and a new migration is the fix (`.claude/rules/sqlite-and-migrations.md`)
- [ ] **AC-8.3** Given `bin/upgrade-smoke` and the helpers under `script/upgrade/` When their commands are read by a spec Then every command they run is in the plan's allowlist, whose categories are: the entrypoint's boot of an image, `bin/rails runner` (seeds, state checks, the enqueue of AC-5.7), `bin/rails -T`, `backup:create` and `backup:restore`, one-off file operations on a volume (`cp`, `chown`, `chmod`, `ls`, and the removal of the check's own volumes and temporary directory), and the host commands of the harness (`bundle exec ruby script/upgrade/…`); and no `db:schema:load`, `db:reset`, `db:drop` or `db:setup` appears in any of them
- [ ] **AC-8.4** Given a working tree that is behind the previous release (the previous release has a migration file the working tree lacks) When the guard runs Then it fails with "the code under test is behind v<X.Y.Z>" and the files it lacks
- [ ] **AC-8.5** Given no stable tag, or a checkout where the tags are not fetched When the guard runs Then "no previous release" (printed, and a pass) applies only when tags are present and none is stable, or when there is no remote; a repository that has a remote and no tags at all fails saying to fetch tags (so a shallow checkout cannot silently skip the guard or `bin/upgrade-smoke`); the `ci` and `image` jobs' checkouts fetch the full history and tags (decision 2)
- [ ] **AC-8.6** Given the specs of this feature (the comparer, the expected-changes rules, the previous-release resolution, the guard, and the command list of AC-3.4) When `bin/rspec` runs Then they run without a container engine, a network or a registry, and are part of `bin/ci`

### Story 9: The documents say what it proves

**As a** maintainer
**I want** the release procedure to say what is automatic and what is mine
**So that** I do not repeat the check CI already makes, and do not skip the one it cannot

- [ ] **AC-9.1** Given `docs/releasing.md` When it is read Then it has the release steps of decision 9 (rename `next.rb` and the `next` key of `seed_exceptions.yml` before tagging, read the upgrade proof in the tag's run, keep the real-data restore checks for the releases that touch import, export, the schema, the backup or the restore), a line in its upgrade notes, and step 5 no longer asks for the upgrade check that CI now makes while step 4 is unchanged (verified by reading)
- [ ] **AC-9.2** Given `CLAUDE.md` and the release-and-deploy area doc when it exists (#109) When they are read Then they list `bin/upgrade-smoke` among the commands, the seeds and expected-changes file, and the rule that a released migration is never edited, pointing to this spec and not restating it (verified by reading)
- [ ] **AC-9.3** Given `docs/specs/README.md` When it is read Then spec 031 has its row, the row's *Supersedes* column records "030 decision 14 and AC-5.7, the newer-image leg: automated where the previous release has the backup task", and spec 030's row has its *Superseded by* cell read "decision 14 and AC-5.7, the newer-image leg: 031 (decision 7)" (both directions); spec 030's own files are not edited

## Functional Requirements

- **FR-1.** The previous release is resolved as decision 2 states, from the checkout's tags; the image is pulled by exact version tag; no other source (a registry listing, `latest`, `edge`) decides it.
- **FR-2.** The old database is made by the previous release's image from an empty volume through the entrypoint's normal boot, and filled through that release's own code by a seed supplied from the checkout. Nothing in the old database comes from the code under test except the seed.
- **FR-3.** The code under test is started on the same volume, with the same secret and settings, as an operator upgrades. The only database command the proof causes is the entrypoint's `db:prepare`.
- **FR-4.** The comparison reads consolidated snapshots of the databases with SQLite directly (decision 5), not through the application, and compares counts and digests over the columns both have. Only listed expected changes (decision 6) pass a difference, besides the backup leg's four tables that spec 030's restore empties (decision 7, AC-6.2).
- **FR-5.** Every failure names the step and the evidence (release, digest, commit, table, column, key, file or log). Nothing in the check is a warning that lets the job pass, except the two stated skips: "no previous release" and "no backup task".
- **FR-6.** The check never writes outside its own containers, volumes and a temporary directory, removes them on every exit path, and adds no secret, login or permission of its own (the pull is anonymous on a pull request).
- **FR-7.** Every acceptance criterion that a suite can test without a container engine is tested in `bin/rspec`; the ones that need images are proved by `bin/upgrade-smoke` in the image job (as spec 030 decision 9 divides them).
- **FR-8.** `bin/upgrade-smoke`, its helpers (under `script/upgrade/`, not `lib/`), the seeds and the two yml files are not in the published image: `.dockerignore` already excludes `script/`, and it gains `bin/upgrade-smoke` as it has `bin/backup-smoke`, which `bin/image-smoke` gains in its absent-paths list.

## Non-Functional Requirements

- **Time.** Under 5 minutes added per architecture, the Ruby setup and the extra boots included, 10 as the failure point of the upgrade step (decision 8, AC-7.4); a boot allowance equal to `bin/backup-smoke`'s (2 s attempts, raised for emulated runs).
- **Reliability.** The check pulls one image per architecture, retries transient registry errors (AC-1.5), has no fixed sleeps longer than its polling interval, and cleans up on every exit.
- **Security.** No credential is used or logged; a fork's pull request runs it; nothing from a collector or from the seed's recognisable test values is written to a log beyond table, column and key names, and, for a table without a primary key, the ordering columns' values of its first differing row (the seed uses no real data). Brakeman stays clean.
- **Self-hosting and upgrades.** It adds no migration and changes no setting and no image content. It enforces `.claude/rules/sqlite-and-migrations.md`'s "never edit a released migration" and "safe to run unattended from any prior version".
- **Maintainability.** A release adds one seed, renames the `next` exceptions key and clears the expected changes it made (the file shrinks); the failure messages say which.

## Error Scenarios

| Situation | What happens |
|---|---|
| No stable tag, or the first release's tag run | "no previous release"; no container is started; exit 0 (AC-1.2, AC-8.5) |
| The previous release's tag exists but the image does not, or lacks the runner's platform | Fails naming tag, platform and the registry's answer; no fallback (AC-1.4) |
| ghcr.io unreachable | Up to three attempts, then fails naming the registry and the last answer; a re-run clears an outage (AC-1.5) |
| The tags were not fetched in a checkout that has a remote | The guard fails saying to fetch tags (AC-8.5) |
| No seed for the previous release | Fails before booting anything, naming the file and the release step (AC-2.7) |
| The seed raises on the previous release | Fails naming the release, with the error; no comparison is made (AC-2.8) |
| A table of the previous release got no rows from the seed | Fails naming the table (AC-2.5) |
| `next.rb` does not run on the code under test | Fails naming the file (AC-2.6) |
| A table the code under test adds is not filled by `next.rb` and not in the `next` exceptions | Fails naming the table and the file, before the release is cut (AC-2.6) |
| A container exits with 137 or another unclean status, or leaves a log the snapshot cannot read | Fails naming the container and the status; no comparison is made on a bare main file (AC-2.4) |
| The harness cannot run (no Ruby or bundle on the runner, a missing gem) | Fails naming the missing prerequisite; the job does not pass without the proof (decision 5) |
| A migration raises on the old data | Fails with the container's log, the previous release and the migration (AC-3.3) |
| The upgraded container exits, or `/up` never answers | Fails with its log within the allowance; the job does not hang (AC-3.3) |
| A migration drops a table or column, deletes rows or rewrites values and the change is not listed | Fails naming table, column and first key, and says to fix the migration or list an expected change (AC-4.2, AC-4.6) |
| A listed expected change matches nothing while the previous release lacks its migration | Fails naming the entry (AC-4.5) |
| An expected change's migration is already in the previous release (a release was just tagged) | Ignored and printed as retired; the release step deletes it (AC-4.5, decision 9) |
| The upgraded database fails SQLite's integrity or foreign-key check | Fails naming the check and its first finding (AC-3.5) |
| A released migration was edited, deleted or renamed | `bin/ci` and the `ci` job fail naming the file (AC-8.2) |
| The code under test is behind the previous release (a maintenance branch whose migrations lack the previous release's) | Fails: "the code under test is behind v<X.Y.Z>", listing the missing files (AC-8.4) |
| The previous release's database has a schema the code under test cannot read (for example a table or column the new code removed without a migration, or a column type it no longer accepts) | The app fails to boot or to serve a page, or the comparison fails; either way the run fails with the container's log or the table and column (AC-3.3, AC-4.1, Story 5) |
| The previous release has a backup task and the backup leg does not run or the restore refuses the backup | Fails naming the step (AC-6.3, AC-6.4) |
| The previous release has no backup task | The leg is skipped with a printed line (AC-6.4) |
| The check on a release tag fails | The image is not pushed and no release tag is published (AC-7.2) |
| The step takes over 10 minutes | Fails with the time printed (AC-7.4) |
| A pull request from a fork | Runs the same check with an anonymous pull and no secret (AC-1.6) |

## Supersedes

Supersedes spec 030 decision 14 and AC-5.7 in part: the "newer image" leg of backup and restore (a backup taken on the previous release restored on the next) is automated in CI from the first release that has the backup task (decision 7), where spec 030 made it a manual `docs/releasing.md` step; the maintainer's real-data restore stays manual (decision 9). Spec 030's *Non-Goals* and *Out of Scope* name this proof as owed to #42, which this spec delivers. Spec 030 is not edited; `docs/specs/README.md` records the supersession in both directions, in the row for 031 (*Supersedes*) and in the row for 030 (*Superseded by*) (AC-9.3). `docs/releasing.md` steps 4 and 5 change as decision 9 says.

## Documents that change

- `.github/workflows/ci.yml`: a Ruby setup step and the `bin/upgrade-smoke` step in the `image` job (AC-7.1, decision 5) and full-history, tag-fetching checkouts in the `ci` and `image` jobs (AC-8.5).
- `config/ci.rb`: the guard step (AC-8.1).
- `bin/upgrade-smoke` and `script/upgrade/` (the seeds, `expected_changes.yml`, `seed_exceptions.yml`, the comparer and the previous-release resolution; the plan names the files).
- `.dockerignore` and `bin/image-smoke`: `bin/upgrade-smoke` kept out of the image and listed among the paths that must be absent (FR-8).
- `docs/releasing.md` (AC-9.1), `CLAUDE.md` (the Commands and Non-obvious Facts, AC-9.2), the release-and-deploy area doc when it exists (#109), `.claude/rules/sqlite-and-migrations.md` (a pointer to the guard).
- `docs/adr/`: an ADR is owed only if the plan changes how a release is cut or published beyond decision 9; the plan decides and says (the choice of the real image over a fixture, decision 4, is recorded in this spec and the plan, not a new ADR).
- `docs/roadmap.md`: theme A item 7 marked done, which completes theme A.
- `docs/specs/README.md`: this spec's row and spec 030's *Superseded by* cell (done with the draft; AC-9.3).

Each is verified by reading, except the workflow, the scripts and the guard, which the specs and the first CI run prove.

## Open Questions

None. Decisions 1 to 10 were ruled by the maintainer on 2026-10-23 (4 to 10 as recommended). The maintainer approved the spec on 2026-10-23.

## Out of Scope

Upgrading across several releases in one step, a downgrade, the maintainer's NAS restore, the queue, cache and cable databases' contents, sessions surviving an upgrade, a version shown in the app, a rollback tool, an operator dry-run of migrations, migration timing at 50,000 lots, a change to the export format or to how the image is published, and any hosted-service feature.
