require "rails_helper"

# Spec 070 decision 2 (spec 057's "Free to use"): a lot is free when it is in no deck zone.
RSpec.describe Lot, ".free", type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }

  it "holds the unplaced lots and the lots of a place, and no lot in a zone, Considering included", :aggregate_failures do
    unplaced = create(:lot, account:)
    in_a_place = create(:lot, account:, location: create(:location, account:))
    in_main = create_lot_in_zone(deck, "main")
    in_considering = create_lot_in_zone(deck, "considering")

    expect(account.lots.free).to contain_exactly(unplaced, in_a_place)
    expect(account.lots).to include(in_main, in_considering) # the fixture could have produced them
  end

  it "chains with the account's lots and other conditions, and leaves the account scoping to the caller", :aggregate_failures do
    mine = create(:lot, account:)
    other = create(:user).account
    theirs = create(:lot, account: other, location: create(:location, account: other))

    expect(account.lots.free.where(catalog_entry_id: mine.catalog_entry_id)).to contain_exactly(mine)
    expect(described_class.free).to include(mine, theirs)
  end
end
