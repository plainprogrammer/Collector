$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "card_scanner_phase3"
require "card_scanner_phase3/server"

run CardScannerPhase3::Server.new(
  phase2_public: CardScannerPhase2::ROOT.join("public"),
  phase3_public: CardScannerPhase3::ROOT.join("public"),
  app_scanner: CardScannerPhase3::REPO.join("app/javascript/scanner"),
  work_dir: CardScannerPhase2::WORK_DIR,
  corpus_dir: CardScannerPhase3.corpus_dir,
  runs_dir: CardScannerPhase3.runs_dir,
  settings_path: CardScannerPhase2::SETTINGS_PATH,
  queries_path: CardScannerPhase2::WORK_DIR.join("phone_queries.json"),
  cards_dir: CardScannerPhase3.corpus_dir.join("runs/phase2/held-hand"))
