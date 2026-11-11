# Moves every copy of many lots to one location, to none, or to a deck's Considering zone (spec 041, spec 064). Lots that
# reach one identity in the destination merge into one (the destination's own lot survives, else the first moved lot in the
# bulk table's order); a selected lot already in the destination stays where it is (decision 3). All or nothing: the 9,999
# cap is checked for every merge before anything is written. Collectible-agnostic.
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

  # +to+ is a place of +account+, a zone of one of its decks, or nil for none, never a deck's own row: the writes below skip
  # validations, so the caller's lookup is what keeps a lot out of a deck. The collection's Move to… passes a place or none
  # (`Collections::MovesController`); a deck's change of format passes its Considering zone (`Deck::FormatChange`, spec 064).
  # +lots+ is the selection's relation of the account's lots, whatever place each is in: a lot in a zone is never "already
  # there", so the partition below, by `lot.location_id != @to&.id`, moves it out of its zone; when +to+ is a zone of a deck,
  # the lots moved are those of the deck's other zones, so none is already there either.
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
      alone, merging = groups.partition { |key, group| group.one? && !targets[key] }
      check_cap!(groups, targets, lots.to_set(&:id))
      now = Time.current
      delete!(merging.flat_map { |key, group| targets[key] ? group : group.drop(1) }.map(&:id))
      merging.each { |key, group| merge!(key, group, targets[key], now) }
      move_alone!(alone.map { |_, group| group.first.id }, now)
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

    # Every merge is checked before anything is written (spec 041 AC-3.8). The lot named is the first, in the table's order,
    # among the *selected* lots of the over-cap identities: the moved lots and a selected lot already there; an unselected
    # destination lot may not be in the table.
    def check_cap!(groups, targets, selected)
      over = groups.select { |key, group| group.sum(&:quantity) + (targets[key]&.quantity || 0) > Lot::MAX_QUANTITY }
      return if over.empty?

      named = over.flat_map { |key, group| group + [ targets[key] ].compact.select { |target| selected.include?(target.id) } }
      raise Lot::CapExceeded, @sort.apply(@account.lots.joins(entry: :set).where(id: named.map(&:id))).preload(entry: :set).first
    end

    # Lots that keep their own identity apart from the place, in one statement per batch: lot_key is rebuilt as Lot.key_for
    # would, place included (a fifth key builder; spec 041 FR-2, ADR 0025). Merging lots are handled separately.
    def move_alone!(ids, now)
      suffix = @to ? "|#{@to.id}" : ""
      ids.each_slice(BATCH) do |slice|
        @account.lots.where(id: slice).update_all([ "location_id = ?, lot_key = COALESCE(finish, '') || '|' || COALESCE(condition, '') || '|' || COALESCE(price_paid_cents, '') || ?, updated_at = ?", @to&.id, suffix, now ]) # Safe: tenant-scoped; every value is bound; the destination was looked up through the account; the identity of each lot is free in the destination (checked against the lots read in this transaction); quantity, finish, condition and price don't change
      end
    end

    # The destination's lot gains the copies and survives; with none, the group's first lot takes the place and the sum.
    # One statement per surviving lot, written with Lot.key_for's text (key.last): validations would load each lot's entry
    # and vocabulary, and the cap, the place and the tenant are checked above.
    def merge!(key, group, target, now)
      if target
        @account.lots.where(id: target.id).update_all(quantity: target.quantity + group.sum(&:quantity), updated_at: now) # Safe: tenant-scoped; the cap was checked for this sum
      else
        @account.lots.where(id: group.first.id).update_all(location_id: @to&.id, lot_key: key.last, quantity: group.sum(&:quantity), updated_at: now) # Safe: tenant-scoped; the cap was checked; the key is Lot.key_for's
      end
    end

    # The database nulls or cascades what points at a lot (number-entry lines, scanner entries, marks).
    def delete!(ids)
      ids.each_slice(BATCH) { |slice| @account.lots.where(id: slice).delete_all } # Safe: tenant-scoped, bound ids
    end
end
