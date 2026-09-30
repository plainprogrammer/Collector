# Catalog sources and collecting vocabularies, one per collectible type (see app/models/catalog/sources.rb).
Rails.application.config.to_prepare do
  Catalog.sources["mtg"] = "MTG::Scryfall::Source"
  Catalog.collecting["mtg"] = "MTG::Collecting"
end
