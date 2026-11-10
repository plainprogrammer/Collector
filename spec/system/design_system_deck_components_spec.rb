require "rails_helper"

# Spec 060: the CSS the deck components need, proved in headless Firefox on the app's own pages. No deck view exists yet
# (#49 builds the first), so each component's markup is added to a real page (the Locations page) inside a wrapper `div`
# whose width the example sets; a container query answers the wrapper's width.
RSpec.describe "Design system: deck components", type: :system do
  let(:user) { create(:user) }

  before do
    system_sign_in_as(user)
    visit locations_path
    blank_host
  end

  def theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def add_to_main(html) = page.execute_script("document.querySelector('main').insertAdjacentHTML('beforeend', arguments[0])", html)
  def evaluate(script) = page.evaluate_script("(() => { #{script} })()")

  # Clears the host page so its own rules cannot answer the examples: the Locations page's `c-locations` class gives every
  # `.c-btn` and `.c-input` a 44px floor, which would pass a size example without the new rule, and its own `.c-form` and
  # `.c-pagehead` would match an unscoped selector. In a narrow frame the same call runs inside the frame.
  def blank_host
    page.execute_script(<<~JS)
      const main = document.querySelector("main")
      main.className = "c-main c-page"
      main.replaceChildren()
    JS
  end

  # The computed values of one element, by CSS property name, in the order asked.
  def computed(selector, *properties)
    evaluate(<<~JS)
      const style = getComputedStyle(document.querySelector(#{selector.to_json}))
      return #{properties.to_json}.map((name) => style.getPropertyValue(name))
    JS
  end

  # A token as the browser resolves it for the current theme, written "rgb(r, g, b)".
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
  def box(selector)
    evaluate(<<~JS)
      const rect = document.querySelector(#{selector.to_json}).getBoundingClientRect()
      return { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom, width: rect.width, height: rect.height }
    JS
  end

  # `html` inside a wrapper of a set width: a container query answers the wrapper, not the window. A table's wrapper is
  # `container: "collection"`.
  def wrap(width, html, container: "page") = %(<div class="c-#{container}" style="width:#{width}px">#{html}</div>)

  describe "ProxyTag (AC-1.2, AC-1.3)" do
    def tag = %(<span class="c-proxy" id="probe">Proxy <b>2</b></span>)

    %w[light dark].each do |name|
      it "is a dashed, uncoloured tag, 20px high, in the #{name} theme", :aggregate_failures do
        add_to_main(tag)
        theme(name)
        expect(computed("#probe", "border-top-style", "border-top-color", "color", "height"))
          .to eq([ "dashed", token("--ink-muted"), token("--ink"), "20px" ])
        expect(computed("#probe", "border-top-left-radius")).to eq([ "4px" ])
      end
    end

    it "reads the word Proxy and the count" do
      add_to_main(tag)
      expect(evaluate('return document.querySelector("#probe").textContent')).to match(/\AProxy\s+2\z/)
    end
  end
end
