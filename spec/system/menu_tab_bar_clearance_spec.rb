require "rails_helper"

# Spec 074 (#326): an opened menu is scrolled clear of the phone's tab bar, and nothing moves where it was already clear or no
# bar is drawn. Phone widths use the narrow frame, sized from the measured scrollbar so the viewport is 360px (a phone has no
# classic scrollbar; the lesson of spec 069), no taller than the window's viewport (a taller frame is clipped and loses the
# fixed tab bar: spec 074 Decision 4). Layout rounds to a quarter pixel and a scroll may land on a fraction, so edges are
# compared with a half pixel of tolerance where an AC says "at least 8px" or "within 1px".
RSpec.describe "Menus and the phone's tab bar", type: :system do
  # Runs +body+ in the narrow frame (`d` is its document, `w` its window) and returns what it returns.
  def frame_js(body)
    page.evaluate_script("(() => { const f = document.getElementById('narrow'), d = f.contentDocument, w = f.contentWindow; #{body} })()")
  end

  def frame_run(body) = frame_js("#{body}; return null")

  # A frame that is a 360px viewport: 375px wide first, then 360px plus the scrollbar the page showed.
  def open_phone(path, ready:, height: 640)
    open_in_narrow_frame(path, width: 375, ready:, height:)
    scrollbar = frame_js("return w.innerWidth - d.documentElement.clientWidth")
    page.execute_script("document.getElementById('narrow').style.width = '#{360 + scrollbar}px'")
    expect(frame_js("return d.documentElement.clientWidth")).to eq(360)
  end

  def row_menu(name) = "summary[aria-label^='Actions for #{name}']"

  # The edge a menu must stay clear of: the tab bar's top, or the frame's bottom where no bar is drawn.
  def limit_top
    frame_js(<<~JS)
      const bar = d.querySelector(".c-shell > .c-tabbar")
      return bar && w.getComputedStyle(bar).display !== "none" ? bar.getBoundingClientRect().top : w.innerHeight
    JS
  end

  def trigger_box(css, index = 0)
    frame_js("const b = d.querySelectorAll(#{css.to_json})[#{index}].getBoundingClientRect(); return { top: b.top, bottom: b.bottom }")
  end

  # Scrolls so the trigger's bottom edge is +gap+ above the limit, or its top edge is +from_top+ below the viewport's top, and
  # checks that the page could do it (it can't scroll above its top, so a trigger too high up fails here, not later).
  def place_trigger(css, index = 0, gap: nil, from_top: nil)
    wanted = from_top ? from_top : limit_top - gap
    delta = from_top ? trigger_box(css, index)["top"] - wanted : trigger_box(css, index)["bottom"] - wanted
    frame_run("w.scrollBy(0, #{delta})")
    box = trigger_box(css, index)
    expect(from_top ? box["top"] : box["bottom"]).to be_within(1).of(wanted), "the page can't scroll the trigger there"
  end

  def open_menu(css, index = 0) = frame_run("d.querySelectorAll(#{css.to_json})[#{index}].click()")

  def open_menus = frame_js("return d.querySelectorAll('details.c-menu[open]').length")

  # Waits, without sleeping in Ruby, until the frame's scroll position has held for 300ms (a smooth scroll takes a moment
  # and `toggle` fires a task after the click).
  def settle
    page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      const w = document.getElementById("narrow").contentWindow
      let last = null, same = 0
      const tick = () => { if (w.scrollY === last) same += 1; else { same = 0; last = w.scrollY }
        same >= 6 ? done(w.scrollY) : setTimeout(tick, 50) }
      tick()
    JS
  end

  # The open menu's boxes, the bars', the scroll position, the ancestors of the list that scroll, and whether the page fits.
  def menu_state
    frame_js(<<~JS)
      const rect = (el) => { const b = el.getBoundingClientRect(); return { top: b.top, bottom: b.bottom, left: b.left, height: b.height } }
      const list = d.querySelector("details.c-menu[open] .c-menu__list")
      const scrolling = []
      for (let n = list.parentElement; n && n !== d.body; n = n.parentElement) {
        const s = w.getComputedStyle(n)
        if (s.overflowX !== "visible" || s.overflowY !== "visible") scrolling.push(n.className || n.tagName)
      }
      return { list: rect(list), items: [...list.querySelectorAll(".c-menu__item")].map(rect), bar: rect(d.querySelector(".c-shell > .c-tabbar")),
               appbar: rect(d.querySelector(".c-appbar")), scrollY: w.scrollY, scrolling: scrolling, innerHeight: w.innerHeight,
               fits: d.documentElement.scrollWidth <= d.documentElement.clientWidth }
    JS
  end

  def scroll_y = frame_js("return w.scrollY")
  def page_height = frame_js("return d.documentElement.scrollHeight")

  # What AC-1.1, 1.3, 1.8 say: every item ends at least 8px above the tab bar's top edge.
  def expect_clear_of_bar(state)
    gap = state["bar"]["top"] - state["items"].pluck("bottom").max
    expect(gap).to be >= 7.5, "the last item ends #{gap}px above the tab bar (wanted 8px, less half a pixel of rounding)"
  end

  # The computed clearances of the open list: its scroll margins and the room box's height and content.
  def clearance_styles
    frame_js(<<~JS)
      const list = d.querySelector("details.c-menu[open] .c-menu__list"), style = w.getComputedStyle(list), after = w.getComputedStyle(list, "::after")
      const bar = d.querySelector(".c-shell > .c-tabbar"), appbar = d.querySelector(".c-appbar")
      return { top: style.scrollMarginTop, bottom: style.scrollMarginBottom, afterHeight: after.height, afterContent: after.content,
               bar: bar ? bar.getBoundingClientRect().height : 0, appbar: appbar.getBoundingClientRect().height }
    JS
  end

  # Each zone table's menu column width and the right edges of its Cost and Total columns, as the frame draws them.
  def zone_columns
    frame_js(<<~JS)
      return [...d.querySelectorAll(".c-zone table")].map((table) => {
        const box = (name) => table.querySelector("th." + name).getBoundingClientRect()
        return { menu: box("c-zone__c-menu").width, cost: box("c-zone__c-cost").right, total: box("c-zone__c-total").right }
      })
    JS
  end

  # Applies every rule inside every `@media (pointer: coarse)` block, as a touch screen draws them (the coarse trigger size included).
  def apply_coarse_rules
    frame_run(<<~JS)
      const css = [...d.styleSheets].flatMap((sheet) => [...sheet.cssRules])
        .filter((rule) => rule.conditionText && rule.conditionText.includes("pointer: coarse"))
        .flatMap((rule) => [...rule.cssRules].map((inner) => inner.cssText)).join("\\n")
      const style = d.createElement("style")
      style.textContent = css
      d.head.append(style)
    JS
  end

  # The page's width as the frame draws it, and how far each zone table is wider than its container.
  def page_and_table_overflow
    frame_js(<<~JS)
      const spill = [...d.querySelectorAll(".c-zone .c-collection")].map((box) => box.scrollWidth - box.clientWidth)
      return { page: d.documentElement.scrollWidth - d.documentElement.clientWidth, spill: Math.max(...spill) }
    JS
  end

  # The worst case of `deck_page_spec.rb`: a 60-character name with no space, a six-symbol cost, 123 owned and 1,234 proxies.
  def worst_case_row(deck, name: "W" * 60)
    entry = create(:catalog_entry, name:)
    faces = [ { "name" => name, "type_line" => "Creature", "mana_cost" => "{2}{W}{U}{B}{R}{G}", "image_uris" => {} } ]
    create(:mtg_printing, entry:, legalities: { "modern" => "banned" }, faces:)
    create_lot_in_zone(deck, "main", entry:, quantity: 123)
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "nonfoil", quantity: 1234)
  end

  # A proxy of +name+ in +zone_key+ of +deck+, one per finish given (a row's menu has four items a finish).
  def proxy_row(deck, zone_key, name, finishes: %w[nonfoil])
    entry = create(:mtg_printing, entry: create(:catalog_entry, name:), finishes: %w[nonfoil foil etched]).entry
    finishes.each { |finish| create(:deck_proxy, zone: deck.zone(zone_key), account:, entry:, finish:, quantity: 1) }
    entry
  end

  # One row menu of a page opened with its trigger 40px above the bar, then closed: what AC-1.3 and AC-1.11 read.
  def exercise_row_menu(css, index)
    place_trigger(css, index, gap: 40)
    height_before = page_height
    open_menu(css, index)
    settle
    state = menu_state
    open_menu(css, index) # a second click closes it
    settle
    state.merge("height_before" => height_before, "height_after" => page_height)
  end

  shared_examples "a row menu on a phone" do
    it "is scrolled clear of the tab bar when opened 40px above it (AC-1.3)", :aggregate_failures do
      open_phone(path, ready:)
      state = exercise_row_menu(trigger, trigger_index)
      expect_clear_of_bar(state)
      expect(state["fits"]).to be(true)
    end

    it "adds no page height and sits in no scrolling container (AC-1.11)", :aggregate_failures do
      open_phone(path, ready:)
      state = exercise_row_menu(trigger, trigger_index)
      expect(state["height_after"]).to eq(state["height_before"])
      expect(state["scrolling"]).to eq([])
      expect(state["fits"]).to be(true)
    end
  end

  context "with a collector's pages" do
    let(:collector) { create(:user) }

    before { system_sign_in_as(collector) }

    def account = collector.account
    def deck = @deck ||= create(:deck, account:, name: "Izzet Tempo")

    # Main has seven proxy rows, so the page is long; Considering's only row has proxies of two finishes (eight items) and is
    # the last row of the page.
    def build_long_deck
      (1..7).each { |n| proxy_row(deck, "main", "Proxy Card #{n}") }
      proxy_row(deck, "considering", "Tail Card", finishes: %w[nonfoil foil])
    end

    describe "the deck page" do
      before { build_long_deck }

      def path = deck_path(deck)
      def ready = ".c-zone:first-child table" # Main's; Considering has a table too, and `find` wants one match
      def trigger = row_menu("Proxy Card 4")

      it "scrolls a row menu opened 40px above the tab bar clear of it (AC-1.1)", :aggregate_failures do
        open_phone(path, ready:)
        place_trigger(trigger, gap: 40)
        open_menu(trigger)
        settle
        state = menu_state
        expect_clear_of_bar(state)
        expect(state["items"].first["top"]).to be >= state["appbar"]["bottom"] - 0.5
      end

      it "does not move the page for a menu that is already clear (AC-1.2)", :aggregate_failures do
        open_phone(path, ready:)
        place_trigger(trigger, from_top: 120)
        before = scroll_y
        open_menu(trigger)
        settle
        expect(open_menus).to eq(1)
        expect(scroll_y).to eq(before)
      end

      it "scrolls the last row of the page's menu clear of the bar, past the list's own bottom edge (AC-1.8)", :aggregate_failures do
        open_phone(path, ready:)
        frame_run("w.scrollTo(0, d.documentElement.scrollHeight)")
        open_menu(row_menu("Tail Card"))
        settle
        state = menu_state
        expect(state["items"].size).to eq(8)
        expect_clear_of_bar(state)
      end

      [ [ true, "instant" ], [ false, "smooth" ] ].each do |reduced, behavior|
        it "asks for #{behavior} scrolling when reduced motion is #{reduced ? "asked for" : "not asked for"} (AC-1.5)" do
          open_phone(path, ready:)
          place_trigger(trigger, gap: 40)
          frame_run(<<~JS)
            w.__scrolls = []
            const original = w.Element.prototype.scrollIntoView
            w.Element.prototype.scrollIntoView = function (options) { w.__scrolls.push(options); return original.call(this, options) }
            w.matchMedia = (query) => ({ matches: #{reduced} && query.includes("prefers-reduced-motion"), media: query,
                                         addEventListener() {}, removeEventListener() {} })
          JS
          open_menu(trigger)
          settle
          expect(frame_js("return w.__scrolls")).to eq([ { "block" => "nearest", "behavior" => behavior } ])
        end
      end

      it "states the clearances in CSS on a phone (AC-1.6)", :aggregate_failures do
        open_phone(path, ready:)
        open_menu(trigger)
        styles = clearance_styles
        expect(styles["bottom"].to_f).to be >= styles["bar"] + 8
        expect(styles["top"].to_f).to be >= styles["appbar"] + 8
        expect(styles["afterHeight"].to_f).to be >= styles["bottom"].to_f
      end

      it "states no clearance at 1280px (AC-1.6)" do
        open_in_narrow_frame(path, width: 1280, ready:, height: 700)
        open_menu(trigger)
        expect(clearance_styles.slice("top", "bottom", "afterContent")).to eq("top" => "0px", "bottom" => "0px", "afterContent" => "none")
      end

      it "does not move a page that draws no tab bar (AC-1.4)", :aggregate_failures do
        open_in_narrow_frame(path, width: 1280, ready:, height: 700)
        place_trigger(row_menu("Tail Card"), gap: 40)
        trigger_bottom = trigger_box(row_menu("Tail Card"))["bottom"]
        before = scroll_y
        open_menu(row_menu("Tail Card"))
        settle
        state = menu_state
        expect(state["list"]["bottom"]).to be > state["innerHeight"] # the list hangs below the window, as today
        expect(state["list"]["top"]).to be_within(1).of(trigger_bottom + 4)
        expect(scroll_y).to eq(before)
      end

      it "leaves a shell with no tab bar alone: no margins, no room box, no scroll (AC-1.12)", :aggregate_failures do
        open_phone(path, ready:)
        frame_run("d.body.classList.add('c-shell--untabbed'); d.querySelector('.c-tabbar').remove()")
        place_trigger(trigger, gap: 40)
        before = scroll_y
        open_menu(trigger)
        settle
        expect(clearance_styles.slice("top", "bottom", "afterContent")).to eq("top" => "0px", "bottom" => "0px", "afterContent" => "none")
        expect(scroll_y).to eq(before)
      end

      it "does not move a scrolled page when the account menu in the sticky app bar opens (AC-1.10)", :aggregate_failures do
        open_phone(path, ready:)
        frame_run("w.scrollTo(0, 300)")
        settle
        before = scroll_y
        expect(before).to be > 0
        open_menu("summary.c-avatar")
        settle
        expect(open_menus).to eq(1)
        expect(scroll_y).to eq(before)
      end

      it "closes on Escape with focus on the trigger (AC-1.7)", :aggregate_failures do
        open_phone(path, ready:)
        place_trigger(trigger, from_top: 120)
        open_menu(trigger)
        within_narrow_frame do
          expect(page).to have_css("details.c-menu[open]")
          # Escape is sent from an item in the list, so only the controller can put focus back on the summary.
          find("#{trigger} + .c-menu__list .c-menu__item", match: :first).send_keys(:escape)
          expect(page).to have_no_css("details.c-menu[open]")
        end
        expect(frame_js("return d.activeElement === d.querySelector(#{trigger.to_json})")).to be(true)
      end

      it "closes on a click outside it (AC-1.7)", :aggregate_failures do
        open_phone(path, ready:)
        place_trigger(trigger, from_top: 120)
        open_menu(trigger)
        frame_run("w.scrollTo(0, 0)") # the heading is then on screen, clear of the tab bar, so the real click needs no scroll
        within_narrow_frame do
          expect(page).to have_css("details.c-menu[open]")
          find("h1").click
          expect(page).to have_no_css("details.c-menu[open]")
        end
      end

      it "leaves the point under the room box to the page, not the list (AC-1.7)", :aggregate_failures do
        open_phone(path, ready:)
        place_trigger(trigger, from_top: 120)
        open_menu(trigger)
        settle
        hit = frame_js(<<~JS)
          const list = d.querySelector("details.c-menu[open] .c-menu__list"), box = list.getBoundingClientRect()
          const under = d.elementFromPoint(box.left + 20, box.bottom + 4)
          return under === null ? null : list.contains(under)
        JS
        expect(hit).not_to be_nil
        expect(hit).to be(false)
      end

      it "restores a page from Turbo's cache with every menu closed and the scroll it had (AC-1.13)", :aggregate_failures do
        open_phone(path, ready:)
        place_trigger(trigger, gap: 40)
        open_menu(trigger)
        settle
        left_at = scroll_y
        within_narrow_frame do
          find("details.c-menu[open] a", text: "Change proxy count").click
          expect(page).to have_no_css(".c-zone")
        end
        wait_for_scroll_events(frame: "narrow") # Back in the frame of the new page's scroll-to-top loses the saved scroll (#404)
        frame_run("w.history.back()")
        within_narrow_frame { expect(page).to have_css(".c-zone table").and(have_no_css("html[aria-busy]")) }
        settle
        expect(open_menus).to eq(0)
        expect(scroll_y).to be_within(1).of(left_at)
      end

      it "finds a scrolling ancestor of a menu when there is one, so AC-1.11's check can fail" do
        open_phone(path, ready:)
        frame_run(<<~JS)
          const menu = d.querySelector(#{trigger.to_json}).closest("details")
          const wrap = d.createElement("div")
          wrap.className = "probe-wrap"; wrap.style.overflowX = "auto"
          menu.parentElement.insertBefore(wrap, menu); wrap.append(menu)
        JS
        open_menu(trigger)
        expect(menu_state["scrolling"]).to eq([ "probe-wrap" ])
      end

      it_behaves_like "a row menu on a phone" do
        def trigger_index = 3
        def trigger = ".c-zone .c-table__actions summary"
      end
    end

    describe "the zones' columns" do
      # Main has a row with proxies (a menu trigger); Sideboard and Considering hold owned cards only, so their menu cells are empty.
      before do
        proxy_row(deck, "main", "Proxied")
        create_lot_in_zone(deck, "sideboard", entry: create(:mtg_printing, entry: create(:catalog_entry, name: "Owned only")).entry, quantity: 2)
        create_lot_in_zone(deck, "considering", entry: create(:mtg_printing, entry: create(:catalog_entry, name: "Considered")).entry)
      end

      it "keeps the menu column and the Cost and Total edges at one x in every zone at 360px (AC-1.14)", :aggregate_failures do
        open_phone(deck_path(deck), ready: ".c-zone:first-child table")
        columns = zone_columns
        spread = ->(key) { columns.pluck(key).then { |values| values.max - values.min } }
        expect(columns.size).to eq(3)
        expect(columns.pluck("menu").min).to be >= 63.5
        expect([ spread.("menu"), spread.("cost"), spread.("total") ]).to all(be <= 1)
      end

      # AC-1.15. Passes before and after: a guard on the floor's cost (spec Decision 6: the worst-case table spills 19px past its container,
      # the document does not scroll sideways).
      it "keeps the worst case from scrolling the page sideways at 360px with every coarse rule applied (AC-1.15)", :aggregate_failures do
        worst_case_row(deck)
        open_phone(deck_path(deck), ready: ".c-zone:first-child table")
        apply_coarse_rules
        trigger_width = frame_js("return d.querySelector('.c-zone .c-table__actions summary').getBoundingClientRect().width")
        expect(trigger_width).to be >= 40, "the coarse rules did not apply (the trigger is #{trigger_width}px wide)"
        overflow = page_and_table_overflow
        expect(overflow["page"]).to be <= 0
        expect(overflow["spill"]).to be <= 20, "the worst-case table is #{overflow["spill"]}px wider than its container (measured 19px)"
      end
    end

    describe "a deck whose row has proxies of three finishes" do
      def long_deck = @long_deck ||= create(:deck, account:, name: "Long menus")

      # Rows sort by name, so "Row 4 Triple" is the fourth row of Main, with three rows above it, three Main rows below it and
      # then the empty Sideboard and Considering zones.
      before do
        (1..3).each { |n| proxy_row(long_deck, "main", "Row #{n}") }
        proxy_row(long_deck, "main", "Row 4 Triple", finishes: %w[nonfoil foil etched])
        (5..7).each { |n| proxy_row(long_deck, "main", "Row #{n}") }
      end

      def open_triple
        open_phone(deck_path(long_deck), ready: ".c-zone table", height: 568)
        place_trigger(row_menu("Row 4 Triple"), gap: 40)
        open_menu(row_menu("Row 4 Triple"))
        settle
        menu_state
      end

      it "lands a list taller than the room under the app bar and lets the last item be scrolled clear (AC-1.9)", :aggregate_failures do
        state = open_triple
        expect(state["items"].size).to eq(12)
        expect(state["list"]["height"]).to be > state["bar"]["top"] - state["appbar"]["bottom"], "this list fits the room: it can't prove the tall case"
        expect(state["list"]["top"]).to be_within(1).of(state["appbar"]["bottom"] + 8)

        missing = state["items"].last["bottom"] - (state["bar"]["top"] - 8)
        frame_run("w.scrollBy(0, #{missing})")
        settle
        moved = menu_state
        expect(moved["scrollY"] - state["scrollY"]).to be_within(1).of(missing)
        expect_clear_of_bar(moved)
      end
    end

    describe "the card page's copies table" do
      before { (1..10).each { |n| create(:lot, account:, entry:, price_paid_cents: n * 100) } } # ten lots: the price paid is part of a lot's identity

      def entry = @entry ||= create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt")).entry

      it_behaves_like "a row menu on a phone" do
        def path = catalog_entry_path(entry)
        def ready = "#copies table"
        def trigger = "#copies .c-table__actions summary"
        def trigger_index = 5
      end
    end

    describe "the collection table" do
      before { (1..12).each { |n| owned_printing("Card #{n}", account:) } }

      it_behaves_like "a row menu on a phone" do
        def path = collection_path(view: "table")
        def ready = "table.c-table"
        def trigger = ".c-table__actions summary"
        def trigger_index = 6
      end
    end
  end

  context "with an admin's pages" do
    before { system_sign_in_as(create(:admin)) }

    describe "the users list" do
      before { create_list(:user, 12) }

      it_behaves_like "a row menu on a phone" do
        def path = admin_users_path
        def ready = "table"
        def trigger = ".c-table__actions summary"
        def trigger_index = 6
      end
    end

    describe "the jobs list", :solid_queue do
      # A row menu is on failed jobs only.
      before { 12.times { fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"), RuntimeError.new("boom")) } }

      it_behaves_like "a row menu on a phone" do
        def path = admin_jobs_path
        def ready = "table"
        def trigger = ".c-table__actions summary"
        def trigger_index = 6
      end
    end
  end

  # AC-3.1, a guard: it passes before and after. The bar is on each page of the deck family at a 360px viewport.
  describe "the tab bar on the deck family's pages (AC-3.1)" do
    let(:collector) { create(:user) }

    before do
      system_sign_in_as(collector)
      create_lot_in_zone(deck, "main", entry:) # the removal refusal page needs a copy in the deck
      create(:lot, account:, entry:, quantity: 2) # Use my copy needs a free copy
    end

    def account = collector.account
    def deck = @deck ||= create(:deck, account:, name: "Izzet Tempo")
    def empty_deck = @empty_deck ||= create(:deck, account:, name: "Empty")
    def entry = @entry ||= create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt"), finishes: %w[nonfoil foil etched]).entry
    def proxy = @proxy ||= create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "nonfoil", quantity: 2)

    def deck_family_paths
      { "Decks" => decks_path, "New deck" => new_deck_path, "Edit deck" => edit_deck_path(deck), "Deck" => deck_path(deck),
        "Change format" => edit_deck_format_path(deck), "Removal question" => new_deck_removal_path(empty_deck),
        "Removal refusal" => new_deck_removal_path(deck),
        "Add a proxy, choose" => new_deck_zone_proxy_path(deck, "main", q: "Lightning"),
        "Add a proxy, form" => new_deck_zone_proxy_path(deck, "main", entry: entry.external_key),
        "Change proxy count" => edit_deck_proxy_path(deck, proxy), "Remove proxy" => new_deck_proxy_removal_path(deck, proxy),
        "Add a new copy" => new_deck_proxy_copy_path(deck, proxy), "Use my copy" => new_deck_proxy_replacement_path(deck, proxy),
        "Add to deck" => new_catalog_entry_deck_addition_path(entry) }
    end

    # The tab bar as the frame draws it, or nil.
    def tab_bar_facts
      frame_js(<<~JS)
        const bar = d.querySelector(".c-shell > .c-tabbar")
        if (!bar) return null
        const style = w.getComputedStyle(bar)
        return { display: style.display, position: style.position, bottom: bar.getBoundingClientRect().bottom, frame: w.innerHeight,
                 tabs: bar.querySelectorAll("a").length, current: bar.querySelectorAll("a[aria-current=page]").length,
                 label: bar.querySelector("a[aria-current=page]")?.textContent.trim(), path: w.location.pathname }
      JS
    end

    it "is drawn, fixed to the frame's bottom, with five tabs and the right one current, on all fourteen pages", :aggregate_failures do
      deck_family_paths.each do |name, path|
        open_phone(path, ready: "main")
        bar = tab_bar_facts
        expect(bar).not_to be_nil, "#{name} draws no tab bar"
        expect(bar.slice("display", "position", "tabs", "current")).to eq("display" => "flex", "position" => "fixed", "tabs" => 5, "current" => 1), name
        expect(bar["bottom"]).to be_within(0.5).of(bar["frame"]), name
        expect(bar["path"]).to eq(URI(path).path), "#{name} ended on #{bar["path"]}"
        expect(name == "Add to deck" ? %w[Search Collection] : [ "Decks" ]).to include(bar["label"]), "#{name}: current tab #{bar["label"]}"
      end
    end
  end
end
