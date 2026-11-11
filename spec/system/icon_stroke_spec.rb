require "rails_helper"

# Spec 063: a small icon keeps its weight. A stroke scales with the icon, so an icon's weight on screen is its
# stroke-width times its drawn width over 24 (the viewBox); additions.css sets the stroke by the component that draws
# the icon (12px at 2.5, 14px to 16px at 2) and the partials keep their 1.5 for 20px and above. These examples read
# computed styles on the app's own pages, never the previews (the previews are a drawing of the design, not of the app).
RSpec.describe "Icon stroke follows size", type: :system do
  let(:user) { create(:user) }
  let(:printing) do
    create(:mtg_printing, legalities: { "standard" => "legal", "modern" => "legal", "legacy" => "banned", "vintage" => "restricted" })
  end

  before do
    create(:lot, account: user.account, entry: printing.entry, quantity: 2)
    system_sign_in_as(user)
  end

  # The rendered svgs matching `selector` in the current document (the page, or the narrow frame inside
  # `within_narrow_frame`) that have a stroke: an svg with no width (the tab bar on a wide screen, a button hidden at
  # this width) is not drawn, and the filled star has `stroke: none`, so neither is measured.
  def icons(selector = "svg")
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(#{selector.to_json})).map((svg) => {
        const style = getComputedStyle(svg)
        return { width: svg.getBoundingClientRect().width, stroke: style.stroke, strokeWidth: parseFloat(style.strokeWidth) }
      }).filter((icon) => icon.width > 0 && icon.stroke !== "none")
    JS
  end

  # `.to_f`: a whole-number stroke and width come back from the browser as Integers, and 2 * 16 / 24 is 1 in Ruby.
  def weight(icon) = icon["strokeWidth"].to_f * icon["width"] / 24

  # Every icon the selector matches is drawn `size` px wide with a computed stroke of `stroke`.
  def expect_stroke(selector, stroke:, size:)
    seen = icons(selector)
    expect(seen).not_to be_empty, "no rendered stroked icon matched #{selector}"
    expect(seen.map { |icon| [ icon["strokeWidth"].to_f, icon["width"].round ] }.uniq).to eq([ [ stroke.to_f, size ] ]), "#{selector}: #{seen}"
  end

  # The icons whose weight on screen is outside the band of the rule, as "path: px" strings for the failure message.
  def outside_band(where)
    icons.map { |icon| weight(icon).round(3) }.reject { |px| (1.1..1.4).cover?(px) }.map { |px| "#{where}: #{px}px" }
  end

  # The real partials' markup in the badges the scanner draws (a "Matched by…" check, a "Printing not confirmed" alert
  # and a foil star), added to the card page: the scanner's own page needs a camera sitting this spec doesn't.
  def add_badges
    markup = <<~HTML.squish
      <p>
        <span class="c-badge c-badge--success">#{ApplicationController.render(partial: "icons/check")}Matched by its collector line</span>
        <span class="c-badge c-badge--warning">#{ApplicationController.render(partial: "icons/alert")}Printing not confirmed</span>
        <span class="c-badge c-badge--foil">#{ApplicationController.render(partial: "icons/star")}Foil</span>
      </p>
    HTML
    page.execute_script("document.querySelector('main').insertAdjacentHTML('afterbegin', arguments[0])", markup)
  end

  it "draws the legality marks at 12px with a stroke of 2.5", :aggregate_failures do # spec 063 AC-1.1
    visit catalog_entry_path(printing.entry)
    expect_stroke(".c-legal--yes svg", stroke: 2.5, size: 12)
    expect_stroke(".c-legal--no svg", stroke: 2.5, size: 12)
  end

  it "draws the check and the alert in a badge at 12px with a stroke of 2.5, and leaves the star filled", :aggregate_failures do # AC-1.2, AC-1.6
    visit catalog_entry_path(printing.entry)
    add_badges
    expect(page).to have_css(".c-badge--foil svg")
    expect_stroke(".c-badge svg", stroke: 2.5, size: 12)
    expect(icons(".c-badge--foil svg")).to be_empty
  end

  it "draws the search field and the buttons at 16px and the view switch at 14px with a stroke of 2", :aggregate_failures do # AC-1.3
    visit collection_path
    expect_stroke(".c-input svg", stroke: 2, size: 16)
    expect_stroke(".c-btn svg", stroke: 2, size: 16)
    expect_stroke(".c-seg svg", stroke: 2, size: 14)
  end

  it "leaves the tab bar's 22px icons at the partials' 1.5", :aggregate_failures do # AC-1.4
    visit collection_path
    open_in_narrow_frame(collection_path, width: 390, ready: "main")
    within_narrow_frame { expect_stroke(".c-tabbar svg", stroke: 1.5, size: 22) }
  end

  # The guard: an icon at a size or in a component the rule doesn't cover fails here, and so does an icon that shrinks.
  # The weights the rule gives are 1.17px (14px), 1.25px (12px and 20px), 1.33px (16px) and 1.375px (22px).
  it "keeps every rendered stroked icon between 1.1px and 1.4px on screen", :aggregate_failures do # AC-1.5
    [ catalog_entry_path(printing.entry), collection_path, collection_path(view: "table"), catalog_entries_path ].each do |path|
      visit path
      expect(icons).not_to be_empty, "no rendered stroked icon on #{path}"
      expect(outside_band(path)).to be_empty
    end
    open_in_narrow_frame(collection_path, width: 390, ready: "main")
    within_narrow_frame do
      expect(icons).not_to be_empty
      expect(outside_band("the 390px collection page")).to be_empty
    end
  end
end
