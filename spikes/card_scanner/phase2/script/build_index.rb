# Fingerprints every cached artwork image and writes the index (AC-4.1, AC-4.4, AC-4.10). Reports the build cost.
# The metadata names the index: "full" when every artwork with an image URL is cached (the artworks without one are
# counted in missing_artworks), else a subset described by --label, which art_score.rb puts in every heading.
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/build_index.rb [--size small] [--label TEXT]
require "bundler/setup"
require "optparse"
require "zlib"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/settings"
require_relative "../lib/card_scanner_phase2/bulk_artworks"
require_relative "../lib/card_scanner_phase2/ppm"
require_relative "../lib/card_scanner_phase2/fingerprint"
require_relative "../lib/card_scanner_phase2/art_index"

size, label = "small", nil
OptionParser.new { |p| p.on("--size SIZE") { size = it }; p.on("--label TEXT") { label = it } }.parse!
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
# Artworks without an image URL can never be fetched (AC-4.8), so they don't make an index partial.
without_image = missing.reject { data["artworks"][it][size] }
full = missing.size == without_image.size
meta = { "image_size" => size, "bulk_version" => data["bulk_version"], "settings_commit" => CardScannerPhase2::Settings.commit,
  "tool" => "ImageMagick #{`magick -version`[/\d+\.\d+\.\d+-\d+/]} (P6 decode) + pure Ruby", "fingerprint_seconds" => seconds.round(1), "missing_artworks" => missing.size,
  "missing_without_image" => without_image.size, "label" => full ? "full" : (label || "subset") }
meta["subset"] = label || "cached artworks only" unless full # a partial index names itself; the full index carries no subset field
CardScannerPhase2::ArtIndex.write!(dir, ids, hashes, meta:)
raw = dir.join("art_index.bin").size
corpus_ids = CardScannerPhase2.truth_corpora.flat_map do |corpus|
  JSON.parse(CardScannerPhase2::WORK_DIR.join("truth", corpus, "ground_truth.json").read).fetch("photos").map { data["entries"][it["external_key"]] }
end.compact.uniq
puts "#{meta["label"]} index: #{ids.size} artworks in #{seconds.round(1)} s; #{missing.size} without a cached image (#{without_image.size} of them without an image URL); index #{raw} bytes raw, #{Zlib::Deflate.deflate(dir.join("art_index.bin").binread, Zlib::BEST_COMPRESSION).bytesize} gzip"
left_out = corpus_ids & missing
puts "corpus artworks left out (AC-4.8): #{left_out.empty? ? "none" : left_out.join(", ")}"
