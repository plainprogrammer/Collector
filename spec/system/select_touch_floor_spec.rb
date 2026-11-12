require "rails_helper"

# Spec 072: every select meets the touch floor on a coarse pointer, on every page that draws one. Headless Firefox has a
# fine pointer and can't emulate a coarse one, so the examples read the `(pointer: coarse)` rules from the loaded
# stylesheets and apply them to the page as an adopted stylesheet (decision 3): the select rule alone to prove it reaches
# every select (AC-1.2), and every coarse rule to show the layout a touch screen draws (AC-1.4, AC-1.5, AC-1.7). A fine
# pointer's heights are measured with nothing applied (AC-1.3). The pages are the spec's audit table; phone widths use
# the narrow frame, since a window can't go below 500px. The coarse rules are applied in source order as one sheet.
RSpec.describe "Selects meet the touch floor on a coarse pointer", type: :system do
  let(:user) { create(:user) }
  let!(:blue) { create(:location, account: user.account, name: "Blue binder") }
  let!(:deck) { create(:deck, account: user.account, name: "Izzet Tempo") }
  let!(:lot) { owned_printing("Lightning Bolt", account: user.account, location: blue, number: "138", quantity: 2) }
  let(:corpus) { Pathname(Dir.mktmpdir("corpus")) } # five memoized helpers: the cap of RSpec/MultipleMemoizedHelpers

  # Measurement mode (development only) draws its select only with a manifest and a run directory.
  around do |example|
    corpus.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,#{lot.entry.set.code},138,no\n")
    Rails.configuration.x.scanner_measurement = { manifest: corpus.join("manifest.csv").to_s, dir: corpus.join("runs/live").to_s }
    example.run
  ensure
    Rails.configuration.x.scanner_measurement = nil
    FileUtils.remove_entry(corpus)
  end

  before do
    # A second language of the same printing, so number entry shows its Language select (spec 026 decision 2).
    create(:mtg_printing, finishes: %w[nonfoil foil],
      entry: create(:catalog_entry, identity: entry.identity, name: entry.name, set: entry.set, number: entry.number, language: "ja"))
    page.driver.browser.manage.window.resize_to(1280, 900)
    system_sign_in_as(user)
  end

  def entry = lot.entry # a method, not a `let`: the cop counts memoized helpers

  # The two rules of the spec's block, as the browser serialises their selectors.
  def select_rule = ".c-field select, .c-select select"
  def row_rule = ".c-filterbar__filters"

  # The audit table of spec 072: every page that draws a select, by name.
  def pages
    { "card search" => catalog_entries_path,
      "collection" => collection_path(view: "grid"), # the view is a saved preference of the user: name it
      "collection in bulk mode" => collection_path(bulk: 1),
      "number entry" => collection_number_entry_path(type: "mtg", set: entry.set.code, language: "en"),
      "add a copy" => new_catalog_entry_lot_path(entry),
      "edit copy" => edit_lot_path(lot),
      "move copies" => new_lot_move_path(lot),
      "bulk move to" => new_collection_move_path,
      "scanner" => scanner_path,
      "new deck" => new_deck_path,
      "change format" => edit_deck_format_path(deck),
      "proxy chooser" => new_deck_zone_proxy_path(deck, "main", q: "Lightning"),
      "proxy form" => new_deck_zone_proxy_path(deck, "main", entry: entry.external_key),
      "currency" => edit_currency_path,
      "measurement mode" => scanner_measurement_path }
  end

  # Bulk Move to… needs a selection, which lives in the session: tick everything in bulk mode and press Move to… once.
  def select_everything
    visit collection_path(view: "grid")
    click_on "Edit many" # starts an empty selection, so calling this again is harmless
    check "Select all"
    within(".c-bulkbar__extra") { click_on "Move to…" }
    expect(page).to have_css("h1", text: /\AMove \d+ items?\z/)
  end

  # Runs the block on the page: in the window at 1280px, or in a frame `width` px wide (the frame is the document the
  # block measures and injects into, so `document` and `window` in its scripts are the frame's).
  def in_page(name, width: 1280, &block)
    path = pages.fetch(name)
    select_everything if name == "bulk move to"
    if width < 500
      visit collection_path(view: "grid")
      open_in_narrow_frame(path, width:, ready: "main")
      within_narrow_frame do
        settle(name)
        block.call
      end
    else
      visit path
      expect(page).to have_css("main")
      settle(name)
      yield
    end
  end

  # The scanner's stage is unhidden by script some time after `main` exists (the fake camera) and is about 416px tall, so
  # a measure taken either side of it differs: wait for it on the two scanner pages.
  def settle(name)
    expect(page).to have_css(".c-scanner__stage:not([hidden])", wait: 10) if [ "scanner", "measurement mode" ].include?(name)
  end

  # Every drawn select of the current document: its name, its height and which of the two shapes holds it.
  def selects
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("select")].map((el) => ({
        name: el.name || el.id, height: el.getBoundingClientRect().height,
        shape: el.closest(".c-field") ? "field" : (el.closest(".c-select") ? "select" : "none")
      })).filter((el) => el.height > 0)
    JS
  end

  # The filter row's select height and how far its centre is from its button's centre (AC-1.5).
  def row_alignment
    page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector(".c-filterbar__filters")
        const select = row.querySelector("select"), button = row.querySelector(".c-btn")
        const centre = (el) => { const rect = el.getBoundingClientRect(); return rect.top + rect.height / 2 }
        return { select: select.getBoundingClientRect().height, offset: Math.abs(centre(select) - centre(button)) }
      })()
    JS
  end

  # Name, label, width and height of every control that is not a select (AC-1.7), in document order.
  def other_controls
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("main :is(button, input, textarea, summary, .c-btn, .c-filter)")]
        .filter((el) => !el.closest(".c-sr") && el.type !== "hidden")
        .map((el) => {
          const rect = el.getBoundingClientRect()
          return [el.tagName, (el.textContent.trim() || el.value || el.name || el.id).slice(0, 24), Math.round(rect.width * 100) / 100, Math.round(rect.height * 100) / 100]
        })
    JS
  end

  # The coarse-pointer rules that set a min-height, as selector and value, and the resolved `--touch-floor` (AC-1.1).
  def coarse_min_heights
    page.evaluate_script(<<~JS)
      (() => {
        const found = []
        for (const sheet of document.styleSheets)
          for (const media of sheet.cssRules)
            if (media instanceof CSSMediaRule && media.conditionText.includes("pointer: coarse"))
              for (const rule of media.cssRules)
                if (rule.style?.minHeight) found.push({ selector: rule.selectorText, minHeight: rule.style.minHeight })
        return { found, floor: parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--touch-floor")) || 0 }
      })()
    JS
  end

  # Every style rule of the loaded stylesheets as its selector and whether a coarse-pointer block holds it (AC-1.6).
  def all_rules
    page.evaluate_script(<<~JS)
      (() => {
        const all = []
        const walk = (list, coarse) => {
          for (const rule of list) {
            if (rule.cssRules && rule.conditionText !== undefined) walk(rule.cssRules, coarse || rule.conditionText.includes("pointer: coarse"))
            else if (rule.selectorText) all.push({ selector: rule.selectorText, coarse })
          }
        }
        for (const sheet of document.styleSheets) walk(sheet.cssRules, false)
        return all
      })()
    JS
  end

  # The controls other than selects of a page at 360px, with the coarse rules applied (AC-1.7). The scrollbar is pinned on
  # so a taller page can't narrow the frame by 15px and change every stretched control's width, which is no layout defect.
  def other_controls_of(name, extra: "", **injection)
    controls = nil
    in_page(name, width: 360) do
      inject_coarse(extra: "html { overflow-y: scroll; } #{extra}", **injection)
      controls = other_controls
    end
    controls
  end

  it "has one coarse-pointer rule for selects, covering both shapes at the touch floor (AC-1.1)", :aggregate_failures do
    visit new_deck_path
    read = coarse_min_heights
    select_rules = read["found"].select { it["selector"].include?("select") }
    expect(select_rules).to eq([ { "selector" => select_rule, "minHeight" => "var(--touch-floor)" } ])
    expect(read["floor"]).to be >= 44
  end

  it "reaches every select of every page with the select rule alone: at least 44px (AC-1.2)", :aggregate_failures do
    pages.each_key do |name|
      in_page(name) do
        inject_coarse(only: [ select_rule ])
        found = selects
        expect(found).not_to be_empty, "#{name}: no select is drawn"
        expect(found.map { it["shape"] }).not_to include("none"), "#{name}: a select outside c-field and c-select: #{found}"
        expect(found.map { it["height"] }).to all(be >= 44), "#{name}: #{found}"
      end
    end
  end

  it "leaves a fine pointer's heights alone: 36px in a form, 28px in the filter bar (AC-1.3)", :aggregate_failures do
    pages.each_key do |name|
      in_page(name) do
        found = selects
        expect(found).not_to be_empty, "#{name}: no select is drawn"
        found.each { |one| expect(one["height"]).to be_within(0.5).of(one["shape"] == "field" ? 36 : 28), "#{name}: #{one}" }
      end
    end
  end

  it "keeps every page whole at 360px with all the coarse rules: no overflow, no wide select, no overlap (AC-1.4)", :aggregate_failures do
    pages.each_key do |name|
      in_page(name, width: 360) do
        inject_coarse(needs: [ select_rule, row_rule ])
        report = layout_report
        expect(report["overflow"]).to be <= 0, "#{name}: scrolls sideways by #{report['overflow']}px"
        expect(report["wide"]).to be_empty, "#{name}: wider than its container: #{report['wide']}"
        expect(report["overlaps"]).to be_empty, "#{name}: overlapping controls: #{report['overlaps']}"
      end
    end
  end

  # The filter bars: the collection (grid view and bulk mode), the card search and the add-a-proxy chooser.
  def filter_pages = [ "collection", "collection in bulk mode", "card search", "proxy chooser" ]

  [ 1280, 360 ].each do |width|
    it "centres the filter row's button on its select at #{width}px (AC-1.5)", :aggregate_failures do
      filter_pages.each do |name|
        in_page(name, width:) do
          inject_coarse(needs: [ select_rule, row_rule ])
          row = row_alignment
          expect(row["select"]).to be >= 44, "#{name}: #{row}"
          expect(row["offset"]).to be <= 1, "#{name}: the button's centre is #{row['offset']}px off the select's"
          expect(layout_report["overlaps"]).to be_empty, "#{name}: overlapping controls"
        end
      end
    end
  end

  # A button shorter than the select (spec 075: small buttons are 44px too, so a 30px one stands in for "a control that is not 44px").
  def short_button = ".c-filterbar__filters .c-btn { min-height:30px; height:30px; }"

  it "keeps a shorter button level with the select by the alignment rule (AC-1.5)" do
    in_page("card search") do
      inject_coarse(needs: [ select_rule, row_rule ], extra: short_button)
      expect(row_alignment["offset"]).to be <= 1
    end
  end

  it "needs the alignment rule: without it a shorter button sits off the select's centre (AC-1.5 can fail)" do
    in_page("card search") do
      inject_coarse(except: [ row_rule ], needs: [ select_rule ], extra: short_button) # the select rule must exist, or there is nothing to compare
      expect(row_alignment["offset"]).to be > 1
    end
  end

  it "changes no other control's size: all coarse rules with and without the block's two (AC-1.7)", :aggregate_failures do
    needs = [ select_rule, row_rule ]
    pages.each_key do |name|
      without = other_controls_of(name, except: needs, needs:)
      with = other_controls_of(name, needs:)
      expect(without).not_to be_empty, "#{name}: no control found"
      expect(with.size).to eq(without.size), "#{name}: #{without.size} controls without the block, #{with.size} with it"
      changed = without.zip(with).reject { |before, after| before == after }
      expect(changed).to be_empty, "#{name}: controls whose size changed: #{changed}"
    end
  end

  it "notices a rule that grows another control (AC-1.7 can fail)" do
    without = other_controls_of("card search", except: [ select_rule, row_rule ])
    with = other_controls_of("card search", extra: ".c-btn--sm { min-height: 90px; }")
    search = ->(controls) { controls.find { |control| control[1] == "Search" }.last }
    expect([ search.(without), search.(with) ]).to eq([ 44, 90 ])
  end

  it "has no select rule scoped to the deck pages and none in the filter bar's own block (AC-1.6)", :aggregate_failures do
    visit new_deck_path
    rules = all_rules
    expect(rules.map { it["selector"] }.grep(/\.c-decks .*select/)).to be_empty
    expect(rules.select { it["coarse"] }.map { it["selector"] }).not_to include(".c-select select")
  end
end
