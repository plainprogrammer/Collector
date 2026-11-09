---
date: 2026-11-09
spec: none (issue #127)
tags: [flaky-tests, system-specs, geckodriver, load]
---

# Lesson: reproduce a load-dependent system-spec flake with another suite running, not with synthetic load

## Context

Issue #127: phone-width examples of `spec/system/card_image_fit_spec.rb` sometimes failed with an empty-message `Selenium::WebDriver::Error::WebDriverError` from `evaluate_async_script`. Three sightings, all on a loaded machine; 38 earlier runs (idle, and CPU-busy) never reproduced it.

## What happened

- 60 runs under load of my own did not reproduce it: 30 with eight `yes > /dev/null` loops (load average about 32), 30 with those plus a loop writing and syncing a 2 GB file (47 s a run against 14 s).
- Looping the spec back to back while another worktree's full `bin/ci` ran reproduced it at the first window: 1 failure in 40 runs (seed 13356), this time in a different example than the issue's, so every phone-width frame example shares it. #138's diagnostic then showed the frame was the same document, `readyState` complete and both pictures loaded: the page had finished and the driver lost the reply.
- A script that returns `{ error: … }` is read by geckodriver as its own error, so the helper's "a test picture did not load" path raised the same empty `WebDriverError`. A guard example for that path failed before the fix, which was a deterministic red the flake itself never gave.
- The fix (no async script call: a plain script, a Capybara wait, a synchronous measurement) passed 74 runs in two sibling windows (a `bin/ci` and a full `bin/rspec`).

## What to do next time

Reproduce with a second real suite (Firefox, Puma and SQLite at once), not with busy loops, and loop the spec for the length of the window; the loop stops at a run boundary when a stop file appears. At 1 in 40, 20 clean runs prove little: verify with 60 or more across windows. Keep the seed, the diagnostic message and the failure screenshot before removing a worktree. Look for a deterministic neighbour of the flake (here the error path) to write the red example from.

## Signals to watch for

- An empty `WebDriverError` message from `evaluate_async_script` or any script that returns an object with an `error` key.
- A sighting that only ever happens while another worktree runs its full CI.
