require "rails_helper"

RSpec.describe "Collection table", type: :system do
  it "filters in place and goes back to the unfiltered table", :aggregate_failures do
    user = system_sign_in_as(create(:user))
    owned_printing("Lightning Bolt", account: user.account)
    owned_printing("Opt", account: user.account)
    visit collection_path(view: "table")
    page.execute_script("window.__marker = 'still here'")
    fill_in "Search your collection", with: "bolt"
    find_field("Search your collection").send_keys(:enter)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    wait_for_turbo_idle
    page.go_back
    expect(page).to have_css("tbody tr", count: 2)
  end

  it "shows only name, quantity and actions on a phone, with the key facts under the name", :aggregate_failures do
    user = system_sign_in_as(create(:user))
    owned_printing("Lightning Bolt", account: user.account, number: "146", quantity: 9_999, finish: "foil", condition: "near_mint")
    visit collection_path
    expect(open_in_narrow_frame(collection_path(view: "table"), width: 360, ready: "table.c-table")).to eq([ 360, true ])
    within_narrow_frame do
      headers = page.all("thead th", visible: :visible)
      expect(headers.size).to eq(3)
      expect(headers.first(2).map { |th| th.text.strip }).to eq([ "Name", "Qty" ])
      expect(page).to have_css(".c-table__sub", visible: :visible, text: "· 146 · Foil · NM · EN")
    end
  end
end
