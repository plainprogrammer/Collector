# Implementation Plan: Design System: Deck Rules, Navigation and Pickers

**Spec:** [docs/specs/057-deck-design-rules/spec.md](spec.md) (version 1.1.0: Approved at Gate A on 2026-11-10, plus decision 19 ruled by the maintainer the same day)
**Decisions:** none new; the maintainer's rulings are the spec's decisions 1–18 (no ADR, decision 14)
**Issue:** [#248](https://github.com/plainprogrammer/Collector/issues/248) (roadmap item 14a)
**Created:** 2026-11-10
**Status:** Approved at Gate B (2026-11-10); revised for spec 1.1.0 (Phase 5 and the Navigation docs), the maintainer's ruling on the header
**Review:** round 1 (read-only Opus): NEEDS REVISION, 0 blocking, 7 major, 8 minor; all fixed in this draft (the font longhands on the optgroup, the selected option in the probe, the batches, the Decks icon, the README and phone-page sentences, the missed re-export line in the area doc, the header measure's control, the preview scripts). Round 2: APPROVED (one wording nit, fixed).

## Global Constraints

These bind every phase. They are the spec's, copied in short.

- The change is documents, `additions.css`, six previews, one view line and specs. No helper, model, route, query, export, migration or token changes; no view other than `collections/_location_select.html.erb` (spec Non-Goals; FR-4, FR-5).
- Build only on the tokens in `app/assets/stylesheets/collector/tokens.css`. No colour literal, no hard-coded spacing, no `font` shorthand on `optgroup`, no JavaScript, no custom select (FR-4 Must not).
- New CSS goes in `app/assets/stylesheets/collector/additions.css`, each block under its own heading comment ending `(spec 057 …)`. `spec/design_system_files_spec.rb` finds a block by its heading and counts rules up to the next heading: "spec 019" appears once, "spec 021" once, the image-fit block has no "font", the untabbed-shell block has 3 rules. A rule added without a heading is counted in the block above it (FR-4).
- No RSpec example reads a prose document (`.claude/rules/testing.md`). Document criteria are verified by reading and recorded in `docs/specs/057-deck-design-rules/verification.md`. `spec/design_system_tokens_spec.rb` reads `tokens.css`, which is code.
- Every changed area-doc line cites the spec inline ("spec 057 decision 12"). Shipped specs are not edited; supersessions are already in the spec and the index.
- A statement that only says where a rule came from ("the export's `c-stats` grid") stays as history. Where a file says an override "holds", it keeps that fact and says only that `components.css` still carries the original rule (decision 12).
- The deck vocabulary names no format and no collectible (FR-3 Must). The Charts rule and the mana rule are the spec's FR-2 text, as ruled.
- Commits: small Conventional Commits, one per task. Implementer subagents (Sonnet) end each commit message with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; the supervising session's own commits end with its own line. One git operation per shell call. Never `git push` (the supervisor does, with a CI slot).
- Run Ruby through `script/worktree/with_mise` (this shell's plain Ruby is macOS 2.6). Targeted `script/worktree/with_mise bin/rspec <file>` needs no CI slot; a full `bin/ci` does.
- Never read `.kamal/secrets`, `config/master.key`, `.env*` or `storage/`; end every `git grep` with `':!.kamal/secrets'`.
- Subagents share the worktree's test database: never run two test runs at once. The batches (see Batches) run one after another.

---

## Goal

The design system states the rules decks follow (navigation, colour and charts, the deck vocabulary, grouped pickers, the card page's stats and "In decks", Locations), ships the three bits of CSS those rules need (grouped-select labels, the location filter's 300px cap, a three-stat strip) proved in a browser, shows the rules in six updated previews, and no file tells anyone to upstream a pattern or wait for a re-export.

## File map

| File | Responsibility | Phase |
|------|----------------|-------|
| `app/views/collections/_location_select.html.erb` | One class, `c-select--wide`, on the label | 1 |
| `spec/requests/collection_location_select_spec.rb` | The label class, normal and bulk (AC-4.6) | 1 |
| `app/assets/stylesheets/collector/additions.css` | Four new blocks (grouped select, location cap, three-stat strip, the header's logo swap); three comment rewrites | 2, 3, 4, 5, 7 |
| `spec/system/design_system_deck_rules_spec.rb` (new) | AC-1.3 to 1.6, 4.2–4.4, 5.2–5.4 in headless Firefox | 2–6 |
| `spec/design_system_tokens_spec.rb` (new), `.rubocop.yml` | AC-2.3; the new spec's string describe is excluded from `RSpec/DescribeClass` | 6 |
| `spec/design_system_files_spec.rb` | One comment | 7 |
| `docs/design-system/README.md`, `components/*.md`, `.claude/skills/collector-design-system/SKILL.md`, `CLAUDE.md`, `docs/architecture/catalog-core.md`, `collection-and-lots.md` | The rules and the retired wording | 8–12 |
| `docs/design-system/previews/*.html` (six) | FR-8 | 13, 14 |
| `docs/specs/057-deck-design-rules/verification.md` (new), `docs/specs/README.md` | The record; the Plan column | 15, 16 |

## Batches

One Sonnet implementer per batch (test-first, one commit per phase), run one after another because they share the test database. The supervisor reads each batch's diff before the next starts.

| Batch | Phases | Content |
|-------|--------|---------|
| A | 0–3 | Baseline, the view class, grouped selects, the filter's cap |
| B | 4–6 | The three-stat strip, the header and tab bar guards, the contrast floor |
| C | 7–10 | Code comments, the README, the navigation docs, the mana, picker, Locations and SingleStat docs |
| D | 11–14 | The card page docs, the skill and CLAUDE.md, the re-export wording, the six previews |

The supervisor does Phases 15 and 16 (the record, the screenshots, the CI slot, the reviews).

## Pre-implementation gates

- **Simplicity:** three components (view class, four CSS blocks, documents). No new dependency. Passes.
- **Anti-abstraction:** the system spec uses Capybara, Selenium's `execute_script` and the repo's `NarrowFrame`; no new wrapper beyond four small private helpers inside the one spec file. Passes.
- **Integration-first:** the contract is the class name and the computed values in the spec's ACs; Phases 1 to 6 write the examples before the CSS they prove.

---

## Phase 0: Baseline

**Implements:** none | **Satisfies:** none
**Files:** none
**Interfaces:** Consumes: nothing. Produces: a known-green start.

- [ ] Run `script/worktree/with_mise bin/rspec spec/design_system_files_spec.rb spec/requests/collection_location_select_spec.rb spec/system/locations_spec.rb` — expect `0 failures`. If anything fails, stop and tell the supervisor; do not start Phase 1.

---

## Phase 1: The filter's label class (AC-4.6)

**Implements:** FR-4 (the one view line) | **Satisfies:** AC-4.6
**Files:** `spec/requests/collection_location_select_spec.rb`, `app/views/collections/_location_select.html.erb`
**Interfaces:** Consumes: the existing partial and the spec's helpers `select`, `start_bulk`, `blue`, `own`. Produces: the class `c-select c-select--wide` on the filter's label, which Phase 3's CSS targets.

The existing example at line 32 expects the label's class to equal exactly `"c-select"`; editing it is the first failing test. A second example covers bulk mode.

- [ ] In `spec/requests/collection_location_select_spec.rb`, change line 32 from `... to eq([ "label", "c-select", "Location" ])` to:

```ruby
      expect([ label.name, label["class"], label.at_css(".c-sr").text ]).to eq([ "label", "c-select c-select--wide", "Location" ])
```

- [ ] In the same file, in `describe "the control (AC-1.1, AC-1.5, AC-6.3)"`, after the example "shows the chosen location, in both views", add:

```ruby
    it "carries the wide modifier in bulk mode too (AC-4.6)" do
      own
      blue
      start_bulk
      expect(select.parent["class"]).to eq("c-select c-select--wide")
    end
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/requests/collection_location_select_spec.rb` — expect 2 failures (the edited example and the new one: `expected: "c-select c-select--wide"  got: "c-select"`).
- [ ] In `app/views/collections/_location_select.html.erb`, replace the file's text with:

```erb
<%# locals: (listing:, form: nil) %>
<%# The location filter (spec 037 decision 6): the design system's FilterSelect, all, none, then the account's locations.
    c-select--wide lifts its cap from 220px to 300px in a collection 640px wide or wider (spec 057 decision 4); the Set
    select on search and the Language select on number entry are c-select too and stay at 220px (decision 18). %>
<label class="c-select c-select--wide"><span class="c-sr">Location</span><%= select_tag :location,
      options_for_select([ [ "All locations", "" ], [ "No location", CollectionFilter::Place::NONE ], *listing.locations.map { [ it.name, it.id.to_s ] } ], listing.location),
      form:, id: nil %></label>
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/requests/collection_location_select_spec.rb` — expect `0 failures`.
- [ ] Commit: `feat(collection): mark the location filter c-select--wide (spec 057 AC-4.6, #248)`

---

## Phase 2: Grouped selects (AC-4.2, AC-4.3)

**Implements:** FR-4 (grouped labels and options) | **Satisfies:** AC-4.2, AC-4.3
**Files:** `spec/system/design_system_deck_rules_spec.rb` (new), `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: the real collection page; `owned_printing`, `system_sign_in_as`. Produces: the spec file's helpers `theme`, `add_to_main`, `computed`, `token`, `evaluate`, `own`, `picker` and `probe`, which Phases 3 to 5 reuse in the same file (no constants: `RSpec/LeakyConstantDeclaration` is on); the CSS block "Grouped select (spec 057)".

The picker markup (a `.c-field` select and a `.c-select` select, each with a flat option and two optgroups) is added to a real page, because no page has one yet (the deck issues build them). Computed style is read in the light and the dark theme; the theme is switched on `<html>` as `spec/support/card_images.rb` does.

- [ ] Create `spec/system/design_system_deck_rules_spec.rb`:

```ruby
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
end
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/system/design_system_deck_rules_spec.rb` — expect 4 failures (Firefox draws the group label bold italic in a system font and the default colour, and the option's background is transparent).
- [ ] In `app/assets/stylesheets/collector/additions.css`, insert the block below directly after the line `@media (pointer: coarse) { .c-select select { min-height:40px; } }` (the end of "Select inside the filter bar") and before the `/* ---------- Pagination ---------- */` heading, with one blank line either side:

```css
/* ---------- Grouped select (spec 057): optgroup labels and options, in a form and in the filter bar ---------- */
/* A group label is quiet text, not the browser's bold italic, and options keep ink on a raised ground in both themes.
   Firefox's own stylesheet gives an optgroup a system font, which the options inside it would inherit, so its size and
   family are set back to the select's with two longhands (never the shorthand, FR-4; AC-4.3). The browser or the phone
   draws the open list: this applies where it is honoured and nothing relies on it (spec 057 decision 16). */
.c-field select optgroup, .c-select select optgroup { color:var(--ink-muted); font-weight:600; font-style:normal; font-size:inherit; font-family:inherit; }
.c-field select option, .c-select select option { color:var(--ink); background:var(--surface-raised); font-weight:400; }
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/system/design_system_deck_rules_spec.rb` — expect `0 failures`. If the options' `font-size, font-family` comparison still fails, do not add a `font` shorthand: report the computed values of the select, the optgroup and the option to the supervisor.
- [ ] Run `script/worktree/with_mise bin/rspec spec/design_system_files_spec.rb` — expect `0 failures` (the guard counts the new heading as its own block).
- [ ] Commit: `feat(design-system): style the labels and options of a grouped select (spec 057 AC-4.2, AC-4.3, #248)`

---

## Phase 3: The filter's 300px cap (AC-4.4, AC-4.5)

**Implements:** FR-4 (the cap) | **Satisfies:** AC-4.4, AC-4.5
**Files:** `spec/system/design_system_deck_rules_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: Phase 1's class, Phase 2's `computed` helper, `NarrowFrame#open_in_narrow_frame` and `within_narrow_frame` (`spec/support/narrow_frame.rb`). Produces: the CSS block "Location filter cap (spec 057)".

A collection "700px wide" is made exact by setting the width of the page's own `.c-collection`, the container the rule queries, in the wide window; the phone is a 390px frame. Bulk mode is entered with `collection_path(bulk: 1)`, as `spec/system/narrow_bulk_pages_spec.rb` does.

- [ ] In the same spec file, inside the top-level `describe`, after the `grouped selects` describe, add:

```ruby
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
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/system/design_system_deck_rules_spec.rb -e "location filter's cap"` — expect 1 failure, in the 700px example (`expected: "300px"  got: "220px"`); the 390px example already passes as a control. AC-4.5 (the other selects as they are) is proved by the existing examples run in the last step of this phase and by the 700px example's Set-select line.
- [ ] In `additions.css`, insert directly after the Phase 2 block, with one blank line either side:

```css
/* ---------- Location filter cap (spec 057 decision 4): 300px from a 640px collection, 220px below ---------- */
/* At 220px a long selection clips its zone, the part that tells zones apart. On a phone the filter row scrolls sideways and
   300px would push the Filter button off screen. Only the location select carries c-select--wide; the Set select on search
   and the Language select on number entry stay at 220px (decision 18). The doubled class outranks `.c-select select` above
   whatever the order. */
@container collection (min-width: 640px) {
  .c-select.c-select--wide select { max-width:300px; }
}
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/system/design_system_deck_rules_spec.rb` — expect `0 failures`.
- [ ] Run `script/worktree/with_mise bin/rspec spec/design_system_files_spec.rb spec/system/collection_location_filter_spec.rb spec/system/catalog_search_spec.rb spec/system/number_entry_spec.rb spec/system/bulk_move_spec.rb spec/system/collection_table_fit_spec.rb` — expect `0 failures` (AC-4.5: the existing selects behave as before).
- [ ] Commit: `feat(design-system): cap the collection's location filter at 300px from a 640px collection (spec 057 AC-4.4, #248)`

---

## Phase 4: The three-stat strip (AC-5.2 to AC-5.4)

**Implements:** FR-5 (the CSS) | **Satisfies:** AC-5.2, AC-5.3, AC-5.4
**Files:** `spec/system/design_system_deck_rules_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: Phase 2's `add_to_main`, `evaluate`, `token`. Produces: the class `c-stats--three`, which the card page (#50) and `ItemPage.md` name; the CSS block "Three-stat strip (spec 057)".

The strip is added to a real page inside a `.c-page` of a fixed width: 900px, and 328px (a 360px phone less the page's two 16px gutters). `.c-page` is the container the narrow rules query.

- [ ] Add to the spec file, after the cap describe:

```ruby
  describe "the three-stat strip (AC-5.2 to AC-5.4)" do
    def three = [ [ "Owned", "7", "3 printings" ], [ "In decks", "4", "in 2 decks" ], [ "Free to use", "3", "not in a deck" ] ]
    def four = three + [ [ "Est. value", "$10.20", "updated today" ] ]

    def stat(label, value, small) = %(<div class="c-stat"><dt>#{label}</dt><dd>#{value}</dd><small>#{small}</small></div>)
    def strip(width, modifier, stats) = add_to_main(%(<div class="c-page" style="width:#{width}px"><dl class="c-stats #{modifier}" id="probe-strip">#{stats.map { stat(*it) }.join}</dl></div>))

    # Columns, each stat's width and its left and top border, whether the strip scrolls sideways and whether every
    # stat's content fits inside the stat.
    def layout
      evaluate(<<~JS)
        const strip = document.querySelector("#probe-strip")
        const stats = [ ...strip.children ]
        const border = (el, side) => getComputedStyle(el).getPropertyValue(`border-${side}-width`)
        return { columns: getComputedStyle(strip).gridTemplateColumns.split(" ").length,
                 widths: stats.map((el) => el.getBoundingClientRect().width),
                 left: stats.map((el) => border(el, "left")), top: stats.map((el) => border(el, "top")),
                 divider: getComputedStyle(stats[1]).borderLeftColor,
                 scrolls: strip.scrollWidth > strip.clientWidth, fits: stats.every((el) => el.scrollWidth <= el.clientWidth) }
      JS
    end

    before do
      own
      visit collection_path
    end

    it "is three equal columns with a 1px line divider between neighbours at 900px (AC-5.2)", :aggregate_failures do
      strip(900, "c-stats--three", three)
      found = layout
      expect(found["columns"]).to eq(3)
      expect(found["widths"].max - found["widths"].min).to be <= 1
      expect(found["left"]).to eq([ "0px", "1px", "1px" ])
      expect(found["divider"]).to eq(token("--line"))
    end

    it "stays three across at 328px, divided by left borders and none on top, without overflow (AC-5.3)", :aggregate_failures do
      strip(328, "c-stats--three", three)
      found = layout
      expect(found["columns"]).to eq(3)
      expect(found["widths"].max - found["widths"].min).to be <= 1
      expect(found["left"]).to eq([ "0px", "1px", "1px" ])
      expect(found["top"]).to eq(%w[0px 0px 0px])
      expect([ found["scrolls"], found["fits"] ]).to eq([ false, true ])
    end

    it "leaves the four-up strip two by two and the single strip one column at 328px (AC-5.4)", :aggregate_failures do
      strip(328, "", four)
      found = layout
      expect([ found["columns"], found["left"], found["top"] ]).to eq([ 2, %w[0px 1px 0px 1px], %w[0px 0px 1px 1px] ])
      visit collection_path
      strip(328, "c-stats--single", three.first(1))
      expect(layout["columns"]).to eq(1)
    end
  end
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/system/design_system_deck_rules_spec.rb -e "three-stat strip"` — expect 2 failures (the 900px and the 328px examples: `expected: 3  got: 4` and `got: 2`); the AC-5.4 example passes as a control of the rules that stay.
- [ ] In `additions.css`, insert after the card-page block's last line (`@container page (max-width: 639px) { .c-stats--single { … } }`) and before the `/* ---------- Sortable table header (spec 006)` heading, with one blank line either side:

```css
/* ---------- Three-stat strip (spec 057): the card page's Owned, In decks and Free to use ---------- */
/* Three equal columns at every width, because the labels fit at 360px. The export's narrow rules assume a two by two grid
   (no left border on the third stat, a top border from the third stat on), so the strip restates them for three. With
   "Est. value" back the page uses the plain four-up c-stats and drops this modifier (spec 057 decision 7). */
.c-stats--three { grid-template-columns:repeat(3, minmax(0, 1fr)); }
@container page (max-width: 639px) {
  .c-stats.c-stats--three { grid-template-columns:repeat(3, minmax(0, 1fr)); }
  .c-stats.c-stats--three .c-stat { padding:var(--space-3); border-top:0; }
  .c-stats.c-stats--three .c-stat + .c-stat { border-left:1px solid var(--line); }
}
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/system/design_system_deck_rules_spec.rb` — expect `0 failures`. If AC-5.3's `fits` is false (a label wider than its stat at 328px), report it to the supervisor with the measured widths: it is a design finding, not something to fix by shrinking type.
- [ ] Run `script/worktree/with_mise bin/rspec spec/design_system_files_spec.rb spec/system/card_page_spec.rb` — expect `0 failures`.
- [ ] Commit: `feat(design-system): add the three-stat strip c-stats--three (spec 057 AC-5.2 to AC-5.4, #248)`

---

## Phase 5: The header's room for five links, and five tabs (AC-1.3 to AC-1.6)

**Implements:** FR-1 (what the CSS must hold), decision 19 | **Satisfies:** AC-1.3, AC-1.4, AC-1.5, AC-1.6
**Files:** `spec/system/design_system_deck_rules_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: the app's `layouts/_appbar` and `layouts/_tabbar` as rendered, `NarrowFrame`. Produces: the fourth CSS block (the logo swap), which `AppHeader.md` and the README's Navigation section state (Phases 8, 9).

**Revised for spec 1.1.0.** The first run of this phase's header guard failed: five links overflow the app's header at 640px by 54.6px (nav 379.6px, wordmark 138px, bar padding 32px, 625px layout width with a classic scrollbar). The maintainer ruled decision 19: the logo mark replaces the wordmark from 640px to 719px while the nav holds five or more links. The header examples therefore have a real red run; the tab examples stay guards (five tabs fit at 360px with room: the widest label, "Collection", leaves 11.5px).

The Decks link and tab are cloned from Collection's in the page, so the real partials, real CSS and real fonts are measured. Each fit measure has a control: a header and a tab bar with extra items, which the same measure must report as not fitting, so the measure is shown able to fail.

The Phase 5 describe is already in the working tree, uncommitted (the implementer wrote it before the stop). Replace its three header examples with the ones below, add the `logo` helper, then follow the steps in order.

- [ ] Add to the spec file, after the stats describe:

```ruby
  describe "five header links and five tabs (AC-1.3, AC-1.4)" do
    # Clones Collection's link (or tab) `names` times, after the first, so the page has the section that #49 adds.
    def add_nav_links(*names)
      page.execute_script(<<~JS, names)
        const first = document.querySelector(".c-appbar__nav a")
        let anchor = first
        for (const name of arguments[0]) {
          const copy = first.cloneNode(true)
          copy.textContent = name
          copy.removeAttribute("aria-current")
          anchor.after(copy)
          anchor = copy
        }
      JS
    end

    def add_tabs(*names)
      page.execute_script(<<~JS, names)
        const first = document.querySelector(".c-tabbar a")
        let anchor = first
        for (const name of arguments[0]) {
          const copy = first.cloneNode(true)
          copy.lastChild.textContent = name
          copy.removeAttribute("aria-current")
          anchor.after(copy)
          anchor = copy
        }
      JS
    end

    # Link count, how many distinct tops (1 is one line), whether every link ends inside the nav, whether the nav ends
    # before the account menu starts (true by the row's own layout), whether the account menu ends inside the bar, and whether
    # the page scrolls sideways. Extra links push the account menu out of the bar, which is what the control looks for.
    def header_fit
      evaluate(<<~JS)
        const nav = document.querySelector(".c-appbar__nav"), box = nav.getBoundingClientRect()
        const links = [ ...nav.querySelectorAll("a") ]
        const actions = document.querySelector(".c-appbar__actions").getBoundingClientRect()
        const bar = document.querySelector(".c-appbar"), barStyle = getComputedStyle(bar)
        const barEnd = bar.getBoundingClientRect().right - parseFloat(barStyle.paddingRight)
        return { links: links.length, lines: new Set(links.map((el) => Math.round(el.getBoundingClientRect().top))).size,
                 inside: links.every((el) => el.getBoundingClientRect().right <= box.right + 0.5),
                 beforeAccount: box.right <= actions.left, accountInside: actions.right <= barEnd + 0.5,
                 scrolls: document.documentElement.scrollWidth > window.innerWidth }
      JS
    end

    # Tab count, whether the last tab ends inside the bar, whether the bar scrolls sideways, and whether each tab's
    # label fits inside its tab (the bar is fixed, so page overflow alone can't see it overflow).
    def tabbar_fit
      evaluate(<<~JS)
        const bar = document.querySelector(".c-tabbar"), box = bar.getBoundingClientRect()
        const tabs = [ ...bar.querySelectorAll("a") ]
        const label = (tab) => { const range = document.createRange(); range.selectNodeContents(tab.lastChild); return range.getBoundingClientRect().width }
        return { tabs: tabs.length, lastInside: tabs.at(-1).getBoundingClientRect().right <= box.right + 0.5,
                 scrolls: bar.scrollWidth > bar.clientWidth, labelsFit: tabs.every((tab) => label(tab) <= tab.clientWidth) }
      JS
    end

    def header_fits?(found) = found["lines"] == 1 && found["inside"] && found["beforeAccount"] && found["accountInside"] && !found["scrolls"]

    # Which logo the header draws: whether the wordmark and the mark are displayed (decision 19).
    def logo
      evaluate(<<~JS)
        const shown = (selector) => getComputedStyle(document.querySelector(selector)).display !== "none"
        return { wordmark: shown(".c-appbar__wordmark"), mark: shown(".c-appbar__mark") }
      JS
    end

    [ 640, 719 ].each do |width|
      it "fits five links before the account menu, with the mark for the wordmark, at #{width}px (AC-1.3)", :aggregate_failures do
        open_in_narrow_frame(collection_path, width:, ready: ".c-appbar__nav", height: 1200)
        within_narrow_frame do
          add_nav_links("Decks")
          found = header_fit
          expect(found["links"]).to eq(5)
          expect(header_fits?(found)).to be(true)
          expect(logo).to eq("wordmark" => false, "mark" => true)
        end
      end
    end

    it "fits five links with the wordmark at 720px, where the swap ends (AC-1.5)", :aggregate_failures do
      open_in_narrow_frame(collection_path, width: 720, ready: ".c-appbar__nav", height: 1200)
      within_narrow_frame do
        add_nav_links("Decks")
        found = header_fit
        expect(found["links"]).to eq(5)
        expect(header_fits?(found)).to be(true)
        expect(logo).to eq("wordmark" => true, "mark" => false)
      end
    end

    it "keeps the wordmark for today's four links at 640px (AC-1.6)", :aggregate_failures do
      open_in_narrow_frame(collection_path, width: 640, ready: ".c-appbar__nav", height: 1200)
      within_narrow_frame do
        expect(header_fit["links"]).to eq(4)
        expect(logo).to eq("wordmark" => true, "mark" => false)
      end
    end

    it "reports a header with five more links as not fitting (the measure can fail)" do
      open_in_narrow_frame(collection_path, width: 640, ready: ".c-appbar__nav", height: 1200)
      within_narrow_frame do
        add_nav_links("Decks", "Wishlist", "Recently viewed", "Price alerts", "Trade binder")
        expect(header_fits?(header_fit)).to be(false)
      end
    end

    it "keeps five tabs inside the bar, each label inside its tab, at 360px (AC-1.4)", :aggregate_failures do
      open_in_narrow_frame(collection_path, width: 360, ready: ".c-tabbar")
      within_narrow_frame do
        add_tabs("Decks")
        found = tabbar_fit
        expect([ found["tabs"], found["lastInside"], found["scrolls"], found["labelsFit"] ]).to eq([ 5, true, false, true ])
      end
    end

    it "reports a tab bar with four more tabs as not fitting (the measure can fail)" do
      open_in_narrow_frame(collection_path, width: 360, ready: ".c-tabbar")
      within_narrow_frame do
        add_tabs("Decks", "Wishlist", "Collections", "Trades")
        found = tabbar_fit
        expect(found.values_at("lastInside", "scrolls", "labelsFit")).not_to eq([ true, false, true ])
      end
    end
  end
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/system/design_system_deck_rules_spec.rb -e "five links" -e "five tabs"` and confirm the red run: the two AC-1.3 examples (640px and 719px) fail (`header_fits?` false: the account menu overhangs; `logo` shows the wordmark); the AC-1.5, AC-1.6, AC-1.4 examples and the two controls pass. Record the failing example names and the measured overhang. If anything else fails (for example AC-1.5 at 720px: the five links and the wordmark do not fit there), stop and report the numbers; do not change the 719/720 boundary.
- [ ] Add the fourth block to `app/assets/stylesheets/collector/additions.css`, after the three-stat strip block (its own heading, so the guard spec's block counts stay as they are):

```css
/* ---------- Header room for five links (spec 057 decision 19): the logo mark stands in for the wordmark from 640px to 719px ---------- */
/* With five links the header overflows from 640px (the account menu ends 54.6px past the bar), and five links plus the wordmark
   first fit at a 695px viewport; the mark leaves room until 720px. It applies only while the nav holds five or more links, so
   today's four-link header keeps its wordmark. The two declarations are the phone rule's in components.css. */
@media (min-width: 640px) and (max-width: 719px) {
  .c-appbar:has(.c-appbar__nav > :nth-child(5)) .c-appbar__brand .c-appbar__wordmark { display:none; }
  .c-appbar:has(.c-appbar__nav > :nth-child(5)) .c-appbar__brand .c-appbar__mark { display:block; }
}
```

- [ ] Run the same command and `script/worktree/with_mise bin/rspec spec/design_system_files_spec.rb` — expect `0 failures` for both (the new block has its own heading, "spec 057" appears in several headings, and none of the guarded blocks changed).
- [ ] Commit: `feat(design-system): the logo mark stands in for the wordmark when the header holds five links (spec 057 decision 19, AC-1.3 to AC-1.6, #248)`

---

## Phase 6: The contrast floor (AC-2.3)

**Implements:** FR-2 (the 3:1 floor of the Charts rule) | **Satisfies:** AC-2.3
**Files:** `spec/design_system_tokens_spec.rb` (new)
**Interfaces:** Consumes: `app/assets/stylesheets/collector/tokens.css`. Produces: nothing for later phases.

The ratios are WCAG's, computed from the sRGB hex values, unrounded. Three blocks of `tokens.css` carry the colours: the light block, the dark block and the dark-by-preference block. The lowest pair today is `line-strong` on the light `surface-sunken`, 3.010:1, so the floor is 3.0 exactly with no rounding. A control example feeds the same check a block with a lowered `line-strong` and expects it to be flagged.

- [ ] Create `spec/design_system_tokens_spec.rb`:

```ruby
require "rails_helper"

# Spec 057 AC-2.3: the Charts rule says fills and outlines hold 3:1 against the ground they sit on. The two tokens a chart
# draws with (`ink-muted` for fills, `line-strong` for outlines and hatching) are compared with the three surfaces in each
# block of tokens.css that defines colours, unrounded. A token change that breaks the floor fails here. tokens.css is
# code (generated from tokens.json); the design system's prose is not read by RSpec (.claude/rules/testing.md).
RSpec.describe "Design system tokens: the contrast floor (spec 057 AC-2.3)" do
  let(:css) { Rails.root.join("app/assets/stylesheets/collector/tokens.css").read }

  # The three blocks that define colours: the light one, the dark one and the dark one the OS preference selects.
  def block(name)
    pattern = {
      "light" => /^:root, \[data-theme="light"\] \{(.*?)^\}/m,
      "dark" => /^\[data-theme="dark"\] \{(.*?)^\}/m,
      "dark by preference" => /^  :root:not\(\[data-theme\]\) \{(.*?)^  \}/m
    }.fetch(name)
    css[pattern, 1]
  end

  def colours(text) = text.scan(/--([a-z-]+):\s*(#\h{6})\b/).to_h
  def linear(channel) = channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4

  def luminance(hex)
    red, green, blue = hex.delete("#").scan(/../).map { linear(it.to_i(16) / 255.0) }
    0.2126 * red + 0.7152 * green + 0.0722 * blue
  end

  def ratio(one, other)
    light, dark = [ luminance(one), luminance(other) ].max, [ luminance(one), luminance(other) ].min
    (light + 0.05) / (dark + 0.05)
  end

  # Every [drawn token, surface, ratio] in one block's colours that is under 3:1.
  def below_floor(palette)
    %w[ink-muted line-strong].product(%w[surface surface-raised surface-sunken])
      .map { |drawn, surface| [ drawn, surface, ratio(palette.fetch(drawn), palette.fetch(surface)) ] }
      .select { |_drawn, _surface, value| value < 3.0 }
  end

  it "computes WCAG's contrast ratio", :aggregate_failures do
    expect(ratio("#000000", "#ffffff")).to be_within(0.001).of(21.0)
    expect(ratio("#777777", "#ffffff")).to be_within(0.01).of(4.48)
  end

  [ "light", "dark", "dark by preference" ].each do |name|
    it "holds 3:1 for ink-muted and line-strong on every surface in the #{name} block", :aggregate_failures do
      expect(block(name)).to be_present
      expect(below_floor(colours(block(name)))).to be_empty
    end
  end

  it "finds the lowest pair, line-strong on the light surface-sunken, at 3.010:1" do
    palette = colours(block("light"))
    expect(ratio(palette.fetch("line-strong"), palette.fetch("surface-sunken"))).to be_within(0.001).of(3.010)
  end

  it "flags a token that falls under the floor (the check can fail)" do
    palette = colours(block("light")).merge("line-strong" => "#b0a898")
    expect(below_floor(palette).map(&:first)).to include("line-strong")
  end
end
```

- [ ] Add the new file to the string-describe exclusions in `.rubocop.yml`: under `RSpec/DescribeClass:` `Exclude:`, add the line `    - "spec/design_system_tokens_spec.rb"` next to `    - "spec/design_system_files_spec.rb"` (a describe of the tokens file is no class, as the other design-system spec's is not), and give it its reason in the comment block above `RSpec/DescribeClass`: change that block's last line `# the shell scripts' pipes (#217).` to `# the shell scripts' pipes (#217). The design-system tokens spec checks the colours in tokens.css, a stylesheet (spec 057 AC-2.3).`
- [ ] Run `script/worktree/with_mise bin/rspec spec/design_system_tokens_spec.rb` — expect `0 failures`. This is a guard on values that already hold, so it has no red run of its own; the control example proves the check can fail. If the `be_within(0.001).of(3.010)` example fails, record the measured value and tell the supervisor (the spec states 3.010:1) before changing the expectation.
- [ ] Run `script/worktree/with_mise bin/rubocop spec/design_system_tokens_spec.rb spec/system/design_system_deck_rules_spec.rb` — expect no offenses; fix any with `bin/rubocop -a` through `script/worktree/with_mise`.
- [ ] Commit: `test(design-system): guard the 3:1 floor of ink-muted and line-strong (spec 057 AC-2.3, #248)`

---

## Phase 7: Retire the re-export wording in code comments (AC-7.3)

**Implements:** FR-7 (the comments) | **Satisfies:** AC-7.3 (additions.css, the guard spec)
**Files:** `app/assets/stylesheets/collector/additions.css`, `spec/design_system_files_spec.rb`
**Interfaces:** Consumes: the guard spec's block finder. Produces: comments that say only where a rule came from.

The guard spec already protects these blocks: before and after the edit it must pass unchanged. Edit only the comment text, never a rule, and keep "spec 019" once, "spec 021" once and the word "font" out of the image-fit block.

- [ ] Run `script/worktree/with_mise bin/rspec spec/design_system_files_spec.rb` — expect `0 failures` (before).
- [ ] In `additions.css`, replace lines 1–2:

```css
/* Collector app additions: patterns the export lacks (spec 004 FR-11), built only on tokens.
   Documented in docs/design-system/components/; upstream them into the published design system. */
```

  with:

```css
/* Collector app additions: the project's own patterns on top of the export's components (spec 004 FR-11, spec 057
   decision 12), built only on tokens. Documented in docs/design-system/components/. */
```

- [ ] In the image-fit block, replace the comment

```css
/* Overrides the export until the published design system fits images this way; then delete this block. Any leftover
   shows the slot's surface-sunken ground. */
```

  with:

```css
/* Overrides the export's crop and stretch, which components.css still carries; this block is the rule (spec 057
   decision 12). Any leftover shows the slot's surface-sunken ground. */
```

- [ ] In the unowned-tile block, replace the comment's first two lines

```css
/* Overrides the export, which fades the image and the missing-image fallback to 45%; once an export drops that fade,
   delete the first rule. The marker is a c-tag on a second c-tile__meta row, so the tile is one line taller: the add
```

  with:

```css
/* Overrides the export, which fades the image and the missing-image fallback to 45% and still carries that rule; the
   first rule here is what applies (spec 057 decision 12). The marker is a c-tag on a second c-tile__meta row, so the
   tile is one line taller: the add
```

  (the following lines of the comment, "control goes to the foot of its cell and a row that mixes owned and unowned tiles keeps its buttons level. */", stay as they are).
- [ ] In `spec/design_system_files_spec.rb`, replace the two comment lines 48–49

```ruby
      # Comments are dropped first, so only a rule's own declarations are read. The first of the two is the export's
      # (components.css); an export that drops the fade removes it, and this expectation is edited then.
```

  with:

```ruby
      # Comments are dropped first, so only a rule's own declarations are read. The first of the two is the export's
      # (components.css), which still carries the fade; the second is the override that applies (spec 057 decision 12).
```

- [ ] Run `script/worktree/with_mise bin/rspec spec/design_system_files_spec.rb spec/system/unowned_tile_spec.rb spec/system/card_image_fit_spec.rb` — expect `0 failures` (after).
- [ ] Run `git grep -n -i -e "upstream" -e "re-export" -e "published design system" -e "an export that" -- app/assets/stylesheets spec/design_system_files_spec.rb ':!.kamal/secrets'` — expect no output.
- [ ] Commit: `docs(design-system): retire the re-export wording in additions.css and its guard spec (spec 057 AC-7.3, #248)`

---

## Phase 8: README (FR-1, FR-2, FR-3, FR-7)

**Implements:** FR-1, FR-2, FR-3, FR-7 | **Satisfies:** AC-1.1, AC-2.1 (README half), AC-2.2, AC-2.4, AC-3.1, AC-3.2 (README half), AC-7.2
**Files:** `docs/design-system/README.md`
**Interfaces:** Consumes: the spec's FR-1, FR-2, FR-3, FR-7 text. Produces: the README sections that the component docs (Phases 9 to 11) and the previews (Phases 13, 14) agree with: "Decks" section, Navigation, Color rules, Components ownership.

There is no test for a prose document (`.claude/rules/testing.md`); the check is reading, recorded in `verification.md` (Phase 15). Edit by the quoted text, not by line number. After each edit, read the changed lines back.

- [ ] **Who it's for.** Replace the whole bullet that begins `- A physical copy is in exactly one place at a time. A deck is a location like a binder or a box,` with:

```markdown
- A physical copy is in exactly one place at a time. A deck is a kind of location whose copies live in its zones, so a copy in a deck is not free for another deck; the Decks section below defines the words, "Free to use" among them. (Digital decks that share cards may come later; when they do, their cards are labelled as such and never count against physical copies.)
```

- [ ] **Color, text contrast.** In the bullet that begins `- Text is \`ink\`; secondary text and metadata are \`ink-muted\`.`, replace `(≥6:1)` with `(5.5:1 or better)`.
- [ ] **Color, status then mana then charts.** After the bullet that begins ``- `success`, `warning`, `danger` are status only`` insert these two bullets (the FR-2 text, verbatim):

```markdown
- **Mana colours.** The `mana-*` colours are data colours, used only to show mana: the `ManaCost` pips and charts of mana symbols. The fills stay apart from `success`, `warning` and `danger` and are the same in both themes. The letter or number always shows, and every use has a 1px `line-strong` outline.
- **Charts.** Fills are neutral: `ink-muted` for the main series, a hatched `line-strong` fill with an `ink-muted` outline for a second series stacked on it; never `brand` (brand means an action) and never a status colour. Every column or segment carries a word or a number (a count above a column; a letter and count in a segment; a segment too narrow for its label shows them in the caption beneath), and a legend or caption names each series, so colour or pattern is never the only signal. The chart is `role="img"` with an `aria-label` that reads the values. Fills and outlines hold 3:1 against the ground they sit on. A chart of mana symbols may use the `mana-*` fills, each with a 1px `line-strong` outline, and a divider between segments, because the white and black fills disappear on the light and dark ground.
```

  Leave the Voice section's line "Never use a game's … mana symbols … as UI decoration" as it is.
- [ ] **Navigation.** Replace the whole first bullet, which reads in full `- The default sections, in this order: Collection, Decks, Locations, Wishlist (today's header for a collector links Collection, Search, Scan and Locations, spec 029; Decks and Wishlist don't exist yet). Each collector will be able to choose and reorder their own sections; design for any four, and never hard-code a section's position. Wide screens show them in the \`AppHeader\`; phones show them in a native-style bottom \`TabBar\` with a fifth tab, More.`, with:

```markdown
- A collector's wide header, in order: Collection, Decks, Search, Scan, Locations. The phone tab bar, in order: Collection, Decks, Search, Scan, More; Locations stays in More. Each collector will later be able to choose and reorder their own sections, so never hard-code a section's position. Wishlist is planned. Decks joins the header and the tab bar when the deck pages ship (today's header for a collector links Collection, Search, Scan and Locations, spec 029); the order is the rule for both from then on (spec 057 decision 6). Wide screens show the sections in the `AppHeader`; phones show them in a native-style bottom `TabBar` with More as its fifth tab.
```

  Replace the bullet `- The tab bar holds five tabs at most. A new section starts in More.` with `- The tab bar holds five tabs at most and is now full (Collection, Decks, Search, Scan, More): a new section starts in More.` Then add one bullet after it: `- With five links the header has no room for the wordmark between 640px and 719px: the logo mark stands in for it there, while the nav holds five or more links, and the wordmark returns from 720px (spec 057 decision 19).` Keep the bullets on the avatar menu / More and on `c-appbar--detail` and the shell's 640px as they are.
- [ ] **Decks section.** After the Navigation section's last bullet and before `## Components`, insert:

```markdown
## Decks

The words every deck screen uses (spec 057 FR-3). They name no format and no collectible; a deck's formats and zones are defined where decks are built.

- **Deck:** a kind of location. Its copies live in its zones.
- **Zone:** a named part of a deck, such as Main or Sideboard. Which zones a deck has depends on its format; every deck has Considering.
- **Considering:** the zone for cards you are thinking about. Copies there are in the deck.
- **Proxy:** a stand-in for a card you do not own, recorded against a deck zone with a printing. A proxy never counts as owned; it is not in Owned, In decks or Free to use.
- **"Deck › Zone":** how a zone is named wherever a place is shown or chosen (tiles, rows, pickers): the deck's name, a single right angle quote (›), the zone's name. A zone is never shown without its deck.
- **Free to use:** copies you own minus copies in any deck zone, Considering included. Proxies don't change it.
- **Places:** your locations that are not decks (a binder, a box). "Places" is the picker's group label; the page is still "Locations".
```

- [ ] **Components, ownership.** After the bullet `- Build new components from these before inventing new styles; a new pattern gets its own entry here first.` add:

```markdown
- The design system is the project's own, in code (spec 057 decision 12). A new pattern goes in `collector/additions.css`, with a doc under `components/` and a line in the App additions list below; a rule changes in this README, in the same change as the code.
```

- [ ] **App additions lines.** In each of the 14 `App additions (spec …)` lines, delete the sentence ` Upstream these into the published design system before the next export replaces this folder.` and its variants (`Upstream it into …`, `Upstream them into …`), leaving the rest of the line. Do it with one substitution run through Python, then check the count:

  Write `/private/tmp/claude-501/-Users-james-orca-workspaces-Collector-deck-design-rules/ec07c470-c507-4b98-907e-1884affc6f7c/scratchpad/readme_upstream.py` (a path outside the worktree; the shell's `ruby` is not used):

```python
import re
path = "/Users/james/orca/workspaces/Collector/deck-design-rules/docs/design-system/README.md"
text = open(path).read()
pattern = re.compile(r" Upstream (?:these|it|them) into the published design system before the next export replaces this folder\.")
text, count = pattern.subn("", text)
assert count == 14, count
open(path, "w").write(text)
print("removed", count)
```

  Run `python3 -I /private/tmp/claude-501/-Users-james-orca-workspaces-Collector-deck-design-rules/ec07c470-c507-4b98-907e-1884affc6f7c/scratchpad/readme_upstream.py` — expect `removed 14`.
- [ ] **Fifteenth line.** After the spec 048 line (the last `App additions` line), with a blank line between, add:

```markdown
App additions (spec 057, in `collector/additions.css`): the label and option rules of a grouped select (documented in `Form` and `FilterSelect`), `c-select--wide` (`FilterSelect`), `c-stats--three` (`ItemPage`) and the logo mark's stand-in for the wordmark from 640px to 719px while the header holds five links (`AppHeader`).
```

- [ ] Read back: `git grep -n -i -e "upstream" -e "re-export" -e "replaced wholesale" -e "before the next export" -e "published design system" -e "Wishlist" -e "≥6:1" -- docs/design-system/README.md ':!.kamal/secrets'` — expect only: the Wishlist-is-planned sentence in Navigation, and no other line.
- [ ] Commit: `docs(design-system): README gains the Decks vocabulary, the Charts and mana rules, the new navigation and its own ownership (spec 057 FR-1 to FR-3, FR-7, #248)`

---

## Phase 9: Navigation component docs (FR-1)

**Implements:** FR-1 | **Satisfies:** AC-1.2
**Files:** `docs/design-system/components/AppHeader.md`, `TabBar.md`, `MorePage.md`
**Interfaces:** Consumes: Phase 8's Navigation bullet (the order). Produces: the markup `TabBar.md` shows, which the previews (Phase 13) copy.

Each doc says the same order as the README. Read each file before editing; keep every rule about height, sticky, the current tab and 56px tabs as it is (FR-1 Must not).

- [ ] `AppHeader.md`: replace the two bullets that begin `- Default sections: Collection, Decks, Locations, Wishlist.` and `- The collector's links today are Collection, Search, Scan and Locations, in that order (spec 029);` with:

```markdown
- Sections, in order for a collector: Collection, Decks, Search, Scan, Locations (spec 057 decision 6). Collectors will be able to choose and reorder them later; whatever they pick appears in the same order in the `TabBar` on phones, so the app has one navigation model at every width. Wishlist is planned.
- Today's header links Collection, Search, Scan and Locations, in that order (spec 029); Decks joins after Collection when the deck pages ship. At 640px, where the nav first appears, the five links share one line with the account menu (`spec/system/design_system_deck_rules_spec.rb` measures it with Decks added).
- With five links there is no room for the wordmark from 640px to 719px, so the logo mark replaces it there while the nav holds five or more links, and the wordmark shows from 720px (spec 057 decision 19; today's four-link header keeps the wordmark).
```

- [ ] `TabBar.md`: in the first paragraph replace `four sections (the collector's choice; Collection, Decks, Locations and Wishlist by default) and More.` with `four sections (Collection, Decks, Search and Scan, in that order; Locations stays in More) and More. The five tabs are full: a new section starts in More. Collectors will later be able to choose and reorder their sections (spec 057 decision 6).` In the markup block, keep the Collection, Decks and More tabs as they are (Decks' own markup line is replaced in the next step) and replace the `<a href="/locations">…Locations</a>` and `<a href="/wishlist">…Wishlist</a>` lines with:

```html
  <a href="/catalog/entries"><span class="c-tabbar__icon"><svg …/></span>Search</a>
  <a href="/scanner"><span class="c-tabbar__icon"><svg …/></span>Scan</a>
```

  (use the exact indentation of the neighbouring lines; the `…` stays as in the Collection and More tabs). Keep the sentence about More opening a full page.
- [ ] `TabBar.md`, the Decks icon (spec 057 decision 5): in the markup block replace the Decks line's `<svg …/>` with the design system's own icon, the one the `TabBar` preview and the card page's "Add to deck" button use, so the document shows it:

```html
  <a href="/decks"><span class="c-tabbar__icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" aria-hidden="true"><rect x="8" y="3" width="12" height="16" rx="2"/><path d="M5 7v12a2 2 0 0 0 2 2h9"/></svg></span>Decks</a>
```

  and add this bullet after "Labels always show; icons alone are not enough.": `- Decks' icon is the design system's own, a card and the one behind it, the same as the card page's "Add to deck" button, so one icon means deck everywhere (spec 057 decision 5).`
- [ ] `MorePage.md`: in the bullet that begins `- Locations comes right after "Signed in as" and opens the locations page (spec 029);` replace `it is a section, so on phones it starts in More and the tab bar doesn't change.` with `it is a section, and it stays in More because the tab bar's fifth tab is More and its five tabs are full: Collection, Decks, Search, Scan, More (spec 057 decision 6).`
- [ ] Read back: `git grep -n -i -e "wishlist" -e "four links" -e "tab bar doesn't change" -- docs/design-system/components/AppHeader.md docs/design-system/components/TabBar.md docs/design-system/components/MorePage.md ':!.kamal/secrets'` — expect only the "Wishlist is planned" sentence in `AppHeader.md`.
- [ ] Commit: `docs(design-system): AppHeader, TabBar and MorePage say the new section order (spec 057 FR-1, #248)`

---

## Phase 10: Mana, pickers, Locations and SingleStat docs (FR-2, FR-4, FR-5, FR-6)

**Implements:** FR-2 (ManaCost), FR-4 (docs), FR-5 (SingleStat), FR-6 | **Satisfies:** AC-2.1 (ManaCost half), AC-4.1, AC-5.5, AC-6.1
**Files:** `docs/design-system/components/ManaCost.md`, `Form.md`, `FilterSelect.md`, `SingleStat.md`, `Locations.md`
**Interfaces:** Consumes: Phase 2 to 4's class names (`c-select--wide`, `c-stats--three`). Produces: the picker rules #252 builds from.

- [ ] `ManaCost.md`: in the bullet that begins `- **Colours**:`, replace `identical in both themes, and are never used anywhere else in the UI.` with `identical in both themes. They are data colours, used only to show mana: these pips and charts of mana symbols (the README's Charts rule). They stay apart from \`success\`, \`warning\` and \`danger\`; the letter or number always shows, and every use has a 1px \`line-strong\` outline (spec 057 FR-2).`
- [ ] `Form.md`: add this bullet to the select's notes (next to the bullets about a required select's "Choose…" and an optional one's "Not specified", which stay):

```markdown
- **Location picker (spec 057 decisions 2, 3, 15).** With no deck in the account the picker is flat: "No location", then the places. With a deck: "No location", then an `optgroup` "Places", then an `optgroup` "Decks" whose options are written "Deck › Zone" (the README's Decks section). A group with nothing in it is omitted: decks and no places give "No location" then "Decks". The group labels are `ink-muted`, weight 600, not italic, and options are `ink` on `surface-raised` in both themes (`optgroup` and `option` rules in `collector/additions.css`). The browser or the phone draws the open list: Firefox on a desktop honours the styling, native menus honour less or none of it, and nothing depends on it (decision 16). The select stays native: no script, no custom list.
```

- [ ] `FilterSelect.md`: replace the bullet `- It is at most 220px wide; long option names are clipped by the browser, never wrapped.` with:

```markdown
- It is at most 220px wide; long option names are clipped by the browser, never wrapped. The one exception is the collection's location filter, whose label also carries `c-select--wide`: its cap is 300px when the collection is 640px wide or wider (so a zone, the part that tells zones apart, shows) and 220px below that, where the filter row scrolls sideways. The Set select on search and the Language select on number entry stay at 220px (spec 057 decisions 4, 18).
- When the account has a deck, the location filter lists "All locations" and "No location" first, outside any group, then an `optgroup` "Places", then an `optgroup` "Decks". Inside "Decks" each deck has one option "<Deck> (all zones)" first, then its zones written "Deck › Zone" (spec 057 decisions 2, 3, 15). With no deck it is flat, as it is today. The group and option styling is the same as `Form`'s, and the browser draws the open list.
```

- [ ] `SingleStat.md`: add as the last bullet: `- For three stats use \`c-stats c-stats--three\` instead (three equal columns at every width; see \`ItemPage\`).`
- [ ] `Locations.md`: add this bullet directly after the bullet that begins `- The list is in the order of the names' comparison key`:

```markdown
- The page lists places only: locations that are not decks. Its count counts places only. Decks live on their own page (Decks, with its own header link and tab) and appear in every location picker; the Locations page carries no pointer to Decks (spec 057 decision 11).
```

- [ ] Read back: `git grep -n -e "never used anywhere else" -- docs/design-system/components ':!.kamal/secrets'` — expect no output.
- [ ] Commit: `docs(design-system): the mana rule, grouped pickers, the filter's cap, three stats and Locations (spec 057 FR-2, FR-4 to FR-6, #248)`

---

## Phase 11: The card page, the skill and CLAUDE.md (FR-3, FR-5, FR-7)

**Implements:** FR-3, FR-5, FR-7 | **Satisfies:** AC-3.2 (ItemPage and SKILL), AC-5.1, AC-7.1
**Files:** `docs/design-system/components/ItemPage.md`, `ItemPagePhone.md`, `.claude/skills/collector-design-system/SKILL.md`, `CLAUDE.md`
**Interfaces:** Consumes: the vocabulary of Phase 8. Produces: the card page rules #50 and #254 build from; the structure the previews of Phase 14 show.

- [ ] `ItemPage.md`, markup block: change `<dl class="c-stats">…Owned, In decks, Free to use, Est. value…</dl>` to `<dl class="c-stats c-stats--three">…Owned, In decks, Free to use…</dl>`, and replace the line `<div class="c-split"><section>…In decks (c-list)…</section><section>…Format legality (c-legality)…</section></div>` with two lines, in section order after Printings:

```html
        <section>…In decks (c-table in .c-collection: Deck, Zone, Owned, Proxy)…</section>
        <section>…Format legality (c-legality)…</section>
```

- [ ] `ItemPage.md`, notes: replace the sentence `**Order of sections** (most-used first): stats, your copies, printings, decks, legality.` with `**Order of sections** (most-used first): stats, your copies, printings, in decks, format legality.` and keep the rest of that bullet. Replace the whole `- **Stats** answer the player's question first: …` bullet with:

```markdown
- **Stats** answer the player's question first, three across at every width (`c-stats c-stats--three`): Owned ("N printings"), In decks ("in N decks") and Free to use ("not in a deck"). Free to use is the copies you own minus the copies in any deck zone, Considering included. A proxy never counts in Owned, In decks or Free to use (the README's Decks section). Est. value waits for prices: when it returns, the strip is the plain four-up `c-stats` again (spec 057 decisions 7, 8).
```

  Replace the whole `- **In decks** names each deck, its format and board, and how many copies it uses.` bullet with:

```markdown
- **In decks** is a full-width section after Printings, with Format legality below it. It is `CollectionTable`'s pattern (a `c-table` in `.c-collection`, numeric cells `is-num`): columns Deck (the deck's name as `TableItemLink` documents, its format muted beside it), Zone, Owned and Proxy. Owned counts the copies in that zone and Proxy the proxies in it; the Proxy column is always shown, with a muted dash for none. On a phone Zone folds under the deck name with the format (`c-table__sub`), as in the other tables. No new CSS (spec 057 decision 8).
```

- [ ] `ItemPagePhone.md`: replace the line `- Stats become a 2 × 2 grid.` with `- The stats stay three across (\`c-stats--three\`), divided by left borders; the labels fit at 360px (spec 057 decision 7).` and replace the line `- Decks and legality stack instead of sitting side by side.` with `- In decks is the full-width table with Zone folded under the deck name and the format (\`c-table__sub\`); Format legality follows it (spec 057 decision 8).`
- [ ] `ItemPage.md`, Your copies: replace `A deck is a location, so copies in a deck appear here with the deck's name.` with `A deck is a location, so copies in a deck appear here, the place written Deck › Zone (the README's Decks section).`
- [ ] `.claude/skills/collector-design-system/SKILL.md`: replace the line `- A physical copy is in one place at a time; a deck is a location. "Free to use" = owned − in decks.` with `- A physical copy is in one place at a time; a deck is a location with zones that holds the copies it uses. "Free to use" = owned − copies in any deck zone (Considering included); a proxy never counts. The README's Decks section has the words.`
- [ ] `CLAUDE.md`, "UI and design system": replace the sentence `The export's files (\`tokens.css\`, \`components.css\`, fonts, logos, \`docs/design-system/\`) are replaced wholesale by re-exporting the published design system; app-specific patterns live in \`collector/additions.css\` with a doc per pattern under \`docs/design-system/components/\`.` with `The design system is the project's own, in code: new patterns go in \`collector/additions.css\` with a doc per pattern under \`docs/design-system/components/\`, and a rule changes in \`docs/design-system/README.md\`.`
- [ ] Read back: `git grep -n -i -e "owned minus in decks" -e "location like a binder" -e "replaced wholesale" -- CLAUDE.md .claude/skills docs/design-system ':!.kamal/secrets'` — expect no output.
- [ ] Commit: `docs(design-system): the card page's three stats and In decks table; the skill and CLAUDE.md follow the vocabulary and the ownership rule (spec 057 FR-3, FR-5, FR-7, #248)`

---

## Phase 12: Retire the re-export wording in component and area docs (FR-7)

**Implements:** FR-7 | **Satisfies:** AC-7.3 (docs), AC-7.4 (part)
**Files:** `docs/design-system/components/ImageFit.md`, `UnownedTile.md`, `ItemTile.md`, `docs/architecture/catalog-core.md`, `docs/architecture/collection-and-lots.md`
**Interfaces:** Consumes: nothing. Produces: files whose remaining mentions of the export say only where a rule came from.

Read each line before replacing it; the replacements keep the facts and drop the instruction or expectation. Each area-doc line cites spec 057 decision 12 inline.

- [ ] `ImageFit.md`: first paragraph, replace `It overrides the export until the published design system fits images this way.` with `It overrides the export's image rules.` Replace the bullet that begins `- This overrides the export, whose` with: `- This overrides the export, whose \`c-tile__media\` and \`c-item__image\` crop with \`cover\` and whose \`c-table__thumb\` stretches the image to its box; \`components.css\` still carries those rules, and the block in \`collector/additions.css\` is what applies. The design system is the project's own, so the block stays (spec 057 decision 12).`
- [ ] `UnownedTile.md`: keep the first paragraph (it says where the override came from). Replace the bullet that begins `- This overrides the export: \`components.css\` still carries` with: `- This overrides the export: \`components.css\` still carries \`.c-tile--owned-none .c-tile__media > img, .c-tile--owned-none .c-tile__missing { opacity:.45; }\`, and this rule is what applies. Where this document differs from \`ItemTile.md\`, this one holds, and \`ItemTile.md\` points here. \`spec/design_system_files_spec.rb\` has two examples for this block (one pins the \`opacity:.45\` that \`components.css\` still carries) and \`spec/system/unowned_tile_spec.rb\` the browser examples (spec 057 decision 12).`
- [ ] `ItemTile.md`: in the **Modifiers** paragraph replace `\`c-tile--owned-none\` fades an item you don't own (wishlist, set checklist).` with `\`c-tile--owned-none\` marks a card you don't own (search results, a card's printings, a set checklist): its image stays as supplied and a "Not owned" tag sits under it; see \`UnownedTile\` (spec 057 decision 12).`
- [ ] `catalog-core.md` line "A card image is shown whole…": replace `and the rule is held where a re-export of the design system can't undo it (spec 019 FR-1–FR-3, Goals).` with `and the rule is a block of its own in \`additions.css\` (spec 019 FR-1–FR-3, Goals; spec 057 decision 12).`
- [ ] `catalog-core.md` paragraph "A card image fits its slot…": replace `The export's \`components.css\` crops with \`cover\` and stretches the thumbnail; the override lives in \`additions.css\`, in one block headed with spec 019, so a re-export can't undo it (spec 019 decision 1, FR-3, AC-4.3, AC-4.4).` with `The export's \`components.css\` crops with \`cover\` and stretches the thumbnail, and still carries those rules; the override lives in \`additions.css\`, in one block headed with spec 019, guarded by \`spec/design_system_files_spec.rb\` (spec 019 decision 1, FR-3, AC-4.3, AC-4.4; spec 057 decision 12).`
- [ ] `catalog-core.md` decision bullet: replace `- **Images fit by an override, not a re-export, and slots keep their shape.** A re-export of the design system replaces \`docs/design-system/\` wholesale and 28 app patterns live only in this repo, so the fix lives in \`additions.css\` with a pattern doc, listed for upstreaming; once the published system fits images this way the block is deleted.` with `- **Images fit by an override in \`additions.css\`, and slots keep their shape.** The design system is the project's own, in code (spec 057 decision 12), so the fix is a block of its own in \`additions.css\` with a pattern doc; the export's \`components.css\` still carries the crop and the stretch it overrides.` Keep the rest of that bullet (from `Slots stay 63:88` on).
- [ ] `collection-and-lots.md`: replace `\`ItemTile.md\` still describes the fade until a re-export (spec 021).` with `\`ItemTile.md\` points to \`UnownedTile\` for the marker (spec 021; spec 057 decision 12).`
- [ ] `collection-and-lots.md` line "An unowned search tile keeps its image unfaded": replace `as an override in \`additions.css\` until the published \`ItemTile\` drops the fade (spec 021 decision 8).` with `as a rule of the project's own in \`additions.css\`; \`components.css\` still carries the fade it overrides (spec 021 decision 8; spec 057 decision 12).`
- [ ] Run the AC-7.4 search and record every hit in your report for `verification.md`: `git grep -n -i -e "re-export" -e "replaced wholesale" -e "Upstream" -e "before the next export" -e "an export that" -e "published design system" -- CLAUDE.md .claude/skills docs/design-system docs/architecture app/assets/stylesheets spec ':!.kamal/secrets'` — expect only unrelated hits: `spec/models/collection_import/round_trip_spec.rb` ("re-exports"), `spec/lib/collector/push_scope_spec.rb` and `spec/script/upgrade/release_spec.rb` ("upstream" in git commands), `spec/requests/catalog/entries_show_spec.rb` ("upstream source"), `docs/architecture/catalog-core.md` and `docs/architecture/release-and-deploy.md` ("upstream source", "filed upstream", unrelated to the design system), `docs/design-system/components/StatusMessage.md` ("the upstream source" in a sample message), and `docs/design-system/components/ImageFit.md`'s sentence that `components.css` still carries the export's rules is not a hit. Any other hit is reported, not edited, and the supervisor decides.
- [ ] Commit: `docs(design-system): retire the re-export wording from ImageFit, UnownedTile, ItemTile and two area docs (spec 057 FR-7, #248)`

---

## Phase 13: Previews, navigation (FR-8: AppHeader, TabBar, CollectionPage, CollectionPagePhone)

**Implements:** FR-8 | **Satisfies:** AC-8.1, AC-8.3 (four of six)
**Files:** `docs/design-system/previews/AppHeader.html`, `TabBar.html`, `CollectionPage.html`, `CollectionPagePhone.html`
**Interfaces:** Consumes: the markup shown in `TabBar.md` (Phase 9). Produces: the script `previews_nav.py`, which Phase 14 reuses for the other two previews.

The edit is mechanical, so it is a script with exact-count assertions, written to the scratchpad (outside the worktree). Each preview gets the five-link nav, the five-tab bar with Search and Scan icons in the Decks tab's stroke style, and `additions.css` linked after `components.css`.

- [ ] Write `/private/tmp/claude-501/-Users-james-orca-workspaces-Collector-deck-design-rules/ec07c470-c507-4b98-907e-1884affc6f7c/scratchpad/previews_nav.py`:

```python
import re, sys

root = "/Users/james/orca/workspaces/Collector/deck-design-rules/docs/design-system/previews/"
# file -> (header nav expected, tab bar expected)
files = {
    "AppHeader.html": (1, 0), "TabBar.html": (0, 1),
    "CollectionPage.html": (1, 1), "CollectionPagePhone.html": (1, 1),
    "ItemPage.html": (1, 1), "ItemPagePhone.html": (1, 1),
}
only = sys.argv[1:] or list(files)

OLD_NAV = '<nav class="c-appbar__nav" aria-label="Main"><a href="#" aria-current="page">Collection</a><a href="#">Decks</a><a href="#">Locations</a><a href="#">Wishlist</a></nav>'
NEW_NAV = '<nav class="c-appbar__nav" aria-label="Main"><a href="#" aria-current="page">Collection</a><a href="#">Decks</a><a href="#">Search</a><a href="#">Scan</a><a href="#">Locations</a></nav>'

TAB = '<a href="#"><span class="c-tabbar__icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" aria-hidden="true">%s</svg></span>%s</a>'
SEARCH = TAB % ('<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>', "Search")
SCAN = TAB % ('<path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3"/><rect x="9" y="7.5" width="6" height="9" rx="1"/>', "Scan")
# the Locations tab and the Wishlist tab, side by side, whatever their icons
OLD_TABS = re.compile(r'<a href="#"><span class="c-tabbar__icon">(?:(?!</a>).)*?</span>Locations</a><a href="#"><span class="c-tabbar__icon">(?:(?!</a>).)*?</span>Wishlist</a>', re.S)

LINK_BEFORE = '<link rel="stylesheet" href="../../../app/assets/stylesheets/collector/components.css">'
LINK_AFTER = LINK_BEFORE + '<link rel="stylesheet" href="../../../app/assets/stylesheets/collector/additions.css">'

for name in only:
    nav, tabs = files[name]
    text = open(root + name).read()
    assert text.count(OLD_NAV) == nav, (name, "nav", text.count(OLD_NAV))
    text = text.replace(OLD_NAV, NEW_NAV)
    text, found = OLD_TABS.subn(lambda _: SEARCH + SCAN, text)
    assert found == tabs, (name, "tabs", found)
    assert text.count(LINK_BEFORE) == 1 and "additions.css" not in text, (name, "link")
    text = text.replace(LINK_BEFORE, LINK_AFTER)
    assert "Wishlist" not in text or name.startswith("ItemPage"), (name, "Wishlist")  # the card page's "Add to wishlist" menu item is a later issue's
    open(root + name, "w").write(text)
    print("edited", name)
```

- [ ] Run `python3 -I /private/tmp/claude-501/-Users-james-orca-workspaces-Collector-deck-design-rules/ec07c470-c507-4b98-907e-1884affc6f7c/scratchpad/previews_nav.py AppHeader.html TabBar.html CollectionPage.html CollectionPagePhone.html` — expect four `edited` lines and no assertion error. (If an assertion fails, nothing for that file is written; read the file and tell the supervisor.)
- [ ] Read back: `git grep -n -c "Wishlist" -- docs/design-system/previews/AppHeader.html docs/design-system/previews/TabBar.html docs/design-system/previews/CollectionPage.html docs/design-system/previews/CollectionPagePhone.html ':!.kamal/secrets'` — expect no output (no match in any of the four).
- [ ] Open each of the four in headless Firefox through a scratch Selenium script in the scratchpad (the supervisor does the screenshots in Phase 15; here only confirm each file loads and the nav and tab bar counts): `script/worktree/with_mise bundle exec ruby /private/tmp/claude-501/-Users-james-orca-workspaces-Collector-deck-design-rules/ec07c470-c507-4b98-907e-1884affc6f7c/scratchpad/count_nav.rbm` (write the script there first; a non-`.rb` extension keeps the RuboCop hook off it):

```ruby
require "selenium-webdriver"
options = Selenium::WebDriver::Firefox::Options.new(args: [ "-headless" ])
driver = Selenium::WebDriver.for(:firefox, options:)
begin
  root = "file:///Users/james/orca/workspaces/Collector/deck-design-rules/docs/design-system/previews/"
  %w[AppHeader TabBar CollectionPage CollectionPagePhone].each do |name|
    driver.navigate.to("#{root}#{name}.html")
    links = driver.execute_script("return [...document.querySelectorAll('.c-appbar__nav a')].map(a => a.textContent)")
    tabs = driver.execute_script("return [...document.querySelectorAll('.c-tabbar a')].map(a => a.textContent)")
    sheets = driver.execute_script("return [...document.querySelectorAll('link[rel=stylesheet]')].map(l => l.getAttribute('href').split('/').pop())")
    puts [ name, links.join("/"), tabs.join("/"), sheets.join(",") ].join(" | ")
  end
ensure
  driver.quit
end
```

  Expect `AppHeader | Collection/Decks/Search/Scan/Locations | | preview-fonts.css,tokens.css,components.css,additions.css`, `TabBar | | Collection/Decks/Search/Scan/More | preview-fonts.css,tokens.css,components.css,additions.css`, and the two collection previews with both lists and `preview-fonts.css,tokens.css,components.css,additions.css` (in that order: it proves AC-8.3).
- [ ] Commit: `docs(design-system): the four navigation previews show Decks, Search, Scan, Locations and the five tabs (spec 057 FR-8, #248)`

---

## Phase 14: Previews, the card page (FR-8: ItemPage, ItemPagePhone)

**Implements:** FR-8, FR-5 | **Satisfies:** AC-8.2, AC-8.3 (the other two of six)
**Files:** `docs/design-system/previews/ItemPage.html`, `ItemPagePhone.html`
**Interfaces:** Consumes: Phase 13's `previews_nav.py` and the shape documented in `ItemPage.md` (Phase 11). Produces: the two previews the maintainer's final visual review looks at.

Both previews already hold the markup the doc describes, apart from the stats strip and the c-split. The header/tab-bar edit is Phase 13's script run for these two files. The card page edit is a second script: three stats with `c-stats--three`, the In decks table after Printings (the markup the maintainer approved in the mock-ups: Deck name link with the format muted beside it on wide, the phone line `c-table__sub` with the format and the zone, Zone `is-opt`, Owned and Proxy `is-num`, a muted dash for no proxy), then Format legality.

- [ ] Run `python3 -I /private/tmp/claude-501/-Users-james-orca-workspaces-Collector-deck-design-rules/ec07c470-c507-4b98-907e-1884affc6f7c/scratchpad/previews_nav.py ItemPage.html ItemPagePhone.html` — expect two `edited` lines. (The card page previews' `Add to wishlist` menu item stays: Wishlist is planned, and no rule of this spec touches the item.)
- [ ] Write `/private/tmp/claude-501/-Users-james-orca-workspaces-Collector-deck-design-rules/ec07c470-c507-4b98-907e-1884affc6f7c/scratchpad/previews_item.py`:

```python
import re

root = "/Users/james/orca/workspaces/Collector/deck-design-rules/docs/design-system/previews/"

STATS_OPEN = '<dl class="c-stats">'
EST_VALUE = '        <div class="c-stat"><dt>Est. value</dt><dd>$10.20</dd><small>updated today</small></div>\n'
IN_DECKS = '''        <section>
          <div class="c-section__head"><h2 class="c-section__title">In decks</h2><span class="c-section__count">4 copies in 2 decks</span></div>
          <div class="c-collection"><table class="c-table"><thead><tr><th>Deck</th><th class="is-opt">Zone</th><th class="is-num">Owned</th><th class="is-num">Proxy</th></tr></thead><tbody>
            <tr><td><div class="c-table__item"><div><a href="#">Izzet Tempo</a><span class="is-opt is-muted"> · Modern</span><span class="c-table__sub">Modern · Main</span></div></div></td><td class="is-opt">Main</td><td class="is-num">3</td><td class="is-num">1</td></tr>
            <tr><td><div class="c-table__item"><div><a href="#">Krenko, goblin army</a><span class="is-opt is-muted"> · Commander</span><span class="c-table__sub">Commander · Considering</span></div></div></td><td class="is-opt">Considering</td><td class="is-num">1</td><td class="is-num is-muted">&mdash;</td></tr>
          </tbody></table></div>
        </section>
'''
# the old In decks section sits in a c-split beside Format legality
SPLIT = re.compile(r'      <div class="c-split">\n        <section>\n          <div class="c-section__head"><h2 class="c-section__title">In decks</h2></div>\n          <ul class="c-list">.*?</ul>\n        </section>\n        <section>\n(?P<legality>.*?)        </section>\n      </div>\n', re.S)

for name in ("ItemPage.html", "ItemPagePhone.html"):
    text = open(root + name).read()
    assert text.count(STATS_OPEN) == 1, (name, "stats")
    text = text.replace(STATS_OPEN, '<dl class="c-stats c-stats--three">')
    assert text.count(EST_VALUE) == 1, (name, "est value")
    text = text.replace(EST_VALUE, "")
    match = SPLIT.search(text)
    assert match, (name, "c-split")
    legality = "        <section>\n" + match.group("legality") + "        </section>\n"
    text = text[:match.start()] + IN_DECKS + legality + text[match.end():]
    assert "c-split" not in text and "c-list" not in text, (name, "leftover")
    # the stat's small line says "in N decks" (decision 7); "Your copies" writes a deck's place as Deck › Zone (FR-3)
    assert text.count("<small>2 decks</small>") == 1, (name, "small")
    text = text.replace("<small>2 decks</small>", "<small>in 2 decks</small>")
    assert text.count("Izzet Tempo deck") == 2, (name, "place")
    text = text.replace("Izzet Tempo deck", "Izzet Tempo › Main")
    open(root + name, "w").write(text)
    print("edited", name)
```

  The `.*?` for the legality section copies its inner lines exactly, so Format legality's content is unchanged and only its wrapper (the `c-split`) goes. The two files are byte-identical today, so the same script applies to both.
- [ ] Run `python3 -I /private/tmp/claude-501/-Users-james-orca-workspaces-Collector-deck-design-rules/ec07c470-c507-4b98-907e-1884affc6f7c/scratchpad/previews_item.py` — expect two `edited` lines. If the `c-split` pattern does not match (the two files' indentation differs from what the script assumes), the script stops with `AssertionError` before writing; read the `In decks` part of the file and adapt the pattern, keeping the replacement text.
- [ ] Read back: `git grep -n -e "c-stats--three" -e "In decks" -e "Est. value" -e "c-split" -- docs/design-system/previews/ItemPage.html docs/design-system/previews/ItemPagePhone.html ':!.kamal/secrets'` — expect `c-stats--three` once and `In decks` (the stat and the section title) in each file, and no `Est. value` and no `c-split`.
- [ ] Run the Phase 13 count script again with `%w[ItemPage ItemPagePhone]` in place of the four names and expect five links, five tabs and `preview-fonts.css,tokens.css,components.css,additions.css` for each.
- [ ] Commit: `docs(design-system): the card page previews show three stats, the In decks table and the new navigation (spec 057 FR-8, #248)`

---

## Phase 15: Verification record and screenshots (supervisor, not delegated)

**Implements:** all | **Satisfies:** the reading of AC-1.1, 1.2, 2.1, 2.2, 2.4, 3.1, 3.2, 4.1, 5.1, 5.5, 6.1, 7.1, 7.2, 7.3, 7.4, 8.1 to 8.3
**Files:** `docs/specs/057-deck-design-rules/verification.md` (new), `docs/specs/057-deck-design-rules/screenshots/` (new)
**Interfaces:** Consumes: everything above. Produces: the record `distill-feature` and the final review read.

- [ ] The supervisor reads each document criterion against the text and writes `verification.md`: a table of criterion, file and line quoted, verdict; the AC-7.4 `git grep` hits with each reading; the AC-8.3 `<link>` read of all six previews.
- [ ] Screenshots, with a scratch Selenium script as in the mock-up work: each of the six previews at 1280px and in a 390px frame, in both themes; the app's own header with a Decks link added (the system example's frame or a scratch page) at 640px, 719px and 720px, light and dark, for decision 19 (mark, mark, wordmark); `AppHeader.html` at 640px and 720px (`?theme=dark` and `data-theme="light"` set explicitly, a 0.6s pause after a switch), plus one image each for the grouped select labels (the probe markup, since the open list is the browser's) in both themes. They go in `docs/specs/057-deck-design-rules/screenshots/` and are embedded in the PR body.
- [ ] Ask the coordinator for the maintainer's final visual review with those screenshots (the brief's step). Fix what the review finds as a task of its own with its own commit.

## Phase 16: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run `script/worktree/with_mise bin/rspec spec/system/design_system_deck_rules_spec.rb spec/design_system_tokens_spec.rb spec/design_system_files_spec.rb spec/requests/collection_location_select_spec.rb` — expect `0 failures`, and record the example counts in `verification.md`.
- [ ] Ask the coordinator for a CI slot, then run `script/worktree/with_mise bin/ci` once (RuboCop, YARD, Brakeman, bundler-audit, importmap audit, the whole suite) — expect green; send "slot released" with the SHA and the result.
- [ ] Opus implementation review (`sdd-review` Mode B) of the whole diff against the spec; record it in `verification.md` under `## Implementation review`, verdict on the first line.
- [ ] `distill-feature` at session wrap decides the area-doc changelog rows and the index status.

## Quickstart Validation

1. `script/worktree/with_mise bin/rspec spec/system/design_system_deck_rules_spec.rb spec/design_system_tokens_spec.rb spec/design_system_files_spec.rb` is green.
2. Open `docs/design-system/previews/ItemPage.html?theme=dark` and `ItemPagePhone.html`: three stats across, the In decks table after Printings with Format legality below, five header links, five tabs.
3. Start the app (`bin/dev`), sign in, open `/collection` with a location: the Location filter is up to 300px wide in a wide window and 220px in a phone-width one.
4. `git grep -n -i -e "upstream" -e "re-export" -e "replaced wholesale" -e "before the next export" -e "an export that" -e "published design system" -- CLAUDE.md .claude/skills docs/design-system docs/architecture app/assets/stylesheets spec ':!.kamal/secrets'` lists only the unrelated hits recorded in `verification.md`.

## Coverage map

| AC | Phase | Proof |
|----|-------|-------|
| 1.1, 1.2 | 8, 9 | reading |
| 1.3, 1.5, 1.6 | 5 | system examples; 1.3 red first, 1.5 and 1.6 guard the swap's two edges |
| 1.4 | 5 | system example, with a control |
| 2.1 | 8, 10 | reading |
| 2.2, 2.4 | 8 | reading |
| 2.3 | 6 | unit example, with a control |
| 3.1, 3.2 | 8, 11 | reading |
| 4.1 | 10 | reading |
| 4.2, 4.3 | 2 | system example, light and dark |
| 4.4 | 3 | system example (700px wide, bulk, 390px, Set select) |
| 4.5 | 3, 16 | the existing request and system examples stay green |
| 4.6 | 1 | request example, normal and bulk |
| 5.1, 5.5 | 10, 11 | reading |
| 5.2 to 5.4 | 4 | system example |
| 6.1 | 10 | reading |
| 7.1, 7.2 | 8, 11 | reading |
| 7.3 | 7, 12 | the guard spec stays green; reading |
| 7.4 | 12, 15 | `git grep` hits recorded |
| 8.1 to 8.3 | 13, 14 | reading the `<link>` tags; screenshots |
