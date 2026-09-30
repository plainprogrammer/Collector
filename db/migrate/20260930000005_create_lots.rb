class CreateLots < ActiveRecord::Migration[8.1]
  def change
    create_table :lots do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.references :catalog_entry, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.string :finish
      t.string :condition
      t.integer :price_paid_cents
      t.string :lot_key, null: false
      t.timestamps
      t.index %i[account_id catalog_entry_id lot_key], unique: true
      t.check_constraint "quantity BETWEEN 1 AND 9999", name: "lots_quantity_range"
      t.check_constraint "price_paid_cents IS NULL OR price_paid_cents >= 0", name: "lots_price_non_negative"
    end
  end
end
