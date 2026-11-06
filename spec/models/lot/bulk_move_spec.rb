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

  describe "merging" do
    let(:entry) { create(:mtg_printing).entry } # a printing with no lot yet: lot.entry would be an unplaced lot's identity, and a second unplaced lot(entry) would hit the unique index

    it "merges a moved lot into the destination's lot of its identity, which survives (AC-3.3)", :aggregate_failures do
      moved = lot(entry, location: box, quantity: 2)
      survivor = lot(entry, location: blue, quantity: 3)
      expect(move([ moved ], blue).ids).to eq([ survivor.id ])
      expect(survivor.reload.quantity).to eq(5)
      expect(Lot.exists?(moved.id)).to be(false)
    end

    it "makes selected lots of one identity one lot, the first in the table's order surviving (AC-3.4)", :aggregate_failures do
      first = lot(entry, quantity: 4)             # unplaced, lower id
      second = lot(entry, location: box, quantity: 2)
      Lot.update_all(created_at: 1.day.ago)
      expect(move([ first, second ], blue).ids).to eq([ first.id ])
      expect(first.reload.created_at).to be < 1.hour.ago # the survivor keeps its added time
      expect(first.reload).to have_attributes(location: blue, quantity: 6, lot_key: Lot.key_for(nil, nil, nil, blue.id))
      expect(Lot.exists?(second.id)).to be(false)
    end

    it "lets the sort choose the survivor (AC-3.4)", :aggregate_failures do
      many = lot(entry, quantity: 4)
      few = lot(entry, location: box, quantity: 2)
      by_quantity = CollectionTable::Sort.parse("quantity", "asc")
      expect(move([ many, few ], blue, sort: by_quantity).ids).to eq([ few.id ])
      expect(few.reload.quantity).to eq(6)
    end

    it "folds two moved lots into the destination's lot when it has the identity (AC-3.5)", :aggregate_failures do
      a = lot(entry, quantity: 4)
      b = lot(entry, location: box, quantity: 2)
      held = lot(entry, location: blue, quantity: 1)
      expect(move([ a, b ], blue).ids).to eq([ held.id ])
      expect([ held.reload.quantity, Lot.where(id: [ a, b ]).count ]).to eq([ 7, 0 ])
    end

    it "treats a selected lot already there as the target, and counts its copies as already there (AC-3.12)", :aggregate_failures do
      a = lot(entry, location: box, quantity: 2)
      b = lot(entry, location: blue, quantity: 3)
      result = move([ a, b ], blue)
      expect(result).to have_attributes(ids: [ b.id ], moved: 2, already_there: 3)
      expect([ b.reload.quantity, Lot.exists?(a.id) ]).to eq([ 5, false ])
    end

    it "reads a number-entry line as changed when its lot is folded away, and names the new place when its lot moved whole (spec 041 decision 6; spec 032 AC-7.6; spec 034 decision 3)", :aggregate_failures do
      folded = NumberEntry.add!(account:, entry:, quantity: 2, finish: nil, line_key: "a" * 32).line
      moved = NumberEntry.add!(account:, entry: create(:mtg_printing).entry, quantity: 1, finish: nil, line_key: "b" * 32).line
      held = lot(entry, location: blue, quantity: 3)
      move(account.lots.where(id: [ folded.lot_id, moved.lot_id ]).to_a, blue)
      expect(folded.reload).not_to be_undoable           # its lot is gone: "Changed in your collection"
      expect(moved.reload).to be_undoable
      expect(moved.lot.location).to eq(blue)              # the line names its lot's new place
      expect(held.reload.quantity).to eq(5)
    end

    # Passes on arrival: a characterisation of the writers above, not a missing red.
    it "keeps lots of other places and identities as they were", :aggregate_failures do
      a = lot(entry, quantity: 2)
      other_finish = lot(entry, finish: "foil", quantity: 1)
      move([ a ], blue)
      expect(other_finish.reload).to have_attributes(location: nil, quantity: 1)
    end
  end

  describe "the 9,999 cap" do
    let(:entry) { create(:mtg_printing).entry } # a printing with no lot yet: lot.entry would be an unplaced lot's identity, and a second unplaced lot(entry) would hit the unique index

    it "changes nothing and names the first selected lot of an over-cap identity (AC-3.8)", :aggregate_failures do
      fine = lot(location: box)
      over = lot(entry, location: box, quantity: 5_000)
      other = lot(entry, quantity: 5_000)
      expect { move([ fine, over, other ], blue) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(over) }
      expect(Lot.order(:id).pluck(:location_id)).to eq([ box.id, box.id, nil ]) # every lot where it was
    end

    it "names a selected lot when the over-cap destination lot is unselected (AC-3.8)", :aggregate_failures do
      moved = lot(entry, location: box, quantity: 9_000)
      lot(entry, location: blue, quantity: 1_000)
      expect { move([ moved ], blue) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(moved) }
    end

    it "names the selected destination lot when it comes first in the table's order (AC-3.8)", :aggregate_failures do
      held = lot(entry, location: blue, quantity: 9_000)
      moved = lot(entry, location: box, quantity: 1_000)
      expect { move([ moved, held ], blue) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(held) }
    end

    # Passes on arrival: a characterisation of the merge.
    it "allows exactly 9,999" do
      lot(entry, location: blue, quantity: 9_000)
      expect(move([ lot(entry, location: box, quantity: 999) ], blue).moved).to eq(999)
    end
  end

  # Passes on arrival: a characterisation of the transaction.
  it "changes nothing when the destination was removed meanwhile, and raises the foreign key error", :aggregate_failures do
    gone = create(:location, account:)
    alone = lot(location: box)
    merged = lot(location: box, quantity: 2)
    twin = lot(merged.entry, quantity: 1)
    Location.where(id: gone.id).delete_all
    expect { move([ alone, merged, twin ], gone) }.to raise_error(ActiveRecord::InvalidForeignKey)
    expect([ alone.reload.location, merged.reload.quantity, Lot.exists?(twin.id) ]).to eq([ box, 2, true ])
  end

  # Passes on arrival: a characterisation of NoLotsLeft.
  it "raises NoLotsLeft, not 'already there', when the relation selects no lot of the account", :aggregate_failures do
    theirs = create(:lot, account: create(:user).account)
    expect { described_class.new(account:, lots: Lot.where(id: theirs.id), to: blue, sort:).apply! }.to raise_error(described_class::NoLotsLeft, BulkSelection::NONE_LEFT)
    expect(theirs.reload.location).to be_nil
  end

  # Passes on arrival: a characterisation of the account guard.
  it "touches only the account's lots", :aggregate_failures do
    theirs = create(:lot, account: create(:user).account, quantity: 2)
    mine = lot
    described_class.new(account:, lots: Lot.where(id: [ mine.id, theirs.id ]), to: blue, sort:).apply!
    expect([ mine.reload.location, theirs.reload.location ]).to eq([ blue, nil ])
  end
end
