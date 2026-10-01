# The scanner's card-name index (spec 007 FR-5, ADR 0003): every name a catalog identity is known by,
# normalised, with an FTS5 trigram index over the normalised name. Global, derived catalog data, filled
# by Catalog::Refresh; this migration only creates the tables, so it's safe on any prior version.
class CreateCatalogNames < ActiveRecord::Migration[8.1]
  FTS_OPTIONS = [ "normalized", "content='catalog_names'", "content_rowid='id'", "tokenize='trigram remove_diacritics 1'" ].freeze

  def up
    create_table :catalog_names do |t|
      t.string :collectible_type, null: false
      t.references :catalog_identity, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized, null: false
      t.index %i[collectible_type catalog_identity_id normalized], unique: true, name: "index_catalog_names_uniqueness"
      t.index %i[collectible_type normalized]
    end
    create_virtual_table :catalog_names_fts, :fts5, FTS_OPTIONS
  end

  def down
    drop_virtual_table :catalog_names_fts, :fts5, FTS_OPTIONS
    drop_table :catalog_names
  end
end
