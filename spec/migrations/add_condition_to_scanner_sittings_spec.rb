require "rails_helper"
require Rails.root.join("db/migrate/20261106200001_add_condition_to_scanner_sittings")

# Spec 042 AC-6.1, AC-6.2: the migration changes no sitting and loses no entry, going up and down, whatever the sitting
# holds. It runs outside a transaction (disable_ddl_transaction!), so the examples commit their rows (:committed empties the
# database around them). Down and up go through the Migrator (MigrationContext#run), which wraps a migration in a
# transaction unless it turns that off, exactly as db:rollback does (spec/migrations/add_location_to_scanner_sittings_spec.rb).
RSpec.describe AddConditionToScannerSittings, :backup, :committed, type: :model do
  let(:account) { create(:user).account }

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up unless Scanner::Sitting.connection.column_exists?(:scanner_sittings, :condition)
    Scanner::Sitting.reset_column_information
    Lot.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def migration = described_class.new

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down = context.run(:down, 2026_11_06_200001)

  def up = context.run(:up, 2026_11_06_200001)

  def connection = Scanner::Sitting.connection

  def sitting_rows = connection.select_rows("SELECT id, account_id, location_id, created_at, updated_at FROM scanner_sittings ORDER BY id")

  def entry_rows = connection.select_rows("SELECT id, scanner_sitting_id, account_id, catalog_entry_id, lot_id, finish, reading_key, undone_at FROM scanner_sitting_entries ORDER BY id")

  # The table copy of a rollback must keep the foreign keys (accounts cascade, locations nullify) and the unique account index.
  def expect_table_intact
    keys = connection.foreign_keys(:scanner_sittings)
    expect(keys.find { |key| key.to_table == "locations" }).to have_attributes(on_delete: :nullify)
    expect(keys.find { |key| key.to_table == "accounts" }).to have_attributes(on_delete: :cascade)
    expect(connection.index_exists?(:scanner_sittings, :account_id, unique: true)).to be(true)
    expect(connection.index_exists?(:scanner_sittings, :location_id)).to be(true)
  end

  def fill
    lot = owned_printing("Opt", account:, quantity: 2, finish: "foil")
    Scanner::Sitting.add!(account:, printing: lot.entry, finish: "foil", reading_key: SecureRandom.hex(16))
    Scanner::Sitting.add!(account:, printing: lot.entry, finish: "foil", reading_key: SecureRandom.hex(16)).entry.undo!
    connection.execute("UPDATE scanner_sittings SET location_id = #{create(:location, account:).id}") # Safe: an integer id
  end

  it "turns the migration's transaction off, so a rollback rebuilds the sittings with foreign keys off" do
    expect(described_class.disable_ddl_transaction).to be(true)
  end

  it "keeps every sitting, its place and every entry going down and up, and leaves no sitting a condition (AC-6.1)", :aggregate_failures do
    fill
    before = [ sitting_rows, entry_rows ]
    expect(entry_rows.map { |row| row[4] }.compact).not_to be_empty
    expect(before.first.map { |row| row[2] }).to all(be_present)

    down
    expect(connection.column_exists?(:scanner_sittings, :condition)).to be(false)
    expect([ sitting_rows, entry_rows ]).to eq(before)
    expect_table_intact

    up
    expect(connection.column_exists?(:scanner_sittings, :condition)).to be(true)
    expect([ sitting_rows, entry_rows ]).to eq(before)
    expect_table_intact
    expect(connection.select_values("SELECT condition FROM scanner_sittings")).to all(be_nil)
  end

  it "goes down while a sitting holds a condition, keeping the sitting, its place and its entries (AC-6.2)", :aggregate_failures do
    fill
    connection.execute("UPDATE scanner_sittings SET condition = 'near_mint'")
    before = [ sitting_rows, entry_rows ]

    down
    expect(connection.column_exists?(:scanner_sittings, :condition)).to be(false)
    expect([ sitting_rows, entry_rows ]).to eq(before)
    expect_table_intact
  end

  it "runs twice without harm, the guard skipping a column that is already there", :aggregate_failures do
    expect { migration.migrate(:up) }.not_to raise_error
    expect(connection.columns(:scanner_sittings).count { |column| column.name == "condition" }).to eq(1)
  end
end
