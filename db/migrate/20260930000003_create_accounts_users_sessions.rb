class CreateAccountsUsersSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, &:timestamps

    create_table :users do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :email_address, null: false, index: { unique: true }
      t.string :password_digest, null: false
      t.boolean :admin, null: false, default: false
      t.timestamps
    end

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
  end
end
