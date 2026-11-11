require "rails_helper"

# Spec 066 Story 5: the deck page at 360, 640, 768 and 1280px in both themes, in headless Firefox. Phone widths use the narrow
# frame (a window can't go below 500px), whose page is a same-origin iframe.
RSpec.describe "Deck page", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:long_name) { "W" * 60 }

  def printing(name:, type_line: "Creature", cost: "{2}{W}{U}{B}{R}{G}", legalities: { "modern" => "banned" }, **attrs)
    entry = create(:catalog_entry, name:, **attrs)
    create(:mtg_printing, entry:, legalities:, faces: [ { "name" => name, "type_line" => type_line, "mana_cost" => cost, "image_uris" => {} } ])
    entry
  end

  # The worst case (a 60-character name with no space, a six-symbol cost, a marker, a three-digit quantity), a short row, a land,
  # and cards in Sideboard and Considering so three zone tables differ in content.
  before do
    create_lot_in_zone(deck, "main", entry: printing(name: long_name), quantity: 123)
    create_lot_in_zone(deck, "main", entry: printing(name: "Lightning Bolt", type_line: "Instant", cost: "{R}", legalities: { "modern" => "legal" }), quantity: 4)
    create_lot_in_zone(deck, "main", entry: printing(name: "Island", type_line: "Basic Land — Island", cost: "", legalities: { "modern" => "legal" }), quantity: 20)
    create_lot_in_zone(deck, "sideboard", entry: printing(name: "Spell Pierce", type_line: "Instant", cost: "{U}", legalities: { "modern" => "not_legal" }), quantity: 2)
    create_lot_in_zone(deck, "considering", entry: printing(name: "Force of Will", type_line: "Instant", cost: "{3}{U}{U}", legalities: { "modern" => "legal" }), quantity: 1)
  end

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  def shown_headers
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".c-zone thead th")].filter((th) => th.getClientRects().length > 0).slice(0, 5).map((th) => th.textContent.trim())
    JS
  end

  # The left edge and width of each column's header in each zone table.
  def column_boxes
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".c-zone table")].map((table) =>
        [...table.querySelectorAll("thead th")].map((th) => { const box = th.getBoundingClientRect(); return [Math.round(box.left * 10) / 10, Math.round(box.width * 10) / 10] }))
    JS
  end

  [ 360, 640, 768, 1280 ].each do |width|
    %w[light dark].each do |theme|
      it "has no horizontal overflow at #{width}px in the #{theme} theme and keeps a six-symbol cost inside its cell (AC-5.4, AC-5.5)", :aggregate_failures do
        open_in_narrow_frame(deck_path(deck), width:, ready: ".c-zone:first-of-type table")
        within_narrow_frame do
          set_theme(theme)
          expect(fits?).to be(true)
          worst = page.evaluate_script(<<~JS)
            (() => { const cost = [...document.querySelectorAll(".c-zone td:nth-child(2)")].find((td) => td.querySelectorAll(".c-mana").length === 6)
              return [cost.scrollWidth, cost.clientWidth] })()
          JS
          expect(worst.first).to be <= worst.last
        end
      end
    end
  end

  it "keeps each zone head's count uncut and, under 640px, on its own line below the name (AC-5.5)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 360, ready: ".c-zone:first-of-type table")
    within_narrow_frame do
      heads = page.evaluate_script(<<~JS)
        [...document.querySelectorAll(".c-zone .c-section__head")].map((head) => {
          const count = head.querySelector(".c-section__count"), title = head.querySelector(".c-section__title")
          return { cut: count.scrollWidth > count.clientWidth, below: count.getBoundingClientRect().top >= title.getBoundingClientRect().bottom }
        })
      JS
      expect(heads.size).to eq(3)
      expect(heads).to all(eq({ "cut" => false, "below" => true }))
    end
  end

  it "shows Card, Cost and Total under 640px, with the set and the marker under the name and Owned hidden (AC-5.3)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 360, ready: ".c-zone:first-of-type table")
    within_narrow_frame do
      expect(shown_headers.first(3)).to eq([ "Card", "Cost", "Total" ])
      visible = page.evaluate_script(<<~JS)
        (() => { const row = [...document.querySelectorAll(".c-zone tbody tr")].find((tr) => tr.textContent.includes("W".repeat(60)))
          const shown = (el) => el.getClientRects().length > 0
          return { sub: shown(row.querySelector(".c-table__sub .c-legal")), beside: shown(row.querySelector(".is-opt .c-legal")) } })()
      JS
      expect(visible).to eq({ "sub" => true, "beside" => false })
    end
  end

  it "shows the marker once beside the name from 640px and not under it, and all five columns (AC-3.6, AC-5.2)", :aggregate_failures do
    open_in_narrow_frame(deck_path(deck), width: 1280, ready: ".c-zone:first-of-type table")
    within_narrow_frame do
      expect(shown_headers).to eq([ "Card", "Cost", "Owned", "Proxy", "Total" ])
      visible = page.evaluate_script(<<~JS)
        (() => { const row = [...document.querySelectorAll(".c-zone tbody tr")].find((tr) => tr.textContent.includes("W".repeat(60)))
          const shown = (el) => el.getClientRects().length > 0
          return { sub: shown(row.querySelector(".c-table__sub .c-legal")), beside: shown(row.querySelector(".is-opt .c-legal")) } })()
      JS
      expect(visible).to eq({ "sub" => false, "beside" => true })
    end
  end

  it "gives Cost, Owned, Proxy and Total one left edge and width in every zone table from 640px (AC-5.2)", :aggregate_failures do
    visit deck_path(deck)
    page.driver.browser.manage.window.resize_to(1280, 900)
    expect(page).to have_css(".c-zone table", count: 3)

    boxes = column_boxes

    (1..4).each { |column| expect(boxes.map { it[column] }.uniq.size).to eq(1), "column #{column} differs between zone tables: #{boxes.map { it[column] }}" }
  end

  it "leaves the second column empty from 992px: the zones keep the first column and nothing sits in the second (AC-5.1)", :aggregate_failures do
    visit deck_path(deck)
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
      (() => { const title = document.querySelector(".c-item__title"), width = window.innerWidth
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
        expect(fits?).to be(true)
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
