# Helpers for specs that need copies in a deck's zones (spec 062).
module DeckHelpers
  # A lot of +entry+ (a new Magic printing unless given) in the zone +zone_key+ of +deck+, merged as the collection merges it.
  def create_lot_in_zone(deck, zone_key, entry: create(:mtg_printing).entry, **attrs)
    Lot.add!(account: deck.account, entry:, location: deck.zone(zone_key), **attrs)
  end
end

RSpec.configure do |config|
  %i[model request system].each { |type| config.include DeckHelpers, type: }
end
