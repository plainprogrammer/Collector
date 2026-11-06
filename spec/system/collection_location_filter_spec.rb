require "rails_helper"

RSpec.describe "Filtering the collection by location", type: :system do # spec 037
  let(:user) { system_sign_in_as(create(:user)) }
  let(:blue) { create(:location, account: user.account, name: "Blue binder") }
  let(:box) { create(:location, account: user.account, name: "Long box") }

  def own(name, **options) = owned_printing(name, account: user.account, **options)
  def count_line = find(".c-results__meta .c-filterbar__count")
  def tile_names = all(".c-tile__name").map(&:text)

  it "narrows the grid to a location and back to all (AC-1.2, AC-1.7)", :aggregate_failures do
    own("Lightning Bolt", quantity: 3, location: blue)
    own("Opt", quantity: 2, location: box)
    visit collection_path(view: "grid")
    expect(page).to have_css(".c-tile__place", count: 2)
    select "Blue binder", from: "Location"
    click_on "Filter"
    expect(page).to have_css(".c-results__meta", exact_text: "3 of 5 items")
    expect([ tile_names, page.has_no_css?(".c-tile__place") ]).to eq([ [ "Lightning Bolt" ], true ])
    expect(page).to have_select("Location", selected: "Blue binder")
    select "All locations", from: "Location"
    click_on "Filter"
    expect(page).to have_css(".c-results__meta", exact_text: "5 items")
    expect(page).to have_css(".c-tile__place", count: 2)
  end

  it "applies the name and the location on Enter in the name field (AC-6.3)", :aggregate_failures do
    own("Lightning Bolt", location: blue)
    own("Opt", location: blue)
    own("Shock", location: box)
    visit collection_path(view: "grid")
    select "Blue binder", from: "Location"
    fill_in "Search your collection", with: "opt"
    find_field("Search your collection").send_keys(:enter)
    expect(page).to have_css(".c-results__meta", exact_text: "1 of 3 items")
    expect(tile_names).to eq([ "Opt" ])
  end

  it "keeps the filter across the table's sort and pages (AC-1.3, AC-4.1)", :aggregate_failures do
    stub_const("CollectionTable::PER_PAGE", 1)
    own("Lightning Bolt", location: blue)
    own("Opt", location: blue)
    own("Shock", location: box)
    visit collection_path(view: "table", location: blue.id)
    click_on "Qty"
    expect(page).to have_css("th[aria-sort]", text: "Qty")
    click_on "Next"
    expect(page).to have_css(".c-pager__position", text: "Page 2 of 2")
    expect([ count_line.text, page.has_select?("Location", selected: "Blue binder") ]).to eq([ "2 of 3 items", true ])
  end

  it "selects and removes only the place's lots in bulk mode, and Undo brings them back (AC-5.1, AC-5.2, AC-5.6)", :aggregate_failures do
    own("Lightning Bolt", quantity: 3, location: blue)
    own("Opt", quantity: 2, location: box)
    visit collection_path(view: "table", location: blue.id)
    click_on "Edit many"
    expect(page).to have_css(".c-bulkbar__count", exact_text: "0 of 3 selected")
    expect(page).to have_select("Location", selected: "Blue binder")
    check "Select all"
    within(".c-bulkbar__extra") { click_on "Remove" }
    click_on "Remove 3 items"
    expect(page).to have_css(".c-status", text: "Removed 3 items from your collection.")
    expect([ user.account.lots.pluck(:quantity), page.has_select?("Location", selected: "Blue binder") ]).to eq([ [ 2 ], true ])
    click_on "Undo"
    expect(page).to have_css(".c-status", text: "Restored 3 items to your collection.")
    expect(user.account.lots.sum(:quantity)).to eq(5)
    expect(page).to have_select("Location", selected: "Blue binder")
  end

  it "pages under the rendered location when the select changed without Filter (AC-5.3)", :aggregate_failures do
    stub_const("CollectionTable::PER_PAGE", 1)
    own("Lightning Bolt", location: blue)
    own("Opt", location: blue)
    own("Shock")
    visit collection_path(bulk: 1, location: blue.id)
    select "No location", from: "Location"
    click_on "Next"
    expect(page).to have_css(".c-pager__position", text: "Page 2 of 2")
    expect(page).to have_select("Location", selected: "Blue binder")
    expect(page).to have_css("tbody tr", text: "Opt")
  end

  it "fits the select and its button in the filter group at 390px, in both modes (AC-6.5)", :aggregate_failures do
    own("Lightning Bolt", location: blue)
    create(:location, account: user.account, name: "A long location name the browser has to clip in its box")
    visit collection_path
    [ collection_path(view: "grid"), collection_path(bulk: 1) ].each do |path|
      expect(open_in_narrow_frame(path, width: 390, ready: ".c-filterbar__filters select")).to eq([ 390, true ])
      within_narrow_frame do
        expect(find(".c-filterbar__filters")).to have_button("Filter")
        expect(page.evaluate_script("document.querySelector('.c-filterbar__filters select').getBoundingClientRect().width")).to be <= 220
      end
    end
  end
end
