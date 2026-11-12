require "rails_helper"

# Issue #317: a filter-bar select with a visible label ("Language" on number entry) keeps the component's gap between the
# label text and the select, as every other control in a bar does. The gap comes from `.c-select` itself, never from a rule
# on one page. A `.c-select` whose name is visually hidden (`c-sr`: the Location, Set selects) draws no label, so its select
# must start where the label starts: if the hidden name were ever in flow, the gap would push the select right.
RSpec.describe "A filter-bar select's label and select", type: :system do
  let(:user) { create(:user) }
  let!(:blue) { create(:location, account: user.account, name: "Blue binder") }
  let(:deck) { create(:deck, account: user.account, name: "Izzet Tempo") }
  let!(:lot) { owned_printing("Lightning Bolt", account: user.account, location: blue, number: "138", quantity: 2) }

  before do
    page.driver.browser.manage.window.resize_to(1280, 900)
    system_sign_in_as(user)
  end

  # A second language of the same printing, so number entry shows its Language select (spec 026 decision 2).
  def add_japanese_printing
    entry = lot.entry
    create(:mtg_printing, finishes: %w[nonfoil foil],
      entry: create(:catalog_entry, identity: entry.identity, name: entry.name, set: entry.set, number: entry.number, language: "ja"))
  end

  # The pages that draw a `c-select`, by name: the one with a visible label first, then those with a hidden one.
  def visible_label_page
    add_japanese_printing
    collection_number_entry_path(type: "mtg", set: lot.entry.set.code, language: "en")
  end

  def hidden_label_pages
    { "collection location" => collection_path(view: "grid"),
      "card search set" => catalog_entries_path,
      "proxy chooser set" => new_deck_zone_proxy_path(deck, "main", q: "Lightning") }
  end

  # Measures every `label.c-select` of the current document: the gap from its name's right edge to the select's left edge,
  # whether the name is visually hidden, and how far the select's left edge is from the label's. The `--space-2` token is
  # resolved by the browser (a probe element's width), so the example reads the design system's value, not a copy of it.
  def measure
    page.evaluate_script(<<~JS)
      (() => {
        const probe = document.createElement("div")
        probe.style.cssText = "position:absolute;visibility:hidden;width:var(--space-2)"
        document.body.append(probe)
        const token = probe.getBoundingClientRect().width
        probe.remove()
        const labels = [...document.querySelectorAll("label.c-select")].map((label) => {
          const name = label.querySelector("span").getBoundingClientRect()
          const select = label.querySelector("select").getBoundingClientRect()
          const box = label.getBoundingClientRect()
          return { hidden: label.querySelector("span").classList.contains("c-sr"),
            gap: select.left - name.right, selectOffset: select.left - box.left, top: select.top, nameTop: name.top, token }
        })
        return labels
      })()
    JS
  end

  def measure_in_frame(path, width:)
    visit collection_path(view: "grid")
    open_in_narrow_frame(path, width:, ready: "main")
    within_narrow_frame { measure }
  end

  # The gap is a whole token on a line the name and the select share (the label never touches its select).
  def expect_gap_of_one_token(found)
    expect(found.size).to eq(1)
    expect(found.first["gap"]).to be_within(0.5).of(found.first["token"])
    expect(found.first["token"]).to be > 0
    expect(found.first["nameTop"]).to be_within(12).of(found.first["top"]) # one row: no stacking hides a missing gap
  end

  it "puts the --space-2 gap between Language and its select on number entry at desktop width", :aggregate_failures do
    visit visible_label_page
    expect(page).to have_css("label.c-select select#number_entry_language")
    expect_gap_of_one_token(measure)
  end

  it "puts the --space-2 gap between Language and its select on a 360px phone", :aggregate_failures do
    expect_gap_of_one_token(measure_in_frame(visible_label_page, width: 360))
  end

  [ "collection location", "card search set", "proxy chooser set" ].each do |name|
    it "leaves the select of #{name} where its label starts (a hidden name takes no gap)", :aggregate_failures do
      visit hidden_label_pages.fetch(name)
      expect(page).to have_css("label.c-select select")
      found = measure
      expect(found.size).to eq(1)
      expect(found.first["hidden"]).to be(true)
      expect(found.first["selectOffset"]).to be_within(0.5).of(0)
    end

    it "leaves the select of #{name} where its label starts on a 360px phone", :aggregate_failures do
      found = measure_in_frame(hidden_label_pages.fetch(name), width: 360)
      expect(found.size).to eq(1)
      expect(found.first["hidden"]).to be(true)
      expect(found.first["selectOffset"]).to be_within(0.5).of(0)
    end
  end
end
