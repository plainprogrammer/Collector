require "rails_helper"

# Spec 082 Story 4 and AC-3.1: a capture freezes on its frame, its result fills the stage in the pane, and "Scan again" returns
# to the camera; the guide the page draws is the one the crop uses. The result is spec 088's selection pane; what it shows is in
# scanner_selection_spec.rb.
RSpec.describe "A result in the pane", type: :system do
  before do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "m10"), number: "146"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
  end

  # The centred card's panel, the one a result's selection leaves showing (spec 088 decision 3).
  def card = ".c-scanpane__card:not([hidden])"

  # The pane's hidden "Done." sentence: written once the pane shows, and only when the band holds text (spec 088 decision 11).
  def have_done_sentence = have_css("#status .c-sr", text: /\ADone\. /, visible: :all, wait: 30)

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
      expect(page).to have_css("#{card} .c-scanpane__name", text: "Lightning Bolt", wait: 30)
      expect(find("#scanner_band")).to have_text("Matched by its collector line")
    end
  end

  # Whether the status line's box, holding one line of text (the caller writes it), stays clear of the guide's box, in the page the driver is in.
  def status_clear_of_guide
    page.evaluate_script(<<~JS)
      (() => {
        const text = document.querySelector("#scanner_status_text").getBoundingClientRect()
        const line = document.querySelector(".c-scan__line--status").getBoundingClientRect(), guide = document.querySelector(".c-scan__guide").getBoundingClientRect()
        return { shown: !document.querySelector(".c-scan__line--status").hidden, clear: line.bottom <= guide.top || line.top >= guide.bottom,
                 lines: Math.round(text.height / parseFloat(getComputedStyle(document.querySelector(".c-scan__line-text")).lineHeight)) }
      })()
    JS
  end

  [ [ 390, 844 ], [ 360, 640 ], [ 360, 560 ] ].each do |width, height|
    it "draws the guide the rule gives at #{width} × #{height}, clear of the status line (AC-3.1)", :aggregate_failures do
      open_scanner_frame(width:, height:)
      within_narrow_frame do
        measured = guide_and_rule
        expect(measured["drawn"]).to eq(measured["rule"])
        expect(measured["rule"]).to all(be > 0)
        page.execute_script("document.getElementById('scanner_status_text').textContent = 'Reading the card…'") # one line at every width
        expect(page).to have_css(".c-scan__line--status:not([hidden])")
        expect(status_clear_of_guide).to include("shown" => true, "clear" => true, "lines" => 1)
      end
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
    eventually("typeof window.__release === 'function'", wait: 30) # the held request is made once the OCR has run (slower on CI)
    page.execute_script("window.__release()")
    expect(page).to have_css(".c-scan.c-scan--result #scanner_result #{card} .c-scanpane__name", text: "Lightning Bolt", wait: 30)
    expect(page).to have_done_sentence
    expect(page).to have_css(".c-scan__line--status[hidden]", visible: :all)
    expect(page.evaluate_script("document.getElementById('scanner_status_text').textContent")).to eq("") # AC-4.2: emptied, so the next sentence is announced
    expect(page).to have_button("Scan again", class: "c-btn--secondary")
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
  end

  it "returns to the camera on Scan again, sending nothing (AC-4.4)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css(card, wait: 30)
    sent = scanner_sent.size
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(page).to have_css("#scanner_status_text", text: "Ready. Line the card up with the guide, then capture.")
    expect(page).to have_button("Capture", class: "c-btn--primary", disabled: false)
    expect(page.evaluate_script("document.getElementById('status').textContent")).to eq("")
    expect(scanner_sent.size).to eq(sent)
  end

  it "shows a send failure in the pane, and Scan again discards it (AC-1.4)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.driver.browser.manage.delete_cookie("session_id")
    click_on "Capture"
    expect(page).to have_css(".c-scan--result #status", text: "Your session has ended", wait: 30)
    expect(page).to have_link("Sign in")
    expect(page).to have_no_css(".c-scanpane__card", visible: :all)
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_no_link("Sign in")
  end

  def main_rect = page.evaluate_script("(() => { const b = document.querySelector('.c-scan__main').getBoundingClientRect(); return [b.left, b.top, b.width, b.height] })()")

  it "keeps Scan again where and as big as Capture was (AC-1.6)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    capture_rect = main_rect
    click_on "Capture"
    expect(page).to have_button("Scan again", wait: 30)
    expect(main_rect).to eq(capture_rect)
  end

  # Answers the readings request in the page as the network or the server fails it; `window.__readings` keeps the real fetch.
  def fail_readings(kind)
    page.execute_script(<<~JS, kind)
      const kind = arguments[0], send = window.fetch
      window.__readings = send
      window.fetch = (url, options) => !url.includes("/scanner/readings") ? send(url, options)
        : kind === "network" ? Promise.reject(new TypeError("offline")) : Promise.resolve(new Response("", { status: 500 }))
    JS
  end

  def restore_readings = page.execute_script("window.fetch = window.__readings")

  def failure_block = find(".c-scanner__failure", visible: true)

  %w[network server].each do |kind|
    it "shows a #{kind} failure in the pane with what was read and Send again, which sends again (AC-1.4)", :aggregate_failures do
      visit scanner_path
      show_synthetic_card
      fail_readings(kind)
      click_on "Capture"
      expect(page).to have_css(".c-scan--result #status", text: kind == "network" ? "The text couldn't be sent" : "The scanner had a problem with that card", wait: 30)
      expect(page).to have_css(".c-scan__read-label", text: "Read from the card").and have_css(".c-scan__read-name", text: /bolt/i)
      expect(page).to have_no_css(".c-scan__read-line", text: "nothing read")
      expect(page).to have_no_css(".c-scanpane__card", visible: :all)
      expect(failure_block).to have_button("Send again")
      expect(failure_block).to have_no_link("Sign in")
      restore_readings
      click_on "Send again"
      expect(page).to have_css(".c-scan--result #{card} .c-scanpane__name", text: "Lightning Bolt", wait: 30)
      expect(page).to have_no_css(".c-scanner__failure", visible: true)
    end
  end

  it "discards a failure on Scan again, sending nothing more (AC-4.5)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    fail_readings("network")
    click_on "Capture"
    expect(page).to have_css(".c-scanner__failure", visible: true, wait: 30)
    restore_readings
    sent = scanner_sent.size
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_no_css(".c-scanner__failure", visible: true)
    expect(page).to have_button("Capture", disabled: false)
    expect(scanner_sent.size).to eq(sent)
  end

  def capture_card_reading(name:, lines:)
    visit scanner_path
    show_synthetic_card(name:, lines:)
    click_on "Capture"
  end

  # Nothing read and no match are the status line's sentence with no pane, the camera live behind it (spec 088 decision 11).
  def expect_status_sentence(text)
    expect(page).to have_css("#scanner_status_text", text:, wait: 30)
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_no_css(".c-scanpane__card", visible: :all)
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(page).to have_button("Capture", disabled: false)
  end

  # A refusal that opens the pane is a visible alert in its region with the result empty; Scan again returns to the camera.
  def expect_pane_alert_then_camera(text)
    expect(page).to have_css(".c-scan--result #status .c-status__message--alert", text:, wait: 30)
    expect(page).to have_css(".c-scan__read-name", text: "Lightning Bolt")
    expect(page).to have_no_css(".c-scanpane__card", visible: :all)
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_button("Capture", disabled: false)
    expect(page).to have_css("#scanner_status_text", text: "Ready. Line the card up with the guide")
  end

  it "says nothing could be read on the status line, with no pane (AC-6.1)", :aggregate_failures do
    capture_card_reading(name: "", lines: [ "", "" ])
    expect_status_sentence("Nothing could be read")
  end

  it "says no card matches what was read on the status line, with no pane (AC-6.1)", :aggregate_failures do
    capture_card_reading(name: "Zzyzx Quuxwhistle", lines: [ "R 9999", "ZZZ • EN" ])
    expect_status_sentence("No card matches what was read")
  end

  it "says the catalog isn't ready in the pane, and Scan again returns to the camera (AC-6.2)", :aggregate_failures do
    Catalog::Name.delete_all # the name index a refresh fills is empty
    capture_card_reading(name: "Lightning Bolt", lines: [ "R 0123", "MOM • EN" ])
    expect_pane_alert_then_camera("The card catalog isn't ready yet")
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
    expect(page).to have_css(".c-scan--result #{card} .c-scanpane__name", text: "Lightning Bolt", wait: 30)
  end

  it "clears the shown result and its frozen frame when a photo is picked, the new reading keeping the status line (decision 13)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css(".c-scan--result #{card}", wait: 30)
    open_destination
    eventually("!document.querySelector('#scanner_destination_sheet [data-card-reader-target=picker]').disabled", wait: 30)
    hold_readings
    pick_synthetic_photo(input: "#scanner_destination_sheet [data-card-reader-target=picker]")
    expect(page).to have_css("#scanner_status_text", text: "Reading the card…")
    expect(page).to have_no_css(".c-scanpane__card", visible: :all)
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(page.evaluate_script("document.getElementById('status').textContent")).to eq("")
    eventually("typeof window.__release === 'function'", wait: 30)
    page.execute_script("window.__release()")
    expect(page).to have_css(".c-scan--result #{card} .c-scanpane__name", text: "Lightning Bolt", wait: 30)
  end

  it "returns to the camera-unavailable notice on Scan again after a photo (AC-4.9)", :aggregate_failures do
    visit scanner_path
    page.execute_script(%(navigator.mediaDevices.getUserMedia = async () => { throw new DOMException("blocked", "NotAllowedError") }))
    restart_camera
    expect(page).to have_css(".c-scan__notice:not([hidden])", text: "Use a photo", wait: 30)
    eventually("!document.querySelector('[data-card-reader-target=picker]').disabled", wait: 30)
    pick_synthetic_photo
    expect(page).to have_css(".c-scan--result #{card}", wait: 30)
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
