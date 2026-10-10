# The art index build as the admin catalog page shows it (spec 015 Story 4): MTG's one extra operation, offered through
# the source's .operations hook. Its state agrees with the art line of `catalog:status` (MTG::Art.status_line).
class MTG::Art::Operation < Catalog::Operation
  OFF = "Art matching is off. Set #{MTG::Art::ENV_NAME}=true to turn it on.".freeze
  NEEDS_CATALOG = "Refresh the catalog first: the art index is built from its cards.".freeze

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

  def build
    return @build if defined?(@build)

    @build = MTG::ArtBuild.latest
  end

  # :off, :queued, :building, :interrupted, :never, :ready or :failed.
  def state
    @state ||=
      if !MTG::Art.enabled? then :off
      elsif build&.running? then build.stale? ? :interrupted : :building
      elsif queue.any? then :queued
      elsif build.nil? then :never
      else build.finished? ? :ready : :failed
      end
  end

  def record_running? = state == :building

  def failed_job? = state == :failed && super

  def summary
    case state
    when :off then OFF
    when :queued then "Queued."
    when :building then "Building."
    when :interrupted then "Interrupted. Build it again to carry on from where it stopped."
    when :never then catalog_loaded? ? "No build has run yet. One starts after the next catalog refresh, or you can start it here." : NEEDS_CATALOG
    when :ready then "Ready."
    when :failed then "Failed: #{build.message}"
    end
  end

  def meter
    return unless %i[building interrupted].include?(state)

    Meter.new(label: "Artworks fingerprinted", done: build.fingerprinted_count, total: build.total_count,
      text: "#{delimited(build.fingerprinted_count)} of #{delimited(build.total_count)} artworks fingerprinted")
  end

  def facts
    case state
    when :building, :interrupted
      [ fact("Started", build.started_at), fact("Images fetched", build.fetched_count), fact("Failed images", build.failed_count),
        fact("Last heartbeat", build.heartbeat_at, relative: true) ]
    when :ready
      [ fact("Finished", build.finished_at), fact("Artworks indexed", build.indexed_count),
        fact("Without an image", build.without_image_count), fact("Failed images", build.failed_count) ]
    when :failed
      [ fact("Finished", build.finished_at), fact("Index in use", MTG::Art::Index.current&.basename&.to_s || "none") ]
    else []
    end
  end

  private
    def catalog_loaded?
      return @catalog_loaded if defined?(@catalog_loaded)

      @catalog_loaded = Catalog::RefreshRun.for_type(collectible_type).applied.exists?
    end

    def delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number)
end
