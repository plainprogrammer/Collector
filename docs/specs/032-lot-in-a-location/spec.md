# Feature 032: Put a Lot in a Location

**Status:** Draft. The maintainer ruled decisions 1–6 on 2026-10-23 (decision 3 against the draft's recommendation); the details P1–P6 are proposed and wait for the maintainer's confirmation. The independent review is in `review.md` (NEEDS REVISION, fixed in 0.2.0)
**Version:** 0.1.0
**Created:** 2026-10-23
**Last Updated:** 2026-10-23
**Depends on:** [spec 029](../029-manage-locations/spec.md) (manage locations, issue #44; merged) and, through it, [spec 028](../028-apply-import/spec.md) (apply an import, issue #40; merged). Spec 031 (#42, an upgrade check in CI) touches CI only and is independent
**Branch:** `032-lot-in-a-location`
**Issue:** [#45](https://github.com/plainprogrammer/Collector/issues/45)
**Plan:** not written. It owes the ADR of decision 1 (numbered when written: the next free number on `origin/main`'s `docs/adr`)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.0 | 2026-10-23 | From the independent review (`review.md`): a row with an unlisted location keeps a readable identity (AC-10.3); a bulk Undo merges restored rows with each other and survives a removal made before the migration (AC-7.5, AC-7.8); a lot's location is matched by comparison key and re-exports with the stored spelling (AC-9.4); the edit form is reached from the table and the scanner too (decision 4, AC-2.8); deleting an account with placed lots (AC-6.6); the migration names every table that points at lots (AC-7.1); the worst-case file for the apply's bars (AC-11.12); Open Questions made consistent; Given/When/Then gaps and smaller points closed |
| 0.1.0 | 2026-10-23 | First draft, with the maintainer's rulings of 2026-10-23 on decisions 1–6 |

## Problem Statement

The design system says players need "where is it" as much as "what is it", and the 1.0 test's first check is that the family's real cards are in a deployed instance, "each with a location" ([north star](../../north-star.md)). Spec 029 gave a collector places to name (a binder, a box) but nothing can be in one: a lot is a quantity of one printing with a finish, a condition and a price paid (spec 004, [ADR 0019](../../adr/0019-lot-as-the-unit-of-ownership.md)), and that is all it knows.

This spec lets a collector record which location a lot's copies are in. ADR 0019 names the difficulty: the design system says a physical copy is in exactly one place at a time, yet a lot is many identical copies, and four copies of one printing can sit in two binders. Decision 1 rules how a lot sits in more than one place. The rest follows from it: how copies are added to a place, moved between places, seen, and kept when a location is removed; how typed entry, the scanner and the bulk actions behave until their own specs; and what the export, the import preview and the apply do with places.

A place is data the collector owns, so this spec extends the export format in the same pull request (roadmap ruling 19, north star "Export covers it"): each lot carries its location, which makes **format version 3** ([ADR 0023](../../adr/0023-locations-make-export-format-version-2.md)).

> **Terms.** A *location*, the *locations page*, a *name* and the *comparison key* are as in spec 029. A lot is *in* a location, or *unplaced* ("No location" on screen). A lot's *identity* is its printing, finish, condition, price paid and location (decision 1); the first four are as in spec 004. A lot's *place* is its location or none. *Moving* copies changes their place. The *card page* is a printing's page, `/catalog/entries/:id`, whose "Your copies" table lists the account's lots of that printing. The *export*, the *preview*, *well-formed*, *resolvable*, a *problem row* and the *plan* are as in specs 017, 025 and 028.

## Goals

- A collector puts copies in a location when adding them, changes the location of a lot, and moves some or all of a lot's copies to another location or to none.
- A printing can be in several places at once, each place its own lot with its own quantity, and a copy is in exactly one place.
- The card page shows where each lot is. The locations page shows how much each location holds.
- A location that holds copies can't be removed; the collector is told what it holds and where to find it (decision 3).
- Every way of adding or changing lots that exists today keeps working, and puts copies in no location until the spec that adds a place to it (#48, #51, #56).
- An export carries each lot's place (format version 3), and the preview and the apply read versions 1 to 3, so a collector can always preview and apply their own file and the restore-and-match check of the 1.0 test stays true.
- Existing lots migrate safely: every lot of the previous release is unplaced, and no value of any lot changes.
- The cost per account is stated (hosted-door rule 4).

## Non-Goals

- Showing a location on tiles and rows (#46) and filtering by location (#47). The collection grid and table don't change.
- "Move to…" on many lots at once (#48; spec 006's deferral). Moving here is one lot at a time, from the card page.
- Decks as locations, a deck's rule that a copy in it isn't free for another deck, and "Free to use" (#49, #50).
- Choosing a location in typed entry (#51) or for a scanner sitting (#56). Both keep adding unplaced copies.
- A default location, a kind of location, nesting, or an order the collector sets (spec 029 decision 4).
- Recording anything about a single copy within a lot (ADR 0019's consequences stand).
- Currency per account (#64). It extends the export after this spec; the format version after 3 is its.
- Changing how spec 028 stores, expires or sequences an upload beyond what places need (decision 10).

## Users and Context

**Primary users:** a signed-in collector who keeps cards in binders and boxes, and wants the app to say which one a card is in.
**Usage context:** setting up an instance for a family's collection: a few thousand lots, a dozen to a few hundred places. Cards are placed as they are added or as a binder is entered, and moved when a binder is taken apart.
**User mental model:** "Four Serra Angels: two in the blue binder, two in the long box. Show me both, and let me move one over."

## Decisions

Rulings of 2026-10-23, put to the maintainer with the alternatives below: decisions 1, 2, 4, 5 and 6 as recommended; decision 3 *not* as recommended (the draft recommended unplacing and merging; the maintainer ruled that a location holding lots can't be removed). The details P1–P6 follow the decisions and are proposed.

### 1. The location joins the lot's identity: a lot splits by place (ruled)

**Ruling.** A lot's identity is its printing, finish, condition, price paid and location. Copies that share all five are one lot with a quantity of 1 to 9,999; copies that differ only in place are different lots. An account never holds two lots of one identity (the unique index of spec 004 FR-6 keeps backing this). The 9,999 cap is per lot, so per place. A lot is in one location or in none, and every copy of it is there.

The ADR that records this is owed by the plan (ADR 0019 asks for it; roadmap item 10 expects it). It lays out the options below against the criteria in the table, and supersedes ADR 0019's open question and the part of [ADR 0023](../../adr/0023-locations-make-export-format-version-2.md) named in decision 3.

| Option | What it is |
|---|---|
| **A. The location joins the identity (ruled)** | A lot carries at most one location; four copies in two binders are two lots. |
| B. Quantity divided among places | The lot's identity is unchanged; another table says how many of the lot's copies are in which location, and the rest are unplaced. |
| C. A location on the lot, outside its identity | One lot per printing, finish, condition and price, with one place. Copies of one identity can't be in two places. |
| (D. A row per copy) | Reverses ADR 0019: thousands of rows for a playset-heavy collection. Not considered further. |

| Criterion | A: in the identity | B: divided among places | C: outside the identity |
|---|---|---|---|
| A copy is in exactly one place | Yes, by construction: a lot's copies share its place | Yes, if the placed quantities never exceed the lot's; every writer must keep that sum | Yes |
| Four identical copies in two binders | Two lots | One lot, two placements | **Not representable**: fails the 1.0 test for split copies |
| Merging typed, scanned and imported copies | The existing merge, one more value in the key; typed and scanned copies merge into the unplaced lot | Unchanged merge, but a merge must also combine placements, and undoing an add must decide which copies leave | Unchanged |
| Collection grid and table | One lot, one place: a row shows its place (#46) | A row may have several places | One place |
| Filter, "Move to…", decks, "Free to use" (#47–#50) | A filter on one column; a move is a change of that column with the merge machinery bulk "Set condition" already has; "in decks" is a sum of lot quantities | A join and a sum of placements; a move rewrites placements | As A, but wrong for split copies |
| Import: replace, plan, fingerprint (specs 025, 028) | A row matches a held lot on one more value; the plan has the same outcomes | A row would carry placements; "changed" must also compare placements | As A |
| Bulk actions and undo | Bulk "Set condition" and the bulk removal's undo keep one more value | Each must also carry placements | As A |
| Export (version 3) | One new field per lot, `location` | A list per lot, `placements` | One new field |
| Migration | A nullable column; unplaced lots keep their key and every value | A new table; no change to lots | As A |
| Removing a location that holds copies | Refused (decision 3); or, if allowed, lots would merge and could pass the cap | Placements could just be deleted | As A |

Why A: it changes only what "the same lot" means, in the one place the code already defines it, and every later spec in the theme is a change of one column. B keeps the lot as it is, but every writer of a lot's quantity (adding, editing, merging, the bulk undo, the typed and scanner undo, the import) then has to keep a second table consistent, which is the failure a collector never sees until the counts disagree. The cost of A, accepted: a lot no longer means "all my copies of this finish, condition and price", and moving some copies is a split.

### 2. Unplaced is no location; existing lots stay as they are (ruled)

A lot with no location is *unplaced*. It is a real state, not an error: the previous release's lots are all unplaced, typed entry and the scanner add unplaced copies until #51 and #56, and a collector may never use locations. There is no default location and no backfill. On screen it reads "No location"; in a file it is `null`.

The migration adds the lot's location (empty for every row) and changes no existing value. An unplaced lot's key is the key it has today, so the previous release's rows need no rewrite and keep their unique index.

### 3. A location that holds copies can't be removed (ruled; supersedes the draft's recommendation)

**Ruling (maintainer, 2026-10-23).** Removing a location that holds any lot is refused. Nothing is unplaced and nothing is merged. The refusal says how many lots and copies the location holds and that they must be moved first. An empty location is removed as spec 029 does (its confirmation page, then `DELETE`).

The draft recommended the opposite: removing sets the location's lots back to unplaced, merging each into the unplaced lot of the same identity, and refusing only when a merge would pass 9,999 copies. The ruling avoids the merge and the cap case in the removal, and keeps "removing a location never deletes or changes a lot" simply true.

**How this relates to spec 029 decision 3** ("removing a location never removes copies"; ADR 0023 binds that "deleting a location sets copies back to 'no location' and nothing else"). The first half stays true: no removal deletes a lot. The second half is replaced: copies are never set back by removing, because a non-empty location can't be removed. The apply (decision 10) is the one path that can remove a location that held lots, and only in the same plan that removes those lots; it never leaves a lot in a missing location. Recorded in the Supersedes table and in the specs index, in both directions.

**How a collector empties a location in this spec.** From the refusal page (P1), one lot at a time: open the lot's card page, choose "Move copies" (decision 4), and send the copies to another location or to none. When every lot has been moved, the location is empty and can be removed. **Known cost until #48** ("Move many lots at once"): a location with many lots takes one move per lot.

### 4. Moving copies is in this spec; a place is set on the add and edit forms (ruled)

A collector sets a place in three ways. The first two are forms that already exist; the edit form is also reached from the collection table's menu and the scanner's Details, so it gains the field wherever it is opened and returns to where it came from. "Move copies" is only in the card page's lot menu; the table's menu is unchanged (decision 5):

- **Adding copies** ("Add a copy", spec 004): the form gains a Location field. The copies join the lot with the same identity in that place, or start one.
- **Editing a lot** ("Edit copy"): the form gains a Location field. Changing it moves the whole lot, merging into the lot of the new identity if there is one (spec 004 AC-10.2).
- **Move copies**, a new action in each lot's menu: a page asking how many of the lot's copies and to which location (or "No location"). All of them is the same as changing the location in the edit form; some of them splits the lot. It is how a printing comes to be in two places.

Without the third, a printing could reach two places only by lowering a lot's quantity and then adding the rest elsewhere, in two steps that the collector must get right. The alternative not chosen: whole-lot placement only, leaving the split to #48. Moving the copies of many lots at once is still #48; this action moves one lot's copies.

### 5. The grid, table, quick add, typed entry, scanner and bulk actions don't gain a place (ruled)

The collection grid and table (#46, #47), the quick add on a tile, typed entry (#51), the scanner (#56) and the bulk actions (#48) are not changed to show, choose or filter by a place. They keep working: copies they add are unplaced and merge into the unplaced lot of their identity; the bulk "Set condition" and the bulk removal's undo keep each lot's place (Story 7). The card page and the locations page are where a place is seen and set in this spec. The card page is a detail page, which the design system says is not where "where is it" should live; #46 puts it beside the name on tiles and rows, and this spec doesn't pre-empt it.

### 6. A location id from another account is 404 (ruled)

Every location a request names is looked up through the signed-in account. An id that belongs to another account, or to no location, answers 404 and changes nothing, as spec 029 decision 12 does for the locations pages. A form that was opened before its location was removed answers 404 too (accepted; removing an empty location while a form is open is rare).

### 7. Older files are read as unplaced (ruled)

**Ruling (maintainer, 2026-10-23).** A version 1 or 2 file has no place on its lots. The preview and the apply read its lots as unplaced: a lot in the file is matched with the account's *unplaced* lot of the same printing, finish, condition and price. A held lot that is in a location has no match in such a file, so the preview shows it as removed, and the file's lot as added (or as changed, against the unplaced lot). The preview says why in a sentence (Story 10), and the apply needs the removal confirmation that spec 028 already asks for when lots are removed.

This is a restore, as every apply is (spec 025 decision 1: the collection becomes the file). The alternatives not chosen: leave places alone for such a file, which is ambiguous when a printing is in two places (which lot does the file's quantity belong to?), and refuse such a file while any lot is placed, which would stop a collector from restoring a backup they took before this spec. Locations follow spec 029: a version 2 file replaces the locations by name, a version 1 file leaves them alone.

### Details proposed (P1–P6)

- **P1. The refusal page lists the lots (decision 3).** The page that refuses removal lists the first 100 lots in the location, ordered by name, then set code, collector number, language, finish, condition and price paid (as the preview orders lots, spec 025 decision 11), each with its quantity and a link to its card page, and "and N more" after 100. Without it a collector could not find the lots to move, because the grid and the table don't show places until #46 and #47.
- **P2. The locations page shows what each location holds.** Each location reads "12 copies in 3 lots" ("1 copy in 1 lot"), or "Empty". Spec 029 left counts out because nothing could be in a location; this is a grouped total over the account's lots, no per-location query.
- **P3. The Location field appears when the account has a location.** An account with no locations sees no field on the add and edit forms, but a hint "Add a location to keep copies in one" linking to the locations page. The Move copies page then says "You have no locations yet", with the link, when the lot is unplaced and no location exists.
- **P4. Moving to the place a lot is already in is refused** (422, "Those copies are already there.").
- **P5. A bulk removal's Undo restores a lot whose location has since been removed unplaced.** The location can only have been removed once it was empty, which the removal itself made possible. Restored rows that then have one identity (one was in the removed location, one was unplaced) merge with each other and with the account's unplaced lot, the 9,999 cap applies to the merged total, and the Undo stays all or nothing. The Undo notice adds how many lots came back without a location.
- **P6. A split-off lot's times.** Moving some copies creates the lot in the new place with *added* and *changed* times of the move. Moving all copies, with or without a merge, keeps the surviving lot's *added* time and sets its *changed* time to the move.

## Supersedes

Earlier specs are frozen (maintainer ruling, 2026-10-15). What this spec changes in them and in the documents they feed is recorded here, not there; the specs index has the same entries, both directions.

| Earlier document | Item | What changes |
|---|---|---|
| [ADR 0019](../../adr/0019-lot-as-the-unit-of-ownership.md) | Decision ("a lot is a quantity of one catalog entry with the same finish, condition and price paid") and the open question for locations | A lot's identity includes its location (decision 1). Recorded in the new ADR, which supersedes the open question; ADR 0019's Status line gets a pointer. |
| [ADR 0023](../../adr/0023-locations-make-export-format-version-2.md) | Consequences: "deleting a location sets copies back to 'no location' and nothing else" | A location that holds copies can't be removed (decision 3). ADR 0023 stays Accepted for the rest; the new ADR supersedes this sentence and ADR 0023's Status line gets a pointer. |
| [Spec 004](../004-design-system-collection/spec.md) | FR-6 and the merge criteria (a lot is the same printing, finish, condition and price paid; AC-7.4, AC-9.3, AC-10.2); the add and edit forms; the card page's "Your copies" table | A lot also has a place and merges only within it. The add and edit forms gain the Location field, the table gains the Location column, and each lot's menu gains "Move copies". |
| [Spec 017](../017-export-format/spec.md), [ADR 0020](../../adr/0020-export-format.md) | Lot identity ("a lot is identified by five values"); decision 14 and the consequences that said a lot in a location raises the format | Lot identity has six values from version 3 (printing's two, finish, condition, price paid, location). Version 3 is this spec's; spec 029 had already moved the statement from version 2. |
| [Spec 022](../022-export-collection/spec.md) | The file it writes (version 1, then 2 by spec 029) | The export writes version 3: each lot gains `location` (Story 8). |
| [Spec 025](../025-import-preview/spec.md) | The versions it reads (1 and 2, by spec 029); the sentence "This instance reads version 2."; decision 1's matching of a row to a held lot on five values; decision 9's problem-row reasons | The preview reads versions 1 to 3, refuses above 3 ("This instance reads version 3."), matches a row to a held lot on six values with the rules of decision 7, and adds the problem-row reason for a location the file doesn't list (Story 10). |
| [Spec 028](../028-apply-import/spec.md) | Terms and decision 2 (what the plan and its fingerprint cover); the lot upsert's unique key; the confirmation and the notice's counts | The apply reads versions 1 to 3, resolves each lot's location to the account's location, includes places in the plan and the fingerprint, and removes a location only with the lots in it (decision 10, Story 11). The stored upload, expiry, sweep and the working state cleared when lots are written stand. |
| [Spec 029](../029-manage-locations/spec.md) | Decision 3 (removing a location never removes copies; the confirmation page "states how many lots are in the location once #45 can put them there"); Non-Goals ("counting lots or copies per location"); decision 9 ("a lot carries no reference to a location in version 2", still true for version 2); the removal pages' AC-3.x | A location that holds copies can't be removed; its confirmation page is replaced by the refusal page when it holds any (decision 3, Story 5). The locations page shows counts (P2). Version 2 is unchanged. |
| [Spec 006](../006-collection-list-view/spec.md) | The deferred "Move to…" bulk action; bulk "Set condition" and the bulk removal's Undo (AC-6.x, AC-7.4) | "Move to…" stays deferred to #48. Set condition merges only lots of one place, and Undo restores each lot to its place (Story 7). |
| [Spec 026](../026-typed-entry/spec.md), [spec 009](../009-card-scanner-confirm-flow/spec.md) | Their lots merge by the identity of spec 004 | The copies they add are unplaced and merge into the unplaced lot only (Story 7). Nothing else in them changes; #51 and #56 add the choice. |

## User Stories

### Story 1: Put copies in a location when adding them

**As a** signed-in collector
**I want** to say where new copies go
**So that** they are recorded in the binder they are about to enter

**Acceptance criteria:**

- [ ] **AC-1.1** Given a collector with locations "Long box" and "Blue binder" When the add form for a printing opens Then it has a "Location" field offering "No location" (selected), then "Blue binder" and "Long box" in the order of spec 029 decision 2.
- [ ] **AC-1.2** Given the add form with quantity 4 and "Blue binder" chosen When it is submitted Then the account holds one lot of that printing with 4 copies in Blue binder, the response is a 303 to the card page, and the notice reads "Added 4 × <name> (<set> <number>) to Blue binder."; given "No location" it reads as before, "…to your collection."
- [ ] **AC-1.3** Given a lot of 4 in Blue binder When 2 more of the same finish, condition and price paid are added to Blue binder Then there is one lot of 6 in Blue binder.
- [ ] **AC-1.4** Given a lot of 4 in Blue binder When 2 of the same finish, condition and price paid are added with "No location" Then there are two lots, 4 in Blue binder and 2 unplaced, and the 4 is unchanged.
- [ ] **AC-1.5** Given a lot of 9,998 in Blue binder When 2 are added to Blue binder Then the response is 422 with "One lot can hold at most 9,999 copies." beside Quantity and nothing changes; given the same 2 added to Long box Then they are added (the cap is per lot, so per place).
- [ ] **AC-1.6** Given the add form was submitted with an error elsewhere (a quantity of 0) When it is shown again (422) Then the chosen location is still selected.
- [ ] **AC-1.7** Given a request that names the location of another account, or a location that doesn't exist When the add form is submitted Then the response is 404 and no lot is created or changed.
- [ ] **AC-1.8** Given a request that leaves the location out or blank When the add form is submitted Then the copies are unplaced, as before this spec.
- [ ] **AC-1.9** Given an account with no locations When the add form opens Then it has no Location field and shows "Add a location to keep copies in one." linking to the locations page (P3).

### Story 2: Change the location of a lot

**As a** signed-in collector
**I want** to correct where a lot is
**So that** the app matches the shelf

**Acceptance criteria:**

- [ ] **AC-2.1** Given a lot in Blue binder When its edit form opens Then the Location field has "Blue binder" selected; given an unplaced lot it has "No location" selected.
- [ ] **AC-2.2** Given a lot of 4 in Long box and no lot of the same printing, finish, condition and price in Blue binder When the collector chooses Blue binder and saves Then the same lot (same id) is in Blue binder with 4 copies, its added time is unchanged and its changed time is the save's, and the response is a 303 to where Edit copy returns, with "Saved.".
- [ ] **AC-2.3** Given a lot of 4 in Long box and a lot of 3 of the same printing, finish, condition and price in Blue binder When the first is edited to Blue binder Then one lot of 7 is in Blue binder and the other is gone (spec 004 AC-10.2).
- [ ] **AC-2.4** Given the merge of AC-2.3 would pass 9,999 copies When it is saved Then the response is 422 with "One lot can hold at most 9,999 copies." and both lots are as they were.
- [ ] **AC-2.5** Given a lot in Blue binder and an unplaced lot of the same printing, finish, condition and price When the first is edited to "No location" Then the two merge into one unplaced lot.
- [ ] **AC-2.6** Given a lot When its quantity and its location are both changed in one save Then the lot ends with the new quantity in the new location, merged as AC-2.3 if the identity exists there.
- [ ] **AC-2.7** Given another account's location, or one that doesn't exist When a lot's edit form is submitted with it Then the response is 404 and the lot is unchanged.
- [ ] **AC-2.8** Given a lot's edit form opened from the collection table's menu, and another from the scanner's Details When the location is changed and saved Then the lot moves as AC-2.2 says and the collector returns to where they came from.

### Story 3: Move some or all of a lot's copies

**As a** signed-in collector
**I want** to move some of a lot's copies to another place
**So that** one printing can be in two binders

**Acceptance criteria:**

- [ ] **AC-3.1** Given the card page's lot menu When it opens Then it offers "Edit copy", "Move copies" and "Remove"; "Move copies" opens `GET /lots/:id/move/new`, titled "Move copies of <name> (<set> <number>)", with a Copies field (1 up to the lot's quantity, set to the quantity), a "To" field offering "No location" and the account's locations other than the lot's own place, starting on the first of them in the order of spec 029 decision 2 ("No location" first), a "Move" button and "Cancel". The table's menu has no "Move copies".
- [ ] **AC-3.2** Given a lot of 4 in Long box When all 4 are moved to Blue binder, which has no lot of that identity Then the same lot (same id) is in Blue binder with 4 copies, the response is a 303 to the card page, and the notice reads "Moved 4 × <name> (<set> <number>) to Blue binder.".
- [ ] **AC-3.3** Given a lot of 4 in Long box When 2 are moved to Blue binder, which has no lot of that identity Then the lot in Long box has 2, a new lot of the same printing, finish, condition and price paid has 2 in Blue binder, the account's copies of that printing are 4 as before, and the notice reads "Moved 2 × …".
- [ ] **AC-3.4** Given a lot of 4 in Long box and a lot of 3 of the same identity in Blue binder When 2 are moved to Blue binder Then Long box has 2 and Blue binder has 5.
- [ ] **AC-3.4a** Given the same lots When all 4 are moved to Blue binder Then one lot of 7 is in Blue binder and the lot in Long box is gone.
- [ ] **AC-3.5** Given a lot in Blue binder When copies are moved to "No location" Then they join the unplaced lot of that identity or start one, and the notice reads "Moved 2 × … to no location.".
- [ ] **AC-3.6** Given a move that would put more than 9,999 copies in one lot of the destination When it is submitted Then the response is 422 with "One lot can hold at most 9,999 copies." beside Copies and both lots are as they were.
- [ ] **AC-3.7** Given a Copies value of 0, a negative number, a number above the lot's quantity, or text When it is submitted Then the response is 422 with "Choose from 1 to <quantity> copies." and nothing changes; given the lot's own place chosen as the destination Then 422 with "Those copies are already there." (P4).
- [ ] **AC-3.8** Given a move whose second write fails (a failure forced after the source lot was changed) When it is submitted Then neither lot has changed.
- [ ] **AC-3.9** Given a lot, or a destination, of another account When its move is requested or submitted Then the response is 404 and nothing changes.
- [ ] **AC-3.10** Given an unplaced lot in an account with no locations When the Move copies page opens Then it says "You have no locations yet." with a link to the locations page and has no Move button (P3).
- [ ] **AC-3.11** Given a split (AC-3.3) When the new lot is read Then its added and changed times are the move's; given a whole move (AC-3.2, AC-3.4) Then the surviving lot keeps its added time and its changed time is the move's (P6).
- [ ] **AC-3.12** Given scripting off, a 360px-wide screen, or the keyboard alone When the Move copies page is used Then a move can be made and cancelled.

### Story 4: See where copies are

**As a** signed-in collector
**I want** to see each lot's place
**So that** I can find a card

**Acceptance criteria:**

- [ ] **AC-4.1** Given a printing with lots in Blue binder and unplaced When its card page shows "Your copies" Then each lot is a row with a Location column reading its location or "No location", and where the optional columns are hidden the location is in the line under the printing with the finish, condition and language.
- [ ] **AC-4.2** Given a printing with 2 copies in Blue binder and 2 in Long box When the card page shows Then it lists two lots, each with its own quantity, and the heading reads "4 in 2 lots".
- [ ] **AC-4.3** Given locations "Blue binder" (3 lots, 12 copies), "Long box" (1 lot, 1 copy) and "Empty box" (none) When the locations page shows Then each reads "12 copies in 3 lots", "1 copy in 1 lot" and "Empty" (P2).
- [ ] **AC-4.4** Given lots in locations When the collection grid or table, the page's totals and the filter bar's counts render Then copies, lots and the owned count of each printing include placed lots exactly as unplaced ones, and neither view shows a location (Non-Goals).
- [ ] **AC-4.5** Given a location name with markup When any page shows it Then it is output escaped.

### Story 5: Remove a location only when it is empty

**As a** signed-in collector
**I want** a location with cards in it to refuse removal and tell me what is in it
**So that** nothing I own is left without a place by accident

**Acceptance criteria:**

- [ ] **AC-5.1** Given an empty location When the collector opens `GET /locations/:id/removal/new` Then they see spec 029's confirmation page, and confirming removes the location, changes no lot, and redirects (303) to the locations page with "Removed “<name>”.".
- [ ] **AC-5.2** Given a location that holds 3 lots (12 copies) When its removal page opens Then it says "“<name>” holds 12 copies in 3 lots. Move them before removing it.", lists the lots (P1), links "Back to locations", and has no Remove button.
- [ ] **AC-5.3** Given the list of AC-5.2 for a location of 250 lots When it renders Then it shows the first 100, ordered as P1 says, and "and 150 more"; each row names the printing, its finish and condition, its quantity, and links to the card page's copies.
- [ ] **AC-5.4** Given a location that holds lots When `DELETE /locations/:id` is sent (a request made by hand, or a stale confirmation page) Then the response is 409 with the page of AC-5.2, the location still exists and no lot has changed.
- [ ] **AC-5.5** Given a confirmation page for an empty location, then a lot is moved into the location, and the confirmation is submitted Then the response is 409 as AC-5.4 and nothing is removed; and a delete made directly in the database of a location that a lot is in fails, so no lot can point at a missing location.
- [ ] **AC-5.6** Given a location holding lots When the collector moves each lot out with Move copies and then removes the location Then the removal succeeds and every lot is where the moves put it (decision 3: how a location is emptied, one lot at a time, until #48).
- [ ] **AC-5.7** Given the refusal page and the locations page When they render Then the counts and the list count only the account's lots.

### Story 6: Only my locations and lots

**As a** signed-in collector
**I want** my places and their contents to be mine alone
**So that** nobody else sees or changes where my cards are

**Acceptance criteria:**

- [ ] **AC-6.1** Given a location of another account When its id is submitted to the add form, the edit form, or the Move copies form Then the response is 404 and nothing changes (AC-1.7, AC-2.7, AC-3.9); and the removal pages answer 404 as spec 029 AC-4.1 says.
- [ ] **AC-6.2** Given two accounts, each with a location called "Box" and a lot of one printing in it When the first adds, edits, moves or merges lots Then the second's lots and locations are unchanged (rows and times compared) and no lot of the second is merged into.
- [ ] **AC-6.3** Given two accounts with "Box" locations When one's locations page and refusal page render Then no count, lot or name of the other appears.
- [ ] **AC-6.4** Given an admin When any admin page renders Then it shows no location name, lot place or per-location count (hosted-door rule 2); the admin users page still shows only account-level copy counts.
- [ ] **AC-6.6** Given a user whose account has lots in locations When an admin deletes the user Then the account, its lots and its locations are all removed and the deletion succeeds (the database refuses deleting a location a lot is in, so lots go first).
- [ ] **AC-6.7** Given a lot being added into a location while another request removes that location (it was empty) When both finish Then the add answers 404 or the removal answers 409, and neither answers 500.
- [ ] **AC-6.5** Given a signed-out visitor When any page of this spec is requested Then the visitor is sent to sign in, and a write without a session fails as spec 029 AC-4.4 says.

### Story 7: Every other way of changing lots keeps working

**As a** signed-in collector
**I want** adding by number, scanning, bulk editing and undo to behave as they did
**So that** placing copies is something I add to my routine, not a change in it

**Acceptance criteria:**

- [ ] **AC-7.1** Given a database from the previous release with lots, a bulk selection with marks, an undoable bulk removal, a number-entry list with lines and a scanner sitting with entries that point at lots When the migration runs Then every lot has the same id, printing, quantity, finish, condition, price paid, key and times as before and is in no location, every mark, line and entry still points at its lot, the bulk removal is still undoable, and the migration is safe to run unattended on an instance that never uses locations. A rollback with no lot in a location keeps the same links.
- [ ] **AC-7.2** Given a printing with an unplaced lot and a lot in Blue binder, each of the same finish, condition and price When a copy is added by the tile's quick add, by number entry, or by confirming a scan Then it joins the unplaced lot, and the lot in Blue binder is unchanged.
- [ ] **AC-7.3** Given a printing with lots of one finish and price in Blue binder and in Long box, both "Near mint" When bulk "Set condition…" sets them to "Lightly played" Then each lot keeps its place, and lots merge only with a lot of the same printing, finish, price, new condition and place; the 9,999 check of spec 006 AC-6.4 holds per place.
- [ ] **AC-7.4** Given a bulk removal of lots in Blue binder and unplaced When its Undo is used Then the lots come back in Blue binder and unplaced, merging per place (spec 006 AC-7.4).
- [ ] **AC-7.5** Given the Undo of AC-7.4 after the location was removed (it was empty once the lots went) When it is used Then those lots come back unplaced and the notice adds how many came back without a location (P5).
- [ ] **AC-7.8** Given a bulk removal of a lot in Blue binder and an unplaced lot of the same printing, finish, condition and price, then Blue binder removed When the Undo is used Then one unplaced lot results with the summed quantity; given the sum passes 9,999 Then the Undo is refused as the cap rule of spec 006 AC-7.5 says and nothing is restored; given a removal made before the migration (its saved lots have no location) Then its lots come back unplaced.
- [ ] **AC-7.6** Given a typed line or a scanner entry whose lot was then moved whole to an empty place (no merge) When its Undo is used Then the copies come out of that lot where it is now (spec 026 AC-3.5); given the move merged the lot into another Then the line can no longer be undone (spec 026 AC-3.4); given a move that left the lot with fewer copies than the line added Then a number-entry line can no longer be undone (spec 026 AC-3.4) and a scanner entry follows its own rule.
- [ ] **AC-7.7** Given a single lot removed (spec 004 AC-10.4) When it was in a location Then it is removed as before, its location is untouched, and the earlier bulk removal can no longer be undone (spec 006 AC-7.6).

### Story 8: The export carries each lot's place

**As a** signed-in collector
**I want** my export to say where each lot is
**So that** a restore puts everything back where it was

**Acceptance criteria:**

- [ ] **AC-8.1** Given an account with lots in locations and unplaced lots When it is exported Then `format_version` is 3 and every lot has a `location` field: the name of its location as stored (NFC), or `null` for an unplaced lot, never an empty string.
- [ ] **AC-8.2** Given a printing in Blue binder and in Long box When it is exported Then the file holds two lots of it, one with each `location`.
- [ ] **AC-8.3** Given an account with an empty location When it is exported Then `locations` lists it, and every lot's `location` is among the listed names.
- [ ] **AC-8.4** Given two accounts When the first is exported Then no name, lot or location of the second is in the file.
- [ ] **AC-8.5** Given an unchanged collection When it is exported twice Then the two files differ only in `exported_at`.
- [ ] **AC-8.6** Given an account that uses no location When it is exported Then every lot has `"location": null` and `locations` is `[]`.

### Story 9: The format document, schema and Coverage cover places

**As a** person who writes or reads an export
**I want** the format to say what a lot's place is
**So that** I can read a file without Collector

**Acceptance criteria:**

- [ ] **AC-9.1** Given `docs/export-format/README.md` When it is read Then it defines version 3: each lot's `location` (a name that follows the Names rules, or `null`; always present), the six-value lot identity, the new well-formedness rule `unknown_location`, `duplicate_lot` over six values, the comparison of a lot's location in "The same collection", the version history and the rewritten expected-changes sentence; and it is updated wherever it says "1 or 2", "All seven fields are always present", "five values" or "the rules are the same for both".
- [ ] **AC-9.2** Given `docs/export-format/v3.schema.json` and the app's copy in `app/models/export_format/` When compared Then they are byte-identical (ADR 0021), `v1.schema.json`, `v2.schema.json`, their examples and their app copies are unchanged byte for byte, and `ExportFormat::Rules` reads each version against its own schema.
- [ ] **AC-9.3** Given the Coverage tables When the suite compares them with the database Then `lots.location_id` is listed with `location` as its field, and the suite fails without that line.
- [ ] **AC-9.4** Given the valid examples When they are checked Then there are: a collection with lots in two locations, a printing in two locations, an unplaced lot and an empty location; an empty version 3 file; a lot whose location is written in NFD, or in another case ("box" for a listed "Box"), for a listed name (well-formed, matched on its comparison key; like `locations-nfd.json` it re-exports with the stored spelling, so it is outside the round-trip check of AC-11.2); and a location of 60 code points on a lot.
- [ ] **AC-9.5** Given the invalid examples and `problems.json` When they are checked Then each fails for the rule it names: a lot with no `location`; a `location` that is a number, `""`, padded, with a double space, with a tab, with a control character, or of 61 code points; a location the file's `locations` doesn't list (`unknown_location`, at `/lots/<i>/location`); and two lots of one printing, finish, condition and price in locations that differ only by case (`duplicate_lot`).
- [ ] **AC-9.6** Given the comparison examples When they are checked Then files whose lots differ only in a lot's location are different collections, a lot written "box" against "Box" are different, and the same lots in another order are the same.
- [ ] **AC-9.7** Given a lot's location string When the model and the schema judge it Then they agree for every Unicode scalar value, by the same definition as a location's name (spec 029 AC-7.8).
- [ ] **AC-9.8** Given a version 2 file whose lots carry a `location` When it is read Then the field is ignored as an unknown field; given a version 3 file with a lot lacking `location` Then it is not well-formed (`required`).

### Story 10: Previewing a file with places

**As a** signed-in collector
**I want** the preview to show what applying a file does to where my cards are
**So that** I don't lose my places by surprise

**Acceptance criteria:**

- [ ] **AC-10.1** Given files of version 1, 2 and 3 When each is previewed Then each is read against its own schema, and a version 4 file is refused as newer: "This instance reads version 3.".
- [ ] **AC-10.2** Given a version 3 file When its rows are matched to the account's lots Then a row matches a held lot only when the printing, finish, condition, price paid and location agree, the location compared by comparison key, so "box" in the file and "Box" held are the same place.
- [ ] **AC-10.3** Given a row whose location the file's `locations` doesn't list When it is previewed Then it is a problem row with the reason "Its location “<name>” isn't one of the file's locations.", the file can't be applied, its identity stays readable (as a `duplicate_lot` row's does) and is matched by comparison key, so no held lot is reported removed because of it (spec 025 decision 1: held by a problem row); the Locations section lists locations as for any file.
- [ ] **AC-10.4** Given a version 1 or 2 file When it is previewed Then the page says "This file was written before lots could be in a location, so its lots would be in none.", its rows are matched with unplaced lots only, and a held lot in a location is reported removed (decision 7).
- [ ] **AC-10.5** Given an account with 4 copies in Blue binder and a version 2 file with the same printing, finish, condition and price When it is previewed Then the preview shows one lot added (4 copies) and one removed (4 copies); and given an unplaced held lot of 4 with the file's times instead Then it is unchanged.
- [ ] **AC-10.6** Given the account's own version 3 export When it is previewed Then nothing would change, and the page says so as spec 028 requires.
- [ ] **AC-10.7** Given a file that moves one lot from Long box to Blue binder and changes nothing else When it is previewed Then the page offers the apply: one lot added in Blue binder, one removed from Long box.
- [ ] **AC-10.8** Given a file that renames "box" to "Box" and changes nothing else When it is previewed Then the Locations section lists the rename, the lots in it are unchanged, and nothing is added or removed.
- [ ] **AC-10.9** Given the lists of added, changed and removed lots When they name a lot Then they add "in <location>" for a placed lot (the file's spelling for added and changed lots, the held one for removed lots), in the first 100 and "and N more" as spec 025 decision 11 says.
- [ ] **AC-10.10** Given a version 3 file that removes a location When it is previewed Then every held lot in it is among the removed lots, and the Locations section lists the location as removed.
- [ ] **AC-10.11** Given two accounts When one previews a file Then only its own lots and locations are read, and no name of the other's appears.

### Story 11: Applying a file with places

**As a** signed-in collector
**I want** applying a file to put my lots back in their places
**So that** a restore matches the export

**Acceptance criteria:**

- [ ] **AC-11.1** Given a previewed version 3 file When it is applied Then every lot of the account ends in the location the file names, or none, in spec 028's one write transaction, with the locations written first so that each lot resolves to one of the account's locations by comparison key.
- [ ] **AC-11.2** Given a collection with lots in two locations, a printing in both, an unplaced lot and an empty location, exported and applied to an empty account on the same catalog When the account is exported again Then the files are equal but for `exported_at` and the profile's name and email (spec 028 Story 6, spec 029 AC-9.15).
- [ ] **AC-11.3** Given a file that moves a lot from Long box to Blue binder When it is applied Then the account holds the lot in Blue binder and none in Long box, and the notice counts one lot added and one removed.
- [ ] **AC-11.4** Given a version 1 or 2 file When it is applied to an account with placed lots Then the lots become the file's, unplaced, the removal needs spec 028's confirmation ("I understand this removes N lots…"), and, for version 2, the locations become the file's; for version 1, the locations are unchanged (spec 029 decision 10).
- [ ] **AC-11.5** Given a file that renames "box" to "Box" When it is applied Then the location keeps its id, its lots stay in it unwritten, and exporting names it "Box".
- [ ] **AC-11.6** Given a plan that removes a location and the lots in it When it is applied Then the lots are deleted before the location in the same transaction, and no lot is ever left in a missing location; given that a lot was placed in such a location after the preview Then the plan differs, the response is 409 with a fresh preview, and nothing is written.
- [ ] **AC-11.7** Given a lot moved to another location between the preview and the apply When the apply is sent Then the response is 409 with a fresh preview and nothing is written (spec 028 Story 3); given a version 2 or 3 file and a location changed in that time as spec 029 AC-9.9 describes Then it is stale as there; a version 1 file doesn't count locations.
- [ ] **AC-11.8** Given the same file applied twice When the second is sent Then it says there is nothing to change (spec 028 AC-2.2) and writes nothing.
- [ ] **AC-11.9** Given a file whose only change is one lot's location When it is previewed Then it is applicable and is stored, and applying it moves that lot.
- [ ] **AC-11.10** Given a write that fails during the apply (a failure forced after the locations were written) Then the whole transaction rolls back and no lot, location or working state has changed.
- [ ] **AC-11.11** Given a file naming a location "Box" and two accounts that each have one When the first applies Then its lots resolve to its own "Box", and the second's lots, locations and `updated_at` times are unchanged.
- [ ] **AC-11.12** Given a collection of 50,000 lots each in one of 500 locations whose names are 60 CJK characters, and its export When the file is previewed and applied Then the file is under the 32 MB limit and spec 028's bars hold (the request under 30 seconds, the write transaction under its hard bar of 4 seconds, under 500 MB growth), with a bounded number of statements and none per lot or per location, recorded in `verification.md`. If the file passes the limit or a bar fails, the maintainer rules before release.
- [ ] **AC-11.13** Given an apply that writes a lot When it finishes Then the working state is cleared as spec 028 decision 7 says; given one that writes no lot Then it is not (spec 029 AC-9.17).

## Functional Requirements

### FR-1: A lot's place

**Must:**
- Keep a lot's identity as its printing, finish, condition, price paid and location, unique per account, backed by the database.
- Allow a lot to be in one of its account's locations or in none, and never in another account's.
- Merge copies of one identity into one lot at every point that merges today (add, edit, bulk set condition, bulk Undo, move), and cap a lot at 9,999 copies there as everywhere.
- Leave every other way of adding or changing lots working, adding unplaced copies (Story 7).

- Scope every lookup and write of locations and lots to the signed-in account (Story 6).

**Must not:**
- Backfill or change any existing lot's value, or give any lot a default location.
- Let a database row point at a location that doesn't exist.
- Name a collectible type in code or copy (spec 029 FR-2).

### FR-2: The pages

**Must:**
- Add the Location field to the add and edit forms, the "Move copies" page and menu item, the Location column on the card page, the counts on the locations page and the refusal page that replaces the confirmation of a non-empty location.
- Answer a failed write with 422 and the reason beside the field, a refused removal with 409, a success with a 303 redirect.
- Work with scripting off, from 360px wide up, with the keyboard alone, and use only the design system's tokens and classes. A new pattern gets a doc under `docs/design-system/components/` and a line in the README's app additions.

**Must not:**
- Change the collection grid, the table, the quick add, typed entry, the scanner or the bulk bar.
- Take an account id from a form, or remove a location on a GET.

### FR-3: The export and the format

**Must:**
- Write version 3, a `location` on every lot (name or `null`), with no extra query per lot.
- Define version 3 in the format document, `v3.schema.json`, the examples, Coverage and the version history in this pull request ("Extending the format"), keeping versions 1 and 2 as they were.
- State `unknown_location`, the six-value identity and the comparison of a lot's location in "The same collection".

**Must not:**
- Write an internal id, or an empty string for "no location".
- Read a missing `location` in a version 3 file as `null`.

### FR-4: The preview and the apply

**Must:**
- Read versions 1 to 3 and refuse higher as newer.
- Match rows to held lots on six values, the location by comparison key, and read older files' lots as unplaced (decision 7).
- Resolve each lot's location to the account's own location, write locations before lots and delete lots before locations, in spec 028's one transaction.
- Cover places in the plan, the "nothing to change" test, the fingerprint, the problem-row reasons and the lists.

**Must not:**
- Leave a lot in a missing location, or remove a location while a lot in it survives.
- Write a location or a place outside the transaction, or for a file that can't be applied.

## Non-Functional Requirements

### Performance

- The card page, the Move copies page and the locations page run a fixed number of queries whatever the number of lots or locations (the locations page's counts are one grouped query; the refusal page's list is one query of at most 100 rows plus the totals). The plan measures them with 500 locations and 5,000 lots.
- The export reads each lot's location name in the one statement that reads the lots.
- Spec 028's and 025's bars hold for 50,000 lots in 500 locations (AC-11.12).
- The migration touches the lots table once and changes no value.

### Security

- Every query of locations and lots goes through `Current.account`; another account's location answers 404 (decision 6).
- Strong parameters (`params.expect`): the location and the copies are the only new parameters; `account_id` is never mass-assigned.
- Names are output escaped like any other text.
- Protect against forgery as every form does; moving and removing are not GETs.

### Reliability

- A move changes two lots in one transaction; a lost race on the unique index retries once and merges, as `Lot.add!` does.
- A location can't be deleted while a lot is in it, in the application and in the database (AC-5.5).
- The migration is safe to run unattended from any prior version: it adds one empty column, an index and a foreign key that refuses deleting a location a lot is in, and changes no value. Rolling it back while any lot is in a location is refused with a message that says why; with none, it is clean.
- Applying places is part of spec 028's all-or-nothing transaction (AC-11.10).

### Cost per account (hosted-door rule 4)

One integer per lot, and one index entry: about 16 bytes a lot, so about 80 KB for a 5,000-lot collection and 0.8 MB for 50,000. No new table, background work, cache entry or job. An export grows by `"location":null,` (16 bytes) per unplaced lot or the field name and the value (typically under 50 bytes; at most about 195 bytes for 60 CJK characters) per placed lot. AC-11.12 measures 50,000 lots in 60-character locations against the 32 MB limit on an import (`CollectionImport::MAX_BYTES`).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Add, edit or move names another account's location, or a missing one | 404, nothing changes (AC-1.7, AC-2.7, AC-3.9) |
| Add, edit or move would make a lot of more than 9,999 | 422, "One lot can hold at most 9,999 copies.", nothing changes (AC-1.5, AC-2.4, AC-3.6) |
| Move: Copies is 0, negative, above the quantity or text | 422, "Choose from 1 to <quantity> copies." (AC-3.7) |
| Move to the place the lot is in | 422, "Those copies are already there." (AC-3.7) |
| A move's second write fails | Both lots unchanged (AC-3.8) |
| Remove a location that holds lots | Refusal page with the counts and the list; `DELETE` answers 409 (AC-5.2, AC-5.4) |
| A lot moves into a location while its confirmation page is open | 409, nothing removed (AC-5.5) |
| Move copies when no other place exists | Page says "You have no locations yet." (AC-3.10) |
| Bulk Undo whose location is gone | Lots come back unplaced; the notice says how many (AC-7.5) |
| Typed or scanner line whose lot merged away | No longer undoable (AC-7.6) |
| Version 3 file, a lot's location isn't in `locations` | Problem row; the file can't be applied (AC-10.3) |
| Version 3 file, a lot has no `location` | Problem row for the lot (`required`, AC-9.8) |
| File of version 4 or higher | Refused as newer: "This instance reads version 3." (AC-10.1) |
| Version 1 or 2 file, account has placed lots | Previewed; placed lots reported removed, the removal confirmed (AC-10.4, AC-11.4) |
| A lot moved or a location changed between preview and apply | 409, fresh preview, nothing written (AC-11.6, AC-11.7) |
| A write fails during the apply | The whole transaction rolls back (AC-11.10) |
| Delete a user whose account has placed lots | The lots go first, then the locations; it succeeds (AC-6.6) |
| A lot is added into a location while it is removed | 404 or 409, never 500 (AC-6.7) |
| Roll back the migration with placed lots | Refused with a message (Reliability) |
| Signed-out visitor | Sent to sign in; a write with no session fails forgery protection (AC-6.5) |

## Open Questions

The details P1–P6 are proposed and wait for the maintainer's confirmation, which comes with approving the spec; the plan starts after the approval. None of them changes decisions 1–7. No `[NEEDS CLARIFICATION]` marker remains.

## Out of Scope (Future Considerations)

- The location on tiles and rows (#46), the filter (#47), "Move to…" on many lots (#48), decks as locations (#49), "Free to use" (#50).
- A location in typed entry (#51) and at the scanner (#56).
- Currency per account (#64), which extends the export after version 3.
- Moving copies between accounts, or a household's shared places (ADR 0017).
- A per-location value or a location's own notes.

## Documents that change

- A new ADR (numbered when written: the next free number on `origin/main`'s `docs/adr`; 0025 unless taken, and #103 expects one too): the location joins the lot's identity, with the options of decision 1, and the format's version 3. It supersedes ADR 0019's open question and ADR 0023's sentence on deleting a location. ADR 0019's and ADR 0023's Status lines get pointers, and `docs/adr/README.md`'s index a line.
- `docs/export-format/README.md`: version 3 (lot `location`, six-value identity, `unknown_location`, `duplicate_lot`, "The same collection", the expected-changes sentence, Coverage with `lots.location_id`, the version history, the Examples rule list); `docs/export-format/v3.schema.json`, its examples (valid, invalid with `problems.json`, comparison) and `app/models/export_format/v3.schema.json`, byte-identical.
- `docs/roadmap.md`: item 10 done with this spec and its pull request; item 9's pointer.
- `docs/design-system/`: a doc for the Location column, the Move copies page and the refusal page if they are new patterns, listed in the README's app additions.
- `docs/architecture/`: the area docs for collection and lots and for data portability, once they exist (spec 027); until then `CLAUDE.md` gains a line on lots in locations and export format version 3.
- `docs/specs/README.md`: this spec's row and the supersessions above, in both directions.
- `README.md`, if it describes the export's version or what a collector can record.
