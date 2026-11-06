# Verification: Feature 043, Rate-Limit Retries Count Only Without Progress

**Spec:** [spec.md](spec.md) v1.0.0 · **Plan:** [plan.md](plan.md) · **Issue:** [#86](https://github.com/plainprogrammer/Collector/issues/86)

## Red evidence

Run evidence is taken from the commit bodies of each task.

| Task | Commit | Command and red run (before the code change) | Green |
|---|---|---|---|
| 1. The core asks the job whether its attempt made progress | `e69075f` | `spec/jobs/catalog/rate_limit_retry_spec.rb`: 12 examples, 2 failures (AC-1.1 and AC-1.5: `RateLimitedError` raised instead of a retry being enqueued). The other 10 examples pin today's behaviour (wait floor, no-progress count, failure from 3, over-an-hour wait, silent job): guards, green when written | `spec/rate_limit_retry_core_spec.rb` and `spec/jobs/catalog/rate_limit_retry_spec.rb`: 14 examples, 0 failures (re-run after Task 7's comments) |
| 2. The rule's source names nothing | `10f8e6c` | A guard, green when written: the rule's file already named nothing. One-off proof it can fail: a `# scryfall` comment as line 1 of the rule's file turned the second example red (2 examples, 1 failure); reverting gave 2 examples, 0 failures | 2 examples, 0 failures |
| 3. A refresh says whether its attempt wrote a catalog row | `239a3cc` | `bin/rspec spec/models/catalog/refresh_spec.rb -e made_progress`: 11 examples, 11 failures (`NoMethodError: undefined method 'made_progress?' for an instance of Catalog::Refresh`) | `refresh_spec`, `refresh_scryfall_spec`, `refresh_operation_spec`: 102 examples, 0 failures |
| 4. The refresh job answers from its attempt | `1ba9069` | `bin/rspec spec/jobs/catalog/refresh_job_spec.rb -e "kept only without progress"`: 4 examples, 1 failure (AC-3.3/3.4: `RateLimitedError` raised from the first `perform_now`, the count 3 being at the limit). AC-3.1, AC-3.2 and the reset example passed before the answer existed: guards, written green | `refresh_job_spec` and `rate_limit_retry_spec`: 35 examples, 0 failures; every non-system spec file referencing `Catalog::Refresh` or `Catalog::RefreshJob`: 288 examples, 0 failures |
| 4a. Reset example (refresh job) | `1ba9069` | With the `@refresh = nil` line removed, "doesn't carry one attempt's progress into the next on the same job instance": 1 example, 1 failure (expected: 2, got: 1, at `refresh_job_spec.rb:112`). Line restored | green again |
| 5. An art build says whether its attempt made progress | `6be65bd` | `bin/rspec spec/models/mtg/art/build_spec.rb -e made_progress`: 6 examples, 6 failures (`NoMethodError: undefined method 'made_progress?' for an instance of MTG::Art::Build`). The AC-2.4 and "before it has run" examples are guards, green when written | `build_spec.rb`: 28 examples, 0 failures |
| 6. The build job answers from its attempt | `f4d5167` | `bin/rspec spec/jobs/mtg/art/build_job_spec.rb -e AC-2.5 -e AC-2.4 -e "carry one attempt"`: 3 examples, 1 failure (AC-2.5 raised `RateLimitedError`, `GET .../d.jpg` returned 429, on the third queued re-execution: the old count reaches 3 and the next rate limit fails). AC-2.4 and the reset example passed before the answer existed: guards | `build_job_spec`, `build_spec`, `rate_limit_retry_spec`: 52 examples, 0 failures |
| 6a. Reset example (build job) | `f4d5167` | With the `@build = nil` line removed, `-e "carry one attempt"`: 1 example, 1 failure ("expected: 2, got: 1"). Line restored | `build_job_spec`: 12 examples, 0 failures |
| 7. The comments say the new count | `1150f28` | Comments only; no example. The guards of Tasks 1 and 2 re-run after the edit | `rate_limit_retry_core_spec`, `jobs/catalog/rate_limit_retry_spec`, `jobs/mtg/art/build_job_spec`: 26 examples, 0 failures; RuboCop: 2 files, no offenses |
| 8, 9. Documents | `b2789f9`, `b4edb15` | Verified by reading (below) | |

## Acceptance criteria

| AC | Evidence |
|---|---|
| AC-1.1 to AC-1.6 | `spec/jobs/catalog/rate_limit_retry_spec.rb` |
| AC-2.1 to AC-2.4 (model), AC-2.6 | `spec/models/mtg/art/build_spec.rb` |
| AC-2.4 (job), AC-2.5 | `spec/jobs/mtg/art/build_job_spec.rb` |
| AC-3.3 (model) | `spec/models/catalog/refresh_spec.rb` |
| AC-3.1, AC-3.2, AC-3.3 (job), AC-3.4 | `spec/jobs/catalog/refresh_job_spec.rb` |
| AC-4.1 | `spec/rate_limit_retry_core_spec.rb` |
| AC-5.1 | Verified by reading `docs/architecture/catalog-operations.md`: "A rate-limited job" step 2 and its progress paragraph; the `MAX_RETRIES` row; the `IMAGE_HOSTS` row and the refresh bullet in "What the source does for a refresh"; #86 absent from "Accepted limits and open issues" and in Sources among the closed issues; "fourth" always followed by "in a row with no progress between them"; no "over the job's life" left. Result: met (read 2026-11-06 at the review fixes' commit; lines 98, 127, 132–134, 163, 168, 189, 191–200, 212; the 2026-10-15 log row keeps its history) |
| AC-5.2 | Verified by reading the header and `COUNTED_AS` comments of `app/jobs/catalog/rate_limit_retry.rb` and the header of `app/jobs/mtg/art/build_job.rb`. Result: met (`rate_limit_retry.rb` lines 15–20 and the `COUNTED_AS` comment; `build_job.rb` lines 8–10) |
| AC-5.3 | Verified by reading `docs/specs/README.md`: row 043's Supersedes cell, and the 002, 011 and 024 rows naming 043 among what supersedes them; row 043's Plan cell reads "present". Result: met |

## Final `bin/ci`

Passed at `d27273d` on 2026-11-06 (4m52s): setup, the released-migrations guard, RuboCop, Brakeman, bundler-audit, importmap audit, and RSpec with 2641 examples, 0 failures, 1 pending (seed 56322).

## Deviations from the plan

- Task 1: the no-progress example uses `probe(count, false)`; the plan's draft read `probe(before, false)`, and `before` is not a variable there (commit `e69075f`).
- Task 9 (`docs/specs/README.md`): rows 002, 011, 024 and 043's Supersedes cell already carried the 043 clauses; only row 043's Plan cell changed.

## Implementation review

SPEC-ALIGNED (sdd-review Mode B, Opus, read-only, 2026-11-06, at `d62dcb2`).

No blocking or major findings. Six minor:

1. `verification.md` unfinished (AC-5.x results, final `bin/ci`, this heading): fixed in `9581c71` and here; `bin/ci` is recorded above.
2. Refresh progress set only after every retired slice: rejected. A rate limit can't follow `retire_unseen`, which asks the source nothing, so the answer never reaches the count; the change would be untested code.
3. The area doc's "a batch of `BATCH` fingerprints": fixed to "up to `BATCH` at a time" (`9581c71`).
4. The area doc's Sources line for spec 043: now cites the Problem Statement and Stories 1 to 4 (`9581c71`).
5. No Distillation log row for spec 043: left to `distill-feature`, which writes it before the merge.
6. The `COUNTED_AS` comment's line length: wrapped (`9581c71`).

AC-5.1, AC-5.2 and AC-5.3: met by the reviewer's reading and the supervisor's (table above).

## Distillation

Distilled 2026-11-06 into [`catalog-operations.md`](../../architecture/catalog-operations.md) (whole spec): "A rate-limited job" step 2 and its progress paragraph, the art build's "Ends:" bullet, the image origins' bullet in "What the source does for a refresh", the `MAX_RETRIES` and `IMAGE_HOSTS` rows, the decision that progress is judged on the attempt alone, #86 out of the open issues and into Sources, and a Distillation log row (`3ad5bac`). Index row: Frozen, Plan "retirement owed"; the spec's frozen line (`spec 027 D4` commit). CLAUDE.md already points to the area doc for rate-limit retries; unchanged. No ADR proposed: the rule's weight sits in the spec and the area doc.
