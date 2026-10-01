require "rails_helper"

RSpec.describe "Bulk Remove and Undo", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
  def page_html = Nokogiri::HTML5(response.body)
  def alert_text = page_html.at_css(".c-status__message--alert").text

  def select_lots(*lots, q: "", page: nil, all: false)
    post collection_selection_path, params: { q: }
    params = { go: "remove", q:, rendered_q: q, all_rendered: "0", page:, shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }
    params[:all] = "1" if all
    patch collection_selection_path, params: params.compact
  end

  def remove_selected(page: nil)
    post collection_bulk_removals_path(page:)
    follow_redirect!
  end

  def undo_form = page_html.at_css(".c-status form.c-status__action")

  it "confirms with exact numbers before removing anything", :aggregate_failures do
    select_lots(own(quantity: 2), own("Opt", quantity: 10), page: 1)
    get new_collection_bulk_removal_path(page: 1)
    expect(page_html.at_css(".c-confirm h1").text).to eq("Remove 12 items?")
    expect(page_html.at_css(".c-confirm p").text).to eq("This removes 12 items in 2 lots from your collection. You can undo this right afterwards.")
    expect(page_html.at_css(".c-confirm form button.c-btn--danger").text).to eq("Remove 12 items")
    expect(page_html.at_css(".c-confirm form")["action"]).to eq(collection_bulk_removals_path(page: 1))
    expect(page_html.at_css(".c-confirm a.c-btn--secondary")["href"]).to eq(collection_path(bulk: 1))
    expect(page_html.at_css('header a[aria-label="Back"]')["href"]).to eq(collection_path(bulk: 1))
    expect(page_html.at_css('.c-tabbar a[aria-current="page"]').text).to include("Collection")
    expect(Lot.count).to eq(2)
  end

  it "keeps the selection when the collector cancels", :aggregate_failures do
    lot = own
    select_lots(lot)
    get new_collection_bulk_removal_path
    get collection_path(bulk: 1)
    expect(page_html.at_css(".c-bulkbar__count").text).to eq("1 of 1 selected")
  end

  it "removes, returns to the bulk table with nothing selected, and offers Undo", :aggregate_failures do
    select_lots(own(quantity: 2), own("Opt"))
    own("Shock")
    post collection_bulk_removals_path
    expect(response).to redirect_to(collection_path(bulk: 1))
    follow_redirect!
    expect(page_html.at_css(".c-status__message").text.squish).to eq("Removed 3 items from your collection. Undo")
    expect(undo_form["action"]).to eq(collection_bulk_removal_undo_path(BulkRemoval.sole))
    expect(undo_form.at_css("input[name=return_to]")["value"]).to eq(collection_path(bulk: 1))
    expect([ page_html.at_css(".c-bulkbar__count").text, response.body.include?("1 item · 1 unique") ]).to eq([ "0 of 1 selected", true ])
  end

  it "shows the empty state with Undo when the removal empties the collection", :aggregate_failures do
    select_lots(own)
    remove_selected
    expect(response.body).to include("No cards in your collection yet.", "Removed 1 item from your collection.")
    expect(undo_form).to be_present
  end

  it "restores the removed lots on Undo and lands on the page it carries", :aggregate_failures do
    select_lots(own(quantity: 2))
    remove_selected
    post undo_form["action"], params: { return_to: collection_path(bulk: 1, q: "bolt") }
    expect(response).to redirect_to(collection_path(bulk: 1, q: "bolt"))
    expect(flash[:notice]).to eq("Restored 2 items to your collection.")
    expect(Lot.sole.quantity).to eq(2)
  end

  it "lands on the collection for an Undo URL off this instance" do
    select_lots(own)
    remove_selected
    post undo_form["action"], params: { return_to: "https://elsewhere.example/collection" }
    expect(response).to redirect_to(collection_path)
  end

  it "refuses a used Undo with 422, re-rendering the page it carries", :aggregate_failures do
    select_lots(own)
    remove_selected
    action = undo_form["action"]
    post action, params: { return_to: collection_path(bulk: 1) }
    post action, params: { return_to: collection_path(bulk: 1) }
    expect(response).to have_http_status(:unprocessable_content)
    expect(alert_text).to eq("This removal can no longer be undone.")
    expect(page_html.at_css("form#bulk")).to be_present
  end

  it "ends the Undo when anything else is removed in the session", :aggregate_failures do
    select_lots(own("Opt"))
    remove_selected
    action = undo_form["action"]
    other = own
    delete lot_path(other)
    post action, params: { return_to: collection_path }
    expect([ response.status, alert_text ]).to eq([ 422, "This removal can no longer be undone." ])
  end

  it "keeps the Undo when the collector removes something in another session" do
    select_lots(own("Opt"))
    remove_selected
    action = undo_form["action"]
    other = own
    other_session = open_session.tap { |browser| browser.post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD } }
    other_session.delete lot_path(other)
    post action, params: { return_to: collection_path }
    expect(flash[:notice]).to eq("Restored 1 item to your collection.")
  end

  it "refuses an Undo past 9,999 copies, restoring nothing", :aggregate_failures do
    lot = own(number: "146")
    select_lots(lot)
    remove_selected
    action = undo_form["action"]
    Lot.add!(account: user.account, entry: lot.entry, quantity: 9_999)
    post action, params: { return_to: collection_path(view: "table") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(alert_text).to eq("Nothing restored. Lightning Bolt (#{lot.entry.set.code.upcase} · 146) would have more than 9,999 copies in one lot.")
    expect(Lot.sole.quantity).to eq(9_999)
  end

  it "removes every lot matching the filter for Select all, and nothing else", :aggregate_failures do
    bolt = own("Lightning Bolt")
    opt = own("Opt")
    select_lots(q: "bolt", all: true)
    post collection_bulk_removals_path
    expect([ Lot.exists?(bolt.id), Lot.exists?(opt.id) ]).to eq([ false, true ])
  end

  it "refuses when every selected lot is gone", :aggregate_failures do
    lot = own
    select_lots(lot)
    lot.destroy!
    post collection_bulk_removals_path
    expect([ response.status, alert_text ]).to eq([ 422, "None of the selected items are in your collection any more." ])
  end

  it "lets only the session that removed undo it", :aggregate_failures do
    select_lots(own)
    remove_selected
    action = undo_form["action"]
    delete session_path
    post action, params: { return_to: collection_path }
    expect(response).to redirect_to(new_session_path)
    sign_in_as(user)
    post action, params: { return_to: collection_path }
    expect(response).to have_http_status(:not_found)
    post collection_bulk_removal_undo_path(0)
    expect(response).to have_http_status(:not_found)
  end
end
