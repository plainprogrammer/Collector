# Spec 009 AC-7.3: the shipped detector against the Phase 2 spike's at its frozen settings, on the spike's 99 photos. The
# spike's runs at those settings (dev-hand-3 for the development half; held-hand, at 39cdc6e, for the held-out half; the
# detector code and settings are identical between them) recorded each photo's outcome and corners, so they are the
# reference and the spike isn't run again. Runs the page's own detector, with outline completion off, in headless
# Firefox against this checkout's dev server.
# Usage: SCANNER_EMAIL=findings@localhost SCANNER_PASSWORD=... bundle exec ruby script/scanner/detector_parity.rb
require "bundler/setup"
require "base64"
require "json"
require "pathname"
require "selenium-webdriver"
require_relative "../../lib/collector/dev_port"

CORPUS = Pathname(File.expand_path(ENV.fetch("CARD_SCANNER_CORPUS", "~/card-scanner-corpus")))
RUNS = %w[dev-hand-3 held-hand].freeze
WORK_WIDTH = 480

DETECT_JS = <<~JS.freeze
  const [ data, done ] = arguments
  window.__detector ||= new Promise((resolve) => {
    addEventListener("detector-ready", () => resolve(window.__scannerDetector), { once: true })
    const script = Object.assign(document.createElement("script"), { type: "module", nonce: document.querySelector("script[type=importmap]")?.nonce || "" })
    script.textContent = `import * as detector from "scanner/detector"; window.__scannerDetector = detector; dispatchEvent(new Event("detector-ready"))`
    document.head.append(script)
  })
  window.__detector.then(async (detector) => {
    const bytes = Uint8Array.from(atob(data), (character) => character.charCodeAt(0))
    const photo = await createImageBitmap(new Blob([ bytes ]))
    const found = detector.findCard(photo, { ...detector.SETTINGS, completeTolerance: null })
    done({ found: found.found, corners: found.corners || null, width: photo.width })
  }).catch((error) => done({ error: String(error) }))
JS

records = RUNS.flat_map { |run| CORPUS.join("runs/phase2", run).glob("*/detect.json").map { JSON.parse(it.read) } }
abort "Expected 99 spike records, found #{records.size}." unless records.size == 99

base = ENV.fetch("SCANNER_URL") { "http://127.0.0.1:#{Collector::DevPort.resolve(root: File.expand_path("../..", __dir__))}" }
email = ENV.fetch("SCANNER_EMAIL") { abort "Set SCANNER_EMAIL and SCANNER_PASSWORD to a local user." }
password = ENV.fetch("SCANNER_PASSWORD") { abort "Set SCANNER_EMAIL and SCANNER_PASSWORD to a local user." }
options = Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ], accept_insecure_certs: true)
driver = Selenium::WebDriver.for(:firefox, options:)
driver.manage.timeouts.script_timeout = 120
begin
  driver.navigate.to("#{base}/session/new")
  driver.find_element(name: "email_address").send_keys(email)
  driver.find_element(name: "password").send_keys(password)
  driver.find_element(css: "input[type=submit][value='Sign in']").click
  Selenium::WebDriver::Wait.new(timeout: 30).until { driver.find_elements(css: ".c-avatar").any? }
  driver.navigate.to("#{base}/scanner")
  mismatches = records.sort_by { it["file"] }.filter_map do |record|
    result = driver.execute_async_script(DETECT_JS, Base64.strict_encode64(CORPUS.join(record["path"]).binread))
    abort "#{record["file"]}: #{result["error"]}" if result["error"]
    scale = WORK_WIDTH.fdiv(record["sourceWidth"])
    drift = record["found"] && result["found"] ? record["corners"].flatten.zip(result["corners"].flatten).map { |a, b| (a - b).abs * scale }.max : 0
    same = record["found"] == result["found"] && result["width"] == record["sourceWidth"] && drift <= 1
    puts format("%-16s %-9s spike %-5s app %-5s drift %.3f px%s", record["file"], record["half"], record["found"], result["found"], drift, same ? "" : "  MISMATCH")
    record["file"] unless same
  end
  puts "#{records.size - mismatches.size} of #{records.size} match: the same outcome, and corners within 1 px at work width #{WORK_WIDTH}."
  puts "Mismatches: #{mismatches.join(", ")}" if mismatches.any?
ensure
  driver.quit
end
