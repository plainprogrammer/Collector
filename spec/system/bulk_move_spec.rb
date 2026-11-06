require "rails_helper"

# Spec 041: Move to… in a browser, on a desktop and at 360px.
RSpec.describe "Bulk Move to…", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let!(:blue) { create(:location, account:, name: "Blue binder") }

  def frame_fits? = page.evaluate_script("(() => { const view = document.getElementById('narrow').contentWindow; return view.document.documentElement.scrollWidth <= view.innerWidth })()")

  it "moves the selected lots from the bar and returns to the bulk table (AC-3.1, AC-3.9)", :aggregate_failures do
    owned_printing("Card A", account:, quantity: 2)
    owned_printing("Card B", account:, quantity: 1)
    visit collection_path
    click_on "Edit many"
    check "Select all"
    within(".c-bulkbar__extra") { click_on "Move to…" }
    expect(page).to have_css("h1", exact_text: "Move 3 items")
    select "Blue binder", from: "To"
    click_on "Move"
    expect(page).to have_css("#status", text: "Moved 3 items to Blue binder.")
    expect(page).to have_css(".c-bulkbar__count", exact_text: "All 3 items selected")
    expect(account.lots.pluck(:location_id).uniq).to eq([ blue.id ])
  end

  it "does not move when the To prompt is left (AC-2.2: the browser refuses it first)", :aggregate_failures do
    lot = owned_printing(account:)
    visit collection_path(bulk: 1)
    check "Select all"
    within(".c-bulkbar__extra") { click_on "Move to…" }
    click_on "Move"
    expect(page.evaluate_script("document.getElementById('to').validity.valueMissing")).to be(true) # the browser's required check stopped it
    expect(page).to have_css("h1", text: "Move 1 item") # still the move page
    expect(page).to have_no_css(".c-field--invalid") # the server's refusal never rendered: the browser stopped it
    expect(page).to have_no_css("#status", text: /\S/)
    expect(lot.reload.location).to be_nil
  end

  it "reaches Move to… from the bar's menu at 360px and fits the move page (AC-6.2)", :aggregate_failures do
    owned_printing(account:, quantity: 9_999, finish: "foil", condition: "near_mint", price_paid_cents: 123_456)
    visit collection_path
    open_in_narrow_frame(collection_path(bulk: 1), width: 360, ready: ".c-bulkbar")
    within_narrow_frame do
      expect(page).to have_no_css(".c-bulkbar__extra", visible: :visible)
      check "Select all"
      find(".c-bulkbar__more summary").click
      expect(page.all(".c-bulkbar__more .c-menu__item").map(&:text)).to eq([ "Set condition…", "Move to…", "Remove" ])
      click_on "Move to…"
      expect(page).to have_css("h1", text: "Move 9,999 items").and have_css(".c-appbar__back")
      expect(page).to have_select("To", options: [ "Choose…", "No location", "Blue binder" ])
    end
    expect(frame_fits?).to be(true)
  end
end
