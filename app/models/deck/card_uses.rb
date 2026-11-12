# Where an account uses one card in its decks: a row per deck zone that holds a copy or a proxy of the card, summed across the
# card's printings (spec 073 decisions 4 and 6). Behind the card page's "In decks" section and the "in N decks" line of its
# stats.
#
# "In a deck" is not decided here: the caller passes the card's lots that are in deck zones (`Catalog::CardOverview#deck_lots`,
# the complement of `Lot::FreeCopies`), so `Lot.free` stays the one definition. Proxies are read here, by the card's identity,
# because they are never lots. Two statements for the proxies and the zones' decks plus one preload each for a zone's deck
# and the deck's own row, however many zones there are; none for a nil account or for a card in no deck.
#
# Takes the account explicitly and never reads `Current.account`. Collectible-agnostic.
# @see file:collection-and-lots.md
class Deck::CardUses
  # The zones' parent, the deck's location, for the order of the rows; a deck's zones have one.
  PARENT_JOIN = "INNER JOIN locations parents ON parents.id = locations.parent_id".freeze

  # One zone that holds a copy or a proxy of the card: its `deck` (a `Deck`), the `zone` (a `Location`), the copies of the card
  # in it (`owned`) and the proxies of the card in it (`proxy`), each summed across printings.
  Row = Data.define(:deck, :zone, :owned, :proxy)

  # @param account [Account, nil] whose decks are read; nil (a visitor) reads nothing
  # @param entry [Catalog::Entry] the shown printing; its identity is the card
  # @param lots [Array<Lot>] the card's lots that are in deck zones (all of them are counted in `owned`)
  def initialize(account:, entry:, lots:)
    @account, @entry, @lots = account, entry, lots
  end

  # The zones with a copy or a proxy of the card, decks by comparison key then name (the order `Deck.listing_order` uses) and a
  # deck's zones by id (the deck's own order).
  #
  # @return [Array<Row>]
  def rows = @rows ||= build_rows

  # The copies of the card in deck zones.
  #
  # @return [Integer]
  def owned = rows.sum(&:owned)

  # The proxies of the card, in every zone.
  #
  # @return [Integer]
  def proxy = rows.sum(&:proxy)

  # The decks that hold at least one owned copy of the card; a deck with only a proxy of it is not counted (a proxy is never
  # owned).
  #
  # @return [Integer]
  def deck_count = rows.select { it.owned.positive? }.map { it.deck.id }.uniq.size

  private
    def build_rows
      return [] unless @account

      owned = @lots.group_by(&:location_id).transform_values { |group| group.sum(&:quantity) }
      proxies = proxies_by_zone
      ids = owned.keys | proxies.keys
      return [] if ids.empty?

      zones = @account.locations.zones_of_decks.where(id: ids).joins(PARENT_JOIN)
        .order("parents.name_key", "parents.name", "locations.id").preload(parent: :deck)
      zones.map { |zone| Row.new(deck: zone.parent.deck, zone:, owned: owned.fetch(zone.id, 0), proxy: proxies.fetch(zone.id, 0)) }
    end

    # One statement: the account's proxies of any printing of the card, summed by zone.
    def proxies_by_zone
      Deck::Proxy.where(account_id: @account.id).joins(:entry)
        .where(catalog_entries: { catalog_identity_id: @entry.catalog_identity_id }).group(:location_id).sum(:quantity)
    end
end
