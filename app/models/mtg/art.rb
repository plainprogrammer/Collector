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
end
