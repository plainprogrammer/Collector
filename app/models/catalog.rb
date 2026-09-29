# Collectible-agnostic catalog: what collectibles exist, fed by source
# adapters registered per collectible type in config/initializers/catalog.rb.
module Catalog
  mattr_accessor :sources, default: {}

  def self.table_name_prefix = "catalog_"

  def self.source_class(collectible_type)
    sources.fetch(collectible_type) { raise ArgumentError, "unknown collectible type: #{collectible_type}" }.constantize
  end

  def self.source_for(collectible_type) = source_class(collectible_type).new

  def self.allowed_hosts = sources.values.flat_map { |name| name.constantize::ALLOWED_HOSTS }.uniq
end
