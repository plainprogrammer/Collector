# API Contracts: Scryfall Catalog Ingestion and Card Search

HTML pages only (no JSON API). Every page is public and renders from the local database only.

## GET /catalog/entries

**Purpose:** Card search.
**Spec requirement:** FR-7, Stories 1–2.

### Request

```json
{ "q": "string — optional, stripped, ≤100 chars, literal substring of name/localized name",
  "set": "string — optional set code",
  "page": "string — optional; non-integer/<1 → 1, beyond last → last" }
```

### Response (200 OK)

HTML with a freshness line (or "not loaded yet"), the search form (the set select lists sets with searchable printings, newest first), and then one of:
- a prompt, when there is no query and no set;
- "No cards found";
- ≤12 card groups sorted by name, each with ≤10 printings (newest first) and a "Show all N printings" link when there are more, plus pagination (`rel="prev"`/`rel="next"`, "Page X of Y").

### Error Responses

| Status | Condition | Body |
|---|---|---|
| 200 | unknown set code, invalid page | normal page (no results / clamped page) |

## GET /catalog/entries/:external_key

**Purpose:** Printing detail by Scryfall ID.
**Spec requirement:** FR-8, Story 3.

### Request

```json
{ "external_key": "string — Scryfall card id" }
```

### Response (200 OK)

HTML with: name, localized name, retired notice (when applicable), set name/code, collector number, language, release date, rarity, finishes, and per face (image, name, printed name, mana cost, type line, rules text, artist). Also Scryfall attribution, a "View on Scryfall" link, a link to search for the card by name, and a link to the card's printings page when it has searchable printings.

### Error Responses

| Status | Condition | Body |
|---|---|---|
| 404 | no entry with that external key | Rails 404 page |

## GET /catalog/identities/:external_key

**Purpose:** Every searchable printing of one card.
**Spec requirement:** FR-10, Story 10.

### Request

```json
{ "external_key": "string — identity key (Scryfall oracle_id)", "set": "string — optional set code", "page": "string — optional, clamped" }
```

### Response (200 OK)

HTML with the card name, "Show all sets" (when filtered), up to 12 printing summaries (newest first), and pagination.

### Error Responses

| Status | Condition | Body |
|---|---|---|
| 404 | unknown identity, or identity with no non-retired card-kind printings | Rails 404 page |

## Catalog source contract (internal)

Documented in `app/models/catalog/sources.rb`. Implemented by `MTG::Scryfall::Source` and by `FakeCatalogSource` in specs. `Catalog::Refresh` depends only on this contract.
