---
date: 2026-11-11
spec: 077 (#320)
tags: [testing, system-specs, narrow-frame, wrapping, acceptance-criteria]
---

# Lesson: sweep the widths before calling a wrapping clause unfailable

## Context

Spec 077 AC-4.3 says no line of the mana caption begins with "·". The spec's first draft said the clause "cannot fail on this fixture" because four measured widths showed dots only at the end of lines, and proposed proving it indirectly through the single-rect check on each item.

## What happened

- The plan's first task swept the old caption through 72 frame widths (255px to 468px in steps of 3px, one throwaway system spec reading the first character of each line with `Range` rects). A line began with "·" at 16 of them, including a 366px frame, a phone-width interior of 269px on a Mac and 272px on the Linux runner.
- So the clause could fail after all: the failing variant now runs at that frame and expects a line to start with "·". Without the sweep the criterion would have been proved only by an indirect check.

## What to do next time

When a criterion is about where text wraps (a line that starts or ends with something, a name split from its count), measure a range of widths in one throwaway run before concluding that a clause cannot fail, and pick the failing variant's width from the result, checking that it holds for both the Mac's 15px and the runner's 12px scrollbar.

## Signals to watch for

- "No line begins with X", "never wraps inside Y" in a criterion.
- A draft that says a clause "cannot fail on this fixture" after looking at three or four widths.
