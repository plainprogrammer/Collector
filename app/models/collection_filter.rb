# The name filter and counts the collection's grid and table share (spec 004 AC-11.1, AC-11.4;
# spec 006 AC-2.2, AC-2.3). Includers set @account and @query.
module CollectionFilter
  def self.normalize(query) = query.to_s.strip.first(Catalog::Search::MAX_QUERY_LENGTH)

  # An account's lots whose printing matches the filter.
  def self.lots(account, query)
    scope = account.lots.joins(:entry)
    query.present? ? scope.merge(Catalog::Entry.named_like(query)) : scope
  end

  attr_reader :query

  def filtered? = query.present?
  def empty_collection? = total_quantity.zero?
  def total_quantity = @total_quantity ||= @account.lots.sum(:quantity)
  def matching_quantity = @matching_quantity ||= matching_lots.sum(:quantity)

  def unique_cards
    @unique_cards ||= @account.lots.joins(:entry).distinct.count("catalog_entries.catalog_identity_id")
  end

  private
    def matching_lots = CollectionFilter.lots(@account, query)
end
