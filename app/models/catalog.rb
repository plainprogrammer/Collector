# Collectible-agnostic catalog: what collectibles exist, fed by source
# adapters registered per collectible type in config/initializers/catalog.rb.
module Catalog
  mattr_accessor :sources, default: {}
  # Collecting vocabulary per collectible type (finishes, conditions); see config/initializers/catalog.rb.
  mattr_accessor :collecting, default: {}

  # Spec 023: the operator's choice to open catalog search and card pages to visitors. Off unless
  # COLLECTOR_PUBLIC_CATALOG is 1, true, yes or on (decision 1); parsed once at boot (config/initializers/public_catalog.rb).
  PUBLIC_ENV = "COLLECTOR_PUBLIC_CATALOG"
  TRUE_VALUES = %w[1 true yes on].freeze

  def self.public_in?(env) = TRUE_VALUES.include?(env.fetch(PUBLIC_ENV, "").to_s.strip.downcase)
  def self.public? = Rails.configuration.x.public_catalog == true

  def self.table_name_prefix = "catalog_"

  def self.source_class(collectible_type)
    sources.fetch(collectible_type) { raise ArgumentError, "unknown collectible type: #{collectible_type}" }.constantize
  end

  def self.source_for(collectible_type) = source_class(collectible_type).new

  def self.collecting_for(collectible_type)
    collecting.fetch(collectible_type) { raise ArgumentError, "unknown collectible type: #{collectible_type}" }.constantize
  end

  # What people call a type's catalog: the source's optional .title, or the type's own name.
  def self.title_for(collectible_type)
    source = source_class(collectible_type)
    source.respond_to?(:title) ? source.title : collectible_type.to_s.humanize
  end

  # The titles of the catalog types with no applied refresh yet (spec 015 glossary, "Loaded"), in one query.
  def self.unloaded_titles
    loaded = Catalog::RefreshRun.applied.where(collectible_type: sources.keys).distinct.pluck(:collectible_type)
    (sources.keys - loaded).sort.map { |collectible_type| title_for(collectible_type) }
  end

  def self.allowed_hosts = sources.values.flat_map { |name| name.constantize::ALLOWED_HOSTS }.uniq
end
