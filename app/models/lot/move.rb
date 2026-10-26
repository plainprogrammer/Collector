# Moves some or all of a lot's copies to another location, or to none (spec 032 Story 3, decision 4). It is the Move copies
# form and the move: copies of one identity are one lot, so moving some is a split and moving all to a place that has the
# identity is a merge. All or nothing. Collectible-agnostic.
class Lot::Move
  include ActiveModel::Model
  include ActiveModel::Attributes

  CHOOSE = "Choose from 1 to %d copies.".freeze
  ALREADY_THERE = "Those copies are already there.".freeze

  attribute :copies, :string
  attr_reader :lot, :to

  validate :copies_in_range, :somewhere_else

  # +to+ is a Location of the lot's account, or nil for none.
  def initialize(lot:, to:, copies: lot.quantity.to_s)
    super(copies:)
    @lot, @to = lot, to
  end

  def count = Integer(copies.to_s.strip, 10, exception: false)

  def location_id = to&.id.to_s # the To select's value

  # Returns the lot that now holds the copies. Raises ActiveRecord::RecordInvalid, with the reason on this form, and changes
  # nothing, when the copies or the destination are wrong or the result would pass the cap.
  def call!
    # SQLite opens the transaction IMMEDIATE, so this is the only writer. The lot is read again under that lock and the move is
    # judged against it: the form was built from a lot read before the lock, and a second submit of it (two tabs, a double
    # click) would otherwise pass the range and "already there" checks on a quantity and a place that no longer hold, and
    # create or lose copies (plan review round 2, M1). The twin below is read under the same lock; the unique index on lot_key
    # stays the backstop. A lot deleted meanwhile raises RecordNotFound (404).
    Lot.transaction do
      lot.reload
      raise ActiveRecord::RecordInvalid, self unless valid?

      count == lot.quantity ? move_whole : split
    end
  rescue ActiveRecord::RecordInvalid => error
    raise if error.record.equal?(self)

    lot.reload # the transaction rolled back; the lot in memory may still hold the unsaved change
    errors.add(:copies, Lot::FULL_MESSAGE) if error.record.errors.of_kind?(:quantity, :too_many)
    raise ActiveRecord::RecordInvalid, self
  end

  private
    def move_whole
      other = twin
      return lot.tap { |moved| moved.update!(location: to) } unless other

      other.update!(quantity: other.quantity + lot.quantity) # the destination's lot survives, as Lot#revise! does (P6)
      lot.destroy!
      other
    end

    def split
      other = twin
      lot.update!(quantity: lot.quantity - count)
      return other.tap { |held| held.update!(quantity: held.quantity + count) } if other

      lot.account.lots.create!(entry: lot.entry, finish: lot.finish, condition: lot.condition, price_paid_cents: lot.price_paid_cents,
        location: to, quantity: count)
    end

    # The account's lot with this lot's identity in the destination, if there is one.
    def twin
      lot.account.lots.find_by(catalog_entry_id: lot.catalog_entry_id,
        lot_key: Lot.key_for(lot.finish, lot.condition, lot.price_paid_cents, to&.id))
    end

    def copies_in_range
      errors.add(:copies, format(CHOOSE, lot.quantity)) unless count&.between?(1, lot.quantity)
    end

    def somewhere_else
      errors.add(:location_id, ALREADY_THERE) if to&.id == lot.location_id
    end
end
