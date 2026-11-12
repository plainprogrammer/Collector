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
    open_in_narrow_frame(deck_path(deck), width: 360, ready: "details.c-shapefold")
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
