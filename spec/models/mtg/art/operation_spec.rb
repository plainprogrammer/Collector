require "rails_helper"

RSpec.describe MTG::Art::Operation, :solid_queue, type: :model do
  subject(:operation) { described_class.new("mtg") }

  def loaded = create(:catalog_refresh_run, status: "applied")

  def build(**attributes) = create(:mtg_art_build, **attributes)

  # A build still marked running that last beat 7 minutes ago: not stale yet.
  def quiet_build(job_id, **attributes)
    build(status: "running", finished_at: nil, started_at: 8.minutes.ago, heartbeat_at: 7.minutes.ago, job_id:, **attributes)
  end

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

    it "is queued, not interrupted, once a build job waits behind the build whose heartbeat stopped (AC-4.3)", :aggregate_failures do
      loaded
      build(status: "running", finished_at: nil, heartbeat_at: 11.minutes.ago, job_id: "job-1")
      queue_job(MTG::Art::BuildJob)

      expect(operation).to have_attributes(state: :queued, summary: "Queued.", startable?: false)
      expect(operation).to be_in_flight
    end

    # A worker that still holds the job is hung or slow, and nothing can be started while it does (issue #79).
    context "when a worker still holds the job of the build whose heartbeat stopped" do
      let(:job) { claim_job(queue_job(MTG::Art::BuildJob)) }

      def stalled_build(**attributes)
        build(status: "running", finished_at: nil, started_at: 1.hour.ago, heartbeat_at: 11.minutes.ago, job_id: job.active_job_id, **attributes)
      end

      it "is stalled, not interrupted: it says what to do and never to build it again", :aggregate_failures do
        loaded
        stalled_build

        expect(operation).to have_attributes(state: :stalled, startable?: false, record_running?: true, failed_job?: false,
          summary: "Building, no heartbeat for 11 minutes. If it stays that way, restart the app. The build then carries on from where " \
                   "it stopped, or reads interrupted and can be built again.")
        expect(operation).to be_in_flight
      end

      it "shows the progress, counts and heartbeat a building one does", :aggregate_failures do
        loaded
        freeze_time do
          stalled_build(total_count: 10, fingerprinted_count: 3, fetched_count: 4, failed_count: 1)

          expect(operation.meter).to have_attributes(percent: 30, text: "3 of 10 artworks fingerprinted")
          expect(operation.facts.map { |fact| [ fact.label, fact.value, fact.relative ] }).to eq([ [ "Started", 1.hour.ago, false ],
            [ "Images fetched", 4, false ], [ "Failed images", 1, false ], [ "Last heartbeat", 11.minutes.ago, true ] ])
        end
      end

      it "stays stalled when another build job waits in the queue" do
        loaded
        stalled_build
        queue_job(MTG::Art::BuildJob)

        expect(operation.state).to eq(:stalled)
      end

      # That job closes the stalled build when it opens its own (MTG::ArtBuild.start!); until then the hung one is the news.
      it "stays stalled while a worker holds a second build job too", :aggregate_failures do
        loaded
        stalled_build
        claim_job(queue_job(MTG::Art::BuildJob))

        expect(operation).to have_attributes(state: :stalled, startable?: false, failed_job?: false)
        expect(operation).to be_in_flight
      end

      it "is interrupted, and can be built again, once the queue has failed that job", :aggregate_failures do
        loaded
        stalled_build
        fail_job(job)

        expect(operation).to have_attributes(state: :interrupted, startable?: true, failed_job?: true,
          summary: "Interrupted. Build it again to carry on from where it stopped.")
      end

      it "is interrupted, and can be built again, once that job has left the queue", :aggregate_failures do
        loaded
        stalled_build
        finish_job(job)

        expect(operation).to have_attributes(state: :interrupted, startable?: true, failed_job?: false)
      end
    end

    it "is still building while a worker holds its job, though it hasn't beaten for some minutes", :aggregate_failures do
      loaded
      quiet_build(claim_job(queue_job(MTG::Art::BuildJob)).active_job_id)

      expect(operation).to have_attributes(state: :building, summary: "Building.", startable?: false)
      expect(operation).to be_in_flight
    end

    # A build the image host rate limited closes its own run as failed, and its job waits in the queue to run again when
    # the host asked (issue #74, Catalog::RateLimitRetry). Nothing was left behind, so issue #73's rule for a running
    # build whose job ended doesn't apply, however old the heartbeat.
    context "when a rate-limited build's job waits to run again" do
      let(:job) { MTG::Art::BuildJob.new }

      before do
        loaded
        allow(MTG::Art::Build).to receive(:new) do # as the build does: it closes its run, then raises
          build(status: "failed", job_id: job.job_id, message: "Catalog::Sources::RateLimitedError: asked for 600 seconds")
          raise Catalog::Sources::RateLimitedError.new("asked for 600 seconds", retry_after: 600)
        end
        job.perform_now
      end

      it "is queued, not interrupted and not failed, long after the build's last heartbeat", :aggregate_failures do
        travel 9.minutes do
          expect(SolidQueue::Job.sole).to have_attributes(active_job_id: job.job_id, scheduled_at: be_within(1.second).of(1.minute.from_now))
          expect(operation).to have_attributes(state: :queued, failed_job?: false, startable?: false, record_running?: false)
          expect(operation).to be_in_flight
        end
      end

      it "says it is queued to retry, why the last build failed and when the retry is due (issue #80)", :aggregate_failures do
        expect(operation).to have_attributes(meter: nil,
          summary: "Queued to retry. The last build failed. #{Catalog::FailureReason::REASONS.fetch("Catalog::Sources::RateLimitedError")}")
        expect(operation.facts.map { |fact| [ fact.label, fact.value, fact.relative ] }).to eq([
          [ "Retrying at", SolidQueue::Job.sole.scheduled_at, false ], [ "Finished", MTG::ArtBuild.sole.finished_at, false ],
          [ "Index in use", "none", false ],
          [ "Technical detail", "Catalog::Sources::RateLimitedError: asked for 600 seconds", false ] ])
      end

      it "opens a new run when the retry starts, leaving the failed one as it ended", :aggregate_failures do
        failed = MTG::ArtBuild.sole

        travel 10.minutes do
          run = MTG::ArtBuild.start!(job_id: job.job_id, catalog_version: "default-cards-1", settings_digest: MTG::Art::Settings.digest)

          expect(run).to have_attributes(status: "running", job_id: job.job_id)
          expect(run.id).not_to eq(failed.id)
          expect(failed.reload).to have_attributes(status: "failed", message: include("asked for 600 seconds"))
        end
      end

      # A build queued meanwhile (by a refresh that applied) is skipped and leaves the panel as it was (issue #78).
      it "still says it is queued to retry after another build was skipped for it", :aggregate_failures do
        second = MTG::ArtBuild.start!(job_id: "job-b", catalog_version: "default-cards-1", settings_digest: MTG::Art::Settings.digest)

        expect(second).to have_attributes(status: "skipped", message: "waiting for another job's retry")
        expect(operation.summary)
          .to eq("Queued to retry. The last build failed. #{Catalog::FailureReason::REASONS.fetch("Catalog::Sources::RateLimitedError")}")
      end
    end

    # Any scheduled retry of the build's own job reads this way (issue #80). The build marks its run failed with the
    # error before the job's retry_on puts it back in the queue (MTG::Art::BuildJob).
    context "when a failed build's job waits to run again" do
      it "says so for a busy database, in plain words (issue #84)", :aggregate_failures do
        loaded
        freeze_time do
          job = queue_job(MTG::Art::BuildJob, wait: 18.seconds)
          build(status: "failed", job_id: job.active_job_id, message: "SQLite3::BusyException: database is locked")

          expect(operation).to have_attributes(state: :queued, startable?: false,
            summary: "Queued to retry. The last build failed. #{Catalog::FailureReason::REASONS.fetch("SQLite3::BusyException")}")
          expect(operation.facts.first).to have_attributes(label: "Retrying at", value: 18.seconds.from_now)
        end
      end

      # The reason and the time belong to the same job (spec 015 AC-4.12).
      it "gives its own job's time, not an earlier one another scheduled build job has", :aggregate_failures do
        loaded
        freeze_time do
          job = queue_job(MTG::Art::BuildJob, wait: 10.minutes)
          queue_job(MTG::Art::BuildJob, wait: 1.minute)
          build(status: "failed", job_id: job.active_job_id, message: "boom")

          expect(operation.summary).to eq("Queued to retry. The last build failed. Boom.")
          expect(operation.facts.first).to have_attributes(label: "Retrying at", value: 10.minutes.from_now)
        end
      end

      it "is plain queued once the retry is due, with nothing left to say about when", :aggregate_failures do
        loaded
        build(status: "failed", job_id: queue_job(MTG::Art::BuildJob).active_job_id, message: "boom")

        expect(operation).to have_attributes(state: :queued, summary: "Queued.", facts: [])
      end
    end

    # A build queued fresh has no failed build of its own behind it, whatever the latest build was (issue #80).
    context "when a build job is queued fresh" do
      it "is plain queued behind another job's failed build", :aggregate_failures do
        loaded
        build(status: "failed", job_id: "job-1", message: "boom")
        queue_job(MTG::Art::BuildJob)

        expect(operation).to have_attributes(state: :queued, summary: "Queued.", facts: [], failed_job?: false)
      end

      # A retry that never opened a build of its own: the database was busy before MTG::ArtBuild.start! could.
      it "doesn't give another job's failure as the reason a scheduled job waits, but still says when it is due", :aggregate_failures do
        loaded
        freeze_time do
          build(status: "failed", job_id: "job-1", message: "boom")
          queue_job(MTG::Art::BuildJob, wait: 3.minutes)

          expect(operation).to have_attributes(state: :queued, summary: "Queued.")
          expect(operation.facts.map { |fact| [ fact.label, fact.value ] }).to eq([ [ "Retrying at", 3.minutes.from_now ] ])
        end
      end

      it "is plain queued behind a finished build" do
        loaded
        build
        queue_job(MTG::Art::BuildJob)

        expect(operation).to have_attributes(state: :queued, summary: "Queued.", facts: [])
      end
    end

    # A worker that dies never closes its build; the queue fails the job it held (issue #73).
    context "when the queue has failed a running build's job" do
      let(:job) { fail_job(claim_job(queue_job(MTG::Art::BuildJob)), SolidQueue::Processes::ProcessPrunedError.new(6.minutes.ago)) }

      it "is interrupted before it goes stale, not building, and can be built again", :aggregate_failures do
        loaded
        quiet_build(job.active_job_id, total_count: 10, fingerprinted_count: 3)

        expect(operation).to have_attributes(state: :interrupted, summary: "Interrupted. Build it again to carry on from where it stopped.")
        expect(operation.meter.percent).to eq(30)
        expect(operation).not_to be_in_flight
        expect(operation).to be_startable
      end

      it "queues a build when started" do
        loaded
        quiet_build(job.active_job_id)

        expect { operation.start }.to change(SolidQueue::Job, :count).by(1)
      end

      it "points at the failed job, as an interrupted refresh does, until another build is queued", :aggregate_failures do
        loaded
        quiet_build(job.active_job_id)

        expect(operation).to be_failed_job
        queue_job(MTG::Art::BuildJob)
        expect(described_class.new("mtg")).to have_attributes(state: :queued, failed_job?: false)
      end

      it "doesn't point at another build's failed job" do
        loaded
        job
        quiet_build("job-1")

        expect(operation).to have_attributes(state: :interrupted, failed_job?: false)
      end

      # That job closes the build when it starts (MTG::ArtBuild.start!), so the build is no longer the news.
      it "is queued once another build job waits in the queue, as after \"Build art index\" (AC-4.3)", :aggregate_failures do
        loaded
        quiet_build(job.active_job_id, total_count: 10, fingerprinted_count: 3)
        queue_job(MTG::Art::BuildJob)

        expect(operation).to have_attributes(state: :queued, summary: "Queued.", meter: nil, facts: [], startable?: false)
        expect(operation).to be_in_flight
      end

      # The queue also fails the job of a worker it lost sight of while the host was suspended; that worker carries on.
      it "is still building, and in flight, while the build beat in the last 2 minutes", :aggregate_failures do
        loaded
        quiet_build(job.active_job_id, heartbeat_at: 1.minute.ago)

        expect(operation).to have_attributes(state: :building, summary: "Building.", startable?: false)
        expect(operation).to be_in_flight
      end

      it "is still building when the failed job is another build's", :aggregate_failures do
        loaded
        job
        quiet_build(claim_job(queue_job(MTG::Art::BuildJob)).active_job_id)

        expect(operation).to have_attributes(state: :building, startable?: false)
      end
    end

    # Its failed job was discarded, say: nothing will close the build, and nothing is working on it (issue #73).
    context "when a running build's job is no longer in the queue" do
      it "is interrupted before it goes stale, and can be built again", :aggregate_failures do
        loaded
        quiet_build("job-1")

        expect(operation).to have_attributes(state: :interrupted, startable?: true)
        expect(operation).not_to be_in_flight
      end

      it "is still building, and in flight, while the build beat in the last 2 minutes", :aggregate_failures do
        loaded
        quiet_build("job-1", heartbeat_at: 1.minute.ago)

        expect(operation).to have_attributes(state: :building, startable?: false)
        expect(operation).to be_in_flight
      end

      it "is interrupted when the queue's record of the job says it finished" do
        loaded
        quiet_build(finish_job(claim_job(queue_job(MTG::Art::BuildJob))).active_job_id)

        expect(operation.state).to eq(:interrupted)
      end

      it "is still building while its job waits in the queue to run again, as after a graceful restart" do
        loaded
        quiet_build(queue_job(MTG::Art::BuildJob).active_job_id)

        expect(operation).to have_attributes(state: :building, startable?: false)
      end
    end

    # A job's row is finished only after its build is closed, so the queue is read before the build: a build still
    # marked running after that read was left behind, never one whose job ended between the two reads.
    context "when the job ends normally while the page is being put together" do
      let(:job) { claim_job(queue_job(MTG::Art::BuildJob)) }

      it "never calls a build interrupted that it read before its job finished" do
        loaded
        running = quiet_build(job.active_job_id)
        operation.build
        running.finish!(:finished)
        finish_job(job)

        expect(operation.state).to eq(:building)
      end

      it "shows the build as it ended when the job finished before the queue was read" do
        loaded
        quiet_build(job.active_job_id).finish!(:finished)
        finish_job(job)

        expect(operation.state).to eq(:ready)
      end
    end

    it "shows a finished build's counts and finish time (AC-4.7)", :aggregate_failures do
      loaded
      build(indexed_count: 31_904, without_image_count: 12, failed_count: 3)

      expect(operation).to have_attributes(state: :ready, summary: "Ready.", meter: nil, startable?: true)
      expect(operation.facts.to_h { |fact| [ fact.label, fact.value ] })
        .to include("Artworks indexed" => 31_904, "Without an image" => 12, "Failed images" => 3, "Finished" => be_a(Time))
    end

    it "shows why a build failed, its error as the detail, and the index still in use (AC-4.8, issue #84)", :aggregate_failures do
      loaded
      build(status: "failed", message: "Errno::ENOSPC: No space left on device")

      expect(operation).to have_attributes(state: :failed, summary: "Failed. An unexpected error stopped it.")
      expect(operation.facts.to_h { |fact| [ fact.label, fact.value ] })
        .to include("Index in use" => "none", "Technical detail" => "Errno::ENOSPC: No space left on device")
    end

    it "says ImageMagick is missing in plain words, as the source words it (issue #84)" do
      loaded
      build(status: "failed", message: "MTG::Art::Decoder::Error: ImageMagick isn't installed: art matching needs the magick " \
                                       "(or convert) command")

      expect(operation.summary).to eq("Failed. #{MTG::Scryfall::Source.failure_reasons.fetch("MTG::Art::Decoder::Error")}")
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
