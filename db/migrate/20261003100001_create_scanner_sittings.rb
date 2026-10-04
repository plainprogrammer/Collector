# The account's open run of scanner adds (spec 009 FR-2): at most one per account.
class CreateScannerSittings < ActiveRecord::Migration[8.1]
  def change
    create_table :scanner_sittings do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.timestamps
    end
  end
end
