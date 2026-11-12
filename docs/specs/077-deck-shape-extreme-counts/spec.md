# Feature 077: The Deck Shape Panel Stays Tidy at Extreme Counts

**Status:** Draft
**Version:** 0.3.0
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 060](../060-deck-components/spec.md) (the `DeckShape` component and its CSS), [spec 069](../069-deck-shape-panel/spec.md) (the panel's figures; its verification "Findings" 1 to 4 are this spec's input), both merged
**Branch:** `077-deck-shape-extreme-counts`
**Issue:** [#320](https://github.com/plainprogrammer/Collector/issues/320) (design-system lane, filed by the maintainer's ruling from spec 069's implementation review)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.3.0 | 2026-11-11 | Spec review round 2 (Opus, read-only; REVISE: 0 blocking, 1 major, 4 minor, 3 nit), all taken: the fixture's red is 2,595 (AC-4.1's strings); the band's shares are 13.5%, 16.5% and 19.5% in both places; the Non-Goal and Goal 1 agree on five-digit Card types rows; AC-5.1 and AC-5.3 require the band and its follow-up issue to be recorded and the 060 AC-2.4 row is qualified; option B is costed; the method is named (`short_count`); AC-2.2's thin room is flagged for the CI runner; the preview comment's chain |
| 0.2.0 | 2026-11-11 | Spec review round 1 (Opus, read-only; REVISE: 0 blocking, 4 major, 10 minor, 7 nit), all taken: AC-1.2's numbers follow spec 069's real fixture (column 1 reads "9", "Owned 132"); AC-2.2 measures against the segment's `clientWidth` less 2px and the label's width is the synthesized bold's (about 43.5px); Goal 1 is narrowed to what is fixed and the unfixed mana band is measured and named, with a narrow rule that follows the label offered as option B for Gate A; decision 1 states its trade-off (a column's exact count is in the `aria-label` only); decision 3's alternative corrected, the name cell's `overflow-wrap`, FR-2's CSS points and AC-3.1b for five-digit counts; AC-4.3's unfailable clause explained; AC-6.2's comment update; the `allow_browser` floor; spec 074's possible padding change; the preview's stale comment; nits |
| 0.1.0 | 2026-11-11 | First draft from issue #320, spec 069's verification "Findings", `DeckShape.md`, the lessons of 2026-11-11 on phone widths, measurement traps and worst-case states, and a measurement of the four limits in headless Firefox (below). Routing: the issue asks for a ruling per item, and the rulings change rules of two shipped specs (060, 069), so it is a spec, not a direct fix |

## Problem Statement

Spec 069 drew the deck shape panel on spec 060's CSS and found four layout limits that show only at extreme counts, a deck or a collection with more than a thousand cards of one kind. It left them in its `verification.md` and `DeckShape.md` for a ruling. The worst-case fixture is spec 069's own: a Main zone with 123 owned and 1,234 proxy copies of one creature (a 6+ column of 1,357), a hybrid-cost proxy that puts about 2,591 coloured symbols on each of the five colours, and 20 lands.

> **Terms.** A *viewport* is the width a phone reports (360px). A *frame* is the test's iframe, which keeps a 15px classic scrollbar (so a frame is the viewport plus the scrollbar; lesson `docs/lessons/2026-11-11-a-phone-width-criterion-needs-a-measured-chain.md`). The *interior* is the space inside the open panel's border and padding: viewport − 16 (body) − 32 (page padding) − 2 (border) − 32 (panel padding). *Abbreviated* means a count written with a unit: 1,357 is "1.4k".

### Measurement (2026-11-11, headless Firefox, the fixture above, the fold open)

| Where | Interior | 6+ count's room in its column | A mana label ("W 2,591") against its segment | Type counts' right edges (Creatures, Lands) | Caption lines |
|---|---|---|---|---|---|
| A 360px viewport (375px frame) | 278px | +0.28px | 50.8px of 54.4px, touching the borders | 231.8, 239 (7.2px apart) | breaks inside "Black / 2,591" and ends a line with "·" |
| A 360px frame (a 345px viewport) | 263px | **−1.85px** | 50.8px of 51.4px | 216.8, 224 | same |
| A 320px viewport (335px frame; a 320px phone, the narrowest the page is meant for) | 238px | **−5.43px** | **wraps onto two lines** (36px) | 191.8, 199 | breaks inside "Green / 2,591" |
| The aside at 1280px (a 320px panel) | 286px | +1.43px | 50.8px of 56px (5.2px to spare) | 1120.8, 1128 | breaks inside "Black / 2,591" |

So the four limits are real, and two are worse than the issue says: the curve's count also overflows at a 320px viewport by 5.43px, and the mana labels wrap onto two lines there. The caption's "leading dot" is not seen in this fixture (the dot ends lines); the two spaces around each "·" allow a break on either side of it, so a line may begin with it (the text is "Black 2,591 · 20% · Red …", and a break before the second "·" is allowed).

## Goals

- At any curve count, and at the worst-case fixture's mana bar and Card types rows (counts up to 9,999 per type, a suffix of "9,999 proxy"), on a 320px to 360px viewport and in the 320px aside, no count is cut off or overflows its column, and the panel does not scroll sideways; with five-digit type counts the rows stay inside the list (the name may wrap).
- Each of the four limits has a ruling (decisions 1 to 4): all four are recommended as fixes, none as an accepted limit, and the narrower cases a fix does not reach are named, with their measured band (Error Scenarios).
- What the abbreviation hides from a sighted reader is stated, not implied: a curve column's exact count is in the chart's `aria-label` only (decision 1); the caption, the legend's totals, the types' counts and the zone heads stay exact.

## Non-Goals

- The 10% rule that hides a segment's label (spec 060 decision 4, spec 069 decision 9) and the segments' proportional widths, unless the maintainer takes option B of decision 2 at Gate A.
- Counts outside the panel (the zone heads, the Owned, Proxy and Total cells, the lists): they have room and stay exact.
- A real-phone-only claim: the 360px frame's 263px interior is a test frame (#318), but the 320px viewport's 238px interior is a real phone, so the fixes are measured at both.
- Any view of another page, any change to what the panel counts, to the export, to a query, a model other than the panel's figures, or to the tokens.
- A type's name staying on one line when its count and suffix have five digits or more at a 320px viewport: the rows stay inside the list and the name may wrap (AC-3.1b); counts of six digits or more in a Card types row are not specified.

## Decisions

Each limit of the issue, with the options, my recommendation (the first option) and the reason. Gate A rules on these.

### 1. The curve's count (limit 1): abbreviate it from 1,000

- **Fix, recommended: abbreviate.** The count above a column reads "1.4k" from 1,000 on ("999" stays "999"). Four characters at most, so it fits a 238px interior's 30.57px column (about 29px of text). The rule is uniform, not width-driven, because the server cannot know the width and a count that fits at 360px still overflows at 320px.
- **The trade-off:** a sighted reader loses the exact count of a column of 1,000 or more. It stays in the chart's `aria-label` (the whole column and its owned and proxy split), and the column's cards are in the zone tables; the legend shows the curve's totals, not a column's split. The curve is a shape, and "1.4k" is the shape's number.
- Alternatives: let the count shrink or wrap (a 12px font is already the smallest the design system sets, and a wrapped number above a bar reads as two numbers); overflow into the gap (two adjacent four-digit columns would touch, and the last column spills into the panel's padding); accept the limit (it is real on a 320px phone, and costs nothing to fix).

### 2. The mana bar's labels (limit 2): abbreviate the label's count the same way

- **Fix, recommended: abbreviate.** A segment's label reads "W 2.6k" from 1,000 on: six characters, about 43.5px (the label is 600 weight and the page loads the mono face at 400 only, so the browser draws a synthesized bold of about 7.26px a character), which fits the 46.4px of the narrowest five-equal-segment case (a 238px interior) on one line. Spec 060's Charts rule keeps its letter and count; the caption beside the bar keeps the exact count and the percentage ("White 2,591 · 20%"), and the bar's `aria-label` the exact count.
- **What this leaves (measured, 2026-11-11):** a segment narrower than its label. A six-character label needs about 45px, which is about 19.5% of a 232px bar (a 238px interior); a five-character one ("W 999") about 16.5%; a four-character one ("U 44") about 13.5%; so segments between 10% (the narrow rule's line) and those shares have no room for their label, at ordinary counts too (a 12% segment of "U 44" at a 320px viewport). The labels wrap onto two lines and are cut off at the bar's 30px (the "before" shots of a deck whose red segment is large show it). The fix for the issue's case, five segments of about equal four-digit counts, does not reach it.
- Alternatives:
  - **B, a narrow rule that follows the label (the reviewer's suggestion; a larger change):** the server marks a segment narrow when its share of the bar is below `(label width + 2px) ÷ 232px`, using the label's length, so the label hides whenever it cannot fit at the narrowest interior, and the caption (always complete) carries the count. It closes the whole band above and is Ruby only. It also changes spec 060 decision 4 (ruled by the maintainer on 2026-11-10 as "a segment under 10% drops the label") and what the page shows at ordinary counts: a 12% segment loses the label it has on a 360px phone, where it fits. **Gate A question:** recommend A, with the band recorded in `DeckShape.md` and offered as its own issue; take B instead if the maintainer wants the band closed here.
  - B's costs, for the maintainer: it replaces AC-2.3, adds 060 decision 4 and 069 decision 9 and AC-4.6 to the supersession lists and the index, drops the band's Error Scenarios row and widens Goal 1; and "Ruby only" means the model hard-codes a font measurement (about 7.26px a character for the synthesized bold, and the 232px bar), which drifts silently if the font, its weight or the page padding changes (spec 074), and it hides labels in the aside and on a 360px phone where they fit.
  - Hide the label when the count has four digits (the Charts rule wants a count on every segment); lower the narrow rule's 10% (the same ruling as B, blunter); accept (the 320px phone wraps the label onto two lines).
- Not changed under A: the 10% rule and the narrow class.

### 3. A type row's count (limit 3): the rows share their columns

- **Fix, recommended: a grid.** The list is a grid of three columns (name, count, proxy suffix) and each row takes the list's columns as its own (`subgrid`), so the count column is as wide as the widest count and the suffix column as wide as the widest suffix, whatever it is, and every row's count ends at the same x. The suffix cell keeps its 4.5rem minimum, so a list whose suffixes are short looks as before. The counts and the suffix stay exact ("1,234 proxy"). The name cell takes `min-width:0` and `overflow-wrap:anywhere`, so when a name, a count and a suffix together are wider than the row (five-digit counts at a 320px viewport) the name wraps inside its cell, even mid-word, and the row never runs past the list.
- Alternatives: widen the minimum to 6rem (it fixes "1,234 proxy" and fails at "12,345 proxy", and costs 24px of every row's name column on a phone); abbreviate the suffix ("1.2k proxy" is 10 characters, 72.0px, exactly the 4.5rem minimum, so it would also fix the alignment with no CSS; it is not recommended because a type's exact proxy count is shown nowhere else and there is room for it); accept.

### 4. The mana caption (limit 4): each colour is one unbreakable item

- **Fix, recommended: items.** The caption is a run of items, "Blue 44 · 73% ·" and the last "Red 16 · 27%", each unbreakable (`white-space:nowrap`), separated by one ordinary space. A line can break only between items, so no line begins with "·", a colour's name never parts from its count or percentage, and a line may end with a trailing "·" (typographically harmless, and what the page does today). The caption's text is unchanged, character for character, so the strings of specs 060 and 069 and of the examples that read it still hold; the figures' `caption` method keeps returning the whole string.
- Alternatives: a non-breaking space before every "·" (changes the string, which Nokogiri and the model examples compare exactly); a list of items with the dots drawn by CSS (the text the page reads changes, and a screen reader reads a caption of pseudo-elements unevenly); accept.

### 5. One abbreviation, written once, for the two places that need it

A count in a slot of fixed width, the curve's column and a mana segment, is abbreviated from 1,000; a count anywhere else is exact and delimited. The abbreviation is the figures object's (`MTG::DeckShape`), the extension's, so the deck's core files, which name no collectible, are untouched.

- **From 1,000:** under 10,000 it has one decimal with a trailing ".0" dropped ("1.4k", "2k"); from 10,000 it is whole ("12k", "123k"). Millions use "m" the same way ("1.2m", "12m"), billions "b". It rounds half up on integers, exactly (1,350 is "1.4k"; 1,349 is "1.3k"). A value whose rounding reaches 1,000 of its unit moves to the next unit (999,500 is "1m"; 999,499 stays "999k"), and one that rounds to 10.0 under the one-decimal rule is written whole (9,950 and 9,999 are "10k"), so no abbreviation is longer than four characters through "999m". It is not `ActiveSupport::NumberHelper.number_to_human`, which keeps two significant digits (123,456 would read "120k").
- **Below 1,000** the number is written as it is ("0", "123", "999").
- The `aria-label`s, the legend, the types' counts and suffixes, the caption and the zone heads are not abbreviated.

## Supersedes

| Document | What it says | What changes |
|---|---|---|
| [Spec 060](../060-deck-components/spec.md) AC-2.2 ("the count above the column reads owned plus proxy"), AC-2.6 ("a segment's label reads its letter and count") | the number is written in full | from 1,000 the visible number is abbreviated (decision 5); below 1,000, and in every `aria-label`, nothing changes |
| Spec 060 decision 2, AC-2.5, and `DeckShape.md` "Card types" ("the element has a minimum width of 4.5rem so the counts of every row line up") | a fixed minimum aligns the counts | the rows share the list's columns; the 4.5rem minimum stays as a floor (decision 3) |
| Spec 060 AC-2.4 and `DeckShape.md` "Width" (the known limit and its mention of #320) | the panel fits in 279px | it fits in 238px (a 320px viewport) and in 278px, at four-digit counts, except the mana-label band of decision 2 (option A); the limit sentence about the 6+ count is replaced by the measured interiors |
| [Spec 069](../069-deck-shape-panel/spec.md) decision 14 ("counts … use `number_with_delimiter`") and its Error Scenarios row "A four-digit count in the 6+ column in a 360px browser frame" | the curve's count and the segment's label are delimited in full; the overflow is a known limit | those two numbers are abbreviated from 1,000 (decision 5) and the limit is gone |
| Spec 069 `verification.md` "Findings" 1 to 4 | recorded, not fixed, for the maintainer | fixed (this spec's verification names each) |

Recorded in the specs index, in both directions. Specs 060 and 069 are frozen and are not edited.

Existing examples this changes (a grep, not memory; the command is repeated in `verification.md`): `git grep -n -i -E "c-curve__count|c-manabar__seg|c-manacap|c-types|\.caption\b|countRoom|1,357|2,591|4\.5rem" -- spec ':!.kamal/secrets'`. Hits that change: `spec/system/deck_shape_panel_spec.rb` (the AC-5.3 example's comment says "a CSS question raised with the maintainer, not decided here", and its fixture's 1,357 now reads "1.4k"), `spec/requests/deck_shape_panel_spec.rb` (the segments' texts "U 6" and the caption lines hold; a new example for the items), `spec/models/mtg/deck_shape_spec.rb` (new examples for the abbreviation and the items; the `caption` examples stay). Hits left alone: `spec/system/design_system_deck_components_spec.rb` (builds its own markup with delimited-free numbers and reads the types' alignment, which the grid keeps) and the previews' text.

## User Stories

### Story 1: The curve's counts fit their columns

**As a** collector with a very large deck on a phone
**I want** the number above each curve column to fit it
**So that** no number is cut off or runs into the next column

- [ ] **AC-1.1** Given the abbreviation When it is given 0, 999, 1,000, 1,049, 1,050, 1,350, 1,357, 9,949, 9,950, 9,999, 10,000, 12,345, 123,456, 999,499, 999,500, 1,250,000 and 12,000,000 Then it returns "0", "999", "1k", "1k", "1.1k", "1.4k", "1.4k", "9.9k", "10k", "10k", "10k", "12k", "123k", "999k", "1m", "1.3m" and "12m", and no result is longer than four characters.
- [ ] **AC-1.2** Given spec 069's system fixture (`spec/system/deck_shape_panel_spec.rb`: Worst at mana value 7, 123 owned; Gleemax, mana value 1,000,000, 1,234 proxy; Bolt 4 owned and five single cards at mana value 1; 20 lands) When the curve renders Then the 6+ column's count reads "1.4k", column 1 reads "9", the chart's `aria-label` reads "6+, 1,357 cards (123 owned, 1,234 proxy)" and the legend reads "Owned 132" and "Proxy 1,234".
- [ ] **AC-1.3** Given the same fixture in the open fold at a 320px viewport (interior 238px), a 345px viewport (a 360px frame; 263px), a 360px viewport (278px) and a 640px frame (a 545px container: the fold again), and in the aside at 1280px (286px), in both themes When each count's room in its column (the column's width less the count's `scrollWidth`) is read Then it is at least 0 for all seven columns, no text is cut off at its own box, no element is drawn past the panel's padding box's right edge and the panel does not scroll sideways. A variant that sets the 6+ count back to "1,357" fails at the 320px and 345px viewports (so the example can fail).

### Story 2: The mana bar's labels have room

**As a** collector with a deck of many symbols
**I want** each segment's label to sit inside its segment, on one line
**So that** the bar reads as a bar, not as crowded text

- [ ] **AC-2.1** Given a segment of 2,591 symbols When the bar renders Then its label reads "W 2.6k" (its letter, a space and the abbreviation), a segment of 44 reads "U 44", the caption reads "White 2,591 · 20% · …" and the bar's `aria-label` reads "white 2,591, …", all exact.
- [ ] **AC-2.2** Given the fixture's five segments of about 2,591 at the viewports and the aside of AC-1.3, in both themes When each label's text is measured with a `Range` Then it is on one line (its height is at most one line, 16px), its width is at most its segment's `clientWidth` (the content box, the divider's border excluded; the first segment has no divider) less 2px (a pixel a side), and no label overlaps another. A variant that writes the count in full fails at the 320px viewport.
- [ ] **AC-2.3** Given a segment under 10% When the bar renders Then it still carries `c-manabar__seg--narrow` and no visible label (spec 069 AC-4.6 unchanged).

### Story 3: The types' counts line up whatever the suffix

**As a** collector
**I want** every type's count to end at the same place
**So that** I can compare them down the list

- [ ] **AC-3.1** Given Card types rows "Creatures" 1,357 with "1,234 proxy", "Instants" 9,999 with "9,999 proxy", "Artifacts" 3 and "Lands" 20 with no suffix When the list renders at the viewports and the aside of AC-1.3 Then every row's count ends at the same x (within 0.5px), every suffix ends at the row's right edge, and no row's name, count or suffix is cut off (`scrollWidth` at most `clientWidth`) or runs past its row. A variant of the previous CSS (flex rows, a 4.5rem minimum) fails: the "Instants" and "Creatures" counts are about 7px left of the others'.
- [ ] **AC-3.1b** Given a row "Planeswalkers" 12,345 with "12,345 proxy" at a 320px viewport (the name, the count and the suffix need about 247px of the 238px interior) When the list renders Then no row runs past the list's right edge and the counts still end at one x; the name may wrap inside its cell, mid-word.
- [ ] **AC-3.2** Given Card types rows none of which has a proxy When the list renders Then the counts line up and each row has its empty suffix cell of at least 4.5rem as before (nothing moves for an ordinary deck).
- [ ] **AC-3.3** Given the same rows in the `design_system_deck_components_spec` markup (`c-types` with its three children per row) When it is measured Then it still passes: name at the row's left edge, suffix at the right edge, counts aligned.

### Story 4: The caption never breaks inside an item or leads with a dot

**As a** collector
**I want** each colour's count and percentage to stay together
**So that** the caption is not misread

- [ ] **AC-4.1** Given the figures of spec 069's fixture (red is 2,595: Bolt's `{R}` adds 4 to the 2,591 of the other four) When `caption` is read Then it returns the string the code builds today ("White 2,591 · 20% · Blue 2,591 · 20% · Black 2,591 · 20% · Red 2,595 · 20% · Green 2,591 · 20%"), and `caption_items` returns five strings, "White 2,591 · 20% ·", "Blue 2,591 · 20% ·", "Black 2,591 · 20% ·", "Red 2,595 · 20% ·" and "Green 2,591 · 20%"; a deck with one coloured symbol has one item with no trailing "·"; a deck with no coloured symbol has `caption_items` of `[]` and `caption` nil (as before).
- [ ] **AC-4.2** Given the rendered caption When its text is read Then it equals `caption` exactly (the items are separated by one space, so `have_text` and Nokogiri's `text` read the same string as before).
- [ ] **AC-4.3** Given the fixture's caption at the viewports and the aside of AC-1.3, in both themes When each item's text is measured with a `Range` Then every item is on one line (a single client rect), and no line of the caption begins with "·". A variant without the nowrap rule fails at the 320px viewport (an item splits). The no-leading-dot clause cannot fail on this fixture today (the measurement saw dots end lines only), so it is proved by the single-rect check (a dot sits at an item's end and an item doesn't split); the plan's first task looks for a width where the old CSS leads a line with "·" (spec 069's commander-wide shots show a break near one) and uses it if it finds one.

### Story 5: The documents

**As a** developer, or an agent, drawing the panel
**I want** the component document and the area doc to say what is shown and what is exact
**So that** the next count in a fixed slot follows the same rule

- [ ] **AC-5.1** `docs/design-system/components/DeckShape.md` states decisions 1 to 5: the abbreviation and where it applies (and that the legend, the types, the caption, the zone heads and the `aria-label`s are exact), the grid and the 4.5rem floor, the caption's items and that its text is unchanged, the markup example's caption in items, the "Width" paragraph rewritten with the measured interiors (238px, 263px, 278px, 286px), the 6+ known limit and its #320 mention removed, and the unfixed mana-label band (decision 2, option A) and the five-digit Card types rows recorded as limits, with their shares (about 13.5%, 16.5% and 19.5% of the bar for labels of four, five and six characters) and the issue that offers the band. (Verified by reading.)
- [ ] **AC-5.2** The three previews that draw the caption (`DeckShape.html`, `DeckPage.html`, `DeckPagePhone.html`) wrap each caption item in a `c-manacap__item`, so the previews match the markup, and `DeckShape.html`'s comment "313px wide, 279px inside" is corrected to the measured chain (the fold 312px wide, 278px inside). (Verified by reading, and by the previews' existing examples, if any, passing.)
- [ ] **AC-5.3** `docs/architecture/collection-and-lots.md` states the abbreviation in the panel's paragraph (which numbers are abbreviated, from 1,000), adds a Named constants row for the 1,000 threshold, and its Issues bullet no longer lists #320 as open and, under option A, names the follow-up issue for the mana-label band; `docs/specs/README.md` has this spec's row with 060 and 069 in "Supersedes" and 077 in their "Superseded by". (Verified by reading.)

### Story 6: Nothing else moves

**As a** maintainer
**I want** the change to be small and to touch only the panel
**So that** it merges cleanly beside the deck-page work of spec 074

- [ ] **AC-6.1** The branch's diff to `app/` is `app/models/mtg/deck_shape.rb`, `app/views/mtg/deck_shapes/_parts.html.erb` and `app/assets/stylesheets/collector/additions.css` only; the CSS change is inside the DeckShape blocks (the card types block and the mana bar block) and adds no colour, font family or spacing literal that the tokens could give (`spec/design_system_files_spec.rb` passes unchanged), and no other stylesheet changes. (Verified by the diff.)
- [ ] **AC-6.2** `spec/deck_core_spec.rb` is unchanged and passes (the deck core files name no collectible), the page's statement counts are unchanged (`spec/requests/query_counts_spec.rb` passes unchanged) and spec 069's AC-5.1 to AC-5.3 examples pass with their assertions unchanged (the AC-5.3 example's comment, which calls the 360px frame's overflow "a CSS question raised with the maintainer, not decided here", is updated in the same commit: a stale comment is a bug).

## Functional Requirements

- **FR-1.** `MTG::DeckShape` gains the abbreviation as the instance method `short_count(number)` (decision 5; AC-1.1's model examples and the partial call it) and `caption_items` (decision 4); `caption` and every method that builds an `aria-label` are unchanged. The partial `mtg/deck_shapes/_parts` writes the column count and the segment's label through the abbreviation and the caption through the items.
- **FR-2.** `additions.css` changes inside the DeckShape card types block (the list a grid of three columns, `minmax(0,1fr) auto auto`, with the column gap on the list; each row `grid-column:1/-1` on `subgrid` columns, its `min-height`, baseline alignment and borders as now; the count keeps `margin-left:auto` so it stays right-aligned in its column; the suffix cell keeps its 4.5rem minimum; the name cell `min-width:0; overflow-wrap:anywhere`) and the mana bar block (one rule, `.c-manacap__item { white-space:nowrap }`), each with a comment saying why, citing spec 077, and no value outside the tokens beyond the literals the blocks already use.
- **FR-3.** Examples first, each red before its fix: the abbreviation and the items in `spec/models/mtg/deck_shape_spec.rb`; the rendered markup in `spec/requests/deck_shape_panel_spec.rb`; the layout in `spec/system/deck_shape_panel_spec.rb` (the viewports and the aside, both themes), sizing each frame from the measured scrollbar as `open_phone_frame` does and comparing against `documentElement.clientWidth`, not `innerWidth` (lesson on measurement traps).
- **FR-4.** The documents of Story 5 and the screenshots of the non-functional requirements.

## Non-Functional Requirements

- **Compatibility:** no migration, no schema change, the export unchanged at version 4, upgrade-safe from the previous release.
- **Hosted-door cost per account (north star rule 4):** none; a few string operations per page view and a stylesheet.
- **Accessibility:** unchanged names and labels: the `aria-label`s keep the exact numbers, the abbreviated visible text is in `aria-hidden` columns and an `img`-role bar, so a screen reader reads the exact figures once; the caption stays a paragraph with the same text.
- **Performance:** the abbreviation is integer arithmetic on at most 12 numbers a copy (the panel renders twice); the statement counts are unchanged.
- **Visual change:** yes, only at counts of 1,000 or more and in the Card types list's alignment (none at ordinary counts). Before and after screenshots of the worst-case panel at 375px (a 360px viewport), 640px and 1280px, in both themes, in the pull request: "before" is the old rules injected as a `<style>` (`.claude/memory/pr-screenshots-workflow.md`), and the old abbreviation-free text is drawn by the same fixture with the figures' abbreviation stubbed to the delimited number.

## Error Scenarios

| Scenario | Behaviour |
|---|---|
| A count of exactly 1,000, or 999 | "1k" and "999" (AC-1.1) |
| A count that rounds up into the next unit (9,950, 999,500) | "10k" and "1m", never "10.0k" or "1000k" |
| A column or segment of 0 | "0" (a curve column; a segment of zero has no element) |
| A deck whose curve counts all fit (every count under 1,000) | Nothing changes: the numbers are written in full |
| A column of 1,000 or more in the aside, where the number would fit | Still abbreviated: the rule is one rule for every width; the exact count is in the chart's `aria-label` (decision 1's trade-off) |
| A type's count or suffix of 10,000 or more ("12,345 proxy") at a 320px viewport (a name such as "Planeswalkers", a five-digit count and a five-digit suffix need about 247px of the 238px interior) | The rows still share their columns, the counts line up and no row runs past the list; the name wraps inside its cell, even mid-word (AC-3.1b). Recorded in `DeckShape.md` |
| A mana segment between 10% and about 13.5% (a label of four characters, "U 44"), 16.5% (five) or 19.5% (six, "W 2.6k") of the bar, whose label does not fit at a 320px viewport | Not changed under decision 2's A: the label wraps and is cut off; the caption carries the count. Recorded in `DeckShape.md` as a limit with its band, and offered as its own issue (or taken here as B) |
| A caption with one colour | One item, no trailing "·" |
| A caption item wider than the panel (not possible at the counts above: the longest item is well under 200px) | It would overflow like any unbreakable word; AC-4.3 fails first |
| The browser lacks `subgrid` | Not reachable: `ApplicationController` allows modern browsers only (`allow_browser versions: :modern`: Safari 17.2, Chrome 120, Firefox 121 and later), and all have `subgrid` |

## Open Questions

None. The rulings of decisions 1 to 4 are recommendations for Gate A; the alternatives are written beside each.

## Notes for the plan

- Task 1 measures what the spec says it will: the AC-1.3, AC-2.2, AC-3.1 and AC-4.3 examples and the model examples are written red first; the band of mana segments whose label does not fit is measured in the same run and recorded in `DeckShape.md`.
- The interiors (238, 263, 278, 286px) are derived from the page's own chain (viewport, body margin, page padding, border, panel padding) and the examples assert the viewport, as `open_phone_frame` does. Spec 074 (#326, branch `074-deck-pages-phone-width`) may change the deck page's padding: if it merges first, re-measure the interiors and update the numbers here and in `DeckShape.md`.
- AC-2.2's room at a 320px viewport is thin (a 43.56px label in a 44.4px bound, 0.84px): the first green run confirms it on the Linux CI runner's Firefox as well as on the Mac, and if a runner's font metrics need more, the spec is updated through `sdd-spec-update` before the bound moves.
- Each geometry example measures both themes in one frame (set `data-theme`, wait about 0.6s, measure again) so the cost is one frame per width; theme cannot change layout, so the second measurement is a guard, not a second example.
- The frame sizes: a viewport of 320px needs a frame of 320 + the measured scrollbar (335px with the Mac's 15px, about 332px on the Linux runner), a 345px viewport a frame of 360px; size every frame from the measured scrollbar as `open_phone_frame` does, and assert the viewport. The aside is measured at a 1280px window (a 320px panel, 286px inside).
- Each system example needs its failing variant (the lesson `an-example-that-cannot-fail-proves-nothing`): inject the old rule (`.c-types li { display:flex }` and the old `.c-types__proxy`) or remove the nowrap rule with a `<style>` and expect the example to fail; say in the example's comment which it is.
- The caption's items are measured by `Range` client rects of each item's text (a single rect is one line); a line's first character is read from the character rects, as the throwaway measurement did.
- `app/assets/stylesheets/collector/additions.css` is shared with the other workers of this run: keep the edit inside the two DeckShape blocks and don't reorder or reformat anything else. `spec/design_system_files_spec.rb` counts the strings "spec 019", "spec 021" and "spec 023" across the whole file; "spec 077" in the comments is fine.
- `bin/rspec spec/system/design_system_deck_components_spec.rb` after the CSS edit (it builds its own `c-types` and `c-manabar` markup, and AC-3.3 keeps it green).
- Run `bin/yard doc` for the new public methods' comments (a summary, `@param` and `@return`, and the "why" of the abbreviation's rounding).

## Out of Scope (Future Considerations)

- Abbreviating counts elsewhere on the deck page (zone heads, table cells), which have room.
- A width-driven rule (container queries that choose an abbreviation or a label): the server-side rule is uniform and enough.
- The curve's blank band when it is empty (spec 069 Findings 5), a separate matter.
- Real-phone checks on a physical 320px device.

## Documents that change

- `app/models/mtg/deck_shape.rb`, `app/views/mtg/deck_shapes/_parts.html.erb`, `app/assets/stylesheets/collector/additions.css` (the card types block and the mana bar block); `spec/models/mtg/deck_shape_spec.rb`, `spec/requests/deck_shape_panel_spec.rb`, `spec/system/deck_shape_panel_spec.rb` (new and changed examples).
- `docs/design-system/components/DeckShape.md`; `docs/design-system/previews/DeckShape.html`, `DeckPage.html`, `DeckPagePhone.html` (the caption's items).
- `docs/architecture/collection-and-lots.md` (the panel's paragraph, a Named constants row, the Issues bullet, Sources and the Distillation log); `docs/specs/README.md` (this spec's row; 060's and 069's "Superseded by").
- No ADR: the rulings are this spec's decisions; no new area doc: the design system has none and the panel's rules are in `collection-and-lots.md`.
- Left as history, not edited: specs 060 and 069 and their `verification.md` files.
