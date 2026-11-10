require "rails_helper"
require Rails.root.join("db/migrate/20261110200001_add_decks")

# Spec 062 AC-9.1 to AC-9.4: the migration makes every location a place, keeps every row and pointer to a location, states
# the kinds, the parent and the zone as named checks, and refuses to go down while a deck exists. It runs outside a
# transaction (disable_ddl_transaction!), so the examples commit their rows (:committed empties the database around them).
# Down and up go through the Migrator (MigrationContext#run), which wraps a migration in a transaction unless it turns that
# off, exactly as db:rollback does; Migration#migrate would open none and pass without disable_ddl_transaction!, the very
# line this spec guards (the precedent is spec/migrations/add_location_to_lots_spec.rb).
RSpec.describe AddDecks, :backup, :committed, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:connection) { ActiveRecord::Base.connection }
  let(:checks) { %w[locations_kind_known locations_parent_matches_kind locations_zone_matches_kind] }

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up unless connection.column_exists?(:locations, :kind)
    Location.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def migration = described_class.new

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down = context.run(:down, 2026_11_10_200001)

  def up = context.run(:up, 2026_11_10_200001)

  def count(table) = connection.select_value("SELECT COUNT(*) FROM #{table}") # Safe: a literal table name from this spec

  def index(name) = connection.indexes(:locations).find { it.name == name }

  def location_rows = connection.select_rows("SELECT id, account_id, name, name_key, created_at, updated_at FROM locations ORDER BY id")

  def lot_rows = connection.select_rows("SELECT id, location_id, lot_key, quantity, created_at, updated_at FROM lots ORDER BY id")

  def insert_location(name, kind: "place", parent_id: nil, zone: nil)
    connection.insert(ActiveRecord::Base.sanitize_sql_array([
      "INSERT INTO locations (account_id, name, name_key, created_at, updated_at, kind, parent_id, zone) " \
      "VALUES (?, ?, ?, datetime('now'), datetime('now'), ?, ?, ?)", account.id, name, name.downcase, kind, parent_id, zone
    ]))
  end

  def insert_deck(name)
    id = insert_location(name, kind: "deck")
    connection.execute("INSERT INTO decks (account_id, location_id, collectible_type, format, created_at, updated_at) " \
                       "VALUES (#{account.id}, #{id}, 'mtg', 'casual', datetime('now'), datetime('now'))")
    id
  end

  # Rows that point at a location, made while the old schema is in place: a place, a lot in it and a scanner sitting.
  def fill
    place = create(:location, account:, name: "Blue binder")
    create(:lot, account:, location: place, quantity: 3)
    create(:lot, account:, quantity: 2)
    connection.execute("INSERT INTO scanner_sittings (account_id, created_at, updated_at, location_id) VALUES (#{account.id}, datetime('now'), datetime('now'), #{place.id})")
  end

  it "turns the migration's transaction off, so the table copy runs with foreign keys off (AC-9.2)" do
    expect(described_class.disable_ddl_transaction).to be(true)
  end

  it "makes every location a place with no parent or zone and changes no row, going down and up (AC-9.1)", :aggregate_failures do
    fill
    before = [ location_rows, lot_rows ]

    down
    expect(connection.column_exists?(:locations, :kind)).to be(false)
    up

    expect([ location_rows, lot_rows ]).to eq(before)
    expect(connection.select_rows("SELECT kind, parent_id, zone FROM locations")).to eq([ [ "place", nil, nil ] ])
    expect(count("decks")).to eq(0)
  end

  it "replaces the old unique index with a top-level one that refuses a repeated name (AC-9.1)", :aggregate_failures do
    expect(index("index_locations_on_account_id_and_name_key")).to be_nil
    top = index("index_locations_on_account_id_and_name_key_top_level")
    zones = index("index_locations_on_parent_id_and_name_key")
    expect([ top.columns, top.unique, top.where ]).to eq([ %w[account_id name_key], true, "parent_id IS NULL" ])
    expect([ zones.columns, zones.unique, zones.where ]).to eq([ %w[parent_id name_key], true, "parent_id IS NOT NULL" ])

    insert_location("Box")
    expect { insert_location("Box") }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { insert_deck("Box") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "lets two decks each have a zone of one name and refuses two in one deck (AC-9.1)", :aggregate_failures do
    one = insert_deck("One")
    two = insert_deck("Two")
    insert_location("Main", kind: "deck_zone", parent_id: one, zone: "main")

    expect { insert_location("Main", kind: "deck_zone", parent_id: two, zone: "main") }.not_to raise_error
    expect { insert_location("Main", kind: "deck_zone", parent_id: one, zone: "other") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "states the kinds, the parent and the zone as named checks (AC-9.4)", :aggregate_failures do
    expect(connection.check_constraints(:locations).map(&:name)).to include(*checks)
    deck = insert_deck("Izzet")

    expect { insert_location("Odd", kind: "other") }.to raise_error(ActiveRecord::StatementInvalid, /locations_kind_known/)
    expect { insert_location("Orphan", kind: "deck_zone", zone: "main") }.to raise_error(ActiveRecord::StatementInvalid, /locations_parent_matches_kind/)
    expect { insert_location("Shelf", parent_id: deck) }.to raise_error(ActiveRecord::StatementInvalid, /locations_parent_matches_kind/)
    expect { insert_location("Shelf", zone: "main") }.to raise_error(ActiveRecord::StatementInvalid, /locations_zone_matches_kind/)
    expect { insert_location("No key", kind: "deck_zone", parent_id: deck) }.to raise_error(ActiveRecord::StatementInvalid, /locations_zone_matches_kind/)
  end

  it "keeps one decks row per location and deletes it, and the zones, with the location (AC-9.4)", :aggregate_failures do
    deck = insert_deck("Izzet")
    insert_location("Main", kind: "deck_zone", parent_id: deck, zone: "main")

    expect { connection.execute("INSERT INTO decks (account_id, location_id, collectible_type, format, created_at, updated_at) VALUES (#{account.id}, #{deck}, 'mtg', 'casual', datetime('now'), datetime('now'))") }
      .to raise_error(ActiveRecord::RecordNotUnique)
    expect(connection.index_exists?(:decks, :account_id)).to be(true)
    connection.execute("DELETE FROM locations WHERE id = #{deck}")
    expect([ count("decks"), count("locations") ]).to eq([ 0, 0 ])
  end

  it "runs again with nothing left to do, and keeps the rows that point at a location (AC-9.2)", :aggregate_failures do
    fill
    before = [ location_rows, lot_rows, count("scanner_sittings") ]

    expect { migration.migrate(:up) }.not_to raise_error
    expect([ location_rows, lot_rows, count("scanner_sittings") ]).to eq(before)
    expect(connection.select_value("SELECT location_id FROM scanner_sittings")).to be_present
  end

  it "keeps a lot and a scanner sitting that point at a location when it goes down and up (AC-9.2)", :aggregate_failures do
    fill
    pointers = connection.select_rows("SELECT location_id FROM lots WHERE location_id IS NOT NULL UNION ALL SELECT location_id FROM scanner_sittings")

    down
    up

    expect(connection.select_rows("SELECT location_id FROM lots WHERE location_id IS NOT NULL UNION ALL SELECT location_id FROM scanner_sittings")).to eq(pointers)
    expect(pointers.size).to eq(2)
  end

  it "finishes a run that stopped after the columns (AC-9.2)", :aggregate_failures do
    connection.drop_table :decks
    connection.remove_index :locations, name: "index_locations_on_account_id_and_name_key_top_level"
    connection.add_index :locations, %i[account_id name_key], unique: true, name: "index_locations_on_account_id_and_name_key"

    migration.migrate(:up)

    expect(connection.table_exists?(:decks)).to be(true)
    expect(index("index_locations_on_account_id_and_name_key")).to be_nil
    expect(index("index_locations_on_account_id_and_name_key_top_level")).to be_present
  end

  describe "going down" do
    it "refuses while a decks row exists, saying how many (AC-9.3)", :aggregate_failures do
      insert_deck("Izzet")

      expect { migration.migrate(:down) }.to raise_error(ActiveRecord::IrreversibleMigration, /deck/)
      expect(connection.column_exists?(:locations, :kind)).to be(true)
    end

    it "refuses while any location is not a place, even with no decks row (AC-9.3)" do
      insert_location("Stray", kind: "deck")

      expect { migration.migrate(:down) }.to raise_error(ActiveRecord::IrreversibleMigration, /1 deck exists/)
    end

    it "removes the columns, the table, the checks and the new indexes, and restores the old index when none exists (AC-9.3)", :aggregate_failures do
      down

      expect(%i[kind parent_id zone].map { |column| connection.column_exists?(:locations, column) }).to eq([ false, false, false ])
      expect(connection.table_exists?(:decks)).to be(false)
      expect(connection.indexes(:locations).map(&:name)).to contain_exactly("index_locations_on_account_id_and_name_key")
      expect(connection.indexes(:locations).first.unique).to be(true)
      expect(connection.check_constraints(:locations).map(&:name)).to contain_exactly("locations_name_length", "locations_name_key_present")
    end
  end
end
