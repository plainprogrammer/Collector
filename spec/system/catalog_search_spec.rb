require "rails_helper"

RSpec.describe "Card search", type: :system do
  it "finds a card and opens a printing", :aggregate_failures do
    search_for_bolt

    click_link "Lightning Bolt"
    expect(page).to have_css("h1", text: "Lightning Bolt")
  end

  # Issue #62: this page's old frame-advance filter swapped the results in, then waited two repaints before
  # starting a page visit. On slow CI runners a click on a result landed in that gap, and the late visit
  # cancelled it (navigator.stop()), so the search page stayed. slow_repaints_and_card_page_fetches widens
  # the gap and keeps the click's fetch in flight across it.
  it "opens a printing even when repaints and the card page's fetch are slow", :aggregate_failures do
    search_for_bolt { slow_repaints_and_card_page_fetches }

    click_link "Lightning Bolt"
    using_wait_time(5) do
      expect(page).to have_css("h1", text: "Lightning Bolt")
      expect(page).to have_current_path(%r{\A/catalog/entries/[^/?]+\z})
    end
  end

  private

  # The block runs once the search page has loaded.
  def search_for_bolt
    system_sign_in_as(create(:user))
    set = create(:catalog_set, code: "m10", name: "Magic 2010")
    entry = create(:catalog_entry, set:, name: "Lightning Bolt", identity: create(:catalog_identity, name: "Lightning Bolt"))
    create(:mtg_printing, entry:)

    visit catalog_entries_path
    yield if block_given?
    fill_in "Card name", with: "bolt"
    click_button "Search"
    expect(page).to have_css(".c-group h2", text: "Lightning Bolt")
  end

  # Each animation frame waits 300ms (and can still be cancelled), and fetches of a card page wait 1.5s.
  def slow_repaints_and_card_page_fetches
    page.execute_script(<<~JS)
      const requestFrame = window.requestAnimationFrame.bind(window)
      const cancelFrame = window.cancelAnimationFrame.bind(window)
      const waiting = new Map()
      let nextId = 1e9
      window.requestAnimationFrame = callback => {
        const id = nextId++
        const entry = { frame: null }
        entry.timeout = setTimeout(() => { entry.frame = requestFrame(time => { waiting.delete(id); callback(time) }) }, 300)
        waiting.set(id, entry)
        return id
      }
      window.cancelAnimationFrame = id => {
        const entry = waiting.get(id)
        if (!entry) return cancelFrame(id)
        clearTimeout(entry.timeout)
        if (entry.frame != null) cancelFrame(entry.frame)
        waiting.delete(id)
      }
      const fetch = window.fetch.bind(window)
      const cardPage = new RegExp("/catalog/entries/[^/?]+$")
      window.fetch = (url, options) => cardPage.test(new URL(url, location).pathname)
        ? new Promise(resolve => setTimeout(resolve, 1500)).then(() => fetch(url, options)) : fetch(url, options)
    JS
  end
end
