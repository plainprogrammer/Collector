require "rails_helper"

RSpec.describe ScannersHelper, type: :helper do
  let(:reading_class) { Data.define(:art_status, :overruled, :overruled_scope) }

  def reading(art_status, overruled = nil, overruled_scope = nil) = reading_class.new(art_status, overruled, overruled_scope)

  it "names the artwork's outcome for a reading sent with artworks, and nothing otherwise (AC-7.1)", :aggregate_failures do
    expect(%i[matched similar no_match].map { helper.scanner_art_outcome(reading(it)) }).to eq([ "Matched", "Looks similar", "No match" ])
    expect(helper.scanner_art_outcome(reading(nil))).to be_nil
  end

  it "says what confident art overruled, the name or the collector line, and whether the card or the printing (AC-7.4)" do
    notes = [ %i[name card], %i[name printing], %i[collector_line card], %i[collector_line printing] ]
      .map { |overruled, scope| helper.scanner_overrule_note(reading(:matched, overruled, scope)) }

    expect(notes).to eq([
      "The artwork matches a different card from the one the name suggests. The artwork's match is first.",
      "The artwork matches a different printing from the one the name suggests. The artwork's match is first.",
      "The artwork matches a different card from the one the collector line suggests. The artwork's match is first.",
      "The artwork matches a different printing from the one the collector line suggests. The artwork's match is first."
    ])
  end

  it "has no note when art overruled nothing" do
    expect(helper.scanner_overrule_note(reading(:matched))).to be_nil
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
