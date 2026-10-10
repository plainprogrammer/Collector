require "rails_helper"
require "yaml"

# File-shape checks for the image publishing flow (spec 012). The registry-side criteria are evidenced by
# workflow runs and podman output (docs/specs/012-ghcr-registry-publishing/verification.md).
RSpec.describe "Image publishing files" do
  describe ".dockerignore" do
    let(:rules) do
      Rails.root.join(".dockerignore").readlines(chomp: true).map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
    end

    it "keeps development-only paths out of the build context (AC-6.1, FR-3)" do
      expect(rules).to include("/docs", "/spikes", "/spec", "/script", "/.claude", "/CLAUDE.md", "/.githooks",
                               "/orca.yaml", "/.worktreeinclude")
    end

    it "still keeps secrets and data out (AC-6.4)" do
      expect(rules).to include("/config/master.key", "/.env*", "/.kamal", "/storage/*")
    end

    it "keeps the GHCR cleanup command out of the image and the smoke test checks it (AC-5.2, FR-5)", :aggregate_failures do
      expect(rules).to include("/bin/ghcr-cleanup", "/lib/collector/ghcr_cleanup.rb")
      expect(Rails.root.join("bin/image-smoke").read).to include("bin/ghcr-cleanup lib/collector/ghcr_cleanup.rb")
    end
  end

  describe "bin/image-smoke" do
    it "checks that Active Storage variants use libvips without a warning (spec 014 AC-1.3, FR-2)" do
      expect(Rails.root.join("bin/image-smoke").read).to include(
        "bin/rails runner 'puts ActiveStorage.variant_transformer'", "requires the (ruby-vips gem|libvips library)",
        "ActiveStorage::Transformers::Vips")
    end
  end

  describe "compose.yaml" do
    let(:compose) { Rails.root.join("compose.yaml") }
    let(:service) { YAML.load_file(compose).dig("services", "web") }

    it "pulls the published image by default, overridable with COLLECTOR_IMAGE (AC-1.5, FR-4)", :aggregate_failures do
      expect(service["image"]).to eq("${COLLECTOR_IMAGE:-ghcr.io/plainprogrammer/collector:latest}")
      expect(service).not_to have_key("build")
      expect(compose.read).to match(/^# Optional: COLLECTOR_IMAGE /)
    end

    it "keeps the rest of the service unchanged (FR-4)", :aggregate_failures do
      expect(service["ports"]).to eq([ "${COLLECTOR_PORT:-3000}:8080" ])
      expect(service["volumes"]).to eq([ "collector_storage:/rails/storage" ])
      expect(service.dig("healthcheck", "test")).to eq([ "CMD", "curl", "-fsS", "http://localhost:8080/up" ])
      expect(service["environment"].keys).to contain_exactly(
        "SECRET_KEY_BASE", "SOLID_QUEUE_IN_PUMA", "HTTP_PORT", "COLLECTOR_MTG_LANGUAGES", "COLLECTOR_MTG_ART_MATCHING",
        "COLLECTOR_CURRENCY", "COLLECTOR_HTTPS", "COLLECTOR_TRUSTED_PROXIES")
    end
  end

  describe "config/deploy.yml" do
    let(:deploy) { YAML.load_file(Rails.root.join("config/deploy.yml")) }

    it "deploys the published image from GHCR with active credentials (AC-5.1, AC-5.4, FR-5)", :aggregate_failures do
      expect(deploy["image"]).to eq("plainprogrammer/collector")
      expect(deploy["registry"]).to eq("server" => "ghcr.io", "username" => "plainprogrammer",
                                       "password" => [ "KAMAL_REGISTRY_PASSWORD" ])
      expect(deploy.dig("builder", "arch")).to eq("amd64")
      expect(deploy.dig("servers", "web")).to eq([ "192.168.0.1" ])
    end
  end

  describe ".github/workflows/ci.yml" do
    let(:workflow) { YAML.load_file(Rails.root.join(".github/workflows/ci.yml")) }
    let(:triggers) { workflow[true] || workflow["on"] } # Psych reads the YAML key `on` as true
    let(:image_job) { workflow.dig("jobs", "image") }
    let(:publish_job) { workflow.dig("jobs", "publish") }
    let(:steps) { image_job["steps"] }

    def step(id) = steps.find { |candidate| candidate["id"] == id }

    it "runs on pull requests, pushes to main and release tags only (FR-1, AC-3.6)", :aggregate_failures do
      expect(triggers.keys).to contain_exactly("pull_request", "push")
      expect(triggers.dig("push", "branches")).to eq([ "main" ])
      expect(triggers.dig("push", "tags")).to eq([ "v[0-9]+.[0-9]+.[0-9]+", "v[0-9]+.[0-9]+.[0-9]+-*" ])
    end

    it "builds both architectures natively after bin/ci, then publishes (ADR 0010, FR-1)", :aggregate_failures do
      expect(image_job["needs"]).to eq("ci")
      expect(image_job["runs-on"]).to eq("${{ matrix.runner }}")
      expect(image_job.dig("strategy", "matrix", "include")).to contain_exactly(
        { "platform" => "linux/amd64", "runner" => "ubuntu-latest" },
        { "platform" => "linux/arm64", "runner" => "ubuntu-24.04-arm" })
      expect(publish_job["needs"]).to eq("image")
    end

    it "installs libvips and ImageMagick before bin/ci (spec 014 AC-2.3, FR-3)", :aggregate_failures do
      ci_steps = workflow.dig("jobs", "ci", "steps")
      install = ci_steps.index { |candidate| candidate["run"].to_s.include?("apt-get install") }
      expect(install).not_to be_nil
      expect(ci_steps[install]["run"].split).to include("libvips", "imagemagick")
      expect(install).to be < ci_steps.index { |candidate| candidate["run"] == "bin/ci" }
    end

    it "grants packages: write only to the image and publish jobs (NFR Security)", :aggregate_failures do
      expect(workflow["permissions"]).to eq("contents" => "read")
      expect(image_job["permissions"]).to eq("contents" => "read", "packages" => "write")
      expect(publish_job["permissions"]).to eq("contents" => "read", "packages" => "write")
      expect(workflow.dig("jobs", "ci")).not_to have_key("permissions")
    end

    it "never pushes from a pull request and caches only in Actions (AC-4.2, FR-1)", :aggregate_failures do
      expect(step("push")["if"]).to eq("github.event_name != 'pull_request'")
      expect(publish_job["if"]).to eq("github.event_name != 'pull_request'")
      expect(step("build")["with"]).to include("load" => true)
      expect(step("build")["with"]).not_to have_key("outputs")
      expect(step("build").dig("with", "cache-to")).to start_with("type=gha,")
      expect(step("push").dig("with", "outputs")).to include("push-by-digest=true", "push=true")
      expect(step("push")["with"]).not_to have_key("cache-to")
    end

    it "builds without attestations so a manifest list has two entries (AC-2.1)", :aggregate_failures do
      expect(step("build")["with"]).to include("provenance" => false, "sbom" => false)
      expect(step("push")["with"]).to include("provenance" => false, "sbom" => false)
    end

    it "smoke-tests each image between the build and the push (AC-4.3, AC-6.2)" do
      names = steps.map { |candidate| candidate["id"] || candidate["name"] }
      expect(names.index("Smoke test")).to be_between(names.index("build"), names.index("push")).exclusive
    end

    it "tags releases, main and SHAs per ADR 0009 (FR-2)", :aggregate_failures do
      rules = step("meta").dig("with", "tags").lines(chomp: true)
      expect(rules).to include("type=edge,branch=main", "type=sha,enable=${{ github.ref == 'refs/heads/main' }}")
      expect(rules).to include("type=semver,pattern={{version}}", "type=semver,pattern={{major}}.{{minor}}")
      expect(rules).to include("type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}")
      expect(publish_job["steps"].find { |candidate| candidate["id"] == "meta" }.dig("with", "tags")).to eq(step("meta").dig("with", "tags"))
    end

    it "labels the licence and description explicitly (AC-3.5, FR-2)" do
      expect(step("meta").dig("with", "labels").lines(chomp: true)).to include(
        "org.opencontainers.image.licenses=AGPL-3.0",
        "org.opencontainers.image.description=Self-hostable, multi-tenant web app for tracking collectibles, " \
        "starting with Magic: The Gathering cards.")
    end
  end

  describe ".github/workflows/ghcr-cleanup.yml" do
    let(:workflow) { YAML.load_file(Rails.root.join(".github/workflows/ghcr-cleanup.yml")) }
    let(:triggers) { workflow[true] || workflow["on"] } # Psych reads the YAML key `on` as true

    def job(name) = workflow.dig("jobs", name)
    def command(name) = job(name)["steps"].find { |candidate| candidate["run"]&.start_with?("bin/ghcr-cleanup") }

    it "runs weekly and by hand, never on pushes or pull requests (AC-1.5, FR-4)", :aggregate_failures do
      expect(triggers.keys).to contain_exactly("schedule", "workflow_dispatch")
      expect(triggers["schedule"]).to eq([ { "cron" => "0 6 * * 0" } ])
      expect(triggers.dig("workflow_dispatch", "inputs", "dry_run")).to include("type" => "boolean", "default" => true)
    end

    it "dry-runs by hand by default, without packages: write (AC-4.2, FR-4)", :aggregate_failures do
      expect(job("dry-run")["if"]).to eq("github.event_name == 'workflow_dispatch' && inputs.dry_run")
      expect(job("dry-run")["permissions"]).to eq("contents" => "read", "packages" => "read")
      expect(command("dry-run")["run"]).to eq("bin/ghcr-cleanup")
    end

    it "deletes on the schedule or an unticked dry_run, the only job with packages: write (AC-1.5, FR-4)", :aggregate_failures do
      expect(job("delete")["if"])
        .to eq("github.event_name == 'schedule' || (github.event_name == 'workflow_dispatch' && !inputs.dry_run)")
      expect(job("delete")["permissions"]).to eq("contents" => "read", "packages" => "write")
      expect(command("delete")["run"]).to eq("bin/ghcr-cleanup --delete")
      expect(workflow["permissions"]).to eq("contents" => "read")
    end

    it "passes the workflow token as GH_TOKEN and uses only GitHub's or ci.yml's actions (FR-4, NFR Security)", :aggregate_failures do
      expect(%w[dry-run delete].map { |name| command(name).dig("env", "GH_TOKEN") }).to all(eq("${{ secrets.GITHUB_TOKEN }}"))
      uses = workflow["jobs"].values.flat_map { |each_job| each_job["steps"].filter_map { |candidate| candidate["uses"] } }
      expect(uses).to all(start_with("actions/").or(start_with("ruby/setup-ruby@")))
    end
  end

  describe "docs/releasing.md" do
    let(:doc) { Rails.root.join("docs/releasing.md").read }

    it "records the release procedure and what each trigger publishes (AC-7.1)", :aggregate_failures do
      expect(doc).to include("git tag -a v", "v0.1.0", "| Tag `vX.Y.Z` |", "| Push to `main` |", "| Pull request |")
      expect(doc).to include("vX.Y.Z-<suffix>", "Only the newest release's workflow may be re-run")
      expect(doc).to include("The workflow does not check that the tag is annotated or on `main`")
    end

    it "orders the go-public checklist and says it cannot be undone (AC-7.2)", :aggregate_failures do
      positions = [ "Push the first image", "Verify an authenticated pull", "Confirm the package is linked",
                    "Change the visibility to public", "Verify an anonymous pull" ].map { |step| doc.index(step) }
      expect(positions).to all(be_a(Integer))
      expect(positions).to eq(positions.sort)
      expect(doc).to include("cannot be undone")
    end

    it "documents the cleanup: rule, grace period, schedule, manual and local runs, failures, token (AC-5.1)", :aggregate_failures do
      expect(doc).to include("## Cleaning up untagged versions", "more than\n  7 days old", "**Never deleted:**")
      expect(doc).to include("Sundays at 06:00 UTC", "The `dry_run` box is ticked by default")
      expect(doc).to include('GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup', "**A failed run failed closed:**")
      expect(doc).to include("Investigate the cause before re-running", "personal access token (classic")
    end
  end
end
