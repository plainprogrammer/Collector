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

  # The pane at rest: the answer is in and neither the rise nor the shrink is running. Task 8 adds the wait for the pane's hidden
  # "Done." sentence, which needs the reader's change.
  def wait_for_pane
    expect(page).to have_css(".c-scan--result .c-scanpane__item[aria-current='true']", wait: 30)
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
end
