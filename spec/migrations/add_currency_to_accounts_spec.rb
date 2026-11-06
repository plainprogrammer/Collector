require "rails_helper"
require Rails.root.join("db/migrate/20261103100001_add_currency_to_accounts")

# Spec 038 AC-4.5: the schema step adds the column and its rollback removes it, leaving every other column and row. It runs
# outside a transaction (disable_ddl_transaction!), so the examples commit their rows (:committed empties the database around
# them), and down and up go through the Migrator, as db:rollback does (see add_location_to_lots_spec.rb).
RSpec.describe AddCurrencyToAccounts, :backup, :committed, type: :model do
  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up unless Account.connection.column_exists?(:accounts, :currency)
    Account.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down = context.run(:down, 2026_11_03_100001)

  def up = context.run(:up, 2026_11_03_100001)

  def account_rows = Account.connection.select_rows("SELECT id, created_at, updated_at FROM accounts ORDER BY id")

  def other_columns = Account.connection.columns(:accounts).reject { |column| column.name == "currency" }.map { |column| [ column.name, column.sql_type, column.null, column.default ] }

  it "turns the migration's transaction off, so a rollback rebuilds accounts with foreign keys off" do
    expect(described_class.disable_ddl_transaction).to be(true)
  end

  it "adds a NOT NULL column defaulting to USD", :aggregate_failures do
    column = Account.connection.columns(:accounts).find { |candidate| candidate.name == "currency" }
    expect([ column.null, column.default, column.sql_type ]).to eq([ false, "USD", "varchar" ])
  end

  it "keeps every account, its lots and every other column going down and up", :aggregate_failures do
    2.times { create(:lot, account: create(:user).account) }
    before = [ account_rows, other_columns, Lot.count ]

    down
    expect(Account.connection.column_exists?(:accounts, :currency)).to be(false)
    expect([ account_rows, other_columns, Lot.count ]).to eq(before)

    up
    expect(Account.connection.column_exists?(:accounts, :currency)).to be(true)
    expect([ account_rows, other_columns, Lot.count ]).to eq(before)
    expect(Account.connection.select_values("SELECT currency FROM accounts")).to all(eq("USD"))
  end
end
