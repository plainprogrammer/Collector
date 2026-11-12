require "rails_helper"

# Spec 070 AC-2.8, AC-4.8, AC-3.9: another account's anything is 404 on both pages and both verbs, and another account's lot in
# the form is no longer free.
RSpec.describe "Replacing a proxy: tenancy", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil]).entry }
  let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2) }
  let(:other) { create(:user).account }

  # Not memoized `let`s: the group has five at most (RSpec/MultipleMemoizedHelpers), so each finds what an earlier call made.
  def account = user.account
  def binder = account.locations.find_by(name: "Blue binder") || create(:location, account:, name: "Blue binder")
  def rival = (@rival ||= "Rival #{SecureRandom.hex(4)}") # built at run time: the test 404 page prints the spec's source
  def other_deck = other.decks.joins(:location).find_by(locations: { name: rival }) || create(:deck, account: other, name: rival)
  def other_proxy = Deck::Proxy.find_by(account: other) || create(:deck_proxy, zone: other_deck.zone("main"), account: other, entry:, finish: "foil", quantity: 2)

  def sibling_proxy
    sibling = account.decks.joins(:location).find_by(locations: { name: "Sibling deck" }) || create(:deck, account:, name: "Sibling deck")
    Deck::Proxy.find_by(zone: sibling.zone("main")) || create(:deck_proxy, zone: sibling.zone("main"), account:, entry:, finish: "foil", quantity: 2)
  end

  before do
    sign_in_as(user)
    other_proxy
    sibling_proxy
  end

  [
    [ "another account's deck and proxy", ->(t) { [ t.other_deck, t.other_proxy ] } ],
    [ "this deck with another account's proxy", ->(t) { [ t.deck, t.other_proxy ] } ],
    [ "this deck with a proxy of another deck of the account", ->(t) { [ t.deck, t.sibling_proxy ] } ],
    [ "another account's deck with this proxy", ->(t) { [ t.other_deck, t.proxy ] } ],
    [ "a place's id as the deck", ->(t) { [ t.binder, t.proxy ] } ],
    [ "a zone's id as the deck", ->(t) { [ t.deck.zone("main"), t.proxy ] } ],
    [ "an id that isn't digits only as the proxy", ->(t) { [ t.deck, "#{t.proxy.id}abc" ] } ]
  ].each do |name, pick|
    it "answers 404 for #{name} on both pages and both verbs, and writes nothing", :aggregate_failures do
      deck_arg, proxy_arg = pick.call(self)
      lot = create(:lot, account:, entry:, location: binder, quantity: 2, finish: "foil")

      get new_deck_proxy_replacement_path(deck_arg, proxy_arg)
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include(rival)
      post deck_proxy_replacement_path(deck_arg, proxy_arg), params: { lots: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "2" } }
      expect(response).to have_http_status(:not_found)
      get new_deck_proxy_copy_path(deck_arg, proxy_arg)
      expect(response).to have_http_status(:not_found)
      post deck_proxy_copy_path(deck_arg, proxy_arg), params: { lot: { quantity: "1", finish: "foil" }, shown_quantity: "2" }
      expect(response).to have_http_status(:not_found)

      expect([ lot.reload.location, proxy.reload.quantity, other_proxy.reload.quantity, sibling_proxy.reload.quantity, Lot.where(location: deck.zone("main")).count ]).to eq([ binder, 2, 2, 2, 0 ])
    end
  end

  it "shows the owner their own page for the same request, so the 404s above are not a bad fixture", :aggregate_failures do
    get new_deck_proxy_replacement_path(deck, proxy)
    expect(response).to have_http_status(:ok)
    get new_deck_proxy_copy_path(deck, proxy)
    expect(response).to have_http_status(:ok)
  end

  it "counts another account's lot of the card as no longer free: 422, nothing moved, and the page doesn't say it exists", :aggregate_failures do
    theirs = create(:lot, account: other, entry:, location: create(:location, account: other), quantity: 2, finish: "foil")

    post deck_proxy_replacement_path(deck, proxy), params: { lots: { theirs.id.to_s => "1" }, shown: { theirs.id.to_s => "2" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML5(response.body).at_css("#replacement-error").text).to eq("Those copies changed. Check the numbers and try again.")
    expect([ theirs.reload.quantity, proxy.reload.quantity ]).to eq([ 2, 2 ])
  end

  it "sends the signed-out visitor to sign in on all four" do
    delete session_path
    [ [ :get, new_deck_proxy_replacement_path(deck, proxy) ], [ :post, deck_proxy_replacement_path(deck, proxy) ],
      [ :get, new_deck_proxy_copy_path(deck, proxy) ], [ :post, deck_proxy_copy_path(deck, proxy) ] ].each do |verb, path|
      public_send(verb, path)
      expect(response).to redirect_to(new_session_path)
    end
  end
end
