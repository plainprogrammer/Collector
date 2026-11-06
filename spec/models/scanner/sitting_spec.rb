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

    def open_in(location) = described_class.choose!(account:, location:)

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

  describe ".add! with the sitting's condition (spec 042)" do
    let(:blue) { create(:location, account:, name: "Blue binder") }

    def choose(**choices) = described_class.choose!(account:, **choices)

    it "adds into the lot of that printing, finish and condition, leaving the others alone (AC-1.3)", :aggregate_failures do
      unspecified = create(:lot, account:, entry: printing, finish: "foil", quantity: 2)
      lightly = create(:lot, account:, entry: printing, finish: "foil", condition: "lightly_played", quantity: 4)
      choose(condition: "near_mint")
      added = add
      expect(added.entry.lot).to have_attributes(condition: "near_mint", location: nil, quantity: 1, finish: "foil", price_paid_cents: nil)
      expect([ unspecified.reload.quantity, lightly.reload.quantity ]).to eq([ 2, 4 ])
    end

    it "merges into a lot already of that condition (AC-1.3)", :aggregate_failures do
      there = create(:lot, account:, entry: printing, finish: "foil", condition: "near_mint", quantity: 3)
      choose(condition: "near_mint")
      add
      expect(there.reload.quantity).to eq(4)
      expect(account.lots.count).to eq(1)
    end

    it "adds with the condition and the place together (AC-1.4)" do
      choose(condition: "near_mint", location: blue)
      expect(add.entry.lot).to have_attributes(condition: "near_mint", location: blue, finish: "foil")
    end

    it "joins the lot with no condition when the sitting has none (AC-1.5)", :aggregate_failures do
      choose(location: blue)
      expect(add.entry.lot.condition).to be_nil
      choose(condition: "near_mint")
      choose(condition: nil)
      expect(add(key: "b" * 32).entry.lot).to have_attributes(condition: nil, quantity: 2)
    end

    it "refuses at the cap of the lot of that condition, while Not specified takes the card (AC-1.6)", :aggregate_failures do
      create(:lot, account:, entry: printing, finish: "foil", condition: "near_mint", quantity: Lot::MAX_QUANTITY)
      choose(condition: "near_mint")
      expect { add }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Scanner::SittingEntry.count).to eq(0)
      choose(condition: nil)
      expect(add.entry.lot.condition).to be_nil
    end

    it "answers a replayed key with its entry, whatever the condition is now (AC-4.4)", :aggregate_failures do
      choose(condition: "near_mint")
      first = add
      choose(condition: "lightly_played")
      again = add
      expect(again).to have_attributes(replayed: true, entry: first.entry)
      expect(again.entry.lot.condition).to eq("near_mint")
      expect(account.lots.sum(:quantity)).to eq(1)
    end

    it "refuses a condition the printing's vocabulary doesn't know as :condition, never as the cap, recording nothing (AC-4.5)", :aggregate_failures, :other_collecting do
      other = create(:catalog_entry, collectible_type: "other")
      choose(condition: "near_mint")
      expect(refusal { add(finish: nil, to: other) }).to eq(:condition)
      expect([ account.lots.count, Scanner::SittingEntry.count ]).to eq([ 0, 0 ])
      expect(described_class.find_by!(account:).condition).to eq("near_mint")
    end

    it "answers a replay before it checks the condition (decision 5)", :aggregate_failures, :other_collecting do
      choose(condition: "near_mint")
      first = add
      again = add(finish: nil, to: create(:catalog_entry, collectible_type: "other"))
      expect(again).to have_attributes(replayed: true, entry: first.entry)
    end
  end

  describe ".choose!" do
    let(:blue) { create(:location, account:, name: "Blue binder") }
    let(:long_box) { create(:location, account:, name: "Long box") }

    def choose(**choices) = described_class.choose!(account:, **choices)

    it "opens a sitting holding the condition, or the place, when none is open (AC-1.2)", :aggregate_failures do
      expect(choose(condition: "near_mint")).to have_attributes(account:, condition: "near_mint", location: nil, persisted?: true)
      expect(described_class.count).to eq(1)
      described_class.destroy_all
      expect(choose(location: blue)).to have_attributes(condition: nil, location: blue, persisted?: true)
    end

    it "keeps the choice it isn't given: a condition alone keeps the place, a place alone keeps the condition (AC-2.4)", :aggregate_failures do
      choose(condition: "near_mint", location: blue)
      expect(choose(condition: "lightly_played")).to have_attributes(condition: "lightly_played", location: blue)
      expect(choose(location: long_box)).to have_attributes(condition: "lightly_played", location: long_box)
      expect(described_class.where(account:).count).to eq(1)
    end

    it "clears a choice given as nil and keeps a sitting that holds a card (AC-1.8)", :aggregate_failures do
      choose(condition: "near_mint", location: blue)
      add
      expect(choose(condition: nil, location: nil)).to have_attributes(condition: nil, location: nil, persisted?: true)
      expect(described_class.find_by!(account:).entries.count).to eq(1)
    end

    it "keeps a sitting with no card while it still holds one choice (AC-1.8)", :aggregate_failures do
      choose(condition: "near_mint", location: blue)
      expect(choose(location: nil)).to have_attributes(condition: "near_mint", location: nil, persisted?: true)
      expect(choose(location: blue, condition: nil)).to have_attributes(condition: nil, location: blue, persisted?: true)
    end

    it "deletes a sitting with no kept card, no condition and no place, whether none was added or all were undone (AC-1.8)", :aggregate_failures do
      choose(condition: "near_mint")
      expect(choose(condition: nil)).to be_destroyed
      expect(described_class.count).to eq(0)

      choose(condition: "near_mint", location: blue)
      add.entry.undo!
      choose(condition: nil, location: nil)
      expect([ described_class.count, Scanner::SittingEntry.count ]).to eq([ 0, 0 ])
    end

    it "does nothing when clearing with no sitting open, and opens none", :aggregate_failures do
      expect(choose(condition: nil, location: nil)).to be_nil
      expect(described_class.count).to eq(0)
    end

    it "needs at least one of the two choices and no other key", :aggregate_failures do
      expect { described_class.choose!(account:) }.to raise_error(ArgumentError)
      expect { described_class.choose!(account:, language: "en") }.to raise_error(ArgumentError)
    end

    it "changes only the given account's sitting" do
      other = create(:user).account
      described_class.choose!(account: other, condition: "damaged")
      choose(condition: "near_mint")
      expect(described_class.where(account: other).sole.condition).to eq("damaged")
    end
  end

  describe "#drop_if_pointless! (spec 040 AC-3.2)" do
    it "deletes a sitting with no entries and no place, and keeps any other", :aggregate_failures do
      expect(described_class.create!(account:).drop_if_pointless!).to be(true)
      expect(described_class.count).to eq(0)
      add.entry.undo!
      expect(described_class.find_by!(account:).drop_if_pointless!).to be(false)
      expect(described_class.count).to eq(1)
    end

    it "reads the sitting again before deciding, so a place set since it was loaded keeps it" do
      stale = described_class.create!(account:)
      described_class.choose!(account:, location: create(:location, account:))
      stale.drop_if_pointless!
      expect(described_class.find_by!(account:).location).to be_present
    end
  end

  describe "#pointless? (spec 040 plan P1, spec 042 AC-3.3)" do
    it "is true only for a sitting with no entries at all, no place and no condition", :aggregate_failures do
      sitting = described_class.create!(account:)
      expect(sitting).to be_pointless
      sitting.update!(location: create(:location, account:))
      expect(sitting).not_to be_pointless
      sitting.update!(location: nil, condition: "near_mint")
      expect(sitting).not_to be_pointless
      sitting.update!(condition: nil)
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
      described_class.choose!(account:, location: blue)
      add
      add(key: "b" * 32, to: create(:mtg_printing).entry)
      described_class.choose!(account:, location: create(:location, account:))
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
