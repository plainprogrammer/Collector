---
name: cloud-session-github-limits
description: A cloud session can't re-run GitHub workflow runs (403 from gh and the GitHub tool) or delete remote branches (the git proxy drops the delete; the API delete is refused as destructive); plan measurements and cleanup around the maintainer
metadata:
  type: reference
---

Seen in spec 035's cloud session (2026-11-01).

- **Re-running a workflow run is refused.** `gh api -X POST …/actions/runs/<id>/rerun` and the GitHub tool's `rerun_workflow_run` both return 403 "Resource not accessible by integration".
- **Deleting a remote branch is refused.**
  - `git push origin --delete <branch>` and `git push origin :refs/heads/<branch>` end with "the remote end hung up unexpectedly"; the agent proxy drops them.
  - `gh api -X DELETE …/git/refs/heads/<branch>` is refused by the auto-mode check as a destructive git action.
- **Everything else in that session worked:** reading runs, jobs, logs and artifacts; creating, updating and closing pull requests; assigning; and ordinary pushes, including `--force-with-lease`.

**Why it matters:** spec 035's plan relied on re-runs for its M = 3 measurements. The maintainer was asked to re-run one, but #149 merged first, so the third measurement became `main`'s merge run. The throwaway branch of #152 had to be left for the maintainer to delete.

**How to apply:**
- When a plan needs repeated CI runs, prefer runs this session can cause: pushes of real commits, never empty ones.
- Otherwise ask the maintainer for the re-runs early, and say what happens if the PR merges first.
- For a throwaway branch, tell the maintainer at the start that they will delete it, from the closed PR's "Delete branch" button.
- Don't retry a refused delete by another route.

Related: [[draft-pr-on-first-push]], [[ghcr-and-actions-facts]].
