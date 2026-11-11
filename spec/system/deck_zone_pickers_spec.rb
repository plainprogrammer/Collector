require "rails_helper"

# Spec 065 browser proofs: the collection filter and the lot form offer a deck's zones, and a deck name as long as a
# name can be keeps the pages inside a phone's width (decision 10, AC-6.1).
RSpec.describe "Deck zones in the pickers", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  def own(name, **options) = owned_printing(name, account:, **options)
  def tile_names = all(".c-tile__name").map(&:text)

  describe "the collection filter" do
    before do
      own("Lightning Bolt", location: deck.zone("main"))
      own("Opt", location: deck.zone("sideboard"))
      own("Shock")
    end

    it "narrows to one zone and widens to the whole deck", :aggregate_failures do
      visit collection_path(view: "grid")
      expect(tile_names).to contain_exactly("Lightning Bolt", "Opt", "Shock")
      select "Izzet Tempo › Main", from: "Location"
      click_on "Filter"
      expect(page).to have_css(".c-results__meta", exact_text: "1 of 3 items")
      expect([ tile_names, page.has_select?("Location", selected: "Izzet Tempo › Main") ]).to eq([ [ "Lightning Bolt" ], true ])
      select "Izzet Tempo (all zones)", from: "Location"
      click_on "Filter"
      expect(page).to have_css(".c-results__meta", exact_text: "2 of 3 items")
      expect([ tile_names, page.has_select?("Location", selected: "Izzet Tempo (all zones)") ]).to eq([ [ "Lightning Bolt", "Opt" ], true ])
    end
  end

  describe "a deck name of 60 characters in a 360px frame" do
    let!(:lot) { own("Lightning Bolt", quantity: 2, location: deck.zone("main")) }

    it "holds the collection page and the lot form inside the frame when the name is one unbroken word", :aggregate_failures do
      deck.location.update!(name: "W" * 60)
      expect(open_in_narrow_frame(collection_path(view: "grid"), width: 360, ready: ".c-filterbar__filters select")).to eq([ 360, true ])
      expect(open_in_narrow_frame(new_catalog_entry_lot_path(lot.entry), width: 360, ready: "select#lot_location_id")).to eq([ 360, true ])
    end

    # An unbroken 60-character name still widens Move copies' page head (its stats line shows the lot's place); that
    # is the same for a place since spec 032, so the example uses a name of words, which wraps.
    it "holds Move copies inside the frame when the name is words", :aggregate_failures do
      deck.location.update!(name: "#{'Izzet Tempo ' * 4}Izzet Tempo!")
      expect(open_in_narrow_frame(new_lot_move_path(lot), width: 360, ready: "select#move_location_id")).to eq([ 360, true ])
    end
  end

  describe "the lot form's Location select" do
    it "adds a copy to a zone chosen from the Decks group", :aggregate_failures do
      entry = create(:mtg_printing, finishes: %w[nonfoil foil]).entry
      deck
      visit new_catalog_entry_lot_path(entry)
      select "Izzet Tempo › Sideboard", from: "Location"
      click_on "Add to collection"
      expect(page).to have_css("#copies td", exact_text: "Izzet Tempo › Sideboard")
      expect(account.lots.pluck(:catalog_entry_id, :location_id)).to eq([ [ entry.id, deck.zone("sideboard").id ] ])
    end
  end
end
