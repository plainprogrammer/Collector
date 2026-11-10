---
date: 2026-11-10
spec: 063 (#294)
tags: [design-system, previews, css, review]
---

# Lesson: "the previews match with no edit" was false for nine of them

## Context

Spec 063 sets the stroke of small icons in one `additions.css` block, by the component that draws the icon. The first draft said the previews would match the app with no edit, because "they load `additions.css`" (spec 060 line 224 says its twelve new previews do).

## What happened

- The first read-only spec review checked the claim against the files and found that eleven previews load only `tokens.css` and `components.css`: nine of them draw stroked icons (`Badge`, `Button`, `Chip`, `CollectionTable`, `FilterBar`, `Input`, `ItemTile`, `Menu`, `ViewSwitch`). Only the twelve previews spec 060 added, and a few older ones, link `additions.css`. A criterion that said "no preview file changes" could not have passed.
- Giving the nine the link has a side effect the second review found by reading `additions.css` against their markup: `ItemTile`'s unowned tile loses the export's 45% fade (the app's own rule), and `CollectionTable`'s phone frame may wrap a line. The spec names both; the measure showed the first and not the second.
- Our own guard code had a second small trap the plan review caught by reading: `evaluate_script` hands back whole numbers as Ruby Integers, so `2 * 16 / 24` is 1, not 1.33. The red run (stroke 1.5, a Float) would have hidden it; only the green run would have failed.

## What to do next time

A spec that says "X loads Y" or "X needs no edit" names the evidence in the spec text: the `git grep -L` that lists the files that don't. Run it while writing the spec, not in the review. When a change makes more files load a stylesheet, read that stylesheet against their markup for rules that now match (the review's list: `.c-tile--owned-none`, `@container collection`), and say in the criterion which changes are intended.

## Signals to watch for

- "They all load it" with a citation to a spec that covers only the previews it added.
- A guard whose red run uses a Float and whose green run uses whole numbers: do the arithmetic with `.to_f` at the boundary.
