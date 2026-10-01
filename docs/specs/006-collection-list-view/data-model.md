# Data Model: Collection Table View and Bulk Editing

## Entities


### User (changed)
| Field | Type | Constraints | Description |
|---|---|---|---|
| collection_view | string | not null, default `"grid"`, model inclusion `grid`/`table` | Saved collection view |
**Spec requirement:** FR-1, AC-1.2, AC-1.3, AC-8.5.

### BulkSelection
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | |
| session_id | integer | not null, FK `sessions` ON DELETE CASCADE, unique index | One per session |
| account_id | integer | not null, FK `accounts` ON DELETE CASCADE, index | Tenant |
| query | string | not null, default `""` | Filter it was made under |
| sort_key | string | not null, default `""` | Sort it was made under (`"price-desc"`, `""` = default) |
| all_matching | boolean | not null, default false | Every matching lot is selected; marks are exceptions |
| created_at/updated_at | datetime | not null | |
**Relationships:** belongs_to session and account; has_many marks. **Spec requirement:** FR-4, Story 5.

### BulkSelection::Mark (`bulk_selection_marks`)
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | |
| bulk_selection_id | integer | not null, FK ON DELETE CASCADE | |
| account_id | integer | not null, FK `accounts` ON DELETE CASCADE, index | Tenant |
| lot_id | integer | not null, FK `lots` ON DELETE CASCADE, index | A selected lot, or an exception |
**Indexes:** unique `[bulk_selection_id, lot_id]`. **Spec requirement:** FR-4, AC-5.3, AC-5.5.

### BulkRemoval
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | Undo addresses it |
| session_id | integer | not null, FK `sessions` ON DELETE CASCADE, index | Owner |
| account_id | integer | not null, FK `accounts` ON DELETE CASCADE, index | Tenant |
| copies | integer | not null | Copies removed, for the messages |
| lots_data | json | nullable | `[{catalog_entry_id, finish, condition, price_paid_cents, quantity}]`; NULL once used or superseded |
| created_at/updated_at | datetime | not null | |
**Indexes:** partial unique `session_id WHERE lots_data IS NOT NULL` (one undoable per session). **Spec requirement:** FR-6, Story 7.

---
