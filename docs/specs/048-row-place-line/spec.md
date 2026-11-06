# Feature 048: A Table Row's Place Line Wraps (Supersedes Spec 033 Decision 5 for Rows)

**Status:** Draft, for the maintainer's approval. The maintainer ruled decisions 1–4 on 2026-10-27 and 2026-11-06 (below); decisions 5 and 6 are recommended
**Version:** 0.1.0
**Created:** 2026-11-06
**Last Updated:** 2026-11-06
**Depends on:** [spec 033](../033-location-on-tiles-and-rows/spec.md) (the place on tiles and rows, issue #46; merged, PR #140), [spec 037](../037-filter-collection-by-location/spec.md) (the location filter), all merged
**Branch:** `142-row-place-line`
**Issue:** [#142](https://github.com/plainprogrammer/Collector/issues/142)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-06 | First draft, from issue #142, spec 033's implementation review, and a probe in headless Firefox (below) |

## Problem Statement

Spec 033 decision 5 says a place line is "kept to one line and cut with an ellipsis when it doesn't fit", and its Terms define a place line as what a tile **or a row** shows. Tiles do that. Rows don't: the phone row's line under the name wraps (`additions.css`, "Row place (spec 033)"), and the wide Location cell never cut or wrapped a name. The implementation review of spec 033 found the difference; the maintainer chose to keep the shipped behaviour, and a shipped spec can't be edited, so this spec supersedes decision 5 for rows ([#142](https://github.com/plainprogrammer/Collector/issues/142)).

The issue left three points open and listed five test gaps. This spec settles the points, and the gaps close as examples and one guard. It changes one stylesheet rule set and no markup, data, export or migration.

> **Terms** are spec 033's (*tile*, *row*, *place line*, *lot*, *location*, *unplaced*) and spec 032's. A *name* is a location's name, 1 to 60 code points (spec 029). An *unbroken* name has no space in it.

**Probe (2026-11-06; headless Firefox, a fixed-width frame per width, one lot per run; table width against its container, which is the frame minus the page gutters).** The table's phone layout is below 640px of container width (frames up to about 735px).

| Place name | Phone (360, 390) | Wide, container 640 to 1280 |
|---|---|---|
| short ("Binder") | fits | fits |
| 20 characters, spaces | wraps to 2 lines at 360, fits | table 726px in a 705px container: slightly over |
| 40 characters, spaces | wraps, fits | table 830px: the page scrolls sideways up to a container of about 830px |
| 60 characters, spaces | wraps to 3 lines, fits | table 950px: scrolls up to a container of about 950px |
| 60 characters, **unbroken** | **table 779px in a 297px container: about 440px of sideways scroll** | table 1313px: scrolls at every width up to 1280 |
| no location in the account | one line at 360 and 390; nothing changes | nothing changes |

So the wide cell does make the table scroll sideways just above the breakpoint (issue point 2), and an unbroken name overflows even the phone row, which the issue did not suspect.

## Goals

- A table row shows the whole place name, wrapped when it is long, on a phone and on a wide table.
- No place name, of any shape up to 60 code points, makes the collection table scroll sideways.
- A tile keeps spec 033's one line with an ellipsis.
- Spec 033's test gaps from the issue are closed, and the `c-table__place` hook is documented.

## Non-Goals

- Changing a tile, or the markup, data, queries, export or sort of the grid and the table.
- A tooltip or a "show more" control for a name. The whole name is visible.
- The card page's "Your copies" Location column, the locations page and the filter's select, which show their own names (their own specs; the select's cap is spec 037's).
- The two other gaps in spec 033's `verification.md` that the issue does not list: AC-1.2's tie example (comparison key against raw name) and AC-1.7 resting on the unchanged main query. They stay as recorded.
- Hiding the Location column or the wrap rule for accounts with no location (decision 4).

## Decisions

### 1. Rows keep wrapping their place line on phones; decision 5's "one line, ellipsis" is for tiles only (ruled by the maintainer, 2026-10-27)

The phone row's line under the name wraps so a 60-code-point name fits 360px. A tile's place line is still one line cut with an ellipsis, with "+N more" kept visible (spec 033 AC-1.6). This is the one change to spec 033's decision 5 for rows.

### 2. The wide Location cell wraps at a maximum width of about 20rem (ruled by the maintainer, 2026-11-06, option B)

| | A. Truncate the cell with an ellipsis | B. Wrap the cell at a maximum width (ruled) |
|---|---|---|
| A 60-character name | cut to about 20 characters | 2 to 3 lines, whole |
| Sideways scroll | no | no (the column shrinks to fit before the table scrolls) |
| Names that share a prefix ("Blue binder, shelf 1", "…2", "…3") | the cut can hide the part that tells them apart | whole |
| Row height | constant | grows for a long name only |
| Consistent with the phone row (decision 1) | no | yes |

Option B: the cell's text wraps, its width is capped at about 20rem, and the table, which is as wide as its container, gives the column only the room it needs.

### 3. A name with no space in it breaks inside the name instead of overflowing, in the phone line and in the cell (ruled by the maintainer, 2026-11-06)

Wrapping at spaces isn't enough: the probe's unbroken name overflowed the phone table by about 440px. The cell and the phone line break anywhere in a word (`overflow-wrap: anywhere`) when it doesn't fit. The name's text is unchanged; only its layout breaks.

### 4. The phone wrap rule applies to every narrow collection table, an account with no location's too (ruled by the maintainer, 2026-11-06)

The rule is the `c-table__sub` line's, which every narrow table has. For an account with no location the line is set · number, finish, condition and language, which fits one line at 360 and 390 (probe), so the rule changes nothing visible there. A conditional class would add code for no visible effect, so the rule is not scoped.

### 5. `c-table__place` becomes a documented hook with a rule (recommended)

The class marks the Location cell (`<td class="is-opt c-table__place">`). It had no rule and no mention in the design system. Decision 2 gives it its rule, so it is documented in `CollectionTable.md` and the rule's comment cites this spec. Dropping the class is the alternative; it would leave the cell with no hook for decision 2 and the request specs' selector.

### 6. The test gaps close without changing behaviour (recommended)

Each gap is an example or a guard (Story 2). If an example fails, the failure is a bug of spec 033 and is fixed here and said in `verification.md`; none is expected, since the review judged each to hold by construction.

## Supersedes

| Spec | What it says | What changes |
|------|--------------|--------------|
| [Spec 033](../033-location-on-tiles-and-rows/spec.md) | Decision 5: a place line "is kept to one line and cut with an ellipsis when it doesn't fit"; AC-2.2: the phone table "never scrolls sideways at 360px" | For a **row**, the place line wraps (decisions 1–3) and the table never scrolls sideways at any width because of a place name. For a **tile**, decision 5 and AC-1.6 stand. The rest of spec 033 stands |

Recorded in the specs index in both directions, and in the collection and lots area doc. Spec 033's index row stops being "frozen in part" for decision 5 once this spec ships.

## User Stories

### Story 1: A long place name never makes the table scroll sideways

**As a** collector with a long location name
**I want** the whole name on my table rows, wrapped
**So that** I can read where a lot is, on a phone or a desktop, without scrolling sideways

- [ ] **AC-1.1** Given an account with a location named with 60 code points and spaces, and a lot in it When the table renders in a 360px frame and in a 390px frame Then the line under the name ends with the whole name, on as many lines as it needs, and the page doesn't scroll sideways (spec 033 AC-2.2).
- [ ] **AC-1.2** Given the same with a 60-code-point name with no space (decision 3) When the table renders at 360px and at 390px Then the name breaks inside itself, all of it is in the line's text, and the page doesn't scroll sideways.
- [ ] **AC-1.3** Given a 60-code-point name with spaces and a table wide enough for the Location column (a container of 640px or more) When it renders at frames of 760, 800, 900, 1024 and 1280px Then the whole name is in the cell, wrapped, and the table is no wider than the same table with a short name (it adds no sideways scroll).
- [ ] **AC-1.4** Given a 60-code-point name with no space When the table renders at the same widths Then the name breaks inside itself in the cell and the table is no wider than with a short name.
- [ ] **AC-1.5** Given a name with markup When a row renders Then it is output escaped in the cell and in the line (spec 032 AC-4.5), unchanged.
- [ ] **AC-1.6** Given the same lots When the grid renders Then a tile's place name is still on one line cut with an ellipsis and its "+N more" is still visible (spec 033 AC-1.6).
- [ ] **AC-1.7** Given an account with no location and a lot whose line is the longest the vocabulary gives it When the table renders at 360px and at 390px Then it fits without sideways scroll, shows no Location column and no place, and its line is one line high (decision 4).

### Story 2: Spec 033's test gaps are closed

**As a** maintainer
**I want** spec 033's criteria to have the examples the review found missing
**So that** a later change that breaks them fails the suite

- [ ] **AC-2.1** (spec 033 AC-1.8) Given two printings with places and a name filter that matches one When the grid renders Then only the matching printing has a tile and its tile shows all its printing's places, including "+N more" for places that no filter touched; given the same filter on the table Then only the matching lots' rows show, each with its place.
- [ ] **AC-2.2** (spec 033 AC-1.6) Given a printing in two places When the grid renders in a browser Then the tile's link's accessible name contains the whole place line, "Blue binder +1 more", after the card's name.
- [ ] **AC-2.3** (spec 033 AC-2.6) Given lots in places When a bulk "Set condition" is applied, and when a bulk Remove is undone Then the rendered bulk table shows each of those lots' rows with the place the lot keeps (an unplaced lot reads "No location").
- [ ] **AC-2.4** (spec 033 FR-6) Given the files spec 033 changed in core (the grid and table models, the filter, the helper, the tile, table and row-cell views) When the suite runs Then a `spec/*_core_spec.rb` guard lists them, fails if the list's size changes without an update, and fails if one names a collectible type or a source.

### Story 3: The hook and the rules are written where the next change reads them

**As a** maintainer
**I want** `c-table__place` and the supersession documented
**So that** nobody reads decision 5 as applying to rows, or meets an undocumented class

- [ ] **AC-3.1** The design system's `CollectionTable.md` names `c-table__place` and the wrap rules of the cell and the phone line; the rule's comment in `additions.css` cites this spec. (A document criterion: verified by reading, recorded in `verification.md`.)
- [ ] **AC-3.2** The specs index records this spec and its supersession of spec 033 in both directions, spec 033's row is no longer "frozen in part" for decision 5, and the collection and lots area doc states the row rule, drops the #142 entry from its accepted limits and cites this spec. (Verified by reading.)

## Functional Requirements

- **FR-1.** The change is in `app/assets/stylesheets/collector/additions.css` and the design-system docs: the cell's rule (`white-space: normal`, `overflow-wrap: anywhere`, `max-width: 20rem`) and the phone line's `overflow-wrap: anywhere`, both under spec 033's existing container query (`collection`, 640px). Tokens and `c-*` classes only; no markup, controller, model or query changes.
- **FR-2.** The tile's rules (`.c-tile__place*`) are not touched.
- **FR-3.** Core code names no collectible; AC-2.4's guard holds it.
- **FR-4.** The width is measured in a browser at the widths of AC-1.1–AC-1.4 (a system example with a fixed-width frame, `spec/support/narrow_frame.rb`), not asserted from the CSS.

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

None. Decisions 1–4 are the maintainer's rulings; decisions 5 and 6 are recommended and come to the maintainer with the spec.

## Notes for the plan

- Spec 033's system examples (`spec/system/collection_table_spec.rb`, "shows the place in the line under the name on a phone…") are the pattern; `open_in_narrow_frame` takes any width.
- Whether the `max-width` on a `td` holds in an auto-layout table, and whether the column shrinks before the table scrolls, is checked in headless Firefox first (FR-4); the value of about 20rem is the maintainer's, the examples decide whether the rule needs more than `max-width` to hold.
- `ItemTile.md` needs no change.

## Out of Scope (Future Considerations)

- Truncating or capping a location name's length anywhere else.
- A sort by location (spec 037 Non-Goals).

## Documents that change

- `docs/specs/README.md`: this spec's row; spec 033's "Superseded by" and its status line; spec 033's row stops being "frozen in part" for decision 5 (a small edit; `main` is merged in before the pull request, as session 4 (#104) edits the same file).
- `docs/architecture/collection-and-lots.md`: the place line bullet, the accepted-limits entry for #142 (dropped) and Sources (spec 033's "all"; spec 048).
- `docs/design-system/components/CollectionTable.md`: `c-table__place` and the two wrap rules.
- `docs/specs/033-location-on-tiles-and-rows/spec.md`: only its frozen line, in a commit of its own that names spec 027 D4, once this spec ships (`.claude/rules/documentation.md`).
- No ADR: the rulings are presentation rules recorded here.
