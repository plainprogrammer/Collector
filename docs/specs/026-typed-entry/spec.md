# Feature 026: Add Cards from a Set by Collector Number

**Status:** Approved by the maintainer (2026-10-15), with rulings on decisions 3, 4 and 7
**Version:** 1.2.3
**Created:** 2026-10-15
**Last Updated:** 2026-10-15
**Branch:** `026-typed-entry`
**Issue:** [#43](https://github.com/plainprogrammer/Collector/issues/43)
**Plan:** retired in `6b18cd6bf263afe0761e78b43f48772a362fafed`; read it with `git show 6b18cd6bf263afe0761e78b43f48772a362fafed^:docs/specs/026-typed-entry/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-15 | Written from issue #43 (roadmap theme B, item 8) |
| 1.2.3 | 2026-10-15 | Merged with spec 025 (PR #113): More's rows are Export collection, Import collection (spec 025 decision 14), then Add by number (coordinator's instruction for the merge); no behaviour of number entry changes |
| 1.2.2 | 2026-10-15 | The maintainer's ruling on More's order: "Add by number" comes after "Export collection"; the account menu doesn't change |
| 1.2.1 | 2026-10-15 | Records what this spec supersedes in earlier specs and ADRs (frozen-specs ruling of 2026-10-15); no behaviour changes |
| 1.2.0 | 2026-10-15 | Approved by the maintainer. Decisions 3, 4 and 7 ruled as recommended |
| 1.1.0 | 2026-10-15 | From the spec review (Opus). Reached from More on a phone, and from the empty collection; the finish defaults to the type's first finish, as the scanner's adds do, so the two paths fill the same lots (decision 3, open); an exact number match comes first and only a tie asks the collector, by the entry's external key, checked on the server; languages show as their codes, as everywhere else in the app; the line key is defined; undone lines leave the list; "Changed" is worked out when the page is shown; the list goes with the account; sets of every kind are offered (decision 9); the cross-type code collision is dropped (the type is in the URL); performance stated as queries, measured in `verification.md`; the cost isn't called bounded |

---

## Problem Statement

The north star names fast typed entry as one of the two bulk entry paths 1.0 needs (ruling 8), and puts it right after data safety (ruling 16). Today a collector adds a card by searching for it by name and opening its page (spec 004), or by scanning it (specs 007–011). Neither suits a box of cards already sorted by set and number: searching by name is slow for hundreds of cards, and the scanner needs a camera and a hand free.

Every printed card carries its set and its collector number. This spec lets a signed-in collector choose a set once and then add cards by typing a collector number and a quantity, line after line, without leaving the keyboard.

> **Terms.** *Number entry* is the page this spec adds. A *line* is one number, quantity and finish the collector submits; an *added line* is one that added copies. The *list* is the account's added lines, shown on the page until the collector ends it with Done. *Set* and *entry* are the catalog core's `Catalog::Set` and `Catalog::Entry` (ADR 0018); a *lot* is spec 004's (ADR 0019). *Finish* and *condition* are the values a collectible's vocabulary defines (`Catalog.collecting_for`); the vocabulary's *finish order* is its list of finishes, in order (`finish_order`).

## Goals

- A signed-in collector chooses a set and a language, then adds copies of that set's entries by collector number and quantity, one line at a time, using only the keyboard.
- Each line merges into the collector's lots exactly as the card page's Add does (spec 004 AC-7.4), and a card typed in lands in the same lot as the same card scanned (spec 009).
- A mistake is visible and reversible at once: each added line shows the card it matched and has an Undo.
- Nothing in the page, its models or its copy names a collectible type; it works for any type the catalog registers.
- The cost per account is stated (hosted-door rule 4).

## Non-Goals

- Choosing a location for the copies (issue #51, theme C item 16).
- Setting condition or price paid on a line; both stay unspecified, as Quick add and the scanner leave them, and are edited on the lot afterwards.
- Pasting or uploading a list of numbers, or importing another tool's file (parked until after 1.0).
- Changing the scanner, the card page's Add or Quick add.
- Any change to the export format: the list is working state, left out of the export like the scanner's sitting (decision 6).
- Telling apart sets of the same code in two collectible types: only one type is registered, and the type travels in the URL with the code (decision 2).

## Users and Context

**Primary users:** a signed-in collector with a sorted box, binder page or pile of cards from one set, at a computer with a keyboard (a phone works too, with its on-screen keyboard).
**Usage context:** loading a collection into a new instance, or adding a booster box's or a purchase's cards. Hundreds of cards in a sitting, mostly one copy each, some playsets, a few foils.
**User mental model:** "Set MH3. 12, enter. 47, tab, 4, enter. 103, tab, tab, foil, enter." The collector looks at the card, types, and glances at the screen to check the name that came back.

## Decisions

Each decision is the recommendation put to the maintainer. Decisions 3, 4 and 7 were open and are ruled; the others were approved with the spec.

### 1. The page and its entry points

Number entry is one page, titled "Add by number", under the collection (`/collection/number_entry`), so it needs a signed-in collector whether the catalog is open or not (spec 023). It is linked from three places:

- the collection page's header, as a secondary button beside "Scan cards" and "Add items" (wide screens; the page head's buttons hide on a phone, `CollectionPagePhone`);
- the More page, as "Add by number" (phones, where More is the home of secondary destinations);
- the empty collection's message, which a new instance shows first: "No cards in your collection yet. Search for a card or add cards by number to start adding."

### 2. Choosing the set and the language

The page starts with one field: the set. It offers every set that has at least one active entry, newest first by release date (sets with no date last), then by code, each shown as its name and code ("Modern Horizons 3 (MH3)"). The offered sets are a native suggestion list on the text field, so typing filters them without scripting, and the collector may type just the code. The value resolves to a set by its code (any case), by its exact name (any case), or by the shown "Name (CODE)" form. When more than one collectible type is registered, each offered set also shows its catalog's title, as search's set filter does.

Once a set is chosen, a language field offers the languages the set's active entries have, shown as their codes in capitals ("EN", "JA"), as the card page and the collection table show them. It defaults to EN when the set has English entries, and otherwise to the language most of the set's active entries have (ties go to the first by code). When the set has one language, the page states it and shows no field.

The chosen set (its type and code) and language are in the page's URL, so a reload or Back keeps them, and "Change set" returns to the set field.

### 3. A line is number, quantity and finish; the finish defaults to the type's first (ruled)

**Ruling (maintainer, 2026-10-15).** As recommended: the finish defaults to the type's first finish (Nonfoil for Magic cards) and carries over from the previous line.

A line has three fields, in tab order: number, quantity (default 1) and finish. Enter in any field submits the line.

- **Number**: see decision 8.
- **Quantity** is a whole number from 1 to 9,999.
- **Finish** offers the type's finishes in the vocabulary's finish order, labelled by the vocabulary. It defaults to the first (for Magic cards, Nonfoil), and keeps the previous line's choice after an add, so a run of foils needs the choice once. The chosen finish travels in the URL after an add, so it carries over without scripting too. An entry that lists no finishes takes none, whatever the field says; an entry that doesn't offer the chosen finish is refused with a field error (AC-4.3).

Why not "Not specified", as Quick add does: the scanner adds every copy with a finish the printing offers (spec 009; `Scanner::Sitting.finish_offered?`), and a lot's identity includes its finish (spec 004), so a card typed with no finish and the same card scanned would sit in two lots that never merge. The default keeps typed entry and the scanner filling the same lots.

Alternatives put to the maintainer: (a) a "Not specified" default, as Quick add; (b) the finish resets to the default on every line, so a foil is never added by accident after a run of foils. The recommendation carries the choice over, because a sorted box usually keeps its foils together, and the added line shows the finish as a badge.

### 4. Each line adds at once (ruled)

**Ruling (maintainer, 2026-10-15).** As recommended: each line adds at once.

A line is added when it is submitted: its copies merge into the collector's lots, the list shows it at the top, and the cursor returns to an empty number field (quantity back to 1, finish kept). Nothing waits for a final "Save".

The alternative put to the maintainer: lines collect in a draft list, and one "Add all" adds them together, all or nothing. The recommendation adds each line at once, because a long sitting then loses nothing to a closed tab or a dropped connection, and the scanner's sitting already works this way (spec 009).

### 5. Undo and Done

Each added line has an Undo, which takes that line's copies back out of the lot they went into: the lot's quantity falls by the line's quantity, and the lot is removed when that leaves none. An undone line leaves the list, and the page says what was undone ("Undid 4 × Name."), as the scanner's Undo does.

Whether a line can be undone is worked out each time the page is shown: it can while its lot exists and holds at least the line's quantity. Otherwise (the lot was removed, merged away, or edited below the line's quantity) the line reads "Changed in your collection" and offers no Undo. A lot whose finish or condition was edited without a merge, and which still holds the copies, can still be undone; the copies come out of it as it now is, as with the scanner's Undo.

Done ends the list: it deletes the list and its lines and returns to the collection. The copies stay.

### 6. The list is working state, left out of the export

The list is stored per account, as the scanner's sitting is (spec 009), so it survives a reload and works without scripting. It is working state: what it added is already in the lots. The export format's Coverage tables list its tables as "Left out", with the reason, and the format and its version don't change (ADR 0020). Deleting an account deletes its list.

### 7. No live preview of the match (ruled)

**Ruling (maintainer, 2026-10-15).** As recommended: no live preview.

The page doesn't look up the number while the collector types. The added line names the card, its set and number, its quantity and its finish, which is where the collector checks the match, and Undo corrects a wrong one.

The alternative put to the maintainer: show the matched card's name beside the number field as the collector types, before Enter. It needs scripting and a request per pause in typing; the recommendation leaves it out to keep the page plain and fast.

### 8. Matching a number

A number matches the active entries of the chosen set and language in two steps:

1. An entry whose collector number equals the typed text, trimmed, exactly.
2. Only if none does: entries whose number equals it ignoring case and leading zeros ("007" finds "7", "117A" finds "117a"; a number of zeros alone, "0" or "00", compares as "0").

One match adds. Two or more ask the collector to choose (AC-2.9); the choice names the entry by its external key, which the server accepts only if that entry is active, in the chosen set and language, and matches the typed number.

Some collector numbers carry symbols a keyboard doesn't offer (a star, for example). They match only when typed exactly; such cards are added from their card page. A later spec can add an optional, per-type way to type them, behind the catalog's extension boundary.

### 9. Sets and entries of every kind

The offered sets are those with any active entry, and a number matches entries of any kind, not only the primary kind search and the scanner use (`Catalog::Entry.searchable`). Collectors keep tokens and other non-card printings in their sorted boxes, and those printings sit in their own sets (for Magic cards, token sets). This roughly doubles the offered sets; the suggestion list filters as the collector types, so the length costs nothing at the keyboard.

### 10. The line key

The line form carries a line key: a random token the server puts in the form and renews after every add. Adding is idempotent per key within the list: a second request with a key already in the list adds nothing and answers as the first did. Two lines typed one after another carry different keys and both add, even when they are the same number.

## Supersedes

Earlier specs are frozen (maintainer ruling, 2026-10-15). What this spec changes in them is recorded here, not there.

| Earlier document | Item | What changes |
|---|---|---|
| [Spec 004](../004-design-system-collection/spec.md) | AC-11.6 | The empty collection's sentence becomes "No cards in your collection yet. Search for a card or add cards by number to start adding.", with "add cards by number" linking to number entry (decision 1). Its link to search stays. |
| [Spec 004](../004-design-system-collection/spec.md), [spec 009](../009-card-scanner-confirm-flow/spec.md) | Spec 004's collection page head; spec 009 AC-8.2 | The collection page's head gains a secondary "Add by number" action before "Scan cards" and "Add items" (decision 1). "Scan cards" stays as AC-8.2 says. |
| [Spec 022](../022-export-collection/spec.md) | Decision 6 (More's rows, in order) | More gains an "Add by number" row after "Export collection" (ruling, 2026-10-15) and, since spec 025 merged, after its "Import collection" (v1.2.3): Signed in as, Export collection, Import collection, Add by number, then the admin links for an admin, then Sign out. The account menu doesn't gain it, so on this one row More holds more than the account menu (`MorePage.md` says so). |
| [ADR 0015](../../adr/0015-admin-progress-by-polling.md) | "Turbo morphing is on app-wide" | Morph stays every page's refresh method, except that a page may ask for another one; number entry asks for `replace`, so the focus moves after each add (plan, Phase 4). |

## User Stories

### Story 1: Choose a set and a language

**As a** signed-in collector
**I want** to choose the set my cards come from, and their language, once
**So that** I only type numbers after that

**Acceptance criteria:**

- [ ] **AC-1.1** Given a signed-in collector on their collection page at desktop width When they activate "Add by number" Then they are on the number entry page, whose heading is "Add by number" and whose set field has focus.
- [ ] **AC-1.2** Given a signed-in collector at phone width When they open More and activate "Add by number" Then they are on the number entry page. And given an empty collection, its message links "add cards by number" to the same page.
- [ ] **AC-1.3** Given sets A (released 2024, with active entries), B (released 2023, whose only active entries are of a non-primary kind) and C (all of whose entries are retired) When the collector opens number entry Then the set field offers A then B, each as "Name (CODE)", and doesn't offer C.
- [ ] **AC-1.4** Given a set with code `mh3` and name "Modern Horizons 3" When the collector submits the set field with "MH3", "mh3", "modern horizons 3" or "Modern Horizons 3 (MH3)" Then each shows the line form for that set, the set's name and code at the top of the page, and the number field has focus.
- [ ] **AC-1.5** Given a set with active English and Japanese entries When the collector chooses it Then the language field offers EN and JA, EN is chosen, and the URL holds the set's type, its code and the language.
- [ ] **AC-1.6** Given a set whose active entries are 30 in Japanese and 10 in German, none in English When the collector chooses it Then JA is chosen.
- [ ] **AC-1.7** Given a set whose active entries are all English When the collector chooses it Then the page states "EN" and shows no language field.
- [ ] **AC-1.8** Given a set field submitted with text that matches no offered set When the page answers Then it says "No set matches “<text>”. Type a set code or choose a set from the list.", keeps the text in the field, gives it focus, and shows no line form.
- [ ] **AC-1.9** Given the line form for a set When the collector activates "Change set" Then the set field is shown again, with focus, and the list is unchanged.
- [ ] **AC-1.10** Given a signed-out visitor, with the catalog open or not When they request the number entry page Then they are sent to sign in, and nothing about any collection is shown.
- [ ] **AC-1.11** Given a URL naming a set code or language that has no active entries When the page is requested Then the set field is shown with the message of AC-1.8 for that code.

### Story 2: Add cards by number

**As a** signed-in collector with the line form for a set open
**I want** to type a number and a quantity and press Enter
**So that** those copies are in my collection and I can type the next one

**Acceptance criteria:**

- [ ] **AC-2.1** Given set MH3, EN, with an active entry numbered "47" that offers nonfoil and foil, and no lot of it When the collector types 47 in the number field and presses Enter Then the account has one lot of that entry with quantity 1, finish nonfoil, condition unspecified and no price paid, and the list's first line names the entry and shows "MH3 · 47", "×1" and the finish.
- [ ] **AC-2.2** Given that add When the page answers Then the number field is empty and has focus, the quantity is 1, and the set, language and finish are unchanged.
- [ ] **AC-2.3** Given the line form When the collector types 47, Tab, 4, Enter Then the lot gains 4 copies and the line shows "×4".
- [ ] **AC-2.4** Given an entry numbered "47" that offers nonfoil and foil When the collector types 47, Tab, Tab, chooses Foil with the keyboard and presses Enter Then the copies go into a lot whose finish is foil, and the next line's finish is Foil.
- [ ] **AC-2.5** Given the account already has a nonfoil lot of entry 47 with no condition or price, quantity 2 When the collector adds 47 with quantity 3 and finish Nonfoil Then that lot has quantity 5 and no other lot is created.
- [ ] **AC-2.6** Given entries numbered "7" and "117a" When the collector submits "007", " 7 " and "117A" Then each adds a copy of the matching entry.
- [ ] **AC-2.7** Given an entry numbered "47" in English and another numbered "47" in Japanese When the collector adds 47 with EN chosen Then the copy is of the English entry.
- [ ] **AC-2.8** Given entries numbered "12a" and "12A" in the set and language When the collector submits "12a" Then the copy is of the entry numbered "12a", with no choice asked.
- [ ] **AC-2.9** Given entries numbered "049" and "49" and none numbered "0049" When the collector submits "0049" Then nothing is added, the page lists both entries by name and number, and choosing one with the keyboard adds the line's quantity and finish of it.
- [ ] **AC-2.10** Given a choice request naming an entry outside the chosen set and language, or one that doesn't match the typed number When it arrives Then nothing is added and the page shows the line form with the message of AC-4.1.
- [ ] **AC-2.11** Given the same line submitted twice with one line key (a double Enter, or a resubmitted request) When both requests arrive Then the copies are added once, and the list shows one line.
- [ ] **AC-2.12** Given the collector adds 47, then adds 47 again as a new line When both are added Then the lot has gained 2 copies and the list shows two lines.
- [ ] **AC-2.13** Given the line form, with no pointer used When the collector adds three lines in a row (number, Tab, quantity, Tab, finish, Enter, three times) Then all three are in the list and the lots, without a click, and every field and button they pass through shows the focus ring.
- [ ] **AC-2.14** Given a token entry in a token set When the collector chooses that set and adds its number Then a lot of the token entry gains the copies.
- [ ] **AC-2.15** Given an entry that lists no finishes When the collector adds it Then the copies go into a lot with no finish.

### Story 3: See and correct what was added

**As a** collector entering a long run of cards
**I want** to see each card that was added and undo a wrong one
**So that** a typo doesn't stay in my collection

**Acceptance criteria:**

- [ ] **AC-3.1** Given a list of 25 added lines adding 31 copies When the page is shown Then it shows "This list: 25 lines, 31 cards", the 10 newest lines newest first, and the rest behind "Show all 25".
- [ ] **AC-3.2** Given an added line of 4 copies into a lot that now holds 6 When the collector activates its Undo Then the lot holds 2, the line leaves the list, the page says "Undid 4 × <name>.", and the counts drop by one line and 4 cards.
- [ ] **AC-3.3** Given an added line of 4 copies into a lot that now holds exactly 4 When the collector activates its Undo Then the lot is removed.
- [ ] **AC-3.4** Given an added line of 4 copies into a lot that was since edited down to 3 copies, merged into another lot or removed When the page shows the line Then it reads "Changed in your collection" and offers no Undo, and an undo request for it changes nothing and says "Those copies have changed in your collection, so they can't be undone here."
- [ ] **AC-3.5** Given an added line of 4 copies into a lot whose condition was since edited, still holding 4 When the collector activates its Undo Then that lot is removed.
- [ ] **AC-3.6** Given a list When the collector reloads the page or leaves and comes back Then the list is unchanged.
- [ ] **AC-3.7** Given a list When the collector activates Done Then the list is cleared, they are on their collection page, and every lot it added copies to keeps them.
- [ ] **AC-3.8** Given a line cleared by Done in another tab, or another account's line When this collector requests its Undo Then the answer is 404 with "That line is no longer in your list.", and nothing changes.
- [ ] **AC-3.9** Given an account with a list When the account is deleted Then its list and lines are deleted with it.

### Story 4: Errors keep the line

**As a** collector typing quickly
**I want** a rejected line to stay as I typed it, with the reason next to it
**So that** I fix it and press Enter again

**Acceptance criteria:**

- [ ] **AC-4.1** Given the collector submits a number that matches no active entry of the set and language When the page answers Then nothing is added, the page says "No card numbered <number> in <set name> (<LANGUAGE>).", the number, quantity and finish stay as typed, and the number field has focus (with scripting on, its text is selected).
- [ ] **AC-4.2** Given a quantity of 0, -1, 2.5, "x" or 10000 When the line is submitted Then nothing is added, the quantity field says "must be a whole number from 1 to 9,999", and it has focus.
- [ ] **AC-4.3** Given an entry that offers only nonfoil When the collector submits it with finish Foil Then nothing is added and the finish field says "isn't available for this printing".
- [ ] **AC-4.4** Given a lot already holding 9,998 copies When the collector adds 2 more of it Then nothing is added and the page says "One lot can hold at most 9,999 copies."
- [ ] **AC-4.5** Given an empty number field When the collector presses Enter Then nothing is added and the number field keeps focus, with no error message.

### Story 5: Works without scripting

**As a** collector whose browser runs no scripts
**I want** number entry to still work
**So that** no step depends on JavaScript

**Acceptance criteria:**

- [ ] **AC-5.1** Given scripting off When the collector chooses a set, adds a foil line, adds another line, undoes it and activates Done Then each step works, through full page loads, with the outcomes of Stories 1–3: after each add the number field has focus and the finish is still Foil.

## Functional Requirements

### FR-1: The number entry page

**Must:**
- Be linked from the collection page's header, More, and the empty collection's message, and need a signed-in collector.
- Keep the chosen set (type and code), language and, after an add, finish in the URL.
- Offer only sets with at least one active entry, of any kind, newest first by release date (no date last), then by code.

**Must not:**
- Name any collectible type, its finishes or its conditions in its code or copy; labels come from the catalog (`Catalog.title_for`) and the type's vocabulary.
- Be reachable by a visitor through the open catalog (spec 023).

### FR-2: Matching a number

**Must:**
- Match only active entries of the chosen set and language, of any kind.
- Prefer an exact match of the trimmed number; fall back to ignoring case and leading zeros only when there is none (decision 8).
- Ask the collector to choose when more than one entry matches, and check the chosen entry on the server (AC-2.10).

**Must not:**
- Match a retired entry, or an entry of another set or language.
- Add anything when no single entry is chosen.

### FR-3: Adding a line

**Must:**
- Add through `Lot.add!`, so copies merge into the lot with the same entry, finish, condition and price, and the 9,999 cap holds.
- Take a finish the entry offers, or none when it lists none.
- Record the added line in the account's list, with the entry, the lot, the quantity, the finish and the line key, in the same transaction as the add.
- Add a line at most once per line key (decision 10).

**Must not:**
- Set a condition or a price paid.
- Record a line when the add fails.

### FR-4: Undo and Done

**Must:**
- Undo take exactly the line's quantity out of the lot it went into, removing the lot when that leaves none, and remove the line from the list.
- Refuse an Undo when the lot is gone or holds fewer copies than the line added, and say so.
- Done delete the account's list and its lines, and nothing else.

**Must not:**
- Undo a line twice.
- Touch another account's lines or lots (404).

### FR-5: Export coverage and account deletion

**Must:**
- List the list's tables in the export format's Coverage tables as "Left out": working state whose adds are already in the lots.
- Delete an account's list with the account.

**Must not:**
- Change the export format, its schema, its examples or its version.

## Non-Functional Requirements

### Performance

- An add runs a fixed number of queries whatever the set's size: find the entries by set, language and number; upsert the lot; insert the line; read the list to show it. The plan measures an add against the full English Magic catalog on the development machine and records the time in `verification.md`.
- The set suggestions render once per page, not per line.

### Security

- Every query of lots and lines is scoped to `Current.account`; another account's line answers 404 (multi-tenancy rule).
- Strong parameters. No `account_id` or lot id comes from a form. The entry is found from set, language and number; the one id a form carries is an entry's external key on a choice between matches, checked as decision 8 says.

### Reliability

- Adding and recording a line happen in one transaction; a failure leaves neither.
- Cost per account (hosted-door rule 4): one list per account, which grows by one row of about 100 bytes per added line until Done deletes it, as the scanner's sitting does. No background work.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| No set matches the typed text | Message, text kept, set field focused (AC-1.8) |
| A set code or language in the URL with no active entries | The set field, with the message (AC-1.11) |
| No entry has the number | Nothing added, message, line kept, number focused (AC-4.1) |
| Two entries match the number | Collector chooses one (AC-2.9) |
| A forged choice | Nothing added (AC-2.10) |
| Quantity invalid | Nothing added, field error (AC-4.2) |
| Finish not offered by the entry | Nothing added, field error (AC-4.3) |
| Lot would exceed 9,999 | Nothing added, cap message (AC-4.4) |
| Line submitted twice with one key | Added once (AC-2.11) |
| Undo after the lot changed | Refused, "Changed in your collection" (AC-3.4) |
| Undo of a cleared or another account's line | 404, nothing changes (AC-3.8) |
| The catalog has no sets loaded | The page says no catalog is loaded yet, as search does (`catalog/not_loaded`), and shows no form |

## Open Questions

None. Decisions 3, 4 and 7 were ruled on 2026-10-15, as recommended.

## Out of Scope (Future Considerations)

- Choosing a location during number entry (#51).
- Condition, language or price paid per line; a sitting-wide condition (theme D's 21b is the scanner's).
- An optional per-type way to type numbers with symbols (decision 8).
- Telling apart a set code shared by two collectible types.
- Pasting a list of numbers.

## Documents that change

- `docs/export-format/README.md`: the Coverage tables gain the list's tables, as "Left out".
- `docs/design-system/`: a doc for the number entry page's new pattern under `components/`, listed in the README's app additions.
- `CLAUDE.md`: a line on number entry.
- `docs/roadmap.md`: item 8 marked done, with the spec and the PR.
