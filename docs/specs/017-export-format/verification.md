# Verification: Export Format

**Spec:** [spec.md](spec.md) | **Plan:** [plan.md](plan.md)

Run on 2026-10-11, on commit `e663f80` (every phase of the plan committed). Before the first phase the suite had 1119 examples, 0 failures, 1 pending.

## Automated

| Check | Command | Result |
|---|---|---|
| The format's examples and rules (AC-1.3, AC-1.4, AC-2.1, AC-2.2, AC-2.3, AC-2.5) | `bin/rspec spec/export_format_examples_spec.rb` | 16 examples, 0 failures |
| The document against the schema, examples and application (AC-1.1, AC-3.4, AC-3.5, AC-4.1 to AC-4.4) | `bin/rspec spec/export_format_document_spec.rb` | 11 examples, 0 failures |
| The whole suite | `bin/rspec` (as `bin/ci`'s last step) | 1146 examples, 0 failures, 1 pending: 27 more than before. The pending example is `spec/system/art_agreement_spec.rb`, which needs `COLLECTOR_ART_AGREEMENT` and was pending before |
| Local CI | `bin/ci` | Every step passed, in 4m24s: Setup; Style: Ruby (`454 files inspected, no offenses detected`); Brakeman (`No warnings found`); Gem audit (`No vulnerabilities found`); Importmap audit; Tests: RSpec |

Each phase's red and green states were the ones the plan states:

| Phase | Red | Green |
|---|---|---|
| 1 | 16 examples, 16 failures, each `NameError: uninitialized constant ExportFormatRules` | 16 examples, 0 failures |
| 2 | 9 examples, 9 failures, each `Errno::ENOENT` for the document | 25 examples, 0 failures (both files) |
| 3 | 11 examples, 2 failures (the README link, the ADR index) | 11 examples, 0 failures |

The 32 example files match the plan's checksums (`sha256sum -c --quiet`: no output, exit 0), and the committed spec files, rules module, schema, document and ADR are byte-identical to the files the plan was tested with. `bundle install` resolved `json_schemer 2.5.0`, `hana 1.3.7` and `simpleidn 0.3.0`: 11 lines added to `Gemfile.lock`, none removed.

## By reading

| Criterion | Where in `docs/export-format/README.md` | Found |
|---|---|---|
| AC-1.2: each field's meaning, whether it may be `null`, its values; price paid is per copy | The field tables under "The file", "Profile", "Lots" and "Entry"; "Not recorded"; "Price paid" | Every field table has a Value and a Meaning column. `finish`, `condition` and `price_paid` each read "…, or `null`", and "Not recorded" says "The three fields are always present, and an empty string never stands for 'not recorded'." `price_paid`: "What the collector paid for **one copy**, in the file's currency." |
| AC-1.5: the opening says the file holds the name and email address, and everything needed to rebuild the collection | The opening list | "**It is personal.** The file contains your name and your email address. It never contains your password." and "**It is complete.** The file contains everything needed to rebuild your collection on another Collector instance." |
| AC-2.4: lot identity; `null` is a value of its own; descriptive fields never part of it | "Lot identity" | Lists the five values, then: "`null` is a value of its own: it matches only `null`." and "The descriptive fields, the quantity and the two times are never part of a lot's identity." |
| AC-2.6: the same collection, well-formed and resolvable; well-formed never depends on a catalog | "The same collection"; "Well-formed and resolvable" | "Two well-formed files of the same version hold the same collection when all of these are true: …" with FR-7's three conditions and its list of what never counts. "**Well-formed** is a property of the file alone. It never depends on a catalog or on an instance." "**Resolvable** is a property of a file against one instance's catalog." |
| AC-3.1: what raises the version, what doesn't, what a reader does with an unknown version and an unknown field | "Versions" | "It goes up by one when a reader of the earlier version would misread a file or lose a collector's data from it:" (five cases, the last "a new field that holds data the collector owns"), "It doesn't go up for:" (five cases), and "A reader: refuses a file whose `format_version` is higher than any it knows, and says that the file is newer than it can read … ignores fields it doesn't know." |
| AC-3.2: the steps a spec takes to extend the format | "Extending the format" | Four numbered steps: describe the data in the document; add it to the schema and the examples; add its tables and columns to Coverage; apply the rule in Versions and, if the version goes up, add a schema for the new version and a line to the version history. |
| AC-3.3: version 1 with its date; locations and shared collections expected | "Versions": the history table and the paragraph after it | "\| 1 \| 2026-10-11 \| The first version: profile, currency and lots. \|" and "Locations will add where each lot is kept … so they will raise the version to 2. Collections shared by a household will change who owns a lot and will raise it again (ADR 0017)." |

## Not checked here

- Whether export writes this format and import reads it: #38, #39 and #40.
- The guard compares names. It can't tell whether a column's mapping is right.
- GitHub's rendering of the format document and of its relative links. Nothing was pushed.
- CI on GitHub (the image builds and their smoke test). It runs on a pull request.
