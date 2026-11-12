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
