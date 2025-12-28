class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections, id: :string do |t|
      t.string :name, null: false
      t.text :description
      t.string :item_type, null: false
      t.string :catalog_id, null: false

      t.timestamps
    end

    add_index :collections, :catalog_id, unique: true
    add_foreign_key :collections, :catalogs
  end
end
