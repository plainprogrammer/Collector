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
