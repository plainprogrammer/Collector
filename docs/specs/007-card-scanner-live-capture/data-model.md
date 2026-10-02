# Data Model: Card Scanner Phase 1 — Live Capture and Re-measure

## Entities

### Catalog::Name (`catalog_names`)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | integer | PK, not null | Row id; also the FTS5 rowid |
| collectible_type | string | not null | Which collectible's catalog (`mtg`) |
| catalog_identity_id | integer | FK → catalog_identities, not null | The card this name belongs to |
| name | string | not null | The name as the catalog stores it: the full name ("Fire // Ice") or a face name ("Fire") |
| normalized | string | not null | `Catalog::NameKey.call(name)`: NFKC, ligatures, diacritics, case, punctuation folded |

**Indexes:** unique `[collectible_type, catalog_identity_id, normalized]` (one row per name a card is known by); `[collectible_type, normalized]` (exact and near lookups); `catalog_identity_id` (foreign key).
**Relationships:** belongs to `Catalog::Identity` (many names per identity). No `account_id`: global catalog data, derived and rebuildable at any time.
**Spec requirement:** FR-5, FR-4 (name matching), ADR 0003.

### catalog_names_fts (FTS5 virtual table)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| rowid | integer | = catalog_names.id | External content row |
| normalized | text | indexed by `trigram remove_diacritics 1` | Trigram index over `catalog_names.normalized` |

**Indexes:** the FTS5 index itself (`content='catalog_names'`, `content_rowid='id'`), kept in `schema.rb` via `create_virtual_table`.
**Relationships:** external content of `catalog_names`; rebuilt with `INSERT INTO catalog_names_fts (catalog_names_fts) VALUES ('rebuild')` after each full rewrite.
**Spec requirement:** FR-5, ADR 0003.

**Lifecycle:** `Catalog::Refresh` rebuilds a type's rows in one transaction after an applied run, and when a scheduled run is skipped for an already-applied version while the index is empty. Nothing else writes them. The migration creates empty tables, so it's safe to run unattended on any prior version.

## Files outside the database (development measurement mode)

`<COLLECTOR_SCANNER_RUN_DIR>/<manifest file>/capture-NNN.json` (`file`, `kind` measured|retake, `name_text`, `collector_text`, `ms`, `user_agent`, `captured_at`), `capture-NNN-name.png`, `capture-NNN-collector.png`, `skipped.json`; `<run dir>/replays/<label>.json` (`label`, `replayed_at`, `results[]` of `file`, `name_text`, `collector_text`). Outside the repository and `storage/`; never committed (FR-6).

## Fixtures (committed, text only)

`spec/fixtures/card_scanner/phase1_photos_{ocr_results,name_matches}.json` (the photo replay of the 50 corpus photos) and `phase1_tuning4_{ocr_results,name_matches}.json` (tuning round 4's live captures), format_version 2, `run` set to the scored run's label: spec 005's format_version 1 fields plus `ms`, `user_agent`, `captured_at` (results) and `lookup_ms`, `name_candidates`, `final_candidates` (matches), keyed by manifest `file` (AC-6.6).
