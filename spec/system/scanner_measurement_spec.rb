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
end
