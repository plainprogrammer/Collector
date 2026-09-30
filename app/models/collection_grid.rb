# One page of an account's collection as image tiles: one per owned printing (spec 004 Story 11).
class CollectionGrid
  PER_PAGE = 120
  Tile = Data.define(:entry, :quantity, :special_finishes)

  attr_reader :query

  def initialize(account:, query:, page:)
    @account = account
    @query = query.to_s.strip.first(Catalog::Search::MAX_QUERY_LENGTH)
    @requested_page = page
  end

  def filtered? = query.present?
  def empty_collection? = total_quantity.zero?
  def total_quantity = @total_quantity ||= @account.lots.sum(:quantity)
  def matching_quantity = @matching_quantity ||= matching_lots.sum(:quantity)

  def unique_cards
    @unique_cards ||= @account.lots.joins(:entry).distinct.count("catalog_entries.catalog_identity_id")
  end

  def pagination
    @pagination ||= Catalog::Pagination.for(total_count: matching_lots.distinct.count(:catalog_entry_id),
      requested_page: @requested_page, per_page: PER_PAGE)
  end

  def tiles
    @tiles ||= begin
      rows = matching_lots.group(:catalog_entry_id)
        .order(Catalog::Entry.arel_table[:name].asc).merge(Catalog::Entry.newest_first)
        .offset(pagination.offset).limit(PER_PAGE)
        .pluck(:catalog_entry_id, Arel.sql("SUM(lots.quantity)"), Arel.sql("GROUP_CONCAT(DISTINCT lots.finish)"))
      entries = Catalog::Entry.includes(:set).where(id: rows.map(&:first)).index_by(&:id)
      rows.map do |entry_id, quantity, finishes|
        entry = entries.fetch(entry_id)
        special = Catalog.collecting_for(entry.collectible_type).special_finishes & finishes.to_s.split(",")
        Tile.new(entry:, quantity:, special_finishes: special)
      end
    end
  end

  private
    def matching_lots
      scope = @account.lots.joins(:entry)
      filtered? ? scope.merge(Catalog::Entry.named_like(query)) : scope
    end
end
