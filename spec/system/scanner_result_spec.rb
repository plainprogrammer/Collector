require "rails_helper"

# Spec 082 Story 4 and AC-3.1: a capture freezes on its frame, its result fills the stage in the pane, and "Scan again" returns
# to the camera; the guide the page draws is the one the crop uses.
RSpec.describe "A result in the pane", type: :system do
  before do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "m10"), number: "146"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
  end

  def guide_and_rule
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      #{ScannerHelpers::MODULES_JS}
      window.__modules.then(({ geometry }) => {
        const stage = document.querySelector(".c-scan__stage").getBoundingClientRect(), guide = document.querySelector(".c-scan__guide").getBoundingClientRect()
        const rule = geometry.liveGuideRect(stage.width, stage.height)
        done({ drawn: [ guide.left - stage.left, guide.top - stage.top, guide.width, guide.height ].map((v) => Math.round(v)),
               rule: [ rule.x, rule.y, rule.width, rule.height ].map((v) => Math.round(v)) })
      })
    JS
  end

  it "draws the guide the rule gives for the stage, and the capture reads a card drawn at it (AC-3.1, AC-3.2)", :aggregate_failures do
    open_scanner_frame(width: 390, height: 844)
    within_narrow_frame do
      measured = guide_and_rule
      expect(measured["drawn"]).to eq(measured["rule"])
      expect(measured["rule"]).to eq([ 15, 127, 360, 502 ])
      show_synthetic_card
      click_on "Capture"
      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      expect(first(".c-scanner__candidate")).to have_text("Matched by its collector line")
    end
  end

  it "freezes on the frame while reading, then shows the result in the pane (AC-4.1, AC-4.2)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.execute_script("const send = window.fetch; window.fetch = (url, options) => url.includes('/scanner/readings') ? new Promise((resolve) => { window.__release = () => resolve(send(url, options)) }) : send(url, options)")
    click_on "Capture"
    expect(page).to have_css("canvas.c-scan__frozen:not([hidden])")
    expect(page).to have_css("#scanner_status_text", text: "Reading the card…", wait: 30)
    expect(page).to have_button("Capture", disabled: true)
    page.execute_script("window.__release()")
    expect(page).to have_css(".c-scan.c-scan--result .c-scanpane__results #scanner_result .c-scanner__candidate", text: "Lightning Bolt", wait: 30)
    expect(page).to have_css("#status", text: "Done. What the scanner read and its candidates are showing.")
    expect(page).to have_css(".c-scan__line--status[hidden]", visible: :all)
    expect(page).to have_button("Scan again", class: "c-btn--secondary")
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
  end

  it "returns to the camera on Scan again, sending nothing (AC-4.4)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css(".c-scanner__candidate", wait: 30)
    sent = scanner_sent.size
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(page).to have_css("#scanner_status_text", text: "Ready. Line the card up with the guide, then capture.")
    expect(page).to have_button("Capture", class: "c-btn--primary", disabled: false)
    expect(page.evaluate_script("document.getElementById('status').textContent")).to eq("")
    expect(scanner_sent.size).to eq(sent)
  end

  it "scrolls a long result inside the pane at 360 × 640, the document still (AC-4.3, AC-1.2)", :aggregate_failures do
    open_scanner_frame(width: 360, height: 640)
    within_narrow_frame do
      show_synthetic_card
      click_on "Capture"
      expect(page).to have_css(".c-scanner__candidate", wait: 30)
      click_on "Other printings"
      expect(page).to have_css("#scanner_printings li", minimum: 1, wait: 10)
      scrolled = page.evaluate_script("(() => { const body = document.querySelector('.c-scanpane__results'); body.scrollTop = body.scrollHeight; return body.scrollTop })()")
      expect(scrolled).to be > 0
      expect(one_screen).to include("scrollable" => false, "scrollY" => 0)
      expect(one_screen["main"]["bottom"]).to be <= 640
    end
  end

  it "shows a send failure in the pane, and Scan again discards it (AC-4.5)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.driver.browser.manage.delete_cookie("session_id")
    click_on "Capture"
    expect(page).to have_css(".c-scan--result #status", text: "Your session has ended", wait: 30)
    expect(page).to have_link("Sign in")
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_no_link("Sign in")
  end

  it "says the card couldn't be read and returns to the camera when reading throws (AC-4.10)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.execute_script("window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('.c-scan'), 'camera').grab = () => { throw new Error('no frame') }")
    click_on "Capture"
    expect(page).to have_css("#scanner_status_text", text: "The card couldn't be read. Line it up with the guide and try again.")
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
  end

  it "closes the sheet when a photo is picked from it (AC-2.2)", :aggregate_failures do
    visit scanner_path
    open_destination
    expect(page).to have_css("dialog#scanner_destination_sheet[open]")
    eventually("!document.querySelector('#scanner_destination_sheet [data-card-reader-target=picker]').disabled", wait: 30)
    pick_synthetic_photo(input: "#scanner_destination_sheet [data-card-reader-target=picker]")
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_css(".c-scan--result .c-scanner__candidate", text: "Lightning Bolt", wait: 30)
  end

  it "clears the shown result and its frozen frame when a photo is picked, the new reading keeping the status line (decision 13)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css(".c-scan--result .c-scanner__candidate", wait: 30)
    open_destination
    eventually("!document.querySelector('#scanner_destination_sheet [data-card-reader-target=picker]').disabled", wait: 30)
    hold_readings
    pick_synthetic_photo(input: "#scanner_destination_sheet [data-card-reader-target=picker]")
    expect(page).to have_css("#scanner_status_text", text: "Reading the card…")
    expect(page).to have_no_css(".c-scanner__candidate")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(page.evaluate_script("document.getElementById('status').textContent")).to eq("")
    eventually("typeof window.__release === 'function'", wait: 30)
    page.execute_script("window.__release()")
    expect(page).to have_css(".c-scan--result .c-scanner__candidate", text: "Lightning Bolt", wait: 30)
  end

  it "returns to the camera-unavailable notice on Scan again after a photo (AC-4.9)", :aggregate_failures do
    visit scanner_path
    page.execute_script(%(navigator.mediaDevices.getUserMedia = async () => { throw new DOMException("blocked", "NotAllowedError") }))
    restart_camera
    expect(page).to have_css(".c-scan__notice:not([hidden])", text: "Use a photo", wait: 30)
    eventually("!document.querySelector('[data-card-reader-target=picker]').disabled", wait: 30)
    pick_synthetic_photo
    expect(page).to have_css(".c-scan--result .c-scanner__candidate", wait: 30)
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css(".c-scan__notice:not([hidden])", text: "Use a photo")
  end

  it "redraws the guide when the stage resizes (AC-3.4)", :aggregate_failures do
    visit scanner_path
    expect(page).to have_css(".c-scan__feed:not([hidden])", wait: 10)
    page.current_window.resize_to(900, 1000)
    eventually("(() => { const s = document.querySelector('.c-scan__stage').getBoundingClientRect(); return Math.round(s.width) >= 450 })()")
    measured = guide_and_rule
    expect(measured["drawn"]).to eq(measured["rule"])
  end
end
