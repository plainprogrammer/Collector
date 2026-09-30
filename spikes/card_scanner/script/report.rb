# Prints the Story 1 and Story 3 tables as Markdown (AC-1.3, AC-1.5, AC-1.7, AC-3.3).
# Usage: bundle exec ruby spikes/card_scanner/script/report.rb <label> [<second label>]
require "bundler/setup"
require "json"
require_relative "../lib/card_scanner_spike"

def read_json(*path) = JSON.parse(File.read(File.join(*path)))
def run_dir(label) = File.join(CardScannerSpike::WORK_DIR, "replays", label)
def cell(text) = text.to_s.gsub("|", "\\|").tr("\n", " ")

label, other = ARGV
abort "usage: report.rb <label> [<second label>]" unless label
spike = CardScannerSpike
truth = read_json(spike::FIXTURE_DIR, "ground_truth.json").fetch("photos").to_h { [ it["file"], it ] }
results = read_json(run_dir(label), "ocr_results.json").fetch("results").select { truth.key?(it["file"]) }
matches = read_json(run_dir(label), "name_matches.json").fetch("matches").to_h { [ it["file"], it ] }
rows = results.map { truth.fetch(it["file"]).merge("result" => it, "match" => matches.fetch(it["file"])) }
with_set_line = rows.select { %w[M15–ONE MOM+].include?(it["era"]) }

puts "## Name strip read exactly (AC-1.3)", "",
  "Compared with the front-face name (`name_bar`), which is what the name bar prints; the strict catalog-name rate follows.", "",
  spike::Rates.markdown("Name read", spike::Rates.breakdown(rows) { spike::Scoring.name_read?(it["result"], it) }), "",
  spike::Rates.markdown("Catalog name", spike::Rates.breakdown(rows) { spike::Scoring.name_read?(it["result"], it.merge("name_bar" => it["name"])) })
puts "", "## Exact printing from the collector line, M15–ONE and MOM+ only (AC-1.3)", "",
  spike::Rates.markdown("Printing", spike::Rates.breakdown(with_set_line) { spike::Scoring.printing_identified?(it["result"], it) }),
  "", "Lookup outcomes: #{with_set_line.map { it.dig("result", "lookup", "status") }.tally}"
[ 1, 3 ].each do |count|
  puts "", "## Correct card in the top #{count} (AC-3.3)", "",
    spike::Rates.markdown("Top #{count}", spike::Rates.breakdown(rows) { spike::Scoring.in_top?(it["match"], it, count) })
end
times = rows.map { it.dig("match", "query_ms") }
puts "", "Query time: median #{spike::Scoring.percentile(times, 50)} ms, p95 #{spike::Scoring.percentile(times, 95)} ms (n=#{times.size})"
puts "", "## Not in the top 3 (AC-1.7)", "", "| File | Expected | Name strip | Collector strip | Top 3 | Likely cause |", "|---|---|---|---|---|---|"
rows.reject { spike::Scoring.in_top?(it["match"], it, 3) }.each do |row|
  top = row.dig("match", "candidates").first(3).map { it["card_name"] }.join("; ")
  puts "| #{row["file"]} | #{cell(row["name"])} | #{cell(row.dig("result", "name_text"))} | #{cell(row.dig("result", "collector_text"))} | #{cell(top)} | |"
end
if other
  diffs = spike::Scoring.differences(results, read_json(run_dir(other), "ocr_results.json").fetch("results"))
  puts "", "## Replay #{label} vs #{other} (AC-1.5)", "", "#{diffs.map { it["file"] }.uniq.size} of #{results.size} photos differ"
  diffs.each { puts "- #{it["file"]} #{it["field"]}: #{it["a"].inspect} vs #{it["b"].inspect}" }
end
