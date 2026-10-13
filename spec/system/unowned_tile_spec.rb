require "rails_helper"

# Spec 021: a tile for a card you don't own shows its image as supplied (no fade, filter or blend, nothing over it)
# and says "Not owned" under it; the add buttons of a row that mixes owned and unowned tiles stay level.
RSpec.describe "Unowned tiles", :card_images, type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:bolt) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:tile) { ->(entry) { "##{ActionView::RecordIdentifier.dom_id(entry, :tile)}" } }

  # arguments: a selector. For each match, the computed opacity, filter and blending of the element and of everything
  # between it and its tile cell, and what its slot's and its link's pseudo-elements draw.
  let(:treatment_script) { <<~JS }
    return [ ...document.querySelectorAll(arguments[0]) ].map((element) => {
      const chain = []
      for (let node = element; node; node = node.parentElement) {
        const style = getComputedStyle(node)
        chain.push([ style.opacity, style.filter, style.mixBlendMode, style.backdropFilter ].join(" "))
        if (node.classList.contains("c-tilecell")) break
      }
      const drawn = [ ".c-tile__media", ".c-tile" ].flatMap((selector) => [ "::before", "::after" ]
        .map((pseudo) => getComputedStyle(element.closest(selector), pseudo).content))
      return { chain: [ ...new Set(chain) ], drawn: [ ...new Set(drawn) ] }
    })
  JS
  let(:as_supplied) { { "chain" => [ "1 none normal none" ], "drawn" => [ "none" ] } }

  # The wide layout is checked at 1280px; the window goes back to the suite's size afterwards (as in spec 019's examples).
  before { page.current_window.resize_to(1280, 900) }
  after { page.current_window.resize_to(1400, 1400) }

  def treatment(selector) = page.evaluate_script("(function () { #{treatment_script} })(#{selector.to_json})")

  def printing(image: true, owned: nil, **attributes)
    create(:catalog_entry, identity: bolt, name: "Lightning Bolt", image_url: (card_image_address if image), **attributes).tap do |entry|
      create(:mtg_printing, entry:)
      create(:lot, account: user.account, entry:, quantity: owned) if owned
    end
  end

  def add_button_tops
    page.evaluate_script("[ ...document.querySelectorAll('.c-grid .c-tile__add') ].map((form) => Math.round(form.getBoundingClientRect().top * 100) / 100)")
  end

  def marker_cut_off?(selector)
    page.evaluate_script("(() => { const tag = document.querySelector(#{selector.to_json}); return tag.scrollWidth > tag.clientWidth })()")
  end

  it "shows the image and the placeholder as supplied, in both themes (AC-1.1, AC-1.4)", :aggregate_failures do
    pictured = printing
    bare = printing(image: false, language: "ja")
    visit catalog_entries_path(q: "bolt")
    expect(page).to have_css(".c-tile--owned-none", count: 2)
    card_image_fits("#{tile[pictured]} img", pictures: [ card_picture(488, 680) ])

    expect(treatment("#{tile[pictured]} .c-tile__media > img")).to eq([ as_supplied ])
    expect(treatment("#{tile[bare]} .c-tile__missing")).to eq([ as_supplied ])
    expect(page).to have_css("#{tile[pictured]} .c-tile__media > *", count: 1)

    use_dark_theme
    expect(treatment(".c-tile--owned-none .c-tile__media > *")).to eq([ as_supplied, as_supplied ])
  end

  it "says Not owned under the tile, in the link's name, and nothing on an owned tile (AC-1.2, AC-1.3, AC-1.6)", :aggregate_failures do
    owned = printing(owned: 3)
    unowned = printing(language: "ja")
    visit catalog_entries_path(q: "bolt")

    expect(page).to have_css("#{tile[unowned]} a.c-tile .c-tag", text: "Not owned", visible: :visible)
    expect(page).to have_no_css("#{tile[unowned]} .c-tile__qty")
    expect(page).to have_css("#{tile[owned]} .c-tile__qty", text: "×3")
    expect(page).to have_no_css("#{tile[owned]}", text: "Not owned")
    expect(find("#{tile[unowned]} a.c-tile").native.accessible_name).to end_with("Not owned")
    expect(find("#{tile[owned]} a.c-tile").native.accessible_name).not_to include("Not owned")
  end

  it "keeps a mixed row's add buttons level at 1280px and at phone width (AC-1.7, AC-2.1)", :aggregate_failures do
    printing(owned: 1)
    printing(language: "ja")
    printing(image: false, language: "de")
    printing(owned: 2, language: "fr")
    visit catalog_entries_path(q: "bolt")
    expect(page).to have_css(".c-grid .c-tile__add", count: 4)

    expect(add_button_tops.uniq.size).to eq(1)

    expect(open_in_narrow_frame(catalog_entries_path(q: "bolt"), width: 390, height: 844, ready: ".c-grid")).to eq([ 390, true ])
    within_narrow_frame do
      tops = add_button_tops
      expect(tops.size).to eq(4)
      expect(tops.each_slice(2).map { |row| row.uniq.size }).to eq([ 1, 1 ]) # two columns: owned beside unowned in each row
      expect(marker_cut_off?(".c-tile--owned-none .c-tile__meta:last-child .c-tag")).to be(false)
    end
  end
end
