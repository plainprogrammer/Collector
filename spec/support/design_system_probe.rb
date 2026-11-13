# What a system example about the design system's CSS needs to read from the browser: a computed style, a token as the
# theme resolves it, an element's box. Written twice before it was moved here, with a third copy due (spec 080); an example group that
# proves CSS includes it. Every method works on the page the driver is in, so inside `within_narrow_frame` it reads the frame.
module DesignSystemProbe
  # Pins the page's theme, as the app's `data-theme` does.
  #
  # @param name [String] "light" or "dark"
  # @return [void]
  def theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")

  # Adds markup at the end of the page's `main`.
  #
  # @param html [String] the markup
  # @return [void]
  def add_to_main(html) = page.execute_script("document.querySelector('main').insertAdjacentHTML('beforeend', arguments[0])", html)

  # Runs a script body in the page and returns what it returns.
  #
  # @param script [String] statements, ending in `return …` when a value is wanted
  # @return [Object] the script's value, as Selenium converts it
  def evaluate(script) = page.evaluate_script("(() => { #{script} })()")

  # The computed values of one element, by CSS property name, in the order asked.
  #
  # @param selector [String] a CSS selector; the first match is read
  # @param properties [Array<String>] property names, as CSS writes them ("border-top-width")
  # @return [Array<String>] the computed values
  def computed(selector, *properties)
    evaluate(<<~JS)
      const style = getComputedStyle(document.querySelector(#{selector.to_json}))
      return #{properties.to_json}.map((name) => style.getPropertyValue(name))
    JS
  end

  # A colour token as the browser resolves it for the current theme.
  #
  # @param name [String] the custom property, with its dashes ("--ink-muted")
  # @return [String] "rgb(r, g, b)", or "rgba(r, g, b, a)" for a token with an alpha
  def token(name)
    evaluate(<<~JS)
      const probe = document.createElement("span")
      probe.style.color = "var(#{name})"
      document.body.append(probe)
      const value = getComputedStyle(probe).color
      probe.remove()
      return value
    JS
  end

  # An element's border box in viewport pixels.
  #
  # @param selector [String] a CSS selector; the first match is measured
  # @return [Hash{String => Float}] "left", "top", "right", "bottom", "width", "height"
  def box(selector)
    evaluate(<<~JS)
      const rect = document.querySelector(#{selector.to_json}).getBoundingClientRect()
      return { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom, width: rect.width, height: rect.height }
    JS
  end
end
