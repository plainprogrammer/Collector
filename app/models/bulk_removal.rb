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
        lots_data: lots.map { |lot| lot.slice(:catalog_entry_id, :finish, :condition, :price_paid_cents, :quantity, :location_id) })
      selection.account.lots.where(id: lots.map(&:id)).destroy_all
      selection.restart!(query: selection.query, sort: selection.sort)
      removal
    end
  end

  # Ends the chance to undo the session's earlier removal (AC-7.6).
  def self.supersede!(session) = session.bulk_removals.undoable.each { |removal| removal.update!(lots_data: nil) }

  def undoable? = !lots_data.nil?

  # What came back: how many saved lots had a location the account no longer has and so came back unplaced (spec 032 P5).
  Undone = Data.define(:unplaced)

  # Puts back the removed lots, each in the location it was in if the account still has it, else in none; saved lots that then
  # share an identity are one lot with the summed quantity, merging into the lot of that identity if there is one. All or
  # nothing (spec 006 AC-7.4, AC-7.5; spec 032 P5, AC-7.8).
  def undo!(sort:)
    raise NotUndoable unless undoable?

    transaction do
      entries = Catalog::Entry.where(id: lots_data.pluck("catalog_entry_id")).index_by(&:id)
      Catalog::Entry.preload_extensions(entries.values)
      locations = account.locations.where(id: lots_data.filter_map { |data| data["location_id"] }).index_by(&:id)
      unplaced = lots_data.count { |data| data["location_id"] && !locations.key?(data["location_id"]) }
      rows = restored_rows(locations)
      existing = existing_lots(rows)
      check_cap!(rows, existing, entries, sort)
      merging, alone = rows.partition { |row| existing.key?(identity(row)) }
      insert_alone!(alone)
      merging.each do |row|
        Lot.add!(account:, entry: entries.fetch(row["catalog_entry_id"]), quantity: row["quantity"], finish: row["finish"],
          condition: row["condition"], price_paid_cents: row["price_paid_cents"], location: locations[row["location_id"]])
      end
      update!(lots_data: nil)
      Undone.new(unplaced:)
    end
  end

  private
    # The saved lots with a location the account no longer has set to none, and those that then share an identity made one.
    def restored_rows(locations)
      lots_data.map { |data| data.merge("location_id" => (data["location_id"] if locations.key?(data["location_id"]))) }
        .group_by { |row| identity(row) }.values.map { |group| group.first.merge("quantity" => group.sum { |row| row["quantity"] }) }
    end

    # One query for every lot a restore would merge into, indexed by identity.
    def existing_lots(rows)
      account.lots.where(catalog_entry_id: rows.pluck("catalog_entry_id").uniq).index_by { |lot| [ lot.catalog_entry_id, lot.lot_key ] }
    end

    def identity(data) = [ data["catalog_entry_id"], Lot.key_for(data["finish"], data["condition"], data["price_paid_cents"], data["location_id"]) ]

    # An existing lot that would pass 9,999 is named first, by the table's sort (spec 006 AC-7.5); if only the restored rows
    # together pass it there is no lot of the account to name, so the first such row is (spec 032 O2, ruled 2026-10-24).
    def check_cap!(rows, existing, entries, sort)
      over = rows.select { |row| row["quantity"] + (existing[identity(row)]&.quantity || 0) > Lot::MAX_QUANTITY }
      return if over.empty?

      held = over.filter_map { |row| existing[identity(row)] }
      raise Lot::CapExceeded, sort.apply(account.lots.joins(entry: :set).where(id: held.map(&:id))).preload(entry: :set).first if held.any?

      raise Lot::CapExceeded, Lot.new(entry: entries.fetch(over.first["catalog_entry_id"]))
    end

    # Rows with no lot of their identity, in one statement.
    def insert_alone!(rows)
      return if rows.empty?

      now = Time.current
      account.lots.insert_all(rows.map do |data| # Safe: values are restored exactly as they were validated when stored, and each identity is free (checked against the index loaded in this transaction)
        data.slice("catalog_entry_id", "quantity", "finish", "condition", "price_paid_cents", "location_id")
          .merge("lot_key" => identity(data).last, "created_at" => now, "updated_at" => now)
      end)
    end
end
