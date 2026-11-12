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
  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
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
    it "has no horizontal overflow at #{width}px in the #{theme} theme with every panel part full (AC-5.1)" do
      open_in_narrow_frame(deck_path(deck), width:, ready: ".c-deck__zones")
      within_narrow_frame do
        page.execute_script("document.documentElement.dataset.theme = #{theme.to_json}")
        page.execute_script('document.querySelector("details.c-shapefold").open = true')
        expect(fits?).to be(true)
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
  # scrollbar inside a 360px width is 15px narrower (263px inside), where the fixture's 1,357 count overflows its column by about
  # 1.85px: a CSS question raised with the maintainer, not decided here. Each check can fail: the panel scrolling sideways, an element
  # drawn past the padding box's right edge, and a text element cut off at its own box.
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
end
