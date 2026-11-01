require "rails_helper"
require "json"

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
  end
end
