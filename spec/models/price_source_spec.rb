require "rails_helper"

RSpec.describe PriceSource, type: :model do
  describe ".sync! (spec 085 decision 7)" do
    it "writes the source and its six series from the Scryfall declaration (AC-3.1)", :aggregate_failures do
      source = described_class.sync!(MTG::Scryfall::PriceQuotes)

      expect(source).to have_attributes(key: "scryfall", name: "Scryfall", attribution_url: "https://scryfall.com", hosted_paid_allowed: MTG::Scryfall::PriceQuotes.hosted_paid_allowed?,
                                        attribution: MTG::Scryfall::PriceQuotes.attribution, persisted?: true)
      expect(described_class.count).to eq(1)
      expect(PriceSeries.pluck(:finish, :currency, :kind)).to match_array(MTG::Scryfall::PriceQuotes.series.map { |series| series.to_h.values })
    end

    it "is idempotent: a second call adds no row, changes no id and leaves the row untouched (AC-3.2)", :aggregate_failures do
      first = described_class.sync!(FakePriceSource)
      updated_at = first.reload.updated_at
      second = described_class.sync!(FakePriceSource)

      expect(second.id).to eq(first.id)
      expect(second.reload.updated_at).to eq(updated_at)
      expect([ described_class.count, PriceSeries.count ]).to eq([ 1, 1 ])
    end

    it "updates a source row whose declaration changed, keeping its id, and never deletes a series (AC-3.3)", :aggregate_failures do
      two = [ Prices::Sources::Series.new(finish: "plain", currency: "USD", kind: "market"), Prices::Sources::Series.new(finish: "shiny", currency: "USD", kind: "market") ]
      first = described_class.sync!(FakePriceSource.with(series: two))
      corrected = described_class.sync!(FakePriceSource.with(attribution: "Corrected text.", series: [ two.first ]))

      expect(corrected.id).to eq(first.id)
      expect(corrected.reload.attribution).to eq("Corrected text.")
      expect(PriceSeries.count).to eq(2)
    end

    it "gives two sources that quote the same series one series row (AC-3.4)", :aggregate_failures do
      described_class.sync!(FakePriceSource)
      described_class.sync!(FakePriceSource.with(key: "other_fake"))

      expect(described_class.count).to eq(2)
      expect(PriceSeries.count).to eq(1)
    end

    it "writes nothing for a source that fails the contract (AC-3.6)", :aggregate_failures do
      expect { described_class.sync!(FakePriceSource.with(title: "")) }.to raise_error(Prices::Sources::ConfigurationError, /title/)
      expect([ described_class.count, PriceSeries.count ]).to eq([ 0, 0 ])
    end
  end

  describe "the table (AC-3.7)" do
    it "is in the prices database, global, and a table the primary database lacks", :aggregate_failures do
      expect(described_class.connection_db_config.name).to eq("prices")
      expect(described_class.column_names).not_to include("account_id", "user_id")
      expect(ActiveRecord::Base.lease_connection.table_exists?("price_sources")).to be(false)
    end
  end
end
