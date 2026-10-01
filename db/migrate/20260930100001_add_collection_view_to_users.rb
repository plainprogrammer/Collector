class AddCollectionViewToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :collection_view, :string, null: false, default: "grid"
  end
end
