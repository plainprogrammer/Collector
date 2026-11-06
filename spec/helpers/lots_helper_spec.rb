require "rails_helper"

# Spec 038 decision 8: a lot's price is written in the signed-in account's currency.
RSpec.describe LotsHelper, type: :helper do
  let(:user) { create(:user) }

  before { Current.session = user.sessions.create! }

  describe "#lot_price" do
    it "writes the account's symbol (AC-1.4)", :aggregate_failures do
      lot = build(:lot, account: user.account, price_paid_cents: 1250)
      expect(helper.lot_price(lot)).to eq("$12.50")
      user.account.update!(currency: "EUR")
      expect(helper.lot_price(lot)).to eq("€12.50")
    end

    it "writes a dash for no price" do
      expect(helper.lot_price(build(:lot, account: user.account, price_paid_cents: nil))).to eq("—")
    end
  end

  describe "#lot_line" do
    it "ends a priced lot in the account's currency (AC-1.4)" do
      user.account.update!(currency: "EUR")
      expect(helper.lot_line(create(:lot, account: user.account, price_paid_cents: 1250))).to end_with(" · €12.50")
    end
  end
end
