# Waits until Turbo has finished the current navigation, so page.go_back/go_forward don't land
# mid-navigation: no visit in progress (aria-busy on <html>) and, with frames: true, no frame load
# in progress (busy on a turbo-frame).
#
# After Back restores a page from Turbo's snapshot, pass frames: false. Turbo 8.0.23 clones that
# snapshot while a frame-targeting form submission still marks the frame busy, so the restored
# frame keeps a stale busy attribute that never clears.
module TurboIdle
  def wait_for_turbo_idle(frames: true)
    expect(page).to have_no_css("html[aria-busy]", visible: :all)
    expect(page).to have_no_css("turbo-frame[busy]", visible: :all) if frames
  end
end

RSpec.configure do |config|
  config.include TurboIdle, type: :system
end
