# frozen_string_literal: true

# StorageUnit model represents physical or logical containers for items.
# Supports arbitrary nesting through self-referential parent-child relationships.
# Can be shared across multiple Collections via CollectionStorageUnit join table.
#
# Unit types: shelf, box, binder, deck
#
# Examples:
# - Root: "Main Shelf" (parent_id: nil)
# - Nested: "Binder A" → parent: "Main Shelf"
# - Deep: "Deck Box 1" → parent: "Binder A" → parent: "Main Shelf"
class StorageUnit < ApplicationRecord
  # Associations
  belongs_to :parent, class_name: "StorageUnit", optional: true
  has_many :children, class_name: "StorageUnit", foreign_key: :parent_id, dependent: :restrict_with_error
  has_many :collection_storage_units, dependent: :destroy
  has_many :collections, through: :collection_storage_units

  # Validations
  validates :name, presence: true
  validates :unit_type, presence: true

  # Callbacks
  before_validation :generate_uuid, on: :create

  private

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end
end
