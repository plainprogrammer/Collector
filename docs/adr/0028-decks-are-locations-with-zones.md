# 0028: A deck is a location whose zones are child locations; formats come from the collectible extension

## Status

Accepted (2026-11-10). Written with spec 062 as Proposed; the maintainer ruled its data shapes on 2026-11-10 (D1: the schema, D2: how a lot names a zone in a file, D3: how decks appear in a file, D4: the collectible type beside the format, D6: a zone's label and the safe edit of a lot in a zone, D7: the older-file refusals) and approved the spec (v0.5.0) and the plan (v0.3.0) the same day. It builds on [ADR 0025](0025-a-lots-location-is-part-of-its-identity.md) and [ADR 0023](0023-locations-make-export-format-version-2.md), which stay Accepted; the seam follows [ADR 0018](0018-collectible-agnostic-catalog-core.md).

**Date:** 2026-11-10
**Feature:** 062-create-rename-remove-a-deck

## Context

The design for 1.0 says a deck is a kind of location: a copy is in one place at a time, so a copy in a deck is not free for another deck ([decks and locations issue design](../superpowers/specs/2026-11-09-decks-and-locations-issues-design.md), decisions 2, 3 and 9). A deck has sections, called zones, that its format fixes (Main, Sideboard, Considering; Commander has its own), and a copy sits in a zone.

Facts that shape the choice:

- A lot's identity ends in a location's id (`lot_key`, ADR 0025), five places build that key, and an account never holds two lots of one identity. A lot's place is one value.
- A location is a name and nothing else today, unique per account by comparison key (`Location::Name`, spec 029). Every deck would want a "Main", so a zone's name cannot be unique per account.
- The export names a location by its name, never by an internal id (ADR 0020), and the apply replaces the collection's places and lots in one all-or-nothing transaction (spec 028).
- The core names no collectible (ADR 0018, `spec/*_core_spec.rb`). Formats (Standard, Modern, Commander) are a game's, and the same key can exist in several games.
- Self-hosters keep whatever shape this fixes: the schema, the file's version 4 and how a zone is identified outlive the release.
- SQLite treats NULLs in a unique index as distinct, so a unique index on `(account_id, parent_id, name_key)` would let two top-level locations share a name.

## Options considered

### Option A: A zone is a child location row (chosen)

A deck is a `locations` row of kind `deck` plus a `decks` row (the format); each zone is a `locations` row of kind `deck_zone` whose `parent_id` is the deck's location, with a zone key and its stored name. A lot's `location_id` points at a zone.

**Pros:** a lot's identity, its key, the restrict foreign key, the merge rules, bulk move, the filter and the card page need no new idea: a zone is a location with an id. A copy is in one place by construction. Names scope by parent with two partial unique indexes. **Cons:** every surface that lists "locations" must now say which kind (places only, until the pickers learn zones); the export needs a way to name a zone that is not a bare name.

### Option B: A `zone` column on lots

A lot is in a deck (a location) and has a zone key.

**Cons:** the zone becomes a seventh part of a lot's identity, the key grows a new segment, five builders change, and "a lot never sits directly in a deck" becomes a rule to remember instead of a shape. Rejected.

### Option C: A separate `deck_zones` table

Zones in their own table, a lot pointing at either a location or a zone.

**Cons:** two foreign keys on a lot, one of them null, a lot in two places by a bug, and every reader of a lot's place reads two columns. Rejected.

### Where a deck's format is stored

- **Option S1 (chosen): a `decks` table** (`account_id`, `location_id` unique, `collectible_type`, `format`), as the issue asks. The location stays a name and a place in the tree; the deck's own data sits beside it, and a later kind's data (a `loan`'s borrower) gets its own table the same way.
- **Option S2:** `format` and `collectible_type` as nullable columns on `locations`. One fewer table, but two more columns that are null for every place and every zone, and a later kind adds more. Rejected (the models rule: game-specific attributes don't go on core tables).

### Formats: where they live

- **Option F1: formats in the core.** Rejected: the core would name a game's formats.
- **Option F2: the collectible extension registers formats and zones through a seam the core asks (chosen).** The extension gives, per collectible type, its formats (key, name, default) and each format's zones (key, name, order), beside the vocabulary the core already asks it for (`Catalog.collecting`).
- **Option F3: formats as data rows, edited by the collector.** Deferred: collector-defined zones and homebrew formats are 2.0 (the issue design).

### Naming a zone in a file

- **Option N1 (chosen): a lot's `location` is `null`, a place's name, or `{ "deck": <name>, "zone": <key> }`.** One field, so a lot is in one place by construction, and the shape has room for a later kind (a `loan` object).
- **Option N2:** a second field `zone` beside `location`, with a rule that not both are set. More fields, one more rule, and two places to look.
- **Option N3:** every location in one list with a kind, and lots pointing at it by position. Position is an internal id by another name.

### Does a file list a deck's zones

- **Option Z1 (chosen): no.** A file lists decks by name, collectible type and format; the zones are the format's, so a lot naming a zone its deck's format lacks is a row problem (`unknown_zone`). There is no empty-zone state to carry, and nothing redundant to disagree.
- **Option Z2:** each deck lists its zones. Redundant today, since zones are fixed per format; the later collector-defined zones can add a list at the version that introduces them.

### Format key and collectible type

- **Option K1 (chosen): `decks.collectible_type` beside `decks.format`,** written in the file too, as an entry carries its type. A key is unique within its type, so two games can both have `standard`.
- **Option K2:** a bare key unique across every collectible, a boot-time rule. A rule someone must remember, and a file cannot say whose `standard` it means.

## Decision

- **Schema.** `locations` gains `kind` (`place`, `deck`, `deck_zone`; every existing row is a place), `parent_id` (set only for a zone; a foreign key and an index; a zone's parent is a deck, so the tree is one level deep) and `zone` (the zone key, set only for a zone). `decks` has `account_id`, `location_id` (unique), `collectible_type` and `format`. Check constraints state what the schema can: the kinds, `parent_id` set exactly for a zone, `zone` set only for a zone. Models state the rest (a zone's parent is a deck of the account, a zone key is one of the format's).
- **Names scope by parent.** The unique index on `(account_id, name_key)` becomes two partial unique indexes: top-level (`account_id`, `name_key` where `parent_id` is null), shared by places and decks, and zones (`parent_id`, `name_key` where `parent_id` is not null). Every deck can have a "Main".
- **A lot sits in a zone only.** `lots.location_id` may name a place or a zone, never a deck's own row; `lot_key` is unchanged. The database cannot state that (SQLite needs a trigger), so the model refuses it and every write path takes its ids from a lookup that can never return a deck's row (places-only, zones-only, or every kind keyed by the kind). The surfaces that choose or list a place (the locations page, the lot form, Move copies, bulk Move to…, number entry, the scanner sitting, the collection filter, the export's `locations`, the import's file and held locations) list `kind = place` until the pickers and the filter learn zones (#252); the readers that follow a lot to where it is (`Lot`'s validation, the card page, the grid and table, a bulk removal's undo, the number-entry and scanner lists, the export's and import's lot rows, the apply's lot placement and the refusal pages) accept every kind, the apply resolving a place key among places and a zone by its (deck key, zone key) pair. A zone is shown as "Deck › Zone" wherever a lot's place is shown, through one label.
- **The core knows one zone key.** Every format has a Considering zone (the issue design), and its key, `considering`, is the one zone key the core names, so a later change of format can move cards there; the core names no other zone and no format.
- **The 500 limit counts top-level locations** (places and decks together); zones do not count. The refusal says so: "You can have at most 500 places and decks together." (maintainer, 2026-11-10; spec 062 AC-1.7a). In a file, places plus decks may not exceed 500.
- **A deck is removed only while empty.** Removing deletes its zones and rows; it is refused while any zone holds a lot, by the application (the refusal page) and by the restrict foreign key.
- **Formats from the extension.** The extension registers, per collectible type, its formats and their zones; the core asks the seam and never names a format. MTG registers Casual (default), Standard, Pioneer, Modern, Legacy, Vintage, Pauper (Main, Sideboard, Considering) and Commander (Commander, Main, Considering). A deck's format is stored as the key and its collectible type beside it.
- **Export format version 4.** `decks` is a new required top-level list of `{ name, collectible_type, format }`; `locations` stays the places; a lot's `location` is `null`, a place's name or `{ deck, zone }`; zones are not listed (Z1). A deck is identified by the comparison key of its name, shared with places; a zone by its deck's key and its zone key. New well-formedness rules: `too_many_locations`; `duplicate_location` and `unknown_location` extend across decks. `unknown_zone` and `unknown_format` are the reader's resolvable checks, as `unknown_type` is. The preview and the apply read versions 1 to 4; a file of version 1 to 3 leaves the decks as they are, its lots read as in places or none, and the copies held in the decks' zones are therefore removed by applying it (the preview says so and the removal needs the checkbox).
- **The apply replaces decks like it replaces places:** matched by comparison key (added, renamed, format changed, unchanged, removed), removals before additions so a key can change kind, removed lots before the zones that held them.

## Consequences

- A lot in a zone merges, moves, bulk-moves, changes condition, is removed and restored exactly as a lot in a place does; the five key builders do not change, and a spec per builder proves a zone's id ends the key.
- Surfaces that read `account.locations` must say `places`: the locations page, the lot form, Move copies, bulk Move to…, number entry, the scanner sitting, the collection filter, the export's `locations`, the import's held locations. A spec per surface keeps a deck and a zone out.
- A zone's name is stored, so a later release that renames a zone's display name leaves existing decks with the old text until a migration says otherwise. Accepted: the key is the identity, and the name is a label.
- Zones are stored rows, created with the deck, and a file does not list them. A release that adds a zone to a format leaves the decks already held without its row until an apply (which creates the zone rows every listed deck's format has) or a data migration; a file whose lot names that zone passes `unknown_zone`, because the format has it, and the apply finds or creates the row. A release that removes a zone from a format makes a lot in that zone `unknown_zone` for newer readers: a change of that kind needs a migration and an upgrade note.
- Two accounts' decks, formats and counts never meet; the operator sees none (hosted-door rule 2).
- The migration adds columns, check constraints, a table and indexes, changes no value, never copies `locations` inside a transaction (ADR 0025's precedent), and its rollback is refused while a deck exists. Cost per account: one `decks` row and one location row per deck, one row per zone (three or so), no job or cache.
- `unknown_zone` and `unknown_format` depend on one instance's registrations, so they are the reader's resolvable checks (with `unknown_type`), not rules of the format; the format's well-formedness rules gain `too_many_locations` and extend `duplicate_location` and `unknown_location` across decks.
- A deck name over 60 code points after NFC is a rule of the format (`maxLength` at `/decks/<i>/name`, `ExportFormat::Rules`) where a place's long name is the reader's check (`long_location`): every invalid example of the format must fail through `Rules.problems`, and the outcome for a collector is the same (spec 062 AC-6.7b).
- An older file (version 1 to 3) is refused when one of its places has a held deck's name or when its places and the held decks pass 500 (spec 062 AC-7.4a, AC-7.4b; maintainer D7, 2026-11-10).
- Adding a second collectible's formats needs no change to the core. A later `loan` kind adds a value of `kind`, an object shape of a lot's `location`, and a version.
- This ADR supersedes spec 029 decision 4's "a location is a name and nothing else" for locations as a whole (places stay a name only) and spec 029 decision 7's count; it leaves ADR 0025 and ADR 0023 Accepted and adds the sixth lot-identity value's second form to them.
