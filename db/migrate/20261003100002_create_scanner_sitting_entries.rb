# One add recorded in a scanner sitting (spec 009 FR-2): the printing, the finish as tapped, the lot the copy went into
# (cleared when that lot is removed or merged away, AC-3.6) and the page's reading key (one entry per key, AC-1.5).
class CreateScannerSittingEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :scanner_sitting_entries do |t|
      t.references :scanner_sitting, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :catalog_entry, null: false, foreign_key: true
      t.references :lot, foreign_key: { on_delete: :nullify }
      t.string :finish
      t.string :reading_key, null: false
      t.datetime :undone_at
      t.timestamps
      t.index %i[scanner_sitting_id reading_key], unique: true
    end
  end
end
