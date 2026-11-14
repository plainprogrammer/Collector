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
end
