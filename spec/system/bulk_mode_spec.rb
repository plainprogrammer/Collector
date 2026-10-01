require "rails_helper"

RSpec.describe "Bulk mode", type: :system do
  let(:user) { system_sign_in_as(create(:user)) }

  # [bar top at or below the app header's bottom, the point at Done's center hits Done]
  def bulkbar_uncovered = page.evaluate_script(<<~JS)
    (() => {
      const bar = document.querySelector(".c-bulkbar").getBoundingClientRect()
      const header = document.querySelector(".c-appbar").getBoundingClientRect()
      const done = [...document.querySelectorAll(".c-bulkbar button")].find((b) => b.textContent.trim() === "Done")
      const box = done.getBoundingClientRect()
      const hit = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2)
      return [ bar.top >= header.bottom, done.contains(hit) ]
    })()
  JS

  def own(name, **options) = owned_printing(name, account: user.account, **options)
  def row_box(name) = find("tbody tr", text: name).find("input[type=checkbox]")

  it "counts ticks live, selects everything from the header and shows a mixed header", :aggregate_failures do
    own("Lightning Bolt", quantity: 3)
    own("Opt", quantity: 2)
    visit collection_path
    click_on "Edit many"
    expect(page).to have_css(".c-bulkbar__count", exact_text: "0 of 5 selected")
    page.execute_script("window.__marker = 'still here'")
    row_box("Lightning Bolt").check
    expect(page).to have_css(".c-bulkbar__count", exact_text: "3 of 5 selected")
    expect(page).to have_css("tr[aria-selected=true]", text: "Lightning Bolt")
    check "Select all"
    expect(page).to have_css(".c-bulkbar__count", exact_text: "All 5 items selected")
    row_box("Opt").uncheck
    expect(page).to have_css(".c-bulkbar__count", exact_text: "3 of 5 selected")
    expect(page.evaluate_script("document.querySelector('thead input[type=checkbox]').indeterminate")).to be(true)
    expect(page.evaluate_script("window.__marker")).to eq("still here")
  end

  it "keeps ticks when paging", :aggregate_failures do
    stub_const("CollectionTable::PER_PAGE", 1)
    own("Card A")
    own("Card B")
    visit collection_path
    click_on "Edit many"
    row_box("Card A").check
    click_on "Next"
    expect(page).to have_css(".c-bulkbar__count", exact_text: "1 of 2 selected")
    click_on "Previous"
    expect(row_box("Card A")).to be_checked
  end

  it "leaves bulk mode on Esc, but Esc with a menu open only closes the menu", :aggregate_failures do
    own("Lightning Bolt")
    visit collection_path
    click_on "Edit many"
    expect(page).to have_css(".c-bulkbar")
    find("summary.c-avatar").click
    expect(page).to have_css("details[open]")
    find("body").send_keys(:escape)
    expect(page).to have_no_css("details[open]")
    expect(page).to have_css(".c-bulkbar")
    find("body").send_keys(:escape)
    expect(page).to have_no_css(".c-bulkbar")
    expect(page).to have_css(".c-grid")
    expect(page).to have_current_path(collection_path)
  end

  it "keeps the bulk bar uncovered below the app header when the page scrolls", :aggregate_failures do
    25.times { |index| own("Card #{index.to_s.rjust(2, '0')}") }
    page.current_window.resize_to(1280, 700)
    visit collection_path(bulk: 1)
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    expect(page.evaluate_script("window.scrollY")).to be > 0
    expect(bulkbar_uncovered).to eq([ true, true ])
    click_on "Done"
    expect(page).to have_no_css(".c-bulkbar")
  end

  it "keeps the count and Done in view on a phone, with the actions in a menu", :aggregate_failures do
    own("Lightning Bolt")
    visit collection_path(bulk: 1)
    expect(open_in_narrow_frame(collection_path(bulk: 1), width: 390, height: 844, ready: ".c-bulkbar")).to eq([ 390, true ])
    within_narrow_frame do
      expect(page).to have_css(".c-bulkbar__count", visible: :visible)
      expect(page).to have_button("Done", visible: :visible)
      expect(page).to have_no_css(".c-bulkbar__extra .c-btn", visible: :visible)
      expect(page).to have_css("thead th", visible: :visible, count: 3)
      find(".c-bulkbar__more summary").click
      expect(page).to have_button("Set condition…", visible: :visible)
    end
  end
end
