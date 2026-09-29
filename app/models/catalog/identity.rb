# What several entries have in common: for MTG, one card across all its printings.
class Catalog::Identity < ApplicationRecord
  has_many :entries, class_name: "Catalog::Entry", foreign_key: :catalog_identity_id,
    inverse_of: :identity, dependent: :restrict_with_exception

  validates :collectible_type, :external_key, :name, :content_digest, presence: true
  validates :external_key, uniqueness: { scope: :collectible_type }

  def to_param = external_key
end
