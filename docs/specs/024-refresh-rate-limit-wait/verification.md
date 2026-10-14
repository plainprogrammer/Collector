# Verification: Spec 024

**Spec:** [spec.md](spec.md) v1.1.0 · **Plan:** [plan.md](plan.md) · **Date:** 2026-10-14

## Red before the change

With the new examples in place and the app unchanged, the run of `spec/models/catalog/operation/queue_spec.rb spec/jobs/catalog/refresh_job_spec.rb spec/models/catalog/refresh_spec.rb spec/models/catalog/refresh_run_spec.rb spec/models/catalog/refresh_operation_spec.rb spec/models/mtg/art_build_spec.rb spec/models/mtg/art/build_spec.rb spec/models/mtg/art/operation_spec.rb` gave 237 examples, 10 failures (the `.start!` example added after the plan review, the 11th, fails on the unknown `retry_waiting:` keyword). The issue's probe failed for the issue's reason:

```
Catalog::RefreshJob when another refresh for the type waits to run again (issue #78) asks the source nothing, …
  Failure/Error: expect(bulk_data).not_to have_been_requested
    The request GET https://api.scryfall.com/bulk-data was not expected to execute but it executed 2 times
```

and the art build's (`spec/models/mtg/art/build_spec.rb`, "fetches nothing while another build's job waits to run again") failed with the build `finished` instead of `skipped`, and the image requested (re-checked against the pre-change `art_build.rb`).

## Green after

`bin/ci` on the branch rebased onto #84's (`084-plain-failure-messages`, PR #95), at `0df5cee`: every step passed; RSpec 1440 examples, 0 failures, 1 pending. Two of this branch's examples were brought to #84's wording for the summaries, in the commits that added them. Before the rebase, on `main`: Setup, RuboCop, Brakeman, bundler-audit, importmap audit passed; RSpec 1427 examples, 0 failures, 1 pending (the pending one predates this branch).

**With #84.** A skip's message never goes through `Catalog::FailureReason`: the refresh panel passes over a run skipped as `waiting for another job's retry` (`attempted`), a skipped build shows nowhere, and the recent-runs list prints a skip's message as it is, as it does "already running".

## Acceptance criteria

| AC | Evidence |
|----|----------|
| AC-1.1 | `spec/jobs/catalog/refresh_job_spec.rb` (the probe: no request to `/bulk-data`, runs skipped `waiting for another job's retry`, one retry chain); `spec/models/catalog/refresh_spec.rb` "is skipped, asking the source nothing…" |
| AC-1.2 | The probe runs both `scheduled` and `manual`; both skipped |
| AC-1.3 | `refresh_spec.rb`: `source.refreshed` is empty, so `after_refresh` (and the art build it queues) isn't run |
| AC-1.4 | `refresh_spec.rb` "runs while only another type's job waits…" (guard) |
| AC-1.5 | `refresh_spec.rb` "runs when the job held for later is its own" (guard) |
| AC-1.6 | `spec/models/catalog/refresh_operation_spec.rb` "still shows the failed run, queued to retry…"; `refresh_run_spec.rb` `.attempted` |
| AC-1.7 | `refresh_spec.rb` "closes a run left behind before it is skipped…" |
| AC-1.8 | `refresh_spec.rb` "is skipped as already running while a run is running…" (guard) |
| AC-2.1 | `spec/models/mtg/art/build_spec.rb` "fetches nothing while another build's job waits to run again"; `spec/models/mtg/art_build_spec.rb` "is skipped while another build's job waits…" |
| AC-2.2 | `art_build_spec.rb` "runs when the build job held for later is its own" (guard) |
| AC-2.3 | `spec/models/mtg/art/operation_spec.rb` "still says it is queued to retry after another build was skipped for it" |
| AC-3.1 | Read: `app/jobs/catalog/rate_limit_retry.rb` header names the start guard and `Catalog::Operation::Queue#waiting_to_retry?` instead of "nothing here stops that" |
| AC-3.2 | Read: spec 002 v1.4.0, the requirement (line 260), the concurrency bullet (line 255) and both 429 Error Scenarios rows; changelog line added |
| AC-3.3 | Read: CLAUDE.md's admin paragraph, after the art panel's "Queued." sentence. The roadmap's #78 line is marked done once the pull request is open |

Also, at the maintainer's request (2026-10-14): spec 015 v1.3.1, AC-2.16 covers the new skip.

## Core boundary

`spec/admin_catalog_core_spec.rb` passes; the core diff (`queue.rb`, `refresh.rb`, `refresh_run.rb`, `rate_limit_retry.rb`) names no collectible.
