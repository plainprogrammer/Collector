# What the job queue holds for an operation's job (spec 015 glossary, "In flight"): its unfinished jobs, whoever queued
# them and with whatever other arguments, read from Solid Queue's own records (ADR 0014). Given a first argument (the
# catalog type), only jobs queued with it count. A failed job is unfinished too, but it is not in flight.
class Catalog::Operation::Queue
  def initialize(job_class, first_argument = nil)
    @job_class = job_class
    @first_argument = first_argument
  end

  def any? = in_flight.any?

  def failed? = jobs.any?(&:failed?)

  # True when a worker holds one of the jobs; with an Active Job id, when it holds that job.
  def claimed?(active_job_id = nil)
    in_flight.any? { |job| job.claimed? && (active_job_id.nil? || job.active_job_id == active_job_id) }
  end

  # When the earliest job waiting for a later time (a retry backing off) is due, or nil when none is.
  def retry_at = in_flight.select(&:scheduled?).filter_map(&:scheduled_at).min

  private
    def in_flight = jobs.reject(&:failed?)

    def jobs
      @jobs ||= SolidQueue::Job.where(class_name: @job_class.name, finished_at: nil)
        .includes(:failed_execution, :claimed_execution, :scheduled_execution)
        .select { |job| @first_argument.nil? || first_argument_of(job) == @first_argument }
    end

    # A row whose stored arguments aren't Active Job's envelope (nothing the app queues) matches no type.
    def first_argument_of(job) = (Array(job.arguments["arguments"]).first if job.arguments.is_a?(Hash))
end
