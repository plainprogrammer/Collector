# One page of an account's collection as image tiles: one per owned printing (spec 004 Story 11).
class CollectionGrid
  include CollectionFilter

  PER_PAGE = 120
  Tile = Data.define(:entry, :quantity, :special_finishes, :place)
  # Where a printing's copies are: the place with most copies (+name+, nil when that is the unplaced lots) and how many
  # other places there are, unplaced counting as one (spec 033 Decision 1).
  Place = Data.define(:name, :more)

  def initialize(account:, query:, page:, location: "")
    @account = account
    @query = CollectionFilter.normalize(query)
    @requested_location = CollectionFilter::Place.parse(location)
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
    # One statement for the page's printings, all of their lots (the name filter doesn't narrow it, spec 033 AC-1.8). Nil for
    # every printing while the account has no place and no deck (spec 065 decision 3), and under a location filter, which
    # names the one place (spec 037 decision 3). The join reads every kind of location: a lot is followed to where it is, and a
    # zone's parent is joined too, so its tile reads "Deck › Zone" from the one statement (spec 062 AC-5.4).
    def places_of(entry_ids)
      return {} unless place_column? && location.empty?

      rows = @account.lots.where(catalog_entry_id: entry_ids).left_joins(:location)
        .joins("LEFT JOIN locations parents ON parents.id = locations.parent_id")
        .group(:catalog_entry_id, :location_id).pluck(:catalog_entry_id, Arel.sql("SUM(lots.quantity)"), "locations.name", "locations.name_key",
          "parents.name", "parents.name_key")
      rows.group_by(&:first).transform_values do |places|
        first, *others = places.sort_by { |_, quantity, name, key, _, parent_key| [ -quantity, name ? 0 : 1, parent_key || key.to_s, key.to_s, name.to_s ] }
        Place.new(name: tile_label(first[2], first[4]), more: others.size)
      end
    end

    # A place's name, or "Deck › Zone" when the row has a deck name (what `Lot#place_label` gives, for rows that are plucked).
    def tile_label(name, deck_name) = deck_name ? Location::Placement.label(name, deck_name) : name
end
