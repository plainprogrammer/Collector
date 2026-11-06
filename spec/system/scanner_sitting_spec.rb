require "rails_helper"

RSpec.describe "The scanner's sitting", type: :system do
  let(:user) { create(:user) }
  let(:printing) do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
  end

  before do
    printing
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(user)
  end

  def add_by_scanning
    show_synthetic_card
    click_on "Capture"
    find("button[aria-label='Add Lightning Bolt MOM · 123 Foil']", wait: 30).click
  end

  it "survives signing out and resumes on the scanner, taking further adds (AC-3.3)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 1 card")
    visit more_path
    click_on "Sign out"
    system_sign_in_as(user)
    visit scanner_path
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 1 card")
    add_by_scanning
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 2 cards")
  end

  it "undoes an add in place, the camera still running (AC-4.1)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    page.execute_script("window.__marker = 'still here'")
    click_on "Undo"
    expect(page).to have_css("#status", text: "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(user.account.lots).to be_empty
  end

  def set_sitting(condition: nil, location: nil)
    select condition, from: "Condition" if condition
    select location, from: "Location" if location
    click_on "Set"
  end

  describe "a sitting's place (spec 040)" do
    def entry_metas = all("#scanner_sitting li .c-list__meta").map { it.text.squish }

    before do
      create(:location, account: user.account, name: "Blue binder")
      create(:location, account: user.account, name: "Long box")
    end

    it "opens a sitting in the chosen place, keeping the page and its camera (AC-1.1, AC-1.2)", :aggregate_failures do
      visit scanner_path
      expect(page).to have_select("Location", selected: "No location")
      expect(page).to have_no_css("#scanner_sitting h2")
      page.execute_script("window.__marker = 'still here'")
      set_sitting(location: "Blue binder")
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 0 cards, in Blue binder")
      expect(page).to have_css("#status", text: "Cards you scan now: condition not specified, in Blue binder.")
      expect(page.evaluate_script("window.__marker")).to eq("still here")
      expect(page).to have_css(".c-scanner__stage video", visible: :all)
    end

    it "scans into the place, and into another once it changes mid-sitting (AC-1.3, AC-2.1)", :aggregate_failures do
      visit scanner_path
      set_sitting(location: "Blue binder")
      add_by_scanning
      expect(page).to have_css("#status", text: "Added 1 × Lightning Bolt (MOM · 123, Foil) in Blue binder to your collection.")
      set_sitting(location: "Long box")
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 1 card, in Long box")
      add_by_scanning
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 2 cards, in Long box")
      expect(entry_metas).to match([ /in Long box/, /in Blue binder/ ])
      expect(user.account.lots.map { [ it.location.name, it.quantity ] }.sort).to eq([ [ "Blue binder", 1 ], [ "Long box", 1 ] ])
    end

    it "keeps the place on a reload, clears it with cards kept, and ends with the control on No location (AC-1.7, AC-1.8, AC-5.2)", :aggregate_failures do
      Scanner::Sitting.choose!(account: user.account, location: user.account.locations.find_by!(name: "Long box"))
      Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
      visit scanner_path
      expect(page).to have_select("Location", selected: "Long box")
      set_sitting(location: "No location")
      expect(page).to have_css("#scanner_sitting h2", exact_text: "This sitting: 1 card")
      click_on "Done"
      click_on "End sitting"
      expect(page).to have_select("Location", selected: "No location")
      set_sitting(location: "Blue binder")
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 0 cards, in Blue binder")
      expect(page).to have_no_text("Added 1 card in this sitting")
    end

    it "chooses a place with the keyboard alone (AC-7.1)", :aggregate_failures do
      visit scanner_path
      field = find_field("Location")
      field.select("Long box")
      field.send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.value")).to eq("Set")
      page.driver.browser.switch_to.active_element.send_keys(:enter)
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 0 cards, in Long box")
    end

    it "fits a 360px screen with a long location name, never scrolling sideways (AC-7.1)", :aggregate_failures do
      long = create(:location, account: user.account, name: "The second long box under the desk, left of the shelf")
      Scanner::Sitting.choose!(account: user.account, location: long)
      Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
      visit collection_path
      expect(open_in_narrow_frame(scanner_path, width: 360, ready: "#sitting_location_id")).to eq([ 360, true ])
      within_narrow_frame do
        expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 360
        expect(page).to have_css("#scanner_sitting h2", text: "in #{long.name}")
      end
    end
  end

  it "fits a 360px screen with a long sitting, never scrolling sideways (NFR Accessibility)", :aggregate_failures do
    12.times { Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: format("%x", it) * 32) }
    visit collection_path
    expect(open_in_narrow_frame(scanner_path, width: 360, ready: ".c-scanner__stage:not([hidden])")).to eq([ 360, true ])
    within_narrow_frame do
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 360
      expect(page.evaluate_script(%(document.querySelector(".c-scanner__shutter").getBoundingClientRect().top))).to be >= 800 * 2 / 3
    end
  end

  describe "a sitting's condition (spec 042)" do
    def entry_metas = all("#scanner_sitting li .c-list__meta").map { it.text.squish }

    it "opens a sitting with the condition, keeping the page and its camera (AC-1.2)", :aggregate_failures do
      visit scanner_path
      expect(page).to have_select("Condition", selected: "Not specified")
      expect(page).to have_no_select("Location")
      page.execute_script("window.__marker = 'still here'")
      set_sitting(condition: "Near mint (NM)")
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 0 cards, Near mint")
      expect(page).to have_css("#status", text: "Cards you scan now: Near mint.")
      expect(page.evaluate_script("window.__marker")).to eq("still here")
      expect(page).to have_css(".c-scanner__stage video", visible: :all)
    end

    it "scans into the condition, and into another once it changes mid-sitting (AC-1.3, AC-2.1)", :aggregate_failures do
      visit scanner_path
      set_sitting(condition: "Near mint (NM)")
      add_by_scanning
      expect(page).to have_css("#status", text: "Added 1 × Lightning Bolt (MOM · 123, Foil, NM) to your collection.")
      set_sitting(condition: "Lightly played (LP)")
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 1 card, Lightly played")
      add_by_scanning
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 2 cards, Lightly played")
      expect(entry_metas).to match([ /Foil · LP ·/, /Foil · NM ·/ ])
      expect(user.account.lots.map { [ it.condition, it.quantity ] }.sort).to eq([ [ "lightly_played", 1 ], [ "near_mint", 1 ] ])
    end

    it "keeps the condition on a reload, clears it with cards kept, and ends with the control on Not specified (AC-1.7, AC-1.8, AC-5.2)", :aggregate_failures do
      Scanner::Sitting.choose!(account: user.account, condition: "near_mint")
      Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
      visit scanner_path
      expect(page).to have_select("Condition", selected: "Near mint (NM)")
      set_sitting(condition: "Not specified")
      expect(page).to have_css("#scanner_sitting h2", exact_text: "This sitting: 1 card")
      click_on "Done"
      click_on "End sitting"
      expect(page).to have_select("Condition", selected: "Not specified")
      set_sitting(condition: "Damaged (DMG)")
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 0 cards, Damaged")
      expect(page).to have_no_text("Added 1 card in this sitting")
    end

    it "reaches Condition, Location and Set with the keyboard alone (AC-7.1)", :aggregate_failures do
      create(:location, account: user.account, name: "Long box")
      visit scanner_path
      field = find_field("Condition")
      field.select("Near mint (NM)")
      field.send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.id")).to eq("sitting_location_id")
      page.driver.browser.switch_to.active_element.send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.value")).to eq("Set")
      page.driver.browser.switch_to.active_element.send_keys(:enter)
      expect(page).to have_css("#scanner_sitting h2", text: "This sitting: 0 cards, Near mint")
    end

    it "fits 390px and a desktop width with both selects and a long location name, never scrolling sideways (AC-7.1)", :aggregate_failures do
      long = create(:location, account: user.account, name: "The second long box under the desk, left of the shelf")
      Scanner::Sitting.choose!(account: user.account, condition: "moderately_played", location: long)
      Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: "a" * 32)
      visit collection_path
      expect(open_in_narrow_frame(scanner_path, width: 390, ready: "#sitting_condition")).to eq([ 390, true ])
      within_narrow_frame do
        expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 390
        expect(page.evaluate_script(%(Array.from(document.querySelectorAll("#scanner_sitting select, #scanner_sitting input[type=submit]")).every(el => el.getBoundingClientRect().right <= document.getElementById("scanner_sitting").getBoundingClientRect().right + 1)))).to be(true)
      end
      page.current_window.resize_to(1280, 900)
      visit scanner_path
      expect(page).to have_css("#scanner_sitting select#sitting_condition")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    end
  end
end
