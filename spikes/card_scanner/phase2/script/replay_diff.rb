# Counts the photos whose outcome (detection class, right card in the final top 3) differs between two runs (AC-2.10).
# Usage: bundle exec ruby spikes/card_scanner/phase2/script/replay_diff.rb <run a> <run b>
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"

abort "usage: replay_diff.rb <run a> <run b>" unless ARGV.size == 2
a, b = ARGV.first(2).map { JSON.parse(CardScannerPhase2.runs_dir.join(it, "score.json").read).fetch("records").to_h { [ it["file"], it ] } }
outcome = ->(r) { [ r["class"], Array(r["final_candidates"]).first(3).include?(r["name"]) ] }
differing = a.keys.select { outcome.(a[it]) != outcome.(b.fetch(it)) }
puts "#{differing.size} of #{a.size} differ: #{differing.join(", ")}"
