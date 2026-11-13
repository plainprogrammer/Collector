# Backup file and manual recovery

How the backup file made by `bin/rails "backup:create[DIRECTORY]"` is laid out, and how to get a database out of it without Collector. The procedure (how to back up and restore, for Compose, Podman and Kamal) is in the [README](../README.md#backup-and-restore); the decisions are in [ADR 0024](adr/0024-backup-with-vacuum-into.md), [ADR 0029](adr/0029-prices-database-held-by-the-backup.md), [spec 030](specs/030-backup-restore/spec.md) and [spec 081](specs/081-prices-database-in-backup/spec.md).

## The file

`collector-backup-YYYYMMDDTHHMMSSZ.tar.gz`: the UTC time the backup started, to the second, with no colon (a colon breaks `docker cp`, `scp` and Windows shares). While it is being made it has a `.partial` name ending in a random part; only a finished, verified backup is linked to the final name, and a final name is never replaced.

It is a gzip-compressed tar of these files, in this order, each mode 0600 (backup format version 2, spec 081 decision 6):

| File | What it is |
|---|---|
| `manifest.json` | What the backup holds and how to check it (below) |
| `primary.sqlite3` | A SQLite database: the instance's primary database at one moment, in rollback-journal mode (no `-wal` or `-shm`) |
| `prices.sqlite3` | A SQLite database: the instance's prices database (market prices and their history, which can't be downloaded again), in rollback-journal mode. It is taken right after the primary, seconds later, not at the same moment; nothing ties the two files together |

Nothing else is in it: no secret, no setting, no queue, cache or cable database, no catalog download, no art image or index, no Active Storage file.

**Version 1**, written by releases before spec 081, has `manifest.json` and `primary.sqlite3` only. A release restores every version it has shipped, so a version 1 file still restores: it places the primary only, and Collector's first start creates an empty prices database. A release that knows only version 1 refuses a version 2 file as a version it doesn't know.

## The manifest

| Member | Meaning |
|---|---|
| `backup_format_version` | `2` (`1` before spec 081). The backup format's own whole number, apart from the export format's `format_version`. A released version never changes meaning; a release restores every version it has shipped and refuses one it doesn't know |
| `taken_at` | When the backup started, UTC, RFC 3339 |
| `schema_version` | The newest migration the snapshot has run (`schema_migrations.version`) |
| `snapshot_bytes` | The size of `primary.sqlite3` |
| `snapshot_sha256` | The SHA-256 of `primary.sqlite3` |
| `counts` | `{ "accounts": n, "users": n, "lots": n }`, counted in the snapshot |
| `prices` | Version 2 only: `{ "schema_version", "snapshot_bytes", "snapshot_sha256", "counts": { "current_prices": n, "price_changes": n } }`, each as the members above but for `prices.sqlite3`; the schema version is the newest of `db/prices_migrate/` |

The members above `prices` always describe `primary.sqlite3`.

## What a restore checks

In this order, before it changes the volume: the volume is empty (none of the five databases, primary, prices, queue, cache and cable, and no `-wal`, `-shm` or `-journal` file); the file is a Collector backup and isn't named `*.partial`; its format version is known; the volume has room for both snapshots (checked as soon as the manifest is read); then the file is read to its end, which finds a cut-short file and checks both checksums. Then, on a temporary file for each snapshot in the volume: SQLite's integrity check and foreign-key check, that no migration is newer than the release's (the primary's against `db/migrate/`, the prices database's against `db/prices_migrate/`), then every session is ended in the primary (which cascades to the bulk removals and selections; nothing is cleared in the prices database), the counts agree with the manifest, and the files are linked to their final names, the prices database first and the primary last, never replacing a file. A restore that stops on a refusal or an error leaves neither database: if the primary can't be placed, the prices file it placed is removed (spec 081 decision 8).

**A restore that was killed** (a power loss, `kill -9`) between the two placings can leave `production_prices.sqlite3` alone on the volume, with no primary. The next restore refuses that volume and says so. **A start of Collector refuses such a volume too** (a container started with the image's default command, or any command that ends in `./bin/rails server`; spec 086 FR-1 to FR-3, issue [#375](https://github.com/plainprogrammer/Collector/issues/375)). It runs before `db:prepare`, exits with status 1 and creates nothing, and its message on standard error says three things: what it found (the storage directory, the prices file or the sidecar present, and no primary database), why it stops (a start would create a new, blank primary, whose first visitor becomes its admin, and keep the stale prices, which the new catalog's ids would attach to the wrong printings) and what to do. Remove `production_prices.sqlite3` and its `-wal`, `-shm` and `-journal` files, then restore again onto a volume that holds no other Collector database, or start blank, and run nothing else on the volume meanwhile. A primary that is an empty file or a dangling link counts as no primary, and the message names it among the files to remove (spec 086 decision 7). A one-off command such as `backup:restore` isn't checked; the next restore refuses the volume itself.

## Manual recovery with `tar` and `sqlite3`

You don't need Collector to open a backup:

```sh
tar -xzf collector-backup-20261021T142100Z.tar.gz        # manifest.json, primary.sqlite3 and prices.sqlite3
cat manifest.json
sha256sum primary.sqlite3 prices.sqlite3                 # the manifest's snapshot_sha256 and prices.snapshot_sha256
sqlite3 primary.sqlite3 "PRAGMA integrity_check;"        # ok
sqlite3 prices.sqlite3 "PRAGMA integrity_check;"         # ok
sqlite3 primary.sqlite3 "SELECT COUNT(*) FROM lots;"
sqlite3 prices.sqlite3 "SELECT COUNT(*) FROM price_changes;"
```

To put it on a new instance by hand, instead of `backup:restore`: stop Collector; the volume must hold no Collector database or `-wal`, `-shm` or `-journal` file; copy `primary.sqlite3` to `<volume>/production.sqlite3` and `prices.sqlite3` to `<volume>/production_prices.sqlite3`, each with owner uid 1000 (`chown 1000:1000`); and, to end the sessions as `backup:restore` does, `sqlite3 <volume>/production.sqlite3 "PRAGMA foreign_keys = ON; DELETE FROM sessions;"`. Then start Collector: its first start creates the other three databases (and an empty prices database, for a version 1 backup) and migrates the restored ones if the backup is from an older release. Never copy in a prices database without its primary. The export of each collector is the other way to get a collection out ([export format](export-format/README.md)).
