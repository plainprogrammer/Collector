# Price sources, one per source key (see app/models/prices/sources.rb); each names the collectible type its prices are for.
Rails.application.config.to_prepare do
  Prices.sources["scryfall"] = "MTG::Scryfall::PriceQuotes"
end
