# One catalogued collectible as the source identifies it: for MTG, a printing.
class Catalog::Entry < ApplicationRecord
  PRIMARY_KIND = "card"

  belongs_to :set, class_name: "Catalog::Set", foreign_key: :catalog_set_id, inverse_of: :entries
  belongs_to :identity, class_name: "Catalog::Identity", foreign_key: :catalog_identity_id, inverse_of: :entries

  # The collectible-specific record (e.g. MTG::Printing); see .preload_extensions.
  attr_accessor :extension

  validates :collectible_type, :external_key, :number, :language, :name, :kind, :content_digest, presence: true
  validates :external_key, uniqueness: { scope: :collectible_type }

  def retired? = retired_at.present?

  def to_param = external_key
end
