require "rails_helper"

# Spec 071 decisions 4, 5 and 7 (AC-2.6, AC-2.8, AC-3.7): the free copies of a card and the order a count takes them in.
RSpec.describe Lot::FreeCopies, type: :model do
  let(:account) { create(:user).account }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:shown) { printing("2X2", Date.new(2022, 7, 8)) }

  def printing(code, released_on, identity: self.identity)
    entry = create(:catalog_entry, name: "Lightning Bolt", identity:, released_on:, set: create(:catalog_set, code:))
    create(:mtg_printing, entry:, finishes: %w[nonfoil foil]).entry
  end

  def free(entry = shown) = described_class.new(account:, entry:)

  it "puts the shown printing's lots first, then the other printings newest first (AC-3.7)" do
    oldest = printing("LEA", Date.new(1993, 8, 5))
    newer = printing("MH2", Date.new(2021, 6, 18))
    [ oldest, shown, newer ].each { |entry| create(:lot, account:, entry:) }

    expect(free.lots.map(&:entry)).to eq([ shown, newer, oldest ])
  end

  it "orders a printing's lots as Your copies does: finish, then unplaced before places by name (AC-3.7)" do
    blue = create(:location, account:, name: "Blue binder")
    red = create(:location, account:, name: "Red box")
    foil_unplaced = create(:lot, account:, entry: shown, finish: "foil")
    in_red = create(:lot, account:, entry: shown, location: red)
    in_blue = create(:lot, account:, entry: shown, location: blue)
    unplaced = create(:lot, account:, entry: shown)

    expect(free.lots).to eq([ unplaced, in_blue, in_red, foil_unplaced ])
  end

  it "leaves out a lot in any deck zone, Considering too, another account's lots and another card's (AC-2.6, AC-2.8)", :aggregate_failures do
    deck = create(:deck, account:)
    create_lot_in_zone(deck, "main", entry: shown)
    create_lot_in_zone(deck, "considering", entry: shown)
    create(:lot, entry: shown)
    create(:lot, account:, entry: create(:mtg_printing).entry)
    mine = create(:lot, account:, entry: shown, quantity: 2)

    expect(free.lots).to eq([ mine ])
    expect(free.total).to eq(2)
  end

  it "counts a card's every printing, and no proxy" do
    other = printing("MH2", Date.new(2021, 6, 18))
    create(:lot, account:, entry: shown, quantity: 2)
    create(:lot, account:, entry: other, quantity: 3)
    create(:deck_proxy, zone: create(:deck, account:).zone("main"), account:, entry: shown, quantity: 5)

    expect(free.total).to eq(5)
  end

  it "names each place once with its copies summed, in take order, and no location as nil (decision 7)" do
    blue = create(:location, account:, name: "Blue binder")
    red = create(:location, account:, name: "Red box")
    create(:lot, account:, entry: shown, quantity: 1)
    create(:lot, account:, entry: shown, quantity: 2, location: blue)
    create(:lot, account:, entry: shown, quantity: 1, location: red)
    create(:lot, account:, entry: shown, quantity: 3, location: blue, finish: "foil")

    expect(free.places).to eq([ described_class::Place.new(name: nil, count: 1), described_class::Place.new(name: "Blue binder", count: 5),
                                described_class::Place.new(name: "Red box", count: 1) ])
  end

  describe "#take" do
    let!(:first) { create(:lot, account:, entry: shown, quantity: 1) }
    let!(:second) { create(:lot, account:, entry: shown, quantity: 2, location: create(:location, account:, name: "Blue binder")) }

    it "takes whole lots from the front, then part of the next" do
      expect(free.take(2)).to eq([ [ first, 1 ], [ second, 1 ] ])
    end

    it "takes every lot whole for the full total" do
      expect(free.take(3)).to eq([ [ first, 1 ], [ second, 2 ] ])
    end

    it "takes part of the first lot when the count is smaller than it" do
      first.update!(quantity: 4)
      expect(free.take(3)).to eq([ [ first, 3 ] ])
    end
  end

  it "reads in a number of statements that does not grow with the lots (AC-2.9)" do
    count = ->(reader) { count_queries { reader.lots } }
    create(:lot, account:, entry: shown, location: create(:location, account:)) # placed, so the small read also loads a place
    small = count.call(free)
    12.times { |n| create(:lot, account:, entry: shown, finish: n.even? ? "foil" : nil, location: create(:location, account:)) }

    expect(count.call(free)).to eq(small)
  end
end
