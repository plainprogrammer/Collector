# Feature 057: Design System: Deck Rules, Navigation and Pickers

**Status:** Approved by the maintainer at Gate A on 2026-11-10 (option A; Q17 and Q18 ruled A; decisions 14 to 16 confirmed); version 1.1.0 adds decision 19 (the header's room for five links), ruled option A by the maintainer on 2026-11-10
**Version:** 1.1.0
**Created:** 2026-11-10
**Last Updated:** 2026-11-10
**Depends on:** [the decks and locations issue design](../../superpowers/specs/2026-11-09-decks-and-locations-issues-design.md) (decisions 9, 14–16 and 18), [spec 029](../029-manage-locations/spec.md) (the header's links, Locations), [spec 037](../037-filter-collection-by-location/spec.md) (the collection's location filter), all merged
**Branch:** `057-deck-design-rules`
**Issue:** [#248](https://github.com/plainprogrammer/Collector/issues/248) (roadmap item 14a)
**Frozen:** the current rules are in the [design system](../../design-system/README.md) and its component docs (whole spec: the deck rules, navigation, pickers, the card page's stats and the CSS in `additions.css`), and in [`catalog-core.md`](../../architecture/catalog-core.md) and [`collection-and-lots.md`](../../architecture/collection-and-lots.md) (parts: decision 12's wording); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.1.0 | 2026-11-10 | MINOR. During execution the guard for AC-1.3 (the app's own header, a Decks link added, 640px, headless Firefox) failed: five links make the account menu end 54.6px past the bar's content edge (nav 379.6px, wordmark 138px, bar padding 32px). The design system's preview header had hidden it. The maintainer ruled option A (decision 19): the logo mark replaces the wordmark from 640px up to the width where five links and the wordmark fit, the wordmark above it. New: decision 19, AC-1.3 rewritten (it could not pass), AC-1.5 and AC-1.6, a fourth CSS block in `additions.css`, the Navigation docs say it. No other criterion changes |
| 1.0.0 | 2026-11-10 | Approved at Gate A by the maintainer (option A): Q17 = A and Q18 = A as drafted, and decisions 14 (no ADR), 15 (an empty picker group is omitted) and 16 (a native open list may ignore the styling) confirmed. Status Approved; no text change |
| 0.3.1 | 2026-11-10 | The maintainer ruled Q17 = A and Q18 = A (decisions 17 and 18, as drafted); both `[NEEDS CLARIFICATION]` markers are removed. No other change |
| 0.3.0 | 2026-11-10 | Spec review round 2 (NEEDS REVISION, mechanical; 0 blocking, 3 major, 7 minor) fixed: the existing example that expects the label class `"c-select"` exactly is named and edited (M1; AC-4.6, Documents table); the 019 and 021 supersession names the frozen clauses that forbid editing `ItemTile.md` and `ItemPage.md` and expect a re-export (M2); AC-1.3 and AC-1.4 measure what can fail (the nav ends before the account menu; the fixed tab bar's last tab is inside the bar) (M3); 3.010:1; the cap's source order; AC-4.3 compares the font family too; AC-4.5 lists every select that must stay as it is; AC-7.4 allows an unrelated hit; the README's own "App additions (spec 057)" line. No round 3; the worker checked the edits |
| 0.2.0 | 2026-11-10 | Spec review round 1 (NEEDS REVISION; 0 blocking, 3 major, 10 minor) fixed: the 300px cap is the location select's alone through `c-select--wide`, which makes one view line a change (M1; decisions 4 and 18, AC-4.4, AC-4.6); supersession of specs 019 and 021 recorded (M2); `ItemTile.md` added to the re-export files, with two more comments (M3, decision 12); the file counts; two more previews with the old navigation (decision 17); the guard spec's constraints; AC-2.3 reads `tokens.css`, unrounded, and AC-2.4 corrects the README's "≥6:1"; AC-5.3 and AC-5.4 use the 328px page container; decision 16 corrected; AC-1.2 gains `AppHeader.md`'s "four links" sentence; AC-1.3 and AC-1.4 use the app's own header and tab bar; the hosted-door line; two questions open (17, 18) |
| 0.1.0 | 2026-11-10 | First draft, from issue #248, the issue design, and 16 rulings by the maintainer on 2026-11-10 (decisions 1–16 below), each made from mock-ups drawn with the real Collector CSS |

## Problem Statement

Decks are the next theme of 1.0, and every later deck issue ([#249](https://github.com/plainprogrammer/Collector/issues/249) and the ten after it) builds on written design rules. Today the design system has none: it says "Decks and Wishlist don't exist yet", it says the `mana-*` colours are "never used anywhere else in the UI" (a deck's mana bar must use them), it has no rule for charts, no deck vocabulary, no grouped location picker (a deck's zones can't sit in a flat list of places), and a card page that shows four stats and an "In decks" list written before proxies and Considering existed. Its README and `CLAUDE.md` still say the design system is "replaced wholesale by re-exporting" and tell every addition to "upstream" itself, although the maintainer ruled on 2026-11-09 that the project owns the design system in code.

This spec writes those rules and adds the CSS they need (grouped selects, a three-stat strip, the filter's width, and room in the header for five links), and retires the re-export wording. It changes documents, one stylesheet and six previews, and adds one class to one line of one view (the collection filter's location select, so the width the maintainer ruled applies to it). It changes no helper, model, route, query, export or migration, and no other view: the app catches up in the issues that build each part.

> **Terms.** A *place* is a location that is not a deck (a binder, a box). A *deck* is a location whose copies live in *zones*. A *proxy* is a stand-in for a card the collector doesn't own, recorded against a deck zone. *Considering* is the zone for cards being thought about. A *picker* is a location `<select>` in a form (the lot form, Move copies, typed entry, the scanner sitting, bulk Move to…); the *filter* is the collection's location select (spec 037). The full vocabulary is decision 9 and FR-3.

## Goals

- The design system's README and component docs state the rules decks follow: navigation with Decks as a live section, the `mana-*` colour rule, a Charts rule, the deck vocabulary, grouped location pickers, the card page's stats and "In decks" table, and a Locations page that lists places only.
- The CSS those rules need exists and is proved in a browser: group labels in selects, a three-stat strip, the filter's wider cap, and a header that holds five links from 640px (decision 19).
- The existing previews that the rules contradict show the new rules: `AppHeader`, `TabBar`, `ItemPage` and `ItemPagePhone` entirely, and `CollectionPage` and `CollectionPagePhone` for their navigation (decision 17).
- No file tells anyone to upstream a pattern or expects a re-export: the design system is the project's own.

## Non-Goals

- Any change to a helper, model, route, query, export or migration, or to a view other than the one class on the collection filter's location select (decision 4). The header and tab bar gain Decks with the deck pages ([#49](https://github.com/plainprogrammer/Collector/issues/49)), the grouped pickers with [#252](https://github.com/plainprogrammer/Collector/issues/252), the card page's stats and table with [#50](https://github.com/plainprogrammer/Collector/issues/50) and [#254](https://github.com/plainprogrammer/Collector/issues/254).
- The deck components (the shape panel's curve, types and mana bar, `ProxyTag`, `DeckPage`, `DecksIndex`, `AddToDeck`, `UseMyCopy`) and their previews: [#249](https://github.com/plainprogrammer/Collector/issues/249).
- A hatched-fill or chart CSS: this spec writes the Charts rule only; #249 draws the first charts.
- Any change to a token's value (`tokens.json`, `tokens.css`).
- How a deck with many zones reads in a picker on a phone (the issue design leaves it to #252).
- A new ADR: decision 18 of the issue design and this spec record that the design system is owned in code.

## Decisions

The maintainer ruled on each of these on 2026-11-10 from the mock-ups the worker drew with the real CSS (`tmp/mockups/index.html` in the worker's worktree; the shots for each decision are in the PR). The issue design's own decisions (9, 14–16, 18) are cited where they apply.

1. **Group labels in a select are quiet (ruled, option A).** `optgroup` labels are `ink-muted`, weight 600, not italic; options keep `ink` on `surface-raised`, the same in both themes. Two rules in `additions.css`, for `.c-field select` and `.c-select select`. The alternative, the browsers' defaults, draws bold italic labels in Firefox and differs by browser.
2. **A picker has groups only when the account has a deck (ruled, option A).** With no deck a picker is exactly as today: "No location" then the places, flat. With a deck: "No location", then the optgroup "Places", then the optgroup "Decks", whose options are written "Deck › Zone".
3. **The filter's "all zones" option sits first in each deck's run (ruled, option A).** In the filter, "All locations" and "No location" come first, outside any group, then "Places", then "Decks". Inside "Decks", each deck has one option "<Deck> (all zones)" followed by its zones "<Deck> › Zone".
4. **The collection filter's location select has a cap of 300px when the collection is 640px wide or wider, and 220px below that (ruled, option B).** At 220px a long selection clips its zone, the part that tells zones apart; on a phone the filter row scrolls sideways, and 300px would move the Filter button off screen. The cap belongs to the location select alone, through a modifier class on it (`c-select--wide`): the same `c-select` is also the Set select on the catalog search page, inside the same collection container, and a plain container rule would widen that one too. See decision 18.
5. **The Decks tab icon is the design system's own: a card and the one behind it (ruled, option B).** It is the icon of the original `TabBar` preview and of the card page's "Add to deck" button, so one icon means deck everywhere.
6. **Navigation (ruled, option B).** A collector's wide header, in order: Collection, Decks, Search, Scan, Locations. The phone tab bar: Collection, Decks, Search, Scan, More; Locations stays in More. The README keeps the line that collectors will later choose and reorder their sections, and says Wishlist is planned. The tab bar's limit of five tabs is now full: a new section starts in More. Decks joins the header and the tab bar when the deck pages ship (#49); the order is the rule for both from now on.
7. **The card page's stats strip has three stats and its own modifier (ruled, option A).** `c-stats--three`: three equal columns, three across at every width, because the labels fit at 360px. The existing narrow rules (`.c-stat + .c-stat { border-left:0 }`, `:nth-child(even)` border, `:nth-child(n+3)` top border) assume a two by two grid and would draw a stray border on the third stat, so the modifier carries its own narrow overrides. When "Est. value" returns with prices, the strip is the default four-up again. The small lines: Owned "N printings", In decks "in N decks", Free to use "not in a deck" (ruled, option A).
8. **"In decks" is a full-width table section after Printings, with Format legality below it (ruled, option A).** Columns: Deck (name link, the format muted beside it), Zone, Owned, Proxy. On a phone Zone folds under the deck name with the format (`c-table__sub`), as in the other tables. The Proxy column is always shown; a row with no proxy shows a muted dash. Owned counts the copies in that zone, Proxy the proxies in it. A proxy never counts in the page's Owned or In decks stats. The table reuses `CollectionTable`'s pattern: no new CSS.
9. **The deck vocabulary is a new README section "Decks", after Navigation (ruled, option A; text approved as drafted).** FR-3 states it.
10. **The Charts rule and the `mana-*` rule are approved as drafted (ruled, options A and A).** FR-2 states both. The measured contrast behind them: `ink-muted` is 5.5:1 or better on every surface in both themes, `line-strong` 3.0:1 or better, and the white mana fill is 1.1:1 on the light ground and the black one 1.2:1 on the dark ground, so a mana bar needs an outline and not only dividers.
11. **The Locations page lists places only, with no pointer to Decks (ruled, option A).** Decks have their own header link and tab and appear in every picker. The page's count counts places only. No new CSS.
12. **The re-export wording is retired everywhere it is an instruction or an expectation (ruled, option B).** The maintainer's ruling named six places: `CLAUDE.md`'s note and the README's "Upstream these…" lines (which the issue names), the comments in `additions.css`, `ImageFit.md`, `UnownedTile.md`, and the area docs `catalog-core.md` and `collection-and-lots.md`. The spec review found the same wording in three more places, which the same ruling covers: `ItemTile.md`'s modifier sentence (it still says `c-tile--owned-none` fades, which the CSS no longer does), the second override comment in `additions.css` ("once an export drops that fade"), and a comment in `spec/design_system_files_spec.rb`. A statement that only says where a rule came from ("the export's `c-stats` grid") stays as history. Where a file says an override of the export "holds" (`UnownedTile.md`, `ImageFit.md`), it keeps that fact, and says only that `components.css` still carries the original rule.
13. **The existing previews that show the old navigation or the old card page are updated now (ruled, option A for the four, and decision 17 for two more).** `AppHeader`, `TabBar`, `ItemPage` and `ItemPagePhone` show the new rules and link `additions.css`, which they didn't, so the new rules show in them. The "Add to deck" button already in the card page preview stays as it is (a later issue owns it).
14. **No ADR (my call, to be confirmed at Gate A).** The decision that the design system is owned in code is the maintainer's (issue design decision 18, 2026-11-09), has no alternative with a cost to weigh, and is recorded here and in the README.
15. **An empty group is omitted (my call, to be confirmed at Gate A).** An account with decks and no places has no "Places" group, and an account with places and no decks is the flat picker of decision 2. The maintainer's ruling covers "no decks"; this is its mirror.
16. **The browser's own list is not our job (my call).** Group labels show only in the open list of a `<select>`, which the browser or the phone draws; Firefox on a desktop honours decision 1, native menus (macOS, phones) honour less or none of it. The closed control never shows a label. Nothing depends on the label's styling: with it ignored a group label is still a label, and the options are still readable. AC-4.2 and AC-4.3 therefore prove that the rule applies (the computed style of the group and its options), not how a native menu looks.
17. (Q17 = A, ruled 2026-11-10.) `CollectionPage.html` and `CollectionPagePhone.html` also show the old header (Wishlist) and tab bar. Their header links and tab bar are updated to decision 6 and nothing else on them changes.
18. (Q18 = A, ruled 2026-11-10.) The 300px cap is the location select's alone (decision 4); the Set select on search and the Language select on number entry stay at 220px.
19. **The header makes room for five links with the logo mark (ruled, option A, 2026-11-10; version 1.1.0).** The app's own header with five links overflows from 640px: measured in headless Firefox with classic scrollbars, the account menu ends 54.6px past the bar's content edge at a 640px viewport, and five links plus the wordmark first fit at a 695px viewport (a 625px layout width). From 640px up to **719px** the logo mark replaces the wordmark (the phone header's own pattern, existing assets), and from **720px** the wordmark shows again; 720px is the measured 695px with 25px to spare for font rendering. The maintainer ruled the swap; my two calls inside it, for the visual review to veto: the rule applies only while the nav holds five or more links (`:has(.c-appbar__nav > :nth-child(5))`), so today's four-link header is unchanged until #49 adds Decks, and the upper bound is 720px rather than the bare minimum. Considered and not chosen: tighter bar and link padding (the overhang drops to 0 only with both, and the links crowd), no CSS change and leaving the band to #49 (a known overflow handed on), and moving the nav and tab bar switch to 720px (it rewrites the export's media rules and changes the tab bar).

## Users and Context

**Primary users:** the agents and the maintainer who build the next deck issues, reading the design system before writing a view; secondarily the collector, who meets these rules as the screens they produce.
**Usage context:** `collector-design-system` tells every agent to read `docs/design-system/README.md`, the component's doc and the preview before writing UI. These documents are the only place the deck rules are written.
**User mental model:** a deck is a place with parts (zones) that holds the copies it uses; a proxy is a card you are borrowing the idea of, never one you own; "free to use" is what is left of what you own.

## User Stories

### Story 1: Navigation with Decks

**As an** agent building the Decks section
**I want** the design system to state where Decks sits in the header and on the phone
**So that** I don't guess, and the tab bar still works.

**Acceptance criteria:**

- [ ] **AC-1.1** Given the README's Navigation section When it is read Then it states the wide header order (Collection, Decks, Search, Scan, Locations), the phone tab bar order (Collection, Decks, Search, Scan, More) with Locations in More, that collectors will later choose and reorder their sections and no position is hard-coded, that Wishlist is planned, that the tab bar holds five tabs at most and is now full so a new section starts in More, and that Decks joins when the deck pages ship; and it no longer says "Decks and Wishlist don't exist yet" or lists Wishlist as a default section
- [ ] **AC-1.2** Given `AppHeader.md`, `TabBar.md` and `MorePage.md` When they are read Then each says the same order, `AppHeader.md`'s sentence that "the four links share one line" at 640px says five and says the logo mark replaces the wordmark from 640px to 719px while the nav holds five links (decision 19), `TabBar.md`'s markup shows the five tabs with the Decks icon (a card and the one behind it), and `MorePage.md` says Locations stays in More because the tab bar's fifth tab is More and its tabs are full (not "the tab bar doesn't change")
- [ ] **AC-1.3** Given the app's own header (`layouts/_appbar`: wordmark, nav, `+` button, account menu) with a Decks link added to its nav after Collection When it is rendered at a 640px viewport (where the nav first appears) and at a 719px viewport Then there are five links, all with the same top (one line), the nav's right edge is at or before the account menu's left edge, the account menu's right edge is at or inside the bar's content edge, the page's scroll width is no more than the window's, and the mark shows and the wordmark does not (decision 19; the five-link sibling of spec 029 AC-5.1's measure, which stays as it is for today's four links)
- [ ] **AC-1.4** Given the app's own tab bar (`layouts/_tabbar`) with a Decks tab added after Collection When it is rendered at a 360px viewport Then there are five tabs, the last tab's right edge is at or inside the bar's right edge, the bar's scroll width is no more than its client width, and each tab's text fits inside its tab (the bar is fixed, so page overflow alone can't see it overflow)
- [ ] **AC-1.5** Given the same header at a 720px viewport Then the five links fit as in AC-1.3 and the wordmark shows and the mark does not (so the swap ends where five links and the wordmark fit, and no earlier)
- [ ] **AC-1.6** Given the app's own header as it is today, four links, at a 640px viewport When it is rendered Then the wordmark shows and the mark does not (decision 19: the swap waits for the fifth link)

### Story 2: Mana colour and charts

**As an** agent drawing a deck's curve and mana bar
**I want** the colour rules to say where the `mana-*` colours and neutral fills belong
**So that** no chart uses `brand` or depends on colour alone.

**Acceptance criteria:**

- [ ] **AC-2.1** Given the README's Color section and `ManaCost.md` When they are read Then both say the `mana-*` colours are data colours used only to show mana (the `ManaCost` pips and charts of mana symbols), the fills stay apart from `success`, `warning` and `danger` and are the same in both themes, the letter or number always shows, and every use has a 1px `line-strong` outline; and neither says they are "never used anywhere else in the UI"
- [ ] **AC-2.2** Given the README When it is read Then it has a Charts rule (FR-2) stating the neutral fills, that every column or segment carries a word or a number, the `aria-label`, the 3:1 floor and the outline a mana bar needs
- [ ] **AC-2.3** Given `tokens.css` (the file the app ships; its light block, its dark block and its dark-by-preference block) When `ink-muted` and `line-strong` are each compared with `surface`, `surface-raised` and `surface-sunken` in each block Then every ratio, unrounded, is at least 3:1 (the Charts rule's floor holds, and a change to a token that breaks it fails; the lowest today is `line-strong` on the light `surface-sunken`, 3.010:1)
- [ ] **AC-2.4** Given the README's Color section When its sentence about text colours is read Then it says `ink` and `ink-muted` read on the three surfaces in both themes at 5.5:1 or better (the README says "≥6:1", which `ink-muted` on the light `surface-sunken`, 5.50:1, does not meet)

### Story 3: Deck vocabulary

**As an** agent writing copy for a deck screen
**I want** one definition of each deck word
**So that** the same word means the same thing on every screen.

**Acceptance criteria:**

- [ ] **AC-3.1** Given the README When it is read Then a section "Decks" after Navigation defines deck, zone, Considering, proxy, "Deck › Zone", Free to use and Places as FR-3 states them, naming no format and no collectible
- [ ] **AC-3.2** Given the README's "Who it's for" section, `ItemPage.md`'s Stats bullet and `SKILL.md`'s deck line When they are read Then none says "a deck is a location like a binder or a box" or that "Free to use" is "owned minus in decks" without Considering and proxies, and each agrees with FR-3

### Story 4: Grouped location pickers

**As an** agent building a location picker
**I want** the rule for grouping places and decks, and the CSS that draws the groups
**So that** a deck's zones sit apart from the places and read "Deck › Zone".

**Acceptance criteria:**

- [ ] **AC-4.1** Given `Form.md` and `FilterSelect.md` When they are read Then they state decisions 2, 3 and 15 (groups only when the account has a deck; "No location" first; "Places" then "Decks"; an empty group omitted; zones written "Deck › Zone"; in the filter "All locations", "No location", and "<Deck> (all zones)" first in each deck's run), that the location filter's cap is 300px (`c-select--wide`) from a 640px collection and 220px below it while every other `c-select` stays at 220px, and that the browser draws the open list (decision 16)
- [ ] **AC-4.2** Given a `Form` select (`.c-field select`) with an `optgroup` and options When the page is rendered in the light and the dark theme Then the computed style of the `optgroup` is `ink-muted` text, weight 600, normal style, and of its `option` `ink` text on a `surface-raised` background, and an `option` outside any group is unaffected
- [ ] **AC-4.3** Given a filter select (`.c-select select`) built the same way When it is rendered in the light and the dark theme Then it has the same computed label and option styles as AC-4.2, and the options' font size and font family equal the select's (an `optgroup` rule that sets the `font` shorthand, or a browser's built-in `optgroup` font, would change the options inside it)
- [ ] **AC-4.4** Given the collection page of an account with a location, in normal view and in bulk mode When the filter's location select is measured in a collection 700px wide Then its computed `max-width` is 300px; in a narrow frame (a 390px phone) it is 220px; and the Set select on the catalog search page in the same 700px collection is 220px
- [ ] **AC-4.5** Given the lot form, Move copies, bulk Move to…, the scanner's and typed entry's pickers and Language select, and the catalog search's Set select as they are today (flat places, no deck, no `c-select--wide`) When the stylesheet changes Then they look and behave as before: no existing request or system example changes except the one that reads the collection filter's label class (AC-4.6)
- [ ] **AC-4.6** Given the collection page of an account with a location, in normal view and in bulk mode When its HTML is read Then the location filter's `label` has the classes `c-select c-select--wide`, and the collection page of an account with no location still has no location filter. The existing example that expects the class to equal exactly `"c-select"` (`spec/requests/collection_location_select_spec.rb`, line 32) is edited to expect both, and is the first failing test for this change

### Story 5: The card page's stats and "In decks"

**As an** agent building the card page's deck parts
**I want** the stats strip and the "In decks" table written down, with the CSS the strip needs
**So that** #50 and #254 build them from rules.

**Acceptance criteria:**

- [ ] **AC-5.1** Given `ItemPage.md` and `ItemPagePhone.md` When they are read Then they state the 1.0 stats (Owned, In decks, Free to use; Est. value waits for prices, and the strip is four-up again with it), the three small lines, the section order (stats, your copies, printings, in decks, format legality), the full-width "In decks" table with its four columns, the dash for no proxy, that proxies never count in Owned or In decks, and the phone layout (stats three across; Zone folds under the deck name with the format)
- [ ] **AC-5.2** Given a `c-stats c-stats--three` strip of three stats in a card page container 900px wide When it is rendered Then it has three equal columns and a 1px `line` divider between neighbours
- [ ] **AC-5.3** Given the same strip in a card page container 328px wide (a 360px phone less the page's 16px gutters) When it is rendered Then it still has three equal columns, the second and third stats each have a 1px left border, no stat has a top border, and the strip has no horizontal overflow
- [ ] **AC-5.4** Given a default four-stat `c-stats` strip and a `c-stats--single` strip in a 328px card page container When they are rendered Then the four-up strip is still two by two with its dividers as before and the single strip is still one column
- [ ] **AC-5.5** Given `SingleStat.md` When it is read Then it points to `c-stats--three` as the strip for three stats

### Story 6: Locations lists places only

**As an** agent changing the Locations page
**I want** the page's scope written down
**So that** decks are never listed there.

**Acceptance criteria:**

- [ ] **AC-6.1** Given `Locations.md` When it is read Then it says the page lists places only, its count counts places only, decks live on their own page (Decks, with its own header link and tab), and no pointer to Decks is on the page

### Story 7: The design system is owned in code

**As an** agent or the maintainer
**I want** no file to tell me to upstream a pattern or wait for a re-export
**So that** a new pattern goes straight into the project's own CSS and docs.

**Acceptance criteria:**

- [ ] **AC-7.1** Given `CLAUDE.md`'s "UI and design system" section When it is read Then it no longer says the export's files are "replaced wholesale by re-exporting"; it says the design system is the project's own in code, new patterns go in `collector/additions.css` with a doc under `docs/design-system/components/`, and rules change in `docs/design-system/README.md`
- [ ] **AC-7.2** Given the README's App additions lines When they are read Then none says "Upstream these into the published design system before the next export replaces this folder" (each line keeps its spec, its classes and its facts), and the README states in its Components section that the design system is the project's own, how a new pattern is added, and where a rule changes
- [ ] **AC-7.3** Given `additions.css`'s heading comment and its two override comments (image fit, unowned tile), the comment at `spec/design_system_files_spec.rb` line 49, `ImageFit.md`, `UnownedTile.md`, `ItemTile.md`, `catalog-core.md` and `collection-and-lots.md` When they are read Then none tells a reader to upstream a pattern or says a re-export will replace, drop or undo a rule, each statement that remains says only where the rule came from, `ItemTile.md`'s `c-tile--owned-none` sentence points to `UnownedTile` instead of saying the tile fades, and `additions.css` still has "spec 019" once, "spec 021" once and no "font" in the image-fit block (`spec/design_system_files_spec.rb` counts them and stays green)
- [ ] **AC-7.4** Given the repository When `git grep` searches for "re-export", "replaced wholesale", "Upstream", "before the next export", "an export that" and "published design system" in `CLAUDE.md`, `.claude/skills`, `docs/design-system`, `docs/architecture`, `app/assets/stylesheets` and `spec` Then every hit is a statement of history (where a rule came from) or is unrelated to the design system (such as the export format's "re-exports" in `spec/models/collection_import/round_trip_spec.rb`), and none is an instruction or an expectation; `verification.md` lists the hits and the reading

### Story 8: The previews show the rules

**As an** agent told to "match the preview"
**I want** the previews to agree with the README
**So that** I don't copy a header with Wishlist or a card page with four stats.

**Acceptance criteria:**

- [ ] **AC-8.1** Given `previews/AppHeader.html`, `previews/TabBar.html`, `previews/CollectionPage.html` and `previews/CollectionPagePhone.html` When they are opened Then the header links read Collection, Decks, Search, Scan, Locations (Collection current on the collection previews) and the tab bar reads Collection, Decks, Search, Scan, More with the Decks icon, in both themes, and no preview names Wishlist
- [ ] **AC-8.2** Given `previews/ItemPage.html` and `previews/ItemPagePhone.html` When they are opened Then they show the three-stat strip, the full-width "In decks" table, Format legality below it and the five-link header and five-tab bar, in both themes, at 1280px and 390px
- [ ] **AC-8.3** Given the six previews When their `<link>` tags are read Then each links `additions.css` after `components.css`

## Functional Requirements

### FR-1: Navigation (README, `AppHeader.md`, `TabBar.md`, `MorePage.md`)

Replace the default-sections sentence and "Decks and Wishlist don't exist yet" with decision 6. The header's nav, the tab bar and the More page say the same order. The five-tab limit stays; it is now full.

**Must:** state both orders; keep "collectors will later choose and reorder", "never hard-code a section's position", "profile, settings and import/export live in the avatar menu or More", and "detail pages use `c-appbar--detail`"; say Wishlist is planned; update `TabBar.md`'s markup and its sentence "four sections (the collector's choice; …)".
**CSS (decision 19):** one block in `additions.css`, headed `(spec 057 …)`, inside `@media (min-width: 640px) and (max-width: 719px)`: while the nav holds five or more links the mark shows and the wordmark hides (the same two declarations as the phone rule in `components.css`). `AppHeader.md` and the README's Navigation section state it; the previews load `additions.css`, so they show it.
**Must not:** change a rule of the header or tab bar other than the sections and the logo swap of decision 19 (height, sticky, current tab, 56px tabs).

### FR-2: Colour (README Color section, `ManaCost.md`)

The mana rule and the Charts rule, as ruled:

> **Mana colours.** The `mana-*` colours are data colours, used only to show mana: the `ManaCost` pips and charts of mana symbols. The fills stay apart from `success`, `warning` and `danger` and are the same in both themes. The letter or number always shows, and every use has a 1px `line-strong` outline.
>
> **Charts.** Fills are neutral: `ink-muted` for the main series, a hatched `line-strong` fill with an `ink-muted` outline for a second series stacked on it; never `brand` (brand means an action) and never a status colour. Every column or segment carries a word or a number (a count above a column; a letter and count in a segment; a segment too narrow for its label shows them in the caption beneath), and a legend or caption names each series, so colour or pattern is never the only signal. The chart is `role="img"` with an `aria-label` that reads the values. Fills and outlines hold 3:1 against the ground they sit on. A chart of mana symbols may use the `mana-*` fills, each with a 1px `line-strong` outline, and a divider between segments, because the white and black fills disappear on the light and dark ground.

`ManaCost.md`'s bullet "never used anywhere else in the UI" is replaced by the mana rule. The README's "Never use a game's … mana symbols … as UI decoration" line stays.

**Must:** put the Charts rule in the Color section after the status-colour line; keep both rules collectible-agnostic in the README's words (it already names Magic's pips in `ManaCost`).
**Must not:** change a token; add chart CSS.

### FR-3: Deck vocabulary (README "Decks" section, "Who it's for", `SKILL.md`, `ItemPage.md`)

A new section "Decks" after Navigation, with these definitions (decision 9):

- **Deck:** a kind of location. Its copies live in its zones.
- **Zone:** a named part of a deck, such as Main or Sideboard. Which zones a deck has depends on its format; every deck has Considering.
- **Considering:** the zone for cards you are thinking about. Copies there are in the deck.
- **Proxy:** a stand-in for a card you do not own, recorded against a deck zone with a printing. A proxy never counts as owned; it is not in Owned, In decks or Free to use.
- **"Deck › Zone":** how a zone is named wherever a place is shown or chosen (tiles, rows, pickers): the deck's name, a single right angle quote (›), the zone's name. A zone is never shown without its deck.
- **Free to use:** copies you own minus copies in any deck zone, Considering included. Proxies don't change it.
- **Places:** your locations that are not decks (a binder, a box). "Places" is the picker's group label; the page is still "Locations".

"Who it's for" keeps its first sentence about a copy being in one place at a time and replaces "A deck is a location like a binder or a box" and the "Free to use" sentence with the vocabulary's. `SKILL.md`'s line "a deck is a location. 'Free to use' = owned − in decks." and `ItemPage.md`'s Stats bullet are brought into line. The digital-decks parenthesis in "Who it's for" stays.

**Must:** name no format and no collectible type in the Decks section (the deck page's shell stays collectible-agnostic).
**Must not:** define a zone key, a format or a limit; those are #49's.

### FR-4: Grouped pickers (`Form.md`, `FilterSelect.md`, `additions.css`)

Decisions 1–4. The docs state the groups and names; the CSS is:

- `optgroup` inside `.c-field select` and `.c-select select`: `ink-muted`, weight 600, `font-style: normal`; `option` inside them: weight 400, `ink` text, `surface-raised` background. No `font` shorthand on `optgroup` (the options inherit it: a size there shrinks every option).
- `.c-select--wide select` raises its `max-width` from 220px to 300px when it is in a collection container at 640px or wider (`@container collection (min-width: 640px)`); `collections/_location_select.html.erb` puts `c-select--wide` on its label, which is the only view change. Every other `c-select` keeps 220px. The rule has the specificity of `.c-select select` (a container query adds none), so it comes after the filter-bar select block in the file, or is written `.c-select.c-select--wide select`.
- The options may inherit their size and family; the ban is on setting `font` on `optgroup`. A `font-size: inherit` or `font-family: inherit` on the options, written as separate properties, is allowed if a browser's own `optgroup` font would otherwise change them.
- Each new block of rules has a heading comment of its own (`/* ---------- … (spec 057) */`): `spec/design_system_files_spec.rb` finds an override's block by its heading and counts its rules up to the next heading, so a rule added without a heading is counted in the block above it.

**Must:** leave a flat select's look as today; keep the select native (keyboard, screen readers and phone pickers work without scripting); keep a required select's "Choose…" rule and an optional select's "Not specified" rule.
**Must not:** replace the native select with a custom list, add JavaScript, or hard-code a colour.

### FR-5: The card page's stats and "In decks" (`ItemPage.md`, `ItemPagePhone.md`, `SingleStat.md`, `additions.css`)

Decisions 7 and 8. CSS in `additions.css`, next to `c-stats--single`:

- `.c-stats--three { grid-template-columns: repeat(3, minmax(0, 1fr)) }`.
- Inside `@container page (max-width: 639px)`: three columns again; a `line` left border on every stat after the first; no top border on any stat; the stat's padding `space-3` so the labels fit at 360px.

The "In decks" table is `CollectionTable`'s pattern (`c-table` in `.c-collection`, numeric cells `is-num`, the format and the phone line as the other tables do); the deck's name is the table's link in `brand` as `TableItemLink` documents.

**Must:** keep the default `c-stats` (four-up, two by two below 640px) and `c-stats--single` unchanged.
**Must not:** change a view: the card page shows `c-stats--single` today and keeps doing so until #50.

### FR-6: Locations (`Locations.md`)

Decision 11: one paragraph. Places only; the count counts places only; decks live on their own page; no pointer. The empty-state sentence is unchanged.

### FR-7: The design system is owned in code (decision 12)

The README says in its Components section that the design system is the project's own, that a new pattern goes in `collector/additions.css` with a doc under `components/` and a line in the README's list, and that a rule changes in the README itself. The README's 14 "App additions" lines keep their specs, classes and facts and lose the "Upstream … before the next export replaces this folder" sentence, and a fifteenth line, "App additions (spec 057, in `collector/additions.css`)", names the grouped select's label and option rules (documented in `Form` and `FilterSelect`), `c-select--wide` (`FilterSelect`) and `c-stats--three` (`ItemPage`). `CLAUDE.md`'s "UI and design system" section drops "The export's files … are replaced wholesale by re-exporting the published design system" and keeps "app-specific patterns live in `collector/additions.css` with a doc per pattern under `docs/design-system/components/`". The other files of decision 12 (`additions.css`'s three comments, `ImageFit.md`, `UnownedTile.md`, `ItemTile.md`, `catalog-core.md`, `collection-and-lots.md` and the comment in `spec/design_system_files_spec.rb`) lose their upstream and re-export statements. Each area doc edit cites this spec's decision 12 inline, and `ItemTile.md`'s modifier sentence points to `UnownedTile`.

### FR-8: Previews (decision 13)

`AppHeader.html`, `TabBar.html`, `ItemPage.html` and `ItemPagePhone.html` are edited to FR-1 and FR-5, and `CollectionPage.html` and `CollectionPagePhone.html` to FR-1 only (their header links and tab bar), and all six link `additions.css`. None shows a select today, so FR-4 changes no preview. A preview shows the same markup the docs show.

## Non-Functional Requirements

### Accessibility

- Text holds 4.5:1 on every surface in both themes, and every fill or outline the new rules name holds 3:1 (AC-2.3).
- Every control keeps its focus ring; the five tab targets stay at least 56px tall and every header link at least 44px by 44px on touch.
- Nothing the new CSS draws needs JavaScript; the grouped select is native.

### Layout

- Everything works from 360px wide, in both themes. The three-stat strip and the five-tab bar don't scroll sideways at 360px.
- The previews render at 1280px and 390px in both themes with no console error (the previews load their fonts from `preview-fonts.css`).

### Hosted door

Checked against the hosted-door rules ([north star](../../north-star.md)): the spec adds no collector-owned data, so there is nothing to export, no per-account state, no sign-up, email or billing, and no data of a source that a hosted instance would have to expose. Cost per account: none (documents, one stylesheet and one class).

### Documentation

- A change of a rule updates the doc that states it in the same commit; each changed area doc line cites this spec (`.claude/rules/documentation.md`).
- No RSpec example reads a prose document (`.claude/rules/testing.md`): the document criteria are verified by reading and recorded in `verification.md`. The CSS criteria are proved in a browser.

## Error Scenarios

| Scenario | Expected behaviour |
|----------|--------------------|
| A browser or phone draws the open list of a select itself and ignores the label's colour or weight | The group label is still a label: indented options under a heading. Nothing relies on the styling (decision 16) |
| A deck's name is long in a picker or in the filter | The browser clips the closed select's text (the existing rule); the filter's 300px cap from 640px shows more of a zone than 220px |
| An account has no deck | A picker is flat, exactly as today (decision 2); the filter has "All locations", "No location" and the places |
| An account has decks but no places | "No location" then the "Decks" group; the empty "Places" group is omitted (decision 15) |
| A later issue needs a fourth stat on the card page (Est. value) | The strip is the default four-up `c-stats`; `c-stats--three` is dropped for that page |
| A new section is wanted in the tab bar | It starts in More; the five-tab limit is full |
| A window 640px to 719px wide with five header links | The logo mark replaces the wordmark; the five links share one line with the account menu (decision 19) |
| A sixth header link is added later | The header no longer fits at 640px; the guard for AC-1.3 fails until the rule is revisited |

## Open Questions

None. The maintainer ruled on every question (decisions 1–13, 17, 18 and 19). Decisions 14, 15 and 16 are my calls for Gate A to confirm.

## Out of Scope (Future Considerations)

- The deck components, previews and the hatched fill: [#249](https://github.com/plainprogrammer/Collector/issues/249).
- The Decks section, its header link and tab, deck pages and removal, formats and zones in code, the export: [#49](https://github.com/plainprogrammer/Collector/issues/49).
- Grouped pickers in the lot form, Move copies, bulk Move to…, typed entry, the scanner sitting and the filter; tiles and rows naming "Deck › Zone": [#252](https://github.com/plainprogrammer/Collector/issues/252).
- The card page's stats, "In decks" table, Free to use and the proxies rule: [#50](https://github.com/plainprogrammer/Collector/issues/50) and [#254](https://github.com/plainprogrammer/Collector/issues/254). What "In decks" shows for a deck with only proxies of the card is left to #50.
- A collector choosing and reordering their sections; Wishlist.
- How a deck with many zones reads in a picker on a phone ([#252](https://github.com/plainprogrammer/Collector/issues/252)).

## Supersedes

- [Spec 029](../029-manage-locations/spec.md) decision 8, the header's links for a collector (Collection, Search, Scan, Locations): the rule gains Decks after Collection (decision 6). The header's code changes in #49.
- [Spec 037](../037-filter-collection-by-location/spec.md) AC-6.4's "at most 220px", for a collection 640px wide or wider (decision 4), and its option list (all, none, then the locations) when the account has a deck (decisions 2 and 3). The select's markup changes in #252; its width rule changes here.
- [Spec 004](../004-design-system-collection/spec.md) FR-1, the `CLAUDE.md` guidance that "the repo copy is updated by re-exporting": the design system is the project's own, in code (decision 12).
- [Spec 019](../019-uncropped-card-images/spec.md) AC-4.2 (the README line for the image-fit override "says to upstream it"); the parts of its decision 1 ("An override in `additions.css`, not a re-export") and FR-3 ("Make the change where a re-export can't undo it") that expect a re-export and the block's deletion once the published design system fits images this way; FR-4's "list it in the README's app additions as an override to upstream" and its "Must not" on editing the exported component docs (`ItemTile.md`, `ItemPage.md`, `CollectionTable.md`), which a re-export replaces; and the Error Scenarios row "A re-export ships the fix upstream … removed in that re-export's PR": the override stays as the project's own rule, and the component docs are the project's to edit (decision 12). Its guard (`spec/design_system_files_spec.rb`) is unchanged.
- [Spec 021](../021-unowned-tile-marker/spec.md) decision 8 ("An override in `additions.css`, not a re-export"), Story 3 ("The change survives a re-export"), the Non-Goal "Editing … the exported document `ItemTile.md`", FR-4's "The exported `ItemTile.md` is not edited", and the Open Questions entry that `ItemTile.md` "still describes the fade until the published design system changes and is re-exported": `ItemTile.md` now points to `UnownedTile` (decision 12).
- No frozen spec is edited.

## Documents and Files Changed

| File | Change |
|------|--------|
| `docs/design-system/README.md` | Who it's for; Color (mana rule, Charts); new Decks section; Navigation; Components (ownership); the 14 App additions lines |
| `docs/design-system/components/AppHeader.md`, `TabBar.md`, `MorePage.md` | Navigation (FR-1) |
| `docs/design-system/components/ManaCost.md` | The mana rule (FR-2) |
| `docs/design-system/components/Form.md`, `FilterSelect.md` | Grouped pickers (FR-4) |
| `docs/design-system/components/ItemPage.md`, `ItemPagePhone.md`, `SingleStat.md` | Stats and "In decks" (FR-5) |
| `docs/design-system/components/Locations.md` | Places only (FR-6) |
| `docs/design-system/components/ImageFit.md`, `UnownedTile.md` | Re-export wording (FR-7) |
| `docs/design-system/components/ItemTile.md` | The `c-tile--owned-none` sentence points to `UnownedTile` (FR-7) |
| `docs/design-system/previews/AppHeader.html`, `TabBar.html`, `ItemPage.html`, `ItemPagePhone.html`, `CollectionPage.html`, `CollectionPagePhone.html` | FR-8 |
| `app/assets/stylesheets/collector/additions.css` | Grouped selects, the filter's cap, `c-stats--three`, the header's logo swap (each under its own `(spec 057)` heading); the heading comment and two override comments (FR-4, FR-5, FR-7) |
| `app/views/collections/_location_select.html.erb` | One class, `c-select--wide`, on the label (FR-4) |
| `.claude/skills/collector-design-system/SKILL.md`, `CLAUDE.md` | The deck line; the ownership note (FR-3, FR-7) |
| `docs/architecture/catalog-core.md`, `collection-and-lots.md` | Re-export wording (FR-7) |
| `docs/specs/README.md` | This spec's row; "Superseded by" for 004, 019, 021, 029 and 037 |
| `spec/design_system_files_spec.rb` | One comment (FR-7) |
| `spec/system/` (one new file) | AC-1.3 to AC-1.6, AC-1.4, AC-4.2 to AC-4.4, AC-5.2 to AC-5.4; `spec/system/locations_spec.rb` (four links at 640px) is unchanged until #49 adds Decks to the real header |
| `spec/requests/collection_location_select_spec.rb` | One edited example (line 32, the label's class), AC-4.6 |
| `spec/design_system_tokens_spec.rb` (new) | AC-2.3 |

## Verification

- **Document criteria** (AC-1.1, 1.2, 2.1, 2.2, 2.4, 3.1, 3.2, 4.1, 5.1, 5.5, 6.1, 7.1, 7.2, and the reading of AC-7.3 and 7.4): read against the text; the quotations, the `git grep` hits and their readings are recorded in `verification.md`.
- **CSS and layout criteria** (AC-1.3 to 1.6, 4.2 to 4.4, 5.2 to 5.4): a system example loads a real page (the header and tab bar are the app's own partials with a Decks link and tab added in the page; the selects and the stats strip are markup added to a real page, since no page has them yet), reads computed style and layout in a browser, uses a fixed-width frame for narrow widths, and each example is shown to fail when its rule is removed.
- **Contrast** (AC-2.3): a unit example computes the unrounded ratios from the three blocks of `tokens.css` (the file the app ships; testing.md bars reading prose documents, and tokens are code). AC-2.4 is a prose statement: verified by reading.
- **The filter's class** (AC-4.6): a request example on the collection page, normal and bulk.
- **Unchanged flat select, default and single stats, the guard spec** (AC-4.5, AC-5.4, AC-7.3): the existing request and system examples and `spec/design_system_files_spec.rb` stay green.
- **Previews** (AC-8.1 to AC-8.3): the `<link>` tags are read (AC-8.3); each preview is opened in headless Firefox at 1280px and 390px in both themes, and the screenshots go in the PR and in `verification.md`.
