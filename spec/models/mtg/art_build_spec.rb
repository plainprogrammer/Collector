require "rails_helper"

RSpec.describe MTG::ArtBuild, type: :model do
  def start(job_id = "job-a") = described_class.start!(job_id:, catalog_version: "default-cards-1", settings_digest: MTG::Art::Settings.digest)

  def running(**attributes) = create(:mtg_art_build, status: "running", finished_at: nil, **attributes)

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

  # A worker that dies never closes its build; the queue fails the job it held (issue #73).
  it "closes a running build whose job the queue has failed, before it goes stale, and runs", :aggregate_failures, :solid_queue do
    job = fail_job(claim_job(queue_job(MTG::Art::BuildJob)), SolidQueue::Processes::ProcessPrunedError.new(6.minutes.ago))
    crashed = running(started_at: 8.minutes.ago, heartbeat_at: 7.minutes.ago, job_id: job.active_job_id)

    expect(start("job-b")).to be_running
    expect(crashed.reload).to have_attributes(status: "failed", message: "interrupted")
  end

  # Its failed job was discarded, say, or it never had one in the queue (issue #73).
  it "closes a running build whose job is no longer in the queue, before it goes stale, and runs", :aggregate_failures do
    left = running(started_at: 8.minutes.ago, heartbeat_at: 7.minutes.ago, job_id: "job-a")

    expect(start("job-b")).to be_running
    expect(left.reload).to have_attributes(status: "failed", message: "interrupted")
  end

  # The queue also fails the job of a worker it lost sight of (a suspended host) while that worker may still be working.
  it "is skipped while a build whose job the queue has failed beat in the last 2 minutes (issue #73)", :aggregate_failures, :solid_queue do
    job = fail_job(claim_job(queue_job(MTG::Art::BuildJob)))
    live = running(started_at: 8.minutes.ago, heartbeat_at: 1.minute.ago, job_id: job.active_job_id)

    expect(start("job-b")).to have_attributes(status: "skipped", message: "already running")
    expect(live.reload).to be_running
  end

  it "is skipped while a worker holds the job of a build that beat in the last 10 minutes (AC-3.2)", :aggregate_failures, :solid_queue do
    job = claim_job(queue_job(MTG::Art::BuildJob))
    live = running(started_at: 1.hour.ago, heartbeat_at: 9.minutes.ago, job_id: job.active_job_id)

    expect(start("job-b")).to have_attributes(status: "skipped", message: "already running")
    expect(live.reload).to be_running
  end

  it "closes a stale build even while a worker holds its job, then runs (AC-3.2)", :aggregate_failures, :solid_queue do
    job = claim_job(queue_job(MTG::Art::BuildJob))
    stale = running(started_at: 1.hour.ago, heartbeat_at: 11.minutes.ago, job_id: job.active_job_id)

    expect(start("job-b")).to be_running
    expect(stale.reload).to have_attributes(status: "failed", message: "interrupted")
  end

  # A retry backing off is an unfinished job: it closes its own build when it starts.
  it "is skipped while the running build's job is scheduled to run again", :aggregate_failures, :solid_queue do
    job = queue_job(MTG::Art::BuildJob, wait: 5.minutes)
    waiting = running(started_at: 8.minutes.ago, heartbeat_at: 7.minutes.ago, job_id: job.active_job_id)

    expect(start("job-b")).to have_attributes(status: "skipped", message: "already running")
    expect(waiting.reload).to be_running
  end

  it "is skipped while another build's job waits to run again, with no build running (issue #78)", :aggregate_failures, :solid_queue do
    job = queue_job(MTG::Art::BuildJob, wait: 5.minutes)
    failed = create(:mtg_art_build, status: "failed", job_id: job.active_job_id, message: "rate limited")

    expect(start("job-b")).to have_attributes(status: "skipped", message: "waiting for another job's retry")
    expect(failed.reload).to have_attributes(status: "failed", message: "rate limited")
  end

  it "runs when the build job held for later is its own (issue #78)", :solid_queue do
    job = queue_job(MTG::Art::BuildJob, wait: 5.minutes)

    expect(start(job.active_job_id)).to be_running
  end

  it "is skipped while a build whose job never was in the queue beat in the last 2 minutes", :aggregate_failures do
    live = running(started_at: 8.minutes.ago, heartbeat_at: 1.minute.ago, job_id: "from-a-console")

    expect(start("job-b")).to have_attributes(status: "skipped", message: "already running")
    expect(live.reload).to be_running
  end

  it "is skipped while a build that recorded no job beat in the last 10 minutes", :aggregate_failures do
    live = running(started_at: 8.minutes.ago, heartbeat_at: 7.minutes.ago, job_id: nil)

    expect(start("job-b")).to have_attributes(status: "skipped", message: "already running")
    expect(live.reload).to be_running
  end

  # Another build's job is queued, and records its build, between this one reading the queue and reading the builds.
  it "leaves alone a build that started after it read the queue", :aggregate_failures do
    later = nil
    allow(described_class).to receive(:job_queue).and_wrap_original do |job_queue|
      job_queue.call.read.tap { later = running(started_at: 1.second.from_now, heartbeat_at: 3.minutes.ago, job_id: "queued-since") }
    end

    expect(start("job-b")).to have_attributes(status: "skipped", message: "already running")
    expect(later.reload).to be_running
  end

  describe "#left_behind?" do
    let(:queue) { described_class.job_queue }

    it "counts a heartbeat as stopped only when it is older than 2 minutes, with its job ended", :aggregate_failures do
      freeze_time do
        build = running(started_at: 8.minutes.ago, heartbeat_at: 2.minutes.ago, job_id: "job-a")

        expect(build.left_behind?(queue)).to be(false)
        travel 1.second
        expect(build.left_behind?(queue)).to be(true)
      end
    end

    it "counts a heartbeat as stale only when it is older than 10 minutes, with its job held", :aggregate_failures, :solid_queue do
      job = claim_job(queue_job(MTG::Art::BuildJob))
      freeze_time do
        build = running(started_at: 1.hour.ago, heartbeat_at: 10.minutes.ago, job_id: job.active_job_id)

        expect(build.left_behind?(queue)).to be(false)
        travel 1.second
        expect(build.left_behind?(queue)).to be(true)
      end
    end

    it "keeps the 10-minute rule for a build that recorded no job", :aggregate_failures do
      build = running(started_at: 1.hour.ago, heartbeat_at: 9.minutes.ago, job_id: nil)

      expect(build.left_behind?(queue)).to be(false)
      travel(2.minutes) { expect(build.left_behind?(queue)).to be(true) }
    end

    it "is true once the queue has failed its job and it hasn't beaten for 2 minutes (issue #73)", :aggregate_failures, :solid_queue do
      job = fail_job(claim_job(queue_job(MTG::Art::BuildJob)))
      build = running(started_at: 8.minutes.ago, heartbeat_at: 1.minute.ago, job_id: job.active_job_id)

      expect(build.left_behind?(queue)).to be(false)
      travel(61.seconds) { expect(build.left_behind?(queue)).to be(true) }
    end

    it "is true once its job is no longer in the queue and it hasn't beaten for 2 minutes (issue #73)", :aggregate_failures do
      build = running(started_at: 8.minutes.ago, heartbeat_at: 1.minute.ago, job_id: "job-a")

      expect(build.left_behind?(queue)).to be(false)
      travel(61.seconds) { expect(build.left_behind?(queue)).to be(true) }
    end

    it "is true when the queue's record of its job says it finished", :solid_queue do
      job = finish_job(claim_job(queue_job(MTG::Art::BuildJob)))

      expect(running(heartbeat_at: 3.minutes.ago, job_id: job.active_job_id).left_behind?(queue)).to be(true)
    end

    it "is false while its job waits in the queue or a worker holds it, until it goes stale", :aggregate_failures, :solid_queue do
      waiting = running(started_at: 1.hour.ago, heartbeat_at: 9.minutes.ago, job_id: queue_job(MTG::Art::BuildJob).active_job_id)
      held = running(started_at: 1.hour.ago, heartbeat_at: 9.minutes.ago, job_id: claim_job(queue_job(MTG::Art::BuildJob)).active_job_id)

      expect([ waiting, held ].map { it.left_behind?(queue) }).to eq([ false, false ])
      travel(2.minutes) { expect([ waiting, held ].map { it.left_behind?(queue) }).to eq([ true, true ]) }
    end

    # Its job was queued since: a reading of the queue from before the build started can't say that job is gone.
    it "is false for a build that started after the queue was read, until it goes stale", :aggregate_failures do
      queue.read
      build = travel(1.second) { running(started_at: Time.current, heartbeat_at: Time.current, job_id: "queued-since") }

      travel(3.minutes) { expect(build.left_behind?(queue)).to be(false) }
      travel(11.minutes) { expect(build.left_behind?(queue)).to be(true) }
    end

    it "is false for a build that ended" do
      expect(create(:mtg_art_build, job_id: "job-a").left_behind?(queue)).to be(false)
    end
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

  describe "#stalled?" do
    let(:queue) { described_class.job_queue }

    it "is true once the heartbeat is older than 10 minutes while a worker still holds the build's job", :aggregate_failures, :solid_queue do
      job = claim_job(queue_job(MTG::Art::BuildJob))
      build = running(heartbeat_at: 9.minutes.ago, job_id: job.active_job_id)

      expect(build.stalled?(queue)).to be(false)
      travel(2.minutes + 1.second) do # travel drops the fraction of the second
        expect(build.stalled?(queue)).to be(true)
        expect(build.stalled_minutes).to eq(11)
      end
    end

    it "is false when the job is failed, waiting, gone or another build's, and for a build that ended", :aggregate_failures, :solid_queue do
      held = claim_job(queue_job(MTG::Art::BuildJob))
      failed = fail_job(claim_job(queue_job(MTG::Art::BuildJob)))
      waiting = queue_job(MTG::Art::BuildJob)

      [ failed.active_job_id, waiting.active_job_id, "job-gone", nil ].each do |job_id|
        expect(running(heartbeat_at: 11.minutes.ago, job_id:).stalled?(queue)).to be(false)
      end
      expect(create(:mtg_art_build, heartbeat_at: 11.minutes.ago, job_id: held.active_job_id).stalled?(queue)).to be(false)
    end
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
