# What an account holds of one card, seen from one of its printings (spec 004 AC-8.4, AC-8.5, AC-8.7).
class Catalog::CardOverview
  NEWEST = 10
  Row = Data.define(:entry, :owned, :shown)

  attr_reader :entry

  def initialize(account:, entry:)
    @account, @entry = account, entry
  end

  def identity = entry.identity
  def vocabulary = Catalog.collecting_for(entry.collectible_type)

  def lots
    @lots ||= @account.lots.joins(:entry).where(catalog_entries: { catalog_identity_id: identity.id })
      .includes(entry: :set).merge(Catalog::Entry.newest_first).order(:finish, :condition, :price_paid_cents).to_a
  end

  def owned_count = lots.sum(&:quantity)
  def printings_owned = lots.map(&:catalog_entry_id).uniq.size
  def total_printings = @total_printings ||= identity.entries.searchable.count

  def rows
    @rows ||= begin
      owned = lots.group_by(&:catalog_entry_id).transform_values { |group| group.sum(&:quantity) }
      owned_entries = Catalog::Entry.where(id: owned.keys).where.not(id: entry.id).newest_first.includes(:set).to_a
      listed = [ entry.id, *owned_entries.map(&:id) ]
      newest = identity.entries.searchable.where.not(id: listed).newest_first.includes(:set).limit(NEWEST).to_a
      [ entry, *owned_entries, *newest ].map { |row_entry| Row.new(entry: row_entry, owned: owned.fetch(row_entry.id, 0), shown: row_entry == entry) }
    end
  end
end
