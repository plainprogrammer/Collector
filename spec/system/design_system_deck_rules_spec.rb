require "rails_helper"

# Spec 057: the CSS the deck rules need, proved in headless Firefox on the app's own pages. The grouped selects and the
# stat strips have no page yet (the deck issues build them), so their markup is added to a real page; the header and the
# tab bar are the app's own partials, with the Decks link and tab that #49 adds put in by the example.
RSpec.describe "Design system: deck rules, navigation and pickers", type: :system do
  let(:user) { create(:user) }
  let(:binder) { create(:location, account: user.account, name: "Blue binder") }

  before { system_sign_in_as(user) }

  # A flat option, then a "Places" group and a "Decks" group, as the picker rule of FR-4 draws them. The last option is
  # the selected one, so neither option the examples read is the checked one, whose highlight Firefox draws itself.
  def picker
    <<~HTML.squish
      <option value="">No location</option>
      <optgroup label="Places"><option value="1">Blue binder</option></optgroup>
      <optgroup label="Decks"><option value="2">Izzet Tempo (all zones)</option><option value="3" selected>Izzet Tempo › Main</option></optgroup>
    HTML
  end

  # The two select shapes the app has: a form field (`.c-field select`) and a filter-bar select (`.c-select select`).
  def probe(kind)
    case kind
    when :form then %(<div class="c-field" id="probe-form"><label class="c-field__label" for="probe-form-select">Place</label><select id="probe-form-select">#{picker}</select></div>)
    when :filter then %(<label class="c-select" id="probe-filter"><span class="c-sr">Location</span><select>#{picker}</select></label>)
    end
  end

  def own = owned_printing("Lightning Bolt", account: user.account, location: binder)
  def theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def add_to_main(html) = page.execute_script("document.querySelector('main').insertAdjacentHTML('beforeend', arguments[0])", html)
  def evaluate(script) = page.evaluate_script("(() => { #{script} })()")

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

  describe "grouped selects (AC-4.2, AC-4.3)" do
    { form: "#probe-form select", filter: "#probe-filter select" }.each do |kind, select|
      %w[light dark].each do |name|
        it "styles the labels and options of the #{kind} select in the #{name} theme", :aggregate_failures do
          own
          visit collection_path
          add_to_main(probe(kind))
          theme(name)
          expect(computed("#{select} optgroup", "color", "font-weight", "font-style")).to eq([ token("--ink-muted"), "600", "normal" ])
          expect(computed("#{select} optgroup option", "color", "background-color", "font-weight"))
            .to eq([ token("--ink"), token("--surface-raised"), "400" ])
          # An option outside any group carries no label style: it keeps the select's own text colour and weight.
          expect(computed("#{select} > option", "color", "font-weight")).to eq([ token("--ink"), "400" ])
          # A rule that set `font` on the optgroup, or a browser's own optgroup font, would change the options in it.
          expect(computed("#{select} optgroup option", "font-size", "font-family")).to eq(computed(select, "font-size", "font-family"))
        end
      end
    end
  end

  describe "the location filter's cap (AC-4.4)" do
    def cap(selector) = computed(selector, "max-width").first
    def collection_width(pixels) = page.execute_script("document.querySelector('.c-collection').style.width = arguments[0] + 'px'", pixels)

    it "is 300px in a collection 700px wide, in normal view and in bulk mode; the Set select beside it stays 220px", :aggregate_failures do
      own
      visit collection_path(view: "table")
      collection_width(700)
      expect(cap("select[name=location]")).to eq("300px")
      visit collection_path(bulk: 1)
      expect(page).to have_css(".c-bulkbar")
      collection_width(700)
      expect(cap("select[name=location]")).to eq("300px")
      visit catalog_entries_path
      collection_width(700)
      expect(cap(".c-select select")).to eq("220px")
    end

    it "is 220px in a 390px phone frame, in normal view and in bulk mode", :aggregate_failures do
      own
      visit collection_path
      open_in_narrow_frame(collection_path(view: "table"), width: 390, ready: "select[name=location]")
      within_narrow_frame { expect(cap("select[name=location]")).to eq("220px") }
      open_in_narrow_frame(collection_path(bulk: 1), width: 390, ready: ".c-bulkbar")
      within_narrow_frame { expect(cap("select[name=location]")).to eq("220px") }
    end
  end
end
