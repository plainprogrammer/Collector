# Feature 064: Change a Deck's Format

**Status:** Approved
**Version:** 0.2.2
**Created:** 2026-11-10
**Last Updated:** 2026-11-10
**Depends on:** [spec 062](../062-create-rename-remove-a-deck/spec.md) (decks, zones, the format seam, the Decks page; merged) and, for the move and the cap, [spec 041](../041-move-many-lots/spec.md) (`Lot::BulkMove`) and [`collection-and-lots.md`](../../architecture/collection-and-lots.md)
**Branch:** `064-change-deck-format`
**Issue:** [#251](https://github.com/plainprogrammer/Collector/issues/251)
**ADR:** none needed: [ADR 0028](../../adr/0028-decks-are-locations-with-zones.md) already records that a change of format moves cards into the one zone the core names, `considering`; this spec adds no table, column, file field or seam

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.2 | 2026-11-10 | AC-1.2: the line under the head names the deck and its current format (AC-1.7 already needs the stored key) |
| 0.2.1 | 2026-11-10 | Gate A: approved by the coordinator under the maintainer's delegation (v0.2.0 as written; both own calls stand: a separate Change format page, `Deck#zones` keeps its order); if the maintainer overrules either, a later version records it |
| 0.2.0 | 2026-11-10 | From review round 1 (no blocking, six major): `Deck#zones` keeps its order (decision 4 dropped, AC-1.6 dropped; the area doc's open note is extended); the statement-count clause is a timing bar; an empty dropped zone (AC-2.1a); kept zones take their names from the registration (AC-1.5); the real concurrent writers named; AC-1.3 and AC-2.9 corrected; smaller fixes |
| 0.1.0 | 2026-11-10 | First draft |

## Problem Statement

A deck keeps the format it was created with: spec 062 let a collector create, rename and remove a deck and left the format fixed in the app (an import can change it). Decks change format in real life, a Modern deck becomes a Commander deck, and a collector who made a mistake choosing the format would have to remove the deck, which needs it empty, and build it again.

This spec lets a collector change a deck's format. The deck's zones become the new format's. Cards in a zone the new format doesn't have are not lost and don't block the change: they move into the deck's Considering zone, which every format has, and the page says how many moved. The change is refused, with nothing changed, only when a move would put more than 9,999 copies in one lot, the all-or-nothing rule every move of copies already follows ([`collection-and-lots.md`](../../architecture/collection-and-lots.md), the invariants; [decks and locations issue design](../../superpowers/specs/2026-11-09-decks-and-locations-issues-design.md), decision 3).

> **Terms.** *Deck, zone, zone key, format, format registration, Considering, label, lot, identity, merge, cap, holdings* are as in [`collection-and-lots.md`](../../architecture/collection-and-lots.md) and [spec 062](../062-create-rename-remove-a-deck/spec.md). A *dropped zone* is a zone row of the deck whose key the new format doesn't have; a *kept zone* is one whose key the new format has; an *added zone* is a zone of the new format the deck has no row for. *Cards* are copies, as on the Decks page.

## Goals

- A collector changes a deck's format from the Decks page, with a page that works without scripting.
- After the change the deck's zones are the new format's zones: kept zones stay (with their lots), added zones are created, dropped zones are removed.
- Every lot in a dropped zone moves into the deck's Considering zone, merging with the lot of its identity already there, and the page says how many cards moved.
- The change is refused, changing nothing, only when a merge would pass 9,999 copies in one lot.
- Considering is the same zone before and after, whatever the formats.

## Non-Goals

- Proxies: they don't exist yet ([#254](https://github.com/plainprogrammer/Collector/issues/254)), so nothing here reads or moves one; the proxy issue adds them to the move.
- "Free to use" counting Considering as in the deck ([#50](https://github.com/plainprogrammer/Collector/issues/50)) and leaving Considering out of the deck shape panel ([#256](https://github.com/plainprogrammer/Collector/issues/256), [#253](https://github.com/plainprogrammer/Collector/issues/253)): neither exists yet; this spec records the rule for them (Out of Scope).
- An import that changes a deck's format: it applies the file as the truth and moves no card into Considering ([spec 062](../062-create-rename-remove-a-deck/spec.md) AC-8.2; issue #251's comment). This spec changes nothing about the import.
- Moving cards back out of Considering when the format changes again, or an Undo of a change: a second change of format moves what it moves, and the collector moves cards out of Considering by hand once #252 offers zones.
- Changing a deck's collectible type apart from its format, formats the collector defines, and warnings or previews of what would move before the collector saves (the page says what happens in a hint; the notice says what happened).
- Deck-size, copy-limit or legality checks for the new format.
- Any change to the export format or its version (a deck already carries its format and a lot its zone).

## Users and Context

**Primary users:** a signed-in collector who keeps decks.
**Secondary users:** an operator, who sees no deck, format or count (hosted-door rule 2).
**Usage context:** a collector changes a deck's format occasionally, when a deck moves from one format to another or when the format chosen at creation was wrong. Most changes among the constructed formats (Casual, Standard, Pioneer, Modern, Legacy, Vintage, Pauper) change no zone and move nothing; a change to or from Commander drops Sideboard or Commander and moves cards.
**User mental model:** "change the deck's format". Cards that don't fit the new format's sections go to "Considering", where cards under consideration wait.

## Decisions

Decisions 1 and 7 are this spec's own calls, flagged for the review; the rest follow the issue and the issue design.

1. **A page of its own, beside Rename and Remove.** Each row of the Decks page gains a "Change format" ghost button, to `/decks/:id/format/edit`, a page with the Format select; `PATCH /decks/:id/format` changes it. A sibling of the Rename page, so a rename stays one field, and a nested singular resource (`resource :format` under decks) like Remove's. The deck id is the deck's location id as on every deck URL (spec 062 decision 4). *(Own call: the alternative, a Format field on the Rename page, makes "Rename deck" do two things and gives one form two kinds of refusal.)*
2. **The zones follow from the deck's rows, not from its old format.** The new format's zones decide which of the deck's zone rows are kept (by key), which are dropped and which are added. A deck whose old format the instance no longer registers can therefore change format too.
3. **Dropped zones' lots go to Considering.** Every lot in a dropped zone moves into the deck's zone with the key `considering` (the one zone key the core names), merging by the lot identity rules: a lot that meets the identity of a lot already in Considering joins it (the one already there survives); lots of one identity from several dropped zones become one. The move keeps the rules of `Lot::BulkMove`: all or nothing at the cap, every lot key rebuilt with the place, no lot or copy created or lost. When the dropped zones hold no lot nothing is moved and the zones go.
4. **Same format is not a change.** Choosing the format the deck already has, judged on the format read inside the change's write transaction, writes nothing and says so.
5. **The notice counts cards.** "Changed “Izzet Tempo” to Commander. 12 cards moved to Considering." counts copies, merged ones included, as the Decks page counts cards; with none moved the second sentence is left out.
6. **Refusal at the cap names the lot.** As bulk Move to… does: "Nothing changed. <name> (<SET> · <number>) would have more than 9,999 copies in one lot.", on the Format page with 422, naming the first such lot among the moved lots in the collection table's default order (`CollectionTable::Sort`).
7. **No new data.** The change updates the deck's `decks` row and adds and removes zone rows; no table, column, export field or version changes, so the export format document does not change (north star "Export covers it": nothing new is collector-owned). *(Own call; checked against the Coverage tables in the plan.)*

## User Stories

### Story 1: Change a deck's format

**As a** collector
**I want** to change the format of a deck
**So that** its zones match the format it is now

**Acceptance criteria:**

- [ ] **AC-1.1** Given a collector with decks When they open the Decks page Then each row has a "Change format" ghost button that names the deck for a screen reader (`Change format<span class="c-sr"> Izzet Tempo</span>`) beside Rename and Remove, linking to `/decks/:id/format/edit`, and the row's buttons never widen the page: at 360px they wrap onto lines of their own, so the row grows taller, with no horizontal overflow at 360px and 1280px (the `additions.css` rule is recorded in `DecksIndex.md`)
- [ ] **AC-1.2** Given a deck When the collector opens `/decks/:id/format/edit` Then the page, titled "Change format of <name> · Collector" and under the Decks section with a detail header, shows the head "Change format" with the deck's name and current format under it ("Izzet Tempo · Modern"), a Format select of every format the registered collectibles give (the options and grouping of the New deck page) with the deck's current format selected, the hint "Cards in zones the new format doesn't have move to Considering.", a primary "Save" and a "Cancel" link back to the Decks page; it works without scripting
- [ ] **AC-1.3** Given a deck When the collector chooses another registered format and saves Then the deck's collectible type and format are the chosen pair's, its name and location id are unchanged, every lot that is not merged keeps its id, the response is 303 to the Decks page with the notice of decision 5, and the Decks page shows the new format
- [ ] **AC-1.4** Given a change between formats with the same zones (Modern to Pauper) When it is saved Then no zone row is added, removed or renamed, no lot changes, and the notice reads "Changed “<name>” to <Format>." with no sentence about cards
- [ ] **AC-1.5** Given a Commander deck When it is changed to Modern Then the deck has the zones Main, Sideboard and Considering: Main and Considering are the rows it had (same ids and keys), Sideboard is created with the registration's key and name, and the Commander zone is removed; and Modern to Commander does the reverse (Sideboard removed, Commander created). Every zone of the deck then has the name the registration gives its key (a kept zone whose stored name a release has since changed is rewritten, as spec 062 AC-8.2a does for an import), and the change never ends in a unique-index error
- [ ] **AC-1.6** Given a deck When the collector saves the format it already has Then the response is 303 to the Decks page with "“<name>” is already <Format>.", nothing is written (no zone, deck or lot row changes, and no `updated_at` moves), and no card is moved
- [ ] **AC-1.7** Given a deck whose format or collectible type the instance no longer registers When its Format page is opened Then it opens, the page head's line under the name shows the deck's stored format key (so a collector who saves the default does not change it unseen), the select starts on the default format, and saving a registered format works as for any deck, dropping the zones the new format lacks and moving their lots into Considering
- [ ] **AC-1.8** Given a deck whose format was changed When the account is exported Then its entry in `decks` carries the new `format`, its lots' `location` is `{ "deck", "zone" }` with the new zone keys (a moved lot's zone is `considering`), and applying that file on the same instance is "nothing to change"

### Story 2: Cards in dropped zones move to Considering

**As a** collector
**I want** the cards in a zone the new format doesn't have to go to Considering
**So that** nothing is lost and the change isn't blocked

**Acceptance criteria:**

- [ ] **AC-2.1** Given a Commander deck with 3 copies in 2 lots in Commander, lots in Main and a lot in Considering When it is changed to Modern Then the two lots of Commander are in Considering, the lots in Main and the lot already in Considering are where they were, the Commander zone is gone, and the notice reads "Changed “<name>” to Modern. 3 cards moved to Considering." ("1 card" for one)
- [ ] **AC-2.1a** Given a deck whose dropped zones hold no lot (an empty Commander zone) When it is changed to Modern Then the zone is removed, no lot changes, and the notice reads "Changed “<name>” to Modern."
- [ ] **AC-2.2** Given a lot in a dropped zone with the identity of a lot already in Considering (same printing, finish, condition and price paid) When the format is changed Then they are one lot with the summed quantity, the lot that was in Considering survives (same id), and the moved lot is gone; with no such lot the moved lot is the same lot (same id) in Considering
- [ ] **AC-2.3** Given a format change that drops two zones, each holding a lot of one identity (a test registration made through the specs' `fake_vocabulary` helper; no shipped format does this) When it is changed Then Considering holds one lot of that identity with the sum of the two
- [ ] **AC-2.4** Given a moved lot When its key is read Then it is `Lot.key_for` of its finish, condition, price paid and the Considering zone's id, and an export of the account lists it in the zone `considering` (the lot identity's sixth value is the zone)
- [ ] **AC-2.5** Given the notice's count When lots merge into lots already in Considering Then the count is the copies that moved out of dropped zones, including those that merged, and not the copies already in Considering
- [ ] **AC-2.6** Given a change that would make a lot in Considering hold more than 9,999 copies (the moved copies and the copies there, or the moved copies of one identity together) When it is saved Then the response is 422, the Format page is shown again with the chosen format kept, the sentence of decision 6 is shown as the page's alert, and nothing changed: the deck's format, every zone row and every lot, quantity and key are as before
- [ ] **AC-2.7** Given a change that moves cards When it has run Then the deck holds as many copies as before it (no copy created or lost), and no lot of another deck, a place or the unplaced lots changes
- [ ] **AC-2.8** Given a failure part way through the change (a statement that raises) When it has run Then the deck's format, its zone rows and every lot are as before it, and the error is not swallowed as a refusal
- [ ] **AC-2.9** Given a lot removed in bulk from a dropped zone earlier in the session, whose Undo is still offered, When the format is changed and the collector then presses Undo Then the lot comes back without a location and the notice says so ("<n> lots came back without a location.", the Undo's own wording), as the Undo does for any lot whose place went (spec 006 AC-7.4, spec 032 AC-7.5)
- [ ] **AC-2.10** Given Considering When any format change has run Then the deck's Considering zone is the same row as before (same id and name), with the lots it held, so a lot there is never moved or recreated by a change that keeps it; a deck that has no Considering row gets one, from the registration, before the move

### Story 3: Refusals and isolation

**As a** collector, and as an operator of a shared instance
**I want** a change to be refused in the cases it can't be made and one account's decks to stay its own
**So that** a request never writes the wrong thing or someone else's data

**Acceptance criteria:**

- [ ] **AC-3.1** Given a Format value that is not a `<collectible_type>/<format key>` pair the extension registers (blank, no slash, an unknown type, a key of another type) When the collector saves Then the response is 422, the Format page is shown again, "Choose a format." is on the Format field, and nothing is written; a request without the `deck` parameter is 400
- [ ] **AC-3.2** Given a request with `account_id`, `kind`, `parent_id`, `zone`, `collectible_type`, a `name` or a `location_id` among its parameters When it is saved Then they are ignored: the collectible type is the checked pair's, the name is unchanged and the account is the signed-in one
- [ ] **AC-3.3** Given another account's deck, or the location id of a place or of a zone When `/decks/:id/format/edit` is opened or `PATCH /decks/:id/format` is sent Then each answers 404 and changes nothing; and the deck's own id works only through its location id
- [ ] **AC-3.4** Given a deck removed in another tab When its Format page is opened or saved Then it answers 404
- [ ] **AC-3.5** Given a signed-out visitor When they request the Format page or send the change Then they are sent to sign in
- [ ] **AC-3.6** Given two accounts When one changes a deck's format Then no row of the other account changes and nothing of either appears in the other's pages, export or preview
- [ ] **AC-3.7** Given the operator's pages (admin users, catalog, jobs) When an account has changed a deck's format Then they show no deck, format, zone or count (hosted-door rule 2)

## Functional Requirements

### FR-1: The change

One transaction changes a deck's format: it reads the deck's zone rows and the lots in the dropped zones under the write lock, moves the lots into Considering (decision 3), removes the dropped zone rows, creates the added zone rows and updates the deck's collectible type and format. A zone is removed only after the lots in it have moved; the lots' foreign key refuses to remove one that still holds a lot.

**Must:**
- Follow the zone rules of decision 2.
- Judge the cap on the lots read in the transaction, so a form submitted twice or a lot added in another tab cannot pass a check that no longer holds (the pattern of `Lot::Move`, `Lot::BulkMove`).
- Rebuild each moved lot's key with the place (`Lot.key_for`, ADR 0025): a lot in a zone is keyed by the zone's id and no sixth key builder is written.
- Take the key and name of every added zone, and the name of every kept zone, from the registration, in an order that cannot meet the unique index on (deck, name key); where it writes with a bulk statement it skips the model's validations on purpose, as `Deck::Creation` does, and the `decks` row is updated before any check against the deck's current format.
- Write in batches, as bulk Move to… does (the batched delete and move, plus one statement for each lot a move merges into), and stay inside the performance bar below.
- Read the deck's format, its zone rows and the lots in the dropped zones inside the write transaction, so the "same format" check (decision 4) and the cap are judged on what holds when the write runs.
- Leave the deck's name, its location id, its `decks` row id and every other account's data as they are.

**Must not:**
- Re-check the old format or the old zone keys (decision 2), or refuse a deck for holding cards.
- Name a collectible, a format or a zone key other than `considering` in a core file: `spec/deck_core_spec.rb` lists the deck files, and the new files are among them.
- Move a lot that is in a kept zone, or a lot of any other location.

### FR-2: The Format page and the Decks page

**Must:**
- Use the design system's classes and tokens only and the words of the Decks section; follow the Rename page's markup (a detail header, a page head, a `c-form`) and the New deck page's Format field and options.
- Work without scripting; answer 422 on a refused form with the chosen format kept and 303 (`:see_other`) after a success.
- Show a refusal for the cap as the page's alert, as the bulk move page does.
- Add one ghost button to each Decks row without widening a 360px page.

**Must not:**
- Hard-code a colour, spacing or font.

## Non-Functional Requirements

### Performance

- The Format page costs a bounded number of queries whatever the number of decks, zones or lots.
- A change that moves 5,000 lots (many merging into lots already in Considering) takes under 2 seconds of server time, the bar of spec 041 AC-4.4; measured by a timing example that never gates the suite, recorded in `verification.md`.
- Cost per account (hosted-door rule 4): no row is added beyond a zone row or two and none outlives the change (a zone row is about 100 bytes); no job, cache entry or file.

### Security

- Every lookup goes through `Current.account` and the deck's location id (AC-3.3); the form takes the format alone (AC-3.2).
- No stored name is rendered unescaped; the page uses the escaped helpers.
- The operator sees no deck (AC-3.7).

### Reliability

- The change is all or nothing (AC-2.6, AC-2.8). Other writes are serialised with the change by the write lock. No page places a lot in a zone today (the pickers list places), so the writers that can meet it are: an import's apply, which answers that the preview is stale when the collection changed; a bulk removal's Undo, which restores a lot whose zone is gone without a location (AC-2.9); and an edit of a lot the change moved or merged away, which answers 404 when the lot is gone. An edit form loaded before the change and saved after it can rewrite a moved lot's key with its old place, a race `Lot::BulkMove` already has and this spec leaves as it is.
- A deck whose registration the instance lost can still be renamed, removed and changed to a registered format.
- A catalog refresh never changes a deck, a zone or a lot.
- Every page works without scripting.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A move would pass 9,999 copies in one lot | 422, the Format page with the chosen format kept, "Nothing changed. <name> (<SET> · <number>) would have more than 9,999 copies in one lot."; the deck, zones and lots unchanged |
| A blank or unregistered format value | 422, "Choose a format." on the Format field; nothing written |
| A request with no `deck` parameter | 400 |
| Another account's deck, a place's or a zone's location id | 404 |
| A deck removed in another tab | 404 |
| The format the deck already has | 303 to the Decks page, "“<name>” is already <Format>."; nothing written |
| A deck whose old format is no longer registered | The page opens with the default format selected; a registered format changes it as for any deck |
| A deck with no Considering row | The row is created from the registration before the move (AC-2.10) |
| An unexpected error while writing | Everything rolls back (AC-2.8); not shown as a refusal |
| An import's apply, an Undo or an edit that meets the change | Serialised by the write lock (Reliability): a stale preview, a lot restored without a location, or a 404 for a lot merged away |

## Open Questions

- The plan decides whether the move calls `Lot::BulkMove` with the Considering zone as its destination (its comment says a place or none, and its writes skip validations, so the caller must pass a zone of the deck's own account) or shares its merge code another way (the plan changes that comment's "never a deck or a zone" if it reuses it; the move is skipped when no lot is in a dropped zone, since `Lot::BulkMove` raises for an empty selection); either keeps FR-1's "no sixth key builder".
- The plan decides whether the zone rewrite reuses the import's `CollectionImport::DeckChanges` zone repair (which does the same for a whole account) or writes one deck's zones itself.

## Out of Scope (Future Considerations)

- **Proxies** move into Considering with lots when they exist: [#254](https://github.com/plainprogrammer/Collector/issues/254) extends this change, and its spec says how.
- **Free to use:** copies in Considering are in the deck, so they are not free to use ([#50](https://github.com/plainprogrammer/Collector/issues/50)); this is the rule the card page's "Free to use" must follow, recorded in the issue design (decision 3) and, with this spec, in the area doc's Decks section.
- **The deck shape panel** leaves Considering out ([#256](https://github.com/plainprogrammer/Collector/issues/256)); recorded likewise.
- Removing a deck stays refused while Considering holds a lot, as for any zone (spec 062 decision 7): no change here.
- Zones in the pickers and the collection filter, the deck page and its zone tables ([#252](https://github.com/plainprogrammer/Collector/issues/252), [#253](https://github.com/plainprogrammer/Collector/issues/253)).
- A preview of what would move, an Undo, and a count of lots as well as cards.

## Supersedes and updates

- **Supersedes** [spec 062](../062-create-rename-remove-a-deck/spec.md) Non-Goal "Changing a deck's format and moving its lots into Considering: #251. In the app a deck keeps the format it was created with (an import can change it, AC-8.2)": in the app a deck's format changes with this spec; the import's rule (AC-8.2) stands. Recorded in the [specs index](../README.md) in both directions.
- **Extends** the area doc's open note that `Deck#zones` is ordered by id, so a zone added later (an import's repair, and now a change of format: Commander to Modern lists Sideboard after Considering) shows last, not in the format's order: it stays for #253, which first lists zones, and this spec does not change `Deck#zones`.
- **Updates** [`collection-and-lots.md`](../../architecture/collection-and-lots.md) (the decks section: the Change format action, the zone rules and the move, and the Considering rules for #50 and #256; the glossary's Format; the invariants' "A deck and its zones are written, renamed and removed as one thing" gains "and changed"; the sources), the design system's [`DecksIndex.md`](../../design-system/components/DecksIndex.md) (the row action and the Change format page's markup) [`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md) (the new route's 404 rule) and [`data-portability.md`](../../architecture/data-portability.md) (its statement that the move into Considering is #251's now points at this spec), in the same pull request.

## Notes for the plan

- **Overlap with #252** (location pickers and the "Deck › Zone" label): keep to the format change; no shared method changes its behaviour (`Deck#zones` keeps its order).
- **Guards that may fail until updated:** `spec/deck_core_spec.rb` (new files listed there, so its file count changes; none may name a format or a zone key but `considering`), `spec/system/design_system_deck_rules_spec.rb` (the header measure), the YARD comment ratchet (new public classes and methods carry comments), `docs/design-system` previews (the app's real page differs from the static preview's row; recorded in `DecksIndex.md`).
- **Specs to write first (test-first):** a model spec for the change (zones kept, dropped and added; the move, merge, cap and rollback), a request spec for the page and the refusals (including tenant isolation), a system spec for the flow without scripting at 360px, and a timing example.
