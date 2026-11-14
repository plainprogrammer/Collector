# Verification: spec 088, the selection pane

Spec 1.0.3, plan at `a6bb3fe1` (Gate B 2026-11-13). Written by the main session after execution; the implementation review (Opus 5.5) is recorded at the end under its heading. Rows say what proves each criterion: a spec and its example, a reading of the code or a document, or an owed check.

## Criteria

| Criterion | Proof |
|---|---|
| AC-1.1 strip beside the match, no interim body | `spec/system/scanner_selection_spec.rb` "shows the capture beside what was read…" (strip texts, capture canvas 178 × 248, band, items, one panel, no `.c-scanpane__results`) |
| AC-1.2 reading's text as text | same file, "writes the reading's text as text"; request example "writes a card named with markup as text" (`readings_spec.rb`) |
| AC-1.3 photo strip | "shows a picked photo's card on the strip, and a no-edge sentence after 'Done.'" (flat photo, `pick_synthetic_photo(flat: true)`) |
| AC-1.4 send failure | "shows the strip and the failure, no band, after a send failure"; `scanner_result_spec.rb` failure examples |
| AC-2.1 to 2.3 band states | `spec/models/scanner/selection_spec.rb` (state_of, bands), `readings_spec.rb` (success, guess, unsure templates and icons) |
| AC-2.4 one band element replaced in place | "steps to the next printing with Next: the same band element…" (node identity and exactly one `.c-band`) |
| AC-2.5 band is `role=status`, empty and spaceless with no result | markup in `_scanner.html.erb`; `.c-band:empty` rule; examples assert `#scanner_band:empty` (`visible: :all`: an empty band takes no space, so the driver reports it not displayed) |
| AC-2.6 nothing about art with art off | "says nothing about art in the pane with art matching off" |
| AC-3.1 to 3.8 the row | `selection_spec.rb`, `readings_spec.rb` (counts, `aria-current`, hidden panels, positions), system examples for Next/Previous, focus move at the end, arrow keys, scroll-to-nearest, neighbour tap; possible-cards row in `readings_spec.rb` |
| AC-3.9, 3.10, 3.11 frame navigation | "opens a possible card's printings from All printings…", "keeps the centred printing centred and focus on Next when Show 20 more…", "says so in the pane's region and leaves the row as it was…"; `printings_spec.rb` |
| AC-4.1 to 4.3 panel, adds, foil marker | `readings_spec.rb` (panel lines, finish buttons, labels, star, relabel), `printings_spec.rb` (`finish_hint`) |
| AC-4.4 to 4.6 adds | "adds the centred printing in the tapped finish…", "adds the swiped-to printing…", `scanner_adding_spec.rb`, `scanner_sitting_spec.rb` (refusals, replays, the `_top` target) |
| AC-5.1 to 5.4 layout at three sizes | "fits the band, Previous and Next, … at 390 × 844 / 360 × 640 / 360 × 560", "fits the not-sure pane at …", "wraps a long set and card name…" |
| AC-5.5 tokens and contrast | the pane uses only tokens (additions.css reading); band contrast is spec 080's `design_system_scanner_components_spec.rb` (AC-1.2) |
| AC-5.6 touch floor | `spec/system/small_controls_touch_floor_spec.rb` (the pane's controls listed) |
| AC-6.1 to 6.3 other outcomes | `readings_spec.rb` (status-line stream, catalog-not-ready alert), "says nothing read on the status line…", `scanner_result_spec.rb`, escaping examples |
| AC-7.1 to 7.5 regions and focus | "says 'Done.' and the band's sentence once…", "keeps the destination sheet's own region working while a result shows", add and Scan-again examples (focus on the main button, empties) |
| AC-8.1 old markup gone | `git grep` for `c-scanpane__results`, `c-scanner__candidate`, `scanner_printings`, `What the scanner read` in `app` finds none; system example asserts their absence |
| AC-8.2 measurement unchanged, ranks | `scanner_measurement_spec.rb` (records the add of a swiped-to printing with rank 'other'), "records the add's rank…"; the run sheet's row logic untouched (`git diff` shows no change to `scanner/measurements` controllers or `measurement_run.rb`) |
| AC-8.3 policy pin and core spec | `spec/requests/footer_spec.rb` and `spec/scanner_sitting_core_spec.rb` (the selection's files added to its glob) pass |
| AC-8.4 design-system docs | read in the implementation review below |

## Measured boxes (decision 13, AC-5.1/5.2)

Headless Firefox, narrow frame, at rest (`document.getAnimations()` idle), from the Task 9 run; px.

| State and size | Strip | Band | Images | Adds bottom | Bottom bar top | Body scrolls |
|---|---|---|---|---|---|---|
| confident 390 × 844 | 144 | 40 | 288 | 732 | 748 | no |
| confident 360 × 640 | 96 | 40 | 160 | 528 | 544 | no |
| confident 360 × 560 | 64 | 40 | 112 | 448 | 464 | no |
| not sure 390 × 844 | 144 | 40 | 288 | 732 | 748 | no |
| not sure 360 × 640 | 96 | 56 | 122 | 528 | 544 | no |
| not sure 360 × 560 | 64 | 56 | 96 | 470 | 464 | yes, about 6px (spec 1.0.2) |

At 360 × 560 the compact strip's name and line are 22 + 18px centred with 10px above and below, the label visually hidden (spec 1.0.3).

## Red window

Tasks 3, 5, 6 and 7 left spec files red on purpose until Task 8's migration closed it (commits name it). From the migration's last commit to the head, every scanner system spec is green: `scanner_selection_spec.rb` 29, `scanner_result_spec.rb` 19, `scanner_adding_spec.rb` 10, `scanner_art_spec.rb` 5, `scanner_detection_spec.rb` 9, `scanner_sitting_spec.rb` 29, `scanner_spec.rb` 9, `scanner_page_spec.rb` 20, `scanner_measurement_spec.rb` 7, `scanner_geometry_spec.rb` 4, `design_system_scanner_components_spec.rb` 53, `small_controls_touch_floor_spec.rb` 23 examples, 0 failures; request, model and helper specs for the scanner 270 examples, 0 failures. `bin/ci checks` passed at `a8b9285d` (27 s). The full `bin/ci` runs once with the coordinator's slot after this review and the wrap.

## Screenshots

In [screenshots/](screenshots/), factory data (placeholder card images: a tile with the name and set number) and a synthetic card, phone frames 390 × 844 (360 × 560 for the short ones), desktop 1280, light and dark (`-light`, `-dark`): `phone-match`, `phone-swiped`, `phone-guess`, `phone-unsure`, `phone-short-match`, `phone-short-unsure`, `phone-nothing-read`, `phone-failure`, `phone-after-add`, `desktop-match`; `flow-match-swipe-add.gif` (capture, result, Next, Previous, Add foil, the after-add line; light). Every shot was looked at before the specs were trusted. Found and fixed: the 64px strip at 360 × 560 was cramped (the label on the top edge, the line touching the band): the label is now visually hidden there (spec 1.0.3, `8b91216e`). Seen and accepted: at 360 × 560 with the not-sure band the add buttons end about 6px below the bottom bar's top until the body is scrolled; the placeholder tiles wrap a name mid-word at the 96px floor (no real card art in the factory data).

## Owed, not done

- The screen-reader pass on a phone (a result opening, a swipe, Previous and Next, an add, a refused add; each sentence said once), as spec 082's was; the examples check the text and the element.
- A real-phone look at the pane over the live camera (the shots use the substituted camera and placeholder images); the maintainer's sitting is not asked for (ruled 2026-11-13).
- Headless Selenium reads no console here (spec 060), so "no console error" is not claimed.
- `script/scanner/detector_parity.rb` needs the spike corpus and a dev server; the detector and the photo path are unchanged by this spec.

## Documents

Read by the implementation review below: `docs/architecture/scanner.md`, `docs/design-system/components/Scanner.md`, `StatusBand.md`, the README, `CLAUDE.md`'s scanner bullet, the specs index row and the supersessions both ways.

## Implementation review

SPEC-ALIGNED WITH FINDINGS (0 blocking, 2 major, 7 minor). Mode B, by Opus 5.5 (read-only), on the head after the screenshots (`5f07f405`); the findings were fixed by a Sonnet 5.5 implementer in the commits below and are re-proved by the examples named, run green after the fixes. The reviewer checked: the band as one persistent element copied from the centred panel's template; the hidden "Done." sentence only with band text; refusals as visible alerts in `#status`; nothing read and no match on the status line with the frozen frame hidden and no pane; the add forms targeting `_top`; the selection frame's params (closed `band` list, clamped `limit`, arrays read as 0, `match` looked up within the card, 404s, sign-in); measurement mode untouched (no diff to `measurement_run.rb`, the measurements controllers, the measurement-mode concern or `scan_shell_controller.js`); the documents and the supersessions both ways; and the screenshots against the mock-ups.

| Finding | Fix | Proof |
|---|---|---|
| M1 the 200 cap was not built: at `limit` 200 the row kept a "more" item that re-rendered the same 200 | `fe912ed4`: `more` is 0 and `more?` false at the cap | `selection_spec.rb` (MAX stubbed), `printings_spec.rb` |
| M2 "Send again" emptied the strip's texts and closed and reopened the pane | `beab3aa9`: the failure block stays shown while a resend is in flight and hides in the same render as the answer | `scanner_result_spec.rb` Send again example (strip texts and no flicker) |
| 1 a failed-load alert outlived a successful retry; `announce` dropped measurement mode's note | `315dce32` | `scanner_selection_spec.rb` retry example |
| 2 AC-5.3 overlap check only in the confident examples | `b0ecad2d` | the not-sure fit examples |
| 3 a possible-cards row of more than one card never exercised | `ade4a10e` | `readings_spec.rb` (three candidates, "Card n of 3", ranks 1 to 3), a system example stepping Next card |
| 4 "Add etched" unproven | `ade4a10e` | `readings_spec.rb` |
| 5 AC-7.2, AC-7.4, AC-6.1 (photo), AC-2.5 unproven clauses | `5ca5187e` | the four assertions |
| 6 dead CSS rule | `606cdd9f` | `git grep` |
| 7 tests-first not visible in the history | not changed: several tasks carry their spec and code in one commit by the plan's batching; the red runs are in the commit bodies of the fixes and in the implementers' reports, and Task 3's request specs were committed red on their own (`58539866`) | |

Not fixed, accepted: the spec's Documents table names `_strip` and `_band` partials; what was built is the strip inline in `_scanner` and `_band_content` (decision 15 is unchanged), and `scanner/printings/index` stays as a one-line render. In `phone-short-unsure` the body's classic scrollbar is drawn and the add buttons end 6px below the bar until scrolled (spec 1.0.2). Still owed: that "a fling announces once" (AC-3.5) and each sentence being said once are the maintainer's screen-reader pass; AC-3.11 is proved for a failed "All printings" request only (a failed "Show 20 more", a server error and an ended session are by reading `scanner_reading_controller.js`).

## Distillation

2026-11-13, by `distill-feature` after the implementation review: the pane, the band's three states and wordings, the row and the selection frame's request, the strip, where each outcome shows, the hidden "Done." sentence and focus, the layout numbers (with the two places they live and what proves them) and the accepted limits are in `docs/architecture/scanner.md` (Sources and the Distillation log row, whose pull request reads "spec 088's pull request" until it has a number); the markup and copy are in the design system's `Scanner.md`, `StatusBand.md` and README; CLAUDE.md's scanner bullet points to the area doc. The index row 088 is Frozen with its plan retirement owed, and its supersessions of specs 009, 011, 080 and 082 are recorded in both directions. No ADR was proposed (decision 17). The session's memory and lessons are in `fc8fef50`.
