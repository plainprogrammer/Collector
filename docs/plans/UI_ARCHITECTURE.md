# UI Architecture & Component Patterns

## Overview

This document defines the UI architecture for Collector, establishing patterns for ViewComponent usage, responsive design strategy, and component interfaces. The goal is consistency and maintainability while allowing Claude Code flexibility in implementation details.

**Stack**: ViewComponent, Tailwind CSS (utilities only), Turbo, Stimulus
**Design Approach**: Desktop-first responsive design
**Breakpoints**: Tailwind defaults (`sm:640px`, `md:768px`, `lg:1024px`, `xl:1280px`)

---

## ViewComponent Configuration

### Directory Structure

```
app/
├── components/
│   ├── application_component.rb      # Base class for all components
│   ├── ui/                           # Generic UI primitives
│   │   ├── button_component.rb
│   │   ├── card_component.rb
│   │   ├── modal_component.rb
│   │   ├── empty_state_component.rb
│   │   ├── flash_component.rb
│   │   ├── form_field_component.rb
│   │   ├── loading_skeleton_component.rb
│   │   └── ...
│   ├── catalog/                      # Card catalog browsing components
│   │   ├── card_thumbnail_component.rb
│   │   ├── card_detail_component.rb
│   │   ├── card_image_component.rb
│   │   ├── set_card_component.rb
│   │   ├── set_list_component.rb
│   │   ├── search_results_component.rb
│   │   └── ...
│   ├── collection/                   # Collection management components
│   │   ├── item_row_component.rb
│   │   ├── item_tile_component.rb
│   │   ├── item_detail_component.rb
│   │   ├── quick_add_form_component.rb
│   │   └── ...
│   └── storage/                      # Storage organization components
│       ├── unit_tree_component.rb
│       ├── unit_card_component.rb
│       ├── unit_breadcrumb_component.rb
│       └── ...
```

### Domain-Based Namespacing

Components are organized by **domain** (user activity) rather than by **model** (data structure). This approach:

1. **Survives model changes**: Renaming `MTGCard` to `Card` doesn't require renaming `Catalog::` components
2. **Extends naturally**: Adding comics uses the same `Catalog::` namespace for browsing
3. **Reflects user mental model**: Users think "browse the catalog" not "view MTGCard records"
4. **Separates concerns**: `Catalog::CardDetailComponent` shows card data; `Collection::ItemDetailComponent` shows owned-item data

| Domain | Purpose | Model References |
|--------|---------|------------------|
| `Catalog::` | Browsing available cards/items | MTGCard, MTGSet, (future: ComicEntry) |
| `Collection::` | Managing owned items | Item, MTGCardItemDetail |
| `Storage::` | Organizing physical storage | StorageUnit |
| `UI::` | Generic, reusable primitives | None (model-agnostic) |

### Base Component

All components inherit from `ApplicationComponent`, which provides shared helpers and conventions:

```ruby
# app/components/application_component.rb
class ApplicationComponent < ViewComponent::Base
  # Common helpers available to all components
  
  # Mana symbol rendering
  def mana_symbols(cost_string)
    # Parses {W}{U}{2} etc. and renders inline images
  end
  
  # Condition badge styling
  def condition_class(condition)
    # Returns appropriate Tailwind classes for condition
  end
end
```

### Naming Conventions

- Component classes: `{Domain}::{Name}Component` (e.g., `Catalog::CardThumbnailComponent`)
- Template files: `{name}_component.html.erb` in same directory as Ruby class
- Stimulus controllers (when needed): Named in component, referenced via `data-controller`

---

## Responsive Design Strategy

### Desktop-First Approach

Design for desktop viewport first, then adapt for smaller screens using Tailwind's responsive prefixes in "mobile override" pattern:

```erb
<%# Desktop default, then mobile overrides %>
<div class="grid grid-cols-4 lg:grid-cols-3 md:grid-cols-2 sm:grid-cols-1">
```

### Breakpoint Usage

| Breakpoint | Target | Common Adaptations |
|------------|--------|-------------------|
| Default | Desktop (1280px+) | Full layouts, data tables, side-by-side panels |
| `lg:` | Small desktop/tablet landscape | Reduce columns, compress spacing |
| `md:` | Tablet portrait | Stack panels, simplify navigation |
| `sm:` | Mobile | Single column, bottom navigation, modals fullscreen |

### Layout Patterns

**Primary Layout**: Sidebar navigation (desktop) → Bottom/hamburger navigation (mobile)

**Content Patterns**:
- Data grids: 4+ columns (desktop) → 1-2 columns (mobile)
- Detail views: Side-by-side image/data (desktop) → Stacked (mobile)
- Forms: Multi-column (desktop) → Single column (mobile)

---

## Component Interface Specifications

### UI Primitives

These are generic, reusable components with no domain knowledge.

#### ButtonComponent

Renders a button or link styled as a button.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `label` | String | Yes | Button text |
| `variant` | Symbol | No | `:primary`, `:secondary`, `:danger`, `:ghost` (default: `:primary`) |
| `size` | Symbol | No | `:sm`, `:md`, `:lg` (default: `:md`) |
| `href` | String | No | If provided, renders as `<a>` instead of `<button>` |
| `disabled` | Boolean | No | Disabled state |
| `type` | String | No | Button type for forms (default: `"button"`) |
| `data` | Hash | No | Data attributes (Turbo, Stimulus, etc.) |

#### CardComponent

A container with consistent padding, border, and shadow. Accepts a content block.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `padding` | Symbol | No | `:none`, `:sm`, `:md`, `:lg` (default: `:md`) |
| `hoverable` | Boolean | No | Apply hover state styling |

#### ModalComponent

A dialog container. Content provided via blocks/slots.

| Slot | Description |
|------|-------------|
| `header` | Modal title area |
| `body` | Main content |
| `footer` | Action buttons |

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `size` | Symbol | No | `:sm`, `:md`, `:lg`, `:full` (default: `:md`) |
| `dismissable` | Boolean | No | Show close button (default: `true`) |

#### FormFieldComponent

Wraps a form input with label, error display, and help text.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `attribute` | Symbol | Yes | Form attribute name |
| `label` | String | No | Label text (defaults to humanized attribute) |
| `help` | String | No | Help text below input |
| `required` | Boolean | No | Show required indicator |

Content block receives the form builder for rendering the actual input.

#### EmptyStateComponent

Displayed when a list or container has no content.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | String | Yes | Primary message |
| `description` | String | No | Secondary explanatory text |
| `icon` | String | No | Icon identifier |
| `action_label` | String | No | CTA button label |
| `action_href` | String | No | CTA button destination |

#### FlashComponent

Displays a flash message with appropriate styling and auto-dismiss.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | Symbol | Yes | `:success`, `:error`, `:warning`, `:info` |
| `message` | String | Yes | Message text |
| `dismissable` | Boolean | No | Show dismiss button (default: `true`) |
| `auto_dismiss` | Boolean | No | Auto-dismiss after timeout (default: `true`) |

#### LoadingSkeletonComponent

Placeholder content shown during loading states.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | Symbol | Yes | `:card_grid`, `:list`, `:detail`, `:text` |
| `count` | Integer | No | Number of skeleton items (default: varies by type) |

### Domain Components

These components have knowledge of domain models and business logic.

#### Catalog::SetCardComponent

Summary card for a set in the set browser.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `set` | MTGSet | Yes | The set record |
| `show_card_count` | Boolean | No | Display card count (default: `true`) |
| `linkable` | Boolean | No | Wrap in link to set detail (default: `true`) |

#### Catalog::SetListComponent

Renders a grouped list of sets (by set type).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `sets` | Collection | Yes | MTGSet records to display |
| `group_by` | Symbol | No | Grouping attribute (default: `:set_type`) |

#### Catalog::CardThumbnailComponent

Displays a card image thumbnail with basic info overlay.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `card` | MTGCard | Yes | The card record |
| `size` | Symbol | No | `:small`, `:normal` (default: `:small`) |
| `show_set` | Boolean | No | Display set code badge |
| `linkable` | Boolean | No | Wrap in link to card detail (default: `true`) |

#### Catalog::CardDetailComponent

Full card display with image and all metadata.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `card` | MTGCard | Yes | The card record |
| `show_add_button` | Boolean | No | Display "Add to Collection" CTA |

#### Catalog::CardImageComponent

Handles card image display with fallback and double-faced card support.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `card` | MTGCard | Yes | The card record |
| `size` | Symbol | No | `:small`, `:normal`, `:large` (default: `:normal`) |
| `face` | Symbol | No | `:front`, `:back` (default: `:front`) |
| `show_flip_button` | Boolean | No | Show flip button for DFCs (default: `true` if DFC) |

#### Catalog::SearchResultsComponent

Displays search results with card thumbnails.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `cards` | Collection | Yes | MTGCard search results |
| `query` | String | No | Original search query (for highlighting) |

#### Collection::ItemRowComponent

A single item in list view format.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item` | Item | Yes | The item record (with detail association) |
| `selectable` | Boolean | No | Show selection checkbox |
| `selected` | Boolean | No | Current selection state |

#### Collection::ItemTileComponent

A single item in grid/tile view format.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item` | Item | Yes | The item record |
| `show_badges` | Boolean | No | Display condition/finish badges (default: `true`) |

#### Collection::ItemDetailComponent

Full item display with editable fields.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item` | Item | Yes | The item record |
| `editable` | Boolean | No | Enable inline editing (default: `false`) |

#### Collection::QuickAddFormComponent

Form for quickly adding a card to collection.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `card` | MTGCard | Yes | The card to add |
| `collection` | Collection | Yes | Target collection |
| `storage_units` | Collection | No | Available storage units |

#### Storage::UnitTreeComponent

Renders hierarchical storage unit tree.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `units` | Collection | Yes | Root-level StorageUnit records |
| `selected_id` | UUID | No | Currently selected unit ID |
| `collapsible` | Boolean | No | Allow expand/collapse (default: `true`) |

#### Storage::UnitCardComponent

Summary card for a storage unit.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `unit` | StorageUnit | Yes | The storage unit record |
| `show_item_count` | Boolean | No | Display item count (default: `true`) |

#### Storage::UnitBreadcrumbComponent

Breadcrumb navigation for storage hierarchy.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `unit` | StorageUnit | Yes | Current storage unit |
| `linkable` | Boolean | No | Make ancestors clickable (default: `true`) |

---

## Icon Strategy

Use [Heroicons](https://heroicons.com/) via the `heroicon` gem or inline SVG helpers.

**Usage Pattern**:
```erb
<%= heroicon "magnifying-glass", variant: :outline, class: "w-5 h-5" %>
```

**Common Icons**:
- Navigation: `home`, `folder`, `magnifying-glass`, `plus`
- Actions: `pencil`, `trash`, `arrow-path`, `check`
- Status: `exclamation-circle`, `check-circle`, `information-circle`
- Domain: `rectangle-stack` (collection), `archive-box` (storage)

---

## Tailwind Configuration

Extend Tailwind's default configuration minimally. Avoid custom design tokens unless a clear pattern emerges.

**Recommended Extensions** (if needed):
- Custom colors for MTG mana symbols (white, blue, black, red, green, colorless)
- Animation for loading states

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        mtg: {
          white: '#F8F6D8',
          blue: '#0E68AB',
          black: '#150B00',
          red: '#D3202A',
          green: '#00733E',
          colorless: '#CBC2BF',
        }
      }
    }
  }
}
```

---

## Mana Symbol Rendering

Oracle text and mana costs contain symbols like `{W}`, `{U}`, `{2}`. These should be rendered as inline images or SVG sprites.

**Approach**: Helper method that parses symbol syntax and renders appropriate markup.

```ruby
# Expected interface
mana_symbols("{2}{W}{W}") 
# => <span class="mana-cost"><img src="..." alt="2">...</span>
```

**Image Source**: Scryfall's SVG symbology API or local sprite sheet.

**Symbol Types**:
- Mana: `{W}`, `{U}`, `{B}`, `{R}`, `{G}`, `{C}` (colorless)
- Generic: `{0}` through `{20}`, `{X}`
- Hybrid: `{W/U}`, `{2/W}`
- Phyrexian: `{W/P}`
- Tap/Untap: `{T}`, `{Q}`

---

## Component Testing

All components should have corresponding specs in `spec/components/`.

**Test Priorities**:
- Correct rendering with required parameters
- Variant/option behavior
- Slot content rendering
- Accessibility attributes (ARIA labels, roles)

See Testing Strategy document for detailed patterns.

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-01-XX | — | Initial draft |
| 2025-01-XX | — | Added domain-based namespacing rationale, additional Catalog and Collection components |
