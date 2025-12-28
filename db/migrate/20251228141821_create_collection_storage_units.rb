class CreateCollectionStorageUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_storage_units, id: :string do |t|
      t.string :collection_id, null: false
      t.string :storage_unit_id, null: false

      t.timestamps
    end

    add_index :collection_storage_units, [:collection_id, :storage_unit_id], unique: true, name: "index_csu_on_collection_and_storage_unit"
    add_foreign_key :collection_storage_units, :collections
    add_foreign_key :collection_storage_units, :storage_units
  end
end
