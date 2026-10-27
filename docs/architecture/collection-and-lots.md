# Collection and lots

What a collector owns and where it is kept: lots and their identity, the ways copies are added, edited, moved and removed, the collection's grid and table, bulk mode, number entry, and locations. This is the current truth; the specs it distils record what each feature promised when it shipped (see Sources and the [specs index](../specs/README.md)). How each page looks is the [design system](../design-system/README.md)'s; this doc names the patterns and does not restate them.

## Scope

**Covers:**

- The lot: `Lot`, its identity and key, merging and the 9,999 cap, and a lot's place (spec 004 FR-6; spec 032 decisions 1, 2; ADRs 0019, 0025).
- Adding, editing and removing one lot: quick add (`Catalog::QuickAddsController`), "Add a copy", "Edit copy" and "Remove" (`LotsController`, `Lots::RemovalsController`, `Lot::Form`) (spec 004 Stories 7, 9, 10; spec 032 Stories 1, 2).
- Moving copies: `Lot::Move`, `Lots::MovesController` (spec 032 Story 3, decision 4).
- What the card page and search say about the collector's copies: owned quantities on tiles, the "Not owned" marker, the card page's stats, "Your copies" and the owned counts of "Printings", and the `from=collection` mark (`Catalog::CardOverview`, `CardContext`) (spec 004 AC-6.3, AC-6.6, AC-8.4–AC-8.7, AC-8.9; spec 021; spec 032 Story 4).
- The collection page: the grid and the table, the name filter, the counts, the saved view and the sort (`CollectionsController`, `CollectionListing`, `CollectionGrid`, `CollectionTable`, `CollectionFilter`, `CollectionTable::Sort`) (spec 004 Story 11; spec 006 Stories 1–3; spec 033).
- Bulk mode: the selection, Set condition, the bulk removal and its Undo (`BulkSelection`, `Collections::SelectionsController`, `Lot::ConditionChange`, `BulkRemoval`) (spec 006 Stories 4–8; spec 032 Story 7).
- Number entry: `NumberEntry`, `NumberEntry::Line`, `NumberEntry::LineForm`, `NumberEntry::SetChoice`, `/collection/number_entry` (spec 026, all but the list being left out of the export; spec 034).
- Locations: `Location`, `Location::Name`, `Location::Holdings`, `/locations` (`LocationsController`, `Locations::RemovalsController`) (spec 029, all but its format, export, preview and apply parts; spec 032 Stories 4, 5).
- Tenant isolation for all of these (spec 004 AC-12.1–AC-12.3, AC-12.5; spec 006 Story 8; spec 029 Story 4; spec 032 Story 6). That every collection table carries `account_id` with a foreign key and an index (spec 004 AC-12.4) is tenancy and accounts'.

**Neighbours:**

- How lots and locations leave and enter an instance (the export, format version 3, the import preview and the apply), and that the number-entry list, the scanner sitting, bulk selections and bulk removals' undo are working state left out of the export and cleared by an apply that writes a lot: **[data portability](data-portability.md)**. This doc uses only that an apply replaces lots and locations in one transaction and keeps the lot identity and the location rules stated here.
- Catalog entries, sets, search, the card page's catalog content (details, legality, the printings list's catalog rows) and each collectible's vocabulary (`Catalog.collecting_for`: finishes, `finish_order`, special finishes, conditions): **catalog core** (no area doc yet). This doc uses the vocabulary as given.
- The scanner's sitting adds copies through `Lot.add!`, unplaced, and has its own Undo (spec 009; a place for a sitting is #56): **scanner** (no area doc yet).
- `Current.account`, users, sessions, sign-up, the admin users page (which shows each account's copy count) and deleting a user with their account: **tenancy and accounts** (no area doc yet). This doc uses that every collection query goes through `Current.account` and that a session ending discards its bulk selection and Undo.
- The patterns these pages are built from (`ItemTile`, `TileAdd`, `UnownedTile`, `CollectionPage`, `CollectionTable`, `ViewSwitchForm`, `SortHeader`, `BulkForm`, `BulkConfirmPage`, `ChoicePage`, `StatusAction`, `ItemPage`, `NumberEntry`, `Locations`): **[design system](../design-system/README.md)**.

## Glossary

- **Printing / entry:** one catalog entry: one set, number and language (`Catalog::Entry`). **Card:** the gameplay identity its printings share (`Catalog::Identity`) (spec 004 Users and Context).
- **Copy / item:** one physical card; the counts on the collection page count copies and call them items (spec 004 AC-11.1; spec 006 Users and Context).
- **Lot:** copies of one printing with the same finish, condition, price paid and place, owned by one account, with a quantity of 1 to 9,999 (spec 004 FR-6; spec 032 decision 1; ADRs 0019, 0025).
- **Identity:** those five values; unspecified equals unspecified. Its text form is `lots.lot_key` (spec 004 FR-6, AC-12.5; spec 032 FR-1).
- **Location:** a named place an account keeps part of its collection in; it has a name and nothing else (spec 029 decision 4).
- **Place / unplaced:** a lot's location, or none. An unplaced lot reads "No location" on screen and `null` in a file (spec 032 Terms, decision 2).
- **Name / comparison key:** a location's name after normalisation, and its Unicode full case folding, which is unique per account (spec 029 decision 5).
- **Merge:** copies that reach an identity a lot already has join that lot instead of making a second (spec 004 AC-7.4, AC-9.3, AC-10.2).
- **Quick add:** one copy of a printing, from a tile or a printings row, with finish, condition, price paid and place unspecified (spec 004 Story 7).
- **Tile:** one grid cell, one owned printing summing its lots. **Row:** one table row, one lot. **Place line:** the text a tile or row shows for its places (spec 033 Terms).
- **Saved view:** the collector's choice of grid or table (`users.collection_view`) (spec 006 FR-1).
- **Bulk mode:** the table with checkboxes and the bulk bar, entered with `Edit many` and left with `Done` (spec 006 Story 4).
- **Selection:** the lots ticked in bulk mode, stored per session under one filter and sort; **every matching lot** is a state of its own, with exceptions (spec 006 FR-4).
- **Undo record:** what a bulk removal keeps so it can be undone once (spec 006 FR-6).
- **Number entry / list / line / line key:** the "Add by number" page; the account's added lines until Done; one submitted number, quantity, finish and place; the random token that makes a line add at most once (spec 026 Terms, decision 10).
- **Holdings:** what an account's lots hold in one location: lots and copies (spec 032 P1, P2).
- **Collection mark:** `from=collection` on a card page URL, which makes its breadcrumb and current section Collection (spec 004 AC-8.9).

## Invariants

- **An account never holds two lots of one identity.** The identity is the printing, finish, condition, price paid and place; the unique index on `lots (account_id, catalog_entry_id, lot_key)` backs it in the database (spec 004 FR-6, AC-12.5; spec 032 decision 1; ADR 0025).
- **The key ends in the place's id, not its name.** `lot_key` is `finish|condition|price_paid_cents`, and for a placed lot `|location_id` after it, so an unplaced lot's key is what it was before locations and renaming a location keeps every key (spec 032 decision 2, FR-1; ADR 0025). Four places build a key and all carry the place: `Lot.key_for`, the SQL in `Lot::ConditionChange#update_alone!`, `BulkRemoval#identity` with its `insert_all`, and the apply's attribute builder for `upsert_lots!` (spec 032 Notes for the plan; [data portability](data-portability.md)). Rolling back spec 032's migration is refused while any lot is placed (spec 032 NFR Reliability; ADR 0025).
- **A lot holds 1 to 9,999 copies,** in the model and in the `lots_quantity_range` check constraint. The cap is per lot, so per place (spec 004 FR-6; spec 032 decision 1, AC-1.5).
- **Every way of adding or changing lots merges into the identity and keeps the cap, all or nothing:** `Lot.add!` (quick add, "Add a copy", number entry, the scanner, a merging Undo), `Lot#revise!` (an edit; the other lot survives), `Lot::Move`, `Lot::ConditionChange` and `BulkRemoval#undo!`. A change that would pass 9,999 changes nothing (spec 004 AC-7.3a, AC-9.3, AC-10.2; spec 006 AC-6.4, AC-7.5; spec 032 AC-1.5, AC-2.4, AC-3.6, FR-1). `Lot.add!` retries once after losing a race on the unique index, so a race merges instead of failing (spec 004 AC-12.5).
- **A lot is in one of its account's locations or in none, never another account's.** `Lot` validates a new place against its account; the forms and Move look the location up through `Current.account` and answer 404 for any other id; number entry shows a field error instead, because it is a form the collector returns to (spec 032 decision 6, AC-1.7, AC-2.7, AC-3.9; spec 034 decision 5, NFR Security).
- **No lot is ever in a missing location.** A location that holds a lot can't be removed: the controller refuses it and the foreign key from `lots.location_id` is `on_delete: :restrict` (spec 032 decision 3, AC-5.4, AC-5.5; ADR 0025). Removing an empty location changes no lot (spec 029 decision 3, AC-3.4). Deleting an account deletes its lots before its locations; that depends on the order of `Account`'s `has_many` declarations, which `spec/models/account_spec.rb` guards (spec 032 AC-6.6).
- **Only some ways of adding choose a place.** "Add a copy", "Edit copy", Move copies and number entry (spec 034) do; quick add, the scanner and the bulk actions add or keep copies unplaced (or keep each lot's place), and merge into the unplaced lot of their identity (spec 032 decision 5, AC-7.2; spec 034).
- **Location names follow one definition,** `Location::Name`: NFC, White_Space trimmed and collapsed to one U+0020, Cc and Cf refused, 1 to 60 code points; the comparison key is unique per account in the model and in the unique index on `locations (account_id, name_key)`; check constraints bound the name's length. `spec/models/location/name_parity_spec.rb` proves the model, the schema and the format document agree for every scalar value (spec 029 decisions 5, 9, AC-7.8).
- **An account has at most 500 locations,** and the cap holds under racing adds because write transactions serialise (spec 029 decision 7, AC-1.13).
- **Everything is scoped to `Current.account`.** Another account's lot, location or number-entry line answers 404, unchanged (spec 004 AC-12.2; spec 026 AC-3.8; spec 029 AC-4.1; spec 032 AC-6.1); lot ids in a bulk submission that aren't the account's are ignored, not answered with 404 (spec 006 AC-8.1); an Undo of another session's removal is 404 (spec 006 AC-8.3). No form takes an account, user or admin value (spec 004 AC-12.3; spec 006 AC-8.4; spec 029 AC-4.3).
- **The operator sees no collection detail.** No admin page shows a location, its name, a lot's place or a per-location count (hosted-door rule 2; spec 029 AC-4.5; spec 032 AC-6.4); the admin users page's per-account copy count is tenancy and accounts'.
- **A catalog refresh never changes a lot, a selection or an undo record,** and lots of retired printings are kept, shown, restored and can be quick-added (spec 004 FR-6, AC-11.9, Error Scenarios; spec 006 AC-2.7, AC-7.7, NFR Reliability).
- **The core names no collectible.** Finishes, the finish order, special finishes and conditions come from the vocabulary; the core stores finish and condition as values it doesn't interpret (spec 004 FR-6; spec 006 FR-2; spec 026 FR-1; spec 029 FR-2; spec 033 FR-6). `spec/number_entry_core_spec.rb` checks number entry's files and `spec/import_apply_core_spec.rb` the location and Move copies files; no core guard lists `Lot`, `LotsController`, `Lot::Form`, `Lot::ConditionChange`, `BulkRemoval`, `BulkSelection`, `CollectionTable::Sort`, the collection views or spec 033's files (#142 names the last).
- **Lists cost a bounded number of queries,** independent of tiles, rows, lots or locations: places add two statements to the grid (`locations.exists?` and the grouped read) and two to the table (`exists?` and the location preload), the locations page two grouped statements for its counts, a number-entry add a fixed number (spec 004 NFR; spec 006 NFR; spec 026 NFR; spec 029 NFR; spec 032 NFR; spec 033 AC-3.2, FR-2, whose `verification.md` records the two statements against the NFR's "one").
- **Every page works without scripting;** scripting only enhances (in-place quick add, the live selection count, the header's mixed state, Esc for `Done`, "/" to search) (spec 004 FR-12; spec 006 NFR; spec 026 Story 5; spec 029 AC-1.12; spec 032 AC-3.12).
- **No request marked as a prefetch changes state:** not the saved view, a selection or an Undo record; `Edit many` and `Done` are buttons, never links (spec 006 FR-1, AC-1.10, AC-4.1).
- **Price paid is stored exactly in cents** and shown in the one instance currency, `COLLECTOR_CURRENCY` (default USD), one of the 20 codes `Collector::Currency::SYMBOLS` knows; any other code stops the app at boot, and changing it converts nothing (spec 004 FR-6; `lib/collector/currency.rb`; #64).
- **An import apply that writes a lot ends the working state that points at lots:** it deletes the account's bulk selections, supersedes every undoable bulk removal of any session, and destroys the number-entry list (and the scanner sitting) (`CollectionImport::WorkingState`; spec 028 decision 7; spec 029 decision 11; [data portability](data-portability.md)).

## States and transitions

### A lot

| What | Does | Notice | Source |
|---|---|---|---|
| Quick add (tile, printings row, card page's Printings) | One unplaced copy, nothing else specified, merged by `Lot.add!`. With scripting, the tile updates in place; without, 303 to the carried return path if it is on this instance, else the card page. At the cap: 422, "You already have the most copies one lot can hold (9,999)." | "Added 1 × <name> (<SET> · <number>) to your collection." | spec 004 AC-7.1–AC-7.6 |
| "Add a copy" (`POST /catalog/entries/:key/lots`) | Quantity (required, 1–9,999), finish (the printing's; not offered when it lists none), condition (the vocabulary's), price paid (non-negative, two places at most), and Location when the account has one; merges; 303 to the card page | "Added <n> × <name> (<SET> · <number>) to <location>." or "…to your collection." | spec 004 AC-9.1–AC-9.4; spec 032 AC-1.1–AC-1.9 |
| "Edit copy" (`PATCH /lots/:id`) | `Lot#revise!`: a change that reaches another lot's identity merges, and the other lot survives with the summed quantity. A request without `lot[location_id]` keeps the place; a blank one is "No location" (plan-level ruling O3, recorded in spec 032's `verification.md`). Returns to the table it came from (with its filter, sort and page), the scanner, or the card page | "Saved." | spec 004 AC-10.1–AC-10.3; spec 006 AC-2.6; spec 032 AC-2.1–AC-2.8 |
| "Remove" (`/lots/:id/removal/new`, then `DELETE`) | A confirmation page first, which works without scripting; removing a lot ends the session's chance to undo an earlier bulk removal | "Removed <n> × <name> (<SET> · <number>) from your collection." | spec 004 AC-10.4, AC-10.5; spec 006 AC-1.7, AC-7.6; spec 032 AC-7.7 |
| Move copies (`/lots/:id/move/new`, `POST`) | Below | "Moved <n> × <name> (<SET> · <number>) to <location>." or "…to no location." | spec 032 Story 3 |

The Location field shows on the add and edit forms only while the account has a location; otherwise the forms show "Add a location to keep copies in one." linking to `/locations` (spec 032 P3). A location removed between showing a form and submitting it answers 404, or 409 for the removal, never 500 (spec 032 AC-6.7).

### Moving copies (`Lot::Move`)

The page asks for Copies (1 to the lot's quantity, set to it) and To ("No location", unless the lot is unplaced, then the account's other locations in name order). The card page's lot menu offers it; the table's menu doesn't (spec 032 AC-3.1). Inside one write transaction the lot is read again and the move is judged against it, so a second submit of a stale form can't create or lose copies (spec 032 plan review round 2, Major 1, recorded as "M1 (round 2)" in its `verification.md`):

| Copies | The destination has the identity | Result | Times |
|---|---|---|---|
| All | No | The same lot (same id) changes place | added kept, changed is the move's |
| All | Yes | The destination's lot gains them and survives; the moved lot is removed | the destination's added kept |
| Some | No | The lot keeps the rest; a new lot of the same identity holds the moved copies in the destination | the new lot's added and changed are the move's |
| Some | Yes | The lot keeps the rest; the destination's lot gains the moved copies | |

Refusals, 422 and nothing changed: Copies outside 1 to the quantity, "Choose from 1 to <quantity> copies."; the lot's own place, "Those copies are already there."; the cap, "One lot can hold at most 9,999 copies." An unplaced lot in an account with no locations gets "You have no locations yet." with a link and no Move button (spec 032 AC-3.2–AC-3.11, P3, P4, P6).

### A location

| From | Action | Result |
|---|---|---|
| none | `POST /locations` from the locations page's one-field form | 303 to `/locations`, "Added “<name>”." Refused with 422 and the typed text kept: "Give the location a name.", "Names can be at most 60 characters.", "Names can't contain control characters.", "You already have a location called “<name>”.", "You can have at most 500 locations." A request without the `location` parameter is 400 (spec 029 Story 1) |
| any | Rename (`/locations/:id/edit`, `PATCH`) | 303, "Renamed “<old>” to “<new>”." A change of case alone is allowed; another location's key is refused; the last of two tabs wins; no lot changes (spec 029 Story 2) |
| empty | Remove (`/locations/:id/removal/new`, a confirmation page, then `DELETE`) | 303, "Removed “<name>”."; a second request is 404 (spec 029 Story 3) |
| holding lots | Remove | The removal page is a refusal instead: "“<name>” holds 12 copies in 3 lots. Move them before removing it.", the first 100 lots (by name, set code, number, language, finish, condition, price paid), each linking to its card page, "and N more", "Back to locations" and no Remove button. A `DELETE` gets the same page with 409, also when a lot was moved in after the confirmation page opened (spec 032 decision 3, AC-5.2–AC-5.5, P1) |

The locations page lists locations by comparison key, then name, in code-point order, each with "12 copies in 3 lots" ("1 copy in 1 lot") or "Empty" (spec 029 decision 2; spec 032 P2). Until "Move to…" (#48), a location is emptied one lot at a time with Move copies (spec 032 decision 3). It is reached from "Locations" in the header after "Scan" and a row in More before "Export collection"; no tab bar section is current on it (spec 029 decision 8).

### The collection page

`GET /collection` shows the grid or the table: the `view` the URL names when it is `grid` or `table`, else the saved view (grid until one is chosen). A page outside bulk mode whose URL names a valid view saves it for that user, unless the browser marked the request a prefetch; an unknown view shows the saved one with 200 (spec 006 FR-1, AC-1.2–AC-1.6, AC-1.10). The page shows "My collection", "<copies> items · <unique cards> unique", the actions "Add by number", "Scan cards" and "Add items", the filter bar (name search, view switch, `Edit many`), and the count on the line under it ("<matching> of <total> items" when filtered) (spec 004 AC-11.1, AC-11.4; spec 006 AC-1.1, AC-4.1; spec 009 AC-8.2; spec 026 decision 1). An empty collection shows "No cards in your collection yet. Search for a card or add cards by number to start adding." and no filter bar, view switch or `Edit many`, and so does a bulk URL or `Edit many` on it (spec 026 decision 1; spec 006 AC-1.9, Error Scenarios). A filter that matches nothing shows "No cards in your collection match "<query>"." and "0 of <total> items"; in bulk mode the bar reads "0 of 0 selected" with no header checkbox (spec 004 AC-11.5; spec 006 AC-5.9).

- **Filter:** part of a card's name or localized name, case-insensitive for ASCII, `%` and `_` literal, at most `Catalog::Search::MAX_QUERY_LENGTH` characters; it is in the URL (spec 004 AC-11.4, AC-11.5).
- **Grid:** one tile per owned printing, ordered by card name, then release date newest first, set code, collector number and language; 120 per page; out-of-range pages fall back with 200. A tile shows the image, the total quantity ("×1" too), one finish badge for the special finishes its lots have, the printed name (localized only for a non-English printing), `SET · number`, the language and its place line (spec 004 AC-11.2, AC-11.3; spec 033).
- **Table:** one row per lot, 120 per page, with name (thumbnail and printed name, linking to the card page with the collection mark), set · number, language, finish, condition (short form), quantity, Location, price paid and a menu ("Edit copy", "Remove"). Below 640px only name, quantity and the menu show, and a line under the name gives set · number, finish, condition, language and the place (spec 006 AC-2.1, AC-2.8; spec 033 AC-2.1, AC-2.2).
- **Sort (table only):** name, set · number, condition (the vocabulary's scale), quantity or price paid, by an allowlist in `CollectionTable::Sort`; the default order is the grid's, then finish order, condition scale and price, unspecified last, then id, which breaks every tie. The first click on Name sorts descending; a new sort returns to page 1. An unknown column is the default order with 200; a known column with an unknown direction is that column ascending (`CollectionTable::Sort.parse`, pinned by `spec/models/collection_table/sort_spec.rb`), where spec 006 AC-3.7 says the default order for both. The Location column is not sortable (spec 006 Story 3, FR-3; spec 033 decision 4).
- **Place line:** while the account has no location there is no place line and no Location column. Otherwise a tile shows the place with most copies, then "+N more" for the printing's other places, unplaced counting as one (ties: comparison key, unplaced last); an unplaced lot or tile reads "No location" in secondary ink, and the phone row line leaves "No location" out. A tile's line is one line with an ellipsis; a row's wraps (#142) (spec 033 decisions 1–3, 5, AC-1.1–AC-1.6, AC-2.2).

### Bulk mode

`Edit many` (a button) clears any stored selection and opens the table in bulk mode (`bulk=1`) with nothing selected, the same filter and sort; the view switch is inert (Table pressed, Grid disabled); rows have no menu (spec 006 AC-4.2, AC-4.3). In bulk mode, paging, sorting, filtering and the actions all submit one form with the page's ticks, so unsubmitted ticks are never lost without scripting (spec 006 FR-4). The selection:

- belongs to the session, tied to the filter and sort it was made under; a page under another filter or sort shows nothing selected, and changing either clears it (spec 006 AC-5.6, FR-4);
- is either a set of ticked lots, or every matching lot with exceptions, resolved against the account's lots and the filter when an action runs (spec 006 AC-5.4, AC-5.5, AC-7.8, FR-4);
- counts copies: "0 of <matching> selected", "12 of 4,812 selected", "All 4,812 items selected" (spec 006 AC-5.1–AC-5.4);
- changes only through submissions; a header toggle resets to everything or nothing, then only rows that differ from their rendered baseline apply (spec 006 FR-4, AC-5.10);
- is cleared by `Done` (back to the saved view with the same filter and sort, the view preference unchanged), discarded when the session ends, and deleted by an import apply that writes a lot (spec 006 AC-4.5, FR-4; spec 028 decision 7).

An action with nothing selected is 422, "Select at least one item."; a selection whose lots are all gone or not the account's is 422, "None of the selected items are in your collection any more." (spec 006 FR-5, AC-8.1).

**Set condition** (its own page): the vocabulary's scale or "Not specified" (anything else is 422, "That isn't a known condition."); every selected lot gets it; lots that reach one identity merge (each keeps its place, so they merge only within a place); all or nothing at the cap, with 422 "Nothing changed. <name> (<SET> · <number>) would have more than 9,999 copies in one lot." naming the first over-cap lot in the table's order; 303 back to the bulk table with the changed lots (a merged lot too) selected. "Set the condition of <n> items to <label>." or "Cleared the condition of <n> items." (spec 006 Story 6; spec 032 AC-7.3).

**Remove** (a confirmation page, "Remove <n> items?") removes the selected lots and keeps one undo record for the session: 303 to the bulk table with the selection cleared and "Removed <n> items from your collection." with an Undo button, the only way to it (spec 006 AC-7.1–AC-7.3). The record:

| State | Moves on | Then |
|---|---|---|
| Undoable (holds each removed lot's printing, finish, condition, price paid, quantity and location) | Undo | The lots come back, each in its location if the account still has it, else unplaced; rows that then share an identity are one, merging into an existing lot; all or nothing at the cap ("Nothing restored. <name> (<SET> · <number>) would have more than 9,999 copies in one lot."). "Restored <n> items to your collection." plus "<n> lots came back without a location." when any did. 303 to the collection URL it carries if that is a collection path, else the collection (spec 006 AC-7.4, AC-7.5; spec 032 P5, AC-7.4, AC-7.5, AC-7.8) |
| Undoable | Any other removal in the same session (bulk, one lot, or a number-entry or scanner Undo that removes a lot) | Superseded |
| Used or superseded (a stub with no lot data) | Undo again | 422, "This removal can no longer be undone." |
| Any | The session ends | Discarded; an Undo then signs in and answers 404 (spec 006 AC-7.6, FR-6) |
| Undoable | An import apply that writes a lot | Superseded, in every session of the account (spec 028 decision 7) |

At most one undoable record per session, backed by a partial unique index (spec 006 FR-6). When only the restored rows themselves pass 9,999 and no held lot does, the cap message names the first such row (plan-level ruling O2, recorded in spec 032's `verification.md`).

### Number entry

`/collection/number_entry` needs a signed-in collector even when the catalog is open (spec 026 decision 1, AC-1.10). It is linked from the collection page's head, More, and the empty collection's sentence.

1. **Set and language.** The set field offers every set with an active entry of any kind, newest first, undated last, then by code, as "Name (CODE)"; it resolves typed text by code, exact name (any case) or the shown form, and otherwise says "No set matches “<text>”. Type a set code or choose a set from the list." The language defaults to EN if the set has it, else the language most of its active entries have (ties to the first code); with one language no field shows. The set's type, code and language are in the URL. With no catalog loaded the page says so and shows no form (spec 026 decisions 2, 9, AC-1.3–AC-1.11, Error Scenarios).
2. **A line** is number, quantity (1–9,999, default 1), finish and, while the account has a location, Location ("No location" first). The finish defaults to the type's first in `finish_order` so typed and scanned copies share lots; finish and location carry over in the URL after an add. A page link whose `location` is no longer the account's shows "No location" and doesn't raise (spec 026 decision 3; spec 034 decisions 1, 2, AC-4.2).
3. **Matching** among the set and language's active entries: an exact match of the trimmed number first; only if none, ignoring case and leading zeros. Two or more ask the collector to choose; the choice (`pick`, the entry's external key) is checked on the server. None: "No card numbered <number> in <set name> (<LANGUAGE>)." (spec 026 decision 8, AC-2.6–AC-2.10, AC-4.1).
4. **Adding** is at once, through `NumberEntry.add!`: `Lot.add!` with the line's finish (none for an entry that lists no finishes) and location, and the line recorded in the same transaction, at most once per line key (`NumberEntry::KEY_FORMAT`). The notice reads "Added <n> × <name> (<SET> · <number>, <finish>) in <location> to your collection.", without the place for an unplaced line. A refused line comes back as typed: a bad quantity, finish or location ("That location isn't one of yours any more. Choose again.") on its field, a malformed line key on the form, and the cap ("One lot can hold at most 9,999 copies.") as a page alert (spec 026 decisions 4, 10, Story 4, FR-3; spec 034 decisions 3, 5, Story 4).

The list:

| State | Moves on | Then |
|---|---|---|
| No list | First add | The account's one list opens (unique per account) |
| A kept line | Undo, while its lot exists, is the account's and holds at least the line's quantity | The copies leave that lot as it now is (removed when none are left); the line leaves the list; "Undid <n> × <name>." Removing a lot this way supersedes the session's bulk Undo (spec 026 decision 5, AC-3.2, AC-3.3, AC-3.5) |
| A kept line | Its lot was removed, merged away or edited below the line's quantity | "Changed in your collection", no Undo; a request is 422 "Those copies have changed in your collection, so they can't be undone here." (spec 026 AC-3.4; spec 032 AC-7.6) |
| Any | Done | The list and its lines are deleted; the copies stay; back to the collection (spec 026 AC-3.7). An Undo of a line of a list Done cleared, or another account's line, is 404, "That line is no longer in your list." (spec 026 AC-3.8) |
| Any | An import apply that writes a lot | Destroyed, as Done would (spec 028 decision 7) |
| Any | The account is deleted | Deleted with it (spec 026 AC-3.9) |

The page shows "This list: <lines> lines, <copies> cards", the newest `NumberEntry::SHOWN` lines, and the rest behind "Show all N"; a line names the place its lot is in now (spec 026 AC-3.1; spec 034 decision 3, AC-3.3). The page asks Turbo to refresh with `replace`, not morph, so focus moves after each add (spec 026 Supersedes, against ADR 0015).

### The card page and search

The card page shows "Owned <copies>" with "<printings> printings" across every printing of the card, then "Your copies": "<copies> in <lots> lots" and one row per lot of every printing (set · number, finish, condition, language, Location, quantity, price paid; ordered newest printing first, then by the stored finish, condition and price as text and numbers, unspecified first, then unplaced first and by location), each with "Edit copy", "Move copies" and "Remove"; with none, "You don't have this card yet." and "Add a copy" (spec 004 AC-8.4–AC-8.6; spec 032 AC-4.1, AC-4.2). Unlike the grid and table, its Location column shows even for an account with no location, every row reading "No location" (open for the maintainer, spec 032 `verification.md`). "Printings" lists the shown printing, then the other owned printings, then up to `Catalog::CardOverview::NEWEST` newest unowned ones, each with its owned quantity (spec 004 AC-8.7). A card page URL with the collection mark starts its breadcrumb at Collection and marks that section; the mark is kept on its links and after its adds, edits, moves and removals; the Referer is never used (spec 004 AC-8.9, FR-9). A visitor on an open catalog holds nothing and nothing about a collection is queried (spec 023 FR-3).

Search and the printings page show each owned printing's quantity ("×3") on its tile, counted from the account's lots in a bounded number of queries (spec 004 FR-14); an unowned tile shows its image at full opacity with a "Not owned" tag on its own meta row, which ends the link's accessible name, and its add control sits at the foot of its cell so a row's add buttons are level (spec 004 AC-6.3, AC-6.6; spec 021 decisions 1–7). Search tiles show no place (spec 033 Non-Goals).

## Named constants

| Name | Value | Defined in | Why this value | Source |
|---|---|---|---|---|
| `Lot::MAX_QUANTITY` | 9,999 | `app/models/lot.rb`; the `lots_quantity_range` check constraint | Copies in one lot; per place since places are in the identity | spec 004 FR-6; spec 032 decision 1 |
| `Lot::FULL_MESSAGE` | "One lot can hold at most 9,999 copies." | `app/models/lot.rb` | The form and number-entry message at the cap | spec 004 AC-9.3; spec 026 AC-4.4 |
| `Catalog::QuickAddsController::FULL_LOT` | "You already have the most copies one lot can hold (9,999)." | `app/controllers/catalog/quick_adds_controller.rb` | The quick add's cap message | spec 004 AC-7.3a |
| `CollectionGrid::PER_PAGE`, `CollectionTable::PER_PAGE` | 120 | `app/models/collection_grid.rb`, `collection_table.rb` | Tiles and rows per page | spec 004 AC-11.3; spec 006 AC-2.4 |
| `Catalog::Search::MAX_QUERY_LENGTH` | 100 | `app/models/catalog/search.rb` (catalog core) | The filter is cut to it, as search is | spec 004 AC-11.4 |
| `CollectionTable::Sort::COLUMNS` | `name set condition quantity price` | `app/models/collection_table/sort.rb` | The sortable columns, an allowlist | spec 006 AC-3.2, FR-3 |
| `User::COLLECTION_VIEWS` | `grid`, `table` | `app/models/user.rb` | The views a URL may name and a user may save | spec 006 FR-1 |
| `Location::MAX_PER_ACCOUNT` | 500 | `app/models/location.rb` | A ceiling for a hosted instance, not a number a collector should meet; equals the format's `maxItems` | spec 029 decision 7 |
| `Location::Name::MAX_LENGTH` | 60 code points | `app/models/location/name.rb`; the `locations_name_length` check constraint | At most 240 bytes of UTF-8; the same in the schema and the document | spec 029 decisions 5, 7 |
| `Location::Holdings::LISTED` | 100 | `app/models/location/holdings.rb` | Lots listed on the refusal page, as many as the import preview lists | spec 032 P1 |
| `NumberEntry::KEY_FORMAT` | 32 lowercase hex digits | `app/models/number_entry.rb` | The line key's form (`SecureRandom.hex(16)`) | spec 026 decision 10 |
| `NumberEntry::SHOWN` | 10 | `app/models/number_entry.rb` | Lines shown before "Show all N" | spec 026 AC-3.1 |
| `Catalog::CardOverview::NEWEST` | 10 | `app/models/catalog/card_overview.rb` | Unowned newest printings listed on the card page | spec 004 AC-8.7 |
| `COLLECTOR_CURRENCY` | one of `Collector::Currency::SYMBOLS`' 20 codes, default `USD` | `config/initializers/currency.rb`, `lib/collector/currency.rb` | The one currency price paid is shown in; any other code stops boot | spec 004 FR-6 |
| `Location::MESSAGES`, `Location::FULL` | "Give the location a name.", "Names can't contain control characters.", "Names can be at most 60 characters."; "You can have at most 500 locations." | `app/models/location.rb` | The name field's refusals | spec 029 AC-1.6–AC-1.10 |
| `Lot::Move::CHOOSE`, `Lot::Move::ALREADY_THERE` | "Choose from 1 to %d copies."; "Those copies are already there." | `app/models/lot/move.rb` | Move copies' refusals | spec 032 AC-3.7, P4 |
| `BulkSelection::NOTHING_SELECTED`, `BulkSelection::NONE_LEFT` | "Select at least one item."; "None of the selected items are in your collection any more." | `app/models/bulk_selection.rb` | Bulk actions refused for want of lots | spec 006 FR-5, AC-8.1 |
| `BulkRemoval::NO_LONGER_UNDOABLE` | "This removal can no longer be undone." | `app/models/bulk_removal.rb` | A used or superseded Undo | spec 006 AC-7.6 |
| `Collections::NumberEntries::Lines::UndosController::GONE`, `CHANGED` | "That line is no longer in your list."; "Those copies have changed in your collection, so they can't be undone here." | `app/controllers/collections/number_entries/lines/undos_controller.rb` | A number-entry Undo refused (404; 422) | spec 026 AC-3.4, AC-3.8 |

Measured bars, not constants (recorded in each spec's `verification.md` where one exists): the collection page and the table under 500 ms of server time for 5,000 lots, and Set condition and Remove on every matching lot of 5,000 under 2 seconds (spec 004 NFR; spec 006 NFR); the grid and table within those budgets with 5,000 lots over 300 locations (spec 033 AC-3.3).

## Decisions not in an ADR

- **Lots merge on identity;** quick add specifies nothing, so repeated quick adds fill one lot (spec 004 Open Questions, AC-7.4, AC-7.5).
- **An edit that collides with another lot merges into it,** and the other lot survives (spec 004 AC-10.2; `Lot#revise!`).
- **Grid to look, table to manage:** the grid stays the default, the view is saved per user by any non-bulk URL that names one, and bulk mode always shows the table (spec 006 Goals, FR-1).
- **The selection is stored on the server per session,** not in the page; "every matching lot" is its own state (spec 006 FR-4).
- **Only the destructive bulk action has an Undo,** one per session, valid until the next removal or the session's end, with no time limit (spec 006 Open Questions, FR-5, FR-6).
- **Bulk actions answer with a redirect,** not Turbo Streams replacing rows, because both are submitted from their own pages (spec 006 FR-5).
- **The location is part of the lot's identity;** moving some copies splits a lot (maintainer, 2026-10-23; spec 032 decision 1; ADR 0025).
- **A location that holds copies can't be removed;** unplacing and merging on removal was not chosen (maintainer, 2026-10-23; spec 032 decision 3, superseding spec 029 decision 3's second half).
- **Move copies works on one lot, from the card page;** many lots at once is #48 (spec 032 decision 4).
- **A location is a name and nothing else** (no kind, order, nesting or notes) (maintainer, 2026-10-20; spec 029 decision 4).
- **Locations are reached from the header and More, not a tab** (spec 029 decision 8).
- **No place line or Location column on the grid and table, and no Location field on the forms or number entry, while an account has no location** (spec 032 P3; spec 033 decision 2; spec 034 decision 2). The card page's column is the exception (below).
- **A tile names one place and counts the rest** ("+N more") rather than listing every place or splitting the tile (maintainer, 2026-10-26; spec 033 decision 1).
- **Number entry's finish defaults to the type's first and carries over;** each line adds at once; there is no live preview of the match (maintainer, 2026-10-15; spec 026 decisions 3, 4, 7). The Location field is on each line and carries over (spec 034 decision 1).
- **Number entry offers sets and matches entries of every kind,** tokens included (spec 026 decision 9).
- **An unowned search tile keeps its image unfaded and says "Not owned"** (maintainer, 2026-10-13; spec 021 decision 1), as an override in `additions.css` until the published `ItemTile` drops the fade (spec 021 decision 8).

**Accepted limits and open issues:**

- [#142](https://github.com/plainprogrammer/Collector/issues/142): a table row's place line wraps on phones, and the wide Location cell doesn't cut a long name, against spec 033 decision 5 (one line, ellipsis), which tiles follow. The wrap rule applies to every narrow collection table, an account's with no location too. The maintainer kept the shipped behaviour; a later spec supersedes decision 5 for rows, and spec 033 stays frozen in part until it does. The same issue lists spec 033's test gaps and the missing core guard.
- The card page's "Your copies" shows its Location column, every row "No location", for an account with no location; whether it should hide as the grid and table do is open for the maintainer (spec 032 `verification.md`, Implementation review).
- An unknown sort direction with a known column sorts that column ascending, not the default order spec 006 AC-3.7 names (`CollectionTable::Sort.parse`).
- [#47](https://github.com/plainprogrammer/Collector/issues/47), [#48](https://github.com/plainprogrammer/Collector/issues/48): no filter or sort by location, and no "Move to…" for many lots; a location with many lots is emptied one move at a time.
- [#49](https://github.com/plainprogrammer/Collector/issues/49), [#50](https://github.com/plainprogrammer/Collector/issues/50): no decks as locations and no "Free to use".
- [#56](https://github.com/plainprogrammer/Collector/issues/56): the scanner adds unplaced copies.
- [#64](https://github.com/plainprogrammer/Collector/issues/64): price paid is shown in one instance currency.
- Collector numbers with symbols a keyboard lacks match only when typed exactly; such cards are added from their card page (spec 026 decision 8).
- Number entry can't tell apart one set code in two collectible types; the type travels in the URL with the code (spec 026 Non-Goals).
- A form opened before its location was removed answers 404 when submitted (spec 032 decision 6).
- Whether the "×N" badge on a card image counts as a stamp under Scryfall's image guidelines is not ruled on (spec 021 Open Questions). `ItemTile.md` still describes the fade until a re-export (spec 021).
- Spec 034 was self-reviewed only; the maintainer's review is owed, and AC-3.2 (a moved or merged line) and AC-5.1 (the select in a browser) have no example of their own (spec 034 `verification.md`).

## Sources

- [Spec 004](../specs/004-design-system-collection/spec.md): the collection and adding cards: Story 7, Stories 9–11, AC-6.3, AC-6.6's owned quantities and add controls, AC-8.4–AC-8.7, AC-8.9, AC-12.1–AC-12.3, AC-12.5, FR-6–FR-8, FR-9's breadcrumb mark, FR-10, FR-12 as these pages meet it, FR-14's owned quantities, the collection rows of its NFRs and Error Scenarios, and the Open Questions resolved for lots. Its design-system part is the [design system](../design-system/README.md)'s; its accounts, users and admin users are tenancy and accounts'; its search and card page catalog content is catalog core's.
- [Spec 006](../specs/006-collection-list-view/spec.md): all.
- [Spec 021](../specs/021-unowned-tile-marker/spec.md): all.
- [Spec 026](../specs/026-typed-entry/spec.md): all but decision 6 and FR-5 (the list left out of the export), which are data portability's.
- [Spec 029](../specs/029-manage-locations/spec.md): decisions 2 (the order of locations, P2), 3–8 and 12, decision 9's name rules as the model holds them, Stories 1–5, FR-1, FR-2 (locations, the pages, the navigation); format version 2, the export, the preview and the apply are data portability's.
- [Spec 032](../specs/032-lot-in-a-location/spec.md): decisions 1–6, P1–P6, Stories 1–7, FR-1, FR-2 (a lot's place, moving copies, the card page, removing a location, every other way of changing lots); format version 3, the export, the preview and the apply are data portability's.
- [Spec 033](../specs/033-location-on-tiles-and-rows/spec.md): all but decision 5 as it applies to rows (#142).
- [Spec 034](../specs/034-location-in-typed-entry/spec.md): all.
- Cited for a neighbour's fact only: [spec 009](../specs/009-card-scanner-confirm-flow/spec.md) AC-8.2 (the collection page's "Scan cards"), [spec 023](../specs/023-signed-out-catalog-browsing/spec.md) FR-3 (a visitor holds nothing), [spec 028](../specs/028-apply-import/spec.md) decision 7 (an apply clears working state).
- ADRs [0019](../adr/0019-lot-as-the-unit-of-ownership.md), [0025](../adr/0025-a-lots-location-is-part-of-its-identity.md); [0023](../adr/0023-locations-make-export-format-version-2.md) as far as locations and their names use it; [0017](../adr/0017-row-level-tenancy-one-user-per-account.md) and [0018](../adr/0018-collectible-agnostic-catalog-core.md) as far as lots use them; [0015](../adr/0015-admin-progress-by-polling.md) for number entry's refresh.
- Reference: [design system](../design-system/README.md).
- Issues [#43](https://github.com/plainprogrammer/Collector/issues/43), [#44](https://github.com/plainprogrammer/Collector/issues/44), [#45](https://github.com/plainprogrammer/Collector/issues/45), [#46](https://github.com/plainprogrammer/Collector/issues/46), [#51](https://github.com/plainprogrammer/Collector/issues/51), [#65](https://github.com/plainprogrammer/Collector/issues/65); open: [#105](https://github.com/plainprogrammer/Collector/issues/105) (this doc), [#47](https://github.com/plainprogrammer/Collector/issues/47), [#48](https://github.com/plainprogrammer/Collector/issues/48), [#49](https://github.com/plainprogrammer/Collector/issues/49), [#50](https://github.com/plainprogrammer/Collector/issues/50), [#56](https://github.com/plainprogrammer/Collector/issues/56), [#64](https://github.com/plainprogrammer/Collector/issues/64), [#142](https://github.com/plainprogrammer/Collector/issues/142).

## Distillation log

| Date | Distilled | Pull request |
|---|---|---|
| 2026-10-27 | Specs 004 (the collection and adding cards), 006, 021, 026 (all but the export part), 029 (locations, the pages, the navigation), 032 (a lot's place, moving copies, removing a location), 033 (all but decision 5 for rows, #142) and 034; ADRs 0019 and 0025; and CLAUDE.md's number entry, locations and lots-in-locations paragraphs | slice C's pull request for #105 |
