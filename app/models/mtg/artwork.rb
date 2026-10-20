# One artwork's fingerprint (spec 011 AC-3.7): global catalog data keyed by Scryfall's illustration_id, with the printing
# whose image was fingerprinted and the digest of the settings it was made with. Written only by MTG::Art::Build.
class MTG::Artwork < ApplicationRecord
  belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id

  validates :illustration_id, presence: true, uniqueness: true
  validates :settings_digest, presence: true
  validates :fingerprint, length: { is: 128 }

  scope :current, -> { where(settings_digest: MTG::Art::Settings.digest) }
end
