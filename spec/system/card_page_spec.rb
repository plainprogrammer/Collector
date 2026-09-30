require "rails_helper"

RSpec.describe "Card page", type: :system do
  let(:entry) { create(:mtg_printing).entry }

  it "keeps the image in view while scrolling on a wide screen" do
    system_sign_in_as(create(:user))
    visit catalog_entry_path(entry)
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.c-item__media')).position")).to eq("sticky")
  end

  # Firefox won't open a window narrower than 500px, so the phone layout is checked in a 390px frame.
  it "shows a back link and a full-width add action on a phone", :aggregate_failures do
    expect(open_card_on_phone).to eq([ 390, true ])
    within_narrow_frame do
      expect(page).to have_link("Back", href: catalog_entries_path)
      expect(page).to have_no_css(".c-appbar__brand", visible: :visible)
      expect(page).to have_no_css(".c-appbar__add", visible: :visible)
      widths = page.evaluate_script(<<~JS)
        [ ".c-item__actions", ".c-item__body", ".c-item__actions .c-btn--primary" ]
          .map((selector) => document.querySelector(selector).getBoundingClientRect().width)
      JS
      expect(widths[0]).to eq(widths[1])
      expect(widths[2]).to be > widths[0] / 2
      expect(page.evaluate_script("document.querySelector('.c-item__actions .c-btn--primary').getBoundingClientRect().width")).to be > 200
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
  def open_card_on_phone
    user = system_sign_in_as(create(:user))
    create(:lot, account: user.account, entry:, finish: "foil", condition: "near_mint")
    visit catalog_entry_path(entry)
    open_in_narrow_frame(catalog_entry_path(entry), width: 390, height: 844, ready: ".c-item__title")
  end
end
