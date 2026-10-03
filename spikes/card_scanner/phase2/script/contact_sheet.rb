# Builds contact sheets of a run's straightened cards for the by-eye classes (AC-2.4).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/contact_sheet.rb <run>
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"

run = ARGV.fetch(0) { abort "usage: contact_sheet.rb <run>" }
run_dir = CardScannerPhase2.runs_dir.join(run)
records = run_dir.glob("*/detect.json").map { JSON.parse(it.read) }.sort_by { it["file"] }
abort "No detect.json under #{run_dir}" if records.empty?
blank = run_dir.join("blank.png")
system("magick", "-size", "252x352", "xc:#dddddd", blank.to_s, exception: true)
records.each_slice(20).with_index(1) do |slice, page|
  args = slice.flat_map do |record|
    card = run_dir.join(File.basename(record["file"], ".*"), "card.png")
    [ "-label", "#{record["file"]}\n#{record["found"] ? "found" : "not found"}", (card.exist? ? card : blank).to_s ]
  end
  out = run_dir.join("contact-#{page}.png")
  system("magick", "montage", *args, "-tile", "5x4", "-geometry", "252x352+6+18", "-pointsize", "14", out.to_s, exception: true)
  puts out
end
