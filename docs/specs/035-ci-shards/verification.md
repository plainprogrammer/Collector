# Verification: `bin/ci` Groups, GitHub's RSpec Shards and a Documentation-Only Pre-Push Path (spec 035)

**Spec:** [spec.md](spec.md) 1.0.0 · **Plan:** [plan.md](plan.md) · **Branch:** `035-ci-shards` · **PR:** [#149](https://github.com/plainprogrammer/Collector/pull/149) · **Issue:** [#145](https://github.com/plainprogrammer/Collector/issues/145)

Executed 2026-10-31 to 2026-11-01 in a cloud session, one implementer subagent per phase (Phases 1–5) and Phase 6 in the main session. Unless noted, local runs were on this branch, one at a time.

**Commit IDs before the rebase:** the branch was rebased onto `main` on 2026-11-01 to bring in #151. The runs and evidence below that name an earlier commit name it as it was then; GitHub's runs keep those IDs. In `main`'s history the same commits are:

| Before | In `main` | Commit |
|---|---|---|
| `7aff25a` | `3791189` | feat(ci): parse bin/ci groups and form spec shards |
| `4e45550` | `50c19f5` | feat(ci): bin/ci runs a group or a shard and prints the slowest examples |
| `9d5bed1` | `2cc50ce` | chore(ci): record the spec run-time log |
| `e94ae42` | `eb7b1cd` | chore(claude): allow bin/ci with a group argument |
| `8f5aa02` | `011659a` | chore(image): keep the CI tooling out of the image |
| `769915e` | `cd27d48` | ci: run bin/ci checks and the RSpec shards in parallel |
| `c1f3f37` | `8f3ce87` | feat(hooks): classify a branch's changes and push command |
| `f3bc962` | `8288236` | feat(hooks): skip RSpec before a documentation-only push |
| `db8d609` | `7efe8a7` | feat(hooks): run the Ruby pre-push hook from settings |
| `6412bc2` | `db40d59` | fix(hooks): read the tool call as UTF-8 in the pre-push hook |
| `59eea89` | `a936950` | docs: CI groups and shards in the area doc, CLAUDE.md and the roadmap |

## Rulings

**By the maintainer, during execution:**
- Both `.claude/settings.json` edits approved: the allow entry (step 2.3) and the hook command (step 4.4). The auto-mode check had refused them as self-modification.
- The `.github/workflows/ci.yml` edit approved: Phase 3, then Phase 6's temporary matrix change.
- The branch was rebased onto `main` and force-pushed with lease, to bring in #151's fix for the order-dependent `spec/system/number_entry_spec.rb:56` failure. That failure had blocked a push at seed 22126.
- The M = 3 trial and the AC-2.2 probe approved. This session's GitHub access can't re-run runs (403 "Resource not accessible by integration").
- #149 merged on 2026-11-01 at 04:55, with the trial's three-shard matrix, before this file, the implementation review and the distillation. The maintainer chose a follow-up pull request on `035-ci-shards`, restarted from `main`. It carries the stop rule's matrix, this file, the review and the distillation, and it counts `main`'s merge run as the third M = 3 measurement.

**Deviations from the plan's drafts, each recorded in its commit body:**
- **Phase 1:** the shard spec uses `let(:scratch)` with an `after` cleanup, instead of an instance variable (RuboCop RSpec/InstanceVariable).
- **Phase 2:**
  - `script/ci/record_runtime_log` also caught RSpec's "Run options" line. It now writes to a temporary file and keeps only `path:seconds` lines, sorted by path. It keeps the log when examples fail and exits with RSpec's status.
  - `spec/config/ci_definition_spec.rb` takes `type: :config`, like `spec/config/recurring_spec.rb`.
- **Phase 3:**
  - `lib/collector/push_scope.rb` went into `.dockerignore` and `bin/image-smoke` one phase early.
  - The permissions example compares `key?("permissions")` with `false` for each job, so a missing job fails it.
  - The AC-2.1 example accepts any contiguous `1..N` matrix with N ≥ 2.
- **Phase 4:**
  - A trailing `| tail -N` / `| head -N` is stripped before a trailing `2>&1`.
  - `||` and `;` are refused before the "more than one push" check, so the reason names the operator.
  - `changed_paths` checks for a detached `HEAD` and a missing `origin/main` itself, so each reason names its case.
  - `decide` falls back to the full `bin/ci` on any `StandardError`.
  - Two helpers were added: `current_branch` and `push?`.
  - An unresolvable `cd` or `-C` directory is treated like today's hook: not this project's repository, so the hook skips `bin/ci`.
- **After Phase 4 (`fix(hooks)`):**
  - **The bug:** in this session's C locale, the hook read the tool call's JSON as US-ASCII. A Bash call with a non-ASCII character and the word "push" crashed it, and its fail-closed rescue blocked a command that wasn't a push.
  - **The fix:** the script forces UTF-8.
  - **The proof:** an example runs the script under `LANG=C`. It failed first, then passed.
- **Output redirection narrower than decision 3:** only a trailing `2>&1` and a trailing `| tail -N` or `| head -N` are stripped. A push with `> file` or `>/dev/null 2>&1` is refused and runs the full `bin/ci`. That fails safe; widening it isn't worth the parsing (implementation review, item 4).
- **AC-1.4's command:** the replay prints `CI=true bin/rspec --seed S --profile 10 <files>`. Decision 8 adds `--profile 10` to every RSpec run. The files, their order, the seed and `CI` are as AC-1.4 says.

## Evidence

### Story 1: `bin/ci` runs a group

Phase 2's runs, each alone, on `9d5bed1` (before step 2.3; the AC-1.8 example was then the one expected failure):

| Criterion | Proved by |
|---|---|
| AC-1.1, AC-1.9 | `bin/ci` ran Setup, the upgrade guard, Style: Ruby, Brakeman, Gem audit, Importmap audit and Tests: RSpec, in that order. RSpec ran as `bin/rspec --profile 10` with RSpec's own seed, the whole suite in one process. The output printed "Top 10 slowest examples (113.62 seconds, 21.3% of total time)". Every later pre-push run did the same: 2,375 → 2,405 examples, 0 failures. |
| AC-1.2 | `bin/ci checks`: the six non-RSpec steps passed in 24.86 s, with no RSpec step. |
| AC-1.3, AC-1.9 | `bin/ci rspec`: Setup, then `bin/rspec --profile 10` on the whole suite, with the top-10 list. No other check ran. |
| AC-1.4, AC-1.9 | `bin/ci rspec 2/4` printed `Shard 2/4: 57 files, grouped by runtime, seed 21835` and `Replay: CI=true bin/rspec --seed 21835 --profile 10 spec/admin_catalog_core_spec.rb …` before the CI banner. It ran 705 examples (0 failures), with the top-10 list. |
| AC-1.5 | `spec/lib/collector/ci_shard_spec.rb`: for M = 2, 3 and 4, every spec file appears once. This holds with a fixture log (one deleted path, one real file missing), with no log (`:filesize`), and with the committed log (M = 4). |
| AC-1.6 | `bin/ci rspec 5/4`, `bin/ci rspec 0/4` and `bin/ci lint` each exited 1 with no step run, printing `Unknown CI group "…". Accepted: bin/ci, bin/ci checks, bin/ci rspec, bin/ci rspec N/M (1 <= N <= M)`. `spec/lib/collector/ci_groups_spec.rb` covers the other refusals (`1/0`, `a/b`, `checks 1/2`, `rspec 1/2 x`). |
| AC-1.7, AC-1.9 | A scratch edit, reverted and never committed, failed `spec/config/recurring_spec.rb:5`. `bin/ci rspec 2/4` exited 1. It printed the top-10 list and then "❌ Tests: RSpec failed" and "❌ Continuous Integration failed". |
| AC-1.8 | `spec/config/ci_definition_spec.rb`, "lets a session run bin/ci and its groups". It was red until `e94ae42` added `Bash(bin/ci *)`, then green. |
| AC-1.9 | `spec/config/ci_definition_spec.rb`, "prints the 10 slowest examples": every `bin/rspec` command in `config/ci.rb` carries `--profile 10`. Exit statuses are unaffected (AC-1.2 and AC-1.7 runs). |

### Story 2: GitHub runs the groups in parallel

**The metric (AC-2.4):** each attempt's `run_started_at` (`GET …/actions/runs/<id>/attempts/<n>`) to its `ci` job's `completed_at` (`…/attempts/<n>/jobs`).

**AC-2.4 baseline:** three green `main` runs of the old single-job workflow, after #147 and #148 merged.

| Run | Commit | Start → `ci` done | Time |
|---|---|---|---|
| [41227871780](https://github.com/plainprogrammer/Collector/actions/runs/41227871780) (#147 merge) | `4494c62` | 18:07:50 → 18:12:42 | 292 s |
| [41228080499](https://github.com/plainprogrammer/Collector/actions/runs/41228080499) (#148 merge) | `29a1138` | 18:10:23 → 18:16:11 | 348 s |
| [41245494315](https://github.com/plainprogrammer/Collector/actions/runs/41245494315) (#151 merge) | `6238217` | 21:51:04 → 21:56:57 | 353 s |

Median: **348 s**.

**M = 4 on #149 (AC-2.4, AC-2.5):**

| Run | Commit | Start → `ci` done | Time | `checks`; shards (job start → end) |
|---|---|---|---|---|
| [41245533672](https://github.com/plainprogrammer/Collector/actions/runs/41245533672) | `769915e` | 21:51:37 → 21:53:55 | 138 s | 36 s; 2:10, 1:45, 1:59, 1:50 |
| [41250006387](https://github.com/plainprogrammer/Collector/actions/runs/41250006387) | `db8d609` | 22:51:10 → 22:53:30 | 140 s | 32 s; 2:13, 2:00, 2:07, 2:05 |
| [41259053498](https://github.com/plainprogrammer/Collector/actions/runs/41259053498) | `a936950` | 00:58:01 → 01:00:58 | 177 s | 31 s; 2:18, 2:24, 2:41, 2:47 |

Median: **140 s**, against the baseline's 348 s, so AC-2.4 holds.

**M = 3 on #149 (AC-2.5), from temporary commit `3251b5c`:**

| Run | Commit | Start → `ci` done | Time | `checks`; shards |
|---|---|---|---|---|
| [41265934051](https://github.com/plainprogrammer/Collector/actions/runs/41265934051) attempt 1 | `3251b5c` | 02:36:53 → 02:39:55 | 182 s | 36 s; 2:35, 2:17, 2:34 |
| [41271119404](https://github.com/plainprogrammer/Collector/actions/runs/41271119404) | `555d03b` | 03:56:36 → 03:59:22 | 166 s | 25 s; 1:59, 2:23, 2:36 |
| [41274952034](https://github.com/plainprogrammer/Collector/actions/runs/41274952034) (`main`, #149's merge) | `9b296aa` | 04:55:56 → 04:58:47 | 171 s | 36 s; 2:38, 2:25, 2:42 |

Median: **171 s**. M = 4's median is 31 s lower, so decision 7's stop rule (keep 4 only if it is at least 30 s faster) keeps **M = 4** (`2b68acd`). The margin is one second, inside the tens of seconds GitHub's times vary by (NFR Performance), so a later trial may well land the other way. The third M = 3 run is `main`'s run of #149's merge, not a re-run on the pull request as AC-2.5 says: this session can't re-run runs, and #149 merged, with the trial's matrix, before the maintainer's re-run. `main` ran three shards from that merge until this follow-up lands.

| Criterion | Proved by |
|---|---|
| AC-2.1 | `spec/image_publishing_spec.rb`, the AC-2.1 example and the libvips example, and `spec/script/upgrade/files_spec.rb`, `checks` and `rspec`. Every run above shows `checks`, `RSpec (N/M)` and `ci`, with `image` after `ci`. |
| AC-2.2 | Probe [`spec/system/ac_2_2_probe_spec.rb`](https://github.com/plainprogrammer/Collector/commit/5772850), which fails only when `GITHUB_ACTIONS` is set; reverted in `555d03b`. Run [41270156511](https://github.com/plainprogrammer/Collector/actions/runs/41270156511), M = 3: `RSpec (1/3)` failed (671 examples, 1 failure, the probe). `RSpec (2/3)` and `RSpec (3/3)` ran to the end and passed (03:43:43, 03:43:47), and `checks` passed. `ci` failed, and both `Image` jobs and `Publish manifest list` were skipped. |
| AC-2.3 | The same run uploaded the artifact `screenshots-1` (49,060 bytes), from `tmp/capybara`, which is `Capybara.save_path` (`spec/image_publishing_spec.rb`). Shard 1's log printed `Shard 1/3: 72 files, grouped by runtime, seed 2231` and `Replay: CI=true bin/rspec --seed 2231 --profile 10 spec/admin_catalog_core_spec.rb …` before the examples. |
| AC-2.6 | The probe run checked out `d17cbe0` ("Merge 5772850 into 6238217"). That commit was fetched as `refs/pull/149/merge` into a scratch worktree. There, `bundle exec ruby -e 'require "./lib/collector/ci_shard"; puts Collector::CiShard.new(index: 1, total: 3).files'` printed 72 files. They were identical, in the same order, to the files on the log's replay line (`diff`: no difference). |

### Story 3: Documentation-only branches skip RSpec before a push

| Criterion | Proved by |
|---|---|
| AC-3.1 | `spec/lib/collector/push_scope_spec.rb`, `.documentation_only?`. It covers each inclusion, each exclusion (`docs/export-format/**`, both settings files, `.claude/hooks/`, `config/ci.rb`), `<dir>x.md` for every `CODE_DIRS` entry, a rename given as both names, a deleted code file, and `[]`. |
| AC-3.2 | The same file, `.parse`: each accepted form (`git push`, `git push origin`, `-u` / `--set-upstream` with the current branch or `HEAD`, `cd /x && …`, `git -C /x push`, `… 2>&1 \| tail -3`) and each refused form, with the reason. A refused push still carries `cd` and `-C`. |
| AC-3.3 | Two runs show it. **(1) Scratch clone** (Phase 4, `f3bc962`, `origin` a local bare repo, `origin/main` set to the branch head): a branch that changed only `docs/roadmap.md` and `docs/scratch/note.md` printed `Pre-push: running bin/ci checks in …/clone (documentation-only branch (2 files): skipping RSpec)` and passed in 32.36 s. **(2) A real push:** the throwaway branch of AC-3.7 printed `… (documentation-only branch (1 file): skipping RSpec)`. A failing `bin/ci checks` blocks the push: the script exits 2 when `bin/ci` fails, the same path that blocked the push at seed 22126 above. |
| AC-3.4 | **Scratch clone:** a branch that changed `docs/export-format/examples/valid/empty-v2.json` printed `Pre-push: running bin/ci in … (branch is not documentation-only (2 files changed))`. It was stopped once RSpec had started. **Real pushes of this branch** printed `(branch is not documentation-only (28 files changed))` and later `(31 files changed)`. Their diff includes `.claude/settings.json` and `.claude/hooks/pre_push_ci.rb`. |
| AC-3.5 | **Scratch clone:** a detached `HEAD` printed `(changed paths unknown: HEAD is detached)`, and `git push --tags` printed `(push form not eligible for the fast path: option --tags pushes more than the current branch)`. Both were stopped once RSpec had started. **Real push:** the rebase's `--force-with-lease` push printed `(push form not eligible for the fast path: option --force-with-lease pushes more than the current branch)` and ran the full `bin/ci` (2,405 examples, 0 failures). **Examples:** no `origin/main`, an orphan branch, and a raising classifier are in `push_scope_spec.rb` (`.changed_paths`, `.decide`). |
| AC-3.6 | `spec/config/ci_definition_spec.rb`: both git hooks keep `"onFailure": "block"`, and the pre-push command runs `.claude/hooks/pre_push_ci.rb` with no `jq`. A missing `ruby` or script blocks the push (exit 2). The new hook ran every push from `db8d609` on. |
| AC-3.7 | **No filter:** `ci.yml`'s `on:` has no `paths` or `paths-ignore`. **A real documentation-only run:** throwaway draft PR [#152](https://github.com/plainprogrammer/Collector/pull/152) (`df9b9bc` from `origin/main`, one comment line in `docs/roadmap.md`, base `035-ci-shards`). Its run [41271774489](https://github.com/plainprogrammer/Collector/actions/runs/41271774489) ran `checks`, `RSpec (1/3)`, `(2/3)`, `(3/3)` and `ci`, all green, and both `Image` jobs. Locally, the branch's own (`main`'s) `bin/ci` ignored the `checks` argument and ran every step, as the plan says it would until this spec merges. #152 was closed. |

### Story 4: The documents

| Criterion | Proved by (read on `a936950`) |
|---|---|
| AC-4.1 | **Rules:** `docs/architecture/release-and-deploy.md`: "One CI definition", "Nothing is published" and the full-history rule now name the `checks` and `rspec` jobs, the `ci` job and the hook's groups. **Table:** "A workflow run" has `checks`, `rspec (M shards)` and `ci` columns. **New rules:** the groups, `--profile 10`, the run-time log and its refresh, and the shard's replay. **Image:** the CI tooling is kept out of it. **Sources:** each change cites spec 035's criteria or decisions inline, and every `ci.yml:NN` and `config/ci.rb:NN` reference was refreshed. spec 035 and #145 are in Sources. |
| AC-4.2 | `CLAUDE.md`: Commands names `bin/ci checks`, `bin/ci rspec`, `bin/ci rspec N/M` and `script/ci/record_runtime_log`. The Hooks section describes the documentation-only fast path, with decision 3's inclusions and exclusions. |
| AC-4.3 | `docs/specs/README.md`: spec 035's row records what it supersedes, and rows 001 and 031 name 035 under Superseded by. It was checked against the spec's Supersedes section and is unchanged. |
| AC-4.4 | `docs/roadmap.md`, housekeeping lane: a line for #145 (spike done, research.md, #147, #148) and a line for spec 035 (#149). |

## Final run

FINAL_BIN_CI

## Gaps and notes

- **Pre-push detection false positive:** the detection regex is today's, kept on purpose (plan 4.3). Any Bash command whose text holds "git" then "push", such as a heredoc commit message, makes the hook run the full `bin/ci`, or blocks the command if `bin/ci` fails. That happened once in Phase 4. Sessions write such text to a file and use `git commit -F`.
- **Deleting a remote branch:** this cloud session's git proxy dropped `git push --delete`, and the API delete was refused as a destructive git action. The throwaway branch `035-ac-3-7-doc-only-probe` is left for the maintainer to delete from #152's page.
- **Remote re-runs:** this session can't re-run workflow runs (403). The third M = 3 run is `main`'s merge run (see Story 2).
- **An intermittent failure that isn't this spec's:** a pre-push `bin/ci` failed once on `spec/system/bulk_mode_spec.rb:67`, at seed 45443. The whole suite then passed at that seed and the example passed five times alone, so it is a timing race, not test order. That example clicks before it waits for the bulk bar's count, which its sibling example waits for. It was raised as a separate task; this spec changes nothing under `app/` and not that spec.

## Implementation review

(pending)
