# Times the pure-Ruby search for each photo's browser-made hashes, and checks it ranks the same first artwork (AC-3.7).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/search_server.rb <art run>
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/fingerprint"
require_relative "../lib/card_scanner_phase2/art_index"

run_dir = CardScannerPhase2.runs_dir.join(ARGV.fetch(0) { abort "usage: search_server.rb <art run>" })
index = CardScannerPhase2::ArtIndex.read(CardScannerPhase2::WORK_DIR.join("index"))
rows = run_dir.glob("*/art.json").map { JSON.parse(it.read) }.select { it["hashes"] }.sort_by { it["file"] }.map do |record|
  hashes = record["hashes"].map { [ it ].pack("H*") }
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ranked = index.search(hashes, limit: 10)
  ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  { "file" => record["file"], "ms" => ms.round(1), "same_first" => ranked.first["id"] == record["art"].first["id"], "browser_ms" => record["msSearch"] }
end
ms = rows.map { it["ms"] }.sort
summary = { "n" => rows.size, "index_count" => index.size, "median_ms" => ms[ms.size / 2], "max_ms" => ms.last, "same_first" => rows.count { it["same_first"] },
  "timed_span" => "ArtIndex#search over the loaded index: six Hamming distances per artwork and the top-10 sort; excludes loading the index", "rows" => rows }
run_dir.join("search_server.json").write(JSON.pretty_generate(summary))
puts summary.except("rows").to_json
