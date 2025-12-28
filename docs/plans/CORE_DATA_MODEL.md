# Core Data Model Plan

## Overview

This document defines the core data model for Collector, a collection management application. The model supports multiple collectible types (trading cards, comics, etc.) through a flexible, extensible architecture using Rails polymorphic associations and Delegated Types.

**Initial scope**: Magic: The Gathering cards as the primary use case, with comic books as the next planned addition.

---

## Design Principles

1. **Strong queryability**: Delegated Types over STI or JSONB for type-specific attributes
2. **Flexible hierarchy**: Storage Units support nesting and multi-Collection membership
3. **Extensible catalogs**: Adapter pattern for diverse data sources (MTGJSON, APIs, custom entries)
4. **Per-item granularity**: Default workflow creates one Item row per physical card; quantity field available for bulk/unsorted storage scenarios
5. **Interface conformity**: All catalog entry types implement a common interface for consistent Item references

---

## Entity Relationship Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              COLLECTION LAYER                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐       1:1        ┌─────────────┐                            │
│  │  Collection │──────────────────│   Catalog   │                            │
│  │             │                  │             │                            │
│  │ name        │                  │ name        │                            │
│  │ description │                  │ source_type │────────► Adapter           │
│  │ item_type   │                  │ source_config│       (MTGJSONAdapter,    │
│  └─────────────┘                  └─────────────┘        ApiAdapter,         │
│         │                               │                CustomAdapter)      │
│         │                               │                                    │
│         │ many-to-many                  │ has_many                           │
│         │                               │                                    │
│         ▼                               ▼                                    │
│  ┌─────────────────────┐         ┌─────────────────────────────────────┐     │
│  │CollectionStorageUnit│         │  Catalog Entries (polymorphic)     │     │
│  │ (join table)        │         │                                     │     │
│  └─────────────────────┘         │  ┌───────────┐    ┌──────────────┐ │     │
│         │                        │  │  MTGCard  │    │ CustomMTGCard│ │     │
│         │                        │  │           │    │              │ │     │
│         ▼                        │  │ (from     │    │ (user-       │ │     │
│  ┌─────────────┐                 │  │ MTGJSON)  │    │  created)    │ │     │
│  │ StorageUnit │                 │  └───────────┘    └──────────────┘ │     │
│  │             │                 │        ▲                           │     │
│  │ name        │                 └────────┼───────────────────────────┘     │
│  │ unit_type   │                          │                                  │
│  │ notes       │                          │ belongs_to                       │
│  │ parent_id   │──┐               ┌───────────┐                              │
│  └─────────────┘  │               │  MTGSet   │                              │
│         ▲         │               │           │                              │
│         └─────────┘               │ code      │                              │
│      (self-referential            │ name      │                              │
│       nesting)                    │ release_  │                              │
│                                   │   date    │                              │
│                                   └───────────┘                              │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                              ITEM LAYER                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐   │
│  │                        Item                                           │   │
│  │                                                                       │   │
│  │  belongs_to :collection                                               │   │
│  │  belongs_to :storage_unit (optional)                                  │   │
│  │  belongs_to :catalog_entry, polymorphic: true  ──► MTGCard,           │   │
│  │                                                    CustomMTGCard,     │   │
│  │                                                    (future types)     │   │
│  │                                                                       │   │
│  │  quantity (integer, default: 1)                                       │   │
│  │  acquisition_price (decimal)                                          │   │
│  │  acquisition_date (date)                                              │   │
│  │  notes (text)                                                         │   │
│  │                                                                       │   │
│  │  delegated_type :detail ──────────────────────────────────────────┐   │   │
│  └───────────────────────────────────────────────────────────────────┼───┘   │
│                                                                      │       │
│                                                               ┌──────┴─────┐ │
│                                                               │            │ │
│                                                        ┌──────┴─────┐ ┌────┴───────┐
│                                                        │MTGCardItem │ │ComicItem   │
│                                                        │Detail      │ │Detail      │
│                                                        └────────────┘ └────────────┘
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Entity Specifications

### Collection

The top-level organizational unit representing a distinct collecting domain.

| Attribute     | Type    | Description                                      |
|---------------|---------|--------------------------------------------------|
| `id`          | UUID    | Primary key                                      |
| `name`        | string  | Display name (e.g., "My MTG Collection")         |
| `description` | text    | Optional description                             |
| `item_type`   | string  | Identifies the collectible type (e.g., "mtg_card") |
| `catalog_id`  | FK      | References the associated Catalog                |
| `created_at`  | datetime| Timestamp                                        |
| `updated_at`  | datetime| Timestamp                                        |

**Relationships:**
- `has_one :catalog`
- `has_many :items`
- `has_many :storage_units, through: :collection_storage_units`

---

### Catalog

Defines the authoritative source for item identification within a Collection. The adapter pattern allows different data sources to feed into the same catalog interface.

| Attribute       | Type    | Description                                        |
|-----------------|---------|----------------------------------------------------|
| `id`            | UUID    | Primary key                                        |
| `name`          | string  | Display name (e.g., "MTGJSON Catalog")             |
| `source_type`   | string  | Adapter identifier (e.g., "mtgjson", "api", "custom") |
| `source_config` | jsonb   | Adapter-specific configuration                     |
| `created_at`    | datetime| Timestamp                                          |
| `updated_at`    | datetime| Timestamp                                          |

**Relationships:**
- `belongs_to :collection`

**Adapter Pattern:**
The `source_type` determines which adapter class handles fetch/refresh operations. Adapters implement a common interface:

```ruby
class CatalogAdapter
  def fetch_entry(identifier)
    raise NotImplementedError
  end

  def search(query, options = {})
    raise NotImplementedError
  end

  def refresh(entry)
    raise NotImplementedError
  end

  def bulk_import(options = {})
    raise NotImplementedError
  end
end
```

**MVP Adapter**: `MTGJSONAdapter` handles bulk import from MTGJSON SQLite/JSON files.

**Future Adapters**: `ApiAdapter` for REST/GraphQL sources (comics, books), `CustomAdapter` for user-created entries.

---

### MTGSet

Set metadata for Magic: The Gathering sets, imported from MTGJSON.

| Attribute      | Type    | Description                                |
|----------------|---------|--------------------------------------------|
| `id`           | UUID    | Primary key                                |
| `code`         | string  | Set code (e.g., "MH3", "LEB")              |
| `name`         | string  | Full set name (e.g., "Modern Horizons 3")  |
| `release_date` | date    | Official release date                      |
| `set_type`     | string  | Type (expansion, core, masters, etc.)      |
| `card_count`   | integer | Total cards in set                         |
| `icon_uri`     | string  | Set symbol image URL                       |
| `created_at`   | datetime| Timestamp                                  |
| `updated_at`   | datetime| Timestamp                                  |

**Relationships:**
- `has_many :mtg_cards`

**Indexes:**
- Unique index on `code`

---

### MTGCard

Catalog entry for Magic: The Gathering cards. This is the concrete implementation that Items reference via polymorphic `catalog_entry` association.

| Attribute          | Type    | Description                                |
|--------------------|---------|--------------------------------------------|
| `id`               | UUID    | Primary key                                |
| `mtg_set_id`       | FK      | References parent MTGSet                   |
| `uuid`             | string  | MTGJSON UUID (stable identifier)           |
| `scryfall_id`      | string  | Scryfall ID (for image URLs)               |
| `name`             | string  | Card name                                  |
| `set_code`         | string  | Set identifier (denormalized for queries)  |
| `collector_number` | string  | Collector number within set                |
| `rarity`           | string  | Rarity (common, uncommon, rare, mythic)    |
| `mana_cost`        | string  | Mana cost string (e.g., "{2}{W}{W}")       |
| `mana_value`       | decimal | Converted mana cost                        |
| `type_line`        | string  | Full type line                             |
| `oracle_text`      | text    | Rules text                                 |
| `power`            | string  | Power (creatures only)                     |
| `toughness`        | string  | Toughness (creatures only)                 |
| `colors`           | array   | Card colors (W, U, B, R, G)                |
| `color_identity`   | array   | Color identity for Commander               |
| `finishes`         | array   | Available finishes (nonfoil, foil, etched) |
| `frame_effects`    | array   | Special frame treatments                   |
| `promo_types`      | array   | Promo categorizations                      |
| `prices`           | jsonb   | Cached price data                          |
| `source_data`      | jsonb   | Full MTGJSON payload for reference         |
| `cached_at`        | datetime| When entry was last synced                 |
| `created_at`       | datetime| Timestamp                                  |
| `updated_at`       | datetime| Timestamp                                  |

**Relationships:**
- `belongs_to :mtg_set`
- `has_many :items, as: :catalog_entry`

**Indexes:**
- Unique index on `uuid`
- Unique index on `scryfall_id`
- Index on `name` (for search)
- Composite index on `[set_code, collector_number]`
- Full-text index on `name` (FTS5 for SQLite)

**Interface Compliance:**
MTGCard implements the catalog entry interface, providing:
- `identifier` → returns `uuid`
- `display_name` → returns `name`
- `image_url(size, face:)` → constructs Scryfall CDN URL

---

### CustomMTGCard

User-created entry for cards not in MTGJSON (promos, test prints, custom cards). Implements the same interface as MTGCard for consistent Item references.

| Attribute          | Type    | Description                                |
|--------------------|---------|--------------------------------------------|
| `id`               | UUID    | Primary key                                |
| `identifier`       | string  | User-defined identifier                    |
| `name`             | string  | Card name                                  |
| `set_code`         | string  | Set identifier (if known)                  |
| `set_name`         | string  | Set name (if known)                        |
| `collector_number` | string  | Collector number (if known)                |
| `rarity`           | string  | Rarity                                     |
| `mana_cost`        | string  | Mana cost string                           |
| `type_line`        | string  | Full type line                             |
| `oracle_text`      | text    | Rules text                                 |
| `colors`           | array   | Card colors                                |
| `finishes`         | array   | Available finishes                         |
| `image_data`       | binary  | User-uploaded image (optional)             |
| `notes`            | text    | Required—rationale for custom entry        |
| `created_at`       | datetime| Timestamp                                  |
| `updated_at`       | datetime| Timestamp                                  |

**Relationships:**
- `has_many :items, as: :catalog_entry`

**Validation:**
- `notes` is required (user must document why custom entry is needed)

---

### StorageUnit

Physical or logical container for items. Supports arbitrary nesting and multi-Collection membership to model real-world storage scenarios (e.g., a shelf holding binders from different collections).

| Attribute   | Type    | Description                                      |
|-------------|---------|--------------------------------------------------|
| `id`        | UUID    | Primary key                                      |
| `name`      | string  | Display name (e.g., "Main Binder", "Box 1")      |
| `unit_type` | string  | Categorization (shelf, binder, box, deck, etc.)  |
| `notes`     | text    | Optional notes                                   |
| `parent_id` | FK      | Self-referential; null for root units            |
| `created_at`| datetime| Timestamp                                        |
| `updated_at`| datetime| Timestamp                                        |

**Relationships:**
- `belongs_to :parent, class_name: "StorageUnit", optional: true`
- `has_many :children, class_name: "StorageUnit", foreign_key: :parent_id`
- `has_many :collection_storage_units`
- `has_many :collections, through: :collection_storage_units`
- `has_many :items`

**Nesting Behavior:**
- Child units may have *narrower* Collection scope than their parent
- A child unit's Collections must be a subset of (or equal to) its ancestors' Collections
- Moving a unit validates Collection scope constraints

**Unit Types (MVP):**
- `shelf` — A shelf or section of shelving
- `box` — A cardboard box, BCW box, or similar container  
- `binder` — A binder with pages/slots
- `deck` — A constructed deck (sleeved cards for play)

---

### CollectionStorageUnit (Join Table)

Associates Storage Units with Collections, enabling shared physical storage across collecting domains.

| Attribute         | Type    | Description                          |
|-------------------|---------|--------------------------------------|
| `id`              | UUID    | Primary key                          |
| `collection_id`   | FK      | References Collection                |
| `storage_unit_id` | FK      | References StorageUnit               |
| `created_at`      | datetime| Timestamp                            |
| `updated_at`      | datetime| Timestamp                            |

**Constraints:**
- Unique index on `[collection_id, storage_unit_id]`

---

### Item

A specific instance (or group of identical instances) of a collectible within a Collection.

| Attribute           | Type    | Description                                      |
|---------------------|---------|--------------------------------------------------|
| `id`                | UUID    | Primary key                                      |
| `collection_id`     | FK      | References owning Collection                     |
| `storage_unit_id`   | FK      | References current StorageUnit (optional)        |
| `catalog_entry_type`| string  | Polymorphic type (e.g., "MTGCard")               |
| `catalog_entry_id`  | FK      | Polymorphic ID for catalog entry                 |
| `detail_type`       | string  | Delegated type identifier                        |
| `detail_id`         | FK      | Delegated type foreign key                       |
| `quantity`          | integer | Number of identical items (default: 1)           |
| `acquisition_price` | decimal | Purchase price (per unit if quantity > 1)        |
| `acquisition_date`  | date    | When acquired                                    |
| `notes`             | text    | Optional notes                                   |
| `created_at`        | datetime| Timestamp                                        |
| `updated_at`        | datetime| Timestamp                                        |

**Relationships:**
- `belongs_to :collection`
- `belongs_to :storage_unit, optional: true`
- `belongs_to :catalog_entry, polymorphic: true`
- `delegated_type :detail, types: %w[MTGCardItemDetail ComicItemDetail ...]`

**Quantity Field Usage:**
The default workflow creates one Item row per physical card (`quantity: 1`). The quantity field exists for bulk/unsorted storage scenarios where tracking individual cards isn't practical (e.g., "500 unsorted commons in Box 3"). When `quantity > 1`, all items in that row share the same condition, finish, and other detail attributes.

**Constraints:**
- Item's StorageUnit must be associated with the Item's Collection (if storage_unit present)
- Moving an Item between StorageUnits within the same Collection is a simple reassignment

---

### MTGCardItemDetail (Item Delegated Type)

Physical-instance attributes for an MTG card. Separated from Item to support type-specific attributes while keeping Item table lean.

| Attribute        | Type    | Description                                    |
|------------------|---------|------------------------------------------------|
| `id`             | UUID    | Primary key                                    |
| `condition`      | string  | Condition grade (NM, LP, MP, HP, DMG)          |
| `finish`         | string  | Finish type (nonfoil, foil, etched)            |
| `language`       | string  | Language code (EN, JP, DE, FR, etc.)           |
| `signed`         | boolean | Whether the card is signed                     |
| `altered`        | boolean | Whether the card has alterations               |
| `graded`         | boolean | Whether professionally graded                  |
| `grading_service`| string  | Grading company (PSA, BGS, CGC)                |
| `grade`          | string  | Grade value                                    |
| `created_at`     | datetime| Timestamp                                      |
| `updated_at`     | datetime| Timestamp                                      |

**Defaults:**
- `condition`: "NM" (Near Mint)
- `finish`: "nonfoil"
- `language`: "EN"
- `signed`: false
- `altered`: false
- `graded`: false

---

## Future Extensions

### ComicEntry (Future Catalog Entry Type)

Catalog entry for comic books—to be defined when Comics are implemented via ApiAdapter.

**Anticipated attributes:**
- `publisher`, `series`, `volume`, `issue_number`
- `cover_artist`, `writer`, `penciler`
- `cover_variant`, `upc`, `release_date`

### ComicItemDetail (Future Item Delegated Type)

Physical-instance attributes for comics—to be defined when Comics are implemented.

**Anticipated attributes:**
- `condition`, `graded`, `grading_service`, `grade`
- `pressed`, `cleaned`, `signed`

---

## Implementation Notes

### Delegated Types Configuration

```ruby
# app/models/item.rb
class Item < ApplicationRecord
  belongs_to :collection
  belongs_to :storage_unit, optional: true
  belongs_to :catalog_entry, polymorphic: true
  
  delegated_type :detail, types: %w[MTGCardItemDetail], dependent: :destroy
  
  validates :storage_unit, collection_scope: true, if: :storage_unit_id?
end
```

### Catalog Entry Interface

All catalog entry types must respond to these methods for consistent Item handling:

```ruby
# Expected interface for catalog entries
module CatalogEntryInterface
  def identifier
    raise NotImplementedError
  end
  
  def display_name
    raise NotImplementedError
  end
  
  def image_url(size = :normal, face: :front)
    raise NotImplementedError
  end
end

# app/models/mtg_card.rb
class MTGCard < ApplicationRecord
  include CatalogEntryInterface
  
  belongs_to :mtg_set
  has_many :items, as: :catalog_entry
  
  def identifier
    uuid
  end
  
  def display_name
    name
  end
  
  def image_url(size = :normal, face: :front)
    return nil unless scryfall_id
    dir1, dir2 = scryfall_id[0], scryfall_id[1]
    "https://cards.scryfall.io/#{size}/#{face}/#{dir1}/#{dir2}/#{scryfall_id}.jpg"
  end
end
```

### Adapter Implementation

```ruby
# app/adapters/catalog_adapter.rb
class CatalogAdapter
  def initialize(catalog)
    @catalog = catalog
  end

  def fetch_entry(identifier)
    raise NotImplementedError
  end

  def search(query, options = {})
    raise NotImplementedError
  end

  def bulk_import(options = {})
    raise NotImplementedError
  end
end

# app/adapters/mtgjson_adapter.rb
class MTGJSONAdapter < CatalogAdapter
  def search(query, options = {})
    MTGCard.where("name LIKE ?", "%#{query}%")
           .limit(options[:limit] || 50)
  end
  
  def bulk_import(source_path:)
    # Import from MTGJSON SQLite or JSON file
    # Creates/updates MTGSet and MTGCard records
  end
end
```

### Validation Rules

1. **Item → StorageUnit → Collection consistency**: An Item's StorageUnit must be associated with the Item's Collection
2. **Nested StorageUnit scope**: A child StorageUnit's Collections must be a subset of its parent's Collections
3. **Catalog → Collection 1:1**: Enforced at database level with unique constraint
4. **Catalog entry interface compliance**: All catalog entry types must respond to `identifier`, `display_name`, `image_url`
5. **Finish validation**: Item's finish must be valid for the card's available finishes

---

## Open Questions for Future Consideration

1. **Deck management**: Should decks be a special StorageUnit type, or a separate entity with additional metadata (format, legality)?
2. **Price history**: When price tracking is added, should it be a separate table with time-series data?
3. **Image storage**: Local caching of card images vs. relying on external URLs?
4. **Bulk operations**: When implemented, should bulk moves/updates be transactional with rollback support?
5. **Quantity splitting**: UX for splitting a quantity > 1 Item into individual Items when user wants to track separately?

---

## Revision History

| Date       | Author | Changes                                      |
|------------|--------|----------------------------------------------|
| 2025-01-XX | —      | Initial draft based on design session        |
| 2025-01-XX | —      | Reconciled naming (MTGCard), added MTGSet, clarified quantity usage, adapter pattern |
