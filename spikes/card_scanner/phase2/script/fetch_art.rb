# Fetches artwork images into tmp/card_scanner_phase2/artwork/<size>/ (AC-4.2, AC-4.7).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/fetch_art.rb --size small --mode corpus|estimate|full [--limit N] [--seed N]
#   corpus:   the artworks of the 99 corpus cards (both sizes are cheap: ~200 requests)
#   estimate: a random sample of 500 uncached artworks; writes fetch_estimate.json and stops (maintainer checkpoint)
#   full:     everything not cached, in order; resumable; --limit bounds one invocation
require "bundler/setup"
require "optparse"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/bulk_artworks"
require_relative "../lib/card_scanner_phase2/art_fetcher"

options = { size: "small", seed: 20261003, limit: nil }
OptionParser.new do |p|
  p.on("--size SIZE") { options[:size] = it }
  p.on("--mode MODE") { options[:mode] = it }
  p.on("--limit N", Integer) { options[:limit] = it }
  p.on("--seed N", Integer) { options[:seed] = it }
end.parse!
abort "--mode corpus|estimate|full is required" unless %w[corpus estimate full].include?(options[:mode])

data = CardScannerPhase2::BulkArtworks.load
fetcher = CardScannerPhase2::ArtFetcher.new(dir: CardScannerPhase2::WORK_DIR.join("artwork"), size: options[:size])
selection =
  case options[:mode]
  when "corpus"
    keys = CardScannerPhase2::CORPORA.keys.flat_map do |corpus|
      JSON.parse(CardScannerPhase2::WORK_DIR.join("truth", corpus, "ground_truth.json").read).fetch("photos").map { data["entries"][it["external_key"]] }
    end.compact.uniq
    data["artworks"].slice(*keys)
  when "estimate"
    uncached = data["artworks"].reject { |id, _| fetcher.path_for(id).file? }
    uncached.keys.sample(500, random: Random.new(options[:seed])).to_h { [ it, data["artworks"][it] ] }
  when "full" then data["artworks"]
  end
stats = fetcher.fetch(selection, limit: options[:limit]).merge("mode" => options[:mode], "selected" => selection.size, "at" => Time.now.utc.iso8601)
if options[:mode] == "estimate"
  remaining = data["artworks"].count { |id, _| !fetcher.path_for(id).file? }
  per_image = { "bytes" => stats["bytes"].to_f / stats["fetched"], "seconds" => stats["seconds"] / stats["fetched"] }
  stats["estimate"] = { "seed" => options[:seed], "sample" => stats["fetched"], "remaining_images" => remaining, "per_image" => per_image,
    "remaining_bytes" => (per_image["bytes"] * remaining).round, "remaining_hours" => (per_image["seconds"] * remaining / 3600).round(2) }
  CardScannerPhase2::WORK_DIR.join("fetch_estimate.json").write(JSON.pretty_generate(stats))
end
CardScannerPhase2::WORK_DIR.join("fetch_#{options[:size]}_#{options[:mode]}_#{Time.now.utc.strftime("%Y%m%dT%H%M%S")}.json").write(JSON.pretty_generate(stats))
puts JSON.pretty_generate(stats.except("failed")) + "\nfailed: #{stats["failed"].size}"
