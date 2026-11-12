require "rails_helper"

# Spec 073 AC-4.1: card page, then the deck's name in "In decks", then the deck page, with no scripting.
RSpec.describe "Card page to deck page without scripting", type: :system do
  before { driven_by :rack_test } # an instance method: before the `let!` that signs in, or the sign-in goes through Firefox

  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:card) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt")).entry }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  it "follows the deck's name from the card page to that deck's page, which lists the card", :aggregate_failures do
    expect(page.driver).to be_a(Capybara::RackTest::Driver)
    create_lot_in_zone(deck, "main", entry: card, quantity: 2)
    visit catalog_entry_path(card)
    within("#in-decks") { click_link "Izzet Tempo" }

    expect(page).to have_current_path(deck_path(deck))
    expect(page).to have_css("h1", text: "Izzet Tempo")
    expect(page).to have_css(".c-zone table", text: "Lightning Bolt")
    expect(page).to have_no_css("#in-decks") # the section is the card page's, not the deck page's
    expect(page).to have_no_text("In decks")
  end
end
