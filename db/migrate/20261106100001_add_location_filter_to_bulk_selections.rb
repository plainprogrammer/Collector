# The bulk selection's location filter, beside its name filter and sort (spec 037 decision 5): "" (all locations), "none" or
# a location's id. Working state, left out of the export. Every existing row was made under all locations, which the default
# says, so nothing is backfilled.
class AddLocationFilterToBulkSelections < ActiveRecord::Migration[8.1]
  def up
    add_column :bulk_selections, :location_filter, :string, default: "", null: false unless column_exists?(:bulk_selections, :location_filter)
  end

  # SQLite drops a plain column in place (3.35+), so the table isn't copied and its marks aren't touched.
  def down
    execute "ALTER TABLE bulk_selections DROP COLUMN location_filter" if column_exists?(:bulk_selections, :location_filter)
  end
end
