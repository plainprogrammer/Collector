# Parses each replayed collector strip, looks up the printing, and queries the name index (AC-1.2, AC-3.3).
# Usage: bin/rails runner spikes/card_scanner/script/match.rb <label>
require_relative "../lib/card_scanner_spike"
require_relative "../lib/card_scanner_spike/printing_lookup"
require_relative "../lib/card_scanner_spike/name_index"

label = ARGV.fetch(0) { abort "usage: match.rb <label>" }
dir = File.join(CardScannerSpike::WORK_DIR, "replays", label)
replay = JSON.parse(File.read(File.join(dir, "ocr.json")))
known = CardScannerSpike::PrintingLookup.known_set_codes
lookup = CardScannerSpike::PrintingLookup.new
index = CardScannerSpike::NameIndex.new(File.join(CardScannerSpike::WORK_DIR, "names.sqlite3"))
abort "Build the name index first (build_name_index.rb)" if index.count.zero?

results = replay.fetch("results").map do |result|
  parsed = CardScannerSpike::CollectorLine.parse(result["collector_text"], known_set_codes: known)
  outcome = lookup.call(set_code: parsed.set_code, number: parsed.number, language: parsed.language)
  result.merge("run" => label,
    "parsed" => parsed.to_h.to_h { |key, value| [ key.to_s, value.is_a?(Symbol) ? value.to_s : value ] },
    "lookup" => { "status" => outcome.status.to_s, "external_keys" => outcome.entries.map(&:external_key) })
end
matches = replay.fetch("results").map do |result|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  candidates = index.search(result["name_text"])
  query_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
  { "file" => result["file"], "query" => result["name_text"], "query_ms" => query_ms,
    "candidates" => candidates.map { it.to_h.transform_keys(&:to_s) } }
end
File.write(File.join(dir, "ocr_results.json"), JSON.pretty_generate({ "format_version" => 1, "run" => label, "results" => results }))
File.write(File.join(dir, "name_matches.json"), JSON.pretty_generate({ "format_version" => 1, "run" => label, "matches" => matches }))
puts "#{results.size} results -> #{dir}"
