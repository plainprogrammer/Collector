# Verification: spec 089, prices refresh once a day, and each change is recorded once (#365)

**Spec:** [`spec.md`](spec.md) (0.4.3) · **Plan:** [`plan.md`](plan.md)

## Evidence

Commands run in the worktree after the last code commit (`5c85705f`), on the test databases:

| Command | Result |
|---|---|
| `bin/ci checks` (AC-5.5) | `Continuous Integration passed in 28.64s`: Setup, Upgrade (released migrations unchanged), RuboCop (875 files, no offenses), YARD without warnings, the comment ratchet (`18 added or changed public objects, all with a comment`), Brakeman (0 warnings), bundler-audit (no vulnerabilities), importmap audit (no vulnerable packages) |
| `ruby script/upgrade/guard.rb` (AC-5.2) | `v0.3.0: its 34 migrations are unchanged` |
| `bin/rspec spec/price_source_core_spec.rb spec/prices_core_spec.rb spec/prices_schema_spec.rb spec/backup_guards_spec.rb spec/config/recurring_spec.rb` (AC-5.2, AC-5.4) | `23 examples, 0 failures` |
| `SCANNER_TIMING=1 bin/rspec spec/models/prices/refresh_timing_spec.rb` (AC-5.6) | see the timing below |

`bin/upgrade-smoke` (AC-5.2's last clause) needs a container engine and runs in CI's image job; it is not run here.

**Timing (AC-5.6)**, run on the development machine, once, alone: a generated file of 110,000 cards with 275,000 quotes, first run all added (275,000 added), then a typical day of 256,666 unchanged and 18,334 repriced. The example printed:

```
price refresh timing: {first_run: 18.4, typical_day: 7.4}
```

in seconds; the whole example took 36.55 s (it builds the file and the catalog entries too). A measurement with no threshold (the spec's wording); #366 replaces it with the run's own numbers.

## Acceptance criteria

| AC | Evidence |
|---|---|
| AC-1.1 | `spec/models/prices/refresh_spec.rb` "adds a price no one has, with a history row for the run's date, and finishes the run (AC-1.1, AC-2.1)"; `refresh_end_to_end_spec.rb` "downloads once, applies the file's quotes dated by its name, and makes no request inside a transaction (AC-4.5)" (run, `source_version`, counts) |
| AC-1.2 | `refresh_spec.rb` "skips a file already applied for the same version and languages, copying its date (AC-1.2; …)"; `refresh_end_to_end_spec.rb` "changes nothing when the same file is read again (AC-1.7)" proves the second run is `skipped`, the file is requested once and the rows are unchanged |
| AC-1.3 | `refresh_spec.rb` "applies a file of the same version when the language set differs (AC-1.3)" |
| AC-1.4 | `refresh_spec.rb` "skips a file older than the latest finished or failed run (AC-1.4)" and "skips a file older than a finished run, and applies another version of the finished run's own day (AC-1.4)" |
| AC-1.5 | `refresh_spec.rb` "skips with a reason and no date when the catalog has no printing of the type, asking the catalog's source nothing (AC-1.5)" |
| AC-1.6 | `refresh_spec.rb` "gives every written row the file's date, whatever the clock says (AC-1.6)" |
| AC-1.7 | `refresh_spec.rb` "writes the same rows when the job is performed twice on one file (AC-1.7)"; `refresh_end_to_end_spec.rb` "changes nothing when the same file is read again (AC-1.7)" |
| AC-1.8 | `refresh_spec.rb` "syncs the source before a run exists, so a source that fails verification fails the job with no run (AC-1.8)" and "syncs the source and its series first, so their rows exist when the run opens (AC-1.8)" |
| AC-1.9 | `refresh_spec.rb` "ends the run failed, with its error, when the source's file has no date, and nothing is written (AC-1.9)"; `spec/prices_schema_spec.rb` "accepts a run with no date and refuses an unknown status" (the table accepts a nil `run_on`) |
| AC-2.1 | `refresh_spec.rb` "adds a price no one has, with a history row for the run's date, and finishes the run (AC-1.1, AC-2.1)" |
| AC-2.2 | `refresh_spec.rb` "writes nothing for an unchanged price, and the current price's dates stay (AC-2.2)" |
| AC-2.3 | `refresh_spec.rb` "updates a changed price and adds one history row, leaving the earlier ones (AC-2.3)" (the count is `repriced` since 0.4.3) |
| AC-2.4 | `refresh_spec.rb` "removes a price the file leaves out and writes a blank history row for the run's date (AC-2.4)" and "treats a price that comes back as an added quote with its own history row (AC-2.4)" |
| AC-2.5 | `refresh_spec.rb` "skips a printing the catalog doesn't have, counting it once however many series it has (AC-2.5)" |
| AC-2.6 | `refresh_spec.rb` "judges each series of a printing on its own (AC-2.6)" |
| AC-2.7 | `refresh_spec.rb` "replaces a history row of the same day when a second file of that day differs (AC-2.7)"; `spec/models/price_change_spec.rb` "is keyed by printing, source, series and day, and an upsert on that key replaces the row" |
| AC-2.8 | `refresh_spec.rb` "keeps rows keyed by the entry's id, in the prices database (AC-2.8)"; the suite has both databases, so a join or an attach would fail every example of the file |
| AC-2.9 | `refresh_spec.rb` "removes a price of a printing absent from the file altogether, and of a retired entry (AC-2.9)" |
| AC-2.10 | `refresh_spec.rb` "judges the first of two quotes for one printing and series, ignoring the second (AC-2.10)" |
| AC-2.11 | `refresh_spec.rb` "raises, fails the run and keeps earlier batches when a quote's series was not declared (AC-2.11)" |
| AC-2.12 | `refresh_spec.rb` "logs a malformed record's key and error, and counts it (AC-2.12)" |
| AC-3.1 | `refresh_spec.rb` "does not remove a price whose quote was unreadable, and the printing's other series are judged as usual (AC-3.1)" |
| AC-3.2 | `refresh_spec.rb` "removes none of a printing's prices when its line could be read only as far as its key (AC-3.2)" |
| AC-3.3 | `refresh_spec.rb` "removes nothing at all when a line names no printing, applying the quotes around it (AC-3.3)" |
| AC-3.4 | `refresh_spec.rb` "fails the run, with the reader's error, when the file is cut short; earlier batches stand, nothing is removed, and a whole file of the day finishes …" (AC-3.4) |
| AC-3.5 | `refresh_spec.rb` "fails the run, 'no valid quotes', and writes nothing when the file yields no quote (AC-3.5)" and "finishes a file whose quotes are all for printings the catalog lacks, counting them and writing or removing nothing (AC-3.5)" |
| AC-3.6 | `refresh_spec.rb` "refuses every removal and fails the run when absences exceed the share, counting them as withheld (AC-3.6)" and "removes absences exactly at the share (AC-3.6)" |
| AC-3.7 | `refresh_spec.rb` "leaves a price whose printing is in a language the run did not read, or the primary lacks, and does not count it (AC-3.7)" |
| AC-3.8 | `refresh_spec.rb` "reads a failed file again on the next run (AC-3.8)" |
| AC-3.9 | `refresh_spec.rb` "leaves both or neither of a removal batch's current price and blank history row when the batch fails (AC-3.9)" |
| AC-4.1 | `spec/models/price_refresh_run_spec.rb` ".start!" "records a skipped run, 'already running', while another run has recent progress (AC-4.1)"; `refresh_spec.rb` "records a skipped run, 'already running', for a run with recent progress, and writes nothing (AC-4.1)" |
| AC-4.2 | `price_refresh_run_spec.rb` "closes a run with no progress for STALL_AFTER as interrupted and goes ahead (AC-4.2)" and "closes a running run that carries the starting job's own id … (AC-4.2)"; `refresh_spec.rb` "closes a run left behind as interrupted and goes ahead (AC-4.2)" |
| AC-4.3 | `spec/jobs/prices/refresh_job_spec.rb` "allows one refresh per source key at a time, on the sync queue (AC-4.3)" |
| AC-4.4 | `refresh_spec.rb` describe "transactions (AC-4.4)": "writes in batches of BATCH_SIZE printings inside savepoint spans, the run row in spans of its own, and reads the primary outside them" (savepoint spans, spec 0.4.2; deviation c below) |
| AC-4.5 | `refresh_end_to_end_spec.rb` "downloads once, applies the file's quotes dated by its name, and makes no request inside a transaction (AC-4.5)" (`MTG::Scryfall::Source` over stubbed requests; the `after_request` hook compares open transactions to a baseline, deviation e below) |
| AC-4.6 | `refresh_job_spec.rb` the per-error examples "retries on …" and "fails, without a retry or a discard, on …" (AC-4.6), and "fails on the third attempt of a transient error, not retried again (AC-4.6)" |
| AC-4.7 | `refresh_spec.rb` "touches the run while the download reports progress, at most once per HEARTBEAT_EVERY (AC-4.7)", "touches the run after every batch, even one that writes nothing (AC-4.7)" and "touches the run for each slice of the removal walk (AC-4.7)"; `price_refresh_run_spec.rb` "#progress! and #heartbeat" |
| AC-4.8 | `spec/models/mtg/scryfall/source_spec.rb` "deletes a partial file left by a killed download once it is a day old, and keeps a fresh one (spec 089 AC-4.8)" and "writes each download to a partial file of its own, so a second download of the version, started inside the first, is harmless (spec 089 AC-4.8)" |
| AC-5.1 | `spec/config/recurring_spec.rb` "refreshes prices daily in production, at another time than the catalog's refresh, and not in development (spec 089 AC-5.1)" |
| AC-5.2 | `spec/prices_schema_spec.rb` context "with spec 089's migration (AC-5.2, AC-1.9)" (a database migrated as main has it keeps its rows, check, key and index; the migration goes down without losing a row) and the file's examples for `WITHOUT ROWID` on both builds; `spec/backup_guards_spec.rb`; `ruby script/upgrade/guard.rb`; commands and output in Evidence; `bin/upgrade-smoke` is CI's image job |
| AC-5.3 | `refresh_spec.rb` "judges each series of a printing on its own (AC-2.6)" (`quotes_seen` 3 = 1 + 1 + 1) and `refresh_end_to_end_spec.rb` (the finished run's counts) |
| AC-5.4 | `spec/price_source_core_spec.rb` "names no collectible, source or marketplace in the files it adds" (its list names `current_price.rb`, `price_change.rb`, `price_refresh_run.rb`, `app/models/prices/**` and `app/jobs/prices/**`) and "has a matcher that flags a name, so the guard can fail"; `spec/prices_core_spec.rb` |
| AC-5.5 | Evidence: `bin/ci checks` passed (YARD without warnings, the comment ratchet with 18 objects, RuboCop, Brakeman) |
| AC-5.6 | Evidence: `spec/models/prices/refresh_timing_spec.rb` "applies a first run and then a typical day" (excluded without `SCANNER_TIMING`); the line above |
| AC-5.7 | Verified by reading, see below |

## Document criteria (AC-5.7, verified by reading)

| File | What it gained or holds | Source |
|---|---|---|
| `README.md` ("Back up", "When to back up") | the sentence now also says to keep backups clear of 11:30 in the container's time zone, when the daily price refresh writes the prices database, which a backup's read transaction holds back like the catalog refresh's window | spec 089 decision 8; ADR 0029, Cost |
| `docs/roadmap.md` (prices lane) | the #365 row ends "Done: [spec 089](specs/089-daily-price-refresh/spec.md)", in the form of #364's row | spec 089; issue #365 |
| `CLAUDE.md` (status paragraph) | the prices database now has "a daily refresh that records each price change once (`Prices::Refresh`, `Prices::RefreshJob`, `PriceRefreshRun`, `CurrentPrice`, `PriceChange`; spec 089, #365) and no reader yet (#366 to #369 are still to come)" | spec 089; issue #365 |
| `docs/specs/README.md` | the spec's row exists (status Approved, plan present); left for `distill-feature` (plan T9.4) | plan T9.4 |
| `docs/architecture/prices.md`, `docs/architecture/catalog-operations.md` | **Not yet written**: `distill-feature` writes them after the implementation review, from the list in plan T9.6; AC-5.7 stays open for these two until then | plan T9.6; `.claude/rules/documentation.md` |

## Deviations of the run so far

- (a) The count column `changed` became `repriced`, by a second migration, because Active Record reserves the attribute name `changed` and `PriceRefreshRun` can't be built with it (spec 0.4.3; commits `e4f4e5b0`, `d8f3add3`).
- (b) `MTG::Scryfall::Source#fetch` deletes its own partial file when a download fails, and `#prune` tolerates a file vanishing under it (a concurrent download's cleanup).
- (c) AC-4.4 measures savepoint spans, not transaction depth, because the suite's non-joinable transaction makes every write a savepoint (spec 0.4.2).
- (d) The pending unreadable records are bounded by the batch size: an automated security review found the pending set in `queue_malformed` unbounded; fixed in commit `3e8a6615`.
- (e) T8.1's check that the primary is not read inside a prices transaction compares the prices connection's open transactions to a baseline, because Rails opens a savepoint lazily.

## Implementation review
