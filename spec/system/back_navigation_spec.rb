require "rails_helper"

# Back after a filter must show the unfiltered page, however the browser's timing falls. Two races hit the
# old frame-advance filters on slow CI runners:
#
# - Page cache written first: Turbo caches the page it leaves under Turbo.session.view.lastRenderedLocation,
#   and a frame advance never updated it, so Back could file the filtered page under the unfiltered URL.
#   write_page_cache_early makes that write land before the restore reads the cache.
# - Late page visit: a frame advance pushed the URL and swapped the results, then waited two repaints before
#   starting the page visit that marks Turbo busy. Back in that gap was cancelled by the late visit.
#   slow_repaints_and_unfiltered_fetches widens the gap and makes Back's fetch outlast it.
RSpec.describe "Back after filtering in place", type: :system do
  it "shows the unfiltered collection even when the page cache is written first", :aggregate_failures do
    filter_collection_to_bolt
    wait_for_turbo_idle
    write_page_cache_early
    page.go_back

    expect(page).to have_current_path(collection_path)
    expect(page).to have_css(".c-filterbar__count", exact_text: "5 items")
  end

  it "shows the unfiltered collection even when repaints and the unfiltered fetch are slow", :aggregate_failures do
    filter_collection_to_bolt { slow_repaints_and_unfiltered_fetches }
    wait_for_turbo_idle
    page.go_back

    using_wait_time(5) do
      expect(page).to have_current_path(collection_path)
      expect(page).to have_css(".c-filterbar__count", exact_text: "5 items")
    end
  end

  it "shows the empty search page even when the page cache is written first", :aggregate_failures do
    search_for_bolt
    wait_for_turbo_idle
    write_page_cache_early
    page.go_back

    expect(page).to have_current_path(catalog_entries_path)
    expect(page).to have_css(".c-empty", text: "Type part of a card name to search.")
    expect(page).to have_no_css(".c-group h2")
  end

  it "shows the empty search page even when repaints and the unfiltered fetch are slow", :aggregate_failures do
    search_for_bolt { slow_repaints_and_unfiltered_fetches }
    wait_for_turbo_idle
    page.go_back

    using_wait_time(5) do
      expect(page).to have_current_path(catalog_entries_path)
      expect(page).to have_css(".c-empty", text: "Type part of a card name to search.")
      expect(page).to have_no_css(".c-group h2")
    end
  end

  private

  # Three Lightning Bolts and two Opts, filtered to "bolt". The block runs once the page has loaded.
  def filter_collection_to_bolt
    user = system_sign_in_as(create(:user))
    bolt = create(:mtg_printing).entry.tap { |e| e.update!(name: "Lightning Bolt") }
    opt = create(:mtg_printing).entry.tap { |e| e.update!(name: "Opt") }
    create(:lot, account: user.account, entry: bolt, quantity: 3)
    create(:lot, account: user.account, entry: opt, quantity: 2)
    visit collection_path
    yield if block_given?
    fill_in "Search your collection", with: "bolt"
    find_field("Search your collection").send_keys(:enter)
    expect(page).to have_css(".c-filterbar__count", text: "3 of 5 items")
  end

  # The block runs once the page has loaded.
  def search_for_bolt
    system_sign_in_as(create(:user))
    entry = create(:catalog_entry, name: "Lightning Bolt", identity: create(:catalog_identity, name: "Lightning Bolt"))
    create(:mtg_printing, entry:)
    visit catalog_entries_path
    yield if block_given?
    fill_in "Card name", with: "bolt"
    click_button "Search"
    expect(page).to have_css(".c-group h2", text: "Lightning Bolt")
  end

  def write_page_cache_early
    page.evaluate_async_script("Turbo.session.view.cacheSnapshot().then(() => arguments[0]())")
  end

  # Each animation frame waits 300ms, and fetches of a URL without a query string wait 1.5s.
  def slow_repaints_and_unfiltered_fetches
    page.execute_script(<<~JS)
      const requestFrame = window.requestAnimationFrame.bind(window)
      window.requestAnimationFrame = callback => setTimeout(() => requestFrame(callback), 300)
      const fetch = window.fetch.bind(window)
      window.fetch = (url, options) => new URL(url, location).search ? fetch(url, options) : new Promise(resolve => setTimeout(resolve, 1500)).then(() => fetch(url, options))
    JS
  end
end
