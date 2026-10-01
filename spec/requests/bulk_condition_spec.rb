require "rails_helper"

RSpec.describe "Bulk Set condition", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
  def page_html = Nokogiri::HTML5(response.body)

  def select_lots(*lots, page: nil)
    post collection_selection_path
    patch collection_selection_path, params: { go: "set_condition", q: "", rendered_q: "", all_rendered: "0", page:,
      shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }.compact
  end

  it "asks for one condition on its own page, with Cancel and Back to the bulk table", :aggregate_failures do
    select_lots(own(quantity: 2), own("Opt"), page: 1)
    get new_collection_condition_change_path(page: 1)
    expect(page_html.at_css("h1").text).to eq("Set the condition of 3 items")
    expect(page_html.css("input[type=radio][name=condition]").map { |radio| radio["value"] })
      .to eq(%w[near_mint lightly_played moderately_played heavily_played damaged] + [ "" ])
    expect(page_html.css(".c-choices label").map { |label| label.text.squish }).to eq([
      "Near mint (NM)", "Lightly played (LP)", "Moderately played (MP)", "Heavily played (HP)", "Damaged (DMG)", "Not specified"
    ])
    expect(page_html.at_css("input[type=submit]")["value"]).to eq("Apply")
    expect(page_html.at_css(".c-form__actions a")["href"]).to eq(collection_path(bulk: 1))
    expect(page_html.at_css('header a[aria-label="Back"]')["href"]).to eq(collection_path(bulk: 1))
    expect(page_html.at_css('.c-tabbar a[aria-current="page"]').text).to include("Collection")
  end

  it "sends the collector back to the bulk table when nothing is selected" do
    get new_collection_condition_change_path
    expect([ response.location, flash[:alert] ]).to eq([ "http://www.example.com#{collection_path(bulk: 1)}", "Select at least one item." ])
  end

  it "lands on the nearest real page when a merge empties the last one", :aggregate_failures do
    stub_const("CollectionTable::PER_PAGE", 1)
    played = own(finish: "foil", condition: "lightly_played")
    unknown = create(:lot, account: user.account, entry: played.entry, finish: "foil")
    select_lots(unknown, page: 2)
    post collection_condition_change_path(page: 2), params: { condition: "lightly_played" }
    expect(response).to redirect_to(collection_path(bulk: 1, page: 2))
    follow_redirect!
    expect([ response.status, Nokogiri::HTML5(response.body).css("tbody tr").size ]).to eq([ 200, 1 ])
  end

  it "sets the condition and returns to the bulk table with the selection kept", :aggregate_failures do
    first = own(quantity: 2)
    second = own("Opt")
    select_lots(first, second)
    post collection_condition_change_path, params: { condition: "lightly_played" }
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(collection_path(bulk: 1))
    expect(flash[:notice]).to eq("Set the condition of 3 items to Lightly played.")
    expect([ first.reload.condition, second.reload.condition ]).to eq(%w[lightly_played lightly_played])
    follow_redirect!
    expect(page_html.at_css(".c-bulkbar__count").text).to eq("3 of 3 selected")
  end

  it "counts only the selected lots still in the collection when one was removed in another tab", :aggregate_failures do
    kept = own(quantity: 2)
    gone = own("Opt", quantity: 3)
    select_lots(kept, gone)
    gone.destroy!
    post collection_condition_change_path, params: { condition: "lightly_played" }
    expect(flash[:notice]).to eq("Set the condition of 2 items to Lightly played.")
    expect(kept.reload.condition).to eq("lightly_played")
  end

  it "clears the condition for Not specified" do
    lot = own(condition: "damaged")
    select_lots(lot)
    post collection_condition_change_path, params: { condition: "" }
    expect([ flash[:notice], lot.reload.condition ]).to eq([ "Cleared the condition of 1 item.", nil ])
  end

  it "merges lots that become identical, keeping the merged lot selected", :aggregate_failures do
    played = own(quantity: 2, finish: "foil", condition: "lightly_played")
    unknown = create(:lot, account: user.account, entry: played.entry, finish: "foil", quantity: 3)
    select_lots(unknown)
    post collection_condition_change_path, params: { condition: "lightly_played" }
    follow_redirect!
    expect(page_html.css("tbody tr").size).to eq(1)
    expect(page_html.at_css("tbody input[name='ticked_ids[]']").key?("checked")).to be(true)
    expect(played.reload.quantity).to eq(5)
  end

  it "changes nothing past 9,999 copies, keeping the selection", :aggregate_failures do
    full = own(number: "146", quantity: 9_999, finish: "foil", condition: "near_mint")
    one = create(:lot, account: user.account, entry: full.entry, finish: "foil")
    select_lots(one)
    post collection_condition_change_path, params: { condition: "near_mint" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(page_html.at_css(".c-status__message--alert").text)
      .to eq("Nothing changed. Lightning Bolt (#{full.entry.set.code.upcase} · 146) would have more than 9,999 copies in one lot.")
    expect([ one.reload.condition, BulkSelection.sole.lots.to_a ]).to eq([ nil, [ one ] ])
  end

  it "refuses an unknown condition", :aggregate_failures do
    select_lots(own)
    post collection_condition_change_path, params: { condition: "mint" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(page_html.at_css(".c-status__message--alert").text).to eq("That isn't a known condition.")
  end

  it "refuses when every selected lot is gone", :aggregate_failures do
    lot = own
    select_lots(lot)
    lot.destroy!
    post collection_condition_change_path, params: { condition: "near_mint" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(page_html.at_css(".c-status__message--alert").text).to eq("None of the selected items are in your collection any more.")
  end
end
