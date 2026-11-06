# Feature 041: Move Many Lots at Once

**Status:** Approved by the coordinator under the maintainer's delegation (2026-11-06) at 0.4.0; decisions 1, 2, 3 and 5 were ruled by the maintainer on 2026-11-06 as recommended
**Version:** 0.4.0
**Created:** 2026-11-06
**Last Updated:** 2026-11-06
**Depends on:** [spec 006](../006-collection-list-view/spec.md) (bulk mode, the selection, Set condition), [spec 032](../032-lot-in-a-location/spec.md) (a lot's place, Move copies; ADR 0025), [spec 037](../037-filter-collection-by-location/spec.md) (the location filter and the selection tied to it)
**Branch:** `041-move-many-lots`
**Issue:** [#48](https://github.com/plainprogrammer/Collector/issues/48) (roadmap item 13, theme C: locations)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.4.0 | 2026-11-06 | Third spec review (Fable, read-only), all 8 findings taken: the To field's values (`""` the prompt, `none`, a location id; decision 6, AC-2.1); decision 6 (3)'s wording; the GET answer in Error Scenarios; FR-3's refusals; the performance allowance and AC-4.4's fixture; AC-6.1 without scripting, the keyboard a manual check; Documents that change completed; AC-1.7's selection under All locations |
| 0.3.0 | 2026-11-06 | Second spec review (Fable, read-only), all 11 findings taken: one order of answers for the move page (decision 6, AC-1.2, AC-1.6, AC-1.7, AC-2.3); spec 037's bulk-action lists superseded both ways; the To field is required and omits the selection's own place (AC-2.1, AC-2.2); the key builder is the plan's choice with its parity owed (FR-2); the nearest real page; some selected lots gone; refusals keep the selection; an excepted lot a merge reaches becomes selected; keyboard and accessibility; AC wording |
| 0.2.0 | 2026-11-06 | First spec review (Fable, read-only), all 14 findings taken: a selected lot already there is the destination's lot of its identity (decision 3, AC-3.12); AC-4.1's merge exception; the selection after a move under a location filter restarts (decision 6, AC-3.9, AC-3.13, Error Scenarios); Documents that change; the supersessions of 006 AC-4.4 and FR-5's Must and 032 decision 5, FR-2, AC-5.6 and its Non-Goal; scanner entries; the cap names a selected lot; the account without locations (AC-1.7); the no-location notice; the merge survivor; times; FR-2's wording; names unquoted as Move copies; the move page is a Form |
| 0.1.0 | 2026-11-06 | First draft from issue #48, specs 006 (Stories 4–6, FR-4, FR-5), 032 (decisions 1, 3, 4, Story 3) and 037, ADR 0025 and the area doc `collection-and-lots.md`; the maintainer ruled decisions 1, 2, 3 and 5 as recommended |

---

## Problem Statement

Spec 032 put each lot in a location and gave the card page a Move copies form for one lot at a time. Spec 037 lets a collector list what is in one place, or what has no place yet. Neither lets a collector act on that list: filing a new box of 200 cards into "Blue binder", or emptying a location before removing it, takes one card page and one Move per lot. Spec 032 named this cost ("a location with many lots takes one move per lot") and left it to #48; spec 006 deferred the "Move to…" bulk action until locations existed.

This spec adds "Move to…" to bulk mode: the collector ticks lots (or every matching lot) and sends all their copies to one location, or to none, in one action. It adds no data a collector owns and no working state: a lot's place exists since spec 032, and the selection since spec 006.

**Outcome (issue #48):** a collector selects lots in bulk mode and moves them to a location in one action.

> **Terms.** *Lot*, *location*, *place*, *unplaced* ("No location" on screen), *identity*, *merge* and *cap* are as in the [area doc](../../architecture/collection-and-lots.md) and spec 032. *Bulk mode*, *selection*, *selected lots* and *every matching lot* are spec 006's, with spec 037's location filter in the selection's context. The *destination* is the place the collector chooses: one of the account's locations, or none. A selected lot is *already there* when its place is the destination.

## Goals

- A collector moves every copy of the selected lots to one of their locations, or to no location, from bulk mode, in one action.
- The move keeps every lot rule: the identity includes the place, lots that reach one identity merge, the 9,999 cap holds, all or nothing.
- It works on "every matching lot" under the name and location filters, so "everything in Long box" can go to "Blue binder" at once.
- A collector with no locations sees bulk mode exactly as it is.

## Non-Goals

- Moving part of a lot's copies in bulk. Move copies on the card page does that for one lot (spec 032 Story 3; decision 2).
- An Undo for the move (decision 1).
- Creating a location from the move page. The locations page adds them (spec 029).
- A button on a location's refusal page that opens its lots in bulk mode (decision 5).
- "Move copies" in the table's row menu (spec 032 AC-3.1 keeps it on the card page).
- Any change to the export format, its version, the schema or the import (decision 7).
- Lend, Update prices and the other bulk actions spec 006 deferred.

## Decisions

Decisions 1, 2, 3 and 5 were ruled by the maintainer on 2026-11-06 as recommended; decisions 4, 6 and 7 were put to the maintainer with them and stand as written.

### 1. No Undo (ruled by the maintainer, 2026-11-06)

The move has no Undo, as Set condition has none (spec 006: only the destructive bulk action has an Undo). A move loses no copy: every copy is still in the collection, and moving the same lots back puts them where they were, except that lots merged by the move stay merged. The session's bulk removal Undo is unaffected by a move (decision 6).

Alternative: a single-use Undo of the session's last move, kept as a working-state record like the bulk removal's. Rejected: it needs a new table, its own supersession rules and its own cap check on the way back, for an action that destroys nothing.

### 2. Whole lots only (ruled by the maintainer, 2026-11-06)

Every copy of each selected lot moves. The bulk table already selects lots, not copies, and a copy count per lot would need a field per row, which the no-script form can't carry without becoming a second table. Part of a lot still moves with Move copies.

### 3. Lots already there are left alone (ruled by the maintainer, 2026-11-06)

A selected lot already in the destination stays where it is and doesn't block the others. Its copies are counted as already there, never as moved. It is still the destination's lot of its identity: when another selected lot of that identity moves in, it gains those copies and survives (decision 4), and its quantity counts in the cap check. The notice counts the copies that moved and, when any were already there, says how many. Only when every selected lot is already there is the move refused (422), so a collector learns that nothing happened.

Alternative: refuse the whole move when any selected lot is already there. Rejected: under "All locations", "every matching lot to Blue binder" would always be refused for a collector who has anything in Blue binder.

### 4. Merges and the cap work as in Set condition and Move copies

Moving a lot changes its identity's place, so (ADR 0025, spec 032 decision 1):

- a moved lot whose identity (printing, finish, condition, price paid) already has a lot in the destination, selected or not, merges into that lot, which survives with the summed quantity (as Move copies' "All, Yes" row, spec 032 P6);
- two or more selected lots of one identity in different places that move to a destination where the identity has no lot become one lot holding their sum; the first of them in the bulk table's order survives and the others are removed;
- a moved lot that meets no other lot of its identity in the destination stays the same lot (same id), with its new place (as Move copies' "All, No" row).

Times follow Move copies (spec 032 P6, the area doc's Move copies table): a lot that moves keeps its added time and its changed time becomes the move's; a surviving lot keeps its added time.

All or nothing: if any resulting lot would hold more than 9,999 copies, nothing moves, and the refusal names the first *selected* lot of an over-cap identity in the bulk table's order (an unselected destination lot may not be in the table), in the words of Set condition's refusal: "Nothing moved. <name> (<SET> · <number>) would have more than 9,999 copies in one lot." (spec 006 AC-6.4; spec 032 AC-7.3).

Messages name a location without quotation marks, as Move copies' notice and number entry's do ("to Blue binder"; spec 032 AC-3.2; spec 034 decision 3).

### 5. The locations refusal page is unchanged (ruled by the maintainer, 2026-11-06)

A location that holds lots still refuses removal with its list and "Move them before removing it." (spec 032 decision 3). With this spec a collector empties it by filtering the collection to that location (spec 037), pressing `Edit many`, selecting every matching lot and choosing "Move to…". A button on the refusal page that does the first three steps at once is a separate outcome, [#187](https://github.com/plainprogrammer/Collector/issues/187).

### 6. The rest of bulk mode and the working state

- "Move to…" is a bulk action like Set condition: it records the page's ticks first, is refused on the bulk table with "Select at least one item." or "None of the selected items are in your collection any more." (spec 006 FR-5, AC-8.1), and opens its own page.
- After a move the collector returns (303) to the bulk table they came from, with the same filters, sort and page. What stays selected depends on the location filter the selection was made under:
  - **All locations** (with or without a name filter): the moved lots still match, so the lots that now hold the moved copies are selected, a surviving merged lot too, and lots that were already there stay selected (as Set condition, spec 006 AC-6.5).
  - **A location, or "No location":** the moved lots no longer match (a move under a location filter always leaves it, since lots already there can't be the only ones moved, decision 3), so the selection restarts empty under the same filters and sort, as after Remove (spec 006 AC-7.3; spec 037 AC-5.6): the header is unticked and the bar reads "0 of <matching> selected".
- A move removes no copy, so it doesn't supersede the session's bulk removal Undo; the undo record holds no lot ids (spec 006 FR-6).
- A number-entry line or a scanner entry whose lot is merged away by a move reads as changed ("Changed in your collection"), as after Move copies (spec 032 AC-7.6); a line whose lot moves without merging names its new place (spec 034 decision 3).
- The move page is a `Form` page with one select, as the Move copies page is (`docs/design-system/components/Form.md`), not a `ChoicePage`: an account may have up to 500 locations.
- An account with no location has nothing to move to: the bulk bar doesn't offer "Move to…".
- **The To field's values.** The prompt submits `""`, which is "no destination chosen" (AC-2.2); "No location" submits `none`, the location filter's word for it (spec 037 decision 1); a location submits its id. (Move copies submits "No location" as `""`; here `""` must be the prompt so the browser's required check refuses it.)
- **The order of answers.** The move page, requested or submitted, answers by the first that holds: (1) a GET with no selection, or a selection with no lot left: 303 to the bulk table with "Select at least one item." (as `BulkSelected` does for Set condition); (2) the account has no location: 303 to the bulk table with the alert "You have no locations yet." (spec 032 P3's words), whatever destination was submitted; (3) a submission whose selection selects no lot (its lots gone, restarted empty after a move or a removal, or no selection in the session): 422 on the move page with "None of the selected items are in your collection any more."; (4) no destination chosen: 422, AC-2.2; (5) a destination value that is neither `none` nor one of the account's location ids: 404; (6) the move (FR-2), with its own refusals (AC-3.7, AC-3.8). Every refusal keeps the selection as it was.

### 7. No collector-owned data, no export change

Nothing new is stored: the move changes lots' places, which the export already carries (format version 3). The format document, its version and the schema are unchanged.

## Supersedes

- **Spec 006 FR-5**: its Must not "Offer or perform Move to…", and its Must "Provide Set condition and Remove on the selected lots" (Move to… joins them); its Non-Goal and Out of Scope entries for "Move to…". Superseded for "Move to…" only; Lend and Update prices stay deferred.
- **Spec 006 AC-4.4**: the bulk bar's actions are "Set condition…", "Move to…" (while the account has a location) and "Remove".
- **Spec 032 decision 3**, "Known cost until #48", **decision 4**'s "many lots at once is #48", **AC-5.6**'s "one lot at a time, until #48", its Non-Goal and Out of Scope entries for "Move to…": met by this spec; Move copies keeps working on one lot from the card page.
- **Spec 037 decision 5, AC-5.2, AC-5.3, AC-5.6**: their lists of bulk actions (Set condition and Remove) gain Move to…; after a move under a location filter the selection restarts under the same location, as after Remove.
- **Spec 032 decision 5** and **FR-2**'s Must not "Change … the bulk bar", for the bulk bar only: bulk mode gains an action that chooses a place. The grid, table, quick add and Set condition are unchanged.

## Documents that change

| Document | Change |
|---|---|
| [`docs/architecture/collection-and-lots.md`](../../architecture/collection-and-lots.md) | Scope's bulk mode line; the Glossary (*destination*, *already there*); the invariant listing every way that merges (the move joins `Lot::Move` and `Lot::ConditionChange`); the measured bars (the move's 2 seconds); the invariant "Four places build a key" if the move adds a key builder (FR-2); the invariant on which ways of adding choose a place (bulk Move to… does); a "Move to…" paragraph in Bulk mode; the locations section's "Until "Move to…" (#48)"; Decisions not in an ADR ("Move copies works on one lot…"); Accepted limits (#48 leaves, its sort half stays as spec 037 Non-Goals); Named constants for the new messages; Sources; Distillation log |
| [`docs/architecture/data-portability.md`](../../architecture/data-portability.md) | None: no new data or working state (decision 7) |
| [`docs/design-system/components/BulkForm.md`](../../design-system/components/BulkForm.md) | Its markup and list of the bulk bar's buttons gain "Move to…"; `CollectionTable.md` already names it |
| [`docs/design-system/components/Form.md`](../../design-system/components/Form.md) | A line for a required select whose blank first option is a "Choose…" prompt, not "Not specified" |
| [`docs/specs/README.md`](../README.md), [`docs/roadmap.md`](../../roadmap.md) | This spec's row and the supersession pointers on rows 006, 032 and 037; item 13 |
| [`CLAUDE.md`](../../../CLAUDE.md) | The status paragraph (bulk Move to…); its "four places build a `lot_key`" sentence if the move adds a key builder (FR-2) |
| Specs 006, 032 and 037 | Not edited; the index records the supersessions above |

## Users and Context

A collector filing or reorganising a physical collection: unpacking a box into a binder, emptying a location before removing it, or giving every unfiled card a place (spec 037's "No location" filter finds them). They work in the collection's table on a desktop or a phone, with or without scripting. The account has at least one location; one without locations has nothing to move to.

## User Stories

### Story 1: Choose "Move to…" in bulk mode

As a collector in bulk mode, I want a "Move to…" action beside Set condition.

- [ ] **AC-1.1** Given an account with at least one location in bulk mode When the bulk bar shows Then it offers "Move to…" after "Set condition…" and before "Remove", in the bar and in its "More bulk actions" menu in the same order.
- [ ] **AC-1.2** Given an account with no location in bulk mode When the bulk bar shows Then it offers no "Move to…"; a bulk submission that asks for the move records the page's ticks and answers as a bulk navigation does: 303 to the bulk table, nothing moved.
- [ ] **AC-1.3** Given lots ticked on the page When the collector presses "Move to…" Then the ticks are recorded and the move page opens (303), as for Set condition (spec 006 FR-4).
- [ ] **AC-1.4** Given nothing selected When the collector presses "Move to…" Then the bulk table re-renders with 422 and "Select at least one item.", nothing changed.
- [ ] **AC-1.5** Given a selection whose lots are all gone (removed in another tab) When the collector presses "Move to…" Then the bulk table re-renders with 422 and "None of the selected items are in your collection any more."
- [ ] **AC-1.6** Given no selection in the session When the move page is requested with GET Then it redirects (303) to the bulk table with "Select at least one item.", as the Set condition page does.
- [ ] **AC-1.7** Given an account whose last location was removed after the bulk bar rendered, with lots selected under All locations When the move page is requested or submitted, with any destination Then the answer is 303 to the bulk table with "You have no locations yet.", nothing changes and the selection is kept (decision 6, the order of answers).

### Story 2: Choose where they go

As a collector, I want to pick the destination on its own page and see how many items will move.

- [ ] **AC-2.1** Given a selection of 12 copies in 4 lots When the move page opens Then its heading reads "Move 12 items" ("Move 1 item" for one copy) and its required To field offers a "Choose…" prompt (selected), "No location", then the account's locations in the locations page's order, with a "Move" button and a "Cancel" link back to the bulk table on the same page. The selection's own place is not offered: under a location filter that location, under "No location" that option (every selected lot is already there, as Move copies leaves out the lot's own place, spec 032 AC-3.1); under "All locations" every place is offered.
- [ ] **AC-2.2** Given the move page When it is submitted with no destination chosen (the browser refuses it first; the server is the backstop) Then it re-renders with 422 and "Choose where to move them." on the To field, nothing changed and the selection kept.
- [ ] **AC-2.3** Given the move page When it is submitted with a location id that is another account's, or one removed since the page opened Then the answer is 404, nothing changes and the selection is kept (spec 032 decision 6, AC-6.7), while the account still has a location (decision 6, the order of answers).
- [ ] **AC-2.4** Given the move page When it renders, also as a refusal Then the appbar's Back and Cancel return to the bulk table with its filters, sort and page.

### Story 3: Move the selected lots

As a collector filing a box into a binder, I want every copy of the selected lots moved in one action.

- [ ] **AC-3.1** Given 3 selected lots (2, 5 and 1 copies) in Long box, none of whose identities has a lot in Blue binder When the collector moves them to Blue binder Then the same 3 lots (same ids) are in Blue binder with their quantities, nothing else changed, and the bulk table (303, same filters, sort and page) says "Moved 8 items to Blue binder."
- [ ] **AC-3.2** Given selected placed lots When the collector moves them to "No location" Then they become unplaced and the notice reads "Moved <n> items to no location."
- [ ] **AC-3.3** Given a selected lot of 2 copies in Long box and an unselected lot of the same identity with 3 copies in Blue binder When the selected lot moves to Blue binder Then the Blue binder lot holds 5 and survives (same id), and the Long box lot no longer exists.
- [ ] **AC-3.4** Given two selected lots of one identity, 2 copies in Long box and 4 unplaced When both move to Blue binder, where the identity has no lot Then one lot of that identity holds 6 in Blue binder, it is the one of the two that comes first in the bulk table's order (same id, with its added time), and the other no longer exists.
- [ ] **AC-3.5** Given the case of AC-3.4 and also a lot of that identity with 1 copy already in Blue binder When both move there Then the Blue binder lot survives with 7 and the two moved lots no longer exist.
- [ ] **AC-3.6** Given selected lots of which some are already in Blue binder and none shares an identity with another When they move to Blue binder Then the others move, the ones already there are unchanged, and the notice reads "Moved <n> items to Blue binder. <m> items were already there." ("1 item was already there." for one copy; for "No location": "Moved <n> items to no location. <m> items were already there.").
- [ ] **AC-3.12** Given selected lot A (2 copies) in Long box and selected lot B (3 copies) in Blue binder, of one identity When they move to Blue binder Then B holds 5 (same id), A no longer exists, the notice reads "Moved 2 items to Blue binder. 3 items were already there.", and B is selected.
- [ ] **AC-3.7** Given every selected lot is already in Blue binder When the collector moves them to Blue binder Then the move page re-renders with 422 and "The selected items are already in Blue binder." (for "No location": "The selected items already have no location."), nothing changed and the selection kept.
- [ ] **AC-3.8** Given a move whose merges would leave a lot with more than 9,999 copies When it is submitted Then the move page re-renders with 422 and "Nothing moved. <name> (<SET> · <number>) would have more than 9,999 copies in one lot.", naming the first selected lot of an over-cap identity in the bulk table's order (also when the identity's lot in the destination is unselected), no lot changed and the selection kept.
- [ ] **AC-3.9** Given a selection made under "All locations" (with or without a name filter) When a move succeeds Then the bulk table shows the lots now holding the moved copies (a surviving merged lot too) selected, and lots that were already there stay selected; a destination lot the collector had unticked as an exception becomes selected when a moved lot merges into it, as after Set condition (spec 006 AC-6.5).
- [ ] **AC-3.13** Given a selection made under a location filter (a location or "No location") When a move succeeds Then the selection restarts empty under the same filters and sort: the bulk table shows no row ticked, the header unticked and "0 of <matching> selected".
- [ ] **AC-3.10** Given lots that differ only in finish, condition or price paid When they move to one location Then they stay separate lots (only one identity merges).
- [ ] **AC-3.11** Given the session has an undoable bulk removal When a move succeeds Then the removal can still be undone.

### Story 4: Move everything a filter shows

As a collector emptying Long box, I want to move every lot in it at once.

- [ ] **AC-4.1** Given the collection filtered to Long box in bulk mode with every matching lot selected (some unticked as exceptions) When the collector moves them to Blue binder Then exactly the matching lots that are not exceptions move, resolved when the move runs, and no lot outside Long box changes except a Blue binder lot that a moved lot merges into (AC-3.3).
- [ ] **AC-4.2** Given the case of AC-4.1 When the move succeeds Then the bulk table under the Long box filter shows only the excepted lots (or the location's empty sentence), nothing selected (AC-3.13), and its count line is updated; if the page it was on no longer exists, the nearest real page shows (spec 006 AC-6.5, AC-7.3).
- [ ] **AC-4.3** Given every matching lot under a name filter and "No location" When the collector moves them to a location Then only the unplaced lots matching the name move.
- [ ] **AC-4.4** Given every matching lot of 5,000 lots selected When they move to one location Then the move completes in under 2 seconds of server time (NFR Performance), with the 5,000 lots spread over 300 locations and many of them merging into lots already in the destination.

### Story 5: Only my lots and locations

As a collector on a shared instance, I want a move never to touch another account.

- [ ] **AC-5.1** Given another account's lot ids in the bulk submission When the collector moves the selection Then those ids are ignored (spec 006 AC-8.1) and the other account's lots are unchanged.
- [ ] **AC-5.2** Given another account's location id When it is submitted as the destination Then the answer is 404 and nothing changes for either account.
- [ ] **AC-5.3** Given the move page and the move request When either carries an account, user or admin value Then it is not used (spec 006 AC-8.4).
- [ ] **AC-5.4** Given a request marked as a prefetch for the move page When it is served Then no selection, lot or record changes (spec 006 FR-1).

### Story 6: Without scripting, and on a phone

- [ ] **AC-6.1** Given a browser without scripting When the collector ticks lots, presses "Move to…", chooses a destination and presses "Move" Then the lots move and the bulk table shows the notice.
- [ ] **AC-6.2** Given a viewport below 640px When the bulk bar shows Then "Move to…" is reachable (in the bar or its "More bulk actions" menu, as the bar's design-system pattern lays it out) and the move page fits without horizontal scrolling.

## Functional Requirements

### FR-1: The action

**Must:**
- Offer "Move to…" in bulk mode while the account has at least one location; otherwise not offer it and not perform it.
- Record the page's ticks before the action, as the other bulk actions do, and refuse with the bulk table (422) when nothing is selected or nothing selected is left.
- Resolve "every matching lot" against the account's lots, the name filter and the stored location filter when the move runs (spec 006 FR-4; spec 037 decision 7).

**Must not:**
- Change any lot in response to a GET or a prefetch.

### FR-2: The move

**Must:**
- Move every copy of each selected lot that is not already in the destination; leave lots already there in place, gaining only copies that merge into them (decision 3).
- Merge into one lot every lot that reaches one identity in the destination: an existing lot of the destination survives if there is one, else the first moved lot of that identity in the bulk table's order. Keep a lot that meets no lot of its identity in the destination as the same lot (same id), with its new place.
- Change nothing when any resulting lot would pass 9,999 copies, when the destination is missing or not the account's, or when every selected lot is already there.
- Keep every key rule of the lot identity (ADR 0025) for the lots it changes: write keys through the existing key rule, or, if the plan rebuilds keys in one statement for speed (as Set condition does), count it as a fifth key builder, with a spec proving it carries the place (ADR 0025 Consequences) and the area doc's "Four places build a key" updated.
- Do the whole move in one write transaction, judged against the lots as they are inside it, so a second submit of a stale page can neither create nor lose copies.

**Must not:**
- Touch another account's lots or locations, or supersede the session's bulk removal Undo.

### FR-3: The answers

**Must:**
- Answer a successful move with 303 to the bulk table it came from (filters, sort, page, or the nearest real page), with the notice of AC-3.1, AC-3.2 or AC-3.6, pluralised ("1 item", "2 items"), and the selection of AC-3.9 or AC-3.13.
- Answer in decision 6's order: every refusal of the move page with 422 and the message in the status region as an alert, or on the To field for a missing choice, re-rendering the move page; 404 for a destination that isn't the account's; 303 with an alert for an account with no location, and for a GET without a selection. The bulk table's own refusals are FR-1's (AC-1.4, AC-1.5). Every refusal keeps the selection.

### FR-4: The core names no collectible

**Must:** keep the move's model, controller and views free of any collectible's vocabulary, as the location and Move copies files are (`spec/import_apply_core_spec.rb`).

## Non-Functional Requirements

### Performance

- Moving every matching lot of 5,000 lots, over 300 locations, completes in under 2 seconds of server time, the bar spec 006 sets for Set condition and Remove; recorded in `verification.md`.
- The move page runs a number of queries independent of the number of selected lots. The move may write one statement per lot that merges or survives a merge, and otherwise a number of statements independent of the number of selected lots; the measured bar above is what `verification.md` records.

### Accessibility

- The "Move to…" button and the move page meet spec 006's accessibility NFR: keyboard operable (the whole flow done with the keyboard alone, checked by hand and recorded in `verification.md`, as spec 006 did), visible focus, accessible names, the notice and refusals announced in the status region, the To field's error tied to it.

### Security

- Every lookup goes through `Current.account`; a foreign location is 404, foreign lot ids are ignored.
- No form takes an account, user or admin value; the destination is the only new parameter.

### Reliability

- All or nothing, in one write transaction; a catalog refresh doesn't affect a move.

### Cost per account (hosted-door rule 4)

- No new storage and no background work: a move rewrites existing lot rows and may delete merged ones. The operator sees nothing of it (hosted-door rule 2).

## Error Scenarios

| Situation | Answer |
|---|---|
| Nothing selected | 422, bulk table, "Select at least one item." |
| All selected lots gone | 422, bulk table (or the move page when it was submitted), "None of the selected items are in your collection any more."; a GET of the move page: 303, bulk table, "Select at least one item." (decision 6 (1)) |
| Some selected lots gone (removed in another tab) | The heading counted them; the move ignores them and the notice counts only the copies that moved (spec 006 Error Scenarios) |
| No destination chosen | 422, move page, "Choose where to move them." on To |
| Destination another account's, or removed meanwhile | 404, nothing changed |
| Every selected lot already there | 422, move page, "The selected items are already in <name>." / "The selected items already have no location." |
| A merge would pass 9,999 | 422, move page, "Nothing moved. <name> (<SET> · <number>) would have more than 9,999 copies in one lot." |
| Account has no location | No "Move to…"; a bulk submission asking for it is a bulk navigation; the move page, requested or submitted, is 303 to the bulk table with "You have no locations yet." (AC-1.2, AC-1.7) |
| Stale move page submitted twice | Under "All locations" the second submit finds the selected lots already there: AC-3.7. Under a location filter the selection restarted empty (AC-3.13): 422 on the move page, "None of the selected items are in your collection any more.". Nothing created or lost either way |

## Open Questions

- None. Decisions 1, 2, 3 and 5 were ruled by the maintainer on 2026-11-06.

## Out of Scope

- Partial lots in bulk, an Undo for moves, creating locations while moving, the refusal page's shortcut into bulk mode (#187), Lend and Update prices, sorting by location.
