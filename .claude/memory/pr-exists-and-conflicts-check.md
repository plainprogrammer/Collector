---
name: pr-exists-and-conflicts-check
description: Before creating a PR check one doesn't exist for the branch; after pushing check it is mergeable, because a conflicting PR gets no CI run; stack on an unmerged sibling branch when the maintainer says so
metadata:
  type: reference
---

- **Before `gh pr create`:** run `gh pr list --head <branch> --json number,url,isDraft`. A draft may already exist from the spec and plan stage (spec 015's PR #32 held only the documents). Update its title and body instead of opening a second one, and keep the old body in the scratchpad.
- **After pushing:** run `gh pr view <n> --json mergeable,mergeStateStatus`. GitHub starts no CI run on a PR that conflicts with its base, so "no checks reported" a few minutes after a push can mean `main` moved. On 2026-10-10, PR #30 had merged and both branches added a bullet at the same place in `CLAUDE.md`.
- **Fix:** `git fetch origin main`, merge `origin/main` into the feature branch (branches 011 and 015 did this; my reading is that pushed branches here are merged, not rebased), keep both sides' bullets, run the whole suite, push. CI then starts.
- **Stacking on an unmerged sibling (spec 024, 2026-10-14):** when another in-flight branch changes the same files, the maintainer may say to stack on it. For #78, before the first push: `git fetch`, `git rebase origin/<sibling-branch>`, keep both behaviours, and bring your examples to the sibling's new wording (squashed into the commits that added them). Then run `bin/ci` again, push, and open the draft PR with `--base <sibling-branch>`, saying in the body that it is stacked and which PR merges first. The branch hadn't been pushed, so a rebase rewrote nothing shared. After the sibling merges, retarget with `gh pr edit <n> --base main` and run the mergeable check above. Expect the sibling's issue to be warned about at plan approval. The maintainer named #84 then, and the rebase came at the push approval.

Related: [[ghcr-and-actions-facts]], [[pr-screenshots-workflow]], [[adr-numbers-across-branches]], [[spec-024-followups]].
