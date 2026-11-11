require "rails_helper"

# Spec 062 Stories 1, 2 and 4: the Decks page, the New deck page and the Rename page, with tenancy.
RSpec.describe "Decks", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }

  def html = Nokogiri::HTML5(response.body)
  def stats = html.at_css(".c-pagehead__stats")&.text.to_s.squish
  def rows = html.css(".c-decks tbody tr")
  def deck_names = rows.map { it.at_css("td:first-child .c-table__item > div > span:first-child").text }

  describe "GET /decks (Story 4)" do
    context "when signed in" do
      before { sign_in_as(user) }

      it "reads the head as a count of decks and cards and lists them in comparison-key order (AC-4.3)", :aggregate_failures do
        create(:deck, account:, name: "tempo").tap { create_lot_in_zone(it, "main", quantity: 4) }
        create(:deck, account:, name: "Beatdown", format: "commander").tap { create_lot_in_zone(it, "commander", quantity: 1) }
        create(:deck, account:, name: "Krenko", format: "pauper").tap do
          create_lot_in_zone(it, "main", quantity: 2)
          create_lot_in_zone(it, "considering", quantity: 3)
        end

        get decks_path

        expect(response).to have_http_status(:ok)
        expect(html.at_css("h1").text).to eq("Decks")
        expect(stats).to eq("3 decks · 10 cards")
        expect(html.css(".c-decks thead th").map { it.text.squish }).to eq([ "Deck", "Format", "Cards", "Owned", "Actions" ])
        expect(deck_names).to eq(%w[Beatdown Krenko tempo])
        expect(html.css(".c-decks tbody td:first-child .c-table__item > div > span:first-child a").map { it["href"] }).to eq(account.decks.listing_order.map { deck_path(it) }) # spec 066 AC-1.5: each name links to its page
        expect(html.at_css(".c-decks").text).not_to include("Proxy")
        expect(html.at_css(".c-pagehead__actions a.c-btn--primary[href='#{new_deck_path}']").text.squish).to eq("New deck")
      end

      it "says '1 deck' for one (AC-4.3)" do
        create(:deck, account:)

        get decks_path

        expect(stats).to eq("1 deck · 0 cards")
      end

      it "shows the format's name, the cards of every zone and 0 for a deck with no copies (AC-4.4)", :aggregate_failures do
        modern = create(:deck, account:, name: "Izzet Tempo")
        create_lot_in_zone(modern, "main", quantity: 5)
        create_lot_in_zone(modern, "sideboard", quantity: 2)
        create_lot_in_zone(modern, "considering", quantity: 1)
        empty = create(:deck, account:, name: "New brew", format: "casual")
        retired = create(:deck, account:, name: "Old")
        retired.update!(format: "retired")

        get decks_path

        row = ->(deck) { html.css(".c-decks tbody tr").find { it.text.include?(deck.name) } }
        expect(row.(modern).css("td").drop(1).first(3).map { it.text.squish }).to eq([ "Modern", "8", "8" ])
        expect(row.(modern).at_css(".c-table__sub").text).to eq("Modern · 8 owned")
        expect(row.(empty).css("td").drop(1).first(3).map { it.text.squish }).to eq([ "Casual", "0", "0" ])
        expect(row.(empty).at_css(".c-table__sub").text).to eq("Casual · 0 owned")
        expect(row.(retired).css("td")[1].text).to eq("retired")
      end

      it "gives each row Rename and Remove links that name the deck for a screen reader (AC-4.4)", :aggregate_failures do
        deck = create(:deck, account:, name: "Izzet Tempo")

        get decks_path

        rename = html.at_css(".c-decks tbody a[href='#{edit_deck_path(deck)}']")
        remove = html.at_css(".c-decks tbody a[href='#{new_deck_removal_path(deck)}']")
        expect(rename.text).to eq("Rename Izzet Tempo")
        expect(rename.at_css("span.c-sr").text).to eq(" Izzet Tempo")
        expect(remove.text).to eq("Remove Izzet Tempo")
        expect([ rename["class"], remove["class"] ]).to all(eq("c-btn c-btn--ghost c-btn--sm"))
      end

      it "links each deck's name to its page and keeps the row's three buttons and narrow line (spec 066 AC-1.5)", :aggregate_failures do
        deck = create(:deck, account:, name: "Izzet Tempo")

        get decks_path

        link = html.at_css(".c-decks tbody td:first-child a")
        expect([ link.text, link["href"] ]).to eq([ "Izzet Tempo", deck_path(deck) ])
        expect(html.css(".c-decks tbody .c-decks__actions a").size).to eq(3)
        expect(html.at_css(".c-decks .c-table__sub").text).to eq("Modern · 0 owned")
      end

      it "shows the empty sentence in place of the table and keeps New deck (AC-4.6)", :aggregate_failures do
        get decks_path

        expect(html.at_css(".c-empty").text).to eq("No decks yet. Add a deck to start building one.")
        expect(html.css(".c-decks table")).to be_empty
        expect(stats).to eq("0 decks · 0 cards")
        expect(html.at_css(".c-pagehead__actions a[href='#{new_deck_path}']")).to be_present
      end

      it "lists the signed-in account's decks only, and no place (AC-4.8, AC-9.7)", :aggregate_failures do
        create(:deck, account:, name: "Mine")
        create(:location, account:, name: "Blue binder")
        create(:deck, name: "Theirs")

        get decks_path

        expect(deck_names).to eq([ "Mine" ])
      end

      it "costs the same number of queries with 2 decks as with 10, lots and all (AC-4.7)" do
        2.times { |index| create(:deck, account:, name: "Deck #{index}").tap { create_lot_in_zone(it, "main", quantity: 2) } }
        get decks_path # warm: the first request loads schema and the format registrations
        few = count_queries { get decks_path }

        8.times { |index| create(:deck, account:, name: "More #{index}").tap { create_lot_in_zone(it, "sideboard", quantity: 3) } }
        many = count_queries { get decks_path }

        expect(many).to eq(few)
      end

      it "marks Decks current in the header and the tab bar, in the order of AC-4.1", :aggregate_failures do
        get decks_path

        nav = html.css(".c-appbar__nav a")
        tabs = html.css(".c-tabbar a")
        expect(nav.map { it.text.squish }).to eq(%w[Collection Decks Search Scan Locations])
        expect(nav.select { it["aria-current"] }.map(&:text)).to eq([ "Decks" ])
        expect(tabs.map { it.text.squish }).to eq(%w[Collection Decks Search Scan More])
        expect(tabs.select { it["aria-current"] }.map { it.text.squish }).to eq([ "Decks" ])
        expect(tabs[1]["href"]).to eq(decks_path)
        expect(tabs[1].at_css("svg rect[width='12']")).to be_present
      end

      it "keeps More's rows and gives Decks no row there (AC-4.10)", :aggregate_failures do
        get more_path

        links = html.css(".c-more a").map { it.text.squish }
        expect(links).to include("Locations", "Currency", "Export collection", "Import collection", "Add by number")
        expect(links).not_to include("Decks")
        expect(html.css(".c-tabbar a").map { it.text.squish }).to eq(%w[Collection Decks Search Scan More])
      end
    end

    context "when signed out (AC-4.9)" do
      before { user } # an instance with no user sends everyone to the first-run page

      it "sends a visitor to sign in", :aggregate_failures do
        get decks_path

        expect(response).to redirect_to(new_session_path)
      end

      it "gives an open-catalog visitor's header no Decks link", :aggregate_failures, :public_catalog do
        get catalog_entries_path

        expect(html.css(".c-appbar__nav a").map { it.text.squish }).to eq([ "Search" ])
        expect(html.css("a[href='#{decks_path}']")).to be_empty
      end
    end
  end

  describe "GET /decks/new and POST /decks (Story 1)" do
    def name_error = html.at_css("#deck_name-error")&.text
    def format_error = html.at_css("#deck_format-error")&.text
    def taken_names = [ create(:location, account:, name: "Blue binder"), create(:deck, account:, name: "Krenko", format: "commander") ]
    def create_deck(name: "Izzet Tempo", format: "mtg/modern", **extra) = post(decks_path, params: { deck: { name:, format: }.merge(extra) })

    context "when signed in" do
      before { sign_in_as(user) }

      it "shows Name, Format with the default selected, the hint and the actions under a detail header (AC-1.1)", :aggregate_failures do
        get new_deck_path

        expect(response).to have_http_status(:ok)
        expect(html.at_css("h1").text).to eq("New deck")
        expect(html.at_css("header.c-appbar.c-appbar--detail .c-appbar__back")["href"]).to eq(decks_path)
        expect(html.at_css("form[action='#{decks_path}'][method=post] input[name='deck[name]']")).to be_present
        select = html.at_css("form select[name='deck[format]']")
        expect(select.css("option").map(&:text)).to eq(%w[Casual Standard Pioneer Modern Legacy Vintage Pauper Commander])
        expect(select.at_css("option[selected]").text).to eq("Casual")
        expect(select.css("option").map { it["value"] }.first(2)).to eq(%w[mtg/casual mtg/standard])
        expect(select.css("optgroup")).to be_empty
        expect(html.at_css(".c-field__hint").text).to eq("The format sets the deck's zones.")
        expect(html.at_css("form input[type=submit]")["value"]).to eq("Create deck")
        expect(html.at_css(".c-form__actions a.c-btn--secondary[href='#{decks_path}']").text).to eq("Cancel")
        expect(html.css(".c-appbar__nav a[aria-current=page]").map(&:text)).to eq([ "Decks" ])
        expect(html.at_css("main").text).not_to match(/magic|mtg|scryfall/i)
      end

      it "groups the formats under each collectible's category name when two are registered (AC-1.2)", :aggregate_failures, :other_collecting do
        get new_deck_path

        groups = html.css("select[name='deck[format]'] optgroup")
        expect(groups.map { it["label"] }).to eq([ "Magic: The Gathering", "Other cards" ])
        expect(groups.last.css("option").map { [ it.text, it["value"] ] }).to eq([ [ "Standard", "other/standard" ] ])
        expect(html.css("select[name='deck[format]'] option[selected]").map(&:text)).to eq([ "Casual" ])
      end

      it "creates the deck and its zones for the signed-in account, then answers 303 with the notice (AC-1.3)", :aggregate_failures do
        create_deck

        expect(response).to have_http_status(:see_other).and redirect_to(decks_path)
        follow_redirect!
        expect(html.at_css("#status").text.squish).to eq("Added “Izzet Tempo”.")
        deck = account.decks.sole
        expect(deck).to have_attributes(collectible_type: "mtg", format: "modern")
        expect(deck.zones.map(&:zone)).to eq(%w[main sideboard considering])
        expect(Deck.where.not(account:)).to be_empty
        expect(stats).to eq("1 deck · 0 cards")
      end

      it "answers 422 with the reason beside the Name field and the typed name and format kept (AC-1.7)", :aggregate_failures do
        taken_names
        {
          "   " => Location::MESSAGES[:blank], ("a" * 61) => Location::MESSAGES[:too_long], "a\u200Bb" => Location::MESSAGES[:control],
          "  blue   BINDER " => "You already have a location called “blue BINDER”.", "krenko" => "You already have a location called “krenko”."
        }.each do |typed, message|
          create_deck(name: typed, format: "mtg/pauper")

          expect(response).to have_http_status(:unprocessable_content)
          expect(html.css(".field_with_errors")).to be_empty
          expect(name_error).to eq(message)
          expect(html.at_css("#deck_name")["value"]).to eq(typed)
          expect(html.at_css("#deck_name")["aria-describedby"]).to eq("deck_name-error")
          expect(html.at_css("#deck_name").ancestors(".c-field").first["class"]).to include("c-field--invalid")
          expect(html.at_css("select option[selected]").text).to eq("Pauper")
        end
        expect(account.decks.count).to eq(1)
      end

      it "says decks count toward the limit of 500 (AC-1.7a)", :aggregate_failures do
        Location.insert_all!(Array.new(500) { |index| { account_id: account.id, name: "Place #{index}", name_key: "place #{index}" } })

        create_deck

        expect(response).to have_http_status(:unprocessable_content)
        expect(name_error).to eq("You can have at most 500 places and decks together.")
        expect(account.decks.count).to eq(0)
      end

      it "refuses a format that is not a registered type and key pair on the Format field and writes nothing (AC-1.8)", :aggregate_failures do
        [ "", "modern", "mtg/", "mtg/nonesuch", "nonesuch/modern", "other/standard" ].each do |value|
          expect { create_deck(format: value) }.not_to change(Location, :count)

          expect(response).to have_http_status(:unprocessable_content), value
          expect(format_error).to eq("Choose a format."), value
          expect(html.at_css("#deck_format")["aria-describedby"]).to eq("deck_format-error")
          expect(html.at_css("#deck_name")["value"]).to eq("Izzet Tempo")
        end
        expect { post decks_path, params: { other: "x" } }.not_to change(Location, :count)
        expect(response).to have_http_status(:bad_request)
      end

      it "ignores an account, a kind, a parent, a zone and a collectible type in the parameters (AC-1.10)", :aggregate_failures do
        other = create(:user).account
        host = create(:deck, account:, name: "Host")

        create_deck(account_id: other.id, kind: "place", parent_id: host.location_id, zone: "main", collectible_type: "other")

        expect(response).to have_http_status(:see_other)
        deck = account.decks.find_by!(location: account.locations.find_by!(name: "Izzet Tempo"))
        expect(deck).to have_attributes(collectible_type: "mtg", account_id: account.id)
        expect(deck.location).to have_attributes(kind: "deck", parent_id: nil, zone: nil, account_id: account.id)
        expect(other.decks.count).to eq(0)
      end
    end

    it "sends a signed-out visitor to sign in", :aggregate_failures do
      user
      get new_deck_path
      expect(response).to redirect_to(new_session_path)
      expect { create_deck }.not_to change(Deck, :count)
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET /decks/:id/edit and PATCH /decks/:id (Story 2)" do
    let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }

    def name_error = html.at_css("#location_name-error")&.text
    def rename(name, to: deck) = patch(deck_path(to), params: { location: { name: } })

    context "when signed in" do
      before { sign_in_as(user) }

      it "shows the Name field with the current name, Save and Cancel, under Decks (AC-2.1)", :aggregate_failures do
        get edit_deck_path(deck)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("h1").text).to eq("Rename deck")
        expect(html.at_css(".c-pagehead__stats").text).to eq("Izzet Tempo")
        expect(html.at_css("form[action='#{deck_path(deck)}'] input[name=_method]")["value"]).to eq("patch")
        expect(html.at_css("input[name='location[name]']")["value"]).to eq("Izzet Tempo")
        expect(html.at_css("form input[type=submit]")["value"]).to eq("Save")
        expect(html.at_css(".c-form__actions a.c-btn--secondary[href='#{decks_path}']").text).to eq("Cancel")
        expect(html.css(".c-appbar__nav a[aria-current=page]").map(&:text)).to eq([ "Decks" ])
        expect(html.at_css("header.c-appbar--detail .c-appbar__back")["href"]).to eq(decks_path)
      end

      it "renames, answers 303 with the notice and leaves the zones, the format and the lots alone (AC-2.2, AC-2.5)", :aggregate_failures do
        lot = create_lot_in_zone(deck, "main", quantity: 3)
        before = [ deck.zones.pluck(:id, :zone, :name), lot.attributes.slice("id", "lot_key", "quantity") ]

        rename("Spirits")

        expect(response).to have_http_status(:see_other).and redirect_to(decks_path)
        follow_redirect!
        expect(html.at_css("#status").text.squish).to eq("Renamed “Izzet Tempo” to “Spirits”.")
        expect(deck.reload).to have_attributes(name: "Spirits", format: "modern", collectible_type: "mtg")
        expect([ deck.zones.pluck(:id, :zone, :name), lot.reload.attributes.slice("id", "lot_key", "quantity") ]).to eq(before)
        expect(lot.place_label).to eq("Spirits › Main")
      end

      it "allows a change of case alone and refuses another place's or deck's name in any case (AC-2.3)", :aggregate_failures do
        create(:location, account:, name: "Blue binder")
        create(:deck, account:, name: "Krenko")

        rename("izzet tempo")
        expect(response).to have_http_status(:see_other)
        expect(deck.reload.name).to eq("izzet tempo")

        [ "BLUE binder", "krenko" ].each do |taken|
          rename(taken)
          expect(response).to have_http_status(:unprocessable_content)
          expect(name_error).to eq("You already have a location called “#{taken}”.")
        end
        expect(deck.reload.name).to eq("izzet tempo")
      end

      it "answers 422 with the typed text kept and the sentence on the Name field (AC-2.4)", :aggregate_failures do
        { "   " => Location::MESSAGES[:blank], ("a" * 61) => Location::MESSAGES[:too_long], "a\u200Bb" => Location::MESSAGES[:control] }.each do |typed, message|
          rename(typed)

          expect(response).to have_http_status(:unprocessable_content)
          expect(html.css(".field_with_errors")).to be_empty
          expect(html.at_css("h1").text).to eq("Rename deck")
          expect(html.at_css(".c-pagehead__stats").text).to eq("Izzet Tempo")
          expect(name_error).to eq(message)
          expect(html.at_css("#location_name")["value"]).to eq(typed)
          expect(html.at_css("#location_name")["aria-describedby"]).to eq("location_name-error")
          expect(deck.reload.name).to eq("Izzet Tempo")
        end
      end

      it "answers 400 without the location parameter" do
        patch deck_path(deck), params: { other: "x" }

        expect(response).to have_http_status(:bad_request)
      end

      it "refuses a place's name for a new place and a rename on the Locations page, by key (AC-2.5a)", :aggregate_failures do
        place = create(:location, account:, name: "Blue binder")

        post locations_path, params: { location: { name: "izzet  TEMPO" } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#location_name-error").text).to eq("You already have a location called “izzet TEMPO”.")
        patch location_path(place), params: { location: { name: "Izzet Tempo" } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(place.reload.name).to eq("Blue binder")
        expect(account.locations.top_level.count).to eq(2)
      end

      it "answers 404 for a place's id and a zone's id on /decks (AC-2.6)", :aggregate_failures do
        place = create(:location, account:, name: "Blue binder")

        [ place, deck.zone("main") ].each do |other|
          get edit_deck_path(other.id)
          expect(response).to have_http_status(:not_found)
          rename("Renamed", to: other.id)
          expect(response).to have_http_status(:not_found)
          expect(other.reload.name).not_to eq("Renamed")
        end
      end

      it "answers 404 for an id that is a deck's id followed by letters, as for any id that is not digits only (spec 066 AC-1.2)", :aggregate_failures do
        [ "#{deck.location_id}abc", "abc", "0", "-1" ].each do |id|
          get edit_deck_path(id)
          expect(response).to have_http_status(:not_found), "#{id.inspect} was not a 404"
        end
        get edit_deck_path(deck)
        expect(response).to have_http_status(:ok)
      end

      it "answers 404 for a deck's id and a zone's id on /locations (AC-2.6, a place's name is the only one this page renames)", :aggregate_failures do
        [ deck.location, deck.zone("main") ].each do |other|
          get edit_location_path(other)
          expect(response).to have_http_status(:not_found)
          patch location_path(other), params: { location: { name: "Renamed" } }
          expect(response).to have_http_status(:not_found)
        end
      end

      it "answers 404 for another account's deck and changes nothing (AC-9.7)", :aggregate_failures do
        theirs = create(:deck, name: "Theirs")

        get edit_deck_path(theirs)
        expect(response).to have_http_status(:not_found)
        rename("Mine", to: theirs)
        expect(response).to have_http_status(:not_found)
        expect(theirs.reload.name).to eq("Theirs")
      end
    end

    it "sends a signed-out visitor to sign in", :aggregate_failures do
      get edit_deck_path(deck)
      expect(response).to redirect_to(new_session_path)
      rename("Spirits")
      expect(response).to redirect_to(new_session_path)
      expect(deck.reload.name).to eq("Izzet Tempo")
    end
  end

  describe "GET /decks/:id/removal/new and DELETE /decks/:id (Story 3)" do
    let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }

    def notice = html.at_css("#status")&.text.to_s.squish
    def page_text = html.at_css("main").text.squish
    def buttons = html.css("main button, main input[type=submit]").map { it.text.squish + it["value"].to_s }

    context "when signed in" do
      before { sign_in_as(user) }

      it "asks first for an empty deck, naming it and its zones, with Remove and Cancel, and removes nothing on a GET (AC-3.1)", :aggregate_failures do
        get new_deck_removal_path(deck)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("h1").text).to eq("Remove Izzet Tempo?")
        expect(html.at_css(".c-confirm p").text).to include('zones are removed with it')
        expect(html.at_css("form[action='#{deck_path(deck)}'] input[name=_method]")["value"]).to eq("delete")
        expect(html.at_css("form[action='#{deck_path(deck)}'] button").text).to eq("Remove")
        expect(html.at_css("form[action='#{deck_path(deck)}'] button")["class"]).to include("c-btn--danger")
        expect(html.at_css(".c-form__actions a.c-btn--secondary[href='#{decks_path}']").text).to eq("Cancel")
        expect(html.css(".c-appbar__nav a[aria-current=page]").map(&:text)).to eq([ "Decks" ])
        expect(account.decks.count).to eq(1)
        expect(deck.zones.count).to be > 0
      end

      it "removes the deck, its row and its zones on DELETE and nothing else, answering 303 with the notice (AC-3.2)", :aggregate_failures do
        other = create(:deck, account:, name: "Krenko")
        place = create(:location, account:, name: "Blue binder")
        lot = create(:lot, account:, location: place, quantity: 2)
        before = [ lot.reload.attributes, other.zones.pluck(:id, :name), place.reload.attributes ]
        zone_ids = deck.zones.pluck(:id)

        delete deck_path(deck)

        expect(response).to have_http_status(:see_other).and redirect_to(decks_path)
        follow_redirect!
        expect(notice).to eq("Removed “Izzet Tempo”.")
        expect(Deck.where(location_id: deck.location_id)).to be_empty
        expect(Location.where(id: [ deck.location_id, *zone_ids ])).to be_empty
        expect(account.decks.pluck(:location_id)).to eq([ other.location_id ])
        expect([ lot.reload.attributes, other.zones.pluck(:id, :name), place.reload.attributes ]).to eq(before)
      end

      it "refuses a deck with lots in two zones, counting and listing each lot with its zone, with no Remove and no bulk button (AC-3.3)", :aggregate_failures do
        create_lot_in_zone(deck, "main", quantity: 4)
        create_lot_in_zone(deck, "main", quantity: 4)
        create_lot_in_zone(deck, "sideboard", quantity: 4)

        get new_deck_removal_path(deck)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("h1").text).to eq("“Izzet Tempo” isn't empty")
        expect(page_text).to include("“Izzet Tempo” holds 12 copies in 3 lots. Move them before removing it.")
        expect(html.css("#held_lots li").size).to eq(3)
        expect(html.css("#held_lots li .c-list__end").map(&:text)).to eq(%w[×4 ×4 ×4])
        expect(html.css("#held_lots li .c-decks__zone").map(&:text).sort).to eq([ "Izzet Tempo › Main", "Izzet Tempo › Main", "Izzet Tempo › Sideboard" ])
        expect(html.css("#held_lots li a").map { it["href"] }).to all(start_with("/catalog/entries/").and(end_with("#copies")))
        expect(html.at_css("a[href='#{decks_path}']", text: "Back to decks")).to be_present
        expect(buttons.grep(/Remove|bulk/)).to be_empty
        expect(html.css("main form")).to be_empty
      end

      it "lists the first 100 lots and says how many more (AC-3.3)", :aggregate_failures do
        entry = create(:mtg_printing, finishes: %w[nonfoil foil]).entry
        zone = deck.zone("main")
        250.times { |n| create(:lot, account:, entry:, location: zone, price_paid_cents: n + 1) }

        get new_deck_removal_path(deck)

        expect(html.css("#held_lots li").size).to eq(100)
        expect(html.at_css(".c-locations__more").text).to eq("and 150 more")
        expect(page_text).to include("holds 250 copies in 250 lots")
      end

      it "answers 409 to DELETE with the same page, removing nothing, also when a lot came after the page opened (AC-3.4)", :aggregate_failures do
        get new_deck_removal_path(deck)
        expect(html.css("form[action='#{deck_path(deck)}'] button").size).to eq(1)
        create_lot_in_zone(deck, "considering", quantity: 2)
        before = account.lots.order(:id).map(&:attributes)

        delete deck_path(deck)

        expect(response).to have_http_status(:conflict)
        expect(page_text).to include("“Izzet Tempo” holds 2 copies in 1 lot. Move them before removing it.")
        expect(html.css("#held_lots li .c-decks__zone").map(&:text)).to eq([ "Izzet Tempo › Considering" ])
        expect(account.decks.exists?(location_id: deck.location_id)).to be(true)
        expect(deck.zones.count).to eq(Catalog::Formats.zones_for("mtg", "modern").size)
        expect(account.lots.order(:id).map(&:attributes)).to eq(before)
      end

      it "answers 409 when a lot lands between the check and the delete, leaving no zone and no deck missing (AC-3.5)", :aggregate_failures do
        zones_before = deck.zones.pluck(:id)
        calls = 0
        allow(Location::Holdings).to receive(:new).and_wrap_original do |original, *args|
          calls += 1
          next original.call(*args) unless calls == 1

          create_lot_in_zone(deck, "main", quantity: 3) # lands after the page opened empty, before the delete
          instance_double(Location::Holdings, any?: false)
        end

        delete deck_path(deck)

        expect(response).to have_http_status(:conflict)
        expect(page_text).to include("“Izzet Tempo” holds 3 copies in 1 lot.")
        expect(deck.zones.pluck(:id)).to eq(zones_before)
        expect(account.decks.exists?(location_id: deck.location_id)).to be(true)
        expect(Location.exists?(deck.location_id)).to be(true)
      end

      it "answers 404 to a second removal and says nothing (AC-3.6)", :aggregate_failures do
        delete deck_path(deck)
        delete deck_path(deck)

        expect(response).to have_http_status(:not_found)
      end

      it "changes no sitting, number-entry line, bulk selection or undo record (AC-3.7)", :aggregate_failures do
        place = create(:location, account:, name: "Blue binder")
        sitting = Scanner::Sitting.create!(account:, location: place)
        NumberEntry.add!(account:, entry: create(:mtg_printing).entry, quantity: 2, finish: nil, line_key: NumberEntry.new_line_key, location: place)
        session = user.sessions.order(:id).last
        BulkSelection.for(session).restart!(query: "", sort: CollectionTable::Sort.parse(nil, nil), location: place.id.to_s, all: true)
        BulkRemoval.create!(session:, account:, copies: 1, lots_data: [])
        snapshot = -> do
          [ sitting.reload.attributes, account.number_entry.lines.map(&:attributes), BulkSelection.for(session).reload.attributes,
            BulkSelection::Mark.count, BulkRemoval.order(:id).map(&:attributes) ]
        end
        before = snapshot.()

        delete deck_path(deck)

        expect(response).to have_http_status(:see_other)
        expect(snapshot.()).to eq(before)
      end

      it "answers 404 for a place's id and a zone's id on the removal page and DELETE (AC-3.8)", :aggregate_failures do
        place = create(:location, account:, name: "Blue binder")

        [ place, deck.zone("main") ].each do |other|
          get new_deck_removal_path(other.id)
          expect(response).to have_http_status(:not_found)
          delete deck_path(other.id)
          expect(response).to have_http_status(:not_found)
          expect(Location.exists?(other.id)).to be(true)
        end
      end

      it "answers 404 for another account's deck on the removal page and DELETE, leaving it whole (AC-9.7)", :aggregate_failures do
        theirs = create(:deck, name: "Theirs")
        create_lot_in_zone(theirs, "main", quantity: 1)

        get new_deck_removal_path(theirs)
        expect(response).to have_http_status(:not_found)
        delete deck_path(theirs)
        expect(response).to have_http_status(:not_found)
        expect(theirs.account.decks.count).to eq(1)
        expect(theirs.zones.count).to be > 0
      end

      it "escapes a deck name with markup on both pages", :aggregate_failures do
        evil = create(:deck, account:, name: "<b>x</b>")
        get new_deck_removal_path(evil)
        expect(response.body).not_to include("<b>x</b>")
        create_lot_in_zone(evil, "main", quantity: 1)
        get new_deck_removal_path(evil)
        expect(response.body).not_to include("<b>x</b>")
        expect(response.body).to include("&lt;b&gt;x&lt;/b&gt;")
      end
    end

    it "sends a signed-out visitor to sign in and removes nothing", :aggregate_failures do
      get new_deck_removal_path(deck)
      expect(response).to redirect_to(new_session_path)
      delete deck_path(deck)
      expect(response).to redirect_to(new_session_path)
      expect(Deck.exists?(location_id: deck.location_id)).to be(true)
    end
  end
end
