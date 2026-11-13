# Prices

Where market prices live, how their database is built and what may never cross from it to the rest of the instance. This is the current truth; when it and an older spec disagree, this doc is right.

## Scope

The prices database: its configuration, its tables, the connection class later models inherit, and the rules that keep prices global and apart from collectors' data (spec 081). The price source contract, with Scryfall's source and the rows of sources and series that a source's declaration writes (spec 085, #364). The daily refresh (#365), the run record (#366), the admin log (#367), the history levels (#368), the display (#369) and the operator's cost documentation (#370) will extend this doc.

Neighbouring areas: the backup that holds the prices database, its format and its restore are in [release and deploy](release-and-deploy.md). The printings that prices name are the catalog's ([catalog core](catalog-core.md)). The export format holds no price ([data portability](data-portability.md)).

## Glossary

- **Prices database:** the instance's fifth SQLite file, `storage/<environment>_prices.sqlite3`, with its migrations in `db/prices_migrate/` and its schema in `db/prices_structure.sql` (spec 081 decision 1; [ADR 0029](../adr/0029-prices-database-held-by-the-backup.md)).
- **Printing:** one catalog entry, named in the prices tables by `catalog_entry_id`, the id of its `catalog_entries` row (spec 081 decision 4).
- **Price source:** where prices come from, with the attribution a page shows and whether a hosted, paid instance may show it (`price_sources`; spec 081 decision 2).
- **Price series:** what a price means: a finish, an ISO 4217 currency and a kind such as `market`. Series are global, not per source (`price_series`; spec 081 decision 2).
- **Current price:** the latest known price of one printing in one series from one source (`current_prices`).
- **Price change:** one row of history, recorded on the day a price differs from the last one recorded; a row with no cents records that the price went away that day (`price_changes`; design decision 7).
- **Price refresh run:** one run of the daily refresh (`price_refresh_runs`). Its identity and times only, so far; #366 adds the measurements (spec 081 decision 2).
- **Quote:** one price of one printing in one series from one source on one reported day, as a source yields it (`Prices::Sources::Quote`: the source's id for the printing, finish, currency, kind, whole cents and the day). Not a row: nothing stores a quote until #365 (spec 085 decision 2).
- **Reported on:** the day a source's data is from, not the day it was read. For Scryfall it is the UTC date in the bulk file's name (spec 085 decisions 2 and 4).
- **Three things named alike:** `PriceSource` is the model, a row of `price_sources`; `Prices::Sources` is the contract a source class implements; `Prices.sources` is the registry of source classes by key (spec 085 decisions 1, 7 and 11).

## Invariants

- **Prices live in their own file.** No price table is in the primary database, and the daily writes never touch it (spec 081 decision 1, FR-1; the design's anti-goal).
- **Prices are global.** No price table has `account_id` or `user_id`, and nothing of the prices database is in an export, a preview or an apply (spec 081 decision 4, AC-3.1, AC-3.2).
- **Nothing crosses the two files.** There is no foreign key from a price table to the primary (SQLite can't make one across files), and no query joins or attaches the two. Code looks up prices by printing. The test environment has both databases, so a join fails in the suite as it would in production (spec 081 decisions 1 and 4, AC-3.3, AC-3.4).
- **A price row may name a printing the primary doesn't have** (a backup's two snapshots are taken seconds apart; a retired entry). That is never an error: a reader finds no entry and shows nothing (spec 081 decision 4).
- **Foreign keys stay inside the prices file**, and each one is `on_delete: :restrict`: a source or a series that prices name can't be deleted (spec 081 decision 2, AC-3.3).
- **`current_prices` and `price_changes` are `WITHOUT ROWID`**: their primary key is the table, so the key is stored once. That holds on a database loaded from `db/prices_structure.sql` (a new instance, the test database) and on one built by the migrations (an upgraded instance), and `spec/prices_schema_spec.rb` fails when either table lacks the option (spec 081 decision 3, ruled 2026-11-13; AC-2.1 to AC-2.3).
- **The two large tables have no index beyond their primary key.** Lookups go by printing, the key's first column. An index on `price_source_id` or `price_series_id` would store most of the key again and undo the saving, so this is an accepted exception to "index every foreign key" (`.claude/rules/sqlite-and-migrations.md`). Deleting a source or a series would scan the table, and nothing does (spec 081 decision 2; the maintainer's ruling of 2026-11-13).
- **The prices schema names no collectible**: its migrations, its structure file and `PricesRecord` never name a game or a source (spec 081 decision 9, AC-3.5; `spec/prices_core_spec.rb`).
- **The backup holds the prices database** beside the primary; how is in [release and deploy](release-and-deploy.md) (spec 081 decision 6).
- **The contract's comment is the contract.** `Prices::Sources` (`app/models/prices/sources.rb`) is the one place what a source provides and what each part returns or raises is written; this doc points to it and does not restate it. There is no ADR for it (spec 085 decisions 1 and 12; Gate A, 2026-11-13). Core files (`app/models/prices.rb`, `app/models/prices/**`, `PriceSource`, `PriceSeries`) name no collectible, source or marketplace, comments included, and `spec/price_source_core_spec.rb` fails on one (spec 085 decisions 1 and 12, AC-4.1).
- **A source yields only the prices its file carries.** A price the file leaves empty has no quote. A `Malformed` that names a series is not an absence (the price exists and was not understood); one with a key and no series means no series of that printing may be read as absent; one with no key makes the run's absences untrustworthy. The reason: a refresh that deletes a price when its quote is absent must never delete one the source failed to parse, because the deletion is recorded in history that can't be fetched again. What #365 does with each is its rule (spec 085 decision 2).
- **`each_quote` makes no network call, writes nothing and reads no database.** It reads the local file its caller gives and streams it one line at a time. The contract has no members that fetch the file: acquiring it is #365's (spec 085 decision 3).
- **The date reported is the UTC date in the file's name.** A name with no date, or digits that are not a date, is an `IntegrityError` from `#reported_on` and from `#each_quote` before any quote is yielded, because a guessed date would put a wrong day into history that can't be fetched again (spec 085 decision 4, AC-2.4).
- **A price becomes cents from its digits, never through a float.** Anything that isn't one to nine digits with at most two decimals is a `Malformed` that names its series; `"0.00"` is a quote of 0 cents, and whether to show it is the display's (#369) (spec 085 decision 6, AC-2.6).
- **Quotes store what the file carries, twins included.** The EUR a non-English printing copies from its English twin is yielded as a quote of that printing; choosing the twin's price is a display rule that #369 owns (ruling 41, [research 083](../specs/083-non-english-printing-prices/research.md); spec 085 decision 5, AC-2.8).
- **Source and series rows are written by `PriceSource.sync!` and `PriceSeries.ensure!`** from a source's declaration, never seeded by a migration and never deleted. A corrected attribution takes effect at the next sync; a series a source stops declaring keeps its row; series are global, so sources that quote the same finish, currency and kind share one row. Both calls are idempotent and create through the unique indexes, so the caller that loses a race reads the winner's row (spec 085 decision 7, AC-3.1 to AC-3.6).
- **Only `PriceSource` and `PriceSeries` are models.** `CurrentPrice`, `PriceChange` and `PriceRefreshRun` are #365's and #366's (spec 085 decision 8).
- **`hosted_paid_allowed?` is stated and stored, and nothing refuses a source by it yet.** No setting for the kind of instance exists; hosted mode (#392) adds one. Scryfall's is `true`, ruled by the maintainer on 2026-11-13 (roadmap rulings 27, 37 and 38). Issue #362 is open and its answer may change the value; the value is written only in `MTG::Scryfall::PriceQuotes.hosted_paid_allowed?` and in its spec (spec 085 decision 9).

## States and transitions

- **The prices database comes into being with the instance's start.** `bin/rails db:prepare` creates it on a new volume, loading `db/prices_structure.sql`, and on an upgraded one that lacks it. A missing `sqlite3` command at that point leaves the load undone and two `command not found` lines in the log, and `db:prepare` then runs every prices migration from scratch, which builds the same tables (spec 081 decision 3).
- **A run's status** is one of `running`, `finished`, `skipped` and `failed`, fixed by a check so that #365 needs no rebuild of a released table to use them; what moves a run between them is #365's (spec 081 decision 2).

## Named constants

| Name | Value | Where | Why | Source |
|---|---|---|---|---|
| Prices database file | `storage/<environment>_prices.sqlite3` | `config/database.yml` | Beside the other four, on the same volume | spec 081 decision 1 |
| Prices schema format | `sql` (`db/prices_structure.sql`) | `config/database.yml` | A Ruby schema dump drops `WITHOUT ROWID` (the SQLite adapter defines no `table_options`); the SQL dump keeps it | spec 081 decision 3; ADR 0029 |
| `price_refresh_runs.status` values | `running`, `finished`, `skipped`, `failed` | `db/prices_migrate/20261113100001_create_price_tables.rb` | The design's three outcomes and a run in progress | spec 081 decision 2 |
| `MTG::Scryfall::PriceQuotes::SERIES_BY_KEY` | six series, all kind `market`: `usd`, `usd_foil`, `usd_etched`, `eur`, `eur_foil`, `eur_etched` | `app/models/mtg/scryfall/price_quotes.rb` | The keys of a card's `prices` that are read, with their finish and currency. The 2026-11-13 file has no `eur_etched` key; it is read anyway, so one that appears is a quote and not a change of contract. `tix` and any other key are left out | spec 085 decision 5; research 083 |
| `MTG::Scryfall::PriceQuotes::PRICE` | `\A\d{1,9}(\.\d{1,2})?\z` | `app/models/mtg/scryfall/price_quotes.rb` | The only shape of a price that becomes cents. Nine integer digits (below a billion) keep a garbled value from becoming a price; more than two decimals is refused, not rounded | spec 085 decision 6 |
| `MTG::Scryfall::PriceQuotes::FILE_STAMP` | `-(\d{4})(\d{2})(\d{2})\d{6}\.jsonl(?:\.gz)?\z` | `app/models/mtg/scryfall/price_quotes.rb` | The UTC timestamp at the end of a bulk file's name, the string the catalog keeps as the version; its date is the quotes' `reported_on` | spec 085 decision 4 |
| `Prices::Sources::CURRENCY` | `\A[A-Z]{3}\z` | `app/models/prices/sources.rb` | An ISO 4217 code is three upper-case letters; the same rule as the `price_series` table's check, so a source can't build what the database would refuse | spec 085 decision 2; spec 081 |
| `Prices::Sources::KEY` | `\A[a-z0-9_]+\z` | `app/models/prices/sources.rb` | A source's key is stored in `price_sources.key` and compared, so it is lower case letters, digits and underscores only; `verify!` refuses another | spec 085 decision 1 |

## Decisions not in an ADR

- **A change to `current_prices` or `price_changes` is a new migration that recreates the table.** On SQLite, Rails changes a column (`change_column`, `remove_column`, `rename_column`, `change_column_null`, `add_check_constraint` and the like) by copying the table into a new one built without its options, so `WITHOUT ROWID` would be silently lost. Write a migration that creates the new table with `options: "WITHOUT ROWID"`, copies the rows and swaps the names; `spec/prices_schema_spec.rb` fails otherwise. `add_column` of a nullable column is safe: SQLite's `ALTER TABLE ADD COLUMN` keeps the table. The first prices migration says the same in its header (spec 081 decision 3, AC-7.3).
- **`PricesRecord` has the writing role only**: nothing reads a replica, and a reading pool that the suite's restored-instance helper doesn't re-point would be a trap (spec 081 decision 5; plan review).
- **The structure file carries query-log comments.** Statements run in development end with `/*application='Collector'*/` (`config.active_record.query_log_tags_enabled`), SQLite stores them with the definition, and the dump keeps them. Production stores none. `spec/prices_schema_spec.rb` strips comments before it compares definitions (spec 081 execution, batch A).
- **The structure file needs the `sqlite3` command** where it is dumped (development, after a migration) and loaded (the test database, a new instance). It is in the image's runtime stage and on CI's runners; CI installs none itself (spec 081 decision 3).
- **Two models exist, three tables have none yet.** `PriceSource` and `PriceSeries` were built with the contract because it needs them; `current_prices`, `price_changes` and `price_refresh_runs` have no model until #365 and #366, each of which writes the models, readers and writers it owns (spec 085 decision 8; spec 081 decision 5, Non-Goals).
- **The attribution wording and the hosted flag are the source's declaration**, code that ships with the build and takes effect at the next sync, not a migration's seed: a migration is never edited once released, and the text is a statement the project may need to correct (spec 085 decisions 7, 9 and 10).
- **No ADR for the contract.** The decisions are spec 085's, and the contract's comment and this doc carry the rules (spec 085 decision 12; Gate A, 2026-11-13).
- **Reading cost.** `each_quote` read a generated file of 50,000 cards (300,000 quotes) in 1.2 s on the development machine; the figure is a measurement with no threshold, for #365 and #366 to plan from (spec 085 execution, T2.3).

## Sources

- [Spec 081](../specs/081-prices-database-in-backup/spec.md): decisions 1 to 5, 9 and 12, Stories 1 to 3 (the backup's part is in [release and deploy](release-and-deploy.md)).
- [Spec 085](../specs/085-price-source-contract/spec.md): decisions 1 to 12, Stories 1 to 4 (the contract, Scryfall's source, the source and series rows, the guards).
- [Research 083](../specs/083-non-english-printing-prices/research.md) and [ruling 41](../roadmap.md#2026-11-13-prices-on-non-english-printings-research-083) (quotes store what the file carries).
- [ADR 0029](../adr/0029-prices-database-held-by-the-backup.md).
- [Price data design](../superpowers/specs/2026-11-13-price-data-design.md) (2026-11-13); roadmap rulings 35 to 40; rulings 27, 37 and 38 (the hosted flag).
- Issues [#363](https://github.com/plainprogrammer/Collector/issues/363) (this database), [#375](https://github.com/plainprogrammer/Collector/issues/375) (a start that refuses a prices file with no primary), [#364](https://github.com/plainprogrammer/Collector/issues/364) (the contract), [#362](https://github.com/plainprogrammer/Collector/issues/362) (Scryfall's written answer, open; it may change the hosted flag).

## Distillation log

| Date | What | Pull request |
|---|---|---|
| 2026-11-13 | Spec 081 (decisions 1 to 5, 9 and 12: the prices database, its five tables, `WITHOUT ROWID` with the SQL schema file, the index exception, `PricesRecord`, the rules that keep prices global and apart; this doc's first distillation) | [#405](https://github.com/plainprogrammer/Collector/pull/405) |
| 2026-11-13 | Spec 085 (decisions 1 to 12: the price source contract and its registry, the Scryfall source's quotes, the rows of sources and series written from a declaration, the hosted flag, the core guard; ruling 41 distilled) | spec 085's pull request |
