# The figures of the deck shape panel for Magic (spec 069, #256): what a deck's Commander and Main zones hold, counted by
# type, by mana value and by coloured mana symbol, owned copies and proxies together and the curve and types keeping them
# apart. A plain object built once per request from `Deck::Page#zones`; it reads the rows' loaded printings and runs one
# statement of its own (the cards' mana values, none when no card counts). It is the code of the spec's
# decisions 2 to 10 (the rules themselves are in the area doc).
#
# Known limit (spec 069 Non-Goals, decision 7): a card is read through its first face, as the zone tables read it, so the second half of a
# split card adds no symbol to the bar, though its mana value (Scryfall's, both halves added) is in the curve. That is deliberate.
# @see file:collection-and-lots.md
class MTG::DeckShape
  # The zone keys that count (decision 2); the order shown is the deck's zone order.
  COUNTED_ZONES = %w[commander main].freeze
  # One kind of card: its group's name, how many cards (owned plus proxy) and how many of them are proxies.
  Type = Data.define(:name, :count, :proxy)

  attr_reader :rows

  # The figures of a deck page's counted zones (decision 2), or nil when the deck has neither a Commander nor a Main zone.
  #
  # @param zones [Array<Deck::Page::Zone>] `Deck::Page#zones`
  # @return [MTG::DeckShape, nil] nil when the deck has no counted zone
  def self.build(zones)
    counted = zones.select { COUNTED_ZONES.include?(it.location.zone) }
    new(counted) if counted.any?
  end

  # @param zones [Array<Deck::Page::Zone>] only the counted zones
  def initialize(zones)
    @names = zones.map(&:name)
    # A row with no position is another collectible's card: the page shows it flat and the panel skips it (decision 3).
    @rows = zones.flat_map { |zone| zone.groups.flat_map(&:rows) }.reject { it.answer.position.nil? }
  end

  # The cards in the counted zones, owned plus proxy.
  # @return [Integer]
  def cards = @cards ||= rows.sum(&:total)

  # The zones' names, "Main" or "Commander + Main".
  # @return [String]
  def scope_names = @names.join(" + ")

  # "Main · 60 cards".
  # @return [String]
  def scope = "#{scope_names} · #{counted(cards, 'card')}"

  # The kinds of card present, in the order of `MTG::DeckGroups::NAMES`; the counts add up to {#cards}.
  # @return [Array<Type>]
  def types
    @types ||= rows.group_by { it.answer.position }.sort.map do |position, in_group|
      Type.new(name: MTG::DeckGroups.group_name(position), count: in_group.sum(&:total), proxy: in_group.sum(&:proxy))
    end
  end

  private
    def delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number)

    def counted(number, word) = "#{delimited(number)} #{number == 1 ? word : word.pluralize}"
end
