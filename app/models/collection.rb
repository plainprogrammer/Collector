# frozen_string_literal: true

# Collection model represents a distinct collecting domain for a user.
# Each collection has a 1:1 relationship with a Catalog that defines
# the authoritative source for item identification.
#
# Examples: "My MTG Collection", "My Comics", "Games Collection"
#
# Collections organize Items and can share StorageUnits with other collections
# through the CollectionStorageUnit join table.
class Collection < ApplicationRecord
  # Associations
  belongs_to :catalog
  has_many :collection_storage_units, dependent: :destroy
  has_many :storage_units, through: :collection_storage_units

  # Validations
  validates :name, presence: true
  validates :item_type, presence: true
  validates :catalog_id, uniqueness: true

  # Callbacks
  before_validation :generate_uuid, on: :create

  private

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end
end
