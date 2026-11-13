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
      it "fills with the status colour and writes in its on- token, in the #{name} theme (AC-1.3)", :aggregate_failures do
        add_to_main(bands)
        theme(name)
        expect(computed("#ok", "background-color", "color")).to eq([ token("--success"), token("--on-success") ])
        expect(computed("#warn", "background-color", "color")).to eq([ token("--warning"), token("--on-warning") ])
        expect(computed("#ok svg", "color")).to eq([ token("--on-success") ])
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
