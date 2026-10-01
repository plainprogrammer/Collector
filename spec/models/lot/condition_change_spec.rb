require "rails_helper"

RSpec.describe Lot::ConditionChange, type: :model do
  let(:account) { create(:user).account }
  let!(:first) { owned_printing(account:, finish: "foil") }
  let(:sort) { CollectionTable::Sort.parse(nil, nil) }

  def lot(**attributes) = create(:lot, account:, entry: first.entry, **attributes)
  def change(lots, condition) = described_class.new(account:, lots: account.lots.where(id: lots.map(&:id)), condition:, sort:)

  it "sets the condition on each lot and leaves others alone", :aggregate_failures do
    other = lot(finish: "nonfoil", condition: "damaged")
    ids = change([ first ], "lightly_played").apply!
    expect([ first.reload.condition, other.reload.condition, ids ]).to eq([ "lightly_played", "damaged", [ first.id ] ])
  end

  it "merges into a lot that already has the identity, selected or not", :aggregate_failures do
    played = lot(finish: "foil", condition: "lightly_played", quantity: 4)
    ids = change([ first ], "lightly_played").apply!
    expect([ Lot.count, played.reload.quantity, ids ]).to eq([ 1, 5, [ played.id ] ])
  end

  it "merges selected lots that become identical" do
    lot(finish: "foil", condition: "damaged", quantity: 2)
    change(Lot.all.to_a, nil).apply!
    expect(Lot.pluck(:condition, :quantity)).to eq([ [ nil, 3 ] ])
  end

  it "changes nothing when a merge would pass 9,999 copies, naming the first such lot in order", :aggregate_failures do
    lot(finish: "foil", condition: "near_mint", quantity: 9_999)
    expect { change([ first ], "near_mint").apply! }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(first) }
    expect(Lot.order(:id).pluck(:condition, :quantity)).to eq([ [ nil, 1 ], [ "near_mint", 9_999 ] ])
  end
end
