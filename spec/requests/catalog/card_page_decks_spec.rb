require "rails_helper"

# Spec 073: the card page's stats strip (Story 1) and "In decks" section (Story 2) for a signed-in collector.
RSpec.describe "Card page: Free to use and In decks", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:card) { create(:mtg_printing, entry: create(:catalog_entry, identity:, released_on: Date.new(2022, 1, 1))).entry }
  let(:older) { create(:mtg_printing, entry: create(:catalog_entry, identity:, released_on: Date.new(2020, 1, 1))).entry }

  before { sign_in_as(user) }

  def html = Nokogiri::HTML5(response.body)

  # The strip as { "Owned" => [ "7", "3 printings" ], … }.
  def strip = html.css("dl.c-stats .c-stat").to_h { [ it.at_css("dt").text, [ it.at_css("dd").text, it.at_css("small").text ] ] }

  def place = create(:location, account:)

  # Another account whose deck holds the card: 5 copies in its Sideboard and 2 proxies in its Main. Every record is its own
  # account's (lesson 2026-11-11: another account's lot and zone are built from one account). Returns the other user.
  def other_account_deck(name)
    other_user = create(:user)
    deck = create(:deck, account: other_user.account, name:)
    create_lot_in_zone(deck, "sideboard", entry: card, quantity: 5)
    create(:deck_proxy, zone: deck.zone("main"), entry: card, account: other_user.account, quantity: 2)
    other_user
  end

  def switch_to(other_user)
    delete session_path
    sign_in_as(other_user)
  end

  describe "the stats strip" do
    it "shows Owned, In decks and Free to use as three stats for a card in no deck (AC-1.1)", :aggregate_failures do
      create(:lot, account:, entry: card, quantity: 3)
      get catalog_entry_path(card)

      expect(html.css("dl.c-stats").size).to eq(1)
      expect(html.at_css("dl.c-stats")["class"].split).to include("c-stats--three")
      expect(html.at_css("dl.c-stats")["class"]).not_to include("c-stats--single")
      expect(strip).to eq("Owned" => [ "3", "1 printing" ], "In decks" => [ "0", "in 0 decks" ], "Free to use" => [ "3", "not in a deck" ])
    end

    it "counts copies in zones, Considering included, as in decks and the rest as free (AC-1.2)", :aggregate_failures do
      alpha, beta = create(:deck, account:, name: "Alpha"), create(:deck, account:, name: "Beta")
      create_lot_in_zone(alpha, "main", entry: card, quantity: 2)
      create_lot_in_zone(beta, "considering", entry: older, quantity: 1)
      create(:lot, account:, entry: card, quantity: 3, location: place)
      create(:lot, account:, entry: older, quantity: 1)
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "7", "2 printings" ], "In decks" => [ "3", "in 2 decks" ], "Free to use" => [ "4", "not in a deck" ])
    end

    it "writes each number with its delimiter (AC-1.2)" do
      deck = create(:deck, account:)
      create_lot_in_zone(deck, "main", entry: card, quantity: 9_999)
      create_lot_in_zone(deck, "sideboard", entry: older, quantity: 2_346)
      create(:lot, account:, entry: card, quantity: 9_999)
      create(:lot, account:, entry: older, quantity: 2_346)
      get catalog_entry_path(card)

      expect(strip.transform_values(&:first)).to eq("Owned" => "24,690", "In decks" => "12,345", "Free to use" => "12,345")
    end

    it "has Free to use 0 and In decks equal to Owned when every copy is in a deck (AC-1.3)" do
      deck = create(:deck, account:)
      create_lot_in_zone(deck, "main", entry: card, quantity: 2)
      create_lot_in_zone(deck, "sideboard", entry: card, quantity: 1)
      get catalog_entry_path(card)

      expect(strip.transform_values(&:first)).to eq("Owned" => "3", "In decks" => "3", "Free to use" => "0")
    end

    it "changes none of the three numbers when a proxy is added to a zone of the same deck or of another deck (AC-1.4)", :aggregate_failures do
      first, second = create(:deck, account:, name: "First"), create(:deck, account:, name: "Second")
      create_lot_in_zone(first, "main", entry: card, quantity: 1)
      create(:lot, account:, entry: card, quantity: 1)
      get catalog_entry_path(card)
      before = strip
      expect(before).to eq("Owned" => [ "2", "1 printing" ], "In decks" => [ "1", "in 1 deck" ], "Free to use" => [ "1", "not in a deck" ])

      [ first.zone("sideboard"), second.zone("main") ].each { create(:deck_proxy, zone: it, entry: card, quantity: 2) }
      get catalog_entry_path(card)
      expect(strip).to eq(before)
    end

    it "reads 0, 0 printings and in 0 decks for a card with only a proxy (AC-1.4)" do
      create(:deck_proxy, zone: create(:deck, account:).zone("main"), entry: card, quantity: 1)
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "0", "0 printings" ], "In decks" => [ "0", "in 0 decks" ], "Free to use" => [ "0", "not in a deck" ])
    end

    it "gives the card's own numbers and agrees with Lot::FreeCopies (AC-1.5)", :aggregate_failures do
      deck = create(:deck, account:)
      other_card = create(:mtg_printing).entry
      create_lot_in_zone(deck, "main", entry: card, quantity: 4)
      create(:lot, account:, entry: card, quantity: 2, location: place)
      create(:lot, account:, entry: card, quantity: 1, finish: "foil")
      create_lot_in_zone(deck, "main", entry: other_card, quantity: 9) # another card in a zone
      create(:lot, account:, entry: other_card, quantity: 8) # another card, free
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "7", "1 printing" ], "In decks" => [ "4", "in 1 deck" ], "Free to use" => [ "3", "not in a deck" ])
      expect(Lot::FreeCopies.new(account:, entry: card).total).to eq(3)
    end

    it "counts nothing of another account's lots and proxies, and shows them on that account's own page (AC-1.6)", :aggregate_failures do
      create(:lot, account:, entry: card, quantity: 1)
      other_user = other_account_deck("Their Deck Name")
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "1", "1 printing" ], "In decks" => [ "0", "in 0 decks" ], "Free to use" => [ "1", "not in a deck" ])
      expect(response.body).not_to include("Their Deck Name")

      switch_to(other_user) # the control: the same page for the other account shows their numbers and their deck
      get catalog_entry_path(card)
      expect(strip).to eq("Owned" => [ "5", "1 printing" ], "In decks" => [ "5", "in 1 deck" ], "Free to use" => [ "0", "not in a deck" ])
      expect(response.body).to include("Their Deck Name")
    end
  end

  # Each row as [ deck name, deck href, zone, owned, proxy ].
  def table_rows
    html.css("#in-decks tbody tr").map do |tr|
      cells = tr.css("td")
      [ tr.at_css("a").text, tr.at_css("a")["href"], cells[1].text.strip, cells[2].text.strip, cells[3].text.strip ]
    end
  end

  describe "the In decks section" do
    it "follows Printings and precedes Format legality, with the four headers (AC-2.1)", :aggregate_failures do
      create_lot_in_zone(create(:deck, account:, name: "Alpha"), "main", entry: card)
      get catalog_entry_path(card)

      body = response.body
      expect([ body.index(%(id="printings")), body.index(%(id="in-decks")), body.index("Format legality") ]).to eq(
        [ body.index(%(id="printings")), body.index(%(id="in-decks")), body.index("Format legality") ].sort)
      expect(html.css("#in-decks .c-collection table.c-table thead th").map { it.text.squish }).to eq([ "Deck", "Zone", "Owned", "Proxy" ])
      expect(html.at_css("#in-decks h2.c-section__title").text).to eq("In decks")
      expect(html.at_css("#in-decks table")["aria-labelledby"]).to eq(html.at_css("#in-decks h2")["id"])
    end

    it "makes a row per zone with a link to the deck, the format beside the name and the zone's own name (AC-2.1)", :aggregate_failures do
      beta = create(:deck, account:, name: "Beta", format: "commander")
      apple = create(:deck, account:, name: "apple")
      create_lot_in_zone(beta, "main", entry: card, quantity: 1)
      create_lot_in_zone(apple, "sideboard", entry: card, quantity: 2)
      create_lot_in_zone(apple, "main", entry: card, quantity: 3)
      get catalog_entry_path(card)

      expect(table_rows).to eq([ [ "apple", deck_path(apple), "Main", "3", "—" ], [ "apple", deck_path(apple), "Sideboard", "2", "—" ],
                                 [ "Beta", deck_path(beta), "Main", "1", "—" ] ])
      first = html.at_css("#in-decks tbody tr")
      expect(first.at_css("span.is-opt.is-muted").text.squish).to eq("· Modern")
      expect(first.at_css(".c-table__sub").text.squish).to eq("Modern · Main")
      expect(html.at_css("#in-decks tbody tr:nth-child(3) span.is-opt.is-muted").text.squish).to eq("· Commander")
    end

    it "sums across printings, finishes and conditions, and proxies across printings (AC-2.2)", :aggregate_failures do
      deck = create(:deck, account:, name: "Alpha")
      create_lot_in_zone(deck, "main", entry: card, quantity: 2, finish: "foil")
      create_lot_in_zone(deck, "main", entry: older, quantity: 3, condition: "near_mint")
      create(:deck_proxy, zone: deck.zone("main"), entry: card, finish: "nonfoil", quantity: 1)
      create(:deck_proxy, zone: deck.zone("main"), entry: older, finish: "foil", quantity: 2)
      get catalog_entry_path(card)

      expect(table_rows).to eq([ [ "Alpha", deck_path(deck), "Main", "5", "3" ] ])
    end

    it "has a Considering row, and the table's Owned sums to the strip's In decks, with delimiters (AC-2.3)", :aggregate_failures do
      alpha, beta = create(:deck, account:, name: "Alpha"), create(:deck, account:, name: "Beta")
      create_lot_in_zone(alpha, "considering", entry: card, quantity: 1)
      create_lot_in_zone(alpha, "main", entry: card, quantity: 9_999)
      create_lot_in_zone(alpha, "main", entry: older, quantity: 9_999)
      create_lot_in_zone(beta, "sideboard", entry: card, quantity: 2)
      get catalog_entry_path(card)

      expect(table_rows.map { it[2..3] }).to eq([ [ "Main", "19,998" ], [ "Considering", "1" ], [ "Sideboard", "2" ] ])
      expect(table_rows.sum { it[3].delete(",").to_i }).to eq(strip.fetch("In decks").first.delete(",").to_i)
    end

    it "has a row with Owned 0 and the proxy count, as plain text, for a zone with only a proxy (AC-2.4)", :aggregate_failures do
      deck = create(:deck, account:, name: "Proxies")
      create(:deck_proxy, zone: deck.zone("main"), entry: card, quantity: 2)
      get catalog_entry_path(card)

      expect(table_rows).to eq([ [ "Proxies", deck_path(deck), "Main", "0", "2" ] ])
      expect(html.css("#in-decks .c-proxy")).to be_empty
      expect(html.css("#in-decks td.is-muted")).to be_empty # the control for the dash below: a proxy cell with a count is not muted
    end

    it "shows a muted dash in the Proxy cell for a zone with no proxy (AC-2.4)" do
      create_lot_in_zone(create(:deck, account:), "main", entry: card)
      get catalog_entry_path(card)

      expect(html.css("#in-decks tbody td")[3].then { [ it.text.strip, it["class"].split ] }).to eq([ "—", %w[is-num is-muted] ])
    end

    it "shows the format's key when the extension no longer registers it, and answers 200 (AC-2.5)", :aggregate_failures do
      deck = create(:deck, account:, name: "Old")
      create_lot_in_zone(deck, "main", entry: card)
      deck.update!(format: "gone")
      get catalog_entry_path(card)

      expect(response).to have_http_status(:ok)
      expect(html.at_css("#in-decks span.is-opt.is-muted").text.squish).to eq("· gone")
    end

    def count_line = html.at_css("#in-decks .c-section__count")&.text

    it "words the head count for copies in decks and proxies (AC-2.6)", :aggregate_failures do
      alpha, beta = create(:deck, account:, name: "Alpha"), create(:deck, account:, name: "Beta")
      create_lot_in_zone(alpha, "main", entry: card, quantity: 3)
      create_lot_in_zone(beta, "main", entry: card, quantity: 1)
      get catalog_entry_path(card)
      expect(count_line).to eq("4 copies in 2 decks")

      create(:deck_proxy, zone: alpha.zone("sideboard"), entry: card, quantity: 2)
      get catalog_entry_path(card)
      expect(count_line).to eq("4 copies in 2 decks · 2 proxy")
    end

    it "words the head count for one copy, for proxies only and for neither (AC-2.6)", :aggregate_failures do
      deck = create(:deck, account:, name: "Alpha")
      create_lot_in_zone(deck, "main", entry: card, quantity: 1)
      get catalog_entry_path(card)
      expect(count_line).to eq("1 copy in 1 deck")

      lone = create(:mtg_printing).entry
      create(:deck_proxy, zone: deck.zone("main"), entry: lone, quantity: 2)
      get catalog_entry_path(lone)
      expect(count_line).to eq("2 proxy")

      get catalog_entry_path(create(:mtg_printing).entry)
      expect(count_line).to be_nil
    end

    it "does not count a deck that holds only a proxy as a deck in the head count (AC-2.6)" do
      copies, proxies = create(:deck, account:, name: "Copies"), create(:deck, account:, name: "Proxies")
      create_lot_in_zone(copies, "main", entry: card, quantity: 1)
      create(:deck_proxy, zone: proxies.zone("main"), entry: card, quantity: 1)
      get catalog_entry_path(card)

      expect(count_line).to eq("1 copy in 1 deck · 1 proxy")
    end

    it "says the card is in no deck, with an Add to deck link that keeps the collection mark (AC-2.7)", :aggregate_failures do
      get catalog_entry_path(card, from: "collection")

      expect(html.css("#in-decks table")).to be_empty
      expect(html.at_css("#in-decks p.c-empty").text.squish).to eq("This card isn't in any of your decks. Add to deck")
      expect(html.at_css("#in-decks p.c-empty a")["href"]).to eq(new_catalog_entry_deck_addition_path(card, from: "collection"))
    end

    it "has no link in the empty state for a retired printing, and is drawn for an account with no decks (AC-2.7)", :aggregate_failures do
      retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
      get catalog_entry_path(retired)

      expect(response).to have_http_status(:ok)
      expect(html.at_css("#in-decks p.c-empty").text.squish).to eq("This card isn't in any of your decks.")
      expect(html.css("#in-decks a")).to be_empty
      expect(account.decks).to be_empty # the account has no deck at all, and the section is still drawn
    end

    it "counts a lot of a retired printing as it counts the others (AC-2.8)", :aggregate_failures do
      retired = create(:mtg_printing, entry: create(:catalog_entry, :retired, identity:)).entry
      deck = create(:deck, account:, name: "Alpha")
      create_lot_in_zone(deck, "main", entry: retired, quantity: 2)
      create(:deck_proxy, zone: deck.zone("main"), entry: retired, quantity: 1)
      get catalog_entry_path(card)

      expect(table_rows).to eq([ [ "Alpha", deck_path(deck), "Main", "2", "1" ] ])
      expect(strip.fetch("In decks")).to eq([ "2", "in 1 deck" ])
    end

    it "shows nothing of another account's deck, zone, lot or proxy (AC-2.9)", :aggregate_failures do
      mine = "Owner Deck #{SecureRandom.hex(4)}" # built at run time, so a literal in the page can't be a coincidence
      deck = create(:deck, account:, name: mine)
      create_lot_in_zone(deck, "main", entry: card, quantity: 1)
      other_user = other_account_deck("Their Deck Name")
      get catalog_entry_path(card)

      expect(table_rows).to eq([ [ mine, deck_path(deck), "Main", "1", "—" ] ]) # the control: the owner's own row is there
      expect(response.body).not_to include("Their Deck Name")

      switch_to(other_user)
      get catalog_entry_path(card)
      expect(response.body).to include("Their Deck Name")
      expect(response.body).not_to include(mine)
    end

    it "shows a renamed deck's new name (AC-2.10)", :aggregate_failures do
      deck = create(:deck, account:, name: "Before")
      create_lot_in_zone(deck, "main", entry: card)
      get catalog_entry_path(card)
      expect(table_rows.first.first).to eq("Before")

      deck.rename("After")
      get catalog_entry_path(card)
      expect(table_rows.first.first).to eq("After")
    end

    it "does not write to lots, locations, decks or deck proxies (AC-3.4)", :aggregate_failures do
      deck = create(:deck, account:)
      create_lot_in_zone(deck, "main", entry: card)
      create(:deck_proxy, zone: deck.zone("main"), entry: card)

      writes = %w[lots locations decks deck_proxies].flat_map { |table| write_statements_to(table) { get catalog_entry_path(card) } }
      expect(writes).to be_empty
      expect(write_statements_to("lots") { create(:lot, account:, entry: card) }).not_to be_empty # the control: the spy sees a write
    end

    it "uses only c- and is- classes and no inline style, and marks the Owned cell numeric (AC-5.3)", :aggregate_failures do
      create_lot_in_zone(create(:deck, account:), "main", entry: card)
      get catalog_entry_path(card)

      expect(html.css("#in-decks [class], dl.c-stats [class]").flat_map { it["class"].split }.uniq).to all(match(/\A(c|is)-/))
      expect(html.css("#in-decks [style], dl.c-stats [style]")).to be_empty
      expect(html.css("#in-decks tbody td")[2]["class"].split).to include("is-num")
    end
  end
end
