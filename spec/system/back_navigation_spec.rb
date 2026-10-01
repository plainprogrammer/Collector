require "rails_helper"

# Turbo caches the page it leaves under Turbo.session.view.lastRenderedLocation. A frame navigation with
# data-turbo-action="advance" pushes a new URL without updating that location, so Back's own cache write
# files the filtered page under the unfiltered URL. On a fast machine Back reads the cache before that write
# lands; on a slow one the write wins and the stale filtered results come back. The call to cacheSnapshot()
# below stands in for a slow browser: it makes that write land before the restore reads the cache.
RSpec.describe "Back after filtering in place", type: :system do
  it "shows the unfiltered collection even when the page cache is written first", :aggregate_failures do
    user = system_sign_in_as(create(:user))
    bolt = create(:mtg_printing).entry.tap { |e| e.update!(name: "Lightning Bolt") }
    opt = create(:mtg_printing).entry.tap { |e| e.update!(name: "Opt") }
    create(:lot, account: user.account, entry: bolt, quantity: 3)
    create(:lot, account: user.account, entry: opt, quantity: 2)
    visit collection_path
    fill_in "Search your collection", with: "bolt"
    find_field("Search your collection").send_keys(:enter)
    expect(page).to have_css(".c-filterbar__count", text: "3 of 5 items")

    wait_for_turbo_idle
    write_page_cache_early
    page.go_back

    expect(page).to have_current_path(collection_path)
    expect(page).to have_css(".c-filterbar__count", exact_text: "5 items")
  end

  it "shows the empty search page even when the page cache is written first", :aggregate_failures do
    system_sign_in_as(create(:user))
    entry = create(:catalog_entry, name: "Lightning Bolt", identity: create(:catalog_identity, name: "Lightning Bolt"))
    create(:mtg_printing, entry:)
    visit catalog_entries_path
    fill_in "Card name", with: "bolt"
    click_button "Search"
    expect(page).to have_css(".c-group h2", text: "Lightning Bolt")

    wait_for_turbo_idle
    write_page_cache_early
    page.go_back

    expect(page).to have_current_path(catalog_entries_path)
    expect(page).to have_css(".c-empty", text: "Type part of a card name to search.")
    expect(page).to have_no_css(".c-group h2")
  end

  private

  def write_page_cache_early
    page.evaluate_async_script("Turbo.session.view.cacheSnapshot().then(() => arguments[0]())")
  end
end
