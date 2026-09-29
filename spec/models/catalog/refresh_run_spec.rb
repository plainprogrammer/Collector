require "rails_helper"

RSpec.describe Catalog::RefreshRun, type: :model do
  describe ".start!" do
    it "starts a running attempt when nothing is running" do
      expect(described_class.start!("mtg", trigger: "manual")).to be_running
    end

    it "records a skip when a run younger than 6 hours is running", :aggregate_failures do
      create(:catalog_refresh_run, status: "running", started_at: 5.hours.ago, finished_at: nil)
      allow(Rails.logger).to receive(:info)

      run = described_class.start!("mtg", trigger: "manual")

      expect(run).to be_skipped
      expect(run.message).to eq("already running")
      expect(Rails.logger).to have_received(:info).with(a_string_including('"status":"skipped"'))
    end

    it "marks a run running for 6 hours or more as interrupted and proceeds", :aggregate_failures do
      stale = create(:catalog_refresh_run, status: "running", started_at: 7.hours.ago, finished_at: nil)

      run = described_class.start!("mtg", trigger: "scheduled")

      expect(stale.reload).to be_failed
      expect(stale.message).to eq("interrupted")
      expect(run).to be_running
    end

    it "ignores runs of other collectible types" do
      create(:catalog_refresh_run, collectible_type: "other", status: "running", started_at: 1.hour.ago, finished_at: nil)

      expect(described_class.start!("mtg", trigger: "manual")).to be_running
    end
  end

  describe ".applied?" do
    it "matches source version and language set", :aggregate_failures do
      create(:catalog_refresh_run, source_version: "v1", languages: "en")

      expect(described_class.applied?("mtg", source_version: "v1", languages: "en")).to be(true)
      expect(described_class.applied?("mtg", source_version: "v1", languages: "en,ja")).to be(false)
    end
  end

  describe "#finish!" do
    it "stores the outcome and logs one structured entry", :aggregate_failures do
      run = described_class.start!("mtg", trigger: "manual")
      allow(Rails.logger).to receive(:info)

      run.finish!(:applied, counts: { seen: 3, inserted: 2 })

      expect(run.reload).to have_attributes(status: "applied", seen_count: 3, inserted_count: 2)
      expect(run.finished_at).to be_present
      expect(Rails.logger).to have_received(:info)
        .with(a_string_including('"event":"catalog.refresh.finished"', '"status":"applied"', '"inserted":2'))
    end
  end
end
