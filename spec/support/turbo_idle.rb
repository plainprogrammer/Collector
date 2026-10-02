# Waits until Turbo has finished the current navigation (no aria-busy on <html>), so
# page.go_back/go_forward don't land mid-navigation.
module TurboIdle
  def wait_for_turbo_idle
    expect(page).to have_no_css("html[aria-busy]", visible: :all)
  end
end

RSpec.configure do |config|
  config.include TurboIdle, type: :system
end
