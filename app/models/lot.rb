# Copies of one catalog entry with the same finish, condition and price paid, owned by an account
# (spec 004 FR-6). Finish and condition are values the collectible's vocabulary defines
# (Catalog.collecting_for); the core doesn't interpret them.
class Lot < ApplicationRecord
  MAX_QUANTITY = 9_999
  FULL_MESSAGE = "One lot can hold at most 9,999 copies.".freeze

  belongs_to :account
  belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id

  normalizes :finish, :condition, with: ->(value) { value.presence }

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :price_paid_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :quantity_within_cap, :finish_offered, :condition_known

  before_validation { self.lot_key = self.class.key_for(finish, condition, price_paid_cents) }

  def self.key_for(finish, condition, price_paid_cents) = [ finish, condition, price_paid_cents ].join("|")

  # Adds copies, merging into the lot with the same identity (spec 004 AC-7.4, AC-9.3). SQLite
  # IMMEDIATE transactions serialise writers; the unique index backs that up, and a lost race
  # retries once so it merges instead of failing (AC-12.5).
  def self.add!(account:, entry:, quantity: 1, finish: nil, condition: nil, price_paid_cents: nil)
    retried = false
    begin
      transaction do
        lot = find_or_initialize_by(account:, entry:, lot_key: key_for(finish.presence, condition.presence, price_paid_cents))
        lot.assign_attributes(finish:, condition:, price_paid_cents:, quantity: lot.quantity.to_i + quantity.to_i)
        lot.save!
        lot
      end
    rescue ActiveRecord::RecordNotUnique
      raise if retried

      retried = true
      retry
    end
  end

  def self.owned_quantities(account, entry_ids)
    account.lots.where(catalog_entry_id: entry_ids).group(:catalog_entry_id).sum(:quantity)
  end

  # Edits this lot. If the new identity matches another lot of the same printing, the two merge and
  # the other survives with the summed quantity (spec 004 AC-10.2). Errors always end up on self.
  def revise!(attributes)
    transaction do
      assign_attributes(attributes)
      validate!
      other = self.class.where(account_id:, catalog_entry_id:, lot_key:).where.not(id:).first
      next tap(&:save!) unless other

      other.quantity += quantity
      other.save!
      destroy!
      other
    end
  rescue ActiveRecord::RecordInvalid => error
    errors.merge!(error.record.errors) unless error.record == self
    raise ActiveRecord::RecordInvalid, self
  end

  def price_paid = price_paid_cents && format("%.2f", price_paid_cents / 100r)

  def vocabulary = Catalog.collecting_for(entry.collectible_type)

  private
    def quantity_within_cap
      errors.add(:quantity, :too_many, message: FULL_MESSAGE) if quantity.to_i > MAX_QUANTITY
    end

    def finish_offered
      errors.add(:finish, "isn't available for this printing") if finish && vocabulary.finishes_for(entry).exclude?(finish)
    end

    def condition_known
      errors.add(:condition, "isn't a known condition") if condition && vocabulary.conditions.exclude?(condition)
    end
end
