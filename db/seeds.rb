# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create default MTGJSON catalog
catalog = Catalog.find_or_create_by!(name: "MTGJSON Catalog") do |c|
  c.source_type = "mtgjson"
  c.source_config = {
    version: nil,
    last_updated: nil
  }
end

puts "✓ Created default catalog: #{catalog.name}"

# Create default MTG collection
collection = Collection.find_or_create_by!(name: "My Collection") do |c|
  c.catalog = catalog
  c.item_type = "mtg_card"
  c.description = "Default Magic: The Gathering collection"
end

puts "✓ Created default collection: #{collection.name}"
