require "rails_helper"

RSpec.describe NumberEntry::Line do
  let(:account) { create(:user).account }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }
  let(:line) { NumberEntry.add!(account:, entry:, quantity: 4, finish: "nonfoil", line_key: "a" * 32).line }
  let(:lot) { line.lot }

  describe "#undo! after a move (spec 032 AC-7.6)" do
    let(:blue) { create(:location, account:) }

    it "undoes against the lot where it is now when the lot moved whole to an empty place", :aggregate_failures do
      lot.update!(location: blue)
      expect(line).to be_undoable
      expect(line.undo!).to be(true)
      expect(account.lots).to be_empty
    end

    it "is no longer undoable once a whole move merged the lot away", :aggregate_failures do
      create(:lot, account:, entry:, finish: "nonfoil", location: blue)
      lot.revise!(location: blue)
      expect(line.reload).not_to be_undoable
    end
  end

  describe "#undo! after Move copies (spec 032 AC-7.6)" do
    let(:blue) { create(:location, account:) }

    it "undoes against the lot where the whole of it was moved", :aggregate_failures do
      line
      Lot::Move.new(lot:, to: blue, copies: "4").call!
      expect(line.reload).to be_undoable
      expect(line.undo!).to be(true)
    end

    it "is no longer undoable once a whole move merged the lot into another" do
      line
      create(:lot, account:, entry:, finish: "nonfoil", location: blue)
      Lot::Move.new(lot:, to: blue, copies: "4").call!
      expect(line.reload).not_to be_undoable
    end

    it "is not undoable once a split left fewer copies in the lot than the line added" do
      line
      Lot::Move.new(lot:, to: blue, copies: "1").call!
      expect(line.reload).not_to be_undoable
    end
  end

  describe "#undo!" do
    it "takes the line's copies out of a lot that holds more (AC-3.2)", :aggregate_failures do
      lot.update!(quantity: 6)
      expect(line.undo!).to be(false)
      expect(lot.reload.quantity).to eq(2)
      expect(line.reload.undone_at).to be_present
    end

    it "removes a lot that holds exactly the line's copies (AC-3.3)", :aggregate_failures do
      expect(line.undo!).to be(true)
      expect(Lot.exists?(lot.id)).to be(false)
    end

    it "undoes from a lot whose condition was edited since (AC-3.5)", :aggregate_failures do
      lot.revise!(condition: "near_mint")
      expect(line.undo!).to be(true)
      expect(account.lots).to be_empty
    end

    it "refuses when the lot now holds fewer copies than the line added (AC-3.4)", :aggregate_failures do
      lot.update!(quantity: 3)
      expect(line).not_to be_undoable
      expect { line.undo! }.to raise_error(NumberEntry::Line::NotUndoable)
      expect(lot.reload.quantity).to eq(3)
    end

    it "refuses when the lot was removed (AC-3.4)", :aggregate_failures do
      lot.destroy!
      expect(line.reload.lot_id).to be_nil
      expect(line).not_to be_undoable
      expect { line.undo! }.to raise_error(NumberEntry::Line::NotUndoable)
    end

    it "refuses when the lot was merged away (AC-3.4)", :aggregate_failures do
      other = create(:lot, account:, entry:, finish: "foil", quantity: 1)
      lot.revise!(finish: "foil")
      expect(Lot.exists?(lot.id)).to be(false)
      expect(other.reload.quantity).to eq(5)
      expect(line.reload).not_to be_undoable
    end

    it "refuses a second undo", :aggregate_failures do
      lot.update!(quantity: 8)
      line.undo!
      expect { line.undo! }.to raise_error(NumberEntry::Line::NotUndoable)
      expect(lot.reload.quantity).to eq(4)
    end
  end
end
