# One attempt to apply a catalog source's data, with its outcome and counts. While it runs it also records its stage,
# how far through that stage it is and when it last made progress (spec 015 FR-1).
class Catalog::RefreshRun < ApplicationRecord
  # No progress for this long means the run stalled; a refresh that starts then closes it as interrupted (spec 015
  # AC-3.3). The job's queue lock is separate and much longer (Catalog::RefreshJob::LOCK_FOR).
  STALL_AFTER = 15.minutes
  TRIGGERS = %w[scheduled manual].freeze
  COUNTS = %i[seen inserted updated retired restored malformed].freeze
  STAGES = %w[download sync retire index].freeze
  ALREADY_RUNNING = "already running".freeze
  INTERRUPTED = "interrupted".freeze
  LAST_PROGRESS = Arel.sql("COALESCE(heartbeat_at, started_at)")

  enum :status, { running: "running", applied: "applied", skipped: "skipped", failed: "failed" }, validate: true

  validates :collectible_type, :started_at, presence: true
  validates :trigger, inclusion: { in: TRIGGERS }
  validates :stage, inclusion: { in: STAGES }, allow_nil: true

  scope :for_type, ->(collectible_type) { where(collectible_type:) }
  scope :recent, -> { order(started_at: :desc, id: :desc) }
  scope :stalled, -> { running.where(LAST_PROGRESS.lteq(STALL_AFTER.ago)) }
  # Every run but the ones skipped because another was running: what the catalog page shows as "the" run (AC-2.16).
  scope :attempted, -> { where.not(status: :skipped, message: ALREADY_RUNNING) }

  # Records a new attempt. A run still marked running is closed as failed ("interrupted") when it has made no
  # progress for STALL_AFTER, or when it belongs to the job that is starting now (the queue re-ran the job after a
  # restart, or an admin retried it). Any other running run makes this attempt a skip.
  def self.start!(collectible_type, trigger:, job_id: nil)
    transaction do
      runs = for_type(collectible_type)
      left_behind = runs.stalled
      left_behind = left_behind.or(runs.running.where(job_id:)) if job_id.present?
      left_behind.find_each { |run| run.finish!(:failed, message: INTERRUPTED) }

      already_running = runs.running.exists?
      now = Time.current
      run = create!(collectible_type:, trigger:, job_id:, status: :running, started_at: now, heartbeat_at: now)
      run.finish!(:skipped, message: ALREADY_RUNNING) if already_running
      run
    end
  end

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

  # The status as the catalog page and `catalog:status` word it. A stalled run is interrupted unless its job is still
  # claimed by a worker (job_claimed), which only the queue knows (spec 015 AC-3.2, AC-3.5, AC-3.6).
  def status_label(job_claimed: false)
    return status unless stalled?

    job_claimed ? "running (no progress for #{stalled_minutes} minutes)" : INTERRUPTED
  end

  def status_line(job_claimed: false)
    [ started_at.utc.iso8601, finished_at&.utc&.iso8601 || "-", status_label(job_claimed:), trigger, source_version || "-",
      counts.map { |name, value| "#{name}=#{value}" }.join(" "), message ].compact.join("  ")
  end

  private
    def count_columns(counts) = counts.transform_keys { |name| :"#{name}_count" }
end
