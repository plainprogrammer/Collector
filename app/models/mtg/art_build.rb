# One attempt to build the art index (spec 011 AC-3.2, AC-3.11): its job, its counts, a heartbeat while it runs, and how
# it ended. A build that finds another running ends at once as skipped. A run left running by the same job (the queue
# re-ran it after a restart), or whose heartbeat is older than STALE_AFTER (a crash), is marked failed as interrupted
# first, so the guard never relies on the job queue's concurrency lock, which a first build can outlast.
class MTG::ArtBuild < ApplicationRecord
  STALE_AFTER = 10.minutes
  COUNTS = %i[total without_image fetched fingerprinted failed indexed].freeze

  enum :status, { running: "running", finished: "finished", failed: "failed", skipped: "skipped" }, validate: true

  validates :started_at, :heartbeat_at, presence: true

  scope :recent, -> { order(started_at: :desc, id: :desc) }

  def self.start!(job_id:, catalog_version:, settings_digest:)
    transaction do
      running.where(job_id:).or(running.where(heartbeat_at: ..STALE_AFTER.ago))
        .find_each { |run| run.finish!(:failed, message: "interrupted") }
      live = running.exists?
      now = Time.current
      run = create!(status: :running, job_id:, catalog_version:, settings_digest:, started_at: now, heartbeat_at: now)
      run.finish!(:skipped, message: "already running") if live
      run
    end
  end

  def self.latest = where.not(status: :skipped).recent.first

  def beat!(**counts) = update!(heartbeat_at: Time.current, **count_columns(counts))

  def finish!(status, message: nil, **counts)
    update!(status:, message:, finished_at: Time.current, **count_columns(counts))
    Rails.logger.info(ActiveSupport::JSON.encode(event: "mtg.art_build.finished", status:, catalog_version:, message:, **self.counts))
  end

  def stale? = running? && heartbeat_at < STALE_AFTER.ago

  def counts = COUNTS.index_with { |name| public_send(:"#{name}_count") }

  private
    def count_columns(counts) = counts.transform_keys { |name| :"#{name}_count" }
end
