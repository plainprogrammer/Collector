# Scores an art run against the text results of its detect run. Usage: bundle exec ruby … art_score.rb <art run> <detect run>
require "bundler/setup"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/runs"
require_relative "../lib/card_scanner_phase2/bulk_artworks"
require_relative "../lib/card_scanner_phase2/art_scoring"

art_run, detect_run = ARGV.fetch(0) { abort "usage: art_score.rb <art run> <detect run>" }, ARGV.fetch(1) { abort "usage: art_score.rb <art run> <detect run>" }
art_dir, detect_dir = CardScannerPhase2.runs_dir.join(art_run), CardScannerPhase2.runs_dir.join(detect_run)
data = CardScannerPhase2::BulkArtworks.load
index_meta = JSON.parse(CardScannerPhase2::WORK_DIR.join("index/art_index_meta.json").read)
# Every heading names the index: a subset index (its metadata carries `subset`) or the full index (AC-4.10).
against = index_meta["subset"] ? "against a #{index_meta["count"]}-artwork subset" : "against #{index_meta["count"]} artworks"
text = JSON.parse(detect_dir.join("score.json").read).fetch("records").to_h { [ it["file"], it ] }
art = art_dir.glob("*/art.json").map { JSON.parse(it.read) }.to_h { [ it["file"], it ] }
records = text.map do |file, record|
  a = art[file] || {}
  record.merge("art" => a["art"], "hashes" => a["hashes"], "msFingerprint" => a["msFingerprint"], "msSearch" => a["msSearch"],
    "art_provenance" => a.slice("run", "half", "recorded_at", "code_commit", "settings_commit", "tree_clean"),
    "text_top3" => Array(record["final_candidates"]).first(3).include?(record["name"]),
    "printing_identified" => record.dig("lookup", "status") == "one" && record.dig("lookup", "external_keys") == [ record["external_key"] ])
end
scored = CardScannerPhase2::ArtScoring.score(records, data)
provenance = CardScannerPhase2::Runs.read(art_dir)
by_corpus = scored.group_by { it["corpus"] }
timing = ->(values) { values.compact.then { { "n" => it.size, "median" => it.sort[it.size / 2], "max" => it.max } } }
md = [ "# Art matching: #{art_run} (#{provenance["half"]}#{provenance["half"] == "development" ? ", biased" : ""}), #{against}",
  "Index: #{index_meta.slice("count", "label", "image_size", "bulk_version", "settings_commit", "subset")}",
  "## Both corpora (#{against})", CardScannerPhase2::ArtScoring.markdown(scored),
  *by_corpus.flat_map { |corpus, rs| [ "## #{corpus} (#{against})", CardScannerPhase2::ArtScoring.markdown(rs) ] },
  "## Misses (right artwork not first, #{against})",
  [ "| File | Expected | First | Right distance | Nearest wrong | Class |", "|---|---|---|---|---|---|", # one table: rows joined by single newlines
    *CardScannerPhase2::ArtScoring.misses(scored).map { "| #{it["file"]} | #{it["name"]} | #{it.dig("art", 0, "id")} | #{it["right_distance"]} | #{it["nearest_wrong_distance"]} | #{it["class"]} |" } ].join("\n"),
  "## Timings (desktop, ms)", { "fingerprint" => timing.call(scored.map { it["msFingerprint"] }), "search_browser" => timing.call(scored.map { it["msSearch"] }) }.to_json ].join("\n\n")
art_dir.join("art_score.md").write(md)
art_dir.join("art_score.json").write(JSON.pretty_generate("provenance" => provenance, "against" => against,
  "index" => index_meta.slice("count", "label", "image_size", "bulk_version", "settings_commit", "built_at", "subset"), "records" => scored))
puts md
