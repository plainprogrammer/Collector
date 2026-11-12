# Headless Firefox won't open a window narrower than 500px, so phone widths are tested by loading
# the page in a fixed-width same-origin iframe (id "narrow") on top of the current page.
module NarrowFrame
  # Loads path in a width × height frame, waits for the ready selector inside it and returns
  # [the frame's innerWidth, whether its page fits without horizontal scrolling (see narrow_frame_fits?)].
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

  # Whether the page in the narrow frame fits without horizontal scrolling, measured now.
  # Call it from the top page, outside within_narrow_frame (it reaches the frame through #narrow).
  #
  # The page's scrollWidth is compared with the documentElement's clientWidth, the width the layout has, and not with
  # innerWidth: innerWidth includes a vertical scrollbar (classic, 15px, in system specs, #271), which the frame draws
  # whenever its page is taller than it, so a page scrolling sideways by up to that much would pass (#318).
  def narrow_frame_fits?
    page.evaluate_script(<<~JS)
      (() => { const doc = document.getElementById("narrow").contentWindow.document.documentElement
        return doc.scrollWidth <= doc.clientWidth })()
    JS
  end

  def within_narrow_frame(&)
    within_frame("narrow", &)
  end
end

RSpec.configure do |config|
  config.include NarrowFrame, type: :system
end
