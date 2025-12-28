# Turbo & Stimulus Patterns

## Overview

This document defines patterns for Turbo and Stimulus usage in Collector. Turbo Frames are the primary mechanism for partial page updates, with Turbo Streams reserved for specific multi-target scenarios. These patterns are designed with future Hotwire Native mobile apps in mind.

**Primary Pattern**: Turbo Frames for scoped updates
**Secondary Pattern**: Turbo Streams for flash messages and multi-element updates
**Navigation**: Standard Turbo Drive for full-page transitions

---

## Turbo Frames

### Naming Conventions

Frame IDs should be descriptive and follow a consistent pattern:

```
{domain}_{resource}_{context}
```

**Examples**:
- `catalog_card_detail` — Card detail panel
- `catalog_set_cards` — Cards grid within a set
- `catalog_search_results` — Search results container
- `collection_items_list` — Items list container
- `storage_unit_tree` — Storage hierarchy navigator
- `storage_unit_content` — Selected unit's contents
- `modal` — Global modal container (singleton)
- `flash_messages` — Flash message container

For resource-specific frames that appear multiple times, include the ID:

```
item_{id}
storage_unit_{id}
```

### Frame Patterns

#### Content Replacement

The most common pattern: clicking a link replaces frame content.

```erb
<%# Index page with list in a frame %>
<%= turbo_frame_tag "collection_items_list" do %>
  <%= render @items %>
<% end %>

<%# Link that updates just the list (e.g., pagination, filtering) %>
<%= link_to "Next", items_path(page: 2), data: { turbo_frame: "collection_items_list" } %>
```

#### Lazy Loading

Defer loading of non-critical content:

```erb
<%= turbo_frame_tag "set_completion_stats", src: set_stats_path(@set), loading: :lazy do %>
  <%= render LoadingSkeletonComponent.new(type: :text) %>
<% end %>
```

#### Modal Pattern

Use a dedicated modal frame that can be targeted from anywhere:

```erb
<%# In application layout %>
<%= turbo_frame_tag "modal" %>

<%# Link that opens content in modal %>
<%= link_to "Add to Collection", new_item_path(card_id: @card.id), data: { turbo_frame: "modal" } %>

<%# Modal response wraps content in the frame %>
<%= turbo_frame_tag "modal" do %>
  <%= render ModalComponent.new do |modal| %>
    <% modal.with_header { "Add to Collection" } %>
    <% modal.with_body do %>
      <%= render "form" %>
    <% end %>
  <% end %>
<% end %>
```

#### Breaking Out of Frames

When a frame action should trigger full navigation (e.g., after successful form submission):

```ruby
# Controller
def create
  @item = Item.new(item_params)
  if @item.save
    redirect_to @item, notice: "Item added"
    # Turbo will do a full page visit for redirects outside the frame
  else
    render :new, status: :unprocessable_entity
  end
end
```

Or explicitly break out with `data-turbo-frame="_top"`:

```erb
<%= link_to "View Full Details", card_path(@card), data: { turbo_frame: "_top" } %>
```

### Frame Nesting

Frames can be nested for granular updates. Child frames don't affect parent frames.

```erb
<%= turbo_frame_tag "storage_browser" do %>
  <div class="flex">
    <%= turbo_frame_tag "storage_unit_tree" do %>
      <%# Tree navigation here %>
    <% end %>
    
    <%= turbo_frame_tag "storage_unit_content" do %>
      <%# Selected unit's contents here %>
    <% end %>
  </div>
<% end %>
```

---

## Turbo Streams

Reserved for cases where Turbo Frames are insufficient.

### Approved Use Cases

1. **Flash Messages**: Display notifications without full page reload
2. **Counter Updates**: Update counts in navigation/headers after CRUD operations
3. **Multi-Element Updates**: Rare cases requiring updates to multiple unrelated DOM areas

### Flash Message Pattern

```erb
<%# app/views/layouts/application.html.erb %>
<%= turbo_frame_tag "flash_messages" do %>
  <% flash.each do |type, message| %>
    <%= render FlashComponent.new(type: type, message: message) %>
  <% end %>
<% end %>

<%# After successful action, stream the flash %>
<%# app/views/items/create.turbo_stream.erb %>
<%= turbo_stream.update "flash_messages" do %>
  <%= render FlashComponent.new(type: :success, message: "Item added to collection") %>
<% end %>

<%= turbo_stream.append "collection_items_list" do %>
  <%= render @item %>
<% end %>
```

### Stream Actions Reference

| Action | Use Case |
|--------|----------|
| `append` | Add to end of container (new list item) |
| `prepend` | Add to start of container (newest first) |
| `replace` | Replace entire element |
| `update` | Replace element's innerHTML only |
| `remove` | Delete element from DOM |

---

## Stimulus Controllers

### Directory Structure

```
app/javascript/controllers/
├── application.js
├── index.js
├── dropdown_controller.js
├── modal_controller.js
├── search_controller.js
├── flash_controller.js
├── tree_controller.js
├── card_flip_controller.js
├── form_validation_controller.js
└── ...
```

### Naming Conventions

- Controller files: `{name}_controller.js` (snake_case)
- Data attributes: `data-controller="{name}"` (kebab-case)
- Actions: `data-action="{event}->{controller}#{method}"`
- Targets: `data-{controller}-target="{name}"`
- Values: `data-{controller}-{name}-value="{value}"`

### Common Controllers

#### ModalController

Handles modal open/close behavior and backdrop clicks.

```javascript
// Expected interface
// data-controller="modal"
// data-action="click->modal#close" (on backdrop)
// data-action="keydown.escape@window->modal#close"
// data-modal-target="container"
```

**Responsibilities**:
- Toggle visibility classes
- Trap focus within modal
- Handle escape key
- Prevent body scroll when open

#### DropdownController

Toggle dropdown menus with click-outside-to-close.

```javascript
// Expected interface
// data-controller="dropdown"
// data-action="click->dropdown#toggle" (on trigger)
// data-action="click@window->dropdown#closeOnClickOutside"
// data-dropdown-target="menu"
```

#### SearchController

Debounced search input that triggers Turbo Frame updates.

```javascript
// Expected interface
// data-controller="search"
// data-search-url-value="/cards/search"
// data-search-frame-value="catalog_search_results"
// data-action="input->search#perform"
```

**Responsibilities**:
- Debounce input (300ms default)
- Minimum character threshold (2 characters)
- Trigger frame navigation with query params
- Show/hide loading indicator

#### FlashController

Auto-dismiss flash messages after timeout.

```javascript
// Expected interface
// data-controller="flash"
// data-flash-timeout-value="5000"
// data-action="click->flash#dismiss"
```

**Responsibilities**:
- Auto-dismiss after timeout
- Manual dismiss on click
- Animate out gracefully

#### TreeController

Expand/collapse tree nodes (for storage unit hierarchy).

```javascript
// Expected interface
// data-controller="tree"
// data-action="click->tree#toggle" (on node toggle)
// data-tree-target="children" (collapsible container)
// data-tree-expanded-value="false"
```

**Responsibilities**:
- Toggle expand/collapse state
- Persist state in localStorage (optional)
- Animate expand/collapse

#### CardFlipController

Handle double-faced card image flipping.

```javascript
// Expected interface
// data-controller="card-flip"
// data-action="click->card-flip#flip" (on flip button)
// data-card-flip-target="front"
// data-card-flip-target="back"
// data-card-flip-flipped-value="false"
```

**Responsibilities**:
- Toggle between front and back face images
- CSS transition for flip animation
- Keyboard accessibility (Enter/Space to flip)

```erb
<%# Usage in CardImageComponent %>
<div data-controller="card-flip" data-card-flip-flipped-value="false">
  <div data-card-flip-target="front" class="card-face">
    <img src="<%= card.image_url(:normal, face: :front) %>" alt="<%= card.name %> (front)">
  </div>
  <div data-card-flip-target="back" class="card-face hidden">
    <img src="<%= card.image_url(:normal, face: :back) %>" alt="<%= card.name %> (back)">
  </div>
  <button data-action="click->card-flip#flip" aria-label="Flip card">
    <%= heroicon "arrow-path", class: "w-5 h-5" %>
  </button>
</div>
```

#### FormValidationController

Client-side validation feedback (complement to server validation).

```javascript
// Expected interface
// data-controller="form-validation"
// data-action="blur->form-validation#validate" (on inputs)
// data-action="submit->form-validation#validateAll"
```

**Responsibilities**:
- Validate on blur
- Show inline error messages
- Prevent submit if invalid
- Complement, don't replace, server validation

---

## Form Handling

### Standard Pattern

Forms submit via Turbo by default. Use frames to scope the response:

```erb
<%= turbo_frame_tag "item_form" do %>
  <%= form_with model: @item do |f| %>
    <%# form fields %>
    <%= f.submit "Save" %>
  <% end %>
<% end %>
```

### Validation Errors

Return `status: :unprocessable_entity` to re-render form with errors:

```ruby
def create
  @item = Item.new(item_params)
  if @item.save
    redirect_to @item
  else
    render :new, status: :unprocessable_entity
  end
end
```

The form frame will be replaced with the error-state form.

### Forms in Modals

After successful submission, either:

1. **Close modal and redirect**: Return redirect (breaks out of frame)
2. **Close modal and update list**: Return Turbo Stream that removes modal and updates list

```erb
<%# app/views/items/create.turbo_stream.erb %>
<%= turbo_stream.update "modal", "" %>
<%= turbo_stream.prepend "collection_items_list" do %>
  <%= render @item %>
<% end %>
<%= turbo_stream.update "flash_messages" do %>
  <%= render FlashComponent.new(type: :success, message: "Item added") %>
<% end %>
```

---

## Navigation Patterns

### Turbo Drive (Default)

Standard link clicks use Turbo Drive for full-page transitions with:
- Progress bar during load
- Scroll position preservation on back
- Cached page snapshots for instant back navigation

### Disabling Turbo

For specific links or forms that should not use Turbo:

```erb
<%= link_to "External Site", "https://...", data: { turbo: false } %>
```

### Prefetching

Turbo prefetches links on hover. For large pages, disable:

```erb
<%= link_to "Heavy Page", path, data: { turbo_prefetch: false } %>
```

---

## Hotwire Native Considerations

These patterns prepare for future Hotwire Native mobile apps:

### Path Configuration

Hotwire Native apps can intercept paths for native presentation. Design paths to be interceptable:

- `/sets/:code` — Could present as native push
- `/cards/:id` — Could present as native push
- `/items/new` — Could present as native modal
- `/storage_units/:id/edit` — Could present as native modal

### Bridge Components

Future Hotwire Native apps use "bridge components" to trigger native UI. Prepare by:

1. Using consistent `data-` attributes that can be recognized
2. Keeping modals/sheets as separate routes (not inline toggles)
3. Designing touch-friendly tap targets (min 44px)

### Form Considerations

Native apps may want to intercept form submissions. Keep forms:
- At distinct routes (not inline in pages)
- Using standard `form_with` patterns
- Returning standard Turbo responses

---

## Anti-Patterns to Avoid

### ❌ Overusing Turbo Streams

Don't use Streams when a Frame redirect works:

```ruby
# Avoid: Stream for simple CRUD
def destroy
  @item.destroy
  respond_to do |format|
    format.turbo_stream { render turbo_stream: turbo_stream.remove(@item) }
  end
end

# Prefer: Redirect and let the frame handle it
def destroy
  @item.destroy
  redirect_to items_path, notice: "Item deleted"
end
```

### ❌ Inline Turbo Stream Tags

Avoid inline stream tags in non-stream responses:

```erb
<%# Avoid: Mixing frames and streams confusingly %>
<%= turbo_frame_tag "content" do %>
  <%= turbo_stream.remove "something" %>
<% end %>
```

### ❌ Breaking Frame Expectations

If a frame exists, its content should always come from a matching frame in the response:

```erb
<%# Page has: %>
<%= turbo_frame_tag "item_detail" do %>

<%# Response MUST include: %>
<%= turbo_frame_tag "item_detail" do %>
```

### ❌ Complex Stimulus for Turbo Tasks

If something can be done with Turbo Frames/Streams, don't use Stimulus for DOM manipulation:

```javascript
// Avoid: Stimulus doing what Turbo should do
async updateList() {
  const response = await fetch('/items');
  this.listTarget.innerHTML = await response.text();
}

// Prefer: Link/form with data-turbo-frame
```

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-01-XX | — | Initial draft |
| 2025-01-XX | — | Added CardFlipController for double-faced cards, additional frame naming examples |
