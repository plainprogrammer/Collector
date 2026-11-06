require "rails_helper"

# Spec 037 NFR Performance: the collection page under a location filter, 5,000 lots over 300 locations, with two other
# accounts' lots in the same table. Measured, never gating (run with SCANNER_TIMING=1); the results go in verification.md.
RSpec.describe "Collection location filter timing", :timing, type: :request do
  let(:user) { create(:user) }

  def seed(account, entries, count: 5_000, places: 300)
    locations = Array.new(places) { |i| account.locations.create!(name: "Place #{i}") }
    now = Time.current
    rows = Array.new(count) do |i|
      location_id = (locations[i % places].id unless (i % 10).zero?) # a tenth unplaced
      { account_id: account.id, catalog_entry_id: entries[i % entries.size], quantity: 1 + (i % 4), finish: "nonfoil",
        price_paid_cents: i, location_id:, lot_key: Lot.key_for("nonfoil", nil, i, location_id), created_at: now, updated_at: now }
    end
    rows.each_slice(1_000) { Lot.insert_all(it) }
    locations
  end

  def median_ms(path, runs: 5)
    get path # warm
    Array.new(runs) { elapsed_ms { get path } }.sort[runs / 2].round
  end

  def elapsed_ms
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
  end

  it "stays under 500 ms with a location filter on" do
    entries = Array.new(1_500) { |i| create(:mtg_printing, entry: create(:catalog_entry, name: "Card #{i}")).entry.id }
    2.times { seed(create(:user).account, entries) }
    locations = seed(user.account, entries)
    sign_in_as(user)
    place = locations[7].id
    results = {
      "grid, all" => collection_path(view: "grid"), "grid, one location" => collection_path(view: "grid", location: place),
      "grid, none" => collection_path(view: "grid", location: "none"), "table, all" => collection_path(view: "table"),
      "table, one location" => collection_path(view: "table", location: place), "table, none" => collection_path(view: "table", location: "none"),
      "bulk, one location" => collection_path(bulk: 1, location: place)
    }.transform_values { |path| [ median_ms(path), count_queries { get path } ] }
    results.each { |name, (ms, statements)| RSpec.configuration.reporter.message format("%-22s %4d ms  %2d statements", name, ms, statements) }
    expect(results.values.map(&:first)).to all(be < 500)
  end
end
