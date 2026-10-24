require "rails_helper"

RSpec.describe Lot, type: :model do
  let(:account) { create(:user).account }
  let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil]).entry }

  describe ".key_for" do
    it "carries the place for a placed lot and is today's key for an unplaced one (spec 032 AC-7.1)", :aggregate_failures do
      expect(described_class.key_for("foil", "near_mint", 150)).to eq("foil|near_mint|150")
      expect(described_class.key_for(nil, nil, nil)).to eq("||")
      expect(described_class.key_for("foil", "near_mint", 150, 7)).to eq("foil|near_mint|150|7")
      expect(described_class.key_for(nil, nil, nil, 7)).to eq("|||7")
    end
  end

  describe ".add! in a place (spec 032)" do
    let(:blue) { create(:location, account:) }
    let(:box) { create(:location, account:) }

    it "merges only into the lot in the same place (AC-1.3, AC-1.4)", :aggregate_failures do
      described_class.add!(account:, entry:, quantity: 4, location: blue)
      lot = described_class.add!(account:, entry:, quantity: 2, location: blue)
      expect([ lot.quantity, lot.location, account.lots.count ]).to eq([ 6, blue, 1 ])
      described_class.add!(account:, entry:, quantity: 2)
      expect(account.lots.pluck(:quantity, :location_id)).to contain_exactly([ 6, blue.id ], [ 2, nil ])
    end

    it "holds 9,999 per place (AC-1.5)", :aggregate_failures do
      described_class.add!(account:, entry:, quantity: 9_998, location: blue)
      expect { described_class.add!(account:, entry:, quantity: 2, location: blue) }
        .to raise_error(ActiveRecord::RecordInvalid) { |error| expect(error.record.errors[:quantity]).to include(described_class::FULL_MESSAGE) }
      expect(account.lots.sole.quantity).to eq(9_998)
      expect(described_class.add!(account:, entry:, quantity: 2, location: box).quantity).to eq(2)
    end

    it "refuses another account's location", :aggregate_failures do
      expect { described_class.add!(account:, entry:, location: create(:location)) }
        .to raise_error(ActiveRecord::RecordInvalid) { |error| expect(error.record.errors).to include(:location) }
    end

    it "raises the foreign key's error, writing nothing, when the location is gone meanwhile (AC-6.7)", :aggregate_failures do
      location = create(:location, account:)
      Location.where(id: location.id).delete_all
      expect { described_class.add!(account:, entry:, location:) }.to raise_error(ActiveRecord::InvalidForeignKey)
      expect(account.lots.count).to eq(0)
    end
  end

  describe "#revise! to a place (spec 032)" do
    let(:blue) { create(:location, account:) }
    let(:box) { create(:location, account:) }

    it "moves the same lot, keeping its id and created_at (AC-2.2)", :aggregate_failures do
      lot = described_class.add!(account:, entry:, quantity: 4, location: box)
      lot.update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)
      created = lot.reload.created_at
      lot.revise!(location: blue)
      expect(lot.reload).to have_attributes(id: lot.id, location: blue, created_at: created)
      expect(lot.updated_at).to be > created
      expect(lot.lot_key).to end_with("|#{blue.id}")
    end

    it "merges into a twin in the new place (AC-2.3)", :aggregate_failures do
      twin = described_class.add!(account:, entry:, quantity: 3, location: blue)
      lot = described_class.add!(account:, entry:, quantity: 4, location: box)
      expect(lot.revise!(location: blue)).to eq(twin)
      expect(twin.reload.quantity).to eq(7)
      expect(described_class.exists?(lot.id)).to be(false)
    end

    it "refuses a merge over the cap and changes neither lot (AC-2.4)", :aggregate_failures do
      twin = described_class.add!(account:, entry:, quantity: 9_997, location: blue)
      lot = described_class.add!(account:, entry:, quantity: 4, location: box)
      expect { lot.revise!(location: blue) }.to raise_error(ActiveRecord::RecordInvalid)
      expect([ twin.reload.quantity, lot.reload.quantity, lot.location ]).to eq([ 9_997, 4, box ])
    end

    it "merges into the unplaced lot when revised to no location (AC-2.5)", :aggregate_failures do
      unplaced = described_class.add!(account:, entry:, quantity: 1)
      lot = described_class.add!(account:, entry:, quantity: 4, location: box)
      expect(lot.revise!(location: nil)).to eq(unplaced)
      expect(unplaced.reload.quantity).to eq(5)
    end

    it "ends with the new quantity in the new place when both change (AC-2.6)", :aggregate_failures do
      lot = described_class.add!(account:, entry:, quantity: 4, location: box)
      lot.revise!(quantity: 9, location: blue)
      expect(lot.reload).to have_attributes(quantity: 9, location: blue)
    end

    it "raises the foreign key's error when the location is gone meanwhile (AC-6.7)", :aggregate_failures do
      lot = described_class.add!(account:, entry:, quantity: 4)
      Location.where(id: blue.id).delete_all
      expect { lot.revise!(location: blue) }.to raise_error(ActiveRecord::InvalidForeignKey)
      expect(lot.reload.location_id).to be_nil
    end
  end

  describe ".add!" do
    it "merges into the lot with the same finish, condition and price", :aggregate_failures do
      described_class.add!(account:, entry:)
      lot = described_class.add!(account:, entry:, quantity: 2)
      expect(lot.quantity).to eq(3)
      expect(account.lots.count).to eq(1)
    end

    it "creates a separate lot when any identity field differs" do
      described_class.add!(account:, entry:, finish: "foil", condition: "near_mint", price_paid_cents: 400)
      described_class.add!(account:, entry:)
      expect(account.lots.count).to eq(2)
    end

    it "refuses a sum above 9,999 and changes nothing", :aggregate_failures do
      described_class.add!(account:, entry:, quantity: 9_999)
      expect { described_class.add!(account:, entry:) }.to raise_error(ActiveRecord::RecordInvalid, /at most 9,999/)
      expect(account.lots.sole.quantity).to eq(9_999)
    end

    it "rejects a finish the printing lacks, an unknown condition and bad prices", :aggregate_failures do
      expect { described_class.add!(account:, entry:, finish: "etched") }.to raise_error(ActiveRecord::RecordInvalid, /Finish/)
      expect { described_class.add!(account:, entry:, condition: "mint") }.to raise_error(ActiveRecord::RecordInvalid, /Condition/)
      expect { described_class.add!(account:, entry:, price_paid_cents: -1) }.to raise_error(ActiveRecord::RecordInvalid, /Price/)
    end
  end

  describe "#revise!" do
    it "merges into another lot when the edit makes their identities equal", :aggregate_failures do
      foil = described_class.add!(account:, entry:, finish: "foil")
      plain = described_class.add!(account:, entry:, quantity: 2)
      survivor = plain.revise!(quantity: 2, finish: "foil", condition: nil, price_paid_cents: nil)
      expect(survivor).to eq(foil)
      expect([ survivor.quantity, account.lots.count ]).to eq([ 3, 1 ])
    end

    it "refuses a merge above 9,999 and leaves both lots as they were", :aggregate_failures do
      foil = described_class.add!(account:, entry:, finish: "foil", quantity: 9_000)
      plain = described_class.add!(account:, entry:, quantity: 1_000)
      expect { plain.revise!(quantity: 1_000, finish: "foil", condition: nil, price_paid_cents: nil) }
        .to raise_error(ActiveRecord::RecordInvalid)
      expect(plain.errors[:quantity]).to include(described_class::FULL_MESSAGE)
      expect([ foil.reload.quantity, plain.reload.finish ]).to eq([ 9_000, nil ])
    end
  end

  it "sums owned quantities per printing for one account" do
    described_class.add!(account:, entry:, quantity: 2)
    described_class.add!(account:, entry:, finish: "foil")
    described_class.add!(account: create(:user).account, entry:, quantity: 5)
    expect(described_class.owned_quantities(account, [ entry.id ])).to eq(entry.id => 3)
  end

  describe "data store" do
    let(:connection) { described_class.connection }

    it "rejects a duplicate identity even when validations are skipped" do
      described_class.add!(account:, entry:)
      duplicate = described_class.new(account:, entry:, quantity: 1, lot_key: described_class.key_for(nil, nil, nil))
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "tells a placed lot from an unplaced one of the same printing, finish, condition and price" do
      placed = described_class.add!(account:, entry:, location: create(:location, account:))
      unplaced = described_class.add!(account:, entry:)
      expect(placed).not_to eq(unplaced)
    end

    it "gives lots an indexed, non-null account foreign key", :aggregate_failures do
      expect(connection.columns("lots").find { |column| column.name == "account_id" }.null).to be(false)
      expect(connection.foreign_keys("lots").map(&:to_table)).to include("accounts")
      expect(connection.indexes("lots").map(&:columns)).to include(a_collection_starting_with("account_id"))
    end

    it "keeps catalog tables global" do
      catalog = connection.tables.grep(/\A(catalog|mtg)_/)
      expect(catalog.select { |table| connection.column_exists?(table, :account_id) }).to be_empty
    end
  end
end
