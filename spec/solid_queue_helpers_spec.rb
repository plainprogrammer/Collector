require "rails_helper"

# Spec 015 NFR Reliability: the admin pages' specs run against Solid Queue's real tables, with jobs queued through its
# adapter and never performed by a worker (spec/support/solid_queue.rb).
RSpec.describe SolidQueueHelpers, type: :model do
  it "leaves the :test adapter in place for examples that don't ask for the queue", :aggregate_failures do
    expect(ActiveJob::Base.queue_adapter).to be_a(ActiveJob::QueueAdapters::TestAdapter)
    expect { Catalog::RefreshJob.perform_later("mtg") }.to have_enqueued_job(Catalog::RefreshJob)
    expect(SolidQueue::Job.count).to eq(0)
  end

  it "loads the queue's tables without leaving its schema version behind", :aggregate_failures do
    expect(ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")).to be(true)
    expect(ActiveRecord::Base.connection_pool.schema_migration.versions).not_to include("1")
    expect(ActiveRecord::Base.connection_pool.migration_context.needs_migration?).to be(false)
  end

  context "with an example tagged :solid_queue", :solid_queue do
    it "queues through Solid Queue, honouring a job's concurrency limit", :aggregate_failures do
      ready = queue_job(Catalog::RefreshJob, "mtg", "manual")
      blocked = queue_job(Catalog::RefreshJob, "mtg", "scheduled")

      expect(ready).to be_ready
      expect(blocked).to be_blocked
      expect(ready.arguments["arguments"]).to eq(%w[mtg manual])
    end

    it "schedules a job for later with wait:" do
      freeze_time do
        expect(queue_job(MTG::Art::BuildJob, wait: 5.minutes)).to be_scheduled.and have_attributes(scheduled_at: 5.minutes.from_now)
      end
    end

    it "moves a job as a worker would: claimed, then failed with its error, releasing the next", :aggregate_failures do
      job = queue_job(Catalog::RefreshJob, "mtg", "manual")
      waiting = queue_job(Catalog::RefreshJob, "mtg", "manual")

      expect(claim_job(job)).to be_claimed
      expect(fail_job(job, ArgumentError.new("no"))).to be_failed
      expect(job.failed_execution).to have_attributes(exception_class: "ArgumentError", message: "no", backtrace: be_present)
      expect(waiting.reload).to be_ready
    end

    it "finishes a job, keeping its record" do
      expect(finish_job(queue_job(MTG::Art::BuildJob))).to be_finished
    end
  end

  it "starts every example with an empty queue" do
    expect(SolidQueue::Job.count).to eq(0)
  end
end
