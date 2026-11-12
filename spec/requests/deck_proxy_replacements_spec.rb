require "rails_helper"

# Spec 070 Stories 2 and 3: Use my copy, GET /decks/:id/proxies/:id/replacement/new and its POST.
RSpec.describe "Use my copy", type: :request do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:bolt) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:entry) { printing }
  let!(:proxy) { proxy_of(entry) }

  # Not memoized `let`s: the group has five at most (RSpec/MultipleMemoizedHelpers), so each finds what an earlier call made.
  def account = user.account
  def place(name) = account.locations.find_by(name:) || create(:location, account:, name:)
  def binder = place("Blue binder")
  def box = place("Red box")
  def html = Nokogiri::HTML5(response.body)

  def printing(set: "2x2", number: "117", language: "en", finishes: %w[foil nonfoil])
    set = Catalog::Set.find_by(code: set) || create(:catalog_set, code: set)
    create(:mtg_printing, finishes:, entry: create(:catalog_entry, name: "Lightning Bolt", identity: bolt, number:, language:, set:)).entry
  end

  def lot_in(location, entry, quantity = 1, **attrs) = create(:lot, account:, entry:, location:, quantity:, **attrs)
  def proxy_of(entry, quantity: 2, finish: "foil") = create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish:, quantity:)

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the page (AC-2.1 to AC-2.6)" do
      it "is a detail page that names the card and the proxy row, with a field of 0 per free lot", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil", condition: "near_mint", price_paid_cents: 125)

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Use my copy of Lightning Bolt · Collector")
        expect(html.at_css("header.c-appbar--detail a[aria-label='Back'][href='#{deck_path(deck)}']")).to be_present
        expect(html.at_css("main")["class"].split).to include("c-decks")
        expect(html.at_css("h1").text).to eq("Use my copy of Lightning Bolt")
        expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Replaces 2 proxies in Izzet Tempo › Main · 2X2 · 117, Foil")
        field = html.at_css("input[name='lots[#{lot.id}]']")
        expect(field.attributes.slice("type", "min", "max", "value").transform_values(&:value)).to eq("type" => "number", "min" => "0", "max" => "2", "value" => "0")
        expect(html.at_css("input[name='shown[#{lot.id}]']")["value"]).to eq("2")
      end

      it "names each field by its lot's text: printing, finish, condition, price, place and the free count", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil", condition: "near_mint", price_paid_cents: 125)
        unplaced = lot_in(nil, printing(set: "mm3", number: "122", language: "de"), 1)

        get new_deck_proxy_replacement_path(deck, proxy)

        label = html.at_css("label[for='lot_#{lot.id}']").text.squish
        expect(label).to eq("2X2 · 117 Foil, Near mint, paid $1.25, Blue binder, ×2 free")
        expect(html.at_css("label[for='lot_#{unplaced.id}']").text.squish).to eq("MM3 · 122 · DE, No location, ×1 free")
        expect(html.at_css("label.c-input input[id='lot_#{lot.id}']")).to be_present
      end

      it "groups This printing (the proxy's printing and finish) before Other printings in the card page's order, leaving an empty group out", :aggregate_failures do
        same = lot_in(binder, entry, 1, finish: "foil")
        other_finish = lot_in(box, entry, 1, finish: "nonfoil")
        newer = lot_in(box, printing(set: "mm3", number: "122"), 1, finish: "foil")
        newer.entry.update_columns(released_on: Date.new(2030, 1, 1)) # `newest_first` sorts by the entry's own release date
        retired = lot_in(binder, create(:mtg_printing, entry: create(:catalog_entry, :retired, name: "Lightning Bolt", identity: bolt)).entry, 1)

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(html.css(".c-pick__group").map(&:text)).to eq([ "This printing", "Other printings" ])
        ids = html.css(".c-pick__lot input[type=number]").map { it["id"] }
        expect(ids.first).to eq("lot_#{same.id}")
        expect(ids.drop(1).first).to eq("lot_#{newer.id}") # newest printing first, whatever the finish
        expect(ids.drop(1)).to contain_exactly("lot_#{newer.id}", "lot_#{other_finish.id}", "lot_#{retired.id}")

        same.destroy!
        other_finish.destroy!
        get new_deck_proxy_replacement_path(deck, proxy)
        expect(html.css(".c-pick__group").map(&:text)).to eq([ "Other printings" ])
      end

      it "lists only free lots of the card: no lot in a zone, in Considering, of another card or of another account", :aggregate_failures do
        free = lot_in(binder, entry, 1, finish: "foil")
        lot_in(deck.zone("main"), entry, 1, finish: "foil")
        lot_in(deck.zone("considering"), entry, 1, finish: "foil")
        lot_in(binder, create(:mtg_printing, entry: create(:catalog_entry, name: "Other card")).entry, 1)
        stranger = create(:user).account
        create(:lot, account: stranger, entry:, location: create(:location, account: stranger), quantity: 1, finish: "foil")
        other_deck = create(:deck, account:, name: "Other deck")
        lot_in(other_deck.zone("main"), entry, 1, finish: "foil") # a zone of another deck of the account

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(html.css(".c-pick__lot input[type=number]").map { it["id"] }).to eq([ "lot_#{free.id}" ])
      end

      it "reads a place with the zone's name as the place's name and the proxy line as Deck › Zone (AC-2.5)", :aggregate_failures do
        lot = lot_in(create(:location, account:, name: "Main"), entry, 1, finish: "foil")

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(html.at_css("label[for='lot_#{lot.id}']").text.squish).to eq("2X2 · 117 Foil, Main, ×1 free")
        expect(html.at_css(".c-pagehead__stats").text.squish).to start_with("Replaces 2 proxies in Izzet Tempo › Main")
      end

      it "says '1 proxy' and keeps a 60-character place name whole", :aggregate_failures do
        one = proxy_of(printing(set: "one"), quantity: 1)
        lot_in(create(:location, account:, name: "P" * 60), one.entry, 1, finish: "foil")

        get new_deck_proxy_replacement_path(deck, one)

        expect(html.at_css(".c-pagehead__stats").text.squish).to start_with("Replaces 1 proxy in Izzet Tempo › Main")
        expect(html.at_css(".c-pick__label").text).to include("P" * 60)
      end

      it "shows the empty sentence, a Back button and no form when no copy is free (AC-2.6)", :aggregate_failures do
        lot_in(deck.zone("main"), entry, 1, finish: "foil") # owned, but in the deck: the fixture could produce a free lot

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(html.at_css(".c-empty").text.squish).to eq("You have no free copy of Lightning Bolt to use.")
        expect(html.at_css("main a.c-btn[href='#{deck_path(deck)}']").text).to eq("Back to Izzet Tempo")
        expect(html.css("main form")).to be_empty # the layout's sign-out form is outside main
      end

      it "runs the same number of statements for 1 lot and for 200 lots of 20 printings in 2 places (AC-2.7)", :aggregate_failures do
        lot_in(binder, printing(set: "mm3", number: "122"), 1, finish: "foil") # not the proxy's printing: its entry and set are in the request's query cache already
        get new_deck_proxy_replacement_path(deck, proxy) # warm what the counts would otherwise differ by
        few = count_queries { get new_deck_proxy_replacement_path(deck, proxy) }

        20.times do |n|
          other = printing(set: "s#{n}", number: "#{n + 200}")
          10.times { |m| lot_in(m.even? ? binder : box, other, 1 + m, finish: "foil", price_paid_cents: m) } # 10 identities a printing
        end
        many = count_queries { get new_deck_proxy_replacement_path(deck, proxy) }

        expect(account.lots.free.count).to eq(201)
        expect(many).to eq(few)
      end
    end

    describe "Use these copies (AC-3.1 to AC-3.13)" do
      def post_use(typed, shown = nil, to: proxy)
        shown ||= typed.keys.to_h { |id| [ id, account.lots.find(id).quantity.to_s ] }
        post deck_proxy_replacement_path(deck, to), params: { lots: typed, shown: }
      end

      it "moves the chosen copies into the zone, lowers the proxy and goes back to the deck page with the notice", :aggregate_failures do
        lot = lot_in(binder, entry, 3, finish: "foil", condition: "near_mint")
        original = proxy.updated_at

        post_use({ lot.id.to_s => "1" })

        expect(response).to redirect_to(deck_path(deck))
        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq("Replaced 1 proxy of Lightning Bolt (2X2 · 117, Foil) in Izzet Tempo › Main with copies you own.")
        expect(proxy.reload).to have_attributes(quantity: 1, id: proxy.id)
        expect(proxy.updated_at).to be > original
        expect(lot.reload).to have_attributes(quantity: 2, location: binder)
        expect(account.lots.find_by(location: deck.zone("main"))).to have_attributes(quantity: 1, finish: "foil", condition: "near_mint")
      end

      it "removes the proxy when the copies used equal its count, and the deck page then shows the owned row alone", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil")

        post_use({ lot.id.to_s => "2" })
        follow_redirect!

        expect(Deck::Proxy.exists?(proxy.id)).to be(false)
        main = html.css("section.c-zone").find { it.at_css("h2").text == "Main" }
        expect(main.css(".c-proxy")).to be_empty
        expect(html.at_css(".c-item__type").text).to eq("Modern · 2 cards · 2 owned · 0 proxy")
      end

      it "uses copies of another printing: it enters as a row of its own and the card's Total on the deck page is unchanged (AC-3.3)", :aggregate_failures do
        other = lot_in(box, printing(set: "mm3", number: "122"), 1, finish: "foil")

        post_use({ other.id.to_s => "1" })
        follow_redirect!

        expect(proxy.reload.quantity).to eq(1)
        expect(account.lots.find_by(location: deck.zone("main")).catalog_entry_id).to eq(other.catalog_entry_id)
        main = html.css("section.c-zone").find { it.at_css("h2").text == "Main" }
        rows = main.css("tbody tr:not(.c-zone__group)")
        expect(rows.size).to eq(2) # the proxy's printing keeps its row; the copy's printing has one of its own
        expect(html.at_css(".c-item__type").text).to eq("Modern · 2 cards · 1 owned · 1 proxy") # 2 cards before and after
      end

      it "judges a proxy lowered since the page was shown against its count now (AC-3.10)", :aggregate_failures do
        lot = lot_in(binder, entry, 5, finish: "foil")
        proxy.update!(quantity: 1) # lowered in another tab

        post_use({ lot.id.to_s => "2" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#replacement-error").text).to eq("Enter a number from 1 to 1.")
        expect(lot.reload.location).to eq(binder)
      end

      it "agrees across the deck page, the card page's Your copies, the collection and the Decks page after a replacement (AC-3.12)", :aggregate_failures do
        lot = lot_in(binder, entry, 3, finish: "foil")

        post_use({ lot.id.to_s => "2" })

        get deck_path(deck)
        expect(html.at_css(".c-item__type").text).to eq("Modern · 2 cards · 2 owned · 0 proxy")
        get catalog_entry_path(entry)
        expect(html.text).to include("Izzet Tempo › Main")
        get collection_path(view: "table")
        expect(html.text).to include("Izzet Tempo › Main").and include("Blue binder")
        get decks_path
        row = html.at_css("tbody tr")
        expect(row.text.squish).to include("2 owned") # the phone line; Owned was 0 before the replacement
        expect(row.at_css(".c-proxy")).to be_nil
      end

      it "shows the changed-lots sentence above the empty state when every chosen lot stopped being free", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil")
        lot.update!(location: deck.zone("sideboard")) # taken into a zone since the page was shown

        post_use({ lot.id.to_s => "1" }, { lot.id.to_s => "2" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#replacement-error").text).to eq("Those copies changed. Check the numbers and try again.")
        expect(html.at_css(".c-empty").text.squish).to eq("You have no free copy of Lightning Bolt to use.")
      end

      it "writes nothing and re-renders with every entry kept for a number outside the lot's copies (AC-3.5)", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil")

        post_use({ lot.id.to_s => "3" })

        expect(response).to have_http_status(:unprocessable_content)
        error = html.at_css("#lot_#{lot.id}-error")
        expect(error.text).to eq("Enter a number from 0 to 2.")
        expect(html.at_css("input#lot_#{lot.id}")["aria-describedby"]).to eq("lot_#{lot.id}-error")
        expect(html.at_css("input#lot_#{lot.id}")["value"]).to eq("3")
        expect([ lot.reload.location, proxy.reload.quantity ]).to eq([ binder, 2 ])
      end

      it "refuses a total of 0 or over the proxy's count under the fieldset (AC-3.6)", :aggregate_failures do
        lot = lot_in(binder, entry, 5, finish: "foil")

        post_use({ lot.id.to_s => "" })
        expect(html.at_css("#replacement-error").text).to eq("Enter a number from 1 to 2.")
        expect(html.at_css("fieldset")["aria-describedby"]).to eq("replacement-error")

        post_use({ lot.id.to_s => "3" })
        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#replacement-error").text).to eq("Enter a number from 1 to 2.")
        expect(account.lots.where(location: deck.zone("main"))).to be_empty
      end

      it "refuses a lot that changed since the page was shown, and the refused page works as the next submit (AC-3.9)", :aggregate_failures do
        lot = lot_in(binder, entry, 5, finish: "foil")

        post_use({ lot.id.to_s => "1" }, { lot.id.to_s => "9" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#replacement-error").text).to eq("Those copies changed. Check the numbers and try again.")
        expect(html.at_css("input[name='shown[#{lot.id}]']")["value"]).to eq("5")
        expect(html.at_css("input#lot_#{lot.id}")["value"]).to eq("1")
        expect(proxy.reload.quantity).to eq(2)

        post_use({ lot.id.to_s => "1" }, { lot.id.to_s => "5" }) # what the refused page posts again
        expect(response).to redirect_to(deck_path(deck))
        expect(proxy.reload.quantity).to eq(1)
      end

      it "moves once when the same form is submitted twice: the second is refused as changed (AC-3.11)", :aggregate_failures do
        lot = lot_in(binder, entry, 5, finish: "foil")
        params = { lots: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "5" } }

        post deck_proxy_replacement_path(deck, proxy), params: params
        post deck_proxy_replacement_path(deck, proxy), params: params

        expect(response).to have_http_status(:unprocessable_content)
        expect(proxy.reload.quantity).to eq(1)
        expect(lot.reload.quantity).to eq(4)
        expect(account.lots.find_by(location: deck.zone("main")).quantity).to eq(1)
      end

      it "writes nothing when a later lot passes the cap, the earlier lot included, and names the lot (AC-3.7, AC-3.8)", :aggregate_failures do
        lot_in(deck.zone("main"), entry, 9_999, finish: "foil")
        first = lot_in(binder, entry, 1, finish: "nonfoil")
        second = lot_in(box, entry, 1, finish: "foil")

        post_use({ first.id.to_s => "1", second.id.to_s => "1" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#lot_#{second.id}-error").text).to eq("One lot can hold at most 9,999 copies.")
        expect([ first.reload.location, second.reload.location, proxy.reload.quantity ]).to eq([ binder, box, 2 ])
      end

      it "ignores an account id, a zone id and a location id in the request (AC-3.13)", :aggregate_failures do
        lot = lot_in(binder, entry, 1, finish: "foil")

        post deck_proxy_replacement_path(deck, proxy), params: { lots: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "1" },
                                                                   account_id: create(:user).account.id, zone_id: deck.zone("sideboard").id, location_id: box.id }

        expect(response).to redirect_to(deck_path(deck))
        expect(lot.reload.location).to eq(deck.zone("main"))
      end

      it "answers 404 for a proxy removed meanwhile and writes nothing (AC-3.10)", :aggregate_failures do
        lot = lot_in(binder, entry, 1, finish: "foil")
        stale = proxy.id
        proxy.destroy!

        post deck_proxy_replacement_path(deck, stale), params: { lots: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "1" } }

        expect(response).to have_http_status(:not_found)
        expect(lot.reload.location).to eq(binder)
      end

      it "leaves the other proxies, other decks and the other account's lots as they were (AC-5.2)", :aggregate_failures do
        sibling = proxy_of(printing(set: "sib"), quantity: 2)
        stranger = create(:user).account
        theirs = create(:lot, account: stranger, entry:, location: create(:location, account: stranger), quantity: 4, finish: "foil")
        lot = lot_in(binder, entry, 1, finish: "foil")

        post_use({ lot.id.to_s => "1" })

        expect([ sibling.reload.quantity, theirs.reload.quantity ]).to eq([ 2, 4 ])
      end

      it "leaves the export consistent: the moved lots in the zone's place and the lowered proxy, no new field (AC-5.3)", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil")
        post_use({ lot.id.to_s => "1" })

        data = CollectionExport.new(account:, at: Time.current).to_h

        expect(data["proxies"].map { it.slice("quantity", "finish") }).to eq([ { "quantity" => 1, "finish" => "foil" } ])
        expect(data["lots"].filter_map { it["location"]["zone"] if it["location"].is_a?(Hash) }).to include("main")
        expect(data.keys).to match_array(CollectionExport.new(account: create(:user).account, at: Time.current).to_h.keys)
      end

      it "changes no proxy when a copy reaches the zone by any other path (AC-5.1, the spec 068 rule stands)", :aggregate_failures do
        place_lot = lot_in(binder, entry, 2, finish: "foil")
        Lot::Move.new(lot: place_lot, to: deck.zone("main"), copies: "1").call!

        expect(proxy.reload.quantity).to eq(2)
      end
    end

    describe "who can open it (AC-2.8, AC-2.9)" do
      it "answers 404 for a proxy whose printing's collectible the instance no longer registers", :aggregate_failures do
        entry.update_columns(collectible_type: "gone")

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  it "sends a visitor who isn't signed in to sign in" do
    get new_deck_proxy_replacement_path(deck, proxy)

    expect(response).to redirect_to(new_session_path)
  end
end
