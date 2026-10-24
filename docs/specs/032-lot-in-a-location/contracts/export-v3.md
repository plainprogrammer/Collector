# Contract: export format version 3

**Spec:** [spec.md](../spec.md) Stories 8 to 11 · **Plan:** [../plan.md](../plan.md) · The document is `docs/export-format/README.md`; this file says what changes in it and in the files beside it.

Version 3 adds one required field to each lot, `location`, and nothing else. Versions 1 and 2, their schemas, their examples and the app's copies of them are not touched (AC-9.2).

## The lot, version 3

| Field | Value | Meaning |
|---|---|---|
| `location` | A string that follows the [Names](#names) rules, or `null`; **always present** | The name of the location the lot is in, as the instance stores it (NFC), or `null` for a lot in none. Never `""`. |

All eight fields are always present. A version 3 lot without `location` is **not well-formed** (`required`, at `/lots/<i>/location`); a reader never reads it as `null` (FR-3). A version 1 or 2 lot says nothing about its place; Collector reads such a lot as unplaced because applying a file is a restore (decision 7). A `location` on a version 1 or 2 lot is an unknown field and is ignored (AC-9.8).

## Names

A lot's `location` follows exactly the rules of a location's `name` (spec 029): 1 to 60 code points, no Cc or Cf character, no White_Space other than single U+0020 between words, not padded. A reader normalises it on read (NFC, trim, collapse) as it does a location's name, so a lot written in NFD is well-formed.

## Rules a schema can't state (document and `ExportFormat::Rules`)

| Rule | Version | Fails when | Pointer |
|---|---|---|---|
| `duplicate_lot` | all; judged on **six** values from version 3 | two lots have the same entry, finish, condition, price paid and location **comparison key**. "Box" and "box" are one place. | `/lots/<i>` of the later lot |
| `unknown_location` (**new**) | 3 | a lot's `location` is a string whose comparison key is no listed location's | `/lots/<i>/location` |

`unknown_location` is judged only for a lot whose `location` is a string that passed the schema, and only when the file's `locations` list itself passed (an over-long list is refused at `/locations` and not walked again, spec 029 review M1). A row it fails keeps a readable identity (the key of its location) so the preview can say which held lot it matches, as `duplicate_lot` rows do (AC-10.3). It is added to `ExportFormat::Rules::RULES`, and the examples must include an invalid file for it.

## Lot identity, version 3

A lot is identified by six values: its entry's `collectible_type`, its entry's `source_id`, its `finish`, its `condition`, its `price_paid`, its `location`. The location is compared by comparison key; `null` matches only `null`. For versions 1 and 2 the sixth value is `null` for every lot. A file never holds two lots with the same identity; copies that share all six are one lot with a larger quantity.

## The same collection, version 3

Lots are equal as sets: each lot in one file has exactly one lot in the other with the same identity (six values), and those two have the same `quantity`, `added_at` and `changed_at`. Two files whose lots differ only in a lot's location are different collections. "box" against "Box" on a lot are different here, as location names are (the comparison is exact, character for character), although a reader treats them as one place when it matches and `duplicate_lot` treats them as one lot. (The document says this in its "The same collection" section, and the suite's comparison keys a lot by its location string as written, not by the comparison key.) The order of the lots never counts.

## `v3.schema.json`

A copy of `v2.schema.json` with:

- `$id` `urn:collector:export-format:v3`, `title` "Collector export, format version 3", `format_version` `const` 3;
- `description` extended: no two lots have the same identity (entry, finish, condition, price paid and location once the names are normalised and case folded), and a lot's location is one of the file's locations;
- `$defs/lot` gains `location` in `required` (after `price_paid`) and in `properties`: `{ "$ref": "#/$defs/lot_location" }`;
- a new `$defs/lot_location`: the same `description`, `minLength`, `maxLength` and `pattern` as `location_name`, with `"type": ["string", "null"]` (the string keywords don't apply to `null`; as `recorded_text` does for `finish`).

`docs/export-format/v3.schema.json` and `app/models/export_format/v3.schema.json` are byte-identical (ADR 0021); `spec/models/export_format/rules_spec.rb` already compares each pair and gains version 3.

## Document changes (AC-9.1)

Each is made in `docs/export-format/README.md` and verified by reading, plus the one spec that reads the document (`spec/export_format_document_spec.rb`, the exception in `.claude/rules/testing.md`):

| Where | Change |
|---|---|
| Header | "Format version: 3" |
| Intro line | names `v3.schema.json`; "one for each version" |
| The file, `format_version` row | "1, 2 or 3" |
| The file, `locations` row | "From version 2: …" (was "Version 2 only") |
| Lots | the lot "share a finish, a condition, a price paid **and a location**"; the table gains `location`; "All eight fields are always present" |
| Lot identity | six values; "share all six values" |
| Locations | "in version 2 a lot carries no reference to one" gains "from version 3, a lot's `location` names one" |
| Well-formed and resolvable | "checks against all three versions"; the rule list gains `unknown_location` and the six-value `duplicate_lot`; "the rules are the same for all versions, with…" |
| The same collection | lots equal on six values; the comparison of a lot's location (exact, as for names; a reader's matching and `duplicate_lot` use the comparison key) |
| Versions | row for version 3 (2026-10-23, "Lots in locations: each lot gains the required `location`, the rule `unknown_location`, and lot identity has six values"); the expected-changes sentence rewritten (version 3 is no longer expected; the next is currency per account, #64, and households, ADR 0017) |
| Coverage | `lots.location_id` → `location`; `lots.lot_key`'s "Why" adds the place |
| Examples | the rule list gains the version 3 examples below |

## Examples (`docs/export-format/examples/`)

| File | Kind | Shows |
|---|---|---|
| `valid/collection-v3.json` | valid | lots in two locations, one printing in two locations (two lots), an unplaced lot, an empty location |
| `valid/empty-v3.json` | valid | no locations, no lots |
| `valid/lot-location-nfd.json` | valid | a lot whose location is written in NFD for a listed NFC name, and one in another case ("box" for "Box"); re-exports with the stored spelling, so it is outside the round-trip checks (AC-9.4) |
| `valid/lot-location-60.json` | valid | a lot in a location of 60 code points |
| `invalid/lot-location-missing.json` | invalid | a version 3 lot with no `location` (`required`) |
| `invalid/lot-location-number.json`, `-empty.json`, `-padded.json`, `-double-space.json`, `-tab.json`, `-control.json`, `-61.json` | invalid | the other forms AC-9.5 lists (`type`, `minLength`, `pattern`, `maxLength`) |
| `invalid/lot-location-unlisted.json` | invalid | `unknown_location` |
| `invalid/duplicate-lot-location-case.json` | invalid | `duplicate_lot` on six values: two lots of one printing, finish, condition and price in locations that differ only by case |
| `comparison/v3-base.json`, `v3-same.json`, `v3-different-lot-location.json`, `v3-different-lot-location-case.json` | comparison | files whose lots differ only in a lot's location are different; "box" against "Box" are different; the same lots in another order are the same (AC-9.6) |

`examples/problems.json` gains one entry per invalid file (`why`, `rule`, `at`).

## What the application does with it

| Component | Version 3 |
|---|---|
| `CollectionExport` | `FORMAT_VERSION = 3`; the lots are read with `lots.location_id` and each lot's `location` is the name of that id in the one read of the account's locations (never a second lookup, so a rename mid-export can't leave a lot naming an unlisted location; if an id is missing the reads repeat, at most 3 times), `null` when unplaced; the export stays deterministic (AC-8.5) |
| `ExportFormat::Rules` | `VERSIONS = [1, 2, 3]`; `identity(lot, version)` returns six values; `unknown_location` (not judged when `/locations` failed); `duplicate_lot` on six; a `location` pointer is an identity field |
| `CollectionImport` | reads 1 to 3; "This instance reads version 3."; held lots carry their place's key as the sixth identity value; a version 1 or 2 file's rows have `nil` there; a version 3 duplicate row reads "…, price and location as row M"; "in <location>" goes on the removed lots and the problem rows, the two lists the preview has (spec 1.0.2) |
| `CollectionImport::Apply` | the order and the keys of Phase 7 |
