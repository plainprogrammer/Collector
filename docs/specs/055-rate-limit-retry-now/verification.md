# Verification: Spec 055, Retry Now for a Job Waiting to Retry

Spec: [spec.md](spec.md) v1.0.0. Plan: [plan.md](plan.md). Issue [#77](https://github.com/plainprogrammer/Collector/issues/77).

Each line names the example that proves the criterion, or says "by reading" with what was read. Examples are in the file named; counts are from `bin/rspec --dry-run` and the targeted runs of 2026-11-09 (0 failures each).

## Examples by file

| File | Examples |
|---|---|
| `spec/models/catalog/operation/queue_spec.rb` | 23 (10 new, `#run_now`) |
| `spec/models/catalog/refresh_operation_spec.rb` | 60 |
| `spec/models/mtg/art/operation_spec.rb` | 76 |
| `spec/requests/admin/catalogs/operation_retries_spec.rb` | 14 (new file) |
| `spec/requests/admin/catalogs_spec.rb` | 47 |
| `spec/jobs/catalog/refresh_job_spec.rb`, `spec/jobs/mtg/art/build_job_spec.rb` | 24, 13 |
| `spec/system/admin_catalog_spec.rb` | 5 |
| `spec/system/narrow_admin_pages_spec.rb` | 3 |
| `spec/admin_catalog_core_spec.rb` | 2 (file count 15 → 16) |

## Story 1: offered while a retry waits

- AC-1.1: `operation_retries_spec.rb` "shows an enabled Retry now beside the disabled start button of a waiting refresh"; model level in `refresh_operation_spec.rb` "offers it, and runs that job at once…".
- AC-1.2: `operation_retries_spec.rb` "shows it on a waiting art index build too"; `art/operation_spec.rb` "offers Retry now, and runs the waiting job at once…".
- AC-1.3 (a)–(i): the table of examples "doesn't offer it for …" in `refresh_operation_spec.rb`; AC-1.3a: the same table in `art/operation_spec.rb` plus "offers no Retry now, whatever waits" (art matching off). `operation_retries_spec.rb` "shows none when nothing waits to retry".
- AC-1.4, AC-1.7: `refresh_operation_spec.rb` "shows the run's own job's time and moves only that job when another is scheduled sooner".
- AC-1.5: `refresh_operation_spec.rb` "offers it for any retry of that job, not only a rate limit's" and `art/operation_spec.rb` "offers it for the busy-database retry too" (maintainer ruling 2026-11-09).
- AC-1.6: `refresh_operation_spec.rb` "shows a failed run beside only a hand-scheduled job as plain queued…" (fails before the change: "Queued to retry." with the failed run's stages).

## Story 2: pressing it runs the waiting job

- AC-2.1, AC-2.8: `operation_retries_spec.rb` "runs the waiting refresh job at once, without queueing another or writing a run" (no job row, no run row, `303`, "Retrying now."); WebMock blocks real HTTP in every request spec, so a source call would fail the example.
- AC-2.2: `operation_retries_spec.rb` "runs the waiting art build job at once".
- AC-2.3, AC-5.3: `operation_retries_spec.rb` "then reads Queued., with no Retry now, the start button disabled, and the page polling".
- AC-2.4: `refresh_job_spec.rb` and `build_job_spec.rb` "when Retry now has moved its waiting retry": the retry record counts 1 before and after the press, and 2 after the next rate limit with no progress. The "made progress, so it starts again at 1" half is not re-tested: the press leaves the retry record alone, and spec 043's example "starts the count again after an attempt that wrote rows" in `refresh_job_spec.rb` proves the rule.
- AC-2.5: refresh: the same `refresh_job_spec.rb` example asserts a second run is recorded under the same job id (both failed). Art: `art/operation_spec.rb` "opens a new run when the retry starts, leaving the failed one as it ended" calls `MTG::ArtBuild.start!` under the job's id; the moved art job is not run end to end (the build job example stubs `MTG::Art::Build.new`).
- AC-2.6: `refresh_operation_spec.rb` (same example as AC-1.4) and `operation_retries_spec.rb` "moves only the operation's own run's job, whatever else the request carries".
- AC-2.7: `queue_spec.rb` "blocks a refresh behind another refresh of the type that holds its lock, and runs it when that one ends".

## Story 3: races and repeats

- AC-3.1: `operation_retries_spec.rb` "says nothing is waiting, and changes nothing, on a second press"; `queue_spec.rb` "moves it once: a second call changes nothing".
- AC-3.2, AC-3.4 (press first): `queue_spec.rb` "moves a retry that is due but not yet dispatched, and the dispatcher then finds nothing". AC-3.4 (dispatcher first): "does nothing when the dispatcher got there first".
- AC-3.3: `queue_spec.rb` "does nothing for a job that isn't waiting for a later time" (ready, claimed, finished, failed, unknown id); `operation_retries_spec.rb` "…claimed since the page was shown".
- AC-3.5: `refresh_operation_spec.rb` "does nothing, and says so, when the job was moved after the operation read the queue" (the stale operation; the move re-reads). The spec's seam "between the re-read and the move" cannot be interposed without stubbing the object under test; the delete-first row count in `Catalog::Operation::Queue#run_now` is what serialises it (see "By reading").
- AC-3.6: `queue_spec.rb` "moves the scheduled row of a refresh retry whose old attempt is still claimed, to a blocked entry". AC-3.7: "…an art build retry whose old attempt is still claimed, to a ready entry".
- Rollback: `queue_spec.rb` "puts the entry back when the dispatch fails, so nothing is lost".

## Story 4: admins only

- AC-4.1: `operation_retries_spec.rb` "is invisible to a member". AC-4.2: "sends a visitor who isn't signed in to sign in". AC-4.3: "answers 404 for an unknown type or operation". AC-4.4: "moves only the operation's own run's job, whatever else the request carries". Art matching off: "offers no button and moves nothing for an art build while art matching is off".
- AC-4.5: by reading. `ApplicationController` inherits Rails' forgery protection (on by default, `protect_from_forgery` through `ActionController::Base`; no `skip_forgery_protection` in the new controller), and `button_to` posts the page's token.

## Story 5: the button in the page

- AC-5.1: `spec/system/admin_catalog_spec.rb` "runs a refresh that waits to retry at once, and the button goes".
- AC-5.2: `spec/system/narrow_admin_pages_spec.rb` "keeps Retry now beside the start button, reachable and fitting, at 360px and 375px" (no sideways scroll, both buttons by name); screenshots at 390px light and dark in [screenshots/](screenshots/). At 390px "Refresh now" and "Retry now" sit beside the title; the Art index's longer title wraps the two buttons together onto the line below it. The wrapper wraps as a unit by design (`flex-wrap`).

## Story 6: documents (by reading)

- AC-6.1: `docs/architecture/catalog-operations.md` read after the edit: the rate-limited-job section, the two panel tables (own-job rows, the new "only another job scheduled" row), the Invariants bullet, the glossary, the #77 line, Covers, Sources. The distillation-log row is added by `distill-feature`.
- AC-6.2: `docs/design-system/components/AdminCatalog.md`: the markup sample and the "one start button, plus Retry now" bullet. No preview file shows the waiting state (`grep -ln "Queued to retry\|c-operation__start" docs/design-system/previews/*.html`: none).
- AC-6.3: `docs/specs/README.md` has the 055 row and the three Superseded-by entries (done with the spec); `docs/roadmap.md` line 82, `docs/architecture/catalog-core.md` lines 205 and 217 and CLAUDE.md's "Admin catalog and jobs" bullet updated.
- AC-6.4: `spec/admin_catalog_core_spec.rb` passes with the count at 16; the new controller, the view and the new `Catalog::Operation` code contain no collectible's name.

## By reading

- **`run_now`'s transaction (FR-2).** `Catalog::Operation::Queue#run_now` opens `SolidQueue::Record.transaction(requires_new: true)`, the queue's own connection; the test environment keeps the queue tables in the primary database, so no example can tell that connection from `ActiveRecord::Base`'s. The scheduled entry is removed first, and the dispatch happens only when exactly one row went (`delete_all == 1`); SQLite's IMMEDIATE write transactions serialise two such transactions, and the queue's own dispatcher does the same inside its transaction (`ScheduledExecution.dispatch_next_batch`).
- **No threaded race example.** Two simultaneous requests are not run on threads; the dispatcher-first, press-first, repeated and stale orders above are the examples of it.

## Deviations from the plan, and accepted edges

- **`retry_job_id` checks `unavailable_reason` first** (before reading the candidate record), not last as plan Task 2.5 has it: with art matching off the build operation has no start label, so the view's `operation.retry_now?` ran for it, and reading the latest build and the queue added queries to a page that must make the same queries however many runs and jobs exist (`catalogs_spec.rb` "runs the same queries however many runs and jobs there are"). Found by that example in Phase 3 (`a8b7679c`).
- **A failed build whose job waits, with no applied refresh** (barely reachable): `retrying?` goes through `unavailable_reason`, so the panel reads "Queued." with no button instead of "Queued to retry." (the art operation's `unavailable_reason` is "Refresh the catalog first…" then). Accepted.
- **"Before" screenshots** are the same page with the "Retry now" form hidden by an appended `<style>`, since nothing of the old code can be loaded in this worktree. The data is factory data (the catalog shows 0 cards; no printings are shown).

## Implementation review

(Task 5.7.)
