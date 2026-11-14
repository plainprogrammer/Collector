module ScannersHelper
  # The visually hidden tail of a band sentence, naming the centred card so the band's text changes with every swipe and is
  # announced each time (spec 088 decision 8): "Printing 2 of 14: Lightning Bolt, Double Masters 2022, 2X2 · 117." The more item
  # (index past the items) says what it offers instead.
  #
  # @param selection [Scanner::Selection]
  # @param index [Integer] the item's place in the row
  # @return [String]
  def selection_tail(selection, index)
    return "#{pluralize(selection.more, "more printing")}. Show 20 more." if index >= selection.items.size

    entry = selection.items[index].entry
    noun = selection.kind == :cards ? "Card" : "Printing"
    "#{noun} #{index + 1} of #{selection.total}: #{entry.display_name}, #{entry.set.name}, #{set_number(entry)}."
  end

  # "2 of 14 printings", "1 of 3 possible cards": the details block's position (spec 088, design decision 15).
  #
  # @param selection [Scanner::Selection]
  # @param index [Integer] the item's place in the row
  # @return [String]
  def selection_position(selection, index)
    noun = selection.kind == :cards ? "possible card" : "printing"
    "#{index + 1} of #{pluralize(selection.total, noun)}"
  end

  def ocr_engine_path = "/ocr/#{::Collector::OcrEngine::VERSION}"

  def scanner_finish(printing, finish) = finish && Catalog.collecting_for(printing.collectible_type).finish_label(finish)

  # "NM": a lot's or a sitting's condition as its short label, from the vocabulary of the printing's own collectible (spec 042
  # decision 3); nil when none is set or the vocabulary doesn't list it. No query: the vocabulary is a constant.
  def scanner_condition(printing, condition) = condition && Catalog.collecting_for(printing.collectible_type).conditions[condition]&.last

  # "Tome Shredder (STX · 117, Foil, NM)": a scanner add's card, printing, finish and, when given, condition (spec 009 AC-1.3,
  # spec 042 decision 3). The Undo announcement and the accessible names call it without a condition (spec 042 decision 3).
  def scanner_copy(printing, finish, condition = nil)
    "#{printing.name} (#{[ set_number(printing), scanner_finish(printing, finish), scanner_condition(printing, condition) ].compact.join(", ")})"
  end

  # The sitting's choices as words, only those that are set: "Near mint", "in Blue binder" (spec 042 decision 3). The scale is
  # the Hash the caller gives (condition key => [ long label, short label ]).
  def sitting_choices(sitting, conditions)
    [ sitting.condition && conditions.dig(sitting.condition, 0), ("in #{sitting.location.label}" if sitting.location) ].compact
  end

  # "Atraxa › Main · NM": the top bar's value, the sitting's place (a zone by its label) and its condition's short label, in spec
  # 082 decision 7's four forms ("Blue binder", "No location · NM", "No location"). The scale is the Hash the caller gives
  # (condition key => [ long label, short label ]); nil sitting reads as nothing set.
  #
  # @param sitting [Scanner::Sitting, nil]
  # @param conditions [Hash{String => Array(String, String)}]
  # @return [String]
  def scanner_destination(sitting, conditions)
    short = sitting&.condition && conditions.dig(sitting.condition, 1)
    [ sitting&.location&.label || "No location", short ].compact.join(" · ")
  end

  # "This sitting: 12 cards, Near mint, in Blue binder": the list sheet's title, today's heading (spec 009 AC-3.2), with no
  # sitting too ("This sitting: 0 cards", spec 082 decision 9).
  #
  # @param sitting [Scanner::Sitting, nil]
  # @param entries [Array] the kept entries
  # @param conditions [Hash{String => Array(String, String)}]
  # @return [String]
  def sitting_title(sitting, entries, conditions)
    words = sitting ? sitting_choices(sitting, conditions) : []
    "This sitting: #{pluralize(entries.size, "card")}#{", #{words.join(", ")}" if words.any?}"
  end

  # "Added Lightning Bolt MOM · 123, foil": the after-add line, which names no condition or place, since the top bar shows them
  # (spec 080 decision 11, spec 082 decision 12); a printing with no finish listed has none.
  #
  # @param printing [Catalog::Entry]
  # @param finish [String, nil]
  # @return [String]
  def scanner_added(printing, finish)
    label = scanner_finish(printing, finish)
    "Added #{printing.name} #{set_number(printing)}#{", #{label.downcase}" if label}"
  end

  # The data of a redrawn sitting panel that puts keyboard focus back (spec 047 decision 3): nil on a page render, so nothing is
  # focused by it. `focus` is :set, :heading or :main (the main button, spec 082 decision 15; an add names :main, since its
  # button went with the result), a word of ours; the Stimulus controller reads it once.
  def sitting_focus_data(focus) = (focus ? { controller: "sitting-focus", sitting_focus_to_value: focus } : nil)
end
