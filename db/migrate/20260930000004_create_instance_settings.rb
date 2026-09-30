class CreateInstanceSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :instance_settings do |t|
      t.boolean :sign_up_open, null: false, default: false
      t.timestamps
    end
  end
end
