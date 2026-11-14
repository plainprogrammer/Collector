---
date: 2026-11-13
spec: 088 (#345)
tags: [scanner, testing, ocr]
---

# Lesson: an example that draws a name for the OCR must not depend on how it is read

## Context

Spec 088's "not sure of this card" examples need a reading whose first candidate is a name-only match below the strong threshold (0.96). The system examples draw a name on a synthetic card and the page's OCR reads it.

## What happened

A misspelling such as "Lightnlng Bo1t" is below the threshold when sent verbatim (a request example), but the OCR can read it as "Lightning Bo1t" or "Lightning Bolt", which scores 0.97 or more: the row becomes a printings row and the example fails for a reason that has nothing to do with the code. The plan review (round 2) caught it. The system examples draw "Lightning", which scores about 0.93 against "lightning bolt" however well it is read, and a request example asserts that score against the test catalog.

## What to do next time

- Draw a name that stays on the intended side of a threshold when read perfectly, not one that is only below it when read badly.
- Assert the score or the branch in a request example that needs no OCR, next to the system examples that rely on it; if a fixture card makes it strong, change the drawn name, never the threshold.

## Signals to watch for

- A system example whose scenario depends on the exact text the OCR returned for a drawn string.
