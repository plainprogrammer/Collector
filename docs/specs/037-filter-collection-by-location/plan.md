# Plan: Spec 037, Filter the Collection by Location

**Spec:** [spec.md](spec.md) 0.2.2 (approved 2026-11-03 at 0.2.0; 0.2.1 and 0.2.2 are wording corrections from planning and its review, confirmed at the plan gate)
**Issue:** [#47](https://github.com/plainprogrammer/Collector/issues/47). The PR for this plan says "Refs #47"; the implementation PR closes it.
**Method:** tests first in every task (red, then green); the code blocks are drafts, not pre-run (memory: `sdd-execute-exact-plans`, `plan-reviews-run-the-code`). One subagent per phase, Opus; a deviation is recorded as a ruling in the commit body. No phase touches the export format (decision 8).

## What exists today (read before changing)

- `CollectionFilter` (module, `app/models/collection_filter.rb`) holds `self.normalize`, `self.lots(account, query)`, `filtered?`, `places?` (`@account.locations.exists?`, memoised), counts and `matching_lots`. `CollectionGrid.new(account:, query:, page:)` and `CollectionTable.new(account:, query:, page:, sort:)` include it.
- `CollectionGrid#tiles` already sums `matching_lots` per printing and collects finishes from them, so a narrower `matching_lots` gives decision 3's quantities and badges with no tile code. Only `places_of` must be skipped under a location filter.
- `BulkSelection` stores `query`, `sort_key`, `all_matching`; `context?(query, sort)`, `restart!(query:, sort:)`, `lots` and `record!` use `CollectionFilter.lots(account, query)`.
- `q` is carried in: `CollectionsController#show`, `CollectionListing#prepare_collection(_at)`, `CollectionsHelper#collection_listing_path` and `#sort_header`, `Collections::SelectionsController` (`create`, `update`, `done`, `act`, `navigate`, `destination`), `BulkSelected#set_selection`, `BulkRemoval.remove!` (`restart!`), `CollectionTable::SelectionState`, and the views `show`, `_filter_bar`, `_view_forms`, `_bulk`, `_bulk_pager`. `Collections::BulkRemovals::UndosController` re-renders through `prepare_collection_at(return_path)`.
- `_table.html.erb`'s Edit copy and Remove links return to `@listing_path` (`request.fullpath`), so they carry `location` with no change.

## Design

**One value, one canonical string.** `CollectionFilter::Place` is the only place that reads a raw `location` (decision 1):

```ruby
# app/models/collection_filter/place.rb
# The collection's location filter as one canonical string: "" (all), "none" (unplaced lots) or a location's id in
# decimal digits (spec 037 decision 1). Stored and compared as this string; never re-resolved to "all" for a stored
# selection or a submitted form (decision 7).
module CollectionFilter::Place
  NONE = "none".freeze
  ID = /\A[1-9]\d{0,17}\z/ # 18 digits: a longer id would overflow SQLite's 64-bit bind (spec 0.2.2)

  # Anything that isn't "none" or such an id (a non-string, "017", " 17", "17abc") is "".
  def self.parse(raw) = raw.is_a?(String) && (raw == NONE || raw.match?(ID)) ? raw : ""

  # A plain predicate on the lots' own column: another account's or a removed id matches no lot of this account's.
  def self.apply(scope, place)
    case place
    when "" then scope
    when NONE then scope.where(location_id: nil)
    else scope.where(location_id: place.to_i)
    end
  end
end
```

**Names.** `CollectionGrid::Place` (the tile's `Data` struct) shadows `CollectionFilter::Place` inside `CollectionGrid`: write `CollectionFilter::Place` in full there. `CollectionFilter`'s header comment ("Includers set @account and @query") adds `@requested_location`. A crafted Edit many `location=none` from an account with no locations is stored as given, mismatches the page's resolved "" and restarts under "" at the next submit: harmless and consistent with decision 7.

**Display resolves, storage doesn't.** The listing (`CollectionFilter`) resolves the URL's value against the account's locations for what it *shows and queries* (`location`); a `BulkSelection` keeps the canonical string it was given and applies `Place.apply` directly, so a removed id fails closed.

```ruby
# app/models/collection_filter.rb (changes)
def self.lots(account, query, place = "")
  scope = account.lots.joins(:entry)
  scope = scope.merge(Catalog::Entry.named_like(query)) if query.present?
  Place.apply(scope, place)
end

attr_reader :query

# One read of the account's locations in name order: the select's options, "does the account have one" and the chosen name.
def locations = @locations ||= @account.locations.ordered.to_a
def places? = locations.any?

# The filter as the page shows and queries it: "" unless the account has a location and the value names one of its own.
def location = @location ||= resolved_place
def chosen_location = (locations.find { it.id.to_s == location } unless location.in?([ "", Place::NONE ]))
def filtered? = query.present? || location.present?

private
  def resolved_place
    return "" unless places?

    @requested_location == Place::NONE || locations.any? { it.id.to_s == @requested_location } ? @requested_location : ""
  end
  def matching_lots = CollectionFilter.lots(@account, query, location)
```

`CollectionGrid.new(account:, query:, location: "", page:)` and `CollectionTable.new(account:, query:, location: "", page:, sort:)` set `@requested_location = CollectionFilter::Place.parse(location)`. `CollectionGrid#places_of` returns `{}` when `location.present?` (the place line is dropped, decision 3).

**Migration.** `bulk_selections.location_filter`, a string, `default: ""`, `null: false`. Reversible; no data backfill (the default is "all", what every existing row means); no model reference.

## Phase 1: model layer (no controller or view)

Tests first (red), then code.

| Test file | Examples |
|---|---|
| `spec/models/collection_filter/place_spec.rb` (new) | `parse`: `""`, `nil`, `"none"`, `"17"` stay or become `""`; `"017"`, `" 17"`, `"17abc"`, `"0"`, `"-3"`, `"NONE"`, a 19-digit id, an Array and a Hash become `""` (M1). `apply`: `""` returns the scope; `"none"` keeps only `location_id IS NULL`; an id keeps only that location's lots; a foreign or removed id returns none |
| `spec/models/collection_grid_spec.rb` (extend) | Under a place: a printing with 3 in Blue binder and 2 in Long box has one tile, quantity 3, no `place`, and its special finishes are the Blue binder lots' (a foil lot in Long box gives no foil) (AC-1.2); a printing with no copy there has no tile; `pagination` counts the filtered printings; `none` sums unplaced copies; a stale, foreign or non-numeric place resolves to `""`; an account with no location ignores a place; with a name filter and a place, both apply (AC-3.1); statements: the grid under a place runs no `places_of` statement and one `locations` read, and the count doesn't grow with tiles (NFR) |
| `spec/models/collection_table_spec.rb` (extend) | Rows are the matching lots; `matching_quantity` and `filtered?`; the place with the name filter; `chosen_location`; the locations read happens once |
| `spec/models/bulk_selection_spec.rb` (extend) | a row inserted with SQL that leaves out `location_filter` reads `""` and `context?("", sort)` is true; `context?` compares query, sort and location_filter; `restart!(…, location:)` stores it and clears marks; `lots` and `record!` are within the place (a shown id outside it is ignored, AC-5.2); **a stored id of a removed location, a foreign location's id and an id of no row all select no lot, also with `all_matching`** (decision 7, AC-5.5); `none` selects only unplaced lots |
| `spec/models/bulk_removal_spec.rb` (extend) | After `remove!` the selection is still under its location and query (`restart!` keeps them) |

Code:

- `db/migrate/<timestamp>_add_location_filter_to_bulk_selections.rb`: `add_column :bulk_selections, :location_filter, :string, default: "", null: false`. Run `bin/rails db:migrate`, then restore the cable/cache/queue schema noise (memory `migrate-schema-noise`), keeping only `bulk_selections` in `db/schema.rb`; `ruby script/upgrade/guard.rb` must stay green.
- `BulkSelection`:

```ruby
def context?(query, sort, location: "") = self.query == query && sort_key == sort.key && location_filter == location

def lots
  matching = CollectionFilter.lots(account, query, location_filter)
  all_matching? ? matching.where.not(id: marks.select(:lot_id)) : matching.where(id: marks.select(:lot_id))
end

def restart!(query:, sort:, location: "")
  transaction do
    marks.delete_all
    update!(query:, sort_key: sort.key, location_filter: location, all_matching: false)
  end
end
# record!: `shown = CollectionFilter.lots(account, query, location_filter).where(id: shown_ids).pluck(:id)`
```

- `BulkRemoval.remove!`: `selection.restart!(query: selection.query, sort: selection.sort, location: selection.location_filter)`.
- `CollectionFilter`, `Place`, `CollectionGrid`, `CollectionTable` as in Design. `CollectionTable::SelectionState` passes `location: table.location`: `selection&.context?(table.query, table.sort, location: table.location)`.
- Keep the defaulted `location:` keyword only in the model API; every controller call in Phase 2 passes it explicitly (a spec in Phase 2 proves each path).

Commit: `feat(collection): filter lots by location in the grid, table and bulk selection`.

## Phase 2: controllers and helpers

Tests first, in `spec/requests/collection_location_filter_spec.rb` (new, `type: :request`, `:aggregate_failures`) and the existing bulk request specs.

| Spec | Examples (AC) |
|---|---|
| show | `?location=<blue.id>` lists only Blue binder printings with Blue binder quantities (1.2); table view: only Blue binder rows (1.3); the count line "n of N items", the head's stats whole (1.4); `none` (2.1); name + location (3.1); an account with no location ignores `location=…` (6.1) |
| bad values | Another account's location id, a removed id, `abc`, `017`, `location[]=1`, `location[a]=1` and `location=` give 200 with the whole collection, no "of" in the count line, the unfiltered pager, and nothing of the other account's lots or location name in the body (1.7, 6.2); a request spec with **two accounts** proves it |
| bulk | `POST /collection/selection` (Edit many) with `location` redirects to the bulk path carrying it and stores it; `PATCH` with `go=filter`, `q`, `location` restarts under the new pair and carries it; `rendered_location` decides Next/sort/Remove/Done, not the select's `location` (M2); a page is kept only when both filters are unchanged; Select all then Remove removes only the place's lots (5.2); another account's id in `location` or `rendered_location` removes nothing (6.2); **AC-5.8**: a page under L, L deleted (a location with no lot), header ticked, Remove: 422 `NONE_LEFT`, nothing removed, for a matching and a non-matching `rendered_location` (the header tick is re-applied after a restart), and the refusal page shows All locations with `rendered_location=""` (L no longer resolves, decision 7; M2 of the plan review); a refusal for a location that still exists re-renders under it (controller-level: `@listing.location` and `@listing_path`; the select's markup is Phase 3); Undo of a removal redirects to the URL with `location`, and the Undo refusal re-renders under it (5.6); after a removal the stored selection is still under the location (no restart on the next submit) |

Phase 2 stops at the controllers, helpers and models: its examples assert redirects, `@listing` state and `collection_listing_path` values, and nothing that needs a view edit of Phase 3 (the links, the empty sentences, the select's markup, the bulk pager's `go=` URLs).

Code:

```ruby
# app/controllers/collections_controller.rb
prepare_collection(query: params[:q], location: params[:location], sort: …, page: params[:page], view: …, bulk:)

# app/controllers/concerns/collection_listing.rb
def prepare_collection(query:, location:, sort:, page:, view:, bulk:, path: request.fullpath)
  …
  CollectionTable.new(account: Current.account, query:, location:, page:, sort:)
  CollectionGrid.new(account: Current.account, query:, location:, page:)
end
# prepare_collection_at: location: values["location"]
```

```ruby
# app/helpers/collections_helper.rb
def collection_listing_path(query: nil, location: nil, sort: nil, page: nil, bulk: nil, view: nil)
  collection_path({ bulk:, view:, q: query.presence, location: location.presence, page: (page.to_i if page.to_i > 1) }.merge(sort&.to_params || {}).compact)
end
# sort_header: location: table.location

# The empty sentence of both modes (spec 037 AC-1.6, AC-2.2, AC-3.2; spec 004 AC-11.5 when there is no location filter).
def no_match_message(listing)
  query = listing.query
  case listing.location
  when "" then %(No cards in your collection match "#{query}".)
  when CollectionFilter::Place::NONE
    query.present? ? %(No cards in your collection match "#{query}" without a location.) : "No cards in your collection are without a location."
  else
    name = listing.chosen_location.name
    query.present? ? %(No cards in your collection match "#{query}" in “#{name}”.) : "No cards in your collection are in “#{name}”."
  end
end
```

```ruby
# app/controllers/collections/selections_controller.rb
def create
  query = CollectionFilter.normalize(params[:q])
  location = CollectionFilter::Place.parse(params[:location])
  sort = …
  BulkSelection.for(Current.session).restart!(query:, sort:, location:)
  redirect_to helpers.collection_listing_path(bulk: 1, query:, location:, sort:), status: :see_other
end

def update
  query = CollectionFilter.normalize(params[:rendered_q])
  location = CollectionFilter::Place.parse(params[:rendered_location]) # canonical, never re-resolved (decision 7)
  …
  selection.restart!(query:, sort:, location:) unless selection.context?(query, sort, location:)
  …act(selection, query, location, sort) / navigate(selection, *destination(query, location, sort))
end

def destination(query, location, sort)
  if params[:go] == "filter"
    filter = CollectionFilter.normalize(params[:q])
    place = CollectionFilter::Place.parse(params[:location])
    [ filter, place, sort, (params[:page] if filter == query && place == location) ]
  elsif (values = collection_values(params[:go]))
    [ CollectionFilter.normalize(values["q"]), CollectionFilter::Place.parse(values["location"]), CollectionTable::Sort.parse(values["sort"], values["dir"]), values["page"] ]
  else
    [ query, location, sort, params[:page] ]
  end
end
```

`done`, `act` (its `prepare_collection_at(collection_listing_path(…, location:))`) and `navigate` take and pass `location`. `BulkSelected#set_selection`: add `location: @selection&.location_filter` to `@bulk_path`. `UndosController` needs no change (`prepare_collection_at(return_path)` reads `location` from the URL it carries); a request example proves it.

Commit: `feat(collection): carry the location filter through the collection page, bulk mode and their redirects`.

## Phase 3: views, design system, system spec

Tests first: request examples for the markup (below) and `spec/system/collection_location_filter_spec.rb` (new, `type: :system`, headless Firefox, no `sleep`).

| Spec | Examples (AC) |
|---|---|
| links (moved from Phase 2) | The paging links, sort headers, the `view-switch` and `edit-many` forms' hidden fields carry `location` (and omit it for all); the filter bar's GET form submits `q`, the sort fields and `location` together and the select has no `form` attribute there (3.3); Edit copy / Remove menu links' `return_to` carries it (4.1); a page naming a view and a location saves the view, not the location (4.2); the card page is unchanged (4.3); the bulk pager's and sort headers' `go=` URLs carry it (5.6) |
| empty sentences | The three sentences of `no_match_message` in the grid, the table and the bulk table: "No cards in your collection are in “Blue binder”.", "…are without a location.", `…match "q" in “Blue binder”.`, `…match "q" without a location.`, and spec 004's for the name filter alone (1.6, 2.2, 3.2); bulk under a matching-nothing location: "0 of 0 selected", no header checkbox, the sentence (5.4); the bulk count "0 of <matching> selected" and the bulk select showing the choice after Edit many (5.1); a refusal re-render (422) under an existing location shows the select and the sentence (5.6) |
| request, markup | The select is `select[name=location]` with `All locations`, `No location`, then the locations in `Location.ordered` order, the right option selected, label text "Location", inside `.c-filterbar__filters` with a "Filter" submit after it (1.1, 1.5, 6.3); no select with no location, both modes (6.1); `rendered_location` hidden field in the bulk form; the bulk default submit (`go=filter`) is first in tree order of the bulk form's submit buttons and is visible when the account has a location, `c-sr` otherwise (decision 6); an option and the empty sentence escape `<b>&"` (6.6); a long name is in one option; the AC-5.8 refusal page's select shows All locations |
| system | Grid: choose Blue binder, press Filter, see only its tiles and "n of N items"; pick All locations and place lines return (1.7); Table view keeps the filter across sort and page; bulk: Edit many keeps the filter, Select all then Remove under a location removes only those lots and Undo restores; changing the select without Filter and pressing Next uses the rendered location (5.3); Enter in the name field applies the name and the location (6.3); a 390px-wide frame shows the select and button in the filter group with no horizontal scroll (6.5; headless Firefox can't go below 500px, use the fixed-width iframe, memory `headless-firefox-narrow-frame`) |

Code:

- `app/views/collections/_location_select.html.erb` (`locals: (listing:, form: nil)`): `<label class="c-select"><span class="c-sr">Location</span><%= select_tag :location, options_for_select([ [ "All locations", "" ], [ "No location", "none" ], *listing.locations.map { |l| [ l.name, l.id.to_s ] } ], listing.location), form:, id: nil %></label>`.
- `_filter_bar.html.erb`: when `listing.places?`, a `.c-filterbar__filters` div with the partial and `form.submit "Filter", name: nil, class: "c-btn c-btn--secondary c-btn--sm"`, after the search label.
- `_bulk.html.erb`: when `table.places?`, `.c-filterbar__filters` holding the partial with `form: "bulk"` and the existing `go=filter` button made visible (`c-btn c-btn--secondary c-btn--sm`, no `tabindex`); otherwise the hidden `c-sr` button as now. Add `hidden_field_tag :rendered_location, table.location, id: nil` beside `rendered_q`. `_bulk_pager` passes `location: table.location`. The empty sentence uses `no_match_message(table)`.
- `show.html.erb`: the empty sentence uses `no_match_message(@listing)`; both `link_params` gain `location: @listing.location.presence`.
- `_view_forms.html.erb`: both forms add `<% if listing.location.present? %><%= hidden_field_tag :location, listing.location, id: nil %><% end %>`.
- CSS: none expected (FilterSelect's `.c-select` exists, `additions.css:97`). If the bulk bar's layout needs a rule, add it to `collector/additions.css` and note it in `docs/design-system/components/FilterSelect.md` (use the `collector-design-system` skill; read `docs/design-system/README.md` first).
- `docs/design-system/components/FilterSelect.md`: one line that the collection page uses it, in both modes.

Commit: `feat(collection): a Location select in the filter bar`.

## Phase 4: measurement, documents and verification

1. Measure (spec NFR): the collection page's server time for 5,000 lots over 300 locations, with a location filter on and with `location=none`, with lots of **several accounts** in the table, grid and table, against 500 ms, the way spec 033's `verification.md` AC-3.3 recorded it. If a measurement misses the budget, add a migration for `[account_id, location_id]` on `lots` and measure again; otherwise record that the index was not needed. Record the statement counts (grid and table) in `verification.md`.
2. `verification.md` in this folder, with an `## Implementation review` heading whose first line is the review's verdict (`.claude/rules/documentation.md`): per-AC evidence (spec, example, or a reading), the statement counts, the measurements, the manual checks (phone width, keyboard, Firefox).
3. Documents (same PR, `.claude/rules/documentation.md`): `docs/architecture/collection-and-lots.md` (the collection page: the filter, counts, tiles under it, bulk context; remove the "no filter by location" half of the #47 line in "Not yet"; add this spec and #47 to Sources), `docs/specs/README.md` (status, plan row, supersession columns already in), `docs/roadmap.md` item 12, the root `CLAUDE.md`'s locations paragraph ("the collection's grid tiles and table rows show it (spec 033)": add "and filter by it (spec 037)"); the area doc's Selection bullets (the "Selection" term and bulk mode's selection paragraph) gain the location in the context and the fail-closed rule, each with its source. `distill-feature` runs at the end.
4. `bin/ci` (migration guard, RuboCop, Brakeman, specs). Brakeman: `params[:location]` is only read as a string through `Place.parse` and bound as a parameter; no ignore is needed.

Commit: `docs(spec-037): verification, area doc and roadmap`.

## Spec to test map

| Criteria | Where |
|---|---|
| AC-1.1–1.7, 2.1–2.2, 3.1–3.3 | Phase 2 show requests (1.2–1.4, 2.1, 3.1); Phase 3 markup, empty sentences, links and system (1.1, 1.5–1.7, 2.2, 3.2, 3.3) |
| AC-4.1–4.3 | Phase 3 links |
| AC-5.1–5.8 | Phase 1 `bulk_selection_spec`, `bulk_removal_spec`; Phase 2 bulk requests; Phase 3 system |
| AC-6.1–6.6 | Phase 2 bad values; Phase 3 markup and system |
| FR-1–FR-5 | `place_spec`, `collection_grid_spec`, `bulk_selection_spec`; request examples |
| NFR performance, tenancy | Phase 1 statement-count examples; Phase 2 two-account examples; Phase 4 measurement |

## Risks and what only a run can confirm

- The `Place` constant's autoload under `CollectionFilter` (a module defined in `collection_filter.rb`, with the nested file in `collection_filter/`): run `bin/rails zeitwerk:check`.
- The bulk filter bar's layout with a visible Filter button, and that Enter in the name field still submits `go=filter` (the first submit button in tree order).
- Existing specs that call `restart!`, `context?` or `collection_listing_path` positionally keep working (defaults), and `spec/system/narrow_bulk_pages_spec.rb` and `bulk_mode_spec.rb` still pass with a visible Filter button only for an account with a location.
- SQLite's `IS NULL` plan on `index_lots_on_location_id` across accounts (Phase 4).
