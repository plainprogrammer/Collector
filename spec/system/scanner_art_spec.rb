require "rails_helper"

RSpec.describe "Art matching on the scanner page", type: :system do
  let(:text_fields) { [ "reading[name_text]", "reading[collector_text]", "reading[key]" ] }
  let(:art_fields) { [ "reading[artworks][][id]", "reading[artworks][][distance]" ] }

  before do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
  end

  # 12 artworks with seeded random fingerprints, so a search finds 10 (AC-5.3). The index is served immutable and the
  # browser's cache outlives an example, so an example that alters the file names its own catalog version.
  def write_index(count: 12, catalog_version: "v1")
    random = Random.new(11)
    records = Array.new(count) { |i| [ format("aaaaaaaa-0000-4000-8000-%012d", i), random.bytes(128) ] }
    MTG::Art::Index.write!(catalog_version, records)
  end

  it "shows no art status and sends only the text with art matching off (AC-1.1, AC-5.1)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
    expect(page).to have_no_css(".c-scanner__art")
    expect(scanner_sent).to eq([ text_fields ])
  end

  context "with art matching on", :art_matching do
    it "has no status line until an index is built (Error Scenarios)" do
      visit scanner_path
      wait_for_scanner
      expect(page).to have_no_css(".c-scanner__art")
    end

    it "loads the index after the scanner starts and sends the 10 nearest artworks with a live capture (AC-5.1–AC-5.3, AC-5.5)", :aggregate_failures do
      write_index
      visit scanner_path
      expect(page).to have_css(".c-scanner__art[role=status][aria-live=polite]", text: "Artwork matching is on", wait: 30)
      show_synthetic_card
      click_on "Capture"

      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      expect(scanner_sent).to eq([ text_fields + art_fields * 10 ])
    end

    it "says art matching isn't available, and sends text only, when the index doesn't match the page (AC-5.2, AC-5.4)", :aggregate_failures do
      path = write_index(catalog_version: "mismatched")
      bytes = Zlib.gunzip(path.binread)
      bytes[8, 16] = "0123456789abcdef"
      path.binwrite(ActiveSupport::Gzip.compress(bytes))
      visit scanner_path
      expect(page).to have_css(".c-scanner__art", text: "Artwork matching isn't available. The scanner is reading text only.", wait: 30)
      show_synthetic_card
      click_on "Capture"

      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      expect(scanner_sent).to eq([ text_fields ])
    end

    it "sends no artworks with a picked photo (AC-5.4)", :aggregate_failures do
      write_index
      visit scanner_path
      expect(page).to have_css(".c-scanner__art", text: "Artwork matching is on", wait: 30)
      pick_photo
      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 60)
      expect(scanner_sent).to eq([ text_fields ])
    end
  end
end
