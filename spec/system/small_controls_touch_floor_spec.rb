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
    ".c-locations, .c-decks, .c-deckpage .c-section__actions, .c-numentry__list, .c-scanner__add, .c-scanner__undo, .c-scanner__sitting, .c-scan .c-sheet"
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

  # The rows whose line counts AC-1.5 compares.
  def rows = ".c-filterbar, .c-bulkbar, .c-pager, .c-section__head, .c-decks__actions, .c-numentry__language, .c-jobs__filters, .c-appbar"

  # Counts the lines of every row of `rows` on the current page: a line is a cluster of the row's drawn controls whose vertical
  # extents overlap, so controls of different heights centred on one line are one line. Returns the `[selector#index, lines]`
  # pairs and the height of the first `.c-filterbar`.
  def row_lines
    page.evaluate_script(<<~JS, rows, small)
      (() => {
        const [rows, small] = arguments
        const wanted = "button, input:not([type=hidden]), select, summary, a[href], .c-btn, .c-filter, " + small
        const drawn = (el) => { const d = el.closest("details:not([open])"); const box = el.getBoundingClientRect()
          return box.width > 0 && box.height > 0 && !el.closest(".c-sr") && !(d && !(el.tagName === "SUMMARY" && el.parentElement === d)) }
        const lines = [...document.querySelectorAll(rows)].map((row, index) => {
          const boxes = [...row.querySelectorAll(wanted)].filter(drawn).map((el) => el.getBoundingClientRect()).sort((a, b) => a.top - b.top)
          let count = 0, bottom = -Infinity
          for (const box of boxes) { if (box.top >= bottom - 1) { count += 1; bottom = box.bottom } else { bottom = Math.max(bottom, box.bottom) } }
          return [row.className.split(" ")[0] + "#" + index, count]
        })
        const bar = document.querySelector(".c-filterbar")
        return { lines, bar: bar ? bar.getBoundingClientRect().height : null }
      })()
    JS
  end

  # The filter row's select and button heights, and how far apart their vertical centres are (AC-1.6).
  def row_alignment
    page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector(".c-filterbar__filters")
        const select = row.querySelector("select"), button = row.querySelector(".c-btn")
        const centre = (el) => { const rect = el.getBoundingClientRect(); return rect.top + rect.height / 2 }
        return { select: select.getBoundingClientRect().height, button: button.getBoundingClientRect().height, offset: Math.abs(centre(select) - centre(button)) }
      })()
    JS
  end

  # Name, label, width and height of every control that is not a small control (AC-1.7), in document order: the page's `main` and
  # its header (the printings page has no control in `main` that is not small, and the check must still compare something there).
  def other_controls
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(":is(main, .c-appbar) :is(button, input, textarea, select, summary, .c-btn)")]
        .filter((el) => !el.closest(".c-sr") && el.type !== "hidden" && !el.matches(".c-btn--sm, .c-filter, .c-seg button"))
        .map((el) => {
          const box = el.getBoundingClientRect()
          return [el.tagName, (el.textContent.trim() || el.value || el.name || el.id).slice(0, 24), Math.round(box.width * 100) / 100, Math.round(box.height * 100) / 100]
        })
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
      2.times { fail_job(queue_job(MTG::Art::BuildJob)) } # two failed, so the failed list has a second page
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
          narrow: [ [ ".c-filterbar__filters .c-btn--sm", "Filter" ], [ ".c-filterbar__more summary", nil ], [ ".c-seg button", nil ],
                    [ ".c-pager .c-btn--sm", "Next" ], [ ".c-appbar .c-appbar__add", nil ] ] },
        "collection table" => { path: collection_path(view: "table"), # row 6
          wide: [ [ ".c-table summary.c-btn--sm.c-btn--icon", nil ], [ ".c-seg button", nil ], [ ".c-pager .c-btn--sm", "Next" ] ] },
        "bulk mode" => { path: collection_path(bulk: 1), # row 7
          wide: [ [ ".c-bulkbar__extra .c-btn--sm", "Set condition" ], [ ".c-bulkbar__extra .c-btn--sm", "Move to" ], [ ".c-bulkbar__extra .c-btn--sm", "Remove" ],
                  [ ".c-bulkbar .c-btn--sm", "Done" ], [ ".c-filterbar__filters .c-btn--sm", "Filter" ], [ ".c-seg button", nil ], [ ".c-pager .c-btn--sm", "Next" ] ],
          narrow: [ [ ".c-bulkbar__more summary", nil ], [ ".c-bulkbar .c-btn--sm", "Done" ], [ ".c-filterbar__filters .c-btn--sm", "Filter" ],
                    [ ".c-seg button", nil ], [ ".c-pager .c-btn--sm", "Next" ] ] },
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
        "scanner" => { path: scanner_path, # row 14 (the sitting's sheets; Done is the top bar's 44px button, not a small control)
          wide: [ [ "#scanner_sitting .c-btn--sm", "Undo" ], [ "#scanner_sitting .c-btn--sm", "Details" ],
                  [ "#scanner_sitting summary.c-btn--sm", "Show all" ], [ "#scanner_picker .c-btn--sm", "Set" ] ] },
        "measurement mode" => { path: scanner_measurement_path, wide: [ [ ".c-btn--sm", "Skip" ] ] } } # row 15
    end

    # Runs the block on the page: in the window at 1280px, or in a frame `width` px wide (the frame is the document the block
    # measures and injects into, so `document` and `window` in its scripts are the frame's).
    def in_page(name, width: 1280, path: nil, &block)
      path ||= pages.fetch(name).fetch(:path)
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

    # The scanner's feed is unhidden by script some time after `main` exists (the fake camera); wait for it on the two scanner pages,
    # then draw the sheets without a modal so their controls have a size (this spec measures sizes, not overlap; spec 082 AC-1.9).
    def settle(name)
      return unless [ "scanner", "measurement mode" ].include?(name)

      expect(page).to have_css(".c-scan__feed:not([hidden])", wait: 10)
      page.execute_script("document.querySelectorAll('dialog.c-sheet').forEach((sheet) => sheet.show())")
    end

    # `settle` shows every sheet at once so their controls have a size; two open sheets overlap each other, which no collector
    # sees, so an overlap check keeps the first and closes the rest.
    # AC-1.4's layout reports: the page's own controls, and on the scanner pages each sheet on its own, measured after its 200ms
    # rise has finished. CI's 360px run flagged the sheet's Close over the main button: measured mid-rise (a probe at 360 x 800:
    # Close starts at y 809 and rests at 294 for the destination sheet, 460 for the list; the main button is at 721-785), so the
    # head crossed the bar while sliding. At rest no sheet control overlaps the bar, and a collector's sheet is modal, which leaves
    # the bar under it covered and inert (spec 082 decision 9), so a sheet is measured against itself, not the bars beneath.
    def layout_reports
      page_roots = [ "main", ".c-appbar", "#status" ]
      sheets = page.evaluate_script("Array.from(document.querySelectorAll('dialog.c-sheet')).map((sheet) => sheet.id)")
      page.execute_script("document.querySelectorAll('dialog.c-sheet[open]').forEach((sheet) => sheet.close())")
      [ layout_report(roots: page_roots) ] + sheets.map do |id|
        page.execute_script("document.querySelectorAll('dialog.c-sheet[open]').forEach((sheet) => sheet.close()); document.getElementById(arguments[0]).show(); document.getAnimations().forEach((motion) => motion.finish())", id)
        layout_report(roots: [ "##{id}" ])
      end
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

    # The pages whose pager draws Previous: the second page of each (every route above is page 1, which has no Previous). The admin
    # jobs' failed list has two jobs (make_fixtures) and the printings page two entries in the set (English and Japanese).
    def second_pages
      { "card search" => catalog_entries_path(q: "Lightning", page: 2), # row 2
        "printings page" => catalog_identity_path(entry.identity, set: entry.set.code, page: 2), # row 4
        "admin jobs" => admin_jobs_path(status: "failed", page: 2) } # row 12
    end

    [ 1280, 360 ].each do |width|
      it "draws the pagers' Previous at 44px on a second page at #{width}px (AC-1.2, rows 2, 4 and 12)", :aggregate_failures do
        second_pages.each do |name, path|
          in_page(name, width:, path:) do
            inject_coarse(needs: block_rules)
            expect(drawn?(".c-pager .c-btn--sm", "Previous")).to be(true), "#{name}: no Previous is drawn on page 2"
            expect(small_controls.select { it["height"] < 44 }.map { it["name"] }).to be_empty, "#{name}: under 44px high"
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

    it "keeps every page whole at 360px with all the coarse rules: no overflow, no overlap, nothing past the edge (AC-1.4)", :aggregate_failures do
      pages.each_key do |name|
        in_page(name, width: 360) do
          inject_coarse(needs: block_rules)
          layout_reports.each do |report|
            expect(report["overflow"]).to be <= 0, "#{name}: scrolls sideways by #{report['overflow']}px"
            expect(report["overlaps"]).to be_empty, "#{name}: overlapping controls: #{report['overlaps']}"
          end
          edge = page.evaluate_script("document.documentElement.clientWidth")
          past = small_controls.reject { it["row"] }.select { it["right"] > edge + 1 }.map { it["name"] }
          expect(past).to be_empty, "#{name}: past the right edge: #{past}"
        end
      end
    end

    # The filter bars: the collection (grid view and bulk mode), the card search and the add-a-proxy chooser.
    def filter_pages = [ "collection grid", "bulk mode", "card search", "proxy chooser" ]

    [ 1280, 360 ].each do |width|
      it "levels the filter row's small button with its select, both at least 44px, at #{width}px (AC-1.6)", :aggregate_failures do
        filter_pages.each do |name|
          in_page(name, width:) do
            inject_coarse(needs: block_rules)
            row = row_alignment
            expect([ row["select"], row["button"] ]).to all(be >= 44), "#{name}: #{row}"
            expect(row["offset"]).to be <= 1, "#{name}: the button's centre is #{row['offset']}px off the select's"
          end
        end
      end
    end

    # The line counts (and the first filter bar's height) of every page at a width, with every coarse rule applied except `except`
    # and with `extra` CSS. The scrollbar is pinned on so a taller page can't narrow the frame by 15px (which is no layout defect).
    def rows_of(width, except: [], extra: "")
      pages.keys.to_h do |name|
        report = nil
        in_page(name, width:) do
          inject_coarse(except:, extra: "html { overflow-y: scroll; } #{extra}", needs: block_rules)
          report = row_lines
        end
        [ name, report ]
      end
    end

    [ 1280, 360 ].each do |width|
      it "adds no line to any row of controls at #{width}px (AC-1.5)", :aggregate_failures do
        without = rows_of(width, except: block_rules)
        with = rows_of(width)
        pages.each_key do |name|
          expect(with.fetch(name)["lines"]).to eq(without.fetch(name)["lines"]), "#{name}: lines per row changed"
        end
        next unless width == 360

        expect(with.fetch("collection grid")["bar"] - without.fetch("collection grid")["bar"]).to be <= 8
      end
    end

    def other_controls_of(name, except: [], extra: "")
      controls = nil
      in_page(name, width: 360) do
        inject_coarse(except:, extra: "html { overflow-y: scroll; } #{extra}", needs: block_rules)
        controls = other_controls
      end
      controls
    end

    it "changes no other control's size: all coarse rules with and without the block's two (AC-1.7)", :aggregate_failures do
      pages.each_key do |name|
        without = other_controls_of(name, except: block_rules)
        with = other_controls_of(name)
        expect(without).not_to be_empty, "#{name}: no control found"
        expect(with.size).to eq(without.size), "#{name}: #{without.size} controls without the block, #{with.size} with it"
        changed = without.zip(with).reject { |before, after| before == after }
        expect(changed).to be_empty, "#{name}: controls whose size changed: #{changed}"
      end
    end

    # Number entry's Add button is a `c-btn` that is not small (card search has none: its Search, Show all, quick add and pager are all
    # small, so the variant could not change anything there and the example would be green for the wrong reason).
    it "notices a rule that grows another control (AC-1.7 can fail)", :aggregate_failures do
      without = other_controls_of("number entry", except: block_rules)
      with = other_controls_of("number entry", extra: ".c-input, .c-btn:not(.c-btn--sm) { min-height: 90px; }")
      expect(with).not_to eq(without)
      expect(without.map { it[3] }.max).to be < 90
    end

    it "notices a row that gains a line (AC-1.5 can fail)", :aggregate_failures do
      [ "bulk mode", "number entry" ].each do |name|
        in_page(name, width: 360) do
          inject_coarse(except: block_rules, extra: "html { overflow-y: scroll; }", needs: block_rules)
          before = row_lines["lines"]
          inject_coarse(extra: ".c-btn--sm { min-width: 300px; }", needs: block_rules) # a second adopted sheet on top of the first
          after = row_lines["lines"]
          expect(after.sum { |_, lines| lines }).to be > before.sum { |_, lines| lines }, "#{name}: no row gained a line"
        end
      end
    end

    # The sizes of the one-screen scanner's own controls, drawn at a fine pointer (nothing injected) with both sheets shown.
    def scanner_control_sizes
      page.evaluate_script(<<~JS)
        [...document.querySelectorAll(".c-scan__back, .c-scan__dest, .c-scan__done, #scanner_count, .c-scan__main, .c-scan__torch, dialog .c-btn")]
          .map((el) => { const box = el.getBoundingClientRect()
            return { name: el.className + " | " + (el.getAttribute("aria-label") || el.textContent.trim()).slice(0, 30), height: box.height, width: box.width } })
          .filter((control) => control.height > 0 && control.width > 0)
      JS
    end

    # Spec 082 AC-1.9, read with spec 072's exception: the sheets' selects are 36px at a fine pointer and are not in the list.
    it "the one-screen scanner's controls are 44px at every pointer (spec 082 AC-1.9)", :aggregate_failures do
      in_page("scanner") do
        sizes = scanner_control_sizes
        expect(sizes.size).to be >= 6
        expect(sizes.select { it["height"] < 44 || it["width"] < 44 }.map { it["name"] }).to be_empty
      end
    end

    # The controls the page draws only in some states (the failure block's Send again and Sign in, the after-add line's link and
    # Undo, a stage notice's button) are drawn for the measure by script, with the classes the views give them.
    def draw_state_dependent_buttons
      # The shell hides the after-add line while its sentence is empty, so a summary is written first and the wait is for it to show.
      page.execute_script(<<~JS)
        document.querySelector("#scanner_added_text").textContent = "Added Lightning Bolt."
        document.querySelector(".c-scan__added-action").innerHTML = '<a class="c-btn c-btn--ghost" href="#">Open your collection</a><form class="c-scan__undo"><button class="c-btn c-btn--ghost">Undo</button></form>'
      JS
      expect(page).to have_css(".c-scan__line--added:not([hidden])")
      expect(page).to have_css("[data-scan-main]:not([disabled])", wait: 30) # the engine has loaded: it no longer hides its failure notice
      page.execute_script(<<~JS)
        document.querySelectorAll(".c-scanner__failure, .c-scanner__failure [hidden], .c-scan__notice, .c-scan__notice [hidden]").forEach((el) => el.hidden = false)
        document.querySelector(".c-scan__notice").insertAdjacentHTML("beforeend", '<button type="button" class="c-btn c-btn--secondary">Try again</button>')
      JS
      page.evaluate_script(<<~JS)
        [...document.querySelectorAll(".c-scan__added-action .c-btn, .c-scanner__failure .c-btn, .c-scan__notice .c-btn")]
          .map((el) => { const box = el.getBoundingClientRect()
            return { name: el.textContent.trim(), height: box.height, width: box.width } })
      JS
    end

    it "the scanner's state-dependent buttons are 44px too (spec 082 AC-1.9)", :aggregate_failures do
      in_page("scanner") do
        sizes = draw_state_dependent_buttons
        expect(sizes.map { it["name"] }).to include("Open your collection", "Undo", "Send again", "Sign in", "Try again")
        expect(sizes.select { it["height"] < 44 || it["width"] < 44 }.map { it["name"] }).to be_empty
      end
    end

    it "has a control under 44px without the block: the floor is the block's doing (AC-1.2 can fail)" do
      in_page("collection grid") do
        inject_coarse(except: block_rules, needs: block_rules)
        expect(small_controls.reject { it["page"] }.map { it["height"] }.min).to be < 44
      end
    end

    # Removes every lot in bulk mode (the "…" menu holds Remove below 640px), confirms, and returns the status line's Undo heights.
    def remove_all_and_measure_undo(narrow)
      check "Select all"
      if narrow
        find(".c-bulkbar__more summary").click
        within(".c-bulkbar__more") { click_on "Remove" }
      else
        within(".c-bulkbar__extra") { click_on "Remove" }
      end
      find(:button, text: /\ARemove \d+ items?\z/).click
      expect(page).to have_css("#status .c-btn--sm", text: "Undo")
      inject_coarse(needs: block_rules)
      heights = small_controls.select { it["name"].include?("Undo") }.map { it["height"] }
      click_on "Undo" # puts the lots back for the next width, inside the frame at 360px
      expect(page).to have_css("#status", text: /Restored/)
      heights
    end

    it "draws the status message's Undo at 44px after a bulk removal (AC-1.2, row 16)", :aggregate_failures do
      [ 1280, 360 ].each do |width|
        heights = nil
        if width < 500
          visit collection_path(view: "grid")
          open_in_narrow_frame(collection_path(bulk: 1), width:, ready: "main")
          within_narrow_frame { heights = remove_all_and_measure_undo(true) }
        else
          visit collection_path(bulk: 1)
          heights = remove_all_and_measure_undo(false)
        end
        expect(heights.size).to eq(1), "exactly one Undo is drawn at #{width}px"
        expect(heights).to all(be >= 44)
      end
    end
  end

  context "without the admin's fixtures" do
    before { page.driver.browser.manage.window.resize_to(1280, 900) }

    # Row 1: a visitor's "Sign in" on an open catalog.
    def sign_in_height_with_coarse_rules
      inject_coarse(needs: [ block_height ])
      page.evaluate_script("document.querySelector('.c-appbar a.c-btn--sm').getBoundingClientRect().height")
    end

    [ 1280, 360 ].each do |width|
      it "draws a visitor's Sign in at 44px on an open catalog at #{width}px (AC-1.2, row 1)", :public_catalog do
        create(:user) # with no account yet every visit goes to the first-run page
        visit catalog_entries_path
        height = nil
        if width < 500
          open_in_narrow_frame(catalog_entries_path, width:, ready: "main")
          within_narrow_frame { height = sign_in_height_with_coarse_rules }
        else
          height = sign_in_height_with_coarse_rules
        end
        expect(height).to be >= 44
      end
    end

    # Row 14b: a candidate's Add buttons and "Other printings" link, then the printings frame's "Show N more" (setup as
    # scanner_adding_spec.rb, plus a second English printing of the card so the frame has one more than SHOWN = 1).
    def read_a_card
      stub_const("Scanner::OtherPrintings::SHOWN", 1)
      identity = create(:catalog_identity, name: "Lightning Bolt")
      mom = create(:catalog_set, code: "mom", name: "March of the Machine")
      create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
      create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set), number: "9"))
      Catalog::NameIndex.new("mtg").rebuild
      system_sign_in_as(create(:user))
    end

    def candidate_heights
      show_synthetic_card
      click_on "Capture"
      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      click_on "Other printings"
      expect(page).to have_css("#scanner_printings summary.c-btn--sm", text: "Show 1 more")
      inject_coarse(needs: block_rules)
      small_controls(".c-scanner__candidate .c-btn--sm, #scanner_printings .c-btn--sm").map { it["height"] }
    end

    it "draws a candidate's Other printings and Add buttons at 44px at 1280px (AC-1.2, row 14b)", :aggregate_failures do
      read_a_card
      visit scanner_path
      heights = candidate_heights
      expect(heights.size).to be >= 6 # Nonfoil, Foil, Other printings; the frame's Nonfoil, Foil and "Show 1 more"
      expect(heights).to all(be >= 44)
    end

    it "draws a candidate's Other printings and Add buttons at 44px at 360px (AC-1.2, row 14b)", :aggregate_failures do
      read_a_card
      visit collection_path(view: "grid")
      open_in_narrow_frame(scanner_path, width: 360, ready: "main")
      heights = nil
      within_narrow_frame { heights = candidate_heights }
      expect(heights.size).to be >= 6
      expect(heights).to all(be >= 44)
    end
  end
end
