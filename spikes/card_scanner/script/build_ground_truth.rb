# Writes spec/fixtures/card_scanner/ground_truth.json from the corpus manifest (AC-1.1, AC-4.4).
# Usage: bin/rails runner spikes/card_scanner/script/build_ground_truth.rb
require_relative "../lib/card_scanner_spike"
require_relative "../lib/card_scanner_spike/printing_lookup"
require_relative "../lib/card_scanner_spike/ground_truth"

corpus = CardScannerSpike.corpus_dir
manifest = File.read(File.join(corpus, "manifest.csv"))
truth = CardScannerSpike::GroundTruth.new.build(manifest, corpus_files: Dir.children(corpus))
FileUtils.mkdir_p(CardScannerSpike::FIXTURE_DIR)
File.write(File.join(CardScannerSpike::FIXTURE_DIR, "ground_truth.json"), JSON.pretty_generate({ "format_version" => 1, **truth }))
puts JSON.pretty_generate(truth.slice("counts", "errors"))
