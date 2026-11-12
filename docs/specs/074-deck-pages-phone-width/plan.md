# Implementation Plan: Deck Pages at Phone Width (spec 074, #326)

**Spec:** docs/specs/074-deck-pages-phone-width/spec.md (v0.4.1, approved at Gate A by the coordinator)
**Decisions:** none (no ADR; the rulings are the spec's Decisions 1 to 5)
**Created:** 2026-11-11

## Global Constraints

Copied from the spec; every phase includes them.

- `components.css` is not changed (the design export's file). All CSS goes in one block of `additions.css` under the heading `/* ---------- Menus open clear of the tab bar (spec 074) ---------- */`, whose comment must not contain "spec 019", "spec 021" or "spec 023" (guards in `spec/design_system_files_spec.rb`).
- No view, helper, model, Rails controller, migration or export file changes (FR-5). The `menu` Stimulus controller and `additions.css` change.
- The CSS applies only below 640px (`@media (max-width: 639px)`) on a tabbed shell (`.c-shell:not(.c-shell--untabbed)`); 640px and wider, and a shell with no tab bar, keep today's behaviour exactly.
- The tab bar is drawn 67px high (56px link minimum height, 6px plus 4px link padding, 1px border, default `content-box`); the app bar 57px (56px plus 1px border). The margins are `calc(57px + var(--space-2))` above and `calc(67px + env(safe-area-inset-bottom) + var(--space-2))` below; the comment says where the 57px and 67px come from, so a later change to either bar finds them (Gate A condition 1).
- The controller scrolls only when the open list's bottom edge plus its bottom margin is below the viewport; "nearest" alignment; `instant` under `prefers-reduced-motion: reduce`, `smooth` otherwise, read when the menu opens.
- A 360px viewport in a spec is a frame of 360px plus the measured scrollbar, no taller than the window's viewport; overflow is compared with `clientWidth`, never `innerWidth` (#318).
- Tolerance: "at least 8px" and "within 1px" are compared with 0.5px of layout rounding, stated in each example.
- Commits: one per task, Conventional Commits, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (per the session's attribution reminder; the coordinator's earlier "Sonnet" line is superseded by it). Stage with `git add` in its own call, then `git commit` in another.
- Never write the throwaway probe or screenshot specs into a commit (`spec/system/zz_*`).

---

## Goal

On a phone, every item of an open menu is on screen or one scroll away (never behind the tab bar), nothing moves where a menu was already clear or no tab bar is drawn, the deck page's previews match the page, and the design system and the screenshots note say so.

---

## Batches for the implementers

One implementer (Sonnet) takes each batch, one commit per task, reading `plan.md` by line range; the supervisor checks each batch's diff before the next. Batch A: Tasks 1 to 3 (the examples, the CSS, the controller). Batch B: Tasks 4 to 6 (previews and `menu_cell`, the documents, the memory line and the index). Batch C: Tasks 7 to 9 (mutation checks, the runs, the screenshots and `verification.md`). Never two test runs at once in this worktree (the database is shared).

## Pre-implementation gates

- **Simplicity:** two components (one CSS block, one controller method) plus documents and one spec file. Passes.
- **Anti-abstraction:** `scrollIntoView` and `scroll-margin-*` used directly; no wrapper. Passes.
- **Integration-first:** there is no API; the system spec file (Phase 0) is the contract and is written and run red before any CSS or JS.

## Files

| File | Responsibility |
|---|---|
| `spec/system/menu_tab_bar_clearance_spec.rb` (new) | AC-1.1 to AC-1.12 and AC-3.1 on the real pages |
| `app/assets/stylesheets/collector/additions.css` | one block: two scroll margins and the room box |
| `app/javascript/controllers/menu_controller.js` | a `toggle` listener and `reveal` |
| `docs/design-system/previews/DeckPage.html`, `DeckPagePhone.html` | empty menu cell on rows with no proxy |
| `spec/system/design_system_deck_components_spec.rb` | `menu_cell` builds the same empty cell |
| `docs/design-system/components/{Menu,TableActions,TabBar,DeckPage}.md`, `docs/design-system/README.md` | the rule, the preview note, the stale arrow-key sentence |
| `.claude/memory/pr-screenshots-workflow.md` | the frame-taller-than-window line (the coordinator approved it) |

---

## Phase 0: The failing system spec

**Implements:** FR-4 | **Satisfies:** AC-1.1 to AC-1.12, AC-3.1 (all proved here; AC-1.1, AC-1.3, AC-1.5, AC-1.6, AC-1.8, AC-1.9 fail until Phase 1)
**Files:** `spec/system/menu_tab_bar_clearance_spec.rb`
**Interfaces:** Consumes: `open_in_narrow_frame`, `within_narrow_frame` (`spec/support/narrow_frame.rb`), `system_sign_in_as` (`spec/support/authentication_helpers.rb`), `create_lot_in_zone` (`spec/support/deck_helpers.rb`), `owned_printing` (`spec/support/collection_helpers.rb`), `queue_job`/`fail_job` (the `:solid_queue` helpers), factories `:deck`, `:deck_proxy`, `:mtg_printing`, `:catalog_entry`, `:lot`, `:user`, `:admin`. Produces: nothing later phases call; Phase 1 must make it pass.

### Task 1: write the spec file and run it red

- [ ] Create `spec/system/menu_tab_bar_clearance_spec.rb` with exactly this content:

```ruby
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
      def ready = ".c-zone table"
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
                 tabs: bar.querySelectorAll("a").length, current: bar.querySelectorAll("a[aria-current=page]").length }
      JS
    end

    it "is drawn, fixed to the frame's bottom, with five tabs and one current, on all fourteen pages", :aggregate_failures do
      deck_family_paths.each do |name, path|
        open_phone(path, ready: "main")
        bar = tab_bar_facts
        expect(bar).not_to be_nil, "#{name} draws no tab bar"
        expect(bar.slice("display", "position", "tabs", "current")).to eq("display" => "flex", "position" => "fixed", "tabs" => 5, "current" => 1), name
        expect(bar["bottom"]).to be_within(0.5).of(bar["frame"]), name
      end
    end
  end
end
```

Notes for the implementer: the file has no `let!`, no constants and at most one `let` a group, because `.rubocop.yml` enforces `RSpec/MultipleMemoizedHelpers` (max 5, counted across ancestor groups), `RSpec/LetSetup`, `RSpec/InstanceVariable` and `RSpec/ExampleLength` (max 15); it was linted statically (`bin/rubocop --stdin`) and syntax-checked before this plan was written, not run. Each describe defines `path`, `ready`, `trigger` and `trigger_index` as methods, and the shared examples call them. The route helpers (`new_deck_zone_proxy_path(deck, "main", …)`, `new_deck_proxy_replacement_path`) are from `bin/rails routes | grep deck`; `entry.external_key` is the entry's route key. If a cop objects after an edit, fix the code, not the config.

- [ ] Run: `bin/rspec spec/system/menu_tab_bar_clearance_spec.rb` — expect FAIL for: AC-1.1, AC-1.3 (the five pages' "scrolled clear" examples: the card page, the collection, the deck page's own row menus, the users list, the jobs list; the admin menus have one or two items but still end behind the bar), AC-1.5 (both), AC-1.6 on a phone, AC-1.8, AC-1.9; expect PASS for AC-1.2, AC-1.4, AC-1.6 at 1280px, AC-1.7 (the Escape example, the outside-click example, and the hit-test with the trigger 120px from the top), AC-1.10, AC-1.11 (the five pages), AC-1.12, "finds a scrolling ancestor" and AC-3.1. If an example the plan expects green is red, or one expected red is green, fix the example, not the plan: a red example that should be green usually means the fixture can't place the trigger (the `place_trigger` message says so). Record the red/green list in `verification.md` and commit that file with this task.
- [ ] Commit: `test: add the menu and tab bar clearance examples (spec 074)`

---

## Phase 1: The rule

**Implements:** FR-1, FR-2 | **Satisfies:** AC-1.1, AC-1.3, AC-1.5, AC-1.6, AC-1.8, AC-1.9 (and keeps the green partners green)
**Files:** `app/assets/stylesheets/collector/additions.css`, `app/javascript/controllers/menu_controller.js`
**Interfaces:** Consumes: the Phase 0 examples. Produces: the block and the `reveal` method; no later task calls them.

### Task 2: the CSS block (Gate A conditions 1 and 3)

- [ ] Run `grep -n 'spec 019\|spec 021\|spec 023' app/assets/stylesheets/collector/additions.css | wc -l` and note the count; run `bin/rspec spec/design_system_files_spec.rb` and confirm it passes before the edit.
- [ ] Append to the end of `app/assets/stylesheets/collector/additions.css` (after the last block; do not reorder or reformat anything above, other branches add blocks too):

```css

/* ---------- Menus open clear of the tab bar (spec 074) ---------- */
/* Below 640px a fixed tab bar covers the bottom 67px of the screen (the link's 56px minimum height and 6px + 4px padding, and the bar's 1px
   border: components.css `.c-tabbar`; a change to the bar's size changes the 67px here; the margin is a literal, not read from the bar, because the room box below is pure CSS and must agree with it, and the spec's AC-1.6 reads both bars' drawn heights from the page, so a mismatch fails an example) and the sticky app bar the top 57px (56px height and
   a 1px border: `.c-appbar`). A menu's list opens downward and is absolutely positioned, so it can end behind the bar. The menu controller
   scrolls an opened list into view (`scrollIntoView`, nearest alignment), and these margins say how far: the list's bottom edge ends
   `space-2` above the bar (plus the home indicator's inset, as `.c-main`'s padding does), a list taller than the room between the two bars
   starts just under the app bar. The empty box under an open list gives the page the scroll range to do it: the page ends 80px under its
   content, and a list adds overflow only to its own bottom edge, so without the box the last rows' menus could not be scrolled clear
   (measured, spec 074). The box is as wide as the list (an engine may ignore a zero-width box) and `pointer-events: none`, so a tap in it
   reaches the page and the controller still sees an outside click. Only below 640px on a shell with a tab bar: wider screens and
   `c-shell--untabbed` pages draw neither margin nor box. Menu items are 36px at a fine pointer and 44px at a coarse one, so nothing here
   states an item height. */
@media (max-width: 639px) {
  .c-shell:not(.c-shell--untabbed) .c-menu__list {
    scroll-margin-top: calc(57px + var(--space-2));
    scroll-margin-bottom: calc(67px + env(safe-area-inset-bottom) + var(--space-2));
  }
  .c-shell:not(.c-shell--untabbed) .c-menu[open] > .c-menu__list::after {
    content: ""; position: absolute; top: 100%; left: 0; right: 0; pointer-events: none;
    height: calc(67px + env(safe-area-inset-bottom) + var(--space-2));
  }
}
```

- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect PASS (the block's comment names "spec 074" only).
- [ ] Run: `bin/rspec spec/system/menu_tab_bar_clearance_spec.rb -e "(AC-1.6)" -e "(AC-1.12)"` — expect "states the clearances in CSS on a phone" PASS, the 1280px and AC-1.12 examples still PASS. (AC-1.1 and the rest still fail until Task 3.)
- [ ] Commit: `feat(design-system): menus keep clear of the tab bar with scroll margins and a room box (spec 074)`

### Task 3: the controller method

- [ ] Replace `app/javascript/controllers/menu_controller.js` with:

```js
import { Controller } from "@hotwired/stimulus"

// Closes a <details> menu on outside click or Escape; the menu works without it. On a phone it also scrolls an opened
// menu's list clear of the fixed tab bar (spec 074).
export default class extends Controller {
  connect() {
    this.close = this.close.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    this.reveal = this.reveal.bind(this)
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.onKeydown)
    // `toggle` does not bubble, so the listener is on the <details> itself (no view carries a data-action for it).
    this.element.addEventListener("toggle", this.reveal)
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.onKeydown)
    this.element.removeEventListener("toggle", this.reveal)
  }

  close(event) {
    if (!this.element.contains(event.target)) this.element.open = false
  }

  onKeydown(event) {
    if (event.key === "Escape" && this.element.open) {
      this.element.open = false
      this.element.querySelector("summary")?.focus()
    }
  }

  // When the <details> opens and its list would end behind the tab bar, scrolls the page just far enough (the list's
  // scroll margins in additions.css say how far). It does nothing where no tab bar is drawn (640px and wider, a page with
  // none) and nothing when the list is already clear, so the account menu in the sticky app bar never moves a page. The
  // reduced-motion preference is read now, not when the controller connects. `toggle` fires on close too, hence the check.
  reveal() {
    if (!this.element.open) return
    const bar = document.querySelector(".c-shell > .c-tabbar")
    if (!bar || getComputedStyle(bar).display === "none") return
    const list = this.element.querySelector(".c-menu__list")
    if (!list) return
    const margin = parseFloat(getComputedStyle(list).scrollMarginBottom) || 0
    if (list.getBoundingClientRect().bottom + margin <= window.innerHeight) return
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    list.scrollIntoView({ block: "nearest", behavior: reduced ? "instant" : "smooth" })
  }
}
```

- [ ] Run: `bin/rspec spec/system/menu_tab_bar_clearance_spec.rb` — expect all PASS. If AC-1.8 or AC-1.9 fail, read the failure's numbers first (the measured prototype is in `verification.md`) and report before changing the CSS or the spec.
- [ ] Run: `bin/rspec spec/system/bulk_mode_spec.rb spec/system/narrow_admin_pages_spec.rb spec/system/narrow_bulk_pages_spec.rb spec/system/bulk_move_spec.rb spec/system/admin_jobs_spec.rb spec/system/deck_proxy_replacements_spec.rb spec/system/lot_moves_spec.rb` — expect PASS (the existing examples that open a menu; the plan's list from the spec's Notes). Note the result for `verification.md`.
- [ ] Run: `bin/rubocop app/javascript spec/system/menu_tab_bar_clearance_spec.rb` (the JS is not linted; the spec is) and `bin/importmap audit` is unaffected.
- [ ] Commit: `feat(menu): scroll an opened menu clear of the phone tab bar (spec 074)`

---

## Phase 2: The previews, the design system and the memory line

**Implements:** FR-3 | **Satisfies:** AC-2.1, AC-2.2, AC-3.2, AC-3.3, AC-3.4
**Files:** `docs/design-system/previews/DeckPage.html`, `docs/design-system/previews/DeckPagePhone.html`, `spec/system/design_system_deck_components_spec.rb`, `docs/design-system/components/Menu.md`, `TableActions.md`, `TabBar.md`, `DeckPage.md`, `docs/design-system/README.md`, `.claude/memory/pr-screenshots-workflow.md`, `docs/specs/README.md`
**Interfaces:** Consumes: the finished rule. Produces: documents only.

### Task 4: the previews and `menu_cell`

- [ ] Write a one-off script in the scratchpad (not in the repo) `fix_previews.py`:

```python
import re, sys
stale = re.compile(r'<td class="c-table__actions"><details class="c-menu"><summary [^>]*aria-label="Actions for [^"]*">.*?</summary><div class="c-menu__list"><a class="c-menu__item" href="#">Move copies</a></div></details></td>')
for path in sys.argv[1:]:
    s = open(path).read()
    s, n = stale.subn('<td class="c-table__actions"></td>', s)
    assert n == 12, f"{path}: replaced {n}, wanted 12"
    assert "Move copies" not in s
    open(path, "w").write(s)
    print(path, n)
```

- [ ] Run it: `python3 <scratchpad>/fix_previews.py docs/design-system/previews/DeckPage.html docs/design-system/previews/DeckPagePhone.html` — expect `12` for each file. (It stops, writing nothing, if the count differs; if it does, read the two files' row cells and fix the pattern, not the count.)
- [ ] Check with `git grep -n 'Move copies' -- docs/design-system/previews ':!.kamal/secrets'` — expect no hit in the two deck previews; rows with proxies keep their menus (the open one on Murktide Regent).
- [ ] In `spec/system/design_system_deck_components_spec.rb`, replace the comment and body of `menu_cell` (lines 198 to 203) with:

```ruby
  # `TableActions`: a row with proxies has its menu (decision 17, spec 068 decision 5); a row with none has an empty cell, so the
  # menu column is the same in every zone (the page builds it so: `decks/_proxy_menu`).
  def menu_cell(row)
    return %(<td class="c-table__actions"></td>) unless row[:proxy].positive?

    dots = %(<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><circle cx="5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="19" cy="12" r="1.8"/></svg>)
    %(<td class="c-table__actions"><details class="c-menu"><summary class="c-btn c-btn--ghost c-btn--sm c-btn--icon" aria-label="Actions for #{row[:name]} #{row[:set]}">#{dots}</summary><div class="c-menu__list"><a class="c-menu__item" href="#">Use my copy</a></div></details></td>)
  end
```

- [ ] Run: `bin/rspec spec/system/design_system_deck_components_spec.rb` — expect PASS. If an example now fails because the empty cell changes a width at a phone width, the failure is about the page's real width (the page draws the empty cell): stop, record the example and numbers, and report to the supervisor before changing any assertion.
- [ ] Look at both previews in a browser (serve the worktree as `.claude/memory/pr-screenshots-workflow.md` says: `python3 -m http.server 3871 --bind 127.0.0.1 --directory "$PWD"`, then Firefox) or by the screenshots in Phase 3: rows with no proxy show an empty last cell and the open menu on Murktide Regent is unchanged.
- [ ] Commit: `docs(design-system): the deck page previews draw an empty menu cell on rows with no proxy (spec 074)` (the previews and the spec file in one commit)

### Task 5: the design-system documents (Gate A condition 4)

- [ ] `docs/design-system/components/Menu.md`: replace the bullet "A Stimulus `menu` controller adds close on outside click and Esc, arrow-key movement and focus return to the trigger; without it the menu still opens and closes." with:

```markdown
- A Stimulus `menu` controller adds close on outside click and Esc, focus return to the trigger on Esc, and, on a phone, the scroll below; without it the menu still opens and closes. (There is no arrow-key movement: an earlier version of this line, and the comment above `.c-menu` in `components.css`, claimed it; the export's comment is left as it is and the next export fixes it, spec 074.)
- **A menu opened near the bottom of a phone is scrolled clear of the tab bar** (spec 074, #326). Below 640px, on a page with a tab bar, the controller scrolls the page just far enough that the open list's bottom edge ends `space-2` above the bar (plus `env(safe-area-inset-bottom)`), and a list taller than the room between the app bar and the bar starts just under the app bar. It does nothing when the list is already clear, at 640px and wider, or on a page with no tab bar (`c-shell--untabbed`), and it scrolls instantly under `prefers-reduced-motion: reduce` and smoothly otherwise. The clearances are `scroll-margin-top` and `scroll-margin-bottom` on `.c-menu__list` and a room box (an `::after` on the open list, as wide as the list, `pointer-events: none`) that lets the page scroll that far at its end, all in one block of `additions.css`; a menu is never put inside a scrolling container, or the room box would show as a scrollbar in it. The 57px (app bar) and 67px (tab bar) in the block are the bars' drawn heights: change them with the bars.
```

- [ ] `docs/design-system/components/TableActions.md`: append one bullet after "Used by …":

```markdown
- Rows near the bottom of a phone open their menu clear of the tab bar (`Menu`, spec 074): the page scrolls for the list, so a row's last item, often the destructive one, is never behind the bar. Nothing here sets a height for it.
```

- [ ] `docs/design-system/components/TabBar.md`: add a new bullet after the bullet "It stays visible while scrolling; …":

```markdown
- A `Menu` opened near the bar is scrolled clear of it (`Menu`, spec 074); when you shoot a phone page, size the window taller than the frame, or the fixed bar is clipped out of the picture (a frame taller than the window's viewport loses it).
```


- [ ] `docs/design-system/components/DeckPage.md`: in "The row menu", after the last bullet ("'Move copies' is not offered on the deck page …"), add:

```markdown
- The previews (`DeckPage.html`, `DeckPagePhone.html`) draw the empty `td.c-table__actions` on every row with no proxy, as the page does, and the menus of the proxy rows with the items above (spec 074, #326; they showed "Move copies" on rows with no proxy until then). A row menu near the bottom of a phone is scrolled clear of the tab bar: see `Menu`.
```

- [ ] `docs/design-system/README.md`, Navigation section: after the bullet "The tab bar holds five tabs at most and is now full …" add:

```markdown
- A menu opened near the bottom of a phone is scrolled clear of the tab bar, so no item is hidden behind it (`Menu`, spec 074, [#326](https://github.com/plainprogrammer/Collector/issues/326)); nothing changes at 640px and wider.
```

- [ ] Read the five edited files once for sentence-case, no hard-coded colours and the "Used by" lists; the design-system skill's voice rules apply. No RSpec on prose (`.claude/rules/testing.md`).
- [ ] Commit: `docs(design-system): state the menu clearance rule in Menu, TableActions, TabBar, DeckPage and the README (spec 074)`

### Task 6: the memory line and the index

- [ ] `.claude/memory/pr-screenshots-workflow.md`: append this paragraph (the coordinator approved the line, 2026-11-11):

```markdown
**A frame taller than the window's viewport loses the fixed tab bar (spec 074, 2026-11-11):** a narrow frame is clipped to the window, and the phone tab bar is fixed to the frame's bottom, so the picture shows no bar. Reproduced: an 815px frame in a 1280×800 window (a 715px viewport) gave an 815px shot with no bar, in a 1280×900 window (815px viewport) the same shot had it, and a 1700px frame in this suite's 1400×1400 window (1315px viewport) gave a 1315px shot with no bar. Spec 071's shots 03, 04, 05 and others look like this; its window can't be read back, so the cause is reproduced, not confirmed. Make the window taller than the frame (`page.current_window.resize_to(…)`, and the after hook restores it) or shoot in a frame no taller than the viewport, and look for the bar in every phone shot.
```

- [ ] `docs/specs/README.md`: row 074's Status stays `Approved`; change its Plan cell, which said `none` until the plan landed, from `| none | | |` to `| present | | |` on the 074 row only.
- [ ] Commit: `docs: record the frame-taller-than-window trap and the spec 074 plan (spec 074)`

---

## Phase 3: Verification

**Implements:** All FRs | **Satisfies:** All ACs
**Files:** `docs/specs/074-deck-pages-phone-width/verification.md`, `docs/specs/074-deck-pages-phone-width/screenshots/`
**Interfaces:** Consumes: the finished work. Produces: `verification.md`'s evidence and the screenshots.

### Task 7: the mutation checks, by hand, once, never committed

- [ ] Stub the controller's `reveal` to always `list.scrollIntoView({ block: "end", behavior: "instant" })` (an unconditional scroll): run `bin/rspec spec/system/menu_tab_bar_clearance_spec.rb -e "(AC-1.2)" -e "(AC-1.10)"` — expect both FAIL (a rule that always scrolls moves a clear menu). Restore the file (`git checkout app/javascript/controllers/menu_controller.js`).
- [ ] Stub `reveal` to return at once: run `-e "(AC-1.1)" -e "(AC-1.8)"` — expect FAIL. (The parentheses keep `-e` from also matching AC-1.10 to AC-1.12.) Restore.
- [ ] Remove `pointer-events: none` from the room box: run `-e "under the room box"` — expect FAIL. Restore.
- [ ] Remove the room box rule: run `-e "(AC-1.8)"` — expect FAIL. Restore.
- [ ] Remove `scroll-margin-top`: run `-e "(AC-1.9)"` — expect FAIL. Restore.
- [ ] In `app/views/decks/show.html.erb` (do not commit) remove `<%= render "layouts/tabbar", section: :decks %>`: run `-e "(AC-3.1)"` — expect FAIL naming "Deck". Restore (`git checkout app/views/decks/show.html.erb`).
- [ ] `git status --short` shows only the intended files. Record each mutation and its result in `verification.md`.

### Task 8: the whole file, the neighbours, the lint, the doc build

- [ ] Run: `bin/rspec spec/system/menu_tab_bar_clearance_spec.rb spec/design_system_files_spec.rb spec/system/design_system_deck_components_spec.rb spec/system/deck_page_spec.rb` — expect PASS; note the counts.
- [ ] Run: `bin/rubocop` on the changed Ruby files, `bin/yard doc` (a YARD warning fails `bin/ci checks`; `menu_controller.js` is not in YARD's scope, the spec file is not either) and `bin/brakeman` — expect clean.
- [ ] The full `bin/ci` runs at the push with a slot from the coordinator (CLAUDE.md: the pre-push hook runs it).

### Task 9: screenshots and the record (throwaway spec; nothing from it is committed except the images)

- [ ] Write `spec/system/zz_074_screenshots_spec.rb` (uncommitted) with factory data as `.claude/memory/pr-screenshots-workflow.md` describes: the deck of Phase 0's fixture, `SHOTS_DIR=<scratchpad>`. Window taller than the frame: `page.current_window.resize_to(1400, 1400)` (the default). Shots, each in light and dark (set `data-theme` in the page and inside the frame, pause 0.6s after each switch), at a 360px viewport (`open_phone`-style frame, 640px tall): (1) AFTER: the deck page, Proxy Card 4's menu opened 40px above the bar, settled; (2) AFTER: Tail Card's eight-item menu at the page's end; (3) BEFORE, emulated: the same two states with the page restored to the scroll position it had when the menu opened (`w.scrollTo(0, before)` right after the click settles), which is what the old code showed; say so in `verification.md`; (4) the two previews (`DeckPage.html`, `DeckPagePhone.html`) served as the memory file's "static previews" paragraph says, at 1280px and a 390px frame, both themes; (5) the card page's copies menu and the collection table's row menu opened near the bottom, after only; (6) one 1280px shot of the deck page with a menu open (nothing moved). Look at every shot yourself before keeping it, and look for the tab bar in each phone shot.
- [ ] Compress with `magick in.png -resize 1000x -quality 70 out.jpg`; copy into `docs/specs/074-deck-pages-phone-width/screenshots/` with names like `01-row-menu-near-bottom-after-360-light.jpg`; list them in `verification.md`. A short GIF of the menu opening and the page scrolling (frames at 4 per second: `ffmpeg -framerate 4 -pattern_type glob -i 'f-*.png' -vf "scale=960:-1,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse" -loop 0 menu-clears-tab-bar-360.gif`, under 1 MB).
- [ ] Delete `spec/system/zz_074_screenshots_spec.rb` and `spec/system/zz_074_probe_spec.rb` before committing. Commit the images: `docs(spec): add the before and after shots for spec 074`.
- [ ] Fill `verification.md`: the red and green lists of Phase 0, the mutation results, the test counts, the Back-navigation check (open a row menu, follow "Edit copy", press Back: record whether the page scrolls on restore), the measured move when the menu closes at a page's end, the existing-example runs, the screenshots, the 0.5px tolerance, and that the headless Firefox can't emulate a coarse pointer (the 44px row items are not measured here). Then the implementation review (Mode B, read-only, Opus) under `## Implementation review` with its verdict on the first line.

---

## Integration Verification

- [ ] `bin/rspec spec/system/menu_tab_bar_clearance_spec.rb` — all green; the mutation checks of Task 7 each failed their example.
- [ ] `bin/rspec spec/design_system_files_spec.rb spec/system/design_system_deck_components_spec.rb` — green.
- [ ] Every AC of the spec has a row in `verification.md` with its evidence (an example name or "verified by reading").
- [ ] `git diff origin/main --stat` shows no view, helper, model, Rails controller, migration, export or `components.css` change (FR-5, FR-1).

## Quickstart Validation

- [ ] On a 360px viewport (the narrow frame), open the deck page, scroll a proxy row near the bottom and open its "…": every item is above the tab bar, "Remove proxy" last, in both themes. At 1280px nothing moves.
