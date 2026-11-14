require "rails_helper"

# Spec 088: a capture's result as the selection pane: the strip, the band, the swipe row, the details block and one add per finish.
RSpec.describe "The selection pane", type: :system do
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

  before do
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "m10", name: "Magic 2010"), number: "146"))
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "2x2", name: "Double Masters 2022"), number: "117"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
  end

  # The pane at rest: the answer is in, the reader has written the pane's hidden "Done." sentence, and neither the rise nor the
  # shrink is running.
  def wait_for_pane
    expect(page).to have_css(".c-scan--result .c-scanpane__item[aria-current='true']", wait: 30)
    expect(page).to have_css("#status .c-sr", text: /\ADone\. /, visible: :all, wait: 30)
    eventually("document.getAnimations().every((animation) => animation.playState !== 'running')")
  end

  def capture_synthetic(frame: false)
    show_synthetic_card
    click_on "Capture"
    wait_for_pane
  end

  def band = find("#scanner_band")

  it "shows the capture beside what was read, the band, the row and the first panel (AC-1.1, AC-2.1, AC-3.1)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    expect(page).to have_css(".c-scan.c-scan--result .c-scan__strip .c-scan__read-name", text: "Lightning Bolt")
    expect(page).to have_css(".c-scan__read-line", text: /MOM/)
    expect(page.evaluate_script("[document.querySelector('.c-scan__capture').width, document.querySelector('.c-scan__capture').height]")).to eq([ 178, 248 ])
    expect(band).to have_css("svg").and have_text("Matched by its collector line")
    expect(band[:class]).to include("c-band--success")
    expect(page).to have_css(".c-scanpane__item", count: 3)
    expect(page).to have_css(".c-scanpane__item[aria-current='true']", count: 1)
    expect(page).to have_css(".c-scanpane__card:not([hidden])", count: 1)
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "1 of 3 printings")
    expect(page).to have_no_css(".c-scanpane__results, .c-scanner__candidate, #scanner_printings", visible: :all)
  end

  it "writes the reading's text as text (AC-1.2)" do
    visit scanner_path
    show_synthetic_card(name: "<b>Bolt</b>")
    click_on "Capture"
    wait_for_pane
    expect(page).to have_no_css(".c-scan__read-name b")
  end

  it "steps to the next printing with Next: the same band element, replaced in place (AC-2.4, AC-3.2, AC-7.2)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    page.evaluate_script("window.__band = document.getElementById('scanner_band'); true")
    expect(page).to have_button("Previous printing", disabled: true)
    click_on "Next printing"
    expect(page).to have_css(".c-scanpane__item:nth-child(2)[aria-current='true']")
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "2 of 3 printings")
    expect(band).to have_text("Not the printing that was read")
    expect(band[:class]).to include("c-band--warning")
    expect(band.text(:all)).to include("Printing 2 of 3:")
    expect(page.evaluate_script("window.__band === document.getElementById('scanner_band') && document.querySelectorAll('.c-band').length === 1")).to be(true)
    expect(page).to have_button("Previous printing", disabled: false)
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
    click_on "Previous printing"
    expect(band).to have_text("Matched by its collector line")
  end

  it "disables Next at the last item and moves focus to Previous (AC-3.3)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    click_on "Next printing"
    expect(page).to have_css(".c-scanpane__item:nth-child(2)[aria-current='true']")
    find_button("Next printing").send_keys(:enter) # Firefox on a Mac does not focus a clicked button (scanner_page_spec.rb:57)
    expect(page).to have_button("Next printing", disabled: true)
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-label')")).to eq("Previous printing")
  end

  it "steps with the arrow keys on the focused row (AC-3.4)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    find(".c-scanpane__row").send_keys(:arrow_right)
    expect(page).to have_css(".c-scanpane__item:nth-child(2)[aria-current='true']")
    find(".c-scanpane__row").send_keys(:arrow_left)
    expect(page).to have_css(".c-scanpane__item:nth-child(1)[aria-current='true']")
  end

  it "notes the nearest item when the row is scrolled by script, and when a neighbour is tapped (AC-3.5, AC-3.6)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    page.execute_script("const row = document.querySelector('.c-scanpane__row'); row.style.scrollBehavior = 'auto'; row.scrollLeft = row.scrollWidth")
    expect(page).to have_css(".c-scanpane__item:nth-child(3)[aria-current='true']", wait: 5)
    page.execute_script("document.querySelectorAll('.c-scanpane__item')[1].click()") # Next covers the neighbour's visible part, so a driver click is intercepted
    expect(page).to have_css(".c-scanpane__item:nth-child(2)[aria-current='true']")
  end

  it "says 'Done.' and the band's sentence once, as hidden text in the pane's region, and no 'What the scanner read' (AC-7.1)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    paragraph = find("#status .c-sr", visible: :all)
    expect(paragraph.text(:all)).to start_with("Done. Matched by its collector line")
    expect(paragraph.text(:all)).to include("Printing 1 of 3:")
    expect(page).to have_no_css("#status .c-status__message")
    expect(page).to have_no_text("What the scanner read")
  end

  it "adds the centred printing in the tapped finish, and the pane closes with the camera live (AC-4.4, AC-4.5, AC-7.4)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    click_on "Add foil"
    expect(page).to have_css("#scanner_added_text", text: "Added Lightning Bolt MOM · 123, foil", wait: 10)
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("#scanner_band:empty", visible: :all)
    eventually("document.activeElement.classList.contains('c-scan__main')")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(Lot.where(finish: "foil").count).to eq(1)
  end

  it "adds the swiped-to printing, not the matched one (AC-4.5)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    click_on "Next printing"
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "2 of 3 printings")
    within(".c-scanpane__card:not([hidden])") { first(".c-scanpane__add button").click }
    expect(page).to have_css("#scanner_added_text", text: /\AAdded Lightning Bolt (M10|2X2) · /, wait: 10)
  end

  it "says nothing read on the status line, with no pane, and the camera live (AC-6.1)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card(name: "", lines: [])
    click_on "Capture"
    expect(page).to have_css("#scanner_status_text", text: /Nothing could be read|No card matches/, wait: 30)
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(page).to have_no_css("#status .c-sr, #status .c-status__message")
    expect(page).to have_button("Capture", disabled: false)
  end

  it "returns to the camera on Scan again, emptying the band, the strip's texts and the region (AC-7.5)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    sent = scanner_sent.size
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("#scanner_band:empty", visible: :all)
    expect(page.evaluate_script("[document.querySelector('.c-scan__read-name').textContent, document.getElementById('status').textContent]")).to eq([ "", "" ])
    expect(page).to have_css("#scanner_status_text", text: "Ready. Line the card up with the guide, then capture.")
    expect(scanner_sent.size).to eq(sent)
  end

  it "shows the strip and the failure, no band, after a send failure (AC-1.4)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.driver.browser.manage.delete_cookie("session_id")
    click_on "Capture"
    expect(page).to have_css(".c-scan--result .c-scan__read-name", text: "Lightning Bolt", wait: 30)
    expect(page).to have_link("Sign in")
    expect(page).to have_css("#scanner_band:empty", visible: :all)
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
  end

  it "shows a picked photo's card on the strip, and a no-edge sentence after 'Done.' (AC-1.3)", :aggregate_failures do
    visit scanner_path
    wait_for_scanner
    pick_synthetic_photo(flat: true, input: "#scanner_destination_sheet input[type=file]") # readable text, no card edge: guide placement
    wait_for_pane
    expect(page).to have_css(".c-scan__read-name", text: "Lightning Bolt")
    expect(page.evaluate_script("[document.querySelector('.c-scan__capture').width, document.querySelector('.c-scan__capture').height]")).to eq([ 178, 248 ])
    expect(page).to have_css("#status .c-sr", text: /\ADone\. /, visible: :all)
    expect(page).to have_css("#status .c-status__message:not(.c-status__message--alert)", text: /No card edge was found/)
  end

  it "says nothing about art in the pane with art matching off (AC-2.6)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    expect(page).to have_no_text(/artwork/i, wait: 0)
    expect(page).to have_no_css("#scanner_art_status, [data-card-reader-target=artStatus]", visible: :all) # it is in the destination sheet only with art on
  end

  it "opens a possible card's printings from All printings, in the frame, with focus on Next (AC-3.9)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card(name: "Lightning", lines: [])
    click_on "Capture"
    wait_for_pane
    expect(band).to have_text("Not sure of this card. Check it against your capture.")
    expect(find(".c-scanpane__row")["aria-label"] || find(".c-scanpane__rowwrap")["aria-label"]).to eq("Possible cards")
    page.execute_script("window.__marker = true")
    find_link("All printings").send_keys(:enter)
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "1 of 3 printings")
    expect(band).to have_text("Printing not confirmed. Swipe to check.")
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-label')")).to eq("Next printing")
    expect(page.evaluate_script("window.__marker")).to be(true)
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
  end

  it "keeps the centred printing centred and focus on Next when Show 20 more renders the frame again (AC-3.10)", :aggregate_failures do
    24.times { |i| create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "t#{i}", name: "Set #{i}"), number: i.to_s)) }
    visit scanner_path
    capture_synthetic
    expect(page).to have_css(".c-scanpane__item--more")
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "1 of 27 printings")
    page.execute_script("const row = document.querySelector('.c-scanpane__row'); row.style.scrollBehavior = 'auto'; row.scrollLeft = row.scrollWidth")
    expect(page).to have_css(".c-scanpane__card:not([hidden]) a.c-btn", text: "Show 20 more", wait: 5)
    find_link("Show 20 more").send_keys(:enter)
    expect(page).to have_css(".c-scanpane__item", count: 27)
    expect(page).to have_no_css(".c-scanpane__item--more")
    expect(page).to have_css(".c-scanpane__item[aria-current='true']", count: 1)
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "20 of 27 printings")
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-label')")).to eq("Next printing")
  end

  it "says so in the pane's region and leaves the row as it was when the selection request fails (AC-3.11)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card(name: "Lightning", lines: [])
    click_on "Capture"
    wait_for_pane
    page.execute_script("const send = window.fetch; window.fetch = (url, options) => String(url).includes('/scanner/printings') ? Promise.reject(new TypeError('offline')) : send(url, options)")
    find_link("All printings").send_keys(:enter)
    expect(page).to have_css("#status .c-status__message--alert", text: "The card's printings couldn't be loaded. Tap “All printings” again.")
    expect(page).to have_css(".c-scanpane__item", count: 1)
  end

  it "shows a card named with markup as text on every pane surface (AC-6.3)", :aggregate_failures do
    Catalog::Entry.find_by!(number: "123").update!(name: "Bolt <i>x</i>")
    visit scanner_path
    capture_synthetic
    expect(page).to have_no_css(".c-scanpane__name i, .c-scanpane__item img[alt*='<i>'] ~ i, #scanner_band i", visible: :all)
    expect(find(".c-scanpane__card:not([hidden]) .c-scanpane__name").text).to eq("Bolt <i>x</i>")
  end

  it "keeps the destination sheet's own region working while a result shows (AC-7.3)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    open_destination
    within("#scanner_destination_sheet") { click_on "Set" }
    expect(page).to have_css("#scanner_destination_status", text: /Cards you scan now/)
    expect(page).to have_no_css("#status .c-status__message", text: /Cards you scan now/)
  end

  it "records the add's rank: 1 on the matched printing, 'other' on a swiped-to one (AC-8.2)", :aggregate_failures do
    visit scanner_path
    capture_synthetic
    expect(page).to have_css(".c-scanpane__card:not([hidden]) form.c-scanpane__add[data-rank='1']", minimum: 1)
    click_on "Next printing"
    expect(page).to have_css(".c-scanpane__card:not([hidden]) form.c-scanpane__add[data-rank='other']", minimum: 1)
  end
end
