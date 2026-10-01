# Sets one condition on many lots of an account (spec 006 Story 6). Lots that become identical to
# another lot of the account merge into it, as a single edit does (004 AC-10.2). All or nothing: the
# cap is checked for every merge before anything is written (AC-6.4).
class Lot::ConditionChange
  def initialize(account:, lots:, condition:, sort:)
    @account, @lots, @condition, @sort = account, lots, condition, sort
  end

  # Returns the ids of the lots holding the changed copies.
  def apply!
    Lot.transaction do
      lots = @lots.preload(:entry).to_a
      Catalog::Entry.preload_extensions(lots.map(&:entry))
      groups = lots.group_by { |lot| [ lot.catalog_entry_id, Lot.key_for(lot.finish, @condition, lot.price_paid_cents) ] }
      targets = existing_targets(groups.keys, lots)
      check_cap!(groups, targets)
      alone = groups.reject { |key, group| group.many? || targets[key] }
      update_alone!(alone.values.flatten.map(&:id))
      groups.map { |key, group| alone.key?(key) ? group.first.id : merge(targets[key], group).id }
    end
  end

  private
    # Lots outside the change that already have a target identity. Only the entry is filtered in SQL:
    # adding lot_key IN and id NOT IN lists made SQLite take seconds at 5,000 lots.
    def existing_targets(keys, lots)
      changed = lots.to_set(&:id)
      @account.lots.where(catalog_entry_id: keys.map(&:first).uniq).reject { |lot| changed.include?(lot.id) }
        .index_by { |lot| [ lot.catalog_entry_id, lot.lot_key ] }.slice(*keys)
    end

    def check_cap!(groups, targets)
      over = groups.select { |key, group| group.sum(&:quantity) + (targets[key]&.quantity || 0) > Lot::MAX_QUANTITY }.values.flatten
      return if over.empty?

      raise Lot::CapExceeded, @sort.apply(@account.lots.joins(entry: :set).where(id: over.map(&:id))).preload(entry: :set).first
    end

    # Lots that keep their own identity, in one statement: lot_key is rebuilt as Lot.key_for would.
    def update_alone!(ids)
      return if ids.empty?

      @account.lots.where(id: ids).update_all([ "condition = ?, lot_key = COALESCE(finish, '') || '|' || ? || '|' || COALESCE(price_paid_cents, ''), updated_at = ?", @condition.presence, @condition.to_s, Time.current ]) # Safe: tenant-scoped; the controller validated the condition against the vocabulary; quantity and finish don't change; merges are handled separately, so no identity collides
    end

    # The existing lot survives if there is one, else the group's first lot; the others fold into it.
    def merge(target, group)
      survivor = target || group.first
      quantity = group.sum(&:quantity) + (target&.quantity || 0)
      (group - [ survivor ]).each(&:destroy!)
      survivor.update!(condition: @condition, quantity:)
      survivor
    end
end
