# Feature 014: Admin Catalog Operations and Jobs

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-10-09
**Last Updated:** 2026-10-09
**Branch:** `014-admin-catalog-and-jobs`
**Issue:** [#29](https://github.com/plainprogrammer/Collector/issues/29)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-09 | Initial draft from the approved [prd.md](prd.md) and the accepted ADRs [0013](../../adr/0013-hand-built-admin-jobs-console.md) (hand-built jobs pages on Solid Queue's models) and [0014](../../adr/0014-admin-progress-by-polling.md) (live progress by polling with morph refreshes) |

---

## Problem Statement

Collector's catalog changes only through background jobs: the catalog refresh (weekly, or `bin/rails "catalog:refresh[mtg]"`) and, with art matching on, the art index build that the refresh queues. An admin can start and watch them only from a shell. A new instance's catalog stays empty until the first weekly run unless the self-hoster runs a rake task inside the container. A running refresh records nothing until it ends, the art build's progress is visible only as a line printed by `catalog:status`, and a failed job can be found and retried only from a Rails console. Admins, often not Rails users, need to start, watch and recover these jobs from the app.

> **Inputs.** Scope and decisions come from the approved [prd.md](prd.md) and the accepted ADRs [0013](../../adr/0013-hand-built-admin-jobs-console.md) and [0014](../../adr/0014-admin-progress-by-polling.md). The job queue (Solid Queue), the existing jobs (`Catalog::RefreshJob`, `MTG::Art::BuildJob`), their run records (`Catalog::RefreshRun`, `MTG::ArtBuild`), the source contract (`Catalog::Sources`), the admin guard (`AdminOnly`) and the design system are fixed inputs, so this spec names them. Paths `/admin/catalog` and `/admin/jobs` are user-facing and named here too.

### Glossary

- **Catalog type:** a kind of collectible with a catalog source (today only `mtg`).
- **Operation:** something an admin can start for a catalog type and watch: the **refresh** (every type) and any **extra operation** the type's source adds (for `mtg`, the **art index** build).
- **Loaded:** a catalog type is loaded once it has at least one applied refresh run. (This is the condition catalog search already uses for "The card catalog hasn't been loaded yet.")
- **In flight:** an operation is in flight while its job is unfinished in the queue (waiting, waiting on a concurrency limit, scheduled for a retry, or running) or its run record is running and not interrupted.
- **Queued (operation state):** in flight with no running run record yet.
- **Interrupted:** a run record still marked running whose last progress is older than the **stall threshold**. The refresh's stall threshold is 15 minutes; the art index keeps its own (`MTG::ArtBuild::STALE_AFTER`, 10 minutes).
- **Stages of a refresh:** *download*, *sync cards*, *retire missing cards*, *rebuild name index*, in that order.
- **Job states on the jobs page:** **Failed** (failed and not retried or discarded), **Running** (claimed by a worker), **Queued** (ready to run, or blocked by a concurrency limit; blocked ones are marked "waiting"), **Scheduled** (due at a later time, including retry back-offs).
- **Admin / member:** a signed-in user with or without `admin`.

## Goals

- An admin can load a new instance's catalog from the app, without a shell, and watch it happen.
- While a refresh runs, the admin sees which stage it is in and, for the download and sync stages, a percentage that rises as work is done.
- With art matching on, the art index build appears beside the refresh with its progress.
- An admin can see failed, running, queued and scheduled jobs, read a failure's error and backtrace, and retry or discard a failed job.
- The admin catalog page works for any catalog type without being changed for it.
- Members are told the catalog isn't loaded, instead of seeing empty results without explanation.

## Non-Goals

- Pausing or resuming queues; running recurring tasks on demand.
- Retrying or discarding several jobs at once; retrying or discarding jobs that aren't failed.
- Filtering or searching jobs by queue, class or argument.
- Progress for jobs other than catalog operations.
- Changing the refresh schedule, languages or art matching from the app.
- Starting the first refresh automatically.
- Live updates pushed by broadcast (ADR 0014); a jobs-dashboard gem (ADR 0013).
- Removing or changing the `catalog:refresh` and `catalog:status` rake tasks (beyond `catalog:status` also reflecting the new stall rule).

## Users and Context

**Primary users:** admins of a self-hosted instance, usually its owner. They load the catalog the first time and occasionally check that the weekly refresh and the art index are healthy, and recover from a failure.
**Secondary users:** members, who search and scan and need to know when the catalog isn't there yet.
**Usage context:** first-run setup right after creating the first account; occasional checks afterwards, on a desktop or a phone.
**User mental model:** "Catalog" is where cards come from and where I update them; "Jobs" is the app's to-do list, where I can retry something that broke.

**What this touches:** `Catalog::Refresh` and `Catalog::RefreshRun` (stage and progress, stall rule); the `Catalog::Sources` contract (optional progress and operations hooks); `MTG::Scryfall::Source`/`Client` and `MTG::Art` (the MTG implementations); new admin controllers and views; catalog search, the scanner and the More page (notices and links); the design system docs for any new pattern; the test setup (Solid Queue's tables in the test database).

## User Stories

### Story 1: Load the catalog the first time

**As an** admin of a new instance
**I want** to be told the catalog is empty and to start loading it in one click
**So that** search and the scanner work without my opening a shell

**Acceptance criteria:**

- [ ] **AC-1.1** Given a catalog type that isn't loaded When an admin opens catalog search, the scanner or the More page Then an inline notice says the card catalog hasn't been loaded yet and links to `/admin/catalog`.
- [ ] **AC-1.2** Given a catalog type that isn't loaded When a member opens catalog search or the scanner Then an inline notice says the card catalog hasn't been loaded yet and to ask an admin, with no link to `/admin/catalog`.
- [ ] **AC-1.3** Given a loaded catalog When an admin or member opens catalog search, the scanner or the More page Then no not-loaded notice is shown.
- [ ] **AC-1.4** Given a catalog type that isn't loaded and no operation in flight When an admin opens `/admin/catalog` Then the type's panel shows an empty state saying no cards are loaded yet, that the first refresh downloads the source's card data and may take several minutes, and which languages are configured, with "Refresh now" as its primary action. (Download sizes are not shown before the refresh: nothing calls the source during a render.)
- [ ] **AC-1.5** Given a fresh instance with no applied refresh When the app boots or the first admin signs up Then no refresh job is queued.

### Story 2: Start a refresh and watch it

**As an** admin
**I want** to start a refresh and see its stage and progress update by themselves
**So that** I know it is working and when it is done

**Acceptance criteria:**

- [ ] **AC-2.1** Given no refresh in flight for a type When an admin presses "Refresh now" Then one refresh job is queued for that type with the manual trigger, the admin is redirected back to `/admin/catalog` with the notice "Refresh queued.", and the panel shows the refresh as queued.
- [ ] **AC-2.2** Given a refresh in flight for a type (queued, running, or retrying) When an admin opens `/admin/catalog` Then that type's "Refresh now" is disabled with the reason shown (queued or running).
- [ ] **AC-2.3** Given a refresh in flight When an admin submits a start request for it anyway (a stale page or a second tab) Then no second job is queued and the admin is redirected with the notice "A refresh is already queued or running."
- [ ] **AC-2.4** Given a running refresh When its panel is rendered Then it lists the four stages in order, each marked done, current or pending, and shows when the run started and its trigger.
- [ ] **AC-2.5** Given a running refresh in the download stage, with a known expected size When its panel is rendered Then the current stage shows bytes received of the expected size as a percentage bar and in megabytes.
- [ ] **AC-2.6** Given a running refresh in the sync cards stage When its panel is rendered Then the current stage shows the share of the bulk file consumed as a percentage bar, and the running counts of records seen, inserted and updated.
- [ ] **AC-2.7** Given a running refresh in the retire or rebuild name index stage When its panel is rendered Then the current stage is marked current without a percentage.
- [ ] **AC-2.8** Given a source that does not report download or sync progress When its refresh is in those stages Then the stage is marked current with counts (if any) and no percentage, and nothing errors.
- [ ] **AC-2.9** Given a running refresh making progress When a sync of N records completes Then its progress (stage, done, total and counts) has been recorded at least every 5,000 records seen or every 5 seconds, whichever comes first, and at most once a second.
- [ ] **AC-2.10** Given `/admin/catalog` open while an operation is in flight When the operation's recorded progress changes Then the page shows the change within 5 seconds without the admin reloading, and keeps its scroll position.
- [ ] **AC-2.11** Given `/admin/catalog` open while an operation is in flight When the last in-flight operation ends Then the page shows the final state and stops requesting updates.
- [ ] **AC-2.12** Given `/admin/catalog` open with nothing in flight When time passes Then the page requests no updates.
- [ ] **AC-2.13** Given a refresh that finishes as applied When the panel is rendered Then it shows the run as applied with its counts (seen, inserted, updated, retired, restored, malformed), its source version and its finish time, and the type's health shows the new entry count and last applied refresh.
- [ ] **AC-2.14** Given a refresh that ends as skipped (already running, or the version already applied) When the panel is rendered Then the run is shown as skipped with its message.
- [ ] **AC-2.15** Given the start of a refresh from the page When the job runs Then it passes through the same guards as a scheduled or rake-started refresh (`Catalog::RefreshRun.start!`), so two refreshes for a type never apply at once.

### Story 3: See a refresh fail or stall

**As an** admin
**I want** a failed or stuck refresh to say what happened and where
**So that** I can decide to retry it

**Acceptance criteria:**

- [ ] **AC-3.1** Given a refresh that failed When its panel is rendered Then it shows the run as failed, the stage it failed in, the message recorded, and a link to the jobs page's Failed list.
- [ ] **AC-3.2** Given a refresh run still marked running whose last recorded progress is older than 15 minutes When its panel is rendered Then it is shown as interrupted, with the time of its last progress and the stage it was in, and "Refresh now" is enabled unless a refresh job is still unfinished in the queue.
- [ ] **AC-3.3** Given an interrupted refresh run When a new refresh starts (from the page, the rake task or the schedule) Then the interrupted run is closed as failed with the message "interrupted" and the new run proceeds, rather than being skipped as already running.
- [ ] **AC-3.4** Given a refresh run still marked running whose last progress is within 15 minutes When a new refresh starts Then the new run is skipped as already running (today's behaviour).
- [ ] **AC-3.5** Given an interrupted refresh run When `bin/rails "catalog:status[mtg]"` runs Then its status line marks it interrupted.

### Story 4: Build the art index from the page

**As an** admin of an instance with art matching on
**I want** to see the art index's state and progress and start a build
**So that** I can resume an interrupted build or rebuild after a failure without a shell

**Acceptance criteria:**

- [ ] **AC-4.1** Given art matching on When `/admin/catalog` is rendered Then the MTG panel shows an "Art index" section with its state: never built, building, ready, failed or interrupted, matching what `catalog:status` reports.
- [ ] **AC-4.2** Given a running art build When its section is rendered Then it shows artworks fingerprinted of the total as a percentage bar, images fetched, failed images and the last heartbeat time.
- [ ] **AC-4.3** Given art matching on, a loaded MTG catalog and no art build in flight When an admin presses "Build art index" Then one art build job is queued, the admin is redirected back with the notice "Art index build queued.", and the section shows it as queued.
- [ ] **AC-4.4** Given an art build in flight When `/admin/catalog` is rendered Then "Build art index" is disabled with the reason; a start request submitted anyway queues nothing and redirects with the notice "An art index build is already queued or running."
- [ ] **AC-4.5** Given art matching on and the MTG catalog not loaded When the section is rendered Then "Build art index" is disabled and the section says the catalog must be refreshed first.
- [ ] **AC-4.6** Given art matching off When the MTG panel is rendered Then the "Art index" section says art matching is off and names the setting that turns it on, and offers no button.
- [ ] **AC-4.7** Given a finished art build When its section is rendered Then it shows artworks indexed, artworks without an image, failed images and the finish time.
- [ ] **AC-4.8** Given a failed art build When its section is rendered Then it shows the failure message and the index still in use (or none).
- [ ] **AC-4.9** Given a refresh queued from the page that applies When art matching is on Then the art build follows it exactly as after a scheduled refresh (spec 011 AC-3.1), and appears in the section.

### Story 5: A panel per catalog type

**As a** maintainer adding a catalog type later
**I want** the admin catalog page to show the new type without changes to the page
**So that** the core stays collectible-agnostic

**Acceptance criteria:**

- [ ] **AC-5.1** Given the registered catalog types When `/admin/catalog` is rendered Then there is one panel per type, titled with the type's display name, showing: entry count (cards not retired), last applied refresh (finish time and source version), next scheduled refresh, the refresh operation, any extra operations, and the 5 most recent refresh runs.
- [ ] **AC-5.2** Given a type whose source defines no extra operations When its panel is rendered Then it shows only the refresh operation, without error.
- [ ] **AC-5.3** Given a test-only catalog type whose source defines one extra operation When `/admin/catalog` is rendered Then that operation appears in the type's panel with its title, state and start button, with no change to the admin controllers or views.
- [ ] **AC-5.4** Given the core's admin catalog code (controllers, views, core models) When it is read Then it names no specific collectible type, source or operation (no MTG, Scryfall or art).
- [ ] **AC-5.5** Given a recurring refresh scheduled for a type When its panel is rendered Then "next scheduled refresh" shows its next run time; given none (as in development) Then it shows "Not scheduled".
- [ ] **AC-5.6** Given a start request naming an unknown catalog type or an operation the type doesn't have When it is submitted Then the response is 404 and nothing is queued.

### Story 6: See and recover jobs

**As an** admin
**I want** to see the app's background jobs and retry or discard failed ones
**So that** I can recover from failures without a console

**Acceptance criteria:**

- [ ] **AC-6.1** Given jobs in each state When an admin opens `/admin/jobs` Then filter chips for Failed, Running, Queued and Scheduled show each state's count, and the Failed list is shown by default.
- [ ] **AC-6.2** Given a filter is chosen When the list renders Then it shows that state's jobs, newest first, 25 per page, each with its job class, a short form of its arguments, its queue, and the time relevant to the state (failed at, started at, queued at, or due at). Queued jobs blocked by a concurrency limit are marked "waiting".
- [ ] **AC-6.3** Given a failed job When it is listed Then the row also shows the exception class and the first line of its message.
- [ ] **AC-6.4** Given a state with no jobs When its filter is chosen Then an empty state says there are no jobs in that state.
- [ ] **AC-6.5** Given a job When an admin opens its page Then it shows its class, full arguments, queue, priority, attempts (executions), when it was queued, scheduled, started and finished as applicable, its current state, and for a failed job the exception class, message and backtrace.
- [ ] **AC-6.6** Given a failed job When an admin chooses Retry Then the job is queued to run again, it no longer appears under Failed, and the admin is redirected to the Failed list with the notice "Retrying <job class>."
- [ ] **AC-6.7** Given a failed job When an admin chooses "Discard…" Then a confirm page names the job and says it will be removed and not run again; confirming removes the job, it no longer appears in any list, and the admin is redirected to the Failed list with the notice "Discarded <job class>."; cancelling returns to the list with the job unchanged.
- [ ] **AC-6.8** Given a job that isn't failed (running, queued, scheduled or already gone) When a retry or discard request is submitted for it Then nothing changes and the admin is redirected to the jobs page with the alert "That job isn't failed any more." (or 404 when the job doesn't exist).
- [ ] **AC-6.9** Given a job that isn't failed When its page or row is rendered Then no Retry or Discard action is offered.
- [ ] **AC-6.10** Given `/admin/jobs` or a job page open while any job is running or queued When jobs change state Then the page shows the change within 5 seconds without reloading, and stops requesting updates once no job is running or queued.

### Story 7: Admins only, and easy to find

**As the** instance owner
**I want** these pages limited to admins and linked where admins look
**So that** members can't run or see operations, and admins can find them

**Acceptance criteria:**

- [ ] **AC-7.1** Given a member When they request any `/admin/catalog` or `/admin/jobs` page or action Then the response is 404 and nothing is queued, retried or discarded.
- [ ] **AC-7.2** Given a visitor who isn't signed in When they request any of those pages or actions Then they are sent to sign in, as for every other page.
- [ ] **AC-7.3** Given an admin When they open the More page Then it links "Catalog" (`/admin/catalog`) and "Jobs" (`/admin/jobs`) beside "Users and sign-up"; given a member Then neither link is shown.
- [ ] **AC-7.4** Given `/admin/catalog` and `/admin/jobs` When rendered at phone width (375 px) and desktop width Then all content and actions are reachable without horizontal page scrolling, using only design-system components and tokens.

## Functional Requirements

### FR-1: Refresh stage and progress

**Must:**
- Record on each refresh run its current stage (one of the four), the stage's done and total quantities (where the source reports them), and the running counts, while the run is running.
- Record progress on the cadence of AC-2.9, measured in records seen and elapsed time, independent of how many rows changed.
- Keep the stage reached when a run fails, so the failure's stage can be shown.
- Treat a run's last recorded progress as its heartbeat for the stall rule (AC-3.2 to AC-3.5), using a 15-minute stall threshold for both display and the start guard.

**Must not:**
- Write progress inside the refresh's batch write transactions or in a way that lengthens them.
- Change the counts a finished run records, or how runs are skipped for an already applied version.

### FR-2: Source hooks

**Must:**
- Let a source optionally report download progress (bytes received and expected size) and sync progress (bytes of the downloaded file consumed and its size); sources that don't report it keep working (AC-2.8).
- Let a source optionally add extra operations to its type's panel, each with: a title, a state (never run, queued, running, finished/ready, failed, interrupted, or unavailable with a reason), progress (done, total, labelled counts), summary lines, whether it can start now (and why not), and how to queue it.
- Implement both for MTG: download and sync progress for Scryfall bulk files; the art index operation (Story 4).

**Must not:**
- Require the core to know any source, collectible type or operation by name.

### FR-3: Starting operations

**Must:**
- Queue the operation's existing job with the same arguments the rake task or the refresh uses (`Catalog::RefreshJob` with the manual trigger; `MTG::Art::BuildJob`).
- Refuse to queue an operation already in flight (AC-2.3, AC-4.4) or unavailable (AC-4.5, AC-4.6), and say so.
- Answer the start request with a redirect (see other) to `/admin/catalog` carrying a notice.

**Must not:**
- Run any operation inline in the request, or call Scryfall during the request or any page render.
- Bypass `Catalog::RefreshRun.start!` or `MTG::ArtBuild.start!`.

### FR-4: Live updates

**Must:**
- Keep `/admin/catalog`, `/admin/jobs` and job pages current while work is in flight (AC-2.10, AC-6.10), by re-rendering from recorded state, with a request interval of about 2 seconds.
- Stop requesting updates when nothing is in flight (AC-2.11, AC-2.12).

**Must not:**
- Broadcast from jobs, or require jobs to render anything.

### FR-5: Jobs pages

**Must:**
- Read job state from the queue's own records, covering failed, claimed, ready, blocked and scheduled jobs (AC-6.1 to AC-6.5).
- Retry and discard failed jobs only, through the queue's own retry and discard operations (AC-6.6 to AC-6.8).
- Confirm a discard on its own page before acting.

**Must not:**
- Offer pausing, resuming, bulk actions or actions on jobs that aren't failed.
- Show more than 25 jobs per page.

### FR-6: Not-loaded notices

**Must:**
- Show the notices of AC-1.1 and AC-1.2 while any catalog type is not loaded, and name the type when there is more than one.
- Never queue a refresh except from an admin's start request, the schedule or the rake task.

### FR-7: Access and navigation

**Must:**
- Guard every page and action of this feature with the existing admin guard (404 for members).
- Link the pages from the More page for admins (AC-7.3).
- Use the design system's existing components and tokens; document any new pattern (for example a progress bar or a stage checklist) under `docs/design-system/components/` with its classes in `collector/additions.css`.

**Must not:**
- Accept a job class, queue or method name from the request beyond the job's id, the catalog type and the operation's key, each checked against what exists.

## Non-Functional Requirements

### Performance

- `/admin/catalog` and `/admin/jobs` render in under 300 ms on the development machine with a loaded MTG catalog and 1,000 finished, 100 failed and 100 scheduled jobs in the queue.
- Progress recording adds no more than 5% to a refresh's wall-clock time, measured on a re-run that changes nothing.
- While polling, each update request does no more than a constant number of queries per panel (no query per job or per run listed).

### Security

- Admin-only (FR-7). Start, retry and discard are non-GET requests with CSRF protection.
- Job arguments and backtraces are shown to admins only, escaped as text.
- Request parameters never choose a class or method to call (FR-7 must-not).

### Reliability

- Pages render correctly whatever state jobs and runs are in, including runs left running by a crash, jobs whose class no longer exists, and an empty queue.
- A restart of the app during a refresh or a build leaves the page showing the run as interrupted (after the stall threshold) and a start possible (AC-3.2, AC-3.3), not a refresh blocked for hours.
- The test suite exercises the jobs pages against real queue tables, not stubs (ADR 0013's consequence).

### Accessibility

- Progress bars expose their value and label to assistive technology; stages are a list whose current item is identified in text, not only by colour.
- Action results use the design system's status message (live region); lasting conditions use the inline notice.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The Scryfall download fails mid-way | The run is failed in the download stage with the error message (AC-3.1); the job's retry rules apply as today; a final failure lists under Failed. |
| The bulk file is unreadable (no valid records) | The run is failed in the sync stage with today's message ("no valid records …"). |
| The app restarts during a refresh | After 15 minutes without progress the run shows as interrupted; the queue re-runs the job or the admin starts a new refresh, which closes the interrupted run (AC-3.3). |
| The app restarts during an art build | As spec 011: the build's own stall rule (10 minutes) and job-id rule mark it interrupted; the section shows it (AC-4.1). |
| Two admins press "Refresh now" at once | At most one job runs the refresh; the other start is refused (AC-2.3) or, if both are queued, the second is skipped as already running (AC-2.15). |
| A retry or discard targets a job another admin already handled | No change; alert "That job isn't failed any more." (AC-6.8). |
| A job's class no longer exists (removed in an upgrade) | It is listed with its recorded class name; its page renders; it can be discarded. |
| ImageMagick missing with art matching on | The art build fails as spec 011 says; the section shows the failure message (AC-4.8). |
| The expected download size is unknown | The download stage shows bytes received without a percentage. |

## Open Questions

None. Decisions made in drafting, for the maintainer to confirm at approval:

- **Loaded** means "has an applied refresh run", the condition catalog search already uses.
- The refresh's **stall threshold is 15 minutes**, and it also changes the start guard: an interrupted refresh no longer blocks new ones for 6 hours (AC-3.3). Today, a refresh interrupted by a restart blocks the next for up to 6 hours.
- Lists show **5 recent runs** per type and **25 jobs** per page; updates every **~2 seconds**, shown within **5 seconds**.

## Out of Scope (Future Considerations)

- A general jobs console with queue control (pause, recurring tasks on demand); revisit ADR 0013 if the scope grows to that.
- Retry all failed jobs.
- Job filtering and search.
- An automatic first refresh.
- Progress for other job types.
- Settings for schedule, languages and art matching in the app.
