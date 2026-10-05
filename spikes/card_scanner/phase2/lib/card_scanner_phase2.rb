require "json"
require "pathname"

# The Phase 2 spike (spec 008): card detection and art matching on the stored photos.
module CardScannerPhase2
  ROOT = Pathname(File.expand_path("..", __dir__))
  REPO = ROOT.join("../../..").expand_path
  # Spec 010 points this at ~/card-scanner-corpus/art-cache, outside the repository, so the cache and index survive a worktree.
  WORK_DIR = Pathname(File.expand_path(ENV.fetch("CARD_SCANNER_WORK_DIR", REPO.join("tmp/card_scanner_phase2").to_s)))
  FIXTURE_DIR = REPO.join("spec/fixtures/card_scanner")
  SETTINGS_PATH = ROOT.join("settings.json")

  def self.corpus_dir = Pathname(File.expand_path(ENV.fetch("CARD_SCANNER_CORPUS", "~/card-scanner-corpus")))
  def self.runs_dir = corpus_dir.join("runs/phase2")
  # The corpora whose ground truth the art scripts read from WORK_DIR/truth/<corpus>/ (spec 010 uses "sitting").
  def self.truth_corpora = ENV.fetch("CARD_SCANNER_TRUTH_CORPORA", "").split(",").map(&:strip).reject(&:empty?).then { it.empty? ? CORPORA.keys : it }

  # The conventional median: the middle value, or the mean of the two middle values for an even count
  # (an Integer when two Integers average to a whole number); nil for an empty sample.
  def self.median(values)
    return if values.empty?

    sorted = values.sort
    middle = sorted.size / 2
    return sorted[middle] if sorted.size.odd?

    sum = sorted[middle - 1] + sorted[middle]
    sum.is_a?(Integer) && sum.even? ? sum / 2 : sum / 2.0
  end

  CORPORA = {
    "phase0" => { manifest: "manifest.csv", label: "Phase 0" },
    "new" => { manifest: "phase1-live/manifest.csv", label: "New corpus" }
  }.freeze
end
