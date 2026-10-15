require "rails_helper"

RSpec.describe "Number entry", type: :system do
  let(:user) { create(:user) }
  let(:mh3) { create(:catalog_set, code: "mh3", name: "Modern Horizons 3", released_on: Date.new(2024, 6, 14)) }

  def printing(number, name)
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, set: mh3, number:, name:, identity: create(:catalog_identity, name:))).entry
  end

  # Sends keys to the number field, then waits for the list's heading and the focus back in the number (AC-2.2).
  def add_line(*keys, list:)
    find_field("Number").send_keys(*keys)
    expect(page).to have_css("#number_entry_list", text: list)
    expect(page).to have_css("#line_number:focus")
  end

  before do
    printing("12", "Flare of Duplication")
    printing("47", "Psychic Frog")
    printing("103", "Ocelot Pride")
    system_sign_in_as(user)
  end

  it "opens from the collection with the set field focused (AC-1.1)", :aggregate_failures do
    visit collection_path
    click_on "Add by number"
    expect(page).to have_css("h1", text: "Add by number")
    expect(page).to have_css("#number_entry_set:focus")
  end

  it "adds three lines from the keyboard alone, the number focused after each (AC-1.4, AC-2.2, AC-2.4, AC-2.13)", :aggregate_failures do
    visit collection_number_entry_path
    fill_in "Set", with: "MH3"
    find_field("Set").send_keys(:escape, :enter) # close the suggestions first
    expect(page).to have_css(".c-numentry__setname", text: "Modern Horizons 3")
    expect(page).to have_css("#line_number:focus")
    add_line("12", :enter, list: "This list: 1 line, 1 card")
    add_line("47", :tab, :backspace, "4", :enter, list: "This list: 2 lines, 5 cards")
    add_line("103", :tab, :tab, "f", :enter, list: "This list: 3 lines, 6 cards")
    expect(page).to have_select("Finish", selected: "Foil")
    expect(user.account.lots.map { [ it.entry.number, it.quantity, it.finish ] })
      .to contain_exactly([ "12", 1, "nonfoil" ], [ "47", 4, "nonfoil" ], [ "103", 1, "foil" ])
  end

  it "selects a rejected number so typing replaces it (AC-4.1)", :aggregate_failures do
    visit collection_number_entry_path(type: "mtg", set: "mh3", language: "en")
    find_field("Number").send_keys("999", :enter)
    expect(page).to have_css(".c-field__error", text: "No card numbered 999 in Modern Horizons 3 (EN).")
    expect(page).to have_css("#line_number:focus")
    expect(page.evaluate_script("[document.activeElement.selectionStart, document.activeElement.selectionEnd]")).to eq([ 0, 3 ])
    find_field("Number").send_keys("47", :enter)
    expect(page).to have_css("#number_entry_list", text: "Psychic Frog")
  end

  it "is reached from More and fits a 360px screen with a list (AC-1.2, NFR Accessibility)", :aggregate_failures do
    12.times { |index| NumberEntry.add!(account: user.account, entry: Catalog::Entry.find_by!(number: "47"), quantity: 1, finish: "foil", line_key: format("%032x", index)) }
    visit collection_path
    open_in_narrow_frame(more_path, width: 360, ready: ".c-more")
    within_narrow_frame do
      click_on "Add by number"
      expect(page).to have_css("h1", text: "Add by number")
    end
    expect(open_in_narrow_frame(collection_number_entry_path(type: "mtg", set: "mh3", language: "en"), width: 360, ready: "#line_number")).to eq([ 360, true ])
  end
end
