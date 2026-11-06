---
name: gh-issue-view-silent
description: In Orca worktrees `gh issue view` prints nothing and exits 0; read issues and comments through `gh api`
metadata:
  type: reference
---

In an Orca worktree on 2026-11-06 (spec 043), `gh issue view 86 --comments`, with or without `--repo plainprogrammer/Collector`, printed nothing and exited 0. `gh api` worked:

- `gh api repos/plainprogrammer/Collector/issues/<n> --jq '.title, .body'`
- `gh api repos/plainprogrammer/Collector/issues/<n>/comments --jq '.[] | .user.login + ": " + .body'`

**Why:** an empty `gh issue view` looks like an issue with no text, and a worker could specify from the title alone.

**How to apply:** when `gh issue view` comes back empty, read the issue with `gh api` before concluding anything; in worker briefs, prefer `gh api` for issue text. Related: [[cloud-session-github-limits]], [[github-comment-tool-mangles-mentions]].
