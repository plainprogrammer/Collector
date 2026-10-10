---
name: pr-exists-and-conflicts-check
description: Before creating a PR check one doesn't exist for the branch; after pushing check it is mergeable, because a conflicting PR gets no CI run
metadata:
  type: reference
---

- **Before `gh pr create`:** run `gh pr list --head <branch> --json number,url,isDraft`. A draft may already exist from the spec and plan stage (spec 015's PR #32 held only the documents). Update its title and body instead of opening a second one, and keep the old body in the scratchpad.
- **After pushing:** run `gh pr view <n> --json mergeable,mergeStateStatus`. GitHub starts no CI run on a PR that conflicts with its base, so "no checks reported" a few minutes after a push can mean `main` moved. On 2026-10-10, PR #30 had merged and both branches added a bullet at the same place in `CLAUDE.md`.
- **Fix:** `git fetch origin main`, merge `origin/main` into the feature branch (branches 011 and 015 did this; my reading is that pushed branches here are merged, not rebased), keep both sides' bullets, run the whole suite, push. CI then starts.

Related: [[ghcr-and-actions-facts]], [[pr-screenshots-workflow]], [[adr-numbers-across-branches]].
