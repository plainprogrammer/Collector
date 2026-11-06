# Feature 048: A Table Row's Place Line Wraps (Supersedes Spec 033 Decision 5 for Rows)

**Status:** Approved by the coordinator under the maintainer's delegation (2026-11-06), at 0.4.0 after two spec review rounds. The maintainer ruled decisions 1–4 on 2026-10-27 and 2026-11-06 (below); the coordinator approved decisions 5 and 6, as recommended
**Version:** 0.4.0
**Created:** 2026-11-06
**Last Updated:** 2026-11-06
**Depends on:** [spec 033](../033-location-on-tiles-and-rows/spec.md) (the place on tiles and rows, issue #46; merged, PR #140), [spec 037](../037-filter-collection-by-location/spec.md) (the location filter), all merged
**Branch:** `142-row-place-line`
**Issue:** [#142](https://github.com/plainprogrammer/Collector/issues/142)
**Frozen:** the current rules are in [`collection-and-lots.md`](../../architecture/collection-and-lots.md) (whole spec); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.4.0 | 2026-11-06 | Approved at Gate A with two changes: spec 033's AC-1.2 tie example and AC-1.7 join Story 2 as AC-2.5 and AC-2.6 (they are in spec 033's `verification.md`, not in the issue), and the table's 16px overflow just above the breakpoint is filed as [#208](https://github.com/plainprogrammer/Collector/issues/208) and cited in Out of Scope. No review round for these two edits |
| 0.3.0 | 2026-11-06 | Spec review round 2 (NEEDS REVISION, mechanical; 1 major, 5 minor) fixed: the wide frames start at 800px because a table with a short name is already wider than a 645px container (M1); the span is on the named cell only (m2); decision 4 states the phone rule's reach (m3); AC-1.3 and AC-1.4 name how the width is measured (m4); AC-2.1's setup is exact (m5); the guard's file and the seven paths are named (m6). No round 3; the worker checked the edits |
| 0.2.0 | 2026-11-06 | Spec review round 1 (NEEDS REVISION; 0 blocking, 2 major, 10 minor) fixed. A second probe (below) found Firefox ignores `max-width` on a table cell, so the cap goes on a span inside the cell (M1, FR-1, decision 2); AC-2.2 of spec 033 is extended, not superseded (m3); spec 033 FR-5 is added to Supersedes (m4); AC-1.3 and AC-1.4 measure once (m5); AC-2.4 is an explicit-list guard (m6); AC-2.3's Undo, AC-1.7, AC-1.2, AC-2.2 and AC-2.1 sharpened (m7–m10, m12); documents list completed (M2, m11) |
| 0.1.0 | 2026-11-06 | First draft, from issue #142, spec 033's implementation review, and a probe in headless Firefox (below) |

## Problem Statement

Spec 033 decision 5 says a place line is "kept to one line and cut with an ellipsis when it doesn't fit", and its Terms define a place line as what a tile **or a row** shows. Tiles do that. Rows don't: the phone row's line under the name wraps (`additions.css`, "Row place (spec 033)"), and the wide Location cell never cut or wrapped a name. The implementation review of spec 033 found the difference; the maintainer chose to keep the shipped behaviour, and a shipped spec can't be edited, so this spec supersedes decision 5 for rows ([#142](https://github.com/plainprogrammer/Collector/issues/142)).

The issue left three points open and listed five test gaps. This spec settles the points, and the gaps close as examples and one guard. It changes the stylesheet, one span in one view's cell, and no data, query, export or migration.

> **Terms** are spec 033's (*tile*, *row*, *place line*, *lot*, *location*, *unplaced*) and spec 032's. A *name* is a location's name, 1 to 60 code points (spec 029). An *unbroken* name has no space in it.

**Probe 1 (2026-11-06; headless Firefox, a fixed-width frame per width, one lot per run; table width against its container, which is the frame minus about 95px of page gutters).** The table's phone layout is below 640px of container width (frames up to about 735px); "wide" below means frames of 740px to 1280px.

| Place name | Phone (frames 360, 390) | Wide (frames 740 to 1280) |
|---|---|---|
| short ("Binder") | fits | fits |
| 20 characters, spaces | wraps to 2 lines at 360, fits | table 726px in a 705px container: slightly over |
| 40 characters, spaces | wraps, fits | table 830px: the page scrolls sideways up to a container of about 830px |
| 60 characters, spaces | wraps to 3 lines, fits | table 950px: scrolls up to a container of about 950px |
| 60 characters, **unbroken** | **table 779px in a 297px container: about 440px of sideways scroll** | table 1313px: scrolls at every width up to 1280 |
| no location in the account | one line at 360 and 390; nothing changes | nothing changes |

So the wide cell does make the table scroll sideways just above the breakpoint (issue point 2), and an unbroken name overflows even the phone row, which the issue did not suspect.

**Probe 2 (the proposed rules injected into the same frames, `td.c-table__place { white-space: normal; overflow-wrap: anywhere }` with and without `max-width: 20rem`, and `.c-table__sub { overflow-wrap: anywhere }`).**

- No sideways scroll at any frame from 360 to 1280, for a short name, a 60-character name with spaces and a 60-character unbroken name: the wrapping works.
- `max-width` on the `td` did nothing in Firefox: the cell with a 60-character name took 442px at 1280 with the cap and 454px without. The cap needs an element inside the cell (decision 2).
- The cost of fitting: near the breakpoint the other columns keep their width and the Location column shrinks to its longest word (about 71px at a container of 645px), so a 60-character name takes 4 to 5 lines there (row height about 200px against 53px) and 1 line at a container of about 1000px or more. At a container of 645px the table is 16px wider than its container even with a short name; that is the other columns', not a place's, and is not changed here.

## Goals

- A table row shows the whole place name, wrapped when it is long, on a phone and on a wide table.
- No place name, of any shape up to 60 code points, makes the collection page scroll sideways.
- A tile keeps spec 033's one line with an ellipsis.
- Spec 033's test gaps, the issue's five and the two more in its `verification.md`, are closed, and the `c-table__place` hook is documented.

## Non-Goals

- Changing a tile, or the data, queries, export, sort or columns of the grid and the table, or the width of a table whose short names already overflow near the breakpoint.
- A tooltip or a "show more" control for a name. The whole name is visible.
- The card page's "Your copies" Location column, the locations page and the filter's select, which show their own names (their own specs; the select's cap is spec 037's).
- Hiding the Location column or the wrap rule for accounts with no location (decision 4).

## Decisions

### 1. Rows keep wrapping their place line on phones; decision 5's "one line, ellipsis" is for tiles only (ruled by the maintainer, 2026-10-27)

The phone row's line under the name wraps so a 60-code-point name fits 360px. A tile's place line is still one line cut with an ellipsis, with "+N more" kept visible (spec 033 AC-1.6). This is the one change to spec 033's decision 5 for rows.

### 2. The wide Location cell wraps at a maximum width of about 20rem (ruled by the maintainer, 2026-11-06, option B)

| | A. Truncate the cell with an ellipsis | B. Wrap the cell at a maximum width (ruled) |
|---|---|---|
| A 60-character name | cut to about 20 characters | 2 to 3 lines, whole |
| Sideways scroll | no | no (probe 2: the column shrinks to fit before the table scrolls) |
| Names that share a prefix ("Blue binder, shelf 1", "…2", "…3") | the cut can hide the part that tells them apart | whole |
| Row height | constant | grows for a long name only: 1 line from a container of about 1000px, up to 5 near the 640px breakpoint (probe 2) |
| Consistent with the phone row (decision 1) | no | yes |

Option B: the cell's text wraps, the name's width is capped at about 20rem, and the table, which is as wide as its container, gives the column only the room it needs. Firefox ignores `max-width` on a table cell (probe 2), so the name sits in a `span` inside the cell and the cap is on the span.

### 3. A name with no space in it breaks inside the name instead of overflowing, in the phone line and in the cell (ruled by the maintainer, 2026-11-06)

Wrapping at spaces isn't enough: the probe's unbroken name overflowed the phone table by about 440px. The cell and the phone line break anywhere in a word (`overflow-wrap: anywhere`) when it doesn't fit. The name's text is unchanged; only its layout breaks.

### 4. The phone wrap rule applies to every narrow collection table, an account with no location's too (ruled by the maintainer, 2026-11-06)

The rule is the `c-table__sub` line's, which every narrow table has. For an account with no location the line is set · number, finish, condition and language, which fits one line at 360 and 390 (probe), so the rule changes nothing visible there. A conditional class would add code for no visible effect, so the rule is not scoped. Its reach is the rule's selector's: the `c-table__sub` line of every table inside `.c-collection` below 640px, the card page's "Your copies" line, whose place the line carries, and the admin and catalog tables' sub lines included; accepted, as spec 033's `white-space: normal` already applies there. The card page's own Location column is not changed.

### 5. `c-table__place` becomes a documented hook with a rule (recommended)

The class marks the Location cell (`<td class="is-opt c-table__place">`). It had no rule and no mention in the design system. Decision 2 gives it its rule (`white-space: normal`), and the new `span.c-table__place-name` inside it holds the cap and the break rule. Both are documented in `CollectionTable.md` and the rules' comments cite this spec. Dropping `c-table__place` is the alternative; it would leave the cell with no hook and the request specs' selector.

### 6. The test gaps close without changing behaviour (recommended)

Each gap is an example or a guard (Story 2). If an example fails, the failure is a bug of spec 033 and is fixed here and said in `verification.md`; none is expected, since the review judged each to hold by construction.

## Supersedes

| Spec | What it says | What changes |
|------|--------------|--------------|
| [Spec 033](../033-location-on-tiles-and-rows/spec.md) | Decision 5: a place line "is kept to one line and cut with an ellipsis when it doesn't fit"; FR-5's "Truncation (Decision 5) uses an existing rule if one fits" | For a **row**, the place line wraps (decisions 1–3). For a **tile**, decision 5, FR-5 and AC-1.6 stand. AC-2.2 (the phone table never scrolls sideways at 360px) is extended, not superseded: it now holds for any name and any width (Story 1). The rest of spec 033 stands |

Recorded in the specs index in both directions, and in the collection and lots area doc. Spec 033's index row stops being "frozen in part" for decision 5 once this spec ships. Spec 006 AC-2.8 (the phone line's content) is untouched.

## User Stories

### Story 1: A long place name never makes the table scroll sideways

**As a** collector with a long location name
**I want** the whole name on my table rows, wrapped
**So that** I can read where a lot is, on a phone or a desktop, without scrolling sideways

- [ ] **AC-1.1** Given an account with a location named with 60 code points and spaces, and a lot in it When the table renders in a 360px frame and in a 390px frame Then the line under the name ends with the whole name, on as many lines as it needs, and the page doesn't scroll sideways (spec 033 AC-2.2).
- [ ] **AC-1.2** Given the same with a name of 60 "W"s (60 code points, no space, the widest glyph; decision 3) When the table renders at 360px and at 390px Then the name breaks inside itself, all of it is in the line's text, and the page doesn't scroll sideways.
- [ ] **AC-1.3** Given a 60-code-point name with spaces and the wide table When it renders at frames of 800, 900, 1024 and 1280px (containers of 705px and more; below about 735px of frame the table's other columns alone are wider than a 645px container, which a place can't change) Then the whole name is in the cell, wrapped, the name's span is at most 20rem wide (its `getBoundingClientRect().width` is at most 20 times the root font size), the table is no wider than `.c-collection` (its `clientWidth`) and the page doesn't scroll sideways.
- [ ] **AC-1.4** Given a name of 60 "W"s When the table renders at the same frames Then the name breaks inside itself in the cell, within the same 20rem, and the table is no wider than `.c-collection` and the page doesn't scroll sideways. At a frame of 760px the page still doesn't scroll sideways for either name (no table wider than its container is asked of it there).
- [ ] **AC-1.5** Given a name with markup When a row renders Then it is output escaped in the cell and in the line (spec 032 AC-4.5), unchanged.
- [ ] **AC-1.6** Given the same lots When the grid renders Then a tile's place name is still on one line cut with an ellipsis and its "+N more" is still visible (spec 033 AC-1.6).
- [ ] **AC-1.7** Given an account with no location and a lot of number 146, foil, near mint, English, quantity 9,999 (spec 006 AC-2.8's line) When the table renders at 360px and at 390px Then it fits without sideways scroll, shows no Location column and no place, and its `c-table__sub` is under 20px high, one line (decision 4).

### Story 2: Spec 033's test gaps are closed

**As a** maintainer
**I want** spec 033's criteria to have the examples the review found missing
**So that** a later change that breaks them fails the suite

- [ ] **AC-2.1** (spec 033 AC-1.8) Given an account with locations, a printing in two places (3 copies in Blue binder, 1 in Long box), another printing in one place, and the name filter `q` matching only the first When the grid renders Then only the matching printing has a tile and its tile shows all its printing's places, including "+N more"; given the same filter on the table Then only the matching lots' rows show, each with its place. (Under a location filter spec 037 decision 3 applies instead: no place line; the example is for the name filter.)
- [ ] **AC-2.2** (spec 033 AC-1.6) Given a printing in two places When the grid renders in a browser Then the tile's link's accessible name, as the browser computes it (a system example, `native.accessible_name`), contains the whole place line, "Blue binder +1 more", after the card's name.
- [ ] **AC-2.3** (spec 033 AC-2.6) Given lots in places When a bulk "Set condition" is applied, and when a bulk Remove is undone Then the rendered bulk table shows each of those lots' rows with the place the lot keeps (an unplaced lot reads "No location" in its Location cell). The Undo is the one on the bulk table's message, carrying the bulk table's URL.
- [ ] **AC-2.4** (spec 033 FR-6) Given the seven core files spec 033 changed (`collection_grid.rb`, `collection_table.rb`, `collection_filter.rb`, `lots_helper.rb`, and the views `_tile`, `_table`, `_lot_cells`; not `additions.css`) When the suite runs Then a new `spec/collection_places_core_spec.rb` lists them by path (`app/models/collection_grid.rb`, `app/models/collection_table.rb`, `app/models/collection_filter.rb`, `app/helpers/lots_helper.rb`, `app/views/collections/_tile.html.erb`, `_table.html.erb`, `_lot_cells.html.erb`), fails if one no longer exists, and fails if one names a collectible type or a source (`mtg`, `scryfall`, `magic`; finish names are not checked, as a comment in `lots_helper.rb` names one).
- [ ] **AC-2.5** (spec 033 AC-1.2's tie) Given a printing with 2 copies in a location named "Beta shelf" and 2 in one named "alpha shelf" When the grid renders Then its tile shows "alpha shelf +1 more": the comparison key (folded case) orders the tie, where the raw name would put "Beta shelf" first.
- [ ] **AC-2.6** (spec 033 AC-1.7) Given an account with a location, and a printing with 3 foil copies and 1 non-foil copy, first all unplaced and then the foil lot placed When each grid renders Then the tile's quantity ("×4"), its finish badge, its set tag, its language tag, its link and its position among the tiles, and the page's counts, are the same in both (the place line is the only difference).

### Story 3: The hook and the rules are written where the next change reads them

**As a** maintainer
**I want** `c-table__place` and the supersession documented
**So that** nobody reads decision 5 as applying to rows, or meets an undocumented class

- [ ] **AC-3.1** The design system's `CollectionTable.md` names `c-table__place` and `c-table__place-name` and the wrap rules of the cell and the phone line; its README's list of app additions records the override of the export's `.c-table td { white-space: nowrap }`; the rules' comments in `additions.css` cite this spec. (A document criterion: verified by reading, recorded in `verification.md`.)
- [ ] **AC-3.2** The specs index records this spec and its supersession of spec 033 in both directions, spec 033's row is no longer "frozen in part" for decision 5, and the collection and lots area doc states the row rule, drops the #142 entry from its accepted limits, names `spec/collection_places_core_spec.rb` in its core-code invariant, records the decision (a row's place line wraps, a tile's is cut), cites this spec in Sources and adds a distillation-log entry. (Verified by reading.)

## Functional Requirements

- **FR-1.** The outcome is Story 1's. The mechanism, from probe 2: the Location cell `white-space: normal`; a `span.c-table__place-name` inside it (the only markup change, in `_lot_cells.html.erb`; the named cell only, the muted "No location" cell is unchanged; the text is the name as before) with `display: block`, `max-width: 20rem` and `overflow-wrap: anywhere`; and `overflow-wrap: anywhere` added to the phone line's rule in spec 033's container query (`collection`, 640px). The rules are in `additions.css`, tokens and `c-*` classes only. No controller, model or query changes. If an AC's measurement shows a rule isn't enough, the plan adjusts the rule, not the criterion.
- **FR-2.** The tile's rules (`.c-tile__place*`) are not touched.
- **FR-3.** Core code names no collectible; AC-2.4's guard holds it.
- **FR-4.** The widths are measured in a browser at the frames of AC-1.1–AC-1.4 and AC-1.7 (a system example with a fixed-width frame, `spec/support/narrow_frame.rb`; a 1280px frame fits the suite's browser window), not asserted from the CSS.

## Non-Functional Requirements

- **Accessibility:** a name is a word the whole of which stays in the text a screen reader reads; nothing is hover-only; wrapping and breaking change layout, not text. Secondary ink and contrast are as before.
- **Responsive and themes:** checked at 1280px and 390px, light and dark, against the `CollectionTable` preview, with a 60-code-point name.
- **Compatibility:** no migration, no schema change, export format unchanged at version 3, upgrade-safe from the previous release.
- **Hosted-door cost per account (north star rule 4):** none; a stylesheet rule and tests.

## Error Scenarios

| Scenario | Behaviour |
|---|---|
| A name of 60 code points with no space | Breaks inside the name, in the cell and in the phone line (decision 3) |
| A name with markup | Escaped, as before |
| An account with no location | No Location column and no place on the line; the wrap rule is present and changes nothing (decision 4) |
| A name that fits | Looks as before |

## Open Questions

None. Decisions 1–4 are the maintainer's rulings; decisions 5 and 6 were approved as recommended at Gate A (the coordinator, under the maintainer's delegation).

## Notes for the plan

- Spec 033's system examples (`spec/system/collection_table_spec.rb`, "shows the place in the line under the name on a phone…") are the pattern; `open_in_narrow_frame` takes any width.
- Probe 2 injected the rules into rendered pages; the plan's first task writes the system examples for AC-1.1–AC-1.4 and sees them fail on the shipped CSS before any rule is written.
- Request specs select the cell by `td.c-table__place` and read its text, which the span leaves unchanged.
- `ItemTile.md` needs no change.

## Out of Scope (Future Considerations)

- Truncating or capping a location name's length anywhere else.
- A sort by location (spec 037 Non-Goals).
- The wide table being up to about 20px wider than its container for containers of 640px to about 660px even with a short name (probe 2: 661px in a 645px container). A place doesn't cause it and nothing scrolls; filed as [#208](https://github.com/plainprogrammer/Collector/issues/208).

## Documents that change

- `docs/specs/README.md`: this spec's row; spec 033's "Superseded by" cell; spec 033's status stops being "frozen in part" for decision 5 (a small edit; `main` is merged in before the pull request, as session 4 (#104) edits the same file).
- `docs/architecture/collection-and-lots.md`: the place line bullet (citation and the row rule); the core-code invariant, which names the new guard and no longer says no guard lists spec 033's files; the accepted-limits entry for #142 (dropped); Decisions not in an ADR (a row's place line wraps, a tile's is cut); Sources (spec 033 "all", spec 048); and the distillation log.
- `docs/design-system/components/CollectionTable.md`: `c-table__place`, `c-table__place-name` and the two wrap rules. `docs/design-system/README.md`: the app additions list, for the override of `.c-table td { white-space: nowrap }`.
- `docs/specs/033-location-on-tiles-and-rows/spec.md`: only its frozen line, in a commit of its own that names spec 027 D4, once this spec ships (`.claude/rules/documentation.md`).
- No ADR: the rulings are presentation rules recorded here.
