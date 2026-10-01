# Replays a measured run's stored strips through the scanner's recognition code in headless Firefox
# (spec 007 AC-5.6). Needs this checkout's dev server running (measurement mode is on in development).
# Usage: bundle exec ruby script/scanner/replay.rb <label>
require "bundler/setup"
require "selenium-webdriver"
require_relative "../../lib/collector/dev_port"

label = ARGV.fetch(0) { abort "usage: bundle exec ruby script/scanner/replay.rb <label>" }
port = Collector::DevPort.resolve(root: File.expand_path("../..", __dir__))
driver = Selenium::WebDriver.for(:firefox, options: Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ]))
begin
  driver.navigate.to("http://127.0.0.1:#{port}/scanner/measurement/replay?label=#{label}")
  Selenium::WebDriver::Wait.new(timeout: 1800, interval: 2).until { driver.execute_script("return Boolean(window.__replay && window.__replay.done)") }
  replay = driver.execute_script("return window.__replay")
  abort "The replay failed: #{replay["error"]}" if replay["error"]
  puts "Replayed #{replay["count"]} captures as #{label}"
ensure
  driver.quit
end
