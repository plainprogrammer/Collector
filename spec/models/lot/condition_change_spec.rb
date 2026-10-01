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

  context "when several lots would pass 9,999 copies" do
    let(:sort) { CollectionTable::Sort.parse("name", "desc") }

    it "names the first one in the selection's sort order", :aggregate_failures do
      ant, zebra = %w[Ant Zebra].map do |name|
        full = owned_printing(name, account:, finish: "foil", condition: "near_mint", quantity: 9_999)
        create(:lot, account:, entry: full.entry, finish: "foil")
      end
      expect { change([ ant, zebra ], "near_mint").apply! }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(zebra) }
      expect(Lot.where(id: [ ant, zebra ]).pluck(:condition)).to eq([ nil, nil ])
    end
  end

  def queries_during
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  def printings(count) = Array.new(count) { owned_printing(account:, finish: "foil") }

  it "runs as many queries for 12 lots that don't merge as for 2" do
    few, many = printings(2), printings(12)
    expect(queries_during { change(many, "near_mint").apply! }).to eq(queries_during { change(few, "near_mint").apply! })
  end

  it "keeps each bulk-updated lot's key equal to the one Lot.key_for gives", :aggregate_failures do
    lots = [ owned_printing(account:, finish: "foil"), owned_printing(account:, price_paid_cents: 150, condition: "damaged") ]
    [ "lightly_played", nil ].each do |condition|
      change(lots, condition).apply!
      expect(Lot.where(id: lots).map { |lot| [ lot.condition, lot.lot_key ] })
        .to match_array(Lot.where(id: lots).map { |lot| [ condition, Lot.key_for(lot.finish, condition, lot.price_paid_cents) ] })
    end
  end
end
