# Feature 024: A Second Refresh or Build Waits Out Another's Rate Limit

**Status:** Draft, for the maintainer's approval and rulings (decisions 1 and 2)
**Version:** 1.0.0
**Created:** 2026-10-14
**Last Updated:** 2026-10-14
**Branch:** `024-refresh-rate-limit-wait`
**Issue:** [#78](https://github.com/plainprogrammer/Collector/issues/78)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-14 | Written from issue #78 |

---

## Problem Statement

When the source rate limits a catalog refresh, `Catalog::RateLimitRetry` (PR #76) schedules the job to run again no sooner than the source asked: 45 seconds at least, an hour at most. While that retry waits, the job holds no concurrency lock (`Catalog::RefreshJob`'s `limits_concurrency` lock is given back when the job ends, and the retry is a new queue row that only asks for the lock once it is due), and the refresh's run is already closed as failed. So a second `Catalog::RefreshJob` for the same type, queued by the weekly schedule (`config/recurring.yml`) or by `bin/rails "catalog:refresh[mtg]"`, runs at once: `Catalog::RefreshRun.start!` finds no running run, and the refresh asks the source inside the window the source asked us to stay out of. Scryfall's rate-limits page says continuing after a 429 may lead to a ban. In the review's probe the second job was itself rate limited, and two retry chains then ran side by side.

`MTG::Art::BuildJob` has the same gap: a rate-limited build's run is closed as failed, its retry waits in the queue, and a build queued meanwhile (by a refresh that applies, `MTG::Art.after_refresh`) passes `MTG::ArtBuild.start!` and starts fetching images at once.

Spec 002 and `app/jobs/catalog/rate_limit_retry.rb` say today that "no sooner than asked" holds for the waiting job only.

> **Terms.**
> - A *waiting retry* is an unfinished job of the same operation, other than the one starting, that the queue holds for a later time (Solid Queue's scheduled execution): a retry backing off. For a refresh, only the jobs for the same catalog type count (`Catalog::Operation::Queue` with the type as first argument); the art build has one queue for all.
> - The *starting job* is the job whose `Catalog::Refresh#call` or `MTG::Art::Build#call` is running the check.

## Goals

- A refresh that starts while another refresh for its type has a waiting retry asks the source nothing, and leaves the work to that retry.
- The same holds for an art build that starts while another build has a waiting retry.
- The admin catalog page keeps showing the waiting refresh or build as it does today ("Queued to retry. The last build failed: …", "Retrying at").

## Non-Goals

- [#77](https://github.com/plainprogrammer/Collector/issues/77): starting or cancelling work while a retry waits.
- [#86](https://github.com/plainprogrammer/Collector/issues/86): how rate-limit retries are counted.
- [#84](https://github.com/plainprogrammer/Collector/issues/84): the wording of failure messages on `/admin/catalog`.
- A refresh while an *art build* waits, or the other way round. The refresh asks `api.scryfall.com`; the build fetches from `cards.scryfall.io` (`MTG::Art::Build::IMAGE_HOSTS`), which Scryfall says has no rate limits. Core code can't tell whether two operations share a source's limit, and nothing so far needs it to.
- Holding Solid Queue's concurrency lock across a retry's wait. The lock is Solid Queue's and its release on a job's end isn't configurable.

## Decisions

### 1. Skip, not defer (for the maintainer's ruling; recommended)

The starting job ends at once, recording a run (refresh) or build (art) that is *skipped*, the way a second refresh or build already ends when another is running. The waiting retry does the work when it is due.

The alternative, *defer*, would reschedule the starting job to run after the waiting retry is due. It keeps two jobs for one piece of work: once the waiting retry has run, the deferred one would refresh again (a manual or applied-version refresh applies again) or be skipped as already applied, and if the retry is rate limited again the deferred job may come due inside the new window. Skip has none of this, needs no new scheduling and matches how a second refresh is already treated while one runs.

What skip gives up: if the waiting retry later fails for good (asked for more than an hour, or turned away a fourth time), the skipped job's work isn't done until the next weekly refresh or an admin's "Refresh now", which the page offers again once nothing is in flight.

### 2. A manual refresh is treated as the scheduled one is (for the maintainer's ruling; recommended)

Today the only manual paths that can queue a second refresh while a retry waits are `bin/rails "catalog:refresh[mtg]"` (trigger `manual`) and `Catalog::RefreshJob.perform_later` in a console: "Refresh now" on `/admin/catalog` is already refused while a job is in flight, and a waiting retry is in flight. The recommendation is that a manual refresh is skipped just as a scheduled one is. Scryfall's rule doesn't care who asked, and a manual run that wants to go ahead without waiting is #77's question ("run the scheduled job now", or discard it). The art build has no trigger; every build is treated alike.

### 3. Any waiting retry counts, not only a rate-limit one

The starting job doesn't ask why the other job waits. A refresh job also waits a few seconds when retrying a transient error (`retry_on … wait: :polynomially_longer`), and the art build when retrying a busy database; that job will do the same work when it comes back, so skipping is right there too. Telling the reasons apart would mean reading Active Job's serialized `exception_executions` from Solid Queue's row, whose count stays set once a job has been rate limited, so it can't tell a later transient wait from a rate-limit one anyway.

### 4. The check is part of the start guard, and the skip's message is its own

The queue is already read before the runs, by `Catalog::Refresh#call` and by `MTG::ArtBuild.start!` (spec 015, issues #60 and #73). The check uses that same reading and is made inside the start guard's transaction, after left-behind runs are closed: so a starting job never asks the source, never runs the source's `after_refresh` hook, and never queues an art build.

The skipped refresh run's message is `waiting for another job's retry`, a new constant beside `ALREADY_RUNNING`. Like "already running", such a run isn't "the" run the catalog page shows (`Catalog::RefreshRun.attempted`): the page goes on showing the rate-limited run and "Queued to retry". A skipped build already never shows (`MTG::ArtBuild.latest`). The build's message is the same text. Both show in `catalog:status`, as skips do today.

### 5. The starting job's own retry doesn't count

A retry that comes due runs with its job's Active Job id (`retry_job` keeps it), and a running job isn't held for later, so it wouldn't find itself. The check excludes the starting job's id all the same, so that no reading of the queue (a row not yet moved from scheduled to claimed in a test, or a duplicate row with one id) can make a job skip itself.

## User Stories

### Story 1: A second refresh doesn't ask the source while another's retry waits

**As a** self-hoster
**I want** a refresh that starts during another refresh's rate-limit wait to leave the source alone
**So that** my instance doesn't keep asking Scryfall inside the window it asked us to stay out of, and risk a ban

- [ ] **AC-1.1** Given a refresh job for `mtg` whose retry the queue holds for a later time When a second `Catalog::RefreshJob` for `mtg` runs Then it makes no request to the source, and its run is recorded as skipped with the message `waiting for another job's retry` (the issue's probe; fails before the change)
- [ ] **AC-1.2** Given the same When the second job is `manual` or `scheduled` Then both are skipped (decision 2, as ruled)
- [ ] **AC-1.3** Given the same Then the skipped run doesn't run the source's `after_refresh` hook, so no art build is queued
- [ ] **AC-1.4** Given a waiting retry for another type only When a refresh for `mtg` runs Then it goes ahead
- [ ] **AC-1.5** Given the starting job's own id is the only job held for later (a job queued twice with one id) Then the refresh goes ahead
- [ ] **AC-1.6** Given a waiting retry and the skipped run When `/admin/catalog`'s refresh panel is rendered Then it shows the rate-limited run and "Queued to retry", as without the skip (the skipped run isn't "the" run)
- [ ] **AC-1.7** Given an earlier refresh still marked running that is left behind (stalled, or its job failed or gone, spec 015) and a waiting retry When a refresh starts Then the left-behind run is closed as interrupted, and the starting one is skipped

### Story 2: A second art build doesn't fetch while another's retry waits

- [ ] **AC-2.1** Given an art build job whose retry the queue holds for a later time When a second `MTG::Art::BuildJob` runs Then it fetches no image, and its build is recorded as skipped with the message `waiting for another job's retry` (fails before the change)
- [ ] **AC-2.2** Given the starting build job's own id is the only one held for later Then the build goes ahead
- [ ] **AC-2.3** Given the skipped build When the art index panel is rendered Then it shows the waiting build's state ("Queued to retry. The last build failed: …") as without the skip

### Story 3: The documents say so

- [ ] **AC-3.1** `app/jobs/catalog/rate_limit_retry.rb`'s header no longer says that nothing stops another job of its class asking the source meanwhile; it names where that is stopped (verified by reading)
- [ ] **AC-3.2** Spec 002's rate-limit requirement no longer says the rule holds for the waiting job only (verified by reading; spec 002 gets a changelog line)
- [ ] **AC-3.3** CLAUDE.md's "Admin catalog and jobs" paragraph says a refresh or build that starts while another's retry waits is skipped; the roadmap marks #78 done when the pull request merges (verified by reading)

## Functional Requirements

- **FR-1** `Catalog::Operation::Queue` answers whether any in-flight job other than a given Active Job id is held for a later time. Core code; names no collectible.
- **FR-2** `Catalog::RefreshRun.start!` takes that answer and, after closing left-behind runs, records the new run as skipped with `WAITING_FOR_RETRY` when it is true and no run is running (a running one still gives "already running"). `Catalog::Refresh#call` passes it from the queue it already reads; its change is the one argument.
- **FR-3** `Catalog::RefreshRun.attempted` leaves out runs skipped with either message.
- **FR-4** `MTG::ArtBuild.start!` makes the same check with the queue it reads and records the build as skipped with the same message.
- **FR-5** `Catalog::RefreshJob`, `Catalog::RateLimitRetry` and `MTG::Art::BuildJob` keep their retry rules unchanged.

## Non-Functional Requirements

- **Data.** No migration, no new column, no stored data; the export format is untouched. A skipped run or build is a row as skips are today.
- **Core boundary.** `app/models/catalog/` and `app/jobs/catalog/` name no collectible (`spec/admin_catalog_core_spec.rb`).
- **Queue reads.** Solid Queue's own tables, through `Catalog::Operation::Queue`, read once per start, before the runs (ADR 0014).
- **Testability.** Examples tagged `:solid_queue` queue the waiting retry with `queue_job(…, wait:)`; requests to the source are stubbed with WebMock, so "asks the source nothing" is an unmade request.

## Interactions for the maintainer

- **#77.** If #77 lets an admin start fresh work while a retry waits, that fresh job is skipped by this rule unless #77 first discards the waiting retry or runs it now. "Run the waiting job now" works with this rule unchanged: the job that runs is the waiting one.
- **#86.** None: the count of retries is untouched. A skipped job counts no retry.
- **#84.** It changes the failure message lines in `refresh.rb` and `mtg/art/build.rb`; this change touches neither line. Both branches add to `Catalog::RefreshRun` only if #84 does; a textual conflict there is trivial.

## Open Questions

None beyond decisions 1 and 2.

## Out of Scope

Retry counting, cancelling or running a waiting job, the admin page's wording, Solid Queue's concurrency settings, and a refresh against a waiting build (Non-Goals).
