---
name: draft-pr-on-first-push
description: The first push of a branch to GitHub opens a draft PR assigned to the maintainer, without asking
metadata:
  type: feedback
---

When a branch is first pushed to GitHub, open a **draft** pull request for it straight away and assign the maintainer (`plainprogrammer`), without waiting to be asked.

**Why:** on 2026-10-31 (spike #145), the maintainer said: "Whenever code is first pushed to Github I would like a draft PR created for it and me assigned". This came after three branches were pushed in one session, two of them with ready-for-review PRs and one with no PR. Those PRs (#147, #148, #149) were then made drafts and assigned.

**How to apply:**
- **After the first push:** check for an existing PR (`gh api repos/plainprogrammer/Collector/pulls?head=plainprogrammer:<branch>`). If there is none, create one with `draft: true`.
- **Assigning:** `mcp__github__create_pull_request` has no assignee field, so set it afterwards with `mcp__github__issue_write` (`method: update`, `assignees: ["plainprogrammer"]`).
- **The body:** use the attribution footer the session gives you.
- **Stacked branches:** a stacked branch's draft targets its parent branch.
- **Marking ready:** only the maintainer's request marks a PR ready. [[session-wrap-before-pr-review]] still applies before that.
- **Later pushes:** pushes to the same branch need no new PR.

Related: [[pr-exists-and-conflicts-check]], [[push-in-background]].
