require "rails_helper"

RSpec.describe Account, type: :model do
  it "deletes its lots before its locations, so lots in locations don't block it (spec 032 AC-6.6)", :aggregate_failures do
    user = create(:user)
    account = user.account
    2.times { create(:lot, account:, location: create(:location, account:)) }
    expect { user.destroy! }.not_to raise_error
    expect([ Lot.where(account_id: account.id).count, Location.where(account_id: account.id).count, described_class.exists?(account.id) ]).to eq([ 0, 0, false ])
  end
end
