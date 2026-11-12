---
date: 2026-11-12
spec: 078 (#330)
tags: [design-system, css, process, specs]
---

# Lesson: when an issue lists options with costs, probe the cheapest missing candidate before asking for the ruling

## Context

Issue #330 (a mana bar label wider than its segment wraps and is cut off) offered three options: A, leave it as the documented limit; B, a server-side rule by label length; C, a container query with the label's length as a class. B and C both hard-coded font metrics or added a class per length, and the maintainer's ruling was needed because B superseded a ruled rule (the 10% narrow class).

## What happened

- Before writing to the coordinator, a throwaway system spec (a deck per label length, 4, 5 and 6 characters, at a 320px viewport, a 360px viewport and the 1280px aside) measured the labels. It showed the real cause: a label wraps at its own space ("W" over "12"), and a label is 29.2px, 36.4px or 43.6px wide, so whether it fits depends on the bar's width as well as the label's length.
- The same probe tried a fourth candidate that the issue did not list: make each segment a wrapping flex container with a zero-width first item, so the browser's own line breaking moves a label that cannot fit onto a second line that `overflow:clip` hides. Every label that fit stayed drawn (including a 12% "W 12" on a 360px phone), every label that did not fit left its segment, and none wrapped or was cut off.
- The question to the coordinator then carried the measurement and a fifth option with its trade-offs, and the maintainer ruled it (D1) in one round trip, keeping the 10% rule. The spec's review rounds spent their effort on the examples' tolerance (the integer `clientWidth` would have failed the Linux runner), not on whether the approach worked.

## What to do next time

When an issue lists options whose costs are about hard-coded numbers or extra markup, spend a few minutes on a throwaway probe (an uncommitted spec that builds the decks and measures the candidate in the real browser, as the screenshots method does) for an option the issue does not list, before asking for the ruling. Put the measurement in the question. A probe that finds nothing better costs the same few minutes and still turns the options' costs into numbers.

## Signals to watch for

- Options in an issue that all trade one literal (a pixel threshold, a font width) for another.
- A "documented limit" option recorded because the fix looked server-side or JavaScript-only; check whether the browser's own layout can make the decision (line breaking, `overflow`, container size) before accepting that.
