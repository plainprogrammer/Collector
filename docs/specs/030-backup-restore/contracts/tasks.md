# Contract: the two rake tasks

**Spec requirements:** decisions 4, 6, 7, FR-1 to FR-4, FR-8, FR-10, AC-1.x, AC-2.x, AC-3.8.

Both run in the operator's shell inside the Collector container (or a one-off of the same image). Neither depends on Rake's `:environment` task, so neither initializes the application (no initializers, no Solid* connection, no `secret_key_base`; research.md section 1 and 2). Neither adds a setting.

## `bin/rails "backup:create[DIRECTORY]"`

| | |
|---|---|
| Argument | `DIRECTORY`, required: an existing directory the container's user can write. No default. A comma splits a rake argument, so a path holding one is refused (the sentence below) |
| Source | The primary database of `Rails.env`, read from `config/database.yml` (`storage/production.sqlite3` in the image) |
| Output on success (stdout) | `Backup written: <path>` / `Size: <size>` / `Schema version: <version>` / `Holds: <n> accounts, <n> users and <n> lots` / `Took: <seconds> s` |
| Exit | 0 on success; 1 on any refusal |
| Output on refusal (stderr) | Two lines: what is wrong, what to do. No exception class, no backtrace |

### Refusals of `backup:create` (problem / advice)

| Case | Problem | Advice |
|---|---|---|
| No argument | "No directory was given." | `Run: bin/rails "backup:create[/path/to/directory]".` |
| A comma in the argument | "The directory argument contains a comma, which Rake reads as a second argument." | "Use a path without a comma." |
| Doesn't exist or isn't a directory | "<dir> doesn't exist or isn't a directory." | "Create it, or give another directory." |
| Not writable | "<dir> isn't writable by the user Collector runs as (uid <n>)." | "Make it writable by that user (for example `chown 1000:1000`), or give another directory." |
| Too little space | "<dir> has <free> free; a backup needs about <need> (twice the database's size)." | "Free some space, or give a directory on a larger disk." |
| No source database | "There is no primary database at <path>." | "Run this inside the running Collector container, with its storage volume mounted." |
| Name taken | "A file named <name> already exists in <dir>; it was left as it is." | "Run it again in a second, or give another directory." |
| `VACUUM INTO` or the read-back finds damage (`SQLITE_CORRUPT`, not a database) | "The database reports damage, so no backup was made." | "Restore the last good backup, and ask each collector to download their export (Export collection) while the instance still answers." |
| Foreign-key check fails | "The database fails its foreign-key check (<n> rows), so no backup was made." | "Each collector's export (Export collection) is still available; a backup of an instance in this state would be refused when restored." |
| Busy beyond the timeout | "The database stayed busy for more than 5 seconds." | "Run it again in a quieter moment." |
| Disk full while writing | "The disk filled up while the backup was written." | "Free some space and run it again." |
| Anything else the system or SQLite reports | see "An error nothing names" below | |

## `bin/rails "backup:restore[FILE]"`

| | |
|---|---|
| Argument | `FILE`, required: a backup made by `backup:create` (any release that knows its format version), readable by the container's user |
| Target | The primary database's configured path. Its directory is "the volume" |
| Output on success (stdout) | `Restored <file name> into <volume>.` / `Taken <taken_at> at schema version <version>; it holds <n> accounts, <n> users and <n> lots. Compare these with what you expect before you start Collector.` / `Everyone signs in again, and pending bulk-removal Undos and selections are gone; no collection is lost.` / `Start Collector now. With art matching on, press Build art index on the admin catalog page to rebuild the scanner's art index.` and, for a backup with no users, `The backup holds no users: the first person to reach the restored instance becomes its admin.` |
| Exit | 0 on success; 1 on any refusal |
| Order (FR-2) | volume fresh → file exists, is readable, and the volume is writable → file kind, then `*.partial` (incomplete), then format version → **room for the snapshot, as soon as the manifest is parsed** (inside the first pass over the archive; maintainer's ruling, plan-review m3) → the rest of the file, which finds a cut-short file and computes the checksum → checksum → remove a leftover temporary file → extract to `collector-restore.partial` (0600) → integrity and foreign-key checks → schema rule → end sessions (foreign keys on) → rollback-journal mode → counts equal the manifest's → fsync → link into place (never replacing a file) |
| Writes before the link | Only `collector-restore.partial` and its `-journal`, in the volume. The restore never opens a connection to the primary's path (FR-8) |

### Refusals of `backup:restore` (problem / advice)

| Case | Problem | Advice |
|---|---|---|
| No argument / comma | as above, with `backup:restore[/path/to/file]` | |
| Volume not fresh (AC-2.5) | "The volume at <dir> isn't empty: it holds <names>." | "Restore onto a new, empty volume and start Collector on that. Nothing was changed." |
| Storage directory missing | "The storage directory <dir> doesn't exist." | "Mount the volume where Collector expects it, then run this again." |
| No such file | "There is no file at <path>." | "Check the path as the container sees it; copy the backup in first." |
| File exists but the user can't read it (`docker cp` makes root-owned files, the backup is 0600) | "<path> can't be read by the user Collector runs as (uid <n>)." | "Give it to that user (chown 1000:1000), as the README's restore steps do, then run this again. Nothing was changed." |
| Volume not writable by the user (a bind mount owned by root) | "The volume at <dir> isn't writable by the user Collector runs as (uid <n>)." | "Give the volume to that user (chown 1000:1000), then run this again. Nothing was changed." |
| Not a backup (AC-3.3) | "<name> isn't a Collector backup." | "Give a collector-backup-….tar.gz file made by backup:create." |
| An export file | "<name> is a Collector export file, not a backup." | "Import it in the app with Import collection (More, then Import collection)." |
| Incomplete (AC-3.1) | "<name> is incomplete; it was cut short or is still being written." | "Take the backup again, or copy it again." |
| Unknown format version (AC-3.4) | "<name> uses backup format version <n>; this release restores version(s) <list>." | "Restore it with a release that knows that version." |
| Checksum (AC-3.2) | "<name> doesn't match its checksum; it was changed or damaged after it was made." | "Use another copy of the backup." |
| Newer release (AC-3.5) | "<name> was taken by a newer release of Collector (schema version <theirs>; this release has <ours>)." | "Restore it onto that release or a newer one." |
| Snapshot damaged (AC-3.7) | "The database inside <name> is damaged." | "Use another copy of the backup." |
| No room | "The volume at <dir> has <free> free; the snapshot needs <need>." | "Free some space or use a larger volume." |
| Counts differ after the clearing | "The restored database doesn't match the backup's counts." | "Use another copy of the backup." (a defence, not a case the spec's criteria reach) |

### An error nothing names (both tasks)

A `SystemCallError` or `SQLite3::Exception` that no command rescued (`Errno::EACCES` from a directory ACL, a failing disk) is caught by `Backup.run` and printed as two lines, exit 1, with no class and no frames: "The command stopped: <the error's own words, without Ruby's `@ rb_sysopen - path` tail>." / "It left nothing half-made; check that the directories and files involved are readable and writable by the user Collector runs as (uid <n>) and have room, then run it again." Each command removes its own temporary files and places nothing until every check has passed, so it leaves nothing half-made; the line does not say "nothing was changed", because an error after the database was placed (the directory fsync) is still possible.

Every refusal leaves the volume as it was (AC-2.5, AC-2.6): checked by checksum of every file before and after, and by the absence of `production.sqlite3` and its sidecars.

## Classes behind them (Phase 0 to 4)

`Collector::Backup` (`lib/collector/backup.rb`) and, under `lib/collector/backup/`: `Refusal`, `Databases`, `FreeSpace`, `Manifest`, `Archive`, `Snapshot`, `Create`, `Restore`. Signatures are in plan.md's phases. The tasks (`lib/tasks/backup.rake`) hold no logic beyond printing, exiting and reading the argument.
