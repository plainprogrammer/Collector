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
