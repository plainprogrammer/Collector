require "rails_helper"

# Spec 059: the shortcut in a browser, end to end, at 360px, both themes, and with the keyboard.
RSpec.describe "Open a location's lots in bulk mode", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let!(:blue) { create(:location, account:, name: "Blue binder") }

  before { create(:location, account:, name: "Long box") } # the destination; reached by its name

  it "empties a location from its refusal page through Move to… and on to its removal (AC-3.1, AC-2.2, AC-2.3)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario: refusal, bulk mode, move, then the removal it unlocks
    owned_printing("Card A", account:, location: blue, quantity: 2)
    owned_printing("Card B", account:, location: blue, quantity: 3)
    visit locations_path
    click_on "Remove Blue binder"
    expect(page).to have_css("h1", text: "“Blue binder” isn't empty")

    click_on "Move them in bulk mode"
    expect(page).to have_css(".c-bulkbar__count", exact_text: "All 5 items selected")
    expect(page).to have_css("tbody tr[aria-selected=true]", count: 2)
    within(".c-bulkbar__extra") { click_on "Move to…" }
    expect(page).to have_css("h1", exact_text: "Move 5 items")
    select "Long box", from: "To"
    click_on "Move"
    expect(page).to have_css("#status", text: "Moved 5 items to Long box.")
    expect(account.lots.where(location: blue)).to be_empty

    visit locations_path
    click_on "Remove Blue binder"
    expect(page).to have_css("h1", text: "Remove Blue binder?")
    click_on "Remove"
    expect(page).to have_css("#status", text: "Removed “Blue binder”.")
  end

  it "works with the keyboard alone: tab to the button and press enter (Accessibility NFR)", :aggregate_failures do
    owned_printing(account:, location: blue, quantity: 4)
    visit new_location_removal_path(blue)

    expect(tab_to("Move them in bulk mode")).to be(true)
    ring = page.evaluate_script("(() => { const el = document.activeElement; const style = getComputedStyle(el); return el.matches(':focus-visible') && style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0 })()")
    expect(ring).to be(true) # a visible focus ring (Accessibility NFR)
    page.driver.browser.action.send_keys(:enter).perform
    expect(page).to have_css(".c-bulkbar__count", exact_text: "All 4 items selected")
  end

  it "fits at 360px in both themes with 44px targets and the button first (AC-5.2)", :aggregate_failures do
    owned_printing(account:, location: blue, quantity: 3)

    %w[light dark].each do |theme|
      expect(open_in_narrow_frame(new_location_removal_path(blue), width: 360, ready: "main")).to eq([ 360, true ])
      within_narrow_frame do
        page.execute_script("document.documentElement.setAttribute('data-theme', arguments[0])", theme)
        expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true), theme
        small = page.evaluate_script("[...document.querySelectorAll('main a, main button')].filter((el) => { const box = el.getBoundingClientRect(); return box.height < 44 || box.width < 44 }).map((el) => el.outerHTML.slice(0, 60))")
        expect(small).to eq([]), theme
        expect(page.evaluate_script("document.querySelector('main .c-form__actions').firstElementChild.textContent.trim()")).to start_with("Move them in bulk mode")
      end
    end
  end
end
