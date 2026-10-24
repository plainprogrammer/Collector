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

  describe "the image job" do
    let(:image_job) { workflow.dig("jobs", "image") }
    let(:steps) { image_job["steps"] }
    let(:names) { steps.map { it["id"] || it["name"] } }
    let(:proof) { steps.find { it["run"].to_s.start_with?("bin/upgrade-smoke") } }
    let(:ruby) { steps.find { it["uses"].to_s.start_with?("ruby/setup-ruby") } }

    it "runs bin/upgrade-smoke for each architecture after the backup smoke test and before the push, on every event (AC-7.1)", :aggregate_failures do
      expect(proof["run"]).to eq("bin/upgrade-smoke auto collector:smoke --platform ${{ matrix.platform }}")
      expect(names.index(proof["name"])).to be_between(names.index("Backup smoke test"), names.index("push")).exclusive
      expect(proof).not_to have_key("if")
      expect(image_job.dig("strategy", "matrix", "include").size).to eq(2)
    end

    it "sets up the host Ruby for the comparer before it, outside the proof's own limit (decision 5, AC-7.4)", :aggregate_failures do
      expect(names.index(ruby["name"])).to be < names.index(proof["name"])
      expect(ruby["with"]).to include("bundler-cache" => true)
      expect(image_job.dig("env", "BUNDLE_WITHOUT")).to eq("development:test")
      expect(proof["timeout-minutes"]).to eq(12)
    end

    it "fetches the full history and the tags, because the proof resolves the previous release from them (AC-8.5)" do
      expect(checkout("image").dig("with", "fetch-depth")).to eq(0)
    end

    it "adds no secret, login or permission of its own, and can't be skipped past (AC-1.6, AC-7.2, FR-6)", :aggregate_failures do
      expect(proof.to_s).not_to include("secrets.")
      expect(proof).not_to have_key("continue-on-error")
      expect(image_job).not_to have_key("continue-on-error")
      expect(image_job["permissions"]).to eq("contents" => "read", "packages" => "write")
      expect(workflow.dig("jobs", "publish", "needs")).to eq("image")
    end
  end
end
