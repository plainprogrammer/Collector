require "rails_helper"

RSpec.describe "Card page", type: :system do
  let(:entry) { create(:mtg_printing).entry }

  it "keeps the image in view while scrolling on a wide screen" do
    system_sign_in_as(create(:user))
    visit catalog_entry_path(entry)
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.c-item__media')).position")).to eq("sticky")
  end

  # Firefox won't open a window narrower than 500px, so the phone layout is checked in a 390px frame.
  it "shows a back link to search instead of the logo on a phone", :aggregate_failures do
    user = system_sign_in_as(create(:user))
    create(:lot, account: user.account, entry:, finish: "foil", condition: "near_mint")
    visit catalog_entry_path(entry)
    expect(open_in_narrow_frame(catalog_entry_path(entry), width: 390, height: 844, ready: ".c-item__title")).to eq([ 390, true ])
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
      # AC-8.10: the image is centred and each copy folds its details into one line under the printing.
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
end
