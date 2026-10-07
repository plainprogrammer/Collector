# The index build's figures as a fixture (spec 010 AC-1.5, AC-1.6): the fetch runs, the index metadata, sizes and agreement.
# Usage: CARD_SCANNER_WORK_DIR=… bundle exec ruby spikes/card_scanner/phase3/script/index_build.rb
require "bundler/setup"
require_relative "../lib/card_scanner_phase3"

work = CardScannerPhase2::WORK_DIR
fetches = work.glob("fetch_small_*.json").sort.map { JSON.parse(it.read).except("failed").merge("failed" => JSON.parse(it.read)["failed"].size) }
meta = JSON.parse(work.join("index/art_index_meta.json").read)
agreement = JSON.parse(work.join("agreement_small.json").read).except("results")
figures = { "index" => meta, "stored_bytes" => work.join("index/art_index.bin").size, "gzip_bytes" => work.join("index/art_index.bin.gz").size,
  "fetches" => fetches, "fetched_images" => fetches.sum { it["fetched"] }, "fetched_bytes" => fetches.sum { it["bytes"] },
  "fetch_seconds" => fetches.sum { it["seconds"] }.round(1), "agreement" => agreement }
CardScannerPhase3::FIXTURE_DIR.join("phase3_index_build.json").write(JSON.pretty_generate(figures))
puts JSON.pretty_generate(figures.except("fetches"))
