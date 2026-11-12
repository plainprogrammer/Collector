require "rails_helper"

# Spec 075: every small control (a `.c-btn--sm`, a `.c-filter` chip, a `.c-seg` view-switch button) meets the touch floor on
# a coarse pointer, on every page that draws one. Headless Firefox has a fine pointer and can't emulate a coarse one, so the
# examples apply every `(pointer: coarse)` rule of the loaded stylesheets as one adopted sheet (`CoarsePointer`, decision 4),
# measure what is drawn, and compare states with and without the block's two rules. The pages are the spec's audit table;
# phone widths use the narrow frame, since a window can't go below 500px. Spec 072's spec is the model.
RSpec.describe "Small controls meet the touch floor on a coarse pointer", :solid_queue, type: :system do
  # Constants would leak onto Object (RSpec/LeakyConstantDeclaration), so these are one-line methods, as spec 072's are.
  # The block's two rules: the first has the selector text of `components.css`'s own 40px rule, so it is named by stylesheet too.
  def block_height = { sheet: "additions", selector: ".c-btn--sm, .c-filter, .c-seg button" }
  def block_width = ".c-btn--sm.c-btn--icon, .c-seg button" # exists only in the block
  def block_rules = [ block_height, block_width ]
  # The small controls of AC-1.2: in the page's `main`, its header and its status line.
  def small = "main .c-btn--sm, main .c-filter, main .c-seg button, .c-appbar .c-btn--sm, #status .c-btn--sm"
  # The page rules (spec 075 decision 3) that give their buttons 44px at every pointer: the rows marked `page` in the audit.
  def page_rule_scopes
    ".c-locations, .c-decks, .c-deckpage .c-section__actions, .c-numentry__list, .c-scanner__add, .c-scanner__undo, .c-scanner__sitting"
  end

  # Every drawn small control of the current document (AC-1.2's set): its name, size, whether a page rule covers it, whether it is
  # icon-only, and where it sits.
  def small_controls(selector = small)
    page.evaluate_script(<<~JS, selector, page_rule_scopes)
      (() => {
        const [selector, scopes] = arguments
        const inClosedMenu = (el) => { const d = el.closest("details:not([open])"); return !!d && !(el.tagName === "SUMMARY" && el.parentElement === d) }
        const iconOnly = (el) => el.classList.contains("c-btn--icon") || (el.matches(".c-seg button") && !!el.querySelector(".c-seg__label") && getComputedStyle(el.querySelector(".c-seg__label")).position === "absolute")
        return [...document.querySelectorAll(selector)]
          .filter((el) => !el.closest(".c-sr") && !inClosedMenu(el))
          .map((el) => { const box = el.getBoundingClientRect()
            return { name: el.className + " | " + (el.getAttribute("aria-label") || el.textContent.trim() || el.value || "").trim().replace(/\\s+/g, " ").slice(0, 40),
                     height: box.height, width: box.width, right: box.right, page: !!el.closest(scopes), icon: iconOnly(el), row: !!el.closest(".c-filterbar__filters") } })
          .filter((control) => control.height > 0 && control.width > 0)
      })()
    JS
  end

  # Whether a control matching `css` (and, with text, whose label, text or value includes it: a submit input has its text in
  # `value`) is drawn in the current document.
  def drawn?(css, text)
    page.evaluate_script(<<~JS, css, text)
      (() => {
        const [css, text] = arguments
        return [...document.querySelectorAll(css)].some((el) => {
          const d = el.closest("details:not([open])"); const hidden = !!d && !(el.tagName === "SUMMARY" && el.parentElement === d)
          const box = el.getBoundingClientRect()
          return !hidden && box.width > 0 && box.height > 0 && (!text || ((el.getAttribute("aria-label") || "") + " " + el.textContent + " " + (el.value || "")).includes(text))
        })
      })()
    JS
  end

  # The coarse-pointer rules that set a min-height or min-width, with the stylesheet that holds each, in source order.
  def coarse_rules
    page.evaluate_script(<<~JS)
      (() => {
        const found = []
        ;[...document.styleSheets].forEach((sheet, index) => {
          for (const media of sheet.cssRules)
            if (media instanceof CSSMediaRule && media.conditionText.includes("pointer: coarse"))
              for (const rule of media.cssRules)
                if (rule.style?.minHeight || rule.style?.minWidth)
                  found.push({ sheet: sheet.href || "", index, selector: rule.selectorText, minHeight: rule.style.minHeight, minWidth: rule.style.minWidth })
        })
        return { found, floor: parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--touch-floor")) || 0 }
      })()
    JS
  end

  context "with an admin's account" do
    let(:user) { create(:admin) } # an admin is a collector too, so one sign-in reaches the admin pages and the rest
    let!(:lot) { owned_printing("Lightning Bolt", account: user.account, location: create(:location, account: user.account, name: "Blue binder"), number: "138", quantity: 2) }
    let(:corpus) { Pathname(Dir.mktmpdir("corpus")) }

    # Measurement mode (development only) draws its Skip button only with a manifest and a run directory.
    around do |example|
      corpus.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,mom,123,no\n")
      Rails.configuration.x.scanner_measurement = { manifest: corpus.join("manifest.csv").to_s, dir: corpus.join("runs/live").to_s }
      example.run
    ensure
      Rails.configuration.x.scanner_measurement = nil
      FileUtils.remove_entry(corpus)
    end

    before do
      # Two of everything that pages, so a second page and a "Show all" exist without 120 rows (the constants are read at call time).
      stub_const("Catalog::Search::PER_PAGE", 1)
      stub_const("Catalog::Search::ENTRIES_PER_GROUP", 1)
      stub_const("Catalog::IdentitiesController::PER_PAGE", 1)
      stub_const("CollectionGrid::PER_PAGE", 1)
      stub_const("CollectionTable::PER_PAGE", 1)
      stub_const("NumberEntry::SHOWN", 1)
      stub_const("Scanner::Sitting::SHOWN", 1)
      stub_const("BackgroundJobs::List::PER_PAGE", 1)
      make_fixtures
      page.driver.browser.manage.window.resize_to(1280, 900)
      system_sign_in_as(user)
    end

    # A second printing of the name in another set and a second owned lot (so the card search, the printings page, the
    # collection and bulk mode have a second page and a "Show all"), a deck with a proxy, a second language of the printing for
    # number entry, two number-entry lines and two scanner sitting entries (more than SHOWN = 1), a second user, a failed and a
    # scheduled job.
    def make_fixtures
      account = user.account
      create(:mtg_printing, finishes: %w[nonfoil foil],
        entry: create(:catalog_entry, identity: entry.identity, name: entry.name, set: create(:catalog_set), number: "139"))
      create(:mtg_printing, finishes: %w[nonfoil foil],
        entry: create(:catalog_entry, identity: entry.identity, name: entry.name, set: entry.set, number: entry.number, language: "ja"))
      owned_printing("Opt", account:, number: "1", quantity: 1)
      owned_printing("Lightning Helix", account:, number: "2", quantity: 1) # a second name that "Lightning" matches, so the card search has a second page
      create(:deck_proxy, zone: create(:deck, account:, name: "Izzet Tempo").zone("main"), entry: second_printing)
      2.times { |i| NumberEntry.add!(account:, entry: i.zero? ? entry : second_printing, quantity: 1, finish: "nonfoil", line_key: SecureRandom.hex(16)) }
      [ entry, second_printing ].each { |printing| Scanner::Sitting.add!(account:, printing:, finish: "nonfoil", reading_key: SecureRandom.hex(16)) }
      create(:user)
      fail_job(queue_job(MTG::Art::BuildJob))
      queue_job(MTG::Art::BuildJob, wait: 1.hour)
    end

    def entry = lot.entry # methods, not `let`s: the cop counts memoized helpers
    def second_printing = Catalog::Entry.find_by!(identity: entry.identity, number: "139")
    def deck = user.account.locations.find_by!(kind: "deck") # a Location; `Deck#to_param` is its id, so the paths work
    def zone_key = "main"

    # The audit table of spec 075: page name → its route, and the small controls the table lists for it at each width, as
    # [css, text] (text nil = any). Row numbers are the spec's.
    def pages
      { "card search" => { path: catalog_entries_path(q: "Lightning"), # row 2
          wide: [ [ ".c-filterbar__filters .c-btn--sm", "Search" ], [ ".c-section__actions .c-btn--sm", "Show all" ], [ ".c-pager .c-btn--sm", "Next" ],
                  [ ".c-grid .c-btn--sm", nil ] ] }, # the tile's quick add
        "card page" => { path: catalog_entry_path(entry), # row 3
          wide: [ [ "summary.c-btn--sm.c-btn--icon", nil ], [ ".c-section__actions .c-btn--sm", "Show all" ], [ "#printings .c-list__end .c-btn--sm", nil ] ] }, # the last: the quick add of an unowned printing
        "printings page" => { path: catalog_identity_path(entry.identity, set: entry.set.code), # row 4
          wide: [ [ ".c-btn--sm", "Show all sets" ], [ ".c-grid .c-btn--sm", nil ], [ ".c-pager .c-btn--sm", "Next" ] ] },
        "collection grid" => { path: collection_path(view: "grid"), # row 5
          wide: [ [ ".c-filterbar__filters .c-btn--sm", "Filter" ], [ ".c-filterbar__bulk", "Edit many" ], [ ".c-seg button", nil ], [ ".c-pager .c-btn--sm", "Next" ] ],
          narrow: [ [ ".c-filterbar__more summary", nil ], [ ".c-seg button", nil ], [ ".c-appbar .c-appbar__add", nil ] ] },
        "collection table" => { path: collection_path(view: "table"), # row 6
          wide: [ [ ".c-table summary.c-btn--sm.c-btn--icon", nil ], [ ".c-seg button", nil ], [ ".c-pager .c-btn--sm", "Next" ] ] },
        "bulk mode" => { path: collection_path(bulk: 1), # row 7
          wide: [ [ ".c-bulkbar__extra .c-btn--sm", "Set condition" ], [ ".c-bulkbar__extra .c-btn--sm", "Move to" ], [ ".c-bulkbar__extra .c-btn--sm", "Remove" ],
                  [ ".c-bulkbar .c-btn--sm", "Done" ], [ ".c-filterbar__filters .c-btn--sm", "Filter" ], [ ".c-seg button", nil ], [ ".c-pager .c-btn--sm", "Next" ] ],
          narrow: [ [ ".c-bulkbar__more summary", nil ], [ ".c-bulkbar .c-btn--sm", "Done" ] ] },
        "number entry" => { path: collection_number_entry_path(type: "mtg", set: entry.set.code, language: "en"), # rows 8, 8b
          wide: [ [ ".c-numentry__language .c-btn--sm", "Change language" ], [ ".c-btn--sm", "Change set" ], [ ".c-numentry__list .c-btn--sm", "Done" ],
                  [ ".c-numentry__list .c-btn--sm", "Undo" ], [ ".c-numentry__list summary.c-btn--sm", "Show all" ] ] },
        "decks" => { path: decks_path, wide: [ [ ".c-decks__actions .c-btn--sm", "Rename" ], [ ".c-decks__actions .c-btn--sm", "Change format" ], [ ".c-decks__actions .c-btn--sm", "Remove" ] ] }, # row 9
        "deck page" => { path: deck_path(deck), # rows 9, 9b
          wide: [ [ ".c-zone .c-section__actions .c-btn--sm", "Add a proxy" ], [ ".c-zone summary.c-btn--sm.c-btn--icon", nil ] ] },
        "proxy chooser" => { path: new_deck_zone_proxy_path(deck, zone_key, q: "Lightning"), # row 10
          wide: [ [ ".c-filterbar__filters .c-btn--sm", "Search" ], [ ".c-btn--sm", "Choose" ] ] },
        "locations" => { path: locations_path, wide: [ [ ".c-btn--sm", "Rename" ], [ ".c-btn--sm", "Remove" ] ] }, # row 11
        "admin jobs" => { path: admin_jobs_path(status: "failed"), # row 12
          wide: [ [ ".c-filter", "Failed" ], [ ".c-filter", "Running" ], [ ".c-filter", "Queued" ], [ ".c-filter", "Scheduled" ], [ "summary.c-btn--sm.c-btn--icon", nil ] ] },
        "admin users" => { path: admin_users_path, wide: [ [ "summary.c-btn--sm.c-btn--icon", nil ] ] }, # row 13
        "scanner" => { path: scanner_path, # row 14 (the sitting)
          wide: [ [ "#scanner_sitting .c-btn--sm", "Done" ], [ "#scanner_sitting .c-btn--sm", "Undo" ], [ "#scanner_sitting .c-btn--sm", "Details" ],
                  [ "#scanner_sitting summary.c-btn--sm", "Show all" ], [ "#scanner_sitting .c-btn--sm", "Set" ] ] },
        "measurement mode" => { path: scanner_measurement_path, wide: [ [ ".c-btn--sm", "Skip" ] ] } } # row 15
    end

    # Runs the block on the page: in the window at 1280px, or in a frame `width` px wide (the frame is the document the block
    # measures and injects into, so `document` and `window` in its scripts are the frame's).
    def in_page(name, width: 1280, &block)
      definition = pages.fetch(name)
      if width < 500
        visit collection_path(view: "grid")
        open_in_narrow_frame(definition.fetch(:path), width:, ready: "main")
        within_narrow_frame do
          settle(name)
          block.call
        end
      else
        visit definition.fetch(:path)
        expect(page).to have_css("main")
        settle(name)
        yield
      end
    end

    # The scanner's stage is unhidden by script some time after `main` exists (the fake camera); wait for it on the two scanner pages.
    def settle(name)
      expect(page).to have_css(".c-scanner__stage:not([hidden])", wait: 10) if [ "scanner", "measurement mode" ].include?(name)
    end

    # What the page expects to draw at this width: the `narrow` list when the table gives one (the pages whose controls differ below
    # 640px: the collection pages, the app bar), else the `wide` list.
    def expected_at(definition, width)
      return definition.fetch(:wide, []) if width >= 500

      definition.fetch(:narrow) { definition.fetch(:wide, []) }
    end

    it "gives the small controls a coarse-pointer rule of their own that wins by source order (AC-1.1)", :aggregate_failures do
      visit new_deck_path
      read = coarse_rules
      height_rules = read["found"].select { it["selector"] == block_height[:selector] }
      width_rules = read["found"].select { it["selector"] == block_width }
      expect(height_rules.size).to eq(2), "components.css's 40px rule and the block's: #{height_rules}"
      expect(height_rules.last).to include("minHeight" => "var(--touch-floor)")
      expect(height_rules.last["sheet"]).to include("additions")
      expect(height_rules.last["index"]).to be > height_rules.first["index"]
      expect(width_rules.last).to include("minWidth" => "var(--touch-floor)")
      expect(read["floor"]).to be >= 44
    end

    [ 1280, 360 ].each do |width|
      it "draws every small control at least 44px high, the icon-only ones 44px wide, at #{width}px (AC-1.2)", :aggregate_failures do
        pages.each do |name, definition|
          in_page(name, width:) do
            inject_coarse(needs: block_rules)
            expected_at(definition, width).each { |css, text| expect(drawn?(css, text)).to be(true), "#{name}: no #{css} #{text} is drawn" }
            found = small_controls
            expect(found).not_to be_empty, "#{name}: no small control is drawn"
            expect(found.select { it["height"] < 44 }.map { it["name"] }).to be_empty, "#{name}: under 44px high"
            expect(found.select { it["icon"] && it["width"] < 44 }.map { it["name"] }).to be_empty, "#{name}: icon-only under 44px wide"
          end
        end
      end
    end

    [ 1280, 360 ].each do |width|
      it "leaves a fine pointer's compact size where no page rule applies, at #{width}px (AC-1.3)", :aggregate_failures do
        compact = 0
        pages.each_key do |name|
          in_page(name, width:) do
            # the expected controls are drawn at a fine pointer too (this runs before the CSS exists, so a wrong selector or fixture shows here)
            expected_at(pages.fetch(name), width).each { |css, text| expect(drawn?(css, text)).to be(true), "#{name}: no #{css} #{text} is drawn" }
            found = small_controls.reject { it["page"] }
            compact += found.size
            expect(found.select { it["height"] >= 36 }.map { it["name"] }).to be_empty, "#{name}: a small control with no page rule is 36px or more with a fine pointer"
          end
        end
        expect(compact).to be > 10 # at least some pages had controls to measure
      end
    end
  end
end
