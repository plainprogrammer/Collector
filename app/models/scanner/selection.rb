# What the scanner's selection pane shows for one reading (spec 088 decisions 2 to 4, 15): the items of the swipe row, each
# with the status band it reads, as the server renders them. Two kinds. When the scanner is sure of the card the row is its
# printings, the matched one first and then the others in `Scanner::OtherPrintings` order, the first `STEP` of them; when it
# is not sure it is the candidate cards, one printing each, and a card's own printings are one tap away (`for_card`). It ranks
# nothing and reads nothing: it takes a reading's candidates as ranked (their evidence predicates: `collector_line?`,
# `corrected?`, `art?`, `art_unique`, `card_sure?`) and the printings as `OtherPrintings` orders them, and it names no
# collectible (`spec/scanner_sitting_core_spec.rb`).
#
# @example the answer to a reading
#   selection = Scanner::Selection.for_reading(reading, key: key)
#   selection.items.first.band.sentence # => "Matched by its collector line"
class Scanner::Selection
  # A status band's content: form (:success or :warning), the icon partial's name and the sentence.
  Band = Data.define(:form, :icon, :sentence)
  # One card of the row: its printing, the rank the add event records (nil for "other"), its band and the band state its
  # printing would have if the collector chose its card ("All printings").
  Item = Data.define(:entry, :rank, :band, :state)

  BANDS = {
    collector_line: Band.new(:success, :check, "Matched by its collector line"),
    collector_line_corrected: Band.new(:success, :check, "Matched by its collector line, one digit corrected"),
    art: Band.new(:success, :check, "Matched by its artwork"),
    guess: Band.new(:warning, :alert, "Printing not confirmed. Swipe to check."),
    unsure: Band.new(:warning, :question, "Not sure of this card. Check it against your capture."),
    other: Band.new(:warning, :alert, "Not the printing that was read")
  }.freeze
  # The states a printings row's first item may have, a closed list: a request's `band` outside it is a guess.
  PRINTING_STATES = %i[collector_line collector_line_corrected art guess].freeze
  # Printings loaded at once, and per "Show 20 more" (spec 088 decision 4; the existing Other printings constant).
  STEP = Scanner::OtherPrintings::SHOWN
  # The most printings a row ever holds (a basic land has more English printings than that).
  MAX = 200

  attr_reader :kind, :items, :total, :current, :limit, :key, :finish_hint, :set, :number, :artwork, :identity, :match, :state

  # The band state of a reading's first candidate: the evidence when its printing is confirmed, a guess when the card is
  # sure and the printing is not, else :unsure.
  #
  # @param candidate [#collector_line?, #corrected?, #art?, #art_unique, #card_sure?] a ranked candidate
  # @return [Symbol] one of :collector_line, :collector_line_corrected, :art, :guess, :unsure
  def self.state_of(candidate)
    printing_state_of(candidate, sure: candidate.card_sure?) || :unsure
  end

  # The band state of a printing whose card the collector has chosen ("All printings"): the evidence when its printing is
  # confirmed, else a guess, never :unsure.
  #
  # @param candidate [#collector_line?, #corrected?, #art?, #art_unique] a ranked candidate
  # @param sure [Boolean] whether the card is trusted; false returns nil for a printing that is not confirmed
  # @return [Symbol, nil]
  def self.printing_state_of(candidate, sure: true)
    if candidate.collector_line? then candidate.corrected? ? :collector_line_corrected : :collector_line
    elsif candidate.art? && candidate.art_unique then :art
    elsif sure then :guess
    end
  end

  # The selection a reading's answer renders.
  #
  # @param reading [#candidates, #finish_hint, #collector_line] a resolved reading with at least one candidate
  # @param key [String] the reading's key
  # @return [Scanner::Selection]
  def self.for_reading(reading, key:)
    first = reading.candidates.first
    context = { key:, finish_hint: reading.finish_hint, set: reading.collector_line.set_code, number: reading.collector_line.number }
    state = state_of(first)
    if state == :unsure
      items = reading.candidates.each_with_index.map do |candidate, index|
        Item.new(entry: candidate.entry, rank: index + 1, band: BANDS.fetch(:unsure), state: printing_state_of(candidate) || :guess)
      end
      new(kind: :cards, items:, total: items.size, current: 0, limit: STEP, **context)
    else
      for_card(identity: first.entry.identity, match: first.entry, state:, artwork: first.artwork_id, first_rank: 1, **context)
    end
  end

  # One card's printings, `match` first: the answer to the reading, to "All printings" and to "Show 20 more".
  #
  # @param identity [Catalog::Identity] the card
  # @param match [Catalog::Entry] the printing that goes first, one of the card's
  # @param state [String, Symbol] the band state of that printing; outside `PRINTING_STATES` it is :guess
  # @param limit [Integer, String] how many printings to render, clamped to `STEP`..`MAX`
  # @param current [String, nil] the external key of the printing to centre
  # @param first_rank [Integer, nil] the rank the first item's add event records
  # @return [Scanner::Selection]
  def self.for_card(identity:, match:, state:, key:, set: nil, number: nil, finish_hint: nil, artwork: nil, limit: STEP, current: nil, first_rank: nil)
    state = PRINTING_STATES.find { it.to_s == state.to_s } || :guess
    limit = (limit.to_s.to_i + STEP - 1).then { it / STEP * STEP }.clamp(STEP, MAX) # a multiple of STEP; arrays and junk read as 0
    others = Scanner::OtherPrintings.new(identity:, set_code: set, number:, artwork:).entries.reject { it.id == match.id }
    ordered = [ match, *others ]
    items = ordered.first(limit).each_with_index.map do |entry, index|
      index.zero? ? Item.new(entry:, rank: first_rank, band: BANDS.fetch(state), state:) : Item.new(entry:, rank: nil, band: BANDS.fetch(:other), state: :guess)
    end
    new(kind: :printings, items:, total: ordered.size, current: (items.index { it.entry.external_key == current } if current) || 0, limit:,
      key:, finish_hint:, set:, number:, artwork:, identity:, match:, state:)
  end

  def initialize(kind:, items:, total:, current:, limit:, key:, finish_hint: nil, set: nil, number: nil, artwork: nil, identity: nil, match: nil, state: nil)
    @kind, @items, @total, @current, @limit = kind, items, total, current, limit
    @key, @finish_hint, @set, @number, @artwork = key, finish_hint, set, number, artwork
    @identity, @match, @state = identity, match, state
  end

  # Printings not rendered yet (the row's "more" item); always 0 for a cards row.
  #
  # @return [Integer]
  def more = kind == :printings ? total - items.size : 0

  # Whether the row ends with a "more printings" item.
  #
  # @return [Boolean]
  def more? = more.positive?

  # The row's items, with the more item when there is one: Previous and Next step through this many.
  #
  # @return [Integer]
  def count = items.size + (more? ? 1 : 0)

  # The query of the selection frame's request for this card (`GET /scanner/printings`), with the given params merged in.
  #
  # @param extra [Hash] params that replace or add to the card's
  # @return [Hash{Symbol => String, Integer}] only the params that have a value
  def link_params(**extra)
    { card: identity.external_key, key:, set:, number:, finish_hint:, artwork:, match: match.external_key, band: state, limit: }.compact.merge(extra)
  end

  # The query that opens a possible card's own printings ("All printings"): that printing first, its band by its own evidence.
  #
  # @param item [Item] a possible card's item
  # @return [Hash{Symbol => String, Integer}]
  def printings_params(item)
    { card: item.entry.identity.external_key, key:, set:, number:, finish_hint:, match: item.entry.external_key, band: item.state, limit: STEP }.compact
  end
end
