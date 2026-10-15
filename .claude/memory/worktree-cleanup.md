---
name: worktree-cleanup
description: Before removing a worktree, check dirty / head in origin/main / PR merged; orca worktree rm for Orca-managed ones, git worktree remove otherwise; branch -D only after the ancestor check; ask before deleting unpushed scratch commits
metadata:
  type: reference
---

From the cleanup of 2026-10-15, after the parallel run's PRs (#95–#99) merged.

- **Check each worktree first**, after `git fetch origin --prune`:
  - `git -C <dir> status --porcelain`: nothing uncommitted.
  - `git merge-base --is-ancestor $(git -C <dir> rev-parse HEAD) origin/main`: its head is in `main`.
  - `gh pr list --state all --head <branch>`: its PR merged. A squash or a differently named branch can merge the work while this check fails.
- **Orca-managed worktrees** (`orca worktree list` shows them): `orca worktree rm --worktree path:<dir>`. It closes their terminals and deletes the local branch when it can prove the branch is merged.
- **Others** (Agent-tool worktrees under `.claude/worktrees/`, hand-made ones): `git worktree remove <dir>` (unlock first if locked), then `git worktree prune`.
- **`git branch -d` refuses when the local `main` is behind `origin/main`** ("not fully merged"). Once the ancestor check above passes, `git branch -D` is safe.
- **A head not in `main` can be the only copy of something.** `065-unowned-tile-options` held three unpushed `scratch(065)` commits prototyping alternative "Not owned" looks; the shipped fix came through PR #88 on another branch. Show the commits (`git log origin/main..<branch>`) and ask before deleting. The maintainer chose to delete them that time.
- Keep a worktree that backs an open PR (`013-live-cleanup-evidence` backs draft PR #28).

**How to apply:** whenever worktrees or branches are cleaned up. Related: [[orca-coordinator-loop]], [[pr-exists-and-conflicts-check]].
