---
date: 2026-10-03
spec: "008"
tags: [sdd, spec, acceptance-criteria, harness]
---

# Lesson: Acceptance criteria state outcomes, not how the harness runs them

## Context

Feature 008 (card scanner Phase 2 spike), spec v1.2.0, AC-4.9: the full artwork fetch of about 50,000 images.

## What happened

AC-4.9 required the fetch to run "in chunks that each finish within a 2-hour background task". In execution it ran as 19 foreground chunks of 3,000 images or fewer, each inside the 10-minute command timeout. That was safer, it resumed from the cache each time, and nothing was fetched twice. Because the AC named the mechanism, this still counted as a deviation. It needed a findings note, a "⚠ Partial" in the implementation review and the maintainer's ruling, although every outcome the AC exists for was met.

## What to do next time

Write acceptance criteria as observable outcomes: resumable, nothing fetched twice, totals and failures reported beside the estimate, no chunk killed (or the killed one reported). Put the mechanism (background task, foreground chunks, chunk size, timeouts) in the plan, where a ruling during execution can change it without touching the spec.

## Signals to watch for

Tool or harness names in an acceptance criterion: "background task", "Bash", "subagent", a specific timeout or chunk size.
