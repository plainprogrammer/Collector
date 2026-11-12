require "rails_helper"

# Spec 070 decisions 7 and 8: the all-or-nothing move of chosen copies of free lots into a zone, through Lot::Move.
RSpec.describe Lot::MoveIntoZone, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }
  let(:binder) { create(:location, account:, name: "Blue binder") }
  let(:box) { create(:location, account:, name: "Red box") }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }

  def zone = deck.zone("main") # a method, not a `let`: the group is at RSpec/MultipleMemoizedHelpers' limit of five

  def lot_in(location, quantity = 4, **attrs) = create(:lot, account:, entry:, location:, quantity:, **attrs)
  def move(picks, to: zone) = described_class.new(account:, zone: to, picks:).call!

  def reasons_of(picks)
    move(picks)
    nil
  rescue described_class::Refused => refused
    refused.reasons
  end

  it "moves a whole lot into the zone, keeping its id, and returns the copies moved", :aggregate_failures do
    lot = lot_in(binder, 3, finish: "foil", condition: "near_mint", price_paid_cents: 150)

    expect(move([ [ lot, 3 ] ])).to eq(3)
    expect(lot.reload).to have_attributes(location: zone, quantity: 3, finish: "foil", condition: "near_mint", price_paid_cents: 150)
    expect(lot.lot_key).to eq(Lot.key_for("foil", "near_mint", 150, zone.id))
  end

  it "moves some copies and leaves the rest in place, in a new lot of the same identity", :aggregate_failures do
    lot = lot_in(binder, 4)

    expect(move([ [ lot, 1 ] ])).to eq(1)
    expect(lot.reload).to have_attributes(location: binder, quantity: 3)
    expect(account.lots.find_by(location: zone)).to have_attributes(entry:, quantity: 1)
  end

  it "moves several lots, merging those that reach one identity into the zone's lot", :aggregate_failures do
    from_binder = lot_in(binder, 2)
    from_box = lot_in(box, 3)
    other_finish = lot_in(binder, 1, finish: "foil")

    expect(move([ [ from_binder, 2 ], [ from_box, 3 ], [ other_finish, 1 ] ])).to eq(6)
    expect(account.lots.where(location: zone).order(:quantity).pluck(:finish, :quantity)).to eq([ [ "foil", 1 ], [ nil, 5 ] ])
    expect(account.lots.where.not(location: zone).count).to eq(0)
  end

  it "writes nothing when the second move would pass the 9,999 cap, the first move included (one transaction)", :aggregate_failures do
    in_zone = lot_in(zone, 9_998)
    first = lot_in(binder, 1)
    second = lot_in(box, 1)

    expect(reasons_of([ [ first, 1 ], [ second, 1 ] ])).to eq({ second.id => :cap })
    expect([ in_zone.reload.quantity, first.reload.location, first.quantity, second.reload.location ]).to eq([ 9_998, binder, 1, box ])
  end

  it "refuses a lot that is no longer free, another account's lot and a lot that is gone, naming each and writing nothing", :aggregate_failures do
    taken = lot_in(deck.zone("sideboard"), 2)
    other = create(:user).account
    theirs = create(:lot, account: other, entry:, location: create(:location, account: other), quantity: 2)
    gone = lot_in(binder, 2).tap(&:destroy!)
    fine = lot_in(binder, 2)

    expect(reasons_of([ [ taken, 1 ], [ theirs, 1 ], [ gone, 1 ], [ fine, 1 ] ])).to eq({ taken.id => :not_free, theirs.id => :not_free, gone.id => :not_free })
    expect([ fine.reload.location, fine.quantity ]).to eq([ binder, 2 ])
  end

  it "refuses a count outside 1 to the lot's copies as it stands now", :aggregate_failures do
    lot = lot_in(binder, 2)

    expect(reasons_of([ [ lot, 0 ] ])).to eq({ lot.id => :count })
    expect(reasons_of([ [ lot, 3 ] ])).to eq({ lot.id => :count })
    lot.update_columns(quantity: 1) # changed since the caller read it
    expect(reasons_of([ [ lot, 2 ] ])).to eq({ lot.id => :count })
  end

  it "refuses a lot whose finish the vocabulary no longer lists, instead of skipping validation", :aggregate_failures do
    lot = lot_in(binder, 2)
    lot.update_columns(finish: "retired_finish")

    expect(reasons_of([ [ lot, 1 ] ])).to eq({ lot.id => :not_saveable })
    expect(lot.reload.location).to eq(binder)
  end

  it "judges every pick before it moves any, so the reasons list every refused lot", :aggregate_failures do
    bad = lot_in(binder, 2)
    worse = lot_in(box, 1)

    expect(reasons_of([ [ bad, 5 ], [ worse, 0 ] ])).to eq({ bad.id => :count, worse.id => :count })
  end

  it "refuses a zone that is not a zone of the account and a lot named twice", :aggregate_failures do
    lot = lot_in(binder, 2)

    expect { described_class.new(account:, zone: binder, picks: [ [ lot, 1 ] ]) }.to raise_error(ArgumentError)
    expect { described_class.new(account:, zone: create(:deck).zone("main"), picks: [ [ lot, 1 ] ]) }.to raise_error(ArgumentError)
    expect { described_class.new(account:, zone:, picks: [ [ lot, 1 ], [ lot, 1 ] ]) }.to raise_error(ArgumentError)
  end

  it "joins a caller's transaction: a refusal inside it rolls the caller's own earlier writes back, and the caller's reads and picks stay under its lock", :aggregate_failures do
    in_zone = lot_in(zone, 9_998)
    first = lot_in(binder, 1)
    second = lot_in(box, 1)
    marker = create(:location, account:, name: "Marker")

    expect do
      Lot.transaction do
        marker.update!(name: "Renamed")
        free = account.lots.free.where(id: [ first.id, second.id ]).to_a # read and chosen under the caller's own lock
        move(free.map { |lot| [ lot, 1 ] })
      end
    end.to raise_error(described_class::Refused) { |refused| expect(refused.reasons).to eq({ second.id => :cap }) }

    expect(marker.reload.name).to eq("Marker") # the caller's write was rolled back with the moves
    expect([ in_zone.reload.quantity, first.reload.location ]).to eq([ 9_998, binder ])
  end

  it "tells a lot that fails its own validation, naming it, from the cap", :aggregate_failures do
    bad = lot_in(binder, 2)
    bad.update_columns(finish: "retired_finish")
    in_zone = lot_in(zone, 9_999, finish: "foil")
    capped = lot_in(box, 1, finish: "foil")

    expect(reasons_of([ [ bad, 1 ] ])).to eq({ bad.id => :not_saveable })
    expect(reasons_of([ [ capped, 1 ] ])).to eq({ capped.id => :cap })
    expect(in_zone.reload.quantity).to eq(9_999)
  end

  it "moves nothing and returns 0 for no picks" do
    expect(move([])).to eq(0)
  end

  it "leaves a failure of an outer transaction rolled back as a whole", :aggregate_failures do
    lot = lot_in(binder, 2)

    expect do
      Lot.transaction do
        move([ [ lot, 2 ] ])
        raise ActiveRecord::Rollback
      end
    end.not_to(change { lot.reload.location })
  end
end
