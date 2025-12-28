# frozen_string_literal: true

# CollectionStorageUnit is a join model that associates StorageUnits with Collections.
# This enables multi-collection storage scenarios where a single physical storage unit
# (e.g., a shelf) can hold items from multiple collections.
#
# Example: A shelf might contain both MTG binders and Comic boxes
class CollectionStorageUnit < ApplicationRecord
  # Associations
  belongs_to :collection
  belongs_to :storage_unit

  # Validations
  validates :storage_unit_id, uniqueness: { scope: :collection_id }

  # Callbacks
  before_validation :generate_uuid, on: :create

  private

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end
end
