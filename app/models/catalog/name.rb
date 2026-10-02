# One name a catalog identity is known by (its full name, or a face name), normalised for the scanner's
# name index (spec 007 FR-5). Derived data: Catalog::NameIndex#rebuild replaces a type's rows in full.
class Catalog::Name < ApplicationRecord
  belongs_to :identity, class_name: "Catalog::Identity", foreign_key: :catalog_identity_id
end
