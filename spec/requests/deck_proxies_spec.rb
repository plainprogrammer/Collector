require "rails_helper"

# Spec 068 Stories 1 and 3: the add, change and remove pages of a deck zone's proxies.
RSpec.describe "Deck proxies", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:bolt) { create(:catalog_identity, name: "Lightning Bolt") }

  def html = Nokogiri::HTML5(response.body)
  # Printings of one card share an identity (the search groups by it); pass `identity: bolt` for several printings of a card.
  def printing(name: "Lightning Bolt", finishes: %w[foil nonfoil], identity: nil, **attrs)
    create(:mtg_printing, entry: create(:catalog_entry, name:, identity: identity || create(:catalog_identity, name:), **attrs), finishes:).entry
  end

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the chooser (AC-1.2, AC-1.3)" do
      it "is a detail page titled for the zone, with the search and no results until a name or a set is given", :aggregate_failures do
        get new_deck_zone_proxy_path(deck, "main")

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Add a proxy to Izzet Tempo › Main · Collector")
        expect(html.at_css("header.c-appbar--detail")).to be_present
        expect(html.at_css("input[name=q]")).to be_present
        expect(html.at_css("select[name=set]")).to be_present
        expect(html.css("a").select { it.text.start_with?("Choose") }).to be_empty
      end

      it "lists a card's printings of the deck's type with a Choose link each, and no retired or other printing", :aggregate_failures do
        first = printing(identity: bolt)
        second = printing(identity: bolt, set: create(:catalog_set, code: "mh2"))
        create(:mtg_printing, entry: create(:catalog_entry, :retired, name: "Lightning Bolt", identity: bolt))
        create(:catalog_entry, name: "Lightning Bolt", collectible_type: "other")

        get new_deck_zone_proxy_path(deck, "main", q: "Lightning")

        links = html.css("a").select { it.text.start_with?("Choose") }
        expect(links.map { it["href"] }).to match_array([ first, second ].map { new_deck_zone_proxy_path(deck, "main", entry: it.external_key) })
        expect(html.text).to include("2 printings")
      end

      it "says how many printings of a card with more than ten it shows (AC-1.3)" do
        12.times { |n| printing(identity: bolt, set: create(:catalog_set, code: "s#{n}")) }

        get new_deck_zone_proxy_path(deck, "main", q: "Lightning")

        expect(html.text).to include("Showing 10 of 12 printings. Choose a set to see the others.")
      end

      it "pages the cards as the card search does (12 a page)", :aggregate_failures do
        13.times { |n| printing(name: "Bolt #{format("%02d", n)}") }

        get new_deck_zone_proxy_path(deck, "main", q: "Bolt")

        expect(html.css("section.c-group").size).to eq(12)
        expect(html.at_css("nav.c-pager a[rel=next]")["href"]).to start_with(new_deck_zone_proxy_path(deck, "main", q: "Bolt", page: 2)) # the path's own params survive in the pager
      end
    end

    describe "the form (AC-1.4)" do
      it "shows the printing, a Finish select of its finishes (in the vocabulary's order) with nothing chosen, a Quantity of 1, Add proxy and Cancel", :aggregate_failures do
        entry = printing

        get new_deck_zone_proxy_path(deck, "main", entry: entry.external_key)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("h1").text).to eq("Add a proxy to Izzet Tempo › Main")
        expect(html.at_css("select[name='proxy[finish]'] option[selected]")).to be_nil
        expect(html.css("select[name='proxy[finish]'] option").map(&:text)).to eq([ "Choose…", "Nonfoil", "Foil" ]) # the vocabulary's finish order
        expect(html.at_css("input[name='proxy[quantity]']")["value"]).to eq("1")
        expect(html.at_css("input[type=submit]")["value"]).to eq("Add proxy")
        expect(html.css("a").find { it.text.squish == "Cancel" }["href"]).to eq(deck_path(deck))
        expect(html.css("label").map(&:text)).to include("Finish", "Quantity") # each field has its visible label (AC-9.1)
      end

      it "ties a field's error to it with aria-describedby (AC-9.1)", :aggregate_failures do
        post deck_zone_proxies_path(deck, "main"), params: { proxy: { entry: printing.external_key, finish: "foil", quantity: "0" } }

        field = html.at_css("input[name='proxy[quantity]']")
        expect(field["aria-describedby"]).to be_present
        expect(html.at_css("##{field["aria-describedby"]}").text).to eq("Enter a number from 1 to 9,999.")
      end

      it "chooses the only finish, and shows no Finish select for a printing that lists none", :aggregate_failures do
        get new_deck_zone_proxy_path(deck, "main", entry: printing(finishes: %w[nonfoil]).external_key)
        expect(html.at_css("select[name='proxy[finish]'] option[selected]").text).to eq("Nonfoil")

        get new_deck_zone_proxy_path(deck, "main", entry: printing(finishes: []).external_key)
        expect(html.at_css("select[name='proxy[finish]']")).to be_nil
      end
    end

    describe "the create (AC-1.5, AC-1.6, AC-1.8 to AC-1.10)" do
      def add(entry, zone: "main", **proxy) = post(deck_zone_proxies_path(deck, zone), params: { proxy: { entry: entry.external_key, finish: "foil", quantity: "2" }.merge(proxy) })

      it "writes the proxy, redirects to the deck page with the notice, and creates no lot", :aggregate_failures do
        entry = printing

        add(entry)

        expect(response).to redirect_to(deck_path(deck))
        expect(flash[:notice]).to eq("Added 2 proxies of Lightning Bolt (#{entry.set.code.upcase} · #{entry.number}, Foil) to Izzet Tempo › Main.")
        proxy = Deck::Proxy.sole
        expect([ proxy.zone, proxy.entry, proxy.finish, proxy.quantity ]).to eq([ deck.zone("main"), entry, "foil", 2 ])
        expect(Lot.count).to eq(0)
      end

      it "says '1 proxy' for one, and merges into the proxy it already has (same id)", :aggregate_failures do
        entry = printing
        add(entry, quantity: "1")
        expect(flash[:notice]).to start_with("Added 1 proxy of ")
        first = Deck::Proxy.sole

        add(entry, quantity: "3")

        expect(Deck::Proxy.sole.id).to eq(first.id)
        expect(Deck::Proxy.sole.quantity).to eq(4)
      end

      it "answers 422 with the field's sentence and what was typed, and writes nothing", :aggregate_failures do
        entry = printing

        add(entry, quantity: "0")
        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css(".c-field__error").text).to eq("Enter a number from 1 to 9,999.")
        expect(html.at_css("input[name='proxy[quantity]']")["value"]).to eq("0")
        add(entry, finish: "")
        expect(html.at_css(".c-field__error").text).to eq("Choose a finish.")
        add(entry, finish: "etched")
        expect(html.at_css(".c-field__error").text).to eq("That finish isn't available for this printing.")
        expect(Deck::Proxy.count).to eq(0)
      end

      it "refuses an add past 9,999 with the cap sentence and changes nothing", :aggregate_failures do
        entry = printing
        add(entry, quantity: "9990")

        add(entry, quantity: "10")

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css(".c-field__error").text).to eq(Deck::Proxy::FULL_MESSAGE)
        expect(Deck::Proxy.sole.quantity).to eq(9_990)
      end

      it "reads no account, zone id, kind or user from the request (AC-1.11)", :aggregate_failures do
        stranger = create(:user).account
        entry = printing

        post deck_zone_proxies_path(deck, "main"), params: { account_id: stranger.id, location_id: 1, kind: "place", user_id: 1,
                                                              proxy: { entry: entry.external_key, finish: "foil", quantity: "1", account_id: stranger.id, location_id: 1 } }

        expect(Deck::Proxy.sole.account).to eq(account)
        expect(Deck::Proxy.sole.zone).to eq(deck.zone("main"))
      end
    end

    describe "what is 404 (AC-1.7, AC-1.10)" do
      let(:entry) { printing }

      it "answers 404 for another account's deck, a place, a zone, a malformed id, a zone key the deck lacks and an entry it can't use", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- a table of paths
        theirs = create(:deck, account: create(:user).account, name: "Theirs")
        place = create(:location, account:)
        retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
        elsewhere = create(:catalog_entry, collectible_type: "other")
        token = create(:catalog_entry, kind: "token")
        bad = [
          new_deck_zone_proxy_path(theirs, "main"), new_deck_zone_proxy_path(place.id, "main"), new_deck_zone_proxy_path(deck.zone("main").id, "main"),
          "/decks/12abc/zones/main/proxies/new", new_deck_zone_proxy_path(deck, "commander"),
          new_deck_zone_proxy_path(deck, "main", entry: "no-such-entry"), new_deck_zone_proxy_path(deck, "main", entry: retired.external_key),
          new_deck_zone_proxy_path(deck, "main", entry: elsewhere.external_key), new_deck_zone_proxy_path(deck, "main", entry: token.external_key)
        ]
        bad.each do |path|
          get path
          expect(response).to have_http_status(:not_found), path
        end
        post deck_zone_proxies_path(theirs, "main"), params: { proxy: { entry: entry.external_key, finish: "foil", quantity: "1" } }
        expect(response).to have_http_status(:not_found)
        post deck_zone_proxies_path(deck, "main"), params: { proxy: { entry: retired.external_key, finish: "foil", quantity: "1" } }
        expect(response).to have_http_status(:not_found)
        expect(Deck::Proxy.count).to eq(0)
      end

      it "answers 404 for a deck whose collectible type the instance no longer registers (decision 19)" do
        deck.update_columns(collectible_type: "gone")

        get new_deck_zone_proxy_path(deck, "main")

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "changing a proxy (Story 3)" do
      let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account:, entry: printing, finish: "foil", quantity: 2) }

      def name = "Lightning Bolt (#{proxy.entry.set.code.upcase} · #{proxy.entry.number}, Foil)" # not a `let`: RSpec/MultipleMemoizedHelpers allows 5

      it "shows the proxy named with its deck, zone and finish, the count, Save and Cancel (AC-3.1)", :aggregate_failures do
        get edit_deck_proxy_path(deck, proxy)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("header.c-appbar--detail")).to be_present
        expect(html.at_css("h1").text).to include("Lightning Bolt")
        expect(html.text).to include("Izzet Tempo › Main")
        expect(html.text).to include("Foil")
        expect(html.at_css("input[name='proxy[quantity]']")["value"]).to eq("2")
        expect(html.at_css("input[type=submit]")["value"]).to eq("Save")
        expect(html.css("a").find { it.text.squish == "Cancel" }["href"]).to eq(deck_path(deck))
      end

      it "saves a quantity from 1 to 9,999 keeping the id, and says so (AC-3.2)", :aggregate_failures do
        patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "4" } }

        expect(response).to redirect_to(deck_path(deck))
        expect(flash[:notice]).to eq("Changed the proxies of #{name} in Izzet Tempo › Main to 4.")
        expect(proxy.reload.quantity).to eq(4)
      end

      it "writes nothing for the same quantity (AC-3.2)", :aggregate_failures do
        expect(write_statements_to("deck_proxies") { patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "2" } } }).to be_empty
        expect(response).to redirect_to(deck_path(deck))
      end

      it "refuses 0, a negative number, over 9,999, text and nothing, keeping what was typed (AC-3.3)", :aggregate_failures do
        [ "0", "-1", "10000", "x", "" ].each do |text|
          patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: text } }

          expect(response).to have_http_status(:unprocessable_content), text.inspect
          expect(html.at_css(".c-field__error").text).to start_with("Enter a number from 1 to 9,999.")
          expect(html.at_css("input[name='proxy[quantity]']")["value"]).to eq(text)
        end
        expect(html.at_css(".c-field__error").text).not_to include("Remove proxy")
        patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "0" } }
        expect(html.at_css(".c-field__error").text).to eq("Enter a number from 1 to 9,999. To remove it, use Remove proxy.")
        expect(proxy.reload.quantity).to eq(2)
      end

      it "touches no lot, location, deck or other proxy (AC-3.7)", :aggregate_failures do
        other = create(:deck_proxy, zone: deck.zone("main"), account:, entry: printing(name: "Spell Pierce"))
        lot = create_lot_in_zone(deck, "main")
        before = [ Lot.pluck(:updated_at), Location.pluck(:updated_at), Deck.pluck(:updated_at), other.reload.updated_at ]

        patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "7" } }

        expect([ Lot.pluck(:updated_at), Location.pluck(:updated_at), Deck.pluck(:updated_at), other.reload.updated_at ]).to eq(before)
        expect(lot.reload.quantity).to eq(1)
      end
    end

    describe "removing a proxy (Story 3)" do
      let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account:, entry: printing, finish: "foil", quantity: 2) }

      before { create(:deck_proxy, zone: deck.zone("main"), account:, entry: proxy.entry, finish: "nonfoil", quantity: 1) } # the same printing in another finish

      def name = "Lightning Bolt (#{proxy.entry.set.code.upcase} · #{proxy.entry.number}, Foil)" # not a `let`: RSpec/MultipleMemoizedHelpers allows 5

      it "asks first on a page that removes nothing by itself (AC-3.4)", :aggregate_failures do
        get new_deck_proxy_removal_path(deck, proxy)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("h1").text).to eq("Remove the proxies of #{name} from Izzet Tempo › Main?")
        expect(html.at_css("form[action='#{deck_proxy_path(deck, proxy)}'] input[name=_method][value=delete]")).to be_present
        expect(html.css("a").find { it.text.squish == "Cancel" }["href"]).to eq(deck_path(deck))
        expect(Deck::Proxy.count).to eq(2)
      end

      it "removes that proxy only, and says so (AC-3.4)", :aggregate_failures do
        delete deck_proxy_path(deck, proxy)

        expect(response).to redirect_to(deck_path(deck))
        expect(flash[:notice]).to eq("Removed the proxies of #{name} from Izzet Tempo › Main.")
        expect(Deck::Proxy.pluck(:finish)).to eq([ "nonfoil" ])
      end

      it "answers 404 for a proxy removed meanwhile and for a second delete (AC-3.5)", :aggregate_failures do
        proxy.destroy!

        get edit_deck_proxy_path(deck, proxy)
        expect(response).to have_http_status(:not_found)
        delete deck_proxy_path(deck, proxy)
        expect(response).to have_http_status(:not_found)
        patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "3" } }
        expect(response).to have_http_status(:not_found)
      end

      it "answers 404 for every proxy page of a deck removed meanwhile (AC-5.5)", :aggregate_failures do
        removed = create(:deck_proxy, zone: deck.zone("sideboard"), account:)
        id = deck.location_id
        deck.remove!

        [ new_deck_zone_proxy_path(id, "main"), edit_deck_proxy_path(id, removed.id), new_deck_proxy_removal_path(id, removed.id) ].each do |path|
          get path
          expect(response).to have_http_status(:not_found), path
        end
        delete deck_proxy_path(id, removed.id)
        expect(response).to have_http_status(:not_found)
      end

      it "answers 404 for another account's proxy, another deck's proxy under this deck, a place's or a zone's id as the deck, and a malformed id (AC-3.6)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- a table of paths
        theirs = create(:deck_proxy)
        elsewhere = create(:deck, account:, name: "Elsewhere")
        elsewhere_proxy = create(:deck_proxy, zone: elsewhere.zone("main"), account:)
        place = create(:location, account:)
        paths = [ [ :get, edit_deck_proxy_path(deck, theirs) ], [ :get, edit_deck_proxy_path(deck, elsewhere_proxy) ],
                  [ :get, new_deck_proxy_removal_path(deck, elsewhere_proxy) ], [ :delete, deck_proxy_path(deck, elsewhere_proxy) ],
                  [ :patch, deck_proxy_path(deck, theirs) ], [ :get, edit_deck_proxy_path(place.id, proxy) ],
                  [ :get, edit_deck_proxy_path(deck.zone("main").id, proxy) ], [ :get, "/decks/#{deck.location_id}/proxies/12abc/edit" ] ]
        paths.each do |verb, path|
          public_send(verb, path)
          expect(response).to have_http_status(:not_found), "#{verb} #{path}"
        end
        expect(Deck::Proxy.count).to eq(4)
      end
    end
  end

  it "sends a visitor who isn't signed in to sign in (AC-1.7)", :aggregate_failures do
    deck = create(:deck)

    get new_deck_zone_proxy_path(deck, "main")
    expect(response).to redirect_to(new_session_path)
    post deck_zone_proxies_path(deck, "main")
    expect(response).to redirect_to(new_session_path)
  end
end
