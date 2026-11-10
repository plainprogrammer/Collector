require "rails_helper"

# Spec 060: the CSS the deck components need, proved in headless Firefox on the app's own pages. No deck view exists yet
# (#49 builds the first), so each component's markup is added to a real page (the Locations page) inside a wrapper `div`
# whose width the example sets; a container query answers the wrapper's width.
RSpec.describe "Design system: deck components", type: :system do
  let(:user) { create(:user) }

  before do
    system_sign_in_as(user)
    visit locations_path
    blank_host
  end

  def theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def add_to_main(html) = page.execute_script("document.querySelector('main').insertAdjacentHTML('beforeend', arguments[0])", html)
  def evaluate(script) = page.evaluate_script("(() => { #{script} })()")

  # Clears the host page so its own rules cannot answer the examples: the Locations page's `c-locations` class gives every
  # `.c-btn` and `.c-input` a 44px floor, which would pass a size example without the new rule, and its own `.c-form` and
  # `.c-pagehead` would match an unscoped selector. In a narrow frame the same call runs inside the frame.
  def blank_host
    page.execute_script(<<~JS)
      const main = document.querySelector("main")
      main.className = "c-main c-page"
      main.replaceChildren()
    JS
  end

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

  # An element's border box in viewport pixels.
  def box(selector)
    evaluate(<<~JS)
      const rect = document.querySelector(#{selector.to_json}).getBoundingClientRect()
      return { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom, width: rect.width, height: rect.height }
    JS
  end

  # `html` inside a wrapper of a set width: a container query answers the wrapper, not the window. A table's wrapper is
  # `container: "collection"`.
  def wrap(width, html, container: "page") = %(<div class="c-#{container}" style="width:#{width}px">#{html}</div>)

  # The `c-curve` markup of a mana curve: seven `[owned, proxy]` pairs, mana value 0 to 6+. `--max` is the tallest column's
  # owned plus proxy; a part of zero has no element, so its borders draw no sliver.
  def curve_html(columns)
    max = columns.sum(&:sum).zero? ? 1 : columns.map(&:sum).max
    cols = columns.map { |owned, proxy| curve_col(owned, proxy, max) }.join
    labels = %w[0 1 2 3 4 5 6+].map { "<span>#{it}</span>" }.join
    owned, proxy = columns.transpose.map(&:sum)
    <<~HTML.squish
      <div class="c-curve"><div role="img" aria-label="Mana curve of the nonland cards in Main">
        <div class="c-curve__cols" aria-hidden="true">#{cols}</div><div class="c-curve__labels" aria-hidden="true">#{labels}</div></div>
        <ul class="c-curve__legend"><li><span class="c-curve__swatch c-curve__swatch--owned"></span>Owned #{owned}</li>
        <li><span class="c-curve__swatch c-curve__swatch--proxy"></span>Proxy #{proxy}</li></ul>
        <p class="c-curve__avg">Average mana value <b>2.3</b></p></div>
    HTML
  end

  def curve_col(owned, proxy, max)
    parts = +""
    parts << %(<div class="c-curve__proxy" style="--proxy:#{proxy};--max:#{max}"></div>) if proxy.positive?
    parts << %(<div class="c-curve__owned" style="--owned:#{owned};--max:#{max}"></div>) if owned.positive?
    %(<div class="c-curve__col"><span class="c-curve__count">#{owned + proxy}</span><div class="c-curve__bar">#{parts}</div></div>)
  end

  # A deck shape panel, `id` on the section so every example scopes its selectors to it. The types and the mana bar are
  # plain strings until their own phases give them markup.
  def panel_html(curve:, types: "", mana: "", id: "probe")
    <<~HTML.squish
      <section class="c-shape" id="#{id}" aria-labelledby="#{id}-title">
        <div><h2 class="c-shape__title" id="#{id}-title">Deck shape</h2><p class="c-shape__scope">Main · 60 cards</p></div>
        <div class="c-shape__part"><h3 class="c-shape__heading">Mana curve</h3>#{curve}</div>
        <div class="c-shape__part"><h3 class="c-shape__heading">Card types</h3>#{types}</div>
        <div class="c-shape__part"><h3 class="c-shape__heading">Mana symbols</h3>#{mana}</div>
      </section>
    HTML
  end

  describe "ProxyTag (AC-1.2, AC-1.3)" do
    def tag = %(<span class="c-proxy" id="probe">Proxy <b>2</b></span>)

    %w[light dark].each do |name|
      it "is a dashed, uncoloured tag, 20px high, in the #{name} theme", :aggregate_failures do
        add_to_main(tag)
        theme(name)
        expect(computed("#probe", "border-top-style", "border-top-color", "color", "height"))
          .to eq([ "dashed", token("--ink-muted"), token("--ink"), "20px" ])
        expect(computed("#probe", "border-top-left-radius")).to eq([ "4px" ])
      end
    end

    it "reads the word Proxy and the count" do
      add_to_main(tag)
      expect(evaluate('return document.querySelector("#probe").textContent')).to match(/\AProxy\s+2\z/)
    end
  end

  describe "DeckShape panel and curve (AC-2.2 to AC-2.4)" do
    def columns = [ [ 4, 0 ], [ 11, 1 ], [ 5, 3 ], [ 4, 0 ], [ 4, 0 ], [ 0, 0 ], [ 2, 2 ] ]
    def curve_panel(width = 320) = add_to_main(wrap(width, panel_html(curve: curve_html(columns))))

    # Per column: its count text and its parts' heights, the owned part's top and the proxy part's bottom (a missing part
    # is 0 high and has no edge).
    def measured_columns
      evaluate(<<~JS)
        const edge = (el, side) => el ? el.getBoundingClientRect()[side] : null
        return [ ...document.querySelectorAll("#probe .c-curve__col") ].map((col) => {
          const owned = col.querySelector(".c-curve__owned"), proxy = col.querySelector(".c-curve__proxy")
          return { count: col.querySelector(".c-curve__count").textContent,
                   owned: owned ? owned.getBoundingClientRect().height : 0, proxy: proxy ? proxy.getBoundingClientRect().height : 0,
                   ownedTop: edge(owned, "top"), proxyBottom: edge(proxy, "bottom") }
        })
      JS
    end

    def expect_column(found, owned, proxy)
      expect(found["count"]).to eq((owned + proxy).to_s)
      expect(found["owned"]).to be_within(1).of(96.0 * owned / 12)
      expect(found["proxy"]).to be_within(1).of(96.0 * proxy / 12)
      expect(found["proxyBottom"]).to be_within(1).of(found["ownedTop"]) if owned.positive? && proxy.positive?
    end

    # Overflow of the panel and the legend, the right edges of the counts and columns against the panel's padding edge,
    # and the narrowest column.
    def curve_fit
      evaluate(<<~JS)
        const panel = document.querySelector("#probe"), legend = document.querySelector("#probe .c-curve__legend")
        const inner = panel.getBoundingClientRect().right - parseFloat(getComputedStyle(panel).borderRightWidth)
        const cells = [ ...panel.querySelectorAll(".c-curve__count, .c-curve__col") ]
        return { panelScrolls: panel.scrollWidth > panel.clientWidth, legendScrolls: legend.scrollWidth > legend.clientWidth,
                 inside: cells.every((el) => el.getBoundingClientRect().right <= inner + 0.5),
                 narrowest: Math.min(...[ ...panel.querySelectorAll(".c-curve__col") ].map((el) => el.getBoundingClientRect().width)) }
      JS
    end

    def fits?(found) = !found["panelScrolls"] && !found["legendScrolls"] && found["inside"] && found["narrowest"] >= 24

    it "draws each part 96px times its share of the tallest column, proxies on owned (AC-2.2)", :aggregate_failures do
      curve_panel
      columns.zip(measured_columns).each { |(owned, proxy), found| expect_column(found, owned, proxy) }
      expect(evaluate('return [ ...document.querySelectorAll("#probe .c-curve__labels span") ].map((el) => el.textContent)'))
        .to eq(%w[0 1 2 3 4 5 6+])
      expect(computed("#probe .c-curve__cols", "border-bottom-width", "border-bottom-style", "border-bottom-color"))
        .to eq([ "1px", "solid", token("--line-strong") ])
    end

    %w[light dark].each do |name|
      it "fills owned with ink-muted and proxies hatched with an ink-muted outline, never brand, in the #{name} theme", :aggregate_failures do
        curve_panel
        theme(name)
        expect(computed("#probe .c-curve__owned", "background-color")).to eq([ token("--ink-muted") ])
        hatch = computed("#probe .c-curve__proxy", "background-image", "border-top-width", "border-top-style", "border-top-color")
        expect(hatch.first).to start_with("repeating-linear-gradient").and include(token("--line-strong")).and include(token("--surface-raised"))
        expect(hatch.drop(1)).to eq([ "1px", "solid", token("--ink-muted") ])
        painted = %w[.c-curve__owned .c-curve__proxy .c-curve__swatch--owned .c-curve__swatch--proxy].flat_map do |part|
          computed("#probe #{part}", "background-color", "border-top-color", "color")
        end
        expect(painted).not_to include(token("--brand"))
      end
    end

    [ 320, 313 ].each do |width|
      it "keeps the curve and its legend inside a panel #{width}px wide, columns at least 24px (AC-2.4)", :aggregate_failures do
        curve_panel(width)
        expect(fits?(curve_fit)).to be(true)
      end
    end

    it "reports a panel 150px wide as not fitting (the measure can fail)" do
      curve_panel(150)
      expect(fits?(curve_fit)).to be(false)
    end
  end
end
