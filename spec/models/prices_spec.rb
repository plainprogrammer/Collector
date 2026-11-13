require "rails_helper"

RSpec.describe Prices, type: :model do
  describe "the registry (spec 085 decision 11, AC-1.3)" do
    around do |example|
      original = described_class.sources.dup
      described_class.sources["fake_source"] = "FakePriceSource"
      described_class.sources["aaa_other"] = "OtherFakePriceSource"
      example.run
    ensure
      described_class.sources.replace(original)
    end

    it "finds a source class by its key", :aggregate_failures do
      expect(described_class.source_class("fake_source")).to eq(FakePriceSource)
      expect { described_class.source_class("nope") }.to raise_error(ArgumentError, /unknown price source: nope/)
    end

    it "lists the sources of a collectible type in key order, and none for a type without one", :aggregate_failures do
      expect(described_class.sources_for("widgets")).to eq([ OtherFakePriceSource, FakePriceSource ])
      expect(described_class.sources_for("gadgets")).to eq([])
    end
  end

  describe "the registered sources (spec 085, AC-1.6)" do
    it "each meet the contract, under their own key, for a collectible the catalog has", :aggregate_failures do
      expect(described_class.sources.keys).to include("scryfall")
      described_class.sources.each do |key, class_name|
        source_class = class_name.constantize

        expect(Prices::Sources.verify!(source_class)).to eq(source_class)
        expect(source_class.key).to eq(key)
        expect(Catalog.sources).to have_key(source_class.collectible_type)
      end
      expect(described_class.source_class("scryfall")).to eq(MTG::Scryfall::PriceQuotes)
      expect(described_class.sources_for("mtg")).to eq([ MTG::Scryfall::PriceQuotes ])
    end
  end
end
