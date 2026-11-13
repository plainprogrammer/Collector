require "rails_helper"

# Spec 082 Stories 1 and 2: the scanner is one screen that never scrolls, at phone sizes in a frame and at a desktop width, and
# its sheets open over the running camera without a navigation.
RSpec.describe "The one-screen scanner", type: :system do
  let(:user) { create(:user) }

  before { system_sign_in_as(user) }

  [ [ 390, 844 ], [ 360, 640 ], [ 360, 560 ] ].each do |width, height|
    it "is one screen at #{width} × #{height}, with the body focused and no header, tab bar or footer (AC-1.1)", :aggregate_failures do
      expect(open_scanner_frame(width:, height:)).to eq(width)
      within_narrow_frame do
        expect(page).to have_css("body.c-shell.c-shell--untabbed.c-shell--focused")
        expect(page).to have_no_css("#appbar, .c-tabbar, footer.c-footer")
        expect_one_screen(height)
        expect(page_fits_sideways?).to be(true)
      end
    end
  end

  it "is a centred 480px column at a desktop width, its sheet under it (AC-1.7)", :aggregate_failures do
    page.current_window.resize_to(1280, 900)
    visit scanner_path
    expect(page).to have_css(".c-scan__feed:not([hidden])", wait: 10)
    shell = page.evaluate_script("(() => { const b = document.querySelector('.c-scan').getBoundingClientRect(); return [b.left, b.width] })()")
    expect(shell).to eq([ (page.evaluate_script("document.documentElement.clientWidth") - 480) / 2.0, 480 ])
    expect_one_screen(page.evaluate_script("window.innerHeight"))
    open_destination
    sheet = page.evaluate_script("(() => { const b = document.querySelector('dialog[open]').getBoundingClientRect(); return [b.left, b.width] })()")
    expect(sheet).to eq(shell)
  end

  it "opens the destination sheet over the running camera and closes it three ways (AC-2.1, AC-2.2, AC-2.4)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.execute_script("window.__marker = 'still here'")
    [ -> { click_on "Close" }, -> { find("dialog[open]").send_keys(:escape) }, -> { page.execute_script("document.querySelector('dialog[open]').dispatchEvent(new MouseEvent('click', { bubbles: true }))") } ].each do |close|
      find(".c-scan__dest").send_keys(:enter) # by keyboard: Firefox on a Mac doesn't focus a clicked button, so a click leaves no opener to return to
      expect(page).to have_css("dialog#scanner_destination_sheet[open]")
      expect(page.evaluate_script("document.activeElement.closest('dialog')?.id")).to eq("scanner_destination_sheet")
      close.call
      expect(page).to have_no_css("dialog[open]")
      expect(page.evaluate_script("document.activeElement.classList.contains('c-scan__dest')")).to be(true)
    end
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
  end

  it "holds the sheet's parts in order: its region, the form, Use a photo and its hint, the foot (AC-2.2)" do
    visit scanner_path
    open_destination
    order = page.evaluate_script(<<~JS)
      Array.from(document.querySelector("#scanner_destination_sheet .c-sheet__body").children).map((el) => el.id || el.className)
    JS
    expect(order).to eq(%w[scanner_destination_status scanner_picker c-scan__photo c-sheet__foot])
  end

  it "opens the list sheet from the count, with the camera running (AC-6.1)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.execute_script("window.__marker = 'still here'")
    open_sitting_list
    expect(page).to have_css("dialog#scanner_list_sheet[open] #scanner-sitting-heading", text: "This sitting: 0 cards")
    expect(page).to have_css("#scanner_list_sheet .c-empty", text: "Nothing added yet.")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
  end

  # AC-1.2's states at one viewport: aiming, reading, a result, after an add, the camera unavailable; the engine failing is
  # T6.1's. The main button's label and state are the table's, and the page stays one screen in each.
  def expect_states_at(width, height)
    open_scanner_frame(width:, height:)
    within_narrow_frame do
      expect(page).to have_button("Capture", disabled: false, wait: 30)
      expect_one_screen(height)
      show_synthetic_card
      hold_readings
      click_on "Capture"
      expect(page).to have_button("Capture", disabled: true, wait: 30)
      expect_one_screen(height)
      eventually("typeof window.__release === 'function'", wait: 30) # the held request is made once the OCR has run
      page.execute_script("window.__release()")
      expect(page).to have_button("Scan again", wait: 30)
      expect_one_screen(height)
      find("button[aria-label='Add Lightning Bolt MOM · 123 Foil']").click
      expect(page).to have_css("#scanner_added_text", text: "Added")
      expect(page).to have_button("Capture", disabled: false)
      expect_one_screen(height)
      page.execute_script(%(navigator.mediaDevices.getUserMedia = async () => { throw new DOMException("blocked", "NotAllowedError") }))
      restart_camera
      expect(page).to have_button("Capture", disabled: true)
      expect_one_screen(height)
    end
  end

  [ [ 390, 844 ], [ 360, 640 ], [ 360, 560 ] ].each do |width, height|
    it "keeps the main button in view through aiming, reading, a result, an add and the camera unavailable at #{width} × #{height} (AC-1.2, AC-1.6)", :aggregate_failures do
      create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity: create(:catalog_identity, name: "Lightning Bolt"), name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123"))
      Catalog::NameIndex.new("mtg").rebuild
      expect_states_at(width, height)
    end
  end

  # A real failed load: the engine's script is not served, so there is no engine to start (spec 007 AC-2.2). A fresh version in
  # the path keeps the browser's cache of the files from earlier examples out of it. Ruling: this, not a stubbed `createWorker`
  # plus `retryEngine`, because a loaded worker is cached for the page's life, so a retry after a good load never fails.
  def withhold_the_engine
    stub_const("Collector::OcrEngine::VERSION", "v0.0.1")
    allow(Collector::OcrEngine).to receive(:path_for).and_return(nil)
  end

  [ [ 390, 844 ], [ 360, 640 ], [ 360, 560 ] ].each do |width, height|
    it "shows the engine's failure as a stage notice, the main button in view at #{width} × #{height} (Error Scenarios, AC-1.2)", :aggregate_failures do
      withhold_the_engine
      open_scanner_frame(width:, height:)
      within_narrow_frame do
        expect(page).to have_css(".c-scan__notice:not([hidden])", text: "The scanner couldn't load", wait: 30)
        expect(page).to have_button("Load the scanner again")
        expect(page).to have_button("Capture", disabled: true)
        expect_one_screen(height)
      end
    end
  end

  it "says the catalog isn't loaded on a line at the stage's foot (Error Scenarios, decision 14)", :aggregate_failures do
    visit scanner_path # no catalog refresh has run in this example
    expect(page).to have_css(".c-scan__catalog #catalog_not_loaded", text: "The card catalog hasn't been loaded yet.")
    expect(page).to have_button("Capture", wait: 30)
  end
end
