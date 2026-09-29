require "rails_helper"

RSpec.describe Catalog, type: :model do
  it "keeps MTG vocabulary out of the core catalog tables" do
    mtg_terms = /mana|colou?r|power|toughness|loyalty|type_line|oracle|rules|legal|face|rarity|finishes|frame|border|security_stamp/
    columns = [ Catalog::Set, Catalog::Identity, Catalog::Entry, Catalog::RefreshRun ].flat_map(&:column_names)

    expect(columns.grep(mtg_terms)).to be_empty
  end

  describe ".source_class" do
    it "returns the registered source class for a collectible type" do
      expect(described_class.source_class("mtg")).to eq(MTG::Scryfall::Source)
    end

    it "rejects unknown collectible types" do
      expect { described_class.source_class("pokemon") }.to raise_error(ArgumentError, /pokemon/)
    end
  end

  it "allows images and links only from registered sources' hosts" do
    expect(described_class.allowed_hosts).to contain_exactly("scryfall.com", "cards.scryfall.io", "svgs.scryfall.io")
  end
end
