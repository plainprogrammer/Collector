require "rails_helper"

# A day's file at realistic size (spec 089 AC-5.6): 110,000 cards, about 300,000 quotes, entries in the test database.
# A measurement, not a gate; the numbers are recorded in verification.md (#366 replaces them with the run's own).
RSpec.describe "the daily price refresh's time", :timing, type: :model do
  let(:count) { 110_000 }
  let(:stamp) { "20261113100623" }

  # Seconds one block takes. Not Benchmark: it is a bundled gem on this Ruby and the bundle doesn't list it.
  def realtime
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  def card_lines(shift)
    Array.new(count) do |index|
      scryfall_card("id" => "card-#{index}", "prices" => { "usd" => format("%.2f", 1 + index / 100.0 + shift.call(index)), "usd_foil" => (index.even? ? format("%.2f", 2 + index / 100.0) : nil), "eur" => format("%.2f", 1 + index / 120.0) })
    end
  end

  it "applies a first run and then a typical day", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one measured scenario
    set = create(:catalog_set, collectible_type: "mtg")
    identity = create(:catalog_identity, collectible_type: "mtg")
    now = Time.current
    Array.new(count) do |index|
      { collectible_type: "mtg", external_key: "card-#{index}", catalog_set_id: set.id, catalog_identity_id: identity.id, number: index.to_s, language: "en",
        name: "Card #{index}", kind: "card", content_digest: "d", created_at: now, updated_at: now }
    end.each_slice(1_000) { |rows| Catalog::Entry.insert_all(rows) } # one statement per 1,000: a single one would pass SQLite's statement size
    timings = {}

    stub_scryfall(cards: card_lines(->(_) { 0 }), stamp: stamp)
    timings[:first_run] = realtime { Prices::Refresh.new("scryfall").call }
    first = PriceRefreshRun.order(:id).last

    next_stamp = "20261114100623"
    stub_scryfall(cards: card_lines(->(index) { (index % 6).zero? ? 0.5 : 0 }), stamp: next_stamp) # about 17 percent change
    timings[:typical_day] = realtime { Prices::Refresh.new("scryfall").call }
    second = PriceRefreshRun.order(:id).last

    # rubocop:disable RSpec/Output -- the measurement is the point of this example
    puts "price refresh timing: #{timings.transform_values { it.round(1) }.inspect}, first #{first.attributes.slice(*PriceRefreshRun::COUNTS.map(&:to_s)).inspect}, second #{second.attributes.slice(*PriceRefreshRun::COUNTS.map(&:to_s)).inspect}"
    # rubocop:enable RSpec/Output
    expect(first.status).to eq("finished")
    expect(second).to have_attributes(status: "finished")
    expect(second.repriced).to be > 0
  ensure
    FileUtils.rm_rf(Rails.configuration.x.catalog_download_dir)
  end
end
