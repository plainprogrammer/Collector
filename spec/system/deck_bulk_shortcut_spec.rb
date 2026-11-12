require "rails_helper"

# Spec 067: the deck refusal page's shortcut in a browser, end to end, at 360px, both themes, and with the keyboard.
RSpec.describe "Open a deck's lots in bulk mode", type: :system do
  context "with scripting" do
    let!(:user) { system_sign_in_as(create(:user)) }
    let(:account) { user.account }
    let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }

    before { create(:location, account:, name: "Long box") } # the destination; reached by its name

    it "empties a deck from its refusal page through Move to… and on to its removal (AC-3.1, AC-2.2, AC-2.3)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario: refusal, bulk mode, move, then the removal it unlocks
      create_lot_in_zone(deck, "main", quantity: 2)
      create_lot_in_zone(deck, "sideboard", quantity: 3)
      visit decks_path
      click_on "Remove Izzet Tempo"
      expect(page).to have_css("h1", text: "“Izzet Tempo” isn't empty")

      click_on "Move them in bulk mode"
      expect(page).to have_css(".c-bulkbar__count", exact_text: "All 5 items selected")
      expect(page).to have_css("tbody tr[aria-selected=true]", count: 2)
      within(".c-bulkbar__extra") { click_on "Move to…" }
      expect(page).to have_css("h1", exact_text: "Move 5 items")
      select "Long box", from: "To"
      click_on "Move"
      expect(page).to have_css("#status", text: "Moved 5 items to Long box.")
      expect(page).to have_text("No cards in your collection are in “Izzet Tempo”.")
      expect(page).to have_css(".c-bulkbar__count", exact_text: "0 of 0 selected") # a move under a deck filter restarts the selection empty (spec 065 decision 12)
      expect(account.lots.where(location: deck.zones)).to be_empty

      visit decks_path
      click_on "Remove Izzet Tempo"
      expect(page).to have_css("h1", text: "Remove Izzet Tempo?")
      click_on "Remove"
      expect(page).to have_css("#status", text: "Removed “Izzet Tempo”.")
    end

    it "works with the keyboard alone: tab to the button and press enter (Accessibility NFR)", :aggregate_failures do
      create_lot_in_zone(deck, "main", quantity: 4)
      visit new_deck_removal_path(deck)

      expect(tab_to_text("Move them in bulk mode")).to be(true)
      ring = page.evaluate_script("(() => { const el = document.activeElement; const style = getComputedStyle(el); return el.matches(':focus-visible') && style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0 })()")
      expect(ring).to be(true) # a visible focus ring (Accessibility NFR)
      page.driver.browser.action.send_keys(:enter).perform
      expect(page).to have_css(".c-bulkbar__count", exact_text: "All 4 items selected")
    end

    it "fits at 360px in both themes with 44px targets and the button first (AC-5.2)", :aggregate_failures do
      create_lot_in_zone(deck, "main", quantity: 3)

      %w[light dark].each do |theme|
        expect(open_in_narrow_frame(new_deck_removal_path(deck), width: 360, ready: "main")).to eq([ 360, true ])
        within_narrow_frame do
          page.execute_script("document.documentElement.setAttribute('data-theme', arguments[0])", theme)
          expect(page_fits_sideways?).to be(true), theme
          small = page.evaluate_script("[...document.querySelectorAll('main a, main button')].filter((el) => { const box = el.getBoundingClientRect(); return box.height < 44 || box.width < 44 }).map((el) => el.outerHTML.slice(0, 60))")
          expect(small).to eq([]), theme
          expect(page.evaluate_script("document.querySelector('main .c-form__actions').firstElementChild.textContent.trim()")).to start_with("Move them in bulk mode")
        end
      end
    end
  end

  # AC-5.1, AC-3.1: the shortcut is a plain form button, so it works with no script at all. rack_test runs none; the hook
  # in spec/support/system.rb picks Firefox before each system example, and this group's own hook runs after it and wins.
  context "without scripting" do
    before { driven_by :rack_test } # declared before the let! that signs in, so sign-in goes through rack_test too

    let!(:user) { system_sign_in_as(create(:user)) }
    let!(:deck) { create(:deck, account: user.account, name: "Izzet Tempo") }

    it "empties a deck from its refusal page through Move to… and on to its removal (AC-5.1, AC-3.1)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario: refusal, bulk mode, move, then the removal it unlocks
      expect(page.driver).to be_a(Capybara::RackTest::Driver) # the example would prove nothing under a browser that runs script
      create(:location, account: user.account, name: "Long box") # the destination; reached by its name
      create_lot_in_zone(deck, "main", quantity: 2)
      create_lot_in_zone(deck, "sideboard", quantity: 3)
      visit decks_path
      click_on "Remove Izzet Tempo"
      expect(page).to have_css("h1", text: "“Izzet Tempo” isn't empty")

      click_on "Move them in bulk mode"
      expect(page).to have_css(".c-bulkbar__count", exact_text: "All 5 items selected")
      expect(page).to have_css("tbody tr[aria-selected=true]", count: 2)
      within(".c-bulkbar__extra") { click_on "Move to…" }
      expect(page).to have_css("h1", exact_text: "Move 5 items")
      select "Long box", from: "To"
      click_on "Move"
      expect(page).to have_css("#status", text: "Moved 5 items to Long box.")
      expect(page).to have_text("No cards in your collection are in “Izzet Tempo”.")
      expect(page).to have_css(".c-bulkbar__count", exact_text: "0 of 0 selected")
      expect(user.account.lots.where(location: deck.zones)).to be_empty

      visit decks_path
      click_on "Remove Izzet Tempo"
      expect(page).to have_css("h1", text: "Remove Izzet Tempo?")
      click_on "Remove"
      expect(page).to have_css("#status", text: "Removed “Izzet Tempo”.")
    end
  end
end
