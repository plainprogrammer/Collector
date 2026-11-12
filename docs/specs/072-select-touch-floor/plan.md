# Plan 072: Selects Meet the Touch Floor on a Coarse Pointer, App-Wide

**Spec:** [spec.md](spec.md) 0.3.0 (approved, Gate A) | **Issue:** [#315](https://github.com/plainprogrammer/Collector/issues/315) | **Branch:** `072-select-touch-floor`

## Global Constraints

- Test first, one commit per task. Targeted `bin/rspec <file>` runs need no CI slot; a full `bin/ci`, or a push whose pre-push hook runs it, needs a slot from the coordinator.
- Never run two test runs at once in this worktree (they share the test database).
- Headless Firefox has a fine pointer and can't emulate a coarse one: examples read the `(pointer: coarse)` rules from the loaded stylesheets and apply them as an adopted stylesheet (spec decision 3). Every example that needs the rule reads it first and says so when it is missing, so a red run names the missing rule and not a downstream symptom.
- No view, helper, controller, model, migration or export change, and no stylesheet but `additions.css` (FR-4, AC-3.1). The block's comment may cite specs 057, 068 and 072 and must not contain "spec 019", "spec 021" or "spec 023" (`spec/design_system_files_spec.rb` counts them across the whole file).
- Styles use the token `var(--touch-floor)`, never a literal 44px (`additions.css` line 367).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. One git operation per shell call (stage, then commit).
- Off limits: `.kamal/secrets`, `config/master.key`, `.env*`, `storage/`, `*.sqlite3`; every `git grep` ends with `':!.kamal/secrets'`.
- Run `bin/rubocop -a` on each Ruby file written (the project's hook does too); array literals use the omakase style `[ a, b ]`.

## Goal

One block in `additions.css` gives every `c-field` and `c-select` select the touch floor on a coarse pointer and centres the filter row's controls there; two rules it makes redundant go (the `.c-select` 40px coarse rule and the `.c-decks` select block); eight component documents and the README's Touch rule say so; one system spec file proves it against the twelve pages of the spec's audit (and measurement mode); evidence shots show the selects before and after on a coarse pointer, as far as the stylesheet allows.

## Pre-implementation gates

- **Simplicity:** one stylesheet block, one spec file, documents. No new component, dependency or abstraction. Pass.
- **Anti-abstraction:** the example uses the framework's own `document.styleSheets`/`CSSStyleSheet`; no wrapper beyond a handful of private helpers in the spec file. Pass.
- **Integration-first:** the contract is the CSS rule's selectors and value (AC-1.1); Phase 1 writes the examples that read it before the rule exists. Pass.

## The existing examples that change (from a grep, not from memory)

Command (run 2026-11-11 from the repo root): `git grep -n -E "c-decks \.c-(select|field)|min-height: ?40px|pointer: ?coarse|touch.floor|grows to at least 40|Selects get the same height" -- spec docs app .claude CLAUDE.md README.md ':!docs/specs' ':!docs/lessons' ':!.kamal/secrets'`. Hits, each with its disposition:

| Hit | Disposition |
|---|---|
| `spec/system/deck_proxies_spec.rb:58-72` (reads the `.c-decks` rule) | rewritten to read the app-wide rule (Phase 1, Task 1 Step 2; AC-3.2) |
| `additions.css:123` (`.c-select select` coarse 40px) | deleted (Task 2) |
| `additions.css:559-563` (the "Deck pages' selects" block) | deleted (Task 2) |
| `docs/design-system/README.md:73` (Touch rule, `bundle.css`) and `:103` (`components/bundle.css`) | rewritten (Task 3) |
| `docs/design-system/components/FilterSelect.md:16` ("grows to at least 40px") | rewritten (Task 3) |
| `docs/design-system/components/DecksIndex.md:144` (the scoped-rule bullet) | rewritten (Task 3) |
| `docs/design-system/components/Form.md:38` ("Selects get the same height…") | kept; a bullet follows it (Task 3) |
| `spec/system/deck_page_spec.rb:156-185`, `components.css:170-173`, `additions.css:367-551` (other touch rules; buttons, links, the `--touch-floor` token) | kept: they don't touch a select |
| `docs/design-system/components/AddProxy.md:5,9`, `DeckPage.md:63`, `DecksIndex.md:141`, `Locations.md:32` | kept: they speak of buttons and links, not selects |
| `docs/specs/**` (including 068's `verification.md`) | history, not edited |

## File structure

| File | Responsibility |
|---|---|
| `spec/system/select_touch_floor_spec.rb` (new) | AC-1.1 to AC-1.7 on the real pages |
| `spec/system/deck_proxies_spec.rb` | the AC-9.1 select example reads the new rule (AC-3.2) |
| `app/assets/stylesheets/collector/additions.css` | the new block; two rules deleted |
| `docs/design-system/README.md` and `components/{Form,FilterSelect,DecksIndex,AddProxy,AddToDeck,NumberEntry,Scanner}.md` | the rule, where the next select is built |
| `docs/specs/072-select-touch-floor/{screenshots/,verification.md}` | evidence and the review record |

---

## Phase 1: The examples, red first

**Implements:** FR-3 | **Satisfies:** AC-1.1 to AC-1.7, AC-3.2 | **Files:** `spec/system/select_touch_floor_spec.rb`, `spec/system/deck_proxies_spec.rb` | **Interfaces:** reads the `(pointer: coarse)` rules of the loaded stylesheets; the rule it expects is `.c-field select, .c-select select { min-height: var(--touch-floor) }` and `.c-filterbar__filters { align-items: center }`

### Task 1: write the examples and watch them fail

**Step 1: write `spec/system/select_touch_floor_spec.rb`.**

```ruby
require "rails_helper"

# Spec 072: every select meets the touch floor on a coarse pointer, on every page that draws one. Headless Firefox has a
# fine pointer and can't emulate a coarse one, so the examples read the `(pointer: coarse)` rules from the loaded
# stylesheets and apply them to the page as an adopted stylesheet (decision 3): the select rule alone to prove it reaches
# every select (AC-1.2), and every coarse rule to show the layout a touch screen draws (AC-1.4, AC-1.5, AC-1.7). A fine
# pointer's heights are measured with nothing applied (AC-1.3). The pages are the spec's audit table; phone widths use
# the narrow frame, since a window can't go below 500px. The coarse rules are applied in source order as one sheet.
RSpec.describe "Selects meet the touch floor on a coarse pointer", type: :system do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:blue) { create(:location, account:, name: "Blue binder") }
  let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let!(:lot) { owned_printing("Lightning Bolt", account:, location: blue, number: "138", quantity: 2) }
  let(:entry) { lot.entry }
  let(:corpus) { Pathname(Dir.mktmpdir("corpus")) }

  # Measurement mode (development only) draws its select only with a manifest and a run directory.
  around do |example|
    corpus.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,#{lot.entry.set.code},138,no\n")
    Rails.configuration.x.scanner_measurement = { manifest: corpus.join("manifest.csv").to_s, dir: corpus.join("runs/live").to_s }
    example.run
  ensure
    Rails.configuration.x.scanner_measurement = nil
    FileUtils.remove_entry(corpus)
  end

  before do
    # A second language of the same printing, so number entry shows its Language select (spec 026 decision 2).
    create(:mtg_printing, finishes: %w[nonfoil foil],
      entry: create(:catalog_entry, identity: entry.identity, name: entry.name, set: entry.set, number: entry.number, language: "ja"))
    page.driver.browser.manage.window.resize_to(1280, 900)
    system_sign_in_as(user)
  end

  # The two rules of the spec's block, as the browser serialises their selectors.
  def select_rule = ".c-field select, .c-select select"
  def row_rule = ".c-filterbar__filters"

  # The audit table of spec 072: every page that draws a select, by name.
  def pages
    { "card search" => catalog_entries_path,
      "collection" => collection_path,
      "collection in bulk mode" => collection_path(bulk: 1),
      "number entry" => collection_number_entry_path(type: "mtg", set: entry.set.code, language: "en"),
      "add a copy" => new_catalog_entry_lot_path(entry),
      "edit copy" => edit_lot_path(lot),
      "move copies" => new_lot_move_path(lot),
      "bulk move to" => new_collection_move_path,
      "scanner" => scanner_path,
      "new deck" => new_deck_path,
      "change format" => edit_deck_format_path(deck),
      "proxy chooser" => new_deck_zone_proxy_path(deck, "main", q: "Lightning"),
      "proxy form" => new_deck_zone_proxy_path(deck, "main", entry: entry.external_key),
      "currency" => edit_currency_path,
      "measurement mode" => scanner_measurement_path }
  end

  # Bulk Move to… needs a selection, which lives in the session: tick everything in bulk mode and press Move to… once.
  def select_everything
    return if @selected

    visit collection_path
    click_on "Edit many"
    check "Select all"
    within(".c-bulkbar__extra") { click_on "Move to…" }
    expect(page).to have_css("h1", text: /\AMove \d+ items?\z/)
    @selected = true
  end

  # Runs the block on the page: in the window at 1280px, or in a frame `width` px wide (the frame is the document the
  # block measures and injects into, so `document` and `window` in its scripts are the frame's).
  def in_page(name, width: 1280, &block)
    path = pages.fetch(name)
    select_everything if name == "bulk move to"
    if width < 500
      visit collection_path
      open_in_narrow_frame(path, width:, ready: "main")
      within_narrow_frame(&block)
    else
      visit path
      expect(page).to have_css("main")
      yield
    end
  end

  # Applies the coarse-pointer rules of the loaded stylesheets, media wrapper removed, to the current document as one
  # adopted sheet (after every stylesheet, in source order). `only` keeps the rules with those selectors; `except` drops
  # them; `extra` is more CSS appended. Raises when a rule named in `only` or `needs` is not in the stylesheets, so a missing
  # rule is reported as that and not as a layout symptom, and an example about the new rules can't pass without them.
  def inject_coarse(only: nil, except: [], extra: "", needs: [])
    found = page.evaluate_script(<<~JS, only, except, extra)
      (() => {
        const [only, except, extra] = arguments
        const css = [], selectors = []
        for (const sheet of document.styleSheets)
          for (const media of sheet.cssRules)
            if (media instanceof CSSMediaRule && media.conditionText.includes("pointer: coarse"))
              for (const rule of media.cssRules) {
                selectors.push(rule.selectorText)
                if ((!only || only.includes(rule.selectorText)) && !except.includes(rule.selectorText)) css.push(rule.cssText)
              }
        const sheet = new CSSStyleSheet()
        sheet.replaceSync(css.join(" ") + " " + extra)
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet]
        return selectors
      })()
    JS
    missing = (Array(only) + Array(needs)) - found
    raise "the coarse-pointer rule #{missing.inspect} is not in the loaded stylesheets (found #{found.inspect})" if missing.any?
  end

  # Every drawn select of the current document: its name, its height and which of the two shapes holds it.
  def selects
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("select")].map((el) => ({
        name: el.name || el.id, height: el.getBoundingClientRect().height,
        shape: el.closest(".c-field") ? "field" : (el.closest(".c-select") ? "select" : "none")
      })).filter((el) => el.height > 0)
    JS
  end

  # Page overflow, wide selects and overlapping controls of the current document (AC-1.4). A control counts when it is not
  # visually hidden (`.c-sr`), has a box, and is not clipped away by the nearest ancestor that clips its overflow (the
  # document itself never clips: the whole page counts, not the viewport); a control of the filter row always counts, as
  # the row scrolls sideways inside itself on a phone (spec 057 decision 4).
  def layout_report
    page.evaluate_script(<<~JS)
      (() => {
        const clipper = (el) => {
          for (let p = el.parentElement; p && p !== document.body && p !== document.documentElement; p = p.parentElement) {
            const style = getComputedStyle(p)
            if ([style.overflowX, style.overflowY].some((value) => value !== "visible")) return p
          }
          return null
        }
        const meets = (a, b) => !(a.right <= b.left || b.right <= a.left || a.bottom <= b.top || b.bottom <= a.top)
        const label = (el) => el.tagName.toLowerCase() + (el.id ? "#" + el.id : "") + (el.className ? "." + String(el.className).split(" ").join(".") : "")
        const controls = [...document.querySelectorAll("main select, main input:not([type=hidden]), main button, main a.c-btn, main summary")]
          .filter((el) => !el.closest(".c-sr"))
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
        return { overflow: document.documentElement.scrollWidth - window.innerWidth, overlaps, wide }
      })()
    JS
  end

  # The filter row's select height and how far its centre is from its button's centre (AC-1.5).
  def row_alignment
    page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector(".c-filterbar__filters")
        const select = row.querySelector("select"), button = row.querySelector(".c-btn")
        const centre = (el) => { const rect = el.getBoundingClientRect(); return rect.top + rect.height / 2 }
        return { select: select.getBoundingClientRect().height, offset: Math.abs(centre(select) - centre(button)) }
      })()
    JS
  end

  # Name, label, width and height of every control that is not a select (AC-1.7), in document order.
  def other_controls
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("main :is(button, input, textarea, summary, .c-btn, .c-filter)")]
        .filter((el) => !el.closest(".c-sr") && el.type !== "hidden")
        .map((el) => {
          const rect = el.getBoundingClientRect()
          return [el.tagName, el.name || el.id || el.textContent.trim().slice(0, 24), Math.round(rect.width * 100) / 100, Math.round(rect.height * 100) / 100]
        })
    JS
  end

  it "has one coarse-pointer rule for selects, covering both shapes at the touch floor (AC-1.1)", :aggregate_failures do
    visit new_deck_path
    read = page.evaluate_script(<<~JS)
      (() => {
        const found = []
        for (const sheet of document.styleSheets)
          for (const media of sheet.cssRules)
            if (media instanceof CSSMediaRule && media.conditionText.includes("pointer: coarse"))
              for (const rule of media.cssRules)
                if (rule.style?.minHeight) found.push({ selector: rule.selectorText, minHeight: rule.style.minHeight })
        return { found, floor: parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--touch-floor")) || 0 }
      })()
    JS
    select_rules = read["found"].select { it["selector"].include?("select") }
    expect(select_rules).to eq([ { "selector" => select_rule, "minHeight" => "var(--touch-floor)" } ])
    expect(read["floor"]).to be >= 44
  end

  it "reaches every select of every page with the select rule alone: at least 44px (AC-1.2)", :aggregate_failures do
    pages.each_key do |name|
      in_page(name) do
        inject_coarse(only: [ select_rule ])
        found = selects
        expect(found).not_to be_empty, "#{name}: no select is drawn"
        expect(found.map { it["shape"] }).not_to include("none"), "#{name}: a select outside c-field and c-select: #{found}"
        expect(found.map { it["height"] }).to all(be >= 44), "#{name}: #{found}"
      end
    end
  end

  it "leaves a fine pointer's heights alone: 36px in a form, 28px in the filter bar (AC-1.3)", :aggregate_failures do
    pages.each_key do |name|
      in_page(name) do
        found = selects
        expect(found).not_to be_empty, "#{name}: no select is drawn"
        found.each { |one| expect(one["height"]).to be_within(0.5).of(one["shape"] == "field" ? 36 : 28), "#{name}: #{one}" }
      end
    end
  end

  it "keeps every page whole at 360px with all the coarse rules: no overflow, no wide select, no overlap (AC-1.4)", :aggregate_failures do
    pages.each_key do |name|
      in_page(name, width: 360) do
        inject_coarse(needs: [ select_rule, row_rule ])
        report = layout_report
        expect(report["overflow"]).to be <= 0, "#{name}: scrolls sideways by #{report['overflow']}px"
        expect(report["wide"]).to be_empty, "#{name}: wider than its container: #{report['wide']}"
        expect(report["overlaps"]).to be_empty, "#{name}: overlapping controls: #{report['overlaps']}"
      end
    end
  end

  # The filter bars: the collection (a list and bulk mode), the card search and the add-a-proxy chooser.
  filter_pages = [ "collection", "collection in bulk mode", "card search", "proxy chooser" ]

  [ 1280, 360 ].each do |width|
    it "centres the filter row's button on its select at #{width}px (AC-1.5)", :aggregate_failures do
      filter_pages.each do |name|
        in_page(name, width:) do
          inject_coarse(needs: [ select_rule, row_rule ])
          row = row_alignment
          expect(row["select"]).to be >= 44, "#{name}: #{row}"
          expect(row["offset"]).to be <= 1, "#{name}: the button's centre is #{row['offset']}px off the select's"
          expect(layout_report["overlaps"]).to be_empty, "#{name}: overlapping controls"
        end
      end
    end
  end

  it "needs the alignment rule: without it the small button sits off the select's centre (AC-1.5 can fail)" do
    in_page("card search") do
      inject_coarse(except: [ row_rule ], needs: [ select_rule ]) # the select rule must exist, or there is nothing to compare
      expect(row_alignment["offset"]).to be > 1
    end
  end

  it "changes no other control's size: all coarse rules with and without the block's two (AC-1.7)", :aggregate_failures do
    pages.each_key do |name|
      without = nil
      with = nil
      in_page(name, width: 360) do
        inject_coarse(except: [ select_rule, row_rule ], needs: [ select_rule, row_rule ])
        without = other_controls
      end
      in_page(name, width: 360) do
        inject_coarse(needs: [ select_rule, row_rule ])
        with = other_controls
      end
      expect(without).not_to be_empty, "#{name}: no control found"
      changed = without.zip(with).reject { |before, after| before == after }
      expect(changed).to be_empty, "#{name}: controls whose size changed: #{changed}"
    end
  end

  it "notices a rule that grows another control (AC-1.7 can fail)" do
    without = nil
    with = nil
    in_page("card search", width: 360) do
      inject_coarse(except: [ select_rule, row_rule ])
      without = other_controls
    end
    in_page("card search", width: 360) do
      inject_coarse(extra: ".c-btn--sm { min-height: 90px; }")
      with = other_controls
    end
    expect(with).not_to eq(without)
  end

  it "has no select rule scoped to the deck pages and none in the filter bar's own block (AC-1.6)", :aggregate_failures do
    visit new_deck_path
    rules = page.evaluate_script(<<~JS)
      (() => {
        const all = []
        const walk = (list, coarse) => {
          for (const rule of list) {
            if (rule.cssRules && rule.conditionText !== undefined) walk(rule.cssRules, coarse || rule.conditionText.includes("pointer: coarse"))
            else if (rule.selectorText) all.push({ selector: rule.selectorText, coarse })
          }
        }
        for (const sheet of document.styleSheets) walk(sheet.cssRules, false)
        return all
      })()
    JS
    expect(rules.map { it["selector"] }.grep(/\.c-decks .*select/)).to be_empty
    expect(rules.select { it["coarse"] }.map { it["selector"] }).not_to include(".c-select select")
  end
end
```

**Step 2: rewrite spec 068's AC-9.1 select example (AC-3.2)** in `spec/system/deck_proxies_spec.rb` (lines 56-72): replace the comment and the example with

```ruby
    # The selects' floor applies on a coarse pointer only, and headless Firefox can't emulate one, so the example reads the rule.
    # Since spec 072 the rule is the app-wide one (`.c-field select, .c-select select`), not one scoped to the deck pages.
    it "lifts the chooser's Set select and the form's Finish select to the touch floor on a coarse pointer (AC-9.1)", :aggregate_failures do
      visit new_deck_zone_proxy_path(deck, "main", q: "WWWW")
      rule = page.evaluate_script(<<~JS)
        (() => { for (const sheet of document.styleSheets) for (const media of sheet.cssRules)
          if (media instanceof CSSMediaRule && media.conditionText.includes("pointer: coarse"))
            for (const rule of media.cssRules)
              if (rule.selectorText === ".c-field select, .c-select select")
                return { minHeight: rule.style.minHeight,
                         floor: parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--touch-floor")) || 0 }
          return null })()
      JS
      expect(rule).not_to be_nil
      expect(rule["minHeight"]).to eq("var(--touch-floor)")
      expect(rule["floor"]).to be >= 44
    end
```

**Step 3: run both files and confirm the expected red.** Command: `bin/rspec spec/system/select_touch_floor_spec.rb spec/system/deck_proxies_spec.rb`.

Expected:
- **Fail** (the rule is missing): AC-1.1 (the select rules are the `.c-decks` and 40px ones), AC-1.2, AC-1.4, both AC-1.5 widths, "needs the alignment rule" and AC-1.7 (each with "the coarse-pointer rule … is not in the loaded stylesheets"; AC-1.7 names its rules in `needs` so it can't pass with nothing to compare), AC-1.6 (finds the `.c-decks` selector and the `.c-select select` coarse rule), spec 068's rewritten example.
- **Pass** (they guard what exists today or test the check itself): AC-1.3 (36px and 28px) and "notices a rule that grows another control".

If an example fails for a reason other than the rule it reads (a factory that doesn't build, a route helper that doesn't exist, a page whose select needs other setup, a page whose frame doesn't load), fix the example's setup, not the assertion, and say what was needed in the commit message. If a page has overlapping controls by design that the CSS can't be blamed for (the scanner's camera stage drawing buttons over the video), exclude only that stage's descendants in `layout_report` (`.closest(".c-scanner__stage")`; read `app/views/scanner/` for the class), with a comment saying why, and record it in `verification.md`; never weaken the check for the other pages.

**Step 4: lint and commit.** `bin/rubocop -a spec/system/select_touch_floor_spec.rb spec/system/deck_proxies_spec.rb`, then `git add spec/system/select_touch_floor_spec.rb spec/system/deck_proxies_spec.rb`, then `git commit -m "test(design-system): selects meet the touch floor on a coarse pointer, red (#315)"` with the trailer.

---

## Phase 2: The CSS

**Implements:** FR-1 | **Satisfies:** AC-1.1 to AC-1.7, AC-3.1, AC-3.2 | **Files:** `app/assets/stylesheets/collector/additions.css` | **Interfaces:** the rule of Phase 1's `select_rule` and `row_rule`

### Task 2: the block and the two deletions

**Step 1: delete the 40px coarse rule.** In `additions.css`, the filter bar's select block (line 123) loses exactly this line:

```css
@media (pointer: coarse) { .c-select select { min-height:40px; } }
```

**Step 2: delete the deck pages' select block** (lines 559-563, the heading comment, the three comment lines and the rule):

```css
/* ---------- Deck pages' selects (spec 068 AC-9.1): the touch floor on a coarse pointer ---------- */
/* The add-a-proxy chooser's Set select (`.c-select`, 40px on a touch screen) and the form's Finish select (`.c-field`, 36px) sit
   under the 44px floor every other control of the deck pages meets. The rule is scoped to `.c-decks`, so it also lifts the Change
   format page's Format select (spec 064), which shares that class; raising the select floor app-wide is out of scope. */
@media (pointer: coarse) { .c-decks .c-select select, .c-decks .c-field select { min-height:var(--touch-floor); } }
```

Leave one blank line between the blocks around it, as the file keeps.

**Step 3: add the new block** after the "Location filter cap" block (after its closing `}` of the `@container collection` rule) and before `/* ---------- Pagination ---------- */`:

```css
/* ---------- Selects meet the touch floor on a coarse pointer (spec 072) ---------- */
/* A select is 36px in a form (`.c-field select`) and 28px in the filter bar (`.c-select select`), so a desktop keeps compact rows.
   Every other control reaches 44px on a touch screen and so does a select, by `min-height`, which only raises. `.c-field` and
   `.c-select` are the design system's two select shapes (`Form`, `FilterSelect`); spec 068 had lifted the deck pages' selects alone.
   The filter row's children use the default `stretch` and a `c-btn--sm` (40px there, an explicit height) does not stretch, so beside
   a 44px select it would sit at the top of the row, 4px short: the row centres its controls on a coarse pointer. Headless Firefox has
   a fine pointer, so `spec/system/select_touch_floor_spec.rb` reads these rules and applies them. */
@media (pointer: coarse) {
  .c-field select, .c-select select { min-height:var(--touch-floor); }
  .c-filterbar__filters { align-items:center; }
}
```

**Step 4: run the targeted examples.** `bin/rspec spec/system/select_touch_floor_spec.rb spec/system/deck_proxies_spec.rb spec/design_system_files_spec.rb spec/system/design_system_deck_rules_spec.rb spec/system/deck_page_spec.rb spec/system/decks_spec.rb spec/system/catalog_search_spec.rb spec/system/collection_location_filter_spec.rb spec/system/number_entry_spec.rb`. Expected: all pass.

**Step 5: if AC-1.5 fails at one width with an offset near half the difference between the `c-select` label's height and its select's** (the label is a plain `label` with no rule of its own and `align-items: center` centres the label, not the select inside it), add this one line inside the new block's `@media`, rerun Step 4 and record it in `verification.md`; do nothing if AC-1.5 passes:

```css
  .c-filterbar__filters .c-select { display:flex; }
```

If a different example fails, read the report's message and fix the cause in the CSS only when it is a real layout defect of a coarse pointer (an overflow, an overlap, a grown control); do not loosen an example. Report any such finding to the supervisor before changing the block beyond Step 5's line.

**Step 6: lint and commit.** `bin/rubocop -a` has nothing to say about CSS; run `git add app/assets/stylesheets/collector/additions.css`, then `git commit -m "feat(design-system): selects meet the 44px touch floor on a coarse pointer (#315)"` with the trailer and a body that names the deleted rules.

---

## Phase 3: Design-system documents

**Implements:** FR-2 | **Satisfies:** AC-2.1, AC-2.2 | **Files:** `docs/design-system/README.md`, `docs/design-system/components/{Form,FilterSelect,DecksIndex,AddProxy,AddToDeck,NumberEntry,Scanner}.md` | **Interfaces:** none (prose; verified by reading, not by RSpec, per `.claude/rules/testing.md`)

### Task 3: write the rule where the next select is built

**Step 1: README.** Replace line 73 with:

```markdown
- On touch devices every target is at least 44px (40px for small buttons, chips and the view switch); `collector/components.css` and `collector/additions.css` handle this with `pointer: coarse`. A select is 44px high there too (spec 072, [#315](https://github.com/plainprogrammer/Collector/issues/315)): `min-height: var(--touch-floor)` on `.c-field select` and `.c-select select`, one rule in `additions.css`; the compact heights, 36px in a form and 28px in the filter bar, are the fine pointer's. On a coarse pointer the filter row (`c-filterbar__filters`) centres its controls, so a 40px small button sits level with the 44px select. A new select is a `c-field` or `c-select` select and meets the floor with no rule of its own; a select outside both shapes is a design-system violation, not something the rule hides.
```

and in line 103 replace "in `components/bundle.css`" with "in `collector/components.css`, with the app's additions in `collector/additions.css`".

**Step 2: `Form.md`.** After the bullet that begins "- Selects get the same height, border and focus ring as `c-input`;" insert:

```markdown
- On a coarse pointer a select is at least the touch floor, 44px, high (`min-height: var(--touch-floor)` on `.c-field select`, spec 072), as `c-input` is; the 36px above is the fine pointer's. The rule covers every form's selects: the lot form's, Move copies' and bulk Move to…'s, the location picker, the scanner's sitting, the deck pages' and the currency page's.
```

**Step 3: `FilterSelect.md`.** Replace "on touch screens it grows to at least 40px." with "on a coarse pointer (a touch screen) it is at least the touch floor, 44px, high (`min-height: var(--touch-floor)` on `.c-select select`, spec 072), and the filter row centres its controls there, so the 40px small button beside it sits level with it." and append at the end of the file:

```markdown
- Also used by the add-a-proxy chooser (the set, button "Search", spec 068) and number entry's language row (the language, button "Change language", spec 026).
```

**Step 4: `DecksIndex.md`.** Replace the whole bullet on line 144 (it starts "- **Selects take the touch floor on a coarse pointer**") with:

```markdown
- **Selects take the touch floor on a coarse pointer** (spec 068 AC-9.1; since spec 072 the design system's own rule for every select, in `Form` and `FilterSelect`): the add-a-proxy chooser's Set, the form's Finish and the Change format page's Format are at least the touch floor (44px) high there, by `@media (pointer: coarse) { .c-field select, .c-select select { min-height: var(--touch-floor) } }` in `additions.css`. The deck pages carry no select rule of their own.
```

**Step 5: the four documents that draw a select.** `AddProxy.md`: append to the final "Sources:" line the sentence " The selects' touch floor is the app-wide rule of spec 072 (`Form`, `FilterSelect`)." `AddToDeck.md`: after the bullet that begins "- **Deck and zone.**" insert

```markdown
- On a coarse pointer the select is at least the touch floor (44px) high, as every select is (`Form`, spec 072).
```

`NumberEntry.md`: append to the end of the file

```markdown
- On a coarse pointer the Language select (`c-select`) and the line form's Finish and Location selects (`c-field`) are at least the touch floor (44px) high (`FilterSelect`, `Form`, spec 072); the language row centres its select and its 40px "Change language" button.
```

`Scanner.md`: append to the end of the file

```markdown
- On a coarse pointer the sitting's Condition and Location selects (`c-field`) and the measurement panel's "Card to capture" select are at least the touch floor (44px) high (`Form`, spec 072).
```

**Step 6: check by reading and commit.** `git grep -n -E "grows to at least 40|bundle\.css" -- docs/design-system ':!.kamal/secrets'` must print nothing from the files above (a `bundle.css` in a preview or a historical note elsewhere is left). `git diff` shows only these eight files. Then `git add docs/design-system`, then `git commit -m "docs(design-system): the touch floor of a select (#315)"` with the trailer.

---

## Phase 4: Visual evidence

**Implements:** the maintainer's evidence rule (coordinator message, 2026-11-11) | **Satisfies:** spec NFR "Visual change" | **Files:** `docs/specs/072-select-touch-floor/screenshots/*.jpg` (committed); `spec/system/zz_072_screenshots_spec.rb` (uncommitted, deleted before the commit) | **Interfaces:** the examples' own `inject_coarse` technique; `SHOTS_DIR`

### Task 4: before and after shots of the selects on a coarse pointer

Headless Firefox draws a fine pointer, so "after" injects every coarse rule of the shipped CSS and "before" injects every coarse rule except the block's two plus the two rules the change deleted (the `.c-select` 40px and the `.c-decks` select rule), which is what a phone drew before. Say so in `verification.md` and in the PR body.

**Step 1: write the throwaway spec** `spec/system/zz_072_screenshots_spec.rb` (never committed). It copies the `let`s, `around`, `before`, `select_rule`, `row_rule`, `pages` and `inject_coarse` of `select_touch_floor_spec.rb` (those helpers are private to that file) and adds:

```ruby
  def set_theme(name)
    page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
    sleep 0.6 # c-btn transitions its background over 0.12s; a shot taken at once shows pale buttons
  end

  # What a phone drew before spec 072: every coarse rule but the block's two, the filter bar's old 40px and the deck pages' rule.
  def before_css = ".c-select select { min-height:40px; } .c-decks .c-select select, .c-decks .c-field select { min-height:var(--touch-floor); }"

  def apply(state)
    if state == "before"
      inject_coarse(except: [ select_rule, row_rule ], extra: before_css)
    else
      inject_coarse(needs: [ select_rule, row_rule ])
    end
  end

  # A wide shot of the window, or a 360px shot of the frame element; the theme is set in the document that is drawn.
  def shoot(name, kind:, theme:, state:, path:)
    if kind == "phone"
      visit collection_path
      open_in_narrow_frame(pages.fetch(name), width: 360, ready: "main", height: 700)
      within_narrow_frame do
        apply(state)
        set_theme(theme)
      end
      find("#narrow").native.save_screenshot(path)
    else
      visit pages.fetch(name)
      expect(page).to have_css("main")
      apply(state)
      set_theme(theme)
      page.save_screenshot(path)
    end
  end

  # Six pages: the card search's Set (a filter bar select), the collection's Location, the lot form's selects, number
  # entry, the proxy chooser (a deck page) and the New deck form.
  it "saves the shots" do
    dir = ENV.fetch("SHOTS_DIR")
    { "card-search" => "card search", "collection" => "collection", "add-a-copy" => "add a copy",
      "number-entry" => "number entry", "proxy-chooser" => "proxy chooser", "new-deck" => "new deck" }.each do |slug, name|
      %w[light dark].each do |theme|
        %w[wide phone].each do |kind|
          %w[before after].each do |state|
            shoot(name, kind:, theme:, state:, path: File.join(dir, "#{slug}-#{kind}-#{theme}-#{state}.png"))
          end
        end
      end
    end
  end
```

Create the directory in the session scratchpad first (`mkdir -p /private/tmp/claude-501/-Users-james-orca-workspaces-Collector-072-select-touch-floor/d9cd9c69-0567-4a95-bf3c-532bdcc6cbf2/scratchpad/shots`), then run `SHOTS_DIR=/private/tmp/claude-501/-Users-james-orca-workspaces-Collector-072-select-touch-floor/d9cd9c69-0567-4a95-bf3c-532bdcc6cbf2/scratchpad/shots bin/rspec spec/system/zz_072_screenshots_spec.rb`. Expected: one example passes and 48 png files exist (6 pages x 2 themes x 2 widths x before and after).

**Step 2: look at every shot yourself** (the Read tool shows images): first one of each theme and width, then all. Check: the light shots are light (headless Firefox prefers dark: `data-theme` is set from the name before each save), the before/after pairs differ only in the selects' height (and the filter row's alignment), nothing overflows at 360px, no control overlaps another. Report anything that looks wrong to the supervisor; do not fix CSS here.

**Step 3: compress and store.** For each png: `magick in.png -resize 1000x -quality 70 out.jpg` into `docs/specs/072-select-touch-floor/screenshots/` (about 48 files; keep their names). Delete `spec/system/zz_072_screenshots_spec.rb`. `git status` must show only the screenshots as new. Then `git add docs/specs/072-select-touch-floor/screenshots`, then `git commit -m "docs(specs): before and after shots of spec 072's selects (#315)"` with the trailer.

---

## Spec coverage

| Criterion | Phase and example |
|---|---|
| AC-1.1 | Phase 1 "has one coarse-pointer rule…"; green by Phase 2 Step 3 |
| AC-1.2 | "reaches every select of every page…" (select rule alone, `only:`) |
| AC-1.3 | "leaves a fine pointer's heights alone…" (characterisation; green throughout) |
| AC-1.4 | "keeps every page whole at 360px…" |
| AC-1.5 | "centres the filter row's button…" at 1280 and 360, with "needs the alignment rule" as its can-fail example |
| AC-1.6 | "has no select rule scoped to the deck pages…" |
| AC-1.7 | "changes no other control's size…", with "notices a rule that grows another control" as its can-fail example |
| AC-2.1, AC-2.2 | Phase 3, read (verification.md records the reading) |
| AC-2.3 | the specs index row, written with the spec; the distillation step changes its status |
| AC-3.1 | the branch's diff (verification.md records `git diff --stat origin/main...`) |
| AC-3.2 | Phase 1 Step 2, green by Phase 2; the width examples of specs 064 and 068 run in Phase 2 Step 4 |
| FR-1 | Phase 2; FR-2 Phase 3; FR-3 Phase 1; FR-4 AC-3.1 |

Interpretations the plan makes of the spec, for the reviewers: AC-1.4's "nearest scrolling ancestor" is the nearest ancestor that clips its overflow, and the document itself never clips (the whole page counts); AC-1.7 runs at 360px only (the width where wrapping can grow a control; AC-1.5 covers the filter row at 1280px too).

## Integration verification

- `bin/rspec spec/system/select_touch_floor_spec.rb spec/system/deck_proxies_spec.rb spec/design_system_files_spec.rb` green after Phase 2, and the Phase 2 Step 4 list green.
- `bin/rubocop` clean, `bin/yard doc` has no new warning (no Ruby API changed), `ruby script/upgrade/guard.rb` unaffected.
- Full `bin/ci` once, with a slot from the coordinator, before the push.
- The implementation review (sdd-review Mode B, Opus, read-only) after Phase 4, recorded in `verification.md` under `## Implementation review`, verdict first.

## Quickstart validation

`bin/rspec spec/system/select_touch_floor_spec.rb` prints the examples above, all passing; opening any page with a select on a phone (or Firefox's responsive mode with touch simulation) shows a 44px select; a desktop shows the compact 28px and 36px.
