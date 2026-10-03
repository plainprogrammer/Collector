# Scores a reading run: the run's records, the baseline from the committed fixtures, and for the new corpus the
# live captures on the same cards; writes score.md (tables, misses, timings) and score.json (records).
# Usage: bin/rails runner spikes/card_scanner/phase2/script/score.rb <run> [<label>]
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "card_scanner_phase2"
require "card_scanner_phase2/runs"
require "card_scanner_phase2/derived_corpus"
require "card_scanner_phase2/scoring"

run = ARGV.fetch(0) { abort "usage: score.rb <run> [<label>]" }
run_dir = CardScannerPhase2.runs_dir.join(run)
provenance = CardScannerPhase2::Runs.read(run_dir)
label = ARGV.fetch(1) { "#{run} (#{provenance["half"] == "development" ? "development, biased" : "held out"})" }

Rails.configuration.x.scanner_measurement = { manifest: run_dir.join("corpus/manifest.csv").to_s, dir: run_dir.join("measurement").to_s }
captures = Scanner::MeasurementRun.current.measured_captures
truths = CardScannerPhase2::CORPORA.keys.to_h do |corpus|
  [ corpus, JSON.parse(CardScannerPhase2::WORK_DIR.join("truth", corpus, "ground_truth.json").read).fetch("photos").to_h { [ it["file"], it ] } ]
end
records = CardScannerPhase2::Scoring.records(run_dir, truths:, measured_captures: captures)
files = records.group_by { it["corpus"] }.transform_values { |rs| rs.map { it["file"] } }
tag = ->(rs, corpus) { rs.map { it.merge("corpus" => corpus) } }
baseline = tag.(CardScannerPhase2::Scoring.fixture_records("phase1_photos_ocr_results.json", truths["phase0"], files.fetch("phase0", [])), "phase0") +
  tag.(CardScannerPhase2::Scoring.fixture_records("phase1_live_photos_ocr_results.json", truths["new"], files.fetch("new", [])), "new")
sources = { label => records, "Baseline: shipped photo path, same photos" => baseline }
if files["new"]
  sources["Live capture, same cards (spec 007)"] = tag.(CardScannerPhase2::Scoring.fixture_records("phase1_live_ocr_results.json", truths["new"], files["new"]), "new")
end

tables = CardScannerPhase2::Scoring.tables(sources)
misses = CardScannerPhase2::Scoring.misses(records)
timings = CardScannerPhase2::Scoring.timings(records)
md = [ "# #{label}", "Run: #{run} · half: #{provenance["half"]} · code: #{provenance["code_commit"]} · settings: #{provenance["settings_commit"]} · tree clean: #{provenance["tree_clean"]}",
  "Catalog: #{Catalog::RefreshRun.where(collectible_type: "mtg", status: "applied").order(:started_at).last&.source_version}",
  "## Both corpora", tables["both"], "## Phase 0", tables["phase0"], "## New corpus", tables["new"],
  "## Misses (not in the final top 3)", "| File | Expected | Class | Name read | Collector read | Top 3 |", "|---|---|---|---|---|---|",
  *misses.map { "| #{it["file"]} | #{it["name"]} | #{it["class"]} | #{it["name_text"].to_s.tr("\n|", " /")[0, 60]} | #{it["collector_text"].to_s.tr("\n|", " /")[0, 60]} | #{Array(it["final_candidates"]).join("; ")} |" },
  "## Timings (desktop)", timings.to_json ].join("\n\n")
run_dir.join("score.md").write(md)
run_dir.join("score.json").write(JSON.pretty_generate("label" => label, "provenance" => provenance, "records" => records, "timings" => timings))
puts md
