# Verification: spec 077, the deck shape panel at extreme counts

Spec 0.3.2, plan `plan.md` (commit `8bee6a51`). Issue [#320](https://github.com/plainprogrammer/Collector/issues/320); the follow-up for the mana-label band is [#330](https://github.com/plainprogrammer/Collector/issues/330).

## Acceptance criteria

Examples are in `spec/models/mtg/deck_shape_spec.rb` (model), `spec/requests/deck_shape_panel_spec.rb` (request) and the nested `describe "extreme counts (spec 077, #320)"` of `spec/system/deck_shape_panel_spec.rb` (system, headless Firefox).

| AC | Proved by |
|---|---|
| AC-1.1 | model "writes 0 to 999 as they are and 1,000 up with one decimal under 10,000, whole from there, half up (AC-1.1)" (all 17 values, none longer than four characters) and "rounds 1,349 down to 1.3k and a count that reaches 1,000 of its unit moves to the next, 9,999,500 being 10m" |
| AC-1.2 | request "abbreviates a column's count from 1,000 and keeps the exact numbers in the label and the legend (AC-1.2)" |
| AC-1.3 | system "keeps every curve count inside its column and the panel inside its box at every width, in both themes (AC-1.3)" (320, 345, 360, a 366px and a 640px frame, the 1280px aside); can fail: "the full count in the 6+ column overflows its column at a 320px and a 345px viewport (AC-1.3)" |
| AC-2.1 | request "abbreviates a segment's label and keeps the bar's label and the caption exact (AC-2.1)"; a segment of 44 reading "U 44" is covered by spec 069's existing request example ("U 6", "R 3": below 1,000 nothing changes) |
| AC-2.2 | system "keeps every mana label on one line inside its segment at every width, in both themes (AC-2.2)"; can fail: "a label written in full wraps inside its segment at a 320px viewport (AC-2.2)" |
| AC-2.3 | spec 069's request example "marks a segment under 10% of the symbols narrow in the page (AC-4.6)", unchanged and green |
| AC-3.1 | system "ends every Card types count at one x with the suffix at the row's edge, nothing cut off, at every width (AC-3.1)"; can fail: "flex rows with a 4.5rem suffix put the 9,999 proxy row's count left of the others' (AC-3.1)" |
| AC-3.1b | system "keeps a five-digit row inside the list with the counts at one x at a 320px viewport, the name wrapping (AC-3.1b)"; can fail: "without the name cell's wrap rule the name spills over its cell (AC-3.1b)" |
| AC-3.2 | system "keeps each empty suffix cell at its 4.5rem floor and the counts at one x when no row has a proxy (AC-3.2)"; can fail: "without the floor the empty suffix cells collapse (AC-3.2)" |
| AC-3.3 | `spec/system/design_system_deck_components_spec.rb`, "DeckShape card types (AC-2.5)", unchanged and green after the CSS |
| AC-4.1 | model "gives one item per colour, each but the last ending in the separator, and `caption` is the items joined (AC-4.1)" and "has one item with no trailing separator for one colour, and none for no colour (AC-4.1)"; the 069 `caption` examples (lines 253, 293, 315) unchanged and green |
| AC-4.2 | request "sets each caption item as a `c-manacap__item` span and the paragraph's text is the caption string (AC-4.2)" |
| AC-4.3 | system "keeps every caption item on one line and no caption line starting with a dot at every width (AC-4.3)"; can fail: "without the nowrap rule an item splits at a 345px and a 360px viewport and a line starts with a dot in a 366px frame (AC-4.3)" |
| AC-5.1 | `docs/design-system/components/DeckShape.md`, read against the code and the CSS (batch C's report and the supervisor's reading) |
| AC-5.2 | the three previews' caption paragraphs and `DeckShape.html`'s width comment, read |
| AC-5.3 | `docs/architecture/collection-and-lots.md` (the panel's paragraph, two Named constants rows, the Issues bullet) and `docs/specs/README.md` (the 077 row, 060's and 069's "Superseded by"), read |
| AC-6.1 | `git diff --stat origin/main...HEAD -- app/` names `app/models/mtg/deck_shape.rb`, `app/views/mtg/deck_shapes/_parts.html.erb`, `app/assets/stylesheets/collector/additions.css` only; the CSS diff is inside the card types and mana bar blocks (10 insertions, 4 deletions) |
| AC-6.2 | `spec/deck_core_spec.rb`, `spec/requests/query_counts_spec.rb` and spec 069's AC-5.1 to AC-5.3 examples green and unchanged (the AC-5.3 example's comment is rewritten, its assertions are not) |

## The failing variants (each proved able to fail)

Each "can fail" example injects the old text or the old rule into the page and expects its predicate to be false; all six pass, so each predicate can fail. Batch B also ran a scratch copy of the AC-3.1b variant with the measurement printed: with `overflow-wrap:normal` on the name cell at a 320px viewport it reads `rowOver 0, cut 1, rights [184.6, 184.6]`, so the predicate goes false through `cut` (a name spilling over its cell), not through count misalignment: the variant is the proof that the wrap rule is tested. The red run before the code (commit `9c1d80a2`): the request examples failed 3 of 4 (the fourth, "keeps the types' counts and suffix exact", guards what exists and can't be red; the plan's "the four examples fail" was imprecise), the system examples failed 5 of 12 groups (AC-1.3 at 320, 345 and the 366px frame; AC-2.2 at 320 and 345; AC-3.1; AC-3.1b on count misalignment; AC-4.3 for lack of items), the six variants and AC-3.2 green.

## Measurements taken before the plan (2026-11-11, headless Firefox, the unchanged code)

- **Four limits, spec 069's fixture** (a table is in the spec): the 6+ count's room in its column was +0.28px at a 360px viewport, −1.85px at a 360px frame, **−5.43px** at a 320px viewport, +1.43px in the aside; the mana labels wrapped onto two lines at 320px; the Card types counts of the "1,234 proxy" row sat 7.2px left of the others'; the caption broke inside "Black / 2,591" and ended lines with "·".
- **The label band:** at a 320px viewport (a 236px bar) a mana label fits its segment from 14% of the bar for four characters ("U 44"), 17% for five ("W 999") and 20% for six ("W 2.6k"), on a half-percent grid (`#330` offers closing it).
- **The leading dot:** a sweep of the old caption in frames of 255px to 468px (steps of 3px) found a line starting with "·" at 16 of 72 widths, among them frames of 285px, 321px, 363px, 366px, 369px, 402px and 438px; a 366px frame is an interior of 269px on a Mac and 272px on the Linux runner, both in the list. At a 320px viewport the old caption breaks between colours (no item split); at 345px and 360px it splits "Green / 2,591" and "Black / 2,591".

## The supersession grep (plan, "The existing examples this changes")

`git grep -n -i -E "c-curve__count|c-manabar__seg|c-manacap|c-types|\.caption\b|countRoom|1,357|2,591|4\.5rem" -- spec docs/design-system docs/architecture app ':!.kamal/secrets'`, read hit by hit; the dispositions are the plan's table. Edited: the AC-5.3 comment of `spec/system/deck_shape_panel_spec.rb` (stale), `DeckShape.md`, three previews, `docs/design-system/README.md` (the class list), the area doc. Kept: the `caption` examples of the model and request specs (the string is unchanged), `design_system_deck_components_spec.rb` (builds its own markup, run green after the CSS).

## Deviations

1. The request spec's fourth example is a guard and green before the code (plan Task 2 Step 3 said all four fail; recorded above).
2. Spec 0.3.1 (a PATCH, spec only) was made while planning: the table's caption column corrected, AC-4.3's variant widths changed and a 366px frame added, the label shares measured (14%, 17%, 20%), AC-3.1b's "not cut off" and its variant (the spec's changelog row). The plan, reviewed twice, follows it.
3. The follow-up issue #330 was filed by the coordinator (decision 2 ruled option A by the maintainer, 2026-11-11).
4. A 0.3.2 row of the spec cites #330 (a pointer only).
5. The spec's Notes say to wait about 0.6s after a theme switch; the geometry examples don't (`testing.md` forbids sleeps, and the second reading in the other theme is a guard, since layout cannot depend on the theme; the helper's comment says so).
6. The non-functional requirements describe the "before" shots as made by injecting the old rules and stubbing the abbreviation; they were taken from the unchanged code at the start of the branch (the same fixture, run before any app change), which is the real "before", not an emulation.
7. `docs/architecture/collection-and-lots.md`'s Sources and Distillation log are written by `distill-feature` at the end (the plan leaves them there), not by Task 5.

## Screenshots

In [`screenshots/`](screenshots/): factory data, placeholder card images; each panel in `-light` and `-dark`, "before" being the unchanged code, "after" this branch. The fixture is spec 069's worst case (a 6+ column of 1,357, five equal mana segments of about 2,591, 20 lands) plus a colourless Instant proxy of 9,999 that gives a 10,002 column and a "9,999 proxy" Card types row.

- `before-phone360-*`, `after-phone360-*`: a 375px frame (a 360px viewport), the fold open.
- `before-phone320-*`, `after-phone320-*`: a 335px frame (a 320px viewport).
- `before-w640-*`, `after-w640-*`: a 640px frame (the fold again).
- `before-wide1280-*`, `after-wide1280-*`: the 320px aside at 1280px.

Every shot was looked at. Before: the 6+ count "1,357" crowds its column and the label "W 2,591" touches its borders (at 320px it wraps onto two lines and is cut off), the "Creatures" and "Instants" counts sit left of the "Artifacts" and "Lands" counts, and the caption breaks inside a colour. After: the counts read "10k" and "1.4k" over their columns, every label reads "W 2.6k" on one line inside its segment, every Card types count ends at one x, and the caption breaks only between colours; both themes read alike.

## Implementation review

SPEC-ALIGNED WITH MINOR FINDINGS (round 1, `sdd-review` Mode B, read-only Opus review of `46568b3d..86e54034` at spec 0.3.2, with the supervisor's fresh run beside it: 253 examples, 0 failures over the model, request and system deck-shape specs, `design_system_deck_components_spec`, `deck_page_spec`, `design_system_files_spec`, `deck_core_spec`, `query_counts_spec` and `deck_pages_spec`; rubocop clean on the four changed Ruby files; the comment ratchet "3 added or changed public objects, all with a comment")

- **Checked, no finding:** `short_count` by hand (1,049, 1,050, 9,949, 9,950, 999,499, 999,500, 1,250,000, 9,999,500, 2,000,000,000), `caption` unchanged, the YARD comments, what the partial abbreviates and what stays exact, the CSS (only the two DeckShape blocks, tokens only), AC-6.1 (the app diff is exactly three files), the unchanged guards (`deck_core_spec`, `query_counts_spec`, specs 060 and 069), the documents against the code, 20 example titles cited here (each exists once), and the screenshot pairs.
- **No blocking or major findings.** Minor findings and their resolution:
  1. The area doc's Sources and Distillation log had no spec 077 entry: left to `distill-feature` (deviation 7), done in the distillation commit.
  2. Three geometry predicates would pass if the panel were not drawn, and "all seven columns" was not counted: fixed in `430295a3` (`measure` returns the column count and the narrowest column, `counts_fit?` requires seven columns of positive width, `counts_aligned?` requires positive right edges).
  3. Two "can fail" examples proved only that the predicate could be false: fixed in `430295a3` (the AC-3.1 variant expects the count edges to spread over 5px, the AC-4.3 variant at 345px and 360px expects an item on two lines).
  - Nits: the version and unrecorded deviations (5, 6, 7 above, fixed here); the literal "U 44" of AC-2.1 had no example of its own (a request example "writes counts under 1,000 in full in a slot of fixed width (AC-2.1)" was added in `430295a3`); "never longer than four characters" overstated past 999m (the area doc and `DeckShape.md` now say "through 999m", `366ae43c`).
- **Owed to CI, not defects:** two checks have little margin and were proved on a Mac only: AC-2.2's 0.44px at a 320px viewport, and the 366px frame's leading dot (an interior of 272px on the Linux runner, inside the measured range). If either fails on the runner, the spec is updated through `sdd-spec-update` before a bound moves.
