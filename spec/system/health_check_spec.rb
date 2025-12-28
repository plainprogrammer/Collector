require "rails_helper"

RSpec.describe "Health check", type: :system do
  scenario "it shows green background" do
    visit rails_health_check_path
    expect(page).to have_css('body[style*="background-color: green"]')
  end
end
