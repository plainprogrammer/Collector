require "rails_helper"

# Spec 066 Story 5, spec 068 AC-2.4, AC-2.5 and AC-2.11: the deck page at 360, 640, 768 and 1280px in both themes, in headless
# Firefox. Phone widths use the narrow frame (a window can't go below 500px), whose page is a same-origin iframe. Two kinds of
# 360px are in this file: the overflow and zone-head examples open a true 360px viewport (open_deck_page_at, #318), the structure
# examples (headers, wrapping, button heights) a 360px frame, which lays out in about 345px with its classic scrollbar.
RSpec.describe "Deck page", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:long_name) { "W" * 60 }
  let(:other_deck) { create(:deck, account:, name: "Other deck", pair: "other/standard") }

  def printing(name:, type_line: "Creature", cost: "{2}{W}{U}{B}{R}{G}", legalities: { "modern" => "banned" }, **attrs)
    entry = create(:catalog_entry, name:, **attrs)
    create(:mtg_printing, entry:, legalities:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    entry
  end

  # The worst case (a 60-character name with no space, a six-symbol cost, a marker, a three-digit quantity and a four-digit
  # proxy count: AC-2.11), a short row, a land, and cards in Sideboard and Considering so three zone tables differ in content.
  before do
    worst = printing(name: long_name)
    create_lot_in_zone(deck, "main", entry: worst, quantity: 123)
    create(:deck_proxy, zone: deck.zone("main"), account:, entry: worst, finish: "nonfoil", quantity: 1234)
    create_lot_in_zone(deck, "main", entry: printing(name: "Lightning Bolt", type_line: "Instant", cost: "{R}", legalities: { "modern" => "legal" }), quantity: 4)
    create_lot_in_zone(deck, "main", entry: printing(name: "Island", type_line: "Basic Land — Island", cost: "", legalities: { "modern" => "legal" }), quantity: 20)
    create_lot_in_zone(deck, "sideboard", entry: printing(name: "Spell Pierce", type_line: "Instant", cost: "{U}", legalities: { "modern" => "not_legal" }), quantity: 2)
    create_lot_in_zone(deck, "considering", entry: printing(name: "Force of Will", type_line: "Instant", cost: "{3}{U}{U}", legalities: { "modern" => "legal" }), quantity: 1)
  end

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")

  def shown_headers
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".c-zone thead th")].filter((th) => th.getClientRects().length > 0).slice(0, 6).map((th) => th.textContent.trim())
    JS
  end

  # What the 60-character card's row shows: the marker and the set line under the name (`.c-table__sub`) and beside it (`.is-opt`),
  # and how many markers show in all.
  def long_row_shown
    page.evaluate_script(<<~JS)
      (() => { const row = [...document.querySelectorAll(".c-zone tbody tr")].find((tr) => tr.textContent.includes("W".repeat(60)))
        const shown = (el) => el.getClientRects().length > 0
        return { sub: shown(row.querySelector(".c-table__sub .c-legal")), beside: shown(row.querySelector(".is-opt .c-legal")),
                 subSet: shown(row.querySelector(".c-table__sub .c-zone__set")), besideSet: shown(row.querySelector(".is-opt .c-zone__set")),
                 markers: [...row.querySelectorAll(".c-legal")].filter(shown).length } })()
    JS
  end

  # Each zone head's count: cut off, and whether it sits below the name.
  def zone_head_counts
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".c-zone .c-section__head")].map((head) => {
        const count = head.querySelector(".c-section__count"), title = head.querySelector(".c-section__title")
        return { cut: count.scrollWidth > count.clientWidth, below: count.getBoundingClientRect().top >= title.getBoundingClientRect().bottom }
      })
    JS
  end

  # The left edge and width of each column's header in each zone table.
  def column_boxes
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".c-zone table")].map((table) =>
        [...table.querySelectorAll("thead th")].map((th) => { const box = th.getBoundingClientRect(); return [Math.round(box.left * 10) / 10, Math.round(box.width * 10) / 10] }))
    JS
  end

  # 360px is a phone's viewport (spec 074 measured the worst case there: the document does not scroll sideways), so its frame is
  # sized from the measured scrollbar. A "360px" narrow frame lays out in about 345px, where the worst-case row's table spills
  # 7 to 10px past the page, by platform (#318: the old checks compared with innerWidth and could not see it). The wider widths are frames.
  def open_deck_page_at(width)
    ready = ".c-zone:first-of-type table"
    return open_in_narrow_frame(deck_path(deck), width:, ready:) unless width == 360

    expect(open_in_viewport_frame(deck_path(deck), viewport: 360, ready:)).to eq(360)
  end

  [ 360, 640, 768, 1280 ].each do |width|
    %w[light dark].each do |theme|
      it "has no horizontal overflow at #{width}px in the #{theme} theme and keeps a six-symbol cost inside its cell (AC-5.4, AC-5.5)", :aggregate_failures do
        open_deck_page_at(width)
        within_narrow_frame do
          set_theme(theme)
          expect(page_fits_sideways?).to be(true)
          worst = page.evaluate_script(<<~JS)
            (() => { const cost = [...document.querySelectorAll(".c-zone td:nth-child(2)")].find((td) => td.querySelectorAll(".c-mana").length === 6)
              return [cost.scrollWidth, cost.clientWidth] })()
          JS
          expect(worst.first).to be <= worst.last
        end
      end
    end
  end

  # Measured: the zone table's container is under 640px in a 640px frame (the page's padding), so the head's count is on its own
  # line, as at 360px, and from 768px it sits beside the name. At every width it is uncut.
  [ 360, 640, 768, 1280 ].each do |width|
    it "keeps each zone head's count uncut at #{width}px and on its own line below the name while the table is narrow (AC-5.5)", :aggregate_failures do
      open_in_narrow_frame(deck_path(deck), width:, ready: ".c-zone:first-of-type table")
      within_narrow_frame do
        heads = zone_head_counts
        expect(heads.size).to eq(3)
        expect(heads).to all(eq({ "cut" => false, "below" => width <= 640 }))
      end
    end

    it "shows the marker once in the card's row at #{width}px (AC-3.6)" do
      open_in_narrow_frame(deck_path(deck), width:, ready: ".c-zone:first-of-type table")
      within_narrow_frame { expect(long_row_shown["markers"]).to eq(1) }
    end
  end

  it "shows Card, Cost and Total under 640px, with the set line and the marker under the name and Owned hidden (AC-5.3)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 360, ready: ".c-zone:first-of-type table")
    within_narrow_frame do
      expect(shown_headers.first(3)).to eq([ "Card", "Cost", "Total" ])
      expect(long_row_shown).to include("sub" => true, "beside" => false, "subSet" => true, "besideSet" => false)
    end
  end

  it "shows the marker and the set line beside the name from 768px and not under it, and all six columns (AC-3.6, AC-5.2; spec 068 AC-2.5)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 1280, ready: ".c-zone:first-of-type table")
    within_narrow_frame do
      expect(shown_headers).to eq([ "Card", "Cost", "Owned", "Proxy", "Total", "Actions" ])
      expect(long_row_shown).to include("sub" => false, "beside" => true, "subSet" => false, "besideSet" => true)
    end
  end

  it "gives Cost, Owned, Proxy, Total and the menu one left edge and width in every zone table from 640px (AC-5.2; spec 068 AC-2.5)", :aggregate_failures do
    visit deck_path(deck)
    page.driver.browser.manage.window.resize_to(1280, 900)
    expect(page).to have_css(".c-zone table", count: 3)

    boxes = column_boxes

    (1..5).each { |column| expect(boxes.map { it[column] }.uniq.size).to eq(1), "column #{column} differs between zone tables: #{boxes.map { it[column] }}" }
  end

  it "shows the proxy tag under the name and hides Owned and Proxy below 640px, keeping Cost, Total and the menu (AC-2.4)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 360, ready: ".c-zone:first-of-type table")
    within_narrow_frame do
      expect(shown_headers.first(4)).to eq([ "Card", "Cost", "Total", "Actions" ]) # the next zone's table follows
      shown = page.evaluate_script(<<~JS)
        (() => { const row = [...document.querySelectorAll(".c-zone tbody tr")].find((tr) => tr.textContent.includes("W".repeat(60)))
          const shown = (el) => el.getClientRects().length > 0
          return { sub: shown(row.querySelector(".c-table__sub .c-proxy")), proxyCell: shown(row.querySelectorAll("td")[3]), menu: shown(row.querySelector("td.c-table__actions summary")) } })()
      JS
      expect(shown).to eq({ "sub" => true, "proxyCell" => false, "menu" => true })
    end
  end

  it "shows the proxy tag in the Proxy column from 640px, with its four digits uncut, and not under the name (AC-2.5, AC-2.11)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 1280, ready: ".c-zone:first-of-type table")
    within_narrow_frame do
      cell = page.evaluate_script(<<~JS)
        (() => { const row = [...document.querySelectorAll(".c-zone tbody tr")].find((tr) => tr.textContent.includes("W".repeat(60)))
          const td = row.querySelectorAll("td")[3], tag = td.querySelector(".c-proxy")
          return { text: tag.textContent.replace(/\\s+/g, " ").trim(), cut: td.scrollWidth > td.clientWidth, sub: row.querySelector(".c-table__sub").getClientRects().length > 0 } })()
      JS
      expect(cell).to eq({ "text" => "Proxy 1,234", "cut" => false, "sub" => false })
    end
  end

  # The trigger's floor on a touch screen is the design system's rule for a small icon button (44px since spec 075, in
  # `additions.css`; `components.css` still writes 40px and loses by source order). Headless Firefox has a fine pointer, so the
  # rule is read from the stylesheet and the trigger is measured as it is drawn.
  it "gives the row menu's trigger the touch floor of a small icon button (AC-2.11)", :aggregate_failures do
    visit deck_path(deck)
    floor = page.evaluate_script(<<~JS)
      (() => { let found = null
        for (const sheet of document.styleSheets) if ((sheet.href || "").includes("additions"))
          for (const rule of sheet.cssRules)
            if (rule.media && rule.conditionText.includes("pointer: coarse")) for (const inner of rule.cssRules)
              if (inner.selectorText === ".c-btn--sm.c-btn--icon, .c-seg button") found = inner.style.minWidth
        return found })()
    JS
    trigger = page.evaluate_script(<<~JS)
      (() => { const box = document.querySelector(".c-zone td.c-table__actions summary").getBoundingClientRect(); const token = getComputedStyle(document.documentElement).getPropertyValue("--touch-floor"); return { size: [box.width, box.height], token: parseFloat(token) } })()
    JS
    expect(floor).to eq("var(--touch-floor)")
    expect(trigger["token"]).to be >= 44 # what the rule's token resolves to
    expect(trigger["size"]).to all(be >= 30) # a small button drawn for a fine pointer
  end

  # "Add a proxy" is a small ghost button, 28px with a mouse and 44px on a touch screen by the design system's rule (spec 075). The deck page's own rule lifts it to
  # the Decks pages' 44px at every pointer, so, as above, the rule is read from the stylesheet and the link measured as drawn.
  it "gives each zone's Add a proxy link the 44px touch floor (NFR Accessibility)", :aggregate_failures do
    visit deck_path(deck)
    rule = page.evaluate_script(<<~JS)
      (() => { for (const sheet of document.styleSheets) for (const rule of sheet.cssRules)
        if (rule.selectorText === ".c-deckpage .c-section__actions .c-btn") return rule.style.minHeight
        return null })()
    JS
    drawn = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".c-zone .c-section__actions .c-btn")].map((el) => { const box = el.getBoundingClientRect(); return [box.width, box.height] }).flat()
    JS
    expect(rule).to eq("var(--touch-floor)")
    expect(drawn.size).to eq(6)
    expect(drawn).to all(be >= 44)
  end

  it "keeps each zone head inside the frame, with Add a proxy on the name's line, at 360px (NFR Accessibility)", :aggregate_failures do
    open_deck_page_at(360)
    within_narrow_frame do
      expect(page_fits_sideways?).to be(true)
      heads = page.evaluate_script(<<~JS)
        [...document.querySelectorAll(".c-zone .c-section__head")].map((head) => { const title = head.querySelector(".c-section__title").getBoundingClientRect(), add = head.querySelector(".c-section__actions").getBoundingClientRect()
          return { inside: add.right <= document.documentElement.clientWidth, sameLine: add.top < title.bottom } })
      JS
      expect(heads).to all(eq({ "inside" => true, "sameLine" => true }))
    end
  end

  it "leaves the second column empty from 992px for a deck whose collectible draws no panel (AC-5.1; spec 069 supersedes it for a Magic deck, spec 060 AC-3.12)", :aggregate_failures, :other_collecting do
    visit deck_path(other_deck)
    page.driver.browser.manage.window.resize_to(1280, 900)
    expect(page).to have_css(".c-deck__zones")

    layout = page.evaluate_script(<<~JS)
      (() => { const grid = getComputedStyle(document.querySelector(".c-deck")); const zones = document.querySelector(".c-deck__zones").getBoundingClientRect()
        return { columns: grid.gridTemplateColumns.split(" ").length, children: document.querySelector(".c-deck").children.length, zonesWidth: zones.width, gridWidth: document.querySelector(".c-deck").getBoundingClientRect().width } })()
    JS
    expect(layout["children"]).to eq(1)
    expect(layout["columns"]).to eq(2)
    expect(layout["zonesWidth"]).to be < layout["gridWidth"]
  end

  it "keeps the marker in the muted ink in both themes, never red (AC-3.1, AC-5.5)", :aggregate_failures do
    visit deck_path(deck)
    %w[light dark].each do |theme|
      set_theme(theme)
      colours = page.evaluate_script(<<~JS)
        (() => { const probe = document.createElement("span"); probe.style.color = "var(--ink-muted)"; document.body.append(probe)
          const muted = getComputedStyle(probe).color; probe.remove()
          return [getComputedStyle(document.querySelector(".c-legal")).color, muted] })()
      JS
      expect(colours.first).to eq(colours.last), "#{theme}: the marker is #{colours.first}, the muted ink #{colours.last}"
    end
  end

  # Whether each of the head's parts lies inside the frame, and whether the name is cut.
  def head_boxes
    page.evaluate_script(<<~JS)
      (() => { const title = document.querySelector(".c-item__title"), width = document.documentElement.clientWidth
        const inside = (el) => { const box = el.getBoundingClientRect(); return box.left >= 0 && box.right <= width }
        return { cut: title.scrollWidth > title.clientWidth, title: inside(title),
                 buttons: [...document.querySelectorAll(".c-item__actions .c-btn")].map(inside) } })()
    JS
  end

  %w[light dark].each do |theme|
    it "wraps a 60-character deck name with no space inside the head at 360px in the #{theme} theme (AC-5.5, AC-5.6)", :aggregate_failures do
      open_in_narrow_frame(deck_path(create(:deck, account:, name: long_name)), width: 360, ready: ".c-item__head")
      within_narrow_frame do
        set_theme(theme)
        expect(page_fits_sideways?).to be(true)
        expect(head_boxes).to eq({ "cut" => false, "title" => true, "buttons" => [ true, true ] })
      end
    end
  end

  it "wraps the head's actions below the name at 360px and keeps them 36px high or more (AC-5.6)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 360, ready: ".c-item__head")
    within_narrow_frame do
      boxes = page.evaluate_script(<<~JS)
        (() => { const rect = (el) => el.getBoundingClientRect()
          return { title: rect(document.querySelector(".c-item__title")).bottom, actions: rect(document.querySelector(".c-item__actions")).top,
                   heights: [...document.querySelectorAll(".c-item__actions .c-btn")].map((el) => rect(el).height) } })()
      JS
      expect(boxes["actions"]).to be >= boxes["title"]
      expect(boxes["heights"]).to all(be >= 36) # the 44px floor is the design system's coarse-pointer rule; a fine-pointer run measures 36px
    end
  end
end
