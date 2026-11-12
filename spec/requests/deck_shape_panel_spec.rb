require "rails_helper"

# Spec 069 Stories 1 to 4: the shape panel on the deck page, GET /decks/:id.
RSpec.describe "Deck shape panel", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  def html = Nokogiri::HTML5(response.body)
  def card(name: "Card #{SecureRandom.hex(3)}", type_line: "Instant", cost: "{R}", mana_value: 1.0)
    entry = create(:catalog_entry, name:)
    create(:mtg_printing, entry:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    create(:mtg_card, identity: entry.identity, mana_value:)
    entry
  end
  def own(entry, quantity = 1, zone: "main") = create_lot_in_zone(deck, zone, entry:, quantity:)
  def proxy(entry, quantity = 1, zone: "main") = create(:deck_proxy, zone: deck.zone(zone), account:, entry:, quantity:)

  before { sign_in_as(user) }

  describe "the two copies (Story 1)" do
    # Bolt (owned 3), Counterspell (owned 1, proxy 2: one column holding both) and two Forests: 8 cards, 6 in the curve.
    before do
      own(card(name: "Lightning Bolt"), 3)
      counterspell = card(name: "Counterspell", cost: "{U}{U}", mana_value: 2.0)
      own(counterspell, 1)
      proxy(counterspell, 2)
      own(card(name: "Forest", type_line: "Basic Land — Forest", cost: "", mana_value: 0.0), 2)
      get deck_path(deck)
    end

    it "puts the details copy, the aside copy and the zones inside c-deck, in that order (AC-1.1)", :aggregate_failures do
      expect(html.css(".c-deck > *").map { it["class"] }).to eq([ "c-shapefold", "c-deck__shape", "c-deck__zones" ])
      aside = html.at_css("aside.c-deck__shape")
      expect(aside.at_css("section.c-shape h2.c-shape__title").text).to eq("Deck shape")
      expect(aside.at_css(".c-shape__scope").text).to eq("Main · 8 cards")
      summary = html.at_css("details.c-shapefold summary")
      expect(summary.at_css(".c-shapefold__title").text).to eq("Deck shape")
      expect(summary.at_css(".c-shapefold__facts").text).to eq("Main · 8 cards · average mana value 1.5")
      expect(html.at_css("details.c-shapefold")["open"]).to be_nil
    end

    it "has the three parts in order in each copy (AC-1.1)" do
      %w[aside.c-deck__shape details.c-shapefold].each do |copy|
        expect(html.css("#{copy} h3.c-shape__heading").map(&:text)).to eq([ "Mana curve", "Card types", "Mana symbols" ])
      end
    end

    it "gives no id twice, no root id, and labels the aside by its own title (AC-1.2)", :aggregate_failures do
      ids = html.css("[id]").map { it["id"] }
      expect(ids.tally.select { |_id, n| n > 1 }).to eq({})
      expect(html.at_css("section.c-shape")["id"]).to be_nil
      expect(html.at_css("section.c-shape")["aria-labelledby"]).to eq(html.at_css("h2.c-shape__title")["id"])
    end

    it "reads each chart for a screen reader once per copy and hides the columns (AC-2.9, AC-4.9)", :aggregate_failures do
      aside = html.at_css("aside.c-deck__shape")
      expect(aside.at_css(".c-curve [role=img]")["aria-label"]).to eq(
        "Mana curve of the 6 nonland cards in Main: mana value 1, 3 cards (3 owned); 2, 3 cards (1 owned, 2 proxy). Average mana value 1.5."
      )
      expect(aside.at_css(".c-curve__cols")["aria-hidden"]).to eq("true")
      expect(aside.at_css(".c-manabar")["aria-label"]).to eq("Coloured mana symbols in Main: blue 6, red 3")
    end

    it "draws a column with the proxy part above the owned part, numbers only in style, a part of zero having no element (AC-2.9, AC-2.10)", :aggregate_failures do
      cols = html.css("aside .c-curve__col")
      expect(cols.size).to eq(7)
      expect(cols[1].css(".c-curve__bar > *").map { [ it["class"], it["style"] ] }).to eq([ [ "c-curve__owned", "--owned:3;--max:3" ] ])
      expect(cols[2].css(".c-curve__bar > *").map { [ it["class"], it["style"] ] }).to eq(
        [ [ "c-curve__proxy", "--proxy:2;--max:3" ], [ "c-curve__owned", "--owned:1;--max:3" ] ] # the proxy part first: it sits on top
      )
      expect(html.css("aside [style]").map { it["style"] }).to all(match(/\A(--\w+:\d+;?)+\z/)) # no colour in a style attribute
      expect(html.css("aside .c-curve__legend li").map(&:text)).to eq([ "Owned 4", "Proxy 2" ])
      expect(html.at_css("aside .c-curve__avg").text.strip).to eq("Average mana value 1.5")
    end

    it "lists the types with the proxy suffix, empty where a row has none, and the symbol segments with their letters (AC-3.1, AC-4.1)", :aggregate_failures do
      expect(html.css("aside .c-types li").map { |li| li.css("span").map(&:text) }).to eq([ [ "Instants", "6", "2 proxy" ], [ "Lands", "2", "" ] ])
      expect(html.css("aside .c-manabar__seg").map { [ it["class"], it["style"], it.text ] }).to eq(
        [ [ "c-manabar__seg c-manabar__seg--u", "--n:6", "U 6" ], [ "c-manabar__seg c-manabar__seg--r", "--n:3", "R 3" ] ]
      )
      expect(html.at_css("aside .c-manacap").text).to eq("Blue 6 · 67% · Red 3 · 33%")
    end
  end

  it "marks a segment under 10% of the symbols narrow in the page (AC-4.6)", :aggregate_failures do
    own(card(cost: "{W}"), 1)
    own(card(cost: "{U}"), 19)
    get deck_path(deck)

    segments = html.css("aside .c-manabar__seg").to_h { [ it["class"][/seg--(\w+)/, 1], it["class"].include?("c-manabar__seg--narrow") ] }
    expect(segments).to eq({ "w" => true, "u" => false })
    expect(html.at_css("aside .c-manacap").text).to eq("White 1 · 5% · Blue 19 · 95%")
  end

  it "skips a card of another collectible in the panel and shows its row flat in the zone table (AC-3.5)", :aggregate_failures, :other_collecting do
    own(card, 2)
    stranger = create(:catalog_entry, collectible_type: "other", name: "Foreign card")
    create_lot_in_zone(deck, "main", entry: stranger, quantity: 4)
    get deck_path(deck)

    expect(html.at_css("aside .c-shape__scope").text).to eq("Main · 2 cards")
    expect(html.css("aside .c-types li").map { |li| li.css("span").first.text }).to eq([ "Instants" ])
    expect(html.css("section.c-zone").find { it.at_css("h2").text == "Main" }.text).to include("Foreign card")
  end

  it "shows the empty states of a Casual deck with no card (AC-1.5)", :aggregate_failures do
    get deck_path(create(:deck, account:, name: "Empty casual", format: "casual"))

    aside = html.at_css("aside.c-deck__shape")
    expect(aside.at_css(".c-shape__scope").text).to eq("Main · 0 cards")
    expect(aside.css(".c-curve__count").map(&:text)).to eq(%w[0] * 7)
    expect(aside.css(".c-curve__owned, .c-curve__proxy")).to be_empty
    expect(aside.css(".c-curve__legend li").map(&:text)).to eq([ "Owned 0", "Proxy 0" ])
    expect(aside.css(".c-curve__avg")).to be_empty
    expect(aside.at_css(".c-types, .c-types li")).to be_nil
    expect(aside.text).to include("No cards yet.", "No coloured mana symbols.")
    expect(aside.at_css(".c-manabar")).to be_nil
  end

  it "notes the nonland cards with no mana value after the average line (AC-2.5)", :aggregate_failures do
    own(card(mana_value: 2.0))
    own(card(mana_value: nil), 2)
    get deck_path(deck)

    notes = html.css("aside .c-curve__avg").map { it.text.squish }
    expect(notes).to eq([ "Average mana value 2.0", "2 nonland cards have no mana value yet." ])
  end

  it "keeps the panel for a format the instance no longer registers (AC-1.8)", :aggregate_failures do
    own(card, 2)
    deck.update!(format: "retired") # a stored key the registry lacks, as deck_pages_spec.rb does
    get deck_path(deck)

    expect(html.at_css("aside .c-shape__scope").text).to eq("Main · 2 cards")
  end

  it "draws no panel for a deck with neither a main nor a commander zone row (AC-1.4)", :aggregate_failures do
    deck.zone("main").destroy!
    get deck_path(deck)

    expect(response).to have_http_status(:ok)
    expect(html.css("aside.c-deck__shape, details.c-shapefold")).to be_empty
    expect(html.css(".c-deck > *").map { it["class"] }).to eq([ "c-deck__zones" ])
  end

  it "draws no panel for a collectible whose vocabulary answers none (AC-1.4)", :aggregate_failures, :other_collecting do
    other = create(:deck, account:, name: "Other deck", pair: "other/standard")
    get deck_path(other)

    expect(response).to have_http_status(:ok)
    expect(html.css("aside.c-deck__shape, details.c-shapefold")).to be_empty
  end

  it "draws no panel for a deck of a type no longer registered, and still answers 200 (AC-1.4)", :aggregate_failures do
    own(card)
    deck.update!(collectible_type: "gone") # the fixture deck_pages_spec.rb uses for a type the instance no longer has
    get deck_path(deck)

    expect(response).to have_http_status(:ok)
    expect(html.css("aside.c-deck__shape, details.c-shapefold")).to be_empty
  end

  it "is a 404 for another account's deck and shows none of its figures (AC-1.6)" do
    rival = create(:deck, account: create(:user).account, name: "Rival #{SecureRandom.hex(4)}")
    create_lot_in_zone(rival, "main", entry: card, quantity: 3)

    get deck_path(rival)

    expect(response).to have_http_status(:not_found)
  end
end
