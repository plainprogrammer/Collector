require "rails_helper"

RSpec.describe "Catalog::DeckChecks for a Magic deck", type: :model do
  let(:account) { create(:user).account }

  def deck_of(format) = create(:deck, account:, format:, name: "Deck #{format}")

  def card(name, type_line: "Instant", text: nil, legalities: {}, identity: create(:catalog_identity, name:), **attributes)
    entry = create(:catalog_entry, identity:, name:, **attributes)
    create(:mtg_printing, entry:, legalities:, faces: [ { "name" => name, "type_line" => type_line, "oracle_text" => text, "image_uris" => {} } ])
    entry
  end

  def land(name = "Plains") = card(name, type_line: "Basic Land — #{name}")
  def own(deck, zone, entry, quantity) = create_lot_in_zone(deck, zone, entry:, quantity:)
  def proxy(deck, zone, entry, quantity = 1) = create(:deck_proxy, zone: deck.zone(zone), account:, entry:, finish: "nonfoil", quantity:)

  def lines(deck)
    page = Deck::Page.new(Deck.includes(:location).find_by!(location_id: deck.location_id))
    Catalog::DeckChecks.report("mtg", deck.format, page.zones).lines.map { [ it.status, it.sentence ] }
  end

  it "judges Main and Sideboard in each constructed format's own name", :aggregate_failures do
    %w[standard pioneer modern legacy vintage pauper].each do |key|
      deck = deck_of(key)
      own(deck, "main", land, 58)
      own(deck, "sideboard", land("Island"), 16)
      expect(lines(deck)).to include([ "Short", "Main: 58 cards; #{key.titleize} needs at least 60." ], [ "Over", "Sideboard: 16 cards; #{key.titleize} allows at most 15." ])
    end
  end

  it "counts a proxy toward Main and passes at 60 and at 15", :aggregate_failures do
    deck = deck_of("standard")
    own(deck, "main", land, 59)
    proxy(deck, "main", land("Island"))
    own(deck, "sideboard", land("Swamp"), 15)
    expect(lines(deck)).to include([ "Pass", "Main: 60 cards; Standard needs at least 60." ], [ "Pass", "Sideboard: 15 cards; Standard allows at most 15." ])
  end

  it "judges Commander's two zones together", :aggregate_failures do
    deck = deck_of("commander")
    own(deck, "commander", card("Krenko"), 1)
    own(deck, "main", land, 98)
    expect(lines(deck)).to include([ "Short", "Commander + Main: 99 cards; Commander needs exactly 100." ])
    own(deck, "main", land("Island"), 2)
    expect(lines(deck)).to include([ "Over", "Commander + Main: 101 cards; Commander needs exactly 100." ])
  end

  it "says Casual and an unregistered format have no rules but still flag a forgotten proxy", :aggregate_failures do
    deck = deck_of("casual")
    bolt = card("Lightning Bolt")
    own(deck, "main", bolt, 2)
    proxy(deck, "main", bolt)
    expect(lines(deck)).to eq([ [ nil, "Casual has no rules to check." ], [ "Owned and proxy", "Lightning Bolt in Main: 2 owned, 1 proxy." ] ])
    deck.update!(format: "retired")
    expect(lines(deck).first).to eq([ nil, "retired has no rules to check." ])
  end

  it "adds a card's copies across printings, zones, owned and proxy", :aggregate_failures do
    deck = deck_of("standard")
    bolt = create(:catalog_identity, name: "Lightning Bolt")
    one = card("Lightning Bolt", identity: bolt)
    two = card("Lightning Bolt", identity: bolt, set: create(:catalog_set))
    own(deck, "main", one, 3)
    own(deck, "sideboard", two, 1)
    proxy(deck, "main", two)
    expect(lines(deck)).to include([ "Over the limit", "Lightning Bolt: 5 copies; the limit is 4." ])
  end

  it "names a card by its English name when its first row in page order is a Japanese printing", :aggregate_failures do
    deck = deck_of("standard") # Main is read before Sideboard, and the Japanese printing is the only row of Main
    bolt = create(:catalog_identity, name: "Lightning Bolt")
    own(deck, "main", card("Lightning Bolt", identity: bolt, language: "ja", localized_name: "稲妻"), 3)
    own(deck, "sideboard", card("Lightning Bolt", identity: bolt, set: create(:catalog_set)), 2)
    expect(lines(deck)).to include([ "Over the limit", "Lightning Bolt: 5 copies; the limit is 4." ])
    expect(lines(deck).map(&:last)).not_to include(a_string_matching(/稲妻/))
  end

  it "names a Sideboard the deck has no zone row for from the registration (AC-2.12)" do
    deck = deck_of("standard")
    deck.zone("sideboard").destroy!
    expect(lines(deck)).to include([ "Pass", "Sideboard: 0 cards; Standard allows at most 15." ])
  end

  it "passes Commander at exactly 100 while cards in Considering count nowhere (AC-2.4, 2.5)" do
    commander = deck_of("commander")
    own(commander, "commander", card("Krenko"), 1)
    own(commander, "main", land, 99)
    own(commander, "considering", land("Island"), 30)
    expect(lines(commander)).to include([ "Pass", "Commander + Main: 100 cards; Commander needs exactly 100." ])
  end

  it "exempts basic lands and any-number cards, and holds Commander to one of the rest", :aggregate_failures do
    standard = deck_of("standard")
    own(standard, "main", land, 20)
    rats = card("Relentless Rats", type_line: "Creature — Rat", text: "A deck can have any number of cards named Relentless Rats.")
    own(standard, "main", rats, 9)
    expect(lines(standard)).to include([ "Pass", "No card is over its limit." ])
    commander = deck_of("commander")
    krenko = create(:catalog_identity, name: "Krenko")
    own(commander, "commander", card("Krenko", identity: krenko), 1)
    own(commander, "main", card("Krenko", identity: krenko, set: create(:catalog_set)), 1)
    own(commander, "main", card("Snow-Covered Island", type_line: "Basic Snow Land — Island"), 2)
    expect(lines(commander)).to include([ "Over the limit", "Krenko: 2 copies; the limit is 1." ])
    expect(lines(commander).map(&:last)).not_to include(a_string_matching(/Snow-Covered/))
  end

  it "holds a numbered card to its number in every format, and passes at that number", :aggregate_failures do
    text = "A deck can have up to seven cards named Seven Dwarves."
    %w[standard commander].each do |key|
      over = deck_of(key)
      own(over, "main", card("Seven Dwarves", type_line: "Creature — Dwarf", text:), 8)
      expect(lines(over)).to include([ "Over the limit", "Seven Dwarves: 8 copies; the limit is 7." ])
      exact = create(:deck, account:, format: key, name: "Exact #{key}")
      own(exact, "main", card("Seven Dwarves", type_line: "Creature — Dwarf", text:), 7)
      expect(lines(exact)).to include([ "Pass", "No card is over its limit." ])
    end
  end

  it "restricts a card to one in Vintage only", :aggregate_failures do
    legalities = { "vintage" => "restricted" }
    vintage = deck_of("vintage")
    own(vintage, "main", card("Black Lotus", type_line: "Artifact", legalities:), 2)
    expect(lines(vintage)).to include([ "Over the limit", "Black Lotus: 2 copies; restricted to 1." ])
    legacy = deck_of("legacy")
    own(legacy, "main", card("Black Lotus", type_line: "Artifact", legalities:), 2)
    expect(lines(legacy)).to include([ "Pass", "No card is over its limit." ])
  end

  it "counts a basic land's two printings, one with no card data, at the ordinary limit (AC-3.14, 3.16)", :aggregate_failures do
    deck = deck_of("standard")
    identity = create(:catalog_identity, name: "Plains")
    own(deck, "main", card("Plains", type_line: "Basic Land — Plains", identity:), 1)
    own(deck, "main", create(:catalog_entry, identity:, name: "Plains", set: create(:catalog_set)), 4)
    expect(lines(deck)).to include([ "Over the limit", "Plains: 5 copies; the limit is 4." ])
  end

  it "leaves out another collectible's cards", :aggregate_failures do
    deck = deck_of("standard")
    own(deck, "main", create(:catalog_entry, collectible_type: "stranger", name: "Odd"), 70)
    expect(lines(deck)).to include([ "Short", "Main: 0 cards; Standard needs at least 60." ], [ "Pass", "No card is over its limit." ])
  end

  it "is Short at a 59-card Main in Pauper, Pioneer, Legacy and Vintage, each in its own name (AC-2.8)", :aggregate_failures do
    %w[pauper pioneer legacy vintage].each do |key|
      deck = deck_of(key)
      own(deck, "main", land, 59)
      expect(lines(deck)).to include([ "Short", "Main: 59 cards; #{key.titleize} needs at least 60." ])
    end
  end

  it "judges a Modern Sideboard Over at 16 and passes it at 15 and at none (AC-2.3)", :aggregate_failures do
    empty = deck_of("modern")
    expect(lines(empty)).to include([ "Pass", "Sideboard: 0 cards; Modern allows at most 15." ])
    over = create(:deck, account:, format: "modern", name: "Over modern")
    own(over, "sideboard", land, 16)
    expect(lines(over)).to include([ "Over", "Sideboard: 16 cards; Modern allows at most 15." ])
    exact = create(:deck, account:, format: "modern", name: "Exact modern")
    own(exact, "sideboard", land, 15)
    expect(lines(exact)).to include([ "Pass", "Sideboard: 15 cards; Modern allows at most 15." ])
  end

  it "counts a Modern deck's Main and Sideboard together: 3 + 2 is over, 3 + 1 passes (AC-3.2)", :aggregate_failures do
    over = deck_of("modern")
    bolt = card("Lightning Bolt")
    own(over, "main", bolt, 3)
    own(over, "sideboard", bolt, 2)
    expect(lines(over)).to include([ "Over the limit", "Lightning Bolt: 5 copies; the limit is 4." ])
    at_limit = create(:deck, account:, format: "modern", name: "At the limit")
    own(at_limit, "main", bolt, 3)
    own(at_limit, "sideboard", bolt, 1)
    expect(lines(at_limit)).to include([ "Pass", "No card is over its limit." ])
  end

  it "counts a Legacy deck's 4 of one printing and 1 of another as 5 copies (AC-3.3)" do
    deck = deck_of("legacy")
    bolt = create(:catalog_identity, name: "Lightning Bolt")
    own(deck, "main", card("Lightning Bolt", identity: bolt), 4)
    own(deck, "main", card("Lightning Bolt", identity: bolt, set: create(:catalog_set)), 1)
    expect(lines(deck)).to include([ "Over the limit", "Lightning Bolt: 5 copies; the limit is 4." ])
  end

  it "counts a Legacy deck's 3 owned and 2 proxy of one printing as 5 copies (AC-3.3)" do
    deck = deck_of("legacy")
    bolt = card("Lightning Bolt")
    own(deck, "main", bolt, 3)
    proxy(deck, "main", bolt, 2)
    expect(lines(deck)).to include([ "Over the limit", "Lightning Bolt: 5 copies; the limit is 4." ])
  end

  it "holds 5 copies of a printing with no card data in Standard to the ordinary limit (AC-3.14)" do
    deck = deck_of("standard")
    own(deck, "main", create(:catalog_entry, name: "Lightning Bolt"), 5)
    expect(lines(deck)).to include([ "Over the limit", "Lightning Bolt: 5 copies; the limit is 4." ])
  end

  it "holds a Commander deck's basic land with no card data to one copy (AC-3.14)" do
    deck = deck_of("commander")
    plains = create(:catalog_entry, name: "Plains")
    own(deck, "commander", plains, 1)
    own(deck, "main", plains, 1)
    expect(lines(deck)).to include([ "Over the limit", "Plains: 2 copies; the limit is 1." ])
  end

  it "gives a card in 5 copies in Main and 5 in Sideboard exactly one finding of 10 (AC-3.15)", :aggregate_failures do
    deck = deck_of("standard")
    bolt = create(:catalog_identity, name: "Lightning Bolt")
    own(deck, "main", card("Lightning Bolt", identity: bolt), 5)
    own(deck, "sideboard", card("Lightning Bolt", identity: bolt, set: create(:catalog_set)), 5)
    over = lines(deck).select { it.first == "Over the limit" }
    expect(over).to eq([ [ "Over the limit", "Lightning Bolt: 10 copies; the limit is 4." ] ])
  end

  it "flags owned and proxy in Considering while no size or copy count includes it (AC-2.11)", :aggregate_failures do
    deck = deck_of("standard")
    bolt = card("Lightning Bolt")
    own(deck, "considering", bolt, 5)
    proxy(deck, "considering", bolt)
    expect(lines(deck)).to include(
      [ "Short", "Main: 0 cards; Standard needs at least 60." ], [ "Pass", "Sideboard: 0 cards; Standard allows at most 15." ],
      [ "Pass", "No card is over its limit." ], [ "Owned and proxy", "Lightning Bolt in Considering: 5 owned, 1 proxy." ]
    )
  end

  it "flags owned and proxy in Main and in Sideboard once each, with that zone's split (AC-4.6)" do
    deck = deck_of("standard")
    bolt = card("Lightning Bolt")
    own(deck, "main", bolt, 2)
    proxy(deck, "main", bolt)
    own(deck, "sideboard", bolt, 1)
    proxy(deck, "sideboard", bolt, 3)
    expect(lines(deck).select { it.first == "Owned and proxy" }).to eq(
      [ [ "Owned and proxy", "Lightning Bolt in Main: 2 owned, 1 proxy." ], [ "Owned and proxy", "Lightning Bolt in Sideboard: 1 owned, 3 proxy." ] ]
    )
  end

  it "does not flag another collectible's owned copy and proxy in a Magic deck's Main (AC-4.9)" do
    deck = deck_of("standard")
    odd = create(:catalog_entry, collectible_type: "stranger", name: "Odd")
    own(deck, "main", odd, 2)
    # Deck::Proxy refuses another collectible's entry, so the fixture skips that validation to reach the check's own guard.
    build(:deck_proxy, zone: deck.zone("main"), account:, entry: odd, finish: "nonfoil", quantity: 1).save!(validate: false)
    expect(lines(deck)).to include([ "Pass", "No card has both owned copies and proxies in one zone." ])
  end
end
