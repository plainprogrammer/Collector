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

  # Spec 080 decision 8: a live region taken out of the accessibility tree while empty is not announced when it is filled in the
  # same moment, so the empty regions stay rendered and take no space instead.
  it "keeps the empty live regions rendered, taking no space (spec 080 decision 8)", :aggregate_failures do
    visit scanner_path
    expect(page).to have_css(".c-scan__feed:not([hidden])", wait: 10)
    regions = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".c-scan__pane-status, .c-scan__sheet-status")].map((region) => {
        const style = getComputedStyle(region)
        const gap = parseFloat(getComputedStyle(region.parentElement).rowGap) || 0
        return { id: region.id, empty: region.textContent === "", display: style.display, visibility: style.visibility,
                 space: parseFloat(style.marginTop) + parseFloat(style.marginBottom) + parseFloat(style.paddingTop) + parseFloat(style.paddingBottom) + gap }
      })
    JS
    expect(regions.map { it["id"] }).to contain_exactly("status", "scanner_list_status", "scanner_destination_status")
    expect(regions).to all(include("empty" => true, "visibility" => "visible"))
    expect(regions.map { it["display"] }).not_to include("none")
    # the pane's region cancels the column's gap; a sheet's region has no margin and its parent no gap
    expect(regions.map { it["space"] }).to all(eq(0))
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

  # Writes a sentence into the sheet's region as an answer to a Set does, then closes it three ways and reads the region each time.
  it "leaves the sheet's live region empty once the sheet closes, however it closes (AC-2.4)", :aggregate_failures do
    visit scanner_path
    region = "document.getElementById('scanner_destination_status').textContent"
    [ -> { click_on "Close" }, -> { find("dialog[open]").send_keys(:escape) } ].each do |close|
      open_destination
      click_on "Set"
      expect(page).to have_css("#scanner_destination_status", text: "Cards you scan now")
      close.call
      expect(page).to have_no_css("dialog[open]")
      expect(page.evaluate_script(region)).to eq("")
    end
  end

  # The bottom bar's padding on each side is the design system's --space-4 (16px) when no inset is set.
  def main_beside_torch
    page.evaluate_script(<<~JS)
      (() => {
        const bar = document.querySelector(".c-scan__bottom"), main = document.querySelector(".c-scan__main").getBoundingClientRect()
        const padding = parseFloat(getComputedStyle(bar).paddingRight)
        return { gap: bar.getBoundingClientRect().right - padding - main.right, width: main.width, torchShown: !document.querySelector(".c-scan__torch").hidden }
      })()
    JS
  end

  it "gives the main button the torch's room until the camera has a torch (AC-1.5)", :aggregate_failures do
    open_scanner_frame(width: 390, height: 844)
    within_narrow_frame do
      show_synthetic_card
      without = main_beside_torch
      expect(without).to include("torchShown" => false)
      expect(without["gap"]).to be_within(0.5).of(0)
      show_synthetic_card(torch: true)
      expect(page).to have_css(".c-scan__torch:not([hidden])")
      with = main_beside_torch
      expect(with["width"]).to be < without["width"]
      expect(without["width"] - with["width"]).to be_within(1).of(56 + 12) # the torch's width and the bar's gap
    end
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

  # The after-add line's box against the guide's, and how many lines its sentence takes, read in one script (spec 082 AC-3.1).
  def added_line_clear_of_guide
    page.evaluate_script(<<~JS)
      (() => {
        const text = document.querySelector("#scanner_added_text"), line = document.querySelector(".c-scan__line--added").getBoundingClientRect()
        const guide = document.querySelector(".c-scan__guide").getBoundingClientRect()
        return { clear: line.bottom <= guide.top || line.top >= guide.bottom, lines: Math.round(text.getBoundingClientRect().height / parseFloat(getComputedStyle(text).lineHeight)) }
      })()
    JS
  end

  # While the engine loads (AC-1.2): startEngine's synchronous part sets the state before its first await, so the state is read
  # in the same script that calls it, with nothing else able to run between.
  def engine_loading_state
    page.evaluate_script(<<~JS)
      (() => {
        const reader = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(".c-scan"), "card-reader")
        reader.startEngine()
        const main = document.querySelector(".c-scan__main"), box = main.getBoundingClientRect(), root = document.documentElement
        window.scrollTo(0, root.scrollHeight)
        return { label: main.textContent.trim(), disabled: main.disabled, busy: main.getAttribute("aria-busy"), inView: box.top >= 0 && box.bottom <= window.innerHeight,
                 scrolls: root.scrollHeight > root.clientHeight || window.scrollY > 0 }
      })()
    JS
  end

  [ [ 390, 844 ], [ 360, 640 ], [ 360, 560 ] ].each do |width, height|
    it "shows Capture disabled and busy, in view, while the engine loads at #{width} × #{height} (AC-1.2)", :aggregate_failures do
      open_scanner_frame(width:, height:)
      within_narrow_frame do
        expect(engine_loading_state).to eq("label" => "Capture", "disabled" => true, "busy" => "true", "inView" => true, "scrolls" => false)
      end
    end
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
      expect(added_line_clear_of_guide).to include("clear" => true) # AC-3.1, however many lines the sentence wraps to
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
