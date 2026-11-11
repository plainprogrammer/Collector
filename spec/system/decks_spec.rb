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

  describe "the New deck page at 360px (AC-1.1)" do
    it "has no horizontal overflow and keeps the field and the select inside the form", :aggregate_failures do
      open_in_narrow_frame(new_deck_path, width: 360, ready: "form.c-form")
      within_narrow_frame do
        inside = page.evaluate_script(<<~JS)
          (() => {
            const form = document.querySelector("form.c-form").getBoundingClientRect()
            return [...document.querySelectorAll("form.c-form input:not([type=hidden]), form.c-form select")]
              .map((el) => el.getBoundingClientRect()).every((box) => box.left >= form.left - 0.5 && box.right <= form.right + 0.5)
          })()
        JS
        expect(inside).to be(true)
        expect(fits?).to be(true)
        expect(page).to have_select("Format", selected: "Casual")
      end
    end

    it "creates a deck from the form, which needs no script", :aggregate_failures do
      visit new_deck_path
      fill_in "Name", with: "Izzet Tempo"
      select "Modern", from: "Format"
      click_on "Create deck"
      expect(page).to have_css("#status", text: "Added “Izzet Tempo”.")
      expect(page).to have_css(".c-decks td", text: "Modern")
    end
  end

  describe "removing a deck, which needs no script (AC-3.1, AC-3.3)" do
    it "removes an empty deck from its row through the confirmation page", :aggregate_failures do
      create(:deck, account:, name: "Izzet Tempo")
      visit decks_path
      click_on "Remove Izzet Tempo"
      expect(page).to have_css("h1", text: "Remove Izzet Tempo?")
      click_on "Remove"
      expect(page).to have_css("#status", text: "Removed “Izzet Tempo”.")
      expect(page).to have_css(".c-empty", text: "No decks yet.")
    end

    it "shows the refusal at 360px with the zones' labels and no horizontal scroll", :aggregate_failures do
      deck = create(:deck, account:, name: "W" * 60)
      create_lot_in_zone(deck, "main", quantity: 2)
      open_in_narrow_frame(new_deck_removal_path(deck), width: 360, ready: "#held_lots")
      within_narrow_frame do
        expect(page).to have_css("#held_lots .c-decks__zone", text: "#{"W" * 60} › Main")
        expect(page).to have_link("Back to decks")
        expect(page).to have_no_css("main button", text: /Remove|bulk/)
        expect(fits?).to be(true)
      end
    end
  end

  describe "changing a deck's format (spec 064)" do
    it "changes the format from the row through the Change format page, which needs no script (AC-1.1, AC-1.3)", :aggregate_failures do
      deck = create(:deck, account:, name: "Krenko", format: "commander")
      create_lot_in_zone(deck, "commander", quantity: 2)

      visit decks_path
      click_link "Change format Krenko"
      expect(page).to have_css("h1", text: "Change format")
      select "Modern", from: "Format"
      click_button "Save"

      expect(page).to have_css("#status", text: "Changed “Krenko” to Modern. 2 cards moved to Considering.")
      expect(page).to have_css(".c-decks tbody", text: "Modern")
    end

    it "keeps the three row buttons on one line on a wide screen (AC-1.1)", :aggregate_failures do
      create(:deck, account:, name: "Krenko", format: "casual")

      visit decks_path
      tops = page.evaluate_script('Array.from(document.querySelectorAll(".c-decks__actions a")).map((a) => a.offsetTop)')

      expect(tops.size).to eq(3)
      expect(tops.uniq.size).to eq(1)
    end

    it "keeps the Decks row and the Change format page inside a 360px frame, a 60-character name included (AC-1.1)", :aggregate_failures do
      create(:deck, account:, name: "W" * 60, format: "casual")

      open_in_narrow_frame(decks_path, width: 360, ready: ".c-decks table")
      within_narrow_frame { expect(fits?).to be(true) }

      open_in_narrow_frame(edit_deck_format_path(account.decks.first), width: 360, ready: ".c-decks form")
      within_narrow_frame { expect(fits?).to be(true) }
    end
  end
end
