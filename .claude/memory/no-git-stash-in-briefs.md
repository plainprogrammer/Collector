---
name: no-git-stash-in-briefs
description: Every implementer and reviewer brief forbids git stash (and reset/checkout except to restore a file after a deliberate mutation test) and the sqlite3 command (it prompts the maintainer); a stash/pop on a clean tree applies an old unrelated stash
metadata:
  type: feedback
---

In spec 080 (2026-11-13), a verification-writer subagent ran `git stash`, then `git stash pop`, to check something on a clean tree. Nothing was stashed, so the pop applied the oldest stash on the stack instead: an unrelated "Teleport auto-stash" from spec 039, which conflicted in `Gemfile.lock`. The controller restored `Gemfile.lock` and kept the old stash as `stash@{0}`. The stash list is shared across every worktree of the repo, so any session can hit this.

**Why:** a no-op `git stash` followed by `pop` doesn't fail. It changes the working tree with someone else's work, silently, and a careless restore can drop the maintainer's stash.

**How to apply:** in every implementer, reviewer and verification brief, say: "Never run `git stash`, `git reset` or `git checkout`. The one exception is `git checkout -- <file>` to restore a file you broke on purpose for a mutation test." After each unit, check `git stash list` and `git status` along with the diff. Related: [[subagent-commit-trailers]], [[worktree-isolation-command-guard]], [[batch-plan-tasks-per-implementer]].

**The `sqlite3` command, too** (rule restated 2026-11-13, spec 086 round 2: a reviewer ran it and prompted the maintainer, about 90 minutes lost): no agent, reviewer or implementer, runs the `sqlite3` command. A reviewer is read-only and runs nothing; a fact about SQLite files comes from a spec example that builds a database in the scratch directory or under `tmp/`. Put the sentence in every subagent brief.
