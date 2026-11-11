# The collection's location filter as one canonical string: "" (all), "none" (unplaced lots), a location's id in decimal
# digits (a place or a zone) or `deck:<id>` (every zone of a deck) (spec 037 decision 1; spec 065 decision 4). Stored and
# compared as this string; never re-resolved to "all" for a stored selection or a submitted form (decision 7).
module CollectionFilter::Place
  NONE = "none".freeze
  ID = Location::ID_TEXT # at most 18 digits: a longer id would overflow SQLite's 64-bit bind (spec 037 0.2.2)
  # A whole deck: `deck:` and its location's id, at most 18 digits (spec 065 decision 4).
  DECK = /\Adeck:([1-9]\d{0,17})\z/ # the digits of Location::ID_TEXT behind the prefix: a regexp can't embed its anchors

  # The value of the "<Deck> (all zones)" option.
  #
  # @param id [Integer, String] the deck's location id
  # @return [String]
  def self.deck_value(id) = "deck:#{id}"

  # Anything that isn't "none", an id or `deck:<id>` (a non-string, "017", " 17", "17abc", "deck:") is "".
  def self.parse(raw) = raw.is_a?(String) && (raw == NONE || raw.match?(ID) || raw.match?(DECK)) ? raw : ""

  # A plain predicate on the lots' own column: another account's or a removed id matches no lot of this account's. A deck's value
  # matches the lots in its zones; the subquery is tied to the lot's own account, so another account's deck id matches nothing
  # even if it were applied to a wider relation (spec 065 AC-8.4).
  #
  # @param scope [ActiveRecord::Relation] the account's lots
  # @param place [String] a parsed value
  # @return [ActiveRecord::Relation]
  def self.apply(scope, place)
    case place
    when "" then scope
    when NONE then scope.where(location_id: nil)
    when DECK then scope.where(location_id: zones_of(place.match(DECK)[1].to_i))
    else scope.where(location_id: place.to_i)
    end
  end

  # The ids of a deck's zones, correlated to the lot's account.
  def self.zones_of(deck_id)
    Location.zones_of_decks.where(parent_id: deck_id).where(Location.arel_table[:account_id].eq(Lot.arel_table[:account_id])).select(:id)
  end
  private_class_method :zones_of
end
