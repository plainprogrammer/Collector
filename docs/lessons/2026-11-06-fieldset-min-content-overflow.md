---
date: 2026-11-06
spec: "042"
tags: [design-system, narrow-width, css, forms]
---

# Lesson: A fieldset is as wide as its widest content; give it `min-width: 0`

## Context

Spec 042 grouped the scanner sitting's two selects (Condition, Location) under one `<fieldset>` with the legend "This sitting's cards", reusing `fieldset.c-choices` (a flex column, no border) so no new class was needed. Spec 040's lesson had already fixed `.c-field select` with `min-width:0; max-width:100%`, and the plan expected that to be enough.

## What happened

The 360px system example with a long location name failed: the frame's page was 419px wide. The selects were already allowed to shrink; the fieldset was not. Browsers give `<fieldset>` a default `min-inline-size: min-content`, so the longest option of a select inside it sets the fieldset's minimum width, and the fieldset pushes past the panel no matter what its children allow. `.c-scanner__place .c-choices { min-width:0; }` in `collector/additions.css` fixed it; the plan had named this rule in advance as its fallback, from a reviewer who spotted the default.

## What to do next time

- Whenever fields go inside a `<fieldset>` (to group them under a legend), add `min-width: 0` to that fieldset, or check that its class already has it, before the narrow-width example runs.
- Keep a 360px example with the longest user-supplied value for every select whose options come from the collector (see the lesson `2026-11-06-long-names-in-narrow-checks.md`).

## Signals to watch for

- A `<fieldset>` around form controls whose option text the collector types.
- A narrow-width failure where the selects already have `min-width:0` and still overflow: look one level up for a fieldset.
