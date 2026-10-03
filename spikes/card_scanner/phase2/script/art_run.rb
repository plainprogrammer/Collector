# Art matching over a detect run: re-runs detection with the fingerprint and search enabled, as a new run
# named <run>-art, for the detect run's photos. The half comes from the detect run, so a development source
# can only make a development art run. Usage: SE_AVOID_STATS=true bundle exec ruby … art_run.rb --from dev-hand-3 --detector hand
require "bundler/setup"
require "optparse"
require "selenium-webdriver"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/runs"
require_relative "../lib/card_scanner_phase2/derived_corpus"

options = {}
OptionParser.new { |p| p.on("--from RUN") { options[:from] = it }; p.on("--detector D") { options[:detector] = it } }.parse!
%i[from detector].each { |key| abort "--#{key} is required" unless options[key] }
from = CardScannerPhase2.runs_dir.join(options.fetch(:from))
provenance = CardScannerPhase2::Runs.read(from)
run_dir = CardScannerPhase2::Runs.start!("#{options[:from]}-art", half: provenance["half"])
jobs = CardScannerPhase2::DerivedCorpus.detections(from).map do |d|
  { "path" => d["path"], "detector" => options[:detector], "scale" => nil, "run" => run_dir.basename.to_s, "stem" => File.basename(d["file"], ".*"), "art" => true, "file" => d["file"], "corpus" => d["corpus"] }
end
# `failure`, not `error`: Selenium reads a returned object with an `error` key as a WebDriver error (see detect_run.rb).
RUN_JS = <<~JS.freeze
  const [ params, done ] = arguments
  window.__phase2.run(params).then((result) => done({ result }), (error) => done({ failure: `${error}\n${error && error.stack || ""}` }))
JS
driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
driver.manage.timeouts.script_timeout = 600
begin
  driver.navigate.to("#{ENV.fetch("SPIKE_URL", "http://127.0.0.1:4200")}/detect.html")
  Selenium::WebDriver::Wait.new(timeout: 120).until { driver.execute_script("return Boolean(window.__phase2 && window.__phase2.ready)") }
  jobs.each do |job|
    answer = driver.execute_async_script(RUN_JS, job.except("file", "corpus"))
    abort "#{job["file"]}: #{answer["failure"]}" if answer["failure"]
    record = CardScannerPhase2::Runs.stamp(run_dir, answer["result"].merge("file" => job["file"], "corpus" => job["corpus"]))
    dir = run_dir.join(job["stem"])
    dir.mkpath
    dir.join("art.json").write(JSON.pretty_generate(record))
    puts format("%-14s %-5s %s", job["file"], record["found"] ? "found" : "none", record["art"] ? "#{record["art"].first["id"][0, 8]} d=#{record["art"].first["distance"]}" : "-")
  end
ensure
  driver.quit
end
puts "#{jobs.size} photos -> #{run_dir}"
