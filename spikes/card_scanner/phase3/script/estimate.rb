# Commits the full fetch's estimate (spec 010 AC-1.2) from the listed artworks and the cache, fetching nothing.
# Usage: CARD_SCANNER_WORK_DIR=… bundle exec ruby spikes/card_scanner/phase3/script/estimate.rb
require "bundler/setup"
require "time"
require_relative "../lib/card_scanner_phase3"
require_relative "../lib/card_scanner_phase3/estimate"
require_relative "../../phase2/lib/card_scanner_phase2/bulk_artworks"

data = CardScannerPhase2::BulkArtworks.load
cache = CardScannerPhase2::WORK_DIR.join("artwork", "small")
estimate = CardScannerPhase3::Estimate.call(data["artworks"], cached: ->(id) { cache.join("#{id}.jpg").file? })
  .merge("bulk_version" => data["bulk_version"], "counts" => data["counts"], "at" => Time.now.utc.iso8601)
CardScannerPhase3::FIXTURE_DIR.join("phase3_fetch_estimate.json").write(JSON.pretty_generate(estimate))
puts JSON.pretty_generate(estimate)
