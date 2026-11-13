# The prices database's tables (spec 081 decision 2; ADR 0029). current_prices and price_changes are WITHOUT ROWID: their
# primary key is the table, stored once (decision 3, ruled 2026-11-13).
#
# WARNING for the next migration of current_prices or price_changes: on SQLite, Rails changes a column
# (change_column, remove_column, rename_column, change_column_null, add_check_constraint and the like) by copying the
# table into a new one built WITHOUT its options, so WITHOUT ROWID is silently lost. Write a new migration that creates
# the new table with options: "WITHOUT ROWID", copies the rows and swaps the names. spec/prices_schema_spec.rb fails
# on either table without the option. Adding a nullable column with add_column is safe (SQLite's ALTER TABLE ADD COLUMN).
#
# No index beyond the primary key on those two tables: an index on price_source_id or price_series_id would store most
# of the key again (decision 2, an exception to "index every foreign key" the maintainer accepted on 2026-11-13).
class CreatePriceTables < ActiveRecord::Migration[8.1]
  def change
    create_table :price_sources do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :attribution, null: false
      t.string :attribution_url
      t.boolean :hosted_paid_allowed, null: false, default: false
      t.timestamps
      t.index :key, unique: true
      t.check_constraint "length(key) >= 1", name: "price_sources_key_present"
      t.check_constraint "length(name) >= 1", name: "price_sources_name_present"
      t.check_constraint "length(attribution) >= 1", name: "price_sources_attribution_present"
    end

    create_table :price_series do |t|
      t.string :finish, null: false
      t.string :currency, null: false
      t.string :kind, null: false
      t.timestamps
      t.index %i[finish currency kind], unique: true
      t.check_constraint "currency GLOB '[A-Z][A-Z][A-Z]'", name: "price_series_currency_code"
    end

    create_table :current_prices, primary_key: %i[catalog_entry_id price_source_id price_series_id], options: "WITHOUT ROWID" do |t|
      t.integer :catalog_entry_id, null: false
      t.references :price_source, null: false, index: false, foreign_key: { on_delete: :restrict }
      t.references :price_series, null: false, index: false, foreign_key: { to_table: :price_series, on_delete: :restrict }
      t.integer :cents, null: false
      t.date :reported_on, null: false
      t.date :changed_on, null: false
      t.check_constraint "cents >= 0", name: "current_prices_cents_non_negative"
    end

    create_table :price_changes, primary_key: %i[catalog_entry_id price_source_id price_series_id recorded_on], options: "WITHOUT ROWID" do |t|
      t.integer :catalog_entry_id, null: false
      t.references :price_source, null: false, index: false, foreign_key: { on_delete: :restrict }
      t.references :price_series, null: false, index: false, foreign_key: { to_table: :price_series, on_delete: :restrict }
      t.date :recorded_on, null: false
      t.integer :cents
      t.check_constraint "cents IS NULL OR cents >= 0", name: "price_changes_cents_non_negative"
    end

    create_table :price_refresh_runs do |t|
      t.references :price_source, null: false, index: false, foreign_key: { on_delete: :restrict }
      t.date :run_on, null: false
      t.string :source_version
      t.string :status, null: false
      t.text :error
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
      t.index %i[price_source_id run_on]
      t.check_constraint "status IN ('running', 'finished', 'skipped', 'failed')", name: "price_refresh_runs_status_known"
    end
  end
end
