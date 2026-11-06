# The collection's location filter as one canonical string: "" (all), "none" (unplaced lots) or a location's id in
# decimal digits (spec 037 decision 1). Stored and compared as this string; never re-resolved to "all" for a stored
# selection or a submitted form (decision 7).
module CollectionFilter::Place
  NONE = "none".freeze
  ID = /\A[1-9]\d{0,17}\z/ # at most 18 digits: a longer id would overflow SQLite's 64-bit bind (spec 037 0.2.2)

  # Anything that isn't "none" or such an id (a non-string, "017", " 17", "17abc") is "".
  def self.parse(raw) = raw.is_a?(String) && (raw == NONE || raw.match?(ID)) ? raw : ""

  # A plain predicate on the lots' own column: another account's or a removed id matches no lot of this account's.
  def self.apply(scope, place)
    case place
    when "" then scope
    when NONE then scope.where(location_id: nil)
    else scope.where(location_id: place.to_i)
    end
  end
end
