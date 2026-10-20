# Feature 029: Manage Locations

**Status:** Draft (awaiting the maintainer's rulings on decisions 1–4)
**Version:** 1.0.0
**Created:** 2026-10-20
**Last Updated:** 2026-10-20
**Branch:** `029-manage-locations`
**Issue:** [#44](https://github.com/plainprogrammer/Collector/issues/44)
**Plan:** none yet

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-20 | Written from issue #44 (roadmap theme C, item 9), the export format (spec 017, ADR 0020), the export (spec 022), the import preview (spec 025) and the design system's "where is it" |

---

## Problem Statement

The design system says players need "where is it" as much as "what is it", and the 1.0 test's first check is that the family's real cards are in a deployed instance, "each with a location" ([north star](../../north-star.md)). Collector has no places at all today: a lot is a quantity of one printing and nothing more (spec 004, [ADR 0019](../../adr/0019-lot-as-the-unit-of-ownership.md)).

This spec adds the places themselves and nothing else. A signed-in collector creates, renames and removes the locations their collection is kept in (a binder, a box). Putting a lot in a location is issue #45, which needs an ADR first; showing and filtering by location, moving many lots at once, decks and choosing a place during typed entry follow it (items 11–16).

A location is data the collector owns, so this spec extends the export format in the same pull request (roadmap ruling 19, north star "Export covers it"). That is the larger part of the work, and decision 1 explains why locations alone already make the format version 2.

> **Terms.** A *location* is a named place the collector keeps part of their collection. The *locations page* is the page this spec adds. A *name* is a location's name as the collector typed it, after the normalisation of decision 5. The *instance* and *account* are as in spec 004; the *export*, the *preview*, *well-formed* and *resolvable* are as in specs 017, 022 and 025.

## Goals

- A signed-in collector sees their locations on one page, creates a location by giving it a name, renames it, and removes it.
- Locations belong to the account: another account's locations are never visible, changeable or counted.
- An export carries the collector's locations, so the restore-and-match check of the 1.0 test stays true.
- The import preview reads a file that carries locations, and reads a file written before locations existed, so a collector can always preview their own export.
- What removing a location does to the copies it holds is decided now (decision 3), so that #45 builds on a settled rule.
- The cost per account is stated (hosted-door rule 4).

## Non-Goals

- Putting a lot, or some of its copies, in a location (#45, which also decides how a lot sits in more than one place; ADR 0019's open question).
- Showing a location on tiles and rows, filtering by location, "Move to…", decks, "Free to use", and choosing a location in typed entry or at the scanner (#46–#51, #56).
- A kind of location (binder, box, deck) or any other attribute besides the name (decision 4).
- Ordering locations by hand, nesting them, or giving them notes, photos or labels.
- Applying an imported file's locations. The apply step is issue #40 (spec 028, in progress); decision 8 records what this spec promises it and what it leaves to it.
- A per-collector choice of which sections the navigation shows (design system, Navigation: "will be able to").
- Counting lots or copies per location (nothing can be in one yet).

## Users and Context

**Primary users:** a signed-in collector who keeps cards in binders, boxes and the like and wants the app to know their names before putting anything in them.
**Usage context:** setting up an instance for a family's collection, where a dozen to a few hundred places are named up front, then occasionally renamed or retired.
**User mental model:** "The blue binder, the long box on the shelf, the trade binder. Add them, fix a typo, drop the one I took apart."

## Decisions

Each decision is the recommendation put to the maintainer. Decisions 1–4 are the maintainer's to rule; the rest follow from them or from existing rules.

### 1. Locations alone raise the export format to version 2 (proposed)

[ADR 0020](../../adr/0020-export-format.md) and the format document's "Versions" section say the version goes up for "a new field that holds data the collector owns", and spec 017 decision 14 gave the reason: a version-1 reader ignores fields it doesn't know, so it would drop a collector's locations without a word. The set of locations is such a field. So this spec, not only #45, changes the format:

- The format becomes **version 2**: a new required top-level field `locations`, a list of objects with one field, `name` (decision 9 gives its shape). Lots are unchanged in version 2.
- A new schema file, `v2.schema.json`, states version 2. `v1.schema.json` stays, because version 1 files exist and the meaning of a released version never changes.
- The Coverage tables gain the new table's row and columns (the suite fails until they are listed).

**Recommendation, and what it does to #45.** #45 records which location each lot's copies are in. That is a further change to data the collector owns, so it raises the format again, to **version 3**. The statements that said "#45 raises the format to version 2" (ADR 0020's consequences, spec 017 decision 14, the roadmap's item 10, the format document's version history) are superseded by this spec; see Supersedes.

The alternative put to the maintainer: ship version 2 here and let #45 change version 2 before any release carries it. It saves a version number. It is fragile: `main` publishes `edge` images, so a collector can hold a version 2 file the day this merges, and the format's rule is that a released version never changes. Whether a file counts as released is not something the format can know.

What does *not* need a bump: nothing else in this spec adds data. The locations page itself changes no file.

### 2. The export always writes the newest version (proposed)

An export is written in version 2, with `locations` present and empty for an account with none. It does not fall back to version 1 for an account without locations: one shape is simpler to read and to test, and the file says what it is.

Locations are written in the order of their names, ignoring case, then by the name itself. The format gives the order no meaning; a fixed order makes two exports of one collection byte-identical apart from their time.

### 3. Removing a location never removes copies (proposed)

**Recommendation.** Removing a location does not delete, change or merge any lot. The copies it held stay owned and are then in no location. Removing goes through a confirmation page, which will say how many lots are in the location once #45 can put them there. In this spec no lot can be in a location, so the page says only which location is removed.

This binds #45: whichever way its ADR divides a lot among places, deleting a location sets its copies back to "no location" and nothing else.

Alternatives put to the maintainer: (a) refuse to remove a location while it holds lots, so the collector moves them first. That needs "Move to…" (#48, item 13) to exist before a location can be retired, and a collector who takes a binder apart would have to move every lot out by hand. (b) Delete the lots with the location, rejected: nothing a collector does to a place should delete what they own.

### 4. A location is a name (proposed)

A location has one attribute, its name. It has no kind (binder, box, deck). Decks as locations is issue #49 and may need more than a kind (the design system says a copy in a deck isn't free for another deck); settling a vocabulary now would guess at it. If #49 adds a kind, it is data the collector owns, so it raises the format again; that cost is accepted, as it is for every later field.

The alternative put to the maintainer: ship a `kind` now to avoid a later format change. It adds a vocabulary to decide (comics have long boxes and short boxes), a field in every form and in the file, and nothing the collector can do with it before #46.

### 5. Names

A name is what the collector types, normalised:

- Spaces and other whitespace at its start and end are removed, and each run of whitespace inside it becomes one space.
- It is 1 to 60 characters after that, and holds no control characters other than whitespace (U+0000, for one, is refused; a tab or newline is whitespace and becomes a space).
- No two of an account's locations have the same name ignoring case ("Blue binder" and "blue binder" are one name). Case is compared by Unicode lower-casing. Renaming a location to its own name in another case ("box" to "Box") is allowed.
- Any other character is allowed, in any script.

An account has at most 500 locations (decision 7).

### 6. The page, its routes and its words

The locations page is `GET /locations`: a heading "Locations", a one-field form (name, "Add location"), and the account's locations as a list, in the order of decision 2, each with a Rename and a Remove action. Rename opens `GET /locations/:id/edit`, a page with the name field, "Save" and "Cancel". Remove opens `GET /locations/:id/removal/new`, a confirmation page in the style of removing copies (`ConfirmPage`): "Remove <name>?", a "Remove" button and "Cancel". Creating is `POST /locations`, renaming `PATCH /locations/:id`, removing `DELETE /locations/:id`. A successful create, rename or remove redirects (303) to the locations page and says what happened ("Added Blue binder.", "Renamed Blue binder to Trade binder.", "Removed Blue binder."). A failed create or rename answers 422 with the reason beside the name field and the typed text kept.

The page works without scripting. It follows the design system's tokens and `c-*` classes; its new pattern, if any, gets a doc under `docs/design-system/components/` and a line in the README's app additions, as specs 025 and 026 did. Its empty state says what to do next: "No locations yet. Add a binder or a box to start recording where things are kept." The copy names no collectible type.

### 7. The cost is bounded: 500 locations of 60 characters

An account has at most 500 locations, a name is at most 60 characters, and a location is one row of about 100 bytes: at most about 50 KB of storage per account and about 20 KB more in an export. No background work. The limits are in the format as well (decision 9), as the quantity limit of 1 to 9,999 already is. They are a ceiling for a hosted instance, not a number a collector should meet: a few hundred places already describes a very large collection. A request over the limit is refused with "You can have at most 500 locations."

### 8. How the page is reached

[Design system](../../design-system/README.md), Navigation: Collection, Decks, Locations and Wishlist are the default sections; wide screens show them in the header; the tab bar holds five at most and "a new section starts in More". So:

- Wide screens: "Locations" in the header's navigation, after "Scan".
- Phones: a "Locations" row in More, before "Export collection". The tab bar doesn't change.
- Not in the account menu (the menu is for the profile, import and export).

The alternative: a fifth tab. It is allowed by count, but the rule says new sections start in More.

### 9. The shape of the format's version 2

`locations` is a required top-level field, a list that may be empty, in no meaningful order. Each element is an object with one field:

| Field | Value | Meaning |
|---|---|---|
| `name` | A string of 1 to 60 characters, with no whitespace but single spaces between words and no control characters | The location's name, written as the instance stores it. |

The list has at most 500 elements. A location's identity in a file is its name compared ignoring case (Unicode lower-casing). A file never holds two locations with the same identity: that is a new well-formedness rule, **`duplicate_location`**, which breaks the way `duplicate_lot` does. Two files hold the same collection (the format's "The same collection") only if, besides what version 1 requires, their locations are equal as sets of identities; `locations` is compared exactly as the file gives it otherwise.

A file carries no internal id for a location, and lots carry no reference to one in version 2. #45 will name a location from a lot by this name; a name that a collector later changes needs no repair in an old file, which is a snapshot.

The format's "Extending the format" steps apply: the document, `v2.schema.json`, valid and invalid examples (a collection with locations, an empty list, two names that differ only in case, a name with a tab, a double space or a control character, a name over 60 characters, more than 500 locations, `locations` missing in a version 2 file), comparison examples, the Coverage tables, the version history and the app's copy of the schema ([ADR 0021](../../adr/0021-export-format-rules-in-the-app.md); a second byte-identical copy, `v2.schema.json`).

### 10. The preview reads version 1 and version 2 (proposed)

Once the export writes version 2, a collector's own file would be refused by the shipped preview as "written by a newer version of Collector", which breaks the restore check this spec is meant to keep true. So the preview (spec 025) changes in the same pull request:

- It reads files of version 1 and of version 2, each against its own schema. A version above 2 is refused as newer ("This instance reads version 2." replaces "version 1").
- For a version 2 file, a problem in `locations` (a schema keyword failing under `/locations`, or `duplicate_location`) refuses the file as a whole, with the field named, like any problem outside `/lots/<row>` (spec 025 decision 10). No location rows are listed: a name is short and the fix is in the file.
- For a version 2 file the preview adds a **Locations** section after the lots' outcomes: how many locations applying would add, keep and remove, comparing names ignoring case, under the replace semantics of spec 025 decision 1, and the names of the ones it would remove. Nothing is applied.
- For a version 1 file the section says "This file was written before locations existed, so your locations would stay as they are." A version 1 file doesn't remove locations: it says nothing about them, and the format must not read a missing field as "none".

### 11. Applying a file's locations is left to the apply spec

This spec doesn't apply an import and doesn't edit spec 028. What it fixes, so that the two fit:

- **Version 2 file:** the apply step makes the account's locations equal the file's by name, ignoring case, adding the missing and removing the others, as the preview shows. Removing a location follows decision 3 (copies stay, in no location).
- **Version 1 file:** the apply step leaves the account's locations as they are.
- **Order of merging.** Whichever of specs 028 and 029 merges second reconciles the other: if 028 merges first and reads only version 1, a collector's version 2 export can't be applied until 029's work is added to it, and the preview says so by showing the Locations section; if 029 merges first, 028 reads versions 1 and 2 as decision 10 does. The coordinator tells 028's author.

### 12. Tenancy and the operator

Every query of locations goes through `Current.account` (multi-tenancy rule). An id in the URL that belongs to another account answers 404, the same as an id that doesn't exist. The admin pages never show or edit a location, its name or its count (hosted-door rule 2: a location's name describes the collection, so it is on the collector's side of the line).

## Supersedes

Earlier specs are frozen (maintainer ruling, 2026-10-15). What this spec changes in them and in the documents they feed is recorded here, not there; the specs index has the same entries.

| Earlier document | Item | What changes |
|---|---|---|
| [ADR 0020](../../adr/0020-export-format.md) | Consequences: "The spec that puts a lot in a location raises the format to version 2" | Locations (this spec) raise it to version 2; putting a lot in a location (#45) raises it to version 3 (decision 1). |
| [Spec 017](../017-export-format/spec.md) | Decision 14's last sentence ("the spec that puts a lot in a location (#45) therefore raises the format to version 2"); the Out of Scope line on locations | As above. Version 2 is defined by this spec; version 3 by #45's. |
| [Roadmap](../../roadmap.md) | Item 10 ("It raises the export format to version 2") and decision-log ruling 32 ("locations will make version 2") | Item 10 raises it to version 3; ruling 32 stands for the locations list. The roadmap file is edited in this spec's implementation pull request, not in this draft. |
| [Spec 022](../022-export-collection/spec.md) | The file it writes (format version 1) | The export writes version 2: the file gains `locations` (decision 2). The profile and lots are as before. |
| [Spec 025](../025-import-preview/spec.md) | Non-Goals ("any format but `collector-export` version 1"); Goals and Inputs (reads version 1, changes none of the format); decision 10's newer-version row ("This instance reads version 1"); the sentence that the spec changes no part of the format | The preview reads versions 1 and 2, refuses above 2, and adds the Locations section (decision 10). |
| [Spec 022](../022-export-collection/spec.md), [spec 026](../026-typed-entry/spec.md) | Decision 6's More rows, in order; spec 026's order of More's rows | More gains "Locations" before "Export collection" (decision 8): Signed in as, Locations, Export collection, Import collection, Add by number, then the admin links, then Sign out. |
| [Spec 004](../004-design-system-collection/spec.md), [spec 009](../009-card-scanner-confirm-flow/spec.md), [spec 023](../023-signed-out-catalog-browsing/spec.md) | The header's navigation for a collector (Collection, Search, Scan) | Gains "Locations" after "Scan" (decision 8). A visitor's header doesn't change. |
| [ADR 0021](../../adr/0021-export-format-rules-in-the-app.md) | The app holds one byte-identical copy of the schema | It holds one per version it reads (decision 9). The ADR's reasoning stands. |

## User Stories

### Story 1: See my locations and add one

**As a** signed-in collector
**I want** to give a new place a name
**So that** the app knows where I keep my collection

**Acceptance criteria:**

- [ ] **AC-1.1** Given a signed-in collector with no locations When they open the locations page Then it is titled "Locations", shows the empty state of decision 6, and has a name field and an "Add location" button.
- [ ] **AC-1.2** Given the locations page When the collector types "Blue binder" and activates "Add location" Then they are on the locations page (303), the page says "Added Blue binder.", the list holds "Blue binder", and the account has one location with that name.
- [ ] **AC-1.3** Given the name field with keyboard focus When the collector types a name and presses Enter Then the location is added, with no pointer used.
- [ ] **AC-1.4** Given locations "box", "Binder 2" and "Binder 10" When the page is shown Then they are listed as "Binder 10", "Binder 2", "box": by name ignoring case, then by the name itself, with no numeric ordering.
- [ ] **AC-1.5** Given a name of "  Blue   binder " When it is added Then the location's name is "Blue binder".
- [ ] **AC-1.6** Given a name that is empty or only whitespace When it is submitted Then nothing is added, the response is 422, and the page says "Give the location a name." beside the field.
- [ ] **AC-1.7** Given a name of 61 characters, and one of 60 When they are submitted Then the first adds nothing and says "Names can be at most 60 characters.", and the second is added.
- [ ] **AC-1.8** Given a name containing a control character that isn't whitespace (U+0000, or U+0007) When it is submitted Then nothing is added and the page says "Names can't contain control characters." And given a name with a tab between two words When it is added Then the tab has become one space (AC-1.5).
- [ ] **AC-1.9** Given a location "Blue binder" When the collector adds "blue BINDER" Then nothing is added, the response is 422, and the page says "You already have a location called “blue BINDER”." with the typed text kept.
- [ ] **AC-1.10** Given an account with 500 locations When the collector adds another Then nothing is added and the page says "You can have at most 500 locations."
- [ ] **AC-1.11** Given a name in a non-Latin script, such as "日本語のバインダー" When it is added Then it is stored and listed exactly as typed.
- [ ] **AC-1.12** Given scripting off When the collector adds a location Then it works through a full page load with the outcome of AC-1.2.

### Story 2: Rename a location

**As a** collector who made a typo, or reorganised
**I want** to change a location's name
**So that** the list says what the place is now

**Acceptance criteria:**

- [ ] **AC-2.1** Given a location "Blue binder" When the collector activates its Rename Then the edit page shows a name field holding "Blue binder", "Save" and "Cancel".
- [ ] **AC-2.2** Given the edit page When the collector changes the name to "Trade binder" and saves Then they are on the locations page (303), it says "Renamed Blue binder to Trade binder.", and the list holds "Trade binder" and not "Blue binder".
- [ ] **AC-2.3** Given a location "box" When the collector renames it to "Box" Then it is saved, with no duplicate-name error (decision 5).
- [ ] **AC-2.4** Given locations "Blue binder" and "Trade binder" When the collector renames "Trade binder" to "blue binder" Then nothing changes, the response is 422, and the edit page says "You already have a location called “blue binder”."
- [ ] **AC-2.5** Given the edit page When the name is empty, over 60 characters or holds a control character Then the reasons of AC-1.6–AC-1.8 are shown and the location keeps its name.
- [ ] **AC-2.6** Given a location When it is renamed to the name it already has Then the response is a redirect with no error.
- [ ] **AC-2.7** Given the edit page When the collector activates Cancel Then they are on the locations page and the name is unchanged.
- [ ] **AC-2.8** Given a rename When it is saved Then no lot of the account changes: their quantities, finishes, conditions, prices and times are the same as before.

### Story 3: Remove a location

**As a** collector who took a binder apart
**I want** to remove its location
**So that** the list only holds places I use

**Acceptance criteria:**

- [ ] **AC-3.1** Given a location "Blue binder" When the collector activates Remove Then a confirmation page asks "Remove Blue binder?" with a "Remove" button and a "Cancel" link, and nothing is removed yet.
- [ ] **AC-3.2** Given the confirmation page When the collector activates Remove Then they are on the locations page (303), it says "Removed Blue binder.", and the location is gone.
- [ ] **AC-3.3** Given the confirmation page When the collector activates Cancel Then they are on the locations page and the location is still there.
- [ ] **AC-3.4** Given an account with lots and a location When the location is removed Then the account's lots are unchanged: the same lots, each with the same quantity, finish, condition, price paid and times (decision 3).
- [ ] **AC-3.5** Given a removed location When its name is added again Then it is added as a new location, with no error.
- [ ] **AC-3.6** Given a request to remove a location that is already gone (a second tab, or a resubmitted request) When it arrives Then the answer is 404 and nothing else changes.
- [ ] **AC-3.7** Given a location removed after a page showed it When that page's rename link is followed Then the answer is 404.

### Story 4: Only my locations

**As a** collector on an instance with other accounts
**I want** my locations to be mine alone
**So that** nobody else sees or changes how I keep my collection

**Acceptance criteria:**

- [ ] **AC-4.1** Given accounts A and B, and a location of B's When A's collector requests that location's edit page, its removal page, a rename (PATCH) or a removal (DELETE) Then each answers 404 and B's location is unchanged.
- [ ] **AC-4.2** Given accounts A and B each with locations When A's collector opens the locations page Then it lists only A's, and an add or rename that uses a name B has succeeds for A.
- [ ] **AC-4.3** Given a request that carries an `account_id` parameter naming another account When a location is created Then the location belongs to the signed-in collector's account.
- [ ] **AC-4.4** Given a signed-out visitor, with the catalog open or not (spec 023) When they request any locations page or action Then they are sent to sign in and nothing about any location is shown.
- [ ] **AC-4.5** Given an admin When they open the admin users, catalog and jobs pages Then no location, name or count of locations appears on them.
- [ ] **AC-4.6** Given an account with locations When the account is deleted Then its locations are deleted with it.

### Story 5: Reach the page

**As a** collector
**I want** a way to the locations page from anywhere
**So that** I can name a place when I need one

**Acceptance criteria:**

- [ ] **AC-5.1** Given a signed-in collector on a wide screen When any collector page is shown Then the header's navigation reads Collection, Search, Scan, Locations, and Locations links to the locations page, marked as the current page while on it or its edit and removal pages.
- [ ] **AC-5.2** Given a signed-in collector at phone width When they open More Then its rows are: Signed in as, Locations, Export collection, Import collection, Add by number, the admin links for an admin, Sign out; and Locations opens the locations page.
- [ ] **AC-5.3** Given a signed-in collector at phone width When any tab bar page is shown Then the tab bar holds the same tabs as before (Collection, Search, Scan, More).
- [ ] **AC-5.4** Given a signed-out visitor to an open catalog (spec 023) When a catalog page is shown Then neither Locations nor any other collection link appears.
- [ ] **AC-5.5** Given the locations page at 360px wide and at desktop width, in both themes When it is shown Then it has no horizontal scrolling, every target is at least 44px on a touch device, and every control shows the focus ring.

### Story 6: My export carries my locations

**As a** collector
**I want** my export to include my locations
**So that** restoring it on another instance can bring them back

**Acceptance criteria:**

- [ ] **AC-6.1** Given an account with locations "Blue binder" and "Trade binder" and some lots When the collector exports their collection Then the file's `format_version` is 2, its `locations` is `[{"name": "Blue binder"}, {"name": "Trade binder"}]` in that order, and its `profile`, `currency` and `lots` are what version 1 wrote.
- [ ] **AC-6.2** Given an account with no locations When it exports Then the file is version 2 and `locations` is `[]`.
- [ ] **AC-6.3** Given locations "box", "Binder 2" and "Binder 10" When the account exports Then `locations` lists them in the order of AC-1.4.
- [ ] **AC-6.4** Given an export of any account When it is checked against `v2.schema.json` and the rules the schema can't state Then it is well-formed.
- [ ] **AC-6.5** Given an export file When it is read Then it holds no location id, account id or time for a location.
- [ ] **AC-6.6** Given two exports of one unchanged collection, made at different times When they are compared Then they are the same collection in the sense of the format (decision 9), and equal apart from `exported_at`.
- [ ] **AC-6.7** Given another account's locations When this account exports Then none of their names is in the file.

### Story 7: The format document, schema and Coverage cover locations

**As a** person writing a program that reads exports
**I want** the format document, the schema and the examples to define version 2
**So that** I can read a file without Collector

**Acceptance criteria:**

- [ ] **AC-7.1** **(review)** Given the format document When it is read Then it says version 2, describes `locations` and the `duplicate_location` rule, keeps version 1's definitions as they were, and its version history has a row for version 2 with its date and the sentence that putting lots in locations will raise it to 3.
- [ ] **AC-7.2** Given `v2.schema.json` When a file is checked Then a version 2 file with `locations` missing, not a list, over 500 elements, or holding a name that is empty, over 60 characters, padded with whitespace, or holding a tab, a run of two spaces or a control character is not well-formed, and `v1.schema.json` is unchanged.
- [ ] **AC-7.3** Given two locations whose names differ only in case When a file holds both Then it is not well-formed (`duplicate_location`), at the second one's pointer.
- [ ] **AC-7.4** Given the examples folder When the suite runs Then every valid example is well-formed under its own version's schema, every invalid example fails for exactly the reason `problems.json` gives, and the comparison examples hold or differ as they say, including version 2 files that differ in their locations.
- [ ] **AC-7.5** Given the database When the suite runs Then the Coverage tables list the `locations` table as exported, with a line for each column the table has, as the format's "Coverage" does for `lots` and `users` (the name exported, the internal ids and the times left out, any column derived from the name left out), and the suite fails when a table or a column is missing.
- [ ] **AC-7.6** Given the app's copy of each schema When the suite runs Then each is byte-identical to the file under `docs/export-format/` (ADR 0021).
- [ ] **AC-7.7** Given a collection exported by the app When it is read back through the format's rules Then its `locations` are well-formed under version 2, and the existing round trip still holds for lots.

### Story 8: Previewing a file that carries locations

**As a** collector
**I want** the import preview to understand my own export
**So that** I can check a file before it replaces my collection

**Acceptance criteria:**

- [ ] **AC-8.1** Given a collector's own version 2 export When they upload it to the import preview Then the file is read, not refused as newer.
- [ ] **AC-8.2** Given a version 2 file whose locations are "Blue binder", "Box" and "Trade binder", and an account holding "box" and "Old crate" When it is previewed Then the Locations section says 2 would be added, 1 kept and 1 removed, and names "Old crate" as the one removed; nothing is written.
- [ ] **AC-8.3** Given a version 2 file with `locations: []` and an account with 3 locations When it is previewed Then the section says all 3 would be removed, and lists them.
- [ ] **AC-8.4** Given a version 1 file When it is previewed Then the page says "This file was written before locations existed, so your locations would stay as they are." and shows no locations removed.
- [ ] **AC-8.5** Given a version 2 file with `locations` missing, not a list, or holding a name that is not well-formed, or two names equal ignoring case When it is previewed Then the preview refuses the file (422), names the field and the reason in the form of spec 025 decision 10, and shows no lots.
- [ ] **AC-8.6** Given a file whose `format_version` is 3 or higher When it is previewed Then it is refused as newer, and the page says "This instance reads version 2."
- [ ] **AC-8.7** Given a version 2 file When it is previewed Then the lot outcomes (added, changed, unchanged, held, removed), the profile notes and the problem rows are what spec 025 gives for a version 1 file with the same lots.
- [ ] **AC-8.8** Given a preview of any file When the page is shown Then no location, lot, user or other row was created, changed or removed.

## Functional Requirements

### FR-1: Locations

**Must:**
- Belong to one account, with a name that follows decision 5, unique within the account ignoring case.
- Be created, renamed and removed only through the locations pages, for the signed-in collector's account.
- Be removed without any effect on lots (decision 3).
- Be limited to 500 per account, and to names of 1 to 60 characters.

**Must not:**
- Carry an attribute besides the name (decision 4).
- Be reachable, listed or counted through any admin page.
- Be created, renamed or removed through the open catalog, or by a signed-out visitor.

### FR-2: The pages

**Must:**
- Answer a failed create or rename with 422 and the reason beside the field, and a successful one with a 303 redirect.
- Be linked as decision 8 says, work with scripting off, and work from 360px wide up.
- Use only the design system's tokens and classes.
- Name no collectible type in code or copy.

**Must not:**
- Remove a location on a GET request, or without the confirmation page.
- Take an account id from a form, or accept any id in the URL but the location's own.

### FR-3: The export

**Must:**
- Write version 2, with every location of the account and no other account's, in the order of decision 2.
- Write only the name of each location.

**Must not:**
- Change the profile, the currency, the lots or the way they are written.

### FR-4: The format

**Must:**
- Define version 2 in the format document, in `v2.schema.json`, in the examples and in the Coverage tables, in this pull request (the format's "Extending the format").
- Keep `v1.schema.json`, its examples and its meaning as they were.
- State the `duplicate_location` rule and the comparison of locations in "The same collection".

**Must not:**
- Give any file an internal id of the instance.
- Treat a missing `locations` in a version 1 file as an empty list.

### FR-5: The preview

**Must:**
- Read versions 1 and 2, each against its own schema, and refuse higher versions as newer.
- Show the Locations section for version 2, and the sentence of AC-8.4 for version 1.
- Refuse a version 2 file whose locations are not well-formed, as a whole.

**Must not:**
- Write anything.
- Apply, or promise to apply, locations (decision 11).

## Non-Functional Requirements

### Performance

- The locations page runs a fixed number of queries whatever the number of locations: one for the list. The export adds one query for the account's locations. The plan measures both with 500 locations and records the time in `verification.md`.
- The preview's time bar (30 s) and memory bar (500 MB) from spec 025 decisions 12 and 13 hold for a version 2 file of 50,000 lots and 500 locations.

### Security

- Every query of locations is scoped to `Current.account`; another account's location answers 404 (multi-tenancy rule).
- Strong parameters (`params.expect`). The name is the only permitted parameter; `account_id` is never mass-assigned.
- Names are output escaped like any other text; nothing about them is `html_safe`.
- Protect against forgery as every form does; remove and rename are not GETs.

### Reliability

- Create and rename keep the uniqueness rule in the database as well as in the model, so two requests racing to add one name leave one location and one clean error. The race loses with the same message as AC-1.9.
- The migration is safe to run unattended from any prior version: it adds a table and changes nothing else.

### Cost per account (hosted-door rule 4)

At most 500 locations of about 100 bytes: about 50 KB of storage and about 20 KB in an export (decision 7). No background work, no cache entry and no job.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Name blank | 422, "Give the location a name." (AC-1.6) |
| Name over 60 characters | 422, "Names can be at most 60 characters." (AC-1.7) |
| Name has a control character | 422, "Names can't contain control characters." (AC-1.8) |
| Name equal to another location's, ignoring case | 422, "You already have a location called “<name>”." (AC-1.9, AC-2.4) |
| 501st location | 422, "You can have at most 500 locations." (AC-1.10) |
| Two requests add one name at once | One location; the second answers like AC-1.9 |
| Location of another account, or already removed | 404, nothing changes (AC-4.1, AC-3.6) |
| Signed-out visitor | Sent to sign in (AC-4.4) |
| Version 2 file with bad or duplicate locations | Preview refuses the whole file (AC-8.5) |
| File of version 3 or higher | Preview refuses it as newer (AC-8.6) |
| Version 1 file | Previewed; locations untouched (AC-8.4) |

## Open Questions

Decisions 1–4 are the maintainer's. Nothing else blocks the plan.

1. **Decision 1.** Is locations alone version 2 and #45 version 3 (recommended), or does #45 amend version 2 before it is released?
2. **Decision 10 and 11.** Does the preview read versions 1 and 2 in this pull request, with applying left to spec 028 (recommended)? Spec 028's author must be told how it reads version 2.
3. **Decision 3.** Does removing a location leave its copies owned and in no location (recommended), or refuse while it holds lots?
4. **Decision 4.** Is a location a name only (recommended), or does it carry a kind now?
5. **Non-blocking, proposed.** The limits of 500 locations and 60 characters (decision 7), the navigation placement (decision 8), and that no new ADR is needed (ADR 0021's mechanism extends to a second schema; ADR 0020 already allows the bump).

## Out of Scope (Future Considerations)

- Putting lots in locations, and the ADR that decides how a lot sits in more than one place (#45; format version 3).
- Per-location counts and the location on tiles and rows (#46), filtering (#47), "Move to…" (#48), decks (#49), "Free to use" (#50), and choosing a location in typed entry (#51) or at the scanner (#56).
- A kind, notes, order or nesting of locations.
- Applying an imported file's locations (spec 028 / issue #40).
- Each collector choosing and reordering their navigation sections.

## Documents that change

- `docs/export-format/README.md`: version 2, the `locations` section, `duplicate_location`, "The same collection", the Coverage tables (the `locations` table and its columns), the version history and the Examples section's rule list.
- `docs/export-format/v2.schema.json` and its examples (valid, invalid with `problems.json`, comparison); `app/models/export_format/v2.schema.json`, byte-identical.
- `docs/roadmap.md`: item 9 marked done with the spec and the PR; item 10's version note changed to 3.
- `docs/design-system/`: a doc for the locations page's new pattern under `components/`, listed in the README's app additions; the Navigation list if the header's links change.
- `docs/architecture/`: the area docs for collection and lots and for data portability, once they exist (spec 027); until then `CLAUDE.md` gains a line on locations and the export's version 2.
- `docs/specs/README.md`: this spec's row, with the supersessions above.
- `README.md`: if it describes the export's version or the navigation.
