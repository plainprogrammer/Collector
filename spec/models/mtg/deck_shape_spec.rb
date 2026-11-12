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
    end

    it "counts Commander and Main together, in the deck's zone order, and not Considering", :aggregate_failures do
      krenko = create(:deck, account:, name: "Krenko", format: "commander")
      own(card, 1, zone: "commander", in_deck: krenko)
      own(card, 99, zone: "main", in_deck: krenko)
      own(card(type_line: "Sorcery", cost: "{G}", mana_value: 7.0), 3, zone: "considering", in_deck: krenko) # a type, a colour and a value the counted zones lack

      figures = shape(krenko)

      expect(figures.scope).to eq("Commander + Main · 100 cards")
      expect(figures.types.map(&:name)).to eq([ "Instants" ])
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
end
