# frozen_string_literal: true

class Catalog < ApplicationRecord
  # Associations
  has_one :collection, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true
  validates :source_type, presence: true, inclusion: { in: %w[mtgjson api custom] }

  # Callbacks
  before_validation :generate_uuid, on: :create

  # Returns the appropriate adapter instance for this catalog's source_type.
  #
  # @return [CatalogAdapter] Adapter instance for this catalog
  # @raise [NotImplementedError] If adapter for source_type is not yet implemented
  def adapter
    case source_type
    when "mtgjson"
      MTGJSONAdapter.new(self)
    when "api"
      raise NotImplementedError, "ApiAdapter not yet implemented. Will be added in future phase."
    when "custom"
      raise NotImplementedError, "CustomAdapter not yet implemented. Will be added in future phase."
    else
      raise ArgumentError, "Unknown catalog source_type: #{source_type}"
    end
  end

  private

  def generate_uuid
    self.id ||= SecureRandom.uuid
  end
end
