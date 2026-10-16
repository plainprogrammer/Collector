# One added line of number entry (spec 026 FR-3): the entry, the quantity and finish, the lot the copies went into and
# the form's line key. The lot reference clears itself (on delete set null) when that lot is removed or merged away.
class NumberEntry::Line < ApplicationRecord
  NotUndoable = Class.new(StandardError)

  belongs_to :list, class_name: "NumberEntry", foreign_key: :number_entry_id, inverse_of: :lines
  belongs_to :account
  belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id
  belongs_to :lot, optional: true

  scope :kept, -> { where(undone_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # Its copies can come back out while it isn't undone and its lot exists, is the account's, and holds at least as
  # many (decision 5, AC-3.4). A lot edited without a merge still counts: the copies come out of it as it now is
  # (AC-3.5). The list preloads the lots, so showing it asks this per line without a query.
  def undoable? = undone_at.nil? && lot.present? && lot.account_id == account_id && lot.quantity >= quantity

  # Takes the line's copies out of its lot, removing the lot when none are left (AC-3.2, AC-3.3), and returns whether
  # the lot went. Raises NotUndoable when it was undone already or its copies changed (AC-3.4).
  def undo!
    transaction do
      reload
      raise NotUndoable unless undoable?

      lot = account.lots.find(lot_id) # the write goes through the account (multi-tenancy rule)
      removed = lot.quantity == quantity
      removed ? lot.destroy! : lot.update!(quantity: lot.quantity - quantity)
      update!(undone_at: Time.current)
      removed
    end
  end
end
