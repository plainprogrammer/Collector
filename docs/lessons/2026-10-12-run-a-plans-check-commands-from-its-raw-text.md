---
date: 2026-10-12
spec: "020"
tags: [planning, review, shell, verification]
---

# Lesson: Run a plan's check commands from its raw text

## Context

Spec 020's plan was mostly check commands: counts, greps, diffs and route lookups whose expected output is the evidence for an acceptance criterion.

## What happened

I prototyped the plan's code edits on scratch copies and ran the introduction's checks, but wrote several other commands without running them. Two plan reviews, each told to copy every command from the Markdown source and run it, found: `bin/rspec --dry-run | tail -3`, which prints the seed line and not the count; a `git diff … | grep` for the safety warnings that also matches unchanged context lines and covered one line of a three-line warning; `bin/rails routes -g '/ocr/v7.0.0/'`, which finds nothing because the route is a pattern; two diff hunks cut two context lines short, so `git apply --check` rejected them; a word count I had written as 95 without counting (it was 97); and an environment-variable lookup whose `git grep` reached the tracked `.kamal/secrets`.

None of these was wrong about the work. Each would have stopped an executor or, worse, passed while proving nothing.

## What to do next time

Run every command in a plan before the plan is presented, from the text as written, and paste the observed output as the expectation. For a check that should print nothing, also run it against a case where it should print something. Ask the plan reviewer to do the same from the raw file and to say what each command actually proves.

**Superseded (2026-10-15):** neither the planner nor the plan reviewer runs a plan's code or commands before execution anymore ([[plan-reviews-run-the-code]]). A read-only reviewer still checks each command against the signals below, and execution runs them.

## Signals to watch for

- An expected output written from memory.
- `tail -N` or `head -N` on output whose length varies.
- `grep` over a diff.
- A literal path passed to a route or file lookup when the route is a pattern.
- A `git grep` with no pathspec in a repository with a tracked secrets file.
