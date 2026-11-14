---
date: 2026-11-13
spec: 089 (#365)
tags: [data-safety, history, specs, reviews]
---

# Lesson: deleting by absence needs a candidate rule for every dimension a file can be silent about

## Context

Spec 089's daily refresh removes a price (and records the removal in history that can't be downloaded again) when the source's file has no quote for it. The spec's decision 4 limited "absent" to prices the file was asked about: a printing in a language the run read, whose entry exists. Two spec review rounds and two plan reviews accepted that.

## What happened

The implementation review found the dimension nobody listed: the series. A price in a series the source no longer declares (a later build drops one) has no quote in any file, so every run would see it absent, and either fail on the ceiling every day or, for a small series, blank prices the file was never asked about. The fix is the same reasoning as the language rule: only what the source declares today is a candidate (spec 089 v0.5.0).

## What to do next time

- When a rule deletes on absence, list every dimension in which the data could be silent for a reason that isn't "gone": language, series or kind, a printing the other database lacks, a source that stopped declaring something, a file that was truncated. Write the candidate rule per dimension in the spec, and add one example per dimension that shows the price kept.
- Prefer a ceiling and a counted, withheld removal to an unconditional delete; the ceiling is what would have shown this one in production.

## Signals to watch for

- A removal rule stated only in terms of the data (what the file lacks) and not of what the file was asked for.
