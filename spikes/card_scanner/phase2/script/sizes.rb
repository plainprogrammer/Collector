# Reports each detector's files and their stored and gzip-compressed sizes (AC-2.7).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/sizes.rb
require "bundler/setup"
require "zlib"
require_relative "../lib/card_scanner_phase2"

shared = %w[canvas.js warp.js output.js detect.js].map { CardScannerPhase2::ROOT.join("public", it) }
detectors = {
  "hand" => shared + [ CardScannerPhase2::ROOT.join("public/hand_detector.js") ],
  "opencv" => shared + [ CardScannerPhase2::ROOT.join("public/hand_detector.js"), CardScannerPhase2::ROOT.join("public/opencv_detector.js"),
                         CardScannerPhase2::WORK_DIR.join("opencv/4.13.0/opencv.js") ]
}
report = detectors.to_h do |name, files|
  entries = files.map { |path| raw = path.binread; { "file" => path.basename.to_s, "raw" => raw.bytesize, "gzip" => Zlib::Deflate.deflate(raw, Zlib::BEST_COMPRESSION).bytesize } }
  [ name, { "files" => entries, "raw" => entries.sum { it["raw"] }, "gzip" => entries.sum { it["gzip"] } } ]
end
CardScannerPhase2::WORK_DIR.join("sizes.json").write(JSON.pretty_generate(report))
report.each { |name, r| puts format("%-7s %2d files  raw %10d  gzip %9d", name, r["files"].size, r["raw"], r["gzip"]) }
