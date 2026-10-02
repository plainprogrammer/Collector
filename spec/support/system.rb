Capybara.enable_aria_label = true

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Camera pages get Firefox's synthetic stream without a prompt; scanner specs then substitute their own
    # card in the page (ADR 0002).
    driven_by :selenium, using: :headless_firefox, screen_size: [ 1400, 1400 ] do |options|
      options.add_preference("media.navigator.permission.disabled", true)
      options.add_preference("media.navigator.streams.fake", true)
    end
  end
end
