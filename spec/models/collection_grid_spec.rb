require "rails_helper"

RSpec.describe CollectionGrid, type: :model do
  include QueryCounting

  let(:account) { create(:user).account }

  def own(name, quantity: 1, finish: nil, released_on: Date.new(2020, 1, 1), **entry_attributes)
    identity = Catalog::Identity.find_by(name:) || create(:catalog_identity, name:)
    entry = create(:mtg_printing, finishes: %w[nonfoil foil etched],
      entry: create(:catalog_entry, identity:, name:, released_on:, **entry_attributes)).entry
    create(:lot, account:, entry:, quantity:, finish:)
    entry
  end

  it "makes one tile per printing with summed quantity and one finish label", :aggregate_failures do
    entry = own("Lightning Bolt", quantity: 2)
    create(:lot, account:, entry:, finish: "foil")
    create(:lot, account:, entry:, finish: "etched")
    tile = described_class.new(account:, query: nil, page: nil).tiles.sole
    expect([ tile.quantity, tile.special_finishes ]).to eq([ 4, %w[foil etched] ])
  end

  it "orders by name, then newest printing", :aggregate_failures do
    own("Opt")
    old = own("Lightning Bolt", released_on: Date.new(1993, 1, 1))
    new = own("Lightning Bolt", released_on: Date.new(2021, 1, 1))
    expect(described_class.new(account:, query: nil, page: nil).tiles.map(&:entry)).to eq([ new, old, Catalog::Entry.find_by(name: "Opt") ])
  end

  it "filters by name and reports whole-collection counts", :aggregate_failures do
    own("Lightning Bolt", quantity: 3)
    own("Opt", quantity: 2)
    grid = described_class.new(account:, query: "BOLT", page: nil)
    expect([ grid.tiles.size, grid.matching_quantity, grid.total_quantity, grid.unique_cards ]).to eq([ 1, 3, 5, 2 ])
  end

  it "keeps retired printings and pages at 120", :aggregate_failures do
    own("Lightning Bolt", retired_at: 1.day.ago)
    expect(described_class.new(account:, query: nil, page: nil).tiles.size).to eq(1)
    expect(described_class::PER_PAGE).to eq(120)
  end

  describe "#places? and a tile's place (spec 033)" do
    let(:entry) { own("Lightning Bolt", quantity: 1).tap { account.lots.destroy_all } }
    let(:blue) { create(:location, account:, name: "Blue binder") }
    let(:box) { create(:location, account:, name: "Long box") }

    def place_of(entry = self.entry) = described_class.new(account:, query: nil, page: nil).tiles.find { it.entry == entry }.place
    def put(quantity, location, **) = create(:lot, account:, entry:, quantity:, location:, **)

    it "has no place and no places while the account has no location", :aggregate_failures do
      put(2, nil)
      grid = described_class.new(account:, query: nil, page: nil)
      expect([ grid.places?, grid.tiles.sole.place ]).to eq([ false, nil ])
    end

    it "names the one place of a printing", :aggregate_failures do
      put(3, blue)
      expect(place_of).to have_attributes(name: "Blue binder", more: 0)
    end

    it "names the place with most copies and counts the others", :aggregate_failures do
      put(1, box)
      put(3, blue, finish: "foil")
      expect(place_of).to have_attributes(name: "Blue binder", more: 1)
    end

    it "breaks a tie by comparison key, and counts unplaced as a place", :aggregate_failures do
      put(2, box)
      put(2, blue, finish: "foil")
      put(2, nil, finish: "etched")
      expect(place_of).to have_attributes(name: "Blue binder", more: 2)
    end

    it "puts unplaced after a named place on a tie, and names nothing when unplaced leads", :aggregate_failures do
      put(2, nil)
      put(2, blue, finish: "foil")
      expect(place_of).to have_attributes(name: "Blue binder", more: 1)
      put(5, nil, finish: "etched")
      expect(place_of).to have_attributes(name: nil, more: 1)
    end

    it "shows an unplaced printing as no name and no other place when the account has locations", :aggregate_failures do
      blue
      put(2, nil)
      expect(place_of).to have_attributes(name: nil, more: 0)
    end

    it "reads a bounded number of statements however many tiles", :aggregate_failures do
      put(1, blue)
      few = count_queries { described_class.new(account:, query: nil, page: nil).tiles }
      15.times { |i| create(:lot, account:, entry: own("Card #{i}"), location: box) }
      many = count_queries { described_class.new(account:, query: nil, page: nil).tiles }
      expect(many).to eq(few)
    end
  end
end
