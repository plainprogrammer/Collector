require "rails_helper"

# Spec 023 in the browser: a visitor to an open catalog searches, opens a card and signs in from it (AC-3.6, decision 4),
# the pages fit a phone (AC-5.5's markup side), and a shell with no tab bar gives up the tab bar's clearance (AC-5.7).
# Phone widths are loaded in a frame (spec/support/narrow_frame.rb).
RSpec.describe "A visitor's catalog", :public_catalog, type: :system do
  let!(:user) { create(:user) }
  let!(:bolt) do
    set = create(:catalog_set, code: "m10", name: "Magic 2010")
    create(:catalog_entry, set:, name: "Lightning Bolt", identity: create(:catalog_identity, name: "Lightning Bolt")).tap do |entry|
      create(:mtg_printing, entry:)
    end
  end
  let(:notice) { "Card data and images provided by Scryfall." }

  def search_for_bolt
    visit catalog_entries_path
    fill_in "Card name", with: "bolt"
    click_button "Search"
    expect(page).to have_css(".c-group h2", text: "Lightning Bolt")
  end

  def result_tile = find("a.c-tile", text: "Lightning Bolt")

  # Scrolls the frame's page to its end and reads the bottom padding of c-main and of the footer (nil without one).
  def clearance_at(path, ready:)
    open_in_narrow_frame(path, width: 390, height: 320, ready:)
    within_narrow_frame do
      page.evaluate_script(<<~JS)
        (() => {
          scrollTo(0, document.documentElement.scrollHeight)
          const footer = document.querySelector("body > footer.c-footer")
          return { scrolled: scrollY, main: getComputedStyle(document.querySelector("main.c-main")).paddingBottom,
            footer: footer ? getComputedStyle(footer).paddingBottom : null }
        })()
      JS
    end
  end

  def px(value) = value.to_f

  it "searches by name and opens a card without signing in (AC-3.6)", :aggregate_failures do
    search_for_bolt
    expect(page).to have_css("body > footer.c-footer", text: notice)
    expect(page).to have_no_css(".c-avatar")
    expect(page).to have_css(".c-appbar", text: "Sign in")

    result_tile.click
    expect(page).to have_css("h1", text: "Lightning Bolt")
    expect(page).to have_current_path(catalog_entry_path(bolt))
    expect(page).to have_no_css(".c-avatar")
    expect(page).to have_no_text("Add a copy")
    expect(page).to have_css("body > footer.c-footer", text: notice)
    expect(page).to have_css(".c-appbar", text: "Sign in")
  end

  it "fits the search and card pages on a 390px phone, with Sign in in view (AC-5.5)", :aggregate_failures do
    visit catalog_entries_path

    { catalog_entries_path(q: "bolt") => ".c-group", catalog_entry_path(bolt) => "h1" }.each do |path, ready|
      expect(open_in_narrow_frame(path, width: 390, ready:)).to eq([ 390, true ]), "#{path} scrolls sideways at 390px"
      within_narrow_frame { expect(page).to have_css(".c-appbar a", text: "Sign in", visible: true), "#{path}: no Sign in" }
    end
  end

  it "gives up the tab bar's clearance on a footed shell with no tab bar, and keeps it for a collector (AC-5.7)", :aggregate_failures do
    InstanceSetting.current.update!(sign_up_open: true)
    visit catalog_entries_path
    pages = { catalog_entries_path(q: "bolt") => ".c-group", new_session_path => "form", new_registration_path => "form" }
    pages.each do |path, ready|
      shell = clearance_at(path, ready:)
      expect(shell["scrolled"]).to be_positive, "#{path}: nothing to scroll"
      expect(px(shell["footer"])).to be < 80, "#{path}: the footer keeps the tab bar's clearance"
      expect(shell["main"]).to eq("16px"), "#{path}: c-main's padding"
    end

    system_sign_in_as(user)
    shell = clearance_at(catalog_entries_path(q: "bolt"), ready: ".c-group")
    expect(shell["scrolled"]).to be_positive
    expect(px(shell["footer"])).to be >= 80
    expect(shell["main"]).to eq("16px")
  end

  # Amendment 5: the "other" type has no content notice, so the shell has no footer; the search page without a query
  # shows no tiles, whose images that source wouldn't allow.
  it "gives up the tab bar's clearance on an unfooted shell with no tab bar, and keeps it for a collector (AC-5.7)", :aggregate_failures do
    with_catalog_sources("other" => "OtherCatalogSource") do
      visit catalog_entries_path
      visitor = clearance_at(catalog_entries_path, ready: "main.c-main")
      expect(visitor["scrolled"]).to be_positive
      expect(visitor["footer"]).to be_nil
      expect(px(visitor["main"])).to be < 80

      system_sign_in_as(user)
      collector = clearance_at(catalog_entries_path, ready: "main.c-main")
      expect(collector["scrolled"]).to be_positive
      expect(collector["footer"]).to be_nil
      expect(px(collector["main"])).to be >= 80
    end
  end

  # Decision 4: Turbo reuses a prefetched page without asking the server again, so a visitor's catalog pages turn
  # prefetch off. The page is marked #prefetched when Turbo sends a prefetch request, and #settled a second after the
  # pointer enters a link: Turbo prefetches 100ms after it does, so by then a prefetch would have been sent.
  it "doesn't prefetch a hovered result for a visitor", :aggregate_failures do
    search_for_bolt
    page.execute_script(<<~JS)
      const mark = (id) => { const element = document.createElement("div"); element.id = id; document.body.append(element) }
      document.addEventListener("turbo:before-fetch-request", (event) => {
        if (event.detail.fetchOptions.headers["X-Sec-Purpose"] === "prefetch") mark("prefetched")
      })
      document.addEventListener("mouseenter", (event) => {
        if (event.target.matches?.("a.c-tile")) setTimeout(() => mark("settled"), 1000)
      }, { capture: true })
    JS

    result_tile.hover
    expect(page).to have_css("#settled", visible: :all)
    expect(page).to have_no_css("#prefetched", visible: :all)
  end

  it "comes back to the card after signing in from it (decision 4)", :aggregate_failures do
    search_for_bolt
    result_tile.hover
    result_tile.click
    expect(page).to have_css("h1", text: "Lightning Bolt")

    within(".c-appbar") { click_link "Sign in" }
    fill_in "Email", with: user.email_address
    fill_in "Password", with: AuthenticationHelpers::PASSWORD
    click_button "Sign in"

    expect(page).to have_css(".c-avatar")
    expect(page).to have_css("h1", text: "Lightning Bolt")
    expect(page).to have_current_path(catalog_entry_path(bolt))
  end
end
