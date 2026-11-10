require "rails_helper"
require "json"
require "tmpdir"

# File-shape checks for bin/ci's definition (spec 035). The runs themselves are evidenced in
# docs/specs/035-ci-shards/verification.md (AC-1.1–AC-1.4, AC-1.7, AC-1.9).
RSpec.describe "The CI definition", type: :config do # rubocop:disable RSpec/DescribeClass -- verifies config files
  it "prints the 10 slowest examples on every RSpec run (AC-1.9, decision 8)", :aggregate_failures do
    rspec_commands = Rails.root.join("config/ci.rb").readlines(chomp: true).grep(/"bin\/rspec\b/)

    expect(rspec_commands).not_to be_empty
    expect(rspec_commands).to all(include("--profile 10"))
  end

  it "runs YARD in bin/ci checks, after the style step and not with the RSpec group, and never reads its cache (spec 054 AC-2.3, AC-2.8)", :aggregate_failures do
    lines = Rails.root.join("config/ci.rb").readlines(chomp: true).map(&:strip)
    yard = lines.index('step "Docs: YARD builds without warnings", "bin/yard doc --no-cache"')

    expect(yard).not_to be_nil
    expect(yard).to be > lines.index('step "Style: Ruby", "bin/rubocop"')
    expect(yard).to be < lines.index { it.start_with?('step "Security: Brakeman') }
    expect(yard).to be > lines.index("unless selection.group == :rspec")
    expect(yard).to be < lines.each_index.find { |i| i > lines.index("unless selection.group == :rspec") && lines[i] == "end" }
  end

  it "runs the comment ratchet in bin/ci checks, directly after the YARD step and not with the RSpec group (spec 056 AC-4.1)", :aggregate_failures do
    lines = Rails.root.join("config/ci.rb").readlines(chomp: true).map(&:strip)
    yard = lines.index('step "Docs: YARD builds without warnings", "bin/yard doc --no-cache"')
    ratchet = lines.index('step "Docs: new and changed public code has a comment", "ruby script/yard/comment_ratchet.rb"')
    guarded = lines.index("unless selection.group == :rspec")

    expect(ratchet).not_to be_nil
    expect(ratchet).to eq(yard + 1)
    expect(ratchet).to be > guarded
    expect(ratchet).to be < lines.each_index.find { |i| i > guarded && lines[i] == "end" }
  end

  it "lets a session run bin/ci and its groups without a permission prompt (AC-1.8)" do
    allowed = JSON.parse(Rails.root.join(".claude/settings.json").read).dig("permissions", "allow")

    expect(allowed).to include("Bash(bin/ci)", "Bash(bin/ci *)")
  end

  describe "the git hooks in .claude/settings.json" do
    let(:hooks) do
      JSON.parse(Rails.root.join(".claude/settings.json").read).dig("hooks", "PreToolUse")
        .select { it["matcher"] == "Bash" }.flat_map { it["hooks"] }
    end
    let(:commit_hook) { hooks.find { it["command"].include?("commit") } }
    let(:push_hook) { hooks.find { it["command"].include?("push") } }

    it "keep blocking when they fail or time out (AC-3.6, decision 1)", :aggregate_failures do
      expect(commit_hook).to include("onFailure" => "block")
      expect(push_hook).to include("onFailure" => "block")
    end

    it "run the pre-push hook script in Ruby, with no jq (AC-3.6)", :aggregate_failures do
      expect(push_hook["command"]).to include(".claude/hooks/pre_push_ci.rb")
      expect(push_hook["command"]).not_to include("jq")
      expect(Rails.root.join(".claude/hooks/pre_push_ci.rb")).to exist
    end
  end

  # A session Orca starts has macOS's Ruby 2.6 first on its PATH, so a hook that runs Ruby bare fails and
  # blocks every commit (#270). Each Ruby the hooks run goes through script/worktree/with_mise --optional,
  # which picks .ruby-version's Ruby where mise exists and changes nothing where it doesn't (CI, cloud).
  describe "the Ruby the hooks in .claude/settings.json run (#270)" do
    let(:commands) do
      JSON.parse(Rails.root.join(".claude/settings.json").read).fetch("hooks").values.flatten
        .flat_map { it["hooks"] }.map { it["command"] }
    end
    let(:ruby_commands) { commands.select { it.match?(%r{bin/rubocop|bin/brakeman|pre_push_ci\.rb}) } }

    it "picks the runner from script/worktree/with_mise --optional", :aggregate_failures do
      expect(ruby_commands.size).to eq(3)
      expect(ruby_commands).to all(include("[ -x script/worktree/with_mise ] && w='script/worktree/with_mise --optional'"))
    end

    it "runs RuboCop, Brakeman and the pre-push script through that runner", :aggregate_failures do
      all = ruby_commands.join("\n")

      expect(all).to include("$($w bin/rubocop", "-r $w bin/rubocop", "then $w bin/brakeman", 'exec $w ruby "$h"')
      expect(all).not_to match(%r{(\$\(|-r|then|exec) (bin/rubocop|bin/brakeman|ruby )})
    end
  end

  describe ".claude/hooks/pre_push_ci.rb" do
    # The hook runs with the session's locale, which may be C (US-ASCII), while the tool call's JSON is UTF-8.
    it "lets a command that only mentions push through, whatever its characters and the locale (FR-4)",
       :aggregate_failures do
      input = JSON.generate("tool_input" => { "command" => "grep Pre-push log # ✅ ❌" },
                            "cwd" => Rails.root.to_s)
      env = { "LANG" => "C", "LC_ALL" => "C", "CLAUDE_PROJECT_DIR" => Rails.root.to_s }

      _out, err, status = Bundler.with_unbundled_env do
        Open3.capture3(env, "ruby", Rails.root.join(".claude/hooks/pre_push_ci.rb").to_s, stdin_data: input)
      end

      expect(err).to eq("")
      expect(status.exitstatus).to eq(0)
    end

    # The real hook script against a sandbox project whose bin/ci is a stub (spec 035 decision 3, FR-4).
    context "with a sandbox project", :git_sandbox do
      let(:dir) { File.realpath(Dir.mktmpdir("pre_push_ci")) }
      let(:repo) do
        new_repo(File.join(dir, "repo"), extra_files: { ".gitignore" => "/bin/\n" }).tap do |path|
          stub = File.join(path, "bin/ci")
          FileUtils.mkdir_p(File.dirname(stub))
          File.write(stub, "#!/bin/sh\necho \"STUB bin/ci $*\"\necho \"STUB pwd $(pwd -P)\"\nexit \"${STUB_EXIT:-0}\"\n")
          File.chmod(0o755, stub)
          git!(path, "switch", "-q", "-c", "feature")
        end
      end

      after { FileUtils.remove_entry(dir) }

      def run_hook(command, cwd: repo, stub_exit: "0")
        input = JSON.generate("tool_input" => { "command" => command }, "cwd" => cwd)
        env = GitSandbox::ENV_OVERRIDES.merge("LANG" => "C", "LC_ALL" => "C", "CLAUDE_PROJECT_DIR" => repo,
                                              "STUB_EXIT" => stub_exit)
        _out, err, status = Bundler.with_unbundled_env do
          Open3.capture3(env, "ruby", Rails.root.join(".claude/hooks/pre_push_ci.rb").to_s, stdin_data: input)
        end
        [ err, status.exitstatus ]
      end

      def documentation_only_branch
        git!(repo, "update-ref", "refs/remotes/origin/main", "main")
        FileUtils.mkdir_p(File.join(repo, "docs"))
        File.write(File.join(repo, "docs/a.md"), "x\n")
        git!(repo, "add", "-A")
        git!(repo, "commit", "-q", "-m", "docs")
      end

      it "runs the full bin/ci in the project when a cd directory can't be resolved (FR-4)", :aggregate_failures do
        [
          [ "cd \"$X\" && git push origin main", "$X" ],
          [ "cd /nonexistent && git push", "/nonexistent" ],
          [ "cd `pwd` && git push", "`pwd`" ],
          [ "git -C /nonexistent push", "/nonexistent" ]
        ].each do |command, named|
          err, status = run_hook(command)
          expect(err).to include("running bin/ci in #{repo} (checkout unresolved: "), "#{command}: #{err}"
          expect(err).to include(named), "#{command}: #{err}"
          expect(err).to include("STUB bin/ci \n", "STUB pwd #{repo}\n"), "#{command}: #{err}"
          expect(status).to eq(0), command
        end
      end

      it "skips bin/ci for a checkout of another repository (decision 3)", :aggregate_failures do
        other = new_repo(File.join(dir, "other"))

        err, status = run_hook("cd #{other} && git push")
        expect(err).to include("#{other} is not this project's repository; skipping bin/ci")
        expect(err).not_to include("STUB")
        expect(status).to eq(0)
      end

      it "runs bin/ci checks for a documentation-only branch and an accepted push form (AC-3.3)", :aggregate_failures do
        documentation_only_branch

        err, status = run_hook("git push origin feature")
        expect(err).to include("running bin/ci checks in #{repo} (documentation-only branch (1 file): skipping RSpec)")
        expect(err).to include("STUB bin/ci checks\n")
        expect(status).to eq(0)
      end

      it "blocks the push when bin/ci checks fails (AC-3.3)", :aggregate_failures do
        documentation_only_branch

        err, status = run_hook("git push origin feature", stub_exit: "1")
        expect(err).to include("STUB bin/ci checks\n", "bin/ci failed in #{repo}")
        expect(status).to eq(2)
      end

      it "blocks the push when the full bin/ci fails (FR-4)", :aggregate_failures do
        documentation_only_branch

        err, status = run_hook("git push --tags", stub_exit: "1")
        expect(err).to include("running bin/ci in #{repo} (push form not eligible", "STUB bin/ci \n", "bin/ci failed in #{repo}")
        expect(status).to eq(2)
      end
    end
  end
end
