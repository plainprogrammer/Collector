# Gives every account the currency its prices are shown in (spec 038 decision 1). The next migration carries the instance's
# current currency to it; this step's default is USD on every instance, so schema.rb is the same everywhere.
# Without a transaction: SQLite copies the table to drop a column, and with foreign keys enforced the copy's DROP TABLE would
# run the ON DELETE actions of every table that points at accounts. Rails turns enforcement off for the copy only outside a
# transaction (see AddLocationToLots).
class AddCurrencyToAccounts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :accounts, :currency, :string, null: false, default: "USD" unless column_exists?(:accounts, :currency)
  end

  def down
    remove_column :accounts, :currency if column_exists?(:accounts, :currency)
  end
end
