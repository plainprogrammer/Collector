module TurboIdle
  # Waits until Turbo has finished the current navigation (no aria-busy on <html>) and the scroll events it queued have been
  # delivered, so page.go_back/go_forward don't land mid-navigation or in the frame of the page's own scroll-to-top.
  # Call it from the top page; for a page in the narrow frame call {#wait_for_scroll_events} with the frame instead.
  def wait_for_turbo_idle
    expect(page).to have_no_css("html[aria-busy]", visible: :all)
    wait_for_scroll_events
  end

  # Waits, with no sleep, for the rendering step that follows now in a window, in which the browser delivers the scroll events
  # queued so far, so Turbo's scroll observer has recorded them before the example goes Back (#404).
  #
  # A Turbo visit scrolls the new page to the top when it renders, and that queues a scroll event for the next frame. Back before
  # that frame makes `popstate` switch Turbo's current restoration identifier to the previous page's entry first, so the queued
  # event, which reports the new page's scroll of 0, is recorded against the previous entry and replaces the position the
  # restore visit is about to put back: the page comes back scrolled to 0. No `aria-busy` shows it (Turbo clears it at
  # `turbo:load`, before the frame), so {#wait_for_turbo_idle}'s first expectation passes in the gap.
  #
  # It waits two animation frames (a scroll event is delivered in the rendering step before a frame's callbacks), or two
  # timeouts when the window is hidden, as Turbo's own render does.
  #
  # @param frame [String, nil] the id of an iframe on the top page whose window to wait in (the narrow frame, `"narrow"`);
  #   nil waits in the top page's window. Always call it from the top page, never inside `within_frame`.
  # @return [true]
  def wait_for_scroll_events(frame: nil)
    window = frame ? "document.getElementById(#{frame.to_json}).contentWindow" : "window"
    page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      const w = #{window}
      const next = (callback) => w.document.visibilityState === "hidden" ? w.setTimeout(callback, 0) : w.requestAnimationFrame(callback)
      next(() => next(() => done(true)))
    JS
  end
end

RSpec.configure do |config|
  config.include TurboIdle, type: :system
end
