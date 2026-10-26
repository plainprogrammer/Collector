# Puts a lot in one of its account's locations, or in none (spec 032 decision 1, ADR 0025). The lot's existing values and
# its key are untouched: every lot is unplaced, and an unplaced lot's key is what it was.
class AddLocationToLots < ActiveRecord::Migration[8.1]
  # SQLite copies a table to remove a column from it or to add a constraint to it, and with foreign keys enforced the copy's
  # DROP TABLE would run the ON DELETE actions of the tables that point at lots (marks, number-entry lines, scanner
  # entries). Rails turns enforcement off for the copy only outside a transaction (sqlite3_adapter.rb,
  # disable_referential_integrity), so this migration runs without one. Each step is guarded, so a run that stopped between
  # them is finished by the next.
  disable_ddl_transaction!

  def up
    # ADD COLUMN copies no table; SQLite accepts REFERENCES on it when the default is NULL, which is every lot's value.
    execute "ALTER TABLE lots ADD COLUMN location_id integer REFERENCES locations (id) ON DELETE RESTRICT" unless column_exists?(:lots, :location_id)
    add_index :lots, :location_id unless index_exists?(:lots, :location_id)
  end

  def down
    placed = select_value("SELECT COUNT(*) FROM lots WHERE location_id IS NOT NULL").to_i
    raise ActiveRecord::IrreversibleMigration, "#{placed} #{placed == 1 ? "lot is" : "lots are"} in a location; move them out before rolling back" if placed.positive?

    remove_index :lots, :location_id if index_exists?(:lots, :location_id)
    remove_column :lots, :location_id if column_exists?(:lots, :location_id)
  end
end
