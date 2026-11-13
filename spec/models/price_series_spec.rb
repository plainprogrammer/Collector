require "rails_helper"

RSpec.describe PriceSeries, type: :model do
  let(:plain) { Prices::Sources::Series.new(finish: "plain", currency: "USD", kind: "market") }
  let(:shiny) { Prices::Sources::Series.new(finish: "shiny", currency: "USD", kind: "market") }

  describe ".ensure! (spec 085 decision 7, AC-3.5)" do
    it "returns the row of each declared series, keyed by the series, creating the ones that are missing", :aggregate_failures do
      existing = described_class.create!(finish: "plain", currency: "USD", kind: "market")
      rows = described_class.ensure!([ plain, shiny ])

      expect(rows.keys).to eq([ plain, shiny ])
      expect(rows[plain]).to eq(existing)
      expect(rows[shiny]).to have_attributes(finish: "shiny", currency: "USD", kind: "market", persisted?: true)
      expect(described_class.count).to eq(2)
    end

    it "finds a quote's row by the quote's series" do
      quote = Prices::Sources::Quote.new(external_key: "abc-1", finish: "shiny", currency: "USD", kind: "market", cents: 5, reported_on: Date.new(2026, 11, 13))

      expect(described_class.ensure!([ plain, shiny ])[quote.series].finish).to eq("shiny")
    end

    it "is idempotent: a second call adds no row and changes no id", :aggregate_failures do
      first = described_class.ensure!([ plain, shiny ]).values.map(&:id)

      expect(described_class.ensure!([ plain, shiny ]).values.map(&:id)).to eq(first)
      expect(described_class.count).to eq(2)
    end
  end

  describe "the table (spec 085 decision 7, AC-3.7)" do
    it "is in the prices database, global, and a table the primary database lacks", :aggregate_failures do
      expect(described_class.connection_db_config.name).to eq("prices")
      expect(described_class.table_name).to eq("price_series")
      expect(described_class.column_names).not_to include("account_id", "user_id")
      expect(ActiveRecord::Base.lease_connection.table_exists?("price_series")).to be(false)
    end
  end
end
