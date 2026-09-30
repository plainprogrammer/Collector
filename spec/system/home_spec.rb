require "rails_helper"

RSpec.describe "Home page", type: :system do
  it "shows the app name with Turbo loaded", :aggregate_failures do
    system_sign_in_as(create(:user))
    visit root_path

    expect(page).to have_css("h1", text: "Collector")
    expect(page.evaluate_script("typeof window.Turbo")).to eq("object")
  end
end
