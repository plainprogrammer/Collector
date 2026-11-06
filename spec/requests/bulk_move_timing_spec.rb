require "rails_helper"

# Spec 041 AC-4.4, NFR Performance: moving every matching lot of 5,000 lots, over 300 locations, many merging into lots
# already in the destination, in under 2 seconds of server time. Measured, never gating (run with SCANNER_TIMING=1); the
# result goes in verification.md.
RSpec.describe "Bulk move timing", :timing, type: :request do
  let(:user) { create(:user) }

  def seed(account, entries, count: 5_000, places: 300)
    locations = Array.new(places) { |i| account.locations.create!(name: "Place #{i}") }
    now = Time.current
    rows = Array.new(count) do |i|
      location = locations[i % places]
      price = i / 3_000
      { account_id: account.id, catalog_entry_id: entries[i % entries.size], quantity: 1 + (i % 4), finish: "nonfoil", price_paid_cents: price,
        location_id: location.id, lot_key: Lot.key_for("nonfoil", nil, price, location.id), created_at: now, updated_at: now }
    end
    rows.each_slice(1_000) { Lot.insert_all(it) }
    locations
  end

  it "moves 5,000 lots to one location in under 2 s", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- a measured scenario: seed, move, count
    entries = Array.new(1_000) { |i| create(:mtg_printing, entry: create(:catalog_entry, name: "Card #{i}")).entry.id }
    2.times { seed(create(:user).account, entries) }
    locations = seed(user.account, entries)
    destination = locations.first
    now = Time.current
    extra = (1..400).reject { |i| (i % 100).zero? }.map do |i| # printings the destination doesn't hold: later moves merge into these
      { account_id: user.account.id, catalog_entry_id: entries[i], quantity: 1, finish: "nonfoil", price_paid_cents: 0, location_id: destination.id,
        lot_key: Lot.key_for("nonfoil", nil, 0, destination.id), created_at: now, updated_at: now }
    end
    Lot.insert_all(extra)
    sign_in_as(user)

    post collection_selection_path
    patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: "", all_rendered: "0", all: "1", header_toggled: "1", shown_ids: [], ticked_ids: [] }
    before = [ user.account.lots.count, user.account.lots.sum(:quantity) ]
    statements = 0
    counter = ->(*, payload) { statements += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { post collection_move_path, params: { to: destination.id } }
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

    after = [ user.account.lots.count, user.account.lots.sum(:quantity) ]
    RSpec.configuration.reporter.message format("move %d lots -> %d lots, %d copies kept, %d ms, %d statements", before.first, after.first, after.last, elapsed, statements)
    expect(response).to have_http_status(:see_other)
    expect(after.last).to eq(before.last) # no copy lost
    expect(user.account.lots.where.not(location_id: destination.id)).to be_empty
    expect(elapsed).to be < 2_000
  end
end
