class CreateMTGExtension < ActiveRecord::Migration[8.1]
  def change
    create_table :mtg_printings do |t|
      t.references :catalog_entry, null: false, foreign_key: true, index: { unique: true }
      t.string :rarity, null: false
      t.json :finishes, null: false, default: []
      t.string :layout, null: false
      t.string :frame
      t.string :border_color
      t.string :security_stamp
      t.json :variant_tags, null: false, default: []
      t.json :legalities, null: false, default: {}
      t.json :external_ids, null: false, default: {}
      t.json :faces, null: false, default: []
      t.string :scryfall_uri, null: false
      t.timestamps
    end

    create_table :mtg_cards do |t|
      t.references :catalog_identity, null: false, foreign_key: true, index: { unique: true }
      t.string :mana_cost
      t.string :type_line
      t.text :oracle_text
      t.json :colors, null: false, default: []
      t.json :color_identity, null: false, default: []
      t.json :keywords, null: false, default: []
      t.timestamps
    end
  end
end
