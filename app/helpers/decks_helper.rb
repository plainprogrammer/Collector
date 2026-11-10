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

  # The line a narrow table shows under a deck's name: "Modern · 58 owned". Owned is the cards count until proxies exist
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
end
