# One run of the daily price refresh, in the prices database (spec 089 decision 2): its identity (source, the file's
# day, version and languages), its times, its status and the counts of what it did to rows. The run is also the guard
# against overlap and against a run left behind (decision 7). Measurements of cost are #366's.
#
# `run_on` is nil until the file's date is known; `error` holds why a run failed or was skipped.
#
# @see file:prices.md
class PriceRefreshRun < PricesRecord
  # What a run counts (spec 089 decision 2); the columns have these names and default to 0.
  COUNTS = %i[quotes_seen unchanged repriced added removed removals_withheld unknown_printings malformed].freeze
  # A running run with no progress for this long is left behind. The catalog refresh's own threshold (spec 089 decision 7).
  STALL_AFTER = 15.minutes
  # The most often the run row is touched while a download reports progress, so a long download never reads as stalled.
  HEARTBEAT_EVERY = 30.seconds

  belongs_to :price_source

  scope :running, -> { where(status: "running") }
  scope :finished, -> { where(status: "finished") }

  # Opens a run for the source, or records that none could be opened. In one transaction it closes each running run that
  # was left behind (`#left_behind?`) as `failed` with `interrupted`; then, if a run still runs, it records the new run
  # as `skipped` with `already running` (nothing else is touched), otherwise as `running`.
  #
  # @param source [PriceSource]
  # @param job_id [String, nil] the starting job's Active Job id
  # @param now [Time]
  # @return [PriceRefreshRun] `running`, or `skipped` when another run is working
  def self.start!(source, job_id:, now: Time.current)
    transaction do
      running.where(price_source: source).select { it.left_behind?(job_id:, now:) }
        .each { it.update!(status: "failed", error: "interrupted", finished_at: now) }
      if running.exists?(price_source_id: source.id)
        create!(price_source: source, status: "skipped", error: "already running", job_id:, started_at: now, finished_at: now)
      else
        create!(price_source: source, status: "running", job_id:, started_at: now)
      end
    end
  end

  # The finished runs of a source for one file and language set: what "applied" means (spec 089 decision 5).
  #
  # @return [ActiveRecord::Relation<PriceRefreshRun>]
  def self.applied(source, version, languages) = finished.where(price_source: source, source_version: version, languages:)

  # The latest day a finished or failed run of the source read a file for (a failed run may have written rows); skipped
  # and running runs don't count (spec 089 decision 3).
  #
  # @return [Date, nil]
  def self.latest_run_on(source) = where(price_source: source, status: %w[finished failed]).maximum(:run_on)

  # Whether nothing works on this running run any more: its last progress is older than STALL_AFTER, or it carries the
  # starting job's own id (the queue re-ran it after a restart).
  #
  # @return [Boolean]
  def left_behind?(job_id:, now: Time.current) = updated_at < now - STALL_AFTER || (job_id.present? && self.job_id == job_id)

  # Whether the run is still open (not finished, skipped or failed).
  #
  # @return [Boolean]
  def running? = status == "running"

  # Records the file this run is for.
  #
  # @param version [String] the catalog source's version (the file's name without its extension)
  # @param languages [String] the sorted language set, comma-joined
  # @return [true]
  def record_file!(version:, languages:) = update!(source_version: version, languages:)

  # Ends the run as skipped, with the reason in `error`; `run_on` when it is known.
  #
  # @param reason [String]
  # @param run_on [Date, nil]
  # @return [true]
  def skip!(reason, run_on: nil) = update!(status: "skipped", error: reason, run_on: run_on || self.run_on, finished_at: Time.current)

  # Ends the run as finished with its counts (keys outside COUNTS are ignored).
  #
  # @param counts [Hash{Symbol => Integer}]
  # @return [true]
  def finish!(counts) = update!(status: "finished", finished_at: Time.current, **counted(counts))

  # Ends the run as failed with `"<class>: <message>"` and the counts so far.
  #
  # @param error [StandardError]
  # @param counts [Hash{Symbol => Integer}]
  # @return [true]
  def fail!(error, counts) = update!(status: "failed", error: "#{error.class}: #{error.message}", finished_at: Time.current, **counted(counts))

  # Stores the counts so far and counts as progress (the stall rule reads `updated_at`). Written outside any batch's
  # transaction.
  #
  # @param counts [Hash{Symbol => Integer}]
  # @return [true]
  def progress!(counts) = update!(**counted(counts), updated_at: Time.current)

  # A progress callback for a download (called with bytes done and total): touches the run at most once per
  # HEARTBEAT_EVERY.
  def heartbeat(*)
    now = Time.current
    return if @last_beat && now - @last_beat < HEARTBEAT_EVERY

    @last_beat = now
    touch
  end

  private
    def counted(counts) = counts.slice(*COUNTS)
end
