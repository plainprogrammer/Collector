# Summarises one device's page loads, posted timings and CSP reports (AC-1.6, NFR Security).
# Usage: bundle exec ruby spikes/card_scanner/script/timing_summary.rb <device ip>
require "bundler/setup"
require "json"
require_relative "../lib/card_scanner_spike"

ip = ARGV.fetch(0) { abort "usage: timing_summary.rb <device ip>" }
logs = File.join(CardScannerSpike::WORK_DIR, "logs")
CardScannerSpike::Timings.sessions(File.readlines(File.join(logs, "requests.jsonl")), ip:).each_with_index do |session, index|
  puts "Page load #{index + 1} at #{session.started_at}: #{session.requests} requests, #{session.bytes} bytes"
end
Dir[File.join(logs, "timings-*.json")].sort.each do |path|
  timings = JSON.parse(File.read(path))
  next unless timings["user_agent"].to_s.include?("iPhone")

  times = timings.fetch("results").map { it["ms"] }
  puts "#{File.basename(path)}: ready #{timings["ready_ms"]} ms, #{times.size} photos, " \
    "median #{CardScannerSpike::Scoring.percentile(times, 50)} ms, slowest #{times.max} ms"
end
reports = File.join(logs, "csp-reports.jsonl")
puts "CSP violation reports: #{File.exist?(reports) ? File.readlines(reports).size : 0}"
