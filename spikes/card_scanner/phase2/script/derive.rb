# Builds a detect run's derived corpus and its ground truth, and prints the environment for the reading run.
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/derive.rb <run>
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/derived_corpus"

run = ARGV.fetch(0) { abort "usage: derive.rb <run>" }
run_dir = CardScannerPhase2.runs_dir.join(run)
abort "#{run_dir} has no run.json" unless run_dir.join("run.json").exist?
corpus = CardScannerPhase2::DerivedCorpus.write!(run_dir)
system("bin/rails", "scanner:ground_truth[#{corpus.join("manifest.csv")}]", chdir: CardScannerPhase2::REPO.to_s, exception: true)
found = corpus.glob("*.png").size
puts "#{found} pictures, #{CardScannerPhase2::DerivedCorpus.not_found(run_dir).size} not found -> #{corpus}"
require_relative "#{CardScannerPhase2::REPO}/lib/collector/dev_port"
port = Collector::DevPort.resolve(root: CardScannerPhase2::REPO.to_s) # the port photo_run.rb defaults to (3204 in this worktree)
puts "Reading run:"
puts "  COLLECTOR_SCANNER_MANIFEST=#{corpus.join("manifest.csv")} COLLECTOR_SCANNER_RUN_DIR=#{run_dir.join("measurement")} bin/rails server -b 127.0.0.1 -p #{port}"
puts "  SE_AVOID_STATS=true SCANNER_EMAIL=phase2@localhost SCANNER_PASSWORD=… bundle exec ruby script/scanner/photo_run.rb"
