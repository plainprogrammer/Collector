# Implementation Plan: Small Icons Keep Their Weight (spec 063, #294)

**Spec:** docs/specs/063-small-icon-stroke/spec.md (0.3.0, approved at Gate A by the maintainer, 2026-11-10)
**Decisions:** none (no ADR; the rulings are the spec's decisions 1 and 2)
**Created:** 2026-11-10

## Global Constraints

- The icon partials (`app/views/icons/*.html.erb`) stay byte-for-byte as they are, and no view, helper, model, controller, migration, export file or other stylesheet changes (AC-3.1, FR-4). The only app file that changes is `app/assets/stylesheets/collector/additions.css`.
- The new CSS block's heading, its comment and its rules name no spec number but 063: `spec/design_system_files_spec.rb` counts "spec 019", "spec 021" and "spec 023" across the whole of `additions.css`, and finds a block by its heading comment up to the next `/* -` heading after a blank line (FR-1). The block holds no colour literal and no `font-family` (`spec/design_system_files_spec.rb`, "keeps colour literals…").
- Use only token variables and `c-*` classes in the app; this change adds no new class (design system skill, README).
- Do not check prose documents from RSpec (`.claude/rules/testing.md`): AC-2.1, AC-2.3 and AC-2.4 are verified by reading and recorded in `verification.md`. The one new spec file measures computed styles on the app's real pages, which is not a prose check.
- Spec types are tagged explicitly (`type: :system`); multi-expectation examples use `:aggregate_failures`; RuboCop's `RSpec/ExampleLength` maximum is 15 lines; no `sleep`, no `any_instance_of`; never two test runs at once (shared test database).
- Comments in the new Ruby file say why and cite the spec criterion as plain text ("spec 063 AC-1.1").
- One git operation per Bash call, and `git add` and `git commit` in separate calls (the pre-commit hook reads the command text for `git add`; `.claude/memory/precommit-hook-staging.md`). Conventional Commits, each ending with the attribution line the session's system reminder gives. Run Ruby through `script/worktree/with_mise bin/…` if a bare `ruby` is not 4.0.7 (#289; here `ruby -v` prints 4.0.7).
- The throwaway screenshot spec (Phase 3) is never committed and is kept outside `spec/` until it runs (its RuboCop offenses would block a commit that stages Ruby).

---

## Goal

A small icon draws at about the weight of the word beside it: stroke 2.5 at 12px, 2 at 14px to 16px, the partials' 1.5 at 20px and above, set in one `additions.css` block by the component that draws the icon; the README's Iconography states how stroke follows size; the nine previews that draw icons load `additions.css` so they match the app; and a guard in the suite fails an icon drawn outside the rule.

---

## Phase 1: The measure and the CSS (Story 1, Story 3, Decisions 1–3)

**Implements:** FR-1, FR-3, FR-4 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-3.1
**Files:** `spec/system/icon_stroke_spec.rb` (new), `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes `system_sign_in_as(user)` (`spec/support/authentication_helpers.rb`), `open_in_narrow_frame(path, width:, ready:, height: 800)` and `within_narrow_frame` (`spec/support/narrow_frame.rb`), the factories `:user`, `:mtg_printing` (its `legalities` column, `db/schema.rb` `mtg_printings`) and `:lot`, and the partials `icons/check`, `icons/alert`, `icons/star` rendered through `ApplicationController.render(partial: …)`. Produces `icons(selector = "svg")` (private to the file): the rendered, stroked `svg`s that match `selector` in the current document (page or narrow frame) as `[{ "width" =>, "stroke" =>, "strokeWidth" => }]`, and the CSS block of Task 2 (no Ruby interface).

Tasks 1 and 2 go to one implementer, each its own commit, finished before Phase 2 starts. Task 1's red run is the TDD gate: the shipped CSS draws every small icon at 1.5.

### Task 1: The system spec, red on the shipped CSS

- [ ] Create `spec/system/icon_stroke_spec.rb`:

```ruby
require "rails_helper"

# Spec 063: a small icon keeps its weight. A stroke scales with the icon, so an icon's weight on screen is its
# stroke-width times its drawn width over 24 (the viewBox); additions.css sets the stroke by the component that draws
# the icon (12px at 2.5, 14px to 16px at 2) and the partials keep their 1.5 for 20px and above. These examples read
# computed styles on the app's own pages, never the previews (the previews are a drawing of the design, not of the app).
RSpec.describe "Icon stroke follows size", type: :system do
  let(:user) { create(:user) }
  let(:printing) do
    create(:mtg_printing, legalities: { "standard" => "legal", "modern" => "legal", "legacy" => "banned", "vintage" => "restricted" })
  end

  before do
    create(:lot, account: user.account, entry: printing.entry, quantity: 2)
    system_sign_in_as(user)
  end

  # The rendered svgs matching `selector` in the current document (the page, or the narrow frame inside
  # `within_narrow_frame`) that have a stroke: an svg with no width (the tab bar on a wide screen, a button hidden at
  # this width) is not drawn, and the filled star has `stroke: none`, so neither is measured.
  def icons(selector = "svg")
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(#{selector.to_json})).map((svg) => {
        const style = getComputedStyle(svg)
        return { width: svg.getBoundingClientRect().width, stroke: style.stroke, strokeWidth: parseFloat(style.strokeWidth) }
      }).filter((icon) => icon.width > 0 && icon.stroke !== "none")
    JS
  end

  # `.to_f`: a whole-number stroke and width come back from the browser as Integers, and 2 * 16 / 24 is 1 in Ruby.
  def weight(icon) = icon["strokeWidth"].to_f * icon["width"] / 24

  # Every icon the selector matches is drawn `size` px wide with a computed stroke of `stroke`.
  def expect_stroke(selector, stroke:, size:)
    seen = icons(selector)
    expect(seen).not_to be_empty, "no rendered stroked icon matched #{selector}"
    expect(seen.map { |icon| [ icon["strokeWidth"].to_f, icon["width"].round ] }.uniq).to eq([ [ stroke.to_f, size ] ]), "#{selector}: #{seen}"
  end

  # The icons whose weight on screen is outside the band of the rule, as "path: px" strings for the failure message.
  def outside_band(where)
    icons.map { |icon| weight(icon).round(3) }.reject { |px| (1.1..1.4).cover?(px) }.map { |px| "#{where}: #{px}px" }
  end

  # The real partials' markup in the badges the scanner draws (a "Matched by…" check, a "Printing not confirmed" alert
  # and a foil star), added to the card page: the scanner's own page needs a camera sitting this spec doesn't.
  def add_badges
    markup = <<~HTML.squish
      <p>
        <span class="c-badge c-badge--success">#{ApplicationController.render(partial: "icons/check")}Matched by its collector line</span>
        <span class="c-badge c-badge--warning">#{ApplicationController.render(partial: "icons/alert")}Printing not confirmed</span>
        <span class="c-badge c-badge--foil">#{ApplicationController.render(partial: "icons/star")}Foil</span>
      </p>
    HTML
    page.execute_script("document.querySelector('main').insertAdjacentHTML('afterbegin', arguments[0])", markup)
  end

  it "draws the legality marks at 12px with a stroke of 2.5", :aggregate_failures do # spec 063 AC-1.1
    visit catalog_entry_path(printing.entry)
    expect_stroke(".c-legal--yes svg", stroke: 2.5, size: 12)
    expect_stroke(".c-legal--no svg", stroke: 2.5, size: 12)
  end

  it "draws the check and the alert in a badge at 12px with a stroke of 2.5, and leaves the star filled", :aggregate_failures do # AC-1.2, AC-1.6
    visit catalog_entry_path(printing.entry)
    add_badges
    expect(page).to have_css(".c-badge--foil svg")
    expect_stroke(".c-badge svg", stroke: 2.5, size: 12)
    expect(icons(".c-badge--foil svg")).to be_empty
  end

  it "draws the search field and the buttons at 16px and the view switch at 14px with a stroke of 2", :aggregate_failures do # AC-1.3
    visit collection_path
    expect_stroke(".c-input svg", stroke: 2, size: 16)
    expect_stroke(".c-btn svg", stroke: 2, size: 16)
    expect_stroke(".c-seg svg", stroke: 2, size: 14)
  end

  it "leaves the tab bar's 22px icons at the partials' 1.5", :aggregate_failures do # AC-1.4
    visit collection_path
    open_in_narrow_frame(collection_path, width: 390, ready: "main")
    within_narrow_frame { expect_stroke(".c-tabbar svg", stroke: 1.5, size: 22) }
  end

  # The guard: an icon at a size or in a component the rule doesn't cover fails here, and so does an icon that shrinks.
  # The weights the rule gives are 1.17px (14px), 1.25px (12px and 20px), 1.33px (16px) and 1.375px (22px).
  it "keeps every rendered stroked icon between 1.1px and 1.4px on screen", :aggregate_failures do # AC-1.5
    [ catalog_entry_path(printing.entry), collection_path, collection_path(view: "table"), catalog_entries_path ].each do |path|
      visit path
      expect(icons).not_to be_empty, "no rendered stroked icon on #{path}"
      expect(outside_band(path)).to be_empty
    end
    open_in_narrow_frame(collection_path, width: 390, ready: "main")
    within_narrow_frame do
      expect(icons).not_to be_empty
      expect(outside_band("the 390px collection page")).to be_empty
    end
  end
end
```

- [ ] Run `bin/rspec spec/system/icon_stroke_spec.rb`. Expected: **4 of 5 examples fail**: the legality, badge and 16px and 14px examples with the measured pairs in the message (for example `.c-legal--yes svg: [{"width"=>12, … "strokeWidth"=>1.5}]` against `[[2.5, 12]]`), and the guard example on the 0.75px icons (`"…: 0.75px"`). The tab bar example (AC-1.4) **passes**, because 1.5 is what the shipped CSS draws and the rule keeps it: it is a regression guard, not a red one. If an example fails any other way (no `main`, `ApplicationController.render` raising, `evaluate_script` returning nil), fix the example and re-run until only the weights fail. The suite pins classic scrollbars; they don't change a weight.
- [ ] Run `bin/rubocop spec/system/icon_stroke_spec.rb` and fix what it reports (`RSpec/ExampleLength` is 15 lines: the longest example is 11; `RSpec/MultipleExpectations` is covered by `:aggregate_failures`).
- [ ] Commit: `git add spec/system/icon_stroke_spec.rb`, then in its own call `git commit -m "test(design-system): small icons keep their weight, red on the shipped stroke (spec 063)"` followed by the attribution line.

### Task 2: The CSS block, green

Load the `collector-design-system` skill first (CLAUDE.md: before any stylesheet or UI copy change), and read `docs/design-system/README.md`.

- [ ] Append to `app/assets/stylesheets/collector/additions.css` (a blank line after the file's last rule, then the block; the file's last block ends with the `.c-pick .is-data, .c-pagehead__stats .is-data` rule):

```css

/* ---------- Small icon stroke (spec 063) ---------- */
/* An icon's stroke scales with it: weight on screen = stroke-width × drawn width ÷ 24 (the viewBox). The partials write
   1.5, Lucide's weight at 20px (1.25px on screen); at 12px that is 0.75px, a hairline beside a 600-weight word, and at
   14px to 16px it is 0.88px to 1px. The rule is about 1.25px on screen below 20px: 30 ÷ size, rounded to a half (12px
   2.5, 14px to 16px 2, 20px and up the partials' 1.5, so the tab bar's 22px icons need no rule). A CSS declaration beats
   an SVG presentation attribute on the same element, so the components that set the size set the stroke too, the
   partials keep their attribute and the previews match once they load this file. The filled star has `stroke: none`
   and is not touched by it. The README's Iconography states the rule. */
.c-badge svg, .c-legal svg { stroke-width:2.5; }
.c-btn svg, .c-input svg, .c-menu__item svg, .c-filter svg, .c-seg button svg { stroke-width:2; }
```

- [ ] Run `bin/rspec spec/system/icon_stroke_spec.rb`. Expected: **5 examples, 0 failures**.
- [ ] Run `bin/rspec spec/design_system_files_spec.rb`. Expected: all pass (the counts of "spec 019", "spec 021" and "spec 023" are unchanged: the new block names none).
- [ ] Run `git diff --stat main -- app`. Expected: only `app/assets/stylesheets/collector/additions.css` (AC-3.1: partials, views, helpers and every other stylesheet untouched).
- [ ] Commit: `git add app/assets/stylesheets/collector/additions.css`, then in its own call `git commit -m "feat(design-system): small icons keep their weight, stroke follows size (spec 063, #294)"` followed by the attribution line.

---

## Phase 2: The documents and the previews (Story 2, Decision 2)

**Implements:** FR-2 | **Satisfies:** AC-2.1, AC-2.2 (the link; its measure is Phase 3), AC-2.3, AC-2.4 (the index row is in `docs/specs/README.md` already)
**Files:** `docs/design-system/README.md`, `docs/design-system/components/TabBar.md`, `docs/design-system/components/Badge.md`, the nine previews `docs/design-system/previews/{Badge,Button,Chip,CollectionTable,FilterBar,Input,ItemTile,Menu,ViewSwitch}.html`
**Interfaces:** none (documents and `<link>` tags).

Tasks 3 and 4 go to one implementer, each its own commit, after Phase 1. The shared test database: no second test run while it works. This phase has no code to test first; AC-2.1 and AC-2.3 are read, AC-2.2's measure is Phase 3.

### Task 3: README, TabBar.md and Badge.md

Load the `collector-design-system` skill first (the README and component documents are its rules).

- [ ] In `docs/design-system/README.md`, replace the Iconography bullet

```
- No icon set chosen yet. Until one is, use Lucide (ISC-licensed, 1.5px stroke, 20px) in `currentColor`, which matches Plex's weight. Flag any other set here before adopting it.
```

with

```
- No icon set chosen yet. Until one is, use Lucide (ISC-licensed) in `currentColor`, which matches Plex's weight. Flag any other set here before adopting it.
- Stroke follows the size an icon is drawn at (spec 063). A stroke scales with its icon, so a Lucide stroke of 1.5 draws 1.25px on screen at 20px but 0.75px at 12px, a hairline beside a 600-weight word. Below 20px an icon keeps about 1.25px on screen: the stroke is `30 ÷ size` in px, rounded to a half, never below 1.5 or above 2.5. The app draws 1.5 at 20px and above (the tab bar's 22px), 2 at 14px to 16px (buttons, inputs, menu items, the view switch, filter chips) and 2.5 at 12px (badges, legality marks).
- Every icon keeps `stroke-width="1.5"` in its markup (the weight at 20px, so a copied icon looks right on its own). `additions.css` sets the heavier stroke by the component that draws the icon, so an icon placed in one of those components needs nothing more. An icon drawn at a size no component sets gets its stroke by the rule above, and its size and stroke are added to the list of sizes above.
```

- [ ] In `docs/design-system/components/TabBar.md` line 10, change `stroke-width="2"` to `stroke-width="1.5"` on the Decks icon's `<svg>` (the app's partials and `previews/TabBar.html` draw 1.5; the icon is the design system's own, no partial draws it).
- [ ] In `docs/design-system/components/Badge.md` line 5, replace `the consumer provides a 12px icon and a one- or two-word label; both are required, because colour alone never carries meaning.` with (the added sentence follows the first one, inside the same paragraph):

```
**Markup** — the consumer provides a 12px icon and a one- or two-word label; both are required, because colour alone never carries meaning. The icon's stroke is 2.5, set by `additions.css` for `c-badge svg` (spec 063), not by its `stroke-width` attribute, which stays 1.5.
```
- [ ] Run `git diff docs/design-system/` and read it: the three files, nothing else. Commit: `git add docs/design-system/README.md docs/design-system/components/TabBar.md docs/design-system/components/Badge.md`, then in its own call `git commit -m "docs(design-system): stroke follows size in Iconography (spec 063, #294)"` followed by the attribution line.

### Task 4: The nine previews load additions.css

- [ ] In each of the nine previews, insert the stylesheet link after the `components.css` link, as the previews that already load it have it. Each file has the same line shape (`…collector/components.css"><meta charset…`). Run:

```
for name in Badge Button Chip CollectionTable FilterBar Input ItemTile Menu ViewSwitch; do
  sed -i '' 's#collector/components.css"><#collector/components.css"><link rel="stylesheet" href="../../../app/assets/stylesheets/collector/additions.css"><#' "docs/design-system/previews/$name.html"
done
```

- [ ] Run `git grep -c "additions.css" -- docs/design-system/previews/Badge.html docs/design-system/previews/Button.html docs/design-system/previews/Chip.html docs/design-system/previews/CollectionTable.html docs/design-system/previews/FilterBar.html docs/design-system/previews/Input.html docs/design-system/previews/ItemTile.html docs/design-system/previews/Menu.html docs/design-system/previews/ViewSwitch.html`. Expected: each file `:1`. Run `git diff --stat docs/design-system/previews`. Expected: 9 files, one line changed each (the link is on the same line as the others).
- [ ] Run `git grep -L "additions.css" -- 'docs/design-system/previews/*.html'`. Expected: `Cover.html` and `ManaCost.html` only (no stroked icon: a filled illustration and no svg).
- [ ] Commit: `git add docs/design-system/previews`, then in its own call `git commit -m "docs(design-system): the previews that draw icons load additions.css (spec 063, #294)"` followed by the attribution line.

---

## Phase 3: The proof (Story 1 AC-1.7, Story 2 AC-2.2)

**Implements:** the verification criteria | **Satisfies:** AC-1.7, AC-2.2 (the measure and the shots), AC-2.1, AC-2.3 and AC-2.4 (by reading)
**Files:** `docs/specs/063-small-icon-stroke/verification.md`, `docs/specs/063-small-icon-stroke/screenshots/*` (new)
**Interfaces:** none. The supervisor (not an implementer) runs this phase, because the maintainer's visual review is the criterion.

### Task 5: Before and after shots of the app

- [ ] Copy the throwaway spec the probe wrote (`/private/tmp/claude-501/-Users-james-orca-workspaces-Collector-small-icon-stroke/dd46c0b2-fada-4ecc-b8de-d0f08f5b8d63/scratchpad/zz_063_screenshots_spec.rb`; scratchpads are per session, so if it is gone rebuild it from `.claude/memory/pr-screenshots-workflow.md`) into `spec/system/`, and rewrite it so each region is shot twice per theme and pixel ratio: **before** with a `<style>` appended after the page has rendered holding the old weight (`.c-badge svg, .c-legal svg, .c-btn svg, .c-input svg, .c-menu__item svg, .c-filter svg, .c-seg button svg { stroke-width: 1.5 !important }`), **after** with no override. Regions: the legality grid (`.c-legality`, card page), a badge row (the real partials' markup, as `add_badges` builds it), the collection page's `main` (header buttons, search field, view switch), and a table row's More button (`collection_path(view: "table")`, the `c-btn--icon` of a row). Light and dark through `layout.css.prefers-color-scheme.content-override` and `data-theme` set in the page with a 0.7s pause; 1x and 2x through `layout.css.devPixelsPerPx`, each combination in its own registered driver (`driven_by :selenium, using: :headless_firefox, options: { name: … }` with `FirefoxBinary.pin(options)`, as the probe's `shoot` helper and `spec/support/system.rb` do). Classic scrollbars as `spec/support/system.rb` pins them. This follows `.claude/memory/pr-screenshots-workflow.md` ("Screenshots from a throwaway system spec", "CSS-fix before shots").
- [ ] Run `SHOTS_DIR=<scratchpad>/final bin/rspec spec/system/zz_063_screenshots_spec.rb`. Look at one shot of each theme and ratio before trusting the rest (headless Firefox prefers dark: each shot sets `data-theme` itself). Delete the throwaway spec from `spec/system/`.
- [ ] Compose labelled before-and-after pairs (`magick … -append`, quality 82 JPEG, about 150–300 KB each) into `docs/specs/063-small-icon-stroke/screenshots/` (`legality-light-2x.jpg`, `badges-dark-2x.jpg`, …, 1x as well), and show them to the maintainer for the final visual review (AC-1.7), with the More dots and the 14px view switch in view. A change the maintainer asks for goes back through the spec (decision 1) before the CSS moves.

### Task 6: The previews measured, and the record

- [ ] Serve the worktree (`python3 -m http.server 3871 --bind 127.0.0.1 --directory "$PWD"`, started with `run_in_background`), and in a scratch Ruby script under the git-ignored `tmp/` (run with `script/worktree/with_mise bundle exec ruby tmp/…`, so the bundle's selenium loads) load `http://127.0.0.1:3871/docs/design-system/previews/<Name>.html` in headless Firefox for Badge, ItemPage, Button, Input, ViewSwitch, Menu, Chip and TabBar, and read `getComputedStyle(svg).strokeWidth` and the drawn width of their icons: expected 2.5 at 12px (Badge, ItemPage's legality), 2 at 16px (Button, Input, Menu's items) and 14px (ViewSwitch, Chip), 1.5 at 22px (TabBar); and run `git grep -ho 'stroke-width="[^"]*"' -- docs/design-system/previews | grep -vc '"1.5"'` (expected 0: AC-2.2, spec 060 AC-7.5; per match, not per line, because the previews' markup sits on long lines). Take before (the link removed in the page by script) and after shots of the nine previews that gained the link, light, 1x, and note the two changes the spec allows (ItemTile's unowned tile, CollectionTable's phone frame) if they show. Keep the shots of this task under `tmp/` too; commit only the few shots `verification.md` cites.
- [ ] Write `docs/specs/063-small-icon-stroke/verification.md`: each AC with how it was met (the commit, the example, the reading), the red run of Task 1 (the pairs it printed), the preview measures, the shots and the maintainer's review of them, the facts not measured (headless Selenium couldn't read the browser console, if that holds), and a `## Implementation review` heading left for `sdd-review` Mode B.
- [ ] Commit the shots and `verification.md`: `git add docs/specs/063-small-icon-stroke`, then in its own call `git commit -m "docs(specs): verification and shots of spec 063"` followed by the attribution line.

---

## Integration Verification

- [ ] `bin/rspec spec/system/icon_stroke_spec.rb spec/design_system_files_spec.rb`: 0 failures.
- [ ] `bin/rspec spec/system/design_system_deck_rules_spec.rb spec/system/design_system_deck_components_spec.rb spec/system/collection_views_spec.rb spec/system/card_page_spec.rb`: the neighbouring design-system and page examples still pass (the heavier stroke changes no layout: an icon's box is unchanged).
- [ ] `bin/ci checks` (RuboCop, YARD, the comment ratchet, Brakeman, audits): green. The ratchet judges `spec/support/`, `app/models/` and `lib/`: this branch adds no Ruby there.
- [ ] The full `bin/ci` runs at push time through the pre-push hook (the branch carries code), in a slot the coordinator grants; the pushed SHA and the result are reported.

## Quickstart Validation

Open a card page in the dev server (`bin/dev`): the Format legality marks read as heavy as "Legal" and "Not legal"; the collection page's "Add items", "Scan cards" and the Grid and Table switch read at the weight of their labels; the tab bar below 640px is unchanged.
