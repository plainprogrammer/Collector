class CreateMTGCardItemDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :mtg_card_item_details, id: :string do |t|
      t.string :condition, default: "NM", null: false
      t.string :finish, default: "nonfoil", null: false
      t.string :language, default: "EN", null: false
      t.boolean :signed, default: false, null: false
      t.boolean :altered, default: false, null: false
      t.boolean :graded, default: false, null: false
      t.string :grading_service
      t.string :grade

      t.timestamps
    end
  end
end
