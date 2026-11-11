# The name and location filters and counts the collection's grid and table share (spec 004 AC-11.1, AC-11.4;
# spec 006 AC-2.2, AC-2.3; spec 037; spec 065). Includers set @account, @query and @requested_location (a
# CollectionFilter::Place value: "", "none", a place's or a zone's id, or `deck:<id>`).
module CollectionFilter
  def self.normalize(query) = query.to_s.strip.first(Catalog::Search::MAX_QUERY_LENGTH)

  # An account's lots whose printing matches the name filter and that are in the place (spec 037 decision 2).
  def self.lots(account, query, place = "")
    scope = account.lots.joins(:entry)
    scope = scope.merge(Catalog::Entry.named_like(query)) if query.present?
    Place.apply(scope, place)
  end

  attr_reader :query

  # Everything the account can choose a location from, read once: the select's options, whether the account has any and the
  # chosen location's label (spec 065 decision 1; spec 037 NFR Performance).
  #
  # @return [Location::Choices]
  def choices = @choices ||= Location::Choices.new(@account)

  # Whether the account has a place or a zone: the gate of the select, the filter and Move to… (spec 065 decision 3).
  #
  # @return [Boolean]
  def choices? = choices.any?

  # Whether a lot's place is shown, on the tile's line, the table's Location column and the phone line: the account has a place
  # or a zone (spec 065 decision 3; supersedes spec 062 AC-5.8a, so no second read is made for an account with no place).
  def place_column? = choices?

  # The location filter as the page shows and queries it: "" unless the account has a place or a zone and the value is "none" or
  # names one of its own (spec 037 decisions 6 and 7; spec 065 decision 4).
  def location = @location ||= resolved_location

  # The place, zone or deck the filter names, nil for all and none; a zone's label reads "Deck › Zone".
  #
  # @return [Location, nil]
  def chosen_location = (choice_for(location) unless location.in?([ "", Place::NONE ]))

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
      return "" unless choices?

      requested == Place::NONE || choice_for(requested) ? requested : ""
    end

    # The location a canonical value names among the account's choices: a place or a zone by its id, a deck by `deck:<id>`
    # (never a deck's own id without its prefix, never a zone's id with one).
    def choice_for(value)
      match = Place::DECK.match(value)
      match ? choices.deck(match[1])&.location : choices.find(value)
    end
end
