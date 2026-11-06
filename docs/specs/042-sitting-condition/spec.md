# Feature 042: Set a Condition for a Scanner Sitting

**Status:** Approved by the coordinator under the maintainer's delegation (2026-11-06) at 0.3.1, after three independent reviews (`review.md`)
**Version:** 0.3.1
**Created:** 2026-11-06
**Last Updated:** 2026-11-06
**Depends on:** [spec 040](../040-sitting-into-location/spec.md) (the sitting's place and its control; merged), [spec 009](../009-card-scanner-confirm-flow/spec.md) (the scanner's sitting; merged) and [spec 006](../006-collection-list-view/spec.md) (bulk Set condition, the pattern for choosing a condition; merged)
**Branch:** `042-sitting-condition`
**Issue:** [#57](https://github.com/plainprogrammer/Collector/issues/57) (roadmap item 21b, theme D)
**Frozen:** the current rules are in [`scanner.md`](../../architecture/scanner.md), [`collection-and-lots.md`](../../architecture/collection-and-lots.md) and [`data-portability.md`](../../architecture/data-portability.md) (whole spec; collection and lots: decisions 2, 4 and 5 as they touch lots; data portability: decision 6 and AC-5.3); see the [specs index](../README.md)
**Plan:** retired in `6412b00ea8a6be07aaf3cce6ca410d5044a935dd`; read it with `git show 6412b00ea8a6be07aaf3cce6ca410d5044a935dd^:docs/specs/042-sitting-condition/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.3.1 | 2026-11-06 | From the third review (Fable, READY TO PLAN): the condition check after the replay check; the status line cleared when "Set" finds no sitting; the guard's pattern; the hook keeps its name; the entry line with no finish. |
| 0.3.0 | 2026-11-06 | From the second review (Fable): spec 040 decision 4, Goals and FR-1 superseded for condition; roadmap item 21a amended; the condition check ahead of `Lot.add!`; the short label from the printing's vocabulary; two error rows; the legend "This sitting's cards"; the helper under the core guard. |
| 0.2.0 | 2026-11-06 | From the first independent review (Fable): the copy that names the condition (notice, entry line; not Undo or accessible names), "Nothing added yet." kept, every status-line variant, where the collectible type may be named and a core guard spec, the rollback with a condition (AC-6.2), the stacked layout, and the supersessions of spec 009 FR-1 and spec 040 decision 2, AC-3.2 and AC-5.2. |
| 0.1.0 | 2026-11-06 | Written from issue #57, roadmap ruling 20, specs 009, 040 and 006, and the coordinator's brief. Decisions 1 and 2 ruled by the maintainer the same day. |

---

## Problem Statement

Spec 009 adds every scanned copy with its condition unspecified and deferred sitting-wide defaults (Non-Goals). Roadmap ruling 20 reversed that: a sitting sets location, condition and language once, one spec each. Spec 040 built the location. A collector who scans a binder of near-mint cards must today open every added lot, or select them afterwards and use bulk Set condition, to say what they knew before the first scan.

**Outcome (issue #57):** a collector sets one condition for a scanner sitting, and every card added in it gets that condition.

This spec is item 21b only. Language (#58) is its own spec; this one adds no field for it.

## Goals

- A collector picks a condition from the vocabulary's scale, or "Not specified", for the sitting on the scanner page, and each card added afterwards goes into the lot of that printing, finish, condition, no price, and the sitting's place.
- The condition is set before the first card, and changed at any time; a change applies to later adds only.
- The condition and the place are chosen together in the one control spec 040 put in the sitting panel.
- The sitting stays working state: nothing is added to the export.

## Non-Goals

- A language for a sitting (#58), a price, or a quantity other than 1 (spec 009 Non-Goals stand for the last two).
- Changing the condition of cards already added when the sitting's condition changes. Bulk Set condition (spec 006 Story 6) and "Edit copy" do that.
- Moving focus to, or announcing, the redrawn panel after a change (#182). This spec keeps spec 040's redraw and status line as they are.
- Any change to capture, detection, art matching or the scanner's JavaScript (as spec 040 decision 1).
- Remembering the condition across sittings, or a default condition per account.
- A condition for the catalog's quick add, number entry or the bulk actions.
- Any change to the export format, its version or the examples (decision 6).

## Users and Context

**Primary users:** a signed-in collector working through a stack or binder whose cards share a condition, at a desk or on a phone, scanning card by card.
**User mental model:** "These are all pack-fresh, near mint. The next stack is the played box: lightly played."

## Decisions

### 1. Build on today's scanner; the spikes need not come first (ruled)

Roadmap item 21 is ordered after the spikes (#52–#55), and spec 040 decision 1 let 21a run first. **Ruling (maintainer, 2026-11-06).** 21b runs first for the same reason. The control and the add path are server-rendered and independent of capture, so a spike's outcome costs little rework. The roadmap row for 21b records the ruling.

### 2. One control for the sitting's choices, shown to every collector (ruled)

**Ruling (maintainer, 2026-11-06).** The sitting panel's form from spec 040 decision 3 becomes the sitting's one control. It holds, in order, a **Condition** select ("Not specified" first, then the vocabulary's scale as "Near mint (NM)", the labels of the lot form and bulk Set condition) and, while the account has at least one location, the **Location** select of spec 040 ("No location" first, then `Location.ordered`), and one "Set" button. Spec 040's label "Put this sitting in" becomes the Location select's label "Location", and a `<fieldset>` legend "This sitting's cards" groups both selects (decision 3 gives the rest of the copy).

A condition can be chosen by any collector, so the control shows on the scanner for every signed-in collector, before the first add too. This supersedes spec 009 AC-3.7 (no sitting panel before the first add) for the control only: no count, list or Done shows until a sitting is open. It supersedes spec 040 decision 3 and AC-3.1 (an account with no locations sees no control and no panel before the first add): such an account sees the Condition select alone.

Alternatives considered: two forms, each with its own "Set" (two buttons for one panel and two answers that redraw it); the condition control only once a sitting is open (the first card of every sitting would be unspecified, which defeats the outcome). Not recommended.

### 3. What the page says

- The panel header names the choices while the sitting has any: "This sitting: 3 cards, Near mint, in Blue binder"; "This sitting: 3 cards, Near mint"; "This sitting: 3 cards, in Blue binder" (spec 040's). The condition uses the vocabulary's long label.
- A sitting with no entries at all says, in place of the list, "Cards you scan now: Near mint, in Blue binder.", naming only the parts that are set: "Cards you scan now: Near mint." or "Cards you scan now: in Blue binder." (spec 040 AC-1.2's "Cards you scan now go into Blue binder." becomes the last). With neither set (a redraw the next render drops, spec 040 AC-3.2) it keeps "Nothing added yet.". "Everything added in this sitting was undone." stays for a sitting whose entries are all undone.
- After "Set", the status line names both choices for an account with locations, "Not specified" as "condition not specified" and no place as "no location": "Cards you scan now: Near mint, in Blue binder.", "Cards you scan now: Near mint, no location.", "Cards you scan now: condition not specified, in Blue binder.", "Cards you scan now: condition not specified, no location." For an account with no locations it names the condition only: "Cards you scan now: Near mint." or "Cards you scan now: condition not specified." When "Set" deletes an empty sitting (decision 4), or clears both choices with no sitting open, the status line is cleared, as spec 040 does.
- The add's notice names the condition by its short label after the finish, inside the parentheses: "Added 1 × Psychic Frog (MH3 · 47, Foil, NM) in Blue binder to your collection.", and "(MH3 · 47, NM)" for a printing with no finish (spec 009 AC-1.3 leaves out an unspecified part). Each list entry shows the short label after its finish: "MH3 · 47 · Foil · NM · in Blue binder · Added 2 minutes ago", and "MH3 · 47 · — · NM · Added 2 minutes ago" for an unspecified finish and no place (spec 009 AC-3.2's "—"). Both read the entry's lot as it is now (spec 040 decision 4's rule for the place), so an entry whose lot was edited to another condition shows that condition, and an entry whose lot is gone ("Changed in your collection") names none. No column is added to an entry.
- Nothing else names the condition: the Undo announcement ("Removed 1 × ‹name› (‹SET› · ‹number›, ‹finish›) from your collection.", spec 009 AC-4.1) and the entries' "Details of …" and "Undo …" accessible names stay as they are, as spec 040 left the place out of them.

### 4. The condition lives on the sitting

`scanner_sittings` gains a nullable `condition` string holding a vocabulary key (`near_mint`), as `lots.condition` does. Every add reads the sitting's condition on the server, inside the add's transaction, as it reads the place (spec 040 decision 2, FR-1), so the add buttons, the page's JavaScript and the add request carry nothing new, and a reload keeps the choice while the sitting is open.

Choosing a condition with no sitting open opens one, empty, holding it (as choosing a place does). A "Set" that leaves a sitting with no kept entries, no condition and no place deletes it, so the page returns to the state of AC-1.1 (spec 040 decision 2's "Choosing 'No location' … deletes it again" and AC-1.8, generalised). The render-time drop of spec 040 AC-3.2 drops a sitting with no entries at all, no place and no condition.

Alternative considered: carry the condition on each add request. Rejected for spec 040 decision 2's reasons (the add forms render inside streamed readings; a reload would forget it).

### 5. Which scale, and a condition a printing's collectible doesn't know

The core names no collectible ([collection and lots](../../architecture/collection-and-lots.md), "The core names no collectible"). The scale is the vocabulary (`Catalog.collecting_for(type).conditions`) of the collectible the scanner reads, which is Magic only (spec 007); the scanner's controllers already name that type (`Scanner::PrintingsController` names `MTG::Reading::COLLECTIBLE_TYPE`; `Scanner::ReadingsController` names `MTG::Reading`). The controllers that build the select and check a submitted key (`Scanner::SittingsController`, the `ScannerSitting` concern, `ScannersController`) may name it too. `Scanner::Sitting`, `Scanner::SittingEntry` and the sitting's partials don't: the model is given the vocabulary (or the checked key) by its caller, and at an add reads the printing's own vocabulary as it already does for finishes (`Scanner::Sitting.finish_offered?`).

An add whose printing's vocabulary doesn't know the sitting's condition (unreachable while the scanner reads one collectible) is refused before anything changes, by a check in `Scanner::Sitting.add!` after the replay check (a replayed key answers as spec 009 AC-1.5 says, whatever the sitting now holds) and before `Lot.add!` (a new `Refused` reason; `Lot#condition_known` would raise `RecordInvalid`, which the entries controller reports as the cap), with spec 009's "That card couldn't be added. Scan it again.", and nothing is recorded; it is never reported as the 9,999 cap.

### 6. The sitting stays working state; nothing in the export changes

The sitting and its entries are left out of the export (spec 009 FR-2; spec 040 decision 5; [data portability](../../architecture/data-portability.md)), and an import apply that writes a lot destroys them (spec 028 decision 7). The condition's column is working state on a left-out table, so the Coverage tables, the format and its version are unchanged. The copies that were added are lots, which the export already covers with their condition.

### 7. The condition can change mid-sitting; later adds only

As spec 040 decision 6 rules for the place: choosing another condition changes later adds only. Cards already added stay in the lots they went into, and their Undo works as before. The count, list and Undo are not reset.

### 8. The request

`PATCH /scanner/sitting` takes `sitting[condition]` and `sitting[location_id]`. An absent key keeps that choice; a present, empty value clears it ("Not specified", "No location"); a request with neither key answers 400 and changes nothing (this supersedes spec 040 AC-3.3, under which `location_id` was required). Both values are checked before anything is written: if either is refused (decision 9), nothing changes.

### 9. A refused value

A `condition` that is not a key of the scanner's vocabulary answers 422, changes nothing, redraws the panel from the stored state, and shows "That isn't a known condition. Choose again." as an alert (bulk Set condition's wording, spec 006, with spec 040's "Choose again."). A refused location keeps spec 040 decision 7's message. When both are refused, the condition's message shows.

## Terms

- **Sitting, entry, reading key:** as in spec 009. **Place, unplaced:** as in spec 040.
- **The scanner's vocabulary:** the collecting vocabulary of the collectible the scanner reads (decision 5).
- **The sitting's choices:** its condition and its place.

## User Stories

### Story 1: Choose a condition for the sitting
As a collector with a stack of near-mint cards, I want to say their condition once.

- [ ] **AC-1.1** Given no open sitting When the scanner shows Then the panel holds the control alone: the legend "This sitting's cards", a Condition select with "Not specified" first and selected, then the vocabulary's scale in order ("Near mint (NM)" … "Damaged (DMG)"), the Location select of spec 040 AC-1.1 only when the account has locations, and "Set"; nothing else of a sitting (no count, no list, no Done).
- [ ] **AC-1.2** Given the control When Near mint is chosen and "Set" is used Then a sitting opens holding Near mint, the header says "This sitting: 0 cards, Near mint", the list's place says "Cards you scan now: Near mint." (for any account; the status line of decision 3 adds ", no location." for an account with locations), the select shows Near mint, and the camera and any reading on screen are untouched (spec 009 AC-1.3).
- [ ] **AC-1.3** Given a sitting holding Near mint When a printing is added from a reading Then one copy goes into the lot of that printing, finish and Near mint, unplaced and with no price (merging into it if it exists); a lot of that printing and finish with no condition, or another condition, is unchanged; the notice says "(MH3 · 47, Foil, NM)" and the list entry shows "NM".
- [ ] **AC-1.4** Given a sitting holding Near mint and Blue binder When a printing is added Then the copy goes into the lot of that printing, finish, Near mint and Blue binder, and the notice says "Added 1 × ‹name› (‹SET› · ‹number›, ‹finish›, NM) in Blue binder to your collection."
- [ ] **AC-1.5** Given a sitting with "Not specified" When a card is added Then it joins the lot with no condition (spec 009 AC-1.2), and the notice and the entry name no condition.
- [ ] **AC-1.6** Given the lot of that printing, finish and Near mint holds 9,999 copies When it is added again in a Near mint sitting Then it is refused with the existing "full" message and nothing is recorded; in a sitting with "Not specified" the same card is added (the cap is per lot).
- [ ] **AC-1.7** Given a sitting holding Near mint When the page is reloaded or opened on another device Then Near mint is still chosen.
- [ ] **AC-1.8** Given a sitting holding cards When "Not specified" (and "No location") is set Then the sitting stays with its cards and later adds have no condition; given a sitting holding no kept card When "Set" leaves it with no condition and no place Then the sitting is deleted and the page returns to AC-1.1's state. The emptiness check and the delete run in one write transaction.

### Story 2: Change the condition during the sitting
- [ ] **AC-2.1** Given a sitting holding Near mint with 3 cards When Lightly played is set Then the next add goes into a Lightly played lot, the first 3 stay in their Near mint lots, the count and list are unchanged, and the header says "Lightly played".
- [ ] **AC-2.2** Given an entry added as Near mint When its Undo is used Then one copy leaves that lot (spec 009 AC-4.1), and the lot goes when none are left.
- [ ] **AC-2.3** Given an entry whose lot was edited to Lightly played since the add When the list shows Then the entry shows "LP" (decision 3); given an entry whose lot was merged away Then it says "Changed in your collection" and names no condition (spec 009 AC-3.6).
- [ ] **AC-2.4** Given a sitting in Blue binder holding Near mint When only the condition is changed in the control Then the place stays Blue binder, and when only the place is changed the condition stays (the form sends both; decision 8).

### Story 3: Every collector sees the control
- [ ] **AC-3.1** Given an account with no locations and no open sitting When the scanner shows Then the panel holds the Condition select and "Set", with no Location select and no hint to `/locations` (spec 040 decision 3's reason); adds with "Not specified" are spec 009's, unchanged.
- [ ] **AC-3.2** Given an account with no locations When a condition is set and cards are added Then they go into unplaced lots of that condition, and the header says "This sitting: ‹n› cards, Near mint".
- [ ] **AC-3.3** Given a sitting with no entries at all, no place and no condition When the scanner next renders Then it is dropped (spec 040 AC-3.2), and the page is AC-1.1's; a sitting with a condition and no entries is kept.

### Story 4: Bad input keeps the page
- [ ] **AC-4.1** Given a `condition` that is not a key of the scanner's vocabulary (a label such as "Near mint", another collectible's key, any other text) When it is submitted Then it answers 422, nothing changes (neither the condition nor a location sent with it), the panel shows the sitting as stored, and decision 9's message is shown as an alert.
- [ ] **AC-4.2** Given a request with neither `condition` nor `location_id` Then it answers 400 and nothing changes; given only one of them Then the other choice is kept.
- [ ] **AC-4.3** Given a `sitting_id`, `account_id` or another account's id in the request Then it is ignored and only `Current.account`'s sitting changes.
- [ ] **AC-4.4** Given a replayed reading key When it is added again Then nothing is added and the answer is spec 009 AC-1.5's; an "added" answer names the entry's lot's condition and place, never the sitting's current ones.
- [ ] **AC-4.5** Given a sitting holding a condition that the added printing's vocabulary doesn't know When the add is made Then it is refused with "That card couldn't be added. Scan it again.", nothing is recorded, and the "full" message is not shown (decision 5; proved in a model spec with a second vocabulary).

### Story 5: Ending the sitting
- [ ] **AC-5.1** Given a sitting holding Near mint When Done is confirmed Then the copies keep their lots, the sitting and its condition go, and the next sitting starts with "Not specified".
- [ ] **AC-5.2** Given the response to Done Then it shows spec 009 AC-3.5's summary and, with it, the control set to "Not specified" (and "No location"), for every account; setting a choice while the summary shows replaces it with the new sitting's panel (spec 040 AC-5.2, now for every account).
- [ ] **AC-5.3** Given an import apply that writes a lot When it completes Then the sitting and its condition are destroyed with it (spec 028 decision 7).

### Story 6: The migration keeps the sitting
- [ ] **AC-6.1** Given a sitting with entries and a place before the migration When it runs up, and then down, Then the sitting, its place and every entry are unchanged, and no sitting has a condition after up.
- [ ] **AC-6.2** Given a sitting with entries that holds a condition When the migration runs down Then the condition column goes and the sitting, its place and every entry stay (the condition is working state, so the rollback drops it whatever it holds).

### Story 7: The control is usable
- [ ] **AC-7.1** The selects and the button are native controls in one form, grouped under a `<fieldset>` whose legend is "This sitting's cards", each select with its own label ("Condition", "Location"), reached by keyboard and usable by screen reader; no script is added. The panel follows `docs/design-system/`: the existing `c-form`/`c-field` classes, stacked as spec 040's control is (the form keeps its markup hook `c-scanner__place`, which has no style rule); if the two fields are laid out side by side at any width, that is a new rule in `collector/additions.css` documented in `docs/design-system/components/Scanner.md`. At 390px and at desktop width no control overflows the panel.

## Functional Requirements

### FR-1: The condition
**Must:** store the condition on the account's sitting as a vocabulary key; check a submitted condition against the scanner's vocabulary before writing; write the condition and the place in one transaction, after both are checked; open a sitting when a choice is set with none open, with the same find-or-create as an add; delete a sitting left with no kept entries, no condition and no place; read the sitting's condition and place inside each add's transaction; redraw the panel after each add, Undo and "Set" with the control.
**Must not:** take a sitting id or an account id from the request; change any lot already added; set a price or quantity.

### FR-2: Adding
**Must:** add through `Lot.add!` with the sitting's condition and place, in the transaction that records the entry; refuse before anything is written when the printing's vocabulary doesn't know the condition; keep spec 009 FR-1 and its replay rule.
**Must not:** record an entry when the add fails.

### FR-3: Core code and export
**Must:** keep `Scanner::Sitting`, `Scanner::SittingEntry` and the sitting's partials (`app/views/scanners/_sitting.html.erb`, `_sitting_entry.html.erb`, `_picker.html.erb`, `_summary.html.erb`) and `app/helpers/scanners_helper.rb` free of any collectible type (the scanner's controllers name it, decision 5), guarded by a core spec like `spec/number_entry_core_spec.rb` that fails when one of those files matches `/\b(mtg|scryfall|magic)\b/i` (number entry's pattern without its finish words, because the helper's comments quote copy such as "Foil"); leave the sitting and its condition out of the export with no new coverage entry (decision 6).

## Non-Functional Requirements

- **Cost per account (hosted-door rule 4):** one nullable string column on a row an account has at most one of; no background work, no instance setting, no query per entry: the entry line and the notice take the condition's short label from the vocabulary of the entry's printing (`entry.printing.collectible_type`, already loaded), not from `Lot#vocabulary`, which would load each lot's catalog entry.
- **Collector choices (rule 3):** the condition is stored per sitting, which belongs to the account; no environment variable.
- **Security:** `condition` and `location_id` are read with `params.expect`; the condition is checked against the vocabulary's keys, the location resolved through `Current.account.locations`. Request specs prove a refused condition changes nothing and another account's sitting is never touched.
- **Migration:** a reversible schema migration adding `scanner_sittings.condition` (string, null allowed, no default, no index: no query filters on it). Adding a nullable column is `ALTER TABLE … ADD COLUMN`, which copies no table; the rollback must not copy the table with foreign keys enforced either, because the copy's `DROP TABLE` would cascade-delete every open sitting's entries (spec 040 NFR Migration; `db/migrate/20261105100001_add_location_to_scanner_sittings.rb`), so it follows that migration's pattern: `disable_ddl_transaction!` and guarded steps. Every existing sitting migrates with no condition, so no add changes. It runs unattended from any prior version and is proved by the upgrade check ([spec 031](../031-upgrade-from-previous-release/spec.md)).
- **Design system:** the view change follows `docs/design-system/`.

## Error Scenarios

| Situation | Behaviour |
|---|---|
| `condition` not a key of the scanner's vocabulary | 422, nothing changes, alert "That isn't a known condition. Choose again." (AC-4.1) |
| Request with neither key | 400, nothing changes (AC-4.2) |
| Lot of that identity at the 9,999 cap | The existing "full" message; nothing recorded (AC-1.6) |
| Sitting's condition unknown to the printing's vocabulary | "That card couldn't be added. Scan it again."; nothing recorded (AC-4.5) |
| `location_id` names another account's or a removed location | 422, nothing changes, spec 040 decision 7's alert (decision 9) |
| Both values refused | 422, nothing changes, the condition's alert (decision 9) |
| Lot edited or merged after the add | The entry shows the lot's condition now, or "Changed in your collection" (AC-2.3) |

## Open Questions

None.

## Out of Scope (Future Considerations)

- Language for a sitting (#58), which joins the same control.
- Focus and announcement after the panel is redrawn (#182).
- Changing the condition of a sitting's cards after the fact (bulk Set condition does it from the collection).
- A default or remembered condition.

## Supersedes

- [Spec 009](../009-card-scanner-confirm-flow/spec.md) Non-Goals "Setting a condition … during the scan" and "Sitting-wide defaults", and FR-1's "Must not: Set condition … when adding", for condition (price and quantity stay deferred; language is #58); AC-1.2's "condition … unspecified" (the sitting's condition, unspecified unless set); AC-1.3's notice and AC-3.2's entry line and heading (they name the condition); AC-3.7, for the control only (it shows with no open sitting, for every collector).
- [Spec 040](../040-sitting-into-location/spec.md) Goals' "no condition", decision 4's "condition (none)" and FR-1's "Must not: … set a condition", for condition (a scan adds with the sitting's condition); decision 3 and AC-1.1, AC-1.2 and AC-5.2's copy (the control's legend and fields, "Cards you scan now: …"); AC-3.1 (an account with no locations sees the condition control before the first add); AC-3.3 (`location_id` is no longer required; a request needs one of the two keys); decision 2's "Choosing 'No location' on a sitting that holds no cards … deletes it again", AC-1.8 and AC-3.2's drop rule (an empty sitting is deleted or dropped only when it has no condition either); AC-3.2's "with Done and no select" and AC-5.2's control "when the account has locations" (an account with no locations now sees the Condition select there, and no Location select); the "Set" status messages of `Scanner::SittingsController`.

Recorded here and in the specs index; neither spec is edited (`.claude/rules/documentation.md`).

## Documents that change

| Document | Change |
|---|---|
| `docs/specs/README.md` | A row for 042; the supersessions of 009 and 040 recorded both ways |
| `docs/roadmap.md` | Item 21b marked built, with decision 1's ruling; item 21a's "21b and 21c keep the order" amended (only 21c does) |
| `docs/architecture/collection-and-lots.md` | The scope line on the scanner and "Every way of adding … merges into the identity" and their Sources (spec 040 decision 4 is frozen there, and this spec supersedes its "condition (none)"): the scanner adds with the sitting's condition and place |
| `docs/architecture/data-portability.md` | The working-state invariant: the sitting's condition, like its place, adds no coverage entry or format version |
| `docs/design-system/components/Scanner.md` | The sitting control: its legend and two fields, that every collector sees it before the first add, the "Cards you scan now: …" copy in the panel and the status line, the condition in the add notice and the entry line |
