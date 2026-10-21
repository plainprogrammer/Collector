Capybara.enable_aria_label = true

# Where the suite's Firefox saves downloads (spec 022); emptied before each example that reads it.
DOWNLOADS = Rails.root.join("tmp/downloads")

# Rails asks Selenium Manager for Firefox's binary only while building the first driver of a process; it then sets
# the driver path, so later drivers find no binary. The default driver's session is reused, but a driver registered
# under another name (the dark-theme examples) starts a new session and needs the first one's binary (issue #118).
module FirefoxBinary
  def self.pin(options)
    @path ||= options.binary
    options.binary ||= @path
  end
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Camera pages get Firefox's synthetic stream without a prompt; scanner specs then substitute their own
    # card in the page (ADR 0002). Downloads land in DOWNLOADS without asking. The colour scheme is pinned to
    # light so the examples don't follow the host's appearance (issue #118); dark examples register their own
    # driver under another name, so the two never share a session.
    driven_by :selenium, using: :headless_firefox, screen_size: [ 1400, 1400 ] do |options|
      FirefoxBinary.pin(options)
      options.add_preference("ui.systemUsesDarkTheme", 0)
      options.add_preference("layout.css.prefers-color-scheme.content-override", 1) # 1 = light
      options.add_preference("media.navigator.permission.disabled", true)
      options.add_preference("media.navigator.streams.fake", true)
      options.add_preference("browser.download.folderList", 2)
      options.add_preference("browser.download.dir", DOWNLOADS.to_s)
    end
  end
end
