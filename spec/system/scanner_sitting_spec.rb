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

  it "fits a 360px screen with a long sitting, never scrolling sideways (NFR Accessibility)", :aggregate_failures do
    12.times { Scanner::Sitting.add!(account: user.account, printing:, finish: "foil", reading_key: format("%x", it) * 32) }
    visit collection_path
    expect(open_in_narrow_frame(scanner_path, width: 360, ready: ".c-scanner__stage:not([hidden])")).to eq([ 360, true ])
    within_narrow_frame do
      expect(page.evaluate_script("document.documentElement.scrollWidth")).to be <= 360
      expect(page.evaluate_script(%(document.querySelector(".c-scanner__shutter").getBoundingClientRect().top))).to be >= 800 * 2 / 3
    end
  end
end
