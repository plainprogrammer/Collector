require "rails_helper"

RSpec.describe "Detection on the scanner's photo path", type: :system do
  before do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
    visit scanner_path
    wait_for_scanner
  end

  def corners_of(card, tilt_degrees)
    cx, cy = card[:x] + card[:width] / 2.0, card[:y] + card[:height] / 2.0
    angle = tilt_degrees * Math::PI / 180
    [ [ -1, -1 ], [ 1, -1 ], [ 1, 1 ], [ -1, 1 ] ].map do |sx, sy|
      dx, dy = sx * card[:width] / 2.0, sy * card[:height] / 2.0
      [ cx + dx * Math.cos(angle) - dy * Math.sin(angle), cy + dx * Math.sin(angle) + dy * Math.cos(angle) ]
    end
  end

  it "finds a tilted card's corners and straightens it into a 3:4 picture (AC-7.1)", :aggregate_failures do
    card = { x: 170, y: 200, width: 859, height: 1200 }
    result = detect_synthetic(card:, tilt_degrees: 3, noise: 2)
    expect(result["found"]).to be(true)
    expect(result["picture"]).to eq([ 1320, 1760 ])
    result["corners"].zip(corners_of(card, 3)).each { |found, real| expect(found.zip(real).map { |a, b| (a - b).abs }.max).to be <= 15 }
  end

  it "finds no card in a photo without one (AC-7.2)" do
    expect(detect_synthetic(card: nil)["found"]).to be(false)
  end

  it "reads a card the guide would miss, sending only the text and the key (AC-7.1, FR-4)", :aggregate_failures do
    pick_photo
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
    expect(first(".c-scanner__candidate")).to have_text("Matched by its collector line")
    expect(scanner_sent).to eq([ [ "reading[name_text]", "reading[collector_text]", "reading[key]" ] ])
  end

  it "falls back to the guide and says no card edge was found (AC-7.2)" do
    pick_photo(card: nil)
    expect(page).to have_css(".c-scanner__status", text: "No card edge was found", wait: 30)
  end

  it "runs no detection on a live capture (AC-7.6)", :aggregate_failures do
    show_synthetic_card
    page.execute_script("window.__outlines = []; document.querySelector('.c-scanner').addEventListener('card-reader:read', (event) => window.__outlines.push(event.detail.outline))")
    click_on "Capture"
    expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
    expect(page.evaluate_script("window.__outlines")).to eq([ "live" ])
  end

  it "tells the collector how to take a photo (AC-7.4)" do
    expect(page).to have_text("Using a photo? Take the whole card, upright, filling most of the photo as the live guide does, on a plain background.")
  end
end
