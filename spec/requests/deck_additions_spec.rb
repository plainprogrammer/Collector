require "rails_helper"

# Spec 071 Stories 2 to 5: the Add to deck page and what it writes.
RSpec.describe "Add to deck", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt"), finishes: %w[nonfoil foil]).entry }

  def html = Nokogiri::HTML5(response.body)
  def zone_path_options = html.css("select#deck_zone optgroup option")
  def radios = html.css("fieldset.c-pick input[type=radio]")

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the page (AC-2.1 to AC-2.4)" do
      before { deck }

      it "is a detail page for the card with the select, the count and the choice", :aggregate_failures do
        get new_catalog_entry_deck_addition_path(entry)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Add Lightning Bolt to a deck · Collector")
        expect(html.at_css("h1").text).to eq("Add Lightning Bolt to a deck")
        expect(html.at_css("header.c-appbar--detail")).to be_present
        expect(html.at_css("main.c-decks")).to be_present
        expect(html.at_css("form.c-form")["action"]).to eq(catalog_entry_deck_additions_path(entry))
        expect(html.css("a.c-btn--secondary").find { it.text == "Cancel" }["href"]).to eq(catalog_entry_path(entry))
        expect(html.at_css("a.c-appbar__back")["href"]).to eq(catalog_entry_path(entry))
        expect(html.at_css("input[type=submit]")["value"]).to eq("Add to deck")
      end

      it "carries the collection mark on the form, Cancel and the back link", :aggregate_failures do
        get new_catalog_entry_deck_addition_path(entry, from: "collection")

        expect(html.at_css("form.c-form")["action"]).to eq(catalog_entry_deck_additions_path(entry, from: "collection"))
        expect(html.css("a.c-btn--secondary").find { it.text == "Cancel" }["href"]).to eq(catalog_entry_path(entry, from: "collection"))
        expect(html.at_css("a.c-appbar__back")["href"]).to eq(catalog_entry_path(entry, from: "collection"))
      end

      it "lists every zone of the account's decks under one Decks group, no Places and no No location (AC-2.2)", :aggregate_failures do
        create(:location, account:, name: "Blue binder")
        get new_catalog_entry_deck_addition_path(entry)

        select = html.at_css("select#deck_zone")
        expect(select["required"]).to be_present
        expect(select.css("option").first.text).to eq("Choose a deck and zone…")
        expect(select.css("option").first["value"]).to eq("")
        expect(select.css("optgroup").map { it["label"] }).to eq([ "Decks" ])
        expect(zone_path_options.map(&:text)).to eq(deck.zones.map { "Izzet Tempo › #{it.name}" })
        expect(zone_path_options.map { it["value"] }).to eq(deck.zones.map { it.id.to_s })
        expect(select.text).not_to include("Blue binder")
      end

      it "has a labelled How many field with 1 in it, a minimum of 1 and no maximum (AC-2.4)", :aggregate_failures do
        get new_catalog_entry_deck_addition_path(entry)

        field = html.at_css("input#how_many")
        expect(html.at_css("label[for=how_many]").text).to eq("How many")
        expect(field.attributes.slice("type", "name", "min", "step", "value").transform_values(&:value))
          .to include("type" => "number", "name" => "quantity", "min" => "1", "step" => "1", "value" => "1")
        expect(field["required"]).to be_present
        expect(field["max"]).to be_nil
      end
    end

    describe "What to use (AC-2.5 to AC-2.8)" do
      before { deck }

      it "offers My copies with the free sentence first, then a proxy per finish, nothing chosen, all required", :aggregate_failures do
        blue = create(:location, account:, name: "Blue binder")
        create(:lot, account:, entry:, quantity: 2, location: blue)
        create(:lot, account:, entry:, quantity: 1)
        get new_catalog_entry_deck_addition_path(entry)

        labels = html.css("fieldset.c-pick label.c-check").map { it.text.squish }
        expect(html.at_css("fieldset.c-pick legend").text).to eq("What to use")
        expect(labels).to eq([ "My copies (3 free: 1 with no location, 2 in Blue binder)", "A proxy of #{ApplicationController.helpers.set_number(entry)} Nonfoil",
                               "A proxy of #{ApplicationController.helpers.set_number(entry)} Foil" ])
        expect(radios.map { it["value"] }).to eq(%w[copies proxy:nonfoil proxy:foil])
        expect(radios.map { it["checked"] }).to all(be_nil)
        expect(radios.map { it["required"] }).to all(be_present)
        expect(html.css("fieldset.c-pick .is-data").map(&:text)).to eq([ ApplicationController.helpers.set_number(entry) ] * 2)
      end

      it "doesn't count or name copies in a deck zone, a proxy, another account's copies or another card's (AC-2.6, AC-2.8)", :aggregate_failures do
        create_lot_in_zone(deck, "main", entry:, quantity: 3)
        create(:deck_proxy, zone: deck.zone("main"), account:, entry:, quantity: 2)
        create(:lot, entry:, quantity: 7) # another account's
        create(:lot, account:, entry: create(:mtg_printing).entry, quantity: 5)
        get new_catalog_entry_deck_addition_path(entry)

        expect(radios.map { it["value"] }).to eq(%w[proxy:nonfoil proxy:foil])
        expect(html.text).not_to include("free:")
      end

      it "shows the owner's own copies, as the positive control of the example above (AC-2.8)", :aggregate_failures do
        create(:lot, account:, entry:, quantity: 3)
        get new_catalog_entry_deck_addition_path(entry)

        expect(radios.first["value"]).to eq("copies")
        expect(html.text).to include("3 free: 3 with no location")
      end

      it "offers two radios and chooses neither when copies are free and the printing has one finish, or two finishes and none free (AC-2.7)", :aggregate_failures do
        one = create(:mtg_printing, entry: create(:catalog_entry), finishes: %w[foil]).entry
        create(:lot, account:, entry: one)
        get new_catalog_entry_deck_addition_path(one)
        expect(radios.map { it["value"] }).to eq(%w[copies proxy:foil])
        expect(radios.map { it["checked"] }).to all(be_nil)

        get new_catalog_entry_deck_addition_path(entry) # two finishes, none free
        expect(radios.map { it["value"] }).to eq(%w[proxy:nonfoil proxy:foil])
        expect(radios.map { it["checked"] }).to all(be_nil)
      end

      it "chooses the only option when one is left (spec 060 decision 14)", :aggregate_failures do
        one = create(:mtg_printing, entry: create(:catalog_entry), finishes: %w[foil]).entry
        get new_catalog_entry_deck_addition_path(one)
        expect(radios.map { it["value"] }).to eq(%w[proxy:foil])
        expect(radios.first["checked"]).to be_present

        none = create(:mtg_printing, entry: create(:catalog_entry), finishes: []).entry
        get new_catalog_entry_deck_addition_path(none)
        expect(radios.map { it["value"] }).to eq(%w[proxy])
        expect(html.at_css("fieldset.c-pick label.c-check").text.squish).to eq("A proxy of #{ApplicationController.helpers.set_number(none)}")
      end
    end

    it "says there are no decks and links New deck, with no form (AC-2.3)", :aggregate_failures, :other_collecting do
      create(:deck, account:, pair: "other/standard")
      get new_catalog_entry_deck_addition_path(entry)

      expect(response).to have_http_status(:ok)
      expect(html.at_css("h1").text).to eq("Add Lightning Bolt to a deck")
      expect(html.at_css("p.c-empty").text.squish).to eq("You have no decks yet. Add a deck first. New deck")
      expect(html.at_css("p.c-empty a")["href"]).to eq(new_deck_path)
      expect(html.at_css("form.c-form")).to be_nil
    end

    it "offers no zone of a deck of another collectible type (AC-2.3)", :aggregate_failures, :other_collecting do
      deck
      create(:deck, account:, name: "Elsewhere", pair: "other/standard")
      get new_catalog_entry_deck_addition_path(entry)

      expect(zone_path_options.map(&:text).join).not_to include("Elsewhere")
      expect(zone_path_options.map(&:text).join).to include("Izzet Tempo")
    end

    it "is 404, on the page and on the create, for a retired printing, a token, a type with a vocabulary and no source, an unregistered type and an unknown key (AC-1.3)", :aggregate_failures, :other_collecting do
      zone_id = deck.zone("main").id
      bad = [ create(:catalog_entry, :retired), create(:catalog_entry, kind: "token"), create(:catalog_entry, collectible_type: "other"),
              create(:catalog_entry, collectible_type: "unregistered") ].map(&:external_key) + [ "no-such-key" ]

      bad.each do |key|
        get "/catalog/entries/#{key}/deck_additions/new"
        expect(response).to have_http_status(:not_found), key
        post "/catalog/entries/#{key}/deck_additions", params: { zone_id:, use: "proxy:foil", quantity: "1" }
        expect(response).to have_http_status(:not_found), key
      end
      expect(Deck::Proxy.count).to eq(0)
    end

    it "runs the same number of statements for one lot and deck as for forty lots and ten decks (AC-2.9)" do
      deck
      create(:lot, account:, entry:, location: create(:location, account:)) # placed, so the small page also loads a place
      get new_catalog_entry_deck_addition_path(entry) # warm-up
      small = count_queries { get new_catalog_entry_deck_addition_path(entry) }
      9.times { |n| create(:deck, account:, name: "Deck #{n}") }
      40.times { |n| create(:lot, account:, entry:, finish: n.even? ? "foil" : nil, price_paid_cents: n, location: create(:location, account:)) }

      expect(count_queries { get new_catalog_entry_deck_addition_path(entry) }).to eq(small)
    end

    describe "My copies (AC-3.1 to AC-3.3, AC-3.6)" do
      def blue = @blue ||= create(:location, account:, name: "Blue binder") # methods, not lets: RSpec/MultipleMemoizedHelpers allows five
      def zone = deck.zone("main")

      def add(use:, quantity: "1", zone_id: zone.id, **extra) = post(catalog_entry_deck_additions_path(entry, **extra), params: { zone_id:, use:, quantity: })

      it "moves the copies, 303s to the card page and says so (AC-3.1)", :aggregate_failures do
        stay = create(:lot, account:, entry:, quantity: 2, location: blue)
        add(use: "copies", quantity: "1")

        expect(response).to redirect_to(catalog_entry_path(entry))
        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq("Moved 1 copy of Lightning Bolt to Izzet Tempo › Main.")
        expect(stay.reload.quantity).to eq(1)
        expect(account.lots.find_by(location: zone).quantity).to eq(1)
      end

      it "keeps the collection mark on the redirect" do
        create(:lot, account:, entry:)
        add(use: "copies", from: "collection")

        expect(response).to redirect_to(catalog_entry_path(entry, from: "collection"))
      end

      it "answers 404 and moves nothing when the zone was removed after the page opened (AC-3.12)", :aggregate_failures do
        lot = create(:lot, account:, entry:, quantity: 1, location: blue)
        gone = zone.id
        account.locations.where(id: gone).delete_all # removed in another tab (the zone held nothing)
        add(use: "copies", zone_id: gone)

        expect(response).to have_http_status(:not_found)
        expect(lot.reload.location).to eq(blue)
      end

      it "offers only the proxy once nothing is free any more, chosen, after the refusal (decision 11)", :aggregate_failures do
        one = create(:mtg_printing, entry: create(:catalog_entry, name: "Island"), finishes: %w[nonfoil]).entry
        post catalog_entry_deck_additions_path(one), params: { zone_id: zone.id, use: "copies", quantity: "1" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#deck_addition_use-error").text).to eq("You have no free copy of Island to use.")
        expect(radios.map { it["value"] }).to eq(%w[proxy:nonfoil])
        expect(radios.first["checked"]).to be_present
      end

      it "says copies for more than one, and shows them as Deck › Zone in Your copies (AC-3.2, AC-3.6)", :aggregate_failures do
        create(:lot, account:, entry:, quantity: 2, location: blue)
        create(:lot, account:, entry:, quantity: 1, finish: "foil")
        add(use: "copies", quantity: "3", zone_id: deck.zone("considering").id)
        expect(flash[:notice]).to eq("Moved 3 copies of Lightning Bolt to Izzet Tempo › Considering.")

        get catalog_entry_path(entry)
        expect(html.at_css("#copies").text).to include("Izzet Tempo › Considering")
        expect(html.at_css(".c-stat dd").text).to eq("3") # Owned is unchanged
      end

      it "refuses a count over the free copies with 422, the typed values kept and nothing moved (AC-3.3)", :aggregate_failures do
        lot = create(:lot, account:, entry:, quantity: 3, location: blue)
        add(use: "copies", quantity: "4")

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#deck_addition_quantity-error").text).to eq("Enter a number from 1 to 3.")
        expect(html.at_css("input#how_many")["value"]).to eq("4")
        expect(html.at_css("select#deck_zone option[selected]")["value"]).to eq(zone.id.to_s)
        expect(html.at_css("input[value=copies]")["checked"]).to be_present
        expect(lot.reload.location).to eq(blue)
      end

      it "refuses the cap with the lot named above the actions (AC-3.5)", :aggregate_failures do
        create(:lot, account:, entry:, quantity: 9_995, finish: "foil", location: zone)
        create(:lot, account:, entry:, quantity: 10, finish: "foil", location: blue)
        add(use: "copies", quantity: "10")

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#deck_addition_base-error").text).to eq("Nothing changed. Lightning Bolt (#{ApplicationController.helpers.set_number(entry)}) would have more than 9,999 copies in one lot.")
        expect(account.lots.find_by(location: blue).quantity).to eq(10)
      end

      it "doesn't make the double submit lose or create copies (AC-3.9)", :aggregate_failures do
        create(:lot, account:, entry:, quantity: 2, location: blue)
        2.times { add(use: "copies", quantity: "2") }

        expect(response).to have_http_status(:unprocessable_content) # the second finds nothing free
        expect(account.lots.sum(:quantity)).to eq(2)
        expect(account.lots.where(location: zone).sum(:quantity)).to eq(2)
      end
    end

    describe "a proxy (AC-4.1, AC-4.5)" do
      it "adds the proxy, says so and shows it on the deck page, owned copies unchanged", :aggregate_failures do
        zone = deck.zone("main")
        post catalog_entry_deck_additions_path(entry), params: { zone_id: zone.id, use: "proxy:foil", quantity: "2" }

        expect(response).to redirect_to(catalog_entry_path(entry))
        expect(flash[:notice]).to eq("Added 2 proxies of Lightning Bolt (#{ApplicationController.helpers.set_number(entry)}, Foil) to Izzet Tempo › Main.")
        expect(account.lots.count).to eq(0)

        get deck_path(deck)
        expect(html.css("section.c-zone").first.text).to include("Lightning Bolt")
        expect(html.css(".c-proxy").first.text.squish).to eq("Proxy 2")
      end

      it "says 1 proxy in the singular, and the finish only when there is one", :aggregate_failures do
        none = create(:mtg_printing, entry: create(:catalog_entry, name: "Island"), finishes: []).entry
        post catalog_entry_deck_additions_path(none), params: { zone_id: deck.zone("main").id, use: "proxy", quantity: "1" }

        expect(flash[:notice]).to eq("Added 1 proxy of Island (#{ApplicationController.helpers.set_number(none)}) to Izzet Tempo › Main.")
      end
    end

    describe "a proxy's refusals (AC-4.3, AC-4.4)" do
      it "answers 422 for an unlisted finish, a bare proxy and a finish on a printing that lists none, on the choice", :aggregate_failures do
        none = create(:mtg_printing, entry: create(:catalog_entry, name: "Island"), finishes: []).entry
        zone_id = deck.zone("main").id
        { [ entry, "proxy:etched" ] => "That finish isn't available for this printing.", [ entry, "proxy" ] => "Choose a finish.",
          [ none, "proxy:foil" ] => "That finish isn't available for this printing." }.each do |(printing, use), sentence|
          post catalog_entry_deck_additions_path(printing), params: { zone_id:, use:, quantity: "1" }
          expect(response).to have_http_status(:unprocessable_content), use
          expect(html.at_css("#deck_addition_use-error").text).to eq(sentence), use
        end
        expect(Deck::Proxy.count).to eq(0)
      end

      it "answers 422 for a quantity that isn't 1 to 9,999 and keeps what was typed (AC-4.4)", :aggregate_failures do
        post catalog_entry_deck_additions_path(entry), params: { zone_id: deck.zone("main").id, use: "proxy:foil", quantity: "10000" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#deck_addition_quantity-error").text).to eq("Enter a number from 1 to 9,999.")
        expect(html.at_css("input#how_many")["value"]).to eq("10000")
        expect(html.at_css("input[value='proxy:foil']")["checked"]).to be_present
      end

      it "leaves the card page's Owned as it was (AC-4.5)" do
        create(:lot, account:, entry:, quantity: 3)
        post catalog_entry_deck_additions_path(entry), params: { zone_id: deck.zone("main").id, use: "proxy:foil", quantity: "2" }

        get catalog_entry_path(entry)
        expect(html.at_css(".c-stat dd").text).to eq("3")
      end
    end

    describe "refusals and tenancy (AC-5.1 to AC-5.3)" do
      before { deck } # a 422 needs the form: with no deck the page draws the empty state instead

      it "answers 422 with a sentence on the field for no zone, no choice or no recognised choice", :aggregate_failures do
        post catalog_entry_deck_additions_path(entry), params: { zone_id: "", quantity: "1" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#deck_addition_zone-error").text).to eq("Choose a deck and zone.")
        expect(html.at_css("#deck_addition_use-error").text).to eq("Choose what to use.")
        expect(html.at_css("input#how_many")["value"]).to eq("1") # what was typed is kept
        expect(Deck::Proxy.count).to eq(0)
      end

      it "ties each sentence to its field, with no inline style and one primary action (AC-6.5)", :aggregate_failures do
        post catalog_entry_deck_additions_path(entry), params: { zone_id: "", quantity: "1" }
        expect(html.at_css("select#deck_zone")["aria-describedby"]).to eq("deck_addition_zone-error")
        expect(html.at_css("fieldset.c-pick")["aria-describedby"]).to eq("deck_addition_use-error")

        post catalog_entry_deck_additions_path(entry), params: { zone_id: deck.zone("main").id, quantity: "0", use: "proxy:foil" }
        expect(html.at_css("input#how_many")["aria-describedby"]).to eq("deck_addition_quantity-error")
        expect(html.at_css("main [style]")).to be_nil
        expect(html.css("main .c-btn--primary, main input.c-btn--primary").size).to eq(1)
        get new_catalog_entry_deck_addition_path(entry) # a page with no error has no empty aria-describedby
        expect(html.css("[aria-describedby='']")).to be_empty
      end

      it "answers 404 for another account's zone, a place, a deck's own row, a missing zone and a bad id, writing nothing and leaking nothing", :aggregate_failures do
        rival = "Rival #{SecureRandom.hex(4)}" # built at run time: the test 404 page prints the spec's source
        theirs = create(:deck, name: rival)
        place = create(:location, account:)
        own = create(:deck, account:, name: "Own #{SecureRandom.hex(4)}")
        [ theirs.zone("main").id, place.id, own.location_id, 0, "abc" ].each do |bad|
          post catalog_entry_deck_additions_path(entry), params: { zone_id: bad, use: "proxy:foil", quantity: "1" }
          expect(response).to have_http_status(:not_found), bad.to_s
          expect(response.body).not_to include(rival)
        end
        expect(Deck::Proxy.count).to eq(0)

        get new_catalog_entry_deck_addition_path(entry) # the owner's own request shows the owner's deck (positive control)
        expect(html.at_css("select#deck_zone").text).to include(own.name)
      end

      it "ignores an account, user, location, kind or lot in the request (AC-5.3)", :aggregate_failures do
        other = create(:user).account
        lot = create(:lot, account:, entry:, quantity: 1)
        post catalog_entry_deck_additions_path(entry), params: { zone_id: deck.zone("main").id, use: "proxy:foil", quantity: "1",
                                                                  account_id: other.id, user_id: other.id, location_id: 0, kind: "place", lot_id: lot.id }

        expect(Deck::Proxy.sole.account_id).to eq(account.id)
        expect(lot.reload.location_id).to be_nil
      end
    end
  end

  context "when signed out (AC-1.2, AC-5.4)" do
    it "sends the page and the create to sign in, writing nothing", :aggregate_failures do
      user # an account exists, or the first-run page answers instead of sign in
      get new_catalog_entry_deck_addition_path(entry)
      expect(response).to redirect_to(new_session_path)

      post catalog_entry_deck_additions_path(entry), params: { zone_id: deck.zone("main").id, use: "proxy:foil", quantity: "1" }
      expect(response).to redirect_to(new_session_path)
      expect(Deck::Proxy.count).to eq(0)
    end
  end
end
