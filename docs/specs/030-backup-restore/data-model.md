# Data model: Back up and restore an instance

**Spec:** [spec.md](spec.md) (v1.2.1, Approved)

## Entities

This feature adds **no table, no column and no migration** (spec NFR "Self-hosting and upgrades": "No migration is added"). The export format's Coverage tables don't change, and `spec/export_format_document_spec.rb` stays green without edits. What follows are the two things the feature does define: the backup file and what each command does to existing tables.

### Backup file (not a database entity)

The archive and its manifest are specified in [contracts/archive.md](contracts/archive.md). There is no table of backups: nothing records that a backup was made (hosted-door rule 3: no setting, no bookkeeping; the operator keeps the files).

**Spec requirement:** decisions 2 and 5; FR-1; FR-7.

### What `backup:create` reads

| Table(s) | Use |
|---|---|
| every table of the primary database | copied whole by `VACUUM INTO` |
| `accounts`, `users`, `lots` | `COUNT(*)` in the snapshot, for the manifest and the printed counts (counts only, AC-1.7) |
| `schema_migrations` | newest `version`, for the manifest |

**Indexes:** none added. **Relationships:** unchanged. **Spec requirement:** FR-1, AC-1.4.

### What `backup:restore` writes

| Table | Change, in the snapshot only, before it is placed |
|---|---|
| `sessions` | every row deleted with `PRAGMA foreign_keys = ON` |
| `bulk_removals`, `bulk_selections` | cascade from `sessions` (`on_delete: :cascade`, `db/schema.rb`) |
| `bulk_selection_marks` | cascade from `bulk_selections` |
| every other table | unchanged: the placed file holds the snapshot's rows exactly (AC-2.1 compares table by table) |

The four tables above and `sessions` are the only ones the restore changes (FR-3); the live instance's databases are never opened (FR-8). The queue, cache and cable databases are not in a backup and are created empty by the first boot's `db:prepare` (decision 2).

**Indexes:** none. **Relationships:** `bulk_removals.session_id`, `bulk_selections.session_id` → `sessions` (cascade); `bulk_selection_marks.bulk_selection_id` → `bulk_selections` (cascade). Verified in `db/schema.rb` lines 331 to 337 (at `acb6e3c`). **Spec requirement:** decision 3, FR-3, AC-2.1, AC-2.4.

### Guard

A model other than `ImportUpload` with an Active Storage attachment, or a production database other than primary, queue, cache and cable, fails the suite (AC-5.5, decision 2) until the table in decision 2 and `docs/backup-restore.md` say what the backup does with it.
