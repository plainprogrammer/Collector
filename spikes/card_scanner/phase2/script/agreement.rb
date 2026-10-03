# Fingerprints the same artwork images in Ruby (the index build) and in the browser, and reports the distances (AC-4.6).
# Usage: SE_AVOID_STATS=true bundle exec ruby spikes/card_scanner/phase2/script/agreement.rb [--size small] [--extra 100]
require "bundler/setup"
require "optparse"
require "selenium-webdriver"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/settings"
require_relative "../lib/card_scanner_phase2/bulk_artworks"
require_relative "../lib/card_scanner_phase2/ppm"
require_relative "../lib/card_scanner_phase2/fingerprint"

size, extra = "small", 100
OptionParser.new { |p| p.on("--size S") { size = it }; p.on("--extra N", Integer) { extra = it } }.parse!
settings = CardScannerPhase2::Settings.load.fetch("fingerprint")
data = CardScannerPhase2::BulkArtworks.load
corpus_ids = CardScannerPhase2::CORPORA.keys.flat_map do |corpus|
  JSON.parse(CardScannerPhase2::WORK_DIR.join("truth", corpus, "ground_truth.json").read).fetch("photos").map { data["entries"][it["external_key"]] }
end.compact.uniq
image_dir = CardScannerPhase2::WORK_DIR.join("artwork", size)
others = (data["artworks"].keys - corpus_ids).select { image_dir.join("#{it}.jpg").file? }.sample(extra, random: Random.new(20261003))
ids = (corpus_ids + others).select { image_dir.join("#{it}.jpg").file? }

# `failure`, not `error`: Selenium reads a returned object with an `error` key as a WebDriver error (see detect_run.rb).
JS = "const [p, done] = arguments; window.__phase2.fingerprintImage(p).then(done, (e) => done({ failure: `${e}\\n${e && e.stack || \"\"}` }))"
driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
driver.manage.timeouts.script_timeout = 120
results = begin
  driver.navigate.to("#{ENV.fetch("SPIKE_URL", "http://127.0.0.1:4200")}/detect.html")
  Selenium::WebDriver::Wait.new(timeout: 120).until { driver.execute_script("return Boolean(window.__phase2 && window.__phase2.ready)") }
  ids.map do |id|
    ruby = CardScannerPhase2::Fingerprint.hash(CardScannerPhase2::Ppm.decode(image_dir.join("#{id}.jpg")), settings, settings["offsets"].first)
    answer = driver.execute_async_script(JS, { "path" => "artwork/#{size}/#{id}.jpg" })
    abort "#{id}: #{answer["failure"]}" if answer["failure"]
    browser = [ answer["hash"] ].pack("H*")
    { "id" => id, "corpus_card" => corpus_ids.include?(id), "distance" => CardScannerPhase2::Fingerprint.hamming(ruby, browser) }
  end
ensure
  driver.quit
end
distances = results.map { it["distance"] }.sort
summary = { "size" => size, "n" => results.size, "corpus_cards" => results.count { it["corpus_card"] }, "median" => CardScannerPhase2.median(distances), "max" => distances.last,
  "settings_commit" => CardScannerPhase2::Settings.commit, "results" => results }
CardScannerPhase2::WORK_DIR.join("agreement_#{size}.json").write(JSON.pretty_generate(summary))
puts summary.except("results").to_json
