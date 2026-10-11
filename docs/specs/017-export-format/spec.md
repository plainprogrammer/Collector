# Feature 017: Export Format

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-10-11
**Last Updated:** 2026-10-11
**Branch:** `017-export-format`
**Issue:** [#37](https://github.com/plainprogrammer/Collector/issues/37)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-11 | Initial draft from the outline the maintainer agreed on 2026-10-11 (file shape, entry reference, contents, deliverables, and eight proposals, listed under [Decisions](#decisions)) |

---

## Problem Statement

Foundation principle 2 says collectors own their data, in open, documented formats. Today a collector's data can't leave an instance or enter another one, and nothing says what such a file would contain. Export ([#38](https://github.com/plainprogrammer/Collector/issues/38)), import preview ([#39](https://github.com/plainprogrammer/Collector/issues/39)) and import apply ([#40](https://github.com/plainprogrammer/Collector/issues/40)) each need one agreed format before any of them is built. The 1.0 test's second check, "an export of that instance has been restored into a fresh instance and matched", has no meaning until "matched" is defined.

> **Inputs.** [ADR 0019](../../adr/0019-lot-as-the-unit-of-ownership.md) (a lot's identity is its entry, finish, condition and price paid), [ADR 0017](../../adr/0017-row-level-tenancy-one-user-per-account.md) (one user per account; shared collections will bump the format's version), [ADR 0018](../../adr/0018-collectible-agnostic-catalog-core.md) (the core names no collectible), spec 004 FR-6 (lots stay addressable by the printing's external id, never an internal one), spec 009 (scanner sittings aren't collection data and aren't exported), `.claude/rules/external-data-and-portability.md` and the [north star](../../north-star.md)'s spec rules. This is an enabling slice: a format definition, releasable alone.

### Glossary

- **The format**: what this spec defines. One file describes one account's collection at one moment.
- **Format document**: the prose description of the format, written for a collector and for a builder.
- **Schema**: a machine-readable statement of what a well-formed file is, kept beside the format document.
- **Example**: a file kept in the repository that the schema is checked against. A valid example must pass; an invalid example must fail for the reason it names.
- **Writer / reader**: any program that produces or consumes a file. Collector's export and import are the first of each; neither is built here.
- **Well-formed**: a property of the file alone, checkable with no catalog and no instance. The schema and the rules in FR-2 to FR-6 decide it.
- **Resolvable**: a property of a file against one instance's catalog: every lot's entry is known there and its finish and condition are allowed for it. A well-formed file may be unresolvable on some instance. Import (#39) decides what happens then; the format only names the distinction.
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
**User mental model:** a collector thinks "my cards, how many, what state they're in and what I paid". A builder thinks in lots (ADR 0019). The file should read as the first and behave as the second.

## User Stories

### Story 1: A collector reads their own file

**As a** collector
**I want** to understand a file of my collection with only the format document beside it
**So that** my data is mine without Collector running

**Acceptance criteria:**

- [ ] **AC-1.1** Given the valid examples When each field that appears in them is looked up in the format document Then every field is described there with its meaning, whether it may be absent or empty, and the values it may take.
- [ ] **AC-1.2** Given a lot in a valid example When it is read without a catalog Then it gives the entry's name, set code, collector number and language alongside the entry identity.
- [ ] **AC-1.3** Given any valid example When its contents are searched Then it holds no password or password digest, no admin flag, no session data, and no internal primary key of an account, user, lot, entry or set.
- [ ] **AC-1.4** Given the format document When a collector reads its opening section Then it says in plain words that the file contains their name and email address, and that it contains everything needed to rebuild their collection.

### Story 2: A builder works from the format alone

**As a** builder of export or import
**I want** the format to answer what a well-formed file is, what identifies a lot, and when two files hold the same collection
**So that** export and import are built against one definition and can be tested against each other

**Acceptance criteria:**

- [ ] **AC-2.1** Given the schema When each valid example is checked against it Then every one passes.
- [ ] **AC-2.2** Given the invalid examples (one per row of [Error Scenarios](#error-scenarios) marked "not well-formed") When each is checked against the schema and the rules of FR-2 to FR-6 Then every one fails, and fails for the reason that example names.
- [ ] **AC-2.3** Given the valid examples taken together When their lots are listed Then they include: a lot with every field set; a lot with no finish, no condition and no price paid; two lots of the same entry that differ only in finish; two that differ only in condition; two that differ only in price paid; a lot with quantity 1 and one with quantity 9,999; and a collection with no lots.
- [ ] **AC-2.4** Given the format document When a builder looks for the definition of lot identity Then it states that a lot is identified by entry identity, finish, condition and price paid, that an absent finish, condition or price is a value of its own (it doesn't match a present one), and that the descriptive fields are never part of identity.
- [ ] **AC-2.5** Given the format document When a builder looks for the definition of "the same collection" Then it gives the rule of FR-7, and the repository holds a pair of examples that are the same collection under it (differing in lot order and in export time) and a pair that are not.
- [ ] **AC-2.6** Given the format document When a builder looks for well-formed and resolvable Then it defines both as the glossary does and states that well-formedness never depends on a catalog.

### Story 3: A later spec extends the format

**As an** author of a spec that adds collector-owned data
**I want** the format to say how it grows and when its version goes up
**So that** "export covers it" is a rule I can follow in the same PR

**Acceptance criteria:**

- [ ] **AC-3.1** Given the format document When an author looks for the versioning rule Then it states FR-8's rule: what raises the version, what doesn't, and what a reader does with a version it doesn't know and with a field it doesn't know.
- [ ] **AC-3.2** Given the format document When an author looks for how to extend the format Then it lists the steps a spec takes in its own PR: describe the new data in the document, add it to the schema and the examples, apply the versioning rule, and record a version bump in the document's version history.
- [ ] **AC-3.3** Given the format document When its version history is read Then it has an entry for version 1 with its date, and names the two changes already expected: locations, and shared collections (which will raise the version, per ADR 0017).
- [ ] **AC-3.4** Given the application's stored data When a kind of data owned by an account exists that the format document neither describes as exported nor lists as left out Then CI fails and names it.
- [ ] **AC-3.5** Given the format document When the list of what is left out is read Then it names scanner sittings and their entries, bulk-edit selections, and bulk-removal undo records, each with its reason.

### Story 4: The format can't drift from its document

**As the** maintainer
**I want** CI to check the document, the schema, the examples and the application against each other
**So that** a change to one that isn't made to the others is caught before merge

**Acceptance criteria:**

- [ ] **AC-4.1** Given the format document and the schema When the version each states is compared Then they are equal, and every valid example carries that version; CI fails otherwise.
- [ ] **AC-4.2** Given the format document's section for Magic When its finishes and conditions are compared with the vocabulary the application registers for Magic Then they are the same values; CI fails otherwise.
- [ ] **AC-4.3** Given the format document When the currencies it says a Collector export may carry are compared with the currencies the application supports Then they are the same codes; CI fails otherwise.
- [ ] **AC-4.4** Given a change that makes a valid example fail the schema, or an invalid example pass When CI runs Then it fails.
- [ ] **AC-4.5** Given the repository after this feature When the README and the ADR index are read Then the README links the format document, and the ADR index lists ADR 0020 and no longer lists the export format as expected.

## Functional Requirements

### FR-1: One file, one account's collection

**Must:**
- Be a single JSON document, encoded as UTF-8.
- Describe exactly one account's collection at one moment.
- Be valid with no lots.

**Must not:**
- Depend on any other file, or on the instance that wrote it, to be read.
- Contain an internal primary key of any record.

### FR-2: Header

**Must:**
- Carry a fixed format name that identifies the file as a Collector export, so that a reader can refuse any other JSON.
- Carry `format_version`, a whole number. This spec defines version 1.
- Carry the moment of export, in UTC, to the second.
- Allow, but not require, the Collector version that wrote the file. It is information only.

**Must not:**
- Give a reader any reason to behave differently on the export time or the writer's version.

### FR-3: Profile

**Must:**
- Carry the collector's name, their email address, and their choice of collection view (grid or table).
- Treat the collection view as a preference: a reader that doesn't know the value uses its own default, and that isn't an error.

**Must not:**
- Carry a password in any form, the admin flag, sessions, or any account or user id.
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
- Carry, for each lot: its entry (FR-6), quantity, finish, condition, price paid, when it was added and when it was last changed.
- Write quantity as a whole number from 1 to 9,999.
- Write finish and condition as the collectible type's own vocabulary values, or as absent. The core of the format gives them no meaning.
- Write price paid as a decimal string with exactly two places and no sign, symbol or separator (`"12.50"`, `"0.00"`, `"1200.00"`), or as absent. Two places apply to every currency, because that is how Collector stores and shows a price. "Absent" and `"0.00"` are different: not recorded, and recorded as free.
- Write both times in UTC, to the second. The time last changed is never earlier than the time added.
- Give the lots no meaningful order.

**Must not:**
- Hold two lots with the same lot identity. Such a file is not well-formed.
- Carry anything about a single copy within a lot (ADR 0019).

### FR-6: Entry reference

**Must:**
- Identify the entry by collectible type and the source's own id for it. For Magic, the type is `mtg` and the id is the Scryfall card id.
- Carry descriptive fields with it: the entry's name, set code, collector number and language.
- State that the descriptive fields are information only. A reader never matches on them, and when they disagree with what the reader's catalog holds for that id, the id wins and the file is still well-formed.
- Keep everything specific to one collectible type (its type key, what its id is, its finishes and conditions) in a section of the format document for that type. Version 1 has one such section, for Magic.

**Must not:**
- Name a collectible in the core part of the format document or in the core of the schema.
- Carry any other catalog data (images, rules text, legalities, prices).

### FR-7: The same collection

Two well-formed files of the same version hold the same collection when all of these are true:

- Their profiles are equal: name, email address and collection view.
- Their currencies are equal.
- Their lots are equal as sets: each lot in one has exactly one lot in the other with the same lot identity, and those two have the same quantity, the same time added and the same time last changed.

**Must not** take into account: the export time, the writer's version, the order of the lots, the descriptive fields, fields the format doesn't define, or how the JSON is laid out.

This is the meaning of "matched" in the 1.0 test's second check.

### FR-8: Versioning

**Must:**
- Raise `format_version` by one for any change that would make a reader of the earlier version misread a file: a change to lot identity or entry identity, a field removed or renamed, or a field given a new meaning or a new form.
- Leave the version alone for: a new optional field, a new collectible type, a new value in a type's finishes or conditions, a new collection view, or a new currency.
- Require a reader to ignore fields it doesn't know.
- Require a reader to refuse a file whose version is higher than any it knows, saying so, and to refuse a file with no version or with another format name.
- Require a reader that meets a collectible type, finish or condition it doesn't know to treat it as not resolvable for that lot, and never to guess or drop it silently.
- Keep a version history in the format document.

**Must not:**
- Change the meaning of version 1 once this feature has merged.

### FR-9: What is left out

**Must** leave out, and list in the format document with the reason:
- Scanner sittings and their entries (working state; spec 009).
- Bulk-edit selections and their marks (working state that lasts for one edit).
- Bulk-removal undo records (a short-lived way to undo; the lots they would restore aren't in the collection).

### FR-10: Deliverables

**Must:**
- Add the format document to the repository's documentation and link it from the README.
- Add the schema and the examples (valid and invalid) beside it.
- Add ADR 0020, "the export format", recording the decision, the alternatives rejected (a spreadsheet file, an id-only reference, descriptive fields as a fallback match, whole-number minor units for price) and why. Update the ADR index.
- Add the automated checks of Stories 2, 3 and 4 to the suite that `bin/ci` runs.
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
- The format carries no credential and no internal id (AC-1.3).
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
| The file isn't JSON, or isn't UTF-8 | Not well-formed |
| The format name is missing or is another name | Not well-formed |
| `format_version` is missing, or isn't a whole number of 1 or more | Not well-formed |
| `format_version` is higher than the reader knows | Well-formed or not is unknown to that reader; it refuses the file (FR-8) |
| The export time, profile, currency or list of lots is missing | Not well-formed |
| The profile has no name or no email address | Not well-formed |
| The currency isn't three uppercase letters | Not well-formed |
| A lot has no entry, or its entry has no collectible type or no id | Not well-formed |
| A lot's entry lacks a descriptive field | Not well-formed |
| A lot's quantity is 0, negative, above 9,999 or not a whole number | Not well-formed |
| A lot's price paid isn't a two-place decimal string (`12.5`, `"12.5"`, `"-1.00"`, `"$3.00"`, `"1,200.00"`) | Not well-formed |
| A lot's time added or last changed is missing, isn't UTC to the second, or the change is earlier than the add | Not well-formed |
| Two lots have the same lot identity | Not well-formed |
| The file holds a field the format doesn't define | Well-formed; the field is ignored |
| The collection view is a value the reader doesn't know | Well-formed; the reader uses its default |
| A lot's collectible type isn't one the reader's instance has | Well-formed, not resolvable there |
| A lot's entry id isn't in the reader's catalog | Well-formed, not resolvable there |
| A lot's finish isn't offered for that entry, or its condition isn't in the type's vocabulary | Well-formed, not resolvable there |
| A descriptive field disagrees with the reader's catalog for that id | Well-formed and resolvable; the id wins |

## Open Questions

None block planning. Three points were settled while writing and go beyond the agreed outline; they stand unless the maintainer changes them at approval:

- **Times are written to the second.** The application stores finer times. Writing whole seconds keeps a file readable and makes FR-7's comparison exact; a restored lot's times equal the file's.
- **Descriptive fields are required** on every lot's entry (name, set code, collector number, language), so Story 1 holds for every well-formed file.
- **AC-3.4's guard.** CI fails when account-owned data exists that the format document neither exports nor lists as left out. It is how "export covers it" is enforced on later specs.

## Decisions

Agreed by the maintainer on 2026-10-11, before this spec was written. ADR 0020 records the format decision itself.

| # | Question | Ruling |
|---|---|---|
| 1 | What shape is the file? | One JSON document. |
| 2 | How does a lot point at its entry? | External id plus descriptive fields; the fields are information only. |
| 3 | What does the file hold besides lots? | The currency of price paid, when each lot was added and last changed, and the collector's profile and preferences. |
| 4 | What does this slice deliver? | The document, ADR 0020, a schema and examples, checked in CI. |
| 5 | How is price paid written? | A two-place decimal string, or absent. |
| 6 | How is the version written, and what raises it? | A whole number from 1; FR-8's rule. |
| 7 | What are finish and condition values? | The collectible type's vocabulary values, listed per type. |
| 8 | Two lots with one identity in a file? | Not well-formed. |
| 9 | Does lot order matter? | No. |
| 10 | What does "matched" compare? | FR-7. |
| 11 | What does the format say about restoring a profile? | Only what the fields mean; applying them is #40's. |
| 12 | Where does the document live? | In the repository's documentation, linked from the README, with the schema and examples beside it. |
| 13 | Currency per file or per lot? | Per file; today the instance's setting, unchanged in meaning after #64. |

## Out of Scope (Future Considerations)

- Export a collection as a file (#38), preview an import (#39), apply an import (#40).
- Locations in the format (theme C; the spec that puts a lot in a location extends the format, and ADR 0019's open question decides whether lot identity changes and the version rises).
- Shared and household collections (after 1.0; a version bump, per ADR 0017).
- Per-account currency (#64).
- A source retiring or replacing an entry id (Scryfall's `/migrations` is parked). The descriptive fields let a person repair such a lot by hand until then.
- Files from other tools, and a spreadsheet view of an export.
- Market prices and estimated value.
