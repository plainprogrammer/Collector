# Data Model: Manage Locations

## Entities

### Location

A named place the collector keeps part of their collection. One row per location; nothing else about it is stored (spec decision 4).

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | integer | PK, not null | Internal id; never in a file |
| account_id | integer | not null, FK to `accounts` (`on_delete: :cascade`) | The tenant (AC-4.6) |
| name | string | not null; `length(name) BETWEEN 1 AND 60` (code points) | The name after normalisation (decision 5, steps 1 and 2); NFC |
| name_key | string | not null; `length(name_key) >= 1` | The comparison key: Unicode full case folding of `name` (`name.downcase(:fold)`). For uniqueness and matching only; never shown, never in a file |
| created_at | datetime | not null | |
| updated_at | datetime | not null | Not touched by an apply when the location is unchanged (AC-9.1) |

**Indexes:** unique `[account_id, name_key]` (the uniqueness rule in the database, not `COLLATE NOCASE`, which folds ASCII only; Reliability). It also serves the page's order (`ORDER BY name_key, name`, SQLite's binary collation on UTF-8 is code-point order, decision 2) and covers the `account_id` foreign key, so no separate index.
**Relationships:** `Account has_many :locations, dependent: :delete_all` (the foreign key cascades too, as for `import_uploads` and `number_entries`); `Location belongs_to :account`. No lot refers to a location in this spec (#45).
**Spec requirement:** FR-1; decisions 4, 5, 7, 9; Reliability; AC-1.x, AC-2.x, AC-3.x, AC-4.6.

Not stored: a kind, notes, order, a count of lots (decision 4, Non-Goals).

**Limits:** at most 500 rows per account, enforced inside the creating transaction (decision 7); worst case about 1 KB a row, 0.5 MB per account.

## Derived, not stored

- **The order of locations** (page and export): `name_key`, then `name`, both in code-point order.
- **A held location** in an apply (`CollectionImport::Locations::Held`): `id`, `name`, `name_key`, read in one statement.

## Export format version 2 (the file, not a table)

`locations`: a required top-level list, at most 500 elements, each `{ "name": <1 to 60 code points> }` (decision 9). Coverage lines for the table:

| Column | In the file | Why left out |
|---|---|---|
| `locations.id` | Left out | An internal id. |
| `locations.account_id` | Left out | An internal id. A file is one account's collection. |
| `locations.name` | `name` | |
| `locations.name_key` | Left out | Derived from the name. |
| `locations.created_at` | Left out | A fact about the instance, not about the collection. |
| `locations.updated_at` | Left out | A fact about the instance, not about the collection. |
