# Writes what the timing page serves (spec 010 Story 2): the index gzipped (as the app would serve a static file) and spec
# 008's 43 held-out query fingerprints. Usage: CARD_SCANNER_WORK_DIR=… bundle exec ruby spikes/card_scanner/phase3/script/gzip_index.rb
require "bundler/setup"
require "zlib"
require_relative "../lib/card_scanner_phase3"

index = CardScannerPhase2::WORK_DIR.join("index/art_index.bin")
Zlib::GzipWriter.open(index.sub_ext(".bin.gz").to_s, Zlib::BEST_COMPRESSION) { it.write(index.binread) }
records = JSON.parse(CardScannerPhase3::FIXTURE_DIR.join("phase2_results.json").read).fetch("records")
queries = records.select { it["half"] == "held_out" && it.dig("art_full", "hashes") }.map { { "file" => it["file"], "hashes" => it.dig("art_full", "hashes") } }
CardScannerPhase2::WORK_DIR.join("phone_queries.json").write(JSON.generate(queries))
puts "index #{index.size} bytes, gzip #{index.sub_ext(".bin.gz").size} bytes; #{queries.size} queries"
