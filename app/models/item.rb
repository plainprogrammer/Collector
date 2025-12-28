# frozen_string_literal: true

# Item model represents a specific instance (or group of identical instances)
# of a collectible within a Collection.
#
# Items reference their catalog entry (what card/comic/item this is) via polymorphic
# catalog_entry association. Physical-instance attributes are stored in delegated
# type models (MTGCardItemDetail for MTG cards).
#
# Quantity defaults to 1 (one row per physical card). The quantity field exists for
# bulk/unsorted storage scenarios where tracking individual cards isn't practical.
class Item < ApplicationRecord
  # Associations
  belongs_to :collection
  belongs_to :storage_unit, optional: true
  belongs_to :catalog_entry, polymorphic: true
  delegated_type :detail, types: %w[MTGCardItemDetail], dependent: :destroy

  # Validations
  validates :quantity, numericality: { greater_than: 0 }
  validate :storage_unit_belongs_to_collection, if: :storage_unit_id?

  # Callbacks
  before_validation :generate_uuid, on: :create

  private

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end

  def storage_unit_belongs_to_collection
    return unless storage_unit && collection

    unless storage_unit.collections.include?(collection)
      errors.add(:storage_unit, "must belong to the item's collection")
    end
  end
end
