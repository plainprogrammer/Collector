# The art index build as the admin catalog page shows it (spec 015 Story 4): MTG's one extra operation, offered through
# the source's .operations hook. It judges a running build as the art line of `catalog:status` does (MTG::Art.status_line,
# both by MTG::ArtBuild#stalled? and #left_behind?). The two differ only while the queue holds a build job that no
# running build is being worked on by: one that waits, or one a worker has taken that hasn't opened its build yet. The
# page then says "Queued." or "Queued to retry.", and the status line still describes the latest build (interrupted,
# ready or failed), or says that no build has run yet.
class MTG::Art::Operation < Catalog::Operation
  OFF = "Art matching is off. Set #{MTG::Art::ENV_NAME}=true to turn it on.".freeze
  NEEDS_CATALOG = "Refresh the catalog first: the art index is built from its cards.".freeze
  # A restart that stops the worker in good order releases the job it holds: the queue runs it again, and it closes its
  # own build and carries on. After a crash or a kill the job stays held until the queue notices its worker is gone
  # (some minutes) and fails it; the build is then interrupted, and nothing carries on until it is built again.
  STALLED_ADVICE = "If it stays that way, restart the app. The build then carries on from where it stopped, or reads " \
                   "interrupted and can be built again.".freeze

  def key = "art_index"
  def title = "Art index"
  def queued_notice = "Art index build queued."
  def in_flight_notice = "An art index build is already queued or running."
  def job_class = MTG::Art::BuildJob

  # No button at all with art matching off (AC-4.6).
  def start_label = ("Build art index" if MTG::Art.enabled?)

  def unavailable_reason
    return OFF unless MTG::Art.enabled?

    NEEDS_CATALOG unless catalog_loaded?
  end

  # Read after the queue, which judges it (MTG::ArtBuild.job_queue says why).
  def build
    return @build if defined?(@build)

    queue.read
    @build = MTG::ArtBuild.latest
  end

  # :off, :queued, :building, :stalled, :interrupted, :never, :ready or :failed. A build still marked running that
  # nothing is working on any more is interrupted: its heartbeat stopped 10 minutes ago, or 2 minutes ago and the queue
  # has failed its job or no longer holds it (issue #73). One whose heartbeat stopped 10 minutes ago while a worker
  # still holds its job is stalled instead (issue #79).
  def state
    @state ||=
      if !MTG::Art.enabled? then :off
      elsif build&.running? then running_state
      elsif queue.any? then :queued
      elsif build.nil? then :never
      else build.finished? ? :ready : :failed
      end
  end

  def record_running? = %i[building stalled].include?(state)

  # The page links to the failed list for the build on show: a failed one, or an interrupted one whose own job is there.
  def failed_job? = (state == :failed && super) || (state == :interrupted && build.job_id.present? && queue.failed?(build.job_id))

  def summary
    case state
    when :off then OFF
    when :queued then retrying? ? "Queued to retry. The last build #{failed_summary.downcase_first}" : "Queued."
    when :building then "Building."
    when :stalled then "Building, no heartbeat for #{build.stalled_minutes} minutes. #{STALLED_ADVICE}"
    when :interrupted then "Interrupted. Build it again to carry on from where it stopped."
    when :never then catalog_loaded? ? "No build has run yet. One starts after the next catalog refresh, or you can start it here." : NEEDS_CATALOG
    when :ready then "Ready."
    when :failed then failed_summary
    end
  end

  def meter
    return unless %i[building stalled interrupted].include?(state)

    Meter.new(label: "Artworks fingerprinted", done: build.fingerprinted_count, total: build.total_count,
      text: "#{delimited(build.fingerprinted_count)} of #{delimited(build.total_count)} artworks fingerprinted")
  end

  # While a job of its waits for a later time, when that is due comes first, as on the refresh (issue #80): the failed
  # build's own job when that is the one retrying, so the reason and the time are one job's, else the earliest.
  def facts
    case state
    when :queued
      retrying? ? [ fact("Retrying at", queue.retry_at(build.job_id)), *failed_facts ] : [ (fact("Retrying at", queue.retry_at) if queue.retry_at) ].compact
    when :building, :stalled, :interrupted
      [ fact("Started", build.started_at), fact("Images fetched", build.fetched_count), fact("Failed images", build.failed_count),
        fact("Last heartbeat", build.heartbeat_at, relative: true) ]
    when :ready
      [ fact("Finished", build.finished_at), fact("Artworks indexed", build.indexed_count),
        fact("Without an image", build.without_image_count), fact("Failed images", build.failed_count) ]
    when :failed then failed_facts
    else []
    end
  end

  private
    # A build nothing is working on any more is interrupted, until a build job waits to start: that one is queued, and
    # closes the build when it starts (spec 015 AC-4.3), as a refresh queued behind an interrupted run is. A worker
    # that still holds the job of a build whose heartbeat stopped keeps the button disabled, whatever else waits in the
    # queue: that build is stalled, as a refresh run is (spec 015 AC-4.11), and the page goes on polling.
    def running_state
      return :stalled if build.stalled?(queue)
      return :building unless build.left_behind?(queue)

      queue.any? ? :queued : :interrupted
    end

    # A failed build whose own job waits to run again: turned away by the image host (Catalog::RateLimitRetry), or by
    # a busy database (MTG::Art::BuildJob's retry_on). The retry keeps the job's id, which is how a build queued fresh
    # behind another job's failure is told apart: that one is plain "Queued.".
    def retrying?
      state == :queued && build&.failed? && build.job_id.present? && queue.retry_at(build.job_id).present?
    end

    def failed_summary = "Failed: #{build.message}"

    def failed_facts
      [ fact("Finished", build.finished_at), fact("Index in use", MTG::Art::Index.current&.basename&.to_s || "none") ]
    end

    def catalog_loaded?
      return @catalog_loaded if defined?(@catalog_loaded)

      @catalog_loaded = Catalog::RefreshRun.for_type(collectible_type).applied.exists?
    end

    def delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number)
end
