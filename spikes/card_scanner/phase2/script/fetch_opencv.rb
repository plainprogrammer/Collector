# Fetches the pinned OpenCV.js build into the ignored work directory and prints its size.
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/fetch_opencv.rb
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/opencv_asset"
require "zlib"

written = CardScannerPhase2::OpencvAsset.install!
path = CardScannerPhase2::OpencvAsset::ROOT.join(CardScannerPhase2::OpencvAsset::PIN.served)
puts "#{written ? "fetched" : "already intact"}: #{path}"
raw = path.binread
puts "raw #{raw.bytesize} bytes, gzip #{Zlib::Deflate.deflate(raw, Zlib::BEST_COMPRESSION).bytesize} bytes"
