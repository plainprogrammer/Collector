# MTG-specific attributes of a printing (a Catalog::Entry).
class MTG::Printing < ApplicationRecord
  belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id

  validates :rarity, :layout, :scryfall_uri, presence: true
  validates :catalog_entry_id, uniqueness: true

  # [identity id, face name] for each face of a multi-face printing among entries (split, adventure and
  # double-faced cards), whose name bar prints a face name rather than "Front // Back" (spec 007 FR-5).
  def self.face_names(entries)
    joins(:entry).merge(entries).where("json_array_length(mtg_printings.faces) > 1")
      .joins("JOIN json_each(mtg_printings.faces) AS face")
      .distinct.pluck("catalog_entries.catalog_identity_id", Arel.sql("json_extract(face.value, '$.name')"))
  end
end
