# Feature 074: Deck Pages at Phone Width (Row Menus Clear of the Tab Bar, the Tab Bar's Missing Shots, the Stale Deck Page Preview)

**Status:** Approved by the coordinator under the maintainer's delegation (2026-11-11, Gate A) at 0.3.0; 0.4.0 adds AC-1.11 and AC-1.12 and a clause of AC-3.2 from the Gate A conditions
**Version:** 0.6.1
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 068](../068-deck-proxies/spec.md) (decision 5 and AC-2.6: the row menu), [spec 070](../070-replace-proxy-with-copy/spec.md) (the menu's items), [spec 071](../071-add-to-deck-from-card-page/spec.md) (its shots 04 and 05), [spec 060](../060-deck-components/spec.md) (`DeckPage`, `Menu`, `TableActions`), all merged
**Branch:** `074-deck-pages-phone-width`
**Issue:** [#326](https://github.com/plainprogrammer/Collector/issues/326) (design-system lane, filed by the maintainer's ruling from the implementation reviews of specs 070 and 071)
**Frozen:** the current rules are in [`design-system/README.md`](../../design-system/README.md) and its component documents `Menu`, `TableActions`, `TabBar` and `DeckPage` (whole spec); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.6.1 | 2026-11-11 | Patch from the review of 0.6.0 (Opus, read-only; REVISE: 0 blocking, 1 major, 5 minor, 2 nit) and the coordinator's ruling on the worst case (Option A): the floor's cost is recorded as measured (Decision 6, AC-1.15: the worst-case row's table spills 19px past its container, 1px today at a fine pointer and 13px at a coarse one, the page does not scroll sideways; realistic rows fit) and AC-1.15 is a committed example with every coarse rule applied; the Card column loses 18px in a zone with a row menu and 48px in one with none; the zone rule's stale comment is updated; the floor has its own heading in `additions.css`; the NFR says the floor follows the container; spec 075's number is named as a forecast; wrapping the proxy tag is Out of Scope as the way to remove the spill |
| 0.6.0 | 2026-11-11 | Minor, ruled by the coordinator under the maintainer's delegation (Option 1; spec review of the change only): Problem 4, Decision 6, AC-1.14 and AC-1.15, FR-1's third rule and the Supersedes entry. Making the preview true (an empty menu cell on rows with no proxy) exposed that the real deck page misaligns its zones' columns at 360px: spec 068's empty cell restores nothing for the menu column, so a zone with no proxy is 30px narrower there than a zone with proxies (measured on the real page); the menu column gets a minimum of 4rem, the wide layout's own 64px. It restores spec 060 AC-3.11's rule and changes no criterion |
| 0.5.0 | 2026-11-11 | Minor, from the coordinator at Gate B (the maintainer's delegation): AC-1.13 and FR-2's second clause, a menu is closed before Turbo caches the page, so Back restores a page with every menu closed and no scroll on restore (a `<details>` restored with `open` fires `toggle` again); Decision 3's "not specified" sentence becomes the rule; no change to an approved criterion |
| 0.4.1 | 2026-11-11 | Patch while writing the plan (no behaviour changes): AC-1.7's room-box part is proved by a hit-test of the point under the box (where a click lands) and the outside click by a real click on the heading; AC-1.9's outcome is stated so it can fail (the list's top lands under the app bar, and scrolling by the missing distance brings the last item above the bar), not "scrolled to its end", which a mid-page row would pass trivially; the Notes state the 0.5px layout tolerance |
| 0.4.0 | 2026-11-11 | Gate A conditions (coordinator): AC-1.11 (the room box adds no height, no scrollbar and sits in no scrolling container) and AC-1.12 (a shell with no tab bar gets no margin and no room box) are added, and AC-3.2 says `Menu.md` notes the export's stale comment so the next export fixes it; no behaviour changes |
| 0.3.0 | 2026-11-11 | Spec review round 2 (Opus, read-only; REVISE: 0 blocking, 5 major, 6 minor, 4 nit), all taken: the app bar is 57px, so the top margin is 65px (R2-1); the method scrolls only when the list's bottom is hidden, so the account menu in the sticky bar never moves a page (R2-2, AC-1.10); the room box is as wide as the list and `pointer-events: none`, with a click-below example (R2-3, R2-4); AC-1.9 has a start position, checkable outcomes and a first assertion that the fixture is tall enough, and AC-1.8 and AC-1.9 use two decks (R2-5, R2-6); closing at a page's end moves the page back (R2-7); the Escape example and the red/green lists are corrected (R2-8 to R2-10); AC-3.1's fixtures (R2-11); the trigger-on-screen claim (R2-12); "Rails controller" (R2-13); the export's stale comment is left and recorded (R2-14); the index row's Plan is "none" until the plan lands (R2-15) |
| 0.2.0 | 2026-11-11 | Spec review round 1 (Opus, read-only; REVISE: 1 blocking, 4 major, 9 minor, 3 nit), all taken: the page can't scroll far enough on the last rows, so an open list gets a room box, and the top margin keeps a tall list under the app bar (B1; Decision 2, AC-1.8, AC-1.9, prototype measured); the missing bar is reproduced at the issue's own 815px (a 1280×800 window) and the memory line says so (M1); `verification.md` exists (M2); the tall-list case is specified (M3); AC-1.4 requires a list that extends below the window (M4); AC-1.1 reads the app bar (m1); AC-1.7 names Escape and the outside click and adds examples (m2); `Menu.md`'s arrow-key claim is corrected (m3); the existing narrow-frame examples are listed (m4); `menu_cell` is named (m5); the controller's `toggle` constraints are stated (m6); fixtures are spelled out (m7); AC-3.1 lists the fourteen views (m8); index row matches AC-3.4 (m9) |
| 0.1.0 | 2026-11-11 | First draft from issue #326 and the measurements below. Routing: the menu rule changes a design-system rule for every `Menu`, so it is a spec, not a direct fix; routing, the fix (scroll the open list clear of the tab bar), the design-system rule and the memory line were confirmed by the coordinator under the maintainer's delegation on 2026-11-11 |

## Problem Statement

Issue #326 holds three loose ends from specs 070 and 071, all seen on the deck pages at phone width.

**1. A row menu opened near the bottom of a phone is hidden behind the tab bar.** Below 640px the shell draws a fixed bottom tab bar (`.c-shell > .c-tabbar`). A `Menu`'s list is absolutely positioned under its trigger and always opens downward, and nothing accounts for the bar. Measured in headless Firefox on the deck page (a 360px viewport, 640px tall, the first proxy row's menu open; the throwaway probe is described in `verification.md`):

| Item | Top | Bottom | Where it is |
|---|---|---|---|
| Use my copy | 524px | 560px | clear |
| Add a new copy | 560px | 596px | its lower 23px behind the bar |
| Change proxy count | 596px | 632px | behind the bar |
| Remove proxy | 641px | 677px | below the viewport, behind the bar |
| (the tab bar) | 573px | 640px | 67px high |

The page can be scrolled to reveal them in the middle of a page (the list is part of the page's scrollable overflow), but a collector opening a menu near the bottom of the screen sees the first items only, and the last one, the destructive "Remove proxy", is the one furthest out of sight. At the end of a page scrolling does not help: the list adds overflow only to its own bottom edge, the page ends 80px under its content (plus the footer), and the furthest scroll puts the list's bottom edge on the viewport's bottom, behind the bar. Measured on the last row of the deck page's last zone with proxies of two finishes (an 8-item menu), at the furthest scroll the last two items sat at 563px to 635px against a bar from 573px (review of this spec, reproduced 2026-11-11). Every `Menu` has the problem when it opens near the bottom of a phone: the audit below lists the ten places the app draws one, five of them table rows.

**2. The tab bar is missing from spec 071's 390px shots 04 and 05.** The issue asks whether the page or the narrow test frame causes it. Measured: the page is not at fault. Add to deck renders the shared `layouts/tabbar` partial, and in a 390px frame of 700px, 815px and 1315px height the bar is `display: flex`, `position: fixed`, with its bottom edge on the frame's bottom edge. The frame is: a narrow frame taller than the browser window's viewport is clipped to it, and the bar, fixed to the frame's bottom, falls outside the picture. Reproduced with the issue's own height, 815px: in a 1280×800 window (a 715px viewport) the 815px frame's shot has no bar, exactly as 04 and 05 show; in a 1280×900 window (an 815px viewport) the same frame's shot has it; a 1700px frame in this suite's 1400×1400 window (a 1315px viewport) gave a 1315px shot with no bar. Spec 071's throwaway spec is gone, so its window size can't be read back, but a desktop-sized window explains every 815px shot of that spec (01 to 09, all 390px or 360px by 815px, without a bar; shot 10, also 815px, has one, so its window was taller) and the two 1315px shots (11 and 12) are the 1315px case. No page change is needed; the cause belongs in the screenshots workflow note (a memory line), and a guard example keeps the bar on the deck family's pages.

**3. The deck page's preview is stale.** `docs/design-system/previews/DeckPage.html` and `DeckPagePhone.html` draw "Move copies" in a one-item menu on every row that has no proxy (12 rows in each file). Spec 066 dropped the row menu and spec 068 decision 5 restored it with the proxy items only, so a row with no proxy has an empty menu cell (`td.c-table__actions` with no trigger), which is what the page builds (`app/views/decks/_proxy_menu.html.erb` renders nothing for a row with no proxy line). `DeckPage.md` already says so ("'Move copies' is not offered on the deck page"); the previews were never brought into line.

**4. The zones' columns misalign at phone width (found while making the preview true; ruled in by the coordinator as inside the issue's outcome).** Spec 068 gave a row with no proxy an empty menu cell (`td.c-table__actions` with no trigger). Below 640px of the table's container a zone table keeps its auto layout, in which the menu column is as wide as its widest cell: with a trigger 46px (a 30px button and 8px of padding a side), with every cell empty 16px. So a zone whose rows have no proxy is 30px narrower in that column than a zone with proxy rows, and Cost and Total move 30px with it. Measured on the real page, a deck with a proxy row in Main and an owned card in Sideboard, 360px viewport: the menu column 46px against 16px, Cost's right edge at 238px against 268px, Total's at 290px against 320px. Spec 060 AC-3.11 says the columns sit at one x in every zone; the design system's fixture had every row carry a menu, so the examples never saw it. The wide layout (from 640px of the container) already fixes the menu column at 4rem (64px) in every zone.

> **Terms.** The *tab bar* is `.c-shell > .c-tabbar`, shown below 640px of the viewport (`TabBar.md`). A *menu* is `Menu` (`details.c-menu`, `.c-menu__list`); a *row menu* is one in a table row (`TableActions`). A *phone viewport* is 360px wide, the narrowest the design system targets; headless Firefox draws a classic scrollbar (15px on a Mac, about 12px on the Linux runner) that a phone doesn't, so a spec states 360px and sizes its narrow frame from the measured scrollbar (lesson `docs/lessons/2026-11-11-a-phone-width-criterion-needs-a-measured-chain.md`).

### Audit: every `Menu` the app draws (2026-11-11)

Built from a search of `app/views/` for `c-menu"` (the exact command is in `verification.md`). Each page draws it through the same markup and the same Stimulus `menu` controller.

| # | Menu | Where | Can open near the bottom of a phone |
|---|---|---|---|
| 1 | Account menu | app header, every page | no, the top of the page |
| 2 | More actions | card page head (`catalog/entries/show`) | no, the page head |
| 3 | Row menu | card page's copies table (`catalog/entries/_copies`) | yes, a table row |
| 4 | More | collection filter bar (`c-filterbar__more`, phones) | no, above the grid |
| 5 | More | bulk bar (`c-bulkbar__more`) | no, sticky at the top |
| 6 | Row menu | collection table (`collections/_table`) | yes |
| 7 | More actions | deck page head (`decks/show`) | no, the page head |
| 8 | Row menu | deck zone tables, proxy rows only (`decks/_proxy_menu`) | yes |
| 9 | Row menu | admin users (`admin/users/index`) | yes |
| 10 | Row menu | admin jobs (`admin/jobs/index`) | yes |

The Locations page has no `Menu` (its actions are buttons), so the issue's "locations" is not affected. All ten take the rule, because it is a property of the component; the examples prove the five row menus, where it matters.

## Goals

- On a phone, every item of an open menu can be seen and reached, whatever its row's position on the screen: nothing sits behind the tab bar.
- A menu that is already clear of the bar does not move the page, and a screen with no tab bar (640px and wider, or a page with none) keeps today's behaviour exactly.
- The fix is made once, in the `Menu`, and documented where the next menu is built.
- The deck page's previews match the page: a row with no proxy has no menu trigger.
- The cause of the missing tab bar in the narrow-frame shots is recorded where the next author shoots, and a guard keeps the bar on the deck family's pages.
- The deck page's zone tables keep their columns at one x in every zone at a 360px viewport, whether or not a zone's rows have a menu (spec 060 AC-3.11).

## Non-Goals

- Opening a menu upward near the bottom (decision 1's alternative B).
- Changing `components.css` (the design export's file), the menu's items, labels, order, width or the items' height. The 44px touch floor of row actions and small buttons is spec 075's (#316); this spec reads boxes as drawn and doesn't fix a number that spec 075 may change.
- Changing the deck shape panel (#320, spec 077).
- A menu that scrolls, or closes, when the window changes size or turns; the rule acts when a menu opens.
- Any Rails controller, model, migration, export or view change. (The `menu` Stimulus controller and `additions.css` change; no view does.)
- Retaking spec 071's shots 04 and 05: they are history. This PR's own shots show the bar.

## Decisions

### 1. An opened menu is scrolled clear of the tab bar (ruled by the coordinator, 2026-11-11; option A)

| | A. Scroll the open list into view, clear of the bar (chosen) | B. Open upward near the bottom | C. Padding or a taller `main` | D. CSS anchor positioning with a flip fallback |
|---|---|---|---|---|
| Every item reachable at any position | yes, the page scrolls the missing amount | only if there is room above; a row near the top of a short viewport has none below nor above | no: a menu is absolutely positioned and does not push the page; padding the page does not move the menu | only where the browser supports it |
| A menu already clear | does nothing | still decides | n/a | flips only when it has to |
| Cost | one controller method and one CSS rule | placement logic, a second fallback, a new class | none, and no fix | a feature self-hosters' browsers may lack |
| Works with the list's height changing (menu items are 44px on a coarse pointer, 36px on a fine one, and a row may have two or three finishes' items) | yes, it measures the list as drawn | yes | n/a | yes |
| Without JavaScript | as today: the page scrolls by hand | as today | n/a | works |

Chosen: A. The list keeps opening below its trigger. When it opens, the page scrolls only far enough for the list's bottom edge to clear the tab bar's top edge by `space-2` (8px). The scroll moves the page up by the missing amount only; the trigger, which is above the list, stays on screen while the list and the trigger fit between the two bars (AC-1.9's taller list scrolls it off).

### 2. CSS says how far and gives the page the room; one controller method scrolls

Below 640px, on a shell that has a tab bar (`.c-shell:not(.c-shell--untabbed)`), three things in one block of `additions.css`:

- **The margin below.** `.c-menu__list` has `scroll-margin-bottom` equal to the tab bar's drawn height, plus `env(safe-area-inset-bottom)` for the home indicator, plus `var(--space-2)`.
- **The margin above.** The same list has `scroll-margin-top` equal to the app bar's drawn height (57px: its 56px height and 1px border in the default `content-box`) plus `var(--space-2)`. It changes nothing for a list that fits (its top is at least 89px down when its row menu's trigger is visible below the app bar); a list taller than the room between the two bars (12 items, the three finishes of a proxy row: about 451px at the 36px rows of a fine pointer and about 560px at a coarse pointer's 44px, against the 444px between the bars of a 568px phone) is then aligned with its top just under the app bar, so its first items are reachable and the rest scrolls.
- **The room.** An open list carries an empty box (`::after`, absolutely positioned at its bottom edge, as wide as the list: `left: 0; right: 0`, because a zero-width box may add no scrollable overflow in some engines, and `pointer-events: none`, so a tap in it reaches what is under it and the controller's outside-click close still sees an outside click) as tall as the bottom margin, so the page can scroll that far past the list: without it the page ends at the list's bottom edge, 80px under its content, and the furthest scroll leaves the last items behind the bar (Problem 1, measured).

The controller's method asks the list to scroll into view with the nearest alignment (no movement when it is already inside the margin box), the moment the `details` opens (its `toggle` event, which does not bubble: the controller adds the listener to its own element in `connect` and removes it in `disconnect`; it acts only when the `details` is open, because `toggle` fires on close too). The block has its own heading in `additions.css` (`/* ---------- Menus open clear of the tab bar (spec 074) ---------- */`), so spec 075's and 077's blocks don't touch it. The tab bar's height is measured at 67px (the link's 56px minimum height and 6px plus 4px of padding, and the bar's 1px border, in the default `content-box`), and the margin states it as a literal: the controller could measure the bar, but the room box is pure CSS and must agree with the margin, so one literal in one block is the single source, and AC-1.6 reads the bar's drawn height and the margin from the page, so a change to the bar that outgrows the margin fails an example instead of reopening the bug.

### 3. The scroll happens only where a tab bar is drawn, and only as far as needed

The method returns at once when the page has no tab bar or the bar is not displayed (`display: none` from 640px of the viewport, and on a page whose shell is `c-shell--untabbed`): today's behaviour is unchanged to the pixel there (the CSS block is scoped to a tabbed shell below 640px, so no margin or room box exists there either). It scrolls only when the list's bottom edge is below the tab bar's top edge less `space-2` (the case the rule exists for), so the margins can never move a page for the top margin alone: the account menu's list sits in the sticky app bar, above the top margin, and opening it must not move a scrolled page (AC-1.10). When it does scroll it uses the nearest alignment, and it scrolls instantly when the collector prefers reduced motion (`prefers-reduced-motion: reduce`) and smoothly otherwise, reading the preference when the menu opens, not when the controller connects. A menu is closed before Turbo caches the page (`turbo:before-cache`), so Back restores the page with every menu closed and the restored page does not scroll for a menu: a `<details>` restored with its `open` attribute fires `toggle` again, and the handler would otherwise scroll on restore (AC-1.13).

### 4. The tab bar's absence from the shots is the frame's, not the page's (finding)

See Problem 2. The page is unchanged. The fix is a sentence in `.claude/memory/pr-screenshots-workflow.md`: a narrow frame sized to a tall page's full height is clipped by the window's viewport if taller than it, which cuts off the fixed tab bar (an 815px frame in a 1280×800 window, whose viewport is 715px; a 1700px frame in a 1315px one); size the window taller than the frame or shoot the page in a frame no taller than the viewport, and look for the bar in every phone shot. A guard example (AC-3.1) keeps the bar on the deck family's pages; it passes before and after.

### 5. The previews match the page

`DeckPage.html` and `DeckPagePhone.html` replace the one-item menu on every row with no proxy by the empty cell the page draws, `<td class="c-table__actions"></td>`; the menus of the proxy rows (the open one on Murktide Regent and the closed ones) already list Use my copy, Add a new copy, Change proxy count and, after a separator, Remove proxy, and stay. `DeckPage.md` is already right about the menu; it gains one sentence on the tab bar clearance and the preview's empty cells.

### 6. The menu column has a floor of 4rem in the auto layout (ruled by the coordinator, 2026-11-11; Option 1)

| | A. `min-width: 4rem` on the menu column below 640px of the table's container (chosen) | B. Give every row a menu trigger or a placeholder | C. Fix the fixture and the examples only | D. A floor equal to the trigger's width (46px) |
|---|---|---|---|---|
| Columns align in every zone | yes | yes | no, the page stays misaligned | yes today |
| View change | none (FR-5 stands) | a view change, and an invisible control or a placeholder per row | none | none |
| Agrees with the wide layout | yes, the same 64px | n/a | n/a | no, 46px against 64px |
| Robust to #316's 44px trigger on a coarse pointer (spec 075, not yet written: 62px of column with its border and padding) | yes, 64px is larger | yes | n/a | no, 46px is smaller than the 60px column |
| Cost | the Card column is 18px narrower in a zone with a row menu and 48px narrower in a zone with none, at 360px on a fine pointer (6px and 36px at a coarse one, whose trigger already makes a 58px column) | markup per row | a known bug stays | none, but fragile |

Chosen: A. One rule in this spec's `additions.css` block, in a container query that matches the auto layout (`@container collection (max-width: 639px)`), on the header cell: `box-sizing: border-box; min-width: 4rem`. The wide layout's `width: 4rem` is unchanged. The comment names the 64px, the trigger's 46px column (30px button, 8px padding a side) and spec 075's coarse 44px trigger (60px of column), so a later change finds the numbers. The Card column's new width at 360px is recorded in `verification.md`, with the worst-case examples (a 60-character name, a six-symbol cost) rerun.

**What it costs, measured (2026-11-11, the real page at a true 360px viewport, `deck_page_spec.rb`'s worst-case fixture: a 60-character name with no space, a six-symbol cost, 123 owned and 1,234 proxies in Main, a short card in Sideboard).** Without the floor the menu column is 46px in Main and 16px in Sideboard and Main's table is 313px wide in a 312px container (1px over at a fine pointer; about 13px over at a coarse one, whose trigger makes a 58px column). With the floor both are 64px and aligned, the Card column of that row stays at 102px (it is at its minimum, the unbroken "Proxy 1,234" tag) and Main's table is 331px (19px over: the trigger sits in the page's 16px side padding, about 5px inside the viewport edge). The document does not scroll sideways (360 of 360) either way. This is the worst case only: rows with names that break, or costs of up to four symbols, fit the container. Wrapping the proxy tag in a zone table would remove the spill (Out of Scope).

## Supersedes

Nothing is superseded. It restores [spec 060](../060-deck-components/spec.md) AC-3.11 (the zone tables' columns sit at one x in every zone) at 360px, which [spec 068](../068-deck-proxies/spec.md) decision 5 and AC-2.6 (an empty menu cell on a row with no proxy) broke without an example noticing; neither criterion changes. The design-system fixture in `spec/system/design_system_deck_components_spec.rb` (`menu_cell`) stops drawing a menu on every row, and the AC-3.11 example there then reads the page's real markup. The grep of `docs/specs/` and `spec/` for menu placement rules (named in `verification.md`) found no earlier criterion that says a menu opens without scrolling or sits behind the bar; spec 070's `verification.md` notes the problem as seen and not its. Spec 068 decision 5 and AC-2.6 are met by the preview change, not changed.

## User Stories

### Story 1: An open menu is never hidden behind the tab bar

**As a** collector on a phone
**I want** every item of an open row menu to be on screen
**So that** I can reach "Remove proxy" (or any last item) without hunting for it behind the bar

- [ ] **AC-1.1** Given the deck page at a 360px viewport (a frame sized from the measured scrollbar, 640px tall, in a window whose viewport is taller than the frame) with a proxy row in Main, scrolled so the row's trigger bottom edge is 40px above the tab bar's top edge When the collector opens the row's menu Then once the page has settled every menu item's bottom edge is at least 8px above the tab bar's top edge and the first item's top edge is below the app bar's bottom edge.
- [ ] **AC-1.2** Given the same page and row, scrolled so the trigger's top edge is 120px below the viewport's top edge (the list ends above the tab bar) When the collector opens the menu Then the page's scroll position is unchanged. (AC-1.1 and AC-1.2 differ only in the starting scroll position, so a rule that always scrolls or never scrolls fails one of them.)
- [ ] **AC-1.3** Given each row menu of the audit (rows 3, 6, 8, 9 and 10: the card page's copies table, the collection table, the deck page, the admin users list and the admin jobs list) at a 360px viewport, each with a row in the middle of its page scrolled so the row's trigger bottom edge is 40px above the tab bar's top edge When the menu is opened Then every item's bottom edge is at least 8px above the tab bar's top edge and the page has no horizontal overflow (`scrollWidth` at most `clientWidth`).
- [ ] **AC-1.4** Given the deck page in a 700px-tall window at 1280px wide (no tab bar) with a proxy row scrolled so its trigger's bottom edge is 40px above the window's bottom edge (the list extends below the window) When the menu is opened Then the page's scroll position is unchanged, and the list's top edge is 4px below the trigger's bottom edge (as today). (The list's bottom edge is below the window's before it opens, so a rule that ignores whether a bar is drawn scrolls and fails.)
- [ ] **AC-1.5** Given a phone viewport and a page that asks for reduced motion When the menu opens near the bottom Then the scroll is requested with the behaviour `instant`; given no such preference it is requested with `smooth`. (Measured by recording the options of the scroll request.)
- [ ] **AC-1.6** Given the deck page at a 360px viewport with a menu open When the open list's computed `scroll-margin-bottom` is read Then it is at least the tab bar's drawn height plus 8px, its computed `scroll-margin-top` is at least the app bar's drawn height plus 8px, and the list's `::after` box is at least as tall as the bottom margin; at a 1280px window the margins are `0px` and there is no `::after` box.
- [ ] **AC-1.7** Given the menu is open When the collector presses Escape Then it closes and focus is on the trigger; when the collector clicks outside it, and the point 4px below the open list's bottom edge (inside the room box of Decision 2) is hit-tested to the page's content, not to the list (where a click on it would land) Then it closes. (No example covers focus return today: `bulk_mode_spec.rb:85` presses Escape on the account menu in the 1400px window and checks only that it closes; the new spec file adds both.)
- [ ] **AC-1.8** Given a deck page at a 360px viewport whose last row on the page (in the last zone, which has one row) has proxies of two finishes (an eight-item menu) and the page scrolled to its end When the collector opens that row's menu Then once the page has settled every item's bottom edge is at least 8px above the tab bar's top edge. (It fails without the room box of Decision 2: the page cannot scroll further than the list's bottom edge, measured in Problem 1.)
- [ ] **AC-1.9** Given a second deck whose row has proxies of three finishes (twelve items) in a 360px by 568px viewport, the example first asserting that the closed menu's list, as it will draw, is taller than the room between the app bar's bottom edge and the tab bar's top edge (about 451px against 444px at the suite's fine pointer; if the fixture's labels wrap, taller), and the row scrolled so its trigger's bottom edge is 40px above the tab bar's top edge When the collector opens the menu Then once the page has settled the list's top edge is within 1px of the app bar's bottom edge plus 8px, and scrolling the page by the distance the last item's bottom edge is below the tab bar's top edge less 8px moves the page by that distance (it is not stopped at the page's end) and brings that edge to at least 8px above the tab bar's top edge.
- [ ] **AC-1.10** Given a phone viewport and a page scrolled down by 300px When the collector opens the account menu in the sticky app bar Then the page's scroll position is unchanged. (A rule that scrolled for the top margin alone would move the page by about 16px.)
- [ ] **AC-1.11** Given each page of AC-1.3 at a 360px viewport When no menu is open Then `documentElement.scrollHeight` is the same as after a menu has been opened and closed (the room box goes with the open list); and when a menu is open, no `.c-menu__list` of the page has an ancestor whose computed `overflow-x` or `overflow-y` is not `visible` (a menu inside a scrolling container would put the room box's height into that container as a scrollbar: the phone filter row, `.c-filterbar__filters`, is `overflow-x: auto`, and no menu is inside it), and the page has no horizontal overflow. (The ancestor check can fail: the example also runs it on a copy of a menu wrapped in an `overflow-x: auto` element and expects it to report that ancestor.)
- [ ] **AC-1.12** Given the deck page at a 360px viewport whose `body` the example gives the class `c-shell--untabbed` and whose tab bar it removes (a shell with no tab bar) When a menu is opened Then the list's computed `scroll-margin-top` and `scroll-margin-bottom` are `0px`, its `::after` box has no height, and the page's scroll position is unchanged. (The block is scoped to a tabbed shell; the class is what the app's layout sets, `application.html.erb`.)
- [ ] **AC-1.13** Given a menu opened near the bottom of a phone page (the page scrolled for it) and a link of its list followed (a Turbo Drive visit) When the collector goes Back Then the page is restored from Turbo's cache with every menu closed and at the scroll position it had when the collector left it.
- [ ] **AC-1.14** Given a deck whose Main has a row with proxies and whose Sideboard and Considering have rows with none (their menu cells are empty) at a 360px viewport When the page renders Then the menu column's header cell is at least 64px wide in every zone table and within 1px of the same width in all three, and the right edges of the Cost and the Total columns are within 1px of each other across the three zones. (It fails before the CSS: the menu column measured 46px against 16px, and the edges 30px apart.)
- [ ] **AC-1.15** Given the existing worst-case examples of the deck page (a 60-character name with no space, a six-symbol cost, a three-digit quantity and a four-digit proxy count: spec 060 AC-3.5, AC-3.6, AC-3.11; spec 068 AC-2.11, `deck_page_spec.rb`) at 360px When the menu column is at least 64px Then they still pass (no horizontal overflow, nothing spilling into the next cell), and the Card column's width at 360px is recorded in `verification.md`. (Verified by running them.) And given the same worst-case fixture on the real page at a true 360px viewport with every rule inside `@media (pointer: coarse)` applied (the coarse trigger size included) When the page renders Then the document does not scroll sideways (`scrollWidth` at most `clientWidth`, #318) and no zone table is more than 20px wider than its container (the measured 19px). (A committed example; it can fail if the floor or a later rule grows the table or the page.)

### Story 2: The deck page's design preview matches the page

**As a** developer, or an agent, reading the design system
**I want** the preview to draw what ships
**So that** a stale item doesn't get rebuilt

- [ ] **AC-2.1** `docs/design-system/previews/DeckPage.html` and `DeckPagePhone.html` contain no "Move copies"; each row with no proxy has an empty `td.c-table__actions`; each row with proxies has the menu with its items in the order Use my copy, Add a new copy, Change proxy count, a separator, Remove proxy. (Verified by reading, and by looking at the previews in both themes at 360px and 1280px.)
- [ ] **AC-2.2** `DeckPage.md` says the preview shows a row with no proxy as an empty cell and points to `Menu.md` for the tab bar clearance. (Verified by reading.)

### Story 3: The design system states the rule, and the missing bar's cause is recorded

**As a** developer adding a menu, or a worker taking phone shots
**I want** the rule and the trap written where I will look
**So that** the next menu and the next walkthrough don't repeat this issue

- [ ] **AC-3.1** Given each of the fourteen views of the deck family that render the tab bar (`git grep -n 'layouts/tabbar' -- app/views`: the Decks index, New deck, Edit deck, deck show, Change format, the removal page and the removal refusal page, the proxy pages New, Choose, Edit, Remove, Add a new copy and Use my copy, and Add to deck from the card page), at a 360px viewport in a frame no taller than the window's viewport When it renders Then the tab bar is displayed, fixed, with its bottom edge on the frame's bottom edge and five tabs, one of them current (Decks on the deck pages; the card's own section on Add to deck). (A guard: it passes before and after this change, and fails if a page stops rendering the bar.)
- [ ] **AC-3.2** `Menu.md`, `TableActions.md`, `TabBar.md` and the README's Navigation section state the rule (Decisions 1 to 3, in their own words), `DeckPage.md` as AC-2.2 says, and `Menu.md`'s sentence that the controller adds "arrow-key movement" (the controller has none) is corrected, with a note in `Menu.md` that the export's `components.css` comment says the same and is left, so the next export fixes it. (Verified by reading.)
- [ ] **AC-3.3** `.claude/memory/pr-screenshots-workflow.md` has the line of Decision 4, including the measured cases (an 815px frame in a 1280×800 window, a 1700px frame in a 1315px viewport) and that the window of spec 071's shots can't be read back, so their cause is "reproduced, not confirmed". (Verified by reading.)
- [ ] **AC-3.4** The specs index has this spec's row, whose "Supersedes" cell says it supersedes nothing and restores spec 060 AC-3.11 after spec 068's empty cell, with no "Superseded by", under the title in this file's heading. (Verified by reading.)

## Functional Requirements

- **FR-1.** `app/assets/stylesheets/collector/additions.css` gets one block, under the heading of Decision 2, with its rules inside `@media (max-width: 639px)`, scoped to `.c-shell:not(.c-shell--untabbed)`: the two scroll margins and the room box (`::after` of an open list), and a comment giving the why (the 67px and the 56px, the safe-area inset, why the bar's height is a literal, why the room box, spec 074). The block's comment must not contain "spec 019", "spec 021" or "spec 023", which the guards in `spec/design_system_files_spec.rb` count across the whole file. `components.css` is unchanged.
- **FR-2.** `app/javascript/controllers/menu_controller.js` gets one method that scrolls the open list into view as Decisions 1 and 3 say, run from a `toggle` listener added in `connect` and removed in `disconnect`, acting only when the `details` is open and reading the reduced-motion preference then, and a comment that says why (the bar covers the list; `toggle` does not bubble). Closing, outside click, Escape and focus return are unchanged. A second method closes the controller's menu on `turbo:before-cache` (a document listener added in `connect` and removed in `disconnect`), at every width, so a cached snapshot never holds an open menu (AC-1.13).
- **FR-3.** `DeckPage.html` and `DeckPagePhone.html` change as AC-2.1 says; `spec/system/design_system_deck_components_spec.rb`'s `menu_cell` (it builds the same stale "Move copies" menu for every row, lines 198 to 203) is brought into line, or kept with a stated reason; the component documents, the README, the specs index and the memory file change as Story 3 says.
- **FR-1a.** `additions.css` gets a second block under its own heading, `/* ---------- Deck zones' menu column floor (spec 074) ---------- */` (after the first block; Decision 6): in `@container collection (max-width: 639px)`, `.c-zone .c-table th.c-zone__c-menu { box-sizing: border-box; min-width: 4rem; }`, with its own comment. It does not change a width at 640px of the container and wider. The same change updates the comment of the zone rule that says Total keeps its content width "as the menu does" (`.c-zone__c-total { width:1% }`, below 640px): the menu column no longer does.
- **FR-4.** One system spec file proves AC-1.1 to AC-1.14 and AC-3.1 on the real pages (AC-1.15 is the existing examples, rerun); it fails before the change (AC-1.1, AC-1.3, AC-1.5, AC-1.6, AC-1.8, AC-1.9, AC-1.13, AC-1.14) and passes after. AC-1.2, AC-1.4, AC-1.7, AC-1.10, AC-1.11, AC-1.12 and AC-3.1 pass both before and after (AC-1.7's click below the list guards the room box's `pointer-events: none`: it can fail only after the change, if the box swallows the click) (AC-1.7 as to Escape and outside click, today's behaviour): they are the partners that keep the rule from moving menus that were clear and from breaking the menu, and keep the bar on its pages.
- **FR-5.** No view, helper, model, Rails controller, migration or export file changes.

## Non-Functional Requirements

- **Compatibility:** no migration, no schema change, export format unchanged at version 4, upgrade-safe from the previous release.
- **Hosted-door cost per account (north star rule 4):** none; a stylesheet rule and a small controller method.
- **Accessibility:** every menu item is on screen, or one scroll away, when the menu is open (WCAG 2.4.11, focus not obscured, for the items a keyboard reaches by Tab); the scroll respects `prefers-reduced-motion`; the focus, labels and names are unchanged.
- **Nothing needs JavaScript to render or work (design system rule):** without scripting a menu opens as today and the page scrolls by hand; the controller only enhances.
- **Visual change:** yes, on phones, as a page scroll; and below 640px of a deck page's zone tables' container, whatever the viewport or shell, the menu column is at least 64px wide (Decision 6), so the zones' columns align and the Card column is narrower.
- **Visual change (the scroll):** yes, on phones only, as a page scroll. Before and after shots at 360px, light and dark, with a menu open near the bottom: the "before" is emulated by restoring the scroll position the open menu started from (`verification.md` says so).

## Error Scenarios

| Scenario | Behaviour |
|---|---|
| A list taller than the room between the app bar and the tab bar (a row with proxies of three finishes: twelve items, about 451px at a fine pointer's 36px rows, about 560px at a coarse pointer's 44px) | The list's top is aligned just under the app bar (the top margin of Decision 2), so its first items are on screen and the rest is one scroll away; the trigger may be scrolled off the top (AC-1.9). A row with two finishes has eight items, about 307px at 36px rows and 372px at 44px, and fits a 568px phone |
| A menu is closed at the end of a page | The room box goes with the open list, the page's furthest scroll shrinks by up to the box's height (75px) and the browser clamps the position: the page may move back down by up to 75px on close. Accepted; `verification.md` records the measured move |
| The collector prefers reduced motion | The scroll is instant (AC-1.5) |
| JavaScript has not loaded or fails | The menu opens and closes as today; the collector scrolls by hand |
| A page with no tab bar below 640px (a visitor's page, a shell with `c-shell--untabbed`) | The method returns at once; nothing scrolls (Decision 3) |
| The menu is opened on a page where the list is already above the bar | Nothing scrolls (AC-1.2) |
| The tab bar grows taller than the margin (a later change) | AC-1.6 and AC-1.1 fail |

## Open Questions

None.

## Notes for the plan

- Task 1 is the system spec, written first. Its red run is the current code: AC-1.1, AC-1.3, AC-1.8 and AC-1.9 fail (nothing scrolls), AC-1.5 fails (nothing records a scroll request), AC-1.6 fails (the margins are `0px` and there is no room box); AC-1.2, AC-1.4, AC-1.7, AC-1.10 and AC-3.1 pass. Run the guards' mutation check from the lesson `an-example-that-cannot-fail-proves-nothing`: with the controller method stubbed to always scroll to the bottom, AC-1.2 must fail; with it stubbed to nothing, AC-1.1 must fail; AC-3.1 must fail for a page whose `render "layouts/tabbar"` is removed (done once, by hand, and noted in `verification.md`).
- Place a trigger "40px above the tab bar's top edge" by scrolling the frame's window so that `trigger.getBoundingClientRect().bottom == bar.getBoundingClientRect().top - 40` (the page must be tall enough; the fixtures, spelled out: the deck page, a Main zone of six rows each with a proxy (a row without a proxy has no menu), and for AC-1.8 and AC-1.9 a last-zone row with proxies of two and of three finishes; the card page, ten separate lots of one printing (ten lots, not one lot of ten); the collection table, `?view=table` and not bulk mode, twelve lots; admin users, an admin and twelve users (a row menu is on every user but the signed-in one: check `admin/users/index.html.erb`); admin jobs, the `:solid_queue` tag with `queue_job` and `fail_job` for twelve failed jobs, because the row menu exists only on failed jobs, with an admin). Measure after the page has settled: the scroll is smooth when no reduced motion is asked, so wait on the scroll position stopping (two equal readings a frame apart) with Capybara's wait, never `sleep` (`testing.md`).
- AC-1.13 follows a link and goes Back inside the frame (`w.history.back()` in the frame; the joint session history makes the frame's Turbo entries its own), waits with Capybara's matchers for the deck page's table (no `sleep`), and reads `.claude/memory/turbo-back-navigation-quirks.md`'s lesson: wait for Turbo to be idle before going Back. Without the handler the restored snapshot holds the open menu, so the example fails on the open-menu count; with a cache restore Turbo makes no request, so the snapshot is what the page shows.
- Layout rounds to a quarter pixel and a scroll may land on a fractional position (the prototype read 514.25), so the examples compare edges with a 0.5px tolerance where an AC says "at least 8px" or "within 1px"; the tolerance is stated in the example, not hidden.
- The 360px viewport chain: a frame of 360px plus the measured scrollbar (`innerWidth - documentElement.clientWidth`) is a 360px viewport; compare overflow with `clientWidth`, not `innerWidth` (#318 and lesson `two-measurement-traps-the-classic-scrollbar-and-closed-details-menus`). The frame is 640px tall, no taller than the window's viewport (the finding of Decision 4).
- Firefox keeps a layout box for the items of a closed `<details>`; read the items of the open menu only, and the tab bar from inside the frame (`document.querySelector(".c-shell > .c-tabbar")`).
- AC-1.5 stubs `Element.prototype.scrollIntoView` inside the frame to record its argument and overrides `window.matchMedia` for the reduced-motion query, so the example reads the controller's request, not the browser's scrolling.
- The existing examples that open a menu in a narrow frame must still pass, and the plan names what happens to each (a grep of `spec/` for `summary` clicks in a frame, named in `verification.md`): `narrow_admin_pages_spec.rb:36` (the admin jobs row menu at 375×800; one failed job, so its row is near the top of the frame and nothing scrolls: it must stay green), `narrow_bulk_pages_spec.rb:18` and `:30` and `bulk_mode_spec.rb:122` (the More menus near the top: no scroll), and `bulk_move_spec.rb:76` (clicks the bulk bar's More). The examples that open a menu in the 1400px window (`bulk_mode_spec.rb:85`, Escape on the account menu; `admin_jobs_spec.rb:56`, `deck_proxy_replacements_spec.rb:26` and `:40`, `lot_moves_spec.rb:13`) have no tab bar and are unaffected by construction.
- AC-3.1's fixtures: every page needs a signed-in collector and a deck; the removal refusal page needs a deck whose zone holds a lot; the proxy pages Edit, Remove, Add a new copy and Use my copy need a proxy in a zone (and Use my copy a free copy of its printing, or it redirects: give it the record it needs); Choose needs the zone's `?q=` search with a matching printing; Add to deck needs a printing; the plan names each path from `bin/rails routes`.
- Run `bin/rspec spec/design_system_files_spec.rb` after the `additions.css` edit (the block counts of its guards); the preview edit needs `spec/system/design_system_deck_components_spec.rb` to still pass, and its `menu_cell` is dealt with as FR-3 says.
- Prototype (2026-11-11, throwaway, in `verification.md`): `scroll-margin-bottom: 75px`, the room box and a `toggle` listener calling `scrollIntoView({block: "nearest"})` took the 8-item menu on the last row from items ending at 635px (behind the bar at 573px) to 561px; without the room box the last item stayed at 563px to 635px. The plan's CSS uses 75px (67px plus `space-2`) and 65px (57px plus `space-2`); AC-1.6 reads both bars' drawn heights from the page.

## Out of Scope (Future Considerations)

- Wrapping the unbroken proxy tag ("Proxy 1,234") in a zone table's Card cell, which would remove the worst case's 19px spill: it changes spec 068's `ProxyTag` rule and is its own ruling.
- Opening a menu upward when there is room above and none below.
- Raising the small buttons and row actions to 44px on a coarse pointer ([#316](https://github.com/plainprogrammer/Collector/issues/316), spec 075).
- A scroll lock or a scrim behind an open menu.
- Re-running the 390px shots of spec 071.

## Documents that change

- `app/assets/stylesheets/collector/additions.css` (two blocks: the menu clearance and the menu column floor); `app/javascript/controllers/menu_controller.js` (one method); one new system spec file; `spec/system/design_system_deck_components_spec.rb` (`menu_cell`, FR-3; its AC-3.11 example then needs no change).
- `docs/design-system/previews/DeckPage.html`, `DeckPagePhone.html`; `docs/design-system/components/Menu.md`, `TableActions.md`, `TabBar.md`, `DeckPage.md`; `docs/design-system/README.md` (Navigation).
- `docs/specs/README.md`: this spec's row. `.claude/memory/pr-screenshots-workflow.md`: one line (AC-3.3).
- No area doc: the design system's rules are its README and component documents (specs 057, 060, 063, 072); no ADR: the ruling is Decision 1 here.
