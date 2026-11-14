require "rails_helper"

RSpec.describe "Card scanner", type: :system do
  before do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  it "asks for the rear camera, draws the guide and reads a lined-up card (AC-1.1, AC-1.3, AC-2.1, AC-3.2)", :aggregate_failures do
    wait_for_scanner
    show_synthetic_card
    expect(page).to have_css(".c-scan__feed:not([hidden]) .c-scan__guide")
    click_on "Capture"
    expect(page).to have_css(".c-scanpane__card:not([hidden])", text: "Lightning Bolt", wait: 30)
    expect(page).to have_css("#scanner_band", text: "Matched by its collector line")
    expect(page.evaluate_script("window.__cameraRequests[0]")).to include("audio" => false, "video" => include("facingMode" => { "ideal" => "environment" }))
    expect(scanner_sent).to eq([ [ "reading[name_text]", "reading[collector_text]", "reading[key]" ] ])
  end

  it "reads one card at a time (AC-2.6)", :aggregate_failures do
    show_synthetic_card
    page.execute_script(%(const shutter = document.querySelector(".c-scan__main"); shutter.click(); shutter.click()))
    expect(page).to have_css(".c-scanpane__card:not([hidden])", text: "Lightning Bolt", wait: 30)
    expect(scanner_sent.size).to eq(1)
  end

  it "stops every camera track when the scanner leaves the page (AC-1.4)" do
    show_synthetic_card
    page.execute_script(%(document.querySelector(".c-scan").remove()))
    expect(eventually("window.__tracks.length > 0 && window.__tracks.every((track) => track.readyState === 'ended')")).to be(true)
  end

  it "shows a live feed again, not a cached picture, when you come back (AC-1.4)" do
    show_synthetic_card
    visit collection_path
    page.go_back
    expect(eventually("document.querySelector('.c-scan__video')?.srcObject?.active === true", wait: 30)).to be(true)
  end

  it "offers the torch only when the camera has one (AC-1.5)", :aggregate_failures do
    wait_for_scanner
    expect(page).to have_no_button("Torch")
    show_synthetic_card(torch: true)
    click_on "Torch"
    expect(page).to have_css("button[aria-label=Torch][aria-pressed=true]")
    click_on "Torch"
    eventually("window.__torch.length === 2")
    expect(page.evaluate_script("window.__torch")).to eq([ true, false ])
  end

  it "explains that the live camera needs HTTPS, without asking for it (AC-1.6, AC-4.1)", :aggregate_failures do
    wait_for_scanner
    page.execute_script(<<~JS)
      Object.defineProperty(window, "isSecureContext", { get: () => false })
      window.__cameraRequests = []
      navigator.mediaDevices.getUserMedia = async (constraints) => { window.__cameraRequests.push(constraints); throw new Error("asked") }
    JS
    restart_camera
    expect(page).to have_css(".c-scan__notice:not([hidden])", text: "The live camera needs this page to be served over HTTPS")
    within(".c-scan__notice") { expect(page).to have_field("Use a photo", type: "file", visible: :all, disabled: false) }
    expect(page).to have_no_button("Try the camera again")
    expect(page.evaluate_script("window.__cameraRequests.length")).to eq(0)
  end

  it "explains a blocked camera and offers to try again (AC-4.1)", :aggregate_failures do
    wait_for_scanner
    page.execute_script(%(navigator.mediaDevices.getUserMedia = async () => { throw new DOMException("blocked", "NotAllowedError") }))
    restart_camera
    expect(page).to have_css(".c-scan__notice:not([hidden])", text: "The camera is blocked for this site")
    expect(page).to have_button("Try the camera again")
    expect(page).to have_button("Capture", disabled: true)
  end

  it "reads a picked photo with the same guide and strips, while the camera is live (AC-4.2, AC-4.3)", :aggregate_failures do
    wait_for_scanner
    expect(page).to have_field("Use a photo", type: "file", visible: :all, disabled: false)
    pick_synthetic_photo
    expect(page).to have_css(".c-scanpane__card:not([hidden])", text: "Lightning Bolt", wait: 30)
    expect(scanner_sent).to eq([ [ "reading[name_text]", "reading[collector_text]", "reading[key]" ] ])
  end

  it "asks you to sign in again when your session has ended" do
    show_synthetic_card
    page.driver.browser.manage.delete_cookie("session_id")
    click_on "Capture"
    expect(page).to have_text("Your session has ended", wait: 30)
  end
end
