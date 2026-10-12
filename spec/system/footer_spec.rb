require "rails_helper"

# Spec 018 Stories 3 and 4: where the footer sits and how it reads, on wide screens and phones, in both themes and
# under the scanner's policy. Phone widths are loaded in a frame (spec/support/narrow_frame.rb).
RSpec.describe "The footer", type: :system do
  # What the page shows of the footer once scrolled to its end: each line's box, whether the footer is what's drawn at
  # each line's middle (nothing covers it), the tab bar's top, and how the footer sits against the main content.
  def measure
    page.evaluate_script(<<~JS)
      (() => {
        scrollTo(0, document.documentElement.scrollHeight)
        const footer = document.querySelector("body > footer.c-footer")
        const main = document.querySelector("main")
        const tabbar = document.querySelector("body > .c-tabbar")
        const lines = [ ...footer.querySelectorAll("p") ].map((line) => {
          const box = line.getBoundingClientRect()
          const seen = document.elementFromPoint(box.left + 4, box.top + box.height / 2)
          return { left: box.left, right: box.right, bottom: box.bottom, uncovered: Boolean(seen && seen.closest("footer.c-footer")) }
        })
        return { lines, scrolled: scrollY, height: innerHeight, position: getComputedStyle(footer).position,
          top: footer.getBoundingClientRect().top, bottom: footer.getBoundingClientRect().bottom,
          mainBottom: main ? main.getBoundingClientRect().bottom : null,
          mainPadding: main ? getComputedStyle(main).paddingBottom : null,
          contentBottom: main && main.lastElementChild ? main.lastElementChild.getBoundingClientRect().bottom : null,
          gutter: main ? main.getBoundingClientRect().left + parseFloat(getComputedStyle(main).paddingLeft) : null,
          tabbarTop: tabbar && getComputedStyle(tabbar).position === "fixed" ? tabbar.getBoundingClientRect().top : null }
      })()
    JS
  end

  # A frame much shorter than any page, so that each one scrolls and its end sits under the fixed tab bar.
  def measure_at(path, width:, ready: "body > footer.c-footer")
    fits = open_in_narrow_frame(path, width:, height: 320, ready:)
    [ fits, within_narrow_frame { measure } ]
  end

  def rgb(css) = css.scan(/[\d.]+/).first(3).map(&:to_f)

  # WCAG 2 contrast ratio of two computed colours.
  def contrast(one, other)
    light, dark = [ one, other ].map do |colour|
      red, green, blue = rgb(colour).map { |channel| (c = channel / 255) <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
      0.2126 * red + 0.7152 * green + 0.0722 * blue
    end.sort.reverse
    (light + 0.05) / (dark + 0.05)
  end

  def colours
    page.evaluate_script(<<~JS)
      (() => { const footer = document.querySelector("body > footer.c-footer")
        return { text: getComputedStyle(footer).color, link: getComputedStyle(footer.querySelector("a")).color,
          ground: getComputedStyle(document.body).backgroundColor } })()
    JS
  end

  let(:user) { create(:user) }

  it "follows short content directly, in normal flow, on a wide screen (AC-3.3)", :aggregate_failures do
    create(:user)
    page.current_window.resize_to(1280, 900) # tall enough that the sign-in page leaves room under its footer
    visit new_session_path
    footer = measure

    expect(footer["position"]).to eq("static")
    expect(footer["top"]).to be_within(0.5).of(footer["mainBottom"])
    expect(footer["bottom"]).to be < footer["height"] - 100
    expect(footer["lines"]).to all(include("uncovered" => true))
  end

  it "stops above the phone's tab bar, inside the gutter, at 390px and 360px (AC-3.1, AC-3.2)", :aggregate_failures do
    lot = create(:lot, account: user.account)
    system_sign_in_as(user)

    [ collection_path, catalog_entry_path(lot.entry), more_path ].each do |path|
      [ 390, 360 ].each do |width|
        fits, footer = measure_at(path, width:)

        expect(fits).to eq([ width, true ]), "#{path} scrolls sideways at #{width}px"
        expect(footer.values_at("tabbarTop", "scrolled")).to all(be_positive), "#{path} at #{width}px: no fixed tab bar, or nothing to scroll"
        expect(footer["lines"].map { |line| line["bottom"] }).to all(be <= footer["tabbarTop"]), "#{path} at #{width}px: text under the tab bar"
        expect(footer["lines"]).to all(include("uncovered" => true, "left" => footer["gutter"])), "#{path} at #{width}px: not on the gutter"
        expect(footer["lines"].map { |line| line["right"] }).to all(be <= width - footer["gutter"]), "#{path} at #{width}px: text past the gutter"
        expect(footer["top"]).to be_within(0.5).of(footer["mainBottom"]), "#{path} at #{width}px: a gap after main"
        expect(footer["mainPadding"]).to eq("16px"), "#{path} at #{width}px: main keeps the tab bar's clearance as well"
      end
    end
  end

  it "wraps inside the gutter on the sign-in page at 360px, where there is no tab bar (AC-3.2)", :aggregate_failures do
    create(:user)
    visit new_session_path
    fits, footer = measure_at(new_session_path, width: 360)

    expect(fits).to eq([ 360, true ])
    expect(footer["lines"]).to all(include("uncovered" => true, "left" => footer["gutter"]))
    expect(footer["lines"].map { |line| line["right"] }).to all(be <= 360 - footer["gutter"])
  end

  it "clears the sticky filter bar and the bulk bar (AC-3.6)", :aggregate_failures do
    create_list(:lot, 3, account: user.account)
    system_sign_in_as(user)

    [ collection_path, collection_path(view: "table", bulk: 1) ].each do |path|
      visit path
      expect(measure["lines"]).to all(include("uncovered" => true)), "#{path} on a wide screen"

      _, footer = measure_at(path, width: 390)
      expect(footer["lines"]).to all(include("uncovered" => true)), "#{path} at 390px"
      expect(footer["scrolled"]).to be_positive, "#{path} at 390px: nothing to scroll"
      expect(footer["lines"].map { |line| line["bottom"] }).to all(be <= footer["tabbarTop"]), "#{path} at 390px"
    end
  end

  it "reads as small print with brand links, in the light theme (AC-3.4, AC-3.8)", :aggregate_failures do
    system_sign_in_as(user)
    visit collection_path
    link = find("body > footer.c-footer a", text: "Scryfall")
    style = ->(property) { page.evaluate_script("getComputedStyle(arguments[0])[arguments[1]]", link, property) }

    # Light --ink-muted is #5f5a52 and --brand is #13595a in tokens.css.
    expect(colours.values_at("text", "link")).to eq([ "rgb(95, 90, 82)", "rgb(19, 89, 90)" ])
    expect(contrast(colours["text"], colours["ground"])).to be >= 4.5
    expect(contrast(colours["link"], colours["ground"])).to be >= 4.5
    expect([ style["fontSize"], style["lineHeight"], style["fontWeight"], style["textDecorationLine"] ]).to eq(%w[12px 16px 400 none])

    link.hover
    expect(style["textDecorationLine"]).to eq("underline")

    page.execute_script("arguments[0].focus({ focusVisible: true })", link)
    expect([ style["outlineStyle"], style["outlineWidth"], style["outlineOffset"] ]).to eq(%w[solid 2px 2px])
  end

  it "holds its contrast in the dark theme (AC-3.4)", :aggregate_failures do
    driven_by :selenium, using: :headless_firefox, screen_size: [ 1280, 900 ], options: { name: :firefox_dark } do |options|
      options.add_preference("ui.systemUsesDarkTheme", 1)
      options.add_preference("layout.css.prefers-color-scheme.content-override", 0) # 0 = dark
    end
    system_sign_in_as(user)
    visit collection_path

    # Dark --surface is #161513, --ink-muted #aaa298 and --brand #5fb7b2 in tokens.css.
    expect(colours.values_at("ground", "text", "link")).to eq([ "rgb(22, 21, 19)", "rgb(170, 162, 152)", "rgb(95, 183, 178)" ])
    expect(contrast(colours["text"], colours["ground"])).to be >= 4.5
    expect(contrast(colours["link"], colours["ground"])).to be >= 4.5
  end

  it "is styled on the scanner page, under its policy (AC-4.1)", :aggregate_failures do
    system_sign_in_as(user)
    visit scanner_path
    expect(page).to have_css(".c-scanner")

    expect(colours.values_at("text", "link")).to eq([ "rgb(95, 90, 82)", "rgb(19, 89, 90)" ])
    expect(page.all("body > footer.c-footer a").map { |link| link[:href] })
      .to eq([ "https://company.wizards.com/en/legal/fancontentpolicy", "https://scryfall.com/" ])
    expect(page).to have_no_css("body > footer.c-footer [style]")
    expect(measure["lines"]).to all(include("uncovered" => true))
  end

  it "clears the scanner and the tab bar on a phone (AC-4.4)", :aggregate_failures do
    system_sign_in_as(user)
    visit collection_path # the scanner's own policy lets it frame nothing, so the phone-width frame opens from here
    fits, footer = measure_at(scanner_path, width: 390, ready: ".c-scanner")
    expect(fits).to eq([ 390, true ])
    expect(footer["scrolled"]).to be_positive
    expect(footer["lines"]).to all(include("uncovered" => true))
    expect(footer["lines"].map { |line| line["bottom"] }).to all(be <= footer["tabbarTop"])
    expect(footer["top"]).to be >= footer["contentBottom"] # measured in the same moment: the scanner grows as the camera starts
  end

  it "is there once after a Turbo visit and after going back (FR-2)", :aggregate_failures do
    system_sign_in_as(user)
    visit collection_path
    within(".c-appbar__nav") { click_on "Search" }

    expect(page).to have_current_path(catalog_entries_path)
    expect(page).to have_css("body > footer.c-footer", count: 1)

    page.go_back
    expect(page).to have_current_path(collection_path)
    expect(page).to have_css("body > footer.c-footer", count: 1)
  end
end
