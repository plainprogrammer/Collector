require "rails_helper"

# Spec 070 Stories 3, 4 and 6: both flows from the deck page's row menu, with and without scripting, and both pages at 360px, 640px
# and 1280px in both themes with the worst-case names (AC-6.1), and the touch-floor rules read (AC-6.2).
RSpec.describe "Replacing a proxy", type: :system do
  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  def entry_of(name = "Lightning Bolt", set: "mh2", number: "138") = create(:mtg_printing, finishes: %w[foil nonfoil], entry: create(:catalog_entry, name:, set: create(:catalog_set, code: set), number:)).entry

  context "with scripting" do
    let(:user) { create(:user) }
    let(:deck) { create(:deck, account: user.account, name: "Izzet Tempo") }
    let!(:entry) { entry_of }

    before do
      create(:deck_proxy, zone: deck.zone("main"), account: user.account, entry:, finish: "foil", quantity: 2)
      page.driver.browser.manage.window.resize_to(1280, 900)
      system_sign_in_as(user)
    end

    it "uses a free copy from the row's menu, and the zone shows the owned copy and the lowered proxy (AC-3.1)", :aggregate_failures do
      create(:lot, account: user.account, entry:, location: create(:location, account: user.account, name: "Blue binder"), quantity: 3, finish: "foil", condition: "near_mint")
      visit deck_path(deck)
      within(first("section.c-zone")) do
        find("summary[aria-label='Actions for Lightning Bolt MH2 · 138']").click
        click_link "Use my copy"
      end
      fill_in "MH2 · 138 Foil, Near mint, Blue binder, ×3 free", with: "1"
      click_button "Use these copies"

      expect(page).to have_content("Replaced 1 proxy of Lightning Bolt (MH2 · 138, Foil) in Izzet Tempo › Main with copies you own.")
      expect(first("section.c-zone")).to have_css(".c-proxy", text: /\AProxy\s+1\z/)
      expect(page).to have_css(".c-item__type", text: "2 cards · 1 owned · 1 proxy")
    end

    it "adds a new copy from the row's menu with the printing, finish and zone filled in (AC-4.1, AC-4.2)", :aggregate_failures do
      visit deck_path(deck)
      within(first("section.c-zone")) do
        find("summary[aria-label='Actions for Lightning Bolt MH2 · 138']").click
        click_link "Add a new copy"
      end
      expect(page).to have_select("Finish", selected: "Foil")
      expect(page).to have_text("Izzet Tempo › Main")
      fill_in "Quantity", with: "2"
      click_button "Add copy"

      expect(page).to have_content("Added 2 × Lightning Bolt (MH2 · 138) to Izzet Tempo › Main, replacing 2 proxies.")
      expect(page).to have_css(".c-item__type", text: "2 cards · 2 owned · 0 proxy")
      expect(page).not_to have_css(".c-proxy")
    end
  end

  # AC-3.1, AC-4.2 "without scripting": rack_test runs no script, and the menu is a plain `details`. driven_by is declared before
  # the let! that signs in, so sign-in goes through rack_test too.
  context "without scripting" do
    before { driven_by :rack_test }

    let!(:user) { system_sign_in_as(create(:user)) }
    let!(:deck) { create(:deck, account: user.account, name: "Izzet Tempo") }
    let!(:entry) { entry_of }
    let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account: user.account, entry:, finish: "foil", quantity: 2) }

    it "uses a copy and then adds a new one, through plain pages and forms", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario across both pages
      expect(page.driver).to be_a(Capybara::RackTest::Driver)
      lot = create(:lot, account: user.account, entry:, location: create(:location, account: user.account, name: "Blue binder"), quantity: 1, finish: "foil")
      visit deck_path(deck)
      # rack_test treats a closed `details` as hiding its links and has no click that opens one; a browser without script
      # opens it natively from the summary, so the example reaches the link inside the row's menu by `visible: :all`.
      zone = first("section.c-zone")
      expect(zone).to have_css("details.c-menu > summary[aria-label='Actions for Lightning Bolt MH2 · 138']")
      zone.click_link "Use my copy", visible: :all
      fill_in "MH2 · 138 Foil, Blue binder, ×1 free", with: "1"
      click_button "Use these copies"
      expect(page).to have_content("Replaced 1 proxy of Lightning Bolt")
      expect(lot.reload.location).to eq(deck.zone("main"))

      first("section.c-zone").click_link "Add a new copy", visible: :all # the menu is closed again on the redirected page
      click_button "Add copy"
      expect(page).to have_content("Added 1 × Lightning Bolt (MH2 · 138) to Izzet Tempo › Main, replacing 1 proxy.")
      expect(Deck::Proxy.exists?(proxy.id)).to be(false)
      expect(page).to have_css(".c-item__type", text: "2 cards · 2 owned · 0 proxy")
    end
  end

  # The worst case for both pages: a deck name, a place name and a card name of 60 characters with no space.
  context "when every name is 60 characters with no space" do
    let(:user) { create(:user) }
    let(:deck) { create(:deck, account: user.account, name: "D" * 60) }
    let!(:long) { entry_of("W" * 60) }
    let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account: user.account, entry: long, finish: "foil", quantity: 2) }

    before do
      create(:lot, account: user.account, entry: long, location: create(:location, account: user.account, name: "P" * 60), quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 125)
      page.driver.browser.manage.window.resize_to(1280, 900)
      system_sign_in_as(user)
    end

    %w[light dark].each do |theme|
      [ 360, 640, 1280 ].each do |width|
        it "fits Use my copy, its refusal and Add a new copy at #{width}px in the #{theme} theme (AC-6.1)", :aggregate_failures do
          paths = [ new_deck_proxy_replacement_path(deck, proxy), new_deck_proxy_copy_path(deck, proxy) ]
          paths.each do |path|
            visit deck_path(deck)
            open_in_narrow_frame(path, width:, ready: "main")
            within_narrow_frame do
              set_theme(theme)
              expect(fits?).to be(true), "#{path} at #{width}px in #{theme}"
            end
          end
        end

        # The refused pages (AC-6.1's "an error is shown with its field"): the form is submitted inside the frame.
        it "fits the refused Use my copy and Add a new copy at #{width}px in the #{theme} theme, each error read by its field (AC-6.1)", :aggregate_failures do
          # Refusals the browser lets through and the server makes (a field's `max` and `required` would stop a typed 9 first):
          # every field left at 0 (the sum), and a price the server refuses (the field has no pattern).
          [ [ new_deck_proxy_replacement_path(deck, proxy), :submit_unused_copies, "fieldset[aria-describedby='replacement-error']" ],
            [ new_deck_proxy_copy_path(deck, proxy), :submit_bad_price, "input[name='lot[price_paid]'][aria-describedby]" ] ].each do |path, submit, described|
            visit deck_path(deck)
            open_in_narrow_frame(path, width:, ready: "main")
            within_narrow_frame do
              set_theme(theme)
              send(submit)
              expect(page).to have_css(".c-field__error")
              expect(page).to have_css(described)
              expect(fits?).to be(true), "#{path} refused at #{width}px in #{theme}"
            end
          end
        end
      end
    end

    def submit_unused_copies = click_button("Use these copies")

    def submit_bad_price
      fill_in "Price paid per copy (USD)", with: "abc"
      click_button "Add copy"
    end

    # AC-6.2: the controls of both pages and the rule that gives each its 44px floor on a coarse pointer. Headless Firefox has a
    # fine pointer, so the example reads the stylesheets' rules (the media rule, its selectors, the resolved `--touch-floor`) and
    # measures what is drawn under the rules that apply at every pointer; a control under a coarse-only rule is read, not measured.
    it "gives each control of Use my copy the rule that lifts it to the touch floor on a coarse pointer (AC-6.2)", :aggregate_failures do
      visit new_deck_proxy_replacement_path(deck, proxy)
      expect(page.evaluate_script("document.querySelector('main').classList.contains('c-decks')")).to be(true)
      expect(top_level_rule(".c-pick__lot .c-input")).to include("minHeight" => "var(--touch-floor)") # the number fields, additions.css
      expect(top_level_rule(".c-decks .c-btn")).to include("minHeight" => "var(--touch-floor)")      # Use these copies, Cancel, the empty state's button
      expect(coarse_rule(".c-btn")).to include("minHeight" => "44px")                                 # components.css, and the app bar's back link (`c-btn`)
      expect(coarse_rule(".c-input")).to include("minHeight" => "44px")                               # Quantity and Price paid on Add a new copy
      expect(coarse_rule(".c-field select")).to include("minHeight" => "var(--touch-floor)") # Finish and Condition on Add a new copy: the app-wide select rule of spec 072
      expect(page.evaluate_script("parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--touch-floor'))")).to be >= 44
      drawn = page.evaluate_script("[...document.querySelectorAll('main .c-btn, main .c-pick__lot .c-input')].map((el) => el.getBoundingClientRect().height)")
      expect(drawn.size).to be >= 3 # the field, Use these copies and Cancel
      expect(drawn).to all(be >= 44)
    end

    it "gives Add a new copy's buttons and page the touch floor of the Decks pages (AC-6.2)", :aggregate_failures do
      visit new_deck_proxy_copy_path(deck, proxy)
      expect(page.evaluate_script("document.querySelector('main').classList.contains('c-decks')")).to be(true)
      buttons = page.evaluate_script("[...document.querySelectorAll('main .c-btn')].map((el) => el.getBoundingClientRect().height)")
      expect(buttons.size).to eq(2) # Add copy and Cancel
      expect(buttons).to all(be >= 44)
    end

    # AC-6.3: a field with focus shows the 2px focus ring: a number field's on its `c-input` wrapper (the pattern of spec 060's
    # `UseMyCopy` example, on the real page), the Finish select's own, reached by Tab from Quantity as a keyboard reaches it.
    it "shows the focus ring on a focused number field's wrapper and on the Finish select", :aggregate_failures do
      visit new_deck_proxy_replacement_path(deck, proxy)
      find("input[type=number]").click
      ring = page.evaluate_script("(() => { const s = getComputedStyle(document.activeElement.closest('.c-input')); return [s.outlineStyle, s.outlineWidth]; })()")
      expect(ring).to eq([ "solid", "2px" ])

      visit new_deck_proxy_copy_path(deck, proxy)
      find("input[name='lot[quantity]']").send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.name")).to eq("lot[finish]")
      expect(page.evaluate_script("(() => { const s = getComputedStyle(document.activeElement); return [s.outlineStyle, s.outlineWidth]; })()")).to eq([ "solid", "2px" ])
    end

    # The first plain (not media) rule whose selector list contains +selector+.
    def top_level_rule(selector)
      page.evaluate_script(<<~JS)
        (() => { for (const sheet of document.styleSheets) for (const rule of sheet.cssRules)
          if (rule.selectorText?.split(",").map((s) => s.trim()).includes(#{selector.to_json})) return { minHeight: rule.style.minHeight }
          return null })()
      JS
    end

    # The first rule of a `pointer: coarse` media block whose selector list contains +selector+ (headless Firefox has a fine
    # pointer, so the example reads the stylesheet's rule, not a layout).
    def coarse_rule(selector)
      page.evaluate_script(<<~JS)
        (() => { for (const sheet of document.styleSheets) for (const media of sheet.cssRules)
          if (media instanceof CSSMediaRule && media.conditionText.includes("pointer: coarse"))
            for (const rule of media.cssRules)
              if (rule.selectorText?.split(",").map((s) => s.trim()).includes(#{selector.to_json})) return { minHeight: rule.style.minHeight }
          return null })()
      JS
    end
  end
end
