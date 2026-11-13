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
end
