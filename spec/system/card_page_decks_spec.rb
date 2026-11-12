require "rails_helper"

# Spec 073 Stories 4 and 5: the stats strip and the In decks table at phone and laptop widths, in both themes. Headless Firefox has a
# fine pointer, so no coarse rule is measured: AC-5.4 lists the controls and the rules that cover them.
RSpec.describe "Card page: Free to use and In decks", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let(:card) { create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", released_on: Date.new(2022, 1, 1))).entry }

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")

  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  describe "the stats strip (AC-5.1)" do
    before do
      older = create(:mtg_printing, entry: create(:catalog_entry, identity: card.identity, released_on: Date.new(2020, 1, 1))).entry
      deck = create(:deck, account:, name: "Alpha")
      create_lot_in_zone(deck, "main", entry: card, quantity: 9_999)
      create_lot_in_zone(deck, "sideboard", entry: older, quantity: 2_346)
      create(:lot, account:, entry: card, quantity: 9_999)
      create(:lot, account:, entry: older, quantity: 2_346)
    end

    %w[light dark].each do |theme|
      [ 360, 390 ].each do |width|
        it "is three across with nothing clipped at #{width}px in the #{theme} theme", :aggregate_failures do
          visit catalog_entry_path(card) # the outer page hosts the frame
          open_in_narrow_frame(catalog_entry_path(card), width:, ready: ".c-stats--three")
          within_narrow_frame do
            set_theme(theme)
            shown = page.evaluate_script(<<~JS)
              (() => { const stats = [ ...document.querySelectorAll(".c-stats--three .c-stat") ]
                const parts = [ ...document.querySelectorAll(".c-stats--three dt, .c-stats--three dd, .c-stats--three small") ]
                return { texts: stats.map((s) => s.querySelector("dd").textContent),
                         oneRow: new Set(stats.map((s) => Math.round(s.getBoundingClientRect().top))).size === 1,
                         clipped: parts.some((el) => el.scrollWidth > el.clientWidth + 1) } })()
            JS
            expect(shown).to eq("texts" => %w[24,690 12,345 12,345], "oneRow" => true, "clipped" => false)
            expect(fits?).to be(true)
          end
        end
      end
    end
  end

  describe "the table (AC-5.2)" do
    let(:deck) { create(:deck, account:, name: "D" * 60) }

    before do
      create_lot_in_zone(deck, "main", entry: card, quantity: 2)
      create(:deck_proxy, zone: deck.zone("considering"), entry: card, quantity: 1)
    end

    # The headers a reader sees, then the section's own width.
    def shown_headers = page.evaluate_script('[ ...document.querySelectorAll("#in-decks thead th") ].filter((th) => th.getClientRects().length > 0).map((th) => th.textContent.trim())')

    def section_width = page.evaluate_script('document.querySelector("#in-decks .c-collection").getBoundingClientRect().width')

    %w[light dark].each do |theme|
      [ 360, 390, 640, 1024 ].each do |width|
        it "folds Zone and the format under the name, keeps Owned and Proxy and does not scroll sideways at #{width}px in the #{theme} theme", :aggregate_failures do
          visit catalog_entry_path(card)
          open_in_narrow_frame(catalog_entry_path(card), width:, ready: "#in-decks table")
          within_narrow_frame do
            set_theme(theme)
            expect(section_width).to be < 640
            expect(shown_headers).to eq([ "Deck", "Owned", "Proxy" ])
            expect(page).to have_css("#in-decks tbody tr:first-child .c-table__sub", text: "Modern · Main", visible: :visible)
            expect(find("#in-decks td:first-child a", match: :first).native.rect.height).to be > 20 # the 60-character name wraps
            expect(fits?).to be(true)
          end
        end
      end

      it "shows all four columns, the format beside the name and no overflow at 1280px in the #{theme} theme", :aggregate_failures do
        visit catalog_entry_path(card)
        open_in_narrow_frame(catalog_entry_path(card), width: 1280, ready: "#in-decks table")
        within_narrow_frame do
          set_theme(theme)
          expect(section_width).to be >= 640
          expect(shown_headers).to eq([ "Deck", "Zone", "Owned", "Proxy" ])
          expect(page).to have_css("#in-decks tbody tr:first-child span.is-muted", text: "· Modern", visible: :visible)
          expect(page).to have_no_css("#in-decks .c-table__sub", visible: :visible)
          expect(fits?).to be(true)
        end
      end
    end

    it "carries the wrap rule, scoped to the section and written with no token (AC-5.3)" do
      visit catalog_entry_path(card)
      rule = page.evaluate_script(<<~JS)
        (() => { const rules = [ ...document.styleSheets ].flatMap((sheet) => [ ...sheet.cssRules ])
          const found = rules.find((r) => r.selectorText === "#in-decks td:first-child")
          return found && { white: found.style.whiteSpace, wrap: found.style.overflowWrap } })()
      JS
      expect(rule).to eq("white" => "normal", "wrap" => "anywhere")
    end
  end
end
