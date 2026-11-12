---
date: 2026-11-11
spec: 074 (#326)
tags: [css, menus, phone-width, prototype]
---

# Lesson: a scroll-into-view fix needs scroll range at the end of the page, so prototype it there

## Context

Issue #326: a row menu opened near the bottom of a phone hides its last items behind the fixed tab bar. The approved fix scrolled the opened list into view (`scrollIntoView({ block: "nearest" })`) with `scroll-margin-bottom` equal to the bar's height.

## What happened

- The first spec review found that this can't work on the last rows of a page: an absolutely positioned list adds scrollable overflow only to its own bottom edge, the page ends 80px under its content, so the furthest scroll puts the list's bottom on the viewport's bottom, behind the bar.
- A throwaway prototype confirmed it: an 8-item menu on the last row still ended at 635px behind a bar at 573px; with an empty `::after` box under the open list, as tall as the margin, it ended at 561px. A 4-item menu fit either way, so a prototype on a short menu would have passed.
- The box also needed a width (a zero-width box may add no overflow) and `pointer-events: none` (it covers the page below the list).

## What to do next time

When a fix relies on the page scrolling, prototype the worst position (the end of the page, the longest content) before the spec states it, with a fixture that is long enough to fail without the fix. Name the scroll range in the spec as a requirement, not only the scroll.

## Signals to watch for

- "The page can be scrolled to reveal it" in a problem statement with no check of the page's end.
- A prototype with the shortest list or a row in the middle of the page.
