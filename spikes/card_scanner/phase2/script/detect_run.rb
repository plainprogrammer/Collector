# Drives the detect page over one half of the split, one photo at a time, and records each result with the
# run's provenance. The page stores card.png and picture.png through the spike server.
# Usage: SE_AVOID_STATS=true bundle exec ruby spikes/card_scanner/phase2/script/detect_run.rb \
#          --run dev-hand --half development --detector hand [--scale 1440] [--corpus phase0,new] [--files IMG_6688.jpeg,...]
#        SETTINGS_COMMIT=<sha> is required for --half held_out (AC-1.2). SPIKE_URL overrides http://127.0.0.1:4200.
require "bundler/setup"
require "optparse"
require "selenium-webdriver"
require_relative "../lib/card_scanner_phase2"
require_relative "../lib/card_scanner_phase2/split"
require_relative "../lib/card_scanner_phase2/runs"

options = { corpus: CardScannerPhase2::CORPORA.keys, scale: nil, files: nil }
OptionParser.new do |parser|
  parser.on("--run NAME") { options[:run] = it }
  parser.on("--half HALF") { options[:half] = it }
  parser.on("--detector NAME") { options[:detector] = it }
  parser.on("--scale HEIGHT", Integer) { options[:scale] = it }
  parser.on("--corpus LIST") { options[:corpus] = it.split(",") }
  parser.on("--files LIST") { options[:files] = it.split(",") }
end.parse!
%i[run half detector].each { |key| abort "--#{key} is required" unless options[key] }

url = ENV.fetch("SPIKE_URL", "http://127.0.0.1:4200")
run_dir = CardScannerPhase2::Runs.start!(options[:run], half: options[:half])
split = CardScannerPhase2::Split.read
jobs = options[:corpus].flat_map do |corpus|
  files = split.fetch(corpus).fetch(options[:half])
  files = files & options[:files] if options[:files]
  files.map { |file| { corpus:, file:, path: File.join(File.dirname(CardScannerPhase2::CORPORA.fetch(corpus)[:manifest]), file).delete_prefix("./") } }
end
if options[:files] && (outside = options[:files] - jobs.map { it[:file] }).any?
  abort "Not in the #{options[:half]} half of the selected corpora: #{outside.join(", ")}" # AC-1.2: never run the other half by accident
end
abort "No photos selected" if jobs.empty?

RUN_JS = <<~JS.freeze
  const [ params, done ] = arguments
  window.__phase2.run(params).then((result) => done({ result }), (error) => done({ error: String(error && error.stack || error) }))
JS

driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
driver.manage.timeouts.script_timeout = 600
begin
  driver.navigate.to("#{url}/detect.html")
  Selenium::WebDriver::Wait.new(timeout: 120, interval: 0.5).until { driver.execute_script("return Boolean(window.__phase2 && window.__phase2.ready)") }
  jobs.each do |job|
    stem = File.basename(job[:file], ".*")
    answer = driver.execute_async_script(RUN_JS, { "path" => job[:path], "detector" => options[:detector], "scale" => options[:scale],
      "run" => options[:run], "stem" => stem })
    abort "#{job[:file]}: #{answer["error"]}" if answer["error"]
    result = answer["result"]
    abort "#{job[:file]}: the source is landscape (#{result["sourceWidth"]}x#{result["sourceHeight"]}); EXIF orientation wasn't applied" if result["sourceWidth"] > result["sourceHeight"]
    record = CardScannerPhase2::Runs.stamp(run_dir, result.merge("file" => job[:file], "corpus" => job[:corpus]))
    dir = run_dir.join(stem)
    dir.mkpath
    dir.join("detect.json").write(JSON.pretty_generate(record))
    puts format("%-14s %-7s %s %6.0f ms", job[:file], record["found"] ? "found" : "none", job[:corpus], record["msDetect"])
  end
ensure
  driver.quit
end
puts "#{jobs.size} photos -> #{run_dir}"
