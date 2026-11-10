# Feature 059: Open a Location's Lots in Bulk Mode from Its Refusal Page

**Status:** Approved by the maintainer (2026-11-10, Gate A, relayed by the coordinator) at 0.2.0, keeping the label "Move them in bulk mode"
**Version:** 0.2.0
**Created:** 2026-11-10
**Last Updated:** 2026-11-10
**Depends on:** [spec 006](../006-collection-list-view/spec.md) (bulk mode, the selection, `Edit many` as a button), [spec 029](../029-manage-locations/spec.md) (locations), [spec 032](../032-lot-in-a-location/spec.md) (the removal refusal page), [spec 037](../037-filter-collection-by-location/spec.md) (the location filter and the selection tied to it), [spec 041](../041-move-many-lots/spec.md) (Move to…)
**Branch:** `059-bulk-mode-from-location-refusal`
**Issue:** [#187](https://github.com/plainprogrammer/Collector/issues/187) (roadmap item 14c, theme: locations)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.0 | 2026-11-10 | Spec reviews (Opus, read-only), round 1: 13 findings, all taken (the count line "12 of <total> items"; spec 006 FR-4 superseded; `restart!` gains an `all:` keyword; the core guard's file list; AC-2.6 and the empty-collection edge, AC-2.6a; button order and accessible name; index pointers both ways; citations); round 2: APPROVE, 2 minors taken. Approved by the maintainer at Gate A |
| 0.1.0 | 2026-11-10 | First draft from issue #187, specs 006, 032, 037 and 041 (decision 5) and the area doc `collection-and-lots.md`; the maintainer ruled decisions 1 and 2 as recommended |

---

## Problem Statement

A location that holds lots refuses removal: "“Blue binder” holds 12 copies in 3 lots. Move them before removing it." (spec 032 decision 3). Spec 041 gave the collector the way to empty it: filter the collection to the location (spec 037), press `Edit many`, select every matching lot and choose "Move to…". The refusal page itself stayed as it was, and spec 041 decision 5 left a shortcut on it to a separate outcome. Today the collector reads the refusal, goes to the collection, chooses the location in the Location filter, presses Filter, presses `Edit many`, ticks the header and presses "Move to…": six steps between the sentence that says what to do and the action that does it, five of which the shortcut replaces.

This spec adds one button to the refusal page. It opens the collection's bulk table filtered to that location with every matching lot selected, so "Move to…" is one press away. It adds no data a collector owns and no new working state: the selection and its location filter exist since specs 006 and 037.

**Outcome (issue #187):** from a location's removal refusal page, a collector opens bulk mode filtered to that location in one step, ready to use Move to….

> **Terms.** *Lot*, *location*, *place*, *selection*, *every matching lot*, *bulk mode* and *bulk table* are as in the [area doc](../../architecture/collection-and-lots.md), spec 006 and spec 037. The *refusal page* is the page `GET /locations/:id/removal/new` and a refused `DELETE` (409) render for a location that holds lots (spec 032 AC-5.2–AC-5.5). The *shortcut* is the button this spec adds to it.

## Goals

- A collector on the refusal page presses one button and is in bulk mode, filtered to that location, with every lot in it selected.
- The shortcut is exactly the sequence spec 041 decision 5 described (filter, `Edit many`, select every matching lot), so everything after it is bulk mode as it is: "Move to…", Set condition and Remove work unchanged.
- It is a button that changes state, so it is a POST and never a link (spec 006 FR-1, AC-1.10).

## Non-Goals

- A shortcut from the locations page's rows, the collection page or anywhere but the refusal page.
- Moving anything itself. The shortcut selects; the collector still chooses the destination on the Move to… page (spec 041).
- Removing the location afterwards. The collector returns to the locations page and removes it as before (spec 029 Story 3).
- Any change to the refusal page's sentence, its list of lots, "and N more" or "Back to locations" (spec 032 P1).
- A shortcut for the empty location's removal page: it has nothing to open.
- Any change to the export format, its version, the schema or the import (decision 6).

## Decisions

Decisions 1 and 2 were ruled by the maintainer on 2026-11-10 as recommended (relayed by the coordinator); decisions 3 to 6 were put to the maintainer with them (the route design is "fine to carry into the spec for review") and stand as written.

### 1. Every matching lot is selected (ruled by the maintainer, 2026-11-10)

The shortcut stores a selection that is "every matching lot" under the location, with no exceptions, the state the header checkbox makes, so the bulk bar reads "All 12 items selected" and "Move to…" works at once. Spec 041 named the steps this replaces as "filtering the collection to that location, pressing `Edit many`, selecting every matching lot", and the issue says "ready to use Move to…".

Alternative: leave nothing selected, as `Edit many` does (spec 006 AC-4.2), and let the collector tick the header. Rejected as the default: it saves four of the six steps and leaves the one (ticking the header) that every use of the shortcut needs. Selecting everything is not destructive: Remove asks for confirmation on its own page, and the removal of a lot is the only bulk action with an Undo (spec 006 FR-6).

### 2. The button says "Move them in bulk mode" (ruled by the maintainer, 2026-11-10)

"Move them in bulk mode" names the next step and echoes the sentence above it ("Move them before removing it"), in sentence case (design system, Voice). It is a `c-btn c-btn--primary`, the page's one primary action, first in the actions row and followed by "Back to locations" (`c-btn--secondary`), as the empty location's confirmation page puts its action first and the way back after it (`ConfirmPage`). Like the locations list's "Rename" and "Remove", it carries a visually hidden tail naming the location (`<span class="c-sr"> from “Blue binder”</span>`), so its accessible name, "Move them in bulk mode from “Blue binder”", reads on its own in a list of buttons. "Bulk mode" is not in any user-facing copy today (the screen says "Edit many" and "Bulk actions"); the ruled label brings the term into the UI, which this decision accepts.

Alternatives: "Open in bulk mode" (says where, not what for) and "Edit these lots" (says nothing about moving, and the page's job is to get the lots moved).

### 3. It starts a fresh selection, as `Edit many` does

The shortcut is a POST to a nested resource of the location, `POST /locations/:location_id/selection` (`Locations::SelectionsController#create`, spec 059's one new route), which finds the location through `Current.account` (another account's is 404), replaces the session's stored selection with a new one under no name filter, the location's id as its canonical filter string (spec 037 decision 1) and the default sort, with every matching lot selected, and answers 303 to `/collection?bulk=1&location=<id>`. It reuses `BulkSelection#restart!`, the one way a selection starts, so `Edit many` and the shortcut can't diverge: `restart!` gains a keyword (`all: false` by default, which is what `Edit many` and every other caller get) that sets "every matching lot" inside its own transaction, so a crash can't leave the location filter stored with nothing selected. Its comment says so in the same commit (`.claude/rules/code-documentation.md`).

It takes no parameters but the location in the path: no name filter, sort, account or user value is read.

### 4. The collection page it lands on is bulk mode as it is

The page is the bulk table (spec 006 Story 4) with the Location filter showing the location, the count line (the location's copies of the account's total: "12 of 40 items"), "All 12 items selected", and the bulk bar offering "Set condition…", "Move to…" and "Remove". Nothing about bulk mode changes. A location that was emptied between the refusal page and the press (another tab moved its lots) lands on the bulk table's empty-filter sentence with "0 of 0 selected" and no header checkbox (spec 037 AC-1.6, AC-5.4; spec 006 AC-5.9), or, when that left the account no lot at all, on the empty collection's page (spec 004 AC-11.6; spec 006 Error Scenarios); the collector goes back and removes the location.

### 5. Both ways to the refusal page get the button

The page is one view for `GET /locations/:id/removal/new` and for the 409 a refused `DELETE` renders (spec 032 AC-5.2, AC-5.4); both show the button. The button is not on the locations list: the list's rows keep "Rename" and "Remove" (spec 029).

### 6. No collector-owned data, no export change

The selection is working state (a `bulk_selections` row, deleted by `Done`, the session's end and an import apply); nothing new is stored and the export is unchanged (format version 3). The format document, its version and the schema are unchanged.

## Supersedes

- **Spec 041 decision 5**, its Non-Goal "A button on a location's refusal page that opens its lots in bulk mode" and its Out of Scope entry for "the refusal page's shortcut into bulk mode (#187)": met by this spec. The refusal page is no longer unchanged.
- **Spec 006 FR-4** (and Story 4's `Edit many` as the only way into bulk mode) where it lists the submissions that start, change or clear a selection (`Edit many`, `Done`, the bulk form): the shortcut is a second way to start a selection, always an empty-then-filled one under a location, replacing any stored one as `Edit many` does. The bulk table it opens is unchanged.
- **Spec 032 AC-5.2 and AC-5.4** where they list the refusal page's controls as "Back to locations" and no Remove button: the page also has the shortcut.

## Documents that change

| Document | Change |
|---|---|
| [`docs/architecture/collection-and-lots.md`](../../architecture/collection-and-lots.md) | The locations table's "holding lots / Remove" row and the paragraph after it ("a shortcut from the refusal page is #187"); the Glossary's *Bulk mode* ("entered with `Edit many`") and the Bulk mode section's opening ("`Edit many` clears any stored selection …"), which gain the shortcut as a second way in; the invariant on prefetch (the shortcut is a POST, never a link); Accepted limits (#187 leaves); Sources; Distillation log |
| [`docs/design-system/components/Locations.md`](../../design-system/components/Locations.md) | The refusal page's actions: the primary button first, "Back to locations" after it, the form and the hidden tail |
| [`docs/specs/README.md`](../README.md), [`docs/roadmap.md`](../../roadmap.md) | This spec's row and the "Superseded by" pointers on rows 006, 032 and 041 (written with the spec); item 14c |
| [`CLAUDE.md`](../../../CLAUDE.md) | The status paragraph's locations sentence (the refusal page's shortcut) |
| Specs 006, 032 and 041 | Not edited; the index records the supersessions above |

## Users and Context

A collector emptying a location before removing it: they pressed "Remove" on the locations page and read the refusal. They are on a desktop or a phone, with or without scripting. The account has at least the location they are on, so "Move to…" is offered.

## User Stories

### Story 1: The button on the refusal page

As a collector told to move a location's lots first, I want a button that takes me to them in bulk mode.

- [ ] **AC-1.1** Given a location that holds lots When `GET /locations/:id/removal/new` renders its refusal page Then, after the list of lots and "and N more", the actions row holds a "Move them in bulk mode" button first and "Back to locations" after it, and there is still no Remove button.
- [ ] **AC-1.2** Given a location that holds lots When a `DELETE /locations/:id` is refused with 409 Then the refusal page it renders has the same button.
- [ ] **AC-1.3** Given an empty location When its removal confirmation page renders Then it has no such button.
- [ ] **AC-1.4** Given the refusal page When it renders Then the shortcut is a `<button>` in a `form` with `method="post"` to `/locations/:id/selection`, not a link, and carries no other field than the CSRF token (spec 006 FR-1, AC-1.10).
- [ ] **AC-1.5** Given the refusal page When the sentence, the lot list, "and N more" and "Back to locations" render Then they are as spec 032 AC-5.2, AC-5.3 and P1 define them.

### Story 2: It opens bulk mode on that location

As a collector, I want to land in bulk mode with the location's lots selected.

- [ ] **AC-2.1** Given a location holding 12 copies in 3 lots When the collector presses the button Then the answer is 303 to `/collection?bulk=1&location=<id>`, and the page shows the bulk table filtered to that location: its 3 lots, the Location filter showing the location, and the count line "12 of <total> items" (for an account whose collection holds 40 copies, "12 of 40 items").
- [ ] **AC-2.2** Given AC-2.1 When the table renders Then every row is ticked, the header is ticked and the bar reads "All 12 items selected".
- [ ] **AC-2.3** Given AC-2.1 When the bar renders Then it offers "Set condition…", "Move to…" and "Remove" as in any bulk table of an account with a location (spec 041 AC-1.1), and pressing "Move to…" opens the move page for "Move 12 items" without ticking anything first, with the location itself not offered as a destination (spec 041 AC-2.1).
- [ ] **AC-2.4** Given the session already has a stored selection, under any name filter, location and sort When the collector presses the button Then that selection is replaced by the new one: nothing of the earlier ticks remains.
- [ ] **AC-2.5** Given the session has an undoable bulk removal When the collector presses the button Then the removal can still be undone (the shortcut removes nothing).
- [ ] **AC-2.6** Given the location was emptied after the refusal page rendered When the collector presses the button Then the answer is the same 303, and the bulk table shows "No cards in your collection are in “<name>”." with "0 of 0 selected" and no header checkbox (spec 037 AC-1.6, AC-5.4; spec 006 AC-5.9), or, if the account then holds no lot at all, the empty collection's page (spec 004 AC-11.6; spec 006 Error Scenarios).
- [ ] **AC-2.6a** Given the location was removed after the shortcut answered but before the bulk table loaded When the table loads Then it reads the location as all locations, 200, with the whole collection in bulk mode and nothing selected, because the stored selection's location no longer matches (spec 037 decision 7, AC-6.2); never a 500.
- [ ] **AC-2.7** Given the bulk table the shortcut opened When the collector presses `Done` Then the selection is deleted and they return to the saved view filtered to the location (spec 006 AC-4.5; spec 037), nothing else changed.

### Story 3: Emptying the location, end to end

As a collector, I want the refusal page to be where emptying starts and removing the location to be where it ends.

- [ ] **AC-3.1** Given a location holding lots and another location When the collector presses "Remove" on the locations page, then "Move them in bulk mode", then "Move to…", chooses the other location and presses "Move" Then the lots are in the other location, the notice reads "Moved <n> items to <name>.", and the location's removal page is now the confirmation page, which removes it. (A system spec covers it from the locations page to the removal.)

### Story 4: Only my locations

As a collector on a shared instance, I want the shortcut never to reach another account.

- [ ] **AC-4.1** Given another account's location id When `POST /locations/:id/selection` is requested Then the answer is 404 and no selection is created or changed for either account.
- [ ] **AC-4.2** Given a location id that does not exist (removed meanwhile) When the shortcut is requested Then the answer is 404.
- [ ] **AC-4.3** Given the request When it carries an account, user, admin, name filter, location or sort value Then none is used: the selection's location is the path's, its name filter is empty and its sort is the default (spec 006 AC-8.4).
- [ ] **AC-4.4** Given a signed-out visitor, with a valid CSRF token, When they request the shortcut Then they are sent to sign-in and nothing is created, as for every other signed-in page (spec 004).
- [ ] **AC-4.5** Given `GET /locations/:id/selection`, marked as a prefetch or not When it is served Then no route answers it (404) and no selection, lot or record changes (spec 006 FR-1, AC-1.10). The shortcut is a form button because a prefetch only follows links.

### Story 5: Without scripting, and on a phone

- [ ] **AC-5.1** Given a browser without scripting When the collector presses the button Then the bulk table opens with every lot selected, as with scripting.
- [ ] **AC-5.2** Given a viewport of 360px When the refusal page renders Then the button and "Back to locations" fit without horizontal scrolling, each at least 44px by 44px (the design system's touch floor), and both themes keep the text and focus ring contrast the design system sets.

## Functional Requirements

### FR-1: The route

**Must:**
- Provide `POST /locations/:location_id/selection`, handled by `Locations::SelectionsController#create`, and no other verb or route for it.
- Find the location only through `Current.account.locations` (404 otherwise) and require sign-in as every page of the app does.
- Start the session's selection with `BulkSelection#restart!` under an empty name filter, the location's canonical filter string and the default sort, selecting every matching lot in the same transaction through the keyword decision 3 adds (decision 1), and answer 303 to `collection_listing_path(bulk: 1, location: …)`.

**Must not:**
- Read any parameter but the location id from the path.
- Change a lot, a location or an undo record, or answer a GET.

### FR-2: The view

**Must:**
- Put the button, a `c-btn c-btn--primary`, in the refusal page's `c-form__actions`, as the page's only primary action, in a post form with no field but the CSRF token; use only design-system tokens and `c-*` classes, and update `Locations.md` with the new control.
- Word it as decision 2 says, in sentence case, with no collectible's name in it.

**Must not:**
- Make it a link, or add it to the locations list's rows.

### FR-3: The core names no collectible

**Must:** keep the new controller and the view's change free of any collectible's vocabulary, and add the controller (`app/controllers/locations/selections_controller.rb`) to the fixed file list of `spec/import_apply_core_spec.rb`, which checks each named file and would not see it otherwise.

## Non-Functional Requirements

### Performance

- The shortcut does a constant number of statements (a find and the selection's restart, flag included), independent of the number of lots; the bulk table it lands on is spec 006's, within its existing budget.

### Accessibility

- The button has an accessible name that reads on its own ("Move them in bulk mode from “Blue binder”", decision 2), is keyboard operable with a visible focus ring, and the landing page's "All 12 items selected" is announced as bulk mode's count line already is (spec 006 NFR).

### Security

- Every lookup goes through `Current.account`; another account's location is 404; CSRF protection stays on; no field is read.

### Reliability

- A concurrent change (the location emptied or removed after the page rendered) is a 303 to an empty table or a 404, never a 500.

### Cost per account (hosted-door rule 4)

- No new storage and no background work beyond the existing `bulk_selections` row of the session. The operator sees nothing of it (hosted-door rule 2).

## Error Scenarios

| Situation | Answer |
|---|---|
| Another account's location, or a removed one | 404, nothing changed |
| Signed out | Redirect to sign-in, nothing changed |
| The location was emptied after the page rendered | 303 to the bulk table under the location: the empty-filter sentence, "0 of 0 selected" (the empty collection's page if no lot is left, AC-2.6) |
| The location was removed after the 303 | The table under all locations, nothing selected, 200 (AC-2.6a) |
| `GET` of the shortcut's path | No route (404) |
| The session has a stored selection | Replaced, as `Edit many` replaces it |

## Open Questions

- None. Decisions 1 and 2 were ruled by the maintainer on 2026-11-10.

## Out of Scope

- A shortcut from the locations list, the collection page or the card page; "Move to…" itself; removing the location in the same step; partial lots in bulk; decks as locations ([#49](https://github.com/plainprogrammer/Collector/issues/49)).
