# Feature 089: Prices Refresh Once a Day, and Each Change Is Recorded Once

**Status:** Approved by the coordinator under the maintainer's delegation (2026-11-13), after two Mode A review rounds (Fable 5.2). The maintainer ruled decisions 1 to 4 as recommended on 2026-11-13 (relayed by the coordinator)
**Version:** 0.4.3
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Branch:** `089-daily-price-refresh`
**Issue:** [#365](https://github.com/plainprogrammer/Collector/issues/365)
**Builds on:** [`prices.md`](../../architecture/prices.md) (the prices database, the `WITHOUT ROWID` rules, the contract's absence rules), [spec 081](../081-prices-database-in-backup/spec.md), [spec 085](../085-price-source-contract/spec.md), [ADR 0029](../../adr/0029-prices-database-held-by-the-backup.md), [research 083](../083-non-english-printing-prices/research.md) and [ruling 41](../../roadmap.md#2026-11-13-prices-on-non-english-printings-research-083), the [price data design](../../superpowers/specs/2026-11-13-price-data-design.md) ("The daily refresh"), [`catalog-operations.md`](../../architecture/catalog-operations.md) (the refresh lifecycle this one follows in part), `.claude/rules/background-jobs.md`
**Supersedes:** spec 002 FR-3's wording that a download goes through "a partial file" (decision 1); spec 081's table for `price_refresh_runs`, whose `run_on` was `NOT NULL` (decision 2)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.4.3 | 2026-11-13 | Execution: the count column `changed` is `repriced`, because Active Record reserves the attribute name `changed` and `PriceRefreshRun` can't be built with it; decision 2's table, the identity of AC-5.3 and the history-rows sentence follow; no behaviour changes (PATCH) |
| 0.4.2 | 2026-11-13 | Plan review round 1: AC-4.4 measures savepoint spans, not transaction depth, because the suite's non-joinable transaction makes every write a savepoint (a testing method; no behaviour changes) (PATCH) |
| 0.4.1 | 2026-11-13 | Approved (Gate A). Status line only (PATCH) |
| 0.4.0 | 2026-11-13 | Review round 2 fixes (listed in the 0.3.0 row's second half); not re-reviewed (two rounds is the limit) |
| 0.3.0 | 2026-11-13 | Review round 1 (Fable 5.2): `run_on` becomes nullable and `job_id` is added (a run opens before its file's date is known); stale partial downloads are pruned; a removal batch is atomic; errors and their fates are one table, with no `discard_on` (a guard failure shows under Failed on `/admin/jobs`); the older-file guard counts finished and failed runs (a failed run may have written rows); `quotes_seen` counts known printings only; constants have values; duplicate quotes and an undeclared series are decided; ACs added for the uncovered rules; AC-4.4 and AC-4.5 rebuilt so they can be written; the index row. Review round 2 (Fable 5.2): the source is looked up and synced before a run exists; "at least one quote" is any `Quote` yielded; the ceiling is two-phase and needs ten candidates in examples; counts are tallied after commit; a catch-all row and the no-discard rationale in the errors table; the download-size error is retried; stale partials by mtime; `#download` must tolerate concurrent calls (the catalog contract's comment); `down` of the migration; AC wording (MINOR) |
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

- **The run's measurements** (#366): seconds downloading and processing, the file's size, lines read, printings matched, the prices database's size, WAL, free pages and row counts, and peak memory. This spec records what the job did to rows; #366 records what it cost. The line is decision 2. (The design's "Prices" and "Writes" groups and its unknown ids moved here; #366 owns the rest.)
- **The admin page, and any start button or rake task** (#367). A run is started by the schedule, or by queuing the job from `bin/rails runner`.
- **History levels** (#368). Every priced printing gets history here; #368 narrows it.
- **Any reader or display of a price** (#369), including ruling 41's twin lookup.
- A source other than Scryfall, a price by condition, and prices that follow a merged printing (#371).
- An operator override that forces a withheld removal (decision 4): nothing asks for it yet.

## Users and Context

**Primary users:** the scheduler, and the later issues that read the rows (#366 to #369).
**Secondary users:** an operator, who sees one more scheduled job on `/admin/jobs` and a database that grows. A collector sees nothing.
**Usage context:** a Solid Queue job, once a day, on a volume with the catalog's downloaded file; and from specs with generated files. No request calls it.
**Vocabulary:** a *quote* and a *series* are as in [`prices.md`](../../architecture/prices.md). A *candidate* is a current price the file may speak for: its printing is a catalog entry in a configured language (decision 4). An *absent* candidate has no quote in the file. *Withheld* is a removal the run didn't apply because the file couldn't be trusted to say the price was gone.

## Decisions

### 1. A job of its own on the catalog's file (ruled by the maintainer, 2026-11-13)

**The question (the issue's open point):** does the daily refresh share the catalog refresh's download and its operation lifecycle (`Catalog::Operation`)? **Ruled:** share the file, not the lifecycle.

- **The file.** The refresh asks the catalog's source for it, as the contract's comment allows (`Catalog.source_for(type)`, a fresh instance per call: `#languages`, `#current_version`, `#download`), so the two refreshes read one file. A file one has downloaded is reused by the other when both see the same version (the source reuses a file of the published size). That is about once a week for an English-only instance, where the weekly catalog refresh finds the day's file already on disk; an instance with more languages reads `all_cards` (408 MB) and downloads it daily whichever job runs first, a cost the price refresh adds (Non-Functional Requirements). No member is added to `Prices::Sources`. The run's `source_version` is the string the catalog keeps as its version (`default-cards-20261113100623`).
- **The lifecycle.** The price refresh has its own job (`Prices::RefreshJob`, queue `sync`), its own run record (`PriceRefreshRun`, in the prices database) and its own small guard (decision 7). It does not use `Catalog::Operation`, `Catalog::RefreshRun`, the admin catalog page or `Catalog::Operation::Queue`: that lifecycle is built around the catalog's records and stages and the page that shows them, the catalog refresh must not learn of prices (design decision 10), and the page for prices is #367's. What it copies is the pattern: a run opened first, a stall rule for a run left behind, `retry_on` for transient errors, and the rate-limit module (`Catalog::RateLimitRetry`, answering no progress, since a rate limit comes before any row is written).
- **The shared directory.** Both jobs download into `storage/catalog/<type>/` through a partial file, and the source prunes to the newest `KEEP_DOWNLOADS` files. Two downloads of one file at once would write one partial file, so the partial file's name is unique per download (`<file>.<random>.part`) and a second download is wasteful but harmless. A unique name leaves an orphan when a download is killed, where the fixed name was overwritten by the next one, so `prune` also deletes a partial file (`*.part`, so a fixed-name one from an earlier build is caught too) whose mtime is older than `STALE_PARTIAL_AFTER` (1 day: a live download is far younger, since the jobs' 6 hour locks end a job that never reports, so a partial file a day old belongs to a killed download). Both changes are in `MTG::Scryfall::Source` (`#fetch` and `#prune`) and supersede spec 002 FR-3's "a partial file". The contract's comment (`app/models/catalog/sources.rb`) is the binding statement, and `#download` now has two callers that can run together, so it gains one line: `#download` must tolerate concurrent calls for one version.

**Alternatives:** (a) a fully shared lifecycle (one operation, two stages) couples the catalog refresh to prices and makes a prices failure look like a catalog failure; (b) a separate download (a second request for the bulk-data index and a second 81 to 408 MB file a day) is the simplest and the most wasteful.

### 2. What a run records at this stage, and where the line is (ruled, 2026-11-13)

`price_refresh_runs` has the run's identity (source, `run_on`, `source_version`, status, error) and its times (`started_at`, `finished_at`). Two of its facts don't fit this job and change:

- **`run_on` becomes nullable.** A run opens before its file is known, and some end before it is: `already running`, an empty catalog, a transient error, a rate limit, a bad language setting. The date can't be read from the version before download (the file's name, and the date in it, is the source's: spec 085 decision 4). So `run_on` is nil until the file's date is known; a run skipped as already applied copies the `run_on` of the finished run it matched; every run that reads the date (after the download) records it, whatever its outcome. This supersedes spec 081's table (`run_on` `NOT NULL`).
- **`job_id` is added** (a nullable string, the Active Job id), for the stall rule of decision 7.

A migration (`db/prices_migrate/`, a new one: released migrations are never edited) makes `run_on` nullable by rebuilding `price_refresh_runs`, a rowid table (the `WITHOUT ROWID` trap is for the two large tables), keeping its status check, its foreign key and its index, adds `job_id` and `languages` (nullable strings) and the counts below (integers, `null: false, default: 0`), and `db/prices_structure.sql` is re-dumped with it:

| Column | Counts |
|---|---|
| `languages` | the sorted language set read, as the catalog's run keeps it (`"en,ja"`) |
| `quotes_seen` | quotes of printings the catalog has, read from the file: `unchanged + repriced + added`. A duplicate of a quote already read in this file is not counted |
| `unchanged` | quotes whose price equals the current price: nothing written |
| `repriced` | quotes whose price differs from the current price: current price and history row written (the column is not `changed`: Active Record reserves that attribute name, and a model of the table can't be built with it) |
| `added` | quotes of a printing and series with no current price: written the same way |
| `removed` | prices whose absence was applied: current price deleted, blank history row written |
| `removals_withheld` | absent candidates that were not removed for any reason in decision 4 (a `Malformed`, a keyless `Malformed`, or the ceiling) |
| `unknown_printings` | printings in the file the catalog doesn't have, each counted once; their quotes are in no other count |
| `malformed` | `Malformed` records, of any kind |

**The line.** Everything above counts a decision the job took. Left to #366: time spent downloading and processing, the file's size, lines read, printings matched, the prices database's size, WAL, free pages and row counts, and peak memory. History rows written is `repriced + added + removed`, so it has no column.

`error` holds the reason a run didn't finish: the error of a failed run (`"<class>: <message>"`), or why it was skipped. A skipped run is never "applied". A failed run's counts are those so far: the counts are tallied after a batch commits (a rolled-back batch adds nothing) and persisted with each progress touch, so a run closed as `interrupted` keeps the counts of its last touch. A run skipped as already applied records its `source_version` and `languages`.

The migration's `down` fills a nil `run_on` with the date of the run's `started_at`, restores `NOT NULL`, and drops the added columns (it never loses a row). The plan adds the columns first and rebuilds the table last, so the stored SQL is canonical.

### 3. The run's date and what "unchanged" means for `reported_on` (ruled, 2026-11-13)

The run's date is the UTC date of the bulk file (`#reported_on`, spec 085 decision 4), never the clock's. A quote is *unchanged* when its cents equal the current price's; nothing is written for it, so `current_prices.reported_on` and `changed_on` are both the run date of the last write. The two columns agree for every row this job writes; both are written because spec 081 made both, and a later source that reports per quote may separate them.

**The consequence to hand to #369:** a price's freshness is not on its row. A price is current as of the source's latest *finished* run's `run_on`, which is what a page labels "as of". Ruled: accept this; the alternative (rewriting `reported_on` on every unchanged price) writes the whole table daily, which the design's anti-goal and the issue's "nothing is written" rule exclude. Prices the run leaves alone (a language not configured, a printing the primary lacks) are not touched and go stale with no marker on their row. **Known limit:** while the ceiling of decision 4 fails every run (a day's worth of one currency vanishing, say), the other prices' changes are still written daily and dated, but no run finishes, so the "as of" label lags until one does. #367 shows the failed runs.

**Older files.** A file whose date is earlier than the latest `run_on` of the source's finished or failed runs (a failed run may have written rows) is skipped after the download, with a reason that names the later date: a history row dated before a later one would reorder history that readers take in date order. A file of the same date and another version (a second publication that day, or a changed language set) is applied: its unchanged prices write nothing, and its changes write one history row per series and date, replacing a row of that date (decision 6). A same-date file that returns a price to its value of the day before leaves a history row equal to the row before it; accepted.

### 4. "Gone" is not "the file is bad" (ruled, 2026-11-13)

A source yields no quote for a price the file leaves empty (spec 085 decision 2), and it can't say whether a printing with no quote was in the file at all. So "gone" is told from absence, and absence is trusted only as far as the file is.

**A current price is a candidate for removal** when its printing is a catalog entry of the collectible type, in a language of the run's `languages`, whether or not the entry is retired. A price whose printing the primary doesn't have (a restore's lag, spec 081) or whose language isn't configured (an operator dropped `ja`) is left alone: the file wasn't asked about it, and it is not counted as withheld. A printing missing from the file altogether, and a retired entry the file no longer lists, are absent like any other. (A printing whose language changed to one not configured, and a card whose `lang` is missing or garbled and so is filtered out by the source without a `Malformed`, are removed as absent: rare, the source's contract behaviour, and bounded by the ceiling.) A candidate with no quote in this file is *absent*.

**An absent candidate is removed** (the current price is deleted and a history row with no cents is written for the run's date) only when all of these hold; otherwise it is withheld and counted in `removals_withheld`:

1. **The file was read to the end.** A corrupt or cut-short gzip raises, the run fails, and no removal is made. Changes and additions already written stand: each was a valid quote, and each batch commits whole.
2. **The source yielded at least one `Quote`**, for a known printing or not (this tally is not `quotes_seen`, which counts known printings only: a catalog that lags the file, a language just added, must not fail a sound file). An empty file, or one with nothing readable, fails the run (`no valid quotes`), as the catalog's refresh fails one with no valid records. Nothing is written.
3. **No `Malformed` names no printing** (a line that isn't JSON or has no `id`): such a line could have been any card, so the run's absences can't be trusted, and every removal is withheld (spec 085 decision 2).
4. **No `Malformed` names this printing** (a card whose `prices` isn't an object, or whose price in this series couldn't be read): that series, or every series of the printing, is withheld. An unreadable price is not an absent one (spec 085 decision 2; the contract's comment).
5. **The removals are a small share of the candidates.** The candidates are the rows of `current_prices` of the source that meet the rule above (printing and series, not printings). The run is two-phase here: the walk over the candidates counts all of them and their absences before the first removal batch, so the ceiling is judged on the whole. If the absent candidates left after items 3 and 4 exceed `MAX_REMOVED_SHARE` of all candidates (compared exactly: `absent > candidates * MAX_REMOVED_SHARE` with a `Rational`), none is applied and the run fails, `error` saying how many of how many, and every absent candidate is counted in `removals_withheld`. A file that lost a tenth of the market's prices in one day is a truncated or damaged publication far more often than a market event.

**What fails the run and what finishes it.** Items 1, 2 and 5 fail it, and the job's failure shows under Failed on `/admin/jobs` (decision 7); 3 and 4 finish it with `removals_withheld` counted, because the next day's file will remove the price if it is really gone, and the quotes that were readable are applied. A failed run is not "applied" (decision 5), so the same file is read again by the next run.

**Ruled (maintainer, 2026-11-13):** 10 percent, and a breach fails the run. `MAX_REMOVED_SHARE` is `Rational(1, 10)`, a named constant whose comment and whose row in `prices.md`'s Named constants table say it is a guess until #366 measures the daily share of disappearing prices, and that a real drop above it is refused until the constant moves.

**Limit.** A real, permanent drop above the ceiling is refused every day until the constant moves. Nothing forces it now (Non-Goals). The failed run says so in plain words. Because the ceiling is a share, an example that removes a price needs at least ten candidate rows (or sets the constant with `stub_const`); the examples of AC-2.4, AC-2.9 and AC-3.9 say which.

### 5. A file is applied once

A run is *applied* when it finished. The job decides in this order:

0. **The source is looked up and synced** (`Prices.source_class(key)`, then `PriceSource.sync!`), before any run exists: a run's `price_source_id` is `NOT NULL` with a foreign key, so there can be no run row without the source's row. An unregistered key, or a class that fails verification, fails the job with no run (the one failure with no run record; it is a defect of the build, not of a day). Then `PriceRefreshRun.start!` opens the run (decision 7: `already running`, or a run left behind closed).
1. **The catalog has no printing of the type:** the run is skipped with a reason (`run_on` nil), before anything is asked of the catalog's source: there is nothing to attach a price to.
2. **Before downloading**, the job asks the catalog's source for the current version and languages. It records the run `skipped` with `"<version> already applied"` (`run_on` copied from the matched run, `source_version` and `languages` recorded) when a finished run of the same source has the same `source_version` and the same `languages`. The language set matters: `en,de` and `en,ja` both read `all_cards`, and the second adds printings the first never stored.
3. **After the download**, the file's date is read. A file older than decision 3's rule is skipped with its reason.

A skipped run changes nothing but its own row. A file the job did not skip is read once, in one run.

### 6. Writes: the four cases

Quotes are read in file order. The first quote of a printing and series in a file is the one judged; a later duplicate is ignored and not counted. The job collects the printings of a batch (`BATCH_SIZE` printings), finds their catalog ids with one query on the primary (by `external_key`, per batch; no join across files), then reads their current prices from the prices database and writes the batch in one transaction on the prices database. A quote whose series the source did not declare (and so has no `price_series` row) raises `Prices::Sources::ConfigurationError` before the batch is written: that is a defect of the source, and earlier batches stand.

| The quote | Current price | Written |
|---|---|---|
| the printing is unknown to the catalog | none | nothing; the printing is counted once in `unknown_printings` |
| equals the current price | one | nothing |
| differs from the current price | one | the current price updated (`cents`, `reported_on` and `changed_on` the run date) and a history row for the run date with the new cents |
| the printing and series have none | none | the current price inserted and a history row, the same |
| no quote, a trusted absence (decision 4) | one | the current price deleted and a history row for the run date with no cents |

A history row is written with an upsert on its primary key: if a row for the same printing, series and date exists (a second file of that date), the later cents replace it, so the key is never violated and a rerun is safe. A removal batch deletes the current prices and upserts their blank history rows **in one transaction**: a failure leaves both or neither, because a price deleted without its row would no longer be a candidate and the removal would be lost for good. Removals run after the whole file was read, in their own batches of `BATCH_SIZE` current prices, from a keyset walk over the source's current prices by printing id (reading the printings' language from the primary in slices, outside the transaction).

A price that was removed and returns is an `added` quote. `Malformed` records are counted and logged (`prices.refresh skipped malformed …`, the key and the error), as the catalog does.

### 7. One run at a time, a run left behind, batches, errors and the network

- **Overlap.** `Prices::RefreshJob` holds a queue concurrency lock per source key (`LOCK_FOR`, 6 hours, as the catalog's: a waiting refresh must never start while another's job may still be working), so a second job waits its turn. `PriceRefreshRun.start!` records a new run `skipped` (`already running`) while another run of the source is running and not left behind.
- **A run left behind.** A running run whose last progress (`updated_at`) is older than `STALL_AFTER` (15 minutes, the catalog's), or whose `job_id` is the starting job's own (the queue re-ran it after a restart), is closed `failed` with `interrupted` when the next run starts. Progress is a touch of the run row at every batch read (even one that writes nothing, as a typical day is mostly unchanged), at every slice of the removal walk, and, while downloading, at most every `HEARTBEAT_EVERY` (30 seconds) through the catalog source's optional `#progress=` hook, so a long download or walk never reads as stalled. This is the catalog refresh's rule without its queue reading. A waiting rate-limit retry holds no lock and its run is already failed; a job that starts meanwhile finds nothing running, and finds the file applied or not as it stands. That is accepted: the worst outcome is one extra request to the bulk-data index.
- **Batches.** `BATCH_SIZE` is 1,000 printings (a few thousand rows). A batch's transaction holds only writes to the prices database and reads of it; the primary's lookup, the file read and the download happen outside any transaction. The run row's progress write is outside the batch transaction.
- **Errors and their fates.** One table, one meaning each. No error is discarded: a failed job shows under Failed on `/admin/jobs`, where an admin can retry it, which is how an operator learns of a guard that fired before #367 shows the runs.

  | Error | Run | Job |
  |---|---|---|
  | `Catalog::Sources::TransientError`, `ActiveRecord::StatementTimeout` (which is what the SQLite adapter makes of `SQLite3::BusyException`) | `failed` | retried, `polynomially_longer`, 3 attempts, then failed |
  | `Catalog::Sources::RateLimitedError` | `failed` | rescheduled by `Catalog::RateLimitRetry` after the wait asked for, then by its rule failed |
  | `Catalog::Sources::IntegrityError` (the download's size: a file republished mid-download gives exactly this, and the retry asks the index again) | `failed` | retried like the transient errors, 3 attempts, then failed |
  | `Prices::Sources::IntegrityError` (a name with no date), `Catalog::Sources::ConfigurationError` (a bad language setting), `Prices::Sources::ConfigurationError` from an undeclared series (decision 6) | `failed` | failed, not retried |
  | `Prices::Sources::ConfigurationError` from `PriceSource.sync!`, or an unregistered key (decision 5, step 0) | none: no run can exist | failed, not retried |
  | `Zlib::Error` (a corrupt or cut-short file) | `failed`, no removal | failed, not retried |
  | a guard of decision 4 (items 2 and 5): `Prices::Refresh::GuardError` | `failed`, nothing removed | failed, not retried |
  | any other `StandardError` (`Catalog::Sources::Error` in general, a `KeyError` from the bulk index) | `failed` | failed, not retried |

  A persistent cause (a bad language code, a standing ceiling breach) leaves one Failed job a day: Solid Queue's hourly clearing removes only finished jobs, and discarding a failed job is the admin's, on `/admin/jobs`. That is a deliberate departure from `background-jobs.md`'s `discard_on` advice, whose example is a `DeserializationError`: the job's argument is a string, and a discarded job would hide a guard that fired before #367 shows the runs.

### 8. The job, the schedule and the files

`Prices::RefreshJob` (`app/jobs/prices/refresh_job.rb`, queue `sync`, argument: the source's key) calls `Prices::Refresh` (`app/models/prices/refresh.rb`), which owns the decisions above. The models `CurrentPrice`, `PriceChange` and `PriceRefreshRun` are added (spec 085 left them out) on composite primary keys; writes are bulk (`insert_all`, `upsert_all`, `delete_all` by key), which skips validations on purpose, as the rows come from a validated `Quote` (a header comment says so, as `Location.upsert_all` does). The job's schedule is one line in `config/recurring.yml`, production only like the catalog's: `refresh_prices`, `args: ["scryfall"]`, `queue: sync`, `at 11:30am every day` (the file seen on 2026-11-13 was published at 10:06 UTC, research 083; the host's time zone is the container's, UTC unless the operator sets one, and the run's date comes from the file whenever it runs). The backup advice ("never Monday 03:00 to 05:00") gains the daily window (ADR 0029, Cost).

Core files name no collectible, comments included: `spec/price_source_core_spec.rb` lists the new ones (its glob already covers `app/models/prices/**`; the three models and the job are added by name). The schedule line is the one place the source's key is written outside its own class and the initializer.

## User Stories

### Story 1: A file is applied once, and the date is the file's

**As** an operator **I want** the daily job to apply each day's file once **So that** the history doesn't grow when nothing changed

- [ ] **AC-1.1** Given a bulk file for 2026-11-13 and no earlier run When the job runs Then a run is `finished` with `run_on` 2026-11-13, the file's `source_version`, the language set and its `job_id`, and `started_at` and `finished_at` set.
- [ ] **AC-1.2** Given AC-1.1 has finished When the job runs again on the same file and languages Then the new run is `skipped` with `<version> already applied` and the earlier run's `run_on`, no row of `current_prices` or `price_changes` changes, and the file is not downloaded again.
- [ ] **AC-1.3** Given a finished run of `all_cards` with `en,ja` When the job runs with `en,de` Then the file is applied, because the language set differs.
- [ ] **AC-1.4** Given a finished run dated 2026-11-13 and a file dated 2026-11-12 When the job runs Then the run is `skipped` after the download with a reason naming the later date, and nothing else changes; Given a second file dated 2026-11-13 with another version Then it is applied; and Given a failed run that read a file dated 2026-11-13 and then a file dated 2026-11-12 Then the older one is skipped.
- [ ] **AC-1.5** Given no catalog entry of the type When the job runs Then the run is `skipped` with a reason and a nil `run_on`, the catalog's source is asked nothing, and no row of either price table is written.
- [ ] **AC-1.6** Given the clock is a different UTC day from the file's When the job runs Then every written row carries the file's date.
- [ ] **AC-1.7** Given the job is performed twice on one file When both have finished Then the rows of both price tables are the same as after the first (idempotency), and a run is recorded for each.
- [ ] **AC-1.8** Given each run When it starts Then `PriceSource.sync!` has been called for the source (its rows exist and are current) before the run row is opened and before any quote is written; and Given an unregistered key, or a source that fails verification When the job runs Then it fails with the error, and no run row is written.
- [ ] **AC-1.9** Given a run that ended before its file's date was known (already running, a transient error) When it is read Then its `run_on` is nil and the table accepts it.

### Story 2: Each quote is judged, and a change is recorded once

**As** the history **I want** a row only where a price changed **So that** it stays small

- [ ] **AC-2.1** Given a quote whose printing and series have no current price When it is applied Then a current price exists with those cents and the run date as `reported_on` and `changed_on`, one history row for the run date has those cents, and `added` is 1.
- [ ] **AC-2.2** Given a quote equal to the current price When it is applied Then no row of either table changes (the current price's dates stay), and `unchanged` is 1.
- [ ] **AC-2.3** Given a quote that differs When it is applied Then the current price has the new cents and the run date, one history row for the run date has the new cents, the earlier history rows are untouched, and `changed` is 1.
- [ ] **AC-2.4** Given a current price whose printing the file carries with no quote for that series, and a trusted file When it is applied Then the current price is gone, one history row for the run date has no cents, and `removed` is 1 (among at least ten candidate rows, decision 4's limit); and Given the price comes back in a later file Then it is an added quote with its own history row.
- [ ] **AC-2.5** Given a quote of a printing the catalog doesn't have When it is applied Then no row is written for it, `unknown_printings` counts the printing once however many series it has, and its quotes are in no other count.
- [ ] **AC-2.6** Given one printing with a quote in each of three series, one new, one equal and one changed When applied Then each is judged on its own series, and `quotes_seen` is 3 with `added`, `unchanged` and `changed` 1 each.
- [ ] **AC-2.7** Given a history row already exists for a printing, series and date, and a later file of that date differs When it is applied Then the row's cents are replaced and no second row exists.
- [ ] **AC-2.8** Given rows written by a run When they are read Then each is keyed by the catalog entry's id, and the example passes in the suite's two-database setup, where a query that joins or attaches the two files would fail.
- [ ] **AC-2.9** Given a current price whose printing is absent from the file altogether (not one card of it), and one whose entry is retired and unlisted When the run is trusted (among at least ten candidate rows) Then both are removed like AC-2.4's.
- [ ] **AC-2.10** Given a file with two quotes for one printing and series When it is applied Then the first is judged, the second is ignored, and `quotes_seen` counts one.
- [ ] **AC-2.11** Given a quote whose series the source didn't declare When it is reached Then `Prices::Sources::ConfigurationError` is raised before that batch is written, the run is `failed`, and earlier batches stand.
- [ ] **AC-2.12** Given a `Malformed` record When the file is read Then a log line names its key and error (`prices.refresh skipped malformed …`), and `malformed` counts it.

### Story 3: A bad file changes nothing it shouldn't

**As** an operator **I want** a truncated or unreadable file to leave history alone **So that** a bad day isn't recorded as a market crash

- [ ] **AC-3.1** Given a `Malformed` that names a series for a printing with a current price in that series, and no quote for it When the run finishes Then that price is not removed and no history row is written for it, the other series of the printing are judged as usual, and `malformed` and `removals_withheld` count it.
- [ ] **AC-3.2** Given a `Malformed` with a printing's key and no series When the run finishes Then none of that printing's prices is removed.
- [ ] **AC-3.3** Given a `Malformed` with no key When the run finishes Then no price is removed at all, quotes before and after it are applied, and `removals_withheld` counts the absent candidates.
- [ ] **AC-3.4** Given a gzip file cut short after some cards When the job runs Then the run is `failed` with the reader's error in `error`, no price is removed, the prices written before the cut stand, and the next run of a whole file of that date applies the rest and writes no row twice.
- [ ] **AC-3.5** Given an empty file, or one in which nothing is readable When the job runs Then the run is `failed` with `no valid quotes`, and no row of either price table is written; and Given a file whose quotes are all for printings the catalog doesn't have Then the run finishes with `quotes_seen` 0, `unknown_printings` counted and nothing removed or written.
- [ ] **AC-3.6** Given absent candidates above `MAX_REMOVED_SHARE` of all candidate rows When the run reaches its removals Then none is applied, the run is `failed` and `error` names how many of how many, `removals_withheld` counts them all, and the quotes' changes already written stand; and Given absent candidates exactly at the share Then they are removed (the comparison is exact, with a `Rational`).
- [ ] **AC-3.7** Given a current price whose printing is in a language the run didn't read, or that the primary doesn't have When the file lacks it Then it is not removed and is not counted as withheld.
- [ ] **AC-3.8** Given a failed run When the job runs again on the same file Then the file is read again (a failed run is not applied).
- [ ] **AC-3.9** Given a failure injected in a removal batch When it happens Then that batch's current prices and blank history rows are both still there or both gone, never one, and a later run removes what is left (among at least ten candidate rows).

### Story 4: One run at a time, in short batches

**As** the instance **I want** runs that never overlap and never hold the database long **So that** the app stays responsive and the history isn't written twice

- [ ] **AC-4.1** Given a run that is running with recent progress When another job starts Then its run is `skipped` with `already running`, and nothing is downloaded or written.
- [ ] **AC-4.2** Given a running run whose last progress is older than `STALL_AFTER`, or whose `job_id` is the starting job's When a job starts Then that run is closed `failed` with `interrupted` and the new run proceeds.
- [ ] **AC-4.3** Given `Prices::RefreshJob` When its concurrency limit is read Then it is one job per source key for `LOCK_FOR`, on queue `sync`.
- [ ] **AC-4.4** Given a file of five printings and `BATCH_SIZE` stubbed to 2 When it is applied, with a subscriber on `sql.active_record` that cuts the prices connection's statements into spans from `SAVEPOINT` to its release or rollback (the suite's own transaction is non-joinable, so every transaction, a batch's or a single run-row write, is a savepoint, and a depth count can't tell them apart) Then every write to `current_prices` and `price_changes` is inside a span; no span holds both such a write and a write to `price_refresh_runs` (the run row's progress is written outside the batch transactions); three spans hold data writes, each of at most 2 printings; and no statement on the primary's connection arrives while a prices span is open.
- [ ] **AC-4.5** Given the run at the catalog source's level (`MTG::Scryfall::Source` with stubbed requests, since the fake catalog source makes no HTTP call and would make the check vacuous) When it downloads and applies a file, with a `WebMock` `after_request` hook that records any request made while either connection's open transactions exceed the baseline Then the recorded list is empty and at least one request was seen.
- [ ] **AC-4.6** Given each error of decision 7's table When the job meets it Then the run ends `failed` with the error (none for the errors of step 0), and the job is retried, rescheduled or failed as the table says; and no error is discarded.
- [ ] **AC-4.7** Given a download in progress When the source reports progress Then the run row's `updated_at` is touched at most once per `HEARTBEAT_EVERY`, a batch read that writes nothing also touches it, and so does each slice of the removal walk.
- [ ] **AC-4.8** Given a partial download file older than `STALE_PARTIAL_AFTER` in the download directory and a fresh one When a download finishes Then the old one is deleted and the fresh one is kept; and Given a second `download` of the same version started from inside the first's stubbed stream (no threads: the example is deterministic) Then each writes its own partial file and the final file is the published size.

### Story 5: A schedule, run records and documents

**As** a maintainer **I want** the job scheduled and the records and documents current **So that** the next issues build on them

- [ ] **AC-5.1** Given `config/recurring.yml` When the production block is read Then `refresh_prices` runs `Prices::RefreshJob` with `scryfall` on queue `sync`, at a time of day other than the catalog refresh's, and the development block has none.
- [ ] **AC-5.2** Given the migration When the prices database is built from the migrations and from `db/prices_structure.sql` Then both have the columns of decision 2 and a nullable `run_on`, the status check, foreign key and index of `price_refresh_runs` survive, and `current_prices` and `price_changes` are still `WITHOUT ROWID` (`spec/prices_schema_spec.rb`); `spec/backup_guards_spec.rb` and `ruby script/upgrade/guard.rb` pass; and `bin/upgrade-smoke` passes in CI's image job (it is not a `bin/ci` step).
- [ ] **AC-5.3** Given a finished run When it is read Then its counts are those of the file, with `quotes_seen = unchanged + repriced + added`.
- [ ] **AC-5.4** Given the new core files When the guard reads them, comments included Then none names a collectible, source or marketplace.
- [ ] **AC-5.5** Given `bin/ci checks` When it runs Then new public code has comments, YARD builds, and RuboCop and Brakeman pass.
- [ ] **AC-5.6** Given a generated file of 110,000 cards with about 300,000 quotes, built under `tmp/` by the example, and the test databases When the job applies it as a first run, and again as a typical day (10 to 20 percent of prices changed) Then the example records both durations (`:timing`, no threshold; it is excluded unless `SCANNER_TIMING` is set, so it is run by hand and the numbers are recorded in `verification.md`).
- [ ] **AC-5.7** Given `prices.md`, `catalog-operations.md`, `README.md`'s backup advice, `docs/roadmap.md`, `docs/specs/README.md` and `CLAUDE.md` When read Then they state what the job does, with the source of each statement (verified by reading, recorded in `verification.md`).

## Functional Requirements

### FR-1: The refresh

**Must:** apply decisions 3 to 6 and 8; write the history only through the cases of decision 6; record the run (decision 2); verify and sync the source (`PriceSource.sync!`) at the start of every run.
**Must not:** write a price whose quote was a `Malformed`, remove one the file can't be trusted about, call the network inside a transaction, read the primary inside a prices transaction, join the two files, name a collectible in a core file, or touch the catalog's tables.

### FR-2: The job and its guard

**Must:** decisions 1, 5 and 7: one job per source at a time, a run record for every attempt, the stall rule, the errors' table.
Also: the catalog contract's comment (`app/models/catalog/sources.rb`) gains the line that `#download` must tolerate concurrent calls for one version (decision 1).
**Must not:** use `Catalog::Operation` or `Catalog::RefreshRun`, or change what the catalog refresh does (apart from the partial file's name and its pruning, decision 1).

### FR-3: The schema change

**Must:** add the changes of decision 2 with a migration of its own (never edit a released one), update `db/prices_structure.sql`, and keep both large tables `WITHOUT ROWID`.

## Non-Functional Requirements

### Performance

- The first run writes about 300,000 current prices and as many history rows (English only) in batches of 1,000 printings; a typical day writes the changes only. AC-5.6 records the durations: they are a measurement, not a gate, and #366 replaces them with the run's own numbers.
- Memory holds the set of series judged this run (for the absences) and the unknown printings' keys, not the file: one batch of quotes at a time otherwise. Peak memory has no portable cheap reading and is #366's.
- **A cost the price refresh adds to the catalog's:** an instance with languages beyond English downloads `all_cards` (408 MB) every day, where the catalog refresh downloaded it once a week.

### Security

- Prices are global data: no account, no `Current.account`, nothing in the export. The job reads a file its source downloaded and a key it was queued with; nothing user-supplied reaches a query (bind parameters throughout).

### Reliability

- The job is at-least-once safe: every batch commits whole and is idempotent on its keys, and removals are computed from the file read to the end.
- A killed run leaves its row `running`, which the next run closes (decision 7).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The bulk-data index lists no such file, or Scryfall times out | `TransientError`: the run fails, the job retries a few times, seconds apart (decision 7's table) |
| Scryfall answers 429 | The rate-limit module reschedules the job after the wait it asked for; the run is failed, the retry records its own |
| The download is the wrong size | The catalog source's `IntegrityError`; the run fails; the job fails and shows under Failed; the next day's run tries again |
| The file's name carries no date | `Prices::Sources::IntegrityError`; the run fails, nothing is written, the job fails |
| `COLLECTOR_MTG_LANGUAGES` has an unsupported code | `Catalog::Sources::ConfigurationError` from the catalog source; the run fails each day, the job fails and shows under Failed, naming the code |
| The gzip is cut short | The run fails; no removal; what was written stands (AC-3.4) |
| A card line is unreadable | Counted and logged; the readable lines apply; every removal is withheld |
| The ceiling is breached | The run fails with how many of how many; nothing is removed; the job fails and shows under Failed |
| The database is busy | The batch rolls back; the job retries; the next attempt finds the earlier batches written and judges them unchanged |
| The process is killed mid-run | The row stays `running` until the next run closes it as `interrupted` |
| Two jobs start together | The queue holds one back; if both start, the second is `skipped` |
| An operator removes a language | Prices of that language's printings are left alone, not removed |

## Open Questions

None are open. The maintainer ruled decisions 1 to 4 on 2026-11-13: (1) the file is shared and the lifecycle isn't, with a unique partial-download name; (2) the run's columns and the line with #366; (3) a price's freshness is the source's latest finished `run_on`, not a column, and earlier-dated files are skipped; (4) the removal conditions, a ceiling of 10 percent, and a failed run on breach. Decisions 5 to 8 and the changes review round 1 made to 1 to 4 (a nullable `run_on`, `job_id`, pruning, the older-file rule over failed runs, the errors' table) follow from the rulings and are Gate A's to confirm. The schedule's 11:30 is a guess from one day's publication time and is a one-line change.

**Supersession (decision 1):** this spec supersedes spec 002 FR-3's wording that a download goes through "a partial file": the partial file's name is unique per download, and partial files left behind are pruned. It also supersedes spec 081's column table for `price_refresh_runs` (`run_on` was `NOT NULL`, no `job_id`). It is recorded here, in `docs/specs/README.md` (this spec's row and the 002 and 081 rows' superseded-by cells), and in [`catalog-operations.md`](../../architecture/catalog-operations.md) and [`prices.md`](../../architecture/prices.md).

## Out of Scope (Future Considerations)

- The measurements (#366), the admin log with a view of the queue (#367), the history levels (#368), the display (#369), the cost documentation (#370).
- A manual start (button or rake task) and an operator override of a withheld removal.
- Following a merged printing (#371).
