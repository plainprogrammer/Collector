# Headless Firefox won't open a window narrower than 500px, so phone widths are tested by loading
# the page in a fixed-width same-origin iframe (id "narrow") on top of the current page.
module NarrowFrame
  # Loads path in a width × height frame, waits for the ready selector inside it and returns
  # [the frame's innerWidth, whether its page fits without horizontal scrolling].
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
    page.evaluate_script(<<~JS)
      (() => { const view = document.getElementById("narrow").contentWindow
        return [ view.innerWidth, view.document.documentElement.scrollWidth <= view.innerWidth ] })()
    JS
  end

  def within_narrow_frame(&)
    within_frame("narrow", &)
  end
end

RSpec.configure do |config|
  config.include NarrowFrame, type: :system
end
