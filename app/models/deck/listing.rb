# The Decks page's rows (spec 062 FR-4): an account's decks in comparison-key order, each with the copies in all its zones,
# in a bounded number of statements however many decks there are (one for the decks and their locations, one for the
# copies grouped by deck). Needs the account, not `Current.account`.
class Deck::Listing
  # One row of the page: the deck (its location loaded) and the copies in all its zones, Considering included.
  Row = Data.define(:deck, :cards)

  # @param account [Account] whose decks are listed
  def initialize(account)
    @account = account
  end

  # The page's rows, read once per listing so the page and its count agree. The copies are summed per deck in one grouped
  # statement and the decks' locations preloaded, so the cost doesn't grow with the number of decks.
  # @return [Array<Row>] the decks by comparison key, then name; a deck with no copies has 0
  def rows
    @rows ||= begin
      cards = @account.lots.joins(:location).where(locations: { kind: "deck_zone" }).group("locations.parent_id").sum(:quantity)
      @account.decks.listing_order.preload(:location).map { |deck| Row.new(deck:, cards: cards.fetch(deck.location_id, 0)) }
    end
  end

  # How many decks the account has, from the rows already read, for the page's heading and empty state.
  # @return [Integer] how many decks the account has
  def count = rows.size
end
