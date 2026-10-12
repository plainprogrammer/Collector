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

  def two_faced_entry
    create(:mtg_printing).tap do |printing|
      printing.update!(faces: %w[front back].map { |face| { "name" => face.capitalize, "image_uris" => { "normal" => card_image_address(face) } } })
    end.entry
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

    it "shows images of any proportions whole, in equal 63:88 slots, in both themes (AC-1.1, AC-1.2, AC-1.5, AC-1.6)", :aggregate_failures do
      %w[Bolt Opt Shock].each { |name| owned_with_image(name) }
      visit collection_path(view: "grid")
      expect(page).to have_css(images, count: 3)

      fits = card_image_fits(images, pictures: [ square, tall, wide ])
      expect(fits.flat_map(&:faults)).to be_empty
      expect(fits.map(&:slot).uniq.size).to eq(1)

      use_dark_theme
      dark = card_image_fits(images)
      expect(dark.flat_map(&:faults)).to be_empty
      expect(dark.first.ground).not_to eq(fits.first.ground)
    end

    it "shows the whole image in search results, faded for a card you don't own (AC-1.3, AC-1.8)", :aggregate_failures do
      user
      create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", image_url: card_image_address))
      visit catalog_entries_path(q: "bolt")
      expect(page).to have_css(images, count: 1)

      expect(card_image_fits(images, pictures: [ square ]).flat_map(&:faults)).to be_empty
      expect(page.evaluate_script("getComputedStyle(document.querySelector(#{images.to_json})).opacity")).to eq("0.45")
    end

    it "shows the whole image at phone width (AC-1.1, AC-1.2)", :aggregate_failures do
      %w[Bolt Opt].each { |name| owned_with_image(name) }
      visit collection_path(view: "grid")

      expect(open_in_narrow_frame(collection_path(view: "grid"), width: 390, height: 844, ready: ".c-grid")).to eq([ 390, true ])
      within_narrow_frame do
        fits = card_image_fits(images, pictures: [ square, tall ])
        expect(fits.size).to eq(2)
        expect(fits.flat_map(&:faults)).to be_empty
      end
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

  describe "the card page" do
    let(:images) { ".c-item__image img" }

    it "shows each face's image whole in its own 63:88 slot, in both themes (AC-2.1, AC-2.3, AC-2.4)", :aggregate_failures do
      user
      visit catalog_entry_path(two_faced_entry)
      expect(page).to have_css(images, count: 2)
      expect(page.evaluate_script("window.innerWidth")).to eq(1280)

      fits = card_image_fits(images, pictures: [ square, tall ])
      expect(fits.flat_map(&:faults)).to be_empty

      use_dark_theme
      dark = card_image_fits(images)
      expect(dark.flat_map(&:faults)).to be_empty
      expect(dark.first.ground).not_to eq(fits.first.ground)
    end

    it "shows the whole image at phone width, with no sideways scroll (AC-2.2)", :aggregate_failures do
      user
      entry = two_faced_entry
      visit catalog_entry_path(entry)

      expect(open_in_narrow_frame(catalog_entry_path(entry), width: 390, height: 844, ready: ".c-item")).to eq([ 390, true ])
      within_narrow_frame do
        fits = card_image_fits(images, pictures: [ wide, tall ])
        expect(fits.size).to eq(2)
        expect(fits.flat_map(&:faults)).to be_empty
      end
    end
  end

  describe "the table thumbnail" do
    let(:images) { "img.c-table__thumb" }

    it "shows a Scryfall-sized image in its own proportions (AC-3.1)", :aggregate_failures do
      owned_with_image("Bolt")
      visit collection_path(view: "table")
      expect(page).to have_css(images, count: 1)

      expect(card_image_fits(images, pictures: [ card_picture(488, 680) ]).flat_map(&:faults)).to be_empty
    end

    it "shows images of any proportions whole, in slots and rows of one size, in both themes (AC-3.2, AC-3.3, AC-3.4)", :aggregate_failures do
      %w[Bolt Opt].each { |name| owned_with_image(name) }
      owned_printing("Shock", account: user.account)
      visit collection_path(view: "table")
      expect(page).to have_css(".c-table__thumb", count: 3)

      # The two images have failed to load at this point, and still take the empty slot's size.
      expect(card_slot_boxes(".c-table__thumb").pluck("box").uniq.size).to eq(1)
      fits = card_image_fits(images, pictures: [ square, tall ])
      expect(fits.flat_map(&:faults)).to be_empty
      thumbs = card_slot_boxes(".c-table__thumb")
      expect(thumbs.pluck("tag")).to contain_exactly("img", "img", "span")
      expect(thumbs.pluck("box").uniq.size).to eq(1)
      expect(thumbs.pluck("row").uniq.size).to eq(1)

      use_dark_theme
      dark = card_image_fits(images)
      expect(dark.flat_map(&:faults)).to be_empty
      expect(dark.first.ground).not_to eq(fits.first.ground)
    end

    it "keeps slots and rows of one size at phone width (AC-3.2, AC-3.3)", :aggregate_failures do
      %w[Bolt Opt].each { |name| owned_with_image(name) }
      owned_printing("Shock", account: user.account)
      visit collection_path(view: "table")

      expect(open_in_narrow_frame(collection_path(view: "table"), width: 390, height: 844, ready: "table.c-table")).to eq([ 390, true ])
      within_narrow_frame do
        expect(card_image_fits(images, pictures: [ tall, wide ]).flat_map(&:faults)).to be_empty
        thumbs = card_slot_boxes(".c-table__thumb")
        expect(thumbs.size).to eq(3)
        expect(thumbs.pluck("box").uniq.size).to eq(1)
        expect(thumbs.pluck("row").uniq.size).to eq(1)
      end
    end
  end
end
