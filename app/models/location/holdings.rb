# What an account's lots hold in a location (spec 032 P1, P2): the totals, and the first lots for the page that refuses a
# removal. Collectible-agnostic: a lot is a quantity of an entry, the entry names it.
class Location::Holdings
  LISTED = 100 # as many lots as the import preview lists (spec 025 decision 11)
  Count = Data.define(:lots, :copies)
  EMPTY = Count.new(lots: 0, copies: 0)

  # Every location's totals for the locations page, in two grouped statements whatever the number of locations or lots.
  def self.counts(account)
    placed = account.lots.where.not(location_id: nil).group(:location_id)
    copies = placed.sum(:quantity)
    placed.count.to_h { |id, lots| [ id, Count.new(lots:, copies: copies.fetch(id)) ] }.tap { |counts| counts.default = EMPTY }
  end

  def initialize(location)
    @lots = Lot.where(account_id: location.account_id, location_id: location.id) # the location came from the signed-in account; the scope is by value, so it costs no query
  end

  def lots_count = @lots_count ||= @lots.count
  def copies = @copies ||= @lots.sum(:quantity)
  def any? = lots_count.positive?
  def total = Count.new(lots: lots_count, copies:)
  def more = lots_count - listed.size

  # The first LISTED lots, as the import preview orders lots: name, set code, number, language, finish, condition, price paid.
  def listed
    @listed ||= @lots.joins(entry: :set).preload(entry: :set).limit(LISTED).order(
      Catalog::Entry.arel_table[:name].asc, Catalog::Set.arel_table[:code].asc, Catalog::Entry.arel_table[:number].asc,
      Catalog::Entry.arel_table[:language].asc, Lot.arel_table[:finish].asc, Lot.arel_table[:condition].asc,
      Lot.arel_table[:price_paid_cents].asc).to_a
  end
end
