class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :name, null: false
      t.string :name_key, null: false
      t.timestamps
      t.index %i[account_id name_key], unique: true
      t.check_constraint "length(name) BETWEEN 1 AND 60", name: "locations_name_length"
      t.check_constraint "length(name_key) >= 1", name: "locations_name_key_present"
    end
  end
end
