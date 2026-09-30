require "rails_helper"

RSpec.describe "Collection on a phone", type: :system do
  # Firefox won't open a window narrower than 500px, so the phone layout is checked in a 390px frame.
  it "shows two columns, a full-width search and the header add button", :aggregate_failures do
    user = system_sign_in_as(create(:user))
    3.times { create(:lot, account: user.account) }
    visit collection_path

    expect(open_in_narrow_frame(collection_path, width: 390, height: 844, ready: ".c-grid")).to eq([ 390, true ])
    within_narrow_frame do
      columns = page.evaluate_script("getComputedStyle(document.querySelector('.c-grid')).gridTemplateColumns.split(' ').length")
      expect(columns).to eq(2)
      search_share = "document.querySelector('.c-filterbar .c-input').getBoundingClientRect().width / document.querySelector('.c-filterbar').getBoundingClientRect().width"
      expect(page.evaluate_script(search_share)).to be > 0.95
      expect(page).to have_css(".c-appbar__add[href='#{catalog_entries_path}']", visible: :visible)
      expect(page).to have_no_css(".c-pagehead__actions", visible: :visible)
      expect(page).to have_css(".c-tabbar", visible: :visible)
      expect(page).to have_css(".c-appbar__nav", visible: :hidden)
    end
  end

  it "filters in place and goes back to the unfiltered collection", :aggregate_failures do
    filter_owned_bolt_and_opt_to_bolt
    expect(page).to have_css(".c-tile__name", count: 1)
    expect(page.evaluate_script("window.__marker")).to eq("still here")

    page.go_back
    expect(page).to have_current_path(collection_path)
    expect(page).to have_css(".c-filterbar__count", exact_text: "5 items")
    expect(page).to have_field("Search your collection", with: "")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
  end

  it "goes forward to the filtered collection again", :aggregate_failures do
    filter_owned_bolt_and_opt_to_bolt
    page.go_back
    expect(page).to have_css(".c-filterbar__count", exact_text: "5 items")

    page.go_forward
    expect(page).to have_current_path(collection_path(q: "bolt"))
    expect(page).to have_css(".c-filterbar__count", text: "3 of 5 items")
    expect(page).to have_field("Search your collection", with: "bolt")
  end

  it "fits a 360px screen without horizontal scrolling" do
    user = system_sign_in_as(create(:user))
    create(:lot, account: user.account, quantity: 9_999)
    visit collection_path
    expect(open_in_narrow_frame(collection_path(q: "bolt"), width: 360, ready: ".c-grid")).to eq([ 360, true ])
  end

  private

  def filter_owned_bolt_and_opt_to_bolt
    sign_in_owning_bolt_and_opt
    visit collection_path
    page.execute_script("window.__marker = 'still here'")
    fill_in "Search your collection", with: "bolt"
    find_field("Search your collection").send_keys(:enter)
    expect(page).to have_current_path(collection_path(q: "bolt"))
    expect(page).to have_css(".c-filterbar__count", text: "3 of 5 items")
  end

  # Three Lightning Bolts and two Opts: five items, three of them matching "bolt".
  def sign_in_owning_bolt_and_opt
    user = system_sign_in_as(create(:user))
    bolt = create(:mtg_printing).entry.tap { |e| e.update!(name: "Lightning Bolt") }
    opt = create(:mtg_printing).entry.tap { |e| e.update!(name: "Opt") }
    create(:lot, account: user.account, entry: bolt, quantity: 3)
    create(:lot, account: user.account, entry: opt, quantity: 2)
  end
end
