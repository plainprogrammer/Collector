# Writes the spike's ground-truth copies under tmp/card_scanner_phase2/truth/<corpus>/ via the shipped task.
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/truth_copies.rb
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/derived_corpus"

CardScannerPhase2::CORPORA.each_key do |corpus|
  dir = CardScannerPhase2::WORK_DIR.join("truth", corpus)
  dir.mkpath
  manifest = dir.join("manifest.csv")
  manifest.write(CardScannerPhase2::DerivedCorpus.manifest_with_era(corpus))
  system("bin/rails", "scanner:ground_truth[#{manifest}]", chdir: CardScannerPhase2::REPO.to_s, exception: true)
  puts "#{corpus}: #{dir.join("ground_truth.json")}"
end
