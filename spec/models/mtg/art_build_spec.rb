require "rails_helper"

RSpec.describe MTG::ArtBuild, type: :model do
  def start(job_id = "job-a") = described_class.start!(job_id:, catalog_version: "default-cards-1", settings_digest: MTG::Art::Settings.digest)

  it "records a running build with its job and a heartbeat" do
    expect(start).to have_attributes(status: "running", job_id: "job-a", heartbeat_at: be_present)
  end

  it "ends a second build at once as skipped while one is running (spec 011 AC-3.2)", :aggregate_failures do
    first = start
    second = start("job-b")
    expect(second).to have_attributes(status: "skipped", message: "already running")
    expect(first.reload).to be_running
  end

  it "marks a run with a stale heartbeat interrupted, then runs (AC-3.2)", :aggregate_failures do
    first = start
    travel(described_class::STALE_AFTER + 1.minute) do
      expect(start("job-b")).to be_running
    end
    expect(first.reload).to have_attributes(status: "failed", message: "interrupted")
  end

  it "lets the queue's re-run of the same job carry on at once (AC-3.2, AC-3.8)", :aggregate_failures do
    first = start
    expect(start("job-a")).to be_running
    expect(first.reload).to have_attributes(status: "failed", message: "interrupted")
  end

  it "keeps its counts and heartbeat as it goes, and its outcome at the end", :aggregate_failures do
    run = start
    travel 1.minute do
      run.beat!(total: 3, fetched: 1)
      expect(run).to have_attributes(total_count: 3, fetched_count: 1, heartbeat_at: Time.current)
    end
    run.finish!(:finished, indexed: 3)
    expect(run).to have_attributes(status: "finished", indexed_count: 3, finished_at: be_present)
    expect(run.counts).to include(total: 3, fetched: 1, indexed: 3)
  end

  it "is stale only while running with an old heartbeat", :aggregate_failures do
    run = start
    expect(run).not_to be_stale
    travel(described_class::STALE_AFTER + 1.minute) { expect(run).to be_stale }
  end

  it "reports the latest run that wasn't skipped" do
    finished = create(:mtg_art_build, started_at: 2.hours.ago)
    create(:mtg_art_build, status: "skipped", started_at: 1.hour.ago)
    expect(described_class.latest).to eq(finished)
  end
end
