# Feature 071: Add to a Deck from the Card Page

**Status:** Approved
**Version:** 0.5.1
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 068](../068-deck-proxies/spec.md) (proxies and `Deck::Proxy.add!`; merged), [spec 065](../065-deck-zones-in-pickers/spec.md) (`Location::Choices`, zones in pickers, `Lot::Move` into a zone; merged), [spec 060](../060-deck-components/spec.md) (the `AddToDeck` design, decision 14; merged), [spec 057](../057-deck-design-rules/spec.md) (the words "Free to use", "Considering", "Deck › Zone"; merged), [spec 062](../062-create-rename-remove-a-deck/spec.md) (decks, zones; merged)
**Branch:** `071-add-to-deck-from-card-page`
**Issue:** [#255](https://github.com/plainprogrammer/Collector/issues/255)
**ADR:** none: a deck is already a location and a zone its child (ADR 0028), a move is already `Lot::Move` and a proxy already a spec 068 row; what is decided here (which lots a count takes, the shape of the finish choice) is this spec's (decisions 4, 5 and 9)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.5.1 | 2026-11-11 | AC-6.3 names spec 072's app-wide select floor (`.c-field select`, merged to main at 9d92ded1), which replaced the `.c-decks`-scoped rule the select was covered by; no change of scope |
| 0.5.0 | 2026-11-11 | Clarified from plan review round 1, no change of scope: AC-1.3 (a card page can't render at all for a type with no vocabulary or no source, because the extensions preload needs the source; the routes are 404 for all of those cases) and decision 2 (the fields are permitted by name with `params.permit`, because `params.expect` answers 400 for the radio a browser leaves out when none is chosen, where AC-5.1 asks for a 422) |
| 0.4.0 | 2026-11-11 | Approved at Gate A (the coordinator, under the maintainer's delegation); decision 16 ruled A by the maintainer: a success lands on the card page; the Open Questions are closed |
| 0.3.0 | 2026-11-11 | From review round 2 (0 blocking, 3 major) and the coordinator's ruling: `Lot.free` and `Lot::MoveIntoZone` are provided by spec 070 (decision 6, FR-2, FR-3); one precedence rule for `use` values (decision 11, AC-5.1); FR-1 allows the zone's own lot to gain copies; AC-1.5 is measured with the coarse sizes injected; the removed-zone 404 comes from the lookup (AC-3.12); the visitor docs and selector joined the supersession list |
| 0.2.0 | 2026-11-11 | From review round 1 (0 blocking, 6 major): the coarse floor is one new rule, the How many field and the new link already have 44px from `components.css` (AC-6.3, AC-6.4, decision 17); AC-1.5 is measurable (one line, inside the row, not clipped) and both `card_page_spec.rb` width assertions are listed; a taken lot `Lot` refuses is a sentence (decision 11, AC-3.11) and the take's transaction rule is in FR-3 (AC-3.12); a printing whose type has no vocabulary or source is 404 (decision 2, AC-1.3); the supersession list gains the visitor system spec, spec 004 AC-9.5, specs 065 and 066's Non-Goals, the roadmap item and the lower-case finish; the card's name, flat parameters, the collection mark on the form, the singular "1 more place", delimiters |
| 0.1.0 | 2026-11-11 | First draft from issue #255, specs 057, 060, 065 and 068, the area docs `collection-and-lots.md` and `tenancy-and-accounts.md`, and `AddToDeck.md` |

---

## Problem Statement

A collector who is looking at a card and thinks "this goes in my Izzet deck" has no way to say so from the card. They would open the deck, add a proxy from the zone's head by searching for the card again, or find their copy in "Your copies" and move it lot by lot. The card page has the printing, the collector's copies and where they are, and it is where the thought happens.

This spec adds "Add to deck" to the card page: one page where the collector chooses a deck and zone, how many, and what to use, either their own free copies, which move into the zone, or a proxy of the printing they are looking at, which is recorded in the zone as spec 068 does.

> **Terms.** *Deck, zone, Considering, lot, label ("Deck › Zone"), vocabulary* are as in [`collection-and-lots.md`](../../architecture/collection-and-lots.md) and specs 062 and 065; *proxy* as in spec 068. A **free copy** is a copy the collector owns that is in no deck zone, Considering counted as a deck zone (spec 057 FR-3; the README's Decks section). A **card** is the gameplay identity its printings share (`Catalog::Identity`); the **shown printing** is the card page's own entry.

## Goals

- The card page has an "Add to deck" action for a signed-in collector, in the head beside "Add a copy".
- One page, `AddToDeck` (spec 060 decision 14), takes a deck and zone, a count and a choice of what to use, and does it in one request.
- "My copies" moves free copies of the card, from any printing, into the zone: the shown printing's first, then the others, all or nothing.
- "A proxy of SET · number finish" records a proxy of the shown printing in the zone, with spec 068's merging, cap and finish rules.
- "My copies" is offered only when copies are free.
- Where the card page's "Free to use" and "In decks" (#50) will sit is stated here, so this action doesn't take it.

## Non-Goals

- **The card page's "Free to use", "In decks" stats and the "In decks" table:** [#50](https://github.com/plainprogrammer/Collector/issues/50). The action sits in the head's action row (decision 1); the stats strip (`c-stats`, today the single Owned stat), the "Your copies" section and the section order stay as they are. When #50 widens the strip to three stats and adds the section, this action needs nothing from it and gives nothing up.
- **Replacing a proxy with a copy** ("Use my copy"): [#257](https://github.com/plainprogrammer/Collector/issues/257). It shares the definition of a free copy and the move of copies into a zone with this spec (decision 6); it chooses lots by hand where this spec's count follows an order.
- **The shape panel** ([#256](https://github.com/plainprogrammer/Collector/issues/256)), deck-size and copy-limit checks ([#258](https://github.com/plainprogrammer/Collector/issues/258), 2.0).
- **Choosing which lots to take** (a condition, a place, a price): the count takes them in the order of decision 5. A collector who wants a particular copy uses "Move copies" on its row, or "Use my copy" when #257 lands.
- **Adding to several zones at once, and a "Create deck" inside this page:** the empty state links to New deck (decision 12).
- **Taking copies out of a deck:** moving a copy out of a zone stays Move copies and bulk Move to….
- **A change to the export, the import, the schema or any table.** Nothing here is new collector-owned data: copies move between locations and proxies are spec 068's rows (decision 13).

## Users and Context

**Primary users:** a collector with a card open, at a desk or at the table, on a laptop or a phone.
**Usage context:** they search a card, open its page, see they own three of it, and want one in "Izzet Tempo › Main" without leaving the card; or they don't own it and want a proxy of it recorded in the zone while it is on screen.
**User mental model:** "put this card in that deck": from my copies if I have free ones, else a stand-in.

## Decisions

1. **The entry point is a secondary "Add to deck" link in the card page's head actions, before "Add a copy"** (the order `ItemPage.html` already draws), with the decks icon (`icons/_decks`), for a signed-in collector on a printing the page can add a proxy of (decision 2). It goes to the page of decision 2 and carries `from=collection` when the card page has it. A visitor on an open catalog has no such link, as they have no "Add a copy" (spec 023 FR-3, AC-4.1). **Where #50's stats sit:** in the stats strip below the head, where "Owned" is today (`ItemPage.md`: Owned, In decks, Free to use); the "In decks" table sits after "Printings". This spec writes into neither; on a phone the head's actions row holds the three controls (the link, "Add a copy" at its flexible width, the "…" menu) and #50 adds nothing to it.
2. **A page of its own, `AddToDeck`, at `GET /catalog/entries/:external_key/deck_additions/new`, written by `POST …/deck_additions`** (`DeckAdditionsController`, `new` and `create`, beside `LotsController`'s routes: the card's key is the path's, as for "Add a copy"). It is a detail page with the card page as its back link, Cancel and the place a success returns to; its app bar and tab bar are those of the card's context (`from=collection` marks Collection, as for Move copies). Signed out is sent to sign in; the page is not part of the open catalog. The path's parameter is `:entry_external_key`, as for `LotsController`'s routes beside it, and the form's fields are flat (`zone_id`, `quantity`, `use`), permitted by name with `params.permit` (`params.expect` answers 400 for the radio a browser leaves out when none is chosen, and that case is a 422 with a sentence, AC-5.1). A printing that isn't searchable (a retired one, a token, an art card) is 404, as spec 068's add pages are (AC-1.10), and so is a printing whose collectible type the instance has no vocabulary or no source for (`Catalog.collecting` or `Catalog.sources` lacks it: spec 068's `require_vocabulary`, whose reason holds here: the finishes and the decks' types come from it); its card page shows no link (decision 1). This is intended for "My copies" too: a retired printing's card page offers neither, because the page's proxy needs a printing a proxy can be made of; the collector reaches their copies' deck through another printing's page or "Move copies". The form's action and the redirect carry the collection mark, as `lots/new`'s do (`catalog_entry_deck_additions_path(@entry, **card_params)`).
3. **"Deck and zone" lists the zones of the account's decks whose collectible type is the printing's,** in `Location::Choices`' order (decks by name, zones in the deck's order), written "Deck › Zone" under one `optgroup` "Decks", with the first option "Choose a deck and zone…" (empty value; the select is `required`). No Places group and no "No location": only a zone can be chosen. Considering is a zone, so it is offered. A deck of another collectible type is not offered: a proxy's printing must be of its deck's type (spec 068 decision 19) and a copy of one type in a deck of another makes no sense; with one collectible type installed the filter shows every deck. A deck of the printing's type is offered only when the page itself is available (decision 2 makes the page 404 for a type the instance no longer registers).
4. **Free means in no deck zone, for the whole card.** The copies offered under "My copies" are the account's lots, of every printing of the card, whose location is none or a place: a lot in any zone, Considering included, is in a deck and is not free (spec 057 FR-3). This is the card page's "Owned" scope (every printing of the card), not the shown printing's: a deck uses a card, and the player's copy of any printing of it is a copy of the card. A proxy never counts, in either direction: no proxy makes a copy not free, and a free copy never replaces one here. The count of free copies is the sum of those lots' quantities; a lot is whole in one place, so a lot is free or not as a whole.
5. **A count takes lots in a fixed, stated order,** which the "My copies" sentence's places follow: the shown printing's free lots first, then the card's other printings' free lots, newest printing first (`Catalog::Entry.newest_first`, the card page's own order of printings); within a printing, in the order of "Your copies" (finish, condition and price paid as stored with unspecified first, then a lot with no location first and the rest by place name; spec 032 AC-4.1). The count takes whole lots from the front while a whole lot fits in what is left, and takes the remainder from the next lot, which splits, leaving the rest of it in its place. Ruled by this spec, not by a ruling to ask for: the alternatives were the lowest condition first (needs a ranking of conditions the core doesn't own: the vocabulary does, and no other feature reads it) and the collector's own pick of lots (that is #257's page). The collector who wants a particular copy moves it first with "Move copies".
6. **"Free" and the move of free copies into a zone are shared with #257 (spec 070), which builds both; this spec uses them and builds neither** (the coordinator's ruling, 2026-11-11). `Lot.free` is a chainable scope on `Lot` (a lot with no location or in a place; a lot in any deck zone, Considering included, is not free: decision 4). `Lot::MoveIntoZone` (`app/models/lot/move_into_zone.rb`) is a plain object taking the account, the zone and chosen `[lot, count]` pairs: it moves each through `Lot::Move`, all or nothing, re-checks that each lot is free under the lock, merges by identity and keeps the 9,999 cap. It decides nothing about which lots a count takes: that is this spec's (decision 5), made by a query object of this spec's own (the card's free lots of every printing in the order of decision 5, built on `Lot.free`; named in the plan) before it calls `MoveIntoZone`. This spec calls `MoveIntoZone` inside its own transaction, which reads the free lots and so judges the count under the same lock (FR-3), so `MoveIntoZone` must work nested in a transaction and let its refusals leave it as exceptions (to be confirmed with spec 070). `Lot::BulkMove` is not used: it moves whole lots only and its `update_all` writes are for the 2-second bar of thousands of lots, which one card's few lots never need.
7. **"My copies (N free: …)" says where the copies are.** The sentence gives the free total and the places the copies are in, in the order they would be taken (decision 5), each place once with its copies summed: "3 free: 2 in Blue binder, 1 in Red box"; copies with no location read "1 with no location". At most five places are named, then "and 2 more places" ("and 1 more place"; a named constant, 5, so the sentence stays a line or two on a phone, and an account with hundreds of places can't make a page of it). It is shown only when N is at least 1; with none free the option isn't drawn (spec 060 decision 14).
8. **"How many" takes 1 up to the limit of what is chosen:** the free total for "My copies" and 9,999 for a proxy (`Deck::Proxy::MAX_QUANTITY`). Its field is a number field with `min` 1, `step` 1 and 1 in it at first. It has no `max`, because the limit follows the radio the collector picks and the page works without scripting: the server decides, with spec 060 decision 23's sentence "Enter a number from 1 to N.", N written with `number_with_delimiter` (decision 11).
9. **A proxy of a printing that lists several finishes is one option per finish.** Spec 060 drew "A proxy of 2X2 · 117 foil" for a printing with one finish. The card page has no finish (it shows a printing, not a lot), a proxy needs one (spec 068 AC-1.4: required when the printing lists any), and a Finish select next to "What to use" would apply to one option only. So "What to use" has "My copies" (when free) and then one proxy option per finish the printing lists, in the vocabulary's order, each "A proxy of `SET · number` Foil" with the finish label the deck page and the notice use (`vocabulary.finish_label`, "Foil": `AddToDeck.md` drew it in lower case, "foil", and takes the label's case); a printing that lists no finish has one proxy option with no finish word. Radio values: `copies`, `proxy:<finish key>`, and `proxy` for a printing with no finish; the server reads them and nothing else (decision 11). This supersedes spec 060 decision 14's "up to two options" for a printing with more than one finish (`AddToDeck.md` and its previews change; "Supersedes and updates"). With one option nothing else is needed, and it is chosen at first, as decision 14 rules; with two or more nothing is chosen at first and both radios are `required`.
10. **Success returns to the card page, with a notice.** A move writes "Moved 3 copies of Lightning Bolt to Izzet Tempo › Main." ("1 copy"); a proxy writes spec 068's sentence, "Added 2 proxies of Lightning Bolt (MH2 · 138, Foil) to Izzet Tempo › Main." (the same `proxy_name`, `proxy_zone_label`). The redirect is 303 to `catalog_entry_path(entry, **card_params)`: the collector started on the card, "Your copies" shows the moved copies as "Deck › Zone" at once, and they can add to a second deck without going back. The alternative, the deck page, shows the result in its zone table; it is one click away through the card's own "Your copies" row only if the collector opens the deck, so this is the one decision of this spec to flag for the maintainer at Gate A (decision 16).
11. **Refusals are 422 re-renders with what was typed, one sentence each, on the field they belong to** (`shared/field_errors`, `aria-describedby`): no zone, "Choose a deck and zone." on the select; no choice, or a `use` of no recognised shape, "Choose what to use." on the radios (`copies`, `proxy` and `proxy:<anything>` are always recognised: `copies` is judged at the write, a proxy value by spec 068's finish rules, so one the printing doesn't list gets the finish sentences below, not this one); a count that isn't a whole number from 1 to the limit, "Enter a number from 1 to N." on How many; "My copies" with none free (they moved while the page was open), "You have no free copy of <name> to use." on the radios, and the page then shows the options that remain, the only one of them chosen as at first; `copies` is always a recognised value, judged at the write (not "Choose what to use."); a taken lot that `Lot` refuses to save for a reason of its own (a finish its printing no longer lists after a catalog refresh, a condition the vocabulary no longer knows: `Lot` validates both on every save), "Nothing changed. <name> (<SET> · <number>) can't be moved until it is edited." above the actions, naming the first such lot in take order, and the collector fixes it with "Edit copy"; a move that would put more than 9,999 copies in one lot of the zone, "Nothing changed. <name> (<SET> · <number>) would have more than 9,999 copies in one lot." above the actions, naming the first lot, in take order, that overflows; a proxy past its cap, spec 068's "A zone can hold at most 9,999 proxies of one printing and finish." on How many; a finish the printing doesn't list or a missing one, spec 068's "That finish isn't available for this printing." and "Choose a finish." on the radios. A zone that isn't one of the signed-in account's zones of a deck of the printing's type (another account's, a place's, a deck's own row, an id that isn't digits only, another type's deck, one removed meanwhile) is 404, nothing written; so is a printing that isn't searchable (decision 2). A blank zone is the 422 above, not a 404.
12. **No deck to add to is a sentence and a link, and no form** (spec 060 decision 23): "You have no decks yet. Add a deck first." with "New deck" to `/decks/new`, under the heading. It is shown when no deck of the printing's type has a zone; with one collectible type installed that means no deck, so the sentence is true, and with more it reads as the design's one sentence (a deck of another type is not a deck to add this card to). The heading stays.
13. **No data model change, no migration, no ADR, no export change.** A move changes a lot's `location_id` and `lot_key` as `Lot::Move` does; a proxy is a `deck_proxies` row. Export format version 4 and its Coverage tables are unchanged, so the spec writes nothing under `docs/export-format/`.
14. **The deck code stays collectible-agnostic.** The controller, views, helper text and models of this feature name no collectible, format or zone key but `considering` (`spec/deck_core_spec.rb`): the finish words, the category name and "Magic" come from the vocabulary, the formats from `Catalog::Formats`. The new files join that spec's list.
15. **The card's name is `entry.name`,** as the card page's heading and Move copies' notice use it, in the heading, the notices and the refusals.
16. **Ruled (the maintainer, option A, 2026-11-11): a success goes to the card page** (decision 10), with the notice naming the deck and zone. Alternative not chosen: the deck page of the zone, which shows the card's row with Owned and Proxy.
17. **The page and the head action follow the design system.** The page is `AddToDeck.md`'s markup inside `c-main c-page c-decks` (the Decks pages' class carries the 44px floor of `c-btn`, the select's coarse floor and the long-name wrap, spec 062, 068); the one new piece of CSS is a coarse-pointer floor for the radio rows (AC-6.3), under its own heading in `collector/additions.css`. The How many field's 44px, and the card page's new link's, are already the app-wide coarse rule `.c-btn, .c-input { min-height:44px }` of `components.css`.

## User Stories

### Story 1: The card page offers "Add to deck"

**As a** collector looking at a card
**I want** an "Add to deck" action on the card
**So that** I can put it in a deck without leaving it.

**Acceptance criteria:**

- [ ] **AC-1.1** Given a signed-in collector on the card page of a searchable printing When it renders Then the head's action row has a secondary link "Add to deck" with the decks icon, before "Add a copy", whose `href` is `/catalog/entries/<key>/deck_additions/new` (with `from=collection` when the page has it), and the row still has "Add a copy" and, when the printing has a Scryfall link, the "…" menu
- [ ] **AC-1.2** Given a visitor on an open catalog When they open a card page Then it has no "Add to deck" link, and `GET`/`POST` of the deck-addition routes redirect to sign in without reading the account's data
- [ ] **AC-1.3** Given a card page of a retired printing or a token When it renders Then it has no "Add to deck" link; and for each of those, and for a printing whose collectible type has no vocabulary or no source (whose card page itself can't render: the page's extensions preload needs the source), the deck-addition routes are 404
- [ ] **AC-1.4** Given the card page When its stats strip, "Your copies", "Printings" and "Format legality" are read Then the strip is the single Owned stat (`c-stats--single`) and the page has no "Free to use", "In decks" or "In decks" section (the example asserts the strip and their absence itself, as no example pins it today), so #50's places are untouched; the head is the only part of the page that changes
- [ ] **AC-1.5** Given the card page at 390px and 360px When it renders with its three head controls Then the row stays on one line with no horizontal overflow, with the "…" menu present and absent, every control lies inside the row, "Add a copy" is not clipped (its width is at least its content's) and the row's height is one control's; the example measures at 360px a second time with the coarse sizes injected (`.c-btn { min-height:44px } .c-btn--icon { min-width:44px }`, the app-wide rule of `components.css`, which a fine-pointer browser doesn't apply and which makes the menu 8px wider), and each control is 44px high by that rule, which the example reads. If the row can't hold the three controls at 360px, the plan changes the head's rule (shared with the deck page's head, whose examples then change too) and says so in `verification.md`; the outcome of this AC is that nothing is clipped or overflows

### Story 2: The Add to deck page

**As a** collector
**I want** one page that says where, how many and what to use
**So that** I can finish in one go.

**Acceptance criteria:**

- [ ] **AC-2.1** Given a signed-in account with a deck of the printing's type When `GET …/deck_additions/new` is requested Then the answer is 200, the title is "Add <card name> to a deck · Collector", the heading reads "Add <card name> to a deck", the back link and Cancel go to the card page (with the collection mark when given), and the form posts to `…/deck_additions`, carrying the collection mark when the page has it
- [ ] **AC-2.2** Given the page When the "Deck and zone" select is read Then it is one native `select` with a label, `required`, whose first option is "Choose a deck and zone…" with an empty value, followed by one `optgroup` "Decks" holding "Deck › Zone" for every zone of every deck of the printing's type (Considering included), deck by deck in the order of the pickers, and no "Places" group and no "No location"
- [ ] **AC-2.3** Given a deck of another collectible type than the printing's When the select is read Then none of its zones is offered; given an account whose only decks are of another type, or none, Then the page shows "You have no decks yet. Add a deck first." with a "New deck" link to `/decks/new`, no form and the heading
- [ ] **AC-2.4** Given the page When "How many" is read Then it is a `c-input` number field with a label, `min` 1, `step` 1, no `max`, `required` and 1 in it
- [ ] **AC-2.5** Given an account with free copies of the card, in lots of the shown printing and of another printing, in places and with no location When "What to use" is read Then it is a fieldset with a visible legend whose first radio is "My copies (N free: …)", N the free total and the places in the order of decision 5 with their copies summed ("2 in Blue binder, 1 in Red box", "1 with no location", at most five places then "and N more places"), followed by the proxy options of decision 9; nothing is chosen and every radio is `required`
- [ ] **AC-2.6** Given copies of the card in a deck zone (Considering among them) and a proxy of the card in a zone When "My copies" is read Then those copies are not counted or named and the proxy changes no count; given copies in a deck zone only, Then "My copies" isn't drawn
- [ ] **AC-2.7** Given a printing that lists foil and nonfoil and no free copy When "What to use" is read Then it has two proxy radios in the vocabulary's finish order ("A proxy of SET · number Nonfoil", "A proxy of SET · number Foil", `SET · number` in `is-data`), and nothing is chosen; given a printing that lists one finish and no free copy, Then it has one proxy radio, already `checked`; given a printing that lists none, Then one proxy radio with no finish word, `checked`; given free copies and one finish, Then two radios and nothing chosen
- [ ] **AC-2.8** Given another account's free copies of the same card When the page is read Then they are not counted, named or moved (a positive control: the owner's own copies show), and the account's lots in another card are not counted
- [ ] **AC-2.9** Given the page's reads When the number of statements is counted with 1 lot and then with 40 lots of the card across 10 places, and with 1 deck and then 10 decks of 3 zones Then it is the same (the example compares the two counts, with no number written in it), and the card page's count with the new link is the count without it

### Story 3: Add my copies to a zone

**As a** collector who owns free copies
**I want** to move some of them into a deck zone
**So that** the deck lists copies I own.

**Acceptance criteria:**

- [ ] **AC-3.1** Given 2 free copies of the shown printing in Blue binder and 1 of another printing in Red box, and "My copies" with a count of 1 When it is submitted for a zone Then one copy of the shown printing is in the zone and the other one stays in Blue binder (the lot splits), the Red box lot is untouched, the response is 303 to the card page and the notice reads "Moved 1 copy of <name> to Izzet Tempo › Main."
- [ ] **AC-3.2** Given the same copies and a count of 3 When it is submitted Then the whole Blue binder lot and the whole Red box lot are in the zone (same lot ids when the zone had no lot of that identity), the lots' other fields are kept, and the notice reads "Moved 3 copies of <name> to Izzet Tempo › Main."
- [ ] **AC-3.3** Given a count over the free total (4 of 3) When it is submitted Then the answer is 422, "Enter a number from 1 to 3." is on How many, what was typed and chosen is kept, and no lot changed
- [ ] **AC-3.4** Given a free lot whose identity (printing, finish, condition, price paid) the zone already has a lot of When it is taken Then the zone's lot gains the copies and survives and the taken lot is removed or reduced as `Lot::Move` does (spec 032 AC-3.4, AC-3.5), and a second lot of the same identity from another place merges into the same zone lot
- [ ] **AC-3.5** Given a take that would put more than 9,999 copies in one lot of the zone, in the second lot of three When it is submitted Then the answer is 422 with "Nothing changed. <name> (<SET> · <number>) would have more than 9,999 copies in one lot.", and no lot changed, the first lot's move rolled back (a request or model example on the real database, not a stub: the take lets the refusal leave its own transaction before it is turned into a sentence)
- [ ] **AC-3.6** Given copies taken into Considering When the card page is read again Then "Your copies" lists them as "Deck › Considering", and the card page's Owned is unchanged
- [ ] **AC-3.7** Given the order of decision 5 When lots of the shown printing, of two other printings of different ages, and of two finishes and places are free and a count takes part of them Then the lots taken are the shown printing's first, then the newer other printing's, then the older's, within a printing in "Your copies" order, and the "My copies" sentence names the places in that order
- [ ] **AC-3.8** Given a free lot another tab moved into a deck, or removed, after the page was opened When the form is submitted with "My copies" Then the free copies are read again inside the write: the count is judged against what is free then ("Enter a number from 1 to N." with that N, or "You have no free copy of <name> to use." when none), and no lot is taken from a zone
- [ ] **AC-3.9** Given two submissions of one take together (a double click) When both run Then no copy is created or lost: the second finds the lots as the first left them and takes what is still free or is refused as AC-3.8 says
- [ ] **AC-3.10** Given a take When it is made Then no proxy, deck, location or other account's row changes, and no other card's lot changes
- [ ] **AC-3.11** Given a free lot whose printing no longer lists its finish (a catalog refresh changed the finishes) or whose condition the vocabulary no longer knows, taken second of three When it is submitted Then the answer is 422 with "Nothing changed. <name> (<SET> · <number>) can't be moved until it is edited." above the actions, the first lot's move is rolled back, and nothing changed
- [ ] **AC-3.12** Given the zone removed after the page opened When the take is submitted Then the answer is 404 and no lot changed (the zone's lookup inside the write finds nothing; for the proxy path `ActiveRecord::InvalidForeignKey` is the backstop and the controller answers 404 as `LotsController` does)

### Story 4: Add a proxy to a zone

**As a** collector who doesn't own the card
**I want** to record a proxy of it in a zone
**So that** the deck lists everything it needs.

**Acceptance criteria:**

- [ ] **AC-4.1** Given a proxy radio and a count from 1 to 9,999 When it is submitted for a zone Then a proxy of the zone, the shown printing and the radio's finish exists (spec 068's merging: the zone's proxy of that printing and finish gains the count and keeps its id, else one is created), no lot changes, the response is 303 to the card page and the notice reads "Added 2 proxies of Lightning Bolt (MH2 · 138, Foil) to Izzet Tempo › Main." ("1 proxy"; the finish only when the proxy has one)
- [ ] **AC-4.2** Given a zone whose proxy of that printing and finish holds 9,990 When 10 are added Then the answer is 422 with spec 068's cap sentence on How many and the proxy is unchanged
- [ ] **AC-4.3** Given a finish the printing doesn't list, a bare `proxy` for a printing that lists finishes, or a `proxy:<finish>` for one that lists none When it is submitted Then the answer is 422 with "That finish isn't available for this printing." or "Choose a finish." on the radios and nothing is written
- [ ] **AC-4.4** Given a count that isn't a whole number from 1 to 9,999 for a proxy When it is submitted Then the answer is 422 with "Enter a number from 1 to 9,999." on How many and what was typed kept
- [ ] **AC-4.5** Given a proxy added from this page When the deck page is read Then the card's row shows it with the dashed Proxy tag in its zone, owned copies unchanged and the Owned of the card page unchanged
- [ ] **AC-4.6** Given two submissions of one proxy add together When both run Then there is one row of that zone, printing and finish with the quantities added, or the second is refused at the cap, never two rows or a 500 (spec 068 AC-1.9)

### Story 5: Refusals, tenancy and the same page without scripting

**As a** collector
**I want** a clear answer to a wrong or stale request
**So that** nothing changes without my meaning it.

**Acceptance criteria:**

- [ ] **AC-5.1** Given a submission with no zone, with no choice, or with a `use` of no recognised shape (not `copies`, `proxy` or `proxy:<text>`) When it is submitted Then the answer is 422 with "Choose a deck and zone." on the select or "Choose what to use." on the radios, what was typed kept, and nothing is written
- [ ] **AC-5.2** Given another account's zone, a place's id, a deck's own location id, a zone id of another type's deck, an id with letters, and a zone removed meanwhile When each is posted as the zone Then the answer is 404, nothing is written, and the body shows nothing of the other account's deck (its name is built at run time, and the owner's own request shows it)
- [ ] **AC-5.3** Given a request with `account_id`, `user_id`, `location_id`, `kind` or `lot_id` among its parameters When it is handled Then each is ignored: the account is the signed-in one, the zone is `zone_id`, the lots are the account's free lots of the card, and the proxy's entry is the path's
- [ ] **AC-5.4** Given a signed-out request to the page or the create When it is made Then it is sent to sign in and nothing is written
- [ ] **AC-5.5** Given a browser without scripting When a collector runs the whole path for "My copies" (the card page, the link, the form, the notice on the card page, "Your copies" and the deck page showing the copies) and again for a proxy Then each works end to end: a system spec per use runs it under `rack_test` with the driver asserted, `driven_by :rack_test` declared before the `let!` that signs in (spec 067's lesson)

### Story 6: The page follows the design system

**As a** collector on any device and either theme
**I want** the page to read and fit like the others
**So that** it feels like one app.

**Acceptance criteria:**

- [ ] **AC-6.1** Given the page at 360px and 640px, light and dark, with a deck name of 60 characters in the select, a place name of 60 characters with no space in the "My copies" sentence and a card name of 60 characters with no space in the heading When it is rendered Then there is no horizontal overflow, the select cuts its text without widening the form, the sentence and the heading wrap inside the word, and the radio rows wrap
- [ ] **AC-6.2** Given the page's radios When one has keyboard focus Then its row shows the 2px `focus` ring (spec 060 AC-5.3)
- [ ] **AC-6.3** Given every control of the page, on a coarse pointer When its size is read Then each meets 44px by the rule that covers it, which the example reads (headless Firefox has a fine pointer and can't emulate one; spec 068's lesson): the primary button and the Cancel link (`.c-decks .c-btn`, at every pointer), the Deck and zone select (`.c-field select`, coarse: spec 072's app-wide rule, which replaced spec 068's `.c-decks`-scoped one), the How many field (`components.css`' coarse `.c-input { min-height:44px }`, app-wide), each radio row (the one new rule, `@media (pointer: coarse) { .c-decks .c-pick .c-check { min-height:var(--touch-floor) } }`, whose label is the tap target), the "New deck" link of the empty state (an inline link in a sentence, exempt as spec 062's are), the app bar's back link and tab bar (the app's own, as on every page) and the avatar, which is 32px on every page and stays an existing, shared exemption; the example reads the new rule's selector, its `@media (pointer: coarse)` and `--touch-floor`, the three existing rules, and measures the buttons as drawn
- [ ] **AC-6.4** Given the new rule When the stylesheet is read Then it uses token variables only, sits in `collector/additions.css` under its own heading and is scoped to `.c-decks .c-pick`, so no other page changes; it also lifts `UseMyCopy`'s radios if that page ever has them (it has lot rows, not radios) and no other control
- [ ] **AC-6.5** Given the page When it renders Then it uses only `c-*` classes and token variables, no inline style, and a heading, a form with visible labels and one primary action; an error is tied to its field by `aria-describedby`

## Functional Requirements

### FR-1: The action and the page

The head link of Story 1 and the page of Stories 2 to 5, a `ChoicePage` variant (`AddToDeck.md`). **Must:** find the printing by key, searchable only; offer the zones of the signed-in account's decks of the printing's type; read the free copies and the options inside the request, and judge a take inside the write; write through `Lot::Move` and `Deck::Proxy.add!`; show a refusal on its field. **Must not:** accept an account, a user, a kind, a location id other than the chosen zone, or a lot id; create a deck, a place or a zone; change a lot outside the card, take copies from a lot that is in a zone, or change a zone's lot but by adding the taken copies to it (AC-3.4); name a collectible, format or zone key but `considering` in a core file.

### FR-2: Free copies

The definition of decision 4 (`Lot.free`, provided by spec 070) and the order of decision 5, as one query object of this spec (decision 6). **Must:** be tenant-scoped through the account; count a card's every printing; leave a lot in a zone out; leave proxies out; be reusable by #50 (the card page's free count) and #257 ("Use my copy" lists the same lots; `UseMyCopy.md` groups them by the proxy's printing and finish, which is a different order for its page: the scope is the shared part and the order may take a finish). **Must not:** read a collectible's vocabulary to rank lots.

### FR-3: The take

The take: this spec's count and order over spec 070's `Lot::MoveIntoZone` (decision 6). **Must:** run in one write transaction (SQLite's immediate lock) that looks up the zone and reads the free lots first, inside it; take whole lots, then split the last; let a refusal leave the transaction before it is turned into a sentence (`Lot::Move` opens its transaction without `requires_new`, so it joins the take's: a take that rescues a refusal inside its block would commit the lots already moved); answer 404 for `ActiveRecord::InvalidForeignKey` (the proxy path's backstop); choose the sentence from what the refusal carries, never from an exception's text: a refusal with `Lot::FULL_MESSAGE` is the over-9,999 sentence, and one with no message of its own (a `Lot` that failed its own validation) is "can't be moved until it is edited", each naming the lot (to be confirmed against `Lot::MoveIntoZone`'s refusals, decision 6; `Lot::Move` reloads its lot before it re-raises, which is safe only because the take lets the error leave); merge by identity through `Lot::Move`; refuse past 9,999 and write nothing; leave every other lot alone. **Must not:** use `update_all` or `delete_all`; move a lot out of a zone; change a proxy.

## Non-Functional Requirements

### Performance

- The page runs a number of statements that doesn't grow with the card's lots, places, or the account's decks and zones (AC-2.9); a take writes a bounded number of statements per lot taken (a card has few free lots), none per other lot of the account.

### Security

- Every read and write goes through `Current.account` (the zone through the account's locations, the lots through the account); another account's anything is 404 or absent. No parameter names an account, a user or a lot; strong parameters (`params.expect`); every value that reaches SQL is bound; output is escaped; CSRF as the other forms. A signed-out request is sent to sign in; the page is not in the open catalog.

### Reliability and the hosted door

- A take is all or nothing and is judged on the lots as they are inside the write; a stale form can't create or lose copies. No migration, no table, no recurring or background cost; hosted-door rule 2 holds (no admin page shows a deck or a copy).

### Accessibility

- Every field has a visible label; the radios are in a fieldset with a legend; an error is tied to its field and read with it; no colour carries meaning alone; focus is visible on every control; every control meets the 44px floor by a rule the example reads (AC-6.3).

### Design system and documentation

- Token variables and `c-*` classes only; new CSS under its own heading in `collector/additions.css`, with the change written into `AddToDeck.md`. The area docs `collection-and-lots.md` (the card page's head action, the page, free copies and the take, the invariant and decisions, constants, #255 off the open list), `tenancy-and-accounts.md` (the new routes' 404 rules), `CLAUDE.md`'s deck sentence and `docs/specs/README.md` change in the same PR.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Another account's zone, a place's id, a deck's own id, an id with letters, a zone of another type's deck, a zone removed meanwhile | 404, nothing written |
| A printing that is retired, a token or an art card, an unknown key | 404 |
| Signed out | Sent to sign in; no catalog page links the action |
| No zone chosen | 422 "Choose a deck and zone." on the select |
| No choice, or a `use` of no recognised shape | 422 "Choose what to use." on the radios (an unlisted `proxy:<finish>` is the finish row below) |
| A count that isn't a whole number from 1 to the limit | 422 "Enter a number from 1 to N." (N: the free total for My copies, 9,999 for a proxy) |
| "My copies" and no free copy now | 422 "You have no free copy of <name> to use."; the page shows the options that remain |
| A take past 9,999 in one lot of the zone | 422 "Nothing changed. <name> (<SET> · <number>) would have more than 9,999 copies in one lot."; nothing written |
| A proxy past 9,999 | 422 spec 068's cap sentence on How many |
| A missing or unlisted finish | 422 "Choose a finish." / "That finish isn't available for this printing." on the radios |
| The account has no deck of the type | The sentence and "New deck"; no form |
| Two submits together | No copy created or lost; one proxy row; the second refused or merged |
| A copy moved into a zone in another tab | The count is judged on what is free at the write |
| A free lot the vocabulary no longer accepts as it is saved | 422 "Nothing changed. <name> (<SET> · <number>) can't be moved until it is edited."; nothing written |
| The zone removed after the page opened | 404; nothing written |

## Open Questions

None. Decision 16 is ruled (the maintainer, 2026-11-11, at Gate A); the rest is approved as written.

## Out of Scope (Future Considerations)

- "Free to use", "In decks" and the "In decks" table on the card page ([#50](https://github.com/plainprogrammer/Collector/issues/50)); "Use my copy" ([#257](https://github.com/plainprogrammer/Collector/issues/257)); the shape panel ([#256](https://github.com/plainprogrammer/Collector/issues/256)); deck checks ([#258](https://github.com/plainprogrammer/Collector/issues/258)).
- Choosing which lots to take; adding to several zones in one request; creating a deck from this page.
- An "Add to deck" from the search results and the printings page's tiles.

## Supersedes and updates

Written from a grep of `spec/`, `docs/` and `app/` for `Add to deck`, `AddToDeck`, `A proxy of`, `My copies`, `Free to use`, `c-item__actions`, `Add a copy` and `#255` (the grep is named in `verification.md`).

- **Supersedes** spec 060 decision 14 and AC-5.1 in part: "What to use" has up to two options only for a printing with one finish or none; a printing with several finishes has one proxy option per finish (decision 9). `AddToDeck.md`'s "What to use has up to two options" bullet and its "What #255 decides" bullet, and the previews `AddToDeck.html` and `AddToDeckPhone.html` (a second proxy radio), change; `spec/system/design_system_deck_components_spec.rb`'s AddToDeck examples build their own markup (`add_to_deck_html`) and gain a multi-finish variant.
- **Fills** spec 060's Non-Goal and Error Scenarios row for AddToDeck ("a count past the free copies, a choice missing past the browser's check" are #255's, drawn here, decision 11) and spec 060 decision 23's first state (the sentence is used as written).
- **Fulfils** the Non-Goals that name #255 as future work: spec 068's ("Adding a proxy from a card page") and Out of Scope, spec 065's ("Add to deck from the card page") and spec 066's ("the add-to-deck flow from a card page"), and the roadmap's item 14j (`docs/roadmap.md` is marked when the feature merges, by the distillation step). `collection-and-lots.md` has no line about #255; its card-page section and its open-issues line (which still says proxies are not built, a stale clause fixed in the same edit) gain the action. The decks-and-locations issue design (`docs/superpowers/specs/2026-11-09-…`) decision 17 draws one proxy option; it is history and stays.
- **Updates** `spec/system/card_page_spec.rb`'s phone example ("a back link and a full-width add action"): its two width assertions (`widths[2] > widths[0] / 2`, line 24, and the primary wider than 200px, line 25) assume one primary button and the menu in the row at 390px; with "Add to deck" in it neither holds (about 170px against about 179px; AC-1.5 states the new bar, measurable in a fine-pointer browser: one line, inside the row, not clipped, no overflow). The deck page's examples (`deck_page_spec.rb` lines 235 and 256) read the same `.c-item__actions` rules of another page and are not changed by an addition to the card page's markup. `ItemPage.md` and `ItemPagePhone.md` gain the action's place in their text (the previews already draw it).
- **Extends** spec 023 AC-4.1's list of what a visitor's pages lack with "Add to deck" in both examples that list "Add a copy" (`spec/requests/catalog/visitors_spec.rb`, whose absent-selector list at line 196 also gains `a[href*='/deck_additions/new']`, and `spec/system/visitor_catalog_spec.rb`), and `docs/design-system/components/VisitorHeader.md` line 42 ("no 'Add a copy' button") gains "Add to deck". **Supersedes in part** spec 004 AC-9.5's "`Add a copy` stays visible full-width" on a phone: it stays visible and is the flexible control of the row, beside "Add to deck" and the menu, as `ItemPagePhone.md` already says.
- **Updates** `spec/deck_core_spec.rb`'s file list and count for the new files, and `docs/architecture/tenancy-and-accounts.md`'s route table.
- Recorded in the specs index in both directions (spec 060, 068 gain a pointer).

## Documents and Files Changed

Listed so the plan can name them; the plan decides the code.

- `docs/design-system/components/AddToDeck.md`, `ItemPage.md`, `ItemPagePhone.md`, `docs/design-system/previews/AddToDeck.html`, `AddToDeckPhone.html`, `collector/additions.css` (one coarse-pointer rule under a heading).
- `docs/architecture/collection-and-lots.md`, `tenancy-and-accounts.md`, `CLAUDE.md`'s deck sentence, `docs/specs/README.md`, `spec/deck_core_spec.rb`.
- New: `DeckAdditionsController`, its routes and views, a form object, the free-copies query object (decision 6; `Lot.free` and `Lot::MoveIntoZone` come from spec 070's commits, cherry-picked), a helper for the sentence and options, and their specs (model, request, system, a no-script system example per use, a statement-count example).
- `app/views/catalog/entries/show.html.erb` (the head link), `Location::Choices` (a choice of decks by collectible type) and `spec/system/card_page_spec.rb`.

## Verification

Written at plan time into `verification.md`: each AC with the spec that proves it; the system specs (headless Firefox) measure overflow at 360px, 640px and 1280px in both themes with the long names of AC-6.1 and read the coarse rules of AC-6.3; the no-script examples run the whole path under `rack_test`; each "absent" assertion has a positive control built at run time (spec 066's lesson) and the take's examples include a stale-form and a double-submit case; the review's screenshots of the page with free copies, with none, with several finishes, the refusals and the card page's head at 360px and 1280px, light and dark, are kept with the spec.
