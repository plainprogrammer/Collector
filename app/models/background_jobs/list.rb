# The jobs in one state, a page at a time, with how many are in each state (spec 015 AC-6.1, AC-6.2). The states are the
# queue's execution tables: failed, claimed by a worker (running), ready or blocked by a concurrency limit (queued), and
# due later (scheduled). Each state orders by the time that matters to it.
class BackgroundJobs::List
  STATES = %w[failed running queued scheduled].freeze
  PER_PAGE = 25
  ORDERS = {
    "failed" => Arel.sql("solid_queue_failed_executions.created_at DESC, solid_queue_jobs.id DESC"),
    "running" => Arel.sql("solid_queue_claimed_executions.created_at DESC, solid_queue_jobs.id DESC"),
    "queued" => Arel.sql("solid_queue_jobs.created_at ASC, solid_queue_jobs.id ASC"),
    "scheduled" => Arel.sql("solid_queue_scheduled_executions.scheduled_at ASC, solid_queue_jobs.id ASC")
  }.freeze

  attr_reader :state

  # True while any job is running or queued: the jobs pages keep themselves current then (AC-6.10).
  def self.live?
    SolidQueue::ClaimedExecution.exists? || SolidQueue::ReadyExecution.exists? || SolidQueue::BlockedExecution.exists?
  end

  # An unknown state shows the failed list; the page number is clamped to the pages there are.
  def initialize(state:, page: nil)
    @state = STATES.include?(state) ? state : STATES.first
    @requested_page = page
  end

  def counts
    @counts ||= { "failed" => SolidQueue::FailedExecution.count, "running" => SolidQueue::ClaimedExecution.count,
                  "queued" => SolidQueue::ReadyExecution.count + SolidQueue::BlockedExecution.count,
                  "scheduled" => SolidQueue::ScheduledExecution.count }
  end

  def live? = counts["running"].positive? || counts["queued"].positive?

  def pagination
    @pagination ||= Catalog::Pagination.for(total_count: counts.fetch(state), requested_page: @requested_page, per_page: PER_PAGE)
  end

  def entries
    @entries ||= jobs.order(ORDERS.fetch(state)).offset(pagination.offset).limit(PER_PAGE)
      .preload(:failed_execution, :claimed_execution, :ready_execution, :blocked_execution, :scheduled_execution)
      .map { |job| BackgroundJobs::Entry.new(job) }
  end

  private
    def jobs
      case state
      when "failed" then SolidQueue::Job.joins(:failed_execution)
      when "running" then SolidQueue::Job.joins(:claimed_execution)
      when "scheduled" then SolidQueue::Job.joins(:scheduled_execution)
      else
        SolidQueue::Job.where(id: SolidQueue::ReadyExecution.select(:job_id))
          .or(SolidQueue::Job.where(id: SolidQueue::BlockedExecution.select(:job_id)))
      end
    end
end
