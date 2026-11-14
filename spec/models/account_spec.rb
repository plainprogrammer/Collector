require "rails_helper"

RSpec.describe Account, type: :model do
  it "deletes its lots before its locations, so lots in locations don't block it (spec 032 AC-6.6)", :aggregate_failures do
    user = create(:user)
    account = user.account
    2.times { create(:lot, account:, location: create(:location, account:)) }
    expect { user.destroy! }.not_to raise_error
    expect([ Lot.where(account_id: account.id).count, Location.where(account_id: account.id).count, described_class.exists?(account.id) ]).to eq([ 0, 0, false ])
  end

  it "deletes its decks, their zones and the lots in them with no foreign key failure (spec 062 AC-9.6)", :aggregate_failures do
    user = create(:user)
    account = user.account
    deck = create(:deck, account:)
    create_lot_in_zone(deck, "main")
    create(:lot, account:, location: create(:location, account:))

    expect { user.destroy! }.not_to raise_error
    expect([ Lot, Location, Deck ].map { it.where(account_id: account.id).count }).to eq([ 0, 0, 0 ])
  end

  it "declares lots before locations and decks, then deck proxies, after them (spec 062 AC-9.6, spec 068 AC-8.4)" do
    order = described_class.reflect_on_all_associations(:has_many).map(&:name) & %i[lots locations decks deck_proxies]

    expect(order).to eq(%i[lots locations decks deck_proxies])
  end

  describe "currency (spec 038)" do
    def default_to(code) = allow(Rails.configuration.x).to receive(:default_currency).and_return(Collector::Currency.fetch!(code))

    it "starts a new account at the instance default (AC-3.1, AC-3.2)", :aggregate_failures do
      expect(described_class.new.currency).to eq("USD")
      default_to("EUR")
      expect(described_class.new.currency).to eq("EUR")
    end

    it "accepts only one of the 20 codes, exactly as listed (FR-1)", :aggregate_failures do
      [ "XYZ", "eur", "", nil, "EUR " ].each do |code|
        expect(described_class.new(currency: code).tap(&:validate).errors[:currency]).to eq([ "Choose one of the listed currencies." ])
      end
      expect(build(:account, currency: "SEK")).to be_valid
    end

    it "answers its currency as a unit" do
      expect(described_class.new(currency: "EUR").currency_unit).to eq(Collector::Currency::Unit.new(code: "EUR", symbol: "€"))
    end

    it "blames its own column, not the setting, for a code it can't show" do
      expect { described_class.new(currency: "XYZ").currency_unit }.to raise_error(ArgumentError, /\Aaccounts\.currency "XYZ"/)
    end

    it "keeps its currency when the instance default changes (AC-3.3)" do
      account = create(:account)
      default_to("EUR")
      expect(account.reload.currency).to eq("USD")
    end
  end

  describe "household and kind (spec 090)" do
    it "needs a household (decision 8)" do
      expect(described_class.new.tap(&:validate).errors[:household]).to be_present
    end

    it "is personal by default and shared or personal only (AC-2.5)", :aggregate_failures do
      expect(create(:account).kind).to eq("personal")
      expect(build(:account, kind: "other")).not_to be_valid
      expect { described_class.connection.execute("UPDATE accounts SET kind = 'other' WHERE id = #{create(:account).id}") }.to raise_error(ActiveRecord::StatementInvalid, /accounts_kind_known/)
    end
  end
end
