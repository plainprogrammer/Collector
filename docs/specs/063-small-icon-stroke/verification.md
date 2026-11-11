# Verification: spec 063, small icons keep their weight (#294)

**Spec:** [spec.md](spec.md) 0.3.0 | **Plan:** plan (retired in `375c33e05e502eec749f84a1cafa9b0d79b00ba1`; read it with `git show 375c33e05e502eec749f84a1cafa9b0d79b00ba1^:docs/specs/063-small-icon-stroke/plan.md`) | **Branch:** `063-small-icon-stroke`
**Commits:** `9a91d4d6` (the red example), `c2b9badd` (the CSS block), `cdccb7d9` (README, TabBar.md, Badge.md), `fa1fb683` (nine previews load `additions.css`)

## Acceptance criteria

| AC | How it was met | Evidence |
|---|---|---|
| AC-1.1 legality marks 12px, stroke 2.5 | `spec/system/icon_stroke_spec.rb`, "draws the legality marks at 12px with a stroke of 2.5" | Red before `c2b9badd`: `.c-legal--yes svg` and `.c-legal--no svg` measured stroke 1.5 at 12px against the expected `[[2.5, 12]]`; green after |
| AC-1.2 badge check and alert 12px, stroke 2.5 | the same file, "draws the check and the alert in a badge…", the real partials' markup inside `c-badge` on the card page | Red: stroke 1.5 at 12px for both; green after |
| AC-1.3 16px and 14px at stroke 2 | the same file, "draws the search field and the buttons at 16px and the view switch at 14px…" | Red: `.c-input svg` and `.c-btn svg` 1.5 at 16px, `.c-seg svg` 1.5 at 14px; green after |
| AC-1.4 tab bar 22px at 1.5 | the same file, "leaves the tab bar's 22px icons at the partials' 1.5", in a 390px frame | Passes before and after (a regression guard, not a red one, as the plan says) |
| AC-1.5 every rendered stroked icon 1.1px to 1.4px | the same file, "keeps every rendered stroked icon between 1.1px and 1.4px on screen": the card page, the collection grid and table, the catalog search and the 390px collection page | Red: listed 0.75px (12px icons), 0.875px (14px) and 1.0px (16px) on every page; green after (weights 1.167, 1.25, 1.333, 1.375px) |
| AC-1.6 star filled, unchanged | the badge example: `icons(".c-badge--foil svg")` is empty (computed `stroke: none`) while the star is in the page | passes before and after |
| AC-1.7 visual review | before and after shots, light and dark, 1x and 2x, in [screenshots/](screenshots/) | see "Visual review" below |
| AC-2.1 README Iconography | read: the bullet states 1.5 at 20px and above, 2 at 14px to 16px, 2.5 at 12px, about 1.25px on screen, `30 ÷ size` rounded to a half, between 1.5 and 2.5, where it lives (`additions.css` by component; the attribute stays 1.5) and points to spec 063 | `docs/design-system/README.md`, Iconography, commit `cdccb7d9` |
| AC-2.2 previews match | the nine previews gained the link (commit `fa1fb683`); measured in headless Firefox on a local static server (below) | the measures and shots below |
| AC-2.3 TabBar.md, Badge.md | read: `TabBar.md` line 10 `stroke-width="1.5"`; `Badge.md` line 5 says the 12px icon's stroke is 2.5, set by `additions.css` | commit `cdccb7d9` |
| AC-2.4 index row | read: the row of 063 in `docs/specs/README.md` (Approved, plan present) | |
| AC-3.1 partials unchanged | `git diff --stat main -- app` lists only `app/assets/stylesheets/collector/additions.css` | run in Task 2 and again at the end |

## Runs

- Task 1, `bin/rspec spec/system/icon_stroke_spec.rb` on the shipped CSS: 5 examples, 4 failures (AC-1.1, AC-1.2, AC-1.3, AC-1.5), all on stroke weights; AC-1.4 passed. After Task 2: 5 examples, 0 failures; `spec/design_system_files_spec.rb` 7 examples, 0 failures.
- Integration: `bin/rspec spec/system/icon_stroke_spec.rb spec/design_system_files_spec.rb spec/system/design_system_deck_rules_spec.rb spec/system/design_system_deck_components_spec.rb spec/system/collection_views_spec.rb spec/system/card_page_spec.rb`: 87 examples, 0 failures (seed 58757). `bin/ci checks`: passed (RuboCop, YARD, the comment ratchet, Brakeman, bundler-audit, importmap audit).
- The full `bin/ci` runs at push time through the pre-push hook; its result is in the pull request.

## The previews (AC-2.2)

Measured on 2026-11-10 in headless Firefox, over `python3 -m http.server` on the worktree, with the classic scrollbars the suite pins. Computed `stroke-width` and drawn width of every stroked, rendered icon:

| Preview | Icons |
|---|---|
| Badge | 3 at 12px, stroke 2.5 |
| ItemPage | 7 at 12px, stroke 2.5; 15 at 16px, stroke 2 |
| ItemTile | 2 at 12px, stroke 2.5 |
| Button | 2 at 16px, stroke 2 |
| Input | 1 at 16px, stroke 2 |
| Menu | 3 at 16px, stroke 2 |
| CollectionTable | 4 at 16px, stroke 2 |
| FilterBar | 4 at 16px and 8 at 14px, stroke 2 |
| ViewSwitch | 2 at 14px, stroke 2 |
| Chip | 2 at 14px, stroke 2 |
| TabBar | 4 at 22px, stroke 1.5 |

Every one has the attribute `stroke-width="1.5"`: `git grep -ho 'stroke-width="[^"]*"' -- docs/design-system/previews` gives 195 matches, all `"1.5"` (spec 060 AC-7.5 stands).

The nine previews that gained the link, before (link removed by script) and after, at 1280px, light, 1x: page sizes are the same (1280×915) and the differing pixels are in the tens (6 to 73), the icons, except `ItemTile`, 169 pixels: the missing-image fallback of the Thoughtseize tile (`c-tile--owned-none`) is at full opacity after, where the export faded it to 45%, which is the app's own rule (spec 021, `UnownedTile.md`) and the first change the spec allows. `CollectionTable`'s phone frame wrapped no line (13 differing pixels in all, the 16px icons): the second allowed change did not show. The shots of `ItemTile` and `Badge` are in `screenshots/preview-ItemTile-before-after.jpg` and `screenshots/preview-Badge-before-after.jpg`.

## Visual review (AC-1.7)

The shots in `screenshots/`, from the real pages with factory data and placeholder printings (headless Firefox, `data-theme` set in the page, classic scrollbars; "before" is the old weight, stroke 1.5 at every size, injected as a `<style>` on the same page after the "after" shot): `legality-*` (the card page's Format legality grid), `badges-*` (the real partials in `c-badge`: Matched by its collector line, Read, Printing not confirmed, Foil), `collection-*` (the page head's buttons, the search field and the view switch), `tablerow-*` (a table row, its More button), each `light` and `dark`, `1x` and `2x`.

What the shots show (read by the author; the maintainer's review is below): the 12px check and cross carry the weight of "Legal" and "Not legal" in both themes, the badge check matches "Read" and "Matched by its collector line", the warning triangle and the foil star read as before, the 14px to 16px icons (Scan, plus, search, Grid, Table) balance their 600-weight labels, and the More dots (stroked circles, radius 1.5, at stroke 2) are slightly larger and stay apart.

Maintainer's visual review: approved as shown (2026-11-10, relayed by the coordinator), the shots of `screenshots/` at 1x and 2x, light and dark, with the rulings of decision 1 unchanged.

## Not measured

- Headless Selenium could not read the browser's console in this setup, so "no console error" is not claimed.
- The preview measures are a one-time headless run, not a suite example (previews are static documents; AC-2.2 is a verification criterion).

## Implementation review

**SPEC-ALIGNED WITH MINORS** (Opus, read-only, `sdd-review` Mode B, 2026-11-10; 0 blocking, 0 major, 5 minor). It confirmed from the repo: the CSS block's selectors cover every component that draws a stroked icon below 20px and none of `spec/design_system_files_spec.rb`'s block guards matches it; `git diff main...HEAD -- app` is `additions.css` alone and `app/views/icons` is unchanged; 27 previews link `additions.css` (only `Cover` and `ManaCost` don't, and neither draws a stroked icon) and the 195 attributes are all `"1.5"`; no document still says "1.5px stroke" or `stroke-width="2"`; each example of `icon_stroke_spec.rb` fails before the CSS and passes after, with no silent-pass path (every selection and page must be non-empty).

The minors and what was done:

1. The README said the stroke is `30 ÷ size` "in px", which reads as the stroke being in px: now "`30 ÷ size`, with the size in px, rounded to a half" (taken).
2. The README had no "App additions (spec 063)" line, as every spec that adds rules to `additions.css` has: added (taken).
3. AC-1.6 is tested for "no stroke" only, not "drawn as before": the badge shots (`badges-*`) show the star in place and at its size; no change to the star's rule exists in the diff (recorded, not tested further: the star is `fill="currentColor"` and no rule here sets its size).
4. The maintainer's AC-1.7 review was pending at the review; since given and recorded above (approved as shown).
5. The table's "Set" header is clipped to "Sei" in `tablerow-*.jpg`, before and after alike: not this branch's doing (cause not investigated), reported to the coordinator as a possible issue, not changed here.

## Distilled

2026-11-10, by `distill-feature` before the merge: the rules of spec 063 are in `docs/design-system/README.md` (Iconography, and the App additions line for `additions.css`), which is the area doc of the design system (it has no Sources table or Distillation log; the Iconography bullet and the App additions line name spec 063). `docs/architecture/README.md`'s list of what the design-system docs cover names spec 063. The index row reads Frozen with the plan owed a retirement after the merge; the spec's header carries its frozen line. Lesson: `docs/lessons/2026-11-10-nine-previews-did-not-load-additions-css.md`.
