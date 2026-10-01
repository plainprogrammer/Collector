require "rails_helper"

RSpec.describe "Table and bulk pages at 360px", type: :system do
  let(:user) { create(:user) }

  before do
    owned_printing(account: user.account, quantity: 9_999, finish: "foil", condition: "near_mint", price_paid_cents: 123_456)
    system_sign_in_as(user)
    visit collection_path
  end

  def frame_fits? = page.evaluate_script("(() => { const view = document.getElementById('narrow').contentWindow; return view.document.documentElement.scrollWidth <= view.innerWidth })()")

  def select_all_and_choose(action)
    open_in_narrow_frame(collection_path(bulk: 1), width: 360, ready: ".c-bulkbar")
    within_narrow_frame do
      check "Select all"
      find(".c-bulkbar__more summary").click
      click_on action
    end
  end

  it "fits the table" do
    expect(open_in_narrow_frame(collection_path(view: "table"), width: 360, ready: "table.c-table")).to eq([ 360, true ])
  end

  it "fits bulk mode, entered from the narrow menu", :aggregate_failures do
    open_in_narrow_frame(collection_path, width: 360, ready: ".c-grid")
    within_narrow_frame do
      find(".c-filterbar__more summary").click
      click_on "Edit many"
      expect(page).to have_css(".c-bulkbar")
    end
    expect(frame_fits?).to be(true)
  end

  it "fits the Set condition page, with a Back link", :aggregate_failures do
    select_all_and_choose("Set condition…")
    within_narrow_frame { expect(page).to have_css("h1", text: "Set the condition of 9,999 items").and have_css(".c-appbar__back") }
    expect(frame_fits?).to be(true)
  end

  it "fits the removal confirmation, with a Back link", :aggregate_failures do
    select_all_and_choose("Remove")
    within_narrow_frame { expect(page).to have_css("h1", text: "Remove 9,999 items?").and have_css(".c-appbar__back") }
    expect(frame_fits?).to be(true)
  end
end
