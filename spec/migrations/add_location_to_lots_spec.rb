require "rails_helper"
require Rails.root.join("db/migrate/20261023100001_add_location_to_lots")

# Spec 032 AC-7.1: the migration changes no lot and breaks no pointer to a lot, going down and up. It runs outside a
# transaction (disable_ddl_transaction!), so the examples commit their rows (:committed empties the database around them).
# Down and up go through the Migrator (MigrationContext#run), which wraps a migration in a transaction unless it turns that
# off (migration.rb ddl_transaction), exactly as db:rollback does. Calling Migration#migrate would open none and so pass
# without disable_ddl_transaction!, the very line this spec guards (plan review M4).
RSpec.describe AddLocationToLots, :backup, :committed, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:session) { user.sessions.create! }

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up unless Lot.connection.column_exists?(:lots, :location_id)
    Lot.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def migration = described_class.new

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down = context.run(:down, 2026_10_23_100001)

  def up = context.run(:up, 2026_10_23_100001)

  def count(table) = Lot.connection.select_value("SELECT COUNT(*) FROM #{table}") # Safe: a literal table name from this spec

  def lot_rows = Lot.connection.select_rows("SELECT id, catalog_entry_id, quantity, finish, condition, price_paid_cents, lot_key, created_at, updated_at FROM lots ORDER BY id")

  def pick(selection, *lots) = selection.record!(shown_ids: [], ticked_ids: lots.map(&:id), header_rendered: false, header_ticked: false)

  # Every kind of row that points at a lot: a mark, a number-entry line, a scanner entry, and an undoable removal.
  def fill
    kept = owned_printing("Opt", account:, quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 150)
    gone = owned_printing("Shock", account:)
    selection = BulkSelection.for(session)
    pick(selection, gone)
    BulkRemoval.remove!(selection)
    pick(selection, kept)
    NumberEntry.add!(account:, entry: kept.entry, quantity: 1, finish: "foil", line_key: NumberEntry.new_line_key)
    Scanner::Sitting.add!(account:, printing: kept.entry, finish: "foil", reading_key: SecureRandom.hex(16))
  end

  it "turns the migration's transaction off, so a rollback rebuilds lots with foreign keys off (research R1)" do
    expect(described_class.disable_ddl_transaction).to be(true)
  end

  it "keeps every lot, mark, line, entry and undoable removal going down and up", :aggregate_failures do
    fill
    before = [ lot_rows, count("bulk_selection_marks"), count("number_entry_lines"), count("scanner_sitting_entries"), count("bulk_removals") ]

    down
    expect(Lot.connection.column_exists?(:lots, :location_id)).to be(false)
    expect([ lot_rows, count("bulk_selection_marks"), count("number_entry_lines"), count("scanner_sitting_entries"), count("bulk_removals") ]).to eq(before)

    up
    expect(Lot.connection.column_exists?(:lots, :location_id)).to be(true)
    expect([ lot_rows, count("bulk_selection_marks"), count("number_entry_lines"), count("scanner_sitting_entries"), count("bulk_removals") ]).to eq(before)
    expect(Lot.connection.select_values("SELECT location_id FROM lots")).to all(be_nil)
    expect(BulkRemoval.last).to be_undoable
  end

  it "points every mark, number-entry line and scanner entry at the lot it had", :aggregate_failures do
    fill
    pointers = %w[bulk_selection_marks number_entry_lines scanner_sitting_entries].to_h { |table| [ table, Lot.connection.select_rows("SELECT id, lot_id FROM #{table} ORDER BY id") ] } # Safe: literal table names
    down
    up
    pointers.each do |table, rows|
      expect(rows.map(&:last)).to all(be_present)
      expect(Lot.connection.select_rows("SELECT id, lot_id FROM #{table} ORDER BY id")).to eq(rows) # Safe: literal table names
    end
  end

  it "refuses to go down while a lot is in a location, saying how many", :aggregate_failures do
    lot = owned_printing("Opt", account:)
    location = create(:location, account:)
    Lot.connection.execute("UPDATE lots SET location_id = #{location.id.to_i} WHERE id = #{lot.id.to_i}") # the model has no place yet (Phase 1)
    expect { migration.migrate(:down) }.to raise_error(ActiveRecord::IrreversibleMigration, /1 lot/) # Migration#migrate itself: the Migrator would re-wrap the error
    expect(Lot.connection.column_exists?(:lots, :location_id)).to be(true)
  end

  it "finishes a run that stopped between its two steps" do
    Lot.connection.remove_index :lots, :location_id # the state a crash between ADD COLUMN and CREATE INDEX leaves
    migration.migrate(:up)
    expect([ Lot.connection.column_exists?(:lots, :location_id), Lot.connection.index_exists?(:lots, :location_id) ]).to eq([ true, true ])
  end
end
