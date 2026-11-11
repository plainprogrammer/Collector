---
date: 2026-11-10
spec: 065 (#252)
tags: [planning, testing, plan-review, supersession]
---

# Lesson: a plan that widens a list must inventory the examples that assert the old list

## Context

Spec 065 widened every location picker and the collection filter from "places only" to "places and zones". Spec 062 had written the opposite on purpose, so about twenty existing examples across a dozen spec files said "never a deck or a zone". The first plan named the examples it knew; the two read-only plan reviews found the rest (nine majors in round 1, one in round 2), almost all of one kind: an existing example the plan would turn red without saying so, or a phase whose "green" run would fail on a file the phase hadn't rewritten.

## What happened

- The spec's "Supersedes" list was complete, because it was written from the earlier specs' criteria. The plan's list of specs to rewrite was not, because it was written from the files the author had open.
- The reviewers found the rest by `git grep` on the old claims ("places only", "never a deck or a zone", `AC-5.8a`, the removed method names `places?`, `locations`, `zone_label`) across `spec/`, including a system spec and two model specs that only called a method the phase removed.
- One find was a phase-ordering bug: the gate changed in Phase 3 turned a Phase 5 example red, so the phase's own verification run could not pass.

## What to do next time

Before writing the plan of a change that supersedes earlier behaviour, grep `spec/` for the earlier spec's AC numbers, its words ("places only"), and every method, constant, partial local and CSS class the change removes. Put the hits in the plan as a per-task "also rewrite" list with line ranges, and put each rewrite in the task whose code turns it red, not the task that is convenient. Then run the plan's phase-by-phase verification in your head: for each phase, name every spec file the phase's change can fail, and check it is in that phase's run list.

## Signals to watch for

- A plan task whose verification run lists fewer spec files than the task's `git grep` finds.
- A supersession that is recorded in the spec and the index but not in a single "rewrite" step of the plan.
- A removed method that appears in `spec/` at all.
