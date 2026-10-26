# Feature 033: Show the Location on Tiles and Rows

**Status:** Approved by the maintainer (2026-10-26), with decisions 1–4 as recommended
**Version:** 1.0.0
**Created:** 2026-10-26
**Last Updated:** 2026-10-26
**Depends on:** [spec 032](../032-lot-in-a-location/spec.md) (a lot in a location, issue #45; merged, PR #137)
**Branch:** `033-location-on-tiles-and-rows`
**Issue:** [#46](https://github.com/plainprogrammer/Collector/issues/46)
**Plan:** [plan.md](plan.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-26 | Approved by the maintainer; decisions 1–4 stand as recommended. Status line only; no criterion changes |
| 0.1.0 | 2026-10-26 | First draft |

## Problem Statement

The design system says players need "where is it" as much as "what is it", and that location sits next to the item name, not on a detail page; its `ItemTile` and `CollectionTable` documents both carry a location. Spec 032 let a collector put a lot in a location but, by its Non-Goals and decision 5, left the collection grid and table unchanged. Today the only place a collector sees where a lot is, is the card page's "Your copies" table (spec 032 Story 4). To answer "where is my Serra Angel?" they open its card page, for every card.

This spec shows the location on the collection's grid tiles and table rows. It adds no data: a lot's location exists since spec 032, so there is no migration, no change to the export and no new column.

> **Terms.** *Lot*, *location*, *unplaced* ("No location" on screen), *place* and *card page* are as in spec 032. A *tile* is one grid cell: one owned **printing**, summing its lots (spec 004 AC-11.2). A *row* is one table row: one **lot** (spec 006 AC-2.1). A *place line* is the text a tile or a row shows for its places.

## Goals

- A tile says where its copies are; a table row says where its lot is, in the place the design system gives: under the name on a tile, a Location column on a wide row, and the line under the name on a phone.
- A printing in several places reads honestly on its tile: it never shows one place as if it were the only one.
- Nothing else about the grid and table changes: the counts, the order, the paging, the filter, the bulk mode and the bulk actions behave as before.
- The number of queries a page makes stays independent of the number of tiles and rows (spec 004 NFR, spec 006).

## Non-Goals

- Filtering by location (#47), sorting by it, and "Move to…" on many lots (#48).
- Choosing a location in the quick add, typed entry or the scanner (#51, #56).
- Showing a location on search results or on the printings page (those tiles are the catalog's, spec 004 AC-6.2; a location belongs to an owned lot).
- Decks, "In decks" and "Free to use" (#49, #50).
- Changing the card page or the locations page.
- Anything in the export, the preview or the apply: no collector-owned data is added, so the export format stays at version 3.

## Users and Context

**Primary users:** a signed-in collector who keeps cards in binders and boxes and scans the grid for "where is it" without opening cards.
**Usage context:** a few thousand lots (the design system designs for 5,000 first), a dozen to a few hundred places, on a phone or a desktop.
**User mental model:** "I'm looking at my Serra Angels. The tile says Blue binder; the other says Blue binder +1 more because two are in the long box."

## Decisions

The maintainer ruled each as recommended (2026-10-26). None changes data.

### 1. A tile shows the place with most copies, then how many other places (ruled)

A tile sums lots, and since spec 032 a printing can be in several places. Options:

| | A. One place line, most copies first, "+N more" (recommended) | B. Every place named | C. One tile per printing and place |
|---|---|---|---|
| Tile with one place | "Blue binder" | "Blue binder" | Same |
| Tile with several | "Blue binder +1 more" | "Blue binder, Long box, No location" (wraps, grows the grid unevenly) | Several tiles of one printing; breaks "one tile per printing" (spec 004 AC-11.2), paging counts and the quantity (×4) |
| Honest | Yes: "+1 more" says there is another | Yes | Yes |
| Cost | One grouped query for the page's printings | Same | Changes the grid's grouping, order and count |

**Recommendation: A.** The place with the most copies comes first (ties: the comparison key, then unplaced last); "+N more" counts the other places, unplaced counting as a place. The full list is the card page's, one click away. B makes tiles uneven at 5,000 rows; C changes what a tile is.

### 2. No location line when the account has no locations (ruled)

An account with no locations (the Location field is hidden from its forms, spec 032 P3) would see "No location" on every tile and row. **Recommendation:** show no place line and no Location column while the account has no location; they appear once it has one. Spec 032 P3 already treats "no locations" as "nothing to say about places".

### 3. An unplaced lot reads "No location", muted (ruled)

Spec 032 decision 2 names the on-screen word. On a tile or row of an account that has locations, an unplaced lot shows "No location" in secondary ink (`ink-muted`, a word, never colour alone); a tile of several places shows it as one of them (Decision 1). An em dash would be a symbol with no word.

### 4. The Location column is not sortable (ruled)

Sorting by location is a feature of its own beside the filter (#47). The header is a plain `th`. **Recommendation:** leave sort to #47; the spec records it so the issue is not read as promising it.

### 5. A place line is text, escaped, one line (ruled by the design system)

A location name is collector text (1 to 60 code points, spec 029): it is output escaped (spec 032 AC-4.5), kept to one line and cut with an ellipsis when it doesn't fit, and its full text stays available to assistive technology. Nothing is hover-only (design system, States).

## Supersedes

| Spec | What it says | What changes |
|------|--------------|--------------|
| [Spec 032](../032-lot-in-a-location/spec.md) | Non-Goals ("Showing a location on tiles and rows (#46)… The collection grid and table don't change"); decision 5 and the paragraph after it ("The grid, table… don't gain a place"); AC-4.4 ("neither view shows a location") | The grid and the table show the place, as this spec says. The rest of decision 5 stands: the quick add, typed entry, the scanner and the bulk actions neither choose nor change a place, and AC-4.4's counts (copies, lots and owned counts include placed lots as unplaced ones) stand |
| [Spec 004](../004-design-system-collection/spec.md) | AC-11.2 (what a tile shows); the Non-Goal "no location on a copy, so tiles have no location line" | A tile gains the place line of Story 1 |
| [Spec 006](../006-collection-list-view/spec.md) | AC-2.1 (the table's columns); AC-2.8 (the phone table's line under the name) | The table gains a Location column; the phone line gains the place (Story 2) |

Recorded in the specs index in both directions.

## User Stories

### Story 1: A tile says where its copies are

**As a** signed-in collector
**I want** each tile in my collection grid to say where its copies are
**So that** I can find a card without opening it

- [ ] **AC-1.1** Given an account with locations and a printing whose lots are all in Blue binder When the grid renders Then its tile shows "Blue binder" under the name, in the tile's meta line.
- [ ] **AC-1.2** Given a printing with 3 copies in Blue binder and 1 in Long box When the grid renders Then its tile shows "Blue binder +1 more"; given 2 and 2 Then the name that sorts first by comparison key comes first (Decision 1).
- [ ] **AC-1.3** Given a printing with 2 copies in Blue binder, 1 in Long box and 1 unplaced When the grid renders Then its tile shows "Blue binder +2 more" (the unplaced lot counts as a place).
- [ ] **AC-1.4** Given a printing whose copies are all unplaced, in an account that has locations When the grid renders Then its tile shows "No location" in secondary ink; given 1 copy unplaced and 3 in Long box Then it shows "Long box +1 more".
- [ ] **AC-1.5** Given an account with no locations When the grid renders Then no tile has a place line (Decision 2); given it then adds a location Then every tile shows one.
- [ ] **AC-1.6** Given a location name with markup, or of 60 code points When a tile renders Then the name is output escaped, stays on one line and is cut with an ellipsis, and the tile's accessible name still contains the whole place line.
- [ ] **AC-1.7** Given the tile for a printing with placed lots When it renders Then its quantity (×4), finish badge, set tag, language tag, link and order are those of spec 004 AC-11.2 and AC-11.3, and the page's totals and counts are unchanged (spec 032 AC-4.4).
- [ ] **AC-1.8** Given a filter that matches some printings When the grid renders Then only the matching printings' places are read, and a tile shows all its printing's places (the filter is on the name, not on a place).

### Story 2: A row says where its lot is

**As a** signed-in collector
**I want** each table row to show its lot's place
**So that** I can scan places down a column, and pick lots in bulk mode knowing where they are

- [ ] **AC-2.1** Given an account with locations When the table renders at 640px of container width or more Then it has a "Location" column after Qty and before Paid, showing the lot's location name, or "No location" in secondary ink for an unplaced lot.
- [ ] **AC-2.2** Given the same table below 640px When it renders Then the Location column is hidden (`is-opt`) and the line under the name gives set · number, finish, condition, language and the place (the place last; "No location" is left out of the line for an unplaced lot), and the table never scrolls sideways at 360px (spec 006 AC-2.8).
- [ ] **AC-2.3** Given bulk mode When the table renders Then each row shows the same place as outside bulk mode, a row's checkbox name (spec 006 AC-2.5) is unchanged, and selecting, "Select all", the count and every bulk action behave as before (spec 006 Story 5).
- [ ] **AC-2.4** Given an account with no locations When the table renders Then it has no Location column and the phone line has no place (Decision 2).
- [ ] **AC-2.5** Given a column header When it renders Then "Location" is a plain header, not a sort link (Decision 4); the sort and `aria-sort` of the other columns are unchanged.
- [ ] **AC-2.6** Given a lot whose location was renamed on the locations page When the table renders Then it shows the new name; given a bulk "Set condition" or Undo (spec 032 AC-7.3, AC-7.4) Then the rows come back showing the places the lots keep.

### Story 3: Only my places, and a bounded cost

**As a** collector sharing an instance
**I want** my grid and table to show only my places, quickly
**So that** nobody sees another account's locations and a large collection stays fast

- [ ] **AC-3.1** Given two accounts with lots and locations When either collection's grid or table renders Then it shows only that account's location names, and a request cannot make it show another's (a request spec seeds both accounts; tenant isolation, `.claude/rules/multi-tenancy.md`).
- [ ] **AC-3.2** Given a page of 120 tiles, and a page of 120 rows, each with places When it renders Then the number of database queries is the same as with 1 tile or row plus the constant the places add, independent of the number of tiles, rows, lots or locations (spec 004 NFR; a query-count spec, like spec 006's).
- [ ] **AC-3.3** Given an account with 5,000 lots over 300 locations When a page renders Then it stays within the page budgets of spec 004 and spec 006 (measured in the plan; no new index is expected, the lots' `location_id` is indexed by spec 032).
- [ ] **AC-3.4** Given a signed-out visitor, or a page of the catalog (search results, the printings page) When rendered Then neither shows a place (Non-Goals).

## Functional Requirements

- **FR-1.** A tile's place line is derived from the account's lots of the tile's printing: group by location, order by copies descending, then comparison key, then unplaced last; one name plus "+N more" for N other places (Decision 1).
- **FR-2.** The place lines of a page are read in a bounded number of statements for the page's printings (FR-1's grouping once for all 120), never one query per tile or per row; rows preload their location.
- **FR-3.** "Has locations" is read once per request (`account.locations.exists?`) and decides the column and the lines (Decision 2).
- **FR-4.** The views receive prepared values; no query or rule is in a view or partial (`.claude/rules/hotwire.md`).
- **FR-5.** The markup is the design system's: the tile's `c-tile__meta` and the table's cells and `c-table__sub`, with tokens only. Truncation (Decision 5) uses an existing rule if one fits; if not, a documented addition in `collector/additions.css` with a component doc.
- **FR-6.** Core code names no collectible: the place line and the column are in core views and models (`spec/…_core_spec.rb` style, as spec 032).

## Non-Functional Requirements

- **Performance:** AC-3.2 and AC-3.3. The grouping adds one statement to the grid; the table adds no statement (a preload of `location`).
- **Accessibility:** a place is a word, never colour alone; secondary ink holds 4.5:1 on `surface` in both themes; the tile's link name includes its place line; touch targets are unchanged (the tile is already one link).
- **Responsive and themes:** checked at 1280px and 390px, light and dark, against the `ItemTile` and `CollectionTable` previews.
- **Hosted-door cost per account (north star rule 4):** no stored data and no job. One extra grouped read per grid page and one preload per table page, bounded by the page size of 120.
- **Compatibility:** no migration, no schema change, export format unchanged at version 3, upgrade-safe from the previous release.

## Error Scenarios

| Scenario | Behaviour |
|----------|-----------|
| A lot whose location was removed | Cannot exist: a location that holds a lot is not removed (spec 032 decision 3) |
| A bulk Undo that restores lots unplaced (spec 032 P5) | Their rows and tiles show "No location" |
| A name with markup or at 60 code points | Escaped, one line, ellipsis (AC-1.6) |
| A signed-out visitor | Sent to sign in as before |

## Open Questions

The maintainer approved decisions 1–4 as recommended (2026-10-26). No question remains.

## Notes for the plan

- A tile's lots are grouped in `CollectionGrid#tiles`; the place data is one more grouped read over the same `matching_lots`-independent set (all the printing's lots, Story 1 AC-1.8), keyed by the page's entry ids.
- `lot_summary` (`LotsHelper`) feeds the card page's and the refusal page's lists too; the phone line gets the place without changing those lists.
- Check `docs/design-system/previews/ItemTile.html` and `CollectionTable.html` for the place's markup before writing a view.

## Out of Scope (Future Considerations)

- The filter by location (#47), a sort by it, "Move to…" (#48), decks as locations and "Free to use" (#49, #50).
- A per-place quantity on a tile ("Blue binder ×2").
- A location on the catalog's tiles.

## Documents that change

- `docs/specs/README.md`: this spec's row and the supersessions above, in both directions (a small edit; `main` is merged in before the pull request).
- `docs/roadmap.md`: item 11 built with this spec (a small edit).
- `docs/design-system/components/ItemTile.md`, `CollectionTable.md` (and the README's app additions if a class is added): the place line, "+N more", "No location", the column and the phone line.
- `CLAUDE.md`: one clause in the Project Status or the locations bullet, only if it stays small.
- A collection-and-lots area doc (#105) does not exist and is not written here; raised with the maintainer.
- No ADR is expected (no decision with lasting alternatives beyond Decision 1, which is a presentation rule recorded here). If the maintainer wants one, the number comes from `origin/main`'s `docs/adr/` at merge.
