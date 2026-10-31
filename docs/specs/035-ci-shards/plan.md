# Plan: Spec 035, `bin/ci` Groups, Used by GitHub's Shards and the Pre-Push Hook

**Spec:** [spec.md](spec.md) 1.0.0 (approved 2026-10-31)
**Branch:** `035-ci-shards` (draft PR [#149](https://github.com/plainprogrammer/Collector/pull/149))

## Global constraints

- **Phases.** Six phases, each executed by its own implementer subagent ([[sdd-execute-exact-plans]]). Each subagent gets its phase's line range of this plan plus this section.
- **Code blocks are strong drafts.** Nobody has run them, and they may be wrong.
  - Write the phase's examples first, run them, and see each fail for the reason stated.
  - Then implement until they pass.
  - A fix must keep the spec's behaviour. Record it as a ruling in the commit body.
- **Scope.** Keep to CI, hook, `lib/`, `spec/` and doc files. Nothing under `app/` changes (spike brief; parallel sessions #122, #127, #47).
- **Commits.** One Conventional Commit per step, ending with the session's attribution trailers ([[subagent-commit-trailers]]).
- **The test database.** One process at a time uses the worktree's test database ([[worktree-shared-test-db]]). Don't run RSpec while a `bin/ci` runs.
- **Gems.** Add `parallel_tests` with `bundle add`. It asks for permission, so ask the maintainer.
- **Workflow edits.** Edits to `.github/workflows/**` ask for permission. Ask the maintainer.
- **Unattended edits.** Never edit `.claude/settings.json`'s permission lists or hooks except as Phases 2 and 4 say.
- **Facts read from `parallel_tests` 5.8.0** (installed to a scratch directory and read, not run):
  - `ParallelTests::RSpec::Runner.tests_in_groups(tests, num_groups, options)` returns `num_groups` sorted file lists. `options` are `group_by:` (`:runtime` or `:filesize`), `runtime_log:` and `allowed_missing_percent:`.
  - With `group_by: :runtime`, a missing log raises (`File.read`) and a log missing more than `allowed_missing_percent` of the files raises `RuntimeLogTooSmallError`.
  - `ParallelTests::RSpec::RuntimeLogger` writes `path:seconds` lines only when `TEST_ENV_NUMBER` is set (an empty string counts).
  - `find_tests(["spec"])` finds the same 219 files as `find spec -name '*_spec.rb'` (checked 2026-10-31).

## Phase 0: Prerequisites (main session)

1. Wait until #147 (the parity fix) and #148 (the hooks block on a timeout) have merged.
2. Then `git fetch origin main` and rebase `035-ci-shards` onto it. #148 adds `"onFailure": "block"` to both hooks; Phase 4 keeps it (AC-3.6).
3. Ask the maintainer to approve `bundle add parallel_tests --version "~> 5.8" --group test --require false`.
4. Check `bin/rails zeitwerk:check` still passes: the gem must not autoload into the app.
5. Commit `chore(deps): add parallel_tests for CI shards (spec 035 decision 6)`.

## Phase 1: Groups and shards in `lib/` (AC-1.5, AC-1.6)

Two plain-Ruby files under `lib/collector/`. They are required by path, like `lib/collector/backup` (`config/application.rb` already keeps `lib/collector` out of autoloading; confirm and follow it). `bin/ci` loads them before Rails boots.

**1.1 Write the examples first: `spec/lib/collector/ci_groups_spec.rb`** (`type: :lib`, or the type the other `spec/lib/collector` files use).

- `Collector::CiGroups.parse([])` → `group: :all`.
- `parse(["checks"])` → `:checks`.
- `parse(["rspec"])` → `:rspec`, no shard.
- `parse(["rspec", "2/4"])` → `:rspec`, shard 2 of 4.
- Each of these raises `Collector::CiGroups::Unknown`, whose message names all four accepted forms (AC-1.6):
  - `["rspec", "5/4"]`, `["rspec", "0/4"]`, `["rspec", "1/0"]`, `["rspec", "a/b"]`;
  - `["lint"]`, `["checks", "1/2"]`, `["rspec", "1/2", "x"]`.

They fail with `NameError` (no `Collector::CiGroups`).

**1.2 Write the examples first: `spec/lib/collector/ci_shard_spec.rb`.**

- **Every file exactly once (AC-1.5).** For M in 2, 3 and 4, the union of `Collector::CiShard.new(index:, total: M).files` over every index equals `Dir["spec/**/*_spec.rb"].sort`, with no file twice. Run this:
  - with the committed log;
  - with the log path pointing at a missing file (expect a file-size grouping);
  - with a log that lists one deleted file and misses a real one (`allowed_missing_percent: 100`).
- **The replay command.** `replay_command(seed: 7)` returns `CI=true bin/rspec --seed 7 --profile 10 <files>` (AC-1.4, decision 8).
- **The grouping it reports.** `#grouping` is `:runtime` when the log exists and `:filesize` when it doesn't.

They fail with `NameError`.

**1.3 Implement.**

```ruby
# lib/collector/ci_groups.rb
# The groups bin/ci runs (spec 035 decision 4): all steps, the checks without RSpec, the whole suite, or one shard.
module Collector
  module CiGroups
    Unknown = Class.new(ArgumentError)
    Selection = Data.define(:group, :index, :total)
    FORMS = [ "bin/ci", "bin/ci checks", "bin/ci rspec", "bin/ci rspec N/M (1 <= N <= M)" ].freeze

    def self.parse(argv)
      case argv
      in [] then Selection.new(:all, nil, nil)
      in [ "checks" ] then Selection.new(:checks, nil, nil)
      in [ "rspec" ] then Selection.new(:rspec, nil, nil)
      in [ "rspec", %r{\A([1-9]\d*)/([1-9]\d*)\z} ] if $1.to_i <= $2.to_i then Selection.new(:rspec, $1.to_i, $2.to_i)
      else raise Unknown, "Unknown CI group #{argv.join(' ').inspect}. Accepted: #{FORMS.join(', ')}"
      end
    end
  end
end
```

Watch that `$1` is still set inside the `if` guard of a `case/in` arm. If it isn't, match with `=~` before the `case`.

```ruby
# lib/collector/ci_shard.rb
require "shellwords"

# One of M groups of spec files, formed by parallel_tests from the committed run-time log, or by file size without
# one (spec 035 decision 6). The same files on every machine, whatever its core count.
module Collector
  class CiShard
    RUNTIME_LOG = "spec/support/runtime_log.txt"

    attr_reader :index, :total

    def initialize(index:, total:, log: RUNTIME_LOG)
      @index, @total, @log = index, total, log
    end

    def grouping = File.file?(@log) ? :runtime : :filesize

    def files
      require "parallel_tests"
      require "parallel_tests/rspec/runner"
      options = grouping == :runtime ? { group_by: :runtime, runtime_log: @log, allowed_missing_percent: 100 } : { group_by: :filesize }
      ParallelTests::RSpec::Runner.tests_in_groups([ "spec" ], total, options).fetch(index - 1)
    end

    def replay_command(seed:) = "CI=true bin/rspec --seed #{seed} --profile 10 #{files.shelljoin}"
  end
end
```

Run the two spec files and see them pass. Commit `feat(ci): parse bin/ci groups and form spec shards (spec 035 decisions 4, 6)`.

## Phase 2: `config/ci.rb` groups, the profile and the run-time log (AC-1.1–AC-1.4, AC-1.6–AC-1.9)

**2.1 Write the example first: AC-1.9 and AC-1.8 as file-shape examples, in `spec/config/ci_definition_spec.rb`.**

- **AC-1.9:** `config/ci.rb` passes `--profile 10` on each RSpec command it builds. Read the file and expect `--profile 10` in the RSpec step strings.
- **AC-1.8:** `.claude/settings.json`'s `permissions.allow` includes both `Bash(bin/ci)` and `Bash(bin/ci *)`.

They fail: neither is there yet.

**2.2 Rewrite `config/ci.rb`.**

```ruby
# Run using bin/ci. Groups (spec 035 decision 4): bin/ci, bin/ci checks, bin/ci rspec, bin/ci rspec N/M.
require_relative "../lib/collector/ci_groups"
require_relative "../lib/collector/ci_shard"

begin
  selection = Collector::CiGroups.parse(ARGV)
rescue Collector::CiGroups::Unknown => error
  abort error.message
end

seed = Integer(ENV.fetch("SEED") { rand(1..65_535) })
rspec = "bin/rspec --seed #{seed} --profile 10"

if selection.index
  shard = Collector::CiShard.new(index: selection.index, total: selection.total)
  files = shard.files
  puts "Shard #{selection.index}/#{selection.total}: #{files.size} files, grouped by #{shard.grouping}, seed #{seed}"
  puts "Balance may be worse: no run-time log at #{Collector::CiShard::RUNTIME_LOG}" if shard.grouping == :filesize
  puts "Replay: #{shard.replay_command(seed:)}"
  rspec = "#{rspec} #{files.shelljoin}"
end

CI.run do
  step "Setup", "bin/setup --skip-server"

  unless selection.group == :rspec
    step "Upgrade: released migrations unchanged", "ruby script/upgrade/guard.rb"
    step "Style: Ruby", "bin/rubocop"
    step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
    step "Security: Gem audit", "bin/bundler-audit"
    step "Security: Importmap vulnerability audit", "bin/importmap audit"
  end

  step "Tests: RSpec", rspec unless selection.group == :checks
end
```

Keep the existing commented signoff block. The full run keeps today's order (AC-1.1).

- **The seed.** A plain `bin/ci` now always passes a seed. `--seed` is how RSpec randomises anyway (`spec_helper.rb` sets random order), so the full run doesn't change.
- **The replay must be printed before the examples run (AC-1.4).** It is: the `puts` lines come before `CI.run`.

**2.3 Add `Bash(bin/ci *)`** to `.claude/settings.json` after `Bash(bin/ci)` (AC-1.8).

**2.4 Add the refresh script, `script/ci/record_runtime_log`.**

```sh
#!/usr/bin/env bash
# Rewrites spec/support/runtime_log.txt from a serial run (spec 035 decision 6). Run it on a quiet machine when shard
# times on GitHub differ by more than a minute, or after spec files are added or removed in bulk.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_ENV_NUMBER="" bin/rspec --require parallel_tests/rspec/runtime_logger --format progress \
  --format ParallelTests::RSpec::RuntimeLogger --out spec/support/runtime_log.txt
```

- **Check `TEST_ENV_NUMBER=""`.** The logger writes only when `ENV['TEST_ENV_NUMBER']` is truthy, and `""` is truthy in Ruby. If Bash's empty assignment doesn't reach Ruby as `""`, use `TEST_ENV_NUMBER=1`. It doesn't change the database (`config/database.yml` doesn't read it).
- **Make it executable.**
- **Record the log.** Run it once, alone, and commit `spec/support/runtime_log.txt`.
- **The `spec/support` loader is safe:** `rails_helper` requires only `spec/support/**/*.rb`.

**2.5 Evidence (record in `verification.md`).**

- `bin/ci` runs every step in today's order (AC-1.1).
- `bin/ci checks` runs no RSpec (AC-1.2).
- `bin/ci rspec` runs the whole suite (AC-1.3).
- `bin/ci rspec 2/4` prints the seed, the file count and the replay before the examples (AC-1.4).
- `bin/ci rspec 5/4` and `bin/ci lint` exit non-zero before any step (AC-1.6).
- A deliberately failing example (a scratch edit, reverted) makes `bin/ci rspec N/4` exit non-zero and name "Tests: RSpec" (AC-1.7).
- Each run prints the 10 slowest examples (AC-1.9).

Run these one at a time, never two together.

Commits:
- `feat(ci): bin/ci runs a group or a shard and prints the slowest examples (spec 035)`;
- `chore(ci): record the spec run-time log (spec 035 decision 6)`.

## Phase 3: The workflow (AC-2.1, AC-2.3, Security; specs 014, 031)

**3.1 Write the examples first.**

- **`spec/image_publishing_spec.rb`:**
  - "installs libvips and ImageMagick before bin/ci" looks in `jobs.rspec`, and the next run line after the install is `bin/ci rspec ${{ matrix.shard }}/${{ strategy.job-total }}` (or whatever expression 3.2 settles on).
  - The example that checks `jobs.ci` has no `permissions` checks `checks`, `rspec` and `ci` (Security).
  - A new example covers AC-2.1:
    - `checks` runs `bin/ci checks`;
    - `rspec` has `strategy.fail-fast: false` and a `shard` matrix of 1..4;
    - `ci` needs `[checks, rspec]` with `if: ${{ !cancelled() }}`;
    - `image` needs `ci`;
    - no run line in any of the three jobs names `bin/rspec`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `bin/importmap` or `script/upgrade/guard.rb`.
- **`spec/script/upgrade/files_spec.rb`:**
  - `checkout("checks")` has `fetch-depth: 0`;
  - neither `checks` nor any `rspec` run line matches `upgrade-smoke|docker|podman` (spec 031 AC-7.6, AC-8.5 as superseded).

They fail against today's single `ci` job.

**3.2 Edit `.github/workflows/ci.yml`.** This asks for permission. Replace the `ci` job with:

```yaml
  checks:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0

      - name: Set up Ruby
        uses: ruby/setup-ruby@7f797815d8adceb1c412e7abefdd1ab4abc47a5f # v1.335.0
        with:
          bundler-cache: true

      - name: Run bin/ci checks
        run: bin/ci checks

  # RSpec in shards formed from spec/support/runtime_log.txt (spec 035 decision 6); bin/ci rspec N/M prints its replay.
  rspec:
    name: RSpec (${{ matrix.shard }}/4)
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        shard: [ 1, 2, 3, 4 ]
    steps:
      - name: Checkout code
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0

      - name: Set up Ruby
        uses: ruby/setup-ruby@7f797815d8adceb1c412e7abefdd1ab4abc47a5f # v1.335.0
        with:
          bundler-cache: true

      - name: Install libvips (Active Storage variants, ADR 0013) and ImageMagick (art matching's decoder, ADR 0012)
        run: sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends libvips imagemagick

      - name: Run bin/ci rspec
        run: bin/ci rspec ${{ matrix.shard }}/4

      - name: Keep screenshots from failed system specs
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        if: failure()
        with:
          name: screenshots-${{ matrix.shard }}
          path: tmp/capybara
          if-no-files-found: ignore

  # The one verdict the image jobs wait for: every group passed (spec 035 decision 5; spec 012 FR-1).
  ci:
    needs: [ checks, rspec ]
    if: ${{ !cancelled() }}
    runs-on: ubuntu-latest
    steps:
      - name: Require every group to pass
        env:
          CHECKS: ${{ needs.checks.result }}
          RSPEC: ${{ needs.rspec.result }}
        run: test "$CHECKS" = success && test "$RSPEC" = success
```

- **The shard count is fixed at 4.** The `/4` in the run line and the matrix must agree. A comment names both, so that Phase 6's M = 3 trial changes both.
- **`image` keeps `needs: ci`.**
- **No new action is added.** Every `uses:` line is already pinned.

**3.3 Run the changed spec files**, then commit `ci: run bin/ci checks and four RSpec shards in parallel, gathered by the ci job (spec 035 decision 5)`.

## Phase 4: The documentation-only fast path (AC-3.1–AC-3.6)

**4.1 Write the examples first: `spec/lib/collector/push_scope_spec.rb`** (include `GitSandbox` with `:git_sandbox` for 4.1c).

**a. `Collector::PushScope.documentation_only?(paths)` (AC-3.1).**

- True for `docs/adr/0001-x.md`, `docs/specs/035-ci-shards/screenshots/a.png`, `README.md`, `.claude/memory/x.md`, `.claude/rules/y.md`.
- False when the list contains any of:
  - `docs/export-format/README.md`, `docs/export-format/v3.schema.json`;
  - `.claude/settings.json`, `.claude/settings.local.json`, `.claude/hooks/notes.md`;
  - `spec/fixtures/x.md`, `app/views/x.md`, `config/ci.rb`.
- False for `[]`.

**b. `Collector::PushScope.parse(command, current_branch:)` (AC-3.2).** It returns `Data.define(:accepted, :directory, :reason)`.

- **Accepted:**
  - `git push`, `git push origin`, `git push -u origin 035-ci-shards`, `git push --set-upstream origin HEAD`, when the current branch is `035-ci-shards`;
  - `cd /x && git push origin HEAD` (directory `/x`);
  - `git -C /x push`;
  - `git push origin 035-ci-shards 2>&1 | tail -3`.
- **Refused, with a reason naming the form:**
  - `git push origin other`, `git push origin a:b`, `git push origin a b`;
  - `git push --tags`, `git push origin v1.0.0` (a ref that isn't the current branch);
  - `git push --all`, `git push --mirror`, `git push --delete origin x`;
  - `git push && git push`, `make && git push`.

**c. `Collector::PushScope.changed_paths(directory)`, in a sandbox repository** with a bare `origin` and a branch (AC-3.5).

- It returns `git diff --no-renames --name-only $(git merge-base HEAD origin/main) HEAD`.
- A rename returns both names.
- It raises `Collector::PushScope::Unknown` with a reason when:
  - there's no `origin/main`;
  - `HEAD` is detached;
  - there's no merge base (an orphan branch).

**d. `Collector::PushScope.decide(command, directory:)` returns `[group_args, reason]`.**

- `[["checks"], "documentation-only branch (N files): skipping RSpec"]` only when the command is accepted and the paths are documentation-only.
- Otherwise `[[], "<why>"]`, including when `changed_paths` or the classifier raises (AC-3.3–AC-3.5).

They fail with `NameError`.

**4.2 Implement `lib/collector/push_scope.rb`.** Plain Ruby, `require "open3"`. The rules:

```ruby
DOCS = ->(path) { path.start_with?("docs/") || (path.end_with?(".md") && !path.start_with?(*CODE_DIRS)) }
CODE_DIRS = %w[app/ bin/ config/ db/ lib/ script/ spec/ vendor/].freeze
EXCLUDED = ->(path) { path.start_with?("docs/export-format/", ".claude/hooks/") || %w[.claude/settings.json .claude/settings.local.json].include?(path) }

def self.documentation_only?(paths) = paths.any? && paths.all? { DOCS.(it) && !EXCLUDED.(it) }
```

**Parsing.**

1. Strip a trailing `2>&1` and a trailing `| …` pipe.
2. Accept one leading `cd <dir> &&`.
3. Split the rest with `Shellwords.split` and require exactly one `git` … `push` with an optional `-C <dir>`.
4. Allow only `-u` or `--set-upstream` as options, then at most a remote and one ref equal to the current branch or `HEAD`.

Anything else is refused, with its reason.

**4.3 The hook script, `.claude/hooks/pre_push_ci.rb`.** It ports today's shell hook to Ruby: the `cd` and `git -C` resolution, the `git-common-dir` check that the push is this project's repository, and skipping a push to another repository.

1. Read the tool call's JSON from stdin with `require "json"` (no `jq`).
2. Exit 0 unless the command contains a `git … push`.
3. Resolve the checkout.
4. Call `Collector::PushScope.decide`.
5. Print `Pre-push: running bin/ci <args> in <dir> (<reason>)` to stderr.
6. Run `bin/ci` with those args in that checkout.
7. Exit 2 with `Pre-push: bin/ci failed in <dir>. Fix the failing step before pushing.` when it fails.

It requires `lib/collector/push_scope.rb` from `CLAUDE_PROJECT_DIR`. Its decision logic is the specced `decide`; the script is only the I/O around it.

**4.4 `.claude/settings.json`.** Replace the pre-push hook's command with:

```sh
[ "${CLAUDE_CODE_REMOTE:-}" = true ] && [ -d /opt/rbenv/shims ] && PATH=/opt/rbenv/shims:$PATH; exec ruby "$CLAUDE_PROJECT_DIR/.claude/hooks/pre_push_ci.rb"
```

Keep `"timeout": 900` and `"onFailure": "block"` (from #148). Add a file-shape example to `spec/config/ci_definition_spec.rb`:
- both git hooks keep `onFailure: "block"`;
- the pre-push command runs `.claude/hooks/pre_push_ci.rb` and contains no `jq` (AC-3.6).

**4.5 Evidence for `verification.md` (a scratch branch, never pushed to a shared remote).**

Pipe a hand-written tool-call JSON into the script for:
- a documentation-only branch: it runs `bin/ci checks` (AC-3.3);
- a branch touching `docs/export-format/examples/valid/empty-v2.json`: full `bin/ci` (AC-3.4);
- a detached `HEAD`: full `bin/ci`, with the reason (AC-3.5).

Commits:
- `feat(hooks): classify a branch's changes and push command for the pre-push hook (spec 035 decision 3)`;
- `feat(hooks): skip RSpec before a documentation-only push (spec 035 Story 3)`.

## Phase 5: Documents (AC-4.1–AC-4.4)

**`docs/architecture/release-and-deploy.md`** (AC-4.1). Each change cites spec 035's criteria inline.

- **The "One CI definition" rule (line 46):** the workflow's `checks` and `rspec` jobs and the pre-push hook run `bin/ci` groups.
- **The "Nothing is published" rule (line 47):** every group, gathered by the `ci` job.
- **The full-history rule (line 59):** the `checks` and `rspec` jobs.
- **The "A workflow run" table:** the jobs, with `checks`/`rspec`/`ci` in place of the `ci` column's single `bin/ci`.
- **A new rule:** shards come from `spec/support/runtime_log.txt` through `Collector::CiShard`; a stale log changes only balance; refresh it with `script/ci/record_runtime_log`; each shard prints its seed and replay with `CI=true`.
- **Sources:** add #145 and spec 035.

**`CLAUDE.md`** (AC-4.2).

- **Commands:** `bin/ci checks`, `bin/ci rspec`, `bin/ci rspec N/M` (replay a GitHub shard), and `script/ci/record_runtime_log`.
- **Hooks:** the pre-push hook runs `bin/ci checks` for a documentation-only branch (everything under `docs/` or Markdown outside code directories, except `docs/export-format/**`, `.claude/settings*.json` and `.claude/hooks/`), and the full `bin/ci` otherwise or when unsure.
- **Rule placement:** keep the area's rules in the area doc (documentation rule: don't restate them in `CLAUDE.md`).

**`docs/specs/README.md`** (AC-4.3): already records the supersessions. Check the rows of 001, 031 and 035 against the spec's Supersedes section.

**`docs/roadmap.md`** (AC-4.4), in its housekeeping lane:
- a line for [#145](https://github.com/plainprogrammer/Collector/issues/145): the spike, done 2026-10-31, with its findings in research.md, #147 and #148;
- a line for spec 035, with its PR #149.

Verify each by reading. Commit `docs: CI groups and shards in the area doc, CLAUDE.md and the roadmap (spec 035 Story 4)`.

## Phase 6: Measure on GitHub (AC-2.2–AC-2.6, AC-3.7; main session)

**The metric (AC-2.4).** For each run, take `run_started_at` from `GET /repos/plainprogrammer/Collector/actions/runs/<id>`. Take the `ci` job's `completed_at` from `…/runs/<id>/jobs`.

1. **Baseline.** The last three green `main` runs after #147 and #148 merged, old workflow.
2. **M = 4.** Three green runs on #149, after Phase 3. Empty commits to re-trigger CI aren't allowed, so the three runs come from Phase 4's and Phase 5's pushes plus one re-run of the last run (a re-run is a new attempt, measured the same way).
3. **M = 3 (AC-2.5).** A temporary commit sets the matrix to `[ 1, 2, 3 ]` and the run line to `/3`, then three runs (one push, two re-runs). Then a revert commit, or keep 3 if the stop rule says so (decision 7: keep 4 only if its median is at least 30 s faster).
4. **AC-2.2.** A temporary commit makes one example fail. Check:
   - that shard and `ci` fail;
   - the other shards finish;
   - no `image` job runs;
   - the shard's log shows the replay.

   Then revert it.
5. **AC-2.3.** On that failing run, if the example is a system spec, check the `screenshots-N` artifact. If it isn't, make the failing example a system spec.
6. **AC-2.6.** Compare one shard's printed file list on GitHub with `bin/ci rspec N/4` run locally on the same commit (print only: interrupt after the replay line, or call `Collector::CiShard` from `bin/rails runner`).
7. **AC-3.7.** Phase 5's documentation commit, pushed through the hook's fast path, still runs every group on GitHub.

Record everything in `verification.md`, then run the full `bin/ci` once at the end.
