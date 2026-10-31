# Plan: Spec 035, `bin/ci` Groups, Used by GitHub's Shards and the Pre-Push Hook

**Spec:** [spec.md](spec.md) 1.0.0 (approved 2026-10-31)
**Branch:** `035-ci-shards` (draft PR [#149](https://github.com/plainprogrammer/Collector/pull/149))
**Plan reviews (Opus, read-only, 2026-10-31):**
- **Round 1: NOT READY.** One blocking finding and 13 others, all fixed.
- **Round 2: READY AFTER FIXES.** Three important findings and five minor ones, all fixed:
  - the screenshots path;
  - the throwaway branch's base;
  - the 4.5 evidence setup;
  - `cd` and `-C` resolved for refused pushes;
  - the hook failing closed without Ruby;
  - the AC-2.6 commands;
  - `bin/ci` left out of the image;
  - small points.

## Global constraints

- **Phases.** Six phases, each executed by its own implementer subagent ([[sdd-execute-exact-plans]]). Each subagent gets its phase's line range of this plan plus this section.
- **Code blocks are strong drafts.** Nobody has run them, and they may be wrong.
  - Write the phase's examples first, run them, and see each fail for the reason stated.
  - Then implement until they pass.
  - A fix must keep the spec's behaviour. Record it as a ruling in the commit body.
- **Scope.** Keep to CI, hook, `lib/`, `spec/`, `config/application.rb`, `.dockerignore`, `bin/image-smoke` and doc files. Nothing under `app/` changes (spike brief; parallel sessions #122, #127, #47).
- **Commits.** One Conventional Commit per step, ending with the session's attribution trailers ([[subagent-commit-trailers]]).
- **The test database.** One process at a time uses the worktree's test database ([[worktree-shared-test-db]]). Don't run RSpec while a `bin/ci` runs.
- **Gems.** Add `parallel_tests` with `bundle add`. It asks for permission, so ask the maintainer.
- **Workflow edits.** Edits to `.github/workflows/**` ask for permission. Ask the maintainer.
- **Unattended edits.** Never edit `.claude/settings.json`'s permission lists or hooks except as Phases 2 and 4 say.
- **New spec files** under `spec/lib/collector/` take no `type:`, like their neighbours.
- **The new `lib/collector` files are development tooling**, like `lib/collector/ghcr_cleanup.rb`. This applies to `ci_groups.rb`, `ci_shard.rb` and `push_scope.rb`. `bin/ci` and `config/ci.rb` require them, so those two leave the image too; nothing in the image runs them (Dockerfile and smoke scripts checked).
  - They are required by path: from `bin/ci`, from the hook script, and from their specs.
  - They are kept out of autoloading: add them to `config.autoload_lib(ignore: …)` in `config/application.rb`, which today ignores only `collector/backup*`. Otherwise Zeitwerk would eager-load them under `CI=true`.
  - They are kept out of the image: `.dockerignore`, and `bin/image-smoke`'s list of paths that must be absent.
- **Facts read from `parallel_tests` 5.8.0** (installed to a scratch directory and read, not run; confirmed by the plan review):
  - `ParallelTests::RSpec::Runner.tests_in_groups(tests, num_groups, options)` returns `num_groups` sorted file lists. `options` are `group_by:` (`:runtime` or `:filesize`), `runtime_log:` and `allowed_missing_percent:`.
  - With `group_by: :runtime`, a missing log raises (`File.read`).
  - With `allowed_missing_percent: 100` a short log never raises: files missing from the log get the average time, and deleted files are ignored.
  - `find_tests(["spec"])` returns `spec/…` paths, the same 219 files as `find spec -name '*_spec.rb'`. These match the runtime logger's relative paths.
  - `ParallelTests::RSpec::RuntimeLogger` writes `path:seconds` lines only when `TEST_ENV_NUMBER` is set. `TEST_ENV_NUMBER=""` reaches Ruby as `""`, which is truthy, so it works.

## Phase 0: Prerequisites (main session)

1. Wait until #147 (the parity fix) and #148 (the hooks block on a timeout) have merged.
2. Then `git fetch origin main` and rebase `035-ci-shards` onto it. #148 adds `"onFailure": "block"` to both hooks; Phase 4 keeps it (AC-3.6).
3. Ask the maintainer to approve `bundle add parallel_tests --version "~> 5.8.0" --group test --require false`. The lockfile pins the exact version; the plan's facts were read at 5.8.0.
4. Commit `chore(deps): add parallel_tests for CI shards (spec 035 decision 6)`.

## Phase 1: Groups and shards in `lib/` (AC-1.5, AC-1.6)

**1.1 Write the examples first: `spec/lib/collector/ci_groups_spec.rb`** (`require Rails.root.join("lib/collector/ci_groups").to_s`).

- `Collector::CiGroups.parse([])` → `group: :all`.
- `parse(["checks"])` → `:checks`.
- `parse(["rspec"])` → `:rspec`, no shard.
- `parse(["rspec", "2/4"])` → `:rspec`, shard 2 of 4.
- Each of these raises `Collector::CiGroups::Unknown`, whose message names all four accepted forms (AC-1.6):
  - `["rspec", "5/4"]`, `["rspec", "0/4"]`, `["rspec", "1/0"]`, `["rspec", "a/b"]`;
  - `["lint"]`, `["checks", "1/2"]`, `["rspec", "1/2", "x"]`.

They fail with `LoadError` (no file).

**1.2 Write the examples first: `spec/lib/collector/ci_shard_spec.rb`.**

- **Every file exactly once (AC-1.5).** For M in 2, 3 and 4, the union of `Collector::CiShard.new(index:, total: M, log:).files` over every index equals `Dir["spec/**/*_spec.rb"].sort`, with no file twice. Run this:
  - **with a fixture log** written to a scratch file: every spec file at 1 s, one deleted path, and one real file left out, so `allowed_missing_percent: 100` applies;
  - **with `log:` pointing at a missing file** (expect `#grouping` to be `:filesize`).

  The committed log's case is added in Phase 2.4, once the log exists.
- **The replay command.** `replay_command(files: %w[spec/a_spec.rb spec/b_spec.rb], seed: 7)` returns `CI=true bin/rspec --seed 7 --profile 10 spec/a_spec.rb spec/b_spec.rb` (AC-1.4, decision 8).
- **The grouping it reports.** `#grouping` is `:runtime` when the log exists and `:filesize` when it doesn't.

They fail with `LoadError`.

**1.3 Implement.**

```ruby
# lib/collector/ci_groups.rb
# The groups bin/ci runs (spec 035 decision 4): all steps, the checks without RSpec, the whole suite, or one shard.
# Development tooling, required by path; not autoloaded and not in the image.
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

```ruby
# lib/collector/ci_shard.rb
require "shellwords"

# One of M groups of spec files, formed by parallel_tests from the committed run-time log, or by file size without
# one (spec 035 decision 6). The same files on every machine, whatever its core count. Development tooling, required
# by path; not autoloaded and not in the image.
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

    def self.replay_command(files:, seed:) = "CI=true bin/rspec --seed #{seed} --profile 10 #{files.shelljoin}"
  end
end
```

`replay_command` is a class method that takes the files, so a shard forms its groups once. `fetch(index - 1)` can return an empty group only when there are fewer files than shards (the CLI drops empty groups), which can't happen with 219 files.

**1.4** Add the two files to `config.autoload_lib(ignore: …)` in `config/application.rb`, beside `collector/backup*`. Update the comment above it, then run `bin/rails zeitwerk:check`.

Run the two spec files and see them pass. Commit `feat(ci): parse bin/ci groups and form spec shards (spec 035 decisions 4, 6)`.

## Phase 2: `config/ci.rb` groups, the profile and the run-time log (AC-1.1–AC-1.4, AC-1.6–AC-1.9)

**2.1 Write the examples first, in `spec/config/ci_definition_spec.rb`** (file-shape, `type: :config` or the type its neighbours use).

- **AC-1.9:** `config/ci.rb` passes `--profile 10` on the RSpec command.
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

rspec = "bin/rspec --profile 10"

if selection.index
  seed = Integer(ENV.fetch("SEED") { rand(1..65_535) })
  shard = Collector::CiShard.new(index: selection.index, total: selection.total)
  files = shard.files
  puts "Shard #{selection.index}/#{selection.total}: #{files.size} files, grouped by #{shard.grouping}, seed #{seed}"
  puts "Balance may be worse: no run-time log at #{Collector::CiShard::RUNTIME_LOG}" if shard.grouping == :filesize
  puts "Replay: #{Collector::CiShard.replay_command(files:, seed:)}"
  rspec = "bin/rspec --seed #{seed} --profile 10 #{files.shelljoin}"
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

- **Keep the existing signoff block**, commented out as it is today.
- **A plain `bin/ci` and `bin/ci rspec` gain only `--profile 10`** (AC-1.1): RSpec picks its own seed as today.
- **Only a shard fixes the seed**, so that its replay is exact.
- **The replay is printed before the examples run (AC-1.4):** the `puts` lines come before `CI.run`.

**2.3 Add `Bash(bin/ci *)`** to `.claude/settings.json`, after `Bash(bin/ci)` (AC-1.8).

**2.4 Add the refresh script, `script/ci/record_runtime_log`**, and make it executable:

```sh
#!/usr/bin/env bash
# Rewrites spec/support/runtime_log.txt from a serial run (spec 035 decision 6). Run it on a quiet machine when shard
# times on GitHub differ by more than a minute, or after spec files are added or removed in bulk.
set -euo pipefail
cd "$(dirname "$0")/../.."
TEST_ENV_NUMBER="" bin/rspec --require parallel_tests/rspec/runtime_logger --format progress \
  --format ParallelTests::RSpec::RuntimeLogger --out spec/support/runtime_log.txt
```

**Record the log.**

1. Run the script once, alone, and commit `spec/support/runtime_log.txt`.
2. Then add the committed-log case to `spec/lib/collector/ci_shard_spec.rb`: the union over M = 4 with the default log equals every spec file once.

`rails_helper` requires only `spec/support/**/*.rb`, so the `.txt` log is never loaded as code.

**2.5 Evidence (record in `verification.md`).** Run these one at a time, never two together.

- `bin/ci` runs every step in today's order (AC-1.1).
- `bin/ci checks` runs no RSpec (AC-1.2).
- `bin/ci rspec` runs the whole suite (AC-1.3).
- `bin/ci rspec 2/4` prints the seed, the file count and the replay before the examples (AC-1.4).
- `bin/ci rspec 5/4` and `bin/ci lint` exit non-zero before any step (AC-1.6).
- A deliberately failing example (a scratch edit, reverted, never committed) makes `bin/ci rspec N/4` exit non-zero and name "Tests: RSpec" (AC-1.7).
- Each run prints the 10 slowest examples (AC-1.9).

Commits:
- `feat(ci): bin/ci runs a group or a shard and prints the slowest examples (spec 035)`;
- `chore(ci): record the spec run-time log (spec 035 decision 6)`.

## Phase 3: The workflow (AC-2.1, AC-2.3, Security; specs 014, 031)

**3.1 Write the examples first.**

- **`spec/image_publishing_spec.rb`:**
  - "installs libvips and ImageMagick before bin/ci" looks in `jobs.rspec`. The run line after the install is `bin/ci rspec ${{ matrix.shard }}/${{ strategy.job-total }}`.
  - The example that checks `jobs.ci` has no `permissions` checks `checks`, `rspec` and `ci` (Security).
  - The `rspec` job's screenshots upload names `screenshots-${{ matrix.shard }}` and `path: tmp/screenshots`, where Rails saves failure screenshots (`Capybara.save_path` is unset, so `ActionDispatch::SystemTesting::TestHelpers::ScreenshotHelper` uses `tmp/screenshots`). Today's `ci.yml:44` uploads `tmp/capybara`, so no screenshot has ever been uploaded; say so in the commit body (AC-2.3).
  - A new example covers AC-2.1:
    - `checks` runs `bin/ci checks`;
    - `rspec` has `strategy.fail-fast: false` and a `shard` matrix that is a contiguous `1..N` with N ≥ 2 (any N, so Phase 6's M = 3 trial stays green);
    - `ci` needs `[checks, rspec]` with `if: ${{ !cancelled() }}`;
    - `image` needs `ci`;
    - no run line in these three jobs names a command `config/ci.rb` runs, except through `bin/ci`. Those commands are `bin/setup`, `bin/rspec`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `bin/importmap` and `script/upgrade/guard.rb`.
  - The three new `lib/collector` files, `bin/ci` and `config/ci.rb` are in `.dockerignore` and in `bin/image-smoke`'s list of absent paths, beside `lib/collector/ghcr_cleanup.rb`.
- **`spec/script/upgrade/files_spec.rb`:**
  - `checkout("checks")` has `fetch-depth: 0`;
  - neither `checks` nor `rspec` has a run line matching `upgrade-smoke|docker|podman` (spec 031 AC-7.6, AC-8.5 as superseded).

They fail against today's single `ci` job and today's `.dockerignore`.

**3.2 Edit `.dockerignore` and `bin/image-smoke`** to add the three `lib/collector` files, `bin/ci` and `config/ci.rb`.

**3.3 Edit `.github/workflows/ci.yml`.** This asks for permission. Replace the `ci` job with:

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

  # RSpec in shards formed from spec/support/runtime_log.txt (spec 035 decisions 6, 7). The shard count is the
  # matrix's length; bin/ci rspec N/M prints the shard's seed and a replay command.
  rspec:
    name: RSpec (${{ matrix.shard }}/${{ strategy.job-total }})
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
        run: bin/ci rspec ${{ matrix.shard }}/${{ strategy.job-total }}

      - name: Keep screenshots from failed system specs
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        if: failure()
        with:
          name: screenshots-${{ matrix.shard }}
          path: tmp/screenshots
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

- **The shard count is only the matrix's length**: changing `[ 1, 2, 3, 4 ]` changes M everywhere.
- **`image` keeps `needs: ci`.**
- **No new action is added.** Every `uses:` line is already pinned.

**3.4 Run the changed spec files.** Then commit, as two commits:
- `chore(image): keep the CI tooling out of the image`;
- `ci: run bin/ci checks and the RSpec shards in parallel, gathered by the ci job (spec 035 decision 5)`.

## Phase 4: The documentation-only fast path (AC-3.1–AC-3.6)

**4.1 Write the examples first: `spec/lib/collector/push_scope_spec.rb`** (include `GitSandbox` with `:git_sandbox` for part c).

**a. `Collector::PushScope.documentation_only?(paths)` (AC-3.1).**

- **True for** `docs/adr/0001-x.md`, `docs/specs/035-ci-shards/screenshots/a.png`, `README.md`, `.claude/memory/x.md`, `.claude/rules/y.md`.
- **False when the list contains:**
  - `docs/export-format/README.md` or `docs/export-format/v3.schema.json`;
  - `.claude/settings.json`, `.claude/settings.local.json` or `.claude/hooks/notes.md`;
  - `config/ci.rb`;
  - `<dir>x.md` for **every** entry of `PushScope::CODE_DIRS`, iterated.
- **False for a rename**, given as its two names `["app/x.rb", "docs/x.md"]`.
- **False for a deleted code file** (`["lib/gone.rb", "docs/a.md"]`).
- **False for `[]`.**

**b. `Collector::PushScope.parse(command, current_branch:)` (AC-3.2).** It returns `Data.define(:accepted, :cd, :git_c, :reason)`, where `cd` is a leading `cd <dir>` and `git_c` the `-C <dir>`; either may be nil. Both are filled **whether or not the command is accepted**, as today's hook extracts them from any command, so a refused push still runs the full `bin/ci` in the right checkout: `cd ../wt && git push --tags` is refused with `cd == "../wt"`.

- **Accepted:**
  - `git push`, `git push origin`, `git push -u origin 035-ci-shards`, `git push --set-upstream origin HEAD`, when the current branch is `035-ci-shards`;
  - `cd /x && git push origin HEAD`;
  - `git -C /x push`;
  - `git push origin 035-ci-shards 2>&1 | tail -3`.
- **Refused, with a reason naming the form:**
  - `git push -u` with no remote;
  - `git push origin other`, `git push origin a:b`, `git push origin a b`;
  - `git push --tags`, `git push origin v1.0.0`;
  - `git push --all`, `git push --mirror`, `git push --delete origin x`;
  - `git push && git push`, `make && git push`;
  - `git push || git push --tags`, `git push; git push --tags`, `git push | tail -3 && git push --tags`, `git push &`.

**c. `Collector::PushScope.changed_paths(directory)`, in a sandbox repository** with a bare `origin` and a branch (AC-3.5).

- It returns the NUL-separated output of `git diff -z --no-renames --name-only $(git merge-base HEAD origin/main) HEAD`, so a path with non-ASCII characters comes back unquoted.
- A rename returns both names.
- It raises `Collector::PushScope::Unknown` with a reason on any non-zero `git` exit, including when:
  - there's no `origin/main`;
  - `HEAD` is detached;
  - there's no merge base (an orphan branch).
- Its git calls clear `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE` and `GIT_COMMON_DIR`, as `spec/support/git_sandbox.rb` does.

**d. `Collector::PushScope.decide(command, directory:, current_branch:, classifier: PushScope)` returns `[group_args, reason]`.**

- It returns `[["checks"], "documentation-only branch (N files): skipping RSpec"]` only when the command is accepted and the paths are documentation-only. Otherwise it returns `[[], "<why>"]`.
- It also returns `[[], …]` when `changed_paths` raises (AC-3.5): use a sandbox with a detached `HEAD`.
- It also returns `[[], …]` when the classifier raises. Test that by passing a small classifier object whose `documentation_only?` raises; this is injection, not stubbing the object under test.

They fail with `LoadError`.

**4.2 Implement `lib/collector/push_scope.rb`.** Plain Ruby, using `open3` and `shellwords`. Add it to the autoload ignore list (Phase 1.4), `.dockerignore` and `bin/image-smoke` (Phase 3.2). The rules:

```ruby
CODE_DIRS = %w[app/ bin/ config/ db/ lib/ script/ spec/ vendor/].freeze
EXCLUDED_DIRS = %w[docs/export-format/ .claude/hooks/].freeze
EXCLUDED_FILES = %w[.claude/settings.json .claude/settings.local.json].freeze

def self.documentation?(path)
  return false if path.start_with?(*EXCLUDED_DIRS) || EXCLUDED_FILES.include?(path)

  path.start_with?("docs/") || (path.end_with?(".md") && !path.start_with?(*CODE_DIRS))
end

def self.documentation_only?(paths) = paths.any? && paths.all? { documentation?(it) }
```

**Parsing (decision 3).**

1. Refuse outright if the command contains `||`, `;`, a lone `&`, or more than one `git … push`.
2. Strip one trailing `2>&1`, and then one trailing `| tail -N` or `| head -N` with nothing after it. Any other pipe refuses.
3. Accept one leading `cd <dir> &&`. Any other `&&` chain refuses.
4. Split the rest with `Shellwords.split`. It must be `git`, an optional `-C <dir>`, then `push`.
5. After `push`, allow:
   - nothing;
   - a remote;
   - `-u` or `--set-upstream`, a remote, and one ref equal to the current branch or `HEAD`;
   - a remote and that ref, without the option.

Anything else is refused, with its reason.

**4.3 The hook script, `.claude/hooks/pre_push_ci.rb`.** It ports today's shell hook (`.claude/settings.json`, second PreToolUse hook) to Ruby, keeping its behaviour:

1. **Load the rules.** `require File.expand_path("../../lib/collector/push_scope", __dir__)`: the same checkout as the settings, with no environment variable.
2. **Read the tool call.** Read its JSON from stdin with `require "json"` (no `jq`) and take `tool_input.command` and `cwd`.
3. **Detect a push.** Exit 0 unless the command matches today's regex, `(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push`.
4. **Resolve the checkout as today.**
   - Start in `cwd`, falling back to `$CLAUDE_PROJECT_DIR`.
   - Then apply a leading `cd <dir>`.
   - Then apply `-C <dir>`, relative to where the `cd` landed.
   - Then go to `git rev-parse --show-toplevel`.
   - If that checkout's `git rev-parse --git-common-dir` isn't this project's, print `Pre-push: <dir> is not this project's repository; skipping bin/ci.` and exit 0.
   - If there's no executable `bin/ci`, exit 0.
5. **Decide.** Call `Collector::PushScope.decide` with that checkout's current branch.
6. **Run.** Print `Pre-push: running bin/ci <args> in <dir> (<reason>)` to stderr. Run `system("bin/ci", *args, chdir: dir, out: :err)`, so `bin/ci`'s output goes to stderr as today's `>&2` does. On failure, print `Pre-push: bin/ci failed in <dir>. Fix the failing step before pushing.` and exit 2.
7. **Crashes.** Wrap the whole body in a top-level `rescue Exception => error` (re-raising `SystemExit`). Print `Pre-push: hook error (<class>: <message>); blocking the push.` and exit 2. An uncaught exception exits 1, which doesn't block, and FR-4 forbids skipping.

**4.4 `.claude/settings.json`.** Replace the pre-push hook's command with:

```sh
in=$(cat); case "$in" in *push*) ;; *) exit 0 ;; esac; [ "${CLAUDE_CODE_REMOTE:-}" = true ] && [ -d /opt/rbenv/shims ] && PATH=/opt/rbenv/shims:$PATH; h="$CLAUDE_PROJECT_DIR/.claude/hooks/pre_push_ci.rb"; command -v ruby >/dev/null && [ -f "$h" ] || { echo 'Pre-push: ruby or the hook script is missing; blocking the push.' >&2; exit 2; }; printf '%s' "$in" | exec ruby "$h"
```

The shell `case` keeps Ruby from starting on every Bash call. A missing `ruby` or hook script blocks the push instead of exiting 127 or 1, which wouldn't block (FR-4). In the JSON, escape the double quotes (`\"`); the settings example parses the file, so invalid JSON fails it. Keep `"timeout": 900` and `"onFailure": "block"` (from #148).

Add file-shape examples to `spec/config/ci_definition_spec.rb`:
- both git hooks keep `onFailure: "block"`;
- the pre-push command runs `.claude/hooks/pre_push_ci.rb` and contains no `jq` (AC-3.6).

**4.5 Evidence for `verification.md`.** Use scratch branches in a scratch clone, never pushed.

**Set up the clone:**

1. Clone the worktree into the scratch directory.
2. Point its `origin/main` at this branch's head: `git update-ref refs/remotes/origin/main <035 head>`. Otherwise its `origin/main` lacks spec 035, so a branch from it either isn't documentation-only or runs the old `bin/ci`.
3. Make the scratch branches from that.
4. Run the clone's own `.claude/hooks/pre_push_ci.rb` with `CLAUDE_PROJECT_DIR=<clone>` and the JSON's `cwd` set to the clone, so the project-repository check passes.

Pipe a hand-written tool-call JSON into the script for:

- a documentation-only branch: it runs `bin/ci checks` (AC-3.3);
- a branch touching `docs/export-format/examples/valid/empty-v2.json`: full `bin/ci` (AC-3.4);
- a detached `HEAD`: full `bin/ci`, with the reason (AC-3.5);
- a `git push --tags`: full `bin/ci`, with the reason (AC-3.5).

Commits:
- `feat(hooks): classify a branch's changes and push command for the pre-push hook (spec 035 decision 3)`;
- `feat(hooks): skip RSpec before a documentation-only push (spec 035 Story 3)`.

## Phase 5: Documents (AC-4.1–AC-4.4)

**`docs/architecture/release-and-deploy.md`** (AC-4.1). Each change cites spec 035's criteria inline.

- **The "One CI definition" rule (line 46):** the workflow's `checks` and `rspec` jobs and the pre-push hook run `bin/ci` groups.
- **The "Nothing is published" rule (line 47):** every group, gathered by the `ci` job.
- **The full-history rule (line 59):** the `checks` and `rspec` jobs.
- **The "A workflow run" table:** the jobs, with `checks`/`rspec`/`ci` in place of the `ci` column's single `bin/ci`.
- **A new rule:** shards come from `spec/support/runtime_log.txt` through `Collector::CiShard`; a stale log changes only balance; refresh it with `script/ci/record_runtime_log`; each shard prints its seed and replay with `CI=true`; the CI tooling under `lib/collector` stays out of the image.
- **Refresh every `ci.yml:NN` and `config/ci.rb:NN` line reference** in the document (for example `config/ci.rb:5` at line 57) against the new files.
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

**The metric (AC-2.4).** Measure each attempt on its own: take `run_started_at` from `GET /repos/plainprogrammer/Collector/actions/runs/<id>/attempts/<n>`, and the `ci` job's `completed_at` from `…/runs/<id>/attempts/<n>/jobs`. A re-run attempt has its own `run_started_at`, so it is a valid new measurement.

1. **Baseline.** Three green `main` runs of the old workflow after #147 and #148 merged.
   - The two merges give two. Take the third from the next merge to `main` by any session before Phase 3's workflow lands there.
   - If none comes, ask the maintainer: re-running a `main` run also re-runs `publish` and re-pushes `edge` and `sha-*`.
   - Green pull-request runs of the old workflow with both fixes (#148's own runs) are the fallback; record which were used.
2. **M = 4.** Three green attempts on #149 after Phase 3: the pushes of Phases 4 and 5, then re-runs of the last run as needed. Empty commits to trigger CI aren't allowed.
3. **M = 3 (AC-2.5).**
   - A temporary commit changes the matrix to `[ 1, 2, 3 ]`; the run line and name follow from `strategy.job-total`, and the AC-2.1 example accepts any contiguous `1..N`.
   - Take one push and two re-runs.
   - Then revert, or keep 3 if the stop rule says so (decision 7: keep 4 only if its median is at least 30 s faster).
4. **AC-2.2 and AC-2.3, in one run.** A temporary commit adds a system spec that fails only on GitHub:

   ```ruby
   # spec/system/ac_2_2_probe_spec.rb: temporary, reverted after Phase 6 step 4 (spec 035 AC-2.2, AC-2.3).
   require "rails_helper"

   RSpec.describe "Spec 035 AC-2.2 probe", type: :system do
     it "fails only on GitHub" do
       visit "/"
       raise "AC-2.2 probe" if ENV["GITHUB_ACTIONS"]
     end
   end
   ```

   The pre-push hook's local `bin/ci` passes, so the push goes through. Check that:
   - that shard and `ci` fail, and the other shards finish;
   - no `image` job runs;
   - the shard's log shows the replay;
   - the shard uploads `screenshots-N`.

   Then revert the probe.
5. **AC-2.6.** Pull-request runs check out the merge ref, not the branch head.
   1. Take the SHA from the shard log's checkout line ("HEAD is now at …").
   2. `git fetch origin <that sha>` (the merge ref moves on every push or `main` change), check out that SHA in a scratch worktree, and print `Collector::CiShard.new(index: N, total: M).files` there with `bundle exec ruby -e` (the bundle finds `parallel_tests`; no Rails).
   3. Compare that list with the shard's printed file count and replay line.
6. **AC-3.7.** Decision 3 diffs the whole branch, and `035-ci-shards` changes code, so its pushes never take the fast path. Two pieces of evidence instead:
   - **The workflow has no filter.** `on:` in `ci.yml` has no `paths` or `paths-ignore`, so any push runs every group. Record this.
   - **A documentation-only run.** Approved by the maintainer on 2026-10-31 as an end-to-end test.
     1. Make a throwaway branch **from `origin/main`** with one Markdown line in `docs/`. The hook's diff is then that one line, so it takes the fast path; record its message.
     2. Open its draft PR ([[draft-pr-on-first-push]]) with **`--base 035-ci-shards`**, so the PR's merge ref carries the new `ci.yml`. A PR into `main` would run the old single-`ci` workflow.
     3. Record that its run ran `checks`, every shard and `ci`.
     4. Note that the local run used `main`'s `bin/ci`, which ignores the `checks` argument until 035 merges.
     5. Close the PR and delete the branch.

Record everything in `verification.md`, then run the full `bin/ci` once at the end.
