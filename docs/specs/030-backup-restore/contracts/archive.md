# Contract: the backup file

**Spec requirements:** decision 5, decision 7, FR-1, FR-2, FR-7, AC-1.1, AC-1.4, AC-3.1 to AC-3.4. The document `docs/backup-restore.md` (written in Phase 7) is this contract in the operator's words; this file is the contract the code and the specs are written against.

## File name

`collector-backup-YYYYMMDDTHHMMSSZ.tar.gz`, UTC, second precision, no colon. Pattern: `\Acollector-backup-\d{8}T\d{6}Z\.tar\.gz\z`.

Temporary names, in the destination directory only, each with a random part so two runs never share one (AC-1.9):

| Piece | Name | Mode | Removed |
|---|---|---|---|
| The snapshot while it is written and verified | `collector-backup-<time>.sqlite3.<16 hex>.partial` | 0600 from creation | by the run, always |
| The archive while it is written | `collector-backup-<time>.tar.gz.<16 hex>.partial` | 0600 from creation | by the run on failure; renamed away on success |

Pattern for both (the sweep of AC-1.6 and the restore's refusal of `*.partial`): `\Acollector-backup-\d{8}T\d{6}Z\.(?:tar\.gz|sqlite3)\.\h{16}\.partial\z`. The sweep removes a file of this pattern whose modification time is more than 24 hours old, and nothing else.

## Layout

A gzip stream holding a ustar tar of exactly two regular files, in this order, each mode 0600:

1. `manifest.json`, the manifest below, UTF-8 JSON.
2. `primary.sqlite3`, the snapshot: a SQLite database file in rollback-journal mode (header bytes 18 and 19 equal 1), no `-wal`, no `-shm`.

followed by tar's end-of-archive blocks. The manifest comes first so a reader classifies the file from its first 512 bytes (FR-2). Nothing else is in the archive (AC-1.4).

## Manifest, backup format version 1

Exactly these six members (AC-1.4):

| Member | Type | Meaning |
|---|---|---|
| `backup_format_version` | integer | `1`. Its own whole number, apart from the export format's `format_version` (decision 5). A released version never changes meaning |
| `taken_at` | string | RFC 3339, UTC, whole seconds, the moment the run started (the file name's time) |
| `schema_version` | string | The newest `schema_migrations.version` in the snapshot, as stored (14 digits) |
| `snapshot_bytes` | integer | Size of `primary.sqlite3` |
| `snapshot_sha256` | string | 64 lower-case hex digits, SHA-256 of `primary.sqlite3` |
| `counts` | object | `{ "accounts": n, "users": n, "lots": n }`, counted in the snapshot. Counts only (hosted-door rule 2) |

```json
{
  "backup_format_version": 1,
  "taken_at": "2026-10-21T14:21:00Z",
  "schema_version": "20261020100002",
  "snapshot_bytes": 52428800,
  "snapshot_sha256": "9f2b…",
  "counts": { "accounts": 1, "users": 1, "lots": 4210 }
}
```

A reader that doesn't know `backup_format_version` refuses before it looks at any other member (AC-3.4). A reader of a version it knows refuses a manifest whose members differ from the table.

## Classification of a file given to `backup:restore` (FR-2, in this order)

| # | The file | Verdict | Refusal |
|---|---|---|---|
| 1 | doesn't start with the gzip magic `1f 8b`; or is gzip whose first tar block isn't a ustar header for `manifest.json`; or has a manifest that doesn't parse; or has a second entry that isn't `primary.sqlite3` | not a backup | "isn't a Collector backup" (export JSON gets the **Import collection** sentence) |
| 2 | starts as a backup (gzip, first entry `manifest.json`) and then ends early, fails the gzip CRC or length, or is named `*.partial` | incomplete | "incomplete: take or copy it again" |
| 3 | manifest names a `backup_format_version` this release doesn't restore | unknown version | names the versions it restores |
| 4 | the snapshot's SHA-256 or size differs from the manifest's | changed | "checksum doesn't match" |

A gzip stream that ends early before its first tar block is classified 2 (it claims to be gzip and stops), not 1. The classification reads the whole archive once and writes nothing (Phase 4 reads it twice: once to classify and check the checksum, once to extract).

## Manual recovery (documented in `docs/backup-restore.md`, tested in Phase 1)

```sh
tar -xzf collector-backup-20261021T142100Z.tar.gz        # manifest.json, primary.sqlite3
sha256sum primary.sqlite3                                  # compare with manifest.json
sqlite3 primary.sqlite3 "PRAGMA integrity_check;"          # ok
# on a fresh volume, before the first start (a volume that already holds a database is not fresh):
cp primary.sqlite3 <volume>/production.sqlite3 && chown 1000:1000 <volume>/production.sqlite3
```
