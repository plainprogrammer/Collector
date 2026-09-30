Capybara.enable_aria_label = true

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_firefox, screen_size: [ 1400, 1400 ]
  end
end
