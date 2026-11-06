# Implementation Plan: A Table Row's Place Line Wraps (spec 048, #142)

**Spec:** docs/specs/048-row-place-line/spec.md (0.4.0, approved at Gate A)
**Decisions:** none (no ADR; the rulings are in the spec)
**Created:** 2026-11-06

## Global Constraints

- Tokens and `c-*` classes only; the rules go in `app/assets/stylesheets/collector/additions.css`, with a comment citing spec 048 (FR-1, AC-3.1).
- No controller, model, query, export or migration change; the one markup change is a `span.c-table__place-name` inside the named Location cell of `app/views/collections/_lot_cells.html.erb` (FR-1). The muted "No location" cell and a tile's rules (`.c-tile__place*`) are not touched (FR-1, FR-2).
- The cell's rule is `white-space: normal` on the named cell only (`.c-table td.c-table__place:not(.is-muted)`, as spec FR-1 and decision 5 say); the span inside it caps the name at 20rem and breaks it;
- The name's span is at most 20rem wide; a name with no space breaks inside itself (`overflow-wrap: anywhere`); the table is no wider than `.c-collection`'s `clientWidth` and the page never scrolls sideways because of a place name at frames of 800–1280px, and at 760px only the page's own scroll is asked of it (AC-1.3, AC-1.4).
- Widths are measured in headless Firefox with `open_in_narrow_frame` (`spec/support/narrow_frame.rb`), never asserted from the CSS (FR-4).
- Core code names no collectible type or source (`mtg`, `scryfall`, `magic`) (FR-3).
- Spec types are tagged explicitly (`type: :request`, `type: :system`, `type: :model`, `type: :config`); multi-expectation examples use `:aggregate_failures` (CLAUDE.md, Specs).
- Do not check prose documents from RSpec (`.claude/rules/testing.md`): the document criteria (AC-3.1, AC-3.2) are verified by reading and recorded in `verification.md`.
- No `sleep`, no `any_instance_of`; one git operation per Bash call; Conventional Commits ending with the attribution line the session's system reminder gives.

---

## Goal

A table row shows its whole place name wrapped, on a phone and in the wide table, so no name of up to 60 code points makes the collection page scroll sideways; spec 033's seven test gaps are closed by examples and a guard; `c-table__place` is documented.

---

## Phase 1: A row's place wraps (Story 1, Decisions 1–3, 5)

**Implements:** FR-1, FR-2, FR-4 | **Satisfies:** AC-1.1–AC-1.7, AC-3.1 (the design-system part)
**Files:** `spec/system/collection_row_place_spec.rb` (new), `spec/requests/collection_places_spec.rb`, `app/views/collections/_lot_cells.html.erb`, `app/assets/stylesheets/collector/additions.css`, `docs/design-system/components/CollectionTable.md`, `docs/design-system/README.md`
**Interfaces:** Consumes: `open_in_narrow_frame(path, width:, ready:, height: 800)` returning `[innerWidth, fits]`, `within_narrow_frame`, `system_sign_in_as`, `owned_printing(name, account:, number:, quantity:, finish:, condition:, location:, ...)` (`spec/support/narrow_frame.rb`, `spec/support/collection_helpers.rb`). Produces: the markup `<td class="is-opt c-table__place"><span class="c-table__place-name">NAME</span></td>` for a placed lot, and the CSS class `.c-table__place-name`; later phases don't depend on them.

Tasks 1–3 go to one implementer, each its own commit, finished and committed before Phase 2 starts. Task 1 writes the examples that fail on today's CSS; Task 2 makes them pass.

### Task 1: The examples, red

- [ ] Create `spec/system/collection_row_place_spec.rb`:

```ruby
require "rails_helper"

# Spec 048: a table row's place line wraps, on a phone (AC-1.1, AC-1.2) and in the wide Location cell (AC-1.3, AC-1.4),
# so no name makes the page scroll sideways; a table with no location is unchanged (AC-1.7). AC-1.6 (a tile's place is
# still cut with an ellipsis) is spec 033's example "keeps a long place name to one line on a tile" in
# collection_table_spec.rb, which must stay green.
RSpec.describe "A table row's place line", type: :system do
  spaced = "Blue binder, shelf three, left side, behind the board games." # 60 code points
  unbroken = "W" * 60

  let(:user) { system_sign_in_as(create(:user)) }
  let(:table_path) { collection_path(view: "table") }

  def own_in(name)
    owned_printing("Lightning Bolt", account: user.account, number: "146", location: create(:location, account: user.account, name:))
  end

  # Measured inside the narrow frame: the table's width, its container's clientWidth, the name span's width in rem,
  # whether the name's text stays inside the span (it doesn't when it can't break), and the span's height in px.
  def measures
    page.evaluate_script(<<~JS).symbolize_keys
      (() => {
        const view = document.getElementById("narrow").contentWindow
        const doc = view.document
        const span = doc.querySelector(".c-table__place-name")
        const root = parseFloat(view.getComputedStyle(doc.documentElement).fontSize)
        return { table: doc.querySelector("table.c-table").getBoundingClientRect().width,
                 container: doc.querySelector(".c-collection").clientWidth,
                 rem: span && span.getBoundingClientRect().width / root,
                 inside: span && span.scrollWidth <= span.clientWidth + 1,
                 height: span && span.getBoundingClientRect().height }
      })()
    JS
  end

  describe "on a phone" do
    [ 360, 390 ].each do |width|
      { "with spaces" => spaced, "with no space" => unbroken }.each do |label, name|
        it "shows a name #{label} whole in the line under the name, with no sideways scroll, at #{width}px", :aggregate_failures do # AC-1.1, AC-1.2
          own_in(name)
          visit table_path
          expect(open_in_narrow_frame(table_path, width:, ready: "tbody tr")).to eq([ width, true ])
          within_narrow_frame do
            expect(find(".c-table__sub", visible: :visible).text).to end_with(" · #{name}")
          end
        end
      end
    end
  end

  describe "in the wide table" do
    [ 800, 900, 1024, 1280 ].each do |width|
      { "with spaces" => spaced, "with no space" => unbroken }.each do |label, name|
        it "keeps a name #{label} whole in the cell, within 20rem and within the table's container, at #{width}px", :aggregate_failures do # AC-1.3, AC-1.4
          own_in(name)
          visit table_path
          expect(open_in_narrow_frame(table_path, width:, ready: "td.c-table__place")).to eq([ width, true ])
          within_narrow_frame do
            seen = measures
            expect(find(".c-table__place-name", visible: :visible).text.squish).to eq(name)
            expect(seen[:rem]).not_to be_nil
            expect([ seen[:table] <= seen[:container] + 1, seen[:rem] <= 20.01, seen[:inside] ]).to eq([ true, true, true ])
            expect(seen[:height]).to be > 18 if name.include?(" ") && width == 800
          end
        end
      end
    end

    { "with spaces" => spaced, "with no space" => unbroken }.each do |label, name|
      it "does not scroll the page sideways for a name #{label} at 760px, the first width with the Location column", :aggregate_failures do # AC-1.3, AC-1.4
        own_in(name)
        visit table_path
        expect(open_in_narrow_frame(table_path, width: 760, ready: "td.c-table__place")).to eq([ 760, true ])
      end
    end
  end

  describe "for an account with no location" do
    [ 360, 390 ].each do |width|
      it "fits one line under the name at #{width}px and shows no place", :aggregate_failures do # AC-1.7
        owned_printing("Lightning Bolt", account: user.account, number: "146", quantity: 9_999, finish: "foil", condition: "near_mint")
        visit table_path
        expect(open_in_narrow_frame(table_path, width:, ready: "tbody tr")).to eq([ width, true ])
        within_narrow_frame do
          expect(page).to have_no_css("th", text: "Location", visible: :all)
          line = find(".c-table__sub", visible: :visible)
          expect(line.text).to end_with("· 146 · Foil · NM · EN")
          expect(line.evaluate_script("this.getBoundingClientRect().height")).to be < 20
        end
      end
    end
  end
end
```

- [ ] In `spec/requests/collection_places_spec.rb`, inside `describe "the table"`, after the "has a Location column…" example, add (AC-1.5; it fails today because the span doesn't exist):

```ruby
    it "escapes a name on the row, in the cell's span and in the line under the name", :aggregate_failures do # spec 048 AC-1.5
      own(location: create(:location, account: user.account, name: "<b>Binder</b> #{'x' * 40}"))
      get collection_path(view: "table")
      expect(response.body).not_to include("<b>Binder</b>")
      expect(page_html.at_css("td.c-table__place .c-table__place-name").text).to start_with("<b>Binder</b>")
      expect(page_html.at_css(".c-table__sub").text).to include("<b>Binder</b>")
    end
```

- [ ] Run: `bin/rspec spec/system/collection_row_place_spec.rb spec/requests/collection_places_spec.rb` — expect FAIL: the no-space phone examples (a real overflow, about 440px), the wide examples (the span doesn't exist yet, so they fail at the span's text or at `expect(seen[:rem]).not_to be_nil`, a missing-markup red; the layout assertions are proved by Task 2's mutation checks), both 760px examples (probe 1: 950px and 1313px tables) and the new request example (no span yet). The spaced phone examples and the no-location examples PASS already; they are regression guards and Task 2 proves they can fail.
- [ ] Commit: `test(collection): a row's place wraps and never scrolls the page sideways (spec 048)`

### Task 2: The rules

- [ ] In `app/views/collections/_lot_cells.html.erb` replace the named cell (line 20) with:

```erb
    <td class="is-opt c-table__place"><span class="c-table__place-name"><%= lot.location.name %></span></td>
```

  The `No location` cell on the next line stays as it is.

- [ ] In `app/assets/stylesheets/collector/additions.css` replace the "Row place (spec 033)" block (the comment and the `@container collection (max-width: 639px) { .c-table__sub { white-space:normal; } }` rule) with:

```css
/* ---------- Row place (spec 033, spec 048): a row's place wraps, a tile's is cut ---------- */
/* The export's `.c-table td { white-space:nowrap }` would widen the table to fit a name of up to 60 characters, so a row's
   place wraps: the phone line below 640px, the Location cell at any width. Firefox ignores max-width on a table cell, so the
   cap is on the span inside it. overflow-wrap:anywhere breaks a name with no space, which has no other break point
   (spec 048 decisions 1–3). The unplaced cell, "No location", keeps one line. */
.c-table td.c-table__place:not(.is-muted) { white-space:normal; }
.c-table__place-name { display:block; max-width:20rem; overflow-wrap:anywhere; }
@container collection (max-width: 639px) {
  .c-table__sub { white-space:normal; overflow-wrap:anywhere; }
}
```

- [ ] Run: `bin/rspec spec/system/collection_row_place_spec.rb spec/system/collection_table_spec.rb spec/requests/collection_places_spec.rb spec/requests/collection_views_spec.rb` — expect PASS. If a wide example still fails, don't guess a rule: print the span, cell and table widths per frame from `measures`, then stop and report them to the supervisor.
- [ ] Run: `bin/rubocop` on the changed Ruby and `bin/rspec spec/requests/collections_spec.rb spec/requests/bulk_condition_spec.rb` — expect PASS (the cell's text is unchanged).
- [ ] Commit: `feat(collection): a row's place wraps and breaks inside a name with no space (spec 048)`
- [ ] Mutation checks, after the commit above so the rules are committed and `git checkout --` restores them: each is a temporary edit to `app/assets/stylesheets/collector/additions.css`, run the named examples, expect FAIL, then `git checkout -- app/assets/stylesheets/collector/additions.css`. (a) Delete `overflow-wrap:anywhere` from `.c-table__place-name`: every wide "with no space" example fails on `inside`. (b) Delete `white-space:normal` from the `@container` `.c-table__sub` rule: the spaced phone examples fail on `end_with` or the page scroll. (c) Add `.c-table__sub { width:4ch }` to the same container rule: the AC-1.7 examples fail on the line's height. (d) Delete the `.c-table td.c-table__place:not(.is-muted)` rule: the 800px spaced example fails on `table <= container` or on the span's height. Run `git status --short` afterwards: nothing may be modified.

### Task 3: The design system's words (AC-3.1)

- [ ] In `docs/design-system/components/CollectionTable.md` replace the bullet that starts `- Location in the app (spec 033):` with:

```markdown
- Location in the app (spec 033, spec 048): a plain `is-opt` "Location" column (`c-table__place`) after Qty and before Paid, with the lot's location name in a `c-table__place-name` span, or "No location" (`is-muted`); on phones the column is hidden and the place ends the `c-table__sub` line under the name (nothing is added for an unplaced lot). A row's place wraps, where a tile's is cut with an ellipsis: the line under the name wraps below 640px so a 60-character name fits 360px, and the named cell wraps (`white-space: normal`, overriding the table's `nowrap`) with the name capped at 20rem by the span (the cap is on the span because Firefox ignores `max-width` on a table cell), so a long name makes a taller row and never a sideways scroll; both break a name with no space inside it (`overflow-wrap: anywhere`). The column and the place on the line are left out while the account has no location; the line's wrap rule applies to every narrow collection table. The column isn't sortable.
```

- [ ] In `docs/design-system/README.md` add a line after the spec 033 "App additions" line:

```markdown
App additions (spec 048, in `collector/additions.css`): `c-table__place-name` (the Location cell's name, capped at 20rem and broken inside a word when it must), the wrapping of the named `c-table__place` cell and `overflow-wrap` on the phone `c-table__sub`, documented in `CollectionTable`. The cell's rule overrides the export's `.c-table td { white-space:nowrap }`. Upstream them into the published design system before the next export replaces this folder.
```

- [ ] Verify by reading that both files say what the spec's AC-3.1 asks. (No RSpec: prose documents aren't checked from RSpec.)
- [ ] Commit: `docs(design-system): document the wrapped place name of a table row (spec 048)`

---

## Phase 2: Spec 033's test gaps (Story 2)

**Implements:** FR-3 | **Satisfies:** AC-2.1–AC-2.6
**Files:** `spec/requests/collection_places_spec.rb`, `spec/models/collection_grid_spec.rb`, `spec/system/collection_row_place_spec.rb`, `spec/collection_places_core_spec.rb` (new), `.rubocop.yml`
**Interfaces:** Consumes: the helpers in `spec/requests/collection_places_spec.rb` (`own`, `page_html`, `place_lines`, `cells`, `blue`, `box`) and `spec/models/collection_grid_spec.rb` (`account`, `put`, `place_of`, `blue`, `box`); Phase 1's span. Produces: examples and one guard; no app code changes. Each example describes behaviour that already holds, so it passes on first run; after writing each, the implementer proves it can fail with the stated mutation, then reverts the mutation with `git checkout -- <file>` before committing.

Tasks 4–8 go to one implementer, in order, each its own commit staging named paths only: the mutation checks edit files other tasks' examples depend on, so no two implementers run in this worktree at once, and the examples that mutate a file are run before the next task starts.

### Task 4: AC-2.1, a name filter keeps a tile's places

- [ ] In `spec/requests/collection_places_spec.rb`, inside `describe "the grid"`, add:

```ruby
    it "shows all of a matching printing's places under a name filter, and no other printing", :aggregate_failures do # spec 033 AC-1.8, spec 048 AC-2.1
      bolt = own(location: blue, quantity: 3).entry
      create(:lot, account: user.account, entry: bolt, location: box, finish: "foil")
      own("Opt", location: box)
      get collection_path(q: "bolt")
      expect(page_html.css(".c-tile__name").map { it.text.squish }).to eq([ "Lightning Bolt" ])
      expect(place_lines).to eq([ "Blue binder +1 more" ])
    end
```

  and inside `describe "the table"`:

```ruby
    it "shows only the matching lots' rows under a name filter, each with its place", :aggregate_failures do # spec 048 AC-2.1
      bolt = own(location: blue, quantity: 3).entry
      create(:lot, account: user.account, entry: bolt, location: box, finish: "foil")
      own("Opt", location: box)
      get collection_path(view: "table", q: "bolt")
      expect(page_html.css("tbody tr").size).to eq(2)
      expect(cells).to contain_exactly("Blue binder", "Long box")
    end
```

- [ ] Run: `bin/rspec spec/requests/collection_places_spec.rb` — expect PASS. Mutation check: in `app/models/collection_grid.rb`, in `places_of`, temporarily make the grouped read take only the first lot's place (or return `{}`), re-run the grid example — expect FAIL; `git checkout -- app/models/collection_grid.rb`.
- [ ] Commit: `test(collection): a name filter keeps a tile's places and a row's place (spec 048 AC-2.1)`

### Task 5: AC-2.5 the tie by comparison key, AC-2.6 nothing but the place changes

- [ ] In `spec/models/collection_grid_spec.rb`, in `describe "#places? and a tile's place (spec 033)"`, after the "breaks a tie by comparison key…" example, add:

```ruby
    it "orders a tie by comparison key, where the raw name would order it the other way", :aggregate_failures do # spec 033 AC-1.2, spec 048 AC-2.5
      put(2, create(:location, account:, name: "Beta shelf"))
      put(2, create(:location, account:, name: "alpha shelf"), finish: "foil")
      expect(place_of).to have_attributes(name: "alpha shelf", more: 1)
    end
```

- [ ] In `spec/requests/collection_places_spec.rb`, next to `def cells`, add the helper, and inside `describe "the grid"` add the example:

```ruby
  # What a tile shows besides its place line (spec 004 AC-11.2, AC-11.3), and the page's counts.
  def tile_facts
    tiles = page_html.css(".c-tile").map do |tile|
      [ tile["href"], tile.at_css(".c-tile__qty").text, tile.css(".c-tile__flags").map { it.text.squish }, tile.css(".c-tile__meta .c-tag").map { it.text.squish } ]
    end
    [ tiles, page_html.at_css(".c-filterbar__count").text.squish, page_html.at_css(".c-pagehead__stats").text.squish ]
  end

    it "changes nothing about a tile but its place line when the lots are placed", :aggregate_failures do # spec 033 AC-1.7, spec 048 AC-2.6
      foil = own(quantity: 3, finish: "foil")
      create(:lot, account: user.account, entry: foil.entry)
      own("Opt")
      blue

      get collection_path
      unplaced = tile_facts
      expect(place_lines).to eq([ "No location", "No location" ])

      foil.update!(location: blue)
      get collection_path
      expect(tile_facts).to eq(unplaced)
      expect(place_lines).to eq([ "Blue binder +1 more", "No location" ])
    end
```

- [ ] Run: `bin/rspec spec/models/collection_grid_spec.rb spec/requests/collection_places_spec.rb` — expect PASS. Mutation check for AC-2.5: in `places_of`'s `sort_by`, temporarily replace `key.to_s` with `name.to_s`; re-run the grid model spec — expect the new example FAIL; `git checkout -- app/models/collection_grid.rb`. Mutation check for AC-2.6: in `app/views/collections/_tile.html.erb` temporarily render the quantity as `<%= tile.place&.name ? tile.quantity - 1 : tile.quantity %>`; re-run — expect the new example FAIL; `git checkout -- app/views/collections/_tile.html.erb`. If the AC-2.6 example fails on unmutated code, the failure is a bug of spec 033: stop and report it, don't adjust the example.
- [ ] Commit: `test(collection): a tie orders by comparison key, and placing lots changes only the place line (spec 048 AC-2.5, AC-2.6)`

### Task 6: AC-2.3, bulk Set condition and Undo on the rendered rows

- [ ] In `spec/requests/collection_places_spec.rb`, add a new `describe` at the end of the file (inside the outer `RSpec.describe`):

```ruby
  describe "after a bulk action (spec 033 AC-2.6, spec 048 AC-2.3)" do
    def select_lots(*lots, go:)
      post collection_selection_path
      patch collection_selection_path, params: { go:, q: "", rendered_q: "", all_rendered: "0",
        shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }
    end

    it "keeps each lot's place when Set condition is applied", :aggregate_failures do
      placed = own(location: blue)
      loose = own("Opt")
      select_lots(placed, loose, go: "set_condition")
      post collection_condition_change_path, params: { condition: "lightly_played" }
      expect([ placed.reload.condition, loose.reload.condition ]).to eq(%w[lightly_played lightly_played])
      follow_redirect!
      expect(cells).to eq([ "Blue binder", "No location" ])
    end

    it "keeps each lot's place when a bulk Remove is undone from the bulk table's message", :aggregate_failures do
      placed = own(location: blue)
      loose = own("Opt")
      own("Shock") # not selected, so the bulk table the message appears on still has a row
      select_lots(placed, loose, go: "remove")
      post collection_bulk_removals_path
      follow_redirect!
      undo = page_html.at_css(".c-status form.c-status__action")
      post undo["action"], params: { return_to: undo.at_css("input[name=return_to]")["value"] }
      follow_redirect!
      expect(user.account.lots.count).to eq(3)
      expect(cells).to eq([ "Blue binder", "No location", "No location" ])
    end
  end
```

- [ ] Run: `bin/rspec spec/requests/collection_places_spec.rb` — expect PASS. Mutation check: in `app/views/collections/_lot_cells.html.erb`, temporarily render the cell only `if places && false`; re-run — expect both new examples FAIL; `git checkout -- app/views/collections/_lot_cells.html.erb`.
- [ ] Commit: `test(collection): bulk Set condition and Undo keep the rendered rows' places (spec 048 AC-2.3)`

### Task 7: AC-2.2, the tile link's accessible name

- [ ] In `spec/system/collection_row_place_spec.rb` add, after the last `describe`:

```ruby
  describe "a tile" do
    it "names the whole place line in its link's accessible name, after the card's name", :aggregate_failures do # spec 033 AC-1.6, spec 048 AC-2.2
      entry = owned_printing("Lightning Bolt", account: user.account, quantity: 3, location: create(:location, account: user.account, name: "Blue binder")).entry
      create(:lot, account: user.account, entry:, finish: "foil", location: create(:location, account: user.account, name: "Long box"))
      visit collection_path(view: "grid")
      name = find("a.c-tile").native.accessible_name
      expect(name).to include("Lightning Bolt")
      expect(name).to end_with("Blue binder +1 more")
      expect(name.index("Lightning Bolt")).to be < name.index("Blue binder +1 more")
    end
  end
```

- [ ] Run: `bin/rspec spec/system/collection_row_place_spec.rb -e "a tile"` — expect PASS. Mutation check: in `app/views/collections/_tile.html.erb` temporarily add `aria-hidden="true"` to the `c-tile__place-more` span; re-run — expect FAIL; `git checkout -- app/views/collections/_tile.html.erb`. If the name lacks the space between the spans (for example "Blue binder+1 more"), that is a real gap of spec 033: report it and fix the template, not the example.
- [ ] Commit: `test(collection): a tile link's accessible name holds the whole place line (spec 048 AC-2.2)`

### Task 8: AC-2.4, the core guard

- [ ] Create `spec/collection_places_core_spec.rb`:

```ruby
require "rails_helper"

# Spec 033 FR-6, spec 048 AC-2.4: the place line and the Location column are core code. The files spec 033 changed
# (git diff --name-only a3baf0d^1 a3baf0d, less the stylesheet and the specs) name no collectible type or source.
# Finish names are not checked: a comment in lots_helper.rb names one.
RSpec.describe "The place line's core code", type: :config do
  let(:files) do
    %w[
      app/models/collection_grid.rb app/models/collection_table.rb app/models/collection_filter.rb
      app/helpers/lots_helper.rb app/views/collections/_tile.html.erb app/views/collections/_table.html.erb
      app/views/collections/_lot_cells.html.erb
    ]
  end

  it "exists, every file of it" do
    expect(files.reject { |file| Rails.root.join(file).exist? }).to be_empty
  end

  it "never names a collectible type or a source" do
    named = files.select { |file| Rails.root.join(file).exist? && Rails.root.join(file).read.match?(/\b(mtg|scryfall|magic)\b/i) }

    expect(named).to be_empty
  end
end
```

- [ ] In `.rubocop.yml`, add `- "spec/collection_places_core_spec.rb"` to the `RSpec/DescribeClass` `Exclude` list (alphabetically, after `spec/collection_import_core_spec.rb`) and extend the comment above the list: "the collection places core spec those of the place line's files (spec 048 AC-2.4)". The file's string `describe` with `type: :config` is the pattern of `spec/import_apply_core_spec.rb` and `spec/number_entry_core_spec.rb`, which are excluded for it.
- [ ] Run: `bin/rubocop spec/collection_places_core_spec.rb .rubocop.yml` — expect no offenses; `bin/rspec spec/collection_places_core_spec.rb` — expect PASS. Mutation check: temporarily add `<%# MTG %>` to `app/views/collections/_tile.html.erb`; re-run — expect the second example FAIL; `git checkout -- app/views/collections/_tile.html.erb`.
- [ ] Commit: `test(collection): guard the place line's core files against naming a collectible (spec 048 AC-2.4)`

---

## Phase 3: Verification and the documents (Story 3, AC-3.2)

**Implements:** AC-3.1, AC-3.2 | **Satisfies:** AC-3.1, AC-3.2
**Files:** `docs/specs/048-row-place-line/verification.md`, `docs/specs/048-row-place-line/screenshots/`, `docs/architecture/collection-and-lots.md`, `docs/specs/README.md`, `docs/specs/033-location-on-tiles-and-rows/spec.md` (its frozen line only)
**Interfaces:** Consumes: Phases 1–2. Produces: nothing code depends on.

Done by the supervisor, not an implementer.

### Task 9: Evidence and screenshots

- [ ] Run each spec file the branch touched, one run at a time: `bin/rspec spec/system/collection_row_place_spec.rb`, `spec/system/collection_table_spec.rb`, `spec/system/collection_spec.rb`, `spec/requests/collection_places_spec.rb`, `spec/models/collection_grid_spec.rb`, `spec/models/collection_table_spec.rb`, `spec/requests/collections_spec.rb`, `spec/requests/bulk_condition_spec.rb`, `spec/requests/bulk_removal_spec.rb`, `spec/collection_places_core_spec.rb`, `spec/requests/query_counts_spec.rb`; record the counts.
- [ ] Screenshots (headless Firefox, per the project's screenshots workflow): the table with a 60-character name at 1280px and 390px, light and dark, plus one frame near the breakpoint (800px) showing the cost of the wrap; read each one. Save under `docs/specs/048-row-place-line/screenshots/`.
- [ ] Write `docs/specs/048-row-place-line/verification.md`: a criterion table (AC → example), the deviation from FR-1's wording (the rule is on the span), the screenshots, the runs, and a "## Implementation review" heading filled by the `sdd-review` Mode B run (opus, read-only) with its verdict on the first line.
- [ ] Commit: `docs(specs): spec 048 verification and screenshots`

### Task 10: The area doc, the index and spec 033's frozen line (AC-3.2)

Done through `distill-feature`, after the implementation review:

- [ ] `docs/architecture/collection-and-lots.md`: the place line bullet states that a tile's line is one line with an ellipsis and a row's wraps (the phone line, and the Location cell in a 20rem span), breaking a name with no space (spec 048 decisions 1–3; maintainer, 2026-10-27 and 2026-11-06); the core-code invariant names `spec/collection_places_core_spec.rb` and no longer says no guard lists spec 033's files; the #142 accepted-limit entry is dropped, #208 (the table's 16px overflow near the breakpoint) is added to the accepted limits, and in Sources' "Issues" line #142 moves out of the open issues and #208 joins them; Decisions not in an ADR gets "a row's place line wraps, a tile's is cut"; Sources lists spec 033 as "all" and adds spec 048 (with #142, #208); the distillation log gets a row.
- [ ] `docs/specs/README.md`: spec 048's row: its Plan cell (now "not yet written") says retired once the plan is retired, and its status becomes Shipped/Frozen as `distill-feature` rules; spec 033's status stops being "frozen in part for decision 5" (Frozen, by collection and lots).
- [ ] `docs/specs/033-location-on-tiles-and-rows/spec.md`: only the frozen line (line 10), in a commit of its own that names spec 027 D4: `docs(specs): mark spec 033 frozen, its decision 5 for rows superseded by spec 048 (spec 027 D4)`.
- [ ] Commit the area doc and the index: `docs(architecture): distil spec 048 into collection and lots (#142)`

---

## Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] `bin/rubocop` — no offenses; `bin/brakeman` — no warnings.
- [ ] The spec runs of Task 9, each green.
- [ ] Before the push, `ask` the coordinator for a push slot (the branch isn't documentation-only, so the pre-push hook runs the full `bin/ci`); release it with the result.
- [ ] Verify each acceptance criterion against `verification.md`; AC-3.1 and AC-3.2 by reading.

---

## Quickstart Validation

1. `bin/rails server` (or the worktree's port), sign in, add a location named `Blue binder, shelf three, left side, behind the board games.` and one named with 60 `W`s, and put a lot in each.
2. Open `/collection?view=table`. At 1280px each row shows its whole name, the cell wraps at about 20rem and the page doesn't scroll sideways. In a 390px frame the line under the name shows the whole name, broken inside the `W`s name, with no sideways scroll.
3. Open `/collection`: a tile's place is still one line with an ellipsis and "+N more" visible.
