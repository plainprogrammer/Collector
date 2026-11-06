# Verification: Keep Focus and Announce After the Scanner Sitting Panel Redraws (spec 047)

**Spec:** [spec.md](spec.md) 0.3.0 · **Plan:** [plan.md](plan.md) · **Issue:** [#182](https://github.com/plainprogrammer/Collector/issues/182)

## Rulings

By the maintainer, 2026-11-06, relayed by the coordinator: decision 1, option A (the clearing case reuses "Set"'s own sentence, "Cards you scan now: condition not specified, no location.", with no new copy). Gates A and B were passed by the coordinator under the maintainer's delegation.

Deviations from the plan, all small and recorded in the commit bodies or here:

- T5 worded the Scanner.md sentence as "It works without script: "Set" submits it, a Turbo Stream redraws the panel and says … in `#status`, and `sitting_focus_controller.js` then puts focus back on "Set"" (the plan's replacement would have repeated the existing "says … in `#status`" clause; the meaning is the plan's).
- T4 wrote the controller and views before the one-selector change in the Undo request example (`h2[tabindex='-1'][data-sitting-focus-target='heading']`); the behaviour itself had been seen red in T3's system examples first.
- The two desktop "Set" screenshots are composites: a crop of the status strip on top of a crop of the panel (the camera stage lies between them, about 1,000 px).

## Evidence

| Criterion | Proved by |
|---|---|
| AC-1.1 | `spec/system/scanner_sitting_spec.rb:224` "puts focus back on Set after a keyboard Set on a sitting with cards, and again on a repeat" (red in T3, green after T4); request half: `spec/requests/scanner/sittings_spec.rb:663` |
| AC-1.2 to AC-1.4 | `spec/system/scanner_sitting_spec.rb:241` "puts focus on Set, with the status, when Set opens a sitting, deletes an empty one, and finds none open" (the repeat Set and the no-sitting Set mark the old panel stale, so only a replaced panel passes); request half: `sittings_spec.rb:663`, and the flipped examples at `:523` and `:540` |
| AC-1.5 | `sittings_spec.rb:678` (condition outside the scale) and `:685` (a location that is not the account's): 422, `focus_to` is "set", the alert sentence is kept |
| AC-2.1, AC-2.2 | `spec/system/scanner_sitting_spec.rb:259` "puts focus on the heading after a keyboard Undo; the heading is not a Tab stop" (two entries, then the last; heading text "This sitting: 1 card", then "This sitting: 0 cards") |
| AC-2.3 | `sittings_spec.rb:692` (done, then "already undone" 422: heading target, alert sentence). The "changed" refusal goes through the same `sitting_stream(…, alert: true, focus: :heading)` call (`undos_controller.rb:19`) as "already undone"; its own request example (`sittings_spec.rb:85`, spec 009 AC-4.2, AC-4.4) is unchanged and green |
| AC-2.4 | `scanner_sitting_spec.rb:259` (`tabIndex` is -1, so not a Tab stop; the heading's computed `outlineStyle` is "solid" and `outlineWidth` "2px" after the keyboard Undo, red before T5's `additions.css` rule: Firefox's default was "auto" and "1px"); the images below, read by looking |
| AC-3.1 | `scanner_sitting_spec.rb:224` (the page load leaves `document.activeElement` on the body); `sittings_spec.rb:705` (the page's own render has no `data-controller` and no target) |
| AC-3.2 | `sittings_spec.rb:705` (an add's answer has no target) |
| AC-3.3 | `scanner_sitting_spec.rb:224` (`window.__marker` survives a Set: the page is not reloaded); the camera is untouched by the stream as in specs 040 and 009 |
| AC-4.1 | `sittings_spec.rb:715` (a replayed add, an Undo, a Set), `:663` (Set accepted, deleting an empty sitting, none open), `:678` and `:685` (Set refused), `:692` (Undo refused); a plain add's sentence by the existing examples in `spec/requests/scanner/sitting_entries_spec.rb` |
| AC-4.2 | the flipped examples `sittings_spec.rb:233` (spec 040's "No location" on an empty sitting), `:523` and `:540` (the `status_cleared?` helper is gone), `:663` |

Screenshots (`screenshots/`, factory data with placeholder printings; the 390 px shots are in a fixed-width frame; each was looked at):

| Image | Shows |
|---|---|
| `heading-focused-undo-desktop-light.jpg`, `-dark.jpg` | the heading "This sitting: 1 card" with the 2px `focus` ring after a keyboard Undo |
| `heading-focused-undo-390-light.jpg`, `-dark.jpg` | the same at 390 px |
| `set-focused-desktop-light.jpg`, `-dark.jpg` | the "Set" button with its ring after Set, under the status "Cards you scan now: Near mint, no location." (a composite of two crops) |

Measured in the page: the outline is 2px solid `rgb(29, 111, 209)` (light) and `rgb(127, 178, 255)` (dark).

## Owed to the maintainer

- **A screen-reader pass** (NVDA or VoiceOver) of Set, Undo and the clearing case (a Set that deletes an empty sitting). Listen for whether the heading and the status together read once or twice after an Undo (focus moves to the heading while the polite live region announces "Removed 1 × …"), and that the clearing case now says "Cards you scan now: condition not specified, no location." instead of nothing. Automation proves `document.activeElement` and the status text, not what a screen reader says.
- **A known edge, not designed around** (plan item P4): if a collector is inside the old panel's Condition or Location select when an answer lands, Turbo's own focus preservation refocuses the new select by its id one frame after the controller connects, which overrides the move to "Set". It does not arise from pressing "Set" or "Undo" themselves.

## Runs

- `bin/rspec spec/requests/scanner spec/requests/scanners_spec.rb spec/system/scanner_sitting_spec.rb` after the second merge of `origin/main`: 157 examples, 0 failures.
- The three new system examples were run six times in a row after T5: 0 failures each time.
- The full `bin/ci` run and the PR's CI are recorded in the pull request.

## Implementation review

SPEC-ALIGNED

Mode B, Opus, read-only, 2026-11-06, on the branch after the second merge of `origin/main`: every AC (1.1 to 4.2), FR-1 to FR-5, decisions 1 to 4 and the Supersedes table are covered; 0 blocking, 0 major, 5 minor.

- Minor 1 (the `_picker.html.erb` header comment still said the control "needs no script"): fixed in the commit that records this review; the plan's T2 had asked for the reword.
- Minor 2 (the AC-4.2 row omitted the flipped example at `sittings_spec.rb:233`): added to the table above.
- Minor 3 and 4 (no focus-target assertion for the "changed" Undo refusal or the "changed" replayed add; no example for "Set" with none open on an account with no locations): accepted. Each shares its code path (`undos_controller.rb:19`, `chosen_message`) with a case that is tested, as AC-2.3 and AC-1.4 say above.
- Minor 5 (the P4 edge, Turbo refocusing a select that held focus while the answer was in flight): accepted, listed under "Owed to the maintainer".

Not run by the reviewer (read-only): the suite. The runs are those under "Runs"; the full `bin/ci` and the PR's CI are recorded in the pull request.
