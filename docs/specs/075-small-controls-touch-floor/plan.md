# Plan: Small Controls Meet the Touch Floor (spec 075, #316)

**Plan version:** 0.2.0 (plan review round 1 taken). **Spec:** [spec.md](spec.md) 0.3.2 (approved at Gate A, decision 1 ruled A by the maintainer). **Branch:** `075-small-controls-touch-floor`.

**Goal:** on a coarse pointer every small control (`.c-btn--sm`, `.c-filter`, `.c-seg button`) is at least 44px high and the icon-only ones 44px wide, by one block in `additions.css`, proved by examples that apply every coarse rule and measure the real pages; the design system's documents say it.

**Implements:** FR-1 to FR-4. **Satisfies:** AC-1.1 to AC-1.8, AC-2.1 to AC-2.3, AC-3.1, AC-3.2.

**No application code changes** (FR-4): the files are one stylesheet, spec files, support, documents. No data model, no contracts, no ADR. The gates: Simplicity (one block, two rules, one new spec file, one helper extended), Anti-Abstraction (the helper is hoisted from spec 072's file, not wrapped), Integration-First (examples first, red, then the CSS).

## Notes on a moved `main`

Spec 076 (#317, merged as 1910bf10, merged into this branch as 7f54c5dc) made `.c-select` `display:inline-flex` with a gap and edited `FilterSelect.md` and `NumberEntry.md`: the line numbers quoted in Tasks 5 and 6 may have moved, so the implementer reads each file and matches the sentence, not the number; the row-alignment examples (spec 072's and AC-1.6) run on that CSS.

## Files

| File | Change | Task |
|---|---|---|
| `spec/support/coarse_pointer.rb` | gains `inject_coarse` (hoisted from spec 072's file, with `except:` taking a selector text or `{ sheet:, selector: }`, and `needs:` the same) and `layout_report(roots:)` (hoisted); `apply_coarse_rules` delegates | 1 |
| `spec/system/select_touch_floor_spec.rb` | its local `inject_coarse` and `layout_report` removed; two examples re-premised | 1, 2 |
| `spec/system/deck_page_spec.rb` | AC-2.11 example reads the `additions.css` rule; two comments say 44px | 2 |
| `spec/system/small_controls_touch_floor_spec.rb` | new; AC-1.1 to AC-1.8 | 3, 4 |
| `app/assets/stylesheets/collector/additions.css` | one new block; two comments corrected | 5 |
| `docs/design-system/README.md`, `Button.md`, `Chip.md`, `ViewSwitch.md`, `TableActions.md`, `BulkForm.md`, `Pager.md`, `AdminJobs.md`, `FilterSelect.md`, `NumberEntry.md` | the Touch rule and one sentence each | 6 |
| `docs/specs/075-small-controls-touch-floor/verification.md` | evidence, the audit and supersession greps, screenshots | 7 |

## Existing examples that change (the supersession grep)

Run `git grep -n -E "40px|c-btn--sm|c-filter|c-seg|touch floor|pointer: ?coarse|apply_coarse_rules|inject_coarse|\[ 40, 90 \]" -- spec docs/design-system app/assets ':!docs/specs' ':!docs/lessons' ':!.kamal/secrets'` in Task 7 and record the dispositions in `verification.md`; the dispositions the plan already knows (from the spec's own grep, round 1 and 2 reviews):

| Where | Disposition |
|---|---|
| `select_touch_floor_spec.rb` "notices a rule that grows another control" (`[ 40, 90 ]`) | Task 2: `[ 44, 90 ]` |
| `select_touch_floor_spec.rb` "needs the alignment rule" | Task 2: re-premised with a 30px button, both halves asserted |
| `deck_page_spec.rb` AC-2.11 and the comment of the Add a proxy example | Task 2 |
| `card_page_spec.rb:89` and `deck_additions_spec.rb:106` (`apply_coarse_rules`) | unchanged in meaning; run in Task 7 |
| `deck_proxies_spec.rb`, `deck_proxy_replacements_spec.rb:147-151` (read `.c-btn`, `.c-field select` rules by selector) | unchanged; they read other rules |
| `additions.css` comments (lines ~143-145, ~525-527) | Task 5 |

---

## Task 1: hoist `inject_coarse` and `layout_report` into `CoarsePointer`

**Files:** `spec/support/coarse_pointer.rb`, `spec/system/select_touch_floor_spec.rb`. Refactor under green: spec 072's examples are the safety net (no new behaviour yet but the `{ sheet:, selector: }` form, which Task 3's examples are the first user of; Task 1's own check is the red-then-green of Step 2).

- [ ] **Step 1: run the safety net.** `bin/rspec spec/system/select_touch_floor_spec.rb spec/system/deck_additions_spec.rb spec/system/card_page_spec.rb` → all pass (record the count).
- [ ] **Step 2: extend the support module.** Replace `apply_coarse_rules` and add the two methods; keep the module's header comment. The whole module body becomes:

```ruby
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
```

(Keep the existing `RSpec.configure` block at the file's end.) The error message text of the old `apply_coarse_rules` is unchanged ("the coarse-pointer rule [...] is not in the loaded stylesheets (found [...])"), which `deck_additions_spec.rb:124` matches.

- [ ] **Step 3: spec 072's file uses the support methods.** In `spec/system/select_touch_floor_spec.rb` delete the local `inject_coarse` and `layout_report` method definitions and their preceding comment blocks (they are the two `def` blocks that begin `# Applies the coarse-pointer rules of the loaded stylesheets, media wrapper removed…` and `# Page overflow, wide selects and overlapping controls…`); every call (`inject_coarse(only: …)`, `layout_report`) stays as written.
- [ ] **Step 4: run the safety net again.** Same command as Step 1 → same count, all pass. Then `bin/rubocop -a spec/support/coarse_pointer.rb spec/system/select_touch_floor_spec.rb` clean.
- [ ] **Step 5: commit.** `refactor(spec): hoist inject_coarse and layout_report into CoarsePointer (spec 075)`.

---

## Task 2: re-premise the existing examples (red before the CSS)

**Files:** `spec/system/select_touch_floor_spec.rb`, `spec/system/deck_page_spec.rb`. **Updates the comments of** the two examples and the support header it touches (Task 1's).

- [ ] **Step 1: spec 072, "notices a rule that grows another control".** Change `expect([ search.(without), search.(with) ]).to eq([ 40, 90 ])` to `[ 44, 90 ]`. Red now (the Search button is 40px before the CSS).
- [ ] **Step 2: spec 072, "needs the alignment rule".** Replace the example (the one titled "needs the alignment rule: without it the small button sits off the select's centre (AC-1.5 can fail)") with two, using one injected shorter button (the premise "a 40px button beside a 44px select" is gone: with both at 44px the centres coincide with or without the row rule):

```ruby
  # A button shorter than the select (spec 075: small buttons are 44px too, so a 30px one stands in for "a control that is not 44px").
  def short_button = ".c-filterbar__filters .c-btn { min-height:30px; height:30px; }"

  it "keeps a shorter button level with the select by the alignment rule (AC-1.5)" do
    in_page("card search") do
      inject_coarse(needs: [ select_rule, row_rule ], extra: short_button)
      expect(row_alignment["offset"]).to be <= 1
    end
  end

  it "needs the alignment rule: without it a shorter button sits off the select's centre (AC-1.5 can fail)" do
    in_page("card search") do
      inject_coarse(except: [ row_rule ], needs: [ select_rule ], extra: short_button) # the select rule must exist, or there is nothing to compare
      expect(row_alignment["offset"]).to be > 1
    end
  end
```

Both pass before and after the CSS (they don't depend on the small-control floor); they are re-premised, not new red.
- [ ] **Step 3: `deck_page_spec.rb` AC-2.11.** Replace the example (from its comment through its `end`, the one titled "gives the row menu's trigger the touch floor of a small icon button (AC-2.11)") with:

```ruby
  # The trigger's floor on a touch screen is the design system's rule for a small icon button (44px since spec 075, in
  # `additions.css`; `components.css` still writes 40px and loses by source order). Headless Firefox has a fine pointer, so the
  # rule is read from the stylesheet and the trigger is measured as it is drawn.
  it "gives the row menu's trigger the touch floor of a small icon button (AC-2.11)", :aggregate_failures do
    visit deck_path(deck)
    floor = page.evaluate_script(<<~JS)
      (() => { let found = null
        for (const sheet of document.styleSheets) if ((sheet.href || "").includes("additions"))
          for (const rule of sheet.cssRules)
            if (rule.media && rule.conditionText.includes("pointer: coarse")) for (const inner of rule.cssRules)
              if (inner.selectorText === ".c-btn--sm.c-btn--icon, .c-seg button") found = inner.style.minWidth
        return found })()
    JS
    trigger = page.evaluate_script(<<~JS)
      (() => { const box = document.querySelector(".c-zone td.c-table__actions summary").getBoundingClientRect(); return [box.width, box.height] })()
    JS
    expect(floor).to eq("var(--touch-floor)")
    expect(trigger).to all(be >= 30) # a small button drawn for a fine pointer
  end
```

and change the comment above "gives each zone's Add a proxy link the 44px touch floor" from `"Add a proxy" is a small ghost button, 40px on a touch screen by the design system's rule.` to `"Add a proxy" is a small ghost button, 28px with a mouse and 44px on a touch screen by the design system's rule (spec 075).`
- [ ] **Step 4: run.** `bin/rspec spec/system/select_touch_floor_spec.rb spec/system/deck_page_spec.rb` → exactly two red: "notices a rule that grows another control" (`[40, 90]` against 44) and AC-2.11 (`nil` against the rule); the rest pass. Record the red output in the commit body.
- [ ] **Step 5:** `bin/rubocop -a` on both files; commit `test(spec): re-premise the 40px small-button examples for spec 075 (red)`. (A red commit is intended; the next tasks finish it. Task 5's commit makes the branch green; the pre-commit hook runs RuboCop and Brakeman only.)

---

## Task 3: the new system spec, part A: the rule, every page's small controls, the fine pointer (AC-1.1 to AC-1.3)

**File:** `spec/system/small_controls_touch_floor_spec.rb` (new). **Red run:** AC-1.1 and AC-1.2 fail (no block yet), AC-1.3 passes (nothing applied; it is the "before" fact).

- [ ] **Step 1: write the file's head, fixtures, page table and helpers.**

```ruby
require "rails_helper"

# Spec 075: every small control (a `.c-btn--sm`, a `.c-filter` chip, a `.c-seg` view-switch button) meets the touch floor on
# a coarse pointer, on every page that draws one. Headless Firefox has a fine pointer and can't emulate a coarse one, so the
# examples apply every `(pointer: coarse)` rule of the loaded stylesheets as one adopted sheet (`CoarsePointer`, decision 4),
# measure what is drawn, and compare states with and without the block's two rules. The pages are the spec's audit table;
# phone widths use the narrow frame, since a window can't go below 500px. Spec 072's spec is the model.
RSpec.describe "Small controls meet the touch floor on a coarse pointer", :solid_queue, type: :system do
  # Constants would leak onto Object (RSpec/LeakyConstantDeclaration), so these are one-line methods, as spec 072's are.
  # The block's two rules: the first has the selector text of `components.css`'s own 40px rule, so it is named by stylesheet too.
  def block_height = { sheet: "additions", selector: ".c-btn--sm, .c-filter, .c-seg button" }
  def block_width = ".c-btn--sm.c-btn--icon, .c-seg button" # exists only in the block
  def block_rules = [ block_height, block_width ]
  # The small controls of AC-1.2: in the page's `main`, its header and its status line.
  def small = "main .c-btn--sm, main .c-filter, main .c-seg button, .c-appbar .c-btn--sm, #status .c-btn--sm"
  # The five page rules (spec 075 decision 3) that give their buttons 44px at every pointer: the rows marked `page` in the audit.
  def page_rule_scopes
    ".c-locations, .c-decks, .c-deckpage .c-section__actions, .c-numentry__list, .c-scanner__add, .c-scanner__undo, .c-scanner__sitting"
  end

  # The rows whose line counts AC-1.5 compares.
  def rows = ".c-filterbar, .c-bulkbar, .c-pager, .c-section__head, .c-decks__actions, .c-numentry__language, .c-jobs__filters, .c-appbar"

  # The helpers below (`in_page`, `small_controls`, `drawn?`, `coarse_rules`, `row_lines`, `rows_of`, `other_controls`, ...) sit at
  # this level; the examples sit in two contexts, so there is one top-level describe (RSpec/MultipleDescribes):
  # "with an admin's account" (the `let`s, `before` and every example of Tasks 3 and 4 except rows 1 and 14b) and "as a visitor
  # and in the scanner's reading flow" (rows 1 and 14b, each with its own sign-in).

  context "with an admin's account" do
  let(:user) { create(:admin) } # an admin is a collector too, so one sign-in reaches the admin pages and the rest
  let!(:lot) { owned_printing("Lightning Bolt", account: user.account, location: create(:location, account: user.account, name: "Blue binder"), number: "138", quantity: 2) }

  before do
    # Two of everything that pages, so a second page and a "Show all" exist without 120 rows (the constants are read at call time).
    stub_const("Catalog::Search::PER_PAGE", 1)
    stub_const("Catalog::Search::ENTRIES_PER_GROUP", 1)
    stub_const("Catalog::IdentitiesController::PER_PAGE", 1)
    stub_const("CollectionGrid::PER_PAGE", 1)
    stub_const("CollectionTable::PER_PAGE", 1)
    stub_const("NumberEntry::SHOWN", 1)
    stub_const("Scanner::Sitting::SHOWN", 1)
    stub_const("BackgroundJobs::List::PER_PAGE", 1)
    make_fixtures
    page.driver.browser.manage.window.resize_to(1280, 900)
    system_sign_in_as(user)
  end

  # A second printing of the name in another set and a second owned lot (so the card search, the printings page, the
  # collection and bulk mode have a second page and a "Show all"), a deck with a proxy, a second language of the printing for
  # number entry, two number-entry lines and two scanner sitting entries (more than SHOWN = 1), a second user, a failed and a
  # scheduled job.
  def make_fixtures
    account = user.account
    create(:mtg_printing, finishes: %w[nonfoil foil],
      entry: create(:catalog_entry, identity: entry.identity, name: entry.name, set: create(:catalog_set), number: "139"))
    create(:mtg_printing, finishes: %w[nonfoil foil],
      entry: create(:catalog_entry, identity: entry.identity, name: entry.name, set: entry.set, number: entry.number, language: "ja"))
    owned_printing("Opt", account:, number: "1", quantity: 1)
    owned_printing("Lightning Helix", account:, number: "2", quantity: 1) # a second name that "Lightning" matches, so the card search has a second page
    create(:deck_proxy, zone: create(:deck, account:, name: "Izzet Tempo").zone("main"), entry: second_printing)
    2.times { |i| NumberEntry.add!(account:, entry: i.zero? ? entry : second_printing, quantity: 1, finish: "nonfoil", line_key: SecureRandom.hex(16)) }
    [ entry, second_printing ].each { |printing| Scanner::Sitting.add!(account:, printing:, finish: "nonfoil", reading_key: SecureRandom.hex(16)) }
    create(:user)
  end

  def entry = lot.entry # methods, not `let`s: the cop counts memoized helpers
  def second_printing = Catalog::Entry.find_by!(identity: entry.identity, number: "139")
  def deck = user.account.locations.find_by!(kind: "deck") # a Location; `Deck#to_param` is its id, so the paths work
  def zone_key = "main"

  # The audit table of spec 075: page name → its route, and the small controls the table lists for it at each width, as
  # [css, text] (text nil = any). Row numbers are the spec's.
  def pages
    { "card search" => { path: catalog_entries_path(q: "Lightning"), # row 2
        wide: [ [ ".c-filterbar__filters .c-btn--sm", "Search" ], [ ".c-section__actions .c-btn--sm", "Show all" ], [ ".c-pager .c-btn--sm", "Next" ],
                [ ".c-grid .c-btn--sm", nil ] ] }, # the tile's quick add
      "card page" => { path: catalog_entry_path(entry), # row 3
        wide: [ [ "summary.c-btn--sm.c-btn--icon", nil ], [ ".c-section__actions .c-btn--sm", "Show all" ], [ "#printings .c-list__end .c-btn--sm", nil ] ] }, # the last: the quick add of an unowned printing
      "printings page" => { path: catalog_identity_path(entry.identity, set: entry.set.code), # row 4
        wide: [ [ ".c-btn--sm", "Show all sets" ], [ ".c-grid .c-btn--sm", nil ], [ ".c-pager .c-btn--sm", "Next" ] ] },
      "collection grid" => { path: collection_path(view: "grid"), # row 5
        wide: [ [ ".c-filterbar__filters .c-btn--sm", "Filter" ], [ ".c-filterbar__bulk", "Edit many" ], [ ".c-seg button", nil ], [ ".c-pager .c-btn--sm", "Next" ] ],
        narrow: [ [ ".c-filterbar__more summary", nil ], [ ".c-seg button", nil ], [ ".c-appbar .c-appbar__add", nil ] ] },
      "collection table" => { path: collection_path(view: "table"), # row 6
        wide: [ [ ".c-table summary.c-btn--sm.c-btn--icon", nil ], [ ".c-seg button", nil ], [ ".c-pager .c-btn--sm", "Next" ] ] },
      "bulk mode" => { path: collection_path(bulk: 1), # row 7
        wide: [ [ ".c-bulkbar__extra .c-btn--sm", "Set condition" ], [ ".c-bulkbar__extra .c-btn--sm", "Move to" ], [ ".c-bulkbar__extra .c-btn--sm", "Remove" ],
                [ ".c-bulkbar .c-btn--sm", "Done" ], [ ".c-filterbar__filters .c-btn--sm", "Filter" ], [ ".c-seg button", nil ], [ ".c-pager .c-btn--sm", "Next" ] ],
        narrow: [ [ ".c-bulkbar__more summary", nil ], [ ".c-bulkbar .c-btn--sm", "Done" ] ] },
      "number entry" => { path: collection_number_entry_path(type: "mtg", set: entry.set.code, language: "en"), # rows 8, 8b
        wide: [ [ ".c-numentry__language .c-btn--sm", "Change language" ], [ ".c-btn--sm", "Change set" ], [ ".c-numentry__list .c-btn--sm", "Done" ],
                [ ".c-numentry__list .c-btn--sm", "Undo" ], [ ".c-numentry__list summary.c-btn--sm", "Show all" ] ] },
      "decks" => { path: decks_path, wide: [ [ ".c-decks__actions .c-btn--sm", "Rename" ], [ ".c-decks__actions .c-btn--sm", "Change format" ], [ ".c-decks__actions .c-btn--sm", "Remove" ] ] }, # row 9
      "deck page" => { path: deck_path(deck), # rows 9, 9b
        wide: [ [ ".c-zone .c-section__actions .c-btn--sm", "Add a proxy" ], [ ".c-zone summary.c-btn--sm.c-btn--icon", nil ] ] },
      "proxy chooser" => { path: new_deck_zone_proxy_path(deck, zone_key, q: "Lightning"), # row 10
        wide: [ [ ".c-filterbar__filters .c-btn--sm", "Search" ], [ ".c-btn--sm", "Choose" ] ] },
      "locations" => { path: locations_path, wide: [ [ ".c-btn--sm", "Rename" ], [ ".c-btn--sm", "Remove" ] ] }, # row 11
      "admin jobs" => { path: admin_jobs_path(status: "failed"), # row 12
        wide: [ [ ".c-filter", "Failed" ], [ ".c-filter", "Running" ], [ ".c-filter", "Queued" ], [ ".c-filter", "Scheduled" ], [ "summary.c-btn--sm.c-btn--icon", nil ] ] },
      "admin users" => { path: admin_users_path, wide: [ [ "summary.c-btn--sm.c-btn--icon", nil ] ] }, # row 13
      "scanner" => { path: scanner_path, # row 14 (the sitting)
        wide: [ [ "#scanner_sitting .c-btn--sm", "Done" ], [ "#scanner_sitting .c-btn--sm", "Undo" ], [ "#scanner_sitting .c-btn--sm", "Details" ],
                [ "#scanner_sitting summary.c-btn--sm", "Show all" ], [ "#scanner_sitting .c-btn--sm", "Set" ] ] },
      "measurement mode" => { path: scanner_measurement_path, wide: [ [ ".c-btn--sm", "Skip" ] ] } } # row 15
  end
```

File layout (the snippets show the pieces; the implementer assembles them and runs `ruby -c`): the describe holds the one-line methods (`block_*`, `small`, `page_rule_scopes`, `rows`) and the measuring helpers (`small_controls(selector = small)`, `drawn?`, `coarse_rules`, `row_lines`, `row_alignment`, `other_controls`); `context "with an admin's account"` holds the `let`s, `around`, `before`, `make_fixtures`, `pages`, `in_page`, `settle`, `expected_at`, `rows_of`, `other_controls_of`, `filter_pages` and every example of Tasks 3 and 4 except rows 1 and 14b; `context "without the admin's fixtures"` holds rows 1 and 14b (Task 4 Step 4), each with its own sign-in. The context and the describe close after the last example.

(A page with no `narrow:` key expects the same list at 360px as at 1280px; the pages whose controls differ below 640px, the collection pages and the app bar, give a `narrow:` list.) The implementer checks every selector and text against the views before the red run (reads `app/views/...`), and fixes the fixture or the selector, never drops an entry; a control that cannot be drawn is a stop-and-ask.

Measurement mode needs spec 072's manifest `around` hook (copy its `around` block and the `corpus` helper from `select_touch_floor_spec.rb` lines 12-22, as a `let(:corpus)` and `around`; the cop's helper count is why `entry` and the like are methods). The admin jobs page needs `:solid_queue` on the `RSpec.describe` line and, in `make_fixtures`, `fail_job(queue_job(MTG::Art::BuildJob))` and `queue_job(MTG::Art::BuildJob, wait: 1.hour)`; the route is `admin_jobs_path(status: "failed")`, which holds the failed job's row menu and the four chips. (No queued or running job exists, so the page's poll is idle.)

- [ ] **Step 2: write the measuring helpers** (the layout paragraph above says where each sits: the measuring methods at describe level, `in_page`, `settle`, `expected_at` inside the admin context):

```ruby
  # Runs the block on the page: in the window at 1280px, or in a frame `width` px wide (the frame is the document the block
  # measures and injects into, so `document` and `window` in its scripts are the frame's).
  def in_page(name, width: 1280, &block)
    definition = pages.fetch(name)
    if width < 500
      visit collection_path(view: "grid")
      open_in_narrow_frame(definition.fetch(:path), width:, ready: "main")
      within_narrow_frame do
        settle(name)
        block.call
      end
    else
      visit definition.fetch(:path)
      expect(page).to have_css("main")
      settle(name)
      yield
    end
  end

  # The scanner's stage is unhidden by script some time after `main` exists (the fake camera); wait for it on the two scanner pages.
  def settle(name)
    expect(page).to have_css(".c-scanner__stage:not([hidden])", wait: 10) if [ "scanner", "measurement mode" ].include?(name)
  end

  # What the page expects to draw at this width: the `narrow` list when the table gives one (the pages whose controls differ below
  # 640px: the collection pages, the app bar), else the `wide` list.
  def expected_at(definition, width)
    return definition.fetch(:wide, []) if width >= 500

    definition.fetch(:narrow) { definition.fetch(:wide, []) }
  end

  # Every drawn small control of the current document (AC-1.2's set): its name, size, whether a page rule covers it, whether it is
  # icon-only, and where it sits.
  def small_controls(selector = small)
    page.evaluate_script(<<~JS, selector, page_rule_scopes)
      (() => {
        const [selector, scopes] = arguments
        const inClosedMenu = (el) => { const d = el.closest("details:not([open])"); return !!d && !(el.tagName === "SUMMARY" && el.parentElement === d) }
        const iconOnly = (el) => el.classList.contains("c-btn--icon") || (el.matches(".c-seg button") && !!el.querySelector(".c-seg__label") && getComputedStyle(el.querySelector(".c-seg__label")).position === "absolute")
        return [...document.querySelectorAll(selector)]
          .filter((el) => !el.closest(".c-sr") && !inClosedMenu(el))
          .map((el) => { const box = el.getBoundingClientRect()
            return { name: el.className + " | " + (el.getAttribute("aria-label") || el.textContent).trim().replace(/\\s+/g, " ").slice(0, 40),
                     height: box.height, width: box.width, right: box.right, page: !!el.closest(scopes), icon: iconOnly(el), row: !!el.closest(".c-filterbar__filters") } })
          .filter((control) => control.height > 0 && control.width > 0)
      })()
    JS
  end

  # Whether a control matching `css` (and, with text, whose label or text includes it) is drawn in the current document.
  def drawn?(css, text)
    page.evaluate_script(<<~JS, css, text)
      (() => {
        const [css, text] = arguments
        return [...document.querySelectorAll(css)].some((el) => {
          const d = el.closest("details:not([open])"); const hidden = !!d && !(el.tagName === "SUMMARY" && el.parentElement === d)
          const box = el.getBoundingClientRect()
          return !hidden && box.width > 0 && box.height > 0 && (!text || ((el.getAttribute("aria-label") || "") + " " + el.textContent).includes(text))
        })
      })()
    JS
  end
```

- [ ] **Step 3: write AC-1.1, AC-1.2, AC-1.3 examples.**

```ruby
  # The coarse-pointer rules that set a min-height or min-width, with the stylesheet that holds each, in source order.
  def coarse_rules
    page.evaluate_script(<<~JS)
      (() => {
        const found = []
        ;[...document.styleSheets].forEach((sheet, index) => {
          for (const media of sheet.cssRules)
            if (media instanceof CSSMediaRule && media.conditionText.includes("pointer: coarse"))
              for (const rule of media.cssRules)
                if (rule.style?.minHeight || rule.style?.minWidth)
                  found.push({ sheet: sheet.href || "", index, selector: rule.selectorText, minHeight: rule.style.minHeight, minWidth: rule.style.minWidth })
        })
        return { found, floor: parseFloat(getComputedStyle(document.documentElement).getPropertyValue("--touch-floor")) || 0 }
      })()
    JS
  end

  it "gives the small controls a coarse-pointer rule of their own that wins by source order (AC-1.1)", :aggregate_failures do
    visit new_deck_path
    read = coarse_rules
    height_rules = read["found"].select { it["selector"] == block_height[:selector] }
    width_rules = read["found"].select { it["selector"] == block_width }
    expect(height_rules.size).to eq(2), "components.css's 40px rule and the block's: #{height_rules}"
    expect(height_rules.last).to include("minHeight" => "var(--touch-floor)")
    expect(height_rules.last["sheet"]).to include("additions")
    expect(height_rules.last["index"]).to be > height_rules.first["index"]
    expect(width_rules.last).to include("minWidth" => "var(--touch-floor)")
    expect(read["floor"]).to be >= 44
  end

  [ 1280, 360 ].each do |width|
    it "draws every small control at least 44px high, the icon-only ones 44px wide, at #{width}px (AC-1.2)", :aggregate_failures do
      pages.each do |name, definition|
        in_page(name, width:) do
          inject_coarse(needs: block_rules)
          expected_at(definition, width).each { |css, text| expect(drawn?(css, text)).to be(true), "#{name}: no #{css} #{text} is drawn" }
          found = small_controls
          expect(found).not_to be_empty, "#{name}: no small control is drawn"
          expect(found.select { it["height"] < 44 }.map { it["name"] }).to be_empty, "#{name}: under 44px high"
          expect(found.select { it["icon"] && it["width"] < 44 }.map { it["name"] }).to be_empty, "#{name}: icon-only under 44px wide"
        end
      end
    end
  end

  [ 1280, 360 ].each do |width|
    it "leaves a fine pointer's compact size where no page rule applies, at #{width}px (AC-1.3)", :aggregate_failures do
      compact = 0
      pages.each_key do |name|
        in_page(name, width:) do
          # the expected controls are drawn at a fine pointer too (this runs before the CSS exists, so a wrong selector or fixture shows here)
          expected_at(pages.fetch(name), width).each { |css, text| expect(drawn?(css, text)).to be(true), "#{name}: no #{css} #{text} is drawn" }
          found = small_controls.reject { it["page"] }
          compact += found.size
          expect(found.select { it["height"] >= 36 }.map { it["name"] }).to be_empty, "#{name}: a small control with no page rule is 36px or more with a fine pointer"
        end
      end
      expect(compact).to be > 10 # at least some pages had controls to measure
    end
  end
```

- [ ] **Step 4: red run.** `bin/rspec spec/system/small_controls_touch_floor_spec.rb` → AC-1.1 and both AC-1.2 fail (AC-1.1 on `height_rules.size` 1 against 2; AC-1.2 by name on `needs:`: "the coarse-pointer rule [{:sheet=>"additions", …}, ".c-btn--sm.c-btn--icon, .c-seg button"] is not in the loaded stylesheets" naming BOTH, because the helper reports both missing); AC-1.3 passes (it also asserts every listed control is drawn, with nothing injected, so a wrong selector or fixture fails here, before the CSS, in the red run). Fix any selector or fixture error from a *different* failure before committing (a failure message that isn't the missing-rule one means the example is wrong).
- [ ] **Step 5:** `bin/rubocop -a` the file; commit `test(spec): small controls touch floor, part A: the rule, the pages, the fine pointer (red)`.

---

## Task 4: the new system spec, part B: layout and the can-fail partners (AC-1.4 to AC-1.8)

**File:** the same. Written red: every example here passes `needs: block_rules` or compares states and so fails by naming the missing rule.

- [ ] **Step 1: AC-1.4, AC-1.6.**

```ruby
  it "keeps every page whole at 360px with all the coarse rules: no overflow, no overlap, nothing past the edge (AC-1.4)", :aggregate_failures do
    pages.each_key do |name|
      in_page(name, width: 360) do
        inject_coarse(needs: block_rules)
        report = layout_report(roots: [ "main", ".c-appbar", "#status" ])
        expect(report["overflow"]).to be <= 0, "#{name}: scrolls sideways by #{report['overflow']}px"
        expect(report["overlaps"]).to be_empty, "#{name}: overlapping controls: #{report['overlaps']}"
        edge = page.evaluate_script("document.documentElement.clientWidth")
        past = small_controls.reject { it["row"] }.select { it["right"] > edge + 1 }.map { it["name"] }
        expect(past).to be_empty, "#{name}: past the right edge: #{past}"
      end
    end
  end

  # The filter bars: the collection (grid view and bulk mode), the card search and the add-a-proxy chooser.
  def filter_pages = [ "collection grid", "bulk mode", "card search", "proxy chooser" ]

  def row_alignment
    page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector(".c-filterbar__filters")
        const select = row.querySelector("select"), button = row.querySelector(".c-btn")
        const centre = (el) => { const rect = el.getBoundingClientRect(); return rect.top + rect.height / 2 }
        return { select: select.getBoundingClientRect().height, button: button.getBoundingClientRect().height, offset: Math.abs(centre(select) - centre(button)) }
      })()
    JS
  end

  [ 1280, 360 ].each do |width|
    it "levels the filter row's small button with its select, both at least 44px, at #{width}px (AC-1.6)", :aggregate_failures do
      filter_pages.each do |name|
        in_page(name, width:) do
          inject_coarse(needs: block_rules)
          row = row_alignment
          expect([ row["select"], row["button"] ]).to all(be >= 44), "#{name}: #{row}"
          expect(row["offset"]).to be <= 1, "#{name}: the button's centre is #{row['offset']}px off the select's"
        end
      end
    end
  end
```

- [ ] **Step 2: AC-1.5 (lines per row) and AC-1.7 (nothing else moves), with their comparison helpers.**

```ruby
  # The pages in the spec's row list that draw each row, at either width: [page name, row selector] pairs are found by the page.
  # Counts the lines of every row of rows on the current page: a line is a cluster of the row's drawn controls whose vertical
  # extents overlap, so controls of different heights centred on one line are one line. Returns [[selector#index, lines], …],
  # and the height of the first `.c-filterbar`.
  def row_lines
    page.evaluate_script(<<~JS, rows, small)
      (() => {
        const [rows, small] = arguments
        const wanted = "button, input:not([type=hidden]), select, summary, a[href], .c-btn, .c-filter, " + small
        const drawn = (el) => { const d = el.closest("details:not([open])"); const box = el.getBoundingClientRect()
          return box.width > 0 && box.height > 0 && !el.closest(".c-sr") && !(d && !(el.tagName === "SUMMARY" && el.parentElement === d)) }
        const lines = [...document.querySelectorAll(rows)].map((row, index) => {
          const boxes = [...row.querySelectorAll(wanted)].filter(drawn).map((el) => el.getBoundingClientRect()).sort((a, b) => a.top - b.top)
          let count = 0, bottom = -Infinity
          for (const box of boxes) { if (box.top >= bottom - 1) { count += 1; bottom = box.bottom } else { bottom = Math.max(bottom, box.bottom) } }
          return [row.className.split(" ")[0] + "#" + index, count]
        })
        const bar = document.querySelector(".c-filterbar")
        return { lines, bar: bar ? bar.getBoundingClientRect().height : null }
      })()
    JS
  end

  # The line counts (and the first filter bar's height) of every page at a width, with every coarse rule applied except `except`
  # and with `extra` CSS. The scrollbar is pinned on so a taller page can't narrow the frame by 15px (which is no layout defect).
  def rows_of(width, except: [], extra: "")
    pages.keys.to_h do |name|
      report = nil
      in_page(name, width:) do
        inject_coarse(except:, extra: "html { overflow-y: scroll; } #{extra}", needs: block_rules)
        report = row_lines
      end
      [ name, report ]
    end
  end

  [ 1280, 360 ].each do |width|
    it "adds no line to any row of controls at #{width}px (AC-1.5)", :aggregate_failures do
      without = rows_of(width, except: block_rules)
      with = rows_of(width)
      pages.each_key do |name|
        expect(with.fetch(name)["lines"]).to eq(without.fetch(name)["lines"]), "#{name}: lines per row changed"
      end
      next unless width == 360

      expect(with.fetch("collection grid")["bar"] - without.fetch("collection grid")["bar"]).to be <= 8
    end
  end

  # Name, label, width and height of every control that is not a small control (AC-1.7), in document order.
  def other_controls
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("main :is(button, input, textarea, select, summary, .c-btn)")]
        .filter((el) => !el.closest(".c-sr") && el.type !== "hidden" && !el.matches(".c-btn--sm, .c-filter, .c-seg button"))
        .map((el) => {
          const box = el.getBoundingClientRect()
          return [el.tagName, (el.textContent.trim() || el.value || el.name || el.id).slice(0, 24), Math.round(box.width * 100) / 100, Math.round(box.height * 100) / 100]
        })
    JS
  end

  def other_controls_of(name, except: [], extra: "")
    controls = nil
    in_page(name, width: 360) do
      inject_coarse(except:, extra: "html { overflow-y: scroll; } #{extra}", needs: block_rules)
      controls = other_controls
    end
    controls
  end

  it "changes no other control's size: all coarse rules with and without the block's two (AC-1.7)", :aggregate_failures do
    pages.each_key do |name|
      without = other_controls_of(name, except: block_rules)
      with = other_controls_of(name)
      expect(without).not_to be_empty, "#{name}: no control found"
      expect(with.size).to eq(without.size), "#{name}: #{without.size} controls without the block, #{with.size} with it"
      changed = without.zip(with).reject { |before, after| before == after }
      expect(changed).to be_empty, "#{name}: controls whose size changed: #{changed}"
    end
  end
```

Caveat for the implementer: `rows_of` with `except: block_rules` leaves `needs: block_rules` satisfied because `needs` is checked against the stylesheets, not against what was injected (the helper's `missing` reads `rules` seen, before the filter).

- [ ] **Step 3: AC-1.8, the can-fail partners.**

```ruby
  # Number entry's Add button is a `c-btn` that is not small (card search has none: its Search, Show all, quick add and pager are all
  # small, so the variant could not change anything there and the example would be green for the wrong reason).
  it "notices a rule that grows another control (AC-1.7 can fail)", :aggregate_failures do
    without = other_controls_of("number entry", except: block_rules)
    with = other_controls_of("number entry", extra: ".c-input, .c-btn:not(.c-btn--sm) { min-height: 90px; }")
    expect(with).not_to eq(without)
    expect(without.map { it[3] }.max).to be < 90
  end

  it "notices a row that gains a line (AC-1.5 can fail)", :aggregate_failures do
    [ [ 360, "bulk mode" ], [ 360, "number entry" ] ].each do |width, name|
      in_page(name, width:) do
        inject_coarse(except: block_rules, extra: "html { overflow-y: scroll; }", needs: block_rules)
        before = row_lines["lines"]
        inject_coarse(extra: ".c-btn--sm { min-width: 300px; }", needs: block_rules) # a second adopted sheet on top of the first
        after = row_lines["lines"]
        expect(after.sum { |_, lines| lines }).to be > before.sum { |_, lines| lines }, "#{name}: no row gained a line"
      end
    end
  end

  it "has a control under 44px without the block: the floor is the block's doing (AC-1.2 can fail)" do
    in_page("collection grid") do
      inject_coarse(except: block_rules, needs: block_rules)
      expect(small_controls.reject { it["page"] }.map { it["height"] }.min).to be < 44
    end
  end
```

Note for the second example: the `.c-btn--sm { min-width: 300px }` in the second injection is the "variant"; the first injection already applied every coarse rule except the block's. If the second `inject_coarse` re-applying all coarse rules (including the block) is a problem, restructure to one injection with `extra:` and two page loads (`in_page` twice) as `rows_of` does; the implementer picks the simpler and keeps the can-fail meaning (a row's line total must grow).

- [ ] **Step 4: flows that need their own setup (rows 16, 1, 14b).** Row 16 goes in the admin context; rows 1 and 14b in a second context of the same describe, `context "without the admin's fixtures"` (each example signs in as it needs, or not, and creates the "Lightning Bolt" identity the admin context also creates, which is why they are not in it).

Row 16, the status message's Undo (in the admin context; it needs the removal flow, so it is its own example with the window and the frame):

```ruby
  # Removes every lot in bulk mode (the "…" menu holds Remove below 640px), confirms, and returns the status line's Undo heights.
  def remove_all_and_measure_undo(narrow)
    check "Select all"
    find(".c-bulkbar__more summary").click if narrow
    click_on "Remove", match: :first
    find(:button, text: /\ARemove \d+ items?\z/).click
    expect(page).to have_css("#status .c-btn--sm", text: "Undo")
    inject_coarse(needs: block_rules)
    heights = small_controls.select { it["name"].include?("Undo") }.map { it["height"] }
    click_on "Undo" # puts the lots back for the next width, inside the frame at 360px
    expect(page).to have_css("#status", text: /Restored/)
    heights
  end

  it "draws the status message's Undo at 44px after a bulk removal (AC-1.2, row 16)", :aggregate_failures do
    [ 1280, 360 ].each do |width|
      heights = nil
      if width < 500
        visit collection_path(view: "grid")
        open_in_narrow_frame(collection_path(bulk: 1), width:, ready: "main")
        within_narrow_frame { heights = remove_all_and_measure_undo(true) }
      else
        visit collection_path(bulk: 1)
        heights = remove_all_and_measure_undo(false)
      end
      expect(heights.size).to eq(1), "exactly one Undo is drawn at #{width}px"
      expect(heights).to all(be >= 44)
    end
  end
```

The implementer reads `collections/_bulk.html.erb` and `spec/system/collection_location_filter_spec.rb:53-70` for the exact Remove path (the "…" menu's items are `c-menu__item` buttons), and adjusts the click steps; the assertion (the status line's one Undo at least 44px high under every coarse rule) is what the example is for.

Rows 1 and 14b, the second context (each width its own example, so none passes RSpec/ExampleLength's 15 lines):

```ruby
  context "without the admin's fixtures" do
    # Row 1: a visitor's "Sign in" on an open catalog.
    def sign_in_height_with_coarse_rules
      inject_coarse(needs: [ block_height ])
      page.evaluate_script("document.querySelector('.c-appbar a.c-btn--sm').getBoundingClientRect().height")
    end

    [ 1280, 360 ].each do |width|
      it "draws a visitor's Sign in at 44px on an open catalog at #{width}px (AC-1.2, row 1)", :public_catalog do
        create(:mtg_printing)
        visit catalog_entries_path
        if width < 500
          open_in_narrow_frame(catalog_entries_path, width:, ready: "main")
          within_narrow_frame { expect(sign_in_height_with_coarse_rules).to be >= 44 }
        else
          expect(sign_in_height_with_coarse_rules).to be >= 44
        end
      end
    end

    # Row 14b: a candidate's Add buttons and "Other printings" link, after the scanner reads a card (setup as scanner_adding_spec.rb).
    def read_a_card
      identity = create(:catalog_identity, name: "Lightning Bolt")
      mom = create(:catalog_set, code: "mom", name: "March of the Machine")
      create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
      Catalog::NameIndex.new("mtg").rebuild
      system_sign_in_as(create(:user))
    end

    def candidate_heights
      show_synthetic_card
      click_on "Capture"
      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      inject_coarse(needs: block_rules)
      small_controls(".c-scanner__candidate .c-btn--sm, .c-scanner__add .c-btn--sm").map { it["height"] }
    end

    it "draws a candidate's Other printings and Add buttons at 44px at 1280px (AC-1.2, row 14b)", :aggregate_failures do
      read_a_card
      visit scanner_path
      heights = candidate_heights
      expect(heights.size).to be >= 3 # Nonfoil, Foil, Other printings
      expect(heights).to all(be >= 44)
    end

    it "draws a candidate's Other printings and Add buttons at 44px at 360px (AC-1.2, row 14b)", :aggregate_failures do
      read_a_card
      visit collection_path(view: "grid")
      open_in_narrow_frame(scanner_path, width: 360, ready: "main")
      heights = nil
      within_narrow_frame { heights = candidate_heights }
      expect(heights.size).to be >= 3
      expect(heights).to all(be >= 44)
    end
  end
```

(The context and the describe close here: the file ends with these two `end`s.) **If the reading flow cannot run inside the frame (the synthetic card or the fake camera needs the top-level page), stop and ask the coordinator: the spec asks for 360px, and measuring at the window's 500px minimum instead is a departure that needs a spec update.** "Show N more" in the printings frame: the example then clicks "Other printings" and measures `summary.c-btn--sm` in `#scanner_printings`; add a second printing of the card to the fixture and `stub_const("Scanner::OtherPrintings::SHOWN", 1)` (`app/models/scanner/other_printings.rb:5`). Not drawing it is a stop-and-ask, not a silent skip. `small_controls` takes the selector (`small_controls(selector = small)`, Task 3 Step 2).

- [ ] **Step 5: red run.** `bin/rspec spec/system/small_controls_touch_floor_spec.rb` → the examples of Task 3 and these all fail naming the missing block rule (AC-1.1 on size, the others on `needs`), except AC-1.3, and the three can-fail partners that don't depend on the block's presence beyond `needs` (they fail by name too). Fix wrong selectors and fixtures until every failure is "the coarse-pointer rule … is not in the loaded stylesheets" or AC-1.1's size message. Record the run (example count and failures) in the commit body.
- [ ] **Step 6:** `bin/rubocop -a`; commit `test(spec): small controls touch floor, part B: layout, rows and the can-fail partners (red)`.

---

## Task 5: the CSS block and the two comments (green)

**File:** `app/assets/stylesheets/collector/additions.css`. **Comments updated:** the heading comment of spec 072's block and of spec 068's "Add a proxy" block (they say 40px).

- [ ] **Step 1: add the block** directly after spec 072's block (the `@media (pointer: coarse) { .c-field select, … }` block that ends with `.c-filterbar__filters { align-items:center; }` and its `}`), before `/* ---------- Pagination ---------- */`:

```css
/* ---------- Small controls meet the touch floor on a coarse pointer (spec 075) ---------- */
/* A small button (`c-btn--sm`), a filter chip (`c-filter`) and a view-switch button (`c-seg button`) are 28px with a mouse. The
   export's touch block (`components.css`) raised them to 40px, below the 44px every other control and every select reaches; the
   maintainer ruled them up to the floor (#316). `min-height` and `min-width`, which only raise, and the token every 44px rule here uses.
   Same specificity as the export's rule, and this file is linked after it, so it wins by source order: the export's 40px lines stay
   in `components.css` (a re-export restores them and still loses here), so keep this block after them. The icon variant and the
   view switch get a width too: an icon-only view-switch button is 38px wide below 640px of its container. Locations, the Decks pages,
   number entry's list and the scanner already give their buttons 44px at every pointer by rules of their own; those stay.
   Headless Firefox has a fine pointer, so `spec/system/small_controls_touch_floor_spec.rb` reads these rules and applies them. */
@media (pointer: coarse) {
  .c-btn--sm, .c-filter, .c-seg button { min-height:var(--touch-floor); }
  .c-btn--sm.c-btn--icon, .c-seg button { min-width:var(--touch-floor); }
}
```

(No "spec 019", "spec 021" or "spec 023" text: `spec/design_system_files_spec.rb` counts them across the file.)
- [ ] **Step 2: correct spec 072's block comment.** In its first comment lines replace "Every other control reaches the touch floor on a touch screen (40px for small buttons, chips and the view switch) and so does a select" with "Every other control reaches the touch floor on a touch screen (the small controls too, spec 075) and so does a select", and replace the sentence "The filter row's children use the default `stretch` and a `c-btn--sm` (40px there, an explicit height) does not stretch, so beside a 44px select it would sit at the top of the row, 4px short: the row centres its controls on a coarse pointer." with "The filter row's children use the default `stretch` and a `c-btn--sm` (an explicit height) does not stretch, so a control shorter than the select would sit at the top of the row: the row centres its controls on a coarse pointer." Read the exact lines first (reading lines ~140-150 with the Read tool); keep the rest.
- [ ] **Step 3: correct spec 068's comment.** In the "Deck page Add a proxy" block comment replace "36px on a mouse and 40px on a touch screen by the design system's rule for a small button" with "28px with a mouse and 44px on a touch screen by the design system's rule for a small button (spec 075)".
- [ ] **Step 4: green run.** `bin/rspec spec/system/small_controls_touch_floor_spec.rb spec/system/select_touch_floor_spec.rb spec/system/deck_page_spec.rb spec/design_system_files_spec.rb` → all pass. If an AC-1.4/1.5 example fails for a real layout reason (a row wraps, a control overlaps at 360px), STOP: fix test-first with the coordinator's knowledge (it is a finding for the PR), do not weaken the example.
- [ ] **Step 5:** commit `feat(design-system): small controls meet the 44px touch floor on a coarse pointer (spec 075, #316)`.

---

## Task 6: the design system's documents (verified by reading)

**Files:** `docs/design-system/README.md` and the nine component documents. **Satisfies:** AC-2.1, AC-2.2.

- [ ] **Step 1: README Touch rule.** Replace the bullet on line 73 (it starts "- On touch devices every target is at least 44px (40px for small buttons, chips and the view switch)") with:

"- On touch devices every target is at least 44px, with no exception: buttons, inputs, menu items and selects, and the small buttons (`c-btn--sm`), filter chips (`c-filter`) and view-switch buttons (`c-seg`) too (spec 075, [#316](https://github.com/plainprogrammer/Collector/issues/316), the maintainer's ruling of 2026-11-11, which ended the 40px of earlier versions); a small icon button and a view-switch button are 44px wide as well. The compact sizes, 28px for the small controls and the filter bar's select and 36px for a form's select, are the fine pointer's. The rules are `pointer: coarse` blocks: `collector/components.css` holds the export's (it still writes 40px for the small controls, which `additions.css` overrides), and `collector/additions.css` holds the app's (the selects', spec 072, [#315](https://github.com/plainprogrammer/Collector/issues/315): `min-height: var(--touch-floor)` on `.c-field select` and `.c-select select`; the small controls', spec 075: `.c-btn--sm`, `.c-filter` and `.c-seg button`; one block each); the app's blocks must stay after the export's in the layout, which is why the export's file is not edited. On a coarse pointer the filter row (`c-filterbar__filters`) centres its controls, so a control that is not 44px (a label, a shorter field) sits level with the select. A new select is a `c-field` or `c-select` select and a new small control carries one of the three classes: each meets the floor with no rule of its own; a select outside both shapes is a design-system violation, not something the rule hides. The pages that give their buttons 44px at every pointer (Locations, the Decks pages, number entry's list, the scanner's sitting) keep their own rules."

(Read line 73 first; the sentence about `bundle.css` was already corrected by spec 072, so the replacement is the whole bullet.)
- [ ] **Step 2: component sentences.** Append to each document one bullet in its list of rules (read each file to place it with its neighbours; wording is the implementer's within these facts, each ends with "(README, Touch rule, spec 075)"):
  - `Button.md`: on a coarse pointer every button is at least 44px high, `c-btn--sm` included, and a `c-btn--icon` 44px wide; 28px and 36px are the fine pointer's.
  - `Chip.md`: on a coarse pointer a filter chip is at least 44px high; 28px is a mouse's.
  - `ViewSwitch.md`: on a coarse pointer each button is at least 44px high and 44px wide, also with its label hidden below 640px.
  - `TableActions.md`: the "…" trigger is a small icon button, 28px square with a mouse and at least 44px square on a touch screen.
  - `BulkForm.md`: the bar's small buttons and "…" menu are 44px on a touch screen.
  - `Pager.md`: Previous and Next are small buttons, 44px high on a touch screen.
  - `AdminJobs.md`: the four state chips and each row's "…" trigger are 44px on a touch screen.
- [ ] **Step 3: corrections.** `FilterSelect.md` line 16: replace "so the 40px small button beside it sits level with it" with "so the small button beside it (also 44px there, spec 075) sits level with it". `NumberEntry.md` line 38: replace "keeps its select and its 40px "Change language" button" with "keeps its select and its "Change language" button, both 44px there (spec 075)".
- [ ] **Step 4: read-through.** `git grep -n -E "(^|[^0-9])40px" -- docs/design-system ':!.kamal/secrets'` (previews included, so a hard-coded 40px in a preview shows too; the pattern skips "640px") → only the README's mention that `components.css` still writes 40px; record in `verification.md`.
- [ ] **Step 5:** commit `docs(design-system): small controls are 44px on a touch screen, no exception (spec 075)`.

---

## Task 7: verification evidence and the targeted run

**Files:** `docs/specs/075-small-controls-touch-floor/verification.md` (the supervisor writes it; the implementer runs the commands).

- [ ] **Step 1: the greps.** Run the audit command and the supersession grep of this plan; record each command and its dispositions in `verification.md` ("The audit", "The supersession grep"); a hit not in the plan's table is fixed test-first or listed with a reason.
- [ ] **Step 2: the targeted suite.** `bin/rspec spec/system/small_controls_touch_floor_spec.rb spec/system/select_touch_floor_spec.rb spec/system/deck_page_spec.rb spec/system/deck_proxies_spec.rb spec/system/deck_additions_spec.rb spec/system/card_page_spec.rb spec/system/deck_proxy_replacements_spec.rb spec/system/deck_bulk_shortcut_spec.rb spec/design_system_files_spec.rb` plus the locations system examples (`ls spec/system | grep -i location`); the rest of AC-3.2's examples run in the full suite on the push → all pass; record the counts. `bin/rubocop` and `bin/yard doc` (the comment ratchet is a `bin/ci checks` step) clean.
- [ ] **Step 3:** AC-3.1 evidence: `git diff --stat origin/main...HEAD -- app db config lib script` shows only `additions.css`.
- [ ] **Step 4:** commit `docs(spec): spec 075 verification`.

Then (supervisor, not the implementer): the visual evidence (before and after screenshots, both themes, 360px and 1280px, of the filter bars, the bulk bar, the view switch and the row menus), the implementation review (Mode B), session-wrap and `distill-feature`, the draft PR.

## Self-review

- **Spec coverage:** FR-1 Task 5; FR-2 Task 6 (and the index row, done at the spec's commit); FR-3 Tasks 1 to 4; FR-4 Task 7 Step 3. AC-1.1 Task 3; AC-1.2, AC-1.3 Task 3 (+ flows, Task 4); AC-1.4, AC-1.6 Task 4 Step 1; AC-1.5, AC-1.7 Task 4 Step 2; AC-1.8 Task 4 Step 3; AC-2.1, AC-2.2 Task 6; AC-2.3 done; AC-3.1 Task 7; AC-3.2 Tasks 2, 5, 7.
- **Placeholders:** the selectors and fixtures marked "the implementer verifies against the views" are bounded (stop-and-ask on a control that can't be drawn); no TBDs.
- **Type consistency:** `inject_coarse(only:, except:, extra:, needs:)`, `layout_report(roots:)`, `small_controls(selector = small)`, `block_rules`, `block_height`, `block_width`, `row_lines`, `rows_of` are used with the signatures defined here.
