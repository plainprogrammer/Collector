# Market prices and price history: the price data design

**Date:** 2026-11-13. **Status:** approved by the maintainer in the interview, 2026-11-13 (Scryfall as the source, changes-only history, the history levels and the issue split); issues filed (see "Filed" at the end).
**Builds on:** [research 016](../../specs/016-scryfall-hosting-terms/research.md) (Scryfall's terms, rulings 27–30), the catalog core and its refresh as built on `main` at `8ee8d29` ([`catalog-core.md`](../../architecture/catalog-core.md), [`catalog-operations.md`](../../architecture/catalog-operations.md)), backup and restore ([ADR 0024](../../adr/0024-backup-with-vacuum-into.md)), and a survey of price sources and their terms on 2026-11-13.
**Deliverable:** GitHub issues under `theme: prices`, each one outcome that a Claude Code agent takes through the SDD workflow in one PR, and the roadmap's prices lane.
**Roadmap:** this reverses ruling 14 for market prices (rulings 35–40).

## Why

Collector shows what a collector has and where it is, but not what it is worth. Collectors want to see the market price of the cards they own and, later, how those prices move: the value of a collection over time, changes on a wish list, alerts. On a hosted instance the same history is useful to a visitor with no account, on a card's public page and in a scan used for lookup.

The catalog's source publishes only today's price. History exists only if the instance records it, from the day it starts recording. That is the reason to start in 1.0: a later start loses the days before it.

In 1.0 the data has one use, a basic price display. The daily job also records what it did and how large the database is, so that growth is measured in the beta environment before any history feature is designed.

## Decisions

| # | Decision | By |
|---|---|---|
| 1 | Scryfall is the price source: the `prices` object of the bulk file the catalog already reads. | Maintainer |
| 2 | Prices and their history are shown to anonymous visitors and free accounts. They are never a paid feature. No price API or dataset is published. | Maintainer |
| 3 | Price sources are pluggable. Only the Scryfall source is built. | Maintainer |
| 4 | Card Kingdom's price list is left out: its terms for commercial use are unclear. | Maintainer |
| 5 | A hosted instance keeps history for the whole catalog. | Maintainer |
| 6 | A self-hosted instance chooses how much history to keep, and the documentation says what each level costs in disk. | Maintainer |
| 7 | History stores changes only: a row when a price differs from the last one recorded. | Maintainer |
| 8 | Thinning old history is a later concern. | Maintainer |
| 9 | In 1.0 the data is used for a basic display only. | Maintainer |
| 10 | The price refresh records analytics about each run. The catalog refresh does not. | Maintainer |
| 11 | The history levels are off, tracked and full; lowering the level deletes nothing. | Proposed, not yet ruled |
| 12 | Prices live in a database file of their own, and the backup holds it. | Proposed, not yet ruled |
| 13 | USD and EUR are both stored; the MTGO price is not. | Proposed, not yet ruled |

Decisions 11 to 13 are the design's proposals. Each is settled in the spec of the issue that carries it.

## Goals, non-goals and anti-goals

**Goals**
- A current price for every priced printing and finish, refreshed once a day.
- Changes-only history, cheap enough to keep for the whole catalog in SQLite on one host.
- A history level an operator sets.
- A source contract, so a second source needs no schema change.
- A record of each run, so growth is measured.

**Non-goals in 1.0**
- Price charts, estimated value, value over time, alerts, wish list changes.
- Thinning or downsampling history.
- A source other than Scryfall. Other collectibles need their own source.
- A price by condition or by language. Scryfall gives one price per finish.
- Analytics for the catalog refresh.

**Anti-goals**
- A price or its history behind payment (ruling 27, decision 2).
- One number blended from several sources.
- Daily price writes in the primary database.

## Constraints

- **Scryfall's rules** (research 016): its data may not be put behind payment and may not be simply repackaged or republished. It calls bulk prices stale after 24 hours and unfit for a storefront.
- **The prices.** Per card: `usd`, `usd_foil`, `usd_etched`, `eur`, `eur_foil`, `eur_etched` and `tix`, each a string or null, updated once a day. USD is TCGplayer's market price. EUR is a Cardmarket trend or average. Scryfall states no licence of its own over either.
- **History can't be downloaded again.** A missed day is a gap for good, and a lost database is lost history.
- **The catalog.** It is global data, keyed by Scryfall's id, refreshed weekly from `default_cards` when the instance is English only and from `all_cards` when `COLLECTOR_MTG_LANGUAGES` adds a language. Core files name no collectible; a source lives in its collectible's namespace.
- **Backup.** `backup:create` holds the primary database only, and a fifth production database fails `spec/backup_guards_spec.rb` until its place in the backup is decided.
- **Currency.** An account shows every price in one currency it chooses (spec 038). Scryfall gives USD and EUR only.

## Approaches

| Approach | Size for the whole catalog (estimate) | Outcome |
|---|---|---|
| Every price, every day | About 100 million rows, 2 to 3 GB a year | Rejected: mostly repeated values |
| **Changes only** | Depends on how many prices move in a day; at 10 to 20 percent, about 0.3 to 0.6 GB a year | **Chosen** (decision 7): append-only, grows with real movement, one table for every history level |
| Changes only, thinned with age | Bounded | Deferred (decision 8): it loses detail for good |

The sizes are estimates. The share of prices that change in a day is not measured; the run record below measures it.

## History levels

One setting for the instance:

| Level | What is recorded | For |
|---|---|---|
| off | Current prices only | The smallest footprint |
| tracked | History for printings any account owns, and wishes for once a wish list exists ([#357](https://github.com/plainprogrammer/Collector/issues/357)) | A household's instance |
| full | History for every priced printing | A hosted instance, and an operator who wants it |

- Current prices refresh at every level.
- Under tracked, a printing's history starts with its current price on the day it is first owned. Nothing earlier exists.
- Lowering the level stops new rows and deletes nothing.
- Raising the level starts from that day. There is no backfill.
- Tracked reads across accounts to learn which printings are owned. It stores no account's data.

## Data

A prices database beside the primary one. It is global data like the catalog: no `account_id`, and nothing of it in the export format. There are no foreign keys or joins across the two files.

- **Price sources:** a key, a name, the attribution text and link, and whether the source may be shown on a hosted, paid instance.
- **Price series:** what a price means: finish, currency and kind (market). Six for Scryfall.
- **Current prices:** one row per printing, source and series: cents, the date the source reported it, the date it last changed.
- **Price changes:** the history: printing, source, series, date and cents. A row with no cents records that the price went away that day, so a later chart doesn't carry a dead price forward.
- **Price refresh runs:** one row per run, with the run record below.

## The daily refresh

A scheduled job, separate from the weekly catalog refresh. It reads the same bulk file the catalog refresh reads and takes only each card's id and prices.

1. Ask Scryfall for the bulk file's entry. Skip a file already applied.
2. Stream the file. Match each card to its printing.
3. For each series: an unchanged price writes nothing; a changed or new price updates the current price and, when the history level covers the printing, writes a history row for the run's date; a price that is gone removes the current price and writes an empty history row.
4. Write in batches. Record the run.

- The run's date is the UTC date of the bulk file. Running the same file twice changes nothing.
- The first run writes a row for every covered price.
- A printing the catalog doesn't have yet is skipped and counted.

## The run record

| Group | Recorded |
|---|---|
| Identity | Source, run date, the bulk file's version, status (finished, skipped, failed), the error |
| Time | Start, finish, seconds downloading, seconds processing |
| Input | The bulk file's size, lines read, printings matched, unknown ids skipped |
| Prices | Seen, unchanged, changed, newly priced, removed |
| Writes | Current prices written and removed, history rows written |
| Storage after the run | The prices database's file size, WAL size, free pages, and rows in current prices and in history |
| Process | Peak memory, where it is cheap to read |

An admin page lists the runs, newest first.

## The source contract

A collectible's extension supplies prices through a contract in the core, as it supplies the catalog through `Catalog::Sources`. An implementation yields quotes (the source's id for the printing, finish, currency, kind, cents, the date reported), and states its attribution and whether it may be shown on a hosted, paid instance. An instance refuses a source its kind of instance may not show.

## Display in 1.0

```
Lightning Bolt · 2X2 #117
Nonfoil  $1.42      Foil  $3.10
TCGplayer market price via Scryfall · as of Nov 12

2x  Lightning Bolt  2X2  Foil  NM     $3.10
```

- The same for an anonymous visitor of an open catalog, a free account and a paid one.
- Each price names its source and the date it was reported.
- A collection row shows the price for its finish. Condition and language don't change it.
- No totals, charts or export of prices.

## Open questions

1. **Non-English printings.** What the bulk file carries as prices for a Japanese printing, and what such a printing shows ([#361](https://github.com/plainprogrammer/Collector/issues/361)).
2. **Scryfall's answer.** Research 016 read the published terms for hosting. It did not ask about recording daily prices and showing their history, on public card pages among others ([#362](https://github.com/plainprogrammer/Collector/issues/362)).
3. **An account's currency.** What an account whose currency is neither USD nor EUR sees ([#369](https://github.com/plainprogrammer/Collector/issues/369)).
4. **Prices that come and go.** If a price often flips between a value and nothing, a short wait before the empty row may be needed. The run record shows it.
5. **A hosted instance on another database.** If the hosted service leaves SQLite, the prices tables can join its main database.

## Filed

On the [1.0 milestone](https://github.com/plainprogrammer/Collector/milestone/1), in order:

| Issue | Outcome |
|---|---|
| [#361](https://github.com/plainprogrammer/Collector/issues/361) | Spike: prices on non-English printings |
| [#362](https://github.com/plainprogrammer/Collector/issues/362) | Ask Scryfall in writing about recording prices and showing their history |
| [#363](https://github.com/plainprogrammer/Collector/issues/363) | A prices database that the backup holds |
| [#364](https://github.com/plainprogrammer/Collector/issues/364) | A price source contract, and Scryfall's prices through it |
| [#365](https://github.com/plainprogrammer/Collector/issues/365) | Prices refresh once a day, and each change is recorded once |
| [#366](https://github.com/plainprogrammer/Collector/issues/366) | Each price refresh records what it did and how large the database is |
| [#367](https://github.com/plainprogrammer/Collector/issues/367) | An admin reads the price refresh log |
| [#368](https://github.com/plainprogrammer/Collector/issues/368) | An operator chooses how much price history the instance keeps |
| [#369](https://github.com/plainprogrammer/Collector/issues/369) | A card's market price on its page and in the collection |
| [#370](https://github.com/plainprogrammer/Collector/issues/370) | Operator documentation: what each price history level costs |

On the [2.0 milestone](https://github.com/plainprogrammer/Collector/milestone/2): [#371](https://github.com/plainprogrammer/Collector/issues/371), prices follow a printing that Scryfall merges into another. It needs Scryfall's `/migrations`, parked until after 1.0.
