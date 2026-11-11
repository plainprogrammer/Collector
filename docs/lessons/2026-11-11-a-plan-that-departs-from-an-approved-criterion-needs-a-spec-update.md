---
date: 2026-11-11
spec: 067 (#302)
tags: [sdd, plans, acceptance-criteria, reviews]
---

# Lesson: a plan that narrowed an approved criterion was a gap, not a deviation, and only the implementation review caught it

## Context

Spec 067 AC-3.1 ends "A system spec covers it, without scripting", and its Notes for the plan repeat it: a system spec, without scripting, covers Story 3 from the Decks page to the removal. The plan's Task 4 split the work instead: the end-to-end example ran in headless Firefox and a separate `rack_test` example covered the button and the Move to… page only (AC-5.1). The plan review had taken the no-script example as the fix for a major finding and did not compare it with AC-3.1's whole scenario.

## What happened

- The implementer followed the plan, every example passed, the full `bin/ci` was green, and the first `verification.md` listed the split as "deviation 3: as the approved plan wrote it", arguing that the move and the removal are plain forms proved elsewhere.
- The implementation review (Mode B, round 1) called it a major gap: the plan had departed from an approved criterion without a spec update, so the no-script path never covered the move, the landing under the deck filter or the removal. The fix was ten lines (the `rack_test` example runs the whole scenario) and one more review round to confirm it.

## What to do next time

When a plan narrows, splits or reinterprets an approved criterion, change the spec through `sdd-spec-update` first, or write the plan to meet the criterion as worded. A deviation note in `verification.md` does not make a departure acceptable, and neither a green suite nor a reviewed plan proves the criterion is met. In plan review, check each task's tests against the whole text of the criteria it names (AC-3.1's "without scripting" and its start and end points), not against the plan's own summary of them.

## Signals to watch for

- A plan task that names a criterion and then lists fewer steps than the criterion's Given/When/Then.
- A `verification.md` row or deviation that explains why a criterion's clause is "proved elsewhere".
- A spec's Notes for the plan that say how a test must run (here, "without scripting") while the plan chooses another way.
