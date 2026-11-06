# Verification: Spec 037, Filter the Collection by Location

**Spec:** [spec.md](spec.md) 0.2.2 · **Plan:** [plan.md](plan.md) · **Pull request:** [#174](https://github.com/plainprogrammer/Collector/pull/174) (closes [#47](https://github.com/plainprogrammer/Collector/issues/47))

## Evidence per criterion

Spec files: `spec/models/collection_filter/place_spec.rb` (place), `spec/models/collection_grid_spec.rb`, `spec/models/collection_table_spec.rb`, `spec/models/bulk_selection_spec.rb`, `spec/models/bulk_removal_spec.rb` (models, "under a location filter (spec 037)"), `spec/requests/collection_location_filter_spec.rb` (filter requests), `spec/requests/collection_location_select_spec.rb` (select markup), `spec/system/collection_location_filter_spec.rb` (system).

| Criterion | Evidence |
|---|---|
| AC-1.1 the select, its options and order, Filter after it | select markup "lists all, none, then the locations in the locations page's order, in the filter bar's GET form" |
| AC-1.2 a place's tiles, quantities, badges, no place line | grid model "sums only the place's copies and finishes and shows no place line"; filter request "shows only a place's printings …"; system "narrows the grid to a location and back to all" |
| AC-1.3 the table under a place | table model "lists the place's lots and counts their copies"; filter request "shows only the place's rows in the table"; system "keeps the filter across the table's sort and pages" |
| AC-1.4 counts and pager | filter request "shows only a place's printings …" (count line and head stats); grid model "leaves out printings with no copy there and pages the filtered printings" |
| AC-1.5 the chosen option selected | select markup "shows the chosen location, in both views" |
| AC-1.6 an empty location's sentence | select markup "names the location, none, and the query with either" (grid and table; no grid, table or pager) |
| AC-1.7 back to all | system "narrows the grid to a location and back to all" |
| AC-2.1 none | grid model "sums unplaced copies for none"; filter request "shows only unplaced lots for none" |
| AC-2.2 none, nothing unplaced | select markup "names the location, none, and the query with either" |
| AC-3.1 name AND location | grid model "joins the name filter with AND"; table model "joins the name filter"; filter request "joins the name filter" |
| AC-3.2 both match nothing | select markup "names the location, none, and the query with either" (both forms, and spec 004's sentence for the name alone) |
| AC-3.3 the GET form submits both | select markup (the select has no `form` attribute inside the GET form); system "applies the name and the location on Enter in the name field"; filter request "reads a non-string parameter as all" and `location=` in the bad-values example |
| AC-4.1 links keep it | select markup "carries the location in pagers, sort headers, the view switch, Edit many and row menus"; filter request "the links' URLs" |
| AC-4.2 the location isn't saved | filter request "does not save the location with the view" |
| AC-4.3 card page unchanged | select markup "keeps the card page listing every lot of the printing" |
| AC-5.1 Edit many under the filter | filter request "opens Edit many under the location and stores it"; select markup "joins the select to the bulk form, shows the choice …"; system bulk example |
| AC-5.2 Select all then act within the place | bulk selection model "selects and records only the place's lots"; bulk removal model; filter request "removes only the place's lots after Select all …"; system bulk example |
| AC-5.3 restart on Filter; rendered location for the rest | filter requests "restarts under the new filter pair on Filter", "keeps the page only when neither filter changed", "uses the rendered location for Next, a sort, Remove and Done …", "acts on nothing selected under another location …"; system "pages under the rendered location when the select changed without Filter" |
| AC-5.4 bulk under nothing matching | select markup "shows the sentence and 0 of 0 selected in bulk mode" |
| AC-5.5 a removed location selects nothing | bulk selection model "fails closed for a removed, foreign or unknown location, also with every matching lot"; filter request "a location removed in another tab" |
| AC-5.6 confirm pages, redirects, Undo, pagers, refusals | filter requests "returns Set condition to the bulk table under the location", "removes only the place's lots … keeps the location after", "re-renders a refusal under a location that still exists", "returns Undo to the URL with the location and re-renders its refusal under it"; select markup (bulk pager and sort `go=` URLs, refusal re-render with select and `rendered_location`); system bulk example (Undo) |
| AC-5.7 Done | filter request "uses the rendered location for Next, a sort, Remove and Done …" (Done redirects to the saved view with `q` and `location`) |
| AC-5.8 removed in another tab, header ticked, Remove | filter request "refuses with nothing removed whether or not the rendered location matches the selection" (both cases: 422, `NONE_LEFT`, nothing removed); select markup "shows all locations on the refusal for a removed location" |
| AC-6.1 no location, no select | select markup "is not shown while the account has no location, in either mode"; filter request "ignores the parameter while the account has no location"; grid model "ignores the place while the account has no location" |
| AC-6.2 values that name no location | filter requests "shows the whole collection, unfiltered, and nothing of the other account" (two accounts; another account's id, removed, `abc`, `017`, empty, `NONE`, a 19-digit id) and "reads a non-string parameter as all"; "removes nothing of another account's for its location id"; place model `parse` |
| AC-6.3 native select, accessible name, Filter, Enter | select markup (label "Location", Filter submit; bulk default `go=filter` first in tree order); system Enter example |
| AC-6.4 long names clipped, at most 220px | system "fits the select and its button in the filter group at 390px" (measures the select at most 220px with a long name); FilterSelect's `.c-select select { max-width:220px }` |
| AC-6.5 narrow screens | system "fits the select and its button in the filter group at 390px, in both modes" (390px frame, no horizontal scroll) |
| AC-6.6 escaping | select markup "escapes a location's name" (option and sentence) |
| FR-1 one value, canonical | `CollectionFilter::Place.parse` and `.apply`; place model; `CollectionFilter#location` resolves for display, `BulkSelection` applies the stored string |
| FR-2 one scope | `CollectionFilter.lots(account, query, place)` is used by the grid, the table, `BulkSelection#lots` and `#record!` |
| FR-3 URL and forms | `collection_listing_path(location:)` (left out for all), `_view_forms`, `_bulk` (`rendered_location`), `_bulk_pager`, both pagers' `link_params`; nothing saves it (AC-4.2) |
| FR-4 bulk selection | `bulk_selections.location_filter` (migration `20261106100001`, default `""`, null false; a row inserted without it reads `""`: bulk selection model "reads a row stored before the column as all locations"); `context?` and `restart!` take it |
| FR-5 wording, no new component | the empty sentences above; no CSS added; FilterSelect's doc gains the collection page |

## Measurements (NFR Performance)

`spec/requests/collection_location_filter_timing_spec.rb` (`:timing`, run with `SCANNER_TIMING=1`): 5,000 lots over 300 locations (a tenth unplaced, 1,500 printings) for the signed-in account, plus two other accounts with 5,000 lots each in the same `lots` table; full request through Rack, test environment, median of 5 after a warm-up, on the dev machine, 2026-11-06:

| Page | Median | Statements |
|---|---|---|
| grid, all locations | 32 ms | 13 |
| grid, one location | 21 ms | 12 |
| grid, `location=none` | 48 ms | 12 |
| table, all locations | 163 ms | 13 |
| table, one location | 37 ms | 13 |
| table, `location=none` | 106 ms | 12 |
| bulk, one location | 33 ms | 14 |

All under the 500 ms budget, so the `[account_id, location_id]` index the NFR held in reserve was not added. A location filter adds no statement: the grid under one runs one fewer (the grouped places read is skipped); the account's locations are read once per page (model examples "reads the locations once and skips the place statement, however many tiles" and "reads the account's locations once").

## Manual checks

To be filled from the screenshots and GIF taken for the pull request (desktop and 390px, light and dark).
