# 0014: Show live progress on admin pages by polling with Turbo morph refreshes

## Status

Proposed

**Date:** 2026-10-09
**Feature:** 014-admin-catalog-and-jobs

## Context

Spec 014's [PRD](../specs/014-admin-catalog-and-jobs/prd.md) asks the admin catalog page to show a running refresh's stages and percentage, and the art index build's progress, while they run, instead of logs or a status line. The issue (#29) asks for progress "rather than just logs or static status reporting".

What the app has:

- **Progress is already in the database.** `MTG::ArtBuild` records counts and a heartbeat after every batch of 50 artworks; spec 014 adds `stage`, `stage_done` and `stage_total` to `catalog_refresh_runs`, written every few thousand records seen or every few seconds, whichever comes first.
- **Turbo morphing is on app-wide** (`turbo_refreshes_with method: :morph, scroll: :preserve` in the layout), so a refresh of the same page replaces only what changed.
- **Solid Cable is configured but unused.** No view subscribes to a stream and no model broadcasts.
- **Jobs run inside Puma** on SQLite (`SOLID_QUEUE_IN_PUMA`), and restarts interrupt them; the art build can run for hours.
- **Tenancy rules** (`.claude/rules/multi-tenancy.md`) require broadcasts to be on channels namespaced to the account or user; catalog progress is global.
- **Audience:** one or a few admins, occasionally.

## Options considered

### Option A: Polling with Turbo morph refreshes

A small Stimulus controller, rendered only while an operation is queued or running, asks Turbo to refresh the page every ~2 seconds. The server renders the page from the database as on any visit; morphing applies the difference. When nothing is running, the rendered page has no controller, so polling stops by itself.

**Pros:**
- One rendering path: the first visit and every update are the same request, so there's nothing to resync after a restart, a sleep or a missed message.
- No change to jobs; they keep writing progress rows as they do now.
- Simple to test with request specs and one system spec.
- No channel for global data to reason about under the tenancy rules.

**Cons:**
- Updates arrive up to ~2 seconds late.
- One page render every ~2 seconds per open admin tab while something runs (a handful of reads; negligible for a few admins).

### Option B: Turbo Stream broadcasts over Solid Cable

The refresh and the art build broadcast after each progress write; the page subscribes with `turbo_stream_from`.

**Pros:**
- Updates are immediate.
- No requests while nothing changes.

**Cons:**
- The app's first broadcast: new channel, new failure modes, and a decision on how a global admin stream fits the tenancy rule.
- Jobs must throttle broadcasts and render partials outside a request.
- A page that loads between broadcasts, or reconnects after a restart, still needs the polling-style full render to catch up, so B is A plus a second path.
- Each broadcast is another SQLite write (to the cable database) inside the jobs' write loop.

## Decision

**Option A.** Progress already lives in the database, the audience is tiny, and a 2-second delay is invisible against a refresh that takes minutes and a build that takes hours; a single rendering path is what makes the page robust to the restarts self-hosters will have.

## Consequences

- Any admin page showing live progress follows the same pattern: render from the database, include the polling controller only while work is in flight.
- Jobs that want to appear with progress only need to record it (a run row with stage and done/total); they never render or broadcast.
- If many admins or sub-second feedback ever matter, superseding this with broadcasts is additive: the progress rows stay, and a stream replaces the timer.
