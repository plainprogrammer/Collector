require "rails_helper"
require Rails.root.join("db/migrate/20261105100001_add_location_to_scanner_sittings")

# Spec 040 AC-6.0: the migration changes no sitting and loses no entry, going down and up. It runs outside a transaction
# (disable_ddl_transaction!), so the examples commit their rows (:committed empties the database around them). Down and up
# go through the Migrator (MigrationContext#run), which wraps a migration in a transaction unless it turns that off, exactly
# as db:rollback does (spec/migrations/add_location_to_lots_spec.rb).
RSpec.describe AddLocationToScannerSittings, :backup, :committed, type: :model do
  let(:account) { create(:user).account }

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up unless Scanner::Sitting.connection.column_exists?(:scanner_sittings, :location_id)
    Scanner::Sitting.reset_column_information
    Lot.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def migration = described_class.new

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down = context.run(:down, 2026_11_05_100001)

  def up = context.run(:up, 2026_11_05_100001)

  def connection = Scanner::Sitting.connection

  def sitting_rows = connection.select_rows("SELECT id, account_id, created_at, updated_at FROM scanner_sittings ORDER BY id")

  def entry_rows = connection.select_rows("SELECT id, scanner_sitting_id, account_id, catalog_entry_id, lot_id, finish, reading_key, undone_at FROM scanner_sitting_entries ORDER BY id")

  def fill
    lot = owned_printing("Opt", account:, quantity: 2, finish: "foil")
    Scanner::Sitting.add!(account:, printing: lot.entry, finish: "foil", reading_key: SecureRandom.hex(16))
    Scanner::Sitting.add!(account:, printing: lot.entry, finish: "foil", reading_key: SecureRandom.hex(16)).entry.undo!
  end

  it "turns the migration's transaction off, so a rollback rebuilds the sittings with foreign keys off" do
    expect(described_class.disable_ddl_transaction).to be(true)
  end

  it "keeps every sitting and entry going down and up, and leaves every sitting with no place", :aggregate_failures do
    fill
    before = [ sitting_rows, entry_rows ]
    expect(entry_rows.map { |row| row[4] }.compact).not_to be_empty

    down
    expect(connection.column_exists?(:scanner_sittings, :location_id)).to be(false)
    expect([ sitting_rows, entry_rows ]).to eq(before)

    up
    expect(connection.column_exists?(:scanner_sittings, :location_id)).to be(true)
    expect([ sitting_rows, entry_rows ]).to eq(before)
    expect(connection.select_values("SELECT location_id FROM scanner_sittings")).to all(be_nil)
  end

  it "goes down while a sitting holds a place, since the place is working state", :aggregate_failures do
    fill
    connection.execute("UPDATE scanner_sittings SET location_id = #{create(:location, account:).id}") # Safe: an integer id
    before = entry_rows

    down
    expect(connection.column_exists?(:scanner_sittings, :location_id)).to be(false)
    expect(entry_rows).to eq(before)
  end

  it "nulls a sitting's place when its location is removed" do
    location = create(:location, account:)
    fill
    connection.execute("UPDATE scanner_sittings SET location_id = #{location.id}") # Safe: an integer id
    connection.execute("DELETE FROM locations WHERE id = #{location.id}") # Safe: an integer id
    expect(connection.select_values("SELECT location_id FROM scanner_sittings")).to eq([ nil ])
  end

  it "finishes a run that stopped between its two steps" do
    connection.remove_index :scanner_sittings, :location_id # the state a crash between ADD COLUMN and CREATE INDEX leaves
    migration.migrate(:up)
    expect([ connection.column_exists?(:scanner_sittings, :location_id), connection.index_exists?(:scanner_sittings, :location_id) ]).to eq([ true, true ])
  end
end
