class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items, id: :string do |t|
      t.string :collection_id, null: false
      t.string :storage_unit_id
      t.string :catalog_entry_type, null: false
      t.string :catalog_entry_id, null: false
      t.string :detail_type, null: false
      t.string :detail_id, null: false
      t.integer :quantity, default: 1, null: false
      t.decimal :acquisition_price, precision: 10, scale: 2
      t.date :acquisition_date
      t.text :notes

      t.timestamps
    end

    add_index :items, :collection_id
    add_index :items, :storage_unit_id
    add_index :items, [:catalog_entry_type, :catalog_entry_id]
    add_index :items, [:detail_type, :detail_id], unique: true
    add_foreign_key :items, :collections
    add_foreign_key :items, :storage_units
  end
end
