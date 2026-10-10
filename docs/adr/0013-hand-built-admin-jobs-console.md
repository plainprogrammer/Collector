# 0013: Hand-build the admin jobs console on Solid Queue's models

## Status

Accepted (2026-10-09, approved with spec 014's PRD)

**Date:** 2026-10-09
**Feature:** 014-admin-catalog-and-jobs

## Context

Spec 014's [PRD](../specs/014-admin-catalog-and-jobs/prd.md) gives admins a jobs page next to the catalog page: queued, running, scheduled and failed jobs, the error and backtrace of a failed job, and **retry and discard** for failed jobs. The maintainer ruled out pausing queues and running recurring tasks on demand, and "retry all" for now. The page is expected to grow with more catalog types and job types.

Constraints that bear on it:

- **The design system.** `CLAUDE.md` requires every view to use the Collector design system (`docs/design-system/`, `c-*` classes and tokens only).
- **Few dependencies.** `.claude/rules/conventions.md`: no gem for what Rails or an existing dependency already does.
- **Solid Queue 1.7.0 already exposes what's needed.** `SolidQueue::Job#retry` (through its failed execution), `SolidQueue::Job#discard`, `SolidQueue::FailedExecution` holding the exception and backtrace, and scopes for ready, scheduled, claimed and failed executions.
- **Self-hosters.** Production runs Solid Queue inside Puma on SQLite; the page must add no service or Node toolchain.

## Options considered

### Option A: Hand-built pages on Solid Queue's models

`Admin::JobsController#index/show` reads `SolidQueue::Job` and its executions; `Admin::Jobs::RetriesController#create` and `Admin::Jobs::DiscardsController#new/create` call `retry` and `discard`.

**Pros:**
- Uses the design system's existing patterns: filter chips, the row menu from `/admin/users`, the confirm page.
- Only the actions the maintainer chose; nothing to hide or strip.
- No new gem; the code is a few small controllers and a query object.
- Behind the existing `AdminOnly` concern and tested like every other admin page.

**Cons:**
- We maintain it. A Solid Queue upgrade that changes its models can break the page (its models are public API, but not a frozen one).
- No filtering by queue or class, search, or bulk actions until we add them.

### Option B: Mount Mission Control – Jobs

The `mission_control-jobs` gem (Rails team, MIT), mounted at `/admin/jobs` with `base_controller_class` set to an admin controller.

**Pros:**
- Retry, discard, backtraces, filtering and bulk actions with no code of ours.
- Maintained upstream, alongside Solid Queue.

**Cons:**
- Its own UI and assets, outside the Collector design system, which `CLAUDE.md` forbids.
- Brings queue pausing and recurring-task controls the maintainer excluded; they can't be switched off without overriding its views or routes.
- One more gem, with its own importmap pins and stylesheet, for every self-hoster to receive and every Dependabot cycle to update.

## Decision

**Option A.** The design-system rule and the maintainer's scope (read plus retry and discard, nothing more) both point to it, and Solid Queue already supplies the operations; the page only presents them.

## Consequences

- The jobs page looks and behaves like the rest of the admin area, and its scope is exactly what was approved.
- Each Solid Queue upgrade should run the jobs page's request specs (they run in `bin/ci` anyway); a breaking change in its models shows up there.
- Adding bulk actions, filters or queue controls later is our work. If the console's scope grows to roughly Mission Control's, revisit this ADR rather than reimplementing it.
