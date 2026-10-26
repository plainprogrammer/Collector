module LocationsHelper
  # "12 copies in 3 lots", "1 copy in 1 lot", "Empty" (spec 032 P2).
  def location_holds(count)
    return "Empty" if count.lots.zero?

    "#{pluralize(number_with_delimiter(count.copies), "copy")} in #{pluralize(number_with_delimiter(count.lots), "lot")}"
  end
end
