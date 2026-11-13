# Implementation Plan: A Start Refuses a Volume That Holds a Prices Database and No Primary (spec 086, issue #375)

**Spec:** `docs/specs/086-start-refuses-orphan-prices/spec.md` (Approved v0.3.1) · **Issue:** #375 · **Branch:** `086-start-refuses-orphan-prices` · **Created:** 2026-11-13
**Status:** Approved (Gate B, 2026-11-13, the coordinator under the maintainer's delegation; the maintainer ruled decisions 1 to 3 as recommended on 2026-11-13). Plan review (Fable, read-only, 2026-11-13): APPROVE WITH CHANGES (0 blocking, 4 major, 9 minor), all fixed below. Decisions 1, 2 and 3 were the maintainer's and are ruled as recommended (2026-11-13): the plan puts each decision's code in a task of its own (T1 for decision 2 and 7, T2 for decision 3, T3 for decision 1), so a different ruling changes one task.

## Context

A container started on a volume that holds `production_prices.sqlite3` and no `production.sqlite3` (a `backup:restore` killed between its two placings) creates a blank primary and keeps stale prices. The start must refuse it before `db:prepare`, say why and what to do, and exit non-zero. The check is `Collector::StartCheck` (`lib/collector/start_check.rb`), run by a task `start:check` (`lib/tasks/start.rake`, no `:environment`), called from `bin/docker-entrypoint` in the `if` that runs `db:prepare`, before it. It reads the places of the files from `Collector::Backup::Databases` and the file system's metadata, and opens no database.

## Global Constraints

- **Repo rules:** `CLAUDE.md`, `.claude/rules/*.md`.
  - Spec types are tagged (`type: :model|:request|:task|:config`); `RSpec/ExampleLength` max 15 lines; multi-expectation examples use `:aggregate_failures`.
  - Prose documents are verified by reading and recorded in `verification.md`, never from RSpec (`.claude/rules/testing.md`).
- **One commit per task, test first** (red, implement, green, RuboCop). Conventional Commits with `(#375)`; the trailer is the attribution reminder in force at commit time (a Sonnet implementer's commits name Sonnet 5.5). One git operation per shell call; `git add` and `git commit` in separate calls. Every `git grep` ends with `':!.kamal/secrets'`. Never read `.kamal/secrets`, `config/master.key`, `.env*`, `storage/` or any `*.sqlite3`.
- **No agent runs the `sqlite3` command** (it prompts the maintainer). A reviewer is read-only and runs nothing; a fact about SQLite files comes from a spec example that builds a database under `tmp/` or the scratch directory. **Put this sentence in every subagent prompt.**
- **Prompting files:** `Dockerfile`, `.github/workflows/**`, `config/deploy*.yml` and `.claude/settings.json` are not touched (spec decision 1). `bin/docker-entrypoint` is a plain edit.
- **The backup tasks still boot nothing:** `lib/collector/backup/` is not changed except `restore.rb`'s advice and two comments (T4) and the `Databases` comment (T1). `start:check` has no `:environment` prerequisite.
- **Core names no collectible:** the new files name none (`spec/*_core_spec.rb` read whole files, comments included).
- **Comments:** every public class and method gets a summary (the comment ratchet), with `@param`/`@return`; no `{…}` outside YARD links; `@see file:release-and-deploy.md`. The `Databases` comment records its second user.
- **Shared test database:** one test run at a time in this worktree. After merging `origin/main`, run `bin/rails db:prepare` before any spec run.
- **No migration, no export change, no gem, no JS, no UI.** `spec/support/runtime_log.txt` is not refreshed.

## Goal

A server start on orphan prices exits 1 before `db:prepare` with the message of FR-3; every other start is as before; the restore's advice and the documents say so; a smoke leg proves it on the image.

## Pre-implementation gates

- **Simplicity (≤3 components): pass.** (1) `Collector::StartCheck` and its task; (2) the entrypoint call; (3) the smoke leg and the documents.
- **Anti-abstraction: pass.** No wrapper; the class reads `Backup::Databases` as it is and returns lines.
- **Integration-first: pass.** The class and its contract first (T1), the task (T2), the entrypoint (T3).

## Files

| File | Change | Responsibility |
|---|---|---|
| `lib/collector/start_check.rb` | create | the decision and the message |
| `lib/tasks/start.rake` | create | `start:check`: prints the lines on stderr, exits 1 |
| `config/application.rb` | edit | `collector/start_check.rb` joins the `autoload_lib(ignore:)` list |
| `bin/docker-entrypoint` | edit | calls `./bin/rails start:check` before `db:prepare`; its comment |
| `lib/collector/backup/databases.rb` | edit (comment) | records the second user |
| `lib/collector/backup/restore.rb` | edit | the advice and two comments |
| `spec/lib/collector/start_check_spec.rb`, `spec/start_check_spec.rb` | create | class-level and process-level proofs |
| `spec/lib/collector/backup/restore_spec.rb` | edit | the exact advice text |
| `bin/backup-smoke` | edit | the AC-4.1 and AC-4.2 leg; its header comment |
| `README.md`, `docs/backup-restore.md`, `docs/releasing.md`, `docs/architecture/release-and-deploy.md`, `docs/architecture/prices.md`, `docs/roadmap.md`, `CLAUDE.md` | edit | FR-4's list |
| `docs/specs/086-start-refuses-orphan-prices/verification.md` | create | evidence |

## T0: Bring `main` in

`git merge origin/main` (a merge commit, no rebase), then `bin/rails db:prepare`. Main holds #410 and #412 (the licences guard: this branch adds no gem, pin, font or icon, so no manifest entry is owed).

## Phase 1: The check (decisions 2 and 7)

### T1: `Collector::StartCheck`, test first

**Implements:** FR-1, FR-3; decisions 2, 4, 7 · **Satisfies:** AC-1.1 to AC-1.4, AC-1.7, AC-1.8, AC-2.1 to AC-2.4 (class level), AC-1.2's text
**Files:** `lib/collector/start_check.rb`, `spec/lib/collector/start_check_spec.rb`, `config/application.rb`, the comment of `lib/collector/backup/databases.rb`

**Red first** (`spec/lib/collector/start_check_spec.rb`, `type: :model`, tag `:backup`, built on `databases_for(scratch("volume"))`, which returns a `Collector::Backup::Databases` of the five production names in a scratch directory; the spec starts with `require Rails.root.join("lib/collector/start_check").to_s`). One example per state, each asserting `refusal` (an array of lines or nil):

- nil: empty directory (AC-2.1); primary (non-empty file) and prices; primary only; only queue, cache and cable files and their sidecars (AC-2.4).
- lines: the prices file only (AC-1.1; non-empty and zero-byte contents alike, AC-1.4); each of `-wal`, `-shm`, `-journal` alone (AC-1.3, the lines name that sidecar's path); the prices file and a zero-byte primary; the prices file and a dangling-symlink primary (`File.symlink(scratch_path("nowhere"), …)`); the prices file with only `production.sqlite3-wal` (AC-1.7, AC-1.8).
- The lines (AC-1.2), as one `include` per sentence over `lines.join(" ")`: the directory; the prices file's path; `no primary database`; `-wal, -shm and -journal`; `restore again onto a volume that holds no other Collector database`; `start Collector blank`; `Run nothing else on the volume`; `Nothing was changed`. In the AC-1.7/AC-1.8 examples the primary file or sidecar found is named and listed among the files to remove.
- Never opens a file: every file's bytes and mtime are as they were after the call (AC-1.1); a prices file holding the text `not a database` is refused all the same.
- A configuration with no prices path (`Backup::Databases.new("primary" => …)`) returns nil.

**Then** `lib/collector/start_check.rb`:

```ruby
require_relative "backup/databases"

module Collector
  # The container's start check (spec 086): decides, from which database files are on the volume, whether a server start
  # may go on, and words the refusal. A prices file or one of its sidecars with no primary is the state a +backup:restore+
  # killed between its two placings leaves, and a start on it would create a blank primary and keep prices that the new
  # catalog's printings don't own (spec 081 decision 8). It asks the file system for existence and size only: it opens no
  # database, creates no file and needs no secret, a connection or the application's initializers.
  #
  # A primary is *there* when it exists following a symlink and isn't empty: a dangling link or an empty file isn't one
  # (spec 086 decision 7). The prices file and each sidecar count when they exist or are symlinks, dangling or not, as
  # the restore counts them (+Backup::Databases#occupied+).
  # @see file:release-and-deploy.md
  class StartCheck
    # The refusal of the volume Collector would start on, or nil when the start may go on.
    #
    # @param databases [Backup::Databases] where the files are; the configured ones by default
    # @return [Array<String>, nil] the lines to print on standard error
    def self.refusal(databases: Backup::Databases.configured) = new(databases:).refusal

    # @param databases [Backup::Databases]
    def initialize(databases:)
      @databases = databases
    end

    # The three sentences that refuse this volume, or nil when the start may go on.
    #
    # @return [Array<String>, nil]
    def refusal
      return unless @databases.prices

      prices = present(@databases.prices)
      return if prices.empty? || primary_there?

      lines(prices, present(@databases.primary))
    end

    private
      def primary_there? = @databases.primary.exist? && @databases.primary.size.positive?

      # The files among a database's file and its sidecars that exist or are links.
      def present(path) = Backup::Databases::SIDECARS.map { Pathname("#{path}#{it}") }.select { it.exist? || it.symlink? }

      # What a leftover primary file is, for the message: a broken link, a sidecar left behind, or an empty file.
      def kind(path)
        return "a broken link" if path.symlink? && !path.exist?

        path.to_s == @databases.primary.to_s ? "an empty file" : "a sidecar left behind"
      end

      def lines(prices, leftovers)
        names = leftovers.map { it.basename.to_s }
        instead = leftovers.empty? ? "" : " (it holds #{leftovers.map { "#{it.basename}, #{kind(it)}" }.join("; ")} instead, which is not a database)"
        removal = [ "#{@databases.prices.basename} and its -wal, -shm and -journal files", *names ].then { it.size > 2 ? "#{it[..-2].join(", ")} and #{it.last}" : it.join(" and ") }
        [ "Collector did not start: the storage directory #{@databases.directory} holds #{prices.join(", ")} and no primary database#{instead}.",
          "A backup:restore that stopped between placing the prices database and the primary leaves this state. Starting here would create a blank primary and keep these prices, which the new catalog's printings don't own.",
          "Remove #{removal}, then restore again onto a volume that holds no other Collector database, or start Collector blank. Run nothing else on the volume meanwhile. Nothing was changed." ]
      end
  end
end
```

`config/application.rb`: add `collector/start_check.rb` to the `autoload_lib(ignore:)` list with a one-line comment (required by path, never autoloaded). `lib/collector/backup/databases.rb`'s class comment gains "It is also read by `Collector::StartCheck` (spec 086), which asks only for the primary and prices paths, the directory and the sidecar names."

Green: `bin/rspec spec/lib/collector/start_check_spec.rb`; `bin/rubocop -a`. Commit: `feat(start): refuse a start on orphan prices, as a class (#375)`.

**Decision 7's measure, in the spec file:** one example runs the one-off command decision 7 is about in a child, `app_command(path, "runner", "ActiveRecord::Base.lease_connection.execute('select 1')")` on a scratch path that doesn't exist (the suite's own pool is left alone), then reads `File.size(path)` and asserts it is `> 0` or `== 0`, whichever it is; the implementer reports which to the supervisor, who records it in `verification.md` and corrects the Non-Goals sentence and decision 7 of the spec if the premise was wrong (spec review round 2 M1 predicts more than zero bytes, in which case the spec's limit stands as written and nothing changes).

## Phase 2: The task (decision 3)

### T2: `start:check`, and the guard that keeps it off the boot path

**Implements:** FR-2; decision 3, 5 · **Satisfies:** AC-2.6
**Files:** `lib/tasks/start.rake`, `spec/start_check_spec.rb` (the guard example)

**Red first:** in `spec/start_check_spec.rb` (`type: :task`, tag `:backup`, `require "rake"`), the example of `spec/backup_boot_spec.rb:23`'s shape: `Rails.application.load_tasks unless Rake::Task.task_defined?("start:check")`, then `expect(Rake::Task["start:check"].all_prerequisite_tasks.map(&:name)).not_to include("environment")`; and a second example reading text: `git grep`-free, by `Rails.root.glob` over `config/initializers/**/*.rb`, `config/application.rb` (minus its `autoload_lib(ignore:)` line), `config/environments/*.rb` and `app/**/*.rb`, none contains `StartCheck` or `start_check` once comment lines (`line.sub(/(\A|\s)#.*/, "")`, as `spec/smoke_scripts_spec.rb:24` strips them) and `config/application.rb`'s `autoload_lib(ignore:)` line are left out: T1's new comment names the file.

**Then** `lib/tasks/start.rake`:

```ruby
require Rails.root.join("lib/collector/start_check").to_s

# The container's start check (spec 086): bin/docker-entrypoint runs it before db:prepare on a server start. It has no
# :environment prerequisite, so it initializes nothing: no initializer, no database connection that could create a
# primary, no secret_key_base. Nothing but the entrypoint calls it.
namespace :start do
  desc "Refuse a start on a volume that holds the prices database and no primary (exit 1 with the reason)"
  task :check do
    lines = Collector::StartCheck.refusal
    next unless lines

    warn(*lines)
    exit 1
  end
end
```

Green; RuboCop. Commit: `feat(start): the start:check task, with no :environment (#375)`.

## Phase 3: The entrypoint (decision 1)

### T3: call it before `db:prepare`

**Implements:** FR-2, FR-3 · **Satisfies:** AC-1.1, AC-1.5, AC-1.6, AC-2.1 to AC-2.3, AC-2.5, AC-2.7
**Files:** `bin/docker-entrypoint`, `spec/start_check_spec.rb`

**Red first** (process level, `spec/start_check_spec.rb`, `type: :task`, `:backup`; the file already holds T2's examples). A helper runs the real entrypoint, `Open3.capture3(env, Rails.root.join("bin/docker-entrypoint").to_s, "echo", "./bin/rails", "server", chdir: Rails.root.to_s)`, with `env` from `app_command`'s shape (`RAILS_ENV=test`, `DATABASE_URL`, `PRICES_DATABASE_URL` of a scratch `production.sqlite3` and `production_prices.sqlite3`, and a fresh `SCHEMA` path): the entrypoint's condition matches `echo ./bin/rails server`, the check and `db:prepare` run for real against the scratch files, and its `exec` runs `echo`, so "the server was not run" is the absence of `./bin/rails server` in standard output.

- Prices file (non-empty, written as the text `stale`) and no primary: status 1; stdout empty; stderr holds the message of AC-1.2; the scratch directory's files and bytes are unchanged (AC-1.1).
- A killed restore (AC-1.5): context `:committed`; `seed_instance`, `seed_prices(entry_ids: …)`, `create_backup`, `run_killed_at(:prices_placed, …)` exactly as `spec/lib/collector/backup/restore_spec.rb:185` does (read it and its `killed_child`), then the entrypoint on that volume refuses, and the prices file is the restored one (its bytes are those the restore placed).
- No secret (AC-1.6): the same entrypoint with `RAILS_ENV=production`, `SECRET_KEY_BASE` and `SECRET_KEY_BASE_DUMMY` nil, `RAILS_MASTER_KEY` of 32 zeros (as `backup_boot_spec`'s `production` helper), the scratch URLs: the stderr is the message and does not mention `secret_key_base`.
- Pass-through: no files, status 0 and stdout `./bin/rails server` and both scratch files created (AC-2.1); primary and prices: status 0 (AC-2.2; build them by running the entrypoint once on the empty directory); primary only: status 0 and the prices file is created (AC-2.3).
- A one-off command on the refused volume (AC-2.5): `bin/rails runner 'puts :ok'` is not touched by the check — assert instead that the entrypoint run with `echo hello` (condition false) prints `hello`, status 0, on the refused volume.
- The way out (AC-2.7), both halves in the AC-1.5 example (`:committed`, marked `# rubocop:disable RSpec/ExampleLength -- one scenario`, as `restore_spec.rb:185` is): after the refusal, delete the prices file and call `restore_backup(path, volume:)` (the restore succeeds with the killed run's `collector-restore.partial` left behind, `restore_spec.rb:194-196`), then the entrypoint passes with status 0 and the restored rows are there; and a separate example: refused volume, the prices file and sidecars removed, the entrypoint passes as a new instance.
- **Assertions.** A passing start runs `db:prepare`, which migrates (no schema file) and prints on stdout: assert `out.lines.last == "./bin/rails server\n"`, never equality. The refusal asserts `err.lines(chomp: true)` equals the three lines exactly (FR-3's "no stack trace"; `backup_boot_spec.rb:37` does the same). The `SCHEMA` path is fresh per entrypoint invocation, not per example (`app_command` does that per call): an example that runs the entrypoint twice must not load run 1's dump into run 2. "Primary only" (AC-2.3) is built as `spec/backup_prices_spec.rb:21-27` builds a volume (`copy_of_instance` under `:committed`), not by deleting after a first run.
- **Red-first, honestly.** Before the entrypoint edit only the refusal examples (the message), AC-1.5 and AC-1.6 are red; the pass-through, `echo hello` and way-out examples are green from the start, and are regression guards. A refusal's red is the missing message, not the exit status: `db:prepare` already fails on a prices file that isn't a database.

**Then** `bin/docker-entrypoint`:

```bash
#!/bin/bash -e

# If running the rails server then refuse a volume that holds a prices database and no primary (spec 086), then create or
# migrate existing database. The check is its own statement: a failure stops the start here (bash -e), before db:prepare
# can create a blank primary.
if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
  ./bin/rails start:check
  ./bin/rails db:prepare
fi

exec "${@}"
```

Green: `bin/rspec spec/start_check_spec.rb`; RuboCop. Commit: `feat(start): the entrypoint refuses orphan prices before db:prepare (#375)`.

## Phase 4: The restore's advice

### T4: advice and comments

**Implements:** FR-4 · **Satisfies:** AC-3.1
**Files:** `lib/collector/backup/restore.rb`, `spec/lib/collector/backup/restore_spec.rb`

**Red first:** `restore_spec.rb:129`'s expected advice changes its last sentence to `Collector refuses to start on this volume as it is.`; run it, it fails. **Then** in `restore.rb` change the advice string at `not_fresh` the same way, and the two comments (the class comment's "#375 owns a start-up check", and the one on `not_fresh`, "and never to start Collector on it") to say that a start now refuses the volume (spec 086). Nothing else of `Restore` changes. Green: `bin/rspec spec/lib/collector spec/backup_prices_spec.rb`. Commit: `fix(backup): the restore's advice says a start refuses the volume (#375)`.

## Phase 5: The smoke leg

### T5: AC-4.1 and AC-4.2 in `bin/backup-smoke`

**Satisfies:** AC-4.1, AC-4.2 · **File:** `bin/backup-smoke` (a script, not a prompting file; `spec/smoke_scripts_spec.rb` guards its pipes: never pipe into an early-exiting reader)

Before the final `echo "OK: …"`, add a leg, in the script's style (outputs captured first, tested after):

```bash
echo "== a start refuses a volume that holds a prices database and no primary (spec 086 AC-4.1, AC-4.2)"
volume_d="collector-backup-smoke-d-$tag"
volumes+=("$volume_d")
"$cli" volume create "$volume_d" >/dev/null
"$cli" run --rm -u 1000 ${run_flags[@]+"${run_flags[@]}"} -v "$volume_d:/rails/storage" -v "$work/restore:/backups:ro" -e SECRET_KEY_BASE_DUMMY=1 \
  "$restore_image" bin/rails "backup:restore[/backups/$file]" >/dev/null 2>&1 || fail "the restore for the refusal leg failed"
# the state a killed restore leaves, made without killing anything: the primary and its sidecars removed
"$cli" run --rm -u 0 -v "$volume_d:/rails/storage" "$restore_image" sh -c 'rm -f /rails/storage/production.sqlite3 /rails/storage/production.sqlite3-wal /rails/storage/production.sqlite3-shm /rails/storage/production.sqlite3-journal && test -e /rails/storage/production_prices.sqlite3' >/dev/null || fail "the refusal leg's volume wasn't made"
refused_name="backup-smoke-refused-$tag"
containers+=("$refused_name")
"$cli" run -d --name "$refused_name" ${run_flags[@]+"${run_flags[@]}"} -v "$volume_d:/rails/storage" \
  -e SECRET_KEY_BASE="a-secret-for-the-refused-start-0000004" -e HTTP_PORT=8080 "$restore_image" >/dev/null
# bounded: an image that doesn't refuse starts a server that never exits, and must fail here, naming the spec
for _ in $(seq 1 "$attempts"); do
  [ "$("$cli" inspect -f '{{.State.Running}}' "$refused_name")" = "false" ] && break
  sleep 2
done
[ "$("$cli" inspect -f '{{.State.Running}}' "$refused_name")" = "false" ] \
  || fail "spec 086 AC-4.1: the image started on a volume that holds a prices database and no primary (still running after $((attempts * 2)) s)"
[ "$("$cli" inspect -f '{{.State.ExitCode}}' "$refused_name")" = "1" ] || fail "spec 086 AC-4.1: the refused start didn't exit with status 1"
refused="$("$cli" logs "$refused_name" 2>&1)"
grep -q "production_prices.sqlite3" <<<"$refused" && grep -q "restore again" <<<"$refused" && grep -q "Nothing was changed" <<<"$refused" \
  || fail "spec 086 AC-4.1: the refusal didn't carry the message; it printed:"$'\n'"$refused"
"$cli" rm -f "$refused_name" >/dev/null
[ "$("$cli" run --rm -u 0 -v "$volume_d:/rails/storage" "$restore_image" sh -c 'test ! -e /rails/storage/production.sqlite3 && echo none')" = "none" ] \
  || fail "spec 086 AC-4.1: the refused start created a primary"
"$cli" run --rm -u 0 -v "$volume_d:/rails/storage" "$restore_image" sh -c 'rm -f /rails/storage/production_prices.sqlite3 /rails/storage/production_prices.sqlite3-wal /rails/storage/production_prices.sqlite3-shm /rails/storage/production_prices.sqlite3-journal' >/dev/null || fail "removing the prices files failed"
d="backup-smoke-d-$tag"
start "$d" "$volume_d" "a-fourth-secret-of-the-fourth-instance-0004" "$restore_image"
blank="$("$cli" exec "$d" bin/rails runner 'puts [ User.count, PricesRecord.lease_connection.select_value("SELECT count(*) FROM current_prices"), %w[production production_prices production_cache production_queue production_cable].all? { Rails.root.join("storage/#{it}.sqlite3").exist? } ].join(",")' 2>&1 | tail -n 1)"
[ "$blank" = "0,0,true" ] || fail "spec 086 AC-4.2: the start after removing the prices files wasn't a blank instance; got: $blank"
```

The container is run detached and its wait is bounded, so an image that doesn't refuse fails the leg and names the spec instead of hanging until the job's timeout (plan review M2); the exit status is asserted to be exactly 1, so a kill (137) or a crash isn't taken for the refusal. This deviates from AC-4.1's word "foreground" (the spec's observable is the status, the log and the volume): recorded in `verification.md`. The `grep … && grep … || fail` line uses herestrings, not pipes into `grep -q`. Update the script's header comment (one sentence: the refusal leg). Run `bin/rspec spec/smoke_scripts_spec.rb` and `bash -n bin/backup-smoke`. Commit: `test(smoke): a start refuses a volume with a prices database and no primary (#375)`. The run against a built image is T7.

## Phase 6: The documents (FR-4, AC-3.2)

### T6: documents, `verification.md` skeleton

Edit, each with its source (spec 086 FR-x) inline, one commit per two or three files:

- `README.md:465`, `docs/backup-restore.md:39`: a start of Collector refuses the volume, with the message's three parts; remove "Don't start" / "Never start" and "#375 will make…".
- `docs/releasing.md` (the upgrade notes, newest first): a note that a start can now refuse a volume with a prices file and no primary, and what to do.
- `docs/architecture/release-and-deploy.md`: line 85 (the server-start rule gains the check before `db:prepare`, and its citation `bin/docker-entrypoint:4-6` becomes the new line range), line 138 (a start refuses it), line 312 (#375 built, spec 086), the Sources and Named-behaviour lists where they cite the restore's advice; the distillation-log row at line 326 stays.
- `docs/architecture/prices.md:59` (its Sources).
- `docs/roadmap.md:111`: #375 done, spec 086.
- `CLAUDE.md`'s status paragraph: one clause (a start refuses a volume with a prices database and no primary, spec 086); the `Release and deploy` bullet's spec list gains 086 only if the area doc's source list does.
- the comment of `bin/docker-entrypoint` is T3's; `bin/backup-smoke`'s header is T5's.

Create `docs/specs/086-start-refuses-orphan-prices/verification.md` with the AC table (each AC, its evidence: the example, or the document line read). AC-1.3, 1.4, 1.7, 1.8 and 2.4 are proven at class level, with the wiring proven by AC-1.1 and AC-1.5; AC-2.5's evidence also cites `restore_spec.rb:124-131` and `:185` (a second restore refuses the volume itself). Commits: `docs(…): … (#375)`.

## Phase 7: The proof on the image (needs the container engine and a CI slot)

### T7: run the leg

Build the branch's image (`README.md`, Building from source: three `--build-arg` flags for `bin/image-smoke`), run `bin/image-smoke <image>` and `bin/backup-smoke <image>` (`.claude/memory/container-engine-colima-macos.md`: append `/opt/homebrew/bin` to the PATH, the `mktemp` shim, `TMPDIR` under the worktree). AC-4.3: also build an image of `origin/main` from `git archive` and run `bin/backup-smoke <branch image>`'s new leg's logic against it, expecting the AC-4.1 failure: the supervisor runs it once and records both runs in `verification.md`. Not a `bin/ci` step; run it before the full `bin/ci`.

## Finish

Implementation review (Opus, read-only, no `sqlite3`), recorded in `verification.md` under `## Implementation review`; `bin/ci` (with a slot); `session-wrap`; `distill-feature` (digest to the coordinator before it is committed); push (with a slot), a draft PR that closes #375.

## Risks

- **Decision 7's measure** may show a connection leaves a one-page primary: the spec's limit already says so (T1's measure).
- **`db:prepare` in the entrypoint examples** runs for real in the test environment against scratch files: `SCHEMA` absent per command as `app_command` does, so neither `db/schema.rb` nor `db/prices_structure.sql` is written.
