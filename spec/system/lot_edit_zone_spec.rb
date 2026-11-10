require "rails_helper"

# Spec 062 AC-5.5: Edit copy of a lot in a deck's zone shows its place as text, and saving keeps the lot in its zone (a select of
# places, which has no option for a zone, would have unplaced it).
RSpec.describe "Edit copy of a lot in a zone", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }
  let!(:lot) { create(:lot, account:, entry:, quantity: 2, location: deck.zone("main")) }

  it "shows the place as text, saves a new quantity and keeps the lot in its zone", :aggregate_failures do
    visit edit_lot_path(lot)
    expect(page).to have_css(".c-field__static", exact_text: "Izzet Tempo › Main")
    expect(page).to have_no_select("Location")
    expect(page).to have_no_css("select[name='lot[location_id]']")
    fill_in "Quantity", with: "5"
    click_on "Save"
    expect(page).to have_css("#status", text: "Saved.")
    expect(page).to have_css("#copies td", exact_text: "Izzet Tempo › Main")
    expect(lot.reload.attributes.values_at("quantity", "location_id")).to eq([ 5, deck.zone("main").id ])
  end

  it "wraps a long deck name inside a phone's width", :aggregate_failures do
    deck.location.update!(name: "W" * 60)
    expect(open_in_narrow_frame(edit_lot_path(lot), width: 360, ready: ".c-field__static")).to eq([ 360, true ])
    within_narrow_frame { expect(page).to have_css(".c-field__static", text: "W" * 60) }
  end
end
