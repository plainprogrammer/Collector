require "rails_helper"

# Spec 041 Stories 3 and 4: moving many lots at once.
RSpec.describe Lot::BulkMove, type: :model do
  let(:account) { create(:user).account }
  let(:blue) { create(:location, account:, name: "Blue binder") }
  let(:box) { create(:location, account:, name: "Long box") }
  let(:sort) { CollectionTable::Sort.parse(nil, nil) }

  def lot(entry = nil, **attributes) = create(:lot, account:, **{ entry: }.compact, **attributes)
  def move(lots, to, sort: self.sort) = described_class.new(account:, lots: account.lots.where(id: lots.map(&:id)), to:, sort:).apply!

  it "moves every copy to the destination, keeping each lot's id and added time (AC-3.1)", :aggregate_failures do
    lots = [ lot(location: box, quantity: 2), lot(location: box, quantity: 5), lot(quantity: 1) ]
    untouched = lot(location: box, quantity: 7)
    Lot.update_all(created_at: 1.day.ago, updated_at: 1.day.ago)
    result = move(lots, blue)
    expect(result).to have_attributes(ids: match_array(lots.map(&:id)), moved: 8, already_there: 0)
    expect(lots.map { |moved| moved.reload.location }).to eq([ blue, blue, blue ])
    expect(lots.map { |moved| moved.quantity }).to eq([ 2, 5, 1 ])
    expect(lots.map { |moved| moved.created_at < 1.hour.ago }).to all(be(true))   # the added time stays
    expect(lots.map { |moved| moved.updated_at > 1.hour.ago }).to all(be(true))   # the changed time is the move's
    expect(untouched.reload).to have_attributes(location: box, updated_at: be < 1.hour.ago)
  end

  it "moves to no location (AC-3.2)", :aggregate_failures do
    placed = lot(location: blue, quantity: 3)
    move([ placed ], nil)
    expect(placed.reload).to have_attributes(location_id: nil, lot_key: Lot.key_for(nil, nil, nil))
  end

  it "keeps lots that differ only in finish, condition or price paid separate (AC-3.10)" do
    entry = create(:mtg_printing).entry
    others = [ lot(entry, finish: "foil", location: box), lot(entry, condition: "damaged", location: box), lot(entry, price_paid_cents: 150, location: box) ]
    move(others, blue)
    expect(account.lots.where(location: blue).count).to eq(3)
  end

  it "keeps each moved lot's key equal to the one Lot.key_for gives, to a place and to none", :aggregate_failures do
    lots = [ lot(finish: "foil", location: box), lot(price_paid_cents: 150, condition: "damaged"), lot(price_paid_cents: 0, finish: "nonfoil", location: blue) ]
    [ blue, nil, box, blue ].each do |to|
      move(lots, to)
      expected = lots.map { |held| Lot.key_for(held.finish, held.condition, held.price_paid_cents, to&.id) }
      expect(Lot.where(id: lots.map(&:id)).order(:id).pluck(:lot_key)).to eq(expected)
    end
  end

  # Passes on arrival: a characterisation of apply!'s mover/stayer split, not a missing red.
  it "leaves lots already there alone and counts their copies apart (AC-3.6)", :aggregate_failures do
    there = lot(location: blue, quantity: 3)
    coming = lot(location: box, quantity: 2)
    Lot.update_all(updated_at: 1.day.ago)
    result = move([ there, coming ], blue)
    expect(result).to have_attributes(moved: 2, already_there: 3, ids: [ coming.id ])
    expect(there.reload.updated_at).to be < 1.hour.ago
    expect(coming.reload.location).to eq(blue)
  end

  # Passes on arrival: a characterisation, as above.
  it "counts lots already unplaced the same way for no location (AC-3.6)" do
    expect(move([ lot(quantity: 4), lot(location: box, quantity: 1) ], nil)).to have_attributes(moved: 1, already_there: 4)
  end

  # Passes on arrival: a characterisation, as above.
  it "refuses when every selected lot is already there, naming the place, and changes nothing (AC-3.7)", :aggregate_failures do
    there = lot(location: blue)
    expect { move([ there ], blue) }.to raise_error(described_class::NothingToMove, "The selected items are already in Blue binder.")
    unplaced = lot
    expect { move([ unplaced ], nil) }.to raise_error(described_class::NothingToMove, "The selected items already have no location.")
    expect(there.reload.location).to eq(blue)
  end
end
