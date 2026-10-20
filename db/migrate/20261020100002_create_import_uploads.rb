class CreateImportUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :import_uploads do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :fingerprint, null: false
      t.datetime :expires_at, null: false
      t.timestamps
      t.index :expires_at
    end
  end
end
