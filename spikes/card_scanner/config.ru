# Phase 0 spike server (spec 005). Start with: bundle exec puma -C spikes/card_scanner/puma.rb
require_relative "lib/card_scanner_spike"
require_relative "lib/card_scanner_spike/server"

run CardScannerSpike::Server.new(
  public_dir: File.join(CardScannerSpike::ROOT, "public"),
  ocr_dir: File.join(CardScannerSpike::WORK_DIR, "ocr"),
  corpus_dir: CardScannerSpike.corpus_dir,
  log_dir: File.join(CardScannerSpike::WORK_DIR, "logs")
)
