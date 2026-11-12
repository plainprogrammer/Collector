require "rails_helper"

# Spec 070 Story 4: Add a new copy, GET /decks/:id/proxies/:id/copy/new and its POST.
RSpec.describe "Add a new copy", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil], entry: create(:catalog_entry, name: "Lightning Bolt", number: "138", set: create(:catalog_set, code: "mh2"))).entry }
  let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 3) }

  def html = Nokogiri::HTML5(response.body)
  def post_copy(lot = {}, shown: "3", to: proxy) = post(deck_proxy_copy_path(deck, to), params: { lot: { quantity: "1", finish: "foil" }.merge(lot), shown_quantity: shown })

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the page (AC-4.1)" do
      it "is a detail page of the deck's section that names the card, the proxy row and the way back", :aggregate_failures do
        get new_deck_proxy_copy_path(deck, proxy)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Add a new copy of Lightning Bolt · Collector")
        expect(html.at_css("header.c-appbar--detail a[aria-label='Back'][href='#{deck_path(deck)}']")).to be_present
        expect(html.at_css("main")["class"].split).to include("c-decks")
        expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Replaces 3 proxies in Izzet Tempo › Main · MH2 · 138, Foil")
        expect(html.css("a.c-btn").find { it.text == "Cancel" }["href"]).to eq(deck_path(deck))
      end

      it "is the Add a copy form for the proxy's printing, with its finish chosen, the zone read-only and the count as the maximum", :aggregate_failures do
        get new_deck_proxy_copy_path(deck, proxy)

        quantity = html.at_css("input[name='lot[quantity]']")
        expect(quantity.attributes.slice("value", "min", "max").transform_values(&:value)).to eq("value" => "1", "min" => "1", "max" => "3")
        expect(html.at_css("select[name='lot[finish]'] option[selected]")["value"]).to eq("foil")
        expect(html.css("select[name='lot[condition]'], input[name='lot[price_paid]']").size).to eq(2)
        expect(html.at_css("select[name='lot[location_id]']")).to be_nil
        expect(html.at_css("p.c-field__label").text).to eq("Location")
        expect(html.at_css("p.c-field__label + p.c-field__value").text).to eq("Izzet Tempo › Main")
        expect(html.text).not_to include("Add a location")
        expect(html.at_css("input[name=shown_quantity]")["value"]).to eq("3")
        expect(html.at_css("input[type=submit]")["value"]).to eq("Add copy")
      end

      it "has no Finish select for a printing that lists none" do
        bare = create(:mtg_printing, finishes: []).entry
        bare_proxy = create(:deck_proxy, zone: deck.zone("main"), account:, entry: bare, finish: nil, quantity: 1)

        get new_deck_proxy_copy_path(deck, bare_proxy)

        expect(html.at_css("select[name='lot[finish]']")).to be_nil
      end

      it "answers 404 for a proxy whose printing's collectible the instance no longer registers" do
        entry.update_columns(collectible_type: "gone")

        get new_deck_proxy_copy_path(deck, proxy)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "the card page's own form and Edit copy (AC-4.9)" do
      it "are unchanged: a Quantity maximum of 9,999, a location select and their own Cancel", :aggregate_failures do
        place = create(:location, account:, name: "Blue binder")
        get new_catalog_entry_lot_path(entry.external_key)
        expect(html.at_css("input[name='lot[quantity]']")["max"]).to eq("9999")
        expect(html.at_css("select[name='lot[location_id]']")).to be_present
        expect(html.at_css("input[name=shown_quantity]")).to be_nil
        expect(html.css("a.c-btn").find { it.text == "Cancel" }["href"]).to eq(catalog_entry_path(entry))

        lot = create(:lot, account:, entry:, location: place)
        get edit_lot_path(lot)
        expect(html.at_css("input[name='lot[quantity]']")["max"]).to eq("9999")
        expect(html.at_css("select[name='lot[location_id]']")).to be_present
        expect(html.css("a.c-btn").find { it.text == "Cancel" }["href"]).not_to eq(deck_path(deck))
      end
    end

    describe "adding the copy (AC-4.2 to AC-4.8)" do
      it "adds the lot to the proxy's zone, lowers the proxy and goes back to the deck page", :aggregate_failures do
        post_copy({ quantity: "2", condition: "near_mint", price_paid: "1.25" })

        expect(response).to redirect_to(deck_path(deck))
        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq("Added 2 × Lightning Bolt (MH2 · 138) to Izzet Tempo › Main, replacing 2 proxies.")
        expect(proxy.reload.quantity).to eq(1)
        expect(account.lots.find_by(location: deck.zone("main"))).to have_attributes(entry:, quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 125)
      end

      it "says '3 proxies' and removes the proxy when the quantity is its whole count, and '1 proxy' for one", :aggregate_failures do
        post_copy({ quantity: "3" })
        expect(flash[:notice]).to end_with("replacing 3 proxies.")
        expect(Deck::Proxy.exists?(proxy.id)).to be(false)

        one = create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "nonfoil", quantity: 1)
        post_copy({ quantity: "1", finish: "nonfoil" }, shown: "1", to: one)
        expect(flash[:notice]).to end_with("replacing 1 proxy.")
      end

      it "lowers the proxy in the path whatever the copy's finish (AC-4.5)", :aggregate_failures do
        post_copy({ finish: "nonfoil" })

        expect(account.lots.find_by(location: deck.zone("main")).finish).to eq("nonfoil")
        expect(proxy.reload.quantity).to eq(2)
      end

      it "refuses a quantity over the proxy's count, keeping what was typed (AC-4.3)", :aggregate_failures do
        post_copy({ quantity: "4", price_paid: "2.5" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#lot_quantity-error").text).to eq("Enter a number from 1 to 3.")
        expect(html.at_css("input[name='lot[quantity]']")["value"]).to eq("4")
        expect(html.at_css("input[name='lot[price_paid]']")["value"]).to eq("2.5")
        expect(html.at_css("input[name=shown_quantity]")["value"]).to eq("3")
        expect([ proxy.reload.quantity, account.lots.count ]).to eq([ 3, 0 ])
      end

      it "gives Add a copy's own sentence to a quantity that isn't a whole number from 1 to 9,999 (AC-4.3)", :aggregate_failures do
        post_copy({ quantity: "10000" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#lot_quantity-error").text).to eq("Quantity must be a whole number from 1 to 9,999")
      end

      it "gives Add a copy's own sentence to a finish, a price and a condition it refuses, and writes nothing", :aggregate_failures do
        { { finish: "etched" } => [ "#lot_finish-error", "Finish isn't available for this printing" ],
          { price_paid: "-1" } => [ "#lot_price_paid-error", "Price paid must be a non-negative amount with at most two decimal places" ],
          { condition: "bogus" } => [ "#lot_condition-error", "Condition isn't a known condition" ] }.each do |lot, (error, sentence)|
          post_copy(lot)

          expect(response).to have_http_status(:unprocessable_content)
          expect(html.at_css(error).text).to eq(sentence)
        end
        expect([ proxy.reload.quantity, account.lots.count ]).to eq([ 3, 0 ])
      end

      it "refuses a proxy that is not the count the form showed, writes the count now, and the next submit works (AC-4.6, AC-4.6a)", :aggregate_failures do
        post_copy({ quantity: "1" }, shown: "3")
        post_copy({ quantity: "1" }, shown: "3") # the second submit of one form

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#lot_quantity-error").text).to eq("This proxy changed. Check the quantity and try again.")
        expect(html.at_css("input[name=shown_quantity]")["value"]).to eq("2")
        expect(html.at_css("input[name='lot[quantity]']")["max"]).to eq("2")
        expect([ proxy.reload.quantity, account.lots.sum(:quantity) ]).to eq([ 2, 1 ])

        post_copy({ quantity: "1" }, shown: "2")
        expect(response).to redirect_to(deck_path(deck))
      end

      it "says the proxy changed as well as the price's own sentence, and shows the count now (decision 10)", :aggregate_failures do
        post_copy({ quantity: "1", price_paid: "-1" }, shown: "5")

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#lot_price_paid-error").text).to be_present
        expect(html.at_css("#lot_quantity-error").text).to eq("This proxy changed. Check the quantity and try again.")
        expect(html.at_css("input[name=shown_quantity]")["value"]).to eq("3")
        expect([ proxy.reload.quantity, account.lots.count ]).to eq([ 3, 0 ])
      end

      it "refuses a merge past 9,999 and changes nothing (AC-4.4)", :aggregate_failures do
        create(:lot, account:, entry:, location: deck.zone("main"), finish: "foil", quantity: 9_999)

        post_copy

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#lot_quantity-error").text).to eq("One lot can hold at most 9,999 copies.")
        expect(proxy.reload.quantity).to eq(3)
      end

      it "ignores an account id, a location id, a zone id and an entry key (AC-4.7)", :aggregate_failures do
        other_entry = create(:mtg_printing).entry
        post deck_proxy_copy_path(deck, proxy), params: { lot: { quantity: "1", finish: "foil", location_id: create(:location, account:).id, entry: other_entry.external_key },
                                                          shown_quantity: "3", account_id: create(:user).account.id, zone_id: deck.zone("sideboard").id }

        lot = account.lots.sole
        expect([ lot.location, lot.entry ]).to eq([ deck.zone("main"), entry ])
      end

      it "answers 404 for a proxy removed meanwhile and writes nothing", :aggregate_failures do
        stale = proxy.id
        proxy.destroy!

        post deck_proxy_copy_path(deck, stale), params: { lot: { quantity: "1" }, shown_quantity: "3" }

        expect(response).to have_http_status(:not_found)
        expect(account.lots.count).to eq(0)
      end
    end
  end

  it "sends a visitor who isn't signed in to sign in" do
    get new_deck_proxy_copy_path(deck, proxy)

    expect(response).to redirect_to(new_session_path)
  end
end
