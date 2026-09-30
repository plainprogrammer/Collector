require "rails_helper"

RSpec.describe "Collection", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  it "shows the empty state without a filter bar", :aggregate_failures do
    get collection_path
    expect(response.body).to include("My collection", "No cards in your collection yet. Search for a card to start adding.")
    expect(response.body).not_to include("c-filterbar")
  end

  it "shows stats, tiles and the Add items action", :aggregate_failures do
    entry = create(:mtg_printing, finishes: %w[nonfoil foil]).entry
    entry.update!(name: "Lightning Bolt", number: "146")
    create(:lot, account: user.account, entry:, quantity: 3)
    create(:lot, account: user.account, entry:, finish: "foil")
    get collection_path
    expect(response.body).to include("4 items · 1 unique", ">×4<", "Foil", "Lightning Bolt", "#{entry.set.code.upcase} · 146", ">EN<",
      %(href="#{catalog_entry_path(entry, from: 'collection')}"), %(href="#{catalog_entries_path}"))
    expect(response.body).not_to include('type="checkbox"', "Edit many", "c-seg")
  end

  it "filters by name and counts matching of total", :aggregate_failures do
    bolt = create(:mtg_printing).entry.tap { |e| e.update!(name: "Lightning Bolt") }
    opt = create(:mtg_printing).entry.tap { |e| e.update!(name: "Opt") }
    create(:lot, account: user.account, entry: bolt, quantity: 3)
    create(:lot, account: user.account, entry: opt, quantity: 2)
    get collection_path(q: "bolt")
    expect(response.body).to include("3 of 5 items")
    get collection_path(q: "zzz")
    expect(response.body).to include(%(No cards in your collection match "zzz".), "0 of 5 items")
  end

  it "says item, not items, for a single copy", :aggregate_failures do
    entry = create(:mtg_printing).entry.tap { |e| e.update!(name: "Lightning Bolt") }
    create(:lot, account: user.account, entry:)
    get collection_path
    expect(response.body).to include("1 item · 1 unique", %(<span class="c-filterbar__count">1 item</span>))
    expect(response.body).not_to include("1 items")
    get collection_path(q: "zzz")
    expect(response.body).to include("0 of 1 item<")
    get collection_path(q: "bolt")
    expect(response.body).to include("1 of 1 item<")
  end

  it "only shows the signed-in account's copies" do
    create(:lot, quantity: 7)
    get collection_path
    expect(response.body).to include("No cards in your collection yet.")
  end

  it "falls back to the first or last page for invalid page numbers", :aggregate_failures do
    stub_const("CollectionGrid::PER_PAGE", 1)
    2.times { create(:lot, account: user.account) }
    get collection_path(page: "abc")
    expect(response.body).to include("Page 1 of 2")
    get collection_path(page: "99")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Page 2 of 2")
  end
end
