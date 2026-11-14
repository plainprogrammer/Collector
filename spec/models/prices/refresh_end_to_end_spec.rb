require "rails_helper"

# The refresh through the real catalog source and the real price source, over a stubbed Scryfall (spec 089 AC-4.5, AC-1.1,
# AC-1.7): the file's quotes become rows, and no request happens inside a transaction.
RSpec.describe "the daily price refresh over the real sources", type: :model do
  let(:stamp) { "20261113100623" }

  def cards(prices_by_id) = prices_by_id.map { |id, prices| scryfall_card("id" => id, "prices" => prices) }

  around do |example|
    example.run
  ensure
    FileUtils.rm_rf(Rails.configuration.x.catalog_download_dir)
  end

  it "downloads once, applies the file's quotes dated by its name, and makes no request inside a transaction (AC-4.5)", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario
    one = create(:catalog_entry, collectible_type: "mtg", external_key: "card-1")
    two = create(:catalog_entry, collectible_type: "mtg", external_key: "card-2")
    stub_scryfall(cards: cards("card-1" => { "usd" => "1.42", "usd_foil" => "3.10", "eur" => nil }, "card-2" => { "usd" => "0.05" }), stamp:)
    connections = [ ApplicationRecord.lease_connection, PricesRecord.lease_connection ]
    baselines = connections.map(&:open_transactions)
    inside = []
    seen = 0
    callback = lambda do |request, _response|
      seen += 1
      inside << request.uri.to_s if connections.zip(baselines).any? { |connection, baseline| connection.open_transactions > baseline }
    end
    WebMock.after_request(&callback)

    run = Prices::Refresh.new("scryfall").call

    expect(seen).to be >= 2 # the bulk-data index and the file
    expect(inside).to be_empty
    expect(run).to have_attributes(status: "finished", run_on: Date.new(2026, 11, 13), source_version: "default-cards-#{stamp}", added: 3, quotes_seen: 3)
    expect(CurrentPrice.where(catalog_entry_id: one.id).order(:price_series_id).pluck(:cents)).to contain_exactly(142, 310)
    expect(CurrentPrice.where(catalog_entry_id: two.id).pluck(:cents)).to eq([ 5 ])
    expect(PriceChange.pluck(:recorded_on).uniq).to eq([ Date.new(2026, 11, 13) ])
  ensure
    WebMock::CallbackRegistry.callbacks.reject! { |entry| entry[:block].equal?(callback) } # only this example's, never VCR's
  end

  it "changes nothing when the same file is read again (AC-1.7)", :aggregate_failures do
    create(:catalog_entry, collectible_type: "mtg", external_key: "card-1")
    stub_scryfall(cards: cards("card-1" => { "usd" => "1.42" }), stamp:)
    Prices::Refresh.new("scryfall").call
    before = [ CurrentPrice.pluck(:cents, :changed_on), PriceChange.pluck(:cents, :recorded_on) ]

    run = Prices::Refresh.new("scryfall").call

    expect(run).to have_attributes(status: "skipped", error: "default-cards-#{stamp} already applied")
    expect(a_request(:get, /data\.scryfall\.io/)).to have_been_made.once # the file is not downloaded again
    expect([ CurrentPrice.pluck(:cents, :changed_on), PriceChange.pluck(:cents, :recorded_on) ]).to eq(before)
  end
end
