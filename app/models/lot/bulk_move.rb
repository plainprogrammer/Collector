# Moves every copy of many lots to one location, or to none (spec 041). Lots that reach one identity in the destination
# merge into one (the destination's own lot survives, else the first moved lot in the bulk table's order); a selected lot
# already in the destination stays where it is (decision 3). All or nothing: the 9,999 cap is checked for every merge
# before anything is written. Collectible-agnostic.
#
# models.md says not to use update_all/delete_all in normal flows (they skip validations and tenant checks). The move does, as
# Lot::ConditionChange#update_alone! does, for the 2-second bar, and each statement is safe: scoped through @account.lots,
# values bound, the cap and every identity collision checked on the lots read in this transaction, the place looked up through
# the account; Lot's only callback is the lot_key builder (before_validation), which these writes reproduce (the SQL in
# move_alone!, Lot.key_for in merge!); it has no dependent: associations, and finish and condition aren't written, so
# normalizes isn't bypassed.
class Lot::BulkMove
  CHOOSE = "Choose where to move them.".freeze
  NO_LOCATIONS = "You have no locations yet.".freeze
  BATCH = 1_000 # ids per statement, well inside SQLite's bound-variable limit

  # +ids+: the lots now holding the moved copies; +moved+: the copies that moved; +already_there+: the selected copies that
  # were already in the destination.
  Result = Data.define(:ids, :moved, :already_there)

  # Every selected lot is already in the destination: nothing would change (spec 041 AC-3.7).
  class NothingToMove < StandardError
    attr_reader :to

    def initialize(to)
      @to = to
      super(to ? "The selected items are already in #{to.name}." : "The selected items already have no location.")
    end
  end

  # The selection selects no lot any more (removed in another tab): not "already there" (spec 041 decision 6 (3)).
  class NoLotsLeft < StandardError
    def initialize = super(BulkSelection::NONE_LEFT)
  end

  # +to+ is a Location of +account+, or nil for none. +lots+ is the selection's relation of the account's lots.
  def initialize(account:, lots:, to:, sort:)
    @account, @lots, @to, @sort = account, lots, to, sort
  end

  def apply!
    Lot.transaction do
      lots = @sort.apply(@lots.where(account_id: @account.id).joins(entry: :set)).to_a # the account's lots only, in the bulk table's order, read under the write lock
      raise NoLotsLeft if lots.empty?

      movers, stayers = lots.partition { |lot| lot.location_id != @to&.id }
      raise NothingToMove, @to if movers.empty?

      groups = movers.group_by { |lot| [ lot.catalog_entry_id, key_for(lot) ] }
      targets = existing_targets(groups.keys)
      alone = groups.select { |key, group| group.one? && !targets[key] }
      move_alone!(alone.values.map { |group| group.first.id }, Time.current)
      Result.new(ids: groups.map { |key, group| targets[key]&.id || group.first.id }, moved: movers.sum(&:quantity), already_there: stayers.sum(&:quantity))
    end
  end

  private
    def key_for(lot) = Lot.key_for(lot.finish, lot.condition, lot.price_paid_cents, @to&.id)

    # The destination's lots of the identities being moved in, selected or not. Only the entry and the place are filtered in
    # SQL: Lot::ConditionChange found long id lists on lot_key slow at 5,000 lots.
    def existing_targets(keys)
      @account.lots.where(location_id: @to&.id, catalog_entry_id: keys.map(&:first).uniq).index_by { |lot| [ lot.catalog_entry_id, lot.lot_key ] }.slice(*keys)
    end

    # Lots that keep their own identity apart from the place, in one statement per batch: lot_key is rebuilt as Lot.key_for
    # would, place included (a fifth key builder; spec 041 FR-2, ADR 0025). Merging lots are handled separately.
    def move_alone!(ids, now)
      suffix = @to ? "|#{@to.id}" : ""
      ids.each_slice(BATCH) do |slice|
        @account.lots.where(id: slice).update_all([ "location_id = ?, lot_key = COALESCE(finish, '') || '|' || COALESCE(condition, '') || '|' || COALESCE(price_paid_cents, '') || ?, updated_at = ?", @to&.id, suffix, now ]) # Safe: tenant-scoped; every value is bound; the destination was looked up through the account; the identity of each lot is free in the destination (checked against the lots read in this transaction); quantity, finish, condition and price don't change
      end
    end
end
