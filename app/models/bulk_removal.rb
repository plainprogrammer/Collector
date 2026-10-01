# A bulk removal that can be undone once, from the status message right after it (spec 006 Story 7,
# FR-6). It belongs to the session that made it. Used or superseded, it keeps no lot data, so a
# replayed Undo can say it no longer works.
class BulkRemoval < ApplicationRecord
  NO_LONGER_UNDOABLE = "This removal can no longer be undone.".freeze
  NotUndoable = Class.new(StandardError)

  belongs_to :session
  belongs_to :account

  scope :undoable, -> { where.not(lots_data: nil) }

  # Removes the selected lots as they are now, keeping them for one undo; the selection empties (AC-7.3, AC-7.8).
  def self.remove!(selection)
    transaction do
      lots = selection.lots.to_a
      supersede!(selection.session)
      removal = create!(session: selection.session, account: selection.account, copies: lots.sum(&:quantity),
        lots_data: lots.map { |lot| lot.slice(:catalog_entry_id, :finish, :condition, :price_paid_cents, :quantity) })
      selection.account.lots.where(id: lots.map(&:id)).destroy_all
      selection.restart!(query: selection.query, sort: selection.sort)
      removal
    end
  end

  # Ends the chance to undo the session's earlier removal (AC-7.6).
  def self.supersede!(session) = session.bulk_removals.undoable.each { |removal| removal.update!(lots_data: nil) }

  def undoable? = !lots_data.nil?

  # Puts back exactly the removed lots, merging into lots of the same identity; all or nothing (AC-7.4, AC-7.5).
  def undo!(sort:)
    raise NotUndoable unless undoable?

    transaction do
      entries = Catalog::Entry.where(id: lots_data.pluck("catalog_entry_id")).index_by(&:id)
      Catalog::Entry.preload_extensions(entries.values)
      check_cap!(sort)
      lots_data.each do |data|
        Lot.add!(account:, entry: entries.fetch(data["catalog_entry_id"]), quantity: data["quantity"],
          finish: data["finish"], condition: data["condition"], price_paid_cents: data["price_paid_cents"])
      end
      update!(lots_data: nil)
    end
  end

  private
    # One query for every lot a restore would merge into, then the cap check in memory.
    def check_cap!(sort)
      existing = account.lots.where(catalog_entry_id: lots_data.pluck("catalog_entry_id").uniq)
        .index_by { |lot| [ lot.catalog_entry_id, lot.lot_key ] }
      over = lots_data.filter_map do |data|
        lot = existing[[ data["catalog_entry_id"], Lot.key_for(data["finish"], data["condition"], data["price_paid_cents"]) ]]
        lot if lot && lot.quantity + data["quantity"] > Lot::MAX_QUANTITY
      end
      raise Lot::CapExceeded, sort.apply(account.lots.joins(entry: :set).where(id: over.map(&:id))).preload(entry: :set).first if over.any?
    end
end
