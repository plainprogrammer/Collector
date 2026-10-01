# One page of an account's collection as table rows, one per lot (spec 006 Story 2), in the chosen
# sort (Story 3).
class CollectionTable
  include CollectionFilter

  PER_PAGE = 120

  attr_reader :sort

  def initialize(account:, query:, page:, sort:)
    @account = account
    @query = CollectionFilter.normalize(query)
    @requested_page = page
    @sort = sort
  end

  def pagination
    @pagination ||= Catalog::Pagination.for(total_count: matching_lots.count, requested_page: @requested_page, per_page: PER_PAGE)
  end

  def lots
    @lots ||= sort.apply(matching_lots.joins(entry: :set)).preload(entry: :set)
      .offset(pagination.offset).limit(PER_PAGE).to_a
  end
end
