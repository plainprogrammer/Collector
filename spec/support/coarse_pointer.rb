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
  # @param needs [Array<String, Hash>] the rules the example is about, in the same forms as `needs:` of {#inject_coarse}: the
  #   `selectorText` exactly as the stylesheet writes it (a grouped rule's text is the whole list, such as `".c-btn, .c-input"`),
  #   or `{ sheet:, selector: }` when two stylesheets have the same selector text.
  # @return [Array<String>] the selector text of every coarse rule found, in source order.
  # @raise [RuntimeError] when a selector in `needs` is not in the loaded stylesheets.
  def apply_coarse_rules(needs: [])
    inject_coarse(needs:)
  end

  # Applies the coarse-pointer rules like {#apply_coarse_rules}, and lets an example leave some out, keep only some, or add CSS.
  # A rule is named by its selector text, or by `{ sheet:, selector: }` when the same selector text is in two stylesheets (spec
  # 075: `components.css` and `additions.css` both have `.c-btn--sm, .c-filter, .c-seg button`); `sheet` is a fragment of the
  # stylesheet's URL (`"additions"`). A bare selector text matches the rule of any stylesheet. Name rules by selector text and
  # stylesheet, never by value: `additions.css` has other coarse rules at `var(--touch-floor)` that a value match would drop.
  #
  # @param only [Array<String>, nil] selector texts to keep; nil keeps all
  # @param except [Array<String, Hash>] rules to leave out
  # @param extra [String] CSS appended after the rules (for a can-fail variant)
  # @param needs [Array<String, Hash>] rules that must exist, or the call raises naming them
  # @return [Array<String>] the selector text of every coarse rule found, in source order
  # @raise [RuntimeError] when a rule in `only` or `needs` is not in the loaded stylesheets
  def inject_coarse(only: nil, except: [], extra: "", needs: [])
    except = Array.wrap(except).map { |rule| rule.is_a?(Hash) ? rule.stringify_keys : { "selector" => rule } }
    rules = page.evaluate_script(<<~JS, only, except, extra)
      (() => {
        const [only, except, extra] = arguments
        const css = [], seen = []
        for (const sheet of document.styleSheets)
          for (const media of sheet.cssRules)
            if (media instanceof CSSMediaRule && media.conditionText.includes("pointer: coarse"))
              for (const rule of media.cssRules) {
                seen.push({ selector: rule.selectorText, sheet: sheet.href || "" })
                const dropped = except.some((entry) => entry.selector === rule.selectorText && (!entry.sheet || (sheet.href || "").includes(entry.sheet)))
                if ((!only || only.includes(rule.selectorText)) && !dropped) css.push(rule.cssText)
              }
        const sheet = new CSSStyleSheet()
        sheet.replaceSync(css.join(" ") + " " + extra)
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet]
        return seen
      })()
    JS
    selectors = rules.map { |rule| rule["selector"] }
    missing = (Array.wrap(only) + Array.wrap(needs)).reject do |wanted|
      if wanted.is_a?(Hash)
        wanted = wanted.stringify_keys
        rules.any? { |rule| rule["selector"] == wanted["selector"] && rule["sheet"].include?(wanted["sheet"].to_s) }
      else
        selectors.include?(wanted)
      end
    end
    raise "the coarse-pointer rule #{missing.inspect} is not in the loaded stylesheets (found #{selectors.inspect})" if missing.any?

    selectors
  end

  # Page overflow, wide selects and overlapping controls of the current document (spec 072 AC-1.4, spec 075 AC-1.4). A
  # control counts when it is not visually hidden (`.c-sr`) or in a closed menu, has a box, and is not clipped away by the
  # nearest ancestor that clips its overflow; a control of the filter row always counts, as the row scrolls sideways inside
  # itself on a phone (spec 057 decision 4).
  #
  # @param roots [Array<String>] the containers whose controls are measured (spec 075 adds the header and `#status`)
  # @return [Hash] `"overflow"` (px the page scrolls sideways), `"overlaps"` (pairs of control labels), `"wide"` (labels of
  #   selects wider than their container)
  def layout_report(roots: [ "main" ])
    controls = roots.flat_map { |root| %w[select input:not([type=hidden]) button .c-btn summary].map { |tag| "#{root} #{tag}" } }.join(", ")
    page.evaluate_script(<<~JS, controls)
      (() => {
        const clipper = (el) => {
          for (let p = el.parentElement; p && p !== document.body && p !== document.documentElement; p = p.parentElement) {
            const style = getComputedStyle(p)
            if ([style.overflowX, style.overflowY].some((value) => value !== "visible")) return p
          }
          return null
        }
        // Firefox still reports a box for the items of a closed `<details>` menu (an absolutely placed list nobody sees), which
        // would overlap the table beneath it; only the menu's own summary is drawn.
        const inClosedMenu = (el) => {
          const details = el.closest("details:not([open])")
          return !!details && !(el.tagName === "SUMMARY" && el.parentElement === details)
        }
        const meets = (a, b) => !(a.right <= b.left || b.right <= a.left || a.bottom <= b.top || b.bottom <= a.top)
        const label = (el) => el.tagName.toLowerCase() + (el.id ? "#" + el.id : "") + (el.className ? "." + String(el.className).split(" ").join(".") : "")
        const controls = [...document.querySelectorAll(arguments[0])]
          .filter((el) => !el.closest(".c-sr") && !inClosedMenu(el))
          .map((el) => ({ el, rect: el.getBoundingClientRect(), row: !!el.closest(".c-filterbar__filters") }))
          .filter(({ el, rect, row }) => rect.width > 0 && rect.height > 0 && (row || !clipper(el) || meets(rect, clipper(el).getBoundingClientRect())))
        const overlaps = []
        controls.forEach((a, i) => controls.slice(i + 1).forEach((b) => {
          const w = Math.min(a.rect.right, b.rect.right) - Math.max(a.rect.left, b.rect.left)
          const h = Math.min(a.rect.bottom, b.rect.bottom) - Math.max(a.rect.top, b.rect.top)
          if (w > 1 && h > 1) overlaps.push([label(a.el), label(b.el)])
        }))
        const wide = [...document.querySelectorAll("main select")].filter((el) => {
          const box = el.closest(".c-form, .c-numentry__line, .c-filterbar__filters, main")
          return el.getBoundingClientRect().width > box.getBoundingClientRect().width + 1
        }).map(label)
        // clientWidth, not innerWidth: innerWidth includes a classic scrollbar's 15px, which would hide a sideways overflow that small
        return { overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth, overlaps, wide }
      })()
    JS
  end
end

RSpec.configure do |config|
  config.include CoarsePointer, type: :system
end
