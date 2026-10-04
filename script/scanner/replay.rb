# Replays a measured run's stored strips through the scanner's recognition code in headless Firefox
# (spec 007 AC-5.6). Needs this checkout's dev server running (measurement mode is on in development).
# Usage: bundle exec ruby script/scanner/replay.rb <label>
#        REFINE=1 bundle exec ruby script/scanner/replay.rb <label> (re-applies spec 009's refinements to strips stored before them)
#        SCANNER_URL=https://127.0.0.1:3578 bundle exec ruby script/scanner/replay.rb <label> (HTTPS dev server)
require "bundler/setup"
require "selenium-webdriver"
require_relative "../../lib/collector/dev_port"

label = ARGV.fetch(0) { abort "usage: bundle exec ruby script/scanner/replay.rb <label>" }
port = Collector::DevPort.resolve(root: File.expand_path("../..", __dir__))
# SCANNER_URL overrides the base URL, e.g. https://127.0.0.1:3578 for a server on the self-signed certificate.
options = Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ], accept_insecure_certs: true)
driver = Selenium::WebDriver.for(:firefox, options:)
begin
  driver.navigate.to("#{ENV.fetch("SCANNER_URL", "http://127.0.0.1:#{port}")}/scanner/measurement/replay?label=#{label}#{ENV["REFINE"] == "1" ? "&refine=1" : ""}")
  Selenium::WebDriver::Wait.new(timeout: 1800, interval: 2).until { driver.execute_script("return Boolean(window.__replay && window.__replay.done)") }
  replay = driver.execute_script("return window.__replay")
  abort "The replay failed: #{replay["error"]}" if replay["error"]
  puts "Replayed #{replay["count"]} captures as #{label}"
ensure
  driver.quit
end
