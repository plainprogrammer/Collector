require "rails_helper"

RSpec.describe "Quick add from search", type: :system do
  let!(:entry) { create(:mtg_printing).entry.tap { |e| e.update!(name: "Lightning Bolt") } }
  let(:tile) { "##{ActionView::RecordIdentifier.dom_id(entry, :tile)}" }

  before { create(:catalog_refresh_run) }

  it "adds a copy without reloading the page and announces it", :aggregate_failures do
    system_sign_in_as(create(:user))
    visit catalog_entries_path(q: "bolt")
    page.execute_script("window.__marker = 'still here'")
    within(tile) { click_button "Add" }

    expect(page).to have_css("[role=status]", text: "Added 1 × Lightning Bolt")
    expect(page).to have_css("#{tile} .c-tile__qty", text: "×1")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(page).to have_current_path(catalog_entries_path(q: "bolt"))
  end

  it "shows the over-cap message in place", :aggregate_failures do
    user = system_sign_in_as(create(:user))
    create(:lot, account: user.account, entry:, quantity: 9_999)
    visit catalog_entries_path(q: "bolt")
    page.execute_script("window.__marker = 'still here'")
    within(tile) { click_button "Add" }

    expect(page).to have_css("[role=status]", text: "You already have the most copies one lot can hold (9,999).")
    expect(page).to have_current_path(catalog_entries_path(q: "bolt"))
    expect(page.evaluate_script("window.__marker")).to eq("still here")
  end

  it "updates results in place and focuses search with /", :aggregate_failures do
    system_sign_in_as(create(:user))
    visit catalog_entries_path
    page.execute_script("window.__marker = 'still here'")
    find("body").send_keys("/")
    expect(page).to have_css("input[name=q]:focus")
    fill_in "Card name", with: "bolt"
    click_button "Search"
    expect(page).to have_css(".c-group h2", text: "Lightning Bolt")
    expect(page).to have_current_path(catalog_entries_path(q: "bolt", set: ""))
    expect(page.evaluate_script("window.__marker")).to eq("still here")

    page.go_back
    expect(page).to have_current_path(catalog_entries_path)
    expect(page).to have_no_css(".c-group h2", text: "Lightning Bolt")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
  end

  it "fits a 360px screen without horizontal scrolling", :aggregate_failures do
    system_sign_in_as(create(:user))
    visit catalog_entries_path(q: "bolt")
    expect(open_in_narrow_frame(catalog_entries_path(q: "bolt"), width: 360, ready: ".c-group h2")).to eq([ 360, true ])
    within_narrow_frame { expect(page).to have_css(".c-group h2", text: "Lightning Bolt") }
  end
end
