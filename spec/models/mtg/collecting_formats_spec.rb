require "rails_helper"

# Spec 062 FR-2, decision 2: Magic's eight deck formats and their zones, as the extension registers them for the core's seam.
RSpec.describe MTG::Collecting, type: :model do
  let(:zones) { ->(format) { format.zones.map { [ it.key, it.name ] } } }
  let(:three) { [ %w[main Main], %w[sideboard Sideboard], %w[considering Considering] ] }

  describe ".formats" do
    subject(:formats) { described_class.formats }

    it "are Casual (the default), Standard, Pioneer, Modern, Legacy, Vintage, Pauper and Commander, in that order", :aggregate_failures do
      expect(formats.map(&:key)).to eq(%w[casual standard pioneer modern legacy vintage pauper commander])
      expect(formats.map(&:name)).to eq(%w[Casual Standard Pioneer Modern Legacy Vintage Pauper Commander])
      expect(formats.select(&:default).map(&:key)).to eq([ "casual" ])
    end

    it "give the seven constructed formats Main, Sideboard and Considering" do
      expect(formats.first(7).map { zones.call(it) }).to all(eq(three))
    end

    it "give Commander its own zone before Main, then Main and Considering" do
      expect(zones.call(formats.last)).to eq([ %w[commander Commander], %w[main Main], %w[considering Considering] ])
    end

    it "give every format the zone the core knows, Considering", :aggregate_failures do
      expect(formats.map { |format| format.zones.map(&:key).include?(Catalog::Formats::CONSIDERING) }).to all(be(true))
      expect(formats).to all(be_frozen)
    end

    it "are in the registration the boot check accepts" do
      expect(Catalog::Formats.verify!).to be(true)
    end
  end
end
