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
    end
  end

  it "fits a 360px screen without horizontal scrolling" do
    user = system_sign_in_as(create(:user))
    create(:lot, account: user.account, quantity: 9_999)
    visit collection_path
    expect(open_in_narrow_frame(collection_path(q: "bolt"), width: 360, ready: ".c-grid")).to eq([ 360, true ])
  end
end
