require "rails_helper"

RSpec.describe "Page head", type: :system do
  # Section spacing (space-6, 24px) separates a page head from the form below it.
  def gap_below_page_head
    page.evaluate_script(<<~JS)
      document.querySelector(".c-form").getBoundingClientRect().top -
        document.querySelector(".c-pagehead").getBoundingClientRect().bottom
    JS
  end

  it "spaces the add-a-copy form below the page head", :aggregate_failures do
    entry = create(:mtg_printing).entry
    system_sign_in_as(create(:user))
    visit new_catalog_entry_lot_path(entry)
    expect(page).to have_css(".c-form")
    expect(gap_below_page_head).to be >= 24
  end

  it "spaces the add-a-user form below the page head", :aggregate_failures do
    system_sign_in_as(create(:admin))
    visit new_admin_user_path
    expect(page).to have_css(".c-form")
    expect(gap_below_page_head).to be >= 24
  end
end
