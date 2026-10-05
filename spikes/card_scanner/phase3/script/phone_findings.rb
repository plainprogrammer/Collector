# Summarises the phone loads and the desktop reference (spec 010 Story 2). Usage: bundle exec ruby … phone_findings.rb [FIXTURES=1]
require "bundler/setup"
require_relative "../lib/card_scanner_phase3"
require_relative "../lib/card_scanner_phase3/phone_findings"

loads = CardScannerPhase3.runs_dir.join("phone").glob("*.json").sort.map { JSON.parse(it.read) }
desktop = loads.reverse.find { it["userAgent"].include?("Firefox") } or abort "run desktop_timing.rb first"
phone = loads.reject { it["userAgent"].include?("Firefox") }
findings = CardScannerPhase3::PhoneFindings.new(results: phone, desktop:)
puts findings.to_markdown
CardScannerPhase3::FIXTURE_DIR.join("phase3_phone_timings.json").write(JSON.pretty_generate(findings.to_h)) if ENV["FIXTURES"] == "1"
