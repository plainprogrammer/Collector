---
date: 2026-11-06
spec: "041, 042, 043, 044"
tags: [git, orchestration, ci, specs-index]
---

# Lesson: Each merge to main re-conflicts every open branch on the specs index

## Context

Four specs (041–044) were built in parallel worktrees and merged one after another on 2026-11-06, along with three plan-retirement PRs and a settings PR. Every feature branch adds its own row to `docs/specs/README.md`, and most also add to a shared file such as an area doc, `.rubocop.yml`'s `DescribeClass` excludes, or `.claude/memory/MEMORY.md`.

## What happened

Every merge to `main` made every other open PR conflict, nearly always on the specs index. GitHub runs no CI on a conflicting PR. So each branch merged `origin/main`, resolved the conflict, and pushed again, and that push ran the full `bin/ci` in the pre-push hook, about 5 minutes.

- Spec 042's PR #193 went green on `489c2c2`, then conflicted twice more before it merged.
- Spec 041's PR #197 conflicted after #193 merged, and again after the small retirement PR #196.
- Each plan retirement is itself a merge to `main`, so it re-conflicts whatever is still open.

## What to do next time

- Merge parallel PRs one at a time.
- Hold a branch's last push until the merge ahead of it has landed. Then merge `main` once, and fold the session-wrap commit into that same push.
- Batch plan retirements into one housekeeping PR after the features are in, rather than one PR per feature between merges.
- When resolving the index, keep each row from the side that last changed it: the branch's own row, and `main`'s rows for specs that have since retired their plans.

## Signals to watch for

- A green PR that GitHub marks CONFLICTING minutes later.
- A second "push slot" request from the same branch with only a merge commit added.
