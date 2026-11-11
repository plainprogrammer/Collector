require "rails_helper"

# Spec 057: the CSS the deck rules need, proved in headless Firefox on the app's own pages. The grouped selects and the
# stat strips have no page yet (the deck issues build them), so their markup is added to a real page; the header and the
# tab bar are the app's own partials with the app's own Decks link and tab (spec 062 AC-4.2): the examples count them and
# never add them. The "can fail" controls still clone links and tabs, which is the point of them.
RSpec.describe "Design system: deck rules, navigation and pickers", type: :system do
  let(:user) { create(:user) }
  let(:binder) { create(:location, account: user.account, name: "Blue binder") }

  before { system_sign_in_as(user) }

  # A flat option, then a "Places" group and a "Decks" group, as the picker rule of FR-4 draws them. The last option is
  # the selected one, so neither option the examples read is the checked one, whose highlight Firefox draws itself.
  def picker
    <<~HTML.squish
      <option value="">No location</option>
      <optgroup label="Places"><option value="1">Blue binder</option></optgroup>
      <optgroup label="Decks"><option value="2">Izzet Tempo (all zones)</option><option value="3" selected>Izzet Tempo › Main</option></optgroup>
    HTML
  end

  # The two select shapes the app has: a form field (`.c-field select`) and a filter-bar select (`.c-select select`).
  def probe(kind)
    case kind
    when :form then %(<div class="c-field" id="probe-form"><label class="c-field__label" for="probe-form-select">Place</label><select id="probe-form-select">#{picker}</select></div>)
    when :filter then %(<label class="c-select" id="probe-filter"><span class="c-sr">Location</span><select>#{picker}</select></label>)
    end
  end

  def own = owned_printing("Lightning Bolt", account: user.account, location: binder)
  def theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def add_to_main(html) = page.execute_script("document.querySelector('main').insertAdjacentHTML('beforeend', arguments[0])", html)
  def evaluate(script) = page.evaluate_script("(() => { #{script} })()")

  # The computed values of one element, by CSS property name, in the order asked.
  def computed(selector, *properties)
    evaluate(<<~JS)
      const style = getComputedStyle(document.querySelector(#{selector.to_json}))
      return #{properties.to_json}.map((name) => style.getPropertyValue(name))
    JS
  end

  # A token as the browser resolves it for the current theme, written "rgb(r, g, b)".
  def token(name)
    evaluate(<<~JS)
      const probe = document.createElement("span")
      probe.style.color = "var(#{name})"
      document.body.append(probe)
      const value = getComputedStyle(probe).color
      probe.remove()
      return value
    JS
  end

  describe "grouped selects (AC-4.2, AC-4.3)" do
    { form: "#probe-form select", filter: "#probe-filter select" }.each do |kind, select|
      %w[light dark].each do |name|
        it "styles the labels and options of the #{kind} select in the #{name} theme", :aggregate_failures do
          own
          visit collection_path
          add_to_main(probe(kind))
          theme(name)
          expect(computed("#{select} optgroup", "color", "font-weight", "font-style")).to eq([ token("--ink-muted"), "600", "normal" ])
          expect(computed("#{select} optgroup option", "color", "background-color", "font-weight"))
            .to eq([ token("--ink"), token("--surface-raised"), "400" ])
          # An option outside any group carries no label style: it keeps the select's own text colour and weight.
          expect(computed("#{select} > option", "color", "font-weight")).to eq([ token("--ink"), "400" ])
          # A rule that set `font` on the optgroup, or a browser's own optgroup font, would change the options in it.
          expect(computed("#{select} optgroup option", "font-size", "font-family")).to eq(computed(select, "font-size", "font-family"))
        end
      end
    end
  end

  describe "the location filter's cap (AC-4.4)" do
    def cap(selector) = computed(selector, "max-width").first
    def collection_width(pixels) = page.execute_script("document.querySelector('.c-collection').style.width = arguments[0] + 'px'", pixels)

    it "is 300px in a collection 700px wide, in normal view and in bulk mode; the Set select beside it stays 220px", :aggregate_failures do
      own
      visit collection_path(view: "table")
      collection_width(700)
      expect(cap("select[name=location]")).to eq("300px")
      visit collection_path(bulk: 1)
      expect(page).to have_css(".c-bulkbar")
      collection_width(700)
      expect(cap("select[name=location]")).to eq("300px")
      visit catalog_entries_path
      collection_width(700)
      expect(cap(".c-select select")).to eq("220px")
    end

    it "is 220px in a 390px phone frame, in normal view and in bulk mode", :aggregate_failures do
      own
      visit collection_path
      open_in_narrow_frame(collection_path(view: "table"), width: 390, ready: "select[name=location]")
      within_narrow_frame { expect(cap("select[name=location]")).to eq("220px") }
      open_in_narrow_frame(collection_path(bulk: 1), width: 390, ready: ".c-bulkbar")
      within_narrow_frame { expect(cap("select[name=location]")).to eq("220px") }
    end
  end

  describe "the three-stat strip (AC-5.2 to AC-5.4)" do
    def three = [ [ "Owned", "7", "3 printings" ], [ "In decks", "4", "in 2 decks" ], [ "Free to use", "3", "not in a deck" ] ]
    def four = three + [ [ "Est. value", "$10.20", "updated today" ] ]

    def stat(label, value, small) = %(<div class="c-stat"><dt>#{label}</dt><dd>#{value}</dd><small>#{small}</small></div>)
    def strip(width, modifier, stats) = add_to_main(%(<div class="c-page" style="width:#{width}px"><dl class="c-stats #{modifier}" id="probe-strip">#{stats.map { stat(*it) }.join}</dl></div>))

    # Columns, each stat's width and its left and top border, whether the strip scrolls sideways and whether every
    # stat's content fits inside the stat.
    def layout
      evaluate(<<~JS)
        const strip = document.querySelector("#probe-strip")
        const stats = [ ...strip.children ]
        const border = (el, side) => getComputedStyle(el).getPropertyValue(`border-${side}-width`)
        return { columns: getComputedStyle(strip).gridTemplateColumns.split(" ").length,
                 widths: stats.map((el) => el.getBoundingClientRect().width),
                 left: stats.map((el) => border(el, "left")), top: stats.map((el) => border(el, "top")),
                 divider: stats[1] ? getComputedStyle(stats[1]).borderLeftColor : null, // a single strip has no second stat
                 scrolls: strip.scrollWidth > strip.clientWidth, fits: stats.every((el) => el.scrollWidth <= el.clientWidth) }
      JS
    end

    before do
      own
      visit collection_path
    end

    it "is three equal columns with a 1px line divider between neighbours at 900px (AC-5.2)", :aggregate_failures do
      strip(900, "c-stats--three", three)
      found = layout
      expect(found["columns"]).to eq(3)
      expect(found["widths"].max - found["widths"].min).to be <= 1
      expect(found["left"]).to eq([ "0px", "1px", "1px" ])
      expect(found["divider"]).to eq(token("--line"))
    end

    it "stays three across at 328px, divided by left borders and none on top, without overflow (AC-5.3)", :aggregate_failures do
      strip(328, "c-stats--three", three)
      found = layout
      expect(found["columns"]).to eq(3)
      expect(found["widths"].max - found["widths"].min).to be <= 1
      expect(found["left"]).to eq([ "0px", "1px", "1px" ])
      expect(found["top"]).to eq(%w[0px 0px 0px])
      expect([ found["scrolls"], found["fits"] ]).to eq([ false, true ])
    end

    it "leaves the four-up strip two by two and the single strip one column at 328px (AC-5.4)", :aggregate_failures do
      strip(328, "", four)
      found = layout
      expect([ found["columns"], found["left"], found["top"] ]).to eq([ 2, %w[0px 1px 0px 1px], %w[0px 0px 1px 1px] ])
      visit collection_path
      strip(328, "c-stats--single", three.first(1))
      expect(layout["columns"]).to eq(1)
    end
  end

  describe "five header links and five tabs (AC-1.3, AC-1.4)" do
    # Clones Collection's link (or tab) once per name, after the first: sections the app does not have, to show the
    # measure fails when the header or the bar holds too many.
    def add_nav_links(*names)
      page.execute_script(<<~JS, names)
        const first = document.querySelector(".c-appbar__nav a")
        let anchor = first
        for (const name of arguments[0]) {
          const copy = first.cloneNode(true)
          copy.textContent = name
          copy.removeAttribute("aria-current")
          anchor.after(copy)
          anchor = copy
        }
      JS
    end

    def add_tabs(*names)
      page.execute_script(<<~JS, names)
        const first = document.querySelector(".c-tabbar a")
        let anchor = first
        for (const name of arguments[0]) {
          const copy = first.cloneNode(true)
          copy.lastChild.textContent = name
          copy.removeAttribute("aria-current")
          anchor.after(copy)
          anchor = copy
        }
      JS
    end

    # Link count, how many distinct tops (1 is one line), whether every link ends inside the nav, whether the nav ends
    # before the account menu starts (true by the row's own layout), whether the account menu ends inside the bar, and whether
    # the page scrolls sideways. Extra links push the account menu out of the bar, which is what the control looks for.
    def header_fit
      evaluate(<<~JS)
        const nav = document.querySelector(".c-appbar__nav"), box = nav.getBoundingClientRect()
        const links = [ ...nav.querySelectorAll("a") ]
        const actions = document.querySelector(".c-appbar__actions").getBoundingClientRect()
        const bar = document.querySelector(".c-appbar"), barStyle = getComputedStyle(bar)
        const barEnd = bar.getBoundingClientRect().right - parseFloat(barStyle.paddingRight)
        return { links: links.length, lines: new Set(links.map((el) => Math.round(el.getBoundingClientRect().top))).size,
                 inside: links.every((el) => el.getBoundingClientRect().right <= box.right + 0.5),
                 beforeAccount: box.right <= actions.left, accountInside: actions.right <= barEnd + 0.5,
                 scrolls: document.documentElement.scrollWidth > window.innerWidth }
      JS
    end

    # Tab count, whether the last tab ends inside the bar, whether the bar scrolls sideways, and whether each tab's
    # label fits inside its tab (the bar is fixed, so page overflow alone can't see it overflow).
    def tabbar_fit
      evaluate(<<~JS)
        const bar = document.querySelector(".c-tabbar"), box = bar.getBoundingClientRect()
        const tabs = [ ...bar.querySelectorAll("a") ]
        const label = (tab) => { const range = document.createRange(); range.selectNodeContents(tab.lastChild); return range.getBoundingClientRect().width }
        return { tabs: tabs.length, lastInside: tabs.at(-1).getBoundingClientRect().right <= box.right + 0.5,
                 scrolls: bar.scrollWidth > bar.clientWidth, labelsFit: tabs.every((tab) => label(tab) <= tab.clientWidth) }
      JS
    end

    def header_fits?(found) = found["lines"] == 1 && found["inside"] && found["beforeAccount"] && found["accountInside"] && !found["scrolls"]

    # Which logo the header draws: whether the wordmark and the mark are displayed (decision 19).
    def logo
      evaluate(<<~JS)
        const shown = (selector) => getComputedStyle(document.querySelector(selector)).display !== "none"
        return { wordmark: shown(".c-appbar__wordmark"), mark: shown(".c-appbar__mark") }
      JS
    end

    [ 640, 719 ].each do |width|
      it "fits five links before the account menu, with the mark for the wordmark, at #{width}px (AC-1.3)", :aggregate_failures do
        open_in_narrow_frame(collection_path, width:, ready: ".c-appbar__nav", height: 1200)
        within_narrow_frame do
          found = header_fit
          expect(found["links"]).to eq(5)
          expect(header_fits?(found)).to be(true)
          expect(logo).to eq("wordmark" => false, "mark" => true)
        end
      end
    end

    it "fits five links with the wordmark at 720px, where the swap ends (AC-1.5)", :aggregate_failures do
      open_in_narrow_frame(collection_path, width: 720, ready: ".c-appbar__nav", height: 1200)
      within_narrow_frame do
        found = header_fit
        expect(found["links"]).to eq(5)
        expect(header_fits?(found)).to be(true)
        expect(logo).to eq("wordmark" => true, "mark" => false)
      end
    end

    # The header has five links now, so the count rule (the mark stands in only while the nav holds five or more) is tested by
    # taking one real link away: with four the wordmark returns at 640px.
    it "keeps the wordmark for four links at 640px (AC-1.6)", :aggregate_failures do
      open_in_narrow_frame(collection_path, width: 640, ready: ".c-appbar__nav", height: 1200)
      within_narrow_frame do
        page.execute_script("document.querySelector('.c-appbar__nav a[href=\"#{locations_path}\"]').remove()")
        expect(header_fit["links"]).to eq(4)
        expect(logo).to eq("wordmark" => true, "mark" => false)
      end
    end

    it "shows the app's five links in the order of AC-4.1 and leaves the page without a sideways scroll at 360px and 1280px", :aggregate_failures do
      [ 360, 1280 ].each do |width|
        open_in_narrow_frame(collection_path, width:, ready: "main", height: 1200)
        within_narrow_frame do
          expect(evaluate("return [...document.querySelectorAll('.c-appbar__nav a')].map((el) => el.textContent.trim())")).to eq(%w[Collection Decks Search Scan Locations])
          expect(evaluate("return document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
        end
      end
    end

    it "reports a header with four more links as not fitting (the measure can fail)", :aggregate_failures do
      open_in_narrow_frame(collection_path, width: 640, ready: ".c-appbar__nav", height: 1200)
      within_narrow_frame do
        add_nav_links("Wishlist", "Recently viewed", "Price alerts", "Trade binder")
        expect(header_fit["links"]).to eq(9)
        expect(header_fits?(header_fit)).to be(false)
      end
    end

    it "reports a header with a sixth link as not fitting at 640px (AC-4.2: the guard still fails on one)", :aggregate_failures do
      open_in_narrow_frame(collection_path, width: 640, ready: ".c-appbar__nav", height: 1200)
      within_narrow_frame do
        add_nav_links("Wishlist")
        expect(header_fit["links"]).to eq(6)
        expect(header_fits?(header_fit)).to be(false)
      end
    end

    it "keeps five tabs inside the bar, each label inside its tab, at 360px (AC-1.4)", :aggregate_failures do
      open_in_narrow_frame(collection_path, width: 360, ready: ".c-tabbar")
      within_narrow_frame do
        found = tabbar_fit
        expect([ found["tabs"], found["lastInside"], found["scrolls"], found["labelsFit"] ]).to eq([ 5, true, false, true ])
      end
    end

    it "reports a tab bar with three more tabs as not fitting (the measure can fail)", :aggregate_failures do
      open_in_narrow_frame(collection_path, width: 360, ready: ".c-tabbar")
      within_narrow_frame do
        add_tabs("Wishlist", "Collections", "Trades")
        found = tabbar_fit
        expect(found["tabs"]).to eq(8)
        expect(found.values_at("lastInside", "scrolls", "labelsFit")).not_to eq([ true, false, true ])
      end
    end
  end
end
