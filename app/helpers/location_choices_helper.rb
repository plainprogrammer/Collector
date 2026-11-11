# The options of a location select (spec 065 decision 2): every picker and the collection filter render one, so they cannot
# disagree. Native `optgroup`s, no script.
module LocationChoicesHelper
  # The options of a location select.
  #
  # With no deck in the account the select is flat (the leading options, then the places). With a deck it is the leading
  # options, an `optgroup` "Places" and an `optgroup` "Decks" whose options read "Deck › Zone"; a group with nothing in it is
  # omitted. Values are location ids as text.
  #
  # @param choices [Location::Choices]
  # @param selected [String, nil] the value to mark selected
  # @param leading [Array<Array(String, String)>] options outside any group, such as `[["No location", ""]]`
  # @param except [Integer, String, nil] the place or zone to leave out (the one a move starts from)
  # @param deck_values [Boolean] the filter's form: each deck's group starts with "<Deck> (all zones)", valued
  #   `CollectionFilter::Place.deck_value`
  # @return [ActiveSupport::SafeBuffer] `option` and `optgroup` tags
  def location_options(choices, selected: nil, leading: [], except: nil, deck_values: false)
    skip = except&.to_s
    places = choices.places.reject { it.id.to_s == skip }.map { [ it.name, it.id.to_s ] }
    base = options_for_select(leading, selected)
    return base + options_for_select(places, selected) unless choices.decks?

    decks = choices.decks.flat_map do |group|
      zones = group.zones.reject { it.id.to_s == skip }.map { [ it.label, it.id.to_s ] }
      next [] if zones.empty?

      deck_values ? [ [ "#{group.location.name} (all zones)", CollectionFilter::Place.deck_value(group.location.id) ], *zones ] : zones
    end
    groups = []
    groups << [ "Places", places ] if places.any?
    groups << [ "Decks", decks ] if decks.any?
    base + grouped_options_for_select(groups, selected)
  end
end
