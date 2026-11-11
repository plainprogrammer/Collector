# Feature 067: Open a Deck's Lots in Bulk Mode from Its Refusal Page

**Status:** Approved (Gate A, 2026-11-11, by the coordinator under the maintainer's delegation, at 0.2.0)
**Version:** 0.2.0
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 059](../059-bulk-mode-from-location-refusal/spec.md) (the place's shortcut, `BulkSelection#restart!`'s `all:`), [spec 062](../062-create-rename-remove-a-deck/spec.md) (decks, zones, the deck refusal page), [spec 065](../065-deck-zones-in-pickers/spec.md) (the filter's `deck:<id>`, "<Deck> (all zones)", Move to… under a deck filter), [spec 037](../037-filter-collection-by-location/spec.md) (the location filter and the selection tied to it), [spec 041](../041-move-many-lots/spec.md) (Move to…)
**Branch:** `067-deck-refusal-bulk-mode`
**Issue:** [#302](https://github.com/plainprogrammer/Collector/issues/302) (theme: locations)
**Frozen:** the current rules are in [`collection-and-lots.md`](../../architecture/collection-and-lots.md) (whole spec) and [`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md) (the deck shortcut's 404 rule); see the [specs index](../README.md)
**Plan:** retired in `e6382f3d4a17e9b5c71a64b01984bd6b061fe260`; read it with `git show e6382f3d4a17e9b5c71a64b01984bd6b061fe260^:docs/specs/067-deck-refusal-bulk-mode/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.0 | 2026-11-11 | Spec review (Opus, read-only), round 1: no blocking, 13 findings, all taken (a Notes for the plan section with the guards that fail until updated; FR-3's guards; the documents table gains the area doc's Decisions line and `tenancy-and-accounts.md`; the glossary, spec 059's supersession of spec 006 FR-4 and the spec 065 Sources line; AC-2.7's Given, AC-3.1's landing, the redirect's encoding, decision 3 names the comments, AC-5.2's verification, roadmap item 14m) |
| 0.1.0 | 2026-11-11 | First draft from issue #302, specs 059, 062 (decisions 5 and 7, AC-3.3, AC-3.8) and 065 (Non-Goals, decision 4) and the area doc `collection-and-lots.md` |

---

## Problem Statement

A deck whose zones hold copies refuses removal: "“Izzet Tempo” holds 12 copies in 3 lots. Move them before removing it." (spec 062 decision 7). A place's refusal page has a button that opens its lots in bulk mode with every lot selected, so "Move to…" is one press away (spec 059). The deck's page has no such button: spec 062 left it off because the collection filter knew no zones, and spec 065 gave the filter "<Deck> (all zones)" but kept the button out to keep that change to pickers and the filter. The collector who was told to move a deck's copies first goes to the collection, chooses "Izzet Tempo (all zones)" in the Location filter, presses Filter, presses `Edit many`, ticks the header and presses "Move to…".

This spec adds the button to the deck's refusal page. It opens the collection's bulk table filtered to the deck (all zones) with every lot of the deck selected. It adds no data a collector owns and no new working state.

**Outcome (issue #302):** from a deck's removal refusal page, a collector opens bulk mode filtered to that deck in one step, ready to use Move to… or Remove.

> **Terms.** *Lot*, *place*, *zone*, *deck*, *label* ("Deck › Zone"), *selection*, *every matching lot*, *bulk mode* and *bulk table* are as in the [area doc](../../architecture/collection-and-lots.md) and specs 006, 037, 062 and 065. The *deck refusal page* is the page `GET /decks/:id/removal/new` and a refused `DELETE /decks/:id` (409) render for a deck whose zones hold lots (spec 062 AC-3.3, AC-3.4). The *shortcut* is the button this spec adds to it; the *place shortcut* is spec 059's.

## Goals

- A collector on the deck refusal page presses one button and is in bulk mode, filtered to "<Deck> (all zones)", with every lot of the deck selected.
- It is the sequence the place shortcut is (filter, `Edit many`, select every matching lot), so everything after it is bulk mode as it is: Move to…, Set condition and Remove work unchanged.
- It is a button that changes state, so it is a POST and never a link (spec 006 FR-1, AC-1.10).
- The place shortcut and the deck shortcut share one definition of what pressing does, so they can't diverge.

## Non-Goals

- Moving or removing anything itself: the shortcut selects; the collector chooses what to do next.
- Removing the deck afterwards: the collector returns to the Decks page and removes it as before (spec 062 Story 3).
- A shortcut from the Decks page's rows, the deck page (#253) or anywhere but the deck refusal page; a shortcut for one zone on its own (a zone is never opened in bulk mode through a locations or deck route, spec 062 AC-3.8).
- A shortcut on the confirmation page of an empty deck: it has nothing to open.
- Any change to the refusal page's sentence, its list of lots, "and N more" or "Back to decks" (spec 062 AC-3.3).
- Any change to the export format, its version, the schema or the import (decision 5).

## Decisions

### 1. Every lot of the deck is selected, under the whole deck's filter

The shortcut stores a selection that is "every matching lot" under the location filter `deck:<location id>` (spec 065 decision 4), with no exceptions, no name filter and the default sort, exactly the state the header checkbox makes under "<Deck> (all zones)". The bulk bar then reads "All 12 items selected" and Move to… works at once, as for a place (spec 059 decision 1).

### 2. A route of the deck's own: `POST /decks/:deck_id/selection`

`Decks::SelectionsController#create`, a sibling of `Decks::RemovalsController`, finds the deck as that controller does (`Current.account.decks`, by the deck's location id), so another account's deck, a place's id and a zone's id are all 404, and answers 303 to `collection_listing_path(bulk: 1, location: "deck:<id>")`, that is `/collection?bulk=1&location=deck:<id>` with the colon percent-encoded. The place shortcut's route, `POST /locations/:location_id/selection`, is unchanged and still answers 404 for a deck's or a zone's id (spec 062 AC-3.8): the locations routes know places only. The deck's id in the path is the only parameter read.

### 3. One definition of the shortcut, used by both controllers

What pressing does (replace the session's selection with a new one under a filter string, every matching lot selected, and redirect to the bulk table under it) is written once and both controllers call it, not copied. The place shortcut's behaviour, specs and answers don't change. `BulkSelection#restart!(all: true)` is already shared, so only the default sort, the redirect and the 404 lookup would be repeated; the shared definition takes the filter string and does the rest. Where it lives (a controller concern or a model method) is the plan's choice; its comment says what it shares and cites spec 059 and this spec. The comments that describe one caller change in the same commit: `BulkSelection#restart!`'s ("a location's shortcut from its refusal page") and the header of `Locations::SelectionsController` (`.claude/rules/code-documentation.md`).

### 4. The button is the place shortcut's, worded and placed the same

"Move them in bulk mode", a `c-btn c-btn--primary`, first in the actions row and followed by "Back to decks" (`c-btn--secondary`), with the visually hidden tail naming the deck (`<span class="c-sr"> from “Izzet Tempo”</span>`), so its accessible name is "Move them in bulk mode from “Izzet Tempo”". Both ways to the refusal page show it (the page is one view for the GET and the 409). It is not on the Decks page's rows.

### 5. No collector-owned data, no export change

The selection is working state (a `bulk_selections` row, deleted by `Done`, the session's end and an import apply); nothing new is stored and the export is unchanged (format version 4). The format document, its version and the schema are unchanged.

## Supersedes

- **Spec 062 decision 7's last clause** ("There is no shortcut into bulk mode for it, because the collection filter by zone is #252"), **the parenthesis of decision 5** ("no bulk-mode shortcut until #252"), and **AC-3.3's** "there is no … 'Move them in bulk mode' button": the deck refusal page has the shortcut.
- **Spec 065's Non-Goal** "A 'Move them in bulk mode' button on a deck's removal refusal page": met by this spec.
- **Spec 059's Out of Scope** entry "decks as locations (#49)" as it touches the refusal page's shortcut: decks have their own. Spec 059 AC-1.1–AC-1.5, AC-4.1–AC-4.5 and the place shortcut's route are unchanged.
- **Spec 059's supersession of spec 006 FR-4 and Story 4** (the shortcut is a second way to start a selection, "always one filled under a location"): extended, not replaced. The deck shortcut is a third way in, under `deck:<id>`, which is a filter value and not a location id.
- Spec 062 AC-3.8 is unchanged and is re-proved: `POST /locations/:id/selection` answers 404 for a deck's and a zone's id.

## Documents that change

| Document | Change |
|---|---|
| [`docs/architecture/collection-and-lots.md`](../../architecture/collection-and-lots.md) | The decks table's "holding lots in any zone / Remove" row (the shortcut, not "not built"); the Decisions line "A deck is removed only while empty" (no shortcut, "filed as #302"); the #50 bullet's last sentence in Accepted limits (removed); the Glossary's *Bulk mode* ("or from a location's refusal page") and the bulk mode section's opening, which gain the deck's shortcut; the prefetch invariant (the deck shortcut is a POST button too); the core guard sentence ("lists the 19 deck files", stale at 26, to read 27 and name the selections controller); the Sources entry for spec 065 ("the refusal page's shortcut for a deck is not built, #302") and spec 059's; Distillation log |
| [`docs/architecture/tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md) | The list of deck controllers and URLs that read `Current.account.decks` by location id gains `Decks::SelectionsController` and `POST /decks/:id/selection` |
| [`docs/design-system/components/DecksIndex.md`](../../design-system/components/DecksIndex.md) | The refusal's actions: the primary button first, then "Back to decks" |
| [`docs/specs/README.md`](../README.md), [`docs/roadmap.md`](../../roadmap.md) | This spec's row and the "Superseded by" pointers on rows 062, 065 and 059 (written with the spec); a roadmap item 14m for #302 after 14l |
| [`CLAUDE.md`](../../../CLAUDE.md) | The status paragraph's decks sentence (the refusal page's shortcut) |
| Specs 059, 062 and 065 | Not edited; the index records the supersessions above |

## Users and Context

A collector emptying a deck before removing it: they pressed "Remove" on the Decks page and read the refusal. They are on a desktop or a phone, with or without scripting. The deck has at least one zone holding a lot, so the account has a zone and Move to… is offered.

## User Stories

### Story 1: The button on the deck refusal page

As a collector told to move a deck's copies first, I want a button that takes me to them in bulk mode.

- [ ] **AC-1.1** Given a deck any of whose zones holds lots When `GET /decks/:id/removal/new` renders its refusal page Then, after the list of lots and "and N more", the actions row holds a "Move them in bulk mode" button first and "Back to decks" after it, and there is still no Remove button.
- [ ] **AC-1.2** Given such a deck When a `DELETE /decks/:id` is refused with 409 Then the refusal page it renders has the same button.
- [ ] **AC-1.3** Given an empty deck When its removal confirmation page renders Then it has no such button.
- [ ] **AC-1.4** Given the refusal page When it renders Then the shortcut is a `<button>` in a `form` with `method="post"` to `/decks/:id/selection`, not a link, and carries no field but the CSRF token (spec 006 FR-1, AC-1.10), and its accessible name is "Move them in bulk mode from “<deck name>”".
- [ ] **AC-1.5** Given the refusal page When the sentence, the lot list with each lot's "Deck › Zone", "and N more" and "Back to decks" render Then they are as spec 062 AC-3.3 defines them.
- [ ] **AC-1.6** Given a place's refusal page When it renders Then it is as spec 059 AC-1.1 defines it (its button posts to `/locations/:id/selection`).

### Story 2: It opens bulk mode on that deck

As a collector, I want to land in bulk mode with the deck's lots selected.

- [ ] **AC-2.1** Given a deck holding 12 copies in 3 lots across two zones, in an account whose collection holds 40 copies When the collector presses the button Then the answer is 303 to `/collection?bulk=1&location=deck:<id>` (the colon percent-encoded, as `collection_listing_path` writes it), and the page shows the bulk table filtered to that deck: its 3 lots, the Location filter showing "<Deck> (all zones)", each row's place reading "Deck › Zone", and the count line "12 of 40 items".
- [ ] **AC-2.2** Given AC-2.1 When the table renders Then every row is ticked, the header is ticked and the bar reads "All 12 items selected".
- [ ] **AC-2.3** Given AC-2.1 When the bar renders Then it offers "Set condition…", "Move to…" and "Remove", and pressing "Move to…" opens the move page for "Move 12 items" without ticking anything first, with no destination left out (spec 065 decision 7: a deck filter leaves out nothing).
- [ ] **AC-2.4** Given the session already has a stored selection, under any name filter, location and sort When the collector presses the button Then that selection is replaced by the new one: nothing of the earlier ticks remains.
- [ ] **AC-2.5** Given the session has an undoable bulk removal When the collector presses the button Then the removal can still be undone (the shortcut removes nothing).
- [ ] **AC-2.6** Given the deck was emptied after the refusal page rendered When the collector presses the button Then the answer is the same 303, and the bulk table shows the filter's empty sentence for the deck with "0 of 0 selected" and no header checkbox (spec 037 AC-1.6, AC-5.4; spec 006 AC-5.9), or, if the account then holds no lot at all, the empty collection's page (spec 004 AC-11.6).
- [ ] **AC-2.7** Given the deck was emptied and removed in another tab after the shortcut answered but before the bulk table loaded When the table loads Then it reads the filter as all locations, 200, with the whole collection in bulk mode and nothing selected, never a 500 (spec 065 decision 4; spec 037 decision 7).
- [ ] **AC-2.8** Given the bulk table the shortcut opened When the collector presses `Done` Then the selection is deleted and they return to the saved view filtered to the deck, nothing else changed (spec 006 AC-4.5).
- [ ] **AC-2.9** Given the lots of the shortcut's selection When the collector uses Move to…, Set condition or Remove Then exactly the deck's lots change, a lot in a zone keeps its zone unless moved, as under any deck filter (spec 065 AC-6.7).

### Story 3: Emptying the deck, end to end

As a collector, I want the refusal page to be where emptying a deck starts and removing the deck to be where it ends.

- [ ] **AC-3.1** Given a deck holding lots and a place When the collector presses "Remove" on the Decks page, then "Move them in bulk mode", then "Move to…", chooses the place and presses "Move" Then the lots are in the place, the notice reads "Moved <n> items to <name>.", the collector lands on the bulk table under the deck with its empty-filter sentence, since a move under a deck filter restarts the selection (spec 065 decision 12, AC-6.11), and the deck's removal page is now the confirmation page, which removes it. A system spec covers it, without scripting.

### Story 4: Only my decks

As a collector on a shared instance, I want the shortcut never to reach another account.

- [ ] **AC-4.1** Given another account's deck id When `POST /decks/:id/selection` is requested Then the answer is 404 and no selection is created or changed for either account.
- [ ] **AC-4.2** Given a place's id, a zone's id, or an id that does not exist (the deck removed meanwhile) When the shortcut is requested Then the answer is 404.
- [ ] **AC-4.3** Given the request When it carries an account, user, admin, name filter, location or sort value Then none is used: the selection's location is `deck:<path id>`, its name filter is empty and its sort is the default (spec 006 AC-8.4).
- [ ] **AC-4.4** Given a signed-out visitor, with a valid CSRF token, When they request the shortcut Then they are sent to sign-in and nothing is created (spec 004).
- [ ] **AC-4.5** Given `GET /decks/:id/selection`, marked as a prefetch or not When it is served Then no route answers it (404) and nothing changes (spec 006 FR-1, AC-1.10).
- [ ] **AC-4.6** Given a deck's id When `POST /locations/:location_id/selection` is requested Then it answers 404 as before (spec 062 AC-3.8), and a place's id on the place shortcut still works (spec 059 AC-2.1).

### Story 5: Without scripting, and on a phone

- [ ] **AC-5.1** Given a browser without scripting When the collector presses the button Then the bulk table opens with every lot of the deck selected, as with scripting.
- [ ] **AC-5.2** Given a viewport of 360px When the deck refusal page renders Then the button and "Back to decks" fit without horizontal scrolling, each at least 44px by 44px, and both themes keep the text and focus ring contrast the design system sets (checked by reading, since the page adds no colour: it reuses `c-btn` and the page's own classes, and recorded in `verification.md`, as spec 059's was).

## Functional Requirements

### FR-1: The route

**Must:**
- Provide `POST /decks/:deck_id/selection`, handled by `Decks::SelectionsController#create`, and no other verb or route for it.
- Find the deck only through `Current.account.decks` by its location id (404 otherwise) and require sign-in as every page does.
- Start the session's selection through the definition decision 3 shares, under an empty name filter, the filter string `deck:<location id>` and the default sort, selecting every matching lot in the same transaction, and answer 303 to `collection_listing_path(bulk: 1, location: "deck:<id>")`.

**Must not:**
- Read any parameter but the deck id from the path.
- Change a lot, a location, a deck or an undo record, or answer a GET.
- Change the place shortcut's route, answers or behaviour.

### FR-2: The view

**Must:**
- Put the button, a `c-btn c-btn--primary`, in the refusal page's `c-form__actions` as the page's only primary action, in a post form with no field but the CSRF token; use only design-system tokens and `c-*` classes; update `DecksIndex.md`.
- Word it as decision 4 says, in sentence case.

**Must not:**
- Make it a link, or add it to the Decks page's rows.

### FR-3: The core names no collectible

**Must:** keep the new controller, the shared definition and the view's change free of any collectible, deck format or zone key's vocabulary. `spec/deck_core_spec.rb` covers `app/controllers/decks/*.rb` and `app/views/decks/**/*.erb` by glob, so the new controller is covered and only its count rises (26 to 27); `spec/import_apply_core_spec.rb` lists its files by name, so the shared definition's file is added to its list (it already lists `app/controllers/locations/selections_controller.rb`).

## Non-Functional Requirements

### Performance

- The shortcut does a constant number of statements (a find and the selection's restart), independent of the number of lots; the bulk table it lands on is spec 006's, within its existing budget.

### Accessibility

- The button's accessible name reads on its own, it is keyboard operable with a visible focus ring, and the landing page's "All 12 items selected" is announced as bulk mode's count line already is.

### Security

- Every lookup goes through `Current.account`; another account's deck is 404; CSRF protection stays on; no field is read.

### Reliability

- A concurrent change (the deck emptied or removed after the page rendered) is a 303 to an empty table or a 404, and a deck removed after the 303 is the table under all locations, never a 500.

### Cost per account (hosted-door rule 4)

- No new storage and no background work beyond the existing `bulk_selections` row of the session. The operator sees nothing of it (hosted-door rule 2).

## Error Scenarios

| Situation | Answer |
|---|---|
| Another account's deck, a place's or a zone's id, or a removed deck | 404, nothing changed |
| Signed out | Redirect to sign-in, nothing changed |
| The deck was emptied after the page rendered | 303 to the bulk table under the deck: the empty sentence, "0 of 0 selected" (the empty collection's page if no lot is left, AC-2.6) |
| The deck was removed after the 303 | The table under all locations, nothing selected, 200 (AC-2.7) |
| `GET` of the shortcut's path | No route (404) |
| The session has a stored selection | Replaced, as `Edit many` replaces it |

## Notes for the plan

- **Guards that fail until updated** (change them first, so they fail against the old code): `spec/requests/decks_spec.rb`'s AC-3.3 example (it expects no bulk button and no form on the refusal page) and the 409 one if it asserts the same, `spec/system/decks_spec.rb`'s 360px refusal example (`have_no_css("main button", text: /Remove|bulk/)`), `spec/deck_core_spec.rb`'s count (26 to 27), `spec/import_apply_core_spec.rb`'s file list. `spec/requests/locations*` examples of AC-3.8 for `POST /locations/:id/selection` stay as they are.
- `config/routes.rb`: the new `resource :selection` under `resources :decks` carries a comment citing spec 067, as line 44's does for spec 059.
- A system spec, without scripting, covers Story 3 (AC-3.1) from the Decks page to the removal.

## Open Questions

- None. The issue states the outcome and spec 059 settled the button's label, order and selection state; this spec keeps them. A route of its own (decision 2) rather than the locations route keeps spec 062 AC-3.8 true.

## Out of Scope

- A shortcut from the Decks page's rows, the deck page (#253) or the card page; one for a single zone; "Move to…" itself; removing the deck in the same step.
