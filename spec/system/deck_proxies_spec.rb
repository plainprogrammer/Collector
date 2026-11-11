require "rails_helper"

# Spec 068 Story 1 and Story 9: the add flow from the zone's header to the table, and every proxy page at 360px, 640px and 1280px
# in both themes (AC-9.1). Phone widths use the narrow frame (a window can't go below 500px), as spec 066's system spec does.
RSpec.describe "Adding a proxy", type: :system do
  let(:user) { create(:user) }
  let(:deck) { create(:deck, account: user.account, name: "Izzet Tempo") }
  let!(:long) { create(:mtg_printing, entry: create(:catalog_entry, name: "W" * 60), finishes: %w[foil nonfoil]).entry } # a 60-character name with no space

  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  before do
    create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", set: create(:catalog_set, code: "mh2"), number: "138"), finishes: %w[foil nonfoil])
    page.driver.browser.manage.window.resize_to(1280, 900)
    system_sign_in_as(user)
  end

  it "adds a proxy through the chooser and the form and shows it in the zone (AC-1.5)", :aggregate_failures do
    visit deck_path(deck)
    within(first("section.c-zone")) { click_link "Add a proxy to Main" }
    fill_in "Card name", with: "Lightning"
    click_button "Search"
    click_link "Choose Lightning Bolt MH2 · 138"
    select "Foil", from: "Finish"
    fill_in "Quantity", with: "3"
    click_button "Add proxy"

    expect(page).to have_content("Added 3 proxies of Lightning Bolt (MH2 · 138, Foil) to Izzet Tempo › Main.")
    expect(first("section.c-zone")).to have_css(".c-proxy", text: /\AProxy\s+3\z/) # the tag is inline-flex, so the browser reads its word and number on two lines
    expect(page).to have_css(".c-item__type", text: "3 cards · 0 owned · 3 proxy")
  end

  # The worst case for every proxy page's heading: the deck's name is 60 characters with no space, and each page says it.
  context "when the deck's name is 60 characters with no space" do
    let(:deck) { create(:deck, account: user.account, name: "D" * 60) }

    %w[light dark].each do |theme|
      [ 360, 640, 1280 ].each do |width|
        it "fits the chooser, the form, the change page and the removal page at #{width}px in the #{theme} theme (AC-9.1)", :aggregate_failures do
          proxy = create(:deck_proxy, zone: deck.zone("main"), account: user.account, entry: long, finish: "foil", quantity: 2)
          paths = [ new_deck_zone_proxy_path(deck, "main", q: "WWWW"), new_deck_zone_proxy_path(deck, "main", entry: long.external_key),
                    edit_deck_proxy_path(deck, proxy), new_deck_proxy_removal_path(deck, proxy) ]

          paths.each do |path|
            visit deck_path(deck) # the outer page hosts the frame
            open_in_narrow_frame(path, width:, ready: "main")
            within_narrow_frame do
              set_theme(theme)
              expect(fits?).to be(true), "#{path} at #{width}px in #{theme}"
            end
          end
        end
      end
    end

    # The Decks pages' touch floor is one rule on `.c-decks .c-btn`, so every page's `main` must carry `c-decks`. Headless Firefox has
    # a fine pointer (a small button is 36px there), so the rule is read from the stylesheet and the buttons are measured as drawn:
    # the rule applies at every pointer, so a button under it is 44px even here.
    it "gives the chooser's buttons the touch floor of the Decks pages (AC-9.1)", :aggregate_failures do
      visit new_deck_zone_proxy_path(deck, "main", q: "WWWW")
      floor = page.evaluate_script(<<~JS)
        (() => { let found = 0
          for (const sheet of document.styleSheets) for (const rule of sheet.cssRules)
            if (rule.selectorText === ".c-decks .c-btn") found = Math.max(found, parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--touch-floor")) || 0)
          return found })()
      JS
      heights = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("main .c-btn")].map((el) => el.getBoundingClientRect().height)
      JS
      expect(floor).to be >= 44
      expect(heights.size).to be >= 2 # Search and Cancel
      expect(heights).to all(be >= 44)
    end
  end
end
