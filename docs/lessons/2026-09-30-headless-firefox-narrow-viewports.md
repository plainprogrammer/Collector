---
date: 2026-09-30
spec: "004"
tags: [testing, system-specs, responsive, firefox]
---

# Lesson: Headless Firefox can't test phone widths with a narrow window

## Context

Spec 004 required every page to work from 360px wide, with specific phone layouts (tab bar, back arrow, two-column grid, folded table rows). The plan tested these with system specs using `driven_by :selenium, using: :headless_firefox, screen_size: [390, 844]` and `[360, 800]`.

## What happened

The Phase 7 implementer noticed that `window.innerWidth` was 500 under the "360px" driver: headless Firefox clamps windows to a 500px minimum. Every phone-width assertion in the plan would have passed or failed against a 500px layout. Several would have passed for the wrong reason: 500px is below the 640px breakpoint, so the phone shell still showed, but grid column counts and overflow checks were wrong.

A second trap: Capybara pools sessions by driver name, and `driven_by` inside an example defaults the name to `:selenium`, so a new `screen_size` or Firefox preference was silently ignored. The plan review caught this, and the fix was distinct `options: { name: … }` per variant.

The working approach loads the page in a fixed-width same-origin iframe on a normal-size window and inspects the frame (`spec/support/narrow_frame.rb`). Media and container queries evaluate against the frame's width. Every narrow assertion was proven by breaking its CSS once and watching it fail.

## What to do next time

When a spec or plan requires phone-width behaviour, plan the checks with the narrow-frame helper from the start, not a narrow driver. Assert the frame's `innerWidth` equals the intended width, so a clamped viewport can't slip through. Keep touch-target and coarse-pointer checks manual, because the iframe can't emulate them.

## Signals to watch for

- A system spec sets `screen_size` below 500 for Firefox.
- A narrow-layout assertion passes on its first run.
- `driven_by` is called inside an example.
- Screenshots at "phone" width look like tablets.
