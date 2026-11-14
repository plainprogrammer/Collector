---
date: 2026-11-13
spec: none (#417)
tags: [testing, flaky-specs, system-specs, turbo]
---

# Lesson: a flake that fails once in thousands is measured by provoking its race, not by looping it

## Context

#417: `spec/system/locations_spec.rb:7` failed once in a 4950-example run. The example clicks "Rename Blue binder" and at once fills in "Name"; the page it leaves has a "Name" field too.

## What happened

- The example alone passed 60 of 60 before the fix and 200 of 200 after it. Those counts only bound the natural rate (under about 5% and 1.5%, at 95% confidence) and cannot tell a fixed example from an unfixed one.
- Holding back the one response the race depends on (a `window.fetch` wrapper that delays the rename page's request) made it measurable: with 40 ms, 8 of 30 runs failed before the fix and 0 of 30 after; with 400 ms, 10 of 10 and 0 of 10. An event log (`turbo:visit`, `turbo:render`, `turbo:load`, `location.pathname`) showed the typing at 75 ms on the old page and the new page rendering at 433 ms.

## What to do next time

For a race between a test and a page change, find the one response or event it depends on, delay it in a temporary spec, and compare before and after at a delay where the failure rate is high. Say in the PR what the clean loop of the real example does not show. Keep the temporary spec out of the suite and put its code in the issue.

## Signals to watch for

- A `click_on` followed at once by `fill_in` or `click_on` of a label the page being left also has.
- A "0 failures in N runs" offered as the proof of a flake's fix, with no provoked comparison.
