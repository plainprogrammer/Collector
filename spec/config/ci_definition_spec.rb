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
end
