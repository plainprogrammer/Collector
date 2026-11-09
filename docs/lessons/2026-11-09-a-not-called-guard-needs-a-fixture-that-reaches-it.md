---
date: 2026-11-09
spec: 053
tags: [testing, rspec, guards]
---

# Lesson: a "not called" guard needs a fixture that would reach the guarded branch

## Context

Spec 053 AC-1.9: with art matching off, the art index panel makes no drift comparison. The first example gave the build a file name that was never written, then asserted `latest_catalog_version` was not called.

## What happened

The unwritten file would have read `:index_missing` even if the `:off` check were bypassed, and `:index_missing` never asks for the latest catalog version. The "not called" assertion could not fail for the reason it names; only the `state == :off` assertion guarded anything. The implementation review (Opus) found it.

## What to do next time

- For "X is not done when Y is off", build the fixture so that without the Y check X would be done (here: stub the file test true, so the build would read `:out_of_date`), then watch the example go red with the check removed.
- A spy that nothing can reach proves nothing; ask what state the code would be in if the guard were missing.
