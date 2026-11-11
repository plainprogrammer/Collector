require "rails_helper"

# Spec 066 Stories 1 to 4 and 6: the deck page, GET /decks/:id.
RSpec.describe "Deck page", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  def html = Nokogiri::HTML5(response.body)
  def zone_section(name) = html.css("section.c-zone").find { it.at_css("h2").text == name }
  def card_rows(section) = section.css("tbody tr:not(.c-zone__group)")
  def own(zone, entry, quantity: 1, **attrs) = create_lot_in_zone(deck, zone, entry:, quantity:, **attrs)
  def proxy_in(zone, entry, quantity: 1, finish: "nonfoil") = create(:deck_proxy, zone: deck.zone(zone), account:, entry:, finish:, quantity:)

  def printing(name: "Lightning Bolt", type_line: "Instant", cost: "{R}", legalities: {}, **attrs)
    entry = create(:catalog_entry, name:, **attrs)
    create(:mtg_printing, entry:, legalities:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    entry
  end

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the page and its head (Story 1)" do
      it "answers 200 as a detail page under Decks with the deck's name as the h1 (AC-1.1)", :aggregate_failures do
        get deck_path(deck)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Izzet Tempo · Collector")
        expect(html.at_css("h1").text).to eq("Izzet Tempo")
        expect(html.at_css("header.c-appbar--detail")).to be_present
        expect(html.at_css("header a[aria-label='Back'][href='#{decks_path}']")).to be_present
        expect(html.at_css("header nav a[aria-current='page']").text).to eq("Decks")
        expect(html.at_css("nav.c-tabbar a[aria-current='page']")&.text.to_s).to include("Decks")
      end

      it "reads the format and the copies of every zone, Considering included (AC-1.3)", :aggregate_failures do
        own("main", printing, quantity: 40)
        own("sideboard", printing(name: "Spell Pierce"), quantity: 15)
        own("considering", printing(name: "Force of Will"), quantity: 3)

        get deck_path(deck)

        expect(html.at_css(".c-item__type").text).to eq("Modern · 58 cards · 58 owned · 0 proxy")
      end

      it "reads '1 card · 1 owned' for one copy and '0 cards · 0 owned' for none (AC-1.3)", :aggregate_failures do
        get deck_path(deck)
        expect(html.at_css(".c-item__type").text).to eq("Modern · 0 cards · 0 owned · 0 proxy")

        own("main", printing)
        get deck_path(deck)
        expect(html.at_css(".c-item__type").text).to eq("Modern · 1 card · 1 owned · 0 proxy")
      end

      it "shows the stored format key for a format the instance no longer registers (AC-1.3)" do
        deck.update!(format: "retired")

        get deck_path(deck)

        expect(html.at_css(".c-item__type").text).to eq("retired · 0 cards · 0 owned · 0 proxy")
      end

      it "offers Edit deck, then a menu with Change format and, after a separator, Remove deck (AC-1.4)", :aggregate_failures do
        get deck_path(deck)

        expect(html.at_css(".c-item__actions > a.c-btn--secondary[href='#{edit_deck_path(deck)}']").text).to eq("Edit deck")
        items = html.css(".c-item__actions .c-menu__list > *")
        expect(items.map { [ it["class"], it.text.strip ] }).to eq([
          [ "c-menu__item", "Change format" ], [ "c-menu__sep", "" ], [ "c-menu__item c-menu__item--danger", "Remove deck" ]
        ])
        expect(items.first["href"]).to eq(edit_deck_format_path(deck))
        expect(items.last["href"]).to eq(new_deck_removal_path(deck))
      end

      it "has no shape panel, and a dash in the Proxy cell of a row with no proxy (AC-1.6; spec 068 supersedes spec 066 AC-1.6's no proxy control)", :aggregate_failures do
        own("main", printing)

        get deck_path(deck)

        expect(card_rows(zone_section("Main")).first.css("td")[3].at_css(".is-muted").text).to eq("–")
        expect(html.at_css("aside.c-deck__shape, details.c-shapefold")).to be_nil
      end
    end

    describe "proxies (spec 068 Story 2)" do
      it "shows the tag, Owned 0 and Total in the row, and the three counts in the heads (AC-2.1, AC-2.3)", :aggregate_failures do
        bolt = printing
        own("main", bolt, quantity: 4)
        proxy_in("main", bolt, quantity: 5)
        proxy_in("sideboard", printing(name: "Spell Pierce"), quantity: 2)

        get deck_path(deck)

        expect(html.at_css(".c-item__type").text).to eq("Modern · 11 cards · 4 owned · 7 proxy")
        main = zone_section("Main")
        expect(main.at_css(".c-section__count").text).to eq("9 cards · 4 owned · 5 proxy")
        row = card_rows(main).first
        expect(row.css("td")[2].text.strip).to eq("4")
        expect(row.css("td")[3].at_css("span.c-proxy").text.squish).to eq("Proxy 5")
        expect(row.css("td")[4].text.strip).to eq("9")
        expect(row.at_css(".c-table__sub .c-proxy").text.squish).to eq("Proxy 5")
        expect(card_rows(zone_section("Sideboard")).first.css("td")[2].text.strip).to eq("0")
        expect(main.at_css("tr.c-zone__group .c-zone__groupcount").text).to eq("9")
      end

      it "shows a muted dash and no tag for a row with no proxy, and '0 proxy' in an empty zone's head (AC-2.1, AC-2.3)", :aggregate_failures do
        own("main", printing)

        get deck_path(deck)

        row = card_rows(zone_section("Main")).first
        expect(row.css("td")[3].at_css(".c-proxy")).to be_nil
        expect(row.css("td")[3].at_css(".is-muted").text).to eq("–")
        expect(row.at_css(".c-table__sub .c-proxy")).to be_nil
        expect(zone_section("Sideboard").at_css(".c-section__count").text).to eq("0 cards · 0 owned · 0 proxy")
        expect(zone_section("Sideboard").at_css(".c-zone__empty").text).to eq("No cards in Sideboard yet.")
      end

      it "gives each zone head an Add a proxy link, and the page no form (AC-1.1, AC-2.7)", :aggregate_failures do
        get deck_path(deck)

        main = zone_section("Main")
        link = main.at_css(".c-section__actions a")
        expect(link["href"]).to eq(new_deck_zone_proxy_path(deck, "main"))
        expect(link.text.squish).to eq("Add a proxy to Main")
        expect(zone_section("Sideboard").at_css(".c-section__actions a")).to be_present
        expect(html.at_css("main form")).to be_nil
      end

      it "has a menu cell with the proxy items for a row with a proxy, and none for a row without (AC-2.6, AC-2.7)", :aggregate_failures do
        bolt = printing
        proxy_in("main", bolt)
        own("main", printing(name: "Spell Pierce"))

        get deck_path(deck)

        rows = card_rows(zone_section("Main"))
        with, without = rows.partition { it.at_css("a").text.include?("Lightning") }.map(&:first)
        trigger = with.at_css("td.c-table__actions summary")
        expect(trigger["aria-label"]).to match(/\AActions for Lightning Bolt /)
        items = with.css(".c-menu__item")
        expect(items.map { it.text.strip }).to eq([ "Change proxy count", "Remove proxy" ])
        expect(items.last["class"]).to include("c-menu__item--danger")
        expect(with.css(".c-menu__sep").size).to eq(1)
        expect(without.at_css("td.c-table__actions").children.map(&:text).join.strip).to eq("")
        expect(without.at_css("summary")).to be_nil
        expect(html.css("th").map { it.text.strip }.first(6)).to eq([ "Card", "Cost", "Owned", "Proxy", "Total", "Actions" ])
      end

      it "names the finish in a row with proxies of two finishes (AC-2.6)", :aggregate_failures do
        bolt = printing
        proxy_in("main", bolt, finish: "foil", quantity: 1)
        proxy_in("main", bolt, finish: "nonfoil", quantity: 2)

        get deck_path(deck)

        items = card_rows(zone_section("Main")).first.css(".c-menu__item").map { it.text.strip }
        expect(items).to eq([ "Change Foil proxy count", "Change Nonfoil proxy count", "Remove Foil proxy", "Remove Nonfoil proxy" ])
      end

      it "shows a proxy of a retired printing and a legality marker on a proxy row (AC-2.8, AC-2.9)", :aggregate_failures do
        banned = printing(name: "Black Lotus", legalities: { "modern" => "banned" })
        retired = create(:catalog_entry, :retired, name: "Old Card")
        create(:mtg_printing, entry: retired)
        proxy_in("main", banned)
        proxy_in("main", retired)

        get deck_path(deck)

        rows = card_rows(zone_section("Main"))
        expect(rows.map { it.at_css("a").text }).to include("Black Lotus", "Old Card")
        expect(rows.find { it.at_css("a").text == "Black Lotus" }.at_css(".c-legal").text).to include("Banned")
      end

      it "shows a proxy of a printing with no extension record in Other, with a dash for its cost and no marker (AC-2.8)", :aggregate_failures do
        proxy_in("main", create(:catalog_entry, name: "Bare"), finish: nil)

        get deck_path(deck)

        expect(zone_section("Main").at_css("tr.c-zone__group th").text).to start_with("Other")
        row = card_rows(zone_section("Main")).sole
        expect(row.css("td")[1].at_css(".is-muted").text).to eq("–")
        expect(row.at_css(".c-proxy").text.squish).to eq("Proxy 1")
        expect(html.css(".c-legal")).to be_empty
      end

      it "counts no proxy in the collection, the card page or an export's lots (AC-4.1)", :aggregate_failures do
        bolt = printing
        proxy_in("main", bolt, quantity: 3)

        get collection_path
        expect(response.body).not_to include("Lightning Bolt")
        get catalog_entry_path(bolt)
        expect(html.text).not_to match(/\b3 copies\b/)
        expect(CollectionExport.new(account:, at: Time.current).to_h["lots"]).to eq([])
      end
    end

    describe "what a proxy leaves alone (AC-2.12, AC-4.1)" do
      let(:bolt) { printing }

      def collection_count
        get collection_path
        html.at_css(".c-pagehead__stats").text
      end

      def card_page_owned
        get catalog_entry_path(bolt)
        html.css(".c-stat").find { it.at_css("dt").text == "Owned" }.at_css("dd").text
      end

      def decks_page_owned
        get decks_path
        html.at_css("tbody tr").css("td")[html.css("thead th").map { it.text.strip }.index("Owned")].text.strip
      end

      def snapshot = [ collection_count, card_page_owned, decks_page_owned ]

      def proxy_tags_on_collection_and_card_page = [ collection_path, catalog_entry_path(bolt) ].flat_map { get(it) && html.css(".c-proxy").to_a }

      it "changes no count on the collection, the card page or the Decks page when a proxy is added, changed and removed", :aggregate_failures do
        own("main", bolt, quantity: 2)
        before = snapshot
        post deck_zone_proxies_path(deck, "main"), params: { proxy: { entry: bolt.external_key, finish: "nonfoil", quantity: "3" } }
        proxy = Deck::Proxy.sole
        added = snapshot
        patch deck_proxy_path(deck, proxy), params: { proxy: { quantity: "5" } }
        changed = snapshot
        delete deck_proxy_path(deck, proxy)

        expect(before).to eq([ "2 items · 1 unique", "2", "2" ])
        expect([ added, changed, snapshot ]).to all(eq(before))
        expect(Deck::Proxy.count).to eq(0)
      end

      it "shows no proxy tag on the collection or the card page while a deck holds one" do
        own("main", bolt, quantity: 2)
        proxy_in("main", bolt, quantity: 3)

        expect(proxy_tags_on_collection_and_card_page).to be_empty
      end
    end

    describe "tenancy (AC-1.2)" do
      it "answers 404 for another account's deck, a place's id, a zone's id and an id nothing has", :aggregate_failures do
        theirs = "Rival #{SecureRandom.hex(4)}" # built at run time: the test environment's error page prints the spec's own source lines
        other = create(:deck, account: create(:user).account, name: theirs)
        place = create(:location, account:)

        [ other.to_param, place.id, deck.zone("main").id, 0, "abc", "#{deck.location_id}abc", Location.maximum(:id).to_i + 100 ].each do |id|
          get deck_path(id)
          expect(response).to have_http_status(:not_found), "#{id.inspect} was not a 404"
          expect(response.body).not_to include(theirs)
        end
      end

      it "sends a visitor who is not signed in to sign in" do
        delete session_path

        get deck_path(deck)

        expect(response).to redirect_to(new_session_path)
      end
    end

    describe "zones (Story 2)" do
      it "stacks a section per zone, h2 and counts, in the format's order, each table named by its heading (AC-2.1, AC-2.3)", :aggregate_failures do
        own("main", printing, quantity: 12)

        get deck_path(deck)

        expect(html.css("section.c-zone h2").map(&:text)).to eq(%w[Main Sideboard Considering])
        expect(zone_section("Main").at_css(".c-section__count").text).to eq("12 cards · 12 owned · 0 proxy")
        table = zone_section("Main").at_css("table")
        expect(table["aria-labelledby"]).to eq(zone_section("Main").at_css("h2")["id"])
        expect(table.css("thead th").map { it.text.squish }).to eq([ "Card", "Cost", "Owned", "Proxy", "Total", "Actions" ])
      end

      it "lists Commander first for a Commander deck (AC-2.1)" do
        krenko = create(:deck, account:, name: "Krenko", format: "commander")

        get deck_path(krenko)

        expect(html.css("section.c-zone h2").map(&:text)).to eq(%w[Commander Main Considering])
      end

      it "lists Main, Sideboard, Considering after a change from Commander to Modern (AC-2.2)" do
        krenko = create(:deck, account:, name: "Krenko", format: "commander")
        Deck::FormatChange.new(deck: krenko, format: "mtg/modern").save!

        get deck_path(krenko)

        expect(html.css("section.c-zone h2").map(&:text)).to eq(%w[Main Sideboard Considering])
      end

      it "adds a printing's lots of every finish into one row, Proxy a dash and Total equal to Owned (AC-2.3, AC-2.4)", :aggregate_failures do
        bolt = printing
        own("main", bolt, quantity: 2, finish: "foil")
        own("main", bolt, quantity: 1, finish: "nonfoil")
        own("main", printing(name: "Lightning Bolt", number: "9"), quantity: 4) # another printing of the card
        own("sideboard", bolt, quantity: 8) # another zone
        create(:lot, account:, entry: bolt, quantity: 6, location: create(:location, account:)) # a place
        create(:lot, entry: bolt, quantity: 5) # another account

        get deck_path(deck)

        cells = card_rows(zone_section("Main")).map { |row| row.css("td").map { it.text.squish } }
        expect(cells.size).to eq(2)
        expect(cells.map { it.values_at(2, 4) }).to contain_exactly([ "3", "3" ], [ "4", "4" ])
        expect(cells.map { it[3] }).to eq([ "–", "–" ])
        expect(card_rows(zone_section("Main")).first.css("td")[3].at_css(".is-muted")).to be_present
      end

      it "shows the name linked to the card's copies in the collection's context, and SET · NUMBER under it (AC-2.5, AC-4.1)", :aggregate_failures do
        entry = printing(name: "Murktide Regent", type_line: "Creature — Dragon", number: "52")
        own("main", entry)

        get deck_path(deck)

        card = card_rows(zone_section("Main")).first.at_css("td")
        link = card.at_css("a")
        expect(link.text).to eq("Murktide Regent")
        expect(link["href"]).to eq(catalog_entry_path(entry, from: "collection", anchor: "copies"))
        expect(card.css(".c-zone__set").map { it.text }).to eq([ "#{entry.set.code.upcase} · 52" ] * 2)
      end

      it "shows a non-English printing under its localized name with its language after the number (AC-2.5)", :aggregate_failures do
        entry = printing(name: "Lightning Bolt", language: "de", localized_name: "Blitzschlag")
        own("main", entry)

        get deck_path(deck)

        card = card_rows(zone_section("Main")).first.at_css("td")
        expect(card.at_css("a").text).to eq("Blitzschlag")
        expect(card.css(".c-zone__set").first.text).to eq("#{entry.set.code.upcase} · #{entry.number} · DE")
      end

      it "puts each group in its own tbody under a rowgroup header with its copies, in the extension's order (AC-2.6, AC-5.7)", :aggregate_failures do
        own("main", printing(name: "Island", type_line: "Basic Land — Island"), quantity: 20)
        own("main", printing(name: "Murktide Regent", type_line: "Creature — Dragon"), quantity: 2)
        own("main", printing(name: "Dryad Arbor", type_line: "Land Creature — Forest Dryad"), quantity: 1)

        get deck_path(deck)

        bodies = zone_section("Main").css("table tbody")
        expect(bodies.map { it.at_css("tr.c-zone__group th[scope='rowgroup']").text }).to eq([ "Creatures3", "Lands20" ])
        expect(bodies.map { it.at_css("th[scope='rowgroup']")["colspan"] }).to eq(%w[6 6])
        expect(bodies.first.css("tr:not(.c-zone__group) td a").map(&:text)).to eq([ "Dryad Arbor", "Murktide Regent" ])
      end

      it "shows the empty sentence in place of a table for an empty zone (AC-2.7)", :aggregate_failures do
        own("main", printing)

        get deck_path(deck)

        sideboard = zone_section("Sideboard")
        expect(sideboard.at_css(".c-section__count").text).to eq("0 cards · 0 owned · 0 proxy")
        expect(sideboard.at_css("p.c-zone__empty").text).to eq("No cards in Sideboard yet.")
        expect(sideboard.at_css("table")).to be_nil
      end

      it "does not show or count copies of another deck of the account (AC-2.8)", :aggregate_failures do
        other = create(:deck, account:, name: "Other")
        create_lot_in_zone(other, "main", entry: printing(name: "Elsewhere"), quantity: 9)

        get deck_path(deck)

        expect(response.body).not_to include("Elsewhere")
        expect(html.at_css(".c-item__type").text).to eq("Modern · 0 cards · 0 owned · 0 proxy")
      end

      it "shows a retired printing like any other (AC-2.9)" do
        own("main", printing(name: "Old Card", retired_at: 1.day.ago))

        get deck_path(deck)

        expect(card_rows(zone_section("Main")).first.at_css("a").text).to eq("Old Card")
      end

      it "escapes a card name with markup" do
        own("main", printing(name: "<script>alert(1)</script>"))

        get deck_path(deck)

        expect(response.body).not_to include("<script>alert(1)</script>")
      end
    end

    describe "cost (AC-6.4)" do
      it "draws the first face's pips, not the second's, and a muted dash for no cost", :aggregate_failures do
        pips = printing(name: "Tarmogoyf", type_line: "Creature", cost: "{3}{G}{G}")
        double = printing(name: "Delver", cost: "{1}{U}")
        MTG::Printing.find_by!(catalog_entry_id: double.id).update!(faces: [ { "name" => "Delver", "type_line" => "Creature", "mana_cost" => "{1}{U}" },
                                          { "name" => "Insectile", "type_line" => "Creature", "mana_cost" => "{2}{G}" } ])
        land = printing(name: "Island", type_line: "Basic Land — Island", cost: "")
        [ pips, double, land ].each { own("main", it) }

        get deck_path(deck)

        cost = ->(name) { card_rows(zone_section("Main")).find { |row| row.at_css("a").text == name }.css("td")[1] }
        expect(cost.("Tarmogoyf").at_css(".c-cost")["aria-label"]).to eq("Mana cost: 3 generic, 1 green, 1 green")
        expect(cost.("Delver").at_css(".c-cost")["aria-label"]).to eq("Mana cost: 1 generic, 1 blue")
        expect(cost.("Island").at_css(".c-cost")).to be_nil
        expect(cost.("Island").at_css(".is-muted").text).to eq("–")
      end
    end

    describe "the legality marker (Story 3)" do
      def markers(name) = card_rows(zone_section("Main")).find { it.at_css("a").text == name }.css(".c-legal")

      it "marks a banned, a restricted and a not legal card in the deck's format in the muted ink, and not a legal one (AC-3.1)", :aggregate_failures do
        own("main", printing(name: "Ragavan", legalities: { "modern" => "banned" }))
        own("main", printing(name: "Pyroblast", legalities: { "modern" => "not_legal" }))
        own("main", printing(name: "Bolt", legalities: { "modern" => "legal" }))
        vintage = create(:deck, account:, name: "Vintage", format: "vintage")
        create_lot_in_zone(vintage, "main", entry: printing(name: "Black Lotus", legalities: { "vintage" => "restricted" }))

        get deck_path(deck)
        expect(markers("Ragavan").map { it.text.strip }).to eq([ "Banned", "Banned" ])
        expect(markers("Pyroblast").map { it.text.strip }).to eq([ "Not legal", "Not legal" ])
        expect(markers("Bolt")).to be_empty
        expect(markers("Ragavan").first["class"]).to eq("c-legal c-legal--no")
        expect(markers("Ragavan").first.at_css("svg")).to be_present

        get deck_path(vintage)
        expect(html.css(".c-legal").map { it.text.strip }).to eq([ "Restricted", "Restricted" ])
      end

      it "reads a card with no entry for the format as Not legal (AC-3.2)" do
        own("main", printing(name: "Blank", legalities: {}))

        get deck_path(deck)

        expect(markers("Blank").map { it.text.strip }).to eq([ "Not legal", "Not legal" ])
      end

      it "shows no marker in a Casual deck (AC-3.3)" do
        casual = create(:deck, account:, name: "Casual", format: "casual")
        create_lot_in_zone(casual, "main", entry: printing(legalities: { "modern" => "banned" }))

        get deck_path(casual)

        expect(html.css(".c-legal")).to be_empty
      end

      it "shows no marker for an unregistered format and keeps the groups and costs (AC-3.4)", :aggregate_failures do
        deck.update!(format: "retired")
        own("main", printing(name: "Ragavan", type_line: "Creature", legalities: { "modern" => "banned" }))

        get deck_path(deck)

        expect(html.css(".c-legal")).to be_empty
        expect(html.css("tr.c-zone__group th").first.text).to start_with("Creatures")
        expect(html.at_css(".c-cost")).to be_present
      end

      it "drops the marker after the deck's format changes to one the card is legal in (AC-3.5)", :aggregate_failures do
        standard = create(:deck, account:, name: "Std", format: "standard")
        create_lot_in_zone(standard, "main", entry: printing(name: "Mox", legalities: { "standard" => "not_legal", "modern" => "legal" }))
        get deck_path(standard)
        expect(html.css(".c-legal").size).to eq(2)

        Deck::FormatChange.new(deck: standard, format: "mtg/modern").save!
        get deck_path(standard)

        expect(html.css(".c-legal")).to be_empty
      end

      it "writes the marker beside the name inside is-opt and in the line under it (AC-3.6)", :aggregate_failures do
        own("main", printing(name: "Ragavan", legalities: { "modern" => "banned" }))

        get deck_path(deck)

        cell = card_rows(zone_section("Main")).first.at_css("td")
        expect(cell.css(".is-opt .c-legal").size).to eq(1)
        expect(cell.css(".c-table__sub .c-legal").size).to eq(1)
      end

      it "sends no request out of the app to read a legality (AC-3.7)" do
        own("main", printing(legalities: { "modern" => "banned" }))

        get deck_path(deck)

        expect(response).to have_http_status(:ok) # WebMock blocks every real request, so a fetch would have raised
      end
    end

    describe "copies are not added or moved here (Story 4)" do
      it "has no form or drag target, no link to add copies, to number entry or to the scanner, and every card links to its copies (AC-4.2)", :aggregate_failures do
        own("main", printing)

        get deck_path(deck)

        main = html.at_css("main")
        expect(main.css("form, [draggable]")).to be_empty
        hrefs = main.css("a").map { it["href"] }
        expect(hrefs.grep(%r{/lots/new|number_entry|/scanner})).to be_empty
        expect(main.css("tbody a").map { it["href"] }).to all(include("from=collection#copies"))
      end
    end

    describe "a collectible that answers nothing (AC-6.1, AC-6.6)", :other_collecting do
      it "renders one flat table with a dash in Cost and no marker", :aggregate_failures do
        other = create(:deck, account:, name: "Other deck", pair: "other/standard")
        Lot.add!(account:, entry: create(:catalog_entry, collectible_type: "other", name: "Thing"), location: other.zone("deck"), quantity: 3)

        get deck_path(other)

        expect(response).to have_http_status(:ok)
        expect(html.css("tr.c-zone__group")).to be_empty
        expect(html.css("table tbody").size).to eq(1)
        row = html.at_css("tbody tr")
        expect(row.css("td")[1].at_css(".is-muted").text).to eq("–")
        expect(html.css(".c-legal")).to be_empty
      end
    end

    it "answers 200 for a deck whose collectible type is no longer registered: the stored format key, a flat table, a dash, no marker (Reliability)", :aggregate_failures do
      own("main", printing(legalities: { "modern" => "banned" }))
      deck.update!(collectible_type: "gone")

      get deck_path(deck)

      expect(response).to have_http_status(:ok)
      expect(html.css("section.c-zone h2").map(&:text)).to eq(%w[Main Sideboard Considering])
      expect(html.at_css(".c-item__type").text).to eq("#{deck.format} · 1 card · 1 owned · 0 proxy")
      expect(html.css("tr.c-zone__group")).to be_empty
      expect(card_rows(zone_section("Main")).first.css("td")[1].at_css(".is-muted").text).to eq("–")
      expect(html.css(".c-legal")).to be_empty
    end

    it "keeps a printing with no face data in Other with a dash and no marker, even in a format with rules (AC-6.6)", :aggregate_failures do
      own("main", printing(name: "Faceless", legalities: { "modern" => "banned" }).tap { MTG::Printing.find_by!(catalog_entry_id: it.id).update!(faces: []) })

      get deck_path(deck)

      expect(response).to have_http_status(:ok)
      expect(zone_section("Main").at_css("tr.c-zone__group th").text).to start_with("Other")
      expect(card_rows(zone_section("Main")).first.css("td")[1].at_css(".is-muted").text).to eq("–")
      expect(html.css(".c-legal")).to be_empty
    end

    it "keeps a printing with no extension record in Other with a dash and no marker (AC-6.6)", :aggregate_failures do
      own("main", create(:catalog_entry, name: "Bare"))

      get deck_path(deck)

      expect(zone_section("Main").at_css("tr.c-zone__group th").text).to start_with("Other")
      expect(card_rows(zone_section("Main")).first.css("td")[1].at_css(".is-muted").text).to eq("–")
      expect(html.css(".c-legal")).to be_empty
    end
  end
end
