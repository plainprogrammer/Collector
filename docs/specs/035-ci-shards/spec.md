# Feature 035: `bin/ci` Groups, Used by GitHub's Shards and the Pre-Push Hook

**Status:** Approved by the maintainer (2026-10-31), after two Mode A reviews
**Version:** 1.0.0
**Created:** 2026-10-31
**Last Updated:** 2026-10-31
**Branch:** `035-ci-shards`
**Issue:** [#145](https://github.com/plainprogrammer/Collector/issues/145) (spike; findings in [research.md](research.md))
**Plan:** retired in `c2528219d9a5232483abb0a05dbbc1d7e3f14bd3`; read it with `git show c2528219d9a5232483abb0a05dbbc1d7e3f14bd3^:docs/specs/035-ci-shards/plan.md`
**Frozen:** the current rules are in [`release-and-deploy.md`](../../architecture/release-and-deploy.md) (parts: all but decision 3 and Story 3, the pre-push hook, whose facts are in CLAUDE.md); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-31 | Approved by the maintainer. Status, version and the Plan line only; no requirement, criterion or decision changes |
| 0.3.1 | 2026-10-31 | Revised after the second Mode A review (READY AFTER FIXES, no blocking findings). The replay sets `CI=true`, because `CI` turns on eager loading in tests (AC-1.4, decision 6). Spec 031's container-engine rule moves to `checks` and the shards, and its decision 2 sentence is superseded too. `config/ci.rb` forms a shard in Ruby through `parallel_tests`' grouping code, prints its files and runs them (decision 6). AC-1.1 allows decision 8's change. The push forms with `cd`, `git -C` and output redirection are classified (decision 3). The Security requirement is tested. AC-2.1's wording and an ambiguous reference to spec 001 AC-2.5 are fixed. No change of intent (PATCH) |
| 0.3.0 | 2026-10-31 | The open question ruled by the maintainer (2026-10-31): every RSpec run of `bin/ci` prints the 10 slowest examples (decision 8, AC-1.9), so a regression like the parity example shows in every run. The hooks' fix is stacked on the parity fix (decision 1) |
| 0.2.0 | 2026-10-31 | Revised after the Mode A review (READY AFTER FIXES) and the maintainer's rulings on it. **Split (ruled):** the hooks' timeout fix left this spec and shipped as an issue fix with the parity fix (decision 1); the title names the one outcome, `bin/ci` groups and the two places that use them. **Supersessions:** spec 001 AC-2.5 (not FR-4); spec 031 AC-7.6 and AC-8.5's "`ci` job"; spec 014 AC-2.3 kept by installing libvips and ImageMagick in each shard; the area doc's rules named. **Shards:** `--group-by runtime` only when the log exists (decision 6); the log's path and refresh command; the seed chosen before the run and the replay a plain `bin/rspec` command (AC-1.4). **Measurement:** one metric for before and after, three runs each (AC-2.4, AC-2.5). **Fast path:** the push forms the hook accepts, a missing merge base or shallow history, a classifier error, renames, `.md` only outside code directories, and the hook in Ruby without `jq` (decision 3, Story 3). **Also:** `!cancelled()`, `Bash(bin/ci *)` allowed, a Testability requirement, Story 4's lines |
| 0.1.0 | 2026-10-31 | First draft, from the spike's findings and the maintainer's rulings of 2026-10-31 (research.md, "Recommendation and rulings") |

---

## Problem Statement

`bin/ci` took 2 min 20 s at spec 014 and 20–30 min by spec 032. The spike ([research.md](research.md)) found one example, `spec/models/location/name_parity_spec.rb:69`, took 1,486 s of a 1,812 s suite. It also found that the pre-push hook stopped gating once `bin/ci` ran past its 900 s timeout. Both are fixed outside this spec (decision 1). With the parity fix, the serial suite takes 5 min 54 s in a cloud session, of which system specs are 153 s.

Two waits remain, and both come from `bin/ci` being one serial list:

- **GitHub waits for one job.** The `ci` job runs every check one after another, and the `image` jobs wait for it (`needs: ci`). The suite divides well: four shards formed by recorded timings come to about 88 s each (research.md §1).
- **Documentation pushes wait for the suite.** A push that changes only Markdown waits for the full RSpec run before the pre-push hook lets it go. The suite reads only one part of the documentation, `docs/export-format/` (spec 020 decision 7; research.md §3).

## Goals

- `bin/ci` runs a named group of its steps, so other tools can choose what to run without listing the steps themselves. A plain `bin/ci` runs everything serially, as today.
- On GitHub, RSpec runs in shards in parallel, next to a job for the other checks. The `image` jobs start when all of them have passed.
- A failing shard can be replayed locally with one printed command (same files, same order, same seed).
- The pre-push hook runs the checks without RSpec when every file the branch changes is documentation that no code reads. When in doubt, it runs everything.

## Non-Goals

- Parallel RSpec on the developer's machine: workers, a database per process, a `tmp/` path per process. Ruled out on 2026-10-31; local `bin/ci` stays serial. Research.md §3 lists what it would need.
- The parity fix and the hooks' timeout fix. They ship first (decision 1).
- Branch protection or required checks. `main` has none (research.md §2). The aggregate `ci` job makes one required check possible later.
- Speeding up the `image` jobs, the backup smoke or the upgrade smoke.
- A fast path on GitHub, which always runs every group.

## Decisions

### 1. The parity example and the hooks' timeout are fixed first, as issue fixes (ruled 2026-10-31)

- **The parity fix:** `def lot_pattern` becomes a memoized `let` (branch `145-memoize-parity-regexp`).
- **The hooks:** both git hooks in `.claude/settings.json` get `"onFailure": "block"` (branch `145-hooks-block-on-timeout`), proved with Claude Code 2.1.316 in a scratch repository. Without the key a timed-out hook let the push through; with it the push was blocked.
- **Order:** the parity fix merges first. With the slow suite, `bin/ci` runs past 900 s, and every push would be blocked. So the hooks' branch is stacked on the parity branch.
- **Timing:** this spec's criteria are measured with both fixes in place.

### 2. RSpec is sharded on GitHub; local `bin/ci` stays serial (ruled 2026-10-31)

GitHub runs the suite as M shards in parallel, next to a job for the other checks (decisions 4–7). Locally, `bin/ci` and the pre-push hook keep running the suite in one process, so the serial order still runs before every push that isn't documentation-only (research.md §4).

### 3. Documentation-only branches skip RSpec in the pre-push hook, with exclusions (ruled 2026-10-31)

**Which files count.** A branch is **documentation-only** when every path it changes meets both conditions:

- it is under `docs/`, or ends in `.md` and is outside `app/`, `bin/`, `config/`, `db/`, `lib/`, `script/`, `spec/` and `vendor/`;
- it is not under `docs/export-format/` or `.claude/hooks/`, and is not `.claude/settings.json` or `.claude/settings.local.json`.

Every path counts: added, modified, deleted, and both names of a rename (`git diff --no-renames`). `docs/export-format/**` is code: the suite reads its schemas, its examples and its README (research.md §3). The settings and hook exclusions are belt-and-braces: the first condition already leaves them out except for a Markdown file under `.claude/hooks/`. Code directories are left out so that a future Markdown fixture under `spec/` or `app/` is never treated as documentation.

**What the hook runs.** For a documentation-only branch it runs `bin/ci checks` (decision 4). Otherwise it runs the full `bin/ci`.

**The changed paths.** They are `git diff --no-renames --name-only <base> HEAD`, where `<base>` is `git merge-base HEAD origin/main`. That is the whole branch, not just the commits being pushed, so a branch that ever changed code runs the suite on every push. A stale `origin/main` gives an older merge base and a larger diff, which only makes the check stricter.

**Which push commands qualify.** Only these forms can take the fast path: `git push`, `git push <remote>`, and `git push [-u|--set-upstream] <remote> <branch>|HEAD`, where `<branch>` is the current branch. Each may be preceded by `cd <dir> &&` or written `git -C <dir> push …` (the existing hook already resolves both to a checkout), and may be followed by output redirection or a pipe (`2>&1`, `| tail -N`). The diff runs in the checkout the hook resolves, and a resolved checkout outside this repository is skipped as today. Anything else runs the full `bin/ci`, including:

- another refspec, `src:dst`, several refspecs, a tag, `--tags`, `--all`, `--mirror` or `--delete`;
- more than one `git push` in the command, or a push chained after anything other than `cd <dir> &&`;
- no merge base (a shallow or unrelated history), no `origin/main`, or a detached `HEAD`;
- a failing `git` command, or an error in the classifier.

The hook says why it ran the full `bin/ci`.

### 4. `bin/ci` takes a group (recommended)

`config/ci.rb` reads one optional argument, checked before `CI.run`:

| Command | Steps |
|---|---|
| `bin/ci` | all, in today's order (setup, guard, RuboCop, Brakeman, bundler-audit, importmap audit, RSpec) |
| `bin/ci checks` | setup, guard, RuboCop, Brakeman, bundler-audit, importmap audit |
| `bin/ci rspec` | setup, then the whole suite in one process |
| `bin/ci rspec N/M` | setup, then shard N of M (1 ≤ N ≤ M) |

Any other argument fails before any step runs and names the accepted forms. Every step stays in `config/ci.rb`; the workflow and the hook name groups, never commands. The workflow's jobs all invoke `bin/ci`, so spec 001 FR-3 and FR-4 hold. Spec 001 AC-2.5's single check job is superseded (see Supersedes).

### 5. The workflow: `checks`, the `rspec` shards and an aggregate `ci` job (recommended)

- `checks` runs `bin/ci checks`, with the full history and tags, because it runs the guard (spec 031 AC-8.5; research.md §1). It installs no apt packages.
- `rspec` is a matrix of M shards (`fail-fast: false`). Each shard installs libvips and ImageMagick before it runs `bin/ci rspec N/M` (spec 014 AC-2.3), and uploads `screenshots-N` on failure. Shards check out the full history too, because `bin/setup` and specs such as the git sandbox's must behave as they do today.
- `ci` needs `checks` and `rspec`, runs `if: ${{ !cancelled() }}`, has no checkout, and fails unless both succeeded. The job name `ci` stays, so `image` still `needs: ci`, nothing is published unless every group passed (spec 012 FR-1, AC-3.4), and one required check stays possible.

### 6. Shards are formed by `parallel_tests` from a committed run-time log (recommended)

**The command.** `bin/ci rspec N/M` runs `parallel_rspec -n M --only-group N` with `--group-by runtime --runtime-log spec/support/runtime_log.txt --allowed-missing 100` when that log exists. When it doesn't, `config/ci.rb` passes `--group-by filesize` and prints that balance may be worse. It decides this itself because `parallel_tests` raises on a missing log once `--group-by runtime` is given. The groups are the same on every machine, whatever its core count.

**Forming and printing a shard.** `config/ci.rb` forms the group in Ruby through `parallel_tests`' own grouping code, the same code the `parallel_rspec` command uses. It prints the seed, the files and the replay command, then runs those files in one RSpec process. AC-1.5's example calls that shared code, because the suite can't call `bin/ci`. The plan names the class and checks the grouping API at the pinned version.

**One process per shard.** Each shard runs as one process against `storage/test.sqlite3` (`TEST_ENV_NUMBER` is empty for a single selected group), so neither `database.yml` nor any `tmp/` path changes.

**The seed and the replay.** `config/ci.rb` chooses the seed before the run (`SEED`, or a random one). The replay command is `CI=true bin/rspec --seed S <files>`. `CI` must be set because `CI.run` and GitHub both set it, and `config/environments/test.rb` turns on eager loading when it is present, so a replay without it would not run the shard as it ran.

**The log.** It is committed and refreshed from a serial run by one documented command (the plan names it; it uses `ParallelTests::RSpec::RuntimeLogger`). It is refreshed when shard times on GitHub differ by more than a minute, or when spec files are added or removed in bulk. A stale log changes balance only, never which files run: a file missing from the log is still assigned, and a deleted file is ignored.

**Where the design comes from.** plainprogrammer/ClientKennel's spec 016 uses it and measured it (research.md §2). The gem goes in the `test` group only, with the version pinned, and its behaviour at that version is checked in the plan.

**Alternative considered.** A hand-written splitter of about 40 lines, with no new gem (`.claude/rules/conventions.md`). It was not chosen: grouping by run time with a fallback, handling of missing files and `--only-group` are already maintained in `parallel_tests`, and a later local parallel run would use the gem.

### 7. Four shards, measured, with a stop rule (recommended)

Start with M = 4. If the median of three green runs with 4 shards isn't at least 30 s faster than with 3 (AC-2.5), use 3. ClientKennel found that a fifth slice added minutes without making the wall time more reliable.

### 8. Every RSpec run of `bin/ci` prints the 10 slowest examples (ruled 2026-10-31)

The RSpec step of `bin/ci`, `bin/ci rspec` and `bin/ci rspec N/M` passes `--profile 10`. Each shard prints its own ten. The point is that a regression like the parity example (research.md §1) shows up in every local and GitHub log. It is not a gate: nothing fails on a slow example. `--profile` only reads the timings RSpec already records, so it adds no measurable time.

## Users and Context

**Primary users:** the maintainer, who waits for CI before merging, and the Claude sessions whose pushes wait for the pre-push hook. These often run several at a time (#122, #127, #47 alongside this one).

**Baseline** (research.md, measured 2026-10-31 with the parity fix, in a cloud session with 4 cores):

- serial suite 5 min 54 s;
- non-RSpec steps about 21 s;
- four greedy shards about 88 s each before setup;
- GitHub job setup about 19 s, plus `bin/setup` 6–9 s.

## User Stories

### Story 1: `bin/ci` runs a group

**As** the maintainer **I want** to run one part of CI by name **so that** GitHub's jobs, the pre-push hook and my replays use the same definition.

- [ ] **AC-1.1** Given `bin/ci` with no argument When it runs Then it runs the same steps in the same order as before this spec, and the RSpec step runs the whole suite in one process; the RSpec command's only change is decision 8's `--profile 10`
- [ ] **AC-1.2** Given `bin/ci checks` When it runs Then it runs setup, the guard, RuboCop, Brakeman, bundler-audit and the importmap audit, and no RSpec
- [ ] **AC-1.3** Given `bin/ci rspec` When it runs Then it runs setup and the whole suite in one process, and none of the other checks
- [ ] **AC-1.4** Given `bin/ci rspec 2/4` When it runs Then it runs setup and the second of four groups formed by decision 6, and prints, before the examples run, the seed, the number of files and a replay command that runs those files in that order with that seed and with `CI` set (`CI=true bin/rspec --seed S <files>`)
- [ ] **AC-1.5** Given `bin/ci rspec 1/4` through `bin/ci rspec 4/4` on one checkout When their files are put together Then every spec file appears exactly once, with the run-time log present and with it absent
- [ ] **AC-1.6** Given an argument that isn't one of decision 4's forms (for example `bin/ci rspec 5/4`, `bin/ci rspec 0/4`, `bin/ci lint`) When `bin/ci` runs Then it exits non-zero before any step runs and names the accepted forms
- [ ] **AC-1.7** Given a failing example in shard N When `bin/ci rspec N/M` exits Then it exits non-zero and names the failed step, as `bin/ci` does today (spec 001 FR-3)
- [ ] **AC-1.8** Given `.claude/settings.json` When it is read Then `Bash(bin/ci *)` is allowed beside `Bash(bin/ci)`, so a group runs without a permission prompt
- [ ] **AC-1.9** Given `bin/ci`, `bin/ci rspec` or `bin/ci rspec N/M` When its RSpec step finishes, passing or failing Then its output lists the 10 slowest examples of that run with their times and locations (decision 8), and no exit status depends on them

### Story 2: GitHub runs the groups in parallel

**As** the maintainer **I want** a pull request's checks to run in parallel **so that** the verdict comes sooner.

- [ ] **AC-2.1** Given the workflow When it is read Then:
  - a `checks` job runs `bin/ci checks` after a full-history checkout;
  - an `rspec` matrix of M jobs each install libvips and ImageMagick and then run `bin/ci rspec N/M`;
  - a `ci` job needs both and runs `if: ${{ !cancelled() }}`;
  - `image` needs `ci`;
  - no job runs a command that `config/ci.rb` runs, except through `bin/ci`.
- [ ] **AC-2.2** Given a commit on the pull request with one deliberately failing example When the workflow finishes Then that shard and `ci` fail, the other shards ran to the end, and no `image` job ran, so nothing is pushed (spec 012 AC-3.4). The commit is reverted afterwards.
- [ ] **AC-2.3** Given a failing system spec in shard N When the job ends Then its screenshots are uploaded as `screenshots-N`, and the shard's log shows AC-1.4's replay command
- [ ] **AC-2.4** Given three green runs of the old workflow on `main` after decision 1's fixes, and three green runs of the new one on the pull request When each run's time is measured from its `run_started_at` to the `ci` job's `completed_at` (REST API) Then every time and both medians are recorded in `verification.md`, and the new median is lower
- [ ] **AC-2.5** Given decision 7 When it is measured with AC-2.4's metric on temporary commits on the pull request Then three runs with M = 4 and three with M = 3 are recorded, and M is the value the stop rule gives
- [ ] **AC-2.6** Given a shard's file list in a GitHub log When it is compared with `bin/ci rspec N/M` formed locally from the same commit and log Then the files and their order are the same

### Story 3: Documentation-only branches skip RSpec before a push

**As** a Claude session pushing only documentation **I want** the hook to skip the suite **so that** the push waits seconds, not minutes.

- [ ] **AC-3.1** Given a list of changed paths When it is classified Then it is documentation-only exactly when decision 3 says so. The classifier's examples cover:
  - each inclusion and each exclusion;
  - a Markdown file under `spec/`;
  - a rename from a code path to a Markdown path;
  - a deleted code file;
  - an empty list (not documentation-only).
- [ ] **AC-3.2** Given a push command When it is parsed Then each form decision 3 accepts is accepted, and each form it lists for the full `bin/ci` is refused
- [ ] **AC-3.3** Given a documentation-only branch and an accepted push form When the hook runs Then it runs `bin/ci checks`, says that it skipped RSpec for a documentation-only branch and how many files that covers, and blocks the push if `bin/ci checks` fails
- [ ] **AC-3.4** Given a branch whose diff touches any other path, including `docs/export-format/examples/valid/empty-v2.json`, `.claude/settings.json` or a file under `.claude/hooks/` When the hook runs Then it runs the full `bin/ci`
- [ ] **AC-3.5** Given any of decision 3's other full-`bin/ci` cases (no `origin/main`, no merge base, a detached `HEAD`, a failing `git` command, a classifier error, a refused push form) When the hook runs Then it runs the full `bin/ci` and says why
- [ ] **AC-3.6** Given the hook When it reads the tool call Then it parses the JSON in Ruby and needs no `jq`; the git commit and push hooks keep `"onFailure": "block"` (decision 1)
- [ ] **AC-3.7** Given a documentation-only push When GitHub's workflow runs Then every group runs

### Story 4: The documents say how CI runs now

**As** the maintainer **I want** the area doc, `CLAUDE.md` and the index to describe the groups **so that** the next session doesn't rediscover them.

- [ ] **AC-4.1** Given the release-and-deploy area doc When it is read Then:
  - "One CI definition" (release-and-deploy.md:46) says the workflow and the hook run `bin/ci` groups;
  - "Nothing is published unless `bin/ci` passed" (:47) says every group, through the `ci` job;
  - the full-history rule (:59) names the `checks` and `rspec` jobs;
  - the workflow table under "A workflow run" shows the jobs;
  - each change has this spec's criteria inline as sources.
- [ ] **AC-4.2** Given `CLAUDE.md` When it is read Then Commands names `bin/ci checks`, `bin/ci rspec` and `bin/ci rspec N/M` and the run-time log's refresh command, and the Hooks section says the pre-push hook skips RSpec for documentation-only branches, with decision 3's exclusions
- [ ] **AC-4.3** Given `docs/specs/README.md` When it is read Then spec 035's row records what it supersedes, and the rows of specs 001 and 031 record it under Superseded by
- [ ] **AC-4.4** Given `docs/roadmap.md` When it is read Then it has a housekeeping line for #145 and a line for spec 035 (issue #145's comment)

## Functional Requirements

### FR-1: CI groups

**Must:**
- accept decision 4's arguments in `config/ci.rb`, checked before `CI.run`;
- keep every step there;
- with no argument, run today's steps in today's order.

**Must not:** run any step when the argument isn't accepted.

### FR-2: Shards

**Must:**
- form groups as decision 6 says, the same on every machine;
- print the seed, the file count and a replay command per shard;
- pass `--profile 10` to every RSpec run of `bin/ci` (decision 8);
- run each shard as one process against `storage/test.sqlite3`.

**Must not:** drop or repeat a file across the M shards of one commit.

### FR-3: The workflow

**Must:**
- have decision 5's jobs, with `image` still needing `ci`;
- check out the full history where the guard and the suite run;
- install libvips and ImageMagick in each shard before `bin/ci`;
- pin every new action to a commit SHA, with its version in a comment (area doc, issue #132).

### FR-4: The pre-push hook

**Must:**
- classify the branch and parse the push command in Ruby, with specs, outside `app/` (the plan names the file, for example `lib/collector/push_scope.rb`);
- run `bin/ci checks` for a documentation-only branch and an accepted push form, and `bin/ci` otherwise;
- print which it ran and why;
- keep `"onFailure": "block"`.

**Must not:** skip anything when the changed paths or the push form can't be determined.

## Non-Functional Requirements

- **Performance:** the GitHub median falls (AC-2.4). There is no fixed target. The spike measured about 88 s of work per shard plus about 30 s of setup, but GitHub's job-completion times vary by tens of seconds (ClientKennel spec 016).
- **Reliability:** a stale or missing run-time log changes only balance (decision 6), and the fast path fails safe (AC-3.5).
- **Security:** the new jobs have `contents: read` only, and the workflow gains no permission. The example in `spec/image_publishing_spec.rb` that checks the `ci` job has no `permissions` is extended to `checks`, `rspec` and the aggregate `ci` job.
- **Testability:**
  - **Suite examples run by `bin/ci`:** AC-1.5, AC-1.6, AC-3.1, AC-3.2 and the hook's decision logic for AC-3.3–AC-3.5.
  - **File-shape specs in the style of `spec/image_publishing_spec.rb`:** AC-2.1, AC-1.8, the hooks' `onFailure` in AC-3.6, the Security requirement, and `--profile 10` in `config/ci.rb` (AC-1.9, beside its evidence). These read the workflow and the settings as configuration, not prose.
  - **Evidence recorded in `verification.md`:** AC-1.1–AC-1.4, AC-1.7, AC-1.9, AC-2.2–AC-2.6 and AC-3.7.
  - **Checked by reading:** AC-4.1–AC-4.4.

## Error Scenarios

| Scenario | Result |
|---|---|
| A shard fails | That shard fails; the others finish; `ci` fails; no `image` job runs; the shard's log has the replay command |
| The run-time log is missing | Shards group by file size; `bin/ci rspec N/M` says that balance may be worse; every file still runs once |
| The log lists a deleted file or misses a new one | The deleted file is ignored; the new one is assigned |
| `bin/ci` gets an unknown group | Exits non-zero before any step and names the accepted forms |
| The run is cancelled | `ci` doesn't run (`!cancelled()`); no `image` job runs |
| The hook can't tell what changed, or the push form isn't accepted | Full `bin/ci`, and the reason printed (AC-3.5) |
| A documentation-only push breaks a document | Not caught by the hook or by GitHub; documents are checked by reading (`.claude/rules/testing.md`) |

## Supersedes

- **Spec 001 AC-2.5:** "its check job invokes the local CI command". The workflow now has several jobs, each invoking a `bin/ci` group (decision 5). FR-3 and FR-4 still hold.
- **Spec 001 Story 2:** "'CI passes' means the same thing on my machine, in the pre-push hook, and on the remote". For a documentation-only branch the hook runs `bin/ci checks`, not the suite (decision 3).
- **Spec 031 AC-7.6, AC-8.5 and decision 2, in part:** "the `ci` job … runs the Story 8 guard" and "the `ci` and `image` jobs' checkouts fetch the full history and tags". The guard runs in the `checks` job, which checks out the full history and tags. The aggregate `ci` job has no checkout. Spec 031 decision 2's sentence about "the `ci` job's … checkout" is superseded the same way. AC-7.6's other half still holds, now for `checks` and every `rspec` shard: none pulls the previous release's image or needs a container engine. `spec/script/upgrade/files_spec.rb` asserts both halves on those jobs.
- **Kept, not superseded:**
  - Spec 014 AC-2.3: each shard installs libvips before `bin/ci`. `spec/image_publishing_spec.rb` changes to look in the `rspec` job.
  - Spec 012 FR-1 and AC-3.4: they hold through the aggregate `ci` job, and "`bin/ci` passed on the same commit" now means every group passed (AC-1.5).
- **Recording it:** specs 001 and 031 are frozen and not edited. `docs/specs/README.md` records the supersessions in both directions (AC-4.3), and the area doc and `CLAUDE.md` change (AC-4.1, AC-4.2).

## Documents that change

- **Code and configuration:** `config/ci.rb`; `.github/workflows/ci.yml`; `.claude/settings.json` (the hook command and `Bash(bin/ci *)`); the classifier and push parser and their specs; the run-time log; `Gemfile` and `Gemfile.lock` (`parallel_tests`, test group).
- **Specs that change:** `spec/script/upgrade/files_spec.rb` and `spec/image_publishing_spec.rb` (the jobs they read).
- **Documents:** `docs/architecture/release-and-deploy.md` (AC-4.1), `CLAUDE.md` (AC-4.2), `docs/specs/README.md` (AC-4.3), `docs/roadmap.md` (AC-4.4).

## Open Questions

None. The question of printing the slowest examples was ruled on 2026-10-31 (decision 8).

## Out of Scope

- Local parallel RSpec (Non-Goals). Revisit if serial `bin/ci` passes an agreed budget.
- Splitting `name_parity_spec.rb`, which is about 56 s after decision 1 and so the floor for every shard.
