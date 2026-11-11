# What a collector can choose a location from, for one account: its places, and its decks with their zones (spec 065
# decision 1). One statement reads every location of the account, so a picker, the collection filter and a message that
# names a zone cost one read between them, and each zone's `parent` is set from that read so `Location#label` costs nothing.
#
# This is for showing a choice. A write that names a location still looks it up through `Location.find_placeable!`, called on
# `Current.account.locations` (404 when it isn't one), because a request's id is untrusted. Collectible-agnostic: a deck is a
# location and a zone is its child; no format or zone key is named here.
# @see file:collection-and-lots.md
class Location::Choices
  # A deck (its location) and its zones in zone order (`Deck#zones`: by id, the format's order).
  Group = Data.define(:location, :zones)

  # @param account [Account, nil] whose locations are offered; nil offers none
  def initialize(account)
    @account = account
  end

  # The account's places, in the Locations page's order.
  #
  # @return [Array<Location>] the places, by comparison key then name
  def places = loaded.first

  # The account's decks that have a zone, each with its zones.
  #
  # @return [Array<Group>] the decks that have a zone, by comparison key then name; a deck with no zone (only an import's
  #   repair can leave one) is not offered, so no group is ever drawn empty
  def decks = loaded.last

  # Whether a picker has anything to offer: a place or a zone.
  #
  # @param except [Integer, String, nil] a place or zone that doesn't count (Move copies' own place)
  # @return [Boolean]
  def any?(except: nil)
    skip = except&.to_s
    places.any? { it.id.to_s != skip } || decks.any? { |group| group.zones.any? { it.id.to_s != skip } }
  end

  # Whether the account has a deck to group zones under.
  #
  # @return [Boolean]
  def decks? = decks.any?

  # A place or a zone of the account by id; nil for anything else, a deck's own row included.
  #
  # @param id [Integer, String, nil]
  # @return [Location, nil] with its parent set when it is a zone
  def find(id)
    key = id.to_s
    return unless key.match?(Location::ID_TEXT)

    places.find { it.id.to_s == key } || decks.flat_map(&:zones).find { it.id.to_s == key }
  end

  # A deck of the account by its location's id.
  #
  # @param id [Integer, String, nil]
  # @return [Group, nil]
  def deck(id) = decks.find { it.location.id.to_s == id.to_s }

  private
    def loaded
      @loaded ||= begin
        rows = @account ? @account.locations.ordered.order(:id).to_a : []
        zones = rows.select(&:zone?).group_by(&:parent_id)
        groups = rows.select(&:deck?).filter_map do |deck|
          in_deck = zones.fetch(deck.id, []).sort_by(&:id)
          next if in_deck.empty?

          in_deck.each { it.association(:parent).target = deck }
          Group.new(location: deck, zones: in_deck)
        end
        [ rows.select(&:place?), groups ]
      end
    end
end
