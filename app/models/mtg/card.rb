# MTG gameplay attributes of a card (a Catalog::Identity).
class MTG::Card < ApplicationRecord
  belongs_to :identity, class_name: "Catalog::Identity", foreign_key: :catalog_identity_id

  validates :catalog_identity_id, uniqueness: true
end
