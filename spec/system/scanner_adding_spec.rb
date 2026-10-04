require "rails_helper"

RSpec.describe "Adding from the scanner", type: :system do
  let(:user) { create(:user) }
  let(:foil_button) { "button[aria-label='Add Lightning Bolt MOM · 123 Foil']" }

  before do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(user)
    visit scanner_path
  end

  # The server failure is the point of the example; Capybara would otherwise re-raise it once the example ends.
  around(:each, :server_error) do |example|
    raising, Capybara.raise_server_errors = Capybara.raise_server_errors, false
    example.run
  ensure
    Capybara.raise_server_errors = raising
  end

  def read_card
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
  end

  it "adds with one tap and is ready for the next card, the camera still running (AC-1.1, AC-1.3)", :aggregate_failures do
    read_card
    page.execute_script("window.__marker = 'still here'")
    expect(page).to have_css(".c-scanner__add button", text: "Nonfoil").and have_css(".c-scanner__add button", text: "Foil")
    find(foil_button).click
    expect(page).to have_css("#status", text: "Added 1 × Lightning Bolt (MOM · 123, Foil) to your collection.")
    expect(page).to have_no_css(".c-scanner__candidate")
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 1 card")
    expect(page).to have_button("Capture", disabled: false)
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(page.evaluate_script("window.__tracks.length === 1 && window.__tracks[0].readyState === 'live'")).to be(true)
    expect(user.account.lots.sole.finish).to eq("foil")
  end

  it "adds one copy even when both buttons are tapped at once (AC-1.4, AC-1.5)", :aggregate_failures do
    read_card
    page.execute_script("document.querySelectorAll('.c-scanner__add button').forEach((button) => button.click())")
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 1 card")
    expect(user.account.lots.sum(:quantity)).to eq(1)
  end

  it "adds from a picked photo and offers the picker again (AC-1.3)", :aggregate_failures do
    wait_for_scanner
    pick_synthetic_photo
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
    find(foil_button).click
    expect(page).to have_css("#status", text: "Added 1 × Lightning Bolt")
    expect(page).to have_field("Use a photo", type: "file", visible: :all, disabled: false)
  end

  it "sends you to sign in when your session ended before the add (Error Scenarios)" do
    read_card
    page.driver.browser.manage.delete_cookie("session_id")
    find(foil_button).click
    expect(page).to have_button("Sign in")
  end

  it "keeps the reading and offers the retry when the add fails on the server (Error Scenarios)", :aggregate_failures, :server_error do
    read_card
    page.execute_script("window.__marker = 'still here'")
    allow(Scanner::Sitting).to receive(:add!).and_raise(StandardError, "boom")
    find(foil_button).click
    expect(page).to have_css("#status", text: "That card wasn't added. Check your connection, then tap its add button again.")
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt")
    expect(page).to have_css("#{foil_button}:not([disabled])")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
  end

  it "opens Other printings in place and adds the one chosen (AC-2.2, AC-2.6)", :aggregate_failures do
    m10 = create(:catalog_set, code: "m10", name: "Magic 2010", released_on: Date.new(2009, 7, 17))
    older = create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity: Catalog::Identity.sole, name: "Lightning Bolt", set: m10, number: "146")).entry
    read_card
    page.execute_script("window.__marker = 'still here'")
    click_on "Other printings"
    expect(page).to have_css("#status", text: "Other printings of Lightning Bolt are below.")
    within("turbo-frame#scanner_printings") { find("button[aria-label='Add Lightning Bolt M10 · 146 Nonfoil']").click }
    expect(page).to have_css("#status", text: "Added 1 × Lightning Bolt (M10 · 146, Nonfoil) to your collection.")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(user.account.scanner_sitting.entries.sole.printing).to eq(older)
  end

  it "says so in place when Other printings can't load (Error Scenarios)", :aggregate_failures, :server_error do
    read_card
    allow(Scanner::OtherPrintings).to receive(:new).and_raise(StandardError, "boom")
    click_on "Other printings"
    expect(page).to have_css("turbo-frame#scanner_printings", text: "Other printings couldn't be loaded.")
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt")
  end
end
