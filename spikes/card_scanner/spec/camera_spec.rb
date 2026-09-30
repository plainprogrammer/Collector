require_relative "spike_helper"
require "capybara/rspec"
require "cgi"
require "selenium-webdriver"
require "card_scanner_spike/server"
require "tmpdir"

CAMERA_SOURCE = ENV.fetch("CAMERA_SOURCE") { abort "Set CAMERA_SOURCE to a corpus photo file name" }
CAMERA_Y4M = File.join(CardScannerSpike::WORK_DIR, "camera.y4m")
MATCH_THRESHOLD = 32 # of 256 average-hash bits

Capybara.app = CardScannerSpike::Server.new(public_dir: File.join(CardScannerSpike::ROOT, "public"),
  ocr_dir: File.join(CardScannerSpike::WORK_DIR, "ocr"), corpus_dir: CardScannerSpike.corpus_dir, log_dir: Dir.mktmpdir)
Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 10

Capybara.register_driver(:firefox_fake_camera) do |app|
  options = Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ],
    prefs: { "media.navigator.streams.fake" => true, "media.navigator.permission.disabled" => true })
  Capybara::Selenium::Driver.new(app, browser: :firefox, options:)
end

Capybara.register_driver(:chrome_file_camera) do |app|
  options = Selenium::WebDriver::Chrome::Options.new(args: [ "--headless=new", "--use-fake-ui-for-media-stream",
    "--use-fake-device-for-media-stream", "--use-file-for-fake-video-capture=#{CAMERA_Y4M}" ])
  Capybara::Selenium::Driver.new(app, browser: :chrome, options:)
end

RSpec.describe "Headless camera spike", type: :feature do # rubocop:disable RSpec/DescribeClass -- experiments, not a class
  around do |example|
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    example.run
    seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(2)
    File.open(File.join(CardScannerSpike::WORK_DIR, "camera-results.jsonl"), "a") do |file|
      file.puts({ approach: example.metadata[:approach], distance: @distance, seconds:, passed: example.exception.nil? }.to_json) # rubocop:disable RSpec/InstanceVariable -- carries the measured distance to the recording hook
    end
  end

  def capture_distance
    expect(page).to have_css("#source-hash", text: /\A[01]{256}\z/)
    click_on "Start camera"
    expect(page).to have_button("Capture", disabled: false)
    click_on "Capture"
    expect(page).to have_css("#frame-hash", text: /\A[01]{256}\z/)
    @distance = find("#frame-hash").text.chars.zip(find("#source-hash").text.chars).count { |a, b| a != b }
  end

  it "Firefox's fake camera shows a synthetic pattern, not the card (AC-2.1)", approach: "firefox-fake", driver: :firefox_fake_camera do
    visit "/camera.html?source=#{CGI.escape(CAMERA_SOURCE)}"
    expect(capture_distance).to be > MATCH_THRESHOLD
  end

  it "Chrome plays the card from a file as the camera (AC-2.3a)", approach: "chrome-file", driver: :chrome_file_camera do
    visit "/camera.html?source=#{CGI.escape(CAMERA_SOURCE)}"
    expect(capture_distance).to be <= MATCH_THRESHOLD
  end

  it "an in-page stream drawn from the card works in Firefox (AC-2.3b)", approach: "firefox-in-page", driver: :firefox_fake_camera do
    visit "/camera.html?source=#{CGI.escape(CAMERA_SOURCE)}"
    page.execute_script(<<~JS, CAMERA_SOURCE)
      const file = arguments[0]
      navigator.mediaDevices.getUserMedia = async () => {
        const image = await createImageBitmap(await (await fetch(`/corpus/${encodeURIComponent(file)}`)).blob())
        const canvas = Object.assign(document.createElement("canvas"), { width: image.width, height: image.height })
        const context = canvas.getContext("2d")
        setInterval(() => context.drawImage(image, 0, 0), 100)
        context.drawImage(image, 0, 0)
        return canvas.captureStream(10)
      }
    JS
    expect(capture_distance).to be <= MATCH_THRESHOLD
  end
end
