# Feature 073: "Free to use" and "In decks" on the Card Page

**Status:** Approved
**Version:** 0.2.3
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 057](../057-deck-design-rules/spec.md) (the words, the three-stat strip and the "In decks" table, decisions 7 and 8; merged), [spec 062](../062-create-rename-remove-a-deck/spec.md) (decks, zones; merged), [spec 068](../068-deck-proxies/spec.md) (proxies; merged), [spec 070](../070-replace-proxy-with-copy/spec.md) (`Lot.free`; merged), [spec 071](../071-add-to-deck-from-card-page/spec.md) (`Lot::FreeCopies`, "where #50's stats sit", decision 1; merged)
**Branch:** `073-card-page-deck-stats`
**Issue:** [#50](https://github.com/plainprogrammer/Collector/issues/50)
**ADR:** none: no data, no schema and no new pattern; what is decided here (the card as the scope, free as the one existing definition, how a count reads) is this spec's (decisions 1 to 6)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.3 | 2026-11-11 | From plan review round 2, no change of scope: `spec/requests/zone_place_label_spec.rb` line 27 (spec 062 AC-5.4: no "Main" outside a label on the card page) now sees the Zone column of "In decks" and is scoped off that section (Supersedes and updates); "Your copies"' place class applies to placed lots only, so "No location" stays on one line |
| 0.2.2 | 2026-11-11 | From plan review round 1, no change of scope: "Your copies"' Location cell takes the existing `c-table__place` class so a 60-character zone label doesn't scroll the page at 1280px (decision 10, AC-5.2); the empty state's second "Add to deck" link makes two existing no-script system examples ambiguous (`spec/system/deck_additions_spec.rb` lines 152 and 168: Supersedes and updates); AC-6.1 states which document carries which sentence |
| 0.2.1 | 2026-11-11 | Clarified from plan writing, no change of scope: AC-5.2's sub-line reads "Modern · Main" (the format first), as the preview and spec 057 draw it |
| 0.2.0 | 2026-11-11 | Approved at Gate A (the coordinator, under the maintainer's delegation), rulings of decisions 5 and 6 stand; from spec review round 1 (0 blocking, 4 major): the fold follows the section's width, not the device (decision 4, AC-5.2); one new wrap rule is needed (decision 10, AC-5.3); AC-5.1's numbers satisfy Owned = In decks + Free to use and the 9,999 cap; AC-3.3's two runs have the same shape; the supersession list gains `query_counts_spec.rb`, spec 057's two lines and 070's, 071's Out of Scope and the stale comments and docs; the head count's deck-only-proxy case, singular and delimiter cases, a renamed deck and the core-guard list are written out |
| 0.1.0 | 2026-11-11 | First draft from issue #50, specs 057, 062, 068, 070 and 071, the area docs `collection-and-lots.md` and `catalog-core.md`, `ItemPage.md` and a grep of `spec/`, `docs/` and `app/` for the strings the earlier specs fixed (named in `verification.md`) |

---

## Problem Statement

A collector who opens a card they own can't tell, from the card, how many of their copies are free to put in a deck and which decks already hold the rest. They would open the decks one by one, or the collection filtered by a deck, and add it up. The card page shows "Owned" and "Your copies" (where a copy in a deck is a place, "Izzet Tempo › Main"), and its head has "Add to deck" (spec 071), but it never answers "how many can I still use?". Spec 057 drew the answer, three stats and an "In decks" table; spec 004 left them out until decks existed, and decks, proxies, "Use my copy" and "Add to deck" now do.

This spec adds the stats strip's "In decks" and "Free to use" and the "In decks" section to the card page for a signed-in collector, reading the definition of "free" that specs 070 and 071 already own.

> **Terms.** *Deck, zone, Considering, proxy, "Deck › Zone", Free to use* are as in [`collection-and-lots.md`](../../architecture/collection-and-lots.md), spec 057 and the design system's README (Decks section): **Free to use** is the copies the collector owns minus the copies in any deck zone, Considering included; a proxy never counts as owned. A **card** is the gameplay identity its printings share (`Catalog::Identity`); the **shown printing** is the card page's own entry. **Owned** is the card page's own count of every printing of the card.

## Goals

- The card page's stats strip shows **Owned, In decks and Free to use**, for the card as a whole.
- A section **"In decks"** after "Printings" lists each deck zone that holds a copy or a proxy of the card: Deck (and format), Zone, Owned, Proxy.
- "Free" is the one definition that exists (`Lot.free`, through `Lot::FreeCopies`); the page writes no second one.
- The page reads a bounded number of statements however many lots, decks and zones the account has, and shows nothing of another account's.

## Non-Goals

- **"Est. value"** waits for prices; the strip is the three-stat one ([spec 057](../057-deck-design-rules/spec.md) decision 7) until it returns.
- **Any new action:** "Add to deck" (spec 071), "Move copies" and "Use my copy" (spec 070) are where they are. The section's rows link to the deck; they offer no menu.
- **A proxy tag in the table:** the card page keeps the plain Proxy count and the dash (spec 057 decision 8, `ProxyTag.md`).
- **The Collection grid and table, the Printings list and the printings page:** their "owned" counts are untouched.
- **Totals, a per-printing split or a sort control for the table.**
- **A change to the export, the import, the schema or any table.** Nothing here is collector-owned data: both counts are read from lots and proxies the export already carries (decision 8).
- **A rewrite of `SingleStat`:** the pattern stays in the design system for a page with one stat; the card page just stops using it.

## Users and Context

**Primary users:** a collector with a card open, at a desk or at the table, on a laptop or a phone, who is building a deck.
**Usage context:** "I own three Lightning Bolts. Are any free for my new deck? Where are the other ones?"
**User mental model:** what I own, minus what is in decks, is what is free; a stand-in (proxy) isn't a card I own.

## Decisions

1. **The scope is the card, every printing, for the signed-in account.** The strip's Owned already is (spec 004 AC-8.4); In decks, Free to use and the table take the same lots and the proxies of every printing of the card (a retired printing's lots and proxies included, as Owned counts them). A visitor on an open catalog has none of this and none of it is read (spec 023 FR-3, decision 5).
2. **"Free" is `Lot.free` read through `Lot::FreeCopies`, and "in decks" is its complement; no second predicate is written.** Free to use is `Lot::FreeCopies#total` for the account and the shown printing (spec 071 FR-2 named this page its reuse: "reusable by #50"); the card's lots that are not among `Lot::FreeCopies#lots` are the lots in a deck zone, and In decks is their quantity. The two always sum to Owned, since a lot is whole in one place and each lot is free or not as a whole (spec 071 decision 4). Nothing on the page tests a location's kind to decide "in a deck". Considering is a zone, so its copies are in decks and not free (spec 057 FR-3). A proxy is never a lot and changes none of the three numbers.
3. **The strip has three stats, in this order, three across at every width:** Owned (as today: the count, "N printings"), In decks (the count, "in N decks", N the decks that hold at least one owned copy of the card, so a deck with only a proxy of it is not counted: "in 0 decks" when none) and Free to use (the count, "not in a deck"); `c-stats c-stats--three` (spec 057 decision 7). It replaces today's single stat for a collector; counts use `number_with_delimiter`. The three numbers are shown in every state, "0" included.
4. **"In decks" is a full-width section after "Printings", before "Format legality," in `CollectionTable`'s pattern** (`c-table` in `.c-collection`; spec 057 decision 8). One row per zone that holds at least one owned copy or one proxy of the card: columns **Deck** (its name, a link to `/decks/:id`, the format's name muted beside it), **Zone** (the zone's own name, "Main", "Considering"), **Owned** (the copies of the card in that zone, every printing, finish and condition) and **Proxy** (the proxies of the card in that zone, every printing and finish; a muted dash for none; no tag). Rows are in the order the pickers use: decks by name (`Deck.listing_order`), then a deck's zones in the deck's own order (`Deck#zones`). A zone with a proxy of the card and no copy has a row with Owned "0". When the section is narrower than 640px (a phone, but also a laptop window whose page column is narrow: the table's own container query, the same as the other tables') Zone folds under the deck name with the format (`c-table__sub`), and Owned and Proxy stay. Considering is a row like any zone.
5. **The section's head and empty state.** The count beside "In decks" is "4 copies in 2 decks" when copies are in decks (the preview's words), then " · 2 proxy" when proxies are (as the deck pages say it: "proxy" has no plural, spec 068 decision 7); with proxies only it is "2 proxy"; with neither it has no count. With neither a copy nor a proxy in any deck the body is the sentence "This card isn't in any of your decks." and, when the printing can be added to a deck (`Catalog::Entry#deck_addable?`), the link "Add to deck" (the card page's own, carrying the collection mark), as "Your copies" has "Add a copy" when empty. The section is drawn for every signed-in collector, with or without decks.
6. **The Proxy column counts proxies of the card, any printing.** A proxy is a stand-in for a card in a zone (spec 068), and the stats and the table answer "where is this card used". The alternative, the shown printing's proxies only, would show a different table from each of the card's printings. Ruled by this spec, flagged for the maintainer at Gate A.
7. **Every render of the card page has the new parts.** The reads hang off the page's `Catalog::CardOverview`, which the page and quick add's no-script over-cap re-render (spec 023 AC-6.2) both build, so neither can lack them. A visitor's overview reads nothing.
8. **No data model change, no migration, no ADR, no export change.** Nothing is written. Export format version 4 and its Coverage tables are unchanged, so the spec writes nothing under `docs/export-format/`.
9. **The code stays collectible-agnostic, and the guard is extended to it.** The new files (the query object, the section's partial), `Catalog::CardOverview` and the card page's new lines name no collectible, format or zone key but `considering`; the format's name comes from `Deck#format_name`. The new files and `card_overview.rb` join `spec/deck_core_spec.rb`'s list explicitly (its globs don't reach `app/views/catalog/entries/`), and the section's head-count helper goes in `decks_helper.rb`, already covered, not `catalog_helper.rb` (whose comments name a game).
10. **One rule of CSS is new: a deck's name wraps in the section.** `c-stats--three`, `CollectionTable`, `c-table__sub`, `is-opt`, `is-num` and the muted dash exist (spec 057, 062, 066), but the table's cells are `white-space:nowrap` and the only rule that lets a deck's name wrap is scoped to the Decks pages (`.c-decks td:first-child`), so a deck name of 60 characters with no space would scroll the card page sideways. The new rule is `#in-decks td:first-child { white-space:normal; overflow-wrap:anywhere; }` (the section carries the id, as `#copies` and `#printings` do), under its own `(spec 073)` heading in `collector/additions.css`; it doesn't touch "Your copies". It uses no token, so it has no colour to check. The page has a second long-name defect with a known answer: "Your copies"' Location cell (`td.is-data.is-opt`) is nowrap and holds the lot's label "Deck › Zone", about 550px for a 60-character deck name, so at laptop widths the page scrolls sideways before "In decks" is a factor; that cell, for a placed lot, takes the existing `c-table__place` class and `c-table__place-name` span (spec 048's rule, in `additions.css`), which is markup, not CSS; an unplaced lot's "No location" stays on one line. A "before" (the rule removed) and an "after" are kept in the screenshots. If an example finds another defect, it is fixed the same way.

## User Stories

### Story 1: The strip says what is free

**As a** collector looking at a card I own
**I want** to see how many copies are in decks and how many are free
**So that** I know how many I can still put in a deck.

**Acceptance criteria:**

- [ ] **AC-1.1** Given a signed-in collector with 3 copies of a card, none in a deck When the card page renders Then its stats strip is `c-stats c-stats--three` (no `c-stats--single`) with three stats in order: "Owned" 3 with "1 printing", "In decks" 0 with "in 0 decks", "Free to use" 3 with "not in a deck"
- [ ] **AC-1.2** Given 7 copies of a card across two printings: 2 in a zone of deck A, 1 in Considering of deck B, 3 in a place, 1 with no location When the card page renders Then Owned is 7, In decks is 3 with "in 2 decks" and Free to use is 4; and given lots of 9,999 copies each, 12,345 of them in deck zones and 12,345 free (Owned 24,690) Then each stat is written with its delimiter ("24,690", "12,345", "12,345")
- [ ] **AC-1.3** Given every copy of the card in deck zones When the card page renders Then In decks equals Owned and Free to use is 0
- [ ] **AC-1.4** Given a card with 2 owned copies, 1 of them in a deck zone, and no proxy When a proxy of the card is added to a zone of that deck (and then another to a zone of a second deck) and the page is read again Then the three numbers and the small lines are as they were (a proxy never counts; the example reads the strip before and after each add); and given a card with no owned copy and a proxy of it in a deck zone Then Owned, In decks and Free to use are 0, "0 printings", "in 0 decks"; and given exactly one deck holding a copy Then the small line reads "in 1 deck"
- [ ] **AC-1.5** Given the lots of a card in a zone, a place and none, and another card's lots in a zone When the strip is read Then In decks and Free to use are the card's own numbers as the fixture sets them (written out in the example, not derived from each other), and the example also reads `Lot::FreeCopies#total` for the same account and printing and expects it equal to Free to use (so the page and the definition can't drift)
- [ ] **AC-1.6** Given another account's lots and proxies of the same card in its own deck zones When the owner's page is read Then none of them is counted in any of the three, and the other account's own page, read with the same card, shows its own numbers (a positive control built at run time, both records from one account each)

### Story 2: The "In decks" section says where

**As a** collector
**I want** a list of the decks and zones that use a card
**So that** I can find the rest of my copies and the cards I'm borrowing.

**Acceptance criteria:**

- [ ] **AC-2.1** Given copies of the card in zones of two decks When the card page renders Then a section "In decks" follows "Printings" and precedes "Format legality", holding a `c-table` in `.c-collection` whose headers are Deck, Zone, Owned and Proxy, with one row per zone that holds a copy, decks by name then a deck's zones in the deck's order, each Deck cell a link to that deck's page with the format's name beside it and each Zone cell the zone's own name
- [ ] **AC-2.2** Given lots of two printings, two finishes and two conditions of the card in one zone, and proxies of two printings in the same zone When the table is read Then that zone has one row whose Owned is the lots' quantities summed and whose Proxy is the proxies' quantities summed
- [ ] **AC-2.3** Given a copy in Considering When the table is read Then it has a row for Considering with that copy; and the table's Owned column sums to the strip's In decks (the example checks it for a mix of printings, zones and decks), with its Owned and Proxy cells written with their delimiters (two lots of 9,999 in one zone read "19,998")
- [ ] **AC-2.4** Given a zone with a proxy of the card and no copy When the table is read Then it has a row with Owned "0" and the proxy count in the Proxy cell, as plain text and with no `c-proxy` tag; and given a zone with a copy and no proxy Then its Proxy cell is a muted dash
- [ ] **AC-2.5** Given a deck whose format its collectible's extension no longer registers When the table is read Then the Deck cell shows the format's key in the format's place, as the deck pages do, and the page is 200
- [ ] **AC-2.6** Given the section's head When the card has copies in 2 decks, 4 in all, and 2 proxies Then the count reads "4 copies in 2 decks · 2 proxy"; with copies only, "1 copy in 1 deck"; with proxies only, "2 proxy"; with neither, no count; and given copies in deck A and a proxy only in deck B Then it reads "1 copy in 1 deck · 1 proxy" (a deck with only a proxy is not a deck in the count)
- [ ] **AC-2.7** Given a card with a printing that can be added to a deck, in no deck When the section renders Then its body is "This card isn't in any of your decks." with an "Add to deck" link to the card's deck-addition page carrying the collection mark when the page has it; given a retired printing Then the sentence has no link; and given a signed-in account with no decks at all Then the section is drawn the same way
- [ ] **AC-2.8** Given a lot or a proxy of a printing that is retired When the page for another printing of the card is read Then it is counted in the strip and the table as the others are
- [ ] **AC-2.9** Given another account's deck, zone, lot or proxy of the card When the owner's page is read Then the owner's response shows none of its numbers or its deck's name (the name built at run time and shown on the other account's own page, a positive control)
- [ ] **AC-2.10** Given a deck renamed after copies were put in it When the page is read Then the table shows the new name (names are read at the request, not stored on the row)

### Story 3: Where the parts are and where they are not

**As a** collector or a visitor
**I want** the parts only a collector has to stay with a collector, on every page that renders the card
**So that** a visitor learns nothing about a collection.

**Acceptance criteria:**

- [ ] **AC-3.1** Given an open catalog and a visitor When the card page renders Then it has no stats strip, no "In decks" section or text, no "Free to use", and runs no statement against `lots`, `locations`, `decks` or `deck_proxies` (an existing count-by-table example gains the new tables, with a positive control: the same page for a collector reads `lots`)
- [ ] **AC-3.2** Given a collector whose quick add is refused because the lot is full, without scripting When the card page is re-rendered with 422 Then it shows the three stats and the "In decks" section with the same numbers a plain visit shows
- [ ] **AC-3.3** Given the page's reads When the number of statements is counted for an account with the same shape of data at two sizes, each with a free lot, a lot in a zone and a proxy, on printings other than the shown one (so every preload has records to load and the request's query cache hides none), the small one with 1 deck of 1 zone in use and the large one with 40 lots across several printings and places and 10 decks of 3 zones with proxies, the page warmed once before each count Then the two counts are equal, with no number written in the example; the example removes one preload to see that it can fail (spec 070's lesson). `spec/requests/query_counts_spec.rb`'s card-page examples (lines 58, 97, 110 to 122) are re-measured with the new reads and their allowance and comment ("a place's plus one") rewritten to what is true
- [ ] **AC-3.4** Given a request for the card page When it is handled Then no row of `lots`, `locations`, `decks` or `deck_proxies` changes (the session's daily `last_used_at` stamp is not one of them)

### Story 4: From the card to the deck

**As a** collector
**I want** to open a deck from the card
**So that** I can see the rest of it.

**Acceptance criteria:**

- [ ] **AC-4.1** Given a collector with a copy in a deck's zone When they open the card page, follow the deck's name in "In decks" and read the deck page Then the deck page is that deck's and its zone lists the card; the example runs the path without scripting (`rack_test`, declared before the `let!` that signs in: spec 067's lesson) from the card page to the deck page, and the "In decks" text does not appear on the deck page

### Story 5: The parts follow the design system on any device

**As a** collector on a phone or a laptop, in either theme
**I want** the strip and the table to read and fit like the rest of the page
**So that** nothing is clipped or hidden.

**Acceptance criteria:**

- [ ] **AC-5.1** Given the card page at 360px and 390px (a narrow frame), light and dark, with Owned 24,690, In decks 12,345 and Free to use 12,345 (lots of 9,999 or fewer) When it renders Then the three stats are in one row of three, no label or number is clipped, and there is no horizontal overflow
- [ ] **AC-5.2** Given the table in a section narrower than 640px (the 360px and 390px frames, a 640px window, whose page column is 576px, and a 1024px window, whose body column is about 628px), light and dark, with a deck name of 60 characters with no space in one row When it renders Then Zone is not a column, Zone and the format are in the name cell's sub-line ("Modern · Main", the format first, as `ItemPage.html` draws it), Owned and Proxy are visible, the name wraps inside its cell and there is no horizontal overflow; and in a section 640px or wider (the example reads the section's width at 1280px) all four columns are visible with the format beside the name; in every one of these the page as a whole has no horizontal overflow, which includes "Your copies" with a lot in that deck's zone
- [ ] **AC-5.3** Given the section When its markup is read Then it uses only `c-*` classes and token variables, no inline style and no new class (the one new rule, decision 10, is scoped by the section's id and sits in `additions.css` under its own heading); the section's heading is an `h2` with `c-section__title` and the table is named by it; a number cell has `is-num`; the dash is `is-muted`
- [ ] **AC-5.4** Given every control the change adds When each is listed Then each is covered: the deck name link in the table is a text link in a cell, as the collection table's name link is, and is exempt as spec 062's table links are; the empty state's "Add to deck" is a link inside a sentence, exempt as "Add a copy" is in "Your copies"; no button, select or field is added, so no floor rule is needed (spec 068's lesson: the list is written out; headless Firefox can't emulate a coarse pointer)

### Story 6: The documents say it

**As a** later maintainer
**I want** the rules in the area docs and the design system
**So that** the next feature reads them, not the code.

**Acceptance criteria** (verified by reading, recorded in `verification.md`; `.claude/rules/testing.md`):

- [ ] **AC-6.1** `ItemPage.md` states the section's head count, its empty state, that Zone and the format fold when the section is narrower than 640px, that the Proxy column counts any printing of the card, the name's wrap rule, "Your copies"' place class and that the strip is the three-stat one; `ItemPagePhone.md` states the fold, the folded cell's order ("Modern · Main") and the name's wrap; `previews/ItemPage.html` and `ItemPagePhone.html` draw the head count; `SingleStat.md` (lines 3 and 15) and the README's "What is live" line (99) say the card page no longer uses the single stat
- [ ] **AC-6.2** `collection-and-lots.md` states the card page's stats and section, the one definition of free, the card as the scope and the constants; its open-issues line for #50 and the sentence in "A deck" that says "Free to use is not built" are updated; `catalog-core.md`'s open-issues line for #50, its card page list (line 88) and its Issues line 221 are updated and gain pointers to it; `collection-and-lots.md`'s scope bullet for `Lot::FreeCopies` (line 19) and its Sources line for #50 (line 353) say the card page reads it too; `CLAUDE.md`'s deck sentence names the stats and section; the roadmap's item 15 and the specs index are marked
- [ ] **AC-6.3** Every supersession in "Supersedes and updates" is recorded in `docs/specs/README.md` in both directions

## Functional Requirements

### FR-1: Reading the card's decks

The card page's overview reads, for the signed-in account and the shown printing's card, the free lots (`Lot::FreeCopies`), the card's other lots, the proxies of the card and the decks and zones they sit in. **Must:** be tenant-scoped through the account; leave a visitor's overview with nothing read; count every printing, retired ones included; take free from `Lot.free` only; leave proxies out of every count of owned copies; read a bounded number of statements. **Must not:** test a location's kind to decide "in a deck"; write; name a collectible, a format or a zone key but `considering`.

### FR-2: The strip

Three stats, decision 3, for a collector; none for a visitor. **Must:** show Owned, In decks and Free to use together and always; keep Owned as it was. **Must not:** show a stat for a proxy or "Est. value".

### FR-3: The section

The "In decks" section, decisions 4 and 5, for a collector, after "Printings" and before the legality section. **Must:** list a zone for a copy or a proxy of the card; sum across printings, finishes and conditions; link each deck to its page; draw the sentence for a card in no deck. **Must not:** show a row for a zone with neither; show another account's anything; show a menu, a button or a proxy tag.

## Non-Functional Requirements

### Performance

- A constant number of statements however many lots, printings, decks, zones or proxies there are (AC-3.3); no per-row query.

### Security

- Every read goes through `Current.account` (the overview's account); another account's lots, zones, decks and proxies are absent. No parameter is added. Output is escaped (a deck name is the collector's own text).

### Reliability

- The page answers 200 for a card with a deck whose format is no longer registered (AC-2.5) and for a card whose lots are in a deck that has been renamed (names are read, not cached).

### Accessibility

- The table is named by its section heading; headers are `th`; no colour carries meaning alone (the dash is text); the deck link is a real link with the focus ring of the app.

### Design system and documentation

- Token variables and `c-*` classes only; the design-system docs and previews change with the text (AC-6.1); the area docs and `CLAUDE.md` change in the same PR.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The card is in no deck | Strip: In decks 0, Free to use = Owned; section: the sentence (with "Add to deck" when the printing can be added) |
| A copy is in Considering | Counted as in the deck, not free; a Considering row |
| Only a proxy of the card is in a deck | Strip counts 0 in decks; the zone has a row with Owned 0 and the proxy count |
| A deck's format is no longer registered | The format's key is shown; 200 |
| Another account has lots, decks or proxies of the card | Not counted, not shown |
| A visitor on an open catalog | No stats, no section, no read of lots or decks |
| Quick add refused (lot full), no scripting | The card page at 422 with the three stats and the section |
| A zone is removed | A zone that holds a lot can't be removed (spec 062); a zone with only proxies goes with its deck, so its row is gone |

## Open Questions

None. Decision 6 (the Proxy column counts any printing of the card) and decision 5 (the empty state's "Add to deck" link) are this spec's rulings, flagged for the maintainer at Gate A.

## Out of Scope (Future Considerations)

- "Est. value" with prices; a per-printing breakdown or a sort of the table; opening a deck at a zone's anchor; "Move copies" from the section.

## Supersedes and updates

Written from a grep of `spec/`, `docs/` and `app/` for `Free to use`, `In decks`, `c-stats--single`, `c-stat`, `<dt>Owned`, `#50`, `Owned stat`, `one stat` and `Show one stat` (the grep is named in `verification.md`).

- **Supersedes** spec 004 FR-9's "Leave out the 'In decks' and 'Free to use' stats… the 'In decks' section" and "Show one stat, 'Owned'… not laid out 2 × 2 until more stats exist", its Non-Goal "…the card page has no 'In decks' or 'Free to use' stats and no 'In decks' section" (line 47) and Out of Scope entry for "Free to use" (line 545), and AC-8.1's order in part: after "Printings" the page has "In decks" (spec 057 decision 8's order). AC-8.4's Owned stat is unchanged (a collector's page now shows it beside two more).
- **Updates** `spec/requests/zone_place_label_spec.rb` line 27 (spec 062 AC-5.4, decision 6: a zone is never shown by its name alone): the card page's `expect(without_label).not_to include("Main")` now finds the Zone column of "In decks", where the zone's name stands in its own cell beside the deck's link, so the example removes that section before it checks the rest of the page.
- **Updates** `spec/system/deck_additions_spec.rb` lines 152 and 168 (spec 071 AC-5.5's no-script examples): a card in no deck now has two links named "Add to deck", the head's and the empty state's, so each click is scoped to `.c-item__actions` (the head's link is what they exercise); `app/views/catalog/entries/_copies.html.erb`'s Location cell gains spec 048's `c-table__place` class (decision 10).
- **Updates** `spec/requests/query_counts_spec.rb` lines 58, 97 and 110 to 122 (the card page's statement counts; AC-3.3), and `additions.css` line 165's heading ("Card page: … single stat") and line 176, whose comments say the card page uses `c-stats--single`: no view does after this spec; the class and `SingleStat.md` stay for a page with one stat. `spec/system/design_system_deck_rules_spec.rb` (lines 105, 155) builds its own probe markup and needs no change.
- **Supersedes** spec 071 AC-1.4 (the strip is the single Owned stat and the page has no "Free to use" or "In decks") and its Non-Goal (line 47) and Out of Scope (line 241) entries: fulfilled; decision 1's "#50 … sits in the stats strip … the 'In decks' table sits after 'Printings'" is carried out as written, not superseded. `spec/requests/catalog/entries_show_spec.rb` ("leaves the stats strip and the sections as they are, so #50's places are free (AC-1.4)", lines 278 to 287) is rewritten to the new strip and section.
- **Updates** `spec/requests/catalog/entries_show_spec.rb`'s order example (line 147: the marker list gains the "In decks" section between "Printings" and "Format legality") and `spec/requests/catalog/quick_adds_spec.rb` line 55 (spec 023 AC-6.2: the collection parts are now the three stats, "Your copies" and "In decks"; the example's `.c-stat dt` list is `Owned, In decks, Free to use`). `spec/requests/deck_additions_spec.rb` lines 228 and 312 and `spec/requests/catalog/visitors_spec.rb` line 348 read the first `.c-stat dd`, which stays Owned, and are not changed; the visitors' absent-selector example (line 196) gains the section's selector and the words "In decks" and "Free to use".
- **Fulfils** the Non-Goals and Out of Scope entries that name #50 as future work: specs 029 (lines 50, 504), 032 (lines 50, 86, 476), 033 (lines 42, 174), 057 (line 43), 070 (lines 44, 257) and 071, the roadmap's item 15 and `collection-and-lots.md`'s and `catalog-core.md`'s open-issues lines for #50.
- **Fulfils** spec 057 decisions 7 and 8, FR-5's "Must not" (the strip stays `c-stats--single` until #50; line 247), its Out of Scope entry that leaves "what 'In decks' shows for a deck with only a proxy" to #50 (line 305: decisions 3 and 4 settle it) and AC-5.1, AC-8.2 (the design) and extends them with the section's head count and empty state (decision 5), which they left open, and the card-wide scope of the Owned and Proxy columns (decision 6); `ItemPage.md`'s "Owned counts the copies in that zone and Proxy the proxies in it" says "of the card" after this spec.
- **Updates** `docs/architecture/collection-and-lots.md` line 163's "the card page's 'Free to use' of #50 must count them… (the card page's 'Free to use' is not built…)" (now built) and its card-page section; `docs/architecture/catalog-core.md` lines 88 (the card page's order), 202 and 221; `docs/architecture/collection-and-lots.md` lines 19 and 353; the design system README's "What is live" line (99) and `SingleStat.md` (lines 3, 15); `CLAUDE.md`'s deck sentence; `docs/specs/README.md`; `spec/deck_core_spec.rb`'s file list and count for the new files (decision 9).
- Recorded in the specs index in both directions (specs 004 and 071 gain a pointer).

## Documents and Files Changed

Listed so the plan can name them; the plan decides the code.

- `app/views/catalog/entries/_copies.html.erb` (one class and span on the Location cell), `spec/system/deck_additions_spec.rb` (two clicks scoped).
- `app/models/catalog/card_overview.rb` (the reads), a deck-reading query object for the table rows, `app/views/catalog/entries/show.html.erb` and a partial for the section, a helper for the head count, and their specs (model, request, system, a statement-count example, a tenancy example, a no-script example).
- `docs/design-system/components/ItemPage.md`, `ItemPagePhone.md`, `docs/design-system/previews/ItemPage.html`, `ItemPagePhone.html`.
- `docs/architecture/collection-and-lots.md`, `catalog-core.md`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/README.md`, `spec/deck_core_spec.rb`.

## Verification

Written at plan time into `verification.md`: each AC with the spec that proves it; the system specs (headless Firefox) measure overflow at 360px, 390px (frame), 640px and 1280px in both themes with the long names and large counts of Story 5; each "absent" assertion has a positive control built at run time (spec 066's lesson); the statement-count example proves it can fail; the screenshots of the card page with no decks, with some copies in decks, with all copies in decks and with proxies only, desktop and phone, both themes, and a GIF from the card page to the deck page, are kept with the spec.
