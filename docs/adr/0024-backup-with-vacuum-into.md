# 0024: Back up the primary database online with `VACUUM INTO`, restore only onto a fresh volume

## Status

Accepted (2026-10-21). Written with the plan for spec 030; the maintainer ruled decisions 1 to 3 of the spec on 2026-10-21 (and confirmed 4 to 15) when approving spec 030 1.2.1, and accepted this ADR with the plan on 2026-10-21. It was numbered 0024 because 0023 is taken by the unmerged `029-manage-locations` branch (ADR 0023, locations make export-format version 2); a branch that merges first takes the number, and this ADR takes the next free one when it is rebased.

**Date:** 2026-10-21
**Feature:** 030-backup-restore

## Context

All of an instance lives in one SQLite file on one host's volume ([ADR 0016](0016-sqlite-in-every-environment.md)): the accounts, the users, the lots, the settings and, because `lots` has a foreign key to `catalog_entries`, the global catalog. ADR 0016 named backing up "the primary database" as the only backup needed and left "the mechanism, and whether a backup includes those files" undecided. This ADR decides both. `README.md` says only "Back up this volume".

Facts that shape the decision (research.md in spec 030 has the traces):

- Production runs SQLite in WAL mode, so copying the files of a running database yields a copy that may not be consistent; Solid Queue runs inside Puma and writes the queue database continuously.
- `VACUUM INTO 'file'` writes a transactionally consistent, compacted copy from one read snapshot in a single statement, and writers keep going in WAL mode. The `sqlite3` gem (2.10.0) and the image's `sqlite3` command already exist.
- The Rails SQLite adapter sets `journal_mode: :wal` on every connection and `SQLite3::Database.new` creates a missing file, so a snapshot opened through Active Record would be converted to WAL, and opening the primary's path from a restore would create an empty database that the next `bin/rails db:prepare` takes for a blank instance (`DatabaseTasks.initialize_database` loads `db/schema.rb` when `schema_migrations` is absent) whose first visitor becomes its admin.
- A rake task that doesn't depend on `:environment` doesn't initialize the application; the application's initializers read `secret_key_base` eagerly (`active_storage.verifier` calls `app.message_verifier`, whose generator reads it in `after_initialize`).
- No model encrypts anything, every secret stays outside the database, and the only Active Storage attachment is spec 028's one-hour import upload (ADR 0022).

## Options considered

### Option A: An online snapshot with `VACUUM INTO`, run by a rake task in the running container (chosen)

**Pros:** one consistent point-in-time file without stopping the app; one procedure to document and test for Compose and Kamal; no new service, gem or image change.
**Cons:** a full rewrite, so it costs the database's size in time and temporary disk (the catalog makes it large); the read transaction holds the WAL back while it runs; no point-in-time recovery between backups.

### Option A': SQLite's online backup API (`sqlite3_backup_*`, the `.backup` command)

Considered inside A. Run incrementally (100 pages a step, as `.backup` does) it restarts whenever another connection writes between steps, so a busy instance can starve it; a single `step(-1)` doesn't restart but `VACUUM INTO` reads one snapshot in one statement and compacts the copy. Not chosen.

### Option B: Stop the app and copy the volume

**Pros:** nothing to build. **Cons:** downtime; a Compose named volume is awkward to reach from the host; copying the files of a running database corrupts the copy and nothing stops the operator doing that; the copy carries the other three databases and the downloads. Not chosen as the supported way; named in the documents.

### Option C: Litestream

**Pros:** continuous, point-in-time. **Cons:** a second long-running process in every deployment, an object store or other replica target, and a binary the image lacks; a restore needs it too. More than a 1.0 self-hoster needs. Named in the documents as an alternative, untested.

### Option D: Host volume snapshots (ZFS, LVM, btrfs)

**Pros:** fast, crash-consistent for WAL. **Cons:** only for operators who have them; the app can't test them; they copy the whole `storage/` volume. Named in the documents, untested.

## Decision

1. **Mechanism (spec decision 1, ruled).** `bin/rails "backup:create[DIRECTORY]"` takes `VACUUM INTO` of the primary database into a snapshot in `DIRECTORY`, verifies it (`PRAGMA integrity_check`, `PRAGMA foreign_key_check`), and archives it. B, C and D are documented as operator alternatives the app doesn't test.
2. **Contents (spec decisions 2 and 3, ruled).** One file holds the primary database whole (accounts, users, lots, settings, sessions, working lists and the catalog) and a manifest. It holds no secret, no Active Storage file, no download, no art image or index, and none of the queue, cache or cable databases. A restore ends every session (`DELETE FROM sessions` with foreign keys on, which cascades to the bulk removals and selections). A new database beyond the four, or a collector-owned attachment, fails the suite until the procedure says what the backup does with it.
3. **Format (spec decision 5).** `collector-backup-YYYYMMDDTHHMMSSZ.tar.gz`: a gzip'd ustar of `manifest.json` then `primary.sqlite3`, written under a random `.partial` name created 0600, fsynced, read back, and linked to its final name only when verified, never replacing a file (a rename only where a share can't link). The backup format has its own version number; a released version never changes meaning. The layout is documented so `tar` and `sqlite3` recover a database without this app.
4. **Restore (spec decisions 6 and 7).** `bin/rails "backup:restore[FILE]"` restores only onto a fresh volume (none of the four databases, no `-wal`, `-shm` or `-journal`), through a temporary file it links into place after every check, and never opens a connection to the primary's path. It refuses a damaged, partial, wrong-format or newer-release file with a plain message, and never migrates (the first boot's `db:prepare` does, as for an upgrade). Snapshots are opened with `SQLite3::Database`, never Active Record.
5. **Where the code lives (the plan's decision, traced from the above).** The two tasks don't depend on `:environment`; their code is in `lib/collector/backup/` (stdlib, `sqlite3` and the database configuration only), `require`d by `lib/tasks/backup.rake`. They therefore boot nothing: no initializers, no queue or cache connection, no `secret_key_base` (so `SECRET_KEY_BASE_DUMMY` is not needed, though the documented one-off keeps it as the maintainer ruled), and no Active Record connection that could create the primary's file. Archive writing and reading use `Zlib` and `Gem::Package::TarWriter`; no gem is added.

## Consequences

- **Good:** an operator can back up a running instance and restore it on a new host with two commands, documented for Compose and Kamal and proven in CI against a built image and once by hand on the maintainer's own collection. A refusal never leaves a half-restored or blank-looking instance.
- **Good:** ADR 0016's open consequence is closed; `docs/adr/README.md`'s "Expected" line loses the backup mechanism; `.claude/rules/sqlite-and-migrations.md` points here.
- **Cost:** a backup is a full rewrite and holds the WAL back while it runs (up to 5 minutes at the 50,000-lot bar), so the schedule avoids Monday 03:00 to 05:00, when the weekly catalog refresh writes the most. The temporary disk is twice the database's size, checked before it starts.
- **Cost:** no restore over a live instance, no restore of one account, no restore onto an older release, no point-in-time recovery; an operator who wants any of these uses an alternative of B to D or restores onto a new volume and switches to it.
- **Limit:** the Kamal path is documented and its container command is tested, but it isn't exercised through Kamal itself (no Kamal host).
- **Follow-up:** a hosting operator's backups for customers (after 1.0, north star); the art index "ready" wording when its file is missing is a separate issue (spec 030 decision 12).
