require "rails_helper"

RSpec.describe Scanner::SittingEntry, type: :model do
  let(:account) { create(:user).account }
  let(:printing) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }

  def add(key) = Scanner::Sitting.add!(account:, printing:, finish: "foil", reading_key: key * 32).entry

  describe "#undo! after a move (spec 032 AC-7.6)" do
    let(:blue) { create(:location, account:) }

    it "undoes against the lot where it is now when the lot moved whole to an empty place", :aggregate_failures do
      entry = add("a")
      account.lots.sole.update!(location: blue)
      expect(entry.undo!).to be(true)
      expect(account.lots).to be_empty
    end

    it "is changed once a whole move merged its lot away", :aggregate_failures do
      entry = add("a")
      create(:lot, account:, entry: printing, finish: "foil", location: blue)
      account.lots.find_by!(location_id: nil).revise!(location: blue)
      expect(entry.reload.state).to eq(:changed)
    end
  end

  describe "#undo!" do
    it "takes one copy out of the lot and marks the entry undone (AC-4.1)", :aggregate_failures do
      add("a")
      entry = add("b")
      expect(entry.undo!).to be(false)
      expect(account.lots.sole.quantity).to eq(1)
      expect(entry.reload.state).to eq(:undone)
    end

    it "removes the lot with its last copy (AC-4.1)", :aggregate_failures do
      expect(add("a").undo!).to be(true)
      expect(account.lots).to be_empty
    end

    it "takes one copy for each of two adds into the same lot (AC-4.3)" do
      [ add("a"), add("b") ].each(&:undo!)
      expect(account.lots).to be_empty
    end

    it "still takes the copy back after the lot was edited, if it wasn't merged away (AC-4.4)" do
      entry = add("a")
      add("b")
      account.lots.sole.revise!(condition: "near_mint", price_paid_cents: 250)
      entry.undo!
      expect(account.lots.sole).to have_attributes(quantity: 1, condition: "near_mint", price_paid_cents: 250)
    end

    it "refuses once undone, and when the lot was merged away or removed (AC-3.6, AC-4.2, AC-4.4)", :aggregate_failures do
      undone = add("a").tap(&:undo!)
      expect { undone.undo! }.to raise_error(described_class::NotUndoable, "undone")
      merged = add("b")
      create(:lot, account:, entry: printing, finish: "foil", condition: "near_mint")
      account.lots.find_by!(condition: nil).revise!(condition: "near_mint")
      expect(merged.reload.state).to eq(:changed)
      expect { merged.undo! }.to raise_error(described_class::NotUndoable, "changed")
      removed = add("c")
      account.lots.find(removed.lot_id).destroy!
      expect { removed.undo! }.to raise_error(described_class::NotUndoable, "changed")
    end
  end
end
