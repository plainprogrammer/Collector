# Verification: Fit Card Images Without Cropping (spec 019)

**Spec:** [spec.md](spec.md) v1.3.0 · **Plan:** [plan.md](plan.md) · **Branch:** `019-uncropped-card-images`

## Table thumbnail, measured

Measured in the suite's browser (headless Firefox, window 1400px wide) with the plan's measurement script, on the commit before the thumbnail's rule and on the commit that adds it. Each text gives the image thumbnail's and the empty thumbnail's content boxes and row heights, where a 488 × 680 picture (Scryfall's `normal` size) is painted according to the computed fit, and the picture's pixels in a screenshot of the thumbnail (its 1px border included).

Before (`27c13d8`):

```text
img: box 24 × 34, row 53
span: box 24 × 33.517, row 52.517
object-fit fill: a 488 × 680 picture painted 24.0 × 34.0 (1.67% taller than its proportions)
pixels: 24x34+1+1 of 26x36
```

After (`68ace07`):

```text
img: box 24 × 33.517, row 52.517
span: box 24 × 33.517, row 52.517
object-fit contain: a 488 × 680 picture painted 24.0 × 33.443 (0.0% taller than its proportions)
pixels: 24x34+1+1 of 26x35
```

The image was stretched: its box was 24 × 34 with `object-fit: fill`, half a pixel taller than the empty thumbnail, so the picture was drawn 1.67% too tall. It is now drawn in its own proportions inside a box of the empty thumbnail's size, and both kinds of row have one height. A screenshot can't show a half-pixel change at this size; the box and the computed fit can.

## Acceptance criteria

The browser examples are in `spec/system/card_image_fit_spec.rb` (11 examples, headless Firefox); they use pictures that are deliberately not 63:88 (40 × 40, 20 × 40, 40 × 20, and 488 × 680 for AC-3.1) and read back where the browser's own fitting rules paint them. All run in `bin/ci`.

| Criterion | Held by |
|---|---|
| AC-1.1, AC-1.2 | "tiles shows images of any proportions whole, in equal 63:88 slots, in both themes" (square, tall and wide pictures at 1280px) and "tiles shows the whole image at phone width" (390px) |
| AC-1.3 | "tiles shows the whole image in search results, faded for a card you don't own" |
| AC-1.4 | `spec/requests/scanner/readings_spec.rb`, "puts a candidate's image in the tile slot, with no class or style of its own" (markup, as the spec's Testability section sets out) |
| AC-1.5 | "tiles shows images of any proportions whole … in both themes": the ground equals each theme's `surface-sunken`, and the two differ |
| AC-1.6 | The same example: the three slots have one size |
| AC-1.7 | "tiles keeps the fallback, the quantity badge and the slot's shape": the fallback's box equals the slot's |
| AC-1.8 | The same example (badge 5px from the slot's top and right edges) and the search results example (unowned image at 45% opacity) |
| AC-2.1, AC-2.3, AC-2.4 | "the card page shows each face's image whole in its own 63:88 slot, in both themes" (two faces, square and tall pictures, window 1280px) |
| AC-2.2 | "the card page shows the whole image at phone width, with no sideways scroll" (390px frame) |
| AC-2.5 | "the card page keeps the fallback inside its own 63:88 slot, clear of another face's image" |
| AC-3.1 | "the table thumbnail shows a Scryfall-sized image in its own proportions", and the measurement above |
| AC-3.2, AC-3.3, AC-3.4 | "the table thumbnail shows images of any proportions whole, in slots and rows of one size, in both themes" (1280px) and "the table thumbnail keeps slots and rows of one size at phone width" (390px) |
| AC-4.1, AC-4.2 | `spec/design_system_files_spec.rb`, "documents the pattern, its three slots and that it overrides the export" |
| AC-4.3 | `spec/design_system_files_spec.rb`, "keeps the rules in one block of their own, with no colour literal or font" |
| AC-4.4 | `components.css` and `tokens.css` are unchanged (`git diff --stat main --` on both prints nothing) and the examples pass. Without each rule they failed, in the red run before it: 5 failures before the first rule (`cropped: a 40.0 × 40.0 picture painted 219.9 × 219.9 at -31.23, 0.0 in a 157.433 × 219.9 box (object-fit: cover)`), 3 before the second (`stretched: a 488.0 × 680.0 picture painted 24.0 × 34.0 … (object-fit: fill)`), 2 before the third (fallback `[300, 892.5]` against a slot of `[298, 416.25]`; 2 rules, not 3) |
| AC-4.5 | [screenshots/](screenshots/): `grid`, `table` and `card`, each at `1280` and `390`, each `light` and `dark` (12 images). Every one was looked at: each picture is whole and undistorted, centred in a card-shaped slot on the theme's sunken ground; slots and rows line up; nothing scrolls sideways at 390px. The pull request is not opened yet, so embedding them there is still to do |

Not asserted: a failed image's alternative text, which is the browser's own rendering (plan, spec coverage table).

## Local gate

`bin/ci` on `f071b4e` (the last commit that changes code or specs; the commits after it add only files under `docs/specs/019-uncropped-card-images/`):

```text
Continuous Integration
✅ Setup passed in 6.47s
453 files inspected, no offenses detected
✅ Style: Ruby passed in 2.03s
Security Warnings: 0
✅ Security: Brakeman code analysis passed in 7.03s
No vulnerabilities found
✅ Security: Gem audit passed in 0.74s
✅ Security: Importmap vulnerability audit passed in 1.80s
1133 examples, 0 failures, 1 pending
✅ Tests: RSpec passed in 4m19.97s
✅ Continuous Integration passed in 4m38.05s
```

The pending example is the art agreement one, which needs `COLLECTOR_ART_AGREEMENT`. The suite had 1,119 examples before this branch; it adds 14.

The whole change outside this spec's directory, `git diff --stat main -- app spec docs/design-system`:

```text
 app/assets/stylesheets/collector/additions.css |   7 +
 docs/design-system/README.md                   |   2 +
 docs/design-system/components/ImageFit.md      |  19 +++
 spec/design_system_files_spec.rb               |  19 +++
 spec/requests/scanner/readings_spec.rb         |   8 ++
 spec/support/card_images.rb                    | 117 +++++++++++++++
 spec/system/card_image_fit_spec.rb             | 191 +++++++++++++++++++++++++
 7 files changed, 363 insertions(+)
```

No view, and none of `components.css`, `tokens.css`, `ItemTile.md`, `ItemPage.md` or `CollectionTable.md`, is changed. Each phase's files were compared with the tree the plan was rendered from and were identical.

`bin/ci` was run again on `5f6711a`, after the screenshots and this file were added: `1133 examples, 0 failures, 1 pending`, every step passed.

## Implementation review

A read-only review against the spec (`sdd-review`, Mode B, Fable) returned SPEC-ALIGNED: every criterion maps to an example that asserts it, the committed files match the plan's blocks, and all 12 screenshots show what AC-4.5 asks. It ran no spec. Its one correction, to the sentence on co-author trailers below, is applied. It also noted that AC-2.5's example checks the fallback's size and top edge but not its left edge, and judged that sufficient because the faces stack in one column; left as it is.

## Commits

`git log --oneline main..HEAD` at the time of recording:

```text
0f83bcc docs(019): add screenshots of the three slots in both themes
f071b4e docs(design): document the image fit override
2ac42f4 fix(design): keep the card page's image fallback inside its slot
791de51 docs(019): record the thumbnail as measured before and after
68ace07 fix(design): stop the table thumbnail stretching its image
27c13d8 fix(design): show card images whole in tiles and on the card page
3c84098 test(design): give the browser test card pictures without the network
ebe3659 docs(019): record the maintainer's approval of the plan
4e4da58 docs(019): revise the plan after its review
cc3c8b1 docs(019): add the implementation plan
15ef4f8 docs(019): record the fallback ruling and the measured facts (1.3.0)
55a10b1 docs(019): record the maintainer's approval of the spec
287ffb6 docs(019): record the ruling on the thumbnail corner
47e1031 docs(019): revise the spec after its review
534e3e2 docs(019): draft the spec for uncropped card images
```

Commits `ebe3659` and `3c84098` through `f071b4e` carry a `Claude Sonnet 5.5` co-author trailer, the model those commits were made on; the others carry `Claude Opus 5.5`.

## Phone browser

Owed. The spec's Reliability requirement asks that the fit hold in the maintainer's phone browser (WebKit). It needs the maintainer and their phone: open the collection grid, the table and a card page from a dev server on this branch, and confirm that the images are whole and the thumbnails aren't stretched. Not checked, and not claimed.
