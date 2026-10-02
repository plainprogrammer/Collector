require "json"
require "pathname"

# The Phase 2 spike (spec 008): card detection and art matching on the stored photos.
module CardScannerPhase2
  ROOT = Pathname(File.expand_path("..", __dir__))
  REPO = ROOT.join("../../..").expand_path
  WORK_DIR = REPO.join("tmp/card_scanner_phase2")
  FIXTURE_DIR = REPO.join("spec/fixtures/card_scanner")
  SETTINGS_PATH = ROOT.join("settings.json")

  def self.corpus_dir = Pathname(File.expand_path(ENV.fetch("CARD_SCANNER_CORPUS", "~/card-scanner-corpus")))
  def self.runs_dir = corpus_dir.join("runs/phase2")

  CORPORA = {
    "phase0" => { manifest: "manifest.csv", label: "Phase 0" },
    "new" => { manifest: "phase1-live/manifest.csv", label: "New corpus" }
  }.freeze
end
