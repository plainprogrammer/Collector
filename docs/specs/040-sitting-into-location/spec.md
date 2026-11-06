# Feature 040: Scan a Sitting into a Location

**Status:** Approved by the maintainer (2026-11-03) at 0.2.0, after one independent review (`review.md`)
**Version:** 0.2.2
**Created:** 2026-11-03
**Last Updated:** 2026-11-03
**Depends on:** [spec 032](../032-lot-in-a-location/spec.md) (a lot's location is part of its identity; merged), [spec 009](../009-card-scanner-confirm-flow/spec.md) (the scanner's sitting; merged) and [spec 034](../034-location-in-typed-entry/spec.md) (the pattern for naming a place; merged)
**Branch:** `040-sitting-into-location`
**Issue:** [#56](https://github.com/plainprogrammer/Collector/issues/56) (roadmap item 21a, theme D)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.2 | 2026-11-03 | AC-3.2 reworded to the maintainer's ruling on plan item P1: only a sitting with no entries at all and no place is dropped on render. |
| 0.2.1 | 2026-11-03 | Approved by the maintainer; status line only. |
| 0.2.0 | 2026-11-03 | From the first independent review: the empty-sitting and Done states, the migration's SQLite pattern, AC-4.x statuses, citations and supersessions; Enter-in-select dropped. |
| 0.1.0 | 2026-11-03 | Written from issue #56, roadmap ruling 20, specs 009, 032 and 034, and the maintainer's answers of 2026-11-03 (decisions 1, 2 and 6). |

---

## Problem Statement

Spec 032 made a lot's location part of its identity and left the scanner adding unplaced copies (decision 5, AC-7.2), naming #56 to add the choice. Spec 009 deferred sitting-wide defaults (Non-Goals); roadmap ruling 20 reversed that: a sitting sets location, condition and language once, one spec each. A collector who scans a binder card by card must today open every added card to place it. The sitting is the one place a whole run of scanned cards goes in, so it is where "these go into Blue binder" is said once.

**Outcome (issue #56):** a collector chooses a location for a scanner sitting, and every card added in it goes there.

This spec is item 21a only. Condition (#57) and language (#58) are their own specs; this one adds no field for them and leaves the sitting's shape ready for them without building it.

## Goals

- A collector picks one of their locations for the sitting on the scanner page, and each card added afterwards goes into the lot of that printing, finish and no condition or price in that place.
- The choice is changed at any time in the sitting and applies to later adds only.
- A collector with no locations sees the scanner exactly as it is.
- The sitting stays working state: nothing is added to the export.

## Non-Goals

- A condition (#57) or a language (#58) for a sitting, a price, or a quantity other than 1 (spec 009 Non-Goals stand for those).
- Moving the cards already added when the place changes. Move copies (spec 032) and bulk "Move to…" (#48) do that.
- Creating a location from the scanner page. Locations are made at `/locations` (spec 029).
- Any change to capture, detection, art matching or the scanner's JavaScript. The spikes #52–#55 may reshape capture; this spec touches none of it (decision 1).
- Remembering the place across sittings, or a default location (spec 029 decision 4).
- A place for the catalog's quick add or the bulk actions (#48).
- Any change to the export format, its version or the examples (decision 5).

## Users and Context

**Primary users:** a signed-in collector with a binder or box to file, at a desk or on a phone, scanning card by card.
**User mental model:** "I'm doing the blue binder. Everything I scan goes in the blue binder. Now the long box."

## Decisions

### 1. Build on today's scanner; the spikes need not come first (ruled)

**Ruling (maintainer, 2026-11-03).** Roadmap item 21 is ordered after the spikes (#52–#55). #56 is built on the scanner as it is. The control and the add path are server-rendered and independent of capture, so a spike's outcome costs little rework here. The roadmap row for 21a records that it may run before the spikes by this ruling (item 21b and 21c keep the order).

### 2. The place lives on the sitting, and choosing one opens the sitting (ruled)

**Ruling.** `scanner_sittings` gains a nullable `location_id` (foreign key to `locations`, `on delete set null`, indexed). Every add reads the account's sitting and its place on the server, so the add buttons, the page's JavaScript and the add request carry nothing new, and a reload keeps the choice for as long as the sitting is open.

A sitting exists today only once a card is added (spec 009 AC-3.7 hides the panel before). Choosing a place with no sitting open opens one, empty, holding the place. Choosing "No location" on a sitting that holds no cards (none added, or all undone) deletes it again, so the page returns to the state of AC-1.1 (the control alone; for an account with no locations nothing shows, as before any sitting); on a sitting that holds cards it keeps the sitting and clears the place.

Alternative considered: carry the place on each add as spec 034 does for number entry's line. The scanner's add forms are rendered inside server-streamed readings, so the page would need a script to keep them in step, and a reload would forget the choice. Not recommended.

### 3. Where the control is, and what it says

While the account has at least one location, the sitting panel (and, with no sitting open, a panel holding only the control) shows **"Put this sitting in"**, a native select of the account's locations (`Location.ordered`, as the other forms list them) with **"No location"** first, and a "Set" button. Submitting is a Turbo form answered by a Turbo Stream that replaces the panel, so the camera and the reading on screen stay (spec 009 AC-1.3). The panel header names the place while one is set: "This sitting: 3 cards, in Blue binder".

An account with no locations sees no control, no hint and no panel before the first add: the page of spec 009 unchanged (spec 034 decision 2's reason: the hint to `/locations` is on the forms the collector uses for one lot).

### 4. What is added, and what the page says

An add reads the sitting's place and adds through `Lot.add!(…, location:)`, so the copy merges into the lot of the same printing, finish, condition (none), price (none) and location (spec 032 decision 1). The 9,999 cap holds per lot, so per place. With no place set an add is spec 009's, unchanged: it merges into the unplaced lot (spec 032 AC-7.2).

The notice names the place when there is one: "Added 1 × Psychic Frog (MH3 · 47, Foil) in Blue binder to your collection." Each list entry shows "in Blue binder" after its finish, read from the entry's lot as the lot is now (spec 034 decision 3), so an entry whose lot was moved shows where it is and an entry whose lot is gone ("Changed in your collection") names no place. No column is added to an entry.

### 5. The sitting stays working state; nothing in the export changes (ruled)

The sitting and its entries are "Left out" of the export (spec 009 FR-2, [data portability](../../architecture/data-portability.md)), and an import apply that writes a lot already destroys them (spec 028 decision 7). The place's column is working state on a left-out table, so the Coverage tables, the format and its version are unchanged. The copies that were added are lots, which the export already covers with their place (format version 3).

### 6. The place can change mid-sitting; later adds only (ruled)

**Ruling (maintainer, 2026-11-03).** Choosing another place at any time changes where later adds go. Cards already added stay in the lots they went into, and their entries keep working Undo (it removes one copy from that lot, wherever the lot is). The sitting's count, list and Undo are not reset.

### 7. A place that is gone, and a place that is not the collector's

The submitted `location` is looked up through `Current.account.locations`. A value that names no location of the account (removed in another tab, another account's id, not a number) changes nothing, and the panel is redrawn from the stored state with the message "That location isn't one of yours any more. Choose again." A location can't be removed while a lot is in it (spec 032 decision 3) but a location that holds none can be, even while a sitting names it: the foreign key sets the sitting's place to none, and the next add is unplaced. The add's notice (decision 4) and the redrawn panel then say so, because the panel is redrawn after every add, so a stale page corrects itself after at most one card.

## Terms

- **Sitting, entry, reading key:** as in spec 009.
- **Place:** a location or none (spec 032). **Unplaced:** no location.

## User Stories

### Story 1: Choose a place for the sitting
As a collector with a binder to file, I want to say once where the scanned cards go.

- [ ] **AC-1.1** Given an account with locations and no open sitting When the scanner shows Then a "Put this sitting in" select lists "No location" first, selected, then the account's locations in the order of the locations page, and nothing else of a sitting (no card count, no Done).
- [ ] **AC-1.2** Given the select and Blue binder When it is submitted Then a sitting opens holding Blue binder, the panel shows "This sitting: 0 cards, in Blue binder" with the select on Blue binder and, in place of a list, "Cards you scan now go into Blue binder." (a sitting with no entries at all; "Everything added in this sitting was undone." stays for a sitting whose entries are all undone), and the camera and any reading on screen are untouched.
- [ ] **AC-1.3** Given a sitting in Blue binder When a printing is added from a reading Then one copy goes into the lot of that printing and finish in Blue binder (merging into it if it exists), the unplaced lot and any lot in another place are unchanged, and the notice and the list entry say "in Blue binder".
- [ ] **AC-1.4** Given a lot of that printing and finish already in Blue binder When a scan adds it Then the copy joins that lot: one lot, quantity summed.
- [ ] **AC-1.5** Given the sitting's place is "No location" When a card is added Then it joins the unplaced lot only (spec 032 AC-7.2).
- [ ] **AC-1.6** Given a lot in Blue binder holds 9,999 copies When that printing is added again Then it is refused with the existing "full" message and nothing is recorded; the same card in Long box is added (the cap is per lot).
- [ ] **AC-1.7** Given a sitting in Blue binder When the page is reloaded or opened on another device Then Blue binder is still chosen.
- [ ] **AC-1.8** Given a sitting with at least one card When "No location" is chosen Then the sitting stays with its cards and later adds are unplaced; given a sitting holding no cards (none added, or all undone) When "No location" is chosen Then the sitting is deleted and the page returns to AC-1.1's state (spec 009 AC-3.7 still hides the panel for an account with no locations). The emptiness check and the delete run in one write transaction.

### Story 2: Change the place during the sitting
- [ ] **AC-2.1** Given a sitting in Blue binder holding 3 cards When Long box is chosen Then the next add goes into Long box, the first 3 stay in Blue binder, the count and list are unchanged, and the header says "in Long box".
- [ ] **AC-2.2** Given an entry added into Blue binder after the place changed When its Undo is used Then one copy leaves the lot in Blue binder (spec 009 AC-4.1, spec 032 AC-7.6) and the lot goes when none are left.
- [ ] **AC-2.3** Given an entry whose lot was moved to another place or merged since When the list shows Then spec 034 decision 3 and spec 009 AC-3.6 apply: it names the lot's place now, or says "Changed in your collection" and names none.

### Story 3: Nothing changes without locations
- [ ] **AC-3.1** Given an account with no locations When the scanner shows Then it has no select, no hint and no panel before the first add, and adds are unplaced as spec 009 says.
- [ ] **AC-3.2** Given an account whose sitting holds a place When the account's last location is removed (only possible with no lot in it) Then the sitting's place is none, the next add is unplaced and says no place, and the redrawn panel has no select. A sitting with no entries at all (none ever added) and no place is dropped when the scanner next renders, so no panel shows for an account with no locations; a sitting with entries, even all undone, stays and shows "This sitting: 0 cards" with Done and no select (the maintainer's ruling of 2026-11-03 on plan item P1). An import apply that removes only an empty location (`CollectionImport::LocationChanges`, which does not clear working state) clears a sitting's place the same way.
- [ ] **AC-3.3** Given a request with no `location` key When it reaches the place endpoint Then it answers 400 and the place is unchanged; "No location" is sent as a present, empty value.

### Story 4: Bad input keeps the page
- [ ] **AC-4.1** Given a `location` that is another account's, a removed one, or not a number When it is submitted Then it answers 422, nothing changes, the panel shows the sitting as stored, and the message of decision 7 is shown as an alert (another account's id is a form error here, not the 404 of spec 032 decision 6, as in spec 034 decision 5).
- [ ] **AC-4.2** Given a `sitting_id` or `account_id` in the request Then it is ignored and only `Current.account`'s sitting changes.
- [ ] **AC-4.3** Given a replayed reading key When it is added again Then nothing is added and the answer is spec 009 AC-1.5's; an "added" answer names the entry's lot's place, never the sitting's current place.

### Story 5: Ending the sitting
- [ ] **AC-5.1** Given a sitting in Blue binder When Done is confirmed Then the copies stay in Blue binder, the sitting and its place go, and the summary says how many cards were added; the next sitting starts with no place.
- [ ] **AC-5.2** Given the response to Done When the account has locations Then it shows the summary and, with it, the control set to "No location", so the next sitting's place is chosen without a reload; choosing a place while the summary shows replaces it with the new sitting's panel. Spec 009 AC-3.5's wording for a sitting that added nothing ("Added 0 cards in this sitting") is unchanged.
- [ ] **AC-5.3** Given an import apply that writes a lot When it completes Then the sitting and its place are destroyed with it, as spec 028 decision 7 says.

### Story 6: The migration keeps the sitting
- [ ] **AC-6.0** Given a sitting with entries before the migration When it runs up, and then down, Then the sitting and every entry are unchanged and no sitting has a place after up (as spec 032 AC-7.1 proves for lots).

### Story 7: The panel is usable
- [ ] **AC-7.1** The select and button are native controls in a form with a label, reached by keyboard (Tab to "Set", then Enter or Space) and usable by screen reader; no script is added. The panel follows `docs/design-system/`: the existing `c-form`/`c-field` classes, or, if the row needs one, an addition in `collector/additions.css` with its doc under `docs/design-system/components/`.

## Functional Requirements

### FR-1: The place
**Must:** store the place on the account's sitting; read it on every add on the server; resolve a submitted location through `Current.account.locations`; open a sitting when a place is set with none open; delete an empty sitting when its place is cleared; redraw the panel after each add, each Undo and each change (the control renders in all three; the entries' lots and their locations are preloaded in `kept_entries`); read the sitting's place inside the add's transaction, so a concurrent location removal can't leave a lot pointing at a deleted location; open a sitting by place with the same find-or-create as an add, backed by the unique `account_id` index.
**Must not:** list another account's locations; create a location; take a sitting id or an account id from the request; change any lot's other values; set a condition, price or quantity; move cards already added.

### FR-2: Adding
**Must:** add through `Lot.add!` with the sitting's `Location`, in the same transaction that records the entry; keep spec 009 FR-1 and its replay rule.
**Must not:** record an entry when the add fails.

### FR-3: Core code and export
**Must:** keep the sitting's code free of any collectible type beyond what spec 009 already names; leave the sitting and its place out of the export with no new coverage entry (decision 5).

## Non-Functional Requirements

- **Cost per account (hosted-door rule 4):** one nullable integer column on a row an account has at most one of, so no storage that grows with the collection, no background work, and no new instance setting. The locations load once per request for the select, and the entries' lots and their locations load once for the list through a preload (no query per entry).
- **Collector choices (rule 3):** the place is stored per sitting, which belongs to the account; no environment variable.
- **Security:** `location` is read with `params.expect`, resolved through `Current.account.locations`, never trusted as an id of another account; a refused value is an alert, not a 404, because the page is a form. A request spec proves another account's location is refused.
- **Migration:** a schema migration, reversible, adding the column and its index with `on delete set null` the way `db/migrate/20261023100001_add_location_to_lots.rb` documents for SQLite: `disable_ddl_transaction!` and a raw `ALTER TABLE … ADD COLUMN … REFERENCES locations (id) ON DELETE SET NULL` that copies no table (a rebuild would cascade-delete every open sitting's entries), with a guarded `down`. Every existing sitting migrates with no place, so no value changes. It runs unattended from any prior version and is proved by the upgrade check ([spec 031](../031-upgrade-from-previous-release/spec.md)). The sitting table is working state, so no backfill.
- **Design system:** the control uses the existing form and `c-scanner__sitting` classes; the view change follows `docs/design-system/`.

## Error Scenarios

| Situation | Behaviour |
|---|---|
| `location` names another account's or a removed location | Nothing changes; alert with decision 7's message (AC-4.1) |
| Request with no `location` | Place unchanged (AC-3.3) |
| Lot in the place at the 9,999 cap | The existing "full" message; nothing recorded (AC-1.6) |
| Place removed while a sitting names it | The sitting's place becomes none; next add is unplaced (AC-3.2) |
| Lot moved or merged after the add | Spec 034 decision 3 / spec 009 AC-3.6 (AC-2.3) |

## Open Questions

None.

## Out of Scope (Future Considerations)

- Naming the place in an entry's Undo label (spec 034 names it in its Undo label; here the entry line does).
- Condition (#57) and language (#58) for a sitting, which will share the one control surface.
- Moving a sitting's cards to another place after the fact (#48).
- A default or remembered location.

## Supersedes

- [Spec 009](../009-card-scanner-confirm-flow/spec.md) Non-Goals "Sitting-wide defaults" and "Locations, bins or a 'Loose' bucket", for a location only (condition, price and language stay deferred to #57, #58 and after).
- Spec 009 AC-1.3's notice text and AC-3.2's heading gain "in <place>" while a place is set, and spec 009 FR-2's "adding opens a sitting": choosing a place opens one too.
- [Spec 032](../032-lot-in-a-location/spec.md) decision 5 and Story 7 (AC-7.2), for the scanner only: a sitting may carry a place.

Recorded here and in the specs index; neither spec is edited (`.claude/rules/documentation.md`).

## Documents that change

| Document | Change |
|---|---|
| `docs/specs/README.md` | A row for 040; supersession of 009 and 032 recorded both ways in the index |
| `docs/roadmap.md` | Item 21a marked built; the note that it ran before the spikes by ruling (decision 1) |
| `docs/architecture/collection-and-lots.md` | The scope line and "Only some ways of adding choose a place" (the scanner adds into the sitting's place); the open item for #56; that removing an empty location clears a sitting's place |
| `docs/architecture/data-portability.md` | None expected: the sitting stays left out; checked at distillation |
