# Feature 058: Store Each Card's Mana Value from the Catalog

**Status:** Approved by the maintainer on 2026-11-10 (Gate A, as written, including decision 3's `reapply?` reason), relayed by the coordinator
**Version:** 1.0.3
**Created:** 2026-11-10
**Last Updated:** 2026-11-10
**Branch:** `058-mtg-mana-value`
**Issue:** [#250](https://github.com/plainprogrammer/Collector/issues/250) (roadmap 14d)
**Plan:** `plan.md` (while the feature is in progress)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-10 | Written from issue #250, the [decks and locations issue design](../../superpowers/specs/2026-11-09-decks-and-locations-issues-design.md) ("Data notes found in the code") and a read of Scryfall's real data (halves, a one-million value, and a layout that has no top-level `cmc`) |
| 1.0.1 | 2026-11-10 | Spec review round 1 (Opus, APPROVE WITH CHANGES, nothing blocking): decision 2 reads `Numeric` only (`Float()` raises and would make a record malformed) and always carries the key; AC-2.5 and AC-2.7 reworded; AC-3.6 observable through `made_progress?` and `updated_at`; AC-3.8 narrowed; the partial-failure Error Scenarios row corrected; Interactions names the real existing specs and fixtures; document ACs say they are verified by reading |
| 1.0.2 | 2026-11-10 | Approved by the maintainer as written (Gate A); the Open Questions' three author calls (float, front face, the `reapply?` reason) are confirmed. No change to the text |
| 1.0.3 | 2026-11-10 | Plan review round 2 (Opus, APPROVE WITH CHANGES, nothing blocking): the reversibility command is `bin/rails db:migrate:redo:primary` (decision 4, AC-1.3, the Error Scenarios row), because plain `db:migrate:redo` aborts in this four-database app; the intent is unchanged |

---

## Problem Statement

`mtg_cards` (`MTG::Card`, what a card's printings share) holds a card's mana cost as text, its type line, rules text, colours, colour identity and keywords. It holds no **mana value** (Scryfall's `cmc`: the number a cost adds up to), and `MTG::Scryfall::Mapper` never reads it. The deck shape panel ([#256](https://github.com/plainprogrammer/Collector/issues/256)) draws a curve of cards by mana value and must do it from local data, since pages never call Scryfall (`catalog-core.md`, Invariants). Parsing `mana_cost` is no substitute: an X, a hybrid or Phyrexian symbol, a split or adjusted card and a card with no cost each need a rule Scryfall has already applied.

**What Scryfall's data holds** (read from `api.scryfall.com` on 2026-11-10, not assumed):

| Card | `cmc` |
|---|---|
| A normal card (Lightning Bolt) | `1.0`: a float, whole for nearly every card |
| Little Girl (Unhinged) | `0.5`: some "funny" cards have halves |
| Gleemax (Unhinged) | `1000000.0`: large, still exact |
| A token or a land | `0.0`: zero is a value, not a blank |
| A `reversible_card` (Secret Lair, e.g. Ajani Goldmane // Ajani Goldmane) | **absent at the top level**; each entry of `card_faces` has its own `cmc` (`4.0` and `4.0`) |

The last row matters: the mapper reads most top-level fields with `fetch`, which raises on a missing key and makes the record `Malformed` (the refresh skips it). A mapper that did `card.fetch("cmc")` would silently drop every reversible card from the catalog.

## Goals

- Every Magic card in the catalog carries its mana value, as a number that can be a half, in the MTG extension's `mtg_cards` table; the core catalog is unchanged.
- The mapper reads it from Scryfall's bulk data, including from a reversible card's front face.
- A running instance fills its existing cards on its next catalog refresh, whether or not Scryfall's bulk file has changed since the last one, and says so in the upgrade notes and the catalog area doc.
- Nothing calls Scryfall during a page render, and nothing reads the new column yet.

## Non-Goals

- Any page, panel, search, filter or helper that shows or uses the mana value. The deck shape panel ([#256](https://github.com/plainprogrammer/Collector/issues/256)) is its first reader, and decides how "6+" and halves bucket and which faces of a double-faced card count (design doc, "Shape panel").
- Deriving a mana value from `mana_cost`, in the migration or anywhere: Scryfall's number is the only source (decision 2).
- Storing a mana value per face, or per printing. It is a property of the card (an oracle identity), as `mana_cost` is.
- Changing the export format, a collection export, the backup's contents or the scanner.
- A new rake task, setting or admin control. The refresh that exists fills the column.

## Decisions

### 1. One nullable `float` column, `mtg_cards.mana_value`

`add_column :mtg_cards, :mana_value, :float`, no default, `null: true`. **Why a float:** Scryfall publishes a JSON number that is a whole number or a half; both, and `1000000.0`, are exact in a double, so no value is rounded; SQLite's `REAL` stores them and ActiveRecord reads a `Float`, which a later average or sum uses without a conversion. A `decimal` would read back as `BigDecimal` for no gain, since no value needs a third place. **Why nullable:** an existing row has no value until the refresh fills it, and a card Scryfall gives no `cmc` for (none seen, but the field is a contract of theirs, not ours) stays NULL, which is not 0 (a land's 0.0 is a value). **Why the name:** "mana value" is the game's term since 2021; `cmc` is Scryfall's field name and stays in the mapper only.

The column is on the MTG extension, never the core: `catalog_identities` gains nothing (`catalog-core.md`, Invariants "The core names no collectible"; the issue's MTG-only line).

### 2. The mapper's reading

`MTG::Scryfall::Mapper.identity_record` adds `mana_value` to the identity's extension, read by a small module function (`mana_value(card)`):

1. the card's top-level `cmc` when present, else
2. the **front face's** `cmc` (`Array(card["card_faces"]).first&.dig("cmc")`, the same form `illustration_id` uses for a printing's art, so a card with no faces is not an error), else
3. `nil`.

A value is kept only when it is a `Numeric`, as `value.to_f` (`value.is_a?(Numeric) ? value.to_f : nil`), so a JSON `3` and `3.0` give one value and one content digest, and a string (even `"3"`), a boolean or `nil` reads as `nil`. **`Float(value)` is not used**: it raises on `nil`, `true` and `"x"`, and `Source#entry_or_malformed` turns a raised error into a `Malformed` record. **No case makes a record malformed**: the field never uses `fetch`. A front face with no `cmc` gives `nil` even when the back face has one (no such card was seen; the rule stays the front face's). The extension hash **always carries the `mana_value` key**, `nil` included, because the refresh's `upsert_all` needs the same keys in every row of a batch. The reversible cards read on 2026-11-10 have two faces that agree (`4.0` and `4.0`, `6.0` and `6.0`); using the front face's is the same rule the mapper applies elsewhere, and the shape panel may refine which face counts for a double-faced card (Non-Goals).

No derivation from `mana_cost`: the one place that number is computed is Scryfall's, which has already applied X, hybrid, Phyrexian, split and adjusted-card rules.

### 3. How an existing row fills

The identity's content digest hashes its extension (`Catalog::Sources::IdentityRecord#digest`), so the new key changes every identity's digest and the next refresh that applies rewrites every card with its value, through the refresh's ordinary batch upsert (`Catalog::Refresh#write_extensions`). Two cases would still leave the column empty, and the spec closes the first:

- **A scheduled refresh whose version was already applied is skipped** (`Catalog::Refresh#already_applied?`; the weekly job is `scheduled`), and Scryfall may not have published a new `default_cards` since the instance last applied, so "the next refresh" would not fill anything. Spec 011 AC-2.3 met the same problem for artwork ids and answers with the source's `#reapply?` hook. `MTG::Scryfall::Source#reapply?` gains a second reason, true while the catalog holds cards and **none has a mana value** (`MTG::Card.exists? && !MTG::Card.where.not(mana_value: nil).exists?`): the instance has just upgraded, and its current file is applied once more. Once one card has a value the test is false, so a catalog whose file is up to date skips as before. The test is "none has", not "any lacks", for the reason 011 gave for artwork: a few cards may legitimately have none.
- **A manual refresh** (an admin's "Refresh now", or `bin/rails "catalog:refresh[mtg]"`) always applies, so it fills the column without the hook.

The two reasons are one hook: `reapply?` is true if either (artwork ids, mana values) holds. The hook is the source's own, so core code is unchanged and the core still names no collectible.

An instance whose refresh fails or has not run yet keeps NULL values, which no page reads (Non-Goals).

### 4. The migration

One migration, `AddManaValueToMtgCards`, timestamped after the newest on `main`: `change { add_column … }`, reversible by itself, no model reference, no backfill (decision 2), safe to run unattended on boot from any prior version, since adding a nullable column to SQLite is one `ALTER TABLE .. ADD COLUMN`. The reader of a restored backup or an upgraded volume sees NULLs until a refresh, never an error. Reversibility is proved with `bin/rails db:migrate:redo:primary` (plain `db:migrate:redo` aborts in this four-database app; no `db:rollback`), recorded in `verification.md`, and the schema file's diff is the one line.

The upgrade proof (`bin/upgrade-smoke`, spec 031) compares the columns both databases have, so an added nullable column is no difference and **`script/upgrade/expected_changes.yml` is unchanged** (it holds spec 049's two `sessions` entries; none is added); `ruby script/upgrade/guard.rb` passes because no released migration changes. The seed `script/upgrade/seeds/next.rb` creates a card with no mana value, which is the state of a real upgrade, and stays as it is.

### 5. The export format does not change (confirmed against `data-portability.md`)

The export format is collector-owned data, "keyed by external IDs" (`docs/export-format/README.md`; `data-portability.md`), and a lot names an entry only by its type and source id (`catalog-core.md`, Scope). `mtg_cards` is catalog data: global, no `account_id` and no `user_id` (`catalog-core.md`, Invariants), changed only by a refresh, and an export never reads it. The format's coverage guard fails only for a new table with `account_id` or `user_id` or a new column on `accounts`, `lots`, `users` or `locations`; this change is none of them, so **`ExportFormat::Rules::VERSIONS` stays `[1, 2, 3]`, version 3 stays current, and the format document is untouched**. The backup copies the whole primary database file (`VACUUM INTO`), so it carries the column without a change (`spec/backup_guards_spec.rb` checks attachments and database count, which don't change).

## User Stories

### Story 1: The column exists and is nullable

**As an** operator upgrading **I want** the schema to gain the column unattended **So that** the app boots and my data is intact

- [ ] **AC-1.1** `mtg_cards` has `mana_value`, a nullable `float` with no default (a schema example reading `MTG::Card.columns_hash`); a card created without one reads `nil`, and a stored `0.0` reads `0.0`, not `nil`
- [ ] **AC-1.2** The column holds `0.5` and `1_000_000.0` exactly (create, reload, compare)
- [ ] **AC-1.3** The migration is reversible: `bin/rails db:migrate:redo:primary` runs without error and leaves `db/schema.rb` as it found it (recorded in `verification.md`; no `db:rollback`)
- [ ] **AC-1.4** The migration references no application model and no other table's column; `ruby script/upgrade/guard.rb` passes; `script/upgrade/expected_changes.yml` is unchanged
- [ ] **AC-1.5** No core table (`catalog_identities`, `catalog_entries`, `catalog_sets`, `catalog_names`) gains a column, and no core file names the new attribute (the core-names-no-collectible specs pass as they are)

### Story 2: The mapper reads Scryfall's `cmc`

**As** the catalog refresh **I want** each card's mana value in its identity record **So that** the column fills from the bulk file

Each AC's input is a **recorded Scryfall object** (`spec/fixtures/files/scryfall/`, fetched from the API on 2026-11-10 and kept whole), except where it says a field is removed.

- [ ] **AC-2.1** Given a normal card with `"cmc": 1.0` (Lightning Bolt) When `Mapper.entry_record` maps it Then `record.identity.extension[:mana_value]` is `1.0`
- [ ] **AC-2.2** Given Little Girl (`"cmc": 0.5`) Then it is `0.5`; given Gleemax (`1000000.0`) Then it is `1_000_000.0`
- [ ] **AC-2.3** Given a token (or a land) with `"cmc": 0.0` Then it is `0.0`, not `nil`
- [ ] **AC-2.4** Given a `reversible_card` (Ajani Goldmane // Ajani Goldmane) that has no top-level `cmc` and `cmc` on each face Then the entry maps (it is **not** `Malformed`) and the value is the front face's, `4.0` (fails if the mapper used `fetch`)
- [ ] **AC-2.5** Given a card with `cmc` removed from the card and from every face, or a card with no `card_faces` key at all and no `cmc`, Then the entry maps and the value is `nil`, the `mana_value` key still present in the extension hash; given `"cmc": "x"`, `"cmc": "3"`, `"cmc": true` or `"cmc": null` Then the value is `nil` and the entry maps (not `Malformed`); given a front face with no `cmc` and a back face with one Then the value is `nil`
- [ ] **AC-2.6** Given the same card with `"cmc": 3` and with `"cmc": 3.0` Then the values are equal (`3.0`) and so are the identity's digests
- [ ] **AC-2.7** Every other attribute of a mapped record is as before: the existing `mapper_spec.rb` examples pass as they are, and the `scryfall_card` helper gains a `cmc` of `1.0`

### Story 3: A refresh fills existing cards, and an unchanged file does not hide the upgrade

**As an** operator who upgraded **I want** my cards to get their mana value on the next refresh **So that** I don't wait for Scryfall to publish a new file

- [ ] **AC-3.1** Given cards in the catalog with no `mana_value` and a source file that carries `cmc` When a refresh applies Then each card's `mana_value` is its file value, the cards' other attributes and their entries' ids are unchanged, and no card is duplicated
- [ ] **AC-3.2** Given an applied run for the source's current version, `MTG::Card` rows with no `mana_value`, and every printing holding its artwork id (so spec 011's test is false), When a **scheduled** refresh runs for the same version Then it applies again (`#reapply?` is true; the run is `applied`, not `skipped`) and fills the column (fails before: `skipped`, "already applied")
- [ ] **AC-3.3** Given the same but at least one `MTG::Card` has a `mana_value` When a scheduled refresh runs for the same version Then it is `skipped` with "already applied", as before (guard)
- [ ] **AC-3.4** Given a catalog with no `MTG::Card` rows, or every printing already holding its artwork id and every card its mana value Then `#reapply?` is false (guard); given artwork ids missing and mana values present, and the reverse, Then it is true (each its own example: one hook, two reasons)
- [ ] **AC-3.5** Given a **manual** refresh of an already-applied version Then it applies as always and fills the column (guard)
- [ ] **AC-3.6** Given a refresh run twice over the same file Then the second run changes no row's `mana_value`, leaves `MTG::Card.maximum(:updated_at)` as it was and reports `made_progress?` false (idempotent). The refresh's counts tally entries only, so a card rewrite never shows in them; the first run after the upgrade rewrites every card and may report `updated: 0`
- [ ] **AC-3.7** Given a file with a reversible card Then the refresh writes it with the front face's value and counts no malformed record (the AC-2.4 case through `Catalog::Refresh`)
- [ ] **AC-3.8** Every example of this spec runs with WebMock blocking real requests and issues none beyond the stubbed bulk-data ones; no view, helper or controller reads the column (the existing "Pages never call a source" invariant, `catalog-core.md`, is unchanged)

### Story 4: The documents say so

Criteria AC-4.1 to AC-4.5 are verified by reading and recorded in `verification.md`, not by RSpec (`.claude/rules/testing.md`); AC-4.6 is verified by `bin/ci`'s YARD step.

- [ ] **AC-4.1** `docs/architecture/catalog-core.md`: the Extension glossary entry says `MTG::Card` also holds the mana value (a nullable float, Scryfall's `cmc`, a reversible card's front face's); a Named constants or Decisions line records the reading and why no derivation from `mana_cost`; spec 058 and #250 are in Sources
- [ ] **AC-4.2** `docs/architecture/catalog-operations.md`: the refresh's "Running" step says the source's `#reapply?` now has a second reason (a catalog with cards and no mana value), next to 011 AC-2.3's, and that an upgraded instance fills on its next refresh; spec 058 is in Sources
- [ ] **AC-4.3** `docs/releasing.md` "Upgrade notes" gains a newest-first entry: one migration (`AddManaValueToMtgCards`, a nullable column, no data change); existing cards get their mana value on the next catalog refresh, which applies even if Scryfall's file is unchanged; nothing required of the operator; the export format is unchanged
- [ ] **AC-4.4** `docs/architecture/data-portability.md` needs no edit (decision 5); the confirmation is recorded in `verification.md`, with the area doc's version rule as its source
- [ ] **AC-4.5** The specs index has the 058 row; spec 058 supersedes nothing (it adds to spec 011 AC-2.3's hook without changing its rule, and spec 002's data model is frozen: no shipped spec is edited)
- [ ] **AC-4.6** `bin/yard doc` builds without warnings, with a comment on `Mapper.mana_value` (the why: the missing top-level key, the front face, no `fetch`) and on `Source#reapply?` naming both reasons

## Functional Requirements

- **FR-1** A migration adds nullable `mtg_cards.mana_value` (`float`); the core tables are untouched (decision 1).
- **FR-2** `MTG::Scryfall::Mapper` puts `mana_value` in the identity extension, read as decision 2 says, and never makes a record malformed over it.
- **FR-3** `MTG::Scryfall::Source#reapply?` is true when either spec 011's artwork test or decision 3's mana-value test is (one hook).
- **FR-4** `Catalog::Refresh`, `Catalog::Sources`, the admin pages, the scanner and every view are unchanged.

## Non-Functional Requirements

- **Data.** Catalog data is global: no `account_id`, no tenant scoping; no collector-owned data and no export or import change (decision 5). The backup needs no change.
- **Safety of the upgrade.** The migration is one nullable `ADD COLUMN`; it never fails on existing rows, loses nothing and needs no operator step. A release before the refresh fills it reads NULL and nothing reads it.
- **Cost.** The first refresh after the upgrade rewrites every card (about the number of distinct `oracle_id`s, tens of thousands) in `Catalog::Refresh::BATCH_SIZE` batches, once, as any digest change does; `#reapply?` adds two `exists?` queries to a scheduled run's start, on a table with a unique index on its foreign key. No request, no file read.
- **Fixtures.** Recorded Scryfall objects only; the suite makes no real HTTP (WebMock and VCR block it).
- **No UI.** No view, copy or design-system change.

## Error Scenarios

| Condition | Behaviour |
|---|---|
| A card has no `cmc` at the top level but its faces do (a reversible card) | The front face's value is stored (AC-2.4) |
| No `cmc` anywhere, or a value that isn't a number | `mana_value` is NULL and the card is kept (AC-2.5); never a malformed record |
| The refresh fails before its first batch commits | The column stays NULL; the retry or the next scheduled run applies again (`#reapply?` is still true) |
| The refresh fails after some batches committed (each batch commits on its own) | Some cards hold a value, so `#reapply?` is false; a scheduled run of the same version is then skipped as already applied (the earlier applied run still counts) and the rest fill when Scryfall publishes a new file (their digests differ) or on a manual refresh. Spec 011's artwork test has the same gap; accepted, no page reads the column |
| Scryfall's file is unchanged since the last applied refresh | A scheduled run applies once anyway while no card has a value, then skips as before (AC-3.2, AC-3.3) |
| An instance whose catalog never loaded | No `MTG::Card` rows, `#reapply?` false, the not-loaded notice as before |
| The migration is run twice, or redone | `change` is reversible; `db:migrate:redo:primary` ends with the same schema (AC-1.3) |

## Interactions

- **Spec 011 AC-2.3 and `#reapply?`.** The artwork test stays; the new one is OR-ed. An instance missing both applies its file once, filling both.
- **Existing examples.** No `MTG::Card` factory exists; `refresh_spec.rb` uses `FakeCatalogSource` (its own `reapply` accessor); `refresh_scryfall_spec.rb`, the one spec that creates real `MTG::Card` rows, runs a manual refresh; spec 011's example in `source_spec.rb` creates only an `MTG::Printing`, so `MTG::Card.exists?` is false and it passes as it is. The plan still runs those files first.
- **Fixtures.** The recorded Scryfall objects (Lightning Bolt, Little Girl, Gleemax, a token, Ajani Goldmane's reversible card) are new files under `spec/fixtures/files/scryfall/`; the one existing fixture, `azusa_ja_transform.json`, has no `cmc`.
- **#256 (deck shape panel).** Its first reader; it chooses how to bucket and which faces count, and may add a column or reading of its own.

## Open Questions

None. (Decisions 1 to 3 are the author's calls inside the issue's outline, for the approver to confirm: a `float` rather than a `decimal`, the front face's value for a reversible card, and the `reapply?` reason so that "the next refresh fills it" holds when Scryfall's file hasn't changed.)

## Out of Scope

Showing or using the mana value; the deck shape panel; per-face values; a derived value from the cost; a rake task or admin control to refill the column; an export change.
