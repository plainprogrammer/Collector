require "rails_helper"

# Spec 029 AC-1.3, AC-5.1, AC-5.5: the flow, the header's four links, and the pages' widths and targets.
RSpec.describe "Locations", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }

  it "adds with the keyboard, renames and removes through the pages (AC-1.3, Story 2, Story 3)", :aggregate_failures do
    visit locations_path
    fill_in "Name", with: "Blue binder"
    find_field("Name").send_keys(:enter)
    expect(page).to have_css("#status", text: "Added “Blue binder”.")
    expect(page).to have_css(".c-locations__name", text: "Blue binder")

    click_on "Rename Blue binder"
    fill_in "Name", with: "Trade binder"
    click_on "Save"
    expect(page).to have_css("#status", text: "Renamed “Blue binder” to “Trade binder”.")

    click_on "Remove Trade binder"
    expect(page).to have_css("h1", text: "Remove Trade binder?")
    click_on "Remove"
    expect(page).to have_css("#status", text: "Removed “Trade binder”.")
    expect(page).to have_css(".c-empty")
  end

  it "keeps Collection, Search, Scan and Locations on one line with the account menu at 640px (AC-5.1)" do
    visit locations_path
    open_in_narrow_frame(locations_path, width: 640, ready: ".c-appbar__nav")
    fits = within_narrow_frame do
      page.evaluate_script(<<~JS)
        (() => {
          const links = [...document.querySelectorAll(".c-appbar__nav a")]
          const nav = document.querySelector(".c-appbar__nav").getBoundingClientRect()
          const actions = document.querySelector(".c-appbar__actions").getBoundingClientRect()
          return [links.length, new Set(links.map((link) => Math.round(link.getBoundingClientRect().top))).size,
            nav.right <= actions.left, document.documentElement.scrollWidth <= window.innerWidth]
        })()
      JS
    end

    expect(fits).to eq([ 4, 1, true, true ])
  end

  # Every control on the page, as the pointer sees it: a field is its label (the `c-input` wrapper), a link or button itself.
  def targets = <<~JS
    [...document.querySelectorAll("main a, main button, main input:not([type=hidden]), .c-appbar a[href='/locations'], .c-appbar__back")]
      .filter((el) => el.getClientRects().length > 0) // only what is rendered at this width: the header link from 640px, the back button below it
      .map((el) => el.closest("label.c-input") || el)
  JS

  it "never scrolls sideways at 360px, 640px and a 1200px desktop frame in both themes, with 44px targets and a focus ring (AC-5.5)", :aggregate_failures do
    long = create(:location, account: user.account, name: "A very long name for a binder of cards")
    create(:location, account: user.account, name: "Box")
    paths = [ locations_path, edit_location_path(long), new_location_removal_path(long) ]

    [ 360, 640, 1200 ].product(%w[light dark], paths).each do |width, theme, path|
      expect(open_in_narrow_frame(path, width:, ready: "main")).to eq([ width, true ]), "#{path} at #{width}px"
      within_narrow_frame do
        page.execute_script("document.documentElement.setAttribute('data-theme', arguments[0])", theme)
        expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true), "#{path} at #{width}px, #{theme}"
        # Measured, not declared: the box each target really has (plan review m4).
        small = page.evaluate_script("#{targets}.filter((el) => { const box = el.getBoundingClientRect(); return box.height < 44 || box.width < 44 }).map((el) => el.outerHTML.slice(0, 60))")
        expect(small).to eq([]), "#{path} at #{width}px, #{theme}: a target under 44px"
      end
    end
  end

  it "shows a focus ring on every control the keyboard reaches, on each page (AC-5.5)", :aggregate_failures do
    long = create(:location, account: user.account, name: "Box")

    [ locations_path, edit_location_path(long), new_location_removal_path(long) ].each do |path|
      visit path
      stops = page.evaluate_script("#{targets}.length")
      rings = []
      (stops + 6).times do
        page.driver.browser.action.send_keys(:tab).perform
        rings << page.evaluate_script("(() => { const el = document.activeElement.closest('label.c-input') || document.activeElement; /* a field's ring is on its c-input wrapper (:focus-within) */ const style = getComputedStyle(el); return !el.matches('main *, .c-appbar *') || (el.matches(':focus-visible, :focus-within') && style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0) })()")
      end
      expect(rings).to all(be(true)), path
    end
  end

  # Spec 032 AC-5.2: the refusal page fits at 360px, offers no Remove, and its links keep the 44px floor.
  it "refuses a location that holds lots without scrolling sideways, with 44px links and the keyboard (spec 032 AC-5.2)", :aggregate_failures do
    blue = create(:location, account: user.account, name: "Blue binder")
    entry = create(:mtg_printing).entry
    create(:lot, account: user.account, entry:, location: blue, quantity: 3)

    expect(open_in_narrow_frame(new_location_removal_path(blue), width: 360, ready: "main")).to eq([ 360, true ])
    within_narrow_frame do
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      expect(page.evaluate_script("[...document.querySelectorAll('main button, main input[type=submit]')].length")).to eq(0)
      expect(page.evaluate_script("#{targets}.filter((el) => { const box = el.getBoundingClientRect(); return box.height < 44 || box.width < 44 }).length")).to eq(0)
    end
    visit new_location_removal_path(blue)
    expect(tab_to("Back to locations")).to be(true)
  end

  # Tabs until the focused element's text includes the given text, at most 40 times.
  def tab_to(text)
    40.times do
      return true if page.evaluate_script("document.activeElement.textContent.includes(arguments[0])", text)

      page.driver.browser.action.send_keys(:tab).perform
    end
    false
  end
end
