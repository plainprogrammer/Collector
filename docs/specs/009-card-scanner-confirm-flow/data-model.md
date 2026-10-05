# Data Model: Card Scanner — Confirm and Add

## Entities

### Scanner::Sitting (`scanner_sittings`)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | integer | PK, not null | Primary identifier |
| account_id | integer | not null, FK → accounts (on delete cascade), unique | The owning account: at most one open sitting each |
| created_at, updated_at | datetime | not null | Timestamps |

**Indexes:** unique `account_id` (one sitting per account; tenant lookup).
**Relationships:** belongs to Account; has many SittingEntries (delete all, and cascade in the database).
**Spec requirement:** FR-2, AC-3.1, AC-3.3, AC-3.5. An ended sitting is deleted, so there is no `ended_at`; it isn't collection data and isn't exported.

### Scanner::SittingEntry (`scanner_sitting_entries`)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | integer | PK, not null | Primary identifier |
| scanner_sitting_id | integer | not null, FK → scanner_sittings (on delete cascade) | Its sitting |
| account_id | integer | not null, FK → accounts (on delete cascade) | Tenant key (every tenant-owned table carries it) |
| catalog_entry_id | integer | not null, FK → catalog_entries | The printing added |
| lot_id | integer | null, FK → lots (on delete set null) | The lot the copy went into; null once that lot is removed or merged away ("Changed in your collection") |
| finish | string | null | The finish as tapped (the collectible's vocabulary); null for a printing with no finish listed |
| reading_key | string | not null, 32 lowercase hex | The page's opaque key for the reading (not derived from what was read) |
| undone_at | datetime | null | When it was undone; undone entries stay until Done, so a replayed add or Undo can say so |
| created_at, updated_at | datetime | not null | `created_at` is the time shown ("Added … ago") |

**Indexes:** unique `[scanner_sitting_id, reading_key]` (AC-1.5; also indexes the sitting key); `account_id`; `catalog_entry_id`; `lot_id`.
**Relationships:** belongs to Sitting, Account, Catalog::Entry (as `printing`), Lot (optional).
**Spec requirement:** FR-2, AC-1.5, AC-3.2, AC-3.6, AC-4.1–AC-4.4.

**Migrations:** two `create_table` migrations, reversible, safe under unattended `db:prepare` from any earlier version. No backfill; no existing table changes.

---
