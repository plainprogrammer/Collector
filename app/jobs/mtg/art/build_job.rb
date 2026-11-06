# Builds the art index in the background (spec 011 Story 3), queued by the catalog refresh (MTG::Art.after_refresh). Two
# builds never work at once: MTG::ArtBuild.start! guards it, keyed on the run record and this job's id, rather than a
# queue concurrency lock that a first build (hours) would outlast (AC-3.2). A missing ImageMagick fails the build run,
# which says so; retrying wouldn't help. A busy SQLite database is transient: the build has already marked its run
# failed and re-raised, and the retry keeps this job's id, so MTG::ArtBuild.start! closes that run and carries on. A
# rate limit from the image host (Catalog::Sources::RateLimitedError, issue #74) stops the build, which says so in its
# failed run; the job then runs again no sooner than the host asked (Catalog::RateLimitRetry), under the same job id, and
# the new run carries on from the images already cached. Asked to wait more than an hour, or turned away a fourth time,
# the job fails, and the build is started again from the admin pages or by the next refresh.
class MTG::Art::BuildJob < ApplicationJob
  queue_as :sync

  retry_on SQLite3::BusyException, ActiveRecord::StatementTimeout, wait: :polynomially_longer, attempts: 3
  discard_on MTG::Art::Decoder::Error
  include Catalog::RateLimitRetry

  def perform
    @build = nil # the answer below is about this attempt alone: a job instance can run perform more than once (spec 043)
    @build = MTG::Art::Build.new(job_id:)
    @build.call
  end

  private
    # Whether the attempt a rate limit just ended fetched and kept an image, or stored a batch of fingerprints
    # (Catalog::RateLimitRetry; spec 043 decision 3). False when the build couldn't even be built.
    def rate_limit_progress? = @build&.made_progress? || false
end
