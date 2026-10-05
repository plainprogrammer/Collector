# Replays the 35 cards through the three paths (spec 010 Story 4) in headless Firefox against the phase 3 server's replay page,
# writing runs/phase3/<label>/results.json. Usage: (server running) bundle exec ruby … replay.rb <label>
require "bundler/setup"
require "selenium-webdriver"
require "time"
require_relative "../lib/card_scanner_phase3"
require_relative "../../phase2/lib/card_scanner_phase2/bulk_artworks"

label = ARGV.fetch(0) { abort "usage: replay.rb <label>" }
out = CardScannerPhase3.runs_dir.join(label)
abort "#{out} exists; pick a new label" if out.exist?
data = CardScannerPhase2::BulkArtworks.load
truth = JSON.parse(CardScannerPhase3.sitting_dir.join("ground_truth.json").read).fetch("photos")
live = CardScannerPhase3.corpus_dir.join("runs/spec010/sitting")
jobs = truth.flat_map do |t|
  right = data["entries"][t["external_key"]]
  capture = JSON.parse(live.join(t["file"], "capture-001.json").read) if live.join(t["file"], "capture-001.json").file?
  frame = "runs/spec010/sitting/#{t["file"]}/capture-001-frame.png"
  [ (capture && { "file" => t["file"], "path" => frame, "kind" => "guide", "guide" => capture["guide"], "right" => right }),
    (capture && { "file" => t["file"], "path" => frame, "kind" => "detected", "right" => right }),
    { "file" => t["file"], "path" => "phase2-sitting/#{t["file"]}", "kind" => "photo", "right" => right } ].compact
end
RUN_JS = "const [ job, done ] = arguments; window.__phase3.run(job).then((r) => done({ r }), (e) => done({ failure: `${e}` }))"
driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
driver.manage.timeouts.script_timeout = 300
results = Hash.new { |h, k| h[k] = {} }
begin
  driver.navigate.to("http://127.0.0.1:#{ENV.fetch("SPIKE_LOCAL_PORT", 4301)}/replay.html")
  Selenium::WebDriver::Wait.new(timeout: 300).until { driver.execute_script("return Boolean(window.__phase3 && window.__phase3.ready)") }
  jobs.each do |job|
    answer = driver.execute_async_script(RUN_JS, job.except("file"))
    abort "#{job["file"]} #{job["kind"]}: #{answer["failure"]}" if answer["failure"]
    results[job["kind"]][job["file"]] = answer["r"]
    puts format("%-14s %-8s %s", job["file"], job["kind"], answer.dig("r", "top", 0, "id").to_s[0, 8])
  end
ensure
  driver.quit
end
out.mkpath
meta = JSON.parse(CardScannerPhase2::WORK_DIR.join("index/art_index_meta.json").read)
head = IO.popen([ "git", "-C", CardScannerPhase3::REPO.to_s, "rev-parse", "HEAD" ], &:read).strip
out.join("results.json").write(JSON.pretty_generate("label" => label, "at" => Time.now.utc.iso8601, "code_commit" => head, "index" => meta, "results" => results))
puts "#{jobs.size} jobs -> #{out.join("results.json")}"
