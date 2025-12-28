class CreateStorageUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :storage_units, id: :string do |t|
      t.string :name, null: false
      t.string :unit_type, null: false
      t.text :notes
      t.string :parent_id

      t.timestamps
    end

    add_index :storage_units, :parent_id
    add_foreign_key :storage_units, :storage_units, column: :parent_id
  end
end
