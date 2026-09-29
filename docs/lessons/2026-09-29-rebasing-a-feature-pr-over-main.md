---
date: 2026-09-29
spec: "002"
tags: [git, rebase, pull-request, ci, process]
---

# Lesson: Rebasing a feature PR over a moved main

## Context

PR #3 (feature 002) had to be rebased after main merged feature 003 (worktree setup) and two Dependabot bumps.

## What happened

- Only `.rubocop.yml` conflicted. Both sides had appended: main added a `RSpec/DescribeClass` exclude, and 002 added `RSpec/ExampleLength`. The fix was to keep both.
- `CLAUDE.md` and `README.md` auto-merged, but they needed reading to confirm the merged prose was still coherent.
- 002 had enabled random spec order, so main's new 003 specs ran in random order for the first time after the rebase. They passed across several seeds.
- Right after `git push --force-with-lease`, `gh pr view` still reported `CONFLICTING`. That was stale, and a recheck showed `MERGEABLE`, with CI then passing.

## What to do next time

1. After resolving, read every auto-merged doc file, not only the conflicted ones.
2. Run `bin/ci` and then `bin/rspec` with two more seeds, especially when either side changed spec-harness settings.
3. Push with `--force-with-lease`.
4. If GitHub still says conflicting, verify locally with `git merge-base --is-ancestor origin/main HEAD` and wait for GitHub to recompute before re-resolving anything.

## Signals to watch for

A PR marked conflicting after main moves; both branches editing shared config (`.rubocop.yml`, `CLAUDE.md`, `README.md`); a branch that changes test ordering or linting rules.
