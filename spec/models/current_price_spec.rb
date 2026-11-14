require "rails_helper"

RSpec.describe CurrentPrice, type: :model do
  it "is keyed by printing, source and series, and an upsert on that key replaces the row", :aggregate_failures do
    source = PriceSource.sync!(FakePriceSource)
    series = PriceSeries.ensure!(FakePriceSource.series).values.first
    keys = { catalog_entry_id: 7, price_source_id: source.id, price_series_id: series.id }

    described_class.upsert_all([ keys.merge(cents: 100, reported_on: Date.new(2026, 11, 12), changed_on: Date.new(2026, 11, 12)) ], unique_by: described_class.primary_key)
    described_class.upsert_all([ keys.merge(cents: 150, reported_on: Date.new(2026, 11, 13), changed_on: Date.new(2026, 11, 13)) ], unique_by: described_class.primary_key)

    expect(described_class.primary_key).to eq(%w[catalog_entry_id price_source_id price_series_id])
    expect(described_class.pluck(:cents, :changed_on)).to eq([ [ 150, Date.new(2026, 11, 13) ] ])
  end

  it "lives in the prices database and has no account" do
    expect([ described_class.connection_db_config.name, described_class.column_names & %w[account_id user_id] ]).to eq([ "prices", [] ])
  end
end
