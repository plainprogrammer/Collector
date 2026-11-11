# Catalog sources and collecting vocabularies, one per collectible type (see app/models/catalog/sources.rb).
Rails.application.config.to_prepare do
  Catalog.sources["mtg"] = "MTG::Scryfall::Source"
  Catalog.collecting["mtg"] = "MTG::Collecting"
  Catalog::Formats.verify! # a bad format registration stops the boot, not a deck's creation (spec 062 FR-2)
end
