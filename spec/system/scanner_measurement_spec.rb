require "rails_helper"

RSpec.describe "Scanner measurement mode", type: :system do
  let(:corpus) { Pathname(Dir.mktmpdir("corpus")) }

  around do |example|
    corpus.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,mom,123,no\n")
    Rails.configuration.x.scanner_measurement = { manifest: corpus.join("manifest.csv").to_s, dir: corpus.join("runs/live").to_s }
    example.run
  ensure
    Rails.configuration.x.scanner_measurement = nil
    FileUtils.remove_entry(corpus)
  end

  def capture_lightning_bolt(other_printing: false)
    identity = create(:catalog_identity, name: "Lightning Bolt")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123"))
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "m10"), number: "146")) if other_printing
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
    visit scanner_measurement_path
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css("#measurement_run_button", text: "All done · 1 of 1 · full", wait: 30)
    find("#measurement_run_button").click
    expect(page).to have_css("#measurement_panel [data-measurement-target=status]", text: "Stored IMG_1.jpeg as the measured capture")
    find("#measurement_sheet .c-sheet__close").click
  end

  # The events the server has written for a row, waited for like a Capybara matcher (they post after the page updates).
  def recorded_events(row, count:)
    page.document.synchronize(10) do
      Scanner::MeasurementRun.current(framing: "full").events(row).tap { raise Capybara::ExpectationNotMet, "#{count} events" if it.size < count }
    end
  end

  def sign_in_with_a_catalog
    identity = create(:catalog_identity, name: "Lightning Bolt")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
  end

  def choose_shipped_framing
    find("#measurement_run_button").click
    click_on "Shipped framing"
    expect(page).to have_css("#measurement_run_button", text: "· shipped")
  end

  # The drawn guide's box in the stage and the rule's for the framing the page draws, as the page's own geometry module computes it.
  def drawn_and_rule(framing)
    page.evaluate_async_script(<<~JS, framing)
      const [ framing, done ] = arguments
      #{ScannerHelpers::MODULES_JS}
      window.__modules.then(({ geometry }) => {
        const stage = document.querySelector(".c-scan__stage").getBoundingClientRect(), guide = document.querySelector(".c-scan__guide").getBoundingClientRect()
        const rule = geometry.liveGuideRect(stage.width, stage.height, framing)
        done({ drawn: [ guide.width, guide.height ].map((v) => Math.round(v)), rule: [ rule.width, rule.height ].map((v) => Math.round(v)) })
      })
    JS
  end

  it "has the hidden heading and the run sheet's two framing buttons (spec 082 AC-7.1)", :aggregate_failures do
    sign_in_with_a_catalog
    visit scanner_measurement_path
    expect(page).to have_css("main.c-scan h1.c-sr", text: "Measure the scanner", visible: :all)
    expect(page.evaluate_script("(() => { const b = document.querySelector('main.c-scan h1').getBoundingClientRect(); return b.width <= 1 && b.height <= 1 })()")).to be(true)
    find("#measurement_run_button").click
    expect(page).to have_css("dialog#measurement_sheet[open]")
    expect(page).to have_button("Full framing", disabled: true).and have_button("Shipped framing", disabled: false)
  end

  it "shows a capture that couldn't be stored in the pane's region, as well as the sheet's line (spec 082 AC-7.1)", :aggregate_failures do
    sign_in_with_a_catalog
    visit scanner_measurement_path
    show_synthetic_card
    page.execute_script("const send = window.fetch; window.fetch = (url, options) => String(url).includes('/measurement/captures') ? Promise.reject(new TypeError('offline')) : send(url, options)")
    click_on "Capture"
    expect(page).to have_css(".c-scan--result #status", text: "The capture wasn't stored, so it doesn't count yet. Store it again.", wait: 30)
    expect(page).to have_css(".c-scanpane__card:not([hidden])", text: "Lightning Bolt")
    expect(page).to have_css("#measurement_panel [data-measurement-target=retry]:not([hidden])", visible: :all)
    expect(corpus.join("runs/live/full/IMG_1.jpeg/capture-001.json")).not_to exist
  end

  it "stores a Skip under the shipped framing's run, and draws that framing's guide (spec 082 AC-7.2)", :aggregate_failures do
    sign_in_with_a_catalog
    visit scanner_measurement_path
    expect(page).to have_css(".c-scan__feed:not([hidden])", wait: 10)
    full = drawn_and_rule("full")
    expect(full["drawn"]).to eq(full["rule"])
    choose_shipped_framing
    expect(page).to have_css(".c-scan__feed:not([hidden])", wait: 10)
    measured = drawn_and_rule("shipped")
    expect(measured["drawn"]).to eq(measured["rule"])
    expect(measured["drawn"]).not_to eq(full["rule"])
    find("#measurement_run_button").click
    click_on "Skip IMG_1.jpeg"
    expect(page).to have_text("Skipped IMG_1.jpeg.")
    expect(corpus.join("runs/live/shipped/IMG_1.jpeg/skipped.json")).to exist
    expect(corpus.join("runs/live/full/IMG_1.jpeg/skipped.json")).not_to exist
  end

  it "stores a capture against the card chosen before the shutter (AC-5.2, AC-5.3)", :aggregate_failures do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
    visit scanner_measurement_path
    expect(page).to have_css("#measurement_run_button", text: "IMG_1.jpeg · 0 of 1 · full")
    find("#measurement_run_button").click
    expect(page).to have_select("Card to capture", selected: "IMG_1.jpeg · MOM 123 (pending)")
    find("#measurement_sheet .c-sheet__close").click
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css("#measurement_run_button", text: "All done · 1 of 1 · full", wait: 30)
    find("#measurement_run_button").click
    expect(page).to have_text("Stored IMG_1.jpeg as the measured capture")
    expect(corpus.join("runs/live/full/IMG_1.jpeg/capture-001-collector.png")).to exist
  end

  it "records the add with its rank and the Undo against the capture's reading key (AC-9.2)", :aggregate_failures do
    capture_lightning_bolt
    find("button[aria-label='Add Lightning Bolt MOM · 123 Foil']", wait: 30).click
    expect(page).to have_css("#scanner_added_text", text: "Added Lightning Bolt MOM · 123, foil")
    click_on "Undo"
    expect(page).to have_css("#scanner_added_text", text: "Removed 1 × Lightning Bolt (MOM · 123, Foil)")
    row = Scanner::MeasurementRun.current(framing: "full").row("IMG_1.jpeg")
    capture = Scanner::MeasurementRun.current(framing: "full").captures(row).sole
    expect(capture).to include("reading_key" => match(/\A\h{32}\z/), "outline" => "live")
    events = recorded_events(row, count: 2)
    expect(events.map { it.values_at("kind", "rank") }).to eq([ %w[add 1], [ "undo", nil ] ])
    expect(events.map { it["reading_key"] }).to all(eq(capture["reading_key"]))
  end

  it "records the add of a swiped-to printing with the rank 'other' (spec 088 AC-8.2)", :aggregate_failures do
    capture_lightning_bolt(other_printing: true)
    click_on "Next printing"
    expect(page).to have_css(".c-scanpane__card:not([hidden]) .c-scanpane__position", text: "2 of 2 printings")
    within(".c-scanpane__card:not([hidden])") { first(".c-scanpane__add button").click }
    expect(page).to have_css("#scanner_added_text", text: /\AAdded Lightning Bolt M10 · 146/, wait: 10)
    row = Scanner::MeasurementRun.current(framing: "full").row("IMG_1.jpeg")
    expect(recorded_events(row, count: 1).map { it.values_at("kind", "rank") }).to eq([ %w[add other] ])
  end

  it "keeps the live frame and its guide rect, and still sends only the text and key for the reading (spec 010 AC-3.1, AC-5.5)", :aggregate_failures do
    Rails.configuration.x.scanner_measurement = Rails.configuration.x.scanner_measurement.merge(keep_frames: true)
    capture_lightning_bolt
    capture = Scanner::MeasurementRun.current(framing: "full").captures(Scanner::MeasurementRun.current(framing: "full").row("IMG_1.jpeg")).sole
    expect(capture).to include("frame_width" => 900, "frame_height" => 1200, "guide" => include("width" => be > 0))
    expect(corpus.join("runs/live/full/IMG_1.jpeg/capture-001-frame.png")).to exist
    expect(scanner_sent).to include([ "reading[name_text]", "reading[collector_text]", "reading[key]" ])
    frames = scanner_sent.select { it.include?("capture[frame]:file") } # file fields are recorded as "<name>:file"
    expect(frames.size).to eq(1)
    expect(frames.sole).to include("capture[guide]", "capture[name_strip]:file")
  end
end
