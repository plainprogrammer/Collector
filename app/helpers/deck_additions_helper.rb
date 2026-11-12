# Words and options of the Add to deck page (spec 071).
module DeckAdditionsHelper
  # The sentence inside "My copies (…)": the free total and where the copies are, "3 free: 2 in Blue binder, 1 in Red box",
  # at most `Lot::FreeCopies::PLACES_SHOWN` places and then "and 2 more places" (decision 7).
  #
  # @param free [Lot::FreeCopies]
  # @return [String]
  def free_copies_sentence(free)
    shown = free.places.first(Lot::FreeCopies::PLACES_SHOWN)
    parts = shown.map do |place|
      count = number_with_delimiter(place.count)
      place.name ? "#{count} in #{place.name}" : "#{count} with no location"
    end
    hidden = free.places.size - shown.size
    parts << "and #{hidden} more #{"place".pluralize(hidden)}" if hidden.positive?
    "#{number_with_delimiter(free.total)} free: #{parts.join(", ")}"
  end

  # The Deck and zone select's options: one `optgroup` "Decks" holding "Deck › Zone" for every zone, valued with the zone's
  # id; the placeholder is the select's `include_blank` (spec 071 decision 3; no Places group, only a zone can be chosen).
  #
  # @param groups [Array<Location::Choices::Group>] from `Deck::Addition#groups`
  # @param selected [String, nil] the zone id to mark
  # @return [ActiveSupport::SafeBuffer]
  def deck_zone_options(groups, selected: nil)
    zones = groups.flat_map { |group| group.zones.map { |zone| [ zone.label, zone.id.to_s ] } }
    grouped_options_for_select([ [ "Decks", zones ] ], selected)
  end

  # A radio's words: "My copies (3 free: …)" or "A proxy of SET · number Foil", `SET · number` in `is-data` (decision 9).
  #
  # @param addition [Deck::Addition]
  # @param use [Deck::Addition::Use]
  # @return [ActiveSupport::SafeBuffer, String]
  def use_label(addition, use)
    return "My copies (#{free_copies_sentence(addition.free)})" if use.kind == :copies

    finish = addition.finish_label(use)
    safe_join([ "A proxy of ", tag.span(set_number(addition.entry), class: "is-data"), (" #{finish}" if finish) ])
  end
end
