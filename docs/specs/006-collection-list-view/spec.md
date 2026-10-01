# Feature 006: Collection Table View and Bulk Editing

**Status:** Approved
**Version:** 4.0.0
**Created:** 2026-09-30
**Last Updated:** 2026-09-30
**Branch:** `006-collection-list-view`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-09-30 | Initial approved spec |
| 2.0.0 | 2026-09-30 | Spec review revisions.<br>**Tenancy:** lot ids outside the account are ignored, not answered with 404; only Undo keeps its 404 (AC-8.1, AC-8.3).<br>**View preference:** saved by any non-bulk collection URL that names a view; `Done` names none; the back button restores the earlier URL (AC-1.3, AC-1.4, AC-4.5, FR-1).<br>**Selection:** stored server-side per session; in bulk mode, paging, sorting and filtering submit the ticks (FR-4, AC-4.7).<br>**Set condition:** has its own page (AC-6.1).<br>**Bulk mode:** rows have no actions menu (AC-2.1, AC-2.8, AC-4.2).<br>**Undo:** belongs to the session, reachable only from the message right after the removal; a replayed Undo answers 422 and an unknown one 404 (AC-7.6, AC-8.3, FR-6).<br>**Refusals:** answer 422 and re-render the originating page (FR-5); a successful action re-renders the results rather than single rows (AC-6.5).<br>**New patterns:** FR-7 lists the new design-system patterns.<br>**Also:** pluralisation, confirmation wording, tie-break order, name and set · number sort keys, unique row-menu names, `Done` keeps the sort, landing pages after removal and Undo, bulk mode with no matches, and phone back links for the new pages |
| 3.0.0 | 2026-09-30 | Second spec review.<br>**View switch:** its options are buttons in a GET form, and prefetch requests never save a view (FR-1, new AC-1.10). AC-1.4 now allows the browser's cached page.<br>**Set condition and Remove:** because both are submitted from their own pages, success always redirects (303) to the bulk table, and a refusal re-renders the page it came from. The in-place re-render is dropped (AC-6.5, AC-6.6, FR-5).<br>**Selection:** the tick-submission protocol is defined (FR-4).<br>**Undo after sign-out:** redirects to sign-in, then answers 404 (AC-7.6). There is at most one undoable record per session, and every way a session ends discards it (FR-4, FR-6).<br>**Also:** the cap message names the first lot in table order; AC-8.1 wording; finish order joins the extension contract; the first click on Name sorts descending; the count wording after an exception; the Undo landing URL; AC-4.7 wording |
| 4.0.0 | 2026-09-30 | Third spec review.<br>**Controls that change state:** `Edit many` and `Done` are buttons that change server state, never links, so a hover prefetch can't clear a selection. `Edit many` always starts with nothing selected, and loading a page never changes the selection. Leaving bulk mode other than by `Done` leaves the selection to be cleared by the next `Edit many` (AC-4.1, AC-4.2, AC-4.5, AC-5.6, FR-4).<br>**Header checkbox:** it acts on a change from how it was rendered, so an untick after Select all is kept (FR-4, AC-5.5, AC-5.8).<br>**Bulk form details:** the form's default submit is the filter; in bulk mode the view switch is inert and outside the bulk form (FR-1, FR-4, AC-4.3); a bulk page whose filter or sort differs from the stored selection's shows nothing selected (FR-4).<br>**Undo URL:** follows the local-path rule.<br>**Also:** AC-6.5 and NFR wording, the third sort click, cap-message order on the grid, FR-7 patterns, `view=grid` on a bulk URL |

---

## Problem Statement

The collection page (feature 004) shows a collection only as an image grid, one tile per printing. A collector can't scan their copies densely, see each lot's condition and price paid at a glance, or sort the collection by anything but name. Changing many copies at once is impossible. Correcting the condition of forty cards, or clearing out a stack of bulk commons, means opening each card page and editing or removing one lot at a time. Feature 004 deferred the design system's table view, view switch and bulk mode (`CollectionTable`, `ViewSwitch`, `Edit many`) to this feature.

> **Constraints.** The design system's `CollectionTable`, `ViewSwitch`, `FilterBar`, `Menu`, `TableActions`, `ConfirmPage`, `StatusMessage` and `Pager` docs (`docs/design-system/components/`) are fixed inputs. They define the look, voice, responsive behaviour and the bulk-mode rules this spec builds on. Feature 004's rules still apply unless this spec supersedes them (listed in AC-1.7): the lot model and identity (FR-6), the grid (Story 11), tenant isolation (Story 12), responsiveness and accessibility with scripting disabled (FR-12). So do the row-level multi-tenancy rules (`.claude/rules/multi-tenancy.md`).

## Goals

- A collector can switch the collection between the grid and a table. The choice is remembered per user, and Grid stays the default.
- The table shows one row per lot, with its printing, finish, condition, language, quantity and price paid. It uses the grid's filter, counts and pagination, and can be sorted by clicking a column header.
- A collector can enter bulk mode from either view, select lots (one by one, across pages, or every lot matching the filter), and then:
  - set the condition of all the selected lots in one step
  - remove them all in one step, with a confirmation first and an undo right after
- Every one of these works on a phone and with scripting disabled, in light and dark themes.

## Non-Goals

- Bulk actions that need data the app doesn't have yet: Move to… (locations), Lend, Update prices (market prices).
- Bulk-setting finish, price paid or quantity.
- Undo for bulk Set condition (only the destructive Remove offers undo, per `CollectionTable`).
- A sort control for the grid. The grid keeps its 004 order (AC-11.3).
- Filters other than the existing name search (set, finish, condition quick filters).
- Collection export and import.
- Selections that span collectible types with different condition scales (only Magic exists).

## Users and Context

**Primary users:** Collectors on a self-hosted instance, on desktop and on a phone.
**Secondary users:** Contributors, who reuse the table and bulk patterns for future collectibles and bulk actions.
**Usage context:** A collector who has just sorted a box types a name in the filter, switches to Table and sorts by condition. Then they tap `Edit many`, tick the twelve lots that turned out to be Lightly played, and choose Set condition → Lightly played. Or they filter to a set they're selling, choose Select all and Remove. Before tapping Undo they see "Removed 312 items from your collection." and realise they meant to keep the foils.
**User mental model:** "Grid to look, table to manage." Vocabulary from 004 and the design system:
- *lot*: a table row.
- *item*: one copy, and what the counts count.
- *Edit many* and *bulk mode*.
- *Select all*, which means all matching, not just the visible page.
- *Done*.

## User Stories

### Story 1: Collector switches between grid and table

**As a** collector
**I want** to choose whether my collection shows as a grid or a table, and have that remembered
**So that** I see my collection the way I prefer every time I open it

**Acceptance criteria:**

- [ ] **AC-1.1** Given a collector with copies When the collection page renders Then the filter bar holds a view switch labelled "View" with two options, Grid and Table, and exactly the option being shown is marked pressed
- [ ] **AC-1.2** Given a collector who has never chosen a view When they open the collection Then the grid is shown
- [ ] **AC-1.3** Given a collector outside bulk mode When they choose Table (or Grid) with the view switch Then that view is shown with the same name filter (and the table's sort), the view is in the URL, and the choice is saved for that user. The next collection visit without a view in the URL shows the chosen view, including after signing out and in again or on another device. Any collection URL outside bulk mode that names a valid view saves it the same way. Bulk-mode URLs never save a view
- [ ] **AC-1.4** Given a collector who switched views When they use the browser's back button Then the URL from before the switch is restored; the browser may show its kept copy of that page, and a fresh load of that URL shows the view it names, or, if it names none, the collector's saved view
- [ ] **AC-1.5** Given a URL with an unrecognised view value When the collection renders Then the collector's saved view is shown (the grid if none), with status 200, and the saved choice is unchanged. A bulk-mode URL always shows the table, whatever view it names
- [ ] **AC-1.6** Given two users on one instance When one chooses Table Then the other's view is unaffected
- [ ] **AC-1.7** Given feature 004 When this feature ships Then these 004 rules are superseded, and all other 004 collection behaviours still hold for the grid:
  - AC-11.7 (no view switch or `Edit many`) is replaced by Stories 1 and 4 of this spec.
  - FR-10's "the filter bar has only the name search" becomes: the name search, plus the view switch and `Edit many` (AC-4.1).
  - For Edit copy and Remove opened from a table row, the return target is the table (AC-2.6) rather than the card page (004 AC-2.7, AC-10.1, AC-10.4).
  - Removing a single lot (004 AC-10.4) now also ends the chance to undo an earlier bulk removal in the same session (AC-7.6).

  004 FR-8 (per-lot edit and remove) and FR-10 (the collection page) are extended by this spec, not replaced.
- [ ] **AC-1.8** (verified in a browser-level test) Given a phone-width page When the view switch renders Then it shows icons only, and each option keeps its accessible name ("Grid", "Table")
- [ ] **AC-1.9** Given an empty collection When the page renders Then there is no view switch and no `Edit many`, whatever the saved view (004 AC-11.6 still applies)
- [ ] **AC-1.10** (verified in a browser-level test) Given the grid with scripting enabled When the collector points at or hovers the Table option without choosing it Then the saved view is unchanged

### Story 2: Collector browses the collection as a table

**As a** collector
**I want** a dense table with one row per lot
**So that** I can scan condition, finish and what I paid across my collection

**Acceptance criteria:**

- [ ] **AC-2.1** Given the table view When it renders Then there is one row per lot of the signed-in account's collection, with columns:
  - name: a small thumbnail (or the no-image fallback) and the printed name as on grid tiles (004 AC-11.2), linking to the printing's card page marked as coming from the collection
  - set · number
  - language
  - finish (as in 004 AC-8.5: a special finish as the one finish badge, any other finish as its capitalised word in muted text, "—" when unspecified)
  - condition (the scale's short form, for MTG `NM`…`DMG`, "—" when unspecified)
  - quantity
  - price paid per copy (in the instance currency, "—" when unspecified)
  - an actions menu (outside bulk mode only; AC-4.2)
- [ ] **AC-2.2** Given the table When it renders Then the page title, stats line and `Add items` are those of the grid (004 AC-11.1), and the count beneath the filter bar reads as in 004 AC-11.4 ("<matching copies> of <total copies> items" when filtered)
- [ ] **AC-2.3** Given the table's name filter When the collector types part of a card name Then only rows of lots whose printing matches (the matching rules of 004 AC-11.4) are shown, and the filter is in the URL with a working back button; a filter matching nothing shows the grid's no-match message (004 AC-11.5)
- [ ] **AC-2.4** Given more than 120 lots match When the table renders Then it shows 120 rows per page with the previous/next pager and page position; invalid or out-of-range page numbers fall back to the first or last page with status 200
- [ ] **AC-2.5** Given a row's actions menu When it is opened Then it offers "Edit copy" and "Remove", and its trigger's accessible name names the row by card name, set · number, and finish and condition when specified ("Actions for Lightning Bolt M10 · 146 Foil NM")
- [ ] **AC-2.6** Given the collector chose "Edit copy" or "Remove" from a table row When they save, remove, cancel or use the page's back link Then they return to the table with the same filter, sort and page, and the status message of 004 AC-10.1 or AC-10.4 is shown
- [ ] **AC-2.7** Given a lot whose printing has been retired from the catalog When the table renders Then its row is shown like any other
- [ ] **AC-2.8** (verified in a browser-level test) Given a phone-width page When the table renders Then only the name (with thumbnail), quantity and actions columns show (in bulk mode: the checkbox, name and quantity columns). A line under the name gives set · number, finish, condition and language, and the table never scrolls sideways at 360px

### Story 3: Collector sorts the table

**As a** collector
**I want** to sort the table by a column
**So that** I can find my most valuable, most numerous or worst-condition copies

**Acceptance criteria:**

- [ ] **AC-3.1** Given the table with no sort chosen When it renders Then rows are in the grid's order (card name A–Z, then release date newest first, set code, collector number, language; 004 AC-11.3), then by finish in the collectible's finish order (MTG: nonfoil, foil, etched), condition in scale order and price paid ascending, with unspecified values last in each. The name column is marked as sorted ascending
- [ ] **AC-3.2** Given the table When the collector activates the header of the name, set · number, condition, quantity or price paid column Then rows are sorted by that column ascending. Activating the same header again sorts it descending, and each further activation reverses it; because the default order already shows Name ascending, the first activation of the Name header sorts it descending. Name sorts by card name, as the grid does, not by the printed name shown. The sorted column's header states its direction to assistive technology, and every other column states none
- [ ] **AC-3.3** Given a sort by set · number When it applies Then rows order by set code, then collector number in the order the grid uses; descending reverses both. Condition sorts by the collectible's scale (MTG ascending: Near mint, Lightly played, Moderately played, Heavily played, Damaged), not alphabetically. Quantity and price paid sort numerically
- [ ] **AC-3.4** Given a sort by condition or price paid When lots have that value unspecified Then those rows come last in both directions
- [ ] **AC-3.5** Given rows with equal values in the sorted column When they render Then they follow the default order of AC-3.1, so the order is stable across page loads and pages
- [ ] **AC-3.6** Given a chosen sort When the collector changes the filter, pages, switches to the grid and back, or uses the back button Then the sort is kept in the URL and restored; choosing a new sort returns to the first page
- [ ] **AC-3.7** Given an unrecognised sort column or direction in the URL When the table renders Then the default sort is used with status 200
- [ ] **AC-3.8** Given a sort in the URL When the grid renders Then the grid keeps its 004 order (AC-11.3)

### Story 4: Collector enters and leaves bulk mode

**As a** collector
**I want** an explicit "Edit many" mode
**So that** selecting and changing many lots never happens by accident while I'm browsing

**Acceptance criteria:**

- [ ] **AC-4.1** Given the grid or the table (not in bulk mode) with copies When the filter bar renders Then it holds an `Edit many` button; below 640px it sits in the filter bar's "…" menu instead, and it appears only once per width. It is a button that submits, never a link
- [ ] **AC-4.2** Given the grid or the table When the collector chooses `Edit many` Then any stored selection is cleared and the table is shown in bulk mode with nothing selected, the same filter (and the table's sort, if one was chosen), a checkbox on every row and in the header, and the bulk bar above the table. Rows have no actions menu in bulk mode
- [ ] **AC-4.3** Given bulk mode When the view switch renders Then Table is marked pressed and Grid is disabled, and pressing either option changes nothing
- [ ] **AC-4.4** Given bulk mode When the bulk bar renders Then it shows the selection count, the actions "Set condition…" and "Remove" (Remove styled as the destructive action), and `Done` as the one primary action; below 640px the actions move into the bar's "…" menu while the count and `Done` stay visible
- [ ] **AC-4.5** Given bulk mode When the collector chooses `Done` Then bulk mode ends and the collector's saved view (the grid if none) is shown with the same filter and sort, the selection is cleared, and the saved view preference is unchanged (the URL `Done` leads to names no view). `Done` is a button that submits, never a link, and any ticks on the page are discarded
- [ ] **AC-4.6** (verified in a browser-level test) Given bulk mode with scripting enabled and no menu or dialog open When the collector presses Esc Then it submits `Done`
- [ ] **AC-4.7** Given bulk mode When the collector uses the table's own controls (sorting, paging, filtering) while in bulk mode Then they stay in bulk mode and the URL says so, so a reload or the back button returns to bulk mode with the selection it had (unless the filter or sort changed, AC-5.6)
- [ ] **AC-4.8** Given the table outside bulk mode When it is inspected Then it has no checkboxes and no bulk bar

### Story 5: Collector selects lots

**As a** collector in bulk mode
**I want** to pick exactly the lots I mean, including all of them at once
**So that** a bulk action touches what I intend and nothing else

**Acceptance criteria:**

- [ ] **AC-5.1** Given bulk mode with nothing selected When the bulk bar renders Then the count reads "0 of <matching copies> selected", where matching copies is the filter's copy total (the count beneath the filter bar)
- [ ] **AC-5.2** Given bulk mode When the collector ticks rows Then each ticked row is marked selected, and the count reads "<sum of the selected lots' quantities> of <matching copies> selected" with digit grouping ("12 of 4,812 selected")
- [ ] **AC-5.3** Given a selection When the collector moves to another page of the same filter and sort, and back Then every ticked lot is still selected, on every page, and the count still covers all of them
- [ ] **AC-5.4** Given bulk mode When the collector ticks the header's "Select all" Then every lot matching the current filter is selected, including lots on other pages, and the count reads "All <matching copies> items selected" ("All 4,812 items selected")
- [ ] **AC-5.5** Given every matching lot is selected When the collector unticks one row Then every other matching lot stays selected (with scripting, the header shows a mixed state; without it, the header stays ticked and the untick is still recorded), and the count changes from "All <m> items selected" to "<m minus that row's quantity> of <m> selected"; when they untick the header's "Select all" Then nothing is selected
- [ ] **AC-5.6** Given a selection When the collector changes the filter or the sort, or chooses `Done` Then the selection is cleared. Leaving bulk mode any other way (a link, the back button, a typed URL) leaves the stored selection as it is until the next `Edit many` clears it (AC-4.2)
- [ ] **AC-5.7** Given scripting is disabled When the collector ticks rows, selects all, pages or runs an action Then selection, paging with a kept selection, and every action still work (the count may update only when the page is next loaded)
- [ ] **AC-5.8** (verified in a browser-level test) Given scripting is enabled When the collector ticks or unticks a row or "Select all" Then the count (and the header's mixed state) update without a page load, and nothing is submitted
- [ ] **AC-5.9** Given bulk mode with a filter that matches nothing When it renders Then the no-match message shows, the bar reads "0 of 0 selected", and there is no header checkbox

### Story 6: Collector sets the condition of many lots

**As a** collector
**I want** to set one condition on every selected lot
**So that** I can grade a stack of cards in one step

**Acceptance criteria:**

- [ ] **AC-6.1** Given a selection When the collector chooses "Set condition…" Then a page titled "Set the condition of <n> items" offers the collectible's condition scale (MTG: Near mint, Lightly played, Moderately played, Heavily played, Damaged) and "Not specified" as a single choice, with "Apply" as the primary action and "Cancel", which returns to the bulk table with the same filter, sort, page and selection. The page works without scripting
- [ ] **AC-6.2** Given a selection and a chosen condition When it is applied Then every selected lot has that condition, and the status message reads "Set the condition of <n> items to <condition label>." (or "Cleared the condition of <n> items." for "Not specified"), where n is the selected copies. Lots already in that condition count and stay unchanged
- [ ] **AC-6.3** Given a changed condition that makes a selected lot's printing, finish, condition and price paid equal to another lot of the same account (selected or not) When it is applied Then those lots become one lot with the summed quantity, as in 004 AC-10.2, and the table shows one row for it
- [ ] **AC-6.4** Given any merge in the action would exceed 9,999 copies in one lot When it is applied Then no lot changes (all or nothing), the response status is 422, the selection is kept, and the status message reads "Nothing changed. <card name> (<SET> · <number>) would have more than 9,999 copies in one lot." When several lots would exceed the cap, the message names the first of them in the table's current order
- [ ] **AC-6.5** Given a successful Set condition When the redirect of AC-6.6 lands Then the collector stays in bulk mode on the same filter, sort and page (the nearest real page if it no longer exists). The selection stays on the changed lots, and a merged lot is selected. Rows are in the sorted order and a merged lot shows once
- [ ] **AC-6.6** Given Set condition is applied successfully, with or without scripting When the response is sent Then it redirects (303) to the bulk table with the same filter, sort and page, and the status message is shown

### Story 7: Collector removes many lots, with undo

**As a** collector
**I want** to remove every selected lot in one step, and take it back if I got it wrong
**So that** clearing out cards is fast but a slip isn't permanent

**Acceptance criteria:**

- [ ] **AC-7.1** Given a selection When the collector chooses "Remove" Then nothing is removed yet. A confirmation (the `ConfirmPage` pattern, which works without scripting) asks "Remove <n> items?" and states the consequence in numbers ("This removes <n> items in <lots> lots from your collection. You can undo this right afterwards."). It offers a destructive "Remove <n> items" button and "Cancel"
- [ ] **AC-7.2** Given the confirmation When the collector chooses "Cancel" Then they return to the bulk table with the same filter, sort, page and selection, and nothing is removed
- [ ] **AC-7.3** Given the confirmation When the collector confirms Then every selected lot is removed. They return to the bulk table on the same filter and sort (the nearest real page) with the selection cleared, the counts and stats reflect the removal, and the status message reads "Removed <n> items from your collection." with an "Undo" button. If the removal empties the collection, they land on the empty state (004 AC-11.6), which shows the same message and Undo. The Undo is offered only in this message; it has no other entry point
- [ ] **AC-7.4** Given the status message after a bulk removal When the collector chooses "Undo" Then exactly the removed lots are restored, each with its printing, finish, condition, price paid and quantity. The collector lands on the collection URL the Undo carries, which is the page the message was rendered on, with its view, filter and sort; an Undo URL that isn't a collection path on this instance is ignored and the collector lands on the collection in their saved view (the bulk table with nothing selected, when that is where they were). The status message reads "Restored <n> items to your collection.", and the Undo is used up
- [ ] **AC-7.5** Given lots were added since the removal with the same identity as a removed lot When the removal is undone Then each restored lot merges into the existing lot (quantities summed); if any merge would exceed 9,999 copies, nothing is restored and the status message reads "Nothing restored. <card name> (<SET> · <number>) would have more than 9,999 copies in one lot." When several lots would exceed the cap, the message names the first of them in the order the sort in the Undo URL gives, or the default order of AC-3.1
- [ ] **AC-7.6** Given a bulk removal When the collector then removes anything else in the same session (in bulk or a single lot), or uses its Undo Then the earlier removal can no longer be undone. Submitting its Undo again (a second time, or from a page kept open) changes nothing and returns status 422 with "This removal can no longer be undone." Removals in the collector's other sessions don't affect it. Signing out ends the session and discards its Undo: submitting it afterwards is redirected to sign-in, and after signing in again it answers 404 (AC-8.3)
- [ ] **AC-7.7** Given a removed lot whose printing has been retired from the catalog When the removal is undone Then that lot is restored like any other
- [ ] **AC-7.8** Given the selection covers every matching lot (AC-5.4) When the removal is confirmed Then exactly the lots matching the filter at the time of confirming are removed, and lots outside the filter are untouched
- [ ] **AC-7.9** Given the bulk confirmation page or the Set condition page on a phone When it renders Then it is a detail page (004 AC-2.7) whose back link returns to the bulk table with the same filter, sort, page and selection, and it keeps the collection's app header and tab bar

### Story 8: Bulk actions stay within the account

**As a** collector sharing an instance
**I want** bulk actions to touch only my own lots
**So that** no one can change or remove another collector's copies

**Acceptance criteria:**

- [ ] **AC-8.1** Given a submission of ticks, or a Set condition or Remove request, whose ticks or stored selection include lot ids that aren't in the signed-in account's collection (another account's, or no longer existing) When it is processed Then those ids are ignored (they are checked when ticks are stored and again when the action runs): no other account's lot changes, the action applies to the remaining selected lots, and if none remain nothing changes and the response is 422 with "None of the selected items are in your collection any more."
- [ ] **AC-8.2** Given "Select all" for a filter When a bulk action runs Then only the signed-in account's lots are affected
- [ ] **AC-8.3** Given an Undo for a removal made in another session (of any account) or an unknown removal When it is submitted Then the response status is 404 and nothing is restored
- [ ] **AC-8.4** Given a bulk request containing account, user or admin values When it is processed Then those values are ignored
- [ ] **AC-8.5** Given two users When one saves a view preference Then it is stored against that user only, and it is never set from another user's request

## Functional Requirements

### FR-1: View preference

**Must:**
- Store the collection view (grid or table) per user, defaulting to grid.
- Take the view from the URL when present and valid, and fall back to the saved preference otherwise.
- Save the view when a collection page is requested outside bulk mode with a valid view in its URL (AC-1.3). This write on a page request is deliberate: it changes only the requester's own display preference, and it gives each view its own URL that the back button restores.
- Make the view switch's options buttons (`ViewSwitch`'s `aria-pressed` markup) in a GET form that names the view along with the current filter and sort, so they are never prefetched. In bulk mode the switch is outside the bulk form, never nested in it, and inert: Grid is disabled and the pressed Table option submits nothing (AC-4.3).
- Make the storage change safe to run unattended on boot against a feature-004 database. Existing users start with the grid.

**Must not:**
- Change the saved preference when entering or leaving bulk mode (AC-4.5). Bulk-mode URLs and the URL `Done` leads to never save a view.
- Save a view from a request the browser marks as a prefetch (AC-1.10). The same holds for every state in this feature: no prefetch-marked request changes a view, selection or Undo record.

### FR-2: Collection table

**Must:**
- Follow the `CollectionTable` design, using the design system's table, thumbnail, sub-line, numeric and data cell styles and `TableActions`. The columns and their contents are those in AC-2.1.
- Share the grid's filter, counts, empty and no-match states and pager.
- Paginate at 120 rows, and lazy-load thumbnails.
- Get condition labels, short forms and scale order, finish labels, finish order and special finishes from the collectible's extension, as 004 FR-6 does.

**Must not:**
- Put MTG-specific knowledge in core collection code.

### FR-3: Sorting

**Must:**
- Sort only by an allowlisted set of columns and directions (AC-3.2); ignore any other value.
- Keep the sort in the URL, and apply it before paginating, so the order spans pages.

### FR-4: Bulk mode and selection

**Must:**
- Follow the `CollectionTable` bulk-mode rules, and `FilterBar`'s placement of `Edit many`.
- Keep bulk mode in the URL.
- Store the selection on the server for the signed-in session, tied to the filter and sort it was made under. Clear it on `Edit many`, on `Done`, when a submission changes the filter or sort, and whenever the session ends, including sessions ended by an admin's password change or a user deletion (004 AC-5.3, AC-5.4, AC-5.7). It survives paging, reload, the back button, Cancel and redirects (AC-4.7, AC-5.3, AC-6.5, AC-7.2).
- Represent "every matching lot" as its own state (with any unticked lots as exceptions), not as a list of the lots on screen.
- Change the selection only through submissions (`Edit many`, `Done`, the bulk form). Rendering a page never changes it. A bulk page whose filter or sort differs from the stored selection's renders with nothing selected and a count of 0, and its first submission replaces the stored selection.
- Work without scripting (AC-5.7): in bulk mode, the row checkboxes, the header checkbox, the pager's Previous/Next, the sort headers, the filter input, the action buttons and `Done` belong to one state-changing form, so unsubmitted ticks are never lost. This is a deliberate departure from `Pager`'s plain links, in bulk mode only. Each submission carries the ids of the rows shown and the ids ticked:
  - Shown-and-ticked lots become selected. Shown-and-unticked lots become unselected, recorded as exceptions when every matching lot is selected.
  - Each submission also carries how the header checkbox was rendered. It renders ticked whenever every matching lot is selected, with or without exceptions. A header submitted ticked after being rendered unticked selects every matching lot and discards exceptions. A header submitted unticked after being rendered ticked clears the selection, whatever the rows say. A header submitted as it was rendered changes nothing by itself; the rows decide.
  - A submission whose filter or sort differs from the stored selection's clears the selection instead of storing the ticks.
  - The form's default submit (what Enter in the filter input triggers) is the filter: it names the bulk URL with the submitted filter, the current sort and page 1. A filter submission with an unchanged filter stores the ticks and reloads the same page.
  - The server then redirects (303) to the URL the pressed control names, or to the pressed action's page, unless nothing is selected (FR-5: 422 re-rendering the bulk table). `Done` discards the ticks.
- Resolve an "every matching lot" selection against the signed-in account's lots and the filter when the action runs.

### FR-5: Bulk actions

**Must:**
- Provide Set condition and Remove on the selected lots, each all-or-nothing within the account (AC-6.4, AC-7.5).
- Apply 004's lot identity and 9,999 cap to every merge, whether from Set condition or from Undo.
- Confirm Remove with exact numbers before it happens (AC-7.1). Offer a single-use Undo afterwards, valid until the collector's next removal in that session or the end of that session (AC-7.6).
- Report every outcome in the page's status message region with exact numbers, as `StatusMessage` specifies, pluralising counts ("1 item", "2 items", "1 lot").
- Answer a successful Set condition, Remove or Undo with a redirect (303): Set condition and Remove to the bulk table (AC-6.5, AC-7.3), Undo to the URL it carries (AC-7.4). This is a deliberate departure from `CollectionTable`'s "answer with Turbo Streams that replace the changed rows", because both actions are submitted from their own pages.
- Answer every refused action with 422, changing nothing, and show the message in the status region marked as an alert:
  - a refused Set condition re-renders the Set condition page
  - a refused Remove re-renders the confirmation page
  - a refused Undo re-renders the collection page at the URL it carries
  - an action button pressed with nothing selected re-renders the bulk table

  With scripting enabled, the same message may instead be delivered by updating the status region, leaving the page otherwise as it was.
- Return 422 with "Select at least one item." and change nothing when a bulk action is submitted with nothing selected.

**Must not:**
- Offer or perform Move to…, Lend or Update prices.
- Remove anything without the confirmation step.

### FR-6: Undo record

**Must:**
- Keep enough about each removed lot to restore it exactly: the printing, finish, condition, price paid and quantity. Key the printing by the same catalog reference lots use, so it survives a catalog refresh.
- Belong to the session that made the removal. Each session has at most one undoable record. However the session ends (sign-out, or 004 AC-5.3, AC-5.4, AC-5.7), its records are discarded.
- When a record is used or superseded, drop its lot data but keep the record as a stub without lot data until the session ends, so a replayed Undo answers 422 (AC-7.6). An unknown Undo, or one belonging to another session, answers 404 (AC-8.3).

**Must not:**
- Keep removed-lot data beyond the latest bulk removal per session, or after the session ends.

### FR-7: New design-system patterns

**Must:**
- Add a doc under `docs/design-system/components/` and token-only styles in the app's additions stylesheet for each pattern this feature needs that the export lacks, and list them in the design-system README. At least:
  - the status message with an action (Undo)
  - the sortable table header
  - the bulk confirmation page
  - the condition chooser page
  - bulk-mode paging and sorting controls that submit the selection
  - the view switch as a GET form, and `Edit many` and `Done` as submit buttons

**Must not:**
- Change the exported design-system files.

## Non-Functional Requirements

### Performance

- The table page returns in under 500 ms (server time) for an account with 5,000 lots, sorted by any column, on a typical developer machine. (Verified manually.)
- Set condition and Remove on "every matching lot" of 5,000 lots each complete in under 2 s (server time) on a typical developer machine. (Verified manually.)
- Rendering the table, with or without a selection, makes a bounded number of database queries, independent of the number of rows or selected lots.

### Security

- Every state-changing bulk and Undo request is CSRF-protected and scoped to the signed-in account and session. The view preference is saved only for the signed-in user (FR-1).
- Sort columns and directions are allowlisted. No request value is interpolated into a query.
- Lot, account and user identifiers in a request are checked against the signed-in account, never trusted (Story 8).

### Reliability

- Each bulk action is one all-or-nothing change: a failure part-way leaves every lot as it was.
- Schema changes are reversible and safe to run unattended on boot.
- A catalog refresh never changes lots, selections or undo records.

### Accessibility and responsiveness

- Every new control (view switch, sort headers, checkboxes, bulk bar, menus, Undo) is keyboard-operable, has a visible focus ring and an accessible name, and meets the design system's touch-target minimums. This is verified manually at 1280px and 390px, in light and dark themes.
- Selected rows are exposed as selected to assistive technology, and every status message is announced.
- Everything works from 360px wide, and with scripting disabled. Scripting only enhances: the live count and the header's mixed state, the filter's in-place results, status-region updates and Esc.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Unrecognised `view` in the URL | Saved view (grid if none), 200, preference unchanged |
| Unrecognised sort column or direction | Default sort, 200 |
| Table page number invalid or out of range | 200, first or last page |
| Bulk action submitted with nothing selected | 422, "Select at least one item.", nothing changes |
| Set condition to a value outside the collectible's scale | 422, "That isn't a known condition.", nothing changes |
| Set condition merge would exceed 9,999 | Nothing changes, status names the printing (AC-6.4), selection kept |
| Selected lot removed elsewhere (another tab) before the action runs | That lot is ignored; the message counts only the lots actually changed or removed |
| Selection names another account's lot | That id is ignored, like a missing lot (AC-8.1) |
| Every selected lot is gone or not the account's | 422, "None of the selected items are in your collection any more.", nothing changes |
| Undo after a later removal in the session, or used twice | 422, "This removal can no longer be undone.", nothing changes |
| Undo after signing out of the session that removed | Redirect to sign-in; after signing in, 404, nothing restored |
| Collection request marked as a prefetch naming a view | Page served; the saved view unchanged |
| Undo merge would exceed 9,999 | 422, nothing restored, status names the printing (AC-7.5) |
| Undo for another session's removal, or an unknown one | 404, nothing restored |
| Bulk mode with a filter that matches nothing | No-match message, "0 of 0 selected", no header checkbox; actions answer "Select at least one item." (AC-5.9) |
| `Edit many` or bulk URL on an empty collection | Empty-state page (004 AC-11.6), no bulk bar |
| Undo URL isn't a collection path on this instance | Ignored; the Undo still runs and lands on the collection in the saved view (AC-7.4) |
| Return path from row Edit/Remove isn't a path on this instance | Ignored; return to the card page (004 AC-7.3 rule) |

## Open Questions

None. Resolved during specification:
- Scope: table view, view switch with a saved per-user preference, sorting, bulk mode with Set condition and Remove.
- Row unit: one row per lot.
- Selection count: copies (quantity sum), matching the page's "items" counts.
- Set condition over the 9,999 cap: all or nothing.
- Undo: an Undo button in the status message, valid until the next removal or sign-out, with no time limit.
- Selection is kept across pages; changing the filter or sort, or leaving bulk mode, clears it.
- Row actions from the table return to the table (supersedes 004's card-page return for that path, AC-1.7).
- After the spec review: the selection is stored server-side per session; Set condition has its own page; rows have no actions menu in bulk mode; an Undo belongs to the session.

## Out of Scope (Future Considerations)

- Move to…, Lend and Update prices bulk actions (need locations, loans and market prices).
- Bulk-setting finish, price paid or quantity; bulk Add.
- Grid sort, and quick filters (set, finish, condition) in the filter bar.
- Undo for non-destructive bulk actions, and multi-step undo history.
- Bulk actions across collectible types with different condition scales.
- Collection export and import.
