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
end
