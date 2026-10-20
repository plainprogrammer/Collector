# The account's list of number entry adds (spec 026 decision 6): at most one per account.
class CreateNumberEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :number_entries do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.timestamps
    end
  end
end
