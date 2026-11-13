require "rails_helper"

RSpec.describe "the prices database in a prepared volume (spec 081 AC-1.2, AC-1.3, AC-6.9)", :backup, type: :model do
  def schema_files = %w[db/schema.rb db/prices_structure.sql].to_h { [ it, Digest::SHA256.file(Rails.root.join(it)).hexdigest ] }
  def prices_versions = Collector::Backup.release_schema_versions(Rails.root, "db/prices_migrate")

  def tables(path) = sqlite(path, readonly: true) { |db| db.execute("SELECT name FROM sqlite_master WHERE type = 'table'").flatten }

  it "creates and migrates the prices file on an empty volume, without touching the repository's schema files", :aggregate_failures do
    before = schema_files
    volume = scratch("volume")
    _out, err, status = app_command(volume.join("production.sqlite3"), "db:prepare")

    expect(status).to be_success, err
    prices = volume.join("production_prices.sqlite3")
    expect(Collector::Backup::Snapshot.new(prices).schema_versions).to match_array(prices_versions)
    expect(tables(prices)).to include("price_sources", "price_series", "current_prices", "price_changes", "price_refresh_runs")
    expect(schema_files).to eq(before)
  end

  it "creates the prices file beside a primary that has no prices file, and keeps the primary's rows (AC-1.3)", :aggregate_failures, :committed do
    seed_instance(lots: 2)
    volume = scratch("volume")
    primary = volume.join("production.sqlite3")
    FileUtils.cp(copy_of_instance, primary)
    rows = table_rows(primary)
    _out, err, status = app_command(primary, "db:prepare")

    expect(status).to be_success, err
    expect(volume.join("production_prices.sqlite3")).to exist
    expect(table_rows(primary).except("schema_migrations", "ar_internal_metadata")).to eq(rows.except("schema_migrations", "ar_internal_metadata"))
  end

  it "empties the prices database after a committed example (AC-1.5, decision 12)", :committed do
    PricesRecord.lease_connection.execute("INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('kept', 'Kept', 'x', 0, '2026-11-13', '2026-11-13')")
    clear_instance!
    expect(PricesRecord.lease_connection.select_value("SELECT count(*) FROM price_sources")).to eq(0)
  end

  it "gives each child command a SCHEMA path that doesn't exist yet (AC-6.9, the second half)" do
    paths = []
    allow(Open3).to receive(:capture3).and_wrap_original do |original, env, *rest, **kw|
      paths << File.exist?(env["SCHEMA"])
      original.call(env, *rest, **kw)
    end
    2.times { app_command(scratch("volume").join("production.sqlite3"), "db:prepare") }
    expect(paths).to eq([ false, false ])
  end

  describe "a backup and a restore of an instance with price rows (AC-6.2)" do
    let(:seed) { seed_instance }
    let(:connection) { PricesRecord.lease_connection }

    # One source, two series, three current prices and four price changes, one of them a missing price (null cents).
    def seed_price_rows(entries)
      stamp = "'2026-10-21 14:21:00'"
      connection.execute("INSERT INTO price_sources (id, key, name, attribution, created_at, updated_at) VALUES (1, 'src', 'Source', 'Credit', #{stamp}, #{stamp})")
      connection.execute("INSERT INTO price_series (id, finish, currency, kind, created_at, updated_at) VALUES (1, 'nonfoil', 'USD', 'market', #{stamp}, #{stamp}), (2, 'foil', 'USD', 'market', #{stamp}, #{stamp})")
      ids = entries.map(&:id)
      connection.execute("INSERT INTO current_prices (catalog_entry_id, price_source_id, price_series_id, cents, reported_on, changed_on) VALUES " \
        "(#{ids[0]}, 1, 1, 150, '2026-10-21', '2026-10-20'), (#{ids[0]}, 1, 2, 420, '2026-10-21', '2026-10-21'), (#{ids[1]}, 1, 1, 7, '2026-10-21', '2026-10-21')")
      connection.execute("INSERT INTO price_changes (catalog_entry_id, price_source_id, price_series_id, recorded_on, cents) VALUES " \
        "(#{ids[0]}, 1, 1, '2026-10-19', 140), (#{ids[0]}, 1, 1, '2026-10-20', 150), (#{ids[0]}, 1, 2, '2026-10-21', 420), (#{ids[1]}, 1, 1, '2026-10-21', NULL)")
    end

    it "restores both databases with the same rows, the sessions and their cascades aside", :aggregate_failures, :committed do # rubocop:disable RSpec/ExampleLength -- one scenario: seed both databases, back up, restore, compare every table
      seed_session(seed.user, seed.lots.first)
      seed_price_rows(seed.entries)
      volume = scratch("volume")
      result = restore_backup(create_backup, volume:)
      cleared = %w[sessions bulk_removals bulk_selections bulk_selection_marks]
      live = table_rows(instance_database)
      restored = table_rows(volume.join("production.sqlite3"))
      live_prices = table_rows(instance_prices_database)
      restored_prices = table_rows(volume.join("production_prices.sqlite3"))

      expect(restored.keys).to eq(live.keys)
      (live.keys - cleared).each { |table| expect(restored.fetch(table)).to eq(live.fetch(table)), table }
      cleared.each { |table| expect(restored.fetch(table)).to be_empty, table }
      expect(restored_prices.keys).to eq(live_prices.keys)
      live_prices.each { |table, rows| expect(restored_prices.fetch(table)).to eq(rows), table }
      expect(restored_prices.values_at("current_prices", "price_changes").map(&:size)).to eq([ 3, 4 ])
      expect(result.report).to include("; 3 current prices and 4 price changes.")
    end
  end
end
