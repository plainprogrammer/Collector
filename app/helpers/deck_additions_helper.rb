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
end
