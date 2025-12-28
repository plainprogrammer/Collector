# Collector MVP Roadmap

## Overview

This roadmap defines the development phases for Collector, a Magic: The Gathering collection management application built with Rails 8.1 and Hotwire. The MVP focuses on personal collection management with offline capability, hierarchical physical storage tracking, and a streamlined card entry workflow.

**Target Stack**: Rails 8.1, SQLite, Turbo, Stimulus, Tailwind CSS  
**Data Source**: MTGJSON (local SQLite import) + Scryfall CDN (images)  
**Design Approach**: Mobile-responsive web, preparing for future Hotwire Native apps

---

## Development Phases

### Phase 0: Foundation
**Goal**: Establish project infrastructure, catalog abstraction layer, and seed the card catalog from MTGJSON.

### Phase 1: Card Discovery
**Goal**: Enable searching and browsing the complete MTG catalog with card detail views.

### Phase 2: Item Management
**Goal**: Add cards to collections with quick-add workflow and manage item details.

### Phase 3: Storage Organization
**Goal**: Create and manage storage units with hierarchical nesting and item assignment.

### Phase 4: Collection Views
**Goal**: Browse and filter collection contents in list and tile views.

### Phase 5: Polish & Quality of Life
**Goal**: Refine UX, add bulk operations foundation, and prepare for future phases.

---

## Phase 0: Foundation

**Duration**: 1-2 weeks  
**Dependencies**: None

### 0.1 Project Setup ✅ **COMPLETE**

**Status**: Completed 2025-12-27
**Commits**: T001–T009 (9 commits)

Establish the Rails 8.1 application with core dependencies and configuration.

**Completed Deliverables**:
- ✅ Rails 8.1 new application with SQLite configuration
- ✅ Tailwind CSS integration with MTG color theme
- ✅ Turbo and Stimulus configuration with controller structure
- ✅ ViewComponent gem installed (v4.1.1)
- ✅ ApplicationComponent base class with helper methods
- ✅ Basic application layout with responsive navigation shell
- ✅ Turbo Frame targets: `flash_messages` and `modal`
- ✅ Development environment configuration (linting, testing framework)
- ✅ RSpec 8.0.2 with FactoryBot integration
- ✅ Capybara + Cuprite for system tests
- ✅ ViewComponent test helpers configured
- ✅ Spec directory structure (components, factories, models, requests, system)
- ✅ RuboCop Omakase style checking
- ✅ Brakeman security scanning
- ✅ CI script integration (`bin/ci`)
- ✅ Database migrations directory created

**Test Coverage**:
- ApplicationComponent: 15 specs, all passing
- CI checks: All passing (setup, style, security)

**Key Files Created**:
- `app/components/application_component.rb` - Base component with badge styling helpers
- `app/assets/tailwind/application.css` - Tailwind v4 with MTG color theme
- `app/views/layouts/application.html.erb` - Responsive layout with nav and Turbo Frames
- `app/javascript/controllers/` - Stimulus controller structure
- `spec/support/` - Test helper configuration
- `Procfile.dev` - Development process manager

**Out of Scope**:
- Authentication (single-user MVP)
- Production deployment configuration

### 0.2 Catalog Infrastructure

Create the catalog abstraction layer that supports multiple data sources.

**Scope**:
- `Catalog` model with adapter pattern support
  - `name` (string)
  - `source_type` (string: "mtgjson", "api", "custom")
  - `source_config` (jsonb)
- `CatalogAdapter` base class defining the adapter interface
- `MTGJSONAdapter` implementation for MTGJSON data source
- Rake task to initialize default MTGJSON-backed catalog

**Adapter Interface**:
```ruby
class CatalogAdapter
  def search(query, options = {})
  def fetch_entry(identifier)
  def bulk_import(options = {})
end
```

**Rationale**: The adapter pattern is established from the start to support fast-follow additions of API-based catalogs for comics or books. The abstraction adds minimal overhead while providing clear extension points.

### 0.3 MTGJSON Data Import

Import MTG card reference data from MTGJSON into the local database.

**Scope**:
- Download and process MTGJSON AllPrintings SQLite file
- `MTGSet` model with set metadata:
  - `code` (string, unique)
  - `name` (string)
  - `release_date` (date)
  - `set_type` (string)
  - `card_count` (integer)
  - `icon_uri` (string)
- `MTGCard` model with card attributes mapped from MTGJSON schema
- `MTGCard` serves as the concrete catalog entry type for MTG collections
- Store both `uuid` (MTGJSON) and `scryfall_id` for cross-reference
- Index key search fields (name, set_code, collector_number)
- Full-text search index on name using SQLite FTS5

**Key Attributes for MTGCard**:
- Identity: `uuid`, `scryfall_id`, `name`, `set_code`, `collector_number`
- Display: `mana_cost`, `mana_value`, `type_line`, `oracle_text`, `power`, `toughness`, `rarity`
- Categorization: `colors` (array), `color_identity` (array)
- Variants: `finishes` (array: nonfoil, foil, etched), `frame_effects`, `promo_types`
- Reference: `source_data` (jsonb for full MTGJSON payload)

**Data Volume**: ~80,000+ unique printings across 100+ sets

**Acceptance Criteria**:
- [ ] Full MTGJSON import completes successfully
- [ ] MTGCard lookup by uuid, scryfall_id, and name+set works correctly
- [ ] Import is idempotent (re-running doesn't duplicate data)
- [ ] Meta version tracking enables incremental updates
- [ ] FTS5 search returns relevant results for partial name matches

### 0.4 Core Domain Models

Establish the collection layer models per the core data model.

**Scope**:
- `Collection` model:
  - `name` (string)
  - `description` (text)
  - `item_type` (string)
  - `catalog_id` (FK, 1:1 with Catalog)
- `StorageUnit` model with self-referential nesting:
  - `name` (string)
  - `unit_type` (string: shelf, box, binder, deck)
  - `notes` (text)
  - `parent_id` (FK, self-referential)
- `CollectionStorageUnit` join model for multi-collection storage support
- `Item` model with polymorphic catalog entry reference:
  - `collection_id` (FK)
  - `storage_unit_id` (FK, optional)
  - `catalog_entry_type` (string, e.g., "MTGCard")
  - `catalog_entry_id` (FK)
  - `quantity` (integer, default: 1)
  - `acquisition_price` (decimal)
  - `acquisition_date` (date)
  - `notes` (text)
  - Delegated type: `detail_type`, `detail_id`
- `MTGCardItemDetail` model (Item delegated type):
  - `condition` (string, default: "NM")
  - `finish` (string, default: "nonfoil")
  - `language` (string, default: "EN")
  - `signed`, `altered`, `graded` (booleans, default: false)
  - `grading_service`, `grade` (strings)

**Default Data**:
- Create default "My Collection" collection on first run
- Associate with default MTGJSON-backed catalog

**Polymorphic Reference Explanation**:
Items reference their catalog entry (what card this is) via polymorphic `catalog_entry` association. This allows Items to point to `MTGCard`, `CustomMTGCard`, or future types like `ComicEntry`. The delegated type `detail` holds physical-instance attributes specific to the item type.

**Constraints**:
- Items belong to a Collection
- Items optionally belong to a StorageUnit
- Item's StorageUnit must belong to Item's Collection (validated)
- StorageUnit collection scope validation (child subset of parent)

---

## Phase 1: Card Discovery

**Duration**: 2-3 weeks  
**Dependencies**: Phase 0 complete

### 1.1 Set Browser

Provide a browsable list of all MTG sets for navigation.

**Scope**:
- Index page listing all sets, grouped by set type (expansion, core, masters, etc.)
- Set card showing: set icon/symbol, name, code, release date, card count
- Sort options: release date (default), alphabetical, card count
- Filter by set type
- Click-through to set detail view

**UI Considerations**:
- Responsive grid layout (4 cols desktop → 1 col mobile)
- Lazy loading or pagination for performance
- Set symbols from Scryfall's SVG CDN where available

**Component**: `Catalog::SetCardComponent`

### 1.2 Set Detail View

Display all cards within a selected set.

**Scope**:
- Header with set metadata (name, release date, total cards)
- Card grid showing all cards in collector number order
- Card thumbnails using Scryfall `small` size images
- Toggle between grid (tile) and list views
- Click-through to card detail view
- Basic rarity filtering (common, uncommon, rare, mythic)

**Performance**:
- Paginate or virtual scroll for large sets (300+ cards)
- Image lazy loading with placeholder

**Component**: `Catalog::CardThumbnailComponent`

### 1.3 Card Search

Enable searching across the entire catalog by name with set filtering.

**Scope**:
- Search input with type-ahead/autocomplete behavior
- Search by card name (partial match via FTS5)
- Filter results by set (dropdown or chips)
- Results displayed as paginated list with card thumbnails
- Click-through to card detail view
- Empty state and no-results messaging

**Search Behavior**:
- Debounced input (300ms) to avoid excessive queries
- Minimum 2 characters to trigger search
- Results ordered by relevance (exact match first, then alphabetical)
- Show set code and collector number in results for disambiguation

**Performance**:
- SQLite FTS5 full-text search for name field
- Limit results to 50 per page

**Stimulus Controller**: `search_controller.js`

### 1.4 Card Detail View

Display complete card information with high-quality image.

**Scope**:
- Large card image (Scryfall `normal` or `large` size)
- Full card metadata display:
  - Name, mana cost (with mana symbols), type line
  - Oracle text (with mana/tap symbols rendered)
  - Power/toughness (if creature)
  - Rarity, set name, collector number
  - Available finishes for this printing
- "Add to Collection" call-to-action button
- Link to other printings of the same card (by name)

**Image Handling**:
- Double-faced cards: show both faces with flip/toggle
- Split/Adventure cards: appropriate layout
- Fallback placeholder for missing images

**Component**: `Catalog::CardDetailComponent`

**Future Hooks**:
- Placeholder for price display (Phase N)
- Placeholder for legality display (Phase N)

---

## Phase 2: Item Management

**Duration**: 2-3 weeks  
**Dependencies**: Phase 1 complete

### 2.1 Quick Add Flow

Enable adding cards to collection with minimal friction.

**Scope**:
- Triggered from Card Detail View "Add to Collection" button
- Modal or slide-out panel workflow (Turbo Frame into `modal` frame)
- Required: Card selection (pre-filled from context)
- Required: Finish selection (nonfoil/foil/etched based on card's available finishes)
- Optional: Condition (defaults to NM)
- Optional: Notes field (free text)
- Optional: Storage unit assignment (dropdown, can be blank)
- Confirm button creates Item + MTGCardItemDetail

**Defaults** (minimal required input):
- Condition: Near Mint
- Language: English
- Quantity: 1
- All grading/signed/altered flags: false

**Validation**:
- Selected finish must be valid for the card printing
- Storage unit must belong to the collection (if selected)

**Post-Add Behavior**:
- Success toast/notification via Turbo Stream
- Option to "Add Another" (same card, reset form)
- Option to "View in Collection"

**Acceptance Criteria**:
- [ ] Can add a card with just 2 clicks (Add → Confirm with defaults)
- [ ] Finish dropdown only shows valid options for the card
- [ ] Success feedback appears without full page reload

### 2.2 Item List View

Display all items in a collection with sorting and filtering.

**Scope**:
- Paginated list of all items in collection
- List row shows: card thumbnail, name, set, collector number, finish, condition
- Sort by: name (default), date added, set, collector number
- Filter by: finish, condition, set
- Click-through to Item Detail View
- Bulk selection checkboxes (UI only, functionality in Phase 5)

**Performance**:
- Eager load card and detail associations
- 50 items per page default

**Component**: `Collection::ItemRowComponent`

### 2.3 Item Detail View

Display and edit complete item information.

**Scope**:
- Card image and core card data (from catalog entry via polymorphic reference)
- Editable item fields:
  - Condition (NM, LP, MP, HP, DMG)
  - Finish (constrained to valid options for printing)
  - Language (EN, JP, DE, FR, etc.)
  - Signed (boolean)
  - Altered (boolean)
  - Graded (boolean) → reveals grading_service and grade fields
  - Notes (text)
  - Storage Unit assignment
- Acquisition fields:
  - Acquisition date (date picker)
  - Acquisition price (decimal)
- Quantity field (for bulk storage scenarios)
- Save/Cancel buttons with optimistic UI
- Delete item with confirmation

**Validation**:
- Finish must be valid for the card
- Grade fields required if graded is true

**Component**: `Collection::ItemDetailComponent`

### 2.4 Item Reassignment

Move items between storage units.

**Scope**:
- From Item Detail View: change storage unit dropdown
- Storage unit dropdown shows hierarchy (indented or breadcrumb format)
- "Remove from storage" option (set storage_unit to null)
- Validate collection scope constraints

---

## Phase 3: Storage Organization

**Duration**: 2 weeks  
**Dependencies**: Phase 0.4 complete (can parallel with Phase 1-2)

### 3.1 Storage Unit Types

Define the initial storage unit types.

**Types**:
- `shelf` — A shelf or section of shelving
- `box` — A cardboard box, BCW box, or similar container
- `binder` — A binder with pages/slots
- `deck` — A constructed deck (sleeved cards for play)

**Type Behaviors**:
- All types support nesting (binder on a shelf, deck in a box)
- Type is descriptive/organizational, not functionally different in MVP
- Icon/visual differentiation per type in UI

### 3.2 Storage Unit CRUD

Create, read, update, delete storage units.

**Scope**:
- Storage Units index page listing all units in hierarchical tree view
- Create new storage unit:
  - Name (required)
  - Type (required, from defined list)
  - Parent unit (optional, for nesting)
  - Notes (optional)
  - Collection associations (multi-select, defaults to current collection)
- Edit storage unit (all fields except type changeable post-creation)
- Delete storage unit:
  - Confirmation required
  - If unit contains items: option to reassign or remove from storage
  - If unit has children: must reassign or delete children first

**Hierarchy Display**:
- Tree view with expand/collapse
- Show item count per unit
- Drag-and-drop reordering (nice-to-have, can defer)

**Component**: `Storage::UnitTreeComponent`, `Storage::UnitCardComponent`

### 3.3 Storage Unit Detail View

Display storage unit contents and metadata.

**Scope**:
- Unit metadata (name, type, notes, parent breadcrumb)
- Child units list (if any)
- Items in this unit (list and tile view toggle)
- Same filtering/sorting as Item List View
- "Add Item" shortcut (opens Quick Add with storage pre-selected)
- Edit and Delete buttons

### 3.4 Nested Storage Navigation

Navigate the storage hierarchy effectively.

**Scope**:
- Breadcrumb navigation showing path from root
- Parent link in unit header
- Sidebar or tree navigator showing full hierarchy
- Deep linking support (URL reflects current unit)

**Stimulus Controller**: `tree_controller.js`

---

## Phase 4: Collection Views

**Duration**: 1-2 weeks  
**Dependencies**: Phases 2 and 3 complete

### 4.1 Collection Dashboard

High-level collection overview and entry point.

**Scope**:
- Total item count (respecting quantity field)
- Breakdown by finish (nonfoil/foil/etched)
- Recently added items (last 10)
- Quick links to:
  - Full item list
  - Storage units
  - Card search
- Stats placeholder (for future: value, set completion)

### 4.2 List View Enhancements

Refine the item list view for collection browsing.

**Scope**:
- Column customization (show/hide columns)
- Saved filter presets (nice-to-have)
- Export current view as CSV (basic implementation)
- "Cards I Own" indicator when browsing catalog

### 4.3 Tile View

Visual grid browsing of collection items.

**Scope**:
- Responsive grid of card images
- Card image shows condition/finish badge overlay
- Hover state shows quick info (name, set, condition)
- Click opens Item Detail View
- Same filtering/sorting options as list view
- Toggle between list and tile views (persisted preference)

**Component**: `Collection::ItemTileComponent`

### 4.4 Cross-Collection Browsing

Browse cards across multiple contexts.

**Scope**:
- "All Items" view spanning entire collection
- "By Set" grouping (which sets do I have cards from?)
- "By Storage" grouping (quick jump to storage units)
- Filter by "has no storage" to find unorganized cards

---

## Phase 5: Polish & Quality of Life

**Duration**: 1-2 weeks  
**Dependencies**: Phases 1-4 complete

### 5.1 Duplicate Detection

Help users identify potential duplicate entries.

**Scope**:
- When adding a card: show "You already own X copies" notice
- Duplicate finder tool: list cards where multiple items exist
- Optional: merge duplicates (adjust quantity or keep separate)

### 5.2 Bulk Add Foundation

Prepare for future bulk operations without full implementation.

**Scope**:
- CSV import UI (upload file, map columns)
- Preview import before committing
- Support Moxfield/Deckbox export formats
- Error handling for unmatched cards
- Import history log

**Out of Scope for MVP**:
- Camera/scanner integration
- API-based import from other platforms

### 5.3 Performance Optimization

Ensure smooth operation with 4,000+ items.

**Scope**:
- Database query optimization (N+1 prevention, proper indexing)
- Image loading optimization (lazy load, placeholder shimmer)
- Turbo Frame/Stream optimization for partial updates
- Local storage for offline catalog browsing (nice-to-have)

### 5.4 Responsive Design Audit

Ensure mobile-friendly experience across all views.

**Scope**:
- Touch-friendly tap targets (min 44px)
- Mobile-appropriate navigation (hamburger menu, bottom nav considerations)
- Card detail modal sizing on small screens
- Storage hierarchy navigation on mobile

---

## Deferred Features (Post-MVP)

The following features are explicitly out of scope for MVP but the architecture should not preclude them:

### Future Phase: Pricing & Value
- Display current market prices on cards
- Collection value totals
- Price history tracking
- Value change notifications

### Future Phase: Set Completion
- Track completion percentage by set
- Breakdown by rarity
- Wishlist for missing cards
- "Need" vs "Have" views

### Future Phase: Deck Management
- Deck as special storage unit type
- Format legality validation
- Deck statistics (mana curve, color distribution)
- "Cards in use" tracking across decks

### Future Phase: Trade Management
- Tradelist as collection subset
- Wishlist for wanted cards
- Trade matching with other users (requires multi-user)

### Future Phase: Additional Catalog Types
- Comics via ApiAdapter (ComicVine, GCD, or similar)
- Books via ApiAdapter (Open Library, Google Books)
- Custom entries for any collectible type

### Future Phase: Multi-User & Sharing
- User authentication
- Multiple collections per user
- Shared collections (household)
- Public collection profiles

### Future Phase: Mobile Apps
- Hotwire Native iOS app
- Hotwire Native Android app
- Camera scanning integration
- Offline-first sync

---

## Technical Decisions

### Catalog Abstraction

**Decision**: Adapter pattern from MVP start

**Rationale**:
- Minimal overhead (one base class, one MVP implementation)
- Clear extension point for API-based catalogs (comics, books)
- Source-agnostic Item references via polymorphic association
- Allows future CustomMTGCard entries for uncataloged items

### MTGJSON vs API

**Decision**: Local MTGJSON SQLite import for MTG catalog

**Rationale**:
- Offline capability requirement satisfied
- No API rate limits during search/browse
- Complete data set available immediately
- ~100MB database size is acceptable for target scale

**Update Strategy**:
- Weekly background job checks MTGJSON Meta.json for new version
- Incremental update imports only changed/new sets
- User-triggerable manual refresh

### Image Handling

**Decision**: Hotlink Scryfall CDN for MVP

**Rationale**:
- Scryfall explicitly allows CDN hotlinking (no rate limits)
- Avoids storage costs and complexity
- Images always current

**Future Consideration**:
- Progressive caching for offline access
- ActiveStorage for user-uploaded alt images

### Individual vs Quantity Tracking

**Decision**: Default one row per physical card, with quantity field for bulk scenarios

**Rationale**:
- Supports varying conditions/finishes for "same" card
- Enables per-item notes and acquisition tracking
- Quantity field provides escape hatch for bulk/unsorted storage (e.g., "500 commons in Box 3")
- When quantity > 1, all items share same detail attributes
- Slight storage overhead acceptable at target scale

### Multi-Collection Storage

**Decision**: Support from MVP via CollectionStorageUnit join table

**Rationale**:
- Models real-world storage (shelf holding binders from different collections)
- Architecture supports future multi-collection households
- Minimal complexity added (one join table)
- Constraints ensure items only in storage units belonging to their collection

---

## Success Metrics (MVP)

1. **Functional**: Can add 100+ cards to collection in under 30 minutes
2. **Performance**: Search results return in under 500ms
3. **Usability**: Core workflows completable on mobile browser
4. **Data Integrity**: No data loss during storage unit reorganization
5. **Maintainability**: Test coverage >80% on models and critical paths

---

## Revision History

| Date       | Author | Changes                                      |
|------------|--------|----------------------------------------------|
| 2025-01-XX | —      | Initial roadmap based on design discussions  |
| 2025-01-XX | —      | Added Catalog abstraction to Phase 0, aligned model naming with CORE_DATA_MODEL, clarified quantity field usage |
| 2025-12-27 | Claude | Phase 0.1 Project Setup completed (T001–T009): Rails 8.1 app bootstrapped with Tailwind, ViewComponent, Turbo/Stimulus, RSpec, and CI configuration |
