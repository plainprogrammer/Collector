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

  describe ".add! beside a lot in a location (spec 032 AC-7.2)" do
    it "adds the copy to the unplaced lot and leaves the placed one alone", :aggregate_failures do
      placed = create(:lot, account:, entry: printing, finish: "foil", quantity: 3, location: create(:location, account:))
      unplaced = create(:lot, account:, entry: printing, finish: "foil", quantity: 1)
      add
      expect([ placed.reload.quantity, unplaced.reload.quantity ]).to eq([ 3, 2 ])
    end
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

  describe ".add! into the sitting's place (spec 040)" do
    include QueryCounting

    let(:blue) { create(:location, account:, name: "Blue binder") }
    let(:long_box) { create(:location, account:, name: "Long box") }

    def open_in(location) = described_class.place!(account:, location:)

    it "adds into the lot of that printing and finish in the place, leaving the others alone (AC-1.3)", :aggregate_failures do
      unplaced = create(:lot, account:, entry: printing, finish: "foil", quantity: 2)
      elsewhere = create(:lot, account:, entry: printing, finish: "foil", quantity: 4, location: long_box)
      open_in(blue)
      added = add
      expect(added.entry.lot).to have_attributes(location: blue, quantity: 1, finish: "foil", condition: nil, price_paid_cents: nil)
      expect([ unplaced.reload.quantity, elsewhere.reload.quantity ]).to eq([ 2, 4 ])
    end

    it "merges into a lot already in the place (AC-1.4)", :aggregate_failures do
      there = create(:lot, account:, entry: printing, finish: "foil", quantity: 3, location: blue)
      open_in(blue)
      add
      expect(there.reload.quantity).to eq(4)
      expect(account.lots.count).to eq(1)
    end

    it "adds unplaced when the place's location was removed after it was chosen (FR-2, AC-3.2)", :aggregate_failures do
      open_in(blue)
      Location.connection.execute("DELETE FROM locations WHERE id = #{blue.id}") # Safe: an integer id; bypasses the model as another request would
      expect(add.entry.lot.location).to be_nil
      expect(described_class.find_by!(account:).location_id).to be_nil
    end

    it "refuses at the cap in the place and records nothing, while another place takes the card (AC-1.6)", :aggregate_failures do
      create(:lot, account:, entry: printing, finish: "foil", quantity: Lot::MAX_QUANTITY, location: blue)
      open_in(blue)
      expect { add }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Scanner::SittingEntry.count).to eq(0)
      open_in(long_box)
      expect(add.entry.lot.location).to eq(long_box)
    end

    it "answers a replayed key with its entry, whatever the place is now (AC-4.3)", :aggregate_failures do
      open_in(blue)
      first = add
      open_in(long_box)
      again = add
      expect(again).to have_attributes(replayed: true, entry: first.entry)
      expect(again.entry.lot.location).to eq(blue)
      expect(account.lots.sum(:quantity)).to eq(1)
    end
  end

  describe ".place!" do
    let(:blue) { create(:location, account:, name: "Blue binder") }
    let(:long_box) { create(:location, account:, name: "Long box") }

    def place(location) = described_class.place!(account:, location:)

    it "opens a sitting holding the place when none is open (AC-1.2)", :aggregate_failures do
      sitting = place(blue)
      expect(sitting).to have_attributes(account:, location: blue, persisted?: true)
      expect(sitting.entries).to be_empty
    end

    it "changes the place of the open sitting, keeping its entries, and stays one sitting (AC-2.1)", :aggregate_failures do
      place(blue)
      entry = add.entry
      place(long_box)
      place(long_box)
      expect(described_class.where(account:).sole).to have_attributes(location: long_box, entries: [ entry ])
    end

    it "clears the place and keeps a sitting that holds a card (AC-1.8)", :aggregate_failures do
      place(blue)
      add
      expect(place(nil)).to have_attributes(location: nil, persisted?: true)
      expect(described_class.find_by!(account:).entries.count).to eq(1)
    end

    it "deletes a sitting with no card on clearing its place, whether none was added or all were undone (AC-1.8)", :aggregate_failures do
      place(blue)
      expect(place(nil)).to be_destroyed
      expect(described_class.count).to eq(0)

      place(blue)
      add.entry.undo!
      place(nil)
      expect([ described_class.count, Scanner::SittingEntry.count ]).to eq([ 0, 0 ])
    end

    it "does nothing when clearing with no sitting open" do
      expect(place(nil)).to be_nil
    end

    it "changes only the given account's sitting" do
      other = create(:user).account
      described_class.place!(account: other, location: create(:location, account: other))
      place(blue)
      expect(described_class.where(account: other).sole.location.account).to eq(other)
    end
  end

  describe "#pointless? (spec 040 plan P1)" do
    it "is true only for a sitting with no entries at all and no place", :aggregate_failures do
      sitting = described_class.create!(account:)
      expect(sitting).to be_pointless
      sitting.update!(location: create(:location, account:))
      expect(sitting).not_to be_pointless
      sitting.update!(location: nil)
      add.entry.undo!
      expect(sitting.reload).not_to be_pointless
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

    it "loads each entry's lot and its location with no query per entry (spec 040 FR-1)", :aggregate_failures do
      extend QueryCounting
      blue = create(:location, account:)
      described_class.place!(account:, location: blue)
      add
      add(key: "b" * 32, to: create(:mtg_printing).entry)
      described_class.place!(account:, location: create(:location, account:))
      add(key: "c" * 32, to: create(:mtg_printing).entry)
      sitting = described_class.find_by!(account:)
      entries = nil
      queries = count_queries do
        entries = sitting.kept_entries.to_a
        entries.each { |entry| [ entry.lot.location&.name, entry.printing.set&.code ] }
      end
      expect(entries.map { |entry| entry.lot.location }.uniq.size).to eq(2)
      expect(queries).to be <= 5
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
