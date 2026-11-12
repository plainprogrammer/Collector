# Feature 069: The Deck Shape Panel (Mana Curve, Card Types and Coloured Mana Symbols)

**Status:** Approved at Gate A (2026-11-11, the coordinator under the maintainer's delegation, as written; version 0.2.0; the decision text of 0.2.0 reached the file only in 0.2.1, see the changelog)
**Version:** 0.2.2
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 058](../058-mtg-mana-value/spec.md) (the stored mana value; merged), [spec 060](../060-deck-components/spec.md) (the `DeckShape` component, its CSS and previews, and the panel's two copies in `DeckPage`; merged), [spec 066](../066-deck-page-owned-cards-by-zone/spec.md) (the deck page, its seam `Catalog::DeckCards` and Magic's groups; merged), [spec 068](../068-deck-proxies/spec.md) (proxies in a zone; merged), [the decks and locations issue design](../../superpowers/specs/2026-11-09-decks-and-locations-issues-design.md) (decisions 4, 11, 12, 13 and 14, "Shape panel" in "Left to each issue's spec")
**Branch:** `069-deck-shape-panel`
**Issue:** [#256](https://github.com/plainprogrammer/Collector/issues/256) (roadmap item 14k)
**ADR:** none: ADR 0028 already puts a deck's collectible part behind the collecting vocabulary, and spec 066 decision 5 added the first optional answer to that seam; this spec adds a second one the same way (decision 1)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.2 | 2026-11-11 | PATCH (spec only, found by the implementation review): AC-5.3's "279px inside it at 360px" came from spec 060 AC-2.4's arithmetic, which leaves out the page's 8px body margin; a 360px phone viewport leaves 278px. The criterion now says so and is proved in a 375px test frame (a 360px viewport, because the test frame keeps a 15px classic scrollbar a phone doesn't have). The coordinator's ruling stands: no CSS changed. A known limit is recorded (Error Scenarios): in a 360px browser frame with that scrollbar, a four-digit 6+ count overflows its column by about 1.85px, a follow-up for spec 060's CSS. No behaviour, code or other criterion changes |
| 0.2.1 | 2026-11-11 | Approved at Gate A as written (v0.2.0 as described to the coordinator). **Correction:** the v0.2.0 commit (`efea31ad`) carried the review's changes to the acceptance criteria and tables but, through a scripting slip, not its changes to the decisions' text; this version applies them (decisions 1, 2, 3, 5, 8, 9, 12 and the new decision 14), adding nothing the Gate A message did not say. The coordinator's notes for the plan: the split-card non-goal is named in the panel's comment and the area doc, and the only controller edit is the one line in `DecksController#show` |
| 0.2.0 | 2026-11-11 | Spec review round 1 (Opus, APPROVE WITH CHANGES, 0 blocking, 2 major, 11 minor, 4 nits) fixed: the seam is called in `DecksController#show` and the answer's members are named, with the core partial drawing each copy's frame (decision 1, FR-1, FR-3); a row's group is the page's own answer, and another collectible's card is skipped (decision 3, AC-3.5); exact arithmetic for the average and the percentages (decisions 5, 9; AC-2.4, AC-4.7); `{HW}` counts nothing (decision 8); empty-part sentences, the singular in the chart's label and number delimiters (decision 14); retired formats keep a panel (decision 2, AC-1.4, AC-1.8); fixtures that can fail (AC-2.8, AC-4.4, AC-4.10); more stale statements named in AC-7.1 and AC-7.2 |
| 0.1.0 | 2026-11-11 | First draft from issue #256, the issue design, specs 058, 060, 066 and 068, the `DeckShape` and `DeckPage` component documents and today's lessons. The supersession list (spec 066 AC-1.6 and AC-5.1) is from a grep of `spec/`, `docs/` and the area docs for "shape", `c-deck`, `c-shapefold` and "second column" |

## Problem Statement

A collector reading a deck wants to know what it does before reading sixty rows: how cheap it is, what it is made of and which colours it needs. The deck page lists every card but leaves the right column empty (spec 066 left it "for the shape panel"), and spec 060 drew the panel and spec 058 stored the number its curve needs, so nothing but the panel itself is missing.

This spec builds it: the deck page shows, beside its zones, a panel with the deck's mana curve, its counts by card type and the coloured mana symbols its costs ask for, all drawn from the catalog and counting owned copies and proxies together, with the curve showing which are which. It is Magic code behind the collectible seam: the core deck page provides the place for it and names no game.

> **Terms.** The *counted zones* are the deck's Commander and Main zones (the issue design's decision 4); Sideboard and Considering are left out. A *card* in a counted zone is one copy or one proxy, so a row of Owned 3 and Proxy 1 is four cards. A *nonland card* is one the deck page groups anywhere but Lands (spec 066 decision 6, so an Artifact Land is a land and Dryad Arbor, a Land Creature, is not). The *mana value* is `mtg_cards.mana_value` (spec 058): Scryfall's number for the card. A *symbol* is one `{…}` of a mana cost. The *page container*, the *two copies* and the *panel's parts* are `DeckPage` and `DeckShape` (spec 060).

## Goals

- A Magic deck's page shows the shape panel built to `DeckShape.md`: a title, a scope line and the parts Mana curve, Card types and Mana symbols, as the `aside` from 640px of the page container and as the closed `details` below it, with figures that are right (the rules in the decisions below).
- Every rule the issue design left to this spec is written down and proved: how "6+" and half mana values fall into the seven columns, which face of a multi-face card counts, how types are grouped and ordered, and how hybrid, Phyrexian and other symbols count.
- The panel's type counts agree with the deck page's groups, and the curve and the type counts agree with each other.
- The panel costs one more statement than the page costs today and no more however large the deck is.
- The panel reads at 360px in both themes without horizontal overflow, and nothing in it depends on colour alone.

## Non-Goals

- Deck rules: deck size, copy limits, "is this deck legal as a whole" (the 2.0 milestone, issue #258). The panel counts and draws; it never judges.
- A change to the panel's markup, classes or look: spec 060 drew it and its CSS is in `additions.css`. This spec adds no class and no token. (A note under the curve and the empty mana part reuse the existing muted paragraph classes, decision 12.)
- Counting a split card's second half in the mana bar. A card is read through its first face for its type, its cost and its symbols, as the deck page already does (spec 066 decisions 6 and 11); its mana value is Scryfall's number for the card, which for a split card is both halves added. A split card therefore sits in the column of both halves while its symbols are the first half's only. The deck page's Cost column shows the same first half.
- Any other statistic: price, rarity, a colour-identity view, a "colourless" or "generic" segment, a creature-types list, a card-count histogram of anything but mana value.
- The panel on any other page (the Decks list, the card page).
- A panel for a collectible whose vocabulary does not answer (it has none today; the page leaves the column empty, spec 060 AC-3.12).
- Storing anything: no migration, no column, no cache, no export or import change (decision 13).
- Changing `Deck::Page`, the deck page's rows, the row menu or the zone head: those are the deck page's own and [#257](https://github.com/plainprogrammer/Collector/issues/257)'s.

## Users and Context

**Primary users:** a collector with a deck of Magic cards, owned or planned.
**Usage context:** at a desk or on a phone, reading a deck to judge its curve and colours before building, buying or sleeving. A phone shows the panel as a closed "Deck shape" fold above the zones.
**User mental model:** "the curve" is how many spells cost how much, lands aside; "the types" are the rows of the zone tables counted; the symbol bar is how much of each colour the costs ask for. A proxy is a card they will have on the table, so it counts, shown hatched so it can't be taken for one they own.

## Decisions

Decisions 1 to 12 and 14 are this spec's calls inside the issue design's outline (decision 13 states what is not stored); the issue design left the answers of decisions 3 to 8 to this spec ("Shape panel: how '6+' and half mana values bucket, which faces of a double-faced card count, and the type-grouping order"). Gate A confirms them.

1. **A second optional answer on the collecting vocabulary, beside `formats` and `deck_card` (the seam).** A vocabulary may answer `deck_shape(zones)`. The core module `Catalog::DeckShape` (in `app/models/catalog/`, named in `spec/deck_core_spec.rb`, naming no collectible) asks it with the deck's collectible type and the page's zones as `Deck::Page#zones` already built them (each a `Deck::Page::Zone`: its location, whose `zone` is the key, its shown name and its rows with the printing, the copies, the proxies and the page's answer) and gets back an `Answer` of `partial` (the view that draws the three parts), `figures` (what that partial draws), `scope` (the scope line) and `facts` (the `details` copy's facts line), or nil for none. **`DecksController#show` asks once** and sets the answer for the view (the statement of decision 11 runs there, not in a template: `.claude/rules/hotwire.md`). The core partial draws each copy's frame: for the `aside`, the `section`, its `h2` (with a generated id) and the scope line; for the `details`, its `summary` with the facts and the `c-shape--bare` box; it renders `answer.partial` inside each, with the figures, to draw the three parts. The extension supplies the words and parts and the core supplies the page's frame. A vocabulary without `deck_shape`, a collectible type no longer registered and a nil answer give the page no panel, as spec 066 decision 5 does for the other parts. The contract (what an implementation must provide and return, and that it reads the loaded extension records and runs a fixed number of statements) is written in `Catalog::DeckShape`'s comment, the one place it is written down. *Alternative:* build the panel from `Deck::Page`. Rejected: `Deck::Page` is #257's and the core's, and the panel is a collectible's.
2. **The counted zones are chosen by the extension.** Magic counts the zones with the keys `commander` and `main`, in the deck's zone order, and names them in the scope line by their own names ("Main", or "Commander + Main"). The core hands over every zone, Sideboard and Considering included, and names none of them. A deck with neither key has no panel. A deck whose format is no longer registered keeps its zones (the page lists them by id) and so keeps its panel over its Main zone. Cards are counted by quantity: Owned 3 is three cards, a proxy of 2 is two.
3. **One type per card, the deck page's group, in the deck page's order.** The Card types part lists the groups of `MTG::DeckGroups` that have at least one card, in the order of `MTG::DeckGroups::NAMES` (Creatures, Planeswalkers, Battles, Instants, Sorceries, Artifacts, Enchantments, Lands, Other), each with its card count (owned plus proxy) and, when it has proxies, "N proxy". The panel uses the same method as the zone tables (`MTG::DeckGroups.position` of the printing's first face's type line), so a Creature that is also an Artifact is a Creature in both (the panel reads the position from the page's own answer, `row.answer.position`, and does not derive it again), a land that is not a creature is a Land in both (spec 066 decision 6 and AC-6.3), a printing with no face data is Other, and the type counts add up to the cards in the counted zones. A row whose card is of another collectible (a lot is not type-checked when placed in a zone, so the page can hold one; its answer is `Catalog::DeckCards::NONE` with no position) is not counted anywhere in the panel: it is not in the scope line's number, a type, the curve or the bar, and the zone tables show it flat as before. A top-level type outside the nine (Kindred alone, Conspiracy and the like) is Other, which narrows the issue design's decision 12 ("any other top-level type present") to the groups the zone tables already use. The issue design's listing started with Lands; spec 066 chose Creatures first and reading the panel against the zone tables outweighs matching a mock-up. *Alternative:* count every type of a multi-type card (an Artifact Creature in both rows). Rejected: the rows would not add up to the deck and would disagree with the zone tables.
4. **The curve counts nonland cards with a mana value, bucketed by the whole number at or below it.** A card is in the curve when it is not in Lands and its card has a mana value. Column `n` for `n` from 0 to 5 holds the cards whose mana value is at least `n` and under `n + 1`, so a half value falls into the column of the whole number below it (Little Girl, 0.5, is in column 0; a 2.5 is in column 2). Column 6+ holds every mana value of 6 or more (Gleemax, 1,000,000, and a 6.5 included). Each column keeps owned and proxy cards apart. *Why floor:* a half value costs less than the whole number above it, and no real card has one but the Unfinity halves; one rule with no exception. *Alternative:* round half up. Rejected: Little Girl would count as a one-drop.
5. **The average mana value is exact, over the same cards.** It is the sum of the cards' exact mana values divided by their number (so 0.5 counts as 0.5 and a 6.5 as 6.5), shown to one decimal with a trailing zero kept ("3.0"), rounded half up. The sum and the division are exact (the mana values are wholes and halves, so the sum is exact, and the mean is a ratio of integers), so a mean of 0.15 rounds to "0.2". Owned and proxy cards count alike. It is left out when no card is in the curve.
6. **A nonland card with no mana value is left out of the curve and the average and the panel says so.** It is a card of an instance whose catalog has not been refreshed since spec 058's upgrade, or one Scryfall gave no number for. It is not counted as a 0, which would put it in the cheapest column; a note under the curve reads "N nonland cards have no mana value yet." (with "card" and "has" for 1) and is left out when there are none. The curve's legend and chart label count only the cards in the curve. The card is still in the type counts and the scope line.
7. **The mana value is the card's, as Scryfall gives it, and the cost is the first face's.** The curve reads `mtg_cards.mana_value` through the printing's identity (spec 058 decision 2: the card's number, the front face's for a reversible card, both halves added for a split card). The symbols come from the first face's `mana_cost` of the printing, the cost the zone tables show (spec 066 decision 11), which the page already has loaded. A transform or modal double-faced card is therefore its front face (type, cost, symbols and mana value); the back face's type and cost never count. *Why not the joined `mtg_cards.mana_cost`:* it concatenates the faces ("{1}{R} // {2}{G}") and would count a back face a collector can't cast from the library.
8. **Coloured symbols: one count per colour a symbol names.** The mana bar counts, for every card in the counted zones (Lands included, which have no cost), each symbol of the first face's cost: `{W}`, `{U}`, `{B}`, `{R}` and `{G}` count one toward their colour; a hybrid symbol (`{W/U}`) counts one toward each of its colours, so it adds two to the bar's total; a Phyrexian symbol (`{G/P}`) counts one toward its colour, as the cost still asks for that colour (it can also be paid with life), and a Phyrexian hybrid (`{G/W/P}`) one toward each of its colours; a hybrid of a colour and a generic or colourless part (`{2/W}`, `{C/W}`) counts one toward the colour only. Generic (`{3}`), variable (`{X}`), colourless (`{C}`) and snow (`{S}`) symbols are never counted, and the bar never draws them (spec 060 decision 4); a half symbol (`{HW}`, Little Girl's cost, from the Unfinity cards) counts nothing, as does any symbol the rules above don't name, because half a symbol is not a symbol the deck asks for. Each symbol counts times the card's count (owned plus proxy), so a card of 3 copies and 1 proxy with one `{U}` adds 4. *Why count the Phyrexian and the hybrid:* the panel answers "what colours does this deck ask for", and an uncounted symbol would hide a colour the cost names (the issue design's decision 13, "my call; the spec may refine", refined only for the cases it did not name).
9. **Percentages and the narrow rule.** The caption's percentage is the colour's share of all coloured symbols, rounded half up to a whole percent on its own in exact arithmetic (1 of 8 is 13%), so a caption may add to 99 or 101. A segment of under 10% of the symbols is narrow (`count × 100 < total × 10`, exact in integers).
10. **The panel's scope line and facts.** The scope line is the counted zones' names joined with " + " in the zone order, then " · " and the number of cards in them: "Main · 60 cards", "Commander + Main · 100 cards", "Main · 1 card", "Main · 0 cards". The `details` copy's facts line is the scope line, and " · average mana value 2.3" when there is an average.
11. **Statements and tenancy.** The panel runs one statement of its own: the cards' mana values, `MTG::Card` for the identity ids of the counted zones' printings, read once and not at all when those zones hold no card. Everything else comes from the rows `Deck::Page` already loaded (the printings' extension records and faces). It reads nothing by id from the request: the deck came from the signed-in account's decks and the rows from its zones, and the identities are catalog data (global, no `account_id`).
12. **Markup and classes are `DeckShape.md`'s.** The panel is rendered twice as `DeckPage.md` says: the `details.c-shapefold` copy, then the `aside.c-deck__shape` copy, then the zones, inside `c-deck`; the figures are custom properties and text, no colour in a `style` attribute. The two cases the component document leaves to the data (the empty mana part's sentence, the curve's note) reuse the muted caption paragraphs `c-manacap` and `c-curve__avg`; no CSS is added. The note follows the average line, so a curve can hold two `c-curve__avg` paragraphs (the average, then the note) and a test tells them apart by text. The component document gets the rules this spec settles.
13. **Nothing is stored and nothing is exported.** The panel is computed on every page view from catalog data and the deck's rows, so it needs no migration, no job, no cache and no change to the export, the import or the backup (no collector-owned field is added).
14. **Words for the edges.** Counts, the scope line and the average use `number_with_delimiter` as the zone heads do (a mana value of 1,000,000 alone reads "1,000,000.0"). The scope line says "1 card", never "1 cards". The curve's `aria-label` reads "Mana curve of the N nonland cards in <scope>: …" with "1 nonland card" for one, and with none reads "Mana curve of the 0 nonland cards in Main: no cards." The Card types part of a scope with no card keeps its heading and says "No cards yet." in a `c-manacap` paragraph, and the Mana symbols part with no coloured symbol says "No coloured mana symbols." in the same class.

## User Stories

### Story 1: The deck page shows the shape panel

**As a** collector reading a Magic deck
**I want** its shape beside its zones
**So that** I see what the deck does without counting rows

**Acceptance criteria:**

- [ ] **AC-1.1** Given a deck of Magic cards When its page is requested Then the markup holds, inside `c-deck` and in this order, a `details.c-shapefold` copy, an `aside.c-deck__shape` copy and the `div.c-deck__zones`; each copy holds the three parts Mana curve, Card types and Mana symbols in that order with their `h3` headings, the `aside`'s `section.c-shape` is labelled by its own `h2` "Deck shape" and carries the scope line, and the `details` summary reads "Deck shape" and the facts line (decision 10)
- [ ] **AC-1.2** Given the two copies When their ids are read Then the panel's root has no `id`, the `aside`'s `aria-labelledby` points to a title id that exists once, and no id on the page is repeated
- [ ] **AC-1.3** Given a page container of 992px or wider When it is rendered Then the zones are the first column and the `aside` is the 320px second column beside them, sticky, with the `details` copy not displayed; given a container of 640px to 991px Then the `aside` copy is displayed above the zones, open, with no summary and not sticky; given one narrower than 640px Then the `details` copy is displayed, closed, above the zones, and the `aside` is not (spec 060 AC-3.3, AC-3.4)
- [ ] **AC-1.4** Given a deck whose collectible's vocabulary has no `deck_shape` answer, a deck of a type no longer registered, and a Magic deck whose zone rows include neither a `main` nor a `commander` (a fixture that deletes them: no path of the app makes one) When its page is requested Then neither copy is rendered and the second column is empty from 992px (spec 060 AC-3.12)
- [ ] **AC-1.5** Given a Casual deck with no card at all When its page is requested Then the panel is there: the scope line "Main · 0 cards", seven curve columns of 0 with no bars, the legend "Owned 0" and "Proxy 0", no average line, the Card types part saying "No cards yet.", and the Mana symbols part saying "No coloured mana symbols."
- [ ] **AC-1.6** Given another account's deck, a place's id or a zone's id When the page is requested Then it is a 404 as before and no figure of it is shown (spec 066 AC-1.2 stands)
- [ ] **AC-1.7** Given the `core guard` (`spec/deck_core_spec.rb`) When it runs Then it lists the new core files (the seam and the page's partial, if the plan adds one), counts them, and none of them names a game, a source, a format or a zone other than Considering, comments included
- [ ] **AC-1.8** Given a Magic deck whose format is no longer registered (a stored key the registry does not list) with cards in its Main zone When its page is requested Then the panel is there, over the Main zone, with the scope line "Main · N cards"

### Story 2: The mana curve

**As a** collector
**I want** the deck's curve with what I own and what I proxy told apart
**So that** I can see how cheap the deck is and how much of it I still need

**Acceptance criteria:**

- [ ] **AC-2.1** Given a Main zone with Lightning Bolt (mana value 1) owned 3 and proxy 1, Llanowar Elves (1) owned 2, Counterspell (2) proxy 2, and a Forest owned 4 When the panel is built Then column 1 shows 6 (5 owned, 1 proxy), column 2 shows 2 (0 owned, 2 proxy), every other column shows 0, the Forest is not in the curve, and the legend reads "Owned 5" and "Proxy 3" and the average "Average mana value 1.3" (6 × 1 + 2 × 2 = 10, over 8 cards = 1.25, rounded half up)
- [ ] **AC-2.2** Given cards of mana value 0, 5, 6, 7, 9 and 1,000,000 When the panel is built Then they are in columns 0, 5, 6+, 6+, 6+ and 6+
- [ ] **AC-2.3** Given a card with mana value 0.5 (Little Girl), one with 2.5, and one with 6.5 When the panel is built Then they are in columns 0, 2 and 6+, and the average uses 0.5, 2.5 and 6.5
- [ ] **AC-2.4** Given the cards of AC-2.3 and one card of mana value 1 When the average is computed Then it is the exact mean, (0.5 + 2.5 + 6.5 + 1) ÷ 4 = 2.625, shown "2.6"; given a mean of exactly 3 Then it is shown "3.0"; and given 3 cards of mana value 0.5 and 7 of 0 (a mean of 0.15) Then it is shown "0.2" (exact arithmetic, decision 5)
- [ ] **AC-2.5** Given a nonland card whose card has no mana value (NULL) and another with a value of 3 When the panel is built Then only the second is in the curve, the average and the legend, a note under the curve reads "1 nonland card has no mana value yet.", the NULL card is still counted in its type and in the scope line, and with three such cards the note reads "3 nonland cards have no mana value yet."; given a mana value of 0.0 Then the card is in column 0 and there is no note
- [ ] **AC-2.6** Given a Land Creature (Dryad Arbor, mana value 0), an Artifact Land and a Basic Land When the panel is built Then Dryad Arbor is in column 0 and the other two are not in the curve (they are Lands, spec 066 decision 6)
- [ ] **AC-2.7** Given a transform double-faced card whose front face costs 2 and whose back face is a land and a reversible card whose two faces have a mana value of 4 When the panel is built Then each is one card in the column of its stored mana value (2, and 4), counted by its front face's type; and a modal double-faced card whose first face is a Sorcery and whose second a Land is a nonland card in the curve
- [ ] **AC-2.8** Given a Sideboard zone and a Considering zone holding cards that Main lacks (a mana value, a type and a colour found nowhere in Main, so counting them would change a figure), with a Main zone holding others When the panel is built for a Casual or a constructed deck Then only the Main zone's cards are in any part and the scope line says "Main"; given a Commander deck Then the Commander and Main zones are counted together, the scope line says "Commander + Main", and Considering is not counted (its cards again hold a value, a type and a colour found nowhere in the counted zones)
- [ ] **AC-2.9** Given the chart When it is read by a screen reader Then it is one `role="img"` whose `aria-label` reads the scope, the number of cards in the curve, each mana value with its card count and its owned and proxy split (a part of zero left out, a column of zero omitted from the sentence) and the average, the columns and their labels are `aria-hidden`, a column has a count above it and a bar of at most 96px with the proxy part on top, and a part of zero has no element (spec 060 AC-2.2, AC-2.3)
- [ ] **AC-2.10** Given the curve in either theme When it is looked at Then owned is the solid `ink-muted` fill and proxy the hatched `line-strong` fill with the `ink-muted` outline, no `brand` and no status colour, and the legend and the counts name each series so no value is carried by fill alone

### Story 3: Counts by card type

**As a** collector
**I want** a count for each kind of card
**So that** I see the balance of creatures, spells and lands

**Acceptance criteria:**

- [ ] **AC-3.1** Given a Main zone with 8 Creatures (2 of them proxies), an Artifact Creature, a Sorcery, 3 Basic Lands and a printing with no face data When the panel is built Then the Card types part lists, in order, Creatures 9 (with "2 proxy"), Sorceries 1, Lands 3 and Other 1, each count in the mono face and a row with no proxy having the empty suffix so the counts line up, and Planeswalkers, Battles, Instants, Artifacts and Enchantments are not listed
- [ ] **AC-3.2** Given the same zone When the type counts are added up Then they equal the number of cards in the counted zones (the scope line's number), and for every group of the deck page the Main zone's table shows the same count as the panel's row (`group.total` of the zone, for a deck whose only counted zone is Main)
- [ ] **AC-3.3** Given Dryad Arbor (Land Creature), an Artifact Land, a Kindred Instant and a Legendary Planeswalker When the panel is built Then they are counted under Creatures, Lands, Instants and Planeswalkers, as the deck page groups them (spec 066 AC-6.3's type lines)
- [ ] **AC-3.4** Given a proxy of a card with a Land type line When the panel is built Then it is a land card, counted under Lands with "1 proxy", and not in the curve
- [ ] **AC-3.5** Given a Magic deck page holding a row whose card is of another collectible type (a lot placed in the zone, whose page answer is `Catalog::DeckCards::NONE`) When the panel is built Then that row is in no part and not in the scope line's number, the type counts still add up to the scope line's number, and the zone table shows the row flat as before

### Story 4: Coloured mana symbols

**As a** collector
**I want** to see how many symbols of each colour the deck's costs ask for
**So that** I can judge the mana base

**Acceptance criteria:**

- [ ] **AC-4.1** Given a Main zone with Counterspell (`{U}{U}`) owned 2, Lightning Bolt (`{R}`) owned 1 and a proxy 1, and Wrath of God (`{2}{W}{W}`) proxy 1 When the panel is built Then the bar has segments in W, U, B, R, G order for the colours present: W 2, U 4, R 2, and the caption reads "White 2 · 25% · Blue 4 · 50% · Red 2 · 25%" (every colour present with its count and percentage; a colour with no symbols is neither drawn nor named)
- [ ] **AC-4.2** Given a card costing `{W/U}{W/U}` (Hybrid) with 2 copies When counted Then it adds 4 to W and 4 to U; given `{R/G}` once Then it adds 1 to R and 1 to G
- [ ] **AC-4.3** Given a card costing `{2}{G/P}` (a Phyrexian symbol) Then it adds 1 to G; given `{G/W/P}` Then 1 to G and 1 to W; given `{2/W}` Then 1 to W only; given `{C/W}` Then 1 to W only
- [ ] **AC-4.4** Given costs holding `{3}`, `{X}`, `{C}`, `{S}` and `{HW}` When counted Then they add nothing to any colour: a Main holding only `{3}{X}{C}{S}{G}` has exactly one coloured symbol, G 1, a total of 1, and a card costing `{HW}` (Little Girl) adds nothing and is still in the curve at its mana value
- [ ] **AC-4.5** Given a double-faced card whose front face costs `{1}{U}` and whose back face costs `{3}{R}`, and a split card `{1}{R} // {1}{U}` When counted Then only the first face's symbols count (U 1 from the first card, R 1 from the split card, whose second half's U is not counted), as the zone table's Cost shows
- [ ] **AC-4.6** Given a deck whose white symbols are 5 of 100 When the panel is built Then the white segment carries `c-manabar__seg--narrow` and has no label inside it, and the caption still names "White 5 · 5%"; given one whose segment is exactly 10 of 100 Then it is not narrow (under 10%, decision 9)
- [ ] **AC-4.7** Given colours with counts 1, 1 and 1 When the caption is built Then each percentage is 33% (rounded on its own, so the caption may not add to 100); given 1 of 8 symbols Then it is 13% (half up, exact)
- [ ] **AC-4.8** Given a deck with no coloured symbol (only lands and artifacts with generic costs) When the panel is built Then the part has no bar, no segment and no caption and says "No coloured mana symbols."
- [ ] **AC-4.9** Given the bar of AC-4.1's deck When it is read by a screen reader Then it is one `role="img"` whose `aria-label` reads "Coloured mana symbols in Main: white 2, blue 4, red 2" (the scope, the present colours in W, U, B, R, G order with their counts), every segment fills with its `mana-*` token with the matching `on-mana-*` text, in both themes, a 1px `line-strong` outline on the bar and a divider between segments (spec 060 AC-2.6, AC-2.7)
- [ ] **AC-4.10** Given Sideboard and Considering cards with a colour that Main lacks (a green card in each, Main having none) When the bar is built Then green is not in the bar or the caption

### Story 5: The panel fits at every width and in both themes

**As a** collector on a phone
**I want** the panel readable at 360px
**So that** I never scroll sideways

**Acceptance criteria:**

- [ ] **AC-5.1** Given a deck page at 360px, 640px, 768px and 1280px in the light and the dark theme, with a deck of every type, a hybrid-heavy five-colour cost list, a 60-character deck name with no space and a mana value of 1,000,000 in the deck When it is rendered Then the page has no horizontal overflow and every colour of the panel is a design system token
- [ ] **AC-5.2** Given the page at 360px When it is rendered Then the `details` copy is the one displayed, closed, at least 44px high, its summary reads "Deck shape" with the facts line of the deck's own figures (for a fixture of 60 cards in Main and an average of 2.3, "Main · 60 cards · average mana value 2.3") and Show, and it opens and closes from the keyboard with Enter or Space and with no script
- [ ] **AC-5.3** Given the panel open in a phone's 360px viewport (the page's 8px body margin, 16px page padding, the fold's 2px border and the panel's 32px padding leave 278px inside it; the example opens a 375px frame, whose pinned 15px classic scrollbar a phone doesn't have) When it is measured Then the seven curve columns, the legend, every type row and the caption fit inside it with no horizontal scroll of the panel, nothing drawn past its padding edge and no text cut off in its own box, and each count has room in its column; the average line wraps when its number is long
- [ ] **AC-5.4** Given the panel in both themes When it is read Then no part is conveyed by colour alone: every column has its count, every segment its letter and count or a caption naming it, and the series are named in the legend

### Story 6: What the page reads

**As a** self-hoster
**I want** the page to cost the same however big the deck is
**So that** a 250-card deck loads as fast as a 60-card one

**Acceptance criteria:**

- [ ] **AC-6.1** Given decks with one card and with 60 cards of 40 printings, with proxies and without When the deck page is requested Then the number of statements is the same for both and is the page's count before this spec plus at most one (the mana values), and zero more for a deck whose counted zones hold no card
- [ ] **AC-6.2** Given `Deck::Page#zones` When it is read Then it is unchanged: its statement counts (3 and 6) are as spec 068 AC-2.10 set them and the panel adds its statement outside it
- [ ] **AC-6.3** Given the panel built twice for one request (the two copies) When the statements are counted Then the figures were built once and rendered twice

### Story 7: The documents

**As an** agent working in the deck code later
**I want** the rules in one place
**So that** I don't rediscover them

**Acceptance criteria:**

- [ ] **AC-7.1** `docs/architecture/collection-and-lots.md` states the panel's rules (the counted zones, the groups and their order, the curve's bucketing, the average, the missing mana value, the symbols, the seam and its statement count) with spec 069 and #256 as sources, its deck-page paragraph no longer says the right column stays empty, and its statements "(both not built …)" (the Considering and shape-panel line near the deck-page rules) and "the shape panel (#256) and proxies (#254) are not" (the open notes) are brought up to date; `docs/architecture/catalog-core.md`'s line "Nothing reads the column yet; the deck shape panel … is its first reader" says the panel reads it (verified by reading, each by a grep of the area docs for `shape panel`, `#256` and `first reader`)
- [ ] **AC-7.2** `docs/design-system/components/DeckShape.md` states what this spec settled (the bucketing, the average's rounding, the order of the types, which cost counts, the note under the curve and the empty mana part's sentence, their classes) `DeckShape.md`'s "Spec 060 builds nothing that reads it … are #256's" says what #256 settled, and `DeckPage.md`'s "As built" no longer says neither copy is rendered and its "No shape panel (a deck page before the panel exists)" reads "a deck whose collectible draws no panel" (verified by reading)
- [ ] **AC-7.3** `docs/specs/README.md` has this spec's row with the supersession of spec 066 AC-1.6's "no shape panel" clause and AC-5.1's "the second column is empty", with the reverse pointer on spec 066's row; `CLAUDE.md`'s decks sentence names the panel and the seam `Catalog::DeckShape` beside `Catalog::DeckCards` in the guard sentence; `spec/deck_core_spec.rb`'s file list and count are updated
- [ ] **AC-7.4** `bin/yard doc` builds without warnings and the new public code carries comments (the extension contract in `Catalog::DeckShape`, the figures' object and its methods), with no collectible named in a core file's comment

## Functional Requirements

### FR-1: The seam

`Catalog::DeckShape` asks a collectible's vocabulary for the deck page's panel (decision 1) and returns nil whenever the vocabulary does not answer. It takes the page's already-built zones and the deck's collectible type, returns an `Answer` of `partial`, `figures`, `scope` and `facts` (decision 1), and runs at most the statements the extension's answer runs. `DecksController#show` calls it once. It names no collectible, format or zone.

**Must:**
- Return nil for a type not registered, a vocabulary without `deck_shape` and an answer of nil.
- Hand the extension every zone and leave the choice of counted zones to it (decision 2).

**Must not:**
- Name Magic, a format, Commander, Main or Sideboard in a core file or comment.
- Change `Deck::Page`, `Catalog::DeckCards` or the deck page's rows.

### FR-2: The figures (Magic)

`MTG::Collecting.deck_shape` builds the figures of decisions 2 to 10 from the counted zones' rows and renders through a partial under `app/views/mtg/`. The figures object is a plain Ruby object under `app/models/mtg/`, built once per request, holding: the scope text, the card total, the seven `[owned, proxy]` curve pairs, the average, the number of cards with no mana value, the type rows (name, count, proxy) and the colour counts.

**Must:**
- Use `MTG::DeckGroups` for the type of every card (decision 3).
- Read mana values in one statement and symbols from the loaded printing's first face (decisions 7, 8 and 11).
- Be pure for fixed rows: the same rows and the same mana values give the same figures.

**Must not:**
- Count a symbol of a face other than the first, a symbol of a zone other than the counted zones, or a nonland card with no mana value as a 0.
- Call Scryfall or read `mtg_cards.mana_cost`.

### FR-3: The view

The deck page renders the two copies of the panel inside `c-deck`, before the zones, when the seam answers (decision 12), through a core partial that draws each copy's frame and renders the answer's partial in both (decision 1), and nothing else on the page changes.

**Must:**
- Follow `DeckShape.md` and `DeckPage.md` for the markup, the title ids and the copies' order.
- Put no value that is a colour in a `style` attribute.

**Must not:**
- Add a CSS rule, a class or a token.

## Non-Functional Requirements

### Performance

- One added statement, bounded however many cards the deck has (decision 11, AC-6.1); no query per card or per zone; the figures are built once for both copies.
- The partial is about 3 KB per copy (spec 060 decision 7).

### Security

- No new route, parameter or form: the panel is part of `GET /decks/:id`, whose lookup and 404 rule do not change (spec 066 AC-1.2). Card names and every figure are escaped by the template as everywhere else; no `html_safe`, no `raw`.
- It reads catalog data (global) and the deck's own rows (the signed-in account's): no query takes an id from the request and no figure of another account can appear.

### Reliability

- A catalog not yet refreshed since spec 058 (every mana value NULL) shows an empty curve with the note of decision 6, never an error or a wrong curve.
- A printing whose extension record or faces are missing is Other, has no cost and adds no symbol; a mana cost that is blank, `nil` or malformed adds nothing and raises nothing.

### Accessibility and design

- Phone at 360px and wide at 1280px, both themes, no horizontal overflow; nothing by colour alone (Story 5); the design system's tokens and classes only.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The catalog was never refreshed since spec 058 (every mana value NULL) | The curve is empty (seven columns of 0, no average), the note says how many nonland cards have no mana value, types and symbols draw as normal (decision 6, AC-2.5) |
| The deck has no card in Main or Commander | The panel shows the empty states of AC-1.5 |
| A deck of a format no longer registered | Keeps its zones and its panel over Main (AC-1.8); only a Magic deck with neither a `main` nor a `commander` zone row has none (AC-1.4) |
| Only proxies | Hatched columns only, each type's "N proxy" equals its count, no owned bar anywhere |
| A card's mana cost is nil, empty or has a symbol the rules don't name (`{HW}`) | Counts no colour for what it cannot read; the card is still counted in its type and the curve (AC-4.4) |
| A card of another collectible type in a Magic zone | Skipped by every part of the panel, shown flat in the zone table (AC-3.5) |
| A mana value of 1,000,000 | Column 6+, and the average line's long number wraps inside the panel |
| A four-digit count in the 6+ column in a 360px browser frame that keeps a 15px classic scrollbar (a 263px interior) | The count ("1,357") overflows its column by about 1.85px and the panel's inner edge by about 1px. A known limit of spec 060's column width, not seen on a phone (278px: +0.28px); the CSS is left unchanged and the follow-up is the maintainer's |
| A card in Lands with a mana value, or a land with a cost | Not in the curve; a land's symbols, if it had any, are counted (decision 8) |
| Every symbol is generic | "No coloured mana symbols." in place of the bar and caption |
| A deck with zero coloured symbols in the five colours but hybrid colourless symbols (`{C/W}`) | The W count rises; the colourless half is never drawn |
| The same printing is owned and proxied in one zone | One row on the page, two kinds of card in the figures: owned in the owned part, proxy in the proxy part |
| The statements fail (the database is busy) | The page fails as every page does; the panel has no rescue of its own |

## Interactions and Supersession

- **Supersedes, from #256** (spec 066 is frozen and is not edited, spec 027 D4; the supersession lives here, in the specs index and in the area docs): spec 066 AC-1.6's clause "it has no shape panel (neither the `aside` nor the 'Deck shape' `details`)", AC-5.1's "the second column is empty, because the shape panel is not rendered" (for a Magic deck; it still holds for a deck the vocabulary gives no panel, spec 060 AC-3.12), and its Goals and Non-Goals lines that leave the right column empty and the panel unrendered "(#256)". Spec 068's list of what is out of scope (the shape panel, #256) is a boundary this spec fills.
- **Existing examples this changes** (found by a grep of `spec/` for `shape`, `c-deck`, `c-shapefold`, `aside`, `second column` and `children.length`; the plan re-runs the grep): `spec/requests/deck_pages_spec.rb` ("has no shape panel, and a dash in the Proxy cell…", its line `expect(html.at_css("aside.c-deck__shape, details.c-shapefold")).to be_nil`) and `spec/system/deck_page_spec.rb` ("leaves the second column empty from 992px…", which asserts `.c-deck` has one child). Both are rewritten whole or changed to the panel-less case; the plan lists any further example that counts the page's headings, text or `details` and finds none by the grep above.
- **Reads, changes nothing of:** spec 058 (`mana_value`), spec 060 (`DeckShape`, `DeckPage`, the CSS and previews), spec 062 (the seam `Catalog::Formats`), spec 066 (`Catalog::DeckCards`, `MTG::DeckGroups`, `Deck::Page`), spec 068 (proxies as lines of a row).
- **#257 (spec 070)** also edits the deck page (`decks/show`, `Deck::Page`, the row menu). This spec's edits are confined to the two copies inside `c-deck`, before `c-deck__zones`, in `decks/show`, one line in `DecksController#show` that sets the panel's answer, and the panel's own files; it does not edit `Deck::Page`, the zone partial or the row menu. If #257 also edits the controller, the two edits are separate lines and merge by keeping both.

## Open Questions

None. (Decisions 1 to 12 are the author's calls inside the issue design's outline, for Gate A to confirm: the seam's shape (1), the groups' order (3), the floor for half values (4), the one-decimal average (5), the left-out and noted NULL value (6), the first face's cost and the mana value as Scryfall gives it (7), counting Phyrexian and hybrid symbols and not half symbols (8).)

## Out of Scope (Future Considerations)

- Deck checks (size, copy limits): the 2.0 milestone ([#258](https://github.com/plainprogrammer/Collector/issues/258)).
- Counting the second half of a split card's symbols, or a "both faces" view of a double-faced card.
- Other statistics (price, colour identity, creature subtypes) and a panel anywhere but the deck page.
- A rake task or admin control that fills missing mana values (spec 058's Out of Scope).
