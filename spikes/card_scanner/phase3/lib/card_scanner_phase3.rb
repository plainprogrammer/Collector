require "json"
require "pathname"
require_relative "../../phase2/lib/card_scanner_phase2"

# The art spike (spec 010): the art index on a phone, and art on live captures. It reuses spec 008's art tools
# (CardScannerPhase2), run with CARD_SCANNER_WORK_DIR=~/card-scanner-corpus/art-cache and CARD_SCANNER_TRUTH_CORPORA=sitting.
module CardScannerPhase3
  ROOT = Pathname(File.expand_path("..", __dir__))
  REPO = CardScannerPhase2::REPO
  FIXTURE_DIR = CardScannerPhase2::FIXTURE_DIR
  # Spec 008's measured full fetch (research.md §7), the basis of the estimate (spec 010 AC-1.2).
  SPEC008_FETCH = { "images" => 50_923, "bytes" => 707_955_694, "seconds" => 9_448.8 }.freeze
  # Spec 009's misses and corrections, reported card by card (AC-4.6).
  NAMED = %w[IMG_6808.jpeg IMG_6829.jpeg IMG_6821.jpeg IMG_6814.jpeg IMG_6823.jpeg].freeze

  def self.corpus_dir = CardScannerPhase2.corpus_dir
  def self.sitting_dir = corpus_dir.join("phase2-sitting")
  def self.runs_dir = corpus_dir.join("runs/phase3")
end
