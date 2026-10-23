# Backup file and manual recovery

How the backup file made by `bin/rails "backup:create[DIRECTORY]"` is laid out, and how to get a database out of it without Collector. The procedure (how to back up and restore, for Compose, Podman and Kamal) is in the [README](../README.md#backup-and-restore); the decisions are in [ADR 0024](adr/0024-backup-with-vacuum-into.md) and [spec 030](specs/030-backup-restore/spec.md).

## The file

`collector-backup-YYYYMMDDTHHMMSSZ.tar.gz`: the UTC time the backup started, to the second, with no colon (a colon breaks `docker cp`, `scp` and Windows shares). While it is being made it has a `.partial` name ending in a random part; only a finished, verified backup is linked to the final name, and a final name is never replaced.

It is a gzip-compressed tar of two files, in this order, each mode 0600:

| File | What it is |
|---|---|
| `manifest.json` | What the backup holds and how to check it (below) |
| `primary.sqlite3` | A SQLite database: the instance's primary database at one moment, in rollback-journal mode (no `-wal` or `-shm`) |

Nothing else is in it: no secret, no setting, no queue, cache or cable database, no catalog download, no art image or index, no Active Storage file.

## The manifest

| Member | Meaning |
|---|---|
| `backup_format_version` | `1`. The backup format's own whole number, apart from the export format's `format_version`. A released version never changes meaning; a release restores every version it has shipped and refuses one it doesn't know |
| `taken_at` | When the backup started, UTC, RFC 3339 |
| `schema_version` | The newest migration the snapshot has run (`schema_migrations.version`) |
| `snapshot_bytes` | The size of `primary.sqlite3` |
| `snapshot_sha256` | The SHA-256 of `primary.sqlite3` |
| `counts` | `{ "accounts": n, "users": n, "lots": n }`, counted in the snapshot |

## What a restore checks

In this order, before it changes the volume: the volume is empty (none of the four databases and no `-wal`, `-shm` or `-journal` file); the file is a Collector backup and isn't named `*.partial`; its format version is known; the volume has room (checked as soon as the manifest is read); then the file is read to its end, which finds a cut-short file and checks the checksum. Then, on a temporary file in the volume: SQLite's integrity check and foreign-key check, that no migration is newer than the release's, then every session is ended (which cascades to the bulk removals and selections), the counts agree with the manifest, and the file is linked to its final name, never replacing a file. A restore that stops anywhere leaves no primary database.

## Manual recovery with `tar` and `sqlite3`

You don't need Collector to open a backup:

```sh
tar -xzf collector-backup-20261021T142100Z.tar.gz        # manifest.json and primary.sqlite3
cat manifest.json
sha256sum primary.sqlite3                                # the manifest's snapshot_sha256
sqlite3 primary.sqlite3 "PRAGMA integrity_check;"        # ok
sqlite3 primary.sqlite3 "SELECT COUNT(*) FROM lots;"
```

To put it on a new instance by hand, instead of `backup:restore`: stop Collector; the volume must hold no Collector database or `-wal`, `-shm` or `-journal` file; copy `primary.sqlite3` to `<volume>/production.sqlite3` with owner uid 1000 (`chown 1000:1000`); and, to end the sessions as `backup:restore` does, `sqlite3 <volume>/production.sqlite3 "PRAGMA foreign_keys = ON; DELETE FROM sessions;"`. Then start Collector: its first start creates the other three databases and migrates this one if the backup is from an older release. The export of each collector is the other way to get a collection out ([export format](export-format/README.md)).
