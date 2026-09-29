# Data Model: Scryfall Catalog Ingestion and Card Search

## Entities

### Catalog::Set (`catalog_sets`)

| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | |
| collectible_type | string | not null | e.g. `"mtg"` |
| code | string | not null | source set code (`m10`) |
| name | string | not null | |
| released_on | date | nullable | optional per FR-1 |
| parent_code | string | nullable | parent grouping code |
| content_digest | string | not null | SHA-256 of stored attributes (change detection) |
| created_at / updated_at | datetime | not null | |

**Indexes:** unique `[collectible_type, code]`.
**Relationships:** has many `Catalog::Entry`.
**Spec requirement:** FR-1, FR-3 (sets listing; created from entry when missing), FR-7 (set filter).

### Catalog::Identity (`catalog_identities`)

| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | |
| collectible_type | string | not null | |
| external_key | string | not null | source identity key (Scryfall `oracle_id`); URL param |
| name | string | not null | canonical name (English card name) |
| content_digest | string | not null | |
| created_at / updated_at | datetime | not null | |

**Indexes:** unique `[collectible_type, external_key]`; `name` (sorting).
**Relationships:** has many `Catalog::Entry`; has one `MTG::Card` (extension, not declared on the core model).
**Spec requirement:** FR-1 (shared identity), FR-7 (grouping), FR-10.

### Catalog::Entry (`catalog_entries`)

| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | stable across updates/restores |
| collectible_type | string | not null | |
| external_key | string | not null | Scryfall `id`; URL param |
| catalog_set_id | integer | FK, not null | |
| catalog_identity_id | integer | FK, not null | |
| number | string | not null | collector number |
| language | string | not null | Scryfall `lang` |
| name | string | not null | display name |
| localized_name | string | nullable | `printed_name`, or face names joined with " // " |
| kind | string | not null | `card` (searchable), `token`, `emblem`, `art_card`, `other` |
| released_on | date | nullable | |
| image_url | string | nullable | front "normal" image |
| content_digest | string | not null | SHA-256 of stored attributes incl. extension |
| retired_at | datetime | nullable | set when absent from a complete source pass |
| created_at / updated_at | datetime | not null | |

**Indexes:** unique `[collectible_type, external_key]`; `catalog_set_id`; `catalog_identity_id`; `[kind, retired_at]`.
**Relationships:** belongs to Set, Identity; has one `MTG::Printing` (extension, loaded via `preload_extensions`).
**Spec requirement:** FR-1, FR-4, FR-7, FR-8.

### Catalog::RefreshRun (`catalog_refresh_runs`)

| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | |
| collectible_type | string | not null | |
| trigger | string | not null | `scheduled` \| `manual` |
| status | string | not null | `running` \| `applied` \| `skipped` \| `failed` |
| source_version | string | nullable | e.g. `all-cards-20260929091807` |
| languages | string | nullable | sorted, comma-joined (`en,ja`) |
| seen/inserted/updated/retired/restored/malformed_count | integer | not null, default 0 | printings only |
| message | text | nullable | error, or skip reason |
| started_at | datetime | not null | |
| finished_at | datetime | nullable | |
| created_at / updated_at | datetime | not null | |

**Indexes:** `[collectible_type, status, started_at]`.
**Spec requirement:** FR-4, FR-5, Story 8, AC-4.3–4.6.

### MTG::Printing (`mtg_printings`)

| Field | Type | Constraints | Description |
|---|---|---|---|
| catalog_entry_id | integer | FK, not null, unique | |
| rarity | string | not null | |
| finishes | json | not null, default [] | sorted |
| layout | string | not null | |
| frame, border_color, security_stamp | string | nullable | |
| variant_tags | json | not null, default [] | promo types ∪ frame effects ∪ flags |
| legalities | json | not null, default {} | |
| external_ids | json | not null, default {} | tcgplayer/cardmarket/mtgo/arena/multiverse ids |
| faces | json | not null, default [] | per face: name, printed_name, mana_cost, type_line, oracle_text, power, toughness, loyalty, defense, artist, image_uris{normal,large} |
| scryfall_uri | string | not null | |

**Spec requirement:** FR-2, FR-8.

### MTG::Card (`mtg_cards`)

| Field | Type | Constraints | Description |
|---|---|---|---|
| catalog_identity_id | integer | FK, not null, unique | |
| mana_cost, type_line | string | nullable | faces joined with " // " when needed |
| oracle_text | text | nullable | |
| colors, color_identity, keywords | json | not null, default [] | sorted |

**Spec requirement:** FR-2.

---
