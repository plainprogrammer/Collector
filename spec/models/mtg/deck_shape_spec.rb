require "rails_helper"

# Spec 069: the figures of the deck shape panel, from a deck page's zones.
RSpec.describe MTG::DeckShape, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  # A printing with a face, and its card's mana value (pass `mana_value: nil` for a card with none yet).
  def card(name: "Card #{SecureRandom.hex(3)}", type_line: "Instant", cost: "{R}", mana_value: 1.0, faces: nil)
    entry = create(:catalog_entry, name:)
    faces ||= [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ]
    create(:mtg_printing, entry:, faces:)
    create(:mtg_card, identity: entry.identity, mana_value:)
    entry
  end

  def own(entry, quantity = 1, zone: "main", in_deck: deck) = create_lot_in_zone(in_deck, zone, entry:, quantity:)
  def proxy(entry, quantity = 1, zone: "main", in_deck: deck) = create(:deck_proxy, zone: in_deck.zone(zone), account:, entry:, quantity:)
  def zones_of(in_deck = deck) = Deck::Page.new(Deck.includes(:location).find_by!(location_id: in_deck.location_id)).zones
  def shape(in_deck = deck) = described_class.build(zones_of(in_deck))

  describe ".build" do
    it "is nil for a deck with neither a main nor a commander zone" do
      deck.zone("main").destroy! # no lot or proxy in it, so the foreign keys allow it

      expect(shape).to be_nil
    end

    it "counts Main only for a constructed deck, by quantity, and says so in the scope line", :aggregate_failures do
      own(card(mana_value: 1.0), 3)
      proxy(card, 1)
      own(card(mana_value: 7.0, type_line: "Sorcery", cost: "{G}"), 5, zone: "sideboard") # a value, a type and a colour Main lacks
      own(card(mana_value: 7.0, type_line: "Sorcery", cost: "{G}"), 2, zone: "considering")

      figures = shape

      expect(figures.cards).to eq(4)
      expect(figures.scope).to eq("Main · 4 cards")
      expect(figures.types.map(&:name)).to eq([ "Instants" ])
      expect(figures.curve.last.total).to eq(0)
      expect(figures.symbols.map(&:colour)).to eq([ "R" ])
    end

    it "counts Commander and Main together, in the deck's zone order, and not Considering", :aggregate_failures do
      krenko = create(:deck, account:, name: "Krenko", format: "commander")
      own(card, 1, zone: "commander", in_deck: krenko)
      own(card, 99, zone: "main", in_deck: krenko)
      own(card(type_line: "Sorcery", cost: "{G}", mana_value: 7.0), 3, zone: "considering", in_deck: krenko) # a type, a colour and a value the counted zones lack

      figures = shape(krenko)

      expect(figures.scope).to eq("Commander + Main · 100 cards")
      expect(figures.types.map(&:name)).to eq([ "Instants" ])
      expect(figures.curve.last.total).to eq(0)
      expect(figures.symbols.map(&:colour)).to eq([ "R" ])
    end

    it "says '1 card' and '0 cards' and delimits thousands", :aggregate_failures do
      expect(shape.scope).to eq("Main · 0 cards")
      own(card)
      expect(shape.scope).to eq("Main · 1 card")
      own(card, 1_233)
      expect(shape.scope).to eq("Main · 1,234 cards")
    end
  end

  describe "#types" do
    it "lists the groups present in the zone tables' order with the owned plus proxy count and the proxy count (AC-3.1)", :aggregate_failures do
      8.times { |n| n < 2 ? proxy(card(type_line: "Creature — Elf", mana_value: 2.0)) : own(card(type_line: "Creature — Elf", mana_value: 2.0)) }
      own(card(type_line: "Artifact Creature — Golem", mana_value: 3.0))
      own(card(type_line: "Sorcery", mana_value: 3.0))
      own(card(type_line: "Basic Land — Island", cost: "", mana_value: 0.0), 3)
      own(card(faces: [], mana_value: nil))

      types = shape.types

      expect(types.map { [ it.name, it.count, it.proxy ] }).to eq([ [ "Creatures", 9, 2 ], [ "Sorceries", 1, 0 ], [ "Lands", 3, 0 ], [ "Other", 1, 0 ] ])
      expect(types.sum(&:count)).to eq(shape.cards)
    end

    it "groups as the zone tables do: Dryad Arbor, an Artifact Land, a Kindred Instant, a Planeswalker (AC-3.3)" do
      { "Land Creature — Forest Dryad" => "Creatures", "Artifact Land" => "Lands", "Kindred Instant — Elf" => "Instants",
        "Legendary Planeswalker — Jace" => "Planeswalkers" }.each_key { own(card(type_line: it)) }

      expect(shape.types.map(&:name)).to eq(%w[Creatures Planeswalkers Instants Lands])
    end

    it "counts a proxy of a land under Lands (AC-3.4)" do
      proxy(card(type_line: "Basic Land — Forest", cost: "", mana_value: 0.0))

      expect(shape.types.map { [ it.name, it.count, it.proxy ] }).to eq([ [ "Lands", 1, 1 ] ])
    end

    it "agrees with the zone table's group counts for a Main-only deck (AC-3.2)" do
      own(card(type_line: "Creature — Elf"), 2)
      own(card(type_line: "Land"), 3)
      proxy(card(type_line: "Creature — Elf"), 1)

      page_groups = zones_of.find { it.name == "Main" }.groups.to_h { [ it.name, it.total ] }

      expect(shape.types.to_h { [ it.name, it.count ] }).to eq(page_groups)
    end

    it "skips a row of another collectible, in every part and in the scope (AC-3.5)", :aggregate_failures do
      own(card(type_line: "Creature — Elf"), 2)
      stranger = create(:catalog_entry, collectible_type: "stranger") # the page's answer for it is NONE: no position
      create_lot_in_zone(deck, "main", entry: stranger, quantity: 4)

      expect(shape.cards).to eq(2)
      expect(shape.types.sum(&:count)).to eq(2)
    end
  end

  describe "#curve" do
    it "buckets Bolt, Elves, Counterspell and a Forest as AC-2.1 says", :aggregate_failures do
      bolt = card(name: "Lightning Bolt", mana_value: 1.0)
      own(bolt, 3)
      proxy(bolt, 1)
      own(card(name: "Llanowar Elves", type_line: "Creature — Elf", mana_value: 1.0), 2)
      proxy(card(name: "Counterspell", mana_value: 2.0), 2)
      own(card(name: "Forest", type_line: "Basic Land — Forest", cost: "", mana_value: 0.0), 4)

      figures = shape

      expect(figures.curve.map { [ it.owned, it.proxy ] }).to eq([ [ 0, 0 ], [ 5, 1 ], [ 0, 2 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ] ])
      expect([ figures.curve_owned, figures.curve_proxy, figures.curve_max ]).to eq([ 5, 3, 6 ])
      expect(figures.average_text).to eq("1.3") # (6 × 1 + 2 × 2) ÷ 8 = 1.25, half up
    end

    it "puts 0, 5, 6, 7, 9 and 1,000,000 in columns 0, 5, 6+, 6+, 6+, 6+ (AC-2.2)" do
      [ 0.0, 5.0, 6.0, 7.0, 9.0, 1_000_000.0 ].each { own(card(mana_value: it)) }

      expect(shape.curve.map(&:total)).to eq([ 1, 0, 0, 0, 0, 1, 4 ])
    end

    it "floors a half value into the whole number below it: 0.5, 2.5, 6.5 (AC-2.3)" do
      [ 0.5, 2.5, 6.5 ].each { own(card(mana_value: it)) }

      expect(shape.curve.map(&:total)).to eq([ 1, 0, 1, 0, 0, 0, 1 ])
    end

    it "leaves lands out and keeps Dryad Arbor in column 0 (AC-2.6)", :aggregate_failures do
      own(card(type_line: "Land Creature — Forest Dryad", cost: "", mana_value: 0.0)) # Dryad Arbor: a Creature, mana value 0
      own(card(type_line: "Artifact Land", cost: "", mana_value: 0.0))
      own(card(type_line: "Basic Land — Island", cost: "", mana_value: 0.0))

      expect(shape.curve.map(&:total)).to eq([ 1, 0, 0, 0, 0, 0, 0 ])
      expect(shape.curve_owned).to eq(1)
    end

    it "uses the card's stored value for a double-faced and a reversible card, and keeps a Sorcery // Land in the curve (AC-2.7)", :aggregate_failures do
      own(card(mana_value: 2.0, faces: [ { "name" => "A", "type_line" => "Creature — Human", "mana_cost" => "{1}{U}" },
                                         { "name" => "B", "type_line" => "Land", "mana_cost" => "" } ])) # transform: front Creature, back Land
      own(card(mana_value: 4.0, faces: [ { "name" => "Ajani", "type_line" => "Legendary Planeswalker — Ajani", "mana_cost" => "{2}{W}{W}" },
                                         { "name" => "Ajani", "type_line" => "Legendary Planeswalker — Ajani", "mana_cost" => "{2}{W}{W}" } ])) # reversible: stored value 4
      own(card(mana_value: 3.0, faces: [ { "name" => "C", "type_line" => "Sorcery", "mana_cost" => "{2}{B}" }, { "name" => "D", "type_line" => "Land", "mana_cost" => "" } ]))

      expect(shape.curve.map(&:total)).to eq([ 0, 0, 1, 1, 1, 0, 0 ])
      expect(shape.types.map { [ it.name, it.count ] }).to eq([ [ "Creatures", 1 ], [ "Planeswalkers", 1 ], [ "Sorceries", 1 ] ]) # by the front face's type
    end

    it "leaves a nonland card with no mana value out and counts it for the note (AC-2.5)", :aggregate_failures do
      own(card(mana_value: 3.0))
      own(card(mana_value: nil))

      expect(shape.curve.map(&:total)).to eq([ 0, 0, 0, 1, 0, 0, 0 ])
      expect(shape.unvalued).to eq(1)
      expect(shape.types.sum(&:count)).to eq(2)
      expect(shape.unvalued_note).to eq("1 nonland card has no mana value yet.")
    end

    it "words the note for several cards, and has none for a mana value of 0.0 (AC-2.5)", :aggregate_failures do
      3.times { own(card(mana_value: nil)) }
      expect(shape.unvalued_note).to eq("3 nonland cards have no mana value yet.")

      other = create(:deck, account:, name: "Zero")
      own(card(type_line: "Artifact", cost: "{0}", mana_value: 0.0), 1, in_deck: other)
      expect(shape(other).unvalued_note).to be_nil
      expect(shape(other).curve.first.total).to eq(1)
    end

    it "counts an entry with no MTG::Card row as having no mana value" do
      entry = create(:catalog_entry)
      create(:mtg_printing, entry:)
      own(entry)

      expect(shape.unvalued).to eq(1)
    end
  end

  describe "#average_text" do
    it "is the exact mean, 2.625 shown 2.6 (AC-2.4)" do
      [ 0.5, 2.5, 6.5, 1.0 ].each { own(card(mana_value: it)) }

      expect(shape.average_text).to eq("2.6")
    end

    it "keeps a trailing zero: a mean of 3 is 3.0 (AC-2.4)" do
      own(card(mana_value: 3.0), 4)

      expect(shape.average_text).to eq("3.0")
    end

    it "rounds 0.15 up with exact arithmetic, not down as a float would (AC-2.4)" do
      own(card(mana_value: 0.5), 3)
      own(card(mana_value: 0.0), 7)

      expect(shape.average_text).to eq("0.2")
    end

    it "is nil with no card in the curve, and delimits a long number (AC-1.5)", :aggregate_failures do
      expect(shape.average_text).to be_nil
      own(card(mana_value: 1_000_000.0))
      expect(shape.average_text).to eq("1,000,000.0")
    end
  end

  describe "statements" do
    it "runs one statement for the mana values however many cards, and none for an empty deck (AC-6.1)", :aggregate_failures do
      page_zones = zones_of
      expect(count_queries { described_class.build(page_zones).curve }).to eq(0)

      10.times { own(card) }
      page_zones = zones_of
      expect(count_queries { described_class.build(page_zones).curve }).to eq(1)

      30.times { own(card) }
      page_zones = zones_of
      expect(count_queries { described_class.build(page_zones).curve }).to eq(1)
    end

    it "reads the mana values once for the curve, the average and the note (AC-6.3)" do
      own(card)
      figures = described_class.build(zones_of)

      expect(count_queries { figures.curve; figures.average_text; figures.unvalued; figures.curve_max }).to eq(1)
    end
  end

  describe "#symbols" do
    def counts(figures = shape) = figures.symbols.to_h { [ it.colour, it.count ] }

    it "counts by colour, times the card's count, W U B R G order (AC-4.1)", :aggregate_failures do
      own(card(cost: "{U}{U}"), 2)
      own(card(cost: "{R}"), 1)
      proxy(card(cost: "{R}"), 1)
      proxy(card(cost: "{2}{W}{W}", type_line: "Sorcery"), 1)

      figures = shape

      expect(figures.symbols.map { [ it.colour, it.count, it.percent ] }).to eq([ [ "W", 2, 25 ], [ "U", 4, 50 ], [ "R", 2, 25 ] ])
      expect(figures.caption).to eq("White 2 · 25% · Blue 4 · 50% · Red 2 · 25%")
      expect(figures.symbols_label).to eq("Coloured mana symbols in Main: white 2, blue 4, red 2")
    end

    it "counts a hybrid symbol toward each colour (AC-4.2)" do
      own(card(cost: "{W/U}{W/U}"), 2)
      own(card(cost: "{R/G}"))

      expect(counts).to eq("W" => 4, "U" => 4, "R" => 1, "G" => 1)
    end

    it "counts a Phyrexian symbol toward its colour, a Phyrexian hybrid toward both, and {2/W} and {C/W} toward W only (AC-4.3)" do
      own(card(cost: "{2}{G/P}"))
      own(card(cost: "{G/W/P}"))
      own(card(cost: "{2/W}"))
      own(card(cost: "{C/W}"))

      expect(counts).to eq("W" => 3, "G" => 2)
    end

    it "never counts generic, X, colourless, snow or half symbols (AC-4.4)", :aggregate_failures do
      own(card(cost: "{3}{X}{C}{S}{G}"))
      own(card(name: "Little Girl", cost: "{HW}", mana_value: 0.5))

      expect(counts).to eq("G" => 1)
      expect(shape.symbols.sum(&:count)).to eq(1)
      expect(shape.curve.first.total).to eq(1) # the {HW} card is still in the curve, at its mana value
    end

    it "reads only the first face of a double-faced and a split card (AC-4.5)" do
      own(card(faces: [ { "name" => "A", "type_line" => "Creature", "mana_cost" => "{1}{U}" }, { "name" => "B", "type_line" => "Land", "mana_cost" => "{3}{R}" } ]))
      own(card(faces: [ { "name" => "Fire", "type_line" => "Instant", "mana_cost" => "{1}{R}" }, { "name" => "Ice", "type_line" => "Instant", "mana_cost" => "{1}{U}" } ]))

      expect(counts).to eq("U" => 1, "R" => 1)
    end

    it "marks a segment under 10% narrow and not one of exactly 10% (AC-4.6)", :aggregate_failures do
      own(card(cost: "{W}"), 5)
      own(card(cost: "{U}"), 95)
      expect(shape.symbols.map { [ it.colour, it.narrow ] }).to eq([ [ "W", true ], [ "U", false ] ])
      expect(shape.caption).to eq("White 5 · 5% · Blue 95 · 95%")

      other = create(:deck, account:, name: "Ten")
      own(card(cost: "{W}"), 10, in_deck: other)
      own(card(cost: "{U}"), 90, in_deck: other)
      expect(shape(other).symbols.first.narrow).to be(false)
    end

    it "rounds each percentage on its own, half up and exactly (AC-4.7)", :aggregate_failures do
      own(card(cost: "{W}{U}{B}"))
      expect(shape.symbols.map(&:percent)).to eq([ 33, 33, 33 ])

      other = create(:deck, account:, name: "Eighths")
      own(card(cost: "{W}"), 1, in_deck: other)
      own(card(cost: "{U}"), 7, in_deck: other)
      expect(shape(other).symbols.map(&:percent)).to eq([ 13, 88 ]) # 12.5 and 87.5, each half up
    end

    it "has no segment and no caption for a deck of generic costs (AC-4.8)", :aggregate_failures do
      own(card(type_line: "Artifact", cost: "{3}", mana_value: 3.0), 4)

      expect(shape.symbols).to eq([])
      expect(shape.caption).to be_nil
    end

    it "does not count Sideboard or Considering symbols (AC-4.10)" do
      own(card(cost: "{U}"))
      own(card(cost: "{G}{G}"), 3, zone: "sideboard")
      own(card(cost: "{G}"), 3, zone: "considering")

      expect(counts).to eq("U" => 1)
    end

    it "reads a nil, blank or malformed cost as nothing and raises nothing" do
      own(card(cost: nil))
      own(card(cost: ""))
      own(card(cost: "{W"))
      own(card(faces: [ { "name" => "Bare" } ]))

      expect(shape.symbols).to eq([])
    end
  end

  describe "texts" do
    it "reads the curve for a screen reader: each column with cards, the owned and proxy split, then the average (AC-2.9)" do
      own(card(mana_value: 1.0), 11)
      proxy(card(mana_value: 1.0), 1)
      own(card(mana_value: 6.0), 2)

      expect(shape.curve_label).to eq("Mana curve of the 14 nonland cards in Main: mana value 1, 12 cards (11 owned, 1 proxy); 6+, 2 cards (2 owned). Average mana value 1.7.")
      # (12 × 1 + 2 × 6) ÷ 14 = 1.714…
    end

    it "says '1 nonland card' and, for none, 'no cards' (AC-1.5)", :aggregate_failures do
      expect(shape.curve_label).to eq("Mana curve of the 0 nonland cards in Main: no cards.")
      own(card(mana_value: 2.0))
      expect(shape.curve_label).to eq("Mana curve of the 1 nonland card in Main: mana value 2, 1 card (1 owned). Average mana value 2.0.")
    end

    it "builds the fold's facts: the scope, then the average when there is one", :aggregate_failures do
      expect(shape.facts).to eq("Main · 0 cards")
      own(card(mana_value: 3.0), 2)
      expect(shape.facts).to eq("Main · 2 cards · average mana value 3.0")
    end

    it "reads the symbols label for the scope (AC-4.9)" do
      krenko = create(:deck, account:, name: "Krenko", format: "commander")
      own(card(cost: "{R}"), 1, zone: "commander", in_deck: krenko)

      expect(shape(krenko).symbols_label).to eq("Coloured mana symbols in Commander + Main: red 1")
    end
  end
end
