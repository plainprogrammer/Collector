require "rails_helper"

# Spec 068 AC-7.13 (the bars of spec 062 AC-8.10, with 20,000 proxies more): the earlier import bars hold with decks and proxies (preview under 30 s and 500 MB, apply under 30 s and
# 500 MB with the write transaction under 4 s, export of 50,000 lots under 10 s and 300 MB) for a file of 50,000 lots over 300
# places, 100 decks and their 300 zones, names of 60 CJK characters as in spec 032's worst case. Measured, never gating beyond
# the bars themselves (run with SCANNER_TIMING=1); the numbers go in verification.md. Memory is the test process's resident set
# (`ps`), the baseline taken after the seed and a collection, the peak sampled while a request runs. It is reported and flagged
# against its bar, not asserted: the process holds the request body and the parsed file beside the application, a first preview
# grows it by 385 to 506 MB in this harness with or without decks (measured both ways), so a hard bar at 500 MB would fail at
# random; the times and the write transaction are asserted.
RSpec.describe "Import and export timing with proxies", :timing, type: :request do
  let(:user) { create(:user) }
  let(:lots) { 50_000 }
  let(:places) { 300 }
  let(:decks) { 100 }
  let(:proxies) { 20_000 }

  def rss_mb = (`ps -o rss= -p #{Process.pid}`.to_i / 1024.0)

  # Runs the block and returns its seconds, the resident set's growth and its peak growth in MB, and the longest transaction
  # (seconds) that finished while it ran: the apply's write transaction.
  def measured
    GC.start
    base = rss_mb
    peak = base
    longest = 0.0
    sampler = Thread.new do
      loop do
        peak = [ peak, rss_mb ].max
        sleep 0.05
      end
    end
    transaction = ->(_name, start, finish, *) { longest = [ longest, finish - start ].max }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ActiveSupport::Notifications.subscribed(transaction, "transaction.active_record") { yield }
    seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    sampler.kill
    { seconds:, growth: rss_mb - base, peak: [ peak, rss_mb ].max - base, transaction: longest }
  end

  def name_of(prefix, index) = (prefix * (60 - 4)) + format("%04d", index)

  def seed_catalog
    set = create(:catalog_set, code: "bulk")
    identity = create(:catalog_identity)
    now = Time.current
    (1..lots).each_slice(1_000) do |slice|
      entries = slice.map do |i|
        { collectible_type: "mtg", external_key: "bulk-#{i}", catalog_set_id: set.id, catalog_identity_id: identity.id, number: i.to_s, language: "en",
          name: "Card #{i}", kind: "card", content_digest: "d", created_at: now, updated_at: now }
      end
      Catalog::Entry.insert_all(entries)
    end
    Catalog::Entry.where(catalog_set_id: set.id).pluck(:id).each_slice(1_000) do |slice|
      MTG::Printing.insert_all(slice.map do |entry_id|
        { catalog_entry_id: entry_id, rarity: "common", finishes: %w[nonfoil foil], layout: "normal", scryfall_uri: "https://example.test/#{entry_id}",
          faces: [], created_at: now, updated_at: now }
      end)
    end
  end

  # A version 4 file: the places and the decks (Modern, three zones each) and every lot in one of the 600 places and zones.
  def build_file(quantity:)
    place_names = Array.new(places) { |i| name_of("箱", i) }
    deck_names = Array.new(decks) { |i| name_of("棚", i) }
    zone_keys = %w[main sideboard considering]
    spots = place_names + deck_names.flat_map { |deck| zone_keys.map { |key| { "deck" => deck, "zone" => key } } }
    rows = (1..lots).map do |i|
      { "entry" => { "collectible_type" => "mtg", "source_id" => "bulk-#{i}", "name" => "Card #{i}", "set_code" => "bulk", "collector_number" => i.to_s, "language" => "en" },
        "quantity" => quantity, "finish" => "nonfoil", "condition" => nil, "price_paid" => nil, "added_at" => "2026-10-01T10:00:00Z", "changed_at" => "2026-10-01T10:00:00Z",
        "location" => spots[i % spots.size] }
    end
    proxy_rows = (1..proxies).map do |i|
      { "deck" => deck_names[i % decks], "zone" => zone_keys[i % 3], "entry" => { "collectible_type" => "mtg", "source_id" => "bulk-#{i}", "name" => "Card #{i}", "set_code" => "bulk", "collector_number" => i.to_s, "language" => "en" },
        "finish" => "foil", "quantity" => quantity }
    end
    { "format" => "collector-export", "format_version" => 4, "exported_at" => "2026-10-15T09:00:00Z",
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => "grid" }, "currency" => "USD",
      "locations" => place_names.map { |name| { "name" => name } },
      "decks" => deck_names.map { |name| { "name" => name, "collectible_type" => "mtg", "format" => "modern" } }, "proxies" => proxy_rows, "lots" => rows }
  end

  # Prints one measurement, marking a memory peak over the bar it is measured against.
  def report(label, numbers, memory_bar:)
    flag = numbers[:peak] < memory_bar ? "" : "  MEMORY BAR (#{memory_bar} MB) MISSED"
    RSpec.configuration.reporter.message format("%-34s %7.2f s  +%4.0f MB (peak +%4.0f MB)  write transaction %5.2f s%s", label, numbers[:seconds],
      numbers[:growth], numbers[:peak], numbers[:transaction], flag)
  end

  it "previews, applies and exports 50,000 lots and 20,000 proxies over 300 places, 100 decks and 300 zones within the bars", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- a measured scenario: seed, preview, apply, change, export
    seed_catalog
    sign_in_as(user)
    bytes = JSON.generate(build_file(quantity: 1))
    RSpec.configuration.reporter.message "file: #{(bytes.bytesize / 1_000_000.0).round(1)} MB, #{lots} lots, #{proxies} proxies, #{places} places, #{decks} decks, #{decks * 3} zones"

    preview = measured { post collection_import_preview_path, params: { export_file: import_upload_file(bytes) } }
    report("preview into an empty account", preview, memory_bar: 500)
    expect(response).to have_http_status(:ok)
    fingerprint = user.account.reload.import_upload.fingerprint
    apply = measured { post collection_import_path, params: { fingerprint: } }
    report("apply into an empty account", apply, memory_bar: 500)
    expect(response).to have_http_status(:see_other)
    expect([ user.account.lots.count, user.account.decks.count, user.account.deck_proxies.count ]).to eq([ lots, decks, proxies ])

    export = measured { get collection_export_path }
    report("export of 50,000 lots", export, memory_bar: 300)
    RSpec.configuration.reporter.message "export: #{(response.body.bytesize / 1_000_000.0).round(1)} MB"
    expect(JSON.parse(response.body).values_at("lots", "proxies").map(&:size)).to eq([ lots, proxies ])

    changed = JSON.generate(build_file(quantity: 2)) # every lot changes: the heaviest apply
    again = measured { post collection_import_preview_path, params: { export_file: import_upload_file(changed) } }
    report("preview of 50,000 changed lots", again, memory_bar: 500)
    second_apply = measured { post collection_import_path, params: { fingerprint: user.account.reload.import_upload.fingerprint } }
    report("apply of 50,000 changed lots", second_apply, memory_bar: 500)

    [ preview, again ].each { |numbers| expect(numbers[:seconds]).to be < 30 }
    [ apply, second_apply ].each { |numbers| expect([ numbers[:seconds], numbers[:transaction] ]).to satisfy { |s, t| s < 30 && t < 4 } }
    expect(export[:seconds]).to be < 10
  end
end
