require "rails_helper"

# Spec 015 AC-1.1 in a browser: the notice takes an admin from where the cards are missing to where they are loaded.
RSpec.describe "The not-loaded notice", type: :system do
  it "leads an admin from search to the catalog page, and from More to the jobs page", :aggregate_failures do
    system_sign_in_as(create(:admin))
    visit catalog_entries_path

    click_link "Go to the catalog page"
    expect(page).to have_css("h1", text: "Catalog")
    expect(page).to have_button("Refresh now")

    visit more_path
    click_link "Jobs"
    expect(page).to have_css("h1", text: "Jobs")
  end
end
