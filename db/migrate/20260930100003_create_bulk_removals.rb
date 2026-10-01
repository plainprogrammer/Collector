class CreateBulkRemovals < ActiveRecord::Migration[8.1]
  def change
    create_table :bulk_removals do |t|
      t.references :session, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.integer :copies, null: false
      t.json :lots_data
      t.timestamps
      t.index :session_id, unique: true, where: "lots_data IS NOT NULL", name: "index_bulk_removals_undoable_per_session"
    end
  end
end
