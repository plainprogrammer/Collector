# One attempt to build the art index (spec 011 AC-3.2, AC-3.11): its job, its counts, a heartbeat while it runs, and how
# it ended. A build that finds another running ends at once as skipped. A run left running by the same job (the queue
# re-ran it after a restart), or that nothing is working on any more (#left_behind?: a crash), is marked failed as
# interrupted first, so the guard never relies on the job queue's concurrency lock, which a first build can outlast.
class MTG::ArtBuild < ApplicationRecord
  STALE_AFTER = 10.minutes
  # A build whose job the queue has failed, or no longer holds, is taken as left behind only once its heartbeat is this
  # old (issue #73), the rule and the length a refresh run has (Catalog::RefreshRun::JOB_ENDED_GRACE). The queue also
  # fails the job of a worker it lost sight of while that worker lives (a suspended host, a paused container), and such
  # a build goes on beating. The length is this build's own, set by how often it beats: after every batch of 50
  # artworks and, within a batch, between images once 30 seconds have passed (MTG::Art::Build::BEAT_EVERY). So a
  # working build is quiet this long only when one image by itself takes more than 90 seconds: its requests (at most
  # 3, each with a 10-second open and a 60-second read timeout; one that times out isn't retried), the waits between
  # them, and its decoding (spec 015, Error Scenarios). Those waits are bounded (issue #74): what a Retry-After asks
  # for, 30 seconds each and 60 in all for one image (MTG::Scryfall::Client::MAX_BACK_OFF), and a longer one asked
  # for stops the build instead. Without a Retry-After they are shorter still (issue #81): 1 and then 2 seconds after
  # a server error, and none after a 429, which stops the build at once. So the waits alone leave at most
  # 30 + 60 = 90 seconds between heartbeats, inside the grace; it takes slow requests or a slow decode on top of them
  # to pass it.
  JOB_ENDED_GRACE = 2.minutes
  COUNTS = %i[total without_image fetched fingerprinted failed indexed].freeze

  enum :status, { running: "running", finished: "finished", failed: "failed", skipped: "skipped" }, validate: true

  validates :started_at, :heartbeat_at, presence: true

  scope :recent, -> { order(started_at: :desc, id: :desc) }

  # The build jobs as the queue holds them, to judge running builds by (#left_behind?). Read it before the builds: a
  # job's row is finished only after its build is closed, so a build still marked running whose job that reading no
  # longer held was left behind, not finished between the two reads.
  def self.job_queue = Catalog::Operation::Queue.new(MTG::Art::BuildJob)

  def self.start!(job_id:, catalog_version:, settings_digest:)
    queue = job_queue.read
    transaction do
      running.find_each { |run| run.finish!(:failed, message: "interrupted") if run.job_id == job_id || run.left_behind?(queue) }
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

  # Still marked running with nothing working on it: the heartbeat is older than STALE_AFTER, or it is older than
  # JOB_ENDED_GRACE and the build's own job ended without closing it (its worker died). The art index's panel, the art
  # line of `catalog:status` and .start! all judge a running build by this, with the queue (.job_queue) read before it.
  def left_behind?(queue) = stale? || (quiet? && job_ended?(queue))

  def counts = COUNTS.index_with { |name| public_send(:"#{name}_count") }

  private
    def quiet? = running? && heartbeat_at < JOB_ENDED_GRACE.ago

    # The queue has failed the build's job, or holds no unfinished job with its id any more (the failed job was
    # discarded, or it never was in the queue: MTG::Art::BuildJob.perform_now in a console). A reading of the queue says
    # nothing about a build that started after it: its job was queued since.
    def job_ended?(queue)
      job_id.present? && (queue.failed?(job_id) || (started_at <= queue.read_at && queue.gone?(job_id)))
    end

    def count_columns(counts) = counts.transform_keys { |name| :"#{name}_count" }
end
