require "rails_helper"

RSpec.describe Catalog::RefreshRun, type: :model do
  describe ".start!" do
    it "starts a running attempt when nothing is running" do
      expect(described_class.start!("mtg", trigger: "manual")).to be_running
    end

    it "records the job running it and starts the heartbeat (spec 015 FR-1)", :aggregate_failures do
      freeze_time do
        run = described_class.start!("mtg", trigger: "manual", job_id: "job-1")

        expect(run).to have_attributes(job_id: "job-1", heartbeat_at: Time.current, stage: nil)
      end
    end

    it "records a skip while a run that made progress in the last 15 minutes is running (AC-3.4)", :aggregate_failures do
      create(:catalog_refresh_run, :running, started_at: 5.hours.ago, heartbeat_at: 14.minutes.ago, job_id: "job-1")
      allow(Rails.logger).to receive(:info)

      run = described_class.start!("mtg", trigger: "manual", job_id: "job-2")

      expect(run).to be_skipped
      expect(run.message).to eq("already running")
      expect(Rails.logger).to have_received(:info).with(a_string_including('"status":"skipped"'))
    end

    it "closes a run with no progress for 15 minutes as interrupted and proceeds (AC-3.3)", :aggregate_failures do
      stale = create(:catalog_refresh_run, :running, started_at: 1.hour.ago, heartbeat_at: 16.minutes.ago, stage: "sync")

      run = described_class.start!("mtg", trigger: "scheduled")

      expect(stale.reload).to have_attributes(status: "failed", message: "interrupted", stage: "sync")
      expect(run).to be_running
    end

    it "closes the starting job's own running run at once and proceeds (AC-3.3)", :aggregate_failures do
      own = create(:catalog_refresh_run, :running, started_at: 2.minutes.ago, heartbeat_at: 1.minute.ago, job_id: "job-1")

      run = described_class.start!("mtg", trigger: "manual", job_id: "job-1")

      expect(own.reload).to have_attributes(status: "failed", message: "interrupted")
      expect(run).to be_running
    end

    it "never matches runs without a job id to a refresh started without one (AC-3.3)" do
      create(:catalog_refresh_run, :running, started_at: 2.minutes.ago, heartbeat_at: 1.minute.ago, job_id: nil)

      expect(described_class.start!("mtg", trigger: "manual", job_id: nil)).to be_skipped
    end

    it "reads a run recorded before heartbeats by its start time", :aggregate_failures do
      old = create(:catalog_refresh_run, :running, started_at: 16.minutes.ago, heartbeat_at: nil)

      expect(described_class.start!("mtg", trigger: "manual")).to be_running
      expect(old.reload.message).to eq("interrupted")
    end

    it "ignores runs of other collectible types" do
      create(:catalog_refresh_run, collectible_type: "other", status: "running", started_at: 1.hour.ago, finished_at: nil)

      expect(described_class.start!("mtg", trigger: "manual")).to be_running
    end
  end

  describe ".attempted (spec 015 AC-2.16)" do
    it "leaves out runs skipped because another was running, and only those" do
      applied = create(:catalog_refresh_run, started_at: 3.hours.ago)
      already_applied = create(:catalog_refresh_run, status: "skipped", message: "v1 already applied", started_at: 2.hours.ago)
      create(:catalog_refresh_run, status: "skipped", message: "already running", started_at: 1.hour.ago)

      expect(described_class.attempted.recent).to eq([ already_applied, applied ])
    end
  end

  describe "#progress! (spec 015 FR-1)" do
    it "records the stage, how far through it is, the counts so far and the heartbeat", :aggregate_failures do
      run = described_class.start!("mtg", trigger: "manual")

      travel 1.minute do
        run.progress!(stage: "sync", done: 40, total: 100, counts: { seen: 7, inserted: 2 })

        expect(run.reload).to have_attributes(stage: "sync", stage_done: 40, stage_total: 100, seen_count: 7,
          inserted_count: 2, heartbeat_at: Time.current, status: "running")
      end
    end

    it "rejects a stage that isn't one of the four" do
      run = described_class.start!("mtg", trigger: "manual")

      expect { run.progress!(stage: "polish") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#status_label and #status_line (spec 015 AC-3.2, AC-3.5, AC-3.6)" do
    let(:run) { create(:catalog_refresh_run, :running, started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago) }

    it "is the plain status while the run makes progress or has ended", :aggregate_failures do
      expect(create(:catalog_refresh_run, :running, heartbeat_at: 1.minute.ago).status_label).to eq("running")
      expect(create(:catalog_refresh_run, status: "failed").status_label).to eq("failed")
    end

    it "is interrupted for a stalled run whose job is gone" do
      expect(run.status_label(job_claimed: false)).to eq("interrupted")
    end

    it "is running with the minutes without progress while the stalled run's job is still claimed" do
      expect(run.status_label(job_claimed: true)).to eq("running (no progress for 20 minutes)")
    end

    it "prints the label in the status line" do
      expect(run.status_line(job_claimed: false)).to include("  interrupted  ")
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
