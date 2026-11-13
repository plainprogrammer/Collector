# Feature 079: Deck Checks (Deck Size, Copy Limits, and Owned Plus Proxy of One Card)

**Status:** Approved (2026-11-12, the maintainer, v0.2.1)
**Version:** 0.2.1
**Created:** 2026-11-12
**Last Updated:** 2026-11-12
**Depends on:** [spec 060](../060-deck-components/spec.md) (the deck page's components; decision 12, a deck's cards are owned plus proxy), [spec 062](../062-create-rename-remove-a-deck/spec.md) (decks, zones and the format registry `Catalog::Formats`; merged), [spec 066](../066-deck-page-owned-cards-by-zone/spec.md) (the deck page, its seam `Catalog::DeckCards` and the legality marker; merged), [spec 068](../068-deck-proxies/spec.md) (proxies in a zone; merged), [spec 069](../069-deck-shape-panel/spec.md) (the second seam, `Catalog::DeckShape`, and the counted-zones and statement-count precedents; merged), [the decks and locations issue design](../../superpowers/specs/2026-11-09-decks-and-locations-issues-design.md) (decisions 5, 6 and 8 and items 13, 15 and 16)
**Branch:** `079-deck-checks`
**Issue:** [#258](https://github.com/plainprogrammer/Collector/issues/258) (the 2.0 milestone, roadmap theme C)
**ADR:** none: ADR 0028 already puts a deck's collectible part behind the collecting vocabulary, and specs 066 and 069 added optional answers to that seam; this spec adds a third the same way (decision 1)
**Plan:** retired in `2086fd143fdd0a99fb5ade70f050e15ab2b0650d`; read it with `git show 2086fd143fdd0a99fb5ade70f050e15ab2b0650d^:docs/specs/079-deck-checks/plan.md`
**Frozen:** the current rules are in [`collection-and-lots.md`](../../architecture/collection-and-lots.md) (whole spec); the results section's markup and CSS rule are `DeckCheck` in the [design system](../../design-system/README.md); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.1 | 2026-11-12 | Spec review round 2 (Opus, NEEDS REVISION, 0 blocking, 7 important, 14 minor; no ruling reopened) fixed: the size rule holds zone keys, a minimum and a maximum and the core owns every word (decision 1; one shape: minimum, maximum or exact); a size rule's zone is counted over the deck's zone rows and named from the registration when the deck has none; the limit question is asked for every counted printing, a printing with no record gets the format's ordinary limit, "none" is above every number, and the reason is the lowest limit's; owned-plus-proxy findings are ordered by their own zone; AC-1.2 is for a deck with rules; the mechanism of "not kept for Back" is Turbo's no-cache tag, and the outcome is stated as a fresh check; `main` has no form; the results heading is "Deck check"; the split's wording; the guard's files are named; AC-7.1 says "in part"; a mis-cited decision, the header's citation of "Left to each issue's spec", AC-2.11's fixture and AC-1.5 are corrected; multi-case criteria are one example per case; `CLAUDE.md`'s Project Status is a Story 7 obligation |
| 0.2.0 | 2026-11-12 | Spec review round 1 (Opus, NEEDS REVISION, 2 blocking, 11 important, 8 minor) fixed: the seam now receives the cards and names its contract (decision 1); a printing with no card data has one rule (decision 4, Error Scenarios, NFR); a request-and-staleness design that fits Turbo (the check is a GET, decision 7); the placement of the control and results (decision 8); which name a card has in a finding and the order of findings (decision 6); every result string (decision 6); the results' order and a no-rules deck (decision 10); a card of another collectible is left out of every check, owned plus proxy included (decision 4); the focus rule for a screen reader (AC-6.3); the statement-count criterion in spec 069's form (AC-5.1); zones the rules don't name (decision 3); the guard, comment and YARD obligations (Story 7); wrong citations of the issue design. The maintainer ruled (2026-11-12) that a card whose text states a number is held to that number in every format, Commander included, and that the button sits in the page head with the results above the zones |
| 0.1.0 | 2026-11-12 | First draft from issue #258, the issue design, specs 062, 066, 068 and 069, and the maintainer's answers of 2026-11-12 (the Check deck button; size and copy limits only; copies counted by card across printings and zones; owned plus proxy of one card in one zone, any printing) |

## Problem Statement

A collector building a deck can't tell whether it meets its format's basic rules. Spec 066 marks each card that isn't legal, but nothing judges the deck as a whole: is it big enough, are there too many of one card, did a proxy stay behind next to the owned copy it was meant to be replaced by. Proxies change only by hand (the issue design's decision 8), so a forgotten proxy never announces itself, and a collector at the table or the sleeve box finds out too late.

This spec adds a **Check deck** button to the deck page. Pressing it judges the deck against its format's size and copy rules and flags every card that has both owned copies and proxies in one zone, and shows the findings on the page. The checks are advisory (they never block an edit) and on demand (nothing is judged, stored or shown until the collector asks). The rules for a game and its formats are that collectible's, kept in code behind the collectible extension; the core deck page names no game, format or zone.

> **Terms.** A *card* in a zone is one owned copy or one proxy, so a row of Owned 3 and Proxy 1 is four cards (spec 060 decision 12). *The same card* is one catalog identity across all its printings, so Lightning Bolt from two sets is one card. A *check* is one question put to the deck (its size, its copy limits, its owned-plus-proxy cards); a *finding* is a check's answer that something is wrong; a check that finds nothing *passes*. A *rule's zones* are the zones the extension names for that rule (decision 1); a zone no rule names is *unnamed*.

## Goals

- A deck page offers **Check deck**, and pressing it shows, on that page, the summary line and a result for each check that applies: a pass line or one finding per fault, each saying what is wrong in numbers.
- A Magic deck is judged against its format's rules (the table in decision 3): the size of its Main zone (and its Commander zone for Commander) and of its Sideboard, and the copies of each card.
- Any deck, whatever its game or format, is checked for a card with both owned copies and proxies in one zone, so a forgotten proxy shows up.
- The rules for a format are code in the collectible extension; the core names no collectible, format or zone key but `considering` (`spec/deck_core_spec.rb`).
- The checks add nothing to the page until asked for, store nothing, and run no statement beyond the ones the deck page already runs.

## Non-Goals

- Colour identity, banned cards and restricted cards of any format but Vintage's limit of one, and a whole-deck "is this deck legal" verdict. Spec 066's per-card marker is the legality view; this spec doesn't repeat it and doesn't judge the number or kind of commanders.
- Collector-defined formats and zones (the issue design's item 16) and rules a collector can change.
- Checks that run unasked: on every page view, on save, in the background or in an export. Nothing is stored and nothing is exported (decision 9).
- Blocking, warning on or refusing any edit because of a finding. The checks are read-only advice.
- A change to the proxy, the zone or the lot behaviour: a finding names a proxy, it never changes one (the issue design's decision 8 stands).
- Rules for Considering, and Sideboard rules beyond decision 3's size. Considering is never counted.
- A "fix it" action beside a finding, and a deck-builder workflow (the issue design's item 15).
- A new look: the results reuse the design system's patterns. If the plan finds a pattern it lacks, the pattern is added the way `CLAUDE.md` says (`collector/additions.css` and a component document), as an addition and not a redesign.

## Users and Context

**Primary users:** a collector with a deck, owned or planned, who is about to build, sleeve or play it.
**Usage context:** at a desk or on a phone, on the deck page, after adding or moving cards, asking "is this deck ready?".
**User mental model:** "a 60-card deck, no more than four of anything but basic lands; a Commander deck is 100 cards and one of each". A proxy is a card they will have on the table; "owned and proxy of one card" means "I meant to swap this proxy for my copy".

## Decisions

Decisions 1 to 10 are this spec's calls inside the issue and the issue design's outline ("Advisory and on demand, shown on the deck page"; "Formats stay rules in code, in the collectible extension"). Those marked *(my call)* are not stated by the issue or the maintainer's rulings; Gate A confirms them.

1. **A third optional answer on the collecting vocabulary, beside `formats`, `deck_card` and `deck_shape` (the seam).** A vocabulary may answer `deck_rules(format_key)`, the rules of one of its formats, or nil for a format it has no rules for. A core module `Catalog::DeckChecks` (added to `spec/deck_core_spec.rb`'s list; it names no collectible, format or zone key but `considering`) asks it with the deck's collectible type and format, runs the rules over the zones as `Deck::Page#zones` built them, and returns the results the core partial draws. **The contract**, written in `Catalog::DeckChecks`' comment (the one place it is written down; the area doc points to it):
   - **Size rules.** The answer lists size rules in the order they are shown. Each holds the *zone keys* it counts (the extension names them; the core matches them to each zone row's key and never names one) and one of three shapes: a minimum only, a maximum only, or an exact size (minimum and maximum equal); a range with two different bounds is not offered. The extension supplies no words: decision 6's sentences, the format's shown name (`Catalog::Formats.name_for`) and the zones' shown names are the core's. The cards of a rule are counted over the deck's zone rows with those keys; a key the deck has no zone row for counts as no cards and is named from the format's registration (`Catalog::Formats.zones_for`), or by its key when the registration lacks it. A deck zone no rule names is unnamed.
   - **The copy rule.** The answer names the zone keys the copy rule counts together and gives a way to ask, for one counted printing (a `Catalog::Entry` whose extension record may be nil, as `Catalog::DeckCards` is asked for an entry loaded by `Catalog::Entry.preload_extensions`), what its card's limit is: a number, with an optional reason word ("restricted to 1"), or none (never limited). For a printing with no extension record the extension answers the format's ordinary limit (decision 4). The core counts copies by catalog identity and asks for **every** counted printing of a card; *none* is above every number, so a card is unlimited only when every counted printing answers none, and otherwise it is held to the lowest number, with the reason given alongside that number (the first printing in page order on a tie). *The mixed case* (one printing of a basic land has a record, another has none) therefore gives the ordinary limit, the same accepted consequence as decision 4's.
   - **Reads.** Asking reads the loaded extension records only: no statement per card, and none beyond the deck page's own (decision 7, AC-5.1). The core reads each row's `catalog_identity_id`, which the page's entries already carry.
   - **The core owns** the counting, the results, their words (decision 6), the order of findings and the pass lines, and it shows the zones' own names (`Zone#name`), joined with " + ".

   A vocabulary without `deck_rules`, a format it returns nil for, a collectible no longer registered and a deck whose format is no longer registered have **no size or copy rules**: the page says so in one line (decision 6). *Alternative:* a hard-coded table in the core. Rejected: the core would name formats, which `spec/deck_core_spec.rb` forbids and issue #258 rules out.
2. **Owned plus proxy is a core check, run for every deck.** It needs no game rule: it reads each zone's rows through their catalog identity and the owned and proxy counts the page already has. It runs for Casual and for a deck whose format is no longer registered, because a proxy forgotten there is as forgotten. *(my call)*
3. **The rules, by format (Magic).** *(The maintainer chose size and copy limits only, on 2026-11-12.)*

   | Format | Size | Copies of one card |
   |---|---|---|
   | Standard, Pioneer, Modern, Legacy, Pauper | Main at least 60; Sideboard at most 15 | at most 4, Main and Sideboard together |
   | Vintage | as above | at most 4, and at most 1 of a card the catalog lists as restricted in Vintage, Main and Sideboard together |
   | Commander | Commander and Main together exactly 100 | at most 1, Commander and Main together |
   | Casual | none | none |

   Basic lands (a type line with the supertype Basic, Snow-Covered ones included) are never limited. A card whose own rules text says a deck can have any number of cards with its name is never limited; a card whose text states a number ("up to seven", "up to nine") is held to that number **in every format, Commander included** (the maintainer's ruling, 2026-11-12). Considering is never counted, for size or for copies, and neither is any unnamed zone. Owned copies and proxies both count (spec 060 decision 12); a proxy is a card on the table. A card is *restricted in Vintage* when any counted printing of it lists it so.
4. **Cards are counted by catalog identity; the cards counted are the deck's collectible's.** The copies of "a card" are summed over every printing of it in the rule's zones, owned plus proxy, so four Lightning Bolts from two sets are four. A card of another collectible than the deck's (a lot isn't type-checked when it is placed in a zone, so a page can hold one) is **left out of every check** (size, copies and owned plus proxy) and is named in no finding, as spec 069 decision 3 does for the panel, so a size count can be smaller than the zone head's "N cards", which counts every row. A token or any other kind of card placed in a zone counts like any card. A printing with no card data (no extension record: the catalog hasn't been refreshed since it was added) is a card like any other: it counts for size and for copies by its identity, and it is never exempt and never restricted, because nothing says it is. The consequence is stated and accepted: before a refresh, a basic land with no record is judged like any card. *(The maintainer chose "by card, across printings and zones", 2026-11-12; the no-card-data rule is my call.)*
5. **The owned-plus-proxy rule.** A card is flagged in a zone when that zone holds at least one owned copy and at least one proxy of the card, in the same or in different printings, in any zone including Considering and an unnamed zone. Each zone is judged alone: owned in Main and a proxy in Considering is not a finding, because a proxy in Considering is a plan and not a leftover *(my call)*. A finding names the card, the zone's shown name and the split ("2 owned, 1 proxy"). *(The maintainer chose "same card in one zone, any printing", 2026-11-12.)*
6. **Findings are numbers, in words; these are the strings.** Every result has a **status word** and a sentence, and the word and an icon the design system already has (if the plan finds one) say pass or fault, so nothing depends on colour alone. "N cards" and "N copies" use `number_with_delimiter` and the singular for one. *(my call)*

   | Result | Status word | Sentence |
   |---|---|---|
   | Size below the minimum | Short | "Main: 58 cards; Standard needs at least 60." |
   | Size above the maximum | Over | "Sideboard: 17 cards; Standard allows at most 15." |
   | Size not exact | Short or Over | "Commander + Main: 99 cards; Commander needs exactly 100." |
   | Size right | Pass | the same sentence with the true count: "Main: 60 cards; Standard needs at least 60." (one line per size rule) |
   | A card over its limit | Over the limit | "Lightning Bolt: 5 copies; the limit is 4." or, with a reason, "Black Lotus: 2 copies; restricted to 1." |
   | No card over its limit | Pass | "No card is over its limit." |
   | Owned and proxy in one zone | Owned and proxy | "Lightning Bolt in Main: 2 owned, 1 proxy." |
   | No such card | Pass | "No card has both owned copies and proxies in one zone." |
   | No size or copy rules | none | "Casual has no rules to check." (the format's shown name, or its stored key when it is no longer registered) |

   A card is named by the English name Scryfall gives the card (`Catalog::Entry#name`, the same for every printing, a double-faced card's "A // B" included), never by the localised name a non-English printing shows on the deck page. Copy findings are ordered by the position, in the page's zone order, of the first counted zone that holds the card, then by name, then by identity id. Owned-plus-proxy findings are ordered by their own zone's position in the page's zone order, then by name, then by identity id. A size finding names its rule's zones by their shown names joined with " + ". The split says "N owned, N proxy" (the proxy count's word does not change with the number, as the deck page's head and zone heads write it). The results section's heading is "Deck check".
7. **The check is a read-only request for the deck page; nothing about it is stored.** Check deck is a **link**, styled as a button like "Edit deck", to the deck's check: a read-only request (a GET, so no form and no redirect) that shows the deck page with the results. Pressing it again checks again against the deck as it then is. The results are never stored, so **any later request of the deck page has none**: a redirect after an edit, a change of format or a visit to the plain deck page shows no results and shows the button again. The results page carries Turbo's `turbo-cache-control: no-cache` tag (as the collection and search pages do), so Turbo keeps no snapshot of it: Back to the results page is a fresh request of the check, which judges the deck as it then is and never shows results computed before an edit. The deck page without a press runs the statements it runs today, and the check runs none beyond them. *(The maintainer chose the button, 2026-11-12; the mechanics are my call.)*
8. **Where it sits.** The button is in the page head's actions beside Edit deck. The results are a full-width section between the head and the zones (so a phone reads them first), with a heading and the summary line; the zones and the shape panel are drawn as on the plain page. On the results page the button remains and checks again. *(The maintainer chose this placement, 2026-11-12.)*
9. **Nothing is stored and nothing is exported.** A result is computed when the check is requested and shown; it needs no migration, no job, no cache, no column and no change to the export, the import or the backup. The export format stays at version 4.
10. **The summary line and the order of results.** Above the results, one line says how many findings there are ("3 findings", "1 finding") or "No findings" when every check passed or has no rules. The results follow in this order: the size rules in the extension's order, then the copy check, then owned plus proxy. A deck with no size or copy rules shows the no-rules line and then owned plus proxy. *(my call)*

## User Stories

### Story 1: Check a deck on demand

**As a** collector reading a deck
**I want** to press Check deck and see what is wrong with it
**So that** I can fix it before I build or play the deck.

**Acceptance criteria:**

- [ ] **AC-1.1** Given a deck page When the collector has not asked for the check Then the page shows the Check deck button in the head's actions and no result, summary line or finding, and runs the statements it ran before this feature.
- [ ] **AC-1.2** Given a deck whose format has size and copy rules When the collector presses Check deck Then the deck page is shown with the summary line and, in the order of decision 10, one result for each size rule, the copy check and the owned-plus-proxy check, between the head and the zones, with the zones still shown.
- [ ] **AC-1.3** Given results are shown When the collector removes a proxy from a row's menu and the deck page is shown again Then it has no results and shows the button, and pressing the button shows the results for the changed deck.
- [ ] **AC-1.4** Given results are shown When the collector presses Check deck again without changing the deck Then the same results are shown.
- [ ] **AC-1.5** Given a deck that breaks a rule When the collector presses Check deck Then the results page has every link and button the plain deck page has, enabled, and following one of them (for example Edit deck) works as it does from the plain page.
- [ ] **AC-1.6** Given another account's deck When the collector requests its check Then the response is a 404 and nothing of that deck is revealed, as for the deck page itself.
- [ ] **AC-1.7** Given the summary line When there are N findings across the checks Then it reads "N findings" ("1 finding" for one), and "No findings" for none.
- [ ] **AC-1.8** Given the results page When it is served Then its head carries the `turbo-cache-control` tag with the value `no-cache`, and the plain deck page does not (decision 7).
- [ ] **AC-1.9** Given the deck page, plain and with results When it is inspected Then the Check deck control is a link and `main` has no `form`.

### Story 2: Deck size

**As a** collector with a Magic deck
**I want** its size judged against its format
**So that** I know it has enough cards, and not too many in the sideboard or in Commander.

**Acceptance criteria:**

- [ ] **AC-2.1** Given a Standard deck with 58 cards in Main (owned and proxy together) When the collector checks it Then there is a Short finding with the sentence "Main: 58 cards; Standard needs at least 60."
- [ ] **AC-2.2** Given a Standard deck with exactly 60 cards in Main When it is checked Then the Main size result passes with the sentence "Main: 60 cards; Standard needs at least 60.", and 61 or more also passes.
- [ ] **AC-2.3** Given a Modern deck with 16 cards in Sideboard When it is checked Then there is an Over finding "Sideboard: 16 cards; Modern allows at most 15."; given 15, or none, the Sideboard size result passes.
- [ ] **AC-2.4** Given a Commander deck with 1 card in Commander and 98 in Main When it is checked Then there is a Short finding "Commander + Main: 99 cards; Commander needs exactly 100."; with 101 cards it is Over and says 101; with 100 it passes.
- [ ] **AC-2.5** Given a deck with cards in Considering When it is checked Then those cards are in no size count.
- [ ] **AC-2.6** Given a Main of 59 owned copies and 1 proxy When it is checked Then the proxy counts: Main has 60 cards and the Main size result passes.
- [ ] **AC-2.7** Given a Casual deck, or a deck whose format the instance no longer registers When it is checked Then there is no size or copy result, one line says the format has no rules to check (its shown name, or its stored key when it is not registered), and the owned-plus-proxy result is still shown after it.
- [ ] **AC-2.8** Given a Pauper, Pioneer, Legacy or Vintage deck with a 59-card Main When it is checked Then each shows the same finding with its own format's name.
- [ ] **AC-2.9** Given a Standard deck with no card in Main When it is checked Then the finding says Main has 0 cards.
- [ ] **AC-2.10** Given a card of another collectible in a zone the size rule counts When the deck is checked Then it is not in the count.
- [ ] **AC-2.11** Given a deck with a zone row whose key no rule names, holding cards When it is checked Then that zone is in no size or copy count.
- [ ] **AC-2.12** Given a Standard deck that has no Sideboard zone row (so the rule's key has no zone) When it is checked Then the Sideboard size result passes as 0 cards and names the zone "Sideboard" from the registration.
- [ ] **AC-2.13** Given a Commander deck When it is checked Then the one size result names its zones "Commander + Main" and the sentence is decision 6's.

### Story 3: Copy limits

**As a** collector with a Magic deck
**I want** the cards I have too many of named
**So that** I can take them out before I play.

**Acceptance criteria:**

- [ ] **AC-3.1** Given a Standard deck with 5 copies of one card in Main When it is checked Then there is an Over the limit finding "Lightning Bolt: 5 copies; the limit is 4." naming the card.
- [ ] **AC-3.2** Given 3 copies of a card in Main and 2 in Sideboard of a Modern deck When it is checked Then the finding says 5 copies, because the zones are counted together; with 4 across both the copy check passes.
- [ ] **AC-3.3** Given 4 copies of a card from one printing and 1 from another printing in one Legacy deck, or 3 owned and 2 proxy of one printing, When it is checked Then each finding says 5 copies: printings and owned plus proxy are counted together.
- [ ] **AC-3.4** Given a deck with any number of Plains, or Snow-Covered Island, in Main When it is checked Then neither is a finding.
- [ ] **AC-3.5** Given a card whose rules text says a deck can have any number of cards with its name, in 9 copies When the deck is checked Then it is not a finding.
- [ ] **AC-3.6** Given a Commander deck with 2 copies of one card, one in Commander and one in Main When it is checked Then the finding says 2 copies and the limit is 1; two basic lands there are no finding.
- [ ] **AC-3.7** Given a Vintage deck with 2 copies of a card the catalog lists as restricted in Vintage When it is checked Then the finding reads "Black Lotus: 2 copies; restricted to 1."; given 2 copies of a card that is not restricted it passes, and the same restricted card in a Legacy deck is limited to 4.
- [ ] **AC-3.8** Given copies in Considering When the deck is checked Then they are counted by no copy rule.
- [ ] **AC-3.9** Given several cards over their limits When the deck is checked Then each has its own finding, ordered as decision 6 says.
- [ ] **AC-3.10** Given a deck with no card over any limit When it is checked Then the copy check passes with "No card is over its limit."
- [ ] **AC-3.11** Given a card of another collectible in a zone of a Magic deck When it is checked Then no rule counts it and no finding names it.
- [ ] **AC-3.12** Given a card whose rules text says a deck can have up to seven cards with its name, in 8 copies in a Standard deck When the deck is checked Then there is a finding saying 8 copies and the limit is 7; and given 8 copies in a Commander deck the finding says 8 copies and the limit is 7; and given 7 copies in either it passes.
- [ ] **AC-3.13** Given a Japanese printing and an English printing of one card in a Standard deck, 3 and 2 copies When the deck is checked Then the finding names the card by its English name and says 5 copies.
- [ ] **AC-3.14** Given a printing with no card data (no extension record) in 5 copies in a Standard deck When the deck is checked Then it is a finding as any card is, and in a Commander deck a basic land with no card data in 2 copies is a finding too (decision 4).
- [ ] **AC-3.16** Given a basic land with two printings in a Standard deck, one with card data and one without, 5 copies in all When the deck is checked Then there is a finding at the limit of 4 (decision 1's mixed case).
- [ ] **AC-3.15** Given a card in 5 copies in Main of a Standard deck and in 5 more in Sideboard When the deck is checked Then there is one finding for the card, saying 10 copies.

### Story 4: A card with owned copies and proxies in one zone

**As a** collector who plans a deck with proxies
**I want** to see the cards that have both
**So that** I notice a proxy I forgot to swap for my own copy.

**Acceptance criteria:**

- [ ] **AC-4.1** Given a zone with 2 owned copies and 1 proxy of one printing When the deck is checked Then there is an Owned and proxy finding "Lightning Bolt in Main: 2 owned, 1 proxy."
- [ ] **AC-4.2** Given a zone with an owned copy of one printing and a proxy of another printing of the same card When the deck is checked Then it is flagged.
- [ ] **AC-4.3** Given an owned copy of a card in Main and its proxy in Considering When the deck is checked Then it is not flagged.
- [ ] **AC-4.4** Given a zone with only owned copies of a card, or only proxies of it When the deck is checked Then the card is not flagged.
- [ ] **AC-4.5** Given a Casual deck, or a deck whose format is not registered When it is checked Then the owned-plus-proxy result is shown.
- [ ] **AC-4.6** Given a card with owned copies and proxies in both Main and Sideboard When the deck is checked Then there is one finding per zone, each with that zone's split.
- [ ] **AC-4.7** Given a deck with no card in this state When it is checked Then the result passes with "No card has both owned copies and proxies in one zone."
- [ ] **AC-4.8** Given a finding When the collector has read it Then nothing has changed: the proxy, the lots and the zones are as before.
- [ ] **AC-4.9** Given a card of another collectible with owned copies and a proxy in one zone of a Magic deck When the deck is checked Then it is not flagged (decision 4).
- [ ] **AC-4.10** Given a card with owned copies and a proxy in a zone no rule names When the deck is checked Then it is flagged, naming that zone.

### Story 5: What the checks read, and what they change

**As a** self-hoster and a maintainer
**I want** the checks to cost nothing extra, keep to one account and add no data
**So that** a big deck doesn't slow the page and an upgrade needs nothing.

**Acceptance criteria:**

- [ ] **AC-5.1** Given decks of 5 rows and of 500 rows When each is checked Then the check request runs the same number of statements as the plain deck page of that deck (spec 069 AC-6.1's form), and `Deck::Page#zones` is as before.
- [ ] **AC-5.2** Given a visitor who is not signed in When the check is requested Then the response is the sign-in redirect the other deck pages give.
- [ ] **AC-5.3** Given the app after the feature When its schema, the export, the import and the backup are compared with before Then nothing has changed and the export format is still version 4.
- [ ] **AC-5.4** Given the core files of the checks (`app/models/catalog/deck_checks.rb` as a new pattern, and the check's controller and views, which the existing globs cover, so the guard's hand-counted total rises by them) When `spec/deck_core_spec.rb` reads them, comments included Then none names a collectible, a format or a zone key but `considering`, so no core comment uses a format's name as an example; and the guard's list and count include them.
- [ ] **AC-5.5** Given a collectible whose vocabulary has no `deck_rules` When a deck of it is checked Then the page says it has no rules to check, shows the owned-plus-proxy result, and nothing raises.

### Story 6: The results are readable

**As a** collector on a phone, in either theme
**I want** the results to be legible
**So that** I can use them where I use the deck.

**Acceptance criteria:**

- [ ] **AC-6.1** Given the results at 360px in the light and the dark theme When they are shown Then nothing overflows the page horizontally and no text is clipped.
- [ ] **AC-6.2** Given a result When it is a pass or a finding Then its status word says which (decision 6), so no result depends on colour alone.
- [ ] **AC-6.3** Given the results page When it loads Then the results section has the heading "Deck check", keyboard focus is on that heading, and the button and every result are reachable in reading order.
- [ ] **AC-6.4** Given a card name that is long, or a zone name that is long When it appears in a finding Then it wraps and nothing overlaps.

### Story 7: The documents and the guards

**As a** maintainer and an agent
**I want** the rules written where the next feature will look
**So that** nothing here is rediscovered from the code.

**Acceptance criteria:**

- [ ] **AC-7.1** Given the area doc `collection-and-lots.md` When the feature is distilled Then it states the checks' rules (decisions 1 to 10) with this spec as the source, and says that spec 069's non-goal "deck rules" is done in part by this spec (size and copy limits; "is this deck legal as a whole" stays out, Non-Goals).
- [ ] **AC-7.2** Given the specs index When the spec is written Then it has a row for 079 naming the area docs it changes and `docs/design-system/components/DeckPage.md`, and notes that it supersedes nothing.
- [ ] **AC-7.3** Given `Catalog::DeckChecks` and `MTG::Collecting.deck_rules` When they are written Then each public class, module and method has a summary comment, `@param` and `@return` where `.claude/rules/code-documentation.md` asks for them, the contract of decision 1 is `Catalog::DeckChecks`' comment, the comment ratchet and the YARD build pass, and the area doc points to the comment.
- [ ] **AC-7.4** Given `docs/design-system/components/DeckPage.md` When the feature is distilled Then it describes the head's Check deck link, the results section and its place, and that the page remains form-free.
- [ ] **AC-7.5** Given the roadmap When the feature merges Then its theme C entry lists #258 as shipped.
- [ ] **AC-7.6** Given `CLAUDE.md`'s Project Status paragraph When the feature is distilled Then it carries one clause for the deck checks (`Catalog::DeckChecks`, `MTG::Collecting.deck_rules`, spec 079), as earlier deck specs added theirs, and restates no rule of the area doc.

## Functional Requirements

### FR-1: The seam

**Must:**
- Ask the collecting vocabulary for a format's rules through an optional `deck_rules` answer (decision 1); treat a missing method, a nil answer and an unregistered type as "no rules" and never raise for them.
- Run the rules, and the owned-plus-proxy check for every deck, over the zones `Deck::Page` already built.
- Keep the core free of any collectible, format and zone key but `considering`.

**Must not:**
- Name a format or a zone in the core, read a record by an id from the request, or run a statement per row.

### FR-2: The checks

**Must:**
- Judge size, copy limits and owned plus proxy by decisions 3 to 5, counting owned copies and proxies together, by catalog identity, and leaving out Considering, unnamed zones for the size and copy rules, and cards of another collectible.
- Return, for each check, either a pass with the line that says what passed, or one finding per fault with the words decision 6 gives, in decision 10's order.

**Must not:**
- Change any lot, proxy, zone or deck, or store a result.

### FR-3: The request and the page

**Must:**
- Show the Check deck link in the page head and, for the check request, the summary line and the results between the head and the zones (decisions 7, 8 and 10).
- Show no result on a request of the deck page that is not the check.

**Must not:**
- Disable or hide any of the page's actions because of a finding, or add a form to the page.

## Non-Functional Requirements

### Performance

- The deck page without a press runs the statements it runs today; the check request runs none beyond them, however many zones, rows and lots the deck has (AC-5.1). The identity of a card and the rule data of a printing come from the entries and extension records the page already loaded.

### Security

- The check is a request for one deck of the signed-in account: another account's deck is a 404 and the identities read are catalog data (global, no `account_id`). No `account_id` or deck id is taken from a form field. Names of cards and zones shown in a finding are escaped as everywhere.

### Reliability

- A missing rule, an unregistered format, a collectible no longer registered or a printing without card data never raises and never shows a partial result: it gives the "no rules to check" line, or counts the printing by its identity as decision 4 says.

### Accessibility and design

- The results use the design system's tokens and `c-*` classes only; any new pattern gets a component document (`CLAUDE.md`). Nothing depends on colour alone; the page reads in both themes at 360px; focus goes to the results heading on load.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The deck's format isn't registered (a format removed from the instance) | No size or copy result; one line says the stored key has no rules to check; the owned-plus-proxy result is shown |
| The collectible's vocabulary has no `deck_rules`, or returns nil for the format | The same line, naming the format's shown name |
| A printing has no card data (not refreshed, no extension record) | It counts for size and for copies by its identity, is never exempt and never restricted (decision 4); the card's name in a finding is its English name (decision 6) |
| A card of another collectible in a Magic deck's zone | Left out of every check and named in no finding (decision 4) |
| The deck has no card anywhere | A format with a minimum finds 0 cards in the named zone; the other results pass |
| A zone no rule names holds cards (an unregistered format's zones, or a zone the format no longer lists) | Not counted for size or copies; judged for owned plus proxy |
| A collector requests the check of a deck that was deleted meanwhile | The usual not-found response, as for the deck page |
| The deck changes after the check was shown | Any later request of the deck page has no results (decision 7), and Back does not show the old ones |

## Interactions and Supersession

- **Testing form:** an acceptance criterion that names several cases ("or", "with 101 it is Over") is one example per case in an `:aggregate_failures` group, so a failure names its case.
- **Supersedes:** nothing. Spec 069 left "deck rules" as a non-goal ("the 2.0 milestone, issue #258"); this spec is part of that work (size and copy limits) and changes no sentence of spec 069 or of spec 066.
- **Area docs it will change** (at distillation): [`collection-and-lots.md`](../../architecture/collection-and-lots.md) (decks and the deck page) and [`DeckPage.md`](../../design-system/components/DeckPage.md) (the head's link and the results section); the design system also if a new pattern is added. The specs index gets its row now.
- **Leaves alone:** spec 066's per-card marker, spec 068's proxy rules, spec 069's panel and the export format.

## Open Questions

None. Decisions marked *(my call)* are for Gate A: decision 2 (the owned-plus-proxy check runs for every deck), the no-card-data rule of decision 4, decision 5's per-zone judging, decision 6's strings and ordering, and decision 10's summary line.

## Out of Scope (Future Considerations)

- Colour identity, banned and restricted cards beyond Vintage's one, the number of commanders and partner rules.
- A check that runs on every view, on save or in the background, or one that warns while editing.
- Collector-defined formats and rules (the issue design's item 16), and rules for other collectibles (they register `deck_rules` when they exist).
- A "fix it" action beside a finding, such as "Use my copy" (spec 070 already offers that from the row's menu).
- Storing results, a history of checks or including them in the export.
