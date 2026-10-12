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

## Local gate

## Commits

## Phone browser
