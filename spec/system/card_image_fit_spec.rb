require "rails_helper"

# Spec 019: a card image is shown whole and in its own proportions in every slot (tile, card page, table thumbnail).
# The pictures here are deliberately not 63:88, so cropping or stretching shows; see spec/support/card_images.rb.
RSpec.describe "Card image fit", :card_images, type: :system do
  let(:user) { system_sign_in_as(create(:user)) }
  let(:square) { card_picture(40, 40) }
  let(:tall) { card_picture(20, 40) }
  let(:wide) { card_picture(40, 20) }

  # The wide layout is checked at 1280px; the window goes back to the suite's size afterwards. (Not an around hook:
  # that would run before the driver is chosen.)
  before { page.current_window.resize_to(1280, 900) }
  after { page.current_window.resize_to(1400, 1400) }

  def owned_with_image(name, **attributes)
    owned_printing(name, account: user.account, **attributes).tap { |lot| lot.entry.update!(image_url: card_image_address) }
  end

  describe "tiles" do
    let(:images) { ".c-grid .c-tile__media img" }

    it "get their test pictures without asking a catalog source (Testability)", :aggregate_failures do
      owned_with_image("Bolt")
      visit collection_path(view: "grid")

      expect(page).to have_css("#{images}[src='#{card_image_address}']", count: 1)
      expect(page.evaluate_script("document.querySelector(#{images.to_json}).naturalWidth")).to eq(0)
      expect(card_image_fits(images, pictures: [ wide ]).sole.natural).to eq([ 40.0, 20.0 ])
    end

    it "keeps the fallback, the quantity badge and the slot's shape (AC-1.7, AC-1.8)", :aggregate_failures do
      owned_with_image("Bolt", quantity: 4)
      owned_printing("Opt", account: user.account)
      visit collection_path(view: "grid")
      expect(page).to have_css(".c-grid .c-tile__media", count: 2)

      # Before any picture arrives the image has failed to load: the slot keeps its shape all the same.
      slots = card_slot_boxes(".c-grid .c-tile__media").pluck("box")
      expect(slots.uniq.size).to eq(1)
      expect(slots.first[1]).to be_within(0.1).of(slots.first[0] * 88 / 63.0)
      expect(card_slot_boxes(".c-grid .c-tile__missing").pluck("outer")).to eq([ slots.first ])
      card_image_fits(images, pictures: [ wide ])
      badge = page.evaluate_script(<<~JS)
        (() => { const badge = document.querySelector(".c-tile__qty").getBoundingClientRect()
          const slot = document.querySelector(".c-tile__qty").parentElement.getBoundingClientRect()
          return [ badge.top - slot.top, slot.right - badge.right ] })()
      JS
      expect(badge).to eq([ 5, 5 ])
    end
  end
end
