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

  it "styles card names as brand links, not browser-default ones", :aggregate_failures do
    user = system_sign_in_as(create(:user))
    owned_printing("Lightning Bolt", account: user.account)
    visit collection_path(view: "table")
    link_style = page.evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.querySelector("tbody tr .c-table__item a"))
        return [ style.color, style.textDecorationLine ]
      })()
    JS
    brand = page.evaluate_script("getComputedStyle(document.querySelector('.c-seg button[aria-pressed=true]')).backgroundColor")
    expect(link_style).to eq([ brand, "none" ])
  end

  it "gives the empty state's Search cards link the brand link colour", :aggregate_failures do
    system_sign_in_as(create(:user))
    visit collection_path
    link_style = page.evaluate_script(<<~JS)
      (() => {
        const link = [...document.querySelectorAll(".c-empty a")].find((a) => a.textContent.trim() === "Search cards")
        const style = getComputedStyle(link)
        return [ style.color, style.textDecorationLine ]
      })()
    JS
    brand = page.evaluate_script("getComputedStyle(document.querySelector('.c-pagehead__actions .c-btn--primary')).backgroundColor")
    expect(link_style).to eq([ brand, "none" ])
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

  it "shows the place in the line under the name on a phone, with no Location column and no sideways scroll", :aggregate_failures do # spec 033 AC-2.2
    user = system_sign_in_as(create(:user))
    owned_printing("Lightning Bolt", account: user.account, location: create(:location, account: user.account, name: "Blue binder " + "long " * 9))
    visit collection_path(view: "table")
    expect(page).to have_css("th", text: "Location")
    expect(open_in_narrow_frame(collection_path(view: "table"), width: 360, ready: "tbody tr")).to eq([ 360, true ])
    within_narrow_frame do
      expect(page).to have_no_css("th", text: "Location", visible: true)
      expect(page).to have_css(".c-table__sub", text: "Blue binder long", visible: true)
    end
  end

  it "keeps a long place name to one line on a tile, and its +N more visible", :aggregate_failures do # spec 033 AC-1.6
    user = system_sign_in_as(create(:user))
    entry = owned_printing("Lightning Bolt", account: user.account, quantity: 3, location: create(:location, account: user.account, name: "W" * 60)).entry
    create(:lot, account: user.account, entry:, finish: "foil", location: create(:location, account: user.account, name: "Long box"))
    expect(open_in_narrow_frame(collection_path, width: 360, ready: ".c-tile__place")).to eq([ 360, true ])
    within_narrow_frame do
      name = find(".c-tile__place-name")
      expect(name.evaluate_script("this.scrollWidth > this.clientWidth")).to be(true)
      expect(name.evaluate_script("this.getBoundingClientRect().height")).to be < 20
      expect(find(".c-tile__place-more", visible: true).text).to eq("+1 more")
    end
  end
end
