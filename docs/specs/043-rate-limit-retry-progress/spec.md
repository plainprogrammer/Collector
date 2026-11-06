# Feature 043: Rate-Limit Retries Count Only Without Progress

**Status:** Approved on 2026-11-06 by the coordinator under the maintainer's delegation, with the maintainer's ruling on decision 1
**Version:** 1.0.0
**Created:** 2026-11-06
**Last Updated:** 2026-11-06
**Branch:** `043-rate-limit-retry-progress`
**Issue:** [#86](https://github.com/plainprogrammer/Collector/issues/86)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-06 | Written from issue #86, drafted around option A (count only rate limits with no progress since the last); ruling pending |
| 0.2.0 | 2026-11-06 | Maintainer ruling on decision 1: option A |
| 0.3.0 | 2026-11-06 | Spec review round 1 (Fable, APPROVE WITH CHANGES, 2 major, 7 minor): a refresh's download is not progress (the source contract can't tell a fresh download from a reused one, and the file is kept anyway), so a refresh makes progress only by writing catalog rows, which the one source can't do before a rate limit today; the build's progress is an image fetched and kept, or a batch of fingerprints stored; an admin's retry starts the count again; an attempt may open no run; the count's key is kept; the index's reverse entries; the area doc's two mentions of #86 |
| 0.4.0 | 2026-11-06 | Spec review round 2 (Fable, APPROVE WITH CHANGES, 8 minor): AC-2.1 says a kept image; the count's kept value defined; FR-2 says "would exceed"; notes for the plan in decision 4; AC order; the area doc's heading named exactly |
| 1.0.0 | 2026-11-06 | Approved |

---

## Problem Statement

When a source rate limits a catalog job, `Catalog::RateLimitRetry` schedules the job to run again no sooner than the source asked (spec 002 FR-4; spec 011 AC-3.6; #74, #81). It allows `MAX_RETRIES` (3) such retries, counted in the job's own retry record over its whole life. The count never starts again, however much work the job did between two rate limits, so the fourth rate limit fails the job.

- An art index build runs for hours under one job (`MTG::Art::BuildJob`). Four rate limits spread across it, each waited out and followed by thousands of fetched images, fail the job on the fourth. Since #81 every 429 without a usable `Retry-After` costs a retry, where it used to cost about 3 seconds inside the call.
- The failure is mild: fetched images stay cached, the job shows under Failed, and "Build art index" or the next refresh carries on from where it stopped. But the build stops, with no automatic resume, for a reason that isn't a real fault.
- The same bound applies to `Catalog::RefreshJob`, where it matters less: a refresh makes few requests.

The bound is there to stop a job that keeps being turned away. It also stops a job that is getting its work done between rate limits.

### Does the image host ever rate limit?

The issue asks this first. From Scryfall's documentation (`https://scryfall.com/docs/api/rate-limits`, read 2026-11-06) and the code:

- The rate limits are those of the API host, `api.scryfall.com`: 10 requests a second for the methods the app uses, 2 a second for some search methods. "The direct file origins located at `*.scryfall.io` do not have rate limits." A 429 limits access for 30 seconds; continuing to overload the API may lead to a ban.
- The art build fetches images only from `cards.scryfall.io` (`MTG::Art::Build::IMAGE_HOSTS`), one of those origins. By the documentation a build is never rate limited. No 429 from it has been observed. The client still treats a 429 from it as one from the API (a host behind a content network can answer 429 without its documentation saying so), and this spec keeps that.
- A refresh asks the API host twice per run: `/bulk-data` (before the download) and `/sets` (after it, one page today), with at least 100 ms between requests (`MTG::Scryfall::Client::MIN_INTERVAL`). The bulk file itself comes from `data.scryfall.io`, unlimited. A refresh is rate limited only when something else on the same address is overloading the API, or when Scryfall's limits change.

So the issue's main case, a long build turned away four times, needs a 429 Scryfall says won't come. The rule is still wrong as stated (it counts work as failure), and it is cheap to make right; the maintainer ruled to change it (decision 1).

> **Terms.**
> - A *rate limit* is a `Catalog::Sources::RateLimitedError` reaching the job, which `Catalog::RateLimitRetry` handles.
> - An *attempt* is one run of the job's `perform`: the first, or a retry (a rate-limit retry, a retry of a transient error, an admin's retry). An attempt that gets far enough opens its own run record (a `Catalog::RefreshRun` or an `MTG::ArtBuild`); one that fails while starting, or a build that returns early (art matching off, no applied catalog), opens none, and has made no progress.
> - *Progress* is durable new work the attempt did before the rate limit ended it, as its operation judges it (decision 3).
> - The *count* is the number of rate limits in a row with no progress between them, the one that is being handled included. The job keeps it after each handling; an AC's "count is N" is that kept value before the next rate limit.

## Goals

- A rate limit that ends an attempt that made progress starts the count again: the job is retried and its count is 1.
- A job is failed for rate limits only on the fourth rate limit in a row with no progress between them, as today on its fourth rate limit.
- A job can't be kept alive for ever by rate limits: each new start of the count needs new durable work, and the work is finite.
- The core rule names no collectible; each operation answers whether its attempt made progress.

## Non-Goals

- **#77**: starting a refresh or build, or cancelling the wait, while a rate-limited job waits. Unchanged.
- **#176** (the art index's settings drift). Unchanged.
- The waits: `SHORTEST_WAIT` (45 seconds), `LONGEST_WAIT` (1 hour) and the client's back-off are unchanged. A wait asked for of more than an hour still fails the job at once, progress or not.
- `MAX_RETRIES` keeps its value, 3.
- The client's handling of a 429 (spec 011 AC-3.4; #81), and which hosts are fetched from.
- A count per period of time (decision 1, option B).
- Any change to the admin pages: a waiting retry still shows as "Queued to retry" with "Retrying at" (spec 024).
- Calling Scryfall from the suite. The answer above is read from its documentation and the code.

## Decisions

### 1. Count only rate limits with no progress since the last one (ruled)

**Ruling (maintainer, 2026-11-06): A.** Only rate limits with no progress since the last one count; each operation answers whether its attempt did new durable work, and the core names no collectible. The options put:

- **A (recommended; ruled).** The count starts again whenever the attempt a rate limit ended made progress. The job fails on the fourth rate limit in a row with no progress between them.
- **B.** Count per period: at most 3 rate-limit retries within a rolling window. No progress question, but the window's length is a guess: too short and a job turned away every 45 seconds never fails; too long and a slow job with work between rate limits still does.
- **C.** No code change: record Scryfall's answer (above) in the area doc and close #86, since under Scryfall's stated limits the long build is never rate limited.

A is what the issue's outcome names first, it fits what the bound is for, and it costs one question per operation. It also covers a host that answers 429 without its documentation saying so.

### 2. Progress is judged on the attempt the rate limit ended

The question is asked of the attempt that was turned away, not of every attempt since the last rate limit. An attempt between two rate limits that ended for another reason (a busy database, retried by `retry_on`) is not looked at. Its work makes the next rate-limited attempt's own progress no larger.

So in the rare order "rate limit, busy-database retry that did work, rate limit with no new work", the second rate limit counts 2, not 1: the job fails sooner than a perfect rule would, which is today's behaviour, never later. This keeps the count in one place (the job's retry record) and keeps the question to the run in hand. It is accepted as a limit.

An admin's retry from `/admin/jobs` already starts the count again, as today: Solid Queue's retry of a failed job clears the job's retry record (`exception_executions`), where the count lives (spec 015 AC-6.5 counts attempts the same way).

### 3. What counts as progress, per operation

Progress must be durable new work, so that an attempt that redoes the same thing never counts and the number of fresh starts is bounded by the work left:

| Operation | Progress (in the attempt) | Not progress |
|---|---|---|
| Art build (`MTG::Art::Build`) | An image fetched into the cache and kept there, or a batch of fingerprints stored (fingerprints are stored a batch of `BATCH` at a time, so those computed in the batch a rate limit ends are not stored, though their images stay cached) | Images found already cached; the fingerprint count recorded at the start (artworks fingerprinted before); an image that failed, or that was fetched but couldn't be decoded and was removed from the cache |
| Catalog refresh (`Catalog::Refresh`) | A catalog row written (set, identity or entry inserted, updated, restored or retired) | Records seen (`Catalog::Refresh::Progress#seen`, the progress the page shows); the download, fresh or reused; a skipped run |

**The download is not a refresh's progress.** The source contract (`Catalog::Sources#download`) returns the verified file's path whether it fetched it or found it already there, and reports progress the same way for both, so the core can't tell them apart without a change to the contract. Nor does it need to: the file is kept and the retry uses it again, so counting it would buy one extra fresh start and no work saved. Records seen are not progress either, though the page's progress counts them: a retried refresh reads the same file again and sees the same records.

**Where a refresh can be rate limited today.** With the one source, a rate-limit error comes only from the API host: `/bulk-data` (before anything is written) and `/sets` (all pages are read before any set is written). The bulk download goes to an unlimited host, and a failed download is a transient error, not a rate limit; nothing is asked of the source after the sync. So with Scryfall a refresh is never rate limited after writing a row, and its count behaves as today. The rule is still stated and tested for a source that can be rate limited after writing (a test source raising its rate-limit error from its entries after a batch is written), so the core's answer is right for the next source.

An operation that doesn't answer the question (a job class that includes the rule and says nothing about progress) gets today's rule: no progress, every rate limit counts.

### 4. Where the question lives

`Catalog::RateLimitRetry` stays core code: it asks the job whether its attempt made progress and names no collectible, no host and no table. Each job that includes it answers for its own operation; the refresh's answer is core (`Catalog::Refresh`), the build's is MTG's (`MTG::Art::Build`). The plan chooses the exact shape. Notes for the plan, from the spec review:

- The refresh's answer can't come from its run's counts alone: they tally entries, and sets and identities written count too.
- The answer must be the attempt's own: a job instance can run `perform` more than once (the job specs reuse one), so nothing kept from an earlier attempt may answer for a later one.
- A refresh rate limited after writing a batch needs `BATCH_SIZE` changed entries from the test source, or the batch size made small in the example; the plan picks one.

## Users and Context

- **Operators** (self-hosters, admins): a long first art build, or a refresh, carries on by itself after scattered rate limits instead of stopping under Failed.
- **Scryfall**: unchanged load. Every retry still waits what the host asked, 45 seconds at least; a job turned away again and again without progress still stops after 3 retries.

## User Stories

### Story 1: A job doing work between rate limits carries on

As an operator, I want a build or refresh that is rate limited now and then, but gets work done in between, to carry on by itself, so that a rate limit that isn't a fault doesn't stop it.

**Acceptance criteria:**

- [ ] **AC-1.1** Given a job that includes `Catalog::RateLimitRetry`, whose count is 3, When it is rate limited again and its attempt made progress Then it is retried after the wait (as today: the wait asked, 45 seconds at least) and its count is 1.
- [ ] **AC-1.2** Given a job whose count is 3, When it is rate limited again and its attempt made no progress Then the job fails with the rate-limit error, as today.
- [ ] **AC-1.3** Given a job whose count is 0, 1 or 2, When it is rate limited and its attempt made no progress Then it is retried after the wait and its count is one more.
- [ ] **AC-1.4** Given a job, When it is rate limited with a wait asked of more than an hour, whether or not its attempt made progress Then the job fails with the rate-limit error and is not retried, as today.
- [ ] **AC-1.5** Given a job, When it is rate limited eight times, each attempt making progress Then it is retried each time and never fails for rate limits.
- [ ] **AC-1.6** Given a job class that includes `Catalog::RateLimitRetry` and says nothing about progress, When it is rate limited a fourth time Then it fails, as today.

### Story 2: The art build says whether its attempt made progress

As an operator, I want a build that fetched images before a rate limit to count as having made progress, so that the bound only stops a build that gets nowhere.

**Acceptance criteria:**

- [ ] **AC-2.1** Given an art build that fetches at least one image that is kept (it decodes) and is then rate limited, When the job handles the rate limit Then the attempt counts as having made progress.
- [ ] **AC-2.2** Given an art build whose images to fetch are all uncached, When its first image request is rate limited Then the attempt counts as having made no progress.
- [ ] **AC-2.3** Given an art build that stores at least one batch of fingerprints for images already cached, fetches none, and is then rate limited, When the job handles it Then the attempt counts as having made progress.
- [ ] **AC-2.4** Given an art build skipped at start (`already running` or `waiting for another job's retry`), When it ends Then it is never rate limited and nothing about the count changes.
- [ ] **AC-2.5** Given an art build job rate limited four times, the first, second and third attempts each fetching images and the fourth fetching none, When the fourth rate limit is handled Then the job is retried (its count goes 1, 1, 1, 2), not failed. (The issue's scenario.)
- [ ] **AC-2.6** Given an art build whose only fetched image couldn't be decoded (removed from the cache) before a rate limit, and no batch stored, When the job handles it Then the attempt counts as having made no progress.

### Story 3: The refresh says whether its attempt made progress

As an operator, I want a refresh to count as having made progress only when it wrote something new, so that a refresh that redoes the same work isn't kept alive.

**Acceptance criteria:**

- [ ] **AC-3.1** Given a refresh whose `/bulk-data` request is rate limited, When the job handles it Then the attempt counts as having made no progress.
- [ ] **AC-3.2** Given a refresh that downloads a new bulk file and is then rate limited on `/sets`, When the job handles it Then the attempt counts as having made no progress (decision 3).
- [ ] **AC-3.3** Given a refresh whose source writes at least one catalog row and is then rate limited (a test source raising the rate-limit error from its entries after a batch is written), When the job handles it Then the attempt counts as having made progress.
- [ ] **AC-3.4** Given a refresh job whose count is 3, When its next attempt writes catalog rows and is then rate limited Then the job is retried with count 1; three more rate limits with no rows written take it to 2, 3, and then fail it.

### Story 4: The rule stays core

- [ ] **AC-4.1** Given `Catalog::RateLimitRetry`'s source, When read Then it names no collectible type, source, host, MTG constant or catalog table (checked by a spec in the manner of `spec/footer_core_spec.rb`).

### Story 5: The documents say so

- [ ] **AC-5.1** Given `docs/architecture/catalog-operations.md`, When read Then "A rate-limited job" step 2 and the `MAX_RETRIES` constant row state the count of rate limits with no progress between them and what each operation counts as progress, with this spec as source; #86 leaves the "Accepted limits and open issues" list and moves from the open issues to the closed ones in Sources; the `IMAGE_HOSTS` row (or "What the source does for a refresh") states that Scryfall's documentation gives the image origins no rate limits. (Verified by reading, recorded in `verification.md`.)
- [ ] **AC-5.2** Given the comments of `Catalog::RateLimitRetry` and `MTG::Art::BuildJob`, When read Then they state the new count and no longer say a job fails when "turned away a fourth time" over its life. (Verified by reading.)
- [ ] **AC-5.3** Given `docs/specs/README.md`, When read Then row 043 names what it supersedes and rows 002, 011 and 024 name 043 among what supersedes them. (Verified by reading.)

## Functional Requirements

- **FR-1** On a rate limit, `Catalog::RateLimitRetry` must fail the job when the wait asked exceeds `LONGEST_WAIT`, regardless of progress (unchanged).
- **FR-2** Otherwise it must ask the job whether the attempt made progress. With progress, the count becomes 1 and the job is retried. Without, it becomes one more, unless that would exceed `MAX_RETRIES`, when the job fails with the error instead; otherwise the job is retried.
- **FR-3** A job that gives no answer must be treated as having made no progress.
- **FR-4** The count must be kept with the job across its retries, in the same place and under the same key as today, so that it survives the job being serialized and dispatched again, and a job queued before the upgrade keeps its count.
- **FR-5** The art build must answer from the work of its own attempt: images fetched and kept, or a batch of fingerprints stored (decision 3).
- **FR-6** The refresh must answer from the work of its own attempt: a catalog row written (decision 3). Records seen and the download must not count. The source contract is unchanged.
- **FR-7** `Catalog::RateLimitRetry` must name no collectible, source or host (ADR 0018).
- **FR-8** A retry must still wait what the source asked, `SHORTEST_WAIT` at least, and still come before the job's own `retry_on` for transient errors.

## Non-Functional Requirements

- **Reliability:** each fresh start of the count needs durable new work, so a job can't be retried for ever: the work left (images uncached, artworks without a fingerprint, rows that differ from the source) shrinks with each.
- **Politeness to the source:** no more requests than today between rate limits; retries keep their waits.
- **Compatibility:** a job already waiting in the queue when an instance upgrades carries its old count, kept under the same key (FR-4); its next rate limit asks the new question. No migration.

## Error Scenarios

| Scenario | Behaviour |
|---|---|
| A build fetches images for an hour, then a 429 | Retried after 45 seconds at least; count 1 |
| A build's first request after its retry gets a 429, four times in a row | Count 1, 2, 3, then the job fails and shows under Failed (as today) |
| A refresh is turned away at `/bulk-data` or `/sets` four times, a fresh download or not | Count 1, 2, 3, then the job fails (as today) |
| A wait of more than an hour asked, after progress | The job fails at once (as today) |
| The job's attempt fails before it opens its run (a busy database at start), then a rate limit next attempt | The rate-limited attempt is judged alone (decision 2) |
| A job queued before the upgrade, waiting with count 3 | Its next rate limit is judged by progress: retried with count 1 if it made progress, failed if not |

## Supersedes

- **Spec 002 FR-4**, "or more than 3 such retries of one job: beyond either the job fails", and its Error Scenarios row "rate limits the same job a fourth time": the fourth rate limit in a row with no progress between them.
- **Spec 011 AC-3.6**, "a job is retried this way 3 times at most" and "So one such 429 stops the build and uses one of the job's 3 retries", and its Error Scenarios rows "stopped by a rate limit a fourth time" / "stopped this way a fourth time": the same.
- **Spec 024**, the parenthesis "turned away a fourth time" (Decisions, decision 1's consequences): the same.

Recorded in `docs/specs/README.md` in both directions.

## Open Questions

None. Decision 1 was ruled by the maintainer on 2026-11-06.

## Out of Scope

- #77 (start or cancel during a rate-limit wait) and #176 (art index settings drift).
- Changing `MAX_RETRIES`, `SHORTEST_WAIT`, `LONGEST_WAIT` or the client's back-off.
- Showing the count on the admin pages.
