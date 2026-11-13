# Implementation Plan: Design System: the Phone-First Scanner (spec 080, issue #343)

**Spec:** `docs/specs/080-phone-first-scanner-components/spec.md` (Approved, 1.2.2) · **Issue:** #343 · **Branch:** `080-phone-first-scanner-components` · **Created:** 2026-11-12
**Approved 2026-11-13** (the maintainer, with spec patch 1.2.2); plan review by Opus (read-only) 2026-11-13: APPROVE WITH CHANGES, applied. Retired by `distill-feature` after the merge (spec 027).

## Summary for the maintainer

Ten phases, one implementer per phase (or two short phases together), test first, one commit per task. Nothing under `app/views`, `app/javascript`, `app/controllers`, `app/models` or `app/helpers` changes.

| Phase | What lands | Criteria |
|---|---|---|
| 0 | Spec patch 1.2.2, plan, index row; bullets on #344 and #345; draft PR | — |
| 1 | `on-success`, `on-warning`, `scrim` in `tokens.css` and `tokens.json`; contrast guard | AC-1.1, 1.2 |
| 2 | Shared probe helpers; reduced-motion helper; the app-wide reduced-motion block | AC-6.4, FR-7 |
| 3 | `ScanMarkup` (test and preview markup); `c-band` | AC-1.3 to 1.5 |
| 4 | `c-shell--focused` (a block of its own), then `c-sheet` | AC-2.1 to 2.5, 2.7; the body half of AC-3.1 |
| 5 | `c-scan` | AC-3.1 to 3.9 |
| 6 | `c-scanpane`, the capture strip, the short-screen rule; the blocks' guard | AC-4.1 to 4.11, 6.2 |
| 7 | README, `StatusBand.md`, `Sheet.md`, `Scanner.md` | AC-1.6, 2.6, 5.1 to 5.7, 5.11 |
| 8 | Four previews, screenshots | AC-5.8 to 5.10 |
| 9 | `verification.md`, `bin/ci`, Mode B review, final visual review | AC-6.1, 6.3 |

**Two things planning found that change the spec (patch 1.2.2, approved with this plan and already in `spec.md`):**

1. **The page's `<body>` needs a class, `c-shell--focused`.** The app's body keeps the browser's 8px margin and `c-shell`'s `min-height:100vh`, so a `100dvh` shell would scroll the document by 16px, and by the address bar's height on a phone. The class removes both; #344's layout sets it. It follows your earlier ruling for `c-shell--footed` and `c-shell--untabbed` (a class on the shell, not `:has()`).
2. **A two-line band is 56px, not 60px.** 60px needs 10px of padding, which decision 15 rules out; `space-2` above and below gives 56px. Every criterion still holds (the sums are in "Spec patch 1.2.2").

**Measured while planning** (ImageMagick, the app's fonts): "Add foil · read from the card" breaks as "Add foil · read" (98px) and "from the card" (95px) in the 120px a 160px button leaves, so AC-4.11's two lines fit with 22px to spare. "Not sure of this card. Check it against your capture." is 330px, so it wraps at 360px (304px of room) and fits one line at 390px (334px) by about 4px.

**Reviewed:** a read-only Opus plan review (2026-11-13) returned APPROVE WITH CHANGES, nothing blocking; its findings are applied. It traced every example's sums against the CSS and found two examples to fix (one text check that would fail after correct CSS, one that passed before any CSS), asked for three more rows in the spec patch (the Files table, AC-5.9's "console" wording, one Verification sentence), and set the count's number to the `data` style's 13px.

**Not run:** by the project's rule nobody runs a plan's code before execution. The blocks are strong drafts; each implementer sees red, then green, and records a deviation as a ruling in the commit body. "Risks" lists what only a run can confirm.

## Context

The scanner is being rebuilt as one phone screen (#344) with a selection pane (#345). Spec 080 draws the design-system parts first: three tokens, the status band, the sheet, the shell, the pane, the rules in the README and four previews, so the two feature issues build from settled patterns. No view exists for these parts, so their CSS is proved by adding their markup to a real page in headless Firefox, as spec 060 did.

## Global Constraints

- **Repo rules:** `CLAUDE.md`, `.claude/rules/*.md`. Before touching CSS or a design-system document, use the `collector-design-system` skill and read `docs/design-system/README.md`. Tokens and `c-*` classes only; no colour literal, no px spacing outside the scale except a stated size.
- **Nothing shipped moves.** No file under `app/views`, `app/javascript`, `app/controllers`, `app/models` or `app/helpers` changes. No existing rule of `additions.css` or `components.css` is changed or removed. The `c-scanner` rules stay.
- **Where CSS goes.** Each new block starts with its own heading, `/* ---------- Name (spec 080…) … ---------- */`, after a blank line. The reduced-motion block (Phase 2) is appended at the end of `additions.css` and stays the last block: every later block is inserted directly above its heading. No new comment contains "spec 019", "spec 021" or "spec 023" (`spec/design_system_files_spec.rb` counts them), and no comment in a spec 080 block is needed to say `#344` (the guard of Phase 6 strips comments before it looks for colour literals, but keep them out).
- **Sizes are outer sizes** (spec decision 15): every new rule that sets a width or height sets `box-sizing:border-box`.
- **Specs:** `type: :system` explicit; `RSpec/ExampleLength` is 15 lines, so measures live in helper methods; multi-expectation examples carry `:aggregate_failures`; no constants inside a `describe` (use methods); no `sleep`. Headless Firefox, classic scrollbars, 1400 × 1400 window (`spec/support/system.rb`). A viewport size in a criterion is an iframe of that size (`open_in_narrow_frame(…, height:)`).
- **Measure after motion.** The sheet, the pane and the capture animate for 200ms when they appear. Every helper that inserts them calls `document.getAnimations().forEach((a) => a.finish())` before anything is measured, and the row is moved with `scrollTo({ behavior: "instant" })`.
- **Comments:** every public module and method in `spec/support/` gets a summary with `@param`/`@return` (the comment ratchet in `bin/ci checks`); no `{…}` in a comment.
- **Commits:** one per task, Conventional Commits with `(#343)`, the attribution trailer in force at commit time. `git add` and `git commit` in separate shell calls; one git operation per call. Never read `.kamal/secrets`, `config/master.key`, `.env*` or `storage/`; every `git grep` ends with `':!.kamal/secrets'`.
- **Run-time log:** `spec/support/runtime_log.txt` is not refreshed (one new spec file takes the average).
- **No prose document is read by RSpec** (`.claude/rules/testing.md`): Phase 7's criteria are verified by reading and recorded in `verification.md`.

## Goal

`additions.css` holds the status band, the sheet, the one-screen shell, the selection pane and one app-wide reduced-motion block, each proved in a browser; the README, `StatusBand.md`, `Sheet.md` and `Scanner.md` state their rules and copy; four previews draw the five steps, the three confidence states and the two sheets at 390 × 844 in both themes.

## Pre-implementation gates

- **Simplicity: pass.** Three kinds of change: tokens, CSS blocks, documents with previews. No gem, no script in the app, no view.
- **Anti-abstraction: pass.** Native `<dialog>`, scroll snap, container queries and `@keyframes` are used directly. The one extraction is `DesignSystemProbe`: the same five helpers are already written twice (`design_system_deck_rules_spec.rb`, `design_system_deck_components_spec.rb`) and this spec would be a third copy.
- **Integration-first: pass.** The contract is the markup. `ScanMarkup` (Phase 3) writes it once; the examples, the previews and `Scanner.md` all take it from there.
- **Complexity note (Phase 3):** `ScanMarkup` is test-support markup for parts with no view. It is deleted piece by piece as #344 and #345 build views and point the examples at real pages.

## Spec patch 1.2.2 (found while planning; applied to `spec.md` on approval, 2026-11-13)

| Where | Change |
|---|---|
| Header, Changelog | Version 1.2.2; a row: "PATCH, found while planning, confirmed by the maintainer with the plan: a focused page's `<body>` carries `c-shell--focused` (the body's 8px margin and `min-height:100vh` would scroll a `100dvh` shell); a two-line band is 56px, not 60px (decision 15 allows no 10px padding). Decisions 7 and 8, FR-4, AC-3.1, AC-5.1 and AC-5.9 change in wording; no sum changes its outcome" |
| Decision 7 | "A band whose sentence wraps is 60px" becomes "A band whose sentence wraps is 56px (two 20px lines and `space-2` above and below)" |
| Decision 8 | After "the sheet is `c-sheet`." add: "The page's `<body>` carries `c-shell--focused` beside `c-shell--untabbed`: the app's body has the browser's 8px margin and `c-shell`'s `min-height:100vh`, which would scroll a shell that is `100dvh` high, so the class removes both. The layout sets it on a focused page (#344's)." |
| AC-3.1 | After "Given the shell" add "on a `<body>` that carries `c-shell--focused`" |
| AC-5.1 | After "keeps a back arrow and its own primary action in view)" add ", that its `<body>` carries `c-shell--focused`" |
| AC-5.9 | "the console has no error" becomes "each page's four stylesheets load with rules and its inline script runs again without an error (headless Selenium cannot read the console here, as spec 060 recorded)" |
| Verification, CSS and layout | "the plan checks which" becomes "the example reads the rule; an implementer who finds the computed style reported adds that expectation" |
| Verification, Previews | "the console is read" becomes "the stylesheets' rule counts and a second run of the inline script are read" |
| FR-4 Must | Add "- Be the whole viewport: `c-shell--focused` on the `<body>` removes its margin and minimum height." |
| Out of Scope, #344's bullet | Add "the layout's `c-shell--focused` on the page's `<body>`," before "the after-add line" |
| Files table, the issues row | Add "`c-shell--focused`" to #344's list |
| Files table, new rows | `spec/support/design_system_probe.rb` (the probe helpers, moved from the two deck specs, which now include it); `spec/support/scan_markup.rb` (the parts' markup for the examples and the previews); `spec/design_system_files_spec.rb` (`!important` only in the reduced-motion block; the blocks' guard, AC-6.2); `docs/specs/080-phone-first-scanner-components/screenshots/` |

Sums with a 56px band: at 360 × 640 the pane's body is 640 − 56 − 96 − 96 − 56 = 336px against 188 + 164 = 352px of content, so it scrolls with the images at 160px (AC-4.7 holds). At 390 × 844 a two-line band takes 16 of the 28px spare and the images stay 288px.

## Files

| File | Change | Responsibility |
|---|---|---|
| `app/assets/stylesheets/collector/tokens.css`, `docs/design-system/tokens.json` | edit | three tokens |
| `app/assets/stylesheets/collector/additions.css` | edit | six new blocks: StatusBand, Focused shell, Sheet, Scan shell, Scan pane, Reduced motion |
| `spec/design_system_tokens_spec.rb` | edit | the tokens and their contrast |
| `spec/design_system_files_spec.rb` | edit | `!important` only in the reduced-motion block; the blocks' guard |
| `spec/support/design_system_probe.rb` | create | `theme`, `evaluate`, `computed`, `token`, `box`, `add_to_main` |
| `spec/support/reduced_motion.rb` | create | applies the reduced-motion rules |
| `spec/support/scan_markup.rb` | create | the parts' markup |
| `spec/system/design_system_scanner_components_spec.rb` | create | the CSS and layout criteria |
| `spec/system/design_system_deck_rules_spec.rb`, `design_system_deck_components_spec.rb` | edit | use `DesignSystemProbe` (their local copies go) |
| `docs/design-system/README.md`, `components/StatusBand.md`, `Sheet.md`, `Scanner.md` | edit, create | rules, documents |
| `docs/design-system/previews/ScannerFlow.html`, `ScannerConfidence.html`, `Sheet.html`, `StatusBand.html` | create | previews |
| `docs/specs/080-phone-first-scanner-components/spec.md`, `plan.md`, `verification.md`, `screenshots/`, `docs/specs/README.md` | edit, create | the record |

---

## Phase 0: Preflight (no code)

**Implements:** execution preamble · **Satisfies:** —
**Interfaces:** Consumes: nothing. Produces: the branch with spec 1.2.2 and this plan committed; issue bullets.

- [x] **T0.1** Done on approval (2026-11-13): spec patch 1.2.2 is in `spec.md`, this plan is at `docs/specs/080-phone-first-scanner-components/plan.md`, and spec 080's Plan column in `docs/specs/README.md` reads "present". Check `git status` shows those three paths and nothing else.
- [ ] **T0.2** `git add docs/specs/080-phone-first-scanner-components docs/specs/README.md`, then commit: `docs(design-system): spec and plan for the phone-first scanner (#343)`.
- [ ] **T0.3** Add the deferred bullets to the issues (spec Out of Scope). For each, read the body (`gh issue view N --json body --jq .body`), insert the bullet before the "**Mock-ups**" line, write the result with the Write tool to the scratchpad and run `gh issue edit N --body-file <path>`.
  - #344: "- **From spec 080** (decisions 8, 13, 17): the layout marks the page's `<body>` `c-shell--focused` beside `c-shell--untabbed`. The scanner's footer goes and the content notice's lines show in the foot of both sheets (`c-sheet__foot`): record the supersession of spec 018 FR-2 for the scanner (\"every page\", \"at the end of the page\", \"with no JavaScript\"), update `Footer.md` and the catalog-core area doc, extend `spec/footer_core_spec.rb` to the foot's partial, and say where the notice shows with script off and with the camera unavailable. A tap on a sheet's backdrop closes it. Each line over the camera keeps its `role=\"status\"` element in the document and replaces its text; Undo sits outside it. Add the icon partials the shell uses (the torch, the destination's chevron), and the page to the `pages` of `spec/system/small_controls_touch_floor_spec.rb`."
  - #345: "- **From spec 080** (decision 8): the status band is one element whose form class, icon and sentence are replaced in place when the centred card changes, never a second band revealed with `hidden`. The row's centred item carries `aria-current=\"true\"` and every `c-scanpane__card` but its own carries `hidden`. The capture's shrink starts from the scale in `--from` on `c-scan__capture` (4 by default). Add the icon partials the pane uses (the question mark, the Previous and Next chevrons)."
- [ ] **T0.4** `git push -u origin 080-phone-first-scanner-components` as a background task in its own call (the hook runs `bin/ci`). Then check that the branch has no pull request (`gh pr list --head 080-phone-first-scanner-components`) and open a draft one assigned to the maintainer: body written with the Write tool, `gh pr create --draft --assignee plainprogrammer --body-file <path>` in a separate call. The body starts "Closes #343." and ends with the attribution line in force.

---

## Phase 1: Tokens

**Implements:** FR-1 · **Satisfies:** AC-1.1, AC-1.2
**Files:** `spec/design_system_tokens_spec.rb`, `app/assets/stylesheets/collector/tokens.css`, `docs/design-system/tokens.json`
**Interfaces:** Consumes: the spec's `block(name)`, `colours(text)`, `ratio(one, other)`. Produces: `--on-success`, `--on-warning`, `--scrim` in each colour block.

### T1.1 The three tokens and the band text's contrast

- [ ] Add inside the `RSpec.describe` of `spec/design_system_tokens_spec.rb`, after the last example:

```ruby
  # Spec 080 AC-1.1, AC-1.2: the status band is the one filled use of a status colour, so the text on it has its own tokens.
  # `scrim` is an eight-digit literal (black at 40%), which `colours` skips: nothing is written on it.
  describe "the status band's text and the scrim (spec 080)" do
    def band_text
      { "light" => %w[#ffffff #ffffff], "dark" => %w[#0c1f1f #231a08], "dark by preference" => %w[#0c1f1f #231a08] }
    end

    [ "light", "dark", "dark by preference" ].each do |name|
      it "defines on-success, on-warning and scrim in the #{name} block (AC-1.1)", :aggregate_failures do
        expect(colours(block(name)).values_at("on-success", "on-warning")).to eq(band_text.fetch(name))
        expect(block(name)[/--scrim:\s*(#\h{8})\b/, 1]).to eq("#00000066")
      end

      it "holds 4.5:1 for the band's text on its fill in the #{name} block (AC-1.2)", :aggregate_failures do
        palette = colours(block(name))
        expect(ratio(palette.fetch("on-success"), palette.fetch("success"))).to be >= 4.5
        expect(ratio(palette.fetch("on-warning"), palette.fetch("warning"))).to be >= 4.5
      end
    end

    it "flags white on the dark success fill (the check can fail)" do
      palette = colours(block("dark")).merge("on-success" => "#ffffff")
      expect(ratio(palette.fetch("on-success"), palette.fetch("success"))).to be < 4.5
    end
  end
```

- [ ] Run `bin/rspec spec/design_system_tokens_spec.rb` — expect: the six new examples FAIL (`values_at` gives `[nil, nil]`; `KeyError: key not found: "on-success"`); the can-fail example passes.
- [ ] In `tokens.css`, in each of the three colour blocks (`:root, [data-theme="light"]`, `[data-theme="dark"]`, and `:root:not([data-theme])` inside the `prefers-color-scheme` media block, keeping that block's four-space indent), replace the three status lines with:

```css
  --success: #256a3a;
  --on-success: #ffffff;
  --warning: #8a5a00;
  --on-warning: #ffffff;
  --danger: #b3362b;
  --scrim: #00000066;
```

  and in the two dark blocks:

```css
  --success: #6cc488;
  --on-success: #0c1f1f;
  --warning: #e8b75a;
  --on-warning: #231a08;
  --danger: #ff8a7a;
  --scrim: #00000066;
```

- [ ] In `docs/design-system/tokens.json`, add after the `success` entry, after the `warning` entry and after the `danger` entry (the last in `color.tokens`; mind the commas):

```json
      {
        "name": "on-success",
        "value": {
          "light": "#ffffff",
          "dark": "#0c1f1f"
        },
        "usage": "The sentence and the icon on a `success` status band, its one filled use (≥4.5:1)."
      },
```
```json
      {
        "name": "on-warning",
        "value": {
          "light": "#ffffff",
          "dark": "#231a08"
        },
        "usage": "The sentence and the icon on a `warning` status band, its one filled use (≥4.5:1)."
      },
```
```json
      {
        "name": "scrim",
        "value": {
          "light": "#00000066",
          "dark": "#00000066"
        },
        "usage": "The backdrop of an open sheet, black at 40% in both themes. Nothing is written on it and nothing else uses it."
      }
```

- [ ] Run `bin/rspec spec/design_system_tokens_spec.rb spec/design_system_files_spec.rb` — expect: PASS. Run `ruby -rjson -e 'JSON.parse(File.read("docs/design-system/tokens.json"))'` — expect: no error.
- [ ] Commit: `feat(design-system): on-success, on-warning and scrim tokens (#343)`

---

## Phase 2: Probe helpers and reduced motion, app-wide

**Implements:** FR-7 · **Satisfies:** AC-6.4 (and the reduced-motion halves of AC-2.4, AC-4.4, AC-4.8 later)
**Files:** `spec/support/design_system_probe.rb`, `spec/support/reduced_motion.rb`, `spec/system/design_system_deck_rules_spec.rb`, `spec/system/design_system_deck_components_spec.rb`, `spec/system/design_system_scanner_components_spec.rb`, `spec/design_system_files_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: nothing. Produces: `DesignSystemProbe#theme(name)`, `#evaluate(script)`, `#computed(selector, *properties)`, `#token(name)`, `#box(selector)`, `#add_to_main(html)`; `ReducedMotion#apply_reduced_motion_rules(needs: [])`; the last block of `additions.css`, headed `Reduced motion, app-wide (spec 080 decision 14)`; the new system spec file with its `blank_host` and `in_viewport(width, height, html)` helpers.

### T2.1 One home for the probe helpers (a refactor; no behaviour changes)

- [ ] Run `bin/rspec spec/system/design_system_deck_rules_spec.rb spec/system/design_system_deck_components_spec.rb` and note the example counts (a characterisation: they must be the same after).
- [ ] Create `spec/support/design_system_probe.rb`:

```ruby
# What a system example about the design system's CSS needs to read from the browser: a computed style, a token as the
# theme resolves it, an element's box. Written twice before it was moved here, with a third copy due (spec 080); an example group that
# proves CSS includes it. Every method works on the page the driver is in, so inside `within_narrow_frame` it reads the frame.
module DesignSystemProbe
  # Pins the page's theme, as the app's `data-theme` does.
  #
  # @param name [String] "light" or "dark"
  # @return [void]
  def theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")

  # Adds markup at the end of the page's `main`.
  #
  # @param html [String] the markup
  # @return [void]
  def add_to_main(html) = page.execute_script("document.querySelector('main').insertAdjacentHTML('beforeend', arguments[0])", html)

  # Runs a script body in the page and returns what it returns.
  #
  # @param script [String] statements, ending in `return …` when a value is wanted
  # @return [Object] the script's value, as Selenium converts it
  def evaluate(script) = page.evaluate_script("(() => { #{script} })()")

  # The computed values of one element, by CSS property name, in the order asked.
  #
  # @param selector [String] a CSS selector; the first match is read
  # @param properties [Array<String>] property names, as CSS writes them ("border-top-width")
  # @return [Array<String>] the computed values
  def computed(selector, *properties)
    evaluate(<<~JS)
      const style = getComputedStyle(document.querySelector(#{selector.to_json}))
      return #{properties.to_json}.map((name) => style.getPropertyValue(name))
    JS
  end

  # A colour token as the browser resolves it for the current theme.
  #
  # @param name [String] the custom property, with its dashes ("--ink-muted")
  # @return [String] "rgb(r, g, b)", or "rgba(r, g, b, a)" for a token with an alpha
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
  #
  # @param selector [String] a CSS selector; the first match is measured
  # @return [Hash{String => Float}] "left", "top", "right", "bottom", "width", "height"
  def box(selector)
    evaluate(<<~JS)
      const rect = document.querySelector(#{selector.to_json}).getBoundingClientRect()
      return { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom, width: rect.width, height: rect.height }
    JS
  end
end
```

- [ ] In both deck specs, add `include DesignSystemProbe` as the first line inside the `RSpec.describe` block and delete the local definitions the module now holds, with their comments: `theme`, `add_to_main`, `evaluate`, `computed`, `token` in both, and `box` in `design_system_deck_components_spec.rb`. Compare each deleted body with the module's first: if one differs, keep that local definition (it overrides the module) and say so in the commit body. `blank_host` and everything else stay.
- [ ] Run the two deck specs again — expect: PASS, the same counts. Run `bin/rubocop spec/support/design_system_probe.rb spec/system/design_system_deck_rules_spec.rb spec/system/design_system_deck_components_spec.rb`.
- [ ] Commit: `refactor(spec): one home for the design-system probe helpers (#343)`

### T2.2 The reduced-motion helper, the block and AC-6.4

- [ ] Create `spec/support/reduced_motion.rb`:

```ruby
# Headless Firefox reports no reduced-motion preference, and a driver with the preference set would be a second browser
# session. This module applies the stylesheets' `(prefers-reduced-motion: reduce)` rules itself, as `CoarsePointer` does
# for a coarse pointer (spec 080 AC-6.4).
module ReducedMotion
  # Applies every rule inside a `prefers-reduced-motion: reduce` media block of the loaded stylesheets to the current
  # document (or the current frame's), media wrapper removed, in source order, as one adopted sheet after every stylesheet.
  # A declaration keeps its `!important`. Nothing is written to the server and the change lasts until the page is left, so
  # a caller reads the moving state first and the still one after.
  #
  # @param needs [Array<String>] fragments of selector text that must be among the rules ("::backdrop",
  #   ".c-scanpane__row"), so an example about a new rule fails by naming it and not by a symptom
  # @return [Array<String>] the selector text of every rule applied, in source order
  # @raise [RuntimeError] when a fragment in `needs` matches no rule
  def apply_reduced_motion_rules(needs: [])
    selectors = page.evaluate_script(<<~JS)
      (() => {
        const css = [], seen = []
        for (const sheet of document.styleSheets)
          for (const media of sheet.cssRules)
            if (media instanceof CSSMediaRule && media.conditionText.includes("prefers-reduced-motion: reduce"))
              for (const rule of media.cssRules) { seen.push(rule.selectorText); css.push(rule.cssText) }
        const sheet = new CSSStyleSheet()
        sheet.replaceSync(css.join(" "))
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet]
        return seen
      })()
    JS
    missing = needs.reject { |fragment| selectors.any? { it.include?(fragment) } }
    raise "no reduced-motion rule matches #{missing.inspect} (found #{selectors.inspect})" if missing.any?

    selectors
  end
end

RSpec.configure do |config|
  config.include ReducedMotion, type: :system
end
```

- [ ] Create `spec/system/design_system_scanner_components_spec.rb`:

```ruby
require "rails_helper"

# Spec 080: the CSS of the phone-first scanner's parts, proved in headless Firefox before any view exists (#344 and #345
# build the views). A part is added to a real page (the Locations page, blanked). The shell is the whole screen, so it
# replaces the body of that page inside an iframe of the viewport's size: the dynamic viewport is then the frame's.
RSpec.describe "Design system: phone-first scanner components", type: :system do
  include DesignSystemProbe

  let(:user) { create(:user) }

  before do
    system_sign_in_as(user)
    visit locations_path
    blank_host
  end

  # Clears the host page so its own rules cannot answer an example: the Locations page's `c-locations` gives every `.c-btn`
  # a 44px floor.
  def blank_host
    page.execute_script(<<~JS)
      const main = document.querySelector("main")
      main.className = "c-main"
      main.replaceChildren()
    JS
  end

  # `html` as the only content of the body of a width × height frame, the block run inside the frame. The body carries the
  # classes a focused page's does. Animations are finished first, so nothing is measured mid-slide.
  def in_viewport(width, height, html)
    open_in_narrow_frame(locations_path, width:, height:, ready: "main")
    within_narrow_frame do
      page.execute_script(<<~JS, html)
        document.body.className = "c-shell c-shell--untabbed c-shell--focused"
        document.body.innerHTML = arguments[0]
        document.getAnimations().forEach((animation) => animation.finish())
      JS
      expect(evaluate("return [document.documentElement.clientWidth, window.innerHeight]")).to eq([ width, height ])
      yield
    end
  end

  describe "reduced motion, app-wide (AC-6.4)" do
    def moving
      %(<button class="c-btn c-btn--primary" id="button">Add</button><a class="c-tile" href="#"><div class="c-tile__media" id="media"></div></a>)
    end

    it "stops a button's and a tile's transitions, which run without the preference", :aggregate_failures do
      add_to_main(moving)
      expect(computed("#button", "transition-duration")).to eq([ "0.12s" ])
      expect(computed("#media", "transition-duration")).to eq([ "0.15s, 0.15s" ])
      apply_reduced_motion_rules(needs: [ "::backdrop" ])
      expect(computed("#button", "transition-duration") + computed("#media", "transition-duration")).to eq(%w[0s 0s])
    end
  end
end
```

- [ ] Add to `spec/design_system_files_spec.rb`, inside the top `describe`, after the last nested `describe`:

```ruby
  describe "the phone-first scanner's blocks (spec 080)" do
    let(:additions) { root.join("app/assets/stylesheets/collector/additions.css").read }
    let(:blocks) { additions.scan(%r{/\* -+ [^\n]*\(spec 080[^\n]*\n.*?(?=\n\n/\* -|\z)}m) }

    it "uses !important only in the reduced-motion block, which is the last block (FR-7)", :aggregate_failures do
      rules = root.glob("app/assets/stylesheets/**/*.css").map { |path| path.read.gsub(%r{/\*.*?\*/}m, "") }.join
      expect(rules.scan("!important").size).to eq(2)
      expect(blocks.last).to include("transition:none !important; animation:none !important;")
      expect(additions.rstrip).to end_with(blocks.last.rstrip)
    end
  end
```

- [ ] Run `bin/rspec spec/system/design_system_scanner_components_spec.rb spec/design_system_files_spec.rb` — expect: FAIL (`no reduced-motion rule matches ["::backdrop"]`; `blocks.last` is nil).
- [ ] Append to the end of `app/assets/stylesheets/collector/additions.css`, after one blank line:

```css
/* ---------- Reduced motion, app-wide (spec 080 decision 14) ---------- */
/* The README's Motion rule: under `prefers-reduced-motion: reduce` nothing eases or slides, in any component. A universal
   selector loses to any class rule (the export's `.c-btn` and `.c-tile__media` set a transition), so these two declarations
   carry `!important`, the stylesheets' only use of it. A scroll the browser animates is not a transition, so the row that
   scrolls smoothly gets its `auto` here too. Keep this block last: a new block goes above this heading, so a rule of the
   same weight further up cannot win over the row's `auto`. The older `.c-scanner *` rule above stays as it is. */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after, ::backdrop { transition:none !important; animation:none !important; }
}
```

- [ ] Run the two files again — expect: PASS. Run `bin/rubocop spec/support/reduced_motion.rb spec/system/design_system_scanner_components_spec.rb spec/design_system_files_spec.rb`.
- [ ] Commit: `feat(design-system): transitions and animations stop app-wide under reduced motion (#343)`

---

## Phase 3: The parts' markup and the status band

**Implements:** FR-2 · **Satisfies:** AC-1.3, AC-1.4, AC-1.5
**Files:** `spec/support/scan_markup.rb`, `spec/system/design_system_scanner_components_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: `DesignSystemProbe`, `--on-success`, `--on-warning`. Produces: `ScanMarkup.icon(name)`, `.band(form, sentence, mark:, id:)`, `.sample_card(**changes)`, `.top_bar(value)`, `.lines(status:, added:)`, `.strip(name:, line:, caption:)`, `.pane(band:, cards:, current:, total:, noun:, step:, caption:, labels:)`, `.bottom_bar(count:, main:, torch:)`, `.shell(result:, main:, status:, added:, count:, torch:, value:, guide:, caption:, read:)`, `.sheet(title:, body:, foot:, id:, open:)`; the classes `c-band`, `c-band--success`, `c-band--warning`.

### T3.1 `ScanMarkup`

- [ ] Create `spec/support/scan_markup.rb` (markup only; nothing to run red, the examples of T3.2 on are its proof):

```ruby
# Markup of the phone-first scanner's parts (spec 080): the status band, the sheet, the one-screen shell and the selection
# pane. No view renders them yet (#344 and #345 build the views), so the examples that prove their CSS and the previews
# under docs/design-system/previews are written from these strings; a view that replaces a part takes its examples with it.
# Plain Ruby with no Rails, so a script can require this file by path.
module ScanMarkup
  # The icons the parts draw: Lucide's paths in a 24px viewBox (README Iconography). The torch, the question mark and the
  # chevrons have no partial under app/views/icons yet.
  ICONS = {
    back: '<path d="m15 18-6-6 6-6"/>',
    forward: '<path d="m9 18 6-6-6-6"/>',
    down: '<path d="m6 9 6 6 6-6"/>',
    cross: '<path d="M18 6 6 18M6 6l12 12"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    alert: '<path d="M12 4 2.5 20h19z"/><path d="M12 10v4M12 17h.01"/>',
    question: '<circle cx="12" cy="12" r="9"/><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3M12 17h.01"/>',
    torch: '<path d="M13 2 3 14h9l-1 8 10-12h-9z"/>'
  }.freeze

  # The filled star of a special finish, as the star partial writes it (FinishBadge).
  STAR = '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none" aria-hidden="true">' \
    '<path d="m12 2 3 6.5 7 .8-5.2 4.8 1.4 7L12 17.6 5.8 21.1l1.4-7L2 9.3l7-.8z"/></svg>'.freeze

  # The sample printing the examples and the previews vary (the mock-ups' copy, not catalog data).
  CARD = { name: "Lightning Bolt", set: "March of the Machine", code: "MOM · 123", year: "2023", finishes: %w[nonfoil foil] }.freeze

  # The status line's sentence while aiming.
  AIM = "Line the card up with the guide, then capture.".freeze

  module_function

  # An icon as the partials write it: stroke 1.5, hidden from assistive technology. The component's CSS sets its size.
  #
  # @param name [Symbol] a key of ICONS
  # @return [String] the `svg`
  def icon(name)
    %(<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{ICONS.fetch(name)}</svg>)
  end

  # The sample printing with some of its facts changed.
  #
  # @param changes [Hash] `name`, `set`, `code`, `year`, `finishes`
  # @return [Hash] a card for `pane`
  def sample_card(**changes) = CARD.merge(changes)

  # A status band (StatusBand): an icon and a sentence on a filled ground.
  #
  # @param form [Symbol] `:success` or `:warning`
  # @param sentence [String] the words
  # @param mark [Symbol] the icon; a check for success, the alert triangle for warning, `:question` for the unsure warning
  # @param id [String, nil] an id for an example to find it by
  # @return [String] the `p`
  def band(form, sentence, mark: (form == :success ? :check : :alert), id: nil)
    %(<p class="c-band c-band--#{form}" role="status"#{%( id="#{id}") if id}>#{icon(mark)}<span>#{sentence}</span></p>)
  end

  # The shell's top bar: Back, the sitting's destination, Done.
  #
  # @param value [String] the destination ("Atraxa › Main · NM", "No location")
  # @return [String] the bar
  def top_bar(value = "Atraxa › Main · NM")
    <<~HTML
      <div class="c-scan__top">
        <a class="c-scan__back" href="#" aria-label="Back">#{icon(:back)}</a>
        <button type="button" class="c-scan__dest"><span class="c-scan__dest-label">Adding to</span> <span class="c-scan__dest-value"><span class="c-scan__dest-text">#{value}</span>#{icon(:down)}</span></button>
        <a class="c-btn c-btn--ghost c-scan__done" href="#">Done</a>
      </div>
    HTML
  end

  # The two lines over the camera. Each keeps its `role="status"` element; the wrapper that draws the line carries
  # `hidden` while the other shows, and Undo sits outside the live region (spec 080 decision 17).
  #
  # @param status [String, nil] the status line's sentence; nil hides the line
  # @param added [String, nil] the after-add line's sentence; given, it takes the status line's place
  # @return [String] both wrappers
  def lines(status: AIM, added: nil)
    <<~HTML
      <div class="c-scan__line c-scan__line--status"#{" hidden" if added || status.nil?}><p class="c-scan__line-text" role="status">#{status unless added}</p></div>
      <div class="c-scan__line c-scan__line--added"#{" hidden" unless added}><p class="c-scan__line-text" role="status">#{added}</p><form class="c-scan__undo"><button type="button" class="c-btn c-btn--ghost">Undo</button></form></div>
    HTML
  end

  # The capture strip: the frozen capture, shrunk, and what was read from it.
  #
  # @param name [String] the name read
  # @param line [String] the collector line read, or "nothing read"
  # @param caption [String, nil] a preview's caption inside the picture
  # @return [String] the strip
  def strip(name: "Lightning Bolt", line: "MOM · 123 · EN", caption: nil)
    <<~HTML
      <div class="c-scan__strip">
        <div class="c-scan__capture">#{caption}</div>
        <div class="c-scan__read"><p class="c-scan__read-label">Read from the card</p><p class="c-scan__read-name">#{name}</p><p class="c-scan__read-line">#{line}</p></div>
      </div>
    HTML
  end

  # One add button, a `button_to`'s shape. Its accessible name is today's (spec 009); a special finish carries the star.
  #
  # @api private
  def add_button(card, finish, label)
    name = [ "Add", card[:name], card[:code], finish&.capitalize ].compact.join(" ")
    star = finish && finish != "nonfoil" ? STAR : ""
    %(<form class="c-scanpane__add"><button type="button" class="c-btn c-btn--secondary" aria-label="#{name}">#{star}#{label || (finish ? "Add #{finish}" : "Add")}</button></form>)
  end

  # One card's details-and-adds panel.
  #
  # @api private
  def panel(card, position:, hidden:, labels:)
    finishes = card.fetch(:finishes)
    adds = finishes.size > 1 ? finishes.map { |finish| add_button(card, finish, labels[finish]) }.join : add_button(card, nil, nil)
    <<~HTML
      <div class="c-scanpane__card"#{" hidden" if hidden}>
        <div class="c-scanpane__details">
          <h2 class="c-scanpane__name">#{card[:name]}</h2>
          <p class="c-scanpane__set">#{card[:set]}</p>
          <p class="c-scanpane__meta"><span class="c-tag">#{card[:code]}</span> <span>#{card[:year]}</span> <span class="c-scanpane__position">#{position}</span></p>
        </div>
        <div class="c-scanpane__adds">#{adds}</div>
      </div>
    HTML
  end

  # The selection pane: the band, the row with Previous and Next, and one panel per card with all but the centred one hidden.
  #
  # @param band [String] the band's markup (see `band`)
  # @param cards [Array<Hash>] the row's cards, in order (see `sample_card`)
  # @param current [Integer] the index of the centred card
  # @param total [Integer] the count the position names ("2 of 14"), which may be more than the cards rendered
  # @param noun [String] what the position counts: "printings" or "possible cards"
  # @param step [String] what Previous and Next move by: "printing" or "card"
  # @param caption [String, nil] a preview's caption inside each image
  # @param labels [Hash{String => String}] a finish's button label when it is not "Add" and its name
  # @return [String] the pane
  def pane(band:, cards:, current: 0, total: cards.size, noun: "printings", step: "printing", caption: nil, labels: {})
    items = cards.each_index.map { |index| %(<li class="c-scanpane__item"#{' aria-current="true"' if index == current}>#{caption}</li>) }.join
    panels = cards.each_with_index.map { |card, index| panel(card, position: "#{index + 1} of #{total} #{noun}", hidden: index != current, labels:) }.join
    <<~HTML
      <div class="c-scanpane">
        #{band}
        <div class="c-scanpane__body">
          <div class="c-scanpane__rowwrap">
            <ul class="c-scanpane__row">#{items}</ul>
            <button type="button" class="c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--prev" aria-label="Previous #{step}"#{" disabled" if current.zero?}>#{icon(:back)}</button>
            <button type="button" class="c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--next" aria-label="Next #{step}"#{" disabled" if current == cards.size - 1}>#{icon(:forward)}</button>
          </div>
          #{panels}
        </div>
      </div>
    HTML
  end

  # The shell's bottom bar: the sitting's count, the main button, the torch.
  #
  # @param count [Integer] the adds in the sitting
  # @param main [Symbol] `:capture`, `:reading` (Capture, disabled) or `:again` (Scan again)
  # @param torch [Boolean] whether the camera reports a torch
  # @return [String] the bar
  def bottom_bar(count: 12, main: :capture, torch: true)
    button = { capture: %(<button type="button" class="c-btn c-btn--primary c-scan__main">Capture</button>),
               reading: %(<button type="button" class="c-btn c-btn--primary c-scan__main" disabled>Capture</button>),
               again: %(<button type="button" class="c-btn c-btn--secondary c-scan__main">Scan again</button>) }.fetch(main)
    light = %(<button type="button" class="c-btn c-btn--secondary c-scan__torch" aria-label="Torch" aria-pressed="false">#{icon(:torch)}</button>)
    <<~HTML
      <div class="c-scan__bottom">
        <button type="button" class="c-btn c-btn--secondary c-scan__count" aria-label="#{count} added. Show this sitting's cards."><b>#{count}</b><span>added</span></button>
        #{button}
        #{light if torch}
      </div>
    HTML
  end

  # The one-screen shell. With a result it carries `c-scan--result`, which shows the capture strip and the pane.
  #
  # @param result [String, nil] the pane's markup (see `pane`), or nil for the live camera
  # @param main [Symbol, nil] the main button (see `bottom_bar`); Scan again with a result, Capture without
  # @param status [String] the status line's sentence
  # @param added [String, nil] the after-add line's sentence
  # @param count [Integer] the sitting's count
  # @param torch [Boolean] whether the torch is rendered
  # @param value [String] the destination
  # @param guide [String, nil] the guide's box as the camera controller sets it inline ("left:5px;top:80px;…")
  # @param caption [String, nil] a preview's caption inside the guide
  # @param read [Hash] `strip`'s arguments
  # @return [String] the shell
  def shell(result: nil, main: nil, status: AIM, added: nil, count: 12, torch: true, value: "Atraxa › Main · NM", guide: nil, caption: nil, read: {})
    <<~HTML
      <div class="c-scan#{" c-scan--result" if result}">
        #{top_bar(value)}
        <div class="c-scan__stage">
          <video class="c-scan__video" playsinline muted></video>
          <div class="c-scan__guide" aria-hidden="true"#{%( style="#{guide}") if guide}>#{caption}</div>
          #{lines(status: (status unless result), added:)}
          #{strip(**read) if result}
          #{result}
        </div>
        #{bottom_bar(count:, main: main || (result ? :again : :capture), torch:)}
      </div>
    HTML
  end

  # A sheet: a native dialog with a head (title, Close) and a body, the content notice's lines in its foot.
  #
  # @param title [String] the sheet's title
  # @param body [String] the body's markup
  # @param foot [Array<String>] the content notice's lines; none gives no foot
  # @param id [String] the dialog's id
  # @param open [Boolean] the `open` attribute (a preview's static sheet; a page opens it with `showModal()`)
  # @return [String] the `dialog`
  def sheet(title:, body:, foot: [], id: "sheet", open: false)
    notice = foot.empty? ? "" : %(<div class="c-sheet__foot">#{foot.map { |line| "<p>#{line}</p>" }.join}</div>)
    <<~HTML
      <dialog class="c-sheet" id="#{id}" aria-labelledby="#{id}_title"#{" open" if open}>
        <div class="c-sheet__head">
          <h2 class="c-sheet__title" id="#{id}_title">#{title}</h2>
          <form method="dialog" class="c-sheet__dismiss"><button class="c-btn c-btn--ghost c-sheet__close" aria-label="Close">#{icon(:cross)}</button></form>
        </div>
        <div class="c-sheet__body">#{body}#{notice}</div>
      </dialog>
    HTML
  end
end
```

- [ ] Run `ruby -c spec/support/scan_markup.rb` and `bin/rubocop spec/support/scan_markup.rb` — expect: `Syntax OK`, no offenses (if `Style/FormatStringToken` or a line-length cop objects, fix the layout, not the markup).
- [ ] Commit: `test(design-system): markup of the phone-first scanner's parts (#343)`

### T3.2 `c-band`

- [ ] In the system spec add `include ScanMarkup` under `include DesignSystemProbe`, this helper after `in_viewport`, and this `describe` before the reduced-motion one:

```ruby
  # An icon's computed stroke, as a number.
  def stroke_width(selector) = evaluate("return parseFloat(getComputedStyle(document.querySelector(#{selector.to_json})).strokeWidth)").to_f

  describe "StatusBand (AC-1.3 to AC-1.5)" do
    def unsure = "Not sure of this card. Check it against your capture."

    def bands
      band(:success, "Matched by its collector line", id: "ok") + band(:warning, "Printing not confirmed. Swipe to check.", id: "warn") +
        band(:warning, unsure, mark: :question, id: "unsure")
    end

    # [the band's height, the icon's top and height, the sentence's top and height], tops measured from the band's top.
    def band_layout(id)
      evaluate(<<~JS).map { it.round(1) }
        const band = document.getElementById(#{id.to_json}), top = band.getBoundingClientRect().top
        const icon = band.querySelector("svg").getBoundingClientRect(), text = band.querySelector("span").getBoundingClientRect()
        return [band.getBoundingClientRect().height, icon.top - top, icon.height, text.top - top, text.height]
      JS
    end

    %w[light dark].each do |name|
      it "fills with the status colour and writes in its on- token, in the #{name} theme (AC-1.3)", :aggregate_failures do
        add_to_main(bands)
        theme(name)
        expect(computed("#ok", "background-color", "color")).to eq([ token("--success"), token("--on-success") ])
        expect(computed("#warn", "background-color", "color")).to eq([ token("--warning"), token("--on-warning") ])
        expect(computed("#ok svg", "color")).to eq([ token("--on-success") ])
      end
    end

    it "is 40px high with its line and its 16px icon centred, 16px at its sides (AC-1.3, AC-1.4)", :aggregate_failures do
      add_to_main(bands)
      expect(computed("#ok", "font-size", "line-height", "font-weight", "padding-left", "padding-right")).to eq(%w[14px 20px 600 16px 16px])
      expect(band_layout("ok")).to eq([ 40.0, 12.0, 16.0, 10.0, 20.0 ])
      expect([ box("#ok svg")["width"], stroke_width("#ok svg") ]).to eq([ 16, 2.0 ])
    end

    it "tells the three forms apart by icon and words (AC-1.4)", :aggregate_failures do
      add_to_main(bands)
      expect(evaluate('return ["ok", "warn", "unsure"].map((id) => document.querySelector(`#${id} svg`).innerHTML)').uniq.size).to eq(3)
      expect(evaluate('return ["warn", "unsure"].map((id) => document.getElementById(id).textContent)'))
        .to eq([ "Printing not confirmed. Swipe to check.", unsure ])
    end

    it "wraps a long sentence inside a 360px band, the icon on the first line (AC-1.5)", :aggregate_failures do
      add_to_main(%(<div style="width:360px">#{band(:warning, unsure, mark: :question, id: "long")}</div>))
      height, icon_top, _icon_height, text_top, text_height = band_layout("long")
      expect([ height, text_height, icon_top - text_top ]).to eq([ 56.0, 40.0, 2.0 ])
      expect(evaluate('const band = document.getElementById("long"); return band.scrollWidth <= band.clientWidth')).to be(true)
    end
  end
```

- [ ] Run `bin/rspec spec/system/design_system_scanner_components_spec.rb` — expect: the band examples FAIL (an unstyled `p`: transparent ground, `ink` text, no fixed height); "tells the three forms apart" passes on arrival (it reads the markup; a characterisation, say so in the commit).
- [ ] Insert above the `Reduced motion, app-wide` heading in `additions.css`:

```css
/* ---------- StatusBand (spec 080): a filled band that says how sure a result is, in an icon and a sentence ---------- */
/* The one filled use of a status colour (README Color): `success` or `warning` as the ground, the matching `on-` token for
   the sentence and the icon. A grid, so one line sits centred in the 40px minimum, and a sentence that wraps grows the band
   (56px for two lines) with the icon staying on its first line: the icon's block margin makes it as tall as a line. Sizes are
   outer sizes; the export sets no box-sizing. `danger` has no band: something that went wrong is a StatusMessage. */
.c-band { box-sizing:border-box; display:grid; grid-template-columns:16px minmax(0, 1fr); column-gap:var(--space-2); align-content:center;
  min-height:40px; margin:0; padding:var(--space-2) var(--space-4); font:600 14px/20px var(--font-sans); overflow-wrap:anywhere; }
.c-band svg { width:16px; height:16px; margin:calc((20px - 16px) / 2) 0; stroke-width:2; }
.c-band--success { background:var(--success); color:var(--on-success); }
.c-band--warning { background:var(--warning); color:var(--on-warning); }
```

- [ ] Run the system spec and `spec/design_system_files_spec.rb` — expect: PASS. RuboCop on the spec.
- [ ] Commit: `feat(design-system): StatusBand, the filled status band (#343)`

---

## Phase 4: The focused shell and the sheet

**Implements:** FR-3, and FR-4's "be the whole viewport" · **Satisfies:** AC-2.1, AC-2.2, AC-2.3, AC-2.4, AC-2.5, AC-2.7; the body half of AC-3.1
**Files:** `spec/system/design_system_scanner_components_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: `ScanMarkup.sheet`, `in_viewport`, `apply_reduced_motion_rules`, `--scrim`. Produces: `c-shell--focused` (every later `in_viewport` relies on it: without it the frame's document scrolls, a classic scrollbar takes 12 to 15px and no part is as wide as its viewport); `c-sheet` and its `__head`, `__title`, `__dismiss`, `__close`, `__body`, `__foot`; the keyframes `c-sheet-rise`.

### T4.1 `c-shell--focused`

- [ ] Add this `describe` after the StatusBand one:

```ruby
  describe "the focused shell (AC-3.1)" do
    it "takes the body's margin and minimum height away, so an empty focused page does not scroll", :aggregate_failures do
      in_viewport(390, 844, "") do
        expect(computed("body", "margin-top", "margin-left", "min-height")).to eq(%w[0px 0px 0px])
        expect(evaluate("const root = document.documentElement; return root.scrollHeight <= root.clientHeight")).to be(true)
      end
    end
  end
```

- [ ] Run the system spec — expect: FAIL inside `in_viewport` (`expected [375, 844]` or `[378, 844]` `to eq [390, 844]`: the body's 8px margin and `c-shell`'s `min-height:100vh` make the frame's document 16px taller than the frame, and the scrollbar narrows it).
- [ ] Insert above the `Reduced motion, app-wide` heading:

```css
/* ---------- Focused shell (spec 080): a focused page's body is exactly the screen ---------- */
/* The app's body keeps the browser's 8px margin, and `c-shell` gives it a minimum height of 100vh, which on a phone is
   taller than the screen while the address bar shows. Either would scroll a page that must be one screen high, so the
   layout marks a focused page's body with this class, beside the one for a page with no tab bar (README Mobile and Hotwire). */
.c-shell--focused { margin:0; min-height:0; }
```

- [ ] Run the system spec and `spec/design_system_files_spec.rb` — expect: PASS.
- [ ] Commit: `feat(design-system): c-shell--focused, a focused page's body is exactly the screen (#343)`

### T4.2 `c-sheet`

- [ ] Add this `describe` after the focused shell's:

```ruby
  describe "Sheet (AC-2.1 to AC-2.5, AC-2.7)" do
    def long_place = "Binder" * 10
    def rows(count) = Array.new(count) { |index| %(<p style="margin:0">Row #{index + 1} in #{long_place}</p>) }.join

    def notice
      [ %(This catalog's content is unofficial and shown under its owner's <a href="#">content policy</a>. #{"Not approved or endorsed. " * 4}),
        "Catalog data and images provided by a source." ]
    end

    # Opens a sheet as a modal over the frame's page and finishes its slide.
    def open_sheet(body: rows(3), foot: [])
      page.execute_script(<<~JS, sheet(title: "Adding to", body:, foot:))
        document.body.insertAdjacentHTML("beforeend", arguments[0])
        document.getElementById("sheet").showModal()
        document.getAnimations().forEach((animation) => animation.finish())
      JS
    end

    # What the stylesheets declare for one property in the rule with this selector, as the rule writes it; nil without such a
    # rule. For what a computed style cannot show: a `::backdrop`'s colour (not relied on, spec 080 Verification) and a hover.
    def rule_value(selector, property)
      evaluate(<<~JS)
        for (const sheet of document.styleSheets)
          for (const rule of sheet.cssRules)
            if (rule.selectorText === #{selector.to_json}) return rule.style.getPropertyValue(#{property.to_json})
        return null
      JS
    end

    def fits?(selector) = evaluate("const el = document.querySelector(#{selector.to_json}); return el.scrollWidth <= el.clientWidth")

    %w[light dark].each do |name|
      it "sits on the bottom edge, as wide as the viewport, in the #{name} theme (AC-2.1)", :aggregate_failures do
        in_viewport(390, 844, "") do
          theme(name)
          open_sheet
          expect(box("#sheet").values_at("left", "width", "bottom")).to eq([ 0, 390, 844 ])
          expect(box("#sheet")["height"]).to be <= 844 * 0.85
          expect(computed("#sheet", "background-color", "border-top-color", "border-top-width", "border-top-left-radius", "box-shadow"))
            .to eq([ token("--surface-raised"), token("--line-strong"), "1px", "8px", "none" ])
        end
      end
    end

    it "is not displayed while closed, and its backdrop is the scrim (AC-2.1)", :aggregate_failures do
      add_to_main(sheet(title: "Adding to", body: rows(1)))
      expect(computed("#sheet", "display")).to eq([ "none" ])
      expect(rule_value(".c-sheet::backdrop", "background-color")).to eq("var(--scrim)")
      expect(token("--scrim")).to eq("rgba(0, 0, 0, 0.4)")
    end

    it "has a title and a 44px Close button drawn with the 20px cross (AC-2.2)", :aggregate_failures do
      in_viewport(390, 844, "") do
        open_sheet
        expect(box(".c-sheet__close").values_at("width", "height")).to eq([ 44, 44 ])
        expect([ box(".c-sheet__close svg")["width"], stroke_width(".c-sheet__close svg") ]).to eq([ 20, 1.5 ])
        expect(computed(".c-sheet__title", "font-size", "font-weight")).to eq(%w[20px 600])
        expect(page).to have_button("Close")
      end
    end

    it "keeps its head in view while its body scrolls inside it, 85% of the viewport at most (AC-2.2, AC-2.3)", :aggregate_failures do
      in_viewport(390, 844, "") do
        open_sheet(body: rows(60))
        head = box(".c-sheet__head")["top"]
        evaluate('document.querySelector(".c-sheet__body").scrollTop = 400')
        expect([ box(".c-sheet__head")["top"], evaluate('return document.querySelector(".c-sheet__body").scrollTop') ]).to eq([ head, 400 ])
        expect(computed(".c-sheet__body", "overscroll-behavior-y")).to eq([ "contain" ])
        expect(box("#sheet")["height"]).to be_within(0.5).of(844 * 0.85)
        expect(evaluate("return window.scrollY")).to eq(0)
      end
    end

    it "slides up in 200ms at most, and not at all under reduced motion (AC-2.4)", :aggregate_failures do
      in_viewport(390, 844, "") do
        open_sheet
        expect(computed("#sheet", "animation-name", "animation-duration")).to eq(%w[c-sheet-rise 0.2s])
        apply_reduced_motion_rules(needs: [ "::backdrop" ])
        expect(computed("#sheet", "animation-name")).to eq([ "none" ])
      end
    end

    %w[light dark].each do |name|
      it "wraps a long place name and the notice in its foot inside a 360px sheet, in the #{name} theme (AC-2.5, AC-2.7)", :aggregate_failures do
        in_viewport(360, 640, "") do
          theme(name)
          open_sheet(body: rows(2), foot: notice)
          expect([ fits?("#sheet"), fits?(".c-sheet__body"), page_fits_sideways? ]).to eq([ true, true, true ])
          expect(computed(".c-sheet__foot", "font-size", "line-height", "color", "border-top-width", "border-top-color"))
            .to eq([ "12px", "16px", token("--ink-muted"), "1px", token("--line") ])
          expect(computed(".c-sheet__foot a", "color")).to eq([ token("--brand") ])
          expect(evaluate('return document.querySelector(".c-sheet__body").lastElementChild.className')).to eq("c-sheet__foot")
        end
      end
    end

    it "rings the notice's link on keyboard focus and underlines it on hover (AC-2.7)", :aggregate_failures do
      in_viewport(390, 844, "") do
        open_sheet(foot: notice)
        expect(rule_value(".c-sheet__foot a:hover", "text-decoration-line")).to eq("underline")
        find(".c-sheet__close").send_keys(:tab)
        expect(computed(".c-sheet__foot a", "outline-style", "outline-width", "outline-color")).to eq([ "solid", "2px", token("--focus") ])
      end
    end
  end
```

- [ ] Run the system spec — expect: the sheet examples FAIL (a browser's own dialog: centred, `fit-content` wide, no rule for `.c-sheet::backdrop`, no `c-sheet-rise`). "is not displayed while closed" fails on `rule_value` being nil.
- [ ] Insert above the `Reduced motion, app-wide` heading:

```css
/* ---------- Sheet (spec 080): a bottom sheet over a page, a native dialog opened as a modal ---------- */
/* The layout is on `[open]`, so a closed dialog keeps the browser's `display:none`. The browser's own dialog is centred, as
   wide as its content, padded and bordered: every one of those is reset. `max-height` is 85% of the containing block, which
   is the viewport for a modal and a preview's frame for a sheet drawn with the `open` attribute. The head stays and the body
   scrolls, without passing the scroll on to the page behind. The body's last padding clears a phone's home indicator. It
   slides up once on opening; closing is instant. No shadow: the top border and the scrim separate it (README Shape and depth).
   A browser whose `::backdrop` does not inherit custom properties draws no dimming (spec 080 decision 4). */
.c-sheet[open] { box-sizing:border-box; position:fixed; inset:auto 0 0 0; display:flex; flex-direction:column; width:100%; max-width:none;
  height:auto; max-height:85%; margin:0; padding:0; overflow:hidden; border:0; border-top:1px solid var(--line-strong);
  border-radius:var(--radius-md) var(--radius-md) 0 0; background:var(--surface-raised); color:var(--ink);
  font-family:var(--font-sans); animation:c-sheet-rise .2s ease-out; }
.c-sheet::backdrop { background-color:var(--scrim); }
@keyframes c-sheet-rise { from { transform:translateY(100%); } }
.c-sheet__head { flex:none; display:flex; align-items:center; gap:var(--space-3); padding:var(--space-2) var(--space-2) var(--space-2) var(--space-4);
  border-bottom:1px solid var(--line); }
.c-sheet__title { flex:1 1 auto; min-width:0; margin:0; font:600 20px/28px var(--font-sans); overflow-wrap:anywhere; }
.c-sheet__dismiss { flex:none; margin:0; }
.c-sheet__close { box-sizing:border-box; width:44px; height:44px; padding:0; }
.c-sheet__close svg { width:20px; height:20px; stroke-width:1.5; }
.c-sheet__body { flex:1 1 auto; min-height:0; overflow-y:auto; overscroll-behavior:contain; overflow-wrap:anywhere;
  padding:var(--space-4) var(--space-4) calc(var(--space-4) + env(safe-area-inset-bottom)); }
/* The content notice on a one-screen focused page (README Mobile and Hotwire): the footer's own text style. */
.c-sheet__foot { display:flex; flex-direction:column; gap:var(--space-1); margin-top:var(--space-4); padding-top:var(--space-4);
  border-top:1px solid var(--line); font:400 12px/16px var(--font-sans); color:var(--ink-muted); }
.c-sheet__foot p { margin:0; }
.c-sheet__foot a { color:var(--brand); text-decoration:none; }
.c-sheet__foot a:hover { text-decoration:underline; }
.c-sheet__foot a:focus-visible { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-sm); }
.c-sheet [hidden] { display:none; } /* c-btn's display would otherwise show a hidden control */
```

- [ ] Run the system spec and `spec/design_system_files_spec.rb` — expect: PASS. RuboCop on the spec.
- [ ] Commit: `feat(design-system): Sheet, a bottom sheet on a native dialog (#343)`

---

## Phase 5: The shell

**Implements:** FR-4 · **Satisfies:** AC-3.1 to AC-3.9
**Files:** `spec/system/design_system_scanner_components_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: `ScanMarkup.shell`, `in_viewport`, `c-shell--focused` (Phase 4). Produces: `c-scan` (a size container named `scan`) and its `__top`, `__back`, `__dest`, `__dest-label`, `__dest-value`, `__dest-text`, `__done`, `__stage`, `__video`, `__guide`, `__line` (`--status`, `--added`), `__line-text`, `__undo`, `__bottom`, `__count`, `__main`, `__torch`.

### T5.1 `c-scan`

- [ ] Add this `describe` after the Sheet one:

```ruby
  describe "the shell (AC-3.1 to AC-3.9)" do
    # [top, height] of the shell and its three rows, and whether the document scrolls either way.
    def shell_rows
      evaluate(<<~JS)
        const rect = (selector) => { const r = document.querySelector(selector).getBoundingClientRect(); return [r.top, r.height] }
        const root = document.documentElement
        return { scan: rect(".c-scan"), top: rect(".c-scan__top"), stage: rect(".c-scan__stage"), bottom: rect(".c-scan__bottom"),
          scrolls: root.scrollHeight > root.clientHeight || root.scrollWidth > root.clientWidth }
      JS
    end

    # The top bar's children in order, and the [width, height] of each control and of the back arrow's icon.
    def top_bar_boxes
      evaluate(<<~JS)
        const size = (selector) => { const r = document.querySelector(selector).getBoundingClientRect(); return [r.width, r.height] }
        const order = [...document.querySelector(".c-scan__top").children].map((el) => el.className.split(" ").pop())
        return { order, back: size(".c-scan__back"), dest: size(".c-scan__dest"), done: size(".c-scan__done"),
          icon: size(".c-scan__back svg"), chevron: size(".c-scan__dest svg") }
      JS
    end

    # [left, width, height] of each control in the bottom bar, in order.
    def bottom_boxes
      evaluate(<<~JS)
        return [...document.querySelector(".c-scan__bottom").children].map((el) => {
          const r = el.getBoundingClientRect(); return [r.left, r.width, r.height] })
      JS
    end

    # The main button in one of its states: its box, its ground, opacity and text, with the two grounds it may have.
    def main_button(main)
      in_viewport(390, 844, shell(main:)) do
        { box: bottom_boxes[1], style: computed(".c-scan__main", "background-color", "opacity", "font-size", "font-weight"),
          brand: token("--brand"), raised: token("--surface-raised") }
      end
    end

    [ [ 390, 844 ], [ 360, 640 ] ].each do |width, height|
      it "is the whole #{width} × #{height} viewport and never scrolls (AC-3.1)", :aggregate_failures do
        in_viewport(width, height, shell) do
          found = shell_rows
          expect(found["scan"]).to eq([ 0, height ])
          expect(found.values_at("top", "stage", "bottom")).to eq([ [ 0, 56 ], [ 56, height - 152 ], [ height - 96, 96 ] ])
          expect(found["scrolls"]).to be(false)
        end
      end
    end

    it "scrolls by the body's margin without c-shell--focused (the measure can fail)" do
      in_viewport(390, 844, shell) do
        page.execute_script("document.body.classList.remove('c-shell--focused')")
        expect(shell_rows["scrolls"]).to be(true)
      end
    end

    it "has a 56px top bar holding Back, the destination and Done, each 44px (AC-3.2)", :aggregate_failures do
      in_viewport(390, 844, shell) do
        found = top_bar_boxes
        expect(found["order"]).to eq(%w[c-scan__back c-scan__dest c-scan__done])
        expect(found.values_at("back", "icon", "chevron")).to eq([ [ 44, 44 ], [ 20, 20 ], [ 20, 20 ] ])
        expect(found["dest"].last).to be >= 44
        expect(found["done"]).to all(be >= 44)
        expect(computed(".c-scan__top", "padding-left", "padding-right")).to eq(%w[8px 8px])
        expect(stroke_width(".c-scan__back svg")).to eq(1.5)
      end
    end

    it "cuts a long destination with an ellipsis and keeps Done whole (AC-3.3)", :aggregate_failures do
      in_viewport(360, 640, shell(value: "A deck with a very long name indeed › Considering · NM")) do
        expect(computed(".c-scan__dest-label", "font-size", "color")).to eq([ "12px", token("--ink-muted") ])
        expect(computed(".c-scan__dest-text", "font-size", "font-weight", "text-overflow", "white-space", "color"))
          .to eq([ "15px", "600", "ellipsis", "nowrap", token("--ink") ])
        expect(evaluate('const el = document.querySelector(".c-scan__dest-text"); return el.scrollWidth > el.clientWidth')).to be(true)
        expect([ box(".c-scan__done")["right"], box(".c-scan__dest-value")["height"] ]).to eq([ 352, 22 ])
        expect(page_fits_sideways?).to be(true)
      end
    end

    it "lays out the count, the main button and the torch in a 96px bar at 390px (AC-3.4)", :aggregate_failures do
      in_viewport(390, 844, shell) do
        expect(bottom_boxes).to eq([ [ 16, 84, 56 ], [ 112, 194, 64 ], [ 318, 56, 56 ] ])
        expect(computed(".c-scan__count b", "font-family").first).to include("IBM Plex Mono")
        expect([ box(".c-scan__torch svg")["width"], stroke_width(".c-scan__torch svg") ]).to eq([ 20, 1.5 ])
        expect(page).to have_button("Torch").and have_button("12 added. Show this sitting's cards.")
        expect(find(".c-scan__torch")["aria-pressed"]).to eq("false")
      end
    end

    it "draws Capture, Capture while reading and Scan again at one place and size (AC-3.5)", :aggregate_failures do
      capture, reading, again = %i[capture reading again].map { main_button(it) }
      expect([ capture, reading, again ].map { it[:box] }.uniq).to eq([ [ 112, 194, 64 ] ])
      expect(capture[:style]).to eq([ capture[:brand], "1", "16px", "600" ])
      expect(reading[:style]).to eq([ reading[:brand], "0.5", "16px", "600" ])
      expect(again[:style]).to eq([ again[:raised], "1", "16px", "600" ])
    end

    it "gives the torch's room to the main button when there is no torch (AC-3.6)" do
      in_viewport(390, 844, shell(torch: false)) { expect(bottom_boxes).to eq([ [ 16, 84, 56 ], [ 112, 262, 64 ] ]) }
    end

    %w[light dark].each do |name|
      it "draws the status line on a raised ground, centred 16px under the stage's top, in the #{name} theme (AC-3.7)", :aggregate_failures do
        in_viewport(390, 844, shell) do
          theme(name)
          line, stage = box(".c-scan__line--status"), box(".c-scan__stage")
          expect(computed(".c-scan__line--status", "background-color", "border-top-color", "border-top-width", "border-top-left-radius", "color"))
            .to eq([ token("--surface-raised"), token("--line-strong"), "1px", "8px", token("--ink") ])
          expect(line["top"] - stage["top"]).to eq(16)
          expect((line["left"] + line["right"]) / 2).to be_within(0.5).of(195)
        end
      end
    end

    it "puts the after-add line in the status line's place, Undo at its end and outside the live region (AC-3.7)", :aggregate_failures do
      in_viewport(390, 844, shell(added: "Added Lightning Bolt MOM · 123, foil", count: 13)) do
        line, stage = box(".c-scan__line--added"), box(".c-scan__stage")
        expect([ line["top"] - stage["top"], line["left"], line["right"] ]).to eq([ 16, 16, 374 ])
        expect(computed(".c-scan__line--status", "display")).to eq([ "none" ])
        expect(computed(".c-scan__line--added", "background-color", "border-top-color")).to eq([ token("--surface-raised"), token("--line-strong") ])
        expect(box(".c-scan__undo .c-btn")["height"]).to eq(44)
        expect(evaluate('return !!document.querySelector(".c-scan__line--added [role=status] .c-scan__undo")')).to be(false)
      end
    end

    it "wraps a long after-add line at 360px with Undo on its first line (AC-3.8)", :aggregate_failures do
      in_viewport(360, 640, shell(added: "Added A card name of forty characters wrapping CLB · 187, foil, and more words")) do
        text, undo, line = box(".c-scan__line--added .c-scan__line-text"), box(".c-scan__undo .c-btn"), box(".c-scan__line--added")
        expect(text["height"]).to be > 44
        expect([ undo["top"] - line["top"], line["right"] - undo["right"] ]).to eq([ 1, 1 ])
        expect(page_fits_sideways?).to be(true)
      end
    end

    it "grounds the stage in surface-sunken under a covering picture, the guide drawn as today (AC-3.9)", :aggregate_failures do
      in_viewport(390, 844, shell(guide: "left:5px;top:80px;width:380px;height:531px")) do
        expect(computed(".c-scan__stage", "background-color")).to eq([ token("--surface-sunken") ])
        expect(computed(".c-scan__video", "object-fit", "position")).to eq(%w[cover absolute])
        expect(box(".c-scan__video").values_at("width", "height")).to eq([ 390, 692 ])
        expect(computed(".c-scan__guide", "border-top-style", "border-top-width", "border-top-color", "outline-style", "outline-color", "outline-offset"))
          .to eq([ "solid", "2px", token("--brand"), "dashed", token("--on-brand"), "-6px" ])
      end
    end
  end
```

- [ ] Run the system spec — expect: the shell examples FAIL (unstyled blocks: no 56px bar, the document scrolls). "scrolls … without c-shell--focused" may pass or fail on arrival (unstyled icons may scroll the frame, which fails `in_viewport`'s own check); either is expected and not a deviation. It is meaningful once AC-3.1 is green.
- [ ] Insert above the `Reduced motion, app-wide` heading:

```css
/* ---------- Scan shell (spec 080): the one-screen scanner page, a top bar, the camera's stage and a bottom bar ---------- */
/* A focused page (README Mobile and Hotwire): no app header, no tab bar, never scrolls; its body carries the focused
   shell's class (the block above), so a shell as tall as the dynamic viewport is the whole screen. The shell is a size
   container named `scan`: the short-screen rule in the pane's block answers to the shell's own height, so a preview's
   frame and a test's frame behave as a phone of that size does. Every size is an outer size (the export sets no
   box-sizing). The stage, the status line and the after-add line follow the theme: there are no always-dark tokens
   (spec 080 decision 5). The stage is its own stacking context, so the lines, the strip and the pane stay inside it.
   Controls are 44px or more at every pointer. State is in the markup: `c-scan--result` shows the capture strip and the
   pane (the pane's block), the main button's `disabled` is the reading state, and the two lines over the camera swap
   with `hidden` on their wrappers. */
.c-scan { container:scan / size; box-sizing:border-box; display:flex; flex-direction:column; height:100vh; height:100dvh; overflow:hidden;
  background:var(--surface); color:var(--ink); font-family:var(--font-sans); }
.c-scan__top { box-sizing:border-box; flex:none; display:flex; align-items:center; gap:var(--space-1); height:56px; padding:0 var(--space-2);
  background:var(--surface-raised); border-bottom:1px solid var(--line); }
.c-scan__back { box-sizing:border-box; flex:none; display:inline-flex; align-items:center; justify-content:center; width:44px; height:44px;
  border-radius:var(--radius-md); color:var(--ink); }
.c-scan__back:focus-visible, .c-scan__dest:focus-visible { outline:2px solid var(--focus); outline-offset:2px; }
.c-scan__back svg, .c-scan__dest svg, .c-scan__torch svg { flex:none; width:20px; height:20px; stroke-width:1.5; }
.c-scan__dest { box-sizing:border-box; flex:1 1 auto; min-width:0; display:flex; flex-direction:column; align-items:flex-start; justify-content:center;
  min-height:44px; padding:0 var(--space-2); border:0; border-radius:var(--radius-md); background:transparent; color:var(--ink);
  font:inherit; text-align:left; cursor:pointer; }
.c-scan__dest-label { font:600 12px/16px var(--font-sans); color:var(--ink-muted); }
.c-scan__dest-value { display:flex; align-items:center; gap:var(--space-1); max-width:100%; font:600 15px/22px var(--font-sans); }
.c-scan__dest-text { min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.c-scan__done { box-sizing:border-box; flex:none; height:44px; min-width:44px; }
.c-scan__stage { position:relative; isolation:isolate; flex:1 1 auto; min-height:0; display:flex; flex-direction:column; overflow:hidden;
  background:var(--surface-sunken); }
.c-scan__video { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; }
/* The guide's box is set inline by the camera controller, as the shipped scanner's is; its geometry is the page's spec's. */
.c-scan__guide { position:absolute; border:2px solid var(--brand); outline:2px dashed var(--on-brand); outline-offset:-6px;
  border-radius:var(--radius-card) / calc(var(--radius-card) * 63 / 88); pointer-events:none; }
.c-scan__line { position:absolute; top:var(--space-4); z-index:1; box-sizing:border-box; display:flex; background:var(--surface-raised);
  border:1px solid var(--line-strong); border-radius:var(--radius-md); color:var(--ink); font:400 14px/20px var(--font-sans); }
.c-scan__line-text { flex:1 1 auto; min-width:0; margin:0; overflow-wrap:anywhere; }
.c-scan__line--status { left:50%; transform:translateX(-50%); width:max-content; max-width:calc(100% - var(--space-4) * 2);
  padding:var(--space-2) var(--space-3); text-align:center; }
/* Undo is 44px and the sentence's first line sits level with it: 12px above a 20px line. */
.c-scan__line--added { left:var(--space-4); right:var(--space-4); align-items:flex-start; gap:var(--space-3); padding-left:var(--space-3); }
.c-scan__line--added .c-scan__line-text { padding:var(--space-3) 0; }
.c-scan__undo { flex:none; margin:0; }
.c-scan__undo .c-btn { box-sizing:border-box; height:44px; min-width:44px; }
.c-scan__bottom { box-sizing:border-box; flex:none; display:flex; align-items:center; gap:var(--space-3); height:96px; padding:0 var(--space-4);
  background:var(--surface-raised); border-top:1px solid var(--line); }
.c-scan__count { box-sizing:border-box; flex:none; flex-direction:column; gap:0; width:84px; height:56px; padding:0; font:400 12px/16px var(--font-sans); }
.c-scan__count b { font:400 13px/18px var(--font-mono); }
.c-scan__main { box-sizing:border-box; flex:1 1 auto; min-width:0; height:64px; font-size:16px; line-height:24px; }
.c-scan__torch { box-sizing:border-box; flex:none; width:56px; height:56px; padding:0; }
.c-scan [hidden] { display:none; } /* c-btn's display, and the lines' flex, would otherwise show a hidden part */
```

- [ ] Run the system spec and `spec/design_system_files_spec.rb` — expect: PASS. RuboCop on the spec.
- [ ] Commit: `feat(design-system): the one-screen scan shell (#343)`

---

## Phase 6: The selection pane

**Implements:** FR-5 · **Satisfies:** AC-4.1 to AC-4.11, AC-6.2
**Files:** `spec/system/design_system_scanner_components_spec.rb`, `spec/design_system_files_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: `ScanMarkup.shell`, `.pane`, `.band`, `.sample_card`; `in_viewport`; `apply_reduced_motion_rules`; the container `scan`. Produces: `c-scan--result`; `c-scan__strip`, `__capture`, `__read`, `__read-label`, `__read-name`, `__read-line`; `c-scanpane` and its `__body`, `__rowwrap`, `__row`, `__item`, `__nav` (`--prev`, `--next`), `__card`, `__details`, `__name`, `__set`, `__meta`, `__position`, `__adds`, `__add`; keyframes `c-scan-shrink`, `c-scanpane-rise`; `.c-scanpane__row { scroll-behavior:auto; }` inside the reduced-motion block.

The sums the examples assert (spec decision 7): the pane's body is a grid of two rows, the row's track `minmax(188px, 316px)` (the images' 160 to 288px and the row's 16 + 12px of padding) and the panel's `1fr`, whose least is 164px (80 + 16 + 52 + 16).

| Viewport | Strip | Pane | Body (pane − band) | Row track | Image | Panel |
|---|---|---|---|---|---|---|
| 390 × 844 | 144 | 548 | 508 | 316 | 288 | 192 (28 spare above the buttons) |
| 390 × 664 | 96 | 416 | 376 | 212 | 184 | 164 |
| 360 × 640 | 96 | 392 | 352 | 188 | 160 | 164 |
| 360 × 640, two-line band | 96 | 392 | 336 | 188 | 160 | 164, scrolls 16 |
| 360 × 560 | 96 | 312 | 272 | 188 | 160 | 164, scrolls 80 |

### T6.1 `c-scanpane` and the capture strip

- [ ] Add this `describe` after the shell's:

```ruby
  describe "the selection pane (AC-4.1 to AC-4.11)" do
    def three_cards
      [ sample_card(set: "Double Masters 2022", code: "2X2 · 117", year: "2022"), sample_card,
        sample_card(set: "Commander Legends: Battle for Baldur’s Gate", code: "CLB · 187", year: "2022") ]
    end

    def matched = band(:success, "Matched by its collector line")
    def unsure = band(:warning, "Not sure of this card. Check it against your capture.", mark: :question)
    def shown = ".c-scanpane__card:not([hidden])"

    # A shell showing a result: the pane over the stage, the second of three cards centred unless told otherwise.
    def result(status: matched, cards: three_cards, current: 1, **options)
      shell(result: pane(band: status, cards:, current:, total: 14, **options))
    end

    # Runs the block in a frame showing a result with its centred card at rest in the middle, as #345's script will leave it.
    def in_result(width, height, html = result)
      in_viewport(width, height, html) do
        evaluate(<<~JS)
          const row = document.querySelector(".c-scanpane__row"), item = row.querySelector('[aria-current="true"]')
          row.scrollTo({ left: item.offsetLeft - (row.clientWidth - item.offsetWidth) / 2, behavior: "instant" })
        JS
        yield
      end
    end

    # Heights of the strip, its picture, the pane, the band, the centred image and the details block; the pane's gaps to
    # the strip above and the bottom bar below; the image's width for a height of 88; the add buttons' gap to the bottom
    # bar; and whether the pane's body scrolls.
    def pane_layout
      evaluate(<<~JS)
        const rect = (selector) => document.querySelector(selector).getBoundingClientRect(), round = (value) => Math.round(value * 10) / 10
        const body = document.querySelector(".c-scanpane__body"), image = rect('.c-scanpane__item[aria-current="true"]')
        return { strip: rect(".c-scan__strip").height, picture: rect(".c-scan__capture").height, pane: rect(".c-scanpane").height,
          above: rect(".c-scanpane").top - rect(".c-scan__strip").bottom, below: rect(".c-scan__bottom").top - rect(".c-scanpane").bottom,
          band: rect(".c-band").height, image: round(image.height), ratio: round(image.width * 88 / image.height),
          details: rect("#{shown} .c-scanpane__details").height, addsGap: round(rect(".c-scan__bottom").top - rect("#{shown} .c-scanpane__adds").bottom),
          scrolls: body.scrollHeight > body.clientHeight }
      JS
    end

    # The row at rest: the centred image's width and centre, how much of each neighbour shows, the gap, the inline
    # padding, the room a scrollbar takes, the snap, and whether the outline's 4px clear the row's clipping edges.
    def row_layout
      evaluate(<<~JS)
        const row = document.querySelector(".c-scanpane__row"), items = [...row.children].map((el) => el.getBoundingClientRect())
        const at = [...row.children].findIndex((el) => el.getAttribute("aria-current") === "true"), mid = items[at], view = row.getBoundingClientRect()
        const round = (value) => Math.round(value * 10) / 10, style = getComputedStyle(row)
        return { width: round(mid.width), centre: round((mid.left + mid.right) / 2), before: round(items[at - 1].right - view.left),
          after: round(view.right - items[at + 1].left), gap: round(mid.left - items[at - 1].right), padding: round(parseFloat(style.paddingLeft)),
          bar: row.offsetHeight - row.clientHeight, snap: [style.scrollSnapType, getComputedStyle(row.children[at]).scrollSnapAlign],
          clear: mid.top - view.top >= 4 && view.bottom - mid.bottom >= 4 }
      JS
    end

    # Where the first image's centre is with the row scrolled to its start, and the last one's with it scrolled to its end.
    def end_centres
      evaluate(<<~JS)
        const row = document.querySelector(".c-scanpane__row")
        const centre = (el) => { const r = el.getBoundingClientRect(); return Math.round((r.left + r.right) / 2) }
        row.scrollTo({ left: 0, behavior: "instant" })
        const first = centre(row.firstElementChild)
        row.scrollTo({ left: row.scrollWidth, behavior: "instant" })
        return [first, centre(row.lastElementChild)]
      JS
    end

    # Each add button of the shown panel: [left, width, height], the lines its words take, and whether they fit inside it.
    def add_buttons
      evaluate(<<~JS)
        return [...document.querySelectorAll("#{shown} .c-scanpane__add .c-btn")].map((el) => {
          const words = [...el.childNodes].find((node) => node.nodeType === 3 && node.textContent.trim()), range = document.createRange()
          range.selectNodeContents(words)
          const lines = new Set([...range.getClientRects()].map((r) => Math.round(r.top))).size, r = el.getBoundingClientRect()
          return { box: [r.left, r.width, r.height], lines, fits: el.scrollHeight <= el.clientHeight && el.scrollWidth <= el.clientWidth } })
      JS
    end

    # The tops of the parts that must never move.
    def fixed_tops = %w[.c-scan__top .c-scan__strip .c-band .c-scan__bottom].map { box(it)["top"] }

    it "shows the capture strip at the top of the stage: a 124px picture and what was read (AC-4.1)", :aggregate_failures do
      in_result(390, 844) do
        strip, picture, stage = box(".c-scan__strip"), box(".c-scan__capture"), box(".c-scan__stage")
        expect([ strip["top"] - stage["top"], strip["height"], picture["height"], picture["top"] - strip["top"] ]).to eq([ 0, 144, 124, 10 ])
        expect(picture["width"]).to be_within(0.1).of(124 * 63 / 88.0)
        expect(computed(".c-scan__read-label", "font-size", "color")).to eq([ "12px", token("--ink-muted") ])
        expect(computed(".c-scan__read-name", "font-size", "font-weight", "text-overflow", "white-space")).to eq(%w[15px 600 ellipsis nowrap])
        expect(computed(".c-scan__read-line", "font-family").first).to include("IBM Plex Mono")
      end
    end

    it "fits the band, the row, the details and the add buttons in 548px at 390 × 844 (AC-4.2)", :aggregate_failures do
      in_result(390, 844) do
        found = pane_layout
        expect(found.values_at("above", "below", "pane", "band", "image")).to eq([ 0, 0, 548, 40, 288 ])
        expect(found.values_at("scrolls", "addsGap")).to eq([ false, 16 ])
        expect(computed(".c-scanpane", "border-top-left-radius", "border-top-right-radius")).to eq(%w[8px 8px])
        expect(box(".c-band")["top"]).to eq(box(".c-scanpane")["top"])
      end
    end

    it "centres a 206px image with 80px of each neighbour, snapped, with no scrollbar (AC-4.3)", :aggregate_failures do
      in_result(390, 844) do
        found = row_layout
        expect(found.values_at("width", "padding")).to match([ be_within(1).of(206), be_within(1).of(92) ])
        expect(found["centre"]).to be_within(0.5).of(195)
        expect(found.values_at("before", "after")).to all(be_within(1).of(80))
        expect(found.values_at("gap", "bar", "snap", "clear")).to eq([ 12, 0, [ "x mandatory", "center" ], true ])
        expect(page_fits_sideways?).to be(true)
      end
    end

    it "outlines the centred image in brand, 63:88 with the card's corners (AC-4.3)", :aggregate_failures do
      in_result(390, 844) do
        centred = '.c-scanpane__item[aria-current="true"]'
        expect(computed(centred, "outline-style", "outline-width", "outline-color")).to eq([ "solid", "2px", token("--brand") ])
        expect(computed(centred, "border-top-left-radius").first).to start_with("4.75%")
        expect(computed(".c-scanpane__item:not([aria-current])", "outline-style")).to eq([ "none" ])
        expect(pane_layout["ratio"]).to eq(63)
      end
    end

    it "can centre its first and its last image (AC-4.3)" do
      in_result(390, 844) { expect(end_centres).to eq([ 195, 195 ]) }
    end

    it "puts Previous and Next over the neighbours, 44px, the one at the row's end disabled (AC-4.4)", :aggregate_failures do
      in_result(390, 844, result(current: 0)) do
        prev, nxt, wrap = box(".c-scanpane__nav--prev"), box(".c-scanpane__nav--next"), box(".c-scanpane__rowwrap")
        expect([ prev, nxt ].map { it.values_at("width", "height") }).to eq([ [ 44, 44 ], [ 44, 44 ] ])
        expect([ prev["left"], 390 - nxt["right"], (prev["top"] + prev["bottom"]) / 2 - wrap["top"] ]).to eq([ 8, 8, 16 + 144 ])
        expect(page).to have_button("Previous printing", disabled: true).and have_button("Next printing", disabled: false)
        expect(computed(".c-scanpane__nav--next", "background-color")).to eq([ token("--surface-raised") ])
        expect([ box(".c-scanpane__nav--next svg")["width"], stroke_width(".c-scanpane__nav--next svg") ]).to eq([ 20, 1.5 ])
      end
    end

    it "rings Next on keyboard focus, and scrolls the row smoothly only without the reduced-motion preference (AC-4.4)", :aggregate_failures do
      in_result(390, 844) do
        find(".c-scanpane__nav--prev").send_keys(:tab)
        expect(computed(".c-scanpane__nav--next", "outline-style", "outline-width", "outline-color")).to eq([ "solid", "2px", token("--focus") ])
        expect(computed(".c-scanpane__row", "scroll-behavior")).to eq([ "smooth" ])
        apply_reduced_motion_rules(needs: [ ".c-scanpane__row" ])
        expect(computed(".c-scanpane__row", "scroll-behavior")).to eq([ "auto" ])
      end
    end

    it "describes the centred card in one 80px block: name, set, then code, year and position (AC-4.5)", :aggregate_failures do
      in_result(390, 844) do
        expect(box("#{shown} .c-scanpane__details").values_at("left", "right", "height")).to eq([ 16, 374, 80 ])
        expect(computed("#{shown} .c-scanpane__name", "font-size", "font-weight") + computed("#{shown} .c-scanpane__set", "font-size")).to eq(%w[20px 600 15px])
        expect(computed("#{shown} .c-scanpane__meta", "color")).to eq([ token("--ink-muted") ])
        expect(computed("#{shown} .c-scanpane__meta", "font-family").first).to include("IBM Plex Mono")
        expect(box("#{shown} .c-scanpane__position")["right"]).to eq(374)
        expect(find("#{shown} .c-scanpane__meta").text(normalize_ws: true)).to eq("MOM · 123 2023 2 of 14 printings")
      end
    end

    it "shares the pane's width between two add buttons, the special finish with its star (AC-4.6)", :aggregate_failures do
      in_result(390, 844) do
        expect(add_buttons.map { it["box"] }).to eq([ [ 16, 175, 52 ], [ 199, 175, 52 ] ])
        expect(computed("#{shown} .c-scanpane__add .c-btn", "font-size", "line-height", "font-weight", "padding-left", "background-color"))
          .to eq([ "15px", "20px", "600", "8px", token("--surface-raised") ])
        expect(computed("#{shown} .c-scanpane__add svg", "width", "color")).to eq([ "14px", token("--foil") ])
        expect(evaluate(%(return [...document.querySelectorAll("#{shown} .c-scanpane__add svg")].map((el) => el.getAttribute("aria-hidden")))))
          .to eq([ "true" ])
      end
    end

    it "gives one finish a full-width Add, and a row of one card no way to move (AC-4.6)", :aggregate_failures do
      in_result(390, 844, result(cards: [ sample_card(finishes: %w[nonfoil]) ], current: 0)) do
        expect(add_buttons.map { it["box"] }).to eq([ [ 16, 358, 52 ] ])
        expect(page).to have_button("Previous printing", disabled: true).and have_button("Next printing", disabled: true)
      end
    end

    it "shrinks the strip and the images at 390 × 664 and still shows the add buttons (AC-4.7)", :aggregate_failures do
      in_result(390, 664) do
        found = pane_layout
        expect(found.values_at("strip", "picture", "ratio", "scrolls", "addsGap")).to eq([ 96, 76, 63, false, 16 ])
        expect(found["image"]).to be_within(2).of(184)
      end
    end

    it "holds the images at 160px at 360 × 640 with a one-line band, nothing scrolling (AC-4.7)" do
      in_result(360, 640) { expect(pane_layout.values_at("band", "image", "scrolls")).to eq([ 40, 160, false ]) }
    end

    it "scrolls the pane's content at 360 × 640 with a two-line band (AC-4.7)" do
      in_result(360, 640, result(status: unsure, noun: "possible cards", step: "card")) do
        expect(pane_layout.values_at("band", "image", "scrolls")).to eq([ 56, 160, true ])
      end
    end

    it "scrolls the pane's content at 360 × 560 and keeps the bars, the strip and the band in place (AC-4.7)", :aggregate_failures do
      in_result(360, 560) do
        before = fixed_tops
        evaluate('document.querySelector(".c-scanpane__body").scrollTop = 60')
        expect(pane_layout["scrolls"]).to be(true)
        expect(fixed_tops).to eq(before)
        expect(evaluate('return [window.scrollY, document.querySelector(".c-scanpane__body").scrollTop]')).to eq([ 0, 60 ])
      end
    end

    it "shrinks the capture and slides the pane in 200ms, and neither under reduced motion (AC-4.8)", :aggregate_failures do
      in_result(390, 844) do
        expect(computed(".c-scanpane", "animation-name", "animation-duration")).to eq(%w[c-scanpane-rise 0.2s])
        expect(computed(".c-scan__capture", "animation-name", "animation-duration")).to eq(%w[c-scan-shrink 0.2s])
        apply_reduced_motion_rules(needs: [ "::backdrop" ])
        expect(computed(".c-scanpane", "animation-name") + computed(".c-scan__capture", "animation-name")).to eq(%w[none none])
      end
    end

    it "wraps a 60-character set name and a 40-character card name at 360px (AC-4.9)", :aggregate_failures do
      long = sample_card(name: "A card name of forty characters wrapping", set: "A set name of sixty characters long enough to wrap two lines")
      in_result(360, 640, result(cards: [ long ], current: 0)) do
        expect([ box(".c-scanpane__name")["height"], box(".c-scanpane__set")["height"] ]).to eq([ 56, 44 ])
        expect(box(".c-scanpane__set")["right"]).to be <= 344
        expect(evaluate('const el = document.querySelector(".c-scanpane__body"); return el.scrollWidth <= el.clientWidth')).to be(true)
        expect(page_fits_sideways?).to be(true)
      end
    end

    it "shows only the centred card's panel (AC-4.10)" do
      in_result(390, 844) do
        heights = evaluate('return [...document.querySelectorAll(".c-scanpane__card")].map((el) => el.getBoundingClientRect().height > 0)')
        expect(heights).to eq([ false, true, false ])
      end
    end

    it "keeps a hidden button hidden in the shell, the pane and a sheet (AC-4.10)" do
      hidden = %(<button class="c-btn" hidden>Hidden</button>)
      add_to_main(%(<div class="c-scan">#{hidden}</div><div class="c-scanpane">#{hidden}</div>) + sheet(title: "Adding to", body: hidden, open: true))
      expect(evaluate('return [...document.querySelectorAll("main .c-btn[hidden]")].map((el) => getComputedStyle(el).display)')).to eq(%w[none none none])
    end

    it "wraps the foil marker's label onto two lines inside a 160px button at 360px (AC-4.11)", :aggregate_failures do
      in_result(360, 640, result(labels: { "foil" => "Add foil · read from the card" })) do
        found = add_buttons
        expect(found.map { it["box"].last(2) }).to eq([ [ 160, 52 ], [ 160, 52 ] ])
        expect(found.map { it.values_at("lines", "fits") }).to eq([ [ 1, true ], [ 2, true ] ])
        expect(computed("#{shown} .c-scanpane__add:last-child .c-btn", "text-align")).to eq([ "center" ])
      end
    end
  end
```

- [ ] Run the system spec — expect: the pane examples FAIL (no strip or pane is displayed with `c-scan--result`; `apply_reduced_motion_rules` raises `no reduced-motion rule matches [".c-scanpane__row"]`). "keeps a hidden button hidden" fails for the pane only (the shell's and the sheet's rules exist). "shows only the centred card's panel" passes on arrival (the browser's own `[hidden]` rule and the shell's hide the other panels): a characterisation, said so in the commit. AC-4.9's heights (two lines each, 56px and 44px) depend on where the fonts wrap: if a name takes three lines, change the expectation to the measured height and record it.
- [ ] Insert above the `Reduced motion, app-wide` heading:

```css
/* ---------- Scan pane (spec 080): a result over the stage: the capture strip, the band, a row of card images, one details block, the add buttons ---------- */
/* `c-scan--result` on the shell shows both. The strip is the frozen capture, shrunk, with what was read beside it: 144px
   high with a 124px picture, 96px with a 76px one in a shell less than 720px high (the container query at the end), and
   never taller, so the name read is one line. The pane fills the rest of the stage. Its band never scrolls; its body is a
   grid of two rows. The first is the image row, 160px to 288px of image and its own 16px above and 12px below; the second
   is the centred card's panel and takes what is left, its add buttons at its foot, so spare room goes above them. When the
   two do not fit (a short screen, a wrapped band or set name) the images have already given way to 160px and the body
   scrolls inside the pane. The sums are in spec 080 decision 7.
   The row is a size container, so an image's width is known from the row's height: the inline padding is half the row less
   half an image, which lets the first and the last image be centred. The row draws no scrollbar (Previous and Next are the
   way to move it without a swipe, and a classic scrollbar would take 12px to 15px of the pane), snaps each image to the
   centre, and scrolls smoothly; its `auto` under reduced motion is in the last block. The centred image is the one with
   `aria-current="true"`; the server renders one `c-scanpane__card` per image and all but the centred one carry `hidden`.
   An add button wraps its words onto two lines: a foil marker read off the card makes a label wider than half a pane.
   The capture's shrink starts from `--from` times its size (about the guide's height over the picture's), which the page's
   script may set; both movements take 200ms and stop under reduced motion. */
.c-scan__strip { position:relative; z-index:1; box-sizing:border-box; flex:none; display:none; align-items:center; gap:var(--space-4); height:144px;
  padding:0 var(--space-4); background:var(--surface-sunken); }
.c-scan--result .c-scan__strip { display:flex; }
.c-scan__capture { box-sizing:border-box; flex:none; height:124px; aspect-ratio:63 / 88; border:1px solid var(--line-strong);
  border-radius:var(--radius-card) / calc(var(--radius-card) * 63 / 88); background:var(--surface-raised); object-fit:cover; }
.c-scan--result .c-scan__capture { transform-origin:top left; animation:c-scan-shrink .2s ease-out; }
@keyframes c-scan-shrink { from { transform:scale(var(--from, 4)); } }
.c-scan__read { min-width:0; display:flex; flex-direction:column; gap:var(--space-1); }
.c-scan__read-label { margin:0; font:600 12px/16px var(--font-sans); color:var(--ink-muted); }
.c-scan__read-name { margin:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; font:600 15px/22px var(--font-sans); color:var(--ink); }
.c-scan__read-line { margin:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; font:400 13px/18px var(--font-mono); color:var(--ink); }
.c-scanpane { position:relative; z-index:1; box-sizing:border-box; flex:1 1 auto; min-height:0; display:none; flex-direction:column; overflow:hidden;
  border-radius:var(--radius-md) var(--radius-md) 0 0; background:var(--surface); }
.c-scan--result .c-scanpane { display:flex; animation:c-scanpane-rise .2s ease-out; }
@keyframes c-scanpane-rise { from { transform:translateY(100%); } }
.c-scanpane > .c-band { flex:none; }
.c-scanpane__body { flex:1 1 auto; min-height:0; display:grid; overflow-y:auto; overscroll-behavior:contain;
  grid-template-rows:minmax(calc(160px + var(--space-4) + var(--space-3)), calc(288px + var(--space-4) + var(--space-3))) 1fr; }
.c-scanpane__rowwrap { container-type:size; position:relative; min-height:0; }
.c-scanpane__row { box-sizing:border-box; display:flex; gap:var(--space-3); height:100%; margin:0; list-style:none;
  padding:var(--space-4) calc(50cqw - (100cqh - var(--space-4) - var(--space-3)) * 63 / 176) var(--space-3);
  overflow-x:auto; overflow-y:hidden; overscroll-behavior-x:contain; scroll-snap-type:x mandatory; scroll-behavior:smooth; scrollbar-width:none; }
.c-scanpane__row::-webkit-scrollbar { display:none; }
.c-scanpane__item { box-sizing:border-box; flex:none; height:100%; aspect-ratio:63 / 88; overflow:hidden; scroll-snap-align:center;
  border-radius:var(--radius-card) / calc(var(--radius-card) * 63 / 88); background:var(--surface-sunken); }
.c-scanpane__item[aria-current="true"] { outline:2px solid var(--brand); outline-offset:2px; }
.c-scanpane__item img { display:block; width:100%; height:100%; object-fit:contain; }
/* Previous and Next: over the visible part of each neighbour, level with the images' middle. */
.c-scanpane__nav { position:absolute; top:calc(var(--space-4) + (100% - var(--space-4) - var(--space-3)) / 2 - 22px); box-sizing:border-box;
  width:44px; height:44px; padding:0; }
.c-scanpane__nav--prev { left:var(--space-2); }
.c-scanpane__nav--next { right:var(--space-2); }
.c-scanpane__nav svg { width:20px; height:20px; stroke-width:1.5; }
.c-scanpane__card { box-sizing:border-box; display:flex; flex-direction:column; padding:0 var(--space-4) var(--space-4); }
.c-scanpane__details { display:flex; flex-direction:column; gap:var(--space-1); }
.c-scanpane__name { margin:0; font:600 20px/28px var(--font-sans); color:var(--ink); overflow-wrap:anywhere; }
.c-scanpane__set { margin:0; font:400 15px/22px var(--font-sans); color:var(--ink); overflow-wrap:anywhere; }
/* 22px: the tag on this line is 20px with its border, and the line would otherwise be 20px (the block is 80px). */
.c-scanpane__meta { display:flex; align-items:center; gap:var(--space-2); min-height:22px; margin:0; font:400 13px/18px var(--font-mono); color:var(--ink-muted); }
.c-scanpane__position { margin-left:auto; white-space:nowrap; }
.c-scanpane__adds { display:flex; gap:var(--space-2); margin-top:auto; padding-top:var(--space-4); }
.c-scanpane__add { flex:1 1 0; min-width:0; margin:0; }
.c-scanpane__add .c-btn { box-sizing:border-box; width:100%; height:52px; padding:0 var(--space-2); font-size:15px; line-height:20px;
  white-space:normal; text-align:center; }
.c-scanpane__add .c-btn svg { width:14px; height:14px; color:var(--foil); }
.c-scanpane [hidden] { display:none; } /* c-btn's display, and a panel's flex, would otherwise show a hidden part */
@container scan (max-height: 719px) {
  .c-scan__strip { height:96px; }
  .c-scan__capture { height:76px; }
}
```

- [ ] In the reduced-motion block, add inside the media rule, after the universal rule: `  .c-scanpane__row { scroll-behavior:auto; }`
- [ ] Run the system spec — expect: PASS. Then `bin/rspec spec/design_system_files_spec.rb` — expect: PASS (`!important` still twice, the block still last).
- [ ] Commit: `feat(design-system): the scan pane, its capture strip and the short-screen rule (#343)`

### T6.2 The blocks' guard (AC-6.2)

- [ ] Add inside `describe "the phone-first scanner's blocks (spec 080)"` in `spec/design_system_files_spec.rb`:

```ruby
    it "keeps each part in a block of its own, with no colour literal and no font but the tokens' (AC-6.2)", :aggregate_failures do
      expect(blocks.map { it[%r{/\* -+ (.+?) \(spec 080}, 1] }).to eq([ "StatusBand", "Focused shell", "Sheet", "Scan shell", "Scan pane", "Reduced motion, app-wide" ])
      rules = blocks.map { it.gsub(%r{/\*.*?\*/}m, "") }
      expect(rules.grep(/#\h{3,8}\b|rgba?\(|hsla?\(/i)).to be_empty
      expect(rules.join.scan(/font(?:-family)?:[^;}]*/).reject { it.include?("var(--font-") || it == "font:inherit" }).to be_empty
    end
```

- [ ] Run `bin/rspec spec/design_system_files_spec.rb` — expect: PASS on arrival (a guard over what Phases 2 to 6 wrote). Show it can fail: add `color:#fff;` to `.c-band` in the working tree, run (expect FAIL), and restore the line. Record the mutation in the commit body.
- [ ] Run the three earlier scanner specs to confirm nothing shipped moved: `bin/rspec spec/system/scanner_spec.rb spec/system/scanner_sitting_spec.rb spec/system/scanner_adding_spec.rb` — expect: PASS.
- [ ] Commit: `test(design-system): the spec 080 blocks hold no colour literal and stay in blocks of their own (#343)`

---

## Phase 7: The documents

**Implements:** FR-6 · **Satisfies:** AC-1.6, AC-2.6, AC-5.1 to AC-5.7, AC-5.11 (by reading; no RSpec example reads these files)
**Files:** `docs/design-system/README.md`, `docs/design-system/components/StatusBand.md`, `Sheet.md`, `Scanner.md`
**Interfaces:** Consumes: the classes of Phases 3 to 6, `ScanMarkup`'s markup. Produces: the documents Phase 8's previews and #344 and #345 read.

Markup in the documents is `ScanMarkup`'s output, pasted and shortened with "…" where a part repeats: print it with `ruby -r ./spec/support/scan_markup.rb -e 'puts ScanMarkup.shell(result: ScanMarkup.pane(band: ScanMarkup.band(:success, "Matched by its collector line"), cards: [ScanMarkup.sample_card], total: 14))'`. In a document an image is an `<img>` inside the `li` (`<li class="c-scanpane__item" aria-current="true"><img src="…" alt="Lightning Bolt, March of the Machine, MOM · 123"></li>`) and the capture is `<canvas class="c-scan__capture"></canvas>`.

### T7.1 README

- [ ] **Color**, after the bullet "`success`, `warning`, `danger` are status only…", add:

```markdown
- **Status band.** A status colour has one filled use, the `StatusBand`: `success` or `warning` as the ground of a band that says how sure a result is, with `on-success` or `on-warning` for the sentence and the icon on it (4.5:1 or better in both themes; the dark theme's `success` and `warning` are light, so white fails on them). `danger` is never a fill: something that went wrong is a `StatusMessage`. A band always carries an icon and words (spec 080).
- `scrim` (black at 40% in both themes) dims the page behind an open `Sheet`, as the dialog's backdrop, and is used for nothing else (spec 080 decision 4).
```

- [ ] After the **States** section, add a section:

```markdown
## Motion

- Nothing moves without a cause the collector started: a tap, a capture, opening a sheet.
- A transition or an animation takes 200ms at most and is instant under `prefers-reduced-motion: reduce`. One block, the last in `collector/additions.css`, turns every transition and animation off under that preference, app-wide (spec 080 decision 14). Its two declarations are the stylesheets' only `!important`, because a universal selector loses to any class rule. A new block goes above it.
- A scroll the browser animates (`scroll-behavior: smooth`) is smooth only without the preference: its `auto` sits in the same block.
```

- [ ] **Mobile and Hotwire**: after the bullet "Phones get a compact header and a bottom tab bar (see Navigation).", add:

```markdown
- **Focused pages.** A page for one task done many times in a row may drop the app header and the tab bar when it keeps a back arrow and its own primary action in view at all times. Its `<body>` carries `c-shell--focused` beside `c-shell--untabbed`, which removes the body's margin and minimum height so the page is exactly the screen (spec 080). The phone-first scanner is the first (`Scanner`); no page is built this way yet.
- A focused page that is one screen high and has no footer shows the content notice's lines in the foot of each of its sheets (`Sheet`); such a page has a sheet or keeps the footer, and a focused page that scrolls keeps the footer. No page does this yet: the scanner keeps its footer until #344 builds the one-screen page (spec 080 decision 13).
- **Sheets.** Content that would otherwise take the collector off a page whose state a navigation would lose (a running camera) opens in a `Sheet`, a bottom sheet over the page. A sheet is a native `<dialog>` opened as a modal, which needs script. It is the one exception to "Nothing needs JavaScript" below: use it only on a page that already needs script, or give its opener a plain link to a page that holds the same content (spec 080 decision 2).
- **Swipes.** A swipe always has a button that does the same: Previous and Next beside a row that is swiped. The buttons are the way for a keyboard, switch access and a fine pointer (spec 080).
```

- [ ] In the bullet "Nothing needs JavaScript to render or work. Menus are `<details>`; …", add at its end: " A `Sheet` is the one exception (Sheets, above)."
- [ ] In the Touch bullet, in its last sentence's list "(Locations, the Decks pages, number entry's list, the scanner's adds, undos and sitting)", add ", the phone-first scanner's shell and pane and a sheet's Close".
- [ ] **Components**, "Current set": rewrite "`DeckShape`, `DeckCheck` and `ProxyTag` (parts)" as "`DeckShape`, `DeckCheck`, `ProxyTag` (parts), `StatusBand` and `Sheet`". After the last "App additions" line add:

```markdown
App additions (spec 080, #343, in `collector/additions.css`; no view uses them yet): `StatusBand` (`c-band`, `c-band--success`, `c-band--warning`); `Sheet` (`c-sheet` and its `__head`, `__title`, `__dismiss`, `__close`, `__body`, `__foot`); the phone-first `Scanner`'s shell (`c-scan` with `c-scan--result`, its `__top`, `__back`, `__dest`, `__done`, `__stage`, `__video`, `__guide`, `__line`, `__undo`, `__strip`, `__capture`, `__read`, `__bottom`, `__count`, `__main`, `__torch`, and `c-shell--focused` on the `<body>`) and pane (`c-scanpane` and its `__body`, `__rowwrap`, `__row`, `__item`, `__nav`, `__card`, `__details`, `__name`, `__set`, `__meta`, `__position`, `__adds`, `__add`); and the app-wide reduced-motion block (Motion). Tokens: `on-success`, `on-warning`, `scrim`.
```

- [ ] **Iconography**, at the end of the bullet "Stroke follows the size…", add: " Spec 080 adds the `StatusBand`'s icons at 16px and stroke 2, the foil add button's star at 14px (filled, so it has no stroke), and 20px icons at stroke 1.5 inside buttons, where the component sets back the 2 a `c-btn` gives its icons: the phone-first scanner's bars (the back arrow, the destination's chevron, the torch), the row's Previous and Next chevrons and a sheet's Close cross."
- [ ] Commit: `docs(design-system): focused pages, sheets, swipes, motion and the status band in the README (#343)`

### T7.2 `StatusBand.md` and `Sheet.md`

- [ ] Create `docs/design-system/components/StatusBand.md`:

````markdown
# StatusBand

A filled band across the top of a result that says, in an icon and a sentence, how sure the app is of it (spec 080). It is the one filled use of a status colour.

**Markup** — the consumer provides the form, the icon and the sentence.

```html
<p class="c-band c-band--success" role="status"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg><span>Matched by its collector line</span></p>
<p class="c-band c-band--warning" role="status"><svg …the alert triangle…></svg><span>Printing not confirmed. Swipe to check.</span></p>
<p class="c-band c-band--warning" role="status"><svg …a question mark in a circle…></svg><span>Not sure of this card. Check it against your capture.</span></p>
```

- Three forms: success with a check, warning with the alert triangle, warning with a question mark in a circle. The two warnings differ by icon and words, never by colour.
- The ground is `success` or `warning`; the sentence and the icon are `on-success` or `on-warning` (4.5:1 or better in both themes). It uses no other colour. `danger` has no band: something that went wrong is a `StatusMessage`.
- A band always carries an icon and a sentence. It holds no control and is never decoration.
- 14px/20px, weight 600, `space-4` at the sides. One line is 40px high with the line centred; a longer sentence wraps, the band grows (56px for two lines) and the icon stays on the first line. The icon is 16px at stroke 2.
- It is a live region (`role="status"`) and one element: when what it describes changes, its form class, icon and sentence are replaced in place, which is what gets announced. Never render a second band and reveal it with `hidden`.
- First use: the top edge of the scanner's selection pane (built by #345). Its sentences there: "Matched by its collector line", "Matched by its collector line, one digit corrected" and "Matched by its artwork" (success); "Printing not confirmed. Swipe to check." and "Not the printing that was read" (warning, alert); "Not sure of this card. Check it against your capture." (warning, question mark).
- It names no collectible.
````

- [ ] Create `docs/design-system/components/Sheet.md`:

````markdown
# Sheet

A panel that opens from the bottom edge over a page, for content that would otherwise take the collector off a page whose state a navigation would lose (spec 080). It is a native `<dialog>` opened as a modal.

**Markup** — the consumer provides the title, the body and, on a one-screen focused page, the content notice's lines; the page's script opens it with `showModal()`.

```html
<dialog class="c-sheet" id="destination" aria-labelledby="destination_title">
  <div class="c-sheet__head">
    <h2 class="c-sheet__title" id="destination_title">Adding to</h2>
    <form method="dialog" class="c-sheet__dismiss"><button class="c-btn c-btn--ghost c-sheet__close" aria-label="Close"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M18 6 6 18M6 6l12 12"/></svg></button></form>
  </div>
  <div class="c-sheet__body">
    …
    <div class="c-sheet__foot"><p>…the content notice's first line…</p><p>…its second…</p></div>
  </div>
</dialog>
```

- Opened as a modal: focus moves into the sheet, and on closing it returns to the control that opened it. Both are the element's own.
- Three ways to close: the Close button (the cross at 20px in a 44px button, named "Close", in a `form method="dialog"`, so it needs no script), Escape, and a tap on the backdrop. The first two are the element's own; the tap is the page's script and is not built yet (#344).
- Fixed to the bottom edge, as wide as the screen, 85% of its height at most. The head (the title in `heading`, Close) stays in view and the body scrolls, without passing the scroll on to the page behind. The body's last padding clears a phone's home indicator.
- `surface-raised` with a 1px `line-strong` top border and `radius-md` top corners; no shadow. The backdrop is `scrim`, its only use. It slides up in 200ms and closes at once; under reduced motion it does not slide.
- **It needs script to open.** Use it only on a page that already needs script, or give its opener a plain link to a page that holds the same content. It is the one exception to "Nothing needs JavaScript" (README, Mobile and Hotwire).
- **It never navigates** on a page that holds the camera: a visit would release it. A form in a sheet answers with a Turbo Stream.
- **The foot.** A focused page that is one screen high has no footer, so each of its sheets ends with the content notice's lines in `c-sheet__foot`, in the footer's text style (12px `ink-muted`, links in `brand`), under a `line` rule. A source that supplies no notice gives no foot. No page does this yet: the scanner keeps its footer until #344 builds the one-screen page (spec 080 decision 13).
- Parts shown and hidden inside it use the `hidden` attribute; `.c-sheet [hidden]` keeps a hidden `c-btn` hidden. The layout is on `.c-sheet[open]`, so never set `display` on `.c-sheet` itself.
- First two uses, on the phone-first scanner (built by #344): the sitting's destination ("Adding to") and the sitting's list. Preview: `Sheet.html`, where the sheets are drawn with the `open` attribute and so have no backdrop.
- It names no collectible.
````

- [ ] Commit: `docs(design-system): StatusBand and Sheet (#343)`

### T7.3 `Scanner.md`

- [ ] Keep the title `# Scanner`. Replace the summary paragraph under it with the introduction below, add the new first section, then the heading `## As built, until #344 and #345` followed by the document's previous text from "The card scanner (spec 007): a live camera feed…" to its last bullet, unchanged (check with `git diff`: the old lines appear only as moved context, with no `-` line but the title's neighbour).

````markdown
# Scanner

The card scanner. Two sections: the phone-first scanner, drawn by spec 080 (#343) and built by #344 (the one-screen page) and #345 (the selection pane); and the scanner as built today, which stays true until those merge. Each of them deletes what it replaces in the second section.

## The phone-first scanner (drawn by spec 080, built by #344 and #345)

One screen that never scrolls: a top bar with the sitting's destination, the camera filling everything between the bars, and a bottom bar whose main button is always in view. After a capture the frozen capture shrinks into a strip and the selection pane slides up over the rest of the stage. Previews: `ScannerFlow.html` (the five steps), `ScannerConfidence.html` (the pane's three states), `Sheet.html` (the two sheets).

**Markup** — no view renders it yet. Shown for a Magic: The Gathering card, with a result.

```html
<body class="c-shell c-shell--untabbed c-shell--focused">
<div class="c-scan c-scan--result">
  <div class="c-scan__top">
    <a class="c-scan__back" href="/collection" aria-label="Back"><svg …back…></svg></a>
    <button type="button" class="c-scan__dest"><span class="c-scan__dest-label">Adding to</span> <span class="c-scan__dest-value"><span class="c-scan__dest-text">Atraxa › Main · NM</span><svg …chevron…></svg></span></button>
    <a class="c-btn c-btn--ghost c-scan__done" href="…">Done</a>
  </div>
  <div class="c-scan__stage">
    <video class="c-scan__video" playsinline muted></video>
    <div class="c-scan__guide" aria-hidden="true"></div>
    <div class="c-scan__line c-scan__line--status" hidden><p class="c-scan__line-text" role="status"></p></div>
    <div class="c-scan__line c-scan__line--added" hidden><p class="c-scan__line-text" role="status"></p><form class="c-scan__undo">…<button class="c-btn c-btn--ghost">Undo</button></form></div>
    <div class="c-scan__strip">
      <canvas class="c-scan__capture"></canvas>
      <div class="c-scan__read"><p class="c-scan__read-label">Read from the card</p><p class="c-scan__read-name">Lightning Bolt</p><p class="c-scan__read-line">MOM · 123 · EN</p></div>
    </div>
    <div class="c-scanpane">
      <p class="c-band c-band--success" role="status"><svg …check…></svg><span>Matched by its collector line</span></p>
      <div class="c-scanpane__body">
        <div class="c-scanpane__rowwrap">
          <ul class="c-scanpane__row">
            <li class="c-scanpane__item" aria-current="true"><img src="…" alt="Lightning Bolt, March of the Machine, MOM · 123"></li>
            <li class="c-scanpane__item"><img src="…" alt="…"></li>
          </ul>
          <button type="button" class="c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--prev" aria-label="Previous printing" disabled><svg …></svg></button>
          <button type="button" class="c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--next" aria-label="Next printing"><svg …></svg></button>
        </div>
        <div class="c-scanpane__card">
          <div class="c-scanpane__details">
            <h2 class="c-scanpane__name">Lightning Bolt</h2>
            <p class="c-scanpane__set">March of the Machine</p>
            <p class="c-scanpane__meta"><span class="c-tag">MOM · 123</span> <span>2023</span> <span class="c-scanpane__position">1 of 14 printings</span></p>
          </div>
          <div class="c-scanpane__adds">
            <form class="c-scanpane__add">…<button class="c-btn c-btn--secondary" aria-label="Add Lightning Bolt MOM · 123 Nonfoil">Add nonfoil</button></form>
            <form class="c-scanpane__add">…<button class="c-btn c-btn--secondary" aria-label="Add Lightning Bolt MOM · 123 Foil"><svg …star… aria-hidden="true"></svg>Add foil</button></form>
          </div>
        </div>
        <div class="c-scanpane__card" hidden>…</div>
      </div>
    </div>
  </div>
  <div class="c-scan__bottom">
    <button type="button" class="c-btn c-btn--secondary c-scan__count" aria-label="12 added. Show this sitting's cards."><b>12</b><span>added</span></button>
    <button type="button" class="c-btn c-btn--secondary c-scan__main">Scan again</button>
    <button type="button" class="c-btn c-btn--secondary c-scan__torch" aria-label="Torch" aria-pressed="false"><svg …></svg></button>
  </div>
</div>
</body>
```

- **A focused page** (README, Mobile and Hotwire): no app header and no tab bar. The `<body>` carries `c-shell--focused` beside `c-shell--untabbed`, so the shell (`c-scan`, as tall as the dynamic viewport) is exactly the screen and the document never scrolls. The top bar is 56px, the bottom bar 96px, and the stage is everything between.
- **Controls** are 44px or more at every pointer: Back (44px), the destination, Done, the count (84 × 56px), the main button (64px high, taking the room that is left; the torch's too when there is none) and the torch (56px, only where the camera reports one).
- **The destination** opens the sitting's choices in a `Sheet`; the count opens the sitting's list in another. Neither navigates: every visit to the scanner releases the camera. "Done" keeps its confirm page and "Details" of an add still leaves for Edit copy. The destination sheet's form keeps `c-scanner__place` (its fieldset's `min-width:0`, spec 042 AC-7.1), and the list keeps `c-scanner__sitting`.
- **State is in the markup, never in a script's memory.** `c-scan--result` on the shell shows the capture strip and the pane; without it the stage is the live camera. The main button's `disabled` is the reading state. The row's centred item carries `aria-current="true"`. The server renders one `c-scanpane__card` per image, and every one but the centred card's carries `hidden`. Parts are shown and hidden with the `hidden` attribute.
- **The stage follows the theme**: `surface-sunken` under the picture, which covers it. The guide is drawn as today (`brand`, with an `on-brand` dashed line inside), its box set inline by the camera controller. The guide's geometry is #344's, which re-measures the reading at the new framing.
- **Two lines over the camera**, 16px under the stage's top, on `surface-raised` with a `line-strong` border: the status line, centred, and the after-add line, which takes its place and spans the stage. While one shows, the other's wrapper carries `hidden`. Each line's `role="status"` element stays in the document and its text is inserted or replaced, which is what gets announced; Undo sits in the wrapper, outside the live region. The status line, the after-add line and the band are the page's three live regions.
- **Capture and add stay the collector's taps**, and one reading adds at most one copy. The frozen frame and the capture strip are drawn in the page from the captured frame: the picture never leaves the device and nothing new is sent.
- **The capture strip** is 144px with a 124px picture, 96px with a 76px one when the screen is less than 720px high, and never taller: the name read is one line.
- **The pane** fills the rest of the stage. The `StatusBand` is its top edge and never scrolls. Under it the image row gives way on a short screen: the images are 288px high at most and 160px at least. When the pane still does not fit (below 640px of screen, or with a wrapped band or set name), its content scrolls inside it; the bars, the strip and the band never move.
- **The row** scrolls sideways with scroll snap and draws no scrollbar. It holds the candidates first (three at most, in ranked order), then the centred card's other printings in today's Other printings order; when the scanner is not sure of the card it holds the candidate cards. The centred image has a 2px `brand` outline, and the images carry no text.
- **A swipe is never the only way**: Previous and Next sit over the neighbours (44px, the one at the row's end disabled). The centred card is announced through the band, which follows it: on a printing other than the matched one it reads "Not the printing that was read". The band is one element whose form, icon and sentence are replaced in place (`StatusBand`).
- **One details block** describes the centred card, each fact on its own line: the name; the set's full name, free to wrap; the set code and number as a tag with the year, and the position at the end.
- **One add button per finish**, sharing the pane's width, 52px high, wrapping onto two lines when it must; a special finish's button carries the star in `foil`. A foil marker read off the card relabels its button and chooses nothing.
- **Motion**: the capture's shrink and the pane's slide take 200ms and stop under reduced motion (README, Motion). The shrink starts from `--from` times the picture's size (4 unless the script sets it on `c-scan__capture`).

**Copy**

| Where | Words |
|---|---|
| Status line | "Line the card up with the guide, then capture." while aiming; "Reading the card…" while a reading runs |
| Top bar | "Adding to" over the destination: "Atraxa › Main · NM" (a place and a condition), "Blue binder" (a place alone), "No location · NM" (a condition alone), "No location". "Done". The back arrow is named "Back" |
| Count | "12 added" ("0 added", "1 added"); its accessible name is "12 added. Show this sitting's cards." |
| Main button | "Capture"; "Scan again" while a result shows. The torch is named "Torch" |
| Capture strip | "Read from the card", the name read, and the collector line read or "nothing read" |
| Band, success | "Matched by its collector line"; "Matched by its collector line, one digit corrected"; "Matched by its artwork" |
| Band, warning | "Printing not confirmed. Swipe to check." (alert); "Not sure of this card. Check it against your capture." (question mark); "Not the printing that was read" (alert, on a swipe away from the match) |
| Position | "1 of 14 printings"; "1 of 3 possible cards" |
| Add buttons | "Add nonfoil", "Add foil", "Add" and a finish's name in lower case ("Add etched"); "Add" alone for one finish or none; "Add foil · read from the card" when the foil marker was read. Accessible names stay today's: "Add Lightning Bolt MOM · 123 Foil" |
| After-add line | "Added Lightning Bolt MOM · 123, foil"; "Added Lightning Bolt MOM · 123" for a printing with no finish; "Undo". It names no condition or place: the top bar shows them |
| Previous and Next | "Previous printing", "Next printing"; "Previous card", "Next card" while the row holds possible cards |
| Sheets | "Adding to" (the destination); "This sitting: 12 cards" (the list) |

**Placed by #344 and #345** (today's copy stands until then): "Use a photo", the artwork-matching line, the photo-framing hint, the camera-unavailable states, "Nothing could be read", "No card matches", the catalog-not-ready notice, the send failures and the art-overrule sentence; the layout from 640px up, landscape and the bars' safe-area insets; how many printings load at once.

## As built, until #344 and #345

The card scanner (spec 007): a live camera feed with a card-shaped guide, …
````

- [ ] Commit: `docs(design-system): the phone-first scanner in Scanner.md, beside the scanner as built (#343)`

---

## Phase 8: The previews

**Implements:** FR-6 · **Satisfies:** AC-5.8, AC-5.9, AC-5.10
**Files:** `docs/design-system/previews/ScannerFlow.html`, `ScannerConfidence.html`, `Sheet.html`, `StatusBand.html`; `docs/specs/080-phone-first-scanner-components/screenshots/`
**Interfaces:** Consumes: `spec/support/scan_markup.rb`, the CSS of Phases 3 to 6. Produces: four static HTML files and their screenshots.

### T8.1 Write the four files from `ScanMarkup`

The previews are static files, written once from the same markup the examples prove. The script below is a scratchpad file, not committed.

- [ ] Write `<scratchpad>/scan_previews.rb` with the Write tool:

```ruby
# Writes the four previews of spec 080 from spec/support/scan_markup.rb. Run from the repository root.
require "./spec/support/scan_markup"
include ScanMarkup

OUT = "docs/design-system/previews".freeze
GUIDE = "left:5px;top:80px;width:380px;height:531px".freeze

def ph(text) = %(<span class="pv__ph">#{text}</span>)

def page(title, body)
  <<~HTML
    <!doctype html>
    <html lang="en" data-theme="light"><head>
    <link rel="stylesheet" href="preview-fonts.css"><link rel="stylesheet" href="../../../app/assets/stylesheets/collector/tokens.css"><link rel="stylesheet" href="../../../app/assets/stylesheets/collector/components.css"><link rel="stylesheet" href="../../../app/assets/stylesheets/collector/additions.css"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>#{title}</title>
    <style>html, body { margin:0; } body { background:var(--surface); }
    /* Preview only: frames and captions. A frame is one 390 × 844 screen: it gives the shell its height and is the containing
       block of a sheet drawn with the open attribute. Camera pictures and card images are placeholders with a caption. */
    .pv { display:flex; flex-wrap:wrap; align-items:flex-start; gap:var(--space-8); padding:var(--space-6); color:var(--ink); font-family:var(--font-sans); }
    .pv__cap { margin:0 0 var(--space-2); font:600 12px/16px var(--font-sans); color:var(--ink-muted); }
    .pv__note { flex-basis:100%; margin:0; font:400 14px/20px var(--font-sans); color:var(--ink-muted); }
    .pv__frame { position:relative; width:390px; height:844px; overflow:hidden; transform:translateZ(0); border:1px solid var(--line-strong); border-radius:var(--radius-md); }
    .pv__frame .c-scan { height:100%; }
    .pv__list { display:flex; flex-direction:column; gap:var(--space-2); width:390px; }
    .pv__ph { display:grid; place-items:center; height:100%; font:400 12px/16px var(--font-sans); color:var(--ink-muted); text-align:center; }
    </style></head>
    <body>
    <div class="pv">
    #{body}</div>
    <script>/* preview only: ?theme=dark, and each row rests on its centred card */
    if(new URLSearchParams(location.search).get("theme")==="dark")document.documentElement.dataset.theme="dark";
    document.querySelectorAll(".c-scanpane__row").forEach(function(row){var item=row.querySelector('[aria-current="true"]');if(item)row.scrollTo({left:item.offsetLeft-(row.clientWidth-item.offsetWidth)/2,behavior:"instant"});});</script>
    </body></html>
  HTML
end

def frame(caption, html) = %(<section><p class="pv__cap">#{caption}</p><div class="pv__frame">\n#{html}</div></section>\n)

MOM = sample_card
DBL = sample_card(set: "Double Masters 2022", code: "2X2 · 117", year: "2022")
CLB = sample_card(set: "Commander Legends: Battle for Baldur’s Gate", code: "CLB · 187", year: "2022")
BLAST = sample_card(name: "Lightning Blast", set: "Tempest", code: "TMP · 185", year: "1997", finishes: %w[nonfoil])
AXE = sample_card(name: "Lightning Axe", set: "Shadows over Innistrad", code: "SOI · 170", year: "2016")
CAPTURE = { caption: ph("your capture") }.freeze

def result(band, cards, current: 0, total: 14, read: {}, **options)
  shell(result: pane(band:, cards:, current:, total:, caption: ph("Card image"), **options), read: CAPTURE.merge(read))
end

matched = result(band(:success, "Matched by its collector line"), [ MOM, DBL, CLB ])
swiped = result(band(:warning, "Not the printing that was read"), [ MOM, DBL, CLB ], current: 1)

flow = frame("1 · Aim", shell(guide: GUIDE, caption: ph("live camera<br>card in the guide"))) +
  frame("2 · Reading", shell(main: :reading, status: "Reading the card…", guide: GUIDE, caption: ph("frozen on the captured frame"))) +
  frame("3 · Match", matched) + frame("4 · Swipe", swiped) +
  frame("5 · Added", shell(added: "Added Lightning Bolt MOM · 123, foil", count: 13, guide: GUIDE, caption: ph("live camera<br>next card")))
File.write("#{OUT}/ScannerFlow.html", page("Scanner: the capture flow", flow))

confidence = frame("Confident", matched) +
  frame("Printing a guess", result(band(:warning, "Printing not confirmed. Swipe to check."), [ CLB, MOM, DBL ], read: { line: "nothing read" })) +
  frame("Not sure of the card", result(band(:warning, "Not sure of this card. Check it against your capture.", mark: :question), [ CLB, BLAST, AXE ],
    total: 3, noun: "possible cards", step: "card", read: { name: "Lighming Bo1t", line: "nothing read" }))
File.write("#{OUT}/ScannerConfidence.html", page("Scanner: the pane's confidence", confidence))

NOTICE = [
  'Collector is unofficial Fan Content permitted under the <a rel="noopener" href="https://company.wizards.com/en/legal/fancontentpolicy">Fan Content Policy</a>. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC.',
  'Card data and images provided by <a rel="noopener" href="https://scryfall.com">Scryfall</a>.'
].freeze

destination = <<~HTML
  <form class="c-form c-scanner__place"><fieldset class="c-choices"><legend class="c-field__label">This sitting's cards</legend>
    <div class="c-field"><label class="c-field__label" for="pv_condition">Condition</label><select id="pv_condition"><option>Not specified</option><option selected>Near mint (NM)</option><option>Lightly played (LP)</option></select></div>
    <div class="c-field"><label class="c-field__label" for="pv_location">Location</label><select id="pv_location"><option>No location</option><optgroup label="Places"><option>Blue binder</option></optgroup><optgroup label="Decks"><option selected>Atraxa › Main</option><option>Atraxa › Sideboard</option></optgroup></select></div>
  </fieldset><div class="c-form__actions"><button type="button" class="c-btn c-btn--secondary">Set</button></div></form>
HTML

def entry(name, meta)
  %(<li><span>#{name}</span> <span class="c-list__meta">#{meta}</span> <span class="c-list__end c-scanner__entry-actions"><a class="c-btn c-btn--ghost c-btn--sm" href="#">Details</a> <button type="button" class="c-btn c-btn--secondary c-btn--sm">Undo</button></span></li>)
end

list = %(<div class="c-scanner__sitting"><ul class="c-list">) +
  entry("Lightning Bolt", "MOM · 123 · Foil · NM · in Atraxa › Main · Added 1 minute ago") +
  entry("Counterspell", "MH2 · 267 · Nonfoil · NM · in Atraxa › Main · Added 2 minutes ago") +
  entry("Arcane Signet", "CLB · 297 · Nonfoil · NM · in Atraxa › Main · Added 4 minutes ago") + "</ul></div>"

live = shell(guide: GUIDE, caption: ph("live camera"))
sheets = %(<p class="pv__note">A sheet is opened as a modal by the page's script. These are drawn with the <code>open</code> attribute, so they have no backdrop; on a page the scrim dims everything behind the sheet.</p>\n) +
  frame("The destination", live + sheet(title: "Adding to", body: destination, foot: NOTICE, id: "pv_destination", open: true)) +
  frame("The sitting's list", live + sheet(title: "This sitting: 12 cards", body: list, foot: NOTICE, id: "pv_list", open: true))
File.write("#{OUT}/Sheet.html", page("Sheet", sheets))

sentences = [
  band(:success, "Matched by its collector line"), band(:success, "Matched by its collector line, one digit corrected"),
  band(:success, "Matched by its artwork"), band(:warning, "Printing not confirmed. Swipe to check."),
  band(:warning, "Not sure of this card. Check it against your capture.", mark: :question), band(:warning, "Not the printing that was read")
].join("\n")
bands = %(<section><p class="pv__cap">Every form and sentence, 390px wide</p><div class="pv__list">\n#{sentences}\n</div></section>\n) +
  %(<section><p class="pv__cap">360px wide: a long sentence wraps</p><div class="pv__list" style="width:360px">\n#{sentences}\n</div></section>\n) +
  frame("In the pane, on a swipe (2 of 14)", swiped)
File.write("#{OUT}/StatusBand.html", page("StatusBand", bands))
```

- [ ] Run it in its own call: `ruby <scratchpad>/scan_previews.rb`. Expect four new files under `docs/design-system/previews/`.
- [ ] Read each file: every `<link>` is one of the four stylesheets (AC-5.8); there is no `<img>`, no set symbol, no mana symbol (AC-5.10); the copy matches the mock-ups and spec decision 11.

### T8.2 Open them, look, and keep the shots

- [ ] Serve the worktree and shoot, as the screenshot workflow for static previews sets out (`.claude/memory/pr-screenshots-workflow.md`, "Static previews and mock-ups with the real CSS"): `python3 -m http.server 3871 --bind 127.0.0.1 --directory "$PWD"` as a background task; an uncommitted Selenium script in the scratchpad loads `http://127.0.0.1:3871/docs/design-system/previews/<Name>.html` and `…?theme=dark` for each of the four files in a window wide enough for the page (2200 × 1000 for the five frames), pauses 0.7s, and saves a full-page screenshot. For each load it also reads:
  - `[...document.styleSheets].map((sheet) => sheet.cssRules.length)`: four numbers, none zero (the stylesheets loaded);
  - `[...document.querySelectorAll(".pv__frame")].map((frame) => frame.scrollWidth <= frame.clientWidth)`: all true (no frame overflows sideways);
  - the heights of each frame's `.c-scan` (844) and, where there is a result, of `.c-scan__strip` (144), so the short-screen rule did not answer to the window;
  - a second run of the page's inline script inside `try { … } catch (error) { return String(error) }`: no error. Headless Selenium could not read the browser console in this setup (spec 060's record), so `verification.md` says what was checked in its place and does not claim "no console error" beyond that.
- [ ] Look at every shot, both themes. Check against the mock-ups: the five steps, the three states, both neighbours showing in the swipe step, the notice in each sheet's foot, text on a band legible in dark. A defect found here goes back to the phase that owns the rule, with its example first.
- [ ] Compress the shots (`magick in.png -resize 1600x -quality 82 out.jpg`) into `docs/specs/080-phone-first-scanner-components/screenshots/` (eight files: four previews, light and dark). Stop the server with TaskStop.
- [ ] Commit: `docs(design-system): previews of the scan flow, the pane's confidence, the sheets and the status band (#343)`

---

## Phase 9: Verification, checks, review

**Implements:** all FRs · **Satisfies:** AC-6.1, AC-6.3, and the record of every criterion

- [ ] **T9.1** Write `docs/specs/080-phone-first-scanner-components/verification.md` in spec 060's shape: the header (spec version, plan, issue, the commit recorded at); **Browser criteria** (the command, the example counts, a table of `describe` against criteria, the red runs as the implementers reported them, the measurements); **Token criteria**; **Document criteria** (a quotation from the README, `StatusBand.md`, `Sheet.md` and `Scanner.md` for each of AC-1.6, 2.6, 5.1 to 5.7 and 5.11, and for `tokens.json` in AC-1.1); **Previews** (what T8.2 read, the shots); **Unchanged scanner** (the output of `git diff --stat origin/main -- app/views app/javascript app/controllers app/models app/helpers`, which must be empty, and `git diff origin/main -- app/assets/stylesheets/collector/additions.css | grep '^-' | grep -v '^---'`, which must print nothing); **Deviations from the plan, and spec patches**; **Observations**.
- [ ] **T9.2** Run `bin/ci checks`, then the full `bin/ci` (one at a time; nothing else may use the worktree's test database). Record both in `verification.md`. Commit: `docs(design-system): verification of spec 080 (#343)`. Push as a background task in its own call.
- [ ] **T9.3** Implementation review: `sdd-superpowers:sdd-review` Mode B by a read-only Opus subagent; record it in `verification.md` under `## Implementation review` with the verdict on its first line. Fix what it finds, test first.
- [ ] **T9.4** Final visual review: the eight screenshots go to the maintainer in chat and into the pull request body (links pinned to a commit SHA: `https://github.com/plainprogrammer/Collector/blob/<sha>/docs/specs/080-phone-first-scanner-components/screenshots/<file>?raw=true`). The body says the previews use placeholder images and factory-free static markup.
- [ ] **T9.5** `sdd-superpowers:session-wrap`, then the `distill-feature` skill (the design system's documents are this spec's area; the index row changes as it says). When CI is green, open the pull request for the maintainer (`gh pr view <N> --web`). It is marked ready and merged only on their word.

---

## Spec coverage

| Requirement | Phase | Criteria and how they are proved |
|---|---|---|
| FR-1 Tokens | 1 | AC-1.1, 1.2: `spec/design_system_tokens_spec.rb`; `tokens.json` by reading |
| FR-7 Reduced motion | 2 (the row's `auto` in 6) | AC-6.4: system example; `!important` only there: `spec/design_system_files_spec.rb`; AC-5.3 by reading |
| FR-2 StatusBand | 3, 7 | AC-1.3 to 1.5: system examples; AC-1.6 by reading |
| FR-3 Sheet | 4, 7 | AC-2.1 to 2.5, 2.7: system examples; AC-2.6 by reading |
| FR-4 Shell | 5, 7 | AC-3.1 to 3.9: system examples in frames |
| FR-5 Pane | 6, 7 | AC-4.1 to 4.11: system examples in frames |
| FR-6 Documents and previews | 7, 8 | AC-5.1 to 5.7, 5.11 by reading; AC-5.8 to 5.10 by T8.1 and T8.2 |
| Story 6 | 6, 9 | AC-6.1: the diff and the suite; AC-6.2: the blocks' guard and the diff; AC-6.3: `bin/ci checks` |

Every error scenario of the spec has an example or a rule: a long destination (AC-3.3), no torch (AC-3.6), "nothing read" and a long name read (AC-4.1's one-line rule; the previews), one finish (AC-4.6), one card in the row (the long-names example renders one; both buttons disabled is in `ScanMarkup.pane`), a wrapped band (AC-1.5, AC-4.7), short viewports (AC-4.7), a tall sheet (AC-2.3), reduced motion (AC-2.4, 4.4, 4.8, 6.4), no content notice (`ScanMarkup.sheet` with no foot, AC-2.1's examples), a `::backdrop` without tokens and a browser without scroll snap (no dimming, and Previous and Next: stated in the CSS comments and the documents; not reproducible in headless Firefox, recorded as such).

## Verification (end to end)

1. `bin/rspec spec/design_system_tokens_spec.rb spec/design_system_files_spec.rb spec/system/design_system_scanner_components_spec.rb spec/system/design_system_deck_rules_spec.rb spec/system/design_system_deck_components_spec.rb` — all pass.
2. `bin/rspec spec/system/scanner_spec.rb spec/system/scanner_sitting_spec.rb spec/system/scanner_adding_spec.rb spec/system/scanner_art_spec.rb spec/system/scanner_detection_spec.rb` — all pass, unchanged.
3. `bin/ci` — green.
4. Open `docs/design-system/previews/ScannerFlow.html`, `ScannerConfidence.html`, `Sheet.html` and `StatusBand.html` through a static server, with and without `?theme=dark`, and compare with the mock-ups in `docs/superpowers/specs/2026-11-12-scanner-phone-first-mockups/`.
5. `git diff --stat origin/main -- app/views app/javascript app/controllers app/models app/helpers` prints nothing.

## Risks and notes (what only a run can confirm)

- **`::backdrop` and tokens.** The example reads the rule (`.c-sheet::backdrop`'s `background-color` is `var(--scrim)`) and the token's value, not the pseudo-element's computed style. If headless Firefox does report `getComputedStyle(dialog, "::backdrop").backgroundColor` as `rgba(0, 0, 0, 0.4)`, the implementer adds that expectation and says so in `verification.md`.
- **The row's end padding.** The last image can be centred only if the scroll container counts its inline-end padding as scrollable. Current Firefox does; if `end_centres` returns less than 195 for the last image, add `.c-scanpane__row::after { content:""; flex:none; width:1px; margin-left:-1px; }` and record the ruling.
- **Container-query units in a grid item.** `c-scanpane__rowwrap` is a size container inside a `minmax()` track. If the browser sizes the track to its minimum because of the containment, set the track's sizes on the item instead (`min-height` and `max-height` on `c-scanpane__rowwrap`, the row `auto`), keeping decision 7's numbers.
- **Float noise.** Sizes are compared after rounding where they are derived (63:88 widths, the padding); a plain `eq` on a box that turns out fractional gets `be_within(0.5)` and a line in the commit body.
- **Selector text.** `apply_reduced_motion_rules` matches fragments because browsers serialise `*::before` differently.
- **`find(...).send_keys(:tab)` inside a modal dialog** relies on the tab order Close, then the notice's link. If the browser focuses the dialog itself first, press Tab until the link has focus (`tab_to_text("content policy")`, `spec/support/keyboard_helpers.rb`).
- **Sample copy is the mock-ups'**, not catalog data ("MOM · 123" is not a real printing of that card). The previews say the images are placeholders; nothing asserts catalog facts.
- **#344 inherits** the body class, the notice in the sheets' foot with its supersession of spec 018, the backdrop tap, the icon partials and the touch-floor audit page (T0.3 puts them on the issue).
