class CreateBulkSelections < ActiveRecord::Migration[8.1]
  def change
    create_table :bulk_selections do |t|
      t.references :session, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :query, null: false, default: ""
      t.string :sort_key, null: false, default: ""
      t.boolean :all_matching, null: false, default: false
      t.timestamps
    end

    create_table :bulk_selection_marks do |t|
      t.references :bulk_selection, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :lot, null: false, foreign_key: { on_delete: :cascade }
      t.index %i[bulk_selection_id lot_id], unique: true
    end
  end
end
