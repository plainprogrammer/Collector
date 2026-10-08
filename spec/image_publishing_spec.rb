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
end
