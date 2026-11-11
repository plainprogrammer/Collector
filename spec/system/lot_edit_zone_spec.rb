require "rails_helper"

# Spec 065 AC-1.6 (supersedes spec 062 AC-5.5): Edit copy of a lot in a deck's zone shows the zone in the Location select, and saving
# keeps the lot in its zone.
RSpec.describe "Edit copy of a lot in a zone", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }
  let!(:lot) { create(:lot, account:, entry:, quantity: 2, location: deck.zone("main")) }

  it "shows the zone chosen in the select, saves a new quantity and keeps the lot in its zone", :aggregate_failures do
    visit edit_lot_path(lot)
    expect(page).to have_select("Location", selected: "Izzet Tempo › Main")
    fill_in "Quantity", with: "5"
    click_on "Save"
    expect(page).to have_css("#status", text: "Saved.")
    expect(page).to have_css("#copies td", exact_text: "Izzet Tempo › Main")
    expect(lot.reload.attributes.values_at("quantity", "location_id")).to eq([ 5, deck.zone("main").id ])
  end

  it "keeps a long deck name inside a phone's width", :aggregate_failures do
    deck.location.update!(name: "W" * 60)
    expect(open_in_narrow_frame(edit_lot_path(lot), width: 360, ready: "select#lot_location_id")).to eq([ 360, true ])
  end
end
