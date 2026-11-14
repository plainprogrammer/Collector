require "rails_helper"

RSpec.describe ScannersHelper, type: :helper do
  describe "the selection's sentences (spec 088 decision 8)" do
    let(:entries) do
      identity = create(:catalog_identity, name: "Lightning Bolt")
      [ [ "mom", "123", "March of the Machine" ], [ "2x2", "117", "Double Masters 2022" ] ].map do |code, number, set_name|
        set = create(:catalog_set, code:, name: set_name)
        create(:mtg_printing, entry: create(:catalog_entry, identity:, name: identity.name, set:, number:)).entry
      end
    end
    let(:printings) { selection(:printings, 14) }
    let(:cards) { selection(:cards, 3) }

    def selection(kind, total)
      band = Scanner::Selection::BANDS.fetch(:collector_line)
      items = entries.map { Scanner::Selection::Item.new(entry: it, rank: nil, band:, state: :guess) }
      Scanner::Selection.new(kind:, items:, total:, current: 0, limit: 20, key: "f" * 32)
    end


    describe "#selection_tail" do
      it "names the centred printing or card so the band's text changes with every swipe", :aggregate_failures do
        expect(helper.selection_tail(printings, 1)).to eq("Printing 2 of 14: Lightning Bolt, Double Masters 2022, 2X2 · 117.")
        expect(helper.selection_tail(cards, 0)).to eq("Card 1 of 3: Lightning Bolt, March of the Machine, MOM · 123.")
      end

      it "says what the more item offers" do
        expect(helper.selection_tail(printings, 2)).to eq("12 more printings. Show 20 more.")
      end
    end

    describe "#selection_position" do
      it "is the details block's position in words", :aggregate_failures do
        expect(helper.selection_position(printings, 1)).to eq("2 of 14 printings")
        expect(helper.selection_position(cards, 0)).to eq("1 of 3 possible cards")
      end
    end
  end

  describe "the condition in the sitting's copy (spec 042 decision 3)" do
    let(:printing) { create(:mtg_printing, entry: create(:catalog_entry, name: "Psychic Frog", set: create(:catalog_set, code: "mh3"), number: "47")).entry }
    let(:conditions) { Catalog.collecting_for("mtg").conditions }

    it "gives a condition's short label from the printing's vocabulary, and nil for none or an unknown key", :aggregate_failures do
      expect(helper.scanner_condition(printing, "near_mint")).to eq("NM")
      expect(helper.scanner_condition(printing, nil)).to be_nil
      expect(helper.scanner_condition(printing, "mint")).to be_nil
    end

    it "puts the condition after the finish inside the copy's parentheses, and leaves each out when unspecified", :aggregate_failures do
      expect(helper.scanner_copy(printing, "foil", "near_mint")).to eq("Psychic Frog (MH3 · 47, Foil, NM)")
      expect(helper.scanner_copy(printing, nil, "near_mint")).to eq("Psychic Frog (MH3 · 47, NM)")
      expect(helper.scanner_copy(printing, "foil")).to eq("Psychic Frog (MH3 · 47, Foil)")
    end

    it "lists the sitting's choices as words, only those that are set", :aggregate_failures do
      place = build_stubbed(:location, name: "Blue binder")
      expect(helper.sitting_choices(Scanner::Sitting.new(condition: "near_mint", location: place), conditions)).to eq([ "Near mint", "in Blue binder" ])
      expect(helper.sitting_choices(Scanner::Sitting.new(condition: "near_mint"), conditions)).to eq([ "Near mint" ])
      expect(helper.sitting_choices(Scanner::Sitting.new(location: place), conditions)).to eq([ "in Blue binder" ])
      expect(helper.sitting_choices(Scanner::Sitting.new, conditions)).to eq([])
    end
  end

  describe "the one-screen page's sentences (spec 082)" do
    let(:conditions) { Catalog.collecting_for("mtg").conditions }
    let(:account) { create(:account) }
    let(:binder) { create(:location, account:, name: "Blue binder") }

    describe "#scanner_destination" do
      it "names the place and the short condition in decision 7's four forms (spec 082 AC-1.4)", :aggregate_failures do
        expect(helper.scanner_destination(Scanner::Sitting.new(account:, condition: "near_mint", location: binder), conditions)).to eq("Blue binder · NM")
        expect(helper.scanner_destination(Scanner::Sitting.new(account:, location: binder), conditions)).to eq("Blue binder")
        expect(helper.scanner_destination(Scanner::Sitting.new(account:, condition: "near_mint"), conditions)).to eq("No location · NM")
        expect(helper.scanner_destination(nil, conditions)).to eq("No location")
      end

      it "reads a deck's zone as Deck › Zone, with the condition after it (spec 082 AC-1.4)", :aggregate_failures do
        zone = create(:deck, account:, name: "Izzet Tempo").zone("main")
        expect(helper.scanner_destination(Scanner::Sitting.new(account:, location: zone), conditions)).to eq("Izzet Tempo › Main")
        expect(helper.scanner_destination(Scanner::Sitting.new(account:, location: zone, condition: "near_mint"), conditions)).to eq("Izzet Tempo › Main · NM")
      end
    end

    describe "#sitting_title" do
      it "is today's heading, with no sitting too (spec 082 decision 9)", :aggregate_failures do
        sitting = Scanner::Sitting.new(account:, condition: "near_mint", location: binder)
        expect(helper.sitting_title(sitting, [ :one, :two ], conditions)).to eq("This sitting: 2 cards, Near mint, in Blue binder")
        expect(helper.sitting_title(nil, [], conditions)).to eq("This sitting: 0 cards")
      end
    end

    describe "#scanner_added" do
      it "is the after-add line's sentence (spec 082 decision 12, AC-5.1, AC-5.2)", :aggregate_failures do
        printing = create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123")).entry
        expect(helper.scanner_added(printing, "foil")).to eq("Added Lightning Bolt MOM · 123, foil")
        expect(helper.scanner_added(printing, nil)).to eq("Added Lightning Bolt MOM · 123")
      end
    end
  end
end
