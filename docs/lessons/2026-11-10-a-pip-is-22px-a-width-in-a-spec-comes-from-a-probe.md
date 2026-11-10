---
date: 2026-11-10
spec: 060 (#249)
tags: [design-system, tables, box-model, spec-review]
---

# Lesson: a mana pip is 22px, and the Cost column the spec approved was 6px too small

## Context

Spec 060 gives every deck zone table one fixed column layout (decision 25), so Cost, Owned, Proxy, Total and the menu sit at the same x in every zone. The Cost width came from arithmetic on declared sizes: `.c-mana` is `width:20px`, six symbols and five 2px gaps make 130px, a cell pads 12px a side, so "Cost needs 154px and has 160px". Gate A approved it.

## What happened

- The plan review (before any code) read the CSS again: `.c-mana` also has `border:1px solid`, and no stylesheet in the app sets `box-sizing`, so a pip is 22px. Six pips are 6 × 22 + 5 × 2 = 142px and the cell needs 166px; 160px let the pips spill 6px into Owned, and no planned example would have seen it, because a fixed table never widens.
- The fix was a spec patch (1.0.1, Cost 11rem, the Card column 128px at a 640px table) and an example that reads the pips' own height and width, plus a second finding of the same kind in round 2: the export's `td { white-space:nowrap }` would let a name spill from a 128px Card column into Cost, and a "fits" assertion on the cell's `scrollWidth` passed even when the pips wrapped.

## What to do next time

State a width in a spec only from a probe (the element's `getBoundingClientRect` in the browser, or the box model worked from the computed `border` and `padding`), not from the declared `width`. For a fixed layout, give each claim an example that can fail on the quantity itself: "the six-symbol cost is one line" (its height is one pip), not "the cell does not scroll". Pair it with `docs/lessons/2026-11-10-measure-the-apps-header-not-the-preview.md`: both found a fit claim made from numbers instead of a measurement.

## Signals to watch for

- A width in a spec or plan that sums declared sizes (`width:20px`) with no mention of borders or box-sizing.
- A "no overflow" check on a table with `table-layout:fixed` or on a cell with a wrapping child: it passes whether or not the content fits.
- `box-sizing` is never set in this app's CSS (the export has none): every `border` adds to a declared width unless the rule says `border-box`.
