require "rails_helper"
require "yaml"

# File-shape checks for the upgrade proof (spec 031). The behaviour is in the other specs of this directory.
RSpec.describe "Upgrade proof files" do
  let(:workflow) { YAML.load_file(Rails.root.join(".github/workflows/ci.yml")) }

  def checkout(job) = workflow.dig("jobs", job, "steps").find { it["uses"].to_s.start_with?("actions/checkout") }

  it "runs the migration guard in bin/ci (AC-8.1, AC-8.6)" do
    expect(Rails.root.join("config/ci.rb").read).to include('step "Upgrade: released migrations unchanged", "ruby script/upgrade/guard.rb"')
  end

  it "fetches the full history and the tags in the ci job, which runs the guard (AC-8.5, AC-7.6)", :aggregate_failures do
    expect(checkout("ci").dig("with", "fetch-depth")).to eq(0)
    run_lines = workflow.dig("jobs", "ci", "steps").filter_map { it["run"] }
    expect(run_lines).not_to include(a_string_matching(/upgrade-smoke|docker|podman/))
  end

  it "keeps bin/upgrade-smoke out of the image, and the image smoke test checks it (FR-8)", :aggregate_failures do
    rules = Rails.root.join(".dockerignore").readlines(chomp: true).map(&:strip)
    expect(rules).to include("/bin/upgrade-smoke", "/script")
    expect(Rails.root.join("bin/image-smoke").read).to include("bin/upgrade-smoke")
  end

  it "is executable and starts with a Ruby shebang", :aggregate_failures do
    path = Rails.root.join("bin/upgrade-smoke")
    expect(path.executable?).to be(true)
    expect(path.readlines.first).to eq("#!/usr/bin/env ruby\n")
  end
end
