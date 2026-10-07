# Copies spec 009's 35-card ground truth into the art spike's working folder as the "sitting" corpus (spec 010).
# Usage: CARD_SCANNER_WORK_DIR=… bundle exec ruby spikes/card_scanner/phase3/script/truth.rb
require "bundler/setup"
require "fileutils"
require_relative "../lib/card_scanner_phase3"

dir = CardScannerPhase2::WORK_DIR.join("truth", "sitting")
dir.mkpath
FileUtils.cp(CardScannerPhase3.sitting_dir.join("ground_truth.json"), dir.join("ground_truth.json"))
puts "#{JSON.parse(dir.join("ground_truth.json").read).fetch("photos").size} truth records -> #{dir}"
