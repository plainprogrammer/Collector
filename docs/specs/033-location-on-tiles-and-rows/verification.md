# Verification: spec 033

Evidence for each criterion. Screenshots (`screenshots/`): grid and table at 1280px and 390px, light and dark, read one by one (a missing space in "Blue binder +1 more" was found and fixed from them; a long place widening the phone table past 360px was found by the system example and fixed). The printings have no card art in the test data, so tiles show the name fallback.

| Criterion | Evidence |
|-----------|----------|
| AC-1.1 one place | `spec/requests/collection_places_spec.rb` "names a printing's place under its name" |
| AC-1.2 most copies first, tie by key | `spec/models/collection_grid_spec.rb` "names the place with most copies…", "breaks a tie by comparison key…" |
| AC-1.3 unplaced counts as a place | same file, request spec "adds how many other places there are, counting unplaced" |
| AC-1.4 No location | model "puts unplaced after a named place on a tie…", "shows an unplaced printing…"; request "says No location…" |
| AC-1.5 none without locations | model "has no place and no places…"; request "shows no place line while the account has no location" |
| AC-1.6 escaped, one line, whole name in the link | request "escapes a name and keeps it in one element"; system "keeps a long place name to one line on a tile, and its +N more visible" |
| AC-1.7 tile otherwise unchanged | `spec/models/collection_grid_spec.rb` and `spec/requests/collections_spec.rb` unchanged and green |
| AC-1.8 all of the printing's places | model examples (the place read is by the page's printings, not by lot filter) |
| AC-2.1 Location column | request "has a Location column after Qty and before Paid"; "says No location in muted ink…" |
| AC-2.2 phone line, no sideways scroll | request "adds the place last to the line under the name…"; system "shows the place in the line under the name on a phone…" at 360px |
| AC-2.3 bulk mode | request "shows the same place in bulk mode"; spec 006's bulk examples unchanged and green |
| AC-2.4 none without locations | request "has no column and no place on the phone line without locations" |
| AC-2.5 not sortable | request "does not sort by location" |
| AC-2.6 rename, bulk keeps place | request "shows a renamed location's new name"; spec 032's bulk Set condition and Undo examples green |
| AC-3.1 tenant isolation | request examples "shows only the signed-in account's places" (grid and table) |
| AC-3.2 bounded queries | model "reads a bounded number of statements however many tiles", table "preloads the lots' locations…" |
| AC-3.3 5,000 lots over 300 locations | **Not measured.** The grid adds one grouped statement over `lots.catalog_entry_id` (indexed) for at most 120 printings, the table a preload of at most 120 locations. A measurement is owed if the maintainer wants one |
| AC-3.4 catalog tiles, signed out | request "shows no place on the catalog's tiles"; signed-out redirect unchanged (`spec/requests/collections_spec.rb`) |
| FR-6 core names no collectible | no `MTG` in the changed files (`grep -rn "MTG" app/models/collection_grid.rb app/views/collections app/helpers/lots_helper.rb` finds none) |

## Implementation review

SPEC-ALIGNED, with one deviation the maintainer accepted (rows wrap the place line, [#142](https://github.com/plainprogrammer/Collector/issues/142)) and the test gaps below. The review was an independent read-only `sdd-review` Mode B, run after the merge (2026-10-27) on `a3baf0d` (PR #140). It first returned DRIFT DETECTED on the deviation. The maintainer chose to keep the shipped behaviour and record it, so a later spec supersedes Decision 5 for rows.

**Deviation (Decision 5, rows).** Decision 5 keeps a place line, which the Terms define as on a tile or a row, to one line with an ellipsis. Tiles do. Rows don't:
- The phone line under the name wraps (`additions.css`, "Row place (spec 033)", commit 383926f) so a 60-character name fits 360px.
- The wide Location cell has no ellipsis, so a long name widens the column. A sideways scroll just above 640px is plausible but was not checked in a browser.

`CollectionTable.md` documents the wrap. Settling it is #142.

**Runs (2026-10-27):**
- Model and request specs (`collection_grid`, `collection_table`, `collection_places`, `collections`, `collection_views`, `bulk_condition`, `bulk_removal`, `lot/condition_change`, and the two core specs): 103 examples, 0 failures.
- `query_counts_spec.rb`: 10 examples, 0 failures.
- System specs (`collection_table`, `collection`, `collection_views`; headless Firefox), including both of spec 033's system examples: 13 examples, 0 failures.
- RuboCop on the changed Ruby: no offenses.

**AC-3.3, measured.** 5,000 lots over 300 locations (about 1,500 printings), full request through Rack, test environment, median of 5:
- grid: 57 ms
- table: 92 ms
- grid page 10: 42 ms

The budget is spec 004's 500 ms of server time. This replaces "Not measured" above. It was measured in the test environment, not in development as the NFR states.

**AC-3.2.** With places on, the grid, the table and the bulk table each run the same number of statements for 1 lot as for 115 printings over 50 locations. Places add a fixed 2 statements per page: the grid adds `locations.exists?` and the grouped read, the table adds `exists?` and the location preload. The NFR's "one statement to the grid; the table adds no statement" undercounts by FR-3's `exists?`. The bound holds.

**Test gaps (not blocking; listed in #142):**
- AC-1.8 has no example with a filter. It holds by construction: the places are read for the page's printings and all their lots.
- AC-1.6: the tile link's accessible name containing the whole "Name +N more" isn't asserted.
- AC-1.2's tie example can't tell ordering by comparison key from ordering by raw name.
- AC-2.6's bulk half is checked at the model level only.
- AC-1.7 rests on the grid's unchanged main query.
- FR-6 is checked by grep, with no `*_core_spec.rb` guard.
- `c-table__place` is a test hook with no CSS and no design-system mention.

**Rule checks:**
- No queries in views: holds (prepared `Data` values, preloaded `location`).
- Tenant scoping through the account: holds (AC-3.1 is tested on the grid and the table).
- Escaping: no `html_safe` or `raw`.
- SQL: constant `Arel.sql`, bound ids.
- CSS: tokens and `c-*` classes only, the addition documented.
