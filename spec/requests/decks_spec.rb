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
        expect(html.css(".c-decks tbody td:first-child a")).to be_empty # a name is plain text until the deck page (#253)
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
end
