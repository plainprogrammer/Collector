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
end
