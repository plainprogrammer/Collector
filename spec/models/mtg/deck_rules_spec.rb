require "rails_helper"

RSpec.describe MTG::DeckRules, type: :model do
  def entry(name = "Card", type_line: "Instant", text: nil, legalities: {}, record: true)
    entry = create(:catalog_entry, name:)
    create(:mtg_printing, entry:, legalities:, faces: [ { "name" => name, "type_line" => type_line, "oracle_text" => text, "image_uris" => {} } ]) if record
    Catalog::Entry.preload_extensions([ entry ]).first
  end

  def limit(format, entry) = described_class.for(format).copies.limit_for.call(entry)&.then { [ it.count, it.reason ] }
  def shape(rule) = [ rule.zone_keys, rule.min, rule.max ]

  describe ".for" do
    it "has size and copy rules for each constructed format", :aggregate_failures do
      %w[standard pioneer modern legacy vintage pauper].each do |key|
        rules = described_class.for(key)
        expect(rules.sizes.map { shape(it) }).to eq([ [ %w[main], 60, nil ], [ %w[sideboard], nil, 15 ] ])
        expect(rules.copies.zone_keys).to eq(%w[main sideboard])
      end
    end

    it "has Commander's exact size, a singleton copy rule, and none for casual or an unknown key", :aggregate_failures do
      commander = described_class.for("commander")
      expect(commander.sizes.map { shape(it) }).to eq([ [ %w[commander main], 100, 100 ] ])
      expect(commander.copies.zone_keys).to eq(%w[commander main])
      expect([ described_class.for("casual"), described_class.for("retired"), MTG::Collecting.deck_rules("casual") ]).to all(be_nil)
    end
  end

  describe "a card's limit" do
    it "is 4 in constructed formats and 1 in Commander", :aggregate_failures do
      bolt = entry("Lightning Bolt")
      expect([ limit("standard", bolt), limit("pauper", bolt), limit("vintage", bolt), limit("commander", bolt) ]).to eq([ [ 4, nil ], [ 4, nil ], [ 4, nil ], [ 1, nil ] ])
    end

    it "is none for a basic land, Snow-Covered ones included", :aggregate_failures do
      plains = entry("Plains", type_line: "Basic Land — Plains")
      snow = entry("Snow-Covered Island", type_line: "Basic Snow Land — Island")
      expect([ limit("standard", plains), limit("commander", snow) ]).to all(be_nil)
    end

    it "is none for any-number text, in every format", :aggregate_failures do
      rats = entry("Relentless Rats", type_line: "Creature — Rat", text: "Relentless Rats gets +1/+1 for each other creature you control named Relentless Rats.\nA deck can have any number of cards named Relentless Rats.")
      expect([ limit("modern", rats), limit("commander", rats) ]).to all(be_nil)
    end

    it "is the stated number for up-to text, in every format", :aggregate_failures do
      dwarves = entry("Seven Dwarves", type_line: "Creature — Dwarf", text: "Seven Dwarves gets +1/+1 for each other creature named Seven Dwarves you control.\nA deck can have up to seven cards named Seven Dwarves.")
      expect([ limit("standard", dwarves), limit("commander", dwarves) ]).to eq([ [ 7, nil ], [ 7, nil ] ])
    end

    it "is 1, restricted, in Vintage only", :aggregate_failures do
      lotus = entry("Black Lotus", type_line: "Artifact", legalities: { "vintage" => "restricted", "legacy" => "banned" })
      expect([ limit("vintage", lotus), limit("legacy", lotus) ]).to eq([ [ 1, "restricted to 1" ], [ 4, nil ] ])
    end

    it "is the ordinary limit for a printing with no card data, a basic land included", :aggregate_failures do
      bare = entry("Plains", record: false)
      expect([ limit("standard", bare), limit("commander", bare) ]).to eq([ [ 4, nil ], [ 1, nil ] ])
    end
  end
end
