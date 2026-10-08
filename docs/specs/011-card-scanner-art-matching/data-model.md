# Data Model: Card Scanner — Art Matching on Live Capture

All three are global catalog data in the MTG extension: no `account_id`, written only by the catalog refresh (the column) and the art build job (the tables). Collectors' data is unchanged.

## Entities

### MTG::Printing (existing, `mtg_printings`): one new column

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| illustration_id | string | nullable, indexed | Scryfall's `illustration_id` of the printing's front face (a multi-face printing's first face, else the card's own). About 760 printings have none |

`faces` (existing JSON) keeps each face's `image_uris` with `small` as well as `normal` and `large`.

**Indexes:** `illustration_id` (the ranking maps an artwork to its printings; the build groups printings by artwork).
**Relationships:** none new. Several printings, of one card or (rarely) several, can share an `illustration_id`.
**Spec requirement:** FR-2, AC-2.1, AC-2.2.

---

### MTG::Artwork (`mtg_artworks`)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | integer | PK, not null | |
| illustration_id | string | not null, unique | The artwork, as Scryfall identifies it |
| catalog_entry_id | integer | not null, FK → catalog_entries | The printing whose `small` image was fingerprinted (its oldest English card printing with one) |
| fingerprint | binary | not null, 128 bytes | ADR 0006's 1,024-bit fingerprint at the zero offset |
| settings_digest | string | not null, indexed | `MTG::Art::Settings.digest` when it was made; only rows at the current digest are used |
| created_at, updated_at | datetime | not null | |

**Indexes:** `illustration_id` unique (upsert key, lookup by sent ids); `settings_digest` (the current set); `catalog_entry_id` (foreign key).
**Relationships:** belongs to one `Catalog::Entry` (the representative printing). Catalog entries are retired, never deleted, so the key stays valid.
**Spec requirement:** FR-2, AC-3.7.

---

### MTG::ArtBuild (`mtg_art_builds`)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | integer | PK, not null | |
| status | string | not null; running, finished, failed, skipped | Outcome |
| job_id | string | nullable, indexed | The ActiveJob id; a re-run of the same job finds its own run |
| catalog_version | string | nullable | The last applied MTG refresh's source version the build ran for |
| settings_digest | string | nullable | The fingerprint settings' digest |
| index_file | string | nullable | The index file it wrote (or found already written) |
| total_count | integer | not null, default 0 | Artworks with a `small` image |
| without_image_count | integer | not null, default 0 | Artworks with no `small` image on any printing |
| fetched_count | integer | not null, default 0 | Images fetched by this build |
| fingerprinted_count | integer | not null, default 0 | Artworks with a current fingerprint |
| failed_count | integer | not null, default 0 | Images that failed (fetch or decode) in this build |
| indexed_count | integer | not null, default 0 | Records in the index written |
| message | text | nullable | "interrupted", "already running", the error, or the first 20 failed artwork ids |
| started_at | datetime | not null | |
| heartbeat_at | datetime | not null | Updated after every batch of 50 images; stale after 10 minutes |
| finished_at | datetime | nullable | |
| created_at, updated_at | datetime | not null | |

**Indexes:** `[status, started_at]` (the running run, the latest run); `job_id` (a re-run finds its own run).
**Relationships:** none.
**Spec requirement:** AC-3.2, AC-3.8, AC-3.11.

---

## Files (global, on the persistent volume)

| Path | Contents | Spec requirement |
|------|----------|------------------|
| `<catalog dir>/mtg/art/small/<illustration_id>.jpg` | Scryfall `small` image, written through `<name>.part`, never fetched twice | AC-3.4, AC-3.5 |
| `<catalog dir>/mtg/art/index/art-index-<catalog version>-<settings digest>-<count>.bin.gz` | The index (header + records, see contracts/api.md); the two newest kept | AC-3.9 |

`<catalog dir>` is `config.x.catalog_download_dir`: `storage/catalog` in production and development, `tmp/catalog` in tests.
