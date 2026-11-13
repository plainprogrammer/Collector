---
name: third-party-fault-reproducers-stay-out-of-the-suite
description: A reproducer that asserts a library's own fault (Turbo, Selenium) is not added to the suite; its code goes in the issue and the commit body
metadata:
  type: feedback
---

When a flake's cause is a fault inside a library (the case: Turbo overwriting its saved scroll, #404), write a deterministic reproducer as the failing-first proof, but keep it out of the suite, and put its code and the event sequence in the issue and in the fix's commit body.

**Why:** the coordinator's ruling on #404 (2026-11-13): an example that asserts the library's fault would fail the day the library fixes it, and the suite would then carry a test of someone else's bug.

**How to apply:** run the reproducer from a scratchpad copy of the spec (so a loop already running isn't changed by an edit), record its fail count (#404: 7 of 8), then fix the test's wait, not the reproducer. See [[turbo-back-navigation-quirks]].
