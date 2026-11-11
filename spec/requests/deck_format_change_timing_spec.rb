require "rails_helper"

# Spec 064 NFR Performance: changing a deck's format when the dropped zone holds 5,000 lots, 400 of them merging into lots
# already in Considering, in under 2 seconds of server time. Measured, never gating (run with SCANNER_TIMING=1); the result
# goes in verification.md.
RSpec.describe "Deck format change timing", :timing, type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }

  # Lots of 1,000 printings in +location+, +count+ of them, each printing priced 0, 1, 2 ... so that no two lots share an identity.
  def insert_lots(location, entries, count:)
    now = Time.current
    rows = Array.new(count) do |i|
      price = i / entries.size
      { account_id: account.id, catalog_entry_id: entries[i % entries.size], quantity: 1 + (i % 4), finish: "nonfoil", price_paid_cents: price,
        location_id: location.id, lot_key: Lot.key_for("nonfoil", nil, price, location.id), created_at: now, updated_at: now }
    end
    rows.each_slice(1_000) { Lot.insert_all(it) }
    rows
  end

  it "moves 5,000 lots out of a dropped zone, 400 merging, in under 2 s", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- a measured scenario: seed, change, count
    entries = Array.new(1_000) { |i| create(:mtg_printing, entry: create(:catalog_entry, name: "Card #{i}")).entry.id }
    deck = create(:deck, account:, name: "Krenko", format: "commander")
    insert_lots(deck.zone("commander"), entries, count: 5_000)
    considering = deck.zone("considering")
    merging = insert_lots(considering, entries, count: 400) # the first 400 moved lots (price 0) find these
    before = [ account.lots.count, account.lots.sum(:quantity) ]
    change = Deck::FormatChange.new(deck:, format: "mtg/modern")

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    change.save!
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

    after = [ account.lots.count, account.lots.sum(:quantity) ]
    RSpec.configuration.reporter.message format("format change %d lots -> %d lots, %d copies kept, %d copies moved, %d ms", before.first, after.first, after.last, change.moved, elapsed)
    expect(merging.size).to eq(400)
    expect(after).to eq([ before.first - 400, before.last ]) # 400 lots merged, no copy lost
    expect(account.lots.where.not(location_id: considering.id)).to be_empty # every lot is in Considering now
    expect(elapsed).to be < 2_000
  end
end
