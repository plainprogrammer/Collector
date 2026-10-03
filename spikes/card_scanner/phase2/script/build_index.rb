# Fingerprints every cached artwork image and writes the index (AC-4.1, AC-4.4). Reports the build cost.
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/build_index.rb [--size small]
require "bundler/setup"
require "optparse"
require "zlib"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/settings"
require_relative "../lib/card_scanner_phase2/bulk_artworks"
require_relative "../lib/card_scanner_phase2/ppm"
require_relative "../lib/card_scanner_phase2/fingerprint"
require_relative "../lib/card_scanner_phase2/art_index"

# The maintainer declined the full fetch, so the index covers only the cached subset (AC-4.3).
SUBSET = "98 corpus artworks + 500 random sample (seed 20261003); full fetch declined by the maintainer 2026-10-03"

size = "small"
OptionParser.new { |p| p.on("--size SIZE") { size = it } }.parse!
settings = CardScannerPhase2::Settings.load.fetch("fingerprint")
data = CardScannerPhase2::BulkArtworks.load
image_dir = CardScannerPhase2::WORK_DIR.join("artwork", size)
ids, hashes, missing = [], [], []
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
data["artworks"].each_key do |id|
  path = image_dir.join("#{id}.jpg")
  next missing << id unless path.file?
  hashes << CardScannerPhase2::Fingerprint.hash(CardScannerPhase2::Ppm.decode(path), settings, settings["offsets"].first)
  ids << id
end
seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
dir = CardScannerPhase2::WORK_DIR.join("index")
CardScannerPhase2::ArtIndex.write!(dir, ids, hashes, meta: { "image_size" => size, "bulk_version" => data["bulk_version"], "settings_commit" => CardScannerPhase2::Settings.commit,
  "tool" => "ImageMagick #{`magick -version`[/\d+\.\d+\.\d+-\d+/]} (P6 decode) + pure Ruby", "fingerprint_seconds" => seconds.round(1), "missing_artworks" => missing.size,
  "subset" => SUBSET })
raw = dir.join("art_index.bin").size
corpus_ids = CardScannerPhase2::CORPORA.keys.flat_map do |corpus|
  JSON.parse(CardScannerPhase2::WORK_DIR.join("truth", corpus, "ground_truth.json").read).fetch("photos").map { data["entries"][it["external_key"]] }
end.compact.uniq
puts "#{ids.size} artworks in #{seconds.round(1)} s; #{missing.size} without a cached image; index #{raw} bytes raw, #{Zlib::Deflate.deflate(dir.join("art_index.bin").binread, Zlib::BEST_COMPRESSION).bytesize} gzip"
left_out = corpus_ids & missing
puts "corpus artworks left out (AC-4.8): #{left_out.empty? ? "none" : left_out.join(", ")}"
