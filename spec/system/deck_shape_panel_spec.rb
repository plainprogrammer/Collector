require "rails_helper"

# Spec 069 Stories 1 and 5: the shape panel on the deck page at 360, 640, 768 and 1280px in both themes, in headless Firefox.
# Phone widths use the narrow frame; headless Firefox has a fine pointer, so the 44px floor is read from the summary's box.
RSpec.describe "Deck shape panel", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "W" * 60) }

  def card(name:, type_line: "Creature — Elf", cost: "{2}{W}{U}{B}{R}{G}", mana_value: 7.0)
    entry = create(:catalog_entry, name:)
    create(:mtg_printing, entry:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    create(:mtg_card, identity: entry.identity, mana_value:)
    entry
  end

  # Every type (Creatures to Other), a five-colour hybrid-heavy cost, proxies, and a mana value of 1,000,000 (the average line's worst case).
  before do
    create_lot_in_zone(deck, "main", entry: card(name: "Worst"), quantity: 123)
    create(:deck_proxy, zone: deck.zone("main"), account:, entry: card(name: "Gleemax", cost: "{W/U}{U/B}{B/R}{R/G}{G/W}", mana_value: 1_000_000.0), quantity: 1234)
    create_lot_in_zone(deck, "main", entry: card(name: "Bolt", type_line: "Instant", cost: "{R}", mana_value: 1.0), quantity: 4)
    create_lot_in_zone(deck, "main", entry: card(name: "Island", type_line: "Basic Land — Island", cost: "", mana_value: 0.0), quantity: 20)
    { "Jace" => "Legendary Planeswalker — Jace", "Invasion of Zendikar" => "Battle — Siege", "Rite" => "Sorcery", "Sol Ring" => "Artifact",
      "Pacifism" => "Enchantment — Aura" }.each { |name, type_line| create_lot_in_zone(deck, "main", entry: card(name:, type_line:, cost: "{1}", mana_value: 1.0), quantity: 1) }
    create_lot_in_zone(deck, "main", entry: create(:mtg_printing, faces: []).entry, quantity: 1) # a printing with no face data: Other
  end

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def shown?(selector) = page.evaluate_script("(() => { const el = document.querySelector(#{selector.to_json}); return !!el && el.getClientRects().length > 0 })()")

  describe "the page container's widths (AC-1.3)" do
    [ 360, 640 ].each do |width|
      it "shows the details copy, closed, in a #{width}px frame (a container under 640px), and not the aside", :aggregate_failures do
        open_in_narrow_frame(deck_path(deck), width:, ready: "details.c-shapefold")
        within_narrow_frame do
          expect(shown?("details.c-shapefold")).to be(true)
          expect(shown?("aside.c-deck__shape")).to be(false)
          expect(page.evaluate_script('document.querySelector("details.c-shapefold").open')).to be(false)
          expect(page.evaluate_script('document.querySelector("details.c-shapefold summary").getBoundingClientRect().height')).to be >= 44
        end
    end
    end

    # The page container is the frame minus the page's 32px side padding from 640px, the body's 8px default margin on each side
    # and a 15px classic scrollbar, so 640px of container needs a frame of at least 640 + 64 + 16 + 15 = 735px, and a 640px frame
    # (container 545px) still shows the fold.
    [ 768, 1000 ].each do |width|
      it "shows the aside, open and not sticky, above the zones in a #{width}px frame (a container of 640px to 991px), and not the details copy", :aggregate_failures do
        open_in_narrow_frame(deck_path(deck), width:, ready: "aside.c-deck__shape")
        within_narrow_frame do
          expect(shown?("aside.c-deck__shape")).to be(true)
          expect(shown?("details.c-shapefold")).to be(false)
          expect(page.evaluate_script('getComputedStyle(document.querySelector("aside.c-deck__shape")).position')).not_to eq("sticky")
          above = page.evaluate_script('document.querySelector("aside.c-deck__shape").getBoundingClientRect().bottom <= document.querySelector(".c-deck__zones").getBoundingClientRect().top')
          expect(above).to be(true)
        end
      end
    end

    it "puts the 320px aside beside the zones, sticky, from 1280px", :aggregate_failures do
      visit deck_path(deck)
      page.driver.browser.manage.window.resize_to(1280, 900)
      expect(page).to have_css("aside.c-deck__shape")

      boxes = page.evaluate_script('(() => { const a = document.querySelector("aside.c-deck__shape"), z = document.querySelector(".c-deck__zones"); return { aside: a.getBoundingClientRect().width, left: a.getBoundingClientRect().left > z.getBoundingClientRect().left, sticky: getComputedStyle(a).position } })()')
      expect(boxes).to eq({ "aside" => 320, "left" => true, "sticky" => "sticky" })
      expect(shown?("details.c-shapefold")).to be(false)
    end
  end

  it "opens and closes the fold from the keyboard with no script, its summary ending in Show (AC-5.2)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 375, ready: "details.c-shapefold")
    within_narrow_frame do
      summary = find("details.c-shapefold summary")
      expect(page.evaluate_script('getComputedStyle(document.querySelector("details.c-shapefold summary"), "::after").content')).to include("Show")
      summary.send_keys(:enter)
      expect(page).to have_css("details.c-shapefold[open]")
      summary.send_keys(:space)
      expect(page).to have_no_css("details.c-shapefold[open]")
    end
  end

  [ 360, 640, 768, 1280 ].product(%w[light dark]).each do |width, theme|
    it "has no horizontal overflow at #{width}px in the #{theme} theme with every panel part full (AC-5.1)", :aggregate_failures do
      if width == 360 # a phone's viewport: a 360px frame lays out in about 345px, where the zone table's worst row spills (#318)
        expect(open_in_viewport_frame(deck_path(deck), viewport: 360, ready: ".c-deck__zones")).to eq(360)
      else
        open_in_narrow_frame(deck_path(deck), width:, ready: ".c-deck__zones")
      end
      within_narrow_frame do
        page.execute_script("document.documentElement.dataset.theme = #{theme.to_json}")
        page.execute_script('document.querySelector("details.c-shapefold").open = true')
        expect(page_fits_sideways?).to be(true)
      end
    end
  end

  # What the open fold's panel measures: its inside width, whether it scrolls sideways, how many elements are drawn past the padding
  # box's right edge, how many text elements are cut off at their own box, the curve's columns, and the least room a count has in
  # its column (the column's width minus the count's scrollWidth; negative is an overflow).
  def open_fold_fit
    page.evaluate_script(<<~'JS')
      (() => { const panel = document.querySelector("details.c-shapefold .c-shape"), box = panel.getBoundingClientRect()
        const right = box.right - parseFloat(getComputedStyle(panel).paddingRight)
        const room = [...panel.querySelectorAll(".c-curve__col")].map((col) => col.getBoundingClientRect().width - col.querySelector(".c-curve__count").scrollWidth)
        return { inside: Math.round(panel.clientWidth - 32), scrolls: panel.scrollWidth > panel.clientWidth,
          beyond: [...panel.querySelectorAll("*")].filter((el) => el.getClientRects().length && el.getBoundingClientRect().right > right + 0.5).length,
          clipped: [...panel.querySelectorAll(".c-curve__count, .c-types li > *, .c-curve__legend li, .c-curve__avg, .c-manacap")].filter((el) => el.scrollWidth > el.clientWidth + 1).length,
          cols: room.length, countRoom: Math.min(...room) } })()
    JS
  end

  # Opens the deck page in a frame whose viewport (the page's `documentElement.clientWidth`, the frame less its classic scrollbar) is
  # 360px, with the fold open, and returns that viewport's width so the example can assert it. The scrollbar's width depends on the
  # platform (15px on the Mac, about 12px on the Linux CI runner, found when CI measured an inside of 281px where the Mac measured
  # 278px), so the frame is sized from the measured scrollbar, `360 + scrollbar`, and never from a constant: it opens at 375px, the
  # Mac's answer, and reopens only when the scrollbar isn't 15px.
  def open_phone_frame
    width = 375
    2.times do
      open_in_narrow_frame(deck_path(deck), width:, ready: "details.c-shapefold")
      within_narrow_frame do
        page.execute_script('document.querySelector("details.c-shapefold").open = true')
        scrollbar = page.evaluate_script("window.innerWidth - document.documentElement.clientWidth")
        width = 360 + scrollbar
      end
      break if width == 375
    end
    within_narrow_frame { page.evaluate_script("document.documentElement.clientWidth") }
  end

  # A phone's 360px viewport has no scrollbar and the frame keeps a classic one, so the frame is 360px plus the measured scrollbar
  # (375px with the Mac's 15px). The chain is the viewport's 360px less the body's 16px (8px margin a side, a 344px body), the main's
  # 32px padding (a 312px container), the details' 2px border (310px) and the panel's 32px padding (a 278px inside). A frame with the
  # scrollbar inside a 360px width is 15px narrower (263px inside), where the fixture's count in full ("1,357") overflowed its column by
  # about 1.85px; spec 077 (#320) abbreviates it ("1.4k"), and the "extreme counts" examples below measure that frame and a 320px
  # viewport. Each check can fail: the panel scrolling sideways, an element drawn past the padding box's right edge, and a text element
  # cut off at its own box.
  it "fits the open fold's parts in the panel's interior at a real phone's 360px viewport, with nothing cut off and each count with room in its column (AC-5.3)", :aggregate_failures do
    expect(open_phone_frame).to eq(360)
    within_narrow_frame do
      fit = open_fold_fit
      expect(fit.except("countRoom")).to eq({ "inside" => 278, "scrolls" => false, "beyond" => 0, "clipped" => 0, "cols" => 7 })
      expect(fit["countRoom"]).to be >= 0, "the least room a count has in its column: #{fit['countRoom']}px"
    end
  end

  %w[light dark].each do |theme|
    it "draws owned solid ink-muted, proxy hatched, and the mana segments in their own tokens in the #{theme} theme (AC-2.10, AC-4.9)", :aggregate_failures do
      visit deck_path(deck)
      page.driver.browser.manage.window.resize_to(1280, 900)
      set_theme(theme)
      expect(page).to have_css("aside .c-curve__owned")

      paint = page.evaluate_script(<<~'JS')
        (() => { const token = (name) => { const p = document.createElement("span"); p.style.color = `var(${name})`; document.body.append(p); const c = getComputedStyle(p).color; p.remove(); return c }
          const owned = getComputedStyle(document.querySelector("aside .c-curve__owned")), proxy = getComputedStyle(document.querySelector("aside .c-curve__proxy"))
          const segments = [...document.querySelectorAll("aside .c-manabar__seg")].map((seg) => { const colour = seg.className.match(/seg--([wubrg])\b/)[1], style = getComputedStyle(seg)
            return style.backgroundColor === token(`--mana-${colour}`) && style.color === token(`--on-mana-${colour}`) })
          return { owned: owned.backgroundColor === token("--ink-muted"), proxyHatch: proxy.backgroundImage.includes("repeating-linear-gradient"),
                   noBrand: [owned, proxy].every((s) => s.backgroundColor !== token("--brand") && s.borderTopColor !== token("--brand")),
                   segments: segments.length, segmentsRight: segments.every(Boolean) } })()
      JS
      expect(paint).to eq({ "owned" => true, "proxyHatch" => true, "noBrand" => true, "segments" => 5, "segmentsRight" => true })
    end
  end

  # Spec 077 (#320): the panel at extreme counts at a 320px, 345px and 360px viewport (a real 320px phone, a 360px browser frame, a
  # 360px phone), a 366px frame (where the old caption leads a line with a dot), a 640px frame (the fold again) and the 320px aside at
  # 1280px, in both themes. The viewport frames are sized from the measured scrollbar (the viewport plus `innerWidth - clientWidth`: 15px
  # on a Mac, about 12px on the Linux runner) and read against `documentElement.clientWidth` (lessons of 2026-11-11 on phone widths and
  # measurement traps); the 366px and 640px frames are fixed frame widths by the spec's words, not viewports. Each geometry example has a
  # failing variant: the old text or the old rule injected into the page.
  # The file's memoized helpers (user, account, deck) plus the two lets below are at the cop's limit of five: another deck an example needs is
  # a local (`plain = create(:deck, …)`, as AC-3.2 does), not another `let`.
  describe "extreme counts (spec 077, #320)" do
    let(:rows_deck) { create(:deck, account:, name: "Rows") }
    let(:wide_deck) { create(:deck, account:, name: "Wide rows") }

    def plain_card(name:, type_line: "Creature — Elf") = card(name:, type_line:, cost: "{1}", mana_value: 2.0)
    def own_in(in_deck, entry, quantity) = create_lot_in_zone(in_deck, "main", entry:, quantity:)
    def proxy_in(in_deck, entry, quantity) = create(:deck_proxy, zone: in_deck.zone("main"), account:, entry:, quantity:)

    # AC-3.1's rows: "Creatures" 1,357 with "1,234 proxy", "Instants" 9,999 with "9,999 proxy", "Artifacts" 3 and "Lands" 20 with none.
    def build_rows
      own_in(rows_deck, plain_card(name: "Rows elf"), 123)
      proxy_in(rows_deck, plain_card(name: "Rows elf proxy"), 1_234)
      proxy_in(rows_deck, plain_card(name: "Rows bolt", type_line: "Instant"), 9_999)
      own_in(rows_deck, plain_card(name: "Rows ring", type_line: "Artifact"), 3)
      own_in(rows_deck, card(name: "Rows island", type_line: "Basic Land — Island", cost: "", mana_value: 0.0), 20)
    end

    # AC-3.1b's rows: "Planeswalkers" 12,345 with "12,345 proxy" (a proxy takes at most 9,999, so two) and "Lands" 20, a second row so that
    # "the counts end at one x" can fail.
    def build_wide_row
      proxy_in(wide_deck, plain_card(name: "Wide jace", type_line: "Legendary Planeswalker — Jace"), 9_999)
      proxy_in(wide_deck, plain_card(name: "Wide ajani", type_line: "Legendary Planeswalker — Ajani"), 2_346)
      own_in(wide_deck, card(name: "Wide island", type_line: "Basic Land — Island", cost: "", mana_value: 0.0), 20)
    end

    def widths = [ 320, 345, 360, :frame366, :frame640, :aside ]
    def fold_panel = "details.c-shapefold .c-shape"
    def open_fold = page.execute_script('document.querySelector("details.c-shapefold").open = true')
    def inject_css(rules) = page.execute_script("const style = document.createElement('style'); style.textContent = #{rules.to_json}; document.head.append(style)")

    # A frame whose viewport is `viewport` px wide with the fold open: the viewport plus the scrollbar the frame draws (measured, then
    # the frame is reopened if it was not 15px). Returns the viewport it got, for the example to assert.
    def open_fold_in_frame(path, viewport)
      width = viewport + 15
      2.times do
        open_in_narrow_frame(path, width:, ready: "details.c-shapefold")
        scrollbar = within_narrow_frame do
          open_fold
          page.evaluate_script("window.innerWidth - document.documentElement.clientWidth")
        end
        break if viewport + scrollbar == width

        width = viewport + scrollbar
      end
      within_narrow_frame { page.evaluate_script("document.documentElement.clientWidth") }
    end

    # Opens the deck page as `width` says (a viewport in px, a fixed frame, or :aside at 1280px) and yields the panel's selector, inside
    # the frame where there is one.
    def at_width(width, path)
      case width
      when Integer
        expect(open_fold_in_frame(path, width)).to eq(width)
        within_narrow_frame { yield fold_panel }
      when :frame366, :frame640
        open_in_narrow_frame(path, width: { frame366: 366, frame640: 640 }.fetch(width), ready: "details.c-shapefold")
        within_narrow_frame do
          open_fold
          yield fold_panel
        end
      when :aside
        visit path
        page.driver.browser.manage.window.resize_to(1280, 900)
        expect(page).to have_css("aside.c-deck__shape")
        yield "aside .c-shape"
      end
    end

    # What the panel measures: per curve column its room (the column's width less its count's scrollWidth), what is drawn past the
    # padding box, per visible mana label its line count, its text width, its segment's content width and whether the text's box is inside
    # its segment's box, the Card types rows' right edges, and per caption item its line count and the first character of every caption line.
    def measure(selector)
      page.evaluate_script(<<~JS)
        (() => { const panel = document.querySelector(#{selector.to_json}), edge = panel.getBoundingClientRect().right - parseFloat(getComputedStyle(panel).paddingRight)
          const textRange = (el) => { const r = document.createRange(); r.selectNodeContents(el); return r }
          const lines = (el) => new Set([...textRange(el).getClientRects()].map((q) => Math.round(q.top))).size
          const cols = [...panel.querySelectorAll(".c-curve__col")], rows = [...panel.querySelectorAll(".c-types li")], list = panel.querySelector(".c-types")
          const labels = [...panel.querySelectorAll(".c-manabar__seg span")].filter((s) => s.getClientRects().length)
          const starts = new Map(), caption = panel.querySelector("p.c-manacap"), walker = document.createTreeWalker(caption, NodeFilter.SHOW_TEXT)
          for (let node = walker.nextNode(); node; node = walker.nextNode()) { for (let i = 0; i < node.length; i++) { const r = document.createRange(); r.setStart(node, i); r.setEnd(node, i + 1)
            const box = r.getClientRects()[0]; if (box && node.data[i] !== " " && !starts.has(Math.round(box.top))) starts.set(Math.round(box.top), node.data[i]) } }
          return { viewport: document.documentElement.clientWidth,
            columns: cols.length,
            narrowest: cols.length ? Math.min(...cols.map((col) => col.getBoundingClientRect().width)) : 0,
            scrolls: panel.scrollWidth > panel.clientWidth,
            beyond: [...panel.querySelectorAll("*")].filter((el) => el.getClientRects().length && el.getBoundingClientRect().right > edge + 0.5).length,
            clipped: [...panel.querySelectorAll(".c-curve__count, .c-types li > *, .c-curve__legend li, .c-curve__avg, .c-manacap")].filter((el) => el.scrollWidth > el.clientWidth + 1).length,
            countRoom: cols.length ? Math.min(...cols.map((col) => col.getBoundingClientRect().width - col.querySelector(".c-curve__count").scrollWidth)) : 0,
            labels: labels.map((s) => { const box = textRange(s).getBoundingClientRect(), seg = s.parentElement.getBoundingClientRect()
              return { lines: lines(s), text: box.width, room: s.parentElement.clientWidth, inside: box.left >= seg.left - 0.5 && box.right <= seg.right + 0.5 } }),
            rights: rows.map((li) => li.children[1].getBoundingClientRect().right),
            suffixGap: rows.map((li) => Math.abs(li.getBoundingClientRect().right - li.children[2].getBoundingClientRect().right)),
            suffixWidth: rows.map((li) => li.children[2].getBoundingClientRect().width),
            rowOver: rows.filter((li) => li.getBoundingClientRect().right > list.getBoundingClientRect().right + 0.5 || li.scrollWidth > li.clientWidth + 1).length,
            cut: rows.flatMap((li) => [...li.children]).filter((el) => el.scrollWidth > el.clientWidth + 1).length,
            itemLines: [...panel.querySelectorAll(".c-manacap__item")].map(lines),
            lineStarts: [...starts.values()] } })()
      JS
    end

    # A label fits when it is on one line and its text is within its segment's content width (spec AC-2.2). Margins at a 320px viewport,
    # where `clientWidth` is a whole 46px: 2.44px on a Mac (a 43.56px label) and 1.30px on the Linux runner (44.70px: its mono face is wider).
    # A page whose panel is not drawn measures nothing, so the seven columns and a column with a width are part of "fits".
    def counts_fit?(found)
      found["countRoom"] >= 0 && !found["scrolls"] && found["beyond"].zero? && found["clipped"].zero? && found["columns"] == 7 && found["narrowest"] > 0
    end
    def labels_fit?(found) = found["labels"].any? && found["labels"].all? { |label| label["lines"] == 1 && label["inside"] && label["text"] <= label["room"] }
    def counts_aligned?(found) = found["rights"].any? && found["rights"].min > 0 && (found["rights"].max - found["rights"].min) <= 0.5
    def types_tidy?(found) = counts_aligned?(found) && found["suffixGap"].all? { it <= 0.5 } && found["rowOver"].zero? && found["cut"].zero?
    def wide_row_tidy?(found) = found["rowOver"].zero? && found["cut"].zero? && counts_aligned?(found) && found["rights"].size == 2
    def floor_held?(found) = counts_aligned?(found) && found["suffixWidth"].all? { it >= 71.5 }
    def caption_whole?(found) = found["itemLines"].any? && found["itemLines"].all?(1) && found["lineStarts"].none?("·")

    # Measures in each theme (layout cannot depend on it, so there is no wait for the 0.12s colour transition here; the second reading is a
    # guard) and expects the block to hold.
    def expect_in_both_themes(width, selector)
      %w[light dark].each do |theme|
        set_theme(theme)
        found = measure(selector)
        expect(yield(found)).to be(true), "at #{width} in #{theme}: #{found.inspect}"
      end
    end

    it "keeps every curve count inside its column and the panel inside its box at every width, in both themes (AC-1.3)", :aggregate_failures do
      widths.each { |width| at_width(width, deck_path(deck)) { |panel| expect_in_both_themes(width, panel) { counts_fit?(it) } } }
    end

    it "can fail: the full count in the 6+ column overflows its column at a 320px and a 345px viewport (AC-1.3)", :aggregate_failures do
      [ 320, 345 ].each do |viewport|
        at_width(viewport, deck_path(deck)) do |panel|
          page.execute_script('document.querySelector("details.c-shapefold .c-curve__col:last-child .c-curve__count").textContent = "1,357"')
          expect(counts_fit?(measure(panel))).to be(false), "at #{viewport}"
        end
      end
    end

    it "keeps every mana label on one line inside its segment at every width, in both themes (AC-2.2)", :aggregate_failures do
      widths.each { |width| at_width(width, deck_path(deck)) { |panel| expect_in_both_themes(width, panel) { labels_fit?(it) } } }
    end

    it "can fail: a label written in full wraps inside its segment at a 320px viewport (AC-2.2)" do
      at_width(320, deck_path(deck)) do |panel|
        page.execute_script('document.querySelectorAll("details.c-shapefold .c-manabar__seg span").forEach((span) => { span.textContent = span.textContent.replace("2.6k", "2,591") })')
        expect(labels_fit?(measure(panel))).to be(false)
      end
    end

    it "ends every Card types count at one x with the suffix at the row's edge, nothing cut off, at every width (AC-3.1)", :aggregate_failures do
      build_rows
      widths.each { |width| at_width(width, deck_path(rows_deck)) { |panel| expect_in_both_themes(width, panel) { types_tidy?(it) } } }
    end

    it "can fail: flex rows with a 4.5rem suffix put the 9,999 proxy row's count left of the others' (AC-3.1)", :aggregate_failures do
      build_rows
      at_width(320, deck_path(rows_deck)) do |panel|
        inject_css(".c-types{display:block !important} .c-types li{display:flex !important;gap:var(--space-2)} .c-types__n{margin-left:auto !important}")
        found = measure(panel)
        expect(types_tidy?(found)).to be(false)
        expect(found["rights"].max - found["rights"].min).to be > 5
      end
    end

    it "keeps each empty suffix cell at its 4.5rem floor and the counts at one x when no row has a proxy (AC-3.2)", :aggregate_failures do
      plain = create(:deck, account:, name: "Plain")
      own_in(plain, plain_card(name: "Plain elf"), 5)
      own_in(plain, plain_card(name: "Plain ring", type_line: "Artifact"), 3)
      [ 360, :aside ].each { |width| at_width(width, deck_path(plain)) { |panel| expect_in_both_themes(width, panel) { floor_held?(it) } } }
    end

    it "can fail: without the floor the empty suffix cells collapse (AC-3.2)" do
      plain = create(:deck, account:, name: "Plain")
      own_in(plain, plain_card(name: "Plain elf"), 5)
      at_width(360, deck_path(plain)) do |panel|
        inject_css(".c-types__proxy{min-width:0 !important}")
        expect(floor_held?(measure(panel))).to be(false)
      end
    end

    it "keeps a five-digit row inside the list with the counts at one x at a 320px viewport, the name wrapping (AC-3.1b)" do
      build_wide_row
      at_width(320, deck_path(wide_deck)) { |panel| expect_in_both_themes(320, panel) { wide_row_tidy?(it) } }
    end

    it "can fail: without the name cell's wrap rule the name spills over its cell (AC-3.1b)" do
      build_wide_row
      at_width(320, deck_path(wide_deck)) do |panel|
        inject_css(".c-types li > :first-child{overflow-wrap:normal !important}")
        expect(wide_row_tidy?(measure(panel))).to be(false)
      end
    end

    it "keeps every caption item on one line and no caption line starting with a dot at every width (AC-4.3)", :aggregate_failures do
      widths.each { |width| at_width(width, deck_path(deck)) { |panel| expect_in_both_themes(width, panel) { caption_whole?(it) } } }
    end

    it "can fail: without the nowrap rule an item splits at a 345px and a 360px viewport and a line starts with a dot in a 366px frame (AC-4.3)", :aggregate_failures do
      [ 345, 360, :frame366 ].each do |width|
        at_width(width, deck_path(deck)) do |panel|
          inject_css(".c-manacap__item{white-space:normal !important}")
          found = measure(panel)
          expect(caption_whole?(found)).to be(false), "at #{width}: #{found.inspect}"
          expect(found["lineStarts"]).to include("·") if width == :frame366
          expect(found["itemLines"].any? { it > 1 }).to be(true), "at #{width}: no item spans two lines: #{found.inspect}" if width.is_a?(Integer)
        end
      end
    end
  end
end
