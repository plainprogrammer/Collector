# MTG-specific attributes of a printing (a Catalog::Entry).
class MTG::Printing < ApplicationRecord
  belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id

  validates :rarity, :layout, :scryfall_uri, presence: true
  validates :catalog_entry_id, uniqueness: true
end
