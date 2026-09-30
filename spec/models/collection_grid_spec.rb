require "rails_helper"

RSpec.describe CollectionGrid, type: :model do
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
end
