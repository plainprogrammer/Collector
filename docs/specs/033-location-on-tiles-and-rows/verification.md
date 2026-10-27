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
