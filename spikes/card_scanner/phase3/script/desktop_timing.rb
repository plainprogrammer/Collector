# Runs the timing page in headless Firefox on this machine, as the desktop reference for the phone (spec 010 AC-2.3).
# Usage: (phase 3 server running) bundle exec ruby spikes/card_scanner/phase3/script/desktop_timing.rb
require "bundler/setup"
require "selenium-webdriver"

options = Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ])
driver = Selenium::WebDriver.for(:firefox, options:)
driver.manage.timeouts.script_timeout = 600
begin
  driver.navigate.to("http://127.0.0.1:#{ENV.fetch("SPIKE_LOCAL_PORT", 4301)}/phone/timing.html") # the loopback bind: same page, no certificate
  Selenium::WebDriver::Wait.new(timeout: 60).until { driver.execute_script("return Boolean(window.__phase3Timing)") }
  result = driver.execute_async_script("const done = arguments[0]; window.__phase3Timing.run('cold').then((r) => done({ ok: r.search.n }), (e) => done({ failure: String(e) }))")
  abort result["failure"] if result["failure"]
  puts "desktop reference saved (#{result["ok"]} searches)"
ensure
  driver.quit
end
