---
date: 2026-11-10
spec: 059 (#187)
tags: [bulk-mode, request-specs]
---

# Lesson: replay the page's own fields, not hand-built ones, to prove a stored bulk selection

## Context

Spec 059's shortcut stores a bulk selection with `all_matching` true. Its request example for AC-2.3 (Move to… opens for every copy without ticking anything) first sent a hand-built PATCH with `all: "1"` and both ids ticked, and the implementation review found it would pass even if the shortcut had selected nothing.

## What happened

- With `all_matching` false, the controller marks the ticked lots, so the hand-built form gave the same "Move 12 items" as the real selection.
- The obvious fix, `ticked_ids: []`, is wrong the other way: with `all_matching` true and the header unchanged, the marks are the shown ids minus `ticked_ids`, and the browser sends every shown id as ticked for an untouched page. Empty `ticked_ids` deselects everything.
- The example now reads the GET page's own fields (`all_rendered`, enabled `shown_ids[]`, `baseline_ids[]`, the checked rows, the header's `all`) and sends them back unchanged. Setting `all: false` in the controller made it fail, which is the proof.

## What to do next time

For a request example about what the bulk page does when the user touches nothing, build the form from the rendered page, and break the implementation once to see the example fail.

## Signals to watch for

- A bulk request example whose params would give the same answer under the opposite stored state.
