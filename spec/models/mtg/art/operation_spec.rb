require "rails_helper"

RSpec.describe MTG::Art::Operation, :solid_queue, type: :model do
  subject(:operation) { described_class.new("mtg") }

  def loaded = create(:catalog_refresh_run, status: "applied")

  def build(**attributes) = create(:mtg_art_build, **attributes)

  context "with art matching off" do
    it "says how to turn it on and offers no button (spec 015 AC-4.6)", :aggregate_failures do
      loaded

      expect(operation).to have_attributes(state: :off, start_label: nil, startable?: false,
        summary: "Art matching is off. Set COLLECTOR_MTG_ART_MATCHING=true to turn it on.")
      expect(operation.start).to be(false)
    end
  end

  context "with art matching on", :art_matching do
    it "is the art index build", :aggregate_failures do
      expect(operation).to have_attributes(key: "art_index", title: "Art index", start_label: "Build art index",
        job_class: MTG::Art::BuildJob, job_arguments: [], queue_argument: nil)
      expect(operation.queued_notice).to eq("Art index build queued.")
      expect(operation.in_flight_notice).to eq("An art index build is already queued or running.")
    end

    it "needs the catalog refreshed first (AC-4.5)", :aggregate_failures do
      expect(operation).to have_attributes(state: :never, startable?: false,
        summary: "Refresh the catalog first: the art index is built from its cards.")
      expect(operation.start).to be(false)
      expect(SolidQueue::Job.count).to eq(0)
    end

    it "has never been built, and queues one build job when started (AC-4.1, AC-4.3)", :aggregate_failures do
      loaded

      expect(operation).to have_attributes(state: :never,
        summary: "No build has run yet. One starts after the next catalog refresh, or you can start it here.")
      expect(operation.start).to be(true)
      expect(SolidQueue::Job.sole.class_name).to eq("MTG::Art::BuildJob")
    end

    it "is queued while its job is in the queue, and can't be started again (AC-4.4)", :aggregate_failures do
      loaded
      queue_job(MTG::Art::BuildJob)

      expect(operation).to have_attributes(state: :queued, summary: "Queued.", startable?: false)
      expect(operation.start).to be(false)
      expect(SolidQueue::Job.count).to eq(1)
    end

    it "shows a running build's progress, counts and heartbeat (AC-4.2)", :aggregate_failures do
      loaded
      freeze_time do
        build(status: "running", finished_at: nil, heartbeat_at: 20.seconds.ago, total_count: 31_904,
          fingerprinted_count: 7_976, fetched_count: 1_200, failed_count: 3)

        expect(operation).to have_attributes(state: :building, summary: "Building.", startable?: false)
        expect(operation.meter).to have_attributes(percent: 25, text: "7,976 of 31,904 artworks fingerprinted")
        expect(operation.facts.map { |fact| [ fact.label, fact.value, fact.relative ] }).to include(
          [ "Images fetched", 1_200, false ], [ "Failed images", 3, false ], [ "Last heartbeat", 20.seconds.ago, true ])
      end
    end

    it "is interrupted when the heartbeat stopped, and can be built again (AC-4.1)", :aggregate_failures do
      loaded
      build(status: "running", finished_at: nil, heartbeat_at: 11.minutes.ago, total_count: 10, fingerprinted_count: 3)

      expect(operation).to have_attributes(state: :interrupted, startable?: true,
        summary: "Interrupted. Build it again to carry on from where it stopped.")
      expect(operation.meter.percent).to eq(30)
    end

    it "shows a finished build's counts and finish time (AC-4.7)", :aggregate_failures do
      loaded
      build(indexed_count: 31_904, without_image_count: 12, failed_count: 3)

      expect(operation).to have_attributes(state: :ready, summary: "Ready.", meter: nil, startable?: true)
      expect(operation.facts.to_h { |fact| [ fact.label, fact.value ] })
        .to include("Artworks indexed" => 31_904, "Without an image" => 12, "Failed images" => 3, "Finished" => be_a(Time))
    end

    it "shows a failed build's message and the index still in use (AC-4.8)", :aggregate_failures do
      loaded
      build(status: "failed", message: "Errno::ENOSPC: No space left on device")

      expect(operation).to have_attributes(state: :failed, summary: "Failed: Errno::ENOSPC: No space left on device")
      expect(operation.facts.to_h { |fact| [ fact.label, fact.value ] }).to include("Index in use" => "none")
    end

    it "names the index a failed build left in use (AC-4.8)" do
      loaded
      kept = MTG::Art::Index.write!("default-cards-1", [])
      build(status: "failed", message: "boom")

      expect(operation.facts.last).to have_attributes(label: "Index in use", value: kept.basename.to_s)
    end

    it "ignores a build skipped because another was running, as the status line does" do
      loaded
      build(indexed_count: 9, started_at: 2.hours.ago)
      build(status: "skipped", message: "already running", started_at: 1.hour.ago)

      expect(operation.state).to eq(:ready)
    end
  end
end
