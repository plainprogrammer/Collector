# Spec 011 AC-2.1, AC-2.2: each printing's artwork (Scryfall's front-face illustration_id), filled by the next applied
# refresh (the extension's digest changes, so every printing is rewritten once). Nullable: some printings have none.
class AddIllustrationIdToMTGPrintings < ActiveRecord::Migration[8.1]
  def change
    add_column :mtg_printings, :illustration_id, :string
    add_index :mtg_printings, :illustration_id
  end
end
