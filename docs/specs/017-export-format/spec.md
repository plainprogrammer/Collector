# Feature 017: Export Format

**Status:** Approved
**Version:** 1.2.1
**Created:** 2026-10-11
**Last Updated:** 2026-10-11
**Branch:** `017-export-format`
**Issue:** [#37](https://github.com/plainprogrammer/Collector/issues/37)
**Frozen:** the current rules are in [`data-portability.md`](../../architecture/data-portability.md) (whole spec); see the [specs index](../README.md)
**Plan:** retired in `d586ff6f117b878fcb40f718e07dd8b832dc0dbc`; read it with `git show d586ff6f117b878fcb40f718e07dd8b832dc0dbc^:docs/specs/017-export-format/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-11 | Initial draft from the outline the maintainer agreed on 2026-10-11 (file shape, entry reference, contents, deliverables, and eight proposals, listed under [Decisions](#decisions)) |
| 1.1.0 | 2026-10-11 | Spec review revisions (Fable, Mode A, NEEDS REVISION), awaiting the maintainer's approval. **Finish is not a per-type list:** the application has a condition vocabulary per type, but a finish is whatever the source lists for that printing (FR-5, FR-6, FR-8, AC-4.2). **Not recorded is `null`:** finish, condition and price paid are always present, `null` when not recorded, never an empty string (FR-5, Error Scenarios). **Price paid is per copy** and has one written form with no leading zeros (FR-5). **Times have one written form** (FR-2, FR-5). **The coverage guard has a unit:** tables that belong to an account or a user, each exported or left out, with the columns an exported table leaves out (FR-9, AC-3.4); sign-in sessions and the dates an account and user were created join the left-out list. **Comparisons are exact** (FR-7). **Retired entries** are resolvable (Error Scenarios). **Which name** the descriptive field carries (FR-6). **ACs checked by reading** are marked, and FR-10 lists the automated ones; AC-1.3 names what it searches for; AC-4.4 (a restatement of AC-2.1 and AC-2.2) is dropped and AC-4.5 renumbered. **Proposed, reverses part of decision 6:** a new field that holds collector-owned data raises the version (FR-8) |
| 1.1.1 | 2026-10-11 | Maintainer ruling, relayed by the coordinator: FR-8's narrowed rule stands. A new field that holds collector-owned data raises `format_version`; only information-only fields are free. Recorded as decision 14 and removed from Open Questions |
| 1.1.2 | 2026-10-11 | Approved by the maintainer as it stands, relayed by the coordinator, including every item that was under Open Questions (now decisions 15 to 19). No requirement changed |
| 1.2.0 | 2026-10-11 | Plan additions, approved by the maintainer with the plan (decision 20). **A repeated key** in one object makes a file not well-formed (FR-1, Error Scenarios). **A time must be a real moment** (FR-2, Error Scenarios). **Accounts** join the coverage table as nothing to export, with each column left out, so a column added later fails the guard (FR-9, AC-3.5). **The writer's name:** the optional header field names any program and its version (FR-2). **No byte order mark** (FR-1). **The collection view** is required and not blank (Error Scenarios). The field names are fixed by the plan and the format document |
| 1.2.1 | 2026-10-11 | Implementation review (Fable, Mode B, SPEC-ALIGNED): four sentences that version 1.2.0 left stale. FR-3 names the collection view among the fields that can't be blank; FR-9's lead names the third mark, nothing to export; Open Questions names decision 20; the glossary says a `null` finish or condition is always resolvable, as the application already treats it. No requirement changed |

---

## Problem Statement

Foundation principle 2 says collectors own their data, in open, documented formats. Today a collector's data can't leave an instance or enter another one, and nothing says what such a file would contain. Export ([#38](https://github.com/plainprogrammer/Collector/issues/38)), import preview ([#39](https://github.com/plainprogrammer/Collector/issues/39)) and import apply ([#40](https://github.com/plainprogrammer/Collector/issues/40)) each need one agreed format before any of them is built. The 1.0 test's second check, "an export of that instance has been restored into a fresh instance and matched", has no meaning until "matched" is defined.

> **Inputs.** [ADR 0019](../../adr/0019-lot-as-the-unit-of-ownership.md) (a lot's identity is its entry, finish, condition and price paid), [ADR 0017](../../adr/0017-row-level-tenancy-one-user-per-account.md) (one user per account; shared collections will bump the format's version), [ADR 0018](../../adr/0018-collectible-agnostic-catalog-core.md) (the core names no collectible), spec 004 FR-6 (lots stay addressable by the printing's external id, never an internal one; lots of retired printings are kept), spec 009 (scanner sittings aren't collection data and aren't exported), `.claude/rules/external-data-and-portability.md` and the [north star](../../north-star.md)'s spec rules. This is an enabling slice: a format definition, releasable alone.

### Glossary

- **The format**: what this spec defines. One file describes one account's collection at one moment.
- **Format document**: the prose description of the format, written for a collector and for a builder.
- **Schema**: a machine-readable statement of what a well-formed file is, kept beside the format document.
- **Example**: a file kept in the repository that the format's rules are checked against. A valid example must pass; an invalid example must fail for the reason it names.
- **Writer / reader**: any program that produces or consumes a file. Collector's export and import are the first of each; neither is built here.
- **Well-formed**: a property of the file alone, checkable with no catalog and no instance. The schema and the rules in FR-1 to FR-6 decide it.
- **Resolvable**: a property of a file against one instance's catalog: every lot's entry is in that catalog (retired or not), its finish is `null` or one the catalog lists for that entry, and its condition is `null` or in the type's vocabulary. A well-formed file may be unresolvable on some instance. Import (#39) decides what happens then; the format only names the distinction.
- **Not recorded**: the collector gave no finish, no condition or no price for a lot. The application has one such state for each (a blank is stored as nothing), and so does the format: `null`.
- **Entry identity**: the collectible type and the source's own id for the entry. For Magic, the Scryfall card id.
- **Lot identity**: the entry identity, finish, condition and price paid (ADR 0019).

## Goals

- One documented format for a collector's data: their lots, the currency of the prices, and their profile.
- Every reference to a catalog entry uses the source's external id. No internal primary key appears anywhere in a file.
- A version number in every file, with a stated rule for when it goes up.
- A definition of "two files hold the same collection" that export, import and the 1.0 test can all use.
- A schema and examples that CI checks, so the document, the schema and the application can't drift apart unnoticed.
- ADR 0020 records the format decision and what was rejected.

## Non-Goals

- Building export, import preview or import apply (#38, #39, #40), or any page, job, task or setting.
- Deciding what import does with a file that is not well-formed, not resolvable, or whose profile clashes with an existing user. Those are #39's and #40's decisions.
- Reading or writing files from other collection tools (parked until after 1.0).
- Locations and shared collections. Each extends the format in its own spec.
- A second representation of the same data (a spreadsheet view).
- Backing up an instance (#41). A backup holds everything an operator runs; this format holds what one collector owns.

## Users and Context

**Primary users:** the builders of export and import (specs #38–#40), who work from the format document, the schema and the examples.
**Secondary users:** a collector who opens their own file; authors of later specs that add collector-owned data; anyone writing another tool that reads a Collector file.
**Usage context:** read when building or changing export or import, when a spec adds collector-owned data, and by a collector who wants to know what they were given.
**User mental model:** a collector thinks "my cards, how many, what state they're in and what I paid for each". A builder thinks in lots (ADR 0019). The file should read as the first and behave as the second.

## User Stories

Most of this feature is a document, so some criteria can only be checked by reading it. Those are marked **(review)** and are checked in the implementation review. The others are automated (FR-10).

### Story 1: A collector reads their own file

**As a** collector
**I want** to understand a file of my collection with only the format document beside it
**So that** my data is mine without Collector running

**Acceptance criteria:**

- [ ] **AC-1.1** Given the valid examples When every field name that appears in them is looked up in the format document Then each one appears there by name.
- [ ] **AC-1.2** **(review)** Given the format document When any field's entry is read Then it gives the field's meaning, whether it may be `null`, and the values it may take, and price paid is described as the price of one copy.
- [ ] **AC-1.3** Given a lot in a valid example When it is read without a catalog Then it gives the entry's name, set code, collector number and language alongside the entry identity.
- [ ] **AC-1.4** Given any valid example When its field names are searched Then none is `admin`, `password` or `session`, none ends in `_digest`, and the only field that holds an identifier of any record is the entry's source id.
- [ ] **AC-1.5** **(review)** Given the format document When a collector reads its opening section Then it says in plain words that the file contains their name and email address, and that it contains everything needed to rebuild their collection.

### Story 2: A builder works from the format alone

**As a** builder of export or import
**I want** the format to answer what a well-formed file is, what identifies a lot, and when two files hold the same collection
**So that** export and import are built against one definition and can be tested against each other

**Acceptance criteria:**

- [ ] **AC-2.1** Given the format's rules (the schema and FR-1 to FR-6) When each valid example is checked against them Then every one passes.
- [ ] **AC-2.2** Given the invalid examples (at least one per row of [Error Scenarios](#error-scenarios) marked "not well-formed") When each is checked against the format's rules Then every one fails, and fails for the reason that example names.
- [ ] **AC-2.3** Given the valid examples taken together When their lots are listed Then they include: a lot with every field set; a lot with finish, condition and price paid all `null`; a lot with price paid `"0.00"`; two lots of the same entry that differ only in finish; two that differ only in condition; two that differ only in price paid; a lot with quantity 1 and one with quantity 9,999; and a collection with no lots.
- [ ] **AC-2.4** **(review)** Given the format document When a builder looks for the definition of lot identity Then it states that a lot is identified by entry identity, finish, condition and price paid, that `null` is a value of its own (it matches only `null`), and that the descriptive fields are never part of identity.
- [ ] **AC-2.5** Given the rule of FR-7 When it is applied to the example pairs kept for it Then the pair that differs only in lot order, export time, writer's version, descriptive fields and an undefined field is the same collection, and each pair that differs in one compared thing (a quantity, a lot's time, a lot's identity, the currency, a profile field) is not.
- [ ] **AC-2.6** **(review)** Given the format document When a builder looks for "the same collection", well-formed and resolvable Then it gives FR-7's rule and defines the other two as the glossary does, stating that well-formedness never depends on a catalog.

### Story 3: A later spec extends the format

**As an** author of a spec that adds collector-owned data
**I want** the format to say how it grows and when its version goes up
**So that** "export covers it" is a rule I can follow in the same PR

**Acceptance criteria:**

- [ ] **AC-3.1** **(review)** Given the format document When an author looks for the versioning rule Then it states FR-8's rule: what raises the version, what doesn't, and what a reader does with a version it doesn't know and with a field it doesn't know.
- [ ] **AC-3.2** **(review)** Given the format document When an author looks for how to extend the format Then it lists the steps a spec takes in its own PR: describe the new data in the document, add it to the schema and the examples, add it to the coverage table (FR-9), apply the versioning rule, and record a version bump in the document's version history.
- [ ] **AC-3.3** **(review)** Given the format document When its version history is read Then it has an entry for version 1 with its date, and names the two changes already expected: locations, and shared collections (which will raise the version, per ADR 0017).
- [ ] **AC-3.4** Given the application's database schema When a table that belongs to an account or to a user is missing from the format document's coverage table, or an exported table has a column that the table neither maps to the format nor lists as left out Then CI fails and names the table or column.
- [ ] **AC-3.5** Given the coverage table When it is read Then lots and users are marked exported, with the left-out columns of FR-9, accounts is marked nothing to export with every column left out, and scanner sittings, scanner sitting entries, bulk selections, bulk selection marks, bulk removals and sessions are marked left out, each with its reason.

### Story 4: The format can't drift from its document

**As the** maintainer
**I want** CI to check the document, the schema, the examples and the application against each other
**So that** a change to one that isn't made to the others is caught before merge

**Acceptance criteria:**

- [ ] **AC-4.1** Given the format document and the schema When the version each states is compared Then they are equal, and every valid example carries that version; CI fails otherwise.
- [ ] **AC-4.2** Given the format document's section for Magic When its conditions are compared with the conditions the application registers for Magic Then they are the same values; CI fails otherwise.
- [ ] **AC-4.3** Given the format document When the currencies it says a Collector export may carry are compared with the currencies the application supports Then they are the same codes; CI fails otherwise.
- [ ] **AC-4.4** Given the repository after this feature When the README and the ADR index are read Then the README links the format document, and the ADR index lists ADR 0020 and no longer lists the export format as expected.

## Functional Requirements

### FR-1: One file, one account's collection

**Must:**
- Be a single JSON document, encoded as UTF-8 with no byte order mark.
- Hold no key twice in one object.
- Describe exactly one account's collection at one moment.
- Be valid with no lots.

**Must not:**
- Depend on any other file, or on the instance that wrote it, to be read.
- Contain an internal primary key of any record.

### FR-2: Header

**Must:**
- Carry a fixed format name that identifies the file as a Collector export, so that a reader can refuse any other JSON.
- Carry `format_version`, a whole number. This spec defines version 1.
- Carry the moment of export, in the time form below.
- Allow, but not require, the name and version of the program that wrote the file. It is information only.
- Write every time in the file in one form: RFC 3339 in UTC with a `Z` suffix and no fraction of a second (`2026-10-11T12:34:56Z`). An offset, a fraction of a second or any other form is not well-formed. A writer drops the fraction; it doesn't round.
- Require every time to be a real moment: 30 February isn't one.

**Must not:**
- Give a reader any reason to behave differently on the export time or the writer's version.

### FR-3: Profile

**Must:**
- Carry the collector's name, their email address, and their choice of collection view (grid or table).
- Require the name, the email address and the collection view to be non-empty after trimming.
- Treat the collection view as a preference: a reader that doesn't know the value uses its own default, and that isn't an error.

**Must not:**
- Carry a password in any form, the admin flag, sessions, the dates the account and user were created, or any account or user id.
- Say what a reader does with the name and email. The fields have a meaning; applying them is import's decision (#40).

### FR-4: Currency

**Must:**
- Carry one ISO 4217 currency code for the file. Every price paid in the file is in that currency.
- Be well-formed with any three-letter uppercase code. The format document lists the codes a Collector export may carry today.
- Record the instance's currency at the moment of export, for as long as currency is an instance setting ([#64](https://github.com/plainprogrammer/Collector/issues/64)). When currency moves to the account the field keeps its meaning and the version doesn't change.

**Must not:**
- Carry a currency per lot.

### FR-5: Lots

**Must:**
- Carry, for each lot: its entry (FR-6), quantity, finish, condition, price paid, when it was added and when it was last changed. All of them are always present.
- Write quantity as a whole number from 1 to 9,999.
- Write finish and condition as non-empty strings, or `null` when not recorded. The core of the format gives the strings no meaning; the collectible type's section does (FR-6).
- Write price paid as the price of **one copy**: a decimal string of digits with no leading zero except a lone `0`, a point, and exactly two digits (`"12.50"`, `"0.00"`, `"1200.00"`), or `null` when not recorded. Two places apply to every currency, because that is how Collector stores and shows a price. `null` and `"0.00"` are different: not recorded, and recorded as free.
- Write both times in FR-2's form. The time last changed is never earlier than the time added.
- Give the lots no meaningful order.

**Must not:**
- Write an empty or whitespace-only string for finish, condition or price paid, or leave any of them out. Such a file is not well-formed.
- Hold two lots with the same lot identity. Such a file is not well-formed.
- Carry anything about a single copy within a lot (ADR 0019).

### FR-6: Entry reference

**Must:**
- Identify the entry by collectible type and the source's own id for it, written as the source gives it. For Magic, the type is `mtg` and the id is the Scryfall card id.
- Carry descriptive fields with it, each a non-empty string: the catalog's name for the entry, its set code, its collector number and its language. The name is the catalog's own name for the entry, not a localized printed name.
- State that the descriptive fields are information only. A reader never matches on them, and when they disagree with what the reader's catalog holds for that id, the id wins and the file is still well-formed.
- Keep everything specific to one collectible type in a section of the format document for that type: its type key, what its id is, its condition vocabulary, and where its finish values come from. Version 1 has one such section, for Magic: condition is one of the values the application registers for Magic, and finish is one of the values the source lists for that printing (an open set; `nonfoil`, `foil` and `etched` are the usual ones).

**Must not:**
- Name a collectible in the core part of the format document or in the core of the schema.
- Limit finish to a fixed list. Whether a finish is allowed is a question about one entry in one catalog, so it is part of resolvable, never of well-formed.
- Carry any other catalog data (images, rules text, legalities, prices).

### FR-7: The same collection

Two well-formed files of the same version hold the same collection when all of these are true:

- Their profiles are equal: name, email address and collection view.
- Their currencies are equal.
- Their lots are equal as sets: each lot in one has exactly one lot in the other with the same lot identity, and those two have the same quantity, the same time added and the same time last changed.

Every comparison is exact, character for character. A writer writes each value as the instance stores it (the email address in lower case and trimmed, the name trimmed, the currency in upper case).

**Must not** take into account: the export time, the writer's version, the order of the lots, the descriptive fields, fields the format doesn't define, or how the JSON is laid out.

This is the meaning of "matched" in the 1.0 test's second check. It follows that a reader which restores a collection keeps each lot's two times as the file gives them; #40 inherits that.

### FR-8: Versioning

**Must:**
- Raise `format_version` by one for any change that would make a reader of the earlier version misread a file or lose a collector's data from it: a change to lot identity or entry identity; a field removed or renamed; a field given a new meaning or a new form; a change in which fields are required; or a new field that holds collector-owned data (anything FR-7 would then compare).
- Leave the version alone for: a new optional field that is information only, a new collectible type, a new condition in a type's vocabulary, a finish the source newly lists, a new collection view, or a new currency.
- Require a reader to ignore fields it doesn't know. Because new collector-owned fields raise the version, a field a reader doesn't know at a version it does know is always information only.
- Require a reader to refuse a file whose version is higher than any it knows, saying so, and to refuse a file with no version or with another format name.
- Require a reader that meets a collectible type or condition it doesn't know, or a finish its catalog doesn't list for the entry, to treat that lot as not resolvable, and never to guess or drop it silently.
- Keep a version history in the format document.

**Must not:**
- Change the meaning of version 1 once this feature has merged.

### FR-9: Coverage

The format document carries a coverage table: one row for every table in the application's database schema that belongs to an account or to a user. Each row says **exported**, **left out** or **nothing to export**. An exported row maps the table's columns to the format and lists the columns it leaves out, each with a reason; a left-out row gives the reason for the whole table.

**Must** mark as exported:
- **Lots.** Left out: the internal ids, and the stored lot key (derived from finish, condition and price paid).
- **Users.** Left out: the internal ids, the password digest, the admin flag (an instance role, not the collector's data), and the dates the record was created and changed (facts about the instance, not the collection).

**Must** mark as left out:
- Scanner sittings and scanner sitting entries (working state; spec 009).
- Bulk selections and bulk selection marks (working state that lasts for one edit).
- Bulk removals (a short-lived way to undo; the lots they would restore aren't in the collection).
- Sessions (sign-in state on one instance).

**Must** mark as nothing to export:
- **Accounts.** The table has no data of its own beyond its id and dates. Each of its columns is listed as left out, so a column added later fails the guard.

### FR-10: Deliverables

**Must:**
- Add the format document to the repository's documentation and link it from the README.
- Add the schema and the examples (valid and invalid) beside it.
- Add ADR 0020, "the export format", recording the decision, the alternatives rejected (a spreadsheet file, an id-only reference, descriptive fields as a fallback match, whole-number minor units for price) and why. Update the ADR index.
- Add automated checks for AC-1.1, AC-1.3, AC-1.4, AC-2.1, AC-2.2, AC-2.3, AC-2.5, AC-3.4, AC-3.5, AC-4.1, AC-4.2, AC-4.3 and AC-4.4 to the suite that `bin/ci` runs.
- Update the roadmap's item 2 and CLAUDE.md's project status to say the format is defined.

**Must not:**
- Add any behaviour a collector or operator can reach.
- Add a dependency that the running application loads.

## Non-Functional Requirements

### Performance

- Nothing runs for a collector or operator, so the feature costs nothing per account in storage or background work (hosted-door rule 4).
- The automated checks read a handful of small files and add no network access to the suite.

### Security

- The format carries a collector's name and email address. The format document says so, so that export (#38) treats a file as personal data.
- The format carries no credential and no internal id (AC-1.4).
- No admin page or task is added, and nothing shows an operator a collection (hosted-door rule 2).

### Reliability

- A file is self-describing: its format name and version are enough for a reader to decide whether it can read it.
- Version 1 is fixed once merged (FR-8), so a file written by any release that writes version 1 stays readable.

### Hosted-door rules

- **Source terms:** no source is adopted. A file carries the Scryfall card id and a card's name, set code, number and language, for the collector's own cards.
- **The operator is not the user:** nothing is added for an operator.
- **Per account or user:** no setting is added. The currency field records today's instance setting and keeps its meaning after #64.
- **Bounded cost:** none; see Performance.

## Error Scenarios

These are properties of a file. What a reader shows a person for each is import's to decide (#39).

| Scenario | Classification |
|----------|----------------|
| The file isn't JSON, isn't UTF-8, or starts with a byte order mark | Not well-formed |
| An object in the file holds the same key twice | Not well-formed |
| The format name is missing or is another name | Not well-formed |
| `format_version` is missing, or isn't a whole number of 1 or more | Not well-formed |
| `format_version` is higher than the reader knows | The reader can't judge the file and refuses it (FR-8) |
| The export time, profile, currency or list of lots is missing | Not well-formed |
| The profile's name, email address or collection view is missing, or empty after trimming | Not well-formed |
| The currency isn't three uppercase letters | Not well-formed |
| A lot has no entry, or its entry has no collectible type or no id | Not well-formed |
| A lot's entry lacks a descriptive field, or has an empty one | Not well-formed |
| A lot's quantity is 0, negative, above 9,999 or not a whole number | Not well-formed |
| A lot's finish, condition or price paid is left out, or is an empty or whitespace-only string | Not well-formed |
| A lot's price paid isn't in FR-5's form (`12.5`, `"12.5"`, `"012.50"`, `"-1.00"`, `"$3.00"`, `"1,200.00"`) | Not well-formed |
| A time isn't in FR-2's form (an offset, a fraction of a second, a date alone) | Not well-formed |
| A time has FR-2's form but is no real moment (30 February, hour 24) | Not well-formed |
| A lot's time last changed is earlier than its time added | Not well-formed |
| Two lots have the same lot identity | Not well-formed |
| The file holds a field the format doesn't define | Well-formed; the field is ignored |
| The collection view is a value the reader doesn't know | Well-formed; the reader uses its default |
| A lot's collectible type isn't one the reader's instance has | Well-formed, not resolvable there |
| A lot's entry id isn't in the reader's catalog | Well-formed, not resolvable there |
| A lot's entry id is in the reader's catalog and retired there | Well-formed and resolvable; a lot of a retired entry is still collection data (spec 004 FR-6) |
| A lot's finish isn't one the reader's catalog lists for that entry | Well-formed, not resolvable there |
| A lot's condition isn't in the type's vocabulary on the reader's instance | Well-formed, not resolvable there |
| A descriptive field disagrees with the reader's catalog for that id | Well-formed and resolvable; the id wins |

## Open Questions

None. The points settled while writing and in review were approved with the spec on 2026-10-11 and are decisions 15 to 19; the plan's additions are decision 20.

## Decisions

Agreed by the maintainer on 2026-10-11: 1 to 13 before this spec was written, 14 after its review, 15 to 19 with its approval, and 20 with the plan's. ADR 0020 records the format decision itself.

| # | Question | Ruling |
|---|---|---|
| 1 | What shape is the file? | One JSON document. |
| 2 | How does a lot point at its entry? | External id plus descriptive fields; the fields are information only. |
| 3 | What does the file hold besides lots? | The currency of price paid, when each lot was added and last changed, and the collector's profile and preferences. |
| 4 | What does this slice deliver? | The document, ADR 0020, a schema and examples, checked in CI. |
| 5 | How is price paid written? | A two-place decimal string, or not recorded. |
| 6 | How is the version written, and what raises it? | A whole number from 1. It rises when a version-1 reader would misread the file; new optional fields don't raise it and readers ignore unknown fields. Narrowed by decision 14. |
| 7 | What are finish and condition values? | The collectible type's own values, described per type. (Review: for Magic, finish comes from the printing, not a type-wide list.) |
| 8 | Two lots with one identity in a file? | Not well-formed. |
| 9 | Does lot order matter? | No. |
| 10 | What does "matched" compare? | FR-7. |
| 11 | What does the format say about restoring a profile? | Only what the fields mean; applying them is #40's. |
| 12 | Where does the document live? | In the repository's documentation, linked from the README, with the schema and examples beside it. |
| 13 | Currency per file or per lot? | Per file; today the instance's setting, unchanged in meaning after #64. |
| 14 | Does a new optional field ever raise the version? (Asked after the review: a version-1 reader that ignores unknown fields would drop later data, such as locations, without a word.) | Yes, when it holds collector-owned data. Only information-only fields are free. The spec that puts a lot in a location (#45) therefore raises the format to version 2. |
| 15 | How precise are times? | To the second, in one UTC form (FR-2). The application stores finer times; whole seconds keep a file readable and make FR-7's comparison exact. |
| 16 | Are the descriptive fields required? | Yes, all four on every lot's entry (FR-6), so Story 1 holds for every well-formed file. A tool that knows only ids can't write a well-formed file; files from other tools are parked. |
| 17 | How is "not recorded" written? | Finish, condition and price paid are always present and `null` when not recorded (FR-5). |
| 18 | Is the coverage table and its CI guard part of this slice? | Yes (FR-9, AC-3.4). It checks names, not meaning; it is how "export covers it" is enforced on later specs. |
| 19 | Are the dates an account and user were created exported? | No. They are facts about the instance (FR-3, FR-9). |
| 20 | Does the plan's reading of the format stand? | Yes: the field names in the format document; a repeated key and a time that is no real moment are not well-formed; accounts are in the coverage table; the writer's name may be any program's; no byte order mark; the collection view is required. |

## Out of Scope (Future Considerations)

- Export a collection as a file (#38), preview an import (#39), apply an import (#40).
- Locations in the format (theme C; the spec that puts a lot in a location extends the format and raises its version).
- Shared and household collections (after 1.0; a version bump, per ADR 0017).
- Per-account currency (#64).
- A source retiring or replacing an entry id (Scryfall's `/migrations` is parked). The descriptive fields let a person repair such a lot by hand until then.
- Files from other tools, and a spreadsheet view of an export.
- Market prices and estimated value.
