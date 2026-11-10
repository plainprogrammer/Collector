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

  # The first family of the `--font-mono` token, as the browser spells it in a computed `font-family`.
  def mono_family = evaluate('return getComputedStyle(document.documentElement).getPropertyValue("--font-mono")').split(",").first.strip.delete("\"'")

  def mana_names = { "W" => "White", "U" => "Blue", "B" => "Black", "R" => "Red", "G" => "Green" }

  # The `c-types` markup: `[name, owned, proxy]` rows. A type with no proxies keeps an empty suffix, so the counts line up.
  def types_html(rows)
    items = rows.map do |name, owned, proxy|
      suffix = proxy.positive? ? "#{proxy} proxy" : ""
      %(<li><span>#{name}</span><span class="c-types__n">#{owned + proxy}</span><span class="c-types__proxy">#{suffix}</span></li>)
    end
    %(<ul class="c-types">#{items.join}</ul>)
  end

  # The `c-manabar` and its caption: `counts` maps W, U, B, R, G to symbol counts. A segment under 10% is marked narrow.
  def manabar_html(counts)
    total = counts.values.sum
    order = mana_names.keys.select { counts.key?(it) }
    segs = order.map { |sym| manabar_seg(sym, counts[sym], total) }.join
    caption = order.map { |sym| "#{mana_names[sym]} #{counts[sym]} · #{(100.0 * counts[sym] / total).round}%" }.join(" · ")
    label = "Coloured mana symbols in Main: #{order.map { "#{mana_names[it].downcase} #{counts[it]}" }.join(", ")}"
    %(<ul class="c-manabar" role="img" aria-label="#{label}">#{segs}</ul><p class="c-manacap">#{caption}</p>)
  end

  def manabar_seg(sym, count, total)
    narrow = count * 10 < total ? " c-manabar__seg--narrow" : ""
    %(<li class="c-manabar__seg c-manabar__seg--#{sym.downcase}#{narrow}" style="--n:#{count}"><span>#{sym} #{count}</span></li>)
  end

  # The three parts of the panel, in order.
  def panel_parts(curve:, types:, mana:)
    <<~HTML.squish
      <div class="c-shape__part"><h3 class="c-shape__heading">Mana curve</h3>#{curve}</div>
      <div class="c-shape__part"><h3 class="c-shape__heading">Card types</h3>#{types}</div>
      <div class="c-shape__part"><h3 class="c-shape__heading">Mana symbols</h3>#{mana}</div>
    HTML
  end

  def default_curve = curve_html([ [ 4, 0 ], [ 11, 1 ], [ 5, 3 ], [ 4, 0 ], [ 4, 0 ], [ 0, 0 ], [ 2, 2 ] ])

  # A deck shape panel, `id` on the section so every example scopes its selectors to it.
  def panel_html(curve: default_curve, types: types_html([ [ "Lands", 22, 2 ], [ "Artifacts", 4, 0 ] ]),
                 mana: manabar_html("U" => 44, "R" => 16), id: "probe")
    <<~HTML.squish
      <section class="c-shape" id="#{id}" aria-labelledby="#{id}-title">
        <div><h2 class="c-shape__title" id="#{id}-title">Deck shape</h2><p class="c-shape__scope">Main · 60 cards</p></div>
        #{panel_parts(curve:, types:, mana:)}
      </section>
    HTML
  end

  def icon_svg(path) = %(<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{path}</svg>)

  def pip(sym)
    modifier = mana_names.key?(sym) ? " c-mana--#{sym.downcase}" : ""
    %(<span class="c-mana#{modifier}" aria-hidden="true">#{sym}</span>)
  end

  # The `c-cost` of a list of symbols (colours as W U B R G, generic as numbers), as `ManaCost.md` shows it.
  def cost_html(symbols)
    words = symbols.map { mana_names.key?(it) ? "1 #{mana_names[it].downcase}" : "#{it} generic" }.join(", ")
    %(<span class="c-cost" role="img" aria-label="Mana cost: #{words}">#{symbols.map { pip(it) }.join}</span>)
  end

  def proxy_tag(count) = %(<span class="c-proxy">Proxy <b>#{count}</b></span>)

  # One row of a zone: a name, where it sits, its cost (symbols or nil), the owned and proxy counts, its legality.
  def zrow(name, group: "Creatures", set: "MH2 · 52", cost: %w[R], owned: 4, proxy: 0, legal: :legal)
    { name:, group:, set:, cost:, owned:, proxy:, legal: }
  end

  def zone_rows
    [ zrow("Murktide Regent", cost: %w[5 U U], owned: 2, proxy: 2), zrow("Dragon's Rage Channeler", set: "MH3 · 124"),
      zrow("Ragavan, Nimble Pilferer", set: "MH2 · 138", legal: :banned),
      zrow("Counterspell", group: "Instants", set: "MH2 · 267", cost: %w[U U]), zrow("Lightning Bolt", group: "Instants", set: "2X2 · 117", owned: 3, proxy: 1),
      zrow("Island", group: "Lands", set: "MH3 · 308", cost: nil, owned: 9) ]
  end

  # A zone: head, then its table of grouped rows, or the empty sentence. `id` on the section.
  def zone_html(title, rows, id: nil)
    body = rows.empty? ? %(<p class="c-zone__empty">No cards in #{title} yet.</p>) : zone_table(rows)
    %(<section class="c-zone"#{%( id="#{id}") if id}>#{zone_head(title, rows)}#{body}</section>)
  end

  def zone_head(title, rows)
    cards = rows.sum { it[:owned] + it[:proxy] }
    counts = "#{cards} #{cards == 1 ? "card" : "cards"} · #{rows.sum { it[:owned] }} owned · #{rows.sum { it[:proxy] }} proxy"
    add = %(<a class="c-btn c-btn--ghost c-btn--sm" href="#">#{icon_svg('<path d="M12 5v14M5 12h14"/>')}Add a proxy<span class="c-sr"> to #{title}</span></a>)
    %(<div class="c-section__head"><h2 class="c-section__title">#{title}</h2><span class="c-section__count">#{counts}</span><div class="c-section__actions">#{add}</div></div>)
  end

  def zone_table(rows)
    cells = %(<th class="c-zone__c-cost">Cost</th><th class="c-zone__c-owned is-num is-opt">Owned</th><th class="c-zone__c-proxy is-num is-opt">Proxy</th><th class="c-zone__c-total is-num">Total</th>)
    body = rows.group_by { it[:group] }.map { |group, found| zone_group(group, found) + found.map { zone_row(it) }.join }.join
    %(<div class="c-collection"><table class="c-table"><thead><tr><th>Card</th>#{cells}<th class="c-zone__c-menu"><span class="c-sr">Actions</span></th></tr></thead><tbody>#{body}</tbody></table></div>)
  end

  def zone_group(group, rows)
    %(<tr class="c-zone__group"><th scope="rowgroup" colspan="6">#{group}<span class="c-zone__groupcount">#{rows.sum { it[:owned] + it[:proxy] }}</span></th></tr>)
  end

  def zone_row(row)
    proxy = row[:proxy].positive?
    legal = row[:legal] == :legal ? "" : %( <span class="c-legal c-legal--no">#{icon_svg('<path d="M6 6l12 12M18 6 6 18"/>')}#{row[:legal].to_s.humanize}</span>)
    set = %(<span class="c-zone__set">#{row[:set]}</span>)
    card = %(<td><div class="c-table__item"><div><a href="#">#{row[:name]}</a>#{legal}<span class="is-opt"><br>#{set}</span><span class="c-table__sub">#{set}#{" #{proxy_tag(row[:proxy])}" if proxy}</span></div></div></td>)
    dash = %(<span class="is-muted">–</span>)
    %(<tr>#{card}<td>#{row[:cost] ? cost_html(row[:cost]) : dash}</td><td class="is-num is-opt">#{row[:owned]}</td><td class="is-num is-opt">#{proxy ? proxy_tag(row[:proxy]) : dash}</td><td class="is-num">#{row[:owned] + row[:proxy]}</td>#{menu_cell(row)}</tr>)
  end

  # `TableActions`: every row has its menu (decision 17), so the menu column is the same in every zone.
  def menu_cell(row)
    dots = %(<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><circle cx="5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="19" cy="12" r="1.8"/></svg>)
    items = row[:proxy].positive? ? %(<a class="c-menu__item" href="#">Use my copy</a>) : %(<a class="c-menu__item" href="#">Move copies</a>)
    %(<td class="c-table__actions"><details class="c-menu"><summary class="c-btn c-btn--ghost c-btn--sm c-btn--icon" aria-label="Actions for #{row[:name]} #{row[:set]}">#{dots}</summary><div class="c-menu__list">#{items}</div></details></td>)
  end

  # The deck page body: the closed `details` copy of the panel, the `aside` copy, then the zones. `panel: false` leaves out both copies.
  def deck_html(panel: true)
    zones = [ zone_html("Main", zone_rows, id: "zone-main"), zone_html("Sideboard", [ zrow("Dress Down", group: "Instants", proxy: 2, owned: 0) ], id: "zone-side") ].join
    %(<div class="c-deck" id="probe">#{shape_copies if panel}<div class="c-deck__zones">#{zones}</div></div>)
  end

  def shape_copies
    parts = panel_parts(curve: default_curve, types: types_html([ [ "Lands", 22, 2 ] ]), mana: manabar_html({ "U" => 44, "R" => 16 }))
    facts = %(<span class="c-shapefold__title">Deck shape</span><span class="c-shapefold__facts">Main · 60 cards · average mana value 2.3</span>)
    %(<details class="c-shapefold"><summary>#{facts}</summary><div class="c-shape c-shape--bare">#{parts}</div></details><aside class="c-deck__shape">#{panel_html(id: "shape-aside")}</aside>)
  end

  def plus_icon = icon_svg('<path d="M12 5v14M5 12h14"/>')

  def deck_list = [ [ "Izzet Tempo", "Modern", 58, 11 ], [ "Mono Red Burn", "Pioneer", 60, 0 ], [ "Empty Shell", "Commander", 0, 0 ] ]

  # The Decks page: `.c-decks` on a wrapper holding the page head (count and the primary New deck button) and the table of
  # the markup reference. `decks` is `[name, format, owned, proxy]`; Cards is owned plus proxy (decision 12). `scoped: false`
  # leaves `.c-decks` off, the control of the phone example.
  def decks_html(decks = deck_list, scoped: true)
    cards = decks.sum { it[2] + it[3] }
    stats = "#{decks.size} decks · #{cards} cards"
    head = %(<div class="c-pagehead"><div><h1 class="c-pagehead__title">Decks</h1><p class="c-pagehead__stats">#{stats}</p></div>) +
           %(<div class="c-pagehead__actions"><a class="c-btn c-btn--primary" href="/decks/new">#{plus_icon}New deck</a></div></div>)
    %(<div#{%( class="c-decks") if scoped} id="probe">#{head}#{decks_table(decks)}</div>)
  end

  def decks_table(decks)
    heads = %w[Deck Format Cards Owned Proxy].zip([ "", " is-opt", " is-num", " is-num is-opt", " is-num is-opt" ]).map { |text, css| %(<th class="#{css.strip}">#{text}</th>) }
    %(<div class="c-collection"><table class="c-table"><thead><tr>#{heads.join}</tr></thead><tbody>#{decks.map { deck_row(*it) }.join}</tbody></table></div>)
  end

  def deck_row(name, format, owned, proxy)
    tag = proxy.positive? ? proxy_tag(proxy) : %(<span class="is-muted">–</span>)
    sub = [ "#{format} · #{owned} owned", (proxy_tag(proxy) if proxy.positive?) ].compact.join(" · ")
    item = %(<td><div class="c-table__item"><div><a href="#">#{name}</a><span class="c-table__sub">#{sub}</span></div></div></td>)
    %(<tr>#{item}<td class="is-opt">#{format}</td><td class="is-num">#{owned + proxy}</td><td class="is-num is-opt">#{owned}</td><td class="is-num is-opt">#{tag}</td></tr>)
  end

  # The New deck page's body: heading and the form of the markup reference.
  def new_deck_html
    formats = %w[Standard Modern Commander].map { %(<option>#{it}</option>) }.join
    field = %(<div class="c-field"><label class="c-field__label" for="deck_name">Name</label><label class="c-input"><input id="deck_name" type="text"></label></div>)
    format = %(<div class="c-field"><label class="c-field__label" for="deck_format">Format</label><select id="deck_format">#{formats}</select><p class="c-field__hint">The format sets the deck's zones.</p></div>)
    actions = %(<div class="c-form__actions"><input type="submit" class="c-btn c-btn--primary" value="Create deck"><a class="c-btn c-btn--secondary" href="#">Cancel</a></div>)
    %(<div id="probe"><div class="c-pagehead"><div><h1 class="c-pagehead__title">New deck</h1></div></div><form class="c-form">#{field}#{format}#{actions}</form></div>)
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

  describe "DeckShape card types (AC-2.5)" do
    def types_panel = add_to_main(wrap(320, panel_html(types: types_html([ [ "Lands", 22, 2 ], [ "Artifacts", 4, 0 ] ]))))

    # Per row: the name's left and the suffix's right edge against the row's, the count's right edge, the texts.
    def measured_rows
      evaluate(<<~JS)
        return [ ...document.querySelectorAll("#probe .c-types li") ].map((li) => {
          const [ name, count, suffix ] = li.children, row = li.getBoundingClientRect()
          return { nameLeft: name.getBoundingClientRect().left - row.left, suffixRight: row.right - suffix.getBoundingClientRect().right,
                   countRight: count.getBoundingClientRect().right, texts: [ count.textContent, suffix.textContent ] }
        })
      JS
    end

    it "puts the name first, the count and the proxy suffix last, and lines the counts up", :aggregate_failures do
      types_panel
      lands, artifacts = measured_rows
      expect([ lands["nameLeft"], artifacts["nameLeft"] ]).to eq([ 0, 0 ])
      expect([ lands["suffixRight"], artifacts["suffixRight"] ]).to all(be_within(0.5).of(0))
      expect(artifacts["countRight"]).to be_within(1).of(lands["countRight"])
      expect([ lands["texts"], artifacts["texts"] ]).to eq([ [ "24", "2 proxy" ], [ "4", "" ] ])
    end

    it "divides rows by line and sets the count in the mono family", :aggregate_failures do
      types_panel
      expect(computed("#probe .c-types li", "border-bottom-color")).to eq([ token("--line") ])
      expect(computed("#probe .c-types__n", "font-family").first).to include(mono_family)
    end
  end

  describe "DeckShape mana bar (AC-2.6, AC-2.7)" do
    def bar_panel(counts, width: 288) = add_to_main(wrap(width, panel_html(mana: manabar_html(counts))))

    # The bar's inner width and, per segment, its content width (border-box less the divider), left border and text.
    def measured_bar
      evaluate(<<~JS)
        const bar = document.querySelector("#probe .c-manabar"), box = bar.getBoundingClientRect()
        const inner = box.width - 2 * parseFloat(getComputedStyle(bar).borderLeftWidth)
        const segs = [ ...bar.children ].map((li) => {
          const left = parseFloat(getComputedStyle(li).borderLeftWidth)
          return { width: li.getBoundingClientRect().width - left, text: li.textContent.trim(), display: getComputedStyle(li.firstElementChild).display }
        })
        return { inner, segs }
      JS
    end

    def bar_outline = computed("#probe .c-manabar", "border-top-width", "border-top-style", "border-top-color", "border-top-left-radius")

    def divider = computed("#probe .c-manabar__seg + .c-manabar__seg", "border-left-width", "border-left-style", "border-left-color")

    %w[light dark].each do |name|
      it "splits the bar by count, outlines it and fills each segment from its mana token in the #{name} theme", :aggregate_failures do
        bar_panel({ "U" => 44, "R" => 16 })
        theme(name)
        found = measured_bar
        expect(found["segs"].map { it["width"] }).to match([ be_within(1).of(found["inner"] * 44 / 60), be_within(1).of(found["inner"] * 16 / 60) ])
        expect([ bar_outline, divider ]).to eq([ [ "1px", "solid", token("--line-strong"), "4px" ], [ "1px", "solid", token("--line-strong") ] ])
        expect(found["segs"].map { it["text"] }).to eq([ "U 44", "R 16" ])
        expect(segment_paints).to eq([ [ token("--mana-u"), token("--on-mana-u") ], [ token("--mana-r"), token("--on-mana-r") ] ])
      end
    end

    def segment_paints = %w[u r].map { |sym| computed("#probe .c-manabar__seg--#{sym}", "background-color", "color") }

    it "hides the label of a segment under 10% and names every colour in the caption", :aggregate_failures do
      bar_panel({ "W" => 3, "U" => 20, "B" => 4, "R" => 18, "G" => 15 })
      expect(measured_bar["segs"].map { it["display"] == "none" }).to eq([ true, false, true, false, false ])
      expect(evaluate('return document.querySelector("#probe .c-manacap").textContent'))
        .to include("White 3 · 5%", "Blue 20 · 33%", "Black 4 · 7%", "Red 18 · 30%", "Green 15 · 25%")
    end
  end

  describe "DeckPage layout (AC-3.2 to AC-3.4, AC-3.12)" do
    def deck_at(width, **) = add_to_main(wrap(width, deck_html(**)))

    # Whether the element's parent, the width-setting wrapper, scrolls sideways.
    def parent_scrolls?(selector) = evaluate("const el = document.querySelector(#{selector.to_json}).parentElement; return el.scrollWidth > el.clientWidth")

    def shape_display = [ computed("#probe > .c-shapefold", "display"), computed("#probe > .c-deck__shape", "display") ].flatten

    def fold_open? = evaluate('return document.querySelector("#probe .c-shapefold").open')

    it "sets the zones left of a 320px sticky panel, 32px apart, from 992px (AC-3.2)", :aggregate_failures do
      deck_at(1100)
      zones, shape = box("#probe .c-deck__zones"), box("#probe .c-deck__shape")
      expect(zones["left"]).to be < shape["left"]
      expect(shape["width"]).to eq(320)
      expect(shape["left"] - zones["right"]).to be_within(0.5).of(32)
      expect(computed("#probe .c-deck__shape", "position", "top")).to eq(%w[sticky 80px])
      expect(shape_display).to eq(%w[none block])
    end

    [ 991, 700 ].each do |width|
      it "stacks the open panel above the zones, as wide as them, with no summary at #{width}px (AC-3.3)", :aggregate_failures do
        deck_at(width)
        zones, shape = box("#probe .c-deck__zones"), box("#probe .c-deck__shape")
        expect(shape["bottom"]).to be <= zones["top"]
        expect(shape["width"]).to be_within(0.5).of(zones["width"])
        expect(computed("#probe .c-deck__shape", "position")).to eq([ "static" ])
        expect(shape_display).to eq(%w[none block])
        expect(evaluate('return document.querySelector("#probe .c-deck__shape summary")')).to be_nil
      end
    end

    it "shows a closed details above the zones below 640px, opened from the keyboard (AC-3.4)", :aggregate_failures do
      deck_at(639)
      fold, zones = box("#probe .c-shapefold"), box("#probe .c-deck__zones")
      expect(shape_display).to eq(%w[block none])
      expect([ fold_open?, fold["bottom"] <= zones["top"], box("#probe .c-shapefold > summary")["height"] ]).to match([ false, true, be >= 44 ])
      expect(evaluate('return document.querySelector("#probe .c-shapefold > summary").textContent')).to include("Deck shape", "average mana value")
      find("#probe .c-shapefold > summary").send_keys(:enter)
      expect(fold_open?).to be(true)
      find("#probe .c-shapefold > summary").send_keys(:enter)
      expect(fold_open?).to be(false)
      expect(parent_scrolls?("#probe")).to be(false)
    end

    it "shows the aside and not the details at 640px (AC-3.4)" do
      deck_at(640)
      expect(shape_display).to eq(%w[none block])
    end

    it "keeps the zones in the first column when there is no panel (AC-3.12)", :aggregate_failures do
      deck_at(1100, panel: false)
      wrapper = evaluate('const r = document.querySelector("#probe").parentElement.getBoundingClientRect(); return { left: r.left, width: r.width }')
      zones = box("#probe .c-deck__zones")
      expect([ zones["left"], zones["width"] ]).to eq([ wrapper["left"], wrapper["width"] - 352 ])
      expect(evaluate('return document.querySelectorAll("#probe .c-shapefold, #probe .c-deck__shape").length')).to eq(0)
    end

    it "lets the zones span the wrapper below 992px when there is no panel (AC-3.12)" do
      deck_at(700, panel: false)
      expect(box("#probe .c-deck__zones")["width"]).to eq(700)
    end
  end

  describe "DeckPage zone tables (AC-3.5, AC-3.6, AC-3.8, AC-3.11, cost and name)" do
    def long_name = "Abcdefghij" * 6

    def zone_at(width, rows = zone_rows, container: "collection") = add_to_main(wrap(width, zone_html("Main", rows, id: "probe"), container:))

    def row_script(name) = %(const row = [ ...document.querySelectorAll("#probe tbody tr") ].find((tr) => tr.querySelector("a")?.textContent === #{name.to_json}))

    # The nth cell (1-based) of the row whose link reads `name`: its edges, whether it scrolls, and how it is set.
    def cell(name, number)
      evaluate(<<~JS)
        #{row_script(name)}
        const td = row.children[#{number - 1}], rect = td.getBoundingClientRect(), style = getComputedStyle(td)
        return { left: rect.left, right: rect.right, scrolls: td.scrollWidth > td.clientWidth, display: style.display, align: style.textAlign,
                 font: style.fontFamily, text: td.textContent.trim(), proxies: td.querySelectorAll(".c-proxy").length }
      JS
    end

    # The height, width and right edge of the row's cost, and the link's right edge.
    def cost_of(name)
      evaluate(<<~JS)
        #{row_script(name)}
        const cost = row.querySelector(".c-cost").getBoundingClientRect()
        return { height: cost.height, width: cost.width, link: row.querySelector("a").getBoundingClientRect().right }
      JS
    end

    # Each legality marker in the row: its word, whether it is drawn, the tag before it and its colour.
    def markers_of(name)
      evaluate(<<~JS)
        #{row_script(name)}
        return [ ...row.querySelectorAll(".c-legal") ].map((m) => ({ text: m.textContent.trim(), shown: m.getClientRects().length > 0,
          after: m.previousElementSibling?.tagName, color: getComputedStyle(m).color }))
      JS
    end

    def wrapper_scrolls? = evaluate('const el = document.querySelector("#probe").parentElement; return el.scrollWidth > el.clientWidth')

    def group_cell
      evaluate(<<~JS)
        const th = document.querySelector("#probe .c-zone__group th"), style = getComputedStyle(th)
        return { colspan: th.colSpan, text: th.textContent.trim(), position: style.position, background: style.backgroundColor }
      JS
    end

    it "reads six columns and sets group rows on a sunken, unstuck ground at 700px (AC-3.5)", :aggregate_failures do
      zone_at(700)
      expect(evaluate('return [ ...document.querySelectorAll("#probe thead th") ].map((th) => th.textContent.trim())')).to eq(%w[Card Cost Owned Proxy Total Actions])
      group = group_cell
      expect(group.values_at("colspan", "position", "background")).to eq([ 6, "static", token("--surface-sunken") ])
      expect(group["text"]).to match(/\ACreatures\s*12\z/)
    end

    it "shows the tag where a row has proxies and a dash where not, right-aligned in mono (AC-3.5)", :aggregate_failures do
      zone_at(700)
      expect([ cell("Murktide Regent", 4)["proxies"], cell("Dragon's Rage Channeler", 4) ]).to match([ 1, include("proxies" => 0, "text" => "–") ])
      numbers = [ 3, 4, 5 ].map { cell("Dragon's Rage Channeler", it) }
      expect(numbers.map { it["align"] }).to all(eq("right"))
      expect(numbers.map { it["font"] }).to all(include(mono_family))
    end

    it "folds Owned and Proxy into the Card cell's line at 360px, keeping Cost and Total (AC-3.6)", :aggregate_failures do
      zone_at(360)
      expect([ 3, 4 ].map { cell("Murktide Regent", it)["display"] }).to eq(%w[none none])
      expect([ 2, 5 ].map { cell("Murktide Regent", it)["display"] }).to eq(%w[table-cell table-cell])
      sub = evaluate(%(#{row_script("Murktide Regent")}; const sub = row.querySelector(".c-table__sub"); return [ getComputedStyle(sub).display, sub.textContent, sub.querySelectorAll(".c-proxy").length ]))
      expect(sub).to match([ "block", include("MH2 · 52"), 1 ])
    end

    it "fits a worst-case row, a 60-character name and a six-symbol cost, in 360px (AC-3.6)", :aggregate_failures do
      zone_at(360, zone_rows + [ zrow(long_name, cost: %w[2 W U B R G]) ])
      expect(wrapper_scrolls?).to be(false)
      expect(cell(long_name, 2)["scrolls"]).to be(false)
    end

    it "keeps a six-symbol cost on one line in Cost and wraps an eight-symbol one (spec 1.0.1)", :aggregate_failures do
      zone_at(640, zone_rows + [ zrow("Six", cost: %w[2 W U B R G]), zrow("Eight", cost: %w[2 W U B R G 1 X]) ])
      six, eight = cost_of("Six"), cost_of("Eight")
      expect([ six["height"], six["width"] ]).to match([ be_within(1).of(22), be_within(1).of(142) ])
      expect(eight["height"]).to be > 22
      expect([ cell("Six", 2)["scrolls"], cell("Eight", 2)["scrolls"] ]).to eq([ false, false ])
    end

    it "wraps a 60-character name inside the Card cell at 640px (spec 1.0.2)", :aggregate_failures do
      zone_at(640, zone_rows + [ zrow(long_name) ])
      expect([ cell(long_name, 1)["scrolls"], wrapper_scrolls? ]).to eq([ false, false ])
      expect(cost_of(long_name)["link"]).to be <= cell(long_name, 2)["left"]
    end

    [ 700, 360 ].each do |width|
      it "marks a banned card after its name and no legal one, in muted ink, at #{width}px (AC-3.8)", :aggregate_failures do
        zone_at(width)
        markers = [ markers_of("Ragavan, Nimble Pilferer"), markers_of("Counterspell") ]
        expect(markers.last).to eq([])
        expect(markers.first).to eq([ { "text" => "Banned", "shown" => true, "after" => "A", "color" => token("--ink-muted") } ])
      end
    end
  end

  describe "DeckPage zone tables across zones (AC-3.11)" do
    def three_zones
      add_to_main(wrap(900, three_zone_html, container: "collection"))
    end

    def three_zone_html
      zone_html("Main", zone_rows, id: "zone-1") +
        zone_html("Sideboard", [ zrow("Mystical Dispute", group: "Instants", cost: %w[2 U], owned: 2), zrow(Array.new(30, "ab").join, owned: 1, proxy: 1) ], id: "zone-2") +
        zone_html("Considering", [ zrow("Opt", group: "Instants", cost: %w[U]), zrow("Island", group: "Lands", cost: nil) ], id: "zone-3")
    end

    # Per header cell of a zone's table: its left and right edge relative to the table's left, and its width.
    def columns_of(zone)
      evaluate(<<~JS)
        const table = document.querySelector("##{zone} table"), base = table.getBoundingClientRect().left
        return [ ...table.querySelectorAll("thead th") ].map((th) => { const r = th.getBoundingClientRect(); return { left: r.left - base, right: r.right - base, width: r.width } })
      JS
    end

    def all_columns = %w[zone-1 zone-2 zone-3].map { columns_of(it) }

    # The column positions the three tables must share, read by `key` over the columns at `indexes`.
    def shared(key, indexes) = all_columns.map { |columns| indexes.map { columns[it][key] } }

    it "gives Cost, Owned, Proxy, Total and the menu one position and width in every zone at 900px", :aggregate_failures do
      three_zones
      expect(shared("left", 1..5).uniq.size).to eq(1)
      expect(shared("width", 1..5)).to all(match([ 176, 80, 112, 80, 64 ].map { be_within(0.5).of(it) }))
    end

    it "lines up the right edges of Cost, Total and the menu in every zone at 360px", :aggregate_failures do
      add_to_main(wrap(360, three_zone_html, container: "collection"))
      edges = shared("right", [ 1, 4, 5 ])
      expect(edges.transpose.map { |column| column.max - column.min }).to all(be <= 1)
      expect(shared("width", [ 4, 5 ]).transpose.map { |column| column.max - column.min }).to all(be <= 1)
    end
  end

  describe "DeckPage zone heads and empty zones (AC-3.7, AC-3.9)" do
    def head_at(width, rows = zone_rows, title: "Main") = add_to_main(wrap(width, zone_html(title, rows, id: "probe")))

    def head_boxes = %w[.c-section__title .c-section__count .c-section__actions\ .c-btn].map { box("#probe #{it}") }

    def counts_scroll? = evaluate('const el = document.querySelector("#probe .c-section__count"); return el.scrollWidth > el.clientWidth')

    it "puts the counts on their own line below 640px, uncut, with Add a proxy beside the title (AC-3.7)", :aggregate_failures do
      head_at(600)
      title, counts, add = head_boxes
      expect(counts["top"]).to be >= title["bottom"]
      expect(add["top"]).to be < title["bottom"]
      expect(counts_scroll?).to be(false)
    end

    it "keeps the head on one line from 640px (AC-3.7)", :aggregate_failures do
      head_at(700)
      title, counts, add = head_boxes
      expect([ counts["top"], add["top"] ]).to all(be < title["bottom"])
    end

    it "shows an empty zone as its head and a sunken sentence, with no table (AC-3.9)", :aggregate_failures do
      head_at(700, [], title: "Sideboard")
      expect(evaluate('return document.querySelector("#probe .c-section__count").textContent')).to eq("0 cards · 0 owned · 0 proxy")
      expect(evaluate('return document.querySelector("#probe table")')).to be_nil
      expect(computed("#probe .c-zone__empty", "background-color")).to eq([ token("--surface-sunken") ])
      expect(evaluate('return document.querySelector("#probe .c-zone__empty").textContent')).to eq("No cards in Sideboard yet.")
    end
  end

  describe "DecksIndex table (AC-4.2, AC-4.3)" do
    def decks_at(width) = add_to_main(wrap(width, decks_html(deck_list + [ [ "Abcdefghij" * 6, "Legacy", 12, 3 ] ])))

    def row_cells(name)
      evaluate(<<~JS)
        const row = [ ...document.querySelectorAll("#probe tbody tr") ].find((tr) => tr.querySelector("a").textContent === #{name.to_json})
        return [ ...row.children ].map((td) => { const style = getComputedStyle(td)
          return { display: style.display, align: style.textAlign, font: style.fontFamily, text: td.textContent.trim(), tags: td.querySelectorAll(".c-proxy").length } })
      JS
    end

    def overflow
      evaluate(<<~JS)
        const scrolls = (el) => el.scrollWidth > el.clientWidth
        return [ scrolls(document.querySelector("#probe").parentElement), scrolls(document.querySelector("#probe .c-collection")) ]
      JS
    end

    it "reads Deck, Format, Cards, Owned and Proxy, the numbers right-aligned in mono, at 700px (AC-4.2)", :aggregate_failures do
      decks_at(700)
      expect(evaluate('return [ ...document.querySelectorAll("#probe thead th") ].map((th) => th.textContent.trim())')).to eq(%w[Deck Format Cards Owned Proxy])
      cells = row_cells("Izzet Tempo")
      expect(cells.values_at(2, 3, 4).map { it["align"] }).to all(eq("right"))
      expect(cells.values_at(2, 3, 4).map { it["font"] }).to all(include(mono_family))
    end

    it "shows the tag where a deck has proxies and a dash where not (AC-4.2)", :aggregate_failures do
      decks_at(700)
      expect(row_cells("Izzet Tempo")[4].values_at("tags", "text")).to eq([ 1, "Proxy 11" ])
      expect(row_cells("Mono Red Burn")[4].values_at("tags", "text")).to eq([ 0, "–" ])
    end

    it "hides Format, Owned and Proxy at 360px and folds them into the Deck cell, Cards staying (AC-4.3)", :aggregate_failures do
      decks_at(360)
      cells = row_cells("Izzet Tempo")
      expect(cells.map { it["display"] }).to eq(%w[table-cell none table-cell none none])
      expect(cells.first["text"]).to match(/Modern · 58 owned\s*·\s*Proxy\s+11/)
      expect([ cells.first["tags"], cells[2]["text"] ]).to eq([ 1, "69" ])
    end

    it "has no sideways overflow at 360px with a 60-character deck name (AC-4.3)" do
      decks_at(360)
      expect(overflow).to eq([ false, false ])
    end
  end

  describe "DecksIndex page head and New deck page (AC-4.4, AC-4.5)" do
    def head_state
      evaluate(<<~JS)
        const actions = getComputedStyle(document.querySelector("#probe .c-pagehead__actions")), button = document.querySelector("#probe .c-btn--primary")
        const shown = button.getClientRects().length > 0 && getComputedStyle(button).display !== "none"
        return { actions: actions.display, shown, height: button.getBoundingClientRect().height,
                 fits: document.documentElement.scrollWidth <= window.innerWidth }
      JS
    end

    def phone_head(**)
      open_in_narrow_frame(locations_path, width: 360, ready: ".c-pagehead")
      within_narrow_frame do
        blank_host
        add_to_main(decks_html(**))
        head_state
      end
    end

    it "keeps a primary New deck button, at least 36px high, in the head at 360px (AC-4.4)", :aggregate_failures do
      found = phone_head
      expect(found.values_at("actions", "shown", "fits")).to eq([ "flex", true, true ])
      expect(found["height"]).to be >= 36
    end

    it "hides the head's actions at 360px without `.c-decks`, so the rule is what shows them (control)" do
      expect(phone_head(scoped: false)["actions"]).to eq("none")
    end

    it "keeps the same button at 1280px (AC-4.4)", :aggregate_failures do
      page.current_window.resize_to(1280, 900)
      add_to_main(decks_html)
      found = head_state
      expect(found.values_at("actions", "shown", "fits")).to eq([ "flex", true, true ])
      expect(found["height"]).to be >= 36
    end

    it "keeps the New deck form at most 420px wide at 1280px (AC-4.5)" do
      page.current_window.resize_to(1280, 900)
      add_to_main(new_deck_html)
      expect(box("#probe .c-form")["width"]).to be <= 420
    end

    it "stacks the New deck fields at 360px with no overflow (AC-4.5)", :aggregate_failures do
      open_in_narrow_frame(locations_path, width: 360, ready: ".c-pagehead")
      within_narrow_frame do
        blank_host
        add_to_main(new_deck_html)
        first, second = box("#probe .c-field:nth-child(1)"), box("#probe .c-field:nth-child(2)")
        expect(second["top"]).to be >= first["bottom"]
        expect(evaluate("return document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      end
    end
  end
end
