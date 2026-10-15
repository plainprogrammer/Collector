# What the job queue holds for an operation's job (spec 015 glossary, "In flight"): its unfinished jobs, whoever queued
# them and with whatever other arguments, read from Solid Queue's own records (ADR 0014). Given a first argument (the
# catalog type), only jobs queued with it count. A failed job is unfinished too, but it is not in flight.
class Catalog::Operation::Queue
  def initialize(job_class, first_argument = nil)
    @job_class = job_class
    @first_argument = first_argument
  end

  # Reads the queue now rather than when first asked about it, so that what is read next can be judged by it: a job's
  # row is finished only after the job's own record of its work is closed.
  def read = jobs && self

  # When the queue was read, reading it now if it hasn't been.
  def read_at = jobs && @read_at

  def any? = in_flight.any?

  # True when one of the jobs is in the failed list; with an Active Job id, when that job is.
  def failed?(active_job_id = nil)
    jobs.any? { |job| job.failed? && (active_job_id.nil? || job.active_job_id == active_job_id) }
  end

  # The Active Job ids of the jobs in the failed list.
  def failed_job_ids = jobs.select(&:failed?).filter_map(&:active_job_id)

  # The Active Job ids of every unfinished job, failed ones included.
  def job_ids = jobs.filter_map(&:active_job_id)

  # True when no unfinished job has this Active Job id: it finished, it was discarded, or it was never in the queue.
  def gone?(active_job_id) = jobs.none? { |job| job.active_job_id == active_job_id }

  # True when a worker holds one of the jobs; with an Active Job id, when it holds that job.
  def claimed?(active_job_id = nil)
    in_flight.any? { |job| job.claimed? && (active_job_id.nil? || job.active_job_id == active_job_id) }
  end

  # When the earliest job waiting for a later time (a retry backing off) is due, or nil when none is; with an Active
  # Job id, when that job is.
  def retry_at(active_job_id = nil)
    in_flight.select { |job| job.scheduled? && (active_job_id.nil? || job.active_job_id == active_job_id) }.filter_map(&:scheduled_at).min
  end

  # True when an unfinished job other than the one with this Active Job id waits for a later time: a retry backing off
  # (issue #78). The job retrying will do the work, so another one starting meanwhile leaves it alone.
  def waiting_to_retry?(except: nil) = in_flight.any? { |job| job.scheduled? && job.active_job_id != except }

  private
    def in_flight = jobs.reject(&:failed?)

    def jobs
      @jobs ||= begin
        @read_at = Time.current
        SolidQueue::Job.where(class_name: @job_class.name, finished_at: nil)
          .includes(:failed_execution, :claimed_execution, :scheduled_execution)
          .select { |job| @first_argument.nil? || first_argument_of(job) == @first_argument }
      end
    end

    # A row whose stored arguments aren't Active Job's envelope (nothing the app queues) matches no type.
    def first_argument_of(job) = (Array(job.arguments["arguments"]).first if job.arguments.is_a?(Hash))
end
