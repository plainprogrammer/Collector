# One attempt to apply a catalog source's data, with its outcome and counts. While it runs it also records its stage,
# how far through that stage it is and when it last made progress (spec 015 FR-1).
class Catalog::RefreshRun < ApplicationRecord
  # No progress for this long means the run stalled; a refresh that starts then closes it as interrupted (spec 015
  # AC-3.3). The job's queue lock is separate and much longer (Catalog::RefreshJob::LOCK_FOR).
  STALL_AFTER = 15.minutes
  # A run whose job the queue has failed, or no longer holds, is taken as left behind only once its own last progress
  # is this old. The queue also fails the job of a worker it lost sight of while that worker lives (a suspended host,
  # a paused container), and such a run goes on recording progress. A working run records it every 2 seconds while
  # downloading and syncing (Catalog::Refresh::Progress), and once on entering the retire and index stages, which
  # took 0.9 and 4.5 seconds on a catalog of 110,000 entries; one hung request to the source lasts at most about 70
  # seconds. Two minutes is above all of these.
  JOB_ENDED_GRACE = 2.minutes
  TRIGGERS = %w[scheduled manual].freeze
  COUNTS = %i[seen inserted updated retired restored malformed].freeze
  STAGES = %w[download sync retire index].freeze
  ALREADY_RUNNING = "already running".freeze
  # Another job for the type waits in the queue to run again (a rate limit, issue #78): it will do the work, and asking
  # the source before then could land inside the wait the source asked for.
  WAITING_FOR_RETRY = "waiting for another job's retry".freeze
  INTERRUPTED = "interrupted".freeze
  LAST_PROGRESS = Arel.sql("COALESCE(heartbeat_at, started_at)")

  enum :status, { running: "running", applied: "applied", skipped: "skipped", failed: "failed" }, validate: true

  validates :collectible_type, :started_at, presence: true
  validates :trigger, inclusion: { in: TRIGGERS }
  validates :stage, inclusion: { in: STAGES }, allow_nil: true

  scope :for_type, ->(collectible_type) { where(collectible_type:) }
  scope :recent, -> { order(started_at: :desc, id: :desc) }
  scope :stalled, -> { running.where(LAST_PROGRESS.lteq(STALL_AFTER.ago)) }
  # Running without progress for JOB_ENDED_GRACE: quiet long enough to be judged by what became of its job.
  scope :quiet, -> { running.where(LAST_PROGRESS.lteq(JOB_ENDED_GRACE.ago)) }
  # Every run but the ones skipped because another was running or waiting to retry: what the catalog page shows as "the"
  # run (AC-2.16).
  scope :attempted, -> { where.not(status: :skipped, message: [ ALREADY_RUNNING, WAITING_FOR_RETRY ]) }

  # Records a new attempt. A run still marked running is closed as failed ("interrupted") when it has made no
  # progress for STALL_AFTER, or when it belongs to the job that is starting now (the queue re-ran the job after a
  # restart, or an admin retried it), or, once it has made no progress for JOB_ENDED_GRACE, to a job the queue has
  # failed (failed_job_ids: its worker died before it could close the run) or to a job that is no longer in the queue
  # at all (one not among queued_job_ids, the unfinished jobs as read before this call, at queue_read_at; nil when the
  # queue wasn't read). That reading says nothing about a run that started after it: its job was queued since. Any
  # other running run makes this attempt a skip, and so does one that recorded no job until it stalls. With none
  # running, so does another job for the type waiting in the queue to run again (retry_waiting, issue #78).
  def self.start!(collectible_type, trigger:, job_id: nil, failed_job_ids: [], queued_job_ids: nil, queue_read_at: nil,
    retry_waiting: false)
    transaction do
      runs = for_type(collectible_type)
      left_behind = runs.stalled
      left_behind = left_behind.or(runs.running.where(job_id:)) if job_id.present?
      failed_job_ids = failed_job_ids.compact_blank
      left_behind = left_behind.or(runs.quiet.where(job_id: failed_job_ids)) if failed_job_ids.any?
      left_behind = left_behind.or(job_gone(runs, queued_job_ids, queue_read_at)) if queued_job_ids
      left_behind.find_each { |run| run.finish!(:failed, message: INTERRUPTED) }

      skip = (ALREADY_RUNNING if runs.running.exists?) || (WAITING_FOR_RETRY if retry_waiting)
      now = Time.current
      run = create!(collectible_type:, trigger:, job_id:, status: :running, started_at: now, heartbeat_at: now)
      run.finish!(:skipped, message: skip) if skip
      run
    end
  end

  def self.job_gone(runs, queued_job_ids, queue_read_at)
    gone = runs.quiet.where.not(job_id: [ nil, *queued_job_ids ])
    queue_read_at ? gone.where(started_at: ..queue_read_at) : gone
  end
  private_class_method :job_gone

  def self.applied?(collectible_type, source_version:, languages:)
    for_type(collectible_type).applied.exists?(source_version:, languages:)
  end

  def self.last_applied = applied.order(finished_at: :desc).first

  # The run's place in its work, written as it goes: the stage, how far through it (when the source says), and the
  # counts so far. Each write is also the heartbeat.
  def progress!(stage:, done: nil, total: nil, counts: {})
    update!(stage:, stage_done: done, stage_total: total, heartbeat_at: Time.current, **count_columns(counts))
  end

  def finish!(status, message: nil, counts: {})
    update!(status:, message:, finished_at: Time.current, **count_columns(counts))
    Rails.logger.info(ActiveSupport::JSON.encode(event: "catalog.refresh.finished", collectible_type:,
      trigger:, status:, source_version:, languages:, message:, **self.counts))
  end

  def counts = COUNTS.index_with { |name| public_send(:"#{name}_count") }

  def last_progress_at = heartbeat_at || started_at

  def stalled? = running? && last_progress_at <= STALL_AFTER.ago

  def stalled_minutes = ((Time.current - last_progress_at) / 60).floor

  def quiet? = running? && last_progress_at <= JOB_ENDED_GRACE.ago

  # The status as the catalog page and `catalog:status` word it. A stalled run is interrupted unless its job is still
  # claimed by a worker (job_claimed), and a running one is interrupted without waiting to stall when its job ended
  # without closing it (job_ended: the queue failed the job, or no longer holds it) and it has made no progress for
  # JOB_ENDED_GRACE; only the queue knows either (spec 015 AC-3.2, AC-3.5, AC-3.6, AC-3.9).
  def status_label(job_claimed: false, job_ended: false)
    return INTERRUPTED if job_ended && quiet?
    return status unless stalled?

    job_claimed ? "running (no progress for #{stalled_minutes} minutes)" : INTERRUPTED
  end

  def status_line(job_claimed: false, job_ended: false)
    [ started_at.utc.iso8601, finished_at&.utc&.iso8601 || "-", status_label(job_claimed:, job_ended:), trigger, source_version || "-",
      counts.map { |name, value| "#{name}=#{value}" }.join(" "), message ].compact.join("  ")
  end

  private
    def count_columns(counts) = counts.transform_keys { |name| :"#{name}_count" }
end
