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
        "SECRET_KEY_BASE", "SOLID_QUEUE_IN_PUMA", "HTTP_PORT", "COLLECTOR_MTG_LANGUAGES", "COLLECTOR_CURRENCY",
        "COLLECTOR_HTTPS", "COLLECTOR_TRUSTED_PROXIES")
    end
  end
end
