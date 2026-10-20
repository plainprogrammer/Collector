---
date: 2026-10-11
spec: "019"
tags: [acceptance-criteria, planning, measurement, css, regressions]
---

# Lesson: Measure today before writing "as it does today"

## Context

Spec 019 changed how card images are fitted and listed several things that must not change. AC-2.5 said that, with no image, the card page's fallback "fills the slot as it does today".

## What happened

The sentence was written from reading the stylesheet, and the spec review, also done by reading, passed it. While planning, each slot was measured in the suite's browser. The fallback measured 300 × 466 against a slot of 298 × 416: it is `position:absolute; inset:0`, its slot has no position, and so it was placed against the sticky image column. For a card with one face's image and none for the other it measured 300 × 892 and lay over the first face's image, which is "covering" a card image, the guideline the spec exists for.

The criterion described behaviour that wasn't true. The maintainer ruled that it be fixed in the same spec (one more rule, decision 4). Had the plan only guarded "as today" with an example, the example would have failed for a reason unrelated to the change, in the middle of execution.

## What to do next time

For every criterion that asserts unchanged behaviour ("as it does today", "unchanged", "keeps"), measure the current behaviour during planning, in the same way the example will, before the plan is written. Record the measured values in the plan. If today differs from the sentence, take it to the maintainer as a finding: it is either a fix to rule on or a criterion to reword.

## Signals to watch for

- "As it does today" in a criterion nobody has run.
- A guard example that is expected to pass before and after the change.
- An absolutely positioned child whose intended container has no `position`.
- A review of a layout claim done by reading CSS only.
