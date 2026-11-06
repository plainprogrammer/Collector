# Lets a scanner sitting hold a condition for its adds (spec 042 decision 4). The sitting is working state, so every existing
# sitting has none.
class AddConditionToScannerSittings < ActiveRecord::Migration[8.1]
  # SQLite copies a table to remove a column from it, and with foreign keys enforced the copy's DROP TABLE would cascade-delete
  # the sitting's entries. Rails turns enforcement off for the copy only outside a transaction, so this migration runs without
  # one, and each step is guarded so a run that stopped between steps is finished by the next
  # (db/migrate/20261105100001_add_location_to_scanner_sittings.rb).
  disable_ddl_transaction!

  def up
    add_column :scanner_sittings, :condition, :string unless column_exists?(:scanner_sittings, :condition) # a nullable ADD COLUMN copies no table
  end

  # The condition is working state, so a rollback drops it whatever it holds.
  def down
    remove_column :scanner_sittings, :condition if column_exists?(:scanner_sittings, :condition)
  end
end
