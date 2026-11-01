# One page of an account's collection as image tiles: one per owned printing (spec 004 Story 11).
class CollectionGrid
  include CollectionFilter

  PER_PAGE = 120
  Tile = Data.define(:entry, :quantity, :special_finishes, :place)
  # Where a printing's copies are: the place with most copies (+name+, nil when that is the unplaced lots) and how many
  # other places there are, unplaced counting as one (spec 033 Decision 1).
  Place = Data.define(:name, :more)

  def initialize(account:, query:, page:)
    @account = account
    @query = CollectionFilter.normalize(query)
    @requested_page = page
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
      places = places_of(entries.keys)
      rows.map do |entry_id, quantity, finishes|
        entry = entries.fetch(entry_id)
        special = Catalog.collecting_for(entry.collectible_type).special_finishes & finishes.to_s.split(",")
        Tile.new(entry:, quantity:, special_finishes: special, place: places[entry_id])
      end
    end
  end

  private
    # One statement for the page's printings, all of their lots (the filter is on the name, spec 033 AC-1.8). Nil for every
    # printing while the account has no location.
    def places_of(entry_ids)
      return {} unless places?

      rows = @account.lots.where(catalog_entry_id: entry_ids).left_joins(:location)
        .group(:catalog_entry_id, :location_id).pluck(:catalog_entry_id, Arel.sql("SUM(lots.quantity)"), "locations.name", "locations.name_key")
      rows.group_by(&:first).transform_values do |places|
        first, *others = places.sort_by { |_, quantity, name, key| [ -quantity, name ? 0 : 1, key.to_s, name.to_s ] }
        Place.new(name: first[2], more: others.size)
      end
    end
end
