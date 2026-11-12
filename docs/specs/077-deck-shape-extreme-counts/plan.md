# Plan 077: The Deck Shape Panel Stays Tidy at Extreme Counts

**Spec:** [spec.md](spec.md) 0.3.1 (approved, Gate A at 0.3.0; decision 2 ruled A; 0.3.1 is a PATCH from the measurements below) | **Issue:** [#320](https://github.com/plainprogrammer/Collector/issues/320) | **Branch:** `077-deck-shape-extreme-counts`

## Global Constraints

- Test first, one commit per task. Targeted `bin/rspec <file>` runs need no CI slot; a full `bin/ci`, or a push whose pre-push hook runs it, needs a slot from the coordinator.
- Never run two test runs at once in this worktree (they share the test database). The untracked `spec/system/zz_077_*` throwaway files are the supervisor's; don't run, edit or commit them.
- The app diff is exactly `app/models/mtg/deck_shape.rb`, `app/views/mtg/deck_shapes/_parts.html.erb` and `app/assets/stylesheets/collector/additions.css` (AC-6.1); the CSS edits stay inside the two DeckShape blocks (card types, mana bar) and use tokens (`var(--space-2)`, `var(--line)`…) wherever the block already does; nothing else in `additions.css` is touched, reordered or reformatted (four other workers edit it).
- Commit trailer: the `Co-Authored-By` line the session's attribution reminder gives (earlier commits of this branch carry a different one; leave them), as a second message: `git commit -m "<subject>" -m "Co-Authored-By: …"`. One git operation per shell call (stage with `git add <paths>`, then `git commit`). `plan.md` itself is committed at Gate B, before batch A starts. Never `git add -A`: the untracked `spec/system/zz_077_*_spec.rb` throwaways must not be committed.
- Off limits: `.kamal/secrets`, `config/master.key`, `.env*`, `storage/`, `*.sqlite3`; every `git grep` ends with `':!.kamal/secrets'`.
- Run `bin/rubocop -a` on each Ruby file written (the project's hook does too); array literals use the omakase style `[ a, b ]`. New public code carries a YARD comment: a summary, `@param`, `@return`, and the why (`.claude/rules/code-documentation.md`); a `{…}` in a comment is YARD link syntax, so put braces in backticks.
- Geometry examples size every viewport frame from the measured scrollbar (the viewport plus `window.innerWidth − documentElement.clientWidth`) and compare against `clientWidth`, never `innerWidth` (lessons of 2026-11-11 on phone widths and measurement traps); the 366px and 640px frames are fixed frame widths by the spec's words, and the aside is a 1280px window.
- Every geometry example has a failing variant in the same file (spec Notes; lesson `an-example-that-cannot-fail-proves-nothing`): the old text or the old rule injected into the page, expecting the predicate to be false.

## Goal

`MTG::DeckShape` gets `short_count` and `caption_items`; the partial writes a curve column's count and a mana segment's label through `short_count` and the caption as unbreakable items; the card types list becomes a grid whose rows are subgrids; one nowrap rule is added for the items; the component document, three previews and the area doc say so (spec decisions 1 to 5, FR-1 to FR-4).

## Pre-implementation gates

- **Simplicity:** one model class gains two methods and two constants, one partial changes, two CSS blocks change. No new component, dependency, class or abstraction. Pass.
- **Anti-abstraction:** `short_count` is a few lines of integer arithmetic; `number_to_human` is not used (spec decision 5: it keeps two significant digits, 123,456 would read "120k"). Pass.
- **Integration-first:** the contract is the two public methods' return values (AC-1.1, AC-4.1) and the rendered markup (AC-1.2, AC-2.1, AC-4.2); Task 1 and Task 2 write them as examples before any code. Pass.

## Measurements taken before this plan (2026-11-11, headless Firefox, the unchanged code; throwaway `zz_077_measure_spec.rb`)

- **The label band** (a 320px viewport, a 236px bar): a mana label fits its segment (one line, within the segment's `clientWidth` less 2px) from a share of 20% for six characters, 17% for five and 14% for four, on a half-percent grid. The fixture's five equal segments are 19.99% to 20.02%, right at the six-character line (0.44px of room): the thin margin of AC-2.2.
- **The leading dot:** the old caption starts a line with "·" at 16 of 72 frame widths from 255px to 468px (a fold open), among them frames of 285px, 321px, 363px, 366px, 369px, 402px and 438px; at a 366px frame the interior is 269px on a Mac and 272px on the Linux runner, both in the list, so the spec's 366px frame is robust to the scrollbar's width. At a 320px viewport (a 335px frame) the old caption breaks between colours, so the variant of AC-4.3 does not use it; at 345px and 360px it splits "Green / 2,591" and "Black / 2,591".
- These go into `verification.md` and into `DeckShape.md`'s known limit (Task 5).

## The existing examples this changes (from a grep, not from memory)

Command (run 2026-11-11 from the repo root): `git grep -n -i -E "c-curve__count|c-manabar__seg|c-manacap|c-types|\.caption\b|countRoom|1,357|2,591|4\.5rem" -- spec docs/design-system docs/architecture app ':!.kamal/secrets'`, read hit by hit.

| Hit | Disposition |
|---|---|
| `spec/system/deck_shape_panel_spec.rb:129-134` (the AC-5.3 comment: "a CSS question raised with the maintainer, not decided here") and `:102-106` (`open_fold_fit` measures `.c-curve__count`, `.c-types li > *`, `.c-manacap` for clipping) | the comment is rewritten (Task 2 Step 4); the example's assertions are unchanged and must stay green (AC-6.2) |
| `spec/models/mtg/deck_shape_spec.rb:253, 293, 315` (`caption` strings, `be_nil`) | kept: `caption` returns the same string (AC-4.1); they stay green and guard it |
| `spec/requests/deck_shape_panel_spec.rb:79-82, 93` (segment texts "U 6", "R 3", caption strings) and `:112` (`.c-curve__count` texts `%w[0] * 7`) | kept: below 1,000 nothing changes and the paragraph's `text` is the same string (AC-4.2) |
| `spec/system/design_system_deck_components_spec.rb:82-111, 327-475` (builds its own `c-curve`, `c-types`, `c-manabar` markup; AC-3.3 guards the types' alignment) | kept; run after the CSS (Task 4) |
| `spec/requests/deck_shape_panel_spec.rb:78, 103, 116`, `spec/system/deck_shape_panel_spec.rb:154` (the segments' classes and style, the paint example's `.c-manabar__seg` tokens) | kept: the markup of a segment and its tokens don't change |
| `docs/design-system/README.md:138` (the App additions list of `DeckShape`'s classes) | gains `c-manacap__item` (Task 5 Step 3b) |
| `docs/design-system/components/DeckShape.md:15-27, 55-56, 60, 64, 68-69, 72-79, 88` | rewritten (Task 5) |
| `docs/design-system/previews/DeckShape.html:45, 40, 72, 102, 112`, `DeckPage.html:58, 85`, `DeckPagePhone.html:58, 85` (the caption paragraphs and one stale width comment) | rewritten (Task 5) |
| `docs/architecture/collection-and-lots.md:137` (the panel's paragraph), `:244-246` (Named constants), `:312` (the Issues bullet naming #320) | rewritten or extended (Task 5) |
| `docs/specs/**` (060, 069 and their `verification.md`) | history, not edited |

## File structure

| File | Responsibility |
|---|---|
| `app/models/mtg/deck_shape.rb` | `SHORT_COUNT_STEP`, `SHORT_COUNT_UNITS`, `#short_count`, `#caption_items`; `#caption` built from the items |
| `app/views/mtg/deck_shapes/_parts.html.erb` | the column count and the segment label through `short_count`; the caption as items |
| `app/assets/stylesheets/collector/additions.css` | the card types block (grid, subgrid rows) and the mana bar block (`.c-manacap__item`) |
| `spec/models/mtg/deck_shape_spec.rb` | AC-1.1, AC-4.1 |
| `spec/requests/deck_shape_panel_spec.rb` | AC-1.2, AC-2.1, AC-4.2 |
| `spec/system/deck_shape_panel_spec.rb` | a nested `describe` with AC-1.3, AC-2.2, AC-3.1, AC-3.2, AC-3.1b, AC-4.3 and their failing variants (spec FR-3), and the stale comment (AC-6.2) |
| `docs/design-system/components/DeckShape.md`, three previews, `docs/architecture/collection-and-lots.md`, `docs/specs/README.md` | Story 5 |
| `docs/specs/077-deck-shape-extreme-counts/{screenshots/,verification.md}` | evidence, the grep, the review record |

Batches for implementer subagents (`sonnet`, read `plan.md` by line range, one TDD commit per task, the supervisor checks each batch's diff): **A** = Tasks 1–2, **B** = Tasks 3–4, **C** = Task 5. Task 6 is the supervisor's.

---

## Phase 1: The figures and the examples, red first

**Implements:** FR-1, FR-3 | **Satisfies:** AC-1.1, AC-4.1 (model); AC-1.2, AC-2.1, AC-4.2 (request); AC-1.3, AC-2.2, AC-3.1, AC-3.2, AC-3.1b, AC-4.3 (system) | **Files:** `app/models/mtg/deck_shape.rb`, three spec files | **Interfaces:** `MTG::DeckShape#short_count(number) → String`, `MTG::DeckShape#caption_items → Array<String>`

### Task 1: `short_count` and `caption_items`

**Step 1: write the failing model examples.** Append inside `RSpec.describe MTG::DeckShape` in `spec/models/mtg/deck_shape_spec.rb`, before the final `end`:

```ruby
  # Spec 077 decision 5: a count in a slot of fixed width is written with a unit from 1,000.
  describe "#short_count" do
    it "writes 0 to 999 as they are and 1,000 up with one decimal under 10,000, whole from there, half up (AC-1.1)", :aggregate_failures do
      expected = { 0 => "0", 999 => "999", 1_000 => "1k", 1_049 => "1k", 1_050 => "1.1k", 1_350 => "1.4k", 1_357 => "1.4k", 9_949 => "9.9k",
                   9_950 => "10k", 9_999 => "10k", 10_000 => "10k", 12_345 => "12k", 123_456 => "123k", 999_499 => "999k", 999_500 => "1m",
                   1_250_000 => "1.3m", 12_000_000 => "12m" }

      figures = shape
      expected.each { |number, text| expect(figures.short_count(number)).to eq(text), "for #{number}" }
      expect(expected.keys.map { figures.short_count(it).length }.max).to be <= 4
    end

    it "rounds 1,349 down to 1.3k and a count that reaches 1,000 of its unit moves to the next, 9,999,500 being 10m", :aggregate_failures do
      expect(shape.short_count(1_349)).to eq("1.3k")
      expect(shape.short_count(9_999_500)).to eq("10m")
      expect(shape.short_count(2_000_000_000)).to eq("2b")
    end
  end

  # Spec 077 decision 4: the caption as items a view can keep whole.
  describe "#caption_items" do
    # Spec 069's worst case: 123 owned five-colour creatures, 1,234 proxies of a hybrid card and 4 Bolts, red being 2,595.
    def worst_case
      own(card(name: "Worst", type_line: "Creature — Elf", cost: "{2}{W}{U}{B}{R}{G}", mana_value: 7.0), 123)
      proxy(card(name: "Gleemax", cost: "{W/U}{U/B}{B/R}{R/G}{G/W}", mana_value: 1_000_000.0), 1_234)
      own(card(name: "Bolt", cost: "{R}", mana_value: 1.0), 4)
    end

    it "gives one item per colour, each but the last ending in the separator, and `caption` is the items joined (AC-4.1)", :aggregate_failures do
      worst_case
      figures = shape

      expect(figures.caption).to eq("White 2,591 · 20% · Blue 2,591 · 20% · Black 2,591 · 20% · Red 2,595 · 20% · Green 2,591 · 20%")
      expect(figures.caption_items).to eq([ "White 2,591 · 20% ·", "Blue 2,591 · 20% ·", "Black 2,591 · 20% ·", "Red 2,595 · 20% ·", "Green 2,591 · 20%" ])
      expect(figures.caption_items.join(" ")).to eq(figures.caption)
    end

    it "has one item with no trailing separator for one colour, and none for no colour (AC-4.1)", :aggregate_failures do
      own(card(cost: "{1}"))
      expect(shape.caption_items).to eq([])
      expect(shape.caption).to be_nil

      own(card(cost: "{R}"), 3)
      expect(shape.caption_items).to eq([ "Red 3 · 100%" ])
    end
  end
```

**Step 2: run it and watch it fail.** `bin/rspec spec/models/mtg/deck_shape_spec.rb -e "short_count" -e "caption_items"` → `NoMethodError: undefined method 'short_count'` and `'caption_items'`. (The existing `caption` examples are untouched and green.)

**Step 3: implement** in `app/models/mtg/deck_shape.rb`. Add the constants after `COLOURS` (after line 122):

```ruby
  # Counts below this are written in full; from it a count in a slot of fixed width takes a unit, and each unit is this many of the one
  # before (spec 077 decision 5). The abbreviation is uniform, not width-driven: the server cannot know the width, and a count that
  # fits at a 360px viewport still overflows at 320px.
  SHORT_COUNT_STEP = 1_000
  # The units of an abbreviated count: thousands, millions, billions.
  SHORT_COUNT_UNITS = %w[k m b].freeze
```

Replace `#caption` (lines 138-142: from the comment `# "White 2 · 25% · Blue 4 · 50%": every colour present with its count and percentage.` through the `end` after `.join(" · ").presence`) with:

```ruby
  # "White 2 · 25% · Blue 4 · 50%": every colour present with its count and percentage, exact (the abbreviation is for a slot of
  # fixed width and this is prose). Built from {#caption_items}.
  # @return [String, nil] nil when there is no coloured symbol
  def caption = caption_items.join(" ").presence

  # The caption as one string per colour, "White 2 · 25% ·" and, last, "Blue 4 · 50%": every item but the last ends in the separator, so a
  # view that sets each item as an unbreakable unit lets a line break only between items and never before a "·" (spec 077 decision 4,
  # #320). Joined with one space they are {#caption}, character for character.
  # @return [Array<String>] empty when there is no coloured symbol
  def caption_items
    items = symbols.map { |s| "#{COLOURS[s.colour].capitalize} #{delimited(s.count)} · #{s.percent}%" }
    items.each_with_index.map { |item, index| index == items.size - 1 ? item : "#{item} ·" }
  end

  # A count written for a slot of fixed width, the curve's column count and a mana segment's label (spec 077 decisions 1, 2 and 5, #320).
  # Below 1,000 it is the number as it is. From there it takes a unit: one decimal under 10 of the unit with a trailing ".0" dropped
  # ("1.4k", "2k"), whole from 10 ("12k", "123k"), rounded half up on exact integers (1,350 is "1.4k", 1,349 "1.3k"). A value that
  # rounds to 1,000 of its unit moves to the next unit (999,500 is "1m"), and one that rounds to 10.0 is written whole (9,999 is "10k"),
  # so nothing is longer than four characters through "999m". It is not `number_to_human`, which keeps two significant digits (123,456
  # would read "120k"). The exact number stays in every `aria-label`, the legend, the caption and the types.
  #
  # @example
  #   short_count(999)     # => "999"
  #   short_count(1_357)   # => "1.4k"
  #   short_count(9_999)   # => "10k"
  #   short_count(999_500) # => "1m"
  # @param number [Integer] a count, 0 or more
  # @return [String]
  def short_count(number)
    return delimited(number) if number < SHORT_COUNT_STEP

    value = Rational(number, SHORT_COUNT_STEP)
    unit = 0
    while value.round >= SHORT_COUNT_STEP && unit < SHORT_COUNT_UNITS.size - 1
      value /= SHORT_COUNT_STEP
      unit += 1
    end
    tenths = (value * 10).round
    body = if value < 10 && tenths < 100
      (tenths % 10).zero? ? (tenths / 10).to_s : format("%d.%d", *tenths.divmod(10))
    else
      value.round.to_s
    end
    "#{body}#{SHORT_COUNT_UNITS[unit]}"
  end
```

(`{#caption_items}` and `{#caption}` are YARD links to methods of the same class and resolve; if `bin/yard doc` warns, put them in backticks.)

**Step 4: run** `bin/rspec spec/models/mtg/deck_shape_spec.rb` → all green (the 069 `caption` examples included), then `bin/rubocop -a app/models/mtg/deck_shape.rb spec/models/mtg/deck_shape_spec.rb`.

**Step 5: commit** (two calls): `git add app/models/mtg/deck_shape.rb spec/models/mtg/deck_shape_spec.rb`, then `git commit -m "feat(deck-shape): short_count and caption_items on the figures (#320)"` with the trailer.

### Task 2: the request and system examples, red

**Step 1: the request examples.** Append inside `RSpec.describe "Deck shape panel", type: :request` in `spec/requests/deck_shape_panel_spec.rb`, before the final `end`:

```ruby
  # Spec 077: the worst case's numbers in a slot of fixed width are abbreviated, and everything that can carry the exact number does.
  describe "counts in a slot of fixed width (spec 077, #320)" do
    # Spec 069's worst case: a 6+ column of 1,357 (123 owned, 1,234 proxy), five single cards and Bolt in column 1, 20 lands, and a
    # five-colour mana bar of about 2,591 symbols a colour (red 2,595: Bolt's {R} times 4).
    before do
      own(card(name: "Worst", type_line: "Creature — Elf", cost: "{2}{W}{U}{B}{R}{G}", mana_value: 7.0), 123)
      proxy(card(name: "Gleemax", type_line: "Creature — Elf", cost: "{W/U}{U/B}{B/R}{R/G}{G/W}", mana_value: 1_000_000.0), 1_234)
      own(card(name: "Bolt", cost: "{R}", mana_value: 1.0), 4)
      5.times { own(card(type_line: "Sorcery", cost: "{1}", mana_value: 1.0)) }
      own(card(name: "Island", type_line: "Basic Land — Island", cost: "", mana_value: 0.0), 20)
      get deck_path(deck)
    end

    it "abbreviates a column's count from 1,000 and keeps the exact numbers in the label and the legend (AC-1.2)", :aggregate_failures do
      expect(html.css("aside .c-curve__count").map(&:text)).to eq(%w[0 9 0 0 0 0 1.4k])
      expect(html.at_css("aside .c-curve [role=img]")["aria-label"]).to include("6+, 1,357 cards (123 owned, 1,234 proxy)")
      expect(html.css("aside .c-curve__legend li").map(&:text)).to eq([ "Owned 132", "Proxy 1,234" ])
    end

    it "abbreviates a segment's label and keeps the bar's label and the caption exact (AC-2.1)", :aggregate_failures do
      expect(html.css("aside .c-manabar__seg span").map(&:text)).to eq([ "W 2.6k", "U 2.6k", "B 2.6k", "R 2.6k", "G 2.6k" ])
      expect(html.at_css("aside .c-manabar")["aria-label"]).to eq("Coloured mana symbols in Main: white 2,591, blue 2,591, black 2,591, red 2,595, green 2,591")
      expect(html.at_css("aside .c-manacap").text).to eq("White 2,591 · 20% · Blue 2,591 · 20% · Black 2,591 · 20% · Red 2,595 · 20% · Green 2,591 · 20%")
    end

    it "sets each caption item as a `c-manacap__item` span and the paragraph's text is the caption string (AC-4.2)", :aggregate_failures do
      items = html.css("aside .c-manacap .c-manacap__item")

      expect(items.map(&:text)).to eq([ "White 2,591 · 20% ·", "Blue 2,591 · 20% ·", "Black 2,591 · 20% ·", "Red 2,595 · 20% ·", "Green 2,591 · 20%" ])
      expect(html.at_css("aside .c-manacap").text).to eq(items.map(&:text).join(" "))
    end

    it "keeps the types' counts and suffix exact (the rows have room)" do
      expect(html.css("aside .c-types li").first.css("span").map(&:text)).to eq([ "Creatures", "1,357", "1,234 proxy" ])
    end
  end
```

**Step 2: the system examples.** Append a nested `describe` inside `RSpec.describe "Deck shape panel", type: :system do` in `spec/system/deck_shape_panel_spec.rb`, before that block's final `end` (spec FR-3 names this file; its top-level `before` already builds spec 069's worst-case fixture on `deck`: a 6+ column of 1,357, five mana segments of about 2,591 (red 2,595), a five-colour caption, and its `set_theme`, `card(name:, type_line:, cost:, mana_value:)` and `create_lot_in_zone` helpers are reused; nothing in the file above changes):

```ruby
  # Spec 077 (#320): the panel at extreme counts at a 320px, 345px and 360px viewport (a real 320px phone, a 360px browser frame, a
  # 360px phone), a 366px frame (where the old caption leads a line with a dot), a 640px frame (the fold again) and the 320px aside at
  # 1280px, in both themes. The viewport frames are sized from the measured scrollbar (the viewport plus `innerWidth - clientWidth`: 15px
  # on a Mac, about 12px on the Linux runner) and read against `documentElement.clientWidth` (lessons of 2026-11-11 on phone widths and
  # measurement traps); the 366px and 640px frames are fixed frame widths by the spec's words, not viewports. Each geometry example has a
  # failing variant: the old text or the old rule injected into the page.
  # The file's memoized helpers (user, account, deck) plus the two lets below are at the cop's limit of five: another deck an example needs is
  # a local (`plain = create(:deck, …)`, as AC-3.2 does), not another `let`.
  describe "extreme counts (spec 077, #320)" do
    let(:rows_deck) { create(:deck, account:, name: "Rows") }
    let(:wide_deck) { create(:deck, account:, name: "Wide rows") }

    def plain_card(name:, type_line: "Creature — Elf") = card(name:, type_line:, cost: "{1}", mana_value: 2.0)
    def own_in(in_deck, entry, quantity) = create_lot_in_zone(in_deck, "main", entry:, quantity:)
    def proxy_in(in_deck, entry, quantity) = create(:deck_proxy, zone: in_deck.zone("main"), account:, entry:, quantity:)

    # AC-3.1's rows: "Creatures" 1,357 with "1,234 proxy", "Instants" 9,999 with "9,999 proxy", "Artifacts" 3 and "Lands" 20 with none.
    def build_rows
      own_in(rows_deck, plain_card(name: "Rows elf"), 123)
      proxy_in(rows_deck, plain_card(name: "Rows elf proxy"), 1_234)
      proxy_in(rows_deck, plain_card(name: "Rows bolt", type_line: "Instant"), 9_999)
      own_in(rows_deck, plain_card(name: "Rows ring", type_line: "Artifact"), 3)
      own_in(rows_deck, card(name: "Rows island", type_line: "Basic Land — Island", cost: "", mana_value: 0.0), 20)
    end

    # AC-3.1b's rows: "Planeswalkers" 12,345 with "12,345 proxy" (a proxy takes at most 9,999, so two) and "Lands" 20, a second row so that
    # "the counts end at one x" can fail.
    def build_wide_row
      proxy_in(wide_deck, plain_card(name: "Wide jace", type_line: "Legendary Planeswalker — Jace"), 9_999)
      proxy_in(wide_deck, plain_card(name: "Wide ajani", type_line: "Legendary Planeswalker — Ajani"), 2_346)
      own_in(wide_deck, card(name: "Wide island", type_line: "Basic Land — Island", cost: "", mana_value: 0.0), 20)
    end

    def widths = [ 320, 345, 360, :frame366, :frame640, :aside ]
    def fold_panel = "details.c-shapefold .c-shape"
    def open_fold = page.execute_script('document.querySelector("details.c-shapefold").open = true')
    def inject_css(rules) = page.execute_script("const style = document.createElement('style'); style.textContent = #{rules.to_json}; document.head.append(style)")

    # A frame whose viewport is `viewport` px wide with the fold open: the viewport plus the scrollbar the frame draws (measured, then
    # the frame is reopened if it was not 15px). Returns the viewport it got, for the example to assert.
    def open_fold_in_frame(path, viewport)
      width = viewport + 15
      2.times do
        open_in_narrow_frame(path, width:, ready: "details.c-shapefold")
        scrollbar = within_narrow_frame do
          open_fold
          page.evaluate_script("window.innerWidth - document.documentElement.clientWidth")
        end
        break if viewport + scrollbar == width

        width = viewport + scrollbar
      end
      within_narrow_frame { page.evaluate_script("document.documentElement.clientWidth") }
    end

    # Opens the deck page as `width` says (a viewport in px, a fixed frame, or :aside at 1280px) and yields the panel's selector, inside
    # the frame where there is one.
    def at_width(width, path)
      case width
      when Integer
        expect(open_fold_in_frame(path, width)).to eq(width)
        within_narrow_frame { yield fold_panel }
      when :frame366, :frame640
        open_in_narrow_frame(path, width: { frame366: 366, frame640: 640 }.fetch(width), ready: "details.c-shapefold")
        within_narrow_frame do
          open_fold
          yield fold_panel
        end
      when :aside
        visit path
        page.driver.browser.manage.window.resize_to(1280, 900)
        expect(page).to have_css("aside.c-deck__shape")
        yield "aside .c-shape"
      end
    end

    # What the panel measures: per curve column its room (the column's width less its count's scrollWidth), what is drawn past the
    # padding box, per visible mana label its line count, its text width, its segment's content width and whether the text's box is inside
    # its segment's box, the Card types rows' right edges, and per caption item its line count and the first character of every caption line.
    def measure(selector)
      page.evaluate_script(<<~JS)
        (() => { const panel = document.querySelector(#{selector.to_json}), edge = panel.getBoundingClientRect().right - parseFloat(getComputedStyle(panel).paddingRight)
          const textRange = (el) => { const r = document.createRange(); r.selectNodeContents(el); return r }
          const lines = (el) => new Set([...textRange(el).getClientRects()].map((q) => Math.round(q.top))).size
          const cols = [...panel.querySelectorAll(".c-curve__col")], rows = [...panel.querySelectorAll(".c-types li")], list = panel.querySelector(".c-types")
          const labels = [...panel.querySelectorAll(".c-manabar__seg span")].filter((s) => s.getClientRects().length)
          const starts = new Map(), caption = panel.querySelector("p.c-manacap"), walker = document.createTreeWalker(caption, NodeFilter.SHOW_TEXT)
          for (let node = walker.nextNode(); node; node = walker.nextNode()) { for (let i = 0; i < node.length; i++) { const r = document.createRange(); r.setStart(node, i); r.setEnd(node, i + 1)
            const box = r.getClientRects()[0]; if (box && node.data[i] !== " " && !starts.has(Math.round(box.top))) starts.set(Math.round(box.top), node.data[i]) } }
          return { viewport: document.documentElement.clientWidth,
            scrolls: panel.scrollWidth > panel.clientWidth,
            beyond: [...panel.querySelectorAll("*")].filter((el) => el.getClientRects().length && el.getBoundingClientRect().right > edge + 0.5).length,
            clipped: [...panel.querySelectorAll(".c-curve__count, .c-types li > *, .c-curve__legend li, .c-curve__avg, .c-manacap")].filter((el) => el.scrollWidth > el.clientWidth + 1).length,
            countRoom: cols.length ? Math.min(...cols.map((col) => col.getBoundingClientRect().width - col.querySelector(".c-curve__count").scrollWidth)) : 0,
            labels: labels.map((s) => { const box = textRange(s).getBoundingClientRect(), seg = s.parentElement.getBoundingClientRect()
              return { lines: lines(s), text: box.width, room: s.parentElement.clientWidth, inside: box.left >= seg.left - 0.5 && box.right <= seg.right + 0.5 } }),
            rights: rows.map((li) => li.children[1].getBoundingClientRect().right),
            suffixGap: rows.map((li) => Math.abs(li.getBoundingClientRect().right - li.children[2].getBoundingClientRect().right)),
            suffixWidth: rows.map((li) => li.children[2].getBoundingClientRect().width),
            rowOver: rows.filter((li) => li.getBoundingClientRect().right > list.getBoundingClientRect().right + 0.5 || li.scrollWidth > li.clientWidth + 1).length,
            cut: rows.flatMap((li) => [...li.children]).filter((el) => el.scrollWidth > el.clientWidth + 1).length,
            itemLines: [...panel.querySelectorAll(".c-manacap__item")].map(lines),
            lineStarts: [...starts.values()] } })()
      JS
    end

    # `clientWidth` is a whole number, so a 46.38px segment reads 46 and a label has 0.44px to spare at a 320px viewport (the bound is 2px).
    def counts_fit?(found) = found["countRoom"] >= 0 && !found["scrolls"] && found["beyond"].zero? && found["clipped"].zero?
    def labels_fit?(found) = found["labels"].any? && found["labels"].all? { |label| label["lines"] == 1 && label["inside"] && label["text"] <= label["room"] - 2 }
    def counts_aligned?(found) = (found["rights"].max - found["rights"].min) <= 0.5
    def types_tidy?(found) = counts_aligned?(found) && found["suffixGap"].all? { it <= 0.5 } && found["rowOver"].zero? && found["cut"].zero?
    def wide_row_tidy?(found) = found["rowOver"].zero? && found["cut"].zero? && counts_aligned?(found) && found["rights"].size == 2
    def floor_held?(found) = counts_aligned?(found) && found["suffixWidth"].all? { it >= 71.5 }
    def caption_whole?(found) = found["itemLines"].any? && found["itemLines"].all?(1) && found["lineStarts"].none?("·")

    # Measures in each theme (layout cannot depend on it, so there is no wait for the 0.12s colour transition here; the second reading is a
    # guard) and expects the block to hold.
    def expect_in_both_themes(width, selector)
      %w[light dark].each do |theme|
        set_theme(theme)
        found = measure(selector)
        expect(yield(found)).to be(true), "at #{width} in #{theme}: #{found.inspect}"
      end
    end

    it "keeps every curve count inside its column and the panel inside its box at every width, in both themes (AC-1.3)", :aggregate_failures do
      widths.each { |width| at_width(width, deck_path(deck)) { |panel| expect_in_both_themes(width, panel) { counts_fit?(it) } } }
    end

    it "can fail: the full count in the 6+ column overflows its column at a 320px and a 345px viewport (AC-1.3)", :aggregate_failures do
      [ 320, 345 ].each do |viewport|
        at_width(viewport, deck_path(deck)) do |panel|
          page.execute_script('document.querySelector("details.c-shapefold .c-curve__col:last-child .c-curve__count").textContent = "1,357"')
          expect(counts_fit?(measure(panel))).to be(false), "at #{viewport}"
        end
      end
    end

    it "keeps every mana label on one line inside its segment at every width, in both themes (AC-2.2)", :aggregate_failures do
      widths.each { |width| at_width(width, deck_path(deck)) { |panel| expect_in_both_themes(width, panel) { labels_fit?(it) } } }
    end

    it "can fail: a label written in full wraps inside its segment at a 320px viewport (AC-2.2)" do
      at_width(320, deck_path(deck)) do |panel|
        page.execute_script('document.querySelectorAll("details.c-shapefold .c-manabar__seg span").forEach((span) => { span.textContent = span.textContent.replace("2.6k", "2,591") })')
        expect(labels_fit?(measure(panel))).to be(false)
      end
    end

    it "ends every Card types count at one x with the suffix at the row's edge, nothing cut off, at every width (AC-3.1)", :aggregate_failures do
      build_rows
      widths.each { |width| at_width(width, deck_path(rows_deck)) { |panel| expect_in_both_themes(width, panel) { types_tidy?(it) } } }
    end

    it "can fail: flex rows with a 4.5rem suffix put the 9,999 proxy row's count left of the others' (AC-3.1)" do
      build_rows
      at_width(320, deck_path(rows_deck)) do |panel|
        inject_css(".c-types{display:block !important} .c-types li{display:flex !important;gap:var(--space-2)} .c-types__n{margin-left:auto !important}")
        expect(types_tidy?(measure(panel))).to be(false)
      end
    end

    it "keeps each empty suffix cell at its 4.5rem floor and the counts at one x when no row has a proxy (AC-3.2)", :aggregate_failures do
      plain = create(:deck, account:, name: "Plain")
      own_in(plain, plain_card(name: "Plain elf"), 5)
      own_in(plain, plain_card(name: "Plain ring", type_line: "Artifact"), 3)
      [ 360, :aside ].each { |width| at_width(width, deck_path(plain)) { |panel| expect_in_both_themes(width, panel) { floor_held?(it) } } }
    end

    it "can fail: without the floor the empty suffix cells collapse (AC-3.2)" do
      plain = create(:deck, account:, name: "Plain")
      own_in(plain, plain_card(name: "Plain elf"), 5)
      at_width(360, deck_path(plain)) do |panel|
        inject_css(".c-types__proxy{min-width:0 !important}")
        expect(floor_held?(measure(panel))).to be(false)
      end
    end

    it "keeps a five-digit row inside the list with the counts at one x at a 320px viewport, the name wrapping (AC-3.1b)" do
      build_wide_row
      at_width(320, deck_path(wide_deck)) { |panel| expect_in_both_themes(320, panel) { wide_row_tidy?(it) } }
    end

    it "can fail: without the name cell's wrap rule the name spills over its cell (AC-3.1b)" do
      build_wide_row
      at_width(320, deck_path(wide_deck)) do |panel|
        inject_css(".c-types li > :first-child{overflow-wrap:normal !important}")
        expect(wide_row_tidy?(measure(panel))).to be(false)
      end
    end

    it "keeps every caption item on one line and no caption line starting with a dot at every width (AC-4.3)", :aggregate_failures do
      widths.each { |width| at_width(width, deck_path(deck)) { |panel| expect_in_both_themes(width, panel) { caption_whole?(it) } } }
    end

    it "can fail: without the nowrap rule an item splits at a 345px and a 360px viewport and a line starts with a dot in a 366px frame (AC-4.3)", :aggregate_failures do
      [ 345, 360, :frame366 ].each do |width|
        at_width(width, deck_path(deck)) do |panel|
          inject_css(".c-manacap__item{white-space:normal !important}")
          found = measure(panel)
          expect(caption_whole?(found)).to be(false), "at #{width}: #{found.inspect}"
          expect(found["lineStarts"]).to include("·") if width == :frame366
        end
      end
    end
  end
```

**Step 3: run them and watch them fail.** `bin/rspec spec/requests/deck_shape_panel_spec.rb -e "spec 077"` → the four examples fail (the column count reads "1,357", the label "W 2,591", no `c-manacap__item`). `bin/rspec spec/system/deck_shape_panel_spec.rb -e "extreme counts"` → expected red: AC-1.3 (320 and 345: room −5.43 and −1.85), AC-2.2 (320 and 345: the label wraps or doesn't fit; at 345 the label is 50.8px in a 51.4px segment, over the 2px bound), AC-3.1 and AC-3.1b (the old flex rows misalign at every width; the five-digit row's name spills), AC-4.3 (no `c-manacap__item` yet, so `itemLines` is empty and `caption_whole?` is false). The "can fail" examples and the AC-3.2 floor example are already green (they inject the old text or rule, or guard what exists today), except the AC-4.3 variant: it is green for the wrong reason now (no item exists to split), so after Task 3 it must be re-run and must still pass, at all three widths, with the leading dot found at the 366px frame. Record the run's failures in the commit body. If an example is green here that the spec says should be red, stop and read it: it can't fail.

**Step 4: the stale comment.** In `spec/system/deck_shape_panel_spec.rb`, replace the comment above the AC-5.3 example (lines 129-134, from "# A phone's 360px viewport" to "...and a text element cut off at its own box.") with:

```ruby
  # A phone's 360px viewport has no scrollbar and the frame keeps a classic one, so the frame is 360px plus the measured scrollbar
  # (375px with the Mac's 15px). The chain is the viewport's 360px less the body's 16px (8px margin a side, a 344px body), the main's
  # 32px padding (a 312px container), the details' 2px border (310px) and the panel's 32px padding (a 278px inside). A frame with the
  # scrollbar inside a 360px width is 15px narrower (263px inside), where the fixture's count in full ("1,357") overflowed its column by
  # about 1.85px; spec 077 (#320) abbreviates it ("1.4k"), and the "extreme counts" examples below measure that frame and a 320px
  # viewport. Each check can fail: the panel scrolling sideways, an element drawn past the padding box's right edge, and a text element
  # cut off at its own box.
```

**Step 5: commit** (two calls): `git add spec/requests/deck_shape_panel_spec.rb spec/system/deck_shape_panel_spec.rb`, then `git commit -m "test(deck-shape): extreme-count examples, red (#320)"` (body: which examples fail and why).

---

## Phase 2: The partial and the CSS

**Implements:** FR-1, FR-2 | **Satisfies:** AC-1.2, AC-1.3, AC-2.1, AC-2.2, AC-3.1, AC-3.1b, AC-3.3, AC-4.2, AC-4.3, AC-6.1 | **Files:** `app/views/mtg/deck_shapes/_parts.html.erb`, `app/assets/stylesheets/collector/additions.css`

### Task 3: the partial

**Step 1: edit `app/views/mtg/deck_shapes/_parts.html.erb`.** Three changes, nothing else:

Line 7, the column's count: `<%= number_with_delimiter(column.total) %>` becomes `<%= figures.short_count(column.total) %>`.

Line 39, the segment's label: `<span><%= segment.colour %> <%= number_with_delimiter(segment.count) %></span>` becomes `<span><%= segment.colour %> <%= figures.short_count(segment.count) %></span>`.

Line 42, the caption: `<p class="c-manacap"><%= figures.caption %></p>` becomes

```erb
    <p class="c-manacap"><%= safe_join(figures.caption_items.map { |item| tag.span(item, class: "c-manacap__item") }, " ") %></p>
```

The legend (lines 17-18), the types' counts and suffix (line 28) and the `aria-label`s stay `number_with_delimiter` / exact. Update the partial's header comment (line 1) to: `<%# The three parts of the deck shape panel for Magic (spec 069, DeckShape.md): a part of zero has no element. A curve column's count and a mana segment's label are in slots of fixed width, so they are abbreviated from 1,000 (spec 077, MTG::DeckShape#short_count); every other number is exact. %>`.

**Step 2: run** `bin/rspec spec/requests/deck_shape_panel_spec.rb spec/models/mtg/deck_shape_spec.rb` → green. `bin/rspec spec/system/deck_shape_panel_spec.rb -e "extreme counts"` → AC-1.3 and AC-2.2 and both of their variants green; AC-3.1, AC-3.1b and AC-4.3 still red (no CSS). The AC-4.3 variant is now green for the right reason: an item exists, splits at 345px and 360px and a line starts with "·" at the 366px frame.

**Step 3: commit** (two calls): `git add app/views/mtg/deck_shapes/_parts.html.erb`, then `git commit -m "feat(deck-shape): abbreviate the curve count and the segment label, caption as items (#320)"`.

### Task 4: the CSS

**Step 1: the card types block.** In `app/assets/stylesheets/collector/additions.css`, in the block headed `/* ---------- DeckShape card types (spec 060)`, replace the four rules `.c-types`, `.c-types li`, `.c-types__n`, `.c-types__proxy` (the lines after the heading, through the `/* reserved even when empty… */` comment) with:

```css
/* Spec 077 (#320): the list is a grid of three columns and every row takes them as its own (subgrid), so the count column is as
   wide as the widest count and the suffix column as wide as the widest suffix, and every count ends at one x whatever a suffix
   says. The suffix cell keeps its 4.5rem floor so a list of short suffixes looks as it did; the name cell may wrap, even mid-word,
   so a five-digit count and suffix at a 320px viewport never push a row past the list. */
.c-types { display:grid; grid-template-columns:minmax(0, 1fr) auto auto; column-gap:var(--space-2); margin:0; padding:0; list-style:none; border-top:1px solid var(--line); }
.c-types li { display:grid; grid-template-columns:subgrid; grid-column:1 / -1; align-items:baseline; min-height:32px; padding:var(--space-1) 0; border-bottom:1px solid var(--line); font:400 14px/20px var(--font-sans); }
.c-types li > :first-child { min-width:0; overflow-wrap:anywhere; }
.c-types__n { margin-left:auto; font:400 14px/20px var(--font-mono); } /* in a grid cell an auto margin right-aligns it, as in the old flex row */
.c-types__proxy { min-width:4.5rem; text-align:right; font:400 12px/16px var(--font-mono); color:var(--ink-muted); } /* reserved even when empty, so a list with short suffixes keeps its look */
```

**Step 2: the mana bar block.** After the line `.c-manacap { margin:0; font:400 13px/18px var(--font-sans); color:var(--ink-muted); }` add:

```css
.c-manacap__item { white-space:nowrap; } /* spec 077 (#320): a caption line breaks only between colours, so a name stays with its count and no line starts with a dot */
```

**Step 3: run** `bin/rspec spec/system/deck_shape_panel_spec.rb spec/system/design_system_deck_components_spec.rb spec/design_system_files_spec.rb spec/requests/deck_shape_panel_spec.rb spec/requests/query_counts_spec.rb spec/models/mtg/deck_shape_spec.rb spec/deck_core_spec.rb` → all green. If AC-2.2 fails at the 320px viewport by under 1px on a label (the thin 0.44px room, spec Notes), read the measured `text` and `room` in the failure message; do not move the bound: ask the supervisor (a spec update).

**Step 4: commit** (two calls): `git add app/assets/stylesheets/collector/additions.css`, then `git commit -m "feat(deck-shape): card types rows share columns, caption items stay whole (#320)"`.

---

## Phase 3: The documents

**Implements:** FR-4 | **Satisfies:** AC-5.1, AC-5.2, AC-5.3 | **Files:** `docs/design-system/components/DeckShape.md`, `docs/design-system/previews/{DeckShape,DeckPage,DeckPagePhone}.html`, `docs/architecture/collection-and-lots.md`, `docs/specs/README.md`

### Task 5: the component document, the previews and the area doc

**Step 1: `DeckShape.md`.** Make these edits (each a unique string):

- In the markup example, the caption line `<p class="c-manacap">Blue 44 · 73% · Red 16 · 27%</p></div>` becomes `<p class="c-manacap"><span class="c-manacap__item">Blue 44 · 73% ·</span> <span class="c-manacap__item">Red 16 · 27%</span></p></div>`.
- The curve bullet "The count above a column is owned plus proxy, in mono." gains: ` From 1,000 it is abbreviated, one decimal under 10,000 and whole from there ("1.4k", "12k", "1.3m"), half up, never longer than four characters, so it fits a 30px column at a 320px viewport (spec 077 decision 1, 5; \`MTG::DeckShape#short_count\`). The exact column count is in the chart's \`aria-label\` only; the legend shows the curve's totals. Everything else is exact and delimited: the legend, the types' counts and suffixes, the caption, the zone heads and every \`aria-label\`.`
- The Card types bullet "A type with no proxies keeps an empty `c-types__proxy`…" is replaced by: `- The list is a grid of three columns (\`minmax(0, 1fr) auto auto\`, a \`space-2\` column gap) and each row is a \`subgrid\` of it, so the count column is as wide as the widest count and the suffix column as wide as the widest suffix: every count ends at one x whatever a suffix says ("1,234 proxy" is wider than the old 4.5rem minimum). A type with no proxies keeps an empty \`c-types__proxy\`, which keeps a 4.5rem floor so a list with short suffixes looks as it did. The name cell has \`min-width:0\` and \`overflow-wrap:anywhere\`: with a five-digit count and suffix at a 320px viewport ("Planeswalkers 12,345 12,345 proxy") the name wraps inside its cell, even mid-word, and no row passes the list (spec 077 decision 3). Counts and suffix are exact.`
- The mana bar bullet "Each segment fills… The segment's label is its letter and count ("U 44"), in mono." gains: ` From 1,000 the count is abbreviated ("W 2.6k": six characters, about 43.5px, which fits one line in the narrowest five-equal-segment bar at a 320px viewport); the caption and the \`aria-label\` keep the exact count (spec 077 decision 2).`
- The mana bar heading's class list "(`c-manabar`, `c-manacap`, spec 060 decisions 3 and 4, AC-2.6, AC-2.7)" gains `c-manacap__item`.
- The caption bullet ends with: ` The caption is a run of \`c-manacap__item\` spans, "Blue 44 · 73% ·" and, last, "Red 16 · 27%", separated by one space, each \`white-space:nowrap\`: a line breaks only between colours, so no line begins with "·" and a name never parts from its count; the paragraph's text is the same string as before (spec 077 decision 4; \`MTG::DeckShape#caption_items\`).`
- The **Width** paragraph is replaced by:

  `**Width.** The panel works in 238px, the space inside its border and padding at a 320px viewport (a phone's 320px less 16px body margin, 32px page padding, 2px border and 32px panel padding), and every count, the legend, the types and the mana labels fit with no horizontal overflow at the worst-case counts of spec 069's fixture (spec 077 AC-1.3, AC-2.2, AC-3.1). It was drawn for 279px (spec 060 AC-2.4); the measured interiors are 238px (a 320px viewport), 263px (a 360px browser frame, which keeps a 15px scrollbar a phone doesn't), 278px (a 360px viewport) and 286px (the 320px aside; beside the zones the panel is 320px wide, spec 060 decision 6). **Known limits:** (1) a mana segment narrower than its label: a label of four characters ("U 44") needs about 14% of the bar, five ("W 999") about 17% and six ("W 2.6k") about 20% at a 320px viewport (measured to the half percent on a 236px bar), and the rule hides a label only under 10% (spec 060 decision 4), so a segment between 10% and those shares wraps its label and cuts it off; the caption carries the count; it exists at ordinary counts too, and is [#NNN](https://github.com/plainprogrammer/Collector/issues/NNN) (spec 077 decision 2, ruled option A). (2) A Card types row with a five-digit count and suffix at a 320px viewport wraps its name, even mid-word; counts of six digits are not specified.` (Replace `NNN` with the number the coordinator gives for the issue before this task's commit; if it is not known yet, write the sentence with the title instead and fix it in the supervisor's follow-up commit.)

**Step 2: the previews.** In `docs/design-system/previews/DeckShape.html`, `DeckPage.html` and `DeckPagePhone.html`, replace every `<p class="c-manacap">Blue 44 · 73% · Red 16 · 27%</p>` (use `replace_all`) with `<p class="c-manacap"><span class="c-manacap__item">Blue 44 · 73% ·</span> <span class="c-manacap__item">Red 16 · 27%</span></p>`; in `DeckShape.html` the five-colour caption `White 3 · 5% · Blue 20 · 33% · Black 4 · 7% · Red 18 · 30% · Green 15 · 25%` becomes five spans (`White 3 · 5% ·`, `Blue 20 · 33% ·`, `Black 4 · 7% ·`, `Red 18 · 30% ·`, last `Green 15 · 25%`, a space between); in `DeckShape.html` line 45 the comment "(313px wide, 279px inside)" becomes "(on a 360px phone the fold is 312px wide, 278px inside)"; the wrappers' own widths (lines 44, 46–47, 76–77) stay: AC-5.2 asks for the comment only. Open each preview's markup only through these strings; no other line changes.

**Step 3: the area doc, `docs/architecture/collection-and-lots.md`.**

- Line 137, the panel's paragraph: after "…(decisions 9, 14, AC-4.6–AC-4.8)." insert: ` The visible number in a curve column's count and in a mana segment's label is abbreviated from 1,000 (\`MTG::DeckShape#short_count\`: 1,357 is "1.4k", 12,345 "12k", 1,250,000 "1.3m", half up on integers, at most four characters), because both sit in a slot of fixed width; every other number and every \`aria-label\` stays exact and delimited; the caption is a run of unbreakable items (\`caption_items\`, one per colour, so a line never starts with "·"); and the Card types list is a grid whose rows are subgrids, so the counts line up whatever the suffix (spec 077 decisions 1 to 5, #320; it supersedes, in part, spec 060 decision 2, AC-2.2, AC-2.4, AC-2.5 and AC-2.6 (the written-in-full numbers, the fixed 4.5rem minimum, the 279px) and spec 069 decision 14 for those two numbers). A mana segment narrower than its label (labels of four, five and six characters need about 14%, 17% and 20% of the bar at a 320px viewport; the 10% rule is spec 060 decision 4) is a known limit, [#NNN](https://github.com/plainprogrammer/Collector/issues/NNN) (spec 077 decision 2, ruled option A).`
- Named constants (after the "narrow threshold" row, line 246): add two rows: `| \`MTG::DeckShape::SHORT_COUNT_STEP\` | 1,000 | \`app/models/mtg/deck_shape.rb\` | A count in a slot of fixed width is written in full below it and takes a unit from it, each unit 1,000 of the one before | spec 077 decision 5; #320 |` and `| \`MTG::DeckShape::SHORT_COUNT_UNITS\` | \`k\`, \`m\`, \`b\` | \`app/models/mtg/deck_shape.rb\` | The units of an abbreviated count | spec 077 decision 5; #320 |`.
- Line 312, the Issues bullet: replace "Open on the panel: its layout at extreme counts, [#320](…) (a four-digit 6+ count in a 360px browser frame, crowded mana bar labels, a long proxy suffix in the Card types rows: spec 060's CSS, spec 069 verification "Findings")." with "Open on the panel: its mana labels in segments narrower than their label, [#NNN](https://github.com/plainprogrammer/Collector/issues/NNN) (spec 077 decision 2; the other limits of [#320](https://github.com/plainprogrammer/Collector/issues/320) are fixed by spec 077)."
- Sources and the Distillation log are written by `distill-feature` at the end (Task 6), not here.

**Step 3b: the design-system README.** In `docs/design-system/README.md` line 138 (the "App additions (spec 060…)" list), where `DeckShape`'s classes are named, add `c-manacap__item`.

**Step 4: the index.** In `docs/specs/README.md` change the 077 row's Status from `Draft` to `Approved` and its Plan cell from `none` to `present`.

**Step 5: verify by reading** each statement against the code (`short_count` examples, the CSS lines, the previews' markup); run `bin/yard doc` (0 warnings). **Commit** (two calls): `git add docs/design-system docs/architecture/collection-and-lots.md docs/specs/README.md`, then `git commit -m "docs: deck shape panel at extreme counts (spec 077, #320)"`.

---

## Phase 4: Evidence, review, finish (the supervisor's)

### Task 6

1. **The follow-up issue's number** (the coordinator files it from the Gate B message): replace every `#NNN` and `/issues/NNN` in `DeckShape.md` and `collection-and-lots.md`, cite it in `spec.md`'s Open Questions (a 0.3.2 changelog row: "issue number cited"), and commit. The measurements are in `verification.md` (from the section above).
2. **Screenshots**: the throwaway `spec/system/zz_077_screenshots_spec.rb` with `PHASE=after`; "before" shots exist (captured from the old code at the plan's start); look at every shot in both themes; commit them under `docs/specs/077-deck-shape-extreme-counts/screenshots/` as JPEGs (`magick in.png -resize 1000x -quality 70 out.jpg`), delete the throwaways, list them in `verification.md`.
3. **`verification.md`**: AC table (each AC and the example title that proves it), the supersession grep, the mutation checks (each "can fail" example proved by the injection), deviations, screenshots.
4. **Mode B review** (read-only Opus, `sdd-review`), recorded under `## Implementation review` with the verdict first.
5. **`session-wrap`, `distill-feature`** (area docs' Sources and Distillation log, the index row to Frozen with "retirement owed"), commit; ask for a CI slot, `bin/ci`, push, draft PR "Closes #320", CI green, `gh pr ready`, `gh pr edit --add-assignee @me`, `worker_done`.

## Self-review

- **Spec coverage:** FR-1 (Tasks 1, 3), FR-2 (Task 4), FR-3 (Tasks 1, 2: the model and request examples and the nested `describe` in `spec/system/deck_shape_panel_spec.rb`), FR-4 (Tasks 5, 6); AC-1.1 (T1), AC-1.2/2.1/4.2 (T2 request), AC-1.3/2.2/3.1/3.1b/4.3 (T2 system, each with a failing variant; AC-4.3's at 345px, 360px and the 366px frame), AC-3.2 (T2 system example and its variant), AC-3.3 (T4 Step 3), AC-4.1 (T1), AC-5.1 to AC-5.3 (T5), AC-6.1 (the diff check in T6), AC-6.2 (T2 Step 4, T4 Step 3, T6 `bin/ci`). **Gap check:** AC-2.3 (narrow segments keep the class) is spec 069's AC-4.6 example, `spec/requests/deck_shape_panel_spec.rb` "marks a segment under 10%…", kept green.
- **Placeholder scan:** the only deliberate placeholder is the follow-up issue's number `#NNN`, which the coordinator supplies after Gate B (Task 5 says where it goes and what to do if it is unknown).
- **Type consistency:** `short_count(number)` and `caption_items` are named identically in the model, the partial, the examples and the documents; `SHORT_COUNT_STEP` and `SHORT_COUNT_UNITS` in the model and the area doc rows.
