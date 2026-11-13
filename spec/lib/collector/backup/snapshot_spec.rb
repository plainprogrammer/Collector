require "rails_helper"

RSpec.describe Collector::Backup::Snapshot, :backup do
  let(:copy) { copy_of_instance }
  let(:snapshot) { described_class.new(copy) }
  let(:now) { "2026-10-21 14:21:00" }

  # A copy of the test prices database in the scratch directory, made with VACUUM INTO.
  def prices_copy(name) = scratch_path(name).tap { described_class.take(source: Collector::Backup::Databases.configured.prices, into: it) }

  def insert_account_and_user(database, email: "a@example.test")
    database.execute("INSERT INTO accounts (created_at, updated_at) VALUES (?, ?)", [ now, now ])
    account_id = database.last_insert_row_id
    database.execute("INSERT INTO users (account_id, name, email_address, password_digest, created_at, updated_at) VALUES (?, 'N', ?, 'd', ?, ?)",
      [ account_id, email, now, now ])
    [ account_id, database.last_insert_row_id ]
  end

  describe ".take" do
    it "copies a database into an empty private file with VACUUM INTO, and the copy checks out", :aggregate_failures do
      target = scratch_path("snapshot.sqlite3")
      Collector::Backup.create_private(target).close

      described_class.take(source: instance_database, into: target)

      expect(target.stat.mode & 0o777).to eq(0o600)
      expect { described_class.new(target).verify! }.not_to raise_error
      expect(described_class.new(target).schema_versions).to match_array(release_versions)
    end

    it "never creates a source that isn't there", :aggregate_failures do
      missing = scratch_path("none.sqlite3")

      expect { described_class.take(source: missing, into: scratch_path("out.sqlite3")) }.to raise_error(SQLite3::CantOpenException)
      expect(missing).not_to exist
    end

    it "calls a source with a page it can't read damaged (AC-1.5)" do
      damage_table!(copy, "lots")

      expect { described_class.take(source: copy, into: scratch_path("out.sqlite3")) }.to raise_error(described_class::Damaged)
    end
  end

  describe "#rollback_journal!" do
    it "turns a WAL file into a rollback-journal file with no sidecar, whatever its header said first (AC-1.4)", :aggregate_failures do
      sqlite(copy) { |database| database.execute("PRAGMA journal_mode = WAL") }
      expect(File.binread(copy, 2, 18).bytes).to eq([ 2, 2 ])

      snapshot.rollback_journal!

      expect(File.binread(copy, 2, 18).bytes).to eq([ 1, 1 ])
      expect(snapshot).to be_rollback_journal
      expect(Dir["#{copy}-*"]).to be_empty
    end

    it "leaves a rollback-journal file as it is" do
      snapshot.rollback_journal!
      snapshot.rollback_journal!

      expect(snapshot).to be_rollback_journal
    end
  end

  describe "#verify!" do
    it "passes a sound database" do
      expect { snapshot.verify! }.not_to raise_error
    end

    it "calls a database with an unreadable page damaged (AC-3.7)" do
      damage_table!(copy, "lots")

      expect { snapshot.verify! }.to raise_error(described_class::Damaged)
    end

    it "counts the rows that fail the foreign-key check (AC-1.12, AC-3.7)", :aggregate_failures do
      sqlite(copy) do |database|
        database.execute("PRAGMA foreign_keys = OFF")
        database.execute("INSERT INTO lots (account_id, catalog_entry_id, quantity, lot_key, created_at, updated_at) VALUES (999, 999, 1, 'k', ?, ?)", [ now, now ])
      end

      expect { snapshot.verify! }.to raise_error(described_class::OrphanRows) { |error| expect(error.count).to eq(1) }
    end

    it "counts each orphan row of a WITHOUT ROWID table, whose rowid is null (spec 081 AC-4.5, decision 3)", :aggregate_failures do
      prices = prices_copy("prices-orphans.sqlite3")
      sqlite(prices) do |database|
        database.execute("PRAGMA foreign_keys = OFF")
        database.execute("INSERT INTO price_sources (key, name, attribution, created_at, updated_at) VALUES ('s', 'S', 'a', ?, ?)", [ now, now ])
        source_id = database.last_insert_row_id # not 1: the copy keeps the test database's sequence
        3.times { |day| database.execute("INSERT INTO price_changes (catalog_entry_id, price_source_id, price_series_id, recorded_on, cents) VALUES (1, ?, 999, ?, 5)", [ source_id, "2026-11-0#{day + 1}" ]) }
      end

      expect { described_class.new(prices).verify! }.to raise_error(described_class::OrphanRows) { |error| expect(error.count).to eq(3) }
    end

    it "calls a file that is not a database damaged" do
      garbage = scratch_path("garbage.sqlite3").tap { it.binwrite("this is not a database" * 100) }

      expect { described_class.new(garbage).verify! }.to raise_error(described_class::Damaged)
    end
  end

  describe "#counts with table names" do
    it "counts the prices tables of a copy of the prices database (spec 081 decision 6)" do
      prices = prices_copy("prices-copy.sqlite3")
      sqlite(prices) do |database|
        database.execute("INSERT INTO price_sources (key, name, attribution, created_at, updated_at) VALUES ('s', 'S', 'a', ?, ?)", [ now, now ])
        source_id = database.last_insert_row_id
        database.execute("INSERT INTO price_series (finish, currency, kind, created_at, updated_at) VALUES ('nonfoil', 'USD', 'market', ?, ?)", [ now, now ])
        series_id = database.last_insert_row_id
        2.times { |card| database.execute("INSERT INTO current_prices VALUES (?, ?, ?, 100, '2026-11-13', '2026-11-13')", [ card + 1, source_id, series_id ]) }
        3.times { |day| database.execute("INSERT INTO price_changes VALUES (1, ?, ?, ?, 100)", [ source_id, series_id, "2026-11-0#{day + 1}" ]) }
      end

      expect(described_class.new(prices).counts(%w[current_prices price_changes])).to eq("current_prices" => 2, "price_changes" => 3)
    end
  end

  describe "#counts and #schema_versions" do
    it "counts accounts, users and lots, and lists the migrations the database has run", :aggregate_failures do
      sqlite(copy) { |database| insert_account_and_user(database) }

      expect(snapshot.counts).to eq("accounts" => 1, "users" => 1, "lots" => 0)
      expect(snapshot.schema_versions).to match_array(release_versions)
    end
  end

  describe "#end_sessions!" do
    it "deletes every session with foreign keys on, which takes the bulk removals, selections and marks with them (decision 3, AC-2.1)", :aggregate_failures do
      sqlite(copy) do |database|
        database.execute("PRAGMA foreign_keys = OFF")
        account_id, user_id = insert_account_and_user(database)
        database.execute("INSERT INTO sessions (user_id, last_used_at, created_at, updated_at) VALUES (?, ?, ?, ?)", [ user_id, now, now, now ])
        session_id = database.last_insert_row_id
        database.execute("INSERT INTO bulk_selections (session_id, account_id, created_at, updated_at) VALUES (?, ?, ?, ?)", [ session_id, account_id, now, now ])
        selection_id = database.last_insert_row_id
        database.execute("INSERT INTO bulk_selection_marks (bulk_selection_id, account_id, lot_id) VALUES (?, ?, 1)", [ selection_id, account_id ])
        database.execute("INSERT INTO bulk_removals (session_id, account_id, copies, created_at, updated_at) VALUES (?, ?, 1, ?, ?)", [ session_id, account_id, now, now ])
      end

      snapshot.end_sessions!

      tables = %w[sessions bulk_selections bulk_selection_marks bulk_removals]
      expect(sqlite(copy, readonly: true) { |database| tables.map { database.get_first_value("SELECT COUNT(*) FROM #{it}") } }).to eq([ 0, 0, 0, 0 ])
      expect(snapshot.counts).to include("users" => 1)
    end
  end
end
