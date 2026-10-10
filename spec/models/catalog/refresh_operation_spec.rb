require "rails_helper"

RSpec.describe Catalog::RefreshOperation, :solid_queue, type: :model do
  subject(:operation) { described_class.new("mtg") }

  def run(**attributes) = create(:catalog_refresh_run, **attributes)

  def running(**attributes) = create(:catalog_refresh_run, :running, **attributes)

  it "is the refresh, started with the manual trigger", :aggregate_failures do
    expect(operation).to have_attributes(key: "refresh", title: "Refresh", start_label: "Refresh now",
      job_class: Catalog::RefreshJob, job_arguments: %w[mtg manual])
    expect(operation.queued_notice).to eq("Refresh queued.")
    expect(operation.in_flight_notice).to eq("A refresh is already queued or running.")
  end

  context "when nothing has run and nothing is queued" do
    it "has never run and can start", :aggregate_failures do
      expect(operation).to have_attributes(state: :never, summary: "No refresh has run yet.", stages: [], facts: [])
      expect(operation).to be_startable
    end

    it "queues one manual refresh job for the type (spec 015 AC-2.1)", :aggregate_failures do
      expect(operation.start).to be(true)
      expect(SolidQueue::Job.sole.arguments["arguments"]).to eq(%w[mtg manual])
    end
  end

  context "when its job is in the queue" do
    it "is queued and can't be started again, whatever queued the job (AC-2.2, AC-2.3)", :aggregate_failures do
      queue_job(Catalog::RefreshJob, "mtg", "scheduled")

      expect(operation).to have_attributes(state: :queued, summary: "Queued.", stages: [], facts: [])
      expect(operation).to be_in_flight
      expect(operation.start).to be(false)
      expect(SolidQueue::Job.count).to eq(1)
    end

    it "doesn't describe an earlier run as the queued one" do
      run(status: "applied")
      queue_job(Catalog::RefreshJob, "mtg", "manual")

      expect(operation).to have_attributes(state: :queued, summary: "Queued.", facts: [])
    end

    it "isn't held back by another type's job" do
      queue_job(Catalog::RefreshJob, "other", "manual")

      expect(operation).to be_startable
    end
  end

  context "when a run is running" do
    it "lists the four stages around the current one, with the download in bytes (AC-2.4, AC-2.5)", :aggregate_failures do
      running(stage: "download", stage_done: 41_200_000, stage_total: 82_400_000)

      expect(operation).to have_attributes(state: :running, summary: "Running.")
      expect(operation.stages.map { |stage| [ stage.label, stage.state ] })
        .to eq([ [ "Download", :current ], [ "Sync cards", :pending ], [ "Retire missing cards", :pending ], [ "Rebuild name index", :pending ] ])
      expect(operation.stages.first.meter).to have_attributes(percent: 50, text: "39.3 MB of 78.6 MB", label: "Download")
    end

    it "shows the share of the file read and the counts so far while syncing (AC-2.6)", :aggregate_failures do
      running(stage: "sync", stage_done: 61, stage_total: 100, seen_count: 66_140, inserted_count: 18, updated_count: 312)

      download, sync, = operation.stages
      expect(download).to have_attributes(state: :done, meter: nil, note: nil)
      expect(sync.meter).to have_attributes(percent: 61, text: nil)
      expect(sync.note).to eq("66,140 seen · 18 inserted · 312 updated")
    end

    it "marks retiring and the name index current without a percentage (AC-2.7)", :aggregate_failures do
      running(stage: "retire")

      expect(operation.stages.map(&:state)).to eq(%i[done done current pending])
      expect(operation.stages.third).to have_attributes(meter: nil, note: nil)
    end

    it "shows bytes received without a percentage when the size is unknown", :aggregate_failures do
      running(stage: "download", stage_done: 1_048_576, stage_total: nil)

      expect(operation.stages.first.meter).to have_attributes(percent: nil, text: "1 MB")
    end

    it "shows a source's stage without a meter when it reports no progress (AC-2.8)" do
      running(stage: "sync", seen_count: 12)

      expect(operation.stages.second).to have_attributes(state: :current, meter: nil, note: "12 seen · 0 inserted · 0 updated")
    end

    it "gives when it started, its trigger and its last progress, and can't be started (AC-2.2, AC-2.4)", :aggregate_failures do
      freeze_time do
        running(stage: "sync", started_at: 3.minutes.ago, heartbeat_at: 10.seconds.ago)

        expect(operation.facts.map { |fact| [ fact.label, fact.value, fact.relative ] })
          .to eq([ [ "Started", 3.minutes.ago, false ], [ "Trigger", "manual", false ], [ "Last progress", 10.seconds.ago, true ] ])
        expect(operation).not_to be_startable
      end
    end
  end

  context "when a run made no progress for 15 minutes" do
    let!(:stalled) { running(stage: "sync", started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago, job_id: "job-1") }

    it "is interrupted once no worker holds its job, and can start again (AC-3.2)", :aggregate_failures do
      expect(operation).to have_attributes(state: :interrupted, summary: "Interrupted while syncing cards.")
      expect(operation.stages.map(&:state)).to eq(%i[done stopped pending pending])
      expect(operation).to be_startable
      expect(operation.status_label(stalled)).to eq("interrupted")
    end

    it "stays closed to a new start while a refresh job for the type is still unfinished in the queue (AC-3.2)" do
      queue_job(Catalog::RefreshJob, "mtg", "manual")

      expect(operation).to have_attributes(state: :interrupted, startable?: false)
    end

    it "is still running, with the minutes, while a worker holds its job (AC-3.6)", :aggregate_failures do
      claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual")).update!(active_job_id: "job-1")

      expect(operation).to have_attributes(state: :stalled, summary: "Running, no progress for 20 minutes.")
      expect(operation.stages.second.state).to eq(:current)
      expect(operation).not_to be_startable
      expect(operation.status_label(stalled)).to eq("running (no progress for 20 minutes)")
    end

    it "isn't kept running by a worker holding another job" do
      claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

      expect(operation.state).to eq(:interrupted)
    end
  end

  context "when the last run ended" do
    it "shows an applied run's counts, version and finish time (AC-2.13)", :aggregate_failures do
      run(status: "applied", source_version: "v7", seen_count: 106_636, updated_count: 12, stage: "index")

      expect(operation).to have_attributes(state: :applied, summary: "Applied.", stages: [])
      expect(operation.facts.to_h { |fact| [ fact.label, fact.value ] }).to include("Source version" => "v7",
        "Counts" => "106,636 seen · 0 inserted · 12 updated · 0 retired · 0 restored · 0 malformed", "Finished" => be_a(Time))
      expect(operation).to be_startable
    end

    it "shows a skipped run with its message (AC-2.14)" do
      run(status: "skipped", message: "v7 already applied")

      expect(operation).to have_attributes(state: :skipped, summary: "Skipped: v7 already applied.")
    end

    it "shows the run before one skipped because another was running (AC-2.16)", :aggregate_failures do
      run(status: "applied", started_at: 2.hours.ago, source_version: "v7")
      2.times { |n| run(status: "skipped", message: "already running", started_at: (60 - n).minutes.ago) }

      expect(operation.state).to eq(:applied)
      expect(operation.run.source_version).to eq("v7")
    end

    it "shows a failed run with the stage it failed in and its message (AC-3.1)", :aggregate_failures do
      run(status: "failed", stage: "sync", message: "RuntimeError: source exploded")

      expect(operation).to have_attributes(state: :failed, summary: "Failed while syncing cards: RuntimeError: source exploded")
      expect(operation.stages.map(&:state)).to eq(%i[done stopped pending pending])
      expect(operation).not_to be_failed_job
    end

    it "words a failure recorded before stages without one" do
      run(status: "failed", stage: nil, message: "IntegrityError: short file")

      expect(operation).to have_attributes(summary: "Failed: IntegrityError: short file", stages: [])
    end

    it "knows when the failed run's job is in the queue's failed list (AC-3.1)" do
      run(status: "failed", stage: "download", message: "TransientError: 503")
      fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

      expect(operation).to be_failed_job.and be_startable
    end

    it "doesn't point at an old failed job once a later run is on show" do
      fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))
      run(status: "applied")

      expect(operation).not_to be_failed_job
    end

    it "shows a failed run whose job waits to retry as queued, retrying at its time (AC-3.7)", :aggregate_failures do
      freeze_time do
        run(status: "failed", stage: "download", message: "Catalog::Sources::TransientError: 503")
        queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 3.minutes)

        expect(operation).to have_attributes(state: :queued, startable?: false, failed_job?: false,
          summary: "Queued to retry. The last run failed while downloading: Catalog::Sources::TransientError: 503")
        expect(operation.facts.first).to have_attributes(label: "Retrying at", value: 3.minutes.from_now)
        expect(operation.stages.first.state).to eq(:stopped)
      end
    end
  end
end
