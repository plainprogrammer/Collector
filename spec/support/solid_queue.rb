# The admin pages read Solid Queue's own tables (spec 015, ADR 0014). The test environment has one database and the
# :test job adapter, so the queue's tables are loaded into that database once per run, and an example tagged
# :solid_queue queues its jobs through Solid Queue's adapter. No worker runs in tests: a queued job stays queued until
# the example moves it with the helpers below.
module SolidQueueHelpers
  # db/queue_schema.rb, loaded only when the tables are missing (a fresh or just-reloaded test database). Its
  # `define(version: 1)` would leave a stray version in schema_migrations, so that row is removed again.
  def self.load_tables
    return if ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")

    ActiveRecord::Migration.suppress_messages { load Rails.root.join("db/queue_schema.rb") }
  ensure
    ActiveRecord::Base.connection_pool.schema_migration.delete_version("1")
  end

  # Queues a job through Solid Queue and returns the queue's record of it. With wait:, it is scheduled for later.
  def queue_job(job_class, *arguments, wait: nil)
    job = wait ? job_class.set(wait:).perform_later(*arguments) : job_class.perform_later(*arguments)
    SolidQueue::Job.find(job.provider_job_id)
  end

  # As if a worker had picked the job up.
  def claim_job(job)
    process = SolidQueue::Process.register(kind: "Worker", pid: job.id, name: "worker-#{job.id}")
    clear_executions(job)
    SolidQueue::ClaimedExecution.create!(job_id: job.id, process_id: process.id)
    job.reload
  end

  # As if the job had raised and run out of retries: it moves to the queue's failed list.
  def fail_job(job, error = RuntimeError.new("it broke"))
    error.set_backtrace([ "app/models/example.rb:1:in 'call'", "app/jobs/example_job.rb:2:in 'perform'" ]) unless error.backtrace
    clear_executions(job)
    job.failed_with(error)
    job.unblock_next_blocked_job # a worker gives the concurrency lock back when a job ends, however it ends
    job.reload
  end

  # As if the job had run to its end.
  def finish_job(job)
    clear_executions(job)
    job.finished!
    job.unblock_next_blocked_job
    job.reload
  end

  private
    def clear_executions(job)
      [ SolidQueue::ReadyExecution, SolidQueue::BlockedExecution, SolidQueue::ScheduledExecution, SolidQueue::ClaimedExecution ]
        .each { |executions| executions.where(job_id: job.id).delete_all }
      job.reload
    end
end

RSpec.configure do |config|
  config.include SolidQueueHelpers

  config.before(:suite) { SolidQueueHelpers.load_tables }

  config.around(:each, :solid_queue) do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original
  end
end
