require "rails_helper"

# Spec 032 Story 3: moving some or all of a lot's copies to another location, or to none.
RSpec.describe Lot::Move, type: :model do
  let(:account) { create(:user).account }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }
  let(:blue) { create(:location, account:, name: "Blue binder") }
  let(:box) { create(:location, account:, name: "Long box") }

  def lot_in(location, quantity = 4, **attributes) = create(:lot, account:, entry:, location:, quantity:, **attributes)

  def move(lot, to, copies = lot.quantity.to_s) = described_class.new(lot:, to:, copies:)

  def copies_total = account.lots.sum(:quantity)

  def errors_of(move)
    move.call!
    nil
  rescue ActiveRecord::RecordInvalid
    move.errors.to_hash
  end

  describe "#call!" do
    it "moves every copy to an empty place, keeping the lot's id and created_at (AC-3.2, P6)", :aggregate_failures do
      lot = lot_in(box, 4, finish: "foil", condition: "near_mint", price_paid_cents: 150)
      lot.update_columns(created_at: 3.days.ago, updated_at: 3.days.ago)
      created = lot.reload.created_at
      moved = move(lot, blue).call!
      expect(moved).to have_attributes(id: lot.id, location: blue, quantity: 4, created_at: created)
      expect(moved.updated_at).to be > created
    end

    it "splits some copies into a new lot of the same identity (AC-3.3, P6)", :aggregate_failures do
      lot = lot_in(box, 4, finish: "foil", condition: "near_mint", price_paid_cents: 150)
      moved = move(lot, blue, "2").call!
      expect(lot.reload.quantity).to eq(2)
      expect(moved).to have_attributes(quantity: 2, location: blue, finish: "foil", condition: "near_mint", price_paid_cents: 150, entry:)
      expect(moved.id).not_to eq(lot.id)
      expect(copies_total).to eq(4)
    end

    it "adds some copies to the twin in the destination (AC-3.4)", :aggregate_failures do
      lot = lot_in(box)
      twin = lot_in(blue, 3)
      move(lot, blue, "2").call!
      expect([ lot.reload.quantity, twin.reload.quantity ]).to eq([ 2, 5 ])
    end

    it "merges a whole lot into the twin, which survives with its id and created_at (AC-3.4a, P6)", :aggregate_failures do
      lot = lot_in(box)
      twin = lot_in(blue, 3)
      created = twin.created_at
      survivor = move(lot, blue).call!
      expect(survivor).to have_attributes(id: twin.id, quantity: 7, created_at: created)
      expect(Lot.exists?(lot.id)).to be(false)
    end

    it "moves to no location, joining or starting the unplaced lot (AC-3.5)", :aggregate_failures do
      lot = lot_in(box)
      unplaced = lot_in(nil, 1)
      move(lot, nil, "3").call!
      expect([ lot.reload.quantity, unplaced.reload.quantity ]).to eq([ 1, 4 ])
      move(lot, nil).call!
      expect(account.lots.pluck(:location_id, :quantity)).to eq([ [ nil, 5 ] ])
    end

    it "refuses a result over 9,999 with the cap message on copies and changes nothing (AC-3.6)", :aggregate_failures do
      lot = lot_in(box)
      twin = lot_in(blue, 9_998)
      move = move(lot, blue, "3")
      expect(errors_of(move)).to eq(copies: [ Lot::FULL_MESSAGE ])
      expect([ lot.reload.quantity, twin.reload.quantity ]).to eq([ 4, 9_998 ])
    end

    it "refuses copies outside 1 to the quantity (AC-3.7)", :aggregate_failures do
      lot = lot_in(box)
      [ "0", "-1", "5", "x", "", "4.5" ].each do |bad|
        expect(errors_of(move(lot, blue, bad))).to eq(copies: [ "Choose from 1 to 4 copies." ]), bad.inspect
      end
      expect(lot.reload).to have_attributes(quantity: 4, location: box)
    end

    it "refuses a move to the lot's own place, unplaced included (P4)", :aggregate_failures do
      expect(errors_of(move(lot_in(box), box))).to eq(location_id: [ "Those copies are already there." ])
      expect(errors_of(move(lot_in(nil), nil))).to eq(location_id: [ "Those copies are already there." ])
    end

    it "leaves both lots unchanged when a write fails after the source changed (AC-3.8)", :aggregate_failures do
      lot = lot_in(box)
      Lot.connection.execute("CREATE TRIGGER fail_lot_insert BEFORE INSERT ON lots BEGIN SELECT RAISE(ABORT, 'forced'); END")
      expect { move(lot, blue, "2").call! }.to raise_error(ActiveRecord::StatementInvalid)
      expect([ lot.reload.quantity, account.lots.count ]).to eq([ 4, 1 ])
    end

    it "refuses a second whole move built from the same stale lot, losing no copies (double submit a)", :aggregate_failures do
      lot = lot_in(nil)
      first = Lot.find(lot.id)
      second = Lot.find(lot.id)
      move(first, blue).call!
      moved_at = account.lots.sole.updated_at
      expect(errors_of(move(second, blue))).to eq(location_id: [ "Those copies are already there." ])
      expect(copies_total).to eq(4)
      expect(account.lots.sole).to have_attributes(quantity: 4, location: blue, updated_at: moved_at)
    end

    it "refuses a second split built from the same stale lot, creating no copies (double submit b)", :aggregate_failures do
      lot = lot_in(nil)
      first = Lot.find(lot.id)
      second = Lot.find(lot.id)
      move(first, blue, "3").call!
      expect(errors_of(move(second, blue, "3"))).to eq(copies: [ "Choose from 1 to 1 copies." ])
      expect(copies_total).to eq(4)
      expect(account.lots.pluck(:location_id, :quantity)).to contain_exactly([ nil, 1 ], [ blue.id, 3 ])
    end
  end

  describe "the unique index" do
    it "refuses two lots of one identity in one place even past validations (backstop)" do
      lot_in(box)
      twin = Lot.new(account:, entry:, location: box, quantity: 1, lot_key: Lot.key_for(nil, nil, nil, box.id))
      expect { twin.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  # Spec 062 AC-5.7a, D6: a lot in a deck's zone is "somewhere", so Move copies takes it out of the zone to a place or to none.
  describe "#call! of a lot in a deck's zone (spec 062 AC-5.7a)" do
    let(:deck) { create(:deck, account:, name: "Izzet Tempo") }

    def zoned(quantity = 4, **attributes) = create_lot_in_zone(deck, "main", entry:, quantity:, **attributes)

    it "splits some copies into a place, leaving the rest in the zone, each key ending in its own place's id", :aggregate_failures do
      lot = zoned(4, finish: "foil", condition: "near_mint")
      moved = move(lot, blue, "3").call!
      expect(lot.reload).to have_attributes(quantity: 1, location: deck.zone("main"))
      expect(lot.lot_key).to eq(Lot.key_for("foil", "near_mint", nil, deck.zone("main").id))
      expect(moved).to have_attributes(quantity: 3, location: blue, lot_key: Lot.key_for("foil", "near_mint", nil, blue.id))
    end

    it "moves every copy to no location, leaving a key without a place", :aggregate_failures do
      lot = zoned(4, finish: "foil")
      move(lot, nil).call!
      expect(lot.reload).to have_attributes(location_id: nil, lot_key: Lot.key_for("foil", nil, nil))
    end

    it "merges every copy into the place's lot of the same identity, and the zone's lot goes", :aggregate_failures do
      lot = zoned(2)
      held = lot_in(blue, 3)
      expect(move(lot, blue).call!).to eq(held)
      expect(held.reload.quantity).to eq(5)
      expect(Lot.exists?(lot.id)).to be(false)
    end

    it "moves a place's copies into the zone's lot only when asked to a zone's id (the model's own check)", :aggregate_failures do
      lot = lot_in(blue, 2)
      zone_lot = zoned(1)
      expect(move(lot, deck.zone("main")).call!).to eq(zone_lot)
      expect(zone_lot.reload.quantity).to eq(3)
    end
  end
end
