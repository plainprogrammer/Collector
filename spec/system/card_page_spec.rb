require "rails_helper"

RSpec.describe "Card page", type: :system do
  let(:entry) { create(:mtg_printing).entry }

  it "keeps the image in view while scrolling on a wide screen" do
    system_sign_in_as(create(:user))
    visit catalog_entry_path(entry)
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.c-item__media')).position")).to eq("sticky")
  end

  # Firefox won't open a window narrower than 500px, so the phone layout is checked in a 390px frame.
  it "shows a back link and the head's actions on one line on a phone", :aggregate_failures do
    expect(open_card_on_phone).to eq([ 390, true ])
    within_narrow_frame do
      expect(page).to have_link("Back", href: catalog_entries_path)
      expect(page).to have_no_css(".c-appbar__brand", visible: :visible)
      expect(page).to have_no_css(".c-appbar__add", visible: :visible)
      widths = page.evaluate_script(<<~JS)
        [ ".c-item__actions", ".c-item__body" ].map((selector) => document.querySelector(selector).getBoundingClientRect().width)
      JS
      expect(widths[0]).to eq(widths[1])
      expect(head_row_fits.except("tall")).to eq("oneLine" => true, "inside" => true, "unclipped" => true, "overflow" => false) # a fine pointer: 36px controls
    end
  end

  # AC-8.10: the image is centred and each copy folds its details into one line under the printing.
  it "centres the image and folds copy rows on a phone", :aggregate_failures do
    expect(open_card_on_phone).to eq([ 390, true ])
    within_narrow_frame do
      gaps = page.evaluate_script(<<~JS)
        (() => { const item = document.querySelector(".c-item").getBoundingClientRect()
          const media = document.querySelector(".c-item__media").getBoundingClientRect()
          return [ media.left - item.left, item.right - media.right ] })()
      JS
      expect(gaps[0]).to be_within(2).of(gaps[1])
      within("#copies") do
        expect(page).to have_css(".c-table__sub", text: "Foil", visible: :visible)
        expect(page).to have_no_css(".is-opt", visible: :visible)
      end
    end
  end

  # A long set name may wrap, but a printing's set · number never breaks mid-code.
  it "keeps each printing's set and number on one line on a phone", :aggregate_failures do
    create(:catalog_entry, identity: entry.identity, number: "806",
      set: create(:catalog_set, code: "msc", name: "Marvel Super Heroes Commander Collector Showcase Extras"))
    expect(open_card_on_phone).to eq([ 390, true ])
    within_narrow_frame do
      lines = page.evaluate_script(<<~JS)
        [ ...document.querySelectorAll("#printings .c-list .is-data") ].map((data) =>
          Math.round(data.getBoundingClientRect().height / parseFloat(getComputedStyle(data).lineHeight)))
      JS
      expect(lines).to eq([ 1, 1 ])
    end
  end

  private

  # Signs in, owns one foil copy of the card, and opens the card page in a 390px frame.
  # The head's actions at the frame's width: on one line, every control inside the row, the primary not clipped, no overflow.
  def head_row_fits
    page.evaluate_script(<<~JS)
      (() => { const row = document.querySelector(".c-item__actions"), box = row.getBoundingClientRect()
        const controls = [...row.querySelectorAll(".c-btn")].map((el) => el.getBoundingClientRect())
        const primary = row.querySelector(".c-btn--primary")
        return { oneLine: Math.max(...controls.map((c) => c.height)) >= box.height - 1, tall: controls.every((c) => c.height >= 44),
                 inside: controls.every((c) => c.left >= box.left - 0.5 && c.right <= box.right + 0.5),
                 unclipped: primary.scrollWidth <= primary.clientWidth + 1,
                 overflow: document.documentElement.scrollWidth > window.innerWidth } })()
    JS
  end

  # AC-1.5: one line, every control inside the row, the primary not clipped, no overflow, with the menu present and absent, at 360px
  # and 390px, and then with every coarse-pointer rule applied (`apply_coarse_rules`: a fine pointer doesn't apply components.css'
  # `.c-btn { min-height:44px }` and `.c-btn--icon { min-width:44px }`, which makes the menu 8px wider), when every control is also 44px high.
  [ 360, 390 ].each do |width|
    { "with" => true, "without" => false }.each do |label, menu|
      it "keeps the head's controls on one line at #{width}px #{label} the … menu, also with the coarse pointer's sizes (AC-1.5)", :aggregate_failures do
        system_sign_in_as(create(:user))
        # `scryfall_uri` is required, so the menu-less card has a link no source vouches for: `catalog_url` returns nil for its host
        uri = menu ? "https://scryfall.com/card/x/1" : "https://example.com/card/x/1"
        printing = create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt"), scryfall_uri: uri).entry
        visit catalog_entry_path(printing)
        open_in_narrow_frame(catalog_entry_path(printing), width:, height: 800, ready: ".c-item__title")
        within_narrow_frame do
          expect(page).to have_link("Add to deck")
          expect(page.all(".c-item__actions summary[aria-label='More actions']").size).to eq(menu ? 1 : 0)
          expect(head_row_fits.except("tall")).to eq("oneLine" => true, "inside" => true, "unclipped" => true, "overflow" => false)
          apply_coarse_rules(needs: [ ".c-btn, .c-input", ".c-btn--icon" ])
          expect(head_row_fits).to eq("oneLine" => true, "tall" => true, "inside" => true, "unclipped" => true, "overflow" => false)
        end
      end
    end
  end

  def open_card_on_phone
    user = system_sign_in_as(create(:user))
    create(:lot, account: user.account, entry:, finish: "foil", condition: "near_mint")
    visit catalog_entry_path(entry)
    open_in_narrow_frame(catalog_entry_path(entry), width: 390, height: 844, ready: ".c-item__title")
  end
end
