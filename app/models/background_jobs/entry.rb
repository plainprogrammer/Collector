# One job in the queue as the admin jobs pages show it (spec 015 AC-6.2 to AC-6.9): what it is, where it stands, and,
# for a failed one, why. Only a failed job can be retried or discarded, through the queue's own operations.
class BackgroundJobs::Entry
  STATE_LABELS = { failed: "Failed", running: "Running", waiting: "Queued, waiting", queued: "Queued",
                   scheduled: "Scheduled", finished: "Finished", unknown: "Unknown" }.freeze
  SHORT = 80

  attr_reader :job

  delegate :id, :class_name, :queue_name, :priority, :finished_at, to: :job

  # Raises ActiveRecord::RecordNotFound when the queue has no such job, so the request answers 404.
  def self.find(id) = new(SolidQueue::Job.find(id))

  def initialize(job)
    @job = job
  end

  def to_param = id.to_s

  # :failed, :running, :waiting (queued, blocked by a concurrency limit), :queued, :scheduled or :finished.
  def state
    if job.finished? then :finished
    elsif job.failed? then :failed
    elsif job.claimed? then :running
    elsif job.blocked? then :waiting
    elsif job.ready? then :queued
    elsif job.scheduled? then :scheduled
    else :unknown
    end
  end

  def state_label = STATE_LABELS.fetch(state)

  def failed? = state == :failed

  # The arguments the job was queued with, not the queue's envelope around them.
  def arguments = Array(envelope["arguments"])
  def arguments_text = ActiveSupport::JSON.encode(arguments)
  def short_arguments = arguments_text.truncate(SHORT)

  # Under the job's name in a list: its arguments when it has any, and that it waits on a concurrency limit.
  def list_note = [ (short_arguments if arguments.any?), ("waiting" if state == :waiting) ].compact.join(" · ").presence

  def attempts = envelope["executions"].to_i

  def queued_at = job.created_at
  def due_at = (job.scheduled_at if state == :scheduled)
  def started_at = job.claimed_execution&.created_at
  def failed_at = job.failed_execution&.created_at

  # The time the lists show and order by, for the state the job is in.
  def listed_at
    case state
    when :failed then failed_at
    when :running then started_at
    when :scheduled then job.scheduled_at
    when :finished then finished_at
    else queued_at
    end
  end

  def error_class = job.failed_execution&.exception_class
  def error_message = job.failed_execution&.message.to_s
  def backtrace = Array(job.failed_execution&.backtrace)

  # The exception class and the first line of its message, for a list row.
  def error_line = "#{error_class}: #{error_message.lines.first.to_s.strip}".truncate(2 * SHORT)

  # Queues a failed job to run again. False, changing nothing, when it isn't failed (any more).
  def retry
    return false unless failed?

    job.failed_execution.retry
    true
  rescue ActiveRecord::RecordNotFound
    false
  end

  # Removes a failed job for good. False, changing nothing, when it isn't failed (any more).
  def discard
    return false unless failed?

    job.failed_execution.discard
    true
  rescue ActiveRecord::RecordNotFound
    false
  end

  private
    # Active Job's record of the job, or nothing for a row that isn't one (nothing the app queues).
    def envelope = job.arguments.is_a?(Hash) ? job.arguments : {}
end
