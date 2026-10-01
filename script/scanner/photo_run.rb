# Replays the manifest's photos through the scanner's photo picker in headless Firefox and stores each one as a
# capture in measurement mode (spec 007 Story 6, AC-6.2). Needs a dev server running with measurement mode on,
# and a user to sign in as.
# Usage: SCANNER_EMAIL=you@example.com SCANNER_PASSWORD=... bundle exec ruby script/scanner/photo_run.rb
#        SCANNER_URL=http://127.0.0.1:3590 overrides the base URL (default: this checkout's dev port).
require "bundler/setup"
require "selenium-webdriver"
require_relative "../../lib/collector/dev_port"

PHOTO_TIMEOUT = 120

# Hands the photo to the real picker, as a person choosing a file would, after marking the current panel so the
# wait below can tell its Turbo Stream replacement apart from it.
PICK_JS = <<~JS.freeze
  const [ file, done ] = arguments
  window.__panelBefore = document.getElementById("measurement_panel")
  fetch(`/scanner/measurement/photos/${encodeURIComponent(file)}`).then(async (response) => {
    if (!response.ok) return done(`HTTP ${response.status} for ${file}`)
    const blob = await response.blob()
    const transfer = new DataTransfer()
    transfer.items.add(new File([ blob ], file, { type: blob.type }))
    const input = document.querySelector("[data-card-reader-target=picker]")
    input.files = transfer.files
    input.dispatchEvent(new Event("change", { bubbles: true }))
    done(null)
  }).catch((error) => done(String(error)))
JS

# The capture's outcome: the stored message, an alert, or the measurement controller's "store again" prompt.
OUTCOME_JS = <<~JS.freeze
  const panel = document.getElementById("measurement_panel")
  const status = panel.querySelector("[data-measurement-target=status]")
  const retry = panel.querySelector("[data-measurement-target=retry]")
  if (retry && !retry.hidden) return { alert: status.textContent.trim() }
  if (panel === window.__panelBefore || !status || status.hidden) return null
  return status.classList.contains("c-status__message--alert") ? { alert: status.textContent.trim() } : { notice: status.textContent.trim() }
JS

NEXT_FILE_JS = <<~JS.freeze
  const panel = document.getElementById("measurement_panel")
  if (!panel || panel.querySelector(".c-empty")) return null
  return panel.querySelector("select[name=file]").value
JS

base = ENV.fetch("SCANNER_URL") { "http://127.0.0.1:#{Collector::DevPort.resolve(root: File.expand_path("../..", __dir__))}" }
email = ENV.fetch("SCANNER_EMAIL") { abort "Set SCANNER_EMAIL and SCANNER_PASSWORD to a local user." }
password = ENV.fetch("SCANNER_PASSWORD") { abort "Set SCANNER_EMAIL and SCANNER_PASSWORD to a local user." }

options = Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ], accept_insecure_certs: true)
driver = Selenium::WebDriver.for(:firefox, options:)
driver.manage.timeouts.script_timeout = 60
wait = ->(timeout, &block) { Selenium::WebDriver::Wait.new(timeout:, interval: 0.25, ignore: [ Selenium::WebDriver::Error::NoSuchElementError ]).until(&block) }
stored = 0
begin
  driver.navigate.to("#{base}/session/new")
  driver.find_element(name: "email_address").send_keys(email)
  driver.find_element(name: "password").send_keys(password)
  driver.find_element(css: "input[type=submit][value='Sign in']").click
  wait.call(30) { driver.find_elements(css: ".c-avatar").any? || driver.find_elements(css: ".c-status__message--alert, [role=alert]").any? }
  abort "Couldn't sign in as #{email}." if driver.find_elements(css: ".c-avatar").empty?

  driver.navigate.to("#{base}/scanner/measurement")
  abort "Measurement mode isn't on at #{base}." if driver.find_elements(id: "measurement_panel").empty?
  picker_ready = -> { wait.call(120) { driver.find_element(css: "[data-card-reader-target=picker]").enabled? } }
  picker_ready.call # the engine has loaded

  while (file = driver.execute_script(NEXT_FILE_JS))
    picker_ready.call # the previous photo's reading has finished
    error = driver.execute_async_script(PICK_JS, file)
    abort "Couldn't hand #{file} to the picker: #{error}" if error

    outcome = begin
      wait.call(PHOTO_TIMEOUT) { driver.execute_script(OUTCOME_JS) }
    rescue Selenium::WebDriver::Error::TimeoutError
      abort "#{file}: nothing was stored within #{PHOTO_TIMEOUT} s. Stored #{stored} captures."
    end
    abort "#{file}: #{outcome["alert"]} Stored #{stored} captures." if outcome["alert"]
    abort "#{file}: unexpected message #{outcome["notice"].inspect}. Stored #{stored} captures." unless outcome["notice"].start_with?("Stored #{file}")

    stored += 1
    puts outcome["notice"]
  end
  puts "Stored #{stored} captures"
ensure
  driver.quit
end
