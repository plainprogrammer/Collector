require "rails_helper"

# Spec 068 decisions 1, 2, 4, 19 and Story 8: the proxy row, its creation-time rules and its merge.
RSpec.describe Deck::Proxy, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }
  let(:zone) { deck.zone("main") }
  let(:entry) { create(:mtg_printing).entry } # the factory's finishes: foil and nonfoil

  def add(quantity: 1, finish: "foil", zone: self.zone, entry: self.entry) = described_class.add!(account:, zone:, entry:, finish:, quantity:)

  it "is saved with a zone of the account, a listed finish and a quantity from 1 to 9,999 (AC-8.2)", :aggregate_failures do
    proxy = add(quantity: 2)

    expect(proxy).to be_persisted
    expect([ proxy.zone, proxy.entry, proxy.finish, proxy.quantity ]).to eq([ zone, entry, "foil", 2 ])
    expect(Lot.count).to eq(0)
  end

  it "refuses what AC-8.2 lists", :aggregate_failures do
    other = create(:user).account
    place = create(:location, account:)
    other_deck_zone = create(:deck, account: other, name: "Theirs").zone("main")
    other_type_entry = create(:catalog_entry, collectible_type: "other")

    expect { add(quantity: 0) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { add(quantity: 10_000) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { add(zone: place) }.to raise_error(ActiveRecord::RecordInvalid)             # a place is no zone
    expect { add(zone: deck.location) }.to raise_error(ActiveRecord::RecordInvalid)     # nor is a deck's own row
    expect { add(zone: other_deck_zone) }.to raise_error(ActiveRecord::RecordInvalid)   # another account's zone
    expect { add(finish: nil) }.to raise_error(ActiveRecord::RecordInvalid, /Choose a finish/)
    expect { add(finish: "etched") }.to raise_error(ActiveRecord::RecordInvalid, /isn't available/)
    expect { add(entry: other_type_entry) }.to raise_error(ActiveRecord::RecordInvalid)  # another collectible than the deck's
    expect(described_class.count).to eq(0)
  end

  it "accepts no finish for a printing that lists none (decision 2)" do
    bare = create(:mtg_printing, finishes: []).entry

    expect(add(entry: bare, finish: nil).finish).to be_nil
  end

  it "merges an add into the proxy of the same zone, printing and finish, keeping its id (AC-1.6)", :aggregate_failures do
    first = add(quantity: 2)
    second = add(quantity: 3)
    other_finish = add(quantity: 1, finish: "nonfoil")

    expect(second.id).to eq(first.id)
    expect(first.reload.quantity).to eq(5)
    expect(other_finish.id).not_to eq(first.id)
    expect(described_class.count).to eq(2)
  end

  it "merges proxies that have no finish too (the unique index holds for a NULL finish)" do
    bare = create(:mtg_printing, finishes: []).entry
    add(entry: bare, finish: nil, quantity: 1)
    add(entry: bare, finish: nil, quantity: 1)

    expect(described_class.where(catalog_entry_id: bare.id).pluck(:quantity)).to eq([ 2 ])
  end

  it "refuses an add past 9,999 and changes nothing (AC-1.9)", :aggregate_failures do
    proxy = add(quantity: 9_990)

    expect { add(quantity: 10) }.to raise_error(ActiveRecord::RecordInvalid, /#{Regexp.escape(described_class::FULL_MESSAGE)}/)
    expect(proxy.reload.quantity).to eq(9_990)
  end

  it "wins a race on the unique index by merging (AC-1.9)" do
    add(quantity: 1)
    calls = 0
    allow(described_class).to receive(:find_by).and_wrap_original do |original, *args, **kwargs|
      calls += 1
      calls == 1 ? nil : original.call(*args, **kwargs) # the first read misses the row another request just wrote
    end

    add(quantity: 2)

    expect(described_class.pluck(:quantity)).to eq([ 3 ])
  end

  it "is removed with its zone and its deck, and deleted with the account (decision 1, AC-8.4)", :aggregate_failures do
    add
    expect { deck.remove! }.to change(described_class, :count).from(1).to(0)

    other_account = create(:user).account
    other = create(:deck, account: other_account, name: "Other")
    described_class.add!(account: other_account, zone: other.zone("main"), entry:, finish: "foil", quantity: 1)
    expect { other_account.user.destroy! }.to change(described_class, :count).from(1).to(0) # the user's account is destroyed with it
  end

  it "doesn't revalidate a stored proxy against the catalog (decision 2)" do
    proxy = add
    entry.extension.update!(finishes: %w[nonfoil]) # a refresh dropped foil

    expect(proxy.reload.update(quantity: 4)).to be(true)
  end
end
