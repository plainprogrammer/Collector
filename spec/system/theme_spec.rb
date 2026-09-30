require "rails_helper"

RSpec.describe "Theme", type: :system do
  it "follows the OS dark preference for tokens and the logo, with Turbo loaded", :aggregate_failures do
    driven_by :selenium, using: :headless_firefox, screen_size: [ 1280, 900 ], options: { name: :firefox_dark } do |options|
      options.add_preference("ui.systemUsesDarkTheme", 1)
      options.add_preference("layout.css.prefers-color-scheme.content-override", 0) # 0 = dark
    end
    system_sign_in_as(create(:user))
    visit collection_path

    # Dark --surface is #161513 in tokens.css.
    expect(page.evaluate_script("getComputedStyle(document.body).backgroundColor")).to eq("rgb(22, 21, 19)")
    expect(page).to have_css(".c-appbar__wordmark .c-logo--dark", visible: :visible)
    expect(page).to have_no_css(".c-appbar__wordmark .c-logo--light", visible: :visible)
    expect(page.evaluate_script("typeof window.Turbo")).to eq("object")
  end
end
