require "rails_helper"

# Spec 062: a deck's own data, its rename and its removal; the records' consistency rules (AC-9.5).
RSpec.describe Deck, type: :model do
  let(:account) { create(:user).account }
  let!(:deck) { create(:deck, account:) }

  it "is named by its location and by the location's id in a route (decision 4)", :aggregate_failures do
    expect(deck.name).to eq("Izzet Tempo")
    expect(deck.to_param).to eq(deck.location_id.to_s)
  end

  it "knows its zones in the format's order and finds one by key", :aggregate_failures do
    expect(deck.zones.map(&:zone)).to eq(%w[main sideboard considering])
    expect(deck.zone("sideboard")).to have_attributes(zone: "sideboard", parent_id: deck.location_id)
    expect { deck.zone("commander") }.to raise_error(ActiveRecord::RecordNotFound)
  end

  describe "#format_name" do
    it "is the registered name, or the key when it is no longer registered", :aggregate_failures do
      expect(deck.format_name).to eq("Modern")
      deck.format = "retired"
      expect(deck.format_name).to eq("retired")
    end
  end

  describe "#rename" do
    it "accepts a change of case alone and keeps the zones, the format and the lots (AC-2.2, AC-2.3, AC-2.5)", :aggregate_failures do
      lot = create_lot_in_zone(deck, "main", quantity: 3)
      zones = deck.zones.pluck(:id, :zone, :name)

      expect(deck.rename("izzet tempo")).to be(true)
      expect(deck.reload.name).to eq("izzet tempo")
      expect(deck.format).to eq("modern")
      expect(deck.zones.pluck(:id, :zone, :name)).to eq(zones)
      expect(lot.reload).to have_attributes(quantity: 3, lot_key: Lot.key_for(nil, nil, nil, deck.zone("main").id))
      expect(lot.location.reload.label).to eq("izzet tempo › Main")
    end

    it "refuses a name a place or another deck has, with the taken sentence (AC-2.3)", :aggregate_failures do
      create(:location, account:, name: "Binder")
      create(:deck, account:, name: "Other")

      [ "binder", "OTHER" ].each do |taken|
        expect(deck.rename(taken)).to be(false)
        expect(deck.location.errors[:name]).to eq([ "You already have a location called “#{taken}”." ])
        expect(deck.reload.name).to eq("Izzet Tempo")
      end
    end

    it "refuses a blank name", :aggregate_failures do
      expect(deck.rename(" ")).to be(false)
      expect(deck.location.errors[:name]).to eq([ Location::MESSAGES[:blank] ])
    end
  end

  describe "#remove!" do
    it "removes the location, the row and the zones and nothing else (AC-3.2)", :aggregate_failures do
      other = create(:deck, account:, name: "Other")
      place = create(:location, account:)
      kept = create(:lot, account:, location: place)

      deck.remove!

      expect(Location.where(id: [ deck.location_id ] + deck.zones.map(&:id))).to be_empty
      expect(described_class.exists?(deck.id)).to be(false)
      expect(other.reload.zones.count).to eq(3)
      expect([ place.reload, kept.reload ]).to all(be_persisted)
    end

    it "is refused by the database when a lot sits in a zone, leaving every row (AC-3.5)", :aggregate_failures do
      create_lot_in_zone(deck, "sideboard")

      expect { deck.remove! }.to raise_error(ActiveRecord::InvalidForeignKey)
      expect(described_class.exists?(deck.id)).to be(true)
      expect(Location.where(parent_id: deck.location_id).count).to eq(3)
    end
  end

  describe "#holdings" do
    it "counts the lots of every zone together" do
      create_lot_in_zone(deck, "main", quantity: 4)
      create_lot_in_zone(deck, "considering", quantity: 2)
      create(:lot, account:, location: create(:location, account:), quantity: 9)

      expect(deck.holdings.total).to eq(Location::Holdings::Count.new(lots: 2, copies: 6))
    end
  end

  describe "consistency (AC-9.5)" do
    def build(**attrs) = described_class.new(account:, collectible_type: "mtg", format: "modern", **attrs)

    it "needs its location to be a deck of its own account", :aggregate_failures do
      place = create(:location, account:)
      other_deck = create(:deck, account: create(:user).account, name: "Theirs")

      expect(build(location: deck.zones.first)).not_to be_valid
      expect(build(location: place)).not_to be_valid
      expect(build(location: other_deck.location)).not_to be_valid
      expect(build(location: account.locations.create!(name: "Free deck", kind: "deck"))).to be_valid
    end

    it "needs a type and a format" do
      expect(build(location: nil, collectible_type: "", format: "")).not_to be_valid
    end

    it "has one row per location (the index)" do
      expect { build(location: deck.location).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
