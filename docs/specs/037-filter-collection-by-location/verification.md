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

Taken on 2026-11-06 with headless Firefox (Selenium) against this worktree's development server, seeded by a scratch script with one collector, three locations ("Blue binder", "Long box", "Red deck box") and 14 lots over 12 placeholder printings (no card art). Each image was inspected; the files are in [`screenshots/`](screenshots/).

- **Desktop, 1280px, light and dark:** the grid under Blue binder (5 tiles, "12 of 40 items", no place line, the foil badge only where the binder holds a foil), "No location" (4 tiles, "10 of 40 items"), the table under Blue binder (Location column repeats it), bulk mode under it (select and a visible Filter in the bulk filter bar, "0 of 12 selected"), after Remove ("No cards in your collection are in “Blue binder”.", "0 of 0 selected", Undo) and after Undo (the 12 items back, still under Blue binder). Dark mode keeps the select, the button and the count legible.
- **Phone, a 390px frame, light and dark:** grid and bulk mode under Blue binder. The select and Filter share a row under the search field, the view switch and "…" the next; the frame's `scrollWidth` equals its 390px width (no horizontal scroll), as the system spec also checks.
- **Walkthrough GIF:** grid, choose Blue binder, Filter; No location; back under Blue binder, switch to the table; Edit many; Select all ("All 12 items selected"); Remove; confirm; Undo.
- **Keyboard:** the select is a native control reached by Tab after the search field, with the design system's focus ring (`.c-select select:focus-visible`); Enter in the name field applies both filters (system spec).
- No UI bug was found in the shots.

## Implementation review

SPEC-ALIGNED. An independent read-only `sdd-review` Mode B on Opus, run 2026-11-06 on `0690b63`, found no blocking or major findings and five minor ones:

1. Showing a selection's ticks under a location (AC-5.3) had no direct example. **Fixed** in `afe0ce8`: `spec/models/collection_table/selection_state_spec.rb` "shows a selection under its location, and as nothing under another".
2. The confirm page's Cancel and Back links, and the confirm page for a selection whose location is gone (AC-5.5, AC-5.6), weren't asserted. **Fixed** in `afe0ce8`: select markup "keeps the location on the confirm page's Cancel and Back …" and "sends the confirm page for a selection whose location is gone back to the bulk table".
3. The filtered table's pager count (AC-1.4) was covered only indirectly. **Fixed** in `afe0ce8` (the same Cancel/Back example asserts "Page 1 of 2").
4. This file's manual checks and this heading were missing. **Fixed** here.
5. The working tree's `Gemfile.lock` carries the dev machine's arm64-darwin platform. **Kept out** of every commit, as the brief says.

The review also judged the three recorded deviations acceptable: the `_no_match` partial in place of the plan's helper (it escapes correctly without `html_safe`; the reviewer notes a helper's `&quot;` would display the same, so the gain is keeping spec 004's existing body assertions unchanged), the migration's `ALTER TABLE … DROP COLUMN` down (the bundled SQLite is newer than 3.35), and no new CSS. It traced tenancy (a foreign id in `location`, `rendered_location` or a `go=` URL never reaches another account's lots), the fail-closed rule (AC-5.5, AC-5.8; SQLite's AUTOINCREMENT keys mean a removed location's id isn't reused), which value bulk submissions use, the default submit order, and every caller of `restart!`, `context?`, `collection_listing_path`, `prepare_collection`, `CollectionGrid.new`, `CollectionTable.new` and `CollectionFilter.lots`. An example for a foreign id in a `go=` URL was optional and is not added; `spec/requests/collection_location_filter_spec.rb` "removes nothing of another account's for its location id" covers the same predicate through `location` and `rendered_location`.

Per-criterion evidence is the table at the top of this file.
