# Implementation Plan: A Second Refresh or Build Waits Out Another's Rate Limit

**Spec:** [spec.md](spec.md) (v1.1.0; approved by the maintainer on 2026-10-14, with rulings on decisions 1 and 2)
**Decisions:** no ADR. Decisions 1 and 2 are the maintainer's rulings; 3 to 6 are the spec's.
**Created:** 2026-10-14
**Issue:** [#78](https://github.com/plainprogrammer/Collector/issues/78)

**How this plan was made.** The whole change was applied to this worktree uncommitted. The new examples were run without the code change (11 failures with Phase 2's added `.start!` example, each for the reason its phase names; the issue's probe failed with "GET https://api.scryfall.com/bulk-data was not expected to execute but it executed 2 times") and with it (`bin/rspec spec/models/catalog spec/jobs spec/models/mtg spec/tasks spec/requests/admin spec/admin_catalog_core_spec.rb`: 623 examples, 0 failures; RuboCop clean). Execution replays it phase by phase, red then green.

## Global Constraints

- `app/models/catalog/` and `app/jobs/catalog/` name no collectible (`spec/admin_catalog_core_spec.rb`).
- The queue is read through `Catalog::Operation::Queue` only, once per start, before the runs (ADR 0014). No new query of Solid Queue's tables.
- `refresh.rb` changes in one place, the `start!` call (lines 20 to 21). Its failure-message line (#84's) and `mtg/art/build.rb` are not touched.
- No migration, gem, setting, view or job change. `Catalog::RefreshJob`, `Catalog::RateLimitRetry`'s code and `MTG::Art::BuildJob` keep their rules (FR-5).
- Examples that need the queue are tagged `:solid_queue` and set it up with `queue_job` / `claim_job` / `fail_job`.
- One Conventional Commit per phase, `git add` and `git commit` as separate commands; each commit passes its files' specs.

## Phase 1: The queue says whether another job waits to run again (FR-1)

**Red.** `spec/models/catalog/operation/queue_spec.rb`, two examples:

1. "knows when a job other than a given one waits to run again (issue #78)": with one `mtg` job queued with `wait: 5.minutes` and one ready, `waiting_to_retry?` is true, true with `except: "another-job"`, false with `except:` the waiting job's `active_job_id`; a queue for `"other"` isn't waiting.
2. "doesn't count a ready job, a held one or a failed one": ready, claimed and failed jobs only, so `waiting_to_retry?` is false.

**Green.** `Catalog::Operation::Queue`:

```ruby
  # True when an unfinished job other than the one with this Active Job id waits for a later time: a retry backing off
  # (issue #78). The job retrying will do the work, so another one starting meanwhile leaves it alone.
  def waiting_to_retry?(except: nil) = in_flight.any? { |job| job.scheduled? && job.active_job_id != except }
```

**Commit:** `feat(catalog): say whether another job waits in the queue to run again`.

## Phase 2: A refresh is skipped while another's retry waits (Story 1, FR-2, FR-3)

**Red.**
- `spec/jobs/catalog/refresh_job_spec.rb`, context "when another refresh for the type waits to run again (issue #78)", `:solid_queue` (the issue's probe, AC-1.1, AC-1.2): a refresh job for `mtg` queued with `wait: 10.minutes`; `/bulk-data` stubbed to answer 429 with `Retry-After: 600`; `perform_now("mtg", "scheduled")` and `perform_now("mtg", "manual")`. Expect the stub not requested, two runs `skipped` with `waiting for another job's retry` (one per trigger), and one unfinished refresh job in the queue (one retry chain).
- `spec/models/catalog/refresh_spec.rb`, under "the job running it", with `FakeCatalogSource`:
  - skipped while another `fake` job waits, with `languages_result` set to an error so asking the source would raise; no download, `after_refresh` not called (AC-1.1, AC-1.3);
  - applied when only an `other` job waits (AC-1.4; a guard, passes before the change);
  - applied when the waiting job is its own (`job_id:` the queued job's `active_job_id`, AC-1.5; a guard, passes before);
  - a stalled running run closed as `interrupted`, then skipped for the waiting retry (AC-1.7);
  - a running run with a claimed job plus a waiting retry gives `already running` (AC-1.8; a guard, passes before).
- `spec/models/catalog/refresh_run_spec.rb`, `.start!`: with `retry_waiting: true` and no run running, the new run is skipped with `waiting for another job's retry`; with it false, running.
- `spec/models/catalog/refresh_run_spec.rb`, `.attempted`: also leaves out a run skipped with `waiting for another job's retry`.
- `spec/models/catalog/refresh_operation_spec.rb`: a failed run, its job queued with `wait: 3.minutes`, and a later skipped `waiting for another job's retry` run: state `:queued`, summary "Queued to retry. The last run failed while downloading: …" (AC-1.6).

**Green.**
- `Catalog::RefreshRun`: `WAITING_FOR_RETRY = "waiting for another job's retry".freeze` beside `ALREADY_RUNNING`, with a comment; `attempted` becomes `where.not(status: :skipped, message: [ ALREADY_RUNNING, WAITING_FOR_RETRY ])`; `start!` takes `retry_waiting: false` and, after closing left-behind runs:

  ```ruby
  skip = (ALREADY_RUNNING if runs.running.exists?) || (WAITING_FOR_RETRY if retry_waiting)
  now = Time.current
  run = create!(collectible_type:, trigger:, job_id:, status: :running, started_at: now, heartbeat_at: now)
  run.finish!(:skipped, message: skip) if skip
  ```

  Its comment gains: "With none running, so does another job for the type waiting in the queue to run again (retry_waiting, issue #78)."
- `Catalog::Refresh#call`: the `start!` call passes `retry_waiting: job_queue.waiting_to_retry?(except: @job_id)`. Nothing else in the file.

**Commit:** `fix(catalog): skip a refresh while another for its type waits to retry`.

## Phase 3: An art build is skipped while another's retry waits (Story 2, FR-4)

**Red.**
- `spec/models/mtg/art/build_spec.rb` (AC-2.1, the probe for the build): a build job queued with `wait: 10.minutes`, its build failed; one printing and its image stubbed; `run_build(job_id: "job-2")` is `skipped` with `waiting for another job's retry` and the image isn't requested.
- `spec/models/mtg/art_build_spec.rb`: `start!` skipped with that message while another build job waits and no build runs, the failed build left as it was; running when the waiting job is its own (AC-2.2; a guard, passes before).
- `spec/models/mtg/art/operation_spec.rb`, in "when a rate-limited build's job waits to run again": a second `start!` (`job-b`) is skipped and the summary is still "Queued to retry. The last build failed: …" (AC-2.3).

**Green.** `MTG::ArtBuild`: `WAITING_FOR_RETRY = "waiting for another job's retry".freeze`; in `start!`, with the queue it already reads:

```ruby
skip = ("already running" if running.exists?) || (WAITING_FOR_RETRY if queue.waiting_to_retry?(except: job_id))
…
run.finish!(:skipped, message: skip) if skip
```

The header comment gains the sentence on the skip. `MTG::Art::BuildJob` is unchanged.

**Commit:** `fix(mtg): skip an art build while another build waits to retry`.

## Phase 4: The documents (Story 3)

- `app/jobs/catalog/rate_limit_retry.rb` header: "That holds for this job only. … nothing here stops that." becomes "While its retry waits it holds no concurrency lock, so another job of its class (the schedule's, or one started by hand) can be queued meanwhile; the operation's start guard skips that one while this one waits (`Catalog::Operation::Queue#waiting_to_retry?`, issue #78)." This core file names no collectible's class.
- Spec 002: header to `**Version:** 1.4.0` and Last Updated 2026-10-14, with a changelog line. In the requirement at line 260, "It holds for the waiting job only: no lock is held while it waits, so a refresh the schedule or an operator starts meanwhile asks the source at once." is replaced by "It holds for every refresh of the type: no lock is held while the job waits, so one the schedule or an operator starts meanwhile is skipped (\"waiting for another job's retry\") and asks the source nothing (issue #78, spec 024)." The concurrency bullet at line 255 names the new skip beside "already running". The two Error Scenarios rows' parentheses (lines 347, 348) become "(a refresh started meanwhile is skipped, spec 024)".
- `CLAUDE.md`, "Admin catalog and jobs": after the `Catalog::RateLimitRetry` sentence, add "A refresh or art build that starts while another job of the same operation waits in the queue to run again is skipped (`waiting for another job's retry`, `Catalog::Operation::Queue#waiting_to_retry?`, issue #78), manual or scheduled."

**Commit:** `docs: say a refresh or build waits out another's rate limit`.

Spec 015's AC-2.16 ("the most recent run that wasn't skipped as already running") is now incomplete; spec 015 is outside this branch's documents, so the pull request notes it for the maintainer rather than editing it.

## Phase 5: Verification

- `bin/ci` green.
- `verification.md`: each AC with its example or, for AC-3.x, what was read; the red run before Phase 2 and Phase 3 quoted.
- After the maintainer allows the push and the draft PR is open: the roadmap's #78 line gets "**Done 2026-10-14:** spec 024, PR #N" (merging marks it done, AC-3.3), as one more commit.

**Commit:** `docs(specs): record spec 024's verification`.

## Interactions (spec, "Interactions for the maintainer")

#77's "start fresh while waiting" will be skipped by this guard unless it first discards or runs the waiting job. #84 touches other lines of `refresh.rb` and `build.rb`; if it changes the `start!` call's neighbourhood, the merge is textual. #86 is untouched.
