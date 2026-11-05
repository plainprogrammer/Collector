---
date: 2026-11-03
spec: "036"
tags: [plan, testing, mutation, review]
---

# Lesson: Mutate both branches of an either/or guard, and write a mutation's sed against the real file

## Context

Spec 036's plan proved each of its ten file-shape guards by mutation (make the file wrong, watch the named example fail, restore). It extends the earlier lesson that guards prove themselves by mutation (2026-10-14).

## What happened

Two plan mistakes were caught by the read-only plan review, by tracing each command by hand, before anything ran:

- The sed that drops the Dependabot group was written against the plan's Markdown, where a list item's code block is indented two spaces more than the file will be. Its range patterns never matched, so the mutation changed nothing and the guard would have shown `0 failures` instead of one.
- AC-2.11 passes when either of two things holds (the gem audit asks for an update, or no step names the advisory database). A mutation that breaks only one branch leaves the example green, so the first version of that row proved nothing. The row had to break both branches at once.

A third, smaller one: the plan asked RuboCop to inspect `.rubocop.yml` by naming it as a file, which makes RuboCop parse it as Ruby and report a syntax offense. Loading the config by inspecting a Ruby file validates it.

## What to do next time

Write each mutation's sed or range against the de-indented file (read it with `cat -A` to see the real spacing), and have the plan review trace every mutation row to the one example that must fail. For a criterion that holds when either of two things holds, give the mutation row a change that breaks both. Name only Ruby files on a RuboCop command line.

## Signals to watch for

- A mutation table whose commands were written from the plan's own indentation.
- An acceptance criterion with "or" in it that has a single mutation row.
- A mutation row whose expected result is `1 failure` but which nobody has traced to the example it names.
