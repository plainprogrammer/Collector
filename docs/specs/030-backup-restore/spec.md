# Feature 030: Back Up and Restore an Instance

**Status:** Approved by the maintainer (2026-10-21), with rulings on decisions 1 to 15 (decisions 1 to 3 as recommended; 4 to 15 confirmed as recommended in 1.1.0, except decision 4's Kamal restore sequence, ruled as option (a)); both Mode A reviews' findings fixed (version 1.2.1)
**Version:** 1.2.1
**Created:** 2026-10-21
**Last Updated:** 2026-10-21
**Branch:** `030-backup-restore`
**Issue:** [#41](https://github.com/plainprogrammer/Collector/issues/41)
**Frozen:** the current rules are in [`release-and-deploy.md`](../../architecture/release-and-deploy.md) (parts: backup and restore, all but decision 11, the export versus the backup); see the [specs index](../README.md)
**Plan:** retired in `c8706d3f9b7eb33b9f13388be5a15bec33f3ce76`; read it with `git show c8706d3f9b7eb33b9f13388be5a15bec33f3ce76^:docs/specs/030-backup-restore/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.2.1 | 2026-10-21 | Approved by the maintainer. Status and the Open Questions line only; no requirement, criterion or decision changes (PATCH) |
| 1.2.0 | 2026-10-21 | Revised after the second Mode A review (`review.md`, round 2) and the maintainer's rulings of 2026-10-21 (decisions 1 to 3 as ruled before; 4 to 15 confirmed as recommended in 1.1.0, except decision 4's Kamal restore sequence, ruled as option (a): `kamal server bootstrap`, a one-off `docker run` of the exact release on the host, then `kamal setup`). The Kamal sequence no longer needs an app boot (decision 4); the copy-in and its ownership are named for each engine (decision 4, AC-5.2); AC-1.5 is split into the cases that can happen (decision 7); FR-2 classifies a file as not a backup before it calls it incomplete (AC-3.1, AC-3.3); snapshots are opened without Active Record (decision 6, decision 7); temporary files are 0600 and fsynced; the file name's time format is fixed (decision 5); and the minor items of the review |
| 1.1.0 | 2026-10-21 | Revised after the independent Mode A review (`review.md`): the session clearing's cascade to Undos and selections (decision 3), a stricter definition of a fresh volume and a restore that never opens the primary's path (decisions 6, FR-8), a verification pre-ship check on the branch's image (decision 14), ownership and the Kamal sequence (decision 4), what the suite and the smoke script each can prove (decision 9), free-space, counts and the other items of the review |
| 1.0.0 | 2026-10-21 | Written from issue #41, roadmap theme A item 6, the north star (the 1.0 test, the hosted-door rules), ADR 0016 (which database needs backing up), ADR 0022 (stored import uploads), the Compose and Kamal deployment files and specs 012, 025 and 028 as style models |

---

## Problem Statement

Everything a collector owns lives in one SQLite file on one host's volume. A collector can already take their own collection out as an export (spec 022) and put it back (specs 025 and 028), but the export is one collector's lots, keyed by catalog ids. It is not the instance. It holds no other account, no password, no setting and no catalog, and restoring it into a fresh instance needs a catalog loaded first. An operator whose disk fails, or whose NAS is rebuilt, has no supported way to get the whole instance back. `README.md` says "Back up this volume" and nothing more: it doesn't say how to copy a SQLite database that is being written to, what the copy must hold, what a restore does, or what happens if the copy is damaged or restored onto another release.

This spec gives the operator that procedure, built and tested. An operator backs up a running instance with one Collector command, keeps the resulting file wherever they choose, and later restores it onto a fresh instance of the same release or a newer one with one Collector command (copying the file out and in are documented host steps). A damaged, partial or wrong-release backup is refused before it changes anything. The procedure is documented for Compose and Kamal and proven in the suite, in CI against a built image, and once by hand on the maintainer's own collection. This is the self-hoster's own backup; backups that a hosting operator runs for customers are after 1.0 (north star, *Not before 1.0*).

> **Terms.** *Instance*: one running Collector with its `storage/` volume. *Backup*: one file that holds the instance's primary database as it was at one moment, plus the facts needed to check it (decision 5). *Snapshot*: the copy of the primary database inside a backup. *Restore*: writing a backup's snapshot into the primary database's place on a fresh instance. *Fresh instance*: an instance whose volume holds none of the four databases (primary, queue, cache, cable) and none of their `-wal`, `-shm` or `-journal` files. *Release*: a published version of the image. *Schema version*: the newest migration a database has run. *Operator*: the person who runs the instance and has a shell on its host or container (not a collector acting through the app). *Export* and *import* are specs 022, 025 and 028's.

## Goals

- An operator backs up a running instance with one command that doesn't stop the app, doesn't block the app's writers beyond the database's busy timeout, and produces one file holding a consistent point-in-time copy of the primary database (decisions 1 and 2).
- An operator restores that file onto a fresh instance with one command, starts it, and finds every account, user, lot, setting and catalog row as it was in the snapshot. Everyone signs in again (decision 3).
- A backup that cannot be restored is never reported as a success: the backup is verified before the command finishes, and a restore verifies the file before it writes (decision 7).
- A damaged, truncated, wrong-format, wrong-release or non-backup file is refused with a plain message, and the fresh instance is left as empty as it was (decision 10).
- A backup restores onto the same release or a newer one. The newer release migrates it on boot, the way an upgrade does (decision 10).
- The procedure is documented for both deployment paths, the file's layout is documented so that it can be opened with standard tools, and the documents tell the operator when to use the export instead (decisions 5 and 11).
- The procedure is tested three ways: in the suite (every behaviour above), in CI against a built image with the commands the documents give, and by the maintainer once, restoring their own collection on their NAS (decision 9).

## Non-Goals

- A backup of a hosting operator's customers, a managed or scheduled backup service, retention, rotation, off-site upload, or restoring one account out of a backup. (After 1.0; north star.)
- A scheduler inside the app (decision 8). The documents show how to run the command from the host's scheduler.
- A web page, route or admin action that creates, lists, downloads or restores a backup. It would put every account's data behind one admin request (hosted-door rule 2) and a restore through a running app would replace the files under it. The commands run in the operator's shell only.
- Continuous replication and point-in-time recovery (Litestream), copies of the stopped volume, and host volume snapshots as *supported* mechanisms. The documents name them as operator alternatives the app doesn't test (decision 1).
- Encrypting the backup file (decision 3). The documents say to store it privately.
- Backing up the queue, cache and cable databases, `storage/catalog/` downloads, the art images, the art index file, Active Storage files, or any secret or environment setting (decisions 2 and 3).
- Restoring onto an instance that already holds a primary database, merging a backup into an instance, or restoring onto an older release than the one that took the backup (decision 6 and decision 10).
- A change to the export format, to what export, preview or apply do, or to any table. Nothing here adds collector-owned data.
- The CI proof that a database created by the previous release upgrades (#42). The restore of an older backup onto a newer release uses the same migration path and is tested here at the database level (AC-3.6), and the container script can take a second image so that #42 may reuse it (decision 9).
- A version shown in the app, a restore of Active Storage variants or previews, and a command that restores part of an instance.

## Decisions

Decisions 1, 2 and 3 were ruled by the maintainer on 2026-10-21, as recommended. Decisions 4 to 15 follow from them, from the deployment files and from the north star; the maintainer confirmed them on 2026-10-21 as recommended in 1.1.0, except the Kamal restore sequence of decision 4, which the second review showed fails on a fresh host and which the maintainer ruled as option (a) (below). Each heading says "(ruled)".

### 1. The mechanism is an online snapshot with SQLite's `VACUUM INTO`, run by a Collector command in the running container (ruled)

Compared for one host, SQLite in WAL mode, run under Compose or Kamal, with no required proprietary service (foundation principle 1):

| Option | For | Against |
|---|---|---|
| **A. Online snapshot of the primary database with `VACUUM INTO`, run by a rake task inside the running container (chosen)** | One consistent point-in-time copy taken in a read transaction, so WAL's writers keep going; no downtime; one portable file; the `sqlite3` gem and the image's `sqlite3` command already exist; a restore is a one-off command into an empty volume; one procedure to test and document for both deployment paths | The copy is a full rewrite, so it costs the database's size in time and temporary disk (the catalog makes it large; decision 13); no point-in-time recovery between backups |
| B. Stop the app and copy the volume | Nothing to build | Downtime; the operator needs the volume's files (a Compose named volume is awkward to reach); copying the files of a database while the app runs corrupts the copy, and nothing stops the operator doing that; the copy carries the other three databases and the downloads |
| C. Litestream | Continuous, point-in-time | A second long-running process in every deployment, an object store or other replica target, and a binary the image lacks; restoring needs it too; more than a 1.0 self-hoster needs |
| D. Host volume snapshots (ZFS, LVM, btrfs) | Fast; crash-consistent for WAL | Only for operators who have them; the app can't test them; they copy the whole `storage/` volume, not one database |

The maintainer ruled A: it is the one tested and supported procedure. B, C and D are named in the documents as alternatives an operator may use; the app doesn't test or support them. SQLite's online backup API was considered inside A and not chosen. Run incrementally, as the `sqlite3` command's `.backup` runs it (100 pages per step), it restarts when another connection writes between steps, so a busy instance can starve it; a single `step(-1)` doesn't restart, but `VACUUM INTO` is still the better choice: it reads one snapshot in one statement and compacts the copy. The ADR owed by the plan records this comparison, supersedes nothing, and closes ADR 0016's consequence about the undecided mechanism.

### 2. What a backup holds (ruled)

| Piece | In the backup | Why |
|---|---|---|
| **The primary database** (`storage/production.sqlite3`), whole | Yes | It holds accounts, users, lots, settings, sessions and the working lists, **and the global catalog**: `lots` has a foreign key to `catalog_entries`, so the catalog can't be left out without orphaning every lot (ADR 0003's name index and the art fingerprints live in it too). A restored instance therefore needs no catalog refresh before its collection resolves |
| **Active Storage files** under `storage/` | **No files today** | The only upload is spec 028's stored import file: it expires after an hour, is the collector's own export already restored into lots by applying it, and a restore tolerates its missing file (an apply answers "Preview the file again." and the sweep removes the row, ADR 0022). A guard fails the suite when a model gets a collector-owned attachment, until the backup covers it (AC-5.5) |
| **`storage/catalog/` downloads, the art images and the art index file** | No | Rebuildable. The index file is rebuilt from the fingerprints the database holds, with **Build art index**, without image downloads when every artwork already has a fingerprint (AC-2.8). The documents tell the operator to press it after a restore when art matching is on |
| **Queue, cache and cable databases** | No | Jobs in flight are lost, the cache refills, cable is ephemeral. `db:prepare` creates them empty on the fresh instance (ADR 0016: only the primary needs backing up) |
| **Secrets and environment settings** | No (decision 3) | The operator keeps them; the documents list them |

A new database beyond the four, or a new collector-owned attachment, fails the suite until this table and the procedure's documents say what they do (AC-5.5). That is this spec's version of the export format's "Export covers it" rule.

### 3. Secrets, sessions and the file's sensitivity (ruled)

- **No secret goes into a backup.** `SECRET_KEY_BASE` and, under Kamal, `RAILS_MASTER_KEY` stay with the operator, who keeps them separately (a password manager, the Compose `.env` file). Nothing in the database is encrypted with them (no model uses `encrypts`; passwords are `has_secure_password` hashes; the one signed-id use is the Active Storage gate), so a restore under a different or lost secret keeps all data: its only effect is that session cookies signed under the old secret stop working, and everyone signs in again with their password (AC-4.2).
- **A restore ends every session** (it clears the `sessions` table), so a backup older than a password change or a sign-out can't bring back a session that was ended since (`collector:user` signs a user out everywhere by deleting its sessions). The clearing cascades: `bulk_removals` and `bulk_selections` have foreign keys to `sessions` with `on_delete: :cascade`, and `bulk_selection_marks` cascade from the selections, so a restore also drops every pending bulk-removal Undo and every bulk selection. That is working state, no collection is lost (its lots are in the snapshot), and the restore's closing message says it. The clearing runs with foreign keys on, and the result passes SQLite's foreign-key check (AC-2.1). Everyone signs in again.
- **The backup file is sensitive** although it holds no secret: it holds every user's password hash and every account's collection. It is written readable by its owner only (AC-1.8), and the documents say to store it privately. Encrypting it is not built in 1.0.
- **What an operator keeps outside the backup**, named in the documents: the secret(s); the environment settings (`COLLECTOR_*`; a restored instance with another `COLLECTOR_CURRENCY` shows the same prices with another symbol, as the README says of changing it); and the `compose.yaml` or `config/deploy.yml` they run.

### 4. The commands and where the file goes (ruled; the Kamal sequence ruled as option (a))

Two commands, in the style of the app's other operator tasks (`catalog:refresh[mtg]`, `collector:user[...]`): `bin/rails "backup:create[DIRECTORY]"` and `bin/rails "backup:restore[FILE]"`. The destination is a required argument. There is no default under `storage/`: a backup inside the volume it protects is lost with it, and a volume backup would carry it. The commands print the file's name, size, schema version and elapsed time, never account, email or lot data (AC-1.7). No setting is added: the destination is the operator's choice per run (hosted-door rule 3).

**Ownership.** The image runs as uid 1000 (`USER 1000:1000`), the backup is 0600 (AC-1.8), and the restore runs before the first start, when there is no service container to copy into. So every way of getting the file in must leave it readable by uid 1000. The documents give two ways, for both Docker and Podman, and `bin/backup-smoke` runs the same commands (AC-5.2):

| | Copy out (backup) | Copy in (restore) |
|---|---|---|
| **Preferred: a host directory** (for example `/srv/collector-backups`) that the operator `chown`s to `1000:1000` once | Mounted read-write at `/backups`; the backup lands there and is already on the host | The file is placed in the same directory; mounted **read-only** at `/backups` for the restore one-off, which reads `/backups/<file>` |
| **Without a host directory** (Docker or Podman) | `docker cp <container>:<path> .` (`podman cp`; the container's name differs by tool, so the documents state it) | `docker create -v collector_storage:/rails/storage <image>`, `docker cp <file> <created container>:/rails/storage/<file>`, then a one-off as root, `docker run --rm -u 0 -v collector_storage:/rails/storage <image> chown 1000:1000 /rails/storage/<file>`, then `docker rm` the created container; the restore one-off then runs as uid 1000 and reads `/rails/storage/<file>` |

`docker cp` creates root-owned files (and `docker cp -a` keeps the host's uid, which is rarely 1000), and uid 1000 cannot `chown` to itself, hence the `-u 0` one-off. Under **rootless Podman** a bind-mounted host directory appears root-owned inside the container unless the mount is given `:U` or the container `--userns=keep-id`; the documents say which. **Where the input file may live:** anywhere the container's user can read it: the mounted directory, or inside the volume, because the freshness test looks only at the four databases and their `-wal`, `-shm` and `-journal` files (AC-2.5). The restore never moves, changes or deletes the input file. `compose.yaml` gets no mount unless the plan adds one as a stated addition; the documents give the one-off commands with `-v`.

**Compose and Podman Compose.** The restore is the engine one-off above against the Compose project's volume (its real name, `<project>_collector_storage`, printed by `docker volume ls`; the documents say to check it, because a different project name is a different volume, see the error table).

**Kamal (ruled 2026-10-21, option (a)).** `config/deploy.yml` uses the named volume `collector_storage`, so the stated addition is a host directory in `volumes:` for backups and a `backup` alias (`kamal app exec --reuse`, like the existing aliases), and the file is fetched with `scp`. A restore cannot use `kamal app exec` before the first boot: Kamal's one-off container takes the role's `--env-file .kamal/apps/<service>/env/roles/web.env` (written only by the app boot, whose `db:prepare` makes the volume not fresh) and the `kamal` network (created by the proxy boot), and picks the image by `latest` unless `--version` is given. So the sequence is:

1. `kamal server bootstrap` (Docker on the host).
2. Over `ssh` on the host, one `docker run --rm -u 1000 -v collector_storage:/rails/storage -v <backups dir>:/backups:ro -e SECRET_KEY_BASE_DUMMY=1 ghcr.io/plainprogrammer/collector:X.Y.Z bin/rails "backup:restore[/backups/<file>]"`, with the **exact release version** `X.Y.Z` as the tag. The version is required: releases deploy with `--skip-push --version X.Y.Z` (`docs/releasing.md`), so no `latest` tag is on the host. The restore needs no secret (AC-2.7), so `SECRET_KEY_BASE_DUMMY=1` stands in for one; **the plan confirms that a production boot of the rake task doesn't read `secret_key_base` eagerly** and, if it does, that the dummy is enough.
3. Then `kamal setup` or `kamal deploy` for that same version, which boots the app, which `db:prepare` migrates.

The Kamal path is documented, and its container command is the one `bin/backup-smoke` runs (with a dummy `SECRET_KEY_BASE`, a mounted directory and the image tag). It isn't exercised through Kamal itself in 1.0, because the maintainer has no Kamal host, and the documents say so.

### 5. The file is one self-describing archive with a documented layout (ruled)

One file, `collector-backup-YYYYMMDDTHHMMSSZ.tar.gz` (UTC, second precision, for example `collector-backup-20261021T142100Z.tar.gz`: no colon, which `docker cp container:path`, `scp host:path` and SMB or Windows shares mishandle), holding `manifest.json` (the backup format version, the UTC time taken, the snapshot's schema version, its size and SHA-256, and what it holds) and `primary.sqlite3` (the snapshot). Written under a temporary name in the destination and renamed only when verified (decision 7), so a file with the final name is a whole backup. The layout is documented in the procedure's document, with a manual recovery path that uses only `tar` and `sqlite3` (the image carries `sqlite3`), because users own their data without needing this app (foundation principle 2). The backup format's version is its own whole number, apart from the export format's `format_version`. A released backup format version never changes meaning; a release restores every format version it has shipped and refuses one it doesn't know (AC-3.4).

### 6. A restore needs a fresh instance and never overwrites (ruled)

The restore runs before the instance's first start, as a one-off command in a container with the empty volume, and doesn't need the app running. It refuses when the volume isn't fresh, that is holds any of the four databases or any `-wal`, `-shm` or `-journal` file (AC-2.5): a stale WAL beside a restored database would be replayed into it, and a stale queue database would run old jobs against it. It offers no override in 1.0: replacing a live database's files under a running Puma and Solid Queue would corrupt them, and `db:drop` and `db:reset` are never run against production (`.claude/rules/security.md`). An operator who wants to restore over an instance restores onto a new volume and switches to it. The restore places the snapshot with a temporary name and renames it into place only after every check passes, so a restore that fails or is killed leaves no primary database that the next boot's `db:prepare` would mistake for an empty instance and silently replace with a blank one (AC-2.6), whose first visitor would become its admin. For the same reason the restore never opens a connection to the primary's path (FR-8), and it closes the snapshot in rollback-journal mode, with no `-wal` file, before the rename. Every snapshot (the restore's temporary file, the backup's `.partial`) is opened with `SQLite3::Database` directly, never through Active Record: the Rails adapter sets `journal_mode: :wal` on every connection, which would convert the snapshot to WAL and leave `-wal` and `-shm` beside it. The checks set `PRAGMA foreign_keys = ON` explicitly (SQLite's default is off). The placed primary has the rollback-mode header (bytes 18 and 19 equal 1) and no sidecar (AC-2.1); the first boot's adapter converts it to WAL as it does any database.

### 7. A backup is verified before it counts; a partial backup is never named like a whole one (ruled)

`VACUUM INTO` writes the snapshot by rebuilding every table and index from a logical read of the source into a fresh database. So an index or free-list inconsistency in the source is repaired in the snapshot rather than reported, and real b-tree damage makes `VACUUM INTO` itself fail with `SQLITE_CORRUPT`, possibly after writing part of the output. The verification therefore proves the *snapshot* sound, not the source, and the cases that can happen are two: (a) `VACUUM INTO` raises, and (b) the snapshot fails the foreign-key check (a violation survives the copy; Rails turns foreign keys on for every connection and checks them after table rebuilds, so a violation means tampering or damage). Before the command finishes it reads the snapshot back (opened with `SQLite3::Database`, decision 6) and runs SQLite's integrity check and foreign-key check on it. Either case is a failed backup: no file with the final name, the run's `.partial` files removed, a message that says what failed, a non-zero exit. For (b) the message also says that each collector's export (decision 11) is still available, because an instance with an orphan row can't be backed up this way and its backups would be refused on restore (AC-3.7).

The archive is written to a temporary name beside the final one (the `.partial` suffix) and renamed on success; a killed or full-disk run leaves at worst a `.partial` file, which the restore refuses by its name and by its content and the next backup run removes when its modification time is more than a day old (a younger one may belong to a run in progress; each run's `.partial` name has a random part, so two runs never share one). The snapshot is written in the destination, not in a temporary directory elsewhere, so the rename is within one filesystem. **The temporary files are private from their creation:** the snapshot's `.partial` file is created empty with mode 0600 first (`VACUUM INTO` accepts an existing empty file) and the archive's `.partial` is created 0600, so neither is ever readable by others. **Durability:** the archive is `fsync`ed before the rename and the destination directory after it (where the platform allows), so a power cut after a reported success can't leave a final-named truncated file; the restore `fsync`s the placed primary and its directory likewise. A final name is never overwritten: the time in the name has second precision and a clash fails the run with a message rather than replacing a file (AC-1.9).

### 8. No scheduler in the app (ruled)

An in-app schedule needs a destination off the volume, a retention rule and a failure signal, each a decision that belongs with a hosted offering's backups. The documents give a cron line for a host and a Kamal alias for the operator's scheduler, and suggest backing up before every upgrade and at least daily for a collection that changes daily. The cron line avoids Monday 03:00 to 05:00 in the instance's time zone, where the weekly catalog refresh (`config/recurring.yml`, Monday 3:15am) is the heaviest writer and a backup's read transaction would hold the WAL back (decision 13). Not scheduling is a documented limit.

### 9. How "tested" is proven: three layers (ruled)

1. **The suite (`bin/ci`).** Every behaviour of Stories 1 to 4 that needs no container (so not AC-2.3 or AC-4.2), against the file-backed test database, without transactional fixtures (`VACUUM INTO` can't run in a transaction and the concurrent writers need their own connections), with the restore's target directory an argument of the class beneath the task so that a scratch directory stands for the volume, and the boot of AC-2.2 run through `db:prepare` against that directory. It covers a writer running during a backup, damaged and wrong-release files, a killed restore, and a round trip through `CollectionExport`.
2. **CI against a built image.** `bin/backup-smoke <image>` runs the two tasks against the image the workflow built, as `bin/image-smoke` runs its tasks: boot one container with a volume, seed a fixture catalog entry, an admin and lots with `bin/rails runner` (no Scryfall), back up (polling `/up` while the task runs, so the instance is seen answering throughout), copy the file out and back in the documented ways (decision 4), boot a second container with a new volume and **a different `SECRET_KEY_BASE`**, restore, start, and check AC-2.3 and AC-4.2 (`/up`, the admin's password at the sign-in form with its CSRF token, the lots, the registered recurring tasks). It runs in the image job of `.github/workflows/ci.yml` after `bin/image-smoke`, on both architectures, and fails the job on any miss. It takes an optional second image to restore into, so that #42 can reuse it with the previous release as the source. It isn't a `bin/ci` step: it needs a container engine, as `bin/image-smoke` does. The Compose and Kamal wrappers of the documents are checked by reading and, for Compose, by the manual check below.
3. **By hand, on real data.** Before the spec ships, the maintainer backs up their running NAS instance (Compose) using the image built from this spec's branch (a released image has no backup task) and restores it onto a fresh Compose project of the same image, and compares the two (AC-5.6). For each later release that changes the schema, the backup or the restore, the same backup is restored onto the new image (AC-5.7, decision 14). This is the release check, as spec 028 AC-6.5 is for import. It also serves the 1.0 test's second check for the maintainer's own collection only in part: that check is an *export* restored into a fresh instance (north star), which spec 028 gave, and a backup restore doesn't replace it.

### 10. Same release or newer: yes. Newer backup, older release: refused (ruled)

A restore compares the snapshot's schema version and its `schema_migrations` rows with the migrations the running release has. A snapshot that lists a migration the release doesn't have was taken by a newer release and is refused, naming that the restore needs that release or a newer one (AC-3.5). A snapshot at the release's schema version or older is accepted as it is; the entrypoint's `bin/rails db:prepare` migrates it on first start, which is the upgrade path every migration is already safe to run unattended on (`.claude/rules/sqlite-and-migrations.md`; AC-3.6). Nothing is migrated by the restore itself: a restore never runs a migration, `db:schema:load` or `db:reset`. A snapshot whose backup format version the release doesn't know is refused (AC-3.4).

### 11. The export is per collector, the backup is per instance; the documents say which to use (ruled)

| | Export (specs 022, 025, 028) | Backup (this spec) |
|---|---|---|
| Whose | One collector's collection | The whole instance: every account, user, setting, and the catalog |
| Made by | The collector, in the app | The operator, on the host |
| Holds | Profile (name, email), currency, lots, keyed by the source's ids | The primary database as it is |
| Restores into | Any instance of any release, even one with another catalog build; replaces that collector's lots | A fresh instance of the same or a newer release; nothing else is replaced |
| Doesn't hold | Passwords, other users, settings, the catalog | Secrets, environment settings, jobs, the art index file, downloads |
| Use it for | Moving a collection between instances, a collector's own safety copy, a file they can read | Disaster recovery of the instance, moving the whole instance to new hardware, backing up before an upgrade |

The README's "Your data" part and the new backup section carry this table's content, and each links to the other (AC-6.1). Neither replaces the other: the north star's 1.0 test asks for an export restored into a fresh instance, and the backup is the operator's safety.

### 12. The art index after a restore (ruled)

A restore rewrites nothing in the catalog tables. The art index file is left behind, so the scanner works on text alone until the operator presses **Build art index** (AC-2.8), which needs no downloads because the fingerprints are in the restored database. Until then `catalog:status` and the admin page still say "ready" for a finished build whose index file is absent. That wording is a flaw of the catalog operations area, found while specifying this; it is not fixed here and is noted for a separate issue (the plan files it with the maintainer's agreement). The documents tell the operator to press the button.

### 13. The bar for time and space (ruled; measured in the plan)

For an instance holding the English catalog (Scryfall's `default_cards`) and 50,000 lots, measured outside the suite on the development machine (AC-1.10): a backup, verification included, completes in under 5 minutes, and during it the app's writes complete, each waiting under the database's 5-second busy timeout; a restore completes in under 5 minutes; the temporary disk a backup needs is the snapshot plus the archive, so the command refuses to start when the destination has less free space than twice the primary database's size (AC-1.11). The 5 minutes include the integrity and foreign-key checks, which grow with the database (`quick_check` plus `foreign_key_check` is the ready fallback if the bar is missed). In WAL mode the backup's read transaction pins its snapshot, so for its length (up to 5 minutes) the WAL can't be reset past it and every write grows the `-wal` file on the volume; the cost is stated here and in the Cost NFR. The sizes are recorded. If a bar is missed, the maintainer rules the fallback. The numbers are recommendations: the catalog's size in the primary database hasn't been measured for this spec.

### 14. The maintainer's own restore is the release check (ruled)

As for import (spec 028 AC-6.5, `docs/releasing.md` step 4), the maintainer restores their NAS instance's backup before the spec ships and before later releases that change the schema, the backup or the restore. Before shipping, only the branch's own image has the commands, so the check restores that image's backup onto a fresh Compose project of the same image (AC-5.6). The *newer image* leg, a backup restored onto a newer release, can't exist before there are two releases with the feature, so it becomes a `docs/releasing.md` step for each later release (AC-5.7); the database-level proof that an older snapshot migrates is AC-3.6.

### 15. One outcome, so one spec (ruled)

The north star says a title that needs "and" is split. This spec's outcome is one: an operator recovers an instance from a backup. A backup that can't be restored isn't a backup (AC-1.5, decision 7), and a restore needs a backup to exist, so neither half is releasable alone. The title keeps the issue's wording; the maintainer ruled this reading on 2026-10-21: backup and restore are one outcome and one spec.

## Users and Context

**Primary users:** the operator of a self-hosted instance, who is usually the maintainer's kind of user: one person, one NAS or small server, Compose or Kamal.
**Secondary users:** the collectors on that instance, who lose nothing but their sign-in session on a restore.
**Usage context:** before an upgrade, on a schedule, and, rarely and under stress, after a failure. The restore is used once in a while, by someone who may not remember the steps, so the documents are complete and the messages say what to do next.
**User mental model:** "Copy my whole Collector somewhere safe. If the box dies, put it back on a new one and everyone's cards are there."

## User Stories

### Story 1: Back up a running instance

**As an** operator
**I want** one Collector command that backs up my running instance
**So that** I can keep a copy of everything without stopping Collector

- [ ] **AC-1.1** Given a running instance and a writable destination directory When `backup:create` is run with it Then exactly one file named `collector-backup-YYYYMMDDTHHMMSSZ.tar.gz` (UTC; the pattern is checked, with no colon) is in the directory, and the command exits 0 and prints the file's path, size, schema version and elapsed time (that the instance keeps answering requests is checked by `bin/backup-smoke`, AC-5.2, and by the concurrent writes of AC-1.3)
- [ ] **AC-1.2** Given a writer that commits transactions of two related rows continuously while the backup runs When the backup finishes Then, for every transaction the writer committed, the snapshot holds both rows or neither, and SQLite's integrity check and foreign-key check on the snapshot report no problem
- [ ] **AC-1.3** Given the same writer, and a second writer that is the app's own write path (a lot add) When the backup runs Then every write completes, none waits longer than the database's busy timeout (5 seconds), and none fails with a busy error
- [ ] **AC-1.4** Given a backup When its archive is opened Then it holds `manifest.json` and `primary.sqlite3` and nothing else; the manifest states exactly these fields: the backup format version, the UTC time taken, the snapshot's schema version, its size, its SHA-256 (that of the snapshot), and the counts of accounts, users and lots in it; and the snapshot in the archive is in rollback-journal mode (header bytes 18 and 19 equal 1) with no `-wal` or `-shm` file beside it
- [ ] **AC-1.5** Given `VACUUM INTO` failing while the snapshot is written (the spec simulates `SQLITE_CORRUPT`, or uses a database file with a damaged page) When `backup:create` is run Then it exits non-zero with a plain message (AC-3.8's meaning) that the database reports damage, and the destination holds no file with a final name and no `.partial` file (the run removes its own partial output, including one `VACUUM INTO` left behind)
- [ ] **AC-1.6** Given a backup run stopped after the snapshot is written and before it is renamed (the spec stops it at that point) When the destination is inspected Then it holds a `.partial` file with mode 0600 and no file with a final name; and given a later `backup:create` into the same directory, a `.partial` file whose modification time is more than 24 hours old is removed and a younger one is left alone
- [ ] **AC-1.7** Given any run of `backup:create` or `backup:restore` When its output and the app's log for it are searched for the recognisable account names, email addresses, lot and catalog values the spec seeded Then none is found: they hold only file names, the volume or destination path, sizes, the counts of accounts, users and lots, the schema version and times
- [ ] **AC-1.8** Given a finished backup When its file mode and bytes are inspected Then the mode allows its owner only (0600; the `.partial` files had it from their creation, AC-1.6), and neither the manifest nor the snapshot holds the value of `SECRET_KEY_BASE` or `RAILS_MASTER_KEY` (the spec sets both to recognisable values and searches)
- [ ] **AC-1.9** Given a destination that already holds a file with the name the run would use When `backup:create` is run Then the existing file is untouched, the command exits non-zero saying so, and no `.partial` file is left; and given two runs started together Then each ends with its own file or the clash message, never one file written by both (each run's `.partial` name carries a random part)
- [ ] **AC-1.10** Given, outside the suite, an instance holding the English catalog and 50,000 lots (decision 13) When `backup:create` and then `backup:restore` are run on the development machine Then the backup, verification included, finishes in under 5 minutes, the longest wait of a write made during it is under 5 seconds, the restore finishes in under 5 minutes, and the file's and the snapshot's sizes are recorded in `verification.md` with the method; if a bar is missed the maintainer rules the fallback
- [ ] **AC-1.11** Given a destination that doesn't exist, isn't writable by the user the container runs as, or has less free space than twice the primary database's size (the snapshot and the archive are both written there) When `backup:create` is run Then it exits non-zero with a plain message saying which, writes nothing (no `.partial` file), and the instance is unaffected
- [ ] **AC-1.12** Given a primary database holding an orphan row (inserted with foreign keys off for the spec), so that the snapshot fails SQLite's foreign-key check When `backup:create` is run Then it exits non-zero with a plain message that the database fails its foreign-key check and that each collector's export is still available, and the destination holds no file with a final name and no `.partial` file

### Story 2: Restore onto a fresh instance

**As an** operator
**I want** one Collector command that puts a backup onto a new instance
**So that** a failed disk or a new NAS costs me a restore, not my collection

- [ ] **AC-2.1** Given a backup and a fresh volume When `backup:restore` is run with the file Then it exits 0; the primary database exists at its configured path; every table except `sessions`, `bulk_removals`, `bulk_selections` and `bulk_selection_marks` holds exactly the snapshot's rows (compared table by table) and those four hold none (decision 3); SQLite's foreign-key check reports nothing; the placed file is in rollback-journal mode (header bytes 18 and 19 equal 1) with no sidecar beside it; the output gives the volume path and the counts of accounts, users and lots, equal to the manifest's; and the closing message says to start the instance, that everyone signs in again, that pending bulk-removal Undos and selections are gone, and that the art index is rebuilt with **Build art index**
- [ ] **AC-2.2** Given a populated account exported with `CollectionExport`, a backup of its database, and a restore into a scratch storage directory that the app is then configured to use and boots from through `db:prepare` (as the entrypoint runs it) When the collector signs in and exports again Then the sign-in with their password succeeds, their collection page shows the same lots, and the second export holds *the same collection* as the first under the export format's rule ([*The same collection*](../../export-format/README.md#the-same-collection))
- [ ] **AC-2.3** Given a restored volume that `bin/backup-smoke` boots (a check only a container can make) When the instance has started Then the queue, cache and cable databases exist and are empty of anything from before the backup, no job from before it exists, and the recurring tasks of `config/recurring.yml` are registered as on any fresh instance
- [ ] **AC-2.4** Given a backup whose snapshot held sessions, and a session cookie from before When it is restored and the app started Then the `sessions` table holds no row, a request with the old cookie is redirected to sign in, and the user's password signs them in
- [ ] **AC-2.5** Given a volume that isn't fresh, in each of these cases: it holds a primary database; it holds only a `-wal` file of a database that is gone; it holds only a queue database When `backup:restore` is run Then it exits non-zero saying the volume isn't empty, every file in the volume is as it was (compared by checksum before and after), and nothing is created in it
- [ ] **AC-2.6** Given any restore that is refused or fails, including one stopped after the snapshot is written to its temporary name and before it is renamed (the spec stops it there), and one given a path that doesn't exist When the volume is inspected Then it holds no `production.sqlite3` file or sidecar (the restore never opened a connection to that path), a later `backup:restore` of the same file succeeds, and it removes the stopped run's leftover temporary file and that file's `-journal`
- [ ] **AC-2.7** Given the same backup restored onto two fresh volumes, with a different `SECRET_KEY_BASE` set for each When the two primary databases are compared Then they hold the same rows in every table: the restore reads no secret
- [ ] **AC-2.8** Given a restored instance with art matching on, ImageMagick present, a last applied catalog refresh in the database, every artwork already fingerprinted at the current settings, and no index file When the scanner page is opened Then it offers text recognition only; and when **Build art index** is pressed Then the build writes the index file without a single HTTP request (the suite blocks all of them) and the scanner page then offers art matching. (An artwork with no fingerprint, such as one whose image failed on the source instance, is fetched by the build as it always is, and is not part of this criterion.)
- [ ] **AC-2.9** Given a backup taken while a catalog refresh was recorded as running, restored and started When the admin catalog page is opened Then, as spec 015's rules judge a run whose job no longer exists, the run is shown as interrupted, **Refresh now** is available and queues a run, and no run reads "Running" for good
- [ ] **AC-2.10** Given a backup taken while a stored import upload existed, restored and started When the collector posts an apply for it Then it answers 422 "Preview the file again." with nothing written, and once the upload's expiry has passed the sweep removes its row
- [ ] **AC-2.11** Given a backup of an instance with no users When it is restored Then the command exits 0 and its message says the backup holds no users and that the first person to reach the restored instance becomes its admin

### Story 3: A wrong or damaged backup is refused

**As an** operator under stress
**I want** a bad file to be refused with a clear message
**So that** I never end up with a half-restored or empty instance that looks fine

- [ ] **AC-3.1** Given a backup cut short (the last bytes removed, as a failed copy leaves it), and a `.partial` file When each is passed to `backup:restore` Then each is refused with a plain message that it is incomplete and to take or copy the backup again, and nothing is written (AC-2.6). A file is *incomplete* only when it starts as a backup (gzip, and a tar whose first entry is `manifest.json`) and then ends early, fails its gzip CRC or length, or is named `*.partial` (FR-2's classification)
- [ ] **AC-3.2** Given a backup with one byte of the snapshot changed inside an otherwise well-formed archive When restored Then it is refused with a message that its checksum doesn't match, and nothing is written
- [ ] **AC-3.3** Given a file that isn't a backup (a text file, a gzip file of something else, a tar.gz whose first entry isn't `manifest.json`, and a Collector *export* file, a JSON document) When restored Then each is refused saying it isn't a Collector backup (never "incomplete", AC-3.1), and for the export file the message also says to use **Import collection** in the app for it; nothing is written
- [ ] **AC-3.4** Given an archive whose manifest names a backup format version the release doesn't know When restored Then it is refused naming the versions this release restores, and nothing is written
- [ ] **AC-3.5** Given a snapshot whose `schema_migrations` lists a version the running release has no migration for (a newer release's backup) When restored Then it is refused saying it was taken by a newer release and must be restored onto that release or a newer one, naming both schema versions, and nothing is written
- [ ] **AC-3.6** Given a snapshot taken from a database migrated only to the migration before the release's newest (built in the spec by migrating a scratch database to that version) holding rows When restored and started through `db:prepare` Then the restore itself ran no migration, the first start migrates it to the release's schema version, no row is lost, and `db:schema:load`, `db:reset` and `db:drop` are not run
- [ ] **AC-3.7** Given an archive whose checksum matches but whose snapshot fails SQLite's integrity check or foreign-key check (the damaged snapshot is built directly in the spec, with a page overwritten for the first and an orphan row inserted with foreign keys off for the second, then archived with a correct manifest, not made through `backup:create`, which would refuse it) When restored Then it is refused saying the database inside is damaged, and nothing is written
- [ ] **AC-3.8** Given each refusal of AC-3.1 to AC-3.7 and AC-2.5 When the command ends Then it exits non-zero, prints one plain sentence saying what is wrong and one saying what to do (a *plain* message is a sentence an operator can act on, with no exception class name and no backtrace), and its exit status distinguishes nothing but success from failure

### Story 4: Secrets and settings stay with the operator

**As an** operator
**I want** to know exactly what I must keep besides the backup
**So that** a restore never surprises me

- [ ] **AC-4.1** Given a backup When its archive entries are listed and its manifest and snapshot bytes are searched for the recognisable values the spec set for `SECRET_KEY_BASE`, `RAILS_MASTER_KEY` and a free-form setting (a unique address in `COLLECTOR_TRUSTED_PROXIES`) Then the archive holds only `manifest.json` and `primary.sqlite3`, and none of those values is found (the queue, cache and cable databases, `storage/catalog/` files and Active Storage files are not in it)
- [ ] **AC-4.2** Given a backup from an instance run with one `SECRET_KEY_BASE`, restored onto a fresh instance run with another (`bin/backup-smoke`, decision 9) When the second instance has started Then `/up` answers 200, the admin's password signs in, the lots are there, and a session cookie from the first instance is not accepted
- [ ] **AC-4.3** Given the application's models and its configuration When the suite runs Then none uses Active Record encryption (`encrypts`, or its keys), and a model that begins to fails the suite until the procedure's secrets section and this spec's decision 3 say what the secret then protects
- [ ] **AC-4.4** Given the documents When they are read Then they name what the operator keeps outside the backup (the secret(s), the environment settings, the `compose.yaml` or `config/deploy.yml`) and say that a lost secret costs the sessions and nothing else

### Story 5: The procedure is documented and tested

**As an** operator, and as the maintainer
**I want** a documented procedure that is proven to work
**So that** I trust the backup before I need it

- [ ] **AC-5.1** Given `README.md` When it is read Then it has a "Backup and restore" section giving, for Docker Compose (and `podman compose`, naming the container for `podman cp`) and for Kamal, the commands to back up, to get the file out of the container and back in (with the ownership the container's user needs, decision 4), and to restore onto a fresh instance before its first start, with the stock `compose.yaml` and `config/deploy.yml` or a stated addition (a mounted backup directory; a `backup` alias); for each engine (Docker, Podman, rootless Podman with `:U` or `--userns=keep-id`) the copy-in step and its ownership (decision 4: a host directory `chown`ed to 1000 and mounted read-only, or `create` + `cp` + a `-u 0` `chown` one-off); for Kamal the sequence of decision 4 (`kamal server bootstrap`, the one-off `docker run` of the exact release over `ssh`, then `kamal setup` or `deploy`), with the statement that the exact `--version` or tag is required and that the Kamal path isn't exercised through Kamal itself; how to quote the task argument (no comma, quoted for the shell); what to keep outside the backup (AC-4.4); a suggested schedule (before every upgrade, and daily) and a cron line that avoids Monday 03:00 to 05:00 (decision 8); the checklist after a restore (compare the printed counts with what you expect, start, sign in, **Build art index**, check the settings); which release to restore onto (decision 10); what a backup doesn't hold; that the file is sensitive; the alternatives B, C and D of decision 1 as untested; and a link to the file layout and its manual recovery with `tar` and `sqlite3`
- [ ] **AC-5.2** Given a built image When `bin/backup-smoke <image>` is run Then it runs the two Collector tasks as `bin/image-smoke` runs its tasks (through the container engine, not Compose): boots a container with a volume, seeds a catalog entry, an admin and lots with `bin/rails runner`, polls `/up` while it runs `backup:create` into a mounted host directory (so the instance is seen answering throughout), copies the file out, removes the container and its volume, copies the file in **in the documented way of decision 4** (a host directory owned by uid 1000 and mounted read-only; and, in a second pass, `docker create` + `docker cp` + the `-u 0` `chown` one-off into a new volume), runs `backup:restore` as a one-off as uid 1000 with `SECRET_KEY_BASE_DUMMY=1` (no secret) from the file **copied in that way**, and asserts it succeeds, then starts the instance with a different `SECRET_KEY_BASE` and checks AC-2.3 and AC-4.2 (the sign-in made as a browser would, with its CSRF token); it exits non-zero naming the failing step on any miss, and takes an optional second image to restore into

- [ ] **AC-5.3** Given `.github/workflows/ci.yml` When it is read Then the image job runs `bin/backup-smoke` after `bin/image-smoke`, for each architecture, and a failure fails the job (verified by reading and by the first run)
- [ ] **AC-5.4** Given `bin/ci` When its RSpec step runs Then it runs the specs of Stories 1 to 4 that a container isn't needed for (everything except AC-2.3 and AC-4.2) and AC-5.5, against the file-backed test database without transactional fixtures (`VACUUM INTO` can't run in a transaction, and the concurrent writers of AC-1.2 and AC-1.3 use their own connections), with the restore's target directory an argument of the class beneath the task (not a setting) so that a scratch directory can stand for the volume; none of them needs a container engine or the network, or ImageMagick beyond what the art specs already need (AC-2.8)
- [ ] **AC-5.5** Given the guards When the suite runs Then it fails if the production configuration holds a database besides primary, queue, cache and cable, or if a model other than `ImportUpload` declares an Active Storage attachment, with a message naming this spec's decision 2 and the documents to update; and `ImportUpload`'s attachment is listed as transient with the reason (spec 028, ADR 0022)
- [ ] **AC-5.6** Once, before the spec ships, by the maintainer on their NAS, using the image built from this spec's branch (a released image has no `backup:create`): a backup of the running instance (Compose) is restored onto a fresh Compose project of the same image; the restored instance starts, the maintainer signs in, and their lots, accounts and catalog counts match the printed counts of the source; an export of each holds the same collection; steps, counts, timings and result are recorded in `verification.md` (decision 14)
- [ ] **AC-5.7** Given `docs/releasing.md` When it is read Then it adds a release check for each release after this one that changes the schema, the backup or the restore: restore the NAS instance's backup, taken on the previous release, onto the new image, and record it (decision 14; verified by reading)

### Story 6: Which one to use

**As a** collector or operator
**I want** to be told whether I need the export or the backup
**So that** I use the right one

- [ ] **AC-6.1** Given `README.md` When it is read Then its "Your data" part and its "Backup and restore" section each say which of the two to use for what, with the comparison of decision 11, and link to each other
- [ ] **AC-6.2** Given the app's routes, controllers and views When the suite lists them Then none is named for a backup (`backup` in a route, controller or view name) and no route runs the two tasks: the commands run in the operator's shell, and the collector's pages are as they are

## Functional Requirements

- **FR-1** `backup:create[DIRECTORY]` takes a consistent snapshot of the primary database in one read transaction, written into `DIRECTORY` under a unique `.partial` name, verifies it (integrity and foreign-key checks), writes the archive (decision 5) beside it, and renames the archive into place. Both temporary files are created mode 0600 and the archive is `fsync`ed before the rename (decision 7). On any failure the run removes its own `.partial` files. It opens snapshots with `SQLite3::Database`, never Active Record (decision 6). It stops no job, no request and no process, takes no write lock, and holds no transaction open longer than the copy. It refuses to start for the destination errors of AC-1.11.
- **FR-2** `backup:restore[FILE]` checks, in this order and before it writes anything on the volume: that the volume is fresh (decision 6); then the file's kind, in this classification order: (1) **not a backup**: not gzip magic, or gzip whose first tar entry isn't `manifest.json` (this includes a text file and a JSON export, which gets the **Import collection** hint, AC-3.3); (2) **incomplete**: gzip and tar that start as a backup but end early, fail the CRC or length check, or are named `*.partial` (AC-3.1); (3) a manifest naming an unknown backup format version (AC-3.4); and then that the volume has room for the snapshot. It then extracts the snapshot to one temporary file on the volume (a fixed name, removed with its `-journal` on any refusal) and checks the checksum, SQLite's integrity and foreign-key checks, and the schema (decision 10). Only after all pass does it end every session in the snapshot (decision 3), close it in rollback-journal mode with no `-wal` file, `fsync` it and rename it into place. Its only writes on the volume before the rename are that temporary file and its `-journal` (the session delete is a write that creates the journal; a kill during it can leave one, which the next restore removes).

- **FR-3** Neither command changes any row of the live instance's databases. The restore changes one row set, in the snapshot it places: it deletes the `sessions` rows with foreign keys on, which cascades to `bulk_removals`, `bulk_selections` and `bulk_selection_marks` (decision 3). Neither command calls Scryfall or any network service.
- **FR-4** A refusal is a plain sentence naming what is wrong and a sentence saying what to do, never an exception class or a backtrace (the style of catalog failures, issue #84). Every refusal exits non-zero and leaves the volume as it was.
- **FR-5** Core code names no collectible: the commands and their files under `app/` and `lib/` contain neither `MTG` nor `Scryfall` (a spec in the style of spec 025 FR-9). The art index appears only in the documents and in AC-2.8, through the app's existing build.
- **FR-6** Everything the commands know about the instance's data is the database's own: no file is walked, listed or deleted under `storage/` (ADR 0022). `backup:create` deletes only a `.partial` file of its own name pattern in the destination, older than a day, and its own temporary files. `backup:restore` deletes only its own temporary file and that file's `-journal` on the volume (the freshness test ignores both by name) and the `sessions` rows (and their cascade) of FR-3.
- **FR-7** The backup format, the manifest's fields and the file layout are documented in a document beside the procedure, with the backup format version's rule (a released version never changes meaning) and the manual recovery with `tar` and `sqlite3`.
- **FR-8** `backup:restore` never opens a connection to the primary database's configured path (opening one would create an empty file that the next `db:prepare` would mistake for an instance, and whose first visitor would become admin). It reads the path from the configuration, takes the release's migrations from the migration files without connecting (`ActiveRecord::MigrationContext#migrations` reads files only; the plan doesn't reach for `ActiveRecord::Base.connection.migration_context`), and opens only its own temporary file.
- **FR-9** `bin/backup-smoke` and its step in the image job of `.github/workflows/ci.yml` exist as AC-5.2 and AC-5.3 describe, and are documented in `CLAUDE.md`'s commands next to `bin/image-smoke`.
- **FR-10** No secret is written into a backup, printed, or logged by either command (AC-1.7, AC-1.8, AC-4.1).

## Non-Functional Requirements

- **Cost per account (hosted-door rule 4).** Per account: the account's rows in the primary database, so a backup's size grows with the number of lots and accounts, in storage the operator chooses. No background work per account, none for the instance: backups run when the operator runs them, and nothing is added to `config/recurring.yml`. Per run: one read of the whole primary database and one write of the snapshot and of the archive (so twice the database's size of free disk in the destination); the bars of decision 13 hold it to 5 minutes for an instance with the English catalog and 50,000 lots. While a backup runs its read transaction holds the WAL back, so the `-wal` file grows with the writes of those minutes.
- **Hosted-door rules.** Rule 1: no source is adopted. Rule 2: the commands are the operator's, not a page; they read and write the database as an opaque file and show no item of a collection, only counts of accounts, users and lots (AC-1.7), and no admin page or task lists, opens or edits one. A hosting operator's backups for customers remain after 1.0. Rule 3: no setting or environment variable is added; the destination and the file are arguments of a command the operator runs. Rule 4: as above.
- **Data safety.** A backup that can't be restored is never reported as made (decision 7); a restore that can't complete leaves the volume empty rather than half-filled (decisions 6 and FR-8); no restore overwrites an instance (AC-2.5); no command runs `db:schema:load`, `db:reset` or `db:drop` (AC-3.6).
- **Security.** The backup file is sensitive and is written readable by its owner only; no secret is written into it or printed (FR-10); neither command logs content (AC-1.7); the commands take no input from a web request. Brakeman stays clean.
- **Self-hosting and upgrades.** The restore works on a release newer than the backup's through the existing boot path (decision 10). No migration is added. Upgrade notes in `docs/releasing.md` announce the commands. The image already carries `sqlite3`; nothing is added to the image. The container runs as uid 1000, so the destination must be writable by it and a copied-in backup readable by it (decision 4).
- **Testability.** Specs for each task and for the guards (AC-5.4), one spec that runs the documented round trip through `CollectionExport` (AC-2.2), and `bin/backup-smoke` for the image (decision 9).

## Error Scenarios

| Situation | What happens |
|---|---|
| The destination doesn't exist, isn't writable by the container's user, or has less free space than twice the primary database's size | `backup:create` exits non-zero saying which, writes nothing, and leaves the instance unaffected (AC-1.11) |
| `VACUUM INTO` fails (a damaged database), or the snapshot fails the foreign-key check | A failed backup: no final file, no `.partial`, a plain message; for a foreign-key failure it points to each collector's export (AC-1.5, AC-1.12) |
| The backup run is killed (the container stops, the disk fills) | At worst a `.partial` file remains, never a file with a final name; the instance is unaffected (AC-1.6) |
| A write by the app lands during the backup | It runs; the snapshot holds it whole or not at all (AC-1.2, AC-1.3) |
| The destination already holds the file the run would write | The file is untouched; the run fails saying so (AC-1.9) |
| The file was truncated by a failed copy, or is a `.partial` file | Refused as incomplete; nothing is written (AC-3.1) |
| A byte of the snapshot changed | Refused on its checksum; nothing is written (AC-3.2) |
| The file isn't a backup (text, other gzip, a tar without `manifest.json`), or is a Collector export | Refused; for an export, the message points to **Import collection** (AC-3.3) |
| The backup format version is unknown | Refused naming the versions this release restores (AC-3.4) |
| The backup was taken by a newer release | Refused, naming both schema versions and saying to restore onto that release or newer (AC-3.5) |
| The backup is from an older release | Restored as it is; the first start migrates it (AC-3.6) |
| The snapshot is damaged inside a well-formed archive | Refused; nothing is written (AC-3.7) |
| The volume isn't fresh: a primary database, a `-wal` or `-shm` file, or another of the four databases is there | Refused; every file is untouched (AC-2.5) |
| The restore is killed after the snapshot is written to its temporary name | No primary database exists; the next restore removes the leftover and succeeds (AC-2.6) |
| The restore is run against a volume whose app has already started once (so `db:prepare` created the four databases) | Refused as in AC-2.5; the documents restore before the first start, and an operator who started first restores onto a new volume |
| The restore is run against the wrong volume (for example a Compose project name that differs from the one the instance runs under) | It restores into that volume and prints its path and the counts; the documents tell the operator to compare them before starting, because an instance started on a different, empty volume would be blank and open to the first visitor |
| The backup is of an instance with no users | Restored; the message says the first person to reach it becomes its admin (AC-2.11) |
| Sessions are cleared on restore | Pending bulk-removal Undos and bulk selections go with them (decision 3, AC-2.1); the message says so |
| A restored instance is started with another `SECRET_KEY_BASE`, or its secret is lost | Data is intact; old session cookies stop working and everyone signs in again (AC-4.2) |
| A restored instance is started with another `COLLECTOR_CURRENCY` or `COLLECTOR_MTG_LANGUAGES` | Prices show with the other symbol (README); a language change takes effect at the next refresh. The documents list the settings to carry over (AC-4.4) |
| A restore of a backup that was taken during a catalog refresh or art build | The run reads as interrupted by spec 015's rules and can be started again (AC-2.9); the art index file is rebuilt by **Build art index** (AC-2.8) |
| A restore of a backup that held a stored import upload | The upload's file is absent: an apply says "Preview the file again." and the sweep removes the row once it has expired (AC-2.10) |
| A backup restored onto a host of another CPU architecture | Works: the snapshot is a SQLite file and carries no architecture; `bin/backup-smoke` runs on both |
| The operator wants to restore over a live instance | Not supported (decision 6): restore onto a new volume and switch to it |

## Supersedes

Nothing in a shipped spec. ADR 0016's consequence "The mechanism, and whether a backup includes those files, is undecided" is closed by the ADR this spec owes (decisions 1 and 2), and `docs/adr/README.md`'s "Expected" line is updated; the ADR isn't edited (`docs/adr/README.md`: to change a decision, write a new ADR). `.claude/rules/sqlite-and-migrations.md` names "Litestream or `.backup`" as examples and is updated to point to the ADR.

## Documents that change

- `compose.yaml` and `config/deploy.yml`: the stated addition of decision 4, if the plan makes one (a backup directory mount; the Kamal alias), with the README kept in step.
- `README.md`: a "Backup and restore" section (AC-5.1), the "Your data" part's pointer and comparison (AC-6.1), and the Compose bullet that says "Back up this volume" (`README.md` has one; the Kamal part says only where the data is, and gets a pointer to the section).
- `docs/backup-restore.md`: the file layout, the manifest, the backup format version rule and the manual recovery with `tar` and `sqlite3` (FR-7), linked from the README.
- `docs/releasing.md`: the maintainer's restore as a release check (AC-5.6, decision 14), and an upgrade note announcing the two commands.
- `docs/adr/`: the backup mechanism ADR (decisions 1 to 3 and 5 to 7), numbered with the next free number on `origin/main` when it is written, and its line in `docs/adr/README.md` (the "Expected" line goes).
- `docs/roadmap.md`: theme A item 6 marked done.
- `CLAUDE.md`: the status line, and a "Backup and restore" fact in Non-obvious Facts (what a backup holds, the two tasks, that restore needs an empty volume).
- `.claude/rules/sqlite-and-migrations.md`: the example mechanisms point to the ADR.
- `docs/architecture/`: the release-and-deploy area doc when it exists (spec 027 slice C, #109), else it stays listed as not written.
- `docs/specs/README.md`: this spec's row (done with the draft).
- `.github/workflows/ci.yml`: the `bin/backup-smoke` step (AC-5.3); `bin/backup-smoke` itself, listed in `CLAUDE.md`'s commands (FR-9).

Each is verified by reading, except the workflow and the script, which the first CI run proves.

## Open Questions

None. The maintainer ruled on 2026-10-21: decision 1 option A, decisions 2 and 3, and decisions 4 to 15 as recommended in 1.1.0, except decision 4's Kamal restore sequence, ruled as option (a) (`kamal server bootstrap`, a one-off `docker run` of the exact release over `ssh`, then `kamal setup`; the plan confirms that a production boot of the rake task doesn't read `secret_key_base` eagerly). No Kamal host is available to the maintainer, which is why the Kamal path is documented and not exercised through Kamal itself (decision 4). Decision 15 stands: backup and restore are one outcome, one spec. The maintainer approved the spec on 2026-10-21.

## Out of Scope

Hosted-service backups, a scheduler or retention inside the app, an admin page or route for backups, replication and point-in-time recovery, volume copies and host snapshots as supported mechanisms, encrypting the backup file, backing up the queue, cache and cable databases or the catalog downloads or Active Storage files, restoring over a live instance or one account out of a backup, restoring onto an older release, the previous-release upgrade proof (#42), a version shown in the app, and any change to the export format.
