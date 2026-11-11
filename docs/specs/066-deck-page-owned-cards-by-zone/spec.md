# Feature 066: The Deck Page, Owned Cards by Zone

**Status:** Approved
**Version:** 0.3.1
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 060](../060-deck-components/spec.md) (the `DeckPage` shell, the zone table, the legality marker and their CSS; merged), [spec 062](../062-create-rename-remove-a-deck/spec.md) (decks, zones, the Decks page; merged), [spec 065](../065-deck-zones-in-pickers/spec.md) (copies reach a zone through the pickers; merged); builds on [spec 064](../064-change-deck-format/spec.md) (a change of format moves copies and can add a zone) and [spec 004](../004-design-system-collection/spec.md)'s card page legality
**Branch:** `066-deck-page-owned-cards-by-zone`
**Issue:** [#253](https://github.com/plainprogrammer/Collector/issues/253)
**ADR:** none: ADR 0028 already puts the formats behind the collectible's vocabulary; this spec adds a second optional answer to the same seam (decision 5) and changes none of its choices

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.3.1 | 2026-11-11 | Gate B, the coordinator's ruling: AC-5.6 states the design system's rule (44px on coarse pointers, the size `c-btn` and links already have on fine ones) so the system example asserts what the criterion says |
| 0.3.0 | 2026-11-11 | Gate A, the maintainer's rulings (2026-11-11) through the coordinator: rows per printing and no row menu as written (decisions 2, 9); **changed:** the zone table keeps spec 060's Card, Cost, Owned, Proxy and Total columns, with no menu column, Proxy a muted dash and Total equal to Owned until #254, and the phone layout stays spec 060 decision 9's, so spec 060 decision 9 and AC-3.6 are no longer superseded (decision 7); **changed:** a card with Land in its type line is in Lands unless it is also a Creature (decision 6, AC-6.3); Approved |
| 0.2.1 | 2026-11-11 | From review round 2 (no blocking, one major): 060 decisions 10 and 25 and AC-3.11 added to the supersession list, AC-6.6 for a printing with no extension record, and wording fixes |
| 0.2.0 | 2026-11-11 | From review round 1 (no blocking, six major): no row menu in 1.0 (decision 9; the name links to the card's copies), Owned on a phone recorded as superseding spec 060 decision 9 (decision 7), the number order cited from `Catalog::Entry`, the printing's first face as the data source (decisions 5, 11), `tenancy-and-accounts.md` added, "one row per printing" flagged as the reading of the issue's "one row per card" (decision 2), and the minor fixes |
| 0.1.0 | 2026-11-11 | First draft from issue #253, the issue design's item [7], specs 060, 062, 064 and 065, and the design system's `DeckPage` |

## Problem Statement

A collector can make a deck, put copies into its zones through the pickers and change its format, but they cannot *look* at it. The Decks page lists decks with a count, and the only way to see what is in a zone is to filter the collection by it. The deck is the unit a collector thinks in at the table: which cards, in which zone, how many, what they cost, and whether each is legal in the format.

This spec adds the deck page: one deck, its zones one under the other, each a table of the cards the collector owns in it, grouped by card type, with the cost and the owned count of each card and a marker on any card that is not legal in the deck's format. Copies still reach a zone only through the ways that exist; the page reads them.

> **Terms.** *Deck, zone, place, label, lot, Considering* are as in [`collection-and-lots.md`](../../architecture/collection-and-lots.md) and spec 062. A *card row* is one row of a zone's table: one catalog entry (one printing) with the copies of it in that zone. *Owned* is the quantity of copies a collector owns. *The page's extension* is the collectible's part of the page (the cost, the groups of rows and the legality marker), supplied through the collectible's vocabulary as the formats are (ADR 0028).

## Goals

- A collector opens a deck from the Decks page and sees every zone, in the format's order, each with its owned cards in a table.
- Each card row (one printing of a card in the zone) shows the card, its cost and how many copies are owned in that zone; rows are grouped under the card's top-level type. The table has spec 060's Card, Cost, Owned, Proxy and Total columns, so #254 fills cells and adds no column.
- A card that is not legal in the deck's format is marked, from the catalog's stored legalities, and a legal card or a format with no rules shows nothing.
- The page fits at 360px, 640px and desktop widths in both themes, with the right column left empty for the shape panel (#256).
- The page is read-only: it adds no way of adding copies and no data to the export.

## Non-Goals

- **Proxies** and everything about them: no "Add a proxy", no proxy count, no proxy data ([#254](https://github.com/plainprogrammer/Collector/issues/254)). The Proxy column exists and shows a muted dash in every row, and Total equals Owned; #254 fills those cells and adds the row menu, with no rework of the table (decisions 7 and 9).
- **The shape panel** ([#256](https://github.com/plainprogrammer/Collector/issues/256)): neither the `aside` nor the `details` copy is rendered.
- **Deck-size and copy-limit checks** (2.0, [#258](https://github.com/plainprogrammer/Collector/issues/258)).
- **A new way to add copies, and any way to move them from the page.** No add form, no "add to this zone" button, no drag and drop, no row menu here; the add-to-deck flow from a card page is [#255](https://github.com/plainprogrammer/Collector/issues/255), and a card's copies are moved from the card page's "Your copies" as today (decision 9).
- **Pagination, sorting or filtering** of a zone's table. A zone lists all its cards, in the order of decision 3.
- **Changing the export format, the import or any table.** The page only reads.
- **Free to use, In decks** or any count on the card page ([#50](https://github.com/plainprogrammer/Collector/issues/50)).
- **A change to where "Rename", "Change format" and "Remove" live on the Decks page.** They stay as spec 062 and 064 made them; the deck page offers the same three, and each still returns to the Decks page when done (decision 1).

## Users and Context

**Primary users:** a collector with a deck of cards they own, at a desk or with the deck laid out on a table, on a laptop or a phone.
**Usage context:** they open the Decks page, choose a deck, and scan its zones: Main first, then Sideboard, then Considering (Commander first for a Commander deck). A deck holds 15 to 100 cards, and Considering may hold more.
**User mental model:** "my Modern deck: 4 Lightning Bolt in Main, 2 Spell Pierce in Sideboard". Cards are grouped as deck builders group them: creatures, instants, lands. A banned card is a card they should look at.

## Decisions

Each is my call unless it names a ruling; alternatives are listed so the coordinator can redirect. Decisions 2, 6, 7 and 9 are the maintainer's rulings of 2026-11-11, given at Gate A; decisions 1, 3, 5, 8, 10, 11 and 12 were reviewed with the spec and stand as written.

1. **The route is `GET /decks/:id` (`decks#show`),** the id being the deck's location id as in every deck route (spec 062 decision 4). It uses the controller's existing lookup, so another account's deck, a place's id and a zone's id are 404 (spec 062 AC-3.8). The Decks page's deck name becomes a link to it, restoring the link spec 060 drew and spec 062 decision 5 postponed "until #253"; the Rename, Change format and Remove buttons on the row stay. Creating, renaming and changing the format still return to the Decks page. *Alternative:* land on the deck page after Create. It is a one-line change but moves a rule spec 062 AC-1.3 states, and a new empty deck on the Decks page is where a collector expects it. So Edit deck, Change format and Remove, started from the deck page, also return to the Decks page, and Back on the rename page goes there.
2. **A card row is one printing in one zone, and Owned is the sum of that printing's lots in the zone (the maintainer's ruling of 2026-11-11).** Finish, condition and price paid do not split a row: a collector who owns a foil and a nonfoil Lightning Bolt of one printing in Main sees one row with the two quantities added. Two printings of one card are two rows, which is what the design system's `set · number` line and its "a zone can hold two printings of one card" assume. Issue #253 says "one row per card"; this is the reading of it that the shell supports (a card row names a printing), and the finish split is visible on the card page's "Your copies", where the name links. *Alternative:* one row per lot (a foil and a nonfoil are two rows), which matches Move copies' unit but makes a deck read like a ledger. *Alternative:* one row per card across printings, which hides which printing a proxy will later replace (#254, #257).
3. **Order.** Zones are in the format's registered order, so a deck that gained a zone later (spec 064: Commander to Modern adds Sideboard after Considering by id) still reads Main, Sideboard, Considering; a zone the format doesn't list, and every zone of a deck whose format the instance no longer registers, follows by id. This closes the open note in the area doc that `Deck#zones` orders by id (it matters "to #253"). Inside a zone the extension's groups come first, in the extension's order, and rows inside a group are by card name, then set code, then collector number as a person reads it (`Catalog::Entry::NUMBER_HAS_DIGITS_FIRST` and `NUMBER_VALUE`, then the number's text), then language. "Card name" is the name shown, the localized name for a non-English printing.
4. **Counts.** A card count is copies (quantity), as the Decks page counts them (spec 060 decision 12). With no proxies, owned and cards are the same number, so the page head reads "Modern · 58 cards · 58 owned" and a zone's head "12 cards · 12 owned", as the Decks page shows both columns (spec 062 AC-4.4); #254 adds "· N proxy" to the heads (this part of spec 060 decision 10 is superseded until then); the Proxy and Total columns exist now (decision 7). A group row's count is its copies. *Alternative:* drop "owned" until proxies exist; it would make #254 reword every head.
5. **The page's extension is a second optional answer of the collectible's vocabulary.** Beside `formats`, a vocabulary may answer what a deck page shows for a set of the account's entries in a deck of a format: for each entry its **group** (a name and a position among groups), its **cost** and its **legality** in that format. The deck's own collectible type's vocabulary answers for the entries of that type; an entry of another type, a type no longer registered, or a vocabulary that answers nothing gets a flat row, a muted dash in Cost and no marker (AC-6.1). Group and legality are data answers the core renders (a group name and position; nothing, or the word the core shows beside a cross with `c-legal--no`); the cost is drawn by the extension's own partial through `render_catalog_extension`, which receives only the extension record, as the card page draws the cost, because the pips are Magic's (`ManaCost`, spec 060 decision 21). The data come from the printing's own record, read once per collectible type (`Catalog::Entry.preload_extensions`). The exact method names and the partial are for the plan; the contract is written in the vocabulary's comment, which is its one home (`.claude/rules/code-documentation.md`).
6. **Magic's groups** (the maintainer's ruling of 2026-11-11) are the top-level types of the printing's first face, listed in this order: Creatures, Planeswalkers, Battles, Instants, Sorceries, Artifacts, Enchantments, Lands, then Other (a card with a type line that has none of those or no type data). A card is placed by its first face's type line, the part before the dash: if it has Creature it is in Creatures; otherwise, if it has Land it is in Lands; otherwise it is in the first group, in the list's order, whose type the line has. So an Artifact Creature is a Creature, a Land Creature (Dryad Arbor) is a Creature, an Artifact Land is in Lands, a Kindred Instant is an Instant. A multi-face card is placed by its first face: a Sorcery // Land is a Sorcery. The shape panel's own type counting is left to #256's spec (the issue design leaves "the type-grouping order" there), which may reuse this list.
7. **The columns are spec 060's, less the menu (the maintainer's ruling of 2026-11-11).** A zone table has Card, Cost, Owned, Proxy and Total, in spec 060's markup, classes and widths (`c-zone`, `c-zone__group`, the fixed layout from 640px of the table's container, with Cost 11rem, Owned 5rem, Proxy 7rem and Total 5rem), and **no menu column** (decision 9). Until #254 every Proxy cell is the muted dash and Total is the Owned number; #254 fills the Proxy cells and Total's sum, and adds the menu column, and so adds no column to the page and reworks none. Below 640px of the table's container the layout is spec 060 decision 9's: Owned and Proxy hidden, Card (with `SET · NUMBER` and any legality marker under the name), Cost and Total shown. This **does not supersede spec 060 decision 9 or AC-3.6**. Without the 4rem menu column, Card in the fixed layout takes the rest: 192px in a 640px container (it was 128px with the menu), where a name still wraps; the plan checks the remaining widths and the existing CSS needs no new rule for it. The menu cell, its header and the `.c-zone__c-menu` width are not rendered. `DeckPage.md` says the page has no menu column until #254.
8. **Legality** is read from the printing's stored legalities, which came with the catalog refresh; nothing is fetched. A format with no rules (Magic's Casual) shows no marker at all (spec 060 decision 8). For a format with rules, a card whose legality in it is anything but legal shows the card page's marker, a cross and its word ("Banned", "Restricted", "Not legal"); a card with no entry for the format is "Not legal", as the card page shows it. A deck whose format the instance no longer registers shows no marker but keeps its groups and costs. The marker is written twice, beside the name and in the line under it, and CSS shows one, as spec 060 AC-3.8 fixed.
9. **No row menu in 1.0 (the maintainer's ruling of 2026-11-11; supersedes spec 060 decision 17 and AC-3.10 and `DeckPage.md`'s row-menu paragraph until #254).** A card's copies are moved from the card page's "Your copies" table, which lists every lot of the card with its place and offers Move copies per lot, and the card name links there. A menu on the deck's row would have to name one of several lots (a foil and a nonfoil of one printing) and would still return to the card page and the collection after a move, not to the deck. #254 adds the menu column with its proxy items and decides how a row of several lots is offered. *Alternative:* a "Move copies" menu per row, one item per lot.
10. **The card page link is the name, in collection context and at its copies** (`/catalog/entries/:key?from=collection#copies`), the link the Decks refusal page uses.
11. **A card's cost is its printing's first face's cost,** as its type is its first face's, so a transform or modal double-faced card shows one cost, not two joined. A split card shows only its first half; that is a known limit of this page, and the shape panel's treatment of faces is #256's to decide.
12. **No ADR.** One more optional answer on a seam ADR 0028 created, with one deck-page home; the choices above are the spec's. If the review disagrees, the coordinator hands out the next number.

## User Stories

### Story 1: Open a deck

**As a** collector
**I want** to open a deck from the Decks page
**So that** I see what it holds.

**Acceptance criteria:**

- [ ] **AC-1.1** Given a signed-in collector with a deck When they open the deck's page Then the answer is 200, the title is "<deck name> · Collector", the page is a detail page with the Decks section current in the header and the tab bar and a back arrow to the Decks page on phones, and the head's h1 is the deck's name
- [ ] **AC-1.2** Given another account's deck, a place's id, a zone's id or an id no location has When its page is requested Then the answer is 404 and nothing of it is shown; a request that isn't signed in is sent to sign in as the other deck pages are
- [ ] **AC-1.3** Given a deck with copies in several zones, Considering included When its page is opened Then the head's muted line reads "<format name> · 58 cards · 58 owned" with the copies of every zone, and reads "1 card · 1 owned" for one copy and "0 cards · 0 owned" for none; for a format the instance no longer registers the line shows the stored format key, as the Decks page does
- [ ] **AC-1.4** Given a deck page When it is read Then the head's actions are "Edit deck" (a secondary button to the rename page) and a "…" menu with "Change format" (to the change-format page) and then, after a separator, "Remove deck" (last, danger, to the removal page, which is the confirmation, or the refusal when a zone holds a lot, as today); the three pages return to the Decks page when done, as they do today (decision 1)
- [ ] **AC-1.5** Given the Decks page When it lists decks Then each deck's name is a link to its page, a long name wraps as it does today, and the row's Rename, Change format and Remove buttons and its narrow line are unchanged
- [ ] **AC-1.6** Given a deck page When it is read Then it has no proxy control, no proxy count and no proxy tag, every Proxy cell is a muted dash, and it has no shape panel (neither the `aside` nor the "Deck shape" `details`)

### Story 2: Each zone's owned cards

**As a** collector
**I want** each zone's cards in a table with their cost and how many I own
**So that** I read the deck at a glance.

**Acceptance criteria:**

- [ ] **AC-2.1** Given a deck of three zones When its page is opened Then each zone is a section with an h2 of its name and the muted counts "12 cards · 12 owned", the sections stacked in the format's order (Main, Sideboard, Considering; Commander, Main, Considering for a Commander deck), a zone the format doesn't list or any zone of an unregistered format after them by id
- [ ] **AC-2.2** Given a deck changed from Commander to Modern, which added Sideboard after Considering by id When its page is opened Then the zones read Main, Sideboard, Considering
- [ ] **AC-2.3** Given a zone that holds lots When it is rendered Then it is a table whose columns are Card, Cost, Owned, Proxy and Total, in that order and with no other (no menu column), Proxy a muted dash and Total equal to Owned in every row, and the table's accessible name is the zone's name, given by its heading
- [ ] **AC-2.4** Given a zone that holds a foil lot and a nonfoil lot of one printing, and a lot of another printing of the same card When it is rendered Then the two printings are two rows, the first row's Owned is the two lots' quantities added, and no lot in another zone, in a place or in another account is counted
- [ ] **AC-2.5** Given a card row When it is rendered Then the Card cell holds the card's name (its localized name for a non-English printing), linked to its card page in the collection's context, and under it `SET · NUMBER` in the mono line, with `· LANG` after the number for a printing whose language isn't English
- [ ] **AC-2.6** Given a zone with cards of several types When it is rendered Then the rows are under full-width group rows, each with the group's name and the copies in it, in the extension's order, with no group row for a group without cards, and inside a group the rows are by card name, then set code, then collector number as a person reads it ("2" before "10"), then language
- [ ] **AC-2.7** Given an empty zone When it is rendered Then it has its head with "0 cards · 0 owned" and, in place of a table, "No cards in Sideboard yet." (the zone's own name) in a `surface-sunken` block
- [ ] **AC-2.8** Given a deck whose lots are in a zone of another deck of the same account When its page is opened Then those copies are not shown or counted
- [ ] **AC-2.9** Given a lot of a printing no longer in the upstream source (a retired entry) When its zone is rendered Then the row is shown like any other
- [ ] **AC-2.10** Given decks with few and with many zones, rows and lots When a page is rendered Then the page runs at most a fixed number of statements, the same whatever the number of zones, rows and lots (the deck, its zones, the zones' lots with their entries and sets in one read, and one read of the extension's data per collectible type), and no row triggers a query of its own

### Story 3: The legality marker

**As a** collector
**I want** a card that is not legal in my deck's format to be marked
**So that** I notice it before I play the deck.

**Acceptance criteria:**

- [ ] **AC-3.1** Given a Vintage deck with a card restricted in Vintage, a Modern deck with a card banned in Modern, and one not legal in it When their pages are rendered Then each such row shows a marker of a cross and its word ("Banned", "Restricted", "Not legal") in the muted ink, never red, and a card legal in Modern shows no marker
- [ ] **AC-3.2** Given a card whose stored legalities have no entry for the deck's format When its row is rendered Then it shows "Not legal", as the card page does
- [ ] **AC-3.3** Given a deck of a format with no rules (Casual) holding a card banned in Modern When its page is rendered Then no row has a marker
- [ ] **AC-3.4** Given a deck whose format the instance no longer registers When its page is rendered Then no row has a marker, the rows keep their groups and costs and the page otherwise renders
- [ ] **AC-3.5** Given a Standard deck with a card legal in Modern but not in Standard When the deck's format is changed to Modern Then the next view of the page shows no marker on it
- [ ] **AC-3.6** Given a card row with a marker When it is read in the markup Then the marker is written twice, beside the name and in the line under it, as spec 060 AC-3.8 fixes, and at most one is displayed at any width
- [ ] **AC-3.7** Given any page When it is rendered Then no request leaves the app to read a legality: it is read from the catalog's stored data

### Story 4: From a card to its copies

**As a** collector
**I want** a card's name to take me to its copies
**So that** I can move or change them where those actions are.

**Acceptance criteria:**

- [ ] **AC-4.1** Given a card row When its name is followed Then it opens the card's page in the collection's context at its "Your copies" section, the link the Decks refusal page uses
- [ ] **AC-4.2** Given a deck page When its markup is read Then it contains no `form`, no row menu, no link to a new copy, to number entry or to the scanner, and no drag target: the page adds no way of adding or moving copies

### Story 5: Layout at every width, in both themes

**As a** collector on a phone, a tablet or a desktop
**I want** the deck to fit my screen
**So that** I never scroll sideways.

**Acceptance criteria:**

- [ ] **AC-5.1** Given a deck page in a page container of 992px or wider When it is rendered Then the zones are the first column and keep its width, and the second column is empty, because the shape panel is not rendered
- [ ] **AC-5.2** Given three zone tables with different content in a table container of 640px or wider When they are rendered Then the Cost, Owned, Proxy and Total columns have the same left edge and width in every table
- [ ] **AC-5.3** Given a table container narrower than 640px When it is rendered Then Owned and Proxy are hidden and the columns shown are Card, Cost and Total, the line under the name carries `SET · NUMBER` and any legality marker, and the beside-the-name marker is hidden (spec 060 decision 9 and AC-3.6)
- [ ] **AC-5.4** Given the worst case at 360px (a 60-character name with no space, a six-symbol cost, a marker, a three-digit Total) When the page is rendered in either theme Then the page has no horizontal overflow and the Cost cell's scroll width is at most its client width
- [ ] **AC-5.5** Given a deck page at 360px, 640px, 768px and 1280px in the light and the dark theme When it is rendered Then it has no horizontal overflow, the zone heads' counts are uncut (own line below 640px, as spec 060 AC-3.7), and every colour comes from the design system's tokens
- [ ] **AC-5.6** Given the page head at 360px When it is rendered Then the actions wrap below the name and each touch target is at least 44px on a coarse pointer, and on a fine pointer at least the 36px that `c-btn` and links already have (`components.css`'s touch rule gives the 44px floor)
- [ ] **AC-5.7** Given a zone table When its markup is read Then each type group is its own `tbody` whose first row is a `th scope="rowgroup"` spanning the columns, so a group row is a row-group header

### Story 6: The collectible's part is the extension's

**As an** agent adding another collectible
**I want** the deck page's collectible part behind the vocabulary
**So that** a second collectible needs no change in the page.

**Acceptance criteria:**

- [ ] **AC-6.1** Given a deck of a collectible whose vocabulary answers nothing for the page When its page is rendered Then each zone is one table with no group rows, Cost shows a muted dash and no card has a marker
- [ ] **AC-6.2** Given the deck page's core files (`app/models/deck/page.rb`, `app/views/decks/show.html.erb` and its partials, and any new helper; the existing globs match the first two) When `spec/deck_core_spec.rb` reads them Then none names a game, a source, a format or a zone but `considering`, comments included, and the guard's list names every new file the globs don't match and its count is 26 plus the new files
- [ ] **AC-6.3** Given Magic's extension When a printing's first face has the type line "Legendary Creature — Elf Druid", "Artifact Creature — Golem", "Basic Land — Forest", "Artifact Land", "Land Creature — Forest Dryad" (Dryad Arbor), "Kindred Instant — Elf", "Instant" (the first face of an "Instant // Instant" split card), "Sorcery" (the first face of a "Sorcery // Land" modal double-faced card), "Legendary Planeswalker — Jace", "Battle — Siege" and "Conspiracy", or has no face data Then they are in Creatures, Creatures, Lands, Lands, Creatures, Instants, Instants, Sorceries, Planeswalkers, Battles and Other, and the groups are listed in the order of decision 6, with Land placed after Creature and before the other types
- [ ] **AC-6.4** Given Magic's extension When a printing's first face has the cost "{3}{G}{G}", or the cost "{1}{U}" with a second face of cost "{2}{G}", or no cost Then Cost shows the pips of "{3}{G}{G}", of "{1}{U}" only, and a muted dash
- [ ] **AC-6.6** Given Magic's extension and a printing with no extension record or no face data When its row is rendered Then it is in Other with a muted dash for its cost and no marker, and the page otherwise renders
- [ ] **AC-6.5** Given Magic's extension and a deck of each of its formats When the legality of a card is read Then the deck formats it registers that have stored legality (Standard, Pioneer, Modern, Legacy, Vintage, Pauper, Commander) read their own key and Casual reads none

## Functional Requirements

### FR-1: The deck page

`GET /decks/:id` for a deck of the signed-in account, in the design system's `DeckPage` shell: the detail header, the page head of decision 4 and Story 1, the zones in one column of `c-deck__zones`, and no panel.

**Must:** read only the account's data through `Current.account`; answer 404 for anything that is not a deck of it; link every card to its card page in the collection's context at its copies; render with no network access.
**Must not:** write anything; add a route other than `show`; name a collectible, format or zone but `considering` in a core file.

### FR-2: Zone tables

One table per zone that holds lots, one row per printing (decision 2), grouped, ordered and counted as decisions 3, 4 and 6 say, in the shell's markup and classes, with the columns of decision 7 (Card, Cost, Owned, Proxy, Total).

**Must:** keep the zone's name as the table's accessible name (`aria-labelledby` its heading) and each group its own `tbody`; show an empty zone's sentence; read the zones' lots in a bounded number of statements; leave #254 only cells to fill and the menu column to add (the Proxy and Total columns, their classes and widths exist, spec 060 decision 25).
**Must not:** merge lots of different printings; count a lot of another zone or account; add a row menu or a menu column (decision 9), or show a proxy count in the Proxy cell.

### FR-3: The extension's contribution

A vocabulary may answer the deck page's part (decision 5). Magic's answers groups (decision 6), cost (decision 11) and legality (decision 8), read from the printing's first face and stored legalities. The core's rows work with any answer or none.

**Must:** put the contract in the vocabulary's comment; give a collectible that answers nothing a flat table with a dash and no marker.
**Must not:** put Magic's type names, its legality words or its cost drawing in core code; fetch anything to answer.

### FR-4: Links from the Decks page

The deck's name on the Decks page links to its page (AC-1.5).

**Must:** keep spec 062's other Decks page behavior.

## Non-Functional Requirements

### Performance

- The page runs at most a fixed number of statements however many zones, rows and lots the deck has (AC-2.10): the deck and its zones, the lots with their entries grouped by zone and printing, and each collectible's extension data in one read per type, never one per row.
- A zone with thousands of rows renders them all, with no paging (Non-Goals); at the sizes a deck has (up to a few hundred printings) a page is one request and a few dozen kilobytes.

### Security

- Every read is through the signed-in account; another account's deck is a 404 (AC-1.2, a request spec). No request parameter names an account, a zone or a kind. Output is escaped (no `html_safe` on a card or deck name).
- The signed-out visitor is sent to sign in; the page is not part of the open catalog.

### Reliability and the hosted door

- The page reads existing tables and adds none: no storage, no background work, no change to the export format, the import or the backup (hosted-door rule "bounded cost per account"). It renders for a deck whose format or collectible type the instance no longer registers (the extension's answer is asked only for a registered type), and for a printing whose extension data is missing (the row has a dash and no marker, in Other).

### Accessibility

- Each table is named by its zone's heading; group rows are row-group headers (one `tbody` per group); the cost keeps its `aria-label`; the marker is a word with an icon, never a colour alone; every control is at least 44px on phones; the head's actions wrap on a phone as the card page's do.

### Design system and documentation

- Uses only token variables and `c-*` classes (`collector/`), adding to `collector/additions.css` only what the table without its menu column needs (the plan finds none unless a rule assumes the menu cell); `DeckPage.md` and `DecksIndex.md` are updated in the same change. The area doc `collection-and-lots.md` (the Decks pages, the zone order note, the extension seam) and `CLAUDE.md`'s deck sentence change in the same PR (`.claude/rules/documentation.md`).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A deck of another account, a place's id, a zone's id, an id no location has, an id with letters | 404 (AC-1.2) |
| Signed out | Sent to sign in, as the other deck pages do |
| A deck removed in another tab, then its page reloaded | 404; nothing else changes |
| A lot moved or removed in another tab | The page shows the lots as they are at the request |
| A zone the format doesn't list (a dropped zone left by an import repair) or a deck of an unregistered format | The zone follows the registered ones by id; no marker; the stored format key in the head |
| A printing whose extension data is missing | The row is in the "Other" group of its collectible, with a dash for its cost and no marker |
| A collectible with no deck page answer | A flat table, a dash, no marker (AC-6.1) |
| A 60-character name with no space, a six-symbol cost | Wraps inside its cell; no overflow at 360px (AC-5.4) |

## Open Questions

None. Decisions 2, 6, 7 and 9 are ruled (Gate A, 2026-11-11); the others are reviewed and stand.

## Out of Scope (Future Considerations)

- Proxies, the content of the Proxy and Total cells, the menu column, "Add a proxy", "Use my copy" ([#254](https://github.com/plainprogrammer/Collector/issues/254), [#257](https://github.com/plainprogrammer/Collector/issues/257)).
- The shape panel in the right column ([#256](https://github.com/plainprogrammer/Collector/issues/256)).
- Add to deck from the card page ([#255](https://github.com/plainprogrammer/Collector/issues/255)); Free to use and In decks ([#50](https://github.com/plainprogrammer/Collector/issues/50)).
- Deck checks: size, copy limits ([#258](https://github.com/plainprogrammer/Collector/issues/258), 2.0); a deck-builder workflow ([#260](https://github.com/plainprogrammer/Collector/issues/260), 2.0).
- The row menu and a way back to the deck after Move copies (#254 adds the menu); a sorting or filtering control in a zone; a paged zone.

## Supersedes and updates

- **Supersedes** spec 062 decision 5's "the deck's name is plain text until the deck page of #253": the name is a link (decision 1). Its other statements, the three row buttons, stand.
- **Closes** the area doc's open note that `Deck#zones` is ordered by id and shows a later-added zone last: the page lists zones in the format's order (decision 3). `Deck#zones` itself does not change; the page orders what it reads.
- **Supersedes, until #254,** spec 060 decision 17 and AC-3.10 (the row menu; decision 9), the menu parts of decision 25, AC-3.5 and AC-3.11 (no menu column; decision 7), the part of decision 10 that fixes the "· N proxy" counts and "Add a proxy" (decision 4), and the parts of AC-3.7 and AC-3.9 that name "Add a proxy" and the proxy counts. **Does not supersede** spec 060 decision 9 or AC-3.6 (the phone's columns), or the Proxy and Total columns of decision 25 and AC-3.5 (decision 7). `DeckPage.md` says which controls exist before proxies; spec 060's rules for the full page stand for #254. Recorded in the specs index in both directions.
- **Rewords** the area doc's statement that spec 062 decision 5 keeps the deck's name plain text until #253 (decision 1).

## Documents and Files Changed

Listed so the plan can name them; the plan decides the code.

- `docs/design-system/components/DeckPage.md`, `DecksIndex.md`, and `collector/additions.css` only where the table without its menu column needs it.
- `docs/architecture/collection-and-lots.md` (the deck page, the zone order, the extension seam, named constants if any), `docs/architecture/tenancy-and-accounts.md` (the deck page route's 404 cases), `CLAUDE.md`'s deck sentence, `docs/specs/README.md` (this spec's row and the supersession), `spec/deck_core_spec.rb` (the new core files and the count).
- New: the deck page's controller action, route, view, a plain Ruby page model, the vocabulary's optional answer and its contract, Magic's answer and partial, helpers, and their specs (request, model, system).

## Verification

Written at plan time into `verification.md`: each AC with the spec that proves it; the system specs (headless Firefox) measure overflow at 360px, 640px, 768px and 1280px in both themes; the review's screenshots of the page at 360px and 1280px, light and dark, are kept with the spec.
