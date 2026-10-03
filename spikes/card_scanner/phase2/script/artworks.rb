# Lists the artworks of the entries the catalog imports from the bulk file the app downloaded (AC-4.1).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/artworks.rb
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/bulk_artworks"

path = CardScannerPhase2::BulkArtworks.latest_bulk_file
result = CardScannerPhase2::BulkArtworks.read(path)
CardScannerPhase2::BulkArtworks.write!(result)
puts "#{result["bulk_version"]}: #{result["counts"]}"
