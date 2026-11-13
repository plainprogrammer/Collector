require "rails_helper"

RSpec.describe PricesRecord, type: :model do
  def connection = described_class.lease_connection
  def insert(sql, binds = []) = connection.exec_insert(sql, "spec", binds)

  def source! = insert("INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('a-source', 'A', 'Prices from A', 0, '2026-11-13', '2026-11-13')") && connection.select_value("SELECT max(id) FROM price_sources")
  def series!(finish = "plain") = insert("INSERT INTO price_series (finish, currency, kind, created_at, updated_at) VALUES ('#{finish}', 'USD', 'market', '2026-11-13', '2026-11-13')") && connection.select_value("SELECT max(id) FROM price_series")

  it "is abstract and connects to storage/test_prices.sqlite3, which the primary test database is not (AC-1.5)", :aggregate_failures do
    expect(described_class).to be_abstract_class
    expect(connection.pool.db_config.database).to eq("storage/test_prices.sqlite3")
    expect(ActiveRecord::Base.lease_connection.table_exists?("current_prices")).to be(false)
    expect(connection.tables).to include("price_sources", "price_series", "current_prices", "price_changes", "price_refresh_runs")
  end

  it "runs each example inside a transaction on the prices database too, so its rows roll back (AC-1.5)", :aggregate_failures do
    source!
    outside = SQLite3::Database.new(Rails.root.join("storage/test_prices.sqlite3").to_s, readonly: true)
    expect(connection.transaction_open?).to be(true)
    expect(connection.select_value("SELECT count(*) FROM price_sources")).to eq(1)
    expect(outside.get_first_value("SELECT count(*) FROM price_sources")).to eq(0) # uncommitted, so not in the file
  ensure
    outside&.close
  end

  it "has no account or user column in any table (AC-3.1)" do
    columns = connection.tables.flat_map { |table| connection.columns(table).map { "#{table}.#{it.name}" } }
    expect(columns.grep(/\.(account_id|user_id)\z/)).to be_empty
  end

  it "keeps every foreign key inside the prices file, restricting deletes, and none on catalog_entry_id (AC-3.3)", :aggregate_failures do
    keys = connection.tables.flat_map { |table| connection.foreign_keys(table) }
    expect(keys.map(&:to_table).uniq).to match_array(%w[price_sources price_series])
    expect(keys.map(&:on_delete).uniq).to eq([ :restrict ])
    expect(keys.map(&:column)).not_to include("catalog_entry_id")
  end

  it "can't reach the primary database's tables (AC-3.4)" do
    expect { connection.select_value("SELECT count(*) FROM catalog_entries") }.to raise_error(ActiveRecord::StatementInvalid, /no such table/)
  end

  it "refuses rows that break the schema's rules (AC-1.4)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one row per rule
    source = source!
    series = series!
    bad = [
      "INSERT INTO current_prices (catalog_entry_id, price_source_id, price_series_id, cents, reported_on, changed_on) VALUES (1, #{source}, #{series}, -1, '2026-11-13', '2026-11-13')",
      "INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('', 'B', 'x', 0, '2026-11-13', '2026-11-13')",
      "INSERT INTO price_series (finish, currency, kind, created_at, updated_at) VALUES ('plain', 'USD', 'market', '2026-11-13', '2026-11-13')",
      "INSERT INTO price_series (finish, currency, kind, created_at, updated_at) VALUES ('shiny', 'usd', 'market', '2026-11-13', '2026-11-13')",
      "INSERT INTO current_prices (catalog_entry_id, price_source_id, price_series_id, cents, reported_on, changed_on) VALUES (1, #{source}, 999, 5, '2026-11-13', '2026-11-13')",
      "INSERT INTO price_changes (catalog_entry_id, price_source_id, price_series_id, recorded_on, cents) VALUES (1, #{source}, #{series}, '2026-11-13', -5)",
      "INSERT INTO price_refresh_runs (price_source_id, run_on, status, started_at, created_at, updated_at) VALUES (#{source}, '2026-11-13', 'lost', '2026-11-13', '2026-11-13', '2026-11-13')",
      "INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('b', '', 'x', 0, '2026-11-13', '2026-11-13')",
      "INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('b', 'B', '', 0, '2026-11-13', '2026-11-13')",
      "INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('   ', 'B', 'x', 0, '2026-11-13', '2026-11-13')",
      "INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('b', '  ', 'x', 0, '2026-11-13', '2026-11-13')",
      "INSERT INTO price_sources (key, name, attribution, hosted_paid_allowed, created_at, updated_at) VALUES ('c', 'B', '  ', 0, '2026-11-13', '2026-11-13')"
    ]
    bad.each { |sql| expect { connection.execute(sql) }.to raise_error(ActiveRecord::StatementInvalid), sql }
  end

  it "refuses a second current price for the same printing, source and series (AC-1.4)" do
    source = source!
    series = series!
    row = "INSERT INTO current_prices (catalog_entry_id, price_source_id, price_series_id, cents, reported_on, changed_on) VALUES (1, #{source}, #{series}, 5, '2026-11-13', '2026-11-13')"
    connection.execute(row)
    expect { connection.execute(row) }.to raise_error(ActiveRecord::StatementInvalid, /UNIQUE|PRIMARY/i)
  end

  it "allows two refresh runs of one source on one date: the index isn't unique (AC-1.4)" do
    source = source!
    run = "INSERT INTO price_refresh_runs (price_source_id, run_on, status, started_at, created_at, updated_at) VALUES (#{source}, '2026-11-13', 'running', '2026-11-13', '2026-11-13', '2026-11-13')"
    2.times { connection.execute(run) }
    expect(connection.select_value("SELECT count(*) FROM price_refresh_runs")).to eq(2)
  end

  it "has the columns and primary keys of decision 2's table (AC-1.4)", :aggregate_failures do
    columns = {
      "price_sources" => %w[id key name attribution attribution_url hosted_paid_allowed created_at updated_at],
      "price_series" => %w[id finish currency kind created_at updated_at],
      "current_prices" => %w[catalog_entry_id price_source_id price_series_id cents reported_on changed_on],
      "price_changes" => %w[catalog_entry_id price_source_id price_series_id recorded_on cents],
      "price_refresh_runs" => %w[id price_source_id run_on source_version status error started_at finished_at created_at updated_at]
    }
    keys = { "current_prices" => %w[catalog_entry_id price_source_id price_series_id],
             "price_changes" => %w[catalog_entry_id price_source_id price_series_id recorded_on] }
    columns.each do |table, names|
      expect(connection.columns(table).map(&:name)).to match_array(names), table
      expect(connection.primary_key(table)).to eq(keys.fetch(table, "id")), table
    end
  end

  it "takes a price change with no cents: the price went away that day (decision 2)" do
    source = source!
    series = series!
    insert("INSERT INTO price_changes (catalog_entry_id, price_source_id, price_series_id, recorded_on, cents) VALUES (7, #{source}, #{series}, '2026-11-13', NULL)")
    expect(connection.select_value("SELECT count(*) FROM price_changes WHERE cents IS NULL")).to eq(1)
  end
end
