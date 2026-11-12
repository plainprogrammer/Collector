# Feature 070: Replace a Proxy with a Copy

**Status:** Draft
**Version:** 0.3.0
**Created:** 2026-11-11
**Last Updated:** 2026-11-11
**Depends on:** [spec 068](../068-deck-proxies/spec.md) (proxies and the row menu this spec adds two items to; merged), [spec 060](../060-deck-components/spec.md) (`UseMyCopy`, its markup, rules and previews; merged), [spec 057](../057-deck-design-rules/spec.md) (the vocabulary "Free to use"; merged), [spec 032](../032-lot-in-a-location/spec.md) (`Lot::Move`; merged) and [spec 065](../065-deck-zones-in-pickers/spec.md) (a lot in a zone; merged)
**Branch:** `070-replace-proxy-with-copy`
**Issue:** [#257](https://github.com/plainprogrammer/Collector/issues/257)
**ADR:** none: ADR 0028 already makes a zone a location that holds lots and spec 068 made a proxy a row that belongs to a zone; this spec adds two ways a proxy becomes lots and records them as decisions
**Overlap:** [#255](https://github.com/plainprogrammer/Collector/issues/255) (spec 071) also needs "free copies" and a move of free copies into a zone; decision 8 names the shared parts and leaves their names to the plan

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.3.0 | 2026-11-11 | From review round 2 (0 blocking, 1 major, 6 minor): a refused page rewrites the `shown` fields from a fresh read and a resubmit then succeeds (decisions 9, 10; AC-3.9, AC-4.6), a missing or malformed `shown` fails closed, the shown check is the quantity and the free state (not the place), the vocabulary check is made in the judging step, the proxy line is written one way, and a changed lot that also fails its range shows both sentences |
| 0.2.0 | 2026-11-11 | From review round 1 (1 blocking, 4 major): the form posts what it showed and a changed lot or proxy is refused, so a double submit can't move twice (decisions 7, 9, 10; AC-3.9, AC-3.11, AC-4.6a); the refusals propagate out of the transaction and the lots are re-read after it (decision 7); a lot `Lot::Move` can't save gets a sentence (decision 9, AC-3.14); the vocabulary gate reads the proxy's printing's type (decision 1, AC-1.4); the touch-floor controls and rules are listed in full and `c-decks` goes on Use my copy's `main` (AC-6.2); the supersession list is widened and spec 068 AC-4.2 and decision 11 are superseded in part; precedence of the sentences; minor fixes |
| 0.1.0 | 2026-11-11 | First draft from issue #257, specs 057, 060, 065 and 068, the area doc `collection-and-lots.md`, `UseMyCopy.md` and the lessons of 2026-11-11 |

## Problem Statement

Spec 068 let a collector list a card their deck needs and they don't own, as a proxy. The day they get the card, or find they already own it, the proxy should become the real thing: the deck should show the copy as owned and the proxy should shrink or go. Today the collector must do it in three steps on three pages: add the copy to the collection, move it into the zone, then lower or remove the proxy by hand, and every step is a chance to pick the wrong printing, the wrong zone or the wrong number.

This spec adds the two replacements the issue design drew: **Use my copy**, which moves free copies the collector already owns into the proxy's zone, and **Add a new copy**, the existing Add a copy form opened with the proxy's printing, finish and zone filled in. Either one lowers the proxy by the copies used and removes the proxy at zero, in the same write as the copies arrive.

> **Terms.** *Deck, zone, Considering, lot, label, merge, cap, proxy, card row* are as in [`collection-and-lots.md`](../../architecture/collection-and-lots.md) and spec 068. The *card* is the gameplay identity a printing's siblings share (`Catalog::Identity`), so "free copies of the card" are those of any of its printings. A copy is **free** when it is in no deck zone, Considering included (decision 2). The proxy being replaced is *the proxy*; its *count* is its quantity.

## Goals

- A collector opens a proxy's row menu and chooses "Use my copy": the free copies of the card are listed, the proxy's own printing and finish first, and they enter the number to take from each lot.
- A collector chooses "Add a new copy": the Add a copy form opens for the proxy's printing with its finish and zone filled in, and the copy they add lands in that zone.
- Either action moves or adds the copies and lowers the proxy by the same number, or removes it at zero, in one write that does all of it or none.
- A copy still in a binder or a box is the only thing "Use my copy" touches: nothing already in a deck zone is offered or moved.

## Non-Goals

- **Add to deck from a card page**, which chooses a deck and zone and how many free copies (or a proxy) to use ([#255](https://github.com/plainprogrammer/Collector/issues/255), spec 071), and **which lots a count takes** there: this spec lets the collector choose lots one by one.
- **The card page's "Free to use" and "In decks" counts** ([#50](https://github.com/plainprogrammer/Collector/issues/50)) and **the shape panel** ([#256](https://github.com/plainprogrammer/Collector/issues/256), spec 069).
- **Taking copies out of another deck's zone** to use here: a copy in a zone is not free (decision 2); a collector moves it out first with Move copies.
- **Moving or replacing in bulk** (many proxies at once) and **replacing a proxy with a proxy** of another printing.
- **A change to the export format, the import or any table:** no new data exists (decision 10).
- **Changing "Add a copy"** on the card page, which stays as it is; "Add a new copy" is a deck-side page that shares its form (decision 5).

## Users and Context

**Primary users:** a collector with a deck they have been building, with some proxies, holding the cards at a desk or at the table, on a laptop or a phone.
**Usage context:** "I opened a pack and got the second Lightning Bolt: add it to Main and take one proxy off." Or "I own a spare Lightning Bolt from another set in a box: use it for the proxy."
**User mental model:** "the proxy is a placeholder; when I have the card, the placeholder goes and the card is in the deck."

## Decisions

Each is my call unless it names a ruling; alternatives are listed so the coordinator can redirect.

1. **Two items at the top of a proxy row's menu (spec 060 decision 17, ruled A; supersedes spec 068 decision 5's "proxy items only").** A row with proxies lists "Use my copy", "Add a new copy", "Change proxy count", then, after the separator, "Remove proxy" (danger, last). A row with proxies of two finishes has the item for each, the finish named as spec 068 names it: "Use my copy for Foil proxy", "Add a new copy for Foil proxy"; the order is every "Use my copy", then every "Add a new copy", then every "Change", the separator and every "Remove". A row with no proxy is as it was. The two items are links to pages, no `form` in the menu (spec 068 AC-2.7 stands for the rest). A proxy whose printing's collectible type the instance no longer registers leaves the two items out, because their pages need that type's vocabulary for the finish and condition labels and the form's checks; the gate reads the **proxy's printing's** type, not the deck's, since a change of format can leave a deck of one type holding proxies of another (spec 068 decision 19). The pages are 404 for such a proxy.
2. **Free means in no deck zone (spec 057's vocabulary: "Free to use").** A lot is free when its place is none or a place (kind `place`); a lot in any zone of any deck, Considering included, is not. Copies in a lot are all free or none: the lot is in one location, so a lot's free count is its quantity. Proxies never change what is free. This is the definition #255 and #50 need, so decision 8 gives it one home. *Alternative:* count a lot of this deck's other zones as free; it would let one click empty Sideboard into Main, which Move copies already does deliberately.
3. **Use my copy is a page, then a form (spec 060 decision 15, ruled B: a quantity on every lot).** `GET /decks/:deck_id/proxies/:proxy_id/replacement/new` and `POST /decks/:deck_id/proxies/:proxy_id/replacement` (the proxy by its id under its deck, spec 068 decision 13's shape). The page is `UseMyCopy.md`: the heading "Use my copy of Lightning Bolt", the muted line "Replaces 1 proxy in Izzet Tempo › Main · 2X2 · 117, Foil", and the free lots of the card, each its own row with a number field. **The lots listed** are the account's free lots of every printing of the card (retired printings included, as the card page's "Your copies" lists them). **"This printing"** holds the lots whose printing and finish are the proxy's (a proxy with no finish matches a lot with none); **"Other printings"** holds all the rest, including another finish of the proxy's printing, and a group with no lot is left out. Nothing is preselected: every field is 0. Within a group the lots are in the order of the card page's "Your copies" (newest printing, then finish, condition, price paid, place). *Alternative:* one lot as a radio and a How many; spec 060 ruled against it.
4. **A lot row says enough to tell two lots apart.** The row's label reads, in order: the printing as the deck page writes it (`SET · number`, with ` · LANG` for a language other than English), the finish and the condition as the vocabulary labels them (each left out when the lot has none), "paid $1.25" in the account's currency when the lot has a price, the place ("No location" when unplaced) and "×N free". Spec 060's label left the price out; two lots of one printing, finish, condition and place that differ only by price would read the same. The label names the field (spec 060 AC-6.4). *Alternative:* leave the price out and merge-list identical rows; they are distinct lots, so the collector could not tell which they were taking.
5. **Add a new copy is the Add a copy form on a deck-side page.** `GET /decks/:deck_id/proxies/:proxy_id/copy/new` and `POST /decks/:deck_id/proxies/:proxy_id/copy`. The page is the form of `lots/_form` (Quantity, Finish, Condition, Price paid), for the proxy's printing, with the Finish select set to the proxy's finish and the Location shown as read-only text, the proxy's zone ("Izzet Tempo › Main"), instead of the select: a copy that replaces a proxy lands in its zone and a collector who wants it elsewhere uses the card page's Add a copy. The printing is fixed by the page (the proxy's); the finish stays editable, as Use my copy lists other finishes. The Quantity field starts at 1 and its largest value is the proxy's count; "Add copy" and "Cancel" (to the deck page). *Alternative:* start Quantity at the proxy's count; one click would replace every proxy, which is the destructive end of the range, so the default is the small one. *Alternative:* route through the card page's `/catalog/entries/:key/lots/new?proxy=…`; the deck lookup (FindsDeck), the 404 rules and the return path would have to be re-done in `LotsController`, which the card page owns.
6. **Both actions are one write that does all or none.** In one transaction the copies are moved or added and the proxy is read again under the write lock, lowered by the copies used, and removed when that reaches zero; a refusal anywhere changes nothing. The proxy's id and times stay when it is only lowered; a removal removes the row. The two actions are the fifth and sixth writers of a proxy (spec 068 decision 11 listed the add, change and remove pages, the format change, a deck's removal and the import); every other path that adds, moves, edits, bulk-moves, types, scans or removes a copy still never changes a proxy (spec 068 AC-4.2).
7. **Use these copies moves through `Lot::Move`.** Each lot with a number above 0 is moved with `Lot::Move` (copies N, to the proxy's zone), which already splits a lot, merges into the zone's lot of the same identity, keeps the 9,999 cap and rebuilds the lot key with the zone's id; the moves and the proxy's change run in one transaction, so a refusal in the third lot undoes the first two. `Lot::BulkMove` is not used: it moves every copy of a lot, and a number of copies from a lot is the point of the page. **How the refusals travel.** The replacement object judges everything it can before calling `Lot::Move`: inside the one transaction, under the write lock, it reads the proxy and the chosen lots again and checks each number against the lot's current free state and the sum against the proxy's count, so `Lot::Move`'s own sentences ("Choose from 1 to N copies.", "already there") never reach this page and a lot deleted meanwhile is a refusal and not `Lot::Move`'s 404. A refusal from `Lot::Move` itself (the cap only: the stale-vocabulary check of decision 9 is made in the judging step, because `Lot::Move` re-raises that failure with no message) leaves the transaction by an exception that nothing rescues inside it, so every earlier move is rolled back; `Lot::Move`'s own `reload` after a refusal reads a transaction that is still open (it is nested), so the page that shows the refusal is built from a fresh read after the rollback, never from the lots in memory. A lot whose quantity differs from what the page showed, or that is no longer free, is a refusal (decision 9), never a silent smaller move.
8. **The parts #255 shares have one home each, and the plan names them.** What "free" is (decision 2) is a chainable query on `Lot`; the move of chosen lots' copies into a zone, all or nothing, with the free test re-checked under the lock, is a plain object around `Lot::Move`. #255's "How many" takes copies from lots in an order of its own and hands the same object the lot-and-count pairs; this spec's page hands it the collector's pairs. The names and files are for the plan, reported at Gate B so the coordinator can align the two plans; neither spec owns them and the second to merge reuses the first's. These shared files name no collectible (the core guards).
9. **The refusals and their sentences (spec 060 decision 23's, extended by one).** Each is a 422 with every entry kept and the page rendered again with `c-field__error`s tied by `aria-describedby`: a lot's number that isn't a whole number from 0 to that lot's free copies, "Enter a number from 0 to M." (M the lot's free copies now) under that lot's field; the numbers' sum 0 or over the proxy's count, "Enter a number from 1 to N." (N the proxy's count now) under the lots' fieldset, shown only when no single field is refused; a lot over the cap in the zone, "One lot can hold at most 9,999 copies." under that lot's field; and a lot with a number above 0 that is no longer one of the account's free lots of the card (removed, taken into a zone or another account's), "Those copies changed. Check the numbers and try again." under the fieldset. **That last sentence is new** (spec 060 decision 23 had the first two kinds and "the copies changed meanwhile" folded into the first): a lot that no longer exists has no free count to name. A blank field is 0. A key in the request that isn't an id of digits only is ignored. An id that is another account's or another card's is treated as no longer free, so nothing tells a collector whether a lot of another account exists. This departs from spec 006 AC-8.1, which ignores ids that aren't the account's in a bulk submission: there the ids are ticks, here a number was typed for the lot, so ignoring it would silently move fewer copies than asked. **The form posts what it showed** (decision 10's twin): next to each lot's field a hidden `shown[<lot id>]` holds the lot's quantity as the page drew it, and a lot whose number is above 0 and whose quantity is no longer what was shown, or that is no longer free, is "Those copies changed. Check the numbers and try again." (the same sentence; a lot moved to another free place keeps its copies, its id and its free state, so it is not a change), and so is a lot whose `shown` value is missing or isn't digits (a tampered or old form fails closed), so a second submit of the same form, whose lots now hold fewer copies or are gone, is refused even when the typed number would still fit. A first submit always changes every lot it chose (a split lowers it, a whole move takes it out of the free lots), so no double submit passes (a lot that returns to its shown quantity by another path between the two submits is not a double submit: the move is still exactly what was typed). **A refused page is a fresh page:** it keeps the numbers typed and writes every `shown[<lot id>]` again from the read after the rollback, so correcting the numbers and submitting again succeeds; a page that echoed the posted `shown` values would refuse every resubmit. A changed lot whose typed number also exceeds what is free now shows both sentences (the fieldset's and its field's "Enter a number from 0 to M."). **Precedence:** the changed-lot sentence (under the fieldset) and a lot's own sentence (under its field) are shown together; the sum's sentence only when neither applies. **A lot the move can't save** (a stored finish or condition the vocabulary no longer lists, after a catalog refresh: `Lot` validates both on save) is listed but refused with "Edit this copy first: its finish or condition isn't offered any more." under its field when a number above 0 is entered, judged by the replacement object with the other checks and not read from `Lot::Move`'s failure; it is never moved by skipping validation. When no lot is free the page shows the empty sentence and a link back and no form (spec 060 decision 23).
10. **Add a new copy's refusals.** The form's own sentences are Add a copy's (Quantity "must be a whole number from 1 to 9,999", the cap's "One lot can hold at most 9,999 copies.", a finish or condition the vocabulary doesn't know); this page adds one: a Quantity over the proxy's count, "Enter a number from 1 to N." (N the proxy's count now), on the Quantity field. 422, what was typed kept, nothing written. The form posts the proxy's count as it showed it (a hidden `shown_quantity`); a count that is no longer that is "This proxy changed. Check the quantity and try again." on Quantity (422, the page shows the count now), and the refused form is written again with `shown_quantity` set to that count and the typed values kept, so submitting it again succeeds; two submits of one form never add two copies against a proxy that one of them already lowered. A proxy removed in another tab while the form is open is a 404 on submit and nothing is written. **Precedence:** the form's own sentences first (a Quantity that isn't a whole number from 1 to 9,999 is Add a copy's sentence even when it is above the proxy's count), then "This proxy changed…", then "Enter a number from 1 to N.".
11. **The notices.** Use my copy: "Replaced 2 proxies of Lightning Bolt (MH2 · 138, Foil) in Izzet Tempo › Main with copies you own." ("1 proxy", the finish only when the proxy has one, as spec 068's notices name it). Add a new copy: "Added 2 × Lightning Bolt (MH2 · 138) to Izzet Tempo › Main, replacing 2 proxies." (Add a copy's own sentence plus the clause; "1 proxy"). Both are 303 to the deck page. Every number in a notice and in the pages' sentences is written with a thousands delimiter ("1,000 proxies"), as spec 068's are. *Alternative:* "Moved 2 copies…"; it names what the collector did to the lots and not what happened to the proxy, which is what they came for.
12. **Nothing new in the data (hosted-door and portability rules).** No table, column or migration; no change to the export, the import or the backup: a replacement writes lots and one proxy row, both already in format version 4. An export taken after a replacement carries the moved lots and the lowered or absent proxy as any export does. The upgrade proof needs no new seed. Hosted-door rule 2 holds: no admin page shows any of it.
13. **Both pages work without scripting, and carry no script of their own.** Plain pages and forms, no Stimulus. A sum no field's `max` can follow is the server's check (spec 060 decision 15).
14. **No ADR.** The decisions above sit inside ADR 0028's model; the one reusable fact, what "free" means, is in decision 2 and in the area doc.

## User Stories

### Story 1: The row menu offers the two replacements

**As a** collector
**I want** "Use my copy" and "Add a new copy" on a proxy's row
**So that** I replace a proxy from where I see it.

**Acceptance criteria:**

- [ ] **AC-1.1** Given a deck page with a row that has a proxy When it is read Then the row's menu lists "Use my copy" (a link to `…/proxies/:id/replacement/new`), "Add a new copy" (a link to `…/proxies/:id/copy/new`), "Change proxy count", a separator and "Remove proxy" (danger, last), in that order, as links with no `form`
- [ ] **AC-1.2** Given a row with proxies of two finishes When it is read Then the menu lists "Use my copy for Foil proxy", "Use my copy for Nonfoil proxy", "Add a new copy for Foil proxy", "Add a new copy for Nonfoil proxy", the two Change items, the separator and the two Remove items, the finish named as the vocabulary labels it, and each link goes to its own proxy
- [ ] **AC-1.3** Given a row with no proxy When it is read Then its menu cell is empty and has no trigger, as before
- [ ] **AC-1.4** Given a proxy whose printing's collectible type the instance no longer registers (and a deck of a registered type holding a proxy of another type after a change of format) When its page is read Then the row's menu has Change proxy count and Remove proxy and not the two new items, and the two new pages answer 404 for that proxy (AC-2.9, AC-4.8); a proxy of a registered type in a deck of an unregistered one has the items
- [ ] **AC-1.5** Given the deck page When its statements are counted Then the menu's new items add none: the count is the one spec 068 AC-2.10 allows, whatever the number of rows and proxies

### Story 2: Use my copy lists the free copies of the card

**As a** collector
**I want** to see my free copies of this card, the printing I chose first
**So that** I take the ones I mean.

**Acceptance criteria:**

- [ ] **AC-2.1** Given a proxy and an account with free lots of the card When "Use my copy" is followed Then the page is 200, a detail page with a back link to the deck page, its heading reads "Use my copy of Lightning Bolt", its muted line reads "Replaces 2 proxies in Izzet Tempo › Main · 2X2 · 117, Foil" ("1 proxy"; the printing as `deck_set_line` writes it, `SET · number` with ` · LANG` after it for a language other than English; then ", " and the finish as the vocabulary labels it, only when the proxy has one) and a form lists the lots, each with a number field whose value is 0
- [ ] **AC-2.2** Given free lots of the proxy's printing and finish and of other printings (a retired one, another finish of the same printing, another language) When the page is read Then "This printing" holds the first and "Other printings" holds the rest, a group with no lot is left out together with its label, and within a group the lots are in the order of the card page's "Your copies" (newest printing, finish, condition, price paid, place)
- [ ] **AC-2.3** Given a lot in a place, an unplaced lot, a lot in a zone of this deck, a lot in a zone of another deck, a lot in Considering, another card's lot and another account's lot of the card When the page is read Then only the first two are listed, with "×N free" the lot's quantity, and none of the others
- [ ] **AC-2.4** Given a lot row When it is read Then its label reads the printing (`SET · number`, with ` · LANG` for a language other than English), the finish and the condition (each left out when the lot has none), "paid $1.25" in the account's currency when the lot has a price, the place ("No location" when unplaced) and "×N free", the field is named by that label (a click on the label focuses the field) and its `min` is 0 and its `max` the lot's quantity
- [ ] **AC-2.5** Given the proxy's zone is "Main" of a deck and a free lot of a place with the same name as the zone When the page is read Then the lot's place reads the place's name and the proxy line reads "Deck › Zone", never one for the other
- [ ] **AC-2.6** Given no free lot of the card When the page is opened Then it shows "You have no free copy of Lightning Bolt to use." with "Back to Izzet Tempo" as a secondary button (a link; it needs the 44px floor) and no form
- [ ] **AC-2.7** Given the page When its statements are counted Then the number is the same for 1 lot and for 200 lots, 1 printing and 20, and no row runs a query of its own
- [ ] **AC-2.8** Given another account's deck or proxy, a proxy of another deck under this deck's path, a place's or a zone's id as the deck, or a deck or proxy id that is not digits only When the page is requested Then the answer is 404; a request that isn't signed in is sent to sign in
- [ ] **AC-2.9** Given a proxy whose printing's collectible type the instance no longer registers When the page is requested Then the answer is 404

### Story 3: Use these copies moves them and lowers the proxy

**As a** collector
**I want** the copies I choose to enter the zone and the proxy to shrink
**So that** the deck shows what I own and what I still need.

**Acceptance criteria:**

- [ ] **AC-3.1** Given numbers over several lots that total from 1 to the proxy's count When the form is submitted Then each chosen lot's copies are in the proxy's zone (as `Lot::Move` does: a lot moved whole to a zone that has no lot of its identity is the same row; one moved in part keeps the rest and a new lot holds the moved copies; and a lot that reaches the identity of the zone's own lot merges into it, the zone's lot surviving), the proxy's count is lowered by the total (same id and the same times but `updated_at`), the answer is 303 to the deck page and the notice reads "Replaced 2 proxies of Lightning Bolt (MH2 · 138, Foil) in Izzet Tempo › Main with copies you own."
- [ ] **AC-3.2** Given a total equal to the proxy's count When the form is submitted Then the proxy is gone and, when the copies are of the proxy's printing, the deck page shows its row with Owned and no Proxy; given a total below the count, the row shows both
- [ ] **AC-3.3** Given copies of another printing of the card When they are used Then they enter the zone as a row of their own printing, the proxy's printing keeps a row of Proxy only (or its lowered count), and the deck's Total for the card is unchanged
- [ ] **AC-3.4** Given a lot's copies moved out of a place or no location When the move runs Then the lot's own finish, condition and price paid are kept, the lot key carries the zone's id as `Lot::Move` writes it (the lot is found by `Lot.key_for`), and no lot of any other identity changes
- [ ] **AC-3.5** Given a number that isn't a whole number from 0 to the lot's free copies (text, a fraction, a negative number, over the lot's quantity) When it is submitted Then the answer is 422 with "Enter a number from 0 to M." under that lot's field, every entry kept, and nothing is written
- [ ] **AC-3.6** Given every field 0 or blank, or a total over the proxy's count, and no single field refused When it is submitted Then the answer is 422 with "Enter a number from 1 to N." under the lots' fieldset and nothing is written
- [ ] **AC-3.7** Given a move that would put more than 9,999 copies in one lot of the zone When it is submitted Then the answer is 422 with "One lot can hold at most 9,999 copies." under that lot's field and nothing is written, the earlier lots' moves in the same submission included
- [ ] **AC-3.8** Given a failure in the third of three moves When the form is submitted Then the first two lots, the zone and the proxy are as they were (one transaction)
- [ ] **AC-3.9** Given a lot with a number above 0 that was removed, moved into a zone, or had copies removed or moved out in part since the page was shown (its quantity is not what the form's `shown` field says, or the field is missing or not digits), or that is another account's or another card's When the form is submitted Then the answer is 422, with "Those copies changed. Check the numbers and try again." under the fieldset, the page shows the current free lots built from a fresh read with every `shown` field written again from it and the typed numbers kept (a lot that also exceeds its free copies shows its own "Enter a number from 0 to M." too), and nothing is written; submitting that page again with numbers that fit succeeds; a lot with 0 is ignored whatever it is
- [ ] **AC-3.10** Given the proxy removed or lowered in another tab since the page was shown When the form is submitted Then a removed proxy answers 404 and writes nothing, and a lowered one is judged against its count now (AC-3.6's sentence with the new N)
- [ ] **AC-3.11** Given the same form submitted twice together (two tabs, a double click) When both run Then the copies move once and the second is refused as "Those copies changed…" (a lot of 5, 2 entered, proxy of 4: after the first the lot holds 3, which is not the 5 the form showed), never a double move and never a negative proxy
- [ ] **AC-3.12** Given a proxy replaced When the deck page, the card page's "Your copies", the collection and the Decks page are read Then they agree: the zone holds the copies, the lots' places read "Deck › Zone", no lot of another account or deck changed, and the other proxies of the deck are as they were
- [ ] **AC-3.14** Given a free lot whose stored finish or condition the vocabulary no longer lists When the page is opened and a number above 0 is entered for it Then the lot is listed, the answer is 422 with "Edit this copy first: its finish or condition isn't offered any more." under its field, nothing is written, and a lot with 0 is ignored
- [ ] **AC-3.15** Given an outer failure after the first move (the cap in the second lot) When the page is shown again Then the lots, their free counts and the proxy's count are those of a fresh read after the rollback (the first lot holds what it held), and no sentence names a count the rollback undid
- [ ] **AC-3.13** Given a request that carries an `account_id`, a zone id, a location id or a kind as a parameter When it is handled Then each is ignored: the account is the signed-in one and the zone is the proxy's

### Story 4: Add a new copy opens the form filled in

**As a** collector
**I want** the Add a copy form to know which proxy it replaces
**So that** the copy lands in the zone and the proxy shrinks without a second trip.

**Acceptance criteria:**

- [ ] **AC-4.1** Given a proxy When "Add a new copy" is followed Then the page is 200, a detail page with a back link to the deck page, its heading names the card, the muted line is Use my copy's ("Replaces 2 proxies in Izzet Tempo › Main · MH2 · 138, Foil"), and the form has Quantity (1, `min` 1, `max` the proxy's count), a Finish select with the proxy's finish chosen (no select for a printing that lists none), Condition, Price paid, the zone as read-only text under a "Location" label that is a `c-field__label` paragraph, not a `label` (it labels no control; not a select, not a field of the request; the form's "Add a location" hint is left out), a hidden `shown_quantity` holding the proxy's count, "Add copy" and "Cancel" (to the deck page)
- [ ] **AC-4.2** Given a valid form When it is submitted Then a lot of the proxy's printing and the form's finish, condition and price paid exists in the zone (merged into the zone's lot of that identity when there is one, by `Lot.add!`), the proxy is lowered by the quantity (removed at zero), the answer is 303 to the deck page and the notice reads "Added 2 × Lightning Bolt (MH2 · 138) to Izzet Tempo › Main, replacing 2 proxies." ("1 proxy")
- [ ] **AC-4.3** Given a Quantity over the proxy's count When it is submitted Then the answer is 422 with "Enter a number from 1 to N." on Quantity, what was typed kept, and nothing is written; given a proxy lowered since the form was shown (its count is not the `shown_quantity`) the answer is 422 with "This proxy changed. Check the quantity and try again." and the form shows the count now; given a Quantity that isn't a whole number from 1 to 9,999, a finish or a condition the vocabulary doesn't list, or a price that is not a non-negative amount with at most two places, the answer is 422 with Add a copy's sentence on that field and nothing is written
- [ ] **AC-4.4** Given a merge that would pass 9,999 copies in the zone's lot When it is submitted Then the answer is 422 with "One lot can hold at most 9,999 copies." and neither the lot nor the proxy changed
- [ ] **AC-4.5** Given a Finish other than the proxy's When the form is submitted Then the copy is of that finish and the proxy in the path, whatever its finish, is the one lowered, and no other proxy of the row changes
- [ ] **AC-4.6** Given the proxy removed in another tab or lowered meanwhile When the form is submitted Then the removed one answers 404 and writes nothing, and the lowered one is refused as "This proxy changed…" with the count now, the form written again with `shown_quantity` set to it, and submitting it again succeeds
- [ ] **AC-4.6a** Given the same form submitted twice together (a double click, Quantity 1, proxy of 2) When both run Then one copy is added and the proxy is 1: the second is refused as "This proxy changed…" (or 404 when the first removed the proxy), never two copies
- [ ] **AC-4.7** Given a request that carries an `account_id`, a `location_id`, a zone id or an entry key When it is handled Then each is ignored: the printing and the zone are the proxy's
- [ ] **AC-4.8** Given another account's deck or proxy, a proxy of another deck under this deck's path, a place's or a zone's id as the deck, an id that is not digits only, or a proxy whose printing's collectible type the instance no longer registers When either request is made Then the answer is 404 and nothing is written; a request that isn't signed in is sent to sign in
- [ ] **AC-4.9** Given the card page's own Add a copy form When it is used Then it, and Edit copy which shares its partial, are unchanged: no proxy, no fixed location, a Quantity `max` of 9,999 and a Cancel that returns where it did, and adding a copy there never lowers a proxy

### Story 5: Only these two actions change a proxy this way

**As a** collector
**I want** my proxies to change only when I say so
**So that** nothing replaces a proxy behind my back.

**Acceptance criteria:**

- [ ] **AC-5.1** Given a proxy and a copy of its printing added to, moved into, edited into, bulk-moved into, typed or scanned into its zone by any other path When it happens Then the proxy is unchanged (spec 068 AC-4.2 stands)
- [ ] **AC-5.2** Given a replacement When it runs Then it changes no other proxy, no other deck, no location and no other account's row, and writes no lot but the moved lots and the new one
- [ ] **AC-5.3** Given an export taken after a replacement When it is read Then its `lots` carry the moved or added lots in the zone's place, its `proxies` carry the lowered proxy or none, there is no field the format lacked, and applying that export on a fresh instance gives the same deck page
- [ ] **AC-5.4** Given a catalog refresh after a replacement When it runs Then no lot or proxy changes (spec 068 AC-4.3 stands)

### Story 6: The pages follow the design system, in both themes

**As a** collector on a phone, a tablet or a desktop
**I want** both pages to fit my screen and read in both themes
**So that** I never scroll sideways or mis-tap.

**Acceptance criteria:**

- [ ] **AC-6.1** Given Use my copy and Add a new copy at 360px, 640px and 1280px, in the light and the dark theme, with a deck name and a place name of 60 characters with no space and a card name of 60 characters When they are rendered Then neither has horizontal overflow, the heading and the muted line break inside a word, a label wraps, every field has a visible label or an accessible name, an error is shown with its field and read by its `aria-describedby`, and every colour comes from the design system's tokens
- [ ] **AC-6.2** Given the controls of each page When the plan lists them Then each has the rule that gives it the 44px touch floor on a coarse pointer and the example that reads the rule. Use my copy: the number fields (`.c-pick__lot .c-input`, `min-height: var(--touch-floor)`, additions.css), Use these copies and Cancel and the empty state's "Back to …" button (`c-btn`: `.c-btn { min-height: 44px }` in components.css's coarse-pointer rule, and `.c-decks .c-btn`, which the page's `main` gets by carrying `c-decks`), and the app bar's back link (`c-btn c-btn--ghost c-btn--icon`: the same components.css rule). Add a new copy: Quantity and Price paid (`label.c-input`: components.css's `.c-input { min-height: 44px }`), the Finish and Condition selects (bare `select` in `div.c-field`: `.c-decks .c-field select`, spec 068's rule, which needs `c-decks` on `main`), Add copy and Cancel (`c-btn`) and the back link. Both pages' `main` is `c-main c-page c-decks`; that also gives their headings `.c-decks .c-pagehead__title`'s wrap. Headless Firefox has a fine pointer, so the examples read the rules (the media rule, its selectors, the resolved `--touch-floor`) and measure what is drawn, which is a lower bound (the lesson of 2026-11-11)
- [ ] **AC-6.3** Given a lot row's field or any field When it has keyboard focus Then it shows the 2px `focus` ring (the `c-input` wrapper's for a number field, the select's own)
- [ ] **AC-6.4** Given the design system When it is read Then `UseMyCopy.md` is updated (the built route, `c-decks` on `main`, the price in the label, the finish written as the vocabulary labels it, the new sentences, the empty state's button, the order of the lots, "built as drawn"), `AddProxy.md` has an "Add a new copy" section (the page, the read-only Location, the Quantity's `max`, its sentences), `DeckPage.md` has the menu's items (lines 5, 82 and 83 say #257's items are still to come) a preview of the Add a new copy page exists in a wide and a phone width in both themes (and the previews of `UseMyCopy` are brought in line with the doc), and the README's Components line is current
- [ ] **AC-6.5** Given the new CSS, if any When it is read Then it is in `collector/additions.css` under its own heading comment and uses token variables and `c-*` classes only; the two pages' markup adds a class only where `UseMyCopy.md` and the form's partial need one

### Story 7: The code follows the project's rules

**As an** agent or the maintainer
**I want** the parts to be where the guards and the other issues expect them
**So that** the second spec to merge reuses the first's.

**Acceptance criteria:**

- [ ] **AC-7.1** Given `spec/deck_core_spec.rb` When it reads the deck files this spec adds (the two controllers, the replacement object, the new views and the changes to `lots/_form.html.erb` and the menu partial) Then none names a game, a source, a format or a zone key but `considering`, comments included, its list names every new file the globs don't match, and its count is the present count plus those files
- [ ] **AC-7.2** Given the shared parts of decision 8 When they are read Then each has a comment that says what a caller gets, whether it needs `Current.account`, that it is one transaction, that it re-checks free under the lock, and that "free" is in no deck zone (`.claude/rules/code-documentation.md`), and `bin/ci checks` passes the comment ratchet
- [ ] **AC-7.3** Given the existing examples this spec's change breaks When the plan lists them Then the list is made from a grep (decision in `verification.md`): `spec/requests/deck_pages_spec.rb`'s menu examples (lines near 135 to 160: the one-finish and the two-finish item lists) and any example that reads a row menu's items; and the comments that say only the old writers change a proxy (`app/models/deck/proxy.rb`'s header, `spec/models/lot_proxy_isolation_spec.rb`'s header)
- [ ] **AC-7.4** Given the area docs When they are read Then `collection-and-lots.md` (the proxy table: two actions; the invariant "A proxy is never owned and changes only by hand"; the glossary's "Free"; the deck row menu), `tenancy-and-accounts.md` (the new routes' 404 rule) `CLAUDE.md`'s deck sentence, `docs/roadmap.md`'s #257 line and `docs/design-system/components/DeckPage.md` are updated in the same PR, with the source of each statement

## Functional Requirements

### FR-1: Use my copy

**Must:** list only the signed-in account's free lots of the card; take the lot, the number and the proxy from the request only as values checked against the account's rows; move through `Lot::Move` in one transaction with the proxy's change; judge each lot and the proxy again under the write lock; show every refusal on the page with the entries kept.
**Must not:** list or move a lot in a zone; move a lot of another account or another card; leave a proxy with a quantity below 1; accept a zone, an account or a location from the request.

### FR-2: Add a new copy

**Must:** build the form from `lots/_form` for the proxy's printing; fix the zone to the proxy's; add the lot with `Lot.add!` in one transaction with the proxy's change; keep the card page's form unchanged.
**Must not:** offer a location select; take an entry, a zone or an account from the request; change a lot but the added or merged one.

### FR-3: The shared parts

**Must:** one definition of "free" and one move of chosen copies into a zone, each the single home the other issues reuse; no collectible named.
**Must not:** decide which lots a count takes (#255's); be a second mover beside `Lot::Move`.

## Non-Functional Requirements

### Performance

- Use my copy's page runs a number of statements that does not grow with lots, printings or places (AC-2.7), and the deck page's statements are unchanged (AC-1.5). The submit's statements grow with the lots moved, which the collector chose one by one.

### Security

- Every read and write goes through `Current.account`: the deck by its location id, the proxy by its id within the deck's zones, the lots by the account's free lots of the card. Another account's anything is 404 (the pages' routes) or no longer free (a lot in the form); no parameter names an account, a zone or a location; no `permit!`; every value that reaches SQL is bound; output is escaped. The signed-out visitor is sent to sign in. No admin page shows a replacement.

### Reliability and the hosted door

- All or nothing, under SQLite's one write lock, with the proxy and each lot judged again inside it (AC-3.8, AC-3.11). No new table, column or recurring cost; hosted-door rule 2 holds (decision 12).

### Accessibility

- Every number field is named by its row's text; an error is tied to its field or fieldset; the menu's items name their finish when a row has two; every control meets the touch floor (AC-6.2).

### Design system and documentation

- Token variables and `c-*` classes only; documents and previews as AC-6.4; the area docs and `CLAUDE.md` in the same PR (AC-7.4; `.claude/rules/documentation.md`).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Another account's deck or proxy, a place's or a zone's id as the deck, a proxy of another deck, an id with letters | 404 (AC-2.8, AC-4.8) |
| Signed out | Sent to sign in |
| A proxy whose printing's collectible type the instance no longer registers | The two pages are 404; the menu leaves the items out; Change and Remove still work |
| A number that isn't a whole number from 0 to the lot's free copies | 422, "Enter a number from 0 to M." under that lot's field |
| A total of 0 or over the proxy's count | 422, "Enter a number from 1 to N." under the lots' fieldset |
| A lot over the 9,999 cap in the zone, on either page | 422, "One lot can hold at most 9,999 copies."; nothing changed |
| A lot removed, taken into a zone, or with a different quantity since the page was shown (a second submit included) | 422, "Those copies changed. Check the numbers and try again."; nothing changed |
| A free lot whose finish or condition the vocabulary no longer lists, chosen | 422, "Edit this copy first: its finish or condition isn't offered any more."; nothing changed |
| Add a new copy submitted twice, or the proxy lowered meanwhile | 422, "This proxy changed. Check the quantity and try again." (404 when the proxy is gone) |
| A lot or proxy id of another account in the request | A lot: counted as no longer free; a proxy in the path: 404 |
| The proxy removed in another tab, then either form submitted | 404; nothing written |
| Two submissions of one form together | The first replaces; the second is refused as changed (or 404 when the proxy is gone), never a double move |
| Add a new copy with a Quantity over the proxy's count | 422, "Enter a number from 1 to N." on Quantity |
| A proxy whose printing's finishes changed after it was made | The page works with the finishes it lists now; a proxy with no finish on a printing that lists some shows the Finish select with nothing chosen |
| A catalog refresh retires the proxy's printing after the proxy was made | Both pages still open (the printing is shown, as a retired proxy's row is); the copy is added or moved as asked |

## Open Questions

None blocking. My calls the coordinator may redirect: decision 4 (the price in the lot's label), decision 5's Quantity starting at 1 and the finish staying editable, and decision 11's notices.

## Out of Scope (Future Considerations)

- "Add to deck" from a card page, which chooses a deck, a zone and how many ([#255](https://github.com/plainprogrammer/Collector/issues/255)); "Free to use" and "In decks" ([#50](https://github.com/plainprogrammer/Collector/issues/50)); the shape panel ([#256](https://github.com/plainprogrammer/Collector/issues/256)).
- A "Use my copy" that offers copies in other decks' zones or this deck's other zones, with a warning.
- Replacing many proxies at once, or a proxy with a proxy.

## Supersedes and updates

Written from `git grep -n -i "use my copy\|add a new copy\|UseMyCopy\|#257\|writers\|only by hand\|changes a proxy\|Change proxy count\|Remove proxy" -- spec docs CLAUDE.md app` and the criteria of specs 060 and 068 that name the menu; the plan's step lists the examples hit, by file and line.

- **Supersedes** spec 068 decision 5 ("proxy items only"; "Use my copy" and "Add a new copy" are #257's) and its AC-2.6 (the menu's items), in part AC-2.7 ("no 'Use my copy', 'Add a new copy'": the two are now offered; still no `form` and no "Move copies"), FR-2's "Must not … offer an item other than the proxy items" (the two are proxy items), its Non-Goals' first bullet and Out of Scope's first bullet, and the "Supersedes and updates" line that waits for #257. **Supersedes in part** spec 068 decision 11 and AC-4.2 (and the area doc's invariant "A proxy is never owned and changes only by hand", whose "No way of adding … or moving an owned copy … changes a proxy" holds for every path but these two pages, which add or move a copy and lower the proxy in the same write). Spec 068's Goal "A proxy is never owned" is unchanged: a proxy never becomes a lot by itself.
- **Records a departure** from spec 006 AC-8.1's "ids that aren't the account's are ignored" for lot ids in this form (decision 9).
- **Builds** spec 060 decision 15 (`UseMyCopy`, ruled B), decision 17 and AC-3.10 (the menu's first two items), AC-6.1 to AC-6.4 (the page's rules) and decision 23's sentences, which it extends by one ("Those copies changed…") and by the price in the lot's label (decision 4); spec 060's own text is not edited.
- **Uses** spec 057's "Free to use" (decision 2) and spec 068 decisions 6 and 13 (the proxy by its id under its deck).
- Recorded in the specs index in both directions; spec 071's overlap is decision 8.

## Documents and Files Changed

Listed so the plan can name them; the plan decides the code.

- `docs/design-system/components/UseMyCopy.md`, `AddProxy.md`, `DeckPage.md`, the previews `UseMyCopy.html`, `UseMyCopyPhone.html` and a new Add a new copy preview pair, the README's Components line, and `collector/additions.css` only if a page needs a rule.
- `docs/architecture/collection-and-lots.md`, `tenancy-and-accounts.md`, `CLAUDE.md`'s deck sentence, `docs/roadmap.md`'s #257 line, `docs/specs/README.md` (this spec's row and the supersessions), `spec/deck_core_spec.rb` (the new files and the count).
- New: the two controllers (`Decks::Proxies::ReplacementsController`, `Decks::Proxies::CopiesController`) and their routes, the replacement object around `Lot::Move`, the free query and the move object of decision 8, the Use my copy and Add a new copy views, the change to `lots/_form.html.erb` (a fixed place, a Quantity maximum, a Cancel path, the shown count) and to the row menu partial and `proxy_item_label`, which maps every verb but "Change" to "Remove" and needs a branch for the two new items, and their specs (model, request, system).

## Verification

Written at plan time into `verification.md`: each AC with the spec that proves it; request specs for every route and verb and the tenancy 404s; model specs for the free query, the move object and the replacement (including the third-move failure and the race); system specs: both flows in headless Firefox at 360px, 640px and 1280px in both themes with the worst-case names, reading the touch-floor rules (AC-6.2), and the same two flows in their own context under `rack_test` (`driven_by` declared before the sign-in, the driver asserted; the lesson of 2026-11-11) for "works without scripting"; the names of other accounts' records built at run time (the 404 page prints the spec's source); a round-trip example (AC-5.3); an example per criterion that says a thing is absent uses an input that could make it appear (the lesson of 2026-11-11); screenshots of both pages at 360px and 1280px, light and dark, kept with the spec.
