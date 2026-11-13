# Feature 085: A Price Source Contract, and Scryfall's Prices Through It

**Status:** Approved by the coordinator under the maintainer's delegation (2026-11-13), after two Mode A review rounds (Fable 5.2); the value of `hosted_paid_allowed?` for Scryfall (decision 9) is pending the maintainer
**Version:** 1.0.3
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Branch:** `085-price-source-contract`
**Issue:** [#364](https://github.com/plainprogrammer/Collector/issues/364)
**Builds on:** [spec 081](../081-prices-database-in-backup/spec.md) and [`prices.md`](../../architecture/prices.md) (the prices database and its five tables), [research 083](../083-non-english-printing-prices/research.md) and [ruling 41](../../roadmap.md#2026-11-13-prices-on-non-english-printings-research-083), the [price data design](../../superpowers/specs/2026-11-13-price-data-design.md) ("The source contract"), [`catalog-core.md`](../../architecture/catalog-core.md) (the `Catalog::Sources` contract this one mirrors)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.3 | 2026-11-13 | Approved (Gate A). Decision 9 says issue #362 is open and may change the flag, and that the value lives in one place; status line (PATCH) |
| 1.0.2 | 2026-11-13 | Review round 2 (Fable 5.2): `.name` is `.title` (a class already has `.name`, so a missing one could not be found); a `Malformed` with a key and no series, and one with no key, say what they mean for absence; `verify!` and `Quote` rules tightened; a date that isn't one is an `IntegrityError`; text fixes (PATCH) |
| 1.0.1 | 2026-11-13 | Review round 1 (Fable 5.2): `#reported_on(path)` added to the contract; `Malformed` carries a series and is not an absence; acquisition left explicitly to #365; the Scryfall class is `MTG::Scryfall::PriceQuotes`; `hosted_paid_allowed?` for Scryfall is `true`, pending the maintainer; `verify!` and the criteria tightened (PATCH) |
| 1.0.0 | 2026-11-13 | First draft |

---

## Problem Statement

Collector will record market prices every day, but nothing yet says how a price source hands its prices to the core, or how Scryfall's file becomes prices. The tables exist (spec 081) with no models and no reader. Without a contract the daily refresh (#365) would be written against Scryfall's file directly, the core would name a collectible, and a second source would need a rewrite. The contract is the seam: a collectible's extension yields quotes and states where they come from and what may be done with them; the core stores them without knowing which collectible they are for.

## Goals

- A documented contract, in the core, that a collectible's extension implements to supply prices: what it yields (quotes), what it states (name, attribution, whether a hosted, paid service may show it, the series it quotes) and what it must raise.
- A registry that finds the price sources of a collectible, as `Catalog.sources` finds its catalog source.
- The Scryfall source for Magic: it reads `prices` from the bulk file the catalog refresh reads and yields one quote per price the file carries.
- The rows that name a source and its series in the prices database, written from the source's own declaration, so attribution text and series are code, not a seed that drifts.
- Core files that name no collectible, proved by a guard, with the contract's comment as the one place the contract is written.

## Non-Goals

- **The daily refresh, its run log and the writes to `current_prices` and `price_changes`** (#365, #366). This spec builds no job, no download of the price file, no matching of a quote's printing to a catalog entry and no model for `current_prices`, `price_changes` or `price_refresh_runs`. The contract's reading side is complete without them.
- **Any page, label or display rule** (#369), including ruling 41's twin lookup. This spec stores nothing about twins.
- **History levels** (#368) and the measurements of a run (#366).
- **Refusing a source on a kind of instance that may not show it.** The design says an instance refuses such a source. Collector has no setting that says which kind of instance it is (the open catalog, `COLLECTOR_PUBLIC_CATALOG`, is a different choice), so this spec states the source's answer and builds no refusal; the first feature that has a kind of instance builds it (decision 9).
- A source other than Scryfall, the MTGO price (`tix`), the "price by condition or language" that Scryfall doesn't give, and prices that follow a merged printing (#371).

## Users and Context

**Primary users:** the developer of a collectible extension (a later collectible, and the Scryfall source today), who reads the contract's comment to write a source; and the later prices issues (#365 to #369), which call the contract.
**Secondary users:** an operator, who sees nothing change in this spec: no setting, page, job or table is added. A collector sees nothing.
**Usage context:** called from a background job (#365) that has the price file on disk; called in specs with fixture lines. No page render calls it, and nothing calls Scryfall: the file is the catalog's.
**Vocabulary:** a *quote* is one price of one printing in one series, as one source reported it on one date. A *series* is what a price means: a finish, an ISO 4217 currency and a kind (spec 081 glossary). *Reported on* is the date the source's data is from, not the date it was read.

## Decisions

### 1. The contract is `Prices::Sources`, and its comment is the one place it is written

A module `Prices::Sources` in the core (`app/models/prices/sources.rb`) holds the contract's comment, its value classes (`Quote`, `Series`, `Malformed`) and its errors, as `Catalog::Sources` does for the catalog. A source is a class that provides:

| Member | Returns |
|---|---|
| `.key` | the source's stable key, lower case, such as `scryfall`; stored as `price_sources.key` and never changed |
| `.collectible_type` | the key of the `Catalog.sources` entry whose printings this source's ids name (`"mtg"`) |
| `.title`, `.attribution` | non-blank strings: the source's name (stored as `price_sources.name`; not `.name`, which every class already answers), and the text a page shows beside its prices |
| `.attribution_url` | an `https` address or `nil` |
| `.hosted_paid_allowed?` | `true` or `false`: whether a hosted, paid service may show this source's prices (decision 9) |
| `.series` | the `Series` the source quotes, with no two alike |
| `#reported_on(path)` | the `Date` the data in the file at `path` is from; raises `IntegrityError` when the file doesn't say |
| `#each_quote(path, languages:)` | yields `Quote` or `Malformed`, streamed, for the file at `path`, each quote carrying `#reported_on`'s date; without a block it returns an `Enumerator` |

A source is built with `.new` and no arguments. The comment says what an implementation must provide and what each part returns or raises, so a new collectible adds a source by reading it (`.claude/rules/code-documentation.md`, Extension contracts); its examples are neutral (a fake collectible), never a real one. The core's other documents point to the comment.

`Series` (finish, currency, kind) is a value that validates when built, by the rules of decision 2, so a source can't declare one the prices database would refuse. `Prices::Sources.verify!(source_class)` checks a class against the table: every member present (the class members above and the instance methods `reported_on` and `each_quote`); `key` matching `\A[a-z0-9_]+\z`; `collectible_type`, `title` and `attribution` non-blank; `attribution_url` `nil` or `https`; `hosted_paid_allowed?` exactly `true` or `false`; `series` a non-empty list of `Series` with no two equal. It raises `Prices::Sources::ConfigurationError` naming the member. Whether `.collectible_type` is a key of `Catalog.sources`, and whether `.key` is the key the class is registered under, are checked for the registered sources by the suite (AC-1.6), because `verify!` sees a class and not its registry entry.

### 2. A quote, and what a source never yields

`Quote` is a value with `external_key` (the source's id for the printing; for Scryfall the card's `id`, which is the catalog entry's `external_key`), `finish`, `currency`, `kind`, `cents` (an Integer, 0 or more) and `reported_on` (a `Date`); `#series` returns its `Series`. Building one with a blank key, finish or kind, a currency that isn't three upper-case letters, a negative or non-Integer `cents`, or a `reported_on` that isn't a `Date` raises `ArgumentError`, so a source can't yield a quote the prices database would refuse.

A source yields only the prices its file carries. A price the file leaves empty has no quote: whether that means "gone" is the refresh's to decide from the absence (#365). `Malformed` (`external_key`, `error`, `series`) reports a line or a price the source could not read, as in the catalog contract; the reader goes on. `series` is the `Series` of a price the file carries but the source could not read, and `nil` for a line that is unreadable as a whole. **A `Malformed` that names a series is not an absence**: the price exists and was not understood, so the refresh must leave that printing's current price and history alone, and must not read the missing quote as "gone", which would delete a price and record the deletion in history that can't be fetched again (#365's rule to write down; this contract gives it what it needs). Two more cases: a `Malformed` with an `external_key` and no series (the card's `prices` is not an object, so none of its series can be read) means **no series of that printing may be read as absent**; a `Malformed` with no key (a line that is not JSON, or has no `id`) names no printing, so the run's absences can't be trusted, and what #365 does with that is its rule. The contract's comment says all three.

### 3. What the contract takes: the file, and the languages

`#each_quote(path, languages:)` reads a local copy of the source's data and nothing else: it makes no network call, writes nothing, and takes `path` from its caller. The contract has no members that fetch the file. For Scryfall the file is the bulk file the catalog refresh downloads (`MTG::Scryfall::Source#download`), so acquiring and verifying it, and skipping one already applied, stay the refresh's (#365), which may take the file from `Catalog.source_for(collectible_type)` or add acquisition members to this contract; this spec decides neither. `languages:` is the list the collectible's catalog source returns from `#languages`, so quotes are yielded for the printings the catalog holds; a source for a collectible without languages ignores it.

### 4. The date reported comes from the file, and is asked for before the file is read

`#reported_on(path)` answers the day the data is from, so the refresh has the run's date and the file's version before it reads a line, and for a file with no quotes at all (design: "The run's date is the UTC date of the bulk file"). Scryfall publishes one price per card per day in a file whose name ends in its UTC timestamp (`default-cards-20261113100623.jsonl.gz`), the same string the catalog keeps as the version and the bulk entry's `updated_at` (research 083). The Scryfall source takes the date from that timestamp, in `#reported_on` and in every quote's `reported_on`. A file name without one, or whose digits are not a date (`20261340`), raises `Prices::Sources::IntegrityError` (never a `Date::Error`) from `#reported_on`, and from `#each_quote` before it yields anything (when enumeration starts, if no block was given): a quote with a guessed date would put a wrong day into history that can't be fetched again.

### 5. The Scryfall source: six series, five in today's file

`MTG::Scryfall::PriceQuotes` (`app/models/mtg/scryfall/price_quotes.rb`; not `Prices`, which would shadow the core module of that name wherever a file nests `module MTG`), registered under `scryfall`, quotes six series, all of kind `market`:

| Key in `prices` | Finish | Currency |
|---|---|---|
| `usd` | `nonfoil` | USD |
| `usd_foil` | `foil` | USD |
| `usd_etched` | `etched` | USD |
| `eur` | `nonfoil` | EUR |
| `eur_foil` | `foil` | EUR |
| `eur_etched` | `etched` | EUR |

The 2026-11-13 file carries no `eur_etched` key in any object (research 083); the source declares and reads it anyway, so one that appears is a quote and not a change of contract (ruling on #364). `tix` and any other key are ignored. The finishes are the names `MTG::Collecting.finish_order` uses.

The source stores what the file carries (ruling 41, research 083): it yields the EUR a non-English printing copies from its English twin (7,667 quotes on 2026-11-13) as a quote of that printing, and applies no twin rule. It yields quotes for paper printings only, the test the catalog's mapper applies (`MTG::Scryfall::Mapper.paper?`), and only for the given languages.

### 6. A price becomes cents without a float

Scryfall writes a price as a decimal string (`"1.42"`). The source turns it into whole cents from the digits, never through a floating-point number. A price is read only if it matches `\A\d{1,9}(\.\d{1,2})?\z`; anything else (`"1.234"`, `"-1"`, `"+1"`, `"abc"`, `"1,42"`, `".5"`, `"1."`, `" 1.42"`, `"1e2"`, an empty string or a number that is not a string) is a `Malformed` naming the series, not a rounded or guessed quote. Nine integer digits (below a billion dollars) keep a garbled value from becoming a price; no real card costs that much. `"0.00"` is a quote of 0 cents: the file carries it, and whether to show it is the display's (#369).

### 7. Source and series rows are written from the source's declaration, not by a migration

`PriceSource.sync!(source_class)` (a model on `price_sources`, inheriting `PricesRecord`) verifies the class, then creates or updates the `price_sources` row for its `key` from `title`, `attribution`, `attribution_url` and `hosted_paid_allowed?`, and creates any series row it declares that doesn't exist (`PriceSeries`, on `price_series`). It returns the source row. It is idempotent, safe to call at the start of every run and from two processes at once, and it never deletes a source or a series. `PriceSeries.ensure!(series)` returns `{ Series => PriceSeries }` for the given declared series, so a refresh maps `quote.series` to a row id.

Why not seed rows in a migration: attribution text is a statement the project may need to correct, and a migration is never edited once released; the declaration is code that ships with the build and takes effect at the next run. Series are global (spec 081 decision 2), so two sources that quote the same finish, currency and kind share one row.

### 8. The models built here, and the ones left

Built: `PriceSource`, `PriceSeries` and the contract's value classes, because the contract needs them. Left to the issues that own the writes: `CurrentPrice` and `PriceChange` (#365) and `PriceRefreshRun` (#365, #366). `PricesRecord`'s comment ("no models yet") is updated.

### 9. Whether a hosted, paid service may show a source: stated, not enforced

A source states `hosted_paid_allowed?`: whether its prices may be shown on a hosted instance that has paid plans. Scryfall's is `true` **[pending the maintainer's confirmation, asked through the coordinator]**: ruling 27 allows its data on a paid hosted service when it is publicly accessible, and rulings 37 and 38 have the hosted instance show prices and history to everyone who can see the card. What Scryfall's terms forbid is a paywall, which is a display rule (prices and history are never a paid feature, ruling 37), not a reason to refuse the source on a hosted instance. With `false`, the refusal the design describes would switch Scryfall's prices off on the hosted service. The flag fits a source that may not be shown on a paid service at all (Card Kingdom, design decision 4). It is stored in `price_sources.hosted_paid_allowed`. The value is written in one place, the source's declaration (`hosted_paid_allowed?`), and its spec sits in a plan task of its own, so a ruling of `false` is a one-line change. Issue #362 (the written question to Scryfall about recording prices and showing their history) is still open, and its answer may change the flag. Nothing reads it yet: the refusal needs a setting for the kind of instance, which doesn't exist; hosted mode (`COLLECTOR_HOSTED`, #392) is the issue that adds one (Non-Goals).

### 10. Scryfall's attribution

`title` is "Scryfall"; `attribution_url` is `https://scryfall.com`; `attribution` is a sentence that says the prices are provided by Scryfall, that USD prices are TCGplayer's market price and EUR prices are Cardmarket's as Scryfall reports them, and that Scryfall updates them once a day. The wording is the one the card page's price label (#369) draws on; #369 may add what it needs (the twin's "English printing", the date) around it.

### 11. The registry

`Prices.sources` (a `mattr_accessor` on the `Prices` module, `app/models/prices.rb`) maps a source key to its class name, registered in `config/initializers/prices.rb` as `Catalog.sources` is in `config/initializers/catalog.rb`. `Prices.source_class(key)` raises `ArgumentError` for an unknown key; `Prices.sources_for(collectible_type)` returns the classes whose `.collectible_type` matches, in key order.

### 12. The guards and the documents

- A guard (`spec/price_source_core_spec.rb`) reads the core files this spec adds (the `Prices` module and its folder, `PriceSource`, `PriceSeries`) and fails on a collectible, source or marketplace name (`mtg`, `magic`, `scryfall`, `tcgplayer`, `cardmarket`), comments included, as the other `*_core_spec.rb` files do; one of its examples applies the same matcher to a sample string to show it flags a name. The initializer and the Scryfall class name them by nature and are outside it. The existing `spec/prices_core_spec.rb` (the schema files) keeps its shorter list.
- [`prices.md`](../../architecture/prices.md) gains the contract, the models, the sync and ruling 41, with the source of each statement; its Scope no longer lists #364 as to come. `CLAUDE.md`'s status paragraph says the contract exists. The roadmap's row for #364 is marked done. The specs index gains this spec's row and the research 083 row records that the prices doc took ruling 41.
- No ADR: the decisions are this spec's, and the contract's comment and the area doc carry the rules. (If the coordinator wants one for the contract, it takes the next number.)

## User Stories

### Story 1: A collectible's extension supplies prices through a documented contract

**As a** developer adding a collectible
**I want** a documented contract and a registry for price sources
**So that** I add prices for my collectible by reading one comment, without touching the core

**Acceptance criteria:**

- [ ] **AC-1.1** Given a source class that provides every member of decision 1 When it is verified Then `Prices::Sources.verify!` returns it; and the contract's comment names each member, what it returns and each error a source raises, with no real collectible in its examples (verified by reading, recorded in `verification.md`, with AC-4.3).
- [ ] **AC-1.2** Given a source class missing a member, with a `key` that is blank, upper case or has a character outside `a-z`, `0-9` and `_`, a blank `collectible_type`, `title` or `attribution`, an `attribution_url` that is not `https`, a `hosted_paid_allowed?` that is `nil`, no series, two equal series, or a series list holding something that is not a `Series` (a `Series` with a blank finish can't be built to put in it) When it is verified Then `Prices::Sources::ConfigurationError` is raised and its message names the member; and Given a `Series` with a blank finish or kind, or a currency that is not three upper-case letters When it is built Then `ArgumentError` is raised.
- [ ] **AC-1.3** Given a fake source registered in `Prices.sources` under a key and a collectible type When `Prices.source_class(key)` and `Prices.sources_for(type)` are called Then they return the fake; and Given an unknown key When `Prices.source_class` is called Then `ArgumentError` is raised; and Given a type with no source When `Prices.sources_for` is called Then it returns an empty list.
- [ ] **AC-1.4** Given the fake source and a file path When `each_quote(path, languages:)` is read to the end Then it yields the quotes the fake was given, including a `Malformed` with a series and one without, and a `Quote` offers `#series` equal to a declared `Series` with the same finish, currency and kind; and Given no block Then it returns an `Enumerator` of the same records; and `#reported_on(path)` returns the fake's date, or raises `IntegrityError`.
- [ ] **AC-1.5** Given the arguments of a `Quote` that is invalid (blank key, blank finish, blank kind, a currency `usd`, a negative `cents`, a `cents` of `1.5`, a `reported_on` that is a String) When it is built Then `ArgumentError` is raised for each.
- [ ] **AC-1.6** Given the registered sources in the suite's boot When each is verified Then every one passes, each one's `.key` is the key it is registered under, its `.collectible_type` is a key of `Catalog.sources`, and `Prices.source_class("scryfall")` is `MTG::Scryfall::PriceQuotes`.

### Story 2: Scryfall's prices come out of the bulk file as quotes

**As** the daily refresh (#365)
**I want** the Scryfall source to yield every price the bulk file carries
**So that** I can store them without reading Scryfall's format

**Acceptance criteria:**

- [ ] **AC-2.1** Given a card line whose `prices` carry `usd` "1.42", `usd_foil` "3.10", `usd_etched` "5.00", `eur` "1.20", `eur_foil` "2.55", `eur_etched` "4.10" When `each_quote` reads it Then six quotes are yielded with the card's `id` as `external_key`, the finish and currency of decision 5, kind `market`, and `cents` of 142, 310, 500, 120, 255 and 410; and `Malformed` has no part in it.
- [ ] **AC-2.2** Given a card whose prices are `null` for some keys, a missing key, an empty `prices` object, or no `prices` key When it is read Then a quote is yielded for each non-null price and none for the rest, and no `Malformed`.
- [ ] **AC-2.3** Given a card whose `prices` carry `tix` and a key the source doesn't know (`usd_gold`) When it is read Then neither yields a quote or a `Malformed`.
- [ ] **AC-2.4** Given a file named `default-cards-20261113100623.jsonl.gz` When it is read Then every quote's `reported_on` is 2026-11-13; and Given `all-cards-20261112235959.jsonl.gz` Then it is 2026-11-12; and `#reported_on(path)` returns the same dates for the same names, for a file with no cards at all too; and Given a file whose name carries no timestamp, or digits that are not a date When `#reported_on` is called, or `each_quote` is called and enumerated Then `Prices::Sources::IntegrityError` is raised, and `each_quote` yields nothing first.
- [ ] **AC-2.5** Given a digital-only card and a card whose `games` lack `paper` When the file is read Then neither yields a quote; and Given a card in a language outside `languages:` Then it yields none, and one inside it yields its quotes.
- [ ] **AC-2.6** Given prices `"0.05"`, `"10"`, `"1234.5"` and `"0.00"` When read Then the cents are 5, 1000, 123450 and 0; and Given `"1.234"`, `"-1"`, `"abc"`, `""`, `"1,42"`, `".5"`, `"1."`, `" 1.42"`, `"+1"`, `"1e2"`, a JSON number `1.42` and `"1234567890.00"` Then each is a `Malformed` carrying the card's id, a message naming the price key and the `Series` of that key (so it can't be read as an absence), the card's other prices are still yielded, and no float is involved (`"0.29"` gives 29, not 28).
- [ ] **AC-2.7** Given a line that is not JSON, a paper line with no `id`, a paper line whose `prices` is a string, and a blank line When the file is read Then the first two are each a `Malformed` with no series and no external key, the third is a `Malformed` carrying the card's id and no series, the blank line is skipped silently, and the reading goes on to the next line; the language and paper filters run before the `id` is read, as the catalog's reading runs them, so a digital card with no `id` is skipped, not malformed.
- [ ] **AC-2.8** Given a Japanese printing that carries a `eur` copied from its English twin (the same `cardmarket_id`), and `languages: ["en", "ja"]` When read Then its EUR is yielded as a quote of the Japanese printing's own id, with no USD quote, and the source looks up no twin (ruling 41).
- [ ] **AC-2.9** Given the same fixture file When the catalog source's `each_entry` and the price source's `each_quote` read it Then every quote's `external_key` is the `external_key` of an entry record, and no network request is made (WebMock blocks all).
- [ ] **AC-2.10** Given a gzip file written with a sync flush after its first card line and then cut short (so the first line is readable and the stream is not complete) When `each_quote` reads it Then the first card's quotes are yielded before `Zlib::GzipFile::Error` is raised to the caller, which shows the file is read as a stream and not loaded whole, and that a corrupt file surfaces as an error.
- [ ] **AC-2.11** Given the source When it is verified and its declaration read Then `title` is "Scryfall", `key` is `scryfall`, `attribution_url` is `https://scryfall.com`, the attribution names Scryfall, TCGplayer's market price for USD, Cardmarket for EUR and the daily update, `hosted_paid_allowed?` is `true` (decision 9, pending the maintainer's confirmation), and the six series are those of decision 5 with finishes among `MTG::Collecting.finish_order`.

### Story 3: The instance holds a row for each source and series

**As** the daily refresh (#365)
**I want** the source and its series written from the source's declaration
**So that** I can name them by id when I store a quote, and their text is never out of date

**Acceptance criteria:**

- [ ] **AC-3.1** Given an empty prices database When `PriceSource.sync!` is called with the Scryfall source Then one `price_sources` row exists with its key, name, attribution, address and `hosted_paid_allowed` of true, six `price_series` rows exist, and the source row is returned.
- [ ] **AC-3.2** Given the rows of AC-3.1 When `sync!` is called again Then no row is added and no id changes.
- [ ] **AC-3.3** Given a source row and a source class whose attribution changed When `sync!` is called Then the row's attribution is updated and its id kept; and Given a source that no longer declares a series Then that series' row stays.
- [ ] **AC-3.4** Given two sources that both quote nonfoil USD market When both are synced Then `price_series` has one row for it.
- [ ] **AC-3.5** Given declared series When `PriceSeries.ensure!` is called Then it returns a hash from each `Series` to its row, and `hash[quote.series]` finds the row of a quote.
- [ ] **AC-3.6** Given a source class that fails verification When `sync!` is called Then `ConfigurationError` is raised and no row is written.
- [ ] **AC-3.7** Given the prices connection When rows are written Then they are in the prices database (`PriceSource.connection_db_config.name` is `prices`), the primary database has no `price_sources` table, and `PriceSource` and `PriceSeries` have no `account_id`.

### Story 4: The core stays collectible-agnostic and documented

**As a** maintainer
**I want** a guard and current documents
**So that** a later change can't leak a collectible into the core, and an agent finds the rules

**Acceptance criteria:**

- [ ] **AC-4.1** Given the core files of decision 12 When a guard reads them, comments included Then none matches a collectible or source name (`mtg`, `magic`, `scryfall`, `tcgplayer`, `cardmarket`) as a word, and the guard fails on a file that does.
- [ ] **AC-4.2** Given the branch When `bin/ci checks` runs Then every public class, module and method added has a comment (spec 056), YARD builds without a warning, and RuboCop and Brakeman pass.
- [ ] **AC-4.3** Given `docs/architecture/prices.md`, `CLAUDE.md`, `docs/roadmap.md` and `docs/specs/README.md` When read Then they say what decision 12 lists, each statement with its source (verified by reading, recorded in `verification.md`).

## Functional Requirements

### FR-1: The contract and its registry

**Must:**
- Provide `Prices::Sources` with the comment, `Quote`, `Series`, `Malformed`, `Error`, `IntegrityError`, `ConfigurationError` and `verify!` (decisions 1, 2 and 4).
- Say in the comment what each kind of `Malformed` means for absence (decision 2), and keep its examples neutral: a fake collectible, never a real name (the guard of decision 12 reads comments).
- Provide `Prices.sources`, `Prices.source_class` and `Prices.sources_for` (decision 11), and register Scryfall's source in `config/initializers/prices.rb`.

**Must not:**
- Name a collectible in a core file, its comments included.
- Make a network call, write a row or read the primary database from `each_quote`.

### FR-2: The Scryfall source

**Must:**
- Implement the contract in `MTG::Scryfall::PriceQuotes` as decisions 3 to 6, 9 and 10 say, reading the file as the catalog's `each_entry` does (gzip, line by line).
- Yield `Malformed` for what it can't read, and go on.

**Must not:**
- Store or yield `tix`, apply a twin rule, call Scryfall, or read the catalog tables.

### FR-3: Source and series rows

**Must:**
- Provide `PriceSource.sync!` and `PriceSeries.ensure!` (decision 7), in the prices database only.

**Must not:**
- Seed rows in a migration, delete a source or a series, or add a model for the tables #365 and #366 own.

## Non-Functional Requirements

### Performance

- `each_quote` holds one line at a time: its memory doesn't grow with the file. The bulk files are about 120,000 lines (`default_cards`) and 500,000 (`all_cards`); a timing example reads a generated file of 50,000 cards and records the time, without a threshold, so #365 and #366 can plan from a number (`timing: true`).
- `sync!` is a handful of queries (at most one lookup and one write for the source, and one lookup per declared series on a database that already has them).

### Security

- Prices are global data: no account, no `Current.account`, nothing in the export.
- A source's `attribution_url` must be `https`; the contract refuses another scheme.
- The source reads a file and a path its caller gives; it opens nothing else.

### Reliability

- A malformed line or price never stops the reading and never yields a guessed quote.
- `sync!` and `ensure!` are idempotent (AC-3.2) and safe under two callers at once: they create through the unique indexes (create-or-find), so the caller that loses a race reads the winner's row. A race can't be forced in a test without stubbing the code under test, so the implementation review reads it instead.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The file's name carries no timestamp | `IntegrityError` from `#reported_on` and from `#each_quote` before it yields anything (decision 4) |
| The file isn't gzip, or is truncated | The reader's error surfaces to the caller (`Zlib::Error`, as in the catalog's reading); quotes already yielded stay yielded |
| A line isn't JSON, or has no `id` | A `Malformed` with no key; the reading goes on; the run's absences can't be trusted (#365's rule) |
| A card's `prices` isn't an object | A `Malformed` with the card's key and no series; none of its series may be read as absent |
| A price is not a decimal of at most two places | A `Malformed` carrying that price's series, which is not an absence; the card's other prices are yielded |
| A card has no `prices`, or a null price | No quote for what is missing, no `Malformed` |
| A registered source fails verification | `ConfigurationError` naming the member, at `sync!` and in the suite's guard |
| A source key is unknown | `ArgumentError` from `Prices.source_class` |
| Two processes sync the same source | Both succeed; one row per key and per series |

## Open Questions

One decision waits for the maintainer, asked through the coordinator before approval: that Scryfall's `hosted_paid_allowed?` is `true` (decision 9; the review read the flag's meaning as "may be shown on a hosted instance with paid plans", which Scryfall's terms allow while prices stay public). Two more a reviewer should confirm: that no refusal is built (Non-Goals; hosted mode, #392, adds the setting it needs), and that the sources and series are written by a call and not seeded by a migration (decision 7).

## Out of Scope (Future Considerations)

- The daily refresh, its run log and the writes to current prices and history (#365, #366), and the models for those three tables.
- The admin log of runs (#367), the history levels (#368), the display with ruling 41's twin lookup and its label (#369), and the operator's cost documentation (#370).
- A refusal of a source on an instance that may not show it, when a setting for the kind of instance exists.
- A second source, a price per condition or language, and the MTGO price.
- A source that publishes more than once a day, or a file that carries its own report date per card: a quote's `reported_on` is per quote and would carry it (`#reported_on(path)` names the file's day).
- Acquisition members on the contract (fetching and verifying a source's file): #365 decides whether it takes the catalog source's download or adds them (decision 3).
