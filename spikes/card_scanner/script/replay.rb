# Replays the photo corpus through the OCR page in headless Firefox (AC-1.2, AC-1.5).
# Usage (spike server running): bundle exec ruby spikes/card_scanner/script/replay.rb <label>
require "bundler/setup"
require "base64"
require "fileutils"
require "json"
require "selenium-webdriver"
require_relative "../lib/card_scanner_spike"

label = ARGV.fetch(0) { abort "usage: replay.rb <label>" }
url = ENV.fetch("SPIKE_URL", "http://127.0.0.1:4100")
out_dir = File.join(CardScannerSpike::WORK_DIR, "replays", label)
FileUtils.mkdir_p(File.join(out_dir, "crops"))

driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
begin
  driver.navigate.to("#{url}/ocr.html?mode=replay")
  Selenium::WebDriver::Wait.new(timeout: 3600, interval: 5).until { driver.execute_script("return Boolean(window.__spike && window.__spike.done)") }
  spike = driver.execute_script("return window.__spike")
  abort "OCR page error: #{spike["error"]}" if spike["error"]
  results = spike.fetch("results").map do |result|
    result.delete("crops").each do |strip, data_url|
      path = File.join(out_dir, "crops", "#{File.basename(result["file"], ".*")}-#{strip}.png")
      File.binwrite(path, Base64.decode64(data_url.split(",", 2).last))
    end
    result
  end
  File.write(File.join(out_dir, "ocr.json"), JSON.pretty_generate({ "run" => label, "ready_ms" => spike["ready"].round, "results" => results }))
  puts "#{results.size} photos -> #{out_dir}/ocr.json"
ensure
  driver.quit
end
