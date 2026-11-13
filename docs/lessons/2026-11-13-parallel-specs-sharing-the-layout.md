---
date: 2026-11-13
spec: 084 (#374), with 082 (#344)
tags: [parallel-work, layout, specs]
---

# Lesson: read sibling branches' specs when a spec changes the layout

## What happened

Spec 084 made the footer appear on every page and the shell always footed. Its plan review read spec 082, which was approved on a sibling branch in the same parallel run, and found that 082 makes the scanner a focused page with no footer, showing the notice's lines in its sheets instead. Neither spec mentioned the other. The fix was spec 084 decision 12, agreed through the coordinator before either branch merged: one core partial, `layouts/notice_lines` with no locals, that holds the types' lines and the licence line. The footer and 082's sheet foot both render it, and whichever branch merges second records the exception for the focused page.

## What to do next time

- When a spec changes the layout, the footer, the shell's classes or a shared partial, read the approved specs on the run's other branches (`git show <branch>:docs/specs/…/spec.md`) before the plan is approved.
- Settle an overlap as a contract with a fixed name and shape, agreed through the coordinator, so either branch can merge first.
