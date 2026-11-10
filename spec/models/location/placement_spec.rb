require "rails_helper"

# Spec 062 decisions 1, 4 and 6, AC-6.12: how a lot's place is written in a file, keyed, resolved and labelled, in one module.
RSpec.describe Location::Placement, type: :model do
  describe ".label" do
    it "joins the deck's name and the zone's name" do
      expect(described_class.label("Main", "Izzet Tempo")).to eq("Izzet Tempo › Main")
    end
  end

  describe ".written" do
    it "is nil for no place, the name for a place and the deck and zone key for a zone", :aggregate_failures do
      expect(described_class.written(kind: nil, name: nil, zone: nil, deck_name: nil)).to be_nil
      expect(described_class.written(kind: "place", name: "Binder", zone: nil, deck_name: nil)).to eq("Binder")
      expect(described_class.written(kind: "deck_zone", name: "Main", zone: "main", deck_name: "Izzet Tempo")).to eq({ "deck" => "Izzet Tempo", "zone" => "main" })
    end

    it "refuses a kind a lot can't be in" do
      expect { described_class.written(kind: "deck", name: "Izzet", zone: nil, deck_name: nil) }.to raise_error(ArgumentError, /deck/)
    end
  end

  describe ".key" do
    it "is nil, the place's name key or the pair of the deck's key and the zone key", :aggregate_failures do
      expect(described_class.key(kind: nil, name_key: nil, zone: nil, deck_key: nil)).to be_nil
      expect(described_class.key(kind: "place", name_key: "binder", zone: nil, deck_key: nil)).to eq("binder")
      expect(described_class.key(kind: "deck_zone", name_key: "main", zone: "main", deck_key: "izzet tempo")).to eq([ "izzet tempo", "main" ])
    end
  end

  describe ".file_key" do
    it "reads a file's place into the same value the database's rows key to", :aggregate_failures do
      expect(described_class.file_key(nil)).to be_nil
      expect(described_class.file_key("  Binder ")).to eq("binder")
      expect(described_class.file_key({ "deck" => "  IZZET  Tempo ", "zone" => "main" })).to eq([ "izzet tempo", "main" ])
    end

    it "makes two spellings of one deck one key and keeps the zone key as it is", :aggregate_failures do
      expect(described_class.file_key({ "deck" => "Izzet", "zone" => "main" })).to eq(described_class.file_key({ "deck" => "izzet", "zone" => "main" }))
      expect(described_class.file_key({ "deck" => "Izzet", "zone" => "main" })).not_to eq(described_class.file_key({ "deck" => "Izzet", "zone" => "side" }))
    end

    it "never lets a place called Box equal the zone main of a deck called Box (AC-6.12)", :aggregate_failures do
      place = described_class.file_key("Box")
      zone = described_class.file_key({ "deck" => "Box", "zone" => "main" })

      expect(place).to eq("box")
      expect(zone).to eq([ "box", "main" ])
      expect(place).not_to eq(zone)
      expect(described_class.file_key("main")).not_to eq(described_class.file_key({ "deck" => "main", "zone" => "main" }))
    end

    it "refuses a value that is neither a name nor a deck and zone" do
      expect { described_class.file_key(3) }.to raise_error(ArgumentError)
    end
  end

  describe ".resolve" do
    let(:places) { { "binder" => 1 } }
    let(:zones) { { [ "izzet", "main" ] => 2 } }

    it "answers the location id of a key among the places or the zones, and nil for no place", :aggregate_failures do
      expect(described_class.resolve(nil, places:, zones:)).to be_nil
      expect(described_class.resolve("binder", places:, zones:)).to eq(1)
      expect(described_class.resolve([ "izzet", "main" ], places:, zones:)).to eq(2)
    end

    it "raises KeyError for a key that isn't there" do
      expect { described_class.resolve([ "izzet", "side" ], places:, zones:) }.to raise_error(KeyError)
    end
  end
end
