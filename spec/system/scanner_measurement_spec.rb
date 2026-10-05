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

  def capture_lightning_bolt
    identity = create(:catalog_identity, name: "Lightning Bolt")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
    visit scanner_measurement_path
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_text("Stored IMG_1.jpeg as the measured capture", wait: 30)
  end

  # The events the server has written for a row, waited for like a Capybara matcher (they post after the page updates).
  def recorded_events(row, count:)
    page.document.synchronize(10) do
      Scanner::MeasurementRun.current.events(row).tap { raise Capybara::ExpectationNotMet, "#{count} events" if it.size < count }
    end
  end

  it "stores a capture against the card chosen before the shutter (AC-5.2, AC-5.3)", :aggregate_failures do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
    visit scanner_measurement_path
    expect(page).to have_select("Card to capture", selected: "IMG_1.jpeg · MOM 123 (pending)")
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_text("Stored IMG_1.jpeg as the measured capture", wait: 30)
    expect(corpus.join("runs/live/IMG_1.jpeg/capture-001-collector.png")).to exist
  end

  it "records the add with its rank and the Undo against the capture's reading key (AC-9.2)", :aggregate_failures do
    capture_lightning_bolt
    find("button[aria-label='Add Lightning Bolt MOM · 123 Foil']", wait: 30).click
    expect(page).to have_css("#scanner_sitting", text: "This sitting: 1 card")
    click_on "Undo"
    expect(page).to have_css("#status", text: "Removed 1 × Lightning Bolt (MOM · 123, Foil)")
    row = Scanner::MeasurementRun.current.row("IMG_1.jpeg")
    capture = Scanner::MeasurementRun.current.captures(row).sole
    expect(capture).to include("reading_key" => match(/\A\h{32}\z/), "outline" => "live")
    events = recorded_events(row, count: 2)
    expect(events.map { it.values_at("kind", "rank") }).to eq([ %w[add 1], [ "undo", nil ] ])
    expect(events.map { it["reading_key"] }).to all(eq(capture["reading_key"]))
  end
end
