require "rails_helper"

# Spec 009 NFR Performance, measured outside the gating suite: SCANNER_TIMING=1 bin/rspec spec/system/scanner_timing_spec.rb
RSpec.describe "Scanner timings", :timing, type: :system do
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

  before do
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  def report(message) = RSpec.configuration.reporter.message(message)

  def median(values)
    sorted = values.sort
    sorted.size.odd? ? sorted[sorted.size / 2] : (sorted[sorted.size / 2 - 1] + sorted[sorted.size / 2]) / 2.0
  end

  # Milliseconds from tapping Foil to #status changing, for one fresh reading.
  def time_scanner_add
    click_on "Capture"
    button = find("button[aria-label='Add Lightning Bolt MOM · 123 Foil']", wait: 30)
    page.execute_script(<<~JS)
      const status = document.getElementById("status")
      window.__added = null
      new MutationObserver((_, observer) => { window.__added = performance.now(); observer.disconnect() }).observe(status, { childList: true, subtree: true, characterData: true })
      window.__tapped = performance.now()
    JS
    button.click
    eventually("window.__added !== null")
    page.evaluate_script("window.__added - window.__tapped")
  end

  # Milliseconds for each of 20 Other printings frame requests, fetched from the page. Capybara's wait (2 s) is also
  # the async script timeout, which 20 requests can outlast, so it is raised for this script only.
  def time_other_printings(url)
    using_wait_time(60) { page.evaluate_async_script(<<~JS, url) }
      const [ url, done ] = arguments
      ;(async () => {
        const times = []
        for (let i = 0; i < 20; i++) {
          const started = performance.now()
          await (await fetch(url, { headers: { "Turbo-Frame": "scanner_printings" } })).text()
          times.push(performance.now() - started)
        }
        done(times)
      })()
    JS
  end

  it "adds, from tap to announcement, in a median of 500 ms or less (desktop)" do
    show_synthetic_card
    times = Array.new(10) { time_scanner_add }
    report "Add, tap to announcement: median #{median(times).round} ms, slowest #{times.max.round} ms (n=10, conventional median)"
    expect(median(times)).to be <= 500
  end

  it "answers Other printings for a card with 100 printings within 300 ms at the 95th percentile (desktop)" do
    100.times { |index| create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", number: (200 + index).to_s)) }
    times = time_other_printings(scanner_printings_path(card: identity.external_key, key: "d" * 32, set: "mom", number: "123"))
    p95 = times.sort[(0.95 * (times.size - 1)).ceil]
    report "Other printings, 100 printings: p95 #{p95.round} ms (n=20)"
    expect(p95).to be <= 300
  end
end
