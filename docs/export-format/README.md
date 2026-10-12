# Collector export format

**Format name:** `collector-export`
**Format version:** 1

An export is one file that holds one collector's data: their profile, the currency their prices are in, and every lot in their collection.

- **It is personal.** The file contains your name and your email address. It never contains your password.
- **It is complete.** The file contains everything needed to rebuild your collection on another Collector instance.
- **It is yours.** It is plain JSON, and it names every item so that a person can read it without Collector.

This document defines the format. Export and import are built against it, and so is the check that a restored collection matches the one exported. The decision and the alternatives it rejected are in [ADR 0020](../adr/0020-export-format.md). [`v1.schema.json`](v1.schema.json) states the same rules for a program, and [`examples/`](examples/) holds files that the test suite checks against both.

Two words are used throughout. A **writer** is any program that produces a file, and a **reader** is any program that consumes one.

## The file

A file is a single JSON document ([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)): one object, encoded as UTF-8 with no byte order mark. No object in it holds the same key twice.

A file describes exactly one account's collection at one moment. It needs no other file to be read, and nothing in it is an internal id of the instance that wrote it.

| Field | Value | Meaning |
|---|---|---|
| `format` | The string `collector-export` | Says that the file is a Collector export. A reader refuses a file with any other value. |
| `format_version` | A whole number | The version of this format that the file follows. This document defines version 1. See [Versions](#versions). |
| `exported_at` | A [time](#times) | When the file was written. Information only. |
| `generator` | A string; may be left out | The program that wrote the file, and its version (`Collector 0.2.1`). Information only. |
| `profile` | An object | The collector. See [Profile](#profile). |
| `currency` | A string | The currency of every price in the file. See [Currency](#currency). |
| `lots` | A list | The collection. See [Lots](#lots). It may be empty, and its order has no meaning. |

A reader never behaves differently because of `exported_at` or `generator`.

A whole number may be written with a zero fraction: `1.0` is the same number as `1`.

A collection with nothing in it is a complete file:

```json
{
  "format": "collector-export",
  "format_version": 1,
  "exported_at": "2026-10-11T12:34:56Z",
  "profile": {
    "name": "Grace Example",
    "email_address": "grace@example.test",
    "collection_view": "grid"
  },
  "currency": "EUR",
  "lots": []
}
```

### Times

Every time in a file has one form: [RFC 3339](https://www.rfc-editor.org/rfc/rfc3339) in UTC, with a `Z` and no fraction of a second.

```
2026-10-11T12:34:56Z
```

An offset (`+02:00`), a fraction of a second or a date alone is not well-formed. The time must also be a real moment: 30 February isn't one. A writer that holds a finer time drops the fraction; it doesn't round.

### Not recorded

A collector may leave a lot's finish, condition or price blank. The file writes each of those as `null`. The three fields are always present, and an empty string never stands for "not recorded".

## Profile

| Field | Value | Meaning |
|---|---|---|
| `name` | A string that isn't blank | The collector's name, without spaces around it. |
| `email_address` | A string that isn't blank | The collector's email address. Collector writes it in lower case. |
| `collection_view` | A string that isn't blank | How the collector likes to see their collection: `grid` or `table` today. |

`collection_view` is a preference. A reader that doesn't know its value uses its own default, and that isn't an error.

The format says what these fields mean. It doesn't say what a reader does with them: whether an import changes a name or an email address is the import's decision.

A file never carries a password in any form, a role on the instance, sign-in sessions, or the dates an account or its user were created.

## Currency

`currency` is one [ISO 4217](https://www.iso.org/iso-4217-currency-codes.html) code of three upper-case letters. Every `price_paid` in the file is in that currency; there is no currency per lot.

A file is well-formed with any three upper-case letters. A file written by Collector carries one of these:

`USD`, `CAD`, `AUD`, `NZD`, `EUR`, `GBP`, `CHF`, `SEK`, `NOK`, `DKK`, `PLN`, `CZK`, `JPY`, `CNY`, `KRW`, `SGD`, `HKD`, `BRL`, `MXN`, `ZAR`

The code is the currency in force for the collector when the file is written. Today that is the instance's setting. When it becomes each collector's own choice, the field keeps its meaning and the version doesn't change.

## Lots

A collector owns lots, not single copies ([ADR 0019](../adr/0019-lot-as-the-unit-of-ownership.md)). A lot is a number of copies of one catalog entry that share a finish, a condition and a price paid.

| Field | Value | Meaning |
|---|---|---|
| `entry` | An object | The catalog entry the copies are of. See [Entry](#entry). |
| `quantity` | A whole number from 1 to 9999 | How many copies. |
| `finish` | A string that isn't blank, or `null` | The finish of the copies, as the collectible type names it. |
| `condition` | A string that isn't blank, or `null` | The condition of the copies, as the collectible type names it. |
| `price_paid` | A string in the form below, or `null` | What the collector paid for **one copy**, in the file's currency. |
| `added_at` | A [time](#times) | When the lot was added to the collection. |
| `changed_at` | A [time](#times) | When the lot was last changed. Never earlier than `added_at`. |

All seven fields are always present. The format gives `finish` and `condition` no meaning of its own; the collectible type does ([Collectible types](#collectible-types)). A file says nothing about a single copy within a lot.

### Price paid

`price_paid` is a string of digits, a point, and exactly two more digits. The digits before the point have no leading zero, except a lone `0`.

```
^(0|[1-9][0-9]*)\.[0-9]{2}$
```

`"12.50"`, `"0.00"` and `"1200.00"` are prices. `12.5`, `"12.5"`, `"012.50"`, `"-1.00"`, `"$3.00"` and `"1,200.00"` are not well-formed.

Two places apply to every currency, including those that are usually written without any, because that is how Collector stores and shows a price.

`null` and `"0.00"` are different. `null` is a price that wasn't recorded. `"0.00"` is a copy that was free.

### Entry

| Field | Value | Meaning |
|---|---|---|
| `collectible_type` | A string that isn't blank | The key of the collectible type. |
| `source_id` | A string that isn't blank | The catalog source's own id for the entry, written as the source gives it. |
| `name` | A string that isn't blank | The catalog's name for the entry. It isn't a localized printed name. |
| `set_code` | A string that isn't blank | The code of the set the entry belongs to. |
| `collector_number` | A string that isn't blank | The entry's number within its set. |
| `language` | A string that isn't blank | The language of the entry. |

`collectible_type` and `source_id` together are the **entry identity**. They are the only thing a reader matches an entry on.

The other four are **descriptive fields**. They are information only, so that a person can read the file without a catalog and can repair a lot whose id a source has retired. A reader never matches on them. When they disagree with what the reader's catalog holds for that id, the id wins and the file is still well-formed.

A file carries no other catalog data: no images, rules text or market prices.

## Lot identity

A lot is identified by five values:

1. its entry's `collectible_type`
2. its entry's `source_id`
3. its `finish`
4. its `condition`
5. its `price_paid`

Each is compared character for character. `null` is a value of its own: it matches only `null`.

The descriptive fields, the quantity and the two times are never part of a lot's identity.

A file never holds two lots with the same identity. Copies that share all five values are one lot with a larger quantity.

## Well-formed and resolvable

A file can be wrong in two different ways, and the format keeps them apart.

**Well-formed** is a property of the file alone. It never depends on a catalog or on an instance. A file is well-formed when it passes [`v1.schema.json`](v1.schema.json) and the rules that a schema can't state:

- it is UTF-8 JSON, and no object holds the same key twice
- every time is a real moment
- no lot's `changed_at` is earlier than its `added_at`
- no two lots have the same [identity](#lot-identity)

The schema and these rules are version 1's. A reader looks at `format_version` first: a file whose version is higher than it knows is refused as newer than it can read, not as malformed.

A field that this document doesn't define doesn't make a file malformed. A reader ignores it.

**Resolvable** is a property of a file against one instance's catalog. A well-formed file is resolvable there when, for every lot:

- its entry is in that catalog, retired or not
- its `finish` is `null` or one that the catalog lists for that entry
- its `condition` is `null` or in the collectible type's conditions on that instance

| A well-formed file where | Is |
|---|---|
| a lot's collectible type isn't one the instance has | not resolvable there |
| a lot's entry isn't in the instance's catalog | not resolvable there |
| a lot's entry is in the catalog and retired | resolvable; a lot of a retired entry is still part of a collection |
| a lot's finish isn't one the catalog lists for that entry | not resolvable there |
| a lot's condition isn't one of the type's conditions | not resolvable there |
| a descriptive field disagrees with the catalog | resolvable; the id wins |

The same file may be resolvable on one instance and not on another. What a reader does with a file that isn't well-formed or isn't resolvable is the reader's decision. A reader never guesses at a lot it can't resolve, and never drops it without saying so.

## The same collection

Two well-formed files of the same version hold the same collection when all of these are true:

- Their profiles are equal: `name`, `email_address` and `collection_view`.
- Their currencies are equal.
- Their lots are equal as sets. Each lot in one file has exactly one lot in the other with the same [identity](#lot-identity), and those two have the same `quantity`, `added_at` and `changed_at`.

Every comparison is exact, character for character. A writer writes each value as the instance stores it: the email address in lower case, the name and the email address without spaces around them, the currency in upper case.

These never count: `exported_at`, `generator`, the order of the lots, the descriptive fields, fields this document doesn't define, and how the JSON is laid out.

This is what "matched" means when an export is restored into another instance and exported again. It follows that a reader which restores a collection keeps each lot's `added_at` and `changed_at` as the file gives them.

## Versions

`format_version` is a whole number. It goes up by one when a reader of the earlier version would misread a file or lose a collector's data from it:

- a change to lot identity or entry identity
- a field removed or renamed
- a field given a new meaning or a new form
- a change in which fields are required
- a new field that holds data the collector owns

It doesn't go up for:

- a new optional field that is information only
- a new collectible type
- a new condition for a collectible type, or a finish that a source newly lists
- a new value of `collection_view`
- a new currency

A reader:

- refuses a file whose `format` isn't `collector-export`, or that has no `format_version`
- refuses a file whose `format_version` is higher than any it knows, and says that the file is newer than it can read
- ignores fields it doesn't know. Because a new field of the collector's data raises the version, a field that a reader doesn't know at a version it does know is always information only

The meaning of a version never changes once it has been released.

| Version | Date | Change |
|---|---|---|
| 1 | 2026-10-11 | The first version: profile, currency and lots. |

Two changes are already expected. Locations will add where each lot is kept, which is the collector's data, so they will raise the version to 2. Collections shared by a household will change who owns a lot and will raise it again ([ADR 0017](../adr/0017-row-level-tenancy-one-user-per-account.md)).

## Extending the format

A feature that adds data a collector owns extends the format in the same pull request. It:

1. describes the new data in this document
2. adds it to the schema and to the examples, valid and invalid
3. adds its tables and columns to [Coverage](#coverage)
4. applies the rule in [Versions](#versions) and, if the version goes up, adds a schema for the new version and a line to the version history

The test suite fails until the third step is done: it compares the coverage tables with the application's database.

## Collectible types

Everything in the format that depends on one kind of collectible is in this section. Version 1 has one type.

### Magic: The Gathering (`mtg`)

| Field | For this type |
|---|---|
| `collectible_type` | `mtg` |
| `source_id` | The [Scryfall](https://scryfall.com) card id: one printing of a card in one language. |
| `name` | The card's name as Scryfall gives it. It is the English name whatever the printing's language. |
| `set_code` | Scryfall's set code, in lower case. |
| `collector_number` | The collector number printed on the card, as Scryfall gives it. |
| `language` | Scryfall's language code (`en`, `ja`). |

`condition` is `null` or one of these:

| Condition | Meaning |
|---|---|
| `near_mint` | Near mint |
| `lightly_played` | Lightly played |
| `moderately_played` | Moderately played |
| `heavily_played` | Heavily played |
| `damaged` | Damaged |

`finish` is `null` or one of the finishes that Scryfall lists for that printing. It is an open set: `nonfoil`, `foil` and `etched` are the usual values, and Scryfall may list others. Whether a finish is allowed is a question about one printing in one catalog, so it is part of resolvable and never of well-formed.

A lot of four foil copies, bought for 12.50 each:

```json
{
  "entry": {
    "collectible_type": "mtg",
    "source_id": "00000000-0000-4000-8000-000000000001",
    "name": "Serra Angel",
    "set_code": "dmr",
    "collector_number": "27",
    "language": "en"
  },
  "quantity": 4,
  "finish": "foil",
  "condition": "near_mint",
  "price_paid": "12.50",
  "added_at": "2026-09-30T18:02:11Z",
  "changed_at": "2026-10-02T09:15:00Z"
}
```

The ids in the examples are invented, and the cards are illustrations.

## Coverage

Every table in Collector's database that belongs to an account or to a user is listed here, with what the format does about it. The test suite compares these two tables with the database, so a table or a column that is added without a line here fails the build.

| Table | In the export | Why |
|---|---|---|
| `accounts` | Nothing to export | It holds only its id and its dates; see the columns below. |
| `lots` | Exported | The collection. |
| `users` | Exported | The collector's profile. |
| `bulk_removals` | Left out | A short-lived way to undo a bulk removal. The lots it would restore aren't in the collection. |
| `bulk_selection_marks` | Left out | Working state that lasts for one bulk edit. |
| `bulk_selections` | Left out | Working state that lasts for one bulk edit. |
| `scanner_sitting_entries` | Left out | Working state of one sitting at the scanner. What a sitting adds is already in the lots. |
| `scanner_sittings` | Left out | Working state of one sitting at the scanner. |
| `sessions` | Left out | Sign-in state on one instance. |

| Column | In the file | Why left out |
|---|---|---|
| `accounts.id` | Left out | An internal id. |
| `accounts.created_at` | Left out | A fact about the instance, not about the collection. |
| `accounts.updated_at` | Left out | A fact about the instance, not about the collection. |
| `lots.id` | Left out | An internal id. |
| `lots.account_id` | Left out | An internal id. A file is one account's collection. |
| `lots.catalog_entry_id` | `entry` | |
| `lots.quantity` | `quantity` | |
| `lots.finish` | `finish` | |
| `lots.condition` | `condition` | |
| `lots.price_paid_cents` | `price_paid` | |
| `lots.lot_key` | Left out | Derived from the finish, the condition and the price paid. |
| `lots.created_at` | `added_at` | |
| `lots.updated_at` | `changed_at` | |
| `users.id` | Left out | An internal id. |
| `users.account_id` | Left out | An internal id. |
| `users.name` | `name` | |
| `users.email_address` | `email_address` | |
| `users.password_digest` | Left out | A credential. |
| `users.admin` | Left out | A role on one instance, not the collector's data. |
| `users.collection_view` | `collection_view` | |
| `users.created_at` | Left out | A fact about the instance, not about the collection. |
| `users.updated_at` | Left out | A fact about the instance, not about the collection. |

`lots.catalog_entry_id` is an internal id too. The file writes the entry it points at by its type and source id.

`currency` comes from no table yet. It is the instance's setting.

## Examples

| Folder | Holds |
|---|---|
| [`examples/valid/`](examples/valid/) | Well-formed files: a collection that shows every shape a lot can take, and an empty one. |
| [`examples/invalid/`](examples/invalid/) | Files that aren't well-formed, each with one thing wrong. |
| [`examples/comparison/`](examples/comparison/) | A base file, a file that holds the same collection, and files that each differ from the base in one thing that counts. |

[`examples/problems.json`](examples/problems.json) names, for each invalid file, why it isn't well-formed (`why`), the rule it breaks (`rule`) and where (`at`, a [JSON Pointer](https://www.rfc-editor.org/rfc/rfc6901) into the file, empty for the whole file).

A `rule` is the schema keyword that fails (`required`, `const`, `pattern`, `minimum`, `maximum`, `type`), or one of these:

| Rule | Meaning |
|---|---|
| `not_utf8` | The file isn't UTF-8. |
| `not_json` | The file isn't JSON, starts with a byte order mark, or has an object that holds the same key twice. |
| `not_a_time` | A time has the right form but isn't a real moment. |
| `changed_before_added` | A lot's `changed_at` is earlier than its `added_at`. |
| `duplicate_lot` | A lot has the same identity as an earlier lot in the file. |
