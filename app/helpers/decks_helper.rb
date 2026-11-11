# The Decks pages' words (spec 062 FR-4); the markup is in `app/views/decks`.
module DecksHelper
  # "6 decks · 379 cards" for the Decks page's head: the decks, then the copies in all their zones (Considering included).
  #
  # @param listing [Deck::Listing]
  # @return [String]
  def deck_count_line(listing)
    cards = listing.rows.sum(&:cards)
    "#{pluralize(number_with_delimiter(listing.count), "deck")} · #{pluralize(number_with_delimiter(cards), "card")}"
  end

  # The line a narrow table shows under a deck's name: "Format name · 58 owned". Owned is the cards count until proxies exist
  # (spec 062 AC-4.4), which is why one number serves both columns.
  #
  # @param row [Deck::Listing::Row]
  # @return [String]
  def deck_sub_line(row)
    "#{row.deck.format_name} · #{number_with_delimiter(row.cards)} owned"
  end

  # The Format select's options: every format the registered collectibles give, in their registered order, as
  # `<type>/<key>` values. With formats of more than one type each type's formats sit under its category name; with one
  # the list is flat (spec 062 AC-1.2).
  #
  # @param selected [String, nil] the value to mark selected, as `<type>/<key>`
  # @return [ActiveSupport::SafeBuffer] option and optgroup tags
  def deck_format_options(selected)
    options = Catalog::Formats.options
    return options_for_select(options.map { [ it.format.name, it.value ] }, selected) unless Catalog::Formats.grouped?

    groups = options.group_by(&:type).map do |type, in_type|
      [ Catalog::Formats.category_name(type), in_type.map { [ it.format.name, it.value ] } ]
    end
    grouped_options_for_select(groups, selected)
  end

  # The value the Change format select starts on: the deck's own pair when the instance registers it, else the default format
  # (a deck whose registration was lost; the page head still shows its stored key, spec 064 AC-1.7).
  #
  # @param deck [Deck]
  # @return [String, nil] `<type>/<key>`
  def deck_format_selection(deck)
    Catalog::Formats.find(deck.collectible_type, deck.format) ? "#{deck.collectible_type}/#{deck.format}" : Catalog::Formats.default_option&.value
  end

  # The notice after a change of format: "Changed “Izzet Tempo” to <Format>. 12 cards moved to Considering." (the second
  # sentence only when copies moved, naming the zone as its row does), or that the deck already has the format (AC-1.3, AC-1.6).
  #
  # @param deck [Deck] after the change
  # @param change [Deck::FormatChange] after {Deck::FormatChange#save}
  # @return [String]
  def format_changed_message(deck, change)
    return "“#{deck.name}” is already #{deck.format_name}." unless change.changed?

    base = "Changed “#{deck.name}” to #{deck.format_name}."
    change.moved.positive? ? "#{base} #{pluralize(number_with_delimiter(change.moved), "card")} moved to #{change.considering_name}." : base
  end
end
