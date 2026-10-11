# Implementation Plan: Fit Card Images Without Cropping

**Spec:** docs/specs/019-uncropped-card-images/spec.md (v1.3.0, Approved)
**Decisions:** no ADR. The spec's decisions 1 to 4 are the maintainer's rulings: an override in `additions.css` and no re-export; the whole image inside the fixed 63:88 slot on `surface-sunken`; the thumbnail keeps its 2px corner; the card page's fallback sits in its own slot.
**Created:** 2026-10-11
**Issue:** [#35](https://github.com/plainprogrammer/Collector/issues/35)

**How this plan was made.** Every code block below was written, run and linted before the plan was. The change was applied to this worktree phase by phase, uncommitted: each phase's examples were run red against the styles before it and green after, RuboCop passed on the changed files, and the whole suite, RuboCop and Brakeman passed on the final state (1,133 examples, 0 failures, 1 pending; the suite has 1,119 before this plan). The worktree was then restored to `HEAD`. The blocks are rendered by script from the tree of each phase, so a new file is shown whole and a changed file as its exact diff. Nothing was committed or pushed.

## Global Constraints

- `app/assets/stylesheets/collector/components.css` and `tokens.css` stay byte-for-byte as exported (FR-3).
- Every style change is in one block of `app/assets/stylesheets/collector/additions.css`, headed `Image fit (spec 019)`. It goes between the `Tile with an add control outside its link` block and the `Select inside the filter bar` block, not at the end of the file, where spec 018 appends its own. No other block is touched. The block has no colour literal and no font (AC-4.3).
- No view changes. `app/views/catalog/entries/show.html.erb` and its attribution line belong to spec 018.
- Slots stay 63:88, with their size, border and corner radius. The thumbnail keeps its 2px corner. The one size that changes is the thumbnail's image box: 24×34 becomes 24×33.52, the empty slot's size, and its table row goes from 53px to 52.52px (FR-2).
- The exported component docs (`ItemTile.md`, `ItemPage.md`, `CollectionTable.md`) aren't edited (FR-4).
- The suite's browser never asks a catalog source for a picture: a test entry's image address is `https://127.0.0.1:9/…`, and pictures arrive as `data:` addresses (Testability).
- The unowned fade (`c-tile--owned-none`, 45% opacity) is out of scope. It is asserted as unchanged only.
- No new gem, no JavaScript in the app, no setting, no migration.
- `bin/ci` passes at every commit: each phase commits its examples with its rule, never a failing example.
- Commits are Conventional Commits, one per step shown, with the attribution trailer. Stage and commit in separate commands (the pre-commit hook reads the command text).
- Nothing is pushed and no pull request is opened until the maintainer says so.
- To keep the merge with spec 018 small: the README gets one line of its own, and `spec/design_system_files_spec.rb` gets a `describe` of its own (the shared `new_patterns` list isn't edited). If 018 merges first, the README's two new lines conflict as neighbours: keep both, in spec order.

---

## Goal

Every card image slot (tile, card page, table thumbnail) shows its image whole and in its own proportions, held by browser examples that fail if a re-export brings cropping or stretching back.

**Facts established during planning (2026-10-11, headless Firefox 157.0.1, window 1280px wide unless noted), each by running it:**

- **The thumbnail is stretched today.** `img.c-table__thumb` has a 24×34 content box and `object-fit: fill`; the empty `span.c-table__thumb` is 24×33.517. A 488×680 picture is painted 24×34, 1.67% too tall. Their rows are 53px and 52.517px. With the fix both boxes are 24×33.517, the fit is `contain`, the picture is painted 24×33.443 and both rows are 52.517px.
- **Tiles and the card page crop today.** In a tile, a 40×40 picture is painted 219.9×219.9 in a 157.4×219.9 box, and a 488×680 picture loses 0.19px from each side. On the card page a 20×40 picture is painted 298×596 in a 298×416.25 box.
- **The card page's fallback isn't in its slot today.** `c-tile__missing` is `position:absolute; inset:0` and `c-item__image` has no position, so it is placed against `c-item__media` (sticky): 300×466.25 for one face, 300×892.5 for two, against a slot of 298×416.25.
- **The derived rectangle matches the pixels.** The examples work out where a picture is painted from its natural size, the image's content box and the computed `object-fit` and `object-position`. Checked once against a screenshot of the element, counting picture-coloured pixels (window 1400px wide, where a tile's box is 151×210.9; the thumbnail's 1px border is taken off the pixel positions):

  | Slot, picture | Derived (left, top, width × height) | Pixels painted |
  |---|---|---|
  | Tile 151×210.9, 40×40, with the fix | 0, 29.96, 151 × 151 | 151×151 at 0, 30 |
  | Tile, 20×40, with the fix | 22.77, 0, 105.46 × 210.92 | 105×210 at 23, 0 |
  | Tile, 40×40, as exported (`cover`) | −29.96, 0, 210.92 × 210.92 | 151×210 at 0, 0 (the box, full) |
  | Thumbnail 24×33.5, 40×40, with the fix | 0, 4.76, 24 × 24 | 24×24 at 0, 5 |
  | Thumbnail, 20×40, with the fix | 3.62, 0, 16.76 × 33.52 | 16×34 at 4, 0 |
  | Thumbnail 24×34, 40×40, as exported (`fill`) | 0, 0, 24 × 34 | 24×34 at 0, 0 |

  Pixels can't show the thumbnail's half-pixel change for a 488×680 picture (24×34 before and after, by anti-aliasing); the box and the computed fit can, which is why the examples use them.
- **A failed image keeps its slot.** `https://127.0.0.1:9/…` fails at once in Firefox (`complete` true, `naturalWidth` 0) and the tile slot stays 63:88. A failed thumbnail is a block box of the slot's size: 24×34 today, 24×33.517 with the fix.
- **`image.decode()` doesn't wait for a new `src`** in Firefox: the second picture given to an image was measured with the first one's size. The helper waits for the `load` event.
- **An `around` hook runs before `driven_by`** (`Capybara::NotSupportedByDriverError`), so the window is resized in `before` and `after`. The driver's window size is set once per session, so the examples put it back to 1400×1400.
- **The collection's view is a saved preference.** After one visit to the table, `collection_path` shows the table: the examples always pass `view:`.
- **Sizes come back with float noise** (33.51666… against 33.51667…), so the helper rounds them to a thousandth of a pixel before comparing.
- **`owned_printing` returns a lot whose `entry.extension` isn't loaded**, so the examples set faces on the `MTG::Printing` they create.

**Pre-implementation gates.** Simplicity: one block of three rules, one doc, one support file; nothing for the future. Anti-abstraction: plain CSS on the exported classes; the test helper reads the browser's own computed values. Integration first: the examples exist and fail before each rule. All pass; no complexity notes.

---

## Phase 0: Test pictures in the browser

**Implements:** Testability (non-functional), FR-2 | **Satisfies:** AC-1.7, AC-1.8 (both as guards on behaviour that must not change)
**Files:** `spec/support/card_images.rb` (new), `spec/system/card_image_fit_spec.rb` (new)
**Interfaces:** Consumes: `png_bytes` (`spec/support/png_helpers.rb`), `owned_printing` (`spec/support/collection_helpers.rb`), `open_in_narrow_frame` and `within_narrow_frame` (`spec/support/narrow_frame.rb`), `system_sign_in_as`. Produces, for system examples: the `:card_images` tag (lets `catalog_url` pass `127.0.0.1`), `card_image_address(name = "card")`, `card_picture(width, height)`, `card_image_fits(selector, pictures: [])` returning `CardImages::Fit` values (`fit`, `slot`, `box`, `natural`, `painted`, `ground`, `sunken`, `#faults`), `card_slot_boxes(selector)` returning hashes with `"tag"`, `"top"`, `"outer"`, `"box"`, `"row"`, and `use_dark_theme`. In the spec file: `user`, `square`, `tall`, `wide`, `owned_with_image(name, **attributes)`.

The spec asks the plan to settle, in its first task, how Firefox gets test images without the network. This phase does that and nothing else: no style changes, and both examples pass against today's styles. They are guards, so there is no red step here; Phase 1's red step is the proof that the helper sees cropping.

- [ ] Create `spec/support/card_images.rb`:

```ruby
# Card images in system specs (spec 019, Testability). The suite's browser must never ask a catalog source for a
# picture, so a test entry's image address is https on a port Firefox refuses to open: the page renders the <img>
# and nothing leaves the machine. An example then hands each rendered <img> a picture as a data: address and reads
# back where the browser's own fitting rules put it.
module CardImages
  HOST = "127.0.0.1".freeze
  EDGE = 0.01 # CSS pixels: rounding in the browser's layout units

  # One <img>'s fit, in CSS pixels. `slot` and `box` are content boxes ([width, height]); `painted` is the picture's
  # [left, top, width, height] inside the box, from the computed object-fit and object-position (CSS Images 3,
  # section 5.5), which is how the browser places it.
  Fit = Data.define(:fit, :slot, :box, :natural, :painted, :ground, :sunken) do
    # What is wrong with this fit, in words; empty when the image is shown whole, in its own proportions, centred and
    # as large as its 63:88 slot allows, on surface-sunken.
    def faults
      left, top, width, height = painted
      [].tap do |faults|
        faults << "cropped: #{describe}" if left < -EDGE || top < -EDGE || left + width > box[0] + EDGE || top + height > box[1] + EDGE
        faults << "stretched: #{describe}" unless ((width / natural[0]) / (height / natural[1]) - 1).abs <= 0.001
        faults << "off centre: #{describe}" unless (box[0] - width - 2 * left).abs <= EDGE && (box[1] - height - 2 * top).abs <= EDGE
        faults << "smaller than its box: #{describe}" unless (box[0] - width).abs <= EDGE || (box[1] - height).abs <= EDGE
        faults << "slot is #{slot.join(' × ')}, not 63:88" unless (slot[1] - slot[0] * 88 / 63.0).abs <= 0.1
        faults << "ground is #{ground}, not surface-sunken (#{sunken})" unless ground == sunken
      end
    end

    def describe
      "a #{natural.join(' × ')} picture painted #{painted.last(2).map { it.round(2) }.join(' × ')} " \
        "at #{painted.first(2).map { it.round(2) }.join(', ')} in a #{box.join(' × ')} box (object-fit: #{fit})"
    end
  end

  # arguments: a selector for the images, the pictures to give them in turn (none: measure them as they are).
  FITS = <<~JS.freeze
    const [ selector, pictures, done ] = arguments
    const px = (value) => parseFloat(value) || 0
    const round = (value) => Math.round(value * 1000) / 1000 // the browser reports sizes with float noise far below this
    const inner = (element) => {
      const style = getComputedStyle(element), rect = element.getBoundingClientRect()
      return [ rect.width - px(style.borderLeftWidth) - px(style.borderRightWidth) - px(style.paddingLeft) - px(style.paddingRight),
        rect.height - px(style.borderTopWidth) - px(style.borderBottomWidth) - px(style.paddingTop) - px(style.paddingBottom) ].map(round)
    }
    const probe = document.body.appendChild(document.createElement("i"))
    probe.style.backgroundColor = "var(--surface-sunken)"
    const sunken = getComputedStyle(probe).backgroundColor
    probe.remove()
    const groundOf = (image, slot) => {
      for (let element = image; element; element = element.parentElement) {
        const colour = getComputedStyle(element).backgroundColor
        if (colour !== "rgba(0, 0, 0, 0)" && colour !== "transparent") return colour
        if (element === slot) return null
      }
    }
    const fitOf = (image) => {
      const slot = image.closest(".c-tile__media, .c-item__image") || image
      const style = getComputedStyle(image), [ boxWidth, boxHeight ] = inner(image)
      const [ naturalWidth, naturalHeight ] = [ image.naturalWidth, image.naturalHeight ]
      const contain = Math.min(boxWidth / naturalWidth, boxHeight / naturalHeight)
      const cover = Math.max(boxWidth / naturalWidth, boxHeight / naturalHeight)
      const [ scaleX, scaleY ] = { fill: [ boxWidth / naturalWidth, boxHeight / naturalHeight ], contain: [ contain, contain ],
        cover: [ cover, cover ], none: [ 1, 1 ], "scale-down": [ Math.min(1, contain), Math.min(1, contain) ] }[style.objectFit]
      const [ width, height ] = [ naturalWidth * scaleX, naturalHeight * scaleY ]
      const [ shareX, shareY ] = style.objectPosition.split(" ").map((share) => parseFloat(share) / 100)
      return { fit: style.objectFit, slot: inner(slot), box: [ boxWidth, boxHeight ], natural: [ naturalWidth, naturalHeight ],
        painted: [ (boxWidth - width) * shareX, (boxHeight - height) * shareY, width, height ], ground: groundOf(image, slot), sunken }
    }
    const images = [ ...document.querySelectorAll(selector) ]
    Promise.all(images.map((image, index) => pictures.length && new Promise((resolve, reject) => {
      image.addEventListener("load", resolve, { once: true })
      image.addEventListener("error", () => reject(new Error("a test picture did not load")), { once: true })
      image.loading = "eager"
      image.src = pictures[index % pictures.length]
    }))).then(() => done(images.map(fitOf)), (error) => done({ error: String(error) }))
  JS

  # arguments: a selector. Each matching element's top edge, border box (outer), content box and row height (null outside
  # a table).
  BOXES = <<~JS.freeze
    const px = (value) => parseFloat(value) || 0
    const round = (value) => Math.round(value * 1000) / 1000 // the browser reports sizes with float noise far below this
    return [ ...document.querySelectorAll(arguments[0]) ].map((element) => {
      const style = getComputedStyle(element), rect = element.getBoundingClientRect(), row = element.closest("tr")
      return { tag: element.tagName.toLowerCase(), top: round(rect.top), outer: [ rect.width, rect.height ].map(round),
        box: [ rect.width - px(style.borderLeftWidth) - px(style.borderRightWidth) - px(style.paddingLeft) - px(style.paddingRight),
          rect.height - px(style.borderTopWidth) - px(style.borderBottomWidth) - px(style.paddingTop) - px(style.paddingBottom) ].map(round),
        row: row && round(row.getBoundingClientRect().height) }
    })
  JS

  # An image address catalog_url accepts (with `:card_images`) and nothing answers.
  def card_image_address(name = "card") = "https://#{HOST}:9/#{name}.png"

  # A plain picture of the given size, as a data: address.
  def card_picture(width, height)
    "data:image/png;base64,#{Base64.strict_encode64(png_bytes(width, height) { [ 196, 30, 90 ] })}"
  end

  # The fit of every image matching the selector, after giving them the pictures in turn (they repeat).
  def card_image_fits(selector, pictures: [])
    result = page.evaluate_async_script(FITS, selector, pictures)
    raise result["error"] if result.is_a?(Hash)

    result.map { |fit| Fit.new(**fit.to_h { |key, value| [ key.to_sym, value.is_a?(Array) ? value.map(&:to_f) : value ] }) }
  end

  def card_slot_boxes(selector) = page.evaluate_script("(function () { #{BOXES} })(#{selector.to_json})")

  def use_dark_theme = page.execute_script("document.documentElement.dataset.theme = 'dark'")
end

RSpec.configure do |config|
  config.include CardImages, type: :system
  # catalog_url passes https addresses on a source's hosts only; these examples add the one nothing answers.
  config.before(:each, :card_images) do
    allow(Catalog).to receive(:allowed_hosts).and_return(Catalog.allowed_hosts + [ CardImages::HOST ])
  end
end
```

- [ ] Create `spec/system/card_image_fit_spec.rb`:

```ruby
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
```

- [ ] Run: `bin/rspec spec/system/card_image_fit_spec.rb` — expect: `2 examples, 0 failures`.
- [ ] Run: `bin/rubocop spec/support/card_images.rb spec/system/card_image_fit_spec.rb` — expect: `no offenses detected`.
- [ ] Commit: `test(design): give the browser test card pictures without the network`

---

## Phase 1: Tiles and the card page show the whole image

**Implements:** FR-1, FR-2, FR-3 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-1.8, AC-2.1, AC-2.2, AC-2.3, AC-2.4, AC-4.4 (first half and the red step)
**Files:** `spec/system/card_image_fit_spec.rb`, `spec/requests/scanner/readings_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: everything Phase 0 produces. Produces: `two_faced_entry` in the spec file; the `Image fit (spec 019)` block in `additions.css`, which Phases 2 and 3 add one line each to.

The export's `cover` becomes `contain` for the image in a tile (collection grid, search results, scanner candidates) and on the card page. The scanner's candidate is covered by markup (AC-1.4): it uses the tile slot, so the tile's rule reaches it.

- [ ] Add the failing examples to `spec/system/card_image_fit_spec.rb`:

```diff
--- a/spec/system/card_image_fit_spec.rb
+++ b/spec/system/card_image_fit_spec.rb
@@ -17,6 +17,12 @@ RSpec.describe "Card image fit", :card_images, type: :system do
     owned_printing(name, account: user.account, **attributes).tap { |lot| lot.entry.update!(image_url: card_image_address) }
   end
 
+  def two_faced_entry
+    create(:mtg_printing).tap do |printing|
+      printing.update!(faces: %w[front back].map { |face| { "name" => face.capitalize, "image_uris" => { "normal" => card_image_address(face) } } })
+    end.entry
+  end
+
   describe "tiles" do
     let(:images) { ".c-grid .c-tile__media img" }
 
@@ -29,6 +35,43 @@ RSpec.describe "Card image fit", :card_images, type: :system do
       expect(card_image_fits(images, pictures: [ wide ]).sole.natural).to eq([ 40.0, 20.0 ])
     end
 
+    it "shows images of any proportions whole, in equal 63:88 slots, in both themes (AC-1.1, AC-1.2, AC-1.5, AC-1.6)", :aggregate_failures do
+      %w[Bolt Opt Shock].each { |name| owned_with_image(name) }
+      visit collection_path(view: "grid")
+      expect(page).to have_css(images, count: 3)
+
+      fits = card_image_fits(images, pictures: [ square, tall, wide ])
+      expect(fits.flat_map(&:faults)).to be_empty
+      expect(fits.map(&:slot).uniq.size).to eq(1)
+
+      use_dark_theme
+      dark = card_image_fits(images)
+      expect(dark.flat_map(&:faults)).to be_empty
+      expect(dark.first.ground).not_to eq(fits.first.ground)
+    end
+
+    it "shows the whole image in search results, faded for a card you don't own (AC-1.3, AC-1.8)", :aggregate_failures do
+      user
+      create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", image_url: card_image_address))
+      visit catalog_entries_path(q: "bolt")
+      expect(page).to have_css(images, count: 1)
+
+      expect(card_image_fits(images, pictures: [ square ]).flat_map(&:faults)).to be_empty
+      expect(page.evaluate_script("getComputedStyle(document.querySelector(#{images.to_json})).opacity")).to eq("0.45")
+    end
+
+    it "shows the whole image at phone width (AC-1.1, AC-1.2)", :aggregate_failures do
+      %w[Bolt Opt].each { |name| owned_with_image(name) }
+      visit collection_path(view: "grid")
+
+      expect(open_in_narrow_frame(collection_path(view: "grid"), width: 390, height: 844, ready: ".c-grid")).to eq([ 390, true ])
+      within_narrow_frame do
+        fits = card_image_fits(images, pictures: [ square, tall ])
+        expect(fits.size).to eq(2)
+        expect(fits.flat_map(&:faults)).to be_empty
+      end
+    end
+
     it "keeps the fallback, the quantity badge and the slot's shape (AC-1.7, AC-1.8)", :aggregate_failures do
       owned_with_image("Bolt", quantity: 4)
       owned_printing("Opt", account: user.account)
@@ -49,4 +92,36 @@ RSpec.describe "Card image fit", :card_images, type: :system do
       expect(badge).to eq([ 5, 5 ])
     end
   end
+
+  describe "the card page" do
+    let(:images) { ".c-item__image img" }
+
+    it "shows each face's image whole in its own 63:88 slot, in both themes (AC-2.1, AC-2.3, AC-2.4)", :aggregate_failures do
+      user
+      visit catalog_entry_path(two_faced_entry)
+      expect(page).to have_css(images, count: 2)
+      expect(page.evaluate_script("window.innerWidth")).to eq(1280)
+
+      fits = card_image_fits(images, pictures: [ square, tall ])
+      expect(fits.flat_map(&:faults)).to be_empty
+
+      use_dark_theme
+      dark = card_image_fits(images)
+      expect(dark.flat_map(&:faults)).to be_empty
+      expect(dark.first.ground).not_to eq(fits.first.ground)
+    end
+
+    it "shows the whole image at phone width, with no sideways scroll (AC-2.2)", :aggregate_failures do
+      user
+      entry = two_faced_entry
+      visit catalog_entry_path(entry)
+
+      expect(open_in_narrow_frame(catalog_entry_path(entry), width: 390, height: 844, ready: ".c-item")).to eq([ 390, true ])
+      within_narrow_frame do
+        fits = card_image_fits(images, pictures: [ wide, tall ])
+        expect(fits.size).to eq(2)
+        expect(fits.flat_map(&:faults)).to be_empty
+      end
+    end
+  end
 end
```

- [ ] Add the markup guard to `spec/requests/scanner/readings_spec.rb` (it passes before and after: it holds the markup the rule depends on):

```diff
--- a/spec/requests/scanner/readings_spec.rb
+++ b/spec/requests/scanner/readings_spec.rb
@@ -31,6 +31,14 @@ RSpec.describe "Scanner readings", type: :request do
       expect(response.body).not_to include("Matched by its collector line")
     end
 
+    it "puts a candidate's image in the tile slot, with no class or style of its own (spec 019 AC-1.4)", :aggregate_failures do
+      bolt.update!(image_url: "https://cards.scryfall.io/normal/front/b/o/bolt.jpg")
+      read("Lightning Bolt", "")
+      image = Nokogiri::HTML5(response.body).at_css(".c-scanner__candidate .c-tile__media > img")
+      expect(image&.[]("src")).to eq(bolt.image_url)
+      expect([ image["class"], image["style"] ]).to eq([ nil, nil ])
+    end
+
     it "says when the collector line matches several printings or none (AC-3.3)", :aggregate_failures do
       create(:mtg_printing, entry: create(:catalog_entry, identity: bolt.identity, name: "Lightning Bolt", set: mom, number: "123"))
       read("Lightning Bolt", "R 0123\nMOM • EN")
```

- [ ] Run: `bin/rspec spec/system/card_image_fit_spec.rb spec/requests/scanner/readings_spec.rb` — expect: FAIL, `28 examples, 5 failures`. The five are the three new tile examples and the two card page examples, each with faults like `"cropped: a 40.0 × 40.0 picture painted 219.9 × 219.9 at -31.23, 0.0 in a 157.433 × 219.9 box (object-fit: cover)"`. This is AC-4.4's second half: without the override, the examples fail.
- [ ] Implement. In `app/assets/stylesheets/collector/additions.css`, add the block between the `Tile with an add control outside its link` block and the `Select inside the filter bar` block:

```diff
--- a/app/assets/stylesheets/collector/additions.css
+++ b/app/assets/stylesheets/collector/additions.css
@@ -66,6 +66,11 @@
 .c-tile__add { display:flex; }
 .c-tile__add .c-btn { width:100%; justify-content:flex-start; }
 
+/* ---------- Image fit (spec 019): a card image is shown whole and in its own proportions inside its 63:88 slot ---------- */
+/* Overrides the export until the published design system fits images this way; then delete this block. Any leftover
+   shows the slot's surface-sunken ground. */
+.c-tile__media img, .c-item__image img { object-fit:contain; } /* the export crops with cover */
+
 /* ---------- Select inside the filter bar ---------- */
 .c-select select { height:28px; max-width:220px; padding:0 var(--space-2); background:var(--surface-raised); color:var(--ink);
   border:1px solid var(--line-strong); border-radius:var(--radius-md); font:400 13px/18px var(--font-sans); }
```

- [ ] Run: `bin/rspec spec/system/card_image_fit_spec.rb spec/requests/scanner/readings_spec.rb` — expect: PASS, `28 examples, 0 failures`.
- [ ] Run: `bin/rubocop spec/system/card_image_fit_spec.rb spec/requests/scanner/readings_spec.rb` — expect: `no offenses detected`.
- [ ] Commit: `fix(design): show card images whole in tiles and on the card page`

---

## Phase 2: The table thumbnail isn't stretched

**Implements:** FR-1, FR-2, FR-3 | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-4.4
**Files:** `spec/system/card_image_fit_spec.rb`, `app/assets/stylesheets/collector/additions.css`, `docs/specs/019-uncropped-card-images/verification.md` (new)
**Interfaces:** Consumes: Phase 0's helpers; Phase 1's block. Produces: `verification.md` with its `## Table thumbnail, measured` section, which Phase 5 completes.

The thumbnail's image gets `height:auto`, so the tag's `height="34"` hint no longer beats `aspect-ratio`, and `object-fit:contain`. The stretch was reasoned in the spec's first draft; the maintainer asked for it to be measured in the browser before and after, so this phase measures it both times and records the numbers.

- [ ] Save the measurement script in your session's scratchpad as `thumbnail_measure_spec.rb`. It is never committed:

```ruby
require "rails_helper"
require "open3"

# Spec 019: the table thumbnail measured in the browser, for verification.md. Run from the scratchpad, never committed:
#   OUT=<directory> bin/rspec <this file>
# It writes thumbnail.txt: the image thumbnail's and the empty thumbnail's boxes, where a Scryfall-sized picture is painted according
# to the computed fit, and the rectangle of picture-coloured pixels in a screenshot of the thumbnail (1px border included).
RSpec.describe "Thumbnail measurement", :card_images, type: :system do
  def picture_pixels(element, path)
    element.native.save_screenshot(path)
    Open3.capture2("magick", path, "-fuzz", "12%", "-fill", "white", "-opaque", "rgb(196,30,90)", "-fill", "black", "+opaque", "white",
      "-format", "%@ of %wx%h", "info:").first
  end

  it "writes the thumbnail's boxes and painted picture", :aggregate_failures do
    user = system_sign_in_as(create(:user))
    owned_printing("Bolt", account: user.account).entry.update!(image_url: card_image_address)
    owned_printing("Opt", account: user.account)
    visit collection_path(view: "table")
    expect(page).to have_css(".c-table__thumb", count: 2)

    fit = card_image_fits("img.c-table__thumb", pictures: [ card_picture(488, 680) ]).sole
    lines = card_slot_boxes(".c-table__thumb").map { |slot| "#{slot['tag']}: box #{slot['box'].join(' × ')}, row #{slot['row']}" }
    lines << "object-fit #{fit.fit}: a 488 × 680 picture painted #{fit.painted.last(2).map { it.round(3) }.join(' × ')} " \
      "(#{(100 * ((fit.painted[3] / 680) / (fit.painted[2] / 488) - 1)).round(2)}% taller than its proportions)"
    lines << "pixels: #{picture_pixels(find('img.c-table__thumb'), File.join(ENV.fetch('OUT'), 'thumbnail.png'))}"
    File.write(File.join(ENV.fetch("OUT"), "thumbnail.txt"), "#{lines.join("\n")}\n")
    expect(fit.natural).to eq([ 488.0, 680.0 ])
  end
end
```

- [ ] Measure before. Run: `OUT=<scratchpad> bin/rspec <scratchpad>/thumbnail_measure_spec.rb` — expect `1 example, 0 failures`, and `<scratchpad>/thumbnail.txt` reading:

```text
img: box 24 × 34, row 53
span: box 24 × 33.517, row 52.517
object-fit fill: a 488 × 680 picture painted 24.0 × 34.0 (1.67% taller than its proportions)
pixels: 24x34+1+1 of 26x36
```

  Keep that text for `verification.md`. (`pixels` counts the picture's pixels in a screenshot of the thumbnail, which includes its 1px border.)
- [ ] Add the failing examples to `spec/system/card_image_fit_spec.rb`:

```diff
--- a/spec/system/card_image_fit_spec.rb
+++ b/spec/system/card_image_fit_spec.rb
@@ -124,4 +124,52 @@ RSpec.describe "Card image fit", :card_images, type: :system do
       end
     end
   end
+
+  describe "the table thumbnail" do
+    let(:images) { "img.c-table__thumb" }
+
+    it "shows a Scryfall-sized image in its own proportions (AC-3.1)", :aggregate_failures do
+      owned_with_image("Bolt")
+      visit collection_path(view: "table")
+      expect(page).to have_css(images, count: 1)
+
+      expect(card_image_fits(images, pictures: [ card_picture(488, 680) ]).flat_map(&:faults)).to be_empty
+    end
+
+    it "shows images of any proportions whole, in slots and rows of one size, in both themes (AC-3.2, AC-3.3, AC-3.4)", :aggregate_failures do
+      %w[Bolt Opt].each { |name| owned_with_image(name) }
+      owned_printing("Shock", account: user.account)
+      visit collection_path(view: "table")
+      expect(page).to have_css(".c-table__thumb", count: 3)
+
+      # The two images have failed to load at this point, and still take the empty slot's size.
+      expect(card_slot_boxes(".c-table__thumb").pluck("box").uniq.size).to eq(1)
+      fits = card_image_fits(images, pictures: [ square, tall ])
+      expect(fits.flat_map(&:faults)).to be_empty
+      thumbs = card_slot_boxes(".c-table__thumb")
+      expect(thumbs.pluck("tag")).to contain_exactly("img", "img", "span")
+      expect(thumbs.pluck("box").uniq.size).to eq(1)
+      expect(thumbs.pluck("row").uniq.size).to eq(1)
+
+      use_dark_theme
+      dark = card_image_fits(images)
+      expect(dark.flat_map(&:faults)).to be_empty
+      expect(dark.first.ground).not_to eq(fits.first.ground)
+    end
+
+    it "keeps slots and rows of one size at phone width (AC-3.2, AC-3.3)", :aggregate_failures do
+      %w[Bolt Opt].each { |name| owned_with_image(name) }
+      owned_printing("Shock", account: user.account)
+      visit collection_path(view: "table")
+
+      expect(open_in_narrow_frame(collection_path(view: "table"), width: 390, height: 844, ready: "table.c-table")).to eq([ 390, true ])
+      within_narrow_frame do
+        expect(card_image_fits(images, pictures: [ tall, wide ]).flat_map(&:faults)).to be_empty
+        thumbs = card_slot_boxes(".c-table__thumb")
+        expect(thumbs.size).to eq(3)
+        expect(thumbs.pluck("box").uniq.size).to eq(1)
+        expect(thumbs.pluck("row").uniq.size).to eq(1)
+      end
+    end
+  end
 end
```

- [ ] Run: `bin/rspec spec/system/card_image_fit_spec.rb` — expect: FAIL, `10 examples, 3 failures`: the three thumbnail examples, with `"stretched: a 488.0 × 680.0 picture painted 24.0 × 34.0 at 0.0, 0.0 in a 24.0 × 34.0 box (object-fit: fill)"` and `"slot is 24.0 × 34.0, not 63:88"`, and two sizes where one is expected for the slots and the rows.
- [ ] Implement. Add one line to the block in `app/assets/stylesheets/collector/additions.css`:

```diff
--- a/app/assets/stylesheets/collector/additions.css
+++ b/app/assets/stylesheets/collector/additions.css
@@ -70,6 +70,7 @@
 /* Overrides the export until the published design system fits images this way; then delete this block. Any leftover
    shows the slot's surface-sunken ground. */
 .c-tile__media img, .c-item__image img { object-fit:contain; } /* the export crops with cover */
+img.c-table__thumb { height:auto; object-fit:contain; } /* the export stretches: the tag's height="34" beats aspect-ratio */
 
 /* ---------- Select inside the filter bar ---------- */
 .c-select select { height:28px; max-width:220px; padding:0 var(--space-2); background:var(--surface-raised); color:var(--ink);
```

- [ ] Run: `bin/rspec spec/system/card_image_fit_spec.rb` — expect: PASS, `10 examples, 0 failures`.
- [ ] Measure after. Run the measurement script again — expect `thumbnail.txt` reading:

```text
img: box 24 × 33.517, row 52.517
span: box 24 × 33.517, row 52.517
object-fit contain: a 488 × 680 picture painted 24.0 × 33.443 (0.0% taller than its proportions)
pixels: 24x34+1+1 of 26x35
```

- [ ] Run: `bin/rubocop spec/system/card_image_fit_spec.rb` — expect: `no offenses detected`.
- [ ] Commit: `fix(design): stop the table thumbnail stretching its image`
- [ ] Create `docs/specs/019-uncropped-card-images/verification.md` with this content, putting the two texts you measured in the two blocks (if a number differs from the plan's, record what you measured and say so in a line under the block):

````markdown
# Verification: Fit Card Images Without Cropping (spec 019)

**Spec:** [spec.md](spec.md) v1.3.0 · **Plan:** [plan.md](plan.md) · **Branch:** `019-uncropped-card-images`

## Table thumbnail, measured

Measured in the suite's browser (headless Firefox, window 1400px wide) with the plan's measurement script, on the commit before the thumbnail's rule and on the commit that adds it. Each text gives the image thumbnail's and the empty thumbnail's content boxes and row heights, where a 488 × 680 picture (Scryfall's `normal` size) is painted according to the computed fit, and the picture's pixels in a screenshot of the thumbnail (its 1px border included).

Before (`<sha of Phase 1's commit>`):

```text
<thumbnail.txt as measured before>
```

After (`<sha of Phase 2's fix commit>`):

```text
<thumbnail.txt as measured after>
```

The image was stretched: its box was 24 × 34 with `object-fit: fill`, half a pixel taller than the empty thumbnail, so the picture was drawn 1.67% too tall. It is now drawn in its own proportions inside a box of the empty thumbnail's size, and both kinds of row have one height. A screenshot can't show a half-pixel change at this size; the box and the computed fit can.

## Acceptance criteria

## Local gate

## Commits

## Phone browser
````

- [ ] Commit: `docs(019): record the thumbnail as measured before and after`

---

## Phase 3: The card page's fallback sits in its own slot

**Implements:** FR-1, FR-3 | **Satisfies:** AC-2.5, AC-4.3
**Files:** `spec/system/card_image_fit_spec.rb`, `spec/design_system_files_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: Phase 0's `card_slot_boxes`; Phase 1's block. Produces: the complete block (three rules), and in `spec/design_system_files_spec.rb` the `describe "the image fit override (spec 019)"` group with its `additions` and `block` lets, which Phase 4 adds one example to.

`c-item__image` gets `position:relative`, so a face's fallback fills that face's slot and no longer lies over another face's image (decision 4). This completes the block, so the example that holds the block's shape (AC-4.3) arrives here too.

- [ ] Add the failing example to `spec/system/card_image_fit_spec.rb`:

```diff
--- a/spec/system/card_image_fit_spec.rb
+++ b/spec/system/card_image_fit_spec.rb
@@ -123,6 +123,22 @@ RSpec.describe "Card image fit", :card_images, type: :system do
         expect(fits.flat_map(&:faults)).to be_empty
       end
     end
+
+    it "keeps the fallback inside its own 63:88 slot, clear of another face's image (AC-2.5)", :aggregate_failures do
+      user
+      printing = create(:mtg_printing)
+      printing.update!(faces: [ { "name" => "Front", "image_uris" => { "normal" => card_image_address("front") } },
+        { "name" => "Back", "image_uris" => {} } ])
+      visit catalog_entry_path(printing.entry)
+      expect(page).to have_css(".c-item__image", count: 2)
+
+      slots = card_slot_boxes(".c-item__image")
+      fallback = card_slot_boxes(".c-item__image .c-tile__missing").sole
+      expect(slots.pluck("box").uniq.size).to eq(1)
+      expect(slots.last["box"][1]).to be_within(0.1).of(slots.last["box"][0] * 88 / 63.0)
+      expect(fallback["outer"]).to eq(slots.last["box"])
+      expect(fallback["top"]).to be_within(0.01).of(slots.last["top"] + 1) # inside the slot's 1px border
+    end
   end
 
   describe "the table thumbnail" do
```

- [ ] Add the block's shape example to `spec/design_system_files_spec.rb`, in a `describe` of its own at the end of the file:

```diff
--- a/spec/design_system_files_spec.rb
+++ b/spec/design_system_files_spec.rb
@@ -35,4 +35,17 @@ RSpec.describe "Design system files" do
   it "removes feature 002's ad-hoc catalog styles" do
     expect(root.join("app/assets/stylesheets/application.css").read).not_to include(".catalog")
   end
+
+  describe "the image fit override (spec 019)" do
+    let(:additions) { root.join("app/assets/stylesheets/collector/additions.css").read }
+    let(:block) { additions[%r{/\* -+ Image fit \(spec 019\).*?(?=\n\n/\* -|\z)}m] }
+
+    it "keeps the rules in one block of their own, with no colour literal or font (AC-4.3)", :aggregate_failures do
+      expect(additions.scan("spec 019").size).to eq(1)
+      expect(block).to include(".c-tile__media img, .c-item__image img { object-fit:contain; }",
+        "img.c-table__thumb { height:auto; object-fit:contain; }", ".c-item__image { position:relative; }")
+      expect(block.scan(/^[^\s\/].*\{/).size).to eq(3)
+      expect(block).not_to match(/#\h{3,8}\b|rgba?\(|hsla?\(|font/i)
+    end
+  end
 end
```

- [ ] Run: `bin/rspec spec/system/card_image_fit_spec.rb spec/design_system_files_spec.rb` — expect: FAIL, `16 examples, 2 failures`. The fallback example fails with `expected: [298, 416.25]` / `got: [300, 892.5]` and `expected 123 to be within 0.01 of 550.25`. The shape example fails because the block doesn't hold `.c-item__image { position:relative; }` and has 2 rules, not 3.
- [ ] Implement. Add one line to the block in `app/assets/stylesheets/collector/additions.css`:

```diff
--- a/app/assets/stylesheets/collector/additions.css
+++ b/app/assets/stylesheets/collector/additions.css
@@ -71,6 +71,7 @@
    shows the slot's surface-sunken ground. */
 .c-tile__media img, .c-item__image img { object-fit:contain; } /* the export crops with cover */
 img.c-table__thumb { height:auto; object-fit:contain; } /* the export stretches: the tag's height="34" beats aspect-ratio */
+.c-item__image { position:relative; } /* holds the missing-image fallback inside its own slot */
 
 /* ---------- Select inside the filter bar ---------- */
 .c-select select { height:28px; max-width:220px; padding:0 var(--space-2); background:var(--surface-raised); color:var(--ink);
```

- [ ] Run: `bin/rspec spec/system/card_image_fit_spec.rb spec/design_system_files_spec.rb` — expect: PASS, `16 examples, 0 failures`.
- [ ] Run: `bin/rspec spec/system/card_page_spec.rb spec/requests/catalog/entries_show_spec.rb` — expect: PASS (the card page's existing examples, including its sticky image column and its phone layout).
- [ ] Run: `bin/rubocop spec/system/card_image_fit_spec.rb spec/design_system_files_spec.rb` — expect: `no offenses detected`.
- [ ] Commit: `fix(design): keep the card page's image fallback inside its slot`

---

## Phase 4: The design system documents the override

**Implements:** FR-4 | **Satisfies:** AC-4.1, AC-4.2
**Files:** `spec/design_system_files_spec.rb`, `docs/design-system/components/ImageFit.md` (new), `docs/design-system/README.md`
**Interfaces:** Consumes: Phase 3's `describe "the image fit override (spec 019)"` group. Produces: the `ImageFit` pattern doc and its README line.

- [ ] Add the failing example to `spec/design_system_files_spec.rb`:

```diff
--- a/spec/design_system_files_spec.rb
+++ b/spec/design_system_files_spec.rb
@@ -40,6 +40,12 @@ RSpec.describe "Design system files" do
     let(:additions) { root.join("app/assets/stylesheets/collector/additions.css").read }
     let(:block) { additions[%r{/\* -+ Image fit \(spec 019\).*?(?=\n\n/\* -|\z)}m] }
 
+    it "documents the pattern, its three slots and that it overrides the export (AC-4.1, AC-4.2)", :aggregate_failures do
+      expect(root.join("docs/design-system/components/ImageFit.md").read).to include("`c-tile__media`", "`c-item__image`",
+        "`c-table__thumb`", "whole and in its own proportions", "`surface-sunken`", "overrides the export", "Upstream it")
+      expect(root.join("docs/design-system/README.md").read).to match(/^App additions \(spec 019, .*`ImageFit`.*Upstream it/)
+    end
+
     it "keeps the rules in one block of their own, with no colour literal or font (AC-4.3)", :aggregate_failures do
       expect(additions.scan("spec 019").size).to eq(1)
       expect(block).to include(".c-tile__media img, .c-item__image img { object-fit:contain; }",
```

- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect: FAIL, `6 examples, 1 failure`, with `Errno::ENOENT` for `docs/design-system/components/ImageFit.md`.
- [ ] Create `docs/design-system/components/ImageFit.md`:

````markdown
# ImageFit

How a card image sits in its slot: whole and in its own proportions, never cropped or stretched. It overrides the export until the published design system fits images this way.

**Markup** — unchanged. The rule applies to the image in each of the three slots: the tile's, the card page's and the table thumbnail's.

```html
<div class="c-tile__media"><img src="…" alt="Lightning Bolt" loading="lazy" width="146" height="204"></div>
<div class="c-item__image"><img src="…" alt="Lightning Bolt" width="300" height="419"></div>
<img class="c-table__thumb" src="…" alt="" width="24" height="34" loading="lazy">
```

- A slot keeps the card's 63:88 shape whatever the image's proportions, so grid rows and table rows line up and nothing moves when an image loads.
- The image is scaled to the largest size that fits inside the slot and centred. Where its proportions differ from 63:88, the leftover shows the slot's `surface-sunken` ground, equal on both sides.
- Never use `object-fit: cover` or `fill` on an item's image, and never size a slot from its image. A source's terms may forbid cropping or distorting its images; Scryfall's do.
- The thumbnail's `width` and `height` attributes are layout hints only. Its height comes from 63:88 of its 24px width, so it matches the empty thumbnail shown when there is no image.
- The card page's slot is positioned, so the missing-image fallback (`c-tile__missing`) stays inside its own slot and never lies over another face's image.
- A new image slot (a comic's cover, a deck's card list) follows the same rule: a fixed slot, with the whole image inside it.
- This overrides the export, whose `c-tile__media` and `c-item__image` crop with `cover` and whose `c-table__thumb` stretches the image to its box. Upstream it; once an export carries it, delete the block from `collector/additions.css`.
````

- [ ] Add the pattern's line to `docs/design-system/README.md`, after the spec 015 line:

```diff
--- a/docs/design-system/README.md
+++ b/docs/design-system/README.md
@@ -96,6 +96,8 @@ App additions (spec 007, in `collector/additions.css`): `Scanner`. Upstream it i
 
 App additions (spec 015, in `collector/additions.css`): `AdminJobs`, `AdminCatalog`, `StageList`, `ProgressMeter`. Upstream these into the published design system before the next export replaces this folder.
 
+App additions (spec 019, in `collector/additions.css`): `ImageFit`. It overrides the export's image fitting. Upstream it into the published design system before the next export replaces this folder.
+
 ## Logo
 
 - The mark is three fanned cards, the front one vault teal with a foil diamond: a collection, one piece of which is special. It is deliberately game-neutral so it grows past trading cards.
```

- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect: PASS, `6 examples, 0 failures`.
- [ ] Run: `bin/rubocop spec/design_system_files_spec.rb` — expect: `no offenses detected`.
- [ ] Commit: `docs(design): document the image fit override`

---

## Phase 5: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs; AC-4.5 and the Reliability requirement by evidence
**Files:** `docs/specs/019-uncropped-card-images/screenshots/` (new, 12 images), `docs/specs/019-uncropped-card-images/verification.md`
**Interfaces:** Consumes: everything above. Produces: the evidence the pull request shows.

- [ ] Run the local gate: `bin/ci` — expect: every step green; RSpec reports `1133 examples, 0 failures, 1 pending` (the pending one is the art agreement example, which needs `COLLECTOR_ART_AGREEMENT`). If the count differs because `main` moved, the failures must still be 0.
- [ ] Confirm the exported files and the views are untouched. Run: `git diff --stat main -- app/assets/stylesheets/collector/components.css app/assets/stylesheets/collector/tokens.css app/views docs/design-system/components/ItemTile.md docs/design-system/components/ItemPage.md docs/design-system/components/CollectionTable.md` — expect: no output.
- [ ] Confirm the whole change. Run: `git diff --stat main -- app spec docs/design-system` — expect exactly these seven files: `app/assets/stylesheets/collector/additions.css` (7 lines added), `docs/design-system/README.md` (2), `docs/design-system/components/ImageFit.md` (new), `spec/design_system_files_spec.rb` (19), `spec/requests/scanner/readings_spec.rb` (8), `spec/support/card_images.rb` (new), `spec/system/card_image_fit_spec.rb` (new).
- [ ] Save the screenshot script in your session's scratchpad as `capture_spec.rb`. It is never committed:

```ruby
require "rails_helper"

# Spec 019 AC-4.5: screenshots of the three slots with pictures that aren't 63:88, in both themes, at 1280px and 390px.
# Run from the scratchpad, never committed: OUT=<directory> bin/rspec <this file>
RSpec.describe "Card image fit screenshots", :card_images, type: :system do
  let(:out) { Pathname(ENV.fetch("OUT")) }
  let(:user) { system_sign_in_as(create(:user)) }
  let(:pictures) { [ card_picture(40, 40), card_picture(20, 40), card_picture(40, 20), card_picture(488, 680) ] }

  before { page.current_window.resize_to(1280, 900) }
  after { page.current_window.resize_to(1400, 1400) }

  def stock
    %w[Bolt Opt Shock Ponder].each do |name|
      owned_printing(name, account: user.account, quantity: 2).entry.update!(image_url: card_image_address)
    end
    owned_printing("Duress", account: user.account)
  end

  def two_faced_entry
    create(:mtg_printing).tap do |printing|
      printing.update!(faces: %w[front back].map { |face| { "name" => face.capitalize, "image_uris" => { "normal" => card_image_address(face) } } })
    end.entry
  end

  # Both themes of the page as it stands, at 1280px. The pause lets the buttons' colour transition finish.
  def shoot_wide(name, images)
    card_image_fits(images, pictures:)
    find("h1").hover # off the tiles, so none is shot in its hover lift
    %w[light dark].each do |theme|
      page.execute_script("document.documentElement.dataset.theme = arguments[0]", theme)
      sleep 0.6 # rubocop:disable Capybara/RSpec/NoSleep -- a screenshot script waiting out a CSS transition, not a spec
      page.save_screenshot(out.join("#{name}-1280-#{theme}.png").to_s)
    end
  end

  # Both themes at 390px: the page in a frame as tall as its content, shot as an element.
  def shoot_phone(name, path, images, ready:)
    open_in_narrow_frame(path, width: 390, height: 844, ready:)
    within_narrow_frame { card_image_fits(images, pictures:) }
    height = within_narrow_frame { page.evaluate_script("document.documentElement.scrollHeight") }
    page.execute_script("document.getElementById('narrow').style.height = arguments[0] + 'px'", height)
    page.current_window.resize_to(1280, height + 200)
    %w[light dark].each do |theme|
      within_narrow_frame { page.execute_script("document.documentElement.dataset.theme = arguments[0]", theme) }
      sleep 0.6 # rubocop:disable Capybara/RSpec/NoSleep -- as above
      find("#narrow").native.save_screenshot(out.join("#{name}-390-#{theme}.png").to_s)
    end
  end

  it "shoots the collection grid" do
    stock
    visit collection_path(view: "grid")
    shoot_wide("grid", ".c-grid .c-tile__media img")
    shoot_phone("grid", collection_path(view: "grid"), ".c-grid .c-tile__media img", ready: ".c-grid")
    expect(out.glob("grid-*.png").size).to eq(4)
  end

  it "shoots the collection table" do
    stock
    visit collection_path(view: "table")
    shoot_wide("table", "img.c-table__thumb")
    shoot_phone("table", collection_path(view: "table"), "img.c-table__thumb", ready: "table.c-table")
    expect(out.glob("table-*.png").size).to eq(4)
  end

  it "shoots a card page" do
    user
    entry = two_faced_entry
    visit catalog_entry_path(entry)
    shoot_wide("card", ".c-item__image img")
    shoot_phone("card", catalog_entry_path(entry), ".c-item__image img", ready: ".c-item")
    expect(out.glob("card-*.png").size).to eq(4)
  end
end
```

- [ ] Capture. Run: `OUT=<scratchpad>/shots bin/rspec <scratchpad>/capture_spec.rb` (make the directory first) — expect: `3 examples, 0 failures` and 12 PNG files: `grid`, `table` and `card`, each at `1280` and `390`, each `light` and `dark`.
- [ ] Look at every one of the 12 shots. In each, every picture (square, tall, wide and card-shaped) is whole and undistorted, centred in a slot of the card's shape, with the theme's sunken ground around it; slots and rows line up; nothing scrolls sideways at 390px. A shot that shows anything else is a failure of this plan, not of the shot: stop and investigate it (`sdd-superpowers:systematic-debugging`).
- [ ] Compress them into the spec's directory. Run: `mkdir -p docs/specs/019-uncropped-card-images/screenshots && for f in <scratchpad>/shots/*.png; do magick "$f" -quality 82 "docs/specs/019-uncropped-card-images/screenshots/$(basename "${f%.png}").jpg"; done` — expect 12 `.jpg` files, each under 300 KB.
- [ ] Commit: `docs(019): add screenshots of the three slots in both themes`
- [ ] Complete `verification.md`: under `## Acceptance criteria`, one row per criterion (AC-1.1 to AC-4.5) naming the example that holds it (file and example name) or the evidence (the Phase 1 to 3 red runs for AC-4.4's second half; the screenshots for AC-4.5); under `## Local gate`, the `bin/ci` result line; under `## Commits`, `git log --oneline main..HEAD`; under `## Phone browser`, a line saying it awaits the maintainer.
- [ ] Commit: `docs(019): record the verification evidence`
- [ ] **Maintainer step (Reliability: the fit holds in the phone's WebKit browser).** Ask the maintainer, through the coordinator, to open the collection grid, the table and a card page on their phone from a dev server on this branch, and confirm that the images are whole and the thumbnails aren't stretched. Record their answer under `## Phone browser`. Real Scryfall images are within 0.3% of 63:88, so this checks that nothing regressed on WebKit rather than showing a visible difference. `object-fit: contain`, `aspect-ratio` and `height:auto` over a height attribute behave the same in WebKit; if the maintainer can't check before the pull request, say so there.
- [ ] Run the implementation review: `sdd-superpowers:sdd-review` (Mode B), as a read-only Fable subagent, and bring its findings back.
- [ ] Run `sdd-superpowers:session-wrap` and commit what it writes, before the pull request is marked ready.
- [ ] On the maintainer's go-ahead only: push and open the pull request with `Closes #35`, embedding the screenshots by commit SHA (`https://github.com/plainprogrammer/Collector/blob/<sha>/docs/specs/019-uncropped-card-images/screenshots/<name>.jpg?raw=true`).

---

## Quickstart Validation

1. `bin/rspec spec/system/card_image_fit_spec.rb spec/design_system_files_spec.rb spec/requests/scanner/readings_spec.rb` — `38 examples, 0 failures`.
2. Take the block out of `additions.css` (from its heading to the blank line after its third rule) and run step 1 again: the nine fit examples and the block's shape example fail (AC-4.4). `git checkout app/assets/stylesheets/collector/additions.css` puts it back.
3. `bin/dev`, sign in, and open the collection grid, the collection table (`?view=table`) and a card page, in both themes (`document.documentElement.dataset.theme = "dark"` in the console) and in the browser's responsive mode at 390px: every card image is whole, and the table's thumbnails match the height of an empty one.
4. Compare with `docs/specs/019-uncropped-card-images/screenshots/`.

## Spec coverage

| Requirement | Phase |
|---|---|
| FR-1 Fit the image inside its slot (and the fallback in its own slot) | 1, 2, 3 |
| FR-2 Keep the slots as they are | 0 (guards), 1, 2 |
| FR-3 Make the change where a re-export can't undo it | 1, 2, 3 (block and examples), 5 (exported files untouched) |
| FR-4 Document the pattern | 4 |
| AC-1.1, 1.2, 1.3, 1.5, 1.6 | 1 |
| AC-1.4 | 1 (request example) |
| AC-1.7, 1.8 | 0, and 1 for the unowned fade |
| AC-2.1 to 2.4 | 1 |
| AC-2.5 | 3 |
| AC-3.1 to 3.4 | 2 |
| AC-4.1, 4.2 | 4 |
| AC-4.3 | 3 |
| AC-4.4 | 1, 2, 3 (each red step), Quickstart step 2 |
| AC-4.5 | 5 |
| Error scenarios: failed image, no image, landscape, smaller than the slot | 0 (failed image, no image), 1 (the 40×20 and 40×40 pictures), 2 (failed thumbnail) |
| Performance (no layout shift), Reliability (no JavaScript; WebKit) | 0 and 2 (slot sizes before and after a picture loads); 5 (maintainer step) |
