# Plan review of spec 031: findings and their fixes

Review: `sdd-superpowers:sdd-review`, Opus, read-only, 2026-10-24, of branch `031-upgrade-from-previous-release` at `4326dc8` (verdict NEEDS REVISION: 0 critical, 4 major, 11 minor). This file maps each finding to the change that answers it. Revised 2026-10-24 against spec 031 1.1.2.

## Maintainer ruling (2026-10-24)

**P4 is a spec PATCH, not only a plan note.** In the backup leg, spec 030's restore clears `sessions`, which cascades to `bulk_removals`, `bulk_selections` and `bulk_selection_marks` (`db/schema.rb` foreign keys). FR-4, decision 6 and AC-6.2 name those four tables as an allowance the comparison expects (emptied by the restore, citing spec 030), and nothing else. Recorded as spec 031 1.1.2 through `sdd-superpowers:sdd-spec-update`, in a commit of its own.

## Commits

| Step | Commit |
|---|---|
| Merge of `origin/main` (`ae593b2`) into the branch; `docs/specs/README.md` resolved so the 031 row and spec 030's *Superseded by* cell (AC-9.3) survive beside main's frozen statuses | `71e3424` |
| Spec 1.1.2, the P4 PATCH | `1ccaa27` |
| Plan, research and contracts revised | `ad32dad` |
| This file | the commit that adds it |

## Major findings

| Finding | Fix | Where |
|---|---|---|
| **M1a** AC-1.7 example expected `previous` nil | Expects `release(branch).previous.tag` to eq `"v0.2.1"` (previous release = newest stable when no tag is being built); the example's title says so. The code is unchanged. | plan.md, Phase 1 `#building` |
| **M1b** `build_history` never created its directory | `FileUtils.mkdir_p(dir)` is its first line | plan.md, Phase 0 |
| **M1c** double-escaped regex | `/^sessions\s+old\s+2\s+new\s+0/` | plan.md, Phase 8 leg example |
| **M2** `BUNDLE_WITHOUT` only on the setup-ruby step | Moved to the `image` job's `env:`, so `ruby/setup-ruby` and `bin/upgrade-smoke`'s `bundler/setup` both see it; files_spec asserts `image_job.dig("env", "BUNDLE_WITHOUT")`; research P10 and section 6 reworded (the fallback is still the full bundle) | plan.md Phase 9; research.md |
| **M3** release-and-deploy area doc not updated; merge would undo AC-9.3 | `main` merged first (`71e3424`), index cells kept. Phase 10 now edits `docs/architecture/release-and-deploy.md` in this pull request, item by item (Scope, Invariants for the guard, the image job step and the full-history checkouts, the image's leave-outs, the States table and "An upgrade", Named constants, Decisions not in an ADR including the reworded `bin/backup-smoke` line, Accepted limits, Sources, the Distillation log row, refreshed `ci.yml:NN` citations), each statement with its source inline. The CLAUDE.md bullet is cut to a one-sentence status line and a Commands line; the rules stay in the area doc. The 031 index row's *Areas* cell links the doc. Traceability AC-9.2 and AC-9.3 rows updated. | plan.md Phase 10, Traceability |
| **M4** (P4) | The maintainer's ruling above: spec 1.1.2. Plan: research P4 and the plan header record it as ruled; see m8 for the guard. | spec.md; plan.md; research.md |

## Minor findings

| Finding | Fix |
|---|---|
| **m1** RuboCop offenses | Twelve examples tagged `:aggregate_failures`; the 21-line engine example split into two (lifecycle, tasks and files); `files_spec.rb` joins `harness_spec.rb` in the `RSpec/MultipleMemoizedHelpers` exclusion. |
| **m2** errors outside the four rescued classes | The harness ends `call` with `rescue StandardError => error` and reports `error.class: message` with the usual evidence lines (new example with a seed line that is not JSON); the guard rescues `Release::Error` (which holds `TagsNotFetched`) and has an example for a non-release `GITHUB_REF_NAME`. The traceability table gains the Error Scenarios row. |
| **m3** git commands outside the allowlist; nothing proves only `Engine` spawns | `contracts/harness.md` gains a "host `git` (read-only)" row; a new engine_spec example fails if any file of `script/upgrade/` or `bin/upgrade-smoke` other than `engine.rb` and `release.rb` starts a process. |
| **m4** keyless table shows a shifted row as `value_changed` | **Not taken as code, stated as a limit** (the review offered either): `contracts/yaml-files.md` states that `rows_removed` and `rows_added` can match a keyless table only past the shorter table's end. No application table lacks a primary key today, and the comparison fails closed (an unlisted difference fails), so a multiset comparison would add code for no table. |
| **m5** failure messages print seed values | Failures name a collector by position (`collector 1 of 2`) and give counts for names and locations (`who` helper); the three harness examples assert the counts and that the email, card and location names are absent. |
| **m6** AC-6.5 builds `4cd1ef5` locally | The hand run pulls `ghcr.io/plainprogrammer/collector:sha-4cd1ef5` and passes it as the previous image; a local build is the fallback only if the tag is missing, with the deviation recorded in `verification.md`. |
| **m7** a pushed branch runs no CI | The AC-7.2 recipe opens a draft pull request from the throwaway branch, and says the tag's own run is the one to read. |
| **m8** `RESTORE_ENDS_SESSIONS` hard-coded | **Taken with a different mechanism from the review's first option.** The spec (1.1.2) names exactly these four tables and "nothing else", so a set derived at run time would silently allow a future cascading table. Instead an `expected_changes_spec` example computes the `on_delete: :cascade` closure from `sessions` in the application's schema and fails in `bin/ci` when it differs from the constant, with a message to update the constant and the spec (a PATCH). The leg's `not_emptied` message names spec 031 decision 7, so its advice is no longer the migration hint. |
| **m9** image version label not printed | The `previous:` line prints `version <label>`; the AC-1.3 example expects `version 0.2.1` (added in the second round, N1). |
| **m10a** guard script example inherits `GITHUB_REF_*` | The example passes `GITHUB_REF_TYPE=branch` and `GITHUB_REF_NAME=main` explicitly. |
| **m10b** `upgrade_fakes.rb` "loads nothing until required" | Comment corrected: `rails_helper` loads `spec/support`, so the suite needs `engine.rb` and `web.rb`; the red step may fail with `cannot load such file`. |
| **m10c** commit trailer names Sonnet 5.5 | The conventions paragraph now says to use the trailer the executing session's attribution gives. |
| **m11** "tag again" is ambiguous | Step 3 of `docs/releasing.md` now reads: cut the next patch (or pre-release) version, never move, reuse or delete the failed tag by hand (tags are published history, the area doc's Re-runs). |

## Not taken

Only m4's code change (a stated limit instead) and m8's derive-at-run-time option (a schema-checked constant instead), both for the reasons above. Everything else is taken as written.

## Checks made

Each fix was read against the plan's own code and the files it edits (`.rubocop.yml`, `.github/workflows/ci.yml`, `lib/collector/backup/snapshot.rb`, `db/schema.rb`'s cascades) and `origin/main:docs/architecture/release-and-deploy.md`. Every Ruby block of `plan.md` parses (`ruby -c`, 27 blocks). Nothing was run: no application code, RSpec, script or workflow was edited.

## Owed to the maintainer at the plan approval gate

- Approval of the revised plan.
- The first CI run still decides P10 (the job-level `BUNDLE_WITHOUT` and the arm64 bundle install), as research section 6 says.

## Second round (Sonnet, read-only, 2026-10-24)

Verdict APPROVE WITH NITS: 0 critical, 0 major, 4 minor. All four are folded into `plan.md`.

| ID | Fix |
|---|---|
| **N1** m9 claim unproven | The AC-1.3 example now includes `"version 0.2.1"`, and the m9 row above says so. |
| **N2** Phase 10 `ci.yml:NN` list incomplete | The parenthetical list is replaced by "every citation of a line after line 20", checked all. |
| **N3** README Areas cell and the log row's owner | Phase 10 edits the Areas row of `docs/architecture/README.md` (adds 031, narrows spec 030's "all but"); `distill-feature` writes the Distillation log row, Phase 10 leaving the date and pull request as placeholders for it. |
| **N4** "rules_spec" naming | Plan and this file say `expected_changes_spec` (`spec/script/upgrade/expected_changes_spec.rb`). |

## Approval

The maintainer approved the plan on 2026-10-24 after its two reviews, with these nits folded in, and chose Sonnet for the execution (`plan.md` header).
