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

  it "gives the time a job waiting to retry is due" do
    freeze_time do
      queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 5.minutes)

      expect(queue).to be_any.and have_attributes(retry_at: 5.minutes.from_now)
    end
  end

  it "reports a failed job as failed, not in flight", :aggregate_failures do
    fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

    expect(queue).to be_failed
    expect(queue).not_to be_any
  end
end
