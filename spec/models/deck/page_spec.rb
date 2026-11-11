require "rails_helper"

# Spec 066 FR-2, Story 2: one deck's zones, groups, rows and counts, read in a bounded number of statements.
RSpec.describe Deck::Page, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

  def printing(name: "Lightning Bolt", type_line: "Instant", cost: "{R}", set: create(:catalog_set), **attrs)
    entry = create(:catalog_entry, name:, set:, **attrs)
    create(:mtg_printing, entry:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    entry
  end

  def page_of(deck) = described_class.new(Deck.includes(:location).find_by!(location_id: deck.location_id))
  def zone_named(page, name) = page.zones.find { it.name == name }

  describe "#zones" do
    it "lists the zones in the format's order (AC-2.1)" do
      expect(page_of(create(:deck, account:, name: "Krenko", format: "commander")).zones.map(&:name)).to eq(%w[Commander Main Considering])
    end

    it "lists Main, Sideboard, Considering after a change from Commander to Modern added Sideboard last by id (AC-2.2)" do
      commander = create(:deck, account:, name: "Krenko", format: "commander")
      Deck::FormatChange.new(deck: commander, format: "mtg/modern").save!

      expect(page_of(commander).zones.map(&:name)).to eq(%w[Main Sideboard Considering])
    end

    it "puts every zone of an unregistered format in id order (AC-2.1)" do
      deck.update!(format: "retired")

      expect(page_of(deck).zones.map(&:name)).to eq(deck.zones.order(:id).pluck(:name))
    end

    it "has a zone for every zone of the deck, with no rows for an empty one (AC-2.7)", :aggregate_failures do
      zone = zone_named(page_of(deck), "Sideboard")

      expect(zone.empty?).to be(true)
      expect(zone.owned).to eq(0)
    end

    it "sums a printing's lots in the zone whatever the finish, and counts nothing outside it (AC-2.4, AC-2.8)", :aggregate_failures do
      entry = printing
      create_lot_in_zone(deck, "main", entry:, quantity: 2, finish: "foil")
      create_lot_in_zone(deck, "main", entry:, quantity: 1, finish: "nonfoil")
      create_lot_in_zone(deck, "sideboard", entry:, quantity: 5)
      other = create(:deck, account:, name: "Other")
      create_lot_in_zone(other, "main", entry:, quantity: 7)
      create(:lot, account:, entry:, quantity: 9, location: create(:location, account:))
      create(:lot, account:, entry:, quantity: 11)
      create(:lot, entry:, quantity: 13) # another account's lot of the same printing

      page = page_of(deck)

      expect(zone_named(page, "Main").groups.flat_map(&:rows).map(&:owned)).to eq([ 3 ])
      expect(zone_named(page, "Sideboard").owned).to eq(5)
      expect(page.owned).to eq(8)
    end

    it "keeps two printings of one card as two rows (AC-2.4)" do
      set = create(:catalog_set, code: "aaa")
      create_lot_in_zone(deck, "main", entry: printing(set:, number: "1"), quantity: 2)
      create_lot_in_zone(deck, "main", entry: printing(set:, number: "2"), quantity: 1)

      expect(zone_named(page_of(deck), "Main").groups.flat_map(&:rows).map(&:owned)).to eq([ 2, 1 ])
    end

    it "shows a retired printing like any other (AC-2.9)" do
      create_lot_in_zone(deck, "main", entry: printing(retired_at: 1.day.ago), quantity: 1)

      expect(zone_named(page_of(deck), "Main").owned).to eq(1)
    end
  end

  describe "groups and order (AC-2.6)" do
    it "lists groups in the extension's order, none for a group with no cards, with the copies in each", :aggregate_failures do
      create_lot_in_zone(deck, "main", entry: printing(name: "Island", type_line: "Basic Land — Island"), quantity: 20)
      create_lot_in_zone(deck, "main", entry: printing(name: "Murktide Regent", type_line: "Creature — Dragon"), quantity: 2)
      create_lot_in_zone(deck, "main", entry: printing(name: "Lightning Bolt", type_line: "Instant"), quantity: 4)

      groups = zone_named(page_of(deck), "Main").groups

      expect(groups.map(&:name)).to eq(%w[Creatures Instants Lands])
      expect(groups.map(&:owned)).to eq([ 2, 4, 20 ])
    end

    it "orders rows by shown name, set code, number as a person reads it, number text and language", :aggregate_failures do
      aaa = create(:catalog_set, code: "aaa")
      bbb = create(:catalog_set, code: "bbb")
      [
        [ "Bolt", bbb, "1", "en" ], [ "Bolt", aaa, "10", "en" ], [ "Bolt", aaa, "2", "en" ], [ "Bolt", aaa, "★", "en" ],
        [ "Bolt", aaa, "2", "de" ], [ "Abzan", bbb, "9", "en" ]
      ].each do |name, set, number, language|
        entry = printing(name:, set:, number:, language:, localized_name: (language == "en" ? nil : "Blitz"))
        create_lot_in_zone(deck, "main", entry:, quantity: 1)
      end

      rows = zone_named(page_of(deck), "Main").groups.flat_map(&:rows)

      expect(rows.map { [ it.entry.display_name, it.entry.set.code, it.entry.number, it.entry.language ] }).to eq([
        [ "Abzan", "bbb", "9", "en" ], [ "Blitz", "aaa", "2", "de" ], [ "Bolt", "aaa", "2", "en" ], [ "Bolt", "aaa", "10", "en" ],
        [ "Bolt", "aaa", "★", "en" ], [ "Bolt", "bbb", "1", "en" ]
      ])
    end

    it "gives a flat zone, one group with no name, when the type's vocabulary answers nothing (AC-6.1)", :aggregate_failures, :other_collecting do
      other_deck = create(:deck, account:, name: "Other deck", pair: "other/standard")
      entry = create(:catalog_entry, collectible_type: "other", name: "Thing")
      Lot.add!(account:, entry:, location: other_deck.zone("deck"), quantity: 3)

      zone = zone_named(page_of(other_deck), "Deck")

      expect(zone.groups.map(&:name)).to eq([ nil ])
      expect(zone.groups.first.rows.first.answer).to eq(Catalog::DeckCards::NONE)
    end

    it "puts a printing with no extension record in Other with a not-costed answer (AC-6.6)", :aggregate_failures do
      create_lot_in_zone(deck, "main", entry: create(:catalog_entry, name: "Bare"), quantity: 1)

      row = zone_named(page_of(deck), "Main").groups.first.rows.first

      expect([ row.answer.group, row.answer.costed ]).to eq([ "Other", false ])
    end
  end

  describe "statements (AC-2.10)" do
    def seed(zones:, printings:)
      printings.times do |i|
        entry = printing(name: "Card #{i}", type_line: i.even? ? "Creature" : "Instant", number: i.to_s)
        zones.each { |zone| create_lot_in_zone(deck, zone, entry:, quantity: 1 + i, finish: "nonfoil") }
      end
    end

    it "runs 5 statements for a small deck and for a large one alike", :aggregate_failures do
      seed(zones: %w[main], printings: 1)
      small = page_of(deck).then { |page| count_queries { page.zones } } # the deck and its location are read outside the count
      seed(zones: %w[main sideboard considering], printings: 12)
      large = page_of(deck).then { |page| count_queries { page.zones } }

      expect([ small, large ]).to eq([ 5, 5 ]) # the zones, the copies, the entries, their sets, the one extension read
    end
  end
end
