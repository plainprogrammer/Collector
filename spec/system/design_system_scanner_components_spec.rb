require "rails_helper"

# Spec 080: the CSS of the phone-first scanner's parts, proved in headless Firefox before any view exists (#344 and #345
# build the views). A part is added to a real page (the Locations page, blanked). The shell is the whole screen, so it
# replaces the body of that page inside an iframe of the viewport's size: the dynamic viewport is then the frame's.
RSpec.describe "Design system: phone-first scanner components", type: :system do
  include DesignSystemProbe
  include ScanMarkup

  let(:user) { create(:user) }

  before do
    system_sign_in_as(user)
    visit locations_path
    blank_host
  end

  # Clears the host page so its own rules cannot answer an example: the Locations page's `c-locations` gives every `.c-btn`
  # a 44px floor.
  def blank_host
    page.execute_script(<<~JS)
      const main = document.querySelector("main")
      main.className = "c-main"
      main.replaceChildren()
    JS
  end

  # `html` as the only content of the body of a width × height frame, the block run inside the frame. The body carries the
  # classes a focused page's does. Animations are finished first, so nothing is measured mid-slide.
  def in_viewport(width, height, html)
    open_in_narrow_frame(locations_path, width:, height:, ready: "main")
    within_narrow_frame do
      page.execute_script(<<~JS, html)
        document.body.className = "c-shell c-shell--untabbed c-shell--focused"
        document.body.innerHTML = arguments[0]
        document.getAnimations().forEach((animation) => animation.finish())
      JS
      expect(evaluate("return [document.documentElement.clientWidth, window.innerHeight]")).to eq([ width, height ])
      yield
    end
  end

  # An icon's computed stroke, as a number.
  def stroke_width(selector) = evaluate("return parseFloat(getComputedStyle(document.querySelector(#{selector.to_json})).strokeWidth)").to_f

  # A token that is no colour, as the root declares it ("8px" for --radius-md).
  def custom(name) = evaluate("return getComputedStyle(document.documentElement).getPropertyValue(#{name.to_json}).trim()")

  # A font token as a computed font-family serialises it, so the two compare as strings.
  def font_token(name)
    evaluate(<<~JS)
      const probe = document.createElement("span")
      probe.style.fontFamily = "var(#{name})"
      document.body.append(probe)
      const value = getComputedStyle(probe).fontFamily
      probe.remove()
      return value
    JS
  end

  # The four corner radii's property names, clockwise from the top left.
  def corners = %w[border-top-left-radius border-top-right-radius border-bottom-right-radius border-bottom-left-radius]

  describe "StatusBand (AC-1.3 to AC-1.5)" do
    def unsure = "Not sure of this card. Check it against your capture."

    def bands
      band(:success, "Matched by its collector line", id: "ok") + band(:warning, "Printing not confirmed. Swipe to check.", id: "warn") +
        band(:warning, unsure, mark: :question, id: "unsure")
    end

    # [the band's height, the icon's top and height, the sentence's top and height], tops measured from the band's top.
    def band_layout(id)
      evaluate(<<~JS).map { it.round(1) }
        const band = document.getElementById(#{id.to_json}), top = band.getBoundingClientRect().top
        const icon = band.querySelector("svg").getBoundingClientRect(), text = band.querySelector("span").getBoundingClientRect()
        return [band.getBoundingClientRect().height, icon.top - top, icon.height, text.top - top, text.height]
      JS
    end

    %w[light dark].each do |name|
      it "fills with the status colour and writes in its on- token and the sans font, in the #{name} theme (AC-1.3)", :aggregate_failures do
        add_to_main(bands)
        theme(name)
        expect(computed("#ok", "background-color", "color")).to eq([ token("--success"), token("--on-success") ])
        expect(computed("#warn", "background-color", "color")).to eq([ token("--warning"), token("--on-warning") ])
        expect(computed("#ok svg", "color") + computed("#warn svg", "color")).to eq([ token("--on-success"), token("--on-warning") ])
        expect(computed("#ok", "font-family")).to eq([ font_token("--font-sans") ])
      end
    end

    it "is 40px high with its line and its 16px icon centred, 16px at its sides (AC-1.3, AC-1.4)", :aggregate_failures do
      add_to_main(bands)
      expect(computed("#ok", "font-size", "line-height", "font-weight", "padding-left", "padding-right")).to eq(%w[14px 20px 600 16px 16px])
      expect(band_layout("ok")).to eq([ 40.0, 12.0, 16.0, 10.0, 20.0 ])
      expect([ box("#ok svg")["width"], stroke_width("#ok svg") ]).to eq([ 16, 2.0 ])
    end

    it "tells the three forms apart by icon and words (AC-1.4)", :aggregate_failures do
      add_to_main(bands)
      expect(evaluate('return ["ok", "warn", "unsure"].map((id) => document.querySelector(`#${id} svg`).innerHTML)').uniq.size).to eq(3)
      expect(evaluate('return ["warn", "unsure"].map((id) => document.getElementById(id).textContent)'))
        .to eq([ "Printing not confirmed. Swipe to check.", unsure ])
    end

    it "wraps a long sentence inside a 360px band, the icon on the first line (AC-1.5)", :aggregate_failures do
      add_to_main(%(<div style="width:360px">#{band(:warning, unsure, mark: :question, id: "long")}</div>))
      height, icon_top, _icon_height, text_top, text_height = band_layout("long")
      expect([ height, text_height, icon_top - text_top ]).to eq([ 56.0, 40.0, 2.0 ])
      expect(evaluate('const band = document.getElementById("long"); return band.scrollWidth <= band.clientWidth')).to be(true)
    end
  end

  describe "the focused shell (AC-3.1)" do
    it "takes the body's margin and minimum height away, so an empty focused page does not scroll", :aggregate_failures do
      in_viewport(390, 844, "") do
        expect(computed("body", "margin-top", "margin-left", "min-height")).to eq(%w[0px 0px 0px])
        expect(evaluate("const root = document.documentElement; return root.scrollHeight <= root.clientHeight")).to be(true)
      end
    end
  end

  describe "Sheet (AC-2.1 to AC-2.5, AC-2.7)" do
    def long_place = "Binder" * 10
    def rows(count) = Array.new(count) { |index| %(<p style="margin:0">Row #{index + 1} in #{long_place}</p>) }.join

    def notice
      [ %(This catalog's content is unofficial and shown under its owner's <a href="#">content policy</a>. #{"Not approved or endorsed. " * 4}),
        "Catalog data and images provided by a source." ]
    end

    # Opens a sheet as a modal over the frame's page and finishes its slide.
    def open_sheet(body: rows(3), foot: [])
      page.execute_script(<<~JS, sheet(title: "Adding to", body:, foot:))
        document.body.insertAdjacentHTML("beforeend", arguments[0])
        document.getElementById("sheet").showModal()
        document.getAnimations().forEach((animation) => animation.finish())
      JS
    end

    # What the stylesheets declare for one property in the rule with this selector, as the rule writes it; nil without such a
    # rule. For what a computed style cannot show, a hover, and for the `::backdrop` rule itself: headless Firefox reports the
    # backdrop's computed colour too (read in the AC-2.1 example), but another browser may not (spec 080 Verification).
    def rule_value(selector, property)
      evaluate(<<~JS)
        for (const sheet of document.styleSheets)
          for (const rule of sheet.cssRules)
            if (rule.selectorText === #{selector.to_json}) return rule.style.getPropertyValue(#{property.to_json})
        return null
      JS
    end

    def fits?(selector) = evaluate("const el = document.querySelector(#{selector.to_json}); return el.scrollWidth <= el.clientWidth")

    %w[light dark].each do |name|
      it "sits on the bottom edge, as wide as the viewport, in the #{name} theme (AC-2.1)", :aggregate_failures do
        in_viewport(390, 844, "") do
          theme(name)
          open_sheet
          expect(box("#sheet").values_at("left", "width", "bottom")).to eq([ 0, 390, 844 ])
          expect(box("#sheet")["height"]).to be <= 844 * 0.85
          expect(computed("#sheet", "background-color", "border-top-color", "border-top-width", "border-top-left-radius", "box-shadow"))
            .to eq([ token("--surface-raised"), token("--line-strong"), "1px", "8px", "none" ])
          expect(evaluate('return getComputedStyle(document.getElementById("sheet"), "::backdrop").backgroundColor')).to eq(token("--scrim"))
          expect(computed("#sheet", *corners, "position")).to eq([ custom("--radius-md"), custom("--radius-md"), "0px", "0px", "fixed" ])
        end
      end
    end

    it "is not displayed while closed, and its backdrop is the scrim (AC-2.1)", :aggregate_failures do
      add_to_main(sheet(title: "Adding to", body: rows(1)))
      expect(computed("#sheet", "display")).to eq([ "none" ])
      expect(rule_value(".c-sheet::backdrop", "background-color")).to eq("var(--scrim)")
      expect(token("--scrim")).to eq("rgba(0, 0, 0, 0.4)")
    end

    it "has a title and a 44px Close button drawn with the 20px cross (AC-2.2)", :aggregate_failures do
      in_viewport(390, 844, "") do
        open_sheet
        expect(box(".c-sheet__close").values_at("width", "height")).to eq([ 44, 44 ])
        expect([ box(".c-sheet__close svg")["width"], stroke_width(".c-sheet__close svg") ]).to eq([ 20, 1.5 ])
        expect(computed(".c-sheet__title", "font-size", "font-weight")).to eq(%w[20px 600])
        expect(page).to have_button("Close")
      end
    end

    it "keeps its head in view while its body scrolls inside it, 85% of the viewport at most (AC-2.2, AC-2.3)", :aggregate_failures do
      in_viewport(390, 844, "") do
        open_sheet(body: rows(60))
        head = box(".c-sheet__head")["top"]
        evaluate('document.querySelector(".c-sheet__body").scrollTop = 400')
        expect([ box(".c-sheet__head")["top"], evaluate('return document.querySelector(".c-sheet__body").scrollTop') ]).to eq([ head, 400 ])
        expect(computed(".c-sheet__body", "overscroll-behavior-y")).to eq([ "contain" ])
        expect(box("#sheet")["height"]).to be_within(0.5).of(844 * 0.85)
        expect(evaluate("return window.scrollY")).to eq(0)
      end
    end

    it "slides up in 200ms at most, and not at all under reduced motion (AC-2.4)", :aggregate_failures do
      in_viewport(390, 844, "") do
        open_sheet
        expect(computed("#sheet", "animation-name", "animation-duration")).to eq(%w[c-sheet-rise 0.2s])
        apply_reduced_motion_rules(needs: [ "::backdrop" ])
        expect(computed("#sheet", "animation-name")).to eq([ "none" ])
      end
    end

    # Closes the open sheet and reads it at once: [display, animation names, transition durations, running animations]. An
    # exit animation, or a transition that keeps the dialog shown (`display … allow-discrete`), changes one of the four.
    def close_sheet
      evaluate(<<~JS)
        const sheet = document.getElementById("sheet")
        sheet.close()
        const style = getComputedStyle(sheet)
        return [style.display, style.animationName, style.transitionDuration, sheet.getAnimations().length]
      JS
    end

    it "closes at once, with no animation and no transition (AC-2.4)" do
      in_viewport(390, 844, "") do
        open_sheet
        expect(close_sheet).to eq([ "none", "none", "0s", 0 ])
      end
    end

    %w[light dark].each do |name|
      it "wraps a long place name and the notice in its foot inside a 360px sheet, in the #{name} theme (AC-2.5, AC-2.7)", :aggregate_failures do
        in_viewport(360, 640, "") do
          theme(name)
          open_sheet(body: rows(2), foot: notice)
          expect([ fits?("#sheet"), fits?(".c-sheet__body"), page_fits_sideways? ]).to eq([ true, true, true ])
          expect(computed(".c-sheet__foot", "font-size", "line-height", "color", "border-top-width", "border-top-color"))
            .to eq([ "12px", "16px", token("--ink-muted"), "1px", token("--line") ])
          expect(computed(".c-sheet__foot a", "color")).to eq([ token("--brand") ])
          expect(evaluate('return document.querySelector(".c-sheet__body").lastElementChild.className')).to eq("c-sheet__foot")
        end
      end
    end

    it "rings the notice's link on keyboard focus and underlines it on hover (AC-2.7)", :aggregate_failures do
      in_viewport(390, 844, "") do
        open_sheet(foot: notice)
        expect(rule_value(".c-sheet__foot a:hover", "text-decoration-line")).to eq("underline")
        find(".c-sheet__close").send_keys(:tab)
        expect(computed(".c-sheet__foot a", "outline-style", "outline-width", "outline-color")).to eq([ "solid", "2px", token("--focus") ])
      end
    end
  end

  describe "the shell (AC-3.1 to AC-3.9)" do
    # [top, height] of the shell and its three rows, and whether the document scrolls either way.
    def shell_rows
      evaluate(<<~JS)
        const rect = (selector) => { const r = document.querySelector(selector).getBoundingClientRect(); return [r.top, r.height] }
        const root = document.documentElement
        return { scan: rect(".c-scan"), top: rect(".c-scan__top"), stage: rect(".c-scan__stage"), bottom: rect(".c-scan__bottom"),
          scrolls: root.scrollHeight > root.clientHeight || root.scrollWidth > root.clientWidth }
      JS
    end

    # The top bar's children in order, and the [width, height] of each control and of the back arrow's icon.
    def top_bar_boxes
      evaluate(<<~JS)
        const size = (selector) => { const r = document.querySelector(selector).getBoundingClientRect(); return [r.width, r.height] }
        const order = [...document.querySelector(".c-scan__top").children].map((el) => el.className.split(" ").pop())
        return { order, back: size(".c-scan__back"), dest: size(".c-scan__dest"), done: size(".c-scan__done"),
          icon: size(".c-scan__back svg"), chevron: size(".c-scan__dest svg") }
      JS
    end

    # [left, width, height] of each control in the bottom bar, in order.
    def bottom_boxes
      evaluate(<<~JS)
        return [...document.querySelector(".c-scan__bottom").children].map((el) => {
          const r = el.getBoundingClientRect(); return [r.left, r.width, r.height] })
      JS
    end

    # The main button in one of its states: its box, its ground, opacity and text, with the two grounds it may have.
    def main_button(main)
      in_viewport(390, 844, shell(main:)) do
        { box: bottom_boxes[1], style: computed(".c-scan__main", "background-color", "opacity", "font-size", "font-weight"),
          brand: token("--brand"), raised: token("--surface-raised") }
      end
    end

    [ [ 390, 844 ], [ 360, 640 ] ].each do |width, height|
      it "is the whole #{width} × #{height} viewport and never scrolls (AC-3.1)", :aggregate_failures do
        in_viewport(width, height, shell) do
          found = shell_rows
          expect(found["scan"]).to eq([ 0, height ])
          expect(found.values_at("top", "stage", "bottom")).to eq([ [ 0, 56 ], [ 56, height - 152 ], [ height - 96, 96 ] ])
          expect(found["scrolls"]).to be(false)
        end
      end
    end

    it "scrolls by the body's margin without c-shell--focused (the measure can fail)" do
      in_viewport(390, 844, shell) do
        page.execute_script("document.body.classList.remove('c-shell--focused')")
        expect(shell_rows["scrolls"]).to be(true)
      end
    end

    it "has a 56px top bar holding Back, the destination and Done, each 44px (AC-3.2)", :aggregate_failures do
      in_viewport(390, 844, shell) do
        found = top_bar_boxes
        expect(found["order"]).to eq(%w[c-scan__back c-scan__dest c-scan__done])
        expect(found.values_at("back", "icon", "chevron")).to eq([ [ 44, 44 ], [ 20, 20 ], [ 20, 20 ] ])
        expect(found["dest"].last).to be >= 44
        expect(found["done"]).to all(be >= 44)
        expect(computed(".c-scan__top", "padding-left", "padding-right")).to eq(%w[8px 8px])
        expect(stroke_width(".c-scan__back svg")).to eq(1.5)
      end
    end

    it "cuts a long destination with an ellipsis and keeps Done whole (AC-3.3)", :aggregate_failures do
      in_viewport(360, 640, shell(value: "A deck with a very long name indeed › Considering · NM")) do
        expect(computed(".c-scan__dest-label", "font-size", "color")).to eq([ "12px", token("--ink-muted") ])
        expect(computed(".c-scan__dest-text", "font-size", "font-weight", "text-overflow", "white-space", "color"))
          .to eq([ "15px", "600", "ellipsis", "nowrap", token("--ink") ])
        expect(evaluate('const el = document.querySelector(".c-scan__dest-text"); return el.scrollWidth > el.clientWidth')).to be(true)
        expect(box(".c-scan__done")["right"]).to be_within(0.5).of(352)
        expect(box(".c-scan__dest-value")["height"]).to eq(22)
        expect(page_fits_sideways?).to be(true)
      end
    end

    # Done's width, and whether the destination's chevron starts where its value's text ends or later, at 360px.
    def done_and_chevron(value)
      in_viewport(360, 640, shell(value:)) do
        evaluate(<<~JS)
          const rect = (selector) => document.querySelector(selector).getBoundingClientRect()
          return [rect(".c-scan__done").width, rect(".c-scan__dest svg").left >= rect(".c-scan__dest-text").right]
        JS
      end
    end

    it "keeps Done as wide with a long value as with a short one, the chevron after the value (AC-3.3)", :aggregate_failures do
      long = done_and_chevron("A deck with a very long name indeed › Considering · NM")
      expect(long).to eq(done_and_chevron("Binder · NM"))
      expect(long.last).to be(true)
    end

    it "lays out the count, the main button and the torch in a 96px bar at 390px (AC-3.4)", :aggregate_failures do
      in_viewport(390, 844, shell) do
        expect(bottom_boxes).to eq([ [ 16, 84, 56 ], [ 112, 194, 64 ], [ 318, 56, 56 ] ])
        expect(computed(".c-scan__count b", "font-family").first).to include("IBM Plex Mono")
        expect(computed(".c-scan__count b", "font-size", "line-height")).to eq(%w[13px 18px])
        expect(box(".c-scan__count b")["bottom"]).to be <= box(".c-scan__count span")["top"]
        expect([ box(".c-scan__torch svg")["width"], stroke_width(".c-scan__torch svg") ]).to eq([ 20, 1.5 ])
        expect(page).to have_button("Torch").and have_button("12 added. Show this sitting's cards.")
        expect(find(".c-scan__torch")["aria-pressed"]).to eq("false")
      end
    end

    it "draws Capture, Capture while reading and Scan again at one place and size (AC-3.5)", :aggregate_failures do
      capture, reading, again = %i[capture reading again].map { main_button(it) }
      expect([ capture, reading, again ].map { it[:box] }.uniq).to eq([ [ 112, 194, 64 ] ])
      expect(capture[:style]).to eq([ capture[:brand], "1", "16px", "600" ])
      expect(reading[:style]).to eq([ reading[:brand], "0.5", "16px", "600" ])
      expect(again[:style]).to eq([ again[:raised], "1", "16px", "600" ])
    end

    it "gives the torch's room to the main button when there is no torch (AC-3.6)" do
      in_viewport(390, 844, shell(torch: false)) { expect(bottom_boxes).to eq([ [ 16, 84, 56 ], [ 112, 262, 64 ] ]) }
    end

    %w[light dark].each do |name|
      it "draws the status line on a raised ground, centred 16px under the stage's top, in the #{name} theme (AC-3.7)", :aggregate_failures do
        in_viewport(390, 844, shell) do
          theme(name)
          line, stage = box(".c-scan__line--status"), box(".c-scan__stage")
          expect(computed(".c-scan__line--status", "background-color", "border-top-color", "border-top-width", "border-top-left-radius", "color"))
            .to eq([ token("--surface-raised"), token("--line-strong"), "1px", "8px", token("--ink") ])
          expect(line["top"] - stage["top"]).to eq(16)
          expect((line["left"] + line["right"]) / 2).to be_within(0.5).of(195)
        end
      end
    end

    it "puts the after-add line in the status line's place, Undo at its end and outside the live region (AC-3.7)", :aggregate_failures do
      in_viewport(390, 844, shell(added: "Added Lightning Bolt MOM · 123, foil", count: 13)) do
        line, stage = box(".c-scan__line--added"), box(".c-scan__stage")
        expect([ line["top"] - stage["top"], line["left"], line["right"] ]).to eq([ 16, 16, 374 ])
        expect(computed(".c-scan__line--status", "display")).to eq([ "none" ])
        expect(computed(".c-scan__line--added", "background-color", "border-top-color")).to eq([ token("--surface-raised"), token("--line-strong") ])
        expect(box(".c-scan__undo .c-btn")["height"]).to eq(44)
        expect(evaluate('return !!document.querySelector(".c-scan__line--added [role=status] .c-scan__undo")')).to be(false)
      end
    end

    %w[light dark].each do |name|
      it "rounds the after-add line's corners and writes it in ink, in the #{name} theme (AC-3.7)", :aggregate_failures do
        in_viewport(390, 844, shell(added: "Added Lightning Bolt MOM · 123, foil", count: 13)) do
          theme(name)
          expect(computed(".c-scan__line--added", *corners)).to eq([ custom("--radius-md") ] * 4)
          expect(computed(".c-scan__line--added .c-scan__line-text", "color")).to eq([ token("--ink") ])
        end
      end
    end

    it "wraps a long after-add line at 360px with Undo on its first line (AC-3.8)", :aggregate_failures do
      in_viewport(360, 640, shell(added: "Added A card name of forty characters wrapping CLB · 187, foil, and more words")) do
        text, undo, line = box(".c-scan__line--added .c-scan__line-text"), box(".c-scan__undo .c-btn"), box(".c-scan__line--added")
        expect(text["height"]).to be > 44
        expect(undo["top"] - line["top"]).to eq(1)
        expect(line["right"] - undo["right"]).to be_within(0.5).of(1)
        expect(page_fits_sideways?).to be(true)
      end
    end

    it "grounds the stage in surface-sunken under a covering picture, the guide drawn as today (AC-3.9)", :aggregate_failures do
      in_viewport(390, 844, shell(guide: "left:5px;top:80px;width:380px;height:531px")) do
        expect(computed(".c-scan__stage", "background-color")).to eq([ token("--surface-sunken") ])
        expect(computed(".c-scan__video", "object-fit", "position")).to eq(%w[cover absolute])
        expect(box(".c-scan__video").values_at("width", "height")).to eq([ 390, 692 ])
        expect(computed(".c-scan__guide", "border-top-style", "border-top-width", "border-top-color", "outline-style", "outline-color", "outline-offset"))
          .to eq([ "solid", "2px", token("--brand"), "dashed", token("--on-brand"), "-6px" ])
      end
    end
  end

  describe "the selection pane (AC-4.1 to AC-4.11)" do
    def three_cards
      [ sample_card(set: "Double Masters 2022", code: "2X2 · 117", year: "2022"), sample_card,
        sample_card(set: "Commander Legends: Battle for Baldur’s Gate", code: "CLB · 187", year: "2022") ]
    end

    def matched = band(:success, "Matched by its collector line")
    def unsure = band(:warning, "Not sure of this card. Check it against your capture.", mark: :question)
    def shown = ".c-scanpane__card:not([hidden])"

    # A shell showing a result: the pane over the stage, the second of three cards centred unless told otherwise.
    def result(status: matched, cards: three_cards, current: 1, **options)
      shell(result: pane(band: status, cards:, current:, total: 14, **options))
    end

    # Runs the block in a frame showing a result with its centred card at rest in the middle, as #345's script will leave it.
    def in_result(width, height, html = result)
      in_viewport(width, height, html) do
        evaluate(<<~JS)
          const row = document.querySelector(".c-scanpane__row"), item = row.querySelector('[aria-current="true"]')
          row.scrollTo({ left: item.offsetLeft - (row.clientWidth - item.offsetWidth) / 2, behavior: "instant" })
        JS
        yield
      end
    end

    # Heights of the strip, its picture, the pane, the band, the centred image and the details block; the pane's gaps to
    # the strip above and the bottom bar below; the image's width for a height of 88; the add buttons' gap to the bottom
    # bar; and whether the pane's body scrolls.
    def pane_layout
      evaluate(<<~JS)
        const rect = (selector) => document.querySelector(selector).getBoundingClientRect(), round = (value) => Math.round(value * 10) / 10
        const body = document.querySelector(".c-scanpane__body"), image = rect('.c-scanpane__item[aria-current="true"]')
        return { strip: rect(".c-scan__strip").height, picture: rect(".c-scan__capture").height, pane: rect(".c-scanpane").height,
          above: rect(".c-scanpane").top - rect(".c-scan__strip").bottom, below: rect(".c-scan__bottom").top - rect(".c-scanpane").bottom,
          band: rect(".c-band").height, image: round(image.height), ratio: round(image.width * 88 / image.height),
          details: rect("#{shown} .c-scanpane__details").height, addsGap: round(rect(".c-scan__bottom").top - rect("#{shown} .c-scanpane__adds").bottom),
          scrolls: body.scrollHeight > body.clientHeight }
      JS
    end

    # The row at rest: the centred image's width and centre, how much of each neighbour shows, the gap, the inline
    # padding, the room a scrollbar takes, the snap, and whether the outline's 4px clear the row's clipping edges.
    def row_layout
      evaluate(<<~JS)
        const row = document.querySelector(".c-scanpane__row"), items = [...row.children].map((el) => el.getBoundingClientRect())
        const at = [...row.children].findIndex((el) => el.getAttribute("aria-current") === "true"), mid = items[at], view = row.getBoundingClientRect()
        const round = (value) => Math.round(value * 10) / 10, style = getComputedStyle(row)
        return { width: round(mid.width), centre: round((mid.left + mid.right) / 2), before: round(items[at - 1].right - view.left),
          after: round(view.right - items[at + 1].left), gap: round(mid.left - items[at - 1].right), padding: round(parseFloat(style.paddingLeft)),
          bar: row.offsetHeight - row.clientHeight, snap: [style.scrollSnapType, getComputedStyle(row.children[at]).scrollSnapAlign],
          clear: mid.top - view.top >= 4 && view.bottom - mid.bottom >= 4 }
      JS
    end

    # Where the first image's centre is with the row scrolled to its start, and the last one's with it scrolled to its end.
    def end_centres
      evaluate(<<~JS)
        const row = document.querySelector(".c-scanpane__row")
        const centre = (el) => { const r = el.getBoundingClientRect(); return Math.round((r.left + r.right) / 2) }
        row.scrollTo({ left: 0, behavior: "instant" })
        const first = centre(row.firstElementChild)
        row.scrollTo({ left: row.scrollWidth, behavior: "instant" })
        return [first, centre(row.lastElementChild)]
      JS
    end

    # Each add button of the shown panel: [left, width, height], the lines its words take, and whether they fit inside it.
    def add_buttons
      evaluate(<<~JS)
        return [...document.querySelectorAll("#{shown} .c-scanpane__add .c-btn")].map((el) => {
          const words = [...el.childNodes].find((node) => node.nodeType === 3 && node.textContent.trim()), range = document.createRange()
          range.selectNodeContents(words)
          const lines = new Set([...range.getClientRects()].map((r) => Math.round(r.top))).size, r = el.getBoundingClientRect()
          return { box: [r.left, r.width, r.height], lines, fits: el.scrollHeight <= el.clientHeight && el.scrollWidth <= el.clientWidth } })
      JS
    end

    # The tops of the parts that must never move.
    def fixed_tops = %w[.c-scan__top .c-scan__strip .c-band .c-scan__bottom].map { box(it)["top"] }

    it "shows the capture strip at the top of the stage: a 124px picture and what was read (AC-4.1)", :aggregate_failures do
      in_result(390, 844) do
        strip, picture, stage = box(".c-scan__strip"), box(".c-scan__capture"), box(".c-scan__stage")
        expect([ strip["top"] - stage["top"], strip["height"], picture["height"], picture["top"] - strip["top"] ]).to eq([ 0, 144, 124, 10 ])
        expect(picture["width"]).to be_within(0.1).of(124 * 63 / 88.0)
        expect(computed(".c-scan__read-label", "font-size", "color")).to eq([ "12px", token("--ink-muted") ])
        expect(computed(".c-scan__read-name", "font-size", "font-weight", "text-overflow", "white-space")).to eq(%w[15px 600 ellipsis nowrap])
        expect(computed(".c-scan__read-name", "color")).to eq([ token("--ink") ])
        expect(computed(".c-scan__read-line", "font-family").first).to include("IBM Plex Mono")
      end
    end

    it "fits the band, the row, the details and the add buttons in 548px at 390 × 844 (AC-4.2)", :aggregate_failures do
      in_result(390, 844) do
        found = pane_layout
        expect(found.values_at("above", "below", "pane", "band", "image")).to eq([ 0, 0, 548, 40, 288 ])
        expect(found.values_at("scrolls", "addsGap")).to eq([ false, 16 ])
        expect(computed(".c-scanpane", "border-top-left-radius", "border-top-right-radius")).to eq(%w[8px 8px])
        expect(box(".c-band")["top"]).to eq(box(".c-scanpane")["top"])
      end
    end

    it "centres a 206px image with 80px of each neighbour, snapped, with no scrollbar (AC-4.3)", :aggregate_failures do
      in_result(390, 844) do
        found = row_layout
        expect(found.values_at("width", "padding")).to match([ be_within(1).of(206), be_within(1).of(92) ])
        expect(found["centre"]).to be_within(0.5).of(195)
        expect(found.values_at("before", "after")).to all(be_within(1).of(80))
        expect(found.values_at("gap", "bar", "snap", "clear")).to eq([ 12, 0, [ "x mandatory", "center" ], true ])
        expect(page_fits_sideways?).to be(true)
      end
    end

    it "outlines the centred image in brand, 63:88 with the card's corners (AC-4.3)", :aggregate_failures do
      in_result(390, 844) do
        centred = '.c-scanpane__item[aria-current="true"]'
        expect(computed(centred, "outline-style", "outline-width", "outline-color")).to eq([ "solid", "2px", token("--brand") ])
        expect(computed(centred, "border-top-left-radius").first).to start_with("4.75%")
        expect(computed(".c-scanpane__item:not([aria-current])", "outline-style")).to eq([ "none" ])
        expect(pane_layout["ratio"]).to eq(63)
      end
    end

    it "can centre its first and its last image (AC-4.3)" do
      in_result(390, 844) { expect(end_centres).to eq([ 195, 195 ]) }
    end

    # Each side's [width, style, colour] of the border of Previous and of Next, in one list.
    def nav_borders
      %w[prev next].flat_map do |nav|
        %w[top right bottom left].map { |side| computed(".c-scanpane__nav--#{nav}", *%w[width style color].map { "border-#{side}-#{it}" }) }
      end
    end

    # Whether the star in the special finish's button starts left of the button's words.
    def star_before_words?
      evaluate(<<~JS)
        const star = document.querySelector("#{shown} .c-scanpane__add svg"), range = document.createRange()
        range.selectNodeContents([...star.closest(".c-btn").childNodes].find((node) => node.nodeType === 3 && node.textContent.trim()))
        return star.getBoundingClientRect().left < range.getBoundingClientRect().left
      JS
    end

    it "puts Previous and Next over the neighbours, 44px, the one at the row's end disabled (AC-4.4)", :aggregate_failures do
      in_result(390, 844, result(current: 0)) do
        prev, nxt, wrap = box(".c-scanpane__nav--prev"), box(".c-scanpane__nav--next"), box(".c-scanpane__rowwrap")
        expect([ prev, nxt ].map { it.values_at("width", "height") }).to eq([ [ 44, 44 ], [ 44, 44 ] ])
        expect([ prev["left"], 390 - nxt["right"], (prev["top"] + prev["bottom"]) / 2 - wrap["top"] ]).to eq([ 8, 8, 16 + 144 ])
        expect(page).to have_button("Previous printing", disabled: true).and have_button("Next printing", disabled: false)
        expect(computed(".c-scanpane__nav--next", "background-color")).to eq([ token("--surface-raised") ])
        expect([ box(".c-scanpane__nav--next svg")["width"], stroke_width(".c-scanpane__nav--next svg") ]).to eq([ 20, 1.5 ])
        expect(nav_borders.uniq).to eq([ [ "1px", "solid", token("--line-strong") ] ])
      end
    end

    it "rings Next on keyboard focus, and scrolls the row smoothly only without the reduced-motion preference (AC-4.4)", :aggregate_failures do
      in_result(390, 844) do
        find(".c-scanpane__nav--prev").send_keys(:tab)
        expect(computed(".c-scanpane__nav--next", "outline-style", "outline-width", "outline-color")).to eq([ "solid", "2px", token("--focus") ])
        expect(computed(".c-scanpane__row", "scroll-behavior")).to eq([ "smooth" ])
        apply_reduced_motion_rules(needs: [ ".c-scanpane__row" ])
        expect(computed(".c-scanpane__row", "scroll-behavior")).to eq([ "auto" ])
      end
    end

    it "describes the centred card in one 80px block: name, set, then code, year and position (AC-4.5)", :aggregate_failures do
      in_result(390, 844) do
        expect(box("#{shown} .c-scanpane__details").values_at("left", "right", "height")).to eq([ 16, 374, 80 ])
        expect(computed("#{shown} .c-scanpane__name", "font-size", "font-weight") + computed("#{shown} .c-scanpane__set", "font-size")).to eq(%w[20px 600 15px])
        expect(computed("#{shown} .c-scanpane__meta", "color")).to eq([ token("--ink-muted") ])
        expect(computed("#{shown} .c-scanpane__meta", "font-family").first).to include("IBM Plex Mono")
        expect(box("#{shown} .c-scanpane__position")["right"]).to eq(374)
        expect(find("#{shown} .c-scanpane__meta").text(normalize_ws: true)).to eq("MOM · 123 2023 2 of 14 printings")
      end
    end

    it "shares the pane's width between two add buttons, the special finish with its star (AC-4.6)", :aggregate_failures do
      in_result(390, 844) do
        expect(add_buttons.map { it["box"] }).to eq([ [ 16, 175, 52 ], [ 199, 175, 52 ] ])
        expect(computed("#{shown} .c-scanpane__add .c-btn", "font-size", "line-height", "font-weight", "padding-left", "background-color"))
          .to eq([ "15px", "20px", "600", "8px", token("--surface-raised") ])
        expect(computed("#{shown} .c-scanpane__add svg", "width", "color")).to eq([ "14px", token("--foil") ])
        expect(evaluate(%(return [...document.querySelectorAll("#{shown} .c-scanpane__add svg")].map((el) => el.getAttribute("aria-hidden")))))
          .to eq([ "true" ])
        expect(star_before_words?).to be(true)
      end
    end

    it "gives one finish a full-width Add, and a row of one card no way to move (AC-4.6)", :aggregate_failures do
      in_result(390, 844, result(cards: [ sample_card(finishes: %w[nonfoil]) ], current: 0)) do
        expect(add_buttons.map { it["box"] }).to eq([ [ 16, 358, 52 ] ])
        expect(page).to have_button("Previous printing", disabled: true).and have_button("Next printing", disabled: true)
      end
    end

    it "shrinks the strip and the images at 390 × 664 and still shows the add buttons (AC-4.7)", :aggregate_failures do
      in_result(390, 664) do
        found = pane_layout
        expect(found.values_at("strip", "picture", "ratio", "scrolls", "addsGap")).to eq([ 96, 76, 63, false, 16 ])
        expect(found["image"]).to be_within(2).of(184)
      end
    end

    it "holds the images at 160px at 360 × 640 with a one-line band, nothing scrolling (AC-4.7)" do
      in_result(360, 640) { expect(pane_layout.values_at("band", "image", "scrolls")).to eq([ 40, 160, false ]) }
    end

    it "scrolls the pane's content at 360 × 640 with a two-line band (AC-4.7)" do
      in_result(360, 640, result(status: unsure, noun: "possible cards", step: "card")) do
        expect(pane_layout.values_at("band", "image", "scrolls")).to eq([ 56, 160, true ])
      end
    end

    it "scrolls the pane's content at 360 × 560 and keeps the bars, the strip and the band in place (AC-4.7)", :aggregate_failures do
      in_result(360, 560) do
        before = fixed_tops
        evaluate('document.querySelector(".c-scanpane__body").scrollTop = 60')
        expect(pane_layout["scrolls"]).to be(true)
        expect(fixed_tops).to eq(before)
        expect(evaluate('return [window.scrollY, document.querySelector(".c-scanpane__body").scrollTop]')).to eq([ 0, 60 ])
      end
    end

    it "shrinks the capture and slides the pane in 200ms, and neither under reduced motion (AC-4.8)", :aggregate_failures do
      in_result(390, 844) do
        expect(computed(".c-scanpane", "animation-name", "animation-duration")).to eq(%w[c-scanpane-rise 0.2s])
        expect(computed(".c-scan__capture", "animation-name", "animation-duration")).to eq(%w[c-scan-shrink 0.2s])
        apply_reduced_motion_rules(needs: [ "::backdrop" ])
        expect(computed(".c-scanpane", "animation-name") + computed(".c-scan__capture", "animation-name")).to eq(%w[none none])
      end
    end

    it "wraps a 60-character set name and a 40-character card name at 360px (AC-4.9)", :aggregate_failures do
      long = sample_card(name: "A card name of forty characters wrapping", set: "A set name of sixty characters long enough to wrap two lines")
      in_result(360, 640, result(cards: [ long ], current: 0)) do
        expect([ box(".c-scanpane__name")["height"], box(".c-scanpane__set")["height"] ]).to eq([ 56, 44 ])
        expect(box(".c-scanpane__set")["right"]).to be <= 344
        expect(evaluate('const el = document.querySelector(".c-scanpane__body"); return el.scrollWidth <= el.clientWidth')).to be(true)
        expect(page_fits_sideways?).to be(true)
      end
    end

    it "shows only the centred card's panel (AC-4.10)" do
      in_result(390, 844) do
        heights = evaluate('return [...document.querySelectorAll(".c-scanpane__card")].map((el) => el.getBoundingClientRect().height > 0)')
        expect(heights).to eq([ false, true, false ])
      end
    end

    it "keeps a hidden button hidden in the shell, the pane and a sheet (AC-4.10)" do
      hidden = %(<button class="c-btn" hidden>Hidden</button>)
      add_to_main(%(<div class="c-scan">#{hidden}</div><div class="c-scanpane">#{hidden}</div>) + sheet(title: "Adding to", body: hidden, open: true))
      expect(evaluate('return [...document.querySelectorAll("main .c-btn[hidden]")].map((el) => getComputedStyle(el).display)')).to eq(%w[none none none])
    end

    it "wraps the foil marker's label onto two lines inside a 160px button at 360px (AC-4.11)", :aggregate_failures do
      in_result(360, 640, result(labels: { "foil" => "Add foil · read from the card" })) do
        found = add_buttons
        expect(found.map { it["box"].last(2) }).to eq([ [ 160, 52 ], [ 160, 52 ] ])
        expect(found.map { it.values_at("lines", "fits") }).to eq([ [ 1, true ], [ 2, true ] ])
        expect(computed("#{shown} .c-scanpane__add:last-child .c-btn", "text-align")).to eq([ "center" ])
      end
    end
  end

  describe "reduced motion, app-wide (AC-6.4)" do
    def moving
      %(<button class="c-btn c-btn--primary" id="button">Add</button><a class="c-tile" href="#"><div class="c-tile__media" id="media"></div></a>)
    end

    it "stops a button's and a tile's transitions, which run without the preference", :aggregate_failures do
      add_to_main(moving)
      expect(computed("#button", "transition-duration")).to eq([ "0.12s" ])
      expect(computed("#media", "transition-duration")).to eq([ "0.15s, 0.15s" ])
      apply_reduced_motion_rules(needs: [ "::backdrop" ])
      expect(computed("#button", "transition-duration") + computed("#media", "transition-duration")).to eq(%w[0s 0s])
    end
  end
end
