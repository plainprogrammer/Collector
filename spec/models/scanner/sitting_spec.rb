require "rails_helper"

RSpec.describe Scanner::Sitting, type: :model do
  let(:account) { create(:user).account }
  let(:printing) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }

  def add(finish: "foil", key: "a" * 32, to: printing) = described_class.add!(account:, printing: to, finish:, reading_key: key)

  def refusal
    yield
    nil
  rescue described_class::Refused => error
    error.reason
  end

  describe ".add!" do
    it "adds one copy with the finish as tapped, condition and price unspecified, and opens the sitting (AC-1.2, AC-3.1)", :aggregate_failures do
      added = add
      lot = account.lots.sole
      expect(lot).to have_attributes(entry: printing, quantity: 1, finish: "foil", condition: nil, price_paid_cents: nil)
      expect(added).to have_attributes(replayed: false)
      expect(added.entry).to have_attributes(sitting: described_class.find_by!(account:), printing:, lot:, finish: "foil", reading_key: "a" * 32)
    end

    it "merges into the lot of the same finish, not a finish-unspecified one (AC-1.2)" do
      plain = create(:lot, account:, entry: printing)
      foil = create(:lot, account:, entry: printing, finish: "foil", quantity: 2)
      add
      expect([ foil.reload.quantity, plain.reload.quantity ]).to eq([ 3, 1 ])
    end

    it "adds nothing for a key the sitting already has, whatever the printing or finish (AC-1.5)", :aggregate_failures do
      first = add
      again = add(finish: "nonfoil", to: create(:mtg_printing).entry)
      expect(again).to have_attributes(replayed: true, entry: first.entry)
      expect(account.lots.sum(:quantity)).to eq(1)
    end

    it "adds a second copy for a second reading, in the same sitting (AC-1.7, AC-3.1)", :aggregate_failures do
      add
      add(key: "b" * 32)
      expect(account.lots.sole.quantity).to eq(2)
      expect(described_class.where(account:).count).to eq(1)
    end

    it "records nothing at the lot cap (AC-1.6)", :aggregate_failures do
      create(:lot, account:, entry: printing, finish: "foil", quantity: Lot::MAX_QUANTITY)
      expect { add }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Scanner::SittingEntry.count).to eq(0)
    end

    it "records a one-finish printing's finish, and none for a printing with none listed (AC-1.1)", :aggregate_failures do
      expect(add(finish: "nonfoil", to: create(:mtg_printing, finishes: %w[nonfoil]).entry).entry.finish).to eq("nonfoil")
      expect(add(finish: "", key: "b" * 32, to: create(:mtg_printing, finishes: []).entry).entry.finish).to be_nil
    end

    it "refuses a bad key, a retired or missing printing, and a finish the printing doesn't come in, changing nothing", :aggregate_failures do
      retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
      expect(refusal { add(key: "not-a-key") }).to eq(:key)
      expect(refusal { add(key: nil) }).to eq(:key)
      expect(refusal { add(to: retired) }).to eq(:unavailable)
      expect(refusal { add(to: nil) }).to eq(:unavailable)
      expect(refusal { add(finish: "etched") }).to eq(:finish)
      expect(refusal { add(finish: "") }).to eq(:finish)
      expect([ account.lots.count, described_class.count ]).to eq([ 0, 0 ])
    end
  end

  describe "#kept_entries" do
    it "lists the entries not undone, newest first, including those whose lot changed (AC-3.2, AC-3.6)", :aggregate_failures do
      first, second, third = %w[a b c].map { add(key: it * 32).entry }
      second.undo!
      account.lots.sole.destroy!
      expect(described_class.find_by!(account:).kept_entries).to eq([ third, first ])
      expect(third.reload.state).to eq(:changed)
    end
  end

  describe "#end!" do
    it "deletes itself and its entries, keeps the copies and counts the entries not undone (AC-3.5)", :aggregate_failures do
      add
      add(key: "b" * 32).entry.undo!
      expect(described_class.find_by!(account:).end!).to eq(1)
      expect([ described_class.count, Scanner::SittingEntry.count, account.lots.sum(:quantity) ]).to eq([ 0, 0, 1 ])
    end

    it "counts nothing when every add was undone (AC-3.5)" do
      add.entry.undo!
      expect(described_class.find_by!(account:).end!).to eq(0)
    end
  end

  it "goes with its account" do
    add
    account.user.destroy!
    expect([ described_class.count, Scanner::SittingEntry.count ]).to eq([ 0, 0 ])
  end
end
