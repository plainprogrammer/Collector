# Lets a scanner sitting hold a place for its adds (spec 040 decision 2). The sitting is working state, so every existing
# sitting has none, and removing a location sets a sitting's place to none.
class AddLocationToScannerSittings < ActiveRecord::Migration[8.1]
  # SQLite copies a table to remove a column from it or to add a constraint to it, and with foreign keys enforced the copy's
  # DROP TABLE would cascade-delete the sitting's entries. Rails turns enforcement off for the copy only outside a
  # transaction, so this migration runs without one, and each step is guarded so a run that stopped between them is
  # finished by the next (db/migrate/20261023100001_add_location_to_lots.rb).
  disable_ddl_transaction!

  def up
    # ADD COLUMN copies no table; SQLite accepts REFERENCES on it when the default is NULL, which is every sitting's value.
    execute "ALTER TABLE scanner_sittings ADD COLUMN location_id integer REFERENCES locations (id) ON DELETE SET NULL" unless column_exists?(:scanner_sittings, :location_id)
    add_index :scanner_sittings, :location_id unless index_exists?(:scanner_sittings, :location_id)
  end

  # The place is working state, so a rollback drops it whatever it holds.
  def down
    remove_index :scanner_sittings, :location_id if index_exists?(:scanner_sittings, :location_id)
    remove_column :scanner_sittings, :location_id if column_exists?(:scanner_sittings, :location_id)
  end
end
