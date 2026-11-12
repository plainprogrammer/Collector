---
date: 2026-11-12
spec: none (direct fix, #318)
tags: [system-specs, firefox, layout, narrow-frame, measurement]
---

# Lesson: sweep a measurement trap by swapping the measure and running, not by grep

## Context

#318: the narrow-frame helper compared `scrollWidth` with `innerWidth`, which includes the frame's classic scrollbar (15px on the Mac, about 12px on CI), so a page overflowing sideways by up to that much passed. Spec 072's review had named the trap on 2026-11-11 (`docs/lessons/2026-11-11-two-measurement-traps-the-classic-scrollbar-and-closed-details-menus.md`). The helper fix was four lines.

## What happened

- The helper's change alone left all 452 examples that use it green. The same trap was written 25 more times as inline `scrollWidth <= window.innerWidth` checks in 17 other specs, nine of them as a local `fits?` method each. A grep found those.
- The first review round found them, and a second grep still missed two variants: `footer_spec` compared the footer text's right edge with `width - gutter`, where `width` is the frame's width and so includes the scrollbar, and `scanner_sitting_spec` compared `scrollWidth` with the literal 360. Neither contains `innerWidth`. The second round's reviewer found them by reading.
- Swapping the measure to `clientWidth` and running was what found real findings: 5 examples failed, all at a "360px" narrow frame of the deck page. The cause was not a bug: a 360px frame with a 15px scrollbar lays a page out in 345px (348px on CI), and the zone table's worst-case row spills 7 to 10px past that, but not past a true 360px viewport (spec 074 recorded the spill and its limit). The examples had been passing because the scrollbar hid it, and "360px" meant two layouts in one file.
- The honest fix was to say which 360px each example means: `open_in_viewport_frame` opens a frame as the viewport plus the measured scrollbar, and the two overflow examples use it. The helper is the one measure now (`page_fits_sideways?`), so the next check has nothing to copy.

## What to do next time

- To remove a measurement trap, put the correct measure in one helper first, then swap every use and run the files. Grep finds the copies that look like the trap; the run finds the ones that behave like it. A comparison against a frame's width, a viewport literal, or a width variable that includes a scrollbar is the same trap without its name.
- When a stricter measure turns an example red, ask what viewport the name promises ("360px" is a phone's viewport, not a 360px frame) before touching the page.
- Probe before asking for a scope ruling: a temporary `sed` over the files, one run and a `git checkout` took under four minutes for 17 files and let the question to the coordinator name the 5 failing examples and their cause.

## Signals to watch for

- `scrollWidth` or an element's `right` compared with `innerWidth`, a frame `width` parameter, or a number that is a frame's width.
- A local `fits?` or `frame_fits?` defined in a spec: the measure belongs in `spec/support/narrow_frame.rb`.
- An example named for a phone width that opens `open_in_narrow_frame(…, width: 360)` and checks overflow or an edge.
