# Error Handling & Edge Cases

## Overview

This document defines patterns for handling errors, edge cases, and exceptional states in Collector. Consistent error handling improves user experience and makes the application more robust.

**Philosophy**: Fail gracefully, inform clearly, recover when possible.

---

## Validation Errors

### Form Validation Pattern

Server-side validation is authoritative. Client-side validation (via Stimulus) provides immediate feedback but doesn't replace server checks.

#### Display Pattern

Validation errors appear:
1. Inline below the relevant field
2. Summarized at form top for screen readers

```erb
<%# FormFieldComponent handles inline errors %>
<%= render FormFieldComponent.new(attribute: :name, label: "Name") do |field| %>
  <%= form.text_field :name, class: field.input_classes %>
<% end %>

<%# Form-level summary for accessibility %>
<% if @item.errors.any? %>
  <div role="alert" class="text-red-600 mb-4">
    <p><%= pluralize(@item.errors.count, "error") %> prevented saving:</p>
    <ul class="list-disc list-inside">
      <% @item.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

#### Controller Pattern

Return `422 Unprocessable Entity` for validation failures:

```ruby
def create
  @item = Item.new(item_params)
  
  if @item.save
    redirect_to @item, notice: "Item created successfully"
  else
    render :new, status: :unprocessable_entity
  end
end
```

### Error Styling

| State | Border | Background | Text |
|-------|--------|------------|------|
| Default | `border-gray-300` | `bg-white` | `text-gray-900` |
| Error | `border-red-500` | `bg-red-50` | `text-red-900` |
| Error message | — | — | `text-red-600 text-sm` |

---

## Flash Messages

### Types

| Type | Use Case | Color | Icon |
|------|----------|-------|------|
| `notice` / `success` | Successful actions | Green | `check-circle` |
| `alert` / `error` | Failed actions, errors | Red | `exclamation-circle` |
| `warning` | Cautions, confirmations | Yellow | `exclamation-triangle` |
| `info` | Neutral information | Blue | `information-circle` |

### Display Pattern

Flash messages appear at the top of the content area, auto-dismiss after 5 seconds with manual dismiss option.

```erb
<%# FlashComponent interface %>
<%= render FlashComponent.new(type: :success, message: "Item added to collection") %>
```

### Controller Pattern

```ruby
# Standard Rails flash
redirect_to @item, notice: "Item created"

# With Turbo Stream for in-page updates
def create
  @item = Item.new(item_params)
  
  if @item.save
    respond_to do |format|
      format.html { redirect_to @item, notice: "Item created" }
      format.turbo_stream do
        flash.now[:notice] = "Item created"
        # Stream will include flash update
      end
    end
  end
end
```

---

## Empty States

Every list or container that can be empty needs an empty state.

### Empty State Interface

```ruby
# EmptyStateComponent parameters
EmptyStateComponent.new(
  title: "No items yet",
  description: "Add cards from the catalog to start your collection",
  icon: "rectangle-stack",
  action_label: "Browse Cards",
  action_href: cards_path
)
```

### Contextual Empty States

| Context | Title | Description | Action |
|---------|-------|-------------|--------|
| Collection items | "No items yet" | "Add cards from the catalog to start your collection" | "Browse Cards" |
| Search results | "No matches found" | "Try adjusting your search terms" | — |
| Storage unit contents | "This storage is empty" | "Move items here or add new cards" | "Add Items" |
| Filtered list | "No items match filters" | "Try adjusting or clearing filters" | "Clear Filters" |
| Set cards (loading) | "Loading cards..." | "Fetching card data from catalog" | — |

---

## Loading States

### Page Loading

Turbo Drive shows a progress bar automatically. No additional implementation needed.

### Frame Loading

When Turbo Frames load content, show a skeleton or spinner:

```erb
<%= turbo_frame_tag "set_details", src: set_path(@set), loading: :lazy do %>
  <%= render LoadingSkeletonComponent.new(type: :card_grid) %>
<% end %>
```

### Loading Skeleton Types

| Type | Use Case |
|------|----------|
| `:card_grid` | Card thumbnail grid placeholder |
| `:list` | Table/list rows placeholder |
| `:detail` | Detail view placeholder |
| `:text` | Text content placeholder |

### Button Loading State

Buttons show loading state during form submission:

```erb
<%= form.submit "Save", 
    data: { 
      turbo_submits_with: "Saving..." 
    } 
%>
```

---

## Image Handling

### Scryfall Image Loading

Card images load from Scryfall's CDN. Handle failures gracefully.

#### Fallback Chain

1. Primary: Scryfall CDN URL (`cards.scryfall.io`)
2. Fallback: Generic placeholder image
3. Alt text: Always present for accessibility

```erb
<%# Catalog::CardImageComponent handles fallback %>
<img 
  src="<%= card.image_url(:normal) %>"
  alt="<%= card.name %>"
  loading="lazy"
  onerror="this.src='/images/card-placeholder.png'"
  class="rounded-lg shadow"
>
```

#### Placeholder Image

A simple card-back or "image unavailable" placeholder stored locally:
- `/public/images/card-placeholder.png`
- Appropriate dimensions for card aspect ratio (488×680 or scaled)

### Double-Faced / Multi-Face Cards

Cards with multiple faces need special handling:

```ruby
# MTGCard should provide:
card.faces            # Array of face data
card.double_faced?    # Boolean
card.image_url(:normal, face: :front)
card.image_url(:normal, face: :back)
```

UI provides toggle/flip interaction via Stimulus controller (`card_flip_controller.js`).

---

## Catalog Adapter Errors

The Catalog adapter pattern abstracts data sources. Each adapter type has specific error scenarios.

### MTGJSONAdapter Errors

| Scenario | Handling |
|----------|----------|
| Import file not found | Log error, show admin notification, continue with existing data |
| Import file corrupted | Validate SHA-256 hash before import, reject if mismatch |
| Import interrupted | Transaction rollback, retry from start |
| Malformed card data | Skip record, log warning with card identifier, continue |
| Missing required field | Skip record, log warning, continue |
| Duplicate UUID | Update existing record (idempotent upsert) |
| Network failure during download | Retry with exponential backoff (3 attempts) |

### Future ApiAdapter Errors

| Scenario | Handling |
|----------|----------|
| API rate limit exceeded | Queue request, retry after cooldown |
| API authentication failure | Log error, notify admin, disable adapter temporarily |
| API response timeout | Retry with backoff, fall back to cached data |
| API schema change | Log warning, attempt graceful degradation |

### Adapter Error Pattern

```ruby
class CatalogAdapter
  class ImportError < StandardError; end
  class FetchError < StandardError; end
  class ValidationError < StandardError; end
  
  def bulk_import(options = {})
    # Implementation
  rescue StandardError => e
    Rails.logger.error("Catalog import failed: #{e.message}")
    raise ImportError, "Failed to import catalog data: #{e.message}"
  end
end
```

### User-Facing Messages

Adapter errors should not expose technical details to users:

| Internal Error | User Message |
|----------------|--------------|
| `ImportError` | "Card catalog is temporarily unavailable. Please try again later." |
| `FetchError` | "Unable to load card details. Please check your connection." |
| Network timeout | "Loading is taking longer than expected. Please wait or try again." |

---

## Not Found (404)

### Resource Not Found

When a specific resource doesn't exist:

```ruby
class ItemsController < ApplicationController
  def show
    @item = Item.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to items_path, alert: "Item not found"
  end
end
```

Or use `find_by` with explicit handling:

```ruby
def show
  @item = Item.find_by(id: params[:id])
  
  unless @item
    redirect_to items_path, alert: "Item not found"
    return
  end
end
```

### Global 404 Page

For routes that don't match:

```ruby
# app/controllers/errors_controller.rb
class ErrorsController < ApplicationController
  def not_found
    render status: :not_found
  end
end

# config/routes.rb
match "/404", to: "errors#not_found", via: :all
```

Custom 404 page with navigation back to safety.

---

## Server Errors (500)

### Error Page

Custom 500 page that:
- Apologizes for the error
- Provides navigation back to home
- Does NOT expose stack traces or sensitive info

```erb
<%# app/views/errors/internal_server_error.html.erb %>
<div class="text-center py-16">
  <h1 class="text-2xl font-bold">Something went wrong</h1>
  <p class="text-gray-600 mt-2">We've been notified and are looking into it.</p>
  <%= link_to "Back to Home", root_path, class: "btn mt-4" %>
</div>
```

### Error Logging

In production, errors should be logged with context. For MVP, Rails default logging is sufficient. Consider adding exception tracking (Sentry, Honeybadger) post-MVP.

---

## Edge Cases by Domain

### Catalog / Cards

| Scenario | Handling |
|----------|----------|
| Card with no image | Show placeholder |
| Card with missing oracle text | Show empty or "No text" |
| Card with no scryfall_id | Log warning, show placeholder image |
| Set with 0 cards (data issue) | Skip in set browser, log warning |
| Search returns 1000+ results | Paginate, show "showing first 50" message |
| Special characters in search | Sanitize input, escape for SQL |
| FTS5 query syntax error | Catch error, fall back to LIKE query |

### Items / Collection

| Scenario | Handling |
|----------|----------|
| Adding duplicate card | Allow (individual tracking), show "You own X copies" notice |
| Deleting item in storage | Remove from storage automatically |
| Invalid finish for card | Validation error, show valid options |
| Changing storage unit | Validate collection constraint, show error if invalid |
| Quantity set to 0 | Treat as deletion, confirm with user |
| Negative quantity | Validation error, must be >= 1 |

### Storage Units

| Scenario | Handling |
|----------|----------|
| Delete unit with items | Require reassignment or confirm orphaning |
| Delete unit with children | Require handling children first |
| Circular parent reference | Validation prevents, show error |
| Moving unit to own descendant | Validation prevents, show error |
| Deep nesting (10+ levels) | Allow but consider UX implications |
| Unit not associated with item's collection | Validation error on item save |

### MTGJSON Import

| Scenario | Handling |
|----------|----------|
| Import interrupted | Transaction rollback, retry from start |
| Malformed data | Skip record, log warning, continue |
| Missing required field | Skip record, log warning |
| Duplicate UUID | Update existing record (idempotent) |
| Network failure during download | Retry with exponential backoff |
| Version already imported | Skip import, log info |

---

## Constraint Violations

Database-level constraints provide a safety net. Handle gracefully:

```ruby
def create
  @item = Item.new(item_params)
  @item.save!
  redirect_to @item, notice: "Created"
rescue ActiveRecord::RecordNotUnique
  flash.now[:alert] = "This record already exists"
  render :new, status: :unprocessable_entity
rescue ActiveRecord::InvalidForeignKey
  flash.now[:alert] = "Referenced record no longer exists"
  render :new, status: :unprocessable_entity
end
```

---

## Form Recovery

### Preserving Input on Error

When validation fails, preserve user input:
- Rails form helpers do this automatically with `form_with model: @item`
- Ensure instance variable contains the attempted (invalid) values

### Browser Navigation

Turbo preserves form state on back navigation via snapshots. Test that:
- Back button restores form input
- Re-submitting doesn't cause duplicates (idempotency)

---

## Accessibility Considerations

### Error Announcements

- Use `role="alert"` for flash messages and form error summaries
- Screen readers announce alerts automatically
- Focus management: move focus to error summary on form error

### Error Identification

- Don't rely on color alone (add icons, text)
- Associate error messages with fields via `aria-describedby`
- Mark invalid fields with `aria-invalid="true"`

```erb
<input 
  type="text" 
  aria-invalid="<%= @item.errors[:name].any? %>"
  aria-describedby="name-error"
>
<span id="name-error" class="text-red-600">
  <%= @item.errors[:name].first %>
</span>
```

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-01-XX | — | Initial draft |
| 2025-01-XX | — | Added Catalog adapter error handling section, additional edge cases |
