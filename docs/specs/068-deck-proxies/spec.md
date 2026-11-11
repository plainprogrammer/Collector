# Feature 068: Proxies in a Deck Zone

**Status:** Approved
**Version:** 0.4.0
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 066](../066-deck-page-owned-cards-by-zone/spec.md) (the deck page, whose Proxy and Total cells and heads this spec fills; merged), [spec 064](../064-change-deck-format/spec.md) (a change of format moves lots into Considering and this spec adds proxies to the move; merged), [spec 062](../062-create-rename-remove-a-deck/spec.md) (decks, zones, export format version 4; merged) and [spec 060](../060-deck-components/spec.md) (`ProxyTag`, `DeckPage`, `DecksIndex` and their CSS; merged)
**Branch:** `068-deck-proxies`
**Issue:** [#254](https://github.com/plainprogrammer/Collector/issues/254)
**ADR:** none: ADR 0028 already makes a deck a location and a zone a child location; a proxy is a row that belongs to a zone, and the choices below are this spec's (decision 12)
**Frozen:** the current rules are in [`collection-and-lots.md`](../../architecture/collection-and-lots.md) (the whole spec but the export, import and tenancy parts), [`data-portability.md`](../../architecture/data-portability.md) (decisions 14–16 and 18, Story 7, FR-4) and [`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md) (AC-1.7, AC-8.3, AC-8.4); see the [specs index](../README.md)
**Plan:** retired in `91a0e8ffbec348799d98734841daf69fdaee75fb`; read it with `git show 91a0e8ffbec348799d98734841daf69fdaee75fb^:docs/specs/068-deck-proxies/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.4.0 | 2026-11-11 | Gate A, the maintainer's ruling (2026-11-11): `proxies` is **required** in version 4 and a version 4 file without it is refused as any schema-invalid file is (decisions 14, 15; AC-7.3, AC-7.5; the optional-list branch, its preview sentence, its removed-outcome case and the `edge` note are dropped); decision 9 ruled as written; Approved at Gate A (the coordinator, under the maintainer's delegation, 2026-11-11) |
| 0.3.0 | 2026-11-11 | From review round 2 (0 blocking, 3 major): a version 4 file without `proxies` still counts the proxies of the decks and zones it removes as removed outcomes (decision 15), the type and finish rules are creation-time rules and the import has no `type_mismatch` (decisions 2, 18, 19: a format change can switch a deck's type), AC-6.4's refusal order, the Coverage mapping and "same collection" for an absent list, `problems.json`, the held-by-a-problem-row case, the chooser's edge cases and the supersession list |
| 0.2.0 | 2026-11-11 | From review round 1 (1 blocking, 8 major): the import's proxy rows are row-level problem rows with a rule list (decision 18), `proxies` is optional in version 4 and an absent list leaves proxies alone (decisions 14, 15; the `edge` channel recorded), the chooser's paging and type filter (decision 3), the finish rules apply at creation only and the import accepts a finish-less proxy (decision 2), the proxy's printing must be of the deck's type in the model and the import (decision 19), counts defined as quantities or rows (Terms), the finish named on every change and removal page and notice, the completed supersession list, "same collection" for proxies, and the minor fixes |
| 0.1.0 | 2026-11-11 | First draft from issue #254, the issue design's item [8], specs 060, 062, 064, 065 and 066, the area docs `collection-and-lots.md` and `data-portability.md`, and the export format document |

## Problem Statement

A collector builds a deck from cards they own and cards they don't: the ones they plan to buy, to borrow, or to print as stand-ins for the table. Today a deck can show only what the collector owns, so the other cards live on paper or in the collector's head, and the deck page can't answer "how many cards is this deck, and how many of them are mine".

This spec adds proxies: a collector records, in one zone of a deck, a printing and a finish with a quantity that they need but don't own. The deck page shows them beside the owned copies, with the dashed Proxy tag, and counts them in its heads and on the Decks page. A proxy is never a lot: it is not in the collection, never counts as owned, and changes only when the collector changes it.

> **Terms.** *Deck, zone, Considering, lot, label, merge, cap, vocabulary, format registration* are as in [`collection-and-lots.md`](../../architecture/collection-and-lots.md) and specs 062 and 064. A *proxy* is one row of `deck_proxies`: one zone, one printing, one finish and a quantity (spec 060 Terms; issue design decision 1). A *card row* is one printing in one zone as the deck page lists it (spec 066 decision 2); its *Proxy* is the sum of the quantities of its proxies (one per finish) and its *Total* is Owned plus Proxy. A deck's *cards* are its owned copies plus its proxies, as spec 060 decision 12 fixed. **Counts of proxies are quantities** (the deck page's heads, the Decks page, the removal page and the format change's notice add up the quantities, "11 proxy" being eleven copies' worth), except in the import, where a proxy count is **rows**, as a lot count is: "2 proxies added" is two proxy rows (decision 16).

## Goals

- A collector adds a proxy to a zone from the zone's header: they find a printing, choose its finish and a quantity, and the zone shows it.
- A collector changes a proxy's quantity or removes it, from a menu on the card row.
- The zone table's Proxy and Total cells, the `ProxyTag`, the page head's and zone heads' proxy counts and the Decks page's Proxy column show proxies, and owned copies are counted apart from them everywhere.
- A proxy is never owned: no count of the collection, the card page or the Decks page's Owned counts one, and no copy that arrives in, moves into or leaves a zone changes one.
- Removing a deck removes its proxies, and changing a deck's format moves the proxies of dropped zones into Considering, as it moves lots (spec 064's cap and notice).
- The export carries proxies, the import previews and applies them, and an export restores on a fresh instance with the proxies as they were. This extends format version 4, which no release has shipped.

## Non-Goals

- **Replacing a proxy with a copy** ("Use my copy", "Add a new copy"): [#257](https://github.com/plainprogrammer/Collector/issues/257). The row menu leaves room for them; this spec renders neither.
- **Adding a proxy from a card page** ("Add to deck", [#255](https://github.com/plainprogrammer/Collector/issues/255)); **the shape panel** ([#256](https://github.com/plainprogrammer/Collector/issues/256)); **Free to use, In decks and any card page count** ([#50](https://github.com/plainprogrammer/Collector/issues/50)).
- **Moving a proxy** to another zone or deck, or **copying** a deck's proxies. A collector who wants a proxy elsewhere removes it and adds it there.
- **Deck-size and copy-limit checks**, and a flag for a card that has both owned copies and proxies in one zone ([#258](https://github.com/plainprogrammer/Collector/issues/258), 2.0).
- **A "Move copies" item** on rows that have no proxy: the card page's "Your copies" stays the place for moving owned copies (spec 066 decision 9; decision 5 below).
- **Condition, price or a note on a proxy.** A proxy is a printing, a finish and a quantity.
- **A new limit** on how many proxies an account or a zone holds beyond the 9,999 of one proxy (decision 2).
- **Bulk mode, the collection's grid and table, the scanner and number entry** learn nothing about proxies.

## Users and Context

**Primary users:** a collector with a deck they are building, at a desk or at the table, on a laptop or a phone.
**Usage context:** they open a deck page, see the zone, and record "4 Lightning Bolt, foil, MH2" as a proxy in Main because they don't own them yet; later they change the number or remove the line.
**User mental model:** "the deck's list has the cards I own and the cards I'm borrowing the idea of"; a proxy is a line on the list, marked so it can't be mistaken for a copy in a box.

## Decisions

Each is my call unless it names a ruling; alternatives are listed so the coordinator can redirect.

1. **A proxy is a row of `deck_proxies`, never a lot.** It has the account, the zone (a location of kind `deck_zone`), the printing (a catalog entry), a finish, a quantity of 1 to 9,999 and the times. It is unique per zone, printing and finish, and a second add of the same three merges into it (decision 4). It is not in `lots`, so no count, query, export row, bulk selection, number-entry line, scanner or card page that reads lots sees it, and the anti-goal "a proxy that ever counts as owned" holds by construction. A zone's or a deck's removal removes its proxies through the foreign key (the schema's job: AC-5.4, AC-7.10), and the format change moves a dropped zone's proxies out first (AC-6.1, AC-6.7), so the cascade never loses a proxy the app meant to keep; `account_id` is enforced as for every tenant table.
2. **A proxy's finish and cap.** A proxy names a finish the printing's vocabulary lists (`Catalog.collecting_for(type).finishes_for(entry)`), and the finish is required when the printing lists any; a printing that lists none has a proxy with no finish. These two rules apply when a proxy is created, by the add page and the model's create, and when its finish is set; a stored proxy is never revalidated against the catalog afterwards, so a refresh that gives a printing finishes it lacked, or drops one, leaves its proxies editable and exportable, and the import never requires a finish (a non-null finish the entry doesn't list is `finish_not_listed`, a missing one is accepted: decision 18). The quantity is 1 to 9,999 (a lot's cap), whole, per proxy. There is no cap on the number of proxy rows beyond that, as for lots. A printing of a retired entry can't be chosen for a new proxy, and an existing one is kept and shown (as a lot's is). *Alternative:* allow an unspecified finish on any printing, as a lot does; it would make a replacement by #257 match less.
3. **Choosing the printing is a search, then a form.** "Add a proxy" in a zone's head opens a page "Add a proxy to <Deck › Zone>" with the catalog's name search (the card search's field, with its set filter) and, under it, the matching cards of the deck's collectible type, paged as the card search pages them (`Catalog::Search`, which gains a filter by collectible type and keeps its 12 cards per page), each card listing its newest printings up to the search's limit of 10 (name, `SET · number`, language, a "Choose" link each); a card with more printings says "Showing 10 of 24 printings. Choose a set to see the others." and the set filter narrows it. Choosing one shows a second step: the printing's summary, a Finish select (shown when the printing lists finishes; the printing's finishes, nothing chosen first when there are several, the only one chosen when there is one), a Quantity field (1) and "Add proxy" and "Cancel". Both steps are plain pages and work without scripting. The deck page's "Add a proxy" is a link, not a form, so the deck page stays form-free (spec 066 AC-4.2). *Alternative:* a set code and collector number as in "Add by number" (spec 026); it is faster for a collector who has the list but can't find a card by name. *Alternative:* the card page's printings list (#255 builds that route from the card side); this spec adds the deck side and #255 adds the card side.
4. **An add merges.** Adding a proxy whose zone, printing and finish already have one adds the quantity to it (the row survives); an add that would pass 9,999 changes nothing and says "A zone can hold at most 9,999 proxies of one printing and finish." as the field's error (422). *Alternative:* refuse the duplicate; merging is how lots behave.
5. **The row menu comes back, with proxy items only (supersedes spec 066 decisions 7 and 9 and their "no menu column" until #254; spec 060 decision 17 is the starting point).** A zone table gains spec 060's last column, the 4rem menu (`TableActions`, trigger "Actions for <card> <set · number>"), for rows that have a proxy: "Change proxy count", then, after a separator, "Remove proxy" (danger, last). A printing with proxies of two finishes has the pair of items for each, the finish named as the vocabulary labels it: "Change Foil proxy count", "Remove Foil proxy". A row with no proxy has an empty menu cell and no trigger. "Use my copy" and "Add a new copy" are #257's and are first in the menu when it lands; "Move copies" isn't offered (Non-Goals). *Alternative:* an owned-only row's "Move copies" with one item per lot; it needs a decision about which lot and returns to the card page, so it is left to the issue that needs it.
6. **Change and remove are pages.** "Change proxy count" opens a page with the proxy named (deck › zone, printing and, when it has one, its finish), a Quantity field with the count and "Save" and "Cancel"; it refuses 0 ("Enter a number from 1 to 9,999. To remove it, use Remove proxy.") so a removal is never a typing slip, and a quantity unchanged is a no-op success. "Remove proxy" opens a confirmation page ("Remove the proxies of Lightning Bolt (MH2 · 138, Foil) from Izzet Tempo › Main?", the finish after the number only when the proxy has one) whose button removes it, as the lot's and the location's removal pages do. Both return to the deck page with a notice, and "Cancel" on every proxy page returns to the deck page.
7. **The counts follow spec 060 decision 12.** A deck's "cards" is its owned copies plus its proxies, in every zone, Considering included. The page head reads "<Format> · 69 cards · 58 owned · 11 proxy"; a zone's head "60 cards · 52 owned · 8 proxy" ("1 card", "1 proxy"); the counts of a group row are the group's Total; an empty zone reads "0 cards · 0 owned · 0 proxy". Spec 066's heads, where cards equals owned, are superseded here. The Decks page's head "6 decks · 379 cards" counts proxies in the cards, and its table is spec 060's: Deck, Format, Cards, Owned and Proxy (the tag or a muted dash); on a phone the line under the name is "<Format> · <n> owned" and the tag.
8. **A row is one printing, with or without owned copies.** A printing that has a proxy and no copy in the zone is a row of Owned 0 (shown as 0) and Proxy N, in its group and place as any row is (spec 066 decision 3). A row with both shows both. Total is Owned plus Proxy.
9. **Removing a deck removes its proxies, and says so.** The removal confirmation reads that the zones and its proxies go with it ("… and its 11 proxies" when it has any, the quantity). A deck whose zones hold lots is still refused, and a deck that holds only proxies is removable, because a proxy is not a copy of the collector's. *Alternative:* refuse while proxies exist; it would make a deck of a wish list unremovable.
10. **A format change moves proxies into Considering with the lots.** Every proxy of a dropped zone moves into the deck's Considering zone, merging by printing and finish into the proxy already there (the one there survives), all or nothing at 9,999 per proxy. It runs in spec 064's one transaction, after the lots. The notice keeps spec 064's first sentence for copies ("12 cards moved to Considering.", owned copies as spec 064 AC-2.5 counts them) and adds a second for proxies ("3 proxies moved to Considering.", "1 proxy"), each only when something moved. A proxy cap refusal reads "Nothing changed. <name> (<SET> · <number>) would have more than 9,999 proxies in one zone." on the Format page, 422, naming the first such proxy by card name, set code, collector number as a person reads it, language, then finish, after the lots' check has passed. *Alternative:* one sentence "15 cards moved, 3 of them proxies"; it breaks spec 064's text for a deck with no proxy.
11. **Proxies change only by hand (issue design decision 8; closes spec 065 decision 11's owed rule).** No way of adding, editing, moving, removing or scanning an owned copy, no bulk action, no import of lots and no catalog refresh creates, changes or removes a proxy. The only writers are the three pages of this spec, the format change (decision 10), the removal of a deck, and an import that carries proxies (decision 14).
12. **No ADR.** `deck_proxies` is one table under the deck model of ADR 0028; the choices above are the spec's. If the review disagrees, the coordinator hands out the next number.
13. **Routes.** A deck's URLs carry its location's id (spec 062 decision 4). A zone is named by its key in the path: `GET /decks/:deck_id/zones/:zone/proxies/new` (the chooser, then the form with `entry=<the printing's key>`) and `POST` to `/decks/:deck_id/zones/:zone/proxies`; a proxy by its own id under the deck: `GET /decks/:deck_id/proxies/:id/edit`, `PATCH /decks/:deck_id/proxies/:id`, `GET /decks/:deck_id/proxies/:id/removal/new` and `DELETE /decks/:deck_id/proxies/:id` (the pattern of the deck's and the location's removal routes). A zone key the deck lacks, another deck's proxy id under this deck, another account's deck, a place's or a zone's id and an id that is not digits only are 404 (AC-1.7). The names of the controllers and the exact paths are for the plan.
14. **Export and import: version 4 gains `proxies` (no release has shipped version 4; the maintainer's ruling of 2026-11-11 makes it required).** The latest tag is `v0.2.1`, whose tree has no `v4.schema.json`, so this changes the unreleased version 4 and not a new version 5 (issue design, data notes; `docs/releasing.md`; the format document's rule that a version's meaning never changes applies from its release). A file's `proxies` is a **required** list, beside `decks` and `lots`, of `{ deck, zone, entry, finish, quantity }`: `deck` and `zone` as a lot's `location` object names them, `entry` as a lot's entry, `finish` a string or `null`, `quantity` 1 to 9,999. The export always writes it (empty for an account with none), so the export side adds the list and nothing else. Its identity is the deck's comparison key, the zone key, the entry's type and source id and the finish. It carries no time, because the table's times are facts about the instance (the format document's rule for decks). The proxy object has no other field, as a lot's `location` object has none. A version 4 file written by an `edge` or `sha-*` image from before this change has no `proxies` and is not supported: it is refused as any schema-invalid file is, a header-level refusal naming `proxies` ("isn't a well-formed export: `proxies` is missing"), never a row problem; no release wrote one.
15. **An older file leaves proxies alone.** A version 1 to 3 file has no way to name a proxy and, as it can name no deck, removes none: the proxies stay, the preview says "This file was written before proxies existed, so your proxies would stay." (after the decks' sentence of spec 062 AC-7.4, in the same place), and the fingerprint holds nothing of them. A version 4 file always names the full proxy set and replaces the collector's proxies with its own, as it replaces the decks and the lots, and removing any needs the confirmation (decision 16).
16. **The import's proxy outcomes.** Held proxies and the file's rows are compared by identity: added (a row no held proxy has), changed (a held proxy with another quantity), unchanged and removed (a held proxy no row has, which includes the proxies of a deck or a zone the file drops). Counts in the import are rows (Terms). A file with a problem proxy row can't be applied (decision 18). The apply's removal confirmation reads "I understand this removes N lots, M locations, K decks and P proxies" (the parts that apply), and its notice "…; 2 proxies added, 1 changed, 1 removed" (zero parts left out) after the decks' part. Applying a file that changes only proxies writes them and clears no working state. A deck an import removes takes its proxies with it, and a deck whose format an import changes keeps the file's proxies and loses a held proxy of a dropped zone as a removed one (an import moves nothing into Considering: spec 062 AC-8.2; spec 064 Non-Goals). A held proxy whose identity only a problem row has is counted as removed in the preview, which can't be applied then (lots' "held by a problem row" outcome exists to keep a stale apply from removing it, and no apply happens). The removed proxies are listed by deck key, zone key, card name, set code, collector number as read, language and finish.
17. **The backup, the upgrade and the guards.** `deck_proxies` is in the primary database, so a backup holds it with no change to the backup. The migration is additive and creates one table. The upgrade proof's next seed adds a proxy so the next release's proof carries one across (spec 031's coverage rule), and the migration needs no entry in `expected_changes.yml` (it changes no data a release holds). The format document's Coverage tables list the table and every column, which the suite compares with the database (spec 017 FR-9).

18. **Proxy rows are read one at a time, as lots are (the answer to how a proxy problem is built).** Today only a problem under `/lots/N` becomes a problem row and any other pointer refuses the whole file (`CollectionImport::ROW`), so this spec widens the reader: the file's proxies are checked one at a time against the schema's `$defs/proxy` (which keeps 20,000 proxies inside the memory bar), and a problem under `/proxies/N` is a problem row of that proxy, shown in the preview's own list as "Proxy N" with the field and the reason, never a refusal of the whole file; a `proxies` that isn't a list, or a header problem, still refuses the file. The rules, each with its home: **format rules** (the schema and `ExportFormat::Rules`, with invalid examples in the format document): the schema's keywords for a proxy (type, required fields, no other field, `quantity` 1 to 9,999, `entry`'s form), `duplicate_proxy` ("Same deck, zone, card and finish as proxy M", a second row of one identity, added to `RULES`) and `unknown_location` extended to a proxy whose deck the file's `decks` don't list ("Its deck “X” isn't one of the file's decks."). **The reader's resolvable checks** (like a lot row's, not in `RULES`), in this order after the format's: `unknown_type`, `not_in_catalog`, `finish_not_listed` (a non-null finish the entry doesn't list) and `unknown_zone` (the deck's format lacks the zone key). A null finish is never a problem, and the reader never compares a proxy's collectible type with its deck's (decisions 2, 19).
19. **A proxy's printing is of its deck's collectible type when it is created.** The add pages list only printings of the deck's type, the create refuses any other (404), and the model refuses it on create, as it does the finish (decision 2); it is not re-checked on a later save, because a format change can switch a deck's collectible type (spec 064 decision 1: the format is a type and format pair), and the proxies of the old type then stay in their zones and move into Considering with the rest. The import therefore has no type check (a state the app itself can make must restore). A deck whose collectible type the instance no longer registers keeps showing and exporting its proxies, and its chooser and add answer 404 for lack of a vocabulary to name the finish and a search to list from. The form and the create accept only what the chooser can list (a searchable printing of the deck's type); any other entry key is 404.

## User Stories

### Story 1: Add a proxy to a zone

**As a** collector
**I want** to record a card I don't own in a zone of my deck
**So that** the deck lists everything it needs.

**Acceptance criteria:**

- [ ] **AC-1.1** Given a deck page When it is read Then each zone's head has "Add a proxy" (a ghost small button with a plus, a link to the chooser, with the zone's name after it for screen readers), after the counts and at the end of the head; an empty zone has it too; and the page still has no `form`
- [ ] **AC-1.2** Given the chooser for a zone When it is opened Then the answer is 200, the title names the deck and the zone ("Add a proxy to Izzet Tempo › Main · Collector"), the page is a detail page with a back link to the deck page, and the catalog's name field and set filter are shown with no results until a name or a set is given
- [ ] **AC-1.3** Given a name that matches printings of the deck's collectible type When it is searched Then the matching cards are listed as the card search lists and pages them (12 cards a page), each card's newest printings (at most 10) by card name with `SET · number` in the mono line and its language, each with a "Choose" link carrying the printing's key, a card with more printings says how many are shown and to choose a set, a printing of another collectible type is not listed, and a retired printing is not listed
- [ ] **AC-1.4** Given a chosen printing that lists finishes When the form is shown Then it shows the printing's name and `SET · number`, a Finish select of its finishes (nothing chosen when there are several, the one chosen when there is one), a Quantity field with 1, "Add proxy" and "Cancel", and a printing that lists no finish shows no Finish select
- [ ] **AC-1.5** Given a valid choice of finish and a quantity from 1 to 9,999 When the form is submitted Then a proxy of that zone, printing, finish and quantity exists, the response is 303 to the deck page, the notice reads "Added 2 proxies of Lightning Bolt (MH2 · 138, Foil) to Izzet Tempo › Main." ("1 proxy", the finish after the number only when the proxy has one), no lot is created or changed, and the zone's table shows the row with its Proxy and Total
- [ ] **AC-1.6** Given a zone that already has a proxy of that printing and finish When another quantity is added Then the proxy is the same row with the quantities added (same id), and a second finish of the printing is a second proxy of the same row on the page
- [ ] **AC-1.7** Given another account's deck, a place's id, a zone's id, an id that is not digits only, a zone key the deck lacks, or a printing key no entry has When any of the chooser, the form or the create is requested Then the answer is 404 and nothing is written; a request that isn't signed in is sent to sign in
- [ ] **AC-1.8** Given a quantity that isn't a whole number from 1 to 9,999, or a missing finish for a printing that lists finishes, or a finish the printing doesn't list When the form is submitted Then the answer is 422, the form is shown again with what was typed and the field's sentence ("Enter a number from 1 to 9,999.", "Choose a finish.", "That finish isn't available for this printing."), and nothing is written
- [ ] **AC-1.9** Given a proxy of 9,990 and an add of 10 When it is submitted Then the answer is 422 with "A zone can hold at most 9,999 proxies of one printing and finish." and the proxy is unchanged; two submissions of one add together never create two rows of one zone, printing and finish
- [ ] **AC-1.10** Given a printing of a collectible type other than the deck's, a retired printing, a printing that isn't of the kind the search lists, an entry key no entry has, or a deck whose collectible type the instance no longer registers When the chooser, the form or the create is requested Then the answer is 404 and nothing is written
- [ ] **AC-1.11** Given a request that carries an `account_id`, a zone id, a kind or a user id as a parameter When it is handled Then each is ignored: the account is the signed-in one and the zone is the path's key within the deck

### Story 2: See proxies in the zone table and the heads

**As a** collector
**I want** a zone's proxies beside the copies I own
**So that** I read the whole deck at a glance and never mistake a proxy for a card I own.

**Acceptance criteria:**

- [ ] **AC-2.1** Given a zone with proxies When its table is rendered Then a printing with proxies shows the `ProxyTag` ("Proxy 2") in its Proxy cell, a printing without shows a muted dash and no tag, Owned is the number of owned copies in the zone (0 when there are none), and Total is Owned plus Proxy in every row
- [ ] **AC-2.2** Given a printing with proxies of two finishes in one zone When its row is rendered Then it is one row whose Proxy is the sum of the two, and a printing with a proxy and no owned copy is a row of its own in the group and place any row has
- [ ] **AC-2.3** Given a deck with 58 owned copies and 11 proxies When its page is opened Then the head reads "<Format> · 69 cards · 58 owned · 11 proxy", a zone's head reads "60 cards · 52 owned · 8 proxy", a group row's count is its Total, "1 card" and "1 proxy" are singular, and an empty zone reads "0 cards · 0 owned · 0 proxy" with the sentence in its block
- [ ] **AC-2.4** Given a table container narrower than 640px When it is rendered Then Owned and Proxy are hidden, the line under the name carries `SET · number`, the `ProxyTag` of a row that has proxies and any legality marker, and Cost, Total and the menu stay, the menu cell narrow and empty for a row with no proxy (spec 060 decision 9, AC-3.6)
- [ ] **AC-2.5** Given a table container of 640px or wider When it is rendered Then the columns are Card, Cost, Owned, Proxy, Total and the menu, in that order, the Cost, Owned, Proxy, Total and menu columns have the same left edge and width in every zone table (spec 060 decision 25, AC-3.11), and a 60-character name with no space still wraps inside the Card cell
- [ ] **AC-2.6** Given a card row with a proxy When it is rendered Then it has a menu cell with the trigger "Actions for <card> <set · number>" listing "Change proxy count" and then, after a separator, "Remove proxy" (danger, last), a row with proxies of two finishes lists the pair for each, naming its finish, and a row with no proxy has an empty menu cell with no trigger
- [ ] **AC-2.7** Given the row's menu When its markup is read Then it contains links to pages and no `form`, no "Use my copy", "Add a new copy" or "Move copies", and the page has no way of adding or moving an owned copy
- [ ] **AC-2.8** Given a proxy of a retired printing, or one whose printing has no extension record When its zone is rendered Then the row is shown like any other (retired: with its card name; no extension record: in Other with a muted dash for its cost and no marker, spec 066 AC-6.6)
- [ ] **AC-2.9** Given a proxy of a printing that is not legal in the deck's format When its row is rendered Then it has the legality marker as an owned card's row does
- [ ] **AC-2.10** Given decks with few and with many zones, rows, lots and proxies When a page is rendered Then the page runs at most one statement more than spec 066 AC-2.10 allows (the proxies, summed per zone, printing and finish), the same whatever the number of zones, rows, lots and proxies, and no row triggers a query of its own
- [ ] **AC-2.11** Given the deck page at 360px, 640px, 768px and 1280px in the light and the dark theme, and the worst case (a 60-character name with no space, a six-symbol cost, a marker, the Proxy tag with a four-digit count, a three-digit Total, the menu) When it is rendered Then it has no horizontal overflow, the zone heads' counts are uncut (own line below 640px, as spec 060 AC-3.7), and every colour comes from the design system's tokens
- [ ] **AC-2.12** Given the `ProxyTag` When it is rendered Then it is `c-proxy` with the word "Proxy" and the number (a dashed outline, readable without colour) and the card page, the collection, bulk mode and the scanner show no tag

### Story 3: Change a proxy's quantity or remove it

**As a** collector
**I want** to change how many proxies of a card a zone has, or remove them
**So that** the list matches the deck I'm building.

**Acceptance criteria:**

- [ ] **AC-3.1** Given a proxy When "Change proxy count" is followed Then a page names the deck and zone, the printing and its finish, shows a Quantity field holding the count, "Save" and "Cancel", and is a detail page with a back link to the deck page
- [ ] **AC-3.2** Given a quantity from 1 to 9,999 When it is saved Then the proxy has it (same id), the response is 303 to the deck page, and the notice reads "Changed the proxies of Lightning Bolt (MH2 · 138, Foil) in Izzet Tempo › Main to 4." (the finish only when the proxy has one); a quantity equal to the count is a success that writes nothing
- [ ] **AC-3.3** Given 0, a negative number, a number over 9,999, text or nothing When it is saved Then the answer is 422, the page is shown again with what was typed and "Enter a number from 1 to 9,999." (with "To remove it, use Remove proxy." added for 0), and the proxy is unchanged
- [ ] **AC-3.4** Given a proxy When "Remove proxy" is followed Then a confirmation page asks "Remove the proxies of Lightning Bolt (MH2 · 138, Foil) from Izzet Tempo › Main?", works without scripting, and removes nothing by itself; its button removes that proxy only (a proxy of the printing's other finish stays) and answers 303 to the deck page with "Removed the proxies of Lightning Bolt (MH2 · 138, Foil) from Izzet Tempo › Main."
- [ ] **AC-3.5** Given a proxy removed in another tab When its change or removal page is opened or submitted Then the answer is 404 and nothing else changes; a second `DELETE` is 404
- [ ] **AC-3.6** Given another account's proxy, a proxy of another deck under this deck's path, a place's or a zone's id as the deck, or an id that is not digits only When any change or removal request is made Then the answer is 404 and nothing is written
- [ ] **AC-3.7** Given any change or removal When it runs Then no lot, location, deck or other proxy changes and no owned count moves

### Story 4: A proxy is never owned and changes only by hand

**As a** collector
**I want** my collection to count only what I own
**So that** a list of cards I need never inflates my collection.

**Acceptance criteria:**

- [ ] **AC-4.1** Given a deck with proxies When the collection page, its table and grid, the card page's "Your copies" and owned quantities, the Decks page's Owned counts and the export's `lots` are read Then none counts or lists a proxy, and adding, changing or removing a proxy changes none of them
- [ ] **AC-4.2** Given a zone with a proxy of a printing When a copy of that printing is added to, moved into, edited into, bulk-moved into, typed or scanned into the zone, or moved out of it, or its lot is removed Then the proxy is unchanged (same id, quantity and times), and the zone's row shows the owned copies beside it
- [ ] **AC-4.3** Given a deck with proxies When an import applies a file of lots that doesn't touch the deck's proxies (an older file), or a catalog refresh runs Then no proxy is created, changed or removed
- [ ] **AC-4.4** Given a deck with proxies and no lot When the deck's removal page is opened Then it is the confirmation (not a refusal), and a deck whose zones hold a lot is the refusal as today whatever its proxies

### Story 5: The Decks page and removing a deck

**As a** collector
**I want** the Decks page to show how many proxies each deck has
**So that** I see which decks are complete.

**Acceptance criteria:**

- [ ] **AC-5.1** Given the Decks page When it lists decks of 58 owned copies and 11 proxies, of 12 copies and no proxy, and of no card Then Cards reads 69, 12 and 0, Owned 58, 12 and 0, Proxy shows the tag "Proxy 11", a muted dash and a muted dash, and the head's count "6 decks · 379 cards" sums owned and proxies
- [ ] **AC-5.2** Given the Decks page in a table container narrower than 640px When it is rendered Then Format, Owned and Proxy are hidden, the line under the deck's name reads "<Format> · <n> owned" followed by the `ProxyTag` for a deck that has proxies, Cards stays, and there is no horizontal overflow at 360px with a 60-character name with no space
- [ ] **AC-5.2a** Given the Decks page in a table container of 640px or wider (at 640px, 768px and 1280px, in both themes) When a deck has proxies Then the columns are Deck, Format, Cards, Owned, Proxy and the row's actions (Rename, Change format, Remove, as spec 062 and 064 made them), there is no horizontal overflow, and the tag and the three buttons don't cut each other
- [ ] **AC-5.3** Given the Decks page When it is rendered Then it runs a bounded number of statements however many decks it lists (one more than spec 062 AC-4.7: the proxies grouped by deck)
- [ ] **AC-5.4** Given a deck with proxies and no lot When its removal is confirmed Then the confirmation said that the zones and its proxies go with it ("…and its 11 proxies"), and the deck, its zones and its proxies are gone, the proxies of no other deck and no lot changing
- [ ] **AC-5.5** Given a deck removed in another tab or its zone removed by an import When a proxy page of it is requested Then the answer is 404

### Story 6: Changing a deck's format moves proxies into Considering

**As a** collector
**I want** a format change to keep my proxies
**So that** a deck never loses what I recorded in a zone its new format lacks.

**Acceptance criteria:**

- [ ] **AC-6.1** Given a Commander deck with proxies in Commander, in Main and in Considering When it is changed to Modern Then the proxies of Commander are in Considering, the proxies of Main and Considering are where they were, the Commander zone is gone with nothing in it, and no proxy is lost or created
- [ ] **AC-6.2** Given a proxy in a dropped zone with the printing and finish of a proxy already in Considering When the format is changed Then they are one proxy with the quantities added and the one that was in Considering survives (same id); with no such proxy the moved proxy is the same row (same id) in Considering, and proxies of one printing and finish from several dropped zones become one
- [ ] **AC-6.3** Given a change that moves lots and proxies When it succeeds Then the notice reads "Changed “<name>” to Modern. 12 cards moved to Considering. 3 proxies moved to Considering." ("1 proxy"; the first sentence only when copies moved and the second only when proxies moved), and the two counts are the quantities that moved out of dropped zones, merged ones included
- [ ] **AC-6.4** Given a change that would make a proxy in Considering hold more than 9,999 When it is saved Then the response is 422, the Format page is shown again with the format kept and the alert "Nothing changed. <name> (<SET> · <number>) would have more than 9,999 proxies in one zone." naming the first such proxy by card name, set code, collector number as read, language and finish (decision 10), and the deck's format, every zone, lot and proxy are as before
- [ ] **AC-6.5** Given a change whose lots would pass the lots' cap and whose proxies would pass theirs When it is saved Then the lots' refusal (spec 064 AC-2.6) is the one shown
- [ ] **AC-6.6** Given a change between formats with the same zones, or a deck whose dropped zones hold no proxy When it is saved Then no proxy changes and no sentence about proxies is added to the notice
- [ ] **AC-6.7** Given a failure part way through the change When it fails Then the deck, its zones, its lots and its proxies are as they were (the change is one transaction)
- [ ] **AC-6.8** Given a deck whose dropped zones hold proxies and a deck with no Considering row When the format is changed Then the proxies move into the Considering zone the change makes (spec 064 AC-2.10)

### Story 7: Proxies in the export and the import

**As a** collector
**I want** my proxies in my export and restored by my import
**So that** my decks are whole when I move to another instance.

**Acceptance criteria:**

- [ ] **AC-7.1** Given an account with proxies When it is exported Then the file is version 4 with a `proxies` list (present and empty for an account with none) whose elements are `{ deck, zone, entry, finish, quantity }`, `deck` the deck's name as stored and `zone` the zone's key, `entry` as a lot's, in an order the same for two exports of one collection, and no internal id and no time
- [ ] **AC-7.2** Given the export When its queries are counted Then the number doesn't depend on the number of proxies (one read of the proxies with their zones, decks and entries), a deck or a zone changed between the reads is handled as spec 062 AC-6.4 handles it, and a proxy of a type the instance no longer has still exports
- [ ] **AC-7.3** Given the format document and the schema `v4.schema.json` When they are read Then `proxies` is a required list whose elements are the proxy object (`deck`, `zone`, `entry`, `finish` string or null, `quantity` 1 to 9,999, no other field), `duplicate_proxy` and the extended `unknown_location` are in its rules, each with an invalid example that fails for exactly that reason and its entry in `problems.json`, the version's row in the history says it carries proxies, the paragraph on older files says a file of version 1 to 3 leaves proxies alone, the "same collection" rule compares proxies as sets of deck name as written, zone key, entry identity, finish and quantity, with `comparison/` examples for equal and unequal proxies, an invalid example for a version 4 file without `proxies` (failing as `required`, with its entry in `problems.json`), and the Coverage tables list `deck_proxies` ("Exported") and each column: `id`, `account_id`, `created_at` and `updated_at` left out, `catalog_entry_id` as `entry`, `location_id` as `deck` (its Why column says the zone is the `zone` field) and `finish` and `quantity` as themselves; the app's schema copy is byte-identical and `spec/export_format_document_spec.rb`'s lists name the new rows (spec 017 FR-9; ADR 0021)
- [ ] **AC-7.4** Given a file exported from an instance with proxies When it is previewed and applied on a fresh instance (same catalog) Then the proxies are the same (deck, zone, printing, finish, quantity), a second export of that instance is "the same collection" as the first, and applying the same file again is refused as nothing to change
- [ ] **AC-7.5** Given a version 4 file with no `proxies`, or a `proxies` that isn't a list When it is previewed Then it is refused whole, as any schema-invalid file is (422, the upload page, no rows), with "isn't a well-formed export: `proxies` …" naming the field, it isn't a row problem, and nothing is stored
- [ ] **AC-7.6** Given a file whose proxy rows have a quantity of 0, a field of the wrong form, an extra field, a deck the file doesn't list, the same identity twice, an unknown type, an entry not in the catalog, a finish the entry doesn't list, or a zone key the deck's format lacks When it is previewed Then each such row is a problem row of its own list ("Proxy N", the field and the reason, with `duplicate_proxy`, `unknown_location`, `unknown_type`, `not_in_catalog`, `finish_not_listed` and `unknown_zone` named in the rules' order of decision 18), a proxy with no finish is not a problem, the lots' rows are judged as before, and the file can't be applied
- [ ] **AC-7.7** Given a file and held proxies When the plan is made Then each proxy has exactly one outcome by identity (the deck's comparison key, the zone key, the entry and the finish): added, changed (another quantity), unchanged or removed, the held proxies of a deck or zone the file drops among the removed, and the preview shows a Proxies section with the four counts (rows) and the first `LIST_LIMIT` removed proxies, in the order of decision 16, each "in <Deck › Zone>", then "and N more"
- [ ] **AC-7.8** Given a version 1 to 3 file When it is previewed Then the preview says "This file was written before proxies existed, so your proxies would stay." after the decks' sentence of spec 062 AC-7.4 (one paragraph, the decks' first), the plan has no proxy outcome, the fingerprint holds nothing of proxies, and applying the file leaves every proxy as it is
- [ ] **AC-7.9** Given a plan that removes a proxy When it is previewed Then the apply form needs the confirmation, which reads "I understand this removes N lots, M locations, K decks and P proxies" (the parts that apply), and an apply without the box is refused as for a removed lot (spec 028 AC-3.5)
- [ ] **AC-7.10** Given a plan with proxies When it is applied Then the proxies are written in the one transaction with the lots and decks (the proxies a plan removes are deleted with the removed lots, before the zones and decks they sit in; an added or changed proxy is an upsert on its identity and keeps its id when changed; a removed deck's or zone's proxies are among the removed outcomes, so the foreign key's cascade finds none left), nothing is written for an unchanged one, and the notice adds "; 2 proxies added, 1 changed, 1 removed" (zero parts left out) after the decks' part
- [ ] **AC-7.11** Given a plan that changes only proxies When it is applied Then it writes them, clears no working state (a selection, a number-entry list, a sitting or an undo record), and a second apply is "nothing to change"
- [ ] **AC-7.12** Given the preview and the apply When the stored fingerprint is compared Then a proxy added, removed or changed in quantity between the preview and the apply, or a deck or zone it sits in changed, makes the preview stale (the fingerprint covers each added, changed and removed proxy by its deck key, zone key, entry, finish and quantity)
- [ ] **AC-7.13** Given a file of 50,000 lots, 100 decks and 20,000 proxies When it is previewed and applied Then the time and the memory bars of spec 062 AC-8.10 hold, asserted by a timing example, with the measurement recorded in `verification.md`
- [ ] **AC-7.14** Given the export, the preview and the apply's code When `spec/collection_export_core_spec.rb`, `spec/collection_import_core_spec.rb`, `spec/import_apply_core_spec.rb` and `spec/deck_core_spec.rb` read it Then none names a collectible, a source or a format, and the zone key `considering` is the only zone key a core file names

### Story 8: The data and the guards

**As an** agent or an operator
**I want** the table to follow the project's rules
**So that** an upgrade never loses data and no tenant sees another's.

**Acceptance criteria:**

- [ ] **AC-8.1** Given the migration When it runs on a database of the previous release (`bin/rails db:prepare` on boot) Then it creates `deck_proxies` and changes no other table; it is reversible; and the table has `account_id` (a foreign key to accounts, `on_delete: :cascade`, indexed), the zone's `location_id` (a foreign key to locations, `on_delete: :cascade`, indexed), `catalog_entry_id` (a foreign key to the catalog), `finish`, `quantity` (a check from 1 to 9,999), the times, and a unique index on zone, printing and finish that also holds for a proxy with no finish
- [ ] **AC-8.2** Given a proxy When it is saved Then its model refuses a zone that isn't a location of kind `deck_zone` of the proxy's own account, a printing of a collectible type other than the deck's, a finish the printing doesn't list or a missing one for a printing that lists some (all on create, and the finish when it is set; decisions 2, 19), and a quantity outside 1 to 9,999
- [ ] **AC-8.3** Given another account When it requests any proxy page of a deck, zone or proxy that isn't its own Then every one is 404, proven by a request spec per page and per verb (the multi-tenancy rule), and the admin pages show no proxy, deck or location
- [ ] **AC-8.4** Given the account's deletion When an account with proxies is deleted Then its proxies go with it by the foreign keys, `Account` still deletes its lots before its locations, and `spec/models/account_spec.rb`'s order guard still holds
- [ ] **AC-8.5** Given `spec/backup_guards_spec.rb` and a backup When a backup is made and restored Then the proxies are restored with the primary database, no attachment or fifth database is added, and the backup's documents need no change except what lists the tables, if one does
- [ ] **AC-8.6** Given `script/upgrade/seeds/next.rb` When the upgrade proof runs in CI Then the seed has a proxy beside its deck and its lot, so the proof carries a proxy across, and `ruby script/upgrade/guard.rb` passes
- [ ] **AC-8.7** Given `spec/deck_core_spec.rb` When it reads the proxies' core files (the model, the controllers, the views, the page's and the listing's changes, and the import's and export's proxy code) Then none names a game, a source, a format or a zone key but `considering`, comments included, its list names every new file the globs don't match and its count is the present count (33) plus those files; the chooser reuses the catalog's search and the vocabulary's finishes, so nothing of a game is named

### Story 9: The pages follow the design system, in both themes

**As a** collector on a phone, a tablet or a desktop
**I want** every proxy page to fit my screen and read in both themes
**So that** I never scroll sideways or squint.

**Acceptance criteria:**

- [ ] **AC-9.1** Given the chooser, the form, the change page and the removal page at 360px, 640px and 1280px in the light and the dark theme When they are rendered Then none has horizontal overflow, every control is at least 44px on a coarse pointer, every field has a visible label, an error is shown with its field and read by its `aria-describedby`, and every colour comes from the design system's tokens
- [ ] **AC-9.2** Given the design system When it is read Then `DeckPage.md` (the Add a proxy button, the menu column, the heads' counts, an owned-and-proxy row), `DecksIndex.md` (the Proxy column and its phone fold), `ProxyTag.md` (the tag's live use) and the README's Decks and Components sections are updated, `AddProxy.md` documents the chooser, the form, the change page and the removal page with their markup and each new class, and the previews of the two new screens exist in a wide and a phone width in both themes
- [ ] **AC-9.3** Given the new CSS When it is read Then it is in `collector/additions.css` under its own heading comment (`spec/design_system_files_spec.rb`) and uses token variables and `c-*` classes only

## Functional Requirements

### FR-1: Proxies

A proxy is a row of `deck_proxies` (decision 1) added, changed and removed by the pages of Stories 1 and 3, created and merged by the format change (Story 6), removed with a deck (Story 5) and written by an import (Story 7).

**Must:** keep a proxy out of every count and list of owned copies; read and write only the signed-in account's rows; merge an add into the proxy of its zone, printing and finish; keep the cap per proxy and refuse, changing nothing, past it; render with no network access.
**Must not:** create a lot, change a lot or read one to decide a proxy; change a proxy when a copy is added, moved, edited, removed, scanned or imported; accept an account, a zone id, a kind or a finish the printing doesn't list from a request.

### FR-2: The deck page and the Decks page

The deck page shows proxies as Stories 2 and 3 say, in spec 066's and spec 060's markup and classes plus the menu column, the Add a proxy button and the heads' proxy counts; the Decks page shows the Proxy column and the cards.

**Must:** read the proxies in one statement for the whole page; count a deck's cards as owned plus proxies; keep a legal or illegal printing marked as for owned copies.
**Must not:** add a form to the deck page; show a proxy as owned or in the Owned cell; offer an item other than the proxy items.

### FR-3: The format change

The proxies of dropped zones move into Considering in spec 064's transaction (decision 10).

**Must:** move them after the lots, merge by printing and finish, judge the cap on what holds in the transaction and write nothing past it, and keep spec 064's other rules.
**Must not:** change the lots' notice or cap sentence; move a proxy out of Considering or recreate its row.

### FR-4: Export and import

Format version 4 carries `proxies` (decision 14); the export, the reader's checks, the plan, the fingerprint, the preview and the apply cover them (Story 7).

**Must:** write the format document, both schema copies, the examples and the Coverage tables in the same change; keep the export's read count independent of the number of proxies; make the apply one transaction with the lots and decks.
**Must not:** add a version number; put an internal id or a time in the file; name a collectible, a source or a format in a core file.

## Non-Functional Requirements

### Performance

- The deck page, the Decks page and the export run a number of statements that doesn't grow with proxies (AC-2.10, AC-5.3, AC-7.2). The import's preview and apply stay within spec 062 AC-8.10's bars with 20,000 proxies (AC-7.13). Proxy rows are written in batches of `CollectionImport::BATCH_SIZE`.

### Security

- Every read and write goes through `Current.account` (the deck by its location id, the zone by its key within the deck, the proxy by its id within the deck's zones); another account's anything is 404 (AC-1.7, AC-3.6, AC-8.3). No parameter names an account or a zone id; no `permit!`; every value that reaches SQL is bound; output is escaped. The signed-out visitor is sent to sign in and no page is part of the open catalog. No proxy appears on any admin page.

### Reliability and the hosted door

- The migration is additive and safe to run unattended from any prior version (`.claude/rules/sqlite-and-migrations.md`). The export and import round-trip (AC-7.4). A catalog refresh never changes a proxy, and a proxy of a retired printing is kept and shown (AC-2.8, AC-4.3). Hosted-door rule 2 (the operator sees no collection detail) holds: no admin page shows a proxy. A proxy adds one tenant-scoped table with the same unbounded-rows property as lots and no recurring or background cost.

### Accessibility

- The tag is a word and a dashed shape, never colour alone; each menu trigger is named for its row; a menu item names its finish when a row has two; every field has a label and an error is tied to it; controls are at least 44px on phones (AC-9.1).

### Design system and documentation

- Uses token variables and `c-*` classes only; new CSS goes in `collector/additions.css` under its own heading, with a document per pattern (AC-9.2, AC-9.3). The area docs `collection-and-lots.md` (the deck page, proxies, the format change, the invariant "A copy that reaches a zone never changes a proxy"), `data-portability.md` (version 4's proxies, rules, plan, fingerprint, apply, constants), `tenancy-and-accounts.md` (the new routes' 404 rule and the table), `CLAUDE.md`'s deck sentence and `docs/export-format/README.md` change in the same PR (`.claude/rules/documentation.md`).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Another account's deck, a place's or a zone's id, an id with letters, a zone key the deck lacks, another deck's proxy id | 404 (AC-1.7, AC-3.6) |
| Signed out | Sent to sign in, as the other deck pages do |
| A quantity that isn't 1 to 9,999 on add or change | 422, the form again with its sentence and what was typed |
| 0 on "Change proxy count" | 422, "Enter a number from 1 to 9,999. To remove it, use Remove proxy." |
| A missing or unlisted finish | 422 "Choose a finish." / "That finish isn't available for this printing." |
| An add or a move that passes 9,999 in one proxy | 422 "A zone can hold at most 9,999 proxies of one printing and finish." / the format change's refusal (AC-6.4); nothing written |
| Two submits of one add together | One proxy row, quantities added or the second refused at the cap, never two rows or a 500 |
| A proxy or a deck removed in another tab, then its page used | 404; nothing else changes |
| A printing retired by a refresh after a proxy was added | The proxy is kept and shown; it can't be chosen for a new proxy |
| A catalog with no matching printing | The chooser says "No cards match." with the search kept |
| A deck whose format the instance no longer registers | The page shows its proxies as it shows owned copies (flat or grouped by the type's vocabulary); adding a proxy still works for its zones |
| A deck whose collectible type the instance no longer registers | Its proxies show and export; adding a new one answers 404 (decision 19) |
| An import row that can't be applied | A problem row with its reason; the file can't be applied (AC-7.6) |
| A version 4 file without `proxies` | Refused as not well-formed, naming `proxies` (AC-7.5) |
| An import that drops a deck or a zone that holds proxies | Those proxies are removed outcomes; the confirmation names them |

## Open Questions

None. Decisions 9, 14 and 15 are ruled (the maintainer, 2026-11-11, at Gate A); decisions 3, 5, 10, 18 and 19 are approved as written.

## Out of Scope (Future Considerations)

- Replacing a proxy with an owned copy ([#257](https://github.com/plainprogrammer/Collector/issues/257)); add to a deck from a card page ([#255](https://github.com/plainprogrammer/Collector/issues/255)); the shape panel ([#256](https://github.com/plainprogrammer/Collector/issues/256)); Free to use and In decks ([#50](https://github.com/plainprogrammer/Collector/issues/50)).
- Deck checks: size, copy limits and a flag for owned plus proxy of one card ([#258](https://github.com/plainprogrammer/Collector/issues/258), 2.0).
- Moving a proxy between zones; a note, a condition or a price on a proxy; a bulk edit of proxies.

## Supersedes and updates

- **Supersedes, from #254,** the parts of spec 066 that kept proxies out: decision 4's counts (cards equal owned, no proxy count in the heads), decisions 7 and 9 (no menu column, no row menu), the page's Goal that it is read-only and its Non-Goals bullet on proxies, AC-1.3's and AC-2.1's head texts ("58 cards · 58 owned", "12 cards · 12 owned"), AC-1.6 (no proxy control, count or tag, a dash in every Proxy cell), AC-2.3's "Proxy a muted dash and Total equal to Owned in every row", AC-2.7's "0 cards · 0 owned", AC-4.2's "no row menu", AC-2.10's statement bound (it gains one), AC-5.3's phone line and its "columns shown are Card, Cost and Total" (they gain the tag and the menu), AC-6.2's file count, and FR-2's "Must not … add a row menu … show a proxy count". Spec 066's other rules stand: rows per printing, the order, the legality marker, the phone's columns, the page's 404 rule, and no way of adding or moving owned copies.
- **Restores** the rules of spec 060 that spec 066 suspended until #254: decision 10 (the heads' counts and "Add a proxy"), decision 25's menu column, AC-3.5, AC-3.7, AC-3.9 and AC-3.11 (the menu column's width and the heads). **Supersedes** spec 060 decision 17 and AC-3.10 in part: this spec's row menu has the proxy items only; "Use my copy" and "Add a new copy" come with #257 and an owned-only row's "Move copies" is not built (decision 5).
- **Supersedes** spec 062 decision 5's "#254 adds the Proxy column", AC-3.1's and AC-3.2's removal question (it names the proxies), AC-4.3's columns, AC-4.4's "Cards and Owned are one number", AC-4.5's phone line (the tag), AC-4.7's statement bound (one more), AC-7.6's confirmation text, AC-7.7's "nothing to change", AC-8.1's apply order and AC-8.8's notice (they gain proxies); and the part of spec 062 that says spec 060's Decks page rules wait for #254.
- **Supersedes** spec 064 Non-Goals' "nothing here reads or moves one (a proxy)" and extends AC-2.1, AC-2.5, AC-2.6, AC-2.7, AC-2.8 and AC-2.10 for proxies (decision 10, Story 6).
- **Closes** spec 065 decision 11's owed rule ("A copy that reaches a zone through a picker never changes a proxy"): AC-4.2 enforces it.
- **Extends** export format version 4 (spec 062 decision 4; the document's history row for version 4) with `proxies`, since no release has shipped it (decision 14); and **widens** the reader of spec 025 and spec 062 AC-6 to AC-8 (a problem under `/proxies/N` is a row problem, decision 18; the fingerprint, the removal confirmation, the notice and the preview's sections gain proxies).
- **Updates** the design system's `DeckPage.md`, `DecksIndex.md`, `ProxyTag.md` and README, which spec 060 wrote for the full page and specs 062 and 066 reduced until #254.
- Recorded in the specs index in both directions.

## Documents and Files Changed

Listed so the plan can name them; the plan decides the code.

- `docs/export-format/README.md`, `v4.schema.json` (and the app's copy in `app/models/export_format/`), `examples/` (valid, invalid and `problems.json`): version 4's `proxies`, its rules and Coverage rows.
- `docs/design-system/components/DeckPage.md`, `DecksIndex.md`, `ProxyTag.md`, `AddProxy.md` (new), the README's Components and Decks sections, previews of the two new screens, and `collector/additions.css` only where a new pattern needs it.
- `docs/architecture/collection-and-lots.md`, `data-portability.md`, `tenancy-and-accounts.md`, `CLAUDE.md`'s deck sentence, `docs/specs/README.md` (this spec's row and the supersessions), `docs/releasing.md`'s upgrade notes (the migration), `spec/deck_core_spec.rb` (the new files and the count).
- New: the migration and `deck_proxies` model, the proxy controllers, views and route entries, the form object, the page's and listing's proxy reads, the format change's proxy move, the export's, reader's, plan's, fingerprint's, preview's and apply's proxy code, `script/upgrade/seeds/next.rb`'s proxy, and their specs (model, request, system, import round-trip and timing).

## Verification

Written at plan time into `verification.md`: each AC with the spec that proves it; the system specs (headless Firefox) measure overflow at 360px, 640px, 768px and 1280px in both themes and exercise the add, change and remove flows without scripting; the round-trip example exports and applies on a fresh account; the review's screenshots of the deck page with proxies and of the new pages at 360px and 1280px, light and dark, are kept with the spec.
