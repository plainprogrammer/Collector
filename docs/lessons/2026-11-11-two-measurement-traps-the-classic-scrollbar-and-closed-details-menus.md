---
date: 2026-11-11
spec: 072 (#315)
tags: [system-specs, firefox, layout, narrow-frame]
---

# Lesson: two measurement traps, the classic scrollbar's 15px and the box of a closed details menu

## Context

Spec 072's AC-1.4 measures, on twelve pages at 360px in a narrow frame, that nothing overflows sideways and no two controls overlap, with every coarse-pointer rule applied.

## What happened

- The overflow check compared `documentElement.scrollWidth` with `window.innerWidth`. `innerWidth` includes the vertical scrollbar, which is classic (15px) in these examples and appears whenever a page is taller than the frame, so a page could scroll sideways by up to 15px and still pass. The implementation review found it; the fix compares with `documentElement.clientWidth` (the 10 examples still pass, so nothing was overflowing). `spec/support/narrow_frame.rb` returns `scrollWidth <= innerWidth` the same way, and has the same blind spot (a possible follow-up, not changed here).
- The first green run failed AC-1.4 and AC-1.5 on bulk mode: the items of the bulk bar's closed More `<details>` menu overlapped the table beneath it. Firefox keeps a layout box for the content of a closed `<details>` although nothing is drawn. The overlap check now skips controls inside a closed `<details>` other than its own `summary`. The skip adds a clause the approved AC-1.4 did not have, so it was recorded as a spec patch (0.3.1) after the implementation review, not left as a silent narrowing (see `docs/lessons/2026-11-11-a-plan-that-departs-from-an-approved-criterion-needs-a-spec-update.md`).

## What to do next time

Compare `scrollWidth` with `clientWidth` when asking whether a page scrolls sideways. When an overlap or visibility check meets a menu, popover or `details`, ask whether Firefox lays it out while it is closed, skip it by what the user can see, and write that clause into the criterion's definition of "visible" when the spec is written.

## Signals to watch for

- `scrollWidth <= innerWidth` (or `window.innerWidth` anywhere a scrollbar may be drawn).
- An overlap report that names a menu item or a `summary`'s list on a page whose menu is closed.
- A measurement helper that grows a skip rule that the criterion's own definition does not mention.
