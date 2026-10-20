# Data Model: Apply an Import

**Spec:** [spec.md](spec.md) v1.3.1 · **Plan:** [plan.md](plan.md)

## Entities

### ImportUpload (`import_uploads`, new)

One account's previewed export file, kept so that it can be applied (decisions 1, 9; FR-10).

| Field | Type | Null | Notes |
|---|---|---|---|
| `id` | integer | no | |
| `account_id` | integer | no | Foreign key to `accounts`, `on_delete: :cascade` |
| `fingerprint` | string | no | SHA-256 hex of the plan and the file's checksum (decision 2) |
| `expires_at` | datetime | no | `created_at + ImportUpload::EXPIRES_IN` (1 hour) |
| `created_at`, `updated_at` | datetime | no | |

**Indexes:** unique `[account_id]` (at most one per account); `[expires_at]` (the sweep).
**Relationships:** `belongs_to :account`; `has_one_attached :file, dependent: :purge` (the blob: `application/json`, created analyzed, with metadata marker `import_upload`); `Account has_one :import_upload, dependent: :destroy`.
**Spec requirement:** decisions 1, 2, 8, 9; FR-10; AC-4.4, AC-5.1, AC-5.2.

### Active Storage tables (new, the framework's install migration)

`active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`, exactly as `ActiveStorage` 8.1.4's `create_active_storage_tables` creates them. None has `account_id` or `user_id`, so the export format's Coverage check ignores them. **Spec requirement:** decision 8 (Installation), AC-1.11.

### Existing tables written by an apply

`lots` (insert, update of `quantity`/`created_at`/`updated_at`, delete), `users.collection_view`, and, when the apply writes, the deletion of the account's `bulk_selections` (marks cascade), `number_entries` and `scanner_sittings` (lines and entries cascade), and `bulk_removals.lots_data` set to null (decision 7).
