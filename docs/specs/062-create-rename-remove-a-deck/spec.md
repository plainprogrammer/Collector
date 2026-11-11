# Feature 062: Create, Rename and Remove a Deck

**Status:** Approved
**Version:** 0.5.0
**Created:** 2026-11-10
**Last Updated:** 2026-11-10
**Depends on:** [spec 057](../057-deck-design-rules/spec.md) (the deck rules, navigation and pickers, #248; merged) and [spec 060](../060-deck-components/spec.md) (the deck components, `DecksIndex` and its New deck page, #249; merged); builds on [spec 029](../029-manage-locations/spec.md) (locations), [spec 032](../032-lot-in-a-location/spec.md) (a lot in a location), [ADR 0025](../../adr/0025-a-lots-location-is-part-of-its-identity.md) and, for the format, [spec 017](../017-export-format/spec.md), [spec 025](../025-import-preview/spec.md) and [spec 028](../028-apply-import/spec.md)
**Branch:** `062-create-rename-remove-a-deck`
**Issue:** [#49](https://github.com/plainprogrammer/Collector/issues/49)
**ADR:** [0028](../../adr/0028-decks-are-locations-with-zones.md), written with this spec: zones as child locations, formats from the collectible extension

**Frozen:** the current rules are in [`collection-and-lots.md`](../../architecture/collection-and-lots.md), [`data-portability.md`](../../architecture/data-portability.md) and [`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md) (whole spec); see the [specs index](../README.md)
**Plan:** retired in `624c513a993a037534b13f7572525d65e6c8238c`; read it with `git show 624c513a993a037534b13f7572525d65e6c8238c^:docs/specs/062-create-rename-remove-a-deck/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.5.0 | 2026-11-10 | Maintainer's approval of v0.4.0 (spec and ADR 0028, with the round 3 fix), with one change: the 500 limit's message says decks count toward it (AC-1.7a); the Open Questions entry that accepted the old sentence is dropped |
| 0.4.0 | 2026-11-10 | From review round 3 (the maintainer's extra round; no blocking, one major): a deck name over 60 characters after normalisation refuses the file (AC-6.7b); the apply rewrites a deck's zone names from the registration before inserting zones (AC-8.2a); AC-7.4d's scope and order, the order of the reader's refusals (AC-7.4e), the Locations page's 500 message and a lost-registration deck's rename and removal recorded |
| 0.3.1 | 2026-11-10 | D7 ruled by the maintainer (option A): AC-7.4a and AC-7.4b stand; AC-7.4d adds the apply's own guard against the unique name index. The reader-only rule for places plus held decks is named `too_many_with_decks` here (the maintainer's message calls it too_many_locations) so it is not confused with the format's own rule of that name |
| 0.3.0 | 2026-11-10 | From review round 2 (no blocking, six major): the apply resolves a place key among places and a zone by its (deck key, zone key) pair; deck URLs use the deck's location id; zone ids on every locations route are 404; the older-file wording says the copies in decks would be removed; spec 041 AC-2.1 is kept; and smaller fixes (a reader-only rule name `too_many_with_decks`, named constraints, the seam's name checks, a reason for deck problem rows, the gate for an account with decks and no place) |
| 0.2.0 | 2026-11-10 | From review round 1 (two blocking, nine major findings): an older file against held decks (AC-7.4a, AC-7.4b, D7 pending), the same printing in two decks' Main (AC-7.4c), renamed plus format-changed decks, the format option as a type and key pair (AC-1.8), the zone repair on apply (AC-8.2a), the places-only and every-kind surface lists (decision 1), the `considering` key the core may name (decision 2), `unknown_zone` and `unknown_format` as the reader's resolvable checks (AC-6.11), the migration's wording (AC-9.2), gates for an account with decks and no place (AC-5.8a), a core guard for the deck files (AC-9.11), and smaller fixes |
| 0.1.0 | 2026-11-10 | First draft, with the maintainer's rulings D1 to D6 of 2026-11-10 (decisions 1 to 6; D5 where rename and remove live, D6 the display and safe edit of a lot in a zone, with the bulk paths checked) |

## Problem Statement

A collector who plays has decks, and the design for 1.0 says a deck is a kind of location: a copy is in one place at a time, so a copy in a deck is not free for another deck ([design system](../../design-system/README.md), Decks; [decks and locations issue design](../../superpowers/specs/2026-11-09-decks-and-locations-issues-design.md), decisions 2, 3 and 9). Nothing in the app can hold a deck yet. Spec 057 wrote the words and rules and spec 060 drew the Decks page and the New deck page, with no data behind them.

This spec is the first deck feature. A collector creates a deck with a name and a format, renames it and removes it, and sees their decks on a Decks page reached from the main navigation. A deck is a location whose **zones** (Main, Sideboard, Considering and so on, which the format decides) are child locations that hold its copies. The formats come from the collectible extension through a seam, so the core names none. A deck is data the collector owns, so the export format and the import grow in the same pull request (**format version 4**, north star "Export covers it"), and an ADR records how decks fit the location model.

Putting copies into a zone, listing zones in pickers and filters, changing a deck's format, the deck page and proxies are the following issues (#252, #251, #253, #254). This spec makes the outcome whole without them: a deck exists, is kept in an export and restored by an import, and a copy that an import places in a zone is shown and kept correctly.

> **Terms.** *Location, place, name, comparison key, lot, unplaced, holdings* and the *refusal page* are as in specs 029 and 032 and [`collection-and-lots.md`](../../architecture/collection-and-lots.md). A *place* is now a location of kind `place`, the only kind there was. A *deck* is a location of kind `deck` with a format; a *zone* is a location of kind `deck_zone` whose parent is a deck. A *top-level location* is a place or a deck. The *zone key* is the stable text id of a zone (`main`); its *zone name* is the text shown for it (`Main`). A *format* is a collectible type's named set of zones; its *key* is stable text (`modern`) and its *name* is shown (`Modern`). A *format registration* is what a collectible extension gives the core for its formats. *"Deck › Zone"* is the label of a zone wherever a place is shown (the design system's Decks section). The *export*, a *file*, the *preview*, the *apply*, *well-formed*, a *problem row* and the *version* are as in [`data-portability.md`](../../architecture/data-portability.md).

## Goals

- A collector creates a deck with a name and a format, renames it, and removes it.
- A deck's zones come from its format and exist as soon as the deck does; a copy can only be in a zone, never in the deck itself.
- A deck's name lives in the same name space as the collector's places, so a name is never two things; a zone's name is unique within its deck, so every deck can have a "Main".
- A collectible extension gives the core its formats and their zones through one seam; the core never names a format.
- A deck that holds copies in any zone is not removed; the collector is told what it holds.
- The Decks section is in the navigation, the Decks page lists decks with format, cards and owned copies, and the New deck page creates one, as specs 057 and 060 drew them.
- An export carries decks and zones (format version 4); the preview and the apply read versions 1 to 4; a round trip of an account that has decks restores the same collection.
- Every existing surface of places keeps listing places only, and a lot in a zone is shown and kept honestly.
- Existing locations and lots migrate with no change of any value, and the upgrade proof stays green.
- The cost per account is stated (hosted-door rule 4).

## Non-Goals

- Putting a copy in a zone from the app (the lot form, Move copies, bulk Move to…, number entry, the scanner), zones in every picker, and "Deck (all zones)" in the collection filter: [#252](https://github.com/plainprogrammer/Collector/issues/252).
- Changing a deck's format and moving its lots into Considering: [#251](https://github.com/plainprogrammer/Collector/issues/251). In the app a deck keeps the format it was created with (an import can change it, AC-8.2).
- The deck page with its zone tables, the shape panel, the legality marker: [#253](https://github.com/plainprogrammer/Collector/issues/253), [#256](https://github.com/plainprogrammer/Collector/issues/256).
- Proxies, their counts and their export: [#254](https://github.com/plainprogrammer/Collector/issues/254). The Decks page here has no Proxy column.
- "Free to use" and "In decks" on the card page: [#50](https://github.com/plainprogrammer/Collector/issues/50).
- Deck-size and copy-limit checks, collector-defined zones and homebrew formats, lending (a `loan` kind), a deck-builder workflow, digital decks (the 2.0 issues of the issue design).
- A location of a kind other than place, deck and zone. The kind column leaves room for a later `loan`; none is built.
- Deleting or merging a collector's data by any new path. A deck is removed only while empty.

## Users and Context

**Primary users:** a signed-in collector who plays and keeps decks built from their own cards.
**Secondary users:** an operator who upgrades the instance, and a collector who exports and restores their collection. The operator sees no deck, name or count (hosted-door rule 2).
**Usage context:** a collector has a handful to a few dozen decks, in several formats; they create a deck when they start building one and remove it when it is taken apart. Until #252 and #253 land, copies reach a zone through an import of a version 4 file.
**User mental model:** "a deck is a place for cards with sections". They say "Main", "Sideboard", "Commander". A deck's name and a binder's name are both names of where cards are.

## Decisions

The rulings D1 to D4 are the maintainer's (2026-11-10, answering the questions this spec raised); the others are recorded as the spec's own and open to the review.

1. **A deck and its zones are location rows (maintainer D1).**
   - A deck is a row of `locations` with `kind = deck` and `parent_id` null, and a row of a new `decks` table (`account_id`, `location_id` unique, `format`; decision 2 adds `collectible_type`). The deck's name is the location's.
   - Each zone is a row of `locations` with `kind = deck_zone`, `parent_id` the deck's location, `zone` its key and `name` its zone name, stored (not derived), created with the deck in one transaction. A place has `kind = place` and null `parent_id` and `zone`.
   - A lot sits in a zone only. `lots.location_id` and `lot_key` (which ends in a location id) do not change. SQLite cannot state "a lot's place is not a deck" without a trigger, so the database does not: the model refuses a deck's row as a lot's place, and every write path takes its ids from a lookup that can never return a deck's row (a places-only lookup, a zones-only lookup, or one that reads every kind and is keyed by the kind), because the bulk writes and the apply skip validations.
   - Names are unique per parent: one unique index on top-level names per account (places and decks share it) and one on a deck's zone names. The top-level index is the old one with a condition that the row is top-level. Every deck can have a "Main".
   - **Places only** (the surfaces that choose or list a place): the locations page and its counts, the lot form's select, Move copies' destinations, bulk Move to…'s destinations, number entry's select, the scanner sitting's place, the collection filter's select and its value, the export's `locations` list and the import's held and file locations. **Every kind** (the readers that follow a lot to where it is): `Lot`'s validation (a place or a zone of the account), the card page's overview and its rows, the collection grid's and table's place reads, a bulk removal's undo, the number-entry and scanner lists' lot places, the export's lot rows, the import's held lots and the apply's lot placement (which resolves a place key only among places and a (deck key, zone key) pair only among zones), and the refusal pages.
2. **The format is the extension's, and the deck names its collectible type (maintainer D4).** `decks` carries `collectible_type` beside `format`; the file writes both. The core never names a format: the extension registers, per collectible type, its formats (key, name, default) and each format's zones (key, name, in order), through one seam (ADR 0028). MTG registers Casual (the default), Standard, Pioneer, Modern, Legacy, Vintage, Pauper (zones Main, Sideboard, Considering) and Commander (zones Commander, Main, Considering). Zone keys: `main`, `sideboard`, `considering`, `commander`. A format key is unique within its collectible type. Every format must include a zone with the key `considering` (the issue design: "every format has a Considering zone"); that one key is the core's to name, so #251 can move cards there without asking the format. The core names no other zone key and no format key (plan-level ruling, flagged for the maintainer's review of this spec).
   - The New deck form's format options carry both the type and the key (`<collectible_type>/<format key>`), so two collectibles that both register `standard` stay apart; the pair is checked against the seam.
3. **Names, the limit and the messages.**
   - A top-level name (place or deck) is unique per account by comparison key; a zone name is unique within its deck. `Location::Name` is the one definition of a name for all three.
   - The 500 limit (`Location::MAX_PER_ACCOUNT`, the export's `maxItems`) counts top-level locations, places and decks together; zones don't count.
   - A refused name shows the Locations page's sentences, as spec 060 decision 23 drew them.
4. **Version 4 of the export (maintainer D2, D3).** Decks join the file as a required top-level list `decks` of `{ "name", "collectible_type", "format" }`, beside `locations`, which stays the places. Zones are not listed: they come from the format. A lot's `location` is one field that is `null`, a place's name, or `{ "deck": <deck name>, "zone": <zone key> }`; the shape stays open for a later kind, which adds another object shape and raises the version. A deck is identified by its comparison key (the name space is shared with places); a zone by its deck's key and its zone key.
   - A deck's URLs (`/decks/:id`, its edit and removal pages) use the deck's **location id**, not `decks.id`: a zone's or a place's location id is then never a deck's id by accident, and a request with one is 404.
5. **Where rename and remove live (maintainer D5, option A).** Each row of the Decks page has Rename and Remove ghost buttons, like the Locations list, and the deck's name is plain text until the deck page of #253 makes it the link spec 060 drew. Rename is its own page, Remove its own confirmation page (or the refusal page: copies listed with their zone, "Back to decks", no bulk-mode shortcut until #252), both reachable without scripting. This differs from spec 060's `DecksIndex` preview in three ways, each recorded here and shown in the final visual review: the row actions, the name as text, and no Proxy column (#254 adds it). #253 restores the link and may remove the row actions where the deck page offers them; #254 adds the Proxy column and tag.
6. **A lot in a zone is shown and kept honestly (maintainer D6, 2026-11-10).** One central label makes every existing place display read "Deck › Zone" for a zone, and "Edit copy" on a lot in a zone shows its place as read-only text instead of the select, so a save keeps it; Move copies offers places only. Every path that could silently unplace a lot in a zone (Edit copy, Move copies, bulk Move to…, bulk Set condition, bulk removal and its Undo, number-entry and scanner Undo, the import) is checked, and each unsafe one is covered by an example that fails first. The grouped pickers, the filter and the tile design stay #252's.
7. **A deck is removed only while empty.** Refusing is as for a place (spec 032 decision 3): a deck whose zones hold any lot is refused on the existing refusal page, with the lots listed with their zone, and by the database. There is no shortcut into bulk mode for it, because the collection filter by zone is #252.

## User Stories

### Story 1: Create a deck

**As a** collector
**I want** to create a deck with a name and a format
**So that** I have a place for the cards of a deck, with the sections its format has

**Acceptance criteria:**

- [ ] **AC-1.1** Given a signed-in collector When they open `/decks/new` Then the New deck page shows a Name field and a Format select of every format the registered collectibles give, the default format selected (Casual for Magic), the hint "The format sets the deck's zones.", a primary "Create deck" button and a "Cancel" link back to the Decks page, as `DecksIndex` draws it
- [ ] **AC-1.2** Given the Format select When it lists formats Then they come from the extension's registrations in their registered order, none is named by core code, and with formats from more than one collectible type the select groups them under each type's category name, with one the list is flat
- [ ] **AC-1.3** Given a valid name and a format When the collector submits Then one deck exists in their account with that name, that format and the format's collectible type, one zone per zone of the format in the format's order with each zone's key and name, all created together, and the response is 303 to the Decks page with the notice "Added “<name>”."
- [ ] **AC-1.4** Given a deck is created When its zones are read Then each is a location of kind `deck_zone` whose parent is the deck, which no list of places shows and which the 500 limit does not count
- [ ] **AC-1.5** Given a collector with a place named "Main" When they create a deck named "Main" Then it is refused with the taken sentence, because places and decks share one name space (comparison key, case and normalisation as for places)
- [ ] **AC-1.6** Given two decks When each is created Then both have a zone named "Main" and both are accepted, because a zone's name is unique within its deck
- [ ] **AC-1.7** Given a blank name, a name with a control character, a name over 60 characters, a name already used by a place or a deck, or an account that already has 500 places and decks When the collector submits Then the response is 422, the New deck page is shown again with the typed name and format kept, and the Name field shows the sentence (`Location::MESSAGES`, `Location::FULL` (AC-1.7a), "You already have a location called “<name>”."), and nothing is written
- [ ] **AC-1.7a** Given an account that holds 500 places and decks together (any mix, for example 400 places and 100 decks, or no deck at all) When a collector adds a place on the Locations page, or submits the New deck page Then the Name field's sentence is "You can have at most 500 places and decks together." (`Location::FULL`, one sentence for both pages, so it says decks count toward the limit wherever it shows), and the sentence replaces spec 029's "You can have at most 500 locations." for every caller (maintainer, 2026-11-10)
- [ ] **AC-1.8** Given a Format value that is not a `<collectible_type>/<format key>` pair the extension registers (blank, no slash, an unknown type, a key of another type), or a request without the `deck` parameter When the collector submits Then nothing is written: an unregistered or blank format is 422 on the Format field ("Choose a format."), a missing `deck` parameter is 400
- [ ] **AC-1.9** Given two requests that create decks with one name together When both run Then one deck and one set of zones exist and the other gets 422 (never 500), and an account at 499 locations that adds one place and one deck together ends at 500, never 501
- [ ] **AC-1.10** Given a request with `account_id`, `kind`, `parent_id`, `zone` or `collectible_type` among its parameters When it is submitted Then those values are ignored: the account is the signed-in one, the kind is `deck`, and the collectible type is the one in the checked format pair
- [ ] **AC-1.11** Given the create succeeds When the zone and deck rows are written Then they are written in one transaction: a failure part way (a zone that cannot be written) leaves neither the deck nor any zone

### Story 2: Rename a deck

**As a** collector
**I want** to rename a deck
**So that** its name says what it is now

**Acceptance criteria:**

- [ ] **AC-2.1** Given a deck When the collector opens its Rename page (`/decks/:id/edit`) Then it shows the Name field with the current name, "Save" and "Cancel", under the Decks section
- [ ] **AC-2.2** Given a valid new name When they save Then the deck (its location) has the new name, its zones, format and lots are unchanged, and the response is 303 to the Decks page with "Renamed “<old>” to “<new>”."
- [ ] **AC-2.3** Given a change of case alone ("izzet tempo" to "Izzet Tempo") When saved Then it is allowed; a name another place or deck has (by comparison key) is refused with the taken sentence; the last of two tabs wins
- [ ] **AC-2.4** Given a refused name (blank, control character, over 60, taken) When saved Then 422, the Rename page again with the typed text kept and the sentence on the Name field, and the deck unchanged
- [ ] **AC-2.5** Given a deck with copies in its zones When it is renamed Then no lot, lot key, zone or quantity changes and a lot's place line reads the new name
- [ ] **AC-2.5a** Given a deck When a place is added or renamed to the deck's name (by comparison key) on the Locations page Then it is refused with the taken sentence, as a deck is refused a place's name (AC-1.5)
- [ ] **AC-2.6** Given a deck's zone When anyone asks to rename it (a request to `/decks/:id` with a zone's or a place's location id, or `/locations/:id` with a zone's or a deck's id) Then it answers 404, because a zone's name is its format's and a deck is renamed only as a deck

### Story 3: Remove a deck

**As a** collector
**I want** to remove a deck I no longer build
**So that** it leaves my list, as long as no copy is still in it

**Acceptance criteria:**

- [ ] **AC-3.1** Given a deck whose zones hold no lot When the collector opens its removal page (`/decks/:id/removal/new`) Then a confirmation page names the deck, says its zones are removed with it, and offers "Remove" and "Cancel"; it works without scripting
- [ ] **AC-3.2** Given the confirmation When they confirm (`DELETE /decks/:id`) Then the deck, its `decks` row and all its zones are removed, no lot, place or other deck changes, and the response is 303 to the Decks page with "Removed “<name>”."
- [ ] **AC-3.3** Given a deck any of whose zones holds a lot When its removal page is opened Then the refusal page shows instead: "“<name>” holds 12 copies in 3 lots. Move them before removing it.", the first 100 lots in the refusal page's order each linking to its card page and showing its zone, "and N more" beyond 100, and "Back to decks"; there is no Remove button and no "Move them in bulk mode" button
- [ ] **AC-3.4** Given such a deck When `DELETE /decks/:id` is sent (also when a lot was moved in after the confirmation page opened) Then the response is 409 with the same refusal page, and nothing is removed
- [ ] **AC-3.5** Given a lot placed in a zone between the application's check and its delete When the delete runs Then the database refuses it, the response is the 409 refusal page, and no zone and no deck is left half removed
- [ ] **AC-3.6** Given a deck removed in another tab When a second removal is sent Then it answers 404
- [ ] **AC-3.7** Given any removal When it is done Then a scanner sitting is unaffected (a sitting's place is a place), and no number-entry line, bulk selection or undo record changes
- [ ] **AC-3.8** Given a deck's or a zone's location id When it is used with any of the locations routes (`/locations/:id/edit`, `PATCH /locations/:id`, `/locations/:id/removal/new`, `DELETE /locations/:id`, `POST /locations/:location_id/selection`) Then it answers 404, and a place's id on any deck route (`/decks/:id/edit`, `PATCH`, `/decks/:id/removal/new`, `DELETE`) is 404 too; the locations pages know places only, and a zone is never removed, renamed or opened in bulk mode on its own

### Story 4: The Decks section and page

**As a** collector
**I want** Decks in the navigation and a page that lists my decks
**So that** I find a deck and add one

**Acceptance criteria:**

- [ ] **AC-4.1** Given a signed-in collector When any page with the header is shown Then the wide header links Collection, Decks, Search, Scan and Locations in that order, and the phone tab bar holds Collection, Decks, Search, Scan and More in that order, each with an icon and a current marker when its section is current; the Decks pages mark Decks current
- [ ] **AC-4.2** Given the five links When the header is measured at 640px to 719px and from 720px Then the logo mark stands in for the wordmark from 640px to 719px and the wordmark returns from 720px (spec 057 decision 19), and the header and tab bar have no overflow at 360px and 1280px; the header guard (`spec/system/design_system_deck_rules_spec.rb`) now measures the app's real Decks link and tab, not a clone of Collection's, and still fails on a sixth link
- [ ] **AC-4.3** Given a collector with decks When they open `/decks` Then the page head reads "6 decks · 379 cards" (the number of decks, then the copies in all their zones; "1 deck" for one) with the primary "New deck" button, and the table lists the account's decks by comparison key then name (code-point order) with the columns Deck, Format, Cards and Owned, as `DecksIndex` draws them without its Proxy column and its Proxy tag
- [ ] **AC-4.4** Given a deck When its row is shown Then Format is the format's name (the format's key when the instance no longer registers it), Cards counts the copies in every zone of the deck, Considering included, and Owned is the same count until proxies exist, a deck with no copies shows "0", and the row has "Rename" and "Remove" (decision 5), each naming the deck for a screen reader
- [ ] **AC-4.5** Given the table at less than 640px of its container When it is shown Then Format and Owned are hidden and the line under the name reads "<Format> · <n> owned", Cards stays, a 60-character name with no space wraps, and the page has no horizontal overflow at 360px
- [ ] **AC-4.6** Given a collector with no deck When they open `/decks` Then the page shows "No decks yet. Add a deck to start building one." in place of the table, and the head and its New deck button stay, and on a phone "New deck" stays visible (spec 060 decision 24)
- [ ] **AC-4.7** Given the Decks page When it is rendered Then it costs a bounded number of queries whatever the number of decks, zones or lots (the decks read with their locations, and one grouped read of the copies of all their zones)
- [ ] **AC-4.8** Given the Locations page When it is rendered Then it lists places only, counts only places ("12 locations") and shows only places' copies; a deck is on the Decks page only
- [ ] **AC-4.9** Given a signed-out visitor When they request any deck URL Then they are sent to sign in, and a visitor's header (open catalog) has no Decks link
- [ ] **AC-4.10** Given the More page When shown Then it keeps its rows (Locations stays in More); Decks is a tab, not a row

### Story 5: Places only elsewhere, and a lot in a zone

**As a** collector
**I want** every place I choose from to stay what it was
**So that** nothing I do before the deck pages exist puts a copy somewhere I cannot see

**Acceptance criteria:**

- [ ] **AC-5.1** Given an account with places, a deck and its zones When the lot form, Move copies, bulk Move to…, number entry, the scanner sitting's place and the collection page's Location filter list locations Then each lists places only, in the order it had; none lists a deck or a zone
- [ ] **AC-5.2** Given an id that is a deck's or a zone's When it is sent as a location to any of those surfaces (a form's `location_id`, the move's destination, the sitting's place, a number-entry line's location, the collection filter's `location`) Then it is refused or read as the surface treats an id that is not the account's: 404 where it answers 404, the field error where number entry shows one, "all" for the filter
- [ ] **AC-5.3** Given a `Lot` When it is given a deck's row as its location Then it is invalid ("isn't one of your locations"); a zone of the account, a place of the account or none is valid; another account's location of any kind is invalid
- [ ] **AC-5.4** Given a lot in a zone When its place is shown anywhere (the card page's "Your copies", the lot's action labels and the Move copies page, the collection's tiles and rows and the phone line, bulk mode, the removal refusal pages, the number-entry and scanner lists, the import preview's removed lots and problem rows) Then it reads "Deck › Zone" ("Izzet Tempo › Main"), the deck's name and the zone's name joined by " › ", never the zone's name alone, and every one of those reads the label from one place in the code (decision 6; this takes from #252 only the label, where #252's issue says "tiles and rows name a zone", recorded in the specs index)
- [ ] **AC-5.5** Given a lot in a zone When the collector opens its "Edit copy" Then the Location field is the read-only text "Deck › Zone" with no select, and saving the form (with or without a change to the other fields) keeps the lot in that zone, merging as every edit does
- [ ] **AC-5.6** Given a lot in a zone When "Move copies" is opened Then it offers the account's places and "No location" as destinations (decision 1), moves as it does for any lot, and the lot's own zone is the source
- [ ] **AC-5.7** Given a lot in a zone When bulk Set condition, bulk removal and its Undo, or number entry's and the scanner's Undo run on it Then each keeps the lot's zone as it keeps a place (the lot's key ends in the zone's id); an Undo of a bulk removal whose lot's zone has since been removed restores it unplaced, as for a place
- [ ] **AC-5.7a** Given a selection in bulk mode that holds lots in a zone, lots in places and unplaced lots When bulk "Move to…" runs to a place or to "No location" Then every selected lot moves (a lot in a zone is never "already there", since the destination is a place or none), lots that meet an identity at the destination merge, the cap rule holds, and no lot is left in a zone by the move; the To select offers places only and omits the filter's own place exactly as spec 041 AC-2.1 does (a zone is never a filter value in this spec), so nothing of spec 041's rule changes
- [ ] **AC-5.7b** Given the bulk bar and the table in bulk mode When a lot in a zone is shown, selected, or edited by Set condition Then its place column and line read "Deck › Zone", and Set condition keeps each lot's zone, merging only within one zone
- [ ] **AC-5.8** Given a lot in a zone and the lots of a place When the collection's Location filter is "No location" or one place Then a lot in a zone is in neither (it is not unplaced and not in that place), and under "All locations" it is shown
- [ ] **AC-5.8a** Given the gates that today show a place only while the account has a location (the grid's place line, the table's Location column, the collection filter's select, the lot form's field and hint, Move to… and the scanner's and number entry's selects) When an account has decks and lots in zones but no place Then the place line and the Location column show while the account has any place or any lot in a zone (a lot in a zone has a place to read), the selects, the filter, Move to… and the form's field stay hidden (they list places, and there is none), and the form's hint "Add a location to keep copies in one." shows; when it has places they all show as before
- [ ] **AC-5.9** Given the number of places and the 500 limit When a collector adds a place Then decks count with places (AC-1.7) and zones do not; an account with 400 places and 100 decks cannot add one more of either

### Story 6: Export version 4

**As a** collector
**I want** my decks in my export
**So that** I can restore them, and so that nothing I own is locked in

**Acceptance criteria:**

- [ ] **AC-6.1** Given any account When it is exported Then the file is `format_version` 4 and has `decks`, a list present and empty for an account with none, each `{ "name", "collectible_type", "format" }`, with the name as stored and ordered by comparison key then name in code-point order, as `locations` is
- [ ] **AC-6.2** Given an account with places and decks When it is exported Then `locations` lists places only, never a deck or a zone, and no zone is listed anywhere in the file as a location
- [ ] **AC-6.3** Given a lot in a zone When it is exported Then its `location` is `{ "deck": "<the deck's name as stored>", "zone": "<the zone's key>" }`; a lot in a place has the place's name as a string and an unplaced lot `null`, never an empty string
- [ ] **AC-6.4** Given the export When it is built Then it reads the account's places, decks and lots with a number of queries that does not depend on their number, takes each lot's deck name and zone key from the same statement as the lot, repeats the reads up to `TRIES` times when a rename, removal or format change of a place or deck lands between them (so a lot never names a deck or place the lists lack), and raises `Unsettled` after that, as the version 3 export did
- [ ] **AC-6.5** Given an unchanged collection When it is exported twice Then the two files are identical apart from `exported_at`; no internal id, no zone's name and no account or user id is in the file
- [ ] **AC-6.6** Given the format document When it is read Then it defines `decks`, the deck's fields, the zone object, the new rules (`too_many_locations`, with `duplicate_location` and `unknown_location` extended to decks) and the two resolvable checks (an unknown format, an unknown zone), the lot identity's sixth value, the shared name space and the combined limit of 500, the version 4 row of the history, the coverage rows for `decks` and the new `locations` columns, and the MTG type's formats and zone keys; its `v4.schema.json` is byte-identical to the app's copy, and `v1` to `v3` and their examples never change
- [ ] **AC-6.7b** Given a version 4 file whose deck name is within 60 characters as written but over 60 code points after normalisation (NFC) When it is checked Then the whole file is refused as the `locations` names are (`long_location`, spec 029 decision 9), pointing at `/decks/<i>/name`, so no bulk write can reach the name's length check constraint; a valid and an invalid example (`invalid/deck-name-60-nfc.json`) cover it
- [ ] **AC-6.7a** Given a problem row that names a deck or a zone When the preview lists it Then its reason reads "Its deck “<name>” isn't one of the file's decks." (`unknown_location`) or "The deck “<name>” has no zone “<key>” in its format." (`unknown_zone`), the names as the file spells them and never as a raw object
- [ ] **AC-6.7** Given a version 4 file When it is checked Then a deck whose name is not a well-formed name, a `collectible_type` or `format` that is blank, a `decks` that is not a list, a deck missing a field, or a lot whose `location` is none of null, a name and a `{ deck, zone }` object (an object without both keys, with any other key, with a `deck` that is not a well-formed name, or with a blank `zone`) is not well-formed, and a missing `decks` or a lot without `location` is not well-formed (a reader never reads them as empty or `null`)
- [ ] **AC-6.8** Given a version 4 file When two entries of `locations` and `decks` together have one comparison key (a deck and a place, or two decks) Then the later one is `duplicate_location`, at its pointer, the places being judged before the decks, whichever list the later one is in
- [ ] **AC-6.9** Given a version 4 file When `locations` and `decks` together hold more than 500 names Then it is refused (rule `too_many_locations`, at `/decks`), only the first 500 names of each being checked so the cost of a hostile file does not grow with the list; each list alone is also bound by the schema's `maxItems` 500. `too_many_locations` is a well-formedness rule of the format (a count of the file alone)
- [ ] **AC-6.10** Given a version 4 file When a lot's `location` names a deck the file's `decks` do not list (by comparison key) Then that lot is a problem row, `unknown_location`, at its `/location` (a well-formedness rule, like a place the `locations` do not list, as in version 3); when the deck is listed but its format does not have that zone key Then the lot is a problem row, `unknown_zone`, at its `/location/zone`
- [ ] **AC-6.11** Given a version 4 file When a deck's `collectible_type` and `format` are not a registration of this instance Then the whole file is refused (reason `unknown_format`, "This instance doesn't know the format “<format>” of <type>.") before any row is judged, like `unsupported_currency`, never a problem row. `unknown_format` and `unknown_zone` depend on this instance's registrations, so they are the reader's checks (`CollectionImport`, like `unknown_type` and `unsupported_currency`), not rules of the format: the format document lists them under "resolvable", not "well-formed", and the format's rule list, schema and examples hold none of them
- [ ] **AC-6.12** Given two lots whose identity is equal except that one is in the zone `{ deck: "Box", zone: "main" }` and the other in a place "Box" When they are compared Then they are different lots (the place key and the (deck key, zone key) pair are different values), and two lots naming one deck by "Izzet" and "izzet" and one zone are one identity, so the second is `duplicate_lot`
- [ ] **AC-6.13** Given two files of version 4 When they are compared as "the same collection" Then decks are equal as sets of `name`, `collectible_type` and `format` compared exactly as written, a lot's `location` is compared exactly (a zone object by its deck's name as written and its key), and the examples for `comparison/` cover a deck's name, its format and a lot's zone each differing

### Story 7: Import preview of a file with decks

**As a** collector
**I want** the preview to tell me what my decks would do
**So that** an import never surprises me

**Acceptance criteria:**

- [ ] **AC-7.1** Given a version 4 file When it is previewed Then the page has a Decks section, after Locations, with counts "Decks added", "Decks renamed", "Format changed", "Decks unchanged" and "Decks removed", lists of the renamed (old → new), format-changed (name, old format → new format) and removed decks, each list showing the first `LIST_LIMIT` and "and N more", and the counts of all
- [ ] **AC-7.2** Given the account's decks and the file's When the plan is made Then held decks become the file's by comparison key: a file key no held deck has is added; a held deck with the key but another spelling is renamed (its id stays); a held deck with the key but a different format or collectible type is format-changed; one with the key, the same name and the same format and type is unchanged; a held deck whose key no file deck has is removed. Renamed and format-changed are independent: a deck with both a new spelling and a new format is counted in both, listed in both, and its fingerprint part has both
- [ ] **AC-7.3** Given a version 4 file When its places and decks share a key with the other kind (a held place "Box" and a file deck "Box") Then the place is removed and the deck added (a key is a place or a deck, never both), the removal needs the confirmation, and the page says so in the Locations and Decks sections
- [ ] **AC-7.4** Given a version 1, 2 or 3 file When it is previewed Then the page says "This file was written before decks existed, so your decks would stay, but the copies in them (<N> lots) would be removed." (the second part only when a deck holds a lot) with no Decks counts, the lots of the file are in places or none (as ever), and a held lot in a zone, which no row of such a file matches, is a removed lot "in Izzet Tempo › Main"
- [ ] **AC-7.4a** Given a version 1, 2 or 3 file and an account with decks When a place of the file has the comparison key of a held deck Then the file is refused as a whole (reason `deck_name_taken`, "A deck you have is called “<name>”, like a place in this file. Rename one of them and preview again.", at the place's pointer `/locations/<i>`), nothing is written, and no 500 can come from the unique name index (maintainer D7, option A)
- [ ] **AC-7.4e** Given the order of the reader's file refusals When a version 4 file has several Then they come after `unsupported_currency` and before any row is judged, in this order: `unknown_format`, then for a version 1 to 3 file `deck_name_taken`, then `too_many_with_decks`; the first that applies decides the preview's reason
- [ ] **AC-7.4b** Given a version 1, 2 or 3 file and an account with decks When the file's places and the held decks together would exceed 500 top-level locations Then the file is refused as a whole (reason `too_many_with_decks`: "This file and your decks together would have more than 500 locations."), nothing is written; a version 1 file, which leaves places alone, is judged on the held places plus held decks, which cannot exceed 500
- [ ] **AC-7.4d** Given a previewed version 1 to 3 file that was applicable and an account whose decks or places changed before the apply (a deck added or renamed to a name a file place has, or enough decks added to pass 500 with the file's places) When the apply runs Then it re-judges the two refusals inside its write transaction on the data it holds then (`replan`), refuses with the preview's reason before the nothing-to-change and stale checks (so a refusal is never shown as a stale preview offered again) and writes nothing, and no path of the apply can reach the unique name index's error: the apply's own writes are guarded before they run, not caught after (maintainer D7)
- [ ] **AC-7.4c** Given a held lot's place When the plan matches it with a file row Then both are identified by the same value: a place's comparison key, or a zone's (deck key, zone key) pair, never the zone key alone, so the same printing in two decks' "Main" is two held lots, two outcomes, and two parts of the fingerprint, and the apply places each lot in the zone of its own deck
- [ ] **AC-7.5** Given the plan When a removed lot, or a problem row, names a zone Then it ends "in <Deck › Zone>" (the file's spelling for a problem row)
- [ ] **AC-7.6** Given the plan removes a deck (or a place, or a lot) When the apply form is shown Then it needs the required checkbox "I understand this removes N lots, M locations and K decks" (the lots in a deck's zones count among N, so applying an older file over decks that hold copies needs it) naming only the parts that apply, after the link to download the current collection
- [ ] **AC-7.7** Given the preview When a file has decks only (no change of lots, places or view) Then it is applicable (a deck added, renamed, format-changed or removed is something to change) and a plan with none of any is "nothing to change"
- [ ] **AC-7.8** Given a refusal by `unknown_format` or `too_many_locations` or a schema problem in `decks` When the file is previewed Then it is 422 with the reason and the pointer, and no row is shown
- [ ] **AC-7.9** Given the preview When it is built Then it writes no deck, location, lot or account and enqueues no job; the one thing it may write is the stored upload, only for a file that can be applied and has something to change (as ever)
- [ ] **AC-7.10** Given the preview's fingerprint When the plan has a deck part Then it covers the names of added decks, the held and file names of renamed ones, the held and file collectible types and formats of format-changed ones and the names of removed ones, with no id, so a deck added, removed, renamed or changed in format between preview and apply makes the preview stale, and a deck deleted and added again with the same spelling and format does not; a plan of a version 1 to 3 file keeps the fingerprint it had

### Story 8: Applying a file with decks

**As a** collector
**I want** applying a file to restore my decks and the copies in their zones
**So that** an export and an import give me back what I had

**Acceptance criteria:**

- [ ] **AC-8.1** Given a previewed version 4 file When it is applied Then the account's places, decks, zones and lots are the file's: removed lots are deleted first, then removed decks (their zones and the deck rows), the zones a format-changed deck loses, and removed places, then added and renamed places and decks are written (an added deck with its zones; a format-changed deck's new format and the zones it lacks), then the lots with their place ids and keys, all in the one write transaction of spec 028, with the account's other data untouched
- [ ] **AC-8.2** Given an added deck When it is applied Then its zones are those of its format in order, with their keys and names as the registration gives them; a renamed deck keeps its id, its zones and its lots; a format-changed deck keeps its id and its name, takes the new format and collectible type, gets the new format's zones it lacks and loses the zones it has that the new format lacks, the lots of the removed zones being among the file's removed lots (the file's rows name the zone each lot is in), and no lot is moved into Considering by an import (that is #251's, and a file is the truth)
- [ ] **AC-8.2a** Given a held deck whose format has gained a zone since the deck was made (a release added it) and a file that lists the deck When it is applied Then every listed deck, changed or not, ends with a zone row for every zone of its format, the missing ones created with the registration's key and name, and the names of the zones it already has rewritten from the registration first (so a renamed zone's old name can never meet a new zone's name in the zone name index), so a lot whose row names that zone can be placed; this repair is written with an apply that is not refused and never makes a plan "something to change" on its own
- [ ] **AC-8.3** Given a file in which a place and a deck swap names across kinds (the place's key becomes a deck's, the deck's key a place's) When applied Then it writes without a unique-index failure (every removal runs before any addition), and the result matches the file
- [ ] **AC-8.4** Given a file with a lot in a zone When applied Then the lot's `location_id` is the zone's id and its key ends in that id, as `Lot.key_for` builds it, and a re-export of the account is the same collection as the file (round trip)
- [ ] **AC-8.5** Given the round trip When an account with places, decks in every MTG format, zones holding lots (some zones empty), a lot in a place and an unplaced lot is exported, applied to a fresh account on an instance, and exported again Then the two files hold the same collection (spec 017 "the same collection", version 4), each deck has the zones of its format, and a lot's place is the same; and applying the same file twice is refused the second time as nothing to change, writing and clearing nothing
- [ ] **AC-8.6** Given an apply that removes a deck or a place When it runs Then a lot in a removed deck's zone is deleted before the zone (so the foreign key never fires), the apply never moves a lot to make a removal succeed, and a scanner sitting's place is cleared through the foreign key when its place is removed (spec 040)
- [ ] **AC-8.7** Given the apply writes a lot When it commits Then it clears the working state that points at lots (selections, undo records, the number-entry list, the sitting), as before; an apply that changes only decks or places clears none
- [ ] **AC-8.8** Given the notice When the apply is done Then it reads "Imported: N lots added, M changed, K removed" with "; 2 locations added, 1 renamed, 1 removed" for places and "; 2 decks added, 1 renamed, 1 format changed, 1 removed" for decks, each part left out at zero, then "; prices now shown in EUR" when the currency changes, no final period
- [ ] **AC-8.9** Given the apply When it writes decks and zones Then it skips the models' validations in bulk statements on purpose (the reader judged each row), a number of statements that does not depend on the number of decks or lots, and a spec checks every written row against `Location` and the `decks` model (name, key, kind, parent, zone, format)
- [ ] **AC-8.10** Given a file at the worst case the earlier bars used (50,000 lots over 300 places) with 100 decks and 300 zones When it is previewed and applied Then the existing bars hold (preview under 30 seconds and 500 MB, apply under 30 seconds and 500 MB with the write transaction under 4 seconds, export of 50,000 lots under 10 seconds and 300 MB)

### Story 9: Upgrading and tenancy

**As an** operator, and as a collector in a shared instance
**I want** the upgrade to lose nothing and one account's decks to be its own
**So that** a release is safe and private

**Acceptance criteria:**

- [ ] **AC-9.1** Given a database of the previous release (accounts, places, placed and unplaced lots, scanner sittings, bulk selections, import uploads) When the migration runs Then every existing location is a place with no parent and no zone, no lot, lot key, name, name key or timestamp changes, the `decks` table is empty, and the old unique index on `(account_id, name_key)` is replaced by the top-level one with equal outcomes for the rows that exist
- [ ] **AC-9.2** Given the migration When it runs on an instance, unattended, from any prior version Then it needs no application model; it never copies `locations` inside a transaction (a copy's `DROP TABLE` would run the `ON DELETE` actions of `lots.location_id`, which restricts, and of `scanner_sittings.location_id`, which sets null), so it follows the precedent of `20261023100001_add_location_to_lots.rb` (steps outside a transaction, each guarded so a run that stopped part way finishes on the next boot); it adds the columns with their checks stated on `ADD COLUMN`, creates the new partial unique indexes before it drops the old one so no name is ever unguarded, and `parent_id`'s foreign key `ON DELETE` action is stated (cascade, since a zone cannot outlive its deck and a zone holding a lot is restricted by `lots`); and `bin/upgrade-smoke` and `ruby script/upgrade/guard.rb` stay green
- [ ] **AC-9.3** Given the migration's rollback When any deck exists Then it is refused with a message that says why (a rollback would turn decks into places or lose them); with none it is clean, and `bin/rails db:migrate:redo:primary` ends with the schema it started with
- [ ] **AC-9.4** Given the schema When it is read Then named check constraints (so the schema dump keeps them) and keys state what the database can: `kind` is `place`, `deck` or `deck_zone`; `parent_id` is null for a place and a deck and not null for a zone; `zone` is null unless the row is a zone; the zone's name stays 1 to 60; `decks.location_id` is unique, with a foreign key to its location that cascades, `decks.account_id` has a foreign key that cascades, and `decks` has an index on `account_id`; `parent_id` has a foreign key and an index; the names' unique indexes are as decision 1 says
- [ ] **AC-9.5** Given the models When a record is built Then a deck's location must be of kind `deck`, a zone's parent a deck of the same account (one level deep: a zone has no children and a deck has no parent), a place has neither a parent nor a zone nor a `decks` row, and a zone's key must be one of its deck's format's; a `decks` row has the account of its location; each is a validation here and, where the schema can state it, a constraint there
- [ ] **AC-9.6** Given the account's `has_many` declarations When an account with decks and lots in zones is deleted Then it deletes its lots before its locations, and decks and zones with them, with no foreign key failure (`spec/models/account_spec.rb` guards the order)
- [ ] **AC-9.7** Given two accounts When one asks for another's deck by id on `/decks/:id/edit`, `PATCH /decks/:id`, `/decks/:id/removal/new` and `DELETE /decks/:id` Then each answers 404 and changes nothing; the Decks page lists only its own; no deck, name or count of an account is in another account's page, export or preview; a request spec proves each
- [ ] **AC-9.8** Given the operator's pages (the admin users page, catalog, jobs) When an account has decks Then they show no deck, deck name, zone, format or deck count (hosted-door rule 2); the admin users page's copy count is unchanged
- [ ] **AC-9.9** Given the backup When an instance with decks is backed up and restored Then the restored database holds the decks, zones and lots (the primary database holds `decks`), `spec/backup_guards_spec.rb` stays green, and no new database or attachment exists
- [ ] **AC-9.10** Given the coverage guard When the migration has run Then `decks` and every new column (`locations.kind`, `locations.parent_id`, `locations.zone`; `decks.id`, `account_id`, `location_id`, `collectible_type`, `format`, `created_at`, `updated_at`) are in the format document's Coverage tables with what the file does about them
- [ ] **AC-9.11** Given the deck files (the decks controllers and views, the deck, zone and format-seam models, the deck helper, and the import and export files this spec adds) When the core guard runs Then a new `spec/deck_core_spec.rb` lists them and fails if one names `mtg`, `scryfall` or `magic` in any spelling or any of MTG's eight format keys (`casual standard pioneer modern legacy vintage pauper commander`, matched as words), and proves it can fail with a temporary identifier-shaped name; the guard also fails on the zone keys `sideboard` and `commander` (`main` is a common word in views and is reviewed by eye), and the only zone key core code may name is `considering` (decision 2)

## Functional Requirements

### FR-1: Deck and zone records

A deck is one `locations` row (kind `deck`) and one `decks` row; each of its zones is a `locations` row (kind `deck_zone`, `parent_id` the deck's location, `zone` the key, `name` the zone name). Creating, renaming and removing run in one transaction each. `Location` keeps its model for names (`Location::Name`, its messages, the comparison key); a deck adds its own record for the format.

**Must:**
- Create a deck and all its zones together, or neither.
- Take the zones, their keys, names and order from the format's registration at the time of creation.
- Keep a lot in a zone only, never in a deck row, in the model and as far as the schema can state.
- Let a zone's name be unique within its deck, and a top-level name unique per account, in the model and in unique indexes, with a racing second write answering as a refused name.
- Count top-level locations only against `Location::MAX_PER_ACCOUNT`, under racing adds, and skip that count when a zone is written, so the 500th deck still gets its zones.

**Must not:**
- Let a zone be a deck's parent, a deck have a parent, or a place have a zone key.
- List a deck or a zone where places are listed, or a place where decks are.
- Name a format, a collectible, or a zone other than `considering` in a core file (decision 2); the export's, the preview's and the apply's three core guards gain the format and zone-key words of AC-9.11, or this is reviewed by eye where a guard cannot match it.

### FR-2: The format seam

A collectible extension gives the core, per collectible type: its formats (key, name, which is the default), and for each its zones (key, name, order). The core asks the seam and never names a format. One format is the default for the New deck page's select; a type with no formats offers none.

**Must:**
- Let a second collectible register formats with no change to the core, and keep a key unique within its type.
- Give MTG's eight formats and their zones as decision 2 states.
- Fail at boot, not at a request, for a registration whose default is not one of its formats, whose zone key repeats, whose zone names share a comparison key or fail `Location::Name`, or whose format lacks a `considering` zone.
- Be documented as an extension contract in the comment of the module that states it (`.claude/rules/code-documentation.md`).

**Must not:**
- Let a format change a zone's meaning to the core (zones are keys and names and an order, and the core knows `considering` only as the key of the zone for cards under consideration).

### FR-3: Export and import, version 4

Versions 1 to 4 are read, version 4 is written. The decision rules of decisions 3 and 4 and Stories 6 to 8 define it; ADR 0028 records it and the format document is its definition.

**Must:**
- Add version 4 to `ExportFormat::Rules::VERSIONS`, its schema copy, its well-formedness rules (`too_many_locations`, and `duplicate_location` and `unknown_location` extended to decks) and its examples, valid, invalid and comparison, checked by the existing example and document specs. `unknown_zone` and `unknown_format` are the reader's resolvable checks, kept in `CollectionImport` with `unknown_type` (AC-6.11), as are the two reader refusals of an older file (`deck_name_taken`, and `too_many_with_decks` for places plus held decks, AC-7.4a, AC-7.4b).
- Keep versions 1 to 3 byte-for-byte as released and read their files as before (decks stay; lots in places or none).
- Put no internal id, zone name or kind column in a file.
- Raise the version (the rule of the format document's Versions: a new field of collector-owned data), and add the version 4 row to its history.

**Must not:**
- Name a collectible, a format or a zone key in the export's, the preview's or the apply's code (the core guards `spec/collection_export_core_spec.rb`, `spec/collection_import_core_spec.rb`, `spec/import_apply_core_spec.rb`; the format document's type section may name MTG's formats).
- Merge a file with the collection: applying replaces places, decks and lots (spec 025 decision 1).

### FR-4: Navigation and pages

The Decks section is a live section of the header and the tab bar; the Decks, New deck, Rename, Remove and refusal pages use the design system's classes and tokens only, and the words of the Decks section.

**Must:**
- Follow `DecksIndex` and the Locations pages' patterns; any difference from spec 060's preview (decision 5's row actions, no Proxy column) is shown in the visual review.
- Work without scripting; answer 422 on a refused form with the typed text kept and `:see_other` after a non-GET success.
- Give each deck's actions an accessible name that includes the deck's name.

**Must not:**
- Hard-code a colour, spacing or font; add a sixth link to the header.
- Show a deck on the Locations page or a place on the Decks page.

## Non-Functional Requirements

### Performance

- The Decks page, the Rename and the removal pages cost a bounded number of queries whatever the number of decks, zones or lots.
- Creating a deck writes one deck row, one location row, and one row per zone in one transaction (at most ten statements for any format).
- Export, preview and apply keep the bars of specs 022, 025, 028 and 032 (AC-8.10), and the apply writes decks and zones in a number of statements independent of their number.
- Cost per account (hosted-door rule 4): a deck is one `decks` row and one `locations` row, plus one `locations` row per zone (three or so), about a few hundred bytes together; a place or a lot costs what it did, plus three small columns on `locations`; no job, cache entry or file.

### Security

- Every deck lookup goes through `Current.account`; another account's deck, or a zone, is 404 (AC-9.7). No form takes an account, user, kind, parent, zone or collectible type value (AC-1.10).
- No stored name is rendered unescaped; names are shown by the escaped helpers, never `html_safe`.
- Responses of the pages carry the app's usual headers; the export, preview and apply keep `Cache-Control: no-store`.
- A file's content is never logged or echoed (the preview's rule), including a deck's name or format on an error.
- The operator sees no deck (AC-9.8).

### Reliability

- Create, rename, remove and the apply are all or nothing. A removal that races a lot being placed is caught by the check or by the database, never leaves a deck without its zones or a zone without its deck.
- A lot is never in a missing location: a deck or zone that holds a lot cannot be removed, in the application and in the database.
- Migrating changes no existing row's values (AC-9.1), and a catalog refresh never changes a deck, a zone or a lot.
- Every page works without scripting.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A blank, control-character, over-long or taken name, or 500 reached | 422, form again with the typed text kept, the Locations page's sentence on the Name field; nothing written |
| A blank or unregistered Format value on create | 422, "Choose a format." on the Format field; nothing written |
| A create request with no `deck` parameter | 400 |
| Another account's deck, a zone's id, or a deck's id on a locations URL | 404 |
| Remove a deck that holds lots (page or `DELETE`) | The refusal page, 200 for the page and 409 for the `DELETE`, nothing removed |
| A lot placed in a zone while a removal runs | The database refuses; 409 refusal page; nothing half removed |
| A deck removed in another tab, then used | 404 |
| A version 4 file whose deck format this instance does not register | 422 on the preview, `unknown_format`, no row shown |
| A version 4 lot naming an unlisted deck or a zone the format lacks | Problem row, `unknown_location` or `unknown_zone`; the file cannot be applied |
| A version 4 file with places and decks over 500 together | Refused, `too_many_locations` |
| A version 1 to 3 file with a place named like a held deck | Refused as a whole, `deck_name_taken`; nothing written (AC-7.4a) |
| A version 1 to 3 file whose places plus the held decks pass 500 | Refused as a whole, `too_many_with_decks` (AC-7.4b) |
| Renaming or removing a deck whose registration the instance has lost | Works: a rename or a removal never re-checks the format or the zone keys, so it never gives a 422 or a 500 |
| A held deck whose registration the instance has lost (format or type no longer registered) | The Decks page shows the format's key; its export carries it, and an import of that file is refused whole as `unknown_format` on this instance (accepted: it is the instance that lost the registration; the file reads on any instance that has it) |
| A held deck whose format a release has since given another zone | An apply creates the missing zone rows (AC-8.2a) |
| A file or a stored upload for a collectible type the instance lost | As before: the row problem `unknown_type`; a deck's `unknown_format` for its format |
| An export whose places or decks changed between reads | Repeats up to three times, then `Unsettled` |
| A rollback of the migration with decks present | Refused with a message |
| A lot in a zone edited with the old form | The place text is read-only; the lot stays in its zone |

## Open Questions

- The plan decides how the apply upserts places and decks under a partial unique index (a conflict target with its condition) and how the migration adds its checks; both must keep AC-9.2.

## Out of Scope (Future Considerations)

- Zones and decks in every picker, "Deck (all zones)" in the collection filter and tiles' design for a zone: #252.
- Changing a deck's format and Considering's move: #251.
- The deck page, owned cards by zone, the shape panel and the legality marker: #253, #256.
- Proxies, their counts on the Decks page and in the export: #254 (it extends version 4 if no release has shipped version 4, else raises it to 5; its spec checks which).
- Free to use and In decks on the card page: #50.
- Deck checks, collector-defined zones and formats, lending, digital decks (the 2.0 issues).
- Sorting or searching decks, a deck's description, colours, cover card or notes: none is asked for.

## Supersedes and updates

- **Supersedes** [spec 029](../029-manage-locations/spec.md) decision 4 ("a location is a name and nothing else": no kind, no nesting) for locations as a whole: a location now has a kind and a zone may have a parent. Places stay a name and nothing else; the Locations page's behaviour is unchanged.
- **Supersedes** [spec 029](../029-manage-locations/spec.md) decision 7 and AC-1.13 where they count "locations": the limit counts top-level locations, places and decks together.
- **Supersedes** [spec 029](../029-manage-locations/spec.md) AC-1.13's sentence "You can have at most 500 locations.": it reads "You can have at most 500 places and decks together." (AC-1.7a; `Location::FULL`, the Locations page's and the New deck page's refusal; the sentence in `collection-and-lots.md` and `DecksIndex.md` changes with it).
- **Supersedes** [spec 029](../029-manage-locations/spec.md) decision 9's "unique per account" for a name: a zone's name is unique within its deck; top-level names are unique per account.
- **Supersedes** [spec 032](../032-lot-in-a-location/spec.md) FR-3's and the format document's "lot identity has six values" in the sixth value's form: the sixth value is a place key, a (deck key, zone key) pair or none, from version 4.
- **Supersedes** [spec 060](../060-deck-components/spec.md) decision 11 and AC-4.1 to AC-4.3 for the Decks page until #253 and #254: the deck's name is plain text (not the `TableItemLink`), each row has Rename and Remove, and the table has no Proxy column or tag. #253 restores the link; #254 adds the Proxy column and tag (maintainer D5, 2026-11-10).
- **Updates** [`collection-and-lots.md`](../../architecture/collection-and-lots.md) (locations, a lot's place, zone display, the limit), [`data-portability.md`](../../architecture/data-portability.md) (version 4, the export, rules, preview, fingerprint, apply, constants), [`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md) (the deck routes' 404 rule) and the design system's README (Navigation: Decks is live) and `AppHeader`, `TabBar`, `DecksIndex` docs where the real pages differ, in the same pull request.

## Notes for the plan

- **Scope notes for #251 and #252.** An import that changes a deck's format applies the file as the truth: a lot whose row names a zone the new format has stays in it, and nothing is moved into Considering (#251 moves cards when the collector changes the format in the app); say so in #251's issue. #252 keeps the grouped pickers, "Deck (all zones)" and the tiles' design; this spec takes only the "Deck › Zone" label and the safe Edit copy (decision 6), so #252's issue and the specs index say that part is done.

- **Guards that fail until updated:** the coverage tables of the format document (the new table and columns); `ExportFormat::Rules::VERSIONS`; `spec/models/location/name_parity_spec.rb` (the name's definition stays one); the five `lot_key` builders (none changes, since a zone is a location with an id, and a spec proves a lot in a zone's key ends in the zone's id in each); `spec/models/account_spec.rb`'s order of `has_many` declarations; the core guards `spec/number_entry_core_spec.rb` and `spec/import_apply_core_spec.rb` (the new deck files name no collectible); `spec/backup_guards_spec.rb`; the header guard `spec/system/design_system_deck_rules_spec.rb`.
- **The seam** lives with the collectible's other vocabulary (`Catalog.collecting` registers it per type, `MTG::Collecting` is MTG's), ADR 0028 records the choice.
- **`Location.upsert_all`** with a partial unique index needs the conflict target's condition; the apply's writes and the migration's index change are the places to prove it.
- **The migration** follows `.claude/rules/sqlite-and-migrations.md`: reversible, no application model, columns added with SQLite's `ADD COLUMN` where it does not copy the table, and the Solid Queue schema noise restored after migrating (`.claude/memory/migrate-schema-noise.md`).
