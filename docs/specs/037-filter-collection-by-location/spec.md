# Feature 037: Filter the Collection by Location

**Status:** Approved by the maintainer (2026-11-03) at 0.2.0; 0.2.1 corrects the wording of AC-5.8 found while planning; decisions 1, 3, 5 and 6 were ruled by the maintainer on 2026-11-03 as recommended
**Version:** 0.2.1
**Created:** 2026-11-03
**Last Updated:** 2026-11-03
**Depends on:** [spec 032](../032-lot-in-a-location/spec.md) (a lot's location; merged), [spec 033](../033-location-on-tiles-and-rows/spec.md) (the place on tiles and rows; merged), [spec 006](../006-collection-list-view/spec.md) (the table, bulk mode and the selection tied to a filter)
**Branch:** `037-filter-collection-by-location`
**Issue:** [#47](https://github.com/plainprogrammer/Collector/issues/47) (roadmap item 12, theme C: locations)
**Plan:** present once written (`plan.md` in this folder)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.1 | 2026-11-03 | AC-5.8 only: the refusal's wording. When the rendered location still matches the stored selection, a ticked header gives the existing "None of the selected items are in your collection any more."; when it doesn't, the selection restarts and the answer is "Select at least one item.". Nothing is removed either way; no decision changes (found tracing `SelectionsController#act` for the plan) |
| 0.2.0 | 2026-11-03 | First spec review (Opus, read-only), all findings taken: fail-closed bulk resolution (B1, decision 7, AC-5.8, FR-1, FR-4), the canonical stored value (decision 1, M1), which value bulk actions use (decision 6, M2), submitted `location=` (FR-3, M3), refusal re-renders, post-removal restart and bulk pagers (AC-4.3, AC-5.6, M4), the supersessions (M5, Supersedes), and minor wording and checks |
| 0.1.0 | 2026-11-03 | First draft from issue #47, specs 004 (Story 11), 006 (FR-4), 032 and 033, and the maintainer's rulings on decisions 1, 3, 5 and 6 |

---

## Problem Statement

Spec 032 let a collector put a lot in a location and spec 033 made the collection's grid and table say where each one is. Neither lets a collector ask the other question: "what is in Blue binder?" The only ways today are to read every tile or row, or to open the locations page, which counts what a location holds but can't list it beyond the first 100 lots on a refusal page. The 1.0 test says every card has a location; a collector filing the collection needs the cards that still have none, and a collector looking for a binder's contents needs just that binder.

This spec adds a location filter to the collection page's filter bar, beside the name search. It adds no data a collector owns: a lot's location exists since spec 032. It adds one column of working state to the bulk selection (decision 5), which the export leaves out like the rest of that table.

**Outcome (issue #47):** a collector narrows the collection to one location.

> **Terms.** *Lot*, *location*, *place*, *unplaced* ("No location" on screen), *tile* and *row* are as in specs 032 and 033. The *name filter* is the collection's search box (spec 004 AC-11.4). The *location filter* is this spec's: one of the account's locations, or "No location", or neither (*All locations*). *Matching lots* are the account's lots that pass every filter that is on.

## Goals

- A collector picks one of their locations in the filter bar, and the grid and the table show only the copies in it.
- A collector can pick "No location" to find what they haven't filed yet.
- The location filter and the name filter work together, in the URL, in the grid, the table, paging, sorting and bulk mode.
- A collector with no locations sees the page exactly as it is.

## Non-Goals

- Choosing more than one location at once (the issue says "one location").
- Sorting by location, or grouping by it (spec 006 FR-3 and spec 033 decision 4 keep the Location column unsortable).
- Counts inside the select's options ("Blue binder (12)"). The locations page has the counts (spec 032 P2).
- A link from the locations page or a location's refusal page to the filtered collection. It is a natural follow-on; the maintainer may rule on it separately.
- Remembering the chosen location across visits. The name filter isn't remembered either; the URL is the state.
- A filter by anything else (set, finish, condition, price).
- Any change to the export format, its version, the schema's collector-owned tables or the import (decision 8).
- "Move to…" for many lots (#48), though it will want this filter (spec 006 bulk mode already carries a filter into its actions).

## Decisions

### 1. The filter's values: all, one location, or none (ruled by the maintainer, 2026-11-03)

The filter has three kinds of value: *All locations* (the default, no narrowing), *one of the account's locations*, and *No location* (only unplaced lots). It is the `location` URL parameter: absent or empty is all, `none` is "No location", and a location's id is that location. The id is the location's own, as the add, edit and Move forms use it, but a bad one is treated differently: those forms answer 404 (spec 032 decision 6), this page is a GET a collector bookmarks, so a bad value means all (decision 7), as spec 034 AC-4.2 treats a stale link on number entry (there, its own default).

**Canonical form.** The value is one of three strings: `""` (all), `"none"`, or a location's id in decimal digits without leading zeros (`\A[1-9]\d*\z`). Anything else, including `017`, ` 17`, `17abc`, and a non-string parameter (`location[]=1`), is read as all. The stored selection (decision 5) and the compared values hold this form only, so `context?` is a string comparison of canonical values.

Alternatives: one location only (recommended against: "what has no place yet?" would be unanswerable, which is the question the 1.0 test makes the collector ask); several locations (beyond the issue, and more state in the URL and the selection).

### 2. It joins the name filter with AND

The two filters combine: a lot matches when its printing's name matches the name filter (if set) and it is in the chosen place (if set). Each is its own URL parameter (`q`, `location`), so a link, Back and a reload keep both.

### 3. A tile under a location filter counts only the copies in that place (ruled by the maintainer, 2026-11-03)

A tile is one printing summing its lots (spec 033). Under a location filter the tile sums only the matching lots: its quantity and its special-finish badges are of the copies in that place, and its place line is not shown, because every copy is in the one place the filter names (the place line returns when the filter is "All locations"). A printing with no copy in the place has no tile. The page's counts follow: the head's "<copies> items · <unique> unique" is the whole collection's and does not change (spec 004 AC-11.1); the line under the filter bar reads "<matching> of <total> items" whenever either filter is on (spec 004 AC-11.4), counting copies.

Alternative: show a printing's full quantity and place line whenever any of its lots matches. Rejected: the tile quantities would not add up to the count line, and "what is in Blue binder?" would show copies that aren't.

### 4. The table keeps its rows and columns

The table is one row per lot (spec 006), so it simply shows the matching lots. Its Location column, sorts, paging and row menus are unchanged; the column then repeats the filter's place on every row, which is harmless and keeps one table layout.

### 5. Bulk mode honours the filter, as part of the selection's context (ruled by the maintainer, 2026-11-03)

Bulk mode shows the filter bar's controls and acts only on matching lots. The selection is already stored "tied to the filter and sort it was made under" (spec 006 FR-4); the location filter joins that context: a page or action under another location filter shows nothing selected and changes restart the selection, exactly as a changed name filter does (spec 006 AC-5.6). "Select every matching lot" and Set condition and Remove on it therefore reach only the lots in the chosen place, resolved against the account's lots when the action runs (spec 006 AC-5.4, AC-8.1, AC-8.2).

The selection stores the filter beside its name filter and sort, in one new column of `bulk_selections` (a string, `""` for all). That table is working state, left out of the export and cleared by an apply that writes a lot (spec 028 decision 7), so the column adds nothing to the format.

Which value a bulk submission uses follows the name filter's rule: pagers, sort headers, Remove, Set condition, Done and the selection's context use the **rendered** location (a hidden `rendered_location`, beside `rendered_q`); only Filter, or Enter in the name field, applies what the select now shows, and a page is kept across it only when neither filter changed.

Alternative: bulk mode ignores the location filter. Rejected: the bulk table would silently show lots outside the chosen place and "every matching lot" would act on them.

### 6. A native select in the filter bar, shown only while the account has a location (ruled by the maintainer, 2026-11-03)

The control is the design system's FilterSelect: a native `<select name="location">` in the filter bar's group, labelled "Location" for assistive technology, followed by a Filter button so it works without scripting (the catalog's set filter does the same, its button is labelled "Search"). In bulk mode the bulk filter bar already has a hidden default "Filter" button, which stays first in tree order so Enter still applies the filters; the visible button is the same one made visible beside the select, not a second control with the same name. Its options are "All locations", "No location", then the account's locations in the order of the locations page (`Location.ordered`). It sits in the filter bar and, in bulk mode, in the bulk filter bar, where it joins the bulk form like the name field (spec 006 FR-4).

While the account has no location the select is not shown, a `location` parameter is ignored, and the page is spec 033's (the same rule as the place line, spec 033 decision 2). Alternative: show it disabled with a hint. Rejected for the reason spec 034 decision 2 gives: a collector who doesn't use locations should not see them.

### 7. A value that names no location of the account means all

A `location` that is another account's id, the id of a location removed in another tab, an id that is not a number, or any text but `none` is **All locations**: the page renders with 200, the select shows "All locations", nothing is raised, no other account's lot is shown and nothing says whether such a location exists. Only the page's **display** of a URL value falls back to all. A *stored* selection and a *submitted* `rendered_location` are never re-resolved to all: the stored id applies as a plain predicate on the account's own lots (`location_id = id`, or `IS NULL` for `none`), so a removed or foreign id matches nothing, and a rendered value that no longer names a location mismatches the selection's context and restarts it with nothing selected, never under all.

A stored selection whose location has since been removed matches no lot: its `lots` are empty, so an action on it answers "None of the selected items are in your collection any more." (spec 006) and never reaches lots the collector didn't choose. (A location that held lots can't be removed, spec 032 decision 3, so this needs a race: still, it must fail closed.)

### 8. No collector-owned data, no export change

Nothing about a lot or a location changes, so the export format's version and its Coverage tables stay as they are; the new column is on working state the export already leaves out. The format document is not edited.

## User Stories

### Story 1: Show what is in one location
As a collector looking for what I keep in Blue binder, I want to narrow the collection to it.

- [ ] **AC-1.1** Given an account with locations When the collection page shows (grid or table, not empty) Then the filter bar has a Location select with "All locations" selected, "No location", then the account's locations in the order of the locations page, and a Filter button after it.
- [ ] **AC-1.2** Given lots in Blue binder and in Long box When the page is requested with `location` set to Blue binder's id Then the grid shows only the printings that have a lot in Blue binder, each tile's quantity the copies in Blue binder only (a printing with 3 in Blue binder and 2 in Long box reads 3), and no tile shows a place line; a special-finish badge shows only if a copy in Blue binder has that finish (a foil lot in Long box gives no foil badge under Blue binder).
- [ ] **AC-1.3** Given the same filter in the table view Then it shows one row per lot in Blue binder, in the chosen sort, with the Location column, paging and row menus as before; a printing in two places shows only its Blue binder row.
- [ ] **AC-1.4** Given the filter is on Then the line under the filter bar reads "<matching> of <total> items" (copies), the head's "<copies> items · <unique> unique" is the whole collection's, and the pager counts the filtered printings (grid) or lots (table).
- [ ] **AC-1.5** Given the filter is on Then the Location select shows the chosen location selected.
- [ ] **AC-1.6** Given a location that holds no lot When it is chosen Then the page shows "No cards in your collection are in “<name>”." and "0 of <total> items", no grid or table and no pager (the select and name search stay).
- [ ] **AC-1.7** Given the filter is on and the collector picks "All locations" Then the page shows the whole collection with place lines again.

### Story 2: Find what has no location
As a collector filing my collection, I want to see the cards I haven't placed.

- [ ] **AC-2.1** Given placed and unplaced lots When `location=none` Then only unplaced lots show; tiles sum only unplaced copies and show no place line; "No location" is selected.
- [ ] **AC-2.2** Given every lot is placed When `location=none` Then the page shows "No cards in your collection are without a location." and "0 of <total> items".

### Story 3: Together with the name search
- [ ] **AC-3.1** Given a name filter and a location When both are in the URL Then a lot shows only if its printing's name matches and it is in that place; the count line counts those copies.
- [ ] **AC-3.2** Given both filters match nothing When the page shows Then it reads `No cards in your collection match "<query>" in “<name>”.` (or `… match "<query>" without a location.`) with "0 of <total> items"; a name filter with no location filter keeps spec 004 AC-11.5's sentence. (The query keeps spec 004's straight quotes and a location's name takes the curly quotes of spec 029's messages; both are deliberate.)
- [ ] **AC-3.3** Given the filter bar's GET form Then it submits `q`, `location` and the sort together, so Enter in the name field or Filter applies both, and `location=` (all) is a valid submission meaning all locations.

### Story 4: Every link and form keeps the filter
- [ ] **AC-4.1** Given the filter is on Then it is kept by: paging (grid and table), a sortable column header, the view switch, the "Edit many" button and its menu row, and the return after "Edit copy" or "Remove" from a row (the table the collector came from, spec 006 AC-2.6), the way the name filter is kept.
- [ ] **AC-4.3** Given the card page Then it is unchanged: it lists every lot of the printing wherever it is, so a tile's "3" under Blue binder can sit beside 5 copies on the card page.
- [ ] **AC-4.2** Given a page that names a view and a location Then opening it saves the view as before (spec 006 AC-1.3), and the location is not saved: opening `/collection` later shows all locations.

### Story 5: Bulk mode
- [ ] **AC-5.1** Given the filter is on When "Edit many" is used Then the bulk table opens under the same filter (and name filter and sort), with nothing selected, the Location select in the bulk filter bar showing the choice, and the bar's count reading "0 of <matching> selected".
- [ ] **AC-5.2** Given the bulk table under a location When "Select all" is ticked and Set condition or Remove is used Then the action changes or removes exactly the matching lots in that place and no lot in another place, and a lot outside the filter whose id is submitted is ignored (spec 006 AC-8.1).
- [ ] **AC-5.3** Given ticks on a page of the bulk table When the collector changes the location in the bulk bar and presses Filter (or Enter in the name field) Then the selection restarts under the new filter (spec 006 AC-5.6); when they change it and instead press Next, a sort header, Remove or Done, the rendered location is used and the unsaved choice of the select is ignored; and a page or an action that arrives under another location than the selection was made under shows and acts on nothing selected.
- [ ] **AC-5.4** Given a bulk table under a filter that matches nothing Then the bar reads "0 of 0 selected" with no header checkbox, as for the name filter (spec 006 AC-5.9), with the message of AC-1.6, AC-2.2 or AC-3.2.
- [ ] **AC-5.5** Given a stored selection under a location that has been removed When the selection's lots are read Then none are selected, and the confirm and refusal pages for it behave as for an empty selection (decision 7).
- [ ] **AC-5.6** Given the confirm pages, Cancel, Back and the redirects after Set condition and Remove Then they return to the bulk table under the same location filter, name filter, sort and page (spec 006 AC-6.5, AC-7.2, AC-7.3), and Undo of a removal returns to the collection URL it carries, location included (spec 006 AC-7.4). The bulk pagers and sort headers (`go=<url>` buttons) carry it, a refused action's 422 re-render ("Select at least one item.", "None of the selected items are in your collection any more.", an Undo refused) shows the same location filter, select and empty sentence, and the selection after a removal is under the same location, so the next submission doesn't restart it.
- [ ] **AC-5.7** Done returns to the saved view under the same location and name filters and sort (spec 006 AC-4.5).
- [ ] **AC-5.8** Given a bulk page rendered under location L, L is removed in another tab, and the collector ticks the header and presses Remove Then nothing is removed and the answer is a 422 refusal, never a removal under all locations: "None of the selected items are in your collection any more." when the rendered location still matches the stored selection (its predicate matches no lot), "Select at least one item." when it doesn't (the selection restarts with nothing selected).

### Story 6: The control, and values that don't belong
- [ ] **AC-6.1** Given an account with no location Then the page shows no Location select, in both modes, and `location=<anything>` is ignored with 200: spec 033's page.
- [ ] **AC-6.2** Given `location` is another account's location id, a removed location's id, not a number, or text other than `none` (decision 7) Then the page is the whole collection with 200, "All locations" is selected, and nothing of the other account is shown or named; the count line has no "of", and the pager is the unfiltered one. A bulk submission or page that names another account's location id in `location` or `rendered_location` acts on no lot of that account (decision 7).
- [ ] **AC-6.3** Given the Location select is a native select with an accessible name "Location", and a Filter button after it Then choosing and pressing Filter applies the filter without scripting, and Enter in the name field applies both (the default submit button stays first in tree order in bulk mode).
- [ ] **AC-6.4** Given a location whose name is long Then the option is clipped by the browser as FilterSelect says, and the select is at most 220px wide.
- [ ] **AC-6.5** Given a narrow screen (below 640px) Then the select and its button sit in the filter bar's filter group, as the design system lays out FilterSelect, with no horizontal page scroll.
- [ ] **AC-6.6** A location's name in an option, a message or the select is HTML-escaped; a name with `<`, `&` or `"` shows as text.

## Functional Requirements

### FR-1: The filter's value
**Must:** be resolved once from the URL parameter against `Current.account`'s locations for display (decision 7), in the canonical form of decision 1 (`\A\d+\z`, non-strings read as all); be one definition used by the grid, the table, the bulk selection and the select. The stored selection and a submitted `rendered_location` are compared as canonical strings and applied as a plain predicate within the account's lots, never re-resolved to all.
**Must not:** accept an account id, a user id or any other account's location; name a collectible type (the filter is core code, `Lot.location_id`).

### FR-2: Where it applies
**Must:** narrow the grid's tiles, quantities and special-finish badges, the table's rows and counts, the pagers, and the bulk selection's lots, from one scope of matching lots (`CollectionFilter.lots`), so no place re-implements it.
**Must not:** change the head's whole-collection stats or any lot.

### FR-3: The URL and the forms
**Must:** carry `location` wherever `q` and the sort are carried (spec 006 FR-1, FR-4), including the bulk form, and keep it out of the URLs the app builds (`collection_listing_path`, pagers, redirects) when it is "All locations"; a submitted `location=` means all.
**Must not:** save the choice for the user, or put it in a cookie.

### FR-4: Bulk selection
**Must:** store the filter in the selection's context beside the name filter and sort, compare it in the same context check (`context?`), restart on a change, and fail closed for a removed location (decision 7).
**Must not:** be exported; broaden a selection when the location is gone.

### FR-5: The Filter button and wording
**Must:** follow the design system's voice for the empty sentences and the labels ("All locations", "No location").
**Must not:** add a component or a hard-coded colour, spacing or font.

## Non-Functional Requirements

- **Performance:** the filter adds a predicate on `lots.location_id` (indexed) to the statements the page already runs, and reads the account's locations once for the select (one memoised read of `account.locations.ordered`, from which "does the account have a location" (spec 033 decision 2), the select's options and the chosen location's name for the empty sentences are all taken; the grid's grouped places read is skipped under a location filter): no new statement per tile, row or location. The collection page stays under 500 ms of server time for 5,000 lots over 300 locations with a location filter on, as spec 033 AC-3.3 measured the unfiltered page. `lots` has an index on `location_id` alone, so the measurement is made with several accounts' lots in the table and with `location=none` (`IS NULL`); if it misses the budget the plan adds `[account_id, location_id]`.
- **Security and tenancy:** the value is resolved only through `Current.account.locations`; a request spec proves that another account's location id shows none of its lots and names nothing. No admin page shows a location, a lot's place or a per-location count (hosted-door rule 2). The new parameter is read with `params.expect`/explicit `params[:location]` as a string and never interpolated into SQL (bind parameters).
- **Cost per account (hosted-door rule 4):** one string column on a row that exists once per session, and no background work or per-account storage beyond it.
- **Collector choice (hosted-door rule 3):** the choice lives in the URL and the session's selection, not an instance setting.
- **Design system:** the select is the `FilterSelect` pattern, with the existing FilterBar layout, `c-*` classes and tokens only; any bulk-bar rule it needs goes in `collector/additions.css` with a note in the component's doc.
- **Reliability:** a location removed between showing and submitting a page never gives a 500 (decision 7).
- **Accessibility:** the select is a native control with an accessible name and a visible focus ring from the design system.

## Error Scenarios

| Situation | Behaviour |
|---|---|
| `location` is another account's, removed, non-numeric or unknown text | All locations, 200, nothing raised (AC-6.2) |
| An account without locations has `location` in the URL | Ignored, spec 033's page (AC-6.1) |
| A location that holds nothing is chosen | "No cards in your collection are in “<name>”." (AC-1.6) |
| A stored bulk selection whose location was removed | No lots selected; "None of the selected items are in your collection any more." (AC-5.5) |
| A bulk page or action under another location than the selection | Nothing selected; the selection restarts (AC-5.3) |

## Open Questions

None. (A link from the locations page to the filtered collection is a Non-Goal; see above.)

## Out of Scope (Future Considerations)

- A link from "12 copies in 3 lots" on the locations page to the filtered collection.
- Filtering by more than one location, and by set, finish or condition.
- "Move to…" for the lots a filter shows (#48).

## Documents that change

| Document | Change |
|---|---|
| [`docs/architecture/collection-and-lots.md`](../../architecture/collection-and-lots.md) | The collection page (the filter, the counts, the tiles, bulk mode's selection context); drops "no filter … by location" from #47 in "Not yet"; Sources |
| [`docs/architecture/data-portability.md`](../../architecture/data-portability.md) | None: it doesn't list the bulk selection's columns (decision 8) |
| [`docs/design-system/components/FilterSelect.md`](../../design-system/components/FilterSelect.md) | A line that the collection page uses it, in bulk mode too, if the plan adds a rule |
| [`docs/specs/README.md`](../README.md), [`docs/roadmap.md`](../../roadmap.md) | This spec's row; item 12 |
| [spec 004 Story 11](../004-design-system-collection/spec.md), [spec 006 FR-4](../006-collection-list-view/spec.md), [spec 033](../033-location-on-tiles-and-rows/spec.md) | Not edited; the index records the supersessions below and what this spec adds (a second filter, the selection's context) |

## Supersedes

- Spec 033 AC-1.8 (a tile shows all its printing's places under a filter): now only under the name filter; under a location filter a tile shows only that place's copies and no place line (decision 3).
- Spec 033 FR-3 (`account.locations.exists?` decides whether places show): the one memoised read of the account's locations (NFR Performance).
- Spec 004's note that the filter bar has only the name search (Story 11 plan notes): it also has the Location select while the account has a location.
- Spec 006 FR-4's selection context (name filter and sort): it also holds the location (decision 5).

## Notes for the plan

- Spec 006 FR-4's context is `query` plus `sort_key` on `bulk_selections`; `BulkSelection#context?`, `restart!`, `record!` and `lots`, `CollectionFilter.lots`, `CollectionTable::SelectionState`, `Collections::SelectionsController` (`query`, `rendered_q`, `destination`), `BulkSelected`, `collection_listing_path`, `prepare_collection(_at)`, the pagers, `_view_forms` and `_bulk`'s hidden fields all carry `q` today; each needs `location` beside it. A small value object for the filter (name and place) would cut that plumbing; the plan decides.
- The new column must be a migration safe on any prior version (default `""`, `null: false`), reversible, with a unit test that an old row reads as "all".
- `places?` and the select's locations should be one read.
- Carry `location` through each place that carries `q`: `BulkRemoval.remove!`'s `restart!` (`selection.query`), `Collections::BulkRemovals::UndosController` and its refusal's `prepare_collection_at`, `ConditionChangesController` and `BulkRemovalsController` through `BulkSelected#set_selection` (`@bulk_path`), `CollectionListing#prepare_collection_at` (it parses only `q`, sort, page, view, bulk), `SelectionsController#destination` (a page is kept only when both filters are unchanged), the bulk pagers and sort headers.
- The empty-state sentence lives in two places keyed differently (`show.html.erb` on `matching_quantity.zero?`, `_bulk.html.erb` on `table.lots.empty?`); both take decision-3's sentences.
- Look for every place that renders the `c-empty` "match" sentence (show and `_bulk`) and the count line.
