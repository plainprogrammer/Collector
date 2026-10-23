# Feature 029: Manage Locations

**Status:** Approved by the maintainer (2026-10-20), with rulings on every decision and on the details P1–P8 (P1 as the lenient alternative: a name in a file that isn't in NFC is well-formed and is normalised on read). No question is open
**Version:** 1.3.2
**Created:** 2026-10-20
**Last Updated:** 2026-10-21
**Depends on:** [spec 028](../028-apply-import/spec.md) (apply an import, issue #40), which has merged (PR #120, `5cca2fb`; its plan retired in PR #121). The plan cites 028 as merged (v1.3.4) and records, for each citation, whether it is still true and the class, method or number now behind it
**Branch:** `029-manage-locations`
**Issue:** [#44](https://github.com/plainprogrammer/Collector/issues/44)
**Plan:** [plan.md](plan.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.3.2 | 2026-10-21 | PATCH, from the independent plan review (`plan-review.md`) and the maintainer's rulings of 2026-10-21, each **ruled**: (1) decision 11's fingerprint holds, for a renamed location, its current name and the file's name, and for a removed location, its name, **not its id** (the apply re-reads the held locations inside its transaction, so the id adds no safety), so AC-9.9 holds as written for every case, including a renamed or removed location deleted and added again with the same spelling; (2) the notice never ends with a period, for every file, as spec 028's does: AC-9.14's example loses its final period, a location part with a zero count is left out, a lot count that is zero stays, as in 028; (3) AC-9.15 holds once the example's location names are normalised to NFC (decision 5: the export writes NFC), so the NFD example is compared after each name passes through the name function. No other behaviour changes |
| 1.3.1 | 2026-10-21 | PATCH, clarifications only (no behaviour changes), made when the plan re-read spec 028 as merged (v1.3.4): the dependency header now says 028 merged at `5cca2fb` instead of "approved at `87308d5`" and "being revised"; decision 11's working-state paragraph and the Supersedes row quote 028 decision 7 as merged ("whenever the apply writes", which also cleared for a view-only apply) instead of the earlier "whatever the plan"; AC-9.16 names 028's merged bars (30 seconds, write transaction under 4 seconds, 500 MB) instead of "as 028 states them when it merges"; the Documents list no longer names `name_not_nfc`, which 1.3.0 removed; the Plan line links the plan |
| 1.3.0 | 2026-10-20 | The maintainer ruled P1–P8. P1 **changed** from the proposal: a v2 name that isn't in NFC is well-formed, not refused; the import preview and apply NFC-normalise names on read and then trim and collapse White_Space exactly as typing does (one function, decision 5), before matching, comparing, judging duplicates and storing. The `name_not_nfc` rule, its refusal and AC-9.18's refusal are gone; duplicates are judged after normalisation and case folding, so an NFD and an NFC spelling of one name in one file are a duplicate; "the same collection" still compares names as written, exactly. P2–P8 confirmed as proposed. All decisions are ruled and Open Questions is empty |
| 1.2.0 | 2026-10-20 | From the independent review (Opus; each finding and its resolution in `review.md`) and the maintainer's rulings of the same day. Ruled: decision 2 (always write version 2) and decision 7's limits (500 locations, 60 characters); the additions under decisions 10 and 11 (the Renamed outcome, a location-only plan being applicable and stored, the apply's checkbox covering removed locations); a location-only apply clears no working state (decision 11, AC-9.17); "the same collection" compares location names exactly, while uniqueness and matching ignore case (decision 9); names are NFC-normalised, Unicode White_Space is trimmed and collapsed, Cc and Cf are refused, length is 1–60 code points, case is compared by Unicode case folding, and the schema and the model must agree, proved by a parity spec (decisions 5 and 9, AC-7.8); one pull request (decision 13); a new ADR, not an amendment (decision 1). Status line and decision labels now say only what was ruled; the review's other fixes are *proposed* P1–P8 (the coordinator agreed; the maintainer confirms at plan review). Supersedes gains spec 025 AC-3.2, spec 017 AC-3.3 and the format document's version sentence; the ADR 0021 row is dropped |
| 1.1.0 | 2026-10-20 | Approved by the maintainer. Decision 1 ruled as recommended (this spec is format version 2, #45 version 3); decision 3 ruled as recommended; decision 4 ruled as recommended; the draft's decision 11 (applying locations left to spec 028) is reversed: spec 028 (apply an import) merges first, so this spec owns the preview *and the apply* of version 2 locations (decisions 10 and 11, Story 9), and the apply's plan, fingerprint and confirmation cover locations. No open questions remain |
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
- The import preview and the apply (spec 028) read a file that carries locations, and a file written before locations existed, so a collector can always preview and apply their own export. Applying a version 2 file makes the collector's locations the file's; applying a version 1 file leaves them alone.
- What removing a location does to the copies it holds is decided now (decision 3), so that #45 builds on a settled rule.
- The cost per account is stated (hosted-door rule 4).

## Non-Goals

- Putting a lot, or some of its copies, in a location (#45, which also decides how a lot sits in more than one place; ADR 0019's open question).
- Showing a location on tiles and rows, filtering by location, "Move to…", decks, "Free to use", and choosing a location in typed entry or at the scanner (#46–#51, #56).
- A kind of location (binder, box, deck) or any other attribute besides the name (decision 4).
- Ordering locations by hand, nesting them, or giving them notes, photos or labels.
- Changing how spec 028's apply stores, fingerprints or sequences an upload beyond what locations need (decision 11).
- A per-collector choice of which sections the navigation shows (design system, Navigation: "will be able to").
- Counting lots or copies per location (nothing can be in one yet).

## Users and Context

**Primary users:** a signed-in collector who keeps cards in binders, boxes and the like and wants the app to know their names before putting anything in them.
**Usage context:** setting up an instance for a family's collection, where a dozen to a few hundred places are named up front, then occasionally renamed or retired.
**User mental model:** "The blue binder, the long box on the shelf, the trade binder. Add them, fix a typo, drop the one I took apart."

## Decisions

Rulings of 2026-10-20: decisions 1, 3 and 4 as recommended; spec 028 merges first (decision 11); then, after the independent review, decision 2 and decision 7's limits confirmed; the additions under decisions 10 and 11 confirmed; a location-only apply clears no working state; the comparison rules of decisions 5 and 9; one pull request; a new ADR; and P1–P8, P1 as the lenient alternative (names in files are normalised on read), P2–P8 as proposed. The choices of decisions 6 and 8 (the `/locations` page, the edit and confirmation pages, a header link and a More row, no new tab) stand. The alternatives named were put to the maintainer.

### 1. Locations alone raise the export format to version 2 (ruled)

[ADR 0020](../../adr/0020-export-format.md) and the format document's "Versions" section say the version goes up for "a new field that holds data the collector owns", and spec 017 decision 14 gave the reason: a version-1 reader ignores fields it doesn't know, so it would drop a collector's locations without a word. The set of locations is such a field. So this spec, not only #45, changes the format:

- The format becomes **version 2**: a new required top-level field `locations`, a list of objects with one field, `name` (decision 9 gives its shape). Lots are unchanged in version 2.
- A new schema file, `v2.schema.json`, states version 2. `v1.schema.json` stays, because version 1 files exist and the meaning of a released version never changes.
- The Coverage tables gain the new table's row and columns (the suite fails until they are listed).

**Ruling, and what it does to #45.** #45 records which location each lot's copies are in. That is a further change to data the collector owns, so it raises the format again, to **version 3**. The statements that said "#45 raises the format to version 2" (ADR 0020's consequences, spec 017 decision 14, the roadmap's item 10, the format document's version history) are superseded by this spec; see Supersedes.

The alternative not chosen: ship version 2 here and let #45 change version 2 before any release carries it. It saves a version number. It is fragile: `main` publishes `edge` images, so a collector can hold a version 2 file the day this merges, and the format's rule is that a released version never changes. Whether a file counts as released is not something the format can know.

What does *not* need a bump: nothing else in this spec adds data. The locations page itself changes no file.

**Expected ADR (ruled).** A new ADR, written with the plan and numbered then (the next free number on `origin/main`), records "locations are format version 2; lots in locations are version 3". It supersedes the part of [ADR 0020](../../adr/0020-export-format.md) whose Consequences say the spec that puts a lot in a location raises the format to version 2, as `docs/adr/README.md` asks (a new ADR, not an amendment). ADR 0020's Status line gets a pointer to it, and the ADR index a line.

### 2. The export always writes the newest version (ruled)

**Ruling (maintainer, 2026-10-20).** An export is written in version 2, with `locations` present and empty for an account with none. It does not fall back to version 1 for an account without locations: one shape is simpler to read and to test, and the file says what it is. The cost, accepted: an instance that reads only version 1 can't read the new instance's exports (the file says it is newer, as the format requires).

*Ruled (P2).* Locations are written, and listed on the locations page, in the order of their comparison key (decision 5, the case-folded NFC name), then by the name itself, both in code-point order, not by locale collation. The format gives the order no meaning; a fixed order makes two exports of one collection byte-identical apart from their time.

### 3. Removing a location never removes copies (ruled)

**Ruling.** Removing a location does not delete, change or merge any lot. The copies it held stay owned and are then in no location. Removing goes through a confirmation page, which states how many lots are in the location once #45 can put them there (the count arrives with #45). In this spec no lot can be in a location, so the page says only which location is removed.

This binds #45: whichever way its ADR divides a lot among places, deleting a location sets its copies back to "no location" and nothing else.

Alternatives not chosen: (a) refuse to remove a location while it holds lots, so the collector moves them first. That needs "Move to…" (#48, item 13) to exist before a location can be retired, and a collector who takes a binder apart would have to move every lot out by hand. (b) Delete the lots with the location, rejected: nothing a collector does to a place should delete what they own.

### 4. A location is a name (ruled)

A location has one attribute, its name. It has no kind (binder, box, deck). Decks as locations is issue #49 and may need more than a kind (the design system says a copy in a deck isn't free for another deck); settling a vocabulary now would guess at it. If #49 adds a kind, it is data the collector owns, so it raises the format again; that cost is accepted, as it is for every later field.

The alternative not chosen: ship a `kind` now to avoid a later format change. It adds a vocabulary to decide (comics have long boxes and short boxes), a field in every form and in the file, and nothing the collector can do with it before #46.

### 5. Names (ruled)

**Ruling (maintainer, 2026-10-20).** A name is what the collector types, made into one form:

1. It is normalised to Unicode **NFC**.
2. Characters with the Unicode **White_Space** property (tab, newline, no-break space, U+0085, U+2028, U+3000 and the rest of that property) at its start and end are removed, and each run of them inside becomes one space (U+0020).
3. A character in general category **Cc** or **Cf** that is left (U+0000, U+0007, U+200B, U+200E, U+FEFF…) refuses the name. Tab, newline and U+0085 are White_Space and so were already collapsed in step 2.
4. It is **1 to 60 Unicode code points** after that (so 60 characters of any script, whatever their bytes; a grapheme of several code points counts each).
5. Any other character is allowed, in any script.

Two names are **the same** when their **comparison keys** are equal: the key is the Unicode full case folding of the normalised name (so an NFC and an NFD spelling of one name have one key). No two of an account's locations share a key ("Blue binder" and "blue binder" are one name, and so are "Straße" and "STRASSE"). Renaming a location to a name with its own key ("box" to "Box") is allowed. The key is for uniqueness and matching only; it is never shown and never in a file.

An account has at most 500 locations (decision 7).

This is one function, **normalising a name** (steps 1 and 2), used for what a collector types and for what the import preview and apply read from a file (decision 9). Its result must then pass steps 3 to 5. The character sets are the same in the model, in the format document and in `v2.schema.json`; decision 9 says how a well-formed name in a file relates to the model, and a parity spec proves it (AC-7.8).

### 6. The page, its routes and its words (ruled)

The locations page is `GET /locations`: a heading "Locations", a one-field form (name, "Add location"), and the account's locations as a list, in the order of decision 2, each with a Rename and a Remove action. Rename opens `GET /locations/:id/edit`, a page with the name field, "Save" and "Cancel". Remove opens `GET /locations/:id/removal/new`, a confirmation page in the style of removing copies (`ConfirmPage`): "Remove <name>?", a "Remove" button and "Cancel". Creating is `POST /locations`, renaming `PATCH /locations/:id`, removing `DELETE /locations/:id`. A successful create, rename or remove redirects (303) to the locations page and says what happened, quoting the normalised name ((ruled, P4): "Added “Blue binder”.", "Renamed “Blue binder” to “Trade binder”.", "Removed “Blue binder”.". A failed create or rename answers 422 with the reason beside the name field and the typed text kept.

The page works without scripting. It follows the design system's tokens and `c-*` classes; its new pattern, if any, gets a doc under `docs/design-system/components/` and a line in the README's app additions, as specs 025 and 026 did. Its empty state says what to do next: "No locations yet. Add a binder or a box to start recording where things are kept." The copy names no collectible type.

### 7. The cost is bounded: 500 locations of 60 code points (ruled)

**Ruling (maintainer, 2026-10-20).** An account has at most 500 locations and a name is at most 60 code points. A location is one row: its name (at most 240 bytes of UTF-8), the comparison key (at most as long again, more after folding) and its index entry, so at most about 1 KB, and the 500 locations at most about 0.5 MB per account; an export carries only the names, at most about 130 KB ((ruled, P8, the worst case where the typical name of 20 Latin characters is under 100 bytes). No background work. The limits are in the format as well (decision 9), as the quantity limit of 1 to 9,999 already is. They are a ceiling for a hosted instance, not a number a collector should meet: a few hundred places already describes a very large collection. A request over the limit is refused with "You can have at most 500 locations."

### 8. How the page is reached (ruled)

[Design system](../../design-system/README.md), Navigation: Collection, Decks, Locations and Wishlist are the default sections; wide screens show them in the header; the tab bar holds five at most and "a new section starts in More". So:

- Wide screens: "Locations" in the header's navigation, after "Scan".
- Phones: a "Locations" row in More, before "Export collection". The tab bar doesn't change, and on the locations pages no tab is marked current, as on every page More leads to ((ruled, P5).
- Not in the account menu (the menu is for the profile, import and export).

The alternative not chosen: a fifth tab. It is allowed by count, but the rule says new sections start in More.

### 9. The shape of the format's version 2 (ruled in part)

`locations` is a required top-level field, a list that may be empty, in no meaningful order. Each element is an object with one field:

| Field | Value | Meaning |
|---|---|---|
| `name` | A string of 1 to 60 Unicode code points, with no character of general category Cc or Cf, no White_Space character other than single U+0020 between words, and none at its start or end | The location's name. Collector writes it as it stores it, in NFC (decision 5). A file written by another program may hold it in another normalisation form. |

The list has at most 500 elements.

- **Identity and `duplicate_location`.** A location's identity in a file is its comparison key (decision 5), worked out from the name after normalisation and case folding. A file never holds two locations with the same identity, so an NFC and an NFD spelling of one name, or "Straße" and "STRASSE", are a duplicate: that is a new well-formedness rule, **`duplicate_location`**, at the pointer `/locations/<i>` of the later one, as `duplicate_lot` is at `/lots/<i>`.
- **Normalisation form (ruled, P1).** A name in a file need not be in NFC: the form is not part of well-formedness, because a schema can't state it, and a hand-edited file may hold an NFD name. A reader **normalises each name on read** (decision 5's function: NFC, then trim and collapse White_Space, which does nothing to a well-formed name's spaces) before it matches, compares, judges duplicates or stores. So an NFD "Café" in a file is, to the preview and the apply, the NFC "Café". A writer that wants a stable file writes NFC; Collector does.
- **The schema agrees with the model.** `v2.schema.json` states the name by `type`, `minLength`, `maxLength` and a `pattern` in the ECMA-262 syntax that `ExportFormat::Rules` already applies (`regexp_resolver: "ecma"`), and the list by `maxItems`. The relation is: (a) every name the model stores is well-formed, as written; and (b) for every well-formed name, the model accepts its normalised form, except the rare name whose normalised form is longer than 60 code points (a few characters, such as U+0344, decompose to two), which the preview and apply refuse as a whole as "locations.N.name isn't valid" (an accepted limit). A spec proves (a) and (b) by trying every Unicode scalar value (AC-7.8). The format document states the same sets and the normalisation in words, so that a program in any language can read a file.
- **The same collection** (the format's "The same collection", **ruled 2026-10-20**). Besides what version 1 requires, two files hold the same collection only if their locations are equal as sets of names compared **exactly, character for character, as written** in the files, without normalising either, as the format compares everything else (a file is judged as it is). Files that Collector writes are in NFC, so for them this is the plain comparison of names. The comparison key is used for `duplicate_location` and for matching a held location to the file's in an apply (decision 10), never for "same". So "box" and "Box" are different collections, and an apply of one to an account restored from the other renames.

A file carries no internal id for a location, and lots carry no reference to one in version 2. #45 will name a location from a lot by this name; a name that a collector later changes needs no repair in an old file, which is a snapshot.

The format's "Extending the format" steps apply: the document (including its sentence in "Versions" that locations will add where each lot is kept and raise the version to 2, which is rewritten), `v2.schema.json`, valid and invalid examples (a collection with locations, an empty list, two names that differ only in case, a pair that differs only by full case folding, a name with a tab, a double space, a control character, a Cf character, a no-break space, U+3000, U+0085 or U+2028, a name in NFD (well-formed, and a duplicate of its NFC spelling when both are present), a name of 60 and one of 61 code points, 500 and 501 locations, `locations` missing in a version 2 file), comparison examples (names differing only in case differ; the same names reordered are the same; a different set differs), the Coverage tables, the version history and the app's copy of the schema ([ADR 0021](../../adr/0021-export-format-rules-in-the-app.md): a second byte-identical copy, `v2.schema.json`).

### 10. The preview and the apply read versions 1 and 2 (ruled; the additions confirmed 2026-10-20)

Once the export writes version 2, a collector's own file would be refused by the shipped preview as "written by a newer version of Collector", which breaks the restore check this spec is meant to keep true. And spec 028 merges before this spec (decision 11), so its apply already exists and reads version 1 only. So this spec changes the preview (spec 025) and the apply (spec 028) in the same pull request:

- **Versions.** Both read files of version 1 and of version 2, each against its own schema. A version above 2 is refused as newer ("This instance reads version 2." replaces "version 1").
- **A bad `locations` refuses the file.** For a version 2 file, a problem in `locations` (a schema keyword failing under `/locations`, or `duplicate_location`) refuses the file as a whole, with the field named, like any problem outside `/lots/<row>` (spec 025 decision 10). No location rows are listed: a name is short and the fix is in the file. *Ruled (P6):* a duplicate reads "locations.1 has the same name as an earlier location, ignoring case"; every other location problem keeps the generic "locations.N.name isn't valid" (`required` reads "is missing").
- **Version 2: replace by name.** Under the replace semantics of spec 025 decision 1, the collector's locations become the file's, matched by comparison key (decision 5), each file name first normalised on read (decision 9). Each location has one outcome:

| Outcome | When | Applying does |
|---|---|---|
| **Added** | The file has a location whose key no held location has. | Creates it. |
| **Renamed** | A held location has the file's key but not exactly the file's name ("box" and "Box"). | Gives that location the file's spelling. Its id stays, so anything that points at it stays pointed. |
| **Unchanged** | A held location has exactly the file's name (after normalisation). | Writes nothing, not even its `updated_at`. |
| **Removed** | A held location whose key no location in the file has. | Deletes it, by decision 3 without touching any lot. |

- **Version 1: locations stay.** A version 1 file says nothing about locations, and the format must not read a missing field as "none". The preview says "This file was written before locations existed, so your locations would stay as they are." and applying changes none.
- **The Locations section.** For a version 2 file the preview adds it after the lots' outcomes: the counts of added, renamed, unchanged and removed locations, and the names of the renamed and the removed, shown as the lots' lists are, the first 100 and then "and N more" ((ruled, P3; spec 025 decision 11).
- **Nothing to change** (spec 028, where an apply with nothing to change is refused with a 422 and clears nothing) now means a plan with no added, changed or removed lot, no added, renamed or removed location, and no view change. A file whose only change is a location is applicable, is stored, and can be applied.

### 11. Spec 029 depends on spec 028 and extends its apply (ruled; the additions confirmed 2026-10-20)

The maintainer ruled on 2026-10-20 that [spec 028](../028-apply-import/spec.md) (apply an import, issue #40; approved) merges before this spec, reversing the draft's order. So this spec depends on it: its plan starts from `main` after 028 has merged, and it builds on 028's `POST /collection/import`, its stored upload, its single all-or-nothing write transaction and its plan fingerprint. This spec does not edit spec 028; what it changes in it is recorded in Supersedes and in the specs index.

What applying locations adds to 028, with 028's own rules otherwise unchanged:

- **One transaction.** The location writes (create, rename, delete) are made in 028's one write transaction, with the lot writes. Either every change is made or none is (spec 028 AC-2.1). The parse and the resolve of the file stay outside it.
- **The plan and the fingerprint cover locations** (spec 028 decision 2). The fingerprint adds, for every added location, its name; for every renamed location, its current name and the file's name, and for every removed location, its name (not its id: the apply re-reads the held locations inside its transaction, so an id adds nothing; ruled 2026-10-21); so a location added, removed or respelled (including a change of case alone, which turns an unchanged location into a renamed one) between the preview and the apply makes the plan differ and the apply is refused with a fresh preview (409). A location, added, renamed or removed, deleted and added again with the same spelling changes nothing in the fingerprint, because the plan doesn't change and the fingerprint holds no id (AC-9.9).
- **Confirmation (confirmed 2026-10-20).** 028's checkbox, "I understand this removes N lots", is required when the plan removes lots or locations, and reads "I understand this removes N lots and M locations" (or only the part that applies). Removing a location keeps its copies (decision 3), but under #45 it forgets where they were, and no apply has an undo.
- **Idempotent.** Applying the same file twice leaves the locations as the first application did, and writes nothing the second time (spec 028 AC-2.2).
- **Tenancy.** Locations are read and written through `Current.account` only (spec 028 Story 4).
- **A version 1 file** leaves the account's locations untouched, in the preview, the fingerprint and the apply.
- **Working state (ruled, 2026-10-20).** Spec 028 decision 7 clears the number-entry list, the scanner sitting, the bulk selections and bulk removals' undo because lots they point at are replaced. An apply that writes no lot clears none of them. So a location-only apply (and a view-only one) leaves them alone, and the clearing happens when the apply writes lots. This narrows 028 decision 7 as merged ("whenever the apply writes", so a view-only apply cleared them too; AC-9.17).
- **The round trip.** Spec 028's round-trip specs (its Story 6) gain locations: an export of a collection with locations, applied to an empty account on the same catalog, restores the same locations (AC-9.5).

### 12. Tenancy and the operator (follows from the tenancy rules)

Every query of locations goes through `Current.account` (multi-tenancy rule). An id in the URL that belongs to another account answers 404, the same as an id that doesn't exist. The admin pages never show or edit a location, its name or its count (hosted-door rule 2: a location's name describes the collection, so it is on the collector's side of the line).

### 13. One pull request (ruled)

The maintainer ruled on 2026-10-20 that the work stays in one pull request: the pages, the navigation, format version 2 with its schema and examples, the export, and the preview's and apply's reading of version 2. "Export covers it" and "leave `main` releasable" couple them: once the export writes version 2 the preview and the apply must read it. The alternative not chosen: ship version 2, its readers and an export that writes `locations: []` first as an enabling slice, and the pages and the table after. The spec's size (nine stories) is accepted.

## Supersedes

Earlier specs are frozen (maintainer ruling, 2026-10-15). What this spec changes in them and in the documents they feed is recorded here, not there; the specs index has the same entries.

| Earlier document | Item | What changes |
|---|---|---|
| [ADR 0020](../../adr/0020-export-format.md) | Consequences: "The spec that puts a lot in a location raises the format to version 2" | Locations (this spec) raise it to version 2; putting a lot in a location (#45) raises it to version 3. Recorded in a new ADR that supersedes this part of ADR 0020 (decision 1); ADR 0020 is not edited by this spec. |
| [Spec 017](../017-export-format/spec.md) | Decision 14's last sentence ("the spec that puts a lot in a location (#45) therefore raises the format to version 2"); AC-3.3's expectation that locations "will raise" the version and its version-history sentence; the Out of Scope line on locations | As above. Version 2 is defined by this spec; version 3 by #45's. The format document's sentence "Locations will add where each lot is kept … raise the version to 2" is rewritten (decision 9). |
| [Roadmap](../../roadmap.md) | Item 10 ("It raises the export format to version 2") and decision-log ruling 32 ("locations will make version 2") | Item 10 raises it to version 3; ruling 32 stands for the locations list. The roadmap file is edited in this spec's implementation pull request, not in this draft. |
| [Spec 022](../022-export-collection/spec.md) | The file it writes (format version 1) | The export writes version 2: the file gains `locations` (decision 2). The profile and lots are as before. |
| [Spec 025](../025-import-preview/spec.md) | Non-Goals ("any format but `collector-export` version 1"); Goals and Inputs (reads version 1, changes none of the format); AC-3.2 (a version 2 file is refused as newer); decision 10's newer-version row ("This instance reads version 1"); the sentence that the spec changes no part of the format | The preview reads versions 1 and 2, refuses above 2, and adds the Locations section (decision 10). |
| [Spec 028](../028-apply-import/spec.md) | Inputs and Non-Goals (reads format version 1 only; "Format. Version 1, unchanged"); Terms (the plan, "nothing to change"); decision 2 (what the fingerprint covers); decision 5 (replace, exactly: lots and the profile only); decision 6 (the checkbox "removes N lots"); decision 7 and AC-1.8 (clearing working state "whenever the apply writes": now only when the apply writes lots); decision 11 and the notice's counts ("Imported: 3 lots added, 2 changed, 1 removed"); Story 6's round trip | Applying reads versions 1 and 2. The plan, the fingerprint, the confirmation, the single transaction and the notice cover locations, and the round trip includes them (decisions 10 and 11, Story 9). Nothing else in 028 changes: its stored upload, expiry, sweep, the working state it clears when it writes lots, and its bars stand. This spec depends on 028 merging first. |
| [Spec 022](../022-export-collection/spec.md), [spec 026](../026-typed-entry/spec.md) | Decision 6's More rows, in order; spec 026's order of More's rows | More gains "Locations" before "Export collection" (decision 8): Signed in as, Locations, Export collection, Import collection, Add by number, then the admin links, then Sign out. |
| [Spec 004](../004-design-system-collection/spec.md), [spec 009](../009-card-scanner-confirm-flow/spec.md), [spec 023](../023-signed-out-catalog-browsing/spec.md) | The header's navigation for a collector (Collection, Search, Scan) | Gains "Locations" after "Scan" (decision 8). A visitor's header doesn't change. |

## User Stories

### Story 1: See my locations and add one

**As a** signed-in collector
**I want** to give a new place a name
**So that** the app knows where I keep my collection

**Acceptance criteria:**

- [ ] **AC-1.1** Given a signed-in collector with no locations When they open the locations page Then it is titled "Locations", shows the empty state of decision 6, and has a name field and an "Add location" button.
- [ ] **AC-1.2** Given the locations page When the collector types "Blue binder" and activates "Add location" Then they are on the locations page (303), the page says "Added “Blue binder”.", the list holds "Blue binder", and the account has one location with that name.
- [ ] **AC-1.3** Given the name field with keyboard focus When the collector types a name and presses Enter Then the location is added, with no pointer used.
- [ ] **AC-1.4** Given locations "box", "Binder 2", "Binder 10", "Éclair" and "eclair" When the page is shown Then they are listed as "Binder 10", "Binder 2", "box", "eclair", "Éclair": by comparison key then by the name, both in code-point order, with no numeric ordering and no locale collation (decision 2, P2).
- [ ] **AC-1.5** Given a name of "  Blue   binder ", and one with a no-break space, a U+3000 or a tab between its words When each is added Then the location's name is "Blue binder" with one ordinary space (decision 5, steps 1–2).
- [ ] **AC-1.6** Given a name that is empty or only whitespace When it is submitted Then nothing is added, the response is 422, and the page says "Give the location a name." beside the field.
- [ ] **AC-1.7** Given a name of 61 code points, and one of 60 When they are submitted Then the first adds nothing and says "Names can be at most 60 characters.", and the second is added; and given 60 CJK characters (180 bytes of UTF-8) Then it is added, and 61 is refused.
- [ ] **AC-1.8** Given a name containing a character of category Cc or Cf that isn't White_Space (U+0000, U+0007, U+200B, U+200E or U+FEFF) When it is submitted Then nothing is added and the page says "Names can't contain control characters."; and given a name with a character of White_Space (a tab, U+0085 or U+2028) between two words Then it is added with one space (AC-1.5).
- [ ] **AC-1.9** Given a location "Blue binder" When the collector adds "  blue   BINDER " Then nothing is added, the response is 422, and the page says "You already have a location called “blue BINDER”." (the normalised name), with the typed text kept; and given a location "Straße" Then adding "STRASSE" is refused the same way (decision 5, case folding).
- [ ] **AC-1.10** Given an account with 500 locations When the collector adds another Then nothing is added and the page says "You can have at most 500 locations."
- [ ] **AC-1.11** Given a name in a non-Latin script, such as "日本語のバインダー" When it is added Then it is stored and listed exactly as typed; and given "Cafe" with a combining acute (U+0301) Then it is stored as "Café" in NFC, and typing "Café" in NFC afterwards is refused as the same name.
- [ ] **AC-1.12** Given scripting off When the collector adds a location Then it works through a full page load with the outcome of AC-1.2.
- [ ] **AC-1.13** Given an account with 499 locations When two add requests with different names arrive together Then exactly one is added, the account holds 500, and the other gets the message of AC-1.10 (the cap holds under a race).
- [ ] **AC-1.14** Given a request without the `location` parameter When it is posted Then the answer is 400 and nothing is added.

### Story 2: Rename a location

**As a** collector who made a typo, or reorganised
**I want** to change a location's name
**So that** the list says what the place is now

**Acceptance criteria:**

- [ ] **AC-2.1** Given a location "Blue binder" When the collector activates its Rename Then the edit page shows a name field holding "Blue binder", "Save" and "Cancel".
- [ ] **AC-2.2** Given the edit page When the collector changes the name to "Trade binder" and saves Then they are on the locations page (303), it says "Renamed “Blue binder” to “Trade binder”.", and the list holds "Trade binder" and not "Blue binder".
- [ ] **AC-2.3** Given a location "box" When the collector renames it to "Box" Then it is saved, with no duplicate-name error (decision 5).
- [ ] **AC-2.4** Given locations "Blue binder" and "Trade binder" When the collector renames "Trade binder" to "blue binder" Then nothing changes, the response is 422, and the edit page says "You already have a location called “blue binder”."
- [ ] **AC-2.5** Given the edit page When the name is empty, over 60 characters or holds a control character Then the reasons of AC-1.6–AC-1.8 are shown and the location keeps its name.
- [ ] **AC-2.6** Given a location When it is renamed to the name it already has Then the response is a redirect with no error.
- [ ] **AC-2.7** Given the edit page When the collector activates Cancel Then they are on the locations page and the name is unchanged.
- [ ] **AC-2.8** Given a rename When it is saved Then no lot of the account changes: their quantities, finishes, conditions, prices and times are the same as before.
- [ ] **AC-2.9** Given two tabs that open the edit page of one location When each saves a different name, one after the other Then both succeed and the later name stands (last write wins), unless it is another location's name (AC-2.4).
- [ ] **AC-2.10** Given a location removed after its edit page was shown When the page's form is saved (PATCH) Then the answer is 404 and nothing is created.

### Story 3: Remove a location

**As a** collector who took a binder apart
**I want** to remove its location
**So that** the list only holds places I use

**Acceptance criteria:**

- [ ] **AC-3.1** Given a location "Blue binder" When the collector activates Remove Then a confirmation page asks "Remove Blue binder?" with a "Remove" button and a "Cancel" link, and nothing is removed yet.
- [ ] **AC-3.2** Given the confirmation page When the collector activates Remove Then they are on the locations page (303), it says "Removed “Blue binder”.", and the location is gone.
- [ ] **AC-3.3** Given the confirmation page When the collector activates Cancel Then they are on the locations page and the location is still there.
- [ ] **AC-3.4** Given an account with lots and a location When the location is removed Then the account's lots are unchanged: the same lots, each with the same quantity, finish, condition, price paid and times (decision 3).
- [ ] **AC-3.5** Given a removed location When its name is added again Then it is added as a new location, with no error.
- [ ] **AC-3.6** Given a request to remove a location that is already gone (a second tab, or a resubmitted request) When it arrives Then the answer is 404 and nothing else changes; the page doesn't redirect with a message (P7, as every removal in the app answers).
- [ ] **AC-3.7** Given a location removed after a page showed it When that page's rename link is followed Then the answer is 404.

### Story 4: Only my locations

**As a** collector on an instance with other accounts
**I want** my locations to be mine alone
**So that** nobody else sees or changes how I keep my collection

**Acceptance criteria:**

- [ ] **AC-4.1** Given accounts A and B, and a location of B's When A's collector requests that location's edit page, its removal page, a rename (PATCH) or a removal (DELETE) Then each answers 404 and B's location is unchanged.
- [ ] **AC-4.2** Given accounts A and B each with locations When A's collector opens the locations page Then it lists only A's, and an add or rename that uses a name B has succeeds for A.
- [ ] **AC-4.3** Given a request that carries an `account_id` parameter naming another account When a location is created Then the location belongs to the signed-in collector's account.
- [ ] **AC-4.4** Given a signed-out visitor, with the catalog open or not (spec 023) When they request (GET) any locations page Then they are sent to sign in and nothing about any location is shown; given a create, rename or removal sent with a session that has ended Then it is sent to sign in and nothing is written; given one sent with no session cookie Then it fails forgery protection first (422), as spec 025 and spec 028 say for every such request, and nothing is written (the request specs for this one enable forgery protection).
- [ ] **AC-4.5** Given an admin When they open the admin users, catalog and jobs pages Then no location, name or count of locations appears on them.
- [ ] **AC-4.6** Given an account with locations When the account is deleted Then its locations are deleted with it.

### Story 5: Reach the page

**As a** collector
**I want** a way to the locations page from anywhere
**So that** I can name a place when I need one

**Acceptance criteria:**

- [ ] **AC-5.1** Given a signed-in collector on a wide screen When any collector page is shown Then the header's navigation reads Collection, Search, Scan, Locations, and Locations links to the locations page, marked as the current page while on it or its edit and removal pages, and at 640px, where the header's navigation first appears, the four links fit on one line with the account menu.
- [ ] **AC-5.2** Given a signed-in collector at phone width When they open More Then its rows are: Signed in as, Locations, Export collection, Import collection, Add by number, the admin links for an admin, Sign out; and Locations opens the locations page.
- [ ] **AC-5.3** Given a signed-in collector at phone width When any tab bar page is shown Then the tab bar holds the same tabs as before (Collection, Search, Scan, More), and on the locations pages no tab is marked current (P5).
- [ ] **AC-5.4** Given a signed-out visitor to an open catalog (spec 023) When a catalog page is shown Then neither Locations nor any other collection link appears.
- [ ] **AC-5.5** Given the locations page, its edit page and its removal page at 360px, 640px and desktop width, in both themes When they are shown Then each has no horizontal scrolling, every target is at least 44px on a touch device, and every control shows the focus ring.

### Story 6: My export carries my locations

**As a** collector
**I want** my export to include my locations
**So that** restoring it on another instance can bring them back

**Acceptance criteria:**

- [ ] **AC-6.1** Given an account with locations "Blue binder" and "Trade binder" and some lots When the collector exports their collection Then the file's `format_version` is 2, its `locations` is `[{"name": "Blue binder"}, {"name": "Trade binder"}]` in that order, and its `profile`, `currency` and `lots` are what version 1 wrote.
- [ ] **AC-6.2** Given an account with no locations When it exports Then the file is version 2 and `locations` is `[]`.
- [ ] **AC-6.3** Given locations "box", "Binder 2", "Binder 10", "Éclair" and "eclair" When the account exports Then `locations` lists them in the order of AC-1.4.
- [ ] **AC-6.4** Given an export of any account When it is checked against `v2.schema.json` and the rules the schema can't state Then it is well-formed.
- [ ] **AC-6.5** Given an export file When it is read Then it holds no location id, account id or time for a location.
- [ ] **AC-6.6** Given two exports of one unchanged collection, made at different times When they are compared Then they are the same collection in the sense of the format (decision 9), and equal apart from `exported_at`.
- [ ] **AC-6.7** Given another account's locations When this account exports Then none of their names is in the file.
- [ ] **AC-6.8** Given two exports of accounts whose locations differ only in the case of one name ("box" and "Box") When they are compared as the format's "same collection" Then they are not the same (names are compared exactly); given the same names in another order Then they are the same.

### Story 7: The format document, schema and Coverage cover locations

**As a** person writing a program that reads exports
**I want** the format document, the schema and the examples to define version 2
**So that** I can read a file without Collector

**Acceptance criteria:**

- [ ] **AC-7.1** **(review)** Given the format document When it is read Then it says version 2, describes `locations` and the `duplicate_location` rule, keeps version 1's definitions as they were, and its version history has a row for version 2 with its date and the sentence that putting lots in locations will raise it to 3.
- [ ] **AC-7.2** Given `v2.schema.json` When a file is checked Then a version 2 file with `locations` missing, not a list, or over 500 elements, or holding a name that is empty, over 60 code points, padded with White_Space, holding a run of two spaces, a tab or another White_Space character other than U+0020, or a Cc or Cf character, is not well-formed; and `v1.schema.json` is unchanged.
- [ ] **AC-7.3** Given two locations whose names have the same comparison key ("box" and "Box"; "Straße" and "STRASSE"; "Café" in NFC and in NFD) When a file holds both Then it is not well-formed (`duplicate_location`), at the pointer `/locations/<i>` of the later one; and given a single name in NFD Then the file is well-formed.
- [ ] **AC-7.4** Given the examples folder When the suite runs Then every valid example is well-formed under its own version's schema, every invalid example fails for exactly the reason `problems.json` gives, and the comparison examples hold or differ as they say, including version 2 files that differ in their locations, in the case of a name (they differ), and in the order of the locations (they are the same); and the invalid examples include each case listed in decision 9.
- [ ] **AC-7.5** Given the database When the suite runs Then the Coverage tables list the `locations` table as exported, with a line for each column the table has, as the format's "Coverage" does for `lots` and `users` (the name exported, the internal ids and the times left out, any column derived from the name left out), and the suite fails when a table or a column is missing.
- [ ] **AC-7.6** Given the app's copy of each schema When the suite runs Then each is byte-identical to the file under `docs/export-format/` (ADR 0021).
- [ ] **AC-7.7** Given a collection exported by the app When it is read back through the format's rules Then its `locations` are well-formed under version 2, and the existing round trip still holds for lots.
- [ ] **AC-7.8** Given every Unicode scalar value `c` (U+0000 to U+10FFFF without the surrogates) When the strings `c`, `a` + `c` + `b`, `a` + `c` + `c` + `b` and `c` + `c` are each tried as a name Then (a) if the model accepts a string, possibly after normalising it, the stored name is a well-formed name as written under the schema, `ExportFormat::Rules` and the format document's rules; (b) if a string is a well-formed name as written, the model accepts its normalised form unless that form is over 60 code points; and (c) every name the model stores exports as a well-formed file (a parity spec, decision 9).

### Story 8: Previewing a file that carries locations

**As a** collector
**I want** the import preview to understand my own export
**So that** I can check a file before it replaces my collection

**Acceptance criteria:**

- [ ] **AC-8.1** Given a collector's own version 2 export When they upload it to the import preview Then the file is read, not refused as newer.
- [ ] **AC-8.2** Given a version 2 file whose locations are "Blue binder", "Box" and "Trade binder", and an account holding "Trade binder", "box" and "Old crate" When it is previewed Then the Locations section says 1 added (Blue binder), 1 renamed (box to Box), 1 unchanged and 1 removed (Old crate), and names the renamed and the removed; no location is written.
- [ ] **AC-8.3** Given a version 2 file with `locations: []` and an account with 3 locations When it is previewed Then the section says all 3 would be removed, and lists them.
- [ ] **AC-8.4** Given a version 1 file When it is previewed Then the page says "This file was written before locations existed, so your locations would stay as they are." and shows no locations removed.
- [ ] **AC-8.5** Given a version 2 file with `locations` missing, not a list, or holding a name that is not well-formed, or two names with the same comparison key (after normalisation), or a name whose normalised form is over 60 code points When it is previewed Then the preview refuses the file (422), shows no lots, and names the field and the reason as decision 10 words them: "locations.1 has the same name as an earlier location, ignoring case" for a duplicate, "locations is missing" for a missing list, and "locations.N.name isn't valid" for the rest (P6).
- [ ] **AC-8.6** Given a file whose `format_version` is 3 or higher When it is previewed Then it is refused as newer, and the page says "This instance reads version 2."
- [ ] **AC-8.7** Given a version 2 file When it is previewed Then the lot outcomes (added, changed, unchanged, held, removed), the profile notes and the problem rows are what spec 025 gives for a version 1 file with the same lots.
- [ ] **AC-8.8** Given a preview of any file When the page is shown Then no location, lot, user or account row was created, changed or removed; the only thing written is what spec 028 AC-1.11 allows (the account's one stored upload).
- [ ] **AC-8.9** Given a version 2 file that would rename 150 locations and remove 150 When it is previewed Then the section counts all 150 and 150 and lists the first 100 of each with "and 50 more" (P3).

### Story 9: Applying a file that carries locations

**As a** collector restoring an export
**I want** applying a file to restore its locations with its lots
**So that** my collection and the places it is kept come back together

**Acceptance criteria:**

- [ ] **AC-9.1** Given a stored version 2 upload as in AC-8.2 and the removal confirmed When the apply is posted Then the account's locations are exactly "Blue binder", "Box" and "Trade binder"; the location that was "box" is the same record (same id) now spelled "Box"; "Trade binder" was not written to (its `updated_at` is what it was); "Old crate" is gone.
- [ ] **AC-9.2** Given an empty account and a resolvable version 2 file of 3 lots and 3 locations When it is previewed and applied Then the account holds those 3 lots and those 3 locations and nothing else.
- [ ] **AC-9.3** Given a version 1 file and an account with locations When it is applied (the lots changing) Then the account's locations are exactly as they were, with the same ids and times; and given a version 1 file whose lots are all unchanged Then the preview says there is nothing to change, whatever locations the account has.
- [ ] **AC-9.4** Given a version 2 file whose lots are all unchanged and whose locations differ from the account's When it is previewed Then the page offers the apply (the file has something to change), stores the upload, and applying it changes the locations and no lot, and clears no working state (AC-9.17).
- [ ] **AC-9.5** Given an account with lots and locations, exported with `CollectionExport` and applied to an empty account on the same catalog Then the new account's locations equal the first's by name, exactly spelled, and exporting the new account gives a document equal to the original but for `exported_at` and the profile's name and email address (the round trip, spec 028 AC-6.2, with locations).
- [ ] **AC-9.6** Given the export of AC-9.5 with the original account's locations then changed (one renamed, one removed, one added) and the file applied back Then the account's locations equal the file's again, exporting gives the file but for `exported_at`, and previewing the same file again says there is nothing to change (spec 028 AC-6.3, with locations).
- [ ] **AC-9.7** Given an applied version 2 file When the same upload's file is previewed again Then every location is unchanged, and no location's attributes, `id` or `updated_at` differ from after the first apply.
- [ ] **AC-9.8** Given a version 2 file that can be applied and a failure raised while a location is written, after the lots were written (injected in the spec) Then no lot and no location is created, changed or deleted, the stored upload is still there, and a following apply of the same upload succeeds (spec 028 AC-2.1).
- [ ] **AC-9.9** Given a stored upload and a held location added, removed or respelled (including a change of case alone), by another tab, after the preview When the apply is posted Then the response is 409, nothing is written, and the page shows the preview of the stored file against the locations as they now are with a new apply form. And given two previews of the same file and account, made apart Then their fingerprints are equal; given an added, removed or respelled held location, or any change to the stored file Then they differ; and given a held location deleted and added again with the same spelling Then they are equal, and the apply goes ahead.
- [ ] **AC-9.10** Given a plan that removes locations and no lots, and a request with the checkbox not checked Then the response is 422 with "Confirm the removal to apply this file", nothing is written; the label reads "I understand this removes M locations" (and "N lots and M locations" when both); given a plan that only adds or renames locations Then no checkbox is needed.
- [ ] **AC-9.11** Given an account with lots and a file whose plan removes locations Then every lot is as the plan leaves it, and none is created, changed or deleted because a location was removed (decision 3).
- [ ] **AC-9.12** Given an account with 500 locations and a file of 500 other locations When applied Then the account holds exactly the file's 500, with no failure from the limit of decision 7 (the removals and additions are one change).
- [ ] **AC-9.13** Given two accounts with locations of the same names, and a stored upload for each When the first applies Then the second account's locations are unchanged (row counts, ids and `updated_at` compared), and none of its names appears in any response.
- [ ] **AC-9.14** Given an applied version 2 file Then the notice names the lots as spec 028 does and adds the locations: "Imported: 3 lots added, 2 changed, 1 removed; 2 locations added, 1 renamed, 1 removed" (never a final period, for any file, as 028's notice has none) with each location part left out when its count is zero (a lot count that is zero stays, as in 028: "Imported: 1 lot added, 0 changed, 0 removed"), and no sentence about locations after a version 1 file.
- [ ] **AC-9.15** Given each valid example under `docs/export-format/examples/valid/`, version 1 and version 2, that resolves against the catalog the spec builds Then it applies to an empty account, and exporting the result equals the example but for `exported_at`, the profile's name and email, and, for a version 1 example, the version and the empty `locations` the export now writes (spec 028 AC-6.4). Each location name in the example is compared after it passes through the name function (NFC, decision 5), because the export writes NFC and a valid example may hold a name in NFD (ruled 2026-10-21).
- [ ] **AC-9.16** Measured outside the suite: spec 028's bars for a 50,000-row file as merged (the whole request under 30 seconds, the write transaction under its hard bar of 4 seconds, under 500 MB RSS growth), still hold with 500 locations in the file and 500 held, recorded in `verification.md` (spec 028 AC-1.10).
- [ ] **AC-9.17** Given an account with a scanner sitting, a number-entry list, a bulk selection and an undoable bulk removal When a version 2 file whose plan changes only locations (no lot, no view) is applied Then all four are as they were; given the same state and a file whose plan changes a lot Then they are cleared as spec 028 says; and given a version 2 file whose plan changes only the collection view Then they are as they were.
- [ ] **AC-9.18** Given a version 2 file whose location is "Café" in NFD, and an account holding "Café" in NFC When it is previewed and applied Then the location is unchanged (nothing is written to it); given an account without it Then it is added, stored in NFC, and exporting afterwards writes the NFC name; given an NFD name that differs from a held name only in case Then it is renamed; and the preview shows names in NFC.

## Functional Requirements

### FR-1: Locations

**Must:**
- Belong to one account, with a name that follows decision 5, whose comparison key is unique within the account.
- Be created, renamed and removed only through the locations pages, for the signed-in collector's account.
- Be removed without any effect on lots (decision 3).
- Be limited to 500 per account, and to names of 1 to 60 code points.

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
- State the `duplicate_location` rule, the sets of characters of decision 5, the normalisation on read, and the comparison of location names as written in "The same collection".
- Have a schema, a model and a format document that agree on what a well-formed name is, proved for every scalar value (AC-7.8).

**Must not:**
- Give any file an internal id of the instance.
- Treat a missing `locations` in a version 1 file as an empty list.

### FR-5: The preview and the apply

**Must:**
- Read versions 1 and 2, each against its own schema, and refuse higher versions as newer.
- Show the Locations section for version 2, and the sentence of AC-8.4 for version 1.
- Refuse a version 2 file whose locations are not well-formed, as a whole.
- Include locations in the plan, its "nothing to change" test, its fingerprint, its confirmation and its notice (decision 11).
- Write the locations in spec 028's one write transaction, with the lots, matched by comparison key: create, respell and delete, keeping the id of every location it keeps.
- Clear no working state when it writes no lot (decision 11, AC-9.17).
- Leave the account's locations alone for a version 1 file.

**Must not:**
- Write a location outside that transaction, or apply the locations of a file that can't be applied.
- Delete, change or move a lot because a location was removed (decision 3).
- Fail on the limit of 500 because it created before it deleted (AC-9.12).
- Edit spec 028, or change its stored upload, expiry, sweep or the working state it clears when it writes lots.

## Non-Functional Requirements

### Performance

- The locations page runs a fixed number of queries whatever the number of locations: one for the list. The export adds one query for the account's locations. The plan measures both with 500 locations and records the time in `verification.md`.
- The preview's time bar (30 s) and memory bar (500 MB) from spec 025 decisions 12 and 13, and the apply's bars from spec 028 decision 3, hold for a version 2 file of 50,000 lots and 500 locations (AC-9.16). The locations add a bounded number of statements to the apply (spec 028 FR-4's wording), not one per location.

### Security

- Every query of locations is scoped to `Current.account`; another account's location answers 404 (multi-tenancy rule).
- Strong parameters (`params.expect`). The name is the only permitted parameter; `account_id` is never mass-assigned.
- Names are output escaped like any other text; nothing about them is `html_safe`.
- Protect against forgery as every form does; remove and rename are not GETs.

### Reliability

- Create and rename keep the uniqueness rule in the database as well as in the model, so two requests racing to add one name leave one location and one clean error. The race loses with the same message as AC-1.9. SQLite's `LOWER()` and `NOCASE` fold ASCII only, so the database's uniqueness rests on the comparison key, computed by the model with Unicode case folding and stored beside the name under a unique index with the account; the plan doesn't use `COLLATE NOCASE`. The cap of 500 holds under racing adds (AC-1.13), because SQLite serialises writers.
- Applying locations is part of spec 028's all-or-nothing transaction (AC-9.8).
- The migration is safe to run unattended from any prior version: it adds a table and changes nothing else.

### Cost per account (hosted-door rule 4)

At most 500 locations: worst case about 1 KB each (a 60-code-point name of 240 bytes of UTF-8, its key and its index entry), so under 0.5 MB of storage per account, and under 130 KB in an export (decision 7, P8); a typical name is under 100 bytes. No background work, no cache entry and no job.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Name blank | 422, "Give the location a name." (AC-1.6) |
| Name over 60 characters | 422, "Names can be at most 60 characters." (AC-1.7) |
| Name has a control character | 422, "Names can't contain control characters." (AC-1.8) |
| Name with the same comparison key as another location's | 422, "You already have a location called “<name>”." (AC-1.9, AC-2.4) |
| 501st location | 422, "You can have at most 500 locations." (AC-1.10) |
| Two requests add one name at once | One location; the second answers like AC-1.9 |
| Location of another account, or already removed | 404, nothing changes (AC-4.1, AC-3.6) |
| Signed-out visitor (GET, or a write with an ended session) | Sent to sign in; a write with no session cookie fails forgery protection first (422) (AC-4.4) |
| PATCH or DELETE of a location removed meanwhile | 404, nothing created or changed (AC-2.10, AC-3.6) |
| A request without the `location` parameter | 400 (AC-1.14) |
| Two tabs rename one location | Both succeed; the later name stands (AC-2.9) |
| Two adds race at 499 locations | One is added; the other gets the cap message (AC-1.13) |
| Version 2 file with bad or duplicate locations (a duplicate after normalisation and case folding) | Preview and apply refuse the whole file (AC-8.5) |
| Version 2 file with a name in NFD | Well-formed; read as the NFC name (AC-9.18) |
| File of version 3 or higher | Preview refuses it as newer (AC-8.6) |
| Version 1 file | Previewed and applied; locations untouched (AC-8.4, AC-9.3) |
| Locations changed between the preview and the apply | 409, fresh preview, nothing written (AC-9.9) |
| Plan removes locations and the removal isn't confirmed | 422, nothing written, the upload stays (AC-9.10) |
| A write of a location fails during the apply | The whole transaction rolls back; nothing changed (AC-9.8) |
| A location-only apply | Locations change; no lot and no working state does (AC-9.4, AC-9.17) |

## Open Questions

None. The maintainer ruled decisions 1–13 and the details P1–P8 on 2026-10-20: P1 as the lenient alternative (decision 9), P2 to P8 as proposed.

## Out of Scope (Future Considerations)

- Putting lots in locations, and the ADR that decides how a lot sits in more than one place (#45; format version 3).
- Per-location counts and the location on tiles and rows (#46), filtering (#47), "Move to…" (#48), decks (#49), "Free to use" (#50), and choosing a location in typed entry (#51) or at the scanner (#56).
- A kind, notes, order or nesting of locations.
- Each collector choosing and reordering their navigation sections.

## Documents that change

- A new ADR (numbered when written: the next free number on `origin/main`'s `docs/adr`): locations are format version 2, lots in locations are version 3; it supersedes the part of ADR 0020 named in decision 1. ADR 0020's Status line gets a pointer to it, and `docs/adr/README.md`'s index a line.
- `docs/export-format/README.md`: version 2 (and the sentence that applying a version 1 file leaves locations alone), the sentence in "Versions" about locations, the `locations` section with its character sets, `duplicate_location`, "The same collection", the Coverage tables (the `locations` table and its columns), the version history and the Examples section's rule list.
- `docs/export-format/v2.schema.json` and its examples (valid, invalid with `problems.json`, comparison); `app/models/export_format/v2.schema.json`, byte-identical.
- `docs/roadmap.md`: item 9 marked done with the spec and the PR; item 10's version note changed to 3.
- `docs/design-system/`: a doc for the locations page's new pattern under `components/`, listed in the README's app additions; the Navigation list if the header's links change.
- `docs/architecture/`: the area docs for collection and lots and for data portability, once they exist (spec 027); until then `CLAUDE.md` gains a line on locations and the export's version 2.
- `docs/specs/README.md`: this spec's row, with the supersessions above (spec 028's own row is not edited by this spec).
- Spec 028's plan and code, when this spec's plan is made: the apply it introduced is extended, not rewritten (decision 11).
- `README.md`: if it describes the export's version or the navigation.
