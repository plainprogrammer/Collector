# Throwaway Phase 0 spike code (spec 005). Not autoloaded, not served by the app.
module CardScannerSpike
  ROOT = File.expand_path("..", __dir__)
  WORK_DIR = File.expand_path("../../../tmp/card_scanner_spike", __dir__)
  FIXTURE_DIR = File.expand_path("../../../spec/fixtures/card_scanner", __dir__)

  def self.corpus_dir = File.expand_path(ENV.fetch("CARD_SCANNER_CORPUS", "~/card-scanner-corpus"))
end
require_relative "card_scanner_spike/normaliser"
require_relative "card_scanner_spike/collector_line"
