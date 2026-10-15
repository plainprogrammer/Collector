# Feature 026: Add Cards from a Set by Collector Number

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-10-15
**Last Updated:** 2026-10-15
**Branch:** `026-typed-entry`
**Issue:** [#43](https://github.com/plainprogrammer/Collector/issues/43)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-15 | Written from issue #43 (roadmap theme B, item 8) |

---

## Problem Statement

The north star names fast typed entry as one of the two bulk entry paths 1.0 needs (ruling 8), and puts it right after data safety (ruling 16). Today a collector adds a card by searching for it by name and opening its page (spec 004), or by scanning it (specs 007–011). Neither suits a box of cards already sorted by set and number: searching by name is slow for hundreds of cards, and the scanner needs a camera and a hand free.

Every printed card carries its set and its collector number. This spec lets a signed-in collector choose a set once and then add cards by typing a collector number and a quantity, line after line, without leaving the keyboard.

> **Terms.** *Number entry* is the page this spec adds. A *line* is one number, quantity and finish the collector submits; an *added line* is one that added copies. The *list* is the account's added lines, shown on the page until the collector ends it with Done. *Set* and *entry* are the catalog core's `Catalog::Set` and `Catalog::Entry` (ADR 0018); a *lot* is spec 004's (ADR 0019). *Finish* and *condition* are the values a collectible's vocabulary defines (`Catalog.collecting_for`).

## Goals

- A signed-in collector chooses a set and a language, then adds copies of that set's entries by collector number and quantity, one line at a time, using only the keyboard.
- Each line merges into the collector's lots exactly as the card page's Add does (spec 004 AC-7.4).
- A mistake is visible and reversible at once: each added line shows the card it matched and has an Undo.
- Nothing in the page, its models or its copy names a collectible type; it works for any type the catalog registers.
- The cost per account is stated and bounded (hosted-door rule 4).

## Non-Goals

- Choosing a location for the copies (issue #51, theme C item 16).
- Setting condition or price paid on a line; both stay unspecified, as Quick add leaves them (spec 004 Story 7), and are edited on the lot afterwards.
- Pasting or uploading a list of numbers, or importing another tool's file (parked until after 1.0).
- Changing the scanner, the card page's Add or Quick add.
- Any change to the export format: the list is working state, left out of the export like the scanner's sitting (decision 6).

## Users and Context

**Primary users:** a signed-in collector with a sorted box, binder page or pile of cards from one set, at a computer with a keyboard (a phone works too, with its on-screen keyboard).
**Usage context:** loading a collection into a new instance, or adding a booster box's or a purchase's cards. Hundreds of cards in a sitting, mostly one copy each, some playsets, a few foils.
**User mental model:** "Set MH3. 12, enter. 47, tab, 4, enter. 103, tab, tab, foil, enter." The collector looks at the card, types, and glances at the screen to check the name that came back.

## Decisions

Each decision is the recommendation put to the maintainer. A decision marked *(open)* needs a ruling before the spec is approved.

### 1. The page and its entry point

Number entry is one page, reached from an "Add by number" button in the collection page's header, beside "Scan cards" and "Add items". It is a page of the collector's own, under the collection (`/collection/number_entry`), so signed-out visitors never reach it, open catalog or not (spec 023). The page's title is "Add by number".

### 2. Choosing the set and the language

The page starts with one field: the set. It offers every set that has at least one active entry, newest first, each shown as its name and code ("Modern Horizons 3 (MH3)"); typing filters the offered sets, and the collector may type just the code. The value resolves to a set by its code (any case), by its exact name, or by the shown "Name (CODE)" form. When more than one collectible type is registered, each offered set also shows its catalog's title, and a code shared by two types resolves only through that labelled form.

Once a set is chosen, a language field offers the languages the set's active entries have. It defaults to English when the set has English entries, and otherwise to the language that most of the set's active entries have (ties go to the first by language code). The chosen set and language are in the page's URL, so a reload or Back keeps them, and "Change set" returns to the set field.

### 3. A line is number, quantity and finish *(open)*

A line has three fields, in tab order: number, quantity (default 1) and finish. Enter in any field submits the line.

- **Number** matches an active entry of the chosen set and language whose collector number is the same after trimming spaces, ignoring case and ignoring leading zeros ("007" finds "7", "117A" finds "117a").
- **Quantity** is a whole number from 1 to 9,999.
- **Finish** offers the type's finishes, labelled by its vocabulary, plus "Not specified". It defaults to "Not specified" and keeps the previous line's choice after an add, so a run of foils needs the choice once.

The alternative put to the maintainer: finish defaults to "Not specified" on every line and doesn't carry over, so a foil is never added by accident after a run of foils. The recommendation carries it over, because a sorted box usually keeps its foils together, and the added line shows the finish.

### 4. Each line adds at once *(open)*

A line is added when it is submitted: its copies merge into the collector's lots, the list shows it at the top, and the cursor returns to an empty number field (quantity back to 1, finish kept as decision 3 says). Nothing waits for a final "Save".

The alternative put to the maintainer: lines collect in a draft list, and one "Add all" adds them together, all or nothing. The recommendation adds each line at once, because a long sitting then loses nothing to a closed tab or a dropped connection, and the scanner's sitting already works this way (spec 009).

### 5. Undo and Done

Each added line has an Undo, which takes that line's copies back out of the lot they went into: the lot's quantity falls by the line's quantity, and the lot is removed when that leaves none. If the lot was since edited, merged or removed so that it no longer holds those copies, the line says "Changed in your collection" and offers no Undo. Done ends the list: it clears the list and returns to the collection. The copies stay.

### 6. The list is working state, left out of the export

The list is stored per account, as the scanner's sitting is (spec 009), so it survives a reload and works without scripting. It is working state: what it added is already in the lots. The export format's Coverage tables list its tables as "Left out", with the reason, and the format and its version don't change (ADR 0020).

### 7. No live preview of the match *(open)*

The page doesn't look up the number while the collector types. The added line names the card, its set and number and its finish, which is where the collector checks the match, and Undo corrects a wrong one.

The alternative put to the maintainer: show the matched card's name beside the number field as the collector types, before Enter. It needs a lookup per keystroke pause and scripting to show it; the recommendation leaves it out to keep the page plain and fast.

### 8. Numbers the keyboard can't type are out of scope

Some collector numbers carry symbols a keyboard doesn't offer (a star, for example). Number entry matches them only when typed exactly; there is no per-type rule for typing them another way. Such cards are added from their card page. A later spec can add an optional, per-type way to type them, behind the catalog's extension boundary.

## User Stories

### Story 1: Choose a set and a language

**As a** signed-in collector
**I want** to choose the set my cards come from, and their language, once
**So that** I only type numbers after that

**Acceptance criteria:**

- [ ] **AC-1.1** Given a signed-in collector on their collection page When they activate "Add by number" Then they are on the number entry page, whose heading is "Add by number" and whose set field has focus.
- [ ] **AC-1.2** Given sets A (released 2024, with active entries), B (released 2023, with active entries) and C (all of whose entries are retired) When the collector opens number entry Then the set field offers A then B, each as "Name (CODE)", and doesn't offer C.
- [ ] **AC-1.3** Given a set with code `mh3` and name "Modern Horizons 3" When the collector submits the set field with "MH3", "mh3", "Modern Horizons 3" or "Modern Horizons 3 (MH3)" Then each shows the line form for that set, the set's name and code in the page's heading area, and the number field has focus.
- [ ] **AC-1.4** Given a set with active English and Japanese entries When the collector chooses it Then the language field offers English and Japanese, English is chosen, and the URL holds the set and the language.
- [ ] **AC-1.5** Given a set whose active entries are 30 in Japanese and 10 in German, none in English When the collector chooses it Then Japanese is chosen.
- [ ] **AC-1.6** Given a set field submitted with text that matches no offered set When the page answers Then it says "No set matches “<text>”. Type a set code or choose a set from the list.", keeps the text in the field, gives it focus, and shows no line form.
- [ ] **AC-1.7** Given the line form for a set When the collector activates "Change set" Then the set field is shown again, with focus, and the list is unchanged.
- [ ] **AC-1.8** Given a signed-out visitor, with the catalog open or not When they request the number entry page Then they are sent to sign in, and nothing about any collection is shown.
- [ ] **AC-1.9** Given two registered collectible types with a set of the same code `abc` When the collector opens number entry Then each offered set shows its catalog's title, submitting "abc" says the code matches more than one set and asks the collector to choose one from the list, and the labelled form resolves to its own type's set.

### Story 2: Add cards by number

**As a** signed-in collector with the line form for a set open
**I want** to type a number and a quantity and press Enter
**So that** those copies are in my collection and I can type the next one

**Acceptance criteria:**

- [ ] **AC-2.1** Given set MH3, English, with an active entry numbered "47", and no lot of it When the collector types 47 in the number field and presses Enter Then the account has one lot of that entry with quantity 1, finish unspecified, condition unspecified and no price paid, and the list's first line names the entry, shows "MH3 · 47", "×1" and "Not specified".
- [ ] **AC-2.2** Given that add When the page answers Then the number field is empty and has focus, the quantity is 1, and the set and language are unchanged.
- [ ] **AC-2.3** Given the line form When the collector types 47, Tab, 4, Enter Then the lot gains 4 copies and the line shows "×4".
- [ ] **AC-2.4** Given an entry numbered "47" that offers the finishes nonfoil and foil When the collector types 47, Tab, Tab, chooses Foil with the keyboard and presses Enter Then the copies go into a lot whose finish is foil, and the next line's finish is Foil.
- [ ] **AC-2.5** Given the account already has a lot of entry 47 with no finish, condition or price, quantity 2 When the collector adds 47 with quantity 3 and finish "Not specified" Then that lot has quantity 5 and no other lot is created.
- [ ] **AC-2.6** Given entries numbered "7" and "117a" When the collector submits "007", " 7 " and "117A" Then each adds a copy of the matching entry.
- [ ] **AC-2.7** Given an entry numbered "47" in English and another numbered "47" in Japanese When the collector adds 47 with English chosen Then the copy is of the English entry.
- [ ] **AC-2.8** Given a retired entry numbered "48" and no active one When the collector submits 48 Then nothing is added and the page says "No card numbered 48 in Modern Horizons 3 (English)."
- [ ] **AC-2.9** Given two active entries of the set and language whose numbers both match "49" When the collector submits 49 Then nothing is added, the page lists both entries by name and number, and choosing one with the keyboard adds the line's quantity and finish of it.
- [ ] **AC-2.10** Given the same line submitted twice (a double Enter, or a resubmitted request) When both requests arrive Then the copies are added once, and the list shows one line.
- [ ] **AC-2.11** Given the line form, with no pointer used When the collector adds three lines in a row (number, Tab, quantity, Tab, finish, Enter, three times) Then all three are in the list and the lots, without a click, and every field and button they pass through shows the focus ring.

### Story 3: See and correct what was added

**As a** collector entering a long run of cards
**I want** to see each card that was added and undo a wrong one
**So that** a typo doesn't stay in my collection

**Acceptance criteria:**

- [ ] **AC-3.1** Given a list of 25 added lines When the page is shown Then it shows "This list: 25 lines, 31 cards" (lines and the copies they added), the 10 newest lines newest first, and the rest behind "Show all 25".
- [ ] **AC-3.2** Given an added line of 4 copies into a lot that now holds 6 When the collector activates its Undo Then the lot holds 2, the line reads "Undone" with no Undo, and the counts drop by one line and 4 cards.
- [ ] **AC-3.3** Given an added line of 4 copies into a lot that now holds exactly 4 When the collector activates its Undo Then the lot is removed.
- [ ] **AC-3.4** Given an added line of 4 copies into a lot that was since edited down to 3 copies, merged into another lot or removed When the page shows the line Then it reads "Changed in your collection" and offers no Undo, and a request to undo it changes nothing and says so.
- [ ] **AC-3.5** Given a list When the collector reloads the page or leaves and comes back Then the list is unchanged.
- [ ] **AC-3.6** Given a list When the collector activates Done Then the list is cleared, they are on their collection page, and every lot it added copies to keeps them.
- [ ] **AC-3.7** Given another account's added line When this collector requests its Undo Then the answer is 404 and nothing changes.

### Story 4: Errors keep the line

**As a** collector typing quickly
**I want** a rejected line to stay as I typed it, with the reason next to it
**So that** I fix it and press Enter again

**Acceptance criteria:**

- [ ] **AC-4.1** Given the collector submits a number that matches no active entry of the set and language When the page answers Then nothing is added, the page says "No card numbered <number> in <set name> (<language>).", the number and quantity stay as typed, and the number field has focus with its text selected.
- [ ] **AC-4.2** Given a quantity of 0, -1, 2.5, "x" or 10000 When the line is submitted Then nothing is added, the quantity field says "must be a whole number from 1 to 9,999", and it has focus.
- [ ] **AC-4.3** Given an entry that offers only nonfoil When the collector submits it with finish Foil Then nothing is added and the finish field says "isn't available for this printing".
- [ ] **AC-4.4** Given a lot already holding 9,998 copies When the collector adds 2 more of it Then nothing is added and the page says "One lot can hold at most 9,999 copies."
- [ ] **AC-4.5** Given an empty number field When the collector presses Enter Then nothing is added and the number field keeps focus, with no error message.

### Story 5: Works without scripting

**As a** collector whose browser runs no scripts
**I want** number entry to still work
**So that** no step depends on JavaScript

**Acceptance criteria:**

- [ ] **AC-5.1** Given scripting off When the collector chooses a set, adds a line, undoes it and activates Done Then each step works, through full page loads, with the same outcomes as Stories 1–3, and after each add the number field has focus.

## Functional Requirements

### FR-1: The number entry page

**Must:**
- Be reachable from the collection page's header ("Add by number") on wide and narrow screens, and need a signed-in collector.
- Keep the chosen set and language in the URL.
- Offer only sets with at least one active entry, newest first by release date, then by code.

**Must not:**
- Name any collectible type, its finishes or its conditions in its code or copy; labels come from the catalog (`Catalog.title_for`) and the type's vocabulary.
- Be reachable by a visitor through the open catalog (spec 023).

### FR-2: Matching a number

**Must:**
- Match only active entries of the chosen set and language, of any kind.
- Compare numbers after trimming, ignoring case and leading zeros.
- Ask the collector to choose when more than one entry matches (AC-2.9).

**Must not:**
- Match a retired entry, or an entry of another set or language.
- Add anything when no single entry is chosen.

### FR-3: Adding a line

**Must:**
- Add through `Lot.add!`, so copies merge into the lot with the same entry, finish, condition and price, and the 9,999 cap holds.
- Record the added line in the account's list, with the entry, the lot, the quantity and the finish, in the same transaction as the add.
- Add a line at most once for a given line key, so a repeated submission adds nothing more (AC-2.10).

**Must not:**
- Set a condition or a price paid.
- Record a line when the add fails.

### FR-4: Undo and Done

**Must:**
- Undo take exactly the line's quantity out of the lot it went into, removing the lot when that leaves none.
- Refuse an Undo when the lot is gone or holds fewer copies than the line added, and say so.
- Done delete the account's list and its lines, and nothing else.

**Must not:**
- Undo a line twice.
- Touch another account's lines or lots (404).

### FR-5: Export coverage

**Must:**
- List the list's tables in the export format's Coverage tables as "Left out", working state whose adds are already in the lots.

**Must not:**
- Change the export format, its schema, its examples or its version.

## Non-Functional Requirements

### Performance

- An add answers in under 200 ms on the development machine with the full English MTG catalog loaded (one entry lookup, one lot upsert, one line insert).
- The set field's choices render once per page, not per line.

### Security

- Every query of lots and lines is scoped to `Current.account`; another account's line answers 404 (multi-tenancy rule).
- Strong parameters; no `account_id`, lot or entry id is taken from the line form (the entry is found from set, language and number; Undo finds the line under the account).

### Reliability

- Adding and recording a line happen in one transaction; a failure leaves neither.
- Cost per account (hosted-door rule 4): one list per account, and one line row (about 100 bytes) per added line until Done deletes them. No background work.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| No set matches the typed text | Message, text kept, set field focused (AC-1.6) |
| A set code matches sets of two types | Asked to choose the labelled set (AC-1.9) |
| No entry has the number | Nothing added, message, number kept and focused (AC-4.1) |
| Two entries match the number | Collector chooses one (AC-2.9) |
| Quantity invalid | Nothing added, field error (AC-4.2) |
| Finish not offered by the entry | Nothing added, field error (AC-4.3) |
| Lot would exceed 9,999 | Nothing added, cap message (AC-4.4) |
| Line submitted twice | Added once (AC-2.10) |
| Undo after the lot changed | Refused, "Changed in your collection" (AC-3.4) |
| The catalog has no sets loaded | The page says no catalog is loaded yet, as search does, and shows no form |
| A set or language in the URL that doesn't exist | The set field is shown with the message of AC-1.6 |

## Open Questions

- Decision 3 *(open)*: does the finish carry over from the previous line (recommended), or reset to "Not specified" each line?
- Decision 4 *(open)*: does each line add at once (recommended), or do lines collect in a draft added all at once?
- Decision 7 *(open)*: no live preview of the match (recommended), or a preview of the card name while typing?

## Out of Scope (Future Considerations)

- Choosing a location during number entry (#51).
- Condition, language per line, or price paid per line; a sitting-wide condition (theme D's 21b is the scanner's).
- An optional per-type way to type numbers with symbols (decision 8).
- Pasting a list of numbers.

## Documents that change

- `docs/export-format/README.md`: the Coverage tables gain the list's tables, as "Left out".
- `docs/design-system/`: a doc for the number entry page's new pattern under `components/`, listed in the README's app additions.
- `CLAUDE.md`: a line on number entry.
- `docs/roadmap.md`: item 8 marked done, with the spec and the PR.
