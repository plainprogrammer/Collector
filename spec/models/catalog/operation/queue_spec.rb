require "rails_helper"

RSpec.describe Catalog::Operation::Queue, :solid_queue, type: :model do
  subject(:queue) { described_class.new(Catalog::RefreshJob, "mtg") }

  it "holds nothing when no job is queued", :aggregate_failures do
    expect(queue).not_to be_any
    expect(queue).not_to be_failed
    expect(queue).not_to be_claimed
    expect(queue.retry_at).to be_nil
  end

  it "counts a job for the type whatever its trigger, ready or waiting on the concurrency limit (spec 015 glossary)", :aggregate_failures do
    queue_job(Catalog::RefreshJob, "mtg", "scheduled")
    expect(described_class.new(Catalog::RefreshJob, "mtg")).to be_any

    waiting = queue_job(Catalog::RefreshJob, "mtg", "manual")
    expect(waiting.blocked_execution).to be_present
    expect(described_class.new(Catalog::RefreshJob, "mtg")).to be_any
  end

  it "ignores jobs of another type, of another class, and finished ones", :aggregate_failures do
    queue_job(Catalog::RefreshJob, "other", "manual")
    queue_job(MTG::Art::BuildJob)
    finish_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

    expect(queue).not_to be_any
    expect(described_class.new(MTG::Art::BuildJob)).to be_any
  end

  it "passes over a row whose arguments aren't a job's envelope" do
    queue_job(Catalog::RefreshJob, "mtg", "manual").update_columns(arguments: "not an envelope") # rubocop:disable Rails/SkipsModelValidations -- a row nothing in the app would write

    expect(queue).not_to be_any
  end

  it "knows when a worker holds a job, and which one", :aggregate_failures do
    job = claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

    expect(queue).to be_claimed
    expect(queue.claimed?(job.active_job_id)).to be(true)
    expect(queue.claimed?("another-job")).to be(false)
  end

  it "knows when no unfinished job has an Active Job id any more: finished, discarded or never queued", :aggregate_failures do
    finished = finish_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))
    failed = fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))
    waiting = queue_job(Catalog::RefreshJob, "mtg", "manual")

    expect(queue.gone?(finished.active_job_id)).to be(true)
    expect(queue.gone?("never-queued")).to be(true)
    expect(queue.gone?(failed.active_job_id)).to be(false)
    expect(queue.gone?(waiting.active_job_id)).to be(false)
    expect(queue.job_ids).to contain_exactly(failed.active_job_id, waiting.active_job_id)
  end

  it "reads the queue once, when asked to or first asked about it, and says when", :aggregate_failures do
    freeze_time { expect(queue.read.read_at).to eq(Time.current) }
    expect(queue.read).to be(queue)
    queue_job(Catalog::RefreshJob, "mtg", "manual")

    expect(queue).not_to be_any
  end

  it "gives the time a job waiting to retry is due" do
    freeze_time do
      queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 5.minutes)

      expect(queue).to be_any.and have_attributes(retry_at: 5.minutes.from_now)
    end
  end

  it "says when one job's retry is due, by Active Job id (issue #80)", :aggregate_failures do
    freeze_time do
      retrying = queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 5.minutes)
      ready = queue_job(Catalog::RefreshJob, "mtg", "manual")

      expect(queue.retry_at(retrying.active_job_id)).to eq(5.minutes.from_now)
      expect(queue.retry_at(ready.active_job_id)).to be_nil
      expect(queue.retry_at("job-gone")).to be_nil
    end
  end

  it "knows when a job other than a given one waits to run again (issue #78)", :aggregate_failures do
    retrying = queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 5.minutes)
    queue_job(Catalog::RefreshJob, "mtg", "manual")

    expect(queue).to be_waiting_to_retry
    expect(queue.waiting_to_retry?(except: "another-job")).to be(true)
    expect(queue.waiting_to_retry?(except: retrying.active_job_id)).to be(false)
    expect(described_class.new(Catalog::RefreshJob, "other")).not_to be_waiting_to_retry
  end

  it "doesn't count a ready job, a held one or a failed one as waiting to run again", :aggregate_failures do
    queue_job(Catalog::RefreshJob, "mtg", "manual")
    claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))
    fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

    expect(queue).not_to be_waiting_to_retry
  end

  it "reports a failed job as failed, not in flight", :aggregate_failures do
    fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

    expect(queue).to be_failed
    expect(queue).not_to be_any
  end

  it "knows which jobs are in the failed list, by Active Job id (issue #60)", :aggregate_failures do
    failed = fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))
    waiting = queue_job(Catalog::RefreshJob, "mtg", "manual")
    fail_job(queue_job(Catalog::RefreshJob, "other", "manual"))

    expect(queue.failed?(failed.active_job_id)).to be(true)
    expect(queue.failed?(waiting.active_job_id)).to be(false)
    expect(queue.failed?("another-job")).to be(false)
    expect(queue.failed_job_ids).to eq([ failed.active_job_id ])
  end

  describe "#run_now (spec 055 FR-2)" do
    def waiting(wait: 10.minutes) = queue_job(Catalog::RefreshJob, "mtg", "manual", wait:)

    it "makes a scheduled job ready, adding no job and leaving its Active Job id and arguments as they were", :aggregate_failures do
      job = waiting
      before = job.slice(:id, :active_job_id, :arguments)

      expect { expect(queue.run_now(job.active_job_id)).to be(true) }.not_to change(SolidQueue::Job, :count)

      expect(job.reload.slice(:id, :active_job_id, :arguments)).to eq(before)
      expect(job).to be_ready
      expect(job.scheduled_execution).to be_nil
      expect(job.blocked_execution).to be_nil
    end

    it "moves a retry that is due but not yet dispatched, and the dispatcher then finds nothing (AC-3.2, AC-3.4)", :aggregate_failures do
      job = waiting
      job.scheduled_execution.update_columns(scheduled_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations -- the wait is over, the dispatcher hasn't run

      expect(queue.run_now(job.active_job_id)).to be(true)
      expect(SolidQueue::ScheduledExecution.dispatch_next_batch(10)).to eq(0)
      expect(SolidQueue::ReadyExecution.where(job_id: job.id).count).to eq(1)
      expect(SolidQueue::BlockedExecution.where(job_id: job.id)).to be_none
    end

    it "does nothing when the dispatcher got there first (AC-3.4)", :aggregate_failures do
      job = waiting
      job.scheduled_execution.update_columns(scheduled_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations -- the wait is over
      expect(SolidQueue::ScheduledExecution.dispatch_next_batch(10)).to eq(1)

      expect(queue.run_now(job.active_job_id)).to be(false)
      expect(SolidQueue::ReadyExecution.where(job_id: job.id).count).to eq(1)
      expect(SolidQueue::BlockedExecution.where(job_id: job.id)).to be_none
    end

    it "moves it once: a second call changes nothing (AC-3.1)", :aggregate_failures do
      job = waiting

      expect(queue.run_now(job.active_job_id)).to be(true)
      expect(queue.run_now(job.active_job_id)).to be(false)
      expect(SolidQueue::ReadyExecution.where(job_id: job.id).count).to eq(1)
      expect(SolidQueue::BlockedExecution.where(job_id: job.id)).to be_none
    end

    it "does nothing for a job that isn't waiting for a later time (AC-3.3)", :aggregate_failures do
      job = queue_job(Catalog::RefreshJob, "mtg", "manual")
      expect(queue.run_now(job.active_job_id)).to be(false) # ready
      claim_job(job)
      expect(queue.run_now(job.active_job_id)).to be(false) # claimed
      finish_job(job)
      expect(queue.run_now(job.active_job_id)).to be(false) # finished
      failed = fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))
      expect(queue.run_now(failed.active_job_id)).to be(false) # failed
      expect(queue.run_now("no-such-job")).to be(false)
      expect(SolidQueue::BlockedExecution.count).to eq(0)
    end

    it "moves no job of another type or another class, whatever its Active Job id", :aggregate_failures do
      other_type = queue_job(Catalog::RefreshJob, "other", "manual", wait: 10.minutes)
      other_class = queue_job(MTG::Art::BuildJob, wait: 10.minutes)

      expect(queue.run_now(other_type.active_job_id)).to be(false)
      expect(queue.run_now(other_class.active_job_id)).to be(false)
      expect(other_type.reload).to be_scheduled
      expect(other_class.reload).to be_scheduled
    end

    it "blocks a refresh behind another refresh of the type that holds its lock, and runs it when that one ends (AC-2.7)", :aggregate_failures do
      holder = queue_job(Catalog::RefreshJob, "mtg", "scheduled") # takes the type's concurrency lock
      job = waiting

      expect(queue.run_now(job.active_job_id)).to be(true)
      expect(job.reload).to be_blocked
      expect(job.ready_execution).to be_nil

      finish_job(holder)
      expect(job.reload).to be_ready
    end

    it "moves the scheduled row of a refresh retry whose old attempt is still claimed, to a blocked entry (AC-3.6)", :aggregate_failures do
      old = claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))
      retry_row = waiting
      retry_row.update_columns(active_job_id: old.active_job_id) # rubocop:disable Rails/SkipsModelValidations -- Active Job's retry keeps the id

      expect(queue.run_now(old.active_job_id)).to be(true)
      expect(retry_row.reload).to be_blocked
      expect(old.reload).to be_claimed

      finish_job(old)
      expect(retry_row.reload).to be_ready
    end

    it "moves the scheduled row of an art build retry whose old attempt is still claimed, to a ready entry (AC-3.7)", :aggregate_failures do
      builds = described_class.new(MTG::Art::BuildJob)
      old = claim_job(queue_job(MTG::Art::BuildJob))
      retry_row = queue_job(MTG::Art::BuildJob, wait: 10.minutes)
      retry_row.update_columns(active_job_id: old.active_job_id) # rubocop:disable Rails/SkipsModelValidations -- Active Job's retry keeps the id

      expect(builds.run_now(old.active_job_id)).to be(true)
      expect(retry_row.reload).to be_ready
      expect(old.reload).to be_claimed
      expect(SolidQueue::BlockedExecution.count).to eq(0)
    end

    it "puts the entry back when the dispatch fails, so nothing is lost", :aggregate_failures do
      job = waiting
      allow(SolidQueue::Semaphore).to receive(:wait).and_raise(ActiveRecord::StatementTimeout)

      expect { queue.run_now(job.active_job_id) }.to raise_error(ActiveRecord::StatementTimeout)
      expect(job.reload).to be_scheduled
    end
  end
end
