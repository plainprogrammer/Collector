# Headless Firefox won't open a window narrower than 500px, so phone widths are tested by loading
# the page in a fixed-width same-origin iframe (id "narrow") on top of the current page.
module NarrowFrame
  # Loads path in a width × height frame, waits for the ready selector inside it and returns
  # [the frame's innerWidth, whether its page fits without horizontal scrolling (see narrow_frame_fits?)].
  #
  # @param path [String] the page to load, on the current origin
  # @param width [Integer] the frame's width in px (its innerWidth, scrollbar included)
  # @param ready [String] a CSS selector that must be present in the frame before it is measured
  # @param height [Integer] the frame's height in px; shorter than the page, the frame draws a vertical scrollbar
  # @return [Array(Integer, Boolean)] the frame's innerWidth and whether its page fits
  def open_in_narrow_frame(path, width:, ready:, height: 800)
    page.execute_script(<<~JS, path, width, height)
      document.getElementById("narrow")?.remove()
      const frame = document.createElement("iframe")
      frame.id = "narrow"
      frame.style.cssText = `position:fixed;top:0;left:0;width:${arguments[1]}px;height:${arguments[2]}px;border:0;z-index:2147483647`
      frame.src = arguments[0]
      document.body.append(frame)
    JS
    within_narrow_frame { find(ready) }
    [ page.evaluate_script("document.getElementById('narrow').contentWindow.innerWidth"), narrow_frame_fits? ]
  end

  # Loads path in a frame whose viewport (its documentElement.clientWidth) is viewport px wide, the way a phone of that width is:
  # open_in_narrow_frame's width includes the frame's classic scrollbar, so a "360px" frame there lays a page out in 345px or 348px.
  # The frame is the viewport plus the scrollbar it draws, measured (about 15px on a Mac, 12px on the Linux runner) and reopened
  # once if the first guess was wrong.
  #
  # @param path [String] the page to load, on the current origin
  # @param viewport [Integer] the width the page is laid out in, in px
  # @param ready [String] a CSS selector that must be present in the frame before it is measured
  # @param height [Integer] the frame's height in px
  # @return [Integer] the viewport the frame got, for the example to assert
  def open_in_viewport_frame(path, viewport:, ready:, height: 800)
    width = viewport + 15
    2.times do
      open_in_narrow_frame(path, width:, ready:, height:)
      scrollbar = within_narrow_frame { page.evaluate_script("window.innerWidth - document.documentElement.clientWidth") }
      break if viewport + scrollbar == width

      width = viewport + scrollbar
    end
    within_narrow_frame { page.evaluate_script("document.documentElement.clientWidth") }
  end

  # Whether the page the driver is in (the top page, or the frame's inside within_narrow_frame) fits without horizontal
  # scrolling, measured now. The one measure of sideways overflow, so a check never has to write it again (#318).
  #
  # The page's scrollWidth is compared with the documentElement's clientWidth, the width the layout has, and not with
  # innerWidth: innerWidth includes a vertical scrollbar (classic in system specs, #271, about 15px on a Mac and 12px on
  # CI), which the page has whenever it is taller than its window or frame, so a page scrolling sideways by up to that
  # much would pass.
  #
  # @return [Boolean]
  def page_fits_sideways?
    page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  end

  # Whether the page in the narrow frame fits without horizontal scrolling, measured now (see page_fits_sideways?).
  # Call it from the top page, outside within_narrow_frame, which it enters itself.
  #
  # @return [Boolean]
  def narrow_frame_fits?
    within_narrow_frame { page_fits_sideways? }
  end

  def within_narrow_frame(&)
    within_frame("narrow", &)
  end
end

RSpec.configure do |config|
  config.include NarrowFrame, type: :system
end
