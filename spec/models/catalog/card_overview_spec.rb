require "rails_helper"

RSpec.describe Catalog::CardOverview, type: :model do
  let(:account) { create(:user).account }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

  def printing(released_on, **attributes)
    create(:mtg_printing, entry: create(:catalog_entry, identity:, released_on:, **attributes)).entry
  end

  it "counts copies and printings owned across the whole card", :aggregate_failures do
    a, b = printing(Date.new(2020, 1, 1)), printing(Date.new(2021, 1, 1))
    create(:lot, account:, entry: a, quantity: 3)
    create(:lot, account:, entry: b, quantity: 4, finish: "foil")
    create(:lot, entry: a, quantity: 9) # another account
    overview = described_class.new(account:, entry: a)
    expect([ overview.owned_count, overview.printings_owned, overview.lots.size ]).to eq([ 7, 2, 2 ])
  end

  it "lists the shown printing, then owned ones, then the 10 newest others", :aggregate_failures do
    old = printing(Date.new(1993, 1, 1))
    owned_retired = printing(Date.new(1994, 1, 1), retired_at: 1.day.ago)
    create(:lot, account:, entry: owned_retired)
    newest = (1..12).map { |i| printing(Date.new(2000 + i, 1, 1)) }

    rows = described_class.new(account:, entry: old).rows
    expect(rows.first).to have_attributes(entry: old, shown: true)
    expect(rows.second).to have_attributes(entry: owned_retired, owned: 1)
    expect(rows.drop(2).map(&:entry)).to eq(newest.reverse.first(10))
    expect(described_class.new(account:, entry: old).total_printings).to eq(13)
  end

  context "with printings of the card in one set (#204)" do
    let(:set) { create(:catalog_set, code: "znr") }
    let(:shown) { printing(set.released_on, set:, number: "1") }

    it "lists the owned and the newest printings by collector number, numerically", :aggregate_failures do
      owned = %w[100 12a 2].map { |number| printing(set.released_on, set:, number:) }
      %w[12 10 ★].each { |number| printing(set.released_on, set:, number:) }
      owned.each { |entry| create(:lot, account:, entry:) }

      overview = described_class.new(account:, entry: shown)
      expect(overview.rows.drop(1).map { |row| row.entry.number }).to eq(%w[2 12a 100 10 12 ★])
      expect(overview.lots.map { |lot| lot.entry.number }).to eq(%w[2 12a 100])
    end
  end

  describe "the card's decks (spec 073)" do
    let(:deck_a) { create(:deck, account:, name: "Alpha") }
    let(:deck_b) { create(:deck, account:, name: "Beta") }

    def overview(entry) = described_class.new(account:, entry:)

    it "splits what is owned into in-decks and free, Considering counted as in a deck", :aggregate_failures do
      a, b = printing(Date.new(2020, 1, 1)), printing(Date.new(2021, 1, 1))
      create_lot_in_zone(deck_a, "main", entry: a, quantity: 2)
      create_lot_in_zone(deck_b, "considering", entry: b, quantity: 1)
      create(:lot, account:, entry: a, quantity: 3, location: create(:location, account:)) # in a place: free
      create(:lot, account:, entry: b, quantity: 1) # no location: free
      create(:lot, account:, entry: create(:mtg_printing).entry, quantity: 5, location: deck_a.zone("main")) # another card: not counted

      overview = overview(a)
      expect([ overview.owned_count, overview.in_decks_count, overview.free_count ]).to eq([ 7, 3, 4 ])
      expect(overview.free_count).to eq(Lot::FreeCopies.new(account:, entry: a).total) # the definition, not a copy of it
      expect(overview.deck_lots.map(&:quantity)).to contain_exactly(2, 1)
      expect(overview.uses.deck_count).to eq(2)
    end

    it "never counts a proxy as owned, in a deck or free", :aggregate_failures do
      entry = printing(Date.new(2020, 1, 1))
      create(:lot, account:, entry:, quantity: 2)
      before = overview(entry).then { [ it.owned_count, it.in_decks_count, it.free_count, it.uses.deck_count ] }
      create(:deck_proxy, zone: deck_a.zone("main"), entry:, quantity: 4)

      after = overview(entry)
      expect([ after.owned_count, after.in_decks_count, after.free_count, after.uses.deck_count ]).to eq(before)
      expect(after.uses.proxy).to eq(4)
    end

    it "reads nothing for a visitor", :aggregate_failures do
      entry = printing(Date.new(2020, 1, 1))
      visitor = described_class.new(account: nil, entry:)
      entry.identity # the identity is the page's own read, loaded beforehand

      statements = count_queries { [ visitor.free_count, visitor.in_decks_count, visitor.deck_lots, visitor.uses.rows ] }
      expect(statements).to eq(0)
      expect([ visitor.free_count, visitor.in_decks_count, visitor.deck_lots, visitor.uses.rows ]).to eq([ 0, 0, [], [] ])
    end
  end
end
