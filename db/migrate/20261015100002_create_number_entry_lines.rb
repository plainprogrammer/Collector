# One added line of number entry (spec 026 FR-3): the entry, the quantity and finish, the lot the copies went into
# (cleared when that lot is removed or merged away, decision 5) and the form's line key (one line per key, decision 10).
class CreateNumberEntryLines < ActiveRecord::Migration[8.1]
  def change
    create_table :number_entry_lines do |t|
      t.references :number_entry, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :catalog_entry, null: false, foreign_key: true
      t.references :lot, foreign_key: { on_delete: :nullify }
      t.integer :quantity, null: false
      t.string :finish
      t.string :line_key, null: false
      t.datetime :undone_at
      t.timestamps
      t.index %i[number_entry_id line_key], unique: true
      t.check_constraint "quantity BETWEEN 1 AND 9999", name: "number_entry_lines_quantity_range"
    end
  end
end
