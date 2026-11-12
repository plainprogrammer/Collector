---
date: 2026-11-11
spec: 077 (#320)
tags: [specs, reviews, measurement, acceptance-criteria]
---

# Lesson: build a measurement table's cells from the data, and re-measure the width a variant depends on

## Context

Spec 077's problem statement has a table of what the four layout limits measure at four widths. I typed it from a JSON dump of one throwaway run.

## What happened

- The caption cell for the 320px viewport read "breaks inside 'Green / 2,591'" where the JSON showed the old caption breaking between colours, with no item split (the split was the 345px row). Two Opus spec reviews and Gate A carried the cell, and AC-4.3's failing variant was written for 320px.
- It surfaced only when the plan needed a failing width for that variant and the supervisor re-read the numbers. The fix was a PATCH (spec 0.3.1) and the variant moved to 345px and 360px.

## What to do next time

Generate each cell of a measurement table from the measured value in the same step (a script that prints the table), or re-read every cell against the data before the spec is reviewed. When an acceptance criterion's failing variant depends on one cell ("an item splits at this width"), re-measure that width on its own before approving the criterion.

## Signals to watch for

- A table typed by hand from JSON or console output.
- A failing variant whose width comes from a table row nobody re-measured.
