Capybara.enable_aria_label = true

# Where the suite's Firefox saves downloads (spec 022); emptied before each example that reads it.
DOWNLOADS = Rails.root.join("tmp/downloads")

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Camera pages get Firefox's synthetic stream without a prompt; scanner specs then substitute their own
    # card in the page (ADR 0002). Downloads land in DOWNLOADS without asking.
    driven_by :selenium, using: :headless_firefox, screen_size: [ 1400, 1400 ] do |options|
      options.add_preference("media.navigator.permission.disabled", true)
      options.add_preference("media.navigator.streams.fake", true)
      options.add_preference("browser.download.folderList", 2)
      options.add_preference("browser.download.dir", DOWNLOADS.to_s)
    end
  end
end
