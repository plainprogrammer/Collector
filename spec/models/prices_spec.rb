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
end
