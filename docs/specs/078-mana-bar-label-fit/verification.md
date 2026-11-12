# Verification: spec 078, a mana bar label fits its segment or isn't drawn

Spec 0.2.1, plan `plan.md` (commit `0474d8fa`). Issue [#330](https://github.com/plainprogrammer/Collector/issues/330). Approach D1, ruled by the maintainer on 2026-11-12.

## Acceptance criteria

Examples are the nested `describe "mana label fit (spec 078, #330)"` of `spec/system/deck_shape_panel_spec.rb` (headless Firefox), inside the spec 077 block. "Four", "five" and "six" are the three band decks (W 12, U 13, B 15, R 16, G 44; W 120 … G 350; W 1,200 … G 3,900).

| AC | Proved by |
|---|---|
| AC-1.1 | system "draws each label on one line inside its segment or not at all, centred, at every width, for the four-label deck" (and "five-label", "six-label"): 320, 345, 360, a 366px and a 640px frame and the 1280px aside, both themes; "draws some labels and clips others at a 320px viewport, so the rule is seen acting and is not vacuous" ("W 12", 29.2px in a 27.83px segment, is clipped and at least one label is drawn) |
| AC-1.2 | the same three examples (`decided?`: a label at least 0.5px narrower than its fractional content width is drawn, one at least 0.5px wider is not); "draws a label at 360px and in the aside where it fits, a 12% segment's among them" ("W 12" in 32.6px and 33.6px of content) |
| AC-1.3 | the same three examples (`centred?`: a drawn label's centre within 1px of its segment's); can fail: "without the segment's first item the label sits off its segment's centre" (`::before{content:none}` leaves a drawn label several pixels off) |
| AC-1.4 | can fail: "with the old layout a label wraps onto two lines at a 320px viewport" (the old layout restored by a `<style>`: "W 12" on two lines, `tidy?` false) |
| AC-1.5 | system "draws every label of the five-equal-segment fixture at every width, none clipped"; spec 077's own AC-2.2 example and its variant, unchanged and green |
| AC-1.6 | spec 069's request example "marks a segment under 10% of the symbols narrow in the page (AC-4.6)", spec 077's AC-2.3 reading and every request example of the bar's markup, `aria-label` and caption, unchanged and green; `git diff --stat origin/main...HEAD -- app/` shows no view or model change |
| AC-2.1 | `docs/design-system/components/DeckShape.md`: the "A label that does not fit is not drawn" and "Browsers" bullets in the mana bar list and the Width paragraph's Known limit (the band replaced; the Card types limit stays), read against the CSS |
| AC-2.2 | read: `docs/design-system/README.md` (the Charts rule line 35, "a segment too narrow for its label shows them in the caption beneath", still true; line 139 lists classes only) and the three previews (draw the real stylesheet, state no limit): no change |
| AC-2.3 | `docs/architecture/collection-and-lots.md` (the panel's paragraph replaced the old known-limit sentence, the Issues bullet no longer lists #330 as open, Sources names spec 078 and marks 077's option A closed) and `docs/specs/README.md` (the 078 row with 077 in "Supersedes", 078 in 077's "Superseded by"), read; the Distillation log row is the `distill-feature` step's |
| AC-2.4 | **owed to the maintainer**: the check of the bar on a phone (WebKit), below |
| AC-3.1 | `git diff --stat origin/main...HEAD -- app/` names `app/assets/stylesheets/collector/additions.css` only (12 insertions, 2 deletions), inside the mana bar block; no colour, font family or spacing literal, no class (`::before` is not a class); `spec/design_system_files_spec.rb` green unchanged |
| AC-3.2 | `spec/deck_core_spec.rb`, `spec/requests/query_counts_spec.rb`, spec 077's and 069's examples and `spec/system/design_system_deck_components_spec.rb` green unchanged |

## Runs

- Task 1, on the unchanged CSS (`bin/rspec spec/system/deck_shape_panel_spec.rb -e "mana label fit"`, 8 examples, 5 failures, as the plan traced): **red** the three per-deck "draws each label …" examples, "draws some labels and clips others …" and "can fail: without the segment's first item …"; **green** "draws a label at 360px and in the aside where it fits", the fixture example and "can fail: with the old layout …". The six-label deck was red at 320px and 345px ("W 1.2k" and "U 1.8k" on two lines there). Commit `da6dbb2f`.
- After the CSS (commit `acf50959`): the nested describe 8 examples, 0 failures; the whole `spec/system/deck_shape_panel_spec.rb` 37 examples, 0 failures.
- 2026-11-12, after every task (documents and screenshots included): `bin/rspec spec/system/deck_shape_panel_spec.rb spec/requests/deck_shape_panel_spec.rb spec/models/mtg/deck_shape_spec.rb spec/system/design_system_deck_components_spec.rb spec/design_system_files_spec.rb spec/deck_core_spec.rb spec/requests/query_counts_spec.rb`: **181 examples, 0 failures**.
- The full `bin/ci` is run once with the coordinator's slot before the push; its result is in the pull request.

## The existing examples this changes (the plan's grep)

Command (2026-11-12): `git grep -n -i -E "c-manabar|manacap|labels_fit|narrow" -- spec docs/design-system docs/architecture app ':!.kamal/secrets'`, read hit by hit. No existing example changes: spec 077's label examples measure the five-equal-segment fixture, all of whose labels fit (46.2px of content against a 43.56px label on a Mac, 44.70px on Linux), so none is clipped; the request examples read markup that does not change; `design_system_deck_components_spec` builds a 288px bar of "U 44" and "R 16", both of which fit. The two doc hits (`DeckShape.md`, the area doc) are edited, as the plan's table says.

## Evidence

Screenshots in `docs/specs/078-mana-bar-label-fit/screenshots/` (24 JPEGs, factory data, placeholder printings): the mana symbols part of the "four" deck (W 12, U 13, B 15, R 16, G 44) and the "six" deck (W 1,200, U 1,800, B 2,000, R 2,100, G 3,900) at a 320px viewport, a 360px viewport and in the 1280px aside, in both themes, named `before-|after-<four|six>-<phone320|phone360|wide1280>-<light|dark>.jpg`. "Before" is the old layout restored by a `<style>` (`flex-wrap:nowrap`, `overflow:visible`, no `::before`, a shrinkable label), not built from `main`. What they show:

- 320px, four: "before" "W 12" wraps onto two lines ("W" over "12") and is cut off; "after" the segment is empty and the caption (below) carries "White 12 · 12%".
- 320px, six: "before" "W 1.2k" and "U 1.8k" wrap and are cut off; "after" both are absent, "B 2k", "R 2.1k" and "G 3.9k" are drawn.
- 360px and the aside: "W 12" fits and is drawn in "after" (and was drawn before); "W 1.2k" is absent in "after" where it wrapped in "before", "U 1.8k" is drawn.
- The first shot of each theme and width was read before the rest were trusted. The shots were taken on a Mac: "R 2.1k" at 320px (44.30px of content against a 43.56px label) is drawn there and would be clipped on the Linux runner, where the label is 44.70px (spec decision 3).
- The browser console could not be read in this setup (headless Selenium); no claim of "no console error" is made.

## Owed to the maintainer: the phone check (AC-2.4)

The suite runs the rule in headless Firefox only. The rule relies on flex line breaking and a percentage height in a stretched flex item (`DeckShape.md`, "Browsers"). **To record here when done:** open a deck of mana symbols in the 10-20% band (a deck whose white is about 12% of its coloured symbols, with a four-character label) on a phone in Safari or another WebKit browser, at 320px or 360px wide, and confirm that no label wraps onto two lines or is cut off, a label that fits is drawn, and a label that does not is not drawn. Status: **not yet done**.

## Implementation review

SPEC-ALIGNED WITH FINDINGS (3 minor, 2 nits; none blocking or major).

Mode B, Opus, read-only (it read the branch and did not run the suite), 2026-11-12, after commit `6f1280ab`. It found every AC met by the CSS, the examples and the documents; the examples' "drawn" and "clipped" predicates sound, neither failing variant able to pass by accident, and the Linux risk low ("W 12" about 30.0px against a 27.83px segment is still clipped; the fixture's 46.2px leaves 1.5px over a 44.70px label); the CSS in scope (AC-3.1) with an accurate comment; the screenshots matching this document (10 of the 24 looked at); no shipped spec edited; no throwaway file committed. Findings and what was done:

- Minor: AC-2.3's Distillation log row is not in the area doc yet. It is the `distill-feature` step's, run after this review; done there.
- Minor: the area doc's Sources line for 078 left out spec 077's Open Questions, which the spec's Supersedes table lists. Fixed (commit after `6f1280ab`).
- Minor: "before-four-phone320" shows "12" only slightly cut off; the two lines are the clearer evidence. Accepted as it is (the verification text says "wraps onto two lines").
- Nit: the "about 8px off" of the AC-1.3 variant is about 7px by geometry. Fixed (now "several pixels").
- Nit: commit trailers name Sonnet 5.5 and Opus 5.5 by session. Left as they are (the plan says earlier commits keep their trailer).

Not verifiable by this review and still to come: the full `bin/ci` and the Linux CI run, and the maintainer's phone check (AC-2.4, above).
