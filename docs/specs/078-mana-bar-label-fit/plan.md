# Plan 078: A Mana Bar Label Fits Its Segment or Isn't Drawn

**Spec:** [spec.md](spec.md) 0.2.1 (approved, Gate A at 0.2.1; D1 ruled by the maintainer) | **Issue:** [#330](https://github.com/plainprogrammer/Collector/issues/330) | **Branch:** `078-mana-bar-label-fit`

## Global Constraints

- Test first, one commit per task. Targeted `bin/rspec <file>` runs need no CI slot; a full `bin/ci`, or a push whose pre-push hook runs it, needs a slot from the coordinator.
- Never run two test runs at once in this worktree (they share the test database). The untracked `spec/system/zz_probe_label_spec.rb` is the supervisor's throwaway probe: don't run, edit or commit it, and never `git add -A` or `git add spec` (stage by path).
- The app diff is exactly `app/assets/stylesheets/collector/additions.css`, inside the DeckShape mana bar block (AC-3.1): no view, model or script, no new class (a pseudo-element is not a class), no colour, font family or spacing literal. Nothing else in `additions.css` is touched, reordered or reformatted (another worker shares the file). `spec/design_system_files_spec.rb` counts the strings "spec 019", "spec 021" and "spec 023" across the whole file; "spec 078" in a comment is fine.
- Commit trailer: the `Co-Authored-By` line the session's attribution reminder gives, as a second message: `git commit -m "<subject>" -m "Co-Authored-By: …"` (earlier commits of this branch carry a different one; leave them). One git operation per shell call: stage with `git add <paths>` in one call and `git commit` in the next (the project's pre-commit hook reads a command that contains `git add` and would run RuboCop on every untracked Ruby file, the probe included).
- Off limits: `.kamal/secrets`, `config/master.key`, `.env*`, `storage/`, `*.sqlite3`; every `git grep` ends with `':!.kamal/secrets'`.
- Run `bin/rubocop -a` on each Ruby file written (the project's hook does too); array literals use the omakase style `[ a, b ]`.
- Geometry examples size every viewport frame from the measured scrollbar (`open_fold_in_frame` does) and read `documentElement.clientWidth`, never `innerWidth` (lessons of 2026-11-11). Label examples compare the **fractional** content width with a 0.5px band (spec decision 3), never the integer `clientWidth`, and never name a per-label result that differs by platform (a label is 43.56px on a Mac and about 44.70px on the Linux runner).
- Every geometry example has a failing variant in the same file (lesson `an-example-that-cannot-fail-proves-nothing`): the old rule injected into the page, expecting the predicate to be false.
- Do not edit `spec/support/narrow_frame.rb` (the #318 worker is changing it to compare with `clientWidth`; if it lands on `main` first, merge `main`).

## Goal

A mana bar label is on one line inside its segment or is not drawn, at any width of the bar and for any label length: `.c-manabar__seg` becomes a wrapping flex container with `overflow:clip`, a zero-width `::before` the segment's height is its first item and the label does not shrink, so the browser's line breaking moves a label that cannot fit onto a clipped second line (spec decision 1, FR-1). The 10% narrow class stays. The component document, the area doc and the index say so (Story 2), with before and after screenshots.

## Pre-implementation gates

- **Simplicity:** one stylesheet block changes (about eight declarations in three rules). No component, class, dependency or abstraction. Pass.
- **Anti-abstraction:** no helper, no Ruby, no JavaScript; the spec's decision 1 rejects the server rule, the container query and the script. Pass.
- **Integration-first:** the contract is what the browser draws (AC-1.1 to AC-1.3), written as system examples that fail first in Task 1, before any CSS. Pass.

## The existing examples this changes (from a grep, not from memory)

Command (run 2026-11-12 from the repo root): `git grep -n -i -E "c-manabar|manacap|labels_fit|narrow" -- spec docs/design-system docs/architecture app ':!.kamal/secrets'`, read hit by hit.

| Hit | Disposition |
|---|---|
| `spec/system/deck_shape_panel_spec.rb:155` (the paint example reads `aside .c-manabar__seg` colours), `:250` (`measure`'s `labels`: the visible spans), `:315` (AC-2.2's variant) | kept unchanged; they stay green after the CSS (AC-3.2): the five equal segments of the 077 fixture all fit (46.2px of content against a 43.56px label on a Mac, 44.70px on Linux) so none is clipped |
| `spec/requests/deck_shape_panel_spec.rb:62-91, 118, 193-218` (the bar's `aria-label`, segment texts and classes, the caption) | kept unchanged: no markup changes (AC-1.6) |
| `spec/system/design_system_deck_components_spec.rb:99-111, 437-468` (builds its own `c-manabar` markup at 288px: "U 44" and "R 16"; measures the bar's box, outline, divider and segment paints) | kept unchanged; run after the CSS (Task 2): both labels still fit, and the segments' widths do not change (`min-width:0` is already set, `overflow:clip` and `flex-wrap` leave a flex item's width alone) |
| `docs/design-system/components/DeckShape.md:26, 72-77, 88` (the markup example, the mana bar paragraph, the Width paragraph's Known limit (1)) | the paragraph gains the fit rule and the Width paragraph's limit (1) is replaced (Task 3) |
| `docs/design-system/previews/DeckShape.html`, `DeckPage.html`, `DeckPagePhone.html` (draw the real stylesheet; `c-manabar__seg--narrow` examples) | read for a statement of the limit or the rule; no markup changes expected (Task 3, AC-2.2) |
| `docs/architecture/collection-and-lots.md:137, 316, 354` | extended or edited (Task 4) |
| `docs/specs/**` (060, 069, 077 and their `verification.md`) | history, not edited |

## File structure

| File | Responsibility |
|---|---|
| `app/assets/stylesheets/collector/additions.css` | the mana bar block: the fit rule (three rules, one comment) |
| `spec/system/deck_shape_panel_spec.rb` | a nested `describe "mana label fit (spec 078, #330)"` inside the "extreme counts" describe (it reuses `at_width`, `inject_css`, `set_theme`, `widths`, `card`, `create_lot_in_zone`), with AC-1.1 to AC-1.5 and their failing variants |
| `docs/design-system/components/DeckShape.md` (and the README and previews if they say otherwise) | AC-2.1, AC-2.2 |
| `docs/architecture/collection-and-lots.md`, `docs/specs/README.md`, `docs/specs/078-mana-bar-label-fit/spec.md` | AC-2.3 (the Distillation log row is the `distill-feature` step's) |
| `docs/specs/078-mana-bar-label-fit/{screenshots/,verification.md}` | evidence, the grep, the review record, the manual phone item (AC-2.4) |

Batches for implementer subagents (`sonnet`, read `plan.md` by line range, one TDD commit per task, the supervisor checks each batch's diff): **A** = Tasks 1–2 (red examples, then the CSS), **B** = Tasks 3–4 (documents). Tasks 5 and 6 are the supervisor's.

---

## Phase 1: The examples, red first, then the rule

**Implements:** FR-1, FR-2 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-3.1, AC-3.2 | **Files:** `spec/system/deck_shape_panel_spec.rb`, `app/assets/stylesheets/collector/additions.css`

### Task 1: the failing examples

The file's memoized helpers (`user`, `account`, `deck`, `rows_deck`, `wide_deck`) are at the cop's limit of five (the comment above the "extreme counts" describe says so): the band decks are built by a method and held in locals, not by `let`. The helpers below go inside a new `describe` nested in `describe "extreme counts (spec 077, #320)"`, placed just before that describe's final `end` (after the AC-4.3 variant example, before the last two `end` lines of the file).

**Step 1: write the examples.** Insert before the two final `end`s of `spec/system/deck_shape_panel_spec.rb`:

```ruby

    # Spec 078 (#330): a mana label is on one line inside its segment or is not drawn. The three decks put W, U, B, R and G symbols in the
    # 10-20% band for labels of four, five and six characters (measured 2026-11-12, a 320px viewport, a 238px bar: "W 12" 29.2px in a 27.83px
    # segment is not drawn; "W 120" 36.4px, "W 1.2k" 43.6px). A label's width differs by platform (the Mac's 43.56px, the Linux runner's about
    # 44.70px for six characters), so the examples assert the rule, with a 0.5px band around the fractional content width (spec decision 3),
    # never a per-label result, except "W 12" on a 320px viewport, which cannot fit on either platform.
    describe "mana label fit (spec 078, #330)" do
      def band_counts
        { four: { "W" => 12, "U" => 13, "B" => 15, "R" => 16, "G" => 44 },
          five: { "W" => 120, "U" => 160, "B" => 180, "R" => 190, "G" => 350 },
          six: { "W" => 1_200, "U" => 1_800, "B" => 2_000, "R" => 2_100, "G" => 3_900 } }
      end

      # One creature per colour with that many copies of a one-symbol cost: the bar's counts are the numbers above.
      def build_band_deck(key)
        band = create(:deck, account:, name: "Band #{key}")
        band_counts.fetch(key).each do |symbol, copies|
          create_lot_in_zone(band, "main", entry: card(name: "Band #{key} #{symbol}", cost: "{#{symbol}}", mana_value: 1.0), quantity: copies)
        end
        band
      end

      # Per label of the panel's bar: its line count, its text width, its segment's fractional content width (the box less the divider's
      # border), whether its text box is inside the segment's box (0.5px of tolerance), whether it lies wholly below it, the segment's
      # overflow and how far the text's centre is from the segment's. A narrow segment's label has no box at all.
      def label_states(selector)
        page.evaluate_script(<<~JS)
          (() => { const panel = document.querySelector(#{selector.to_json})
            return [...panel.querySelectorAll(".c-manabar__seg")].map((seg) => { const span = seg.querySelector("span"), range = document.createRange(); range.selectNodeContents(span)
              const text = range.getBoundingClientRect(), box = seg.getBoundingClientRect(), edge = parseFloat(getComputedStyle(seg).borderLeftWidth)
              return { name: span.textContent, narrow: span.getClientRects().length === 0,
                lines: new Set([...range.getClientRects()].map((q) => Math.round(q.top))).size,
                width: text.width, content: box.width - edge, overflow: getComputedStyle(seg).overflowX,
                inside: text.left >= box.left - 0.5 && text.right <= box.right + 0.5 && text.top >= box.top - 0.5 && text.bottom <= box.bottom + 0.5,
                below: text.top >= box.bottom - 0.5,
                off: Math.abs((text.top + text.bottom) / 2 - (box.top + box.bottom) / 2) } }) })()
        JS
      end

      def drawn?(label) = label["lines"] == 1 && label["inside"]
      def clipped?(label) = label["below"] && %w[clip hidden].include?(label["overflow"])
      # AC-1.1: each label is drawn, clipped away or has no box (a narrow segment); never on two lines, never partly out.
      def clean?(label) = label["narrow"] || drawn?(label) || clipped?(label)
      # AC-1.2: a label at least 0.5px narrower than its content width is drawn, one at least 0.5px wider is not.
      def decided?(label)
        label["narrow"] || ((label["width"] > label["content"] - 0.5 || drawn?(label)) && (label["width"] < label["content"] + 0.5 || !drawn?(label)))
      end
      def centred?(label) = !drawn?(label) || label["off"] <= 1
      def tidy?(states) = states.size >= 2 && states.all? { clean?(it) && decided?(it) && centred?(it) }

      def expect_labels_in_both_themes(width, panel)
        %w[light dark].each do |theme|
          set_theme(theme)
          found = label_states(panel)
          expect(yield(found)).to be(true), "at #{width} in #{theme}: #{found.inspect}"
        end
      end

      # The old layout: no wrapping, nothing clipped, the label a shrinkable item, no first item (what `main` draws).
      def inject_old_label_layout
        inject_css(".c-manabar__seg{flex-wrap:nowrap !important;overflow:visible !important} .c-manabar__seg::before{content:none !important} .c-manabar__seg>span{flex:0 1 auto !important}")
      end

      it "draws each label on one line inside its segment or not at all, centred, at every width, for labels of four, five and six characters (AC-1.1, AC-1.2, AC-1.3)", :aggregate_failures do
        band_counts.each_key do |key|
          band = build_band_deck(key)
          widths.each { |width| at_width(width, deck_path(band)) { |panel| expect_labels_in_both_themes("#{key} at #{width}", panel) { tidy?(it) } } }
        end
      end

      it "draws some labels and clips others at a 320px viewport, so the rule is seen acting and is not vacuous (AC-1.1, AC-1.2)", :aggregate_failures do
        at_width(320, deck_path(build_band_deck(:four))) do |panel|
          states = label_states(panel).index_by { it["name"] }
          expect(states.fetch("W 12")).to include("lines" => 1, "narrow" => false)
          expect(clipped?(states.fetch("W 12"))).to be(true), states["W 12"].inspect # 29.2px of label in a 27.83px segment, on every platform
          expect(states.values.count { drawn?(it) }).to be >= 1, states.inspect
        end
      end

      it "draws a label at 360px and in the aside where it fits, a 12% segment's among them (AC-1.2)", :aggregate_failures do
        band = build_band_deck(:four)
        [ 360, :aside ].each do |width|
          at_width(width, deck_path(band)) do |panel|
            expect(label_states(panel).find { it["name"] == "W 12" }).to satisfy("be drawn at #{width}") { drawn?(it) } # 32.6px and 33.6px of content against 29.2px
          end
        end
      end

      it "draws every label of the five-equal-segment fixture at every width, none clipped (AC-1.5)", :aggregate_failures do
        widths.each do |width|
          at_width(width, deck_path(deck)) do |panel|
            expect_labels_in_both_themes("fixture at #{width}", panel) { |found| found.size == 5 && found.all? { drawn?(it) } }
          end
        end
      end

      it "can fail: with the old layout a label wraps onto two lines at a 320px viewport (AC-1.4)" do
        at_width(320, deck_path(build_band_deck(:four))) do |panel|
          inject_old_label_layout
          found = label_states(panel)
          expect(tidy?(found)).to be(false), found.inspect
          expect(found.find { it["name"] == "W 12" }["lines"]).to eq(2)
        end
      end

      it "can fail: without the segment's first item the label sits off its segment's centre (AC-1.3)" do
        at_width(360, deck_path(build_band_deck(:four))) do |panel|
          inject_css(".c-manabar__seg::before{content:none !important}")
          found = label_states(panel)
          expect(tidy?(found)).to be(false), found.inspect
          expect(found.select { drawn?(it) }.map { it["off"] }.max).to be > 1
        end
      end
    end
```

`card` takes `name:`, `type_line:` (default "Creature — Elf"), `cost:` and `mana_value:` (from the file's top). Run `bin/rubocop -a spec/system/deck_shape_panel_spec.rb`; keep the examples' behaviour when it reformats.

**Step 2: run it and see it fail.** `bin/rspec spec/system/deck_shape_panel_spec.rb -e "mana label fit"`. Expected on the unchanged CSS (traced, not guessed): **red** are (1) "draws each label on one line inside its segment or not at all…" (at a 320px viewport "W 12" wraps onto two lines, so it is neither drawn nor clipped), (2) "draws some labels and clips others…" (nothing is clipped yet) and (3) "can fail: without the segment's first item the label sits off its segment's centre" (there is no `::before` to remove yet, so the labels are centred and `tidy?` is true where the example expects false). **Green** are (4) "draws a label at 360px and in the aside where it fits" (on the old layout "W 12" fits at 360px: a guard against a rule that hides too much), (5) "draws every label of the five-equal-segment fixture…" (a guard likewise) and (6) "can fail: with the old layout a label wraps…" (the old layout is what the unchanged code draws, so it proves the predicate can fail). Record the three red and three green in the commit body; if any differs, stop and read the printed label states before going on.

**Step 3: commit.** `git add spec/system/deck_shape_panel_spec.rb`, then `git commit -m "test(deck shape): a mana label fits its segment or isn't drawn, red first (spec 078, #330)" -m "<trailer>"`.

### Task 2: the fit rule

**Step 1: edit the CSS.** In `app/assets/stylesheets/collector/additions.css`, in the mana bar block (after "DeckShape mana bar (spec 060)"), change the `.c-manabar__seg` rule and add two rules and a comment. The rule today is:

```css
.c-manabar__seg { flex:var(--n) 1 0; min-width:0; display:flex; align-items:center; justify-content:center; background:var(--mana-c); color:var(--on-mana-c);
  font:600 12px/16px var(--font-mono); }
```

Make it:

```css
/* Spec 078 (#330): a label is drawn only if it fits its segment, on one line, whatever its length or the bar's width. The segment is a
   wrapping flex container whose first item, the ::before, is zero wide and as high as the segment, so it always stays on the first line
   and gives that line the segment's height (the label stays centred); the label does not shrink. The browser's line breaking then keeps
   the label on that line only if it fits the segment's content width, and otherwise moves it to a second line below the segment, where
   overflow:clip hides it (clip, not hidden, so the segment is no scroll container and find-in-page or scrollIntoView cannot scroll to
   it). No number about the font: the rule follows the rendered label. The 10% narrow class below stays: a segment under 10% has no
   label at all; the caption carries the count of a colour whose label is not drawn. */
.c-manabar__seg { flex:var(--n) 1 0; min-width:0; display:flex; flex-wrap:wrap; align-content:flex-start; align-items:center; justify-content:center; overflow:clip; background:var(--mana-c); color:var(--on-mana-c);
  font:600 12px/16px var(--font-mono); }
.c-manabar__seg::before { content:""; height:100%; }
.c-manabar__seg > span { flex:none; }
```

(The comment goes above the `.c-manabar__seg` rule; keep the existing README Charts-rule comment above the bar rule where it is. Keep `.c-manabar__seg + .c-manabar__seg`, the colour rules and `.c-manabar__seg--narrow span { display:none; }` unchanged.)

**Step 2: run the examples and see them pass.** `bin/rspec spec/system/deck_shape_panel_spec.rb -e "mana label fit"`, then the whole file `bin/rspec spec/system/deck_shape_panel_spec.rb`. Expected: all green, among them spec 077's AC-2.2 label examples. If a label state differs, read the message: it prints every label's state.

**Step 3: the neighbours.** `bin/rspec spec/system/design_system_deck_components_spec.rb spec/design_system_files_spec.rb spec/deck_core_spec.rb spec/requests/deck_shape_panel_spec.rb spec/requests/query_counts_spec.rb`. Expected: all green (AC-3.2). Then `git diff --stat origin/main...HEAD -- app/` names `additions.css` only (AC-3.1).

**Step 4: commit.** `git add app/assets/stylesheets/collector/additions.css` then `git commit -m "fix(design system): a mana bar label fits its segment or isn't drawn (spec 078, #330)" -m "<trailer>"`.

---

## Phase 2: The documents

**Implements:** FR-3 | **Satisfies:** AC-2.1, AC-2.2, AC-2.3 | **Files:** `docs/design-system/components/DeckShape.md`, `docs/architecture/collection-and-lots.md`, `docs/specs/README.md`

### Task 3: `DeckShape.md`, the README and the previews

**Step 1:** in `docs/design-system/components/DeckShape.md`, in **The mana bar** list, after the bullet that begins "A segment under 10% of the symbols adds `c-manabar__seg--narrow`", insert:

```markdown
- **A label that does not fit is not drawn** (spec 078 decision 1, #330). The server's 10% class is a floor; above it the browser decides from the label's rendered width. A segment is a wrapping flex container with `overflow:clip`; its first flex item is a zero-width `::before` as high as the segment, and the label does not shrink (`flex:none`). The label stays on the first line only if it fits the segment's content width (its box less the 1px divider); otherwise flex line breaking moves it to a second line below the segment, where `overflow:clip` hides it. So a label is on one line inside its segment or is not drawn, at any width of the bar and for any label length ("U 44", "W 999", "W 2.6k"), with no number about fonts in the rule, and a label exactly as wide as its content width is drawn. The caption and the bar's `aria-label` carry every colour's exact count, so nothing is lost; the caption now carries the count of a colour whose label is not drawn as well as one under 10%. A clipped label stays in the DOM (the bar is `role="img"`): find-in-page may match it, and `overflow:clip` means nothing scrolls to show it.
- **Browsers:** the rule relies on flex line breaking (an item moves to a new line when the line's items exceed the container, and the first item of a line always stays) and on a percentage height in a stretched flex item (the `::before`'s `height:100%`). Safari 17.2, Chrome 120 and Firefox 121 and later are the floor (`allow_browser versions: :modern`) and all have it. The suite runs it in headless Firefox; a check on a phone (WebKit) is a manual item of spec 078's verification. A label within half a pixel of its content width may be drawn on one platform and clipped on another (a Mac and the Linux runner draw the mono face a pixel apart).
```

**Step 2:** in the **Width** paragraph of `DeckShape.md`, replace the sentence "and every count, the legend, the types and the mana labels fit with no horizontal overflow at the worst-case counts of spec 069's fixture (spec 077 AC-1.3, AC-2.2, AC-3.1)" so that it ends "… the types and every drawn mana label fit with no horizontal overflow …". Replace "**Known limits:** (1) a mana segment narrower than its label: … and is [#330](…) (spec 077 decision 2, ruled option A). (2) A Card types row …" with "**Known limit:** a Card types row with a five-digit count and suffix at a 320px viewport wraps its name, even mid-word; counts of six digits are not specified. (A mana segment too narrow for its label no longer wraps it: the label is not drawn and the caption carries the count; spec 078, #330, which closed the limit spec 077 had recorded.)" Keep the rest of the paragraph as it is.

**Step 3 (AC-2.2, reading):** `git grep -n -i -E "label|narrow|10%|#330|limit" -- docs/design-system/README.md docs/design-system/previews/DeckShape.html docs/design-system/previews/DeckPage.html docs/design-system/previews/DeckPagePhone.html ':!.kamal/secrets'`; read each hit that states the mana label rule or the limit. Correct only a statement that now differs from Step 1 (none is expected: the README's DeckShape line lists classes, and the previews draw the real stylesheet with no limit text). Record what you read and what you changed (or "no change") in the commit body.

**Step 4: commit.** `git add docs/design-system` then `git commit -m "docs(design system): DeckShape says a mana label that doesn't fit isn't drawn (spec 078, #330)" -m "<trailer>"`.

### Task 4: the area doc and the index

**Step 1:** in `docs/architecture/collection-and-lots.md`, read line 137 (the panel's paragraph), line 316 (the Issues bullet) and line 354 (Sources). (a) In the panel's paragraph, where it says what a mana segment's label shows, add one sentence: "A label is drawn only if it fits its segment on one line (a segment under 10% never has one); otherwise it is clipped and the caption carries the count (spec 078, #330; `DeckShape.md`)." (b) In the Issues bullet, the clause "[#330](…) (spec 077 decision 2; the other limits of [#320](…) are fixed by spec 077)" becomes "[#330](…) (the mana-label band, recorded by spec 077 decision 2 and closed by spec 078; the other limits of [#320](…) were fixed by spec 077)", with #330 no longer named as open. (c) In Sources, append to the spec 077 bullet's "the mana-label band as a documented limit, ruled option A" the words "(closed by spec 078)" and add a bullet after it: "- [Spec 078](../specs/078-mana-bar-label-fit/spec.md) (issue [#330](https://github.com/plainprogrammer/Collector/issues/330)): the mana bar's fit rule (a label is drawn on one line inside its segment or clipped, `additions.css`). It supersedes in part spec 077 decision 2's documented limit, its Goal 1 qualification, Error Scenarios row, AC-5.1 and AC-5.3 and the 060 AC-2.4 exception (neither spec is edited)." Do not add the Distillation log row: the `distill-feature` step does.

**Step 2:** `docs/specs/README.md`: spec 078's row exists (Status Approved at Gate A; the distillation step changes it); 077's "Superseded by" names 078. Read both rows and confirm; no change expected.

**Step 3: commit.** `git add docs/architecture/collection-and-lots.md docs/specs/README.md` then `git commit -m "docs(architecture): the panel's mana label fit rule and the closed #330 (spec 078)" -m "<trailer>"`.

---

## Phase 3: Evidence (the supervisor's)

**Satisfies:** AC-2.4, the visual evidence of the non-functional requirements | **Files:** `docs/specs/078-mana-bar-label-fit/screenshots/`, `docs/specs/078-mana-bar-label-fit/verification.md`

### Task 5: before and after screenshots

A throwaway, uncommitted `spec/system/zz_078_screenshots_spec.rb` (method: `.claude/memory/pr-screenshots-workflow.md` and `.claude/memory/headless-firefox-narrow-frame.md`): build the `:four` and `:six` band decks as Task 1 does; for each deck, each of 320px and 360px viewports (frames from the measured scrollbar) and the 1280px aside, each theme (set `data-theme` explicitly and wait 0.6s), save an element screenshot of the mana symbols part (`.c-shape__part` holding the bar and caption) "before" (inject the old layout of Task 1's `inject_old_label_layout`) and "after" (without it, in the same page load: take "after" first, then inject). Compress with `magick … -quality 82` to JPEG into `docs/specs/078-mana-bar-label-fit/screenshots/` named `before-|after-<four|six>-<phone320|phone360|wide1280>-<light|dark>.jpg` (24 shots). Look at one shot of each theme and width before trusting the rest; the four-character deck's "W 12" must be wrapped in "before" at 320px and absent in "after"; the six-character deck's "W 1.2k" and "U 1.8k" likewise at 320px. Say in `verification.md` that "before" is the old layout restored by a `<style>`. Delete the throwaway spec and the probe before committing. Commit the shots in their own commit.

### Task 6: verification, reviews and wrap-up

`verification.md`: the AC → example table (names as written in Task 1), the failing variants (each proved red: record the red output of Task 1's run), the grep of the existing examples with its command, `git diff --stat origin/main...HEAD -- app/` for AC-3.1, the manual phone item (AC-2.4), and the Mode B `## Implementation review` (Opus, read-only) with its verdict first. Then `bin/ci` (one run, with a slot from the coordinator), the session-wrap and `distill-feature` steps (the Distillation log row, the index row's Status), the first push and the draft pull request.
