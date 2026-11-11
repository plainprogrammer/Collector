---
date: 2026-11-11
spec: 068 (#254)
tags: [sdd, specs, plans, supersession, reviews]
---

# Lesson: a supersession list written from memory misses the existing examples it breaks

## Context

Spec 068 fills cells and heads that spec 066 had left empty "until #254", and spec 066 itself superseded parts of spec 060. The spec's "Supersedes and updates" section and the plan's step that changes existing examples (T6 Step 6) were written from the area docs and from remembering the earlier specs.

## What happened

- Review round 1 of the spec found the supersession list incomplete: spec 066 AC-1.3, AC-2.1, AC-2.7, AC-5.3, AC-6.2 and FR-2, spec 060 decisions 10 and 25 and AC-3.5, AC-3.7, AC-3.9, AC-3.11, spec 062 AC-3.1, AC-4.3, AC-4.5, AC-4.7, AC-7.6, AC-7.7, AC-8.1, AC-8.8 and spec 064 AC-2.7, AC-2.10.
- Review round 1 of the plan found that the plan's list of existing examples to change named two, where `spec/requests/deck_pages_spec.rb` asserted spec 066's head texts at eight places, the AC-1.6 example as a whole ("no proxy control, count or tag"), the AC-4.2 selector (`.c-table__actions`, which every row now has), the five column headers in three spec files, and a `not_to include("Proxy")` line. Round 2 found three more (a `thead th` list, `shown_headers` in a system spec, an export header `except`).
- The same shape repeated for the import: the plan's list of specs building version 4 files by hand named the wrong helpers.
- Each was found by an Opus reader grepping the spec tree, which the author could have done first.

## What to do next time

Write the spec's supersession list and the plan's "existing examples that change" step from a grep, not from memory: take the strings the earlier spec fixed (a head's text, a column list, "no menu", a statement count, "Proxy cell is a dash") and `git grep -n` them in `spec/`, in `docs/design-system/` and in the area docs, then list each hit with its disposition (changed to the new text, rewritten whole because the criterion is superseded, or kept). Do it before the first spec or plan review, and name the grep in `verification.md`.

## Signals to watch for

- A spec that fills in, extends or reverses something a recent spec left empty "until #NNN".
- A plan step that says "update the existing examples" without a list of files and lines.
- A helper or fixture that builds a file or a page shape another feature changed (`file_v4`, `as_current_version`).
