# Headless Firefox reports no reduced-motion preference, and a driver with the preference set would be a second browser
# session. This module applies the stylesheets' `(prefers-reduced-motion: reduce)` rules itself, as `CoarsePointer` does
# for a coarse pointer (spec 080 AC-6.4).
module ReducedMotion
  # Applies every rule inside a `prefers-reduced-motion: reduce` media block of the loaded stylesheets to the current
  # document (or the current frame's), media wrapper removed, in source order, as one adopted sheet after every stylesheet.
  # A declaration keeps its `!important`. Nothing is written to the server and the change lasts until the page is left, so
  # a caller reads the moving state first and the still one after.
  #
  # @param needs [Array<String>] fragments of selector text that must be among the rules ("::backdrop",
  #   ".c-scanpane__row"), so an example about a new rule fails by naming it and not by a symptom
  # @return [Array<String>] the selector text of every rule applied, in source order
  # @raise [RuntimeError] when a fragment in `needs` matches no rule
  def apply_reduced_motion_rules(needs: [])
    selectors = page.evaluate_script(<<~JS)
      (() => {
        const css = [], seen = []
        for (const sheet of document.styleSheets)
          for (const media of sheet.cssRules)
            if (media instanceof CSSMediaRule && media.conditionText.includes("prefers-reduced-motion: reduce"))
              for (const rule of media.cssRules) { seen.push(rule.selectorText); css.push(rule.cssText) }
        const sheet = new CSSStyleSheet()
        sheet.replaceSync(css.join(" "))
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet]
        return seen
      })()
    JS
    missing = needs.reject { |fragment| selectors.any? { it.include?(fragment) } }
    raise "no reduced-motion rule matches #{missing.inspect} (found #{selectors.inspect})" if missing.any?

    selectors
  end
end

RSpec.configure do |config|
  config.include ReducedMotion, type: :system
end
