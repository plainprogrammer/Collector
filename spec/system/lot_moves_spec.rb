require "rails_helper"

# Spec 032 AC-3.12 and AC-5.6: Move copies by keyboard on a phone, and emptying a location one lot at a time.
RSpec.describe "Lot moves", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }
  let!(:blue) { create(:location, account:, name: "Blue binder") }
  let!(:box) { create(:location, account:, name: "Long box") }

  # Opens a lot's actions menu with Enter and walks to "Move copies" by Tab, as a keyboard does.
  def open_move_by_keyboard
    summary = find("#copies summary", match: :first)
    summary.send_keys(:enter)
    expect(page).to have_css("#copies .c-menu__item", text: "Move copies")
    40.times do
      break if page.evaluate_script("document.activeElement.textContent.trim() === 'Move copies'")

      page.driver.browser.action.send_keys(:tab).perform
    end
    page.driver.browser.action.send_keys(:enter).perform
  end

  def move_to_box(lot)
    visit new_lot_move_path(lot)
    select "Long box", from: "To"
    click_on "Move"
    expect(page).to have_css("#status", text: "Moved")
  end

  it "moves 2 of 4 copies and cancels another move, with the keyboard, at 360px (AC-3.12)", :aggregate_failures do
    lot = create(:lot, account:, entry:, quantity: 4, location: box)
    visit catalog_entry_path(entry)
    expect(open_in_narrow_frame(new_lot_move_path(lot), width: 360, ready: "main")).to eq([ 360, true ])
    visit catalog_entry_path(entry)
    open_move_by_keyboard
    expect(page).to have_css("h1", text: "Move copies of")
    fill_in "Copies", with: "2"
    select "Blue binder", from: "To"
    click_on "Move"
    expect(page).to have_css("#status", text: "Moved 2 ×")
    expect(account.lots.pluck(:location_id, :quantity)).to contain_exactly([ box.id, 2 ], [ blue.id, 2 ])

    open_move_by_keyboard
    click_on "Cancel"
    expect(page).to have_css("#copies")
    expect(account.lots.pluck(:quantity).sort).to eq([ 2, 2 ])
  end

  it "empties a location one lot at a time, then removes it (AC-5.6)", :aggregate_failures do
    first = create(:lot, account:, entry:, quantity: 2, location: blue)
    second = create(:lot, account:, entry:, quantity: 3, finish: "foil", location: blue)
    visit new_location_removal_path(blue)
    expect(page).to have_css("h1", text: "isn't empty")
    expect(page).to have_no_button("Remove")

    [ first, second ].each { |lot| move_to_box(lot) }

    visit new_location_removal_path(blue)
    click_on "Remove"
    expect(page).to have_css("#status", text: "Removed “Blue binder”.")
    expect(account.lots.pluck(:location_id)).to all(eq(box.id))
    expect(account.lots.count).to eq(2)
  end
end
