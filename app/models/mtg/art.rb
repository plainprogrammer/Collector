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

  # Spec 011 AC-3.1: one build after an applied refresh, or after one skipped as already applied while that catalog
  # version has no index at the current settings. Nothing with art matching off. Called by the MTG source's hook.
  def self.after_refresh(run)
    return unless enabled?
    return unless run.applied? || (run.skipped? && !MTG::Art::Index.built_for?(run.source_version))

    MTG::Art::BuildJob.perform_later
  end

  # The art line `catalog:status[mtg]` prints (AC-3.11), from the latest build run that wasn't skipped.
  def self.status_line
    return "Art matching: off (set #{ENV_NAME}=true to turn it on)" unless enabled?

    run = MTG::ArtBuild.latest
    return "Art matching: on; no build has run yet (it starts after the next catalog refresh)" unless run

    progress = "#{run.fetched_count} images fetched, #{run.fingerprinted_count} of #{run.total_count} artworks fingerprinted"
    if run.running? && run.stale?
      "Art matching: interrupted (last heartbeat #{run.heartbeat_at.utc.iso8601}) after #{progress}. " \
        'Run bin/rails "catalog:refresh[mtg]" to resume.'
    elsif run.running?
      "Art matching: building since #{run.started_at.utc.iso8601}; #{progress}, #{run.failed_count} failed " \
        "(last heartbeat #{run.heartbeat_at.utc.iso8601})"
    elsif run.finished?
      "Art matching: ready; #{run.indexed_count} artworks indexed, #{run.without_image_count} without an image, " \
        "#{run.failed_count} failed images; index #{run.index_file}"
    else
      "Art matching: failed at #{run.finished_at&.utc&.iso8601}: #{run.message}; index in use: #{MTG::Art::Index.current&.basename || "none"}"
    end
  end
end
