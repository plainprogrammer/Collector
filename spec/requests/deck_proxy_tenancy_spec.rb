require "rails_helper"

# Spec 068 AC-8.3: another account's deck, zone and proxy are 404 on every proxy page and verb, and no admin page shows one.
RSpec.describe "Proxy pages and tenancy", type: :request do
  let(:owner) { create(:user) }
  let(:deck) { create(:deck, account: owner.account, name: "Izzet Tempo") }
  let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account: owner.account, entry: create(:mtg_printing).entry, finish: "foil", quantity: 2) }
  let(:stranger) { create(:user) }

  # rubocop:disable RSpec/ExampleLength -- one table of every page and verb, so a new route is one more row
  it "is 404 for another account on every page and verb, and writes nothing", :aggregate_failures do
    sign_in_as(stranger)
    [ [ :get, new_deck_zone_proxy_path(deck, "main") ], [ :get, new_deck_zone_proxy_path(deck, "main", entry: proxy.entry.external_key) ],
      [ :post, deck_zone_proxies_path(deck, "main") ], [ :get, edit_deck_proxy_path(deck, proxy) ], [ :patch, deck_proxy_path(deck, proxy) ],
      [ :get, new_deck_proxy_removal_path(deck, proxy) ], [ :delete, deck_proxy_path(deck, proxy) ] ].each do |verb, path|
      public_send(verb, path, params: { proxy: { entry: proxy.entry.external_key, finish: "foil", quantity: "5" } })
      expect(response).to have_http_status(:not_found), "#{verb} #{path}"
    end
    expect(proxy.reload.quantity).to eq(2)
    expect(Deck::Proxy.count).to eq(1)
  end
  # rubocop:enable RSpec/ExampleLength

  it "shows no proxy, deck or location on an admin page (hosted-door rule 2)", :aggregate_failures do
    sign_in_as(create(:admin))

    get admin_users_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Izzet Tempo")
  end
end
