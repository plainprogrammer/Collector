# PRD: Admin Catalog Operations and Jobs

**Date:** 2026-10-09
**Feature:** 014-admin-catalog-and-jobs
**Issue:** [#29](https://github.com/plainprogrammer/Collector/issues/29), "Add admin UI for initial catalog refresh, image indexing, and progress of status"

## Problem

Collector's catalog changes only through background jobs: `Catalog::RefreshJob` (weekly on Monday at 03:15, or `bin/rails "catalog:refresh[mtg]"`) and, with art matching on, `MTG::Art::BuildJob`, which the refresh queues. Today an admin can start and watch them only from a shell:

- **A new instance has an empty catalog** until the next Monday, unless the self-hoster runs the rake task inside the container (`docker compose exec web bin/rails …`, or a Kamal alias). Search and the scanner find nothing until then, and nothing in the app says why.
- **A refresh shows no progress.** `Catalog::RefreshRun` records its counts only when it finishes; while it runs, `catalog:status` shows "running" and nothing else, and it records no stage, so a failure doesn't say where it happened.
- **The art build's progress exists but is hidden.** `MTG::ArtBuild` records counts and a heartbeat every 50 artworks; only `catalog:status` prints them, as a line of text. A first build takes hours (spec 011: about 2.6 hours of fetching).
- **A failed job can only be found and retried from a Rails console.** Solid Queue keeps failed jobs, but nothing in the app shows them.

The issue asks for "a Rake UI-style interface for the jobs … catalog refresh and image indexing", showing "progress rather than just logs or static status reporting".

## Users & Context

- **Admins** (`User#admin?`) of a self-hosted instance, usually its owner, often non-technical about Rails. They set up the instance, load the catalog the first time, and occasionally check that the weekly refresh and the art index are healthy. The admin area already exists: `AdminOnly` (404 for everyone else) and `/admin/users`, linked from the More page.
- **Members** don't operate the catalog, but they hit its absence: search and the scanner are empty on a new instance.

It touches:

- `Catalog::Refresh`, `Catalog::RefreshRun`, `Catalog::RefreshJob` and the `Catalog::Sources` contract (optional source hooks, as with `status_lines`, `reapply?` and `after_refresh`).
- `MTG::Art`, `MTG::ArtBuild`, `MTG::Art::BuildJob` (spec 011), through the MTG source.
- Solid Queue's own tables and models (`SolidQueue::Job`, its executions, `FailedExecution`).
- The design system (`docs/design-system/`), `AdminOnly`, the More page, catalog search and the scanner.

## Goals

1. **An admin catalog page** (`/admin/catalog`) with one panel per catalog type: health (entry count, last applied refresh and its source version, next scheduled run from Solid Queue's recurring task, or "not scheduled" where none exists, as in development), a "Refresh now" button, the type's extra operations (for MTG, "Build art index"), the running operation's stages with progress, and recent runs.
2. **Live progress while work runs.** For the refresh, a stage checklist (download, sync cards, retire missing cards, rebuild name index) with a real percentage on the running stage: bytes received against the file size while downloading, bytes read from the bulk file against its size while syncing, plus running counts (seen, inserted, updated). For the art build, its existing counts (artworks fingerprinted of total, images fetched, failed). The page updates by itself while anything is queued or running and stops when nothing is ([ADR 0014](../../adr/0014-admin-progress-by-polling.md)).
3. **Starting operations from the page.** The button queues the same job the rake task does; it's disabled while that operation is queued or running, from the moment it's clicked. Starting never bypasses the existing guards (`Catalog::RefreshRun.start!`, `MTG::ArtBuild.start!`).
4. **A collectible-agnostic page.** The core knows only "catalog operations" (title, state, stages with done/total, summary lines, how to start). The refresh is the core's own operation; a catalog type adds others through an optional source hook. The core never mentions art, Scryfall or MTG. A new catalog type gets its panel without changing the page.
5. **An admin jobs page** (`/admin/jobs`): filters for Failed, Running, Queued and Scheduled with counts, where Queued includes jobs waiting on a concurrency limit (Solid Queue's blocked executions, e.g. a second refresh while one runs), marked as waiting; a list per filter; a page per job with its class, arguments, queue, attempts, timestamps and, for a failed job, the error and backtrace. **Retry** and **Discard** for failed jobs, with Discard confirmed on a confirm page. Retry and Discard apply only to failed jobs ([ADR 0013](../../adr/0013-hand-built-admin-jobs-console.md)).
6. **A first-run prompt.** While a catalog type has no entries, admins see a notice linking to `/admin/catalog` on catalog search, the scanner and the More page; members see that the catalog isn't loaded yet and to ask their admin. The first refresh is never started automatically: the download is the admin's choice (about 79 MB for English, about 393 MB with `COLLECTOR_MTG_LANGUAGES` adding languages, as of 2026-09-29), made after they've set languages or art matching.
7. **Navigation.** The More page links "Catalog" and "Jobs" for admins, beside "Users and sign-up".
8. **The design system throughout:** existing `c-*` components and tokens, a doc under `docs/design-system/components/` for any new pattern, phone width included.

## Non-Goals

- Pausing or resuming queues, or running recurring tasks on demand.
- "Retry all failed" or other bulk actions on jobs.
- Filtering or searching jobs by queue, class or argument.
- Progress for job types other than the catalog's operations.
- Changing the refresh schedule, languages or art matching from the UI (they stay environment settings).
- Starting the first refresh automatically.
- Live updates by broadcast (ADR 0014).
- Mission Control – Jobs or any other jobs-dashboard gem (ADR 0013).
- Replacing the rake tasks; `catalog:refresh` and `catalog:status` keep working.

## Success Criteria

- On a new instance, the first admin finds the catalog page from the notice on search, the scanner or More, clicks "Refresh now", and watches the download and sync percentages rise to an applied run, without a shell, a log or reloading the page.
- With art matching on, the art build that follows appears on the same panel and its progress advances while the admin watches.
- A refresh that fails shows the stage it failed in and its message; its failed job is on the jobs page with its backtrace, and Retry queues it again.
- Clicking "Refresh now" twice, or while the weekly run is going, never runs two refreshes at once and never errors.
- Members never reach `/admin/catalog` or `/admin/jobs` (404), and see a clear message on an empty catalog instead of empty results.
- The pages stop requesting updates once nothing is queued or running.
- Adding a second catalog type in a later spec needs no change to the admin catalog page.

## Architecture Decisions

- [0013: Hand-build the admin jobs console on Solid Queue's models](../../adr/0013-hand-built-admin-jobs-console.md): our own design-system pages calling Solid Queue's `retry` and `discard`, instead of mounting Mission Control – Jobs, whose UI is outside the design system and whose queue controls were excluded.
- [0014: Show live progress on admin pages by polling with Turbo morph refreshes](../../adr/0014-admin-progress-by-polling.md): a Stimulus controller, present only while work is in flight, morph-refreshes the page every ~2 seconds from progress rows the jobs already write, instead of Turbo Stream broadcasts.

Decisions made inline (no ADR; trivial or following existing patterns):

- **Refresh progress columns.** `catalog_refresh_runs` gains `stage`, `stage_done` and `stage_total` in an additive migration. `Catalog::Refresh` writes the stage at each step and progress on a cadence measured in work done, not in batch flushes (a flush only happens once 1,000 *changed* rows are pending, so on a weekly refresh where little changes it would fire once at the end): every few thousand records seen or every few seconds, whichever comes first. That is at most one small update every few seconds, on one row. The progress write doubles as a heartbeat: a run still marked running whose progress hasn't moved for a threshold measured in minutes (as `MTG::ArtBuild::STALE_AFTER` is, and long enough for the stages that report no percentage: retiring and the name index) is shown as interrupted, as the art build already does.
- **Download and sync percentages from the source.** The `Catalog::Sources` contract gains optional progress callbacks on `download` (bytes received against the expected size; `MTG::Scryfall::Client#download` already streams in chunks) and on `each_entry` (the bulk file is gzip, so compressed bytes consumed against the file's size). A source without them shows counts and no percentage.
- **The operations hook.** An optional source class method (alongside `status_lines`) returns the type's extra operations. MTG's returns the art index operation, which with art matching off says how to turn it on.
- **In flight** means any unfinished Solid Queue job for the operation's job class and arguments (ready, blocked, scheduled for a retry back-off, or claimed but not yet recording its run), plus a running run row; the button is disabled from the click until the run ends. "Queued" on the panel is in flight with no running run yet. Job lists read the execution tables (ready, blocked, claimed, scheduled, failed), not `SolidQueue::Job`'s own scopes.
- **Solid Queue in tests.** The test environment is primary-only with the `:test` adapter, so Solid Queue's tables don't exist there; the plan must make them available to request and system specs for these pages (e.g. load `db/queue_schema.rb` into the test database).
- **Routes and controllers** follow `.claude/rules/hotwire.md`: `Admin::CatalogsController#index`, `Admin::Catalogs::OperationStartsController#create`, `Admin::JobsController#index/show`, `Admin::Jobs::RetriesController#create`, `Admin::Jobs::DiscardsController#new/create`, all behind `AdminOnly`, redirecting with `:see_other`.
- **Layouts** (chosen from wireframes during brainstorming; these descriptions are the canonical record): the catalog page is a panel per catalog type with health, start buttons, a stage checklist with a progress bar on the running stage, and recent runs underneath; the jobs page is status filter chips with counts over a list, a row menu holding Retry and "Discard…", and a page per job for details and the backtrace.

## Out of Scope

Discussed and excluded:

- A general jobs console with queue control (scope C of the first question); it may come back later, under ADR 0013's revisit note.
- Retry all failed jobs (deferred by the maintainer).
- An automatic first refresh on sign-up or on boot (rejected for the download's size and to let admins set languages first).
- One overall progress bar without stages (rejected: stages say where a failure happened).
- A table of operations with a page per run (the rejected catalog layout).
- A single jobs page with inline errors (the rejected jobs layout).
