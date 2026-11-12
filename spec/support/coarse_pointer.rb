# Headless Firefox has a fine pointer, so a system example about what a touch screen draws can't rely on the browser applying the
# stylesheets' `(pointer: coarse)` rules. This module applies them itself, all of them (spec 072's lesson: a rule applied alone
# measures a mix no device draws, such as 44px selects beside 28px buttons).
module CoarsePointer
  # Applies every `(pointer: coarse)` rule of the loaded stylesheets to the current document (or the current frame's), media
  # wrapper removed, in source order, as one adopted sheet after every stylesheet. Nothing is written to the server and the
  # change lasts until the page is left, so a caller can measure the fine-pointer state first and this one after.
  #
  # Raises when a selector named in `needs` is not among the coarse rules, so an example about a new rule fails by naming it
  # and not by a layout symptom (or passes with nothing applied, the two states being identical until the rule exists).
  #
  # @param needs [Array<String>] the `selectorText` of rules the example is about, exactly as the stylesheet writes them
  #   (a grouped rule's text is the whole list, such as `".c-btn, .c-input"`).
  # @return [Array<String>] the selector text of every coarse rule found, in source order.
  # @raise [RuntimeError] when a selector in `needs` is not in the loaded stylesheets.
  def apply_coarse_rules(needs: [])
    found = page.evaluate_script(<<~JS)
      (() => {
        const css = [], selectors = []
        for (const sheet of document.styleSheets)
          for (const media of sheet.cssRules)
            if (media instanceof CSSMediaRule && media.conditionText.includes("pointer: coarse"))
              for (const rule of media.cssRules) { selectors.push(rule.selectorText); css.push(rule.cssText) }
        const sheet = new CSSStyleSheet()
        sheet.replaceSync(css.join(" "))
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet]
        return selectors
      })()
    JS
    missing = Array(needs) - found
    raise "the coarse-pointer rule #{missing.inspect} is not in the loaded stylesheets (found #{found.inspect})" if missing.any?

    found
  end
end

RSpec.configure do |config|
  config.include CoarsePointer, type: :system
end
