# One page of an account's collection as table rows, one per lot (spec 006 Story 2), in the chosen
# sort (Story 3).
class CollectionTable
  include CollectionFilter

  PER_PAGE = 120

  attr_reader :sort

  def initialize(account:, query:, page:, sort:, location: "")
    @account = account
    @query = CollectionFilter.normalize(query)
    @requested_location = CollectionFilter::Place.parse(location)
    @requested_page = page
    @sort = sort
  end

  def pagination
    @pagination ||= Catalog::Pagination.for(total_count: matching_lots.count, requested_page: @requested_page, per_page: PER_PAGE)
  end

  # The requested page's lots in the chosen sort, with each lot's place (and a zone's deck) and its entry and set preloaded so
  # the table's rows and their "Deck › Zone" labels cost no statement per row (spec 062).
  # @return [Array<Lot>] at most `PER_PAGE` lots
  def lots
    @lots ||= sort.apply(matching_lots.joins(entry: :set)).preload({ location: :parent }, entry: :set)
      .offset(pagination.offset).limit(PER_PAGE).to_a
  end
end
