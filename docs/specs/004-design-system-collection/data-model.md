# Data Model: Design System, Accounts, Adding Cards and the Collection Grid

## Entities

### Account
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | Tenant |
| created_at/updated_at | datetime | not null | |
**Relationships:** has_one user (1:1), has_many lots (`dependent: :delete_all`). **Spec requirement:** FR-3.

### User
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | |
| account_id | integer | not null, FK, unique index | Exactly one account per user |
| name | string | not null, ≤100 | Display name, avatar initial |
| email_address | string | not null, unique index, stored stripped+downcased | Sign-in identifier |
| password_digest | string | not null | bcrypt hash |
| admin | boolean | not null, default false | Instance admin |
**Relationships:** belongs_to account (`dependent: :destroy` from user), has_many sessions (`dependent: :delete_all`). **Spec requirement:** FR-2, FR-3.

### Session
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | Signed cookie `session_id` |
| user_id | integer | not null, FK, index | |
| ip_address | string | | For the audit trail |
| user_agent | string | | |
**Spec requirement:** FR-2 (sign out ends only this session), AC-5.3.

### InstanceSetting (singleton row)
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | Always the first row |
| sign_up_open | boolean | not null, default false | Open registration |
**Spec requirement:** FR-4.

### Lot (core, collectible-agnostic)
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | |
| account_id | integer | not null, FK, index | Tenant |
| catalog_entry_id | integer | not null, FK, index | Printing |
| quantity | integer | not null, 1–9,999 | Copies |
| finish | string | nullable | Extension-defined value (MTG `nonfoil`/`foil`/`etched`/…) |
| condition | string | nullable | Extension-defined value (MTG `near_mint`…`damaged`) |
| price_paid_cents | integer | nullable, ≥ 0 | Per copy, in minor units of the instance currency |
| lot_key | string | not null | finish, condition and price paid joined with a pipe character (e.g. `foil\|near_mint\|400`), set by the model |
**Indexes:** unique `[account_id, catalog_entry_id, lot_key]` (AC-12.5), which also covers `[account_id, catalog_entry_id]` lookups; `catalog_entry_id`. **Check constraints:** `quantity BETWEEN 1 AND 9999`; `price_paid_cents IS NULL OR price_paid_cents >= 0`. The model merges on identity and retries once on a unique-index conflict. **Spec requirement:** FR-6, AC-12.4, AC-12.5.
