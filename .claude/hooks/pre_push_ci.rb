#!/usr/bin/env ruby
# The pre-push hook (spec 035 Story 3, FR-4), run by .claude/settings.json with the Bash tool call's JSON on stdin.
# Before a push from this project's repository it runs bin/ci, or bin/ci checks for a documentation-only branch
# pushed with a plain push form (decision 3). It exits 0 only for a command that isn't a push, a resolved checkout
# outside this repository, or a checkout without an executable bin/ci; every error blocks the push (exit 2).

begin
  require "json"
  require File.expand_path("../../lib/collector/push_scope", __dir__)

  scope = Collector::PushScope
  # The tool call's JSON is UTF-8 whatever the locale; under LANG=C Ruby would read it as US-ASCII.
  input = JSON.parse($stdin.read.force_encoding(Encoding::UTF_8))
  command = input.dig("tool_input", "command").to_s
  exit 0 unless scope.push?(command)

  common_dir = ->(dir) { File.realpath(File.expand_path(scope.git!(dir, "rev-parse", "--git-common-dir").strip, dir)) }
  project_dir = ENV["CLAUDE_PROJECT_DIR"].to_s.empty? ? File.expand_path("../..", __dir__) : ENV["CLAUDE_PROJECT_DIR"]
  project = common_dir.call(project_dir)

  # The checkout the push runs in: the tool call's cwd, then a leading `cd <dir>`, then `git -C <dir>`.
  parsed = scope.parse(command, current_branch: nil)
  dir = input["cwd"].to_s.empty? ? project_dir : input["cwd"]
  dir = File.expand_path(parsed.cd, dir) if parsed.cd
  dir = File.expand_path(parsed.git_c, dir) if parsed.git_c
  # Only a resolved checkout of another repository is skipped (decision 3). A directory that can't be resolved runs
  # the full bin/ci in this project's checkout (FR-4); if that can't be resolved either, the push is blocked.
  checkout, unresolved = begin
    raise scope::Unknown, "the directory holds a shell expansion" if [ parsed.cd, parsed.git_c ].compact.any? { |text| text.match?(/[$`]/) }

    root = scope.git!(dir, "rev-parse", "--show-toplevel").strip
    if common_dir.call(root) != project
      warn "Pre-push: #{root} is not this project's repository; skipping bin/ci."
      exit 0
    end
    [ root, nil ]
  rescue scope::Unknown, SystemCallError => error
    [ scope.git!(project_dir, "rev-parse", "--show-toplevel").strip, "checkout unresolved: #{dir}: #{error.message}" ]
  end
  exit 0 unless File.executable?(File.join(checkout, "bin/ci"))

  args, reason =
    if unresolved
      [ [], unresolved ]
    else
      scope.decide(command, directory: checkout, current_branch: scope.current_branch(checkout))
    end
  warn "Pre-push: running #{[ "bin/ci", *args ].join(' ')} in #{checkout} (#{reason})"
  unless system("bin/ci", *args, chdir: checkout, out: :err)
    warn "Pre-push: bin/ci failed in #{checkout}. Fix the failing step before pushing."
    exit 2
  end
rescue SystemExit
  raise
rescue Exception => error # rubocop:disable Lint/RescueException -- an uncaught error exits 1, which doesn't block (FR-4)
  warn "Pre-push: hook error (#{error.class}: #{error.message}); blocking the push."
  exit 2
end
