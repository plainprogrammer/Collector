# Collectible-agnostic catalog: what collectibles exist, fed by source
# adapters registered per collectible type in config/initializers/catalog.rb.
module Catalog
  def self.table_name_prefix = "catalog_"
end
