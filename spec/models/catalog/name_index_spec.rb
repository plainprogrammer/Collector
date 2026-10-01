require "rails_helper"

RSpec.describe Catalog::NameIndex, type: :model do
  subject(:index) { described_class.new("mtg") }

  def card(name, faces: [ name ], retired: false)
    identity = create(:catalog_identity, name:)
    entry = create(:catalog_entry, identity:, name:, retired_at: (1.day.ago if retired))
    create(:mtg_printing, entry:, faces: faces.map { { "name" => it } })
    identity
  end

  def top(text, limit: 3) = index.search(text, limit:).map { Catalog::Identity.find(it.identity_id).name }

  before do
    [ "Lightning Bolt", "Lightning Helix", "Aether Vial", "Ox", "Cosmic Hunger", "_____" ].each { card(it) }
    card("Fire // Ice", faces: %w[Fire Ice])
    card("Retired Card", retired: true)
    index.rebuild
  end

  it "indexes each searchable card's name and the face names of multi-face cards, idempotently", :aggregate_failures do
    expect(index.rebuild).to eq(9)
    expect(Catalog::Name.where(collectible_type: "mtg").count).to eq(9)
    expect(index).to be_populated
    expect(described_class.new("other", source_class: FakeCatalogSource)).not_to be_populated
  end

  it "finds a card by its exact name, a misread name or a ligature", :aggregate_failures do
    expect(top("Lightning Bolt").first).to eq("Lightning Bolt")
    expect(top("Lightnlng Bo1t").first).to eq("Lightning Bolt")
    expect(top("Æther Vial").first).to eq("Aether Vial")
  end

  it "maps a face name to its card, once per card", :aggregate_failures do
    expect(top("Fire").first).to eq("Fire // Ice")
    expect(index.search("Fire").map(&:identity_id).tally.values).to all(eq(1))
  end

  it "takes the longest mostly-alphabetic line once short tokens are dropped (AC-3.4)" do
    expect(top("A) ae ea i Rd TE NC DORA AA Sa pr\nCosmic Hunger")).to include("Cosmic Hunger")
  end

  it "matches short queries within one edit (AC-3.5)", :aggregate_failures do
    expect(top("0x")).to include("Ox")
    expect(top("Ixe")).to include("Fire // Ice")
  end

  it "matches text that normalises to nothing exactly (AC-3.5)" do
    expect(top("_____")).to eq([ "_____" ])
  end

  it "leaves out retired printings, returns at most the limit, and nothing for noise", :aggregate_failures do
    expect(top("Retired Card")).not_to include("Retired Card")
    expect(top("Lightning", limit: 1)).to eq([ "Lightning Bolt" ])
    expect(index.search(" -- ")).to eq([])
  end

  describe ".clean" do
    it "keeps a short name when nothing longer survives", :aggregate_failures do
      expect(described_class.clean("Ox")).to eq("Ox")
      expect(described_class.clean("A) ae ea i Rd TE NC DORA AA Sa pr\nCosmic Hunger")).to eq("Cosmic Hunger")
    end
  end
end
