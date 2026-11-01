require "rails_helper"

RSpec.describe NumberEntry do
  let(:account) { create(:user).account }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }
  let(:key) { "a" * 32 }

  def add(line_key: key, quantity: 1, finish: "nonfoil", to: entry, location: nil)
    described_class.add!(account:, entry: to, quantity:, finish:, line_key:, location:)
  end

  describe ".add! into a location (spec 034 AC-1.2, AC-1.3, AC-1.5)" do
    let(:blue) { create(:location, account:, name: "Blue binder") }

    it "adds to the lot in that place, leaving the unplaced lot alone", :aggregate_failures do
      unplaced = create(:lot, account:, entry:, finish: "nonfoil", quantity: 1)
      add(quantity: 2, location: blue)
      placed = account.lots.find_by!(location: blue)
      expect([ placed.quantity, unplaced.reload.quantity ]).to eq([ 2, 1 ])
      expect(account.number_entry.lines.sole.lot).to eq(placed)
    end

    it "joins the lot already in that place", :aggregate_failures do
      add(quantity: 2, location: blue)
      add(quantity: 3, location: blue, line_key: "b" * 32)
      expect(account.lots.sole).to have_attributes(location: blue, quantity: 5)
    end

    it "records nothing when the lot in that place would pass the cap (AC-1.6)", :aggregate_failures do
      create(:lot, account:, entry:, finish: "nonfoil", quantity: 9_990, location: blue)
      expect { add(quantity: 20, location: blue) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(NumberEntry::Line.count).to eq(0)
      expect { add(quantity: 20, location: create(:location, account:)) }.not_to raise_error
    end
  end

  describe ".add! beside a lot in a location (spec 032 AC-7.2)" do
    it "adds the copy to the unplaced lot and leaves the placed one alone", :aggregate_failures do
      placed = create(:lot, account:, entry:, finish: "nonfoil", quantity: 3, location: create(:location, account:))
      unplaced = create(:lot, account:, entry:, finish: "nonfoil", quantity: 1)
      add
      expect([ placed.reload.quantity, unplaced.reload.quantity ]).to eq([ 3, 2 ])
    end
  end

  describe ".add!" do
    it "opens the account's list, adds the copies to a lot and records the line (FR-3)", :aggregate_failures do
      added = add(quantity: 4, finish: "foil")
      expect(added.replayed).to be(false)
      expect(account.lots.sole).to have_attributes(entry:, quantity: 4, finish: "foil", condition: nil, price_paid_cents: nil)
      expect(account.number_entry.lines.sole).to have_attributes(entry:, lot: account.lots.sole, quantity: 4, finish: "foil", line_key: key)
    end

    it "adds nothing for a line key already in the list, and returns that line (AC-2.11)", :aggregate_failures do
      first = add(quantity: 2)
      again = add(quantity: 2)
      expect(again).to have_attributes(line: first.line, replayed: true)
      expect(account.lots.sole.quantity).to eq(2)
      expect(NumberEntry::Line.count).to eq(1)
    end

    it "adds the same number twice under two keys (AC-2.12)", :aggregate_failures do
      add
      add(line_key: "b" * 32)
      expect(account.lots.sole.quantity).to eq(2)
      expect(account.number_entry.lines.count).to eq(2)
    end

    it "records nothing when the lot would pass 9,999 copies (AC-4.4)", :aggregate_failures do
      create(:lot, account:, entry:, finish: "nonfoil", quantity: 9_998)
      expect { add(quantity: 2) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(account.lots.sole.quantity).to eq(9_998)
      expect(NumberEntry::Line.count).to eq(0)
    end

    it "refuses a malformed line key" do
      expect { add(line_key: "x") }.to raise_error(ArgumentError)
    end
  end

  describe "#kept_lines" do
    it "lists lines not undone, newest first", :aggregate_failures do
      older = add.line
      newer = add(line_key: "b" * 32).line
      undone = add(line_key: "c" * 32).line
      undone.undo!
      expect(account.number_entry.kept_lines).to eq([ newer, older ])
    end
  end

  it "goes with its account, lines and all (AC-3.9)", :aggregate_failures do
    add
    account.user.destroy!
    expect(described_class.count).to eq(0)
    expect(NumberEntry::Line.count).to eq(0)
  end

  it "goes with Done, leaving the copies (AC-3.7)", :aggregate_failures do
    add(quantity: 3)
    account.number_entry.destroy!
    expect(NumberEntry::Line.count).to eq(0)
    expect(account.lots.sole.quantity).to eq(3)
  end
end
