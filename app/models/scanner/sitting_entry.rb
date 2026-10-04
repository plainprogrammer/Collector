# One add recorded in a scanner sitting (spec 009 FR-2): the printing, the finish as tapped, the lot the copy went into
# and the page's reading key. The lot reference clears itself (on delete set null) when that lot is removed or merged
# away by an edit, which is how an entry knows it changed in the collection (AC-3.6).
class Scanner::SittingEntry < ApplicationRecord
  NotUndoable = Class.new(StandardError)

  belongs_to :sitting, class_name: "Scanner::Sitting", foreign_key: :scanner_sitting_id, inverse_of: :entries
  belongs_to :account
  belongs_to :printing, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id
  belongs_to :lot, optional: true

  scope :kept, -> { where(undone_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # :added, :undone, or :changed once its lot was removed or merged away (AC-1.5, AC-3.6).
  def state
    if undone_at then :undone
    elsif lot_id.nil? then :changed
    else :added
    end
  end

  # Takes this add's copy back out of the lot it went into, even if that lot was edited since (AC-4.1, AC-4.4), and
  # returns whether the lot went with it. Raises NotUndoable when it was undone already or its lot is gone (AC-4.2).
  def undo!
    transaction do
      reload
      raise NotUndoable, state.to_s unless state == :added

      lot = account.lots.find(lot_id)
      removed = lot.quantity <= 1
      removed ? lot.destroy! : lot.update!(quantity: lot.quantity - 1)
      update!(undone_at: Time.current)
      removed
    end
  end
end
