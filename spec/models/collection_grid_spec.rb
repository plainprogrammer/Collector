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

  describe "#choices? and a tile's place (spec 033, spec 065 decision 3)" do
    let(:entry) { own("Lightning Bolt", quantity: 1).tap { account.lots.destroy_all } }
    let(:blue) { create(:location, account:, name: "Blue binder") }
    let(:box) { create(:location, account:, name: "Long box") }

    def place_of(entry = self.entry) = described_class.new(account:, query: nil, page: nil).tiles.find { it.entry == entry }.place
    def put(quantity, location, **) = create(:lot, account:, entry:, quantity:, location:, **)

    it "has no place and no places while the account has no location", :aggregate_failures do
      put(2, nil)
      grid = described_class.new(account:, query: nil, page: nil)
      expect([ grid.choices?, grid.tiles.sole.place ]).to eq([ false, nil ])
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

    it "orders a tie by comparison key, where the raw name would order it the other way", :aggregate_failures do # spec 033 AC-1.2, spec 048 AC-2.5
      put(2, create(:location, account:, name: "Beta shelf"))
      put(2, create(:location, account:, name: "alpha shelf"), finish: "foil")
      expect(place_of).to have_attributes(name: "alpha shelf", more: 1)
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

  describe "under a location filter (spec 037)" do
    let(:blue) { create(:location, account:, name: "Blue binder") }
    let(:box) { create(:location, account:, name: "Long box") }
    let(:bolt) { own("Lightning Bolt").tap { account.lots.destroy_all } }

    def grid(location, query: nil) = described_class.new(account:, query:, location:, page: nil)
    def put(entry, quantity, location, **) = create(:lot, account:, entry:, quantity:, location:, **)

    it "sums only the place's copies and finishes and shows no place line", :aggregate_failures do
      put(bolt, 3, blue)
      put(bolt, 2, box, finish: "foil")
      tile = grid(blue.id.to_s).tiles.sole
      expect([ tile.entry, tile.quantity, tile.special_finishes, tile.place ]).to eq([ bolt, 3, [], nil ])
      expect([ grid(blue.id.to_s).matching_quantity, grid(blue.id.to_s).filtered? ]).to eq([ 3, true ])
    end

    it "leaves out printings with no copy there and pages the filtered printings", :aggregate_failures do
      put(bolt, 1, blue)
      put(own("Opt").tap { account.lots.where(entry: it).destroy_all }, 1, box)
      expect(grid(blue.id.to_s).tiles.map(&:entry)).to eq([ bolt ])
      expect(grid(blue.id.to_s).pagination.total_count).to eq(1)
    end

    it "sums unplaced copies for none", :aggregate_failures do
      put(bolt, 1, blue)
      put(bolt, 4, nil, finish: "etched")
      tile = grid("none").tiles.sole
      expect([ tile.quantity, tile.special_finishes, tile.place ]).to eq([ 4, %w[etched], nil ])
    end

    it "reads a stale, foreign or malformed value as all", :aggregate_failures do
      put(bolt, 1, blue)
      gone = create(:location, account:).tap(&:destroy!)
      [ gone.id.to_s, create(:location).id.to_s, "abc", "017", [ blue.id.to_s ] ].each do |value|
        filter = grid(value)
        expect([ filter.location, filter.filtered?, filter.tiles.sole.place&.name ]).to eq([ "", false, "Blue binder" ])
      end
    end

    it "ignores the place while the account has no location", :aggregate_failures do
      put(bolt, 2, nil)
      expect([ grid("none").location, grid("none").filtered? ]).to eq([ "", false ])
    end

    it "joins the name filter with AND" do
      put(bolt, 1, blue)
      opt = own("Opt").tap { account.lots.where(entry: it).destroy_all }
      put(opt, 1, blue)
      put(bolt, 1, box, finish: "foil")
      expect(grid(blue.id.to_s, query: "bolt").tiles.map { [ it.entry, it.quantity ] }).to eq([ [ bolt, 1 ] ])
    end

    it "names the chosen location", :aggregate_failures do
      expect(grid(blue.id.to_s).chosen_location).to eq(blue)
      expect([ grid("none").chosen_location, grid("").chosen_location ]).to eq([ nil, nil ])
    end

    it "reads the locations once and skips the place statement, however many tiles", :aggregate_failures do
      put(bolt, 1, blue)
      few = count_queries { grid(blue.id.to_s).tap { it.tiles && it.chosen_location && it.choices? } }
      all = count_queries { grid("").tiles }
      15.times { |i| put(own("Card #{i}").tap { account.lots.where(entry: it).destroy_all }, 1, blue) }
      many = count_queries { grid(blue.id.to_s).tap { it.tiles && it.chosen_location && it.choices? } }
      expect([ many, few ]).to eq([ few, all - 1 ])
    end
  end
end
