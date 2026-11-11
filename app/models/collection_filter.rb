# The name and location filters and counts the collection's grid and table share (spec 004 AC-11.1, AC-11.4;
# spec 006 AC-2.2, AC-2.3; spec 037). Includers set @account, @query and @requested_location (a CollectionFilter::Place
# value).
module CollectionFilter
  def self.normalize(query) = query.to_s.strip.first(Catalog::Search::MAX_QUERY_LENGTH)

  # An account's lots whose printing matches the name filter and that are in the place (spec 037 decision 2).
  def self.lots(account, query, place = "")
    scope = account.lots.joins(:entry)
    scope = scope.merge(Catalog::Entry.named_like(query)) if query.present?
    Place.apply(scope, place)
  end

  attr_reader :query

  # One read of the account's places in the locations page's order: the select's options, whether the account has one
  # (spec 033 Decision 2) and the chosen place's name (spec 037 NFR Performance). Places only (spec 062 D6): a deck or a zone
  # is not a filter value, so its id reads as "all" (AC-5.2).
  def locations = @locations ||= @account.locations.places.ordered.to_a

  # Whether the account has a place: the gate of the select, the filter and Move to… (they list places).
  def places? = locations.any?

  # Everything the account can choose a location from, read once (spec 065 decision 1).
  #
  # @return [Location::Choices]
  def choices = @choices ||= Location::Choices.new(@account)

  # Whether the account has a place or a zone: the gate of the select, the filter and Move to… (spec 065 decision 3).
  #
  # @return [Boolean]
  def choices? = choices.any?

  # Whether a lot's place is shown, on the tile's line, the table's Location column and the phone line: the account has a place,
  # or a lot in a zone, which has a place to read (spec 062 AC-5.8a). The second read happens only for an account with no
  # place, once.
  def place_column?
    return @place_column if defined?(@place_column)

    @place_column = places? || @account.lots.joins(:location).where(locations: { kind: "deck_zone" }).exists?
  end

  # The location filter as the page shows and queries it: "" unless the account has a place and the value is "none" or
  # names one of its own (spec 037 decisions 6 and 7).
  def location = @location ||= resolved_location
  def chosen_location = (locations.find { it.id.to_s == location } unless location.in?([ "", Place::NONE ]))

  def filtered? = query.present? || location.present?
  def empty_collection? = total_quantity.zero?
  def total_quantity = @total_quantity ||= @account.lots.sum(:quantity)
  def matching_quantity = @matching_quantity ||= matching_lots.sum(:quantity)

  def unique_cards
    @unique_cards ||= @account.lots.joins(:entry).distinct.count("catalog_entries.catalog_identity_id")
  end

  private
    def matching_lots = CollectionFilter.lots(@account, query, location)

    def resolved_location
      requested = @requested_location.to_s
      return "" unless places?

      requested == Place::NONE || locations.any? { it.id.to_s == requested } ? requested : ""
    end
end
