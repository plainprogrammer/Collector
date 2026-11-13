# Implementation Plan: Scanner: Capture Always in View (spec 082, issue #344)

**Spec:** `docs/specs/082-scanner-capture-always-in-view/spec.md` (Approved, 1.0.0) · **Issue:** #344 · **Branch:** `082-scanner-capture-always-in-view` · **Created:** 2026-11-13
**Status:** Approved at Gate B on 2026-11-13 (the coordinator, under the maintainer's delegation), with spec patch 1.0.2. Plan review (Opus, read-only) 2026-11-13: round 1 REVISE (2 blocking, 8 major, 16 minor), all applied; round 2 APPROVE WITH CHANGES (2 major, 2 partly resolved, minors), all applied; spec patch 1.0.1 (the notice partial shared with spec 084, maintainer's ruling) is already in `spec.md`.

## Summary for the maintainer

Ten phases. Phases 1 to 8 need nothing from you; Phase 9, the paired re-measure on your cards, is last and nothing waits on it. Implementers (Sonnet 5.5) take 2 to 4 consecutive tasks each, test first, one commit per task; I check every batch's diff.

| Phase | What lands | Criteria | Your calls in it |
|---|---|---|---|
| 0 | Spec patch 1.0.2, plan, index; #345's line | — | 1 (Scan again, the #345 line) |
| 1 | The live guide's geometry; the synthetic card drawn where the stage's guide falls | AC-3.1 to 3.5 | 2 (the guide in the aiming area) |
| 2 | The notice's lines in one partial, shared with spec 084 | decision 16 | |
| 3 | The focused layout; the shell: top bar, stage, bottom bar, the pane, the sheets (markup, CSS, the shell's state) | FR-1; AC-1.1 to 1.9, 2.1, 2.2, 2.4, 6.1 | 3 (Use a photo in the sheet), 5 (the 480px column) |
| 4 | Capture, the frozen frame, a result in the pane, "Scan again" | AC-4.1 to 4.10 | 1 (Scan again), 4 (the pane, the canvas) |
| 5 | The sitting's answers: Set, add, Undo, the after-add line, focus, the flash | AC-2.3, 2.5, 5.1 to 5.6, 6.2 to 6.5 | 4 (a live region per sheet) |
| 6 | The other states, the old CSS, the touch floor, the footer and request specs | AC-1.9; Error Scenarios; decision 16 | |
| 7 | Measurement mode on the shell, the framing, the paired findings task | AC-7.1, 7.2, 7.4's tooling | |
| 8 | Documents, screenshots and GIFs, verification, `bin/ci`, Mode B, push, draft PR | Documentation; Verification | |
| 9 | **The re-measure (you):** corpus, manifest checks, the paired run, findings, bar A | AC-7.3 to 7.5 | |

**One thing planning found that changes the spec (patch 1.0.2, for approval with this plan):** decision 5 sends measurement mode's stored notice and a store failure to the status line, but a capture is stored while its result shows, when the status line is hidden (decision 10's table) and its text is emptied. So the stored notice shows as the top-bar button's new row and count (the button is redrawn with every stored capture), and a store failure goes to the pane's `#status`, which is in view while the result shows. AC-7.1's last clause changes to match.

**Not run:** by the project's rule nobody runs a plan's code before execution. The blocks are strong drafts; each implementer sees red, then green, and records a deviation as a `Ruling:` line in the commit body. "Risks" lists what only a run can confirm.

## Context

Spec 080 drew the shell (`c-scan`), the sheet (`c-sheet`), the lines over the camera and `c-shell--focused` in `additions.css` and the design system's documents; no view uses them. This spec builds the scanner page on them, keeps today's result partial inside the pane, moves the sitting's control and list into two sheets, and makes the live guide one geometry shared by the page and the crop. Every server route stays; the Turbo Stream answers gain targets.

## Global Constraints

- **Repo rules:** `CLAUDE.md`, `.claude/rules/*.md`. Before touching a view, CSS or copy, use the `collector-design-system` skill and read `docs/design-system/README.md`, `components/Scanner.md` and `components/Sheet.md`. Tokens and `c-*` classes only; no colour literal, no font family outside the tokens; every new rule that sets a size sets `box-sizing:border-box` (spec 080 decision 15).
- **Where CSS goes.** One new block, headed `/* ---------- Scanner page (spec 082): … ---------- */`, inserted directly above the heading `/* ---------- Reduced motion, app-wide (spec 080 decision 14) ---------- */`, which stays last. No new comment contains "spec 019", "spec 021" or "spec 023" (`spec/design_system_files_spec.rb`). The frozen spec 080 rules are not edited; where this block overrides one it does so by a selector of equal specificity later in the file, or a higher one.
- **Core files name no collectible.** The sitting's partials and `ScannersHelper` (`spec/scanner_sitting_core_spec.rb`), the layout and the notice partials (`spec/footer_core_spec.rb`): no `mtg`, `scryfall`, `magic`, `wizards`, "fan content" anywhere, comments included.
- **No raw strings into a stream.** `turbo_stream.update(target, "…")` marks its string `html_safe`; every text that can hold a card or place name goes through `ERB::Util.html_escape` or a partial.
- **Specs:** `type: :system` explicit; `RSpec/ExampleLength` is 15 lines, so measures live in helper methods; multi-expectation examples carry `:aggregate_failures`; no `sleep`; no constants in a `describe`. A phone viewport is a frame opened from the collection page (`open_in_narrow_frame`; the scanner's own policy frames nothing). The scanner doesn't scroll, so its frame has no scrollbar and the frame's width is the viewport's. The window (1400 × 1400) is taller than every frame.
- **Comments:** YARD summaries on every public method added or changed in `app/helpers`, `app/models`, `app/controllers/concerns`, `lib`, `spec/support` (the comment ratchet); the why, with spec 082's decision or criterion as its source; no `{…}` in a comment.
- **Commits:** one per task, Conventional Commits ending `(#344)`, with the trailer of the model that wrote it (an implementer's: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`). `git add` and `git commit` in separate calls; one git operation per call. Never read `.kamal/secrets`, `config/master.key`, `.env*`, `storage/` or a `*.sqlite3`; every `git grep` ends with `':!.kamal/secrets'`. No `bin/rails console`, `sqlite3`, `bundle add`, `importmap pin`.
- **Shared test database:** one test run at a time in this worktree; never `bin/jobs`.
- **Selector map** for every existing scanner example the new markup touches (Phases 3 to 7):

  | Today | After |
  |---|---|
  | `.c-scanner` (the controllers' element) | `.c-scan` |
  | `.c-scanner__stage:not([hidden])` | `.c-scan__feed:not([hidden])` |
  | `.c-scanner__stage video`, `.c-scanner__video` | `.c-scan__feed video`, `.c-scan__video` |
  | `.c-scanner__shutter` | `.c-scan__main` |
  | `button[aria-pressed=true]` with text "Torch" | `button[aria-label=Torch][aria-pressed=true]` |
  | `#status` after an add | `#scanner_added_text`, with the new sentence ("Added Lightning Bolt MOM · 123, foil") |
  | `#status` after "Set" | `#scanner_destination_status` (open the destination sheet first) |
  | `#status` after an Undo | `#scanner_list_status` (list sheet open) or `#scanner_added_text` |
  | `#status` after a refused or failed add, Other printings | `#status` (now in the pane; unchanged) |
  | `#scanner_sitting h2` | `#scanner-sitting-heading` (open the list sheet first) |
  | `.c-scanner__status` | `#status` (the pane's) for a result's sentence; `#scanner_status_text` for the status line |
  | `.c-scanner__art` | the same, inside the destination sheet: open it, or match with `visible: :all` |

## Goal

The scanner is the one-screen shell: the destination and Done in the top bar, the live camera with a guide the crop really uses, the main button, count and torch in the bottom bar, a result over the stage, the sitting's control and list in sheets that keep the camera, the after-add line with Undo; measurement mode on the same shell with a framing switch; and, last, a paired re-measure that decides the guide's size.

## Pre-implementation gates

- **Simplicity: pass.** The page's parts are the views, three small Stimulus controllers (one new for the shell's state, one new for the sheets, one changed for focus), the existing camera and card-reader controllers, and stream targets on the existing routes. Measurement adds one development-only form and a findings report.
- **Anti-abstraction: pass.** Native `<dialog>` and `showModal()`, a `MutationObserver` for the state, a `<canvas>` with `object-fit: cover` for the frozen frame. No client-side store: the state is the markup's (decision 19).
- **Integration-first: pass.** The contract is the markup and the stream targets, written in Phase 3 (the ids table below) before any answer writes to them in Phase 5.

**The stream targets (the contract):**

| Id | Element | Written by |
|---|---|---|
| `scanner_sitting_bar` | the destination button and Done (`display:contents`) | add, Undo, Set (replace) |
| `scanner_count` | the count button | add, Undo, Set (replace) |
| `scanner_destination_status` | the destination sheet's `role="status"` region | Set (update) |
| `scanner_picker` | the form's wrapper in the destination sheet | Set (replace) |
| `scanner-sitting-heading` | the list sheet's title (`h2`, `tabindex="-1"`) | add, Undo, Set (update, escaped text) |
| `scanner_list_status` | the list sheet's `role="status"` region | Undo (update) |
| `scanner_sitting` | the list sheet's entries section | add, Undo, Set (replace) |
| `scanner_status_text` | the status line's `role="status"` paragraph | the card reader; add (emptied) |
| `scanner_added_text` | the after-add line's `role="status"` paragraph | add, Undo (update, escaped text) |
| `scanner_added_action` | the after-add line's action (Undo, a link) | add, Undo (replace) |
| `status` | the pane's `role="status"` region | readings' sentence (client), refused adds, replays, Other printings, store failures |
| `scanner_result` | the reading's result, in the pane | readings, add (emptied) |
| `measurement_panel`, `measurement_run_button` | the run sheet's panel, the top bar's run button | measurement captures and skips (replace) |

## Spec patch 1.0.2 (found while planning; applied in T0.1 on approval)

| Where | Change |
|---|---|
| Header, Changelog | Version 1.0.2; a row: "PATCH, found while planning, approved with the plan: a capture is stored while its result shows, when the status line is hidden, so measurement mode's stored notice shows as the top-bar button's new row and count and a store failure in the pane's `#status` (decision 5, AC-7.1). No other criterion changes" |
| Decision 5 | "The stored notice ("Stored IMG_7001 as the measured capture…") and a store failure ("The capture wasn't stored…") go to the status line as well as the sheet, so the row and a failure are in view while capturing" becomes "The stored notice ("Stored IMG_7001 as the measured capture…") shows in the sheet, and the top-bar button, redrawn with every stored capture, shows the next row and the new count; a store failure ("The capture wasn't stored…") shows in the sheet and in the pane's `#status`, which is in view while the capture's result shows" |
| AC-7.1 | "and the stored notice or a store failure also shows on the status line" becomes "the top-bar button shows the next row and the new count after a stored capture, and a store failure also shows in the pane's `#status`" |

## Files

| File | Change | Responsibility |
|---|---|---|
| `app/javascript/scanner/geometry.js` | edit | `LIVE_GUIDE`, `liveGuideRect`, `shippedGuideWidth`; `guideInFrame` takes a rect |
| `app/javascript/controllers/camera_controller.js` | edit | the feed wrapper, the live guide, the framing value |
| `app/javascript/controllers/card_reader_controller.js` | edit | the main button, the frozen frame, the pane's sentences, "Scan again" |
| `app/javascript/controllers/scan_shell_controller.js` | create | `c-scan--result` and the lines' `hidden` from the markup |
| `app/javascript/controllers/sheets_controller.js` | create | open, backdrop close, empty a sheet's region on close |
| `app/javascript/controllers/sitting_focus_controller.js` | edit | "set", "heading" (or the main button), "main" |
| `app/javascript/controllers/measurement_controller.js` | edit | the read event's sizes; a store failure in the pane |
| `app/views/layouts/application.html.erb`, `_footer.html.erb`, `_notice_lines.html.erb` (new), `_notice_foot.html.erb` (new) | edit, create | the focused body; the lines in one place |
| `app/views/scanners/show.html.erb`, `_scanner.html.erb` | edit | the shell |
| `app/views/scanners/_sitting_bar.html.erb`, `_count.html.erb`, `_added_line.html.erb`, `_added_action.html.erb`, `_destination_sheet.html.erb`, `_list_sheet.html.erb` | create | the shell's sitting parts |
| `app/views/scanners/_sitting.html.erb`, `_picker.html.erb` | edit | the list section; the form's wrapper |
| `app/views/scanners/_summary.html.erb` | delete | the summary is the after-add line (AC-5.6) |
| `app/views/icons/_torch.html.erb`, `_chevron_down.html.erb` | create | the bars' icons |
| `app/views/scanner/measurements/show.html.erb`, `_panel.html.erb`, `_run_button.html.erb` (new), `_run_sheet.html.erb` (new) | edit, create | measurement mode on the shell |
| `app/helpers/scanners_helper.rb` | edit | `scanner_destination`, `scanner_added`, `sitting_title`; `sitting_focus_data` takes `:main` |
| `app/controllers/concerns/scanner_sitting.rb` | edit | `sitting_redraw`, `picker_redraw`, `say_in`, `added_line` |
| `app/controllers/scanners_controller.rb`, `scanner/sittings_controller.rb`, `scanner/sittings/entries_controller.rb`, `scanner/sittings/entries/undos_controller.rb` | edit | the new answers; the flash line |
| `app/controllers/scanner/readings_controller.rb`, `concerns/measurement_mode.rb`, `scanner/measurements_controller.rb`, `scanner/measurements/captures_controller.rb`, `scanner/measurements/framings_controller.rb` (new), `config/routes.rb` | edit, create | the framing in the session |
| `app/models/scanner/measurement_run.rb` | edit | `current(framing:)`, `FRAMINGS`, the sizes in `EXTRA_FIELDS` |
| `lib/collector/scanner_findings/paired_report.rb` (new), `lib/tasks/scanner.rake` | create, edit | the paired findings |
| `app/assets/stylesheets/collector/additions.css` | edit | the spec 082 block; the dead `c-scanner` rules removed |
| `spec/support/scanner_helpers.rb` | edit | the live synthetic card; `open_destination`, `open_sitting_list`, `open_scanner_frame`, `one_screen` |
| `spec/system/scanner_geometry_spec.rb`, `scanner_page_spec.rb`, `scanner_result_spec.rb` | create | Phases 1, 3, 4 |
| `spec/system/scanner_spec.rb`, `scanner_sitting_spec.rb`, `scanner_adding_spec.rb`, `scanner_art_spec.rb`, `scanner_detection_spec.rb`, `scanner_timing_spec.rb`, `scanner_measurement_spec.rb`, `footer_spec.rb`, `small_controls_touch_floor_spec.rb` | edit | the selector map; the new answers |
| `spec/requests/scanners_spec.rb`, `footer_spec.rb`, `scanner/sitting_entries_spec.rb`, `scanner/sittings_spec.rb`, `scanner/measurements_spec.rb` | edit | the new answers and page |
| `spec/scanner_sitting_core_spec.rb`, `spec/footer_core_spec.rb`, `spec/helpers/scanners_helper_spec.rb` | edit | the new partials; the helpers |
| `spec/models/scanner/measurement_run_spec.rb`, `spec/lib/collector/scanner_findings/paired_report_spec.rb` (new) | edit, create | Phase 7 |
| `docs/architecture/scanner.md`, `catalog-core.md`; `docs/design-system/README.md`, `components/Scanner.md`, `Sheet.md`, `Footer.md`; `docs/specs/README.md` | edit | Phase 8 |
| `docs/specs/082-scanner-capture-always-in-view/verification.md`, `research.md`, `screenshots/` | create | Phases 8, 9 |

---

## Phase 0: Preflight (no code)

**Implements:** execution preamble; decision 25 · **Satisfies:** —

- [ ] **T0.1** On Gate B approval: apply spec patch 1.0.2 to `spec.md` (the table above), set spec 082's Plan column in `docs/specs/README.md` to "present", stage `docs/specs/082-scanner-capture-always-in-view docs/specs/README.md` in one call and commit in another: `docs(specs): spec 082 patch 1.0.2 and plan (#344)`.
- [ ] **T0.2** Issue #345 (decision 25): read its body (`gh issue view 345 --json body --jq .body`), insert before the "**Mock-ups**" line the bullet "- **From spec 082** (decision 25): \"Scan again\", the after-add line with Undo and the frozen frame (a canvas over the stage) are built by #344; this issue keeps them. #344 holds today's result in an interim scrolling body, `c-scanpane__results`, which this issue removes with the layout it replaces.", write the result with the Write tool to the scratchpad and run `gh issue edit 345 --body-file <path>`.
- [ ] **T0.3** Baseline: `bin/rspec spec/system/scanner_spec.rb spec/system/scanner_sitting_spec.rb spec/system/scanner_adding_spec.rb spec/scanner_sitting_core_spec.rb spec/footer_core_spec.rb` (39 examples, 0 failures on 2026-11-13).

---

## Phase 1: The live guide

**Implements:** FR-3; decisions 2, 3 · **Satisfies:** AC-3.1 (the boxes), AC-3.3, AC-3.5
**Files:** `app/javascript/scanner/geometry.js`, `spec/system/scanner_geometry_spec.rb`, `spec/support/scanner_helpers.rb`
**Interfaces:** Produces `LIVE_GUIDE`, `shippedGuideWidth(stageWidth)`, `liveGuideRect(stageWidth, stageHeight, framing = "full")`, `guideInFrame(frameWidth, frameHeight, viewWidth, viewHeight, rect = guideRect(viewWidth, viewHeight))`. `guideRect`, `GUIDE`, `STAGE_ASPECT`, `STRIPS`, `DETECTED_STRIPS` and every reading setting keep their values: they are the shipped framing, used by the photo path.

### T1.1 The live guide's rule (test first)

Create `spec/system/scanner_geometry_spec.rb`:

```ruby
require "rails_helper"

# Spec 082 decisions 2 and 3: the live guide sits in the stage's aiming area (the stage less its top 64px), as large as 80% of
# that height allows, never narrower than the shipped framing's guide for the stage's width, at most 97.5% of the width and 95%
# of the area's height. The shipped framing (the photo path's) is unchanged. The module is loaded into the page as the scanner
# helpers load it.
RSpec.describe "The scanner's guide geometry", type: :system do
  before do
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  def geometry(script)
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      #{ScannerHelpers::MODULES_JS}
      window.__modules.then(({ geometry }) => done((#{script})(geometry)))
    JS
  end

  def rounded(rect) = rect.transform_values { it.round(1) }

  it "gives the live guide decision 2's boxes at the three stages (AC-3.1)", :aggregate_failures do
    boxes = geometry("(g) => [ [390, 692], [360, 488], [360, 408] ].map(([w, h]) => g.liveGuideRect(w, h))")
    expect(rounded(boxes[0])).to eq("x" => 15.2, "y" => 126.8, "width" => 359.7, "height" => 502.4)
    expect(rounded(boxes[1])).to eq("x" => 42.5, "y" => 84.0, "width" => 274.9, "height" => 384.0)
    expect(rounded(boxes[2])).to eq("x" => 63.0, "y" => 72.6, "width" => 234.0, "height" => 326.8)
  end

  it "draws the shipped framing's card size in the tall stage, for measurement mode (AC-7.2)" do
    box = geometry("(g) => g.liveGuideRect(390, 692, 'shipped')")
    expect(rounded(box)).to eq("x" => 46.1, "y" => 170.0, "width" => 297.8, "height" => 416.0)
  end

  it "keeps the shipped framing for a picked photo (AC-3.3)", :aggregate_failures do
    box = geometry("(g) => ({ guide: g.guideRect(900, 1200), photo: g.guideInFrame(1200, 1600, g.STAGE_ASPECT, 1), aspect: g.STAGE_ASPECT, shares: g.GUIDE })")
    expect(rounded(box["guide"])).to eq("x" => 106.4, "y" => 120.0, "width" => 687.3, "height" => 960.0)
    expect(rounded(box["photo"])).to eq("x" => 141.8, "y" => 160.0, "width" => 916.4, "height" => 1280.0)
    expect(box["aspect"]).to eq(0.75)
    expect(box["shares"]).to eq("height" => 0.8, "maxWidth" => 0.9)
  end

  it "maps a live guide into a 3:4 frame covering a taller stage, inside the frame (AC-3.2)", :aggregate_failures do
    box = geometry("(g) => g.guideInFrame(900, 1200, 390, 692, g.liveGuideRect(390, 692))")
    expect(box["x"]).to be >= 0
    expect(box["x"] + box["width"]).to be <= 900
    expect(box["y"]).to be >= 0
    expect(box["y"] + box["height"]).to be <= 1200
  end
end
```

Run it: red (`liveGuideRect` is not a function). Then in `geometry.js`, after `GUIDE`, add (and change the file's header comment's second sentence to "The shipped framing (a 3:4 stage, the guide 80% of its height) is the photo path's; the live guide is the full framing of spec 082, drawn and cropped from one computation."):

```js
// The live guide (spec 082 decision 2): it sits in the stage's aiming area, the stage less its top `top` px, where the status
// line and the after-add line sit (16px above a one-line line of 38px, and a 10px gap), so a one-line line never covers it. It
// is as large as `height` of the area allows, never narrower than the shipped framing's guide for the stage's width (so a card
// never gets fewer pixels than it did on a portrait stage that has room), at most `maxWidth` of the stage's width and
// `maxHeight` of the area's height. The re-measure (spec 082 Story 7) decides whether it ships at this size or at the shipped
// card size ("shipped").
export const LIVE_GUIDE = { top: 64, height: 0.8, maxWidth: 0.975, maxHeight: 0.95 }

// The width the shipped framing's guide has in a 3:4 stage `stageWidth` wide (0.7636 of it).
export function shippedGuideWidth(stageWidth) {
  return guideRect(stageWidth, stageWidth / STAGE_ASPECT).width
}

// The live guide's box in a stage of this size, in stage pixels. framing "shipped" draws the shipped card size in the same
// place (measurement mode's other half, spec 082 decision 5).
export function liveGuideRect(stageWidth, stageHeight, framing = "full") {
  const area = Math.max(stageHeight - LIVE_GUIDE.top, 0)
  const shipped = shippedGuideWidth(stageWidth)
  let width = framing === "shipped" ? shipped : Math.max(area * LIVE_GUIDE.height * CARD_ASPECT, shipped)
  width = Math.min(width, stageWidth * LIVE_GUIDE.maxWidth, area * LIVE_GUIDE.maxHeight * CARD_ASPECT)
  const height = width / CARD_ASPECT
  return { x: (stageWidth - width) / 2, y: LIVE_GUIDE.top + (area - height) / 2, width, height }
}
```

and give `guideInFrame` a fifth parameter, `rect = guideRect(viewWidth, viewHeight)`, used in place of its `const guide = guideRect(viewWidth, viewHeight)` (the comment above it: "The guide (by default the shipped one) in image pixels when a frameWidth × frameHeight image fills a view with object-fit: cover."). Run: green. Then `ruby script/scanner/detector_parity.rb` (AC-3.5): passes. Commit `feat(scanner): the live guide's geometry (#344)`.

Arithmetic, for the reviewer: at 390 × 692 the area is 628, 0.8 × 628 × 63/88 = 359.67 > 297.80 (shipped), under 380.25 and 427.13; height 502.40; y = 64 + (628 − 502.4)/2 = 126.8; x = (390 − 359.67)/2 = 15.17. At 360 × 488: area 424, 242.83 < 274.89, so 274.89; height 383.98 ≤ 402.8; y = 64 + 20.01 = 84.0; x = (360 − 274.909)/2 = 42.545, rounded 42.5. At 360 × 408: area 344, 274.89 wide would be 383.98 high > 326.8, so 326.8 high, 233.96 wide; y = 64 + 8.6 = 72.6; x = 63.02. Shipped at 390 × 692: 297.80 × 416.0, y = 64 + (628 − 416)/2 = 170.0, x = 46.1. `guideRect(900, 1200)`: 960 high, 687.27 wide; the photo's `guideInFrame(1200, 1600, 0.75, 1)`: scale 1/1200, offset 0, rect of a 0.75 × 1 view (0.8 high, 0.5727 wide, x 0.0886, y 0.1) × 1600 → 141.8, 160, 916.4, 1280.

### T1.2 The synthetic card where the live guide falls

`ScannerHelpers::CARD_JS` draws the card at `guideRect(900, 1200)`: the shipped framing's box in a 3:4 frame, which a taller stage would crop. In `CARD_JS` replace `window.__syntheticCard = async (name, lines) => { const { guideRect } = await window.__geometry … const card = guideRect(canvas.width, canvas.height)` with:

```js
    // A live card is drawn where the page's guide falls in the frame (spec 082 AC-3.1): the stage's live guide mapped into the
    // 3:4 frame the way the camera controller maps it; a photo's card where the shipped guide is (the photo path's framing).
    window.__syntheticCard = async (name, lines, live = false) => {
      const { guideRect, guideInFrame, liveGuideRect } = await window.__geometry
      const canvas = Object.assign(document.createElement("canvas"), { width: 900, height: 1200 })
      const context = canvas.getContext("2d")
      const cardBox = () => {
        const stage = document.querySelector(".c-scan__stage")?.getBoundingClientRect()
        if (!live || !stage) return guideRect(canvas.width, canvas.height)
        const framing = document.querySelector(".c-scan")?.dataset.cameraFramingValue || "full"
        return guideInFrame(canvas.width, canvas.height, stage.width, stage.height, liveGuideRect(stage.width, stage.height, framing))
      }
```

and inside `draw`, start with `const card = cardBox()` (the stage can resize between frames). `show_synthetic_card` calls `window.__syntheticCard(name, lines, true)`; `pick_synthetic_photo` and `detect_guide_card` keep calling it with two arguments. In `show_synthetic_card` change `.c-scanner__video` to `.c-scan__video, .c-scanner__video`, and in `restart_camera` `.c-scanner` to `.c-scan, .c-scanner` (Phase 3 renames them, and T3.5 drops the old names; this task changes the helper only, and the old page's examples keep passing until Phase 3 because the helper falls back to `guideRect` when there is no `.c-scan__stage`; both selectors match the old page now and the new one after Phase 3). Run `bin/rspec spec/system/scanner_spec.rb spec/system/scanner_detection_spec.rb`: green. Commit `test(scanner): draw the synthetic card where the live guide falls (#344)`.

---

## Phase 2: The notice's lines in one partial

**Implements:** decision 16 (spec 1.0.1: the partial is shared with spec 084) · **Satisfies:** `spec/footer_core_spec.rb`
**Files:** `app/views/layouts/_notice_lines.html.erb` (new), `_notice_foot.html.erb` (new), `_footer.html.erb`, `spec/footer_core_spec.rb`

### T2.1 One partial for the notice's lines

Spec 084 (#374, another branch) builds `layouts/_notice_lines.html.erb` with the licence line after the types' lines and makes the footer always present. This task creates the same file under the same name with the types' lines only, so the merge is a take-theirs on one file (maintainer's ruling, 2026-11-13). Keep `_footer.html.erb`'s change to the one line below, in this commit alone.

Test first: in `spec/footer_core_spec.rb` the file list becomes `%w[app/views/layouts/application.html.erb app/views/layouts/_footer.html.erb app/views/layouts/_notice_lines.html.erb app/views/layouts/_notice_foot.html.erb app/models/catalog/content_notice.rb]` and the first example's description "covers the layout, the footer's and the sheets' foot's partials and the model that collects the notices" (red: two files missing). Create `app/views/layouts/_notice_lines.html.erb` (no locals):

```erb
<%# The content notices' lines, one per paragraph, their links as the footer draws them (spec 018 FR-1, FR-4). The footer renders
    them, and so does the foot of a sheet on a one-screen focused page, which has no footer (spec 082 decision 16). Shared with
    spec 084, which adds the licence line after them. %>
<% Catalog::ContentNotice.lines.each do |line| %>
  <p><% line.parts.each do |text, address| %><%= address ? link_to(text, address, rel: "noopener") : text %><% end %></p>
<% end %>
```

`app/views/layouts/_notice_foot.html.erb`:

```erb
<%# A sheet's foot on a one-screen focused page (spec 080 decision 13; spec 082 decision 16): a sheet always has one, which is how
    such a page meets the rule that every page shows the notice (spec 084). %>
<div class="c-sheet__foot"><%= render "layouts/notice_lines" %></div>
```

and in `_footer.html.erb` the loop becomes `<%= render "layouts/notice_lines" %>` inside `<footer class="c-footer">` (its `if lines.any?` and comment kept). Run `bin/rspec spec/footer_core_spec.rb spec/requests/footer_spec.rb spec/system/footer_spec.rb`: green (the footer's markup is the same). Commit `refactor(layout): the notice's lines in one partial (#344)`.

---

## Phase 3: The shell

**Implements:** FR-2, FR-4; decisions 6 to 9, 14, 17, 18, 24 · **Satisfies:** AC-1.1 to 1.9, AC-2.1, AC-2.2, AC-2.4, AC-6.1's opening
**Files:** `app/helpers/scanners_helper.rb`, `spec/helpers/scanners_helper_spec.rb`, `app/views/icons/_torch.html.erb`, `_chevron_down.html.erb`, `app/views/scanners/*`, `app/assets/stylesheets/collector/additions.css`, `app/javascript/controllers/{scan_shell,sheets,camera,card_reader}_controller.js`, `spec/support/scanner_helpers.rb`, `spec/system/scanner_page_spec.rb`, the existing scanner specs (selector map)

### T3.1 The destination's value, the list's title, the after-add sentence (helpers)

Test first, inside the existing `RSpec.describe ScannersHelper` of `spec/helpers/scanners_helper_spec.rb` add the `let`s and three `describe` blocks below (only the inner part of the block shown is new; the existing examples stay; there is no `scanner_sitting` factory, so an unsaved `Scanner::Sitting.new` stands in):

```ruby
require "rails_helper"

RSpec.describe ScannersHelper, type: :helper do
  let(:conditions) { Catalog.collecting_for("mtg").conditions }
  let(:account) { create(:account) }
  let(:binder) { create(:location, account:, name: "Blue binder") }

  describe "#scanner_destination" do
    it "names the place and the short condition in decision 7's four forms (spec 082 AC-1.4)", :aggregate_failures do
      expect(helper.scanner_destination(Scanner::Sitting.new(account:, condition: "near_mint", location: binder), conditions)).to eq("Blue binder · NM")
      expect(helper.scanner_destination(Scanner::Sitting.new(account:, location: binder), conditions)).to eq("Blue binder")
      expect(helper.scanner_destination(Scanner::Sitting.new(account:, condition: "near_mint"), conditions)).to eq("No location · NM")
      expect(helper.scanner_destination(nil, conditions)).to eq("No location")
    end
  end

  describe "#sitting_title" do
    it "is today's heading, with no sitting too (spec 082 decision 9)", :aggregate_failures do
      sitting = Scanner::Sitting.new(account:, condition: "near_mint", location: binder)
      expect(helper.sitting_title(sitting, [ :one, :two ], conditions)).to eq("This sitting: 2 cards, Near mint, in Blue binder")
      expect(helper.sitting_title(nil, [], conditions)).to eq("This sitting: 0 cards")
    end
  end

  describe "#scanner_added" do
    it "is the after-add line's sentence (spec 082 decision 12, AC-5.1, AC-5.2)", :aggregate_failures do
      printing = create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123")).entry
      expect(helper.scanner_added(printing, "foil")).to eq("Added Lightning Bolt MOM · 123, foil")
      expect(helper.scanner_added(printing, nil)).to eq("Added Lightning Bolt MOM · 123")
    end
  end
end
```

Red. In `ScannersHelper` add, and extend `sitting_focus_data`'s comment to name `:main`:

```ruby
  # "Atraxa › Main · NM": the top bar's value, the sitting's place (a zone by its label) and its condition's short label, in spec
  # 082 decision 7's four forms ("Blue binder", "No location · NM", "No location"). The scale is the Hash the caller gives
  # (condition key => [ long label, short label ]); nil sitting reads as nothing set.
  #
  # @param sitting [Scanner::Sitting, nil]
  # @param conditions [Hash{String => Array(String, String)}]
  # @return [String]
  def scanner_destination(sitting, conditions)
    short = sitting&.condition && conditions.dig(sitting.condition, 1)
    [ sitting&.location&.label || "No location", short ].compact.join(" · ")
  end

  # "This sitting: 12 cards, Near mint, in Blue binder": the list sheet's title, today's heading (spec 009 AC-3.2), with no
  # sitting too ("This sitting: 0 cards", spec 082 decision 9).
  #
  # @param sitting [Scanner::Sitting, nil]
  # @param entries [Array] the kept entries
  # @param conditions [Hash{String => Array(String, String)}]
  # @return [String]
  def sitting_title(sitting, entries, conditions)
    words = sitting ? sitting_choices(sitting, conditions) : []
    "This sitting: #{pluralize(entries.size, "card")}#{", #{words.join(", ")}" if words.any?}"
  end

  # "Added Lightning Bolt MOM · 123, foil": the after-add line, which names no condition or place, since the top bar shows them
  # (spec 080 decision 11, spec 082 decision 12); a printing with no finish listed has none.
  #
  # @param printing [Catalog::Entry]
  # @param finish [String, nil]
  # @return [String]
  def scanner_added(printing, finish)
    label = scanner_finish(printing, finish)
    "Added #{printing.name} #{set_number(printing)}#{", #{label.downcase}" if label}"
  end
```

Green. Commit `feat(scanner): the destination, the list's title and the after-add sentence (#344)`.

### T3.2 The torch and the destination's chevron

`app/views/icons/_torch.html.erb`: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M13 2 3 14h9l-1 8 10-12h-9z"/></svg>`; `_chevron_down.html.erb`: the same attributes with `<path d="m6 9 6 6 6-6"/>` (both are spec 080's previews' icons). No test of their own: T3.3's request example asserts both render. Commit with T3.3.

### T3.3 The focused layout and the shell's markup (request first)

The layout's change is its own commit (spec 084's branch edits the layout too). Test first, in `spec/requests/scanners_spec.rb` add a `describe "the one-screen page (spec 082)"` with the example below (red), then **commit 1**, the layout (`app/views/layouts/application.html.erb`):

```erb
  <% notice_lines = Catalog::ContentNotice.lines %>
  <%# A page with no tab bar (a visitor's catalog page, sign-in, sign-up) gives up the bar's clearance (spec 023). A focused page
      (`content_for :focused`) is one screen with its own back arrow and live regions: no header, no status line, no footer
      (its sheets carry the notice), and a body that is exactly the screen (spec 080 decision 8, spec 082 decision 6). %>
  <% focused = content_for?(:focused) %>
  <body class="<%= class_names("c-shell", "c-shell--footed": notice_lines.any? && !focused, "c-shell--untabbed": !content_for?(:tabbar), "c-shell--focused": focused) %>">
    <%= yield :appbar %>
    <% unless focused %><div id="status" class="c-status" role="status" aria-live="polite"><% if (message = flash[:alert] || flash[:notice]) %><%= render "shared/status_message", message:, alert: flash[:alert].present?, undo: (flash[:undo] unless flash[:alert]) %><% end %></div><% end %>
    <%= yield %>
    <% unless focused %><%= render "layouts/footer", lines: notice_lines %><% end %>
    <%= yield :tabbar %>
  </body>
```

No page asks for focus until the scanner's view below, so every other layout and footer example stays green: run `bin/rspec spec/requests/footer_spec.rb spec/system/footer_spec.rb`. Commit `feat(layout): a focused page's body, with no header, status or footer (#344)`.

**Commit 2**, the shell's markup. The example:

```ruby
    it "renders the focused shell with its bars, stage, pane and two sheets (AC-1.1, AC-1.3, AC-1.5, AC-2.2, decision 16)", :aggregate_failures do
      get scanner_path
      body = Nokogiri::HTML5(response.body)
      expect(body.at("body")["class"].split).to include("c-shell", "c-shell--untabbed", "c-shell--focused")
      expect(body.css("#appbar, .c-tabbar, footer.c-footer, body > #status")).to be_empty
      expect(body.at("main.c-scan h1.c-sr").text).to eq("Scan a card")
      expect(body.css(".c-scan__top > *").map { it["class"].to_s[/c-scan__\w+/] }).to eq(%w[c-scan__back c-scan__sitting])
      expect(body.at(".c-scan__back")["href"]).to eq(collection_path)
      expect(body.at(".c-scan__dest").text.squish).to eq("Adding to No location")
      expect(body.css(".c-scan__done")).to be_empty # no sitting open (spec 009 AC-3.7)
      expect(body.css(".c-scan__bottom > *").map { it["id"] || it["class"].to_s[/c-scan__\w+/] }).to eq(%w[scanner_count c-scan__main c-scan__torch])
      expect(body.at("#scanner_count")["aria-label"]).to eq("0 added. Show this sitting's cards.")
      expect(body.at("dialog#scanner_destination_sheet .c-sheet__title").text).to eq("Adding to")
      expect(body.at("dialog#scanner_list_sheet #scanner-sitting-heading").text).to eq("This sitting: 0 cards")
      expect(body.css("dialog .c-sheet__foot").size).to eq(2)
      expect(body.at("main.c-scan noscript").inner_html).to include("The scanner needs JavaScript", "c-sheet__foot")
    end
```

(`c-scan__sitting` is the class of `#scanner_sitting_bar`; the example's `c-scan__\w+` picks the first such class.) Red. Then:

`app/views/scanners/show.html.erb`:

```erb
<% content_for :title, "Scan a card · Collector" %>
<% content_for :focused, "true" %>
<%= render "scanners/head" %>
<%= render "scanners/scanner", **@sitting, heading: "Scan a card", line: @line, unloaded: @unloaded_catalogs, named: @catalogs_named %>
```

`app/views/scanners/_scanner.html.erb` (whole file):

```erb
<%# locals: (sitting:, entries:, conditions:, choices:, added_any:, heading:, line: nil, unloaded: [], named: false, measurement: nil, framing: "full") %>
<%# The one-screen scanner (spec 082; the shell is spec 080's `c-scan`): a top bar with the sitting's destination, the camera's
    stage, a bottom bar whose main button is always in view, the pane a result opens in, and the two sheets that keep the camera
    running (decision 9). State is in the markup (decision 19): `scan-shell` sets `c-scan--result` and the lines' `hidden` from
    what the regions hold. Measurement mode renders the same shell with its run button and sheet (decision 5). %>
<% art = scanner_art %>
<%= tag.main class: "c-scan", data: { controller: "scan-shell sheets card-reader camera",
      card_reader_readings_url_value: scanner_readings_path, card_reader_engine_path_value: ocr_engine_path,
      card_reader_art_index_url_value: (scanner_art_index_path(art[:name]) if art), card_reader_art_settings_value: (art[:settings].to_json if art),
      camera_framing_value: framing,
      action: "camera:ready->card-reader#cameraReady camera:stopped->card-reader#cameraStopped camera:unavailable->card-reader#cameraUnavailable scan-shell:changed->card-reader#shellChanged" } do %>
  <h1 class="c-sr"><%= heading %></h1>
  <div class="c-scan__top">
    <%= link_to collection_path, class: "c-scan__back", "aria-label": "Back" do %><%= render "icons/back" %><% end %>
    <%= render "scanners/sitting_bar", sitting:, conditions: %>
    <%= render "scanner/measurements/run_button", **measurement if measurement %>
  </div>
  <div class="c-scan__stage" data-camera-target="stage">
    <div class="c-scan__feed" data-camera-target="feed" hidden>
      <video class="c-scan__video" data-camera-target="video" playsinline muted autoplay></video>
      <div class="c-scan__guide" data-camera-target="guide" aria-hidden="true"></div>
    </div>
    <canvas class="c-scan__frozen" data-card-reader-target="frozen" aria-hidden="true" hidden></canvas>
    <div class="c-scan__line c-scan__line--status" data-scan-shell-target="statusLine"><p class="c-scan__line-text" id="scanner_status_text" role="status" aria-live="polite" data-card-reader-target="status" data-scan-shell-target="statusText">Loading the scanner…</p></div>
    <%= render "scanners/added_line", **(line || {}) %>
    <%= tag.div(class: "c-scan__catalog") { render "catalog/not_loaded", titles: unloaded, named: } if unloaded.any? %>
    <div class="c-scan__notice" data-card-reader-target="unavailable" hidden>
      <p class="c-scan__notice-text" data-card-reader-target="reason"></p>
      <button type="button" class="c-btn c-btn--secondary" data-card-reader-target="retry" data-action="card-reader#retryCamera">Try the camera again</button>
      <label class="c-btn c-btn--secondary c-scanner__photo">Use a photo<input type="file" accept="image/*" class="c-sr" data-card-reader-target="picker" data-action="change->card-reader#pick" disabled></label>
    </div>
    <div class="c-scan__notice" data-card-reader-target="engineFailed" hidden>
      <p class="c-scan__notice-text">The scanner couldn't load, so neither the camera nor a photo can be read. Check your connection and load it again.</p>
      <button type="button" class="c-btn c-btn--secondary" data-card-reader-target="engineRetry" data-action="card-reader#retryEngine">Load the scanner again</button>
    </div>
    <noscript><div class="c-scan__notice"><p class="c-scan__notice-text">The scanner needs JavaScript. <%= link_to "Search the catalog", catalog_entries_path %> instead.</p><%= render "layouts/notice_foot" %></div></noscript>
    <div class="c-scanpane">
      <div class="c-scanpane__results">
        <div id="status" class="c-scan__pane-status" role="status" aria-live="polite" data-card-reader-target="paneStatus" data-scan-shell-target="paneStatus"></div>
        <div class="c-scanner__failure" data-card-reader-target="failure" data-scan-shell-target="failure" hidden>
          <dl class="c-scanner__read">
            <dt>Name</dt><dd data-card-reader-target="failureName"></dd>
            <dt>Collector line</dt><dd class="c-scanner__mono" data-card-reader-target="failureCollector"></dd>
          </dl>
          <button type="button" class="c-btn c-btn--secondary" data-card-reader-target="resend" data-action="card-reader#resend">Send again</button>
          <%= link_to "Sign in", new_session_path, class: "c-btn c-btn--primary", data: { card_reader_target: "signIn", turbo: false }, hidden: true %>
        </div>
        <div id="scanner_result" class="c-scanner__result" data-card-reader-target="result" data-scan-shell-target="result" data-controller="scanner-reading"
             data-action="turbo:submit-start->scanner-reading#lock turbo:submit-end->scanner-reading#unlock turbo:before-fetch-response->scanner-reading#inspect turbo:frame-missing->scanner-reading#printingsMissing turbo:fetch-request-error->scanner-reading#printingsErrored turbo:frame-load->scanner-reading#printingsLoaded"></div>
      </div>
    </div>
  </div>
  <div class="c-scan__bottom">
    <%= render "scanners/count", count: entries.size %>
    <button type="button" class="c-btn c-btn--primary c-scan__main" data-card-reader-target="main" data-action="card-reader#main" data-scan-main disabled aria-busy="true">Capture</button>
    <button type="button" class="c-btn c-btn--secondary c-scan__torch" aria-label="Torch" aria-pressed="false" data-camera-target="torch" data-action="camera#toggleTorch" hidden><%= render "icons/torch" %></button>
  </div>
  <%= render "scanners/destination_sheet", sitting:, conditions:, choices:, art: %>
  <%= render "scanners/list_sheet", sitting:, entries:, conditions:, added_any: %>
  <%= render "scanner/measurements/run_sheet", **measurement if measurement %>
<% end %>
```

`_sitting_bar.html.erb`:

```erb
<%# locals: (sitting:, conditions:) %>
<%# The top bar's sitting parts (spec 082 decision 7): the destination, which opens its sheet, and Done while a sitting is open
    (spec 009 AC-3.7). `display:contents`, so its two children sit in the top bar's row; an answer replaces it whole. %>
<div id="scanner_sitting_bar" class="c-scan__sitting">
  <button type="button" class="c-scan__dest" data-action="sheets#open" data-sheets-id-param="scanner_destination_sheet">
    <span class="c-scan__dest-label">Adding to</span>
    <span class="c-scan__dest-value"><span class="c-scan__dest-text"><%= scanner_destination(sitting, conditions) %></span><%= render "icons/chevron_down" %></span>
  </button>
  <%= link_to "Done", new_scanner_sitting_ending_path, class: "c-btn c-btn--ghost c-scan__done" if sitting %>
</div>
```

`_count.html.erb`:

```erb
<%# locals: (count:) %>
<%# The bottom bar's count (spec 080 decision 11): the sitting's kept entries; it opens the list sheet. %>
<%= tag.button type: "button", id: "scanner_count", class: "c-btn c-btn--secondary c-scan__count", "aria-label": "#{count} added. Show this sitting's cards.",
      data: { action: "sheets#open", sheets_id_param: "scanner_list_sheet" } do %><b><%= count %></b><span>added</span><% end %>
```

`_added_line.html.erb` (the action partial is T5's; this task renders it with no entry):

```erb
<%# locals: (message: nil, alert: false, link: nil, removal_undo: nil) %>
<%# The after-add line (spec 080 decision 17, spec 082 decisions 10 and 12): its `role="status"` paragraph stays in the document
    and an answer replaces its text; the action (Undo, a link) sits beside it, outside the live region. A page load shows a flash
    or the end of a sitting here. `scan-shell` shows the wrapper while the text isn't empty. %>
<div class="c-scan__line c-scan__line--added<%= " c-scan__line--alert" if alert %>" data-scan-shell-target="added" <%= "hidden" if message.blank? %>>
  <p class="c-scan__line-text" id="scanner_added_text" role="status" aria-live="polite" data-scan-shell-target="addedText" data-card-reader-target="addedText"><%= message %></p>
  <%= render "scanners/added_action", link:, removal_undo: %>
</div>
```

`_added_action.html.erb`:

```erb
<%# locals: (entry: nil, link: nil, removal_undo: nil, focus: nil) %>
<%# What the after-add line offers beside its sentence: Undo for the entry just added, the collection after a sitting ends, or a
    flash's Undo; nothing after an Undo. `focus` is where focus goes once it connects (spec 082 decision 15). %>
<%= tag.div id: "scanner_added_action", class: "c-scan__added-action", data: sitting_focus_data(focus) do %>
  <% if entry %>
    <%= button_to "Undo", scanner_sitting_entry_undo_path(entry), class: "c-btn c-btn--ghost", "aria-label": "Undo #{scanner_copy(entry.printing, entry.finish)}",
          form: { class: "c-scan__undo", data: { scanner_event: "undo", reading_key: entry.reading_key } } %>
  <% elsif link %>
    <%= link_to link.first, link.last, class: "c-btn c-btn--ghost" %>
  <% elsif removal_undo %>
    <%= button_to "Undo", collection_bulk_removal_undo_path(removal_undo), params: { return_to: scanner_path }, class: "c-btn c-btn--ghost", form: { class: "c-scan__undo", data: { turbo: false } } %>
  <% end %>
<% end %>
```

`_destination_sheet.html.erb`:

```erb
<%# locals: (sitting:, conditions:, choices:, art:) %>
<%# The sitting's choices as a sheet (spec 082 decision 9): its own live region (a modal makes the rest of the page inert,
    decision 10), today's form, "Use a photo" with the framing hint, the art line, the notice's foot (decision 16). %>
<dialog class="c-sheet" id="scanner_destination_sheet" aria-labelledby="scanner_destination_title" data-action="click->sheets#backdrop close->sheets#closed">
  <div class="c-sheet__head">
    <h2 class="c-sheet__title" id="scanner_destination_title">Adding to</h2>
    <form method="dialog" class="c-sheet__dismiss"><button class="c-btn c-btn--ghost c-sheet__close" aria-label="Close"><%= render "icons/cross" %></button></form>
  </div>
  <div class="c-sheet__body">
    <div id="scanner_destination_status" class="c-scan__sheet-status" role="status" aria-live="polite" data-sheet-status></div>
    <%= render "scanners/picker", condition: sitting&.condition, location_id: sitting&.location_id, conditions:, choices: %>
    <div class="c-scan__photo">
      <label class="c-btn c-btn--secondary c-scanner__photo">Use a photo<input type="file" accept="image/*" class="c-sr" data-card-reader-target="picker" data-action="change->card-reader#pick" disabled></label>
      <p class="c-scanner__hint">Using a photo? Take the whole card, upright, filling most of the photo as the live guide does, on a plain background.</p>
    </div>
    <% if art %><p class="c-scanner__art" role="status" aria-live="polite" data-card-reader-target="artStatus">Loading artwork matching…</p><% end %>
    <%= render "layouts/notice_foot" %>
  </div>
</dialog>
```

`_list_sheet.html.erb`:

```erb
<%# locals: (sitting:, entries:, conditions:, added_any:) %>
<%# The sitting's list as a sheet (spec 082 decision 9): today's heading as its title, focusable for spec 047's focus after an
    Undo; its own live region; today's entries; the notice's foot. An answer replaces the title's text and the entries' section,
    never the dialog, so an open sheet stays open (decision 15). %>
<dialog class="c-sheet" id="scanner_list_sheet" aria-labelledby="scanner-sitting-heading" data-action="click->sheets#backdrop close->sheets#closed">
  <div class="c-sheet__head">
    <h2 class="c-sheet__title" id="scanner-sitting-heading" tabindex="-1"><%= sitting_title(sitting, entries, conditions) %></h2>
    <form method="dialog" class="c-sheet__dismiss"><button class="c-btn c-btn--ghost c-sheet__close" aria-label="Close"><%= render "icons/cross" %></button></form>
  </div>
  <div class="c-sheet__body">
    <div id="scanner_list_status" class="c-scan__sheet-status" role="status" aria-live="polite" data-sheet-status></div>
    <%= render "scanners/sitting", sitting:, entries:, conditions:, added_any: %>
    <%= render "layouts/notice_foot" %>
  </div>
</dialog>
```

`_sitting.html.erb` (whole file):

```erb
<%# locals: (sitting:, entries:, conditions:, added_any:, focus: nil) %>
<%# The open sitting's adds, newest first: the 10 newest, the rest behind "Show all" (spec 009 AC-3.2), in the list sheet (spec
    082 decision 9), whose title is the heading. Always present, so an answer can replace it. %>
<%= tag.section id: "scanner_sitting", class: "c-scanner__sitting", aria: { labelledby: "scanner-sitting-heading" }, data: sitting_focus_data(focus) do %>
  <% if entries.empty? %>
    <%# Four states (spec 042 decision 3): entries all undone keep spec 009's copy; a sitting with none says what cards get,
        naming only what is set; with neither it says nothing was added. %>
    <% words = sitting ? sitting_choices(sitting, conditions) : [] %>
    <% if added_any %>
      <p class="c-empty">Everything added in this sitting was undone.</p>
    <% elsif words.any? %>
      <p class="c-empty">Cards you scan now: <%= words.join(", ") %>.</p>
    <% else %>
      <p class="c-empty">Nothing added yet.</p>
    <% end %>
  <% else %>
    <ul class="c-list"><%= render partial: "scanners/sitting_entry", collection: entries.first(Scanner::Sitting::SHOWN), as: :entry %></ul>
    <% if entries.size > Scanner::Sitting::SHOWN %>
      <details class="c-scanner__more">
        <summary class="c-btn c-btn--ghost c-btn--sm">Show all <%= entries.size %></summary>
        <ul class="c-list"><%= render partial: "scanners/sitting_entry", collection: entries.drop(Scanner::Sitting::SHOWN), as: :entry %></ul>
      </details>
    <% end %>
  <% end %>
<% end %>
```

`_picker.html.erb`: wrap the form in `<%= tag.div id: "scanner_picker", data: sitting_focus_data(focus) do %> … <% end %>`, add `focus: nil` to its locals line, and change its comment's "answered by a Turbo Stream that redraws the panel" to "in the destination sheet (spec 082 decision 9), answered by a Turbo Stream that redraws it". Delete `_summary.html.erb`.

`ScannersController#show` gains `@line = nil` (T5.4 replaces it with `scanner_line`) and drops `@summary`; its `@sitting` is unchanged.

`scanner_sitting_core_spec.rb`: the glob becomes `"{app/models/scanner/sitting{,_entry}.rb,app/views/scanners/_{sitting,sitting_entry,picker,sitting_bar,count,added_line,added_action,destination_sheet,list_sheet}.html.erb,app/helpers/scanners_helper.rb}"` and the count 12. The destination sheet holds no collectible name: `scanner_art` is a helper call, and its art line's text names none.

The page loses its footer, header and navigation here, so the examples that asserted them change in this commit: in `spec/requests/footer_spec.rb`, `scanner_path` and the measurement page leave the "every page has the footer" list (line 37; the replay page keeps its footer, since it is not focused), and the scanner policy's example (line 210) becomes "the scanner sends the policy it always sent and its sheets carry the notice (spec 082 decision 16)": `expect_the_scanner_policy` unchanged, no `footer.c-footer`, two `.c-sheet__foot` (the measurement page is not focused until T7.2, so its example at line 230 is unchanged here); in `spec/system/footer_spec.rb` the two scanner examples (lines 149, 161) become "has no footer on the scanner; the notice is in each sheet's foot" (open each sheet; `.c-sheet__foot` holds the lines and the Scryfall link's `href`) and "shows the notice with script off in the `<noscript>` notice" (a `rack_test` request, as spec 067's no-script example does: `.c-scan noscript` contains the lines); in `spec/requests/scanners_spec.rb` the shutter's regex (line 20) uses `c-scan__main`, and AC-8.1's "marked current on the scanner" (lines 57–58) checks the ending page (`new_scanner_sitting_ending_path` with an open sitting) and that the scanner page has no `nav` (spec 082 decision 24). Until T7.2 builds measurement mode on the shell, `scanner/measurements/show.html.erb` keeps its page and passes the shell's new required local: `<%= render "scanners/scanner", **@sitting, heading: "Measure the scanner" %>` after its panel (it asks for no focus, so it keeps its header, footer and scroll, and its examples stay green). Run those three files, `spec/requests/scanner/measurements_spec.rb`, `spec/scanner_sitting_core_spec.rb` and `spec/footer_core_spec.rb`: green. The request example written first is committed with this commit, so commit 1 is green on its own. Commit `feat(scanner): the one-screen shell's markup (#344)` (with T3.2's icons).

### T3.4 The spec 082 CSS block

Insert directly above the reduced-motion heading:

```css
/* ---------- Scanner page (spec 082): the one-screen scanner built on the scan shell ---------- */
/* The shell, the lines and the pane are spec 080's; this block is what the page adds. The sitting's top-bar parts are one
   element an answer replaces, laid out as the top bar's own children. The bars grow by the safe-area insets of a phone with a
   notch or home indicator (decision 18). The frozen frame is the captured frame on a canvas, cropped as the video is, so the
   collector sees what was read while it is read (decision 11). A stage notice is centred on the stage (the camera or the
   engine unavailable, no script); the catalog-not-loaded line sits at the stage's foot (decision 14). Today's result sits in an
   interim scrolling body until #345 replaces it (decision 11, `c-scanpane__results`). Each sheet's live region shows only
   when it holds a sentence. From 640px the shell is a centred 480px column and the scanner's sheets sit under it (decision
   17), by a rule scoped to the scanner, so the sheet's own rule is unchanged. */
.c-scan__sitting { display:contents; }
.c-scan__top { box-sizing:border-box; height:calc(56px + env(safe-area-inset-top)); padding:env(safe-area-inset-top) calc(var(--space-2) + env(safe-area-inset-right)) 0 calc(var(--space-2) + env(safe-area-inset-left)); }
.c-scan__bottom { box-sizing:border-box; height:calc(96px + env(safe-area-inset-bottom)); padding:0 calc(var(--space-4) + env(safe-area-inset-right)) env(safe-area-inset-bottom) calc(var(--space-4) + env(safe-area-inset-left)); }
.c-scan__feed { position:absolute; inset:0; }
.c-scan__frozen { box-sizing:border-box; position:absolute; inset:0; width:100%; height:100%; object-fit:cover; }
.c-scan__line--alert { border-color:var(--warning); }
.c-scan__added-action { display:contents; } /* its Undo form or link is the line's flex item; empty, it draws nothing */
.c-scan__notice { box-sizing:border-box; position:absolute; z-index:1; left:var(--space-4); right:var(--space-4); top:50%; transform:translateY(-50%);
  display:flex; flex-direction:column; align-items:center; gap:var(--space-3); margin:0; padding:var(--space-4); background:var(--surface-raised);
  border:1px solid var(--line-strong); border-radius:var(--radius-md); color:var(--ink); font:400 14px/20px var(--font-sans); text-align:center; }
.c-scan__notice-text { margin:0; overflow-wrap:anywhere; }
.c-scan__notice .c-btn { box-sizing:border-box; min-height:44px; }
.c-scan__notice .c-sheet__foot { align-self:stretch; text-align:left; }
.c-scan__catalog { box-sizing:border-box; position:absolute; z-index:1; left:var(--space-4); right:var(--space-4); bottom:var(--space-4); }
.c-scanpane__results { box-sizing:border-box; flex:1 1 auto; min-height:0; display:flex; flex-direction:column; gap:var(--space-4);
  overflow-y:auto; overscroll-behavior:contain; padding:var(--space-4); }
.c-scan__pane-status:empty, .c-scan__sheet-status:empty { display:none; }
.c-scan__sheet-status { margin-bottom:var(--space-4); }
.c-scan__photo { display:flex; flex-direction:column; align-items:flex-start; gap:var(--space-2); margin-top:var(--space-4); }
.c-scan .c-sheet .c-btn { box-sizing:border-box; min-height:44px; min-width:44px; }
.c-scan .c-sheet__title:focus-visible { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-sm); }
@media (min-width: 640px) {
  .c-shell--focused { background:var(--surface-sunken); }
  .c-scan { box-sizing:border-box; max-width:480px; margin:0 auto; }
  .c-scan .c-sheet[open] { box-sizing:border-box; max-width:480px; margin:0 auto; }
}
```

Its test is T3.5's system spec (the layout is measured there). Commit with T3.5.

### T3.5 The shell's state and the sheets (system test first)

`spec/support/scanner_helpers.rb` gains (each with a YARD summary):

```ruby
  # Opens the scanner in a frame `width` × `height` from the collection page (the scanner's own policy frames nothing,
  # `frame-src 'none'`), and waits for the live feed. The page never scrolls, so the frame draws no scrollbar and its width is
  # the viewport's (spec 082 Verification).
  #
  # @param width [Integer] the frame's width in px
  # @param height [Integer] the frame's height in px
  # @param path [String] the page to open, the scanner or measurement mode
  # @return [Integer] the frame's viewport width
  def open_scanner_frame(width:, height:, path: scanner_path)
    visit collection_path
    open_in_narrow_frame(path, width:, height:, ready: ".c-scan__feed:not([hidden])").first
  end

  # The one-screen measures of the page the driver is in, read in one script (spec 082 AC-1.1, AC-1.2): whether the document
  # scrolls, after an attempt to scroll to its end, and the boxes of the bars, the stage and the main button.
  #
  # @return [Hash] "scrollable", "scrollY", "height" and "top", "stage", "bottom", "main" boxes (top, bottom)
  def one_screen
    page.evaluate_script(<<~JS)
      (() => {
        const root = document.documentElement
        window.scrollTo(0, root.scrollHeight)
        const box = (selector) => { const b = document.querySelector(selector).getBoundingClientRect(); return { top: b.top, bottom: b.bottom, height: b.height } }
        return { scrollable: root.scrollHeight > root.clientHeight, scrollY: window.scrollY, height: window.innerHeight,
                 top: box(".c-scan__top"), stage: box(".c-scan__stage"), bottom: box(".c-scan__bottom"), main: box(".c-scan__main") }
      })()
    JS
  end

  # Opens the destination sheet, as the collector's tap on the top bar does.
  def open_destination = find(".c-scan__dest").click

  # Opens the sitting's list sheet from the count.
  def open_sitting_list = find("#scanner_count").click
```

Create `spec/system/scanner_page_spec.rb`:

```ruby
require "rails_helper"

# Spec 082 Stories 1 and 2: the scanner is one screen that never scrolls, at phone sizes in a frame and at a desktop width, and
# its sheets open over the running camera without a navigation.
RSpec.describe "The one-screen scanner", type: :system do
  let(:user) { create(:user) }

  before { system_sign_in_as(user) }

  def expect_one_screen(viewport_height)
    measures = one_screen
    expect(measures["scrollable"]).to be(false)
    expect(measures["scrollY"]).to eq(0)
    expect(measures["top"]["top"]).to eq(0)
    expect(measures["height"]).to eq(viewport_height)
    expect(measures["bottom"]["bottom"]).to be_within(0.5).of(viewport_height)
    expect(measures["stage"]["top"]).to be_within(0.5).of(measures["top"]["bottom"])
    expect(measures["stage"]["bottom"]).to be_within(0.5).of(measures["bottom"]["top"])
    expect(measures["main"]["bottom"]).to be <= viewport_height
  end

  [ [ 390, 844 ], [ 360, 640 ], [ 360, 560 ] ].each do |width, height|
    it "is one screen at #{width} × #{height}, with the body focused and no header, tab bar or footer (AC-1.1)", :aggregate_failures do
      expect(open_scanner_frame(width:, height:)).to eq(width)
      within_narrow_frame do
        expect(page).to have_css("body.c-shell.c-shell--untabbed.c-shell--focused")
        expect(page).to have_no_css("#appbar, .c-tabbar, footer.c-footer")
        expect_one_screen(height)
        expect(page_fits_sideways?).to be(true)
      end
    end
  end

  it "is a centred 480px column at a desktop width, its sheet under it (AC-1.7)", :aggregate_failures do
    page.current_window.resize_to(1280, 900)
    visit scanner_path
    expect(page).to have_css(".c-scan__feed:not([hidden])", wait: 10)
    shell = page.evaluate_script("(() => { const b = document.querySelector('.c-scan').getBoundingClientRect(); return [b.left, b.width] })()")
    expect(shell).to eq([ (page.evaluate_script("document.documentElement.clientWidth") - 480) / 2.0, 480 ])
    expect_one_screen(page.evaluate_script("window.innerHeight"))
    open_destination
    sheet = page.evaluate_script("(() => { const b = document.querySelector('dialog[open]').getBoundingClientRect(); return [b.left, b.width] })()")
    expect(sheet).to eq(shell)
  end

  it "opens the destination sheet over the running camera and closes it three ways (AC-2.1, AC-2.2, AC-2.4)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.execute_script("window.__marker = 'still here'")
    [ -> { click_on "Close" }, -> { find("dialog[open]").send_keys(:escape) }, -> { page.execute_script("document.querySelector('dialog[open]').dispatchEvent(new MouseEvent('click', { bubbles: true }))") } ].each do |close|
      find(".c-scan__dest").send_keys(:enter) # by keyboard: Firefox on a Mac doesn't focus a clicked button, so a click leaves no opener to return to
      expect(page).to have_css("dialog#scanner_destination_sheet[open]")
      expect(page.evaluate_script("document.activeElement.closest('dialog')?.id")).to eq("scanner_destination_sheet")
      close.call
      expect(page).to have_no_css("dialog[open]")
      expect(page.evaluate_script("document.activeElement.classList.contains('c-scan__dest')")).to be(true)
    end
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
  end

  it "holds the sheet's parts in order: its region, the form, Use a photo and its hint, the foot (AC-2.2)" do
    visit scanner_path
    open_destination
    order = page.evaluate_script(<<~JS)
      Array.from(document.querySelector("#scanner_destination_sheet .c-sheet__body").children).map((el) => el.id || el.className)
    JS
    expect(order).to eq(%w[scanner_destination_status scanner_picker c-scan__photo c-sheet__foot])
  end

  it "opens the list sheet from the count, with the camera running (AC-6.1)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.execute_script("window.__marker = 'still here'")
    open_sitting_list
    expect(page).to have_css("dialog#scanner_list_sheet[open] #scanner-sitting-heading", text: "This sitting: 0 cards")
    expect(page).to have_css("#scanner_list_sheet .c-empty", text: "Nothing added yet.")
    expect(page.evaluate_script("window.__marker")).to eq("still here")
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
  end
end
```

(The backdrop click is a click whose target is the dialog element itself, which is what a tap outside its children produces; a `MouseEvent` dispatched on the dialog stands in for it, since a WebDriver click at a point over the backdrop lands on the dialog too but needs coordinates; record which one ran in a `Ruling:` if the dispatched event is used.) Red. Then:

`app/javascript/controllers/sheets_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

// Opens a page's sheets (spec 080 decision 2, spec 082 decision 9): a native dialog opened as a modal, so focus moves into it and
// returns to its opener on closing, and Escape closes it; the element does both. A tap on the backdrop is a click whose target
// is the dialog itself (its children cover the rest), and closes it. On closing, the sheet's live regions are emptied, so a
// sentence is never shown stale the next time it opens (spec 082 decision 10).
export default class extends Controller {
  open({ params: { id } }) {
    const sheet = document.getElementById(id)
    if (sheet && !sheet.open) sheet.showModal()
  }

  backdrop(event) {
    if (event.target === event.currentTarget) event.currentTarget.close()
  }

  // The element's own focus return fails when an answer replaced the opener while the sheet was open (a "Set" redraws the
  // destination, an Undo the count), so focus would fall to the body: the opener of the same name is focused instead.
  closed({ currentTarget }) {
    currentTarget.querySelectorAll("[data-sheet-status]").forEach((region) => region.replaceChildren())
    const active = document.activeElement
    if (!active || active === document.body || !active.isConnected || currentTarget.contains(active)) {
      document.querySelector(`[data-sheets-id-param="${currentTarget.id}"]`)?.focus()
    }
  }
}
```

`app/javascript/controllers/scan_shell_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

// Keeps the shell's state in its markup (spec 082 decision 19): `c-scan--result` while the pane has something to show (a result,
// a sentence in its region, a send failure); the after-add line shown while its text isn't empty; the status line shown while
// it has text and neither the after-add line nor the pane shows, and emptied whenever it hides, so the next sentence written to
// it is a change a screen reader announces (decision 10). A Turbo Stream that empties the result therefore returns the shell to
// the camera with no script of its own. Dispatches scan-shell:changed ({ result }) when the result state changes.
export default class extends Controller {
  static targets = [ "result", "paneStatus", "failure", "statusLine", "statusText", "added", "addedText" ]

  connect() {
    this.observer = new MutationObserver(() => this.sync())
    this.observer.observe(this.element, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: [ "hidden" ] })
    this.sync()
  }

  disconnect() {
    this.observer.disconnect()
  }

  sync() {
    const result = filled(this.resultTarget) || filled(this.paneStatusTarget) || !this.failureTarget.hidden
    const added = filled(this.addedTextTarget)
    this.element.classList.toggle("c-scan--result", result)
    setHidden(this.addedTarget, !added)
    if ((added || result) && filled(this.statusTextTarget)) this.statusTextTarget.textContent = ""
    setHidden(this.statusLineTarget, !filled(this.statusTextTarget) || added || result)
    if (result !== this.result) {
      this.result = result
      this.dispatch("changed", { detail: { result } })
    }
  }
}

// Text or any element: a result is markup, a region holds a paragraph.
function filled(element) {
  return element.textContent.trim() !== "" || element.childElementCount > 0
}

// Only a change is written: the observer watches `hidden`, and an unchanged write would still queue a record.
function setHidden(element, hidden) {
  if (element.hidden !== hidden) element.hidden = hidden
}
```

(The status line's text is emptied only while it would be hidden; the card reader writes "Reading the card…" after emptying the after-add text, so the order is its, T4.2.)

`camera_controller.js`: targets `[ "stage", "feed", "video", "guide", "torch" ]`, `static values = { framing: { type: String, default: "full" } }`; import `guideInFrame, liveGuideRect`; in `start()` replace `this.stageTarget.hidden = false` with `this.feedTarget.hidden = false`; in `unavailable()` replace `this.stageTarget.hidden = true` with `this.feedTarget.hidden = true` (the stage stays, so the bars never move, FR-2); `grab()` and `layoutGuide()` compute `const guide = liveGuideRect(view.width, view.height, this.framingValue)` once and use it (`grab` returns `card: guideInFrame(image.width, image.height, view.width, view.height, guide)`). Its header comment gains "The guide is the live one (spec 082 decision 2), drawn and mapped from one computation; measurement mode may ask for the shipped card size (`framing`)."

`card_reader_controller.js` in this task only renames: targets `shutter` → `main`, `engineRetry` stays, adds `engineFailed`, `frozen`, `paneStatus`, `addedText`; `render()` sets `this.mainTarget`; `pickerTargets` everywhere `pickerTarget` was (each disabled likewise; `pick(event)` reads `event.target.files[0]` and empties `event.target.value`); the failure's `failureMessage` target goes; `send()`'s "Done…" sentence, `failed()`'s sentence and the no-edge sentence are written to `this.paneStatusTarget` now (as a `c-status__message` paragraph; T4.2 adds the wait for the pane), since `scan-shell` empties the status line whenever the pane shows. `capture()` is `main()` for now (T4.2 adds "Scan again"). `startEngine`'s failure also unhides `engineFailedTarget` (and still says the sentence on the status line: the notice is not a live region, so the status line is what announces it), and `retryEngine`/`startEngine` hide it.

Existing specs: apply the selector map to `scanner_spec.rb` (`.c-scanner__guide` → `.c-scan__guide` at line 16; its last example, "fits a 360px screen with the shutter in the bottom third", is replaced by `scanner_page_spec.rb`'s and deleted, with the commit body saying so), `scanner_detection_spec.rb` (`.c-scanner` → `.c-scan`; the no-edge example's `.c-scanner__status` → `#status`; the photo hint's example (line 67) opens the destination sheet first, where the hint now is), `scanner_art_spec.rb` (open the destination sheet before asserting `.c-scanner__art`'s text, or `visible: :all` where the example asserts absence), and `scanner_helpers.rb` (`.c-scan` and `.c-scan__video` only in `restart_camera` and `show_synthetic_card`; `wait_for_scanner` unchanged: "Capture" enabled). Expected red after this task, each with the task that turns it green, listed in the commit body: `scanner_sitting_spec.rb`, `scanner_adding_spec.rb`, `scanner_timing_spec.rb` (T5.3), `scanner_measurement_spec.rb` (T7.2), `small_controls_touch_floor_spec.rb` and `select_touch_floor_spec.rb` (T6.3). Everything else is green.

Run `bin/rspec spec/system/scanner_page_spec.rb spec/system/scanner_spec.rb spec/system/scanner_detection_spec.rb spec/system/scanner_art_spec.rb spec/system/scanner_geometry_spec.rb spec/requests/scanners_spec.rb spec/scanner_sitting_core_spec.rb spec/helpers/scanners_helper_spec.rb`: green. Prove AC-1.1 by removing spec 080's `.c-shell--focused` rule once (the 8px margin scrolls the document: red), and record it in the commit body. Commit `feat(scanner): the shell's state, its sheets and the live guide on the page (#344)` (with T3.4's CSS).

---

## Phase 4: Capture, the frozen frame, a result, Scan again

**Implements:** FR-5; decisions 10, 11, 13, 22 · **Satisfies:** AC-1.2, AC-1.6, AC-3.1 (on the page), AC-3.2, AC-3.4, AC-4.1 to 4.10
**Files:** `app/javascript/controllers/card_reader_controller.js`, `spec/system/scanner_result_spec.rb`, `spec/system/scanner_page_spec.rb`

### T4.1 Results in the pane (system test first)

Create `spec/system/scanner_result_spec.rb`:

```ruby
require "rails_helper"

# Spec 082 Story 4 and AC-3.1: a capture freezes on its frame, its result fills the stage in the pane, and "Scan again" returns
# to the camera; the guide the page draws is the one the crop uses.
RSpec.describe "A result in the pane", type: :system do
  before do
    identity = create(:catalog_identity, name: "Lightning Bolt")
    mom = create(:catalog_set, code: "mom", name: "March of the Machine")
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123"))
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: create(:catalog_set, code: "m10"), number: "146"))
    Catalog::NameIndex.new("mtg").rebuild
    system_sign_in_as(create(:user))
  end

  def guide_and_rule
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      #{ScannerHelpers::MODULES_JS}
      window.__modules.then(({ geometry }) => {
        const stage = document.querySelector(".c-scan__stage").getBoundingClientRect(), guide = document.querySelector(".c-scan__guide").getBoundingClientRect()
        const rule = geometry.liveGuideRect(stage.width, stage.height)
        done({ drawn: [ guide.left - stage.left, guide.top - stage.top, guide.width, guide.height ].map((v) => Math.round(v)),
               rule: [ rule.x, rule.y, rule.width, rule.height ].map((v) => Math.round(v)) })
      })
    JS
  end

  it "draws the guide the rule gives for the stage, and the capture reads a card drawn at it (AC-3.1, AC-3.2)", :aggregate_failures do
    open_scanner_frame(width: 390, height: 844)
    within_narrow_frame do
      measured = guide_and_rule
      expect(measured["drawn"]).to eq(measured["rule"])
      expect(measured["rule"]).to eq([ 15, 127, 360, 502 ])
      show_synthetic_card
      click_on "Capture"
      expect(page).to have_css(".c-scanner__candidate", text: "Lightning Bolt", wait: 30)
      expect(first(".c-scanner__candidate")).to have_text("Matched by its collector line")
    end
  end

  it "freezes on the frame while reading, then shows the result in the pane (AC-4.1, AC-4.2)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.execute_script("const send = window.fetch; window.fetch = (url, options) => url.includes('/scanner/readings') ? new Promise((resolve) => { window.__release = () => resolve(send(url, options)) }) : send(url, options)")
    click_on "Capture"
    expect(page).to have_css("canvas.c-scan__frozen:not([hidden])")
    expect(page).to have_css("#scanner_status_text", text: "Reading the card…", wait: 30)
    expect(page).to have_button("Capture", disabled: true)
    page.execute_script("window.__release()")
    expect(page).to have_css(".c-scan.c-scan--result .c-scanpane__results #scanner_result .c-scanner__candidate", text: "Lightning Bolt", wait: 30)
    expect(page).to have_css("#status", text: "Done. What the scanner read and its candidates are showing.")
    expect(page).to have_css(".c-scan__line--status[hidden]", visible: :all)
    expect(page).to have_button("Scan again", class: "c-btn--secondary")
    expect(page.evaluate_script("window.__tracks.every((track) => track.readyState === 'live')")).to be(true)
  end

  it "returns to the camera on Scan again, sending nothing (AC-4.4)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    click_on "Capture"
    expect(page).to have_css(".c-scanner__candidate", wait: 30)
    sent = scanner_sent.size
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
    expect(page).to have_css("#scanner_status_text", text: "Ready. Line the card up with the guide, then capture.")
    expect(page).to have_button("Capture", class: "c-btn--primary", disabled: false)
    expect(page.evaluate_script("document.getElementById('status').textContent")).to eq("")
    expect(scanner_sent.size).to eq(sent)
  end

  it "scrolls a long result inside the pane at 360 × 640, the document still (AC-4.3, AC-1.2)", :aggregate_failures do
    open_scanner_frame(width: 360, height: 640)
    within_narrow_frame do
      show_synthetic_card
      click_on "Capture"
      expect(page).to have_css(".c-scanner__candidate", wait: 30)
      click_on "Other printings"
      expect(page).to have_css("#scanner_printings li", minimum: 1, wait: 10)
      scrolled = page.evaluate_script("(() => { const body = document.querySelector('.c-scanpane__results'); body.scrollTop = body.scrollHeight; return body.scrollTop })()")
      expect(scrolled).to be > 0
      expect(one_screen).to include("scrollable" => false, "scrollY" => 0)
      expect(one_screen["main"]["bottom"]).to be <= 640
    end
  end

  it "shows a send failure in the pane, and Scan again discards it (AC-4.5)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.driver.browser.manage.delete_cookie("session_id")
    click_on "Capture"
    expect(page).to have_css(".c-scan--result #status", text: "Your session has ended", wait: 30)
    expect(page).to have_link("Sign in")
    click_on "Scan again"
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_no_link("Sign in")
  end

  it "says the card couldn't be read and returns to the camera when reading throws (AC-4.10)", :aggregate_failures do
    visit scanner_path
    show_synthetic_card
    page.execute_script("window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('.c-scan'), 'camera').grab = () => { throw new Error('no frame') }")
    click_on "Capture"
    expect(page).to have_css("#scanner_status_text", text: "The card couldn't be read. Line it up with the guide and try again.")
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_css("canvas.c-scan__frozen[hidden]", visible: :all)
  end
end
```

Red. Then T4.2.

### T4.2 The card reader's flow

In `card_reader_controller.js` (header comment: add "On the one-screen page (spec 082) a capture freezes on its frame (a canvas, decision 11), the answer opens the pane, and the main button reads "Scan again" while a result shows (decision 13); a sentence about a result is written to the pane's region once the pane shows (decision 10).").

```js
const READY_LIVE = "Ready. Line the card up with the guide, then capture."
const SHOWING = "Done. What the scanner read and its candidates are showing."
const COULD_NOT_READ = "The card couldn't be read. Line it up with the guide and try again."

  main() {
    if (this.resultShowing) this.scanAgain()
    else this.capture()
  }

  get resultShowing() {
    return this.element.classList.contains("c-scan--result")
  }

  capture() {
    if (!this.engineReady || !this.cameraLive || this.busy) return
    let grabbed
    try { grabbed = this.camera.grab() } catch { return this.say(COULD_NOT_READ) }
    const { image, card } = grabbed
    this.freeze(image)
    this.read(() => ({ image, card, layout: STRIPS, outline: "live", sizes: this.camera.sizes() }))
  }

  // The captured frame, drawn on the stage's canvas and cropped as the video is (object-fit: cover), so the collector sees
  // what is being read (spec 082 decision 11). Nothing leaves the page.
  freeze(image) {
    Object.assign(this.frozenTarget, { width: image.width, height: image.height })
    this.frozenTarget.getContext("2d").drawImage(image, 0, 0)
    this.frozenTarget.hidden = false
  }

  // Spec 082 decision 13: discards the reading and its key, empties the pane, and returns to the camera (or to the stage notice
  // when the camera is unavailable). Nothing is sent.
  scanAgain() {
    this.paneSaid += 1
    this.lastReading = null
    this.resultTarget.replaceChildren()
    this.paneStatusTarget.replaceChildren()
    this.failureTarget.hidden = true
    this.frozenTarget.hidden = true
    this.say(this.cameraLive ? READY_LIVE : "Ready.")
  }

  // The pane closed (an add cleared the result) or opened: the frozen frame goes with the result, and the main button follows.
  shellChanged({ detail: { result } }) {
    if (!result) this.paneSaid += 1
    if (!result && !this.busy) this.frozenTarget.hidden = true
    this.render()
  }
```

`read()`: first, with `busy` set, `this.paneSaid += 1` and `this.addedTextTarget.textContent = ""` (a reading, a capture's or a photo's, empties the after-add line, decision 10's first row), then `this.say("Reading the card…")` as today; `catch { this.frozenTarget.hidden = true; this.say(COULD_NOT_READ) }` (today's sentence); after `send` succeeds, `if (reading.outline === "not_found") this.paneSay(NO_EDGE)`; the dispatched detail gains `sizes` (`{ videoWidth, videoHeight, stageWidth, stageHeight }` for a live capture, from `camera.sizes()`, else null) for measurement mode (T7.3). `send()`: after `Turbo.renderStreamMessage(...)` replace `this.say("Done. What the scanner read and its candidates are below.")` with `this.paneSay(SHOWING)`. `failed(message, …)`: drop `failureMessageTarget`; after unhiding the failure, `this.paneSay(message, { alert: true })` instead of `this.say(message)`. `cameraReady()` says `READY_LIVE` (as today) only when no result shows. Add:

```js
  // Writes a sentence to the pane's live region once the pane shows: a region filled while hidden and then shown is not
  // announced (spec 080 decision 8; spec 082 decision 10). Waits for `c-scan--result` (set by scan-shell from the answer), at
  // most about two seconds, then one more frame.
  // A sentence for a reading the collector has since discarded ("Scan again", an add, a new reading bump `paneSaid`) is dropped,
  // so a late write can never reopen the pane.
  async paneSay(message, { alert = false } = {}) {
    const said = this.paneSaid
    for (let frame = 0; frame < 120 && !this.resultShowing; frame++) await nextFrame()
    await nextFrame()
    if (said !== this.paneSaid) return
    const paragraph = Object.assign(document.createElement("p"), { className: `c-status__message${alert ? " c-status__message--alert" : ""}`, textContent: message })
    this.paneStatusTarget.replaceChildren(paragraph)
  }

  render() {
    const result = this.resultShowing
    this.mainTarget.textContent = result ? "Scan again" : "Capture"
    this.mainTarget.classList.toggle("c-btn--primary", !result)
    this.mainTarget.classList.toggle("c-btn--secondary", result)
    this.mainTarget.disabled = result ? this.busy : !(this.engineReady && this.cameraLive) || this.busy
    this.mainTarget.setAttribute("aria-busy", String(this.busy || !this.engineReady))
    this.pickerTargets.forEach((picker) => { picker.disabled = !this.engineReady || this.busy })
  }
```

with `const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve))` at the module's end, and `this.paneSaid = 0` in `connect()`. For a photo whose edge wasn't found the no-edge sentence replaces "Done…" in the pane's region (AC-4.9's "ends with"); its text already says what was read. `pick(event)`: close the sheet the picker is in before reading (`event.target.closest("dialog")?.close()`), and freeze nothing (a photo has no stage; its result still opens the pane). In `camera_controller.js` add:

```js
  // The video's and the stage's sizes at a capture, for measurement mode's record (spec 082 AC-7.2).
  sizes() {
    const view = this.stageTarget.getBoundingClientRect()
    return { videoWidth: this.videoTarget.videoWidth, videoHeight: this.videoTarget.videoHeight, stageWidth: Math.round(view.width), stageHeight: Math.round(view.height) }
  }
```

Then `scanner_page_spec.rb` gains AC-1.2's states table:

```ruby
  # Each state of AC-1.2 at one viewport: the main button's label and state, and the page still one screen.
  # Holds the next reading's request until window.__release() is called, so the reading state can be measured.
  def hold_readings = page.execute_script("const send = window.fetch; window.fetch = (url, options) => url.includes('/scanner/readings') ? new Promise((resolve) => { window.__release = () => resolve(send(url, options)) }) : send(url, options)")

  # AC-1.2's states at one viewport: aiming, reading, a result, after an add, the camera unavailable; the engine failing is the
  # next example's. The main button's label and state are the table's, and the page stays one screen in each.
  def states_at(width, height)
    open_scanner_frame(width:, height:)
    within_narrow_frame do
      expect(page).to have_button("Capture", disabled: false, wait: 30)
      expect_one_screen(height)
      show_synthetic_card
      hold_readings
      click_on "Capture"
      expect(page).to have_button("Capture", disabled: true, wait: 30)
      expect_one_screen(height)
      page.execute_script("window.__release()")
      expect(page).to have_button("Scan again", wait: 30)
      expect_one_screen(height)
      find("button[aria-label='Add Lightning Bolt MOM · 123 Foil']").click
      expect(page).to have_css("#scanner_added_text", text: "Added")
      expect(page).to have_button("Capture", disabled: false)
      expect_one_screen(height)
      page.execute_script(%(navigator.mediaDevices.getUserMedia = async () => { throw new DOMException("blocked", "NotAllowedError") }))
      restart_camera
      expect(page).to have_button("Capture", disabled: true)
      expect_one_screen(height)
    end
  end

  [ [ 390, 844 ], [ 360, 640 ], [ 360, 560 ] ].each do |width, height|
    it "keeps the main button in view through aiming, reading, a result, an add and the camera unavailable at #{width} × #{height} (AC-1.2, AC-1.6)", :aggregate_failures do
      create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity: create(:catalog_identity, name: "Lightning Bolt"), name: "Lightning Bolt", set: create(:catalog_set, code: "mom"), number: "123"))
      Catalog::NameIndex.new("mtg").rebuild
      states_at(width, height)
    end
  end
```

The add row needs T5.1's answer: until Phase 5 the add steps of `states_at` fail, so this example is written here and expected red until T5.1 (the commit body says so). The engine-failed row is T6.1's example, run at the three viewports. `scanner_result_spec.rb` also gains: "closes the sheet when a photo is picked from it" (open the destination, `pick_synthetic_photo(input: "#scanner_destination_sheet [data-card-reader-target=picker]")`, `have_no_css("dialog[open]")`, the result shows; AC-2.2); "returns to the camera-unavailable notice on Scan again after a photo" (block the camera, `restart_camera`, `pick_synthetic_photo`, Scan again, the notice and its "Use a photo" show; AC-4.9); "redraws the guide when the stage resizes" (`page.current_window.resize_to(900, 1000)` at the window size, then the guide's box equals `liveGuideRect` of the new stage, as `guide_and_rule` reads it; AC-3.4). `pick_synthetic_photo` and `pick_photo` gain an `input:` keyword (a CSS selector, default `"[data-card-reader-target=picker]"`, which finds the stage notice's input first; `pick(event)` reads whichever fired by `event.target`). Move `expect_one_screen` into `ScannerHelpers` as `expect_one_screen(viewport_height)` so the three files share it (a YARD summary; it uses `expect`, which `ScannerHelpers` has in system examples).

Run `bin/rspec spec/system/scanner_result_spec.rb spec/system/scanner_page_spec.rb spec/system/scanner_spec.rb spec/system/scanner_detection_spec.rb`: green; in `scanner_detection_spec.rb` the no-edge example's `.c-scanner__status` becomes `#status` (AC-4.9). Prove AC-4.1 by deleting `this.frozenTarget.hidden = false` once (red). Commits: `test(scanner): results in the pane (#344)` (T4.1, red, with `Ruling:` none) is folded into `feat(scanner): capture freezes, a result opens the pane, Scan again returns (#344)`.

---

## Phase 5: The sitting's answers

**Implements:** FR-4, FR-5; decisions 9, 10, 12, 15 · **Satisfies:** AC-2.3, AC-2.5, AC-4.7, AC-4.8, AC-5.1 to 5.6, AC-6.2 to 6.5
**Files:** `app/controllers/concerns/scanner_sitting.rb`, `app/controllers/scanner/sittings_controller.rb`, `scanner/sittings/entries_controller.rb`, `scanner/sittings/entries/undos_controller.rb`, `app/controllers/scanners_controller.rb`, `app/javascript/controllers/sitting_focus_controller.js`, `app/helpers/scanners_helper.rb`, request and system specs

### T5.1 The streams (request specs first)

In `spec/requests/scanner/sitting_entries_spec.rb`, `sittings_spec.rb` and the undo examples (wherever they assert `turbo-stream[target="status"]` or `scanner_sitting`), change the assertions to the new targets. The shapes to assert (Nokogiri on `response.body`):

- An add: `turbo-stream[action=update][target=scanner_result]` empty; `[action=update][target=status]` empty; `[action=update][target=scanner_status_text]` empty; `[action=update][target=scanner_added_text]` whose template's text is "Added Lightning Bolt MOM · 123, foil"; `[action=replace][target=scanner_added_action]` holding a form to the entry's undo path and `data-sitting-focus-to-value="main"`; replaces of `scanner_sitting`, `scanner_sitting_bar`, `scanner_count` (aria-label "1 added. Show this sitting's cards."); an update of `scanner-sitting-heading` with "This sitting: 1 card".
- A replay of an undone add: `scanner_result` emptied, `status` holding "You added this card, then undid it. Scan it again to add it." (alert), no `scanner_added_text`.
- A refused add: 422, one stream, `status`, "That card couldn't be added. Scan it again." (unchanged).
- "Set": `scanner_destination_status` holding "Cards you scan now: Near mint, in Blue binder."; `scanner_picker` replaced with `data-sitting-focus-to-value="set"`; the bar's value "Blue binder · NM"; no `status` stream.
- An Undo: `scanner_list_status` and `scanner_added_text` holding "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection."; `scanner_added_action` replaced empty; `scanner_sitting` with `data-sitting-focus-to-value="heading"`.
- An escaping check: a location named `<b>bold</b>` makes the heading's update template contain `&lt;b&gt;`, never `<b>`.

Red. In `ScannerSitting` replace `sitting_stream` with:

```ruby
    # The streams that redraw what shows the sitting (spec 082 decisions 7 to 9): the list's entries, the list sheet's title, the
    # top bar's destination and Done, the count. `focus` (:heading after an Undo) is where focus goes once the entries connect
    # (spec 047 decision 2; spec 082 decision 15). Texts go through html_escape: a stream's string is used as HTML.
    def sitting_redraw(focus: nil)
      locals = sitting_locals
      [ turbo_stream.replace("scanner_sitting", partial: "scanners/sitting", locals: locals.slice(:sitting, :entries, :conditions, :added_any).merge(focus:)),
        turbo_stream.update("scanner-sitting-heading", ERB::Util.html_escape(helpers.sitting_title(locals[:sitting], locals[:entries], locals[:conditions]))),
        turbo_stream.replace("scanner_sitting_bar", partial: "scanners/sitting_bar", locals: locals.slice(:sitting, :conditions)),
        turbo_stream.replace("scanner_count", partial: "scanners/count", locals: { count: locals[:entries].size }) ]
    end

    # The destination sheet's form, redrawn after a "Set" with focus back on "Set" (spec 047 decision 2).
    def picker_redraw(focus: :set)
      sitting = Current.account.scanner_sitting
      turbo_stream.replace("scanner_picker", partial: "scanners/picker",
        locals: { condition: sitting&.condition, location_id: sitting&.location_id, conditions: scanner_conditions, choices: account_choices, focus: })
    end

    # A sentence in one of the page's live regions (spec 082 decision 10's table): never empty, so every redraw is announced
    # (spec 047 FR-1).
    def say_in(region, message, alert: false)
      turbo_stream.update(region, partial: "shared/status_message", locals: { message:, alert: })
    end

    # The after-add line's sentence and its action: Undo for `entry`, or nothing (spec 082 decision 12).
    def added_line(message, entry: nil, focus: nil)
      [ turbo_stream.update("scanner_added_text", ERB::Util.html_escape(message)),
        turbo_stream.replace("scanner_added_action", partial: "scanners/added_action", locals: { entry:, focus: }) ]
    end
```

(`sitting_locals` called with no argument reads `Current.account.scanner_sitting`, as `sitting_stream` did.) The module's header comment: "…and the streams that redraw it after a change, into the regions spec 082 decision 10 names."

`EntriesController#create` (header comment: "Every answer is a Turbo Stream (AC-1.3); an add returns the shell to the camera with the after-add line (spec 082 decision 12)."):

```ruby
  def create
    attributes = params.expect(entry: %i[printing finish reading_key])
    printing = Catalog::Entry.includes(:set).find_by(external_key: attributes[:printing].to_s)
    entry = Scanner::Sitting.add!(account: Current.account, printing:, finish: attributes[:finish], reading_key: attributes[:reading_key]).entry
    render turbo_stream: [ turbo_stream.update("scanner_result", ""), *answer_for(entry), *sitting_redraw ]
  rescue Scanner::Sitting::Refused
    refuse NOT_ADDED
  rescue ActiveRecord::RecordInvalid
    refuse Catalog::QuickAddsController::FULL_LOT
  end

  private
    # An add empties the pane and the status line and says so on the after-add line, focus on the main button; a replay of an
    # undone or changed entry keeps the pane open with its sentence and no add button (spec 009 AC-1.5; spec 082 AC-4.8).
    def answer_for(entry)
      return [ say_in("status", REPLAYED.fetch(entry.state), alert: true) ] unless entry.state == :added

      [ turbo_stream.update("status", ""), turbo_stream.update("scanner_status_text", ""),
        *added_line(helpers.scanner_added(entry.printing, entry.finish), entry:, focus: :main) ]
    end

    def refuse(message)
      render turbo_stream: say_in("status", message, alert: true), status: :unprocessable_content
    end
```

`message_for` and `result_stream` go (their sentences are superseded, spec 082 Supersedes; the condition and place are the top bar's). `UndosController#create`: `render turbo_stream: [ say_in("scanner_list_status", message), *added_line(message), *sitting_redraw(focus: :heading) ]` with `message = "Removed 1 × #{copy} from your collection."`, and the refusal likewise with `alert: true` and status 422. `SittingsController#update`: `render turbo_stream: [ say_in("scanner_destination_status", chosen_message(…)), picker_redraw, *sitting_redraw ]`; `refuse(message)` = `render(turbo_stream: [ say_in("scanner_destination_status", message, alert: true), picker_redraw ], status: :unprocessable_content)`. Green. Commit `feat(scanner): the sitting's answers write the new regions (#344)`.

### T5.2 Focus after a redraw

`sitting_focus_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

// Puts keyboard focus back after a redraw (spec 047; spec 082 decision 15). The server names where ("set", "heading" or "main")
// on the redrawn part; it is focused once, and the value is removed so a reconnect can't focus again. "heading" is the list
// sheet's title while that sheet is open; an Undo from the after-add line leaves it closed, so focus goes to the main button,
// as it does after an add, whose button the redraw removed. A page render names nothing. Without script only focus is lost.
export default class extends Controller {
  static targets = [ "set" ]
  static values = { to: String }

  connect() {
    this.target?.focus()
    this.element.removeAttribute("data-sitting-focus-to-value")
  }

  get target() {
    const main = document.querySelector("[data-scan-main]")
    if (this.toValue === "set") return this.setTargets[0]
    if (this.toValue === "main") return main
    if (this.toValue === "heading") {
      const heading = document.getElementById("scanner-sitting-heading")
      return heading?.closest("dialog")?.open ? heading : main
    }
    return null
  }
}
```

(`_sitting.html.erb` no longer carries a `heading` target.) `ScannersHelper#sitting_focus_data`'s comment: "`focus` is :set, :heading or :main, a word of ours". No test of its own here: T5.3's system examples assert focus. Commit with T5.3.

### T5.3 The sitting's system examples

Rewrite `spec/system/scanner_sitting_spec.rb` and `scanner_adding_spec.rb` to the new page, keeping each example's criterion and its assertions' meaning, with the selector map and these helpers in `scanner_sitting_spec.rb`:

```ruby
  def set_sitting(condition: nil, location: nil)
    open_destination unless page.has_css?("dialog#scanner_destination_sheet[open]", wait: 0)
    select condition, from: "Condition" if condition
    select location, from: "Location" if location
    click_on "Set"
  end

  def list_heading = find("#scanner-sitting-heading", visible: :all).text(:all)
```

The changes example by example (the criterion in each description stays):

| Example | Change |
|---|---|
| "survives signing out…" (AC-3.3) | `#scanner_sitting` text → `expect(page).to have_button("1 added. Show this sitting's cards.")`, then "2 added" |
| "undoes an add in place…" (AC-4.1) | `click_on "Undo"` is the after-add line's; `#status` → `#scanner_added_text` ("Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection."); add `expect(page.evaluate_script("document.activeElement.dataset.scanMain")).to eq("")` (AC-5.3) |
| place: "opens a sitting in the chosen place…" | `open_destination` first; `#scanner_sitting h2` → `list_heading`; `#status` → `#scanner_destination_status`; `.c-scanner__stage video` → `.c-scan__feed video`; add `expect(page).to have_css(".c-scan__dest", text: "Blue binder")` (AC-2.3) |
| place: "scans into the place…" | the add's sentence → `#scanner_added_text`, "Added Lightning Bolt MOM · 123, foil"; close the sheet (`find("dialog[open]").send_keys(:escape)`) before `add_by_scanning`; `entry_metas` read after `open_sitting_list` |
| place: "keeps the place on a reload…" (incl. Done, End sitting) | `have_select` after `open_destination`; after "End sitting", `#scanner_added_text` "Added 1 card in this sitting." and `have_link("Open your collection")` (AC-5.6); the top bar "No location" |
| "chooses a place with the keyboard alone" (AC-7.1) | `open_destination` first, then as today |
| "fits a 360px screen with a long location name" | `open_scanner_frame(width: 360, height: 640)`, `open_destination`; assert `page_fits_sideways?` and the dest text ends in an ellipsis: `page.evaluate_script("(() => { const t = document.querySelector('.c-scan__dest-text'); return t.scrollWidth > t.clientWidth })()")` is true (AC-1.4) |
| "fits a 360px screen with a long sitting" | `open_scanner_frame(width: 360, height: 640)`, `open_sitting_list`, `page_fits_sideways?`, `expect_one_screen(640)` |
| condition: the four examples | as the place ones; `entry_metas` after `open_sitting_list` |
| "fits 390px and a desktop width with both selects…" | `open_scanner_frame(width: 390, height: 844)`, `open_destination`, the selects' right edges against `#scanner_destination_sheet`'s |
| focus: "puts focus back on Set…" | `open_destination` first; `#status` → `#scanner_destination_status`; `set_focused` → `have_css("#scanner_picker input[type=submit][value=Set]:focus")`; `mark_stale` marks `#scanner_picker` |
| focus: "puts focus on Set, with the status, when Set opens…" | as above; "deletes an empty one" asserts the top bar has no Done |
| focus: "puts focus on the heading after a keyboard Undo…" | `open_sitting_list` first; `#status` → `#scanner_list_status`; `#scanner_sitting h2:focus` → `#scanner-sitting-heading:focus` |

Add to `scanner_sitting_spec.rb`:

```ruby
  it "shows the add on the after-add line with Undo, the camera live (AC-5.1, AC-5.5, decision 15)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    expect(page).to have_css("#scanner_added_text", exact_text: "Added Lightning Bolt MOM · 123, foil")
    expect(page).to have_css(".c-scan__line--added:not([hidden]) .c-scan__added-action button", text: "Undo")
    expect(page).to have_css(".c-scan__line--status[hidden]", visible: :all)
    expect(page).to have_no_css(".c-scan--result")
    expect(page).to have_button("Capture", disabled: false)
    expect(page.evaluate_script("document.activeElement.hasAttribute('data-scan-main')")).to be(true)
    expect(page).to have_css(".c-scan__done", text: "Done")
    page.execute_script("window.__added = document.getElementById('scanner_added_text')")
    add_by_scanning
    expect(page.evaluate_script("window.__added === document.getElementById('scanner_added_text')")).to be(true)
  end

  it "returns focus to the destination after a Set redrew it while the sheet was open (decision 15, AC-2.4)", :aggregate_failures do
    visit scanner_path
    find(".c-scan__dest").send_keys(:enter)
    select "Near mint (NM)", from: "Condition"
    click_on "Set"
    expect(page).to have_css(".c-scan__dest", text: "No location · NM")
    find("dialog[open]").send_keys(:escape)
    expect(page.evaluate_script("document.activeElement.classList.contains('c-scan__dest')")).to be(true)
  end

  it "empties the after-add line on the next capture (AC-5.4)", :aggregate_failures do
    visit scanner_path
    add_by_scanning
    expect(page).to have_css("#scanner_added_text", text: "Added")
    click_on "Capture"
    expect(page).to have_css(".c-scan__line--added[hidden]", visible: :all)
    expect(page).to have_css(".c-scan__line--status:not([hidden])")
  end
```

`scanner_adding_spec.rb`: the selector map; the add's `#status` sentences become `#scanner_added_text` (the short sentence); "the add failed on the network" and "Other printings … are below." stay on `#status`; AC-4.8 (a replay of an undone reading) asserts `#status` holds the sentence and `.c-scanner__add` is gone. `scanner_timing_spec.rb`: "from tapping Foil to `#scanner_added_text` changing". Run all scanner system specs: green. Commit `test(scanner): the sitting on the one-screen page (#344)` with T5.2's controller as `feat(scanner): focus after a redraw on the one-screen page (#344)` first.

### T5.4 The flash and the end of a sitting

`ScannersController`:

```ruby
  def show
    @sitting = sitting_locals(current_sitting)
    @line = scanner_line
    @unloaded_catalogs = Catalog.unloaded_titles
    @catalogs_named = Catalog.sources.many?
  end

  private
    # What the after-add line shows on a page load (spec 082 decision 10): the end of a sitting's summary with a link to the
    # collection (spec 009 AC-3.5), or a flash from a page the scanner was left for (Edit copy), with its Undo; else nothing.
    def scanner_line
      if (count = flash[:sitting_summary])
        { message: "Added #{helpers.pluralize(count, "card")} in this sitting.", link: [ "Open your collection", collection_path ] }
      elsif (message = flash[:alert] || flash[:notice])
        { message:, alert: flash[:alert].present?, removal_undo: (flash[:undo] unless flash[:alert]) }
      end
    end
```

Request example in `spec/requests/scanners_spec.rb`: after `post scanner_sitting_ending_path` (with a sitting of one entry) and following the redirect, `#scanner_added_text` reads "Added 1 card in this sitting." and `#scanner_added_action a` is "Open your collection" (AC-5.6); with `flash[:notice]` set by a lot update that returns to the scanner (`patch lot_path(lot, return_to: scanner_path)` as `lots_spec.rb` does), the text is that notice (AC-6.4). Commit `feat(scanner): the flash and the end of a sitting on the after-add line (#344)`.

---

## Phase 6: The other states, the old CSS, the touch floor, the footer

**Implements:** decisions 14, 16, 22, 23; Error Scenarios · **Satisfies:** AC-1.9, AC-4.9, the engine-failed row of AC-1.2
**Files:** `spec/system/scanner_spec.rb`, `scanner_page_spec.rb`, `small_controls_touch_floor_spec.rb`, `footer_spec.rb`, `spec/requests/footer_spec.rb`, `spec/requests/scanners_spec.rb`, `additions.css`

### T6.1 The stage notices

`scanner_spec.rb`'s HTTPS and blocked-camera examples assert the reason inside `.c-scan__notice:not([hidden])`, the notice's "Use a photo" (`within(".c-scan__notice") { expect(page).to have_field("Use a photo", type: "file", visible: :all, disabled: false) }`), and the one-screen measures (`expect_one_screen(page.evaluate_script("window.innerHeight"))` in the window). New examples in `scanner_page_spec.rb`:

```ruby
  [ [ 390, 844 ], [ 360, 640 ], [ 360, 560 ] ].each do |width, height|
  it "shows the engine's failure as a stage notice, the main button in view at #{width} × #{height} (Error Scenarios, AC-1.2)", :aggregate_failures do
    open_scanner_frame(width:, height:)
    within_narrow_frame do
      page.execute_script(<<~JS)
        const reader = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(".c-scan"), "card-reader")
        reader.enginePathValue = "/ocr/missing"
        window.__loadEngineFails = true
      JS
      page.execute_script("window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('.c-scan'), 'card-reader').retryEngine()")
      expect(page).to have_css(".c-scan__notice:not([hidden])", text: "The scanner couldn't load", wait: 30)
      expect(page).to have_button("Load the scanner again")
      expect(page).to have_button("Capture", disabled: true)
      expect_one_screen(height)
    end
  end
  end

  it "says the catalog isn't loaded on a line at the stage's foot (Error Scenarios, decision 14)", :aggregate_failures do
    visit scanner_path # no catalog refresh has run in this example
    expect(page).to have_css(".c-scan__catalog #catalog_not_loaded", text: "The card catalog hasn't been loaded yet.")
    expect(page).to have_button("Capture", disabled: false, wait: 30)
  end
```

(If `retryEngine` reuses a worker the second load does not fail, fail the load instead by stubbing `window.Tesseract.createWorker` to reject before `retryEngine`, and record the choice as a `Ruling:`. `Catalog.unloaded_titles` is non-empty in an example that ran no refresh; check `spec/requests/scanners_spec.rb`'s existing not-loaded example for the factory that marks a catalog loaded, and use its absence.) Commit `test(scanner): the stage notices on the one-screen page (#344)`.

### T6.2 The `c-scanner` rules the page no longer uses

For each rule in `additions.css` lines 260 to 301 (as of `main` at `c91cf71b`), grep `app/views app/javascript spec` for its class (`git grep -n "<class>" -- app spec ':!.kamal/secrets'`). Remove exactly the rules whose class no file uses any more; the expected set is `.c-scanner` (the root rule), `.c-scanner__stage` (both lines), `.c-scanner [hidden]`, `.c-scanner__video`, `.c-scanner__guide` (both lines), `.c-scanner__controls`, `.c-scanner__shutter` (and its name in the 44px rule, which keeps `.c-scanner__photo`), `.c-scanner__torch`, `.c-scanner__unavailable` (keeping `.c-scanner__failure` in that rule), and `.c-scanner__note` if unused. Two stay: `.c-scanner__status` (`app/views/scanner/measurements/replays/show.html.erb` uses it) and the `@media (prefers-reduced-motion: reduce) { .c-scanner * … }` rule, which the frozen reduced-motion block's comment names; it matches nothing now and costs nothing (`Ruling:` in the commit body). Run `spec/design_system_files_spec.rb`, `spec/system/design_system_scanner_components_spec.rb` and the scanner system specs: green. Commit `refactor(css): drop the scanner rules the one-screen page replaced (#344)`.

### T6.3 The touch floors

`small_controls_touch_floor_spec.rb`: `page_rule_scopes` gains `.c-scan .c-sheet`; the scanner row becomes `"scanner" => { path: scanner_path, wide: [ [ "#scanner_sitting .c-btn--sm", "Undo" ], [ "#scanner_sitting .c-btn--sm", "Details" ], [ "#scanner_sitting summary.c-btn--sm", "Show all" ], [ "#scanner_picker .c-btn--sm", "Set" ] ] }` (Done is the top bar's 44px `c-scan__done`, not a small control); `settle(name)` for the two scanner pages waits for `.c-scan__feed:not([hidden])` and then shows every sheet without a modal so their controls are drawn (`page.execute_script("document.querySelectorAll('dialog.c-sheet').forEach((sheet) => sheet.show())")`; this spec measures sizes, not overlap). The scanner's sitting has entries in `make_fixtures` already. Add an example, "the one-screen scanner's controls are 44px at every pointer (spec 082 AC-1.9)", which, without the coarse injection, measures `.c-scan__back, .c-scan__dest, .c-scan__done, #scanner_count, .c-scan__main, .c-scan__torch, dialog .c-btn` on the scanner with both sheets shown and asserts each drawn one is at least 44 × 44. The sheets' selects are not in that list: they are 36px on a fine pointer by spec 072's rule and meet the floor on a coarse one (`Ruling:` in the commit body, AC-1.9's "every control" read with spec 072's exception).

`spec/system/select_touch_floor_spec.rb`: its `settle` waits for `.c-scan__feed:not([hidden])` (line 91) and, since the selects now sit in sheets, opens one sheet per page name with `document.getElementById(id).showModal()`: on the scanner `#scanner_destination_sheet` (its selects), on measurement mode `#measurement_sheet` (the card-to-capture select; the destination sheet's selects are the scanner row's). A modal sheet covers the bottom bar, so for these two pages the overlap check (AC-1.4) is scoped to the open sheet: `layout_report(roots: [ "dialog[open]" ])` (`spec/support/coarse_pointer.rb:75`). Measurement mode's rows in both touch-floor specs are red from T6.3 until T7.2 builds its sheet (declared in the commit body). Run both files and the full scanner set: green. Commit `test(scanner): the touch floors on the one-screen page (#344)`.

---

## Phase 7: Measurement mode and the framing

**Implements:** FR-6; decisions 5, 23 (spec patch 1.0.2) · **Satisfies:** AC-7.1, AC-7.2, AC-7.4's tooling
**Files:** `app/models/scanner/measurement_run.rb`, `app/controllers/concerns/measurement_mode.rb`, `app/controllers/scanner/measurements_controller.rb`, `scanner/measurements/captures_controller.rb`, `scanner/measurements/framings_controller.rb`, `scanner/readings_controller.rb`, `config/routes.rb`, the measurement views, `measurement_controller.js`, `lib/collector/scanner_findings/paired_report.rb`, `lib/tasks/scanner.rake`, specs

### T7.1 A run per framing (model first)

`spec/models/scanner/measurement_run_spec.rb` gains:

```ruby
  describe ".current" do
    around do |example|
      Rails.configuration.x.scanner_measurement = { manifest: "/tmp/m.csv", dir: "/tmp/runs/live" }
      example.run
    ensure
      Rails.configuration.x.scanner_measurement = nil
    end

    it "stores each framing's run in a directory of its own, and the configured one with none (spec 082 decision 5)", :aggregate_failures do
      expect(described_class.current(framing: "full").dir.to_s).to eq("/tmp/runs/live/full")
      expect(described_class.current(framing: "shipped").dir.to_s).to eq("/tmp/runs/live/shipped")
      expect(described_class.current.dir.to_s).to eq("/tmp/runs/live")
      expect { described_class.current(framing: "wide") }.to raise_error(ArgumentError)
    end
  end
```

and an example that `record!` keeps `video_width`, `video_height`, `stage_width`, `stage_height` and `framing` from `extra` (integers and the framing word). Red. In `MeasurementRun`:

```ruby
  # The two framings a paired re-measure compares (spec 082 decision 5): the live guide, and the shipped card size in the tall
  # stage. Each stores its run under `<dir>/<framing>`.
  FRAMINGS = %w[full shipped].freeze
  # … EXTRA_FIELDS gains video_width video_height stage_width stage_height framing (spec 082 AC-7.2) …

  # The configured run, or the run of one framing (spec 082 decision 5). With no framing, the configured directory itself, which
  # is what the findings tasks of earlier specs score.
  #
  # @param framing [String, nil] "full" or "shipped"
  # @return [Scanner::MeasurementRun, nil] nil when measurement mode is off
  # @raise [ArgumentError] for any other framing
  def self.current(framing: nil)
    config = Rails.configuration.x.scanner_measurement
    return unless config.present?
    raise ArgumentError, "Unknown framing #{framing.inspect}" if framing && !FRAMINGS.include?(framing)

    dir = Pathname(config.fetch(:dir))
    new(manifest: config.fetch(:manifest), dir: framing ? dir.join(framing) : dir)
  end
```

Green. Commit `feat(scanner): a measured run per framing (#344)`.

### T7.2 The framing in the session; the page on the shell (request first)

`spec/requests/scanner/measurements_spec.rb` gains: `patch scanner_measurement_framing_path, params: { framing: "shipped" }` redirects (303) to `scanner_measurement_path`, and the page then renders `.c-scan[data-camera-framing-value="shipped"]` and the run button's text ends "· shipped"; `framing: "wide"` answers 422; with measurement mode off the route answers 404; a capture posted after choosing "shipped" lands under `<dir>/shipped/<file>/capture-001.json` and records `"framing" => "shipped"`; a reading posted to `scanner_readings_path` in the same session writes `<dir>/shipped/readings.jsonl`; the scanner's own page renders `data-camera-framing-value="full"` whatever the session holds. Red. Then:

- `config/routes.rb`, inside the measurement scope: `resource :framing, only: :update`.
- `app/controllers/scanner/measurements/framings_controller.rb`:

```ruby
# Chooses which framing measurement mode draws, crops and stores under (spec 082 decision 5): the live guide ("full") or the
# shipped card size in the tall stage ("shipped"), kept in the session so every later write of the paired run reaches its run.
class Scanner::Measurements::FramingsController < ApplicationController
  include MeasurementMode

  def update
    framing = params.expect(:framing).to_s
    return head(:unprocessable_content) unless Scanner::MeasurementRun::FRAMINGS.include?(framing)

    session[:scanner_framing] = framing
    redirect_to scanner_measurement_path, status: :see_other
  end
end
```

- `Scanner::MeasurementRun.framing_in(session)` (a class method with a YARD summary: the session's framing when it is one of `FRAMINGS`, else "full", spec 082 decision 5; the one rule both callers use). `MeasurementMode`: `def measurement_framing = Scanner::MeasurementRun.framing_in(session)` and `measurement_run` becomes `Scanner::MeasurementRun.current(framing: measurement_framing)`; `panel_locals` gains `framing: measurement_framing`; `render_panel` also replaces `measurement_run_button` with `partial: "scanner/measurements/run_button", locals: panel_locals(...)`.
- `Scanner::ReadingsController#record_measurement`: `Scanner::MeasurementRun.current(framing: Scanner::MeasurementRun.framing_in(session))&.record_reading!(key, reading)` (`current` is nil with the mode off; `MeasurementMode` is not included here, since it 404s when the mode is off, and the reading's route must not).
- `CapturesController`: permit `video_width video_height stage_width stage_height`, and `extra` gains those four as integers (`.presence&.to_i`) and `"framing" => measurement_framing` (the server's, never the client's).
- Views. `scanner/measurements/show.html.erb`:

```erb
<% content_for :title, "Measure the scanner · Collector" %>
<% content_for :focused, "true" %>
<%= render "scanners/head" %>
<% if @manifest_problem %>
  <main class="c-scan">
    <h1 class="c-sr">Measure the scanner</h1>
    <div class="c-scan__top"><%= link_to scanner_path, class: "c-scan__back", "aria-label": "Back" do %><%= render "icons/back" %><% end %></div>
    <div class="c-scan__stage"><div class="c-scan__notice"><p class="c-scan__notice-text"><%= @manifest_problem %> Measurement mode can't start. The scanner itself is unaffected.</p></div></div>
  </main>
<% else %>
  <%= render "scanners/scanner", **@sitting, heading: "Measure the scanner", measurement: @panel, framing: @panel[:framing] %>
<% end %>
```

  (the broken-manifest page has no camera controller, so no camera is requested, decision 23.) `_run_button.html.erb`:

```erb
<%# locals: (run:, next_row:, framing:, **) %>
<%# Measurement mode's top-bar button (spec 082 decision 5): the next row, the count and the framing, redrawn with every stored
    capture, so the row is in view while capturing; it opens the run's sheet. %>
<%= tag.button type: "button", id: "measurement_run_button", class: "c-btn c-btn--secondary c-scan__run", data: { action: "sheets#open", sheets_id_param: "measurement_sheet" } do %>
  <%= [ next_row&.file || "All done", "#{run.counts.fetch(:captured, 0)} of #{run.rows.size}", framing ].join(" · ") %>
<% end %>
```

  `_run_sheet.html.erb`: a `dialog.c-sheet#measurement_sheet` titled "Measured run", with the `click->sheets#backdrop close->sheets#closed` actions, its locals `(run:, next_row:, expected:, keep_frames:, notice:, alert:, framing:)`, its body holding `render "scanner/measurements/panel", run:, next_row:, expected:, keep_frames:, notice:, alert:, framing:`, then the framing switch:

```erb
    <div class="c-scan__framing">
      <%= button_to "Full framing", scanner_measurement_framing_path, method: :patch, params: { framing: "full" }, class: "c-btn c-btn--secondary", disabled: framing == "full", form: { data: { turbo: false } } %>
      <%= button_to "Shipped framing", scanner_measurement_framing_path, method: :patch, params: { framing: "shipped" }, class: "c-btn c-btn--secondary", disabled: framing == "shipped", form: { data: { turbo: false } } %>
    </div>
```

  then the notice's foot (`render "layouts/notice_foot"`). `_panel.html.erb`'s locals gain `framing:` (unused in its body), and its status paragraph (`data-measurement-target="status"`) gains `role="status" aria-live="polite"`, the run sheet's live region (FR-4); the panel is replaced on each answer, so the top-bar button's new row and count are what the collector reads at a glance (spec patch 1.0.2).
- The CSS block gains `.c-scan__run { box-sizing:border-box; flex:none; min-height:44px; max-width:40%; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }` and `.c-scan__framing { display:flex; flex-wrap:wrap; gap:var(--space-2); margin-top:var(--space-4); }`.
- `measurement_controller.js`: `store` appends `capture[video_width]` and the three others from `detail.sizes` when present; `post()`'s failure also writes the failure sentence into the pane's region (`document.getElementById("status")?.replaceChildren(paragraph)`, the alert style), spec patch 1.0.2.

`spec/requests/footer_spec.rb` line 230: the measurement page now has no footer and three sheet feet; the replay page keeps its footer. `scanner_measurement_spec.rb`: the stored notice is asserted in the open run sheet (`find("#measurement_run_button").click`) and as the run button's new text ("All done · 1 of 1 · full"); its Undo is the after-add line's and its sentence `#scanner_added_text`. Green. Commit `feat(scanner): measurement mode on the shell, with the framing in the session (#344)`.

### T7.3 The paired findings

`spec/lib/collector/scanner_findings/paired_report_spec.rb` (no browser): build two runs in a temporary directory with `MeasurementRun#record!` (two rows, the full run reading both names, the shipped run one, the strips any tiny PNG as the model spec's helper makes them), a ground truth of the two printings (`ScannerFindings.ground_truth` from a manifest, as the existing reports' specs do), and assert: `to_markdown` has a table with one column per framing and rows "right card first", "top 3", "exact printing", "name read"; the discordant list names the row the shipped run missed; `bar` returns `:passes` for full 2/2 against shipped 1/2 and `:fails` for full 0/2 against shipped 2/2; a third row measured only by the full run is in `unpaired` and in no rate. Red. Then:

```ruby
module Collector
  module ScannerFindings
    # Spec 082 Story 7: the paired re-measure. Scores each framing's run (its first capture per row) against the ground truth,
    # lists the cards one framing got right first and the other didn't, and applies bar A: the full framing passes when its
    # right card first is at most one card below the shipped framing's and its exact printing at most two below (maintainer,
    # 2026-11-13). Text is re-ranked as `rescore` does; where the run recorded readings (art matching on), the first candidate
    # as recorded is the right-card-first figure the bar reads.
    class PairedReport
      RIGHT_FIRST_SLACK = 1
      EXACT_PRINTING_SLACK = 2

      # @param runs [Hash{String => Scanner::MeasurementRun}] "full" and "shipped"
      # @param truth [Hash{String => Hash}] ground-truth records by file
      def initialize(runs:, truth:)
        @runs = runs
        @truth = truth
      end

      # Each framing's scored records for the cards both framings measured (bar A compares the same cards): `right_first` from
      # the recorded first candidate where readings were recorded, else the re-ranked text's.
      #
      # @return [Hash{String => Array<Hash>}]
      def records
        @records ||= all_records.transform_values { |rows| rows.select { shared.include?(it["file"]) } }
      end

      # Files one framing measured and the other didn't, left out of the comparison and listed in the report.
      #
      # @return [Array<String>]
      def unpaired = all_records.values.flat_map { |rows| rows.map { it["file"] } }.uniq - shared.to_a

      # Whether the full framing passes bar A on the shared cards.
      #
      # @return [Symbol] :passes or :fails
      def bar
        full, shipped = records.values_at("full", "shipped")
        right = ->(rows) { rows.count { it["right_first"] } }
        exact = ->(rows) { rows.count { SET_LINE_ERAS.include?(it["era"]) && ScannerFindings.printing_identified?(it) } }
        right.(full) >= right.(shipped) - RIGHT_FIRST_SLACK && exact.(full) >= exact.(shipped) - EXACT_PRINTING_SLACK ? :passes : :fails
      end

      # The shared cards one framing put right first and the other didn't, with which.
      #
      # @return [Array<String>]
      def discordant
        full = records["full"].to_h { [ it["file"], it["right_first"] ] }
        records["shipped"].filter_map do |record|
          next if full[record["file"]] == record["right_first"]

          "#{record["file"]}: #{full[record["file"]] ? "full" : "shipped"} only"
        end
      end

      # The report for research.md: a table per framing (right card first, top 3, exact printing with its foil and non-foil
      # split, name read), the frame and stage sizes seen, the discordant and unpaired cards, and bar A's outcome.
      #
      # @return [String]
      def to_markdown
        rows = { "right card first" => ->(r) { r["right_first"] }, "top 3" => ->(r) { ScannerFindings.in_top?(r, "final_candidates", 3) },
                 "name read" => ->(r) { ScannerFindings.name_read?(r) } }
        table = rows.map { |label, hit| "| #{label} | #{records.values.map { ScannerFindings.rate(it, &hit) }.join(" | ")} |" }
        exact = [ [ "exact printing", ->(_) { true } ], [ "  foils", ->(r) { r["foil"] } ], [ "  non-foils", ->(r) { !r["foil"] } ] ].map do |label, kind|
          "| #{label} | #{records.values.map { |rows_of| ScannerFindings.rate(rows_of.select { SET_LINE_ERAS.include?(it["era"]) && kind.(it) }) { ScannerFindings.printing_identified?(it) } }.join(" | ")} |"
        end
        sizes = records.transform_values { |rows_of| rows_of.map { it["sizes"].values.join("×") }.uniq.join(", ") }
        [ "| Rate | #{records.keys.join(" | ")} |", "|---|#{"---|" * records.size}", *table, *exact, "",
          "Sizes (video × stage): #{sizes.map { |framing, seen| "#{framing} #{seen}" }.join("; ")}.",
          "Discordant: #{discordant.join("; ").presence || "none"}.", "Unpaired (left out): #{unpaired.join(", ").presence || "none"}.", "", "Bar A: #{bar}." ].join("\n")
      end

      private
        # Every measured row of each framing, scored.
        def all_records
          @all_records ||= @runs.transform_values do |run|
            recorded = run.readings.to_h { [ it["reading_key"], it["candidates"].to_a.first ] }
            ScannerFindings.rescore(@truth, run.measured_captures).map do |record|
              capture = run.measured_captures.find { it["file"] == record["file"] }
              first = recorded[capture&.dig("reading_key")]
              record.merge("right_first" => first ? Catalog::Entry.find_by(external_key: first)&.name == record["name"] : ScannerFindings.in_top?(record, "final_candidates", 1),
                "sizes" => capture.to_h.slice("video_width", "video_height", "stage_width", "stage_height"))
            end
          end
        end

        # The files both framings measured.
        def shared = @shared ||= all_records.values.map { |rows| rows.to_set { it["file"] } }.reduce(:&)
    end
  end
end
```

`lib/tasks/scanner.rake`:

```ruby
  desc "Spec 082 AC-7.4: the paired re-measure, each framing's run against GROUND_TRUTH, the cards one framing got right and the other didn't, and bar A"
  task paired_findings: :environment do
    runs = Scanner::MeasurementRun::FRAMINGS.to_h { [ it, Scanner::MeasurementRun.current(framing: it) ] }
    abort "Measurement mode is off; run this in development." if runs.values.any?(&:nil?)
    truth = JSON.parse(Pathname(ENV.fetch("GROUND_TRUTH")).expand_path.read).fetch("photos").to_h { [ it["file"], it ] }
    puts Collector::ScannerFindings::PairedReport.new(runs:, truth:).to_markdown
  end
```

and the other run-scoring tasks read `Scanner::MeasurementRun.current(framing: ENV.fetch("FRAMING", "full").presence)` (`FRAMING=` named in each `desc`: unset scores `<dir>/full`, as measurement mode now writes; `FRAMING=` empty scores the configured directory itself, where the runs of specs 007 to 011 are; a `Ruling:` in the commit body). The example also asserts a file only one framing measured is listed as unpaired and left out of `bar`. Green. Commit `feat(scanner): the paired re-measure's findings (#344)`.

---

## Phase 8: Documents, evidence, verification, push

**Implements:** NFR Documentation; Verification · **Satisfies:** the document criteria; AC-1.8 (by reading)

- [ ] **T8.1 Area docs** (`.claude/rules/documentation.md`; each new statement with its source inline). `docs/architecture/scanner.md`: Scope (the new controllers `scan-shell`, `sheets`; the measurement framing), States and transitions rewritten for the page (the shell, the two sheets, decision 10's table, the frozen frame, "Scan again", the after-add line, the flash line, the stage notices), Invariants ("The scanner's accessibility bars" gains the one-screen rule and the sheets' regions; "Redraws are announced" names the regions), Named constants (`LIVE_GUIDE` with decision 2's rule and numbers; `GUIDE`, `STAGE_ASPECT` "the shipped framing, the photo path's"; `MeasurementRun::FRAMINGS`), Decisions not in an ADR (decisions 2, 3, 13; the landscape limit as an accepted limit), Sources (spec 082), the distillation log is `distill-feature`'s. `catalog-core.md`: the footer's place on the scanner (decision 16; spec 018 FR-2 superseded for it). Commit `docs(architecture): the one-screen scanner (#344)`.
- [ ] **T8.2 Design system** (use the `collector-design-system` skill). `README.md`: Mobile and Hotwire's "no page does yet" becomes "the scanner does (spec 082)"; `components/Scanner.md`: the first section's "Nothing here is live yet" becomes what #344 built and what #345 builds, the markup updated to the page's ids, "Use a photo" in the destination sheet, the stage notice, `c-scanpane__results` as #344's interim, and the "As built" parts this page replaced deleted (spec 080 decision 1); `Sheet.md`: the backdrop tap is the `sheets` controller's, the scanner uses it, its region per sheet; `Footer.md`: "One `<footer>` per page" gains "except a one-screen focused page (the scanner), whose sheets carry the notice (spec 082)". Commit `docs(design-system): the scanner page as built (#344)`.
- [ ] **T8.3 Specs index:** spec 082's row as written, and the "Superseded by" cells of 007, 009, 011, 018, 040, 042 and 047 each gain the part spec 082's Supersedes names ("…: 082 (…)"), both directions. Commit `docs(specs): spec 082's supersessions in the index (#344)`.
- [ ] **T8.4 Screenshots and GIFs** (`.claude/memory/pr-screenshots-workflow.md`, `headless-firefox-narrow-frame.md`): a script under the scratchpad seeds a user, a catalog with Lightning Bolt (two printings), a sitting with three entries in "Blue binder" at Near mint, and art off; it opens the scanner in a 390 × 844 frame from the collection page (phone) and at 1280 × 900 (desktop), light and dark (`data-theme`, a 0.6 s pause after switching), and captures: aiming, a result, after an add, the destination sheet, the list sheet, the camera unavailable. Two GIFs (ffmpeg from frames): capture → result → Add foil → the after-add line; and opening and closing both sheets over the camera. Into `docs/specs/082-scanner-capture-always-in-view/screenshots/`; commit `docs(specs): spec 082 screenshots (#344)`.
- [ ] **T8.5 Verification** `verification.md`: each criterion with its example (file and line) or its reading, AC-1.8 by reading the CSS, the deviations and `Ruling:` lines from the commits, the review rounds. Then ask the coordinator for a CI slot and run `bin/ci` (record the SHA and the counts; "slot released" with the result). Then `sdd-review` Mode B (read-only, Opus) → `## Implementation review` with its verdict on the first line. Then `session-wrap` and `distill-feature`, with the digest sent to the coordinator before it is committed.
- [ ] **T8.6 Push and draft PR:** ask for a slot; `git push -u origin 082-scanner-capture-always-in-view` (the hook runs `bin/ci`); "slot released" with the SHA. Check no PR exists for the branch; the body with the Write tool ("Closes #344.", the summary, the screenshots and GIFs by SHA-pinned `blob/<sha>/…?raw=true` links, what is owed: the re-measure and the screen-reader pass, and the attribution line); `gh pr create --draft --assignee plainprogrammer --body-file <path>` in its own call. The PR stays a draft until Phase 9.

---

## Phase 9: The re-measure (the maintainer; last)

**Implements:** Story 7; decisions 1, 4 · **Satisfies:** AC-7.3 to 7.5
**Needs:** the maintainer, a phone over HTTPS on the LAN (`bin/dev-certificate`, `.claude/memory/phone-lan-dev-access.md`), about 40 owned cards. Nothing above waits on it.

- [ ] **T9.1 Ask** the coordinator for the cards and a time, with the corpus brief (decision 4): about 40 cards, none of spec 007's tuning cards, at least 10 sets, 8 foils, 5 frames that print no set code, a few light names on dark bars; a manifest `file,set,number,foil[,era]` beside them (`file` a label such as `C001`), in a folder outside the repository (`~/card-scanner-corpus/phase082/`).
- [ ] **T9.2 Check the manifest** (AC-7.3): `bin/rails "scanner:ground_truth[~/card-scanner-corpus/phase082/manifest.csv]"` (every row one printing), `bin/rails "scanner:overlap[…]"` (aborts on overlap: list the clashes for the maintainer to keep or drop), the List and era rules and the foil column against the cards (`verify-corpus-manifests`). Record each in `research.md`.
- [ ] **T9.3 The run:** `COLLECTOR_SCANNER_MANIFEST=… COLLECTOR_SCANNER_RUN_DIR=~/card-scanner-corpus/runs/phase082 bin/dev -b "ssl://…"`; on the phone, `/scanner/measurement`; the blocks in ABBA order (full, shipped, shipped, full; about 10 cards each), the framing switched in the run sheet between blocks; one deliberate capture per card, retakes only when the shot is plainly unusable (the first counts).
- [ ] **T9.4 Findings:** `GROUND_TRUTH=… bin/rails scanner:paired_findings` into `research.md` with the phone, browser, frame sizes, art on or off, every discordant card's strips viewed before a miss is counted (`verify-corpus-manifests`), and bar A's outcome. If it fails (AC-7.5), `LIVE_GUIDE` becomes the shipped card size (`liveGuideRect`'s default framing "shipped"), T1.1's expected boxes change to the shipped ones, the area doc says so with the run as its source: one commit `fix(scanner): the live guide at the shipped card size, by the re-measure (#344)`.
- [ ] **T9.5 Finish:** `verification.md` gains Story 7; push (with a slot); CI green; `gh pr ready <N>`; `gh pr edit <N> --add-assignee @me`; `worker_done`.

---

## Risks (what only a run confirms)

- **The frozen canvas's `object-fit: cover`.** Firefox and Safari apply `object-fit` to a `<canvas>`; if a browser drew it stretched, the frozen frame would not line up with the video. AC-4.1 asserts the canvas shows, not its crop; the screenshots show it, and the maintainer's phone does.
- **`MutationObserver` order.** `scan-shell` sets `c-scan--result` in a microtask after the stream renders; `paneSay` waits for it by frames. If a slow device needed more than about two seconds, the sentence would be written before the pane shows and not be announced (the screen-reader pass owed to the maintainer would catch it).
- **The backdrop click in headless Firefox.** A dispatched click on the dialog stands in for a tap on the backdrop; a real tap's target is the dialog too, by the element's rules.
- **Turbo's stream into a closed dialog.** Turbo renders into a closed `<dialog>`'s children like any element; the request specs assert the streams, the system examples the result.
- **Measurement on the phone.** The framing's session cookie and the phone's HTTPS dev certificate are as spec 007's runs had them; only T9.3 proves it on a device.

## Self-review

- **Spec coverage:** FR-1 T3.3 (commit 1); decision 16 Phase 2 and T3.3; FR-2 Phases 3, 4, 6; FR-3 Phase 1 and T3.5; FR-4 T3.3, T3.5, Phase 5, T7.2; FR-5 Phases 4, 5; FR-6 Phases 7, 9. Every AC is named in a phase's Satisfies line; AC-1.8 is by reading (T8.5).
- **Placeholders:** none; where a run may choose between two stubs (T3.5's backdrop, T6.1's engine failure), both are written and the choice is a `Ruling:`.
- **Names:** `liveGuideRect`, `shippedGuideWidth`, `LIVE_GUIDE`, `guideInFrame(…, rect)`, `scanner_destination`, `sitting_title`, `scanner_added`, `sitting_redraw`, `picker_redraw`, `say_in`, `added_line`, `MeasurementRun.current(framing:)`, `FRAMINGS`, `PairedReport#bar`, the stream ids of the contract table: used with the same names in every phase.
