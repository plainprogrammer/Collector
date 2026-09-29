# Catalog sources, one per collectible type (see app/models/catalog/sources.rb).
Rails.application.config.to_prepare do
  Catalog.sources["mtg"] = "MTG::Scryfall::Source"
end
