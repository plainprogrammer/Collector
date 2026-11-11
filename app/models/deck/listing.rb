# The Decks page's rows (spec 062 FR-4, spec 068 FR-2): an account's decks in comparison-key order, each with the copies in all
# its zones and the proxies in them, in a bounded number of statements however many decks there are (one for the decks and
# their locations, one grouped read of the copies and one of the proxies). Needs the account, not `Current.account`.
class Deck::Listing
  # One row of the page: the deck (its location loaded), the copies owned in all its zones and the proxies in them,
  # Considering included.
  Row = Data.define(:deck, :owned, :proxy) do
    # The deck's cards: owned plus proxy (spec 060 decision 12).
    def cards = owned + proxy
  end

  # @param account [Account] whose decks are listed
  def initialize(account)
    @account = account
  end

  # The page's rows, read once per listing so the page and its count agree. The copies and the proxies are each summed per deck
  # in one grouped statement and the decks' locations preloaded, so the cost doesn't grow with the number of decks.
  # @return [Array<Row>] the decks by comparison key, then name; a deck with no copies and no proxies has 0 of each
  def rows
    @rows ||= begin
      owned = @account.lots.joins(:location).where(locations: { kind: "deck_zone" }).group("locations.parent_id").sum(:quantity)
      proxies = @account.deck_proxies.joins(:zone).group("locations.parent_id").sum(:quantity)
      @account.decks.listing_order.preload(:location).map do |deck|
        Row.new(deck:, owned: owned.fetch(deck.location_id, 0), proxy: proxies.fetch(deck.location_id, 0))
      end
    end
  end

  # How many decks the account has, from the rows already read, for the page's heading and empty state.
  # @return [Integer] how many decks the account has
  def count = rows.size
end
