require "rails_helper"

RSpec.describe Lot, type: :model do
  let(:account) { create(:user).account }
  let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil]).entry }

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
