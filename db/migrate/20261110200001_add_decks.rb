# Adds decks to locations (spec 062 decisions 1 and 3, ADR 0028). A deck is a location of kind "deck" plus a row of
# `decks`; a zone is a location of kind "deck_zone" whose parent is the deck. Every existing location becomes a place.
class AddDecks < ActiveRecord::Migration[8.1]
  # Same reason as AddLocationToLots: SQLite copies a table to add a constraint to it or drop a column, and with foreign
  # keys enforced inside a transaction the copy's DROP TABLE would run lots.location_id's RESTRICT and
  # scanner_sittings.location_id's SET NULL. Rails turns enforcement off for a copy only outside a transaction, so this
  # migration runs without one and every step is guarded: a run that stopped part way is finished by the next boot.
  disable_ddl_transaction!

  TOP_LEVEL = "index_locations_on_account_id_and_name_key_top_level".freeze
  ZONES = "index_locations_on_parent_id_and_name_key".freeze
  OLD = "index_locations_on_account_id_and_name_key".freeze
  CHECKS = %w[locations_kind_known locations_parent_matches_kind locations_zone_matches_kind].freeze

  def up
    # ADD COLUMN copies no table. A CHECK stated on the column is tested against every existing row (all places) and
    # kept by the schema dump when it is named; REFERENCES is accepted because the default is NULL.
    unless column_exists?(:locations, :kind)
      execute "ALTER TABLE locations ADD COLUMN kind varchar NOT NULL DEFAULT 'place' " \
              "CONSTRAINT locations_kind_known CHECK (kind IN ('place', 'deck', 'deck_zone'))"
    end
    unless column_exists?(:locations, :parent_id)
      execute "ALTER TABLE locations ADD COLUMN parent_id integer REFERENCES locations (id) ON DELETE CASCADE " \
              "CONSTRAINT locations_parent_matches_kind CHECK ((kind = 'deck_zone') = (parent_id IS NOT NULL))"
    end
    unless column_exists?(:locations, :zone)
      execute "ALTER TABLE locations ADD COLUMN zone varchar " \
              "CONSTRAINT locations_zone_matches_kind CHECK ((kind = 'deck_zone') = (zone IS NOT NULL))"
    end
    add_index :locations, :parent_id unless index_exists?(:locations, :parent_id)
    # The new guards exist before the old one goes, so no name is ever unguarded.
    unless index_name_exists?(:locations, TOP_LEVEL)
      add_index :locations, %i[account_id name_key], unique: true, where: "parent_id IS NULL", name: TOP_LEVEL
    end
    unless index_name_exists?(:locations, ZONES)
      add_index :locations, %i[parent_id name_key], unique: true, where: "parent_id IS NOT NULL", name: ZONES
    end
    remove_index :locations, name: OLD if index_name_exists?(:locations, OLD)
    create_table :decks, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :location, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :collectible_type, null: false
      t.string :format, null: false
      t.timestamps
    end
  end

  def down
    decks = select_value("SELECT COUNT(*) FROM locations WHERE kind <> 'place'").to_i if column_exists?(:locations, :kind)
    decks = [ decks.to_i, (table_exists?(:decks) ? select_value("SELECT COUNT(*) FROM decks").to_i : 0) ].max
    if decks.positive?
      raise ActiveRecord::IrreversibleMigration,
            "#{decks} #{decks == 1 ? "deck exists" : "decks exist"}; remove #{decks == 1 ? "it" : "them"} before rolling back"
    end

    drop_table :decks, if_exists: true
    add_index :locations, %i[account_id name_key], unique: true, name: OLD unless index_name_exists?(:locations, OLD)
    remove_index :locations, name: TOP_LEVEL if index_name_exists?(:locations, TOP_LEVEL)
    remove_index :locations, name: ZONES if index_name_exists?(:locations, ZONES)
    remove_index :locations, :parent_id if index_exists?(:locations, :parent_id)
    # The checks name the columns they test, so they go before the columns do.
    CHECKS.each do |name|
      remove_check_constraint :locations, name: name if check_constraint_exists?(:locations, name: name)
    end
    remove_column :locations, :zone if column_exists?(:locations, :zone)
    remove_column :locations, :parent_id if column_exists?(:locations, :parent_id)
    remove_column :locations, :kind if column_exists?(:locations, :kind)
  end
end
