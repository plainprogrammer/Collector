---
date: 2026-10-11
spec: "019"
tags: [acceptance-criteria, tolerance, measurement, css, system-specs]
---

# Lesson: Check a tolerance against the defect it has to catch

## Context

Spec 019 makes every card image slot show its image whole and in its own proportions. One of the three defects was the collection table's 24px thumbnail, which stretched its image. The spec defined "in its own proportions" as the painted width over height matching the file's "within one device pixel".

## What happened

The definition was written before anything was measured, and a spec review passed it. Planning measured the thumbnail in the suite's browser: its box was 24 × 34 and a 488 × 680 image was drawn 1.67% too tall. At that size the stretch is 0.56px. An example written to the approved wording would have passed against the bug it existed to catch, so AC-3.1 could never have gone red.

The spec was patched (1.3.0) to "the same scale across and down, within 0.1%", which is independent of the element's size. The examples derive the painted rectangle from the image's natural size, its content box and the computed `object-fit`, so the comparison is exact; a screenshot of the thumbnail showed 24 × 34 pixels before and after the fix, because anti-aliasing hides half a pixel.

## What to do next time

When a criterion carries a tolerance, work out the size of the known defect at the smallest size it appears, and confirm the tolerance fails it. For small elements state proportions as a ratio or a scale, not in pixels. Before trusting pixels as evidence, check that the change is larger than a pixel.

## Signals to watch for

- "Within one pixel" or "within N px" in a definition that also has to hold for a thumbnail or an icon.
- A tolerance chosen in the spec before the defect was measured.
- A red step that passes on the first run.
- A before-and-after screenshot comparison of a sub-pixel change.
