# Feature 060: Design System: Deck Components and Previews

**Status:** Draft (every decision, 1 to 17, 23 and 24, ruled by the maintainer on 2026-11-10; spec review round 2 fixed; awaiting Gate A)
**Version:** 0.4.0
**Created:** 2026-11-10
**Last Updated:** 2026-11-10
**Depends on:** [spec 057](../057-deck-design-rules/spec.md) (the deck rules, the Charts rule, the Decks vocabulary, grouped pickers), [spec 058](../058-mtg-mana-value/spec.md) (the mana value the curve expects), both merged; [the decks and locations issue design](../../superpowers/specs/2026-11-09-decks-and-locations-issues-design.md) (decisions 4, 7, 9 to 13, 15 to 17)
**Branch:** `060-deck-components`
**Issue:** [#249](https://github.com/plainprogrammer/Collector/issues/249) (roadmap item 14b)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.4.0 | 2026-11-10 | Spec review round 2 (NEEDS REVISION; 0 blocking, 5 major, 6 minor, 2 nits) fixed: decision 25's widths redone from the real CSS (border-box `th` widths; Cost 10rem; the fixed layout from 640px of the table's container only, narrow tables keep the auto layout the maintainer ruled in decision 9, with the pips allowed to wrap), moved into FR-3 and limited to the zone tables; decision 24 ruled A and its CSS and the `AppHeader.md` exception named; the quantity errors split into a per-lot and a group sentence; the panel-less deck page (issue design [7]) gets a rule and AC-3.12; the panel's DOM order and ids; Supersedes and the index row; AC-7.7 in the Verification list; two nits |
| 0.3.0 | 2026-11-10 | The maintainer ruled decisions 1 to 17 and 23 (2026-11-10): all as recommended except 13 (New deck is a button to its own page) and 15 (a quantity field on every lot), and 14 as recommended for the single-option case. Decision 24 (New deck on a phone) is a follow-up, drafted as recommended and still with the maintainer. Markers removed; stories, FRs and the files table follow decisions 13 and 15 (a New deck page, with its own preview; quantity fields); the plan inherits the shared fixed column layout the coordinator asked for (decision 25) |
| 0.2.0 | 2026-11-10 | Spec review round 1 (NEEDS REVISION; 0 blocking, 7 major, 10 minor, 6 nits) fixed: the stacked panel's mechanism (two renderings, decision 7); names wrap in a narrow table container, with worst-case rows in the ACs; the card page's Proxy column keeps spec 057's plain count; the shell's rules vs the Magic sample (decision 21); the panel's widths (320px, 313px stacked); empty and refused states, with decision 23 for their wording; the pick list's wrap and focus ring; AC-1.3, AC-4.4, AC-7.2, AC-7.5, AC-7.7 and the verification lists; three Supersedes entries |
| 0.1.0 | 2026-11-10 | First draft, from issue #249 and its comment (spec 057's leftovers), the issue design, spec 057 and its verification record, and mock-ups drawn with the real Collector CSS (the 2026-11-09 mock-ups are not in the repository, so deck page option B and curve option B were redrawn from the issue text). Seventeen decisions are open, each sent to the coordinator as a separate question with options and a recommendation; the recommended option is written below as the draft text |

## Problem Statement

Decks are the next theme of 1.0, and the deck issues ([#49](https://github.com/plainprogrammer/Collector/issues/49) first, then [#253](https://github.com/plainprogrammer/Collector/issues/253), [#254](https://github.com/plainprogrammer/Collector/issues/254), [#255](https://github.com/plainprogrammer/Collector/issues/255), [#256](https://github.com/plainprogrammer/Collector/issues/256), [#257](https://github.com/plainprogrammer/Collector/issues/257)) each build a view. Spec 057 wrote the rules those views follow (the Decks words, the Charts rule, grouped pickers, navigation), but the components themselves do not exist yet: there is no deck shape panel (a mana curve, counts by type, a coloured-mana bar), no way to mark a proxy without colour, no deck page layout, no list of decks, and no page for adding a card to a deck or for replacing a proxy with a copy. An agent building #49 would invent them, and the first invention would become the pattern.

This spec draws them, with the real CSS, before any view is built: six component documents, the CSS they need in `additions.css`, and a preview of each at desktop and phone width in both themes. It changes documents, one stylesheet and the previews. It changes no view, helper, model, route, query, export or migration.

> **Terms.** A *zone* is a named part of a deck (Main, Sideboard, Considering). A *proxy* is a stand-in for a card the collector does not own, recorded against a deck zone. The *shape panel* is `DeckShape`: the curve, the card types and the coloured mana symbols of a deck's Main (and Commander) zone. The *page container* is `.c-page`, whose width the page's own layout answers to (`@container page`). The full vocabulary is the README's Decks section (spec 057 FR-3).

## Goals

- Six components are documented in `docs/design-system/components/` with the markup an agent copies and the rules it must keep: `DeckShape`, `ProxyTag`, `DeckPage`, `DecksIndex`, `AddToDeck`, `UseMyCopy`.
- The CSS they need exists in `collector/additions.css`, in tokens and `c-*` classes only, each rule under its own `(spec 060 …)` heading, and is proved in a browser.
- Each component is previewed in HTML at 1280px and 390px in light and dark, and listed in the README's Components section.
- The leftovers of spec 057 on the issue are done: `c-split` is out of the README's Components list, the preview icons share the app's stroke (decision 16), and the stale indentation in the card page previews is tidied.

## Non-Goals

- Any view, helper, route, model, query, export or migration: the first deck view is [#49](https://github.com/plainprogrammer/Collector/issues/49). `DeckShape` names the data it expects (`mtg_cards.mana_value`, spec 058) and builds nothing that reads it.
- How "6+" and half mana values fall into the seven curve columns, which faces of a double-faced card count and the order of the card types: the shape panel's issue ([#256](https://github.com/plainprogrammer/Collector/issues/256), the issue design's "Left to each issue's spec"); and hybrid and Phyrexian symbols in the mana bar (the issue design's decision 13, "my call; the spec may refine"), also #256's. `DeckShape` draws the seven columns, the type counts and the symbol counts it is given.
- What a lot count takes from when the collector asks for fewer copies than are free (`AddToDeck`), what changing or removing a proxy does, and the proxy's own pages: [#254](https://github.com/plainprogrammer/Collector/issues/254), [#255](https://github.com/plainprogrammer/Collector/issues/255), [#257](https://github.com/plainprogrammer/Collector/issues/257). This spec draws where those actions sit and the two replace actions' names.
- Format rules beyond the per-card legality marker (deck size, copy limits): the 2.0 milestone.
- A token change (`tokens.json`, `tokens.css`).
- A new ADR (decision 18).

## Decisions

The maintainer ruled on decisions 1 to 17 and 23 on 2026-11-10 from the mock-ups drawn with the real CSS (the screenshots are in the questions; the final ones go in the pull request). Decisions 18 to 22 and 25 are my calls, for Gate A to confirm; decision 24 is a follow-up question still open, drafted as recommended.

1. **The hatch for proxies in the curve** (ruled, option A, 2026-11-10). A diagonal 45° hatch of `line-strong` lines, 1.5px wide every 5px, on `surface-raised`, with a 1px `ink-muted` outline, stacked on top of the solid `ink-muted` owned part (issue design decision 11). Alternatives drawn: a denser diagonal (1px/3px), a cross-hatch, dots.
2. **Card types: one count and a muted proxy suffix** (ruled, option A, 2026-11-10). Each type is a row: its name, its count (owned plus proxy, in `data` mono), and, when it has proxies, a muted "N proxy". Alternative drawn: two columns, Owned and Proxy.
3. **Mana bar caption carries the counts** (ruled, option B, 2026-11-10). "Blue 44 · 73% · Red 16 · 27%": the colour, its symbol count and its percentage, so a segment too narrow for its label still has its count (the Charts rule). Alternative: percentages only ("Blue 73% · Red 27%", the issue design's wording).
4. **Mana bar rules** (ruled, all three as proposed, 2026-11-10). Segments always in W U B R G order; a segment under 10% of the symbols drops the label inside it (the server sets `c-manabar__seg--narrow`; no JavaScript) and the caption carries it; only W, U, B, R and G are drawn, never generic or colourless symbols.
5. **ProxyTag** (ruled, option A, 2026-11-10). A 20px tag, `radius-sm`, a 1px **dashed** `ink-muted` border, text `ink`, "Proxy" in sans 600 and the count in mono: "Proxy 2". It is the same tag in the Proxy column, on the phone's line under a card's name and in the Decks list. It reads without colour: the shape and the word carry it. Alternatives drawn: the tag in mono with a `line-strong` border; the number alone inside the dashed box in the Proxy column.
6. **The panel stacks above the zones below 992px of the page container** (ruled, option C, 2026-11-10). Measured on the real CSS: with the issue design's 640px the two columns start at a 719px window with a 288px zone column, and a zone table only gets its wide layout (Owned and Proxy columns, which `CollectionTable`'s pattern shows from 640px of its own container) from a window of about 1071px, so between them a phone-layout table sits beside a 320px panel and the zone's counts are cut. 992px is the table's 640px, the panel's 320px and the 32px gap (`space-8`). This replaces the 640px that the issue design marked as its author's call (decision 10); the same decision's panel position (sticky right column) stands. Alternatives: 640px as the issue design says, 900px.
7. **A stacked panel on a phone is a closed `details` above the zones** (ruled, option B, 2026-11-10). When the panel stacks it is about 640px tall, so a collector on a phone would scroll about 800px to the first card. Below 640px of the page container the panel sits above the zones as a native `<details>` (works without JavaScript, as the design system's menus do), closed, its summary "Deck shape" with "Main · 60 cards · average mana value 2.3" and Show or Hide. From 640px to the breakpoint the stacked panel is open and has no summary. **Mechanism:** one server rendering cannot be both a closed `details` and an open panel (a closed `details` hides its content whatever the CSS), and relying on `::details-content` would put a browser floor under the page, so the page renders the panel twice: once in the `aside` (shown from 640px) and once in the `details` (shown below 640px). Each hides the other with `display:none`, so assistive technology and the tab order meet only one; the panel's root has no `id`, and its `aria-labelledby` title ids are unique per copy (the view generates them). The cost is a second copy of a small panel (about 3 KB). Alternatives: above and open (the issue design), below the zones.
8. **The legality marker shows exceptions only** (ruled, option A, 2026-11-10). A card that is not legal in the deck's format (Banned, Restricted, Not legal) gets the card page's `c-legal c-legal--no` marker, a cross and the word, after its name; a legal card has no marker, and a format with no rules has none at all. Alternative: a Legality column with Legal on every row.
9. **Phone columns of a zone table** (ruled, option A, 2026-11-10). Below 640px of the table's container: Card (name, then `set · number`, the Proxy tag and any legality marker on the line under it), Cost, Total (and the row's menu, decision 17). Owned and Proxy fold into the tag and the Total. Alternative: Card and Total only, with the cost on the line under the name.
10. **The deck page's heads** (ruled, option A, 2026-11-10). The page head is `c-item__head`'s pattern: the deck's name, a muted line "Modern · 69 cards · 58 owned · 11 proxy", the actions "Edit deck" (secondary) and a "…" `Menu` ("Change format", then "Remove deck", danger, last). A zone's head is `c-section__head`: the zone's name, "60 cards · 52 owned · 8 proxy" and "Add a proxy" (ghost, small, with a plus) at the end; below 640px the counts take their own line (a cut count is information lost). An empty zone says "No cards in Sideboard yet." Alternative: no "Edit deck" button (rename and change format only in the menu).
11. **DecksIndex is a table** (ruled, option A, 2026-11-10). A `c-table` in `.c-collection`: Deck (the name as `TableItemLink`), Format, Cards, Owned, Proxy (the tag, or a muted dash). Below 640px Deck folds the format, the owned count and the proxy tag into its line and Cards stays. Alternative: `c-list` rows like Locations.
12. **"Cards" counts every zone** (ruled, option A, 2026-11-10). In the Decks list and the deck page's head "cards" is owned plus proxy in every zone, Considering included (copies in Considering are in the deck, README Decks section), so owned and proxy always add up to cards. The shape panel and each zone's head name their own zone. Alternative: Main and Commander only.
13. **New deck is a button to its own page** (ruled, option B, 2026-11-10; my recommendation was the inline form). The Decks page head has a primary "New deck" button (a plus and the words); it opens a page, a `c-form` under `c-appbar--detail`: "New deck" as the heading, Name, Format (a native select, hint "The format sets the deck's zones."), "Create deck" (primary) and "Cancel" back to the list. The list stays first on the Decks page. How the button is reached on a phone is decision 24. Alternative drawn: the Locations page's inline form above the list.
14. **AddToDeck preselects the only option** (ruled, option B for the single-option case, 2026-11-10). The page is a `ChoicePage` variant: "Add Lightning Bolt to a deck"; "Deck and zone", one native select whose options are "Deck › Zone" under a "Decks" group (spec 057 decision 2's shape, with no "Places" group because only zones can be chosen); "How many" (a number field, 1); "What to use": "My copies (3 free: 2 in Blue binder, 1 in Red box)", shown only when copies are free, and "A proxy of 2X2 · 117 foil". With two options nothing is chosen at first and the page refuses a submission without a choice; with one (no copy is free) it is already chosen (the maintainer ruled B for the single-option case only).
15. **UseMyCopy: a quantity field on every lot** (ruled, option B, 2026-11-10; my recommendation was one lot and a How many). "Use my copy of Lightning Bolt", a line naming the proxy row (deck › zone, printing, finish, the proxy count); the free copies as lots grouped "This printing" then "Other printings", each lot a row with its own number field (0 at first, at most the lot's free copies) so copies from several lots can be used at once; "Use these copies" and "Cancel". The maintainer asked that the rows be tidy at 390px and the fields hard to mis-tap on a phone: each row is a bordered `surface-raised` block with its label first (the lot's `set · number`, finish, condition and place, wrapping, and "×N free"), the field below the label at least 44px high and 6rem wide with `space-3` between rows, and every field named for its lot by its `label`. The sum must be at least 1 and at most the row's proxies (the server decides; a refusal is decision 23). Alternative drawn: one lot as a radio and a How many.
16. **Preview icons use the app's stroke** (ruled, option A, 2026-11-10). The app draws every icon at stroke 1.5 (its eleven icon partials) and the README's Iconography says 1.5; the previews draw 99 icons at 2 and 21 at 2.5, and the phone tab bar's Collection icon is already 1.5. Every icon in every preview is set to 1.5, and the new previews draw at 1.5. Alternatives: only the new previews and the tab bars and headers of the existing ones; leave the existing previews.
17. **A zone row's actions are a menu cell** (ruled, option A, 2026-11-10). The issue design's "a proxy row offers Use my copy and Add a new copy" needs a place. The last cell of a zone row is `TableActions` (a "…" `Menu` whose trigger is named for the row): a row with proxies lists "Use my copy", "Add a new copy", "Change proxy count", then "Remove proxy" (danger, last, to a confirm page); a row with only owned copies lists "Move copies". This spec documents the cell and names the two replace items; the rest of the items are #254's and #257's. Alternatives: an inline "Use my copy" button on proxy rows; nothing drawn.
18. **No ADR (my call).** The design system is the project's own, in code (spec 057 decision 12); a component, a rule and a breakpoint are recorded in its documents and here, and none has an alternative with a cost beyond the page.
19. **Phone previews follow the existing convention (my call).** A screen has `Name.html` and `NamePhone.html` (`ItemPage` and `ItemPagePhone`); the shell and the page container adapt by themselves, so the two hold the same markup and the phone one is opened in a 390px frame. The new screens (`DeckPage`, `DecksIndex`, the New deck page, `AddToDeck`, `UseMyCopy`) get both; `DeckShape` and `ProxyTag`, parts and not screens, get one preview each that shows the part at both widths side by side. One document per component covers both widths (as `Locations.md` does); the existing `ItemPagePhone.md` and `CollectionPagePhone.md` document a phone-only chrome the new screens don't have.
20. **A chart's numbers are custom properties on its elements (my call).** The curve's bar heights and the mana bar's segment shares come from the data, so each element carries them as unitless custom properties in a `style` attribute (`--owned`, `--proxy`, `--max`, `--n`), and the CSS turns them into lengths. A value is a number, never a colour, so no token is bypassed. No page except the scanner's sends a Content-Security-Policy, and that one allows inline styles.
21. **`DeckShape` is MTG-specific; the page shell is not (my call).** `DeckPage` is the collectible-agnostic shell: its rules and vocabulary name no format and no game, and the shape panel, the Cost column and the legality marker are "the extension's contribution" (issue design). The documents' samples are a Magic deck, said so in a line (as `ItemPage.md` says "Shown here for a Magic: The Gathering card"), and `DeckShape.md` is Magic-specific.
22. **Each new block of CSS has its own heading (my call).** `spec/design_system_files_spec.rb` finds a block by its heading comment and counts the rules up to the next heading; a block without a heading is counted in the one above. The blocks, each headed `(spec 060 …)`: ProxyTag; DeckShape (panel, curve, types, mana bar); DeckPage (layout, zone groups, empty zone, stacked panel); DecksIndex; the pick list of AddToDeck and UseMyCopy.
23. **Empty and refused states** (ruled, option A, 2026-11-10). Four states no mock-up had drawn the sentences of: no deck when AddToDeck opens: "You have no decks yet. Add a deck first." (a link "New deck" to the New deck page, no form); no free copy when UseMyCopy opens: "You have no free copy of Lightning Bolt to use." (a link back to the deck, no form); a refused quantity: "Enter a number from 1 to N." (N the limit the server computes) as a `c-field__error`; a refused deck name: the Locations page's own sentences, "Give the location a name." and "You already have a location called “<name>”." (spec 029 AC-1.6 and AC-1.9: a deck is a location, and decks and places share one namespace, so the words stay true).
24. **New deck on a phone** (ruled, option A, 2026-11-10). The header's plus is "Add items" on every page (`layouts/_appbar.html.erb`), and the export hides the page head's actions below 640px, so a phone has no New deck button. The Decks page keeps the page head's "New deck" visible on a phone: one rule in the DecksIndex block shows `c-pagehead__actions` on that page below 640px (the head wraps it beside the title), and `AppHeader.md`'s "the page head's own buttons hide" gains the exception. The header plus is unchanged (Add items everywhere). Alternative: the header plus links to New deck on the Decks page only.
25. **Zone tables share one column layout (the coordinator's review of the shots; my call for the widths).** From 640px of the table's container every zone table uses `table-layout:fixed` with set widths on its `th` (`box-sizing:border-box`, so a width is the column's whole width, padding included): Cost 10rem, Owned 5rem, Proxy 7rem, Total 5rem, menu 4rem; the Card column takes the rest, so the columns sit at the same x in Main, Sideboard and Considering. Measured from the real CSS: a six-symbol cost is 6 × 20px + 5 × 2px = 130px and a cell's padding is `space-3` a side, so Cost needs 154px and has 160px; the Proxy tag (about 66px) fits 7rem; at a 640px container the fixed columns take 496px and Card keeps 144px, where a name wraps. Below 640px of the table's container the layout is the auto layout of decision 9 (Card, Cost, Total, menu): zones are stacked there, a fixed Cost width would starve the Card cell (a 313px phone container less 152px of Cost and 56px each of Total and menu leaves 49px), and the Cost cell lets its pips wrap (`flex-wrap:wrap` on `c-cost` inside the zone table) rather than widen the table. The Decks table is not part of this rule: its columns size themselves. The existing `.c-table td.c-table__actions { width:1% }` stays for other tables; a zone table's menu column takes the `th` width.

## Users and Context

**Primary users:** the agents and the maintainer who build the deck views (#49, #253 to #257), reading the design system before writing a view; secondarily the collector, who meets these components as the pages the views produce.
**Usage context:** `collector-design-system` tells every agent to read `docs/design-system/README.md`, the component's doc and the preview before writing UI. These six documents and previews are where the deck components are written.
**User mental model:** a deck is a place with parts; a proxy is a card you are borrowing the idea of, marked so it can't be mistaken for one you own; the shape panel answers "what does this deck do" from the catalog alone.

## User Stories

### Story 1: ProxyTag

**As an** agent marking a proxy in a table or a list
**I want** one tag that reads without colour
**So that** a proxy is never mistaken for an owned card, and I don't invent a second look.

**Acceptance criteria:**

- [ ] **AC-1.1** Given `ProxyTag.md` When it is read Then it states the markup (`c-proxy`, the word "Proxy" and the count), the 20px height, the dashed `ink-muted` border, that it reads without colour, where it is used (the Proxy column, the phone's line under a card's name, the Decks list's Proxy cell and phone line), that a row with no proxies shows a muted dash and no tag, and that a proxy never counts as owned
- [ ] **AC-1.2** Given a `c-proxy` in the light and in the dark theme When its style is read Then its border style is dashed with the `ink-muted` token as its colour, its text is `ink`, its height is 20px, and it has `radius-sm` corners
- [ ] **AC-1.3** Given a `c-proxy` When its text and border are read Then its text contains the word "Proxy" and the number, so it reads without colour

### Story 2: DeckShape

**As an** agent building the deck page's panel (#256)
**I want** the curve, the types and the mana bar drawn and documented
**So that** I fill them with data and don't draw them.

**Acceptance criteria:**

- [ ] **AC-2.1** Given `DeckShape.md` When it is read Then it states the panel's markup and its three parts in order (Mana curve, Card types, Mana symbols), what each expects as data (seven columns of owned and proxy counts; types with owned and proxy counts; symbol counts for W, U, B, R, G; the average mana value; the scope line), that lands are left out of the curve, that the figures come from the deck's Main (and Commander) zone, that the mana value is `mtg_cards.mana_value` (spec 058) and this spec builds nothing that reads it, that a zero part is left out of the markup, the `role="img"` and `aria-label` of each chart and what the label reads, and that no part uses `brand` or a status colour
- [ ] **AC-2.2** Given a curve whose columns hold owned and proxy counts and a largest column of N When it is rendered in a panel Then each column's owned part is 96px × owned ÷ N high and its proxy part 96px × proxy ÷ N (borders inside the height, `box-sizing:border-box`; within 1px), the proxy part sits on top of the owned part, the count above the column reads owned plus proxy, and the seven mana-value labels sit below a 1px `line-strong` baseline
- [ ] **AC-2.3** Given the curve in the light and in the dark theme When its fills are read Then the owned part's background is the `ink-muted` token, the proxy part's background image is a gradient of the `line-strong` and `surface-raised` tokens with a 1px `ink-muted` border, and neither uses `brand` or a status colour (the tokens' contrast is guarded by spec 057 AC-2.3)
- [ ] **AC-2.4** Given the panel at 320px wide (side by side) and at 313px wide (stacked in a 360px frame with the classic scrollbar: 360 − 15 − 32; 279px inside its border and padding) When it is rendered Then the seven columns, their counts, the legend and the types fit with no horizontal overflow, and no count is clipped
- [ ] **AC-2.5** Given the card types list When it is rendered Then each row has its name at the start and its count at the end in `data` mono, a type with proxies shows a muted "N proxy" and a type without shows none, and rows are divided by `line` (decision 2)
- [ ] **AC-2.6** Given a mana bar of segments of counts c1…cn When it is rendered Then each segment's width is proportional to its count (within 1px), consecutive segments are divided by a 1px `line-strong` border, the bar has a 1px `line-strong` outline and `radius-sm` corners, each segment's fill is its `mana-*` token with its `on-mana-*` text in both themes (the same fills in both), a segment's label reads its letter and count ("U 44"), and a segment marked narrow hides its label (decision 4)
- [ ] **AC-2.7** Given a five-colour deck whose white segment is under 10% When the bar and its caption are read Then the white segment shows no label, and the caption carries the colour, its count and its percentage for every colour (decision 3)
- [ ] **AC-2.8** Given the README's Charts rule and `ManaCost.md` When they are read Then each points to `DeckShape` as where the rule is drawn, and the Charts rule's "hatched `line-strong` fill" says which hatch (decision 1)

### Story 3: DeckPage

**As an** agent building the deck page (#253, #254)
**I want** the layout, the zone tables and the shape panel's place written down and drawn
**So that** the page is the same at every width and in every deck.

**Acceptance criteria:**

- [ ] **AC-3.1** Given `DeckPage.md` When it is read Then it states the page's markup (head, zones in the main column, the shape panel as an `aside`), the zone table's columns and their order (Card, Cost, Owned, Proxy, Total and the row menu), the group rows (the extension supplies the groups: Magic's are its top-level card types), the legality marker (decision 8), the zone head and the page head (decision 10), the empty zone, that the shell's rules name no format and no game (its sample is a Magic deck, said so) and that the panel, the Cost column and the legality marker are the extension's contribution (decision 21), and what each width does
- [ ] **AC-3.2** Given a deck page in a page container of 992px or wider When it is rendered Then the zones and the panel are two columns (the panel 320px, a `space-8` gap), the panel is `position: sticky` with its top at the header's 56px plus `space-6`, and the zones are the column on its left
- [ ] **AC-3.3** Given the same page in a container of 991px or narrower When it is rendered Then the panel is above the zones in one column, is not sticky, and (from 640px to 991px) is open and as wide as the zones, with no summary (decision 6)
- [ ] **AC-3.4** Given the same page in a container narrower than 640px (a 390px phone) When it is rendered Then the `aside` copy of the panel is not displayed and the `details` copy is: closed, above the zones, its summary reading "Deck shape" with its facts, at least 44px high, opening and closing from the keyboard (Enter or Space), and the page has no horizontal overflow; from 640px the `details` copy is not displayed and the `aside` copy is (decision 7)
- [ ] **AC-3.5** Given a zone table of three type groups When it is rendered in a container of 640px or wider Then the columns are Card, Cost, Owned, Proxy, Total and the menu; each group has a full-width row with the type's name and its count on `surface-sunken` that does not stick; a row with proxies shows the Proxy tag in the Proxy column and a row without shows a muted dash; the Owned, Proxy and Total cells are right-aligned mono
- [ ] **AC-3.6** Given the same table in a container narrower than 640px When it is rendered Then Owned and Proxy are hidden, the Card cell's line under the name shows `set · number` and the Proxy tag of a row that has proxies, Cost and Total stay, and the table has no horizontal overflow at 360px with a worst-case row: a 60-character name with no space and a six-symbol cost, and the Cost cell's scroll width is at most its client width (decision 9)
- [ ] **AC-3.7** Given a zone's head in a container narrower than 640px When it is rendered Then the name and "Add a proxy" share the first line and the counts are on their own line below, uncut (the example reads the counts' scroll width against its client width); from 640px the head is one line
- [ ] **AC-3.8** Given a card that is not legal in the deck's format When its row is rendered Then the marker (a cross and the word) follows the name, and a legal card's row has no marker (decision 8)
- [ ] **AC-3.9** Given an empty zone When it is rendered Then it shows the head with "0 cards · 0 owned · 0 proxy", "Add a proxy", and the sentence in a `surface-sunken` block, with no table
- [ ] **AC-3.10** Given a row's menu When it is read Then it is `TableActions` (a trigger named for the row, "Actions for <card> <set · number>", since a zone can hold two printings of one card), a row with proxies lists "Use my copy" and "Add a new copy" first, and the destructive item is last after a separator (decision 17)
- [ ] **AC-3.11** Given a deck page with three zone tables of different content When it is rendered in a container of 640px or wider Then the Cost, Owned, Proxy, Total and menu columns have the same left edge and width in every zone table (decision 25), and from the narrow container the Cost, Total and menu columns do
- [ ] **AC-3.12** Given a deck page with no shape panel When it is rendered in a container of 992px or wider Then the zones keep the first column's width and the second column is empty, and below 992px the zones are one column with no panel and no `details`

### Story 4: DecksIndex

**As an** agent building the Decks page (#49)
**I want** the list of decks and the page that adds one drawn
**So that** the page is built from a component.

**Acceptance criteria:**

- [ ] **AC-4.1** Given `DecksIndex.md` When it is read Then it states the Decks page's markup (the page head with its count and the primary "New deck" button, then the table), the columns, what "Cards" counts (decision 12), the Proxy cell, the phone fold, the empty state ("No decks yet. Add a deck to start building one."), that the Decks page lists decks only and the Locations page places only (spec 057 decision 11), the New deck page (heading, Name, a native Format select with its hint, Create deck and Cancel, `c-appbar--detail`) and its refusals, which use spec 029's own sentences (`Location::MESSAGES`, `Location::FULL`: blank, control character, too long, taken, and the 500 limit) (decisions 11, 13, 23), and how a phone reaches New deck (decision 24)
- [ ] **AC-4.2** Given a Decks table of decks with and without proxies in a container 640px or wider When it is rendered Then the columns are Deck, Format, Cards, Owned and Proxy, Cards, Owned and Proxy are right-aligned mono, a deck with proxies shows the tag and a deck without shows a muted dash
- [ ] **AC-4.3** Given the same table in a container narrower than 640px When it is rendered Then Format, Owned and Proxy are hidden, the line under the deck's name reads the format, the owned count and the Proxy tag, Cards stays, and the table has no horizontal overflow at 360px with a 60-character deck name with no space
- [ ] **AC-4.4** Given the Decks page head When it is rendered at 1280px and in a 360px frame Then "New deck" is a primary `c-btn` at both widths (decision 24), at least 44px high on a coarse pointer, and the head has no horizontal overflow
- [ ] **AC-4.5** Given the New deck page When it is rendered at 1280px Then its form is no wider than 420px (`c-form`), and in a 360px frame its fields are stacked and the page has no horizontal overflow

### Story 5: AddToDeck

**As an** agent building "Add to deck" on the card page (#255)
**I want** the page drawn
**So that** it is a `ChoicePage` with known fields.

**Acceptance criteria:**

- [ ] **AC-5.1** Given `AddToDeck.md` When it is read Then it states the markup (a `ChoicePage` variant: the heading, a `c-form` of the Deck and zone select, How many, a `c-choices` fieldset "What to use", Add to deck and Cancel), that the select's options are "Deck › Zone" under a Decks group with no Places group, that "My copies" shows only when copies are free and its sentence's shape ("3 free: 2 in Blue binder, 1 in Red box"), that the proxy option names the shown printing ("A proxy of 2X2 · 117 foil", `SET · number` in mono), that with two options nothing is chosen and the page refuses a submission without a choice, with one it is chosen (decision 14), what #255 decides (which lots a count takes), and where Cancel returns to (the card page)
- [ ] **AC-5.2** Given the page in a 360px frame When it is rendered with a deck name of 60 characters in the select and a place name of 60 characters with no space in the "My copies" option Then it has no horizontal overflow, the select cuts its text without widening the form (spec 040 AC-7.1's rule), and the option's text wraps
- [ ] **AC-5.3** Given the page's radios When one has keyboard focus Then its row shows the 2px `focus` ring

### Story 6: UseMyCopy

**As an** agent building "Use my copy" (#257)
**I want** the page drawn
**So that** the choice of a free copy is a component.

**Acceptance criteria:**

- [ ] **AC-6.1** Given `UseMyCopy.md` When it is read Then it states the markup (heading, the proxy row's line, the two groups of lot rows each with its quantity field, Use these copies and Cancel), what a lot row reads (`set · number`, finish, condition, place, "×N free") and that its field is named by that text, that "This printing" holds the proxy's own printing and finish and "Other printings" the rest, that every field is 0 at first (nothing chosen), that the sum must be from 1 to the row's proxies and a replacement lowers the proxy count by the copies used, that a group with no lot is left out, and the empty state when no copy is free (a sentence and a link back, no form) (decisions 15, 23)
- [ ] **AC-6.2** Given the lot rows in a 360px frame When they are rendered Then each row is a bordered block with its label above its field, the field is at least 44px high and 6rem wide, rows are `space-3` apart, a 60-character place name with no space breaks inside the word, and the page has no horizontal overflow
- [ ] **AC-6.3** Given a lot row's field When it has keyboard focus Then the field shows the 2px `focus` ring on its `c-input` wrapper, and a click on the row's label focuses the field
- [ ] **AC-6.4** Given a lot whose free count is N When its field is read Then its `max` is N and its `min` is 0, and its accessible name contains the lot's `set · number`, finish, condition and place

### Story 7: Documents, previews and leftovers

**As an** agent or the maintainer
**I want** the components listed, previewed and consistent with the app
**So that** I find them, match them and trust them.

**Acceptance criteria:**

- [ ] **AC-7.1** Given the README's Components section When it is read Then it lists `DeckShape`, `ProxyTag`, `DeckPage`, `DecksIndex`, `AddToDeck` and `UseMyCopy` among the current set and the full screens, has an "App additions (spec 060, in `collector/additions.css`)" line naming the new classes and their documents, and no longer lists `c-split` among the card-page parts
- [ ] **AC-7.2** Given the twelve previews (`DeckShape`, `ProxyTag`, `DeckPage`, `DeckPagePhone`, `DecksIndex`, `DecksIndexPhone`, `NewDeck`, `NewDeckPhone`, `AddToDeck`, `AddToDeckPhone`, `UseMyCopy`, `UseMyCopyPhone`) When their `<link>` tags are read Then each links `preview-fonts.css`, `tokens.css`, `components.css` and `additions.css` in that order, and each shows the same markup its document shows
- [ ] **AC-7.3** Given each preview in headless Firefox at 1280px (and at a 390px frame for the Phone ones) in the light and in the dark theme When it is opened Then it renders with no console error and no horizontal overflow, and the screenshots are recorded in `verification.md` and the pull request
- [ ] **AC-7.4** Given `ItemPage.html` and `ItemPagePhone.html` When they are read Then the In decks and Format legality sections have no leftover indentation of the removed `c-split` wrapper (the two previews stay identical)
- [ ] **AC-7.5** Given the previews When their icons are read Then every `stroke-width` attribute is 1.5, as in the app (decision 16; filled icons have none)
- [ ] **AC-7.6** Given `ChoicePage.md`, `ManaCost.md` and `TableActions.md` When they are read Then each carries one line pointing to the component that uses it (`AddToDeck`; `DeckShape`'s mana bar; `DeckPage`'s row menu)
- [ ] **AC-7.7** Given the repository When `bin/ci checks` runs Then the YARD, RuboCop and comment-ratchet steps pass, and `spec/design_system_files_spec.rb` is green ("spec 019" and "spec 021" still once each, the untabbed-shell block still three rules); each new block has its own heading (decision 22; the guard counts up to the next heading, and is edited only if it must be)

## Functional Requirements

### FR-1: ProxyTag (`ProxyTag.md`, `additions.css`)

`.c-proxy`: `display:inline-flex`, `align-items:center`, `gap:var(--space-1)`, height 20px, padding `0 6px`, `border:1px dashed var(--ink-muted)`, `border-radius:var(--radius-sm)`, `font:600 12px/16px var(--font-sans)`, `color:var(--ink)`, `white-space:nowrap`; its count in `c-proxy b` is `font:400 12px/16px var(--font-mono)`. Markup `<span class="c-proxy">Proxy <b>2</b></span>`. **Must:** keep the word with the number; use the tag wherever a proxy count appears on the deck pages (the zone table, the Decks list). The card page's In decks Proxy column keeps spec 057 decision 8's plain count and dash. **Must not:** fill the tag with a colour, or use it for anything but proxies.

### FR-2: DeckShape (`DeckShape.md`, `additions.css`)

A panel `.c-shape` (`surface-raised`, 1px `line` border, `radius-md`, `space-4` padding, `space-6` between parts) holding a title ("Deck shape") and scope line (`data` mono, `ink-muted`) and three `c-shape__part`s, each with an `h3` `c-shape__heading`.
- **Curve** (`c-curve`): a `role="img"` chart with an `aria-label` that reads every column (decision 20 for the numbers), seven columns in a grid (0 to 6+), each a count (mono 12px) above a bar of at most 96px with the proxy part above the owned part; a 1px `line-strong` baseline; seven labels below; then a legend ("Owned 30", "Proxy 6", each with its swatch) and "Average mana value 2.3". A column with no owned (or no proxy) has no element for that part. Heights are `calc(96px * var(--owned) / var(--max))`.
- **Types** (`c-types`): decision 2. **Mana bar** (`c-manabar`, a `role="img"` list with an `aria-label` that reads the counts) and its caption (`c-manacap`): decisions 3 and 4.
**Must:** every part work in 279px inside the panel's border and padding (the stacked panel in a 360px frame); every part have a word or a number on it; use only tokens (`ink-muted`, `line-strong`, `surface-raised`, `line`, `ink`, `mana-*`, `on-mana-*`). **Must not:** use `brand`, a status colour or a `mana-*` fill outside the mana bar; draw lands in the curve; read data.

### FR-3: DeckPage (`DeckPage.md`, `additions.css`)

`.c-deck`: a grid of the zones (`minmax(0,1fr)`) and the panel (320px) with a `space-8` gap from 992px of the page container (decision 6), the panel `position:sticky; top:calc(56px + var(--space-6))`, one column below it with the panel first and not sticky, and, below 640px, the panel inside `details.c-shapefold` (decision 7). Zones are `section.c-zone` in a column with a `space-8` gap, each a `c-section__head` (decision 10) and a `c-table` in `.c-collection` whose group rows are `tr.c-zone__group` with `th scope="rowgroup"`: `surface-sunken`, `ink-muted`, 12px 600, not sticky (the export's `.c-table th` sticks). From 640px of the table's container a zone table uses decision 25's fixed layout. Below 640px of the page container the zone head wraps its counts onto their own line, and below 640px of the table's container the Card cell and the Decks table's Deck cell wrap their names (`overflow-wrap:anywhere`) and the Cost cell wraps its pips. With no shape panel (the deck page before #256 ships, issue design [7]) the grid keeps its two columns and the panel's column stays empty, as the issue design says; below the breakpoint it is one column of zones, with neither the `aside` nor the `details` copy. DOM order is the `details` copy, the `aside` copy, then the zones; the grid places the zones in the first column and the `aside` in the second, so tab order and reading order agree at every width (the panel's `aria-labelledby` points to its own title, which exists once per copy because the root has no `id` and the view generates two). The card's name is `TableItemLink`; `set · number` is mono `ink-muted`; the Cost cell is a `ManaCost` or a muted dash; the last cell is `TableActions` (decision 17).
**Must:** keep the existing table rules (the `is-opt` fold, `c-table__sub` on narrow containers); keep every control at its existing touch size. **Must not:** name a format or a game in the shell's rules (decision 21); add a column to the table.

### FR-4: DecksIndex (`DecksIndex.md`, `additions.css`)

Decisions 11 to 13, 24. The Decks page is `.c-main.c-page`: a `c-pagehead` ("Decks", a muted "6 decks · 379 cards", and `c-pagehead__actions` holding the primary "New deck" button, kept visible on a phone), then the table (decision 25's column layout). The New deck page is `c-main c-page` under `c-appbar--detail`: a `c-pagehead` ("New deck") and a `c-form` of Name and Format, with Create deck and Cancel. **Must:** a deck with no cards shows "0" and a dash; the empty state replaces the table; the page head keeps the existing `c-pagehead__actions` rule on other pages. Its only new CSS is the name wrap and the column widths shared with the zone table (FR-3), in the DecksIndex block of decision 22.

### FR-5: AddToDeck and UseMyCopy (`AddToDeck.md`, `UseMyCopy.md`, `additions.css`)

`AddToDeck` and `UseMyCopy` are composed from `c-pagehead`, `c-form`, `c-field`, `c-input`, `c-choices` and `c-check`, plus the pick list, `c-pick`, on each page's `c-choices` fieldset: `min-width:0` (a fieldset is as wide as its widest child, spec 042 AC-7.1: a long place name in "My copies (…)" would widen the page), rows that wrap and break inside a word (`overflow-wrap:anywhere`), and a 2px `focus` ring on a row whose control has keyboard focus (`.c-check` has none today). `UseMyCopy`'s lot rows are bordered `surface-raised` blocks (`c-pick__lot`) with the lot's label first and its number field below it (a `c-input` at least 44px high and 6rem wide), `space-3` apart, with `c-pick__group` for the group label. Both pages use `c-appbar--detail`.

### FR-6: Documents and previews

The six documents follow the existing documents' shape (one-line summary, **Markup**, the rules as bullets). The README's Components list and App additions line, the three one-line pointers (AC-7.6), the twelve previews (decision 19), the c-split removal and the icon strokes and the indentation (decision 16, AC-7.4). Each preview loads `preview-fonts.css`, `tokens.css`, `components.css` and `additions.css`, and honours `?theme=dark`.

## Non-Functional Requirements

### Accessibility

- Every chart is `role="img"` with an `aria-label` that reads its values; the visible numbers and legend repeat them for sighted readers (README Charts rule).
- Nothing is colour-only: the proxy is a dashed shape and a word, the legality marker a cross and a word, every segment a letter and a count or the caption.
- Text holds 4.5:1 and every fill or outline 3:1 on `surface`, `surface-raised` and `surface-sunken` in both themes (spec 057 AC-2.3 guards the tokens; the mana letters hold 5.5:1 on their fills, `ManaCost.md`).
- Every control keeps its focus ring and its touch size; the row menus and the Show/Hide summary are keyboard-operable (`<details>`).

### Layout

- Everything works from 360px wide, in both themes, with no horizontal scroll; the shape panel works at 313px wide (279px inside).
- The shell follows the viewport at 640px and the page at its own container (README Mobile and Hotwire).

### Hosted door

Checked against the hosted-door rules ([north star](../../north-star.md)): the spec adds no collector-owned data, so there is nothing to export, no per-account state, no sign-up, email or billing, and no data of a source a hosted instance would have to expose. Cost per account: none (documents, one stylesheet and previews).

### Documentation

- A change of a rule updates the document that states it in the same commit (`.claude/rules/documentation.md`); the README's Components list, App additions line and the Decks and Charts rules agree with the new documents.
- No RSpec example reads a prose document (`.claude/rules/testing.md`): document criteria are verified by reading and recorded in `verification.md`. The CSS and layout criteria are proved in a browser.

## Error Scenarios

| Scenario | Expected behaviour |
|----------|--------------------|
| A deck has no nonland cards | The curve shows seven columns of "0" with no bars, the legend "Owned 0 · Proxy 0" and no average (the line is left out) |
| A deck has only proxies | The curve's columns are hatched only; the types show their counts with "N proxy" equal to the count |
| A symbol count is zero for a colour | That colour has no segment; the caption names only the colours present |
| A deck has no coloured symbols | The mana bar and its caption are left out and the part says "No coloured mana symbols." |
| A part is zero (owned or proxy) in a column | The element is not in the markup, so there is no 2px sliver from the borders |
| A card name is long | The Card cell wraps in a table container narrower than 640px (`white-space:normal`, `overflow-wrap:anywhere`; the export's `nowrap` and the existing 640 to 699px rule do not cover it); a long deck name wraps in the head, the Decks list and the select |
| A zone has many rows | The page scrolls; the panel stays sticky only while it fits the window (the panel's height is under the window's at 720px) |
| No free copy for a proxy | UseMyCopy shows the sentence and the link back and no form |
| The account has no deck when AddToDeck opens | The page says so and links to Decks; no form (decision 23) |
| A quantity is refused: the sum is zero or more than the row's proxies | The page re-renders (422) with a `c-field__error` under the lots' group (the fieldset), "Enter a number from 1 to N." with N the row's proxies, and the entries kept (decision 23) |
| A lot's quantity is over its free copies, or the copies changed meanwhile | The same re-render, with the `c-field__error` under that lot's field, "Enter a number from 0 to M." with M its free copies (decision 23's sentence, one bound lower); with no JavaScript no field's `max` can follow the others' sum, so the server is the check |
| AddToDeck is submitted with no choice, or a count over the free copies | The radios are `required`, as `ChoicePage`'s are; the server's own refusals of the page (no choice past the browser, a count past the free copies) are #255's, drawn there |
| New deck with a blank name or a name another top-level location has | The New deck page re-renders (422) with a `c-field__error` under Name: "Give the location a name." or "You already have a location called “<name>”." (decision 23) |
| A browser draws the open `select` list itself | The group label and options are still readable; nothing relies on the styling (spec 057 decision 16) |

## Open Questions

None. The maintainer ruled every decision (1 to 17, 23 and 24); decisions 18 to 22 and 25 are my calls for Gate A.

## Out of Scope (Future Considerations)

- The deck pages' views, helpers and queries: [#49](https://github.com/plainprogrammer/Collector/issues/49), [#253](https://github.com/plainprogrammer/Collector/issues/253), [#254](https://github.com/plainprogrammer/Collector/issues/254), [#255](https://github.com/plainprogrammer/Collector/issues/255), [#256](https://github.com/plainprogrammer/Collector/issues/256), [#257](https://github.com/plainprogrammer/Collector/issues/257).
- Grouped pickers in the lot form and the other pickers: [#252](https://github.com/plainprogrammer/Collector/issues/252).
- Collector-chosen sections, a deck-builder workflow, deck-size and copy-limit checks (the 2.0 milestone).
- A sixth header link (spec 057's guard fails until the header is revisited).

## Supersedes

- [The issue design](../../superpowers/specs/2026-11-09-decks-and-locations-issues-design.md) decision 10's "Below 640px of the page container, the panel stacks above the zones *(my call)*", for 992px, and the phone's closed `details` (decisions 6 and 7). The issue design is a design document, not a shipped spec; its text is not edited.
- [Spec 057](../057-deck-design-rules/spec.md) Non-Goal "A hatched-fill or chart CSS": drawn here (not a change of a rule). Its Charts rule stands; decision 1 names the hatch.
- The issue design's decision 7 ("Use my copy": a choice page lists free copies, nothing preselected), refined by decision 15 (a quantity on every lot).
- The issue design decision 13's caption ("a caption gives percentages") and the issue body's "letter and count on every segment", refined by decisions 3 and 4 (a narrow segment shows its count in the caption).
- `ChoicePage.md`'s "Nothing is chosen at first", for a page with a single option (decision 14); `ChoicePage.md` gets the exception in its pointer line (AC-7.6).
- No frozen spec is edited.

## Documents and Files Changed

| File | Change |
|------|--------|
| `docs/design-system/components/DeckShape.md`, `ProxyTag.md`, `DeckPage.md`, `DecksIndex.md` (with the New deck page), `AddToDeck.md`, `UseMyCopy.md` | New (FR-1 to FR-5) |
| `docs/design-system/components/ChoicePage.md`, `ManaCost.md`, `TableActions.md` | One pointer line each (AC-7.6) |
| `docs/design-system/components/AppHeader.md` | The page head's buttons hide below 640px, except the Decks page's New deck (decision 24) |
| `docs/design-system/README.md` | Components list and App additions line; the Charts rule's hatch; `c-split` out |
| `docs/design-system/previews/DeckShape.html`, `ProxyTag.html`, `DeckPage.html`, `DeckPagePhone.html`, `DecksIndex.html`, `DecksIndexPhone.html`, `NewDeck.html`, `NewDeckPhone.html`, `AddToDeck.html`, `AddToDeckPhone.html`, `UseMyCopy.html`, `UseMyCopyPhone.html` | New |
| `docs/design-system/previews/*.html` (existing) | Icon strokes (decision 16); `ItemPage.html` and `ItemPagePhone.html` indentation |
| `app/assets/stylesheets/collector/additions.css` | New blocks, each under its own `(spec 060 …)` heading (decision 22) |
| `spec/system/design_system_deck_components_spec.rb` (new) | The CSS and layout criteria (AC-1.2, 1.3, 2.2 to 2.7, 3.2 to 3.9, 3.11, 3.12, 4.2 to 4.5, 5.2, 5.3, 6.2 to 6.4) |
| `docs/specs/README.md` | This spec's row |
| `docs/specs/060-deck-components/verification.md` | The record |

## Verification

- **Document criteria** (AC-1.1, 2.1, 2.8, 3.1, 3.10, 4.1, 5.1, 6.1, 7.1, 7.2's links and markup, 7.4 to 7.6): read against the text; the quotations are recorded in `verification.md`.
- **CSS and layout criteria**: a system example per criterion group, in headless Firefox with classic scrollbars (`spec/support/system.rb`), adds the components' markup to a real page (no view exists), reads computed style and layout, uses `open_in_narrow_frame` for narrow widths, and is shown to fail with its rule removed. Where a component will sit in an existing page or partial (the header, the `.c-page` container, the tab bar's clearance), it is measured there and not only in the preview (lesson `docs/lessons/2026-11-10-measure-the-apps-header-not-the-preview.md`).
- **Previews** (AC-7.2, 7.3): the `<link>` tags are read; each preview is opened in headless Firefox at 1280px and in a 390px frame in both themes, the console is read, and the screenshots go in `verification.md` and the pull request.
- **Repository checks** (AC-7.7): `bin/ci checks` and `spec/design_system_files_spec.rb`, recorded in `verification.md`; the full `bin/ci` run (with a CI slot) is in the pull request.
- **Final visual review**: before the pull request is marked ready, screenshots of each component in both themes, wide and phone, go to the maintainer for review and into the pull request body.
