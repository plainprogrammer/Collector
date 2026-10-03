$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "card_scanner_phase2"
require "card_scanner_phase2/server"

run CardScannerPhase2::Server.new(
  public_dir: CardScannerPhase2::ROOT.join("public"),
  opencv_dir: CardScannerPhase2::WORK_DIR.join("opencv"),
  corpus_dir: CardScannerPhase2.corpus_dir,
  work_dir: CardScannerPhase2::WORK_DIR,
  runs_dir: CardScannerPhase2.runs_dir,
  log_dir: CardScannerPhase2::WORK_DIR.join("logs"),
  settings_path: CardScannerPhase2::SETTINGS_PATH,
  unsafe_eval: ENV["SPIKE_UNSAFE_EVAL"] == "1")
