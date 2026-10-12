# 0020: The export format is one versioned JSON document keyed by source ids

## Status

Accepted (2026-10-11; the maintainer ruled on each point in spec 017: decisions 1 to 19 with the spec and 20 with the plan).

**Date:** 2026-10-11
**Feature:** 017-export-format

## Context

Foundation principle 2 says collectors own their data in open, documented formats. Export, import preview and import apply (roadmap items 3 to 5) each need one agreed format before any of them is built, and the 1.0 test's second check, "an export of that instance has been restored into a fresh instance and matched", needs a definition of "matched". [Spec 017](../specs/017-export-format/spec.md) defines the format; this ADR records the decision and what was rejected.

What the format has to describe is small today:

- A collector owns lots ([ADR 0019](0019-lot-as-the-unit-of-ownership.md)): a quantity of one catalog entry with the same finish, condition and price paid. A lot points at its entry by an internal id, and the catalog keys each entry by the source's own id (for Magic, the Scryfall card id).
- An account has one user ([ADR 0017](0017-row-level-tenancy-one-user-per-account.md)), with a name, an email address and a choice of collection view.
- Price paid is stored in hundredths for every currency, and the currency is one instance setting.

Two changes are known to be coming: locations (roadmap theme C), and collections shared by a household after 1.0, for which ADR 0017 already accepts a format bump.

## Options considered

### The shape of the file

- **One JSON document (chosen).** A header, the profile, the currency and a list of lots. Nested data has somewhere to go when locations and shared collections arrive, and the header carries the version.
- **CSV, one row per lot.** It opens in a spreadsheet, but it has no natural place for the version, the currency or the profile, and a lot divided among places doesn't fit a row.
- **JSON with a CSV view beside it.** Two representations to specify and keep in step, for a convenience that a later feature can add without changing this format.

### How a lot points at its entry

- **The source's id, with descriptive fields beside it (chosen).** The collectible type and the source id identify the entry. The name, set code, collector number and language are information only.
- **The source's id alone.** The smallest file, but a person can't read it without a catalog, and a lot whose id a source later retires leaves no clue to what it was.
- **Descriptive fields as a fallback match.** More forgiving, but it makes the set code, number and language part of identity, so two readers with different catalogs could resolve one file to different entries.

### How price paid is written

- **A decimal string with two places (chosen).** `"12.50"` is what the collector typed and what the app shows.
- **A whole number of minor units.** Exact as well, but Collector stores hundredths for every currency, including those with no minor unit. `1250` in a file whose currency is `JPY` would read as 1,250 yen to anyone who knows ISO 4217 and mean 12.50.

### What raises the version

- **A change that makes an older reader misread a file or lose the collector's data from it (chosen).** That includes a new field that holds data the collector owns.
- **Only a change that makes an older reader misread a file.** New optional fields would be free. A version-1 reader ignores fields it doesn't know, so it would drop a later release's locations without a word and report the same collection.

## Decision

The format is a single JSON document, encoded as UTF-8, that describes one account's collection at one moment. It is defined in [`docs/export-format/README.md`](../export-format/README.md), with a JSON Schema (draft 2020-12) and example files beside it.

- **Header:** the format name `collector-export`, `format_version` (a whole number, 1 today), the time of export and, optionally, the program that wrote it.
- **Contents:** the collector's profile (name, email address, collection view), one ISO 4217 currency for the file, and the lots.
- **A lot:** its entry, quantity, finish, condition, price paid per copy, and when it was added and last changed. Finish, condition and price paid are always present, and `null` when not recorded.
- **An entry:** identified by collectible type and source id, with four descriptive fields that a reader never matches on.
- **No internal primary key appears anywhere.** Lot identity in a file is the entry identity, finish, condition and price paid, as ADR 0019 defines it, and a file never holds two lots with the same identity.
- **Times** are RFC 3339 in UTC to the second.
- **Well-formed and resolvable are kept apart.** Whether a file is well-formed never depends on a catalog. Whether its entries, finishes and conditions exist is a question about one instance.
- **The same collection** is defined by the profile, the currency and the lots as sets. That definition is what "matched" means in the 1.0 test.
- **The version** rises by the rule chosen above. A reader refuses a version higher than it knows and ignores fields it doesn't know.

The document, the schema and the examples are checked against each other and against the application by the test suite. That includes a coverage table of every table that belongs to an account or to a user, which fails the build when a table or column is added without a line in the format document.

## Consequences

- Export and import are built against one definition, and a round trip can be tested by comparing two files.
- The file carries a name and an email address, so export has to treat it as personal data.
- The descriptive fields make the file larger than it needs to be for Collector alone. That is the price of a file a person can read and repair.
- The spec that puts a lot in a location raises the format to version 2, whichever way its own ADR decides ADR 0019's open question.
- A file can only be written by a program that knows the descriptive fields. A tool that knows only source ids can't write a well-formed file. Importing files from other tools is parked until after 1.0.
- Times lose their fraction of a second. A restored lot's times equal the file's, not the original instance's to the microsecond.
- The format, the schema and the examples live under `docs/`, which the published image leaves out. The suite checks the schema with `json_schemer`, a test-only gem. An import that validates files inside the running app has to decide where its copy of the rules lives.
- The coverage check compares names, not meaning. It catches a table or column that nobody accounted for; it can't tell whether the account given is right.
- A source that retires or replaces an id still leaves a lot that doesn't resolve. The descriptive fields let a person repair it; nothing does so automatically.
