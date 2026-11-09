# Art matching (spec 011): the instance's opt-in setting and where its global files live. Off unless
# COLLECTOR_MTG_ART_MATCHING is 1, true, yes or on (AC-1.2); every art behaviour asks .enabled? (FR-1).
module MTG::Art
  ENV_NAME = "COLLECTOR_MTG_ART_MATCHING"
  TRUE_VALUES = %w[1 true yes on].freeze

  def self.enabled_in?(env) = TRUE_VALUES.include?(env.fetch(ENV_NAME, "").to_s.strip.downcase)

  # Parsed once at boot into the app's configuration (config/initializers/art_matching.rb); tests set the configuration.
  def self.enabled? = Rails.configuration.x.mtg_art_matching == true

  # Global catalog files on the persistent volume: storage/catalog/mtg/art (tmp/catalog/mtg/art in tests).
  def self.root = Rails.configuration.x.catalog_download_dir.join("mtg", "art")

  # Scryfall small images, one per artwork, named <illustration_id>.jpg and never fetched twice (AC-3.4, AC-3.5).
  def self.cache_dir = root.join("small")

  # What the scanner page needs for art matching (AC-5.1): the current index's name and the fingerprint settings with
  # their digest, or nil with art matching off or no index built yet.
  def self.page_config
    index = enabled? && MTG::Art::Index.current
    { name: index.basename.to_s, settings: MTG::Art::Settings.for_page } if index
  end

  # The source version of the latest applied catalog refresh, the version a build records (MTG::Art::Build#call) and the
  # one a build's catalog drift is judged against (spec 053 decision 1). Nil with none applied, or when that refresh
  # recorded no version.
  def self.latest_catalog_version = Catalog::RefreshRun.for_type(MTG::Art::Build::COLLECTIBLE_TYPE).last_applied&.source_version

  # Spec 011 AC-3.1: one build after an applied refresh, or after one skipped as already applied while that catalog
  # version has no index at the current settings. Nothing with art matching off. Called by the MTG source's hook.
  def self.after_refresh(run)
    return unless enabled?
    return unless run.applied? || (run.skipped? && !MTG::Art::Index.built_for?(run.source_version))

    MTG::Art::BuildJob.perform_later
  end

  # The art line `catalog:status[mtg]` prints (AC-3.11), from the latest build run that wasn't skipped. A build still
  # marked running reads as the admin catalog page words it (MTG::Art::Operation): building with no heartbeat while a
  # worker holds the job of a build that stopped beating (MTG::ArtBuild#stalled?), interrupted once nothing is working
  # on it (MTG::ArtBuild#left_behind?), both judged by the queue as it was read before the build. A finished build whose
  # index file isn't on the volume reads as missing, and says to press the admin page's button (spec 039 decision 3);
  # one made with other settings reads as out of date, which the scanner refuses, and one made for an older catalog
  # reads as ready with a warning (spec 053 decision 4).
  def self.status_line
    return "Art matching: off (set #{ENV_NAME}=true to turn it on)" unless enabled?

    queue = MTG::ArtBuild.job_queue.read
    run = MTG::ArtBuild.latest
    return "Art matching: on; no build has run yet (it starts after the next catalog refresh, or from the admin catalog page)" unless run

    progress = "#{run.fetched_count} images fetched, #{run.fingerprinted_count} of #{run.total_count} artworks fingerprinted"
    if run.stalled?(queue)
      "Art matching: building (no heartbeat for #{run.stalled_minutes} minutes) since #{run.started_at.utc.iso8601}; #{progress}, " \
        "#{run.failed_count} failed (last heartbeat #{run.heartbeat_at.utc.iso8601}). Restart the app if it stays that way; the build then carries on, or reads interrupted."
    elsif run.left_behind?(queue)
      "Art matching: interrupted (last heartbeat #{run.heartbeat_at.utc.iso8601}) after #{progress}. " \
        'Run bin/rails "catalog:refresh[mtg]" to resume.'
    elsif run.running?
      "Art matching: building since #{run.started_at.utc.iso8601}; #{progress}, #{run.failed_count} failed " \
        "(last heartbeat #{run.heartbeat_at.utc.iso8601})"
    elsif run.finished? && !run.index_file_present?
      "Art matching: index file missing (#{run.index_file.presence || "no file name recorded"}); press Build art index on the " \
        "admin catalog page to write it again. #{run.indexed_count} artworks indexed, #{run.without_image_count} without an image, " \
        "#{run.failed_count} failed images"
    elsif run.finished? && run.settings_drift?
      "Art matching: out of date (built with settings #{run.settings_digest}, current #{MTG::Art::Settings.digest}); the scanner " \
        "reads text only. Press Build art index on the admin catalog page to build it again. #{run.indexed_count} artworks indexed, " \
        "#{run.without_image_count} without an image, #{run.failed_count} failed images; index #{run.index_file}"
    elsif run.finished?
      ready_line(run)
    else
      "Art matching: failed at #{run.finished_at&.utc&.iso8601}: #{run.message}; index in use: #{MTG::Art::Index.current&.basename || "none"}"
    end
  end

  # The ready line, with the older-catalog warning after it (spec 053 decision 4).
  def self.ready_line(run)
    line = "Art matching: ready; #{run.indexed_count} artworks indexed, #{run.without_image_count} without an image, " \
           "#{run.failed_count} failed images; index #{run.index_file}"
    latest = latest_catalog_version
    return line unless run.catalog_drift?(latest)

    "#{line} Warning: built from catalog #{run.catalog_version}, the latest refresh is #{latest}; press Build art index on the " \
      "admin catalog page to build it again."
  end
  private_class_method :ready_line
end
