# Feature 089: Prices Refresh Once a Day, and Each Change Is Recorded Once

**Status:** Draft, for Mode A review. The maintainer ruled decisions 1 to 4 as recommended on 2026-11-13 (relayed by the coordinator)
**Version:** 0.2.0
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Branch:** `089-daily-price-refresh`
**Issue:** [#365](https://github.com/plainprogrammer/Collector/issues/365)
**Builds on:** [`prices.md`](../../architecture/prices.md) (the prices database, the `WITHOUT ROWID` rules, the contract's absence rules), [spec 081](../081-prices-database-in-backup/spec.md), [spec 085](../085-price-source-contract/spec.md), [ADR 0029](../../adr/0029-prices-database-held-by-the-backup.md), [research 083](../083-non-english-printing-prices/research.md) and [ruling 41](../../roadmap.md#2026-11-13-prices-on-non-english-printings-research-083), the [price data design](../../superpowers/specs/2026-11-13-price-data-design.md) ("The daily refresh"), [`catalog-operations.md`](../../architecture/catalog-operations.md) (the refresh lifecycle this one follows in part), `.claude/rules/background-jobs.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.0 | 2026-11-13 | The maintainer's rulings on decisions 1 to 4 recorded (as recommended); decision 4's ceiling is a named constant documented as a guess until #366 measures it; the supersession of spec 002 FR-3's partial-file wording is named (MINOR) |
| 0.1.0 | 2026-11-13 | First draft |

---

## Problem Statement

The prices database has its five tables (spec 081) and Scryfall's prices come out of the bulk file as quotes (spec 085), but nothing reads a quote into a row. No price is stored, so no price history is being recorded, and history can't be downloaded again: every day without this job is a gap for good (design, "Constraints"). The job also has to be safe to leave running unattended for years. It writes the history, so a bad file, a double run or a half-parsed price must never delete or duplicate a row there.

## Goals

- Current prices refreshed once a day, by a scheduled job on the `sync` queue, separate from the weekly catalog refresh.
- A history row only where a price changed, dated by the bulk file's UTC date, so the same file twice changes nothing.
- A price the file no longer carries is removed from the current prices and recorded as a blank history row, and only when the file can be trusted to say so.
- A printing the catalog doesn't have yet is skipped and counted.
- Short write batches, no network inside a transaction, and never two runs at once.
- The run's identity, times, status and the counts this issue names, in `price_refresh_runs`.

## Non-Goals

- **The run's measurements** (#366): seconds downloading and processing, the file's size, lines read, printings matched, the database's size, WAL, free pages and row counts, peak memory. This spec records what the job did to rows; #366 records what it cost. The line is decision 2.
- **The admin page, and any start button or rake task** (#367). A run is started by the schedule, or by queuing the job from `bin/rails runner`.
- **History levels** (#368). Every priced printing gets history here; #368 narrows it.
- **Any reader or display of a price** (#369), including ruling 41's twin lookup.
- A source other than Scryfall, a price by condition, and prices that follow a merged printing (#371).
- An operator override that forces a withheld removal (decision 4): nothing asks for it yet.

## Users and Context

**Primary users:** the scheduler, and the later issues that read the rows (#366 to #369).
**Secondary users:** an operator, who sees one more scheduled job on `/admin/jobs` and a database that grows. A collector sees nothing.
**Usage context:** a Solid Queue job, once a day, on a volume with the catalog's downloaded file; and from specs with generated files. No request calls it.
**Vocabulary:** a *quote* and a *series* are as in [`prices.md`](../../architecture/prices.md). *Candidate* is a current price the file may speak for: its printing is a catalog entry in a configured language (decision 4). *Withheld* is a removal the run didn't apply because the file couldn't be trusted to say the price was gone.

## Decisions

### 1. A job of its own on the catalog's file

**The question (the issue's open point):** does the daily refresh share the catalog refresh's download and its operation lifecycle (`Catalog::Operation`)?

**Recommendation:** share the file, not the lifecycle.

- **The file.** The refresh asks the catalog's source for it, as the contract's comment allows (`Catalog.source_for(type)`: `#languages`, `#current_version`, `#download`), so the two refreshes read one file, a file one has downloaded is reused by the other (the source reuses a file of the published size), and an instance downloads 81 MB (English) or 408 MB (more languages) once, not twice. No member is added to `Prices::Sources`. The run's `source_version` is the string the catalog keeps as its version (`default-cards-20261113100623`).
- **The lifecycle.** The price refresh has its own job (`Prices::RefreshJob`, queue `sync`), its own run record (`PriceRefreshRun`, in the prices database) and its own small guard (decision 7). It does not use `Catalog::Operation`, `Catalog::RefreshRun`, the admin catalog page or `Catalog::Operation::Queue`: that lifecycle is built around the catalog's records and stages and the page that shows them, the catalog refresh must not learn of prices (design decision 10: the catalog refresh records no analytics), and the admin page for prices is #367's own. What it copies is the pattern: a run opened first, a stall rule for a run left behind, `retry_on` for transient errors, and the rate-limit retry module, which it includes (`Catalog::RateLimitRetry`, with no progress to report, since a rate limit ends a refresh before any row is written).
- **The shared directory.** Both jobs download into `storage/catalog/<type>/` through a partial file, and the source prunes to the newest `KEEP_DOWNLOADS` files. Two downloads of one file at once would write one partial file. The source's partial file gets a name of its own per download, so a second download is wasteful but harmless (the catalog source's `fetch`, a one-line change that supersedes spec 002 FR-3's "a partial file" wording by naming it unique).

**Alternatives:** (a) a fully shared lifecycle (one operation, two stages) couples the catalog refresh to prices and makes a prices failure look like a catalog failure; (b) a separate download (a second request for the bulk-data index and a second 81 to 408 MB file a day) is the simplest and the most wasteful.

### 2. What a run records at this stage, and where the line is

**Recommendation:** `price_refresh_runs` already has the run's identity (source, `run_on`, `source_version`, status, error) and its times (`started_at`, `finished_at`). A migration adds `languages` and the counts of what the job did to rows, all integers that default to 0:

| Column | Counts |
|---|---|
| `languages` | the sorted language set read (a string, as the catalog's run keeps it) |
| `quotes_seen` | quotes read from the file, for printings known or not |
| `unchanged` | quotes whose price equals the current price: nothing written |
| `changed` | quotes whose price differs from the current price: current price and history row written |
| `added` | quotes of a printing and series with no current price: written the same way |
| `removed` | prices whose absence was applied: current price deleted, blank history row written |
| `removals_withheld` | candidates that were absent from the file and not removed, because the file couldn't be trusted (decision 4) |
| `unknown_printings` | printings in the file the catalog doesn't have, each counted once |
| `malformed` | `Malformed` records, of any kind |

**The line.** Everything above is a count of a decision the job took, which this issue's rules need (the unknown printings are the issue's own; `removals_withheld` and `malformed` show a guard worked). Left to #366: time spent downloading and processing, the file's size, lines read, printings matched, the prices database's size, WAL, free pages and row counts, and peak memory. History rows written is `changed + added + removed`, so it has no column. A migration adds the columns with `add_column` (safe on this rowid table: the `WITHOUT ROWID` trap is for the two large tables); the structure file is updated with it.

`error` holds the reason a run didn't finish: the error of a failed run (`"<class>: <message>"`), or why it was skipped. A skipped run is never "applied".

### 3. The run's date and what "unchanged" means for `reported_on`

The run's date is the UTC date of the bulk file (`#reported_on`, spec 085 decision 4), never the clock's. A quote is *unchanged* when its cents equal the current price's; nothing is written for it, so `current_prices.reported_on` and `changed_on` are both the run date of the last write. The two columns therefore agree for every row this job writes; both are written because spec 081 made both, and a later source that reports per quote may separate them.

**The consequence to hand to #369:** a price's freshness is not on its row. A price is current as of the source's latest finished run's `run_on`, which is what a page labels "as of". **Recommendation:** accept this. The alternative (rewriting `reported_on` on every unchanged price) writes the whole table daily, which the design's anti-goal and the issue's "nothing is written" rule exclude.

A file whose date is earlier than the latest finished run's `run_on` for the source is skipped, not applied: a history row dated before a later one would reorder history that readers take in date order. A file of the same date and another version (a second publication that day, or a changed language set) is applied: its unchanged prices write nothing, and its changes write one history row per series and date, replacing a row of the same date (decision 6).

### 4. "Gone" is not "the file is bad"

A source yields no quote for a price the file leaves empty (spec 085 decision 2), and it can't say whether a printing with no quote was in the file at all. So "gone" is told from absence, and absence is trusted only as far as the file is.

**A current price is a candidate for removal** when its printing is a catalog entry of the collectible type, in a language of the run's `languages`, whether or not the entry is retired. A price whose printing the primary doesn't have (a restore's lag, spec 081) or whose language isn't configured (an operator dropped `ja`) is left alone: the file wasn't asked about it. A candidate with no quote in this file is *absent*.

**An absent candidate is removed** (the current price is deleted and a history row with no cents is written for the run's date) only when all of these hold; otherwise it is withheld and counted in `removals_withheld`:

1. **The file was read to the end.** A corrupt or cut-short gzip raises, the run fails, and no removal is made. Changes and additions already written stand: each was a valid quote, and each batch commits whole.
2. **The file has at least one quote.** An empty file, or one with nothing readable, fails the run (`no valid quotes`), as the catalog's refresh fails one with no valid records. Nothing is written.
3. **No `Malformed` names no printing** (a line that isn't JSON or has no `id`): such a line could have been any card, so the run's absences can't be trusted, and every removal is withheld (spec 085 decision 2).
4. **No `Malformed` names this printing** (a card whose `prices` isn't an object, or whose price in this series couldn't be read): that series, or every series of the printing, is withheld. An unreadable price is not an absent one (spec 085 decision 2; the contract's comment).
5. **The removals are a small share of the candidates.** If the absent candidates (after 3 and 4) exceed `MAX_REMOVED_SHARE` of all candidates, none is applied and the run fails, `error` saying how many of how many. A file that lost a tenth of the market's prices in one day is a truncated or damaged publication far more often than a market event. The value is a measurement-free first guess: #366's run records show the real daily share, and the constant moves with them.

**What fails the run versus what finishes it.** Items 1, 2 and 5 fail it (an operator should look); 3 and 4 finish it with `removals_withheld` counted, because the next day's file will remove the price if it is really gone, and the quotes that were readable are applied. A failed run is not "applied" (decision 5), so the same file is read again on the next run.

**Ruled (maintainer, 2026-11-13):** 10 percent, and a breach fails the run. `MAX_REMOVED_SHARE` is a named constant whose comment and whose row in `prices.md`'s Named constants table say it is a guess until #366 measures the daily share of disappearing prices, and that a real drop above it is refused until the constant moves.

**Limit.** A real, permanent drop above the ceiling is refused every day until the ceiling moves. Nothing forces it now (Non-Goals). The failed run says so in plain words.

### 5. A file is applied once

A run is *applied* when it finished. Before downloading, the job asks the source for the current version and languages. It records the run `skipped` with `"<version> already applied"` when a finished run of the same source has the same `source_version` and the same `languages` (a run's language set matters: `en,de` and `en,ja` both read `all_cards`, and the second adds printings the first never stored). A file older than the latest finished run (decision 3) is skipped with a reason that says so. A catalog with no printings of the type is skipped with a reason, before any download: there is nothing to attach a price to, and the file isn't consumed. A skipped run changes nothing but its own row.

### 6. Writes: the four cases

Quotes are read in file order. The job collects the printings of a batch (`BATCH_SIZE` printings), finds their catalog ids with one query on the primary (by `external_key`, per batch; no join across files), reads their current prices from the prices database, and writes the batch in one transaction on the prices database:

| The quote | Current price | Written |
|---|---|---|
| the printing is unknown to the catalog | none | nothing; the printing is counted once in `unknown_printings` |
| equals the current price | one | nothing |
| differs from the current price | one | the current price updated (`cents`, `reported_on` and `changed_on` the run date) and a history row for the run date with the new cents |
| the printing and series have none | none | the current price inserted and a history row, the same |
| no quote, a trusted absence (decision 4) | one | the current price deleted and a history row for the run date with no cents |

A history row is written with an upsert on its primary key: if a row for the same printing, series and date exists (a second file of that date), the later cents replace it, so the key is never violated and a rerun is safe. `reported_on` and `changed_on` are the run date for a row the job writes (decision 3). Removals are applied after the whole file was read, in their own batches, from a keyset walk over the source's current prices by printing id.

A price that was removed and returns is an `added` quote. `Malformed` records are counted and logged (`prices.refresh skipped malformed …`, the key and the error), as the catalog does.

### 7. One run at a time, a run left behind, batches and the network

- **Overlap.** `Prices::RefreshJob` holds a queue concurrency lock per source (`LOCK_FOR`), so a second job waits its turn. `PriceRefreshRun.start!` records a new run `skipped` (`already running`) while another run of the source is running and not left behind.
- **A run left behind.** A running run whose last progress (`updated_at`, touched at each batch and, while downloading, at most every `HEARTBEAT_EVERY` seconds through the catalog source's optional `#progress=` hook) is older than `STALL_AFTER`, or whose job id is the starting job's own (the queue re-ran it after a restart), is closed `failed` with `interrupted` when the next run starts. This is the catalog refresh's rule without its queue reading: the price job has no waiting retry to defer to, and #367 may add the queue's view.
- **Batches.** `BATCH_SIZE` is 1,000 printings, so a batch is a few thousand rows. A batch's transaction holds only writes to the prices database and reads of it; the primary's lookup, the file read and the download happen outside any transaction. The progress write is outside the batch transaction.
- **Retries.** `retry_on` for the catalog source's `TransientError`, `ActiveRecord::StatementTimeout` and `SQLite3::BusyException`, then the rate-limit module; `discard_on` for a failed guard (decision 4) and `Prices::Sources::IntegrityError`, which a retry can't fix. The failed run is already recorded.

### 8. The job, the schedule and the files

`Prices::RefreshJob` (`app/jobs/prices/refresh_job.rb`, queue `sync`, argument: the source's key) calls `Prices::Refresh` (`app/models/prices/refresh.rb`), which owns the decisions above. The models `CurrentPrice`, `PriceChange` and `PriceRefreshRun` are added (spec 085 left them out) on composite primary keys; writes are bulk (`insert_all`, `upsert_all`, `delete_all` by key), which skips validations on purpose, as the rows come from a validated `Quote` (a header comment says so). The job's schedule is one line in `config/recurring.yml`, production only like the catalog's: `refresh_prices`, `args: ["scryfall"]`, `queue: sync`, `at 11:30am every day` (the file seen on 2026-11-13 was published at 10:06 UTC, research 083; the host's time zone is the container's, UTC unless the operator sets one, and the run's date comes from the file whenever it runs). The backup advice ("never Monday 03:00 to 05:00") gains the daily window (ADR 0029, Cost).

Core files name no collectible, comments included: `spec/price_source_core_spec.rb` lists the new ones. The job's schedule line is the one place the source's key is written outside its own class and the initializer.

## User Stories

### Story 1: A file is applied once, and the date is the file's

**As** an operator **I want** the daily job to apply each day's file once **So that** the history doesn't grow when nothing changed

- [ ] **AC-1.1** Given a bulk file for 2026-11-13 and no earlier run When the job runs Then a run is `finished` with `run_on` 2026-11-13, the file's `source_version` and the language set, and `started_at` and `finished_at` set.
- [ ] **AC-1.2** Given AC-1.1 has finished When the job runs again on the same file and languages Then the new run is `skipped` with `<version> already applied`, no row of `current_prices` or `price_changes` changes, and nothing is downloaded again.
- [ ] **AC-1.3** Given a finished run of `all_cards` with `en,ja` When the job runs with `en,de` Then the file is applied, because the language set differs.
- [ ] **AC-1.4** Given a finished run dated 2026-11-13 and a file dated 2026-11-12 When the job runs Then the run is `skipped` with a reason naming the later date, and nothing changes; and Given a second file dated 2026-11-13 with another version Then it is applied.
- [ ] **AC-1.5** Given no catalog entry of the type When the job runs Then the run is `skipped` with a reason, no file is downloaded, and no row is written.
- [ ] **AC-1.6** Given the clock is a different UTC day from the file's When the job runs Then every written row carries the file's date.
- [ ] **AC-1.7** Given the job is performed twice on one file (perform, then perform again) When both have finished Then the rows of both tables are the same as after the first (idempotency), and a run is recorded for each.

### Story 2: Each quote is judged, and a change is recorded once

**As** the history **I want** a row only where a price changed **So that** it stays small

- [ ] **AC-2.1** Given a quote whose printing and series have no current price When it is applied Then a current price exists with those cents and the run date as `reported_on` and `changed_on`, one history row for the run date has those cents, and `added` is 1.
- [ ] **AC-2.2** Given a quote equal to the current price When it is applied Then no row of either table changes (the current price's dates stay), and `unchanged` is 1.
- [ ] **AC-2.3** Given a quote that differs When it is applied Then the current price has the new cents and the run date, one history row for the run date has the new cents, the earlier history rows are untouched, and `changed` is 1.
- [ ] **AC-2.4** Given a current price whose printing the file carries with no quote for that series, and a trusted file When it is applied Then the current price is gone, one history row for the run date has no cents, and `removed` is 1; and Given the price comes back in a later file Then it is an added quote with its own history row.
- [ ] **AC-2.5** Given a quote of a printing the catalog doesn't have When it is applied Then no row is written for it, and `unknown_printings` counts the printing once however many series it has.
- [ ] **AC-2.6** Given a quote for each series of one printing in several states (new, equal, changed) When applied Then each is judged on its own series.
- [ ] **AC-2.7** Given a history row already exists for a printing, series and date, and a later file of that date differs When it is applied Then the row's cents are replaced and no second row exists.
- [ ] **AC-2.8** Given a printing, a source and a series When any run writes it Then the rows are keyed by the catalog entry's id, no query joins or attaches the two database files, and no row has an `account_id`.

### Story 3: A bad file changes nothing it shouldn't

**As** an operator **I want** a truncated or unreadable file to leave history alone **So that** a bad day isn't recorded as a market crash

- [ ] **AC-3.1** Given a `Malformed` that names a series for a printing with a current price in that series, and no quote for it When the run finishes Then that price is not removed and no history row is written for it, the other series of the printing are judged as usual, and `malformed` and `removals_withheld` count it.
- [ ] **AC-3.2** Given a `Malformed` with a printing's key and no series When the run finishes Then none of that printing's prices is removed.
- [ ] **AC-3.3** Given a `Malformed` with no key When the run finishes Then no price is removed at all, quotes before and after it are applied, and `removals_withheld` counts the candidates.
- [ ] **AC-3.4** Given a gzip file cut short after some cards When the job runs Then the run is `failed` with the reader's error in `error`, no price is removed, the prices written before the cut stand, and the next run of a whole file of that date applies the rest and writes no row twice.
- [ ] **AC-3.5** Given an empty file, or one in which nothing is readable When the job runs Then the run is `failed` with `no valid quotes`, and no row of either price table is written.
- [ ] **AC-3.6** Given absent candidates above `MAX_REMOVED_SHARE` of all candidates When the run reaches its removals Then none is applied, the run is `failed` and `error` names how many of how many, and the quotes' changes already written stand; and Given absent candidates at or below the share Then they are removed.
- [ ] **AC-3.7** Given a current price whose printing is in a language the run didn't read, or that the primary doesn't have When the file lacks it Then it is not removed and is not counted as withheld.
- [ ] **AC-3.8** Given a failed run When the job runs again on the same file Then the file is read again (a failed run is not applied).

### Story 4: One run at a time, in short batches

**As** the instance **I want** runs that never overlap and never hold the database long **So that** the app stays responsive and the history isn't written twice

- [ ] **AC-4.1** Given a run that is running with recent progress When another job starts Then its run is `skipped` with `already running`, and nothing is downloaded or written.
- [ ] **AC-4.2** Given a running run whose last progress is older than `STALL_AFTER`, or whose job id is the starting job's When a job starts Then that run is closed `failed` with `interrupted` and the new run proceeds.
- [ ] **AC-4.3** Given `Prices::RefreshJob` When its concurrency limit is read Then it is one job per source key for `LOCK_FOR`, on queue `sync`.
- [ ] **AC-4.4** Given a file of more printings than `BATCH_SIZE` When it is applied Then no transaction on the prices database holds more than `BATCH_SIZE` printings' rows (counted through the connection's transaction events), and the run row is written outside them.
- [ ] **AC-4.5** Given the whole run, with WebMock blocking every request not stubbed When it applies a downloaded file Then no request happens inside a transaction (the check is a subscriber that fails an HTTP call while a transaction is open).
- [ ] **AC-4.6** Given a transient error from the source, a busy database or a rate limit When the job runs Then it is retried by the rules of decision 7; and Given an `IntegrityError` or a failed guard Then it is discarded and the run reads `failed`.

### Story 5: A schedule, run records and documents

**As** a maintainer **I want** the job scheduled and the records and documents current **So that** the next issues build on them

- [ ] **AC-5.1** Given `config/recurring.yml` When the production block is read Then `refresh_prices` runs `Prices::RefreshJob` with `scryfall` on queue `sync`, at a time of day other than the catalog refresh's, and the development block has none.
- [ ] **AC-5.2** Given the migration When the prices database is built from the migrations and from `db/prices_structure.sql` Then both have the columns of decision 2, `current_prices` and `price_changes` are still `WITHOUT ROWID` (`spec/prices_schema_spec.rb`), and the upgrade proof (`ruby script/upgrade/guard.rb`, `bin/upgrade-smoke`) and `spec/backup_guards_spec.rb` pass.
- [ ] **AC-5.3** Given a finished run When it is read Then its counts are those of the file (the example of AC-2.6 gives the numbers), and `quotes_seen = unchanged + changed + added + (quotes of unknown printings)`.
- [ ] **AC-5.4** Given the new core files When the guard reads them, comments included Then none names a collectible, source or marketplace.
- [ ] **AC-5.5** Given `bin/ci checks` When it runs Then new public code has comments, YARD builds, and RuboCop and Brakeman pass.
- [ ] **AC-5.6** Given a generated file of 110,000 cards with about 300,000 quotes and their entries in a test database under `tmp/` When the job applies it as a first run, and again as a typical day (10 to 20 percent of prices changed) Then the example records both durations and the peak memory (`:timing`, no threshold, spec 085's convention).
- [ ] **AC-5.7** Given `prices.md`, `catalog-operations.md`, `README.md`'s backup advice, `docs/roadmap.md`, `docs/specs/README.md` and `CLAUDE.md` When read Then they state what the job does, with the source of each statement (verified by reading, recorded in `verification.md`).

## Functional Requirements

### FR-1: The refresh

**Must:** apply decisions 3 to 6 and 8; write the history only through the cases of decision 6; record the run (decision 2); verify and sync the source (`PriceSource.sync!`) at the start of every run.
**Must not:** write a price whose quote was a `Malformed`, remove one the file can't be trusted about, call the network inside a transaction, read the primary inside a prices transaction, join the two files, name a collectible in a core file, or touch the catalog's tables.

### FR-2: The job and its guard

**Must:** decisions 1, 5 and 7: one job per source at a time, a run record for every attempt, the stall rule, the retries.
**Must not:** use `Catalog::Operation` or `Catalog::RefreshRun`, or change what the catalog refresh does (apart from the partial file's name, decision 1).

### FR-3: The schema change

**Must:** add the columns of decision 2 with a migration of its own (never edit a released one), update `db/prices_structure.sql`, and keep both large tables `WITHOUT ROWID`.

## Non-Functional Requirements

### Performance

- The first run writes about 300,000 current prices and as many history rows (English only) in batches of 1,000 printings; a typical day writes the changes only. AC-5.6 records the durations: they are a measurement, not a gate, and #366 replaces them with the run's own numbers.
- Memory holds the set of series judged this run (for the absences) and the unknown printings' keys, not the file: one printing's batch of quotes at a time otherwise. The example records the peak.

### Security

- Prices are global data: no account, no `Current.account`, nothing in the export. The job reads a file its source downloaded and a key it was queued with; nothing user-supplied reaches a query (bind parameters throughout).

### Reliability

- The job is at-least-once safe: every batch commits whole and is idempotent on its keys, and removals are computed from the file read to the end.
- A killed run leaves its row `running`, which the next run closes (decision 7).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The bulk-data index lists no such file, or Scryfall times out | `TransientError`: the run fails, the job retries a few times, seconds apart |
| Scryfall answers 429 | The rate-limit module reschedules the job after the wait it asked for; the run is failed, the retry records its own |
| The download is the wrong size | The catalog source's `IntegrityError`; the run fails; the job is discarded and the next day's run tries again |
| The file's name carries no date | `Prices::Sources::IntegrityError`; the run fails, nothing is written, the job is discarded |
| The gzip is cut short | The run fails; no removal; what was written stands (AC-3.4) |
| A card line is unreadable | Counted and logged; the readable lines apply; every removal is withheld |
| The database is busy | The batch rolls back; the job retries; the next attempt finds the earlier batches written and judges them unchanged |
| The process is killed mid-run | The row stays `running` until the next run closes it as `interrupted` |
| Two jobs start together | The queue holds one back; if both start, the second is `skipped` |
| An operator removes a language | Prices of that language's printings are left alone, not removed |

## Open Questions

None are open. The maintainer ruled decisions 1 to 4 on 2026-11-13: (1) the file is shared and the lifecycle isn't, with a unique partial-download name; (2) the run's columns and the line with #366; (3) a price's freshness is the source's latest finished `run_on`, not a column, and earlier-dated files are skipped; (4) the removal conditions, a ceiling of 10 percent, and a failed run on breach. The schedule's 11:30 is a guess from one day's publication time and is a one-line change.

**Supersession (decision 1):** this spec supersedes spec 002 FR-3's wording that a download goes through "a partial file": the partial file's name is unique per download. It is recorded here and in `docs/specs/README.md` (the 002 row's superseded-by cell and this spec's row), and in [`catalog-operations.md`](../../architecture/catalog-operations.md).

## Out of Scope (Future Considerations)

- The measurements (#366), the admin log with a view of the queue (#367), the history levels (#368), the display (#369), the cost documentation (#370).
- A manual start (button or rake task) and an operator override of a withheld removal.
- Following a merged printing (#371).
