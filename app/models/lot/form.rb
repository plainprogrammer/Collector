# Parses the add/edit form's text fields into lot attributes with per-field errors (spec 004 AC-9.4).
class Lot::Form
  include ActiveModel::Model
  include ActiveModel::Attributes

  PRICE = /\A\d+(\.\d{1,2})?\z/

  attribute :quantity, :string, default: "1"
  attribute :finish, :string
  attribute :condition, :string
  attribute :price_paid, :string
  attr_accessor :entry

  validate :quantity_in_range, :price_well_formed, :finish_offered, :condition_known

  def self.from(lot)
    new(entry: lot.entry, quantity: lot.quantity.to_s, finish: lot.finish, condition: lot.condition, price_paid: lot.price_paid)
  end

  def vocabulary = Catalog.collecting_for(entry.collectible_type)

  def lot_attributes
    { quantity: parsed_quantity, finish: finish.presence, condition: condition.presence,
      price_paid_cents: price_paid.present? ? (BigDecimal(price_paid.strip) * 100).to_i : nil }
  end

  # Copies model errors (for example the 9,999 cap on a merge) onto the form's fields.
  def absorb(lot)
    lot.errors.each do |error|
      field = error.attribute == :price_paid_cents ? :price_paid : error.attribute
      errors.add(field, error.message) if attribute_names.include?(field.to_s)
    end
    self
  end

  private
    def parsed_quantity = Integer(quantity.to_s.strip, 10, exception: false)

    def quantity_in_range
      errors.add(:quantity, "must be a whole number from 1 to 9,999") unless parsed_quantity&.between?(1, Lot::MAX_QUANTITY)
    end

    def price_well_formed
      return if price_paid.blank? || price_paid.strip.match?(PRICE)

      errors.add(:price_paid, "must be a non-negative amount with at most two decimal places")
    end

    def finish_offered
      errors.add(:finish, "isn't available for this printing") if finish.present? && vocabulary.finishes_for(entry).exclude?(finish)
    end

    def condition_known
      errors.add(:condition, "isn't a known condition") if condition.present? && vocabulary.conditions.exclude?(condition)
    end
end
