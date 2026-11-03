require "rails_helper"
require "yaml"

# File-shape checks for the advisory response (spec 036): Dependabot's security-update group and the daily audit
# workflow. The criteria that need GitHub (AC-1.3, AC-1.4, AC-2.6 to AC-2.8, AC-2.10) are evidenced in
# docs/specs/036-advisory-response/verification.md; the document criteria (Story 3) are verified by reading.
RSpec.describe "Advisory response files" do
  describe ".github/dependabot.yml" do
    let(:config) { YAML.load_file(Rails.root.join(".github/dependabot.yml")) }

    def update_for(ecosystem) = config["updates"].find { |entry| entry["package-ecosystem"] == ecosystem }

    it "groups the Ruby gems' security updates into one pull request (AC-1.1, FR-1)" do
      expect(update_for("bundler")["groups"].values)
        .to include("applies-to" => "security-updates", "patterns" => [ "*" ])
    end

    it "leaves the schedule, the limit and the github-actions entry as they were (AC-1.2, FR-1)", :aggregate_failures do
      weekly = { "directory" => "/", "schedule" => { "interval" => "weekly" }, "open-pull-requests-limit" => 10 }

      expect(update_for("bundler").except("groups")).to eq(weekly.merge("package-ecosystem" => "bundler"))
      expect(update_for("github-actions")).to eq(weekly.merge("package-ecosystem" => "github-actions"))
    end
  end

  describe ".github/workflows/advisory-audit.yml" do
    let(:path) { Rails.root.join(".github/workflows/advisory-audit.yml") }
    let(:workflow) { YAML.load_file(path) }

    def triggers = workflow[true] || workflow["on"] # Psych reads the YAML key `on` as true
    def job = workflow.dig("jobs", "audit")
    def steps = job["steps"]
    def audits = steps.select { |candidate| candidate["run"].to_s.start_with?("bin/bundler-audit", "bin/importmap") }
    def pinned_uses(file) = file.read.scan(%r{uses: (\S+@\h{40}) # v\d}).flatten
    def ci_pins = pinned_uses(Rails.root.join(".github/workflows/ci.yml"))

    it "runs once a day and by hand, never on pushes or pull requests (AC-2.1, FR-2)", :aggregate_failures do
      expect(triggers.keys).to contain_exactly("schedule", "workflow_dispatch")
      expect(triggers["schedule"].size).to eq(1)

      minute, hour, *rest = triggers["schedule"].first["cron"].split
      expect(Integer(minute)).to be_between(1, 59) # a minute other than 0
      expect(Integer(hour)).to be_between(0, 23)
      expect(rest).to eq(%w[* * *])
    end

    it "runs both audits as separate steps that cannot hide a failure (AC-2.2, FR-2)", :aggregate_failures do
      commands = audits.map { |candidate| candidate["run"] }

      expect(commands.size).to eq(2)
      expect(commands.first).to start_with("bin/bundler-audit")
      expect(commands.last).to eq("bin/importmap audit")
      expect(commands).to all(match(%r{\Abin/[\w-]+( [\w-]+)*\z})) # no `||`, `;` or `&&` to hide an exit status
      expect(steps.flat_map(&:keys)).not_to include("continue-on-error")
    end

    it "runs the second audit after the first fails, and neither after a failed setup (AC-2.3, AC-2.9, FR-2)", :aggregate_failures do
      first, second = audits
      setup = steps.select { |candidate| candidate["id"] }

      expect(setup.map { |candidate| candidate["id"] }).to eq(%w[checkout ruby])
      expect(setup.last.dig("with", "bundler-cache")).to be(true) # the gem installation is part of the setup
      expect(first).not_to have_key("if") # the default, success(), runs it only after every earlier step succeeded
      expect(second["if"]).to include("!cancelled()", "steps.checkout.outcome == 'success'", "steps.ruby.outcome == 'success'")
    end

    it "asks for read-only access and uses only actions pinned as ci.yml pins them (AC-2.4, FR-2, NFR Security)", :aggregate_failures do
      expect(workflow["permissions"]).to eq("contents" => "read")
      expect(job.fetch("permissions", { "contents" => "read" })).to eq("contents" => "read")
      expect(path.read.scan(/\buses:/).size).to eq(pinned_uses(path).size) # every `uses:` line is a SHA with a version comment
      expect(pinned_uses(path)).to all(satisfy { |action| ci_pins.include?(action) })
    end

    it "stops a hung run within 10 minutes (AC-2.5, FR-2)" do
      expect(job["timeout-minutes"]).to be_between(1, 10)
    end

    it "keeps no copy of the Ruby advisory database between runs (AC-2.11, FR-2)" do
      names_database = steps.any? { |candidate| candidate.to_s.include?("ruby-advisory-db") }

      expect(audits.first["run"].include?("--update") || !names_database).to be(true)
    end
  end
end
