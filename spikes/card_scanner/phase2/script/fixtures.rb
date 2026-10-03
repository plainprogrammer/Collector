# Assembles the committed fixtures from the held-out, development, scaled, replay and art runs (AC-5.5: one record per
# photo keyed by the original manifest file name; text and numbers only).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/fixtures.rb --held hand=held-hand,opencv=held-opencv \
#          --scaled hand=held-hand-scaled,opencv=held-opencv-scaled --dev hand=dev-hand-3,opencv=dev-opencv-5 \
#          --dev-scaled hand=dev-hand-scaled,opencv=dev-opencv-scaled \
#          --replays hand=dev-hand-r1+dev-hand-r2,opencv=dev-opencv-r1+dev-opencv-r2 --art held-hand-art --dev-art dev-hand-3-art \
#          --agreement small
require "bundler/setup"
require "optparse"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/settings"

options = {}
OptionParser.new { |p| %w[held scaled dev dev-scaled replays art dev-art agreement].each { |k| p.on("--#{k} V") { options[k] = it } } }.parse!
pairs = ->(v) { v.to_s.split(",").map { it.split("=") }.to_h }
records = ->(run) { JSON.parse(CardScannerPhase2.runs_dir.join(run, "score.json").read).fetch("records") }
READING = %w[run half class found name_text collector_text parsed lookup lookup_ms name_candidates final_candidates ms msDetect msWarp recorded_at
  code_commit settings_commit tree_clean].freeze
ART = %w[hashes art right_artwork art_rank right_distance nearest_wrong_distance share_name share_artwork msFingerprint msSearch].freeze

out = {}
add = ->(run, detector, slot) do
  records.(run).each do |r|
    rec = out[r["file"]] ||= { "file" => r["file"], "corpus" => r["corpus"], "half" => r["half"], "name" => r["name"], "external_key" => r["external_key"],
                               "era" => r["era"], "foil" => r["foil"], "borderless_or_showcase" => r["borderless_or_showcase"], "detectors" => {} }
    (rec["detectors"][detector] ||= {})[slot] = r.slice(*READING)
  end
end
pairs.(options["held"]).each { |d, run| add.(run, d, "full") }
pairs.(options["dev"]).each { |d, run| add.(run, d, "full") }
pairs.(options["scaled"]).each { |d, run| add.(run, d, "scaled") }
pairs.(options["dev-scaled"]).each { |d, run| add.(run, d, "scaled") }
pairs.(options["replays"]).each do |d, runs|
  runs.split("+").each do |run|
    records.(run).each do |r|
      ((out.fetch(r["file"])["detectors"][d] ||= {})["replays"] ||= []) <<
        { "run" => run, "class" => r["class"], "top3" => Array(r["final_candidates"]).first(3).include?(r["name"]) }
    end
  end
end
# Each art record carries its own half in its provenance, so the held-out and development art runs merge the same way.
options.values_at("art", "dev-art").compact.each do |run|
  art = JSON.parse(CardScannerPhase2.runs_dir.join(run, "art_score.json").read)
  art["records"].each do |r|
    out.fetch(r["file"])["art"] = r.slice(*ART).merge(r.fetch("art_provenance", {})).merge("detector" => art.dig("provenance", "run").sub(/-art\z/, ""))
  end
end
CardScannerPhase2::FIXTURE_DIR.join("phase2_results.json").write(JSON.pretty_generate("format_version" => 1, "spec" => "008",
  "settings_commit" => CardScannerPhase2::Settings.commit, "records" => out.values.sort_by { it["file"] }))
if options["agreement"]
  agreement = JSON.parse(CardScannerPhase2::WORK_DIR.join("agreement_#{options["agreement"]}.json").read)
  CardScannerPhase2::FIXTURE_DIR.join("phase2_agreement.json").write(JSON.pretty_generate(agreement.merge("format_version" => 1)))
end
puts "#{out.size} records -> #{CardScannerPhase2::FIXTURE_DIR.join("phase2_results.json")}"
