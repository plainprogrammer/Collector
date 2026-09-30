require "rails_helper"

RSpec.describe "Quick add", type: :request do
  let(:user) { create(:user) }
  let(:entry) { create(:mtg_printing).entry.tap { |e| e.update!(name: "Lightning Bolt", number: "146") } }
  let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

  before { sign_in_as(user) }

  it "adds one copy with nothing else specified and returns to the page", :aggregate_failures do
    return_to = catalog_entries_path(q: "bolt")
    post catalog_entry_quick_add_path(entry), params: { return_to: }
    expect(response).to redirect_to(return_to)
    expect(response).to have_http_status(:see_other)
    expect(user.account.lots.sole).to have_attributes(quantity: 1, finish: nil, condition: nil, price_paid_cents: nil)
    follow_redirect!
    expect(response.body).to include("Added 1 × Lightning Bolt (#{entry.set.code.upcase} · 146) to your collection.")
  end

  it "merges two quick adds into one lot" do
    2.times { post catalog_entry_quick_add_path(entry) }
    expect(user.account.lots.sole.quantity).to eq(2)
  end

  it "ignores return paths that aren't on this instance", :aggregate_failures do
    post catalog_entry_quick_add_path(entry), params: { return_to: "https://evil.example/x" }
    expect(response).to redirect_to(catalog_entry_path(entry))
    post catalog_entry_quick_add_path(entry), params: { return_to: "//evil.example/x" }
    expect(response).to redirect_to(catalog_entry_path(entry))
  end

  it "answers an over-cap add with scripting on by updating only the status region", :aggregate_failures do
    create(:lot, account: user.account, entry:, quantity: 9_999)
    post catalog_entry_quick_add_path(entry), headers: turbo
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include('<turbo-stream action="update" target="status">',
      "You already have the most copies one lot can hold (9,999).")
    expect(user.account.lots.sole.quantity).to eq(9_999)
  end

  it "answers an over-cap add without scripting with the card page at 422", :aggregate_failures do
    create(:lot, account: user.account, entry:, quantity: 9_999)
    post catalog_entry_quick_add_path(entry)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("You already have the most copies one lot can hold (9,999).", "Your copies", "9999")
  end

  it "adds a retired printing like any other", :aggregate_failures do
    entry.update!(retired_at: 1.day.ago)
    post catalog_entry_quick_add_path(entry)
    expect(response).to redirect_to(catalog_entry_path(entry))
    expect(user.account.lots.sole).to have_attributes(entry:, quantity: 1)
  end

  it "returns 404 for an unknown printing" do
    post catalog_entry_quick_add_path("nope")
    expect(response).to have_http_status(:not_found)
  end
end
