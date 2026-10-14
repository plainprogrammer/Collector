# Verification: Mark Unowned Tiles Without Fading the Card Image (spec 021)

**Spec:** [spec.md](spec.md) v1.1.0 · **Plan:** [plan.md](plan.md) · **Branch:** `021-unowned-tile-marker` · **Issue:** [#65](https://github.com/plainprogrammer/Collector/issues/65)

## Red runs

Each example was seen to fail before its change (headless Firefox for the browser examples).

Before the marker was in the partial, with the export's fade standing (6 failures of 46 examples in the four files):

```text
entries_search_spec  expected: [["S44 · 51", "JA"], ["Not owned"]]   got: [["S44 · 51", "JA"]]
entries_search_spec  expected: ["Not owned", "Not owned"]            got: ["S26 · 30EN", "S27 · 31JA"]
identities_spec      the unowned tile's last row was its set and language row
unowned_tile_spec    expected to find visible css "#tile_catalog_entry_2 a.c-tile .c-tag" with text "Not owned" but there were no matches
unowned_tile_spec    expected "Lightning Bolt Lightning Bolt S108 · 117 JA" to end with "Not owned"   (the link's accessible name)
unowned_tile_spec    expected: [{"chain" => ["1 none normal none"], "drawn" => ["none"]}]
                          got: [{"chain" => ["0.45 none normal none", "1 none normal none"], "drawn" => ["none"]}]   (image, placeholder, both themes)
card_image_fit_spec  expected: "1"   got: "0.45"
```

With the marker in the partial and no style change (AC-3.3: the browser examples without the block):

```text
unowned_tile_spec    add buttons at 1280px: expected: 1 (distinct top edge)   got: 2
unowned_tile_spec    add buttons at 390px, per row: expected: [1, 1]          got: [2, 2]
unowned_tile_spec    chain "0.45 none normal none" on the image and the placeholder, as above
card_image_fit_spec  expected: "1"   got: "0.45"
```

So the fade and the uneven row are each caught by an example, and the examples pass with the block in place.

## Measured in the browser, with real card images

A dev server on this worktree, seeded with 90 real printings through the app's own `Catalog::Refresh` (the mock-up's `seed.rb`: three of the ten Lightning Bolt printings in the results owned, one unowned printing with no image). Search results for "lightning bolt" (13 tiles, 10 unowned, 12 Scryfall images loaded, 1 placeholder), headless Firefox, read with `getComputedStyle` from every tile's image or placeholder and from each ancestor up to its `c-tilecell` (`opacity filter mix-blend-mode backdrop-filter`):

| | Before (`origin/main`'s partial and stylesheet) | After (this branch) |
|---|---|---|
| Unowned image or placeholder, all four views | `0.45 none normal none` on all 10 | `1 none normal none` on all 10 |
| Their ancestors up to the cell | `1 none normal none` | `1 none normal none` |
| Owned tiles (3) | `1 none normal none` | `1 none normal none` |
| "Not owned" markers | 0 | 10 on unowned, 0 on owned, 0 cut off |
| Elements in an unowned slot besides the image | 0 | 0 |
| 1280px: rows with level add buttons | 3 of 3 (2 mixed) | 3 of 3 (2 mixed): `600.3`; `1010.6` × 7; `1364.9` × 3 |
| 390px frame: rows with level add buttons | 7 of 7 (3 mixed) | 7 of 7 (3 mixed) |
| 390px frame: sideways scroll | no | no |

The figures were the same in the light and the dark theme. On the printings page ("Show all 57 printings", 12 tiles, 9 unowned): 9 markers, every image or placeholder at opacity `1`, one add-button top edge per row.

## Screenshots

[screenshots/](screenshots/), six images, about 440 KB in all: search results `after` at `1280` and `390`, each `light` and `dark`, and `before` at `1280` in both themes. Each is cut to the part that shows the tiles (at 1280px the first group and the mixed row under it; at 390px three rows of the second group, two of them mixed, with the placeholder) and saved as JPEG at quality 40. The full-page captures, the 390px `before` pair and a shot of the printings page were looked at and are not kept: at this weight the 1280px pair shows the fade well enough, and the printings page is covered by its request example and the measurement above. The 390px shots are of a fixed-width frame, since headless Firefox won't open a window that narrow. Every kept image was looked at again after recompressing; the "Not owned" tags, set codes and quantities read clearly in each.

- **Before:** unowned images are washed out against the page in both themes; the placeholder's name and set number are faint.
- **After:** every image is at full strength; each unowned tile has a dashed frame and a "Not owned" tag on its own line under the set and language tags, readable in both themes; owned tiles show `×4`, `×1`, `×2` and no tag; the placeholder ("Lightning Bolt", "SLD · 2579") is readable and tagged. In the mixed rows (the second at 1280px; the first and third shown at 390px) the Add buttons are level, with an empty line under an owned tile's tags. Nothing is cut off and nothing scrolls sideways at 390px.
- In each 1280px shot, before and after, the third tile of the first row sits 2px high: the pointer rested on it after the sign-in click, and that is the tile's hover lift (the export's `a.c-tile:hover`), there before and after.

## Acceptance criteria

| Criterion | Held by |
|---|---|
| AC-1.1 | `spec/system/unowned_tile_spec.rb`, "shows the image and the placeholder as supplied, in both themes" (computed style of the element and its ancestors, pseudo-elements, one child in the slot); the request example "marks a printing you don't own that has no image, and lays nothing over an image"; the measurement above with real images |
| AC-1.2, AC-1.3 | `spec/requests/catalog/entries_search_spec.rb`, "shows owned quantities and marks printings you don't own as not owned"; the browser example "says Not owned under the tile, in the link's name, and nothing on an owned tile" |
| AC-1.4 | The first browser example (placeholder at `1 none normal none`) and the second request example |
| AC-1.5 | `spec/requests/catalog/identities_spec.rb`, "marks the printings you don't own as not owned"; the printings page's measurement above |
| AC-1.6 | The second browser example: Firefox's computed accessible name of the link ends with "Not owned" (it read "Lightning Bolt Lightning Bolt S108 · 117 JA" before) |
| AC-1.7 | The third browser example (390px frame: no sideways scroll, marker not cut off) and the four `after` screenshots |
| AC-1.8 | `spec/system/quick_add_spec.rb`, "adds a copy without reloading the page and announces it": the marker is there before the add; after it the tile shows `×1` and no marker |
| AC-2.1 | The third browser example, at 1280px (owned, unowned, unowned, owned in one row) and in the 390px frame (each row asserted mixed); the measurement and screenshots above |
| AC-2.2 | By reading: `scanners/_candidate.html.erb` and `scanners/_add_buttons.html.erb` render `c-scanner__adds` and `c-scanner__add`, never `c-tile__add`. The scanner's system specs pass unchanged |
| AC-3.1 | `git diff --stat origin/main -- app/assets/stylesheets/collector/components.css app/assets/stylesheets/collector/tokens.css` prints nothing |
| AC-3.2 | `spec/design_system_files_spec.rb`, "the unowned tile override (spec 021)" (two examples) |
| AC-3.3 | The second red run above |
| AC-3.4 | By reading: `docs/design-system/components/UnownedTile.md`, the README's "App additions (spec 021…)" line, and `TileAdd.md`'s marker row and foot-of-cell bullet |

**How "no shipped rule fades or filters a tile's card image" was checked.** Three ways: computed style in the browser on test pictures (the suite, every run); computed style in the browser on real Scryfall images in all four views (above, once); and a text check in `spec/design_system_files_spec.rb` that the only rules naming `c-tile` with `opacity`, `filter` or `mix-blend-mode` in the app's stylesheets are the export's fade and this block's override. The other `opacity` in the shipped CSS is the disabled button's (`components.css:21`).

**Verified only by reading:** AC-2.2, AC-3.4, the marker's contrast (the tag's `ink-muted` on `surface`, which the design system states as at least 6:1 in both themes; not measured here), and the copy against the voice rules. Not tried: a real screen reader (the browser's computed accessible name stands in for it), and a phone (the 390px frame stands in for it).

## Local gate

`bin/ci` on `455f7c7` (the last commit before this file's update; the commit after it changes only this file):

```text
✅ Setup passed in 5.31s
✅ Style: Ruby passed in 1.53s
✅ Security: Brakeman code analysis passed in 5.86s
✅ Security: Gem audit passed in 0.62s
✅ Security: Importmap vulnerability audit passed in 1.53s
1354 examples, 0 failures, 1 pending
✅ Tests: RSpec passed in 3m7.57s
✅ Continuous Integration passed in 3m22.42s
```

The one pending example is `spec/system/art_agreement_spec.rb`, which needs the art spike's cache (`COLLECTOR_ART_AGREEMENT`), as on `main`.

## Review

A read-only review of the branch (an Opus subagent, 2026-10-13) found nothing blocking, nothing wrong with the override's cascade or the add-button rule's reach, and no missed place an unowned tile renders. Its points, all taken in `5bdece6` and `0f8fd38`:

- The phone-width row check depended on the factories' set-code sequence: at some counter values the rows came out owned/owned and unowned/unowned and the check passed without the rule. The four entries now share a set with numbers in order, and each row is asserted to be mixed.
- The stylesheet check missed a rule written inside a one-line media query or with its selectors on several lines. Its pattern no longer stops at a line.
- AC-1.8 had no assertion that the marker goes after an add. `spec/system/quick_add_spec.rb` now asserts the marker before the add and its absence after.
- Wording: the accessible name in decision 6 is an example; the plan says what the stylesheet check can't see; `UnownedTile.md` says which examples change when the rule is deleted; the spec says it replaces half of spec 019's AC-1.8.

After those changes the examples were broken once more on purpose (the add-button rule removed, a fading rule added inside a media query): the block's shape, the stylesheet check (`got: ["{opacity:.45;}", "{opacity:.6;}", "{opacity:1;}"]`) and the row check (`got: [[2, 2], [2, 2]]` for `[[2, 1], [2, 1]]`) each failed.

A second review, by the coordinator, found no code defect and confirmed the after screenshots against the chosen look. Its points, taken in `4c231a6` to `455f7c7`: `TileAdd.md` is the app's own document and never described the fade (a mistake carried from the brief), so the spec, plan and `UnownedTile.md` are corrected and `TileAdd.md` now documents the add control's place; the stylesheet check reads declarations only, so a comment can't fail it; a block variable no longer shadows a `let`; the screenshots went from 2.1 MB to about 440 KB; the spec's status says what is approved.

Not taken: editing spec 019's own document to point here (it is another spec's approved text; this spec states the replacement instead).

## Commits

```text
455f7c7 docs(021): say what is approved and correct TileAdd's ownership (spec v1.1.0)
869319d docs(021): document the add control's place in TileAdd, the app's own document
c1a4477 test(021): read declarations only in the fade check; rename a shadowing variable
4c231a6 docs(021): cut the screenshots to the tiles and recompress them
2fb226b docs(021): record the verification
0f8fd38 docs(021): take the review's points on the spec, plan and pattern
5bdece6 test(021): fix the row order, widen the fade check, cover the marker after an add
5004e22 docs(021): add before and after screenshots of search results
502f55f docs(021): document the unowned tile pattern
d71d3da fix(021): show an unowned tile's image as supplied and keep its row level
f349541 feat(021): say "Not owned" on the tile of a card you don't own
b9fd4ba docs(021): plan the unowned tile's marker
76e62fe docs(021): specify the unowned tile's marker (#65)
```

Then this file's update. The branch is pushed; the pull request is the coordinator's to open.

## Left for the maintainer

- Decisions 2 to 8, put to the maintainer in the pull request.
- The pull request, and the roadmap's housekeeping note for #65 (the coordinator adds it; PR #83 edits that lane).
- Upstreaming: the published design system's `ItemTile` should drop the fade at its next export.
- The open question on the `×N` badge (spec, Open Questions).
