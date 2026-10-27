# Feature 034: Choose a Location During Typed Entry

**Status:** Approved by the maintainer (2026-10-26): decisions 1, 2 and 3 ruled as recommended (the field on each line; nothing new without locations; the place read from the lot, no column).
**Version:** 1.0.0
**Created:** 2026-10-26
**Last Updated:** 2026-10-26
**Depends on:** [spec 032](../032-lot-in-a-location/spec.md) (a lot's location is part of its identity; merged, PR #137) and [spec 026](../026-typed-entry/spec.md) (number entry, "Add by number")
**Branch:** `034-location-in-typed-entry`
**Issue:** [#51](https://github.com/plainprogrammer/Collector/issues/51) (roadmap item 16, theme C: locations)
**Plan:** retired in `5aa4a8fe0c8cada745d0535886aea2905e975f96`; read it with `git show 5aa4a8fe0c8cada745d0535886aea2905e975f96^:docs/specs/034-location-in-typed-entry/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-26 | Approved; decisions 1–3 ruled as recommended. |
| 0.1.0 | 2026-10-26 | Written from issue #51, spec 032 (decision 5, Story 7, AC-7.2, AC-7.6) and spec 026. |

---

## Problem Statement

Spec 032 made a lot's location part of its identity and left number entry adding unplaced copies, naming this issue to add the choice (032 decision 5, Non-Goals). A collector who sorts a box into a binder and types its cards in by number must now open each card to place the copies. Number entry is the one place a whole run of cards goes in at once, so it is where "these go into Blue binder" is said once.

**Outcome (issue #51):** cards added by number entry go straight into a chosen location.

## Goals

- A collector picks one of their locations on the number entry line, and each line adds its copies to the lot of that printing, finish and no condition or price in that place.
- The choice carries over from one line to the next, as the finish does, so a run into one binder is chosen once.
- A collector with no locations sees number entry exactly as it is.

## Non-Goals

- A location for the scanner's sitting (#56), the tile's quick add, or the bulk actions (#48). They keep adding unplaced copies (spec 032 decision 5).
- Creating a location from the number entry page. Locations are made at `/locations` (spec 029).
- Choosing a condition or a price paid on a line (spec 026 FR-3 "Must not").
- Any change to the export format, its version, the schema or the examples (decision 4).
- Showing the location on the collection grid or table (#46, spec 033).

## Decisions

### 1. A Location field on the line, kept after an add (recommended)

The line gains a fourth field, **Location**, after Finish in tab order: a select of the account's locations (`Location.ordered`, as the add and edit forms list them), with "No location" first and selected by default. It carries over after an add in the URL as `location` (the location's id), exactly as `finish` does (spec 026 decision 3), so it works without scripting and a reload or Back keeps it. The language form and "Change set" keep it the way they keep the finish.

Alternative: choose the place once per list, beside the chosen set, and not on each line. It reads as "this sitting goes into Blue binder", but it adds a second form and a state that is not on the line the collector is looking at; a collector who moves from one binder to the next mid-set would have to leave the line. The recommendation keeps the one form.

### 2. The field shows only when the account has a location (recommended)

An account with no locations sees no field and no hint, so a collector who never uses locations gets the page spec 026 shipped. The add and edit forms show a hint linking to `/locations` (spec 032); repeating it on a page the collector returns to line after line would be noise.

Alternative: show the field disabled with the same hint link. Rejected as above.

### 3. What is added, and what the page says

A line with a location adds through `Lot.add!(…, location:)`, so its copies merge into the lot of the same printing, finish, condition (none), price (none) and location (spec 032 decision 1), and the 9,999 cap holds per lot. A line with no location is spec 026's line unchanged: it merges into the unplaced lot only (spec 032 AC-7.2).

The added line, the notice and the Undo label name the place when there is one: "Added 2 × Psychic Frog (MH3 · 47, Foil) in Blue binder to your collection." and, in the list, "in Blue binder" after the finish. The place shown is the lot's place now, read through the already preloaded lot, so a line whose lot was moved shows where it is. No column is added to the line.

### 4. The list stays working state; nothing in the export changes

A line records the lot it went into; the lot carries the location. The list's tables are "Left out" of the export (spec 026 decision 6, FR-5) and gain no column, so the Coverage tables, the format and its version are unchanged. The choice itself lives only in the URL.

### 5. A location that is not the collector's, or is gone

The submitted `location` is looked up through `Current.account.locations`. A value that names no location of the account (removed in another tab, another account's id, or not a number) is a field error on Location ("That location isn't one of yours any more. Choose again."), nothing is added, and the line comes back as typed (Story 4 of spec 026). A page link whose `location` no longer exists shows the select at "No location"; it does not raise.

## Terms

- **Unplaced:** a lot with no location (spec 032).
- **Line:** one submission of number entry (spec 026).

## User Stories

### Story 1: Add cards into a location
As a collector with a binder to file, I want to choose it once and type numbers so the cards go in there.

- [ ] **AC-1.1** Given an account with locations When number entry has a set chosen Then each line has a Location select after Finish listing "No location" first and then the account's locations in the order of the locations page, with "No location" selected.
- [ ] **AC-1.2** Given Blue binder is chosen When the line "47", quantity 2 is added Then 2 copies of that printing and finish are in a lot in Blue binder, the notice and the list line say "in Blue binder", and the unplaced lot of that printing is unchanged.
- [ ] **AC-1.3** Given a lot of that printing and finish already in Blue binder When a line adds to Blue binder Then the copies join that lot (one lot, quantity summed), and a lot in Long box or unplaced is unchanged.
- [ ] **AC-1.4** Given a line was added to Blue binder When the page shows again Then Blue binder is still selected, with the number emptied, quantity 1 and the finish kept (spec 026 decision 3), and "Change language" keeps it too.
- [ ] **AC-1.5** Given "No location" is chosen When a line is added Then the copies join the unplaced lot only (spec 032 AC-7.2).
- [ ] **AC-1.6** Given a lot in Blue binder holds 9,990 copies When a line of 20 is added to Blue binder Then it is refused with the cap message and nothing is recorded; the same line to Long box is added (the cap is per lot).

### Story 2: Nothing changes without locations
- [ ] **AC-2.1** Given an account with no locations When number entry shows Then there is no Location field or hint, and a line adds unplaced copies as spec 026 says.
- [ ] **AC-2.2** Given an account with locations When a request names no `location` Then it adds unplaced copies (a link or a bookmark from before this spec keeps working).

### Story 3: Undo and the list
- [ ] **AC-3.1** Given a line added to Blue binder When Undo is used Then its copies come out of that lot and the lot goes when none are left (spec 026 AC-3.2, AC-3.3).
- [ ] **AC-3.2** Given a line added to Blue binder whose lot was then moved or merged When the list shows Then spec 032 AC-7.6 applies: undoable from where the lot now is, or "Changed in your collection" if it merged away or holds fewer than the line added; the line names the lot's place now.
- [ ] **AC-3.3** Given a line whose lot is gone When the list shows Then no place is named.

### Story 4: Errors keep the line
- [ ] **AC-4.1** Given a `location` that is another account's location, a removed one, or not a number When a line is submitted Then nothing is added, the Location field shows decision 5's message, and the number, quantity and finish are kept.
- [ ] **AC-4.2** Given a page link whose `location` names no location of the account When the page shows Then "No location" is selected and nothing raises.
- [ ] **AC-4.3** Given a line replayed with the same line key and a different location When it is submitted again Then nothing is added and the page answers as for the first (spec 026 decision 10).
- [ ] **AC-4.4** Given a number that matches more than one entry (the choice step, spec 026 AC-2.9) When the collector picks one Then the chosen Location is still selected.

### Story 5: Works without scripting
- [ ] **AC-5.1** The Location select is a native select in the line form; choosing a place and submitting needs no scripting, and Enter in it adds the line like the Finish select.

## Functional Requirements

### FR-1: The Location field
**Must:** appear only for an account with a location; list the account's locations only; be reached in tab order after Finish; take `location` from the page's URL and the form; show its error on its own field.
**Must not:** list another account's locations; create a location.

### FR-2: Adding
**Must:** add through `Lot.add!` with the account's own `Location`, in the same transaction as the line; keep spec 026 FR-3.
**Must not:** change a lot's other values; set a condition or price; record a line when the add fails.

### FR-3: Undo and Done
**Must:** keep spec 026 FR-4 unchanged.

### FR-4: Core code and export
**Must:** keep number entry's code free of any collectible type, source or finish name (`spec/number_entry_core_spec.rb`); leave the list out of the export with no new column.

## Non-Functional Requirements

- **Performance:** the locations load once per request for the select and once for the list's lots through the existing preload; no query per line.
- **Security:** `location` is read with `params.expect`, resolved through `Current.account.locations`, never trusted as an id of another account (404 is not used; a field error is, because the page is a form). A request spec proves another account's location is refused.
- **Design system:** the field uses the Finish select's markup and `c-*` classes; no new component or CSS is expected. The view change follows `docs/design-system/`.

## Error Scenarios

| Situation | Behaviour |
|---|---|
| `location` names another account's or a removed location | Field error, nothing added, line kept (AC-4.1) |
| Page link with a stale `location` | "No location" selected (AC-4.2) |
| Lot in the place at the 9,999 cap | Cap message, nothing recorded (AC-1.6) |
| Lot moved or merged after the add | Spec 032 AC-7.6 (AC-3.2) |

## Open Questions

None.

## Out of Scope (Future Considerations)

- A location for a scanner sitting (#56), for the quick add and for bulk entry (#48).
- Making a location from the number entry page.
- Remembering the last place per account across sittings.

## Documents that change

| Document | Change |
|---|---|
| [Spec 032](../032-lot-in-a-location/spec.md) | Decision 5 and Story 7 are superseded for number entry only: a line may carry a place (recorded here and in the specs index, not edited there) |
| [Spec 026](../026-typed-entry/spec.md) | Decision 3 gains a fourth field; FR-3's "unplaced" is superseded (recorded here) |
| `docs/specs/README.md`, `docs/roadmap.md` | A row for 034; item 16 marked built |
| `docs/architecture/` | The collection and lots area doc where one exists, else the note in `data-portability.md` that the list stays left out; decided at distillation |
