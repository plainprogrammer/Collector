---
date: 2026-11-13
spec: none (#404, a direct fix)
tags: [testing, turbo, flaky-tests, debugging]
---

# Lesson: the issue's guess about a flake was wrong; an event timeline found the cause

## Context

Issue #404: the AC-1.13 example failed about 5% of runs with `expected 0 to be within 1 of 442.75` after Back. The issue's "Reading" guessed the example read `scrollY` before Turbo had restored the scroll, and proposed `wait_for_turbo_idle`.

## What happened

A 60-run loop reproduced the rate (3 failures). A temporary copy of the example logged `turbo:visit`, `turbo:render`, `turbo:load`, `popstate` and `scroll` in the frame, each with `scrollY`, `aria-busy` and `history.restorationData` of the current identifier. The log showed Turbo had restored to 0 on purpose: Back came one frame after the previous visit's scroll-to-top, `popstate` switched the restoration identifier first, and the queued scroll event recorded `{y: 0}` on the previous entry. `wait_for_turbo_idle` could not have helped, since `aria-busy` is cleared before that frame.

## What to do next time

- Put the saved state beside every event in a timeline before choosing a wait. A wait added on a guess would have passed 200 runs only by luck of its own timing, and left the cause.
- Loop from a scratchpad copy of the spec when instrumenting: editing the repo's file changes the runs in flight.
- Make the failure deterministic (here, Back from `turbo:load`) before fixing, so the fix is proved against the cause and not only against a rate.

## Signals to watch for

- A flake whose written "likely cause" is a race with no log behind it.
- A wait helper that checks a state (`aria-busy`) the fault happens outside of.
