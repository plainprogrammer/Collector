# Verification: The Phone Line's Wrap Is Stated at a Phone's Width (spec 061, #288)

**Spec:** [spec.md](spec.md) (0.3.0) | **Plan:** plan (retired in `1c0d5ee074242ad292e522b94df96b291f82954d`; read it with `git show 1c0d5ee074242ad292e522b94df96b291f82954d^:docs/specs/061-place-line-wrap-at-phone-width/plan.md`) | **Branch:** `061-place-line-wrap-at-phone-width`

The example is `spec/system/collection_row_place_spec.rb`, "wraps a line wider than its room at a phone's 360px content width, with no sideways scroll and no place". Commits: `bb6626bd` (red, on the old PMH3A line), `a2223414` (green, on the PLST line), `2bd9a9c0` and `0643068d` (comments).

## Criteria

| Criterion | How it was verified | Evidence |
|---|---|---|
| AC-1.1 (the line is two lines high at 360px, no sideways scroll, no Location column, no place; the same at either scrollbar) | The example above: `open_in_narrow_frame` returns `[360, true]`, the narrow frame has no `th` "Location", the line ends with "PLST · PCY-132 · Etched · NM · EN", and `line_measures` height is 20px or more. Run in the suite's classic scrollbars and once with overlay (AC-1.4) | Red run on the old PMH3A line (`bb6626bd`): `margin -7.6: unwrapped 153.4, room 146, scrollbar 15`. Green run (`a2223414`): the whole file, 18 examples, 0 failures. Classic run (printed by a temporary logging line, reverted; nothing committed): `NUMBERS {height: 32, room: 146, scrollbar: 15, unwrapped: 184.1499938964844} margin 23.149993896484403`, passed |
| AC-1.2 (unwrapped width exceeds room plus scrollbar width by 20px or more) | The same example: `margin = unwrapped - (room + scrollbar)` asserted `>= 20`, with a message giving the numbers | The classic `NUMBERS` line above: 184.15 - (146 + 15) = 23.15, passed. The red run shows the assertion failing, with its message, when the line is too short |
| AC-1.3 (spec 048 AC-1.7's MH3 line is one line at 360px and 390px) | Met by the existing examples in `spec/system/collection_row_place_spec.rb`, "fits one line under the name at 360px and 390px and shows no place"; no new example | Both pass in the whole-file run (18 examples, 0 failures) |
| AC-1.4 (the example passes with overlay scrollbars, recorded with a scrollbar width of 0) | A temporary edit of `ui.useOverlayScrollbars` in `spec/support/system.rb` to 1, the example run once, then the edit reverted; nothing committed for it | Overlay run: `NUMBERS {height: 32, room: 161, scrollbar: 0, unwrapped: 184.1499938964844} margin 23.149993896484403`, passed. Scrollbar 0, room 161, unwrapped 184.1, height 32. The pin is back at classic and `git status` was clean after the revert |
| AC-2.1 (the index adds spec 061's row and names the supersession; spec 048's "Superseded by" cell names spec 061) | By reading `docs/specs/README.md` | Row 78 (spec 061) names spec 048 AC-1.8, the Error Scenarios row for an account with no location and the sentences of decision 4, and says the ruling and AC-1.7 stand. Row 69 (spec 048), "Superseded by" cell, names spec 061 and the same three parts. Spec 048 itself is not edited |
| AC-2.2 (the area doc's place line bullet states the rule and cites AC-1.1 and AC-1.2; Sources and the distillation log carry spec 061) | By reading `docs/architecture/collection-and-lots.md` (commit `2e31cd81`) | The Place line bullet's last sentence now says a line wider than its cell wraps, gives the three lines (MH3 fits, PMH3A fits with about 8px to spare, PLST · PCY-132 · Etched wraps by 23px) and cites spec 061 AC-1.1 and AC-1.2. Sources: the spec 048 line reads "all, except AC-1.8, restated by spec 061", a spec 061 line follows it, and the issues list adds #288 and #271 (#271 is closed). `git grep -n "five-character" -- docs/architecture` finds only the new sentence. The distillation-log entry is still owed by `distill-feature`, which writes it at the feature's end |

## Deviations

None from the plan, except one extra commit, `0643068d`, which changes the wording of one header comment in `spec/system/collection_row_place_spec.rb` (it names spec 048 in the place spec's header). No stylesheet, view, helper, model, controller, migration or export file changed (FR-2).

## Implementation review

SPEC-ALIGNED (Opus, read-only, `sdd-review` Mode B, 2026-11-10, at `ac3a4d56`). Every criterion AC-1.1 to AC-2.2 and FR-1 to FR-3 is met and evidenced; spec 048 is unedited; only the system spec and documents changed. 0 blocking, 0 major, 3 minor, all taken: the classic numbers' evidence says they came from a temporary logging line; the area doc's sentence is split so its two citation groups don't touch; the system spec's header comment is re-wrapped. The distillation-log entry and the index row's status word are owed by `distill-feature`.

## Distillation

Distilled into [`collection-and-lots.md`](../../architecture/collection-and-lots.md) (2026-11-10): the place line bullet (done with Task 4), Sources, the issues list and a distillation log row; the specs index row is Frozen with its plan "retirement owed"; spec 061 carries its frozen line. The lesson is `docs/lessons/2026-11-10-a-wrap-criterion-needs-a-measured-margin-at-the-phones-width.md`. No ADR was needed, and CLAUDE.md restates none of this.
