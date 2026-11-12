require "rails_helper"

# Spec 070 Story 4 at the model: a new copy added to the proxy's zone, the proxy lowered by the same quantity.
RSpec.describe Deck::Proxy::AddCopy, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:zone) { deck.zone("main") }
  let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil]).entry }
  let!(:proxy) { create(:deck_proxy, zone:, account:, entry:, finish: "foil", quantity: 3) }

  def form(**attrs) = Lot::Form.new(entry:, **{ quantity: "1", finish: "foil" }.merge(attrs))
  def add(form = self.form, shown: proxy.quantity.to_s) = described_class.new(proxy:, form:, shown_quantity: shown)

  it "adds the lot to the zone, merging into the zone's lot of that identity, and lowers the proxy", :aggregate_failures do
    in_zone = create(:lot, account:, entry:, location: zone, finish: "foil", quantity: 2)

    expect(add(form(quantity: "2")).save).to be(true)

    expect(in_zone.reload.quantity).to eq(4)
    expect(proxy.reload.quantity).to eq(1)
    expect(account.lots.count).to eq(1)
  end

  it "adds a new lot with the form's finish, condition and price, and removes the proxy at zero", :aggregate_failures do
    expect(add(form(quantity: "3", finish: "nonfoil", condition: "near_mint", price_paid: "1.25")).save).to be(true)

    expect(account.lots.find_by(location: zone)).to have_attributes(entry:, quantity: 3, finish: "nonfoil", condition: "near_mint", price_paid_cents: 125)
    expect(Deck::Proxy.exists?(proxy.id)).to be(false)
  end

  it "lowers the proxy in the path whatever the copy's finish and no other proxy of the row", :aggregate_failures do
    other = create(:deck_proxy, zone:, account:, entry:, finish: "nonfoil", quantity: 2)

    add(form(quantity: "1", finish: "nonfoil")).save

    expect([ proxy.reload.quantity, other.reload.quantity ]).to eq([ 2, 2 ])
  end

  it "refuses a quantity over the proxy's count, after the form's own sentences", :aggregate_failures do
    over = add(form(quantity: "4"))
    huge = add(form(quantity: "10000"))

    expect([ over.save, huge.save ]).to eq([ false, false ])
    expect(over.form.errors[:quantity]).to eq([ "Enter a number from 1 to 3." ])
    expect(huge.form.errors[:quantity]).to eq([ "must be a whole number from 1 to 9,999" ]) # Add a copy's sentence wins
    expect(account.lots.count).to eq(0)
  end

  it "refuses when the proxy is not the count the form showed, and shows the count now (a second submit)", :aggregate_failures do
    first = add(form(quantity: "1"))
    expect(first.save).to be(true)

    again = add(form(quantity: "1"), shown: "3")

    expect(again.save).to be(false)
    expect(again.form.errors[:quantity]).to eq([ "This proxy changed. Check the quantity and try again." ])
    expect([ proxy.reload.quantity, account.lots.sum(:quantity) ]).to eq([ 2, 1 ])
  end

  it "says the proxy changed after the form's own sentence when both apply (decision 10)", :aggregate_failures do
    stale = add(form(quantity: "1", price_paid: "-1"), shown: "5")

    expect(stale.save).to be(false)
    expect(stale.form.errors[:price_paid]).to be_present
    expect(stale.form.errors[:quantity]).to eq([ "This proxy changed. Check the quantity and try again." ])
    expect(account.lots.count).to eq(0)
  end

  it "fails closed on a missing shown count", :aggregate_failures do
    expect(add(form, shown: nil).save).to be(false)
    expect(account.lots.count).to eq(0)
  end

  it "refuses a merge past 9,999 and changes neither the lot nor the proxy", :aggregate_failures do
    create(:lot, account:, entry:, location: zone, finish: "foil", quantity: 9_999)
    refused = add(form(quantity: "1"))

    expect(refused.save).to be(false)
    expect(refused.form.errors[:quantity]).to include(Lot::FULL_MESSAGE)
    expect(proxy.reload.quantity).to eq(3)
  end

  it "answers RecordNotFound for a proxy removed meanwhile", :aggregate_failures do
    pending_add = add
    proxy.destroy!

    expect { pending_add.save }.to raise_error(ActiveRecord::RecordNotFound)
    expect(account.lots.count).to eq(0)
  end
end
