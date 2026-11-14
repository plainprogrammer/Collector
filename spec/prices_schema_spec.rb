require "rails_helper"
require "open3"

# Spec 081 decision 3 (ruled 2026-11-13): current_prices and price_changes are WITHOUT ROWID on a database loaded from
# db/prices_structure.sql (a new instance, the test database) and on one built by the migrations (an upgraded instance).
RSpec.describe "the prices schema keeps WITHOUT ROWID (spec 081 AC-2.1 to AC-2.3)", type: :model do
  def large_tables = %w[current_prices price_changes]
  def internal_tables = %w[schema_migrations ar_internal_metadata]

  def advice
    "a column change on SQLite (change_column, remove_column and the like) rebuilds the table without WITHOUT ROWID; " \
      "write a new migration that recreates it with options: \"WITHOUT ROWID\" (db/prices_migrate's first migration says how)"
  end

  # A statement as stored, without the query-log comment Active Record appends to the SQL it runs (the structure file
  # carries them from the development database it was dumped from; a database built in a bare process has none).
  def bare(sql) = sql.to_s.gsub(%r{\s*/\*.*?\*/}m, "").strip

  # The tables and indexes a database's sqlite_master defines, name => [type, bare sql].
  def definitions(rows)
    rows.reject { |name, _type, _sql| internal_tables.include?(name) || name.start_with?("sqlite_") }
      .to_h { |name, type, sql| [ name, [ type, bare(sql) ] ] }
  end

  # Each table that should be WITHOUT ROWID and isn't, or is and shouldn't be: [] when the schema is right.
  def rowid_problems(definitions)
    definitions.filter_map do |name, (type, sql)|
      next unless type == "table"

      without = sql.end_with?("WITHOUT ROWID")
      "#{name}: #{without ? "is WITHOUT ROWID and shouldn't be" : "isn't WITHOUT ROWID; #{advice}"}" if without != large_tables.include?(name)
    end
  end

  # A database built only by running db/prices_migrate's migrations, in a child Ruby process with Active Record alone.
  # `through` stops at a version (nil: all); `path` continues a database already begun.
  def migrated_database(through: nil, path: nil)
    path ||= Pathname(Dir.mktmpdir("prices-migrated")).join("prices.sqlite3")
    script = <<~RUBY
      require "bundler/setup"
      require "active_record"
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ARGV[0])
      ActiveRecord::Migration.verbose = false
      target = ARGV[2].to_s.empty? ? nil : ARGV[2].to_i
      ActiveRecord::MigrationContext.new(ARGV[1]).migrate(target)
    RUBY
    _out, err, status = Open3.capture3(RbConfig.ruby, "-e", script, path.to_s, Rails.root.join("db/prices_migrate").to_s, through.to_s, chdir: Rails.root.to_s)
    raise "migrating failed: #{err}" unless status.success?

    path
  end

  def execute_in(path, sql)
    database = SQLite3::Database.new(path.to_s)
    database.execute(sql)
  ensure
    database&.close
  end

  def master_of(path)
    database = SQLite3::Database.new(path.to_s, readonly: true)
    database.execute("SELECT name, type, sql FROM sqlite_master WHERE type IN ('table', 'index') ORDER BY name")
  ensure
    database&.close
  end

  def loaded_master
    PricesRecord.lease_connection.select_rows("SELECT name, type, sql FROM sqlite_master WHERE type IN ('table', 'index') ORDER BY name")
  end

  it "holds on the structure-loaded test database (AC-2.1)" do
    expect(rowid_problems(definitions(loaded_master))).to be_empty
  end

  it "holds on a database built by the migrations, whose tables and indexes are the structure-loaded one's (AC-2.2)", :aggregate_failures do
    migrated = definitions(master_of(migrated_database))
    loaded = definitions(loaded_master)

    expect(rowid_problems(migrated)).to be_empty
    expect(migrated).to eq(loaded)
  end

  it "would notice either table without the option, naming it and the fix (AC-2.3, a negative control)" do
    rows = [ [ "current_prices", "table", 'CREATE TABLE "current_prices" ("catalog_entry_id" integer, PRIMARY KEY ("catalog_entry_id"))' ],
             [ "price_changes", "table", 'CREATE TABLE "price_changes" ("a" integer, PRIMARY KEY ("a")) WITHOUT ROWID /*application=\'Collector\'*/' ] ]

    expect(rowid_problems(definitions(rows))).to eq([ "current_prices: isn't WITHOUT ROWID; #{advice}" ])
  end

  context "with spec 089's migration (AC-5.2, AC-1.9)" do
    let(:released) { "20261113100001" }
    let(:count_columns) { %w[quotes_seen unchanged changed added removed removals_withheld unknown_printings malformed] }

    def columns_of(path)
      execute_in(path, "PRAGMA table_info(price_refresh_runs)").to_h { |_cid, name, type, notnull, default, _pk| [ name, { type:, notnull:, default: } ] }
    end

    it "keeps a run row of a database migrated as main has it, and its table's check, key and index", :aggregate_failures do
      path = migrated_database(through: released)
      execute_in(path, "INSERT INTO price_sources (key, name, attribution, created_at, updated_at) VALUES ('s', 'S', 'a', '2026-11-13', '2026-11-13')")
      execute_in(path, "INSERT INTO price_refresh_runs (price_source_id, run_on, status, started_at, created_at, updated_at) VALUES (1, '2026-11-12', 'finished', '2026-11-12 10:00:00', '2026-11-12', '2026-11-12')")

      migrated_database(path:)
      columns = columns_of(path)
      master = execute_in(path, "SELECT name, sql FROM sqlite_master").to_h

      expect(execute_in(path, "SELECT run_on, quotes_seen, job_id FROM price_refresh_runs")).to eq([ [ "2026-11-12", 0, nil ] ])
      expect(columns["run_on"][:notnull]).to eq(0)
      expect(columns.keys).to include("job_id", "languages", *count_columns)
      expect(count_columns.map { |name| columns[name].values_at(:notnull, :default) }.uniq).to eq([ [ 1, "0" ] ])
      expect(master["price_refresh_runs"]).to include("price_refresh_runs_status_known", "REFERENCES \"price_sources\"")
      expect(master).to have_key("index_price_refresh_runs_on_price_source_id_and_run_on")
      expect(rowid_problems(definitions(master_of(path)))).to be_empty
    end

    it "accepts a run with no date and refuses an unknown status", :aggregate_failures do
      path = migrated_database
      execute_in(path, "INSERT INTO price_sources (key, name, attribution, created_at, updated_at) VALUES ('s', 'S', 'a', '2026-11-13', '2026-11-13')")

      expect { execute_in(path, "INSERT INTO price_refresh_runs (price_source_id, status, started_at, created_at, updated_at) VALUES (1, 'skipped', '2026-11-13', '2026-11-13', '2026-11-13')") }.not_to raise_error
      expect { execute_in(path, "INSERT INTO price_refresh_runs (price_source_id, status, started_at, created_at, updated_at) VALUES (1, 'bogus', '2026-11-13', '2026-11-13', '2026-11-13')") }.to raise_error(SQLite3::ConstraintException)
    end

    it "goes down without losing a row: a nil run_on takes the date of started_at", :aggregate_failures do
      path = migrated_database
      execute_in(path, "INSERT INTO price_sources (key, name, attribution, created_at, updated_at) VALUES ('s', 'S', 'a', '2026-11-13', '2026-11-13')")
      execute_in(path, "INSERT INTO price_refresh_runs (price_source_id, status, started_at, created_at, updated_at) VALUES (1, 'skipped', '2026-11-13 09:00:00', '2026-11-13', '2026-11-13')")

      migrated_database(through: released, path:)

      expect(execute_in(path, "SELECT run_on FROM price_refresh_runs")).to eq([ [ "2026-11-13" ] ])
      expect(columns_of(path)["run_on"][:notnull]).to eq(1)
      expect(columns_of(path).keys).not_to include("job_id", "quotes_seen")
    end
  end
end
