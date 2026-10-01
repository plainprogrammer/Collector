require "rails_helper"

RSpec.describe "Collection views", type: :system do
  let(:user) { system_sign_in_as(create(:user)) }

  def prefetches_after_half_a_second
    page.evaluate_async_script("const done = arguments[0]; setTimeout(() => done(window.__prefetches), 500)")
  end

  it "switches to the table, remembers it, and goes back to the grid", :aggregate_failures do
    owned_printing(account: user.account)
    visit collection_path
    click_on "Table"
    expect(page).to have_css("table.c-table")
    expect(page).to have_current_path(collection_path(view: "table"))
    expect(page).to have_css(".c-seg button[aria-pressed=true]", text: "Table")
    wait_for_turbo_idle
    page.go_back
    expect(page).to have_current_path(collection_path)
    visit collection_path
    expect(page).to have_css("table.c-table")
  end

  it "doesn't save a view the collector only points at", :aggregate_failures do
    owned_printing(account: user.account)
    visit collection_path
    page.execute_script("window.__prefetches = 0; document.addEventListener('turbo:before-prefetch', () => window.__prefetches++)")
    find(".c-appbar__nav a", text: "Search").hover
    expect(prefetches_after_half_a_second).to be > 0
    page.execute_script("window.__prefetches = 0")
    find(".c-seg button", text: "Table").hover
    expect(prefetches_after_half_a_second).to eq(0)
    expect(user.reload.collection_view).to eq("grid")
  end

  it "shows the switch as icons with names on a phone", :aggregate_failures do
    owned_printing(account: user.account)
    visit collection_path
    expect(open_in_narrow_frame(collection_path, width: 390, height: 844, ready: ".c-seg")).to eq([ 390, true ])
    within_narrow_frame do
      widths = page.evaluate_script("[...document.querySelectorAll('.c-seg__label')].map((label) => label.getBoundingClientRect().width)")
      expect(widths).to all(be <= 1)
      expect(page).to have_button("Grid")
      expect(page).to have_button("Table")
    end
  end
end
