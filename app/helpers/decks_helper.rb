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
end
