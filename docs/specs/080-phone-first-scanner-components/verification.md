# Verification: spec 080, design system: the phone-first scanner

**Spec:** [spec.md](spec.md) 1.2.2 | **Plan:** [plan.md](plan.md) | **Issue:** [#343](https://github.com/plainprogrammer/Collector/issues/343) | **Pull request:** [#360](https://github.com/plainprogrammer/Collector/pull/360) (draft)
**Recorded:** 2026-11-13, on branch `080-phone-first-scanner-components` at `bc21f9cd` (merge base with `main` `59b0bdaa`; `origin/main` at `8ee8d291` when the diffs below were read, which changes none of the paths they name).

Each criterion with the example or the reading that proves it. Documents are verified by reading, never by RSpec (`.claude/rules/testing.md`). The red runs, rulings and measurements are as the implementers reported them in their commit bodies.

## Repository checks (AC-6.3)

- `bin/ci` at `bc21f9cd`, 2026-11-13: **"Continuous Integration passed in 8m36.12s"**. It runs every `bin/ci checks` step first (setup, the migration guard, RuboCop, YARD, the comment ratchet, Brakeman, bundler-audit, importmap audit; CI stops at the first that fails), so `bin/ci checks` passed as part of that run. Then RSpec: **4671 examples, 0 failures, 1 pending**, in 8m13.77s.
- Baseline before the branch's code (`bin/rspec` on the state before `be5d0149`): 4614 examples, 0 failures, 1 pending. The branch adds 57 examples: 48 in the scanner components spec, 7 in the tokens spec (6 examples at `59b0bdaa`, 13 now) and 2 in the files spec (7, now 9), by the dry run below and the files at the merge base.
- The spec-and-plan commit `73e4e329` (documents only) passed the pre-push hook's `bin/ci checks` when it was pushed.
- `spec/design_system_files_spec.rb` passes in that run (AC-6.3's second half).

## Browser criteria (RSpec, headless Firefox)

`bin/rspec --dry-run spec/system/design_system_scanner_components_spec.rb spec/design_system_tokens_spec.rb spec/design_system_files_spec.rb`: **70 examples** (48 + 13 + 9). The design-system run the implementers used, `bin/rspec spec/design_system_tokens_spec.rb spec/design_system_files_spec.rb spec/system/design_system_scanner_components_spec.rb spec/system/design_system_deck_rules_spec.rb spec/system/design_system_deck_components_spec.rb`, gave **141 examples, 0 failures** after T6.2 (the two deck specs are 71). The shipped scanner's specs, `bin/rspec spec/system/scanner*_spec.rb` (seven files), gave **51 examples, 0 failures** after T5.1, T6.1 and T6.2, unchanged; the full suite above runs them again.

| Describe (in `spec/system/design_system_scanner_components_spec.rb`) | Examples | Criteria |
|---|---|---|
| StatusBand (AC-1.3 to AC-1.5) | 5 | AC-1.3 (light and dark), AC-1.4 (the 16px icon at stroke 2; the three forms told apart by icon and words), AC-1.5 |
| the focused shell (AC-3.1) | 1 | AC-3.1's `c-shell--focused` (spec 1.2.2) |
| Sheet (AC-2.1 to AC-2.5, AC-2.7) | 9 | AC-2.1 (light and dark; closed; the backdrop's rule and computed colour), AC-2.2, AC-2.3, AC-2.4, AC-2.5 and AC-2.7 (light and dark at 360px), AC-2.7 (the link's focus ring and hover) |
| the shell (AC-3.1 to AC-3.9) | 13 | AC-3.1 (390 × 844 and 360 × 640, with the control "scrolls by the body's margin without c-shell--focused"), AC-3.2 to AC-3.6, AC-3.7 (light and dark, and the after-add line), AC-3.8, AC-3.9 |
| the selection pane (AC-4.1 to AC-4.11) | 19 | AC-4.1, AC-4.2, AC-4.3 (three examples), AC-4.4 (two), AC-4.5, AC-4.6 (two), AC-4.7 (four viewports), AC-4.8, AC-4.9, AC-4.10 (two), AC-4.11 |
| reduced motion, app-wide (AC-6.4) | 1 | AC-6.4 (a `c-btn` and a `c-tile__media`, with and without the block's rules) |

The reduced-motion parts of AC-2.4, AC-4.4 and AC-4.8 apply the block's rules through the reduced-motion helper (`spec/support/`, modelled on `CoarsePointer`). The parts' markup comes from `ScanMarkup` (`spec/support/scan_markup.rb`), which has no direct example: the examples from T3.2 on are its proof, and at `f596ea8c` it was checked with `ruby -c`, RuboCop, YARD (100% documented), the comment ratchet and a plain-Ruby script calling `band`, `pane`, `shell`, `sheet` and `bottom_bar`.

### Red runs (test first), as the implementers reported them

| Task (commit) | Red | Reason |
|---|---|---|
| T1.1 (`be5d0149`) | 13 examples, 6 failures | the AC-1.1 examples read `[nil, nil]` for the `on-` tokens and `nil` for `--scrim`; the AC-1.2 examples raised `KeyError` "on-success". The "can fail" control passed beforehand, as planned |
| T2.1 (`d6e8087e`) | none (a refactor) | the two deck specs ran 71 examples, 0 failures before the move and after it; the six helper bodies were identical to the module's |
| T2.2 (`e2a6804c`) | 9 examples, 2 failures | the system example raised `no reduced-motion rule matches ["::backdrop"] (found [".c-scanner *"])` after its checks without the preference passed (button 0.12s, tile 0.15s and 0.15s); the files example counted 0 `!important` and found `blocks.last` nil. Green: 93 examples, 0 failures across the tokens, files, scanner components and both deck specs |
| T3.2 (`5cccf1df`) | 4 of the file's 6 examples | a transparent ground with `ink` text; "16px normal 400" with no padding against "14px 20px 600 16px 16px"; the svg 1305px wide at stroke 1.5 against 16px at 2; the long sentence at 360px gave a 409px band with 44px text against 56 and 40. "tells the three forms apart" passed on arrival (a characterisation: it reads `ScanMarkup`), and the reduced-motion example was already green. Green: 27 examples, 0 failures |
| T4.1 (`11b4b4ae`) | the focused-shell example | the frame measured `[375, 844]` against `[390, 844]`; the body's margin-top, margin-left and min-height were 8px, 8px and 844px, and the document scrolled |
| T4.2 (`a228906e`) | all 9 sheet examples | the browser's dialog: bottom at 568, a 3px border, no radius; Close 50 × 36 with a 16px icon; the title 24px/700; the body did not scroll; `overscroll-behavior` auto; animation "none 0s"; no rule for `.c-sheet::backdrop` or `.c-sheet__foot a:hover`; the foot 16px in the browser's colours; the link the browser's blue with an auto outline; sideways overflow at 360px. Green: 108 examples, 0 failures. Tab from Close in the modal reached the notice's link directly, so `tab_to_text` was not needed |
| T5.1 (`e3ae3e4b`) | all 13 shell examples | the unstyled shell made the frame scroll (a scrollbar made frames 375 and 345 wide); bar controls 36px high; the main button's text 14px; the torch icon 16px at stroke 2; the count's number in Plex Sans, not Mono. The control "scrolls by the body's margin without c-shell--focused" failed on arrival, as the plan allowed. Green: 121 examples, 0 failures; the scanner's specs 51, 0 failures |
| T6.1 (`3542f6bb`) | 18 of the 19 new examples | no strip or pane displayed; `apply_reduced_motion_rules` raised `no reduced-motion rule matches [".c-scanpane__row"]`; the hidden-button example failed for the pane only. "shows only the centred card's panel" passed on arrival (a characterisation: the browser's own `[hidden]` rule hides the other panels). Green: 19 of 19 on the first CSS run |
| T6.2 (`2ec7cd91`) | passed on arrival (it guards what Phases 2 to 6 wrote) | shown to fail by three mutations of `additions.css` in the working tree, one at a time, each restored with `git checkout`: `color:#fff;` in `.c-band`; `font-family:serif;` in `.c-scanpane__name`; the heading "Scan pane (spec 080)" renamed "Pane (spec 080)" |

### Measurements recorded (headless Firefox)

- **AC-4.2**, 390 × 844: the pane 548px, the band 40px, the images 288px, the details block 80px, 16px from the add buttons to the bottom bar; nothing scrolls.
- **AC-4.3**, 390px: the centred image 206.2px wide, the row's inline padding 91.9px, 79.9px of each neighbour, a 12px gap, no scrollbar, snap `x mandatory` and `center`, the outline clear of the row's edges; the first and the last image centre at 195px.
- **AC-4.7**: 390 × 664, the strip 96px, its picture 76px, the images 184px, nothing scrolls; 360 × 640 with a one-line band, the images 160px, nothing scrolls; 360 × 640 with the two-line band, the band 56px, the images 160px, the pane's content scrolls; 360 × 560, the pane 312px and its content scrolls.
- **AC-4.9**: the heights 56px and 44px as drafted.
- **AC-4.11**, 360 × 640: two buttons 160 × 52px (left edges 16px and 184px), the long label on two lines, both fit.
- **AC-2.1**: `getComputedStyle(dialog, "::backdrop").backgroundColor` is `rgba(0, 0, 0, 0.4)` in both themes, and Firefox's own `rgba(0, 0, 0, 0.1)` with the rule removed.
- **AC-3.3**, **AC-3.8**: Done's right edge at 352.0000153px and Undo's inset from the after-add line's right edge at 1.0000153px (see the T5.1 ruling below).
- None of the plan's Risks fallbacks was needed: the row's end padding counts as scrollable (both end images centre at 195px), and the container-query units in the grid track resolve.

## Token criteria (AC-1.1, AC-1.2)

`spec/design_system_tokens_spec.rb`, describe "the status band's text and the scrim (spec 080)", beside spec 057's: "defines on-success, on-warning and scrim in the #{name} block (AC-1.1)" and "holds 4.5:1 for the band's text on its fill in the #{name} block (AC-1.2)", each for the light, dark and dark-by-preference blocks, and the control "flags white on the dark success fill (the check can fail)". `tokens.css` holds `--on-success: #ffffff`, `--on-warning: #ffffff` in the light block, `#0c1f1f` and `#231a08` in both dark blocks, and `--scrim: #00000066` in all three (decisions 3 and 4).

`tokens.json` (AC-1.1, read): "on-success" `{ "light": "#ffffff", "dark": "#0c1f1f" }`, "The sentence and the icon on a `success` status band, its one filled use (≥4.5:1)."; "on-warning" `{ "light": "#ffffff", "dark": "#231a08" }`, the same usage for `warning`; "scrim" `{ "light": "#00000066", "dark": "#00000066" }`, "The backdrop of an open sheet, black at 40% in both themes. Nothing is written on it and nothing else uses it." Met.

`spec/design_system_files_spec.rb`, describe "the phone-first scanner's blocks (spec 080)": "uses !important only in the reduced-motion block, which is the last block (FR-7)" and "keeps each part in a block of its own, with no colour literal and no font but the tokens' (AC-6.2)". The six blocks are StatusBand, Focused shell, Sheet, Scan shell, Scan pane and Reduced motion, app-wide, in that order.

## Document criteria (read against the text)

| AC | Where, and what it says | Verdict |
|---|---|---|
| 1.6 | `StatusBand.md`: the markup `<p class="c-band c-band--success" role="status"><svg …><path d="M20 6 9 17l-5-5"/></svg><span>Matched by its collector line</span></p>` and two warning lines; "Three forms: success with a check, warning with the alert triangle, warning with a question mark in a circle."; "It is a live region (`role="status"`)"; "`danger` has no band: something that went wrong is a `StatusMessage`."; "A band always carries an icon and a sentence."; "one element: when what it describes changes, its form class, icon and sentence are replaced in place … Never render a second band and reveal it with `hidden`."; "First use: the top edge of the scanner's selection pane … Its sentences there: …"; "It names no collectible: the component is the coloured band, and each use writes its own sentences." | met |
| 2.6 | `Sheet.md`: `<dialog class="c-sheet" …>` with `c-sheet__head`, `c-sheet__title`, `c-sheet__close` (in `form method="dialog"`) and `c-sheet__body`; "It is a native `<dialog>` opened as a modal."; "focus moves into the sheet on opening, and on closing it returns to the control that opened it."; "Three ways to close: the Close button …, Escape, and a tap on the backdrop."; "the tap on the backdrop is closed by the page's script, which is #344's and not built yet."; "**It never navigates** on a page that holds the camera: a visit would release it."; "Use it only on a page that already needs script, or give its opener a plain link to a page that holds the same content."; "First two uses … the sitting's destination ("Adding to") and the sitting's list."; "**The foot.** A focused page that is one screen high has no footer, so each of its sheets ends with the content notice's lines in `c-sheet__foot` … No page does this yet … (spec 080 decision 13)."; "It names no collectible." | met |
| 5.1 | README, Mobile and Hotwire: "A page for one task done many times in a row may drop the app header and the tab bar when it keeps a back arrow and its own primary action in view at all times."; "Its `<body>` carries `c-shell--focused` beside `c-shell--untabbed`"; "A focused page that is one screen high and has no footer shows the content notice's lines in the foot of each of its sheets (`Sheet`); such a page has a sheet or keeps the footer … No page does this yet … (spec 080 decision 13)."; "It is the one exception to "Nothing needs JavaScript" below", and the JavaScript bullet ends "A `Sheet` is the one exception (Sheets, above)."; "Content that would otherwise take the collector off a page whose state a navigation would lose (a running camera) opens in a `Sheet`, a bottom sheet over the page, which keeps that state."; "A swipe always has a button that does the same." | met |
| 5.2 | README, Color: "A status colour has one filled use, the `StatusBand`: … with `on-success` or `on-warning` for the sentence and the icon on it"; "`danger` is never a fill"; "A band always carries an icon and words (spec 080)."; "`scrim` … dims the page behind an open `Sheet`, as the dialog's backdrop, and is used for nothing else." | met |
| 5.3 | README, Motion: "Nothing moves without a cause the collector started"; "A transition or an animation takes 200ms at most and is instant under `prefers-reduced-motion: reduce`."; "One block, the last in `collector/additions.css`, turns every transition and animation off under that preference, app-wide (spec 080 decision 14)."; "A scroll the browser animates (`scroll-behavior: smooth`) is smooth only without the preference" | met |
| 5.4 | README, Components: "`DeckShape`, `DeckCheck`, `ProxyTag` (parts), `StatusBand` and `Sheet`."; "App additions (spec 080, #343, in `collector/additions.css`; no view uses them yet): `StatusBand` (`c-band`, …); `Sheet` (`c-sheet` …); … `c-scan` … `c-scanpane` …; and the app-wide reduced-motion block (Motion). Tokens: `on-success`, `on-warning`, `scrim`." | met |
| 5.5 | `Scanner.md`: "## The phone-first scanner (drawn by spec 080, built by #344 and #345)"; markup of the shell (`c-scan c-scan--result`), the status line (`c-scan__line--status`), the strip (`c-scan__strip`), the pane (`c-scanpane`) and the after-add line (`c-scan__line--added`), and a second block for the two lines over the camera; "## As built, until #344 and #345", then the old text: its 38 lines diffed against that section print nothing, and the file's diff is 106 insertions, 0 deletions | met |
| 5.6 | `Scanner.md`, the Copy table and "Placed by": "Line the card up with the guide, then capture." and "Reading the card…"; "Atraxa › Main · NM", "Blue binder", "No location · NM", "No location"; "Done"; "12 added" ("0 added", "1 added"), named "12 added. Show this sitting's cards."; "Capture", "Scan again"; "Read from the card" … "nothing read"; the five band sentences and "Not the printing that was read"; "1 of 14 printings", "1 of 3 possible cards"; the add labels, and "Accessible names stay today's: "Add Lightning Bolt MOM · 123 Foil""; "Added Lightning Bolt MOM · 123, foil" and the no-finish form, with "Undo"; "Previous printing"/"Next printing", "Previous card"/"Next card"; "Adding to", "This sitting: 12 cards"; "**Placed by #344 and #345** … "Use a photo", the artwork-matching line, … the art-overrule sentence" | met |
| 5.7 | `Scanner.md`, the rules: "**Capture and add stay the collector's taps**"; "The frozen frame and the capture strip are drawn in the page from the captured frame: the picture never leaves the device and nothing new is sent."; "The status line, the after-add line and the band are the page's three live regions."; "The centred card is announced through the band, which follows it (design decision 14)"; "It holds the candidates first (three at most, in ranked order), then … (design decision 17)."; "The guide's geometry is #344's" | met |
| 5.11 | README, Iconography: "Spec 080 adds the `StatusBand`'s icons at 16px and stroke 2, the foil add button's star at 14px (filled, so it has no stroke), and 20px icons at stroke 1.5 … the phone-first scanner's bars (the back arrow, the destination's chevron, the torch), the row's Previous and Next chevrons and a sheet's Close cross." | met |

Each document edit was grepped for before (absent) and after (present). The collectible grep of `Sheet.md` finds only the CSS word "set"; of `StatusBand.md`, only the scanner's sentences, in the first-use bullet and the Markup example labelled "Shown with sentences of its first use" (FR-6). `bin/yard doc` gave 0 warnings (see Observations for what that build covers).

## Previews (AC-5.8 to AC-5.10)

**Read (AC-5.8, AC-5.10).** `ScannerFlow.html`, `ScannerConfidence.html`, `Sheet.html` and `StatusBand.html` (`343f6daa`, written from `ScanMarkup` by the plan's generator, kept in the session scratchpad as the plan puts it). Each has exactly four `<link>`s, in order `preview-fonts.css`, `tokens.css`, `components.css`, `additions.css`; one `<style>` whose selectors are only `html`, `body`, `body`, `.pv`, `.pv__cap`, `.pv__note`, `.pv__frame`, `.pv__frame .c-scan`, `.pv__list`, `.pv__ph`; the `?theme=dark` script; 0 `<img>`, and no `c-mana`, `c-cost`, set symbol, `.svg`/`.png`/`.jpg` file or `url()`. The inline `style` attributes are the guide's box (as the camera controller sets it) and `StatusBand.html`'s `style="width:360px"` list.

**Opened (AC-5.9), T8.2.** All eight page-and-theme loads in headless Firefox (classic scrollbars):

- rule counts: `preview-fonts.css` 4, `tokens.css` 15, `components.css` 185, `additions.css` 395, the inline sheet 9; none zero, so the four stylesheets loaded;
- a second run of each page's inline script inside `try … catch`: "ok". Headless Selenium could not read the browser console here (as spec 060 recorded), so this record does not claim "no console error" beyond those loads and that run;
- no frame overflows sideways (`ScannerFlow` 5 of 5, `ScannerConfidence` 3 of 3, `Sheet` 2 of 2, `StatusBand` 1 of 1);
- `.c-scan` is 844px in every frame and the strip 144px in the result frames, so the short-screen rule answered to the frame, not the window; the centred card is 0px off the row's centre;
- `?theme=dark` gave dark on load; the sheets are 407px and 633px, under 85% of 844px;
- "Not sure of this card. Check it against your capture." is one line (a 40px band) at 390px in `ScannerConfidence.html`; in `StatusBand.html`'s 360px list it wraps to 56px, as does "…one digit corrected".

**Shots.** In [screenshots/](screenshots/) (`bc21f9cd`), JPEG, 78 to 106 KB each: `ScannerFlow-{light,dark}.jpg`, `ScannerConfidence-{light,dark}.jpg`, `Sheet-{light,dark}.jpg`, `StatusBand-{light,dark}.jpg`. Compared with the mock-ups: the layout and the copy match; the stage is a flat `surface-sunken` area (decision 10); the foil marker is the star (decision 16); Previous and Next are drawn (decision 6); the Match step has no left neighbour (it shows the first card); the unsure state's images say "Card image" (one caption for every image).

**Final visual review.** Pending (T9.4): the eight screenshots go to the maintainer in chat and into the pull request body, with links pinned to a commit SHA.

## Unchanged scanner (AC-6.1, AC-6.2)

At `bc21f9cd`, against `origin/main`:

- `git diff --stat origin/main -- app/views app/javascript app/controllers app/models app/helpers`: empty.
- `git diff origin/main -- app/assets/stylesheets/collector/additions.css | grep '^-' | grep -v '^---'`: empty; the branch only adds blocks to `additions.css`.
- The shipped scanner's seven `spec/system/scanner*_spec.rb` files: 51 examples, 0 failures, unchanged, and every scanner example passes in the full `bin/ci` run above.
- The blocks' guard (AC-6.2) is the files spec's describe "the phone-first scanner's blocks (spec 080)" (Token criteria, above), shown to fail by T6.2's three mutations.

## Deviations from the plan, and spec patches

- **Spec 1.2.2** (found while planning, applied to `spec.md` before execution as part of the plan's approval, 2026-11-13): a focused page's `<body>` carries `c-shell--focused`; a two-line band is 56px, not 60px; AC-5.9 and Verification name what stands in for the console; the Files table lists the support files and the guards. No spec patch was made during execution.
- **T4.2, `a228906e`**: the computed `::backdrop` expectation was added beside the rule read (the plan's Risks, first bullet). Headless Firefox reports `rgba(0, 0, 0, 0.4)` in both themes and its own `rgba(0, 0, 0, 0.1)` with the rule removed, so the expectation tests the rule; if another browser reports none, the expectation is Firefox's.
- **T5.1, `e3ae3e4b`**: Done's right edge (352px) and Undo's 1px inset are compared within 0.5px, because Firefox places these text-width rows at 352.0000153 and 1.0000153 (the plan's Risks, "Float noise").
- **T7.1, `71da9467`**: the Sheets bullet adds "which keeps that state" (AC-5.1); the Touch bullet says the spec 080 rules are drawn and used by no page yet (FR-6); the App additions line names the sub-classes the CSS has; Iconography says the 20px icons sit "inside controls" (the back arrow and the destination are not `c-btn`).
- **T7.2, `cea748de`**: `StatusBand.md`'s Markup shows the band's full icons from `ScanMarkup.icon` and is labelled as its first use's sentences (decision 9), with a note that the markup keeps `stroke-width="1.5"` and the CSS sets 2; both documents say no view renders a band or a sheet yet (FR-6); `Sheet.md` is matched to the CSS (the foot's place, line height, hover, focus, decision 13's clause, decision 4's fallback, Close's size and stroke, overscroll, the safe-area inset); the backdrop tap reads "closed by the page's script, which is #344's and not built yet".
- **T7.3, `3c926ab2`**: the first section's summary says "Nothing here is live yet" (FR-6); a second Markup block shows the two lines over the camera (AC-5.5); the document writes the capture as a `canvas` and an image as an `img` in the `li` (`ScanMarkup` uses a `div` and an empty `li` for the previews; the CSS takes either); the strip's short form is named as the shell under 720px; the rules cite design decisions 14 and 17.
- **T8.1 and T8.2, `343f6daa` and `bc21f9cd`**: the plan's T8.2 commit subject went on the previews' commit and the shots took a commit of their own; the shots were resized with `-resize 1600x>` (no enlarging) rather than the plan's `1600x`; JPEG as the plan says.
- **T6.1, `3542f6bb`**: no deviation and no Risks fallback. The `.c-scanpane [hidden]` rule is decision 8's, and `.c-scanpane__row { scroll-behavior:auto }` sits inside the reduced-motion block (FR-7), with no new `!important`.

## Observations

- **The dark guide's dashed line.** The guide's inner dashed `on-brand` line does not show on the dark theme's `surface-sunken` stage in the previews; the outer `brand` border does. It is the shipped guide's rule (AC-3.9, "drawn as today") and reads over a real picture; it is for #344 to consider.
- **A neighbour's caption.** A letter of a neighbour's "Card image" caption shows past the Next button in the previews, as in the mock-ups. The captions are the previews' own (decision 10); the app puts no text on an image.
- **The design-system documents are not in the YARD build.** `bin/yard doc` built with 0 warnings, but `.yardopts` feeds YARD only `docs/architecture/*.md` and `docs/adr/0*.md`, so `docs/design-system/` is not part of that build and its warnings check says nothing about these documents.
- **Co-author trailers.** The trailer in force in the implementing agents' environment changed between commits: `5cccf1df` reads "Claude Sonnet 5.5", left as is. `git log` shows the same trailer on `73e4e329`, `11b4b4ae`, `a228906e` and `e3ae3e4b`; every other commit on the branch reads "Claude Opus 5.5".
- **`::backdrop` is reported by Firefox.** The plan expected to read only the rule; headless Firefox reports the pseudo-element's computed colour, so AC-2.1's example reads both (Deviations, T4.2).
- **No-snap and no-inherit fallbacks are not reproduced.** A `::backdrop` that does not inherit the tokens (no dimming) and a browser without scroll snap (Previous and Next still move the row) are stated in the CSS comments and the documents; headless Firefox supports both features, so neither is exercised by an example.

## Implementation review

Pending: sdd-review Mode B (T9.3).
