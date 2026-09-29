class Catalog::Set < ApplicationRecord
  has_many :entries, class_name: "Catalog::Entry", foreign_key: :catalog_set_id,
    inverse_of: :set, dependent: :restrict_with_exception

  validates :collectible_type, :code, :name, :content_digest, presence: true
  validates :code, uniqueness: { scope: :collectible_type }
end
