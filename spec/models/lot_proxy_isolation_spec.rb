require "rails_helper"

# Spec 068 decision 11 (closing spec 065 decision 11): no way of adding, moving, editing, bulk-moving, typing, scanning or
# removing a copy changes a proxy, and a catalog refresh doesn't either. The proxy is checked by id, quantity and times.
RSpec.describe "Proxies and the ways copies reach a zone", type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }
  let(:entry) { create(:mtg_printing).entry }
  let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 3) }

  def unchanged? = Deck::Proxy.sole.slice(:id, :quantity, :updated_at) == proxy.slice(:id, :quantity, :updated_at)

  # rubocop:disable RSpec/ExampleLength -- one scenario walks every way a copy reaches a zone, checking the proxy after each
  it "leaves the proxy as it is when a copy is added, moved, edited, bulk-moved, typed in, scanned in or removed", :aggregate_failures do
    lot = Lot.add!(account:, entry:, quantity: 2, finish: "foil", location: deck.zone("main"))
    expect(unchanged?).to be(true)
    elsewhere = create(:location, account:)
    Lot::Move.new(lot:, to: elsewhere, copies: "1").call!
    Lot::Move.new(lot: Lot.find_by!(location: elsewhere), to: deck.zone("main"), copies: "1").call!
    expect(unchanged?).to be(true)
    lot.reload.revise!(quantity: 4)
    expect(unchanged?).to be(true)
    Lot::BulkMove.new(account:, lots: account.lots, to: deck.zone("sideboard"), sort: CollectionTable::Sort.parse(nil, nil)).apply!
    expect(unchanged?).to be(true)
    NumberEntry.add!(account:, entry:, quantity: 1, finish: "foil", line_key: SecureRandom.hex(16), location: deck.zone("main"))
    expect(unchanged?).to be(true)
    account.lots.destroy_all
    expect(unchanged?).to be(true)
    expect(Deck::Proxy.count).to eq(1)
  end
  # rubocop:enable RSpec/ExampleLength

  it "survives a catalog refresh that retires the printing (AC-4.3)", :aggregate_failures do
    entry.update!(retired_at: Time.current)

    expect(unchanged?).to be(true)
    expect(proxy.reload.entry).to eq(entry)
  end
end
