require "rails_helper"

# Spec 062 Story 4 and Story 1: the Decks page and the New deck page at a phone's width, in headless Firefox.
RSpec.describe "Decks", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }

  # Whether the frame's page scrolls sideways, and what the narrow frame's page reports.
  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  describe "the Decks page at 360px (AC-4.5)" do
    let(:long_name) { "W" * 60 }

    before do
      create(:deck, account:, name: "Izzet Tempo").tap { create_lot_in_zone(it, "main", quantity: 58) }
      create(:deck, account:, name: long_name, format: "casual")
    end

    it "hides Format and Owned, reads the format and owned count under the name, wraps a long name and does not scroll sideways", :aggregate_failures do
      open_in_narrow_frame(decks_path, width: 360, ready: ".c-decks table")
      within_narrow_frame do
        shown = page.evaluate_script(<<~JS)
          [...document.querySelectorAll(".c-decks thead th")].filter((th) => th.getClientRects().length > 0).map((th) => th.textContent.trim())
        JS
        expect(shown).to eq([ "Deck", "Cards", "Actions" ])
        expect(page).to have_css(".c-decks .c-table__sub", text: "Modern · 58 owned")
        expect(page).to have_css(".c-decks .c-table__sub", text: "Casual · 0 owned")
        name = find(".c-decks td:first-child .c-table__item span", text: long_name, match: :first)
        expect(name.native.rect.height).to be > 20 # more than one line: the name wraps
        expect(fits?).to be(true)
        expect(page).to have_link("New deck") # stays visible on a phone (spec 060 decision 24)
        expect(find_link("New deck").native.rect.height).to be >= 36
      end
    end

    it "shows Format and Owned at 1280px and the page does not scroll sideways", :aggregate_failures do
      visit decks_path
      expect(page).to have_css(".c-decks thead th", text: "Format")
      expect(page).to have_css(".c-decks thead th", text: "Owned")
      expect(page).to have_css(".c-decks td", text: "Modern")
      expect(fits?).to be(true)
    end
  end
end
