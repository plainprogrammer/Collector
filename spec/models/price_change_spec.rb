require "rails_helper"

RSpec.describe PriceChange, type: :model do
  it "is keyed by printing, source, series and day, and an upsert on that key replaces the row", :aggregate_failures do
    source = PriceSource.sync!(FakePriceSource)
    series = PriceSeries.ensure!(FakePriceSource.series).values.first
    keys = { catalog_entry_id: 7, price_source_id: source.id, price_series_id: series.id, recorded_on: Date.new(2026, 11, 13) }

    described_class.upsert_all([ keys.merge(cents: 100) ], unique_by: described_class.primary_key)
    described_class.upsert_all([ keys.merge(cents: nil) ], unique_by: described_class.primary_key)

    expect(described_class.primary_key).to eq(%w[catalog_entry_id price_source_id price_series_id recorded_on])
    expect(described_class.pluck(:cents)).to eq([ nil ])
  end

  it "lives in the prices database and has no account" do
    expect([ described_class.connection_db_config.name, described_class.column_names & %w[account_id user_id] ]).to eq([ "prices", [] ])
  end
end
