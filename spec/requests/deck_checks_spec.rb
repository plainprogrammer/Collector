require "rails_helper"

RSpec.describe "Deck checks", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo", format: "standard") }

  def html = Nokogiri::HTML5(response.body)

  def printing(name: "Lightning Bolt", type_line: "Instant")
    entry = create(:catalog_entry, identity: create(:catalog_identity, name:), name:)
    create(:mtg_printing, entry:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => "{R}", "image_uris" => {} } ])
    entry
  end

  def plains = printing(name: "Plains", type_line: "Basic Land — Plains")
  def own(zone, entry, quantity: 1) = create_lot_in_zone(deck, zone, entry:, quantity:)
  def proxy_in(zone, entry) = create(:deck_proxy, zone: deck.zone(zone), account:, entry:, finish: "nonfoil", quantity: 1)
  def rows = html.css(".c-check__row").map { it.text.squish }

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the button and no results on the plain deck page (AC-1.1, 1.9)", :aggregate_failures do
      get deck_path(deck)
      expect(html.at_css(".c-item__actions > a.c-btn--secondary[href='#{deck_check_path(deck)}']").text).to eq("Check deck")
      expect(html.at_css("#deck-check-title")).to be_nil
      expect(html.at_css("main form")).to be_nil
      expect(response.body).not_to include('name="turbo-cache-control"')
    end

    it "shows the summary and the results between the head and the zones (AC-1.2, 1.7, 1.8, 1.9)", :aggregate_failures do
      own("main", plains, quantity: 58)
      get deck_check_path(deck)
      expect(response).to have_http_status(:ok)
      expect([ html.at_css("#deck-check-title").text, html.at_css(".c-check__summary").text ]).to eq([ "Deck check", "1 finding" ])
      expect(rows).to eq([ "Short Main: 58 cards; Standard needs at least 60.", "Pass Sideboard: 0 cards; Standard allows at most 15.",
                           "Pass No card is over its limit.", "Pass No card has both owned copies and proxies in one zone." ])
      expect(html.css("main > *").first(3).map { it["class"].to_s.split.first }).to eq(%w[c-item__head c-check c-deck])
      expect(response.body).to include('<meta name="turbo-cache-control" content="no-cache">')
      expect(html.at_css("main form")).to be_nil
    end

    it "shows the same results again and every link of the plain page (AC-1.4, 1.5)", :aggregate_failures do
      own("main", plains, quantity: 58)
      get deck_path(deck)
      plain = html.css("main a[href]").map { it["href"] }
      get deck_check_path(deck)
      first = rows
      get deck_check_path(deck)
      expect(rows).to eq(first)
      expect(html.css("main a[href]").map { it["href"] }).to include(*plain)
      expect(html.css("main a, main button").map { it["disabled"] || it["aria-disabled"] }.compact).to be_empty
      get edit_deck_path(deck) # following one of them works as from the plain page
      expect(response).to have_http_status(:ok)
    end

    it "changes nothing: no write reaches lots, proxies or locations (AC-4.8)", :aggregate_failures do
      entry = printing
      own("main", entry)
      proxy_in("main", entry)
      before = [ Lot.sum(:quantity), Deck::Proxy.sum(:quantity), Location.count ]
      writes = [ Lot, Deck::Proxy, Location ].flat_map { |model| write_statements_to(model.table_name) { get deck_check_path(deck) } }
      expect(writes).to be_empty
      expect([ Lot.sum(:quantity), Deck::Proxy.sum(:quantity), Location.count ]).to eq(before)
    end

    it "shows no results on the next deck page request after the deck changes (AC-1.3)", :aggregate_failures do
      entry = printing
      own("main", entry)
      proxy = proxy_in("main", entry)
      get deck_check_path(deck)
      expect(rows).to include("Owned and proxy Lightning Bolt in Main: 1 owned, 1 proxy.")
      delete deck_proxy_path(deck, proxy)
      follow_redirect!
      expect(html.at_css("#deck-check-title")).to be_nil
      expect(html.at_css("a[href='#{deck_check_path(deck)}']")).to be_present
      get deck_check_path(deck) # pressing the button again judges the changed deck
      expect(rows).not_to include(a_string_matching(/Owned and proxy/))
    end

    it "words no findings, one finding and several (AC-1.7)", :aggregate_failures do
      own("main", plains, quantity: 60)
      get deck_check_path(deck)
      expect(html.at_css(".c-check__summary").text).to eq("No findings")
      own("sideboard", plains, quantity: 16)
      get deck_check_path(deck)
      expect(html.at_css(".c-check__summary").text).to eq("1 finding")
      own("main", printing(name: "Shock"), quantity: 5)
      get deck_check_path(deck)
      expect(html.at_css(".c-check__summary").text).to eq("2 findings")
    end

    it "gives a deck with no rules the no-rules line and the owned-plus-proxy result (AC-2.7)" do
      get deck_check_path(create(:deck, account:, name: "Pile", format: "casual"))
      expect(rows).to eq([ "Casual has no rules to check.", "Pass No card has both owned copies and proxies in one zone." ])
    end

    it "is a 404 for another account's deck, a zone and a bad id (AC-1.6)", :aggregate_failures do
      theirs = "Rival #{SecureRandom.hex(4)}" # built at run time: the test 404 page prints the spec's own source lines (docs/lessons 2026-11-11)
      other = create(:deck, account: create(:user).account, name: theirs)
      [ other.to_param, deck.zone("main").id, 0, "abc" ].each do |id|
        get deck_check_path(id)
        expect(response).to have_http_status(:not_found), "#{id.inspect} was not a 404"
        expect(response.body).not_to include(theirs)
      end
    end
  end

  it "redirects a visitor who is not signed in (AC-5.2)" do
    get deck_check_path(deck)
    expect(response).to redirect_to(new_session_path)
  end

  describe "statements" do
    before { sign_in_as(user) }

    # `count_queries` is `spec/support/query_counting.rb`'s (cached, SCHEMA and TRANSACTION statements are not counted).
    def queries_for(path)
      count = count_queries { get path }
      expect(response).to have_http_status(:ok)
      count
    end

    # +rows+ printings of one identity, bulk-inserted and owned in the deck's Main zone, ten of them also as proxies.
    def fill(deck, rows, label)
      set = create(:catalog_set, code: label)
      identity = create(:catalog_identity, name: "Bulk #{label}")
      now = Time.current
      Catalog::Entry.insert_all(Array.new(rows) { |i| { collectible_type: "mtg", external_key: "#{label}-#{i}", catalog_set_id: set.id, catalog_identity_id: identity.id, number: i.to_s, language: "en", name: "Card #{i}", kind: "card", content_digest: "d", created_at: now, updated_at: now } })
      ids = Catalog::Entry.where(catalog_set_id: set.id).pluck(:id)
      MTG::Printing.insert_all(ids.map { |id| { catalog_entry_id: id, rarity: "common", finishes: %w[nonfoil], layout: "normal", scryfall_uri: "https://example.test/#{id}", faces: [], created_at: now, updated_at: now } })
      location = deck.zone("main")
      Lot.insert_all(ids.map { |id| { account_id: account.id, catalog_entry_id: id, quantity: 2, finish: "nonfoil", price_paid_cents: nil, location_id: location.id, lot_key: Lot.key_for("nonfoil", nil, nil, location.id), created_at: now, updated_at: now } })
      ids.first(10).each { |id| create(:deck_proxy, zone: location, account:, entry: Catalog::Entry.find(id), finish: "nonfoil", quantity: 1) }
    end

    it "runs the plain deck page's statements however many rows the deck has", :aggregate_failures do
      small = create(:deck, account:, name: "Small", format: "standard")
      big = create(:deck, account:, name: "Big", format: "standard")
      fill(small, 5, "small")
      fill(big, 500, "big")
      [ small, big ].each { |deck| get deck_path(deck) } # warm the page once
      expect(queries_for(deck_check_path(small))).to eq(queries_for(deck_path(small)))
      expect(queries_for(deck_check_path(big))).to eq(queries_for(deck_path(big)))
      expect(queries_for(deck_check_path(big))).to eq(queries_for(deck_check_path(small)))
    end
  end
end
