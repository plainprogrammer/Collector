---
date: 2026-11-06
spec: "048"
tags: [design-system, narrow-width, testing, firefox, tables]
---

# Lesson: Probe a layout claim in the browser before the spec rules on it

## Context

Issue #142 asked whether a long place name in the collection table's wide Location cell makes the table scroll sideways just above the 640px breakpoint, and said "plausible, not checked in a browser". Spec 048 was to settle it.

## What happened

A throwaway system spec, kept in the session scratchpad and never committed, loaded the table in fixed-width frames (`open_in_narrow_frame`) at 360 to 1280px and printed the table's width, its container's width and the page's overflow, one lot per run, for names of 0, 20, 40 and 60 characters and one of 60 unbroken characters. A second run injected the candidate CSS into the frame, with and without `max-width`. About 60 lines each, and they found three facts nobody had asked about:

- A 60-character name with no space overflowed the **phone** row by about 440px, because the wrapping line had no break point. The issue and the review had only looked at names with spaces.
- Firefox ignored `max-width` on the `td` (a cell took 442px under a 320px cap). The cap needed an element inside the cell. The spec had been about to name the cell's `max-width` as the mechanism; the first spec review caught that it was unverified, the probe settled it.
- A table with a short name was already about 20px wider than its container for containers of 640 to 660px, which no place name causes. It was filed as #208 rather than folded into the spec.

The plan's measuring helper then called `document.getElementById("narrow")` from inside `within_frame`, where the iframe element doesn't exist; the plan review caught it by reading `spec/support/narrow_frame.rb`.

## What to do next time

- When an issue says a layout "is plausible but unchecked", measure it before the spec decides, with every shape of the input: no space, spaces, the maximum length, none at all. Put the numbers in the spec as a table, so the rulings are made on them.
- Test a candidate rule by injecting it into the frame (`style.textContent`) before writing it into the stylesheet. It costs one spec run and shows which declarations Firefox honours.
- A helper that reaches into the frame (`document.getElementById("narrow").contentWindow`) runs from the top page; inside `within_narrow_frame` the page is the frame's own. Call it after `open_in_narrow_frame`, outside the block.
- Leave a probe's findings that aren't the spec's job as an issue with the numbers, and cite it in Out of Scope.

## Signals to watch for

- "Plausible, not checked" in an issue about widths.
- A CSS rule named in a spec that nobody has run in the browser that matters (this suite's is headless Firefox, which has its own table-cell rules).
- Related: [Put the longest user-supplied name in every narrow-width check](2026-11-06-long-names-in-narrow-checks.md).
