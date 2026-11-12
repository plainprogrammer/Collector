# The figures of the deck shape panel for Magic (spec 069, #256): what a deck's Commander and Main zones hold, counted by
# type, by mana value and by coloured mana symbol, owned copies and proxies together and the curve and types keeping them
# apart. A plain object built once per request from `Deck::Page#zones`; it reads the rows' loaded printings and runs one
# statement of its own (the cards' mana values, none when no card counts). It is the code of the spec's
# decisions 2 to 10 and 14 (the rules themselves are in the area doc).
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

  # One column of the curve: nonland cards of one mana value bucket, owned and proxy apart.
  Column = Data.define(:owned, :proxy) do
    # Owned plus proxy: the count above the column.
    def total = owned + proxy
  end
  # The curve's last column holds this mana value and above (decision 4).
  TOP_COLUMN = 6

  # The seven columns, mana value 0 to 6+, counting nonland cards with a mana value (decision 4): column n holds values from n
  # up to but not including n + 1, and the last holds every value from 6.
  # @return [Array<Column>]
  def curve
    @curve ||= begin
      owned = Array.new(TOP_COLUMN + 1, 0)
      proxy = Array.new(TOP_COLUMN + 1, 0)
      valued.each do |row, value|
        column = [ value.floor, TOP_COLUMN ].min
        owned[column] += row.owned
        proxy[column] += row.proxy
      end
      owned.zip(proxy).map { |o, p| Column.new(owned: o, proxy: p) }
    end
  end

  # The owned cards in the curve (the legend's "Owned N").
  # @return [Integer]
  def curve_owned = curve.sum(&:owned)

  # The proxy cards in the curve (the legend's "Proxy N").
  # @return [Integer]
  def curve_proxy = curve.sum(&:proxy)

  # The tallest column's owned plus proxy, the custom property `--max` of every bar; 0 when the curve is empty.
  # @return [Integer]
  def curve_max = curve.map(&:total).max

  # The cards in the curve.
  # @return [Integer]
  def curve_cards = curve_owned + curve_proxy

  # The exact mean mana value of the cards in the curve, shown to one decimal, rounded half up (decision 5). The arithmetic is
  # exact (Rational), so 0.15 shows 0.2 where a float would give 0.1.
  # @return [String, nil] nil when no card is in the curve
  def average_text
    return @average_text if defined?(@average_text)

    @average_text = unless curve_cards.zero?
      mean = valued.sum { |row, value| value.to_r * row.total } / curve_cards
      delimited(format("%.1f", mean.round(1).to_f))
    end
  end

  # The nonland cards with no mana value (decision 6): a catalog not refreshed since spec 058, or a card Scryfall gave none.
  # @return [Integer]
  def unvalued = @unvalued ||= nonland.sum { |row| mana_values[row.entry.catalog_identity_id] ? 0 : row.total }

  # The sentence under the curve, or nil when every nonland card has a mana value.
  # @return [String, nil]
  def unvalued_note
    return if unvalued.zero?

    "#{counted(unvalued, 'nonland card')} #{unvalued == 1 ? 'has' : 'have'} no mana value yet."
  end

  # One coloured segment of the mana bar: the colour's letter, its symbol count, its share rounded half up to a percent and whether the
  # segment is too narrow for its label (under 10% of the symbols, decision 9).
  Segment = Data.define(:colour, :count, :percent, :narrow)
  # The five colours in the order the bar draws them, with the words the caption and label use.
  COLOURS = { "W" => "white", "U" => "blue", "B" => "black", "R" => "red", "G" => "green" }.freeze

  # Counts below this are written in full; from it a count in a slot of fixed width takes a unit, and each unit is this many of the one
  # before (spec 077 decision 5). The abbreviation is uniform, not width-driven: the server cannot know the width, and a count that
  # fits at a 360px viewport still overflows at 320px.
  SHORT_COUNT_STEP = 1_000
  # The units of an abbreviated count: thousands, millions, billions.
  SHORT_COUNT_UNITS = %w[k m b].freeze

  # The segments of the mana bar for the colours that have a symbol (decision 8), in W, U, B, R, G order.
  # @return [Array<Segment>]
  def symbols
    @symbols ||= begin
      total = symbol_counts.values.sum
      COLOURS.keys.filter_map do |colour|
        count = symbol_counts[colour]
        next unless count.positive?

        Segment.new(colour:, count:, percent: Rational(count * 100, total).round, narrow: count * 100 < total * 10)
      end
    end
  end

  # "White 2 · 25% · Blue 4 · 50%": every colour present with its count and percentage, exact (the abbreviation is for a slot of
  # fixed width and this is prose). Built from {#caption_items}.
  # @return [String, nil] nil when there is no coloured symbol
  def caption = caption_items.join(" ").presence

  # The caption as one string per colour, "White 2 · 25% ·" and, last, "Blue 4 · 50%": every item but the last ends in the separator, so a
  # view that sets each item as an unbreakable unit lets a line break only between items and never before a "·" (spec 077 decision 4,
  # #320). Joined with one space they are {#caption}, character for character.
  # @return [Array<String>] empty when there is no coloured symbol
  def caption_items
    items = symbols.map { |s| "#{COLOURS[s.colour].capitalize} #{delimited(s.count)} · #{s.percent}%" }
    items.each_with_index.map { |item, index| index == items.size - 1 ? item : "#{item} ·" }
  end

  # A count written for a slot of fixed width, the curve's column count and a mana segment's label (spec 077 decisions 1, 2 and 5, #320).
  # Below 1,000 it is the number as it is. From there it takes a unit: one decimal under 10 of the unit with a trailing ".0" dropped
  # ("1.4k", "2k"), whole from 10 ("12k", "123k"), rounded half up on exact integers (1,350 is "1.4k", 1,349 "1.3k"). A value that
  # rounds to 1,000 of its unit moves to the next unit (999,500 is "1m"), and one that rounds to 10.0 is written whole (9,999 is "10k"),
  # so nothing is longer than four characters through "999m". It is not `number_to_human`, which keeps two significant digits (123,456
  # would read "120k"). The exact number stays in every `aria-label`, the legend, the caption and the types.
  #
  # @example
  #   short_count(999)     # => "999"
  #   short_count(1_357)   # => "1.4k"
  #   short_count(9_999)   # => "10k"
  #   short_count(999_500) # => "1m"
  # @param number [Integer] a count, 0 or more
  # @return [String]
  def short_count(number)
    return delimited(number) if number < SHORT_COUNT_STEP

    value = Rational(number, SHORT_COUNT_STEP)
    unit = 0
    while value.round >= SHORT_COUNT_STEP && unit < SHORT_COUNT_UNITS.size - 1
      value /= SHORT_COUNT_STEP
      unit += 1
    end
    tenths = (value * 10).round
    body = if value < 10 && tenths < 100
      (tenths % 10).zero? ? (tenths / 10).to_s : format("%d.%d", *tenths.divmod(10))
    else
      value.round.to_s
    end
    "#{body}#{SHORT_COUNT_UNITS[unit]}"
  end

  # "Coloured mana symbols in Main: white 2, blue 4" for the bar's `aria-label`.
  # @return [String]
  def symbols_label = "Coloured mana symbols in #{scope_names}: #{symbols.map { |s| "#{COLOURS[s.colour]} #{delimited(s.count)}" }.join(', ')}"

  # The curve's `aria-label` (spec 060 AC-2.2): the scope, the cards in the curve, each column that has cards with its split, then the average.
  # @return [String]
  def curve_label
    head = "Mana curve of the #{counted(curve_cards, 'nonland card')} in #{scope_names}: "
    return "#{head}no cards." if curve_cards.zero?

    columns = curve.each_with_index.reject { |column, _| column.total.zero? }.map.with_index do |(column, index), position|
      split = [ ("#{delimited(column.owned)} owned" if column.owned.positive?), ("#{delimited(column.proxy)} proxy" if column.proxy.positive?) ].compact.join(", ")
      "#{'mana value ' if position.zero?}#{index == TOP_COLUMN ? '6+' : index}, #{counted(column.total, 'card')} (#{split})"
    end
    "#{head}#{columns.join('; ')}. Average mana value #{average_text}."
  end

  # The fold's facts line: the scope, and the average when the curve has cards.
  # @return [String]
  def facts = [ scope, ("average mana value #{average_text}" if average_text) ].compact.join(" · ")

  private
    def nonland = @nonland ||= rows.reject { MTG::DeckGroups.land?(it.answer.position) }

    # [[row, mana value]] for the nonland rows whose card has one.
    def valued = @valued ||= nonland.filter_map { |row| (value = mana_values[row.entry.catalog_identity_id]) && [ row, value ] }

    # One statement, none when no card counts: `{ identity id => mana value }` (spec 058's column, global catalog data).
    def mana_values
      @mana_values ||= begin
        ids = rows.map { it.entry.catalog_identity_id }.uniq
        ids.empty? ? {} : MTG::Card.where(catalog_identity_id: ids).where.not(mana_value: nil).pluck(:catalog_identity_id, :mana_value).to_h
      end
    end

    # `{ "W" => 3, … }` for every colour: each symbol of every row's first face's cost, times the row's cards.
    def symbol_counts
      @symbol_counts ||= rows.each_with_object(COLOURS.keys.index_with { 0 }) do |row, counts|
        cost = row.entry.extension&.faces&.first&.dig("mana_cost")
        cost.to_s.scan(/\{([^{}]+)\}/).flatten.each { |symbol| (symbol.split("/") & COLOURS.keys).each { counts[it] += row.total } }
      end
    end

    def delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number)

    def counted(number, word) = "#{delimited(number)} #{number == 1 ? word : word.pluralize}"
end
