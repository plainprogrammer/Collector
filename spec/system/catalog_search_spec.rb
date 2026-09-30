require "rails_helper"

RSpec.describe "Card search", type: :system do
  it "finds a card and opens a printing", :aggregate_failures do
    system_sign_in_as(create(:user))
    set = create(:catalog_set, code: "m10", name: "Magic 2010")
    entry = create(:catalog_entry, set:, name: "Lightning Bolt", identity: create(:catalog_identity, name: "Lightning Bolt"))
    create(:mtg_printing, entry:)

    visit catalog_entries_path
    fill_in "Card name", with: "bolt"
    click_on "Search"

    expect(page).to have_css("h2", text: "Lightning Bolt")
    click_on "Lightning Bolt"
    expect(page).to have_css("h1", text: "Lightning Bolt")
  end
end
