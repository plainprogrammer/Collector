# Scores a replay (spec 010 Story 4) and, with FIXTURES=1, writes phase3_art_results.json. Also compares two replays for
# determinism (AC-4.8). Usage: bin/rails runner spikes/card_scanner/phase3/script/art_findings.rb <label> [<second label>]
require_relative "../lib/card_scanner_phase3"
require_relative "../lib/card_scanner_phase3/artwork_owners"
require_relative "../lib/card_scanner_phase3/art_findings"
require_relative "../../phase2/lib/card_scanner_phase2/bulk_artworks"

label, second = ARGV
replay = JSON.parse(CardScannerPhase3.runs_dir.join(label, "results.json").read)
data = CardScannerPhase2::BulkArtworks.load
owners = CardScannerPhase3::ArtworkOwners.read(CardScannerPhase2::BulkArtworks.latest_bulk_file)
truth = JSON.parse(CardScannerPhase3.sitting_dir.join("ground_truth.json").read).fetch("photos").to_h { [ it["file"], it ] }
fixtures = Rails.root.join("spec/fixtures/card_scanner")
lookups = JSON.parse(fixtures.join("phase2_sitting_ocr_results.json").read).fetch("results").to_h { [ it["file"], it["lookup"] ] }
tops = JSON.parse(fixtures.join("phase2_sitting_name_matches.json").read).fetch("matches").to_h { [ it["file"], it["final_candidates"] ] }
text = truth.keys.to_h { [ it, { "top3" => tops[it], "lookup" => lookups[it] } ] }
run = Scanner::MeasurementRun.new(manifest: CardScannerPhase3.sitting_dir.join("manifest.csv"), dir: CardScannerPhase3.corpus_dir.join("runs/spec010/sitting"))
same = Collector::ScannerFindings.rescore(truth, run.measured_captures).to_h { [ it["file"], { "top3" => it["final_candidates"], "lookup" => it["lookup"] } ] }
findings = CardScannerPhase3::ArtFindings.new(results: replay["results"], truth:, entries: data["entries"], owners:, text:, same_capture_text: same)
puts "Index: #{replay["index"].slice("count", "label", "bulk_version", "settings_commit")}", "", findings.to_markdown
if second
  other = JSON.parse(CardScannerPhase3.runs_dir.join(second, "results.json").read)["results"]
  diffs = replay["results"].flat_map { |path, files| files.filter_map { |file, r| "#{path} #{file}" if other.dig(path, file, "hashes") != r["hashes"] } }
  puts "", "Determinism (#{label} vs #{second}): #{diffs.empty? ? "identical fingerprints for every job" : diffs.join(", ")}"
end
if ENV["FIXTURES"] == "1"
  records = replay["results"].transform_values { |files| files.transform_values { it.slice("hashes", "top", "rightDistance", "crop", "found", "corners", "searchMs") } }
  fixtures.join("phase3_art_results.json").write(JSON.pretty_generate("format_version" => 1, "spec" => "010", "index" => replay["index"], "code_commit" => replay["code_commit"],
    "replay" => records, "scored" => findings.to_h))
end
