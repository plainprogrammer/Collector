# Feature 055: Retry Now for a Job Waiting to Retry

**Status:** Approved by the coordinator under the maintainer's delegation on 2026-11-09; open question 1 ruled by the maintainer the same day
**Version:** 1.0.0
**Created:** 2026-11-09
**Last Updated:** 2026-11-09
**Branch:** `055-rate-limit-retry-now`
**Issue:** [#77](https://github.com/plainprogrammer/Collector/issues/77)
**Frozen:** the current rules are in [`catalog-operations.md`](../../architecture/catalog-operations.md) (whole spec); see the [specs index](../README.md)
**Plan:** retired in `9427c40ae0d7d43c8f99e81964d5fe04974440b4`; read it with `git show 9427c40ae0d7d43c8f99e81964d5fe04974440b4^:docs/specs/055-rate-limit-retry-now/plan.md`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-09 | Written from issue #77 and the maintainer's ruling of 2026-11-09 (add "Retry now" to the waiting status on `/admin/catalog`; the run keeps its lifecycle and retry count; discarding a scheduled retry from `/admin/jobs` is out of scope) |
| 1.0.0 | 2026-11-09 | Approved. Maintainer ruling on open question 1 (2026-11-09): the wide offer, for any waiting retry of the failed run's own job; the side effect is that the refresh's "Queued to retry" means the run's own job, superseding spec 015 AC-3.7 in part. Open Questions now none; decision 1 and AC-1.5 stand as written |
| 0.2.0 | 2026-11-09 | Spec review rounds 1 and 2 (rounds: Fable, APPROVE WITH CHANGES each; round 2's two major fixes are in 0.2.0: the refresh mirrors the build's not-retrying panel (AC-1.3b, AC-1.6), AC-3.6 and an Error Scenarios row are per operation). Round 1 (Fable, APPROVE WITH CHANGES, 4 major, 6 minor): the refresh's "Queued to retry" is tied to the run's own job as the build's is (decision 1, AC-1.6, AC-1.7, FR-1); a retry is a new queue row with the same Active Job id, so the move targets the unfinished row holding the scheduled entry (decision 2, AC-3.6); the one-winner guard is stated (FR-2); decision 1's breadth is an open question with the narrow alternative; documents list completed; AC format and the "never an error" contradiction fixed |

---

## Problem Statement

`Catalog::RateLimitRetry` holds a rate-limited refresh or art index build in the queue for the wait the source asked for: up to 1 hour, up to 3 times in a row without progress (spec 002 FR-4; spec 011 AC-3.6; spec 043). The held job counts as in flight, so "Refresh now" and "Build art index" are refused for that whole time, and `/admin/jobs` retries and discards only failed jobs, so an admin can neither start the work another way nor end the wait (issue #77). An admin who knows the source is available again (a limit that lifted, a mistaken wait) has to sit out up to an hour per retry.

The maintainer ruled (2026-11-09) that the waiting status gets **Retry now**: it runs the scheduled job at once, as the same job, so the run keeps its lifecycle and its retry count. Discarding a scheduled retry from `/admin/jobs` is out of scope.

What exists today (verified in the code): a failed build whose own job is scheduled reads "Queued to retry." with "Retrying at" for that job (spec 015 AC-4.12; #80; `MTG::Art::Operation#retrying?`), while a failed refresh run reads it when *any* job queued for the type is scheduled (spec 015 AC-3.7; `Catalog::RefreshOperation#retrying?` and its "Retrying at" ask the queue with no job id), so a job held by hand beside a failed run makes the refresh read "Queued to retry." and show that other job's time; a start request is refused with "already queued or running"; while the retry waits the job holds no concurrency lock and a refresh or build started meanwhile is skipped as "waiting for another job's retry" (spec 024). A retry is a **new row** in the queue's jobs table (Active Job's `retry_job` enqueues again) that carries the same Active Job id, the same arguments and the retry record; the old row is finished when its attempt ends. The Active Job id is how the run records tell a retry from a fresh job, and how the build's panel finds its own job.

## Goals

- While a refresh or an art index build waits for its scheduled retry, an admin can run that job now from `/admin/catalog` with one button, "Retry now".
- The job that runs is the waiting one: no second job is queued, its retry count and run lifecycle are untouched, and the same guards apply as when its wait ends.
- Pressing it twice, two admins pressing it together, or pressing it as the wait ends runs the job at most once, and the loser sees that nothing is waiting, not an error.

## Non-Goals

- Discarding or cancelling a scheduled retry, or listing it differently, on `/admin/jobs` (ruling 2026-11-09). That page is unchanged.
- Starting a fresh refresh or build while a retry waits. "Refresh now" and "Build art index" stay disabled then, and a fresh job would be skipped by spec 024's rule anyway.
- Changing how long a retry waits, the retry count or its progress rule (`Catalog::RateLimitRetry`, spec 043), the start guards or the skip rule (spec 015, spec 024).
- Retrying a job that is not waiting: a failed job is retried from `/admin/jobs` as before (spec 015 AC-6.6), and a job a hand put into the queue for later (`perform_later(wait:)`) with no failed run of its own gets no button.
- A button for operations an extension adds in future: the interface is generic, but only the refresh and the art build use it.

## Users and Context

**Primary users:** an admin of a self-hosted instance (spec 004 admin flag).
**Usage context:** `/admin/catalog`, on a panel that reads "Queued to retry." with "Retrying at" some minutes or up to an hour away, after the admin has read the sentence saying the source was turning requests away.
**User mental model:** "The source is back. Run it now." The word is "retry", as in the status ("Queued to retry", "Retrying at") and on `/admin/jobs` ("Retry").

## Decisions

### 1. When the button is offered

On an operation's panel in the state "Queued to retry.": its latest run (refresh) or build (art index) failed, and **that run's own job** (by its Active Job id) is still in the queue waiting for a later time. For the refresh this tightens the state to the run's own job, as #80 did for the build: a failed run with only a hand-scheduled job beside it reads plain "Queued." (superseding spec 015 AC-3.7 in part, below). Nothing else gets the button: not a plain "Queued." (a job queued fresh, or one held by hand), not a failed run whose job is in the Failed list, not a run in progress, applied, skipped or never run, not an operation that is switched off, unavailable or has no job id on its run.

It is offered for any retry the queue holds for that job, whatever caused it: a rate limit (the case of the issue) and also the few-second waits of a busy database or a transient source error. One rule is simpler, and running the job a few seconds early is harmless; the cost is that an early press on a busy-database or transient-error retry (which the job allows 3 attempts in all) can use up one of those attempts sooner. The recorded failure does say whether it was a rate limit (`Catalog::FailureReason` keys on the stored error class), so the narrow rule is possible. *(Ruled by the maintainer on 2026-11-09: the wide offer. The rate-limit-only alternative was possible from the stored error class and was not chosen.)*

### 2. What it does

It makes that one job's scheduled entry ready to run now, through the queue's usual rules for the job: for a refresh, the per-type concurrency limit still applies, so the job runs when no other refresh of the type holds the lock and never beside one (spec 002 FR-4's "two refreshes of one type never apply at once"). It targets the one unfinished queue row of that Active Job id that holds the scheduled entry (a retry's old row, finished or finishing, never counts), queues no new job, copies nothing and changes neither the job's Active Job id, its arguments nor its retry record, so:

- the job runs under the same job id, and the run records treat it as the retry it is (`Catalog::RefreshRun.start!`, `MTG::ArtBuild.start!`);
- the count of rate limits in a row, kept in the job's retry record, is as it was: a rate limit with no progress on that attempt counts one more, not one again (spec 043).

The request does not run the job, and calls no source (spec 015 FR-3).

### 3. One winner

Moving the scheduled entry is atomic: of any number of requests, and of the queue's own dispatch of the entry when the wait ends, exactly one moves it. The others find nothing scheduled and change nothing: they never create a second ready or blocked entry for the job, and never queue a job. A press that finds nothing is not an error.

### 4. What the request names

Like a start request, only a catalog type and an operation's key, each looked up among what is registered. The job comes from the operation's own run, never from the request, so a request can't move another job.

### 5. Wording

Button **"Retry now"**, `c-btn--secondary`, in the operation's head beside its start button (which stays disabled and says why). After a press the notice is **"Retrying now."**; when nothing is waiting (another admin was first, the wait just ended, the job was discarded) the notice is **"Nothing is waiting to retry."** Both are flash notices on a `303` back to the page. When the job's per-type concurrency limit holds it behind another refresh, "Retrying now." still says what was asked; the panel then reads "Queued." and the job runs when the other ends (or its 6-hour lock expires).

## User Stories

### Story 1: Retry now is offered while a retry waits

**As an** admin looking at a rate-limited refresh or build
**I want** a "Retry now" button on its panel while it waits
**So that** I can run it as soon as I know the source is back

**Acceptance criteria:**

- [ ] **AC-1.1** Given a type's latest refresh run failed and its own job is scheduled for a later time When an admin views `/admin/catalog` Then the Refresh section reads "Queued to retry. …" with "Retrying at", shows an enabled "Retry now" button, and "Refresh now" is disabled
- [ ] **AC-1.2** Given art matching on and the latest art build failed and its own job is scheduled for a later time When an admin views `/admin/catalog` Then the Art index section reads "Queued to retry. …" with "Retrying at", shows an enabled "Retry now" button, and "Build art index" is disabled
- [ ] **AC-1.3** Given a refresh whose state is any of the following (each its own example) When an admin views `/admin/catalog` Then no "Retry now" button is shown: (a) a job queued fresh and ready; (b) a job scheduled by hand with no failed run of its own (the panel reads "Queued." with "Retrying at" as that job's time, as today); (c) a failed run whose job is in the Failed list; (d) a failed run whose job id is no longer in the queue; (e) a failed run with no job id; (f) running; (g) applied; (h) skipped; (i) never run
- [ ] **AC-1.3a** Given the art index in each of the same cases (a)–(i) read for a build, and art matching off Then no "Retry now" button is shown (each its own example)
- [ ] **AC-1.4** Given a failed run whose own job is scheduled and another job of the same class scheduled for a later time When the panel is read Then "Retry now" is offered for the failed run's own job, "Retrying at" shows that job's time (not the other's), and the other job is not the one a press moves (see AC-2.6)
- [ ] **AC-1.5** Given a failed art build whose own job is scheduled by the busy-database retry Then the panel offers "Retry now" as for a rate limit (decision 1, ruled 2026-11-09)
- [ ] **AC-1.6** Given a failed refresh run and only a job scheduled by hand beside it (not the run's own) When an admin views `/admin/catalog` Then the Refresh section reads "Queued." with "Retrying at" as the hand-scheduled job's time (as the art index does for a job that isn't the failed build's own retry), shows no stages or other facts of the failed run, and shows no "Retry now" (fails before the change: "Queued to retry." with the failed run's stages and facts)
- [ ] **AC-1.7** Given a failed refresh run whose own job is scheduled, and a hand-scheduled job due earlier When the panel is read Then "Retrying at" is the own job's time

### Story 2: Pressing it runs the waiting job

**As an** admin
**I want** the press to run the job that is waiting
**So that** nothing is queued twice and the retry keeps counting where it was

**Acceptance criteria:**

- [ ] **AC-2.1** Given the state of AC-1.1 When the admin presses "Retry now" Then the refresh job's scheduled entry is gone and the job has a ready entry, no job row was added, the job's Active Job id, arguments and retry record are unchanged, and the response is a `303` to `/admin/catalog` with the notice "Retrying now."
- [ ] **AC-2.2** Given the state of AC-1.2 When the admin presses "Retry now" Then the same holds for the art build's job (AC-2.1's assertions)
- [ ] **AC-2.3** Given a press that moved the job and it is not yet claimed, and no other job of the operation is scheduled When the panel is read Then it reads "Queued." with no "Retrying at", no "Retry now", and the start button still disabled; once a worker holds the job, the panel reads as it does for any running refresh or build
- [ ] **AC-2.4** Given a refresh job whose retry record counts 1 rate limit, moved by "Retry now", When it runs and is turned away again with no progress Then its count is 2 and it is scheduled again (job spec; the count was not reset by the press); and given it made progress Then the count starts again at 1, as without the press
- [ ] **AC-2.5** Given a moved refresh job runs (source stubbed) Then it passes through `Catalog::RefreshRun.start!` under its own job id and records its run as any retry does; given a moved art build job runs Then it passes through `MTG::ArtBuild.start!` the same way
- [ ] **AC-2.6** Given a failed run whose own job is scheduled, and a second job of the same class also scheduled for later When "Retry now" is pressed Then only the failed run's own job is moved
- [ ] **AC-2.7** Given a refresh job waiting to retry and another refresh job of the same type that holds the type's concurrency lock When "Retry now" is pressed Then the retry is blocked behind it (it waits, as any second refresh does) and runs only when that job ends or the lock expires; two refreshes of the type never run at once (queue example with Solid Queue's semaphore)
- [ ] **AC-2.8** Given the press Then no source is called in the request (HTTP blocked in the example) and no run record is created or changed by the press itself

### Story 3: Races and repeats do nothing twice

**As an** admin, and **as a second admin** on the same page
**I want** a repeated, late or simultaneous press to be harmless
**So that** the job runs once and I'm told plainly when there was nothing to run

**Acceptance criteria:**

- [ ] **AC-3.1** Given the state of AC-1.1 When "Retry now" is pressed twice in a row Then the second changes nothing (one ready entry, no blocked entry, no new job, same retry record) and answers `303` with the notice "Nothing is waiting to retry."
- [ ] **AC-3.2** Given a retry whose scheduled time has passed but which the queue has not yet dispatched When "Retry now" is pressed Then it is moved, once
- [ ] **AC-3.3** Given the job has been claimed by a worker, or has finished, or has been discarded, or has failed When "Retry now" is pressed (a page rendered earlier still showed the button) Then nothing changes (no ready or blocked entry is added for the job) and the notice is "Nothing is waiting to retry."
- [ ] **AC-3.4** Given the press has moved the job When the queue's own dispatch of due scheduled entries then runs (`SolidQueue::ScheduledExecution.dispatch_next_batch`) Then it finds nothing to dispatch for that job and the job still has exactly one ready entry and no blocked one; and given the dispatch ran first, a press after it changes nothing and adds no blocked entry (both orders)
- [ ] **AC-3.5** Given the queue-side move is asked to move a job whose scheduled entry another party removed after the operation re-read the queue and before the move (a model-level example: the entry is removed between the re-read and the move, standing for another admin or the dispatcher) Then exactly one entry is ready, none is blocked, nothing raises, and a request that hits this answers "Nothing is waiting to retry."
- [ ] **AC-3.6** Given a refresh job still claimed whose own retry row (same Active Job id, new row) is scheduled, as in the instant between the retry being queued and the old attempt's claim ending When "Retry now" is pressed Then the scheduled row is the one moved, to a blocked entry (the type's concurrency limit), released when the old claim ends; the claimed row is untouched and the two never run at once
- [ ] **AC-3.7** Given the same window for an art build job (which has no concurrency limit) When "Retry now" is pressed Then the scheduled row becomes ready, the claimed row is untouched and no other entry is created; the art build's own start guard (`MTG::ArtBuild.start!`, spec 011 AC-3.2) is what keeps two builds from working at once, as for any retry

### Story 4: Admins only, and only what the page names

**As the** instance operator
**I want** only admins to move jobs, and only the page's own job
**So that** a member or a crafted request can't run background work

**Acceptance criteria:**

- [ ] **AC-4.1** Given a member (not an admin) When they post a retry-now request Then the response is 404 and the waiting job is unchanged
- [ ] **AC-4.2** Given a visitor who is not signed in When they post a retry-now request Then they are sent to sign in and nothing changes
- [ ] **AC-4.3** Given a request naming an unknown catalog type or an unknown operation When an admin posts it Then the response is 404 and nothing changes
- [ ] **AC-4.4** Given an admin and a request that carries a job id or any other parameter besides the type and the operation Then the parameter has no effect (the job moved is the operation's own run's)
- [ ] **AC-4.5** Given the form posts the type and the operation key with the page's CSRF token Then the request is accepted; forgery protection is the framework default for every post (verified by reading `ApplicationController`, recorded in `verification.md`)

### Story 5: The button in the page

**As an** admin on a phone or a desktop
**I want** the button to read and work like the page's other actions
**So that** I find it where the status is

**Acceptance criteria:**

- [ ] **AC-5.1** Given a Capybara system example with a rate-limited refresh waiting (a failed run, its job scheduled) When an admin clicks "Retry now" Then the page shows "Retrying now.", the panel reads "Queued." and the "Retry now" button is gone, without a full reload by the example (Turbo)
- [ ] **AC-5.2** Given the panel in the waiting state at 390px wide Then the operation's head holds both buttons without sideways scrolling and the button has its text as accessible name (recorded in `verification.md` with screenshots at 390px and 1280px, light and dark, taken with the method in `.claude/memory/pr-screenshots-workflow.md`; the PR shows them)
- [ ] **AC-5.3** Given the page polls while anything waits (spec 015 AC-2.10) Then it still does, and after the press polling carries on until the job ends

### Story 6: The documents say so

**As a** maintainer or an agent reading the docs later
**I want** the area doc, the design system and the indexes to describe the button
**So that** the current rules are in one place

- [ ] **AC-6.1** `docs/architecture/catalog-operations.md`: the "A rate-limited job" section and the panel tables gain "Retry now" (what it does, one winner, which job, wording), the invariants gain that a press moves only the operation's own run's job and runs nothing in the request, the panel table rows for "Failed, a refresh job scheduled to run again" (now the run's own job) and the build's "Failed build whose own job is scheduled" show the button, a new refresh row says a failed run beside only another scheduled job reads "Queued." with that job's "Retrying at" (as the build's "isn't a failed build's own retry" row does), the invariant that the jobs pages read the queue's tables adds that the catalog page moves one scheduled job through the queue's own operations (ADR 0014), the open-issues line for #77 is reworded to what remains (discarding), the glossary's "Waiting retry" cross-refers, and Sources and the distillation log carry spec 055 and #77 (verified by reading)
- [ ] **AC-6.2** `docs/design-system/components/AdminCatalog.md` (and the admin catalog preview if it shows the waiting state): the rule "Each operation has at most one button" says one start button, plus "Retry now" while a retry waits (verified by reading)
- [ ] **AC-6.3** `docs/specs/README.md` has the 055 row with its Supersedes (015, 043, 024 in the senses below), and those rows carry "Superseded by" 055; no shipped spec is edited; `docs/roadmap.md`'s #77 line and `docs/architecture/catalog-core.md`'s two mentions of #77 (lines 205 and 217) are updated, and CLAUDE.md's "Admin catalog and jobs" bullet names spec 055 (verified by reading)
- [ ] **AC-6.4** `spec/admin_catalog_core_spec.rb` covers the new controller and view code (its file count is raised to the new count of files the glob finds, and nothing else in it changes) and passes: the core names no collectible

## Functional Requirements

### FR-1: The operation offers and performs a retry now

`Catalog::Operation` answers whether a retry of its own latest run is waiting (so the panel offers the button) and performs the move, generically, with no collectible named in the core. By default an operation has none. `Catalog::RefreshOperation` and `MTG::Art::Operation` answer from their latest run's or build's job id and the queue's reading, the one the panel already makes; the refresh's "Queued to retry" state and its own-job "Retrying at" take the run's job id, as the build's already do; with no retry of the run's own it falls back to the earliest scheduled job's time, as the build does (AC-1.6, AC-1.7).

**Must:**
- Offer only in the state of decision 1; and perform only when that state still holds when the request is handled (re-read at press time, not trusted from the page).
- Move exactly the job of the operation's own latest failed run or build.

**Must not:**
- Offer or move a job it can't tie to the run by Active Job id.
- Run the job, call a source, or write a run record in the request.

### FR-2: The move is atomic and has one winner

The queue-side move (the scheduled entry becomes a ready, or concurrency-blocked, entry) happens in one transaction on the queue's database that only one caller can win, and reports whether it did (decision 3). The scheduled entry is removed first and the move goes on only when exactly that removal happened, so a caller that finds it already gone dispatches nothing: the queue's own dispatch of a job does not check that the entry exists, and dispatching a limited job that is already ready or claimed would add a blocked entry that later runs it a second time. It uses the queue's own operations for dispatching a job, so the job's concurrency rules are the queue's. The test environment keeps the queue in the primary database, so no example can show that the transaction is opened on the queue's connection; that is checked by reading and recorded in `verification.md`.

**Must:**
- Leave the job's row, Active Job id, arguments and retry record untouched.
- Report false, changing nothing, when no scheduled entry exists (any reason).
- Target the unfinished row that holds the scheduled entry, never another row with the same Active Job id.

**Must not:**
- Create a job row, or a second ready or blocked entry for the job.

### FR-3: A resource of its own

A new resource controller under the catalog page's admin namespace takes `create`, answering `303` back to `/admin/catalog` with the notice of decision 5, and is admin-only (spec 015 FR-7). No custom action on an existing controller.

### FR-4: The button

`app/views/admin/catalogs/_operation.html.erb` renders "Retry now" in the operation's head when the operation offers it, a `button_to` to the new resource with the type and operation as parameters, with the page's existing classes and no new component, class or token.

### FR-5: Nothing else changes

`Catalog::RateLimitRetry`, the start guards, the skip rule (the refresh's "Queued to retry" test is the one change to its panel, FR-1), the jobs pages, `BackgroundJobs::Entry`, the retry and discard controllers, the poll controller and the scanner are unchanged.

## Non-Functional Requirements

### Performance

- No query on a render beyond what the panel already reads: the offer is decided from the queue reading the panel makes (scheduled entry of the run's job id). A press makes a handful of queries in one short transaction.

### Security

- Admin only; 404 for a member, sign-in for a visitor; CSRF as every post; the request names only a type and an operation key, each looked up among what is registered; no `permit!`, no job id from the request (`.claude/rules/security.md`).
- Catalog and queue data are global; no tenant data is read or written (`.claude/rules/multi-tenancy.md`: nothing tenant-owned).

### Reliability

- A press can't lose a job or run it twice: it is a move inside one transaction, and the queue's dispatch of the same entry is the other party to it. A press while the database is busy fails as any other post does (an error page) and moves nothing; the admin presses again.
- No migration, no new column, no stored data, no change to the export format or the backup.

### UI

- Copy is admin page copy under the `collector-design-system` skill: sentence case, no emoji, state words first, numbers exact; the button is `c-btn--secondary`; colour never carries the state alone.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The wait ended between the page render and the press | The queue already dispatched the job: nothing moves, notice "Nothing is waiting to retry." |
| Another admin pressed first | Same notice; the job runs once |
| The job was discarded or finished meanwhile | Same notice |
| The job's retry blocks behind another refresh holding the type's lock | "Retrying now."; the panel reads "Queued." (waiting) until that job ends, then the retry runs |
| A press in the instant a retry row is scheduled while its old attempt's row is still claimed | The scheduled row is moved: for a refresh it is blocked until the claim ends, for a build it is ready and the build's start guard keeps two builds from working at once (AC-3.6, AC-3.7) |
| The run has no job id (a run from before spec 015, or `perform_now`) | No button; a forged request moves nothing and gets the "nothing waiting" notice |
| Unknown type or operation | 404, nothing changes |
| The source is still rate limiting when the job runs | The job is turned away again as usual: the count goes up (no progress) or starts again (progress); it is scheduled again and the button reappears |
| Art matching turned off while a build waits | No button (the section reads "off") |

## Supersedes

- **Spec 015 AC-3.7 and AC-4.12, in part:** the "Queued to retry" panel keeps "Refresh now" and "Build art index" disabled, and now also shows "Retry now". AC-3.7's "a refresh job scheduled to run again" becomes the failed run's own job (as AC-4.12's already is), so a failed run beside only a hand-scheduled job reads "Queued.". Spec 015 AC-2.3/AC-4.4 (a start while in flight queues nothing) stand.
- **Spec 043 Non-Goals ("#77: … Unchanged") and spec 024 "Interactions for the maintainer" (#77):** #77 is now addressed for running the waiting job now; nothing in either spec's behaviour changes, and the second's "'Run the waiting job now' works with this rule unchanged" is what is built. Discarding a waiting retry stays open and out of scope.

## Open Questions

None. Open question 1 (breadth of the offer) was ruled by the maintainer on 2026-11-09: offer "Retry now" for any retry the queue holds for the failed run's own job, not only a rate limit's. The accepted cost is that an early press on a busy-database or transient-error retry may use one of its 3 attempts sooner.

## Out of Scope (Future Considerations)

- Discarding a scheduled retry, and showing scheduled jobs' actions on `/admin/jobs` (#77's other half, ruled out of scope).
- A "Retry now" for a job held by hand with no failed run.
- Starting fresh work while a retry waits (it would be skipped by spec 024's rule).
