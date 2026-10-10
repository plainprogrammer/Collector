require "rails_helper"

RSpec.describe BackgroundJobs::Entry, :solid_queue, type: :model do
  def entry(job) = described_class.find(job.id)

  it "raises not found for a job the queue doesn't have" do
    expect { described_class.find(0) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "describes a queued job by the arguments it was queued with (spec 015 AC-6.2, AC-6.5)", :aggregate_failures do
    job = entry(queue_job(Catalog::RefreshJob, "mtg", "manual"))

    expect(job).to have_attributes(class_name: "Catalog::RefreshJob", queue_name: "sync", priority: 0, attempts: 0,
      arguments: %w[mtg manual], arguments_text: '["mtg","manual"]', short_arguments: '["mtg","manual"]',
      list_note: '["mtg","manual"]',
      state: :queued, state_label: "Queued", failed?: false, due_at: nil, started_at: nil, failed_at: nil)
    expect(job.listed_at).to eq(job.queued_at)
    expect(job.to_param).to eq(job.id.to_s)
  end

  it "shortens long arguments for a list row" do
    job = entry(queue_job(Catalog::RefreshJob, "x" * 200, "manual"))

    expect(job.short_arguments.length).to eq(80)
  end

  it "knows each state and the time that matters to it", :aggregate_failures do
    freeze_time do
      waiting = queue_job(Catalog::RefreshJob, "mtg", "manual") && entry(queue_job(Catalog::RefreshJob, "mtg", "manual"))
      scheduled = entry(queue_job(MTG::Art::BuildJob, wait: 5.minutes))
      running = entry(claim_job(queue_job(MTG::Art::BuildJob)))
      finished = entry(finish_job(queue_job(MTG::Art::BuildJob)))

      expect(waiting).to have_attributes(state: :waiting, state_label: "Queued, waiting", list_note: '["mtg","manual"] · waiting')
      expect(scheduled.list_note).to be_nil # a job without arguments has nothing to note
      expect(scheduled).to have_attributes(state: :scheduled, due_at: 5.minutes.from_now, listed_at: 5.minutes.from_now)
      expect(running).to have_attributes(state: :running, started_at: Time.current, listed_at: Time.current)
      expect(finished).to have_attributes(state: :finished, state_label: "Finished", finished_at: Time.current, failed?: false)
    end
  end

  context "with a failed job" do
    let(:job) { fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"), Catalog::Sources::TransientError.new("GET /bulk-data returned 503\nmore")) }

    it "gives the error, its first line for a list row, and the backtrace (AC-6.3, AC-6.5)", :aggregate_failures do
      expect(entry(job)).to have_attributes(state: :failed, failed?: true, error_class: "Catalog::Sources::TransientError",
        error_message: "GET /bulk-data returned 503\nmore", error_line: "Catalog::Sources::TransientError: GET /bulk-data returned 503",
        backtrace: [ "app/models/example.rb:1:in 'call'", "app/jobs/example_job.rb:2:in 'perform'" ])
      expect(entry(job).listed_at).to eq(entry(job).failed_at)
    end

    it "queues it to run again and takes it off the failed list (AC-6.6)", :aggregate_failures do
      expect(entry(job).retry).to be(true)
      expect(entry(job)).to have_attributes(state: :queued, failed?: false)
      expect(SolidQueue::FailedExecution.count).to eq(0)
    end

    it "removes it for good (AC-6.7)", :aggregate_failures do
      expect(entry(job).discard).to be(true)
      expect(SolidQueue::Job.count).to eq(0)
    end

    it "never touches a refresh run or an art build by retrying or discarding (AC-6.11)" do
      run = create(:catalog_refresh_run, status: "failed", job_id: job.active_job_id)
      build = create(:mtg_art_build, status: "failed")

      expect { entry(job).retry && entry(fail_job(queue_job(MTG::Art::BuildJob))).discard }
        .not_to(change { [ run.reload.attributes, build.reload.attributes ] })
    end
  end

  it "refuses to retry or discard a job that isn't failed, changing nothing (AC-6.8)", :aggregate_failures do
    queued = queue_job(MTG::Art::BuildJob)
    running = claim_job(queue_job(MTG::Art::BuildJob))

    expect([ entry(queued).retry, entry(queued).discard, entry(running).retry, entry(running).discard ]).to all(be(false))
    expect(SolidQueue::Job.count).to eq(2)
  end

  it "refuses when another admin handled the failed job in between (AC-6.8)", :aggregate_failures do
    stale = entry(fail_job(queue_job(MTG::Art::BuildJob)))
    stale.state # loaded as failed
    SolidQueue::FailedExecution.sole.retry

    expect(stale.retry).to be(false)
    expect(SolidQueue::Job.sole).to be_ready
  end

  it "describes, retries and discards a job whose class no longer exists (Error Scenarios)", :aggregate_failures do
    job = fail_job(queue_job(MTG::Art::BuildJob))
    job.update_columns(class_name: "Removed::InAnUpgradeJob") # rubocop:disable Rails/SkipsModelValidations -- as an upgrade leaves it

    expect(entry(job)).to have_attributes(class_name: "Removed::InAnUpgradeJob", state: :failed, arguments: [])
    expect(entry(job).retry).to be(true)
    expect(entry(job).state).to eq(:queued)
    expect(entry(fail_job(SolidQueue::Job.sole)).discard).to be(true)
  end

  it "describes a row whose arguments aren't a job's envelope, without failing", :aggregate_failures do
    job = queue_job(MTG::Art::BuildJob)
    job.update_columns(arguments: "not an envelope") # rubocop:disable Rails/SkipsModelValidations -- a row nothing in the app would write

    expect(entry(job)).to have_attributes(arguments: [], arguments_text: "[]", attempts: 0, list_note: nil)
  end

  it "shows the queue's own maintenance job by its command (glossary)" do
    job = SolidQueue::Job.enqueue(SolidQueue::RecurringJob.new("SolidQueue::Job.clear_finished_in_batches"))

    expect(entry(job)).to have_attributes(class_name: "SolidQueue::RecurringJob",
      arguments_text: '["SolidQueue::Job.clear_finished_in_batches"]')
  end
end
